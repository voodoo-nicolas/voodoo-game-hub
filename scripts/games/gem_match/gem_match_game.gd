extends Control

## Gem Match -- swipe a gem onto its neighbour (or tap one, then the other)
## to swap them. Make lines of 3+ before the clock runs out; matches add
## time, quick matches raise the multiplier, 4 in a row makes a bomb and
## 5 clears a whole colour. See gem_match_engine.gd for the rules.

const GMEngine = preload("res://scripts/games/gem_match/gem_match_engine.gd")
const HomeKit = preload("res://scripts/games/gem_match/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
## Skull mode skin. Loaded, never preloaded: packs also run on apps before
## v0.21, which keep the gems.
const VOODOO_PATH := "res://scripts/common/voodoo.gd"

const BEST_PATH := "user://gem_match_best.json"
const GEM_COLORS := [Color(0.95, 0.3, 0.35), Color(0.3, 0.65, 1), Color(0.35, 0.9, 0.45), Color(1, 0.85, 0.25),
	Color(0.75, 0.45, 1), Color(1, 0.55, 0.2)]
const SWAP_TIME := 0.13
const FLASH_TIME := 0.2
## Cells per second², for falling gems.
const GRAVITY := 70.0

enum State { IDLE, SWAP, SWAP_BACK, FLASH, FALL, OVER, READY }

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var Voodoo = load(VOODOO_PATH) if ResourceLoader.exists(VOODOO_PATH) else null
var voodoo_on: bool = false
var engine: GMEngine
var board: Control
var score_label: Label
var time_bar: ProgressBar
var time_label: Label
var mult_label: Label
var over_dialog: ColorRect
var start_dialog: ColorRect
var pause_dialog: ColorRect
var best: int = 0
var state: int = State.READY
var state_t: float = 0.0
var selected: int = -1
var hint_pair: Array = []
var press_cell: int = -1
var press_pos := Vector2.ZERO
var swap_pair: Array = []
var flashing: Array = []
var fall: Array = []          # rows still to fall, per cell (drawn above it)
var fall_speed: Array = []
var effects: Array = []       # {kind, pos (cell centre, in cells), t, life, ...}
var popups: Array = []        # {text, pos, t, color}

func _ready() -> void:
	preload("res://scripts/games/gem_match/gem_match_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = GMEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	voodoo_on = Voodoo != null and Voodoo.is_on()
	_build_ui()
	engine.reset()
	_reset_anim()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = HomeKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 16)
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
	title.text = tr("💎 Gem Match")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 24)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	# Score | multiplier
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 20)
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 20)
	sm.add_theme_constant_override("margin_right", 20)
	sm.add_child(stats)
	root.add_child(sm)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 34)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(score_label)
	mult_label = Label.new()
	mult_label.add_theme_font_size_override("font_size", 34)
	mult_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	mult_label.add_theme_constant_override("outline_size", 6)
	mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(mult_label)

	# The clock: a bar plus seconds left
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 20)
	tm.add_theme_constant_override("margin_right", 20)
	root.add_child(tm)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 12)
	tm.add_child(trow)
	time_bar = ProgressBar.new()
	time_bar.show_percentage = false
	time_bar.max_value = GMEngine.START_TIME
	time_bar.custom_minimum_size = Vector2(0, 22)
	time_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(1, 1, 1, 0.08)
	bg_sb.set_corner_radius_all(11)
	time_bar.add_theme_stylebox_override("background", bg_sb)
	trow.add_child(time_bar)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 30)
	time_label.custom_minimum_size = Vector2(70, 0)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trow.add_child(time_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_bottom", 30)
	rm.add_child(row)
	root.add_child(rm)
	var hint_btn := Button.new()
	hint_btn.text = tr("💡 Hint")
	hint_btn.custom_minimum_size = Vector2(220, 70)
	hint_btn.add_theme_font_size_override("font_size", 26)
	hint_btn.pressed.connect(_on_hint)
	row.add_child(hint_btn)

	start_dialog = UI.build_dialog(tr("💎 Gem Match"), [
		{"text": tr("Start"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	start_dialog.get_meta("message_label").text = tr("Beat the clock! Every match adds time. Match fast for a multiplier, 4 in a row for a bomb, 5 to clear a colour.")
	add_child(start_dialog)
	over_dialog = UI.build_dialog(tr("Time's up!"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(over_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	])
	add_child(pause_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/gem_match/gem_match_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best > 0:
			info.high("Best score", best)
	add_child(SettingsDrawer.new())
	_set_voodoo(voodoo_on)

## Skull mode: skulls, bones, voodoo dolls, sugar skulls, fire and an evil
## eye instead of gems. Called by the ⚙ drawer's toggle too.
func _set_voodoo(on: bool) -> void:
	voodoo_on = on and Voodoo != null
	var bg: ColorRect = get_node_or_null("Bg")
	if bg:
		bg.color = Voodoo.BG if voodoo_on else Color(0.08, 0.07, 0.13)
	if board:
		board.queue_redraw()

func _reset_anim() -> void:
	fall.resize(GMEngine.SIZE * GMEngine.SIZE)
	fall.fill(0.0)
	fall_speed.resize(GMEngine.SIZE * GMEngine.SIZE)
	fall_speed.fill(0.0)
	effects.clear()
	popups.clear()
	flashing = []
	swap_pair = []

func _start() -> void:
	engine.reset()
	_reset_anim()
	selected = -1
	hint_pair = []
	over_dialog.visible = false
	start_dialog.visible = false
	_set_state(State.IDLE)
	_update_info()

func _resume() -> void:
	pass  # the dialog closing is enough: the clock only runs while it's hidden

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and state != State.READY and state != State.OVER and home:
			home.pause()

func _set_state(s: int) -> void:
	state = s
	state_t = 0.0

func _update_info() -> void:
	score_label.text = tr("Score: %d") % engine.score
	time_label.text = str(ceili(engine.time_left))
	time_bar.max_value = maxf(GMEngine.START_TIME, engine.time_left)
	time_bar.value = engine.time_left
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(11)
	fill.bg_color = Color(0.35, 0.85, 0.45) if engine.time_left > 10.0 else Color(1, 0.35, 0.3)
	time_bar.add_theme_stylebox_override("fill", fill)
	if engine.multiplier > 1:
		mult_label.text = "×%d 🔥" % engine.multiplier
		mult_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3).lerp(Color(1, 0.4, 0.2), engine.multiplier / 8.0))
		mult_label.modulate.a = 0.45 + 0.55 * engine.multiplier_window()
	else:
		mult_label.text = "×1"
		mult_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		mult_label.modulate.a = 1.0

# ---------- the main loop: swap -> flash -> clear & fall -> repeat ----------

func _process(delta: float) -> void:
	var active: bool = state != State.READY and state != State.OVER and not pause_dialog.visible \
			and not (info and info.overlay and info.overlay.visible)
	if not active:
		return
	engine.tick(delta)
	state_t += delta
	match state:
		State.SWAP:
			if state_t >= SWAP_TIME:
				swap_pair = []
				_set_state(State.FLASH)
				flashing = engine.find_matches()
				if flashing.is_empty():
					_settled()
		State.SWAP_BACK:
			if state_t >= SWAP_TIME * 2.0:
				swap_pair = []
				_set_state(State.IDLE)
		State.FLASH:
			if state_t >= FLASH_TIME:
				_clear_and_drop()
		State.FALL:
			if _step_fall(delta):
				flashing = engine.find_matches()
				if flashing.is_empty():
					_settled()
				else:
					_set_state(State.FLASH)  # a chain!
		State.IDLE:
			if engine.time_left <= 0.0:
				_game_over()
	_step_effects(delta)
	_update_info()
	board.queue_redraw()

func _clear_and_drop() -> void:
	var res: Dictionary = engine.clear_matches()
	flashing = []
	var cs := GMEngine.SIZE
	for c in res.bombs:
		effects.append({"kind": "boom", "pos": Vector2(c % cs, c / cs) + Vector2(0.5, 0.5), "t": 0.0, "life": 0.45})
	for k in res.color_clears:
		effects.append({"kind": "flash", "color": GEM_COLORS[k], "t": 0.0, "life": 0.4})
	for c in res.cleared:
		effects.append({"kind": "spark", "pos": Vector2(c % cs, c / cs) + Vector2(0.5, 0.5), "t": 0.0, "life": 0.3,
			"color": Color(1, 1, 1)})
	if not res.cleared.is_empty():
		var centre := Vector2.ZERO
		for c in res.cleared:
			centre += Vector2(c % cs, c / cs) + Vector2(0.5, 0.5)
		centre /= res.cleared.size()
		var label := "+%ds" % int(res.time)
		if engine.chain > 1:
			label = tr("Chain ×%d!") % engine.chain + "  " + label
		popups.append({"text": label, "pos": centre, "t": 0.0, "color": Color(0.5, 1, 0.6)})
	var fell: Array = engine.collapse()
	for i in fell.size():
		if fell[i] > 0:
			fall[i] = float(fell[i])
			fall_speed[i] = 0.0
	_set_state(State.FALL)

## Moves every falling gem down; true once they've all landed.
func _step_fall(delta: float) -> bool:
	var moving := false
	for i in fall.size():
		if fall[i] > 0.0:
			fall_speed[i] += GRAVITY * delta
			fall[i] = maxf(0.0, fall[i] - fall_speed[i] * delta)
			moving = moving or fall[i] > 0.0
	return not moving

func _settled() -> void:
	_set_state(State.IDLE)
	if not engine.has_moves():
		engine.reshuffle()
		popups.append({"text": tr("No moves — shuffled!"), "pos": Vector2(4, 4), "t": 0.0, "color": Color(1, 0.85, 0.4)})

func _game_over() -> void:
	_set_state(State.OVER)
	if engine.score > best:
		best = engine.score
		SaveUtil.write(BEST_PATH, {"best": best})
	if info:
		info.add("Games played")
		info.best("Best score", best)
		info.high("Longest chain", engine.best_chain)
	over_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score + "\n" + tr("Best: %d") % best
	over_dialog.visible = true

func _step_effects(delta: float) -> void:
	for list in [effects, popups]:
		for i in range(list.size() - 1, -1, -1):
			list[i].t += delta
			if list[i].t >= list[i].get("life", 0.9):
				list.remove_at(i)

func _attempt(a: int, b: int) -> void:
	selected = -1
	hint_pair = []
	swap_pair = [a, b]
	if engine.try_swap(a, b):
		_set_state(State.SWAP)
	else:
		_set_state(State.SWAP_BACK)

func _on_hint() -> void:
	if state == State.IDLE:
		hint_pair = engine.hint()
		board.queue_redraw()

# ---------- drawing ----------

func _cell() -> float:
	return floor(min(board.size.x - 24.0, board.size.y - 8.0) / GMEngine.SIZE)

func _origin() -> Vector2:
	var c := _cell() * GMEngine.SIZE
	return Vector2((board.size.x - c) / 2.0, (board.size.y - c) / 2.0)

func _cell_pos(i: int) -> Vector2:
	return Vector2(i % GMEngine.SIZE, i / GMEngine.SIZE)

func _draw_board() -> void:
	if engine.grid.is_empty():
		return
	var cs := _cell()
	var o := _origin()
	var n := GMEngine.SIZE
	var board_rect := Rect2(o, Vector2(cs, cs) * n)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.set_corner_radius_all(int(cs * 0.2))
	board.draw_style_box(sb, board_rect.grow(6))
	for i in n * n:
		var p := o + _cell_pos(i) * cs
		board.draw_rect(Rect2(p, Vector2(cs, cs)), Color(1, 1, 1, 0.03 if (i + i / n) % 2 == 0 else 0.07))
	for i in n * n:
		if i == selected or i in hint_pair:
			var p := o + _cell_pos(i) * cs
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
			board.draw_rect(Rect2(p, Vector2(cs, cs)).grow(-2), Color(1, 1, 1, pulse), false, 3.0)
	var t := Time.get_ticks_msec() / 1000.0
	for i in n * n:
		var k: int = engine.grid[i]
		if k == GMEngine.EMPTY:
			continue
		var cell := _cell_pos(i) - Vector2(0, fall[i])
		# swap animation: the two gems slide past each other
		if swap_pair.size() == 2 and (i == swap_pair[0] or i == swap_pair[1]):
			var other: int = swap_pair[1] if i == swap_pair[0] else swap_pair[0]
			var k2: float = clampf(state_t / SWAP_TIME, 0.0, 1.0)
			if state == State.SWAP:
				cell = _cell_pos(other).lerp(_cell_pos(i), k2)  # already swapped in the engine
			elif state == State.SWAP_BACK:
				# a swap that makes no match: nudge halfway over, then back
				var there: float = clampf(state_t / SWAP_TIME, 0.0, 1.0) if state_t < SWAP_TIME else clampf(2.0 - state_t / SWAP_TIME, 0.0, 1.0)
				cell = _cell_pos(i).lerp(_cell_pos(other), there * 0.5)
		var centre := o + (cell + Vector2(0.5, 0.5)) * cs
		if centre.y < o.y - cs * 0.5:
			continue  # still above the board
		var r := cs * 0.38
		var flash := i in flashing
		if flash:
			r *= 1.0 + 0.25 * sin(clampf(state_t / FLASH_TIME, 0.0, 1.0) * PI)
		_draw_piece(centre, r, k, flash, t)
	for e in effects:
		var a: float = 1.0 - e.t / e.life
		match e.kind:
			"boom":
				var c: Vector2 = o + e.pos * cs
				board.draw_circle(c, cs * 1.5 * (e.t / e.life), Color(1, 0.6, 0.2, a * 0.5))
				board.draw_arc(c, cs * 1.6 * (e.t / e.life), 0, TAU, 32, Color(1, 0.9, 0.5, a), 4.0, true)
			"flash":
				board.draw_rect(board_rect, Color(e.color, a * 0.35))
			"spark":
				var c2: Vector2 = o + e.pos * cs
				for s in 4:
					var dir := Vector2.RIGHT.rotated(s * PI / 2.0 + PI / 4.0)
					board.draw_line(c2 + dir * cs * 0.15, c2 + dir * cs * (0.15 + 0.4 * e.t / e.life), Color(e.color, a), 3.0)
	var font: Font = ThemeDB.fallback_font
	for p in popups:
		var a2: float = 1.0 - p.t / 0.9
		var pos: Vector2 = o + p.pos * cs - Vector2(cs * 3, cs * 0.6 * p.t / 0.9)
		board.draw_string_outline(font, pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, cs * 6, int(cs * 0.45), 6, Color(0, 0, 0, a2))
		board.draw_string(font, pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, cs * 6, int(cs * 0.45), Color(p.color, a2))

func _draw_piece(c: Vector2, r: float, kind: int, flash: bool, t: float) -> void:
	if kind == GMEngine.BOMB:
		_draw_bomb(c, r, t)
		return
	if voodoo_on:
		_draw_voodoo_piece(c, r, kind, flash, t)
		return
	var col: Color = Color(1, 1, 1) if flash else GEM_COLORS[kind]
	var sides: int = [0, 4, 3, 6, 5, 8][kind]
	if sides == 0:
		board.draw_circle(c, r, col)
	else:
		var pts := PackedVector2Array()
		var rot := -PI / 2.0 if sides != 4 else 0.0
		for k in sides:
			var a := rot + TAU * k / sides
			pts.append(c + Vector2(cos(a), sin(a)) * r * (1.1 if sides == 3 else 1.0))
		board.draw_colored_polygon(pts, col.darkened(0.15))
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * 0.7)
		board.draw_colored_polygon(inner, col)
	board.draw_circle(c - Vector2(r * 0.3, r * 0.3), r * 0.2, Color(1, 1, 1, 0.45))

## A round black bomb with a fizzing fuse: the wildcard.
func _draw_bomb(c: Vector2, r: float, t: float) -> void:
	board.draw_circle(c + Vector2(0, r * 0.1), r * 0.85, Color(0.12, 0.12, 0.15))
	board.draw_circle(c + Vector2(-r * 0.3, -r * 0.15), r * 0.22, Color(1, 1, 1, 0.3))
	board.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.85), Vector2(r * 0.4, r * 0.25)), Color(0.35, 0.35, 0.4))
	var fuse_end := c + Vector2(r * 0.35, -r * 1.05)
	board.draw_line(c + Vector2(0, -r * 0.8), fuse_end, Color(0.8, 0.7, 0.5), maxf(2.0, r * 0.1))
	var spark := 0.6 + 0.4 * sin(t * 25.0)
	board.draw_circle(fuse_end, r * 0.2 * spark, Color(1, 0.8, 0.2))
	board.draw_circle(fuse_end, r * 0.1 * spark, Color(1, 1, 0.8))
	# rainbow ring: it matches anything
	for k in 6:
		board.draw_arc(c + Vector2(0, r * 0.1), r * 0.95, TAU * k / 6.0 + t, TAU * (k + 1) / 6.0 + t, 6, GEM_COLORS[k], maxf(2.0, r * 0.1), true)

func _draw_voodoo_piece(c: Vector2, r: float, kind: int, flash: bool, t: float) -> void:
	var s := r * 2.2
	var rim := Color(0, 0, 0, 0.6)
	var tint: Color = Color(1, 1, 1) if flash else GEM_COLORS[kind]
	match kind:
		0:  # skull
			Voodoo.draw_skull(board, c, s, Voodoo.BONE.lerp(tint, 0.15), Voodoo.INK, rim)
		1:  # crossbones
			Voodoo.draw_crossbones(board, c, s, Voodoo.BONE.lerp(tint, 0.35), rim)
		2:  # voodoo doll
			Voodoo.draw_doll(board, c, s, Color(0.85, 0.75, 0.55).lerp(tint, 0.25), Voodoo.INK, rim)
		3:  # sugar skull: a bright skull with flower eyes
			Voodoo.draw_skull(board, c, s, Color(1, 0.75, 0.9).lerp(tint, 0.2), Color(0.35, 0.05, 0.3), rim)
			for x in [-0.13, 0.13]:
				var e := c + Vector2(x, -0.04) * s
				for p in 5:
					board.draw_circle(e + Vector2(s * 0.05, 0).rotated(TAU * p / 5.0), s * 0.03, Color(1, 0.85, 0.25))
			board.draw_circle(c + Vector2(0, -0.27) * s, s * 0.05, Color(0.3, 0.85, 0.5))
		4:  # fire
			_draw_flame(c, s, t, flash)
		_:  # evil eye
			board.draw_circle(c, r * 0.95, Color(0.15, 0.25, 0.75) if not flash else tint)
			board.draw_circle(c, r * 0.72, Color(1, 1, 1))
			board.draw_circle(c, r * 0.45, Color(0.35, 0.6, 1))
			board.draw_circle(c, r * 0.22, Color(0.05, 0.05, 0.1))
			board.draw_circle(c + Vector2(-r * 0.15, -r * 0.15), r * 0.08, Color(1, 1, 1, 0.8))

func _draw_flame(c: Vector2, s: float, t: float, flash: bool) -> void:
	var flick := sin(t * 12.0 + c.x) * 0.05
	for layer in [[1.0, Color(1, 0.35, 0.1)], [0.68, Color(1, 0.7, 0.15)], [0.38, Color(1, 0.95, 0.6)]]:
		var k: float = layer[0]
		var col: Color = Color(1, 1, 1) if flash else layer[1]
		var pts := PackedVector2Array()
		var steps := 14
		for i in steps + 1:
			var a := PI * i / steps  # bottom half: round base
			pts.append(c + Vector2(cos(a), sin(a) * 0.9) * s * 0.3 * k + Vector2(0, s * 0.12))
		pts.append(c + Vector2(-s * 0.18 * k, -s * 0.1 * k))
		pts.append(c + Vector2((flick - 0.02) * s, -s * 0.45 * k))
		pts.append(c + Vector2(s * 0.12 * k, -s * 0.15 * k))
		board.draw_colored_polygon(pts, col)

# ---------- input ----------

func _cell_at(pos: Vector2) -> int:
	var p: Vector2 = (pos - _origin()) / _cell()
	var c := floori(p.x)
	var r := floori(p.y)
	if r < 0 or c < 0 or r >= GMEngine.SIZE or c >= GMEngine.SIZE:
		return -1
	return r * GMEngine.SIZE + c

func _on_board_input(event: InputEvent) -> void:
	if state != State.IDLE or over_dialog.visible or start_dialog.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_cell = _cell_at(event.position)
			press_pos = event.position
		elif press_cell >= 0:
			var d: Vector2 = event.position - press_pos
			if d.length() > _cell() * 0.4:
				_swipe_from(press_cell, d)
			elif selected >= 0 and GMEngine.adjacent(selected, press_cell):
				_attempt(selected, press_cell)
			else:
				selected = -1 if selected == press_cell else press_cell
				board.queue_redraw()
			press_cell = -1
	elif event is InputEventMouseMotion and press_cell >= 0:
		# Swap as soon as the finger has clearly moved -- no need to let go.
		var d2: Vector2 = event.position - press_pos
		if d2.length() > _cell() * 0.55:
			_swipe_from(press_cell, d2)
			press_cell = -1

func _swipe_from(cell: int, d: Vector2) -> void:
	var n := cell
	if abs(d.x) > abs(d.y):
		n += 1 if d.x > 0 else -1
	else:
		n += GMEngine.SIZE if d.y > 0 else -GMEngine.SIZE
	if n >= 0 and n < GMEngine.SIZE * GMEngine.SIZE and GMEngine.adjacent(cell, n):
		_attempt(cell, n)

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/gem_match/gem_match_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/gem_match/gem_match_help.gd"),
		"info": info,
		"accent": HomeKit.MAGENTA,
		"subtitle": "Swap gems to line up three or more. Race the clock!",
		"logo": _draw_home_logo,
		"modes": [{"text": "💎  Play", "sub": "Beat the clock", "action": _start}],
		"restart": _start,
		"board_note": "Your best score.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var r := minf(c.size.y / 6.5, 26.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	var cols := [HomeKit.MAGENTA, HomeKit.MAGENTA, HomeKit.CYAN, HomeKit.MAGENTA, HomeKit.LIME, HomeKit.GOLD, HomeKit.CYAN, HomeKit.LIME, HomeKit.PURPLE]
	for i in 9:
		var p := ctr + Vector2((i % 3 - 1) * r * 2.7, (int(i / 3) - 1) * r * 2.7)
		var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		c.draw_colored_polygon(pts, Color(cols[i], 0.25))
		HomeKit.glow_polyline(c, pts, cols[i], 2.0, true)
