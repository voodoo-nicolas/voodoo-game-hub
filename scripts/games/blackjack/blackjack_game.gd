extends Control

## Blackjack table: build a bet from chip buttons, then Hit / Stand / Double.
## The chip stack persists between visits; leaving mid-hand refunds the bet.

const BlackjackEngine = preload("res://scripts/games/blackjack/blackjack_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")

const CHIPS_PATH := "user://blackjack_chips.json"
const CHIP_VALUES := [10, 25, 50, 100]
const COLOR_FELT := Color(0.05, 0.3, 0.17)
const COLOR_CARD := Color(0.97, 0.97, 0.95)
const COLOR_CARD_BACK := Color(0.55, 0.12, 0.15)
const OUTCOME_TEXT := {
	"blackjack": "Blackjack! You win %d",
	"win": "You win %d!",
	"dealer_bust": "Dealer busts — you win %d!",
	"push": "Push — bet returned",
	"lose": "Dealer wins",
	"bust": "Bust!",
}

var engine
var pending_bet: int = 0
var last_bet: int = 0

var chips_label: Label
var dealer_cards: HBoxContainer
var dealer_value: Label
var player_cards: HBoxContainer
var player_value: Label
var message_label: Label
var bet_row: Control
var bet_label: Label
var action_row: Control
var double_btn: Button
var next_row: Control

func _ready() -> void:
	preload("res://scripts/games/blackjack/blackjack_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BlackjackEngine.new()
	var data = SaveUtil.read(CHIPS_PATH)
	if data != null:
		engine.chips = int(data.get("chips", BlackjackEngine.STARTING_CHIPS))
		last_bet = int(data.get("last_bet", 0))
	_build_ui()
	_to_betting()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _exit_tree() -> void:
	_save_game()

## Called by the settings drawer / hub exit too. A hand in progress is
## abandoned, so its bet goes back on the stack rather than vanishing.
func _save_game() -> void:
	var chips: int = engine.chips
	if engine.phase == BlackjackEngine.Phase.PLAYER_TURN:
		chips += engine.bet
	SaveUtil.write(CHIPS_PATH, {"chips": chips, "last_bet": last_bet})

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COLOR_FELT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)
	var bar := HBoxContainer.new()
	top_margin.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🂱 Blackjack")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	chips_label = Label.new()
	chips_label.add_theme_font_size_override("font_size", 28)
	chips_label.add_theme_color_override("font_color", Color(1, 0.84, 0.3))
	bar.add_child(chips_label)

	root.add_child(_section_label(tr("Dealer")))
	dealer_value = _value_label()
	root.add_child(dealer_value)
	dealer_cards = _card_row()
	root.add_child(dealer_cards)

	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 36)
	message_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(message_label)

	player_cards = _card_row()
	root.add_child(player_cards)
	player_value = _value_label()
	root.add_child(player_value)
	root.add_child(_section_label(tr("You")))

	var controls := MarginContainer.new()
	controls.add_theme_constant_override("margin_bottom", 40)
	controls.add_theme_constant_override("margin_left", 16)
	controls.add_theme_constant_override("margin_right", 16)
	controls.custom_minimum_size = Vector2(0, 250)
	root.add_child(controls)

	# Betting controls
	var bet_box := VBoxContainer.new()
	bet_box.add_theme_constant_override("separation", 14)
	bet_row = bet_box
	controls.add_child(bet_box)
	bet_label = Label.new()
	bet_label.add_theme_font_size_override("font_size", 30)
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet_box.add_child(bet_label)
	var chip_row := HBoxContainer.new()
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_row.add_theme_constant_override("separation", 12)
	bet_box.add_child(chip_row)
	for v in CHIP_VALUES:
		chip_row.add_child(_button("+%d" % v, 140, _add_to_bet.bind(v)))
	var deal_row := HBoxContainer.new()
	deal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	deal_row.add_theme_constant_override("separation", 12)
	bet_box.add_child(deal_row)
	deal_row.add_child(_button(tr("Clear"), 200, _clear_bet))
	deal_row.add_child(_button(tr("Deal"), 300, _deal))

	# Playing controls
	var act := HBoxContainer.new()
	act.alignment = BoxContainer.ALIGNMENT_CENTER
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # else the buttons stretch to the full control area
	act.add_theme_constant_override("separation", 12)
	action_row = act
	controls.add_child(act)
	act.add_child(_button(tr("Hit"), 200, _hit))
	act.add_child(_button(tr("Stand"), 200, _stand))
	double_btn = _button(tr("Double"), 200, _double)
	act.add_child(double_btn)

	# After the hand
	var nxt := CenterContainer.new()
	next_row = nxt
	controls.add_child(nxt)
	nxt.add_child(_button(tr("Next Hand"), 360, _to_betting))

	add_child(SettingsDrawer.new())

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _value_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _card_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", -30)  # cards overlap like a fanned hand
	row.custom_minimum_size = Vector2(0, 180)
	return row

func _button(text: String, width: int, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 84)
	b.add_theme_font_size_override("font_size", 30)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b

func _make_card(card: Dictionary, face_up: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 172)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD if face_up else COLOR_CARD_BACK
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.2, 0.2, 0.2)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 44)
	if face_up:
		l.text = BlackjackEngine.card_text(card)
		l.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1) if BlackjackEngine.is_red(card) else Color(0.1, 0.1, 0.1))
	else:
		l.text = "✦"
		l.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	panel.add_child(l)
	return panel

# ---------- flow ----------

func _to_betting() -> void:
	if engine.is_broke():
		engine.rebuy()
		message_label.text = tr("Out of chips — here's a fresh %d.") % BlackjackEngine.STARTING_CHIPS
	else:
		message_label.text = tr("Place your bet")
	engine.phase = BlackjackEngine.Phase.BETTING
	pending_bet = min(last_bet, engine.chips) if last_bet >= BlackjackEngine.MIN_BET else 0
	_render()

func _add_to_bet(v: int) -> void:
	pending_bet = min(pending_bet + v, engine.chips)
	_render()

func _clear_bet() -> void:
	pending_bet = 0
	_render()

func _deal() -> void:
	if pending_bet < BlackjackEngine.MIN_BET:
		message_label.text = tr("Minimum bet is %d") % BlackjackEngine.MIN_BET
		return
	last_bet = pending_bet
	if engine.deal(pending_bet):
		message_label.text = ""
		_after_action()

func _hit() -> void:
	engine.hit()
	_after_action()

func _stand() -> void:
	engine.stand()
	_after_action()

func _double() -> void:
	engine.double_down()
	_after_action()

func _after_action() -> void:
	if engine.phase == BlackjackEngine.Phase.ROUND_OVER:
		var text: String = tr(OUTCOME_TEXT.get(engine.outcome, ""))
		message_label.text = text % engine.payout if text.contains("%d") else text
		_save_game()
	_render()

# ---------- rendering ----------

func _render() -> void:
	chips_label.text = "🪙 %d" % engine.chips
	var phase: int = engine.phase
	bet_row.visible = phase == BlackjackEngine.Phase.BETTING
	action_row.visible = phase == BlackjackEngine.Phase.PLAYER_TURN
	next_row.visible = phase == BlackjackEngine.Phase.ROUND_OVER
	double_btn.disabled = not engine.can_double()
	bet_label.text = tr("Bet: %d") % pending_bet

	for row in [dealer_cards, player_cards]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	if phase == BlackjackEngine.Phase.BETTING:
		dealer_value.text = ""
		player_value.text = ""
		return
	var hide_hole: bool = phase == BlackjackEngine.Phase.PLAYER_TURN
	for i in range(engine.dealer.size()):
		dealer_cards.add_child(_make_card(engine.dealer[i], not (hide_hole and i == 1)))
	for card in engine.player:
		player_cards.add_child(_make_card(card, true))
	dealer_value.text = "?" if hide_hole else _value_text(engine.dealer)
	player_value.text = tr("%s   (bet %d)") % [_value_text(engine.player), engine.bet]

func _value_text(hand: Array) -> String:
	var v: Dictionary = BlackjackEngine.hand_value(hand)
	if v.soft and v.total < 21:
		return "%d / %d" % [v.total - 10, v.total]
	return str(v.total)
