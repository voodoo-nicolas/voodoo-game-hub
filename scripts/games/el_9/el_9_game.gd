extends Control

## El 9: build ladders on the table, starting from the 9 of oros. Tap a glowing card to play it, or
## Pass when nothing fits. You vs one to three computers.
## Landing menu style: S10 Bento Grid (docs/MENU_STYLES.md).

const MenuStyles = preload("res://scripts/games/el_9/menu_styles.gd")
const Engine9 = preload("res://scripts/games/el_9/el_9_engine.gd")
const HomeKit = preload("res://scripts/games/el_9/home_kit.gd")
const Cards = preload("res://scripts/games/el_9/el_9_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const HELP = preload("res://scripts/games/el_9/el_9_help.gd")
## Not preloaded: apps before v0.20 don't have it, and the game must still run there.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SAVE_PATH := "user://el_9_save.json"

var info = null
var home
var engine: Engine9
var board: Control
var status_label: Label
var pass_btn: Button
var end_dialog: ColorRect
var cpu_timer: Timer
var font: Font
var started := false
var result_recorded := false
var cpus := 2                # computer seats (1-3)
var last_msg := ""
var skin: String = "classic"
var bg: ColorRect

func _ready() -> void:
	preload("res://scripts/games/el_9/el_9_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = Engine9.new()
	_build_ui()
	engine.new_game(cpus + 1)
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
	var title := Label.new()
	title.text = tr("9️⃣ El 9")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_restart)
	bar.add_child(new_btn)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 64)
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
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_bottom", 26)
	root.add_child(pm)
	pass_btn = Button.new()
	pass_btn.text = tr("Pass")
	pass_btn.custom_minimum_size = Vector2(260, 70)
	pass_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pass_btn.add_theme_font_size_override("font_size", 28)
	pass_btn.pressed.connect(_h_pass)
	pm.add_child(pass_btn)
	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 0.9
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)
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
		# Menu style (docs/MENU_STYLES.md): S10 Bento Grid; deep green + gold.
		"landing": "bento",
		"landing_style": MenuStyles,
		"title_colors": [Color("ffd23c"), Color("ffffff"), Color("62d26f")],
		"landing_colors": [Color("04200f"), Color("0d4a24")],
		"menu_color": Color("ffd23c"),
		"help": HELP,
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Start from the 9 of oros and build the ladders. First out wins.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "9️⃣  Play", "sub": "vs two computers", "key": "two", "action": _new_game.bind(2)},
			{"text": "1 CPU", "row": "cpus", "color": HomeKit.CYAN, "action": _new_game.bind(1)},
			{"text": "3 CPUs", "row": "cpus", "color": HomeKit.PINK, "action": _new_game.bind(3)},
		],
		"solo_heading": "vs Computer",
		"resume_text": _resume_text,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _restart,
		"helps": [{"text": "💡 Hint", "how": "Plays a good card for you (or passes when nothing fits).", "action": _help_play}],
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
	var specs := [[-0.35, Cards.make(1, 9)], [0.0, Cards.make(0, 9)], [0.35, Cards.make(3, 9)]]
	for spec in specs:
		c.draw_set_transform(ctr + Vector2(spec[0] * w * 1.1, abs(spec[0]) * h * 0.18), spec[0], Vector2.ONE)
		Cards.draw_card(c, Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)), spec[1])
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------- flow ----------

func _new_game(n: int = 2) -> void:
	cpus = n
	SaveUtil.delete(SAVE_PATH)
	_restart()

func _name(p: int) -> String:
	return tr("You") if p == 0 else tr("CPU %d") % p

func _restart() -> void:
	started = true
	result_recorded = false
	cpu_timer.stop()
	engine.new_game(cpus + 1)
	_sfx("card_shuffle")
	last_msg = tr("%s opens with the 9 of oros.") % _name(engine.last.p)
	end_dialog.visible = false
	_update()

func _my_turn() -> bool:
	return engine.winner == -1 and engine.turn == 0

func _update() -> void:
	if engine.winner != -1:
		status_label.text = last_msg
		_refresh()
		_game_over()
		return
	if _my_turn():
		status_label.text = last_msg + ("\n" if last_msg != "" else "") + (tr("Your turn: play a glowing card.") if not engine.playable(0).is_empty() else tr("Nothing fits: tap Pass."))
	else:
		status_label.text = last_msg
	_refresh()
	if not _my_turn():
		cpu_timer.start()

func _refresh() -> void:
	pass_btn.visible = _my_turn() and engine.playable(0).is_empty()
	board.queue_redraw()

func _h_play(card: int) -> void:
	if engine.play(0, card):
		_sfx("card_place")
		last_msg = tr("You play %s.") % Cards.label(card)
		_update()

func _h_pass() -> void:
	if engine.pass_turn(0):
		last_msg = tr("You pass.")
		_update()

func _cpu_turn() -> void:
	var p: int = engine.turn
	if p == 0 or engine.winner != -1:
		return
	var c := engine.cpu_pick(p)
	if c == -1:
		engine.pass_turn(p)
		last_msg = tr("%s passes.") % _name(p)
	else:
		engine.play(p, c)
		_sfx("card_place")
		last_msg = tr("%s plays %s.") % [_name(p), Cards.label(c)]
	_update()

func _game_over() -> void:
	cpu_timer.stop()
	var won: bool = engine.winner == 0
	var msg := tr("You win!") if won else tr("%s wins!") % _name(engine.winner)
	SaveUtil.delete(SAVE_PATH)
	if info and not result_recorded:
		result_recorded = true
		info.result("win" if won else "loss")
		msg += "\n" + info.summary()
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _hand_rects() -> Array:
	var n: int = engine.hands[0].size()
	var cw: float = minf(86.0, (board.size.x - 24.0) / 7.5)
	var cs := Vector2(cw, cw * 1.4)
	var per_row: int = n if n <= 8 else ceili(n / 2.0)
	var rows := ceili(float(n) / maxi(1, per_row))
	var out: Array = []
	var bottom := board.size.y - cs.y - 4.0
	for i in n:
		var row: int = i / per_row
		var col: int = i % per_row
		var in_row: int = mini(per_row, n - row * per_row)
		var step: float = minf(cs.x + 4.0, (board.size.x - 16.0 - cs.x) / maxf(1.0, in_row - 1.0))
		var x0: float = (board.size.x - (step * (in_row - 1) + cs.x)) / 2.0
		out.append(Rect2(Vector2(x0 + col * step, bottom - (rows - 1 - row) * cs.y * 0.92), cs))
	return out

func _draw_board() -> void:
	if engine.hands.is_empty():
		return
	var gold := Color(1, 0.9, 0.4)
	var white := Color(0.88, 0.95, 0.9)
	for p in range(1, engine.seats):
		var x: float = board.size.x * (float(p) / engine.seats if engine.seats > 2 else 0.5)
		var col := gold if engine.turn == p and engine.winner == -1 else white
		board.draw_string(font, Vector2(x - 90.0, 28), tr("%s: %d cards") % [_name(p), engine.hands[p].size()], HORIZONTAL_ALIGNMENT_CENTER, 180, 20, col)
	# the four ladders: 12 slots per suit
	var mw: float = (board.size.x - 16.0) / 12.0
	var mh := mw * 1.35
	var y0 := 44.0
	for s in 4:
		for n in range(1, 13):
			var r := Rect2(Vector2(8.0 + (n - 1) * mw + 1.0, y0 + s * (mh + 4.0)), Vector2(mw - 2.0, mh))
			if engine.hi[s] != 0 and n >= engine.lo[s] and n <= engine.hi[s]:
				Cards.draw_card(board, r, Cards.make(s, n))
			else:
				Cards.draw_card(board, r, -1)
	var rects := _hand_rects()
	var my := _my_turn()
	for i in rects.size():
		var card: int = engine.hands[0][i]
		var ok := my and engine.can_play(card)
		Cards.draw_card(board, rects[i], card, true, ok, my and not ok)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _my_turn():
		return
	var rects := _hand_rects()
	for i in range(rects.size() - 1, -1, -1):
		if rects[i].has_point(event.position):
			var card: int = engine.hands[0][i]
			if engine.can_play(card):
				_h_play(card)
			return

# ---------- save / resume ----------

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	return tr("%d players") % int(d.seats)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

## Saved on the player's turn; the computers' turns replay from there.
func _save_game() -> void:
	if not started or not _my_turn():
		return
	SaveUtil.write(SAVE_PATH, engine.to_dict())

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_restart()
		return
	started = true
	result_recorded = false
	engine.from_dict(d)
	cpus = engine.seats - 1
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
	var c := engine.cpu_pick(0)
	if c == -1:
		_h_pass()
	else:
		_h_play(c)
	return true
