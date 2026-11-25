extends RefCounted

## Brick Breaker: keep the ball in play with your paddle and smash every
## brick. The number on a brick is how many hits it still needs. Grey steel
## bricks never break: they guard the others, so find the way in. Some
## bricks are cut diagonally and send the ball off at an angle. Three lives;
## each cleared wall brings a new, tougher one. Pure simulation in a field
## 1000 high; `field.x` is 600 on phones and wider on wide screens (set it
## before reset()).
##
## Two modes (set `reloaded` before reset()):
## - Classic: no power-ups, no TNT.
## - Reloaded: broken bricks drop power-ups (catch them with the paddle),
##   TNT bricks blow up their neighbours, and chains of bricks broken
##   without touching the paddle multiply the points (combo).
## The game draws; this file only simulates. Things worth a visual effect
## are pushed onto `events` during step() (cleared at the start of the next).

const FIELD := Vector2(600, 1000)   # the phone field (field.x grows on wide screens)
const MAX_FIELD_X := 2160.0
const PADDLE := Vector2(110, 18)
const PADDLE_Y := 920.0
const BALL_R := 10.0
const CELL_W := 60.0                # one brick column per 60 px of width
const BRICK_H := 26.0
const ROW_GAP := 4.0
const TOP := 70.0
const MAX_ROWS := 17
const MAX_HP := 9

# ---- Reloaded ----
const MAX_BALLS := 24
const DROP_CHANCE := 0.2
const POWER_SIZE := Vector2(64, 30)   # falling capsule
const POWER_FALL := 230.0             # px/s
const BOOM_R := 80.0                  # explosion radius
const TNT_CHANCE := 0.06
const LASER_EVERY := 0.3
const LASER_SPEED := 900.0
const SHIELD_Y := 975.0               # the barrier under the paddle
const MAX_SHIELD := 3

## Power-ups: seconds they last (0 = instant), how often they drop (weight)
## and whether they help ("good") or hurt.
const POWERS := {
	"wide": {"time": 15.0, "w": 10, "good": true},
	"multi": {"time": 0.0, "w": 9, "good": true},
	"pierce": {"time": 8.0, "w": 7, "good": true},
	"boom": {"time": 10.0, "w": 7, "good": true},
	"laser": {"time": 8.0, "w": 6, "good": true},
	"slow": {"time": 10.0, "w": 6, "good": true},
	"shield": {"time": 0.0, "w": 5, "good": true},
	"life": {"time": 0.0, "w": 2, "good": true},
	"shrink": {"time": 10.0, "w": 4, "good": false},
	"fast": {"time": 8.0, "w": 3, "good": false},
}

var reloaded := false
var field := FIELD
## [{rect: Rect2, poly: PackedVector2Array, hp, max_hp, row, tnt, steel, cut}]
## cut: -1 = full brick, 0..3 = which corner is sliced off (TL, TR, BR, BL).
var bricks: Array = []
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

static func is_good(kind: String) -> bool:
	return POWERS.get(kind, {}).get("good", true)

func reset() -> void:
	field.x = clampf(field.x, FIELD.x, MAX_FIELD_X)
	field.y = FIELD.y
	paddle_x = field.x / 2.0
	lives = 3
	score = 0
	level = 1
	shield = 0
	timers.clear()
	rng.randomize()
	_build_level()

func cols() -> int:
	return maxi(10, int(field.x / CELL_W))

## Bricks that still have to be broken (steel never counts).
func breakable_left() -> int:
	var n := 0
	for br in bricks:
		if not br.steel:
			n += 1
	return n

# ---------- levels ----------

## Five wall shapes take turns; from level 2 the edges of a wall are cut
## diagonally, and steel guards the wall: a vault every 5th level, a
## rampart with gaps under the wall from level 3.
func _build_level() -> void:
	bricks.clear()
	powerups.clear()
	lasers.clear()
	var nc := cols()
	var rows: int = mini(6 + level, MAX_ROWS)
	var shape := (level - 1) % 5
	var grid := {}   # Vector2i -> "b" (brick) / "s" (steel)
	var mid := (nc - 1) / 2.0
	for r in rows:
		for c in nc:
			var keep := true
			match shape:
				0: keep = not (r == 0 and (c == 0 or c == nc - 1)) and not (r < 2 and absf(c - mid) < 1.0)
				1: keep = (r + c) % 2 == 0 or r < 2
				2: keep = absf(c - mid) + r * 0.6 < mid + 2.0
				3: keep = c % 3 != 2 or r < 2
			if keep:
				grid[Vector2i(c, r)] = "b"
	if shape == 4:
		_add_vault(grid, nc, rows)
	elif level >= 3:
		# rampart: a steel row under the wall with a couple of gaps
		var gaps := [int(nc * 0.25), int(nc * 0.75)]
		if level % 2 == 0:
			gaps = [0, nc - 1, nc / 2]
		for c in nc:
			if not gaps.has(c):
				grid[Vector2i(c, rows)] = "s"
	for cell in grid:
		var steel: bool = grid[cell] == "s"
		var r: int = cell.y
		var cut := -1
		if level >= 2 and not steel:
			cut = _edge_cut(grid, cell, nc)
		var hp := 1
		if not steel:
			# higher bricks are tougher, and every level adds a little
			var top_share := 1.0 - float(r) / rows
			hp = clampi(1 + int(top_share * (level - 1) * 0.45 + rng.randf() * (0.5 + level * 0.1)), 1, MAX_HP)
		var tnt := reloaded and not steel and hp == 1 and cut < 0 and rng.randf() < TNT_CHANCE
		_add_brick(cell, hp, steel, cut, tnt)
	_reset_ball()

## A box of steel in the middle with the way in at the bottom; the bricks
## inside are the tough ones.
func _add_vault(grid: Dictionary, nc: int, rows: int) -> void:
	var w: int = clampi(nc / 2 + 1, 5, nc - 2)
	var x0: int = (nc - w) / 2
	var y0 := 2
	var y1: int = rows - 1
	for y in range(y0, y1 + 1):
		for x in range(x0, x0 + w):
			var edge := x == x0 or x == x0 + w - 1 or y == y0 or y == y1
			grid[Vector2i(x, y)] = "s" if edge else "b"
	# the door: two cells in the floor
	var door: int = x0 + w / 2 - 1
	grid.erase(Vector2i(door, y1))
	grid.erase(Vector2i(door + 1, y1))

## Which corner to slice off a brick at the edge of the wall (-1 = none):
## a corner whose two sides both face open space.
func _edge_cut(grid: Dictionary, cell: Vector2i, nc: int) -> int:
	var l := _open(grid, cell + Vector2i.LEFT, nc)
	var rt := _open(grid, cell + Vector2i.RIGHT, nc)
	var up := _open(grid, cell + Vector2i.UP, nc)
	var dn := _open(grid, cell + Vector2i.DOWN, nc)
	var opts: Array = []
	if l and up: opts.append(0)
	if rt and up: opts.append(1)
	if rt and dn: opts.append(2)
	if l and dn: opts.append(3)
	if opts.is_empty() or rng.randf() > 0.75:
		return -1
	return opts[rng.randi() % opts.size()]

func _open(grid: Dictionary, c: Vector2i, nc: int) -> bool:
	if c.x < 0 or c.x >= nc:
		return false   # the side walls are not open space (above the wall is)
	return not grid.has(c)

func _add_brick(cell: Vector2i, hp: int, steel: bool, cut: int, tnt: bool) -> void:
	var bw := field.x / cols()
	var rect := Rect2(cell.x * bw + 2, TOP + cell.y * (BRICK_H + ROW_GAP), bw - 4, BRICK_H)
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var poly := PackedVector2Array()
	for i in 4:
		if i != cut:
			poly.append(corners[i])
	bricks.append({"rect": rect, "poly": poly, "hp": hp, "max_hp": hp, "row": cell.y, "tnt": tnt, "steel": steel, "cut": cut})

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
	# a little wider on wide fields: there is more ground to cover
	var base := PADDLE.x * (1.0 + (field.x / FIELD.x - 1.0) * 0.35)
	if timers.has("wide"):
		return base * 1.7
	if timers.has("shrink"):
		return base * 0.6
	return base

func has_power(kind: String) -> bool:
	return timers.has(kind)

func launch() -> void:
	if stuck:
		stuck = false
		balls[0].v = Vector2(randf_range(-0.4, 0.4), -1).normalized() * speed()

func set_paddle(x: float) -> void:
	var half := paddle_w() / 2.0
	paddle_x = clamp(x, half, field.x - half)
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
		if breakable_left() == 0:
			level += 1
			_build_level()
			events.append({"type": "cleared", "pos": field / 2.0})
			return "cleared"
		for b in balls.duplicate():
			if b.p.y > field.y + BALL_R:
				balls.erase(b)
		if balls.is_empty():
			lives -= 1
			timers.clear()
			powerups.clear()
			lasers.clear()
			events.append({"type": "lost", "pos": Vector2(paddle_x, field.y)})
			if lives <= 0:
				return "game_over"
			_reset_ball()
			return "lost_life"
	return ""

## Where the ball at `p` touches a brick: {n: push-out normal, c: contact
## point}, or an empty Dictionary when it doesn't.
func _contact(p: Vector2, br: Dictionary) -> Dictionary:
	var r: Rect2 = br.rect
	if p.x < r.position.x - BALL_R or p.x > r.end.x + BALL_R or p.y < r.position.y - BALL_R or p.y > r.end.y + BALL_R:
		return {}
	var poly: PackedVector2Array = br.poly
	var best := INF
	var best_c := Vector2.ZERO
	var best_i := 0
	for i in poly.size():
		var c := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		var d := p.distance_squared_to(c)
		if d < best:
			best = d
			best_c = c
			best_i = i
	var inside := Geometry2D.is_point_in_polygon(p, poly)
	if not inside and best > BALL_R * BALL_R:
		return {}
	var n: Vector2
	if inside or best < 0.0001:
		# centre inside the brick: push out through the nearest side
		var a := poly[best_i]
		var e := poly[(best_i + 1) % poly.size()] - a
		n = Vector2(e.y, -e.x).normalized()
		if n.dot((a + e * 0.5) - r.get_center()) < 0:
			n = -n
	else:
		n = (p - best_c).normalized()
	return {"n": n, "c": best_c}

func _move_ball(b: Dictionary, dt: float) -> void:
	b.p += b.v * dt
	if b.p.x < BALL_R:
		b.p.x = BALL_R
		b.v.x = abs(b.v.x)
	elif b.p.x > field.x - BALL_R:
		b.p.x = field.x - BALL_R
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
	# bricks: a normal ball bounces off the first one it touches (along the
	# side it hit, so diagonal sides send it off at an angle); a piercing
	# ball smashes straight through everything except steel.
	var pierce := has_power("pierce")
	var hits: Array = []
	for br in bricks:
		var ct := _contact(b.p, br)
		if ct.is_empty():
			continue
		if pierce and not br.steel:
			hits.append(br)
			continue
		var n: Vector2 = ct.n
		if b.v.dot(n) < 0:
			b.v = b.v.bounce(n)
		b.p = ct.c + n * (BALL_R + 0.05)
		_keep_climbing(b)
		if br.steel:
			events.append({"type": "steel", "pos": ct.c})
		else:
			hits.append(br)
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

## Never let a ball skim sideways forever (diagonals and steel can send it
## nearly flat): keep at least a quarter of its speed vertical.
func _keep_climbing(b: Dictionary) -> void:
	var v: Vector2 = b.v
	var l := v.length()
	if l > 0.0 and absf(v.y) < l * 0.25:
		v.y = l * 0.25 * (signf(v.y) if v.y != 0.0 else -1.0)
		b.v = v.normalized() * l

## Hit a brick for `dmg`; break it when its hp runs out. Steel shrugs it off.
func _damage(br: Dictionary, dmg: int) -> void:
	if br.get("dead", false) or br.steel:
		return
	var c: Vector2 = (br.rect as Rect2).get_center()
	br.hp -= dmg
	if br.hp > 0:
		score += 2
		events.append({"type": "chip", "pos": c, "row": br.row, "brick": br})
		return
	br["dead"] = true
	bricks.erase(br)
	combo += 1
	var pts := 10 * level
	if reloaded:
		pts = int(pts * (1.0 + 0.25 * min(combo - 1, 12)))
	score += pts
	events.append({"type": "break", "pos": c, "row": br.row, "combo": combo, "pts": pts, "tnt": br.tnt, "brick": br})
	if not reloaded:
		return
	if br.tnt:
		_explode(c, BOOM_R * 1.4)
	if rng.randf() < DROP_CHANCE:
		powerups.append({"kind": _pick_power(), "pos": c})

## Damage every brick within `radius` of `at` (TNT bricks chain; steel holds).
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
		elif p.pos.y > field.y + POWER_SIZE.y:
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
			if hit.steel:
				events.append({"type": "steel", "pos": Vector2(l.x, hit.rect.end.y)})
			else:
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
