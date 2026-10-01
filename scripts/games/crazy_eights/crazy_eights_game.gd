extends Control

## Crazy Eights vs two computer players. Tap a glowing card to play it; tap
## the deck to draw when you have nothing to play.

const C8Engine = preload("res://scripts/games/crazy_eights/crazy_eights_engine.gd")
const Cards = preload("res://scripts/games/crazy_eights/crazy_eights_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_FELT := Color(0.05, 0.3, 0.17)

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var engine: C8Engine
var board: Control
var status_label: Label
var suit_dialog: ColorRect
var end_dialog: ColorRect
var cpu_timer: Timer
var pending_eight: int = -1
var font: Font

func _ready() -> void:
	preload("res://scripts/games/crazy_eights/crazy_eights_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = C8Engine.new()
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COLOR_FELT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
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
	root.add_child(status_label)

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
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/crazy_eights/crazy_eights_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	result_recorded = false
	cpu_timer.stop()
	engine.new_game()
	pending_eight = -1
	end_dialog.visible = false
	suit_dialog.visible = false
	_update_status()

func _player_name(p: int) -> String:
	return tr("You") if p == 0 else tr("CPU %d") % p

func _update_status(extra: String = "") -> void:
	engine.hands[0].sort()
	if engine.turn == 0 and engine.winner == -1:
		if engine.playable(0).is_empty():
			status_label.text = tr("No match — tap the deck to draw.") if engine.can_draw() else tr("No match and no cards left — tap the deck to pass.")
		else:
			status_label.text = tr("Your turn: match %s or a rank, 8s are wild.") % Cards.SUITS[engine.suit_now]
	else:
		status_label.text = extra
	board.queue_redraw()

# ---------- turns ----------

func _human_play(card: int) -> void:
	if C8Engine.rank(card) == 8:
		pending_eight = card
		suit_dialog.visible = true
		return
	engine.play(0, card)
	_after_turn()

func _choose_suit(s: int) -> void:
	if pending_eight >= 0:
		engine.play(0, pending_eight, s)
		pending_eight = -1
		_after_turn()

func _human_draw() -> void:
	if not engine.playable(0).is_empty():
		return
	if engine.draw() == -1:
		engine.pass_turn()
		_after_turn()
		return
	_update_status()

func _after_turn() -> void:
	if _check_end():
		return
	_update_status(tr("%s is thinking...") % _player_name(engine.turn))
	if engine.turn != 0:
		cpu_timer.start()

func _cpu_turn() -> void:
	var p: int = engine.turn
	if p == 0 or engine.winner != -1:
		return
	var drew := 0
	var choice: Array = engine.cpu_choice(p)
	while choice.is_empty():
		if engine.draw() == -1:
			break
		drew += 1
		choice = engine.cpu_choice(p)
	var msg := ""
	if choice.is_empty():
		engine.pass_turn()
		msg = tr("%s passes.") % _player_name(p)
	else:
		engine.play(p, choice[0], choice[1])
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
	if engine.winner == 0:
		msg = tr("You win!")
	elif engine.winner == C8Engine.PLAYERS:
		msg = tr("Nobody can move — it's a draw.")
	else:
		msg = tr("%s wins!") % _player_name(engine.winner)
	msg += _record_result("win" if engine.winner == 0 else ("draw" if engine.winner == C8Engine.PLAYERS else "loss"))
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
	var hand: Array = engine.hands[0]
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
	# opponents
	for p in [1, 2]:
		var x: float = board.size.x * (0.25 if p == 1 else 0.75)
		var small := cs * 0.55
		var n: int = engine.hands[p].size()
		var spread: float = min(small.x * 0.35, 200.0 / max(1, n))
		var x0 := x - (spread * (n - 1) + small.x) / 2.0
		for k in n:
			Cards.draw_card(board, Rect2(Vector2(x0 + k * spread, 36), small), 0, false)
		var name_col := Color(1, 0.9, 0.4) if engine.turn == p else Color(0.85, 0.9, 0.85)
		board.draw_string(font, Vector2(x - 150, 26), tr("%s: %d cards") % [_player_name(p), n], HORIZONTAL_ALIGNMENT_CENTER, 300, 22, name_col)
	var piles := _pile_rects()
	if engine.can_draw():
		Cards.draw_card(board, piles[0], 0, false, engine.turn == 0 and engine.playable(0).is_empty())
	else:
		Cards.draw_card(board, piles[0], -1, true, engine.turn == 0 and engine.playable(0).is_empty())
	Cards.draw_card(board, piles[1], engine.top())
	# current suit marker (matters after an 8)
	board.draw_string(font, piles[1].position + Vector2(piles[1].size.x + 12, piles[1].size.y * 0.6), Cards.SUITS[engine.suit_now],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Cards.COLOR_RED if engine.suit_now in [1, 2] else Color(1, 1, 1))
	var rects := _hand_rects()
	var my_turn: bool = engine.turn == 0 and engine.winner == -1
	for i in rects.size():
		var card: int = engine.hands[0][i]
		var ok: bool = my_turn and engine.can_play(card)
		Cards.draw_card(board, rects[i], card, true, ok, my_turn and not ok)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if engine.turn != 0 or engine.winner != -1 or suit_dialog.visible:
		return
	var pos: Vector2 = event.position
	if _pile_rects()[0].has_point(pos):
		_human_draw()
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		if rects[i].has_point(pos):
			var card: int = engine.hands[0][i]
			if engine.can_play(card):
				_human_play(card)
			return


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()
