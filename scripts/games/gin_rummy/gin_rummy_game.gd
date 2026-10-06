extends Control

## Gin Rummy vs the computer, or two players passing the phone (a cover
## screen hides the hands between turns). Tap the stock or the discard pile to draw, tap a
## card to select it, then Discard (or Knock / Gin when your deadwood allows).
## Your hand is kept sorted into melds (left) and deadwood (right).

const GinEngine = preload("res://scripts/games/gin_rummy/gin_rummy_engine.gd")
const HomeKit = preload("res://scripts/games/gin_rummy/home_kit.gd")
const Cards = preload("res://scripts/games/gin_rummy/gin_rummy_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_FELT := Color(0.03, 0.04, 0.1)
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://gin_rummy_save.json"

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: GinEngine
var board: Control
var status_label: Label
var score_label: Label
var discard_btn: Button
var knock_btn: Button
var next_btn: Button
var cpu_timer: Timer
var end_dialog: ColorRect
var started := false  # a match is on (not just the one behind Home)
var selected: int = -1
var layout: Array = []     # the player's cards in display order
var group_breaks: Array = []
var font: Font
## Two players on one phone: `viewer` is whose hand is face up.
var hotseat := false
var viewer: int = 0
var cover: ColorRect
var cover_label: Label
var last_msg := ""

func _ready() -> void:
	preload("res://scripts/games/gin_rummy/gin_rummy_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = GinEngine.new()
	_build_ui()
	_new_match()
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
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	_build_cover()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/gin_rummy/gin_rummy_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(210, 70)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b

func _pname(p: int) -> String:
	if hotseat:
		return tr("Player %d") % (p + 1)
	return tr("You") if p == 0 else tr("The computer")

## The seat whose hand is face up on this phone.
func _me() -> int:
	return viewer if hotseat else 0

func _my_turn() -> bool:
	return engine.turn == _me() and engine.phase != "over" and not (hotseat and cover.visible)

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
	cover_label.add_theme_font_size_override("font_size", 34)
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
	cover_label.text = (last_msg + "\n\n" if last_msg != "" else "") + tr("Pass the phone to %s") % _pname(engine.turn)
	cover.visible = true
	board.queue_redraw()

func _on_cover_ready() -> void:
	cover.visible = false
	viewer = engine.turn
	selected = -1
	_refresh()

func _new_match() -> void:
	started = true
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
	_sfx("card_shuffle")
	_start_hand()

func _start_hand() -> void:
	selected = -1
	last_msg = ""
	_refresh()
	if hotseat:
		_show_cover()
		return
	if engine.turn == 1:
		cpu_timer.start()

# ---------- state -> UI ----------

func _refresh() -> void:
	var mine := GinEngine.best_melds(engine.hands[_me()])
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
	if hotseat:
		score_label.text = "%s %d  ·  %s %d   (%s)" % [_pname(0), engine.scores[0], _pname(1), engine.scores[1], tr("to %d") % GinEngine.TARGET]
	var my_turn: bool = _my_turn()
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
		status_label.text = tr("Computer's turn...") if not hotseat else ""
	elif engine.phase == "draw":
		status_label.text = tr("Draw from the stock or the discard pile.  Deadwood: %d") % mine.points
	else:
		status_label.text = tr("Select a card to discard.  Deadwood: %d") % mine.points
	board.queue_redraw()

func _result_text() -> String:
	var r: Dictionary = engine.result
	if r.get("draw", false):
		return tr("The stock ran out — this hand is a draw.")
	var who := _pname(r.winner)
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
	if not _my_turn() or selected < 0:
		return
	var card := selected
	if engine.do_discard(selected, knock):
		_sfx("card_place")
		selected = -1
		if hotseat:
			last_msg = tr("%s discarded %s.") % [_pname(1 - engine.turn), Cards.label(card)]
		_after_action()

func _after_action() -> void:
	_refresh()
	if engine.phase == "over":
		if engine.match_over():
			if hotseat:
				var w := 0 if engine.scores[0] >= GinEngine.TARGET else 1
				var msg := tr("%s wins the match!") % _pname(w)
				SaveUtil.delete(SAVE_PATH)
				if info and not result_recorded:
					result_recorded = true
					info.add("2-player games")
					info.celebrate(msg)
				end_dialog.get_meta("message_label").text = msg
				end_dialog.visible = true
				return
			var won: bool = engine.scores[0] >= GinEngine.TARGET
			end_dialog.get_meta("message_label").text = (tr("You win the match!") if won else tr("The computer wins the match.")) + _record_result("win" if won else "loss")
			end_dialog.visible = true
		return
	if hotseat:
		_show_cover()
		return
	if engine.turn == 1:
		cpu_timer.start()

func _cpu_step() -> void:
	if hotseat or engine.turn != 1 or engine.phase == "over":
		return
	if engine.phase == "draw":
		if engine.cpu_wants_discard():
			var c := engine.draw_discard()
			_sfx("card_deal")
			status_label.text = tr("Computer takes the %s.") % Cards.label(c)
		else:
			engine.draw_stock()
			_sfx("card_deal")
			status_label.text = tr("Computer draws from the stock.")
		board.queue_redraw()
		cpu_timer.start()
		return
	var choice := engine.cpu_discard()
	engine.do_discard(choice[0], choice[1])
	_sfx("card_place")
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
	if hotseat and cover.visible:
		return  # nothing on show while the phone changes hands
	var cs := _card_size()
	# the other hand: hidden until the hand ends
	var cpu_hand: Array = engine.hands[1 - _me()]
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
	board.draw_string(font, Vector2(0, 22), (_pname(1 - _me()) if hotseat else tr("Computer")) + ("" if not reveal else "  " + tr("(deadwood %d)") % GinEngine.deadwood(cpu_hand)),
		HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 22, Color(0.85, 0.9, 0.85))
	var piles := _pile_rects()
	var can_draw: bool = _my_turn() and engine.phase == "draw"
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
	if not _my_turn():
		return
	var pos: Vector2 = event.position
	if engine.phase == "draw":
		var piles := _pile_rects()
		if piles[0].has_point(pos):
			engine.draw_stock()
			_sfx("card_deal")
			_refresh()
		elif piles[1].has_point(pos):
			engine.draw_discard()
			_sfx("card_deal")
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
	SaveUtil.delete(SAVE_PATH)
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/gin_rummy/gin_rummy_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/gin_rummy/gin_rummy_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Meld your cards, knock, and race to 100 points.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🃏  New match", "sub": "vs the computer, to 100", "action": _fresh_match.bind(false)},
			{"text": "👥 2 Players", "sub": "Pass the phone; hands stay hidden", "multi": true, "action": _fresh_match.bind(true)},
		],
		"resume_text": _resume_text,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _new_match,
		"board": "Wins",
		"board_note": "Matches won against the computer.",
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
	var run := [4, 5, 6, 7]  # 5-6-7-8 of spades: a meld
	for i in run.size():
		Cards.draw_card(c, Rect2(ctr + Vector2((i - 2) * w * 0.55, -h / 2.0 + abs(i - 1.5) * 6), Vector2(w, h)), run[i])

func _fresh_match(two: bool = false) -> void:
	hotseat = two
	SaveUtil.delete(SAVE_PATH)
	_new_match()

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var sc: Array = d.get("scores", [0, 0])
	return (tr("2 Players") + "   ·   " if bool(d.get("two", false)) else "") + "%d – %d" % [int(sc[0]), int(sc[1])]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

## Mid-hand, the whole table is kept; between hands, just the match score.
func _save_game() -> void:
	if not started or engine.match_over():
		return
	if engine.phase == "over":
		SaveUtil.write(SAVE_PATH, {"scores": engine.scores, "starter": engine.starter, "between": true, "two": hotseat})
		return
	SaveUtil.write(SAVE_PATH, {"hands": engine.hands, "stock": engine.stock, "discard": engine.discard,
		"turn": engine.turn, "phase": engine.phase, "taken": engine.taken_discard, "scores": engine.scores,
		"starter": engine.starter, "two": hotseat})

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_new_match()
		return
	hotseat = bool(d.get("two", false))
	_new_match()
	engine.scores = _ints(d.scores)
	engine.starter = int(d.get("starter", 0))
	if bool(d.get("between", false)):
		engine.new_hand()
		_start_hand()
		return
	engine.hands = [_ints(d.hands[0]), _ints(d.hands[1])]
	engine.stock = _ints(d.stock)
	engine.discard = _ints(d.discard)
	engine.turn = int(d.turn)
	engine.phase = str(d.phase)
	engine.taken_discard = int(d.get("taken", -1))
	cpu_timer.stop()
	_start_hand()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
