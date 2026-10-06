extends RefCounted

## The campaign bosses: big multi-part enemies with their own rules, kept as
## plain Dictionaries like the rest of the game (see geometry_wars_core.gd).
## Distances are in grid squares times Core.U, like everything else.
##
##   queen    Hive Queen     a core inside a turning ring of armour plates.
##                           Shoot plates away to reach the core; she hatches
##                           grunts, then spinners and rings of shots.
##   serpent  Serpent King   a long snake. Only the glowing tail end can be
##                           hurt; once the body is gone the head can.
##   lord     Gravity Lord   a giant gravity well: pulls you, bends your
##                           shots, fires rings of shots and spawns protons.
##   titan    Titan          an octagon with four gun turrets. Destroy the
##                           turrets, then the core -- which starts charging.
##
## A "hard" boss (Ultimate, the end of Boss Rush) has more health and
## fires more. update() returns events for the game to act on:
##   {kind: "spawn", type, pos}   a minion to add
##   {kind: "shots", list}        enemy bullets [{pos, vel, life, r}]
##   {kind: "phase", pos}         the boss got angry (half health)
##   {kind: "part", pos, color}   an armour plate / segment / turret broke

const Core = preload("res://scripts/games/geometry_wars/geometry_wars_core.gd")

const NAMES := {"queen": "Hive Queen", "serpent": "Serpent King", "lord": "Gravity Lord", "titan": "Titan"}
const COLORS := {
	"queen": Color(1.0, 0.35, 0.85), "serpent": Color(0.35, 1.0, 0.55),
	"lord": Color(1.0, 0.5, 0.15), "titan": Color(0.35, 0.8, 1.0),
}
const POINTS := {"queen": 25000, "serpent": 30000, "lord": 40000, "titan": 50000}

const QUEEN_PLATES := 10
const QUEEN_RING := 2.7
const QUEEN_CORE := 1.5
const SERPENT_SEGS := 22
const SERPENT_GAP := 0.85
const SERPENT_SEG_R := 0.55
const LORD_R := 1.8
const LORD_PULL_RANGE := 16.0
const TITAN_R := 2.2
const TITAN_TURRET_OFF := 2.7
const TITAN_TURRET_R := 0.75
const SHOT_SPEED := 7.0

static func make(kind: String, pos: Vector2, hard: bool = false) -> Dictionary:
	var k := 1.5 if hard else 1.0
	var b := {"boss": true, "kind": kind, "pos": pos, "vel": Vector2.ZERO, "t": 0.0, "hard": hard,
		"phase": 1, "warm": 2.0, "flash": 0.0, "timers": {}}
	match kind:
		"queen":
			b.hp = int(320 * k)
			var plates: Array = []
			for i in QUEEN_PLATES:
				plates.append(int(12 * k))
			b.plates = plates
			b.rot = 0.0
		"serpent":
			b.hp = int(150 * k)
			var segs: Array = []
			var seg_hp: Array = []
			for i in SERPENT_SEGS:
				segs.append(pos - Vector2(SERPENT_GAP * Core.U * (i + 1), 0))
				seg_hp.append(int(10 * k))
			b.segs = segs
			b.seg_hp = seg_hp
			b.dir = Vector2.LEFT
		"lord":
			b.hp = int(1000 * k)
			b.spin = 0.0
		"titan":
			b.hp = int(420 * k)
			var turrets: Array = []
			for i in 4:
				turrets.append(int(70 * k))
			b.turrets = turrets
			b.rot = 0.0
			b.state = "drift"
			b.st = 0.0
			b.dir = Vector2.RIGHT
	b.max_hp = total_hp(b)
	return b

static func name_of(b: Dictionary) -> String:
	return NAMES.get(b.kind, "Boss")

static func color_of(b: Dictionary) -> Color:
	return COLORS.get(b.kind, Color.WHITE)

## Everything that still has to be shot away, for the health bar.
static func total_hp(b: Dictionary) -> int:
	var n := int(b.hp)
	match b.kind:
		"queen":
			for p in b.plates:
				n += int(p)
		"serpent":
			for h in b.seg_hp:
				n += int(h)
		"titan":
			for h in b.turrets:
				n += int(h)
	return n

static func is_dead(b: Dictionary) -> bool:
	return int(b.hp) <= 0

static func _timer(b: Dictionary, key: String, every: float, delta: float) -> bool:
	var t: float = float(b.timers.get(key, every * 0.6)) - delta
	if t <= 0.0:
		b.timers[key] = every
		return true
	b.timers[key] = t
	return false

## Where the queen's plate i is, and the titan's turret i.
static func plate_pos(b: Dictionary, i: int) -> Vector2:
	var a: float = float(b.rot) + TAU * i / QUEEN_PLATES
	return b.pos + Vector2(cos(a), sin(a)) * QUEEN_RING * Core.U

static func turret_pos(b: Dictionary, i: int) -> Vector2:
	var a: float = float(b.rot) + TAU * i / 4.0 + PI / 4.0
	return b.pos + Vector2(cos(a), sin(a)) * TITAN_TURRET_OFF * Core.U

## The serpent's segment that can be hurt (its tail end), or -1 once the body is gone.
static func serpent_tail(b: Dictionary) -> int:
	return b.segs.size() - 1

# ---------- movement + attacks ----------

static func update(b: Dictionary, player_pos: Vector2, arena: Vector2, delta: float) -> Array:
	var u: float = Core.U
	var ev: Array = []
	b.t = float(b.t) + delta
	b.flash = maxf(0.0, float(b.flash) - delta)
	if float(b.warm) > 0.0:
		b.warm = float(b.warm) - delta
		return ev
	var to_p: Vector2 = player_pos - b.pos
	var chase: Vector2 = to_p.normalized() if to_p.length() > 1.0 else Vector2.ZERO
	var angry: bool = int(b.phase) >= 2
	var hard: bool = b.hard
	if int(b.phase) == 1 and total_hp(b) <= int(b.max_hp) / 2:
		b.phase = 2
		angry = true
		ev.append({"kind": "phase", "pos": b.pos})
	match b.kind:
		"queen":
			b.rot = float(b.rot) + (1.3 if angry else 0.55) * delta
			# Keeps a few squares between herself and the player.
			var want: Vector2 = chase * (2.2 if to_p.length() > 7.0 * u else -1.0) * u
			b.vel = (b.vel as Vector2).move_toward(want, 3.0 * u * delta)
			if _timer(b, "hatch", 2.6 if angry else 3.6, delta):
				var types: Array = ["spinner", "grunt", "spinner"] if angry else ["grunt", "grunt", "weaver"]
				for i in types.size():
					var a := randf() * TAU
					ev.append({"kind": "spawn", "type": types[i], "pos": b.pos + Vector2(cos(a), sin(a)) * (QUEEN_RING + 1.2) * u})
			if angry and _timer(b, "ring", 4.5 if hard else 5.5, delta):
				ev.append({"kind": "shots", "list": ring_shots(b.pos, 14 if hard else 10, float(b.t), SHOT_SPEED * 0.9)})
		"serpent":
			var speed: float = (9.0 if angry else 7.0) * (1.15 if hard else 1.0)
			var want_dir: Vector2 = chase.rotated(sin(float(b.t) * 1.6) * 0.7)
			var d: Vector2 = (b.dir as Vector2)
			d = d.slerp(want_dir, clampf(delta * 2.2, 0.0, 1.0)).normalized() if want_dir != Vector2.ZERO else d
			b.dir = d
			b.vel = d * speed * u
			if b.segs.size() < SERPENT_SEGS * 2 / 3 and _timer(b, "spit", 3.0 if hard else 4.0, delta):
				ev.append({"kind": "shots", "list": fan_shots(b.pos, chase, 5, 0.5, SHOT_SPEED * 1.2)})
		"lord":
			b.spin = float(b.spin) + delta
			b.vel = chase * 1.2 * u
			if _timer(b, "ring", (3.2 if angry else 4.2) * (0.8 if hard else 1.0), delta):
				ev.append({"kind": "shots", "list": ring_shots(b.pos, (24 if angry else 16) + (6 if hard else 0), float(b.t), SHOT_SPEED * 0.8)})
			if _timer(b, "protons", 6.0, delta):
				for i in (6 if angry else 4):
					var a := TAU * i / (6.0 if angry else 4.0) + float(b.t)
					ev.append({"kind": "spawn", "type": "proton", "pos": b.pos + Vector2(cos(a), sin(a)) * (LORD_R + 1.0) * u})
			if angry and not b.has("wells_out"):
				b.wells_out = true
				for i in 2:
					var a := PI * i + 0.7
					ev.append({"kind": "spawn", "type": "well", "pos": b.pos + Vector2(cos(a), sin(a)) * 7.0 * u, "active": true})
		"titan":
			b.rot = float(b.rot) + 0.5 * delta
			var guns := 0
			for h in b.turrets:
				if int(h) > 0:
					guns += 1
			if guns > 0:
				b.vel = (b.vel as Vector2).move_toward(chase * 2.0 * u, 4.0 * u * delta)
				if _timer(b, "volley", (1.1 if hard else 1.5), delta):
					var shots: Array = []
					for i in 4:
						if int(b.turrets[i]) <= 0:
							continue
						var tp := turret_pos(b, i)
						var aim: Vector2 = (player_pos - tp).normalized()
						shots.append({"pos": tp, "vel": aim * SHOT_SPEED * u, "life": 6.0, "r": 0.28})
					ev.append({"kind": "shots", "list": shots})
			else:
				# Turrets gone: it charges like a repulsor and fires 8-way bursts.
				b.st = float(b.st) - delta
				if b.state != "charge":
					b.dir = (b.dir as Vector2).slerp(chase, clampf(delta * 3.0, 0.0, 1.0)).normalized() if chase != Vector2.ZERO else b.dir
					b.vel = (b.vel as Vector2).move_toward(Vector2.ZERO, 10.0 * u * delta)
					if b.st <= 0.0:
						b.state = "charge"
						b.st = 0.8
						b.vel = (b.dir as Vector2) * (20.0 if hard else 17.0) * u
				else:
					b.vel = (b.vel as Vector2).move_toward(Vector2.ZERO, 8.0 * u * delta)
					if b.st <= 0.0:
						b.state = "aim"
						b.st = 1.4
						ev.append({"kind": "shots", "list": ring_shots(b.pos, 12 if hard else 8, float(b.t), SHOT_SPEED)})
	_move(b, arena, delta)
	return ev

static func _move(b: Dictionary, arena: Vector2, delta: float) -> void:
	var u: float = Core.U
	var r := body_radius(b)
	var pos: Vector2 = b.pos + (b.vel as Vector2) * delta
	var lo := Vector2(r, r)
	var hi := arena - Vector2(r, r)
	if pos.x < lo.x or pos.x > hi.x:
		b.vel = Vector2(-(b.vel as Vector2).x, (b.vel as Vector2).y)
		if b.has("dir"):
			b.dir = Vector2(-(b.dir as Vector2).x, (b.dir as Vector2).y)
	if pos.y < lo.y or pos.y > hi.y:
		b.vel = Vector2((b.vel as Vector2).x, -(b.vel as Vector2).y)
		if b.has("dir"):
			b.dir = Vector2((b.dir as Vector2).x, -(b.dir as Vector2).y)
	b.pos = pos.clamp(lo, hi)
	if b.kind == "serpent":
		var prev: Vector2 = b.pos
		var segs: Array = b.segs
		for k in segs.size():
			var s: Vector2 = segs[k]
			var off := s - prev
			if off.length() > SERPENT_GAP * u:
				s = prev + off.normalized() * SERPENT_GAP * u
			segs[k] = s
			prev = s

static func body_radius(b: Dictionary) -> float:
	var u: float = Core.U
	match b.kind:
		"queen":
			return (QUEEN_RING + 0.4) * u
		"serpent":
			return 0.9 * u
		"lord":
			return LORD_R * u
		"titan":
			return TITAN_R * u
	return u

static func ring_shots(pos: Vector2, n: int, twist: float, speed: float) -> Array:
	var out: Array = []
	for i in n:
		var a := TAU * i / n + twist * 0.37
		out.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * speed * Core.U, "life": 7.0, "r": 0.28})
	return out

static func fan_shots(pos: Vector2, dir: Vector2, n: int, spread: float, speed: float) -> Array:
	var out: Array = []
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	for i in n:
		var a := (i - (n - 1) / 2.0) * spread / maxf(1.0, n - 1.0) * 2.0
		out.append({"pos": pos, "vel": dir.rotated(a) * speed * Core.U, "life": 6.0, "r": 0.28})
	return out

## Pulls the player (pixels/s) -- only the Gravity Lord does.
static func pull(b: Dictionary, p: Vector2) -> Vector2:
	if b.kind != "lord" or float(b.warm) > 0.0:
		return Vector2.ZERO
	var off: Vector2 = b.pos - p
	var d: float = off.length()
	var rng := LORD_PULL_RANGE * Core.U
	if d > rng or d < 1.0:
		return Vector2.ZERO
	return off / d * (3.2 if int(b.phase) == 1 else 4.6) * Core.U * (1.0 - d / rng)

## A Gravity Lord bends shots like a well, harder.
static func bender(b: Dictionary) -> Dictionary:
	if b.kind != "lord" or float(b.warm) > 0.0:
		return {}
	return {"pos": b.pos, "range": 9.0 * Core.U, "pull": 75.0}

# ---------- damage ----------

## One bullet at `p` against this boss. Returns "" (missed), "block"
## (armour: bullet spent, no damage), "hit" (damage done) or "part"
## (a plate / segment / turret broke). `out` gets the hit's position.
static func bullet_hit(b: Dictionary, p: Vector2, br: float, ev: Array) -> String:
	if float(b.warm) > 0.0:
		return ""
	var u: float = Core.U
	match b.kind:
		"queen":
			var off: Vector2 = p - b.pos
			var d: float = off.length()
			if d <= QUEEN_CORE * u + br:
				return _hurt(b, 1, ev)
			if absf(d - QUEEN_RING * u) <= 0.45 * u + br:
				var a: float = fposmod(off.angle() - float(b.rot) + PI / QUEEN_PLATES, TAU)
				var i := int(a / (TAU / QUEEN_PLATES)) % QUEEN_PLATES
				if int(b.plates[i]) > 0:
					b.plates[i] = int(b.plates[i]) - 1
					b.flash = 0.06
					if int(b.plates[i]) <= 0:
						ev.append({"kind": "part", "pos": plate_pos(b, i), "color": color_of(b)})
						return "part"
					return "block"
			return ""
		"serpent":
			var tail := serpent_tail(b)
			if p.distance_to(b.pos) <= 0.9 * u + br:
				if tail >= 0:
					return "block"
				return _hurt(b, 1, ev)
			for k in b.segs.size():
				if p.distance_to(b.segs[k]) <= SERPENT_SEG_R * u + br:
					if k != tail:
						return "block"
					b.seg_hp[k] = int(b.seg_hp[k]) - 1
					b.flash = 0.06
					if int(b.seg_hp[k]) <= 0:
						ev.append({"kind": "part", "pos": b.segs[k], "color": color_of(b)})
						b.segs.remove_at(k)
						b.seg_hp.remove_at(k)
						return "part"
					return "hit"
			return ""
		"lord":
			if p.distance_to(b.pos) <= LORD_R * u + br:
				return _hurt(b, 1, ev)
			return ""
		"titan":
			for i in 4:
				if int(b.turrets[i]) > 0 and p.distance_to(turret_pos(b, i)) <= TITAN_TURRET_R * u + br:
					b.turrets[i] = int(b.turrets[i]) - 1
					b.flash = 0.06
					if int(b.turrets[i]) <= 0:
						ev.append({"kind": "part", "pos": turret_pos(b, i), "color": color_of(b)})
						return "part"
					return "hit"
			if p.distance_to(b.pos) <= TITAN_R * u + br:
				for h in b.turrets:
					if int(h) > 0:
						return "block"
				return _hurt(b, 1, ev)
			return ""
	return ""

static func _hurt(b: Dictionary, n: int, _ev: Array) -> String:
	b.hp = maxi(0, int(b.hp) - n)
	b.flash = 0.06
	return "hit"

## Damage from a bomb, a drone or a blast: armour first, like bullets would.
static func damage(b: Dictionary, n: int) -> void:
	if float(b.warm) > 0.0:
		return
	for i in n:
		match b.kind:
			"queen":
				var hit := false
				for k in b.plates.size():
					if int(b.plates[k]) > 0:
						b.plates[k] = int(b.plates[k]) - 1
						hit = true
						break
				if not hit:
					b.hp = maxi(0, int(b.hp) - 1)
			"serpent":
				var tail := serpent_tail(b)
				if tail >= 0:
					b.seg_hp[tail] = int(b.seg_hp[tail]) - 1
					if int(b.seg_hp[tail]) <= 0:
						b.segs.remove_at(tail)
						b.seg_hp.remove_at(tail)
				else:
					b.hp = maxi(0, int(b.hp) - 1)
			"titan":
				var hit := false
				for k in 4:
					if int(b.turrets[k]) > 0:
						b.turrets[k] = int(b.turrets[k]) - 1
						hit = true
						break
				if not hit:
					b.hp = maxi(0, int(b.hp) - 1)
			_:
				b.hp = maxi(0, int(b.hp) - 1)
	b.flash = 0.08

## Does the boss's body touch the player?
static func touches(b: Dictionary, p: Vector2, pr: float) -> bool:
	if float(b.warm) > 0.0:
		return false
	var u: float = Core.U
	match b.kind:
		"queen":
			return p.distance_to(b.pos) <= (QUEEN_RING + 0.35) * u + pr
		"serpent":
			if p.distance_to(b.pos) <= 0.9 * u + pr:
				return true
			for s in b.segs:
				if p.distance_to(s) <= SERPENT_SEG_R * u + pr:
					return true
			return false
		"lord":
			return p.distance_to(b.pos) <= LORD_R * u + pr
		"titan":
			if p.distance_to(b.pos) <= TITAN_R * u + pr:
				return true
			for i in 4:
				if int(b.turrets[i]) > 0 and p.distance_to(turret_pos(b, i)) <= TITAN_TURRET_R * u + pr:
					return true
	return false

## The nearest point worth shooting at (drones aim here).
static func target_point(b: Dictionary) -> Vector2:
	match b.kind:
		"serpent":
			var tail := serpent_tail(b)
			if tail >= 0:
				return b.segs[tail]
		"titan":
			for i in 4:
				if int(b.turrets[i]) > 0:
					return turret_pos(b, i)
	return b.pos
