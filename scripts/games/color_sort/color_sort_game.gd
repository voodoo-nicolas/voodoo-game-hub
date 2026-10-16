extends Control

## Color Sort -- tap a vial, then another (or the big central vial), to pour its
## top colour over. A colour can go into an empty vial or onto the same colour.
## Fill every vial with a single colour. Every colour has its own pattern too.
## Liquid is drawn in code: layers with a wavy surface, glass shine, bubbles.

const CSEngine = preload("res://scripts/games/color_sort/color_sort_engine.gd")
const HELP = preload("res://scripts/games/color_sort/color_sort_help.gd")
const HomeKit = preload("res://scripts/games/color_sort/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
## Skulls, bones, dolls for the Voodoo skin. Loaded, never preloaded: apps before v0.21 lack it.
const VOODOO_PATH := "res://scripts/common/voodoo.gd"

const SAVE_PATH := "user://color_sort_save.json"
const PROGRESS_PATH := "user://color_sort_progress.json"
const OPTS_PATH := "user://color_sort_opts.json"
const LEVEL_NAMES := ["Easy", "Normal", "Hard", "Expert"]
## Fourteen colours; most levels use far fewer.
const CLASSIC_COLORS := [Color("e63946"), Color("f4a261"), Color("f1d34a"), Color("2a9d8f"), Color("3a86ff"),
	Color("8d5bd6"), Color("ff6fa8"), Color("4cc26a"), Color("9aa0aa"), Color("8d5524"),
	Color("17c3e8"), Color("7a1f3d"), Color("c6f432"), Color("2b2d7a")]
const NEON_COLORS := [Color("ff2b4f"), Color("ff9a2b"), Color("fff23a"), Color("29e6a6"), Color("3a8cff"),
	Color("b36bff"), Color("ff2bd6"), Color("7dff3a"), Color("c9d2e6"), Color("c98a4a"),
	Color("17f0ff"), Color("a3004f"), Color("c6ff2b"), Color("5a4dff")]
## Okabe-Ito based (safe for the common kinds of colour blindness), plus six more
## that differ in lightness; the patterns do the rest.
const SAFE_COLORS := [Color("e69f00"), Color("56b4e9"), Color("009e73"), Color("f0e442"), Color("0072b2"),
	Color("d55e00"), Color("cc79a7"), Color("999999"), Color("1b2a5e"), Color("a8e6cf"),
	Color("7b4a12"), Color("c3b1e1"), Color("f2f2f2"), Color("6b7a1a")]
## Voodoo-skin sounds, synthesized from Sfx recipes (see scripts/common/sfx.gd): only this
## game uses them, so they live here. Apps without Sfx._render fall back to library sounds.
const POTION_SOUNDS := {
	"cork_pop": [{"t": "sine", "f": 900, "f2": 240, "len": 0.09, "dec": 30, "vol": 0.5},
		{"t": "noise", "len": 0.05, "dec": 70, "lp": 0.5, "hp": true, "vol": 0.35}],
	"glug": [{"t": "sine", "f": 180, "f2": 420, "len": 0.08, "dec": 22, "vol": 0.4},
		{"t": "sine", "f": 150, "f2": 380, "at": 0.1, "len": 0.08, "dec": 22, "vol": 0.36},
		{"t": "sine", "f": 210, "f2": 460, "at": 0.2, "len": 0.09, "dec": 20, "vol": 0.3},
		{"t": "noise", "len": 0.3, "swell": true, "lp": 0.1, "lp2": 0.2, "vol": 0.15}],
	"stinger": [{"t": "tri", "f": 440, "f2": 415, "len": 0.9, "dec": 2.5, "vol": 0.2},
		{"t": "tri", "f": 622, "f2": 588, "at": 0.04, "len": 0.9, "dec": 2.5, "vol": 0.15},
		{"t": "sine", "f": 110, "f2": 98, "len": 1.1, "dec": 2.0, "vol": 0.3},
		{"t": "sine", "f": 1760, "f2": 1480, "at": 0.18, "len": 0.7, "dec": 4, "vol": 0.07},
		{"t": "noise", "len": 0.7, "swell": true, "lp": 0.04, "lp2": 0.2, "vol": 0.25}],
}
## Names of the colours above, for the Color names learning option (tr() to translate;
## the English + Spanish mode reads the Spanish from the i18n file).
const CLASSIC_NAMES := ["Red", "Orange", "Yellow", "Teal", "Blue", "Purple", "Pink", "Green", "Gray", "Brown",
	"Cyan", "Maroon", "Lime", "Indigo"]
const SAFE_NAMES := ["Orange", "Sky blue", "Green", "Yellow", "Blue", "Vermilion", "Orchid", "Gray", "Navy", "Mint",
	"Brown", "Lilac", "Pearl", "Olive"]
const I18N = preload("res://scripts/games/color_sort/color_sort_i18n.gd")
const PATTERNS := 14
const POUR_TIME := 0.32
## Free economy (no ads, no purchases): hints and extra vials are earned by playing.
const START_HINTS := 3
const START_VIALS := 2
const MAX_HINTS := 20
const MAX_VIALS_STOCK := 10
const MAX_P := 96
const MOTES := 12

var info = null  # GameInfo; null on apps without it, so guard every use
var voodoo = null  # scripts/common/voodoo.gd (static drawing); null on old apps
var _potion_cache := {}
var home  # HomeKit: Landing + pause menu
var engine: CSEngine
var bg: ColorRect
var skin: String = "classic"
var status_label: Label
var table: Control
var undo_btn: Button
var tube_btn: Button
var reset_btn: Button
var end_dialog: ColorRect
var fail_dialog: ColorRect
var banner_label: Label
var selected: int = -1
var playing: bool = false
var solved_shown: bool = false
var ended: bool = false           # failed (out of moves / time): the level is over
var was_locked: Array = []        # to notice a padlock opening / a cork popping
var last_sec: int = -1
var hint_btn: Button
var hint_from: int = -2           # a hint being shown: pour hint_from -> hint_to
var hint_to: int = -2
var hint_t: float = 0.0
var toast_text: String = ""
var toast_t: float = 0.0

## Player choices (OPTS_PATH): colour-blind palette, pattern overlay.
var opts: Dictionary = {"safe": false, "patterns": true, "names": 0}  # names: 0 off, 1 my language, 2 English + Spanish
## Campaign progress (PROGRESS_PATH): next level, best result per level.
var progress: Dictionary = {"level": 1, "best": {}, "hints": START_HINTS, "vials": START_VIALS, "day": 0}

var elapsed: float = 0.0
var clock: float = 0.0
var wobble: float = 0.0           # liquid sloshing after a pour, 1 -> 0
var flash: float = 0.0            # central vial completed
var anim = null                   # the pour being shown: {from, to, n, col, t}
var lifts := PackedFloat32Array() # how far each vial is raised (selected)
var idle_acc: float = 0.0
var bubble_acc: float = 0.0
var _lay: Dictionary = {}
var _lay_key: String = ""
var _sb_normal: StyleBoxFlat
var _sb_selected: StyleBoxFlat
var _cpoly: PackedVector2Array = PackedVector2Array()
var _cpoly_key: String = ""

# pooled particles: bubbles (0), sparks (1), ambient motes (2)
var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_rad := PackedFloat32Array()
var p_col := PackedColorArray()
var p_kind := PackedByteArray()

func _ready() -> void:
	preload("res://scripts/games/color_sort/color_sort_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = CSEngine.new()
	engine.new_game(0)
	if ResourceLoader.exists(VOODOO_PATH):
		voodoo = load(VOODOO_PATH)
	_load_opts()
	_load_progress()
	_init_particles()
	_build_ui()
	_calm_music()
	_sync_down()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _calm_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 0, 2.0)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause_home)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🧪 Color Sort")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = "↺"
	new_btn.custom_minimum_size = Vector2(76, 64)
	new_btn.add_theme_font_size_override("font_size", 30)
	new_btn.pressed.connect(_restart)
	bar.add_child(new_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	banner_label = Label.new()
	banner_label.add_theme_font_size_override("font_size", 22)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	banner_label.visible = false
	root.add_child(banner_label)

	table = Control.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.draw.connect(_draw_table)
	table.gui_input.connect(_on_table_input)
	root.add_child(table)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_theme_constant_override("margin_left", 16)
	bm.add_theme_constant_override("margin_right", 16)
	root.add_child(bm)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bm.add_child(row)
	undo_btn = _button(tr("↩ Undo"), _on_undo)
	row.add_child(undo_btn)
	hint_btn = _button(tr("💡 Hint"), _on_hint)
	row.add_child(hint_btn)
	tube_btn = _button(tr("➕ Tube"), _on_add_tube)
	row.add_child(tube_btn)
	reset_btn = _button(tr("⟲ Reset"), _on_reset)
	row.add_child(reset_btn)

	end_dialog = UI.build_dialog(tr("Sorted!"), [
		{"text": tr("Next puzzle"), "action": _next_puzzle},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)
	fail_dialog = UI.build_dialog(tr("Not this time"), [
		{"text": tr("Try again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(fail_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = [{"text": "▶ Play", "sub": tr("Level %d") % int(progress.level), "key": "campaign",
		"action": _start_campaign}]
	for i in 4:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard", "🤯 Expert"][i], "sub": "%d colors" % CSEngine.LEVELS[i].colors, "row": "lvl",
			"action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Pour the colors until every vial is one color.",
		"logo": _draw_home_logo,
		"modes": modes,
		"extra": _add_options,
		"more": [["🗺 Levels", HomeKit.CYAN, _show_levels]],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Total stars",
		"board_note": "Stars earned on campaign levels.",
	})
	add_child(home)
	if info:
		add_child(info)

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b

## The game's own pickers on the setup screens.
func _add_options(box: VBoxContainer) -> void:
	box.add_child(home.section(tr("Colors")))
	box.add_child(home.choice_row(["Standard", "Color-blind safe"], 1 if opts.safe else 0, _on_pick_palette))
	box.add_child(home.section(tr("Patterns on the colors")))
	box.add_child(home.choice_row(["On", "Off"], 0 if opts.patterns else 1, _on_pick_patterns))
	box.add_child(home.section(tr("Color names")))
	box.add_child(home.choice_row(["No names", "Names", "English + Español"], int(opts.names), _on_pick_names))

func _on_pick_palette(i: int) -> void:
	opts.safe = i == 1
	_save_opts()
	table.queue_redraw()

func _on_pick_names(i: int) -> void:
	opts.names = i
	_save_opts()
	table.queue_redraw()

func _on_pick_patterns(i: int) -> void:
	opts.patterns = i == 0
	_save_opts()
	table.queue_redraw()

func _load_opts() -> void:
	var d = SaveUtil.read(OPTS_PATH)
	if d is Dictionary:
		opts.safe = bool(d.get("safe", false))
		opts.patterns = bool(d.get("patterns", true))
		opts.names = clampi(int(d.get("names", 0)), 0, 2)

func _save_opts() -> void:
	SaveUtil.write(OPTS_PATH, opts)

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	if d is Dictionary:
		progress.level = maxi(1, int(d.get("level", 1)))
		var b = d.get("best", {})
		progress.best = b if b is Dictionary else {}
		progress.hints = clampi(int(d.get("hints", START_HINTS)), 0, MAX_HINTS)
		progress.vials = clampi(int(d.get("vials", START_VIALS)), 0, MAX_VIALS_STOCK)
		progress.day = int(d.get("day", 0))

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	_lay_key = ""
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if table:
		table.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _color_of(c: int) -> Color:
	if c < 0:
		return Color("4a4466")  # a hidden (mystery) layer
	var pal: Array = SAFE_COLORS if opts.safe else (CLASSIC_COLORS if _is_classic() else NEON_COLORS)
	return pal[c % pal.size()]

# ---------- layout ----------

## Where everything goes, for the current table size, vial count and level kind:
## {"rects": [Rect2 per vial], "lh": layer height, "vw", "vh", "center": Rect2}.
func _layout() -> Dictionary:
	var key := "%d|%d|%d|%d|%d|%s" % [int(table.size.x), int(table.size.y), engine.tubes.size(), engine.cap,
		1 if engine.has_center() else 0, skin]
	if key == _lay_key:
		return _lay
	_lay_key = key
	var n: int = engine.tubes.size()
	var w: float = table.size.x
	var h: float = table.size.y
	var has_c: bool = engine.has_center()
	var c_h: float = clampf(h * 0.30, 150.0, 280.0) if has_c else 0.0
	var groups: Array = []
	if has_c:
		var split: int = int(ceil(n / 2.0))
		groups = [range(0, split), range(split, n)]
	else:
		groups = [range(0, n)]
	var cols_max: int = maxi(3, int((w - 16.0) / 84.0))
	var rows_of: Array = []
	var rows_total := 0
	var max_cols := 1
	for g in groups:
		var rws: int = maxi(1, int(ceil(g.size() / float(cols_max))))
		rows_of.append(rws)
		rows_total += rws
		max_cols = maxi(max_cols, int(ceil(g.size() / float(rws))))
	var band_h: float = (h - c_h) / rows_total
	var cell_w: float = (w - 16.0) / max_cols
	var vw0: float = clampf(cell_w * 0.66, 30.0, 76.0)
	var lh: float = maxf(14.0, minf((band_h - 30.0) / engine.cap, vw0 * 0.95))
	var vw: float = minf(vw0, lh * 1.9)
	var vh: float = engine.cap * lh + 14.0
	# no more room per row than a vial needs: the whole set sits in the middle of the table
	var band_use: float = minf(band_h, vh + 46.0)
	var rects: Array = []
	rects.resize(n)
	var y: float = maxf(0.0, (h - c_h - rows_total * band_use) / 2.0)
	var center_rect := Rect2()
	for gi in groups.size():
		var g: Array = groups[gi]
		var per_row: int = int(ceil(g.size() / float(rows_of[gi])))
		for r in rows_of[gi]:
			var first: int = r * per_row
			var count: int = mini(per_row, g.size() - first)
			if count <= 0:
				continue
			var x0: float = (w - count * cell_w) / 2.0 + (cell_w - vw) / 2.0
			for c in count:
				rects[g[first + c]] = Rect2(x0 + c * cell_w, y + band_use - vh - 4.0, vw, vh)
			y += band_use
		if has_c and gi == 0:
			var hc: float = c_h - 34.0
			var wc: float = minf(w * 0.6, hc * (1.1 if _is_classic() else 0.95))
			center_rect = Rect2((w - wc) / 2.0, y + 30.0, wc, hc)
			y += c_h
	var rad: int = int(vw / 2.0)
	_sb_normal = _vial_style(rad, false)
	_sb_selected = _vial_style(rad, true)
	_lay = {"rects": rects, "lh": lh, "vw": vw, "vh": vh, "center": center_rect}
	return _lay

func _vial_style(rad: int, sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_bottom_left = rad
	sb.corner_radius_bottom_right = rad
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.set_border_width_all(3)
	if _is_classic():
		sb.bg_color = Color(0.85, 0.92, 1.0, 0.14)
		sb.border_color = HomeKit.CLASSIC.yellow if sel else Color("c9d6ea")
	else:
		sb.bg_color = Color(HomeKit.CYAN, 0.07)
		sb.border_color = HomeKit.GOLD if sel else HomeKit.CYAN
		sb.shadow_color = Color(HomeKit.GOLD if sel else HomeKit.CYAN, 0.3)
		sb.shadow_size = 6
	return sb

# ---------- drawing ----------

func _draw_table() -> void:
	if engine == null or engine.tubes.is_empty():
		return
	var lay := _layout()
	var w: float = table.size.x
	var h: float = table.size.y
	# dark gradient ground
	var c1 := Color("1b2438") if _is_classic() else Color("150a26")
	var c2 := Color("0c101c") if _is_classic() else Color("04050c")
	var kind: String = engine.rules.get("kind", "")
	if kind != "":
		c1 = c1.lerp(_kind_color(kind), 0.22)  # each special level has its own tint
	table.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([c1, c1, c2, c2]))
	for i in MOTES:
		if p_life[i] > 0.0:
			var a: float = minf(1.0, p_life[i] / 2.0) * 0.18
			table.draw_circle(p_pos[i], p_rad[i], Color(1, 1, 1, a))
	var rects: Array = lay.rects
	if not _is_classic():
		_draw_decor(lay, w, h)
	for p in engine.rules.get("blocked", []):
		if int(p[0]) < rects.size() and int(p[1]) < rects.size():
			var pa: Vector2 = rects[int(p[0])].get_center()
			var pb: Vector2 = rects[int(p[1])].get_center()
			table.draw_dashed_line(pa, pb, Color("ff5a5a", 0.55), 3.0, 8.0)
			var mid: Vector2 = pa.lerp(pb, 0.5)
			table.draw_circle(mid, 11.0, Color("ff5a5a", 0.9))
			table.draw_line(mid + Vector2(-5, -5), mid + Vector2(5, 5), Color.WHITE, 2.5)
			table.draw_line(mid + Vector2(-5, 5), mid + Vector2(5, -5), Color.WHITE, 2.5)
	for i in rects.size():
		_draw_vial(i, rects[i], lay)
	if engine.has_center():
		_draw_center(lay.center)
		if hint_t > 0.0 and hint_to == CSEngine.CENTER:
			var pulse2: float = 0.5 + 0.5 * sin(clock * 8.0)
			var cr: Rect2 = lay.center
			table.draw_rect(cr.grow(8.0 + pulse2 * 4.0), Color("4cff8a", 0.5 + 0.4 * pulse2), false, 4.0)
	_draw_stream(lay)
	if toast_t > 0.0:
		var font := ThemeDB.fallback_font
		var tw: float = minf(w - 24.0, 620.0)
		var box := Rect2((w - tw) / 2.0, h - 70.0, tw, 52.0)
		table.draw_rect(box, Color(0.02, 0.03, 0.08, minf(1.0, toast_t) * 0.9))
		table.draw_string(font, box.position + Vector2(10.0, 33.0), toast_text, HORIZONTAL_ALIGNMENT_CENTER, tw - 20.0, 22, Color(1, 1, 1, minf(1.0, toast_t)))
	for i in range(MOTES, MAX_P):
		if p_life[i] > 0.0:
			var f: float = p_life[i] / p_max[i]
			if p_kind[i] == 0:
				table.draw_arc(p_pos[i], p_rad[i], 0.0, TAU, 10, Color(1, 1, 1, 0.5 * f + 0.1), 1.5)
			else:
				table.draw_circle(p_pos[i], p_rad[i] * (0.4 + f * 0.6), Color(p_col[i], f))

## The name of colour c for the learning option: in the player's language, or "Red · Rojo".
func _name_text(c: int) -> String:
	var names: Array = SAFE_NAMES if opts.safe else CLASSIC_NAMES
	var key: String = names[c % names.size()]
	if int(opts.names) == 2:
		var es: String = str(I18N.STRINGS.es.get(key, key))
		return key if es == key else "%s · %s" % [key, es]
	return tr(key)

## A small tag with a colour's name above a lifted vial.
func _draw_name_tag(at: Vector2, c: int) -> void:
	var font := ThemeDB.fallback_font
	var txt := _name_text(c)
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var box := Rect2(at.x - sz.x / 2.0 - 10.0, at.y - 22.0, sz.x + 20.0, 30.0)
	var wall: float = table.size.x
	box.position.x = clampf(box.position.x, 4.0, wall - box.size.x - 4.0)
	table.draw_rect(box, Color(0.02, 0.03, 0.08, 0.9))
	table.draw_rect(box, Color(1, 1, 1, 0.5), false, 1.5)
	table.draw_string(font, Vector2(box.position.x + 10.0, box.position.y + 22.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

## Accent colour of a special level (banner and ground tint).
func _kind_color(kind: String) -> Color:
	match kind:
		"mystery":
			return Color("8d5bd6")
		"locked":
			return Color("e0c36a")
		"moves":
			return Color("ff8a3d")
		"timer":
			return Color("29e6ff")
		"corks":
			return Color("b98a56")
		"mixed":
			return Color("ff5a5a")
		"boss":
			return Color("ff2b4f")
		"pressure":
			return Color("3a8cff")
	return Color.WHITE

func _kind_title(kind: String) -> String:
	match kind:
		"mystery":
			return tr("Mystery vials")
		"locked":
			return tr("Locked vials")
		"moves":
			return tr("Limited moves")
		"timer":
			return tr("Timer")
		"corks":
			return tr("Sealed corks")
		"mixed":
			return tr("Blocked pours")
		"boss":
			return tr("Boss level")
		"pressure":
			return tr("Pressure")
	return ""

func _kind_hint(kind: String) -> String:
	match kind:
		"mystery":
			return tr("Hidden layers show when they reach the top.")
		"locked":
			return tr("A padlocked vial opens after the number of pours on it.")
		"moves":
			return tr("Finish before the moves run out.")
		"timer":
			return tr("Finish before the time runs out.")
		"corks":
			return tr("A corked vial opens when the vial next to it is full.")
		"mixed":
			return tr("Vials joined by a red line can't pour into each other.")
		"boss":
			return tr("Several rules at once. Good luck!")
		"pressure":
			return tr("The big vial leaks a layer back every few pours.")
	return ""

## The layers of vial i to show: [colour, lo, hi] in layer units (so a pour can be
## drawn half done), same colours merged into one block.
func _blocks(i: int) -> Array:
	var t: Array = engine.tubes[i]
	var layers: Array = []
	# A leak from the central vial lands after the pour: keep it out of the picture until the pour is done.
	var eff: int = t.size() - (1 if (anim != null and int(anim.leak) == i) else 0)
	var grow_from: int = -1
	var grow_n: int = 0
	var prog: float = 1.0
	if anim != null:
		prog = clampf(float(anim.t), 0.0, 1.0)
		if int(anim.to) == i:
			grow_from = eff - int(anim.n)
			grow_n = int(anim.n)
	for k in eff:
		var hi: float = k + 1.0
		var lo: float = float(k)
		if grow_from >= 0 and k >= grow_from:
			hi = minf(k + 1.0, grow_from + grow_n * prog)
			if hi <= lo:
				continue
		layers.append([-1 if engine.is_hidden(i, k) else int(t[k]), lo, hi])
	if anim != null and int(anim.from) == i:
		for j in int(anim.n):
			var lo2: float = eff + j
			var hi2: float = minf(lo2 + 1.0, eff + int(anim.n) * (1.0 - prog))
			if hi2 > lo2:
				layers.append([int(anim.col), lo2, hi2])
	var blocks: Array = []
	for l in layers:
		if not blocks.is_empty() and blocks[blocks.size() - 1][0] == l[0] and absf(blocks[blocks.size() - 1][2] - l[1]) < 0.001:
			blocks[blocks.size() - 1][2] = l[2]
		else:
			blocks.append([l[0], l[1], l[2]])
	return blocks

func _half_w(rad: float, cy: float, y: float) -> float:
	if y <= cy:
		return rad
	return sqrt(maxf(0.0, rad * rad - (y - cy) * (y - cy)))

func _add_pt(pts: PackedVector2Array, v: Vector2) -> void:
	if pts.is_empty() or pts[pts.size() - 1].distance_to(v) > 0.05:
		pts.append(v)

## Polygon of a liquid band in a round-bottomed vial (centre x `cx`, inner
## half-width `rad`, inner bottom `yb`), from y_top down to y_bot. amp > 0: wavy top.
func _band(cx: float, rad: float, yb: float, y_top: float, y_bot: float, amp: float, phase: float) -> PackedVector2Array:
	var cy: float = yb - rad
	var pts := PackedVector2Array()
	var ht: float = _half_w(rad, cy, y_top)
	for j in 7:
		var u: float = j / 6.0
		var yy: float = y_top
		if amp > 0.0:
			yy += amp * sin(phase + u * 6.0)
		_add_pt(pts, Vector2(cx - ht + u * 2.0 * ht, yy))
	var y0: float = maxf(y_top, cy)
	if y_bot > cy:
		for s in 7:
			var yy2: float = lerpf(y0, y_bot, s / 6.0)
			_add_pt(pts, Vector2(cx + _half_w(rad, cy, yy2), yy2))
		for s in range(6, -1, -1):
			var yy3: float = lerpf(y0, y_bot, s / 6.0)
			_add_pt(pts, Vector2(cx - _half_w(rad, cy, yy3), yy3))
	else:
		_add_pt(pts, Vector2(cx + rad, y_bot))
		_add_pt(pts, Vector2(cx - rad, y_bot))
	return pts

func _draw_vial(i: int, r0: Rect2, lay: Dictionary) -> void:
	var lift: float = lifts[i] if i < lifts.size() else 0.0
	var r := Rect2(r0.position + Vector2(0, lift), r0.size)
	var lh: float = lay.lh
	var is_sel: bool = i == selected
	if lift < -1.0:
		table.draw_circle(Vector2(r0.position.x + r0.size.x / 2.0, r0.end.y - 2.0), r0.size.x * 0.32, Color(0, 0, 0, 0.18))
	var cx: float = r.position.x + r.size.x / 2.0
	var rad: float = r.size.x / 2.0 - 4.0
	var yb: float = r.end.y - 4.0
	var shape: int = _shape_of(i)
	var hh: float = engine.cap * lh
	var shaped: bool = not _is_classic()
	if shaped:
		var glass := _outline(cx, rad + 3.0, yb + 3.0, hh + 6.0, shape)
		table.draw_colored_polygon(glass, Color(HomeKit.CYAN, 0.07))
		var closed := glass.duplicate()
		closed.append(glass[0])
		var edge: Color = HomeKit.GOLD if is_sel else HomeKit.CYAN
		table.draw_polyline(closed, Color(edge, 0.3), 8.0, true)
		table.draw_polyline(closed, edge, 3.0, true)
	else:
		table.draw_style_box(_sb_selected if is_sel else _sb_normal, r)
	if hint_t > 0.0 and (i == hint_from or i == hint_to):
		var pulse: float = 0.5 + 0.5 * sin(clock * 8.0)
		var hc: Color = Color("ffd84a") if i == hint_from else Color("4cff8a")
		table.draw_rect(r.grow(5.0 + pulse * 3.0), Color(hc, 0.55 + 0.35 * pulse), false, 4.0)
	var blocks := _blocks(i)
	var top_i := -1
	var top_hi := 0.0
	for b in blocks.size():
		if blocks[b][2] > top_hi:
			top_hi = blocks[b][2]
			top_i = b
	for b in blocks.size():
		var blk: Array = blocks[b]
		var col := _color_of(int(blk[0]))
		var y_bot: float = yb - blk[1] * lh
		var y_top: float = yb - blk[2] * lh
		var amp := 0.0
		if b == top_i:
			amp = 0.8 + wobble * 3.0
		var poly: PackedVector2Array
		if shaped:
			poly = _band_shaped(cx, rad, yb, hh, shape, y_top, y_bot, amp, clock * 5.0 + i)
		else:
			poly = _band(cx, rad, yb, y_top, y_bot, amp, clock * 5.0 + i)
		if poly.size() >= 3:
			table.draw_colored_polygon(poly, col)
			if y_bot - y_top > 10.0:
				var pf: float = _prof(shape, clampf((yb - (y_top + y_bot) / 2.0) / hh, 0.0, 1.0), 0.1) if shaped else 1.0
				table.draw_line(Vector2(cx - rad * 0.55 * pf, y_top + 5.0), Vector2(cx - rad * 0.55 * pf, y_bot - 5.0), Color(1, 1, 1, 0.22), 3.0)
				table.draw_line(Vector2(cx + rad * 0.7 * pf, y_top + 5.0), Vector2(cx + rad * 0.7 * pf, y_bot - 5.0), Color(0, 0, 0, 0.14), 3.0)
			if b == top_i:
				var surf := PackedVector2Array()
				for j in 7:
					surf.append(poly[j])
				table.draw_polyline(surf, col.lightened(0.45), 2.0)
	# mystery layers show a question mark
	var font := ThemeDB.fallback_font
	var tt: Array = engine.tubes[i]
	for k in tt.size():
		if engine.is_hidden(i, k):
			var fs: int = int(lh * 0.62)
			table.draw_string(font, Vector2(cx - fs * 0.3, yb - (k + 0.5) * lh + fs * 0.33), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.75))
	# patterns, one per whole layer
	if opts.patterns:
		var t: Array = engine.tubes[i]
		for k in t.size():
			if engine.is_hidden(i, k):
				continue
			if anim != null and int(anim.to) == i and k >= t.size() - int(anim.n) and float(anim.t) < 1.0:
				continue
			var col2 := _color_of(int(t[k]))
			var mark := Color(0, 0, 0, 0.55) if col2.get_luminance() > 0.55 else Color(1, 1, 1, 0.8)
			_draw_symbol(Vector2(cx, yb - (k + 0.5) * lh), minf(lh, rad * 2.0) * 0.21, int(t[k]), mark)
	# glass shine
	if not shaped:
		table.draw_line(Vector2(cx - rad + 5.0, r.position.y + 12.0), Vector2(cx - rad + 5.0, yb - rad), Color(1, 1, 1, 0.3), 3.0, true)
		table.draw_arc(Vector2(cx, yb - rad), rad * 0.72, PI * 0.6, PI * 0.9, 6, Color(1, 1, 1, 0.28), 2.5)
	else:
		var sh: float = rad * _prof(shape, 0.4, 0.1) * 0.8
		table.draw_line(Vector2(cx - sh, yb - hh * 0.75), Vector2(cx - sh, yb - hh * 0.18), Color(1, 1, 1, 0.3), 3.0, true)
	if shaped:
		var top_hw: float = (rad + 3.0) * _prof(shape, 1.0, 0.1)
		table.draw_line(Vector2(cx - top_hw - 3.0, yb - hh - 3.0), Vector2(cx + top_hw + 3.0, yb - hh - 3.0), Color(1, 1, 1, 0.5), 3.0)
		if not engine.is_locked(i):
			_draw_skull_cork(cx, yb - hh - 4.0, r.size.x * 0.95, false)
	else:
		table.draw_line(Vector2(r.position.x - 3.0, r.position.y + 6.0), Vector2(r.end.x + 3.0, r.position.y + 6.0), Color(1, 1, 1, 0.5), 3.0)
	if engine.is_locked(i):
		_draw_lock(i, r, cx)
	if is_sel and int(opts.names) > 0 and not engine.tubes[i].is_empty() and not engine.is_hidden(i, engine.tubes[i].size() - 1):
		_draw_name_tag(Vector2(cx, r.position.y - (r.size.x * 0.9 + 12.0 if shaped else 6.0)), int(engine.tubes[i][engine.tubes[i].size() - 1]))

## Voodoo skin: potion bottles of a few shapes. Half-width of a vial at height share
## t (0 = inner bottom, 1 = top) as a share of the full inner half-width.
func _prof(shape: int, t: float, rb: float) -> float:
	var f := 1.0
	match shape:
		1:  # round flask: wide body, narrow neck
			f = 1.0 - 0.55 * smoothstep(0.55, 0.82, t)
		2:  # tall and slim
			f = 0.74
		3:  # teardrop: wide at the bottom, narrowing up
			f = lerpf(1.0, 0.5, smoothstep(0.1, 1.0, t))
	if t < rb:
		var u: float = 1.0 - t / rb
		f *= sqrt(maxf(0.0, 1.0 - u * u))
	return f

## Which bottle vial i is (Classic: all test tubes).
func _shape_of(i: int) -> int:
	if _is_classic():
		return 0
	return [1, 0, 3, 2][i % 4]

## Closed outline of a vial: from the top-left rim down, round the bottom, up the right side.
func _outline(cx: float, rad: float, yb: float, hh: float, shape: int) -> PackedVector2Array:
	var rb: float = clampf(rad / hh, 0.05, 0.35)
	var pts := PackedVector2Array()
	for s in 25:
		var t: float = 1.0 - s / 24.0
		pts.append(Vector2(cx - rad * _prof(shape, t, rb), yb - t * hh))
	for s in 1:
		pts.append(Vector2(cx, yb))
	for s in range(1, 25):
		var t2: float = s / 24.0
		pts.append(Vector2(cx + rad * _prof(shape, t2, rb), yb - t2 * hh))
	return pts

## Liquid band in a shaped bottle, y_top down to y_bot; amp > 0 gives the surface a wave.
func _band_shaped(cx: float, rad: float, yb: float, hh: float, shape: int, y_top: float, y_bot: float, amp: float, phase: float) -> PackedVector2Array:
	var rb: float = clampf(rad / hh, 0.05, 0.35)
	var pts := PackedVector2Array()
	var wt: float = rad * _prof(shape, clampf((yb - y_top) / hh, 0.0, 1.0), rb)
	for j in 7:
		var u: float = j / 6.0
		var yy: float = y_top
		if amp > 0.0:
			yy += amp * sin(phase + u * 6.0)
		_add_pt(pts, Vector2(cx - wt + u * 2.0 * wt, yy))
	var n := 10
	for s in n + 1:
		var y: float = lerpf(y_top, y_bot, float(s) / n)
		_add_pt(pts, Vector2(cx + rad * _prof(shape, clampf((yb - y) / hh, 0.0, 1.0), rb), y))
	for s in range(n, -1, -1):
		var y2: float = lerpf(y_top, y_bot, float(s) / n)
		_add_pt(pts, Vector2(cx - rad * _prof(shape, clampf((yb - y2) / hh, 0.0, 1.0), rb), y2))
	return pts

## A skull stopper on a vial's mouth (Voodoo skin).
func _draw_skull_cork(cx: float, rim_y: float, s: float, dark: bool) -> void:
	if voodoo == null:
		return
	var fill_c: Color = Color(0.45, 0.43, 0.5) if dark else Color(0.93, 0.9, 0.8)
	voodoo.draw_skull(table, Vector2(cx, rim_y - 0.3 * s), s, fill_c, Color(0.08, 0.05, 0.1), Color(0, 0, 0, 0.55))

# ---------- Voodoo decorations ----------

## Candles, bones, a doll and a spellbook on the dark ground, in whatever room the
## vials leave; drawn first so the vials sit in front.
func _draw_decor(lay: Dictionary, w: float, h: float) -> void:
	var rects: Array = lay.rects
	var top_free: float = h
	var bot_free: float = h
	for r in rects:
		top_free = minf(top_free, r.position.y)
		bot_free = minf(bot_free, h - r.end.y)
	if engine.has_center():
		top_free = 0.0
		bot_free = 0.0
	var flick: float = 0.75 + 0.25 * sin(clock * 11.0) * sin(clock * 7.3 + 1.0)
	for k in 2:
		var x: float = 34.0 if k == 0 else w - 34.0
		_draw_candle(Vector2(x, h - 14.0), 58.0, flick + 0.1 * sin(clock * 13.0 + k * 2.0), k)
	if bot_free > 80.0 and voodoo != null:
		voodoo.draw_crossbones(table, Vector2(w * 0.5, h - 34.0), 70.0, Color(0.93, 0.9, 0.8, 0.6), Color(0, 0, 0, 0.4))
	if top_free > 110.0:
		_draw_book(Rect2(24.0, 30.0, 84.0, 60.0))
		if voodoo != null:
			voodoo.draw_doll(table, Vector2(w - 62.0, 62.0), 78.0, Color(0.78, 0.64, 0.42, 0.9), Color(0.08, 0.05, 0.1), Color(0, 0, 0, 0.4))

func _draw_candle(base: Vector2, hgt: float, flick: float, k: int) -> void:
	table.draw_circle(base + Vector2(0, -hgt - 8.0), 70.0 * flick, Color(1.0, 0.7, 0.25, 0.05))
	table.draw_circle(base + Vector2(0, -hgt - 8.0), 38.0 * flick, Color(1.0, 0.75, 0.3, 0.08))
	table.draw_rect(Rect2(base.x - 11.0, base.y - hgt, 22.0, hgt), Color("e8dcc0"))
	table.draw_rect(Rect2(base.x - 11.0, base.y - hgt, 6.0, hgt), Color(1, 1, 1, 0.25))
	table.draw_rect(Rect2(base.x + 5.0, base.y - hgt, 6.0, hgt), Color(0, 0, 0, 0.18))
	table.draw_colored_polygon(PackedVector2Array([Vector2(base.x - 11.0, base.y - hgt), Vector2(base.x + 11.0, base.y - hgt),
		Vector2(base.x + 11.0, base.y - hgt + 9.0), Vector2(base.x + 6.0, base.y - hgt + 17.0), Vector2(base.x + 2.0, base.y - hgt + 8.0),
		Vector2(base.x - 5.0, base.y - hgt + 12.0), Vector2(base.x - 11.0, base.y - hgt + 6.0)]), Color("f3e9d0"))
	var sway: float = sin(clock * 9.0 + k * 1.7) * 2.5
	var tip := Vector2(base.x + sway, base.y - hgt - 26.0 * flick)
	var fl := PackedVector2Array([Vector2(base.x - 6.0, base.y - hgt - 3.0), Vector2(base.x - 7.0, base.y - hgt - 12.0), tip,
		Vector2(base.x + 7.0, base.y - hgt - 12.0), Vector2(base.x + 6.0, base.y - hgt - 3.0)])
	table.draw_colored_polygon(fl, Color("ff9b2e"))
	var inner := PackedVector2Array([Vector2(base.x - 3.0, base.y - hgt - 3.0), Vector2(base.x - 3.5, base.y - hgt - 9.0),
		Vector2(base.x + sway * 0.6, base.y - hgt - 18.0 * flick), Vector2(base.x + 3.5, base.y - hgt - 9.0), Vector2(base.x + 3.0, base.y - hgt - 3.0)])
	table.draw_colored_polygon(inner, Color("fff1a8"))

func _draw_book(r: Rect2) -> void:
	table.draw_rect(r, Color("5a1226"))
	table.draw_rect(r, Color("c9a23a"), false, 2.0)
	table.draw_rect(Rect2(r.position.x + 7.0, r.position.y, 4.0, r.size.y), Color(0, 0, 0, 0.35))
	table.draw_rect(Rect2(r.end.x - 4.0, r.position.y + 3.0, 4.0, r.size.y - 6.0), Color("e8dcc0"))
	var ctr: Vector2 = r.get_center() + Vector2(5.0, 0)
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = -PI / 2.0 + i * TAU / 5.0 * 2.0
		pts.append(ctr + Vector2(cos(a), sin(a)) * 16.0)
	table.draw_polyline(pts, Color("e0c36a"), 1.8, true)
	table.draw_arc(ctr, 18.0, 0.0, TAU, 20, Color("e0c36a"), 1.5)

## A padlock (with the pours left) or a cork over a vial that can't be used yet.
func _draw_lock(i: int, r: Rect2, cx: float) -> void:
	if _is_classic():
		var dim := _sb_normal.duplicate() as StyleBoxFlat
		dim.bg_color = Color(0.02, 0.02, 0.06, 0.55)
		dim.border_color = Color(0, 0, 0, 0)
		dim.shadow_size = 0
		table.draw_style_box(dim, r)
	else:
		var lhh: float = engine.cap * float(_layout().lh)
		table.draw_colored_polygon(_outline(cx, r.size.x / 2.0 - 1.0, r.end.y - 1.0, lhh + 6.0, _shape_of(i)), Color(0.02, 0.02, 0.06, 0.55))
	var is_cork := false
	for l in engine.rules.get("locks", []):
		if int(l.v) == i and l.get("cork", false):
			is_cork = true
	if is_cork and not _is_classic() and voodoo != null:
		_draw_skull_cork(cx, r.position.y + 10.0, r.size.x * 1.25, true)
		return
	if is_cork:
		var w: float = r.size.x * 0.42
		var top: float = r.position.y - 14.0
		var cork := PackedVector2Array([Vector2(cx - w, top + 18.0), Vector2(cx + w, top + 18.0), Vector2(cx + w * 0.8, top), Vector2(cx - w * 0.8, top)])
		table.draw_colored_polygon(cork, Color("b98a56"))
		table.draw_line(Vector2(cx - w * 0.7, top + 6.0), Vector2(cx + w * 0.7, top + 6.0), Color("8a6338"), 2.0)
		table.draw_line(Vector2(cx - w * 0.8, top + 12.0), Vector2(cx + w * 0.8, top + 12.0), Color("8a6338"), 2.0)
		table.draw_line(Vector2(cx - w * 0.6, top + 2.0), Vector2(cx - w * 0.6, top + 16.0), Color(1, 1, 1, 0.3), 2.0)
		return
	var s: float = minf(r.size.x * 0.6, 38.0)
	var cy: float = r.position.y + r.size.y * 0.42
	table.draw_arc(Vector2(cx, cy), s * 0.3, PI, TAU, 10, Color("e0c36a"), 4.0)
	table.draw_line(Vector2(cx - s * 0.3, cy), Vector2(cx - s * 0.3, cy + 6.0), Color("e0c36a"), 4.0)
	table.draw_line(Vector2(cx + s * 0.3, cy), Vector2(cx + s * 0.3, cy + 6.0), Color("e0c36a"), 4.0)
	table.draw_rect(Rect2(cx - s * 0.45, cy + 4.0, s * 0.9, s * 0.75), Color("c9a23a"))
	var left: int = engine.lock_pours_left(i)
	if left > 0:
		var fs: int = int(s * 0.55)
		table.draw_string(ThemeDB.fallback_font, Vector2(cx - fs * 0.3, cy + 4.0 + s * 0.6), str(left), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("3a2a05"))

## One small symbol per colour, so colour is never the only cue.
func _draw_symbol(ctr: Vector2, s: float, c: int, col: Color) -> void:
	match c % PATTERNS:
		0:
			table.draw_circle(ctr, s * 0.8, col)
		1:
			table.draw_rect(Rect2(ctr - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), col)
		2:
			table.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -s), ctr + Vector2(s, s * 0.8), ctr + Vector2(-s, s * 0.8)]), col)
		3:
			table.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -s), ctr + Vector2(s, 0), ctr + Vector2(0, s), ctr + Vector2(-s, 0)]), col)
		4:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(ctr + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.45))
			table.draw_colored_polygon(pts, col)
		5:
			table.draw_line(ctr + Vector2(-s, -s), ctr + Vector2(s, s), col, 3.0)
			table.draw_line(ctr + Vector2(-s, s), ctr + Vector2(s, -s), col, 3.0)
		6:
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(ctr + Vector2(cos(i * PI / 3.0), sin(i * PI / 3.0)) * s)
			table.draw_colored_polygon(hex, col)
		7:
			table.draw_line(ctr + Vector2(-s, 0), ctr + Vector2(s, 0), col, 3.0)
			table.draw_line(ctr + Vector2(0, -s), ctr + Vector2(0, s), col, 3.0)
		8:
			table.draw_rect(Rect2(ctr + Vector2(-s, -s * 0.28), Vector2(s * 2.0, s * 0.56)), col)
		9:
			table.draw_polyline(PackedVector2Array([ctr + Vector2(-s, s * 0.5), ctr + Vector2(0, -s * 0.5), ctr + Vector2(s, s * 0.5)]), col, 3.0)
		10:
			table.draw_arc(ctr, s * 0.8, 0.0, TAU, 14, col, 3.0)
		11:
			table.draw_circle(ctr + Vector2(-s * 0.6, 0), s * 0.38, col)
			table.draw_circle(ctr + Vector2(s * 0.6, 0), s * 0.38, col)
		12:
			for d in [-0.6, 0.0, 0.6]:
				table.draw_line(ctr + Vector2(-s * 0.8 + d * s, s * 0.8), ctr + Vector2(s * 0.2 + d * s, -s * 0.8), col, 2.5)
		_:
			var half := PackedVector2Array()
			for i in 9:
				var a2 := -PI / 2.0 + i * PI / 8.0
				half.append(ctr + Vector2(cos(a2), sin(a2)) * s)
			table.draw_colored_polygon(half, col)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.5, 64.0)
	var mid := c.size / 2.0
	for i in 3:
		var x := mid.x + (i - 1) * k * 1.2
		var r := Rect2(Vector2(x - k * 0.4, mid.y - k * 0.8), Vector2(k * 0.8, k * 1.6))
		HomeKit.glow_rect(c, r, HomeKit.CYAN, 2.5, 0.06)
		var cols := [HomeKit.PINK, HomeKit.GOLD, HomeKit.LIME]
		for j in (3 if i != 2 else 2):
			HomeKit.glow_circle(c, Vector2(x, r.end.y - k * 0.28 - j * k * 0.42), k * 0.17, cols[(i + j) % 3], 2.0, 0.6)

# ---------- central vial ----------

## Outline of the central vial in a 0..1 box: heart (Classic) or skull (Voodoo).
func _unit_shape() -> PackedVector2Array:
	var pts := PackedVector2Array()
	if _is_classic():
		for i in 56:
			var t: float = i * TAU / 56.0
			var x: float = 16.0 * pow(sin(t), 3.0)
			var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
			pts.append(Vector2((x + 16.0) / 32.0, (12.0 - y) / 29.0))
	else:
		for i in 25:
			var a: float = PI + i * PI / 24.0
			pts.append(Vector2(0.5 + cos(a) * 0.46, 0.42 + sin(a) * 0.42))
		pts.append(Vector2(0.9, 0.62))
		pts.append(Vector2(0.8, 0.78))
		pts.append(Vector2(0.74, 0.97))
		pts.append(Vector2(0.26, 0.97))
		pts.append(Vector2(0.2, 0.78))
		pts.append(Vector2(0.1, 0.62))
	return pts

func _center_poly(r: Rect2) -> PackedVector2Array:
	var key := "%s|%d|%d|%d|%d" % [skin, int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]
	if key != _cpoly_key:
		_cpoly_key = key
		_cpoly = PackedVector2Array()
		for u in _unit_shape():
			_cpoly.append(r.position + Vector2(u.x * r.size.x, u.y * r.size.y))
	return _cpoly

func _center_size() -> float:
	var sz: float = engine.center.size()
	if anim != null:
		if int(anim.leak) >= 0:
			sz += 1.0  # the leaked layer only goes once the pour is done
		if int(anim.to) == CSEngine.CENTER:
			sz = sz - int(anim.n) + int(anim.n) * clampf(float(anim.t), 0.0, 1.0)
	return sz

func _draw_center(r: Rect2) -> void:
	var poly := _center_poly(r)
	var total: float = engine.center_total()
	var need: int = engine.center_need()
	var pulse: float = 0.5 + 0.5 * sin(clock * 2.6)
	# glow in the colour it wants
	var glow: Color = _color_of(need) if need >= 0 else Color("ffd84a")
	for g in 3:
		var grow: float = 1.0 + 0.025 * (g + 1)
		var gp := PackedVector2Array()
		var mid := r.get_center()
		for p in poly:
			gp.append(mid + (p - mid) * grow)
		gp.append(gp[0])
		table.draw_polyline(gp, Color(glow, (0.30 - g * 0.08) * (0.55 + 0.45 * pulse) + flash * 0.4), 4.0 + g * 2.0, true)
	var sb_fill := Color(0.85, 0.92, 1.0, 0.12) if _is_classic() else Color(HomeKit.CYAN, 0.08)
	table.draw_colored_polygon(poly, sb_fill)
	# liquid, block by block
	var size_now := _center_size()
	var unit: float = r.size.y / total
	var seg: int = engine.center_seg
	for j in engine.center_order.size():
		var lo: float = j * seg
		var hi: float = minf((j + 1) * seg, size_now)
		if hi <= lo:
			continue
		var is_top: bool = hi >= size_now - 0.001
		var y_bot: float = r.end.y - lo * unit
		var y_top: float = r.end.y - hi * unit
		var band := PackedVector2Array()
		for s in 9:
			var u: float = s / 8.0
			var yy: float = y_top
			if is_top:
				yy += (1.2 + wobble * 4.0) * sin(clock * 4.0 + u * 7.0)
			band.append(Vector2(r.position.x - 4.0 + u * (r.size.x + 8.0), yy))
		band.append(Vector2(r.end.x + 4.0, y_bot))
		band.append(Vector2(r.position.x - 4.0, y_bot))
		var col := _color_of(int(engine.center_order[j]))
		for piece in Geometry2D.intersect_polygons(poly, band):
			if piece.size() >= 3:
				table.draw_colored_polygon(piece, col)
				table.draw_polyline(piece, col.lightened(0.3), 1.5, true)
	# patterns, one per block of liquid
	if opts.patterns:
		for j in engine.center_order.size():
			var mid_l: float = j * seg + seg * 0.5
			if mid_l <= size_now:
				var col2 := _color_of(int(engine.center_order[j]))
				var mark := Color(0, 0, 0, 0.5) if col2.get_luminance() > 0.55 else Color(1, 1, 1, 0.7)
				_draw_symbol(Vector2(r.get_center().x, r.end.y - mid_l * unit), minf(r.size.x, r.size.y) * 0.07, int(engine.center_order[j]), mark)
	var closed := poly.duplicate()
	closed.append(poly[0])
	var rim: Color = HomeKit.CLASSIC.yellow if _is_classic() else HomeKit.CYAN
	table.draw_polyline(closed, Color(1, 1, 1, 0.75) if _is_classic() else rim, 4.0, true)
	# shine
	table.draw_arc(r.position + Vector2(r.size.x * 0.28, r.size.y * 0.3), r.size.x * 0.13, PI * 0.95, PI * 1.55, 8, Color(1, 1, 1, 0.5), 4.0)
	if not _is_classic():
		for e in [0.33, 0.67]:
			table.draw_circle(r.position + Vector2(r.size.x * e, r.size.y * 0.48), r.size.x * 0.085, Color(0.02, 0.01, 0.05, 0.85))
		table.draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.5, r.size.y * 0.6),
			r.position + Vector2(r.size.x * 0.46, r.size.y * 0.68), r.position + Vector2(r.size.x * 0.54, r.size.y * 0.68)]),
			Color(0.02, 0.01, 0.05, 0.85))
	_draw_center_marker(r)

## What the big vial is asking for: the next colour, and its count.
func _draw_center_marker(r: Rect2) -> void:
	var order: Array = engine.center_order
	var y: float = r.position.y - 18.0
	var step := 34.0
	var x0: float = r.get_center().x - (order.size() - 1) * step / 2.0
	var need := engine.center_need()
	for j in order.size():
		var c: int = int(order[j])
		var ctr := Vector2(x0 + j * step, y)
		var done: bool = engine.center.size() >= (j + 1) * engine.center_seg
		var col := _color_of(c)
		var is_next: bool = need >= 0 and j == engine.center.size() / engine.center_seg
		table.draw_circle(ctr, 16.0 if is_next else 11.0, Color(col, 0.35 if done else 1.0))
		table.draw_arc(ctr, 16.0 if is_next else 11.0, 0.0, TAU, 18, Color(1, 1, 1, 0.9 if is_next else 0.4), 2.0)
		if opts.patterns:
			var mark := Color(0, 0, 0, 0.55) if col.get_luminance() > 0.55 else Color(1, 1, 1, 0.85)
			_draw_symbol(ctr, 5.0, c, mark)
	var font := ThemeDB.fallback_font
	var txt := "%d/%d" % [engine.center.size(), engine.center_total()]
	if int(opts.names) > 0 and need >= 0:
		txt += "  " + _name_text(need)
	var drain: int = int(engine.rules.get("drain", 0))
	if drain > 0 and not engine.center_full():
		txt += "   " + tr("leak in %d") % (drain - engine.moves % drain)
	table.draw_string(font, Vector2(r.get_center().x - 170.0, r.end.y + 24.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 340.0, 20, Color(1, 1, 1, 0.8))

## The thin stream of liquid from the raised vial into the one it pours into.
func _draw_stream(lay: Dictionary) -> void:
	if anim == null:
		return
	var t: float = float(anim.t)
	if t < 0.1 or t > 0.9:
		return
	var rects: Array = lay.rects
	var src: Rect2 = rects[int(anim.from)]
	var from_p := Vector2(src.get_center().x, src.position.y + (lifts[int(anim.from)] if int(anim.from) < lifts.size() else 0.0))
	var to_p: Vector2
	if int(anim.to) == CSEngine.CENTER:
		var cr: Rect2 = lay.center
		to_p = Vector2(cr.get_center().x, cr.end.y - _center_size() / engine.center_total() * cr.size.y)
	else:
		var dr: Rect2 = rects[int(anim.to)]
		to_p = Vector2(dr.get_center().x, dr.end.y - 4.0 - (engine.tubes[int(anim.to)].size() - int(anim.n) * (1.0 - t)) * float(lay.lh))
	var mid := Vector2((from_p.x + to_p.x) / 2.0, minf(from_p.y, to_p.y) - 10.0)
	var col := _color_of(int(anim.col))
	var pts := PackedVector2Array()
	for s in 9:
		var u: float = s / 8.0
		pts.append(from_p.lerp(mid, u).lerp(mid.lerp(to_p, u), u))
	table.draw_polyline(pts, col, maxf(3.0, float(lay.lh) * 0.22), true)

# ---------- particles ----------

func _init_particles() -> void:
	p_pos.resize(MAX_P)
	p_vel.resize(MAX_P)
	p_life.resize(MAX_P)
	p_max.resize(MAX_P)
	p_rad.resize(MAX_P)
	p_col.resize(MAX_P)
	p_kind.resize(MAX_P)
	for i in MAX_P:
		p_life[i] = 0.0
		p_max[i] = 1.0
	for i in MOTES:
		p_kind[i] = 2

func _spawn(pos: Vector2, vel: Vector2, life: float, rad: float, col: Color, kind: int) -> void:
	for i in range(MOTES, MAX_P):
		if p_life[i] <= 0.0:
			p_pos[i] = pos
			p_vel[i] = vel
			p_life[i] = life
			p_max[i] = life
			p_rad[i] = rad
			p_col[i] = col
			p_kind[i] = kind
			return

## Returns true while anything is still moving (so the table keeps redrawing).
func _update_particles(delta: float) -> bool:
	var alive := false
	for i in MOTES:
		p_life[i] -= delta
		if p_life[i] <= 0.0 and table.size.x > 0.0:
			p_pos[i] = Vector2(randf() * table.size.x, randf() * table.size.y)
			p_vel[i] = Vector2(randf_range(-4.0, 4.0), randf_range(-8.0, -2.0))
			p_life[i] = randf_range(6.0, 12.0)
			p_rad[i] = randf_range(1.0, 2.2)
		p_pos[i] += p_vel[i] * delta
	for i in range(MOTES, MAX_P):
		if p_life[i] > 0.0:
			alive = true
			p_life[i] -= delta
			p_pos[i] += p_vel[i] * delta
			if p_kind[i] == 0:
				p_pos[i].x += sin(p_life[i] * 9.0) * 0.4
			else:
				p_vel[i].y += 260.0 * delta
	return alive

## A few bubbles rising in the vial that just received liquid.
func _bubbles_in(r: Rect2, rise: float, col: Color) -> void:
	for k in 4:
		var x: float = r.position.x + r.size.x * randf_range(0.3, 0.7)
		var spd: float = randf_range(40.0, 70.0)
		_spawn(Vector2(x, r.end.y - 10.0 - randf() * 8.0), Vector2(0, -spd), maxf(0.15, rise / spd), randf_range(1.8, 3.4), col, 0)

func _burst(at: Vector2, order: Array) -> void:
	for k in 40:
		var a: float = randf() * TAU
		var spd: float = randf_range(90.0, 260.0)
		var c: Color = _color_of(int(order[k % order.size()])).lightened(0.3) if k % 3 != 0 else Color("ffd84a")
		_spawn(at, Vector2(cos(a), sin(a) - 0.6) * spd, randf_range(0.6, 1.2), randf_range(2.0, 4.5), c, 1)

# ---------- play ----------

func _process(delta: float) -> void:
	if table == null or engine == null:
		return
	clock += delta
	if playing and not solved_shown and not ended:
		elapsed += delta
		var limit: int = int(engine.rules.get("time", 0))
		if limit > 0:
			var sec: int = maxi(0, limit - int(elapsed))
			if sec != last_sec:
				last_sec = sec
				_render()
			if elapsed >= limit and anim == null:
				_on_failed(tr("Time's up!"))
	var dirty := false
	if lifts.size() != engine.tubes.size():
		lifts.resize(engine.tubes.size())
		dirty = true
	var lift_h: float = -float(_layout().lh) * 0.7
	for i in lifts.size():
		var target: float = lift_h if i == selected else 0.0
		if lifts[i] != target:
			lifts[i] = move_toward(lifts[i], target, absf(lift_h) * 9.0 * delta)
			dirty = true
	if anim != null:
		anim.t = float(anim.t) + delta / POUR_TIME
		dirty = true
		if float(anim.t) >= 1.0:
			_finish_pour()
	if hint_t > 0.0:
		hint_t -= delta
		dirty = true
	if toast_t > 0.0:
		toast_t -= delta
		dirty = true
	if wobble > 0.0:
		wobble = maxf(0.0, wobble - delta * 1.6)
		dirty = true
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 1.4)
		dirty = true
	if _update_particles(delta):
		dirty = true
	if engine.has_center() and engine.center.size() > 0 and playing:
		bubble_acc += delta
		if bubble_acc > 0.4:
			bubble_acc = 0.0
			var cr: Rect2 = _layout().center
			var surf: float = cr.end.y - _center_size() / engine.center_total() * cr.size.y
			_spawn(Vector2(cr.get_center().x + randf_range(-0.2, 0.2) * cr.size.x, cr.end.y - 6.0), Vector2(0, -50.0),
				maxf(0.2, (cr.end.y - 6.0 - surf) / 50.0), randf_range(1.6, 3.0), Color.WHITE, 0)
	# ambient motes and the target glow: a gentle rate, not every frame
	idle_acc += delta
	if idle_acc > 0.066:
		idle_acc = 0.0
		dirty = true
	if dirty:
		table.queue_redraw()

func _on_table_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not playing or solved_shown or ended or anim != null:
		return
	var lay := _layout()
	var rects: Array = lay.rects
	for i in rects.size():
		if rects[i].grow(8.0).has_point(event.position):
			_tap_tube(i)
			return
	if engine.has_center() and lay.center.grow(10.0).has_point(event.position):
		_tap_tube(CSEngine.CENTER)
		return
	selected = -1
	table.queue_redraw()

func _tap_tube(i: int) -> void:
	if i == CSEngine.CENTER:
		if selected >= 0 and engine.can_move(selected, CSEngine.CENTER):
			_start_pour(selected, CSEngine.CENTER)
		else:
			_sfx("invalid")
		return
	if selected < 0:
		if engine.is_locked(i):
			_sfx("invalid")
		elif not engine.tubes[i].is_empty():
			selected = i
			_sfx("tick")
	elif selected == i:
		selected = -1
		_sfx("back")
	elif engine.can_move(selected, i):
		_start_pour(selected, i)
	else:
		_sfx("invalid")
		selected = i if not engine.tubes[i].is_empty() and not engine.is_locked(i) else -1
	_render()

## The move is made at once; the picture catches up over POUR_TIME.
func _start_pour(from: int, to: int) -> void:
	var n: int = engine.pour_amount(from, to)
	var col: int = int(engine.tubes[from][engine.tubes[from].size() - 1])
	hint_t = 0.0
	engine.do_move(from, to)
	var leak: int = int(engine.history[engine.history.size() - 1][3])
	anim = {"from": from, "to": to, "n": n, "col": col, "t": 0.0, "leak": leak}
	selected = -1
	_skin_sfx("glug", "place")
	_save_game()
	_render()

func _finish_pour() -> void:
	var a = anim
	anim = null
	wobble = 1.0
	var lay := _layout()
	var col := _color_of(int(a.col))
	if int(a.leak) >= 0:
		# pressure: a layer of the big vial pops back into a small one
		var lr: Rect2 = lay.rects[int(a.leak)]
		var cr2: Rect2 = lay.center
		_burst(cr2.get_center(), [int(engine.tubes[int(a.leak)][engine.tubes[int(a.leak)].size() - 1])])
		_bubbles_in(lr, lr.size.y * 0.5, _color_of(int(engine.tubes[int(a.leak)][engine.tubes[int(a.leak)].size() - 1])))
		_sfx("whoosh")
	if int(a.to) == CSEngine.CENTER:
		var cr: Rect2 = lay.center
		_bubbles_in(cr, cr.size.y * 0.5, col)
		if engine.center_full():
			flash = 1.0
			_burst(cr.get_center(), engine.center_order)
			_sfx("powerup")
	else:
		var r: Rect2 = lay.rects[int(a.to)]
		_bubbles_in(r, r.size.y * 0.5, col)
	_render()
	if engine.solved():
		var t := create_tween()
		t.tween_interval(0.9 if engine.has_center() else 0.3)
		t.tween_callback(_on_solved)
	elif engine.failed():
		_on_failed(tr("Out of moves!"))

func _render() -> void:
	var kind: String = engine.rules.get("kind", "")
	if engine.level_no > 0:
		var mv: String = tr("Moves: %d") % engine.moves
		if int(engine.rules.get("cap_moves", 0)) > 0:
			mv = tr("Moves: %d / %d") % [engine.moves, int(engine.rules.cap_moves)]
		status_label.text = tr("Level %d") % engine.level_no + "    " + mv + "    " + tr("Par %d") % engine.par
		if int(engine.rules.get("time", 0)) > 0:
			status_label.text += "    ⏱ " + _clock_text()
	else:
		status_label.text = tr("Moves: %d") % engine.moves + "    " + tr("%s — %d colors") % [tr(LEVEL_NAMES[engine.level]), engine.color_count()]
	banner_label.visible = kind != ""
	if kind != "":
		banner_label.text = _kind_title(kind) + " — " + _kind_hint(kind)
		banner_label.add_theme_color_override("font_color", _kind_color(kind).lightened(0.25))
	var locked: bool = solved_shown or ended or anim != null
	undo_btn.disabled = not engine.can_undo() or locked
	var campaign: bool = engine.level_no > 0
	hint_btn.text = tr("💡 Hint (%d)") % int(progress.hints) if campaign else tr("💡 Hint")
	hint_btn.disabled = locked
	tube_btn.text = tr("➕ Tube (%d)") % int(progress.vials) if campaign else tr("➕ Tube")
	tube_btn.disabled = not engine.can_add_tube() or locked or (campaign and int(progress.vials) <= 0)
	reset_btn.disabled = (engine.moves == 0 and engine.extra_used == 0) or locked
	# a padlock opened or a cork popped since the last look
	for i in engine.tubes.size():
		var now: bool = engine.is_locked(i)
		if i < was_locked.size() and was_locked[i] and not now:
			_unlock_effect(i)
	was_locked.resize(engine.tubes.size())
	for i in engine.tubes.size():
		was_locked[i] = engine.is_locked(i)
	table.queue_redraw()

func _clock_text() -> String:
	var left: int = maxi(0, int(engine.rules.get("time", 0)) - int(elapsed))
	return "%d:%02d" % [left / 60, left % 60]

func _unlock_effect(i: int) -> void:
	var lay := _layout()
	if i >= lay.rects.size():
		return
	var r: Rect2 = lay.rects[i]
	for k in 10:
		var a: float = randf_range(-PI * 0.9, -PI * 0.1)
		_spawn(Vector2(r.get_center().x, r.position.y), Vector2(cos(a), sin(a)) * randf_range(60.0, 150.0), randf_range(0.4, 0.8), randf_range(2.0, 3.5), Color("e0c36a"), 1)
	_skin_sfx("cork_pop", "pickup")

## 💡 The solver's next pour, shown as two glowing vials. Costs a hint in the
## campaign (none left: say how to earn more); free in the quick puzzles.
func _on_hint() -> void:
	if anim != null or solved_shown or ended or not playing:
		return
	if engine.level_no > 0 and int(progress.hints) <= 0:
		_toast(tr("No hints left. Win levels with 3 stars to earn more."))
		return
	var h: Array = engine.hint()
	if h.is_empty():
		_toast(tr("No hint found. Try undoing a move."))
		return
	hint_from = int(h[0])
	hint_to = int(h[1])
	hint_t = 3.5
	selected = -1
	if engine.level_no > 0:
		progress.hints = int(progress.hints) - 1
		_save_progress()
	_sfx("powerup")
	_render()

func _toast(text: String) -> void:
	toast_text = text
	toast_t = 2.6
	_sfx("invalid")
	table.queue_redraw()

func _on_undo() -> void:
	if anim == null and engine.undo():
		selected = -1
		_sfx("back")
		_save_game()
		_render()

func _on_add_tube() -> void:
	if anim == null and engine.can_add_tube() and (engine.level_no == 0 or int(progress.vials) > 0) and engine.add_tube():
		if engine.level_no > 0:
			progress.vials = int(progress.vials) - 1
			_save_progress()
		_sfx("powerup")
		_save_game()
		_render()

func _on_reset() -> void:
	if anim != null:
		return
	engine.reset()
	selected = -1
	_sfx("back")
	_save_game()
	_render()

## Out of moves or time: the level is over (nothing is kept, the save goes).
func _on_failed(reason: String) -> void:
	if ended or solved_shown:
		return
	ended = true
	selected = -1
	_sfx("lose")
	SaveUtil.delete(SAVE_PATH)
	fail_dialog.get_meta("message_label").text = reason
	fail_dialog.visible = true
	_render()

func _on_solved() -> void:
	if solved_shown:
		return
	solved_shown = true
	_skin_sfx("stinger", "win")
	var msg: String = tr("Moves: %d") % engine.moves
	var buttons: Array = end_dialog.find_children("*", "Button", true, false)
	if engine.level_no > 0:
		var stars: int = engine.stars_for(engine.moves)
		var key := str(engine.level_no)
		var prev: Dictionary = progress.best.get(key, {})
		var first: bool = prev.is_empty()
		var prev_stars: int = int(prev.get("stars", 0))
		var best_time: int = int(prev.get("time", 999999))
		if first or engine.moves < int(prev.get("moves", 99999)):
			progress.best[key] = {"moves": engine.moves, "stars": maxi(stars, prev_stars), "time": mini(int(elapsed), best_time)}
		else:
			prev["stars"] = maxi(stars, prev_stars)
			prev["time"] = mini(int(elapsed), best_time)
		progress.level = maxi(int(progress.level), engine.level_no + 1)
		var earned := _earn(first, stars, prev_stars)
		_save_progress()
		msg = "%s\n%s  (%s)" % ["★".repeat(stars) + "☆".repeat(3 - stars), msg, tr("Par %d") % engine.par]
		if earned != "":
			msg += "\n" + earned
		if info:
			info.add("Puzzles solved")
			var total_stars := 0
			for k in progress.best:
				total_stars += int(progress.best[k].get("stars", 0))
			info.high("Levels cleared", progress.best.size())
			info.high("Total stars", total_stars)
			info.high("Highest level", engine.level_no)
			if stars == 3 and prev_stars < 3:
				info.add("3-star levels")
			if first and CSEngine.special_kind(engine.level_no) != "":
				info.add("Special levels cleared")
				if CSEngine.special_kind(engine.level_no) == "boss":
					info.add("Bosses beaten")
			if elapsed >= 3.0:
				info.low("Fastest level (seconds)", int(elapsed))
			info.celebrate(tr("Sorted!"))
		_sync_up()
		if buttons.size() > 0:
			buttons[0].text = tr("Next level")
	else:
		var name: String = LEVEL_NAMES[engine.level]
		if info:
			info.add("Puzzles solved")
			info.best("Fewest moves (%s)" % name, engine.moves, true)
			info.celebrate(tr("Sorted!"))
		if buttons.size() > 0:
			buttons[0].text = tr("Next puzzle")
	SaveUtil.delete(SAVE_PATH)
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

## Cloud copy of the campaign position, no extra tables: the hub's `scores` rows keep
## the higher number, so the furthest level reached under "color_sort_level" restores
## the Play button on a new phone. (Stars and stock stay on the device.)
const CLOUD_LEVEL := "color_sort_level"

func _auth() -> Node:
	var a := get_node_or_null("/root/Auth")
	return a if a and a.has_method("fetch_my_scores") and a.has_method("submit_score") and a.has_method("is_logged_in") else null

func _sync_up() -> void:
	var a := _auth()
	if a and a.is_logged_in():
		a.submit_score(CLOUD_LEVEL, int(progress.level))

func _sync_down() -> void:
	var a := _auth()
	if a and a.is_logged_in():
		a.fetch_my_scores(_on_cloud_scores)

func _on_cloud_scores(rows: Variant) -> void:
	if not (rows is Array):
		return
	for r in rows:
		if r is Dictionary and str(r.get("game", "")) == CLOUD_LEVEL:
			var cloud: int = int(r.get("score", 0))
			if cloud > int(progress.level):
				progress.level = cloud
				_save_progress()
			elif cloud < int(progress.level):
				_sync_up()
			return
	if int(progress.level) > 1:
		_sync_up()

## Rewards for a cleared level: a hint for a first 3 stars, two for a first clear of
## a special level, an extra vial for every fifth level, a daily hint. Returns the text.
func _earn(first: bool, stars: int, prev_stars: int) -> String:
	var hints := 0
	var vials := 0
	if stars == 3 and prev_stars < 3:
		hints += 1
	if first and CSEngine.special_kind(engine.level_no) != "":
		hints += 2
	if first and engine.level_no % 5 == 0:
		vials += 1
	var today: int = int(Time.get_unix_time_from_system() / 86400.0)
	var daily := false
	if int(progress.day) != today:
		progress.day = today
		hints += 1
		daily = true
	progress.hints = mini(MAX_HINTS, int(progress.hints) + hints)
	progress.vials = mini(MAX_VIALS_STOCK, int(progress.vials) + vials)
	var parts: Array = []
	if hints > 0:
		parts.append(tr("+%d 💡") % hints)
	if vials > 0:
		parts.append(tr("+%d ➕") % vials)
	if parts.is_empty():
		return ""
	return "  ".join(parts) + ("   " + tr("(daily bonus included)") if daily else "")

## 🗺 Every level in groups by tier: stars earned, the next one to play, the rest locked.
func _show_levels() -> void:
	var parts: Array = home._overlay(tr("🗺 Levels"), HomeKit.CYAN, true)
	parts[0].visible = true
	var body: VBoxContainer = parts[1]
	var stars_total := 0
	var cleared := 0
	for k in progress.best:
		stars_total += int(progress.best[k].get("stars", 0))
		cleared += 1
	body.add_child(home._row(tr("Levels cleared"), str(cleared), HomeKit.WHITE, HomeKit.LIME, true))
	body.add_child(home._row(tr("Stars"), "%d ★" % stars_total, HomeKit.WHITE, HomeKit.GOLD))
	body.add_child(home._row(tr("Hints"), "%d 💡" % int(progress.hints), HomeKit.WHITE, HomeKit.CYAN))
	body.add_child(home._row(tr("Extra vials"), "%d ➕" % int(progress.vials), HomeKit.WHITE, HomeKit.PINK))
	var last: int = int(progress.level) + 14
	last += (5 - last % 5) % 5
	var starts: Array = CSEngine.TIER_START
	for t in starts.size():
		var a: int = int(starts[t])
		if a > last:
			break
		var b: int = int(starts[t + 1]) - 1 if t + 1 < starts.size() else last
		b = mini(b, last)
		body.add_child(home._section("%s  %d–%d" % [tr(CSEngine.TIER_NAMES[t]), a, b]))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		body.add_child(grid)
		for n in range(a, b + 1):
			grid.add_child(_level_cell(n))

func _level_cell(n: int) -> Button:
	var key := str(n)
	var done: bool = progress.best.has(key)
	var open: bool = n <= int(progress.level)
	var stars: int = int(progress.best[key].get("stars", 0)) if done else 0
	var kind: String = CSEngine.special_kind(n)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var second := "🔒"
	if done:
		second = "★".repeat(stars) + "☆".repeat(3 - stars)
	elif open:
		second = "◆" if kind != "" else "▶"
	b.text = "%d\n%s" % [n, second]
	b.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	var edge: Color = _kind_color(kind) if kind != "" else HomeKit.CYAN
	sb.border_color = edge if open else Color(1, 1, 1, 0.15)
	sb.bg_color = Color(edge, 0.30) if n == int(progress.level) else (Color(0.1, 0.2, 0.35, 0.9) if done else Color(0.05, 0.08, 0.15, 0.9))
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, sb)
	b.disabled = not open
	b.pressed.connect(_play_level.bind(n))
	return b

func _play_level(n: int) -> void:
	home.start_mode({"text": "Play", "key": "campaign", "action": _new_level.bind(n)})

# ---------- Landing (home_kit.gd) ----------

func _new_game(level: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_game(level)
	_begin_play()

func _start_campaign() -> void:
	_new_level(int(progress.level))

func _new_level(n: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.load_level(n)
	_begin_play()

## The dialog's first button: the next campaign level, or a new random puzzle.
func _next_puzzle() -> void:
	if engine.level_no > 0:
		_new_level(engine.level_no + 1)
	else:
		_restart()

func _restart() -> void:
	if engine.level_no > 0:
		_new_level(engine.level_no)
	else:
		_new_game(engine.level)

func _begin_play() -> void:
	playing = true
	solved_shown = false
	ended = false
	selected = -1
	anim = null
	last_sec = -1
	was_locked = []
	fail_dialog.visible = false
	elapsed = 0.0
	wobble = 0.0
	flash = 0.0
	_lay_key = ""
	end_dialog.visible = false
	lifts.resize(engine.tubes.size())
	for i in lifts.size():
		lifts[i] = 0.0
	_render()
	_save_game()

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

# ---------- save / resume ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or not playing or solved_shown or ended or engine.tubes.is_empty():
		return
	var d: Dictionary = engine.to_dict()
	d["elapsed"] = int(elapsed)
	SaveUtil.write(SAVE_PATH, d)

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var lvl: int = int(d.get("level_no", 0))
	var mv: String = tr("Moves: %d") % int(d.get("moves", 0))
	return (tr("Level %d") % lvl + " · " + mv) if lvl > 0 else mv

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d) or engine.solved():
		_new_game(0)
		return
	_begin_play()
	elapsed = float(d.get("elapsed", 0))
	_render()

## Skin sound: the Voodoo skin's own (cork pop, glug, stinger), else the library one.
func _skin_sfx(potion: String, plain: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s == null:
		return
	if not _is_classic() and POTION_SOUNDS.has(potion) and s.has_method("_render") and s.has_method("play_stream"):
		if not _potion_cache.has(potion):
			_potion_cache[potion] = s._render(POTION_SOUNDS[potion])
		var st = _potion_cache[potion]
		if st != null:
			s.play_stream(st, 0.0, randf_range(0.96, 1.04), "game")
			return
	s.play(plain)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
