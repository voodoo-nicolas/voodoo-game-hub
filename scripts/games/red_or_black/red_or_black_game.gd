extends Control

const RedOrBlackEngine = preload("res://scripts/games/red_or_black/red_or_black_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const RED_SUITS := ["♥", "♦"]
const SUITS := ["♠", "♥", "♦", "♣"]

var engine
var num_players: int = 2

var setup_box: Control
var play_box: Control
var end_box: Control

var players_label: Label
var turn_label: Label
var round_label: Label
var stakes_label: Label
var history_label: Label
var card_label: Label
var result_label: Label
var guess_row: HBoxContainer
var next_btn: Button

func _ready() -> void:
	Orientation.lock_portrait()
	engine = RedOrBlackEngine.new()
	_build_ui()
	_show_setup()

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
	title.text = "🂡 Red or Black"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(spacer)

	_build_setup(root)
	_build_play(root)
	_build_end(root)
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
	rules_label.text = "4 rounds, each player draws one card per round.\nGuess right, give a drink. Guess wrong, take a drink.\nRound 1: Red/Black (1) · 2: Higher/Lower (2)\n3: Inside/Outside (3) · 4: Suit (4)"
	rules_label.add_theme_font_size_override("font_size", 13)
	rules_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rules_label)

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
	turn_label.add_theme_font_size_override("font_size", 22)
	turn_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(turn_label)

	round_label = Label.new()
	round_label.add_theme_font_size_override("font_size", 18)
	round_label.add_theme_color_override("font_color", Color(1, 1, 1))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(round_label)

	stakes_label = Label.new()
	stakes_label.add_theme_font_size_override("font_size", 14)
	stakes_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	stakes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stakes_label)

	history_label = Label.new()
	history_label.add_theme_font_size_override("font_size", 26)
	history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(history_label)

	card_label = Label.new()
	card_label.text = "🂠"
	card_label.add_theme_font_size_override("font_size", 80)
	card_label.add_theme_color_override("font_color", Color(1, 1, 1))
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(card_label)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 20)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	result_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(result_label)

	guess_row = HBoxContainer.new()
	guess_row.alignment = BoxContainer.ALIGNMENT_CENTER
	guess_row.add_theme_constant_override("separation", 14)
	box.add_child(guess_row)

	next_btn = Button.new()
	next_btn.text = "Next Player ➜"
	next_btn.custom_minimum_size = Vector2(240, 56)
	next_btn.add_theme_font_size_override("font_size", 18)
	next_btn.visible = false
	next_btn.pressed.connect(_on_next_pressed)
	box.add_child(next_btn)

func _build_end(root: VBoxContainer) -> void:
	end_box = CenterContainer.new()
	end_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	end_box.visible = false
	root.add_child(end_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	end_box.add_child(box)

	var big := Label.new()
	big.text = "🍻 Game Over!"
	big.add_theme_font_size_override("font_size", 32)
	big.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)

	var again_btn := Button.new()
	again_btn.text = "New Game"
	again_btn.custom_minimum_size = Vector2(220, 56)
	again_btn.pressed.connect(_show_setup)
	box.add_child(again_btn)

	var hub_btn := Button.new()
	hub_btn.text = "Back to Hub"
	hub_btn.custom_minimum_size = Vector2(220, 48)
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(hub_btn)

# ---------- flow ----------

func _show_setup() -> void:
	setup_box.visible = true
	play_box.visible = false
	end_box.visible = false

func _on_start_pressed() -> void:
	engine.reset(num_players)
	setup_box.visible = false
	end_box.visible = false
	play_box.visible = true
	card_label.text = "🂠"
	card_label.add_theme_color_override("font_color", Color(1, 1, 1))
	result_label.text = ""
	next_btn.visible = false
	_update_round_display()

func _card_text(card: Dictionary) -> String:
	return "%s%s" % [card.rank, card.suit]

func _update_round_display() -> void:
	turn_label.text = "Player %d's turn" % (engine.current_player + 1)
	var r: Dictionary = engine.current_round()
	round_label.text = "ROUND %d: %s" % [engine.round_index + 1, r.name.to_upper()]
	stakes_label.text = "Correct: give %d  ·  Wrong: take %d" % [r.drink, r.drink]

	var history: Array = engine.player_cards[engine.current_player]
	var pieces: PackedStringArray = []
	for c in history:
		pieces.append(_card_text(c))
	history_label.text = " → ".join(pieces) if not pieces.is_empty() else ""

	for child in guess_row.get_children():
		guess_row.remove_child(child)
		child.queue_free()

	match engine.round_index:
		0:
			_add_guess_button("Red", "red", Color(0.8, 0.2, 0.2))
			_add_guess_button("Black", "black", Color(0.15, 0.15, 0.18))
		1:
			_add_guess_button("Higher", "higher", Color(0.2, 0.5, 0.3))
			_add_guess_button("Lower", "lower", Color(0.5, 0.3, 0.2))
		2:
			_add_guess_button("Inside", "inside", Color(0.2, 0.4, 0.55))
			_add_guess_button("Outside", "outside", Color(0.5, 0.35, 0.15))
		3:
			for suit in SUITS:
				_add_guess_button(suit, suit, Color(0.8, 0.2, 0.2) if RED_SUITS.has(suit) else Color(0.15, 0.15, 0.18))

func _add_guess_button(label_text: String, guess: String, color: Color) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(90, 64)
	btn.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.pressed.connect(_on_guess_pressed.bind(guess))
	guess_row.add_child(btn)

func _on_guess_pressed(guess: String) -> void:
	var result: Dictionary = engine.answer(guess)
	var card: Dictionary = result.card
	var color := Color(1, 0.4, 0.4) if RED_SUITS.has(card.suit) else Color(1, 1, 1)
	card_label.text = _card_text(card)
	card_label.add_theme_color_override("font_color", color)

	if result.correct:
		result_label.text = "✅ Correct! Give %d away." % result.drink_amount
		result_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		result_label.text = "❌ Wrong! Drink %d." % result.drink_amount
		result_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	for child in guess_row.get_children():
		child.visible = false
	next_btn.visible = true
	next_btn.text = "See Results ➜" if result.game_finished else "Next Player ➜"
	next_btn.set_meta("finished", result.game_finished)

func _on_next_pressed() -> void:
	if next_btn.get_meta("finished", false):
		end_box.visible = true
		play_box.visible = false
		return
	result_label.text = ""
	card_label.text = "🂠"
	card_label.add_theme_color_override("font_color", Color(1, 1, 1))
	next_btn.visible = false
	_update_round_display()
