extends Control

## Gin Rummy vs the computer. Tap the stock or the discard pile to draw, tap a
## card to select it, then Discard (or Knock / Gin when your deadwood allows).
## Your hand is kept sorted into melds (left) and deadwood (right).

const GinEngine = preload("res://scripts/games/gin_rummy/gin_rummy_engine.gd")
const Cards = preload("res://scripts/games/gin_rummy/gin_rummy_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_FELT := Color(0.05, 0.3, 0.17)

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var engine: GinEngine
var board: Control
var status_label: Label
var score_label: Label
var discard_btn: Button
var knock_btn: Button
var next_btn: Button
var cpu_timer: Timer
var end_dialog: ColorRect
var selected: int = -1
var layout: Array = []     # the player's cards in display order
var group_breaks: Array = []
var font: Font

func _ready() -> void:
	preload("res://scripts/games/gin_rummy/gin_rummy_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = GinEngine.new()
	_build_ui()
	_new_match()

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
	title.text = tr("🃁 Gin Rummy")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_new_match)
	bar.add_child(new_btn)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(score_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 25)
	status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
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

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 16)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 30)
	cm.add_child(controls)
	root.add_child(cm)
	discard_btn = _button(tr("Discard"), _on_discard.bind(false))
	controls.add_child(discard_btn)
	knock_btn = _button(tr("Knock"), _on_discard.bind(true))
	controls.add_child(knock_btn)
	next_btn = _button(tr("Next Hand"), _next_hand)
	controls.add_child(next_btn)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 0.9
	cpu_timer.timeout.connect(_cpu_step)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog(tr("Match Over"), [
		{"text": tr("Play Again"), "action": _new_match},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/gin_rummy/gin_rummy_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(210, 70)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b

func _new_match() -> void:
	result_recorded = false
	cpu_timer.stop()
	engine.new_match()
	end_dialog.visible = false
	_start_hand()

func _next_hand() -> void:
	if engine.phase != "over":
		return
	if engine.match_over():
		return
	engine.new_hand()
	_start_hand()

func _start_hand() -> void:
	selected = -1
	_refresh()
	if engine.turn == 1:
		cpu_timer.start()

# ---------- state -> UI ----------

func _refresh() -> void:
	var mine := GinEngine.best_melds(engine.hands[0])
	layout = []
	group_breaks = []
	for m in mine.melds:
		var sorted_meld: Array = m.duplicate()
		sorted_meld.sort_custom(func(a, b): return GinEngine.rank(a) < GinEngine.rank(b))
		layout.append_array(sorted_meld)
		group_breaks.append(layout.size())
	var dead: Array = mine.deadwood.duplicate()
	dead.sort_custom(func(a, b): return GinEngine.rank(a) * 4 + GinEngine.suit(a) < GinEngine.rank(b) * 4 + GinEngine.suit(b))
	layout.append_array(dead)
	score_label.text = tr("You %d  ·  Computer %d   (to %d)") % [engine.scores[0], engine.scores[1], GinEngine.TARGET]
	var my_turn: bool = engine.turn == 0 and engine.phase != "over"
	next_btn.visible = engine.phase == "over"
	discard_btn.visible = engine.phase != "over"
	knock_btn.visible = engine.phase != "over"
	discard_btn.disabled = not (my_turn and engine.phase == "discard" and selected >= 0 and engine.can_discard(selected))
	knock_btn.disabled = true
	knock_btn.text = tr("Knock")
	if not discard_btn.disabled:
		var dw := engine.deadwood_after(selected)
		knock_btn.disabled = dw > 10
		knock_btn.text = tr("Gin!") if dw == 0 else tr("Knock (%d)") % dw
	if engine.phase == "over":
		status_label.text = _result_text()
	elif not my_turn:
		status_label.text = tr("Computer's turn...")
	elif engine.phase == "draw":
		status_label.text = tr("Draw from the stock or the discard pile.  Deadwood: %d") % mine.points
	else:
		status_label.text = tr("Select a card to discard.  Deadwood: %d") % mine.points
	board.queue_redraw()

func _result_text() -> String:
	var r: Dictionary = engine.result
	if r.get("draw", false):
		return tr("The stock ran out — this hand is a draw.")
	var who := tr("You") if r.winner == 0 else tr("The computer")
	var how: String
	match r.kind:
		"gin":
			how = tr("%s went gin") % who
		"knock":
			how = tr("%s won the knock") % who
		_:
			how = tr("%s undercut the knock") % who
	return how + " — " + tr("%d points.") % r.points

# ---------- player actions ----------

func _on_discard(knock: bool) -> void:
	if engine.turn != 0 or selected < 0:
		return
	if engine.do_discard(selected, knock):
		selected = -1
		_after_action()

func _after_action() -> void:
	_refresh()
	if engine.phase == "over":
		if engine.match_over():
			var won: bool = engine.scores[0] >= GinEngine.TARGET
			end_dialog.get_meta("message_label").text = (tr("You win the match!") if won else tr("The computer wins the match.")) + _record_result("win" if won else "loss")
			end_dialog.visible = true
		return
	if engine.turn == 1:
		cpu_timer.start()

func _cpu_step() -> void:
	if engine.turn != 1 or engine.phase == "over":
		return
	if engine.phase == "draw":
		if engine.cpu_wants_discard():
			var c := engine.draw_discard()
			status_label.text = tr("Computer takes the %s.") % Cards.label(c)
		else:
			engine.draw_stock()
			status_label.text = tr("Computer draws from the stock.")
		board.queue_redraw()
		cpu_timer.start()
		return
	var choice := engine.cpu_discard()
	engine.do_discard(choice[0], choice[1])
	_after_action()

# ---------- drawing ----------

func _card_size() -> Vector2:
	var w: float = min(96.0, board.size.x / 7.0)
	return Vector2(w, w * 1.4)

func _pile_rects() -> Array:
	var cs := _card_size() * 1.2
	var y := board.size.y * 0.32
	return [Rect2(Vector2(board.size.x / 2.0 - cs.x - 24, y), cs), Rect2(Vector2(board.size.x / 2.0 + 24, y), cs)]

func _hand_rects() -> Array:
	var cs := _card_size()
	var n := layout.size()
	var gaps := group_breaks.size()
	var extra := cs.x * 0.25
	var step: float = min(cs.x + 4.0, (board.size.x - 20.0 - cs.x - gaps * extra) / max(1, n - 1))
	var total: float = step * (n - 1) + cs.x + gaps * extra
	var x: float = (board.size.x - total) / 2.0
	var out: Array = []
	for i in n:
		if i in group_breaks:
			x += extra
		var y := board.size.y - cs.y - 16.0
		if layout[i] == selected:
			y -= 26.0
		out.append(Rect2(Vector2(x, y), cs))
		x += step
	return out

func _draw_board() -> void:
	if engine.hands[0].is_empty():
		return
	var cs := _card_size()
	# computer's hand: hidden until the hand ends
	var cpu_hand: Array = engine.hands[1]
	var reveal: bool = engine.phase == "over"
	var shown: Array = cpu_hand
	var cpu_breaks: Array = []
	if reveal:
		var bm := GinEngine.best_melds(cpu_hand)
		shown = []
		for m in bm.melds:
			shown.append_array(m)
			cpu_breaks.append(shown.size())
		shown.append_array(bm.deadwood)
	var small := cs * (0.85 if reveal else 0.6)
	var n := shown.size()
	var step: float = min(small.x * (1.0 if reveal else 0.45), (board.size.x - 30.0 - small.x) / max(1, n - 1))
	var x0: float = (board.size.x - (step * (n - 1) + small.x + cpu_breaks.size() * 8)) / 2.0
	var x := x0
	for i in n:
		if i in cpu_breaks:
			x += 8
		Cards.draw_card(board, Rect2(Vector2(x, 30), small), shown[i], reveal)
		x += step
	board.draw_string(font, Vector2(0, 22), tr("Computer") + ("" if not reveal else "  " + tr("(deadwood %d)") % GinEngine.deadwood(cpu_hand)),
		HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 22, Color(0.85, 0.9, 0.85))
	var piles := _pile_rects()
	var can_draw: bool = engine.turn == 0 and engine.phase == "draw"
	if engine.stock.is_empty():
		Cards.draw_card(board, piles[0], -1)
	else:
		Cards.draw_card(board, piles[0], 0, false, can_draw)
	board.draw_string(font, piles[0].position + Vector2(0, piles[0].size.y + 26), tr("Stock: %d") % engine.stock.size(),
		HORIZONTAL_ALIGNMENT_CENTER, piles[0].size.x, 20, Color(0.85, 0.9, 0.85))
	if engine.discard.is_empty():
		Cards.draw_card(board, piles[1], -1)
	else:
		Cards.draw_card(board, piles[1], engine.discard.back(), true, can_draw)
	var rects := _hand_rects()
	for i in rects.size():
		var card: int = layout[i]
		var in_meld: bool = group_breaks.size() > 0 and i < group_breaks.back()
		Cards.draw_card(board, rects[i], card, true, card == selected)
		if in_meld:
			board.draw_rect(Rect2(rects[i].position + Vector2(4, rects[i].size.y - 8), Vector2(rects[i].size.x - 8, 4)), Color(0.4, 0.9, 0.5))

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if engine.turn != 0 or engine.phase == "over":
		return
	var pos: Vector2 = event.position
	if engine.phase == "draw":
		var piles := _pile_rects()
		if piles[0].has_point(pos):
			engine.draw_stock()
			_refresh()
		elif piles[1].has_point(pos):
			engine.draw_discard()
			_refresh()
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		if rects[i].has_point(pos):
			selected = -1 if selected == layout[i] else layout[i]
			_refresh()
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
