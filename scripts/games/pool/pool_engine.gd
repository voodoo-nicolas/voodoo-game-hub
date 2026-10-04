extends RefCounted

## Pool: 8-ball on a portrait table. Physics (rolling balls, elastic
## collisions, cushions, six pockets) plus the rules: break, open table,
## solids (1-7) vs stripes (9-15), fouls with ball in hand, and the 8 last.
## Also the computer player. World units: the playing surface is W x H,
## y grows downwards, the rack sits at the top and the cue ball breaks from
## the bottom.

const W := 500.0
const H := 1000.0
const R := 12.5               # ball radius
const KITCHEN_Y := H * 0.75   # behind this line for the break
const FOOT := Vector2(W / 2.0, H * 0.25)
const MAX_SPEED := 1900.0
const DRAG := 0.42            # exponential slowdown per second
const DECEL := 70.0           # plus a constant slowdown
const STOP := 5.0
const BALL_BOUNCE := 0.96
const RAIL_BOUNCE := 0.72
const CORNER_R := 25.0        # pocket capture radius
const SIDE_R := 22.0
const CORNER_MOUTH := 34.0    # no cushion this close to a corner
const SIDE_MOUTH := 26.0      # ...or this close to a side pocket's middle
const POCKETS := [Vector2(-3, -3), Vector2(W + 3, -3), Vector2(-9, H / 2.0), Vector2(W + 9, H / 2.0), Vector2(-3, H + 3), Vector2(W + 3, H + 3)]

var balls: Array = []         # index = number (0 = cue): {"n", "p", "v", "in": still on the table}
var turn: int = 0
var groups := [-1, -1]        # per player: -1 open, 0 solids, 1 stripes
var ball_in_hand := true
var break_shot := true
var winner: int = -1
var moving := false
var shots: int = 0
# What happened during the current shot, for the rules.
var first_hit: int = -1
var potted: Array = []
var rail_after_hit := false
var shot_targets: Array = []  # what the shooter had to hit, decided before the shot
var rng := RandomNumberGenerator.new()

func reset(seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	balls = []
	for n in 16:
		balls.append({"n": n, "p": Vector2.ZERO, "v": Vector2.ZERO, "in": true})
	# The rack: 8 in the middle, a solid and a stripe in the back corners.
	var order: Array = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var spots: Array = []
	for row in 5:
		for k in row + 1:
			spots.append(FOOT + Vector2((k - row / 2.0) * (2.0 * R + 0.4), -row * (2.0 * R + 0.2) * 0.866))
	var corner_solid := -1
	var corner_stripe := -1
	for n in order:
		if n < 8 and corner_solid < 0:
			corner_solid = n
		if n > 8 and corner_stripe < 0:
			corner_stripe = n
	order.erase(corner_solid)
	order.erase(corner_stripe)
	var rack: Array = []
	for i in 15:
		if i == 4:
			rack.append(8)
		elif i == 10:
			rack.append(corner_solid)
		elif i == 14:
			rack.append(corner_stripe)
		else:
			rack.append(order.pop_back())
	for i in 15:
		balls[rack[i]].p = spots[i]
	balls[0].p = Vector2(W / 2.0, H * 0.82)
	turn = 0
	groups = [-1, -1]
	ball_in_hand = true
	break_shot = true
	winner = -1
	moving = false
	shots = 0

static func group_of(n: int) -> int:
	if n == 0 or n == 8:
		return -1
	return 0 if n < 8 else 1

func remaining(group: int) -> int:
	var c := 0
	for b in balls:
		if b.in and group_of(b.n) == group:
			c += 1
	return c

## What the player whose turn it is should hit: their group, or the 8 once it's cleared.
func targets(player: int) -> Array:
	var g: int = groups[player]
	var out: Array = []
	if g >= 0 and remaining(g) == 0:
		return [8]
	for b in balls:
		if b.in and b.n != 0 and b.n != 8 and (g < 0 or group_of(b.n) == g):
			out.append(b.n)
	return out

func cue_ok(p: Vector2) -> bool:
	if p.x < R or p.x > W - R or p.y < R or p.y > H - R:
		return false
	if break_shot and p.y < KITCHEN_Y:
		return false
	for b in balls:
		if b.n != 0 and b.in and (b.p as Vector2).distance_to(p) < 2.0 * R + 0.5:
			return false
	return true

func place_cue(p: Vector2) -> bool:
	if not ball_in_hand or not cue_ok(p):
		return false
	balls[0].p = p
	balls[0].in = true
	return true

func shoot(dir: Vector2, power: float) -> void:
	if moving or winner >= 0 or dir.length() < 0.0001:
		return
	balls[0].v = dir.normalized() * clampf(power, 0.02, 1.0) * MAX_SPEED
	moving = true
	ball_in_hand = false
	first_hit = -1
	potted = []
	rail_after_hit = false
	shot_targets = targets(turn)
	shots += 1

# ---------- physics ----------

## Advances the balls. Returns sound events: "click" (ball-ball, with
## strength in the second slot), "rail", "pot".
func step(dt: float) -> Array:
	var ev: Array = []
	if not moving:
		return ev
	var fastest := 0.0
	for b in balls:
		if b.in:
			fastest = maxf(fastest, b.v.length())
	var n := maxi(1, int(ceilf(fastest * dt / (R * 0.35))))
	var h := dt / n
	for i in n:
		_sub(h, ev)
	moving = false
	for b in balls:
		if b.in and b.v.length() > 0.0:
			moving = true
	return ev

func _sub(h: float, ev: Array) -> void:
	for b in balls:
		if not b.in:
			continue
		var v: Vector2 = b.v
		var sp := v.length()
		if sp <= 0.0:
			continue
		v *= exp(-DRAG * h)
		sp = v.length()
		sp = maxf(0.0, sp - DECEL * h)
		v = v.normalized() * sp if sp > STOP else Vector2.ZERO
		b.v = v
		b.p += v * h
	# Ball against ball.
	for i in balls.size():
		var a: Dictionary = balls[i]
		if not a.in:
			continue
		for j in range(i + 1, balls.size()):
			var b: Dictionary = balls[j]
			if not b.in:
				continue
			var d: Vector2 = b.p - a.p
			var dist := d.length()
			if dist >= 2.0 * R or dist < 0.0001:
				continue
			var nn := d / dist
			var overlap := 2.0 * R - dist
			a.p -= nn * overlap / 2.0
			b.p += nn * overlap / 2.0
			var rel: float = (a.v - b.v).dot(nn)
			if rel > 0.0:
				var imp := rel * (1.0 + BALL_BOUNCE) / 2.0
				a.v -= nn * imp
				b.v += nn * imp
				if a.n == 0 and first_hit < 0:
					first_hit = b.n
				elif b.n == 0 and first_hit < 0:
					first_hit = a.n
				if not ev.has("click"):
					ev.append("click")
	# Cushions, except at the pocket mouths; pockets.
	for b in balls:
		if not b.in:
			continue
		var p: Vector2 = b.p
		var near_corner_y := p.y < CORNER_MOUTH or p.y > H - CORNER_MOUTH
		var near_corner_x := p.x < CORNER_MOUTH or p.x > W - CORNER_MOUTH
		var near_side := absf(p.y - H / 2.0) < SIDE_MOUTH
		if not near_corner_y and not near_side:
			if p.x < R and b.v.x < 0.0:
				b.p.x = R
				b.v.x = -b.v.x * RAIL_BOUNCE
				_rail(b, ev)
			elif p.x > W - R and b.v.x > 0.0:
				b.p.x = W - R
				b.v.x = -b.v.x * RAIL_BOUNCE
				_rail(b, ev)
		if not near_corner_x:
			if p.y < R and b.v.y < 0.0:
				b.p.y = R
				b.v.y = -b.v.y * RAIL_BOUNCE
				_rail(b, ev)
			elif p.y > H - R and b.v.y > 0.0:
				b.p.y = H - R
				b.v.y = -b.v.y * RAIL_BOUNCE
				_rail(b, ev)
		for k in POCKETS.size():
			var pr := CORNER_R if k != 2 and k != 3 else SIDE_R
			if (b.p as Vector2).distance_to(POCKETS[k]) < pr:
				_pot(b, ev)
				break
		# Anything that got past the cushion line in a mouth drops in.
		if b.in and (b.p.x < -R or b.p.x > W + R or b.p.y < -R or b.p.y > H + R):
			_pot(b, ev)

func _rail(b: Dictionary, ev: Array) -> void:
	if first_hit >= 0:
		rail_after_hit = true
	if not ev.has("rail") and b.v.length() > 60.0:
		ev.append("rail")

func _pot(b: Dictionary, ev: Array) -> void:
	b.in = false
	b.v = Vector2.ZERO
	potted.append(b.n)
	ev.append("pot")

# ---------- rules, once everything has stopped ----------

## Applies the rules to the shot just played. Returns {"foul": bool,
## "reason": String, "again": bool (same player shoots), "assigned": bool,
## "potted": Array, "winner": int}.
func resolve() -> Dictionary:
	var me := turn
	var res := {"foul": false, "reason": "", "again": false, "assigned": false, "potted": potted.duplicate(), "winner": -1}
	var was_break := break_shot
	break_shot = false
	var scratch := potted.has(0)
	var my_targets_before: Array = shot_targets
	var foul := false
	var reason := ""
	if scratch:
		foul = true
		reason = "Scratch!"
	elif first_hit < 0:
		foul = true
		reason = "No ball hit"
	elif not was_break and not my_targets_before.has(first_hit):
		foul = true
		reason = "Wrong ball hit first"
	if scratch:
		balls[0].in = true
		balls[0].p = Vector2(W / 2.0, H * 0.82)
		balls[0].v = Vector2.ZERO
	# The 8.
	if potted.has(8):
		if was_break and not scratch:
			# Potted on the break: back on its spot, play on.
			_respot_8()
			potted.erase(8)
		else:
			var cleared: bool = groups[me] >= 0 and my_targets_before == [8]
			winner = me if (cleared and not foul) else 1 - me
			res.winner = winner
			res.foul = foul
			res.reason = reason if foul else ""
			return res
	# Groups are decided by the first legal pot after the break.
	if groups[me] < 0 and not foul and not was_break:
		for n in potted:
			if group_of(n) >= 0:
				groups[me] = group_of(n)
				groups[1 - me] = 1 - groups[me]
				res.assigned = true
				break
	var pocketed_own := false
	for n in potted:
		if n == 0 or n == 8:
			continue
		if groups[me] < 0 or group_of(n) == groups[me]:
			pocketed_own = true
	res.foul = foul
	res.reason = reason
	if foul:
		turn = 1 - me
		ball_in_hand = true
	elif pocketed_own:
		res.again = true
	else:
		turn = 1 - me
	return res

func _respot_8() -> void:
	var b: Dictionary = balls[8]
	b.in = true
	b.v = Vector2.ZERO
	var p := FOOT
	while not _free(p, 8):
		p.y -= 2.0 * R
	b.p = p

func _free(p: Vector2, skip: int) -> bool:
	for b in balls:
		if b.n != skip and b.in and (b.p as Vector2).distance_to(p) < 2.0 * R:
			return false
	return true

# ---------- aiming helpers (guide line, computer) ----------

## Where the cue ball first touches another ball along dir: {"n", "ghost"}, or {} if none.
func first_contact(from: Vector2, dir: Vector2, skip: int = 0) -> Dictionary:
	var best := INF
	var out := {}
	dir = dir.normalized()
	for b in balls:
		if not b.in or b.n == skip:
			continue
		var to: Vector2 = b.p - from
		var along := to.dot(dir)
		if along <= 0.0:
			continue
		var off2 := to.length_squared() - along * along
		var rr := 4.0 * R * R
		if off2 > rr:
			continue
		var t := along - sqrt(rr - off2)
		if t < best:
			best = t
			out = {"n": b.n, "ghost": from + dir * t}
	return out

func _path_clear(a: Vector2, b: Vector2, skip: Array) -> bool:
	for ball in balls:
		if not ball.in or skip.has(ball.n):
			continue
		var q := Geometry2D.get_closest_point_to_segment(ball.p, a, b)
		if q.distance_to(ball.p) < 2.0 * R - 0.5:
			return false
	return true

func _pocket_aim(k: int) -> Vector2:
	# Aim a little inside the pocket, past the jaws.
	var p: Vector2 = POCKETS[k]
	return p + (Vector2(W / 2.0, H / 2.0) - p).normalized() * 6.0

## Straight-in candidates for the player whose turn it is.
func candidates(player: int) -> Array:
	var cue: Vector2 = balls[0].p
	var out: Array = []
	for n in targets(player):
		var t: Vector2 = balls[n].p
		for k in POCKETS.size():
			var pk := _pocket_aim(k)
			var to_pocket := (pk - t).normalized()
			var ghost := t - to_pocket * 2.0 * R
			var aim := ghost - cue
			if aim.length() < 1.0:
				continue
			var cut := absf(aim.normalized().angle_to(to_pocket))
			if cut > deg_to_rad(78.0):
				continue
			# Side pockets only take balls coming in fairly square.
			if (k == 2 or k == 3) and absf(to_pocket.x) < 0.45:
				continue
			if not _path_clear(cue, ghost, [0, n]) or not _path_clear(t, pk, [0, n]):
				continue
			var dist := aim.length() + t.distance_to(pk)
			var score: float = cut * 2.2 + dist / 600.0
			var power := clampf(0.18 + dist / 1500.0 + cut * 0.25, 0.15, 0.95)
			out.append({"n": n, "pocket": k, "dir": aim.normalized(), "power": power, "score": score})
	out.sort_custom(func(a, b): return a.score < b.score)
	return out

## A copy of this table to try shots on.
func clone() -> RefCounted:
	var c = get_script().new()
	c.balls = []
	for b in balls:
		c.balls.append({"n": b.n, "p": b.p, "v": b.v, "in": b.in})
	c.turn = turn
	c.groups = groups.duplicate()
	c.ball_in_hand = ball_in_hand
	c.break_shot = break_shot
	c.winner = winner
	return c

## Plays a shot on a copy until the balls have nearly stopped (pots happen
## early; the slow tail isn't worth simulating): the rules' verdict.
func try_shot(dir: Vector2, power: float) -> Array:
	var c = clone()
	c.shoot(dir, power)
	var guard := 0
	while c.moving and guard < 300:
		c.step(1.0 / 30.0)
		guard += 1
		var fast := false
		for b in c.balls:
			if b.in and (b.v as Vector2).length_squared() > 40.0 * 40.0:
				fast = true
				break
		if not fast:
			break
	c.moving = false
	return [c.resolve(), c]

## The computer's shot. level 0..2. Returns {"place": Vector2 or null, "dir", "power"}.
func cpu_shot(level: int) -> Dictionary:
	var me := turn
	var place = null
	if ball_in_hand:
		place = _cpu_place(me)
		if place != null:
			balls[0].p = place
	if break_shot:
		return {"place": place, "dir": (FOOT - balls[0].p).normalized().rotated(rng.randf_range(-0.02, 0.02)), "power": 1.0}
	var cands := candidates(me)
	var pick = null
	if level >= 2:
		# Hard: try the best few for real and keep one that pots without a foul.
		for cnd in cands.slice(0, 4):
			var r: Array = try_shot(cnd.dir, cnd.power)
			var res: Dictionary = r[0]
			if res.winner == me or (res.again and not res.foul):
				pick = cnd
				break
	if pick == null and not cands.is_empty():
		pick = cands[0] if level > 0 or rng.randf() < 0.6 else cands[rng.randi_range(0, mini(2, cands.size() - 1))]
	var dir: Vector2
	var power: float
	if pick != null:
		dir = pick.dir
		power = pick.power
	else:
		# Nothing on: roll gently into the nearest legal ball.
		var best := INF
		dir = Vector2.UP
		for n in targets(me):
			var d: float = (balls[n].p as Vector2).distance_to(balls[0].p)
			if d < best:
				best = d
				dir = ((balls[n].p as Vector2) - balls[0].p).normalized()
		power = 0.35
	var noise: float = [0.045, 0.016, 0.004][clampi(level, 0, 2)]
	dir = dir.rotated(rng.randf_range(-noise, noise))
	power = clampf(power * rng.randf_range(0.9, 1.1), 0.1, 1.0)
	return {"place": place, "dir": dir, "power": power}

## Ball in hand: put the cue ball straight behind the easiest ball.
func _cpu_place(me: int):
	var best = null
	var best_score := INF
	for n in targets(me):
		var t: Vector2 = balls[n].p
		for k in POCKETS.size():
			var pk := _pocket_aim(k)
			var to_pocket := (pk - t).normalized()
			if (k == 2 or k == 3) and absf(to_pocket.x) < 0.45:
				continue
			if not _path_clear(t, pk, [0, n]):
				continue
			for back in [110.0, 170.0, 240.0]:
				var p: Vector2 = t - to_pocket * (2.0 * R + back)
				if not cue_ok(p) or not _path_clear(p, t - to_pocket * 2.0 * R, [0, n]):
					continue
				var score: float = t.distance_to(pk) + back * 0.5
				if score < best_score:
					best_score = score
					best = p
	if best == null:
		for tries in 200:
			var p: Vector2 = Vector2(rng.randf_range(R, W - R), rng.randf_range(KITCHEN_Y if break_shot else R, H - R))
			if cue_ok(p):
				return p
	return best

# ---------- save / load ----------

func to_dict() -> Dictionary:
	var bl: Array = []
	for b in balls:
		bl.append([b.p.x, b.p.y, b.in])
	return {"balls": bl, "turn": turn, "groups": groups, "hand": ball_in_hand, "break": break_shot, "shots": shots}

func from_dict(d: Dictionary) -> void:
	reset()
	for i in mini(16, d.balls.size()):
		balls[i].p = Vector2(float(d.balls[i][0]), float(d.balls[i][1]))
		balls[i].in = bool(d.balls[i][2])
	turn = int(d.turn)
	groups = [int(d.groups[0]), int(d.groups[1])]
	ball_in_hand = bool(d.hand)
	break_shot = bool(d["break"])
	shots = int(d.get("shots", 0))
	balls[0].in = true
