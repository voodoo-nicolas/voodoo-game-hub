extends Node2D

## Positioned at arena_offset by the parent controller, so every draw call here
## uses arena-local coordinates matching the entity positions in `game`.
var game: Control

func _draw() -> void:
	if game == null:
		return

	draw_rect(Rect2(Vector2.ZERO, game.arena_size), Color(0.3, 0.3, 0.42), false, 2.0)

	for p in game.particles:
		var t: float = p.age / p.lifetime
		var radius: float = lerp(4.0, 34.0, t)
		draw_circle(p.pos, radius, Color(1.0, 0.6, 0.2, (1.0 - t) * 0.6))

	for b in game.bullets:
		draw_circle(b.pos, 4.0, Color(0.6, 1.0, 1.0))

	for e in game.enemies:
		if e.type == "seeker":
			_draw_diamond(e.pos, 16.0, Color(1.0, 0.2, 0.55))
		else:
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

func _draw_player(pos: Vector2, dir: Vector2) -> void:
	var d: Vector2 = dir if dir.length() > 0.01 else Vector2.UP
	var perp: Vector2 = d.rotated(PI / 2.0)
	var tip: Vector2 = pos + d * 18.0
	var back1: Vector2 = pos - d * 12.0 + perp * 12.0
	var back2: Vector2 = pos - d * 12.0 - perp * 12.0
	draw_colored_polygon(PackedVector2Array([tip, back1, back2]), Color(0.3, 1.0, 1.0))
