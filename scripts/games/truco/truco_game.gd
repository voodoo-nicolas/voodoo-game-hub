extends Control

## Truco Argentino: you vs the computer, Spanish cards, first to 15. Tap a card to play it; the
## buttons under the table are the calls (Envido, Truco...) and the answers (Quiero / No quiero).
## Landing menu style: S9 Arcade Marquee (docs/MENU_STYLES.md).

const MenuStyles = preload("res://scripts/games/truco/menu_styles.gd")
const TrucoEngine = preload("res://scripts/games/truco/truco_engine.gd")
const HomeKit = preload("res://scripts/games/truco/home_kit.gd")
const Cards = preload("res://scripts/games/truco/truco_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const HELP = preload("res://scripts/games/truco/truco_help.gd")
## Not preloaded: apps before v0.20 don't have it, and the game must still run there.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SAVE_PATH := "user://truco_save.json"
const TRUCO_NAMES := ["Truco", "Retruco", "Vale cuatro"]

var info = null
var home
var engine: TrucoEngine
var board: Control
var actions: HFlowContainer
var status_label: Label
var score_label: Label
var round_dialog: ColorRect
var end_dialog: ColorRect
var cpu_timer: Timer
var font: Font
var started := false
var result_recorded := false
var skill := 1               # 0 easy, 1 normal, 2 hard
var last_msg := ""
var skin: String = "classic"
var bg: ColorRect

func _ready() -> void:
	preload("res://scripts/games/truco/truco_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = TrucoEngine.new()
	_build_ui()
	engine.new_game()
	_update()
	started = false

# ---------- look ----------

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
	score_label.add_theme_font_size_override("font_size", 28)
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

	var am := MarginContainer.new()
	am.add_theme_constant_override("margin_left", 12)
	am.add_theme_constant_override("margin_right", 12)
	am.add_theme_constant_override("margin_bottom", 26)
	root.add_child(am)
	actions = HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 8)
	actions.custom_minimum_size = Vector2(0, 150)
	am.add_child(actions)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 1.0
	cpu_timer.timeout.connect(_cpu_act)
	add_child(cpu_timer)

	round_dialog = UI.build_dialog("", [{"text": tr("Next hand"), "action": _next_round}], true)
	add_child(round_dialog)
	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _new_game},
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
		# Menu style (docs/MENU_STYLES.md): S9 Arcade Marquee; sky blue + white + sun yellow.
		"landing": "marquee",
		"landing_style": MenuStyles,
		"title_colors": [Color("74acdf"), Color("ffffff"), Color("f6b40e")],
		"landing_colors": [Color("06182c"), Color("123a63")],
		"menu_color": Color("74acdf"),
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Envido, truco, and a good poker face. You vs the computer, to 15.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🗡️  Play", "sub": "to 15 points, Spanish cards", "key": "normal", "action": _new_game.bind(1)},
			{"text": "Easy", "row": "level", "color": HomeKit.LIME, "action": _new_game.bind(0)},
			{"text": "Hard", "row": "level", "color": HomeKit.PINK, "action": _new_game.bind(2)},
		],
		"solo_heading": "vs Computer",
		"resume_text": _resume_text,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _restart,
		"helps": [{"text": "💡 Hint", "how": "Plays the card the computer would play from your hand.", "action": _help_play}],
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
	var specs := [[-0.35, Cards.make(3, 1)], [0.0, Cards.make(2, 1)], [0.35, Cards.make(0, 7)]]
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

func _mano_msg() -> String:
	return tr("You are \"mano\": you lead.") if engine.mano == 0 else tr("The computer is \"mano\" and leads.")

func _restart() -> void:
	started = true
	result_recorded = false
	cpu_timer.stop()
	engine.new_game()
	_sfx("card_shuffle")
	last_msg = _mano_msg()
	round_dialog.visible = false
	end_dialog.visible = false
	_update()

func _next_round() -> void:
	round_dialog.visible = false
	engine.new_round()
	_sfx("card_shuffle")
	last_msg = _mano_msg()
	_update()

func _update() -> void:
	score_label.text = tr("You %d  ·  %d CPU   (to %d)") % [engine.score[0], engine.score[1], engine.target]
	status_label.text = last_msg
	board.queue_redraw()
	_refresh_actions()
	if engine.winner != -1:
		_game_over()
	elif engine.round_winner != -1:
		_round_over()
	elif _cpu_to_move():
		cpu_timer.start()

func _cpu_to_move() -> bool:
	if engine.pending.is_empty():
		return engine.turn == 1
	return int(engine.pending.by) == 0

# ---------- the player ----------

func _my_turn() -> bool:
	return engine.round_on() and engine.pending.is_empty() and engine.turn == 0

## "You win the trick." etc. when the last play finished a trick that did not end the hand.
func _trick_note(before: int) -> String:
	if engine.tricks.size() == before or engine.round_winner != -1:
		return ""
	var w: int = engine.tricks.back()
	return " " + (tr("You win the trick.") if w == 0 else (tr("The computer wins the trick.") if w == 1 else tr("Tie (parda).")))

func _h_play(card: int) -> void:
	var before := engine.tricks.size()
	if not engine.play(0, card):
		return
	_sfx("card_place")
	last_msg = tr("You play %s.") % Cards.label(card) + _trick_note(before)
	_update()

func _h_envido(kind: String) -> void:
	if engine.call_envido(0, kind):
		last_msg = tr("You: %s!") % _envido_name(kind)
		_update()

func _h_truco() -> void:
	var lv: int = int(engine.pending.level) if not engine.pending.is_empty() else engine.level
	if engine.call_truco(0):
		last_msg = tr("You: %s!") % tr(TRUCO_NAMES[lv])
		_update()

func _h_answer(accept: bool) -> void:
	if engine.pending.is_empty():
		return
	if engine.pending.kind == "envido":
		engine.answer_envido(0, accept)
		last_msg = _envido_summary(accept)
	else:
		engine.answer_truco(0, accept)
		last_msg = tr("You: ¡Quiero!") if accept else tr("You: No quiero.")
	_update()

func _h_fold() -> void:
	if engine.fold(0):
		last_msg = tr("You go to the deck (al mazo).")
		_update()

func _envido_name(kind: String) -> String:
	return {"envido": tr("Envido"), "real": tr("Real envido"), "falta": tr("Falta envido")}[kind]

func _envido_summary(accepted: bool) -> String:
	var r: Dictionary = engine.envido_result
	if r.is_empty():
		return ""
	if r.rejected:
		return tr("Envido refused: %s +%d.") % [tr("You") if r.winner == 0 else tr("CPU"), r.points]
	if accepted and info and r.winner == 0:
		info.add("Envidos won")
	return tr("Envido: you %d, CPU %d → %s +%d.") % [r.vals[0], r.vals[1], tr("You") if r.winner == 0 else tr("CPU"), r.points]

# ---------- the computer ----------

func _cpu_act() -> void:
	if not engine.round_on() or not _cpu_to_move():
		return
	var a: Dictionary = engine.cpu_action(1, skill)
	var act: String = a["do"]
	if not engine.pending.is_empty():
		var kind: String = engine.pending.kind
		match act:
			"yes", "no":
				var yes := act == "yes"
				if kind == "envido":
					engine.answer_envido(1, yes)
					last_msg = (tr("CPU: ¡Quiero!") if yes else tr("CPU: No quiero.")) + " " + _envido_summary(yes)
				else:
					engine.answer_truco(1, yes)
					last_msg = tr("CPU: ¡Quiero!") if yes else tr("CPU: No quiero.")
			"envido":
				engine.call_envido(1, a["kind"])
				last_msg = tr("CPU: %s!") % _envido_name(a["kind"])
			"truco":
				var lv2: int = int(engine.pending.level)
				engine.call_truco(1)
				last_msg = tr("CPU: %s!") % tr(TRUCO_NAMES[lv2])
		_update()
		return
	match act:
		"envido":
			engine.call_envido(1, a["kind"])
			last_msg = tr("CPU: %s!") % _envido_name(a["kind"])
		"truco":
			var lv: int = engine.level
			engine.call_truco(1)
			last_msg = tr("CPU: %s!") % tr(TRUCO_NAMES[lv])
		_:
			var c: int = a["card"]
			var before := engine.tricks.size()
			engine.play(1, c)
			_sfx("card_place")
			last_msg = tr("CPU plays %s.") % Cards.label(c) + _trick_note(before)
	_update()

# ---------- ends ----------

func _round_over() -> void:
	cpu_timer.stop()
	var who := tr("You win the hand") if engine.round_winner == 0 else tr("The computer wins the hand")
	round_dialog.get_meta("message_label").text = "%s: +%d" % [who, engine.round_points]
	round_dialog.visible = true
	SaveUtil.delete(SAVE_PATH)
	if engine.round_winner == 0 and info and not result_recorded:
		info.add("Hands won")

func _game_over() -> void:
	cpu_timer.stop()
	round_dialog.visible = false
	var won: bool = engine.winner == 0
	var msg := tr("You win the game!") if won else tr("The computer wins the game.")
	msg += " %d – %d" % [engine.score[0], engine.score[1]]
	SaveUtil.delete(SAVE_PATH)
	if info and not result_recorded:
		result_recorded = true
		info.result("win" if won else "loss")
		msg += "\n" + info.summary()
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- actions bar ----------

func _btn(text: String, action: Callable, hot: bool = false) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 64)
	b.add_theme_font_size_override("font_size", 24)
	if hot:
		b.add_theme_color_override("font_color", Color("ffd23c"))
	b.pressed.connect(action)
	actions.add_child(b)

func _refresh_actions() -> void:
	for c in actions.get_children():
		actions.remove_child(c)
		c.queue_free()
	if not engine.round_on():
		return
	var p: Dictionary = engine.pending
	if not p.is_empty():
		if int(p.by) != 1:
			return
		_btn(tr("¡Quiero!"), _h_answer.bind(true), true)
		_btn(tr("No quiero"), _h_answer.bind(false))
		if p.kind == "envido":
			for k in ["envido", "real", "falta"]:
				if engine.can_call_envido(0, k):
					_btn(_envido_name(k), _h_envido.bind(k))
		elif engine.can_call_truco(0):
			_btn(tr(TRUCO_NAMES[int(p.level)]), _h_truco)
		return
	if engine.turn != 0:
		return
	for k in ["envido", "real", "falta"]:
		if engine.can_call_envido(0, k):
			_btn(_envido_name(k), _h_envido.bind(k))
	if engine.can_call_truco(0):
		_btn(tr(TRUCO_NAMES[engine.level]), _h_truco)
	_btn(tr("Al mazo"), _h_fold)

# ---------- drawing ----------

func _card_size() -> Vector2:
	var w: float = minf(104.0, board.size.x / 4.0)
	return Vector2(w, w * 1.5)

func _hand_rects() -> Array:
	var cs := _card_size()
	var n: int = engine.hands[0].size()
	var gap := 12.0
	var x0: float = (board.size.x - (cs.x * n + gap * (n - 1))) / 2.0
	var out: Array = []
	for i in n:
		out.append(Rect2(Vector2(x0 + i * (cs.x + gap), board.size.y - cs.y - 8.0), cs))
	return out

func _draw_board() -> void:
	if engine.hands.is_empty():
		return
	var cs := _card_size()
	var small := cs * 0.5
	var n1: int = engine.hands[1].size()
	for k in n1:
		Cards.draw_card(board, Rect2(Vector2(board.size.x / 2.0 - (small.x * n1 + 6 * (n1 - 1)) / 2.0 + k * (small.x + 6), 6), small), 0, false)
	var white := Color(0.9, 0.95, 1)
	board.draw_string(font, Vector2(8, 26), tr("CPU") + ("  ✋" if engine.mano == 1 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, white)
	board.draw_string(font, Vector2(8, board.size.y - cs.y - 16), tr("You") + ("  ✋" if engine.mano == 0 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, white)
	# the table: one column per trick, the computer's card above yours
	var mw := cs.x * 0.82
	var mh := mw * 1.5
	var gap := 14.0
	var x0 := (board.size.x - (mw * 3 + gap * 2)) / 2.0
	var y0 := small.y + 24.0
	for t in 3:
		var x := x0 + t * (mw + gap)
		var r1 := Rect2(Vector2(x, y0), Vector2(mw, mh))
		var r0 := Rect2(Vector2(x, y0 + mh * 0.5), Vector2(mw, mh))
		var a: int = engine.played[1][t] if t < engine.played[1].size() else -1
		var b: int = engine.played[0][t] if t < engine.played[0].size() else -1
		if a < 0 and b < 0:
			Cards.draw_card(board, r1, -1)
			continue
		var tw: int = engine.tricks[t] if t < engine.tricks.size() else -2
		if a >= 0:
			Cards.draw_card(board, r1, a, true, tw == 1)
		if b >= 0:
			Cards.draw_card(board, r0, b, true, tw == 0)
	var st := tr("Stake: %d") % engine.stake()
	if engine.level > 0:
		st = tr(TRUCO_NAMES[engine.level - 1]) + " · " + st
	board.draw_string(font, Vector2(0, y0 + mh * 1.55), st, HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 22, Color(1, 0.85, 0.35))
	var rects := _hand_rects()
	var my := _my_turn()
	for i in rects.size():
		Cards.draw_card(board, rects[i], engine.hands[0][i], true, my, false)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _my_turn():
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		if rects[i].has_point(event.position):
			_h_play(engine.hands[0][i])
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

## Saved on the player's turn, with nothing pending (the computer's turns replay from there).
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
	_h_play(engine.pick_card(0))
	return true
