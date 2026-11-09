extends RefCounted

## Bug Chain logic (pure, no Nodes; headless-testable).
##
## A level has one or two tracks: smooth paths from an entrance off the edge
## of the field to a pit. Bugs crawl along each track in a chain, pushed from
## behind. The player's bug launcher slides along a rail under the field and
## fires straight up. A shot that touches a chain bug is pushed into the
## chain next to it; three or more of one colour touching pop. If the bugs on
## both sides of a hole share a colour, the front part crawls back to close
## it and may pop again (a chain reaction, worth more each step). A chain
## that reaches its pit costs a life.
##
## Units: the field is FIELD wide/tall, the rail at RAIL_Y; the game scales
## it to the screen. Position along a track = arc length `s` (0 = entrance).

const FIELD := Vector2(100.0, 124.0)
const RAIL_Y := 136.0
const FIELD_H := 146.0
const R := 3.4  # bug radius
const D := 6.8  # spacing of bugs along a track
const STEP := 0.5  # sample spacing of a track's points
const SHOT_SPEED := 200.0
const RETRACT := 75.0  # how fast a front part crawls back to close a gap
const RUSH_SPEED := 46.0  # a chain rushes in at the start of a level...
const RUSH_UNTIL := 0.28  # ...until its head is this far along
const PIT_SPEED := 150.0  # a lost chain slides into the pit
const SLOW_TIME := 7.0
const SLOW_FACTOR := 0.3
const REVERSE_TIME := 3.0
const BOMB_RADIUS := 15.0
const DANGER := 0.82  # head this far along = danger
const EPS := 0.06

## Power bugs: carry a mark; popping one fires it.
enum { P_NONE, P_BOMB, P_SLOW, P_REVERSE, P_RAINBOW }
const RAINBOW := -1  # a shot that takes the colour of the bug it hits

## Track shapes, in campaign order (5 levels each).
const SHAPES := ["meadow", "spiral", "zigzag", "hook", "wave", "twin"]
const CAMPAIGN_LEVELS := 30
const DIFF_SPEED := [0.78, 1.0, 1.22]
const DIFF_COLORS := [-1, 0, 0]

var tracks: Array = []  # [{pts, len, balls, spawned, quota, rushing}]
var shots: Array = []  # [{p: Vector2, c: int}]
var checks: Array = []  # [{id, lvl, t, shot}] pending match checks
var spec: Dictionary = {}
var rng: RandomNumberGenerator
var score: int = 0
var popped: int = 0  # bugs popped this level
var best_chain: int = 0  # deepest chain reaction this level
var slow_t: float = 0.0
var reverse_t: float = 0.0
var losing := false
var done := false  # level over (cleared or lost)
var _next_id: int = 1

# ---------- levels ----------

## What level `n` (1-based; past CAMPAIGN_LEVELS = endless waves) looks like.
static func level_spec(n: int, diff: int) -> Dictionary:
	n = maxi(1, n)
	diff = clampi(diff, 0, 2)
	var shape: String
	if n <= CAMPAIGN_LEVELS:
		shape = SHAPES[((n - 1) / 5) % SHAPES.size()]
	else:
		shape = SHAPES[(n * 7 + 3) % SHAPES.size()]
	var sub: int = (n - 1) % 5
	var colors: int = 4 + (1 if n >= 8 else 0) + (1 if n >= 21 else 0) + DIFF_COLORS[diff]
	var powers: Array = []
	if n >= 2:
		powers.append(P_BOMB)
	if n >= 4:
		powers.append(P_SLOW)
	if n >= 7:
		powers.append(P_REVERSE)
	if n >= 11:
		powers.append(P_RAINBOW)
	return {
		"n": n, "diff": diff, "shape": shape,
		"colors": clampi(colors, 3, 6),
		"speed": (5.2 + 0.11 * minf(n, 70)) * DIFF_SPEED[diff],
		"quota": mini(44 + 5 * sub + n, 115),
		"powers": powers,
		"power_chance": 0.05,
	}

## Control points of each track for a shape (field units).
static func shape_points(shape: String) -> Array:
	match shape:
		"spiral":
			var pts: Array = [Vector2(50, -12), Vector2(50, 2)]
			var c := Vector2(50, 60)
			var turns := 1.7
			var steps := int(turns * 12)
			for i in steps + 1:
				var f := float(i) / steps
				var a := -PI / 2.0 + f * turns * TAU
				var r: float = lerpf(44.0, 11.0, f)
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			return [pts]
		"zigzag":
			return [[Vector2(-12, 10), Vector2(10, 12), Vector2(70, 22), Vector2(88, 32),
				Vector2(70, 44), Vector2(28, 52), Vector2(12, 64), Vector2(30, 76),
				Vector2(72, 84), Vector2(88, 96), Vector2(72, 108), Vector2(46, 110)]]
		"hook":
			return [[Vector2(16, -12), Vector2(14, 10), Vector2(10, 50), Vector2(14, 92),
				Vector2(32, 110), Vector2(68, 110), Vector2(86, 92), Vector2(90, 50),
				Vector2(84, 22), Vector2(66, 14), Vector2(50, 26), Vector2(54, 50),
				Vector2(52, 70)]]
		"wave":
			return [_serpentine([18.0, 54.0, 90.0], true, 64.0, 6.0)]
		"twin":
			return [_serpentine([12.0, 38.0], true, 34.0, 3.0),
				_serpentine([66.0, 94.0], false, 66.0, 3.0)]
		_:  # "meadow"
			return [_serpentine([12.0, 38.0, 64.0, 90.0], true, 52.0, 0.0)]

## Rows joined by U-turns, entering from one side; `amp` adds a wave.
static func _serpentine(ys: Array, from_left: bool, end_x: float, amp: float) -> Array:
	var left := 18.0
	var right := 82.0
	var pts: Array = []
	var x: float = -12.0 if from_left else 112.0
	var go_right := from_left
	for r in ys.size():
		var y: float = ys[r]
		var last: bool = r == ys.size() - 1
		var xb: float = (right if go_right else left)
		if last:
			xb = end_x
		var sg := 1.0 if go_right else -1.0
		while (xb - x) * sg > 6.0:
			pts.append(Vector2(x, y + amp * sin(x * 0.21 + r)))
			x += sg * 13.0
		pts.append(Vector2(xb, y + (amp * sin(xb * 0.21 + r) if not last else 0.0)))
		if not last:
			var dy: float = ys[r + 1] - y
			var bulge: float = minf(dy * 0.45, 12.0)
			pts.append(Vector2(xb + sg * bulge * 0.8, y + dy * 0.18))
			pts.append(Vector2(xb + sg * bulge, y + dy * 0.5))
			pts.append(Vector2(xb + sg * bulge * 0.8, y + dy * 0.82))
			x = xb
		go_right = not go_right
	return pts

## Smooths control points (Catmull-Rom) and resamples every STEP.
static func build_track(ctrl: Array) -> Dictionary:
	var dense: Array = []
	var m := ctrl.size()
	for i in m - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, m - 1)]
		var n := maxi(4, int(p1.distance_to(p2) / 0.8))
		for j in n:
			var t := float(j) / n
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	dense.append(ctrl[m - 1])
	var pts := PackedVector2Array()
	pts.append(dense[0])
	var carry := 0.0
	for i in range(1, dense.size()):
		var a: Vector2 = dense[i - 1]
		var b: Vector2 = dense[i]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		var at := STEP - carry
		while at <= seg:
			pts.append(a.lerp(b, at / seg))
			at += STEP
		carry = seg - (at - STEP)
	return {"pts": pts, "len": (pts.size() - 1) * STEP, "balls": [], "spawned": 0, "quota": 0, "rushing": true}

static func pos_at(t: Dictionary, s: float) -> Vector2:
	var pts: PackedVector2Array = t.pts
	if s <= 0.0:
		return pts[0] + (pts[1] - pts[0]).normalized() * s
	var f := s / STEP
	var i := int(f)
	if i >= pts.size() - 1:
		return pts[pts.size() - 1]
	return pts[i].lerp(pts[i + 1], f - i)

static func tangent_at(t: Dictionary, s: float) -> Vector2:
	var pts: PackedVector2Array = t.pts
	var i := clampi(int(s / STEP), 0, pts.size() - 2)
	return (pts[i + 1] - pts[i]).normalized()

# ---------- setup ----------

func setup(level: Dictionary, random: RandomNumberGenerator) -> void:
	spec = level
	rng = random
	tracks.clear()
	shots.clear()
	checks.clear()
	popped = 0
	best_chain = 0
	slow_t = 0.0
	reverse_t = 0.0
	losing = false
	done = false
	var shapes: Array = shape_points(spec.shape)
	for ctrl in shapes:
		var t := build_track(ctrl)
		t.quota = int(ceil(float(spec.quota) / (1.0 if shapes.size() == 1 else 1.6)))
		tracks.append(t)

func _new_ball(s: float) -> Dictionary:
	var b := {"id": _next_id, "s": s, "vs": s, "c": rng.randi_range(0, int(spec.colors) - 1), "p": P_NONE, "lvl": 0, "fly": 0.0}
	_next_id += 1
	if spec.powers.size() > 0 and rng.randf() < float(spec.power_chance):
		b.p = spec.powers[rng.randi_range(0, spec.powers.size() - 1)]
	return b

# ---------- queries ----------

func colors_present() -> Array:
	var out: Array = []
	for t in tracks:
		for b in t.balls:
			if b.s >= -D and not out.has(b.c):
				out.append(b.c)
	out.sort()
	return out

## How far the furthest chain head has crawled (0 = entrance, 1 = pit).
func head_frac() -> float:
	var f := 0.0
	for t in tracks:
		if not t.balls.is_empty():
			f = maxf(f, t.balls[t.balls.size() - 1].s / t.len)
	return f

func ball_count() -> int:
	var n := 0
	for t in tracks:
		n += t.balls.size()
	return n

## Bugs still to pop this level (on the tracks + still to come).
func remaining() -> int:
	var n := 0
	for t in tracks:
		n += t.balls.size() + maxi(0, t.quota - t.spawned)
	return n

func quota_total() -> int:
	var n := 0
	for t in tracks:
		n += t.quota
	return n

func in_danger() -> bool:
	return not losing and head_frac() > DANGER

# ---------- play ----------

func fire(x: float, color: int) -> void:
	shots.append({"p": Vector2(clampf(x, R, FIELD.x - R), RAIL_Y - 7.0), "c": color})

## Advances everything by dt. Returns events for sounds and effects:
## ["pop", pos, count, color, lvl], ["power", kind, pos], ["stick", pos],
## ["miss"] (a shot bug stuck without popping), ["pit"] (a chain reached
## its pit), ["lost"], ["cleared"].
func update(dt: float) -> Array:
	var ev: Array = []
	if done:
		return ev
	if losing:
		var any := false
		for t in tracks:
			for b in t.balls:
				b.s += PIT_SPEED * dt
				b.vs = b.s
			var ln: float = t.len
			t.balls = t.balls.filter(func(b): return b.s < ln)
			any = any or not t.balls.is_empty()
		if not any:
			done = true
			ev.append(["lost"])
		return ev
	slow_t = maxf(0.0, slow_t - dt)
	reverse_t = maxf(0.0, reverse_t - dt)
	for t in tracks:
		_move_track(t, dt)
	_move_shots(dt, ev)
	_run_checks(dt, ev)
	for t in tracks:
		for b in t.balls:
			b.vs = lerpf(b.vs, b.s, minf(1.0, dt * 16.0))
			if absf(b.vs - b.s) < 0.02:
				b.vs = b.s
			b.fly = maxf(0.0, b.fly - dt)
	for t in tracks:
		if not t.balls.is_empty() and t.balls[t.balls.size() - 1].s >= t.len:
			losing = true
			shots.clear()
			checks.clear()
			ev.append(["pit"])
			return ev
	if shots.is_empty() and checks.is_empty():
		var empty := true
		for t in tracks:
			if not t.balls.is_empty() or t.spawned < t.quota:
				empty = false
		if empty:
			done = true
			ev.append(["cleared"])
	return ev

func _speed(t: Dictionary) -> float:
	var head: float = t.balls[t.balls.size() - 1].s / t.len if not t.balls.is_empty() else 0.0
	if t.rushing:
		if head < RUSH_UNTIL and t.spawned < t.quota:
			return RUSH_SPEED
		t.rushing = false
	var v: float = float(spec.speed) * (1.0 - 0.4 * head)
	if reverse_t > 0.0:
		return -v * 2.2
	if slow_t > 0.0:
		v *= SLOW_FACTOR
	return v

func _move_track(t: Dictionary, dt: float) -> void:
	var b: Array = t.balls
	# New bugs come in at the entrance behind the last one.
	while t.spawned < t.quota and (b.is_empty() or b[0].s >= 0.0) and reverse_t <= 0.0:
		var s0: float = -D * 0.5 if b.is_empty() else minf(b[0].s - D, 0.0)
		b.insert(0, _new_ball(s0))
		t.spawned += 1
	if b.is_empty():
		return
	var v := _speed(t)
	var end := _group_end(b, 0)
	var mv := v * dt
	if mv < 0.0:
		mv = maxf(mv, -D - b[0].s)  # never back past the entrance
	for i in end + 1:
		b[i].s += mv
	_push(b)
	# A hole whose two edges share a colour closes: the front part crawls back.
	var i := 0
	while i < b.size() - 1:
		var gap: float = b[i + 1].s - b[i].s
		if gap > D + EPS and b[i].c == b[i + 1].c:
			var j_end := _group_end(b, i + 1)
			var back := minf(RETRACT * dt, gap - D)
			for k in range(i + 1, j_end + 1):
				b[k].s -= back
			if gap - back <= D + EPS:
				checks.append({"id": b[i + 1].id, "lvl": int(b[i + 1].lvl) + 1, "t": 0.04, "shot": false})
			i = j_end
		i += 1

## Last index of the group that starts at i (bugs touching each other).
func _group_end(b: Array, i: int) -> int:
	while i < b.size() - 1 and b[i + 1].s - b[i].s <= D + EPS:
		i += 1
	return i

## Bugs never overlap: anything behind pushes what is in front.
func _push(b: Array) -> void:
	for i in range(1, b.size()):
		if b[i].s < b[i - 1].s + D:
			b[i].s = b[i - 1].s + D

func _move_shots(dt: float, ev: Array) -> void:
	var keep: Array = []
	for sh in shots:
		var hit := false
		var dist := SHOT_SPEED * dt
		var steps := maxi(1, int(ceil(dist / 1.5)))
		for st in steps:
			sh.p.y -= dist / steps
			var h := _hit_test(sh.p)
			if not h.is_empty():
				_insert(h[0], h[1], sh, ev)
				hit = true
				break
		if not hit and sh.p.y > -R * 2.0:
			keep.append(sh)
	shots = keep

## [track, index] of the bug a shot at p touches, or [].
func _hit_test(p: Vector2) -> Array:
	var best: Array = []
	var best_d := D * 0.92
	for t in tracks:
		var b: Array = t.balls
		for i in b.size():
			if b[i].s < 0.0:
				continue
			var d := p.distance_to(pos_at(t, b[i].vs))
			if d < best_d:
				best_d = d
				best = [t, i]
	return best

func _insert(t: Dictionary, j: int, sh: Dictionary, ev: Array) -> void:
	var b: Array = t.balls
	var hit_b: Dictionary = b[j]
	var c: int = sh.c if sh.c != RAINBOW else hit_b.c
	var ahead: bool = (sh.p - pos_at(t, hit_b.s)).dot(tangent_at(t, hit_b.s)) >= 0.0
	var nb := {"id": _next_id, "s": hit_b.s + (D if ahead else 0.0), "vs": 0.0, "c": c, "p": P_NONE,
		"lvl": 0, "fly": 0.12, "from": sh.p}
	_next_id += 1
	nb.vs = nb.s
	b.insert(j + 1 if ahead else j, nb)
	_push(b)
	checks.append({"id": nb.id, "lvl": 0, "t": 0.1, "shot": true})
	ev.append(["stick", sh.p])

func _run_checks(dt: float, ev: Array) -> void:
	var due: Array = []
	var keep: Array = []
	for c in checks:
		c.t -= dt
		if c.t <= 0.0:
			due.append(c)
		else:
			keep.append(c)
	checks = keep
	for c in due:
		var found := _find(c.id)
		if found.is_empty():
			continue
		if not _check_at(found[0], found[1], int(c.lvl), ev):
			found[0].balls[found[1]].lvl = 0
			if c.shot:
				ev.append(["miss"])

func _find(id: int) -> Array:
	for t in tracks:
		var b: Array = t.balls
		for i in b.size():
			if b[i].id == id:
				return [t, i]
	return []

## Pops the run of one colour through index k if it is 3 or more long.
func _check_at(t: Dictionary, k: int, lvl: int, ev: Array) -> bool:
	var b: Array = t.balls
	var c: int = b[k].c
	var lo := k
	while lo > 0 and b[lo - 1].c == c and b[lo].s - b[lo - 1].s <= D + EPS:
		lo -= 1
	var hi := k
	while hi < b.size() - 1 and b[hi + 1].c == c and b[hi + 1].s - b[hi].s <= D + EPS:
		hi += 1
	if hi - lo + 1 < 3:
		return false
	_pop_range(t, lo, hi, lvl, ev)
	return true

func _pop_range(t: Dictionary, lo: int, hi: int, lvl: int, ev: Array) -> void:
	var b: Array = t.balls
	var count := hi - lo + 1
	var mid: Vector2 = pos_at(t, (b[lo].vs + b[hi].vs) / 2.0)
	var c: int = b[lo].c
	var powers: Array = []
	for i in range(lo, hi + 1):
		if b[i].p != P_NONE:
			powers.append([b[i].p, pos_at(t, b[i].vs)])
	for i in count:
		b.remove_at(lo)
	popped += count
	best_chain = maxi(best_chain, lvl)
	score += count * 10 * (lvl + 1) + (50 * lvl if lvl > 0 else 0)
	# The front part remembers how deep this reaction is, for when it closes the hole.
	if lo < b.size():
		b[lo].lvl = lvl
	ev.append(["pop", mid, count, c, lvl])
	for p in powers:
		_fire_power(p[0], p[1], ev)

func _fire_power(kind: int, at: Vector2, ev: Array) -> void:
	ev.append(["power", kind, at])
	match kind:
		P_BOMB:
			blast(at, BOMB_RADIUS, ev)
		P_SLOW:
			slow_t = SLOW_TIME
		P_REVERSE:
			reverse_t = REVERSE_TIME
		# P_RAINBOW: the game hands the launcher a rainbow bug.

## Removes every bug within `radius` of `at` (any track).
func blast(at: Vector2, radius: float, ev: Array) -> int:
	var n := 0
	for t in tracks:
		var b: Array = t.balls
		var i := 0
		while i < b.size():
			if b[i].s >= 0.0 and pos_at(t, b[i].vs).distance_to(at) <= radius:
				b.remove_at(i)
				n += 1
			else:
				i += 1
	popped += n
	score += n * 10
	if n > 0:
		ev.append(["pop", at, n, -1, 0])
	return n

## Help: removes the `n` front bugs of every chain (nearest the pit).
func clear_front(n: int) -> int:
	var out := 0
	for t in tracks:
		var k := mini(n, t.balls.size())
		for i in k:
			t.balls.pop_back()
		out += k
	popped += out
	return out

# ---------- save ----------

func to_dict() -> Dictionary:
	var ts: Array = []
	for t in tracks:
		var bs: Array = []
		for b in t.balls:
			bs.append([snappedf(b.s, 0.01), b.c, b.p])
		ts.append({"balls": bs, "spawned": t.spawned, "quota": t.quota, "rushing": t.rushing})
	return {"spec": spec, "tracks": ts, "score": score, "popped": popped,
		"best_chain": best_chain, "slow": slow_t, "reverse": reverse_t}

func from_dict(d: Dictionary, random: RandomNumberGenerator) -> bool:
	var sp = d.get("spec")
	if not sp is Dictionary or not SHAPES.has(str(sp.get("shape", ""))):
		return false
	# The level's own numbers, with the saved shape (endless waves pick theirs at random).
	var s2: Dictionary = level_spec(int(sp.get("n", 1)), int(sp.get("diff", 1)))
	for key in ["shape", "colors", "speed", "quota", "power_chance"]:
		if sp.has(key):
			s2[key] = sp[key] if key == "shape" else (int(sp[key]) if key in ["colors", "quota"] else float(sp[key]))
	var pw: Array = []
	for x in sp.get("powers", []):
		pw.append(int(x))
	s2.powers = pw
	setup(s2, random)
	var ts: Array = d.get("tracks", [])
	if ts.size() != tracks.size():
		return false
	for i in ts.size():
		var t: Dictionary = tracks[i]
		t.spawned = int(ts[i].get("spawned", 0))
		t.quota = int(ts[i].get("quota", t.quota))
		t.rushing = bool(ts[i].get("rushing", false))
		for bb in ts[i].get("balls", []):
			var nb := {"id": _next_id, "s": float(bb[0]), "vs": float(bb[0]), "c": int(bb[1]), "p": int(bb[2]), "lvl": 0, "fly": 0.0}
			_next_id += 1
			t.balls.append(nb)
	score = int(d.get("score", 0))
	popped = int(d.get("popped", 0))
	best_chain = int(d.get("best_chain", 0))
	slow_t = float(d.get("slow", 0.0))
	reverse_t = float(d.get("reverse", 0.0))
	return true
