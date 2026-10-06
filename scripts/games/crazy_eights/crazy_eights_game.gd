extends Control

## Crazy Eights vs two computer players, or 2-4 people passing the phone.
## Tap a glowing card to play it; tap the deck to draw when you have nothing
## to play. In pass-and-play a cover screen hides the hand between turns.

const C8Engine = preload("res://scripts/games/crazy_eights/crazy_eights_engine.gd")
const HomeKit = preload("res://scripts/games/crazy_eights/home_kit.gd")
const Cards = preload("res://scripts/games/crazy_eights/crazy_eights_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_FELT := Color(0.03, 0.04, 0.1)
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://crazy_eights_save.json"

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: C8Engine
var board: Control
var status_label: Label
var suit_dialog: ColorRect
var end_dialog: ColorRect
var cpu_timer: Timer
var pending_eight: int = -1
var font: Font
var started := false  # a game is on (not just the one behind Home)
## Pass-and-play: every seat is a person; `viewer` is the one holding the phone.
var hotseat := false
var viewer: int = 0
var cover: ColorRect
var cover_label: Label
var last_msg := ""

func _ready() -> void:
	preload("res://scripts/games/crazy_eights/crazy_eights_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = C8Engine.new()
	_build_ui()
	_start_new_game()
	started = false

## Look (STANDARDS §9): "classic" = traditional ivory cards on green felt (default); "voodoo" = the neon
## board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: ColorRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.felt_dark if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	Cards.classic = skin == "classic"
	_redraw_cards()

func _redraw_cards() -> void:
	for n in find_children("*", "CanvasItem", true, false):
		n.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
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
	title.text = tr("8️⃣ Crazy Eights")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_start_new_game)
	bar.add_child(new_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var status_label_m := MarginContainer.new()  # side room for the floating ⚙ tab
	status_label_m.add_theme_constant_override("margin_left", 48)
	status_label_m.add_theme_constant_override("margin_right", 48)
	status_label_m.add_child(status_label)
	root.add_child(status_label_m)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	root.add_child(spacer)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 0.9
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	suit_dialog = UI.build_dialog(tr("Choose a suit"), [
		{"text": "♠", "action": _choose_suit.bind(0)},
		{"text": "♥", "action": _choose_suit.bind(1)},
		{"text": "♦", "action": _choose_suit.bind(2)},
		{"text": "♣", "action": _choose_suit.bind(3)},
	])
	add_child(suit_dialog)
	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	_build_cover()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/crazy_eights/crazy_eights_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	started = true
	result_recorded = false
	cpu_timer.stop()
	engine.new_game(engine.PLAYERS if hotseat else 3)
	_sfx("card_shuffle")
	pending_eight = -1
	viewer = 0
	last_msg = ""
	end_dialog.visible = false
	suit_dialog.visible = false
	cover.visible = false
	_update_status()
	if hotseat:
		_show_cover()

func _player_name(p: int) -> String:
	if hotseat:
		return tr("Player %d") % (p + 1)
	return tr("You") if p == 0 else tr("CPU %d") % p

## The seat whose hand is face up on this phone.
func _me() -> int:
	return viewer if hotseat else 0

func _my_turn() -> bool:
	return engine.winner == -1 and engine.turn == _me() and not (hotseat and cover.visible)

func _build_cover() -> void:
	cover = ColorRect.new()
	cover.color = Color(0.01, 0.02, 0.06, 1.0)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.visible = false
	add_child(cover)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	center.add_child(box)
	cover_label = Label.new()
	cover_label.add_theme_font_size_override("font_size", 36)
	cover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cover_label.custom_minimum_size = Vector2(560, 0)
	box.add_child(cover_label)
	var go := Button.new()
	go.text = tr("I'm ready")
	go.custom_minimum_size = Vector2(360, 90)
	go.add_theme_font_size_override("font_size", 32)
	go.pressed.connect(_on_cover_ready)
	box.add_child(go)

func _show_cover() -> void:
	cover_label.text = (last_msg + "\n\n" if last_msg != "" else "") + tr("Pass the phone to %s") % _player_name(engine.turn)
	cover.visible = true

func _on_cover_ready() -> void:
	cover.visible = false
	viewer = engine.turn
	_update_status(last_msg)

func _update_status(extra: String = "") -> void:
	engine.hands[_me()].sort()
	if _my_turn():
		var who := (_player_name(_me()) + ": ") if hotseat else ""
		if engine.playable(_me()).is_empty():
			status_label.text = who + (tr("No match — tap the deck to draw.") if engine.can_draw() else tr("No match and no cards left — tap the deck to pass."))
		else:
			status_label.text = who + tr("Your turn: match %s or a rank, 8s are wild.") % Cards.SUITS[engine.suit_now]
		if hotseat and extra != "":
			status_label.text = extra + "\n" + status_label.text
	else:
		status_label.text = extra
	board.queue_redraw()

# ---------- turns ----------

func _human_play(card: int) -> void:
	if C8Engine.rank(card) == 8:
		pending_eight = card
		suit_dialog.visible = true
		return
	var who := _me()
	engine.play(who, card)
	_sfx("card_place")
	last_msg = tr("%s plays %s") % [_player_name(who), Cards.label(card)]
	_after_turn()

func _choose_suit(s: int) -> void:
	if pending_eight >= 0:
		var who := _me()
		engine.play(who, pending_eight, s)
		_sfx("card_place")
		last_msg = tr("%s plays %s") % [_player_name(who), Cards.label(pending_eight)] + " — " + tr("suit is now %s") % Cards.SUITS[engine.suit_now]
		pending_eight = -1
		_after_turn()

func _human_draw() -> void:
	if not engine.playable(_me()).is_empty():
		return
	if engine.draw() == -1:
		last_msg = tr("%s passes.") % _player_name(_me())
		engine.pass_turn()
		_after_turn()
		return
	_sfx("card_deal")
	_update_status()

func _after_turn() -> void:
	if _check_end():
		return
	if hotseat:
		_update_status()
		_show_cover()
		return
	_update_status(tr("%s is thinking...") % _player_name(engine.turn))
	if engine.turn != 0:
		cpu_timer.start()

func _cpu_turn() -> void:
	var p: int = engine.turn
	if p == 0 or hotseat or engine.winner != -1:
		return
	var drew := 0
	var choice: Array = engine.cpu_choice(p)
	while choice.is_empty():
		if engine.draw() == -1:
			break
		drew += 1
		_sfx("card_deal")
		choice = engine.cpu_choice(p)
	var msg := ""
	if choice.is_empty():
		engine.pass_turn()
		msg = tr("%s passes.") % _player_name(p)
	else:
		engine.play(p, choice[0], choice[1])
		_sfx("card_place")
		msg = tr("%s plays %s") % [_player_name(p), Cards.label(choice[0])]
		if C8Engine.rank(choice[0]) == 8:
			msg += " — " + tr("suit is now %s") % Cards.SUITS[engine.suit_now]
	if drew > 0:
		msg = tr("%s drew %d.") % [_player_name(p), drew] + " " + msg
	if _check_end():
		return
	_update_status(msg)
	if engine.turn != 0:
		cpu_timer.start()
	else:
		# show what just happened above the player's prompt
		status_label.text = msg + "\n" + status_label.text

func _check_end() -> bool:
	if engine.winner == -1:
		return false
	var msg: String
	if hotseat:
		cover.visible = false
		if engine.winner == engine.PLAYERS:
			msg = tr("Nobody can move — it's a draw.")
		else:
			msg = tr("%s wins!") % _player_name(engine.winner)
		SaveUtil.delete(SAVE_PATH)
		if info and not result_recorded:
			result_recorded = true
			info.add("Pass-and-play games")
			info.celebrate(msg)
		end_dialog.get_meta("message_label").text = msg
		end_dialog.visible = true
		board.queue_redraw()
		return true
	if engine.winner == 0:
		msg = tr("You win!")
	elif engine.winner == engine.PLAYERS:
		msg = tr("Nobody can move — it's a draw.")
	else:
		msg = tr("%s wins!") % _player_name(engine.winner)
	msg += _record_result("win" if engine.winner == 0 else ("draw" if engine.winner == engine.PLAYERS else "loss"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	board.queue_redraw()
	return true

# ---------- drawing ----------

func _card_size() -> Vector2:
	var w: float = min(110.0, board.size.x / 6.5)
	return Vector2(w, w * 1.4)

func _pile_rects() -> Array:
	var cs := _card_size()
	var y := board.size.y * 0.3
	return [Rect2(Vector2(board.size.x / 2.0 - cs.x - 20, y), cs), Rect2(Vector2(board.size.x / 2.0 + 20, y), cs)]

## Positions of the player's cards (up to two rows).
func _hand_rects() -> Array:
	var cs := _card_size()
	var hand: Array = engine.hands[_me()]
	var n := hand.size()
	var per_row: int = max(1, ceili(n / 2.0)) if n > 7 else n
	var out: Array = []
	var bottom := board.size.y - cs.y - 10.0
	for i in n:
		var row: int = i / per_row if per_row > 0 else 0
		var col: int = i % per_row if per_row > 0 else i
		var in_row: int = min(per_row, n - row * per_row)
		var step: float = min(cs.x + 6.0, (board.size.x - 20.0 - cs.x) / max(1, in_row - 1))
		var x0: float = (board.size.x - (step * (in_row - 1) + cs.x)) / 2.0
		var rows: int = ceili(float(n) / per_row) if per_row > 0 else 1
		out.append(Rect2(Vector2(x0 + col * step, bottom - (rows - 1 - row) * cs.y * 0.62), cs))
	return out

func _draw_board() -> void:
	if engine.hands.is_empty():
		return
	var cs := _card_size()
	# opponents: everyone but the player holding the phone
	var others: Array = []
	for k in range(1, engine.PLAYERS):
		others.append((_me() + k) % engine.PLAYERS)
	var xs: Array = [[0.5], [0.25, 0.75], [0.17, 0.5, 0.83]][others.size() - 1]
	for oi in others.size():
		var p: int = others[oi]
		var x: float = board.size.x * xs[oi]
		var small := cs * 0.55
		var n: int = engine.hands[p].size()
		var spread: float = min(small.x * 0.35, 200.0 / max(1, n))
		var x0 := x - (spread * (n - 1) + small.x) / 2.0
		for k in n:
			Cards.draw_card(board, Rect2(Vector2(x0 + k * spread, 36), small), 0, false)
		var name_col := Color(1, 0.9, 0.4) if engine.turn == p else Color(0.85, 0.9, 0.85)
		board.draw_string(font, Vector2(x - 120, 26), tr("%s: %d cards") % [_player_name(p), n], HORIZONTAL_ALIGNMENT_CENTER, 240, 20 if others.size() > 2 else 22, name_col)
	var piles := _pile_rects()
	var stuck: bool = _my_turn() and engine.playable(_me()).is_empty()
	if engine.can_draw():
		Cards.draw_card(board, piles[0], 0, false, stuck)
	else:
		Cards.draw_card(board, piles[0], -1, true, stuck)
	Cards.draw_card(board, piles[1], engine.top())
	# current suit marker (matters after an 8)
	board.draw_string(font, piles[1].position + Vector2(piles[1].size.x + 12, piles[1].size.y * 0.6), Cards.SUITS[engine.suit_now],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Cards.COLOR_RED if engine.suit_now in [1, 2] else Color(1, 1, 1))
	if hotseat and cover.visible:
		return  # never show a hand while the phone changes hands
	var rects := _hand_rects()
	var my_turn: bool = _my_turn()
	for i in rects.size():
		var card: int = engine.hands[_me()][i]
		var ok: bool = my_turn and engine.can_play(card)
		Cards.draw_card(board, rects[i], card, true, ok, my_turn and not ok)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _my_turn() or suit_dialog.visible:
		return
	var pos: Vector2 = event.position
	if _pile_rects()[0].has_point(pos):
		_human_draw()
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		if rects[i].has_point(pos):
			var card: int = engine.hands[_me()][i]
			if engine.can_play(card):
				_human_play(card)
			return


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	SaveUtil.delete(SAVE_PATH)
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/crazy_eights/crazy_eights_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/crazy_eights/crazy_eights_help.gd"),
		"info": info,
		"accent": HomeKit.PINK,
		"subtitle": "Match the suit or the rank — eights are wild. You vs two computers.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🃏  Play", "sub": "vs two computer players", "action": _new_game.bind(0)},
			{"text": "👥 2", "row": "players", "multi": true, "color": HomeKit.CYAN, "action": _new_game.bind(2)},
			{"text": "👥 3", "row": "players", "multi": true, "color": HomeKit.PINK, "action": _new_game.bind(3)},
			{"text": "👥 4", "row": "players", "multi": true, "color": HomeKit.LIME, "action": _new_game.bind(4)},
		],
		"multi_heading": "Pass the phone",
		"resume_text": _resume_text,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _start_new_game,
		"board": "Wins",
		"board_note": "Games won.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y * 0.85, 160.0)
	var w := h * 0.68
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0 + 6)
	var cards := [[-0.35, Cards.new_deck()[7 + 13]], [0.0, Cards.new_deck()[7]], [0.35, Cards.new_deck()[7 + 39]]]
	for spec in cards:
		c.draw_set_transform(ctr + Vector2(spec[0] * w * 1.1, abs(spec[0]) * h * 0.18), spec[0], Vector2.ONE)
		Cards.draw_card(c, Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)), spec[1])
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 0 = vs the computers; 2-4 = that many people passing the phone.
func _new_game(n: int = 0) -> void:
	hotseat = n > 0
	engine.PLAYERS = n if hotseat else 3
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var n := int(d.get("players", 0))
	return tr("%d players") % n if n > 0 else tr("vs Computer")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

## Saved on a person's turn: the computers' turns replay from there.
func _save_game() -> void:
	if not started or engine.winner != -1 or pending_eight >= 0:
		return
	if not hotseat and engine.turn != 0:
		return
	SaveUtil.write(SAVE_PATH, {"hands": engine.hands, "deck": engine.deck, "discard": engine.discard,
		"suit": engine.suit_now, "passes": engine.passes, "players": engine.PLAYERS if hotseat else 0, "turn": engine.turn})

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	var n := int(d.get("players", 0))
	hotseat = n > 0
	engine.PLAYERS = n if hotseat else 3
	_start_new_game()
	engine.hands = []
	for hnd in d.hands:
		engine.hands.append(_ints(hnd))
	engine.deck = _ints(d.deck)
	engine.discard = _ints(d.discard)
	engine.suit_now = int(d.suit)
	engine.passes = int(d.get("passes", 0))
	engine.turn = clampi(int(d.get("turn", 0)), 0, engine.PLAYERS - 1) if hotseat else 0
	engine.winner = -1
	_update_status()
	if hotseat:
		last_msg = ""
		_show_cover()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
