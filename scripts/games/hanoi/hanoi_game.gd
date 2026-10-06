extends Control

## Tower of Hanoi -- tap a peg to lift its top disc, tap another to drop it.

const HanoiEngine = preload("res://scripts/games/hanoi/hanoi_engine.gd")
const HomeKit = preload("res://scripts/games/hanoi/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://hanoi_best.json"
const SAVE_PATH := "user://hanoi_save.json"
const DISC_COLORS := [Color(0.95, 0.3, 0.3), Color(0.98, 0.6, 0.2), Color(0.98, 0.85, 0.25),
	Color(0.4, 0.85, 0.4), Color(0.3, 0.75, 0.95), Color(0.45, 0.45, 0.95), Color(0.75, 0.45, 0.95),
	Color(0.95, 0.45, 0.75)]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: HanoiEngine
var board: Control
var moves_label: Label
var discs_label: Label
var win_dialog: ColorRect
var started := false  # a tower is in play (not just the one behind Home)
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
	started = false

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
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
	title.text = tr("🗼 Tower of Hanoi")
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

	win_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("Add a Disc"), "action": _change_discs.bind(1)},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/hanoi/hanoi_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _change_discs(delta: int) -> void:
	engine.discs = clampi(engine.discs + delta, HanoiEngine.MIN_DISCS, HanoiEngine.MAX_DISCS)
	_start_new_game()

func _start_new_game() -> void:
	started = true
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

## Look (STANDARDS §9): "classic" = a wooden base and pegs, bright solid discs (default); "voodoo" = the neon
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
	var w := board.size.x
	var h := board.size.y
	var base_y := h - 60.0
	var disc_h: float = min(46.0, (h - 200.0) / (HanoiEngine.MAX_DISCS + 1))
	var max_w := w / 3.0 - 16.0
	if _is_classic():
		board.draw_rect(Rect2(8, base_y, w - 16, 14), HomeKit.CLASSIC.wood_dark)
	else:
		HomeKit.glow_rect(board, Rect2(8, base_y, w - 16, 14), HomeKit.BLUE, 2.0, 0.2)
	for i in 3:
		var x := _peg_x(i)
		var peg_top: float = base_y - disc_h * (engine.discs + 1.5)
		if _is_classic():
			board.draw_line(Vector2(x, peg_top), Vector2(x, base_y), HomeKit.CLASSIC.wood_dark, 8.0)
		else:
			HomeKit.glow_line(board, Vector2(x, peg_top), Vector2(x, base_y), Color(HomeKit.BLUE, 0.8), 3.0)
		var stack: Array = engine.pegs[i]
		for j in stack.size():
			var s: int = stack[j]
			var dw: float = 40.0 + (max_w - 40.0) * (s - 1) / float(HanoiEngine.MAX_DISCS - 1)
			var y := base_y - disc_h * (j + 1)
			if i == lifted and j == stack.size() - 1:
				y = peg_top - disc_h - 20.0
			var rect := Rect2(x - dw / 2.0, y + 2, dw, disc_h - 4)
			var col: Color = DISC_COLORS[(s - 1) % DISC_COLORS.size()]
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(col, 0.25)
			sb.border_color = col
			sb.set_border_width_all(3)
			sb.shadow_color = Color(col, 0.4)
			sb.shadow_size = 7
			if _is_classic():
				sb.bg_color = col
				sb.border_color = col.darkened(0.35)
				sb.shadow_color = Color(0, 0, 0, 0.35)
				sb.shadow_size = 3
				sb.shadow_offset = Vector2(1, 2)
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
			_sfx("tick")
	elif i == lifted:
		_sfx("tick")
		lifted = -1
	elif engine.move(lifted, i):
		_sfx("place")
		lifted = -1
		if engine.is_solved():
			_on_solved()
	else:
		_sfx("invalid")
		lifted = i if not engine.pegs[i].is_empty() else lifted
	_refresh()

func _on_solved() -> void:
	SaveUtil.delete(SAVE_PATH)
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

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/hanoi/hanoi_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/hanoi/hanoi_help.gd"),
		"info": info,
		"accent": HomeKit.PURPLE,
		"subtitle": "Move the whole tower to the right peg. Never a big disc on a small one.",
		"logo": _draw_home_logo,
		"solo_heading": "Number of discs",
		"modes": [
			{"text": "3", "row": "a", "color": HomeKit.LIME, "action": _play_discs.bind(3)},
			{"text": "4", "row": "a", "color": HomeKit.LIME, "action": _play_discs.bind(4)},
			{"text": "5", "row": "a", "color": HomeKit.CYAN, "action": _play_discs.bind(5)},
			{"text": "6", "row": "b", "color": HomeKit.CYAN, "action": _play_discs.bind(6)},
			{"text": "7", "row": "b", "color": HomeKit.PINK, "action": _play_discs.bind(7)},
			{"text": "8", "row": "b", "color": HomeKit.PINK, "action": _play_discs.bind(8)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): var d = SaveUtil.read(SAVE_PATH); return "" if d == null else tr("%d discs") % int(d.discs),
		"restart": _start_new_game,
		"board": "Puzzles solved",
		"board_note": "Towers moved, all sizes.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var w := h * 1.6
	var o := Vector2((c.size.x - w) / 2.0, (c.size.y + h) / 2.0 - 8)
	HomeKit.glow_line(c, o, o + Vector2(w, 0), HomeKit.BLUE, 2.5)
	for i in 3:
		var x := o.x + w * (i + 0.5) / 3.0
		HomeKit.glow_line(c, Vector2(x, o.y), Vector2(x, o.y - h * 0.85), Color(HomeKit.BLUE, 0.7), 2.0)
	var cols := [HomeKit.PINK, HomeKit.GOLD, HomeKit.LIME, HomeKit.CYAN]
	for k in 4:
		var dw := w * (0.3 - k * 0.055)
		var x := o.x + w * 0.5 / 3.0
		HomeKit.glow_rect(c, Rect2(x - dw / 2.0, o.y - (k + 1) * h * 0.16, dw, h * 0.13), cols[k], 2.0, 0.25)

func _play_discs(n: int) -> void:
	engine.discs = n
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not started or win_dialog.visible:
		return
	SaveUtil.write(SAVE_PATH, {"discs": engine.discs, "pegs": engine.pegs, "moves": engine.moves})

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	engine.discs = clampi(int(d.discs), HanoiEngine.MIN_DISCS, HanoiEngine.MAX_DISCS)
	_start_new_game()
	engine.pegs = [_ints(d.pegs[0]), _ints(d.pegs[1]), _ints(d.pegs[2])]
	engine.moves = int(d.get("moves", 0))
	_refresh()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
