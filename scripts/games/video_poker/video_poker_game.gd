extends Control

## Video Poker (Jacks or Better): bet, deal, tap cards to hold, draw.

const VpEngine = preload("res://scripts/games/video_poker/video_poker_engine.gd")
const Cards = preload("res://scripts/games/video_poker/video_poker_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/video_poker/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/video_poker/video_poker_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://video_poker_save.json"
const CARD_ASPECT := 1.42

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var started := false

var credits_label: Label
var pay_box: GridContainer
var pay_labels: Array = []
var table: Control
var result_label: Label
var bet_label: Label
var deal_btn: Button
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/video_poker/video_poker_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = VpEngine.new()
	_build_ui()
	engine.new_session()
	started = false
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

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
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	credits_label = Label.new()
	credits_label.add_theme_font_size_override("font_size", 36)
	credits_label.add_theme_color_override("font_color", HomeKit.GOLD.lerp(Color.WHITE, 0.5))
	credits_label.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.5))
	credits_label.add_theme_constant_override("outline_size", 8)
	credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(credits_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	bar.add_child(spacer)

	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 30)
	pm.add_theme_constant_override("margin_right", 30)
	root.add_child(pm)
	pay_box = GridContainer.new()
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
	result_label.add_theme_font_size_override("font_size", 32)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(result_label)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 34)
	root.add_child(bm)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 12)
	bm.add_child(row2)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(70, 76)
	minus.pressed.connect(_change_bet.bind(-1))
	row2.add_child(minus)
	bet_label = Label.new()
	bet_label.custom_minimum_size = Vector2(120, 0)
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet_label.add_theme_font_size_override("font_size", 26)
	row2.add_child(bet_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(70, 76)
	plus.pressed.connect(_change_bet.bind(1))
	row2.add_child(plus)
	deal_btn = Button.new()
	deal_btn.custom_minimum_size = Vector2(230, 76)
	deal_btn.add_theme_font_size_override("font_size", 30)
	deal_btn.set_meta("sfx", "")
	deal_btn.pressed.connect(_on_deal)
	row2.add_child(deal_btn)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Start over"), "action": _new_session},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Jacks or Better. Hold the keepers, draw the rest.",
		"logo": _draw_home_logo,
		"modes": [{"text": "🃏 " + tr("New session"), "sub": "100 credits, just for fun", "action": _new_session}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _new_session,
		"board": "Most credits",
		"board_note": "The most credits you've ever held. Play money only.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.05)  # right of the credits
	add_child(drawer)

# ---------- flow ----------

func _new_session() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_session()
	started = true
	end_dialog.visible = false
	result_label.text = tr("Pick your bet and deal.")
	_render()

func _change_bet(d: int) -> void:
	if engine.phase != "bet":
		return
	engine.bet = clampi(engine.bet + d, 1, 5)
	_render()

func _on_deal() -> void:
	if engine.phase == "bet":
		if engine.credits < engine.bet:
			engine.bet = maxi(1, engine.credits)
		if engine.deal(rng):
			_sfx("card_deal")
			result_label.text = tr("Tap the cards to hold, then draw.")
			var k := VpEngine.evaluate(engine.hand)
			if k >= 0:
				result_label.text = tr("You have: %s") % tr(VpEngine.PAYS[k][0])
	else:
		var win: int = engine.draw()
		if info:
			info.add("Hands played")
			info.high("Most credits", engine.credits)
			if win > 0:
				info.high("Biggest win", win)
			if engine.last_hand == "Royal Flush":
				info.add("Royal flushes")
		if win > 0:
			_sfx("win" if win >= engine.bet * 9 else "pickup")
			result_label.text = tr("%s! +%d") % [tr(engine.last_hand), win]
		else:
			_sfx("card_place")
			result_label.text = tr("No win this time.")
		if engine.broke():
			_out_of_credits()
	_render()

func _out_of_credits() -> void:
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("Out of credits!")
	if info:
		info.add("Sessions played")
		msg += "\n" + info.summary(["Most credits", "Biggest win", "Hands played"])
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

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
	credits_label.text = tr("Credits: %d") % engine.credits
	bet_label.text = tr("Bet %d") % engine.bet
	deal_btn.text = tr("Deal") if engine.phase == "bet" else tr("Draw")
	var win_row := VpEngine.evaluate(engine.hand) if engine.hand.size() == 5 else -1
	for k in pay_labels.size():
		var pays: int = VpEngine.PAYS[k][1] * engine.bet
		if k == 0 and engine.bet == 5:
			pays = 4000
		pay_labels[k][1].text = str(pays)
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

func _draw_home_logo(c: Control) -> void:
	var w := minf(c.size.y * 0.38, 54.0)
	var h := w * CARD_ASPECT
	var o := c.size / 2.0
	var hand := [0, 12, 11, 10, 9]
	for k in 5:
		var r := Rect2(o + Vector2((k - 2.5) * w * 0.82, -h / 2.0 + absf(k - 2) * 5.0), Vector2(w, h))
		Cards.draw_card(c, r, hand[k], true, k == 0)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.broke():
		return
	SaveUtil.write(SAVE_PATH, {"credits": engine.credits, "bet": engine.bet, "phase": engine.phase,
		"hand": engine.hand, "held": engine.held, "deck": engine.deck})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Credits: %d") % int(d.get("credits", 0))

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	_new_session()
	if d == null:
		return
	engine.credits = int(d.get("credits", VpEngine.START_CREDITS))
	engine.bet = clampi(int(d.get("bet", 1)), 1, 5)
	var hand := _ints(d.get("hand", []))
	if str(d.get("phase", "bet")) == "hold" and hand.size() == 5:
		engine.hand = hand
		engine.deck = _ints(d.get("deck", []))
		engine.held = []
		for v in d.get("held", []):
			engine.held.append(bool(v))
		engine.phase = "hold"
		result_label.text = tr("Tap the cards to hold, then draw.")
	_render()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
