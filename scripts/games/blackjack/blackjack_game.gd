extends Control

## Blackjack table: build a bet from chip buttons, then Hit / Stand / Double.
## The chip stack persists between visits; leaving mid-hand refunds the bet.

const BlackjackEngine = preload("res://scripts/games/blackjack/blackjack_engine.gd")
const HomeKit = preload("res://scripts/games/blackjack/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const CHIPS_PATH := "user://blackjack_chips.json"
const CHIP_VALUES := [10, 25, 50, 100]
const COLOR_FELT := Color(0.03, 0.05, 0.1)
const COLOR_CARD := Color(0.05, 0.07, 0.15)
const COLOR_CARD_BACK := Color(0.2, 0.06, 0.32)
const OUTCOME_TEXT := {
	"blackjack": "Blackjack! You win %d",
	"win": "You win %d!",
	"dealer_bust": "Dealer busts — you win %d!",
	"push": "Push — bet returned",
	"lose": "Dealer wins",
	"bust": "Bust!",
	"split": "Split hands: net %+d",
}

var hand_recorded := false  # this hand's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
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
var split_btn: Button
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
	_to_betting()  # behind the Home screen until Play
	_chill_music()

## Chill background music from the hub's Music library (apps before v0.33 play none).
func _chill_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 1, 2.0)

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
		chips += engine.total_bet()
	SaveUtil.write(CHIPS_PATH, {"chips": chips, "last_bet": last_bet})

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
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
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = "♠ " + tr("Blackjack")
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
		var chip := _button("+%d" % v, 140, _add_to_bet.bind(v))
		chip.set_meta("sfx", "chip")
		chip_row.add_child(chip)
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
	act.add_child(_button(tr("Hit"), 160, _hit))
	act.add_child(_button(tr("Stand"), 160, _stand))
	double_btn = _button(tr("Double"), 160, _double)
	act.add_child(double_btn)
	split_btn = _button(tr("Split"), 160, _split)
	act.add_child(split_btn)

	# After the hand
	var nxt := CenterContainer.new()
	next_row = nxt
	controls.add_child(nxt)
	nxt.add_child(_button(tr("Next Hand"), 360, _to_betting))

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/blackjack/blackjack_help.gd"))
		info.stats["_seen"] = 1  # How to Play is on the Landing; no card before it (owner 2026-10-07)
	_build_home()
	if info:
		add_child(info)
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

func _make_card(card: Dictionary, face_up: bool, small: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(84, 120) if small else Vector2(120, 172)
	var sb := StyleBoxFlat.new()
	var rim: Color = (HomeKit.PINK if BlackjackEngine.is_red(card) else HomeKit.CYAN) if face_up else HomeKit.PURPLE
	sb.bg_color = COLOR_CARD if face_up else COLOR_CARD_BACK
	var cl := _is_classic()
	if cl:
		sb.bg_color = Color(0.98, 0.97, 0.93) if face_up else Color(0.1, 0.24, 0.62)
		rim = Color(0.45, 0.45, 0.5) if face_up else Color.WHITE
	sb.set_corner_radius_all(12)
	sb.border_color = rim
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.3) if cl else Color(rim, 0.35)
	sb.shadow_size = 3 if cl else 8
	if cl:
		sb.shadow_offset = Vector2(1, 2)
	panel.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30 if small else 44)
	if face_up:
		l.text = BlackjackEngine.card_text(card)
		l.add_theme_color_override("font_color", HomeKit.PINK.lerp(Color.WHITE, 0.2) if BlackjackEngine.is_red(card) else Color(0.9, 0.98, 1.0))
		if cl:
			l.add_theme_color_override("font_color", Color(0.78, 0.1, 0.14) if BlackjackEngine.is_red(card) else Color(0.07, 0.07, 0.1))
	else:
		l.text = "✦"
		l.add_theme_color_override("font_color", Color(0.55, 0.7, 1.0) if cl else HomeKit.PURPLE.lerp(Color.WHITE, 0.4))
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
	# First hand: the minimum is already on the table, so Deal is one tap.
	pending_bet = min(last_bet if last_bet >= BlackjackEngine.MIN_BET else BlackjackEngine.MIN_BET, engine.chips)
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
		hand_recorded = false
		_sfx("card_shuffle")
		_after_action()

func _hit() -> void:
	engine.hit()
	_sfx("card_deal")
	_after_action()

func _stand() -> void:
	engine.stand()
	_sfx("card_flip")  # the dealer turns over the hole card
	_after_action()

func _double() -> void:
	engine.double_down()
	_sfx("chip")
	_sfx("card_deal")
	_after_action()

func _split() -> void:
	engine.split()
	_sfx("chip")
	_sfx("card_deal")
	_after_action()

## Plays a sound from the app's library (silent on apps from before v0.23).
func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _after_action() -> void:
	if engine.phase == BlackjackEngine.Phase.ROUND_OVER:
		var text: String = tr(OUTCOME_TEXT.get(engine.outcome, ""))
		message_label.text = text % engine.payout if (text.contains("%d") or text.contains("%+d")) else text
		if info and not hand_recorded:
			hand_recorded = true
			var won_any := false
			for h in engine.hands:
				match h.outcome:
					"blackjack", "win", "dealer_bust":
						info.add("Hands won")
						won_any = true
						if h.outcome == "blackjack":
							info.add("Blackjacks")
							info.celebrate(tr("Blackjack!"))
					"push":
						info.add("Pushes")
					_:
						info.add("Hands lost")
			if won_any and engine.outcome != "blackjack":
				_sfx("chip")  # chips coming in; a blackjack celebrates
			elif not won_any and engine.payout < 0:
				_sfx("letter_wrong")
			info.high("Most chips", engine.chips)
		_save_game()
	_render()

# ---------- rendering ----------

## Look (STANDARDS §9): "classic" = ivory cards on green felt (default); "voodoo" = the neon
## board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: ColorRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.felt_dark if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if dealer_cards and engine:
		_render()

func _is_classic() -> bool:
	return skin == "classic"

func _render() -> void:
	chips_label.text = "🪙 %d" % engine.chips
	var phase: int = engine.phase
	bet_row.visible = phase == BlackjackEngine.Phase.BETTING
	action_row.visible = phase == BlackjackEngine.Phase.PLAYER_TURN
	next_row.visible = phase == BlackjackEngine.Phase.ROUND_OVER
	double_btn.disabled = not engine.can_double()
	split_btn.disabled = not engine.can_split()
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
	if engine.hands.size() > 1:
		# Split: each hand in its own column, the one being played marked.
		for i in engine.hands.size():
			var h: Dictionary = engine.hands[i]
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 6)
			var cards := HBoxContainer.new()
			cards.alignment = BoxContainer.ALIGNMENT_CENTER
			cards.add_theme_constant_override("separation", -34)
			for card in h.cards:
				cards.add_child(_make_card(card, true, true))
			col.add_child(cards)
			var tag := _value_label()
			var playing: bool = phase == BlackjackEngine.Phase.PLAYER_TURN and i == engine.cur
			tag.text = ("▶ " if playing else "") + tr("%s   (bet %d)") % [_value_text(h.cards), h.bet]
			col.add_child(tag)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			player_cards.add_child(col)
		player_value.text = ""
	else:
		for card in engine.player:
			player_cards.add_child(_make_card(card, true))
		player_value.text = tr("%s   (bet %d)") % [_value_text(engine.player), engine.bet]
	dealer_value.text = "?" if hide_hole else _value_text(engine.dealer)

func _value_text(hand: Array) -> String:
	var v: Dictionary = BlackjackEngine.hand_value(hand)
	if v.soft and v.total < 21:
		return "%d / %d" % [v.total - 10, v.total]
	return str(v.total)

# ---------- Home screen (home_kit.gd) ----------

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/blackjack/blackjack_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Beat the dealer to 21. Your chips carry over between visits.",
		"logo": _draw_home_logo,
		"modes": [{"text": "♠  Play", "sub": "vs the dealer", "action": _to_betting}],
		"restart": _to_betting,
		"board": "Most chips",
		"board_note": "The most chips you have ever held.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y * 0.9, 170.0)
	var w := h * 0.7
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	for spec in [[-0.22, Vector2(-w * 0.32, 4), "A", HomeKit.CYAN], [0.18, Vector2(w * 0.32, 0), "K", HomeKit.PINK]]:
		c.draw_set_transform(ctr + spec[1], spec[0], Vector2.ONE)
		var r := Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h))
		c.draw_rect(r, Color(0.05, 0.07, 0.15))
		HomeKit.glow_rect(c, r, spec[3], 2.5)
		HomeKit.glow_text(c, Vector2(0, -h * 0.08), spec[2], int(h * 0.42), spec[3])
		HomeKit.glow_text(c, Vector2(0, h * 0.28), "♠" if spec[2] == "A" else "♥", int(h * 0.22), spec[3])
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
