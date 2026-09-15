extends Control

const KingsCupEngine = preload("res://scripts/games/kings_cup/kings_cup_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const RED_SUITS := ["♥", "♦"]
const CIRCLE_SIZE := 320.0
const CARD_SIZE := Vector2(26, 36)
const MIN_RADIUS := 55.0
const MAX_RADIUS := 145.0

var engine
var num_players: int = 4
var reveal_active: bool = false

var setup_box: Control
var play_box: Control
var end_box: Control

var players_label: Label
var turn_label: Label
var crown_label: Label
var circle_area: Control
var reveal_panel: Control
var reveal_card_label: Label
var reveal_title_label: Label
var reveal_desc_label: Label
var done_btn: Button
var hint_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = KingsCupEngine.new()
	_build_ui()
	_show_setup()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.06, 0.08)
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
	title.text = "👑 Kings Cup"
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
		num_players = min(20, num_players + 1)
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
	rules_label.text = "Pass the phone around. Pick a card from the circle,\nfollow the rule, tap Done. The 4th King drinks the cup!"
	rules_label.add_theme_font_size_override("font_size", 14)
	rules_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rules_label)

func _build_play(root: VBoxContainer) -> void:
	play_box = VBoxContainer.new()
	play_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.alignment = BoxContainer.ALIGNMENT_CENTER
	play_box.add_theme_constant_override("separation", 10)
	play_box.visible = false
	root.add_child(play_box)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 22)
	turn_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_box.add_child(turn_label)

	crown_label = Label.new()
	crown_label.add_theme_font_size_override("font_size", 18)
	crown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_box.add_child(crown_label)

	var circle_center := CenterContainer.new()
	circle_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.add_child(circle_center)

	circle_area = Control.new()
	circle_area.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	circle_center.add_child(circle_area)

	hint_label = Label.new()
	hint_label.text = "Tap a card to draw it"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_box.add_child(hint_label)

	_build_reveal_panel(play_box)

func _build_reveal_panel(parent: VBoxContainer) -> void:
	reveal_panel = PanelContainer.new()
	reveal_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.1, 0.09, 0.97)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.65, 0.2)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	reveal_panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_child(reveal_panel)
	parent.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	reveal_panel.add_child(box)

	reveal_card_label = Label.new()
	reveal_card_label.add_theme_font_size_override("font_size", 46)
	reveal_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reveal_card_label)

	reveal_title_label = Label.new()
	reveal_title_label.add_theme_font_size_override("font_size", 24)
	reveal_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	reveal_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reveal_title_label)

	reveal_desc_label = Label.new()
	reveal_desc_label.add_theme_font_size_override("font_size", 17)
	reveal_desc_label.add_theme_color_override("font_color", Color(1, 1, 1))
	reveal_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	reveal_desc_label.custom_minimum_size = Vector2(280, 0)
	box.add_child(reveal_desc_label)

	done_btn = Button.new()
	done_btn.text = "✓ Done"
	done_btn.custom_minimum_size = Vector2(200, 56)
	done_btn.add_theme_font_size_override("font_size", 20)
	done_btn.pressed.connect(_on_done_pressed)
	box.add_child(done_btn)

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
	big.text = "🍺 DRINK\nTHE CUP! 🍺"
	big.add_theme_font_size_override("font_size", 36)
	big.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
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
	reveal_active = false
	setup_box.visible = false
	end_box.visible = false
	play_box.visible = true
	reveal_panel.visible = false
	hint_label.visible = true
	_update_turn_display()
	_render_circle()

func _update_turn_display() -> void:
	turn_label.text = "Player %d's turn" % (engine.current_player + 1)
	crown_label.text = "👑 " + "♔".repeat(engine.king_count) + "▫".repeat(4 - engine.king_count) + "  (%d/4)" % engine.king_count

## Rebuilds every card-back button around a ring; the ring's radius shrinks as the
## circle empties, and each button carries the card's stable id so taps stay correct
## even though positions get reassigned on every render.
func _render_circle() -> void:
	for child in circle_area.get_children():
		circle_area.remove_child(child)
		child.free()

	var count: int = engine.deck.size()
	if count == 0:
		return
	var radius: float = lerp(MIN_RADIUS, MAX_RADIUS, float(count) / 52.0)
	var center := Vector2(CIRCLE_SIZE, CIRCLE_SIZE) / 2.0

	for i in range(count):
		var card: Dictionary = engine.deck[i]
		var angle: float = (float(i) / count) * TAU - PI / 2.0
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		var btn := _make_card_back_button(card.id)
		btn.position = pos - CARD_SIZE / 2.0
		circle_area.add_child(btn)

func _make_card_back_button(card_id: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.size = CARD_SIZE
	btn.focus_mode = Control.FOCUS_NONE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 0.08, 0.12)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.85, 0.65, 0.2)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)

	btn.pressed.connect(_on_card_picked.bind(card_id))
	return btn

func _on_card_picked(card_id: int) -> void:
	if reveal_active:
		return
	var result: Dictionary = engine.pick_by_id(card_id)
	reveal_active = true
	hint_label.visible = false

	var color := Color(1, 0.4, 0.4) if RED_SUITS.has(result.suit) else Color(1, 1, 1)
	reveal_card_label.text = "%s%s" % [result.rank, result.suit]
	reveal_card_label.add_theme_color_override("font_color", color)
	reveal_title_label.text = result.title
	reveal_desc_label.text = result.desc
	reveal_panel.visible = true

	crown_label.text = "👑 " + "♔".repeat(engine.king_count) + "▫".repeat(4 - engine.king_count) + "  (%d/4)" % engine.king_count
	_render_circle()

func _on_done_pressed() -> void:
	reveal_active = false
	reveal_panel.visible = false
	if engine.game_over:
		end_box.visible = true
		play_box.visible = false
		return
	hint_label.visible = true
	engine.advance_player()
	_update_turn_display()
