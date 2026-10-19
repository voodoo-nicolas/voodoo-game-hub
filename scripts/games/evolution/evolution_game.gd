extends Control

## Evolution (M1, eat and grow): drag anywhere to steer a glowing cell, eat
## food and smaller cells, run from bigger ones. All rules live in the engine.

const EvEngine = preload("res://scripts/games/evolution/evolution_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/evolution/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/evolution/evolution_help.gd")
const TITLE_FOR_HOME := HELP.TITLE

const BG := Color(0.012, 0.016, 0.03)
const MINE := Color("29e6ff")
const PREY := Color("7dff3a")
const HUNTER := Color("ff4f9a")
const EQUAL := Color("d8e4ff")
const FOOD := [Color("ffd23f"), Color("ff9f43"), Color("c77dff")]
const JOY_RADIUS := 110.0
const ZOOM_SMOOTH := 3.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var result_sent := false
var zoom: float = 1.0
var joy_active := false
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var keys := Vector2.ZERO
var voodoo := false
var pulse: float = 0.0
var particles: Array = []
var bump: float = 0.0          # player body pop after eating
var hurt: float = 0.0          # red screen-edge warning when a hunter is close
var stage := 0
var stage_banner := ""
var stage_banner_t: float = 0.0

var field: Control
var score_label: Label
var size_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/evolution/evolution_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = EvEngine.new()
	_build_ui()
	engine.reset()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	field = Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	add_child(field)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := MarginContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("margin_top", 24)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 38)
	score_label.add_theme_color_override("font_color", MINE.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(MINE, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(score_label)
	size_label = Label.new()
	size_label.custom_minimum_size = Vector2(150, 64)
	size_label.add_theme_font_size_override("font_size", 22)
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(size_label)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": MINE,
		"subtitle": "Eat to grow. Don't get eaten.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  " + tr("Play"), "sub": "Start as a tiny cell and eat your way up", "action": _new_game}],
		"restart": _new_game,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)

# ---------- input ----------

func _on_field_input(event: InputEvent) -> void:
	# Phones send touch AND emulated mouse; the mouse copy is the one handled.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		joy_active = event.pressed
		joy_origin = event.position
		joy_pos = event.position
	elif event is InputEventMouseMotion and joy_active:
		joy_pos = event.position
		var off := joy_pos - joy_origin
		if off.length() > JOY_RADIUS:
			joy_origin = joy_pos - off.normalized() * JOY_RADIUS  # floating base follows

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				keys.x = -1.0 if event.pressed else (0.0 if keys.x < 0.0 else keys.x)
			KEY_RIGHT, KEY_D:
				keys.x = 1.0 if event.pressed else (0.0 if keys.x > 0.0 else keys.x)
			KEY_UP, KEY_W:
				keys.y = -1.0 if event.pressed else (0.0 if keys.y < 0.0 else keys.y)
			KEY_DOWN, KEY_S:
				keys.y = 1.0 if event.pressed else (0.0 if keys.y > 0.0 else keys.y)

func _direction() -> Vector2:
	if joy_active:
		return ((joy_pos - joy_origin) / JOY_RADIUS).limit_length(1.0)
	return keys.limit_length(1.0)

# ---------- game flow ----------

func _new_game() -> void:
	engine.reset()
	started = true
	result_sent = false
	zoom = EvEngine.zoom_for(engine.player.mass)
	particles.clear()
	bump = 0.0
	hurt = 0.0
	stage = 0
	stage_banner_t = 0.0
	joy_active = false
	end_dialog.visible = false
	_update_hud()

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	pulse += delta
	var food_before: int = engine.eaten_food
	engine.step(delta, _direction())
	if engine.eaten_food > food_before and engine.eaten_food % 3 == 0:
		_sfx("tick")
	_handle_events()
	_update_particles(delta)
	_check_danger()
	stage_banner_t = maxf(0.0, stage_banner_t - delta)
	var si: int = EvEngine.stage_index(engine.player.mass)
	if si > stage:
		stage_banner = tr(EvEngine.STAGES[si][1])
		stage_banner_t = 2.2
		_sfx("powerup")
	stage = si
	zoom = lerpf(zoom, EvEngine.zoom_for(engine.player.mass), clampf(ZOOM_SMOOTH * delta, 0.0, 1.0))
	_update_hud()
	if not engine.alive:
		_game_over()
	field.queue_redraw()

## Raises the red edge warning while a hunter is close.
func _check_danger() -> void:
	for n in engine.npcs:
		if EvEngine.can_eat(n.mass, engine.player.mass) and n.pos.distance_to(engine.player.pos) < 420.0 + EvEngine.radius_of(n.mass) * 2.0:
			hurt = 1.0
			return

func _update_hud() -> void:
	score_label.text = str(engine.score())
	size_label.text = tr(EvEngine.STAGES[EvEngine.stage_index(engine.player.mass)][1]) + "\n" + tr("Size %d") % int(engine.player.mass)

func _game_over() -> void:
	started = false
	joy_active = false
	_sfx("explode")
	var msg := tr("You were eaten!") + "\n" + tr("Score: %d") % engine.score() + "   ·   " + tr("Size %d") % int(engine.peak_mass)
	if info and not result_sent:
		result_sent = true
		info.add("Games played")
		info.add("Cells eaten", engine.eaten_cells)
		info.add("Food eaten", engine.eaten_food)
		info.high("Biggest size", int(engine.peak_mass))
		if info.high("Best score", engine.score()):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- effects ----------

func _spawn_burst(p: Vector2, col: Color, n: int, speed: float, size: float, ring_r: float) -> void:
	for i in n:
		var a := randf() * TAU
		particles.append({"pos": p, "vel": Vector2.RIGHT.rotated(a) * randf_range(0.3, 1.0) * speed,
			"life": randf_range(0.4, 0.9), "max": 0.9, "col": col, "size": size * randf_range(0.6, 1.2), "ring": 0.0})
	if ring_r > 0.0:
		particles.append({"pos": p, "vel": Vector2.ZERO, "life": 0.5, "max": 0.5, "col": col, "size": 0.0, "ring": ring_r})

func _handle_events() -> void:
	for ev in engine.events:
		match ev.type:
			"food":
				_spawn_burst(ev.pos, FOOD[int(ev.pos.x) % FOOD.size()], 3, 70.0, 3.0, 0.0)
				bump = maxf(bump, 0.04)
			"cell":
				var r: float = EvEngine.radius_of(ev.mass)
				_spawn_burst(ev.pos, PREY, 14, 220.0, 5.0, r * 1.6)
				bump = 0.16
				_sfx("pickup")
			"death":
				_spawn_burst(ev.pos, MINE, 46, 420.0, 7.0, EvEngine.radius_of(engine.player.mass) * 2.2)

func _update_particles(delta: float) -> void:
	for p in particles:
		p.pos += p.vel * delta
		p.vel *= maxf(0.0, 1.0 - 2.2 * delta)
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0.0)
	bump = maxf(0.0, bump - delta * 0.5)
	hurt = maxf(0.0, hurt - delta * 1.5)

# ---------- drawing ----------

func _w2s(p: Vector2) -> Vector2:
	return (p - engine.player.pos) * zoom + field.size / 2.0

## Deterministic 0..1 hash for background specks.
static func _h(x: int, y: int, k: int) -> float:
	var n: int = ((x * 73856093) ^ (y * 19349663) ^ (k * 83492791)) & 0x7FFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0

func _draw_field() -> void:
	var s := field.size
	field.draw_rect(Rect2(Vector2.ZERO, s), BG)
	if engine == null:
		return
	_draw_background(s)
	var a: float = EvEngine.TUNING.arena
	_draw_arena_edge(s, a)
	var margin := 40.0
	# Food: glowing spores that breathe.
	var fr: float = maxf(EvEngine.radius_of(EvEngine.TUNING.food_mass) * zoom, 3.0)
	for i in engine.food.size():
		var sp := _w2s(engine.food[i])
		if sp.x < -margin or sp.y < -margin or sp.x > s.x + margin or sp.y > s.y + margin:
			continue
		var col: Color = FOOD[i % FOOD.size()]
		var br := 1.0 + 0.18 * sin(pulse * 3.0 + float(i) * 1.7)
		field.draw_circle(sp, fr * 3.4 * br, Color(col, 0.07))
		field.draw_circle(sp, fr * 2.0 * br, Color(col, 0.16))
		field.draw_circle(sp, fr * br, col)
		field.draw_circle(sp - Vector2(fr, fr) * 0.25, fr * 0.35, Color(1, 1, 1, 0.8))
	# Other cells, small first so big ones cover them.
	var pm: float = engine.player.mass
	var list: Array = engine.npcs.duplicate()
	list.sort_custom(_by_mass)
	for n in list:
		var sp2 := _w2s(n.pos)
		var r: float = EvEngine.radius_of(n.mass) * zoom
		if sp2.x < -r * 2.0 - margin or sp2.y < -r * 2.0 - margin or sp2.x > s.x + r * 2.0 + margin or sp2.y > s.y + r * 2.0 + margin:
			continue
		var kind := "equal"
		if EvEngine.can_eat(pm, n.mass):
			kind = "prey"
		elif EvEngine.can_eat(n.mass, pm):
			kind = "hunter"
		_draw_cell(field, sp2, r, kind, n.vel, int(n.get("id", 0)), pulse)
	# Effects under the player's own cell
	for p in particles:
		var a2: float = clampf(p.life / p.max, 0.0, 1.0)
		var pp: Vector2 = _w2s(p.pos)
		if p.ring > 0.0:
			var rr: float = p.ring * zoom * (1.2 - a2 * 0.6)
			field.draw_arc(pp, rr, 0.0, TAU, 40, Color(p.col, a2 * 0.7), 3.0, true)
		else:
			field.draw_circle(pp, p.size * zoom + 1.0, Color(p.col, a2))
	if engine.alive:
		var pr: float = EvEngine.radius_of(pm) * zoom * (1.0 + bump)
		_draw_cell(field, s / 2.0, pr, "player", engine.player.vel, 0, pulse)
	_draw_hunter_arrows(s, pm)
	_draw_vignette(s)
	if joy_active:
		field.draw_arc(joy_origin, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.16), 3.0, true)
		field.draw_arc(joy_origin, JOY_RADIUS * 0.55, 0.0, TAU, 40, Color(1, 1, 1, 0.07), 2.0, true)
		var knob := joy_origin + (joy_pos - joy_origin).limit_length(JOY_RADIUS)
		field.draw_circle(knob, 40.0, Color(MINE, 0.18))
		field.draw_circle(knob, 28.0, Color(MINE, 0.5))
	if stage_banner_t > 0.0:
		var al := clampf(stage_banner_t, 0.0, 1.0)
		HomeKit.glow_text(field, Vector2(s.x / 2.0, s.y * 0.22), stage_banner, 44, Color(MINE, al))

static func _by_mass(x, y) -> bool:
	return x.mass < y.mass

## Soft light blobs + three parallax layers of drifting plankton.
func _draw_background(s: Vector2) -> void:
	var pp: Vector2 = engine.player.pos
	var tcol := Color("0b2f4a") if not voodoo else Color("2a0b46")
	# Big faint caustic blobs, slowest layer.
	var cell := 900.0
	var par := 0.25
	var cam := pp * par
	var x0 := int(floorf((cam.x - s.x / 2.0 / zoom) / cell)) - 1
	var y0 := int(floorf((cam.y - s.y / 2.0 / zoom) / cell)) - 1
	var nx := int(s.x / (cell * zoom)) + 3
	var ny := int(s.y / (cell * zoom)) + 3
	for ix in range(x0, x0 + nx):
		for iy in range(y0, y0 + ny):
			var c := Vector2(ix + _h(ix, iy, 1), iy + _h(ix, iy, 2)) * cell
			var sp := (c - cam) * zoom + s / 2.0
			var rr := (260.0 + 240.0 * _h(ix, iy, 3)) * zoom
			for q in 6:
				field.draw_circle(sp, rr * (1.0 - float(q) * 0.15), Color(tcol, 0.09))
	# Plankton layers: (parallax, cell, size, alpha)
	for L in [[0.45, 240.0, 1.6, 0.16], [0.75, 190.0, 2.2, 0.22], [1.0, 160.0, 2.6, 0.30]]:
		var par2: float = L[0]
		var cs: float = L[1]
		var cam2 := pp * par2
		var gx := int(floorf((cam2.x - s.x / 2.0 / zoom) / cs)) - 1
		var gy := int(floorf((cam2.y - s.y / 2.0 / zoom) / cs)) - 1
		var cx := int(s.x / (cs * zoom)) + 3
		var cy := int(s.y / (cs * zoom)) + 3
		for ix in range(gx, gx + cx):
			for iy in range(gy, gy + cy):
				var wp := Vector2(ix + _h(ix, iy, 4), iy + _h(ix, iy, 5)) * cs
				wp += Vector2(sin(pulse * 0.4 + _h(ix, iy, 6) * 6.0), cos(pulse * 0.35 + _h(ix, iy, 7) * 6.0)) * 14.0
				var sp2 := (wp - cam2) * zoom + s / 2.0
				var tw := 0.6 + 0.4 * sin(pulse * 1.5 + _h(ix, iy, 8) * 9.0)
				field.draw_circle(sp2, L[2] * (0.6 + _h(ix, iy, 9)) * maxf(zoom, 0.5), Color(0.55, 0.9, 1.0, L[3] * tw))

func _draw_arena_edge(s: Vector2, a: float) -> void:
	var tl := _w2s(Vector2.ZERO)
	var br := _w2s(Vector2(a, a))
	var dead := Color(0.0, 0.0, 0.0, 0.62)
	# Darken everything outside the pond.
	field.draw_rect(Rect2(Vector2(-10, -10), Vector2(maxf(tl.x + 10, 0.0), s.y + 20)), dead)
	field.draw_rect(Rect2(Vector2(br.x, -10), Vector2(maxf(s.x - br.x + 10, 0.0), s.y + 20)), dead)
	field.draw_rect(Rect2(Vector2(tl.x, -10), Vector2(br.x - tl.x, maxf(tl.y + 10, 0.0))), dead)
	field.draw_rect(Rect2(Vector2(tl.x, br.y), Vector2(br.x - tl.x, maxf(s.y - br.y + 10, 0.0))), dead)
	var edge := HUNTER if not voodoo else Color("9b4dff")
	var glow := 0.5 + 0.2 * sin(pulse * 2.0)
	field.draw_rect(Rect2(tl, br - tl), Color(edge, 0.12 * glow), false, 14.0 * zoom + 4.0)
	field.draw_rect(Rect2(tl, br - tl), Color(edge, 0.9), false, 3.0)

func _draw_vignette(s: Vector2) -> void:
	var d := Color(0, 0, 0, 0.55)
	var z := Color(0, 0, 0, 0)
	var w := minf(s.x, s.y) * 0.28
	field.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, w), Vector2(0, w)]), PackedColorArray([d, d, z, z]))
	field.draw_polygon(PackedVector2Array([Vector2(0, s.y), Vector2(s.x, s.y), Vector2(s.x, s.y - w), Vector2(0, s.y - w)]), PackedColorArray([d, d, z, z]))
	if hurt > 0.0:
		var h := Color(HUNTER, 0.22 * hurt)
		field.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, s.y), Vector2(0, s.y)]), PackedColorArray([h, z, z, h]))
		field.draw_polygon(PackedVector2Array([Vector2(s.x, 0), Vector2(s.x - w, 0), Vector2(s.x - w, s.y), Vector2(s.x, s.y)]), PackedColorArray([h, z, z, h]))

## Edge arrows toward hunters that are close but off screen; a close hunter
## also raises the red screen-edge warning.
func _draw_hunter_arrows(s: Vector2, pm: float) -> void:
	var c := s / 2.0
	for n in engine.npcs:
		if not EvEngine.can_eat(n.mass, pm):
			continue
		var d: Vector2 = n.pos - engine.player.pos
		var sp := _w2s(n.pos)
		var r: float = EvEngine.radius_of(n.mass) * zoom
		var on_screen := sp.x > -r and sp.y > -r and sp.x < s.x + r and sp.y < s.y + r
		var dist := d.length()
		if on_screen or dist > 1500.0 / maxf(zoom, 0.3):
			continue
		var dir := d.normalized()
		var edge := c + dir * minf(s.x, s.y) * 0.44
		edge = Vector2(clampf(edge.x, 44.0, s.x - 44.0), clampf(edge.y, 90.0, s.y - 44.0))
		var al := clampf(1.2 - dist * zoom / 1500.0, 0.25, 1.0)
		var perp := dir.orthogonal()
		var pts := PackedVector2Array([edge + dir * 18.0, edge - dir * 10.0 + perp * 12.0, edge - dir * 10.0 - perp * 12.0])
		field.draw_colored_polygon(pts, Color(HUNTER, 0.35 * al))
		pts.append(pts[0])
		field.draw_polyline(pts, Color(HUNTER, al), 2.5, true)

## One cell: wobbling membrane, inner glow, nucleus, organelles, eyes.
## kind: player / prey / hunter / equal. `ci` is any CanvasItem (the logo reuses it).
func _draw_cell(ci: CanvasItem, c: Vector2, r: float, kind: String, vel: Vector2, seed_: int, t: float) -> void:
	if r < 1.5:
		return
	var col: Color = MINE
	match kind:
		"prey":
			col = PREY
		"hunter":
			col = HUNTER
		"equal":
			col = EQUAL
	var sd := float(seed_) * 1.37
	var spd := clampf(vel.length() / 300.0, 0.0, 1.0)
	var heading := vel.angle() if vel.length() > 5.0 else 0.0
	if kind == "player" and vel.length() <= 5.0:
		heading = -PI / 2.0
	var sides := 36 if r > 24.0 else 20
	var pts := PackedVector2Array()
	for i in sides:
		var ang := TAU * float(i) / float(sides)
		var k := 1.0 + 0.035 * sin(ang * 3.0 + t * 2.2 + sd) + 0.025 * sin(ang * 5.0 - t * 3.1 + sd * 1.7)
		var along := cos(ang - heading)
		k *= 1.0 + 0.10 * spd * along - 0.04 * spd * (1.0 - absf(along))
		if kind == "hunter" and i % 3 == 0:
			k *= 1.2  # spikes
		pts.append(c + Vector2.RIGHT.rotated(ang) * r * k)
	var closed := pts.duplicate()
	closed.append(pts[0])
	if voodoo:
		_draw_cell_voodoo(ci, c, r, col, pts, closed, heading, kind, t, sd)
		return
	# Tail (flagellum) for the player and prey, trailing behind.
	if kind == "player" or kind == "prey":
		var tail := PackedVector2Array()
		var back := Vector2.RIGHT.rotated(heading + PI)
		var side := back.orthogonal()
		var tail_len := r * (1.5 if kind == "player" else 1.0)
		for j in 12:
			var f := float(j) / 11.0
			tail.append(c + back * (r * 0.9 + tail_len * f) + side * sin(t * 9.0 - f * 5.0 + sd) * r * 0.22 * f)
		ci.draw_polyline(tail, Color(col, 0.55), maxf(r * 0.08, 1.5), true)
	# Soft halo
	ci.draw_circle(c, r * 1.9, Color(col, 0.05))
	ci.draw_circle(c, r * 1.45, Color(col, 0.09))
	# Body: dark base, tinted body, bright core
	ci.draw_colored_polygon(pts, Color(col.darkened(0.7), 0.88))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.82)
	ci.draw_colored_polygon(inner, Color(col, 0.30 if kind != "player" else 0.42))
	var core := PackedVector2Array()
	for p in pts:
		core.append(c + (p - c) * 0.45 + Vector2(-r * 0.06, -r * 0.08))
	ci.draw_colored_polygon(core, Color(col.lightened(0.35), 0.22))
	# Organelles (slowly orbiting dots)
	if r > 14.0:
		for j in 6:
			var oa := sd + float(j) * 1.05 + t * 0.25 * (1.0 if j % 2 == 0 else -1.0)
			var orad := r * (0.35 + 0.35 * fmod(float(j) * 0.37 + sd * 0.11, 1.0))
			ci.draw_circle(c + Vector2.RIGHT.rotated(oa) * orad, r * (0.045 + 0.02 * float(j % 3)), Color(col.lightened(0.4), 0.55))
	# Membrane
	ci.draw_polyline(closed, Color(col, 0.35), maxf(r * 0.12, 3.0), true)
	ci.draw_polyline(closed, col.lightened(0.25), maxf(r * 0.05, 1.8), true)
	# Cilia hairs on equal/prey cells
	if kind != "hunter" and kind != "player" and r > 12.0:
		for i in range(0, sides, 2):
			var dir := (pts[i] - c).normalized()
			var wav := sin(t * 6.0 + float(i) + sd) * 0.25
			ci.draw_line(pts[i], pts[i] + dir.rotated(wav) * r * 0.16, Color(col, 0.7), maxf(r * 0.02, 1.0), true)
	# Nucleus
	var look := Vector2.RIGHT.rotated(heading) * r * 0.10 * (0.4 + spd)
	var nuc := c - look * 0.3
	ci.draw_circle(nuc, r * 0.30, Color(col.darkened(0.45), 0.85))
	ci.draw_arc(nuc, r * 0.30, 0.0, TAU, 24, Color(col.lightened(0.3), 0.8), maxf(r * 0.03, 1.2), true)
	ci.draw_circle(nuc - Vector2(r * 0.08, r * 0.08), r * 0.07, Color(1, 1, 1, 0.5))
	_draw_eyes(ci, c, r, heading, kind, col)

func _draw_eyes(ci: CanvasItem, c: Vector2, r: float, heading: float, kind: String, col: Color) -> void:
	if r < 9.0:
		return
	var fwd := Vector2.RIGHT.rotated(heading)
	var side := fwd.orthogonal()
	var base := c + fwd * r * 0.38
	var er := r * (0.17 if kind != "hunter" else 0.15)
	for sgn in [-1.0, 1.0]:
		var ep: Vector2 = base + side * sgn * r * 0.26
		ci.draw_circle(ep, er, Color(1, 1, 1, 0.95))
		var pup := ep + fwd * er * 0.35
		ci.draw_circle(pup, er * (0.55 if kind != "prey" else 0.7), Color(0.03, 0.03, 0.08))
		ci.draw_circle(pup - Vector2(er * 0.15, er * 0.15), er * 0.18, Color.WHITE)
		if kind == "hunter":
			# angry brow: low on the inside, high on the outside
			var brow_in: Vector2 = ep - side * sgn * er * 1.0 + fwd * er * 0.9
			var brow_out: Vector2 = ep + side * sgn * er * 1.1 + fwd * er * 1.5
			ci.draw_line(brow_in, brow_out, col.lightened(0.4), maxf(r * 0.05, 1.5), true)
	if kind == "hunter" and r > 18.0:
		# jagged mouth
		var m := c - fwd * r * 0.2
		var zig := PackedVector2Array()
		for j in 7:
			zig.append(m - side * r * 0.3 + side * r * 0.1 * float(j) + fwd * r * (0.07 if j % 2 == 0 else -0.05))
		ci.draw_polyline(zig, Color(1, 1, 1, 0.9), maxf(r * 0.04, 1.5), true)
	elif kind == "prey" and r > 18.0:
		ci.draw_arc(c + fwd * r * 0.02, r * 0.16, 0.2, PI - 0.2, 10, Color(0.03, 0.03, 0.08, 0.8), maxf(r * 0.03, 1.2), true)

## Voodoo skin: neon wireframe skull cell.
func _draw_cell_voodoo(ci: CanvasItem, c: Vector2, r: float, col: Color, pts: PackedVector2Array, closed: PackedVector2Array, heading: float, kind: String, t: float, sd: float) -> void:
	ci.draw_circle(c, r * 1.6, Color(col, 0.06))
	ci.draw_colored_polygon(pts, Color(col, 0.14))
	ci.draw_polyline(closed, Color(col, 0.30), maxf(r * 0.14, 4.0), true)
	ci.draw_polyline(closed, col, maxf(r * 0.045, 2.0), true)
	if r < 10.0:
		return
	var fwd := Vector2.RIGHT.rotated(heading)
	var side := fwd.orthogonal()
	# eye sockets
	for sgn in [-1.0, 1.0]:
		var ep: Vector2 = c + fwd * r * 0.12 + side * sgn * r * 0.3
		ci.draw_circle(ep, r * 0.2, Color(0.02, 0.0, 0.05, 0.95))
		ci.draw_arc(ep, r * 0.2, 0.0, TAU, 20, col, maxf(r * 0.04, 1.4), true)
		ci.draw_circle(ep + fwd * r * 0.03, r * 0.06, Color(col.lightened(0.5), 0.6 + 0.4 * sin(t * 4.0 + sd)))
	# nose + teeth
	ci.draw_colored_polygon(PackedVector2Array([c - fwd * r * 0.08, c - fwd * r * 0.22 + side * r * 0.06, c - fwd * r * 0.22 - side * r * 0.06]), col)
	if r > 16.0:
		ci.draw_line(c - fwd * r * 0.5 - side * r * 0.32, c - fwd * r * 0.5 + side * r * 0.32, col, maxf(r * 0.04, 1.4), true)
		for j in range(-2, 3):
			var tp := c - fwd * r * 0.5 + side * r * 0.14 * float(j)
			ci.draw_line(tp, tp - fwd * r * 0.16, col, maxf(r * 0.03, 1.2), true)

func _draw_home_logo(c: Control) -> void:
	var o := c.size / 2.0
	var k := minf(c.size.y / 3.0, 44.0)
	for spec in [[Vector2(-2.7, 0.5), 0.6, "prey", 3], [Vector2(2.5, -0.3), 1.35, "hunter", 5], [Vector2(-0.3, 0.0), 1.05, "player", 0]]:
		_draw_cell(c, o + spec[0] * k, spec[1] * k, spec[2], Vector2(60, 0) if spec[2] != "hunter" else Vector2(-60, 0), spec[3], pulse)

# ---------- pause / skin ----------

func _on_pause() -> void:
	joy_active = false
	home.pause()

func _go_home() -> void:
	home.go_home()

## Called by the Landing kit's skin switch: re-skin in place.
func _set_skin(skin: String) -> void:
	voodoo = skin == "voodoo"
	if field:
		field.queue_redraw()

func _current_skin() -> String:
	return "voodoo" if voodoo else "classic"

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
