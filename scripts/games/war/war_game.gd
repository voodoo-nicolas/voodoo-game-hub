extends Control

const WarEngine = preload("res://scripts/games/war/war_engine.gd")
const HomeKit = preload("res://scripts/games/war/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const RED_SUITS := ["♥", "♦"]

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var p1_pile_label: Label
var p2_pile_label: Label
var p1_card_label: Label
var p2_card_label: Label
var result_label: Label
var play_btn: Button
var win_dialog: Control
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://war_save.json"
var started := false  # a game is on (not just the one behind Home)
var win_label: Label
## Two players on one phone: each flips with their own button; a round is
## played once both have flipped.
var two_player := false
var flip_row: HBoxContainer
var flip_btns: Array = []
var ready_flags: Array = [false, false]

func _ready() -> void:
	preload("res://scripts/games/war/war_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = WarEngine.new()
	_build_ui()
	_start_new_game()
	started = false

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
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
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("⚔️ War")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.PINK.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.PINK, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var piles_row := HBoxContainer.new()
	piles_row.alignment = BoxContainer.ALIGNMENT_CENTER
	piles_row.add_theme_constant_override("separation", 60)
	box.add_child(piles_row)

	p1_pile_label = _pile_label(tr("You: 26"))
	piles_row.add_child(p1_pile_label)
	p2_pile_label = _pile_label(tr("CPU: 26"))
	piles_row.add_child(p2_pile_label)

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 30)
	box.add_child(cards_row)

	p1_card_label = _card_label()
	cards_row.add_child(p1_card_label)
	p2_card_label = _card_label()
	cards_row.add_child(p2_card_label)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 26)
	result_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	result_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(result_label)

	play_btn = Button.new()
	play_btn.text = tr("Play Round")
	play_btn.custom_minimum_size = Vector2(220, 56)
	play_btn.add_theme_font_size_override("font_size", 26)
	play_btn.pressed.connect(_on_play_pressed)
	box.add_child(play_btn)

	flip_row = HBoxContainer.new()
	flip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	flip_row.add_theme_constant_override("separation", 30)
	box.add_child(flip_row)
	for p in 2:
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 110)
		b.add_theme_font_size_override("font_size", 28)
		b.set_meta("sfx", "card_flip")
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, HomeKit.neon_box([HomeKit.CYAN, HomeKit.PINK][p], st))
		b.pressed.connect(_on_flip.bind(p))
		flip_row.add_child(b)
		flip_btns.append(b)

	_build_win_dialog()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/war/war_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _pile_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	return l

func _card_label() -> Label:
	var l := Label.new()
	l.text = "🂠"
	l.add_theme_font_size_override("font_size", 70)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.custom_minimum_size = Vector2(90, 100)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _build_win_dialog() -> void:
	win_dialog = ColorRect.new()
	win_dialog.color = Color(0, 0, 0, 0.75)
	win_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_dialog.visible = false
	add_child(win_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_dialog.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.18)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	win_label = Label.new()
	win_label.add_theme_font_size_override("font_size", 31)
	win_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_label)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(_go_home)
	box.add_child(menu_btn)

# ---------- game flow ----------

func _start_new_game() -> void:
	started = true
	result_recorded = false
	engine.reset()
	win_dialog.visible = false
	result_label.text = tr("Tap Play Round to begin!")
	p1_card_label.text = "✦"
	p2_card_label.text = "✦"
	p1_card_label.add_theme_color_override("font_color", Color(1, 1, 1))
	p2_card_label.add_theme_color_override("font_color", Color(1, 1, 1))
	ready_flags = [false, false]
	play_btn.visible = not two_player
	flip_row.visible = two_player
	if two_player:
		result_label.text = tr("Both players tap Flip!")
	_update_flip_buttons()
	_update_piles()

func _pname(p: int) -> String:
	if two_player:
		return tr("Player %d") % p
	return tr("You") if p == 1 else tr("CPU")

func _on_flip(p: int) -> void:
	if engine.game_over or ready_flags[p]:
		return
	ready_flags[p] = true
	_update_flip_buttons()
	if ready_flags[0] and ready_flags[1]:
		ready_flags = [false, false]
		_on_play_pressed()
		_update_flip_buttons()

func _update_flip_buttons() -> void:
	for p in 2:
		flip_btns[p].text = (tr("Player %d") % (p + 1)) + "\n" + (tr("Ready!") if ready_flags[p] else tr("Flip"))
		flip_btns[p].disabled = ready_flags[p]

func _on_play_pressed() -> void:
	var result: Dictionary = engine.play_round()
	_update_piles()

	if result.has("p1_card"):
		var c1: Dictionary = result.p1_card
		var c2: Dictionary = result.p2_card
		p1_card_label.text = "%s%s" % [c1.rank, c1.suit]
		p2_card_label.text = "%s%s" % [c2.rank, c2.suit]
		p1_card_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if RED_SUITS.has(c1.suit) else Color(1, 1, 1))
		p2_card_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if RED_SUITS.has(c2.suit) else Color(1, 1, 1))

		var prefix := tr("⚔️ WAR! ") if result.war_happened else ""
		if two_player:
			result_label.text = prefix + tr("%s wins %d cards!") % [_pname(result.round_winner), result.cards_won]
		elif result.round_winner == 1:
			result_label.text = tr("%sYou win %d cards!") % [prefix, result.cards_won]
		else:
			result_label.text = tr("%sCPU wins %d cards!") % [prefix, result.cards_won]
	elif result.has("ran_out"):
		result_label.text = tr("%s ran out of cards mid-war!") % _pname(result.ran_out)

	if result.game_over:
		_show_result()

func _update_piles() -> void:
	p1_pile_label.text = _pname(1) + ": %d" % engine.p1_pile.size()
	p2_pile_label.text = _pname(2) + ": %d" % engine.p2_pile.size()

func _show_result() -> void:
	SaveUtil.delete(SAVE_PATH)
	if two_player:
		win_label.text = tr("%s wins the game!") % _pname(engine.winner)
		if info and not result_recorded:
			result_recorded = true
			info.add("2-player games")
			info.celebrate(win_label.text)
		win_dialog.visible = true
		return
	win_label.text = (tr("You win the game!") if engine.winner == 1 else tr("CPU wins the game!")) + _record_result("win" if engine.winner == 1 else "loss")
	win_dialog.visible = true


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/war/war_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/war/war_help.gd"),
		"info": info,
		"accent": HomeKit.PINK,
		"subtitle": "Flip, compare, win the cards. Take all 52!",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "⚔️  Play", "sub": "vs the computer", "action": _fresh_game.bind(false)},
			{"text": "👥 2 Players", "sub": "Each flips their own card", "multi": true, "action": _fresh_game.bind(true)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _start_new_game,
		"board": "Wins",
		"board_note": "Games won against the computer.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y * 0.85, 150.0)
	var w := h * 0.68
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	for spec in [[-0.2, -w * 0.45, "K", "♥", HomeKit.PINK], [0.2, w * 0.45, "Q", "♠", HomeKit.CYAN]]:
		c.draw_set_transform(ctr + Vector2(spec[1], 0), spec[0], Vector2.ONE)
		var r := Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h))
		c.draw_rect(r, Color(0.05, 0.07, 0.15))
		HomeKit.glow_rect(c, r, spec[4], 2.5)
		HomeKit.glow_text(c, Vector2(0, -h * 0.1), spec[2], int(h * 0.36), Color.WHITE)
		HomeKit.glow_text(c, Vector2(0, h * 0.24), spec[3], int(h * 0.24), spec[4])
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _fresh_game(two: bool = false) -> void:
	two_player = two
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	return (tr("2 Players") + "   ·   " if bool(d.get("two", false)) else "") + tr("%d cards") % d.p1.size()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not started or engine.game_over:
		return
	SaveUtil.write(SAVE_PATH, {"p1": engine.p1_pile, "p2": engine.p2_pile, "two": two_player})

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	two_player = bool(d.get("two", false))
	_start_new_game()
	engine.p1_pile = []
	for card in d.p1:
		engine.p1_pile.append({"rank": str(card.rank), "suit": str(card.suit), "value": int(card.value)} if typeof(card) == TYPE_DICTIONARY and card.has("value") else card)
	engine.p2_pile = []
	for card in d.p2:
		engine.p2_pile.append({"rank": str(card.rank), "suit": str(card.suit), "value": int(card.value)} if typeof(card) == TYPE_DICTIONARY and card.has("value") else card)
	_update_piles()
