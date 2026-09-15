extends Control

const ThreeManEngine = preload("res://scripts/games/three_man/three_man_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const DIE_FACES := ["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]

var engine
var num_players: int = 4

var setup_box: Control
var tiebreak_box: Control
var play_box: Control

var players_label: Label
var tiebreak_rolls_label: Label
var tiebreak_status_label: Label
var tiebreak_btn: Button

var turn_label: Label
var three_man_label: Label
var dice_label: Label
var messages_label: Label
var roll_btn: Button

func _ready() -> void:
	Orientation.lock_portrait()
	engine = ThreeManEngine.new()
	_build_ui()
	_show_setup()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.05)
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
	title.text = "3️⃣ Three Man"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(spacer)

	_build_setup(root)
	_build_tiebreak(root)
	_build_play(root)
	add_child(SettingsDrawer.new())

func _build_setup(root: VBoxContainer) -> void:
	setup_box = CenterContainer.new()
	setup_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(setup_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	setup_box.add_child(box)

	var label := Label.new()
	label.text = "How many players?"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var counter_row := HBoxContainer.new()
	counter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_row.add_theme_constant_override("separation", 24)
	box.add_child(counter_row)

	var minus_btn := Button.new()
	minus_btn.text = "－"
	minus_btn.custom_minimum_size = Vector2(64, 64)
	minus_btn.add_theme_font_size_override("font_size", 28)
	minus_btn.pressed.connect(func():
		num_players = max(2, num_players - 1)
		players_label.text = str(num_players)
	)
	counter_row.add_child(minus_btn)

	players_label = Label.new()
	players_label.text = str(num_players)
	players_label.add_theme_font_size_override("font_size", 40)
	players_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	players_label.custom_minimum_size = Vector2(70, 0)
	players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_row.add_child(players_label)

	var plus_btn := Button.new()
	plus_btn.text = "＋"
	plus_btn.custom_minimum_size = Vector2(64, 64)
	plus_btn.add_theme_font_size_override("font_size", 28)
	plus_btn.pressed.connect(func():
		num_players = min(12, num_players + 1)
		players_label.text = str(num_players)
	)
	counter_row.add_child(plus_btn)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(220, 56)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_on_start_pressed)
	box.add_child(start_btn)

	var rules_label := Label.new()
	rules_label.text = "Roll 1 die each — lowest goes first (ties re-roll).\nThen pass the phone: roll 2 dice on your turn.\n7 = right drinks · 11 = left drinks · Doubles = give that many\nAny 3 (or 2&1) = become/feed 3 Man. Keep rolling while someone drinks!"
	rules_label.add_theme_font_size_override("font_size", 13)
	rules_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	rules_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(rules_label)

func _build_tiebreak(root: VBoxContainer) -> void:
	tiebreak_box = CenterContainer.new()
	tiebreak_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tiebreak_box.visible = false
	root.add_child(tiebreak_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	tiebreak_box.add_child(box)

	var label := Label.new()
	label.text = "Rolling to see who goes first…"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	tiebreak_rolls_label = Label.new()
	tiebreak_rolls_label.add_theme_font_size_override("font_size", 18)
	tiebreak_rolls_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75))
	tiebreak_rolls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tiebreak_rolls_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tiebreak_rolls_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(tiebreak_rolls_label)

	tiebreak_status_label = Label.new()
	tiebreak_status_label.add_theme_font_size_override("font_size", 22)
	tiebreak_status_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	tiebreak_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tiebreak_status_label)

	tiebreak_btn = Button.new()
	tiebreak_btn.text = "Roll for First"
	tiebreak_btn.custom_minimum_size = Vector2(220, 56)
	tiebreak_btn.add_theme_font_size_override("font_size", 20)
	tiebreak_btn.pressed.connect(_on_tiebreak_pressed)
	box.add_child(tiebreak_btn)

func _build_play(root: VBoxContainer) -> void:
	play_box = CenterContainer.new()
	play_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.visible = false
	root.add_child(play_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	play_box.add_child(box)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 24)
	turn_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(turn_label)

	three_man_label = Label.new()
	three_man_label.add_theme_font_size_override("font_size", 16)
	three_man_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
	three_man_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(three_man_label)

	dice_label = Label.new()
	dice_label.text = "⚀ ⚀"
	dice_label.add_theme_font_size_override("font_size", 80)
	dice_label.add_theme_color_override("font_color", Color(1, 1, 1))
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(dice_label)

	messages_label = Label.new()
	messages_label.add_theme_font_size_override("font_size", 19)
	messages_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	messages_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	messages_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	messages_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(messages_label)

	roll_btn = Button.new()
	roll_btn.text = "🎲 Roll"
	roll_btn.custom_minimum_size = Vector2(220, 56)
	roll_btn.add_theme_font_size_override("font_size", 20)
	roll_btn.pressed.connect(_on_roll_pressed)
	box.add_child(roll_btn)

# ---------- flow ----------

func _show_setup() -> void:
	setup_box.visible = true
	tiebreak_box.visible = false
	play_box.visible = false

func _on_start_pressed() -> void:
	engine.reset(num_players)
	setup_box.visible = false
	play_box.visible = false
	tiebreak_box.visible = true
	tiebreak_rolls_label.text = ""
	tiebreak_status_label.text = ""
	tiebreak_btn.text = "Roll for First"

func _on_tiebreak_pressed() -> void:
	var result: Dictionary = engine.roll_tiebreak()
	var pieces: PackedStringArray = []
	for p in result.rolls.keys():
		pieces.append("P%d: %d" % [p + 1, result.rolls[p]])
	tiebreak_rolls_label.text = ", ".join(pieces)

	if result.resolved:
		tiebreak_status_label.text = "Player %d goes first!" % (result.first_player + 1)
		tiebreak_btn.text = "Start Playing ➜"
		tiebreak_btn.pressed.disconnect(_on_tiebreak_pressed)
		tiebreak_btn.pressed.connect(_on_begin_play)
	else:
		var names: PackedStringArray = []
		for p in result.pool:
			names.append("P%d" % (p + 1))
		tiebreak_status_label.text = "Tied: %s — reroll!" % ", ".join(names)

func _on_begin_play() -> void:
	tiebreak_box.visible = false
	play_box.visible = true
	messages_label.text = ""
	dice_label.text = "⚀ ⚀"
	_update_turn_display()

func _update_turn_display() -> void:
	turn_label.text = "Player %d's turn" % (engine.current_player + 1)
	three_man_label.text = "3 Man: Player %d" % (engine.three_man + 1) if engine.three_man >= 0 else "3 Man: not assigned yet"
	roll_btn.text = "🎲 Roll"

func _on_roll_pressed() -> void:
	var result: Dictionary = engine.roll_turn()
	dice_label.text = "%s %s" % [DIE_FACES[result.die1], DIE_FACES[result.die2]]
	messages_label.text = "\n".join(result.messages)
	three_man_label.text = "3 Man: Player %d" % (engine.three_man + 1) if engine.three_man >= 0 else "3 Man: not assigned yet"

	if result.continue_turn:
		roll_btn.text = "🎲 Roll Again"
	else:
		roll_btn.text = "Next Player ➜"
		roll_btn.pressed.disconnect(_on_roll_pressed)
		roll_btn.pressed.connect(_on_next_player_pressed)

func _on_next_player_pressed() -> void:
	engine.advance_player()
	roll_btn.pressed.disconnect(_on_next_player_pressed)
	roll_btn.pressed.connect(_on_roll_pressed)
	messages_label.text = ""
	dice_label.text = "⚀ ⚀"
	_update_turn_display()
