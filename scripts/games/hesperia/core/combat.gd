extends RefCounted

## Direction vectors are cardinal (Vector2i). Crab shell protects the front.
static func crab_hit_mult(hit_dir: Vector2i, crab_facing: Vector2i) -> int:
	# hit_dir = direction the attack travels. Front attack travels opposite to the crab's facing.
	if hit_dir == -crab_facing:
		return 0      ## shell: blocked
	return 1

static func knockback(from: Vector2, to: Vector2, force: float) -> Vector2:
	var d := (to - from)
	if d.length() < 0.01:
		d = Vector2.DOWN
	return d.normalized() * force
