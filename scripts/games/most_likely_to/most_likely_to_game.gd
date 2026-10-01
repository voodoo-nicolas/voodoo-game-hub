extends Control

## Most Likely To -- a pass-the-phone prompt deck. Read the card, count to
## three, everyone points; whoever gets the most fingers drinks.

const MLEngine = preload("res://scripts/games/most_likely_to/most_likely_to_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const DECKS := ["mild", "spicy", "mixed"]
const CARD_COLORS := {"mild": Color(0.2, 0.45, 0.75), "spicy": Color(0.75, 0.18, 0.3), "mixed": Color(0.5, 0.25, 0.7)}

var info = null  # GameInfo; null on apps without it, so guard every use
var engine: MLEngine
var deck_index := 0

var deck_btn: Button
var card_panel: PanelContainer
var card_label: Label
var count_label: Label

func _ready() -> void:
	preload("res://scripts/games/most_likely_to/most_likely_to_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MLEngine.new()
	_build_ui()
	_start_deck()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("👉 Most Likely To")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	bar.add_child(spacer)

	var hint := Label.new()
	hint.text = tr("Read it out loud, count to 3 and point! Most fingers drinks.")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(hint)

	var cm := MarginContainer.new()
	cm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		cm.add_theme_constant_override("margin_" + side, 36)
	root.add_child(cm)
	card_panel = PanelContainer.new()
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.gui_input.connect(_on_card_input)
	cm.add_child(card_panel)
	card_label = Label.new()
	card_label.add_theme_font_size_override("font_size", 44)
	card_label.add_theme_color_override("font_color", Color(1, 1, 1))
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # content, not UI
	card_panel.add_child(card_label)

	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 22)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.75))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(count_label)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_bottom", 36)
	rm.add_theme_constant_override("margin_left", 36)
	rm.add_theme_constant_override("margin_right", 36)
	rm.add_child(rows)
	root.add_child(rm)
	var next_btn := Button.new()
	next_btn.text = tr("Next card ➜")
	next_btn.custom_minimum_size = Vector2(0, 90)
	next_btn.add_theme_font_size_override("font_size", 32)
	next_btn.pressed.connect(_next)
	rows.add_child(next_btn)
	deck_btn = Button.new()
	deck_btn.custom_minimum_size = Vector2(0, 70)
	deck_btn.add_theme_font_size_override("font_size", 26)
	deck_btn.pressed.connect(_cycle_deck)
	rows.add_child(deck_btn)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/most_likely_to/most_likely_to_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_deck() -> void:
	var deck: String = DECKS[deck_index]
	engine.reset(deck, TranslationServer.get_locale().begins_with("es"))
	deck_btn.text = {"mild": tr("Deck: 😇 Mild"), "spicy": tr("Deck: 🌶️ Spicy"), "mixed": tr("Deck: 🎲 Mixed")}[deck]
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_COLORS[deck]
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(6)
	sb.border_color = Color(1, 1, 1, 0.85)
	sb.set_content_margin_all(36)
	sb.shadow_size = 18
	sb.shadow_color = Color(0, 0, 0, 0.5)
	card_panel.add_theme_stylebox_override("panel", sb)
	_next()

func _cycle_deck() -> void:
	deck_index = (deck_index + 1) % DECKS.size()
	_start_deck()

func _on_card_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		_next()

func _next() -> void:
	card_label.text = engine.next_card()
	count_label.text = tr("Card %d") % engine.dealt
	if info:
		info.add("Cards played")
	# a little flip: squash and spring back
	card_panel.pivot_offset = card_panel.size / 2.0
	card_panel.scale = Vector2(0.85, 0.85)
	card_panel.create_tween().tween_property(card_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
