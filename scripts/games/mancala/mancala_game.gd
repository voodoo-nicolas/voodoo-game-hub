extends Control

const MancalaEngine = preload("res://scripts/games/mancala/mancala_engine.gd")
const HomeKit = preload("res://scripts/games/mancala/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://mancala_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
const COLOR_PIT := HomeKit.BLUE
const COLOR_PIT_ACTIVE := HomeKit.GOLD
const COLOR_STORE := HomeKit.PURPLE
const LEVELS := ["Easy", "Medium", "Hard"]
const CPU_DELAY := 0.8

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var game_active: bool = false
var pit_buttons: Dictionary = {}  # index -> Button
var pit_labels: Dictionary = {}  # index -> Label
var store_labels: Dictionary = {}  # index -> Label
var status_label: Label
var win_dialog: Control
var win_label: Label
var home  # HomeKit
## -1 = two players on one phone; 0..2 = against the computer (Player 2, top row).
var cpu_level: int = -1
var cpu_timer: Timer
var rng := RandomNumberGenerator.new()
## Online play (null on apps without it). Host is Player 1 (bottom row),
## guest Player 2 (top row); my_player == 0 means same-phone play.
var online: Control = null
var my_player: int = 0

func _ready() -> void:
	preload("res://scripts/games/mancala/mancala_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = MancalaEngine.new()
	_build_ui()
	_reset_board()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

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
	title.text = tr("Mancala")
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.5))
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
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	# The board stands upright so the pits can be big on a phone: your pits
	# run down the left column into your store at the bottom; the other
	# player's run up the right column into theirs at the top. Seeds still go
	# round counter-clockwise, and each pit faces its opposite (12 - i).
	var view: Vector2 = get_viewport_rect().size
	var pit_size: float = floor(minf((view.x - 160.0) / 2.0, (view.y - 300.0) / 7.6))
	pit_size = clampf(pit_size, 64.0, 150.0)
	var gap := 10.0

	var board_col := VBoxContainer.new()
	board_col.add_theme_constant_override("separation", int(gap))
	center.add_child(board_col)
	board_col.add_child(_make_store(MancalaEngine.P2_STORE, pit_size * 2.0 + gap * 3.0, pit_size * 0.7))
	for row in 6:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", int(gap * 3.0))
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		board_col.add_child(line)
		line.add_child(_make_pit(row, pit_size))        # yours: 0 at the top .. 5
		line.add_child(_make_pit(12 - row, pit_size))   # theirs: 12 at the top .. 7
	board_col.add_child(_make_store(MancalaEngine.P1_STORE, pit_size * 2.0 + gap * 3.0, pit_size * 0.7))

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	_build_win_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("mancala", tr("Mancala"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_reset_board)
		online.status_changed.connect(_render)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/mancala/mancala_help.gd"))
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
		"help": preload("res://scripts/games/mancala/mancala_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"solo_heading": "vs Computer",
		"subtitle": "Sow the seeds, fill your store. Beat the computer or a friend.",
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
	var k := minf(c.size.y * 0.32, 52.0)
	var w := k * 6.4
	var o := Vector2((c.size.x - w) / 2.0, c.size.y / 2.0)
	var stores := [o + Vector2(-k * 0.2, 0), o + Vector2(w + k * 0.2, 0)]
	for p in stores:
		var r := Rect2(p - Vector2(k * 0.35, k * 1.05), Vector2(k * 0.7, k * 2.1))
		HomeKit.glow_rect(c, r, COLOR_STORE, 2.5, 0.12)
	for i in 4:
		for row in [-1, 1]:
			var ctr := o + Vector2(k * (1.0 + i * 1.47), row * k * 0.55)
			HomeKit.glow_circle(c, ctr, k * 0.42, COLOR_PIT_ACTIVE if row == 1 else COLOR_PIT, 2.0, 0.08)
			for s in 3:
				var a := TAU * (s / 3.0 + i * 0.13)
				c.draw_circle(ctr + Vector2(cos(a), sin(a)) * k * 0.17, k * 0.08, HomeKit.LIME if (s + i) % 2 == 0 else HomeKit.CYAN)

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

func _maybe_cpu() -> void:
	if game_active and _vs_cpu() and engine.current_player == 2:
		cpu_timer.start(CPU_DELAY)

func _cpu_turn() -> void:
	if not game_active or not _vs_cpu() or engine.current_player != 2:
		return
	var pit: int = engine.cpu_move(cpu_level, rng)
	if pit >= 0:
		_sow(pit)

func _resume_text() -> String:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return ""
	var lvl := int(data.get("cpu", -1))
	return tr("2 Players") if lvl < 0 else tr(LEVELS[clampi(lvl, 0, 2)])

func _make_pit(index: int, size: float) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(size, size)
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta("sfx", "")  # sowing plays its own sound
	btn.pressed.connect(_on_pit_pressed.bind(index))
	pit_buttons[index] = btn

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(size * 0.4))
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)
	pit_labels[index] = label

	return btn

func _make_store(index: int, width: float, height: float) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)
	var sb := HomeKit.neon_box(COLOR_STORE)
	sb.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", sb)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(height * 0.55))
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 1.0))
	panel.add_child(label)
	store_labels[index] = label

	return panel

func _build_win_dialog() -> void:
	win_dialog = Ui.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 Mancala Home"), "action": _go_home},
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
	game_active = true
	win_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	home.pause()

func _on_pit_pressed(index: int) -> void:
	if not game_active:
		return
	if _is_online() and not online.can_act(engine.current_player == my_player):
		return
	if _vs_cpu() and engine.current_player != 1:
		return  # the computer's turn
	if _sow(index) and _is_online():
		online.send_move({"pit": index})

func _sow(index: int) -> bool:
	if not engine.legal_pits(engine.current_player).has(index):
		return false
	var result: Dictionary = engine.sow(index)
	if not result.valid:
		return false
	_sfx("capture" if int(result.captured) > 0 else ("merge" if result.landed_in_store else "slide"))
	_render()
	if engine.game_over:
		_show_result()
	elif result.extra_turn:
		if _vs_cpu():
			status_label.text = tr("You go again!") if engine.current_player == 1 else tr("The computer goes again!")
		else:
			status_label.text = tr("Player %d goes again!") % engine.current_player
	_maybe_cpu()
	return true

# ---------- online ----------

func _online_state() -> Dictionary:
	return {"board": engine.board, "current_player": engine.current_player, "game_over": engine.game_over, "winner": engine.winner}

func _on_online_started(p_my_player: int) -> void:
	my_player = p_my_player
	cpu_level = -1
	home.hide_home()
	_reset_board()

func _on_remote_move(p: Dictionary) -> void:
	if game_active and engine.current_player != my_player:
		_sow(int(p.get("pit", -1)))

func _on_remote_state(st: Dictionary) -> void:
	var board: Array = []
	for v in st.get("board", []):
		board.append(int(v))
	if board.size() != 14:
		return
	engine.board = board
	engine.current_player = int(st.get("current_player", 1))
	engine.game_over = bool(st.get("game_over", false))
	engine.winner = int(st.get("winner", 0))
	game_active = not engine.game_over
	win_dialog.visible = false
	_render()
	if engine.game_over:
		_show_result()

func _show_result() -> void:
	var just_ended := game_active  # a resync of a finished game isn't a new result
	game_active = false
	if not _is_online():  # an online game ending mustn't wipe a paused local one
		SaveUtil.delete(SAVE_PATH)
	var p1: int = engine.board[MancalaEngine.P1_STORE]
	var p2: int = engine.board[MancalaEngine.P2_STORE]
	if engine.winner == 0:
		win_label.text = tr("It's a tie! %d - %d") % [p1, p2]
	elif _is_online():
		win_label.text = "%s %d - %d" % [online.result_text(engine.winner == my_player), p1, p2]
	elif _vs_cpu():
		win_label.text = (tr("You win!") if engine.winner == 1 else tr("The computer wins!")) + "  %d - %d" % [p1, p2]
	else:
		win_label.text = tr("Player %d wins! %d - %d") % [engine.winner, p1, p2]
	if info and just_ended:
		if _is_online():
			info.result("draw" if engine.winner == 0 else ("win" if engine.winner == my_player else "loss"), true)
			win_label.text += "\n" + info.summary(["Online wins", "Online losses", "Online draws"])
		elif _vs_cpu():
			info.result("draw" if engine.winner == 0 else ("win" if engine.winner == 1 else "loss"))
			if engine.winner == 1:
				info.add("Wins (%s)" % LEVELS[cpu_level])
			info.high("Most seeds", p1)
			win_label.text += "\n" + info.summary(["Wins", "Losses", "Draws"])
		else:
			info.add("Draws" if engine.winner == 0 else ("Player 1 wins" if engine.winner == 1 else "Player 2 wins"))
			if not (engine.winner == 0):
				info.celebrate(win_label.text.split("\n")[0])
			win_label.text += "\n" + info.summary(["Player 1 wins", "Player 2 wins"])
	win_dialog.visible = true

# ---------- rendering ----------

func _render() -> void:
	for i in pit_labels.keys():
		pit_labels[i].text = str(engine.board[i])
	for i in store_labels.keys():
		store_labels[i].text = str(engine.board[i])

	var current: int = engine.current_player
	for i in pit_buttons.keys():
		var is_current_side: bool = (current == 1 and i >= 0 and i <= 5) or (current == 2 and i >= 7 and i <= 12)
		var can_play: bool = is_current_side and engine.board[i] > 0 and game_active \
			and (not _is_online() or current == my_player) and not (_vs_cpu() and current == 2)
		_style_pit(pit_buttons[i], COLOR_PIT_ACTIVE if can_play else COLOR_PIT)

	if game_active:
		if _is_online():
			var side := tr("left side") if current == 1 else tr("right side")
			status_label.text = online.status_text(current == my_player, tr("Player %d, %s") % [current, side])
		elif _vs_cpu():
			status_label.text = tr("Your turn (%s)") % tr("left side") if current == 1 else tr("Computer is thinking...")
		else:
			status_label.text = tr("Player %d's turn") % current

func _style_pit(btn: Button, color: Color) -> void:
	var sb := HomeKit.neon_box(color, "normal")
	sb.bg_color = Color(color, 0.16 if color == COLOR_PIT_ACTIVE else 0.06)
	sb.shadow_size = 8 if color == COLOR_PIT_ACTIVE else 3
	var radius: int = int(btn.custom_minimum_size.x / 2.0)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, sb)

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or _is_online():
		return  # online games aren't resumable alone
	SaveUtil.write(SAVE_PATH, {
		"board": engine.board,
		"current_player": engine.current_player,
		"cpu": cpu_level,
	})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		_reset_board()
		return false
	var board: Array = []
	for v in data.board:
		board.append(int(v))
	engine.board = board
	engine.current_player = int(data.current_player)
	engine.game_over = false
	game_active = true
	cpu_level = clampi(int(data.get("cpu", -1)), -1, 2)
	win_dialog.visible = false
	_render()
	_maybe_cpu()
	return true

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
