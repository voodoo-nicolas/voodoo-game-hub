extends Control

const TicTacToeEngine = preload("res://scripts/games/tictactoe/tictactoe_engine.gd")
const HomeKit = preload("res://scripts/games/tictactoe/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://tictactoe_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
## How to Play + stats; not preloaded for the same reason (apps before v0.20).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
## Voodoo Mode (crossbones vs skulls); not preloaded either (apps before v0.21).
const VOODOO_PATH := "res://scripts/common/voodoo.gd"
const X_COLOR := HomeKit.CYAN
const O_COLOR := HomeKit.MAGENTA
const LEVELS := ["Easy", "Medium", "Hard"]
const CPU_DELAY := 0.45

var engine
var game_active: bool = false
## -1 = two players on one phone; 0..2 = against the computer at that level
## (the player is X, the computer O).
var cpu_level: int = -1
var rng := RandomNumberGenerator.new()

var status_label: Label
var cells: Array = []  # 9 Buttons
var win_dialog: Control
var win_label: Label
var cpu_timer: Timer
## Online play (null on apps without it). my_mark: host plays X, guest O;
## 0 means ordinary same-phone play.
var online: Control = null
var my_mark: int = 0
var info = null  # GameInfo, null on apps without it
var home  # HomeKit
var voodoo = null  # the Voodoo script, null on apps without it
var voodoo_on: bool = false
var marks: Array = []  # 9 Voodoo pieces, one per cell (empty without Voodoo)
var bg: ColorRect
## Look (STANDARDS §9): "classic" = dark ink X and red O on paper (default),
## "voodoo" = neon, crossbones vs skulls. Set by the kit.
var skin: String = "classic"

func _ready() -> void:
	preload("res://scripts/games/tictactoe/tictactoe_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	if ResourceLoader.exists(VOODOO_PATH):
		voodoo = load(VOODOO_PATH)
		voodoo_on = voodoo.is_on()
	engine = TicTacToeEngine.new()
	_build_ui()
	_reset_board()

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
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)

	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var title := Label.new()
	title.text = tr("Tic-Tac-Toe")
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0))
	title.add_theme_color_override("font_outline_color", Color(X_COLOR, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 36)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)

	var grid := GridContainer.new()
	grid.columns = 3
	var separation := 12
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	box.add_child(grid)

	var viewport_width: float = get_viewport_rect().size.x
	var outer_margin := 36.0
	var cell_size: float = floor((viewport_width - outer_margin * 2.0 - separation * 2.0) / 3.0)

	for i in range(9):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		cell.add_theme_font_size_override("font_size", int(cell_size * 0.5))
		cell.focus_mode = Control.FOCUS_NONE
		cell.set_meta("sfx", "")  # the move plays "place"
		_style_cell(cell, HomeKit.BLUE, false)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(cell)
		cells.append(cell)
		if voodoo:
			var mark: Control = voodoo.new()
			mark.span = 0.7
			cell.add_child(mark)
			marks.append(mark)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	_build_win_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("tictactoe", tr("Tic-Tac-Toe"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_reset_board)
		online.status_changed.connect(_render)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/tictactoe/tictactoe_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _build_home() -> void:
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": ["🙂 Easy", "😐 Medium", "😈 Hard"][i], "row": "cpu",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_vs_cpu.bind(i)})
	modes.append({"text": "👥 2 Players", "sub": "Take turns on one phone", "multi": true, "action": _new_two_player})
	if online:
		modes.append({"text": "🌐 Online", "sub": "Play a friend on another phone", "multi": true,
			"color": HomeKit.PURPLE, "action": online.open_lobby})
	home = HomeKit.new({
		"help": preload("res://scripts/games/tictactoe/tictactoe_help.gd"),
		"info": info,
		"accent": X_COLOR,
		"solo_heading": "vs Computer",
		"subtitle": "Three in a row wins. Beat the computer or a friend.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _start_new_game,
		"board": "Wins",
		"board_note": "Games won against the computer, at any level.",
		"online": online,
	})
	add_child(home)

func _draw_home_logo(c: Control) -> void:
	var s := minf(c.size.y, 190.0)
	var o := Vector2((c.size.x - s) / 2.0, (c.size.y - s) / 2.0)
	var k := s / 3.0
	for i in [1, 2]:
		HomeKit.glow_line(c, o + Vector2(k * i, 6), o + Vector2(k * i, s - 6), HomeKit.BLUE, 3.0)
		HomeKit.glow_line(c, o + Vector2(6, k * i), o + Vector2(s - 6, k * i), HomeKit.BLUE, 3.0)
	var pad := k * 0.24
	for idx in [0, 4, 8]:
		var cell := o + Vector2((idx % 3) * k, int(idx / 3) * k)
		HomeKit.glow_line(c, cell + Vector2(pad, pad), cell + Vector2(k - pad, k - pad), X_COLOR, 4.0)
		HomeKit.glow_line(c, cell + Vector2(k - pad, pad), cell + Vector2(pad, k - pad), X_COLOR, 4.0)
	for idx in [2, 6]:
		HomeKit.glow_circle(c, o + Vector2((idx % 3 + 0.5) * k, (int(idx / 3) + 0.5) * k), k * 0.3, O_COLOR, 4.0)
	# the winning line
	HomeKit.glow_line(c, o + Vector2(k * 0.2, k * 0.2), o + Vector2(s - k * 0.2, s - k * 0.2), HomeKit.LIME, 2.0)

func _style_cell(cell: Button, color: Color, lit: bool) -> void:
	if skin == "classic":
		# Paper squares with pencil edges; the winning three turn pale green.
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("d9f2d0") if lit else HomeKit.CLASSIC.paper
			sb.border_color = HomeKit.CLASSIC.pencil
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(6)
			cell.add_theme_stylebox_override(state, sb)
		return
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := HomeKit.neon_box(color, "pressed" if lit else ("hover" if state == "hover" else "normal"))
		sb.bg_color = Color(color, 0.22 if lit else 0.05)
		cell.add_theme_stylebox_override(state, sb)

func _build_win_dialog() -> void:
	win_dialog = Ui.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 Tic-Tac-Toe Home"), "action": _go_home},
	], true)
	add_child(win_dialog)
	win_label = win_dialog.get_meta("message_label")

func _go_home() -> void:
	home.go_home()

func _is_online() -> bool:
	return online != null and online.is_online()

func _new_vs_cpu(level: int) -> void:
	cpu_level = level
	SaveUtil.delete(SAVE_PATH)
	_reset_board()

func _new_two_player() -> void:
	cpu_level = -1
	SaveUtil.delete(SAVE_PATH)
	_reset_board()

func _start_new_game() -> void:
	if online:
		online.new_game()
	_reset_board()

func _reset_board() -> void:
	engine.reset()
	cpu_timer.stop()
	game_active = true
	win_dialog.visible = false
	_render()

func _vs_cpu() -> bool:
	return cpu_level >= 0 and not _is_online()

func _on_cell_pressed(i: int) -> void:
	if _is_online() and not online.can_act(engine.turn == my_mark):
		return  # not your turn (or nobody to play against right now)
	if _vs_cpu() and engine.turn != TicTacToeEngine.X:
		return  # the computer is thinking
	if engine.move(i):
		if _is_online():
			online.send_move({"i": i})
		_after_move()

func _after_move() -> void:
	_sfx("place")
	_render()
	if engine.is_over():
		_show_result()
	elif _vs_cpu() and engine.turn == TicTacToeEngine.O:
		cpu_timer.start(CPU_DELAY)

func _cpu_turn() -> void:
	if not game_active or not _vs_cpu() or engine.turn != TicTacToeEngine.O:
		return
	var i: int = engine.cpu_move(cpu_level, rng)
	if i >= 0 and engine.move(i):
		_after_move()

# ---------- online ----------

func _online_state() -> Dictionary:
	return {"board": engine.board, "turn": engine.turn}

func _on_online_started(my_player: int) -> void:
	my_mark = TicTacToeEngine.X if my_player == 1 else TicTacToeEngine.O
	cpu_level = -1
	home.hide_home()
	_reset_board()

func _on_remote_move(p: Dictionary) -> void:
	if engine.turn != my_mark and engine.move(int(p.get("i", -1))):
		_after_move()

func _on_remote_state(st: Dictionary) -> void:
	var board: Array = []
	for v in st.get("board", []):
		board.append(int(v))
	if board.size() != 9:
		return
	engine.board = board
	engine.turn = int(st.get("turn", TicTacToeEngine.X))
	game_active = not engine.is_over()
	win_dialog.visible = false
	_render()
	if engine.is_over():
		_show_result()

func _on_pause_pressed() -> void:
	home.pause()

func _show_result() -> void:
	var just_ended := game_active  # a resync of a finished game isn't a new result
	game_active = false
	if not _is_online():  # an online game ending mustn't wipe a paused local one
		SaveUtil.delete(SAVE_PATH)
	var w: int = engine.winner()
	if w == TicTacToeEngine.EMPTY:
		win_label.text = tr("It's a draw!")
	elif _is_online():
		win_label.text = online.result_text(w == my_mark)
	elif _vs_cpu():
		win_label.text = tr("You win!") if w == TicTacToeEngine.X else tr("The computer wins!")
	else:
		win_label.text = tr("%s wins!") % _mark_name(w)
	if info and just_ended:
		if _is_online():
			info.result("draw" if w == TicTacToeEngine.EMPTY else ("win" if w == my_mark else "loss"), true)
			win_label.text += "\n" + info.summary(["Online wins", "Online losses", "Online draws"])
		elif _vs_cpu():
			info.result("draw" if w == TicTacToeEngine.EMPTY else ("win" if w == TicTacToeEngine.X else "loss"))
			if w == TicTacToeEngine.X:
				info.add("Wins (%s)" % LEVELS[cpu_level])
			win_label.text += "\n" + info.summary(["Wins", "Losses", "Draws"])
		else:
			info.add("Draws" if w == TicTacToeEngine.EMPTY else ("X wins" if w == TicTacToeEngine.X else "O wins"))
			if not (w == TicTacToeEngine.EMPTY):
				info.celebrate(win_label.text.split("\n")[0])
			win_label.text += "\n" + info.summary(["X wins", "O wins"])
	win_dialog.visible = true

## The kit's Look (Options): re-skins in place, so an online match goes on.
func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	voodoo_on = skin == "voodoo" and voodoo != null
	if bg and bg.get_child_count() > 0:
		bg.get_child(0).visible = skin != "classic"  # the faint neon grid
	_render()

## Older apps' drawer toggle.
func _set_voodoo(on: bool) -> void:
	_set_skin("voodoo" if on else "classic")

func _x_color() -> Color:
	return HomeKit.CLASSIC.ink if skin == "classic" else X_COLOR

func _o_color() -> Color:
	return HomeKit.CLASSIC.red if skin == "classic" else O_COLOR

func _mark_name(mark: int) -> String:
	if voodoo_on:
		return tr("Bones") if mark == TicTacToeEngine.X else tr("Skull")
	return "X" if mark == TicTacToeEngine.X else "O"

func _render() -> void:
	bg.color = voodoo.BG if voodoo_on else (HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG)
	var line: Array = []
	if engine.winner() != TicTacToeEngine.EMPTY:
		for l in TicTacToeEngine.WIN_LINES:
			if engine.board[l[0]] == engine.winner() and engine.board[l[1]] == engine.winner() and engine.board[l[2]] == engine.winner():
				line = l
	for i in range(9):
		var v: int = engine.board[i]
		var color := _x_color() if v == TicTacToeEngine.X else _o_color()
		if voodoo_on:
			cells[i].text = ""
			marks[i].kind = voodoo.BONES if v == TicTacToeEngine.X else (voodoo.SKULL if v == TicTacToeEngine.O else voodoo.NONE)
			marks[i].fill = color
		else:
			cells[i].text = "X" if v == TicTacToeEngine.X else ("O" if v == TicTacToeEngine.O else "")
			if voodoo:
				marks[i].kind = voodoo.NONE
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			cells[i].add_theme_color_override(key, color if skin == "classic" else color.lerp(Color.WHITE, 0.25))
		cells[i].add_theme_color_override("font_outline_color", Color(color, 0.0 if skin == "classic" else 0.5))
		cells[i].add_theme_constant_override("outline_size", 0 if skin == "classic" else 10)
		_style_cell(cells[i], HomeKit.LIME if line.has(i) else HomeKit.BLUE, line.has(i))

	var mark_name := _mark_name(engine.turn)
	if _is_online():
		status_label.text = online.status_text(engine.turn == my_mark, mark_name)
	elif _vs_cpu():
		status_label.text = tr("Your turn (%s)") % mark_name if engine.turn == TicTacToeEngine.X \
			else tr("Computer is thinking...")
	else:
		status_label.text = tr("Turn: %s") % mark_name
	status_label.add_theme_color_override("font_color", (X_COLOR if engine.turn == TicTacToeEngine.X else O_COLOR).lerp(Color.WHITE, 0.4))  # on the dark table either way

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or _is_online():
		return  # online games aren't resumable alone
	SaveUtil.write(SAVE_PATH, {"board": engine.board, "turn": engine.turn, "cpu": cpu_level})

func _resume_text() -> String:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return ""
	var lvl := int(data.get("cpu", -1))
	return tr("2 Players") if lvl < 0 else tr(LEVELS[clampi(lvl, 0, 2)])

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		_reset_board()
		return false
	var board: Array = []
	for v in data.board:
		board.append(int(v))
	engine.board = board
	engine.turn = int(data.turn)
	cpu_level = clampi(int(data.get("cpu", -1)), -1, 2)
	game_active = not engine.is_over()
	win_dialog.visible = false
	_render()
	if _vs_cpu() and engine.turn == TicTacToeEngine.O and game_active:
		cpu_timer.start(CPU_DELAY)
	return game_active

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
