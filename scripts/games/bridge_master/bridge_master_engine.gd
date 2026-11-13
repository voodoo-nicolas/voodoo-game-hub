extends RefCounted

## Bridge Master engine: pure logic, no Nodes (headless-testable).
## - Levels: 300, generated from the level number (deterministic). Budgets and
##   the "engineer's design" cost come from bridge_master_levels.json, made by
##   tools/bridge_master_levels.gd, which proves every level solvable by
##   simulating a reference bridge across it.
## - A design is an Array of members [ax, ay, bx, by, material] on a 1 m grid
##   (y up, the left cliff edge at x = 0, the right one at x = W).
## - Physics: pin-jointed truss, XPBD with small fixed substeps. Members carry
##   axial force only; a member breaks when its force passes its strength.
##   Cables only pull. The vehicle rides the road members and loads their joints.

const LEVEL_COUNT := 300
const PER_CHAPTER := 30
const CHAPTERS := ["Green Valley", "River Bend", "Red Rocks", "Pine Gorge", "Dry Canyon",
	"Sunset Mesa", "Twin Falls", "Eagle Pass", "Deep Ravine", "Great Divide"]
## Backdrop per chapter: 0 forest gorge, 1 desert canyon, 2 sunset mesa.
const CHAPTER_ART := [0, 0, 1, 0, 1, 2, 0, 2, 1, 2]
const LEVELS_PATH := "res://scripts/games/bridge_master/bridge_master_levels.json"

const G := 10.0
const H := 1.0 / 600.0      # physics substep (s)
const SPEED := 3.0          # vehicle speed (m/s)
## Front wheel's start, metres before the left edge (owner 2026-11-13: start further back; was -1).
const START_X := -3.0
const START_DELAY := 1.0    # the bridge settles before the vehicle drives on
const GRAVITY_RAMP := 0.5
const DAMP := 1.5           # velocity damping per second

## cost $ per metre, mass t per metre, str = breaking force (kN), ea = stiffness (kN),
## max = longest piece (m), deck = vehicles drive on it, pull = cable (tension only),
## unlock = first level it is available.
const MATS := {
	"road": {"name": "Road", "cost": 120, "mass": 0.10, "str": 40.0, "ea": 6000.0, "max": 2.3, "deck": true, "pull": false, "unlock": 1},
	"wood": {"name": "Wood", "cost": 60, "mass": 0.04, "str": 30.0, "ea": 5000.0, "max": 3.2, "deck": false, "pull": false, "unlock": 1},
	"steel": {"name": "Steel", "cost": 160, "mass": 0.07, "str": 90.0, "ea": 15000.0, "max": 4.2, "deck": false, "pull": false, "unlock": 16},
	"cable": {"name": "Cable", "cost": 40, "mass": 0.015, "str": 70.0, "ea": 6000.0, "max": 8.0, "deck": false, "pull": true, "unlock": 46},
	"sroad": {"name": "Steel Road", "cost": 260, "mass": 0.14, "str": 110.0, "ea": 15000.0, "max": 2.3, "deck": true, "pull": false, "unlock": 91},
}
const MAT_ORDER := ["road", "sroad", "wood", "steel", "cable"]
## mass t, base = axle distance m, len/h = drawn size m.
const VEHICLES := {
	"car": {"name": "Car", "mass": 1.0, "base": 1.6, "len": 2.6, "h": 1.1},
	"van": {"name": "Van", "mass": 1.8, "base": 2.0, "len": 3.0, "h": 1.6},
	"bus": {"name": "Bus", "mass": 3.0, "base": 3.0, "len": 4.4, "h": 1.8},
	"truck": {"name": "Truck", "mass": 4.5, "base": 3.2, "len": 4.6, "h": 2.0},
	"heavy": {"name": "Heavy Truck", "mass": 7.0, "base": 3.6, "len": 5.2, "h": 2.2},
}
const VEHICLE_ORDER := ["car", "van", "bus", "truck", "heavy"]
const SPAN_BY_CHAPTER := [4, 6, 8, 8, 10, 10, 12, 12, 14, 14]
const VEHICLE_BY_CHAPTER := [0, 0, 1, 1, 2, 2, 3, 3, 3, 4]

static var _table: Dictionary = {}

# ---------- levels ----------

static func chapter_of(n: int) -> int:
	return clampi((n - 1) / PER_CHAPTER, 0, CHAPTERS.size() - 1)

static func mats_for(n: int) -> Array:
	var out: Array = []
	for k in MAT_ORDER:
		if n >= int(MATS[k].unlock):
			out.append(k)
	return out

## The level layout from its number alone (budget not included).
## Owner 2026-11-13: "everything is the same" in the first levels. Now every level varies:
## the span drifts up through each chapter with a random step either way, cliffs at different
## heights from level 6, lower bolts and river pillars from chapter 1, a heavier vehicle late in
## a chapter, and the backdrop changes every level (art_of / flip_of / tint_of).
## Levels 1-2 are the lesson (road alone carries a car over 4 m); from level 3 on, no level can
## be crossed with a plain road deck.
## w_over: the span the level tool settled on (it widens a level a plain deck could cross).
static func generate(n: int, w_over: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 7919 + 3
	var c := chapter_of(n)
	var i := (n - 1) % PER_CHAPTER
	var lo: int = SPAN_BY_CHAPTER[c]
	var hi: int = SPAN_BY_CHAPTER[mini(c + 1, SPAN_BY_CHAPTER.size() - 1)] + 2
	var w: int = lo + roundi(float(hi - lo) * i / (PER_CHAPTER - 1) / 2.0) * 2
	w += [-2, 0, 0, 2][rng.randi() % 4]
	w = clampi(w, 4, 18)
	var dh := 0
	if n >= 6 and rng.randf() < 0.35 + 0.03 * c:
		var r := 1 if c == 0 else 2
		dh = rng.randi_range(-r, r)
	var veh: int = VEHICLE_BY_CHAPTER[c]
	if i < 8 and veh > 0 and rng.randf() < 0.5:
		veh -= 1
	if i >= 12 and veh < 4 and rng.randf() < 0.2 + 0.015 * i:
		veh += 1
	if n <= 2:
		w = 4
		dh = 0
		veh = 0
	elif w == 4 and veh == 0:
		# A car on 4 m of plain road always makes it: give it something to solve.
		if rng.randf() < 0.5:
			veh = 1
		else:
			w = 6
	if w_over > 0:
		w = w_over
	var water := -clampi(w / 3 + 3, 4, 8)
	var anchors: Array = [[0, 0], [w, dh]]
	var low_p := 0.0 if n < 4 else 0.3 + 0.04 * c
	if rng.randf() < low_p:
		anchors.append([0, -2])
	if rng.randf() < low_p:
		anchors.append([w, dh - 2])
	var pier = null
	if n >= 8 and w >= 8 and rng.randf() < 0.25 + 0.05 * c:
		var px: int = (w / 2) & ~1
		pier = [px, -2]
		anchors.append([px, -2])
	return {"n": n, "w": w, "dh": dh, "water": water, "anchors": anchors, "pier": pier,
		"vehicle": VEHICLE_ORDER[veh], "mats": mats_for(n), "chapter": c,
		"budget": 0, "ref": 0}

## Backdrop for a level (0 forest, 1 desert, 2 mesa): the chapter's own art, with the other two
## mixed in, so neighbouring levels never look alike.
static func art_of(n: int) -> int:
	var c := chapter_of(n)
	var i := (n - 1) % PER_CHAPTER
	return (int(CHAPTER_ART[c]) + [0, 0, 1, 0, 2, 0][(i / 2) % 6]) % 3

## Every other level shows its backdrop mirrored.
static func flip_of(n: int) -> bool:
	return n % 2 == 0

## Light of day: morning, noon, golden hour, dusk (classic skin).
const TINTS := [Color(1.0, 0.97, 0.92), Color(1, 1, 1), Color(1.0, 0.86, 0.7), Color(0.78, 0.8, 1.0)]
static func tint_of(n: int) -> Color:
	return TINTS[((n - 1) / 3) % TINTS.size()]

static func load_table() -> void:
	if not _table.is_empty() or not FileAccess.file_exists(LEVELS_PATH):
		return
	var f := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_table = d

## A playable level: layout + budget, engineer's cost and vehicle from the table.
static func level(n: int) -> Dictionary:
	load_table()
	var row = _table.get(str(n))
	var lv := generate(n, int(row.get("w", 0)) if row is Dictionary else 0)
	if row is Dictionary:
		lv.budget = int(row.get("budget", 0))
		lv.ref = int(row.get("ref", 0))
		lv.vehicle = str(row.get("veh", lv.vehicle))
	if lv.budget <= 0:
		lv.budget = 400 * lv.w + 1000
	return lv

static func top_limit(lv: Dictionary) -> int:
	return 6 + maxi(0, int(lv.dh))

static func is_anchor(lv: Dictionary, x: int, y: int) -> bool:
	for a in lv.anchors:
		if int(a[0]) == x and int(a[1]) == y:
			return true
	return false

## May a joint sit at (x, y)? Not inside rock, not in the water, not off screen.
static func can_place(lv: Dictionary, x: int, y: int) -> bool:
	if is_anchor(lv, x, y):
		return true
	var w: int = lv.w
	if x < -3 or x > w + 3 or y > top_limit(lv) or y <= int(lv.water):
		return false
	if x <= 0 and y <= 0:
		return false
	if x >= w and y <= int(lv.dh):
		return false
	if lv.pier != null and x == int(lv.pier[0]) and y <= int(lv.pier[1]):
		return false
	return true

# ---------- designs ----------

static func member_len(m: Array) -> float:
	return Vector2(float(m[2]) - float(m[0]), float(m[3]) - float(m[1])).length()

static func member_cost(m: Array) -> int:
	return int(round(member_len(m) * float(MATS[str(m[4])].cost)))

static func design_cost(design: Array) -> int:
	var c := 0
	for m in design:
		c += member_cost(m)
	return c

static func same_member(m: Array, ax: int, ay: int, bx: int, by: int) -> bool:
	return (int(m[0]) == ax and int(m[1]) == ay and int(m[2]) == bx and int(m[3]) == by) \
		or (int(m[0]) == bx and int(m[1]) == by and int(m[2]) == ax and int(m[3]) == ay)

## Why a new member may not be added ("" = fine).
static func check_member(lv: Dictionary, design: Array, ax: int, ay: int, bx: int, by: int, mat: String) -> String:
	if ax == bx and ay == by:
		return "same"
	if not can_place(lv, ax, ay) or not can_place(lv, bx, by):
		return "Can't build there."
	var l := Vector2(bx - ax, by - ay).length()
	if l > float(MATS[mat].max) + 0.001:
		return "Too long for that material."
	for m in design:
		if same_member(m, ax, ay, bx, by):
			return "same"
	return ""

## The longest grid step toward (tx, ty) from (ax, ay) that fits the material.
static func clamp_reach(ax: int, ay: int, tx: float, ty: float, mat: String) -> Vector2i:
	var mx: float = MATS[mat].max
	var best := Vector2i(roundi(tx), roundi(ty))
	if Vector2(best.x - ax, best.y - ay).length() <= mx + 0.001:
		return best
	var dirv := Vector2(tx - ax, ty - ay).normalized()
	var best_d := INF
	best = Vector2i(ax, ay)
	var r := int(ceil(mx))
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var v := Vector2(dx, dy)
			var l := v.length()
			if l < 0.5 or l > mx + 0.001:
				continue
			var off := (Vector2(ax, ay) + dirv * mx).distance_to(Vector2(ax + dx, ay + dy))
			if off < best_d:
				best_d = off
				best = Vector2i(ax + dx, ay + dy)
	return best

## The engineer's bridge used by the level tool: a through truss of height h
## above a road deck in 2 m panels, with a post down to a pier when there is one.
static func ref_design(lv: Dictionary, h: int, chord: String, web: String, road: String) -> Array:
	var w: int = lv.w
	var dh: int = lv.dh
	var d: Array = []
	var deck := func(x: int) -> int: return roundi(float(dh) * x / w)
	var x := 0
	while x < w:
		d.append([x, deck.call(x), x + 2, deck.call(x + 2), road])
		x += 2
	x = 1
	while x < w:
		var ty: int = deck.call(x) + h
		d.append([x, ty, x - 1, deck.call(x - 1), web])
		d.append([x, ty, x + 1, deck.call(x + 1), web])
		if x + 2 < w:
			d.append([x, ty, x + 2, deck.call(x + 2) + h, chord])
		x += 2
	if lv.pier != null:
		var px: int = lv.pier[0]
		d.append([px, deck.call(px), px, int(lv.pier[1]), web])
	for m in d:
		if member_len(m) > float(MATS[str(m[4])].max) + 0.001:
			return []
	return d

# ---------- simulation ----------

var lv: Dictionary
var pos := PackedVector2Array()
var prev := PackedVector2Array()
var vel := PackedVector2Array()
var invm := PackedFloat32Array()
var fixed := PackedByteArray()
var ma := PackedInt32Array()
var mb := PackedInt32Array()
var rest := PackedFloat32Array()
var alpha := PackedFloat32Array()
var strength := PackedFloat32Array()
var pull := PackedByteArray()
var deck := PackedByteArray()
var broken := PackedByteArray()
var force := PackedFloat32Array()   # smoothed axial force, + = tension
var mat_of: Array = []
var t := 0.0
var acc := 0.0
var status := "idle"   # idle | running | win | fail
var reason := ""
var load_mult := 1.0
var veh: Dictionary
var vx := 0.0          # front axle x
var vstate := "wait"   # wait | drive | fall | done
var wheel_y := [0.0, 0.0]
var wheel_m := [-1, -1]
var fall_pos := Vector2.ZERO
var fall_vel := Vector2.ZERO
var fall_rot := 0.0
var max_ratio := 0.0   # highest force/strength seen (for the result screen)

func setup(level_dict: Dictionary, design: Array, mult: float = 1.0) -> void:
	lv = level_dict
	load_mult = mult
	veh = VEHICLES[str(lv.vehicle)]
	pos.clear(); prev.clear(); vel.clear(); invm.clear(); fixed.clear()
	ma.clear(); mb.clear(); rest.clear(); alpha.clear(); strength.clear()
	pull.clear(); deck.clear(); broken.clear(); force.clear(); mat_of.clear()
	var index := {}
	var mass: Array = []
	for a in lv.anchors:
		var k := Vector2i(int(a[0]), int(a[1]))
		index[k] = pos.size()
		pos.append(Vector2(k)); mass.append(0.0); fixed.append(1)
	for m in design:
		var ends := [Vector2i(int(m[0]), int(m[1])), Vector2i(int(m[2]), int(m[3]))]
		for e in ends:
			if not index.has(e):
				index[e] = pos.size()
				pos.append(Vector2(e)); mass.append(0.0); fixed.append(0)
		var a: int = index[ends[0]]
		var b: int = index[ends[1]]
		var mt: Dictionary = MATS[str(m[4])]
		var l := member_len(m)
		ma.append(a); mb.append(b); rest.append(l)
		alpha.append(l / float(mt.ea)); strength.append(float(mt.str))
		pull.append(1 if mt.pull else 0); deck.append(1 if mt.deck else 0)
		broken.append(0); force.append(0.0); mat_of.append(str(m[4]))
		mass[a] += float(mt.mass) * l * 0.5
		mass[b] += float(mt.mass) * l * 0.5
	for i in pos.size():
		prev.append(pos[i]); vel.append(Vector2.ZERO)
		invm.append(0.0 if fixed[i] else 1.0 / maxf(0.02, mass[i]))
	t = 0.0
	acc = 0.0
	status = "running"
	reason = ""
	vx = START_X
	vstate = "wait"
	wheel_y = [0.0, 0.0]
	wheel_m = [-1, -1]
	max_ratio = 0.0

func ground_y(x: float) -> float:
	if x <= 0.0:
		return 0.0
	return float(lv.dh)

## Road under x: [member, y, t] or [] (picks the road nearest the wheel's last height).
func _road_at(x: float, near_y: float) -> Array:
	var best: Array = []
	var bd := INF
	for i in ma.size():
		if not deck[i] or broken[i]:
			continue
		var pa := pos[ma[i]]
		var pb := pos[mb[i]]
		var lo := minf(pa.x, pb.x)
		var hi := maxf(pa.x, pb.x)
		if x < lo or x > hi or hi - lo < 0.05:
			continue
		var tt := (x - pa.x) / (pb.x - pa.x)
		var y := lerpf(pa.y, pb.y, tt)
		var dd := absf(y - near_y)
		if dd < bd:
			bd = dd
			best = [i, y, tt]
	return best

func vehicle_pos() -> Vector2:
	if vstate == "fall":
		return fall_pos
	return Vector2(vx - float(veh.base) * 0.5, (wheel_y[0] + wheel_y[1]) * 0.5)

func vehicle_angle() -> float:
	if vstate == "fall":
		return fall_rot
	return atan2(wheel_y[0] - wheel_y[1], float(veh.base))

## Runs the simulation for dt seconds of game time.
func advance(dt: float) -> void:
	if status == "idle":
		return  # after a win or a fail it keeps running: the vehicle drives off, debris falls
	acc += minf(dt, 0.1)
	while acc >= H:
		acc -= H
		_substep()

func _substep() -> void:
	t += H
	var g := G * minf(1.0, t / GRAVITY_RAMP)
	var n := pos.size()
	# Vehicle loads.
	var loads := {}
	if vstate == "wait" or vstate == "drive":
		if vstate == "wait" and t >= START_DELAY and status == "running":
			vstate = "drive"
		if vstate == "drive":
			vx += SPEED * H
		var base: float = veh.base
		var wheel_force: float = float(veh.mass) * load_mult * g * 0.5
		var xs := [vx, vx - base]
		for k in 2:
			var wx: float = xs[k]
			if wx <= 0.0 or wx >= float(lv.w):
				wheel_y[k] = ground_y(wx)
				wheel_m[k] = -1
				continue
			var r := _road_at(wx, wheel_y[k])
			if r.is_empty() or float(r[1]) < wheel_y[k] - 0.6:
				_start_fall("The road gave way.")
				break
			var y_new: float = r[1]
			if y_new > wheel_y[k] + 0.6:
				_start_fall("The road gave way.")
				break
			wheel_y[k] = y_new
			wheel_m[k] = r[0]
			var mi: int = r[0]
			var tt: float = r[2]
			loads[ma[mi]] = loads.get(ma[mi], 0.0) + wheel_force * (1.0 - tt)
			loads[mb[mi]] = loads.get(mb[mi], 0.0) + wheel_force * tt
		if vstate == "drive":
			if absf(wheel_y[0] - wheel_y[1]) / base > 0.8:
				_start_fall("Too steep for the vehicle.")
			elif vx - base > float(lv.w) + 1.0 and status == "running":
				status = "win"
				vstate = "done"
	elif vstate == "fall":
		fall_vel.y -= g * H
		fall_pos += fall_vel * H
		fall_rot += 1.2 * H
		if fall_pos.y < float(lv.water) - 1.0 and status == "running":
			status = "fail"
	elif vstate == "done":
		vx += SPEED * H
	# Integrate.
	var damp := 1.0 - DAMP * H
	for i in n:
		if invm[i] == 0.0:
			continue
		var v := vel[i] * damp
		v.y -= g * H
		if loads.has(i):
			v.y -= float(loads[i]) * invm[i] * H
		vel[i] = v
		prev[i] = pos[i]
		var p := pos[i] + v * H
		if p.y < float(lv.water) - 4.0:
			p.y = float(lv.water) - 4.0
			vel[i] = Vector2.ZERO
		pos[i] = p
	# Members.
	var h2 := H * H
	for i in ma.size():
		if broken[i]:
			continue
		var a := ma[i]
		var b := mb[i]
		var wa := invm[a]
		var wb := invm[b]
		var w := wa + wb
		if w == 0.0:
			continue
		var d := pos[b] - pos[a]
		var l := d.length()
		if l < 1e-6:
			continue
		var c := l - rest[i]
		if pull[i] and c < 0.0:
			force[i] *= 0.9
			continue
		var dl := -c / (w + alpha[i] / h2)
		var nrm := d / l
		pos[a] -= nrm * dl * wa
		pos[b] += nrm * dl * wb
		var f := -dl / h2
		force[i] = lerpf(force[i], f, 0.05)
		var ratio := absf(force[i]) / strength[i]
		if t > 0.05 and ratio > 1.0:
			broken[i] = 1
		elif ratio > max_ratio:
			max_ratio = ratio
	# Velocities from positions.
	for i in n:
		if invm[i] != 0.0:
			vel[i] = (pos[i] - prev[i]) / H
	if t > 40.0 and status == "running":
		status = "fail"
		reason = "Time ran out."

func _start_fall(why: String) -> void:
	if vstate == "fall":
		return
	fall_pos = vehicle_pos()
	fall_rot = vehicle_angle()
	fall_vel = Vector2(SPEED * 0.6, 0.0)
	vstate = "fall"
	reason = why

## Ratio of each member's force to its strength (for the stress colours).
func stress(i: int) -> float:
	return absf(force[i]) / strength[i]

func broken_count() -> int:
	var k := 0
	for b in broken:
		k += b
	return k

## Runs a whole test without drawing (level tool, headless tests).
static func simulate(level_dict: Dictionary, design: Array, mult: float = 1.0) -> String:
	var e = load("res://scripts/games/bridge_master/bridge_master_engine.gd").new()
	e.setup(level_dict, design, mult)
	var steps := 0
	while e.status == "running" and steps < 60 * 45:
		e.advance(1.0 / 60.0)
		steps += 1
	return e.status
