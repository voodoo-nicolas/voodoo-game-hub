extends Control

## Nine Men's Morris vs the computer, a friend on the same phone, or online
## (host = White, moves first; guest = Black).

const MorrisEngine = preload("res://scripts/games/morris/morris_engine.gd")
const HomeKit = preload("res://scripts/games/morris/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
## Not preloaded either: apps older than v0.14 don't have it (no Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"

const HUMAN := 1
const CPU := 2
const COLOR_LINE := Color("9b4dff")
const COLOR_BOARD := Color(0.04, 0.05, 0.11)
const COLOR_WHITE := Color(0.95, 0.98, 1.0)
const COLOR_BLACK := Color(0.06, 0.04, 0.1)
const RIM_WHITE := Color("29e6ff")
const RIM_BLACK := Color("ff2bd6")
const COLOR_HILITE := Color("7dff3a")
const COLOR_REMOVE := Color("ff4f6a")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://morris_save.json"

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: MorrisEngine
var board: Control
var status_label: Label
var info_label: Label
var cpu_timer: Timer
var end_dialog: ColorRect
var selected: int = -1
var must_remove := false
var difficulty_btn: Button
var depth: int = 2
## Two players on one phone: Black is a person, not the computer.
var two_player := false
var started := false  # a game is on (not just the one behind Home)
## Online play (null on apps without it); my_player 1 = White (host), 2 = Black.
var online: Control = null
var my_player: int = 0
## This turn's move, sent once the turn is complete: [from, to, removed].
var turn_move: Array = [-1, -1, -1]

func _ready() -> void:
	preload("res://scripts/games/morris/morris_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MorrisEngine.new()
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
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("✳️ Nine Men's Morris")
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
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

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
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_child(bottom)
	root.add_child(bm)
	difficulty_btn = Button.new()
	difficulty_btn.custom_minimum_size = Vector2(280, 64)
	difficulty_btn.add_theme_font_size_override("font_size", 26)
	difficulty_btn.pressed.connect(_toggle_difficulty)
	bottom.add_child(difficulty_btn)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 0.5
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("morris", tr(TITLE_FOR_HOME), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_reset_game)
		online.status_changed.connect(_update_labels)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/morris/morris_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _toggle_difficulty() -> void:
	depth = 3 if depth == 2 else 2
	_update_labels()

func _start_new_game() -> void:
	if online:
		online.new_game()
	_reset_game()

func _reset_game() -> void:
	started = true
	result_recorded = false
	cpu_timer.stop()
	engine.reset()
	selected = -1
	must_remove = false
	end_dialog.visible = false
	_update_labels()

func _update_labels() -> void:
	difficulty_btn.text = tr("Computer: Hard") if depth == 3 else tr("Computer: Normal")
	difficulty_btn.visible = not two_player and not _is_online()
	if two_player or _is_online():
		info_label.text = tr("White: %d to place, %d on board   ·   Black: %d to place, %d on board") % [
			engine.to_place[0], engine.count(HUMAN), engine.to_place[1], engine.count(CPU)]
	else:
		info_label.text = tr("You: %d to place, %d on board   ·   CPU: %d to place, %d on board") % [
			engine.to_place[0], engine.count(HUMAN), engine.to_place[1], engine.count(CPU)]
	var me: int = engine.turn
	var who := ((tr("White") if me == HUMAN else tr("Black")) + ": ") if two_player else ""
	if engine.winner != 0:
		status_label.text = ""
	elif _is_online() and not _my_turn():
		status_label.text = online.status_text(me == my_player, tr("White") if me == HUMAN else tr("Black"))
	elif not _person():
		status_label.text = tr("Computer is thinking...")
	elif must_remove:
		status_label.text = who + (tr("Mill! Tap a black piece to remove it.") if me == HUMAN else tr("Mill! Tap a white piece to remove it."))
	elif engine.placing(me):
		status_label.text = who + tr("Tap a point to place a piece.")
	elif engine.flying(me):
		status_label.text = who + tr("Only 3 left: you can fly anywhere!")
	else:
		status_label.text = who + tr("Select a piece, then an empty neighbour.")
	board.queue_redraw()

# ---------- player input ----------

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _my_turn() or engine.winner != 0:
		return
	var me: int = engine.turn
	var foe: int = CPU if me == HUMAN else HUMAN
	var pos := _point_at(event.position)
	if pos < 0:
		return
	if must_remove:
		if pos in engine.removable(foe):
			engine.remove_piece(pos)
			turn_move[2] = pos
			must_remove = false
			_end_human_turn()
		return
	var legal: Array = engine.moves_for(me)
	if engine.placing(me):
		if [-1, pos] in legal:
			turn_move = [-1, pos, -1]
			_after_move(engine.apply_move(-1, pos))
		return
	if engine.board[pos] == me:
		selected = pos
		board.queue_redraw()
	elif selected >= 0 and [selected, pos] in legal:
		var from := selected
		selected = -1
		turn_move = [from, pos, -1]
		_after_move(engine.apply_move(from, pos))

func _after_move(mill: bool) -> void:
	if mill and not engine.removable(CPU if engine.turn == HUMAN else HUMAN).is_empty():
		must_remove = true
		_update_labels()
		return
	_end_human_turn()

func _end_human_turn() -> void:
	engine.end_turn()
	_update_labels()
	if _is_online():
		online.send_move({"m": turn_move})
	if not _check_game_over() and not two_player and not _is_online():
		cpu_timer.start()

func _cpu_turn() -> void:
	var m: Array = engine.best_move(depth)
	engine.apply_move(m[0], m[1])
	if m[2] >= 0:
		engine.remove_piece(m[2])
	engine.end_turn()
	_update_labels()
	_check_game_over()

func _check_game_over() -> bool:
	if engine.winner == 0:
		return false
	var msg: String
	if _is_online():  # an online game ending mustn't wipe a paused local one
		var draw: bool = engine.winner == 3
		msg = tr("Draw — no mills for too long.") if draw else online.result_text(engine.winner == my_player)
		if info and not result_recorded:
			result_recorded = true
			info.result("draw" if draw else ("win" if engine.winner == my_player else "loss"), true)
		if info:
			msg += "\n" + info.summary(["Online wins", "Online losses", "Online draws"])
		end_dialog.get_meta("message_label").text = msg
		end_dialog.visible = true
		return true
	SaveUtil.delete(SAVE_PATH)
	if two_player:
		msg = tr("White wins!") if engine.winner == HUMAN else (tr("Black wins!") if engine.winner == CPU else tr("Draw — no mills for too long."))
		if info and not result_recorded:
			result_recorded = true
			info.add("White wins" if engine.winner == HUMAN else ("Black wins" if engine.winner == CPU else "2-player draws"))
			if engine.winner != 3:
				info.celebrate(msg)
		end_dialog.get_meta("message_label").text = msg
		end_dialog.visible = true
		return true
	if engine.winner == HUMAN:
		msg = tr("You win!")
	elif engine.winner == CPU:
		msg = tr("You lose!")
	else:
		msg = tr("Draw — no mills for too long.")
	msg += _record_result("win" if engine.winner == HUMAN else ("loss" if engine.winner == CPU else "draw"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	return true

# ---------- drawing ----------

func _geom() -> Dictionary:
	var side: float = min(board.size.x - 60.0, board.size.y - 30.0)
	var step := side / 6.0
	return {"step": step, "origin": Vector2((board.size.x - side) / 2.0, (board.size.y - side) / 2.0)}

func _point_pos(i: int, g: Dictionary) -> Vector2:
	return g.origin + Vector2(MorrisEngine.COORDS[i]) * g.step

func _point_at(p: Vector2) -> int:
	var g := _geom()
	for i in 24:
		if p.distance_to(_point_pos(i, g)) < g.step * 0.45:
			return i
	return -1

func _draw_board() -> void:
	if engine.board.is_empty():
		return
	var g := _geom()
	var step: float = g.step
	board.draw_rect(Rect2(g.origin - Vector2(step, step) * 0.5, Vector2(step, step) * 7.0), COLOR_BOARD)
	for m in MorrisEngine.MILLS:
		HomeKit.glow_line(board, _point_pos(m[0], g), _point_pos(m[2], g), COLOR_LINE, 2.5)
	var removable: Array = engine.removable(CPU if engine.turn == HUMAN else HUMAN) if must_remove else []
	var targets: Array = []
	if selected >= 0:
		for mv in engine.moves_for(engine.turn):
			if mv[0] == selected:
				targets.append(mv[1])
	for i in 24:
		var p := _point_pos(i, g)
		var v: int = engine.board[i]
		if v == MorrisEngine.EMPTY:
			board.draw_circle(p, step * 0.1, COLOR_LINE)
			if i in targets:
				board.draw_circle(p, step * 0.2, Color(COLOR_HILITE, 0.5))
			continue
		var col := COLOR_WHITE if v == HUMAN else COLOR_BLACK
		board.draw_circle(p, step * 0.32, col)
		HomeKit.glow_circle(board, p, step * 0.32, RIM_WHITE if v == HUMAN else RIM_BLACK, 2.0)
		if i == selected:
			board.draw_arc(p, step * 0.38, 0, TAU, 32, COLOR_HILITE, 5)
		elif i in removable:
			board.draw_arc(p, step * 0.38, 0, TAU, 32, COLOR_REMOVE, 4)


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/morris/morris_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/morris/morris_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Line up three to form a mill and take a piece.",
		"logo": _draw_home_logo,
		"solo_heading": "vs Computer",
		"modes": [
			{"text": "😐 Normal", "row": "cpu", "color": HomeKit.CYAN, "action": _new_game.bind(2, false)},
			{"text": "😈 Hard", "row": "cpu", "color": HomeKit.PINK, "action": _new_game.bind(3, false)},
			{"text": "👥 2 Players", "sub": "White and Black share one phone", "multi": true, "action": _new_game.bind(2, true)},
		] + ([{"text": "🌐 Online", "sub": "Play a friend on another phone", "multi": true,
			"color": HomeKit.PURPLE, "action": online.open_lobby}] if online else []),
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): var d = SaveUtil.read(SAVE_PATH); return "" if d == null else (tr("2 Players") if bool(d.get("two", false)) else tr("vs Computer")),
		"restart": _start_new_game,
		"board": "Wins",
		"board_note": "Games won against the computer.",
		"online": online,
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var s := minf(c.size.y * 0.9, 160.0)
	var o := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	for k in [1.0, 0.66, 0.33]:
		HomeKit.glow_rect(c, Rect2(o - Vector2(s, s) * 0.5 * k, Vector2(s, s) * k), COLOR_LINE, 2.0)
	for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		HomeKit.glow_line(c, o + d * s * 0.165, o + d * s * 0.5, COLOR_LINE, 2.0)
	for p in [Vector2(-0.5, -0.5), Vector2(0, -0.5), Vector2(0.5, -0.5)]:
		HomeKit.glow_circle(c, o + p * s, s * 0.07, RIM_WHITE, 2.0, 0.9)
	for p in [Vector2(-0.33, 0.33), Vector2(0.33, 0), Vector2(0.165, 0.165)]:
		c.draw_circle(o + p * s, s * 0.07, COLOR_BLACK)
		HomeKit.glow_circle(c, o + p * s, s * 0.07, RIM_BLACK, 2.0)

func _new_game(d: int, two: bool) -> void:
	depth = d
	two_player = two
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

## Is a person (not the computer) to move?
func _person() -> bool:
	return engine.turn == HUMAN or two_player or _is_online()

## May the player on this phone touch the board now?
func _my_turn() -> bool:
	if _is_online():
		return online.can_act(engine.turn == my_player)
	return _person()

func _is_online() -> bool:
	return online != null and online.is_online()

# ---------- online ----------

func _online_state() -> Dictionary:
	return {"board": engine.board, "to_place": engine.to_place, "turn": engine.turn,
		"quiet": engine.quiet_moves, "winner": engine.winner}

func _on_online_started(p_my_player: int) -> void:
	my_player = p_my_player
	two_player = false
	home.hide_home()
	_reset_game()

## The other player's whole turn: [from, to, removed] (-1 = none).
func _on_remote_move(p: Dictionary) -> void:
	var m: Array = p.get("m", [])
	if engine.winner != 0 or engine.turn == my_player or m.size() != 3:
		return
	var from := int(m[0])
	var to := int(m[1])
	var removed := int(m[2])
	if not ([from, to] in engine.moves_for(engine.turn)):
		return  # out of step: the state check that follows resyncs us
	var mill := engine.apply_move(from, to)
	if mill and removed in engine.removable(3 - engine.turn):
		engine.remove_piece(removed)
	engine.end_turn()
	selected = -1
	must_remove = false
	_update_labels()
	_check_game_over()

func _on_remote_state(st: Dictionary) -> void:
	var b := _ints(st.get("board", []))
	if b.size() != 24:
		return
	engine.board = b
	engine.to_place = _ints(st.get("to_place", [9, 9]))
	engine.turn = int(st.get("turn", 1))
	engine.quiet_moves = int(st.get("quiet", 0))
	engine.winner = int(st.get("winner", 0))
	selected = -1
	must_remove = false
	end_dialog.visible = false
	_update_labels()
	_check_game_over()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

## Saved when a person is to move, so a computer turn replays from there.
func _save_game() -> void:
	if _is_online() or not started or engine.winner != 0 or not _person() or must_remove:
		return
	SaveUtil.write(SAVE_PATH, {"board": engine.board, "to_place": engine.to_place, "turn": engine.turn,
		"quiet": engine.quiet_moves, "depth": depth, "two": two_player})

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

static func _grid(a: Variant, as_bool: bool) -> Array:
	var out: Array = []
	for row in a:
		var r: Array = []
		for v in row:
			r.append(bool(v) if as_bool else int(v))
		out.append(r)
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	depth = int(d.get("depth", 2))
	two_player = bool(d.get("two", false))
	_start_new_game()
	engine.board = _ints(d.board)
	engine.to_place = _ints(d.to_place)
	engine.turn = int(d.turn)
	engine.quiet_moves = int(d.get("quiet", 0))
	_update_labels()
	if not _person():
		cpu_timer.start()
