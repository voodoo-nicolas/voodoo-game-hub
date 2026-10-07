extends RefCounted

## The bosses: big multi-part enemies with their own rules, kept as plain
## Dictionaries like the rest of the game (see geometry_wars_core.gd).
## Distances are in grid squares times Core.U, like everything else.
##
##   queen    Hive Queen     a core inside turning rings of armour plates
##                           (one ring, two from tier 3, three from tier 6).
##                           Shoot plates away to reach the core; she hatches
##                           eyes and masks, then splitters and rings of shots.
##   serpent  Serpent King   a long snake. Every body segment can be shot
##                           away (owner, 2026-10-07: only the tail tip was
##                           too hard); once the body is gone the head can.
##                           It weaves after you, slower than it used to,
##                           and its tail keeps hatching little bone serpents.
##   scorpion Bone Scorpion  two claws, a tail and a head (owner, 2026-10-07).
##                           Break both claws (they snap at you up close);
##                           before each tail strike it stops, rears its
##                           tail and marks the spot in red (move!), then
##                           the tail whips round to strike, and only then,
##                           while it is out in front, can its stinger be
##                           hurt. Claws and stinger gone, the head can. It
##                           sends spiders after you.
##   lord     Gravity Lord   a giant black hole: pulls you, bends your shots,
##                           fires rings of shots and spawns sprites. Gentler
##                           since 2026-10-07 (the owner couldn't beat it).
##   titan    Titan          an octagon with gun turrets (4, 6 from tier 5, 8
##                           from tier 7). Destroy the turrets, then the core
##                           -- which starts charging.
##   watcher  Watcher        a giant eye that shoots at you. Its lid shuts
##                           out your pins; it opens to aim a beam (a thin
##                           sight line that locks just before), fires it,
##                           then stays open, dazed
##                           (double damage). Its beam and shots stop at the
##                           tombstones the game puts round the map: hide
##                           behind one (owner, 2026-10-07).
##   warden   Warden         a fortress under a shield fed by four crystal
##                           pylons, one in each corner of the map. Break all
##                           four and the shield drops; a while later the
##                           pylons grow back and it comes up again.
##
## Tier (1 = the first boss .. 8 = the last, the level data's boss "n";
## owner: "bigger and stronger as progression goes"): each tier is bigger
## (size_k), tougher (hp_k), quicker to attack (rate_k) and sends more
## minions; some attacks only start at a tier. update() returns events for
## the game to act on:
##   {kind: "spawn", type, pos}   a minion to add
##   {kind: "shots", list}        enemy bullets [{pos, vel, life, r}]
##   {kind: "line", n}            a line of darts at the player
##   {kind: "phase", pos}         the boss got angry (half health)
##   {kind: "part", pos, color}   a plate / segment / turret / claw broke
##   {kind: "beam", on}           the Watcher's beam fires / stops
##   {kind: "aim"}                the Watcher opens to aim
##   {kind: "shield", on, pos}    the Warden's shield comes up / drops
##   {kind: "tell", pos}          the scorpion rears to strike at pos
##   {kind: "whip", pos}          the scorpion's tail strikes
##   {kind: "snap", pos}          a claw snaps

const Core = preload("res://scripts/games/geometry_wars/geometry_wars_core.gd")

const NAMES := {"queen": "Hive Queen", "serpent": "Serpent King", "scorpion": "Bone Scorpion", "lord": "Gravity Lord",
	"titan": "Titan", "watcher": "Watcher", "warden": "Warden"}
const COLORS := {
	"queen": Color(1.0, 0.35, 0.85), "serpent": Color(0.35, 1.0, 0.55), "scorpion": Color(1.0, 0.62, 0.2),
	"lord": Color(1.0, 0.5, 0.15), "titan": Color(0.35, 0.8, 1.0), "watcher": Color(1.0, 0.25, 0.3),
	"warden": Color(0.55, 0.65, 1.0),
}
const POINTS := {"queen": 25000, "serpent": 30000, "scorpion": 35000, "lord": 40000, "titan": 50000,
	"watcher": 45000, "warden": 60000}
const MAX_TIER := 8

const QUEEN_CORE := 1.5
## [plates, radius, spin] per ring, inside out; tier 3 adds the inner one,
## tier 6 the outer one.
const QUEEN_RINGS := [[8, 1.95, -1.6], [10, 2.7, 1.0], [14, 3.5, -0.7]]
const SERPENT_SEGS := 22
const SERPENT_GAP := 0.85
const SERPENT_SEG_R := 0.55
const LORD_R := 1.8
const LORD_PULL_RANGE := 13.0
const TITAN_R := 2.2
const TITAN_TURRET_OFF := 2.7
const TITAN_TURRET_R := 0.75
const WATCHER_EYE := 1.6
const WATCHER_FRAME := 3.0
## The Watcher's sight line stops following you this long before it fires.
const BEAM_LOCK := 0.45
## The beam's half-width in squares, plus this much per tier.
const BEAM_HALF := 0.5
const BEAM_HALF_TIER := 0.05
const WARDEN_R := 2.4
const PYLON_R := 0.95
## Seconds the Warden's shield stays down before the pylons grow back.
const SHIELD_DOWN := 20.0
const SCORP_HEAD := 1.4
const SCORP_CLAW_R := 0.95
const TAIL_SEGS := 8
const TAIL_SEG := 0.75
const STINGER_R := 0.6
## The stinger is this much easier to hit while the tail is out.
const STINGER_OUT_R := 1.15
## The tell before a tail strike: it stops, rears and rattles this long.
const WIND_UP := 0.9
const SHOT_SPEED := 7.0

static func make(kind: String, pos: Vector2, tier: int = 1) -> Dictionary:
	tier = clampi(tier, 1, MAX_TIER)
	var hk := hp_k_of(tier)
	var b := {"boss": true, "kind": kind, "pos": pos, "vel": Vector2.ZERO, "t": 0.0, "tier": tier,
		"scale": size_k_of(tier), "hard": tier >= 6, "phase": 1, "warm": 2.0, "flash": 0.0, "timers": {}}
	match kind:
		"queen":
			b.hp = int(320 * hk)
			var rings: Array = []
			var which: Array = [1]
			if tier >= 3:
				which = [0, 1]
			if tier >= 6:
				which = [0, 1, 2]
			for wi in which:
				var spec: Array = QUEEN_RINGS[wi]
				var plates: Array = []
				for i in int(spec[0]):
					plates.append(int(12 * hk))
				rings.append({"r": float(spec[1]), "spin": float(spec[2]), "rot": randf() * TAU, "plates": plates})
			b.rings = rings
		"serpent":
			b.hp = int(150 * hk)
			var segs: Array = []
			var seg_hp: Array = []
			for i in SERPENT_SEGS + 2 * (tier - 1):
				segs.append(pos - Vector2(SERPENT_GAP * Core.U * b.scale * (i + 1), 0))
				seg_hp.append(int(10 * hk))
			b.segs = segs
			b.seg_hp = seg_hp
			b.dir = Vector2.LEFT
		"scorpion":
			b.hp = int(260 * hk)
			b.claws = [int(60 * hk), int(60 * hk)]
			b.snap = [0.0, 0.0]
			b.snap_cd = [1.0, 1.6]
			b.sting = int(70 * hk)
			b.dir = Vector2.LEFT
			b.tail_a = 0.0
			b.tail_side = 1.0
			b.whip = "rest"
			b.wt = 2.5
			b.step = 0.0
		"lord":
			b.hp = int(650 * hk)
			b.spin = 0.0
		"titan":
			b.hp = int(420 * hk)
			var turrets: Array = []
			for i in (8 if tier >= 7 else (6 if tier >= 5 else 4)):
				turrets.append(int(70 * hk))
			b.turrets = turrets
			b.rot = 0.0
			b.state = "drift"
			b.st = 0.0
			b.dir = Vector2.RIGHT
		"watcher":
			b.hp = int(380 * hk)
			b.state = "watch"
			b.st = 2.5
			b.dir = Vector2.LEFT
			b.rot = 0.0
		"warden":
			b.hp = int(440 * hk)
			b.pylons = []  # placed in the corners on its first update (it needs the map's size)
			b.shield = true
			b.down_t = 0.0
			b.spiral = 0.0
			b.rot = 0.0
	b.max_hp = total_hp(b)
	return b

## How much bigger, tougher and quicker each tier is.
static func size_k_of(tier: int) -> float:
	return 1.25 * (1.0 + 0.09 * (tier - 1))

static func hp_k_of(tier: int) -> float:
	return 1.0 + 0.15 * (tier - 1)

## Attack intervals are multiplied by this.
static func rate_k(b: Dictionary) -> float:
	return maxf(0.6, 1.0 - 0.05 * (_tier(b) - 1))

static func _tier(b: Dictionary) -> int:
	return int(b.get("tier", 1))

static func _sc(b: Dictionary) -> float:
	return float(b.get("scale", 1.0))

static func name_of(b: Dictionary) -> String:
	return NAMES.get(b.kind, "Boss")

static func color_of(b: Dictionary) -> Color:
	return COLORS.get(b.kind, Color.WHITE)

## Everything that still has to be shot away, for the health bar.
static func total_hp(b: Dictionary) -> int:
	var n := int(b.hp)
	match b.kind:
		"queen":
			for ring in b.rings:
				for p in ring.plates:
					n += int(p)
		"serpent":
			for h in b.seg_hp:
				n += int(h)
		"scorpion":
			n += int(b.claws[0]) + int(b.claws[1]) + int(b.sting)
		"titan":
			for h in b.turrets:
				n += int(h)
		"warden":
			for p in b.pylons:
				n += int(p.hp)
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

## Where a queen ring's plate i is, a titan turret, a scorpion claw.
static func plate_pos(b: Dictionary, ring: Dictionary, i: int) -> Vector2:
	var a: float = float(ring.rot) + TAU * i / (ring.plates as Array).size()
	return b.pos + Vector2(cos(a), sin(a)) * float(ring.r) * _sc(b) * Core.U

static func turret_pos(b: Dictionary, i: int) -> Vector2:
	var n: int = (b.turrets as Array).size()
	var a: float = float(b.rot) + TAU * i / n + PI / n
	return b.pos + Vector2(cos(a), sin(a)) * TITAN_TURRET_OFF * _sc(b) * Core.U

static func claw_pos(b: Dictionary, i: int) -> Vector2:
	var u: float = Core.U * _sc(b)
	var f: Vector2 = b.dir
	var side := Vector2(-f.y, f.x) * (-1.0 if i == 0 else 1.0)
	return b.pos + f * (SCORP_HEAD * 0.7 + 2.0 + _lunge(float(b.snap[i]))) * u + side * 1.9 * u

## The claw's reach while it snaps: out fast, a moment held, back slowly.
static func _lunge(t: float) -> float:
	if t <= 0.0:
		return 0.0
	var k := 0.65 - t  # time since the snap began
	if k < 0.18:
		return 2.0 * k / 0.18
	if k < 0.33:
		return 2.0
	return 2.0 * maxf(0.0, 1.0 - (k - 0.33) / 0.32)

## The shoulder a claw's arm starts from (drawing).
static func shoulder_pos(b: Dictionary, i: int) -> Vector2:
	var u: float = Core.U * _sc(b)
	var f: Vector2 = b.dir
	var side := Vector2(-f.y, f.x) * (-1.0 if i == 0 else 1.0)
	return b.pos + f * SCORP_HEAD * 0.45 * u + side * SCORP_HEAD * 0.8 * u

## The tail, base to stinger (the stinger is the last point): a curve from
## the back of the body. Resting, it curls behind; striking (tail_a 0 -> 1),
## it arcs over one side and the stinger lands where you stood when it wound
## up (strike_l, in the body's own frame, so it moves with it).
static func tail_points(b: Dictionary) -> Array:
	var u: float = Core.U * _sc(b)
	var f: Vector2 = b.dir
	var sd := Vector2(-f.y, f.x)
	var side: float = b.tail_side
	var w: float = b.tail_a
	var sway := sin(float(b.t) * 2.2) * 0.35 * (1.0 - clampf(w, 0.0, 1.0))
	var base := Vector2(-SCORP_HEAD * 0.85, 0.0)
	var strike: Vector2 = b.get("strike_l", Vector2(5.0, 0.0))
	var e := Vector2(-4.6, (1.0 + sway) * side).lerp(strike, w)
	var c := Vector2(-3.4, (-0.9 + sway) * side).lerp(Vector2(0.4, 3.0 * side), w)
	var pts: Array = []
	var n := TAIL_SEGS if int(b.sting) > 0 else 1
	for k in n + 1:
		var q := float(k) / TAIL_SEGS
		var l := base * (1.0 - q) * (1.0 - q) + c * 2.0 * (1.0 - q) * q + e * q * q
		pts.append(b.pos + (f * l.x + sd * l.y) * u)
	return pts

## Where the stinger will land (the red mark shown while it winds up).
static func strike_point(b: Dictionary) -> Vector2:
	var u: float = Core.U * _sc(b)
	var f: Vector2 = b.dir
	var l: Vector2 = b.get("strike_l", Vector2(5.0, 0.0))
	return b.pos + (f * l.x + Vector2(-f.y, f.x) * l.y) * u

## 0..1 while the strike is coming (wind-up and swing), for the warning mark.
static func strike_warning(b: Dictionary) -> float:
	if b.kind != "scorpion" or int(b.sting) <= 0:
		return 0.0
	match str(b.whip):
		"wind":
			return clampf(1.0 - float(b.wt) / WIND_UP, 0.0, 1.0) * 0.8
		"swing":
			return 1.0
	return 0.0

static func stinger_pos(b: Dictionary) -> Vector2:
	var pts := tail_points(b)
	return pts[pts.size() - 1]

## While the tail is out (striking, held, coming back) the stinger can be hurt.
static func stinger_open(b: Dictionary) -> bool:
	return b.kind == "scorpion" and int(b.sting) > 0 and str(b.whip) in ["swing", "hold", "back"]

static func claws_left(b: Dictionary) -> int:
	return (1 if int(b.claws[0]) > 0 else 0) + (1 if int(b.claws[1]) > 0 else 0)

static func pylon_r(b: Dictionary) -> float:
	return PYLON_R * minf(_sc(b), 1.5) * Core.U

static func pylons_left(b: Dictionary) -> int:
	var n := 0
	for p in b.get("pylons", []):
		if int(p.hp) > 0:
			n += 1
	return n

static func shield_up(b: Dictionary) -> bool:
	return b.kind == "warden" and bool(b.get("shield", false))

static func shield_r(b: Dictionary) -> float:
	return (WARDEN_R + 1.0) * _sc(b) * Core.U

## The Watcher's beams: directions while it aims or fires (else empty).
static func beam_dirs(b: Dictionary) -> Array:
	if b.kind != "watcher" or float(b.warm) > 0.0 or not str(b.state) in ["aim", "fire"]:
		return []
	var d: Vector2 = b.dir
	if int(b.phase) >= 2:
		return [d, d.rotated(0.45), d.rotated(-0.45)]
	return [d]

static func beam_on(b: Dictionary) -> bool:
	return b.kind == "watcher" and str(b.state) == "fire"

## Aimed and locked: the beam is about to fire along the sight line.
static func beam_locked(b: Dictionary) -> bool:
	return b.kind == "watcher" and str(b.state) == "aim" and float(b.st) <= BEAM_LOCK

static func beam_half(b: Dictionary) -> float:
	return (BEAM_HALF + BEAM_HALF_TIER * _tier(b)) * Core.U

## Its lid is open: pins get through (aiming, firing, dazed).
static func eye_open(b: Dictionary) -> bool:
	return b.kind == "watcher" and str(b.state) != "watch"

# ---------- movement + attacks ----------

static func update(b: Dictionary, player_pos: Vector2, arena: Vector2, delta: float) -> Array:
	var u: float = Core.U
	var ev: Array = []
	b.t = float(b.t) + delta
	b.flash = maxf(0.0, float(b.flash) - delta)
	if b.kind == "warden" and (b.pylons as Array).is_empty():
		_place_pylons(b, arena)
	if float(b.warm) > 0.0:
		b.warm = float(b.warm) - delta
		return ev
	var to_p: Vector2 = player_pos - b.pos
	var chase: Vector2 = to_p.normalized() if to_p.length() > 1.0 else Vector2.ZERO
	var angry: bool = int(b.phase) >= 2
	var tier := _tier(b)
	var rk := rate_k(b)
	var sc := _sc(b)
	if int(b.phase) == 1 and total_hp(b) <= int(b.max_hp) / 2:
		b.phase = 2
		angry = true
		ev.append({"kind": "phase", "pos": b.pos})
	match b.kind:
		"queen":
			for ring in b.rings:
				ring.rot = float(ring.rot) + float(ring.spin) * (1.3 if angry else 0.55) * delta
			# Keeps a few squares between herself and the player.
			var want: Vector2 = chase * (2.2 if to_p.length() > (7.0 * sc) * u else -1.0) * u
			b.vel = (b.vel as Vector2).move_toward(want, 3.0 * u * delta)
			if _timer(b, "hatch", (2.6 if angry else 3.6) * rk, delta):
				var types: Array = ["spinner", "grunt", "spinner"] if angry else ["grunt", "grunt", "weaver"]
				if tier >= 3:
					types.append("weaver" if not angry else "spinner")
				if tier >= 5:
					types.append("snake" if randf() < 0.5 else "repulsor")
				for i in types.size():
					var a := randf() * TAU
					ev.append({"kind": "spawn", "type": types[i], "pos": b.pos + Vector2(cos(a), sin(a)) * body_radius(b) * 1.15})
			if angry and _timer(b, "ring", 5.5 * rk, delta):
				ev.append({"kind": "shots", "list": ring_shots(b.pos, 10 + 2 * (tier - 1), float(b.t), SHOT_SPEED * 0.9)})
			if tier >= 4 and _timer(b, "fan", 6.5 * rk, delta):
				ev.append({"kind": "shots", "list": fan_shots(b.pos, chase, 5, 0.45, SHOT_SPEED)})
		"serpent":
			# Slower and looser than it used to be (owner, 2026-10-07).
			var speed: float = (6.5 if angry else 5.0) * (1.0 + 0.04 * (tier - 2))
			var want_dir: Vector2 = chase.rotated(sin(float(b.t) * 1.3) * 0.9)
			var d: Vector2 = (b.dir as Vector2)
			d = d.slerp(want_dir, clampf(delta * 1.3, 0.0, 1.0)).normalized() if want_dir != Vector2.ZERO else d
			b.dir = d
			b.vel = d * speed * u
			if (b.segs.size() < (SERPENT_SEGS * 2) / 3 or tier >= 4) and _timer(b, "spit", 4.0 * rk, delta):
				ev.append({"kind": "shots", "list": fan_shots(b.pos, chase, 5, 0.5, SHOT_SPEED * 1.1)})
			# Its brood: little bone serpents from its tail (owner, 2026-10-07:
			# the whole body can be shot now, so it gets more helpers).
			if _timer(b, "brood", 6.5 * rk, delta):
				var tail_p: Vector2 = b.segs[b.segs.size() - 1] if not b.segs.is_empty() else b.pos
				for i in 1 + tier / 3:
					ev.append({"kind": "spawn", "type": "snake", "pos": tail_p + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * u})
		"scorpion":
			_update_scorpion(b, player_pos, to_p, chase, angry, tier, rk, sc, delta, ev)
		"lord":
			b.spin = float(b.spin) + delta
			b.vel = chase * 1.2 * u
			if _timer(b, "ring", (3.8 if angry else 4.8) * rk, delta):
				ev.append({"kind": "shots", "list": ring_shots(b.pos, (14 if angry else 10) + tier, float(b.t), SHOT_SPEED * 0.7)})
			if _timer(b, "protons", 7.0, delta):
				var n := 4 if angry else 3
				for i in n:
					var a := TAU * i / float(n) + float(b.t)
					ev.append({"kind": "spawn", "type": "proton", "pos": b.pos + Vector2(cos(a), sin(a)) * (LORD_R * sc + 1.0) * u})
			if angry and not b.has("wells_out"):
				b.wells_out = true
				for i in (2 if tier >= 6 else 1):
					var a := PI * i + 0.7
					ev.append({"kind": "spawn", "type": "well", "pos": b.pos + Vector2(cos(a), sin(a)) * 7.0 * u, "active": true})
		"titan":
			b.rot = float(b.rot) + 0.5 * delta
			var guns := 0
			for h in b.turrets:
				if int(h) > 0:
					guns += 1
			if tier >= 7 and _timer(b, "darts", 6.0 * rk, delta):
				ev.append({"kind": "line", "n": 3 + tier / 2})
			if guns > 0:
				b.vel = (b.vel as Vector2).move_toward(chase * 2.0 * u, 4.0 * u * delta)
				if _timer(b, "volley", 1.5 * rk, delta):
					# More than four guns take turns: every other one per volley.
					var n: int = (b.turrets as Array).size()
					b.volley_n = int(b.get("volley_n", 0)) + 1
					var shots: Array = []
					for i in n:
						if int(b.turrets[i]) <= 0 or (n > 4 and i % 2 != int(b.volley_n) % 2):
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
						b.vel = (b.dir as Vector2) * (17.0 + tier * 0.5) * u
				else:
					b.vel = (b.vel as Vector2).move_toward(Vector2.ZERO, 8.0 * u * delta)
					if b.st <= 0.0:
						b.state = "aim"
						b.st = 1.4
						ev.append({"kind": "shots", "list": ring_shots(b.pos, 8 + tier / 2 * 2, float(b.t), SHOT_SPEED)})
		"watcher":
			_update_watcher(b, player_pos, to_p, chase, angry, tier, rk, delta, ev)
		"warden":
			_update_warden(b, player_pos, arena, chase, angry, tier, rk, delta, ev)
	_move(b, arena, delta)
	return ev

static func _update_scorpion(b: Dictionary, player_pos: Vector2, to_p: Vector2, chase: Vector2, angry: bool,
		tier: int, rk: float, sc: float, delta: float, ev: Array) -> void:
	var u: float = Core.U
	var exposed := claws_left(b) == 0 and int(b.sting) <= 0
	# It turns to face you and scuttles in a zigzag, stopping a tail's length
	# away. Before a strike it stops dead and rears its tail (the tell, owner
	# 2026-10-07: you must see it coming), so the marked spot stays put.
	var striking: bool = str(b.whip) in ["wind", "swing", "hold"]
	if chase != Vector2.ZERO and not striking:
		b.dir = (b.dir as Vector2).slerp(chase, clampf(delta * 2.0, 0.0, 1.0)).normalized()
	b.step = float(b.step) + delta
	var f: Vector2 = b.dir
	var keep := (4.0 if exposed else 7.0) * sc * u
	var speed := (4.6 if exposed else 2.8) * (1.0 + 0.05 * (tier - 1)) * u
	var want := Vector2.ZERO
	if to_p.length() > keep:
		want = (f + Vector2(-f.y, f.x) * sin(float(b.step) * 1.7) * 0.6).normalized() * speed
	elif to_p.length() < keep * 0.6:
		want = -f * speed * 0.5
	if striking:
		want = Vector2.ZERO
	b.vel = (b.vel as Vector2).move_toward(want, (24.0 if striking else 6.0) * u * delta)
	# Claws snap when you come close.
	for i in 2:
		b.snap[i] = maxf(0.0, float(b.snap[i]) - delta)
		b.snap_cd[i] = maxf(0.0, float(b.snap_cd[i]) - delta)
		if int(b.claws[i]) <= 0:
			continue
		var cp := claw_pos(b, i)
		if float(b.snap_cd[i]) <= 0.0 and cp.distance_to(player_pos) < 3.2 * sc * u:
			b.snap[i] = 0.65
			b.snap_cd[i] = 1.4 * rk
			ev.append({"kind": "snap", "pos": cp})
		if tier >= 4 and _timer(b, "claw%d" % i, 2.6 * rk + i * 0.4, delta):
			ev.append({"kind": "shots", "list": fan_shots(cp, (player_pos - cp).normalized(), 3, 0.25, SHOT_SPEED)})
	# The tail: rest -> wind up (it picks the spot you are on) -> strike ->
	# stuck there a moment (the stinger can be shot) -> back.
	if int(b.sting) > 0:
		b.wt = float(b.wt) - delta
		match str(b.whip):
			"rest":
				b.tail_a = move_toward(float(b.tail_a), 0.0, 2.0 * delta)
				if float(b.wt) <= 0.0:
					b.whip = "wind"
					b.wt = WIND_UP
					b.tail_side = 1.0 if randf() < 0.5 else -1.0
					# Where you are, in its own frame, within the tail's reach.
					var l := Vector2(to_p.dot(f), to_p.dot(Vector2(-f.y, f.x))) / (sc * u)
					l.x = clampf(l.x, 2.5, 6.8)
					l.y = clampf(l.y, -2.8, 2.8)
					b.strike_l = l
					ev.append({"kind": "tell", "pos": strike_point(b)})
			"wind":
				b.tail_a = move_toward(float(b.tail_a), -0.25, 1.0 * delta)
				if float(b.wt) <= 0.0:
					b.whip = "swing"
					b.wt = 0.3
					ev.append({"kind": "whip", "pos": stinger_pos(b)})
			"swing":
				b.tail_a = move_toward(float(b.tail_a), 1.0, 4.2 * delta)
				if float(b.wt) <= 0.0:
					b.tail_a = 1.0
					b.whip = "hold"
					b.wt = 1.3
					if tier >= 5:
						ev.append({"kind": "shots", "list": ring_shots(stinger_pos(b), 8, float(b.t), SHOT_SPEED * 0.8)})
			"hold":
				if float(b.wt) <= 0.0:
					b.whip = "back"
					b.wt = 0.6
			"back":
				b.tail_a = move_toward(float(b.tail_a), 0.0, 1.8 * delta)
				if float(b.wt) <= 0.0:
					b.whip = "rest"
					b.wt = (2.4 if angry else 3.4) * rk
	# Spiders scuttle out from under it; grunts once its head is bare.
	if _timer(b, "brood", 7.0 * rk, delta):
		var kind := "grunt" if exposed else "layer"
		for i in 2 + tier / 3:
			var a := randf() * TAU
			ev.append({"kind": "spawn", "type": kind, "pos": b.pos + Vector2(cos(a), sin(a)) * SCORP_HEAD * sc * 1.6 * u})
	if exposed and _timer(b, "ring", 3.4 * rk, delta):
		ev.append({"kind": "shots", "list": ring_shots(b.pos, 10 + tier, float(b.t), SHOT_SPEED * 0.85)})

static func _update_watcher(b: Dictionary, player_pos: Vector2, to_p: Vector2, chase: Vector2, angry: bool,
		tier: int, rk: float, delta: float, ev: Array) -> void:
	var u: float = Core.U
	b.rot = float(b.rot) + (0.9 if angry else 0.4) * delta
	b.st = float(b.st) - delta
	var still := str(b.state) in ["aim", "fire"]
	# Keeps its distance: about 11 squares away.
	var want := Vector2.ZERO
	if not still:
		var d := to_p.length()
		if d < 9.0 * u:
			want = -chase * 3.0 * u
		elif d > 14.0 * u:
			want = chase * 2.5 * u
		else:
			want = Vector2(-chase.y, chase.x) * 1.5 * u * sin(float(b.t) * 0.5)
	b.vel = (b.vel as Vector2).move_toward(want, 5.0 * u * delta)
	match str(b.state):
		"watch":
			# Lid shut: it fires streams of bolts and calls its minions.
			if _timer(b, "bolts", 1.3 * rk, delta):
				var shots: Array = []
				for i in 3 + tier / 2:
					shots.append({"pos": b.pos + chase * WATCHER_EYE * _sc(b) * u, "vel": chase * (SHOT_SPEED + 1.0 + i * 0.9) * u,
						"life": 6.0, "r": 0.32})
				ev.append({"kind": "shots", "list": shots})
			if _timer(b, "minions", 5.5 * rk, delta):
				var types: Array = ["grunt", "grunt"]
				if tier >= 4:
					types.append("weaver")
				if tier >= 6:
					types.append("spinner")
				for i in types.size():
					var a := randf() * TAU
					ev.append({"kind": "spawn", "type": types[i], "pos": b.pos + Vector2(cos(a), sin(a)) * WATCHER_FRAME * _sc(b) * u})
			if float(b.st) <= 0.0:
				b.state = "aim"
				b.st = maxf(1.2, 1.6 - 0.05 * (tier - 1))
				if chase != Vector2.ZERO:
					b.dir = chase
				ev.append({"kind": "aim"})
		"aim":
			# The sight line follows you, then locks for its last moment (it
			# blinks): get behind a tombstone, or step out of the line.
			if float(b.st) > BEAM_LOCK:
				_turn_toward(b, chase, (1.5 + 0.1 * tier) * delta)
			if float(b.st) <= 0.0:
				b.state = "fire"
				b.st = 1.0
				b.beam_id = int(b.get("beam_id", 0)) + 1
				ev.append({"kind": "beam", "on": true})
		"fire":
			_turn_toward(b, chase, (0.35 if tier >= 5 else 0.2) * delta)
			if float(b.st) <= 0.0:
				b.state = "daze"
				b.st = 2.4
				ev.append({"kind": "beam", "on": false})
		"daze":
			if float(b.st) <= 0.0:
				b.state = "watch"
				b.st = (2.4 if angry else 3.2) * rk

static func _turn_toward(b: Dictionary, chase: Vector2, max_angle: float) -> void:
	if chase == Vector2.ZERO:
		return
	var d: Vector2 = b.dir
	var a := d.angle_to(chase)
	b.dir = d.rotated(clampf(a, -max_angle, max_angle))

static func _place_pylons(b: Dictionary, arena: Vector2) -> void:
	var u: float = Core.U
	var hp := int(45 * hp_k_of(_tier(b)))
	var m := 3.0 * u
	var pylons: Array = []
	for c in [Vector2(m, m), Vector2(arena.x - m, m), Vector2(m, arena.y - m), Vector2(arena.x - m, arena.y - m)]:
		pylons.append({"pos": c, "hp": hp, "max": hp, "t": randf() * TAU})
	b.pylons = pylons
	b.max_hp = total_hp(b)

static func _update_warden(b: Dictionary, player_pos: Vector2, arena: Vector2, chase: Vector2, angry: bool,
		tier: int, rk: float, delta: float, ev: Array) -> void:
	var u: float = Core.U
	b.rot = float(b.rot) + 0.35 * delta
	var shield: bool = b.shield
	if shield and pylons_left(b) == 0:
		b.shield = false
		b.down_t = SHIELD_DOWN
		ev.append({"kind": "shield", "on": false, "pos": b.pos})
	elif not shield:
		b.down_t = float(b.down_t) - delta
		if float(b.down_t) <= 0.0:
			# The pylons grow back, weaker each time.
			for p in b.pylons:
				p.max = maxi(8, int(int(p.max) * 0.7))
				p.hp = p.max
			b.shield = true
			ev.append({"kind": "shield", "on": true, "pos": b.pos})
	shield = b.shield
	# Drifts round the middle of the map; with its shield down it creeps at you.
	var mid := arena / 2.0 + Vector2(cos(float(b.t) * 0.2), sin(float(b.t) * 0.27)) * minf(arena.x, arena.y) * 0.15
	var want: Vector2 = ((mid - b.pos).limit_length(1.0) * 1.6 * u) if shield else chase * 0.7 * u
	b.vel = (b.vel as Vector2).move_toward(want, 3.0 * u * delta)
	# A slow spiral of shots, always.
	var arms := 3 if tier >= 7 else 2
	# The shots fade before the corners: breaking the pylons is a run, not a gauntlet.
	if _timer(b, "spiral", (0.5 if not shield else 0.55) * rk, delta):
		b.spiral = float(b.spiral) + 0.37
		var shots: Array = []
		for i in arms:
			var a := float(b.spiral) + TAU * i / arms
			shots.append({"pos": b.pos, "vel": Vector2(cos(a), sin(a)) * SHOT_SPEED * 0.75 * u, "life": 4.5, "r": 0.28})
		ev.append({"kind": "shots", "list": shots})
	if shield:
		# Shielded, it sends its guards: a pack from itself, one from each pylon.
		if _timer(b, "guards", 4.5 * rk, delta):
			var types: Array = ["grunt", "weaver", "grunt"]
			if tier >= 5:
				types.append("spinner")
			if tier >= 6:
				types.append("repulsor")
			for i in types.size():
				var a := randf() * TAU
				ev.append({"kind": "spawn", "type": types[i], "pos": b.pos + Vector2(cos(a), sin(a)) * shield_r(b) * 1.1})
		if _timer(b, "posts", 8.0 * rk, delta):
			for p in b.pylons:
				if int(p.hp) > 0:
					var a := randf() * TAU
					ev.append({"kind": "spawn", "type": "weaver" if tier >= 6 else "grunt", "pos": (p.pos as Vector2) + Vector2(cos(a), sin(a)) * 2.2 * u})
	else:
		# Shield down: angrier, but its body is open -- a slow ring now and then.
		if _timer(b, "ring", 3.2 * rk, delta):
			ev.append({"kind": "shots", "list": ring_shots(b.pos, 10 + tier, float(b.t), SHOT_SPEED * 0.7)})
	for p in b.pylons:
		p.t = float(p.t) + delta
		p.flash = maxf(0.0, float(p.get("flash", 0.0)) - delta)

static func _move(b: Dictionary, arena: Vector2, delta: float) -> void:
	var u: float = Core.U
	var r := minf(body_radius(b), minf(arena.x, arena.y) * 0.4)
	var pos: Vector2 = b.pos + (b.vel as Vector2) * delta
	var lo := Vector2(r, r)
	var hi := arena - Vector2(r, r)
	if pos.x < lo.x or pos.x > hi.x:
		b.vel = Vector2(-(b.vel as Vector2).x, (b.vel as Vector2).y)
		if b.has("dir") and b.kind != "scorpion" and b.kind != "watcher":
			b.dir = Vector2(-(b.dir as Vector2).x, (b.dir as Vector2).y)
	if pos.y < lo.y or pos.y > hi.y:
		b.vel = Vector2((b.vel as Vector2).x, -(b.vel as Vector2).y)
		if b.has("dir") and b.kind != "scorpion" and b.kind != "watcher":
			b.dir = Vector2((b.dir as Vector2).x, -(b.dir as Vector2).y)
	b.pos = pos.clamp(lo, hi)
	if b.kind == "serpent":
		var prev: Vector2 = b.pos
		var segs: Array = b.segs
		var gap := SERPENT_GAP * _sc(b) * u
		for k in segs.size():
			var s: Vector2 = segs[k]
			var off := s - prev
			if off.length() > gap:
				s = prev + off.normalized() * gap
			segs[k] = s
			prev = s

static func body_radius(b: Dictionary) -> float:
	var u: float = Core.U * _sc(b)
	match b.kind:
		"queen":
			var r := 0.0
			for ring in b.rings:
				r = maxf(r, float(ring.r))
			return (r + 0.4) * u
		"serpent":
			return 0.9 * u
		"scorpion":
			return SCORP_HEAD * u
		"lord":
			return LORD_R * u
		"titan":
			for h in b.turrets:
				if int(h) > 0:
					return (TITAN_TURRET_OFF + TITAN_TURRET_R) * u
			return TITAN_R * u
		"watcher":
			return WATCHER_EYE * 1.25 * u
		"warden":
			return (WARDEN_R + (1.0 if b.get("shield", false) else 0.0)) * u
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
	var k := 1.0 + 0.05 * (_tier(b) - 1)
	return off / d * (2.0 if int(b.phase) == 1 else 2.8) * k * Core.U * (1.0 - d / rng)

## A Gravity Lord bends shots like a well, a little harder.
static func bender(b: Dictionary) -> Dictionary:
	if b.kind != "lord" or float(b.warm) > 0.0:
		return {}
	return {"pos": b.pos, "range": 7.0 * Core.U, "pull": 40.0}

# ---------- damage ----------

## One bullet at `p` against this boss. Returns "" (missed), "block"
## (armour: bullet spent, no damage), "hit" (damage done) or "part"
## (a plate / segment / turret / claw / pylon broke). Events go in `ev`.
static func bullet_hit(b: Dictionary, p: Vector2, br: float, ev: Array) -> String:
	if float(b.warm) > 0.0:
		return ""
	var u: float = Core.U
	var sc := _sc(b)
	match b.kind:
		"queen":
			var off: Vector2 = p - b.pos
			var d: float = off.length()
			# Outermost ring first: a plate there stops the pin.
			for ri in range((b.rings as Array).size() - 1, -1, -1):
				var ring: Dictionary = b.rings[ri]
				var rr: float = float(ring.r) * sc * u
				if absf(d - rr) > 0.45 * sc * u + br:
					continue
				var n: int = (ring.plates as Array).size()
				var a: float = fposmod(off.angle() - float(ring.rot) + PI / n, TAU)
				var i := int(a / (TAU / n)) % n
				if int(ring.plates[i]) > 0:
					ring.plates[i] = int(ring.plates[i]) - 1
					b.flash = 0.06
					if int(ring.plates[i]) <= 0:
						ev.append({"kind": "part", "pos": plate_pos(b, ring, i), "color": color_of(b)})
						return "part"
					return "block"
			if d <= QUEEN_CORE * sc * u + br:
				return _hurt(b, 1, ev)
			return ""
		"serpent":
			if p.distance_to(b.pos) <= 0.9 * sc * u + br:
				if not b.segs.is_empty():
					return "block"
				return _hurt(b, 1, ev)
			for k in b.segs.size():
				if p.distance_to(b.segs[k]) <= SERPENT_SEG_R * sc * u + br:
					b.seg_hp[k] = int(b.seg_hp[k]) - 1
					b.flash = 0.06
					if int(b.seg_hp[k]) <= 0:
						ev.append({"kind": "part", "pos": b.segs[k], "color": color_of(b)})
						b.segs.remove_at(k)
						b.seg_hp.remove_at(k)
						return "part"
					return "hit"
			return ""
		"scorpion":
			for i in 2:
				if int(b.claws[i]) > 0 and p.distance_to(claw_pos(b, i)) <= SCORP_CLAW_R * sc * u + br:
					b.claws[i] = int(b.claws[i]) - 1
					b.flash = 0.06
					if int(b.claws[i]) <= 0:
						ev.append({"kind": "part", "pos": claw_pos(b, i), "color": color_of(b)})
						return "part"
					return "hit"
			if int(b.sting) > 0:
				var open := stinger_open(b)
				var sp := stinger_pos(b)
				if p.distance_to(sp) <= (STINGER_OUT_R if open else STINGER_R) * sc * u + br:
					if not open:
						return "block"
					b.sting = int(b.sting) - 1
					b.flash = 0.06
					if int(b.sting) <= 0:
						ev.append({"kind": "part", "pos": sp, "color": Color(1.0, 0.9, 0.4)})
						return "part"
					return "hit"
				var pts := tail_points(b)
				for k in range(1, pts.size() - 1):
					if p.distance_to(pts[k]) <= 0.4 * sc * u + br:
						return "block"
			if p.distance_to(b.pos) <= SCORP_HEAD * sc * u + br:
				if claws_left(b) > 0 or int(b.sting) > 0:
					return "block"
				return _hurt(b, 1, ev)
			return ""
		"lord":
			if p.distance_to(b.pos) <= LORD_R * sc * u + br:
				return _hurt(b, 1, ev)
			return ""
		"titan":
			for i in (b.turrets as Array).size():
				if int(b.turrets[i]) > 0 and p.distance_to(turret_pos(b, i)) <= TITAN_TURRET_R * sc * u + br:
					b.turrets[i] = int(b.turrets[i]) - 1
					b.flash = 0.06
					if int(b.turrets[i]) <= 0:
						ev.append({"kind": "part", "pos": turret_pos(b, i), "color": color_of(b)})
						return "part"
					return "hit"
			if p.distance_to(b.pos) <= TITAN_R * sc * u + br:
				for h in b.turrets:
					if int(h) > 0:
						return "block"
				return _hurt(b, 1, ev)
			return ""
		"watcher":
			if p.distance_to(b.pos) <= WATCHER_EYE * sc * u + br:
				if str(b.state) == "watch":
					return "block"
				return _hurt(b, 2 if str(b.state) == "daze" else 1, ev)
			return ""
		"warden":
			for p2 in b.pylons:
				if int(p2.hp) > 0 and p.distance_to(p2.pos) <= pylon_r(b) + br:
					p2.hp = int(p2.hp) - 1
					p2.flash = 0.06
					if int(p2.hp) <= 0:
						ev.append({"kind": "part", "pos": p2.pos, "color": Color(0.6, 0.9, 1.0)})
						return "part"
					return "hit"
			if b.shield and p.distance_to(b.pos) <= shield_r(b) + br:
				return "block"
			if p.distance_to(b.pos) <= WARDEN_R * sc * u + br:
				return _hurt(b, 1, ev)
			return ""
	return ""

static func _hurt(b: Dictionary, n: int, _ev: Array) -> String:
	b.hp = maxi(0, int(b.hp) - n)
	b.flash = 0.06
	return "hit"

## Damage from a bomb, a familiar or a blast: armour first, like bullets
## would. `at` / `reach` say where it struck: the Warden's shield takes
## nothing, its pylons only what lands near one (a bomb reaches the pylon
## nearest you).
static func damage(b: Dictionary, n: int, at: Vector2 = Vector2.INF, reach: float = INF) -> void:
	if float(b.warm) > 0.0:
		return
	if b.kind == "warden" and b.shield:
		var best: Dictionary = {}
		var best_d := INF
		for p in b.pylons:
			if int(p.hp) <= 0:
				continue
			var d: float = 0.0 if at == Vector2.INF else (p.pos as Vector2).distance_to(at)
			if d < best_d:
				best_d = d
				best = p
		if not best.is_empty() and best_d <= reach:
			best.hp = maxi(0, int(best.hp) - n)
			best.flash = 0.08
		return
	for i in n:
		match b.kind:
			"queen":
				var hit := false
				for ri in range((b.rings as Array).size() - 1, -1, -1):
					var ring: Dictionary = b.rings[ri]
					for k in (ring.plates as Array).size():
						if int(ring.plates[k]) > 0:
							ring.plates[k] = int(ring.plates[k]) - 1
							hit = true
							break
					if hit:
						break
				if not hit:
					b.hp = maxi(0, int(b.hp) - 1)
			"serpent":
				var tail: int = b.segs.size() - 1
				if tail >= 0:
					b.seg_hp[tail] = int(b.seg_hp[tail]) - 1
					if int(b.seg_hp[tail]) <= 0:
						b.segs.remove_at(tail)
						b.seg_hp.remove_at(tail)
				else:
					b.hp = maxi(0, int(b.hp) - 1)
			"scorpion":
				if int(b.claws[0]) > 0:
					b.claws[0] = int(b.claws[0]) - 1
				elif int(b.claws[1]) > 0:
					b.claws[1] = int(b.claws[1]) - 1
				elif int(b.sting) > 0:
					b.sting = int(b.sting) - 1
				else:
					b.hp = maxi(0, int(b.hp) - 1)
			"titan":
				var hit := false
				for k in (b.turrets as Array).size():
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
	var sc := _sc(b)
	match b.kind:
		"queen":
			return p.distance_to(b.pos) <= body_radius(b) - 0.05 * sc * u + pr
		"serpent":
			if p.distance_to(b.pos) <= 0.9 * sc * u + pr:
				return true
			for s in b.segs:
				if p.distance_to(s) <= SERPENT_SEG_R * sc * u + pr:
					return true
			return false
		"scorpion":
			if p.distance_to(b.pos) <= SCORP_HEAD * sc * u + pr:
				return true
			for i in 2:
				if int(b.claws[i]) > 0 and p.distance_to(claw_pos(b, i)) <= SCORP_CLAW_R * sc * u + pr:
					return true
			var pts := tail_points(b)
			for k in range(1, pts.size()):
				if p.distance_to(pts[k]) <= 0.42 * sc * u + pr:
					return true
			return false
		"lord":
			return p.distance_to(b.pos) <= LORD_R * sc * u + pr
		"titan":
			if p.distance_to(b.pos) <= TITAN_R * sc * u + pr:
				return true
			for i in (b.turrets as Array).size():
				if int(b.turrets[i]) > 0 and p.distance_to(turret_pos(b, i)) <= TITAN_TURRET_R * sc * u + pr:
					return true
		"watcher":
			return p.distance_to(b.pos) <= WATCHER_EYE * sc * u + pr
		"warden":
			for p2 in b.pylons:
				if int(p2.hp) > 0 and p.distance_to(p2.pos) <= pylon_r(b) + pr:
					return true
			return p.distance_to(b.pos) <= (shield_r(b) if b.shield else WARDEN_R * sc * u) + pr
	return false

## The point worth shooting at (familiars aim here): nearest to `from` when
## it matters (the Warden's pylons).
static func target_point(b: Dictionary, from: Vector2 = Vector2.INF) -> Vector2:
	match b.kind:
		"serpent":
			if not b.segs.is_empty():
				return b.segs[b.segs.size() - 1]
		"scorpion":
			for i in 2:
				if int(b.claws[i]) > 0:
					return claw_pos(b, i)
			if int(b.sting) > 0:
				return stinger_pos(b)
		"titan":
			for i in (b.turrets as Array).size():
				if int(b.turrets[i]) > 0:
					return turret_pos(b, i)
		"warden":
			if b.shield:
				var best: Vector2 = b.pos
				var best_d := INF
				for p in b.pylons:
					if int(p.hp) <= 0:
						continue
					var d: float = 0.0 if from == Vector2.INF else (p.pos as Vector2).distance_to(from)
					if d < best_d:
						best_d = d
						best = p.pos
				return best
	return b.pos
