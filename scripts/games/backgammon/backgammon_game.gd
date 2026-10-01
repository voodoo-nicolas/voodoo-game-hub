extends Control

## Backgammon vs the computer, on a board turned sideways to fit a phone.
## You are white: your checkers travel up the left side, across the top and
## down the right side into your home board (bottom right), then bear off
## into the tray below. Tap a checker, then a highlighted point.

const BgEngine = preload("res://scripts/games/backgammon/backgammon_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const HUMAN := 0
const CPU := 1
const COLOR_FELT := Color(0.12, 0.3, 0.2)
const COLOR_FRAME := Color(0.35, 0.22, 0.12)
const COLOR_TRI_A := Color(0.78, 0.62, 0.42)
const COLOR_TRI_B := Color(0.55, 0.18, 0.15)
const COLOR_WHITE := Color(0.96, 0.94, 0.88)
const COLOR_BLACK := Color(0.14, 0.14, 0.16)
const COLOR_HILITE := Color(0.35, 0.9, 1.0)

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var engine: BgEngine
var board: Control
var status_label: Label
var roll_btn: Button
var undo_btn: Button
var cpu_timer: Timer
var end_dialog: ColorRect
var font: Font

var turn: int = HUMAN
var dice: Array = []          # dice still to play
var rolled: Array = []        # the dice as rolled (for display)
var turn_start: Dictionary = {}
var selected: int = -1        # relative source, BgEngine.BAR for the bar
var legal: Array = []
var cpu_moves: Array = []

func _ready() -> void:
	preload("res://scripts/games/backgammon/backgammon_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = BgEngine.new()
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🎲 Backgammon")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start_new_game)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
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
	controls.add_theme_constant_override("separation", 20)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 30)
	cm.add_child(controls)
	root.add_child(cm)
	undo_btn = Button.new()
	undo_btn.text = tr("↶ Undo")
	undo_btn.custom_minimum_size = Vector2(200, 72)
	undo_btn.add_theme_font_size_override("font_size", 28)
	undo_btn.pressed.connect(_on_undo)
	controls.add_child(undo_btn)
	roll_btn = Button.new()
	roll_btn.text = tr("🎲 Roll")
	roll_btn.custom_minimum_size = Vector2(260, 72)
	roll_btn.add_theme_font_size_override("font_size", 28)
	roll_btn.pressed.connect(_on_roll)
	controls.add_child(roll_btn)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_step)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/backgammon/backgammon_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

# ---------- turn flow ----------

func _start_new_game() -> void:
	result_recorded = false
	cpu_timer.stop()
	engine.new_game()
	end_dialog.visible = false
	dice = []
	rolled = []
	selected = -1
	legal = []
	turn = HUMAN
	_begin_human_turn()

func _begin_human_turn() -> void:
	turn = HUMAN
	dice = []
	rolled = []
	roll_btn.disabled = false
	undo_btn.disabled = true
	status_label.text = tr("Your turn — roll the dice.")
	board.queue_redraw()

func _on_roll() -> void:
	if turn != HUMAN or not dice.is_empty():
		return
	dice = BgEngine.roll_dice()
	rolled = dice.duplicate()
	turn_start = engine.state
	roll_btn.disabled = true
	_refresh_legal()
	if legal.is_empty():
		status_label.text = tr("No legal moves — turn passes.")
		dice = []
		_schedule_cpu(1.2)
	else:
		status_label.text = tr("Tap a white checker to move it.")
	board.queue_redraw()

func _refresh_legal() -> void:
	legal = BgEngine.legal_moves(engine.state, HUMAN, dice) if not dice.is_empty() else []
	undo_btn.disabled = engine.state == turn_start or turn != HUMAN

func _on_undo() -> void:
	if turn != HUMAN or turn_start.is_empty():
		return
	engine.state = turn_start
	dice = rolled.duplicate()
	selected = -1
	_refresh_legal()
	status_label.text = tr("Tap a white checker to move it.")
	board.queue_redraw()

func _targets_from(from: int) -> Array:
	var out: Array = []
	for m in legal:
		if m[0] == from:
			out.append(m)
	return out

func _do_human_move(m: Array) -> void:
	engine.state = BgEngine.apply(engine.state, HUMAN, m[0], m[1])
	dice.erase(m[1])
	selected = -1
	_refresh_legal()
	board.queue_redraw()
	if _check_winner():
		return
	if legal.is_empty():
		dice = []
		undo_btn.disabled = true
		status_label.text = tr("Computer's turn...")
		_schedule_cpu(0.8)

func _schedule_cpu(delay: float) -> void:
	turn = CPU
	undo_btn.disabled = true
	cpu_moves = []
	cpu_timer.wait_time = delay
	cpu_timer.start()

func _cpu_step() -> void:
	if turn != CPU:
		return
	if dice.is_empty() and cpu_moves.is_empty():
		dice = BgEngine.roll_dice()
		rolled = dice.duplicate()
		cpu_moves = BgEngine.best_turn(engine.state, CPU, dice)
		status_label.text = tr("Computer rolled %d and %d.") % [rolled[0], rolled[1]] if rolled.size() == 2 \
			else tr("Computer rolled double %d!") % rolled[0]
		board.queue_redraw()
		if cpu_moves.is_empty():
			status_label.text += " " + tr("No moves.")
			dice = []
			cpu_timer.wait_time = 1.2
			cpu_timer.start()
			turn = CPU
			cpu_moves = [null]   # marker: finish turn on the next tick
			return
		cpu_timer.wait_time = 0.9
		cpu_timer.start()
		return
	if cpu_moves.is_empty() or cpu_moves[0] == null:
		cpu_moves = []
		dice = []
		_begin_human_turn()
		return
	var m: Array = cpu_moves.pop_front()
	engine.state = BgEngine.apply(engine.state, CPU, m[0], m[1])
	dice.erase(m[1])
	board.queue_redraw()
	if _check_winner():
		return
	if cpu_moves.is_empty():
		cpu_moves = [null]
	cpu_timer.wait_time = 0.55
	cpu_timer.start()

func _check_winner() -> bool:
	var w := BgEngine.winner(engine.state)
	if w == -1:
		return false
	cpu_timer.stop()
	turn = -1
	var kind := BgEngine.win_kind(engine.state, w)
	var kinds := [tr("a single game"), tr("a gammon"), tr("a backgammon")]
	var msg: String
	if w == HUMAN:
		msg = tr("You win %s!") % kinds[kind - 1]
	else:
		msg = tr("The computer wins %s.") % kinds[kind - 1]
	msg += _record_result("win" if w == HUMAN else "loss")
	if info and w == HUMAN and kind > 1:
		info.add("Gammons won")
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	board.queue_redraw()
	return true

# ---------- geometry ----------
# Rows 0..11 run top to bottom. Left column row i = point 12 + i, right column
# row i = point 11 - i. The bar band sits between rows 5 and 6.

func _geom() -> Dictionary:
	var tray_h := 64.0
	var w: float = min(board.size.x - 24.0, 680.0)
	var h: float = board.size.y - tray_h * 2.0 - 8.0
	var bar_h: float = clamp(h * 0.07, 40.0, 70.0)
	var row_h: float = (h - bar_h) / 12.0
	var x0: float = (board.size.x - w) / 2.0
	var y0: float = tray_h + 4.0
	return {"x0": x0, "y0": y0, "w": w, "row_h": row_h, "bar_h": bar_h, "tray_h": tray_h, "col_w": w / 2.0 - 6.0}

func _row_y(g: Dictionary, row: int) -> float:
	return g.y0 + row * g.row_h + (g.bar_h if row >= 6 else 0.0)

func _point_row(point: int) -> Vector2i:
	# returns (column 0 = left / 1 = right, row)
	if point >= 12:
		return Vector2i(0, point - 12)
	return Vector2i(1, 11 - point)

func _point_at(g: Dictionary, pos: Vector2) -> int:
	var col := 0 if pos.x < g.x0 + g.w / 2.0 else 1
	var y: float = pos.y - g.y0
	var row := -1
	if y < 6 * g.row_h:
		row = int(y / g.row_h)
	elif y > 6 * g.row_h + g.bar_h:
		row = 6 + int((y - 6 * g.row_h - g.bar_h) / g.row_h)
	if row < 0 or row > 11:
		return -1
	return 12 + row if col == 0 else 11 - row

func _draw_board() -> void:
	if engine.state.is_empty():
		return
	var g := _geom()
	var s: Dictionary = engine.state
	var x0: float = g.x0
	var w: float = g.w
	var row_h: float = g.row_h
	var col_w: float = g.col_w
	var full_h: float = 12 * row_h + g.bar_h
	board.draw_rect(Rect2(x0 - 8, g.y0 - 8, w + 16, full_h + 16), COLOR_FRAME)
	board.draw_rect(Rect2(x0, g.y0, w, full_h), COLOR_FELT)
	# trays: black's borne-off checkers on top, white's below
	var top_tray := Rect2(x0, 0, w, g.tray_h - 6)
	var bottom_tray := Rect2(x0, g.y0 + full_h + 10, w, g.tray_h - 6)
	var bear_target: bool = selected >= 0 and _targets_from(selected).any(func(m): return m[0] - m[1] < 0)
	board.draw_rect(top_tray, Color(0.2, 0.15, 0.1))
	board.draw_rect(bottom_tray, Color(0.3, 0.45, 0.5) if bear_target else Color(0.2, 0.15, 0.1))
	_draw_tray_checkers(top_tray, s.off[CPU], COLOR_BLACK)
	_draw_tray_checkers(bottom_tray, s.off[HUMAN], COLOR_WHITE)
	if bear_target:
		board.draw_string(font, Vector2(bottom_tray.position.x, bottom_tray.get_center().y + 9), tr("Tap here to bear off"),
			HORIZONTAL_ALIGNMENT_RIGHT, bottom_tray.size.x - 12, 24, COLOR_HILITE)

	var targets: Array = []
	if selected >= 0:
		for m in _targets_from(selected):
			if m[0] - m[1] >= 0:
				targets.append(BgEngine.idx(HUMAN, m[0] - m[1]))
	var sources: Array = []
	for m in legal:
		if m[0] != BgEngine.BAR:
			sources.append(BgEngine.idx(HUMAN, m[0]))

	for point in 24:
		var cr := _point_row(point)
		var y := _row_y(g, cr.y)
		var base_x: float = x0 if cr.x == 0 else x0 + w
		var dir: float = 1.0 if cr.x == 0 else -1.0
		var tri_col := COLOR_TRI_A if point % 2 == 0 else COLOR_TRI_B
		if point in targets:
			tri_col = COLOR_HILITE
		var tip := Vector2(base_x + dir * col_w * 0.95, y + row_h / 2.0)
		board.draw_colored_polygon(PackedVector2Array([Vector2(base_x, y + 2), Vector2(base_x, y + row_h - 2), tip]), tri_col)
		var count: int = s.pts[point]
		var n: int = abs(count)
		if n == 0:
			continue
		var r: float = min(row_h * 0.44, col_w / 10.0)
		var shown: int = min(n, 5)
		for k in shown:
			var c := Vector2(base_x + dir * (r + 2 + k * r * 1.9), y + row_h / 2.0)
			_draw_checker(c, r, count > 0)
		if n > 5:
			var c := Vector2(base_x + dir * (r + 2 + 4 * r * 1.9), y + row_h / 2.0)
			board.draw_string(font, c + Vector2(-r, r * 0.4), str(n), HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 1.1),
				Color(0.1, 0.1, 0.1) if count > 0 else Color(1, 1, 1))
		var home_c := Vector2(base_x + dir * (r + 2), y + row_h / 2.0)
		if point in sources and turn == HUMAN:
			board.draw_arc(home_c, r + 3, 0, TAU, 28, Color(COLOR_HILITE, 0.6), 2)
		if selected >= 0 and selected != BgEngine.BAR and BgEngine.idx(HUMAN, selected) == point:
			board.draw_arc(home_c, r + 4, 0, TAU, 28, COLOR_HILITE, 5)

	# bar band with dice and checkers on the bar
	var band := Rect2(x0, g.y0 + 6 * row_h, w, g.bar_h)
	board.draw_rect(band, COLOR_FRAME.darkened(0.2))
	var br: float = g.bar_h * 0.36
	for k in s.bar[HUMAN]:
		_draw_checker(Vector2(x0 + br + 6 + k * br * 1.6, band.get_center().y), br, true)
	for k in s.bar[CPU]:
		_draw_checker(Vector2(x0 + w - br - 6 - k * br * 1.6, band.get_center().y), br, false)
	if selected == BgEngine.BAR:
		board.draw_arc(Vector2(x0 + br + 6, band.get_center().y), br + 4, 0, TAU, 28, COLOR_HILITE, 4)
	var ds: float = g.bar_h * 0.8
	var dx: float = x0 + w / 2.0 - (rolled.size() * (ds + 8)) / 2.0
	var remaining: Array = dice.duplicate()
	for i in rolled.size():
		var used: bool = not remaining.has(rolled[i])
		remaining.erase(rolled[i])
		_draw_die(Rect2(dx + i * (ds + 8), band.get_center().y - ds / 2.0, ds, ds), rolled[i], used)

func _draw_checker(c: Vector2, r: float, white: bool) -> void:
	board.draw_circle(c, r, COLOR_WHITE if white else COLOR_BLACK)
	board.draw_arc(c, r, 0, TAU, 24, Color(0.45, 0.45, 0.45), 1.5)
	board.draw_arc(c, r * 0.6, 0, TAU, 24, Color(0.6, 0.6, 0.6, 0.6), 1.0)

func _draw_tray_checkers(rect: Rect2, n: int, col: Color) -> void:
	for k in n:
		board.draw_rect(Rect2(rect.position.x + 8 + k * 14, rect.position.y + 6, 10, rect.size.y - 12), col)

func _draw_die(rect: Rect2, v: int, used: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.95, 0.95, 0.35 if used else 1.0)
	sb.set_corner_radius_all(6)
	board.draw_style_box(sb, rect)
	var pip_col := Color(0.1, 0.1, 0.1, 0.35 if used else 1.0)
	var spots := {1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
		5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}
	for sp in spots[v]:
		var p := rect.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * rect.size.x
		board.draw_circle(p, rect.size.x * 0.08, pip_col)

# ---------- input ----------

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if turn != HUMAN or legal.is_empty():
		return
	var g := _geom()
	var pos: Vector2 = event.position
	var full_h: float = 12 * g.row_h + g.bar_h
	# bottom tray = bear off
	if pos.y > g.y0 + full_h + 4 and selected >= 0:
		var offs := _targets_from(selected).filter(func(m): return m[0] - m[1] < 0)
		if not offs.is_empty():
			offs.sort_custom(func(a, b): return a[1] < b[1])
			_do_human_move(offs[0])
		return
	# bar band
	var band_y: float = g.y0 + 6 * g.row_h
	if pos.y >= band_y and pos.y <= band_y + g.bar_h:
		if engine.state.bar[HUMAN] > 0:
			selected = BgEngine.BAR
			board.queue_redraw()
		return
	var point := _point_at(g, pos)
	if point < 0:
		return
	var rel := BgEngine.idx(HUMAN, point)
	if selected >= 0:
		for m in _targets_from(selected):
			if m[0] - m[1] == rel:
				_do_human_move(m)
				return
	if not _targets_from(rel).is_empty():
		selected = rel
	elif engine.state.bar[HUMAN] > 0 and not _targets_from(BgEngine.BAR).is_empty():
		selected = BgEngine.BAR
	else:
		selected = -1
	board.queue_redraw()


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()
