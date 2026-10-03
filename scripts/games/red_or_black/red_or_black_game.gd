extends Control

const RedOrBlackEngine = preload("res://scripts/games/red_or_black/red_or_black_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const RED_SUITS := ["♥", "♦"]
const SUITS := ["♠", "♥", "♦", "♣"]

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var num_players: int = 2

var setup_box: Control
var play_box: Control
var end_box: Control

var players_label: Label
var turn_label: Label
var round_label: Label
var stakes_label: Label
var history_row: HBoxContainer
var card_slot: CenterContainer
var tracker_grid: GridContainer
var odds_label: Label
var result_label: Label
var guess_row: HBoxContainer
var next_btn: Button

func _ready() -> void:
	preload("res://scripts/games/red_or_black/red_or_black_i18n.gd").install(self)
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
	hub_btn.text = tr("Hub")
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("🂡 Red or Black")
	title.add_theme_font_size_override("font_size", 31)
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
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/red_or_black/red_or_black_help.gd"))
		add_child(info)
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
	label.text = tr("How many players?")
	label.add_theme_font_size_override("font_size", 31)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var counter_row := HBoxContainer.new()
	counter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_row.add_theme_constant_override("separation", 24)
	box.add_child(counter_row)

	var minus_btn := _counter_button("−")
	minus_btn.pressed.connect(_change_players.bind(-1))
	counter_row.add_child(minus_btn)

	players_label = Label.new()
	players_label.text = str(num_players)
	players_label.add_theme_font_size_override("font_size", 64)
	players_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	players_label.custom_minimum_size = Vector2(90, 0)
	players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_row.add_child(players_label)

	var plus_btn := _counter_button("+")
	plus_btn.pressed.connect(_change_players.bind(1))
	counter_row.add_child(plus_btn)

	var start_btn := Button.new()
	start_btn.text = tr("Start Game")
	start_btn.custom_minimum_size = Vector2(300, 72)
	start_btn.add_theme_font_size_override("font_size", 32)
	start_btn.pressed.connect(_on_start_pressed)
	box.add_child(start_btn)

	var rules_label := Label.new()
	rules_label.text = tr("4 rounds, each player draws one card per round.\nGuess right, give a drink. Guess wrong, take a drink.\nRound 1: Red/Black (1) · 2: Higher/Lower (2)\n3: Inside/Outside (3) · 4: Suit (4)")
	rules_label.add_theme_font_size_override("font_size", 19)
	rules_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rules_label)

func _build_play(root: VBoxContainer) -> void:
	play_box = MarginContainer.new()
	play_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.add_theme_constant_override("margin_left", 16)
	play_box.add_theme_constant_override("margin_right", 16)
	play_box.add_theme_constant_override("margin_bottom", 16)
	play_box.visible = false
	root.add_child(play_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	play_box.add_child(box)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 36)
	turn_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(turn_label)

	round_label = Label.new()
	round_label.add_theme_font_size_override("font_size", 28)
	round_label.add_theme_color_override("font_color", Color(1, 1, 1))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(round_label)

	stakes_label = Label.new()
	stakes_label.add_theme_font_size_override("font_size", 22)
	stakes_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	stakes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stakes_label)

	# This player's earlier cards (small), then the card being guessed (big).
	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 18)
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(cards_row)
	history_row = HBoxContainer.new()
	history_row.alignment = BoxContainer.ALIGNMENT_CENTER
	history_row.add_theme_constant_override("separation", 6)
	history_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cards_row.add_child(history_row)
	card_slot = CenterContainer.new()
	cards_row.add_child(card_slot)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 30)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	result_label.custom_minimum_size = Vector2(300, 40)
	box.add_child(result_label)

	guess_row = HBoxContainer.new()
	guess_row.alignment = BoxContainer.ALIGNMENT_CENTER
	guess_row.add_theme_constant_override("separation", 14)
	box.add_child(guess_row)

	next_btn = Button.new()
	next_btn.text = tr("Next Player ➜")
	next_btn.custom_minimum_size = Vector2(0, 96)
	next_btn.add_theme_font_size_override("font_size", 34)
	next_btn.visible = false
	next_btn.pressed.connect(_on_next_pressed)
	box.add_child(next_btn)

	# Every card already drawn from this one deck, so players can work the odds.
	var tracker_title := Label.new()
	tracker_title.text = tr("Cards played")
	tracker_title.add_theme_font_size_override("font_size", 22)
	tracker_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	tracker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tracker_title)
	tracker_grid = GridContainer.new()
	tracker_grid.columns = 14
	tracker_grid.add_theme_constant_override("h_separation", 2)
	tracker_grid.add_theme_constant_override("v_separation", 2)
	tracker_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(tracker_grid)
	odds_label = Label.new()
	odds_label.add_theme_font_size_override("font_size", 22)
	odds_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	odds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(odds_label)

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
	big.text = tr("🍻 Game Over!")
	big.add_theme_font_size_override("font_size", 39)
	big.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)

	var again_btn := Button.new()
	again_btn.text = tr("New Game")
	again_btn.custom_minimum_size = Vector2(220, 56)
	again_btn.pressed.connect(_show_setup)
	box.add_child(again_btn)

	var hub_btn := Button.new()
	hub_btn.text = tr("Back to Hub")
	hub_btn.custom_minimum_size = Vector2(220, 48)
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(hub_btn)

# ---------- flow ----------

func _show_setup() -> void:
	setup_box.visible = true
	play_box.visible = false
	end_box.visible = false

func _on_start_pressed() -> void:
	if info:
		info.add("Games played")
	engine.reset(num_players)
	setup_box.visible = false
	end_box.visible = false
	play_box.visible = true
	result_label.text = ""
	next_btn.visible = false
	_update_round_display()

func _card_text(card: Dictionary) -> String:
	return "%s%s" % [card.rank, card.suit]

func _change_players(delta: int) -> void:
	num_players = clampi(num_players + delta, 2, 12)  # 12 x 4 rounds fits one deck
	players_label.text = str(num_players)

## A big, bordered square button, so −/+ read as buttons at a glance.
static func _counter_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(96, 96)
	btn.add_theme_font_size_override("font_size", 52)
	btn.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.2, 0.26) if state != "pressed" else Color(0.3, 0.3, 0.38)
		sb.set_border_width_all(3)
		sb.border_color = Color(1, 0.8, 0.3)
		sb.set_corner_radius_all(18)
		btn.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(c, Color(1, 0.85, 0.3))
	return btn

## A playing card drawn as a panel: face up (rank + suit) or, with an empty
## card, face down.
func _make_card(card: Dictionary, w: float) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, w * 1.4)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(w * 0.1))
	sb.set_border_width_all(maxi(2, int(w * 0.03)))
	if card.is_empty():
		sb.bg_color = Color(0.55, 0.1, 0.14)
		sb.border_color = Color(0.95, 0.95, 0.95)
	else:
		sb.bg_color = Color(0.97, 0.96, 0.92)
		sb.border_color = Color(0.3, 0.3, 0.35)
	panel.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if card.is_empty():
		l.text = "?"
		l.add_theme_font_size_override("font_size", int(w * 0.5))
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	else:
		l.text = "%s\n%s" % [card.rank, card.suit]
		l.add_theme_font_size_override("font_size", int(w * 0.36))
		l.add_theme_color_override("font_color", Color(0.85, 0.12, 0.15) if RED_SUITS.has(card.suit) else Color(0.08, 0.08, 0.1))
	panel.add_child(l)
	return panel

## The player's earlier cards beside the big card being guessed (face down
## until the guess, then `shown`).
func _render_cards(shown: Dictionary, history: Array) -> void:
	for c in history_row.get_children():
		c.queue_free()
	for c in card_slot.get_children():
		c.queue_free()
	for c in history:
		history_row.add_child(_make_card(c, 74))
	card_slot.add_child(_make_card(shown, 170))

func _played_cards() -> Array:
	var out: Array = []
	for h in engine.player_cards:
		out.append_array(h)
	return out

## 4 suit rows x 13 ranks; drawn cards stay bright, the rest are dimmed, plus
## what's left in the deck by color.
func _update_tracker() -> void:
	for c in tracker_grid.get_children():
		c.queue_free()
	var played := {}
	var red_out := 0
	for c in _played_cards():
		played[_card_text(c)] = true
		if RED_SUITS.has(c.suit):
			red_out += 1
	var cell_w: float = floorf((get_viewport_rect().size.x - 60.0) / 14.0)
	for suit in SUITS:
		var red: bool = RED_SUITS.has(suit)
		var ink := Color(1, 0.4, 0.4) if red else Color(0.92, 0.92, 0.95)
		tracker_grid.add_child(_tracker_cell(suit, ink, true, cell_w))
		for rank in RedOrBlackEngine.RANKS:
			tracker_grid.add_child(_tracker_cell(rank, ink, played.has(rank + suit), cell_w))
	var total_out: int = _played_cards().size()
	odds_label.text = tr("Left in deck: %d red · %d black") % [26 - red_out, 26 - (total_out - red_out)]

func _tracker_cell(text: String, ink: Color, bright: bool, w: float) -> Control:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", ink if bright else Color(ink, 0.18))
	return l

func _update_round_display() -> void:
	turn_label.text = tr("Player %d's turn") % (engine.current_player + 1)
	var r: Dictionary = engine.current_round()
	round_label.text = tr("ROUND %d: %s") % [engine.round_index + 1, tr(r.name).to_upper()]
	stakes_label.text = tr("Correct: give %d  ·  Wrong: take %d") % [r.drink, r.drink]

	_render_cards({}, engine.player_cards[engine.current_player])
	_update_tracker()

	for child in guess_row.get_children():
		guess_row.remove_child(child)
		child.queue_free()

	match engine.round_index:
		0:
			_add_guess_button(tr("Red"), "red", Color(0.8, 0.2, 0.2))
			_add_guess_button(tr("Black"), "black", Color(0.15, 0.15, 0.18))
		1:
			_add_guess_button(tr("Higher"), "higher", Color(0.2, 0.5, 0.3))
			_add_guess_button(tr("Lower"), "lower", Color(0.5, 0.3, 0.2))
		2:
			_add_guess_button(tr("Inside"), "inside", Color(0.2, 0.4, 0.55))
			_add_guess_button(tr("Outside"), "outside", Color(0.5, 0.35, 0.15))
		3:
			for suit in SUITS:
				_add_guess_button(suit, suit, Color(0.8, 0.2, 0.2) if RED_SUITS.has(suit) else Color(0.15, 0.15, 0.18))

func _add_guess_button(label_text: String, guess: String, color: Color) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 38 if label_text.length() > 1 else 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.35)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.pressed.connect(_on_guess_pressed.bind(guess))
	guess_row.add_child(btn)

func _on_guess_pressed(guess: String) -> void:
	var earlier: Array = engine.player_cards[engine.current_player].duplicate()
	var result: Dictionary = engine.answer(guess)
	if info:
		info.add("Right guesses" if result.correct else "Wrong guesses")
	_render_cards(result.card, earlier)
	_update_tracker()

	if result.correct:
		result_label.text = tr("✅ Correct! Give %d away.") % result.drink_amount
		result_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		result_label.text = tr("❌ Wrong! Drink %d.") % result.drink_amount
		result_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	for child in guess_row.get_children():
		child.visible = false
	next_btn.visible = true
	next_btn.text = tr("See Results ➜") if result.game_finished else tr("Next Player ➜")
	next_btn.set_meta("finished", result.game_finished)

func _on_next_pressed() -> void:
	if next_btn.get_meta("finished", false):
		end_box.visible = true
		play_box.visible = false
		return
	result_label.text = ""
	next_btn.visible = false
	_update_round_display()
