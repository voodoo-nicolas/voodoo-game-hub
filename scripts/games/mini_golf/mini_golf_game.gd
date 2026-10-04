extends Control

## Mini Golf: 18 holes of neon crazy golf. Pull back anywhere on the green
## (like a slingshot) and let go to putt. Solo, or 2-4 players taking turns
## on one phone.

const MgEngine = preload("res://scripts/games/mini_golf/mini_golf_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/mini_golf/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/mini_golf/mini_golf_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://mini_golf_save.json"

const COURSE_NAMES := ["Front 9", "Back 9", "18 holes"]
const BALL_COLORS := [Color("29e6ff"), Color("ff2bd6"), Color("7dff3a"), Color("ffae2b")]
const GREEN := Color("7dff3a")
const WALL := Color("9b4dff")
const SAND := Color("ffae2b")
const WATER := Color("3a8cff")
const BUMPER := Color("ff4f9a")
const MILL := Color("ff2bd6")
const GATE := Color("29e6ff")
const PULL_FULL := 260.0      # screen pixels of pull for a full-power putt

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var course: int = 0
var players: int = 1
var pos_in_course: int = 0    # which hole of the course
var cur: int = 0              # whose turn
var scores: Array = []        # [player][hole of course] = strokes, -1 = not played
var started := false
var phase := "aim"            # aim, roll, holed, card, over
var phase_t: float = 0.0
var pulling := false
var pull_from := Vector2.ZERO
var pull_to := Vector2.ZERO
var trail: Array = []
var bump_flash: Dictionary = {}
var banner := ""
var banner_t: float = 0.0
var round_recorded := false

var field: Control
var hole_label: Label
var turn_label: Label
var card: Control
var card_title: Label
var card_grid: GridContainer
var card_totals: Label
var card_btn: Button

func _ready() -> void:
	preload("res://scripts/games/mini_golf/mini_golf_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MgEngine.new()
	engine.load_hole(0)
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
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
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	bar.add_child(mid)
	hole_label = HomeKit.label("", 28, GREEN.lerp(Color.WHITE, 0.4), false, true)
	mid.add_child(hole_label)
	turn_label = HomeKit.label("", 22, HomeKit.DIM, false, true)
	mid.add_child(turn_label)
	var card_btn_top := Button.new()
	card_btn_top.text = "📋"
	card_btn_top.custom_minimum_size = Vector2(76, 64)
	card_btn_top.pressed.connect(_show_card.bind(false))
	bar.add_child(card_btn_top)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(56, 0)
	bar.add_child(spacer)

	var fm := MarginContainer.new()
	fm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fm.add_theme_constant_override("margin_left", 6)
	fm.add_theme_constant_override("margin_right", 6)
	fm.add_theme_constant_override("margin_bottom", 24)
	root.add_child(fm)
	field = Control.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	fm.add_child(field)

	_build_card()

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": GREEN,
		"solo_heading": "Solo",
		"multi_heading": "Pass the phone",
		"subtitle": "Windmills, bumpers, water and sand. Pull back, let go, sink it.",
		"logo": _draw_home_logo,
		"extra": _add_course_picker,
		"modes": [
			{"text": "⛳  Play", "sub": "Just you", "action": _new_game.bind(1)},
			{"text": "2 Players", "row": "multi", "multi": true, "action": _new_game.bind(2)},
			{"text": "3 Players", "row": "multi", "multi": true, "action": _new_game.bind(3)},
			{"text": "4 Players", "row": "multi", "multi": true, "action": _new_game.bind(4)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Birdies or better",
		"board_note": "Holes you finished under par, in any round.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.05)  # top right, beside the hole number
	add_child(drawer)

func _add_course_picker(box: VBoxContainer) -> void:
	box.add_child(home.section("Course"))
	box.add_child(home.choice_row(COURSE_NAMES, course, _pick_course, GREEN))

func _pick_course(i: int) -> void:
	course = i

func _build_card() -> void:
	card = ColorRect.new()
	card.color = Color(0, 0, 0, 0.75)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HomeKit.neon_box(GREEN))
	center.add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	card_title = HomeKit.label("", 34, GREEN.lerp(Color.WHITE, 0.3), true, true)
	card_title.custom_minimum_size.x = 520
	v.add_child(card_title)
	card_grid = GridContainer.new()
	card_grid.add_theme_constant_override("h_separation", 4)
	card_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(card_grid)
	card_totals = HomeKit.label("", 24, HomeKit.WHITE, true, true)
	v.add_child(card_totals)
	card_btn = HomeKit.neon_button("", GREEN, 28, 80)
	card_btn.pressed.connect(_on_card_button)
	v.add_child(card_btn)

# ---------- flow ----------

func _holes() -> Array:
	var r: Array = MgEngine.COURSES[course]
	return range(r[0], r[1])

func _new_game(n: int) -> void:
	players = n
	_restart()

func _restart() -> void:
	SaveUtil.delete(SAVE_PATH)
	scores = []
	for p in players:
		var row: Array = []
		for h in _holes():
			row.append(-1)
		scores.append(row)
	pos_in_course = 0
	cur = 0
	round_recorded = false
	started = true
	card.visible = false
	_start_hole_for(0)

func _start_hole_for(p: int) -> void:
	cur = p
	engine.load_hole(_holes()[pos_in_course])
	phase = "aim"
	trail.clear()
	pulling = false
	if players > 1:
		_show_banner(tr("Player %d") % (cur + 1))
	else:
		_show_banner(tr("Hole %d") % (engine.index + 1) + " · " + tr("Par %d") % engine.par())
	_update_hud()

func _show_banner(text: String, t: float = 1.6) -> void:
	banner = text
	banner_t = t

func _update_hud() -> void:
	hole_label.text = tr("Hole %d") % (engine.index + 1) + " (%d/%d)" % [pos_in_course + 1, _holes().size()] + "  ·  " + tr("Par %d") % engine.par()
	var who := (tr("Player %d") % (cur + 1) + "  ·  ") if players > 1 else ""
	turn_label.text = who + tr("Strokes: %d") % engine.strokes
	turn_label.add_theme_color_override("font_color", BALL_COLORS[cur] if players > 1 else HomeKit.DIM)

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	banner_t = maxf(0.0, banner_t - delta)
	for k in bump_flash.keys():
		bump_flash[k] -= delta
		if bump_flash[k] <= 0.0:
			bump_flash.erase(k)
	var ev: Array = engine.step(delta)
	if engine.moving and phase == "aim":
		phase = "roll"   # knocked by a windmill or a gate
	for e in ev:
		match e:
			"wall", "mill":
				_sfx("tick")
			"bumper":
				_sfx("hit")
				for b in engine.hole.get("bumpers", []):
					if engine.ball.distance_to(Vector2(b[0], b[1])) < b[2] + 20:
						bump_flash[str(b)] = 0.25
			"water":
				_sfx("invalid")
				_show_banner(tr("Splash! +1 stroke"))
				phase = "aim"
				trail.clear()
				_update_hud()
				_check_max()
			"lip":
				_sfx("tick")
			"holed":
				_sfx("pickup")
				phase = "holed"
				phase_t = 1.3
				_show_banner(tr(MgEngine.score_name(engine.strokes, engine.par())), 1.4)
			"stopped":
				phase = "aim"
				_update_hud()
				_check_max()
	if engine.moving:
		if trail.is_empty() or (trail[trail.size() - 1] as Vector2).distance_to(engine.ball) > 12.0:
			trail.append(engine.ball)
			if trail.size() > 18:
				trail.pop_front()
	if phase == "holed":
		phase_t -= delta
		if phase_t <= 0.0:
			_finish_hole_for_player()
	field.queue_redraw()

## Out of strokes: the ball is picked up with the maximum.
func _check_max() -> void:
	if not engine.holed and engine.strokes >= MgEngine.MAX_STROKES and phase == "aim":
		_show_banner(tr("Picked up at %d") % MgEngine.MAX_STROKES, 1.4)
		phase = "holed"
		phase_t = 1.3

func _finish_hole_for_player() -> void:
	var n: int = mini(engine.strokes, MgEngine.MAX_STROKES)
	scores[cur][pos_in_course] = n
	if info and engine.holed and cur == 0:
		if n == 1:
			info.add("Holes in one")
		if n < engine.par():
			info.add("Birdies or better")
	if cur + 1 < players:
		_start_hole_for(cur + 1)
		return
	_show_card(true)

func _show_card(between: bool) -> void:
	if not started:
		return
	var last := pos_in_course >= _holes().size() - 1
	var all_done := true
	for p in players:
		if scores[p][pos_in_course] < 0:
			all_done = false
	var ended := last and all_done and between
	# Title: the hole just played (solo) or the leader.
	if between and players == 1:
		card_title.text = tr("Hole %d") % (engine.index + 1) + " — " + tr(MgEngine.score_name(scores[0][pos_in_course], engine.par()))
	else:
		card_title.text = tr("Scorecard")
	_fill_grid()
	var lines: Array = []
	var best := 9999
	for p in players:
		best = mini(best, _total(p))
	for p in players:
		var who_name := tr("Player %d") % (p + 1) if players > 1 else tr("Total")
		var crown := "  👑" if ended and players > 1 and _total(p) == best else ""
		lines.append("%s: %d (%s)%s" % [who_name, _total(p), _vs_par(p), crown])
	card_totals.text = "\n".join(lines)
	if ended:
		card_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
		phase = "over"
		_round_over()
	elif between:
		card_btn.text = tr("Next hole") + " ▶"
		phase = "card"
	else:
		card_btn.text = tr("Close")
	card.set_meta("between", between)
	card.visible = true

func _fill_grid() -> void:
	for ch in card_grid.get_children():
		ch.queue_free()
	# The nine holes around the current one, so it fits a phone.
	var holes := _holes()
	var first := 0 if pos_in_course < 9 else 9
	var count := mini(9, holes.size() - first)
	card_grid.columns = count + 2
	var fs := 20
	_cell(tr("Hole"), fs, HomeKit.DIM)
	for i in count:
		_cell(str(holes[first + i] + 1), fs, HomeKit.DIM)
	_cell("Σ", fs, HomeKit.DIM)
	_cell(tr("Par"), fs, HomeKit.DIM)
	var par_sum := 0
	for i in count:
		var par_i: int = MgEngine.HOLES[holes[first + i]].par
		par_sum += par_i
		_cell(str(par_i), fs, HomeKit.DIM)
	_cell(str(par_sum), fs, HomeKit.DIM)
	for p in players:
		_cell("P%d" % (p + 1) if players > 1 else "⛳", fs, BALL_COLORS[p])
		var sum := 0
		for i in count:
			var sc: int = scores[p][first + i]
			var par_i: int = MgEngine.HOLES[holes[first + i]].par
			var col := HomeKit.WHITE
			if sc > 0 and sc < par_i:
				col = GREEN
			elif sc > par_i:
				col = BUMPER
			_cell("·" if sc < 0 else str(sc), fs, col)
			sum += maxi(0, sc)
		_cell(str(sum), fs, BALL_COLORS[p])

func _cell(text: String, fs: int, col: Color) -> void:
	var l := HomeKit.label(text, fs, col, false, true)
	l.custom_minimum_size = Vector2(38, 0)
	card_grid.add_child(l)

func _total(p: int) -> int:
	var t := 0
	for sc in scores[p]:
		t += maxi(0, sc)
	return t

func _vs_par(p: int) -> String:
	var par_sum := 0
	var holes := _holes()
	for i in holes.size():
		if scores[p][i] >= 0:
			par_sum += MgEngine.HOLES[holes[i]].par
	var d := _total(p) - par_sum
	return "E" if d == 0 else ("%+d" % d)

func _on_card_button() -> void:
	var between: bool = card.get_meta("between", false)
	card.visible = false
	if phase == "over":
		_go_home()
	elif between and phase == "card":
		pos_in_course += 1
		_save_game()
		_start_hole_for(0)

func _round_over() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	if round_recorded or not info:
		return
	round_recorded = true
	info.add("Rounds played")
	if players == 1:
		var under := _total(0) - _par_total()
		if info.low("Best round (%s)" % COURSE_NAMES[course], _total(0)):
			info.celebrate(tr("New best round!"))
		info.low("Best vs par", under)
	else:
		info.add("Multiplayer rounds")
		var best := 9999
		for p in players:
			best = mini(best, _total(p))
		var winners: Array = []
		for p in players:
			if _total(p) == best:
				winners.append(tr("Player %d") % (p + 1))
		info.celebrate(tr("%s wins!") % " & ".join(winners))

func _par_total() -> int:
	var s := 0
	for h in _holes():
		s += MgEngine.HOLES[h].par
	return s

# ---------- aiming ----------

func _on_field_input(event: InputEvent) -> void:
	if not started or phase != "aim" or card.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pulling = true
			pull_from = event.position
			pull_to = event.position
		elif pulling:
			pulling = false
			var pull := pull_from - pull_to
			var power := clampf(pull.length() / PULL_FULL, 0.0, 1.0)
			if power > 0.05:
				engine.shoot(pull, power)
				phase = "roll"
				trail.clear()
				_sfx("hit")
				_update_hud()
		field.queue_redraw()
	elif event is InputEventMouseMotion and pulling:
		pull_to = event.position
		field.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var k: float = minf(field.size.x / MgEngine.W, field.size.y / MgEngine.H)
	var o := (field.size - Vector2(MgEngine.W, MgEngine.H) * k) / 2.0
	return {"k": k, "o": o}

func _rect(r: Array, o: Vector2, k: float) -> Rect2:
	return Rect2(o + Vector2(r[0], r[1]) * k, Vector2(r[2] - r[0], r[3] - r[1]) * k)

func _draw_field() -> void:
	var g := _geom()
	var k: float = g.k
	var o: Vector2 = g.o
	var c := field
	var h: Dictionary = engine.hole
	var tt: float = engine.t
	var outline := PackedVector2Array()
	for p in engine.outline():
		outline.append(o + p * k)
	c.draw_colored_polygon(outline, Color(0.02, 0.09, 0.06))
	# A faint mowing pattern.
	var stripe := 50.0 * k
	var y0 := o.y
	var n := 0
	while y0 < o.y + MgEngine.H * k:
		if n % 2 == 0:
			var band := Rect2(Vector2(0, y0), Vector2(field.size.x, stripe))
			var clipped := Geometry2D.intersect_polygons(outline, PackedVector2Array([band.position, Vector2(band.end.x, band.position.y), band.end, Vector2(band.position.x, band.end.y)]))
			for poly in clipped:
				c.draw_colored_polygon(poly, Color(GREEN, 0.035))
		y0 += stripe
		n += 1
	for s in h.get("slopes", []):
		var r := _rect(s, o, k)
		var dir := Vector2(s[4], s[5]).normalized()
		var ph := fmod(tt * 0.8, 1.0)
		for i in 4:
			for j in 3:
				var p := r.position + Vector2(r.size.x * (i + 0.5) / 4.0, r.size.y * (j + 0.5) / 3.0) + dir * (ph - 0.5) * 30.0 * k
				var a := p + dir * 12.0 * k
				c.draw_line(a, a - dir.rotated(0.6) * 12.0 * k, Color(GREEN, 0.35), 2.0)
				c.draw_line(a, a - dir.rotated(-0.6) * 12.0 * k, Color(GREEN, 0.35), 2.0)
	for s in h.get("sand", []):
		var r := _rect(s, o, k)
		c.draw_rect(r, Color(SAND, 0.18))
		HomeKit.glow_rect(c, r, Color(SAND, 0.7), 1.2)
		for i in 14:
			c.draw_circle(r.position + Vector2(fmod(i * 37.0, r.size.x), fmod(i * 23.0, r.size.y)), 1.5, Color(SAND, 0.5))
	for w in h.get("water", []):
		var r := _rect(w, o, k)
		c.draw_rect(r, Color(WATER, 0.25))
		HomeKit.glow_rect(c, r, WATER, 1.2)
		var wy := r.position.y + 14.0 * k
		while wy < r.end.y - 6.0:
			var pts := PackedVector2Array()
			var x := r.position.x + 6.0
			while x < r.end.x - 6.0:
				pts.append(Vector2(x, wy + sin(x * 0.08 + tt * 3.0) * 3.0))
				x += 8.0
			if pts.size() > 1:
				c.draw_polyline(pts, Color(WATER, 0.5), 1.2)
			wy += 22.0 * k
	HomeKit.glow_polyline(c, outline, GREEN, 2.2, true)
	for b in h.get("blocks", []):
		var r := _rect(b, o, k)
		c.draw_rect(r, Color(WALL, 0.22))
		HomeKit.glow_rect(c, r, WALL, 2.0)
	for b in h.get("bumpers", []):
		var p := o + Vector2(b[0], b[1]) * k
		var lit: bool = bump_flash.has(str(b))
		HomeKit.glow_circle(c, p, b[2] * k, HomeKit.WHITE if lit else BUMPER, 2.2, 0.35 if lit else 0.15)
		c.draw_circle(p, b[2] * 0.4 * k, Color(BUMPER, 0.6))
	for s in h.get("sliders", []):
		var r: Rect2 = MgEngine.slider_rect(s, tt)
		var rr := Rect2(o + r.position * k, r.size * k)
		c.draw_rect(rr, Color(GATE, 0.2))
		HomeKit.glow_rect(c, rr, GATE, 2.0)
	for m in h.get("mills", []):
		var cpos := o + Vector2(m[0], m[1]) * k
		for b in int(m[4]):
			var a: float = tt * m[3] + TAU * b / m[4]
			HomeKit.glow_line(c, cpos, cpos + Vector2(cos(a), sin(a)) * m[2] * k, MILL, 3.0)
		HomeKit.glow_circle(c, cpos, 12.0 * k, MILL, 2.0, 0.4)
	# The cup and its flag.
	var cp: Vector2 = o + engine.cup() * k
	c.draw_circle(cp, MgEngine.CUP_R * k, Color(0, 0, 0))
	HomeKit.glow_circle(c, cp, MgEngine.CUP_R * k, HomeKit.WHITE, 1.6)
	if not engine.holed:
		var top := cp + Vector2(0, -70) * k
		c.draw_line(cp, top, HomeKit.WHITE, 2.0)
		var wave := sin(tt * 4.0) * 4.0 * k
		var flag := PackedVector2Array([top, top + Vector2(34 * k, 10 * k + wave), top + Vector2(0, 22 * k)])
		c.draw_colored_polygon(flag, Color(BUMPER, 0.6))
		HomeKit.glow_polyline(c, flag, BUMPER, 1.5, true)
	# The ball, its trail and the aim.
	var col: Color = BALL_COLORS[cur]
	for i in trail.size():
		c.draw_circle(o + trail[i] * k, MgEngine.BALL_R * k * 0.5, Color(col, 0.05 + 0.25 * i / trail.size()))
	var bp: Vector2 = o + engine.ball * k
	if not engine.holed:
		c.draw_circle(bp, MgEngine.BALL_R * k, HomeKit.WHITE)
		HomeKit.glow_circle(c, bp, MgEngine.BALL_R * k, col, 2.0)
	if pulling and phase == "aim":
		var pull := pull_from - pull_to
		var power := clampf(pull.length() / PULL_FULL, 0.0, 1.0)
		if power > 0.02:
			var dir := pull.normalized()
			var reach := 40.0 + power * 260.0
			var steps := int(reach / 14.0)
			var pc := GREEN.lerp(BUMPER, power)
			for i in steps:
				c.draw_circle(bp + dir * (18.0 + i * 14.0) * k, 3.0 * k * (1.0 - 0.5 * i / steps), Color(pc, 1.0 - 0.6 * i / steps))
			# Power meter by the ball.
			var mr := Rect2(bp + Vector2(24, -40) * k, Vector2(10, 80) * k)
			c.draw_rect(mr, Color(1, 1, 1, 0.1))
			c.draw_rect(Rect2(Vector2(mr.position.x, mr.end.y - mr.size.y * power), Vector2(mr.size.x, mr.size.y * power)), pc)
	elif phase == "aim" and engine.strokes == 0 and pos_in_course == 0 and cur == 0:
		c.draw_string(ThemeDB.fallback_font, bp + Vector2(-160, 46 * k), tr("Pull back and let go"), HORIZONTAL_ALIGNMENT_CENTER, 320, 20, HomeKit.DIM)
	if banner_t > 0.0:
		HomeKit.glow_text(c, Vector2(field.size.x / 2.0, field.size.y * 0.42), banner, int(clampf(field.size.x / 15.0, 24, 44)), col.lerp(Color.WHITE, 0.3))

func _draw_home_logo(c: Control) -> void:
	var s := c.size
	var k := minf(s.y / 170.0, 1.4)
	var o := s / 2.0
	var green := PackedVector2Array([o + Vector2(-170, 40) * k, o + Vector2(-60, -30) * k, o + Vector2(170, -30) * k, o + Vector2(80, 60) * k])
	c.draw_colored_polygon(green, Color(0.02, 0.09, 0.06))
	HomeKit.glow_polyline(c, green, GREEN, 2.0, true)
	var hub := o + Vector2(-20, -60) * k
	for b in 4:
		var a := 0.3 + TAU * b / 4.0
		HomeKit.glow_line(c, hub, hub + Vector2(cos(a), sin(a)) * 46 * k, MILL, 2.5)
	HomeKit.glow_circle(c, hub, 8 * k, MILL, 2.0, 0.4)
	var cup := o + Vector2(95, 5) * k
	c.draw_circle(cup, 12 * k, Color.BLACK)
	HomeKit.glow_circle(c, cup, 12 * k, HomeKit.WHITE, 1.5)
	c.draw_line(cup, cup + Vector2(0, -75) * k, HomeKit.WHITE, 2.0)
	var flag := PackedVector2Array([cup + Vector2(0, -75) * k, cup + Vector2(34, -64) * k, cup + Vector2(0, -52) * k])
	HomeKit.glow_polyline(c, flag, BUMPER, 1.6, true)
	for i in 5:
		c.draw_circle(o + Vector2(-110 + i * 30, 30 - i * 5) * k, (2.0 + i * 0.6) * k, Color(BALL_COLORS[0], 0.15 + i * 0.12))
	c.draw_circle(o + Vector2(45, 6) * k, 9 * k, HomeKit.WHITE)
	HomeKit.glow_circle(c, o + Vector2(45, 6) * k, 9 * k, BALL_COLORS[0], 2.0)

# ---------- pause / save ----------

func _on_pause() -> void:
	pulling = false
	home.pause()

func _go_home() -> void:
	home.go_home()

## The whole round: course, players, every score, and where the ball lies.
func _save_game() -> void:
	if not started or phase == "over":
		return
	var hole_pos := pos_in_course
	var who := cur
	var ball: Vector2 = engine.ball if not engine.moving else engine.last_shot
	var strokes: int = engine.strokes
	if phase == "card":
		# Between holes: the next one, from its tee.
		hole_pos += 1
		who = 0
		var tee: Array = MgEngine.HOLES[_holes()[hole_pos]].tee
		ball = Vector2(tee[0], tee[1])
		strokes = 0
	elif phase == "holed":
		return
	SaveUtil.write(SAVE_PATH, {"course": course, "players": players, "scores": scores, "pos": hole_pos, "cur": who,
		"ball": [ball.x, ball.y], "strokes": strokes})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var c := clampi(int(d.get("course", 0)), 0, 2)
	return tr(COURSE_NAMES[c]) + " · " + tr("Hole %d") % (int(MgEngine.COURSES[c][0]) + int(d.get("pos", 0)) + 1)

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not d.has("scores"):
		_new_game(1)
		return
	course = clampi(int(d.course), 0, 2)
	players = clampi(int(d.players), 1, 4)
	scores = []
	for row in d.scores:
		var r: Array = []
		for v in row:
			r.append(int(v))
		scores.append(r)
	pos_in_course = clampi(int(d.pos), 0, _holes().size() - 1)
	round_recorded = false
	started = true
	card.visible = false
	_start_hole_for(clampi(int(d.cur), 0, players - 1))
	engine.place(Vector2(float(d.ball[0]), float(d.ball[1])))
	engine.strokes = int(d.get("strokes", 0))
	_update_hud()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
