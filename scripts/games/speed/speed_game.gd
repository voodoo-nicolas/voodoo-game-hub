extends Control

## Speed vs the computer -- tap a card that's one higher or lower than a
## centre pile to play it. Be quick: the computer plays at the same time.

const SpeedEngine = preload("res://scripts/games/speed/speed_engine.gd")
const HomeKit = preload("res://scripts/games/speed/home_kit.gd")
const Cards = preload("res://scripts/games/speed/speed_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_FELT := Color(0.03, 0.04, 0.1)
const CPU_SPEEDS := [1.8, 1.2, 0.8]

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: SpeedEngine
var board: Control
var status_label: Label
var level_btn: Button
var cpu_timer: Timer
var stuck_timer: Timer
var start_dialog: ColorRect
var end_dialog: ColorRect
var pause_dialog: ColorRect
var level: int = 1
var running := false
var flash_card: int = -1
var font: Font

func _ready() -> void:
	preload("res://scripts/games/speed/speed_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = SpeedEngine.new()
	_build_ui()
	_show_start()
	start_dialog.visible = false  # the Home screen picks the speed now

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
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
	title.text = tr("⚡ Speed")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_show_start)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 25)
	status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	root.add_child(spacer)

	cpu_timer = Timer.new()
	cpu_timer.timeout.connect(_cpu_play)
	add_child(cpu_timer)
	stuck_timer = Timer.new()
	stuck_timer.one_shot = true
	stuck_timer.wait_time = 1.2
	stuck_timer.timeout.connect(_on_stuck_flip)
	add_child(stuck_timer)

	start_dialog = UI.build_dialog(tr("⚡ Speed"), [
		{"text": tr("Start"), "action": _start_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	var box: Node = start_dialog.get_meta("message_label").get_parent()
	level_btn = Button.new()
	level_btn.custom_minimum_size = Vector2(320, 64)
	level_btn.add_theme_font_size_override("font_size", 26)
	level_btn.pressed.connect(_cycle_level)
	box.add_child(level_btn)
	box.move_child(level_btn, 2)
	add_child(start_dialog)
	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _show_start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	])
	add_child(pause_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/speed/speed_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _cycle_level() -> void:
	level = (level + 1) % CPU_SPEEDS.size()
	_update_level_text()

func _update_level_text() -> void:
	var names := [tr("Relaxed"), tr("Quick"), tr("Lightning")]
	level_btn.text = tr("Computer: %s") % names[level]

func _show_start() -> void:
	running = false
	cpu_timer.stop()
	stuck_timer.stop()
	end_dialog.visible = false
	engine.new_game()
	_update_level_text()
	start_dialog.get_meta("message_label").text = tr("Play cards one higher or lower than a centre pile. Empty your cards first!")
	start_dialog.visible = true
	status_label.text = ""
	board.queue_redraw()

func _start_game() -> void:
	result_recorded = false
	running = true
	cpu_timer.wait_time = CPU_SPEEDS[level]
	cpu_timer.start()
	status_label.text = tr("Go!")
	_check_state()

func _resume() -> void:
	running = true
	cpu_timer.start()
	_check_state()

## Leaving the app mid-race pauses it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running and home:
			home.pause()
			return
		if is_node_ready() and running:
			running = false
			cpu_timer.stop()
			stuck_timer.stop()
			pause_dialog.visible = true

func _cpu_play() -> void:
	if not running:
		return
	for c in engine.hands[1]:
		var t := engine.target_for(c, randi() % 2)
		if t >= 0:
			engine.play(1, c, t)
			# a little human-like jitter
			cpu_timer.wait_time = CPU_SPEEDS[level] * randf_range(0.7, 1.3)
			break
	_check_state()

func _check_state() -> void:
	board.queue_redraw()
	if engine.winner != -1:
		running = false
		cpu_timer.stop()
		stuck_timer.stop()
		end_dialog.get_meta("message_label").text = (tr("You win!") if engine.winner == 0 else tr("The computer was faster!")) + _record_result("win" if engine.winner == 0 else "loss")
		end_dialog.visible = true
		return
	if engine.stuck():
		status_label.text = tr("Nobody can play — flipping new centre cards...")
		if stuck_timer.is_stopped():
			stuck_timer.start()
	else:
		status_label.text = tr("You: %d cards left  ·  Computer: %d") % [engine.cards_left(0), engine.cards_left(1)]

func _on_stuck_flip() -> void:
	if not running:
		return
	var before := [engine.top(0), engine.top(1)]
	engine.flip()
	if [engine.top(0), engine.top(1)] == before and engine.stuck():
		# nothing left to flip: fewest cards wins
		engine.winner = 0 if engine.cards_left(0) <= engine.cards_left(1) else 1
	_check_state()

# ---------- drawing ----------

func _card_size() -> Vector2:
	var w: float = min(120.0, (board.size.x - 40.0) / 5.4)
	return Vector2(w, w * 1.4)

func _center_rects() -> Array:
	var cs := _card_size() * 1.15
	var y := board.size.y / 2.0 - cs.y / 2.0
	return [Rect2(Vector2(board.size.x / 2.0 - cs.x - 14, y), cs), Rect2(Vector2(board.size.x / 2.0 + 14, y), cs)]

func _hand_rects() -> Array:
	var cs := _card_size()
	var out: Array = []
	var n: int = engine.hands[0].size()
	var step := cs.x + 8.0
	var x0 := (board.size.x - (step * (n - 1) + cs.x)) / 2.0
	for i in n:
		out.append(Rect2(Vector2(x0 + i * step, board.size.y - cs.y - 50.0), cs))
	return out

func _draw_board() -> void:
	if engine.hands[0].is_empty() and engine.draws[0].is_empty() and engine.winner == -1:
		return
	var cs := _card_size()
	# computer's hand (backs) and pile
	var small := cs * 0.7
	var n: int = engine.hands[1].size()
	var x0 := (board.size.x - (n * (small.x + 6))) / 2.0
	for i in n:
		Cards.draw_card(board, Rect2(Vector2(x0 + i * (small.x + 6), 36), small), 0, false)
	board.draw_string(font, Vector2(0, 26), tr("Computer — draw pile: %d") % engine.draws[1].size(),
		HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 22, Color(0.85, 0.9, 0.85))
	var centers := _center_rects()
	for k in 2:
		Cards.draw_card(board, centers[k], engine.top(k))
		var side := Rect2(Vector2(20 if k == 0 else board.size.x - 20 - small.x, centers[k].position.y + 20), small)
		if engine.sides[k].is_empty():
			Cards.draw_card(board, side, -1)
		else:
			Cards.draw_card(board, side, 0, false)
		board.draw_string(font, side.position + Vector2(0, side.size.y + 24), str(engine.sides[k].size()),
			HORIZONTAL_ALIGNMENT_CENTER, side.size.x, 20, Color(0.85, 0.9, 0.85))
	var rects := _hand_rects()
	for i in rects.size():
		var c: int = engine.hands[0][i]
		var ok: bool = running and engine.target_for(c) >= 0
		Cards.draw_card(board, rects[i], c, true, ok or c == flash_card)
	board.draw_string(font, Vector2(0, board.size.y - 14), tr("Your draw pile: %d") % engine.draws[0].size(),
		HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 22, Color(0.85, 0.9, 0.85))

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not running:
		return
	var rects := _hand_rects()
	for i in rects.size():
		if rects[i].has_point(event.position):
			var c: int = engine.hands[0][i]
			# play on the pile nearest to where the card is
			var prefer := 0 if rects[i].get_center().x < board.size.x / 2.0 else 1
			var t := engine.target_for(c, prefer)
			if t >= 0:
				engine.play(0, c, t)
				_check_state()
			return


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

const TITLE_FOR_HOME := preload("res://scripts/games/speed/speed_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/speed/speed_help.gd"),
		"info": info,
		"accent": HomeKit.PINK,
		"subtitle": "No turns — race the computer to empty your hand.",
		"logo": _draw_home_logo,
		"solo_heading": "vs Computer",
		"modes": [
			{"text": "🐢 Relaxed", "row": "lvl", "color": HomeKit.LIME, "action": _start_level.bind(0)},
			{"text": "🐇 Quick", "row": "lvl", "color": HomeKit.CYAN, "action": _start_level.bind(1)},
			{"text": "⚡ Lightning", "row": "lvl", "color": HomeKit.PINK, "action": _start_level.bind(2)},
		],
		"restart": _show_start,
		"board": "Wins",
		"board_note": "Races won against the computer.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y * 0.85, 150.0)
	var w := h * 0.68
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	Cards.draw_card(c, Rect2(ctr + Vector2(-w * 1.15, -h / 2.0), Vector2(w, h)), 8)
	Cards.draw_card(c, Rect2(ctr + Vector2(w * 0.15, -h / 2.0), Vector2(w, h)), 22)
	for k in 3:
		HomeKit.glow_line(c, ctr + Vector2(-w * 1.55 - k * 8, -h * 0.2 + k * h * 0.2), ctr + Vector2(-w * 1.3 - k * 8, -h * 0.2 + k * h * 0.2), HomeKit.GOLD, 2.0)

func _start_level(l: int) -> void:
	level = l
	_show_start()
	start_dialog.visible = false
	_start_game()
