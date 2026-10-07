extends Control

## Sevens (Fan Tan) against three computer players: West (on your left), North
## and East. The 7♦ starts; then 7s open suits and everyone builds up and
## down from them. No playable card: you pass. First to play all 13 wins.

const SevensEngine = preload("res://scripts/games/sevens/sevens_engine.gd")
const Cards = preload("res://scripts/games/sevens/sevens_cards.gd")
const HELP = preload("res://scripts/games/sevens/sevens_help.gd")
const HomeKit = preload("res://scripts/games/sevens/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://sevens_save.json"
const SEATS := ["You", "West", "North", "East"]
const ROW_SUITS := [0, 1, 3, 2]     # top to bottom: ♠ ♥ ♣ ♦
const CARD_ASPECT := 1.42
const CPU_DELAY := 0.6

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine: SevensEngine
var rng := RandomNumberGenerator.new()
var bg: ColorRect
var skin: String = "classic"
var started: bool = false
var result_recorded: bool = false
var busy: bool = false
var table: Control
var hand_view: Control
var status_label: Label
var timer: Timer
var end_dialog: ColorRect

func _ready() -> void:
	preload("res://scripts/games/sevens/sevens_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = SevensEngine.new()
	engine.new_game(1, rng)
	_build_ui()
	started = false
	_render()
	_calm_music()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _calm_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 2, 2.0)

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
	title.text = tr("7️⃣ Sevens")
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
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.draw.connect(_draw_table)
	table.resized.connect(table.queue_redraw)
	root.add_child(table)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	hand_view = Control.new()
	hand_view.custom_minimum_size = Vector2(0, 190)
	hand_view.mouse_filter = Control.MOUSE_FILTER_STOP
	hand_view.draw.connect(_draw_hand)
	hand_view.gui_input.connect(_on_hand_input)
	hand_view.resized.connect(hand_view.queue_redraw)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_bottom", 24)
	hm.add_child(hand_view)
	root.add_child(hm)

	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timer)
	add_child(timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in 3:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "sub": "You and three computers", "row": "lvl", "action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Open the suits from the sevens. Be first to play every card.",
		"logo": _draw_home_logo,
		"modes": modes,
		"solo_heading": "vs Computer",
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Wins",
		"board_note": "Games won against the computers.",
	})
	add_child(home)
	if info:
		add_child(info)

# ---------- game flow ----------

func _new_game(level: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_game(level, rng)
	_begin()

func _restart() -> void:
	_new_game(engine.level)

func _begin() -> void:
	started = true
	result_recorded = false
	busy = false
	timer.stop()
	end_dialog.visible = false
	_sfx("card_shuffle")
	_render()
	_advance()

func _advance() -> void:
	if busy:
		_render()
		return
	if engine.winner >= 0:
		_end_game()
		return
	if engine.turn != 0 or engine.legal(0).is_empty():
		busy = true
		timer.start(CPU_DELAY if engine.turn != 0 else 1.2)
	_render()

func _on_timer() -> void:
	busy = false
	if engine.winner >= 0 or not started:
		return
	var p: int = engine.turn
	if p == 0:
		if engine.legal(0).is_empty():
			engine.pass_turn(0)
			_sfx("invalid")
	else:
		var c := engine.cpu_play(p)
		if c < 0:
			engine.pass_turn(p)
			_sfx("tick")
		else:
			engine.play(p, c)
			_sfx("card_place")
	_advance()

func _on_hand_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not started or busy or engine.turn != 0 or engine.winner >= 0:
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		if not rects[i].has_point(event.position):
			continue
		var c: int = engine.hands[0][i]
		if engine.play(0, c):
			_sfx("card_place")
			_advance()
		else:
			_sfx("invalid")
		return

func _end_game() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var w: int = engine.winner
	var lines: Array = []
	for p in 4:
		if p == w:
			lines.append("%s: %s" % [tr(SEATS[p]), tr("out of cards")])
		else:
			lines.append("%s: %s" % [tr(SEATS[p]), tr("%d points left") % engine.hand_points(p)])
	var msg := (tr("You win!") if w == 0 else tr("%s wins.") % tr(SEATS[w])) + "\n\n" + "\n".join(lines)
	if info and not result_recorded:
		result_recorded = true
		info.result("win" if w == 0 else "loss")
		if w == 0 and engine.passes[0] == 0:
			info.add("Wins without passing")
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_render()

# ---------- drawing ----------

func _render() -> void:
	if engine.winner >= 0:
		status_label.text = ""
	elif busy and engine.turn == 0:
		status_label.text = tr("No playable card — you pass.")
	elif engine.turn == 0:
		status_label.text = tr("Your turn — tap a glowing card.")
		if engine.table_empty():
			status_label.text = tr("You have the 7♦ — start with it.")
	else:
		status_label.text = tr("%s is playing...") % tr(SEATS[engine.turn])
	table.queue_redraw()
	hand_view.queue_redraw()

func _grid() -> Dictionary:
	var s := table.size
	var top_h := 86.0
	var slot: float = (s.x - 16.0) / 13.0
	var cw: float = slot - 4.0
	var ch: float = cw * CARD_ASPECT
	var row_h: float = minf(ch + 8.0, (s.y - top_h - 8.0) / 4.0)
	ch = row_h - 8.0
	cw = minf(cw, ch / CARD_ASPECT)
	var spare: float = maxf(0.0, (s.y - top_h - 8.0 - row_h * 4.0) / 2.0)
	return {"top": top_h + spare, "slot": slot, "cw": cw, "ch": ch, "row_h": row_h, "x0": 8.0}

func _draw_table() -> void:
	if engine == null:
		return
	var font := ThemeDB.fallback_font
	var s := table.size
	var g := _grid()
	# The three computers: card count, passes, and whose turn it is.
	for p in range(1, 4):
		var cx: float = s.x * (0.17 + (p - 1) * 0.33)
		var col: Color = HomeKit.GOLD if engine.turn == p and engine.winner < 0 else (Color(1, 1, 1, 0.8) if _is_classic() else HomeKit.DIM)
		table.draw_string(font, Vector2(cx - 90, 28), "🤖 %s" % tr(SEATS[p]), HORIZONTAL_ALIGNMENT_CENTER, 180, 24, col)
		table.draw_string(font, Vector2(cx - 90, 58), tr("%d cards  ·  %d passes") % [engine.hands[p].size(), engine.passes[p]],
			HORIZONTAL_ALIGNMENT_CENTER, 180, 19, Color(1, 1, 1, 0.65))
	for row in 4:
		var suit: int = ROW_SUITS[row]
		var y: float = g.top + row * g.row_h
		for r in range(1, 14):
			var card: int = suit * 13 + r - 1
			var rect := Rect2(Vector2(g.x0 + (r - 1) * g.slot + (g.slot - g.cw) / 2.0, y), Vector2(g.cw, g.ch))
			if engine.on_table(card):
				Cards.draw_card(table, rect, card, true, false)
			else:
				Cards.draw_card(table, rect, -1, true, r == 7 and engine.high[suit] == 0)

func _hand_rects() -> Array:
	var n: int = engine.hands[0].size()
	var out: Array = []
	if n == 0:
		return out
	var cw: float = minf(110.0, hand_view.size.y / CARD_ASPECT)
	var ch := cw * CARD_ASPECT
	var step: float = minf(cw * 0.75, (hand_view.size.x - 24.0 - cw) / maxf(1.0, n - 1))
	var x0: float = (hand_view.size.x - (step * (n - 1) + cw)) / 2.0
	for i in n:
		out.append(Rect2(Vector2(x0 + i * step, hand_view.size.y - ch), Vector2(cw, ch)))
	return out

func _draw_hand() -> void:
	var rects := _hand_rects()
	var mine: bool = started and engine.turn == 0 and not busy and engine.winner < 0
	var legal: Array = engine.legal(0) if mine else []
	for i in rects.size():
		var c: int = engine.hands[0][i]
		var r: Rect2 = rects[i]
		var glow: bool = c in legal
		if glow:
			r.position.y -= 14
		Cards.draw_card(hand_view, r, c, true, glow, mine and not glow)

func _draw_home_logo(c: Control) -> void:
	var w := minf(c.size.y * 0.42, 60.0)
	var h := w * CARD_ASPECT
	var o := c.size / 2.0
	var cards := [13 + 5, 26 + 6, 6, 39 + 7]
	for k in 4:
		var r := Rect2(o + Vector2((k - 1.5) * w * 0.8 - w / 2.0, -h / 2.0 + absf(k - 1.5) * 6.0), Vector2(w, h))
		Cards.draw_card(c, r, cards[k], true, k == 1)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.winner >= 0:
		return
	SaveUtil.write(SAVE_PATH, {"hands": engine.hands, "low": engine.low, "high": engine.high, "turn": engine.turn,
		"passes": engine.passes, "level": engine.level, "plays": engine.plays})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var hands: Array = d.get("hands", [])
	return tr("You: %d cards left") % (Array(hands[0]).size() if hands.size() == 4 else 13)

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or d.get("hands", []).size() != 4:
		_new_game(1)
		return
	engine.hands = []
	for h in d.hands:
		engine.hands.append(_ints(h))
	engine.low = _ints(d.get("low", [0, 0, 0, 0]))
	engine.high = _ints(d.get("high", [0, 0, 0, 0]))
	engine.turn = clampi(int(d.get("turn", 0)), 0, 3)
	engine.passes = _ints(d.get("passes", [0, 0, 0, 0]))
	engine.level = clampi(int(d.get("level", 1)), 0, 2)
	engine.plays = int(d.get("plays", 0))
	engine.winner = -1
	started = true
	result_recorded = false
	busy = false
	end_dialog.visible = false
	_render()
	_advance()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
