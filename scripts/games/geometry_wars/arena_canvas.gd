extends Node2D

## Positioned at arena_offset by the parent controller, so every draw call here
## uses arena-local coordinates matching the entity positions in `game`.
## Everything is drawn as glowing vector lines: each outline is stroked three
## times (wide faint, medium, thin bright) to fake the neon bloom.
var game: Control

const Core = preload("res://scripts/games/geometry_wars/geometry_wars_core.gd")

const GRID_COLOR := Color(0.18, 0.4, 0.9)
const SPRING := 38.0
const DAMPING := 3.2
const COUPLING := 55.0

# The background grid: a sheet of springs that ripples when things explode.
var grid_nx := 0
var grid_ny := 0
var grid_step := Vector2.ONE
var grid_off := PackedVector2Array()
var grid_vel := PackedVector2Array()
var grid_awake := 0.0
var grid_lines := PackedVector2Array()
var grid_dirty := true

func reset_grid() -> void:
	var u: float = Core.U
	grid_ny = 20
	grid_nx = int(ceil(game.arena_size.x / u)) + 1
	grid_step = Vector2(game.arena_size.x / float(grid_nx - 1), game.arena_size.y / float(grid_ny - 1))
	grid_off = PackedVector2Array()
	grid_off.resize(grid_nx * grid_ny)
	grid_vel = PackedVector2Array()
	grid_vel.resize(grid_nx * grid_ny)
	grid_awake = 0.0
	grid_dirty = true

## A ripple: positive `strength` shoves the grid away from `pos`, negative
## pulls it in. `radius` is in pixels.
func pulse(pos: Vector2, strength: float, radius: float) -> void:
	if grid_nx == 0:
		return
	var i0 := maxi(0, int((pos.x - radius) / grid_step.x))
	var i1 := mini(grid_nx - 1, int((pos.x + radius) / grid_step.x) + 1)
	var j0 := maxi(0, int((pos.y - radius) / grid_step.y))
	var j1 := mini(grid_ny - 1, int((pos.y + radius) / grid_step.y) + 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var idx := j * grid_nx + i
			var p := Vector2(i * grid_step.x, j * grid_step.y) + grid_off[idx]
			var off := p - pos
			var d := off.length()
			if d < radius and d > 0.01:
				grid_vel[idx] += off / d * strength * (1.0 - d / radius)
	grid_awake = 2.5

func _process(delta: float) -> void:
	if grid_awake <= 0.0 or grid_nx == 0:
		return
	grid_awake -= delta
	var dt := minf(delta, 0.033)
	for j in grid_ny:
		for i in grid_nx:
			var idx := j * grid_nx + i
			var o := grid_off[idx]
			var f := -o * SPRING
			if i > 0:
				f += (grid_off[idx - 1] - o) * COUPLING
			if i < grid_nx - 1:
				f += (grid_off[idx + 1] - o) * COUPLING
			if j > 0:
				f += (grid_off[idx - grid_nx] - o) * COUPLING
			if j < grid_ny - 1:
				f += (grid_off[idx + grid_nx] - o) * COUPLING
			grid_vel[idx] = (grid_vel[idx] + f * dt) * maxf(0.0, 1.0 - DAMPING * dt)
	for j in grid_ny:
		for i in grid_nx:
			var idx := j * grid_nx + i
			if i == 0 or j == 0 or i == grid_nx - 1 or j == grid_ny - 1:
				grid_off[idx] = Vector2.ZERO  # the frame stays put
				continue
			grid_off[idx] += grid_vel[idx] * dt
	grid_dirty = true

func _draw_grid() -> void:
	if grid_nx == 0:
		return
	if grid_dirty:
		grid_lines.resize(0)
		for j in grid_ny:
			for i in grid_nx:
				var idx := j * grid_nx + i
				var p := Vector2(i * grid_step.x, j * grid_step.y) + grid_off[idx]
				if i < grid_nx - 1:
					grid_lines.append(p)
					grid_lines.append(Vector2((i + 1) * grid_step.x, j * grid_step.y) + grid_off[idx + 1])
				if j < grid_ny - 1:
					grid_lines.append(p)
					grid_lines.append(Vector2(i * grid_step.x, (j + 1) * grid_step.y) + grid_off[idx + grid_nx])
		grid_dirty = false
	draw_multiline(grid_lines, Color(GRID_COLOR, 0.14), 4.0)
	draw_multiline(grid_lines, Color(GRID_COLOR, 0.55), 1.2)

func _draw() -> void:
	if game == null:
		return
	var u: float = Core.U
	var t := Time.get_ticks_msec() / 1000.0

	_draw_grid()
	_neon(PackedVector2Array([Vector2.ZERO, Vector2(game.arena_size.x, 0), game.arena_size, Vector2(0, game.arena_size.y)]), Color(0.35, 0.6, 1.0), true, 2.5)

	if game.shockwave_t >= 0.0:
		var k: float = game.shockwave_t / game.SHOCKWAVE_TIME
		var r: float = lerpf(20.0, game.arena_size.length(), k)
		draw_arc(game.player_pos, r, 0, TAU, 96, Color(1, 0.7, 0.3, 1.0 - k), 10.0 * (1.0 - k) + 2.0, true)
		draw_arc(game.player_pos, r * 0.8, 0, TAU, 96, Color(1, 1, 1, (1.0 - k) * 0.5), 3.0, true)

	# Geoms: small spinning green gems that blink out in their last second.
	for c in game.crystals:
		var left: float = Core.CRYSTAL_LIFE - c.age
		var a: float = 1.0 if left > 1.0 else (0.35 + 0.65 * absf(sin(left * 18.0)))
		var big: bool = int(c.get("v", 1)) > 1
		_draw_gem(c.pos, (0.5 if big else 0.2) * u, t * 3.0 + c.pos.x, Color(1.0, 0.65, 0.15, a) if big else Color(1.0, 0.92, 0.25, a), big)

	for e in game.enemies:
		_draw_enemy(e, t, u)

	# Sparks from explosions.
	for p in game.particles:
		var k: float = p.age / p.lifetime
		var dir: Vector2 = p.vel.normalized()
		var tail: Vector2 = p.pos - dir * (p.len * (1.0 - k) + 2.0)
		var col: Color = p.color
		draw_line(tail, p.pos, Color(col, (1.0 - k) * 0.25), 6.0)
		draw_line(tail, p.pos, Color(col.lightened(0.5), 1.0 - k), 2.0)

	# Bullets: orange darts that streak behind them.
	for b in game.bullets:
		var d: Vector2 = b.vel.normalized()
		var side := Vector2(-d.y, d.x)
		var front: Vector2 = b.pos + d * 0.5 * u
		var back: Vector2 = b.pos - d * 0.25 * u
		draw_line(back, back - d * 1.6 * u, Color(1.0, 0.6, 0.15, 0.25), 0.28 * u)
		draw_colored_polygon(PackedVector2Array([front, back + side * 0.1 * u, back - side * 0.1 * u]), Color(1.0, 0.65, 0.2))
		draw_line(front, back, Color(1.0, 0.95, 0.7), 1.5)

	if game.lives > 0:
		_draw_player(t, u)

# ---------- helpers ----------

## A glowing outline.
func _neon(pts: PackedVector2Array, color: Color, closed: bool = true, width: float = 2.0) -> void:
	var line := pts
	if closed:
		line = pts.duplicate()
		line.append(pts[0])
	draw_polyline(line, Color(color, 0.16), width * 3.6, true)
	draw_polyline(line, Color(color, 0.45), width * 2.0, true)
	draw_polyline(line, color.lightened(0.35), width, true)

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

# ---------- enemies ----------

func _draw_enemy(e: Dictionary, t: float, u: float) -> void:
	var col: Color = Core.color_of(e.type)
	var pos: Vector2 = e.pos
	var r: float = Core.radius_of(e.type)
	var warm: float = e.warm
	if warm > 0.0:
		# Spawning in: a ring that closes in on a dim, shrinking-out copy.
		var k: float = clampf(warm / Core.WARM_TIME, 0.0, 1.0)
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
			_neon(PackedVector2Array([pos + Vector2(-r * 0.6, 0), pos + Vector2(r * 0.6, 0)]).duplicate(), col, false, 1.4)
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
			var active: bool = e.active
			var grow: float = 1.0 + float(e.eaten) * 0.07
			var pulse_k: float = 0.5 + 0.5 * sin(t * (9.0 if active else 3.0))
			var wc: Color = col if active else Color(col, 0.6)
			for i in 3:
				_ring(pos, r * grow * (0.45 + 0.28 * i + (0.08 * pulse_k if active else 0.0)), wc, 1.6, 28)
			if active:
				var rng := Core.WELL_RANGE * u
				_ring(pos, rng * (0.25 + 0.04 * pulse_k), Color(col, 0.25), 1.2, 40)
				draw_circle(pos, r * 0.3, Color(1, 0.9, 0.8, 0.9))
		"proton":
			_ring(pos, r * 1.1, col, 1.8, 14)
		"ufo":
			var flat := PackedVector2Array()
			for i in 20:
				var a := i * TAU / 20.0
				flat.append(pos + Vector2(cos(a) * r * 1.5, sin(a) * r * 0.8).rotated(spin * 0.4))
			_neon(flat, col, true, 2.0)
			_ring(pos, r * 0.4, col, 1.4, 12)

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
