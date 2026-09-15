extends Control

const HangmanEngine = preload("res://scripts/games/hangman/hangman_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const STAGE_FACES := ["🙂", "😐", "😟", "😧", "😨", "😰", "💀"]
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

var engine
var game_active: bool = false

var word_label: Label
var stage_label: Label
var status_label: Label
var letter_buttons: Dictionary = {}  # letter -> Button
var end_dialog: Control
var end_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = HangmanEngine.new()
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
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

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)

	var hub_btn := Button.new()
	hub_btn.text = "Hub"
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = "Hangman"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "New Word"
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	stage_label = Label.new()
	stage_label.add_theme_font_size_override("font_size", 64)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stage_label)

	word_label = Label.new()
	word_label.add_theme_font_size_override("font_size", 36)
	word_label.add_theme_color_override("font_color", Color(1, 1, 1))
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(word_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)

	var keyboard_margin := MarginContainer.new()
	keyboard_margin.add_theme_constant_override("margin_left", 16)
	keyboard_margin.add_theme_constant_override("margin_right", 16)
	keyboard_margin.add_theme_constant_override("margin_bottom", 24)
	box.add_child(keyboard_margin)

	var keyboard := GridContainer.new()
	keyboard.columns = 7
	keyboard.add_theme_constant_override("h_separation", 4)
	keyboard.add_theme_constant_override("v_separation", 4)
	keyboard_margin.add_child(keyboard)

	for letter in ALPHABET:
		var btn := Button.new()
		btn.text = letter
		btn.custom_minimum_size = Vector2(40, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_letter_pressed.bind(letter))
		keyboard.add_child(btn)
		letter_buttons[letter] = btn

	_build_end_dialog()
	add_child(SettingsDrawer.new())

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
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 22)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_label)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		end_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Back to Hub"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(menu_btn)

# ---------- game flow ----------

func _start_new_game() -> void:
	engine.reset()
	game_active = true
	end_dialog.visible = false
	for letter in letter_buttons:
		var btn: Button = letter_buttons[letter]
		btn.disabled = false
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_render()

func _on_letter_pressed(letter: String) -> void:
	if not game_active:
		return
	var result: String = engine.guess(letter)
	var btn: Button = letter_buttons[letter]
	btn.disabled = true
	btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if result == "correct" else Color(0.9, 0.4, 0.4))
	_render()

	if engine.is_won():
		_end_game("You win! The word was %s" % engine.word, Color(0.4, 0.9, 0.4))
	elif engine.is_lost():
		_end_game("Game over — the word was %s" % engine.word, Color(0.9, 0.4, 0.4))

func _end_game(text: String, color: Color) -> void:
	game_active = false
	end_label.text = text
	end_label.add_theme_color_override("font_color", color)
	end_dialog.visible = true

func _render() -> void:
	word_label.text = engine.display_word()
	stage_label.text = STAGE_FACES[engine.wrong_count]
	status_label.text = "Wrong guesses: %d/%d" % [engine.wrong_count, HangmanEngine.MAX_WRONG]
