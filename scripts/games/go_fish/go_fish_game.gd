extends Control

## Go Fish vs the computer -- tap one of your cards to ask for that rank.

const GFEngine = preload("res://scripts/games/go_fish/go_fish_engine.gd")
const Cards = preload("res://scripts/games/go_fish/go_fish_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_FELT := Color(0.05, 0.3, 0.17)

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var engine: GFEngine
var board: Control
var status_label: Label
var log_text: String = ""
var cpu_timer: Timer
var end_dialog: ColorRect
var font: Font

func _ready() -> void:
	preload("res://scripts/games/go_fish/go_fish_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = GFEngine.new()
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
	title.text = tr("🐟 Go Fish")
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
	status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
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
	cpu_timer.wait_time = 1.3
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/go_fish/go_fish_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	result_recorded = false
	cpu_timer.stop()
	engine.new_game()
	end_dialog.visible = false
	log_text = tr("Tap one of your cards to ask the computer for that rank.")
	_begin_turn()

func _rank_name(r: int) -> String:
	return Cards.rank_str(r)

func _begin_turn() -> void:
	if engine.is_over():
		_finish()
		return
	var skipped := not engine.prepare_turn()
	if skipped:
		# that player had no cards and the deck is empty
		_begin_turn()
		return
	engine.hands[0].sort_custom(func(a, b): return GFEngine.rank(a) < GFEngine.rank(b))
	if engine.turn == 0:
		status_label.text = tr("Your turn — ask for a rank.")
	else:
		status_label.text = tr("Computer's turn...")
		cpu_timer.start()
	board.queue_redraw()

func _describe(who_asks: int, r: int, res: Dictionary) -> String:
	var rn := _rank_name(r)
	var msg: String
	if who_asks == 0:
		if res.got > 0:
			msg = tr("The computer gives you %d × %s!") % [res.got, rn]
		elif res.drew >= 0:
			msg = tr("Go fish! You drew %s.") % Cards.label(res.drew)
			if res.again:
				msg += " " + tr("That's what you asked for — go again!")
		else:
			msg = tr("Go fish! The pond is empty.")
	else:
		if res.got > 0:
			msg = tr("Computer asked for %s — you hand over %d.") % [rn, res.got]
		else:
			msg = tr("Computer asked for %s — go fish!") % rn
			if res.again:
				msg += " " + tr("It drew one and goes again.")
	for b in res.new_books:
		msg += "\n" + (tr("You made a book of %s!") if who_asks == 0 else tr("Computer made a book of %s.")) % _rank_name(b)
	return msg

func _cpu_turn() -> void:
	if engine.turn != 1 or engine.is_over():
		return
	var r := engine.cpu_pick()
	var res := engine.ask(r)
	log_text = _describe(1, r, res)
	_begin_turn()

func _finish() -> void:
	var a: int = engine.books[0].size()
	var b: int = engine.books[1].size()
	var msg := tr("Books: you %d, computer %d.") % [a, b] + "\n"
	msg += tr("You win!") if a > b else tr("You lose!")
	msg += _record_result("win" if a > b else "loss")
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	board.queue_redraw()

# ---------- drawing ----------

func _card_size() -> Vector2:
	var w: float = min(120.0, board.size.x / 6.0)
	return Vector2(w, w * 1.4)

func _hand_rects() -> Array:
	var cs := _card_size()
	var n: int = engine.hands[0].size()
	var out: Array = []
	var per_row: int = n if n <= 8 else ceili(n / 2.0)
	var rows: int = ceili(float(n) / max(1, per_row))
	for i in n:
		var row: int = i / per_row
		var col: int = i % per_row
		var in_row: int = min(per_row, n - row * per_row)
		var step: float = min(cs.x + 6.0, (board.size.x - 20.0 - cs.x) / max(1, in_row - 1))
		var x0: float = (board.size.x - (step * (in_row - 1) + cs.x)) / 2.0
		out.append(Rect2(Vector2(x0 + col * step, board.size.y - cs.y - 10.0 - (rows - 1 - row) * cs.y * 0.6), cs))
	return out

func _draw_books(y: float, p: int) -> void:
	var small := _card_size() * 0.45
	var list: Array = engine.books[p]
	for i in list.size():
		Cards.draw_card(board, Rect2(Vector2(20 + i * (small.x * 0.55), y), small), list[i] - 1)

func _draw_board() -> void:
	if engine.hands[0].is_empty() and engine.hands[1].is_empty() and engine.deck.is_empty() and engine.books[0].is_empty():
		return
	var cs := _card_size()
	var small := cs * 0.5
	var n: int = engine.hands[1].size()
	var spread: float = min(small.x * 0.4, 300.0 / max(1, n))
	var x0 := board.size.x / 2.0 - (spread * (n - 1) + small.x) / 2.0
	for k in n:
		Cards.draw_card(board, Rect2(Vector2(x0 + k * spread, 34), small), 0, false)
	board.draw_string(font, Vector2(0, 24), tr("Computer: %d cards, %d books") % [n, engine.books[1].size()],
		HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 22, Color(0.85, 0.9, 0.85))
	_draw_books(34 + small.y + 10, 1)
	# the pond
	var pond := Rect2(Vector2(board.size.x / 2.0 - cs.x / 2.0, board.size.y * 0.3), cs)
	if engine.deck.is_empty():
		Cards.draw_card(board, pond, -1)
	else:
		for k in min(4, engine.deck.size()):
			Cards.draw_card(board, Rect2(pond.position + Vector2(k * 3, -k * 3), cs), 0, false)
	board.draw_string(font, pond.position + Vector2(-100, cs.y + 30), tr("Pond: %d") % engine.deck.size(),
		HORIZONTAL_ALIGNMENT_CENTER, cs.x + 200, 22, Color(0.85, 0.9, 0.85))
	# log text between pond and hand
	var log_y := pond.position.y + cs.y + 70
	var lines: PackedStringArray = log_text.split("\n")
	for i in lines.size():
		board.draw_string(font, Vector2(10, log_y + i * 30), lines[i], HORIZONTAL_ALIGNMENT_CENTER, board.size.x - 20, 23, Color(1, 1, 1))
	var rects := _hand_rects()
	var top_y: float = rects[0].position.y if not rects.is_empty() else board.size.y - cs.y
	board.draw_string(font, Vector2(20, top_y - 64), tr("Your books: %d") % engine.books[0].size(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.9, 0.85))
	_draw_books(top_y - 56, 0)
	for i in rects.size():
		Cards.draw_card(board, rects[i], engine.hands[0][i], true, engine.turn == 0)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if engine.turn != 0 or engine.is_over() or end_dialog.visible:
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		if rects[i].has_point(event.position):
			var r := GFEngine.rank(engine.hands[0][i])
			var res := engine.ask(r)
			log_text = tr("You asked for %s.") % _rank_name(r) + " " + _describe(0, r, res)
			_begin_turn()
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
