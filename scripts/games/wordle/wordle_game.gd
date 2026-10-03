extends Control

## Wordle: 6 rows of 5 tiles and an on-screen keyboard whose keys take on the
## best color each letter has earned so far. A physical keyboard works too.

const WordleEngine = preload("res://scripts/games/wordle/wordle_engine.gd")
const HomeKit = preload("res://scripts/games/wordle/home_kit.gd")
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
const COLOR_BG := HomeKit.BG
const COLOR_EMPTY := Color(0.24, 0.32, 0.55)
const COLOR_TYPED := Color("29e6ff")
const COLOR_KEY := Color(0.45, 0.55, 0.85)
const MARK_COLORS := {
	WordleEngine.Mark.ABSENT: Color(0.4, 0.42, 0.5),
	WordleEngine.Mark.PRESENT: Color("ffae2b"),
	WordleEngine.Mark.CORRECT: Color("7dff3a"),
}
const SAVE_PATH := "user://wordle_save.json"

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var current: String = ""
var stats: Dictionary = {"played": 0, "wins": 0, "streak": 0, "best_streak": 0}

var tiles: Array = []  # 6 x 5 {panel, label}
var key_buttons: Dictionary = {}  # letter -> Button
var message_label: Label
var result_dialog: Control
var result_label: Label
## Two players: one types the secret word first (setting), the other guesses.
var two_player := false
var setting := false
var playing := false  # a word is being guessed (not just the one behind Home)

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
	playing = false

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
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
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
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
	# Tiles and keys follow the screen, so the game keeps the full text size.
	var view := get_viewport_rect().size
	var tile_px: float = floor(clampf(minf((view.x - 80.0) / 5.0, (view.y - 600.0) / 6.6), 56.0, 104.0))
	var key_px: float = floor((view.x - 16.0 - 9 * 6.0) / 10.0)
	board.add_theme_constant_override("h_separation", 10)
	board.add_theme_constant_override("v_separation", 10)
	center.add_child(board)
	for r in range(WordleEngine.MAX_GUESSES):
		var row: Array = []
		for c in range(WordleEngine.WORD_LENGTH):
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(tile_px, tile_px)
			var label := Label.new()
			label.add_theme_font_size_override("font_size", int(tile_px * 0.5))
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
			row.add_child(_make_key(tr("Enter").to_upper(), int(key_px * 1.6), _submit))
		for letter in key_rows[i]:
			key_buttons[letter] = _make_key(letter, int(key_px), _type_letter.bind(letter))
			row.add_child(key_buttons[letter])
		if i == 2:
			row.add_child(_make_key("⌫", int(key_px * 1.6), _backspace))

	result_dialog = UI.build_dialog("", [
		{"text": tr("Next Word"), "action": _new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	result_label = result_dialog.get_meta("message_label")
	add_child(result_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/wordle/wordle_help.gd"))
	_build_home()
	if info:
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
	btn.set_meta("sfx", "")  # no tap: typing sounds play in _type_letter etc. (PC keyboard too)
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
	playing = true
	setting = false
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
	_sfx("key")
	_render()

func _backspace() -> void:
	if engine.game_over or current.is_empty():
		return
	current = current.left(current.length() - 1)
	_sfx("back")
	_render()

func _submit() -> void:
	if setting:
		if current.length() != WordleEngine.WORD_LENGTH:
			message_label.text = tr("Not enough letters")
			return
		engine.reset(current)
		current = ""
		setting = false
		message_label.text = tr("Guesser: your turn!")
		_render()
		return
	if engine.game_over:
		return
	var result: String = engine.submit(current)
	if result == "short":
		message_label.text = tr("Not enough letters")
		_sfx("invalid")
		return
	if result == "not_word":
		message_label.text = tr("Not in word list")
		_sfx("invalid")
		return
	current = ""
	_render()
	if result == "won" or result == "lost":
		_record_result(result == "won")
	else:
		# Bright if the guess hit a letter in its right spot, dull if not.
		_sfx("letter_right" if WordleEngine.Mark.CORRECT in engine.marks[-1] else "letter_wrong")

## Plays a sound from the app's library (silent on apps from before v0.23).
func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _record_result(won: bool) -> void:
	SaveUtil.delete(SAVE_PATH)
	if two_player:
		if info:
			info.add("Words guessed (2 players)" if won else "Words kept (2 players)")
		result_label.text = (tr("The guesser wins!") if won else tr("The setter wins — the word was %s") % engine.answer)
		create_tween().tween_callback(_show_result).set_delay(0.6)
		return
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

## Neon tile: tinted glass with a glowing rim in the mark's colour.
func _tile_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.25 if color in MARK_COLORS.values() else 0.07)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.shadow_color = Color(color, 0.3)
	sb.shadow_size = 5
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

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/wordle/wordle_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/wordle/wordle_help.gd"),
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Guess the five-letter word in six tries.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🔤  Guess a word", "sub": "Solo", "action": _new_word.bind(false)},
			{"text": "👥  Set a word for a friend", "sub": "One types a secret word, the other guesses", "multi": true, "action": _new_word.bind(true)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): var d = SaveUtil.read(SAVE_PATH); return "" if d == null else tr("Guess %d of 6") % (d.guesses.size() + 1),
		"restart": _new_game,
		"board": "Wins",
		"board_note": "Words guessed on your own.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 2.4, 62.0)
	var o := Vector2(c.size.x / 2.0 - k * 2.5, c.size.y / 2.0 - k * 1.05)
	var rows := [["N", 0], ["E", 1], ["O", 2], ["N", 0], ["S", 0]]
	var rows2 := [["V", 2], ["O", 2], ["O", 2], ["D", 2], ["O", 2]]
	for i in 5:
		for spec in [[rows[i], 0], [rows2[i], 1]]:
			var cell: Array = spec[0]
			var r := Rect2(o + Vector2(i * k, spec[1] * k * 1.1), Vector2(k, k)).grow(-4)
			var col: Color = MARK_COLORS[[WordleEngine.Mark.ABSENT, WordleEngine.Mark.PRESENT, WordleEngine.Mark.CORRECT][cell[1]]]
			HomeKit.glow_rect(c, r, col, 2.0, 0.3)
			HomeKit.glow_text(c, r.get_center(), cell[0], int(k * 0.5), Color.WHITE)

func _new_word(two: bool) -> void:
	two_player = two
	SaveUtil.delete(SAVE_PATH)
	_new_game()
	if two_player:
		setting = true
		message_label.text = tr("Word setter: type a 5-letter word, then Enter. Guesser — look away!")
		_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not playing or setting or engine.game_over:
		return
	SaveUtil.write(SAVE_PATH, {"answer": engine.answer, "guesses": engine.guesses, "spanish": engine.spanish, "two": two_player})

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_new_game()
		return
	_new_game()
	two_player = bool(d.get("two", false))
	engine.reset(str(d.answer))
	for g in d.get("guesses", []):
		engine.guesses.append(str(g))
		engine.marks.append(WordleEngine.score_guess(str(g), engine.answer))
	_render()
