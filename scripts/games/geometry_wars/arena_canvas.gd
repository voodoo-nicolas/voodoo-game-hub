extends Node2D

## Positioned at arena_offset by the parent controller, so every draw call here
## uses arena-local coordinates matching the entity positions in `game`.
var game: Control

const CRYSTAL_LIFE := 3.0

func _draw() -> void:
	if game == null:
		return

	draw_rect(Rect2(Vector2.ZERO, game.arena_size), Color(0.3, 0.3, 0.42), false, 2.0)
	var t := Time.get_ticks_msec() / 1000.0

	if game.shockwave_t >= 0.0:
		var k: float = game.shockwave_t / game.SHOCKWAVE_TIME
		var r: float = lerpf(20.0, game.arena_size.length(), k)
		draw_arc(game.player_pos, r, 0, TAU, 96, Color(1, 0.7, 0.3, 1.0 - k), 10.0 * (1.0 - k) + 2.0, true)
		draw_arc(game.player_pos, r * 0.8, 0, TAU, 96, Color(1, 1, 1, (1.0 - k) * 0.5), 3.0, true)

	for p in game.particles:
		var pt: float = p.age / p.lifetime
		var radius: float = lerp(4.0, 34.0, pt)
		draw_circle(p.pos, radius, Color(1.0, 0.6, 0.2, (1.0 - pt) * 0.6))

	# Crystals: small spinning green gems that blink out in their last second.
	for c in game.crystals:
		var left: float = CRYSTAL_LIFE - c.age
		var a: float = 1.0 if left > 1.0 else (0.35 + 0.65 * absf(sin(left * 18.0)))
		_draw_gem(c.pos, 10.0, t * 4.0 + c.pos.x, Color(0.35, 1.0, 0.5, a))

	for b in game.bullets:
		draw_circle(b.pos, 4.0, Color(0.6, 1.0, 1.0))

	for e in game.enemies:
		match e.type:
			"seeker":
				_draw_diamond(e.pos, 16.0, Color(1.0, 0.2, 0.55))
			"wanderer":
				_draw_square(e.pos, 16.0, Color(1.0, 0.7, 0.1))
			"weaver":
				_draw_outline_square(e.pos, 15.0, t * 2.0, Color(0.35, 1.0, 0.35))
			"splitter":
				_draw_pinwheel(e.pos, 17.0, t * 5.0, Color(0.75, 0.35, 1.0))
			"mini":
				_draw_pinwheel(e.pos, 9.0, t * 9.0, Color(0.85, 0.55, 1.0))
			"dart":
				_draw_dart(e.pos, 16.0, e.vel, Color(1.0, 0.95, 0.25), e.get("charging", false))
			"tank":
				_draw_hexagon(e.pos, 22.0, int(e.get("hp", 3)), Color(1.0, 0.25, 0.2))
			_:
				_draw_square(e.pos, 16.0, Color(1.0, 0.7, 0.1))

	if game.lives > 0:
		var flashing_hidden: bool = game.invuln_timer > 0.0 and int(game.invuln_timer * 10.0) % 2 == 0
		if not flashing_hidden:
			_draw_player(game.player_pos, game.last_aim_dir)

func _draw_diamond(pos: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r, 0), pos + Vector2(0, r), pos + Vector2(-r, 0)])
	draw_colored_polygon(pts, color)

func _draw_square(pos: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([pos + Vector2(-r, -r), pos + Vector2(r, -r), pos + Vector2(r, r), pos + Vector2(-r, r)])
	draw_colored_polygon(pts, color)

func _draw_outline_square(pos: Vector2, r: float, angle: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 5:
		pts.append(pos + Vector2(r, 0).rotated(angle + PI / 4.0 + i * PI / 2.0) * 1.3)
	draw_polyline(pts, color, 3.0, true)
	draw_circle(pos, 3.0, color)

func _draw_pinwheel(pos: Vector2, r: float, angle: float, color: Color) -> void:
	for i in 4:
		var a := angle + i * PI / 2.0
		var tri := PackedVector2Array([pos, pos + Vector2(r, 0).rotated(a), pos + Vector2(r, r * 0.8).rotated(a)])
		draw_colored_polygon(tri, color)

func _draw_dart(pos: Vector2, r: float, vel: Vector2, color: Color, charging: bool) -> void:
	var d: Vector2 = vel.normalized() if vel.length() > 0.01 else Vector2.RIGHT
	var p := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([pos + d * r * 1.2, pos - d * r * 0.8 + p * r * 0.8, pos - d * r * 0.3, pos - d * r * 0.8 - p * r * 0.8])
	draw_colored_polygon(pts, color)
	if charging:  # speed streak
		draw_line(pos - d * r, pos - d * r * 2.4, Color(color, 0.5), 3.0)

func _draw_hexagon(pos: Vector2, r: float, hp: int, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		pts.append(pos + Vector2(r, 0).rotated(i * TAU / 6.0))
	draw_colored_polygon(pts, Color(color, 0.25))
	draw_polyline(pts, color, 3.0, true)
	for i in hp:  # one pip per hit left
		draw_circle(pos + Vector2((i - (hp - 1) / 2.0) * 9.0, 0), 3.0, color)

func _draw_gem(pos: Vector2, r: float, angle: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 4:
		var rr := r if i % 2 == 0 else r * 0.6
		pts.append(pos + Vector2(rr, 0).rotated(angle + i * PI / 2.0))
	draw_colored_polygon(pts, color)

func _draw_player(pos: Vector2, dir: Vector2) -> void:
	var d: Vector2 = dir if dir.length() > 0.01 else Vector2.UP
	var perp: Vector2 = d.rotated(PI / 2.0)
	var tip: Vector2 = pos + d * 18.0
	var back1: Vector2 = pos - d * 12.0 + perp * 12.0
	var back2: Vector2 = pos - d * 12.0 - perp * 12.0
	draw_colored_polygon(PackedVector2Array([tip, back1, back2]), Color(0.3, 1.0, 1.0))
