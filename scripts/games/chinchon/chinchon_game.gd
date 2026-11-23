extends Control

## Chinchón vs the computer, Spanish cards. Draw from the deck or the discard pile, then tap a card
## to throw it. When your seven cards have 5 points or less outside groups, tap "Close" and then the
## card to throw: the hand ends. Reach 100 points and you lose the match.
## Landing menu style: S6 Stone Slabs (docs/MENU_STYLES.md).

const MenuStyles = preload("res://scripts/games/chinchon/menu_styles.gd")
const ChinchonEngine = preload("res://scripts/games/chinchon/chinchon_engine.gd")
const HomeKit = preload("res://scripts/games/chinchon/home_kit.gd")
const Cards = preload("res://scripts/games/chinchon/chinchon_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const HELP = preload("res://scripts/games/chinchon/chinchon_help.gd")
## Not preloaded: apps before v0.20 don't have it, and the game must still run there.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SAVE_PATH := "user://chinchon_save.json"

var info = null
var home
var engine: ChinchonEngine
var board: Control
var status_label: Label
var score_label: Label
var close_btn: Button
var round_dialog: ColorRect
var end_dialog: ColorRect
var cpu_timer: Timer
var font: Font
var started := false
var result_recorded := false
var skill := 1
var last_msg := ""
var close_armed := false
var shown: Array = []        # my hand in display order: groups first, then loose cards
var group_of: Array = []     # group index per shown card (-1 = loose)
var loose_points := 0
var skin: String = "classic"
var bg: ColorRect

func _ready() -> void:
	preload("res://scripts/games/chinchon/chinchon_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = ChinchonEngine.new()
	_build_ui()
	engine.new_game()
	_update()
	started = false

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.felt_dark if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	Cards.classic = skin == "classic"
	for n in find_children("*", "CanvasItem", true, false):
		n.queue_redraw()

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
	var pause := Button.new()
	pause.text = "⏸"
	pause.custom_minimum_size = Vector2(76, 64)
	pause.add_theme_font_size_override("font_size", 30)
	pause.pressed.connect(_on_pause_home)
	bar.add_child(pause)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(score_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 70)
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 48)
	sm.add_theme_constant_override("margin_right", 48)
	sm.add_child(status_label)
	root.add_child(sm)
	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 26)
	root.add_child(bm)
	close_btn = Button.new()
	close_btn.text = tr("🔒 Close")
	close_btn.custom_minimum_size = Vector2(260, 70)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(_h_close_toggle)
	bm.add_child(close_btn)
	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 1.1
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)
	round_dialog = UI.build_dialog("", [{"text": tr("Next hand"), "action": _next_round}], true)
	add_child(round_dialog)
	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _build_home() -> void:
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S6 Stone Slabs; burgundy + gold.
		"landing": "slabs",
		"landing_style": MenuStyles,
		"title_colors": [Color("ffd23c"), Color("ffffff"), Color("ff6b6b")],
		"landing_colors": [Color("2a0810"), Color("5c1424")],
		"menu_color": Color("ffd23c"),
		"help": HELP,
		"info": info,
		"accent": HomeKit.PINK,
		"subtitle": "Make groups, close the hand, stay under 100. You vs the computer.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🃏  Play", "sub": "match to 100 points", "key": "normal", "action": _new_game.bind(1)},
			{"text": "Easy", "row": "level", "color": HomeKit.LIME, "action": _new_game.bind(0)},
			{"text": "Hard", "row": "level", "color": HomeKit.PINK, "action": _new_game.bind(2)},
		],
		"solo_heading": "vs Computer",
		"resume_text": _resume_text,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _restart,
		"helps": [{"text": "💡 Hint", "how": "Draws for you if you have not yet, then throws the best card.", "action": _help_play}],
		"board": "Wins",
		"board_note": "Matches won.",
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
	var specs := [[-0.35, Cards.make(0, 5)], [0.0, Cards.make(0, 6)], [0.35, Cards.make(0, 7)]]
	for spec in specs:
		c.draw_set_transform(ctr + Vector2(spec[0] * w * 1.1, abs(spec[0]) * h * 0.18), spec[0], Vector2.ONE)
		Cards.draw_card(c, Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)), spec[1])
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------- flow ----------

func _new_game(level: int = -1) -> void:
	if level >= 0:
		skill = level
	SaveUtil.delete(SAVE_PATH)
	_restart()

func _restart() -> void:
	started = true
	result_recorded = false
	cpu_timer.stop()
	engine.new_game()
	_sfx("card_shuffle")
	last_msg = ""
	close_armed = false
	round_dialog.visible = false
	end_dialog.visible = false
	_update()

func _next_round() -> void:
	round_dialog.visible = false
	engine.new_round()
	_sfx("card_shuffle")
	last_msg = ""
	close_armed = false
	_update()

func _my_turn() -> bool:
	return engine.winner == -1 and not engine.round_over and engine.turn == 0

## Orders my hand: groups together, loose cards last (and remembers their points).
func _arrange() -> void:
	shown = []
	group_of = []
	loose_points = 0
	var hand: Array = engine.hands[0]
	if hand.is_empty():
		return
	var bm: Dictionary = ChinchonEngine.best_melds(hand)
	var gi := 0
	for g in bm.melds:
		var cs: Array = g.duplicate()
		cs.sort()
		for c in cs:
			shown.append(c)
			group_of.append(gi)
		gi += 1
	var rest: Array = bm.dead.duplicate()
	rest.sort()
	for c in rest:
		shown.append(c)
		group_of.append(-1)
	loose_points = int(bm.points)

func _update() -> void:
	score_label.text = tr("You %d  ·  %d CPU   (limit %d)") % [engine.score[0], engine.score[1], ChinchonEngine.LIMIT]
	_arrange()
	var can_close := false
	if _my_turn() and engine.phase == "discard":
		for c in engine.hands[0]:
			if engine.can_close(0, c):
				can_close = true
				break
	if not can_close:
		close_armed = false
	close_btn.visible = can_close
	close_btn.text = tr("✔ Tap the card to throw") if close_armed else tr("🔒 Close")
	if _my_turn():
		var tip := tr("Draw from the deck or the discard pile.") if engine.phase == "draw" else (tr("Throw a card to close the hand.") if close_armed else tr("Tap a card to throw it."))
		status_label.text = last_msg + ("\n" if last_msg != "" else "") + tip
	else:
		status_label.text = last_msg
	board.queue_redraw()
	if engine.winner != -1:
		_game_over()
	elif engine.round_over:
		_round_over()
	elif engine.turn == 1:
		cpu_timer.start()

# ---------- the player ----------

func _h_draw_stock() -> void:
	if engine.draw_stock(0) == -1:
		return
	_sfx("card_deal")
	last_msg = ""
	_update()

func _h_draw_discard() -> void:
	var c := engine.draw_discard(0)
	if c == -1:
		return
	_sfx("card_deal")
	last_msg = tr("You take %s.") % Cards.label(c)
	_update()

func _h_throw(card: int) -> void:
	if close_armed:
		if engine.close(0, card):
			_sfx("card_place")
			last_msg = tr("You close the hand.")
			if info:
				info.add("Hands closed")
			close_armed = false
			_update()
		return
	if engine.throw(0, card):
		_sfx("card_place")
		last_msg = tr("You throw %s.") % Cards.label(card)
		_update()

func _h_close_toggle() -> void:
	close_armed = not close_armed
	_update()

# ---------- the computer ----------

func _cpu_turn() -> void:
	if engine.turn != 1 or engine.round_over or engine.winner != -1:
		return
	var msg := ""
	if engine.cpu_take_discard(1):
		var top: int = engine.discard.back()
		engine.draw_discard(1)
		msg = tr("CPU takes %s.") % Cards.label(top)
	else:
		if engine.draw_stock(1) == -1:
			engine.draw_discard(1)
		msg = tr("CPU draws from the deck.")
	var f: Dictionary = engine.cpu_finish(1, skill)
	_sfx("card_place")
	if f.close:
		engine.close(1, f.card)
		last_msg = msg + " " + tr("CPU closes the hand.")
	else:
		engine.throw(1, f.card)
		last_msg = msg + " " + tr("CPU throws %s.") % Cards.label(f.card)
	_update()

# ---------- ends ----------

func _round_over() -> void:
	cpu_timer.stop()
	SaveUtil.delete(SAVE_PATH)
	var r: Dictionary = engine.result
	var lines: Array = []
	if r.chinchon:
		lines.append(tr("Chinchón!") + " " + (tr("You win the match.") if r.closer == 0 else tr("The computer wins the match.")))
	else:
		lines.append((tr("You closed the hand.") if r.closer == 0 else tr("The computer closed the hand.")) + (" " + tr("Clean close: -10") if r.clean else ""))
		lines.append(tr("Loose points: you %d, CPU %d") % [r.dead[0], r.dead[1]])
		lines.append(tr("Score: you %d, CPU %d") % [engine.score[0], engine.score[1]])
	round_dialog.get_meta("message_label").text = "\n".join(lines)
	round_dialog.get_meta("message_label").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if engine.winner == -1:
		round_dialog.visible = true

func _game_over() -> void:
	cpu_timer.stop()
	round_dialog.visible = false
	SaveUtil.delete(SAVE_PATH)
	var won: bool = engine.winner == 0
	var r: Dictionary = engine.result
	var msg := tr("You win the match!") if won else tr("The computer wins the match.")
	if r.get("chinchon", false):
		msg = tr("Chinchón!") + " " + msg
		if won and info:
			info.add("Chinchones")
	msg += "\n" + tr("Score: you %d, CPU %d") % [engine.score[0], engine.score[1]]
	if info and not result_recorded:
		result_recorded = true
		info.result("win" if won else "loss")
		msg += "\n" + info.summary()
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _card_size() -> Vector2:
	var w: float = minf(92.0, (board.size.x - 16.0) / 7.6)
	return Vector2(w, w * 1.45)

func _hand_rects() -> Array:
	var cs := _card_size()
	var n := shown.size()
	var out: Array = []
	var step: float = minf(cs.x + 4.0, (board.size.x - 16.0 - cs.x) / maxf(1.0, n - 1.0))
	var extra := 10.0
	var gaps := 0
	for i in range(1, n):
		if group_of[i] != group_of[i - 1]:
			gaps += 1
	var total: float = step * (n - 1) + cs.x + extra * gaps
	if total > board.size.x - 12.0 and n > 1:
		step = maxf(8.0, (board.size.x - 12.0 - cs.x - extra * gaps) / (n - 1))
		total = step * (n - 1) + cs.x + extra * gaps
	var x := (board.size.x - total) / 2.0
	var y := board.size.y - cs.y - 8.0
	for i in n:
		if i > 0 and group_of[i] != group_of[i - 1]:
			x += extra
		out.append(Rect2(Vector2(x, y), cs))
		x += step
	return out

func _piles() -> Array:
	var cs := _card_size()
	var y := board.size.y * 0.3
	return [Rect2(Vector2(board.size.x / 2.0 - cs.x - 20, y), cs), Rect2(Vector2(board.size.x / 2.0 + 20, y), cs)]

func _draw_board() -> void:
	if engine.hands.is_empty():
		return
	var cs := _card_size()
	var small := cs * 0.55
	var n1: int = engine.hands[1].size()
	var reveal := engine.round_over
	var spread: float = minf(small.x * (1.05 if reveal else 0.45), (board.size.x - 40.0) / maxf(1.0, n1))
	var x0 := (board.size.x - (spread * (n1 - 1) + small.x)) / 2.0
	for k in n1:
		var rr := Rect2(Vector2(x0 + k * spread, 34), small)
		if reveal:
			Cards.draw_card(board, rr, engine.hands[1][k])
		else:
			Cards.draw_card(board, rr, 0, false)
	board.draw_string(font, Vector2(8, 24), tr("CPU"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.95, 1))
	var piles := _piles()
	var can_draw: bool = _my_turn() and engine.phase == "draw"
	if engine.stock.is_empty() and engine.discard.size() <= 1:
		Cards.draw_card(board, piles[0], -1, true, can_draw)
	else:
		Cards.draw_card(board, piles[0], 0, false, can_draw)
	if not engine.discard.is_empty():
		Cards.draw_card(board, piles[1], engine.discard.back(), true, can_draw)
	else:
		Cards.draw_card(board, piles[1], -1, true)
	board.draw_string(font, Vector2(piles[0].position.x, piles[0].end.y + 22), tr("Deck"), HORIZONTAL_ALIGNMENT_CENTER, piles[0].size.x, 18, Color(0.9, 0.95, 1))
	board.draw_string(font, Vector2(piles[1].position.x, piles[1].end.y + 22), tr("Discard"), HORIZONTAL_ALIGNMENT_CENTER, piles[1].size.x, 18, Color(0.9, 0.95, 1))
	var rects := _hand_rects()
	var thrower: bool = _my_turn() and engine.phase == "discard"
	for i in rects.size():
		var c: int = shown[i]
		var ok := thrower and engine.can_discard(0, c)
		if close_armed:
			ok = ok and engine.can_close(0, c)
		var r: Rect2 = rects[i]
		if group_of[i] >= 0:
			r.position.y -= 10.0       # grouped cards sit a little higher
		Cards.draw_card(board, r, c, true, ok, thrower and not ok)
	if not shown.is_empty():
		board.draw_string(font, Vector2(8, board.size.y - cs.y - 26), tr("Loose points: %d") % loose_points, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.85, 0.35))

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _my_turn():
		return
	var pos: Vector2 = event.position
	if engine.phase == "draw":
		var piles := _piles()
		if piles[0].has_point(pos):
			_h_draw_stock()
		elif piles[1].has_point(pos):
			_h_draw_discard()
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		var r: Rect2 = rects[i]
		if group_of[i] >= 0:
			r.position.y -= 10.0
		if r.has_point(pos):
			_h_throw(shown[i])
			return

# ---------- save / resume ----------

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	return tr("%d – %d") % [int(d.score[0]), int(d.score[1])]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

## Saved on the player's turn (the computer's turns replay from there).
func _save_game() -> void:
	if not started or not _my_turn():
		return
	var d := engine.to_dict()
	d["skill"] = skill
	SaveUtil.write(SAVE_PATH, d)

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_restart()
		return
	started = true
	result_recorded = false
	skill = int(d.get("skill", 1))
	engine.from_dict(d)
	close_armed = false
	round_dialog.visible = false
	end_dialog.visible = false
	last_msg = ""
	_update()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

# ---------- helps (STANDARDS §17) ----------

func _help_play() -> bool:
	if not _my_turn():
		return false
	if engine.phase == "draw":
		if engine.cpu_take_discard(0):
			_h_draw_discard()
		else:
			_h_draw_stock()
	var c := engine.best_throw(0)
	if c == -1:
		return true
	close_armed = false
	_h_throw(c)
	return true
