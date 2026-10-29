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
## Neon gem colours (ART_STYLE.md palette), one hue per gem kind.
const GEM_COLORS := [Color("ff3b6b"), Color("29e6ff"), Color("7dff3a"), Color("ffd23a"),
	Color("9b4dff"), Color("ff8a2b")]
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
	var deco := Control.new()
	deco.name = "Deco"
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(_draw_backdrop.bind(deco))
	deco.resized.connect(deco.queue_redraw)
	bg.add_child(deco)

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
## The kit's Look (Options): "classic" = the retro-arcade screen filter
## (flat primaries, no glow), "voodoo" = skulls and dolls on neon.
func _set_skin(name: String) -> void:
	var v: bool = name == "voodoo"
	_set_voodoo(v)
	if home:
		home._set_retro(false)  # the retro filter flattened the gems to blobs; Classic = the cut stones

func _set_voodoo(on: bool) -> void:
	voodoo_on = on and Voodoo != null
	var bg: ColorRect = get_node_or_null("Bg")
	if bg:
		bg.color = Voodoo.BG if voodoo_on else Color(0.08, 0.07, 0.13)
		var deco: Control = bg.get_node_or_null("Deco")
		if deco:
			deco.visible = not voodoo_on
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
	_sfx("explode" if not res.bombs.is_empty() else ("powerup" if engine.chain > 1 else "merge"))
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
		_sfx("slide")
		_set_state(State.SWAP)
	else:
		_sfx("invalid")
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
	# A dark glass panel with a neon frame and a faint cell grid.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.08, 0.78)
	sb.set_corner_radius_all(int(cs * 0.2))
	sb.border_color = Color(HomeKit.PURPLE, 0.85)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(HomeKit.PURPLE, 0.3)
	sb.shadow_size = 14
	board.draw_style_box(sb, board_rect.grow(8))
	for k in range(1, n):
		var a := Color(HomeKit.BLUE, 0.13)
		board.draw_line(o + Vector2(k * cs, 0), o + Vector2(k * cs, n * cs), a, 1.0)
		board.draw_line(o + Vector2(0, k * cs), o + Vector2(n * cs, k * cs), a, 1.0)
	for i in n * n:
		if i == selected or i in hint_pair:
			var p := o + _cell_pos(i) * cs
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
			HomeKit.glow_rect(board, Rect2(p, Vector2(cs, cs)).grow(-3), Color(HomeKit.WHITE, pulse), 2.0)
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
	_flush()
	for e in effects:
		var a: float = 1.0 - e.t / e.life
		match e.kind:
			"boom":
				var c: Vector2 = o + e.pos * cs
				_disc(c, cs * 1.5 * (e.t / e.life), Color(1, 0.6, 0.2, a * 0.5))
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
	_draw_jewel(c, r, kind, flash, t)

## Classic gems: six cut stones, each its own colour and shape, shaded facet by facet
## with the light from the top left (ruby, sapphire, emerald, topaz, amethyst, amber).
const JEWELS := [Color("e0143c"), Color("2563eb"), Color("10b055"), Color("f5c518"), Color("9a46e0"), Color("ff7a1a")]

## Outline of each cut around centre c, radius r.
func _jewel_outline(kind: int, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = [10, 8, 3, 4, 6, 5][kind]
	var rot: float = [-PI / 2.0, PI / 8.0, -PI / 2.0, -PI / 2.0, 0.0, -PI / 2.0][kind]
	var sx: float = [1.0, 0.9, 1.0, 0.82, 1.0, 1.0][kind]
	var rr: float = r * [1.0, 1.04, 1.18, 1.1, 1.0, 1.04][kind]
	var shift := Vector2(0, r * 0.12) if kind == 2 else Vector2.ZERO
	for k in n:
		var a := rot + TAU * k / n
		pts.append(c + shift + Vector2(cos(a) * sx, sin(a)) * rr)
	return pts

func _draw_jewel(c: Vector2, r: float, kind: int, flash: bool, t: float) -> void:
	var base: Color = Color(1, 1, 1) if flash else JEWELS[kind]
	var outer := _jewel_outline(kind, c, r)
	var n := outer.size()
	var mid := Vector2.ZERO
	for q in outer:
		mid += q / n
	_disc(mid + Vector2(r * 0.08, r * 0.16), r * 1.0, Color(0, 0, 0, 0.28))
	var inner := PackedVector2Array()
	for q in outer:
		inner.append(mid + (q - mid) * 0.52)
	var light := Vector2.from_angle(-3.0 * PI / 4.0)
	for k in n:
		var k2 := (k + 1) % n
		var normal := ((outer[k] + outer[k2]) / 2.0 - mid).normalized()
		var b: float = normal.dot(light)
		var col: Color = base.lerp(Color.WHITE, 0.45 * maxf(b, 0.0)) if b > 0.0 else base.darkened(0.12 + 0.38 * -b)
		_fan(PackedVector2Array([outer[k], outer[k2], inner[k2], inner[k]]), col)
	_fan(inner, base.lightened(0.2))
	# a bright slice across the table, the stone's main reflection
	var slice := PackedVector2Array([inner[0], inner[1], mid])
	if n > 2:
		slice = PackedVector2Array([inner[n - 1], inner[0], mid])
	_fan(slice, Color(1, 1, 1, 0.3))
	var line_w := maxf(1.5, r * 0.07)
	for k in n:
		_seg(outer[k], inner[k], base.darkened(0.45), maxf(1.0, r * 0.03), true)
	_strip(inner + PackedVector2Array([inner[0]]), Color(1, 1, 1, 0.45), maxf(1.0, r * 0.04), true)
	_strip(outer + PackedVector2Array([outer[0]]), base.darkened(0.6), line_w, true)
	_dots.append([mid + Vector2(-r * 0.3, -r * 0.34), r * 0.11, Color(1, 1, 1, 0.9)])
	# a twinkle that comes round every few seconds, each stone out of step
	var tw: float = pow(maxf(0.0, sin(t * 1.7 + kind * 1.9 + mid.x * 0.02)), 14.0)
	if tw > 0.05:
		var sp := mid + Vector2(r * 0.25, -r * 0.4)
		var L := r * 0.5 * tw
		_seg(sp - Vector2(L, 0), sp + Vector2(L, 0), Color(1, 1, 1, tw), 2.0, true)
		_seg(sp - Vector2(0, L), sp + Vector2(0, L), Color(1, 1, 1, tw), 2.0, true)

# ---------- cheap drawing (2026-10-29) ----------
# In Godot 4.7 every draw_circle / draw_arc / draw_polyline / draw_colored_polygon call costs 60-110 µs (each one
# makes its own GPU buffer), while a texture rect costs 0.5 µs and one draw_multiline ~12 µs however many segments
# it holds. A full board of Classic gems made ~1,300 such calls a frame (11 fps on a weak GPU). So the gems'
# facets go into one triangle array, their edges into one draw_multiline_colors per line width, circles are a
# white disc texture, and the highlights are drawn last; `_flush` draws the lot after the board's gems.
# Antialiased multiline segments overlap at their joints, which shows as bright dots on see-through colours, so
# only solid colours are antialiased.

var _tri_pts := PackedVector2Array()
var _tri_cols := PackedColorArray()
var _tri_idx := PackedInt32Array()
var _seg_pts := {}  # Vector2(width, antialiased 0/1) -> PackedVector2Array of segment ends
var _seg_cols := {}  # same key -> PackedColorArray, one per segment
var _dots: Array = []  # [centre, radius, colour]: the gems' highlights, drawn over everything else
static var _disc_tex: Array = []  # white discs, 16 / 64 / 256 px (the closest size keeps the edge sharp)

func _disc_texture(px: float) -> Texture2D:
	if _disc_tex.is_empty():
		for sz in [16, 64, 256]:
			var g := Gradient.new()
			g.set_offset(0, 0.0)
			g.set_color(0, Color.WHITE)
			g.set_offset(1, 1.0)
			g.set_color(1, Color(1, 1, 1, 0))
			g.add_point(1.0 - 2.0 / float(sz), Color.WHITE)  # solid to one texel from the rim
			var tex := GradientTexture2D.new()
			tex.gradient = g
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(1.0, 0.5)
			tex.width = sz
			tex.height = sz
			_disc_tex.append(tex)
	if px <= 16.0:
		return _disc_tex[0]
	return _disc_tex[1] if px <= 64.0 else _disc_tex[2]

## A filled circle (like draw_circle), drawn at once on `ci` (the board if null).
func _disc(c: Vector2, r: float, col: Color, ci: CanvasItem = null) -> void:
	if r > 0.0:
		var tex := _disc_texture(r * 2.0)
		r /= 1.0 - 1.0 / float(tex.get_width())  # the texture's soft rim straddles the circle's edge
		(ci if ci else board).draw_texture_rect(tex, Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), false, col)

static var _glow_tex := {}  # alpha scale -> the 14 stacked discs of a backdrop glow, as one stepped texture

## 14 discs of colour `col` round `c`, radius r0, r0 + step ... r0 + 13 step, each 0.045 alpha (fading out
## with k, times `k_alpha`), drawn as one texture rect.
func _glow(ci: CanvasItem, c: Vector2, r0: float, step: float, k_alpha: float, col: Color) -> void:
	var rmax := r0 + 13.0 * step
	var key := Vector3(r0 / rmax, step / rmax, k_alpha)
	if not _glow_tex.has(key):
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var alphas := []
		for k in 14:
			alphas.append(0.045 * (1.0 - k / 14.0) * k_alpha)
		# Between disc j-1's rim and disc j's, discs j..13 cover the spot.
		var through := 1.0
		var covered := []
		for j in range(13, -1, -1):
			through *= 1.0 - alphas[j]
			covered.push_front(1.0 - through)
		g.set_offset(0, 0.0)
		g.set_color(0, Color(1, 1, 1, covered[0]))
		g.set_offset(1, 1.0)
		g.set_color(1, Color(1, 1, 1, 0))
		for j in range(1, 14):
			g.add_point(key.x + key.y * (j - 1), Color(1, 1, 1, covered[j]))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 1024
		tex.height = 1024
		_glow_tex[key] = tex
	ci.draw_texture_rect(_glow_tex[key], Rect2(c - Vector2(rmax, rmax), Vector2(rmax, rmax) * 2.0), false, col)

## A convex polygon (like draw_colored_polygon), batched.
func _fan(pts: PackedVector2Array, col: Color) -> void:
	var base := _tri_pts.size()
	for p in pts:
		_tri_pts.append(p)
		_tri_cols.append(col)
	for k in range(1, pts.size() - 1):
		_tri_idx.append(base)
		_tri_idx.append(base + k)
		_tri_idx.append(base + k + 1)

## Any simple polygon (like draw_colored_polygon), batched.
func _poly(pts: PackedVector2Array, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	var base := _tri_pts.size()
	for p in pts:
		_tri_pts.append(p)
		_tri_cols.append(col)
	for i in tris:
		_tri_idx.append(base + i)

## A line through the points (like draw_polyline), batched.
func _strip(pts: PackedVector2Array, col: Color, w: float = -1.0, aa: bool = false) -> void:
	var n := pts.size()
	if n < 2:
		return
	var key := Vector2(w, 1.0 if aa and col.a >= 0.99 else 0.0)
	if not _seg_pts.has(key):
		_seg_pts[key] = PackedVector2Array()
		_seg_cols[key] = PackedColorArray()
	var sp: PackedVector2Array = _seg_pts[key]
	var sc: PackedColorArray = _seg_cols[key]
	for i in range(1, n):
		sp.append(pts[i - 1])
		sp.append(pts[i])
		sc.append(col)

## One line (like draw_line), batched.
func _seg(a: Vector2, b: Vector2, col: Color, w: float = -1.0, aa: bool = false) -> void:
	_strip(PackedVector2Array([a, b]), col, w, aa)

## Draws the batch: facets, then edges (widest first), then highlights.
func _flush() -> void:
	if not _tri_idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(board.get_canvas_item(), _tri_idx, _tri_pts, _tri_cols)
		_tri_idx.clear()
		_tri_pts.clear()
		_tri_cols.clear()
	var keys: Array = _seg_pts.keys()
	keys.sort_custom(_wider)
	for k in keys:
		board.draw_multiline_colors(_seg_pts[k], _seg_cols[k], k.x, k.y > 0.5)
	_seg_pts.clear()
	_seg_cols.clear()
	for d in _dots:
		_disc(d[0], d[1], d[2])
	_dots.clear()

static func _wider(a: Vector2, b: Vector2) -> bool:
	return a.x > b.x

## Backdrop for the classic skin: a violet-to-teal gradient, a soft lattice, two glows
## and a scatter of stars (the same every time, so nothing shimmers on redraw).
func _draw_backdrop(d: Control) -> void:
	var sz := d.size
	var top := Color(0.13, 0.06, 0.26)
	var bot := Color(0.02, 0.12, 0.2)
	d.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]), PackedColorArray([top, top, bot, bot]))
	# Two glows, each 14 faint discs (0.045 alpha, fading out) one inside the other. They were 28 draw_circles
	# nearly the size of the screen: ~27 ms of GPU fill a frame on a weak GPU. Discs of one colour stacked up
	# are one disc with stepped alpha, so each glow is now a single texture of those steps (2026-10-29).
	_glow(d, Vector2(sz.x * 0.5, sz.y * 0.58), sz.x * 0.18, sz.x * 0.05, 1.0, Color(0.75, 0.2, 0.85))
	_glow(d, Vector2(sz.x * 0.12, sz.y * 0.1), sz.x * 0.08, sz.x * 0.04, 0.8, Color(0.1, 0.8, 1.0))
	var step := 96.0
	var x := -sz.y
	while x < sz.x:
		d.draw_line(Vector2(x, 0), Vector2(x + sz.y, sz.y), Color(1, 1, 1, 0.035), 1.0)
		d.draw_line(Vector2(x + sz.y, 0), Vector2(x, sz.y), Color(1, 1, 1, 0.035), 1.0)
		x += step
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 70:
		var p := Vector2(rng.randf() * sz.x, rng.randf() * sz.y)
		var s := rng.randf_range(1.0, 2.6)
		_disc(p, s, Color(1, 1, 1, rng.randf_range(0.2, 0.6)), d)
		if k % 9 == 0:
			d.draw_line(p - Vector2(s * 4, 0), p + Vector2(s * 4, 0), Color(1, 1, 1, 0.35), 1.0)
			d.draw_line(p - Vector2(0, s * 4), p + Vector2(0, s * 4), Color(1, 1, 1, 0.35), 1.0)

## A round black bomb with a fizzing fuse: the wildcard.
func _draw_bomb(c: Vector2, r: float, t: float) -> void:
	_disc(c + Vector2(0, r * 0.1), r * 0.85, Color(0.04, 0.03, 0.08))
	HomeKit.glow_circle(board, c + Vector2(0, r * 0.1), r * 0.85, HomeKit.WHITE, maxf(1.5, r * 0.07))
	_disc(c + Vector2(-r * 0.3, -r * 0.15), r * 0.16, Color(1, 1, 1, 0.6))
	HomeKit.glow_rect(board, Rect2(c + Vector2(-r * 0.2, -r * 0.85), Vector2(r * 0.4, r * 0.22)), HomeKit.PURPLE, maxf(1.0, r * 0.05), 0.4)
	var fuse_end := c + Vector2(r * 0.35, -r * 1.05)
	HomeKit.glow_line(board, c + Vector2(0, -r * 0.8), fuse_end, HomeKit.GOLD, maxf(1.5, r * 0.07))
	var spark := 0.6 + 0.4 * sin(t * 25.0)
	_disc(fuse_end, r * 0.2 * spark, Color(1, 0.8, 0.2))
	_disc(fuse_end, r * 0.1 * spark, Color(1, 1, 0.8))
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
					_disc(e + Vector2(s * 0.05, 0).rotated(TAU * p / 5.0), s * 0.03, Color(1, 0.85, 0.25))
			_disc(c + Vector2(0, -0.27) * s, s * 0.05, Color(0.3, 0.85, 0.5))
		4:  # fire
			_draw_flame(c, s, t, flash)
		_:  # evil eye
			_disc(c, r * 0.95, Color(0.15, 0.25, 0.75) if not flash else tint)
			_disc(c, r * 0.72, Color(1, 1, 1))
			_disc(c, r * 0.45, Color(0.35, 0.6, 1))
			_disc(c, r * 0.22, Color(0.05, 0.05, 0.1))
			_disc(c + Vector2(-r * 0.15, -r * 0.15), r * 0.08, Color(1, 1, 1, 0.8))

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
		_poly(pts, col)

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

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
