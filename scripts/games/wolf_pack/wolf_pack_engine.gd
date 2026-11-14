extends RefCounted

## Pure game logic for Wolf Pack: no Nodes, no UI, headless-testable.
## You steer the lead wolf; the rest of the pack follows and joins the chase.
## Small prey falls to one wolf; big prey needs several wolves round it at
## once, and kicks back when too few are there. Hunger drains all the time
## (faster in winter and with a bigger pack); meat fills it, and spare meat
## raises pups. Hunger at zero: a wolf leaves; the leader alone starving = over.

const W := 2400.0
const H := 3600.0
const SEASON_LEN := 75.0
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const MAX_PACK := 10
const GROW_AT := 60.0            # spare meat that raises one pup
const WOLF_SPEED := 230.0
const SPRINT_SPEED := 340.0
const CATCH_R := 46.0

## Prey kinds. need = wolves that must be round it; hold = seconds they must
## hold it; food = hunger it fills; kg = score.
const PREY := {
	"hare": {"name": "Hare", "speed": 300.0, "need": 1, "hold": 0.0, "food": 9.0, "kg": 2, "r": 10.0, "flee": 200.0, "kick": false},
	"deer": {"name": "Deer", "speed": 285.0, "need": 2, "hold": 0.8, "food": 26.0, "kg": 40, "r": 18.0, "flee": 240.0, "kick": false},
	"elk": {"name": "Elk", "speed": 255.0, "need": 3, "hold": 1.3, "food": 50.0, "kg": 120, "r": 24.0, "flee": 230.0, "kick": true},
	"bison": {"name": "Bison", "speed": 200.0, "need": 5, "hold": 2.0, "food": 100.0, "kg": 300, "r": 32.0, "flee": 170.0, "kick": true},
}
## How many of each to keep around, per season.
const POP := [
	{"hare": 7, "deer": 5, "elk": 2, "bison": 1},
	{"hare": 8, "deer": 5, "elk": 3, "bison": 2},
	{"hare": 6, "deer": 4, "elk": 3, "bison": 2},
	{"hare": 3, "deer": 3, "elk": 3, "bison": 2},
]
const DIFF := [   # hunger per second, prey speed factor
	{"drain": 0.9, "speed": 0.92},
	{"drain": 1.2, "speed": 1.0},
	{"drain": 1.55, "speed": 1.06},
]

var mode := "year"        # year (one year, 4 seasons) or endless
var diff: int = 1
var time: float = 0.0
var hunger: float = 100.0
var spare: float = 0.0
var meat: int = 0
var stamina: float = 1.0
var wolves: Array = []    # {p, v, stun, lead}
var prey: Array = []      # {kind, p, v, hold, stam, wander, kick_t}
var kills := {"hare": 0, "deer": 0, "elk": 0, "bison": 0}
var biggest: int = 0
var over := false
var won := false
var rng := RandomNumberGenerator.new()

func reset(m: String, d: int, seed_v: int) -> void:
	mode = m
	diff = clampi(d, 0, 2)
	rng.seed = seed_v
	time = 0.0
	hunger = 100.0
	spare = 0.0
	meat = 0
	stamina = 1.0
	over = false
	won = false
	kills = {"hare": 0, "deer": 0, "elk": 0, "bison": 0}
	wolves.clear()
	prey.clear()
	for i in 4:
		_add_wolf(Vector2(W / 2.0 + rng.randf_range(-40, 40), H / 2.0 + 40.0 + i * 30.0), i == 0)
	biggest = wolves.size()
	_top_up(true)

func _add_wolf(p: Vector2, lead: bool = false) -> void:
	wolves.append({"p": p, "v": Vector2.ZERO, "stun": 0.0, "lead": lead})

func season() -> int:
	return int(time / SEASON_LEN) % 4

func year() -> int:
	return int(time / (SEASON_LEN * 4.0))

func season_left() -> float:
	return SEASON_LEN - fmod(time, SEASON_LEN)

func leader() -> Dictionary:
	return wolves[0]

func is_over() -> bool:
	return over

## One tick. inp = {"move": Vector2 (length <= 1), "sprint": bool}.
## Returns events: ["catch", kind, pos], ["kick", pos], ["pup"], ["leave"],
## ["season", index], ["starve"], ["win"].
func step(delta: float, inp: Dictionary) -> Array:
	var ev: Array = []
	if over:
		return ev
	var old_season := season()
	time += delta
	if season() != old_season:
		ev.append(["season", season()])
		if mode == "year" and time >= SEASON_LEN * 4.0:
			over = true
			won = true
			ev.append(["win"])
			return ev
	# Hunger.
	var drain: float = DIFF[diff].drain * (1.0 + 0.07 * (wolves.size() - 1)) * (1.5 if season() == 3 else 1.0)
	hunger -= drain * delta
	if hunger <= 0.0:
		if wolves.size() > 1:
			wolves.pop_back()
			hunger = 35.0
			ev.append(["leave"])
		else:
			hunger = 0.0
			over = true
			ev.append(["starve"])
			return ev
	_move_wolves(delta, inp)
	_move_prey(delta, ev)
	_top_up(false)
	return ev

func _move_wolves(delta: float, inp: Dictionary) -> void:
	var L: Dictionary = wolves[0]
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	var sprint: bool = inp.get("sprint", false) and stamina > 0.05 and mv.length() > 0.1
	if sprint:
		stamina = maxf(0.0, stamina - delta * 0.35)
	else:
		stamina = minf(1.0, stamina + delta * 0.18)
	var top := SPRINT_SPEED if sprint else WOLF_SPEED
	if L.stun > 0.0:
		L.stun -= delta
		mv = Vector2.ZERO
	L.v = L.v.lerp(mv.limit_length(1.0) * top, minf(1.0, delta * 6.0))
	L.p = _clamp(L.p + L.v * delta)
	var target = _hunt_target()
	for i in range(1, wolves.size()):
		var w: Dictionary = wolves[i]
		if w.stun > 0.0:
			w.stun -= delta
			w.v *= 0.9
			w.p = _clamp(w.p + w.v * delta)
			continue
		var goal: Vector2
		if target != null:
			# Spread round the prey so several wolves can hold it.
			var a := TAU * float(i) / float(wolves.size())
			goal = target.p + Vector2.RIGHT.rotated(a) * PREY[target.kind].r * 0.8 + target.v * 0.25
		else:
			var back: Vector2 = -L.v.normalized() if L.v.length() > 20.0 else Vector2.DOWN
			var side := back.orthogonal() * (float((i % 3) - 1) * 46.0)
			goal = L.p + back * (50.0 + 34.0 * float((i + 1) >> 1)) + side
		var to: Vector2 = goal - w.p
		var spd: float = (SPRINT_SPEED * 1.02 if target != null else WOLF_SPEED * 1.15)
		var want := to.normalized() * minf(spd, to.length() * 4.0)
		# Keep apart a little.
		for j in wolves.size():
			if j != i:
				var d: Vector2 = w.p - wolves[j].p
				if d.length() < 26.0 and d.length() > 0.01:
					want += d.normalized() * 120.0
		w.v = w.v.lerp(want, minf(1.0, delta * 5.0))
		w.p = _clamp(w.p + w.v * delta)

## The prey the pack goes for: nearest to the leader within reach.
func _hunt_target():
	var L: Dictionary = wolves[0]
	var best = null
	var bd := 260.0
	for pr in prey:
		var d: float = pr.p.distance_to(L.p)
		if d < bd:
			bd = d
			best = pr
	return best

func _move_prey(delta: float, ev: Array) -> void:
	var dead: Array = []
	for pr in prey:
		var k: Dictionary = PREY[pr.kind]
		pr.kick_t = maxf(0.0, pr.kick_t - delta)
		var near := 0
		var threat := Vector2.ZERO
		var closest := 99999.0
		for w in wolves:
			var d: Vector2 = pr.p - w.p
			var dl := d.length()
			closest = minf(closest, dl)
			if dl < k.flee:
				threat += d.normalized() * (k.flee - dl)
			if dl < k.r + CATCH_R:
				near += 1
		var want := Vector2.ZERO
		if threat != Vector2.ZERO:
			pr.stam = maxf(0.0, pr.stam - delta * 0.12)
			var f: float = k.speed * DIFF[diff].speed * (0.55 + 0.45 * pr.stam)
			var dir: Vector2 = threat.normalized()
			if pr.kind == "hare":
				dir = dir.rotated(sin(time * 7.0 + pr.p.x) * 0.9)
			# Steer off the edges.
			var edge := Vector2.ZERO
			if pr.p.x < 150: edge.x += 1.0
			if pr.p.x > W - 150: edge.x -= 1.0
			if pr.p.y < 150: edge.y += 1.0
			if pr.p.y > H - 150: edge.y -= 1.0
			want = (dir + edge * 1.5).normalized() * f
		else:
			pr.stam = minf(1.0, pr.stam + delta * 0.08)
			pr.wander += rng.randf_range(-1.5, 1.5) * delta
			want = Vector2.RIGHT.rotated(pr.wander) * 30.0
		pr.v = pr.v.lerp(want, minf(1.0, delta * 4.0))
		pr.p = _clamp(pr.p + pr.v * delta)
		# Catch.
		if near >= int(k.need):
			pr.hold += delta
			if pr.hold >= float(k.hold):
				dead.append(pr)
		else:
			pr.hold = maxf(0.0, pr.hold - delta * 2.0)
			if near > 0 and k.kick and pr.kick_t <= 0.0:
				pr.kick_t = 1.4
				for w in wolves:
					if w.p.distance_to(pr.p) < k.r + CATCH_R:
						w.stun = 0.9
						w.v = (w.p - pr.p).normalized() * 380.0
				hunger = maxf(1.0, hunger - 3.0)
				ev.append(["kick", pr.p])
	for pr in dead:
		prey.erase(pr)
		var k: Dictionary = PREY[pr.kind]
		kills[pr.kind] += 1
		meat += int(k.kg)
		var room := 100.0 - hunger
		var food: float = k.food
		hunger = minf(100.0, hunger + food)
		if food > room:
			spare += food - room
		ev.append(["catch", pr.kind, pr.p])
		while spare >= GROW_AT and wolves.size() < MAX_PACK:
			spare -= GROW_AT
			_add_wolf(pr.p + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20)))
			biggest = maxi(biggest, wolves.size())
			ev.append(["pup"])
		if wolves.size() >= MAX_PACK:
			spare = minf(spare, GROW_AT)

## Keep each kind at the season's number, new ones out of sight of the leader.
func _top_up(anywhere: bool) -> void:
	var want: Dictionary = POP[season()]
	for kind in want:
		var have := 0
		for pr in prey:
			if pr.kind == kind:
				have += 1
		while have < int(want[kind]):
			var p := Vector2.ZERO
			for tries in 20:
				p = Vector2(rng.randf_range(120, W - 120), rng.randf_range(120, H - 120))
				if anywhere and p.distance_to(wolves[0].p) > 500.0 or p.distance_to(wolves[0].p) > 900.0:
					break
			prey.append({"kind": kind, "p": p, "v": Vector2.ZERO, "hold": 0.0, "stam": 1.0, "wander": rng.randf() * TAU, "kick_t": 0.0})
			have += 1

func _clamp(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 20.0, W - 20.0), clampf(p.y, 20.0, H - 20.0))

## ❤ help: a full belly.
func feed() -> bool:
	if over or hunger >= 99.0:
		return false
	hunger = 100.0
	return true

func pack_size() -> int:
	return wolves.size()

# ---------- save ----------

func to_dict() -> Dictionary:
	var ws: Array = []
	for w in wolves:
		ws.append([w.p.x, w.p.y])
	var ps: Array = []
	for pr in prey:
		ps.append([pr.kind, pr.p.x, pr.p.y, pr.stam, pr.wander])
	return {"mode": mode, "diff": diff, "time": time, "hunger": hunger, "spare": spare, "meat": meat,
		"stamina": stamina, "wolves": ws, "prey": ps, "kills": kills.duplicate(), "biggest": biggest, "seed": rng.seed}

func from_dict(d: Dictionary) -> void:
	reset(str(d.get("mode", "year")), int(d.get("diff", 1)), int(d.get("seed", 1)) + 7)
	time = float(d.get("time", 0.0))
	hunger = float(d.get("hunger", 100.0))
	spare = float(d.get("spare", 0.0))
	meat = int(d.get("meat", 0))
	stamina = float(d.get("stamina", 1.0))
	biggest = int(d.get("biggest", 4))
	var kd: Dictionary = d.get("kills", {})
	for k in kills:
		kills[k] = int(kd.get(k, 0))
	wolves.clear()
	for w in d.get("wolves", []):
		_add_wolf(Vector2(float(w[0]), float(w[1])), wolves.is_empty())
	if wolves.is_empty():
		_add_wolf(Vector2(W / 2.0, H / 2.0), true)
	prey.clear()
	for p in d.get("prey", []):
		if PREY.has(str(p[0])):
			prey.append({"kind": str(p[0]), "p": Vector2(float(p[1]), float(p[2])), "v": Vector2.ZERO, "hold": 0.0,
				"stam": float(p[3]), "wander": float(p[4]), "kick_t": 0.0})
	_top_up(false)
