extends RefCounted

## Brick Breaker: keep the ball in play with your paddle and smash every
## brick. Darker bricks take two hits. Three lives; each cleared wall brings
## a new, tougher one. Pure simulation in a fixed 600×1000 field.
##
## Two modes (set `reloaded` before reset()):
## - Classic: exactly the game as it always was.
## - Reloaded: broken bricks drop power-ups (catch them with the paddle),
##   TNT bricks blow up their neighbours, and chains of bricks broken
##   without touching the paddle multiply the points (combo).
## The game draws; this file only simulates. Things worth a visual effect
## are pushed onto `events` during step() (cleared at the start of the next).

const FIELD := Vector2(600, 1000)
const PADDLE := Vector2(110, 18)
const PADDLE_Y := 920.0
const BALL_R := 10.0
const COLS := 10
const BRICK_H := 28.0
const TOP := 110.0

# ---- Reloaded ----
const MAX_BALLS := 24
const DROP_CHANCE := 0.2
const POWER_SIZE := Vector2(56, 28)   # falling capsule
const POWER_FALL := 230.0             # px/s
const BOOM_R := 80.0                  # explosion radius
const TNT_CHANCE := 0.06
const LASER_EVERY := 0.3
const LASER_SPEED := 900.0
const SHIELD_Y := 975.0               # the barrier under the paddle
const MAX_SHIELD := 3

## Power-ups: seconds they last (0 = instant) and how often they drop (weight).
## "shrink" and "fast" are the bad ones: dodge them.
const POWERS := {
	"wide": {"time": 15.0, "w": 10},
	"multi": {"time": 0.0, "w": 9},
	"pierce": {"time": 8.0, "w": 7},
	"boom": {"time": 10.0, "w": 7},
	"laser": {"time": 8.0, "w": 6},
	"slow": {"time": 10.0, "w": 6},
	"shield": {"time": 0.0, "w": 5},
	"life": {"time": 0.0, "w": 2},
	"shrink": {"time": 10.0, "w": 4},
	"fast": {"time": 8.0, "w": 3},
}

var reloaded := false
var bricks: Array = []     # [{rect: Rect2, hp: int, row: int, tnt: bool}]
var balls: Array = []      # [{p: Vector2, v: Vector2}]; balls[0] rests on the paddle
var powerups: Array = []   # falling: [{kind: String, pos: Vector2}]
var lasers: Array = []     # [Vector2] shots flying up
var timers := {}           # power id -> seconds left
var shield: int = 0        # balls the barrier will still save
var events: Array = []     # [{type, pos, ...}] for the game's effects
var combo: int = 0         # bricks broken since the paddle last touched a ball
var paddle_x: float = 300.0
var stuck: bool = true      # ball resting on the paddle, waiting for launch
var lives: int = 3
var score: int = 0
var level: int = 1
var laser_cd: float = 0.0
var rng := RandomNumberGenerator.new()

## The first ball (the only one in Classic).
var ball: Vector2:
	get:
		return balls[0].p if not balls.is_empty() else Vector2.ZERO
	set(value):
		if not balls.is_empty():
			balls[0].p = value
var vel: Vector2:
	get:
		return balls[0].v if not balls.is_empty() else Vector2.ZERO
	set(value):
		if not balls.is_empty():
			balls[0].v = value

func reset() -> void:
	lives = 3
	score = 0
	level = 1
	shield = 0
	timers.clear()
	rng.randomize()
	_build_level()

func _build_level() -> void:
	bricks.clear()
	powerups.clear()
	lasers.clear()
	var rows: int = min(4 + level, 10)
	var bw := FIELD.x / COLS
	var pattern := level % 4
	for r in rows:
		for c in COLS:
			var keep := true
			match pattern:
				2: keep = (r + c) % 2 == 0 or r < 2
				3: keep = abs(c - 4.5) + r * 0.6 < 6.5
				0: keep = c != 0 and c != COLS - 1 or r % 2 == 0
			if not keep:
				continue
			var hp := 2 if (level >= 2 and r < level - 1 and r < 3) else 1
			var tnt := reloaded and hp == 1 and rng.randf() < TNT_CHANCE
			bricks.append({"rect": Rect2(c * bw + 2, TOP + r * (BRICK_H + 4), bw - 4, BRICK_H), "hp": hp, "row": r, "tnt": tnt})
	_reset_ball()

func _reset_ball() -> void:
	stuck = true
	combo = 0
	balls = [{"p": Vector2(paddle_x, PADDLE_Y - BALL_R - 1), "v": Vector2.ZERO}]

func speed() -> float:
	return 480.0 + 45.0 * (level - 1)

## Slow / fast power-ups scale how far the balls travel, not their stored speed.
func speed_mul() -> float:
	if timers.has("slow"):
		return 0.65
	if timers.has("fast"):
		return 1.3
	return 1.0

func paddle_w() -> float:
	if timers.has("wide"):
		return PADDLE.x * 1.7
	if timers.has("shrink"):
		return PADDLE.x * 0.6
	return PADDLE.x

func has_power(kind: String) -> bool:
	return timers.has(kind)

func launch() -> void:
	if stuck:
		stuck = false
		balls[0].v = Vector2(randf_range(-0.4, 0.4), -1).normalized() * speed()

func set_paddle(x: float) -> void:
	var half := paddle_w() / 2.0
	paddle_x = clamp(x, half, FIELD.x - half)
	if stuck and not balls.is_empty():
		balls[0].p.x = paddle_x

## Returns "", "lost_life", "game_over" or "cleared".
func step(delta: float) -> String:
	events.clear()
	if reloaded:
		_tick_powers(delta)
	if stuck:
		return ""
	var mul := speed_mul()
	var fastest := 0.0
	for b in balls:
		fastest = max(fastest, b.v.length() * mul)
	var steps: int = max(1, int(ceil(fastest * delta / 6.0)))
	var dt: float = delta / steps
	for i in steps:
		for b in balls.duplicate():
			_move_ball(b, dt * mul)
		if bricks.is_empty():
			level += 1
			_build_level()
			events.append({"type": "cleared", "pos": FIELD / 2.0})
			return "cleared"
		for b in balls.duplicate():
			if b.p.y > FIELD.y + BALL_R:
				balls.erase(b)
		if balls.is_empty():
			lives -= 1
			timers.clear()
			powerups.clear()
			lasers.clear()
			events.append({"type": "lost", "pos": Vector2(paddle_x, FIELD.y)})
			if lives <= 0:
				return "game_over"
			_reset_ball()
			return "lost_life"
	return ""

func _move_ball(b: Dictionary, dt: float) -> void:
	b.p += b.v * dt
	if b.p.x < BALL_R:
		b.p.x = BALL_R
		b.v.x = abs(b.v.x)
	elif b.p.x > FIELD.x - BALL_R:
		b.p.x = FIELD.x - BALL_R
		b.v.x = -abs(b.v.x)
	if b.p.y < BALL_R:
		b.p.y = BALL_R
		b.v.y = abs(b.v.y)
	# paddle
	var half := paddle_w() / 2.0
	if b.v.y > 0 and b.p.y + BALL_R >= PADDLE_Y and b.p.y < PADDLE_Y + PADDLE.y and abs(b.p.x - paddle_x) <= half + BALL_R:
		var offset: float = clamp((b.p.x - paddle_x) / half, -1.0, 1.0)
		b.v = Vector2(sin(offset * 1.05), -cos(offset * 1.05)) * b.v.length()
		b.p.y = PADDLE_Y - BALL_R
		combo = 0
		events.append({"type": "paddle", "pos": b.p})
	# the shield under the paddle saves a ball once
	if shield > 0 and b.v.y > 0 and b.p.y + BALL_R >= SHIELD_Y:
		b.p.y = SHIELD_Y - BALL_R
		b.v.y = -abs(b.v.y)
		shield -= 1
		events.append({"type": "shield", "pos": b.p})
	# bricks: a normal ball bounces off the first one it touches;
	# a piercing ball smashes straight through everything it touches.
	var pierce := has_power("pierce")
	var hits: Array = []
	for br in bricks:
		var r: Rect2 = br.rect
		var closest := Vector2(clamp(b.p.x, r.position.x, r.end.x), clamp(b.p.y, r.position.y, r.end.y))
		if closest.distance_to(b.p) <= BALL_R:
			hits.append(br)
			if not pierce:
				var d: Vector2 = b.p - closest
				if abs(d.x) > abs(d.y):
					b.v.x = abs(b.v.x) * sign(d.x) if d.x != 0 else -b.v.x
				else:
					b.v.y = abs(b.v.y) * sign(d.y) if d.y != 0 else -b.v.y
				break
	if hits.is_empty():
		return
	var boom := has_power("boom")
	for br in hits:
		_damage(br, 99 if pierce else 1)
		if boom:
			_explode((br.rect as Rect2).get_center(), BOOM_R)
	if not pierce:
		b.v = b.v.normalized() * min(b.v.length() * 1.004, speed() * 1.6)

## Hit a brick for `dmg`; break it when its hp runs out.
func _damage(br: Dictionary, dmg: int) -> void:
	if br.get("dead", false):
		return
	var c: Vector2 = (br.rect as Rect2).get_center()
	br.hp -= dmg
	if br.hp > 0:
		score += 2
		events.append({"type": "chip", "pos": c, "row": br.row})
		return
	br["dead"] = true
	bricks.erase(br)
	combo += 1
	var pts := 10 * level
	if reloaded:
		pts = int(pts * (1.0 + 0.25 * min(combo - 1, 12)))
	score += pts
	events.append({"type": "break", "pos": c, "row": br.row, "combo": combo, "pts": pts, "tnt": br.tnt})
	if not reloaded:
		return
	if br.tnt:
		_explode(c, BOOM_R * 1.4)
	if rng.randf() < DROP_CHANCE:
		powerups.append({"kind": _pick_power(), "pos": c})

## Damage every brick within `radius` of `at` (TNT bricks chain).
func _explode(at: Vector2, radius: float) -> void:
	events.append({"type": "boom", "pos": at, "r": radius})
	for br in bricks.duplicate():
		var r: Rect2 = br.rect
		var closest := Vector2(clamp(at.x, r.position.x, r.end.x), clamp(at.y, r.position.y, r.end.y))
		if closest.distance_to(at) <= radius:
			_damage(br, 1)

func _pick_power() -> String:
	var total := 0
	for k in POWERS:
		total += POWERS[k].w
	var n := rng.randi_range(1, total)
	for k in POWERS:
		n -= POWERS[k].w
		if n <= 0:
			return k
	return "wide"

func _tick_powers(delta: float) -> void:
	for k in timers.keys():
		timers[k] -= delta
		if timers[k] <= 0.0:
			timers.erase(k)
			events.append({"type": "power_end", "kind": k, "pos": Vector2(paddle_x, PADDLE_Y)})
	# falling capsules
	var half := paddle_w() / 2.0
	for p in powerups.duplicate():
		p.pos.y += POWER_FALL * delta
		if abs(p.pos.x - paddle_x) <= half + POWER_SIZE.x / 2.0 and abs(p.pos.y - (PADDLE_Y + PADDLE.y / 2.0)) <= (POWER_SIZE.y + PADDLE.y) / 2.0:
			powerups.erase(p)
			apply_power(p.kind)
		elif p.pos.y > FIELD.y + POWER_SIZE.y:
			powerups.erase(p)
	# lasers: two shots from the paddle's ends
	if timers.has("laser") and not stuck:
		laser_cd -= delta
		if laser_cd <= 0.0:
			laser_cd = LASER_EVERY
			lasers.append(Vector2(paddle_x - half + 8, PADDLE_Y))
			lasers.append(Vector2(paddle_x + half - 8, PADDLE_Y))
			events.append({"type": "laser", "pos": Vector2(paddle_x, PADDLE_Y)})
	var travel := LASER_SPEED * delta
	for i in range(lasers.size() - 1, -1, -1):
		var l: Vector2 = lasers[i]
		var path := Rect2(l.x - 2, l.y - travel, 4, travel)
		var hit = null
		for br in bricks:
			if (br.rect as Rect2).intersects(path) and (hit == null or br.rect.end.y > hit.rect.end.y):
				hit = br
		if hit != null:
			lasers.remove_at(i)
			_damage(hit, 1)
		elif l.y - travel < 0:
			lasers.remove_at(i)
		else:
			lasers[i] = Vector2(l.x, l.y - travel)

func apply_power(kind: String) -> void:
	events.append({"type": "power", "kind": kind, "pos": Vector2(paddle_x, PADDLE_Y)})
	match kind:
		"multi":
			if stuck:
				launch()
			var add: Array = []
			for b in balls:
				for a in [-0.4, 0.4]:
					if balls.size() + add.size() < MAX_BALLS:
						add.append({"p": b.p, "v": (b.v as Vector2).rotated(a)})
			balls.append_array(add)
		"shield":
			shield = min(shield + 1, MAX_SHIELD)
		"life":
			lives += 1
		_:
			# opposites cancel each other
			var opposite := {"wide": "shrink", "shrink": "wide", "slow": "fast", "fast": "slow"}
			if opposite.has(kind):
				timers.erase(opposite[kind])
			timers[kind] = POWERS[kind].time
	set_paddle(paddle_x)
