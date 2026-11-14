extends Control

## Mini Golf: 18 holes of crazy golf on a sunny course (stone walls, brick
## blocks, real windmills; art generated in mini_golf_art.gd). Pull back anywhere on the green
## (like a slingshot) and let go to putt. Solo, or 2-4 players taking turns
## on one phone.

const MgEngine = preload("res://scripts/games/mini_golf/mini_golf_engine.gd")
const Art = preload("res://scripts/games/mini_golf/mini_golf_art.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
## Landing menu style: S10 Bento Grid (docs/MENU_STYLES.md).
const MenuStyles = preload("res://scripts/games/mini_golf/menu_styles.gd")
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
var static_layer: Control   # the course, redrawn per hole
var dyn: Control            # ball, windmills, water..., redrawn per frame
var shore: Dictionary = {}  # rim lines per hole: {"water": PackedVector2Array, "sand": ...}
var hole_label: Label
var turn_label: Label
var card: Control
var card_title: Label
var card_grid: GridContainer
var card_totals: Label
var card_btn: Button

var mulligan: Dictionary = {}  # the ball before the last putt (solo), for the ↩ help

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
	field.gui_input.connect(_on_field_input)
	fm.add_child(field)
	# Two layers: the course itself (grass, walls, sand...) is drawn once per
	# hole; only the moving things are redrawn every frame (cheap on phones).
	static_layer = Control.new()
	dyn = Control.new()
	for layer in [static_layer, dyn]:
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		field.add_child(layer)
	static_layer.draw.connect(_draw_static)
	dyn.draw.connect(_draw_dynamic)
	field.resized.connect(static_layer.queue_redraw)

	_build_card()

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S10 Bento Grid; colours analogous green/sea green/lime.
		"landing": "bento",
		"landing_style": MenuStyles,
		"title_font": "res://games/mini_golf/title.ttf",
		"title_colors": [Color("4cd964"), Color("2ecc8a"), Color("a6e22e")],
		"landing_colors": [Color("08200f"), Color("12381c")],
		"menu_color": Color("a6e22e"),
		# Own skins (_set_skin): the kit's retro filter flattened the course art.
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
		"helps": [{"text": "↩ Mulligan", "how": "Takes your last putt back (solo games).", "action": _help_mulligan}],
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
	shore = {"water": _rims(engine.hole.get("water", [])), "sand": _rims(engine.hole.get("sand", []))}
	static_layer.queue_redraw()
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
	dyn.queue_redraw()

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
		# Start the hole first: saving while still in "card" phase skipped a
		# hole and, on a course's last hole, indexed past the end (the freeze).
		_start_hole_for(0)
		_save_game()

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
				mulligan = {"ball": engine.ball, "strokes": engine.strokes, "hole": pos_in_course}
				engine.shoot(pull, power)
				phase = "roll"
				trail.clear()
				_sfx("hit")
				_update_hud()
		dyn.queue_redraw()
	elif event is InputEventMouseMotion and pulling:
		pull_to = event.position
		dyn.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var k: float = minf(field.size.x / MgEngine.W, field.size.y / MgEngine.H)
	var o := (field.size - Vector2(MgEngine.W, MgEngine.H) * k) / 2.0
	return {"k": k, "o": o}

func _rect(r: Array, o: Vector2, k: float) -> Rect2:
	return Rect2(o + Vector2(r[0], r[1]) * k, Vector2(r[2] - r[0], r[3] - r[1]) * k)

const WALL_T := 16.0          # stone wall thickness, world units

func _r(a: Array) -> Rect2:
	return Rect2(Vector2(a[0], a[1]), Vector2(a[2] - a[0], a[3] - a[1]))

func _uv(pts: PackedVector2Array, tile: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p / tile)
	return out

## Edges of a set of touching rectangles, minus the shared parts (so the
## island hole's five water rects read as one pond), as multiline pairs.
func _rims(rects: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in rects.size():
		var r := _r(rects[i])
		var cs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for e in 4:
			var a: Vector2 = cs[e]
			var b: Vector2 = cs[(e + 1) % 4]
			var nn := (b - a).orthogonal().normalized()
			if r.has_point((a + b) / 2.0 + nn):
				nn = -nn
			var steps := maxi(1, int((b - a).length() / 6.0))
			for si in steps:
				var p0 := a.lerp(b, float(si) / steps)
				var p1 := a.lerp(b, float(si + 1) / steps)
				var mid := (p0 + p1) / 2.0 + nn * 3.0
				var shared := false
				for j in rects.size():
					if j != i and MgEngine.in_rect(mid, rects[j]):
						shared = true
				if not shared:
					out.append_array([p0, p1])
	return out

## The course, drawn once per hole: rough grass everywhere, the mown green,
## stone walls, brick blocks, sand, the tee mat and the cup.
func _draw_static() -> void:
	var c := static_layer
	c.draw_texture_rect(Art.tex("rough"), Rect2(Vector2.ZERO, c.size), true)
	if engine.hole.is_empty():
		return
	var g := _geom()
	var k: float = g.k
	c.draw_set_transform(g.o, 0.0, Vector2(k, k))
	var h: Dictionary = engine.hole
	var poly: PackedVector2Array = engine.poly
	_draw_decor(c, poly)
	c.draw_colored_polygon(poly, Color.WHITE, _uv(poly, 100.0), Art.tex("grass"))
	# Slopes: shaded from high to low side.
	for s in h.get("slopes", []):
		var r := _r(s)
		var dir := Vector2(s[4], s[5]).normalized()
		for i in 5:
			var f := float(i) / 5.0
			var band: Rect2
			if absf(dir.x) > absf(dir.y):
				band = Rect2(r.position + Vector2(r.size.x * f, 0), Vector2(r.size.x / 5.0, r.size.y))
				if dir.x < 0:
					f = 1.0 - f
			else:
				band = Rect2(r.position + Vector2(0, r.size.y * f), Vector2(r.size.x, r.size.y / 5.0))
				if dir.y < 0:
					f = 1.0 - f
			c.draw_rect(band, Color(1, 1, 0.8, 0.10 * (1.0 - f)) if f < 0.5 else Color(0, 0.1, 0, 0.12 * f))
	# Sand bunkers.
	for s in h.get("sand", []):
		c.draw_texture_rect(Art.tex("sand"), _r(s), true)
	var sand_rim: PackedVector2Array = shore.get("sand", PackedVector2Array())
	if sand_rim.size() > 1:
		c.draw_multiline(sand_rim, Color("a8854a"), 4.0)
		c.draw_multiline(sand_rim, Color(0.2, 0.35, 0.1, 0.5), 1.5)
	# Tee mat.
	var tee := Vector2(h.tee[0], h.tee[1])
	var mat := Rect2(tee - Vector2(28, 22), Vector2(56, 44))
	c.draw_rect(mat.grow(2), Color(0, 0, 0, 0.25))
	c.draw_rect(mat, Color("2e8a40"))
	c.draw_rect(mat, Color("1d5e2a"), false, 2.0)
	# Block shadows, then the stone walls, then brick blocks.
	for b in h.get("blocks", []):
		c.draw_rect(Rect2(_r(b).position + Vector2(4, 6), _r(b).size), Color(0, 0, 0, 0.28))
	_draw_walls(c, poly)
	var hi := PackedVector2Array()
	var lo := PackedVector2Array()
	for b in h.get("blocks", []):
		var r := _r(b)
		c.draw_texture_rect(Art.tex("brick"), r, true)
		var tr_ := Vector2(r.end.x, r.position.y)
		var bl := Vector2(r.position.x, r.end.y)
		hi.append_array([r.position, tr_, r.position, bl])
		lo.append_array([tr_, r.end, bl, r.end])
	if hi.size() > 1:
		c.draw_multiline(hi, Color(1, 0.9, 0.8, 0.45), 2.0)
		c.draw_multiline(lo, Color(0.15, 0.05, 0.02, 0.6), 2.5)
	for m in h.get("mills", []):
		_draw_mill_tower(c, Vector2(m[0], m[1]), m[2])
	# The cup: a white lip round a dark hole.
	var cp: Vector2 = engine.cup()
	Art.disc(c, cp, MgEngine.CUP_R + 3.0, Color(1, 1, 1, 0.9))
	Art.disc(c, cp, MgEngine.CUP_R, Color("141414"))
	Art.disc(c, cp + Vector2(2, 3), MgEngine.CUP_R * 0.6, Color("262626"))
	c.draw_set_transform(Vector2.ZERO)

## The windmill's body, seen from the front like a toy-course windmill: a
## whitewashed tower narrowing upward, a red roof, a door the ball rolls
## through and a little window. Drawn under the sails.
func _draw_mill_tower(c: CanvasItem, ctr: Vector2, rad: float) -> void:
	var base_w := rad * 1.0
	var top_w := rad * 0.62
	var y_base := ctr.y + rad * 0.32
	var y_top := ctr.y - rad * 1.05
	var body := PackedVector2Array([Vector2(ctr.x - base_w / 2, y_base), Vector2(ctr.x - top_w / 2, y_top),
		Vector2(ctr.x + top_w / 2, y_top), Vector2(ctr.x + base_w / 2, y_base)])
	var shadow := PackedVector2Array()
	for p in body:
		shadow.append(p + Vector2(8, 10))
	c.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	c.draw_colored_polygon(body, Color(1.0, 0.97, 0.9), _uv(body, 96.0), Art.tex("stone"))
	c.draw_colored_polygon(body, Color(1, 1, 1, 0.45))
	# Shade on the right half for roundness.
	var half := PackedVector2Array([Vector2(ctr.x + base_w * 0.18, y_base), Vector2(ctr.x + top_w * 0.18, y_top),
		Vector2(ctr.x + top_w / 2, y_top), Vector2(ctr.x + base_w / 2, y_base)])
	c.draw_colored_polygon(half, Color(0.1, 0.1, 0.25, 0.18))
	c.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3]]), Color("5a5246"), 2.5)
	# Roof.
	var roof := PackedVector2Array([Vector2(ctr.x - top_w * 0.62, y_top + 4), Vector2(ctr.x, y_top - rad * 0.42),
		Vector2(ctr.x + top_w * 0.62, y_top + 4)])
	c.draw_colored_polygon(roof, Color(0.85, 0.35, 0.3), _uv(roof, 64.0), Art.tex("wood"))
	c.draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[0]]), Color("4a1a12"), 2.5)
	# Door (the tunnel) and window.
	var dw := rad * 0.34
	var door := Rect2(ctr.x - dw / 2, y_base - rad * 0.3, dw, rad * 0.3)
	c.draw_rect(door, Color("1c1410"))
	Art.disc(c, Vector2(ctr.x, door.position.y), dw / 2, Color("1c1410"))
	c.draw_rect(Rect2(ctr.x - 7, y_top + rad * 0.2, 14, 18), Color("2a3a55"))
	c.draw_rect(Rect2(ctr.x - 7, y_top + rad * 0.2, 14, 18), Color("5a3a1a"), false, 2.0)

## Thick stone walls on the outside of the green, with a shadow inside.
func _draw_walls(c: CanvasItem, poly: PackedVector2Array) -> void:
	var n := poly.size()
	var normals: Array = []
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var nn := (b - a).orthogonal().normalized()
		if Geometry2D.is_point_in_polygon((a + b) / 2.0 + nn * 2.0, poly):
			nn = -nn
		normals.append(nn)
	var shade := PackedVector2Array()
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var stone := Art.tex("stone")
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var nn: Vector2 = normals[i]
		shade.append_array([a - nn * 4.0, b - nn * 4.0])
		inner.append_array([a, b])
		outer.append_array([a + nn * WALL_T, b + nn * WALL_T])
	c.draw_multiline(shade, Color(0, 0, 0, 0.22), 8.0)
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var nn: Vector2 = normals[i]
		var quad := PackedVector2Array([a, b, b + nn * WALL_T, a + nn * WALL_T])
		c.draw_colored_polygon(quad, Color.WHITE, _uv(quad, 96.0), stone)
		# The corner block after this side.
		var n2: Vector2 = normals[(i + 1) % n]
		if nn.dot(n2) < 0.999:
			var cap := PackedVector2Array([b, b + nn * WALL_T, b + (nn + n2) * WALL_T, b + n2 * WALL_T])
			c.draw_colored_polygon(cap, Color.WHITE, _uv(cap, 96.0), stone)
	c.draw_multiline(inner, Color(1, 1, 0.95, 0.5), 2.5)
	c.draw_multiline(outer, Color(0, 0, 0, 0.45), 2.5)

## Bushes and flowers in the rough, the same every visit to a hole.
func _draw_decor(c: CanvasItem, poly: PackedVector2Array) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1000 + engine.index
	var flowers := [Color("ffffff"), Color("ffd93a"), Color("ff7ab0"), Color("b48cff")]
	for i in 70:
		var p := Vector2(r.randf_range(-60, MgEngine.W + 60), r.randf_range(-40, MgEngine.H + 40))
		var near := Geometry2D.is_point_in_polygon(p, poly)
		for sg in engine.segs:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, sg[0], sg[1])) < WALL_T + 22.0:
				near = true
				break
		if near:
			continue
		if r.randf() < 0.35:
			var s := r.randf_range(14, 26)
			Art.disc(c, p + Vector2(5, 7), s * 1.15, Color(0, 0, 0, 0.35), true)
			Art.disc(c, p, s, Color("1f5220"))
			Art.disc(c, p + Vector2(-s * 0.3, -s * 0.25), s * 0.7, Color("2f7330"))
			Art.disc(c, p + Vector2(s * 0.35, -s * 0.1), s * 0.55, Color("3a8a3a"))
			Art.disc(c, p + Vector2(-s * 0.4, -s * 0.45), s * 0.25, Color("5aa850"))
		else:
			var col: Color = flowers[r.randi() % flowers.size()]
			for j in 3:
				var q := p + Vector2(r.randf_range(-8, 8), r.randf_range(-8, 8))
				Art.disc(c, q, 3.0, col)
				Art.disc(c, q, 1.2, Color("ffcc33"))

## Everything that moves: water, bridges, slopes' arrows, gates, bumpers,
## windmills, the flag, the ball and the aim.
func _draw_dynamic() -> void:
	var c := dyn
	if engine.hole.is_empty():
		return
	var g := _geom()
	var k: float = g.k
	var o: Vector2 = g.o
	var h: Dictionary = engine.hole
	var tt: float = engine.t
	c.draw_set_transform(o, 0.0, Vector2(k, k))
	# Water: two layers drifting apart, a stone kerb round the pond.
	var wt := Art.tex("water")
	for w in h.get("water", []):
		var r := _r(w)
		c.draw_texture_rect_region(wt, r, Rect2(r.position + Vector2(tt * 7.0, tt * 3.0), r.size))
		c.draw_texture_rect_region(wt, r, Rect2(r.position * 0.7 + Vector2(-tt * 5.0, tt * 8.0), r.size * 0.7), Color(1, 1, 1, 0.35))
	var wrim: PackedVector2Array = shore.get("water", PackedVector2Array())
	if wrim.size() > 1:
		c.draw_multiline(wrim, Color("77736a"), 7.0)
		c.draw_multiline(wrim, Color(1, 1, 1, 0.3), 2.0)
	for b in h.get("bridges", []):
		var r := _r(b)
		c.draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.3))
		c.draw_texture_rect(Art.tex("wood"), r, true)
		var rail := Color("4a3018")
		c.draw_line(r.position + Vector2(3, 0), Vector2(r.position.x + 3, r.end.y), rail, 6.0)
		for y in [r.position.y + 4, r.end.y - 4]:
			Art.disc(c, Vector2(r.position.x + 3, y), 6.0, rail)
	# Slope arrows, painted on the turf and drifting downhill.
	var arrows := PackedVector2Array()
	for s in h.get("slopes", []):
		var r := _r(s)
		var dir := Vector2(s[4], s[5]).normalized()
		var ph := fmod(tt * 0.8, 1.0)
		for i in 4:
			for j in 3:
				var p := r.position + Vector2(r.size.x * (i + 0.5) / 4.0, r.size.y * (j + 0.5) / 3.0) + dir * (ph - 0.5) * 30.0
				var a := p + dir * 12.0
				arrows.append_array([a, a - dir.rotated(0.6) * 14.0, a, a - dir.rotated(-0.6) * 14.0])
	if arrows.size() > 1:
		c.draw_multiline(arrows, Color(1, 1, 1, 0.35), 3.0)
	# Sliding wooden gates.
	for s in h.get("sliders", []):
		var r: Rect2 = MgEngine.slider_rect(s, tt)
		c.draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.3))
		c.draw_texture_rect(Art.tex("wood"), r, true)
		c.draw_rect(r, Color("3a2412"), false, 2.5)
		for x in [r.position.x + 8, r.end.x - 8]:
			c.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color("2b2b30"), 4.0)
	# Bumpers: rubber rings on a steel post.
	for b in h.get("bumpers", []):
		var p := Vector2(b[0], b[1])
		var rad: float = b[2]
		var lit: bool = bump_flash.has(str(b))
		Art.disc(c, p + Vector2(4, 6), rad * 1.2, Color(0, 0, 0, 0.4), true)
		Art.disc(c, p, rad, Color("8c9198"))
		Art.disc(c, p, rad * 0.9, Color("ffd6d6") if lit else Color("c62a3a"))
		Art.disc(c, p, rad * 0.6, Color("fff2f2") if lit else Color("ec4a58"))
		Art.disc(c, p, rad * 0.32, Color("d9dde2"))
		Art.disc(c, p - Vector2(rad, rad) * 0.3, rad * 0.22, Color(1, 1, 1, 0.55))
	# Windmills from above: sails with cloth on a lattice, a shingled cap.
	var sail := Art.tex("sail")
	for m in h.get("mills", []):
		var cpos := Vector2(m[0], m[1])
		var rad: float = m[2]
		var w := rad * 0.26
		for pass_ in 2:
			for b in int(m[4]):
				var a: float = tt * m[3] + TAU * b / m[4]
				var shift := Vector2(6, 9) * k if pass_ == 0 else Vector2.ZERO
				c.draw_set_transform(o + cpos * k + shift, a, Vector2(k, k))
				c.draw_texture_rect(sail, Rect2(0, -w / 2.0, rad, w), false, Color(0, 0, 0, 0.3) if pass_ == 0 else Color.WHITE)
		c.draw_set_transform(o, 0.0, Vector2(k, k))
		Art.disc(c, cpos, 13.0, Color("3a2412"))
		Art.disc(c, cpos, 9.0, Color("7a4a26"))
		Art.disc(c, cpos - Vector2(2, 2), 3.5, Color("d8c8a8"))
	# The flag.
	var cp: Vector2 = engine.cup()
	if not engine.holed:
		var top := cp + Vector2(0, -70)
		c.draw_line(cp, cp + Vector2(34, -18), Color(0, 0, 0, 0.3), 3.0)
		c.draw_line(cp, top, Color("e8e8e8"), 3.0)
		var wave := sin(tt * 4.0) * 4.0
		var flag := PackedVector2Array([top, top + Vector2(36, 10 + wave), top + Vector2(0, 22)])
		c.draw_colored_polygon(flag, Color("e8333f"))
		c.draw_polyline(PackedVector2Array([top, top + Vector2(36, 10 + wave), top + Vector2(0, 22)]), Color("8a1520"), 1.5)
	# Trail, ball, aim.
	var col: Color = BALL_COLORS[cur]
	for i in trail.size():
		Art.disc(c, trail[i], MgEngine.BALL_R * 0.55, Color(1, 1, 1, 0.05 + 0.3 * i / trail.size()))
	var bp: Vector2 = engine.ball
	var r_ := MgEngine.BALL_R
	if not engine.holed:
		Art.disc(c, bp + Vector2(3, 4), r_ * 1.4, Color(0, 0, 0, 0.45), true)
		if players > 1:
			Art.disc(c, bp, r_ + 3.0, col)
		Art.disc(c, bp, r_, Color("c9ced6"))
		Art.disc(c, bp - Vector2(0.8, 0.8), r_ * 0.85, Color("ffffff"))
		Art.disc(c, bp - Vector2(3, 3), r_ * 0.3, Color(1, 1, 1, 1))
	if pulling and phase == "aim":
		var pull := (pull_from - pull_to) / k
		var power := clampf(pull.length() * k / PULL_FULL, 0.0, 1.0)
		if power > 0.02:
			var dir := pull.normalized()
			var reach := 40.0 + power * 260.0
			var steps := int(reach / 14.0)
			var pc := Color.WHITE.lerp(Color("ff3030"), power)
			for i in steps:
				Art.disc(c, bp + dir * (18.0 + i * 14.0), 3.5 * (1.0 - 0.5 * i / steps), Color(pc, 1.0 - 0.6 * i / steps))
			var mr := Rect2(bp + Vector2(24, -40), Vector2(10, 80))
			c.draw_rect(mr.grow(2), Color(0, 0, 0, 0.5))
			c.draw_rect(Rect2(Vector2(mr.position.x, mr.end.y - mr.size.y * power), Vector2(mr.size.x, mr.size.y * power)), pc)
	c.draw_set_transform(Vector2.ZERO)
	if not pulling and phase == "aim" and engine.strokes == 0 and pos_in_course == 0 and cur == 0:
		var sp: Vector2 = o + bp * k
		c.draw_string(ThemeDB.fallback_font, sp + Vector2(-160, 50 * k), tr("Pull back and let go"), HORIZONTAL_ALIGNMENT_CENTER, 320, 20, Color.WHITE)
	if banner_t > 0.0:
		HomeKit.glow_text(c, Vector2(c.size.x / 2.0, c.size.y * 0.42), banner, int(clampf(c.size.x / 15.0, 24, 44)), col.lerp(Color.WHITE, 0.3))

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
		hole_pos = mini(hole_pos + 1, _holes().size() - 1)
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

# ---------- skins ----------

var skin := "classic"

## Classic: a sunny course. Voodoo: the same course by moonlight.
func _set_skin(name_: String) -> void:
	skin = name_
	if field:
		field.modulate = Color(0.55, 0.62, 0.95) if skin == "voodoo" else Color.WHITE

func _current_skin() -> String:
	return skin

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

# ---------- helps (STANDARDS §17) ----------

## ↩ help (solo): the last putt never happened.
func _help_mulligan() -> bool:
	if not started or players != 1 or phase != "aim" or mulligan.is_empty() or int(mulligan.hole) != pos_in_course:
		return false
	engine.ball = mulligan.ball
	engine.strokes = int(mulligan.strokes)
	mulligan = {}
	trail.clear()
	dyn.queue_redraw()
	return true
