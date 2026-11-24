extends RefCounted

## Stonewater engine (docs: D:/Dev/Minigame Art/wolf/GAME_DESIGN_WOLFPACK.md).
## Pure logic, no Nodes, headless-testable. A world is built from a map + mission
## dictionary (wolf_pack_data.gd): campaign missions use premade maps, Quick Mission
## builds its own. The hero (a rank in the pack and a role), AI packmates, herds of
## deer / elk / bison with weak-target logic, rival wolves, scent posts, den defence,
## Sense, pack commands, bite-and-hold, pounce, rallying howl, pack hunger.
## The old arcade game is in git history (6318dcf8).

const TerrainGen = preload("res://scripts/games/wolf_pack/terrain_gen.gd")
const Data = preload("res://scripts/games/wolf_pack/wolf_pack_data.gd")

const TCELL := 32.0
## Climbing slows everybody, running downhill is a little faster; max_slope in the
## terrain options keeps every hill crossable (no cliffs).
const UPHILL := 7.0                # speed lost per unit of height climbed per cell
const SLOPE_MIN := 0.65            # steepest climb still keeps this share of the speed
const SLOPE_MAX := 1.12            # steepest run downhill
const CHUNK := 1024.0

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
const SENSE_SHORT := 2.5           # before the Tracker rank
const SENSE_COOLDOWN := 9.0

const ELK_DRAIN := 12.0            # stamina per second while fleeing
const ELK_REGEN := 7.0
const TIRED_AT := 0.4              # fraction of stamina at which a bite can hold

const COMMANDS := ["rally", "hold", "scout", "drive", "flank", "strike", "guard"]
const ROLES := {
	"chaser": {"name": "Dart", "speed": 1.06, "stamina": 130.0, "bite": 9.0, "natural": "drive"},
	"attacker": {"name": "Juniper", "speed": 1.0, "stamina": 100.0, "bite": 16.0, "natural": "flank"},
	"scout": {"name": "Whisper", "speed": 1.08, "stamina": 100.0, "bite": 8.0, "natural": "scout"},
	"guardian": {"name": "Boulder", "speed": 0.98, "stamina": 110.0, "bite": 13.0, "natural": "guard"},
	"leader": {"name": "Sable", "speed": 1.02, "stamina": 110.0, "bite": 12.0, "natural": "strike"},
}
## What the hero's own role changes (Quick Mission). Missing keys = 1.0 (fog = radius in cells).
const ROLE_MODS := {
	"leader": {"fog": 7},
	"chaser": {"speed": 1.1, "stam": 1.3, "bite": 0.8, "fog": 8},
	"attacker": {"speed": 0.98, "bite": 1.4, "fog": 7},
	"scout": {"speed": 1.08, "stam": 1.1, "bite": 0.7, "sense_t": 1.6, "sense_cd": 0.6, "fog": 16},
}
const RIVAL_HP := 60.0
const BOSS_HP := 260.0
const RIVAL_SPEED := 250.0
const WOLF_DOWN_SECS := 9.0

var rng := RandomNumberGenerator.new()
var seed_used: int = 1
var mapd := {}                    # the map dictionary this world was built from
var mission := {}
var W: float = 4096.0
var H: float = 3072.0
var TGW: int = 128
var TGH: int = 96
var FOG_W: int = 128
var FOG_H: int = 96
var den := Vector2(700, 2500)
var landmark := Vector2(2100, 1500)
var mud: Array = []               # Rect2
var tint := Color(0.95, 1.02, 0.88)
var relief: float = 9.0
var rank_i: int = 0
var role := "leader"
var abil: Array = []
var cmds_ok: Array = []
var raid_points: Array = []

var time: float = 0.0
var stage := "leader"
var hero := {}                    # p, v, face, hp, max_hp, stam, max_stam, down_t, inv
var pack: Array = []              # {role, name, p, v, hp, stam, max_stam, biting, down_t}
var herd: Array = []              # {id, g, sp, p, v, hp, stam, max_stam, weak, kick_t, prog, alive, flee, wander, home}
var rivals: Array = []            # {id, p, v, hp, max_hp, boss, mode, home, alive, bite_t, flee_t, wander}
var posts: Array = []             # {p, marked}
var hunger: float = 70.0          # 0..100, the pack's belly
var command := "rally"
var target_id: int = -1
var sense_t: float = 0.0
var sense_cd: float = 0.0
var kills: int = 0
var kills_by := {}
var driven_off: int = 0
var downs: int = 0
var reached := false
var den_hp: float = 100.0
var waves_i: int = 0
var xp: int = 0
var hold_id: int = -1             # animal the hero is biting and holding
var hold_progress: float = 0.0    # 0..1 on that animal
var heir_used := false
var over := false
var outcome := ""                 # "" while playing, then "win" or "fail"
var fail_reason := ""             # "den", "time"
var trails: Array = []            # [animal id, pos, age]
var revealed := PackedByteArray()
var hgt := PackedFloat32Array()   # TGW x TGH heights 0..1, rebuilt from the seed (not saved)
var rally_t: float = 0.0
var rally_cd: float = 0.0
var pounce_cd: float = 0.0
var sprinting := false
var auto_t: float = 0.0
var hero_bite_t: float = 0.0
var _next_rival: int = 0

## Builds the world. roster = the packmates' role ids (see ROLES); role = the hero's own.
func start(map_d: Dictionary, mission_d: Dictionary, rank_v: int, role_v: String, roster: Array) -> void:
	mapd = map_d
	mission = mission_d
	rank_i = clampi(rank_v, 0, Data.RANKS.size() - 1)
	role = role_v if ROLE_MODS.has(role_v) else "leader"
	var rk: Dictionary = Data.rank(rank_i)
	abil = (rk.abil as Array).duplicate()
	cmds_ok = (rk.cmds as Array).duplicate()
	stage = str(rk.stage)
	W = float(map_d.w)
	H = float(map_d.h)
	TGW = int(W / TCELL)
	TGH = int(H / TCELL)
	FOG_W = TGW
	FOG_H = TGH
	den = map_d.den
	landmark = map_d.landmark
	mud = (map_d.mud as Array).duplicate()
	var ty: Dictionary = Data.MAP_TYPES[map_d.type]
	tint = ty.tint
	relief = float(ty.relief)
	seed_used = int(map_d.seed)
	rng.seed = seed_used * 31 + 5
	hgt = TerrainGen.generate(TGW, TGH, seed_used, ty.opts)
	time = 0.0
	var st: Dictionary = _hero_stats()
	hero = {"p": den, "v": Vector2.ZERO, "face": Vector2.RIGHT, "hp": st.hp, "max_hp": st.hp,
		"stam": st.stamina, "max_stam": st.stamina, "down_t": 0.0, "inv": 0.0}
	hunger = 70.0
	command = "rally"
	target_id = -1
	sense_t = 0.0
	sense_cd = 0.0
	kills = 0
	kills_by = {}
	driven_off = 0
	downs = 0
	reached = false
	den_hp = 100.0
	waves_i = 0
	xp = 0
	hold_id = -1
	hold_progress = 0.0
	heir_used = false
	over = false
	outcome = ""
	fail_reason = ""
	rally_t = 0.0
	rally_cd = 0.0
	pounce_cd = 0.0
	sprinting = false
	auto_t = 0.0
	hero_bite_t = 0.0
	trails.clear()
	revealed = PackedByteArray()
	revealed.resize(FOG_W * FOG_H)
	pack.clear()
	var i := 0
	for ro in roster:
		var r: Dictionary = ROLES[ro]
		pack.append({"role": ro, "name": r.name, "p": den + Vector2(-60 - i * 40, 50 + i * 30), "v": Vector2.ZERO,
			"hp": 100.0, "max_hp": 100.0, "stam": r.stamina, "max_stam": r.stamina, "biting": false, "down_t": 0.0})
		i += 1
	herd.clear()
	var gi := 0
	var aid := 0
	for hd in map_d.herds:
		var sp: Dictionary = Data.SPECIES[hd.sp]
		for k in int(hd.n):
			# Old, young and injured animals are the weak ones (design §5.2).
			var weak: bool = k < int(hd.get("weak", 2))
			var ms: float = float(sp.stam_weak) if weak else float(sp.stam)
			var p: Vector2 = (hd.at as Vector2) + Vector2(rng.randf_range(-260, 260), rng.randf_range(-200, 200))
			herd.append({"id": aid, "g": gi, "sp": hd.sp, "p": _clamp(p), "v": Vector2.ZERO,
				"hp": float(sp.hp_weak) if weak else float(sp.hp), "stam": ms, "max_stam": ms,
				"weak": weak, "kick_t": 0.0, "prog": 0.0, "alive": true, "flee": false,
				"wander": rng.randf() * TAU, "home": hd.at})
			aid += 1
		gi += 1
	posts.clear()
	for pp in map_d.posts:
		posts.append({"p": pp, "marked": false})
	rivals.clear()
	_next_rival = 0
	for rg in map_d.rivals:
		for k in int(rg.n):
			var at: Vector2 = (rg.at as Vector2) + Vector2(rng.randf_range(-120, 120), rng.randf_range(-120, 120))
			_spawn_rival(at, bool(rg.get("boss", false)) and k == 0, "patrol", rg.at)
	raid_points = (map_d.get("raid", []) as Array).duplicate()
	if raid_points.is_empty():
		var x: float = W - 90.0 if den.x < W / 2.0 else 90.0
		raid_points = [Vector2(x, H * 0.2), Vector2(x, H * 0.5), Vector2(x, H * 0.8)]
	_reveal()

func is_over() -> bool:
	return over

func has_ability(a: String) -> bool:
	return a in abil

func has_command(c: String) -> bool:
	return c in cmds_ok

## Stage stats, then the hero's own role on top.
func _hero_stats() -> Dictionary:
	var st: Dictionary = (STAGES[stage] as Dictionary).duplicate()
	var rm: Dictionary = ROLE_MODS.get(role, {})
	st.speed = float(st.speed) * float(rm.get("speed", 1.0))
	st.stamina = float(st.stamina) * float(rm.get("stam", 1.0))
	st.bite = float(st.bite) * float(rm.get("bite", 1.0))
	return st

func hero_stats() -> Dictionary:
	return _hero_stats()

func animal(id: int) -> Dictionary:
	for e in herd:
		if e.id == id:
			return e
	return {}

## Older name from the slice (the herd is not only elk now).
func elk(id: int) -> Dictionary:
	return animal(id)

func in_mud(p: Vector2) -> bool:
	for r in mud:
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

## The animal the pack goes for: the nearest to `from`, weak ones count as closer.
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

## The player's order (only commands the rank has earned). Returns true when taken.
func set_command(c: String) -> bool:
	if not c in COMMANDS or not has_command(c):
		return false
	_apply_command(c)
	return true

func _apply_command(c: String) -> void:
	command = c
	if c in ["drive", "flank", "strike"]:
		target_id = pick_target(hero.p)
	# A Rallying Howl: every tap on Rally while the howl is ready heals and quickens the pack.
	if c == "rally" and has_ability("rally_howl") and rally_cd <= 0.0:
		rally_t = 6.0
		rally_cd = 25.0
		for w in pack:
			w.hp = minf(w.max_hp, w.hp + w.max_hp * 0.15)
		pending_events.append(["rally_howl"])

var pending_events: Array = []

func _sense_time() -> float:
	var t: float = SENSE_TIME if has_ability("far_sense") else SENSE_SHORT
	if has_ability("wisdom"):
		t *= 1.25
	return t * float((ROLE_MODS[role] as Dictionary).get("sense_t", 1.0))

func sense() -> bool:
	if sense_cd > 0.0 or over:
		return false
	sense_t = _sense_time()
	var cd: float = SENSE_COOLDOWN * (0.7 if has_ability("wisdom") else 1.0) * float((ROLE_MODS[role] as Dictionary).get("sense_cd", 1.0))
	sense_cd = cd + sense_t
	return true

## inp: move (Vector2, length <= 1), sprint (bool), bite (bool held).
## Events: ["bite", pos], ["kick", pos], ["kill", pos], ["alarm"], ["down"], ["wolf_down", name],
## ["pounce", pos], ["rally_howl"], ["post", pos], ["rival_off", pos], ["wave", n], ["reached"],
## ["win"], ["fail", reason], ["fed"].
func step(delta: float, inp: Dictionary) -> Array:
	var ev: Array = pending_events
	pending_events = []
	if over:
		return ev
	time += delta
	sense_t = maxf(0.0, sense_t - delta)
	sense_cd = maxf(0.0, sense_cd - delta)
	rally_t = maxf(0.0, rally_t - delta)
	rally_cd = maxf(0.0, rally_cd - delta)
	pounce_cd = maxf(0.0, pounce_cd - delta)
	hero_bite_t = maxf(0.0, hero_bite_t - delta)
	hunger = maxf(0.0, hunger - 0.35 * delta)
	_auto_command(delta)
	_waves(ev)
	_hero(delta, inp, ev)
	_pack(delta, ev)
	_herd(delta, ev)
	_rivals(delta, ev)
	_posts(ev)
	_reveal()
	_check(ev)
	return ev

func _regen_mult() -> float:
	return 1.15 if hunger > 85.0 else (0.5 if hunger <= 0.0 else 1.0)

## When the hero is not the leader, a packmate (Sable) calls the hunt: Drive while the
## prey is fresh, Flank as it tires, Strike when it can be held, Guard against rivals.
func _auto_command(delta: float) -> void:
	if role == "leader":
		return
	auto_t -= delta
	if auto_t > 0.0:
		return
	auto_t = 1.2
	var rv: Dictionary = _nearest_rival(hero.p, 600.0)
	if not rv.is_empty():
		_auto_set("guard")
		return
	if target_id != -1:
		var cur: Dictionary = animal(target_id)
		if cur.is_empty() or not cur.alive or cur.p.distance_to(hero.p) > 1000.0:
			target_id = -1
	if target_id == -1:
		target_id = pick_target(hero.p, 900.0)
	if target_id == -1:
		_auto_set("rally")
		return
	var t: Dictionary = animal(target_id)
	var f: float = t.stam / t.max_stam
	if f > 0.7:
		_auto_set("drive")
	elif f > TIRED_AT + 0.1:
		_auto_set("flank")
	else:
		_auto_set("strike")

func _auto_set(c: String) -> void:
	if command != c:
		var keep := target_id
		command = c
		target_id = keep

func _hero(delta: float, inp: Dictionary, ev: Array) -> void:
	var h: Dictionary = hero
	h.inv = maxf(0.0, float(h.inv) - delta)
	if h.down_t > 0.0:
		h.down_t -= delta
		if h.down_t <= 0.0:
			# Rest at the den: the checkpoint (design §8).
			h.p = den
			h.hp = h.max_hp
			h.stam = h.max_stam
			hold_id = -1
			hold_progress = 0.0
		return
	var st: Dictionary = _hero_stats()
	var mv: Vector2 = (inp.get("move", Vector2.ZERO) as Vector2).limit_length(1.0)
	var sprint: bool = bool(inp.get("sprint", false)) and has_ability("sprint") and h.stam > 1.0 and mv.length() > 0.5
	sprinting = sprint
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
	# The chaser role wears prey down just by running them: the hero does it too.
	if role == "chaser":
		for e in herd:
			if e.alive and e.flee and e.p.distance_to(h.p) < 170.0:
				e.stam = maxf(0.0, e.stam - 9.0 * delta * (1.4 if sprint else 1.0))
	_bite(delta, bool(inp.get("bite", false)), ev)

func _bite(delta: float, pressed: bool, ev: Array) -> void:
	var h: Dictionary = hero
	if not pressed:
		hold_id = -1
		hold_progress = 0.0
		return
	var power: float = float(_hero_stats().bite)
	if hold_id == -1:
		for e in herd:
			if not e.alive:
				continue
			var sp: Dictionary = Data.SPECIES[e.sp]
			var d: float = e.p.distance_to(h.p)
			# Pounce (Tracker rank): a running sprint ends in a leap that costs the animal stamina.
			if d < 190.0 and d >= 70.0 and sprinting and has_ability("pounce") and pounce_cd <= 0.0 \
					and e.stam > e.max_stam * TIRED_AT and h.stam > 18.0:
				var dir: Vector2 = (e.p - h.p).normalized()
				h.p = _clamp(e.p - dir * 55.0)
				h.stam = maxf(0.0, h.stam - 18.0)
				e.stam = maxf(0.0, e.stam - e.max_stam * 0.4)
				e.kick_t = 1.0
				pounce_cd = 8.0
				ev.append(["pounce", e.p])
				return
			if d < 70.0:
				if e.stam <= e.max_stam * TIRED_AT:
					hold_id = e.id
					hold_progress = float(e.prog)   # a re-grab carries on where the last hold broke
					e.kick_t = 2.2
					ev.append(["bite", e.p])
				elif e.kick_t <= 0.0:
					# A nip at a fresh animal only costs it stamina, and it may kick back.
					e.stam = maxf(0.0, e.stam - 6.0)
					e.kick_t = 1.2
					ev.append(["bite", e.p])
					if rng.randf() < 0.5:
						_hurt_hero(float(sp.kick) * 0.7, e.p, ev)
				return
		# No prey in reach: a bite at a rival wolf.
		if hero_bite_t <= 0.0:
			var rv: Dictionary = _nearest_rival(h.p, 85.0)
			if not rv.is_empty():
				hero_bite_t = 0.55
				rv.hp -= power
				rv.v = (rv.p - h.p).normalized() * 160.0
				ev.append(["bite", rv.p])
		return
	var e2: Dictionary = animal(hold_id)
	if e2.is_empty() or not e2.alive or e2.p.distance_to(h.p) > 110.0:
		hold_id = -1
		return
	var helpers := 0
	for w in pack:
		if w.biting:
			helpers += 1
	# Each packmate biting speeds the hold up (design §5.5); a bigger bite holds faster.
	var sp2: Dictionary = Data.SPECIES[e2.sp]
	var need: float = float(sp2.hold_weak) if e2.weak else float(sp2.hold)
	var mult: float = clampf(power / 12.0, 0.6, 1.5)
	hold_progress += delta * (1.0 + 0.7 * helpers) * mult / need
	e2.prog = hold_progress
	e2.v = Vector2.ZERO
	# A held healthy animal still kicks; a kick breaks the hold.
	e2.kick_t -= delta
	if e2.kick_t <= 0.0 and not e2.weak:
		e2.kick_t = 2.2
		_hurt_hero(float(sp2.kick), e2.p, ev)
		hold_id = -1
		hold_progress = 0.0
		e2.prog = maxf(0.0, e2.prog - 0.2)
		return
	if hold_progress >= 1.0:
		_kill(e2, ev)

func _hurt_hero(dmg: float, from: Vector2, ev: Array) -> void:
	var h: Dictionary = hero
	if h.down_t > 0.0 or h.inv > 0.0:
		return
	h.hp -= dmg
	h.inv = 0.45
	h.v = (h.p - from).normalized() * 320.0
	ev.append(["kick", from])
	if h.hp <= 0.0:
		h.hp = 0.0
		h.down_t = 3.0
		hold_id = -1
		hunger = maxf(0.0, hunger - 10.0)
		downs += 1
		ev.append(["down"])

func _hurt_wolf(w: Dictionary, dmg: float, ev: Array) -> void:
	if w.down_t > 0.0:
		return
	w.hp -= dmg
	if w.hp <= 0.0:
		w.hp = 0.0
		w.down_t = WOLF_DOWN_SECS
		w.biting = false
		downs += 1
		ev.append(["wolf_down", w.name])

func _kill(e: Dictionary, ev: Array) -> void:
	e.alive = false
	hold_id = -1
	hold_progress = 0.0
	kills += 1
	kills_by[e.sp] = int(kills_by.get(e.sp, 0)) + 1
	xp += 80 if e.sp == "bison" else 40
	hunger = minf(100.0, hunger + 38.0)
	hero.hp = minf(hero.max_hp, hero.hp + 25.0)
	for w in pack:
		if w.down_t <= 0.0:
			w.hp = minf(w.max_hp, w.hp + 25.0)
	if target_id == e.id:
		target_id = -1
	ev.append(["kill", e.p])
	ev.append(["fed"])

# ---------- pack ----------

func _nearest_rival(from: Vector2, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := reach
	for r in rivals:
		if r.alive and r.mode != "flee":
			var d: float = r.p.distance_to(from)
			if d < bd:
				bd = d
				best = r
	return best

func _pack(delta: float, _ev: Array) -> void:
	var h: Dictionary = hero
	var tgt: Dictionary = animal(target_id) if target_id != -1 else {}
	if not tgt.is_empty() and not tgt.alive:
		tgt = {}
	var wise: float = 1.2 if has_ability("wisdom") else 1.0
	var slot := 0
	for w in pack:
		slot += 1
		if w.down_t > 0.0:
			w.down_t -= delta
			w.v = Vector2.ZERO
			if w.down_t <= 0.0:
				w.hp = w.max_hp * 0.5
			continue
		var r: Dictionary = ROLES[w.role]
		w.biting = false
		var eff: float = (1.2 if command == r.natural else 1.0) * wise
		var goal: Vector2 = _formation(h, slot)
		var sprinting_w := false
		var cmd := command
		# No marked target: pick the nearest, or fall back to following.
		if cmd in ["drive", "flank", "strike"] and tgt.is_empty():
			target_id = pick_target(h.p)
			tgt = animal(target_id) if target_id != -1 else {}
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
					sprinting_w = true
			"flank":
				if w.role != "scout":
					var away2: Vector2 = (tgt.p - h.p).normalized()
					var side: Vector2 = away2.orthogonal() * (1.0 if w.role == "attacker" else -1.0)
					goal = tgt.p + away2 * 260.0 + side * 140.0   # cut the escape line
					sprinting_w = w.p.distance_to(goal) > 150.0
			"strike":
				if not tgt.is_empty():
					goal = tgt.p
					sprinting_w = w.p.distance_to(tgt.p) > 120.0
			"guard":
				# Stay tight round the leader; the guardian takes the front.
				var ang: float = TAU * float(slot) / float(maxi(1, pack.size())) + 0.6
				goal = h.p + Vector2.RIGHT.rotated(ang) * (110.0 if w.role == "guardian" else 150.0)
		# Rival wolves in reach pull a wolf off whatever it was doing (not on Hold, not the scout).
		var reach := 80.0 if cmd == "hold" else (420.0 if (cmd == "guard" or w.role == "guardian") else 260.0)
		if w.role == "scout":
			reach = minf(reach, 160.0)
		var rv: Dictionary = _nearest_rival(w.p, reach)
		var bit_rival := false
		if not rv.is_empty():
			goal = rv.p
			sprinting_w = w.p.distance_to(rv.p) > 140.0
			if w.p.distance_to(rv.p) < 72.0:
				bit_rival = true
				w.biting = true
				rv.hp -= float(r.bite) * 1.1 * delta * eff
		var to: Vector2 = goal - w.p
		var spd: float = TROT * r.speed * (SPRINT_MULT if sprinting_w and w.stam > 1.0 else 1.0) * eff
		if rally_t > 0.0:
			spd *= 1.2
		if sprinting_w and w.stam > 1.0:
			w.stam = maxf(0.0, w.stam - SPRINT_COST * 0.55 * delta)
		else:
			w.stam = minf(w.max_stam, w.stam + STAM_REGEN * _regen_mult() * delta)
		if in_mud(w.p):
			spd *= 0.85
		spd *= slope_mult(w.p, to)
		var want: Vector2 = to.normalized() * minf(spd, to.length() * 4.0)
		for o in pack:
			if o != w and o.down_t <= 0.0:
				var dd: Vector2 = w.p - o.p
				if dd.length() < 40.0 and dd.length() > 0.01:
					want += dd.normalized() * 90.0
		var hd: Vector2 = w.p - h.p
		if hd.length() < 46.0 and hd.length() > 0.01:
			want += hd.normalized() * 90.0
		w.v = (w.v as Vector2).lerp(want, minf(1.0, delta * 5.0))
		w.p = _clamp(w.p + w.v * delta)
		# Harry the target and bite it when close.
		if not bit_rival and not tgt.is_empty() and w.p.distance_to(tgt.p) < 150.0 and cmd in ["drive", "flank", "strike"]:
			if w.role == "chaser":
				tgt.stam = maxf(0.0, tgt.stam - 9.0 * delta * eff)
			elif cmd == "strike" and w.role != "scout" and w.p.distance_to(tgt.p) < 90.0:
				w.biting = true
				tgt.stam = maxf(0.0, tgt.stam - 14.0 * delta * (float(r.bite) / 12.0) * eff)

func _formation(h: Dictionary, slot: int) -> Vector2:
	var back: Vector2 = -(h.face as Vector2)
	var side: Vector2 = back.orthogonal() * (float((slot % 3) - 1) * 62.0)
	return h.p + back * (60.0 + 38.0 * slot) + side

# ---------- herd ----------

func _herd(delta: float, ev: Array) -> void:
	var sums := {}
	var counts := {}
	for e in herd:
		if e.alive:
			sums[e.g] = (sums.get(e.g, Vector2.ZERO) as Vector2) + e.p
			counts[e.g] = int(counts.get(e.g, 0)) + 1
	if counts.is_empty():
		_trails(delta)
		return
	var wolves: Array = []
	if hero.down_t <= 0.0:
		wolves.append(hero.p)
	for w in pack:
		if w.down_t <= 0.0:
			wolves.append(w.p)
	var alarm := false
	for e in herd:
		if not e.alive:
			continue
		var sp: Dictionary = Data.SPECIES[e.sp]
		e.kick_t = maxf(0.0, e.kick_t - delta) if e.id != hold_id else e.kick_t
		if e.id != hold_id:
			e.prog = maxf(0.0, float(e.prog) - 0.12 * delta)
		if e.id == hold_id:
			e.flee = false
			continue
		var centre: Vector2 = (sums[e.g] as Vector2) / float(counts[e.g])
		var threat := Vector2.ZERO
		for wp in wolves:
			var d: float = e.p.distance_to(wp)
			# A trotting wolf is quiet, a sprinting one alarms from further away.
			var reach: float = float(sp.alert) * (1.0 if hero.v.length() > 260.0 or d < 300.0 else 0.55)
			if d < reach:
				threat += (e.p - wp).normalized() * (reach - d)
		var want := Vector2.ZERO
		if threat != Vector2.ZERO:
			if not e.flee:
				e.flee = true
				alarm = true
			var factor: float = 0.45 + 0.55 * (e.stam / e.max_stam)
			var spd: float = float(sp.speed) * factor * (0.6 if in_mud(e.p) else 1.0)
			var dir: Vector2 = threat.normalized()
			# Healthy herd animals bunch together; the weak one lags (design §5.2).
			var coh: Vector2 = centre - e.p
			if bool(sp.herd) and not e.weak and coh.length() > 220.0:
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
			var back: Vector2 = (e.home as Vector2) - e.p
			if back.length() > 700.0:
				want += back.normalized() * 40.0
		e.v = (e.v as Vector2).lerp(want, minf(1.0, delta * 4.0))
		e.p = _clamp(e.p + e.v * delta)
	_trails(delta)
	if alarm:
		ev.append(["alarm"])

func _trails(delta: float) -> void:
	if sense_t > 0.0 and int(time * 4.0) != int((time - delta) * 4.0):
		for e in herd:
			if e.alive:
				trails.append([e.id, e.p, 0.0])
	for t in trails:
		t[2] += delta
	trails = trails.filter(func(t): return t[2] < 6.0)
	if trails.size() > 400:
		trails = trails.slice(trails.size() - 400)

# ---------- rivals, raids ----------

func _spawn_rival(p: Vector2, boss: bool, mode: String, home: Vector2) -> void:
	rivals.append({"id": _next_rival, "p": _clamp(p), "v": Vector2.ZERO, "hp": BOSS_HP if boss else RIVAL_HP,
		"max_hp": BOSS_HP if boss else RIVAL_HP, "boss": boss, "mode": mode, "home": home, "alive": true,
		"bite_t": 0.0, "flee_t": 0.0, "wander": rng.randf() * TAU})
	_next_rival += 1

## Raid waves: [secs, count, boss] from the mission; they come in from the raid points and head for the den.
func _waves(ev: Array) -> void:
	var wl: Array = mission.get("waves", [])
	while waves_i < wl.size() and time >= float(wl[waves_i][0]):
		var wv: Array = wl[waves_i]
		waves_i += 1
		for k in int(wv[1]):
			var src: Vector2 = raid_points[(k + waves_i) % raid_points.size()]
			var at := src + Vector2(rng.randf_range(-90, 90), rng.randf_range(-90, 90))
			_spawn_rival(at, bool(wv[2]) and k == 0, "raid", den)
		ev.append(["wave", int(wv[1])])

func _rivals(delta: float, ev: Array) -> void:
	for r in rivals:
		if not r.alive:
			continue
		r.bite_t = maxf(0.0, float(r.bite_t) - delta)
		r.v = (r.v as Vector2) * maxf(0.0, 1.0 - delta * 6.0)
		if r.mode == "flee":
			r.flee_t -= delta
			var away: Vector2 = r.p - _nearest_wolf_pos(r.p)
			r.p = _clamp(r.p + away.normalized() * 320.0 * delta)
			if r.flee_t <= 0.0:
				r.alive = false
			continue
		if r.hp <= float(r.max_hp) * 0.28:
			r.mode = "flee"
			r.flee_t = 3.5
			driven_off += 1
			ev.append(["rival_off", r.p])
			continue
		var boss: bool = r.boss
		var aggro: float = 700.0 if boss else (380.0 if r.mode == "raid" else 480.0)
		var target_p := Vector2.ZERO
		var target_w: Dictionary = {}
		var on_hero := false
		var bd := aggro
		if hero.down_t <= 0.0 and r.p.distance_to(hero.p) < bd:
			bd = r.p.distance_to(hero.p)
			target_p = hero.p
			on_hero = true
		for w in pack:
			if w.down_t <= 0.0 and r.p.distance_to(w.p) < bd:
				bd = r.p.distance_to(w.p)
				target_p = w.p
				target_w = w
				on_hero = false
		var want := Vector2.ZERO
		var spd: float = RIVAL_SPEED * (0.94 if boss else 1.0) * (0.85 if in_mud(r.p) else 1.0)
		if bd < aggro:
			var to: Vector2 = target_p - r.p
			want = to.normalized() * spd * minf(1.0, to.length() / 40.0)
			if to.length() < 62.0 and r.bite_t <= 0.0:
				r.bite_t = 1.1
				var dmg: float = 14.0 if boss else 7.0
				if on_hero:
					_hurt_hero(dmg, r.p, ev)
				else:
					_hurt_wolf(target_w, dmg, ev)
		elif r.mode == "raid":
			var tod: Vector2 = den - r.p
			if tod.length() > 130.0:
				want = tod.normalized() * spd
			else:
				den_hp = maxf(0.0, den_hp - (6.0 if boss else 3.0) * delta)
		else:
			r.wander += rng.randf_range(-1.0, 1.0) * delta
			want = Vector2.RIGHT.rotated(r.wander) * 30.0
			var back: Vector2 = (r.home as Vector2) - r.p
			if back.length() > 260.0:
				want += back.normalized() * 60.0
		want *= slope_mult(r.p, want)
		r.p = _clamp(r.p + want * delta + (r.v as Vector2) * delta)

func _nearest_wolf_pos(from: Vector2) -> Vector2:
	var best: Vector2 = hero.p
	var bd: float = from.distance_to(best)
	for w in pack:
		var d: float = from.distance_to(w.p)
		if d < bd:
			bd = d
			best = w.p
	return best

# ---------- posts, objectives ----------

func _posts(ev: Array) -> void:
	if hero.down_t > 0.0:
		return
	for p in posts:
		if not p.marked and (p.p as Vector2).distance_to(hero.p) < 80.0:
			p.marked = true
			xp += 10
			ev.append(["post", p.p])
	if not reached and landmark.distance_to(hero.p) < 170.0:
		var ok := pack.is_empty()
		for w in pack:
			if w.down_t <= 0.0 and w.p.distance_to(landmark) < 480.0:
				ok = true
		if ok:
			reached = true
			ev.append(["reached"])

func marked_count() -> int:
	var n := 0
	for p in posts:
		if p.marked:
			n += 1
	return n

## Share of the map seen, in whole percent.
func scout_pct() -> int:
	var n := 0
	for b in revealed:
		if b == 1:
			n += 1
	return int(100.0 * float(n) / float(maxi(1, revealed.size())))

## The mission's goals with progress: [{t, sp, have, need, done}].
func objectives() -> Array:
	var out: Array = []
	for o in mission.get("objectives", []):
		var have := 0
		var need := 1
		match o.t:
			"hunt":
				need = int(o.n)
				have = int(kills_by.get(o.sp, 0)) if o.has("sp") else kills
			"scout":
				need = int(o.pct)
				have = scout_pct()
			"mark":
				need = int(o.n)
				have = marked_count()
			"reach":
				have = 1 if reached else 0
			"rivals":
				need = int(o.n)
				have = driven_off
			"defend":
				need = int(o.secs)
				have = int(time)
		out.append({"t": o.t, "sp": str(o.get("sp", "")), "have": mini(have, need), "need": need, "done": have >= need})
	return out

func _check(ev: Array) -> void:
	if den_hp <= 0.0:
		_finish("fail", "den", ev)
		return
	var lim: float = float(mission.get("limit", 0))
	if lim > 0.0 and time > lim:
		_finish("fail", "time", ev)
		return
	var all_done := true
	for o in objectives():
		if not o.done:
			all_done = false
	if all_done:
		_finish("win", "", ev)

func _finish(what: String, why: String, ev: Array) -> void:
	over = true
	outcome = what
	fail_reason = why
	ev.append([what, why] if what == "fail" else [what])

## Stars for a win: 1 finish, +1 within the mission's par time, +1 if no wolf went down.
func result() -> Dictionary:
	var stars := 0
	if outcome == "win":
		stars = 1
		if time <= float(mission.get("par", 99999.0)):
			stars += 1
		if downs == 0:
			stars += 1
	return {"outcome": outcome, "stars": stars, "time": time, "downs": downs, "kills": kills, "xp": xp,
		"driven_off": driven_off}

func _reveal() -> void:
	var fr: int = int((ROLE_MODS[role] as Dictionary).get("fog", 7))
	var pts: Array = [[hero.p, fr]]
	for w in pack:
		pts.append([w.p, 16 if w.role == "scout" else 5])
	for q in pts:
		var cx := int((q[0] as Vector2).x / TCELL)
		var cy := int((q[0] as Vector2).y / TCELL)
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
func chunks_around(c: Vector2i) -> Array:
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
## The map and mission are rebuilt by start() from the game's own setup record; this is
## only what moves.

func to_dict() -> Dictionary:
	var hs: Array = []
	for e in herd:
		hs.append([e.id, e.p.x, e.p.y, e.stam, e.weak, e.alive, e.hp])
	var ps: Array = []
	for w in pack:
		ps.append([w.p.x, w.p.y, w.hp, w.stam, w.down_t])
	var rs: Array = []
	for r in rivals:
		if r.alive:
			rs.append([r.p.x, r.p.y, r.hp, r.max_hp, r.boss, r.mode, r.home.x, r.home.y, r.flee_t])
	var pm: Array = []
	for p in posts:
		pm.append(p.marked)
	return {"seed": seed_used, "time": time, "hero": [hero.p.x, hero.p.y, hero.hp, hero.stam], "pack": ps, "herd": hs,
		"rivals": rs, "posts": pm, "den_hp": den_hp, "downs": downs, "driven_off": driven_off, "kills_by": kills_by,
		"reached": reached, "waves_i": waves_i, "rally_cd": rally_cd, "pounce_cd": pounce_cd,
		"hunger": hunger, "kills": kills, "xp": xp, "command": command, "heir": heir_used,
		"fog": Marshalls.raw_to_base64(revealed)}

## Call after start() with the same map / mission / rank / role / roster.
func from_dict(d: Dictionary) -> void:
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
		if pd[i].size() > 4:
			pack[i].down_t = float(pd[i][4])
	for hs in d.get("herd", []):
		var e: Dictionary = animal(int(hs[0]))
		if not e.is_empty():
			e.p = Vector2(float(hs[1]), float(hs[2]))
			e.stam = float(hs[3])
			e.alive = bool(hs[5])
			if hs.size() > 6:
				e.hp = float(hs[6])
	if d.has("rivals"):
		rivals.clear()
		_next_rival = 0
		for rs in d.rivals:
			_spawn_rival(Vector2(float(rs[0]), float(rs[1])), bool(rs[4]), str(rs[5]), Vector2(float(rs[6]), float(rs[7])))
			var r: Dictionary = rivals.back()
			r.hp = float(rs[2])
			r.max_hp = float(rs[3])
			r.flee_t = float(rs[8])
	var pm: Array = d.get("posts", [])
	for i in mini(pm.size(), posts.size()):
		posts[i].marked = bool(pm[i])
	den_hp = float(d.get("den_hp", 100.0))
	downs = int(d.get("downs", 0))
	driven_off = int(d.get("driven_off", 0))
	kills_by = d.get("kills_by", {})
	reached = bool(d.get("reached", false))
	waves_i = int(d.get("waves_i", 0))
	rally_cd = float(d.get("rally_cd", 0.0))
	pounce_cd = float(d.get("pounce_cd", 0.0))
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
