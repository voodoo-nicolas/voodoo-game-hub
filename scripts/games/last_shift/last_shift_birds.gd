extends Node2D

## A small flock of birds on the ground outside (pigeons at dusk, crows at dawn). They peck and
## hop around inside their area and all take off together when Nash comes close (or a shot goes
## off), flying away over the roofs. Pure decoration: no collision, no story effect.
##
## Room data (in "props", kind "birds", solid false): {"id", "rect": Rect2i area in tiles,
##   "count": int}. The world passes `dawn` so the flock is crows instead of pigeons.

const A = preload("res://scripts/games/last_shift/last_shift_art.gd")

const SCARE_RANGE := 75.0
const FLY_SPEED := 190.0

var world: Node = null
var nash: Node2D = null
var area := Rect2()
var crows := false
var flying := false
var _birds: Array = []      # {p: Vector2, hop: Vector2, t: float, flip: float, peck: float, v: Vector2}
var _t := 0.0

func setup(data: Dictionary, world_node: Node, nash_node: Node2D, dawn: bool) -> void:
	world = world_node
	nash = nash_node
	crows = dawn
	var r: Rect2i = data.rect
	area = Rect2(Vector2(r.position * 32), Vector2(r.size * 32))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(data.id)
	for i in int(data.get("count", 5)):
		_birds.append({
			"p": area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y),
			"hop": Vector2.ZERO, "t": rng.randf() * 3.0, "flip": 1.0 if rng.randf() < 0.5 else -1.0,
			"peck": 0.0, "v": Vector2.ZERO})
	z_index = int(area.position.y + area.size.y * 0.5)

## Everyone up! (Nash too close, or a loud noise.)
func scare(from: Vector2) -> void:
	if flying:
		return
	flying = true
	z_index = 2500
	for b in _birds:
		var away: Vector2 = (b.p - from).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		b.v = (away + Vector2(0, -0.9) + Vector2(randf_range(-0.3, 0.3), 0)).normalized() * FLY_SPEED * randf_range(0.8, 1.2)
		b.flip = signf(b.v.x) if b.v.x != 0.0 else 1.0
	if world != null and world.has_method("on_birds_scared"):
		world.on_birds_scared(self)

func _process(delta: float) -> void:
	_t += delta
	if not flying and nash != null and nash.visible:
		for b in _birds:
			if b.p.distance_to(nash.position) < SCARE_RANGE:
				scare(nash.position)
				break
	for b in _birds:
		if flying:
			b.v *= 1.0 + delta * 0.6        # speeding up as they climb
			b.p += b.v * delta
			continue
		# on the ground: peck now and then, hop to a new spot now and then
		b.t -= delta
		b.peck = maxf(0.0, b.peck - delta)
		if b.t <= 0.0:
			b.t = randf_range(0.8, 2.6)
			if randf() < 0.55:
				b.peck = 0.35
			else:
				var to: Vector2 = b.p + Vector2(randf_range(-28, 28), randf_range(-14, 14))
				to.x = clampf(to.x, area.position.x, area.end.x)
				to.y = clampf(to.y, area.position.y, area.end.y)
				b.hop = to - b.p
				b.flip = signf(b.hop.x) if absf(b.hop.x) > 1.0 else b.flip
		if b.hop.length() > 0.5:
			var step: Vector2 = b.hop.limit_length(60.0 * delta)
			b.p += step
			b.hop -= step
	if flying and _t > 0.0:
		var gone := true
		for b in _birds:
			if b.p.y > -200.0:
				gone = false
		if gone:
			queue_free()
	queue_redraw()

func _draw() -> void:
	var body := Color("1f1f24") if crows else Color("8d939c")
	var wing := Color("141418") if crows else Color("6b717a")
	var head := Color("1f1f24") if crows else Color("5e6a72")
	for b in _birds:
		var p: Vector2 = b.p - position
		var f: float = b.flip
		if flying:
			# wings flapping up and down
			var flap := sin(_t * 22.0 + p.x) * 6.0
			draw_line(p, p + Vector2(-8 * f, -flap), A.INK, 3.0)
			draw_line(p, p + Vector2(8 * f, -flap), A.INK, 3.0)
			draw_line(p, p + Vector2(-7 * f, -flap), wing, 1.6)
			draw_line(p, p + Vector2(7 * f, -flap), wing, 1.6)
			A.ink_circle(self, p, 3.0, body, 1.2)
			continue
		var bob := 2.5 if b.peck > 0.0 else 0.0
		var hop_lift := -2.0 if b.hop.length() > 0.5 else 0.0
		A.shadow(self, p + Vector2(0, 4), 5.0, 1.6, 0.3)
		p.y += hop_lift
		# body, tail, wing, head, beak, legs
		draw_line(p + Vector2(1, 3), p + Vector2(1, 5), Color("d9772e"), 1.0)
		draw_line(p + Vector2(-1, 3), p + Vector2(-1, 5), Color("d9772e"), 1.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-5 * f, -1), p + Vector2(-9 * f, -3),
			p + Vector2(-8 * f, 1)]), A.INK)
		A.ink_circle(self, p, 4.2, body, 1.4)
		draw_circle(p + Vector2(-1 * f, 0.5), 2.4, wing)
		var hp := p + Vector2(4 * f, -3 + bob)
		A.ink_circle(self, hp, 2.4, head, 1.2)
		draw_line(hp + Vector2(2 * f, 0.4), hp + Vector2(4.2 * f, 1.0), Color("3a3a36") if crows else Color("d9a35a"), 1.4)
		draw_circle(hp + Vector2(0.8 * f, -0.6), 0.6, Color.WHITE if not crows else Color("c9ccd3"))
