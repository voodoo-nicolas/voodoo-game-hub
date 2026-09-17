extends Control

const WarEngine = preload("res://scripts/games/war/war_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const RED_SUITS := ["♥", "♦"]

var engine
var p1_pile_label: Label
var p2_pile_label: Label
var p1_card_label: Label
var p2_card_label: Label
var result_label: Label
var play_btn: Button
var win_dialog: Control
var win_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = WarEngine.new()
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_margin.add_child(top_bar)

	var hub_btn := Button.new()
	hub_btn.text = "Hub"
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = "⚔️ War"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var piles_row := HBoxContainer.new()
	piles_row.alignment = BoxContainer.ALIGNMENT_CENTER
	piles_row.add_theme_constant_override("separation", 60)
	box.add_child(piles_row)

	p1_pile_label = _pile_label("You: 26")
	piles_row.add_child(p1_pile_label)
	p2_pile_label = _pile_label("CPU: 26")
	piles_row.add_child(p2_pile_label)

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 30)
	box.add_child(cards_row)

	p1_card_label = _card_label()
	cards_row.add_child(p1_card_label)
	p2_card_label = _card_label()
	cards_row.add_child(p2_card_label)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 20)
	result_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	result_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(result_label)

	play_btn = Button.new()
	play_btn.text = "Play Round"
	play_btn.custom_minimum_size = Vector2(220, 56)
	play_btn.add_theme_font_size_override("font_size", 20)
	play_btn.pressed.connect(_on_play_pressed)
	box.add_child(play_btn)

	_build_win_dialog()
	add_child(SettingsDrawer.new())

func _pile_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	return l

func _card_label() -> Label:
	var l := Label.new()
	l.text = "🂠"
	l.add_theme_font_size_override("font_size", 70)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.custom_minimum_size = Vector2(90, 100)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _build_win_dialog() -> void:
	win_dialog = ColorRect.new()
	win_dialog.color = Color(0, 0, 0, 0.75)
	win_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_dialog.visible = false
	add_child(win_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_dialog.add_child(center)

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

	win_label = Label.new()
	win_label.add_theme_font_size_override("font_size", 24)
	win_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_label)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
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
	win_dialog.visible = false
	result_label.text = "Tap Play Round to begin!"
	p1_card_label.text = "🂠"
	p2_card_label.text = "🂠"
	p1_card_label.add_theme_color_override("font_color", Color(1, 1, 1))
	p2_card_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_update_piles()

func _on_play_pressed() -> void:
	var result: Dictionary = engine.play_round()
	_update_piles()

	if result.has("p1_card"):
		var c1: Dictionary = result.p1_card
		var c2: Dictionary = result.p2_card
		p1_card_label.text = "%s%s" % [c1.rank, c1.suit]
		p2_card_label.text = "%s%s" % [c2.rank, c2.suit]
		p1_card_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if RED_SUITS.has(c1.suit) else Color(1, 1, 1))
		p2_card_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if RED_SUITS.has(c2.suit) else Color(1, 1, 1))

		var prefix := "⚔️ WAR! " if result.war_happened else ""
		if result.round_winner == 1:
			result_label.text = "%sYou win %d cards!" % [prefix, result.cards_won]
		else:
			result_label.text = "%sCPU wins %d cards!" % [prefix, result.cards_won]
	elif result.has("ran_out"):
		result_label.text = "%s ran out of cards mid-war!" % ("You" if result.ran_out == 1 else "CPU")

	if result.game_over:
		_show_result()

func _update_piles() -> void:
	p1_pile_label.text = "You: %d" % engine.p1_pile.size()
	p2_pile_label.text = "CPU: %d" % engine.p2_pile.size()

func _show_result() -> void:
	win_label.text = "You win the game!" if engine.winner == 1 else "CPU wins the game!"
	win_dialog.visible = true
