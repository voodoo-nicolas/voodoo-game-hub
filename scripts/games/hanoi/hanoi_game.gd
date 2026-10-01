extends Control

## Tower of Hanoi -- tap a peg to lift its top disc, tap another to drop it.

const HanoiEngine = preload("res://scripts/games/hanoi/hanoi_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://hanoi_best.json"
const DISC_COLORS := [Color(0.95, 0.3, 0.3), Color(0.98, 0.6, 0.2), Color(0.98, 0.85, 0.25),
	Color(0.4, 0.85, 0.4), Color(0.3, 0.75, 0.95), Color(0.45, 0.45, 0.95), Color(0.75, 0.45, 0.95),
	Color(0.95, 0.45, 0.75)]

var info = null  # GameInfo; null on apps without it, so guard every use
var engine: HanoiEngine
var board: Control
var moves_label: Label
var discs_label: Label
var win_dialog: ColorRect
var lifted: int = -1
var best: Dictionary = {}

func _ready() -> void:
	preload("res://scripts/games/hanoi/hanoi_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = HanoiEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = data
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🗼 Tower of Hanoi")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start_new_game)
	bar.add_child(restart_btn)

	var disc_row := HBoxContainer.new()
	disc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	disc_row.add_theme_constant_override("separation", 20)
	root.add_child(disc_row)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(70, 60)
	minus.add_theme_font_size_override("font_size", 32)
	minus.pressed.connect(_change_discs.bind(-1))
	disc_row.add_child(minus)
	discs_label = Label.new()
	discs_label.add_theme_font_size_override("font_size", 28)
	disc_row.add_child(discs_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(70, 60)
	plus.add_theme_font_size_override("font_size", 32)
	plus.pressed.connect(_change_discs.bind(1))
	disc_row.add_child(plus)

	moves_label = Label.new()
	moves_label.add_theme_font_size_override("font_size", 26)
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(moves_label)

	var hint := Label.new()
	hint.text = tr("Move the whole tower to the right peg. Never put a bigger disc on a smaller one.")
	hint.add_theme_font_size_override("font_size", 22)
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

	win_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("Add a Disc"), "action": _change_discs.bind(1)},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/hanoi/hanoi_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _change_discs(delta: int) -> void:
	engine.discs = clampi(engine.discs + delta, HanoiEngine.MIN_DISCS, HanoiEngine.MAX_DISCS)
	_start_new_game()

func _start_new_game() -> void:
	engine.reset(engine.discs)
	lifted = -1
	win_dialog.visible = false
	_refresh()

func _refresh() -> void:
	discs_label.text = tr("%d discs") % engine.discs
	var b: int = int(best.get(str(engine.discs), 0))
	moves_label.text = tr("Moves: %d   (best possible: %d)") % [engine.moves, engine.optimal_moves()]
	if b > 0:
		moves_label.text += "   " + tr("Your best: %d") % b
	board.queue_redraw()

func _peg_x(i: int) -> float:
	return board.size.x * (i + 0.5) / 3.0

func _draw_board() -> void:
	var w := board.size.x
	var h := board.size.y
	var base_y := h - 60.0
	var disc_h: float = min(46.0, (h - 200.0) / (HanoiEngine.MAX_DISCS + 1))
	var max_w := w / 3.0 - 16.0
	board.draw_rect(Rect2(8, base_y, w - 16, 18), Color(0.45, 0.3, 0.18))
	for i in 3:
		var x := _peg_x(i)
		var peg_top: float = base_y - disc_h * (engine.discs + 1.5)
		board.draw_rect(Rect2(x - 7, peg_top, 14, base_y - peg_top), Color(0.55, 0.38, 0.22))
		var stack: Array = engine.pegs[i]
		for j in stack.size():
			var s: int = stack[j]
			var dw: float = 40.0 + (max_w - 40.0) * (s - 1) / float(HanoiEngine.MAX_DISCS - 1)
			var y := base_y - disc_h * (j + 1)
			if i == lifted and j == stack.size() - 1:
				y = peg_top - disc_h - 20.0
			var rect := Rect2(x - dw / 2.0, y + 2, dw, disc_h - 4)
			var sb := StyleBoxFlat.new()
			sb.bg_color = DISC_COLORS[(s - 1) % DISC_COLORS.size()]
			sb.set_corner_radius_all(int(disc_h / 2.0))
			board.draw_style_box(sb, rect)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if win_dialog.visible:
		return
	var i := clampi(int(event.position.x / (board.size.x / 3.0)), 0, 2)
	if lifted < 0:
		if not engine.pegs[i].is_empty():
			lifted = i
	elif i == lifted:
		lifted = -1
	elif engine.move(lifted, i):
		lifted = -1
		if engine.is_solved():
			_on_solved()
	else:
		lifted = i if not engine.pegs[i].is_empty() else lifted
	_refresh()

func _on_solved() -> void:
	var key := str(engine.discs)
	var prev: int = int(best.get(key, 0))
	if prev == 0 or engine.moves < prev:
		best[key] = engine.moves
		SaveUtil.write(BEST_PATH, best)
	var msg := tr("%d moves") % engine.moves
	if engine.moves == engine.optimal_moves():
		msg += "\n" + tr("A perfect solve!")
	if info:
		info.add("Puzzles solved")
		info.celebrate("Solved!")
		if engine.moves == engine.optimal_moves():
			info.add("Perfect solves")
		info.high("Most discs solved", engine.discs)
	win_dialog.get_meta("message_label").text = msg
	win_dialog.visible = true
