extends Node2D

## Draws the world. It sits inside the game's clipped view and is moved by
## -camera, so every draw call here uses world coordinates (the same as the
## entity positions in `game`). Only what's near the view is drawn.
## Everything is glowing vector lines: each outline is stroked three times
## (wide faint, medium, thin bright) to fake the neon bloom.
var game: Control

const Core = preload("res://scripts/games/geometry_wars/geometry_wars_core.gd")
const Bosses = preload("res://scripts/games/geometry_wars/geometry_wars_bosses.gd")
const Drones = preload("res://scripts/games/geometry_wars/geometry_wars_drones.gd")

const SPRING := 30.0
const DAMPING := 2.6
const COUPLING := 55.0
## After a bomb the sheet rings for longer.
const BOMB_DAMPING := 1.1
const MAX_OFFSET := 3.2  # squares
## How far beyond the view the springs keep moving (in grid nodes).
const SIM_MARGIN := 4

# The background grid: a sheet of springs that ripples when things explode.
var grid_color := Color(0.18, 0.4, 0.9)
var grid_nx := 0
var grid_ny := 0
var grid_step := Vector2.ONE
var grid_off := PackedVector2Array()
var grid_vel := PackedVector2Array()
var grid_awake := 0.0
var loose_t := 0.0  # seconds of low damping left (after a bomb)
var flash := 0.0  # the grid lights up after a bomb
## Expanding shockwave rings: {pos, t, speed, strength}.
var shocks: Array = []
var _font: Font

func reset_grid() -> void:
	var u: float = Core.U
	grid_nx = int(round(game.arena_size.x / u)) + 1
	grid_ny = int(round(game.arena_size.y / u)) + 1
	grid_step = Vector2(game.arena_size.x / float(grid_nx - 1), game.arena_size.y / float(grid_ny - 1))
	grid_off = PackedVector2Array()
	grid_off.resize(grid_nx * grid_ny)
	grid_vel = PackedVector2Array()
	grid_vel.resize(grid_nx * grid_ny)
	grid_awake = 0.0
	shocks.clear()
	_font = ThemeDB.fallback_font

## A ripple: positive `strength` shoves the grid away from `pos`, negative
## pulls it in. `radius` is in pixels.
func pulse(pos: Vector2, strength: float, radius: float) -> void:
	if grid_nx == 0:
		return
	var i0 := maxi(1, int((pos.x - radius) / grid_step.x))
	var i1 := mini(grid_nx - 2, int((pos.x + radius) / grid_step.x) + 1)
	var j0 := maxi(1, int((pos.y - radius) / grid_step.y))
	var j1 := mini(grid_ny - 2, int((pos.y + radius) / grid_step.y) + 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var idx := j * grid_nx + i
			var p := Vector2(i * grid_step.x, j * grid_step.y) + grid_off[idx]
			var off := p - pos
			var d := off.length()
			if d < radius and d > 0.01:
				grid_vel[idx] += off / d * strength * (1.0 - d / radius)
	grid_awake = maxf(grid_awake, 2.5)

## A bomb: a ring that races outward, shoving the grid as it passes, and a
## few seconds of loose, wobbling springs.
func shock(pos: Vector2, strength: float = 1.0) -> void:
	shocks.append({"pos": pos, "t": 0.0, "speed": 38.0 * Core.U, "strength": 2600.0 * strength})
	pulse(pos, 1400.0 * strength, 7.0 * Core.U)
	loose_t = 3.5
	flash = 1.0
	grid_awake = 6.0

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 1.2)
	loose_t = maxf(0.0, loose_t - delta)
	if grid_awake <= 0.0 or grid_nx == 0:
		return
	grid_awake -= delta
	var dt := minf(delta, 0.033)
	var u: float = Core.U
	# Only the part of the sheet near the view moves.
	var cam: Vector2 = game.cam
	var vs: Vector2 = game.view_size
	var i0 := maxi(1, int(cam.x / grid_step.x) - SIM_MARGIN)
	var i1 := mini(grid_nx - 2, int((cam.x + vs.x) / grid_step.x) + SIM_MARGIN)
	var j0 := maxi(1, int(cam.y / grid_step.y) - SIM_MARGIN)
	var j1 := mini(grid_ny - 2, int((cam.y + vs.y) / grid_step.y) + SIM_MARGIN)
	for si in range(shocks.size() - 1, -1, -1):
		var s: Dictionary = shocks[si]
		s.t = float(s.t) + dt
		var r: float = float(s.t) * float(s.speed)
		if r > vs.length() * 1.2:
			shocks.remove_at(si)
			continue
		var band := 2.2 * u
		var fade: float = 1.0 - r / (vs.length() * 1.2)
		var c: Vector2 = s.pos
		for j in range(maxi(j0, int((c.y - r - band) / grid_step.y)), mini(j1, int((c.y + r + band) / grid_step.y) + 1) + 1):
			for i in range(maxi(i0, int((c.x - r - band) / grid_step.x)), mini(i1, int((c.x + r + band) / grid_step.x) + 1) + 1):
				var idx := j * grid_nx + i
				var p := Vector2(i * grid_step.x, j * grid_step.y)
				var off := p - c
				var d := off.length()
				if absf(d - r) < band and d > 0.01:
					grid_vel[idx] += off / d * float(s.strength) * fade * (1.0 - absf(d - r) / band) * dt
	var damp := DAMPING if loose_t <= 0.0 else lerpf(DAMPING, BOMB_DAMPING, minf(1.0, loose_t / 2.0))
	var max_off := MAX_OFFSET * u
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var idx := j * grid_nx + i
			var o := grid_off[idx]
			var f := -o * SPRING
			f += (grid_off[idx - 1] - o) * COUPLING
			f += (grid_off[idx + 1] - o) * COUPLING
			f += (grid_off[idx - grid_nx] - o) * COUPLING
			f += (grid_off[idx + grid_nx] - o) * COUPLING
			grid_vel[idx] = (grid_vel[idx] + f * dt) * maxf(0.0, 1.0 - damp * dt)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var idx := j * grid_nx + i
			grid_off[idx] = (grid_off[idx] + grid_vel[idx] * dt).limit_length(max_off)

func _draw_grid() -> void:
	if grid_nx == 0:
		return
	var u: float = Core.U
	var cam: Vector2 = game.cam
	var vs: Vector2 = game.view_size
	var i0 := maxi(0, int(cam.x / grid_step.x) - 2)
	var i1 := mini(grid_nx - 1, int((cam.x + vs.x) / grid_step.x) + 2)
	var j0 := maxi(0, int(cam.y / grid_step.y) - 2)
	var j1 := mini(grid_ny - 1, int((cam.y + vs.y) / grid_step.y) + 2)
	var lines := PackedVector2Array()
	var colors := PackedColorArray()
	var hot := Color(1.0, 0.95, 0.8).lerp(grid_color.lightened(0.6), 0.4)
	var base := grid_color.lerp(Color(1.0, 0.75, 0.4), flash * 0.6)
	var stretch := 1.0 / (1.2 * u)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var idx := j * grid_nx + i
			var o := grid_off[idx]
			var p := Vector2(i * grid_step.x, j * grid_step.y) + o
			var k := minf(1.0, o.length() * stretch)
			var col := Color(base.lerp(hot, k), 0.42 + 0.5 * k + flash * 0.3)
			if i < i1:
				var o2 := grid_off[idx + 1]
				lines.append(p)
				lines.append(Vector2((i + 1) * grid_step.x, j * grid_step.y) + o2)
				colors.append(col)
			if j < j1:
				var o3 := grid_off[idx + grid_nx]
				lines.append(p)
				lines.append(Vector2(i * grid_step.x, (j + 1) * grid_step.y) + o3)
				colors.append(col)
	draw_multiline(lines, Color(base, 0.1 + flash * 0.15), 4.0)
	draw_multiline_colors(lines, colors, 1.2)

func _draw() -> void:
	if game == null:
		return
	var u: float = Core.U
	var t := Time.get_ticks_msec() / 1000.0
	var vis := Rect2(game.cam - Vector2(3, 3) * u, game.view_size + Vector2(6, 6) * u)

	_draw_grid()
	_neon(PackedVector2Array([Vector2.ZERO, Vector2(game.arena_size.x, 0), game.arena_size, Vector2(0, game.arena_size.y)]), grid_color.lightened(0.35), true, 3.0)

	for z in game.zones:
		_draw_zone(z, t, u)

	if game.shockwave_t >= 0.0:
		var k: float = game.shockwave_t / game.SHOCKWAVE_TIME
		var r: float = lerpf(20.0, game.view_size.length() * 1.1, k)
		draw_arc(game.bomb_pos, r, 0, TAU, 128, Color(1, 0.7, 0.3, 1.0 - k), 14.0 * (1.0 - k) + 2.0, true)
		draw_arc(game.bomb_pos, r * 0.85, 0, TAU, 128, Color(1, 1, 1, (1.0 - k) * 0.6), 4.0, true)
		draw_arc(game.bomb_pos, r * 0.6, 0, TAU, 96, Color(0.5, 0.8, 1.0, (1.0 - k) * 0.35), 3.0, true)

	for m in game.mines:
		if vis.has_point(m.pos):
			_draw_mine(m, t, u)

	# Geoms: tiny yellow crystals that blink out in their last second.
	for c in game.crystals:
		if not vis.has_point(c.pos):
			continue
		var left: float = Core.CRYSTAL_LIFE - c.age
		var a: float = 1.0 if left > 1.0 else (0.35 + 0.65 * absf(sin(left * 18.0)))
		var big: bool = int(c.get("v", 1)) > 1
		_draw_gem(c.pos, (0.5 if big else 0.2) * u, t * 3.0 + c.pos.x, Color(1.0, 0.65, 0.15, a) if big else Color(1.0, 0.92, 0.25, a), big)

	for e in game.enemies:
		if vis.grow(3.0 * u).has_point(e.pos) or e.type == "snake":
			_draw_enemy(e, t, u)

	for b in game.bosses:
		_draw_boss(b, t, u)

	# Sparks from explosions.
	for p in game.particles:
		if not vis.has_point(p.pos):
			continue
		var k: float = p.age / p.lifetime
		var dir: Vector2 = p.vel.normalized()
		var tail: Vector2 = p.pos - dir * (p.len * (1.0 - k) + 2.0)
		var col: Color = p.color
		draw_line(tail, p.pos, Color(col, (1.0 - k) * 0.25), 6.0)
		draw_line(tail, p.pos, Color(col.lightened(0.5), 1.0 - k), 2.0)

	# Bullets: orange darts that streak behind them (gold after a gate bounce).
	for b in game.bullets:
		if not vis.has_point(b.pos):
			continue
		var d: Vector2 = b.vel.normalized()
		var side := Vector2(-d.y, d.x)
		var front: Vector2 = b.pos + d * 0.5 * u
		var back: Vector2 = b.pos - d * 0.25 * u
		var gold: bool = b.get("gold", false)
		var c1 := Color(1.0, 0.85, 0.2) if gold else (Color(0.6, 0.85, 1.0) if b.get("drone", false) else Color(1.0, 0.65, 0.2))
		draw_line(back, back - d * 1.6 * u, Color(c1, 0.25), 0.28 * u)
		draw_colored_polygon(PackedVector2Array([front, back + side * 0.1 * u, back - side * 0.1 * u]), c1)
		draw_line(front, back, Color(1.0, 0.95, 0.7), 1.5)

	# Enemy shots: hot pink orbs.
	for b in game.ebullets:
		if not vis.has_point(b.pos):
			continue
		var r: float = float(b.get("r", 0.25)) * u
		draw_circle(b.pos, r * 2.0, Color(1.0, 0.2, 0.5, 0.18))
		draw_circle(b.pos, r, Color(1.0, 0.35, 0.6))
		draw_circle(b.pos, r * 0.45, Color(1, 0.95, 0.95))

	for d in game.drones:
		_draw_drone(d, t, u)
	for ray in game.rays:
		var k: float = float(ray.age) / 0.25
		draw_line(ray.from, ray.to, Color(0.4, 1.0, 1.0, (1.0 - k) * 0.3), 8.0)
		draw_line(ray.from, ray.to, Color(0.85, 1.0, 1.0, 1.0 - k), 2.0)

	if game.lives > 0 or game.rules.lives == 0:
		if game.respawn_t <= 0.0:
			_draw_player(t, u)

	for p in game.popups:
		var k: float = float(p.age) / 1.2
		var col: Color = p.color
		var pos: Vector2 = p.pos + Vector2(0, -1.5 * u * k)
		var fs := int(p.get("size", 22))
		var w := _font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_font, pos - Vector2(w / 2.0, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, (1.0 - k) * 0.8))
		draw_string(_font, pos - Vector2(w / 2.0, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 1.0 - k))

# ---------- helpers ----------

## A glowing outline.
func _neon(pts: PackedVector2Array, color: Color, closed: bool = true, width: float = 2.0) -> void:
	var line := pts
	if closed:
		line = pts.duplicate()
		line.append(pts[0])
	draw_polyline(line, Color(color, color.a * 0.16), width * 3.6, true)
	draw_polyline(line, Color(color, color.a * 0.45), width * 2.0, true)
	draw_polyline(line, Color(color.lightened(0.35), color.a), width, true)

func _ring(pos: Vector2, r: float, color: Color, width: float = 2.0, segs: int = 24) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		pts.append(pos + Vector2(r, 0).rotated(i * TAU / segs))
	_neon(pts, color, true, width)

func _poly(pos: Vector2, r: float, sides: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		pts.append(pos + Vector2(r, 0).rotated(rot + i * TAU / sides))
	return pts

## A tiny yellow crystal: a thin elongated gem (not a box, so it can't be
## mistaken for an enemy) that shimmers rather than spins.
func _draw_gem(pos: Vector2, r: float, phase: float, color: Color, big: bool = false) -> void:
	var w := r * (0.55 if not big else 0.7)
	var h := r * 1.5
	var pts := PackedVector2Array([pos + Vector2(0, -h), pos + Vector2(w, -h * 0.2), pos + Vector2(0, h), pos + Vector2(-w, -h * 0.2)])
	_neon(pts, color, true, 1.2)
	var glint: float = 0.5 + 0.5 * sin(phase * 2.0)
	draw_circle(pos + Vector2(0, -h * 0.25), maxf(1.0, r * 0.18), Color(1, 1, 0.85, color.a * (0.5 + 0.5 * glint)))

# ---------- King zones, mines ----------

func _draw_zone(z: Dictionary, t: float, u: float) -> void:
	var r: float = float(z.r) * u
	var gold := Color(1.0, 0.85, 0.3)
	if z.active:
		var k: float = clampf(float(z.left) / float(z.life), 0.0, 1.0)
		draw_circle(z.pos, r, Color(gold, 0.07 + 0.05 * sin(t * 6.0)))
		_ring(z.pos, r, gold, 2.4, 64)
		draw_arc(z.pos, r + 0.35 * u, -PI / 2.0, -PI / 2.0 + TAU * k, 64, Color(1, 1, 1, 0.8), 3.0, true)
	else:
		var dash := 24
		for i in dash:
			if i % 2 == 0:
				var a0 := TAU * i / dash + t * 0.3
				draw_arc(z.pos, r, a0, a0 + TAU / dash, 6, Color(gold, 0.55), 2.0, true)
		draw_circle(z.pos, r, Color(gold, 0.03))

func _draw_mine(m: Dictionary, t: float, u: float) -> void:
	var armed: bool = float(m.age) >= Core.MINE_ARM
	var col := Color(1.0, 0.3, 0.3) if armed else Color(1.0, 0.6, 0.4, 0.5)
	var left: float = Core.MINE_LIFE - float(m.age)
	if left < 2.0 and int(left * 8.0) % 2 == 0:
		col.a *= 0.4
	var r := Core.MINE_RADIUS * u
	_neon(_poly(m.pos, r * 1.4, 4, t * 2.0), col, true, 1.3)
	draw_circle(m.pos, r * (0.35 + 0.15 * sin(t * 9.0 + m.pos.x)), Color(1, 0.8, 0.7, col.a))

# ---------- enemies ----------

func _draw_enemy(e: Dictionary, t: float, u: float) -> void:
	var col: Color = Core.color_of(e.type)
	var pos: Vector2 = e.pos
	var r: float = Core.radius_of(e.type)
	var warm: float = e.warm
	if warm > 0.0:
		# Spawning in: a ring that closes in on a dim, shrinking-out copy.
		var k: float = clampf(warm / Core.WARM_TIME, 0.0, 1.0)
		if e.type in Core.GATES:
			var ends := Core.gate_ends(e)
			_neon(PackedVector2Array([ends[0], ends[1]]), Color(col, 0.3 + 0.4 * (1.0 - k)), false, 1.2)
			return
		_ring(pos, r * (1.0 + 2.5 * k), Color(col, 0.7 * (1.0 - k) + 0.2), 1.5, 20)
		if e.type != "ufo":
			draw_circle(pos, r * 0.25 * (1.0 - k), Color(col, 0.6))
		return
	var spin: float = t * 3.0 + float(e.id)
	match e.type:
		"grunt":
			var pts := PackedVector2Array([pos + Vector2(0, -r * 1.2), pos + Vector2(r * 1.2, 0), pos + Vector2(0, r * 1.2), pos + Vector2(-r * 1.2, 0)])
			_neon(pts, col)
			_neon(PackedVector2Array([pos + Vector2(0, -r * 0.5), pos + Vector2(r * 0.5, 0), pos + Vector2(0, r * 0.5), pos + Vector2(-r * 0.5, 0)]), col, true, 1.4)
		"wanderer":
			for i in 4:
				var a := spin * 1.4 + i * PI / 2.0
				var tri := PackedVector2Array([pos, pos + Vector2(r * 1.2, 0).rotated(a), pos + Vector2(r * 1.2, r * 0.9).rotated(a)])
				_neon(tri, col, true, 1.6)
		"duck":
			_neon(_poly(pos, r * 1.35, 4, PI / 4.0), col)
		"rocket":
			var d: Vector2 = (e.dir as Vector2)
			var p := Vector2(-d.y, d.x)
			var pts := PackedVector2Array([pos + d * r * 1.4, pos - d * r * 0.9 + p * r * 0.95, pos - d * r * 0.3, pos - d * r * 0.9 - p * r * 0.95])
			var speed_k: float = clampf(float(e.slow), 0.0, 1.0)
			draw_line(pos - d * r * 0.8, pos - d * r * (1.0 + 4.0 * speed_k), Color(1.0, 0.6, 0.2, 0.45 * speed_k), r * 0.9)
			_neon(pts, col)
		"repulsor":
			# A blue rhino: armoured orange front, soft blue back.
			var d: Vector2 = e.dir
			var p := Vector2(-d.y, d.x)
			var charging: bool = e.state == "charge"
			if charging:
				draw_line(pos - d * r, pos - d * r * 5.0, Color(0.4, 0.6, 1.0, 0.3), r * 1.2)
			var back := PackedVector2Array([pos + p * r * 1.0, pos - d * r * 1.2 + p * r * 0.6, pos - d * r * 1.2 - p * r * 0.6, pos - p * r * 1.0])
			_neon(back, col, false, 2.0)
			var front := PackedVector2Array([pos + p * r * 1.1, pos + d * r * 0.6 + p * r * 0.7, pos + d * r * 1.6, pos + d * r * 0.6 - p * r * 0.7, pos - p * r * 1.1])
			var orange := Color(1.0, 0.55, 0.15)
			_neon(front, orange, false, 2.4)
			if e.state == "aim":
				var k: float = 1.0 - clampf(float(e.st) / Core.REPULSOR_AIM, 0.0, 1.0)
				draw_circle(pos + d * r * 0.4, r * 0.25, Color(1, 0.8, 0.4, 0.3 + 0.7 * k))
		"neutron":
			_ring(pos, r * 1.05, col, 1.8)
			for i in 3:
				var a := spin * 1.8 + i * TAU / 3.0
				_ring(pos + Vector2(r * 0.55, 0).rotated(a), r * 0.32, col, 1.3, 10)
		"gear":
			var teeth := PackedVector2Array()
			var fast: float = 1.0 + float(e.eaten) * 0.5
			for i in 16:
				var rr := r * (1.25 if i % 2 == 0 else 0.85)
				teeth.append(pos + Vector2(rr, 0).rotated(t * 2.0 * fast + i * TAU / 16.0))
			_neon(teeth, col, true, 1.6)
			_neon(PackedVector2Array([pos + Vector2(-r * 0.6, 0), pos + Vector2(r * 0.6, 0)]), col, false, 1.4)
		"mayfly":
			var a := (e.vel as Vector2).angle() if (e.vel as Vector2).length() > 1.0 else 0.0
			_neon(_poly(pos, r * 1.3, 3, a), col, true, 1.3)
		"weaver":
			_neon(_poly(pos, r * 1.35, 4, spin * 0.7 + PI / 4.0), col)
			_neon(_poly(pos, r * 0.65, 4, -spin * 0.7 + PI / 4.0), col, true, 1.3)
		"spinner", "mini":
			var sq := _poly(pos, r * 1.35, 4, spin * 0.9 + PI / 4.0)
			_neon(sq, col, true, 1.8 if e.type == "spinner" else 1.4)
			_neon(PackedVector2Array([sq[0], sq[2]]), col, false, 1.2)
			_neon(PackedVector2Array([sq[1], sq[3]]), col, false, 1.2)
		"snake":
			var segs: Array = e.segs
			for k in range(segs.size() - 1, -1, -1):
				var fade: float = 1.0 - float(k) / segs.size() * 0.6
				_ring(segs[k], 0.3 * u, Color(1.0, 0.8, 0.3, fade), 1.4, 8)
			var hd: Vector2 = (e.vel as Vector2).normalized() if (e.vel as Vector2).length() > 1.0 else Vector2.RIGHT
			var hp := Vector2(-hd.y, hd.x)
			_neon(PackedVector2Array([pos + hd * r * 1.5, pos + hp * r * 0.9, pos - hd * r * 0.7, pos - hp * r * 0.9]), col, true, 2.0)
			draw_circle(pos, r * 0.3, Color(1, 1, 1, 0.9))
		"well":
			_draw_well(e, t, u, col, r)
		"proton":
			# Little skittering circles: they jitter as they run.
			var jit := Vector2(sin(t * 31.0 + float(e.id)), cos(t * 27.0 + float(e.id) * 1.7)) * r * 0.15
			_ring(pos + jit, r * 1.1, col, 1.8, 14)
			draw_circle(pos + jit, r * 0.3, Color(0.8, 1.0, 1.0, 0.8))
		"ufo":
			var flat := PackedVector2Array()
			for i in 20:
				var a := i * TAU / 20.0
				flat.append(pos + Vector2(cos(a) * r * 1.5, sin(a) * r * 0.8).rotated(spin * 0.4))
			_neon(flat, col, true, 2.0)
			_ring(pos, r * 0.4, col, 1.4, 12)
		"nufo":
			var flat := PackedVector2Array()
			for i in 16:
				var a := i * TAU / 16.0
				flat.append(pos + Vector2(cos(a) * r * 1.45, sin(a) * r * 0.6))
			_neon(flat, col, true, 1.6)
			draw_arc(pos - Vector2(0, r * 0.25), r * 0.6, PI, TAU, 10, Color(col.lightened(0.4), 0.9), 1.6, true)
			draw_circle(pos + Vector2(sin(t * 8.0 + float(e.id)) * r * 0.8, r * 0.2), r * 0.15, Color(1, 1, 1, 0.8))
		"gate", "golden":
			var ends := Core.gate_ends(e)
			var golden: bool = e.type == "golden"
			var bar := Color(1.0, 0.9, 0.4) if golden else Color(0.9, 0.95, 1.0)
			if golden and float(e.life) < 2.0 and int(float(e.life) * 8.0) % 2 == 0:
				bar.a = 0.4
			_neon(PackedVector2Array([ends[0], ends[1]]), Color(bar, bar.a * 0.85), false, 2.0)
			for end in ends:
				_neon(_poly(end, r * 1.2, 6, t * 2.5), col, true, 2.0)
				draw_circle(end, r * 0.45, Color(col.lightened(0.4), 0.9))
		"layer":
			var hop: float = absf(sin(float(e.t) * PI / 0.6)) * 0.2 * r
			var body := _poly(pos - Vector2(0, hop), r * 1.1, 4, PI / 4.0)
			_neon(body, col, true, 1.8)
			for i in 4:
				var a := i * PI / 2.0 + PI / 4.0
				_neon(PackedVector2Array([pos + Vector2(r * 0.8, 0).rotated(a), pos + Vector2(r * 1.5, 0).rotated(a + 0.4)]), col, false, 1.2)
			draw_circle(pos - Vector2(0, hop), r * 0.3, Color(1.0, 0.3, 0.3, 0.9))

## A black hole: its pull shows as a faint field (dormant) or a swirling
## vortex (awake), and it swells with everything it eats.
func _draw_well(e: Dictionary, t: float, u: float, col: Color, r: float) -> void:
	var pos: Vector2 = e.pos
	var active: bool = e.active
	var grow: float = Core.well_scale(e)
	var pulse_k: float = 0.5 + 0.5 * sin(t * (9.0 if active else 3.0))
	var wc: Color = col if active else Color(col, 0.6)
	var field: float = Core.well_range(e) * u
	if active:
		# The vortex: arms spiralling in toward the core.
		for arm in 5:
			var pts := PackedVector2Array()
			for k in 14:
				var f: float = 1.0 - k / 13.0
				var a: float = arm * TAU / 5.0 + f * 3.2 - t * 3.5
				pts.append(pos + Vector2(cos(a), sin(a)) * (r * grow * 1.1 + f * field * 0.5))
			draw_polyline(pts, Color(col, 0.18), 2.0, true)
		_ring(pos, field * (0.3 + 0.05 * pulse_k), Color(col, 0.22), 1.2, 40)
	else:
		_ring(pos, field * 0.45, Color(col, 0.08 + 0.05 * pulse_k), 1.0, 32)
	draw_circle(pos, r * grow * 0.95, Color(0.02, 0.0, 0.0, 0.85))
	for i in 3:
		_ring(pos, r * grow * (0.45 + 0.28 * i + (0.08 * pulse_k if active else 0.0)), wc, 1.6, 28)
	if active:
		draw_circle(pos, r * 0.3, Color(1, 0.9, 0.8, 0.9))
		# Close to bursting: it throbs.
		var full: float = float(e.eaten) / Core.WELL_BURST_AT
		if full > 0.6:
			_ring(pos, r * grow * (1.1 + 0.15 * sin(t * 25.0)), Color(1, 0.9, 0.6, full * 0.6), 2.0, 28)

# ---------- bosses ----------

func _draw_boss(b: Dictionary, t: float, u: float) -> void:
	var col: Color = Bosses.color_of(b)
	if float(b.flash) > 0.0:
		col = col.lerp(Color.WHITE, 0.7)
	var pos: Vector2 = b.pos
	var warm: float = b.warm
	if warm > 0.0:
		# Arriving: a big closing ring and a growing ghost.
		var k: float = clampf(warm / 2.0, 0.0, 1.0)
		_ring(pos, Bosses.body_radius(b) * (1.0 + 3.0 * k), Color(col, 0.8 * (1.0 - k) + 0.1), 3.0, 48)
		_ring(pos, Bosses.body_radius(b) * (1.0 - k), Color(col, 0.4), 2.0, 32)
		return
	match b.kind:
		"queen":
			var core := _poly(pos, Bosses.QUEEN_CORE * u, 6, t * 0.8)
			_neon(core, col, true, 3.0)
			_neon(_poly(pos, Bosses.QUEEN_CORE * u * 0.55, 6, -t * 1.3), col, true, 2.0)
			draw_circle(pos, Bosses.QUEEN_CORE * u * 0.25, Color(1, 0.85, 0.95, 0.7 + 0.3 * sin(t * 6.0)))
			var seg := TAU / Bosses.QUEEN_PLATES
			for i in Bosses.QUEEN_PLATES:
				var hp: int = b.plates[i]
				if hp <= 0:
					continue
				var a0: float = float(b.rot) + i * seg - seg * 0.42
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(pos + Vector2(cos(a0 + seg * 0.84 * k / 6.0), sin(a0 + seg * 0.84 * k / 6.0)) * Bosses.QUEEN_RING * u)
				var pc := Color(1.0, 0.75, 0.3).lerp(col, 0.5)
				pc.a = 0.45 + 0.55 * clampf(hp / 4.0, 0.0, 1.0)
				_neon(pts, pc, false, 4.0)
		"serpent":
			var tail := Bosses.serpent_tail(b)
			for k in range(b.segs.size() - 1, -1, -1):
				var sp: Vector2 = b.segs[k]
				var weak: bool = k == tail
				var sc := Color(1.0, 0.95, 0.4) if weak else col
				_ring(sp, Bosses.SERPENT_SEG_R * u * (1.0 + (0.15 * sin(t * 12.0) if weak else 0.0)), sc, 2.2 if weak else 1.6, 14)
				if weak:
					draw_circle(sp, Bosses.SERPENT_SEG_R * u * 0.4, Color(1, 1, 0.8, 0.8))
			var hd: Vector2 = b.dir
			var hp := Vector2(-hd.y, hd.x)
			var hr := 0.9 * u
			var head := PackedVector2Array([pos + hd * hr * 1.8, pos + hp * hr * 1.1, pos - hd * hr * 0.8, pos - hp * hr * 1.1])
			_neon(head, Color(1, 1, 0.6) if tail < 0 else col, true, 3.0)
			for s in [-1.0, 1.0]:
				draw_circle(pos + hd * hr * 0.4 + hp * s * hr * 0.45, hr * 0.18, Color(1, 0.3, 0.3))
		"lord":
			var r := Bosses.LORD_R * u
			var angry: bool = int(b.phase) >= 2
			for arm in 7:
				var pts := PackedVector2Array()
				for k in 18:
					var f: float = 1.0 - k / 17.0
					var a: float = arm * TAU / 7.0 + f * 4.0 - t * (4.0 if angry else 2.5)
					pts.append(pos + Vector2(cos(a), sin(a)) * (r * 1.05 + f * r * 3.5))
				draw_polyline(pts, Color(col, 0.22), 2.5, true)
			draw_circle(pos, r, Color(0.02, 0.0, 0.0, 0.92))
			for i in 4:
				_ring(pos, r * (0.4 + 0.2 * i + 0.05 * sin(t * 5.0 + i)), col, 2.4 - i * 0.3, 40)
			draw_circle(pos, r * 0.2, Color(1, 0.85, 0.6, 0.9))
		"titan":
			var r := Bosses.TITAN_R * u
			var guns := 0
			for h in b.turrets:
				if int(h) > 0:
					guns += 1
			var body := _poly(pos, r, 8, float(b.rot))
			_neon(body, col, true, 3.2)
			_neon(_poly(pos, r * 0.62, 8, -float(b.rot) * 1.5), col, true, 2.0)
			var core_col := Color(1, 0.4, 0.3) if guns == 0 else Color(col, 0.5)
			draw_circle(pos, r * 0.28, Color(core_col, 0.85 if guns == 0 else 0.4))
			for i in 4:
				if int(b.turrets[i]) <= 0:
					continue
				var tp := Bosses.turret_pos(b, i)
				var aim: Vector2 = (game.player_pos - tp).normalized()
				_neon(_poly(tp, Bosses.TITAN_TURRET_R * u, 4, float(b.rot) + PI / 4.0), Color(0.9, 0.95, 1.0), true, 2.2)
				_neon(PackedVector2Array([tp, tp + aim * 1.1 * u]), Color(1, 0.5, 0.4), false, 2.4)
			if b.get("state", "") == "charge":
				draw_line(pos, pos - (b.dir as Vector2) * r * 2.5, Color(col, 0.3), r * 0.8)

# ---------- drones ----------

func _draw_drone(d: Dictionary, t: float, u: float) -> void:
	var col: Color = Drones.color_of(d.kind)
	var pos: Vector2 = d.pos
	if d.kind == "sweep":
		draw_arc(game.player_pos, Drones.SWEEP_RADIUS * u, 0, TAU, 48, Color(col, 0.12), 2.0, true)
	var dir: Vector2 = (d.vel as Vector2).normalized() if (d.vel as Vector2).length() > 1.0 else game.ship_dir
	var p := Vector2(-dir.y, dir.x)
	var s := 0.4 * u
	_neon(PackedVector2Array([pos + dir * s, pos - dir * s * 0.7 + p * s * 0.7, pos - dir * s * 0.3, pos - dir * s * 0.7 - p * s * 0.7]), col, true, 1.5)
	draw_circle(pos, s * 0.2, Color(1, 1, 1, 0.6 + 0.4 * sin(t * 8.0)))

# ---------- player ----------

func _draw_player(t: float, u: float) -> void:
	var pos: Vector2 = game.player_pos
	var inv: float = game.invuln_timer
	# Flicker in the last second, as the shield is about to drop.
	if inv > 0.0 and inv < 1.0 and int(inv * 12.0) % 2 == 0:
		pass
	else:
		var d: Vector2 = game.ship_dir
		var p := Vector2(-d.y, d.x)
		var speed_k: float = clampf(float(game.thrust), 0.0, 1.0)
		if speed_k > 0.05:
			var blue := Color(0.5, 0.75, 1.0)
			for k in 3:
				var off := p * (k - 1) * 0.18 * u
				draw_line(pos - d * 0.5 * u + off, pos - d * (1.0 + 2.2 * speed_k) * u + off, Color(blue, 0.18 - k % 2 * 0.06), 0.3 * u)
		var white := Color(0.85, 0.95, 1.0)
		# Two nested chevrons: the C-shaped claw.
		_neon(PackedVector2Array([pos + d * 0.75 * u + p * 0.0, pos - d * 0.55 * u + p * 0.7 * u, pos - d * 0.25 * u]), white, false, 1.8)
		_neon(PackedVector2Array([pos + d * 0.75 * u, pos - d * 0.55 * u - p * 0.7 * u, pos - d * 0.25 * u]), white, false, 1.8)
		_neon(PackedVector2Array([pos + d * 0.35 * u, pos - d * 0.35 * u + p * 0.4 * u, pos - d * 0.15 * u, pos - d * 0.35 * u - p * 0.4 * u]), Color(0.6, 0.8, 1.0), true, 1.2)
	if inv > 0.0:
		# The shield halo, pulsing faster as it runs out.
		var rate: float = 5.0 if inv > 1.0 else 16.0
		var pulse_k: float = 0.5 + 0.5 * sin(t * rate)
		var hr: float = (1.15 + 0.12 * pulse_k) * u
		draw_arc(pos, hr, 0, TAU, 40, Color(0.6, 0.9, 1.0, 0.18), 0.5 * u, true)
		draw_arc(pos, hr, 0, TAU, 40, Color(0.7, 0.95, 1.0, 0.55 + 0.3 * pulse_k), 2.0, true)
	# King: a small crown over the ship while it can shoot.
	if game.rules.king and game.king_zone >= 0:
		_neon(PackedVector2Array([pos + Vector2(-0.4, -1.0) * u, pos + Vector2(-0.4, -1.4) * u, pos + Vector2(-0.15, -1.2) * u,
			pos + Vector2(0, -1.5) * u, pos + Vector2(0.15, -1.2) * u, pos + Vector2(0.4, -1.4) * u, pos + Vector2(0.4, -1.0) * u]), Color(1, 0.85, 0.3), true, 1.4)
