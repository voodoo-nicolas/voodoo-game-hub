extends Control

## Five in a Row: vs the computer (three levels), two players on one phone,
## or online (host = Black, moves first; guest = White).

const GomokuEngine = preload("res://scripts/games/five_in_row/five_in_row_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/five_in_row/home_kit.gd")
## Not preloaded: apps before v0.20 / v0.14 don't have these.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
const HELP := preload("res://scripts/games/five_in_row/five_in_row_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://five_in_row_save.json"

const LEVELS := ["Easy", "Normal", "Hard"]
const CPU_DELAY := 0.45
const COLOR_GRID := Color("3a8cff")
const RIM := [Color.WHITE, Color("ff2bd6"), Color("29e6ff")]   # index = player
const FILL := [Color.WHITE, Color(0.08, 0.03, 0.12), Color(0.9, 0.97, 1.0)]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
## -1 = two players on one phone; 0..2 = vs the computer (you are Black).
var cpu_level: int = 1
var started := false
var result_recorded := false
var online: Control = null
var my_player: int = 0

var board: Control
var status_label: Label
var cpu_timer: Timer
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/five_in_row/five_in_row_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = GomokuEngine.new()
	_build_ui()
	_reset_board()
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
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("Five in a Row")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.MAGENTA.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.MAGENTA, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_start_new_game)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 30)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_bottom", 40)
	bm.add_child(board)
	root.add_child(bm)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("five_in_row", tr(TITLE_FOR_HOME), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_reset_board)
		online.status_changed.connect(_render)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "row": "cpu",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	modes.append({"text": "👥 2 Players", "sub": "Black and White share one phone", "multi": true, "action": _new_game.bind(-1)})
	if online:
		modes.append({"text": "🌐 Online", "sub": "Play a friend on another phone", "multi": true,
			"color": HomeKit.PURPLE, "action": online.open_lobby})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.MAGENTA,
		"solo_heading": "vs Computer",
		"subtitle": "Get five stones in a row before your opponent does.",
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
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.975)  # under the board
	add_child(drawer)

# ---------- game flow ----------

func _new_game(level: int) -> void:
	cpu_level = level
	SaveUtil.delete(SAVE_PATH)
	_reset_board()

func _start_new_game() -> void:
	if online:
		online.new_game()
	_reset_board()

func _reset_board() -> void:
	engine.reset()
	cpu_timer.stop()
	started = true
	result_recorded = false
	end_dialog.visible = false
	_render()

func _is_online() -> bool:
	return online != null and online.is_online()

func _vs_cpu() -> bool:
	return cpu_level >= 0 and not _is_online()

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if engine.winner != 0:
		return
	if _is_online() and not online.can_act(engine.turn == my_player):
		return
	if _vs_cpu() and engine.turn != 1:
		return
	var g := _geom()
	var p: Vector2 = (event.position - g.origin) / g.step
	var x := int(round(p.x))
	var y := int(round(p.y))
	if x < 0 or y < 0 or x >= GomokuEngine.SIZE or y >= GomokuEngine.SIZE:
		return
	if _play(y * GomokuEngine.SIZE + x) and _is_online():
		online.send_move({"i": y * GomokuEngine.SIZE + x})

func _play(i: int) -> bool:
	if not engine.play(i):
		return false
	_sfx("place")
	_render()
	if engine.winner != 0:
		_show_result()
	elif _vs_cpu() and engine.turn == 2:
		cpu_timer.start(CPU_DELAY)
	return true

func _cpu_turn() -> void:
	if engine.winner == 0 and _vs_cpu() and engine.turn == 2:
		_play(engine.cpu_move(cpu_level, rng))

func _show_result() -> void:
	var just_ended := not result_recorded
	result_recorded = true
	var w: int = engine.winner
	var msg: String
	if not _is_online():
		SaveUtil.delete(SAVE_PATH)
	if w == 3:
		msg = tr("It's a draw!")
	elif _is_online():
		msg = online.result_text(w == my_player)
	elif _vs_cpu():
		msg = tr("You win!") if w == 1 else tr("The computer wins!")
	else:
		msg = tr("Black wins!") if w == 1 else tr("White wins!")
	if info and just_ended:
		if _is_online():
			info.result("draw" if w == 3 else ("win" if w == my_player else "loss"), true)
			msg += "\n" + info.summary(["Online wins", "Online losses"])
		elif _vs_cpu():
			info.result("draw" if w == 3 else ("win" if w == 1 else "loss"))
			if w == 1:
				info.add("Wins (%s)" % LEVELS[cpu_level])
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
		else:
			info.add("Black wins" if w == 1 else ("White wins" if w == 2 else "2-player draws"))
			if w != 3:
				info.celebrate(msg)
	end_dialog.get_meta("message_label").text = msg
	var t := create_tween()
	t.tween_interval(0.9)
	t.tween_callback(func(): end_dialog.visible = engine.winner != 0)

func _render() -> void:
	var t: int = engine.turn
	var color_name := tr("Black") if t == 1 else tr("White")
	if engine.winner != 0:
		status_label.text = ""
	elif _is_online():
		status_label.text = online.status_text(t == my_player, color_name)
	elif _vs_cpu():
		status_label.text = tr("Your turn (%s)") % tr("Black") if t == 1 else tr("Computer is thinking...")
	else:
		status_label.text = tr("%s to play") % color_name
	status_label.add_theme_color_override("font_color", RIM[t].lerp(Color.WHITE, 0.4))
	board.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var n := GomokuEngine.SIZE
	var side: float = minf(board.size.x - 40.0, board.size.y - 20.0)
	var step: float = floor(side / n)
	var span := step * (n - 1)
	return {"step": step, "origin": Vector2((board.size.x - span) / 2.0, (board.size.y - span) / 2.0)}

## Look (STANDARDS §9): "classic" = a wooden board, black and white stones (default); "voodoo" = the neon
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
	if engine.board.is_empty():
		return
	var g := _geom()
	var n := GomokuEngine.SIZE
	var step: float = g.step
	var o: Vector2 = g.origin
	var span := step * (n - 1)
	var grid_col: Color = COLOR_GRID
	if _is_classic():
		grid_col = HomeKit.CLASSIC.wood_frame
		board.draw_rect(Rect2(o, Vector2(span, span)).grow(step * 0.6), HomeKit.CLASSIC.wood_light)
	else:
		board.draw_rect(Rect2(o, Vector2(span, span)).grow(step * 0.6), Color(0.03, 0.04, 0.1))
		HomeKit.glow_rect(board, Rect2(o, Vector2(span, span)).grow(step * 0.6), Color(HomeKit.PURPLE, 0.8), 2.0)
	for k in n:
		var a := 0.55 if k == 0 or k == n - 1 else 0.3
		board.draw_line(o + Vector2(k * step, 0), o + Vector2(k * step, span), Color(grid_col, 1.0 if _is_classic() else a), 1.5)
		board.draw_line(o + Vector2(0, k * step), o + Vector2(span, k * step), Color(grid_col, 1.0 if _is_classic() else a), 1.5)
	for s in [[3, 3], [11, 3], [7, 7], [3, 11], [11, 11]]:
		board.draw_circle(o + Vector2(s[0], s[1]) * step, step * 0.09, Color(grid_col, 0.8))
	var r := step * 0.42
	for i in engine.board.size():
		var v: int = engine.board[i]
		if v == 0:
			continue
		var c := o + Vector2(i % n, i / n) * step
		if _is_classic():
			var cc: Color = HomeKit.CLASSIC.black_piece if v == 1 else HomeKit.CLASSIC.white_piece
			board.draw_circle(c + Vector2(1, 2), r, Color(0, 0, 0, 0.35))
			board.draw_circle(c, r, cc)
			board.draw_arc(c, r, 0, TAU, 28, cc.darkened(0.4) if v == 1 else Color("b9b3a3"), 2.0, true)
		else:
			board.draw_circle(c, r, FILL[v])
			HomeKit.glow_circle(board, c, r, RIM[v], 2.0)
	if engine.last >= 0:
		var lc := o + Vector2(engine.last % n, engine.last / n) * step
		board.draw_circle(lc, r * 0.25, HomeKit.CLASSIC.red if _is_classic() else HomeKit.GOLD)
	if engine.line.size() >= 5:
		var pts: Array = engine.line.duplicate()
		pts.sort()
		var a2 := o + Vector2(pts[0] % n, pts[0] / n) * step
		var b2 := o + Vector2(pts[-1] % n, pts[-1] / n) * step
		HomeKit.glow_line(board, a2, b2, HomeKit.LIME, 5.0)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 5.0, 34.0)
	var o := c.size / 2.0 - Vector2(k * 2.5, k * 2.0)
	for i in 6:
		c.draw_line(o + Vector2(i * k, 0), o + Vector2(i * k, k * 4), Color(COLOR_GRID, 0.4), 1.5)
	for i in 5:
		c.draw_line(o + Vector2(0, i * k), o + Vector2(k * 5, i * k), Color(COLOR_GRID, 0.4), 1.5)
	for i in 5:
		var p := o + Vector2(i + 0.0, 4.0 - i) * k
		c.draw_circle(p, k * 0.4, FILL[1])
		HomeKit.glow_circle(c, p, k * 0.4, RIM[1], 2.0)
	for q in [Vector2(1, 1), Vector2(3, 3), Vector2(4, 2)]:
		c.draw_circle(o + q * k, k * 0.4, FILL[2])
		HomeKit.glow_circle(c, o + q * k, k * 0.4, RIM[2], 2.0)
	HomeKit.glow_line(c, o + Vector2(0, 4) * k, o + Vector2(4, 0) * k, HomeKit.LIME, 3.0)

# ---------- online ----------

func _online_state() -> Dictionary:
	return {"board": engine.board, "turn": engine.turn, "winner": engine.winner, "last": engine.last, "line": engine.line}

func _on_online_started(p: int) -> void:
	my_player = p
	cpu_level = -1
	home.hide_home()
	_reset_board()

func _on_remote_move(p: Dictionary) -> void:
	if engine.winner == 0 and engine.turn != my_player:
		_play(int(p.get("i", -1)))

func _on_remote_state(st: Dictionary) -> void:
	var b: Array = []
	for v in st.get("board", []):
		b.append(int(v))
	if b.size() != GomokuEngine.SIZE * GomokuEngine.SIZE:
		return
	engine.board = b
	engine.turn = int(st.get("turn", 1))
	engine.winner = int(st.get("winner", 0))
	engine.last = int(st.get("last", -1))
	engine.line = []
	for v in st.get("line", []):
		engine.line.append(int(v))
	end_dialog.visible = false
	_render()
	if engine.winner != 0:
		_show_result()

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.winner != 0 or _is_online():
		return
	if _vs_cpu() and engine.turn == 2:
		return  # the computer's move is a moment away; save after it
	SaveUtil.write(SAVE_PATH, {"board": engine.board, "turn": engine.turn, "last": engine.last, "cpu": cpu_level})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var lvl := int(d.get("cpu", -1))
	return tr("2 Players") if lvl < 0 else tr(LEVELS[clampi(lvl, 0, 2)])

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or d.get("board", []).size() != GomokuEngine.SIZE * GomokuEngine.SIZE:
		_reset_board()
		return
	cpu_level = clampi(int(d.get("cpu", -1)), -1, 2)
	_reset_board()
	for i in engine.board.size():
		engine.board[i] = int(d.board[i])
	engine.turn = int(d.get("turn", 1))
	engine.last = int(d.get("last", -1))
	_render()
	if _vs_cpu() and engine.turn == 2:
		cpu_timer.start(CPU_DELAY)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
