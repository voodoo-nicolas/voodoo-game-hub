extends Control

## Snake -- swipe anywhere to steer. Solo, 2 players on one phone (each
## swipes on their own half), vs the computer, or online.

const SnakeEngine = preload("res://scripts/games/snake/snake_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
## Online play. Not preloaded either (apps before v0.14 don't have it).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"

const BEST_PATH := "user://snake_best.json"
## Columns across the screen; rows follow from the space available.
const COLS := 22
const STEP_SECONDS := 0.14
const VERSUS_STEP_SECONDS := 0.16
## How far a finger travels before it counts as a turn.
const SWIPE_PX := 28.0
const COLOR_BG := Color(0.08, 0.12, 0.09)
const COLOR_BG_ALT := Color(0.09, 0.135, 0.1)
const COLOR_FOOD := Color(0.95, 0.3, 0.3)
## Per snake: body, head.
const SNAKE_COLORS := [[Color(0.3, 0.85, 0.4), Color(0.55, 1.0, 0.6)], [Color(0.3, 0.6, 1.0), Color(0.55, 0.8, 1.0)]]

enum Mode { SOLO, TWO_PLAYER, VS_CPU, ONLINE }

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var mode: int = Mode.SOLO
var best_score: int = 0
var wins := [0, 0]
var board: Control
var score_label: Label
var best_label: Label
var hint_label: Label
var step_timer: Timer
var start_overlay: Control
var start_title: Label
var start_status: Label
var start_buttons: Array = []
var game_over_dialog: Control
var game_over_label: Label
var pause_dialog: Control
var online = null
var online_btn: Button
var my_player: int = 0
var running := false
## Active swipes: touch index -> {origin: Vector2, player: int}
var swipes: Dictionary = {}

func _ready() -> void:
	preload("res://scripts/games/snake/snake_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = SnakeEngine.new()
	_load_best()
	_build_ui()
	engine.reset(COLS, 30)
	_show_start_overlay()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 16)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_margin.add_child(top_bar)

	var hub_btn := Button.new()
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 24)
	hub_btn.pressed.connect(_go_hub)
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("🐍 Snake")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 24)
	restart_btn.pressed.connect(_show_start_overlay)
	top_bar.add_child(restart_btn)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 30)
	root.add_child(stats_row)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	stats_row.add_child(score_label)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 26)
	best_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	stats_row.add_child(best_label)

	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_left", 10)
	bm.add_theme_constant_override("margin_right", 10)
	root.add_child(bm)
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.draw.connect(_draw_board)
	board.resized.connect(board.queue_redraw)
	bm.add_child(board)

	hint_label = Label.new()
	hint_label.text = tr("Swipe anywhere to turn")
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_bottom", 18)
	hm.add_child(hint_label)
	root.add_child(hm)

	step_timer = Timer.new()
	step_timer.wait_time = STEP_SECONDS
	step_timer.timeout.connect(_on_step)
	add_child(step_timer)

	_build_start_overlay()
	_build_game_over_dialog()
	_build_pause_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("snake", tr("🐍 Snake"), _online_state)
		add_child(online)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_on_remote_new_game)
		online.started.connect(_on_online_started)
		online.status_changed.connect(_on_online_status)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/snake/snake_help.gd"))
		add_child(info)
		if best_score > 0:
			info.high("Best score", best_score)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.975)  # by the hint line, off the field
	add_child(drawer)

func _go_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

func _build_start_overlay() -> void:
	start_overlay = ColorRect.new()
	start_overlay.color = Color(0, 0, 0, 0.8)
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.visible = false
	add_child(start_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	start_title = Label.new()
	start_title.text = tr("🐍 Snake")
	start_title.add_theme_font_size_override("font_size", 40)
	start_title.add_theme_color_override("font_color", Color(1, 1, 1))
	start_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(start_title)

	start_status = Label.new()
	start_status.add_theme_font_size_override("font_size", 22)
	start_status.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	start_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	start_status.custom_minimum_size = Vector2(320, 0)
	box.add_child(start_status)

	for spec in [[tr("Solo"), Mode.SOLO], [tr("2 Players (same phone)"), Mode.TWO_PLAYER], [tr("vs Computer"), Mode.VS_CPU]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(340, 64)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(_start_game.bind(spec[1]))
		box.add_child(b)
		start_buttons.append(b)

	online_btn = Button.new()
	online_btn.text = tr("🌐 Play Online")
	online_btn.custom_minimum_size = Vector2(340, 64)
	online_btn.add_theme_font_size_override("font_size", 28)
	online_btn.pressed.connect(_on_online_pressed)
	online_btn.visible = ResourceLoader.exists(ONLINE_MATCH_PATH)
	box.add_child(online_btn)

func _build_game_over_dialog() -> void:
	game_over_dialog = Ui.build_dialog("", [
		{"text": tr("Play Again"), "action": _play_again},
		{"text": tr("Change Mode"), "action": _show_start_overlay},
		{"text": tr("Back to Hub"), "action": _go_hub},
	], true)
	game_over_label = game_over_dialog.get_meta("message_label")
	game_over_label.add_theme_font_size_override("font_size", 32)
	add_child(game_over_dialog)

# ---------- game flow ----------

func _is_online() -> bool:
	return online != null and online.is_online()

func _versus() -> bool:
	return mode != Mode.SOLO

func _show_start_overlay() -> void:
	step_timer.stop()
	running = false
	game_over_dialog.visible = false
	start_overlay.visible = true
	_on_online_status()

## Rows that fit the board area at COLS columns.
func _rows_for_board() -> int:
	var cell: float = board.size.x / COLS
	if cell <= 0.0:
		return 30
	return clampi(int(board.size.y / cell), 12, 60)

func _start_game(p_mode: int) -> void:
	if _is_online():
		if not online.is_host():
			return  # the host starts online rounds
		p_mode = Mode.ONLINE
	mode = p_mode
	engine.reset(COLS, _rows_for_board(), 2 if _versus() else 1)
	start_overlay.visible = false
	game_over_dialog.visible = false
	swipes.clear()
	running = true
	step_timer.wait_time = VERSUS_STEP_SECONDS if _versus() else STEP_SECONDS
	step_timer.start()
	_update_hint()
	_render()
	if _is_online():
		online.push_state()

func _play_again() -> void:
	if _is_online() and not online.is_host():
		online.new_game()  # asks the host
		return
	_start_game(mode)

func _update_hint() -> void:
	match mode:
		Mode.TWO_PLAYER:
			hint_label.text = tr("Green swipes on the bottom half, blue on the top half")
		Mode.ONLINE:
			hint_label.text = tr("You are %s — swipe anywhere to turn") % (tr("Green") if my_player == 1 else tr("Blue"))
		_:
			hint_label.text = tr("Swipe anywhere to turn")

func _on_step() -> void:
	if not running:
		return
	if mode == Mode.VS_CPU and engine.snakes[1].alive:
		engine.set_direction(1, engine.ai_direction(1))
	var ended: bool = engine.step()
	_render()
	if ended:
		_end_round()  # before the push, so the guest sees running = false
	if _is_online():
		online.push_state()

func _process(_delta: float) -> void:
	if running:
		board.queue_redraw()  # the food pulses

func _end_round() -> void:
	step_timer.stop()
	running = false
	if not _versus():
		if engine.score > best_score:
			best_score = engine.score
			_save_best()
		if info:
			info.add("Games played")
			info.best("Best score", best_score)
		var won: bool = engine.food.x < 0  # the snake filled the whole board
		game_over_label.text = (tr("You filled the board!\nScore: %d") if won else tr("Score: %d")) % engine.score
	else:
		if engine.winner >= 0:
			wins[engine.winner] += 1
		var text: String
		if engine.winner < 0:
			text = tr("Head-on crash — a draw!")
		elif mode == Mode.ONLINE:
			text = online.result_text(engine.winner == my_player - 1)
		elif mode == Mode.VS_CPU:
			text = tr("You win!") if engine.winner == 0 else tr("The computer wins!")
		else:
			text = tr("%s wins!") % (tr("Green") if engine.winner == 0 else tr("Blue"))
		if info and mode != Mode.TWO_PLAYER:
			var me: int = (my_player - 1) if mode == Mode.ONLINE else 0
			info.result("draw" if engine.winner < 0 else ("win" if engine.winner == me else "loss"), mode == Mode.ONLINE)
		_set_dialog_title(text)
		game_over_label.text = tr("Green %d — %d Blue") % [wins[0], wins[1]]
	if not _versus():
		_set_dialog_title(tr("Game Over!"))
	game_over_dialog.visible = true

func _set_dialog_title(text: String) -> void:
	# build_dialog's title is the first label in its card
	var box: VBoxContainer = game_over_label.get_parent()
	var first: Node = box.get_child(0)
	if first is Label and first != game_over_label:
		first.text = text
	else:
		var t := Label.new()
		t.add_theme_font_size_override("font_size", 40)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.text = text
		box.add_child(t)
		box.move_child(t, 0)

func _render() -> void:
	if _versus():
		score_label.text = tr("Green: %d") % engine.snakes[0].score
		best_label.text = tr("Blue: %d") % (engine.snakes[1].score if engine.snakes.size() > 1 else 0)
		score_label.add_theme_color_override("font_color", SNAKE_COLORS[0][1])
		best_label.add_theme_color_override("font_color", SNAKE_COLORS[1][1])
	else:
		score_label.text = tr("Score: %d") % engine.score
		best_label.text = tr("Best: %d") % best_score
		score_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		best_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	board.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var cell: float = minf(board.size.x / engine.cols, board.size.y / engine.rows)
	var size := Vector2(engine.cols, engine.rows) * cell
	return {"cell": cell, "origin": (board.size - size) / 2.0, "size": size}

func _draw_board() -> void:
	if engine.snakes.is_empty():
		return
	var g := _geom()
	var c: float = g.cell
	var o: Vector2 = g.origin
	board.draw_rect(Rect2(o, g.size), COLOR_BG)
	for y in engine.rows:  # faint checkerboard
		for x in range(y % 2, engine.cols, 2):
			board.draw_rect(Rect2(o + Vector2(x, y) * c, Vector2(c, c)), COLOR_BG_ALT)
	board.draw_rect(Rect2(o, g.size), Color(0.3, 0.5, 0.35, 0.6), false, 2.0)
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 160.0)
	for f in engine.foods:
		var fc: Vector2 = o + (Vector2(f) + Vector2(0.5, 0.55)) * c
		board.draw_circle(fc, c * 0.34 * pulse, COLOR_FOOD)
		board.draw_circle(fc + Vector2(-c * 0.1, -c * 0.1), c * 0.08, Color(1, 1, 1, 0.5))
		board.draw_line(fc + Vector2(0, -c * 0.3), fc + Vector2(c * 0.15, -c * 0.45), Color(0.3, 0.8, 0.3), maxf(2.0, c * 0.1))
	for i in engine.snakes.size():
		_draw_snake(engine.snakes[i], SNAKE_COLORS[i % 2], o, c)

## A thin, rounded snake: a thick line through the segment centres, a
## slightly bigger head with eyes looking where it's going.
func _draw_snake(s: Dictionary, colors: Array, o: Vector2, c: float) -> void:
	var body: Array = s.body
	if body.is_empty():
		return
	var alpha: float = 1.0 if s.alive else 0.35
	var col: Color = Color(colors[0], alpha)
	var head_col: Color = Color(colors[1], alpha)
	var w: float = c * 0.5
	var pts := PackedVector2Array()
	for seg in body:
		pts.append(o + (Vector2(seg) + Vector2(0.5, 0.5)) * c)
	if pts.size() > 1:
		board.draw_polyline(pts, col, w, true)
		for p in pts:  # round the joints
			board.draw_circle(p, w / 2.0, col)
	var head: Vector2 = pts[0]
	board.draw_circle(head, c * 0.36, head_col)
	var d: Vector2 = Vector2(SnakeEngine.DELTA[s.dir])
	var side := Vector2(-d.y, d.x)
	for k in [-1.0, 1.0]:
		var e: Vector2 = head + d * c * 0.12 + side * k * c * 0.16
		board.draw_circle(e, c * 0.09, Color(1, 1, 1, alpha))
		board.draw_circle(e + d * c * 0.03, c * 0.045, Color(0, 0, 0, alpha))

# ---------- input: swipe anywhere ----------

## Each finger steers from where it last turned: once it has moved SWIPE_PX
## along one axis, that's a turn, and the next turn is measured from there --
## so one long drag can make several turns. In 2-player mode the bottom
## half steers green and the top half steers blue (sitting across the phone,
## so their swipes are mirrored).
func _input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed:
		_on_key(event.keycode)
		return
	var idx := -1
	var pos := Vector2.ZERO
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		idx = event.index
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		idx = event.index
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		idx = 0
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available() and swipes.has(0):
		idx = 0
		pos = event.position
	else:
		return
	if pressed:
		swipes[idx] = {"origin": pos, "player": _player_for(pos)}
		return
	if released:
		swipes.erase(idx)
		return
	if not swipes.has(idx):
		return
	var sw: Dictionary = swipes[idx]
	var delta: Vector2 = pos - sw.origin
	if maxf(absf(delta.x), absf(delta.y)) < SWIPE_PX:
		return
	var d: int
	if absf(delta.x) > absf(delta.y):
		d = SnakeEngine.Dir.RIGHT if delta.x > 0 else SnakeEngine.Dir.LEFT
	else:
		d = SnakeEngine.Dir.DOWN if delta.y > 0 else SnakeEngine.Dir.UP
	if mode == Mode.TWO_PLAYER and sw.player == 1:
		d = SnakeEngine.OPPOSITE[d]  # they're holding the phone upside down
	sw.origin = pos
	_steer(sw.player, d)

func _player_for(pos: Vector2) -> int:
	if mode == Mode.TWO_PLAYER:
		return 1 if pos.y < get_viewport_rect().size.y / 2.0 else 0
	if mode == Mode.ONLINE:
		return my_player - 1
	return 0

func _on_key(key: int) -> void:
	var map := {KEY_UP: [0, SnakeEngine.Dir.UP], KEY_DOWN: [0, SnakeEngine.Dir.DOWN],
		KEY_LEFT: [0, SnakeEngine.Dir.LEFT], KEY_RIGHT: [0, SnakeEngine.Dir.RIGHT],
		KEY_W: [1, SnakeEngine.Dir.UP], KEY_S: [1, SnakeEngine.Dir.DOWN],
		KEY_A: [1, SnakeEngine.Dir.LEFT], KEY_D: [1, SnakeEngine.Dir.RIGHT]}
	if not map.has(key):
		return
	var who: int = map[key][0]
	if mode == Mode.ONLINE:
		who = my_player - 1
	elif mode != Mode.TWO_PLAYER and who == 1:
		who = 0
	_steer(who, map[key][1])

func _steer(who: int, d: int) -> void:
	if mode == Mode.ONLINE and not online.is_host():
		online.send_move({"d": d})  # the host moves our snake
		return
	engine.set_direction(who, d)

# ---------- online (host runs the game, guest sends turns) ----------

func _on_online_pressed() -> void:
	if online:
		online.open_lobby()

func _online_state() -> Dictionary:
	var st: Dictionary = engine.to_dict()
	st["running"] = running
	st["wins"] = wins
	return st

func _on_online_started(p_my_player: int) -> void:
	my_player = p_my_player
	mode = Mode.ONLINE
	wins = [0, 0]
	_show_start_overlay()

func _on_online_status() -> void:
	if start_status == null:
		return
	var is_on := _is_online()
	start_buttons[1].visible = not is_on
	start_buttons[2].visible = not is_on
	online_btn.visible = not is_on and online != null
	if not is_on:
		start_status.text = tr("Swipe anywhere to turn. In versus, make the other snake run into your side!")
		start_buttons[0].text = tr("Solo")
		start_buttons[0].disabled = false
		return
	start_buttons[0].text = tr("Start")
	start_buttons[0].disabled = not (online.is_host() and online.opponent_here)
	if not online.opponent_here:
		start_status.text = online.status_text(false, "") if online.has_method("opponent_name") else tr("Opponent disconnected — waiting...")
	elif online.is_host():
		start_status.text = tr("You are Green. Tap Start when you're both ready!")
	else:
		start_status.text = tr("You are Blue. Waiting for your friend to start...")

func _on_remote_move(p: Dictionary) -> void:
	if online.is_host() and p.has("d"):
		engine.set_direction(1, int(p.d))

func _on_remote_new_game() -> void:
	if online.is_host():
		_start_game(Mode.ONLINE)

func _on_remote_state(st: Dictionary) -> void:
	if online.is_host():
		# Only a host that came back after a drop-out takes the guest's copy;
		# it then carries on running the game from there.
		if running:
			return
		engine.from_dict(st)
		var hw = st.get("wins", [0, 0])
		wins = [int(hw[0]), int(hw[1])]
		mode = Mode.ONLINE
		if bool(st.get("running", false)) and not engine.game_over:
			start_overlay.visible = false
			game_over_dialog.visible = false
			running = true
			step_timer.wait_time = VERSUS_STEP_SECONDS
			step_timer.start()
			_update_hint()
		_render()
		return
	engine.from_dict(st)
	var w = st.get("wins", [0, 0])
	wins = [int(w[0]), int(w[1])]
	var was_running := running
	running = bool(st.get("running", false))
	mode = Mode.ONLINE
	if running:
		start_overlay.visible = false
		game_over_dialog.visible = false
		_update_hint()
	_render()
	if was_running and not running and engine.game_over:
		_end_round_guest()

## The guest doesn't step the game; it just shows how the round ended.
func _end_round_guest() -> void:
	var text: String
	if engine.winner < 0:
		text = tr("Head-on crash — a draw!")
	else:
		text = online.result_text(engine.winner == my_player - 1)
	if info:
		info.result("draw" if engine.winner < 0 else ("win" if engine.winner == my_player - 1 else "loss"), true)
	_set_dialog_title(text)
	game_over_label.text = tr("Green %d — %d Blue") % [wins[0], wins[1]]
	game_over_dialog.visible = true

# ---------- persistence ----------

func _save_best() -> void:
	SaveUtil.write(BEST_PATH, {"best": best_score})
	if Auth.is_logged_in():
		Auth.push_stat("snake_best", best_score)

func _load_best() -> void:
	var data = SaveUtil.read(BEST_PATH)
	best_score = int(data.get("best", 0)) if data != null else 0
	if Auth.is_logged_in():
		# A method, not a lambda: if the player leaves before the reply lands,
		# a method callable on a freed scene is skipped instead of erroring.
		Auth.reconcile_stat("snake_best", best_score, _on_best_reconciled)

func _on_best_reconciled(merged: int) -> void:
	best_score = merged
	if info:
		info.high("Best score", merged)
	SaveUtil.write(BEST_PATH, {"best": merged})
	if best_label and not _versus():  # can land before _build_ui() if the request fails instantly
		best_label.text = tr("Best: %d") % best_score

# ---------- auto-pause ----------

## Leaving the app (home button, a phone call) pauses mid-round instead of
## letting the game run on unseen. Online rounds can't pause -- the other
## player is still playing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running and mode != Mode.ONLINE and not get_tree().paused:
			get_tree().paused = true
			pause_dialog.visible = true

func _resume() -> void:
	get_tree().paused = false

func _exit_paused_to_hub() -> void:
	get_tree().paused = false
	Ui.exit_to_hub(self)

## Never leave the tree paused behind us -- the next scene would be frozen.
func _exit_tree() -> void:
	get_tree().paused = false

func _build_pause_dialog() -> void:
	pause_dialog = Ui.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("Exit to Hub"), "action": _exit_paused_to_hub},
	])
	pause_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_dialog)
