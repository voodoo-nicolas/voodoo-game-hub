extends Control

## Ride the Bus -- pass the phone through the guessing rounds, flip the
## pyramid, then whoever holds the most cards rides the bus until they get
## all four guesses right in a row.

const RBEngine = preload("res://scripts/games/ride_the_bus/ride_the_bus_engine.gd")
const HomeKit = preload("res://scripts/games/ride_the_bus/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := {11: "J", 12: "Q", 13: "K", 14: "A"}
const COLOR_RED := Color("ff4f9a")
const COLOR_BLACK := Color("29e6ff")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: RBEngine
var num_players := 4
var waiting_next := false   # a result is showing; the Next button continues

var setup_box: Control
var players_label: Label
var play_box: Control
var turn_label: Label
var question_label: Label
var card_panel: PanelContainer
var card_label: Label
var result_label: Label
var hand_label: Label
var guess_row: HBoxContainer
var suit_row: HBoxContainer
var next_btn: Button
var pyramid_box: Control
var pyramid_rows: VBoxContainer
var pyramid_msg: Label
var counts_label: Label
var flip_btn: Button
var end_dialog: ColorRect

func _ready() -> void:
	preload("res://scripts/games/ride_the_bus/ride_the_bus_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = RBEngine.new()
	_build_ui()
	_show_setup()

static func card_text(c: Dictionary) -> String:
	return "%s%s" % [RANKS.get(c.rank, str(c.rank)), SUITS[c.suit]]

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	title.text = tr("🚌 Ride the Bus")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New Game")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_show_setup)
	bar.add_child(new_btn)

	_build_setup(root)
	_build_play(root)
	_build_pyramid(root)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _show_setup},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/ride_the_bus/ride_the_bus_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _big_button(text: String, action: Callable, height: float = 80) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(action)
	return b

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l

func _build_setup(root: VBoxContainer) -> void:
	setup_box = CenterContainer.new()
	setup_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(setup_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	setup_box.add_child(box)
	var l := _label(31, Color(1, 1, 1))
	l.text = tr("How many players?")
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var minus := Button.new()
	minus.text = "－"
	minus.custom_minimum_size = Vector2(64, 64)
	minus.add_theme_font_size_override("font_size", 35)
	minus.pressed.connect(_change_players.bind(-1))
	row.add_child(minus)
	players_label = _label(46, Color(1, 0.8, 0.3))
	players_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(players_label)
	var plus := Button.new()
	plus.text = "＋"
	plus.custom_minimum_size = Vector2(64, 64)
	plus.add_theme_font_size_override("font_size", 35)
	plus.pressed.connect(_change_players.bind(1))
	row.add_child(plus)
	var start := Button.new()
	start.text = tr("Start Game")
	start.custom_minimum_size = Vector2(260, 64)
	start.add_theme_font_size_override("font_size", 28)
	start.pressed.connect(_on_start)
	box.add_child(start)

func _change_players(d: int) -> void:
	num_players = clampi(num_players + d, 2, RBEngine.MAX_PLAYERS)
	players_label.text = str(num_players)

func _build_play(root: VBoxContainer) -> void:
	play_box = VBoxContainer.new()
	play_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.add_theme_constant_override("separation", 14)
	root.add_child(play_box)
	turn_label = _label(34, Color(1, 0.82, 0.3))
	play_box.add_child(turn_label)
	question_label = _label(28, Color(1, 1, 1))
	play_box.add_child(question_label)

	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.add_child(cc)
	card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(220, 300)
	cc.add_child(card_panel)
	card_label = Label.new()
	card_label.add_theme_font_size_override("font_size", 96)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	card_panel.add_child(card_label)

	result_label = _label(30, Color(0.5, 1, 0.5))
	result_label.custom_minimum_size = Vector2(0, 80)
	play_box.add_child(result_label)
	hand_label = _label(26, Color(0.8, 0.9, 0.85))
	play_box.add_child(hand_label)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_theme_constant_override("margin_left", 24)
	bm.add_theme_constant_override("margin_right", 24)
	play_box.add_child(bm)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bm.add_child(bottom)
	guess_row = HBoxContainer.new()
	guess_row.add_theme_constant_override("separation", 14)
	bottom.add_child(guess_row)
	suit_row = HBoxContainer.new()
	suit_row.add_theme_constant_override("separation", 10)
	for s in 4:
		var b := _big_button(SUITS[s], _on_guess.bind(str(s)), 90)
		b.add_theme_font_size_override("font_size", 48)
		b.add_theme_color_override("font_color", COLOR_RED.lightened(0.3) if s == 1 or s == 2 else Color(1, 1, 1))
		suit_row.add_child(b)
	bottom.add_child(suit_row)
	next_btn = _big_button(tr("Next ➜"), _on_next, 86)
	bottom.add_child(next_btn)

func _build_pyramid(root: VBoxContainer) -> void:
	pyramid_box = VBoxContainer.new()
	pyramid_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pyramid_box.add_theme_constant_override("separation", 16)
	root.add_child(pyramid_box)
	var head := _label(32, Color(1, 0.82, 0.3))
	head.text = tr("🔺 The Pyramid")
	pyramid_box.add_child(head)
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pyramid_box.add_child(cc)
	pyramid_rows = VBoxContainer.new()
	pyramid_rows.add_theme_constant_override("separation", 12)
	cc.add_child(pyramid_rows)
	pyramid_msg = _label(28, Color(1, 1, 1))
	pyramid_msg.custom_minimum_size = Vector2(0, 110)
	pyramid_box.add_child(pyramid_msg)
	counts_label = _label(24, Color(0.8, 0.9, 0.85))
	pyramid_box.add_child(counts_label)
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_theme_constant_override("margin_left", 24)
	bm.add_theme_constant_override("margin_right", 24)
	pyramid_box.add_child(bm)
	flip_btn = _big_button(tr("Flip next card"), _on_flip, 86)
	bm.add_child(flip_btn)

func _style_card(panel: PanelContainer, face_up: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.97, 0.94) if face_up else Color(0.55, 0.12, 0.15)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.shadow_size = 10
	sb.shadow_color = Color(0, 0, 0, 0.45)
	panel.add_theme_stylebox_override("panel", sb)

# ---------- flow ----------

func _show_setup() -> void:
	end_dialog.visible = false
	setup_box.visible = true
	play_box.visible = false
	pyramid_box.visible = false
	players_label.text = str(num_players)

func _on_start() -> void:
	engine.reset(num_players)
	if info:
		info.add("Games played")
	setup_box.visible = false
	play_box.visible = true
	_show_question()

func _player_name(p: int) -> String:
	return tr("Player %d") % (p + 1)

## Sets up the guess buttons for the step the current player / rider is on.
func _show_question() -> void:
	waiting_next = false
	var step: int = engine.round_index
	var who: int = engine.rider if engine.phase == "bus" else engine.current
	if engine.phase == "bus":
		turn_label.text = tr("🚌 %s rides the bus!") % _player_name(who)
		question_label.text = tr("Step %d of 4 · try %d") % [step + 1, engine.bus_attempts] + "\n" + _question_text(step)
		hand_label.text = "  ".join(PackedStringArray(engine.bus_cards.map(card_text)))
	else:
		turn_label.text = tr("%s's turn") % _player_name(who)
		question_label.text = tr("Round %d of 4") % (step + 1) + "\n" + _question_text(step)
		hand_label.text = "  ".join(PackedStringArray(engine.hands[who].map(card_text)))
	result_label.text = ""
	card_label.text = "?"
	card_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_style_card(card_panel, false)
	for c in guess_row.get_children():
		c.queue_free()
	match step:
		0:
			guess_row.add_child(_colored(_big_button(tr("Red"), _on_guess.bind("red"), 90), COLOR_RED.lightened(0.3)))
			guess_row.add_child(_big_button(tr("Black"), _on_guess.bind("black"), 90))
		1:
			guess_row.add_child(_big_button(tr("Higher ⬆"), _on_guess.bind("higher"), 90))
			guess_row.add_child(_big_button(tr("Lower ⬇"), _on_guess.bind("lower"), 90))
		2:
			guess_row.add_child(_big_button(tr("Inside"), _on_guess.bind("inside"), 90))
			guess_row.add_child(_big_button(tr("Outside"), _on_guess.bind("outside"), 90))
	guess_row.visible = step < 3
	suit_row.visible = step == 3
	next_btn.visible = false

func _colored(b: Button, c: Color) -> Button:
	b.add_theme_color_override("font_color", c)
	return b

func _question_text(step: int) -> String:
	return [tr("Red or black?"), tr("Higher or lower than your first card?"),
		tr("Inside or outside your first two cards?"), tr("Guess the suit!")][step]

func _on_guess(g: String) -> void:
	if waiting_next:
		return
	waiting_next = true
	var res: Dictionary = engine.bus_guess(g) if engine.phase == "bus" else engine.guess(g)
	var c: Dictionary = res.card
	_style_card(card_panel, true)
	card_label.text = card_text(c)
	card_label.add_theme_color_override("font_color", COLOR_RED if RBEngine.is_red(c) else COLOR_BLACK)
	card_panel.pivot_offset = card_panel.size / 2.0
	card_panel.scale = Vector2(0.2, 1.0)
	card_panel.create_tween().tween_property(card_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if res.correct:
		result_label.text = tr("✅ Right!")
		result_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	else:
		var drink_text: String = tr("❌ Wrong! Drink %d.") % res.drinks
		if engine.phase == "bus":
			drink_text += "\n" + tr("Back to the start!")
		result_label.text = drink_text
		result_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	guess_row.visible = false
	suit_row.visible = false
	if engine.phase == "done":
		_off_the_bus()
		return
	next_btn.text = tr("Pass the phone ➜") if engine.phase == "guess" else tr("Next ➜")
	if engine.phase == "pyramid":
		next_btn.text = tr("To the pyramid ➜")
	next_btn.visible = true

func _on_next() -> void:
	if engine.phase == "pyramid":
		play_box.visible = false
		pyramid_box.visible = true
		pyramid_msg.text = tr("Flip the cards one by one. Hold the same rank? Give out drinks!")
		_render_pyramid()
		return
	_show_question()

func _render_pyramid() -> void:
	for c in pyramid_rows.get_children():
		c.queue_free()
	var start := 0
	var rows: Array = []
	for r in RBEngine.PYRAMID_ROWS.size():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		for k in RBEngine.PYRAMID_ROWS[r]:
			var i: int = start + k
			var p := PanelContainer.new()
			p.custom_minimum_size = Vector2(118, 160)
			var up: bool = i < engine.flipped
			_style_card(p, up)
			var l := Label.new()
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			l.add_theme_font_size_override("font_size", 44 if up else 30)
			if up:
				l.text = card_text(engine.pyramid[i])
				l.add_theme_color_override("font_color", COLOR_RED if RBEngine.is_red(engine.pyramid[i]) else COLOR_BLACK)
			else:
				l.text = "×%d" % (r + 1)
				l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
			p.add_child(l)
			row.add_child(p)
		rows.append(row)
		start += RBEngine.PYRAMID_ROWS[r]
	rows.reverse()  # the top of the pyramid is drawn first
	for row in rows:
		pyramid_rows.add_child(row)
	var counts: PackedStringArray = []
	for p in engine.players:
		counts.append("%s: %d" % [tr("P%d") % (p + 1), engine.hands[p].size()])
	counts_label.text = tr("Cards left") + " — " + " · ".join(counts)
	if engine.phase == "bus":
		flip_btn.text = tr("Get on the bus ➜")
	else:
		flip_btn.text = tr("Flip next card")

func _on_flip() -> void:
	if engine.phase == "bus":
		pyramid_box.visible = false
		play_box.visible = true
		_show_question()
		return
	var res: Dictionary = engine.flip_next()
	var msg := card_text(res.card) + " — " + tr("row %d: %d drinks each") % [res.row + 1, res.drinks]
	if res.matches.is_empty():
		msg += "\n" + tr("Nobody has one. Phew!")
	else:
		for m in res.matches:
			msg += "\n" + tr("%s gives out %d!") % [_player_name(m[0]), res.drinks * m[1]]
	if engine.phase == "bus":
		msg += "\n\n" + tr("🚌 %s has the most cards and rides the bus!") % _player_name(engine.rider)
	pyramid_msg.text = msg
	_render_pyramid()

func _off_the_bus() -> void:
	var msg := tr("%s got off the bus!") % _player_name(engine.rider) + "\n" + tr("It took %d tries.") % engine.bus_attempts
	if info:
		info.add("Bus rides")
		info.high("Longest bus ride (tries)", engine.bus_attempts)
		info.celebrate(tr("Off the bus!"))
	end_dialog.get_meta("message_label").text = msg
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(end_dialog.set_visible.bind(true))

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/ride_the_bus/ride_the_bus_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/ride_the_bus/ride_the_bus_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Guess the cards, empty your hand in the pyramid — don't ride the bus!",
		"logo": _draw_home_logo,
		"multi_heading": "Party · one phone, pass it around",
		"modes": [{"text": "🚌  Play", "sub": "Choose the number of players", "multi": true, "color": HomeKit.GOLD, "action": _show_setup}],
		"restart": _show_setup,
		"board": "Games played",
		"board_note": "Games played, all time.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var w := h * 1.5
	var o := Vector2((c.size.x - w) / 2.0, c.size.y / 2.0 - h * 0.3)
	# a neon bus
	HomeKit.glow_rect(c, Rect2(o, Vector2(w, h * 0.5)), HomeKit.GOLD, 3.0, 0.12)
	for i in 4:
		HomeKit.glow_rect(c, Rect2(o + Vector2(w * (0.06 + i * 0.22), h * 0.08), Vector2(w * 0.16, h * 0.18)), HomeKit.CYAN, 1.5, 0.2)
	for x in [0.22, 0.78]:
		HomeKit.glow_circle(c, o + Vector2(w * x, h * 0.52), h * 0.1, HomeKit.PINK, 2.5, 0.2)
