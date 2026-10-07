extends Control

## Color Sort -- tap a tube, then another, to move its top ball over. A ball
## can go on an empty tube or on a ball of the same colour. Fill every tube
## with a single colour. Every colour has its own symbol too.

const CSEngine = preload("res://scripts/games/color_sort/color_sort_engine.gd")
const HELP = preload("res://scripts/games/color_sort/color_sort_help.gd")
const HomeKit = preload("res://scripts/games/color_sort/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://color_sort_save.json"
const LEVEL_NAMES := ["Easy", "Normal", "Hard", "Expert"]
const CLASSIC_COLORS := [Color("e63946"), Color("f4a261"), Color("f1d34a"), Color("2a9d8f"), Color("3a86ff"),
	Color("8d5bd6"), Color("ff6fa8"), Color("4cc26a"), Color("9aa0aa"), Color("8d5524")]
const NEON_COLORS := [Color("ff2b4f"), Color("ff9a2b"), Color("fff23a"), Color("29e6a6"), Color("3a8cff"),
	Color("b36bff"), Color("ff2bd6"), Color("7dff3a"), Color("c9d2e6"), Color("c98a4a")]

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

func _ready() -> void:
	preload("res://scripts/games/color_sort/color_sort_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = CSEngine.new()
	engine.new_game(0)
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
		{"text": tr("Next puzzle"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in 4:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard", "🤯 Expert"][i], "sub": "%d colors" % CSEngine.LEVELS[i].colors, "row": "lvl",
			"action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Move the balls until every tube is one color.",
		"logo": _draw_home_logo,
		"modes": modes,
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

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if table:
		table.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _color_of(c: int) -> Color:
	return (CLASSIC_COLORS if _is_classic() else NEON_COLORS)[c % 10]

# ---------- layout ----------

func _layout() -> Dictionary:
	var n: int = engine.tubes.size()
	var cols: int = n if n <= 6 else int(ceil(n / 2.0))
	var rows: int = 1 if n <= 6 else 2
	var cell_w: float = (table.size.x - 24.0) / cols
	var d: float = clampf(minf(cell_w * 0.62, (table.size.y / rows - 70.0) / (CSEngine.CAP + 0.6) - 8.0), 28.0, 66.0)
	var tube_w: float = d + 16.0
	var tube_h: float = CSEngine.CAP * (d + 6.0) + 16.0
	return {"cols": cols, "rows": rows, "cell_w": cell_w, "d": d, "tube_w": tube_w, "tube_h": tube_h}

func _tube_rect(i: int, lay: Dictionary) -> Rect2:
	var cols: int = lay.cols
	var rows: int = lay.rows
	var r: int = i / cols
	var c: int = i % cols
	var in_row: int = cols if r < rows - 1 else engine.tubes.size() - cols * (rows - 1)
	var row_w: float = in_row * lay.cell_w
	var x0: float = (table.size.x - row_w) / 2.0 + c * lay.cell_w + (lay.cell_w - lay.tube_w) / 2.0
	var band: float = table.size.y / rows
	var y0: float = r * band + (band - lay.tube_h) / 2.0 + 14.0
	return Rect2(x0, y0, lay.tube_w, lay.tube_h)

# ---------- drawing ----------

func _draw_table() -> void:
	if engine == null or engine.tubes.is_empty():
		return
	var lay := _layout()
	var d: float = lay.d
	for i in engine.tubes.size():
		var r := _tube_rect(i, lay)
		var lift: float = -d * 0.55 if i == selected else 0.0
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(r.size.x * 0.45))
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.set_border_width_all(3)
		if _is_classic():
			sb.bg_color = Color(0.85, 0.92, 1.0, 0.16)
			sb.border_color = Color("c9d6ea") if i != selected else HomeKit.CLASSIC.yellow
		else:
			sb.bg_color = Color(HomeKit.CYAN, 0.07)
			sb.border_color = HomeKit.CYAN if i != selected else HomeKit.GOLD
			sb.shadow_color = Color(HomeKit.CYAN, 0.3)
			sb.shadow_size = 6
		table.draw_style_box(sb, r)
		var t: Array = engine.tubes[i]
		for k in t.size():
			var is_top: bool = k == t.size() - 1
			var ctr := Vector2(r.position.x + r.size.x / 2.0, r.end.y - 8.0 - d / 2.0 - k * (d + 6.0))
			if is_top:
				ctr.y += lift
			_draw_ball(ctr, d / 2.0, int(t[k]))

func _draw_ball(ctr: Vector2, r: float, c: int) -> void:
	var col := _color_of(c)
	table.draw_circle(ctr, r, col)
	table.draw_circle(ctr + Vector2(-r * 0.3, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.28))
	table.draw_arc(ctr, r, 0.0, TAU, 28, col.darkened(0.35), 2.0)
	var mark := Color(0, 0, 0, 0.55) if col.get_luminance() > 0.55 else Color(1, 1, 1, 0.8)
	_draw_symbol(ctr, r * 0.42, c, mark)

## One small symbol per colour, so colour is never the only cue.
func _draw_symbol(ctr: Vector2, s: float, c: int, col: Color) -> void:
	match c % 10:
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
		_:
			table.draw_polyline(PackedVector2Array([ctr + Vector2(-s, s * 0.5), ctr + Vector2(0, -s * 0.5), ctr + Vector2(s, s * 0.5)]), col, 3.0)

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

# ---------- play ----------

func _on_table_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not playing or solved_shown:
		return
	var lay := _layout()
	for i in engine.tubes.size():
		if _tube_rect(i, lay).grow(8.0).has_point(event.position):
			_tap_tube(i)
			return
	selected = -1
	table.queue_redraw()

func _tap_tube(i: int) -> void:
	if selected < 0:
		if not engine.tubes[i].is_empty():
			selected = i
			_sfx("tick")
	elif selected == i:
		selected = -1
		_sfx("back")
	elif engine.can_move(selected, i):
		engine.do_move(selected, i)
		selected = -1
		_sfx("place")
		_save_game()
		if engine.solved():
			_on_solved()
	else:
		_sfx("invalid")
		selected = i if not engine.tubes[i].is_empty() else -1
	_render()

func _render() -> void:
	status_label.text = tr("Moves: %d") % engine.moves + "    " + tr("%s — %d colors") % [tr(LEVEL_NAMES[engine.level]), engine.color_count()]
	undo_btn.disabled = not engine.can_undo() or solved_shown
	tube_btn.disabled = not engine.can_add_tube() or solved_shown
	reset_btn.disabled = engine.moves == 0 and engine.extra_used == 0
	table.queue_redraw()

func _on_undo() -> void:
	if engine.undo():
		selected = -1
		_sfx("back")
		_save_game()
		_render()

func _on_add_tube() -> void:
	if engine.add_tube():
		_sfx("powerup")
		_save_game()
		_render()

func _on_reset() -> void:
	engine.reset()
	selected = -1
	_sfx("back")
	_save_game()
	_render()

func _on_solved() -> void:
	solved_shown = true
	_sfx("win")
	var name: String = LEVEL_NAMES[engine.level]
	if info:
		info.add("Puzzles solved")
		info.best("Fewest moves (%s)" % name, engine.moves, true)
		info.celebrate(tr("Sorted!"))
	SaveUtil.delete(SAVE_PATH)
	end_dialog.get_meta("message_label").text = tr("Moves: %d") % engine.moves
	end_dialog.visible = true

# ---------- Landing (home_kit.gd) ----------

func _new_game(level: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_game(level)
	_begin_play()

func _restart() -> void:
	_new_game(engine.level)

func _begin_play() -> void:
	playing = true
	solved_shown = false
	selected = -1
	end_dialog.visible = false
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
	SaveUtil.write(SAVE_PATH, engine.to_dict())

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Moves: %d") % int(d.get("moves", 0))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d) or engine.solved():
		_new_game(0)
		return
	_begin_play()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
