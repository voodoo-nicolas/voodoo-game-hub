extends Control

## Peg Solitaire -- tap a peg, then tap the hole to jump into. Builds its whole
## UI in code; the board is one Control drawn in _draw_board().

const PegEngine = preload("res://scripts/games/peg_solitaire/peg_solitaire_engine.gd")
const HomeKit = preload("res://scripts/games/peg_solitaire/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_BOARD := Color(0.06, 0.05, 0.14)
const COLOR_HOLE := Color(0.12, 0.16, 0.32)
const COLOR_PEG := Color("ffae2b")
const COLOR_SELECTED := Color("29e6ff")
const COLOR_TARGET := Color(0.16, 0.9, 1.0, 0.45)
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://peg_solitaire_save.json"

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: PegEngine
var board: Control
var status_label: Label
var end_dialog: ColorRect
var started := false  # a game is on (not just the one behind Home)
var selected := Vector2i(-1, -1)

func _ready() -> void:
	preload("res://scripts/games/peg_solitaire/peg_solitaire_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = PegEngine.new()
	_build_ui()
	_start_new_game()
	started = false

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("📌 Peg Solitaire")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start_new_game)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	var hint := Label.new()
	hint.text = tr("Jump a peg over another into an empty hole. Leave just one!")
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(hint)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 40)
	bm.add_child(bottom)
	root.add_child(bm)
	var undo_btn := Button.new()
	undo_btn.text = tr("↶ Undo")
	undo_btn.custom_minimum_size = Vector2(240, 70)
	undo_btn.add_theme_font_size_override("font_size", 28)
	undo_btn.pressed.connect(_on_undo)
	bottom.add_child(undo_btn)

	end_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("↶ Undo"), "action": _on_undo},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/peg_solitaire/peg_solitaire_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	started = true
	engine.reset()
	selected = Vector2i(-1, -1)
	end_dialog.visible = false
	_refresh()

func _on_undo() -> void:
	engine.undo()
	selected = Vector2i(-1, -1)
	_refresh()

func _refresh() -> void:
	status_label.text = tr("Pegs left: %d") % engine.peg_count()
	board.queue_redraw()

# ---------- board geometry ----------

func _cell_size() -> float:
	return floor(min(board.size.x - 32.0, board.size.y - 16.0) / PegEngine.SIZE)

func _origin() -> Vector2:
	var s := _cell_size() * PegEngine.SIZE
	return Vector2((board.size.x - s) / 2.0, (board.size.y - s) / 2.0)

func _draw_board() -> void:
	var cs := _cell_size()
	var o := _origin()
	var full := cs * PegEngine.SIZE
	# the cross-shaped wooden board
	board.draw_rect(Rect2(o + Vector2(cs * 2, 0), Vector2(cs * 3, full)), COLOR_BOARD)
	board.draw_rect(Rect2(o + Vector2(0, cs * 2), Vector2(full, cs * 3)), COLOR_BOARD)
	HomeKit.glow_polyline(board, PackedVector2Array([o + Vector2(cs * 2, 0), o + Vector2(cs * 5, 0), o + Vector2(cs * 5, cs * 2),
		o + Vector2(full, cs * 2), o + Vector2(full, cs * 5), o + Vector2(cs * 5, cs * 5), o + Vector2(cs * 5, full),
		o + Vector2(cs * 2, full), o + Vector2(cs * 2, cs * 5), o + Vector2(0, cs * 5), o + Vector2(0, cs * 2),
		o + Vector2(cs * 2, cs * 2)]), HomeKit.PURPLE, 2.0, true)
	var targets: Array = engine.targets_from(selected.y, selected.x) if selected.x >= 0 else []
	for r in PegEngine.SIZE:
		for c in PegEngine.SIZE:
			if not PegEngine.is_hole(r, c):
				continue
			var center := o + Vector2(c + 0.5, r + 0.5) * cs
			board.draw_circle(center, cs * 0.22, COLOR_HOLE)
			if engine.at(r, c) == PegEngine.PEG:
				var col := COLOR_SELECTED if Vector2i(c, r) == selected else COLOR_PEG
				HomeKit.glow_circle(board, center, cs * 0.34, col, 2.5, 0.45)
			elif Vector2i(c, r) in targets:
				board.draw_circle(center, cs * 0.3, COLOR_TARGET)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if end_dialog.visible:
		return
	var cs := _cell_size()
	var p: Vector2 = (event.position - _origin()) / cs
	var cell := Vector2i(floori(p.x), floori(p.y))
	if not PegEngine.is_hole(cell.y, cell.x):
		selected = Vector2i(-1, -1)
		board.queue_redraw()
		return
	if engine.at(cell.y, cell.x) == PegEngine.PEG:
		selected = Vector2i(-1, -1) if cell == selected else cell
	elif selected.x >= 0 and engine.try_move(selected.y, selected.x, cell.y, cell.x):
		_sfx("capture")
		# keep chaining from the landing hole when another jump is possible
		selected = cell if not engine.targets_from(cell.y, cell.x).is_empty() else Vector2i(-1, -1)
		_refresh()
		_check_end()
		return
	board.queue_redraw()

func _check_end() -> void:
	if engine.has_moves():
		return
	SaveUtil.delete(SAVE_PATH)
	var left: int = engine.peg_count()
	var msg: String
	if left == 1 and engine.at(3, 3) == PegEngine.PEG:
		msg = tr("Perfect! One peg, dead centre.")
	elif left == 1:
		msg = tr("Solved! Just one peg left.")
	else:
		msg = tr("No more jumps. %d pegs left.") % left
	if info:
		info.add("Games played")
		if left == 1:
			info.add("Games solved")
			info.celebrate("Solved!")
		if left == 1 and engine.at(3, 3) == PegEngine.PEG:
			info.add("Perfect games")
		if info.low("Fewest pegs left", left) and left > 1:
			msg += "\n" + tr("New best!")
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/peg_solitaire/peg_solitaire_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/peg_solitaire/peg_solitaire_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Jump pegs to remove them. End with one in the centre.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  New game", "sub": "English board, 32 pegs", "action": _fresh_game}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): var d = SaveUtil.read(SAVE_PATH); return "" if d == null else tr("Pegs left: %d") % int(d.get("left", 0)),
		"restart": _start_new_game,
		"board": "Games solved",
		"board_note": "Boards solved down to one peg.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 7.4, 26.0)
	var o := Vector2(c.size.x / 2.0 - k * 3.5, c.size.y / 2.0 - k * 3.5)
	for r in 7:
		for col in 7:
			if not PegEngine.is_hole(r, col):
				continue
			var p := o + Vector2(col + 0.5, r + 0.5) * k
			if (r * 7 + col) % 3 == 0 and not (r == 3 and col == 3):
				HomeKit.glow_circle(c, p, k * 0.32, COLOR_PEG, 1.5, 0.5)
			else:
				c.draw_arc(p, k * 0.18, 0, TAU, 16, Color(HomeKit.BLUE, 0.6), 1.5)

func _fresh_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not started or end_dialog.visible or not engine.has_moves():
		return
	SaveUtil.write(SAVE_PATH, {"grid": engine.grid, "left": engine.peg_count()})

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	_start_new_game()
	var g: Array = []
	for v in d.grid:
		g.append(int(v))
	if g.size() == PegEngine.SIZE * PegEngine.SIZE:
		engine.grid = g
		engine.history = []
	_refresh()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
