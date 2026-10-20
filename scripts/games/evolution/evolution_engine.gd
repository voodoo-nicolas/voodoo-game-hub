extends RefCounted

## Evolution: a cell in an endless dark pond. Eat food and smaller creatures to
## grow, run from bigger ones, finish missions for size and DNA points, and
## spend DNA on the evolution tree. Pure simulation in world units, stepped by
## the game. Tuning lives in TUNING; lookup tables in evolution_data.gd.
##
## The world has no walls: creatures and food are spawned in a ring around the
## player, just outside what the player can see (`view_r`), and recycled when
## they fall far behind.

const Data = preload("res://scripts/games/evolution/evolution_data.gd")

const TUNING := {
	"start_mass": 10.0,
	"radius_k": 7.0,            # radius = radius_k * sqrt(mass)
	"eat_ratio": 1.15,          # eater needs mass >= victim mass * eat_ratio
	"jaws_step": 0.05,          # each point of jaws lowers the ratio by this
	"absorb": 0.10,             # share of the victim's mass the eater gains (small, so eating only plumps you a little)
	"food_mass": 1.0,
	"food_per_area": 4.2e-5,    # food per square world unit of the spawn disc
	"food_min": 30,
	"food_max": 220,
	"npc_per_area": 8.0e-6,
	"npc_min": 12,
	"npc_max": 40,
	"hunter_chance_cap": 0.45,
	"toxic_chance": 0.05,
	"rare_chance": 0.012,
	"equal_chance": 0.20,
	"min_npc_mass": 2.0,
	"player_speed": 360.0,      # x MOVE_MULT[rank]
	"speed_decay": 0.17,        # bigger = slower: speed / mass^decay
	"min_speed_frac": 0.35,
	"drift_speed": 24.0,        # prey wander speed while you still can't swim
	"flee_frac": 0.6,
	"sense": 520.0,             # hunter sight, x radius floor
	"glow_sense": 1.8,
	"accel": 7.0,
	"jolt_speed": 170.0,        # rank 0: each push
	"jolt_cooldown": 0.75,
	"jolt_drag": 3.2,
	"dash_mult": 2.3,
	"power_regen": 6.0,         # power-bar points per second (the bar slowly refills)
	"start_depth": 700.0,       # y = 0 is the water surface; y grows downward, forever
	"surface_margin": 0.6,      # x radius: how close to the surface the cell's centre may get
	"upgrade_cost_cut": 0.2,    # each ability upgrade makes it this much cheaper
	"upgrade_time_gain": 0.5,   # ... and this much longer / stronger
	"spit_speed": 760.0,
	"spit_range": 0.9,          # seconds a spit flies
	"slow_mult": 0.4,
	"lure_pull": 140.0,
	"tox_res_mult": 0.6,        # ailment time x this per point
	"warning_pause": 1.2,
	"poison_skin_rate": 0.10,   # share of its mass a biting hunter loses per second
	"camo_sense": 0.2,
	"harpoon_speed": 1000.0,
	"harpoon_range": 1.0,
	"venom_rate": 0.12,         # share of its mass a venomed creature loses per second
	"venom_slow": 0.6,
	"decoy_speed": 150.0,
	"limb_hp": 2.0,
	"limb_stun": 1.5,
	"suction_pull": 260.0,
	"grab_pull": 220.0,
	"shell_mult": 0.75,
	"slime_slow": 3.0,
	"stinger_rate": 0.07,
	"fins_bonus": 0.10,
	"streamlined_bonus": 0.12,
	"base_hp": 10.0,
	"membrane_hp": 5.0,
	"regen": 0.25,              # hp per second when not hit lately
	"regen_rank": 0.35,         # extra hp per second per point of regeneration
	"regen_delay": 3.0,
	"spikes_mult": 0.7,
	"armor_mult": 0.7,
	"brittle_mult": 1.6,
	"slow_heal_mult": 0.25,
	"appetite_mult": 0.5,
	"photo_rate": 0.012,        # mass per second per unit of mass
	"magnet_range": 190.0,
	"cam_base": 1.0,
	"cam_k": 0.045,
	"cam_min": 0.25,
	"respawn_per_step": 3,
	"story_grow": 1.25,         # a size-reward mission grows you by this factor
	"mission_linger": 3.0,
}

## Growth stages: [from mass, name]. Names are translated by the game.
const STAGES := [[0.0, "Spore"], [18.0, "Microbe"], [45.0, "Amoeba"], [110.0, "Hunter"], [260.0, "Predator"], [600.0, "Leviathan"]]

var rng := RandomNumberGenerator.new()
var difficulty := "normal"
var player := {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "mass": 0.0, "hp": 0.0}
var food: Array = []      # Vector2
var npcs: Array = []      # {"id","pos","vel","mass","species","role","wander","t"}
var alive := true
var peak_mass: float = 0.0
var eaten_food: int = 0
var eaten_cells: int = 0
var eaten_species := {}   # species id -> count
var jolts: int = 0
var time: float = 0.0
var events: Array = []    # this step's events; the game draws effects / banners from them
var dna: int = 0
var owned := {}           # tree node id -> points spent (only ids with 1 or more)
var slot_ids: Array = ["", "", "", ""]   # the ability on each of the 4 buttons ("" = none)
var specials := {}        # special trait id -> true
var ailments := {}        # ailment id -> seconds left
var move_rank: int = 0    # 0 = jolting, 1.. = tail ranks
var sight_rank: int = 1   # 1 = blind blob, 2 = first eye, 3.. = wider
var power: float = 100.0   # the blue bar
var dash_t: float = 0.0
var camo_t: float = 0.0
var lure_t: float = 0.0
var ink_t: float = 0.0
var ink_pos := Vector2.ZERO
var facing := Vector2.RIGHT
var decoy := {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "t": 0.0}
var suction_t: float = 0.0
var sonar_t: float = 0.0
var shots: Array = []     # acid spit: {"pos","vel","life"}
var hit_t: float = 99.0   # seconds since the last bite
var escape_time: float = 0.0
var seen := {}            # species ids already met
var view_r: float = 220.0   # world units the player can see (the game sets it from zoom)
var vision_r: float = 220.0
var missions: Array = []
var missions_done: int = 0
var _story := 0
var _reward_n := 0
var _grow_target := 14.0
var _jolt_cd := 0.0
var _next_id := 1
var _mission_id := 1

# ---------- static rules ----------

static func stage_index(mass: float) -> int:
	var idx := 0
	for i in STAGES.size():
		if mass >= STAGES[i][0]:
			idx = i
	return idx

static func t(key: String):
	return TUNING[key]

static func radius_of(mass: float) -> float:
	return TUNING.radius_k * sqrt(maxf(mass, 0.0))

## The one rule: can `a_mass` eat `b_mass`?
static func can_eat(a_mass: float, b_mass: float, ratio: float = -1.0) -> bool:
	if ratio < 0.0:
		ratio = TUNING.eat_ratio
	return a_mass >= b_mass * ratio

## Mass after the eater swallows the victim.
static func grown_mass(eater: float, victim: float) -> float:
	return eater + victim * TUNING.absorb

## Top speed for a cell of this mass.
static func speed_for(mass: float, base: float = -1.0) -> float:
	if base < 0.0:
		base = TUNING.player_speed
	var m := maxf(mass / TUNING.start_mass, 1.0)
	return base * maxf(pow(m, -TUNING.speed_decay), TUNING.min_speed_frac)

## Camera zoom (smaller = further out) for the player's mass.
static func zoom_for(mass: float) -> float:
	var over := maxf(sqrt(mass) - sqrt(TUNING.start_mass), 0.0)
	return maxf(TUNING.cam_base / (1.0 + over * TUNING.cam_k), TUNING.cam_min)

# ---------- derived player state ----------

func score() -> int:
	return int(peak_mass * 10.0)

func stage() -> int:
	return stage_index(player.mass)

## 0..1 progress to the next growth stage (the gold XP bar).
func xp_frac() -> float:
	var i := stage()
	if i >= STAGES.size() - 1:
		return 1.0
	var lo: float = STAGES[i][0]
	var hi: float = STAGES[i + 1][0]
	return clampf((player.mass - lo) / (hi - lo), 0.0, 1.0)

func has(id: String) -> bool:
	return int(owned.get(id, 0)) > 0

## Points spent on a tree node.
func rank_of(id: String) -> int:
	return int(owned.get(id, 0))

func eat_ratio() -> float:
	return maxf(t("eat_ratio") - t("jaws_step") * rank_of("jaws"), 1.0)

## Strength shown on the info screen: 1 + jaws nodes.
func strength() -> int:
	return 1 + rank_of("jaws")

func max_hp() -> float:
	return t("base_hp") + t("membrane_hp") * rank_of("membrane")

func has_bars() -> bool:
	return sight_rank >= 2

func has_actives() -> bool:
	return not owned_actives().is_empty()

func ability_rank(id: String) -> int:
	return maxi(rank_of(id), 1)

func ability_cost(id: String) -> float:
	return Data.ABILITIES[id].cost * (1.0 - t("upgrade_cost_cut") * (ability_rank(id) - 1))

func ability_time(id: String) -> float:
	return Data.ABILITIES[id].time * (1.0 + t("upgrade_time_gain") * (ability_rank(id) - 1))

func ability_radius(id: String) -> float:
	return Data.ABILITIES[id].get("radius", 0.0) * (1.0 + 0.25 * (ability_rank(id) - 1))

func power_frac() -> float:
	return power / Data.POWER_MAX

func hunters_on() -> bool:
	return sight_rank >= 2 and Data.DIFFICULTY[difficulty].hunters > 0.0

## Clarity 0..2 from the lens nodes (the blur shown by the game).
func clarity() -> int:
	return mini(rank_of("lens") + (1 if has("real_eyes") else 0), Data.BLUR.size() - 1)

func move_mult() -> float:
	var m: float = Data.MOVE_MULT[clampi(move_rank, 0, Data.MOVE_MULT.size() - 1)]
	if move_rank >= 1:
		m += t("fins_bonus") * rank_of("fins") + (t("streamlined_bonus") if has("streamlined") else 0.0)
	return m

## Top speed now (without a dash), world units per second.
func top_speed() -> float:
	return speed_for(player.mass, t("player_speed") * move_mult())

func _recompute_ranks() -> void:
	var tails: int = rank_of("tail") + (1 if has("flagella") else 0) + (1 if has("cilia") else 0)
	if move_rank >= 1 or tails > 0:
		move_rank = clampi(1 + tails, 1, Data.MOVE_MULT.size() - 1)
	var eyes := 0
	for id in ["second_eye", "wide_eyes"]:
		if has(id):
			eyes += 1
	if sight_rank >= 2 or eyes > 0:
		sight_rank = clampi(2 + eyes, 2, Data.SIGHT_FRAC.size())

# ---------- start ----------

func reset(seed_: int = -1, diff: String = "normal") -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	difficulty = diff if Data.DIFFICULTY.has(diff) else "normal"
	player = {"pos": Vector2(0.0, t("start_depth")), "vel": Vector2.ZERO, "mass": t("start_mass"), "hp": t("base_hp")}
	food.clear()
	npcs.clear()
	alive = true
	peak_mass = player.mass
	eaten_food = 0
	eaten_cells = 0
	eaten_species = {}
	jolts = 0
	time = 0.0
	events.clear()
	dna = 0
	owned = {}
	slot_ids = ["", "", "", ""]
	specials = {}
	ailments = {}
	move_rank = 0
	sight_rank = 1
	power = Data.POWER_MAX
	dash_t = 0.0
	camo_t = 0.0
	lure_t = 0.0
	ink_t = 0.0
	suction_t = 0.0
	sonar_t = 0.0
	decoy = {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "t": 0.0}
	shots = []
	facing = Vector2.RIGHT
	hit_t = 99.0
	escape_time = 0.0
	seen = {}
	missions = []
	missions_done = 0
	_story = 0
	_reward_n = 0
	_grow_target = 14.0
	_jolt_cd = 0.0
	_next_id = 1
	_mission_id = 1
	_add_mission({"kind": "jolts", "target": 5, "text": "Learn to move: push the stick", "reward": "none"})
	# First meals right next to you, so the first steps have a goal.
	var spawn_max := _spawn_max()
	for i in 6:
		npcs.append(_new_npc(false, _ring_pos(view_r * 0.3, view_r * 1.6)))
	for i in _food_target():
		food.append(_ring_pos(view_r * 0.2, spawn_max))
	while npcs.size() < _npc_target():
		npcs.append(_new_npc(false, _ring_pos(view_r * 0.9, spawn_max)))

# ---------- spawning ----------

func _spawn_min() -> float:
	return maxf(view_r * 0.95, 120.0)

func _spawn_max() -> float:
	return _spawn_min() * 2.4

func _food_target() -> int:
	var a := PI * pow(_spawn_max(), 2.0)
	return clampi(int(a * t("food_per_area")), int(t("food_min")), int(t("food_max")))

func _npc_target() -> int:
	var a := PI * pow(_spawn_max(), 2.0)
	return clampi(int(a * t("npc_per_area")), int(t("npc_min")), int(t("npc_max")))

func _ring_pos(r0: float, r1: float) -> Vector2:
	var ang := rng.randf() * TAU
	var r := sqrt(rng.randf_range(r0 * r0, r1 * r1))
	var p: Vector2 = player.pos + Vector2.RIGHT.rotated(ang) * r
	if p.y < 24.0:
		p.y = 24.0 + (24.0 - p.y)       # spawns reflect off the surface, never above it
	return p

func _pick_role() -> String:
	var roll := rng.randf()
	if sight_rank >= 2:
		if roll < t("rare_chance"):
			return "rare"
		roll -= t("rare_chance")
		if roll < t("toxic_chance"):
			return "toxic"
		roll -= t("toxic_chance")
	if hunters_on():
		var share := minf(Data.DIFFICULTY[difficulty].hunters, t("hunter_chance_cap"))
		if roll < share:
			return "hunter"
		roll -= share
	if roll < t("equal_chance") and sight_rank >= 2:
		return "equal"
	return "prey"

func _new_npc(away: bool = true, at: Vector2 = Vector2.INF) -> Dictionary:
	var role := _pick_role()
	var list := Data.species_by_role(role)
	var sp: Dictionary = list[rng.randi() % list.size()]
	var rr: Array = Data.MASS_RANGE[role]
	var m: float = maxf(player.mass * rng.randf_range(rr[0], rr[1]), t("min_npc_mass"))
	_next_id += 1
	var pos := at if at != Vector2.INF else _ring_pos(_spawn_min(), _spawn_max())
	return {"id": _next_id, "pos": pos, "vel": Vector2.ZERO, "mass": m, "species": sp.id, "role": role,
		"wander": Vector2.RIGHT.rotated(rng.randf() * TAU), "t": rng.randf_range(0.5, 3.0)}

# ---------- the step ----------

## dir: desired heading, length 0..1 (joystick deflection).
func step(delta: float, dir: Vector2) -> void:
	if not alive:
		return
	time += delta
	events.clear()
	hit_t += delta
	_tick_ailments(delta)
	power = minf(power + t("power_regen") * delta, Data.POWER_MAX)
	dash_t = maxf(dash_t - delta, 0.0)
	camo_t = maxf(camo_t - delta, 0.0)
	lure_t = maxf(lure_t - delta, 0.0)
	ink_t = maxf(ink_t - delta, 0.0)
	suction_t = maxf(suction_t - delta, 0.0)
	sonar_t = maxf(sonar_t - delta, 0.0)
	_update_decoy(delta)
	_update_shots(delta)
	_move_player(delta, dir)
	_heal_and_passives(delta)
	_think(delta)
	_resolve(delta)
	_top_up()
	_recycle()
	_track_missions(delta)
	_tick_missions(delta)

func _move_player(delta: float, dir: Vector2) -> void:
	if dir.length() > 1.0:
		dir = dir.normalized()
	if move_rank == 0:
		# No tail yet: the cell only lurches, then drifts to a stop.
		_jolt_cd = maxf(_jolt_cd - delta, 0.0)
		if dir.length() > 0.3 and _jolt_cd <= 0.0:
			player.vel += dir.normalized() * t("jolt_speed")
			_jolt_cd = t("jolt_cooldown")
			jolts += 1
			events.append({"type": "jolt", "dir": dir.normalized()})
		player.vel *= exp(-t("jolt_drag") * delta)
	else:
		var want: Vector2 = dir * top_speed()
		if dash_t > 0.0:
			want = (dir.normalized() if dir.length() > 0.05 else player.vel.normalized()) * top_speed() * t("dash_mult")
		player.vel = player.vel.lerp(want, clampf(t("accel") * delta * (2.5 if dash_t > 0.0 else 1.0), 0.0, 1.0))
	player.pos += player.vel * delta
	# The surface: the one wall. Sides and depth never end.
	var top: float = radius_of(player.mass) * t("surface_margin")
	if player.pos.y < top:
		player.pos.y = top
		player.vel.y = maxf(player.vel.y, 0.0)
	if player.vel.length() > 5.0:
		facing = player.vel.normalized()

## Uses an active ability (button / key). Returns true when it fired.
func use_ability(id: String) -> bool:
	if not alive or not has(id) or not Data.ABILITIES.has(id):
		return false
	var cost := ability_cost(id)
	if power < cost:
		return false
	var dur := ability_time(id)
	match id:
		"burst":
			if move_rank < 1:
				return false
			dash_t = dur
			events.append({"type": "dash", "pos": player.pos})
		"spit":
			shots.append({"pos": player.pos + facing * radius_of(player.mass), "vel": facing * t("spit_speed"), "life": t("spit_range"), "slow": dur, "kind": "spit"})
			events.append({"type": "spit", "pos": player.pos})
		"shock", "spine":
			var rad := ability_radius(id)
			for n in npcs:
				if n.pos.distance_to(player.pos) < rad:
					n["stun"] = dur
			events.append({"type": "shock", "pos": player.pos, "radius": rad, "id": id})
		"lure":
			if lure_t > 0.0:
				return false
			lure_t = dur
			events.append({"type": "lure"})
		"ink":
			ink_t = dur
			ink_pos = player.pos
			events.append({"type": "ink", "pos": player.pos})
		"camo":
			if camo_t > 0.0:
				return false
			camo_t = dur
			events.append({"type": "camo"})
		"harpoon":
			shots.append({"pos": player.pos + facing * radius_of(player.mass), "vel": facing * t("harpoon_speed"), "life": t("harpoon_range"), "venom": dur, "kind": "harpoon"})
			events.append({"type": "spit", "pos": player.pos})
		"decoy":
			decoy = {"pos": player.pos, "vel": facing * t("decoy_speed"), "t": dur}
			events.append({"type": "decoy", "pos": player.pos})
		"limb":
			if player.hp <= t("limb_hp") + 0.5:
				return false
			player.hp -= t("limb_hp")
			decoy = {"pos": player.pos, "vel": Vector2.ZERO, "t": dur}
			for n in npcs:
				if n.role == "hunter" and n.pos.distance_to(player.pos) < ability_radius(id):
					n["stun"] = t("limb_stun")
			events.append({"type": "decoy", "pos": player.pos})
		"suction":
			suction_t = dur
			events.append({"type": "suction"})
		"grab":
			var picks := 0
			for n in npcs:
				if picks > ability_rank(id):
					break
				if n.pos.distance_to(player.pos) < ability_radius(id) and can_eat(player.mass, n.mass, eat_ratio()):
					n["stun"] = dur
					n["held"] = dur
					picks += 1
			events.append({"type": "grab", "count": picks})
		"sonar":
			sonar_t = dur
			events.append({"type": "sonar", "pos": player.pos, "radius": ability_radius(id)})
	power -= cost
	return true

func _update_decoy(delta: float) -> void:
	if decoy.t <= 0.0:
		return
	decoy.t -= delta
	decoy.pos += decoy.vel * delta
	decoy.vel *= maxf(0.0, 1.0 - 0.8 * delta)
	decoy.pos.y = maxf(decoy.pos.y, 0.0)

func _update_shots(delta: float) -> void:
	var keep: Array = []
	for sh in shots:
		sh.pos += sh.vel * delta
		sh.life -= delta
		var hit := false
		for n in npcs:
			if n.pos.distance_to(sh.pos) < radius_of(n.mass) + 14.0:
				if sh.get("kind", "spit") == "harpoon":
					n["venom"] = sh.venom
				else:
					n["slow"] = sh.slow
				events.append({"type": "spit_hit", "pos": sh.pos})
				hit = true
				break
		if not hit and sh.life > 0.0:
			keep.append(sh)
	shots = keep

func _heal_and_passives(delta: float) -> void:
	if hit_t > t("regen_delay") and player.hp < max_hp():
		var rate: float = t("regen") + t("regen_rank") * rank_of("regen")
		rate *= Data.DIFFICULTY[difficulty].regen
		if ailments.has("slow_heal"):
			rate *= t("slow_heal_mult")
		player.hp = minf(player.hp + rate * delta, max_hp())
	if specials.has("photo"):
		player.mass += player.mass * t("photo_rate") * delta
	if specials.has("magnet"):
		var rng2: float = t("magnet_range") + radius_of(player.mass)
		for i in food.size():
			var d: Vector2 = player.pos - food[i]
			if d.length() < rng2:
				food[i] += d.normalized() * 220.0 * delta
	peak_mass = maxf(peak_mass, player.mass)

func _tick_ailments(delta: float) -> void:
	for k in ailments.keys():
		ailments[k] -= delta
		if ailments[k] <= 0.0:
			ailments.erase(k)
			events.append({"type": "ailment_end", "id": k})

func _think(delta: float) -> void:
	var sense_floor: float = t("sense")
	if ailments.has("glow"):
		sense_floor *= t("glow_sense")
	if camo_t > 0.0:
		sense_floor *= t("camo_sense")
	var base_speed: float = maxf(top_speed(), 150.0) if move_rank > 0 else t("drift_speed")
	var hunter_speed: float = base_speed * Data.DIFFICULTY[difficulty].speed
	var ratio := eat_ratio()
	var ink_r := ability_radius("ink") if has("ink") else 0.0
	for n in npcs:
		n.t -= delta
		var slow_mult := 1.0
		if n.get("venom", 0.0) > 0.0:
			n["venom"] -= delta
			n.mass = maxf(n.mass - n.mass * t("venom_rate") * delta, t("min_npc_mass"))
			slow_mult = t("venom_slow")
		if n.get("stun", 0.0) > 0.0:
			n["stun"] -= delta
			if n.get("held", 0.0) > 0.0:
				n["held"] -= delta
				n.pos = n.pos.move_toward(player.pos, t("grab_pull") * delta)
			n.vel = n.vel.lerp(Vector2.ZERO, clampf(10.0 * delta, 0.0, 1.0))
			n.pos += n.vel * delta
			continue
		if n.get("slow", 0.0) > 0.0:
			n["slow"] -= delta
			slow_mult = minf(slow_mult, t("slow_mult"))
		var steer := Vector2.ZERO
		var speed := speed_for(n.mass, base_speed * 0.6)
		var to_p: Vector2 = player.pos - n.pos
		var d := to_p.length()
		var sight := maxf(sense_floor, radius_of(n.mass) * 6.0)
		var role: String = n.role
		# Ink: a hunter inside the cloud has lost you.
		if ink_t > 0.0 and n.pos.distance_to(ink_pos) < ink_r:
			sight = 0.0
		var chase := to_p
		var chase_d := d
		if role == "hunter" and decoy.t > 0.0:
			var dv: Vector2 = decoy.pos - n.pos
			if dv.length() < d * 1.5 + 100.0:
				chase = dv                                     # the decoy looks like a better meal
				chase_d = dv.length()
				sight = maxf(t("sense"), radius_of(n.mass) * 6.0)
				if chase_d < radius_of(n.mass):
					decoy.t = 0.0
					n["pause"] = 1.5
		var hunting: bool = role == "hunter" and chase_d < sight and can_eat(n.mass, player.mass)
		if hunting and has("warning") and not n.get("hunting", false):
			n["pause"] = t("warning_pause") * rank_of("warning")             # predators hesitate at the warning colours
		n["hunting"] = hunting
		if n.get("pause", 0.0) > 0.0:
			n["pause"] -= delta
			n.vel = n.vel.lerp(Vector2.ZERO, clampf(8.0 * delta, 0.0, 1.0))
			n.pos += n.vel * delta
			continue
		if hunting:
			steer = chase / maxf(chase_d, 0.001)              # hunt
			speed = speed_for(n.mass, hunter_speed)
		elif suction_t > 0.0 and (role == "prey" or role == "rare") and d < ability_radius("suction") and d > radius_of(player.mass) * 0.5 and can_eat(player.mass, n.mass, ratio):
			steer = to_p / maxf(d, 0.001)                     # sucked in
			speed = t("suction_pull")
		elif lure_t > 0.0 and (role == "prey" or role == "rare") and d < ability_radius("lure") and d > radius_of(player.mass):
			steer = to_p / maxf(d, 0.001)                     # drawn by the lure
			speed = t("lure_pull")
		elif (role == "prey" or role == "hunter" or role == "rare") and d < sight * 0.7 and can_eat(player.mass, n.mass, ratio) and move_rank > 0:
			steer = -to_p / maxf(d, 0.001)                    # flee
			speed = speed_for(n.mass, base_speed * (1.0 if role == "rare" else t("flee_frac")))
		else:
			if n.t <= 0.0:
				n.wander = Vector2.RIGHT.rotated(rng.randf() * TAU)
				n.t = rng.randf_range(1.5, 4.0)
			steer = n.wander * 0.4
			if move_rank == 0:
				speed = t("drift_speed")
		n.vel = n.vel.lerp(steer * speed * slow_mult, clampf(t("accel") * delta, 0.0, 1.0))
		n.pos += n.vel * delta
		# Nothing swims above the surface.
		var nr := radius_of(n.mass)
		if n.pos.y < nr:
			n.pos.y = nr
			n.vel.y = maxf(n.vel.y, 0.0)
			n.wander.y = absf(n.wander.y)
		if not seen.has(n.species) and d < vision_r * 0.92:
			_met(n.species)

## Eating on contact: the eater's centre must be inside the victim's rim
## (overlap by the victim's radius) so a graze doesn't swallow.
func _resolve(delta: float) -> void:
	var pr := radius_of(player.mass)
	var gain_mult: float = t("appetite_mult") if ailments.has("appetite") else 1.0
	# Food
	var fr := radius_of(t("food_mass"))
	var keep: Array = []
	for f in food:
		if f.distance_to(player.pos) < pr + fr * 0.5:
			player.mass += t("food_mass") * gain_mult
			eaten_food += 1
			events.append({"type": "food", "pos": f})
		else:
			keep.append(f)
	food = keep
	# NPCs
	var ratio := eat_ratio()
	var bite: float = Data.DIFFICULTY[difficulty].bite
	var left: Array = []
	for n in npcs:
		var d: float = n.pos.distance_to(player.pos)
		var nr := radius_of(n.mass)
		if can_eat(player.mass, n.mass, ratio) and d < pr - nr * 0.35:
			player.mass = player.mass + n.mass * t("absorb") * gain_mult
			eaten_cells += 1
			eaten_species[n.species] = int(eaten_species.get(n.species, 0)) + 1
			events.append({"type": "cell", "pos": n.pos, "mass": n.mass, "species": n.species, "role": n.role})
			if has("meal_heal") and not ailments.has("slow_heal"):
				player.hp = minf(player.hp + float(rank_of("meal_heal")), max_hp())
			if n.role == "toxic":
				_poison()
			elif n.role == "rare":
				_grant_rare()
			pr = radius_of(player.mass)
			continue
		if n.role == "hunter" and can_eat(n.mass, player.mass) and d < nr + pr * 0.5 and n.get("stun", 0.0) <= 0.0 and n.get("pause", 0.0) <= 0.0:
			var dmg := bite * delta
			if has("spikes"):
				dmg *= pow(t("spikes_mult"), rank_of("spikes"))
			if has("shell"):
				dmg *= t("shell_mult")
			if has("slime"):
				n["slow"] = t("slime_slow")
			if specials.has("armor"):
				dmg *= t("armor_mult")
			if ailments.has("brittle"):
				dmg *= t("brittle_mult")
			player.hp -= dmg
			if has("poison_skin"):
				n.mass = maxf(n.mass - n.mass * t("poison_skin_rate") * delta, t("min_npc_mass"))
			if hit_t > 0.5:
				events.append({"type": "hurt", "pos": player.pos})
			hit_t = 0.0
			player.vel += (player.pos - n.pos).normalized() * 260.0 * delta * 6.0
			if player.hp <= 0.0:
				player.hp = 0.0
				alive = false
				events.append({"type": "death", "pos": player.pos})
		if has("stinger") and (n.role == "hunter" or n.role == "equal") and d < nr + pr * 1.3:
			n.mass = maxf(n.mass - n.mass * t("stinger_rate") * rank_of("stinger") * delta, t("min_npc_mass"))
		left.append(n)
	npcs = left
	peak_mass = maxf(peak_mass, player.mass)

func _top_up() -> void:
	var made := 0
	while food.size() < _food_target() and made < int(t("respawn_per_step")):
		food.append(_ring_pos(_spawn_min(), _spawn_max()))
		made += 1
	made = 0
	while npcs.size() < _npc_target() and made < 1:
		npcs.append(_new_npc())
		made += 1

## Things far behind you are removed (and respawned ahead by _top_up).
func _recycle() -> void:
	var far := _spawn_max() * 1.5
	var far2 := far * far
	var kf: Array = []
	for f in food:
		if f.distance_squared_to(player.pos) < far2:
			kf.append(f)
	food = kf
	var kn: Array = []
	for n in npcs:
		if n.pos.distance_squared_to(player.pos) < far2:
			kn.append(n)
	npcs = kn

# ---------- poison, rare creatures ----------

func _poison() -> void:
	var id: String = Data.AILMENT_ORDER[rng.randi() % Data.AILMENT_ORDER.size()]
	ailments[id] = Data.AILMENTS[id].time * pow(t("tox_res_mult"), rank_of("tox_res"))
	events.append({"type": "ailment", "id": id})

## Rare creature: a tree trait ahead of time, or a special trait, or (if you have everything) DNA.
func _grant_rare() -> void:
	var pool: Array = []
	for n in Data.NODES:
		if reqs_met(n.id) and rank_of(n.id) < int(n.max):
			pool.append({"kind": "node", "id": n.id, "name": n.name})
	for s in Data.SPECIALS:
		if not specials.has(s.id):
			pool.append({"kind": "special", "id": s.id, "name": s.name})
	if pool.is_empty():
		dna += 2
		events.append({"type": "rare", "name": "+2 DNA"})
		return
	var pick: Dictionary = pool[rng.randi() % pool.size()]
	if pick.kind == "node":
		_add_point(pick.id)
	else:
		specials[pick.id] = true
	events.append({"type": "rare", "name": pick.name, "kind": pick.kind})

# ---------- the evolution tree ----------

## Every prerequisite owned with enough points?
func reqs_met(id: String) -> bool:
	var n := Data.node_of(id)
	if n.is_empty():
		return false
	for r in n.req:
		if rank_of(r[0]) < int(r[1]):
			return false
	return true

## DNA for the next point of a node (the first costs `cost`, each further one 1 more).
func cost_of(id: String) -> int:
	var n := Data.node_of(id)
	return int(n.cost) + rank_of(id) if not n.is_empty() else 0

## "maxed" (all points spent), "owned" (some points, more can be bought), "available" (can be bought
## now), "stage" (prerequisites owned, but you are not big enough yet) or "locked" (shown as "?").
func node_state(id: String) -> String:
	var n := Data.node_of(id)
	if n.is_empty():
		return "locked"
	var r := rank_of(id)
	if r >= int(n.max):
		return "maxed"
	if not reqs_met(id):
		return "locked" if r == 0 else "owned"
	if stage() < int(n.stage):
		return "stage"
	return "owned" if r > 0 else "available"

func can_buy(id: String) -> bool:
	var st := node_state(id)
	return (st == "available" or st == "owned") and reqs_met(id) and dna >= cost_of(id)

func _add_point(id: String) -> void:
	owned[id] = rank_of(id) + 1
	if id == "membrane":
		player.hp += t("membrane_hp")
	_recompute_ranks()
	auto_assign()

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	dna -= cost_of(id)
	_add_point(id)
	events.append({"type": "bought", "id": id})
	return true

# ---------- the ability buttons ----------

## Owned actives in the order they are offered.
func owned_actives() -> Array:
	var out: Array = []
	for id in Data.ABILITY_ORDER:
		if has(id):
			out.append(id)
	return out

func slot_type(i: int) -> String:
	return Data.SLOT_TYPE[i]

## 1 offensive and 1 defensive button once you own such an active; the 3rd and 4th arrive with growth
## (and only when there is another active to put on them).
func slot_visible(i: int) -> bool:
	if i < 2:
		for id in owned_actives():
			if Data.ABILITIES[id].kind == Data.SLOT_TYPE[i]:
				return true
		return false
	if stage() < int(Data.SLOT_STAGE[i]):
		return false
	return owned_actives().size() > i

## Actives that may go on button `i` (not already on another button).
func eligible(i: int) -> Array:
	var out: Array = []
	for id in owned_actives():
		var kind: String = Data.ABILITIES[id].kind
		if Data.SLOT_TYPE[i] != "any" and kind != Data.SLOT_TYPE[i]:
			continue
		var taken := false
		for j in 4:
			if j != i and slot_ids[j] == id:
				taken = true
		if not taken:
			out.append(id)
	return out

## Fills empty or invalid visible buttons with the first fitting active.
func auto_assign() -> void:
	for i in 4:
		if not slot_visible(i):
			continue
		var list := eligible(i)
		if slot_ids[i] == "" or not list.has(slot_ids[i]):
			slot_ids[i] = list[0] if not list.is_empty() else ""

## The player picks: next fitting active for button `i`.
func cycle_slot(i: int) -> void:
	var list := eligible(i)
	if list.is_empty():
		return
	var k := list.find(slot_ids[i])
	slot_ids[i] = list[(k + 1) % list.size()]

## Uses the ability on button `i`.
func use_slot(i: int) -> bool:
	if i < 0 or i > 3 or not slot_visible(i) or slot_ids[i] == "":
		return false
	return use_ability(slot_ids[i])

# ---------- missions ----------

func _add_mission(m: Dictionary) -> void:
	m["id"] = _mission_id
	_mission_id += 1
	m["done"] = false
	m["linger"] = 0.0
	m["args"] = m.get("args", [])
	if not m.has("base"):
		m["base"] = _counter(m.kind, m.get("species", ""))
	missions.append(m)

func _counter(kind: String, species: String) -> float:
	match kind:
		"jolts":
			return 0.0
		"cells":
			return float(eaten_cells)
		"food":
			return float(eaten_food)
		"species":
			return float(eaten_species.get(species, 0))
		"escape":
			return escape_time
		"rare":
			return float(eaten_species.get("gold", 0))
		"mass":
			return 0.0
	return 0.0

## Current progress of a mission, in its own units.
func progress_of(m: Dictionary) -> float:
	if m.kind == "mass":
		return player.mass
	if m.kind == "jolts":
		return float(jolts)
	return _counter(m.kind, m.get("species", "")) - float(m.base)

func _track_missions(delta: float) -> void:
	for n in npcs:
		if n.role == "hunter" and can_eat(n.mass, player.mass) and n.pos.distance_to(player.pos) < vision_r:
			escape_time += delta
			break
	for m in missions:
		if m.done:
			continue
		if progress_of(m) >= float(m.target):
			_complete(m)

func _tick_missions(delta: float) -> void:
	var keep: Array = []
	for m in missions:
		if m.done:
			m.linger -= delta
			if m.linger <= 0.0:
				continue
		keep.append(m)
	missions = keep

func _complete(m: Dictionary) -> void:
	m.done = true
	m.linger = t("mission_linger")
	missions_done += 1
	events.append({"type": "mission", "text": m.text})
	match m.reward:
		"tail":
			move_rank = 1
			events.append({"type": "tail"})
		"eye":
			sight_rank = 2
			events.append({"type": "eye"})
		"size":
			player.mass *= t("story_grow")
			peak_mass = maxf(peak_mass, player.mass)
			events.append({"type": "grow"})
		"dna":
			dna += 1
			events.append({"type": "dna"})
	# The first three missions are the tutorial, in order.
	if _story == 0 and m.kind == "jolts":
		_story = 1
		_add_mission({"kind": "cells", "target": 1, "text": "Eat another creature", "reward": "tail"})
	elif _story == 1 and m.reward == "tail":
		_story = 2
		_add_mission({"kind": "cells", "target": 10, "text": "Eat 10 creatures", "reward": "eye"})
	elif _story == 2 and m.reward == "eye":
		_story = 3
		_grow_mission()
		_fill()
	elif _story >= 3:
		if m.kind == "mass":
			_grow_target = maxf(_grow_target * 1.5, player.mass * 1.3)
			_grow_mission()
		_fill()

func _next_reward() -> String:
	_reward_n += 1
	return "size" if _reward_n % 2 == 1 else "dna"

func _grow_mission() -> void:
	_add_mission({"kind": "mass", "target": int(ceil(_grow_target)), "text": "Eat and grow: reach size %d",
		"args": [int(ceil(_grow_target))], "reward": _next_reward()})

## Keeps two ordinary goals on the list besides the grow mission and encounters.
func _fill() -> void:
	var ordinary := 0
	for m in missions:
		if not m.done and (m.kind == "cells" or m.kind == "food"):
			ordinary += 1
	while ordinary < 2:
		var k := missions_done
		if rng.randf() < 0.6:
			var n := 6 + 2 * k
			_add_mission({"kind": "cells", "target": n, "text": "Eat %d creatures", "args": [n], "reward": _next_reward()})
		else:
			var n2 := mini(25 + 5 * k, 150)
			_add_mission({"kind": "food", "target": n2, "text": "Eat %d food specks", "args": [n2], "reward": _next_reward()})
		ordinary += 1

func _open_count() -> int:
	var c := 0
	for m in missions:
		if not m.done:
			c += 1
	return c

## First sighting of a species: new encounters give new missions.
func _met(id: String) -> void:
	seen[id] = true
	var sp := Data.species_of(id)
	events.append({"type": "seen", "species": id, "role": sp.role})
	if _story < 3 or _open_count() >= 5:
		return
	match sp.role:
		"prey":
			_add_mission({"kind": "species", "species": id, "target": 1, "text": "Eat a %s", "args": [sp.name], "reward": _next_reward()})
		"hunter":
			_add_mission({"kind": "escape", "target": 8, "text": "Stay alive 8 seconds near a hunter", "reward": _next_reward()})
		"rare":
			_add_mission({"kind": "rare", "target": 1, "text": "Catch a Golden spore", "reward": "dna"})

## Fields for the HUD: each mission as {text, args, prog, target, done, reward}.
func mission_rows() -> Array:
	var out: Array = []
	for m in missions:
		var p := minf(progress_of(m), float(m.target))
		out.append({"text": m.text, "args": m.args, "prog": int(p), "target": int(m.target), "done": m.done, "reward": m.reward, "kind": m.kind})
	return out
