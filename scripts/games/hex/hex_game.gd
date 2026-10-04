extends Control

## Hex: Red joins top to bottom, Blue joins left to right. Vs the computer
## (three levels, you are Red), two players on one phone, or online (host =
## Red, moves first; guest = Blue).

const HexEngine = preload("res://scripts/games/hex/hex_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/hex/home_kit.gd")
## Not preloaded: apps before v0.20 / v0.14 don't have these.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
const HELP := preload("res://scripts/games/hex/hex_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://hex_save.json"

const SIZE := 9
const LEVELS := ["Easy", "Normal", "Hard"]
const CPU_DELAY := 0.35
const COLORS := [Color.WHITE, Color("ff4f6a"), Color("29a8ff")]  # index = player

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
## -1 = two players on one phone; 0..2 = vs the computer (you are Red).
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
	preload("res://scripts/games/hex/hex_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = HexEngine.new()
	_build_ui()
	_reset_board()
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

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
	title.text = tr("Hex")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.95))
	title.add_theme_color_override("font_outline_color", Color(COLORS[1], 0.5))
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
	status_label.add_theme_font_size_override("font_size", 28)
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
		online = load(ONLINE_MATCH_PATH).new("hex", tr(TITLE_FOR_HOME), _online_state)
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
	modes.append({"text": "👥 2 Players", "sub": "Red and Blue share one phone", "multi": true, "action": _new_game.bind(-1)})
	if online:
		modes.append({"text": "🌐 Online", "sub": "Play a friend on another phone", "multi": true,
			"color": HomeKit.PURPLE, "action": online.open_lobby})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": COLORS[1],
		"solo_heading": "vs Computer",
		"subtitle": "Red links top to bottom, Blue links left to right. No draws.",
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
	engine.reset(SIZE)
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
	var i := _cell_at(event.position)
	if i >= 0 and _play(i) and _is_online():
		online.send_move({"i": i})

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
	if _is_online():
		msg = online.result_text(w == my_player)
	elif _vs_cpu():
		msg = tr("You win!") if w == 1 else tr("The computer wins!")
	else:
		msg = tr("Red wins!") if w == 1 else tr("Blue wins!")
	if info and just_ended:
		if _is_online():
			info.result("win" if w == my_player else "loss", true)
			msg += "\n" + info.summary(["Online wins", "Online losses"])
		elif _vs_cpu():
			info.result("win" if w == 1 else "loss")
			if w == 1:
				info.add("Wins (%s)" % LEVELS[cpu_level])
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
		else:
			info.add("Red wins" if w == 1 else "Blue wins")
			info.celebrate(msg)
	end_dialog.get_meta("message_label").text = msg
	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_callback(_show_end)

func _show_end() -> void:
	end_dialog.visible = engine.winner != 0

func _render() -> void:
	var t: int = engine.turn
	var side_name := tr("Red") if t == 1 else tr("Blue")
	if engine.winner != 0:
		status_label.text = ""
	elif _is_online():
		status_label.text = online.status_text(t == my_player, side_name)
	elif _vs_cpu():
		status_label.text = tr("Your turn (%s)") % tr("Red") if t == 1 else tr("Computer is thinking...")
	else:
		status_label.text = tr("%s to play") % side_name
	status_label.add_theme_color_override("font_color", COLORS[t].lerp(Color.WHITE, 0.35))
	board.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var n := SIZE
	var cols_span := n + (n - 1) * 0.5      # hex widths across
	var w: float = minf((board.size.x - 40.0) / cols_span, (board.size.y - 40.0) * sqrt(3.0) / ((n - 1) * 1.5 + 2.0))
	var r := w / sqrt(3.0)
	var span := Vector2(cols_span * w, (n - 1) * 1.5 * r + 2.0 * r)
	var o := (board.size - span) / 2.0 + Vector2(w / 2.0, r)
	return {"w": w, "r": r, "o": o}

func _center(i: int, g: Dictionary) -> Vector2:
	var x := i % SIZE
	var y := i / SIZE
	return g.o + Vector2((x + y * 0.5) * g.w, y * 1.5 * g.r)

func _hex_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(c + Vector2.UP.rotated(TAU * k / 6.0) * r)
	return pts

func _cell_at(p: Vector2) -> int:
	var g := _geom()
	var best := -1
	var best_d: float = g.r * 0.95
	for i in SIZE * SIZE:
		var d := p.distance_to(_center(i, g))
		if d < best_d:
			best_d = d
			best = i
	return best

func _draw_board() -> void:
	if engine.board.is_empty():
		return
	var g := _geom()
	var r: float = g.r
	var n := SIZE
	# Edge bands: red top and bottom, blue left and right.
	var tl := _center(0, g)
	var tr_ := _center(n - 1, g)
	var bl := _center((n - 1) * n, g)
	var br := _center(n * n - 1, g)
	var up := Vector2(0, -r * 1.25)
	HomeKit.glow_line(board, tl + up + Vector2(-r * 0.6, 0), tr_ + up + Vector2(r * 0.6, 0), COLORS[1], 4.0)
	HomeKit.glow_line(board, bl - up + Vector2(-r * 0.6, 0), br - up + Vector2(r * 0.6, 0), COLORS[1], 4.0)
	var side := Vector2(-r * 1.15, 0)
	HomeKit.glow_line(board, tl + side + Vector2(0, -r * 0.5), bl + side + Vector2(0, r * 0.5), COLORS[2], 4.0)
	HomeKit.glow_line(board, tr_ - side + Vector2(0, -r * 0.5), br - side + Vector2(0, r * 0.5), COLORS[2], 4.0)
	var on_path := {}
	for i in engine.path:
		on_path[i] = true
	for i in n * n:
		var c := _center(i, g)
		var pts := _hex_points(c, r * 0.97)
		var v: int = engine.board[i]
		if v == 0:
			board.draw_colored_polygon(pts, Color(0.06, 0.07, 0.14))
			board.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(HomeKit.PURPLE, 0.55), 1.5, true)
		else:
			var col: Color = COLORS[v]
			board.draw_colored_polygon(pts, Color(col, 0.75 if on_path.has(i) else 0.4))
			board.draw_polyline(pts + PackedVector2Array([pts[0]]), col.lightened(0.3) if on_path.has(i) else col, 2.0, true)
	if engine.last >= 0:
		board.draw_circle(_center(engine.last, g), r * 0.18, Color.WHITE)

func _draw_home_logo(c: Control) -> void:
	var r := minf(c.size.y / 6.0, 28.0)
	var w := r * sqrt(3.0)
	var o := c.size / 2.0 - Vector2(w * 2.0, r * 2.25)
	var cols := [[1, 0, 2], [0, 1, 0], [2, 1, 2], [0, 1, 0]]
	for y in 4:
		for x in 3:
			var p := o + Vector2((x + y * 0.5) * w, y * 1.5 * r)
			var v: int = cols[y][x]
			var pts := _hex_points(p, r * 0.95)
			c.draw_colored_polygon(pts, Color(COLORS[v], 0.45) if v > 0 else Color(0.06, 0.07, 0.14))
			HomeKit.glow_polyline(c, pts, COLORS[v] if v > 0 else HomeKit.PURPLE, 1.6, true)

# ---------- online ----------

func _online_state() -> Dictionary:
	return {"board": engine.board, "turn": engine.turn, "winner": engine.winner, "last": engine.last, "path": engine.path}

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
	if b.size() != SIZE * SIZE:
		return
	engine.board = b
	engine.turn = int(st.get("turn", 1))
	engine.winner = int(st.get("winner", 0))
	engine.last = int(st.get("last", -1))
	engine.path = []
	for v in st.get("path", []):
		engine.path.append(int(v))
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
	if d == null or d.get("board", []).size() != SIZE * SIZE:
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
