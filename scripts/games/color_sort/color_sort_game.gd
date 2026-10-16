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
const PATTERNS := 14
const POUR_TIME := 0.32
const MAX_P := 96
const MOTES := 12

var info = null  # GameInfo; null on apps without it, so guard every use
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
var selected: int = -1
var playing: bool = false
var solved_shown: bool = false

## Player choices (OPTS_PATH): colour-blind palette, pattern overlay.
var opts: Dictionary = {"safe": false, "patterns": true}
## Campaign progress (PROGRESS_PATH): next level, best result per level.
var progress: Dictionary = {"level": 1, "best": {}}

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
	_load_opts()
	_load_progress()
	_init_particles()
	_build_ui()
	_calm_music()

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
	tube_btn = _button(tr("➕ Tube"), _on_add_tube)
	row.add_child(tube_btn)
	reset_btn = _button(tr("⟲ Reset"), _on_reset)
	row.add_child(reset_btn)

	end_dialog = UI.build_dialog(tr("Sorted!"), [
		{"text": tr("Next puzzle"), "action": _next_puzzle},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = [{"text": "▶ Campaign", "sub": tr("Level %d") % int(progress.level), "key": "campaign",
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
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Puzzles solved",
		"board_note": "Puzzles solved at any level.",
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

func _on_pick_palette(i: int) -> void:
	opts.safe = i == 1
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

func _save_opts() -> void:
	SaveUtil.write(OPTS_PATH, opts)

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	if d is Dictionary:
		progress.level = maxi(1, int(d.get("level", 1)))
		var b = d.get("best", {})
		progress.best = b if b is Dictionary else {}

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
	var cols_max: int = maxi(3, int((w - 16.0) / 64.0))
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
	var rects: Array = []
	rects.resize(n)
	var y: float = 0.0
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
				rects[g[first + c]] = Rect2(x0 + c * cell_w, y + band_h - vh - 4.0, vw, vh)
			y += band_h
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
	table.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([c1, c1, c2, c2]))
	for i in MOTES:
		if p_life[i] > 0.0:
			var a: float = minf(1.0, p_life[i] / 2.0) * 0.18
			table.draw_circle(p_pos[i], p_rad[i], Color(1, 1, 1, a))
	var rects: Array = lay.rects
	for i in rects.size():
		_draw_vial(i, rects[i], lay)
	if engine.has_center():
		_draw_center(lay.center)
	_draw_stream(lay)
	for i in range(MOTES, MAX_P):
		if p_life[i] > 0.0:
			var f: float = p_life[i] / p_max[i]
			if p_kind[i] == 0:
				table.draw_arc(p_pos[i], p_rad[i], 0.0, TAU, 10, Color(1, 1, 1, 0.5 * f + 0.1), 1.5)
			else:
				table.draw_circle(p_pos[i], p_rad[i] * (0.4 + f * 0.6), Color(p_col[i], f))

## The layers of vial i to show: [colour, lo, hi] in layer units (so a pour can be
## drawn half done), same colours merged into one block.
func _blocks(i: int) -> Array:
	var t: Array = engine.tubes[i]
	var layers: Array = []
	var shown_n: int = t.size()
	var grow_from: int = -1
	var grow_n: int = 0
	var prog: float = 1.0
	if anim != null:
		prog = clampf(float(anim.t), 0.0, 1.0)
		if int(anim.to) == i:
			grow_from = t.size() - int(anim.n)
			grow_n = int(anim.n)
	for k in shown_n:
		var hi: float = k + 1.0
		var lo: float = float(k)
		if grow_from >= 0 and k >= grow_from:
			hi = minf(k + 1.0, grow_from + grow_n * prog)
			if hi <= lo:
				continue
		layers.append([int(t[k]), lo, hi])
	if anim != null and int(anim.from) == i:
		for j in int(anim.n):
			var lo2: float = t.size() + j
			var hi2: float = minf(lo2 + 1.0, t.size() + int(anim.n) * (1.0 - prog))
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
	table.draw_style_box(_sb_selected if is_sel else _sb_normal, r)
	var cx: float = r.position.x + r.size.x / 2.0
	var rad: float = r.size.x / 2.0 - 4.0
	var yb: float = r.end.y - 4.0
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
		var poly := _band(cx, rad, yb, y_top, y_bot, amp, clock * 5.0 + i)
		if poly.size() >= 3:
			table.draw_colored_polygon(poly, col)
			if y_bot - y_top > 10.0:
				table.draw_line(Vector2(cx - rad * 0.55, y_top + 5.0), Vector2(cx - rad * 0.55, y_bot - 5.0), Color(1, 1, 1, 0.22), 3.0)
				table.draw_line(Vector2(cx + rad * 0.7, y_top + 5.0), Vector2(cx + rad * 0.7, y_bot - 5.0), Color(0, 0, 0, 0.14), 3.0)
			if b == top_i:
				var surf := PackedVector2Array()
				for j in 7:
					surf.append(poly[j])
				table.draw_polyline(surf, col.lightened(0.45), 2.0)
	# patterns, one per whole layer
	if opts.patterns:
		var t: Array = engine.tubes[i]
		for k in t.size():
			if anim != null and int(anim.to) == i and k >= t.size() - int(anim.n) and float(anim.t) < 1.0:
				continue
			var col2 := _color_of(int(t[k]))
			var mark := Color(0, 0, 0, 0.55) if col2.get_luminance() > 0.55 else Color(1, 1, 1, 0.8)
			_draw_symbol(Vector2(cx, yb - (k + 0.5) * lh), minf(lh, rad * 2.0) * 0.21, int(t[k]), mark)
	# glass shine
	table.draw_line(Vector2(cx - rad + 5.0, r.position.y + 12.0), Vector2(cx - rad + 5.0, yb - rad), Color(1, 1, 1, 0.3), 3.0, true)
	table.draw_arc(Vector2(cx, yb - rad), rad * 0.72, PI * 0.6, PI * 0.9, 6, Color(1, 1, 1, 0.28), 2.5)
	table.draw_line(Vector2(r.position.x - 3.0, r.position.y + 6.0), Vector2(r.end.x + 3.0, r.position.y + 6.0), Color(1, 1, 1, 0.5), 3.0)

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
	if anim != null and int(anim.to) == CSEngine.CENTER:
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
	table.draw_string(font, Vector2(r.get_center().x - 40.0, r.end.y + 24.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 20, Color(1, 1, 1, 0.8))

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
	if playing and not solved_shown:
		elapsed += delta
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
	if not playing or solved_shown or anim != null:
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
		if not engine.tubes[i].is_empty():
			selected = i
			_sfx("tick")
	elif selected == i:
		selected = -1
		_sfx("back")
	elif engine.can_move(selected, i):
		_start_pour(selected, i)
	else:
		_sfx("invalid")
		selected = i if not engine.tubes[i].is_empty() else -1
	_render()

## The move is made at once; the picture catches up over POUR_TIME.
func _start_pour(from: int, to: int) -> void:
	var n: int = engine.pour_amount(from, to)
	var col: int = int(engine.tubes[from][engine.tubes[from].size() - 1])
	engine.do_move(from, to)
	anim = {"from": from, "to": to, "n": n, "col": col, "t": 0.0}
	selected = -1
	_sfx("place")
	_save_game()
	_render()

func _finish_pour() -> void:
	var a = anim
	anim = null
	wobble = 1.0
	var lay := _layout()
	var col := _color_of(int(a.col))
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

func _render() -> void:
	if engine.level_no > 0:
		status_label.text = tr("Level %d") % engine.level_no + "    " + tr("Moves: %d") % engine.moves + "    " + tr("Par %d") % engine.par
	else:
		status_label.text = tr("Moves: %d") % engine.moves + "    " + tr("%s — %d colors") % [tr(LEVEL_NAMES[engine.level]), engine.color_count()]
	var locked: bool = solved_shown or anim != null
	undo_btn.disabled = not engine.can_undo() or locked
	tube_btn.disabled = not engine.can_add_tube() or locked
	reset_btn.disabled = (engine.moves == 0 and engine.extra_used == 0) or locked
	table.queue_redraw()

func _on_undo() -> void:
	if anim == null and engine.undo():
		selected = -1
		_sfx("back")
		_save_game()
		_render()

func _on_add_tube() -> void:
	if anim == null and engine.add_tube():
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

func _on_solved() -> void:
	if solved_shown:
		return
	solved_shown = true
	_sfx("win")
	var msg: String = tr("Moves: %d") % engine.moves
	var buttons: Array = end_dialog.find_children("*", "Button", true, false)
	if engine.level_no > 0:
		var stars: int = engine.stars_for(engine.moves)
		var key := str(engine.level_no)
		var prev: Dictionary = progress.best.get(key, {})
		if prev.is_empty() or engine.moves < int(prev.get("moves", 99999)):
			progress.best[key] = {"moves": engine.moves, "stars": maxi(stars, int(prev.get("stars", 0))), "time": int(elapsed)}
		else:
			prev["stars"] = maxi(stars, int(prev.get("stars", 0)))
		progress.level = maxi(int(progress.level), engine.level_no + 1)
		_save_progress()
		msg = "%s\n%s  (%s)" % ["★".repeat(stars) + "☆".repeat(3 - stars), msg, tr("Par %d") % engine.par]
		if info:
			info.add("Puzzles solved")
			info.celebrate(tr("Sorted!"))
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
	selected = -1
	anim = null
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
	if engine == null or not playing or solved_shown or engine.tubes.is_empty():
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

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
