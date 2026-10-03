extends Control

const KingsCupEngine = preload("res://scripts/games/kings_cup/kings_cup_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const RED_SUITS := ["♥", "♦"]
const GOLD := Color(0.85, 0.65, 0.2)
## Ring geometry as fractions of the circle area's side. A full deck is a
## wide ring of small cards; as cards are drawn the ring tightens and the
## remaining cards grow, so the last few are big and easy to tap.
const RING_FULL := 0.4
const RING_EMPTY := 0.22
const CARD_W_FULL := 0.085
const CARD_W_EMPTY := 0.2
const CARD_ASPECT := 1.4

var info = null  # GameInfo; null on apps without it, so guard every use
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
var reveal_overlay: Control
var reveal_card_label: Label
var reveal_title_label: Label
var reveal_desc_label: Label
var done_btn: Button
var hint_label: Label
var end_label: Label

func _ready() -> void:
	preload("res://scripts/games/kings_cup/kings_cup_i18n.gd").install(self)
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
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 24)
	hub_btn.pressed.connect(_go_hub)
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("👑 Kings Cup")
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
	_build_reveal()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/kings_cup/kings_cup_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _go_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

## A big, gold-rimmed square button, so −/+ read as buttons at a glance.
static func _counter_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(96, 96)
	btn.add_theme_font_size_override("font_size", 52)
	btn.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.4, 0.08, 0.12) if state != "pressed" else Color(0.6, 0.15, 0.18)
		sb.set_border_width_all(3)
		sb.border_color = GOLD
		sb.set_corner_radius_all(18)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.6))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.3))
	return btn

func _big_button(text: String, height: float, font_px: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, height)
	btn.add_theme_font_size_override("font_size", font_px)
	return btn

func _build_setup(root: VBoxContainer) -> void:
	setup_box = CenterContainer.new()
	setup_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(setup_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	setup_box.add_child(box)

	var label := Label.new()
	label.text = tr("How many players?")
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var counter_row := HBoxContainer.new()
	counter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_row.add_theme_constant_override("separation", 28)
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

	var start_btn := _big_button(tr("Start Game"), 72, 32)
	start_btn.pressed.connect(_on_start_pressed)
	box.add_child(start_btn)

	var rules_label := Label.new()
	rules_label.text = tr("Pass the phone around. Pick a card from the circle,\nfollow the rule, tap Done. The 4th King drinks the cup!")
	rules_label.add_theme_font_size_override("font_size", 20)
	rules_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rules_label)

func _change_players(delta: int) -> void:
	num_players = clampi(num_players + delta, 2, 20)
	players_label.text = str(num_players)

func _build_play(root: VBoxContainer) -> void:
	play_box = VBoxContainer.new()
	play_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.add_theme_constant_override("separation", 10)
	play_box.visible = false
	root.add_child(play_box)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 36)
	turn_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_box.add_child(turn_label)

	crown_label = Label.new()
	crown_label.add_theme_font_size_override("font_size", 26)
	crown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_box.add_child(crown_label)

	# Square, as wide as the screen allows; the ring is laid out from its size.
	circle_area = Control.new()
	circle_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	circle_area.resized.connect(_render_circle)
	play_box.add_child(circle_area)

	hint_label = Label.new()
	hint_label.text = tr("Tap a card to draw it")
	hint_label.add_theme_font_size_override("font_size", 24)
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_box.add_child(hint_label)

	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, 24)
	play_box.add_child(bottom)

## The drawn card fills the screen: big card, big rule, big Done button.
func _build_reveal() -> void:
	reveal_overlay = ColorRect.new()
	reveal_overlay.color = Color(0, 0, 0, 0.7)
	reveal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	reveal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reveal_overlay.visible = false
	add_child(reveal_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 40)
	reveal_overlay.add_child(margin)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.1, 0.09, 0.98)
	sb.set_border_width_all(3)
	sb.border_color = GOLD
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	reveal_card_label = Label.new()
	reveal_card_label.add_theme_font_size_override("font_size", 120)
	reveal_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reveal_card_label)

	reveal_title_label = Label.new()
	reveal_title_label.add_theme_font_size_override("font_size", 48)
	reveal_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	reveal_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(reveal_title_label)

	reveal_desc_label = Label.new()
	reveal_desc_label.add_theme_font_size_override("font_size", 32)
	reveal_desc_label.add_theme_color_override("font_color", Color(1, 1, 1))
	reveal_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	reveal_desc_label.custom_minimum_size = Vector2(280, 0)
	box.add_child(reveal_desc_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	box.add_child(gap)

	done_btn = _big_button(tr("✓ Done"), 96, 40)
	for state in ["normal", "hover", "pressed", "focus"]:
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = GOLD if state != "pressed" else GOLD.lightened(0.2)
		dsb.set_corner_radius_all(18)
		done_btn.add_theme_stylebox_override(state, dsb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		done_btn.add_theme_color_override(c, Color(0.15, 0.06, 0.04))
	done_btn.pressed.connect(_on_done_pressed)
	box.add_child(done_btn)

func _build_end(root: VBoxContainer) -> void:
	end_box = CenterContainer.new()
	end_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	end_box.visible = false
	root.add_child(end_box)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	end_box.add_child(box)

	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 43)
	end_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_label)

	var again_btn := _big_button(tr("New Game"), 72, 30)
	again_btn.pressed.connect(_show_setup)
	box.add_child(again_btn)

	var hub_btn := _big_button(tr("Back to Hub"), 60, 26)
	hub_btn.pressed.connect(_go_hub)
	box.add_child(hub_btn)

# ---------- flow ----------

func _show_setup() -> void:
	setup_box.visible = true
	play_box.visible = false
	end_box.visible = false
	reveal_overlay.visible = false

func _on_start_pressed() -> void:
	if info:
		info.add("Games played")
		info.high("Most players", num_players)
	engine.reset(num_players)
	reveal_active = false
	setup_box.visible = false
	end_box.visible = false
	play_box.visible = true
	reveal_overlay.visible = false
	hint_label.visible = true
	_update_turn_display()
	_render_circle()

func _update_turn_display() -> void:
	turn_label.text = tr("Player %d's turn") % (engine.current_player + 1)
	crown_label.text = tr("👑 Kings: %d/4") % engine.king_count + "   " + tr("Cards left: %d") % engine.deck.size()

## Rebuilds every card-back button around a ring; each button carries the
## card's stable id so taps stay correct even though positions get
## reassigned on every render.
func _render_circle() -> void:
	if circle_area == null or engine == null:
		return
	for child in circle_area.get_children():
		circle_area.remove_child(child)
		child.queue_free()

	var count: int = engine.deck.size()
	if count == 0:
		return
	var side: float = minf(circle_area.size.x, circle_area.size.y)
	if side <= 0.0:
		return
	var full: float = float(count) / 52.0
	var radius: float = side * lerpf(RING_EMPTY, RING_FULL, full)
	var card_w: float = side * lerpf(CARD_W_EMPTY, CARD_W_FULL, full)
	var card_size := Vector2(card_w, card_w * CARD_ASPECT)
	var center := circle_area.size / 2.0

	for i in range(count):
		var card: Dictionary = engine.deck[i]
		var angle: float = (float(i) / count) * TAU - PI / 2.0
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		var btn := _make_card_back_button(card.id, card_size)
		btn.position = pos - card_size / 2.0
		btn.pivot_offset = card_size / 2.0
		btn.rotation = angle + PI / 2.0
		circle_area.add_child(btn)

func _make_card_back_button(card_id: int, card_size: Vector2) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = card_size
	btn.size = card_size
	btn.focus_mode = Control.FOCUS_NONE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 0.08, 0.12)
	sb.set_border_width_all(maxi(1, int(card_size.x / 22.0)))
	sb.border_color = GOLD
	sb.set_corner_radius_all(maxi(3, int(card_size.x / 8.0)))
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
	reveal_title_label.text = tr(result.title)
	reveal_desc_label.text = tr(result.desc)
	reveal_overlay.visible = true

	_update_turn_display()
	_render_circle()

func _on_done_pressed() -> void:
	reveal_active = false
	reveal_overlay.visible = false
	if engine.game_over:
		end_label.text = tr("🍺 That's the\nwhole deck! 🍺")
		end_box.visible = true
		play_box.visible = false
		return
	hint_label.visible = true
	engine.advance_player()
	_update_turn_display()
