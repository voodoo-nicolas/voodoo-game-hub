extends RefCounted

## Mini Golf: 18 holes of crazy golf. A hole is a fenced green (one outer
## outline plus blocks inside) with any of: sand (slows the ball), water
## (back to where you shot from, +1 stroke), slopes (push the ball),
## bumpers (bounce it hard), windmills (spinning blades) and sliding
## gates. Pure physics in world units (W x H, y down), stepped by the game.

const W := 600.0
const H := 1000.0
const BALL_R := 9.0
const CUP_R := 14.0
const MAX_SPEED := 1150.0     # a full-power putt
const SINK_SPEED := 470.0     # faster than this and the ball lips out
const STOP_SPEED := 7.0
const ROLL_DRAG := 0.55       # exponential slowdown per second
const ROLL_DECEL := 55.0      # plus a constant slowdown
const SAND_DECEL := 900.0
const BOUNCE := 0.78
const BUMPER_BOUNCE := 1.25
const MAX_STROKES := 8        # then the ball is picked up
const SUB_MOVE := 3.0         # largest move per physics sub-step

## Every hole, front nine then back nine. Rectangles are [x0, y0, x1, y1].
const HOLES := [
	# 1 -- a warm-up
	{"par": 2, "tee": [300, 880], "cup": [300, 200], "outline": [[160, 110], [440, 110], [440, 950], [160, 950]]},
	# 2 -- a block in the way
	{"par": 2, "tee": [300, 880], "cup": [300, 180], "outline": [[110, 100], [490, 100], [490, 950], [110, 950]],
		"blocks": [[240, 470, 360, 530]]},
	# 3 -- round the corner
	{"par": 3, "tee": [200, 880], "cup": [440, 200], "outline": [[100, 950], [300, 950], [300, 330], [520, 330], [520, 100], [100, 100]]},
	# 4 -- bumpers
	{"par": 2, "tee": [300, 880], "cup": [300, 170], "outline": [[120, 100], [480, 100], [480, 950], [120, 950]],
		"bumpers": [[210, 520, 28], [390, 520, 28], [300, 400, 28], [300, 640, 28]]},
	# 5 -- zig-zag with a bunker
	{"par": 3, "tee": [300, 880], "cup": [420, 190], "outline": [[100, 100], [500, 100], [500, 950], [100, 950]],
		"blocks": [[100, 650, 380, 690], [220, 400, 500, 440]], "sand": [[110, 150, 270, 300]]},
	# 6 -- the windmill
	{"par": 3, "tee": [300, 880], "cup": [300, 180], "outline": [[150, 100], [450, 100], [450, 950], [150, 950]],
		"blocks": [[150, 470, 235, 530], [365, 470, 450, 530]], "mills": [[300, 500, 105, 1.5, 4]]},
	# 7 -- over the bridge
	{"par": 3, "tee": [300, 880], "cup": [200, 200], "outline": [[100, 100], [500, 100], [500, 950], [100, 950]],
		"water": [[100, 420, 390, 560]]},
	# 8 -- crosswind slope
	{"par": 2, "tee": [300, 880], "cup": [240, 180], "outline": [[130, 100], [470, 100], [470, 950], [130, 950]],
		"slopes": [[130, 330, 470, 670, 170, 0]]},
	# 9 -- switchbacks
	{"par": 4, "tee": [150, 900], "cup": [440, 130], "outline": [[80, 80], [520, 80], [520, 960], [80, 960]],
		"blocks": [[80, 760, 420, 800], [180, 560, 520, 600], [80, 360, 420, 400], [180, 180, 520, 220]]},
	# 10 -- the diamond
	{"par": 2, "tee": [300, 880], "cup": [300, 170], "outline": [[300, 90], [500, 330], [500, 670], [300, 950], [100, 670], [100, 330]],
		"bumpers": [[300, 520, 40]]},
	# 11 -- the sliding gate
	{"par": 3, "tee": [300, 880], "cup": [300, 180], "outline": [[150, 100], [450, 100], [450, 950], [150, 950]],
		"blocks": [[150, 480, 255, 520], [345, 480, 450, 520]], "sliders": [[155, 400, 255, 440, 190, 0, 3.0]]},
	# 12 -- the U-turn
	{"par": 3, "tee": [180, 880], "cup": [420, 860], "outline": [[100, 950], [260, 950], [260, 320], [340, 320], [340, 950], [500, 950], [500, 100], [100, 100]]},
	# 13 -- uphill
	{"par": 2, "tee": [300, 880], "cup": [300, 190], "outline": [[150, 100], [450, 100], [450, 950], [150, 950]],
		"slopes": [[150, 300, 450, 700, 0, 150]], "sand": [[150, 100, 220, 170], [380, 100, 450, 170]]},
	# 14 -- two windmills
	{"par": 3, "tee": [300, 890], "cup": [300, 160], "outline": [[100, 100], [500, 100], [500, 950], [100, 950]],
		"mills": [[210, 380, 95, 1.3, 3], [390, 650, 95, -1.6, 3]]},
	# 15 -- the island green
	{"par": 3, "tee": [300, 880], "cup": [300, 290], "outline": [[100, 100], [500, 100], [500, 950], [100, 950]],
		"water": [[100, 150, 500, 210], [100, 210, 210, 380], [390, 210, 500, 380], [100, 380, 275, 600], [325, 380, 500, 600]]},
	# 16 -- pinball
	{"par": 3, "tee": [300, 890], "cup": [300, 150], "outline": [[120, 100], [480, 100], [480, 950], [120, 950]],
		"bumpers": [[180, 300, 22], [300, 300, 22], [420, 300, 22], [240, 430, 22], [360, 430, 22], [180, 560, 22], [300, 560, 22], [420, 560, 22], [240, 690, 22], [360, 690, 22]],
		"sand": [[120, 760, 220, 860], [380, 760, 480, 860]]},
	# 17 -- the long way round
	{"par": 4, "tee": [450, 900], "cup": [150, 130], "outline": [[80, 80], [520, 80], [520, 960], [80, 960]],
		"blocks": [[180, 760, 520, 800], [80, 560, 420, 600], [180, 360, 520, 400], [80, 180, 420, 220]],
		"slopes": [[80, 600, 520, 760, -90, 0]], "sand": [[430, 230, 520, 350]]},
	# 18 -- the finale
	{"par": 4, "tee": [300, 900], "cup": [300, 150], "outline": [[120, 100], [480, 100], [480, 960], [120, 960]],
		"blocks": [[120, 640, 240, 680], [360, 640, 480, 680]], "mills": [[300, 660, 100, 1.8, 4]],
		"sliders": [[125, 380, 225, 410, 250, 0, 2.6]], "water": [[120, 230, 230, 330], [370, 230, 480, 330]], "bumpers": [[300, 470, 30]]},
]
const COURSES := [[0, 9], [9, 18], [0, 18]]   # Front 9, Back 9, all 18

var hole: Dictionary = {}
var index: int = 0
var t: float = 0.0            # time, for windmills and gates
var ball := Vector2.ZERO
var vel := Vector2.ZERO
var moving := false
var holed := false
var last_shot := Vector2.ZERO
var strokes: int = 0
var segs: Array = []          # static wall segments: [a, b]

func load_hole(i: int) -> void:
	index = i
	hole = HOLES[i]
	segs = []
	var outline := _pts(hole.outline)
	for k in outline.size():
		segs.append([outline[k], outline[(k + 1) % outline.size()]])
	for r in hole.get("blocks", []):
		var p := rect_points(r)
		for k in 4:
			segs.append([p[k], p[(k + 1) % 4]])
	ball = Vector2(hole.tee[0], hole.tee[1])
	last_shot = ball
	vel = Vector2.ZERO
	moving = false
	holed = false
	strokes = 0

static func rect_points(r: Array) -> PackedVector2Array:
	return PackedVector2Array([Vector2(r[0], r[1]), Vector2(r[2], r[1]), Vector2(r[2], r[3]), Vector2(r[0], r[3])])

static func _pts(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in a:
		out.append(Vector2(p[0], p[1]))
	return out

func outline() -> PackedVector2Array:
	return _pts(hole.outline)

func cup() -> Vector2:
	return Vector2(hole.cup[0], hole.cup[1])

func par() -> int:
	return hole.par

## Puts the ball down somewhere (a resumed game).
func place(p: Vector2) -> void:
	ball = p
	last_shot = p
	vel = Vector2.ZERO
	moving = false

## dir: any length; power 0..1.
func shoot(dir: Vector2, power: float) -> void:
	if moving or holed or dir.length() < 0.001:
		return
	last_shot = ball
	vel = dir.normalized() * clampf(power, 0.0, 1.0) * MAX_SPEED
	moving = true
	strokes += 1

## The moving parts' wall segments at time tt: windmill blades and gates,
## as [a, b, spin centre or null, spin speed, gate velocity].
func moving_segs(tt: float) -> Array:
	var out: Array = []
	for m in hole.get("mills", []):
		var c := Vector2(m[0], m[1])
		for k in int(m[4]):
			var a: float = tt * m[3] + TAU * k / m[4]
			out.append([c, c + Vector2(cos(a), sin(a)) * m[2], c, m[3], Vector2.ZERO])
	for s in hole.get("sliders", []):
		var p := slider_rect(s, tt)
		var pts := rect_points([p.position.x, p.position.y, p.end.x, p.end.y])
		var gv: Vector2 = Vector2(s[4], s[5]) * (PI / s[6]) * sin(TAU * tt / s[6])
		for k in 4:
			out.append([pts[k], pts[(k + 1) % 4], null, 0.0, gv])
	return out

## Moving parts knock a resting ball (and a rolling one) along.
func _hit_moving(ev: Array) -> bool:
	var any := false
	for sg in moving_segs(t):
		var push: Vector2 = sg[4]
		if sg[2] != null:
			var q := Geometry2D.get_closest_point_to_segment(ball, sg[0], sg[1])
			var rr: Vector2 = q - sg[2]
			push = Vector2(-rr.y, rr.x) * float(sg[3])
		if _collide(sg[0], sg[1], BOUNCE, push, 4.0):
			_sound(ev, "mill")
			any = true
	return any

static func slider_rect(s: Array, tt: float) -> Rect2:
	var k := 0.5 - 0.5 * cos(TAU * tt / s[6])
	var off := Vector2(s[4], s[5]) * k
	return Rect2(Vector2(s[0], s[1]) + off, Vector2(s[2] - s[0], s[3] - s[1]))

static func in_rect(p: Vector2, r: Array) -> bool:
	return p.x >= r[0] and p.x <= r[2] and p.y >= r[1] and p.y <= r[3]

## Advances time (and the ball, if rolling). Returns events: "wall",
## "bumper", "mill", "water", "holed", "stopped", "lip".
func step(dt: float) -> Array:
	var ev: Array = []
	if not moving:
		t += dt
		if not holed and _hit_moving(ev):
			moving = vel.length() > STOP_SPEED
		return ev
	var n := maxi(1, int(ceilf(vel.length() * dt / SUB_MOVE)))
	var h := dt / n
	for i in n:
		t += h
		_sub_step(h, ev)
		if not moving:
			t += dt - h * (i + 1)
			break
	return ev

func _sub_step(h: float, ev: Array) -> void:
	# Slopes push, sand and grass slow.
	for s in hole.get("slopes", []):
		if in_rect(ball, s):
			vel += Vector2(s[4], s[5]) * h
	var decel := ROLL_DECEL
	for s in hole.get("sand", []):
		if in_rect(ball, s):
			decel = SAND_DECEL
	vel *= exp(-ROLL_DRAG * h)
	var sp := vel.length()
	if sp > 0.0:
		vel = vel / sp * maxf(0.0, sp - decel * h)
	ball += vel * h
	# Walls (static and moving).
	for sg in segs:
		if _collide(sg[0], sg[1], BOUNCE, Vector2.ZERO):
			_sound(ev, "wall")
	_hit_moving(ev)
	for b in hole.get("bumpers", []):
		var c := Vector2(b[0], b[1])
		var d := ball - c
		var rr: float = b[2] + BALL_R
		if d.length() < rr and d.length() > 0.001:
			var nn := d.normalized()
			ball = c + nn * rr
			if vel.dot(nn) < 0.0:
				vel -= (1.0 + BUMPER_BOUNCE) * vel.dot(nn) * nn
				vel = vel.limit_length(MAX_SPEED)
				_sound(ev, "bumper")
	# Water: back to where the shot was played from, one stroke added.
	for w in hole.get("water", []):
		if in_rect(ball, w):
			ball = last_shot
			vel = Vector2.ZERO
			moving = false
			strokes += 1
			ev.append("water")
			return
	# The cup.
	var to_cup := cup() - ball
	if to_cup.length() < CUP_R:
		if vel.length() < SINK_SPEED:
			ball = cup()
			vel = Vector2.ZERO
			moving = false
			holed = true
			ev.append("holed")
			return
		# Too fast: the lip bends its path a little.
		vel = vel.rotated(signf(vel.cross(to_cup)) * 0.02)
		_sound(ev, "lip")
	if vel.length() < STOP_SPEED:
		vel = Vector2.ZERO
		moving = false
		ev.append("stopped")

func _sound(ev: Array, e: String) -> void:
	if not ev.has(e):
		ev.append(e)

## Circle vs segment: push the ball out and bounce it. `push` is the
## surface's own velocity at the contact (windmill blades).
func _collide(a: Vector2, b: Vector2, bounce: float, push: Vector2, thick: float = 0.0) -> bool:
	var q := Geometry2D.get_closest_point_to_segment(ball, a, b)
	var d := ball - q
	var r := BALL_R + thick
	var l := d.length()
	if l >= r:
		return false
	var nn := d / l if l > 0.0001 else (b - a).orthogonal().normalized()
	ball = q + nn * r
	var rel := vel - push
	if rel.dot(nn) < 0.0:
		rel -= (1.0 + bounce) * rel.dot(nn) * nn
		vel = (rel + push).limit_length(MAX_SPEED)
		return true
	return false

## Name of a score against par, for the end of a hole.
static func score_name(strokes_: int, par_: int) -> String:
	if strokes_ == 1:
		return "Hole in one!"
	match strokes_ - par_:
		-3:
			return "Albatross!"
		-2:
			return "Eagle!"
		-1:
			return "Birdie!"
		0:
			return "Par"
		1:
			return "Bogey"
		2:
			return "Double bogey"
	return "+%d" % (strokes_ - par_)
