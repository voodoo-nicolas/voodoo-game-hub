extends Control

## Liar's Dice vs two computer players, or 2-4 people passing the phone.
## Raise the bid or call "Liar!". In pass-and-play only the player whose turn
## it is sees their own dice; a cover screen hides the table between turns.

const LDEngine = preload("res://scripts/games/liars_dice/liars_dice_engine.gd")
const HomeKit = preload("res://scripts/games/liars_dice/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const PIPS := {1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
	5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: LDEngine
var table: Control
var status_label: Label
var qty_label: Label
var bid_btn: Button
var liar_btn: Button
var next_btn: Button
var face_buttons: Array = []
var controls: Control
var cpu_timer: Timer
var end_dialog: ColorRect
var my_qty: int = 1
var my_face: int = 2
var revealing := false
var log_lines: Array = []
## Pass-and-play: every seat is a person; `viewer` is whose dice are shown.
var hotseat := false
var viewer: int = 0
var cover: ColorRect
var cover_label: Label

func _ready() -> void:
	preload("res://scripts/games/liars_dice/liars_dice_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = LDEngine.new()
	_build_ui()
	_start()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
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
	title.text = tr("🤥 Liar's Dice")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 25)
	status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.custom_minimum_size = Vector2(0, 70)
	root.add_child(status_label)

	table = Control.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.draw.connect(_draw_table)
	table.resized.connect(table.queue_redraw)
	root.add_child(table)

	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 10)
	controls = cbox
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 30)
	cm.add_theme_constant_override("margin_left", 16)
	cm.add_theme_constant_override("margin_right", 16)
	cm.add_child(cbox)
	root.add_child(cm)

	var qrow := HBoxContainer.new()
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	qrow.add_theme_constant_override("separation", 16)
	cbox.add_child(qrow)
	qrow.add_child(_small_button("−", _change_qty.bind(-1)))
	qty_label = Label.new()
	qty_label.add_theme_font_size_override("font_size", 30)
	qty_label.custom_minimum_size = Vector2(200, 0)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qrow.add_child(qty_label)
	qrow.add_child(_small_button("+", _change_qty.bind(1)))

	var frow := HBoxContainer.new()
	frow.alignment = BoxContainer.ALIGNMENT_CENTER
	frow.add_theme_constant_override("separation", 10)
	cbox.add_child(frow)
	for f in range(1, 7):
		var b := Button.new()
		b.text = str(f)
		b.custom_minimum_size = Vector2(92, 80)
		b.add_theme_font_size_override("font_size", 46)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick_face.bind(f))
		frow.add_child(b)
		face_buttons.append(b)

	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.add_theme_constant_override("separation", 16)
	cbox.add_child(arow)
	bid_btn = Button.new()
	bid_btn.custom_minimum_size = Vector2(300, 76)
	bid_btn.add_theme_font_size_override("font_size", 26)
	bid_btn.pressed.connect(_on_bid)
	arow.add_child(bid_btn)
	liar_btn = Button.new()
	liar_btn.text = tr("Liar!")
	liar_btn.custom_minimum_size = Vector2(220, 76)
	liar_btn.add_theme_font_size_override("font_size", 28)
	liar_btn.pressed.connect(_on_liar)
	arow.add_child(liar_btn)
	next_btn = Button.new()
	next_btn.text = tr("Next Round")
	next_btn.custom_minimum_size = Vector2(300, 76)
	next_btn.add_theme_font_size_override("font_size", 26)
	next_btn.pressed.connect(_next_round)
	arow.add_child(next_btn)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 1.3
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	_build_cover()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/liars_dice/liars_dice_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(90, 70)
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(action)
	return b

func _name(p: int) -> String:
	if hotseat:
		return tr("Player %d") % (p + 1)
	return tr("You") if p == 0 else tr("CPU %d") % p

func _is_person(p: int) -> bool:
	return hotseat or p == 0

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
	cover_label.add_theme_font_size_override("font_size", 38)
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

func _on_cover_ready() -> void:
	cover.visible = false
	viewer = engine.turn
	_refresh()

func _bid_text(b: Vector2i) -> String:
	return tr("%d × face %d") % [b.x, b.y]

func _start() -> void:
	result_recorded = false
	cpu_timer.stop()
	engine.reset(engine.PLAYERS if hotseat else 3)
	viewer = 0
	end_dialog.visible = false
	revealing = false
	log_lines = []
	_after_change()

func _next_round() -> void:
	if not revealing:
		return
	revealing = false
	log_lines = []
	engine.new_round(engine.next_starter())
	_sfx("dice_roll")
	_after_change()

## Picks a legal default for the bid controls and schedules computer turns.
func _after_change() -> void:
	if hotseat and not revealing and engine.winner == -1 and viewer != engine.turn:
		cover_label.text = tr("Pass the phone to %s") % _name(engine.turn) + "\n\n" + tr("Only they may look at their dice!")
		cover.visible = true
	if _is_person(engine.turn) and not revealing:
		my_face = max(engine.bid.y, 1)
		my_qty = max(engine.bid.x, 1)
		if not LDEngine.beats(Vector2i(my_qty, my_face), engine.bid):
			if my_face < 6:
				my_face += 1
			else:
				my_qty += 1
	_refresh()
	if not _is_person(engine.turn) and not revealing and engine.winner == -1:
		cpu_timer.start()

func _refresh() -> void:
	var mine: bool = _is_person(engine.turn) and engine.turn == viewer and not revealing and engine.alive(engine.turn)
	for n in [qty_label, bid_btn, liar_btn]:
		n.visible = not revealing
	for b in face_buttons:
		b.get_parent().visible = not revealing
	qty_label.get_parent().visible = not revealing
	next_btn.visible = revealing and engine.winner == -1
	bid_btn.text = tr("Bid %s") % _bid_text(Vector2i(my_qty, my_face))
	bid_btn.disabled = not mine or not LDEngine.beats(Vector2i(my_qty, my_face), engine.bid) or my_qty > engine.total_dice()
	liar_btn.disabled = not mine or engine.bid == Vector2i.ZERO
	qty_label.text = tr("%d dice") % my_qty
	for i in face_buttons.size():
		face_buttons[i].modulate = Color(1, 0.85, 0.3) if i + 1 == my_face else Color(1, 1, 1)
	if not revealing:
		var who := _name(engine.turn)
		var bid_part := tr("No bid yet.") if engine.bid == Vector2i.ZERO else tr("Current bid: %s by %s.") % [_bid_text(engine.bid), _name(engine.bidder)]
		status_label.text = bid_part + "\n" + (tr("Your move.") if mine else tr("%s is thinking...") % who)
		if hotseat and mine:
			status_label.text = bid_part + "\n" + tr("%s, your move.") % who
		if not hotseat and not engine.alive(0):
			status_label.text = bid_part + "\n" + tr("You're out — watching the computers.")
	table.queue_redraw()

func _change_qty(d: int) -> void:
	my_qty = clampi(my_qty + d, 1, engine.total_dice())
	_refresh()

func _pick_face(f: int) -> void:
	my_face = f
	_refresh()

func _on_bid() -> void:
	var p: int = engine.turn
	if _is_person(p) and p == viewer and engine.place_bid(Vector2i(my_qty, my_face)):
		if hotseat:
			log_lines.append(tr("%s bids %s.") % [_name(p), _bid_text(engine.bid)])
		else:
			log_lines.append(tr("You bid %s.") % _bid_text(engine.bid))
		_after_change()

func _on_liar() -> void:
	if _is_person(engine.turn) and engine.turn == viewer and engine.bid != Vector2i.ZERO:
		_resolve()

func _cpu_turn() -> void:
	var p: int = engine.turn
	if _is_person(p) or revealing:
		return
	var choice := engine.cpu_decide(p)
	if choice == Vector2i.ZERO or not engine.place_bid(choice):
		if engine.bid == Vector2i.ZERO:
			engine.place_bid(Vector2i(1, randi_range(1, 6)))
			log_lines.append(tr("%s bids %s.") % [_name(p), _bid_text(engine.bid)])
		else:
			_resolve()
			return
	else:
		log_lines.append(tr("%s bids %s.") % [_name(p), _bid_text(engine.bid)])
	_after_change()

func _resolve() -> void:
	var r := engine.challenge()
	_sfx("drumroll")
	revealing = true
	var msg := tr("%s calls Liar on %s!") % [_name(r.caller), _bid_text(r.bid)] + "\n"
	msg += tr("There are %d. %s loses a die.") % [r.actual, _name(r.loser)]
	status_label.text = msg
	_refresh()
	if hotseat:
		if engine.winner != -1:
			var win_msg := tr("%s wins!") % _name(engine.winner)
			if info and not result_recorded:
				result_recorded = true
				info.add("Pass-and-play games")
				info.celebrate(win_msg)
			end_dialog.get_meta("message_label").text = win_msg
			end_dialog.visible = true
		return
	if engine.winner != -1:
		end_dialog.get_meta("message_label").text = (tr("You win!") if engine.winner == 0 else tr("%s wins!") % _name(engine.winner)) + _record_result("win" if engine.winner == 0 else "loss")
		end_dialog.visible = true
	elif not engine.alive(0):
		end_dialog.get_meta("message_label").text = tr("You're out of dice!") + _record_result("loss")
		end_dialog.visible = true

# ---------- drawing ----------

## Look (STANDARDS §9): "classic" = ivory dice, wooden cups (default); "voodoo" = the neon
## board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: ColorRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.felt_dark if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if table:
		table.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _draw_die(pos: Vector2, s: float, v: int, hidden: bool, hilite: bool) -> void:
	var r := Rect2(pos, Vector2(s, s))
	var col: Color = HomeKit.GOLD if hilite else (HomeKit.PURPLE if hidden else HomeKit.CYAN)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.2 if hilite else 0.1)
	sb.border_color = col
	sb.set_border_width_all(4 if hilite else 2)
	sb.shadow_color = Color(col, 0.35)
	sb.shadow_size = 6
	sb.set_corner_radius_all(int(s * 0.16))
	var pip := Color.WHITE
	if _is_classic():
		sb = StyleBoxFlat.new()
		sb.bg_color = HomeKit.CLASSIC.wood_dark if hidden else Color("f4efe4")
		sb.set_corner_radius_all(int(s * 0.16))
		sb.border_color = HomeKit.CLASSIC.yellow if hilite else (HomeKit.CLASSIC.wood_frame if hidden else Color("b9b3a3"))
		sb.set_border_width_all(5 if hilite else 2)
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(1, 2)
		pip = HomeKit.CLASSIC.ink
	table.draw_style_box(sb, r)
	if hidden:
		table.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.get_center().y + s * 0.2), "?", HORIZONTAL_ALIGNMENT_CENTER, s, int(s * 0.55), Color(1, 1, 1, 0.6))
		return
	for sp in PIPS[v]:
		table.draw_circle(r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * s, s * 0.085, pip)

func _draw_table() -> void:
	if engine.dice.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var face: int = engine.bid.y if revealing else 0
	# The other seats on top, the one looking at the phone at the bottom.
	var me: int = viewer if hotseat else 0
	var rows: Array = []
	for k in range(1, engine.PLAYERS):
		rows.append((me + k) % engine.PLAYERS)
	rows.append(me)
	var y := 10.0
	for p in rows:
		var n: int = engine.counts[p]
		var col := Color(1, 0.85, 0.4) if engine.turn == p and not revealing else Color(0.9, 0.85, 0.8)
		table.draw_string(font, Vector2(0, y + 24), tr("%s — %d dice") % [_name(p), n], HORIZONTAL_ALIGNMENT_CENTER, table.size.x, 24, col)
		var s: float = 76.0 if p == me else (58.0 if engine.PLAYERS <= 3 else 46.0)
		var total: float = n * s + max(0, n - 1) * 10.0
		for i in n:
			var v: int = engine.dice[p][i]
			var hidden: bool = (p != me or (hotseat and cover.visible)) and not revealing
			_draw_die(Vector2((table.size.x - total) / 2.0 + i * (s + 10.0), y + 40), s, v, hidden, revealing and v == face)
		y += s + (70 if engine.PLAYERS <= 3 else 58)
	var ly := y + 10
	for line in log_lines.slice(max(0, log_lines.size() - 3)):
		table.draw_string(font, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, table.size.x, 21, Color(0.8, 0.75, 0.7))
		ly += 28


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/liars_dice/liars_dice_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/liars_dice/liars_dice_help.gd"),
		"info": info,
		"accent": HomeKit.PURPLE,
		"subtitle": "Bluff about the dice under your cup. Last player with dice wins.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🎲  Play", "sub": "vs two computer players", "action": _new_game.bind(0)},
			{"text": "👥 2", "row": "players", "multi": true, "color": HomeKit.CYAN, "action": _new_game.bind(2)},
			{"text": "👥 3", "row": "players", "multi": true, "color": HomeKit.PINK, "action": _new_game.bind(3)},
			{"text": "👥 4", "row": "players", "multi": true, "color": HomeKit.LIME, "action": _new_game.bind(4)},
		],
		"multi_heading": "Pass the phone",
		"restart": _start,
		"board": "Wins",
		"board_note": "Games won.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

## 0 = vs the computers; 2-4 = that many people passing the phone.
func _new_game(n: int) -> void:
	hotseat = n > 0
	engine.PLAYERS = n if hotseat else 3
	_start()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	# a dice cup and three dice, one hidden
	var cup := PackedVector2Array([ctr + Vector2(-h * 0.5, -h * 0.4), ctr + Vector2(-h * 0.2, -h * 0.4), ctr + Vector2(-h * 0.14, h * 0.3), ctr + Vector2(-h * 0.56, h * 0.3)])
	c.draw_colored_polygon(cup, Color(HomeKit.PURPLE, 0.2))
	HomeKit.glow_polyline(c, cup, HomeKit.PURPLE, 2.5, true)
	var s := h * 0.24
	for i in 3:
		var r := Rect2(ctr + Vector2(h * (0.02 + i * 0.3), h * 0.06), Vector2(s, s))
		HomeKit.glow_rect(c, r, [HomeKit.CYAN, HomeKit.CYAN, HomeKit.GOLD][i], 2.0, 0.12)
		if i == 2:
			HomeKit.glow_text(c, r.get_center(), "?", int(s * 0.6), HomeKit.GOLD)
		else:
			for sp in PIPS[[5, 3][i]]:
				c.draw_circle(r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * s, s * 0.08, Color.WHITE)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
