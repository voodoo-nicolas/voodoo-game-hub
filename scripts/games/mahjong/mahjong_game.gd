extends Control

## Mahjong Solitaire: clear the stacked tiles in matching pairs. Only free
## tiles (nothing on top, left or right side open) can be taken.

const MjEngine = preload("res://scripts/games/mahjong/mahjong_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/mahjong/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/mahjong/mahjong_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://mahjong_save.json"

const LEVELS := ["Easy", "Normal", "Hard"]
const KINDS := [18, 24, 36]
const SYMBOLS := ["🍎", "🍊", "🍋", "🍉", "🍇", "🍓", "🍒", "🥝", "🌶", "🥕", "🌽", "🍄",
	"🌵", "🌻", "🌙", "⭐", "☀", "⚡", "🔥", "💧", "❄", "🍀", "🎲", "🎯",
	"🎸", "🎈", "🎁", "💎", "🔔", "⚓", "🚀", "👑", "💀", "🦋", "🐟", "🐙"]
## Rim colour per symbol group, so similar fruit still read apart.
const RIMS := [Color("29e6ff"), Color("ff2bd6"), Color("7dff3a"), Color("ffae2b"), Color("9b4dff"), Color("ff4f9a")]
const ASPECT := 1.28  # tile height / width
const DEPTH := 0.34  # tile thickness and per-layer lift, in half-tile units

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var level: int = 0
var started := false
var solved := false
var elapsed: float = 0.0
var selected: int = -1
var hinted: Array = []
var used_hint := false

var board: Control
var status_label: Label
var end_dialog: Control
var stuck_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/mahjong/mahjong_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = MjEngine.new()
	_build_ui()
	_deal(0)
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
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
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("Mahjong")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.LIME.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.LIME, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 30)
	root.add_child(bm)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	bm.add_child(row)
	for b in [["↶ " + tr("Undo"), _undo], ["💡 " + tr("Hint"), _hint], ["🔀 " + tr("Shuffle"), _shuffle]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(170, 64)
		btn.pressed.connect(b[1])
		row.add_child(btn)

	end_dialog = UI.build_dialog("", [
		{"text": tr("New game"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	stuck_dialog = UI.build_dialog(tr("No more matching pairs."), [
		{"text": "🔀 " + tr("Shuffle"), "action": _shuffle},
		{"text": "↶ " + tr("Undo"), "action": _undo},
		{"text": tr("New game"), "action": _restart},
	])
	add_child(stuck_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": LEVELS[i], "sub": tr("%d tiles") % _count(i), "row": "levels",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Match free tiles in pairs until the table is clear.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Games solved",
		"board_note": "Tables cleared, any layout.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.975)  # under the buttons
	add_child(drawer)

static func _count(kind: int) -> int:
	var n := 0
	for l in MjEngine.layout(kind):
		n += l.size()
	return n

# ---------- game flow ----------

func _new_game(lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_deal(lvl)

func _restart() -> void:
	_deal(level)

func _deal(lvl: int) -> void:
	level = lvl
	engine.deal(lvl, KINDS[lvl], rng)
	started = true
	solved = false
	elapsed = 0.0
	selected = -1
	hinted = []
	used_hint = false
	end_dialog.visible = false
	stuck_dialog.visible = false
	_status()
	board.queue_redraw()

func _process(delta: float) -> void:
	if started and not solved:
		var before := int(elapsed)
		elapsed += delta
		if int(elapsed) != before:
			_status()

func _status() -> void:
	var s := int(elapsed)
	status_label.text = tr("%s   ·   Tiles left: %d   ·   %d:%02d") % [tr(LEVELS[level]), engine.remaining(), s / 60, s % 60]

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if solved:
		return
	var i := _tile_at(event.position)
	if i < 0:
		return
	if not engine.is_free(i):
		_sfx("invalid")
		return
	hinted = []
	if selected == i:
		selected = -1
	elif selected >= 0 and engine.tiles[selected].s == engine.tiles[i].s:
		engine.remove_pair(selected, i)
		selected = -1
		_sfx("merge")
		_after_pair()
	else:
		selected = i
		_sfx("toggle")
	board.queue_redraw()

func _after_pair() -> void:
	_status()
	if engine.won():
		_on_won()
	elif engine.hint().is_empty():
		stuck_dialog.visible = true

func _on_won() -> void:
	solved = true
	SaveUtil.delete(SAVE_PATH)
	var s := int(elapsed)
	var msg := tr("Table cleared!") + "\n" + tr("Time: %d:%02d") % [s / 60, s % 60]
	if info:
		info.add("Games solved")
		if not used_hint and engine.shuffles == 0:
			info.add("Solved without help")
		if info.low("Best time (%s)" % LEVELS[level], s):
			msg += "\n" + tr("New best time!")
		info.celebrate(tr("Table cleared!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

func _undo() -> void:
	stuck_dialog.visible = false
	if engine.undo():
		selected = -1
		hinted = []
		_sfx("back")
		_status()
		board.queue_redraw()

func _hint() -> void:
	hinted = engine.hint()
	used_hint = true
	if hinted.is_empty():
		stuck_dialog.visible = true
	else:
		_sfx("notify")
	board.queue_redraw()

func _shuffle() -> void:
	stuck_dialog.visible = false
	if engine.remaining() == 0:
		return
	engine.reshuffle(rng)
	selected = -1
	hinted = []
	_sfx("card_shuffle")
	board.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var minx := 999
	var maxx := -999
	var miny := 999
	var maxy := -999
	for t in engine.tiles:
		minx = mini(minx, t.x)
		maxx = maxi(maxx, t.x + 2)
		miny = mini(miny, t.y)
		maxy = maxi(maxy, t.y + 2)
	var zmax := 0
	for t in engine.tiles:
		zmax = maxi(zmax, t.z)
	var extra: float = (zmax + 2.0) * DEPTH  # layer lift (up-left) plus tile thickness (down-right)
	var span_x: float = maxx - minx + 0.6 + extra
	var span_y: float = maxy - miny + 0.6 + extra / ASPECT
	var hu: float = minf((board.size.x - 24.0) / span_x, (board.size.y - 16.0) / (span_y * ASPECT))
	var hv: float = hu * ASPECT
	var lead: float = zmax * DEPTH  # room on the left/top for raised layers
	var o := Vector2((board.size.x - span_x * hu) / 2.0 - minx * hu + 0.3 * hu + lead * hu,
		(board.size.y - span_y * hv) / 2.0 - miny * hv + 0.3 * hv + lead * hu)
	return {"hu": hu, "hv": hv, "o": o}

func _rect_of(i: int, g: Dictionary) -> Rect2:
	var t: Dictionary = engine.tiles[i]
	var lift: float = t.z * g.hu * DEPTH
	return Rect2(g.o + Vector2(t.x * g.hu - lift, t.y * g.hv - lift), Vector2(g.hu * 2.0, g.hv * 2.0))

func _order() -> Array:
	var ids: Array = []
	for i in engine.tiles.size():
		if engine.tiles[i].on:
			ids.append(i)
	ids.sort_custom(func(a, b):
		var ta: Dictionary = engine.tiles[a]
		var tb: Dictionary = engine.tiles[b]
		if ta.z != tb.z:
			return ta.z < tb.z
		if ta.x != tb.x:
			return ta.x < tb.x
		return ta.y < tb.y)
	return ids

func _tile_at(p: Vector2) -> int:
	var g := _geom()
	var ids := _order()
	for k in range(ids.size() - 1, -1, -1):
		if _rect_of(ids[k], g).has_point(p):
			return ids[k]
	return -1

## Look (STANDARDS §9): "classic" = ivory tiles (default); "voodoo" = the neon
## board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: ColorRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if board:
		board.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _draw_board() -> void:
	if engine.tiles.is_empty():
		return
	var g := _geom()
	var on := {}
	for i in engine.tiles.size():
		if engine.tiles[i].on:
			on[i] = true
	for i in _order():
		var t: Dictionary = engine.tiles[i]
		var r := _rect_of(i, g).grow(-1.5)
		var free: bool = engine._free_among(i, on)
		var hot: bool = i == selected or i in hinted
		_draw_tile(board, r, int(t.s), free, hot, i == selected, g.hu)

## One thick tile: a jade back slab and an ivory side layer give the 3D depth, the face sits on top.
func _draw_tile(cv: Control, r: Rect2, sym: int, free: bool, hot: bool, is_sel: bool, hu: float) -> void:
	var depth: float = hu * DEPTH
	var rad := int(hu * 0.28)
	var classic := _is_classic()
	var rim: Color = RIMS[sym % RIMS.size()]
	var back: Color
	var side: Color
	if classic:
		back = Color("2f7d5a") if free else Color("3d5a4c")
		side = Color("e6dcc3") if free else Color("a9a28f")
	else:
		back = Color(rim, 0.55 if free else 0.18).darkened(0.35)
		side = Color(0.1, 0.12, 0.24) if free else Color(0.05, 0.06, 0.12)
	cv.draw_rect(Rect2(r.position + Vector2(depth * 1.05, depth * 1.2), r.size), Color(0, 0, 0, 0.35))  # cast shadow
	cv.draw_style_box(_slab(back, rad), Rect2(r.position + Vector2(depth * 0.55, depth), r.size))
	cv.draw_style_box(_slab(side, rad), Rect2(r.position + Vector2(depth * 0.3, depth * 0.55), r.size))
	var face := StyleBoxFlat.new()
	if classic:
		face.bg_color = Color("fbf7ec") if free else Color("c9c3b2")
		face.border_color = Color("8a8168")
	else:
		face.bg_color = Color(0.08, 0.09, 0.18) if free else Color(0.04, 0.045, 0.09)
		face.border_color = Color(rim, 0.95 if free else 0.35)
	face.set_corner_radius_all(rad)
	face.set_border_width_all(2)
	if hot:
		face.border_color = HomeKit.GOLD if is_sel else HomeKit.LIME
		face.set_border_width_all(4)
		face.shadow_color = Color(face.border_color, 0.55)
		face.shadow_size = 10
		if classic:
			face.bg_color = Color("fff3c4") if is_sel else Color("e9f7d6")
	cv.draw_style_box(face, r)
	if classic and free:
		cv.draw_line(r.position + Vector2(rad, 3), r.position + Vector2(r.size.x - rad, 3), Color(1, 1, 1, 0.8), 2.0)
	_draw_face(cv, r, sym, free)

func _slab(c: Color, rad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(rad)
	return sb

## Ink colours: traditional blue / red / green on ivory; neon on the voodoo skin.
func _ink(k: int, free: bool) -> Color:
	var cols: Array = [Color("1f4fa8"), Color("c42222"), Color("1b7a3e")]
	if not _is_classic():
		cols = [Color("29e6ff"), Color("ff2bd6"), Color("7dff3a")]
	var c: Color = cols[k % 3]
	return c if free else c.lerp(Color(0.5, 0.5, 0.5), 0.55)

const DOT_POS := {
	1: [[0, 0]], 2: [[0, -0.55], [0, 0.55]], 3: [[-0.55, -0.7], [0, 0], [0.55, 0.7]],
	4: [[-0.5, -0.55], [0.5, -0.55], [-0.5, 0.55], [0.5, 0.55]],
	5: [[-0.5, -0.55], [0.5, -0.55], [0, 0], [-0.5, 0.55], [0.5, 0.55]],
	6: [[-0.5, -0.8], [0.5, -0.8], [-0.5, 0], [0.5, 0], [-0.5, 0.8], [0.5, 0.8]],
	7: [[-0.6, -0.9], [0, -0.65], [0.6, -0.4], [-0.5, 0.35], [0.5, 0.35], [-0.5, 0.9], [0.5, 0.9]],
	8: [[-0.5, -0.9], [0.5, -0.9], [-0.5, -0.3], [0.5, -0.3], [-0.5, 0.3], [0.5, 0.3], [-0.5, 0.9], [0.5, 0.9]],
	9: [[-0.6, -0.8], [0, -0.8], [0.6, -0.8], [-0.6, 0], [0, 0], [0.6, 0], [-0.6, 0.8], [0, 0.8], [0.6, 0.8]],
}
const BAMBOO_ROWS := {1: [1], 2: [1, 1], 3: [1, 2], 4: [2, 2], 5: [2, 1, 2], 6: [3, 3], 7: [1, 3, 3], 8: [3, 2, 3], 9: [3, 3, 3]}

## Tile faces drawn in code (no fonts needed): 0-8 dots, 9-17 bamboo, 18-26 numbered
## characters, 27-30 winds, 31-33 dragons, 34-35 flowers.
func _draw_face(cv: Control, r: Rect2, s: int, free: bool) -> void:
	var c := r.get_center()
	var fw := r.size.x * 0.74
	var fh := r.size.y * 0.78
	var font := ThemeDB.fallback_font
	if s < 9:
		var n := s + 1
		var pts: Array = DOT_POS[n]
		var rr := fw * (0.3 if n == 1 else 0.14)
		for k in pts.size():
			var p: Vector2 = c + Vector2(pts[k][0] * fw * 0.5, pts[k][1] * fh * 0.5)
			var ci := 1 if (n == 1 or (n == 5 and k == 2)) else ((k + s) % 3 if n > 3 else 0)
			var col := _ink(ci, free)
			cv.draw_circle(p, rr, col)
			cv.draw_circle(p, rr * 0.62, Color(1, 1, 1, 0.9 if free else 0.5))
			cv.draw_circle(p, rr * 0.3, col)
	elif s < 18:
		var n := s - 8
		var rows: Array = BAMBOO_ROWS[n]
		var rh := fh / rows.size()
		for ri in rows.size():
			var cnt: int = rows[ri]
			var y: float = c.y - fh / 2.0 + rh * (ri + 0.5)
			var sw := fw * (0.2 if n > 1 else 0.3)
			for ci in cnt:
				var x: float = c.x + (ci - (cnt - 1) / 2.0) * fw * 0.3
				var col := _ink(1 if (n >= 5 and n % 2 == 1 and ri == 1) else 2, free)
				var sh := rh * (0.86 if n > 1 else 0.95)
				cv.draw_style_box(_slab(col, int(sw * 0.4)), Rect2(x - sw / 2.0, y - sh / 2.0, sw, sh))
				cv.draw_line(Vector2(x - sw / 2.0, y), Vector2(x + sw / 2.0, y), Color(1, 1, 1, 0.8), 2.0)
	elif s < 27:
		var fs := int(fh * 0.62)
		var txt := str(s - 17)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		cv.draw_string(font, Vector2(c.x - w / 2.0, c.y - fh * 0.04), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _ink(0, free))
		for k in 3:  # three-bar ornament under the number
			var yy: float = c.y + fh * 0.2 + k * fh * 0.1
			cv.draw_line(Vector2(c.x - fw * (0.32 - k * 0.04), yy), Vector2(c.x + fw * (0.32 - k * 0.04), yy), _ink(1, free), 3.0)
	elif s < 31:
		var letter: String = ["N", "E", "S", "W"][s - 27]
		cv.draw_arc(c, fw * 0.46, 0, TAU, 28, _ink(0, free), 3.0, true)
		var fs := int(fh * 0.55)
		var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		cv.draw_string(font, Vector2(c.x - w / 2.0, c.y + fs * 0.34), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _ink(2 if s % 2 == 0 else 1, free))
	elif s == 31:  # red dragon: diamond
		var d := fw * 0.48
		cv.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d * 1.2), c + Vector2(d, 0), c + Vector2(0, d * 1.2), c + Vector2(-d, 0)]), _ink(1, free))
		cv.draw_circle(c, d * 0.35, Color(1, 1, 1, 0.9))
	elif s == 32:  # green dragon: leaf
		var d := fw * 0.42
		cv.draw_circle(c + Vector2(-d * 0.45, -d * 0.2), d * 0.75, _ink(2, free))
		cv.draw_circle(c + Vector2(d * 0.45, -d * 0.2), d * 0.75, _ink(2, free))
		cv.draw_circle(c + Vector2(0, d * 0.5), d * 0.75, _ink(2, free))
		cv.draw_line(c + Vector2(0, d * 0.2), c + Vector2(0, d * 1.3), Color(1, 1, 1, 0.9), 3.0)
	elif s == 33:  # white dragon: frame
		cv.draw_rect(Rect2(c - Vector2(fw * 0.42, fh * 0.4), Vector2(fw * 0.84, fh * 0.8)), _ink(0, free), false, 4.0)
		cv.draw_rect(Rect2(c - Vector2(fw * 0.28, fh * 0.26), Vector2(fw * 0.56, fh * 0.52)), _ink(0, free), false, 2.0)
	elif s == 34:  # flower
		for k in 5:
			cv.draw_circle(c + Vector2.from_angle(k * TAU / 5.0 - PI / 2.0) * fw * 0.27, fw * 0.2, _ink(1, free))
		cv.draw_circle(c, fw * 0.14, Color("f2c230") if free else Color(0.6, 0.6, 0.5))
	else:  # sun
		cv.draw_circle(c, fw * 0.26, _ink(1, free).lerp(Color("f2a230"), 0.5))
		for k in 8:
			var a := k * TAU / 8.0
			cv.draw_line(c + Vector2.from_angle(a) * fw * 0.34, c + Vector2.from_angle(a) * fw * 0.5, _ink(1, free), 3.0)

func _draw_home_logo(c: Control) -> void:
	var w := minf(c.size.y * 0.42, 60.0)
	var h := w * ASPECT
	var o := c.size / 2.0
	var spots := [[-1.6, 0.25, 0, 3], [-0.55, 0.25, 0, 13], [0.5, 0.25, 0, 31], [-1.07, -0.25, 1, 8], [-0.02, -0.25, 1, 20]]
	for s in spots:
		var r := Rect2(o + Vector2(s[0] * w, s[1] * h - h / 2.0) - Vector2(s[2] * 6, s[2] * 6), Vector2(w, h))
		_draw_tile(c, r, s[3], true, false, false, w * 0.5)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or solved:
		return
	var ts: Array = []
	for t in engine.tiles:
		ts.append([t.x, t.y, t.z, t.s, 1 if t.on else 0])
	SaveUtil.write(SAVE_PATH, {"level": level, "tiles": ts, "time": elapsed, "moves": engine.moves,
		"history": engine.history, "shuffles": engine.shuffles, "hint": used_hint})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var left := 0
	for t in d.get("tiles", []):
		left += int(t[4])
	return tr(LEVELS[clampi(int(d.get("level", 0)), 0, 2)]) + "   ·   " + tr("Tiles left: %d") % left

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or d.get("tiles", []).is_empty():
		_deal(0)
		return
	_deal(clampi(int(d.get("level", 0)), 0, 2))
	engine.tiles = []
	for t in d.tiles:
		engine.tiles.append({"x": int(t[0]), "y": int(t[1]), "z": int(t[2]), "s": int(t[3]), "on": int(t[4]) == 1})
	engine.history = []
	for p in d.get("history", []):
		engine.history.append([int(p[0]), int(p[1])])
	engine.moves = int(d.get("moves", 0))
	engine.shuffles = int(d.get("shuffles", 0))
	used_hint = bool(d.get("hint", false))
	elapsed = float(d.get("time", 0.0))
	_status()
	board.queue_redraw()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
