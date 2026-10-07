extends Control

## Rummy against the computer. Draw from the stock or the discard pile, put
## down sets and runs, lay cards off on melds (yours or theirs), then discard
## one card. Go out first and score the points left in the other hand.

const RummyEngine = preload("res://scripts/games/rummy/rummy_engine.gd")
const Cards = preload("res://scripts/games/rummy/rummy_cards.gd")
const HELP = preload("res://scripts/games/rummy/rummy_help.gd")
const HomeKit = preload("res://scripts/games/rummy/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://rummy_save.json"
const CARD_ASPECT := 1.42
const CPU_DELAY := 1.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine: RummyEngine
var bg: ColorRect
var skin: String = "classic"
var started: bool = false
var result_recorded: bool = false
var busy: bool = false
var selected: Array = []
var message: String = ""
var meld_rects: Array = []     # Rect2 of each meld on the table, from the last draw
var stock_rect: Rect2
var discard_rect: Rect2
var table: Control
var hand_view: Control
var status_label: Label
var meld_btn: Button
var discard_btn: Button
var timer: Timer
var round_dialog: ColorRect
var round_next: Callable

func _ready() -> void:
	preload("res://scripts/games/rummy/rummy_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = RummyEngine.new()
	engine.new_match()
	_build_ui()
	started = false
	_render()
	_calm_music()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _calm_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 3, 2.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.felt_dark if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	Cards.classic = skin == "classic"
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
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🃏 Rummy")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	table = Control.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.mouse_filter = Control.MOUSE_FILTER_STOP
	table.draw.connect(_draw_table)
	table.gui_input.connect(_on_table_input)
	table.resized.connect(table.queue_redraw)
	root.add_child(table)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 66)
	root.add_child(status_label)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_left", 16)
	bm.add_theme_constant_override("margin_right", 16)
	root.add_child(bm)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 12)
	bm.add_child(brow)
	meld_btn = Button.new()
	meld_btn.text = tr("🃏 Meld")
	meld_btn.custom_minimum_size = Vector2(0, 68)
	meld_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meld_btn.add_theme_font_size_override("font_size", 26)
	meld_btn.pressed.connect(_on_meld)
	brow.add_child(meld_btn)
	discard_btn = Button.new()
	discard_btn.text = tr("🗑 Discard")
	discard_btn.custom_minimum_size = Vector2(0, 68)
	discard_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_btn.add_theme_font_size_override("font_size", 26)
	discard_btn.pressed.connect(_on_discard)
	brow.add_child(discard_btn)

	hand_view = Control.new()
	hand_view.custom_minimum_size = Vector2(0, 175)
	hand_view.mouse_filter = Control.MOUSE_FILTER_STOP
	hand_view.draw.connect(_draw_hand)
	hand_view.gui_input.connect(_on_hand_input)
	hand_view.resized.connect(hand_view.queue_redraw)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_bottom", 22)
	hm.add_child(hand_view)
	root.add_child(hm)

	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timer)
	add_child(timer)

	round_dialog = UI.build_dialog("", [
		{"text": tr("Next hand"), "action": _on_round_button},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(round_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.PINK,
		"solo_heading": "vs Computer",
		"subtitle": "Draw, meld, lay off and discard. Go out first.",
		"logo": _draw_home_logo,
		"modes": [{"text": "🃏 " + tr("New match"), "sub": "First to 100 points", "action": _new_match}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Wins",
		"board_note": "Matches won against the computer.",
	})
	add_child(home)
	if info:
		add_child(info)

# ---------- game flow ----------

func _new_match() -> void:
	SaveUtil.delete(SAVE_PATH)
	_restart()

func _restart() -> void:
	engine.new_match()
	_begin_hand()

func _begin_hand() -> void:
	started = true
	result_recorded = false
	busy = false
	selected = []
	message = ""
	timer.stop()
	round_dialog.visible = false
	_sfx("card_shuffle")
	_render()
	_advance()

func _advance() -> void:
	if engine.phase == "over":
		_end_hand()
		return
	if engine.turn == 1 and not busy:
		busy = true
		timer.start(CPU_DELAY)
	_render()

func _on_timer() -> void:
	busy = false
	if not started or engine.phase == "over" or engine.turn != 1:
		return
	var steps := engine.cpu_turn()
	_sfx("card_place")
	message = _describe_cpu(steps)
	selected = []
	_advance()

func _describe_cpu(steps: Array) -> String:
	var parts: Array = []
	if steps.has("discard"):
		parts.append(tr("took the discard"))
	elif steps.has("stock"):
		parts.append(tr("drew from the stock"))
	var melds_n: int = steps.count("meld")
	if melds_n > 0:
		parts.append(tr("put down %d meld(s)") % melds_n)
	var lay: int = steps.count("layoff")
	if lay > 0:
		parts.append(tr("laid off %d card(s)") % lay)
	if engine.phase != "over" and not engine.discard.is_empty():
		parts.append(tr("discarded %s") % Cards.label(engine.discard[engine.discard.size() - 1]))
	return tr("Computer") + ": " + ", ".join(parts) + "."

func _my_turn() -> bool:
	return started and not busy and engine.turn == 0 and engine.phase != "over"

func _on_table_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _my_turn():
		return
	if engine.phase == "draw":
		if stock_rect.has_point(event.position) and engine.can_draw_stock():
			engine.draw_stock(0)
			_sfx("card_deal")
			message = ""
			_after_draw()
		elif discard_rect.has_point(event.position) and not engine.discard.is_empty():
			engine.draw_discard(0)
			_sfx("card_flip")
			message = ""
			_after_draw()
		return
	# lay off the selected cards on the tapped meld
	for i in meld_rects.size():
		if meld_rects[i].has_point(event.position):
			_try_lay_off(i)
			return

func _after_draw() -> void:
	selected = []
	if engine.phase == "over":
		_advance()
		return
	_render()
	_save_game()

func _try_lay_off(index: int) -> void:
	if selected.is_empty():
		message = tr("Select a card first, then tap a meld to add it.")
		_render()
		return
	var done := 0
	for c in selected.duplicate():
		if engine.lay_off(0, c, index):
			done += 1
			selected.erase(c)
			if engine.phase == "over":
				break
	if done == 0:
		_sfx("invalid")
		message = tr("That card doesn't fit this meld.")
	else:
		_sfx("card_place")
		message = ""
	if engine.phase == "over":
		_advance()
		return
	_render()
	_save_game()

func _on_hand_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _my_turn() or engine.phase != "play":
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		if rects[i].has_point(event.position):
			var c: int = engine.hands[0][i]
			if c in selected:
				selected.erase(c)
			else:
				selected.append(c)
			_sfx("toggle")
			message = ""
			_render()
			return

func _on_meld() -> void:
	if not _my_turn() or engine.phase != "play":
		return
	if engine.meld(0, selected.duplicate()):
		selected = []
		message = ""
		_sfx("card_place")
		if engine.phase == "over":
			_advance()
			return
		_render()
		_save_game()
	else:
		_sfx("invalid")
		message = tr("Those cards don't make a set or a run.")
		_render()

func _on_discard() -> void:
	if not _my_turn() or engine.phase != "play" or selected.size() != 1:
		return
	if not engine.do_discard(0, selected[0]):
		_sfx("invalid")
		message = tr("You can't discard the card you just took.")
		_render()
		return
	selected = []
	message = ""
	_sfx("card_place")
	_save_game()
	_advance()

func _end_hand() -> void:
	started = false
	var w: int = engine.winner
	var msg := ""
	if w == 0:
		msg = tr("You went out! +%d") % engine.hand_points
		if info:
			info.add("Hands won")
	elif w == 1:
		msg = tr("The computer went out. +%d for the computer") % engine.hand_points
	else:
		msg = tr("The stock ran out — nobody scores.")
	msg += "\n\n" + tr("You: %d    Computer: %d") % [engine.scores[0], engine.scores[1]]
	if engine.match_over():
		SaveUtil.delete(SAVE_PATH)
		var won: bool = engine.scores[0] >= RummyEngine.TARGET and engine.scores[0] >= engine.scores[1]
		msg = (tr("You win the match!") if won else tr("The computer wins the match.")) + "\n\n" + msg
		if info and not result_recorded:
			result_recorded = true
			info.result("win" if won else "loss")
		_set_round_button(tr("Play Again"))
		round_next = _restart
	else:
		_set_round_button(tr("Next hand"))
		round_next = _next_hand
	round_dialog.get_meta("message_label").text = msg
	round_dialog.visible = true
	_render()

func _next_hand() -> void:
	engine.next_hand()
	_begin_hand()

func _set_round_button(t: String) -> void:
	for b in round_dialog.find_children("*", "Button", true, false):
		if b.text == tr("Next hand") or b.text == tr("Play Again"):
			b.text = t

func _on_round_button() -> void:
	if round_next.is_valid():
		round_next.call()

# ---------- drawing ----------

func _render() -> void:
	var can_meld := false
	if _my_turn() and engine.phase == "play" and selected.size() >= 3:
		can_meld = RummyEngine.classify(selected) != ""
	meld_btn.disabled = not can_meld
	discard_btn.disabled = not (_my_turn() and engine.phase == "play" and selected.size() == 1)
	if engine.phase == "over" or not started:
		status_label.text = message
	elif engine.turn == 1:
		status_label.text = tr("The computer is playing...")
	elif engine.phase == "draw":
		status_label.text = (message + "
" if message != "" else "") + tr("Your turn — draw from the stock or the discard pile.")
	else:
		status_label.text = message if message != "" else tr("Select cards to meld or lay off, then discard one card to finish.")
	table.queue_redraw()
	hand_view.queue_redraw()

func _draw_table() -> void:
	if engine == null:
		return
	var font := ThemeDB.fallback_font
	var s := table.size
	# the computer
	var n1: int = engine.hands[1].size()
	table.draw_string(font, Vector2(14, 28), "🤖 " + tr("Computer"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, HomeKit.GOLD if engine.turn == 1 else Color(1, 1, 1, 0.8))
	table.draw_string(font, Vector2(14, 56), tr("%d cards   Score %d") % [n1, engine.scores[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
	var bw: float = 34.0
	for i in n1:
		Cards.draw_card(table, Rect2(Vector2(s.x - 20 - bw - i * 14.0, 8), Vector2(bw, bw * CARD_ASPECT)), 0, false)
	table.draw_string(font, Vector2(14, s.y - 8), tr("You   Score %d") % engine.scores[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, HomeKit.GOLD if engine.turn == 0 else Color(1, 1, 1, 0.8))
	# the melds on the table
	meld_rects = []
	var area := Rect2(10, 76, s.x - 20, s.y - 76 - 150)
	var mcw := 44.0
	var layout: Array = []
	var rows := 1
	for attempt in 8:
		layout = []
		var mch: float = mcw * CARD_ASPECT
		var x := area.position.x
		var y := area.position.y
		rows = 1
		for m in engine.melds:
			var w: float = mcw + (m.cards.size() - 1) * mcw * 0.52
			if x + w > area.end.x and x > area.position.x:
				x = area.position.x
				y += mch + 12.0
				rows += 1
			layout.append(Rect2(x, y, w, mch))
			x += w + 14.0
		if y + mch <= area.end.y or mcw <= 26.0:
			break
		mcw -= 4.0
	var accent_marks := _meld_hints()
	for i in engine.melds.size():
		var m: Dictionary = engine.melds[i]
		var r: Rect2 = layout[i]
		meld_rects.append(r.grow(4.0))
		var cw: float = mcw
		for k in m.cards.size():
			var cr := Rect2(r.position + Vector2(k * cw * 0.52, 0), Vector2(cw, cw * CARD_ASPECT))
			Cards.draw_card(table, cr, m.cards[k], true, accent_marks.has(i))
		table.draw_rect(Rect2(r.position.x, r.end.y + 2.0, r.size.x, 3.0), HomeKit.CYAN if m.owner == 0 else HomeKit.PINK)
	if engine.melds.is_empty():
		table.draw_string(font, Vector2(0, area.position.y + 40), tr("Melds go here"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 22, Color(1, 1, 1, 0.35))
	# stock and discard piles
	var pw: float = minf(86.0, s.x * 0.2)
	var ph: float = pw * CARD_ASPECT
	var py: float = s.y - ph - 36.0
	stock_rect = Rect2(Vector2(s.x / 2.0 - pw - 24.0, py), Vector2(pw, ph))
	discard_rect = Rect2(Vector2(s.x / 2.0 + 24.0, py), Vector2(pw, ph))
	var can_draw: bool = _my_turn() and engine.phase == "draw"
	if engine.stock.is_empty():
		Cards.draw_card(table, stock_rect, -1, true, false)
	else:
		Cards.draw_card(table, stock_rect, 0, false, can_draw)
	if engine.discard.is_empty():
		Cards.draw_card(table, discard_rect, -1, true, false)
	else:
		Cards.draw_card(table, discard_rect, engine.discard[engine.discard.size() - 1], true, can_draw)
	table.draw_string(font, Vector2(stock_rect.position.x, py + ph + 24), tr("Stock %d") % engine.stock.size(), HORIZONTAL_ALIGNMENT_CENTER, pw, 18, Color(1, 1, 1, 0.7))
	table.draw_string(font, Vector2(discard_rect.position.x, py + ph + 24), tr("Discard"), HORIZONTAL_ALIGNMENT_CENTER, pw, 18, Color(1, 1, 1, 0.7))

## Melds the selected cards could be added to (they glow).
func _meld_hints() -> Array:
	var out: Array = []
	if not _my_turn() or engine.phase != "play" or selected.is_empty():
		return out
	for i in engine.melds.size():
		for c in selected:
			if engine.can_lay_off(c, engine.melds[i]):
				out.append(i)
				break
	return out

func _hand_rects() -> Array:
	var n: int = engine.hands[0].size()
	var out: Array = []
	if n == 0:
		return out
	var cw: float = minf(104.0, hand_view.size.y / CARD_ASPECT - 8.0)
	var ch := cw * CARD_ASPECT
	var step: float = minf(cw * 0.78, (hand_view.size.x - 24.0 - cw) / maxf(1.0, n - 1))
	var x0: float = (hand_view.size.x - (step * (n - 1) + cw)) / 2.0
	for i in n:
		out.append(Rect2(Vector2(x0 + i * step, hand_view.size.y - ch), Vector2(cw, ch)))
	return out

func _draw_hand() -> void:
	var rects := _hand_rects()
	var playing: bool = _my_turn() and engine.phase == "play"
	for i in rects.size():
		var c: int = engine.hands[0][i]
		var r: Rect2 = rects[i]
		var sel: bool = c in selected
		if sel:
			r.position.y -= 18
		var locked: bool = c == engine.drew_discard and engine.phase == "play"
		Cards.draw_card(hand_view, r, c, true, sel, false)
		if locked and playing:
			hand_view.draw_circle(r.position + Vector2(r.size.x - 12, 12), 6.0, HomeKit.GOLD)

func _draw_home_logo(c: Control) -> void:
	var w := minf(c.size.y * 0.42, 60.0)
	var h := w * CARD_ASPECT
	var o := c.size / 2.0
	var cards := [4 - 1, 13 + 4 - 1, 26 + 4 - 1, 39 + 4 - 1]
	for k in 4:
		var r := Rect2(o + Vector2((k - 1.5) * w * 0.7 - w / 2.0, -h / 2.0 + absf(k - 1.5) * 6.0), Vector2(w, h))
		Cards.draw_card(c, r, cards[k], true, k == 1)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.phase == "over" or engine.match_over():
		return
	SaveUtil.write(SAVE_PATH, engine.to_dict())

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var sc: Array = d.get("scores", [0, 0])
	return tr("You %d — Computer %d") % [int(sc[0]), int(sc[1])]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d) or engine.phase == "over":
		_restart()
		return
	started = true
	result_recorded = false
	busy = false
	selected = []
	message = ""
	round_dialog.visible = false
	_render()
	_advance()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
