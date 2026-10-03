extends Control

## Farkle vs the computer -- tap scoring dice to set them aside, then roll the
## rest or bank your points.

const FEngine = preload("res://scripts/games/farkle/farkle_engine.gd")
const HomeKit = preload("res://scripts/games/farkle/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const PIPS := {1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
	5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: FEngine
var table: Control
var score_label: Label
var status_label: Label
var roll_btn: Button
var bank_btn: Button
var cpu_timer: Timer
var end_dialog: ColorRect
var selected: Array = []
## Two players on one phone: the second player is a person, not the computer.
var two_player := false
var rolled := false      # the human has rolled at least once this turn
var farkled := false
var cpu_phase := ""

func _ready() -> void:
	preload("res://scripts/games/farkle/farkle_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = FEngine.new()
	_build_ui()
	_start()

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
	title.text = tr("🎯 Farkle")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(score_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.custom_minimum_size = Vector2(0, 76)
	root.add_child(status_label)

	table = Control.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.mouse_filter = Control.MOUSE_FILTER_STOP
	table.draw.connect(_draw_table)
	table.gui_input.connect(_on_table_input)
	table.resized.connect(table.queue_redraw)
	root.add_child(table)

	var rules := Label.new()
	rules.text = tr("1 = 100 · 5 = 50 · three of a kind = face × 100 (1s = 1000), each extra doubles · straight or three pairs = 1500")
	rules.add_theme_font_size_override("font_size", 24)
	rules.add_theme_color_override("font_color", Color(0.75, 0.85, 0.8))
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(rules)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_bottom", 30)
	rm.add_child(row)
	root.add_child(rm)
	roll_btn = Button.new()
	roll_btn.custom_minimum_size = Vector2(280, 76)
	roll_btn.add_theme_font_size_override("font_size", 26)
	roll_btn.pressed.connect(_on_roll)
	row.add_child(roll_btn)
	bank_btn = Button.new()
	bank_btn.custom_minimum_size = Vector2(280, 76)
	bank_btn.add_theme_font_size_override("font_size", 26)
	bank_btn.pressed.connect(_on_bank)
	row.add_child(bank_btn)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 1.0
	cpu_timer.timeout.connect(_cpu_step)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/farkle/farkle_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _start() -> void:
	result_recorded = false
	cpu_timer.stop()
	engine.reset()
	end_dialog.visible = false
	_begin_human()

func _begin_human() -> void:
	selected = []
	rolled = false
	farkled = false
	status_label.text = (tr("%s: roll the dice!") % _who()) if two_player else tr("Your turn — roll the dice!")
	_refresh()

func _selection_values() -> Array:
	var out: Array = []
	for i in selected:
		out.append(engine.dice[i])
	return out

func _refresh() -> void:
	if two_player:
		score_label.text = tr("Player 1: %d   ·   Player 2: %d   (to %d)") % [engine.scores[0], engine.scores[1], FEngine.TARGET]
	else:
		score_label.text = tr("You: %d   ·   Computer: %d   (to %d)") % [engine.scores[0], engine.scores[1], FEngine.TARGET]
	var mine: bool = _person() and engine.winner == -1 and not farkled
	var sel_score := FEngine.score_of(_selection_values())
	if not rolled:
		roll_btn.text = tr("🎲 Roll")
		roll_btn.disabled = not mine
		bank_btn.text = tr("Bank")
		bank_btn.disabled = true
	else:
		var left: int = engine.dice.size() - selected.size()
		roll_btn.text = tr("Keep & roll %d") % (left if left > 0 else 6)
		roll_btn.disabled = not mine or sel_score <= 0
		bank_btn.text = tr("Bank %d") % (engine.turn_points + max(0, sel_score))
		bank_btn.disabled = not mine or sel_score <= 0
	if mine and rolled:
		if selected.is_empty():
			status_label.text = tr("Turn: %d — tap scoring dice to set them aside.") % engine.turn_points
		elif sel_score <= 0:
			status_label.text = tr("Those dice don't all score.")
		else:
			status_label.text = tr("Selected: %d  (turn total %d)") % [sel_score, engine.turn_points + sel_score]
	table.queue_redraw()

func _on_roll() -> void:
	if not _person() or farkled:
		return
	if rolled:
		if not engine.keep(selected):
			return
	selected = []
	rolled = true
	if engine.roll():
		farkled = true
		status_label.text = tr("Farkle! No scoring dice — you lose this turn's points.")
		_refresh()
		cpu_phase = "handover"
		cpu_timer.wait_time = 1.8
		cpu_timer.start()
		return
	_refresh()

func _on_bank() -> void:
	if not _person() or not engine.keep(selected):
		return
	selected = []
	engine.bank()
	if _check_winner():
		return
	if two_player:
		_begin_human()
	else:
		_start_cpu()

func _start_cpu() -> void:
	rolled = false
	farkled = false
	cpu_phase = "roll"
	status_label.text = tr("Computer's turn...")
	_refresh()
	cpu_timer.wait_time = 1.0
	cpu_timer.start()

func _cpu_step() -> void:
	match cpu_phase:
		"handover":
			engine.end_turn()
			if two_player:
				_begin_human()
			else:
				_start_cpu()
			return
		"roll":
			if engine.roll():
				status_label.text = tr("Computer farkled!")
				cpu_phase = "done"
			else:
				selected = engine.cpu_keep_indices()
				status_label.text = tr("Computer keeps %d points.") % FEngine.score_of(_selection_values())
				cpu_phase = "keep"
		"keep":
			engine.keep(selected)
			selected = []
			if engine.cpu_should_bank():
				status_label.text = tr("Computer banks %d.") % engine.turn_points
				engine.scores[1] += engine.turn_points
				if engine.scores[1] >= FEngine.TARGET:
					engine.winner = 1
				cpu_phase = "done"
			else:
				status_label.text = tr("Computer rolls again (turn: %d).") % engine.turn_points
				cpu_phase = "roll"
		"done":
			if _check_winner():
				return
			engine.end_turn()
			_begin_human()
			return
	_refresh()
	cpu_timer.wait_time = 1.1
	cpu_timer.start()

func _check_winner() -> bool:
	if engine.winner == -1:
		return false
	_refresh()
	if two_player:
		var msg := tr("Player %d wins!") % (engine.winner + 1)
		if info and not result_recorded:
			result_recorded = true
			info.add("Player 1 wins" if engine.winner == 0 else "Player 2 wins")
			info.celebrate(msg)
		end_dialog.get_meta("message_label").text = msg
		end_dialog.visible = true
		return true
	end_dialog.get_meta("message_label").text = (tr("You win!") if engine.winner == 0 else tr("You lose!")) + _record_result("win" if engine.winner == 0 else "loss")
	end_dialog.visible = true
	return true

# ---------- drawing ----------

func _die_size() -> float:
	return min(110.0, (table.size.x - 80.0) / 6.0 - 10.0)

func _die_rect(i: int, n: int, y: float, s: float) -> Rect2:
	var total := n * s + (n - 1) * 14.0
	return Rect2(Vector2((table.size.x - total) / 2.0 + i * (s + 14.0), y), Vector2(s, s))

func _draw_die(r: Rect2, v: int, hilite: bool, dim: bool) -> void:
	var col: Color = HomeKit.GOLD if hilite else HomeKit.CYAN
	var sb := HomeKit.neon_box(col, "pressed" if hilite else "normal")
	sb.bg_color = Color(col, 0.28 if hilite else 0.08)
	sb.set_border_width_all(4 if hilite else 2)
	sb.set_corner_radius_all(int(r.size.x * 0.16))
	if dim:
		sb.border_color = Color(col, 0.4)
		sb.shadow_size = 0
	table.draw_style_box(sb, r)
	for sp in PIPS[v]:
		table.draw_circle(r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * r.size.x, r.size.x * 0.085, Color(1, 1, 1, 0.45 if dim else 1.0))

func _draw_table() -> void:
	var font: Font = ThemeDB.fallback_font
	var s := _die_size()
	var y := table.size.y * 0.3
	for i in engine.dice.size():
		_draw_die(_die_rect(i, engine.dice.size(), y, s), engine.dice[i], selected.has(i), farkled)
	if not engine.kept.is_empty():
		table.draw_string(font, Vector2(0, table.size.y * 0.66), tr("Set aside:"), HORIZONTAL_ALIGNMENT_CENTER, table.size.x, 26, Color(0.8, 0.9, 0.85))
		var ks := s * 0.6
		for i in engine.kept.size():
			_draw_die(_die_rect(i, engine.kept.size(), table.size.y * 0.7, ks), engine.kept[i], false, true)

func _on_table_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _person() or not rolled or farkled:
		return
	var s := _die_size()
	for i in engine.dice.size():
		if _die_rect(i, engine.dice.size(), table.size.y * 0.3, s).has_point(event.position):
			if selected.has(i):
				selected.erase(i)
			else:
				selected.append(i)
			_refresh()
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

const TITLE_FOR_HOME := preload("res://scripts/games/farkle/farkle_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/farkle/farkle_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Push your luck with six dice. First to 10,000 wins.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🤖 vs Computer", "sub": "First to 10,000", "action": _new_game.bind(false)},
			{"text": "👥 2 Players", "sub": "Take turns on one phone", "multi": true, "action": _new_game.bind(true)},
		],
		"restart": _start,
		"board": "Wins",
		"board_note": "Games won against the computer.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var s := minf(c.size.y * 0.42, 70.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	var faces := [5, 1, 3]
	for i in 3:
		var r := Rect2(ctr + Vector2((i - 1) * s * 1.25 - s / 2.0, -s / 2.0 + (i % 2) * s * 0.25 - s * 0.1), Vector2(s, s))
		c.draw_set_transform(r.get_center(), [-0.2, 0.1, 0.25][i], Vector2.ONE)
		var rr := Rect2(-r.size / 2.0, r.size)
		HomeKit.glow_rect(c, rr, [HomeKit.CYAN, HomeKit.GOLD, HomeKit.PINK][i], 2.5, 0.12)
		for sp in PIPS[faces[i]]:
			c.draw_circle(rr.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * s, s * 0.08, Color.WHITE)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _new_game(two: bool) -> void:
	two_player = two
	_start()

## Is a person (not the computer) to move?
func _person() -> bool:
	return engine.turn == 0 or two_player

func _who() -> String:
	return tr("Player %d") % (engine.turn + 1)
