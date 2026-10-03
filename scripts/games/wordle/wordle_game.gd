extends Control

## Wordle: 6 rows of 5 tiles and an on-screen keyboard whose keys take on the
## best color each letter has earned so far. A physical keyboard works too.

const WordleEngine = preload("res://scripts/games/wordle/wordle_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const STATS_PATH := "user://wordle_stats.json"
const KEY_ROWS := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
const KEY_ROWS_ES := ["QWERTYUIOP", "ASDFGHJKLÑ", "ZXCVBNM"]
const COLOR_BG := Color(0.09, 0.09, 0.13)
const COLOR_EMPTY := Color(0.16, 0.16, 0.2)
const COLOR_TYPED := Color(0.24, 0.24, 0.3)
const COLOR_KEY := Color(0.36, 0.38, 0.45)
const MARK_COLORS := {
	WordleEngine.Mark.ABSENT: Color(0.25, 0.25, 0.28),
	WordleEngine.Mark.PRESENT: Color(0.78, 0.66, 0.2),
	WordleEngine.Mark.CORRECT: Color(0.3, 0.62, 0.3),
}

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var current: String = ""
var stats: Dictionary = {"played": 0, "wins": 0, "streak": 0, "best_streak": 0}

var tiles: Array = []  # 6 x 5 {panel, label}
var key_buttons: Dictionary = {}  # letter -> Button
var message_label: Label
var result_dialog: Control
var result_label: Label

func _ready() -> void:
	preload("res://scripts/games/wordle/wordle_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = WordleEngine.new()
	# Language is fixed for the visit: switching happens in the hub.
	engine.spanish = TranslationServer.get_locale().begins_with("es")
	var data = SaveUtil.read(STATS_PATH)
	if data != null:
		for k in stats:
			stats[k] = int(data.get(k, 0))
	_build_ui()
	_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)
	var bar := HBoxContainer.new()
	top_margin.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🟩 Wordle")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_new_game)
	bar.add_child(new_btn)

	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 26)
	message_label.add_theme_color_override("font_color", Color(1, 0.84, 0.3))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.custom_minimum_size = Vector2(0, 36)
	root.add_child(message_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var board := GridContainer.new()
	board.columns = WordleEngine.WORD_LENGTH
	board.add_theme_constant_override("h_separation", 10)
	board.add_theme_constant_override("v_separation", 10)
	center.add_child(board)
	for r in range(WordleEngine.MAX_GUESSES):
		var row: Array = []
		for c in range(WordleEngine.WORD_LENGTH):
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(104, 104)
			var label := Label.new()
			label.add_theme_font_size_override("font_size", 52)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			panel.add_child(label)
			board.add_child(panel)
			row.append({"panel": panel, "label": label})
		tiles.append(row)

	var kb_margin := MarginContainer.new()
	kb_margin.add_theme_constant_override("margin_bottom", 36)
	kb_margin.add_theme_constant_override("margin_left", 8)
	kb_margin.add_theme_constant_override("margin_right", 8)
	root.add_child(kb_margin)
	var kb := VBoxContainer.new()
	kb.add_theme_constant_override("separation", 10)
	kb_margin.add_child(kb)
	var key_rows: Array = KEY_ROWS_ES if engine.spanish else KEY_ROWS
	for i in range(key_rows.size()):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		kb.add_child(row)
		if i == 2:
			row.add_child(_make_key(tr("Enter").to_upper(), 104, _submit))
		for letter in key_rows[i]:
			key_buttons[letter] = _make_key(letter, 64, _type_letter.bind(letter))
			row.add_child(key_buttons[letter])
		if i == 2:
			row.add_child(_make_key("⌫", 104, _backspace))

	result_dialog = UI.build_dialog("", [
		{"text": tr("Next Word"), "action": _new_game},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	result_label = result_dialog.get_meta("message_label")
	add_child(result_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/wordle/wordle_help.gd"))
		add_child(info)
		info.high("Wins", int(stats.wins))
		info.high("Losses", int(stats.played) - int(stats.wins))
		info.high("Best streak", int(stats.best_streak))
	add_child(SettingsDrawer.new())

func _make_key(text: String, width: int, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(width, 88)
	btn.add_theme_font_size_override("font_size", 28 if text.length() == 1 else 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(action)
	return btn

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_submit()
	elif event.keycode == KEY_BACKSPACE:
		_backspace()
	elif event.unicode > 0:
		var letter := char(event.unicode).to_upper()
		if key_buttons.has(letter):  # A-Z, plus Ñ in Spanish
			_type_letter(letter)

# ---------- flow ----------

func _new_game() -> void:
	engine.reset()
	current = ""
	message_label.text = ""
	result_dialog.visible = false
	_render()

func _type_letter(letter: String) -> void:
	if engine.game_over or current.length() >= WordleEngine.WORD_LENGTH:
		return
	current += letter
	message_label.text = ""
	_render()

func _backspace() -> void:
	if engine.game_over or current.is_empty():
		return
	current = current.left(current.length() - 1)
	_render()

func _submit() -> void:
	if engine.game_over:
		return
	var result: String = engine.submit(current)
	if result == "short":
		message_label.text = tr("Not enough letters")
		return
	if result == "not_word":
		message_label.text = tr("Not in word list")
		return
	current = ""
	_render()
	if result == "won" or result == "lost":
		_record_result(result == "won")

func _record_result(won: bool) -> void:
	stats.played += 1
	if won:
		stats.wins += 1
		stats.streak += 1
		stats.best_streak = max(stats.best_streak, stats.streak)
	else:
		stats.streak = 0
	SaveUtil.write(STATS_PATH, stats)
	if info:
		info.result("win" if won else "loss")
		if won:
			info.low("Fewest guesses", engine.guesses.size())
	var headline: String
	if won:
		headline = [tr("Genius!"), tr("Magnificent!"), tr("Impressive!"), tr("Splendid!"), tr("Great!"), tr("Phew!")][engine.guesses.size() - 1]
	else:
		headline = tr("The word was %s") % engine.answer
	result_label.text = tr("%s\n\nPlayed %d · Won %d%%\nStreak %d · Best %d") % [
		headline, stats.played, int(round(100.0 * stats.wins / max(stats.played, 1))), stats.streak, stats.best_streak]
	create_tween().tween_callback(_show_result).set_delay(0.6)

func _show_result() -> void:
	if engine.game_over:
		result_dialog.visible = true

# ---------- rendering ----------

func _tile_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	return sb

func _render() -> void:
	for r in range(WordleEngine.MAX_GUESSES):
		for c in range(WordleEngine.WORD_LENGTH):
			var tile: Dictionary = tiles[r][c]
			var letter := ""
			var color := COLOR_EMPTY
			if r < engine.guesses.size():
				letter = engine.guesses[r][c]
				color = MARK_COLORS[engine.marks[r][c]]
			elif r == engine.guesses.size() and c < current.length():
				letter = current[c]
				color = COLOR_TYPED
			tile.label.text = letter
			tile.panel.add_theme_stylebox_override("panel", _tile_style(color))

	var states: Dictionary = engine.letter_states()
	for letter in key_buttons:
		var color: Color = MARK_COLORS[states[letter]] if states.has(letter) else COLOR_KEY
		var sb := _tile_style(color)
		for state in ["normal", "hover", "pressed", "focus"]:
			key_buttons[letter].add_theme_stylebox_override(state, sb)
