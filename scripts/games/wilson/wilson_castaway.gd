extends Node2D

## Beached: Johnny, PLACEHOLDER art (KICKOFF: placeholder until the Gemini sprite sheet exists,
## README open question 2). Drawn in code from rectangles (cheap draw calls): torn waistcoat, rolled
## trousers, barefoot. Origin = his feet, in plate pixels. Poses: idle, walk, work, chop, fish, sleep.

const SKIN := Color("e0a878")
const SHIRT := Color("efe9d8")
const VEST := Color("7a4a2a")
const PANTS := Color("3b4f74")
const HAIR := Color("3a2a1e")
const OUTLINE := Color("2a1c12")

var pose := "idle"
var facing := 1.0          # 1 right, -1 left
var target := Vector2.ZERO
var walking := false
var _t := 0.0

signal arrived

func _process(dt: float) -> void:
	_t += dt
	if walking:
		var to := target - position
		var step := 150.0 * dt
		if absf(to.x) > 2.0:
			facing = signf(to.x)
		if to.length() <= step:
			position = target
			walking = false
			arrived.emit()
		else:
			position += to.normalized() * step
	# a little smaller towards the back lanes (depth)
	var depth := clampf((position.y - 430.0) / 110.0, 0.0, 1.0)
	scale = Vector2(facing, 1.0) * lerpf(0.9, 1.08, depth)
	queue_redraw()

func walk_to(p: Vector2) -> void:
	target = p
	walking = position.distance_to(p) > 2.0
	if not walking:
		arrived.emit()

## Head position in plate pixels (for the thought bubble).
func head_global() -> Vector2:
	if pose == "sleep":
		return position + Vector2(0, -26)
	return position + Vector2(0, -92) * absf(scale.y)

func _limb(at: Vector2, angle: float, size: Vector2, col: Color) -> void:
	draw_set_transform(at, angle, Vector2.ONE)
	draw_rect(Rect2(-size.x / 2.0 - 1.0, -1.0, size.x + 2.0, size.y + 2.0), OUTLINE)
	draw_rect(Rect2(-size.x / 2.0, 0.0, size.x, size.y), col)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw() -> void:
	# shadow
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.22))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if pose == "sleep":
		_draw_lying()
		return
	var walk := walking or pose == "walk"
	var swing := sin(_t * 9.0) * 0.5 if walk else 0.0
	var bob := absf(sin(_t * 9.0)) * 2.0 if walk else sin(_t * 2.0) * 0.8
	var hip := Vector2(0, -40 - bob)
	# legs (rolled trousers + bare shins)
	_limb(hip + Vector2(-5, 0), swing, Vector2(9, 26), PANTS)
	_limb(hip + Vector2(5, 0), -swing, Vector2(9, 26), PANTS)
	_limb(hip + Vector2(-5, 0) + Vector2(0, 26).rotated(swing), swing, Vector2(7, 14), SKIN)
	_limb(hip + Vector2(5, 0) + Vector2(0, 26).rotated(-swing), -swing, Vector2(7, 14), SKIN)
	# torso: shirt + open waistcoat
	var chest := hip + Vector2(0, -34)
	draw_rect(Rect2(chest + Vector2(-13, -1), Vector2(26, 37)), OUTLINE)
	draw_rect(Rect2(chest + Vector2(-12, 0), Vector2(24, 35)), SHIRT)
	draw_rect(Rect2(chest + Vector2(-12, 0), Vector2(8, 33)), VEST)
	draw_rect(Rect2(chest + Vector2(4, 0), Vector2(8, 33)), VEST)
	draw_rect(Rect2(chest + Vector2(-2, 22), Vector2(6, 4)), Color("c9bfa6"))  # a tear
	# arms
	var arm_a := -swing * 0.8
	var arm_b := swing * 0.8
	match pose:
		"work":
			arm_a = -1.2 + sin(_t * 8.0) * 0.5
			arm_b = -0.9 + cos(_t * 8.0) * 0.5
		"chop":
			arm_a = -2.4 + absf(sin(_t * 5.0)) * 2.0
			arm_b = arm_a + 0.2
		"fish":
			arm_a = -1.0
			arm_b = -0.9
	_limb(chest + Vector2(-12, 3), arm_a, Vector2(7, 30), SHIRT)
	_limb(chest + Vector2(12, 3), arm_b, Vector2(7, 30), SHIRT)
	if pose == "chop":
		var hand := chest + Vector2(12, 3) + Vector2(0, 30).rotated(arm_b)
		_limb(hand, arm_b + PI * 0.5, Vector2(4, 26), Color("6b4a2a"))
		draw_rect(Rect2(hand + Vector2(-6, -6).rotated(arm_b), Vector2(12, 9)), Color("8a8a86"))
	if pose == "fish":
		var hand := chest + Vector2(12, 3) + Vector2(0, 30).rotated(arm_b)
		draw_line(hand, hand + Vector2(70, -60), Color("6b4a2a"), 3.0)
		draw_line(hand + Vector2(70, -60), hand + Vector2(95, 40 + sin(_t * 2.0) * 4.0), Color(1, 1, 1, 0.7), 1.0)
	# head
	var head := chest + Vector2(1, -14)
	draw_circle(head, 13.0, OUTLINE)
	draw_circle(head, 12.0, SKIN)
	draw_rect(Rect2(head + Vector2(-12, -13), Vector2(24, 8)), HAIR)
	draw_rect(Rect2(head + Vector2(-12, -8), Vector2(5, 8)), HAIR)
	draw_rect(Rect2(head + Vector2(-6, 5), Vector2(15, 6)), Color(0.25, 0.17, 0.1, 0.55))  # stubble
	draw_rect(Rect2(head + Vector2(5, -3), Vector2(3, 3)), OUTLINE)  # eye (faces right)
	draw_rect(Rect2(head + Vector2(3, 3), Vector2(6, 2)), Color("8a4a3a"))  # unimpressed mouth

func _draw_lying() -> void:
	var breathe := sin(_t * 1.6) * 1.5
	draw_rect(Rect2(-34, -16 - breathe, 40, 15), OUTLINE)
	draw_rect(Rect2(-33, -15 - breathe, 38, 13), SHIRT)
	draw_rect(Rect2(-33, -15 - breathe, 38, 5), VEST)
	draw_rect(Rect2(5, -13, 30, 11), PANTS)
	draw_rect(Rect2(35, -12, 12, 9), SKIN)
	draw_circle(Vector2(-44, -12), 12.0, OUTLINE)
	draw_circle(Vector2(-44, -12), 11.0, SKIN)
	draw_rect(Rect2(-55, -24, 22, 7), HAIR)
