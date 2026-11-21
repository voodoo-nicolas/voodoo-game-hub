extends RefCounted

## Ancient Assassins: two assassins stand on rock islands across a lagoon in
## the ruins of an old-world harbour and take turns throwing at each other --
## javelin, throwing axe, chakram. Hold, drag to aim (left / right and the
## elevation), release. Gravity bends the arc, the crosswind pushes it sideways
## (more for light weapons). Head ×2, body ×1, legs ×0.6.
## Pure simulation in metres (x = sideways, y = up, z = from fighter 0 towards
## fighter 1), no Nodes. The game draws it in 3D (aa_world.gd).
##
## Online play: both phones run the same throw from the same whole-number aim
## (tenths of a degree), with fixed physics ticks and the wind of every turn
## from the match seed, so the two copies agree; the host's state wins if
## they ever don't (see snapshot()).

const DT := 1.0 / 120.0
## Hit tests per tick (a 25 m/s throw moves 0.2 m a tick; a head is 0.24 m across).
const SUB := 3
const MAX_HP := 100
## Crosswind: sideways acceleration in m/s², times the weapon's "wind" factor.
const WIND_MAX := 2.0
## The assassins (Quaternius' female base, 1.78 m): hit zones, from the feet.
const HEAD_Y := 1.64
const HEAD_R := 0.125
const BODY_Y := [0.94, 1.50]
const BODY_R := 0.23
const LEGS_R := 0.17
const HAND_Y := 1.55
const ZONE_MULT := {"head": 2.0, "body": 1.0, "legs": 0.6}
## speed m/s, gravity, wind factor, damage, ammo (-1 = unlimited).
const WEAPONS := [
	{"name": "Javelin", "speed": 22.0, "g": 9.8, "wind": 1.0, "dmg": 34, "ammo": -1},
	{"name": "Throwing Axe", "speed": 19.0, "g": 9.8, "wind": 0.45, "dmg": 46, "ammo": 2},
	{"name": "Chakram", "speed": 25.0, "g": 7.0, "wind": 1.6, "dmg": 26, "ammo": 3},
]
## Map styles: 0 = lagoon, 1 = ruins (columns in the way), 2 = cliffs (a rock to throw over).
const STYLES := 3
const PITCH_RANGE := [-10.0, 80.0]
const YAW_RANGE := [-35.0, 35.0]

var islands: Array = []        # {"x", "z", "r", "top"}: standing ground (flat-topped rock)
var blocks: Array = []         # {"x", "z", "r", "top", "kind": "column"|"rock"}: in the way, from the water up
var style: int = 0
var fighters: Array = []       # {"x", "y" (feet), "z", "hp", "char", "ammo": [..], "weapon"}
var aim: Array = []            # per fighter: [yaw tenths of a degree (+ = to her right), pitch tenths]
var turn: int = 0
var winner: int = -1
var seed_: int = 0
var throws: int = 0
var wind: float = 0.0          # + pushes towards +x
var wind_max: float = WIND_MAX
var shot: Dictionary = {}      # {"p", "prev", "v", "w", "owner", "age", "trail"}
var last_hit: Dictionary = {}
var rng := RandomNumberGenerator.new()
var acc: float = 0.0

## opts: "dist" (metres between the two, default 22-30), "style", "wind_max",
## "hp" ([a, b]), "chars" ([a, b]).
func reset(p_seed: int = -1, opts: Dictionary = {}) -> void:
	if p_seed < 0:
		rng.randomize()
		p_seed = rng.randi() % 1000000000
	seed_ = p_seed
	rng.seed = seed_
	style = int(opts.get("style", rng.randi() % STYLES))
	wind_max = float(opts.get("wind_max", WIND_MAX))
	var dist: float = float(opts.get("dist", rng.randf_range(22.0, 30.0)))
	var hp: Array = opts.get("hp", [MAX_HP, MAX_HP])
	var chars: Array = opts.get("chars", [0, 1])
	var lat := snappedf(rng.randf_range(-4.0, 4.0), 0.1)
	var h0 := snappedf(rng.randf_range(0.8, 2.2), 0.1)
	var h1 := snappedf(rng.randf_range(0.8, 2.6) + (1.8 if style == 2 else 0.0), 0.1)
	islands = [{"x": 0.0, "z": 0.0, "r": 3.2, "top": h0}, {"x": lat, "z": snappedf(dist, 0.1), "r": 3.0, "top": h1}]
	blocks = []
	match style:
		1:
			for k in 2 + rng.randi() % 2:
				var u := rng.randf_range(0.35, 0.7)
				blocks.append({"x": snappedf(lat * u + rng.randf_range(-2.5, 2.5), 0.1), "z": snappedf(dist * u, 0.1),
					"r": 0.42, "top": snappedf(rng.randf_range(3.0, 5.5), 0.1), "kind": "column"})
		2:
			var u := rng.randf_range(0.45, 0.6)
			blocks.append({"x": snappedf(lat * u + rng.randf_range(-1.0, 1.0), 0.1), "z": snappedf(dist * u, 0.1),
				"r": snappedf(rng.randf_range(1.6, 2.4), 0.1), "top": snappedf(rng.randf_range(3.5, 5.0), 0.1), "kind": "rock"})
		_:
			if rng.randf() < 0.5:
				blocks.append({"x": snappedf(lat * 0.5 + rng.randf_range(-3.0, 3.0), 0.1), "z": snappedf(dist * rng.randf_range(0.4, 0.6), 0.1),
					"r": 0.42, "top": snappedf(rng.randf_range(2.5, 4.0), 0.1), "kind": "column"})
	fighters = []
	aim = []
	for i in 2:
		var ammo: Array = []
		for wpn in WEAPONS:
			ammo.append(int(wpn.ammo))
		var isl: Dictionary = islands[i]
		fighters.append({"x": isl.x, "y": isl.top, "z": isl.z, "hp": int(hp[i]), "char": int(chars[i]), "ammo": ammo, "weapon": 0})
		aim.append([0, 150])
	turn = 0
	winner = -1
	throws = 0
	shot = {}
	last_hit = {}
	acc = 0.0
	wind = wind_for(0)

## Wind for the n-th throw of the match: the same on every phone (from the seed).
func wind_for(n: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = seed_ * 31 + n * 7919 + 17
	var v := r.randf_range(-1.0, 1.0)
	v = signf(v) * pow(absf(v), 0.8)
	return snappedf(v * wind_max, 0.1)

func is_over() -> bool:
	return winner != -1

func feet(i: int) -> Vector3:
	var f: Dictionary = fighters[i]
	return Vector3(f.x, f.y, f.z)

## Level direction from fighter i towards the other one.
func forward(i: int) -> Vector3:
	var d := feet(1 - i) - feet(i)
	d.y = 0.0
	return d.normalized()

# ---------- aiming ----------

func yaw_of(i: int) -> float:
	return aim[i][0] / 10.0

func angle_of(i: int) -> float:
	return aim[i][1] / 10.0

## yaw (deg, + = to the thrower's right), pitch (deg, up). Kept in tenths, so
## the same aim is the same number on both phones.
func set_aim(i: int, yaw: float, pitch: float) -> void:
	aim[i] = [int(roundf(clampf(yaw, YAW_RANGE[0], YAW_RANGE[1]) * 10.0)), int(roundf(clampf(pitch, PITCH_RANGE[0], PITCH_RANGE[1]) * 10.0))]

## The throw's direction for an aim.
func direction(i: int, yaw: float, pitch: float) -> Vector3:
	var fw := forward(i)
	var right := fw.cross(Vector3.UP).normalized()
	var y := deg_to_rad(yaw)
	var flat := fw * cos(y) + right * sin(y)
	var p := deg_to_rad(pitch)
	return (flat * cos(p) + Vector3.UP * sin(p)).normalized()

## Where the throw leaves the hand (over the right shoulder).
func hand(i: int) -> Vector3:
	var fw := forward(i)
	var right := fw.cross(Vector3.UP).normalized()
	return feet(i) + Vector3(0, HAND_Y, 0) + right * 0.22 + fw * 0.3

func pick_weapon(i: int, w: int) -> bool:
	if w < 0 or w >= WEAPONS.size() or fighters[i].ammo[w] == 0:
		return false
	fighters[i].weapon = w
	return true

func cycle_weapon(i: int) -> void:
	var f: Dictionary = fighters[i]
	for k in WEAPONS.size():
		var w: int = (f.weapon + 1 + k) % WEAPONS.size()
		if f.ammo[w] != 0:
			f.weapon = w
			return

# ---------- throwing ----------

func _new_shot(i: int, w: int) -> Dictionary:
	var p := hand(i)
	var v := direction(i, yaw_of(i), angle_of(i)) * float(WEAPONS[w].speed)
	return {"p": p, "prev": p, "v": v, "w": w, "owner": i, "age": 0.0}

func throw() -> void:
	var f: Dictionary = fighters[turn]
	var w: int = f.weapon
	if f.ammo[w] == 0:
		w = 0
	if f.ammo[w] > 0:
		f.ammo[w] -= 1
	shot = _new_shot(turn, w)
	shot["trail"] = [shot.p]
	acc = 0.0
	last_hit = {}
	throws += 1
	if f.ammo[f.weapon] == 0:
		f.weapon = 0

## Whole DT ticks only (left-over time waits), so a throw lands in the same spot
## at any frame rate. Returns what happened: {"kind": "hit", "f", "zone", "dmg", "p"}
## · {"kind": "stick", "p", "surface": "ground"|"stone"|"water"} · {"kind": "out"}.
func step(dt: float) -> Array:
	var out: Array = []
	acc = minf(acc + dt, 0.25)
	while acc >= DT and not shot.is_empty():
		acc -= DT
		var res := _tick(shot, true)
		if not res.is_empty():
			out.append(res)
			shot = {}
	return out

func _tick(s: Dictionary, real: bool) -> Dictionary:
	var wpn: Dictionary = WEAPONS[s.w]
	s.prev = s.p
	s.v += Vector3(wind * float(wpn.wind), -float(wpn.g), 0.0) * DT
	s.p += s.v * DT
	s.age += DT
	if real:
		var tr: Array = s.trail
		if (tr[tr.size() - 1] as Vector3).distance_to(s.p) > 0.4:
			tr.append(s.p)
			if tr.size() > 60:
				tr.pop_front()
	var p: Vector3 = s.p
	if absf(p.x) > 60.0 or p.z < -20.0 or p.z > 90.0:
		return {"kind": "out"}
	for k in SUB:
		var q: Vector3 = (s.prev as Vector3).lerp(p, float(k + 1) / SUB)
		var r := _hit_at(q, s, wpn, real)
		if not r.is_empty():
			return r
	return {}

func _hit_at(q: Vector3, s: Dictionary, wpn: Dictionary, real: bool) -> Dictionary:
	for i in fighters.size():
		var f: Dictionary = fighters[i]
		if absf(q.x - f.x) > 0.5 or absf(q.z - f.z) > 0.5 or (i == s.owner and s.age < 0.25) or f.hp <= 0:
			continue
		var zone := zone_at(i, q)
		if zone != "":
			var dmg := int(roundf(float(wpn.dmg) * float(ZONE_MULT[zone])))
			if real:
				f.hp = maxi(0, f.hp - dmg)
				last_hit = {"f": i, "zone": zone, "dmg": dmg}
			return {"kind": "hit", "f": i, "zone": zone, "dmg": dmg, "p": q}
	for b in blocks:
		if q.y <= b.top and Vector2(q.x - b.x, q.z - b.z).length() <= b.r:
			return {"kind": "stick", "p": q, "surface": "stone"}
	for isl in islands:
		if q.y <= isl.top and Vector2(q.x - isl.x, q.z - isl.z).length() <= isl.r:
			return {"kind": "stick", "p": Vector3(q.x, isl.top, q.z), "surface": "ground"}
	if q.y <= 0.0:
		return {"kind": "stick", "p": Vector3(q.x, 0.0, q.z), "surface": "water"}
	return {}

## "head", "body", "legs" or "" for a point near fighter i.
func zone_at(i: int, q: Vector3) -> String:
	var f: Dictionary = fighters[i]
	var y: float = q.y - f.y
	var d := Vector2(q.x - f.x, q.z - f.z).length()
	if Vector2(d, y - HEAD_Y).length() <= HEAD_R:
		return "head"
	if y >= BODY_Y[0] and y < BODY_Y[1] and d <= BODY_R:
		return "body"
	if y >= 0.0 and y < BODY_Y[0] and d <= LEGS_R:
		return "legs"
	return ""

## After a throw lands: someone may be down, else the other side's turn with the next wind.
func settle() -> void:
	shot = {}
	for i in fighters.size():
		if fighters[i].hp <= 0:
			winner = 1 - i
			return
	turn = 1 - turn
	wind = wind_for(throws)

# ---------- the computer ----------

## Where a throw would end (no side effects): {"p": Vector3, "f", "zone", "out", "surface"}.
func predict(i: int, yaw: float, pitch: float, w: int) -> Dictionary:
	var keep: Array = aim[i]
	set_aim(i, yaw, pitch)
	var s := _new_shot(i, w)
	aim[i] = keep
	var res := {}
	for n in 1200:
		res = _tick(s, false)
		if not res.is_empty():
			break
	if res.is_empty() or res.kind == "out":
		return {"p": s.p, "f": -1, "zone": "", "out": true, "surface": ""}
	return {"p": res.p, "f": int(res.get("f", -1)), "zone": str(res.get("zone", "")), "out": false, "surface": str(res.get("surface", ""))}

## The path of fighter i's current aim (🦅 Eagle Eye, wind included): a point every few ticks.
func path(i: int, w: int) -> PackedVector3Array:
	var s := _new_shot(i, w)
	var pts := PackedVector3Array([s.p])
	for n in 1200:
		var res := _tick(s, false)
		if n % 4 == 0 or not res.is_empty():
			pts.append(s.p)
		if not res.is_empty():
			break
	return pts

## The computer's throw, a slice per call so the screen never stalls:
## plan = cpu_plan(i, level); call cpu_think(plan) once per frame until true;
## then plan.yaw / plan.pitch / plan.weapon. Level 0..3 = Easy..Expert.
## Its aim sharpens over the match (the first throw is a sighter).
func cpu_plan(i: int, level: int) -> Dictionary:
	var j := 1 - i
	var want_head := level >= 2 and rng.randf() < (0.35 if level == 2 else 0.6)
	var weapon := 0
	var ammo: Array = fighters[i].ammo
	if level >= 1:
		if absf(wind) >= 1.2 and ammo[1] != 0 and rng.randf() < 0.7:
			weapon = 1
		elif absf(wind) <= 0.4 and ammo[2] != 0 and rng.randf() < 0.4:
			weapon = 2
		elif ammo[1] != 0 and rng.randf() < 0.15 * level:
			weapon = 1
	var t := feet(j) + Vector3(0, HEAD_Y if want_head else 1.2, 0)
	return {"i": i, "j": j, "level": level, "weapon": weapon, "target": t, "yaw": 0.0, "pitch": 15.0,
		"round": 0, "arc": 0, "best": {"yaw": 0.0, "pitch": 15.0, "d": INF}}

func cpu_think(plan: Dictionary) -> bool:
	var i: int = plan.i
	var best: Dictionary = plan.best
	if plan.round < 6:
		# One round: bisect the elevation for distance, then correct the yaw for the drift.
		var lo: float = -5.0 if plan.arc == 0 else 45.0
		var hi: float = 45.0 if plan.arc == 0 else 78.0
		var fw := forward(i)
		var right := fw.cross(Vector3.UP).normalized()
		var tgt: Vector3 = plan.target
		var r := {}
		for n in 9:
			var mid := (lo + hi) / 2.0
			r = predict(i, plan.yaw, mid, plan.weapon)
			var d := _miss(r, plan.j, tgt)
			if d < best.d:
				best.yaw = plan.yaw
				best.pitch = mid
				best.d = d
			if r.f == plan.j and r.zone != "legs":
				break
			var along: float = ((r.p as Vector3) - hand(i)).dot(fw) - (tgt - hand(i)).dot(fw)
			var short: bool = along < 0.0 or r.surface == "stone"
			if plan.arc == 0:
				if short:
					lo = mid
				else:
					hi = mid
			else:
				if short:
					hi = mid
				else:
					lo = mid
			plan.pitch = mid
		var side: float = ((r.p as Vector3) - tgt).dot(right)
		var dist: float = maxf(2.0, (tgt - hand(i)).dot(fw))
		plan.yaw = clampf(plan.yaw - rad_to_deg(atan2(side, dist)), YAW_RANGE[0], YAW_RANGE[1])
		plan.round += 1
		if plan.round == 3 and best.d > 1.5:
			plan.arc = 1   # the low throw is blocked: lob it
			plan.yaw = 0.0
		return false
	# Degrees of deliberate error (yaw, pitch): a body is under 1° wide at 25 m.
	var noise: Array = [[2.2, 2.6], [1.0, 1.2], [0.5, 0.6], [0.22, 0.28]][clampi(plan.level, 0, 3)]
	@warning_ignore("integer_division")
	var mine := (throws + (1 if i == 0 else 0)) / 2
	var sharpen := maxf(0.55, 1.35 - 0.2 * mine)
	plan.yaw = best.yaw + rng.randf_range(-1.0, 1.0) * noise[0] * sharpen
	plan.pitch = best.pitch + rng.randf_range(-1.0, 1.0) * noise[1] * sharpen
	return true

func cpu_aim(i: int, level: int) -> Dictionary:
	var plan := cpu_plan(i, level)
	while not cpu_think(plan):
		pass
	return {"yaw": plan.yaw, "pitch": plan.pitch, "weapon": plan.weapon}

func _miss(r: Dictionary, j: int, target: Vector3) -> float:
	if r.f == j:
		return 0.0 if r.zone == "head" else target.distance_to(r.p) * 0.2
	if r.f >= 0:
		return 500.0
	return target.distance_to(r.p) + (20.0 if r.out else 0.0)

# ---------- save / load / online ----------

func snapshot() -> Dictionary:
	var fs: Array = []
	for f in fighters:
		fs.append({"x": f.x, "y": f.y, "z": f.z, "hp": f.hp, "char": f.char, "ammo": (f.ammo as Array).duplicate(), "weapon": f.weapon})
	return {"islands": islands.duplicate(true), "blocks": blocks.duplicate(true), "style": style, "fighters": fs,
		"turn": turn, "winner": winner, "seed": seed_, "throws": throws, "wind": wind, "wind_max": wind_max}

func to_dict() -> Dictionary:
	var d := snapshot()
	d["aim"] = aim.duplicate(true)
	return d

func from_dict(d: Dictionary) -> bool:
	if not (d.get("islands") is Array) or (d.islands as Array).size() != 2 or not (d.get("fighters") is Array) or (d.fighters as Array).size() != 2:
		return false
	islands = []
	for isl in d.islands:
		islands.append({"x": float(isl.x), "z": float(isl.z), "r": float(isl.r), "top": float(isl.top)})
	blocks = []
	for b in d.get("blocks", []):
		blocks.append({"x": float(b.x), "z": float(b.z), "r": float(b.r), "top": float(b.top), "kind": str(b.get("kind", "column"))})
	style = int(d.get("style", 0))
	fighters = []
	for f in d.fighters:
		var ammo: Array = []
		for a in f.ammo:
			ammo.append(int(a))
		fighters.append({"x": float(f.x), "y": float(f.y), "z": float(f.z), "hp": int(f.hp), "char": int(f.char), "ammo": ammo, "weapon": int(f.weapon)})
	turn = int(d.get("turn", 0))
	winner = int(d.get("winner", -1))
	seed_ = int(d.get("seed", 0))
	throws = int(d.get("throws", 0))
	wind = float(d.get("wind", 0.0))
	wind_max = float(d.get("wind_max", WIND_MAX))
	if d.get("aim") is Array and (d.aim as Array).size() == 2:
		aim = [[int(d.aim[0][0]), int(d.aim[0][1])], [int(d.aim[1][0]), int(d.aim[1][1])]]
	elif aim.size() != 2:
		aim = [[0, 150], [0, 150]]
	shot = {}
	acc = 0.0
	return true
