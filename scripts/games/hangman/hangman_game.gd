extends Control

const HangmanEngine = preload("res://scripts/games/hangman/hangman_engine.gd")
const HomeKit = preload("res://scripts/games/hangman/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const WOOD := Color("9b4dff")
const WOOD_DARK := Color(0.25, 0.1, 0.45)
const ROPE := Color("ffae2b")
const FIGURE := Color("29e6ff")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://hangman_save.json"
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const ALPHABET_ES := "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ"

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var game_active: bool = false

var category_label: Label
var word_label: Label
var gallows: Control
var shown_parts: int = 0
## 0..1 while the newest body part fades in; redraws as it changes.
var part_fade: float = 1.0:
	set(v):
		part_fade = v
		if gallows:
			gallows.queue_redraw()
var status_label: Label
var letter_buttons: Dictionary = {}  # letter -> Button
var end_dialog: Control
## Two players on one phone: one types the word (setting), the other guesses.
var two_player := false
var setting := false
var typed := ""
var set_row: HBoxContainer
var end_label: Label

func _ready() -> void:
	preload("res://scripts/games/hangman/hangman_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = HangmanEngine.new()
	# Language is fixed for the visit: switching happens in the hub.
	engine.spanish = TranslationServer.get_locale().begins_with("es")
	_build_ui()
	_start_new_game()

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

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)

	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("Hangman")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.LIME.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.LIME, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	# A CenterContainer shrinks its child to its minimum width, which squeezed
	# the letter keys into a narrow column. Claim the screen's width instead.
	box.custom_minimum_size = Vector2(get_viewport_rect().size.x - 24, 0)
	center.add_child(box)

	var category_tag := Label.new()
	category_tag.text = tr("Topic").to_upper()
	category_tag.add_theme_font_size_override("font_size", 24)
	category_tag.add_theme_color_override("font_color", Color(0.5, 0.55, 0.53))
	category_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(category_tag)

	category_label = Label.new()
	category_label.add_theme_font_size_override("font_size", 28)
	category_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(category_label)

	gallows = Control.new()
	gallows.custom_minimum_size = Vector2(260, 250)
	gallows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gallows.draw.connect(_draw_gallows)
	box.add_child(gallows)

	word_label = Label.new()
	word_label.add_theme_font_size_override("font_size", 50)
	word_label.add_theme_color_override("font_color", Color(1, 1, 1))
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(word_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)

	set_row = HBoxContainer.new()
	set_row.alignment = BoxContainer.ALIGNMENT_CENTER
	set_row.add_theme_constant_override("separation", 16)
	set_row.visible = false
	box.add_child(set_row)
	var back_btn := HomeKit.neon_button("⌫", HomeKit.PINK, 30, 72)
	back_btn.custom_minimum_size.x = 140
	back_btn.pressed.connect(_on_set_back)
	set_row.add_child(back_btn)
	var done_btn := HomeKit.neon_button(tr("🔒 Lock word"), HomeKit.LIME, 28, 72)
	done_btn.custom_minimum_size.x = 280
	done_btn.pressed.connect(_on_set_done)
	set_row.add_child(done_btn)

	var keyboard_margin := MarginContainer.new()
	keyboard_margin.add_theme_constant_override("margin_left", 14)
	keyboard_margin.add_theme_constant_override("margin_right", 14)
	keyboard_margin.add_theme_constant_override("margin_bottom", 24)
	keyboard_margin.add_theme_constant_override("margin_top", 8)
	box.add_child(keyboard_margin)

	var keyboard := GridContainer.new()
	keyboard.columns = 7
	keyboard.add_theme_constant_override("h_separation", 6)
	keyboard.add_theme_constant_override("v_separation", 6)
	keyboard_margin.add_child(keyboard)

	for letter in (ALPHABET_ES if engine.spanish else ALPHABET):
		var btn := Button.new()
		btn.text = letter
		btn.custom_minimum_size = Vector2(0, 84)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 28)
		_style_letter_button(btn)
		btn.set_meta("sfx", "key")
		btn.pressed.connect(_on_letter_pressed.bind(letter))
		keyboard.add_child(btn)
		letter_buttons[letter] = btn

	_build_end_dialog()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/hangman/hangman_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _style_letter_button(btn: Button) -> void:
	var sb := HomeKit.neon_box(HomeKit.CYAN)
	sb.set_corner_radius_all(10)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	var sb_disabled := sb.duplicate()
	sb_disabled.bg_color = Color(0.04, 0.05, 0.1)
	sb_disabled.border_color = Color(HomeKit.CYAN, 0.2)
	sb_disabled.shadow_size = 0
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))

func _build_end_dialog() -> void:
	end_dialog = ColorRect.new()
	end_dialog.color = Color(0, 0, 0, 0.8)
	end_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	end_dialog.visible = false
	add_child(end_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_dialog.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.18)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 28)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_label)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(320, 64)
	again_btn.pressed.connect(func():
		end_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(_go_home)
	box.add_child(menu_btn)

# ---------- game flow ----------

func _start_new_game() -> void:
	result_recorded = false
	engine.reset()
	game_active = true
	end_dialog.visible = false
	for letter in letter_buttons:
		var btn: Button = letter_buttons[letter]
		btn.disabled = false
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1))
	_render()
	if two_player:
		_begin_setting()

func _on_letter_pressed(letter: String) -> void:
	if setting:
		if typed.length() < 14:
			typed += letter
		_render_setting()
		return
	if not game_active:
		return
	var result: String = engine.guess(letter)
	if result != "ignored":
		_sfx("letter_right" if result == "correct" else "letter_wrong")
	var btn: Button = letter_buttons[letter]
	btn.disabled = true
	btn.add_theme_color_override("font_disabled_color", HomeKit.LIME if result == "correct" else HomeKit.PINK)
	_render()

	if engine.is_won() or engine.is_lost():
		SaveUtil.delete(SAVE_PATH)
	if two_player and (engine.is_won() or engine.is_lost()):
		if info and not result_recorded:
			result_recorded = true
			info.add("Words guessed (2 players)" if engine.is_won() else "Words kept (2 players)")
		var t := (tr("The guesser wins! The word was %s") if engine.is_won() else tr("The setter wins — the word was %s")) % engine.word
		_end_game(t, HomeKit.LIME if engine.is_won() else HomeKit.PINK)
		return
	if engine.is_won():
		_end_game(tr("You win! The word was %s") % engine.word + _record_result("win"), Color(0.4, 0.9, 0.4))
	elif engine.is_lost():
		_end_game(tr("Game over — the word was %s") % engine.word + _record_result("loss"), Color(0.9, 0.4, 0.4))

func _end_game(text: String, color: Color) -> void:
	game_active = false
	end_label.text = text
	end_label.add_theme_color_override("font_color", color)
	end_dialog.visible = true

func _render() -> void:
	category_label.text = engine.category
	word_label.text = engine.display_word()
	# Long words ("FIREFIGHTER" = 21 characters with spaces) would run off a
	# narrow phone at full size.
	word_label.add_theme_font_size_override("font_size", 50 if engine.word.length() <= 8 else 40)
	if engine.wrong_count != shown_parts:
		# The newest body part fades in instead of popping.
		shown_parts = engine.wrong_count
		part_fade = 0.0
		var tw := create_tween()
		tw.tween_property(self, "part_fade", 1.0, 0.35)
	gallows.queue_redraw()
	status_label.text = tr("Wrong guesses: %d/%d") % [engine.wrong_count, HangmanEngine.MAX_WRONG]


## The wooden gallows, then one body part per wrong guess: head, body, left
## arm, right arm, left leg, right leg (HangmanEngine.MAX_WRONG = 6).
func _draw_gallows() -> void:
	var s: Vector2 = gallows.size
	var k: float = minf(s.x / 260.0, s.y / 250.0)
	var o := Vector2((s.x - 260.0 * k) / 2.0, (s.y - 250.0 * k) / 2.0)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * k
	var beam := 12.0 * k
	# Base, post, top beam, brace -- planks with a darker edge.
	for seg in [[p.call(20, 240), p.call(180, 240)], [p.call(60, 240), p.call(60, 18)],
			[p.call(54, 18), p.call(190, 18)], [p.call(60, 62), p.call(104, 18)]]:
		gallows.draw_line(seg[0], seg[1], WOOD_DARK, beam + 4.0 * k, true)
		gallows.draw_line(seg[0], seg[1], WOOD, beam, true)
	gallows.draw_line(p.call(180, 18), p.call(180, 56), ROPE, 4.0 * k, true)

	var n: int = engine.wrong_count if engine else 0
	var lost: bool = engine != null and engine.is_lost()
	var w := 5.0 * k
	for i in n:
		var c := FIGURE
		if i == n - 1:
			c.a = part_fade
		match i:
			0:
				gallows.draw_arc(p.call(180, 78), 22.0 * k, 0, TAU, 32, c, w, true)
				if lost:  # X eyes
					for ex in [172.0, 188.0]:
						gallows.draw_line(p.call(ex - 4, 72), p.call(ex + 4, 80), c, 3.0 * k, true)
						gallows.draw_line(p.call(ex + 4, 72), p.call(ex - 4, 80), c, 3.0 * k, true)
			1:
				gallows.draw_line(p.call(180, 100), p.call(180, 168), c, w, true)
			2:
				gallows.draw_line(p.call(180, 116), p.call(150, 146), c, w, true)
			3:
				gallows.draw_line(p.call(180, 116), p.call(210, 146), c, w, true)
			4:
				gallows.draw_line(p.call(180, 166), p.call(156, 212), c, w, true)
			5:
				gallows.draw_line(p.call(180, 166), p.call(204, 212), c, w, true)

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

const TITLE_FOR_HOME := preload("res://scripts/games/hangman/hangman_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/hangman/hangman_help.gd"),
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Guess the word one letter at a time.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🔤  Guess a word", "sub": "Solo", "action": _new_game.bind(false)},
			{"text": "👥  Set a word for a friend", "sub": "One player picks the word, the other guesses", "multi": true, "action": _new_game.bind(true)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _start_new_game,
		"board": "Wins",
		"board_note": "Words guessed on your own.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 250.0, 0.75)
	var o := Vector2(c.size.x / 2.0 - 130 * k, (c.size.y - 250 * k) / 2.0)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * k
	for seg in [[p.call(20, 240), p.call(180, 240)], [p.call(60, 240), p.call(60, 18)], [p.call(54, 18), p.call(190, 18)], [p.call(60, 62), p.call(104, 18)]]:
		HomeKit.glow_line(c, seg[0], seg[1], WOOD, 3.0)
	HomeKit.glow_line(c, p.call(180, 18), p.call(180, 56), ROPE, 2.0)
	HomeKit.glow_circle(c, p.call(180, 78), 22.0 * k, FIGURE, 2.5)
	HomeKit.glow_line(c, p.call(180, 100), p.call(180, 168), FIGURE, 2.5)

func _new_game(two: bool) -> void:
	two_player = two
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

## Two players: the setter types the word with the letter keys first.
func _begin_setting() -> void:
	setting = true
	typed = ""
	game_active = false
	set_row.visible = true
	for letter in letter_buttons:
		letter_buttons[letter].disabled = false
	_render_setting()

func _render_setting() -> void:
	category_label.text = tr("Word setter: type a word")
	word_label.text = " ".join(typed.split("")) if typed != "" else "…"
	status_label.text = tr("Guesser — look away!")
	gallows.queue_redraw()

func _on_set_back() -> void:
	typed = typed.substr(0, maxi(0, typed.length() - 1))
	_render_setting()

func _on_set_done() -> void:
	if typed.length() < 2:
		status_label.text = tr("At least 2 letters.")
		return
	setting = false
	set_row.visible = false
	engine.word = typed
	engine.category = tr("A friend's word")
	engine.guessed = {}
	engine.wrong_count = 0
	game_active = true
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not game_active or setting or engine.is_won() or engine.is_lost():
		return
	SaveUtil.write(SAVE_PATH, {"word": engine.word, "category": engine.category, "guessed": engine.guessed.keys(),
		"wrong": engine.wrong_count, "two": two_player})

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	two_player = bool(d.get("two", false))
	_start_new_game()
	setting = false
	set_row.visible = false
	game_active = true
	engine.word = str(d.word)
	engine.category = str(d.category)
	engine.guessed = {}
	for l in d.get("guessed", []):
		engine.guessed[str(l)] = true
		if letter_buttons.has(str(l)):
			var btn: Button = letter_buttons[str(l)]
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", HomeKit.LIME if engine.word.contains(str(l)) else HomeKit.PINK)
	engine.wrong_count = int(d.get("wrong", 0))
	_render()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
