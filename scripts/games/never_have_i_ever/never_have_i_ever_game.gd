extends Control

## Never Have I Ever -- a pass-the-phone prompt deck. Pick a deck, read the
## card out loud, everyone who has done it drinks, tap for the next card.

const NHEngine = preload("res://scripts/games/never_have_i_ever/never_have_i_ever_engine.gd")
const HomeKit = preload("res://scripts/games/never_have_i_ever/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const DECKS := ["mild", "spicy", "mixed"]
const CARD_COLORS := {"mild": Color(0.2, 0.45, 0.75), "spicy": Color(0.75, 0.18, 0.3), "mixed": Color(0.5, 0.25, 0.7)}

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: NHEngine
var deck_index := 0

var deck_btn: Button
var card_panel: PanelContainer
var card_label: Label
var count_label: Label

func _ready() -> void:
	preload("res://scripts/games/never_have_i_ever/never_have_i_ever_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = NHEngine.new()
	_build_ui()
	_start_deck()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
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
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🙊 Never Have I Ever")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	bar.add_child(spacer)

	var hint := Label.new()
	hint.text = tr("Read it out loud. Everyone who HAS done it drinks!")
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	var hint_m := MarginContainer.new()  # side room for the floating ⚙ tab
	hint_m.add_theme_constant_override("margin_left", 48)
	hint_m.add_theme_constant_override("margin_right", 48)
	hint_m.add_child(hint)
	root.add_child(hint_m)

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
	count_label.add_theme_font_size_override("font_size", 24)
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
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/never_have_i_ever/never_have_i_ever_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_deck() -> void:
	var deck: String = DECKS[deck_index]
	engine.reset(deck, TranslationServer.get_locale().begins_with("es"))
	deck_btn.text = {"mild": tr("Deck: 😇 Mild"), "spicy": tr("Deck: 🌶️ Spicy"), "mixed": tr("Deck: 🎲 Mixed")}[deck]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CARD_COLORS[deck], 0.18)
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(4)
	sb.border_color = CARD_COLORS[deck].lightened(0.35)
	sb.set_content_margin_all(36)
	sb.shadow_size = 20
	sb.shadow_color = Color(CARD_COLORS[deck].lightened(0.3), 0.4)
	card_panel.add_theme_stylebox_override("panel", sb)
	_next()

func _cycle_deck() -> void:
	deck_index = (deck_index + 1) % DECKS.size()
	_start_deck()

func _on_card_input(event: InputEvent) -> void:
	# Mouse only: a phone turns each tap into a ScreenTouch AND an emulated
	# mouse click, so handling both drew two cards per tap.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next()

func _next() -> void:
	card_label.text = engine.next_card()
	_sfx("card_flip")
	count_label.text = tr("Card %d") % engine.dealt
	if info:
		info.add("Cards played")
	# a little flip: squash and spring back
	card_panel.pivot_offset = card_panel.size / 2.0
	card_panel.scale = Vector2(0.85, 0.85)
	card_panel.create_tween().tween_property(card_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------- Home screen (home_kit.gd) ----------

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/never_have_i_ever/never_have_i_ever_help.gd"),
		"info": info,
		"accent": HomeKit.PURPLE,
		"subtitle": "Read it out loud. Everyone who HAS done it drinks!",
		"logo": _draw_home_logo,
		"multi_heading": "Party · one phone, pass it around",
		"modes": [
			{"text": "😇 Mild", "row": "deck", "multi": true, "color": HomeKit.CYAN, "action": _play_deck.bind(0)},
			{"text": "🌶️ Spicy", "row": "deck", "multi": true, "color": HomeKit.PINK, "action": _play_deck.bind(1)},
			{"text": "🎲 Mixed", "row": "deck", "multi": true, "color": HomeKit.PURPLE, "action": _play_deck.bind(2)},
		],
		"restart": _start_deck,
		"board": "Cards played",
		"board_note": "Cards played, all time.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y * 0.9, 160.0)
	var w := h * 0.72
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	for k in 3:
		var col: Color = [HomeKit.PURPLE, HomeKit.PINK, HomeKit.CYAN][k]
		c.draw_set_transform(ctr + Vector2((k - 1) * w * 0.35, 0), (k - 1) * 0.16, Vector2.ONE)
		var r := Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h))
		c.draw_rect(r, Color(0.04, 0.05, 0.11))
		HomeKit.glow_rect(c, r, col, 2.5, 0.1)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	HomeKit.glow_text(c, ctr, "🙊", int(h * 0.42), Color.WHITE)

func _play_deck(i: int) -> void:
	deck_index = i
	_start_deck()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
