extends Control

## The Video Poker machine (Jacks or Better) as one screen of Poker: bet
## 1-5 coins of 10 / 50 / 250 chips from the player's chips, tap cards to
## hold, draw. 💡 Hint shows the standard strategy's hold.

signal pause_pressed()
## The player's chips changed (a bet went in or a win came back).
signal chips_changed(chips: int)
## A hand was drawn: winnings in chips, the paying hand ("" for none).
signal hand_finished(win: int, hand_name: String)

const VpEngine = preload("res://scripts/games/video_poker/video_poker_engine.gd")
const Cards = preload("res://scripts/games/video_poker/video_poker_cards.gd")
const HomeKit = preload("res://scripts/games/video_poker/home_kit.gd")
const CARD_ASPECT := 1.42

var engine = VpEngine.new()
var rng := RandomNumberGenerator.new()
var credits_label: Label
var pay_labels: Array = []
var table: Control
var result_label: Label
var hint_label: Label
var bet_label: Label
var deal_btn: Button
var hint_btn: Button
var coin_row: HBoxContainer
var hint_held: Array = []

func _ready() -> void:
	rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(pause_pressed.emit)
	bar.add_child(pause_btn)
	credits_label = Label.new()
	credits_label.add_theme_font_size_override("font_size", 34)
	credits_label.add_theme_color_override("font_color", HomeKit.GOLD.lerp(Color.WHITE, 0.5))
	credits_label.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.5))
	credits_label.add_theme_constant_override("outline_size", 8)
	credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(credits_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	bar.add_child(spacer)

	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 30)
	cm.add_theme_constant_override("margin_right", 30)
	root.add_child(cm)
	coin_row = HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 10)
	cm.add_child(coin_row)
	var cl := Label.new()
	cl.text = tr("Coin")
	cl.add_theme_font_size_override("font_size", 24)
	cl.add_theme_color_override("font_color", HomeKit.DIM)
	coin_row.add_child(cl)
	var group := ButtonGroup.new()
	for i in VpEngine.COINS.size():
		var b := HomeKit.neon_button(str(VpEngine.COINS[i]), HomeKit.GOLD, 24, 56)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on := HomeKit.neon_box(HomeKit.GOLD, "pressed")
		on.bg_color = Color(HomeKit.GOLD, 0.45)
		b.add_theme_stylebox_override("pressed", on)
		b.pressed.connect(_set_coin.bind(VpEngine.COINS[i]))
		coin_row.add_child(b)

	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 30)
	pm.add_theme_constant_override("margin_right", 30)
	root.add_child(pm)
	var pay_box := GridContainer.new()
	pay_box.columns = 2
	pay_box.add_theme_constant_override("h_separation", 20)
	pay_box.add_theme_constant_override("v_separation", 2)
	pm.add_child(pay_box)
	for row in VpEngine.PAYS:
		var n := Label.new()
		n.text = tr(row[0])
		n.add_theme_font_size_override("font_size", 22)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pay_box.add_child(n)
		var v := Label.new()
		v.add_theme_font_size_override("font_size", 22)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pay_box.add_child(v)
		pay_labels.append([n, v])

	table = Control.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.mouse_filter = Control.MOUSE_FILTER_STOP
	table.draw.connect(_draw_table)
	table.gui_input.connect(_on_table_input)
	table.resized.connect(table.queue_redraw)
	root.add_child(table)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 30)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(result_label)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", HomeKit.LIME)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint_label)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 34)
	bm.add_theme_constant_override("margin_left", 12)
	bm.add_theme_constant_override("margin_right", 12)
	root.add_child(bm)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 10)
	bm.add_child(row2)
	hint_btn = Button.new()
	hint_btn.text = "💡"
	hint_btn.custom_minimum_size = Vector2(70, 76)
	hint_btn.pressed.connect(_on_hint)
	row2.add_child(hint_btn)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(66, 76)
	minus.pressed.connect(_change_bet.bind(-1))
	row2.add_child(minus)
	bet_label = Label.new()
	bet_label.custom_minimum_size = Vector2(110, 0)
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet_label.add_theme_font_size_override("font_size", 24)
	row2.add_child(bet_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(66, 76)
	plus.pressed.connect(_change_bet.bind(1))
	row2.add_child(plus)
	deal_btn = Button.new()
	deal_btn.custom_minimum_size = Vector2(200, 76)
	deal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deal_btn.add_theme_font_size_override("font_size", 30)
	deal_btn.set_meta("sfx", "")
	deal_btn.pressed.connect(_on_deal)
	row2.add_child(deal_btn)
	_render()

## Starts at the machine with `chips`; `saved` (from state()) restores a
## hand in progress.
func open(chips: int, saved: Dictionary = {}) -> void:
	engine.new_session(chips)
	engine.coin = int(saved.get("coin", engine.coin))
	if not VpEngine.COINS.has(engine.coin):
		engine.coin = VpEngine.COINS[0]
	engine.bet = clampi(int(saved.get("bet", engine.bet)), 1, 5)
	var hand := _ints(saved.get("hand", []))
	result_label.text = tr("Pick your bet and deal.")
	hint_label.text = ""
	hint_held = []
	if str(saved.get("phase", "bet")) == "hold" and hand.size() == 5:
		engine.hand = hand
		engine.deck = _ints(saved.get("deck", []))
		engine.held = []
		for v in saved.get("held", []):
			engine.held.append(bool(v))
		while engine.held.size() < 5:
			engine.held.append(false)
		engine.phase = "hold"
		result_label.text = tr("Tap the cards to hold, then draw.")
	for i in coin_row.get_child_count() - 1:
		(coin_row.get_child(i + 1) as Button).button_pressed = VpEngine.COINS[i] == engine.coin
	_render()

func state() -> Dictionary:
	return {"coin": engine.coin, "bet": engine.bet, "phase": engine.phase, "hand": engine.hand,
		"held": engine.held, "deck": engine.deck}

## The bet already on a hand being held (counted back if the hand is dropped).
func stake_in_play() -> int:
	return engine.stake() if engine.phase == "hold" else 0

func _set_coin(c: int) -> void:
	if engine.phase != "bet":
		for i in coin_row.get_child_count() - 1:
			(coin_row.get_child(i + 1) as Button).button_pressed = VpEngine.COINS[i] == engine.coin
		return
	engine.coin = c
	_render()

func _change_bet(d: int) -> void:
	if engine.phase != "bet":
		return
	engine.bet = clampi(engine.bet + d, 1, 5)
	_render()

func _on_deal() -> void:
	hint_label.text = ""
	hint_held = []
	if engine.phase == "bet":
		if engine.credits < engine.stake():
			engine.bet = maxi(1, engine.credits / engine.coin)
		if engine.deal(rng):
			_sfx("card_deal")
			chips_changed.emit(engine.credits)
			result_label.text = tr("Tap the cards to hold, then draw.")
			var k := VpEngine.evaluate(engine.hand)
			if k >= 0:
				result_label.text = tr("You have: %s") % tr(VpEngine.PAYS[k][0])
		else:
			_sfx("invalid")
			result_label.text = tr("Not enough chips for that bet.")
	else:
		var win: int = engine.draw()
		chips_changed.emit(engine.credits)
		hand_finished.emit(win, engine.last_hand)
		if win > 0:
			_sfx("win" if win >= engine.stake() * 9 else "pickup")
			result_label.text = tr("%s! +%d") % [tr(engine.last_hand), win]
		else:
			_sfx("card_place")
			result_label.text = tr("No win this time.")
	_render()

func _on_hint() -> void:
	if engine.phase != "hold":
		hint_label.text = tr("Deal first, then ask for a hint.")
		return
	var h: Array = VpEngine.hint(engine.hand)
	hint_held = h[0]
	hint_label.text = "💡 " + tr(h[1])
	table.queue_redraw()

func _on_table_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if engine.phase != "hold":
		return
	var rects := _card_rects()
	for i in rects.size():
		if rects[i].grow(6).has_point(event.position):
			engine.toggle(i)
			_sfx("toggle")
			table.queue_redraw()
			return

func _render() -> void:
	credits_label.text = "🪙 " + _chips(engine.credits)
	bet_label.text = tr("Bet %d") % engine.stake()
	deal_btn.text = tr("Deal") if engine.phase == "bet" else tr("Draw")
	var win_row := VpEngine.evaluate(engine.hand) if engine.hand.size() == 5 else -1
	for k in pay_labels.size():
		pay_labels[k][1].text = _chips(VpEngine.pays(k, engine.bet) * engine.coin)
		var hot: bool = k == win_row
		for l in pay_labels[k]:
			l.add_theme_color_override("font_color", HomeKit.GOLD if hot else HomeKit.DIM)
	table.queue_redraw()

func _card_rects() -> Array:
	var w: float = minf((table.size.x - 60.0) / 5.0, (table.size.y - 50.0) / CARD_ASPECT)
	var h := w * CARD_ASPECT
	var x0: float = (table.size.x - (w * 5 + 40.0)) / 2.0
	var y0: float = (table.size.y - h) / 2.0 - 10.0
	var out: Array = []
	for i in 5:
		out.append(Rect2(Vector2(x0 + i * (w + 10.0), y0), Vector2(w, h)))
	return out

func _draw_table() -> void:
	var rects := _card_rects()
	var font := ThemeDB.fallback_font
	for i in 5:
		var r: Rect2 = rects[i]
		if engine.hand.size() < 5:
			Cards.draw_card(table, r, 0, false)
			continue
		var held: bool = engine.held[i] and engine.phase == "hold"
		if held:
			r.position.y -= 12
		Cards.draw_card(table, r, engine.hand[i], true, held)
		if held:
			table.draw_string(font, Vector2(r.position.x - 20, r.end.y + 30), tr("Held").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 40, 20, Cards.COLOR_HILITE)
		if engine.phase == "hold" and hint_held.has(i):
			table.draw_string(font, Vector2(r.position.x - 20, r.position.y - 10), "💡", HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 40, 26, HomeKit.LIME)
			table.draw_rect(r.grow(5), Color(HomeKit.LIME, 0.8), false, 3.0)

static func _ints(a: Variant) -> Array:
	var out: Array = []
	if typeof(a) == TYPE_ARRAY:
		for v in a:
			out.append(int(v))
	return out

static func _chips(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
