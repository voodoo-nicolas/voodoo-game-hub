extends RefCounted

## Stonewater, M0 vertical slice (docs: D:/Dev/Minigame Art/wolf/GAME_DESIGN_WOLFPACK.md).
## Pure logic, no Nodes, headless-testable: the hero and 3 AI packmates (chaser,
## attacker, scout), one elk herd with weak-target logic, Sense, pack commands,
## bite-and-hold, pack hunger. The old arcade game is in git history (6318dcf8).

const TerrainGen = preload("res://scripts/games/wolf_pack/terrain_gen.gd")

const W := 6144.0
const H := 4608.0
## Rolling hills (shared TerrainGen, 2026-11-18): one height per 32 px cell. Climbing
## slows everybody, running downhill is a little faster; max_slope keeps every hill
## crossable (no cliffs), so the hills shape the chase without walling anything off.
const TCELL := 32.0
const TGW := 192                   # W / TCELL
const TGH := 144                   # H / TCELL
const TERRAIN := {"hill": 30.0, "octaves": 5, "warp": 0.7, "macro": 1.0, "macro_size": 3.0, "ridge": 0.15, "max_slope": 0.045}
const UPHILL := 7.0                # speed lost per unit of height climbed per cell
const SLOPE_MIN := 0.65            # steepest climb still keeps this share of the speed
const SLOPE_MAX := 1.12            # steepest run downhill
const CHUNK := 1024.0
const DEN := Vector2(1100.0, 3700.0)
const LANDMARK := Vector2(3100.0, 2100.0)
const HERD_AT := Vector2(4300.0, 1300.0)

## Life stages (design §6). hp, bite, speed factor, stamina.
const STAGES := {
	"pup": {"hp": 40.0, "bite": 4.0, "speed": 0.80, "stamina": 60.0, "scale": 0.55},
	"juvenile": {"hp": 70.0, "bite": 8.0, "speed": 0.95, "stamina": 80.0, "scale": 0.8},
	"lone": {"hp": 100.0, "bite": 12.0, "speed": 1.00, "stamina": 100.0, "scale": 1.0},
	"leader": {"hp": 130.0, "bite": 16.0, "speed": 1.05, "stamina": 120.0, "scale": 1.1},
	"elder": {"hp": 110.0, "bite": 14.0, "speed": 0.95, "stamina": 90.0, "scale": 1.1},
}
const TROT := 230.0
const SPRINT_MULT := 1.5
const SPRINT_COST := 28.0          # stamina per second
const STAM_REGEN := 16.0
const SENSE_TIME := 4.0
const SENSE_COOLDOWN := 9.0

const ELK_SPEED := 330.0
const ELK_STAM_HEALTHY := 120.0
const ELK_STAM_WEAK := 50.0
const ELK_ALERT := 520.0           # how close a running wolf alarms the herd
const ELK_DRAIN := 12.0            # stamina per second while fleeing
const ELK_REGEN := 7.0
const TIRED_AT := 0.4              # fraction of stamina at which a bite can hold
const MUD := [Rect2(2200, 2600, 520, 380), Rect2(3500, 1700, 420, 320), Rect2(4700, 900, 560, 300),
	Rect2(1800, 1500, 380, 420), Rect2(3900, 2900, 500, 360), Rect2(2600, 900, 380, 300)]

const COMMANDS := ["rally", "hold", "scout", "drive", "flank", "strike"]
const ROLES := {
	"chaser": {"name": "Dart", "speed": 1.06, "stamina": 130.0, "bite": 9.0, "natural": "drive"},
	"attacker": {"name": "Juniper", "speed": 1.0, "stamina": 100.0, "bite": 16.0, "natural": "flank"},
	"scout": {"name": "Whisper", "speed": 1.08, "stamina": 100.0, "bite": 8.0, "natural": "scout"},
}

var rng := RandomNumberGenerator.new()
var seed_used: int = 1
var time: float = 0.0
var stage := "leader"
var hero := {}                    # p, v, face, hp, max_hp, stam, max_stam, down_t
var pack: Array = []              # {role, name, p, v, hp, stam, max_stam, biting}
var herd: Array = []              # {id, p, v, hp, stam, max_stam, weak, kick_t, alive, flee}
var hunger: float = 70.0          # 0..100, the pack's belly
var command := "rally"
var target_id: int = -1
var sense_t: float = 0.0
var sense_cd: float = 0.0
var kills: int = 0
var goal_kills: int = 2
var xp: int = 0
var hold_id: int = -1             # elk the hero is biting and holding
var hold_progress: float = 0.0    # 0..1 on that elk
var heir_used := false
var over := false
var trails: Array = []            # [elk id, pos, age]
var revealed := PackedByteArray()
var hgt := PackedFloat32Array()   # TGW x TGH heights 0..1, rebuilt from the seed (not saved)
const FOG_W := 192
const FOG_H := 144

func reset(seed_v: int = 1) -> void:
	seed_used = seed_v
	rng.seed = seed_v
	hgt = TerrainGen.generate(TGW, TGH, seed_v, TERRAIN)
	time = 0.0
	stage = "leader"
	var st: Dictionary = STAGES[stage]
	hero = {"p": DEN, "v": Vector2.ZERO, "face": Vector2.RIGHT, "hp": st.hp, "max_hp": st.hp,
		"stam": st.stamina, "max_stam": st.stamina, "down_t": 0.0}
	hunger = 70.0
	command = "rally"
	target_id = -1
	sense_t = 0.0
	sense_cd = 0.0
	kills = 0
	xp = 0
	hold_id = -1
	hold_progress = 0.0
	heir_used = false
	over = false
	trails.clear()
	revealed = PackedByteArray()
	revealed.resize(FOG_W * FOG_H)
	pack.clear()
	var i := 0
	for role in ROLES:
		var r: Dictionary = ROLES[role]
		pack.append({"role": role, "name": r.name, "p": DEN + Vector2(-60 - i * 40, 50 + i * 30), "v": Vector2.ZERO,
			"hp": 100.0, "max_hp": 100.0, "stam": r.stamina, "max_stam": r.stamina, "biting": false})
		i += 1
	herd.clear()
	for k in 12:
		# Old, young and injured animals are the weak ones (design §5.2): 3 in 12.
		var weak := k % 4 == 1
		var ms: float = ELK_STAM_WEAK if weak else ELK_STAM_HEALTHY
		var p := HERD_AT + Vector2(rng.randf_range(-260, 260), rng.randf_range(-200, 200))
		herd.append({"id": k, "p": p, "v": Vector2.ZERO, "hp": 60.0 if weak else 100.0, "stam": ms, "max_stam": ms,
			"weak": weak, "kick_t": 0.0, "prog": 0.0, "alive": true, "flee": false, "wander": rng.randf() * TAU})

func is_over() -> bool:
	return over

func hero_stats() -> Dictionary:
	return STAGES[stage]

func elk(id: int) -> Dictionary:
	for e in herd:
		if e.id == id:
			return e
	return {}

func in_mud(p: Vector2) -> bool:
	for r in MUD:
		if (r as Rect2).has_point(p):
			return true
	return false

## Ground height 0..1 at a world point.
func height_at(p: Vector2) -> float:
	return TerrainGen.sample(hgt, TGW, TGH, p.x / TCELL - 0.5, p.y / TCELL - 0.5)

## Speed factor for moving along dir at p: uphill slows, downhill helps a little.
func slope_mult(p: Vector2, dir: Vector2) -> float:
	if hgt.is_empty() or dir.length() < 0.01:
		return 1.0
	var g := TerrainGen.gradient(hgt, TGW, TGH, p.x / TCELL - 0.5, p.y / TCELL - 0.5)
	return clampf(1.0 - g.dot(dir.normalized()) * UPHILL, SLOPE_MIN, SLOPE_MAX)

## The elk the pack goes for: the nearest to the hero, weak ones count as closer.
func pick_target(from: Vector2, reach: float = 700.0) -> int:
	var best := -1
	var bs := 1e9
	for e in herd:
		if not e.alive:
			continue
		var d: float = e.p.distance_to(from)
		if d > reach:
			continue
		var score: float = d * (0.45 if e.weak else 1.0)
		if score < bs:
			bs = score
			best = e.id
	return best

func set_command(c: String) -> void:
	if not c in COMMANDS:
		return
	command = c
	if c in ["drive", "flank", "strike"]:
		target_id = pick_target(hero.p)

func sense() -> bool:
	if sense_cd > 0.0 or over:
		return false
	sense_t = SENSE_TIME
	sense_cd = SENSE_COOLDOWN + SENSE_TIME
	return true

## inp: move (Vector2, length <= 1), sprint (bool), bite (bool held).
## Events: ["bite", pos], ["kick", pos], ["kill", pos], ["alarm"], ["down"],
## ["heir"], ["goal"], ["fed"].
func step(delta: float, inp: Dictionary) -> Array:
	var ev: Array = []
	if over:
		return ev
	time += delta
	sense_t = maxf(0.0, sense_t - delta)
	sense_cd = maxf(0.0, sense_cd - delta)
	hunger = maxf(0.0, hunger - 0.35 * delta)
	_hero(delta, inp, ev)
	_pack(delta, ev)
	_herd(delta, ev)
	_reveal()
	if kills >= goal_kills:
		over = true
		ev.append(["goal"])
	return ev

func _regen_mult() -> float:
	return 1.15 if hunger > 85.0 else (0.5 if hunger <= 0.0 else 1.0)

func _hero(delta: float, inp: Dictionary, ev: Array) -> void:
	var h: Dictionary = hero
	if h.down_t > 0.0:
		h.down_t -= delta
		if h.down_t <= 0.0:
			# Rest at the den: the checkpoint (design §8).
			h.p = DEN
			h.hp = h.max_hp
			h.stam = h.max_stam
			hold_id = -1
			hold_progress = 0.0
		return
	var st: Dictionary = STAGES[stage]
	var mv: Vector2 = (inp.get("move", Vector2.ZERO) as Vector2).limit_length(1.0)
	var sprint: bool = inp.get("sprint", false) and h.stam > 1.0 and mv.length() > 0.5
	var spd: float = TROT * st.speed * mv.length() * (SPRINT_MULT if sprint else 1.0)
	if in_mud(h.p):
		spd *= 0.85
	spd *= slope_mult(h.p, mv)
	if hold_id != -1:
		spd *= 0.15
	if sprint:
		h.stam = maxf(0.0, h.stam - SPRINT_COST * delta)
	else:
		h.stam = minf(h.max_stam, h.stam + STAM_REGEN * _regen_mult() * delta)
	if mv.length() > 0.05:
		h.face = mv.normalized()
	h.v = (h.v as Vector2).lerp(mv.normalized() * spd if mv.length() > 0.05 else Vector2.ZERO, minf(1.0, delta * 7.0))
	h.p = _clamp(h.p + h.v * delta)
	_bite(delta, bool(inp.get("bite", false)), ev)

func _bite(delta: float, pressed: bool, ev: Array) -> void:
	var h: Dictionary = hero
	if not pressed:
		hold_id = -1
		hold_progress = 0.0
		return
	if hold_id == -1:
		for e in herd:
			if e.alive and e.p.distance_to(h.p) < 70.0:
				if e.stam <= e.max_stam * TIRED_AT:
					hold_id = e.id
					hold_progress = float(e.prog)   # a re-grab carries on where the last hold broke
					e.kick_t = 2.2
					ev.append(["bite", e.p])
				elif e.kick_t <= 0.0:
					# A nip at a fresh elk only costs it stamina, and it may kick back.
					e.stam = maxf(0.0, e.stam - 6.0)
					e.kick_t = 1.2
					ev.append(["bite", e.p])
					if rng.randf() < 0.5:
						_hurt_hero(10.0, e.p, ev)
				break
		return
	var e: Dictionary = elk(hold_id)
	if e.is_empty() or not e.alive or e.p.distance_to(h.p) > 110.0:
		hold_id = -1
		return
	var helpers := 0
	for w in pack:
		if w.biting:
			helpers += 1
	# Each packmate biting speeds the hold up (design §5.5).
	var need: float = 3.2 if e.weak else 5.0
	hold_progress += delta * (1.0 + 0.7 * helpers) / need
	e.prog = hold_progress
	e.v = Vector2.ZERO
	# A held healthy elk still kicks; a kick breaks the hold.
	e.kick_t -= delta
	if e.kick_t <= 0.0 and not e.weak:
		e.kick_t = 2.2
		_hurt_hero(14.0, e.p, ev)
		hold_id = -1
		hold_progress = 0.0
		e.prog = maxf(0.0, e.prog - 0.2)
		return
	if hold_progress >= 1.0:
		_kill(e, ev)

func _hurt_hero(dmg: float, from: Vector2, ev: Array) -> void:
	var h: Dictionary = hero
	h.hp -= dmg
	h.v = (h.p - from).normalized() * 320.0
	ev.append(["kick", from])
	if h.hp <= 0.0:
		h.hp = 0.0
		h.down_t = 3.0
		hold_id = -1
		hunger = maxf(0.0, hunger - 10.0)
		ev.append(["down"])
		# The heir takes over once per level (design §4): not built in M0, it only reports it.
		if not heir_used:
			heir_used = true
			ev.append(["heir"])

func _kill(e: Dictionary, ev: Array) -> void:
	e.alive = false
	hold_id = -1
	hold_progress = 0.0
	kills += 1
	xp += 40
	hunger = minf(100.0, hunger + 38.0)
	hero.hp = minf(hero.max_hp, hero.hp + 25.0)
	for w in pack:
		w.hp = minf(w.max_hp, w.hp + 25.0)
	if target_id == e.id:
		target_id = -1
	ev.append(["kill", e.p])
	ev.append(["fed"])

func _pack(delta: float, _ev: Array) -> void:
	var h: Dictionary = hero
	var tgt: Dictionary = elk(target_id) if target_id != -1 else {}
	if not tgt.is_empty() and not tgt.alive:
		tgt = {}
	var slot := 0
	for w in pack:
		slot += 1
		var r: Dictionary = ROLES[w.role]
		w.biting = false
		var eff: float = 1.2 if command == r.natural else 1.0
		var goal: Vector2 = _formation(h, slot)
		var sprinting := false
		var cmd := command
		# No marked target: pick the nearest, or fall back to following.
		if cmd in ["drive", "flank", "strike"] and tgt.is_empty():
			target_id = pick_target(h.p)
			tgt = elk(target_id) if target_id != -1 else {}
			if tgt.is_empty():
				cmd = "rally"
		match cmd:
			"hold":
				goal = w.p
			"scout":
				if w.role == "scout":
					goal = h.p + (h.face as Vector2) * 520.0
			"drive":
				if w.role == "chaser":
					var away: Vector2 = (tgt.p - h.p).normalized()
					goal = tgt.p - away * 90.0
					sprinting = true
			"flank":
				if w.role != "scout":
					var away2: Vector2 = (tgt.p - h.p).normalized()
					var side: Vector2 = away2.orthogonal() * (1.0 if w.role == "attacker" else -1.0)
					goal = tgt.p + away2 * 260.0 + side * 140.0   # cut the escape line
					sprinting = w.p.distance_to(goal) > 150.0
			"strike":
				if not tgt.is_empty():
					goal = tgt.p
					sprinting = w.p.distance_to(tgt.p) > 120.0
		var to: Vector2 = goal - w.p
		var spd: float = TROT * r.speed * (SPRINT_MULT if sprinting and w.stam > 1.0 else 1.0) * eff
		if sprinting and w.stam > 1.0:
			w.stam = maxf(0.0, w.stam - SPRINT_COST * 0.55 * delta)
		else:
			w.stam = minf(w.max_stam, w.stam + STAM_REGEN * _regen_mult() * delta)
		if in_mud(w.p):
			spd *= 0.85
		spd *= slope_mult(w.p, to)
		var want: Vector2 = to.normalized() * minf(spd, to.length() * 4.0)
		for o in pack:
			if o != w:
				var dd: Vector2 = w.p - o.p
				if dd.length() < 40.0 and dd.length() > 0.01:
					want += dd.normalized() * 90.0
		var hd: Vector2 = w.p - h.p
		if hd.length() < 46.0 and hd.length() > 0.01:
			want += hd.normalized() * 90.0
		w.v = (w.v as Vector2).lerp(want, minf(1.0, delta * 5.0))
		w.p = _clamp(w.p + w.v * delta)
		# Harry the target and bite it when close.
		if not tgt.is_empty() and w.p.distance_to(tgt.p) < 150.0 and cmd in ["drive", "flank", "strike"]:
			if w.role == "chaser":
				tgt.stam = maxf(0.0, tgt.stam - 9.0 * delta)
			elif cmd == "strike" and w.role != "scout" and w.p.distance_to(tgt.p) < 90.0:
				w.biting = true
				tgt.stam = maxf(0.0, tgt.stam - 14.0 * delta * (float(r.bite) / 12.0))

func _formation(h: Dictionary, slot: int) -> Vector2:
	var back: Vector2 = -(h.face as Vector2)
	var side: Vector2 = back.orthogonal() * (float((slot % 3) - 1) * 62.0)
	return h.p + back * (60.0 + 38.0 * slot) + side

func _herd(delta: float, ev: Array) -> void:
	var alive := 0
	var centre := Vector2.ZERO
	for e in herd:
		if e.alive:
			alive += 1
			centre += e.p
	if alive == 0:
		return
	centre /= float(alive)
	var wolves: Array = [hero.p]
	for w in pack:
		wolves.append(w.p)
	var alarm := false
	for e in herd:
		if not e.alive:
			continue
		e.kick_t = maxf(0.0, e.kick_t - delta) if e.id != hold_id else e.kick_t
		if e.id != hold_id:
			e.prog = maxf(0.0, float(e.prog) - 0.12 * delta)
		if e.id == hold_id:
			e.flee = false
			continue
		var threat := Vector2.ZERO
		for wp in wolves:
			var d: float = e.p.distance_to(wp)
			# A trotting wolf is quiet, a sprinting one alarms from further away.
			var reach: float = ELK_ALERT * (1.0 if hero.v.length() > 260.0 or d < 300.0 else 0.55)
			if d < reach:
				threat += (e.p - wp).normalized() * (reach - d)
		var want := Vector2.ZERO
		if threat != Vector2.ZERO:
			if not e.flee:
				e.flee = true
				alarm = true
			var factor: float = 0.45 + 0.55 * (e.stam / e.max_stam)
			var spd: float = ELK_SPEED * factor * (0.6 if in_mud(e.p) else 1.0)
			var dir: Vector2 = threat.normalized()
			# Healthy elk bunch with the herd; the weak one lags (design §5.2).
			var coh: Vector2 = centre - e.p
			if not e.weak and coh.length() > 220.0:
				dir = (dir + coh.normalized() * 0.4).normalized()
			var edge := Vector2.ZERO
			if e.p.x < 200.0: edge.x += 1.0
			if e.p.x > W - 200.0: edge.x -= 1.0
			if e.p.y < 200.0: edge.y += 1.0
			if e.p.y > H - 200.0: edge.y -= 1.0
			want = (dir + edge * 1.6).normalized() * spd
			want *= slope_mult(e.p, want)
			e.stam = maxf(0.0, e.stam - ELK_DRAIN * delta)
		else:
			e.flee = false
			e.stam = minf(e.max_stam, e.stam + ELK_REGEN * delta)
			e.wander += rng.randf_range(-1.2, 1.2) * delta
			want = Vector2.RIGHT.rotated(e.wander) * 28.0
			var back: Vector2 = HERD_AT - e.p
			if back.length() > 700.0:
				want += back.normalized() * 40.0
		e.v = (e.v as Vector2).lerp(want, minf(1.0, delta * 4.0))
		e.p = _clamp(e.p + e.v * delta)
	if sense_t > 0.0 and int(time * 4.0) != int((time - delta) * 4.0):
		for e in herd:
			if e.alive:
				trails.append([e.id, e.p, 0.0])
	for t in trails:
		t[2] += delta
	trails = trails.filter(func(t): return t[2] < 6.0)
	if trails.size() > 400:
		trails = trails.slice(trails.size() - 400)
	if alarm:
		ev.append(["alarm"])

func _reveal() -> void:
	var pts: Array = [[hero.p, 7]]
	for w in pack:
		pts.append([w.p, 16 if w.role == "scout" else 5])
	for q in pts:
		var cx := int((q[0] as Vector2).x / 32.0)
		var cy := int((q[0] as Vector2).y / 32.0)
		var r: int = q[1]
		for y in range(maxi(0, cy - r), mini(FOG_H, cy + r + 1)):
			for x in range(maxi(0, cx - r), mini(FOG_W, cx + r + 1)):
				if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
					revealed[y * FOG_W + x] = 1

func _clamp(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 30.0, W - 30.0), clampf(p.y, 30.0, H - 30.0))

## Chunk of a world position (32 x 32 tiles of 32 px).
static func chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / CHUNK), int(p.y / CHUNK))

## Chunks to keep loaded: a 3 x 3 square round the camera chunk, inside the map.
static func chunks_around(c: Vector2i) -> Array:
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := Vector2i(c.x + dx, c.y + dy)
			if q.x >= 0 and q.y >= 0 and float(q.x) * CHUNK < W and float(q.y) * CHUNK < H:
				out.append(q)
	return out

## ❤ help: a full belly.
func feed() -> bool:
	if over or hunger >= 99.0:
		return false
	hunger = 100.0
	return true

# ---------- save ----------

func to_dict() -> Dictionary:
	var hs: Array = []
	for e in herd:
		hs.append([e.id, e.p.x, e.p.y, e.stam, e.weak, e.alive])
	var ps: Array = []
	for w in pack:
		ps.append([w.p.x, w.p.y, w.hp, w.stam])
	return {"seed": seed_used, "time": time, "hero": [hero.p.x, hero.p.y, hero.hp, hero.stam], "pack": ps, "herd": hs,
		"hunger": hunger, "kills": kills, "xp": xp, "command": command, "heir": heir_used,
		"fog": Marshalls.raw_to_base64(revealed)}

func from_dict(d: Dictionary) -> void:
	reset(int(d.get("seed", 1)))
	time = float(d.get("time", 0.0))
	var hd: Array = d.get("hero", [])
	if hd.size() == 4:
		hero.p = Vector2(float(hd[0]), float(hd[1]))
		hero.hp = float(hd[2])
		hero.stam = float(hd[3])
	var pd: Array = d.get("pack", [])
	for i in mini(pd.size(), pack.size()):
		pack[i].p = Vector2(float(pd[i][0]), float(pd[i][1]))
		pack[i].hp = float(pd[i][2])
		pack[i].stam = float(pd[i][3])
	for hs in d.get("herd", []):
		var e: Dictionary = elk(int(hs[0]))
		if not e.is_empty():
			e.p = Vector2(float(hs[1]), float(hs[2]))
			e.stam = float(hs[3])
			e.alive = bool(hs[5])
	hunger = float(d.get("hunger", 70.0))
	kills = int(d.get("kills", 0))
	xp = int(d.get("xp", 0))
	command = str(d.get("command", "rally"))
	heir_used = bool(d.get("heir", false))
	var fog = d.get("fog", "")
	if fog is String and fog != "":
		var raw := Marshalls.base64_to_raw(fog)
		if raw.size() == FOG_W * FOG_H:
			revealed = raw
