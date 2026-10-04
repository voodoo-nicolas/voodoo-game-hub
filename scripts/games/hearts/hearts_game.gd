extends Control

## Hearts against three computer players: West (on your left), North and
## East. Your hand is along the bottom; each player's card in the current
## trick lands in front of them.

const HeartsEngine = preload("res://scripts/games/hearts/hearts_engine.gd")
const Cards = preload("res://scripts/games/hearts/hearts_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/hearts/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/hearts/hearts_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://hearts_save.json"

const SEATS := ["You", "West", "North", "East"]
const CARD_ASPECT := 1.42
const CPU_DELAY := 0.55
const TRICK_PAUSE := 1.1

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var started := false
var result_recorded := false
var picks: Array = []      # cards chosen to pass
var received: Array = []   # cards just passed to you (highlighted)
var showing_last := false  # a finished trick stays on the table a moment
var busy := false          # waiting on the timer (CPU move or trick pause)

var table: Control
var hand_view: Control
var status_label: Label
var pass_btn: Button
var timer: Timer
var round_dialog: Control
var round_next: Callable

func _ready() -> void:
	preload("res://scripts/games/hearts/hearts_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = HeartsEngine.new()
	_build_ui()
	engine.new_game(rng)
	started = false
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

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
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("Hearts")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.PINK.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.PINK, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
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

	var pb := HBoxContainer.new()
	pb.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(pb)
	pass_btn = Button.new()
	pass_btn.custom_minimum_size = Vector2(320, 64)
	pass_btn.pressed.connect(_on_pass)
	pb.add_child(pass_btn)

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

	round_dialog = UI.build_dialog("", [
		{"text": tr("Next hand"), "action": _on_round_button},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(round_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.PINK,
		"solo_heading": "vs Computer",
		"subtitle": "Dodge the hearts and the Queen of Spades — or take them all.",
		"logo": _draw_home_logo,
		"modes": [{"text": "♥ " + tr("New game"), "sub": "You and three computers, to 100", "action": _new_game}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Wins",
		"board_note": "Games won (lowest score when someone reaches 100).",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.42)  # beside East's seat, clear of the trick
	add_child(drawer)

# ---------- game flow ----------

func _new_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	_restart()

func _restart() -> void:
	engine.new_game(rng)
	_begin_hand()

func _begin_hand() -> void:
	started = true
	result_recorded = false
	picks = []
	received = []
	showing_last = false
	busy = false
	timer.stop()
	round_dialog.visible = false
	_sfx("card_shuffle")
	_render()
	_advance()

## Moves the game along: computer turns, the end of a hand.
func _advance() -> void:
	if engine.passing or busy:
		_render()
		return
	if engine.round_over():
		_end_hand()
		return
	if engine.turn != 0:
		busy = true
		timer.start(CPU_DELAY)
	_render()

func _on_timer() -> void:
	busy = false
	if showing_last:
		showing_last = false
		_advance()
		return
	if engine.turn != 0 and not engine.passing and not engine.round_over():
		_play(engine.turn, engine.cpu_play(engine.turn))

func _play(p: int, c: int) -> void:
	var before: int = engine.tricks_played
	if not engine.play(p, c):
		return
	_sfx("card_place")
	if engine.tricks_played > before:
		showing_last = true
		busy = true
		timer.start(TRICK_PAUSE)
		var pts := 0
		for t in engine.last_trick:
			pts += HeartsEngine.points(t[1])
		if pts > 0 and engine.last_winner == 0:
			_sfx("lose")
	_advance()

func _on_hand_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		if not rects[i].has_point(event.position):
			continue
		var c: int = engine.hands[0][i]
		if engine.passing:
			if c in picks:
				picks.erase(c)
			elif picks.size() < 3:
				picks.append(c)
			_sfx("toggle")
			_render()
		elif engine.turn == 0 and not busy and not engine.round_over():
			if c in engine.legal(0):
				received = []
				_play(0, c)
			else:
				_sfx("invalid")
		return

func _on_pass() -> void:
	if not engine.passing or picks.size() != 3:
		return
	var all: Array = [picks.duplicate()]
	for p in range(1, 4):
		all.append(engine.cpu_pass(p))
	var from: int = (4 - engine.pass_dir()) % 4
	engine.do_pass(all)
	received = all[from].duplicate()
	picks = []
	_sfx("card_deal")
	_advance()

func _end_hand() -> void:
	var moon: int = engine.score_round()
	var lines: Array = []
	if moon >= 0:
		lines.append(tr("%s shot the moon!") % tr(SEATS[moon]))
		if moon == 0 and info:
			info.add("Moons shot")
	for p in 4:
		lines.append("%s: +%d  →  %d" % [tr(SEATS[p]), 0 if moon == p else (26 if moon >= 0 else engine.round_points[p]), engine.scores[p]])
	if engine.round_points[0] == 0 and moon < 0 and info:
		info.add("Clean hands")
	var msg := "\n".join(lines)
	if engine.game_over():
		SaveUtil.delete(SAVE_PATH)
		var lead: Array = engine.leaders()
		var won: bool = 0 in lead
		msg = (tr("You win!") if won and lead.size() == 1 else (tr("Tied for the win!") if won else tr("%s wins.") % tr(SEATS[lead[0]]))) + "\n\n" + msg
		if info and not result_recorded:
			result_recorded = true
			info.result("win" if won and lead.size() == 1 else ("draw" if won else "loss"))
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
		_set_round_button(tr("Play Again"))
		round_next = _restart
	else:
		_set_round_button(tr("Next hand"))
		round_next = _begin_hand
		engine.deal(rng)
	round_dialog.get_meta("message_label").text = msg
	round_dialog.visible = true
	_render()

func _set_round_button(t: String) -> void:
	for b in round_dialog.find_children("*", "Button", true, false):
		if b.text == tr("Next hand") or b.text == tr("Play Again"):
			b.text = t

func _on_round_button() -> void:
	if round_next.is_valid():
		round_next.call()

# ---------- drawing ----------

func _render() -> void:
	var dir_names := {1: tr("to West ←"), 3: tr("to East →"), 2: tr("to North ↑")}
	pass_btn.visible = engine.passing
	if engine.passing:
		pass_btn.text = tr("Pass 3 cards %s") % dir_names.get(engine.pass_dir(), "")
		pass_btn.disabled = picks.size() != 3
		status_label.text = tr("Choose 3 cards to pass.") + "  (%d/3)" % picks.size()
	elif engine.round_over():
		status_label.text = ""
	elif engine.turn == 0 and not busy:
		status_label.text = tr("Your turn — tap a glowing card.")
		if engine.tricks_played == 0 and engine.trick.is_empty():
			status_label.text = tr("You have the 2♣ — lead it.")
	else:
		status_label.text = tr("%s is playing...") % tr(SEATS[engine.turn]) if not showing_last \
			else tr("%s takes the trick.") % tr(SEATS[engine.last_winner])
	table.queue_redraw()
	hand_view.queue_redraw()

func _seat_pos(p: int) -> Vector2:
	var s := table.size
	match p:
		0:
			return Vector2(s.x / 2.0, s.y * 0.78)
		1:
			return Vector2(s.x * 0.17, s.y * 0.45)
		2:
			return Vector2(s.x / 2.0, s.y * 0.13)
	return Vector2(s.x * 0.83, s.y * 0.45)

func _draw_table() -> void:
	var s := table.size
	var cw: float = minf(s.x * 0.17, s.y * 0.2 / CARD_ASPECT * 1.4)
	var ch := cw * CARD_ASPECT
	var center := Vector2(s.x / 2.0, s.y * 0.46)
	HomeKit.glow_circle(table, center, minf(s.x, s.y) * 0.33, Color(HomeKit.PURPLE, 0.35), 1.5, 0.04)
	var font := ThemeDB.fallback_font
	# Seat labels for the computers, with this hand's and the game's points.
	for p in range(1, 4):
		var pos := _seat_pos(p)
		var col: Color = HomeKit.GOLD if engine.turn == p and not engine.passing and not showing_last else HomeKit.DIM
		var label := "🤖 %s" % tr(SEATS[p])
		var label2 := tr("%d pts  (+%d)") % [engine.scores[p], engine.round_points[p]]
		var y_off := -ch * 0.95 if p != 2 else 0.0
		var lpos := pos + Vector2(0, y_off) if p != 2 else pos + Vector2(0, -ch * 0.15)
		table.draw_string(font, lpos - Vector2(110, 0), label, HORIZONTAL_ALIGNMENT_CENTER, 220, 24, col)
		table.draw_string(font, lpos - Vector2(110, -26), label2, HORIZONTAL_ALIGNMENT_CENTER, 220, 20, HomeKit.DIM)
	var my_pos := _seat_pos(0)
	table.draw_string(font, my_pos + Vector2(-160, ch * 0.42), tr("You: %d pts  (+%d)") % [engine.scores[0], engine.round_points[0]],
		HORIZONTAL_ALIGNMENT_CENTER, 320, 22, HomeKit.GOLD if engine.turn == 0 else HomeKit.DIM)
	# The trick: each card between its player's seat and the centre.
	var shown: Array = engine.last_trick if showing_last else engine.trick
	for t in shown:
		var at := center.lerp(_seat_pos(t[0]), 0.42)
		var r := Rect2(at - Vector2(cw, ch) / 2.0, Vector2(cw, ch))
		Cards.draw_card(table, r, t[1], true, showing_last and t[0] == engine.last_winner)
	if engine.hearts_broken and not engine.passing:
		table.draw_string(font, Vector2(0, s.y - 6), tr("Hearts are broken"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color(Cards.COLOR_RED, 0.8))

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
	var legal: Array = engine.legal(0) if (engine.turn == 0 and not engine.passing and not busy and not engine.round_over()) else []
	for i in rects.size():
		var c: int = engine.hands[0][i]
		var r: Rect2 = rects[i]
		var lifted: bool = c in picks or c in received
		if lifted:
			r.position.y -= 18
		var glow: bool = c in legal or c in picks
		var dim: bool = not engine.passing and engine.turn == 0 and not busy and not c in legal
		Cards.draw_card(hand_view, r, c, true, glow, dim)

func _draw_home_logo(c: Control) -> void:
	var w := minf(c.size.y * 0.42, 60.0)
	var h := w * CARD_ASPECT
	var o := c.size / 2.0
	var cards := [13 + 0, 13 + 12, 11, 13 + 9]
	for k in 4:
		var r := Rect2(o + Vector2((k - 1.5) * w * 0.7 - w / 2.0, -h / 2.0 + absf(k - 1.5) * 6.0), Vector2(w, h))
		Cards.draw_card(c, r, cards[k], true, k == 2)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.game_over():
		return
	SaveUtil.write(SAVE_PATH, {"hands": engine.hands, "scores": engine.scores, "round": engine.round_points,
		"hand_no": engine.hand_no, "trick": engine.trick, "leader": engine.leader, "turn": engine.turn,
		"broken": engine.hearts_broken, "tricks": engine.tricks_played, "passing": engine.passing})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	return tr("You: %d pts") % int(d.get("scores", [0])[0])

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or d.get("hands", []).size() != 4:
		_restart()
		return
	engine.hands = []
	for h in d.hands:
		engine.hands.append(_ints(h))
	engine.scores = _ints(d.get("scores", [0, 0, 0, 0]))
	engine.round_points = _ints(d.get("round", [0, 0, 0, 0]))
	engine.hand_no = int(d.get("hand_no", 0))
	engine.trick = []
	for t in d.get("trick", []):
		engine.trick.append([int(t[0]), int(t[1])])
	engine.leader = int(d.get("leader", 0))
	engine.turn = int(d.get("turn", 0))
	engine.hearts_broken = bool(d.get("broken", false))
	engine.tricks_played = int(d.get("tricks", 0))
	engine.passing = bool(d.get("passing", false))
	engine.last_trick = []
	started = true
	result_recorded = false
	picks = []
	received = []
	showing_last = false
	busy = false
	round_dialog.visible = false
	_render()
	_advance()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
