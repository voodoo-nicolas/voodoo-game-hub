extends Control

const CheckersEngine = preload("res://scripts/games/checkers/checkers_engine.gd")
const HomeKit = preload("res://scripts/games/checkers/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://checkers_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"

const COLOR_DARK_SQUARE := Color(0.07, 0.1, 0.2)
const COLOR_LIGHT_SQUARE := Color(0.12, 0.16, 0.3)
const COLOR_SELECTED := HomeKit.GOLD
const COLOR_DEST := HomeKit.LIME
const COLOR_P1 := Color("ff3b6b")
const COLOR_P2 := Color("bff6ff")
const LEVELS := ["Easy", "Medium", "Hard"]
## Pause before the computer moves, and between the hops of a multi-jump.
const CPU_DELAY := 0.55
const CPU_STEP := 0.4

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var game_active: bool = false
var selected: Vector2i = Vector2i(-1, -1)
var dest_map: Dictionary = {}  # Vector2i(dest) -> Vector2i(captured) or (-1,-1)

var squares: Array = []  # 8x8 Buttons
var piece_views: Array = []  # 8x8 Panel (may be null-equivalent hidden)
var king_labels: Array = []  # 8x8 Label
var status_label: Label
var win_dialog: Control
var win_label: Label
var home  # HomeKit
## -1 = two players on one phone; 0..2 = against the computer, which plays White.
var cpu_level: int = -1
var cpu_steps: Array = []  # the computer's turn still to show, [from, to] each
var cpu_timer: Timer
var rng := RandomNumberGenerator.new()
## Online play (null on apps without it). Host is Player 1 (red, bottom),
## guest Player 2 (white) and sees the board flipped so their own pieces are
## at the bottom. my_side: 1 / -1 as the engine counts; 0 = same-phone play.
var online: Control = null
var my_side: int = 0
var flipped: bool = false

func _ready() -> void:
	preload("res://scripts/games/checkers/checkers_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = CheckersEngine.new()
	_build_ui()
	_reset_board()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg_rect = HomeKit.backdrop()
	add_child(bg_rect)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
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
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var title := Label.new()
	title.text = tr("Checkers")
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.93))
	title.add_theme_color_override("font_outline_color", Color(COLOR_P1, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 32)
	status_label.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var viewport_width: float = get_viewport_rect().size.x
	var board_margin := 12.0
	var cell_size: float = floor((viewport_width - board_margin * 2.0) / 8.0)
	var board_size: float = cell_size * 8.0

	var board_wrap := Control.new()
	board_wrap.custom_minimum_size = Vector2(board_size, board_size)
	center.add_child(board_wrap)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	board_wrap.add_child(grid)

	squares.resize(64)
	piece_views.resize(64)
	king_labels.resize(64)

	for r in range(8):
		for c in range(8):
			var idx := r * 8 + c
			var sq := Button.new()
			sq.custom_minimum_size = Vector2(cell_size, cell_size)
			sq.flat = false
			sq.focus_mode = Control.FOCUS_NONE
			sq.pressed.connect(_on_square_pressed.bind(r, c))
			grid.add_child(sq)
			squares[idx] = sq

			var piece := PanelContainer.new()
			piece.custom_minimum_size = Vector2(cell_size * 0.78, cell_size * 0.78)
			piece.size = piece.custom_minimum_size
			piece.position = Vector2(cell_size * 0.11, cell_size * 0.11)
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piece.visible = false
			sq.add_child(piece)
			piece_views[idx] = piece

			var king_label := Label.new()
			king_label.text = "♛"
			king_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			king_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			king_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			king_label.add_theme_font_size_override("font_size", int(cell_size * 0.4))
			king_label.add_theme_color_override("font_color", Color(1, 0.84, 0.1))
			king_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			king_label.visible = false
			piece.add_child(king_label)
			king_labels[idx] = king_label

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_step)
	add_child(cpu_timer)

	_build_win_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("checkers", tr("Checkers"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_reset_board)
		online.status_changed.connect(_render)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/checkers/checkers_help.gd"))
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
		"help": preload("res://scripts/games/checkers/checkers_help.gd"),
		"info": info,
		"accent": COLOR_P1,
		"solo_heading": "vs Computer",
		"subtitle": "Jump, capture, crown your kings. Beat the computer or a friend.",
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
	var n := 4
	var k := minf(c.size.y / (n + 0.4), 44.0)
	var o := Vector2((c.size.x - k * n) / 2.0, (c.size.y - k * n) / 2.0)
	for y in n:
		for x in n:
			if (x + y) % 2 == 1:
				c.draw_rect(Rect2(o + Vector2(x, y) * k, Vector2(k, k)), Color(HomeKit.BLUE, 0.18))
	HomeKit.glow_rect(c, Rect2(o, Vector2(k * n, k * n)), HomeKit.BLUE, 2.5)
	var pieces := {Vector2i(1, 0): COLOR_P2, Vector2i(3, 0): COLOR_P2, Vector2i(2, 1): COLOR_P2,
		Vector2i(1, 2): COLOR_P1, Vector2i(0, 3): COLOR_P1, Vector2i(2, 3): COLOR_P1}
	for p in pieces:
		HomeKit.glow_circle(c, o + (Vector2(p) + Vector2(0.5, 0.5)) * k, k * 0.36, pieces[p], 2.5, 0.3)
	# a jump arrow: red takes white
	var from := o + Vector2(1.5, 2.5) * k
	var to := o + Vector2(3.5, 0.5) * k
	HomeKit.glow_line(c, from, to, HomeKit.GOLD, 2.0)
	HomeKit.glow_line(c, to, to + Vector2(-k * 0.35, k * 0.05), HomeKit.GOLD, 2.0)
	HomeKit.glow_line(c, to, to + Vector2(-k * 0.05, k * 0.35), HomeKit.GOLD, 2.0)
	HomeKit.glow_text(c, o + Vector2(0.5, 3.5) * k, "♛", int(k * 0.42), HomeKit.GOLD)

func _new_vs_cpu(level: int) -> void:
	cpu_level = level
	SaveUtil.delete(SAVE_PATH)
	_reset_board()

func _new_two_player() -> void:
	cpu_level = -1
	SaveUtil.delete(SAVE_PATH)
	_reset_board()

func _vs_cpu() -> bool:
	return cpu_level >= 0 and not _is_online()

## Plans the computer's whole turn, then shows it one hop at a time.
func _maybe_cpu() -> void:
	if game_active and _vs_cpu() and engine.current_player == -1 and cpu_steps.is_empty():
		cpu_steps = engine.cpu_turn(cpu_level, rng)
		if not cpu_steps.is_empty():
			cpu_timer.start(CPU_DELAY)
			_render()

func _cpu_step() -> void:
	if not game_active or cpu_steps.is_empty():
		return
	var s: Array = cpu_steps.pop_front()
	_move_sfx(engine.move(s[0], s[1]))
	selected = s[1] if not cpu_steps.is_empty() else Vector2i(-1, -1)
	_render()
	if engine.game_over:
		cpu_steps.clear()
		_show_result()
	elif not cpu_steps.is_empty():
		cpu_timer.start(CPU_STEP)

func _resume_text() -> String:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return ""
	var lvl := int(data.get("cpu", -1))
	return tr("2 Players") if lvl < 0 else tr(LEVELS[clampi(lvl, 0, 2)])

func _build_win_dialog() -> void:
	win_dialog = Ui.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 Checkers Home"), "action": _go_home},
	], true)
	add_child(win_dialog)
	win_label = win_dialog.get_meta("message_label")

func _go_home() -> void:
	home.go_home()

func _is_online() -> bool:
	return online != null and online.is_online()

func _start_new_game() -> void:
	if online:
		online.new_game()
	_reset_board()

func _reset_board() -> void:
	engine.reset()
	cpu_timer.stop()
	cpu_steps.clear()
	game_active = true
	selected = Vector2i(-1, -1)
	dest_map = {}
	win_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	home.pause()

## Screen square -> board square. The guest's view is rotated 180 degrees.
func _view_index(r: int, c: int) -> int:
	return (7 - r) * 8 + (7 - c) if flipped else r * 8 + c

func _on_square_pressed(vr: int, vc: int) -> void:
	if not game_active:
		return
	if _is_online() and not online.can_act(engine.current_player == my_side):
		return
	if _vs_cpu() and (engine.current_player != 1 or not cpu_steps.is_empty()):
		return  # the computer's turn
	var r: int = 7 - vr if flipped else vr
	var c: int = 7 - vc if flipped else vc
	var pos := Vector2i(r, c)

	if dest_map.has(pos):
		var from := selected
		var result: Dictionary = engine.move(selected, pos)
		if result.valid:
			_move_sfx(result)
			if _is_online():
				online.send_move({"from": [from.x, from.y], "to": [pos.x, pos.y]})
			if result.chain_continues:
				selected = pos
			else:
				selected = Vector2i(-1, -1)
			_render()
			if engine.game_over:
				_show_result()
			else:
				_maybe_cpu()
		return

	if pos == selected:
		selected = Vector2i(-1, -1)
		_render()
		return

	if engine.must_continue_from.x >= 0:
		return  # mid-chain: only the forced piece's destinations are selectable

	var lm: Dictionary = engine.legal_moves_for(r, c)
	if not lm.captures.is_empty() or not lm.moves.is_empty():
		selected = pos
	else:
		selected = Vector2i(-1, -1)
	_render()

# ---------- online ----------

func _online_state() -> Dictionary:
	return {
		"board": engine.board, "current_player": engine.current_player,
		"must_continue_from": [engine.must_continue_from.x, engine.must_continue_from.y],
		"quiet_moves": engine.quiet_moves, "game_over": engine.game_over, "winner": engine.winner,
	}

func _on_online_started(my_player: int) -> void:
	my_side = 1 if my_player == 1 else -1
	flipped = my_side == -1
	cpu_level = -1
	home.hide_home()
	_reset_board()

func _on_remote_move(p: Dictionary) -> void:
	if not game_active or engine.current_player == my_side:
		return
	var f: Array = p.get("from", [-1, -1])
	var t: Array = p.get("to", [-1, -1])
	var result: Dictionary = engine.move(Vector2i(int(f[0]), int(f[1])), Vector2i(int(t[0]), int(t[1])))
	if result.valid:
		_move_sfx(result)
		selected = Vector2i(-1, -1)
		_render()
		if engine.game_over:
			_show_result()

func _on_remote_state(st: Dictionary) -> void:
	var board: Array = []
	for row in st.get("board", []):
		var r: Array = []
		for v in row:
			r.append(int(v))
		board.append(r)
	if board.size() != 8:
		return
	engine.board = board
	engine.current_player = int(st.get("current_player", 1))
	var mc: Array = st.get("must_continue_from", [-1, -1])
	engine.must_continue_from = Vector2i(int(mc[0]), int(mc[1]))
	engine.quiet_moves = int(st.get("quiet_moves", 0))
	engine.game_over = bool(st.get("game_over", false))
	engine.winner = int(st.get("winner", 0))
	game_active = not engine.game_over
	selected = Vector2i(-1, -1)
	win_dialog.visible = false
	_render()
	if engine.game_over:
		_show_result()

func _show_result() -> void:
	var just_ended := game_active  # a resync of a finished game isn't a new result
	game_active = false
	if not _is_online():  # an online game ending mustn't wipe a paused local one
		SaveUtil.delete(SAVE_PATH)
	if engine.winner == 0:
		win_label.text = tr("Draw — 40 moves each with no captures")
	elif _is_online():
		win_label.text = online.result_text(engine.winner == my_side)
	elif _vs_cpu():
		win_label.text = tr("You win!") if engine.winner == 1 else tr("The computer wins!")
	else:
		win_label.text = tr("Player %d wins!") % (1 if engine.winner == 1 else 2)
	if info and just_ended:
		if _is_online():
			info.result("draw" if engine.winner == 0 else ("win" if engine.winner == my_side else "loss"), true)
			win_label.text += "\n" + info.summary(["Online wins", "Online losses", "Online draws"])
		elif _vs_cpu():
			info.result("draw" if engine.winner == 0 else ("win" if engine.winner == 1 else "loss"))
			if engine.winner == 1:
				info.add("Wins (%s)" % LEVELS[cpu_level])
			win_label.text += "\n" + info.summary(["Wins", "Losses", "Draws"])
		else:
			info.add("Draws" if engine.winner == 0 else ("Red wins" if engine.winner == 1 else "White wins"))
			if not (engine.winner == 0):
				info.celebrate(win_label.text.split("\n")[0])
			win_label.text += "\n" + info.summary(["Red wins", "White wins"])
	win_dialog.visible = true

# ---------- rendering ----------

## Look (STANDARDS §9): "classic" = wooden board, red and white pieces
## (default); "voodoo" = the neon board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg_rect: ColorRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg_rect and bg_rect.get_child_count() > 0:
		bg_rect.get_child(0).visible = skin != "classic"
	if bg_rect:
		bg_rect.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
	_render()

func _square_color(dark: bool) -> Color:
	if skin == "classic":
		return HomeKit.CLASSIC.wood_dark if dark else HomeKit.CLASSIC.wood_light
	return COLOR_DARK_SQUARE if dark else COLOR_LIGHT_SQUARE

func _piece_color(p1: bool) -> Color:
	if skin == "classic":
		return HomeKit.CLASSIC.red_piece if p1 else HomeKit.CLASSIC.white_piece
	return COLOR_P1 if p1 else COLOR_P2

func _render() -> void:
	dest_map = {}
	if selected.x >= 0:
		var lm: Dictionary = engine.legal_moves_for(selected.x, selected.y)
		var moves: Array = lm.captures if not lm.captures.is_empty() else lm.moves
		for m in moves:
			if lm.captures.is_empty():
				dest_map[m] = Vector2i(-1, -1)
			else:
				dest_map[m.to] = m.captured

	for r in range(8):
		for c in range(8):
			var idx := _view_index(r, c)
			var sq: Button = squares[idx]
			var is_dark: bool = (r + c) % 2 == 1
			var pos := Vector2i(r, c)

			var square_color: Color = _square_color(is_dark)
			var edge := Color(0, 0, 0, 0)
			if pos == selected:
				edge = COLOR_SELECTED
			elif dest_map.has(pos):
				edge = COLOR_DEST
			_style_square(sq, square_color, edge)

			var v: int = engine.board[r][c]
			var piece: PanelContainer = piece_views[idx]
			var king_label: Label = king_labels[idx]
			if v == 0:
				piece.visible = false
			else:
				piece.visible = true
				var owner_color: Color = _piece_color(v > 0)
				_style_piece(piece, owner_color)
				king_label.visible = absi(v) == 2

	if not game_active:
		return
	if _is_online():
		var turn_text := tr("Red") if engine.current_player == 1 else tr("White")
		if engine.must_continue_from.x >= 0:
			turn_text += tr(" — keep capturing!")
		status_label.text = online.status_text(engine.current_player == my_side, turn_text)
	elif _vs_cpu():
		if engine.current_player == -1:
			status_label.text = tr("Computer is thinking...")
		elif engine.must_continue_from.x >= 0:
			status_label.text = tr("Keep capturing!")
		else:
			status_label.text = tr("Your turn (%s)") % tr("Red")
	elif engine.must_continue_from.x >= 0:
		status_label.text = tr("Player %d must continue capturing!") % (1 if engine.current_player == 1 else 2)
	else:
		status_label.text = tr("Player %d's turn") % (1 if engine.current_player == 1 else 2)

func _style_square(sq: Button, color: Color, edge: Color = Color(0, 0, 0, 0)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color if edge.a == 0.0 else color.lerp(edge, 0.25)
	if edge.a > 0.0:
		sb.border_color = edge
		sb.set_border_width_all(3)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		sq.add_theme_stylebox_override(state, sb)

func _style_piece(piece: PanelContainer, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	if skin == "classic":
		# A solid disc with a darker rim and a plain drop shadow.
		sb.bg_color = color
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(1, 2)
		var radius_c: int = int(piece.custom_minimum_size.x / 2.0)
		sb.set_corner_radius_all(radius_c)
		sb.set_border_width_all(4)
		sb.border_color = color.darkened(0.3)
		piece.add_theme_stylebox_override("panel", sb)
		return
	sb.bg_color = Color(color, 0.28)
	sb.shadow_color = Color(color, 0.45)
	sb.shadow_size = 6
	var radius: int = int(piece.custom_minimum_size.x / 2.0)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.set_border_width_all(4)
	sb.border_color = color
	piece.add_theme_stylebox_override("panel", sb)

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or _is_online():
		return  # online games aren't resumable alone
	SaveUtil.write(SAVE_PATH, {
		"board": engine.board,
		"current_player": engine.current_player,
		"must_continue_from": [engine.must_continue_from.x, engine.must_continue_from.y],
		"quiet_moves": engine.quiet_moves,
		"cpu": cpu_level,
	})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		_reset_board()
		return false
	var board: Array = []
	for row in data.board:
		var r: Array = []
		for v in row:
			r.append(int(v))
		board.append(r)
	engine.board = board
	engine.current_player = int(data.current_player)
	var mc: Array = data.must_continue_from
	engine.must_continue_from = Vector2i(int(mc[0]), int(mc[1]))
	engine.quiet_moves = int(data.get("quiet_moves", 0))
	engine.game_over = false
	engine.winner = 0
	game_active = true
	selected = Vector2i(-1, -1)
	cpu_level = clampi(int(data.get("cpu", -1)), -1, 2)
	cpu_steps.clear()
	win_dialog.visible = false
	_render()
	_maybe_cpu()
	return true

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _move_sfx(result: Dictionary) -> void:
	if not result.get("valid", false):
		return
	if result.get("captured", Vector2i(-1, -1)) != Vector2i(-1, -1):
		_sfx("capture")
	elif result.get("promoted", false):
		_sfx("powerup")
	else:
		_sfx("place")
