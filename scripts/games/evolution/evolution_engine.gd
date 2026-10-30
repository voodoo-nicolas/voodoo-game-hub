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
	"radius_k": 6.0,            # radius = radius_k * sqrt(mass) (was 7: creatures drawn a bit smaller, 2026-10-22)
	"eat_ratio": 1.15,          # eater needs mass >= victim mass * eat_ratio
	"jaws_step": 0.05,          # each point of jaws lowers the ratio by this
	"absorb": 0.10,             # share of the victim's mass a creature gains when it eats another one (you grow by xp, below)
	# xp per size: Data.XP_KILLS (owner 2026-10-29). Before: xp_first 30 (size 1 -> 2), xp_second 50 (the owner's
	# "X", size 2 -> 3), then xp_ratio 1.5 x the one before (owner 2026-10-24; it was 5 then x2).
	"food_xp": 0.5,             # xp per food speck (a creature is worth its size level in xp)
	"food_mass": 1.0,
	"food_per_area": 1.5e-5,    # food per square world unit of the spawn disc
	"food_min": 12,
	"food_max": 80,    # was 30 / 220 and 4.2e-5: swamped in specks and laggy (owner 2026-10-29)
	"npc_per_area": 8.0e-6,
	"npc_min": 10,
	"npc_max": 40,
	"hunter_safe": 650.0,       # no hunter ever spawns closer to you than this (world units)
	"hunter_gap": 6.0,          # seconds between one hunter spawning and the next (so they never pile up behind you)
	"revive_grace": 5.0,        # endless mode: seconds nothing can hurt you after coming back
	"hunter_weight": 5.0,       # x the difficulty share: how often a predator species is picked
	"toxic_chance": 0.05,
	"rare_chance": 0.012,
	"rare_max": 1,              # never more than this many rare creatures alive at once (owner 2026-10-29: schools of them)
	"min_npc_mass": 2.0,
	"player_speed": 360.0,      # x MOVE_MULT[rank]
	"size_speed_exp": 0.8,      # the camera zooms out as you grow, so speed grows with it: on screen you never feel slower
	"tail_value": 5,            # creature value to eat for a tail (or eat one that has a tail); was 20
	"eye_value": 12,            # ... and for an eye (was 40): both come while you are still size 1 (owner 2026-10-24)
	"tree_size": 2,             # growing to this size opens the evolution tree (it used to take 10 kills after the eye: size 5)
	"trait_tail_chance": 0.14,  # share of early prey that carries a tail
	"trait_eye_chance": 0.12,   # ... an eye
	"npc_sight": 380.0,         # how far creatures notice each other
	"npc_flee": 300.0,
	"npc_sep": 150.0,           # creatures push apart inside this distance
	"drift_speed": 24.0,        # prey wander speed while you still can't swim
	"flee_frac": 0.6,
	"sense": 520.0,             # hunter sight, x radius floor
	"glow_sense": 1.8,
	"accel": 7.0,               # creatures' steering
	"player_accel": 13.0,       # yours: quicker starts and turns (owner 2026-10-29 "fast, agile"; it shared the 7)
	"jolt_speed": 170.0,        # rank 0: each push
	"jolt_cooldown": 0.75,
	"jolt_drag": 3.2,
	"dash_mult": 2.3,
	"power_regen": 6.0,         # power-bar points per second (the bar slowly refills)
	"start_depth": 700.0,       # y = 0 is the water surface; y grows downward, forever
	"units_per_m": 50.0,        # depth: world units per metre (was 10, which made 320 m a few centimetres of screen; owner 2026-10-23)
	"warn_margin": 0.15,        # the early warning comes this share of your depth limit (and 3 °C) before it
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
	"photo_rate": 0.003,        # share of the current size's xp per second (Photosynthesis)
	"magnet_range": 190.0,
	"cam_base": 0.88,           # was 1.0: the whole pond zoomed out a little (2026-10-22)
	"cam_k": 0.045,
	"cam_min": 0.22,
	"respawn_per_step": 3,
	"story_xp": 0.005,          # a size-reward mission gives this share of the current size's xp (was 0.4: missions made size 5 in 90 s, owner 2026-10-29)
	"mission_linger": 3.0,
	# Water: temperature falls with depth (warm at the surface, about 4 °C deep down) and in cold currents
	# that come and go as you swim sideways. `units_per_m` world units = 1 m of depth.
	"temp_surface": 24.0,
	"temp_deep": 4.0,
	"thermo_m": 150.0,          # how fast it gets colder with depth (m)
	"cold_band": 7.0,           # cold currents: up to this many °C colder
	"cold_band_len": 6000.0,    # ... repeating every this many world units sideways
	"min_temp": 8.0,            # coldest water a cell is fine in, without traits (°C)
	"cold_step": 2.5,           # each point of Antifreeze / Fat layer: this much colder
	"abyss_cold": 4.0,
	"max_depth": 200.0,         # deepest a cell is fine at, without traits (m)
	"pressure_step": 120.0,     # each point of Pressure cells: this much deeper
	"deep_body_step": 250.0,
	"abyss_depth": 600.0,
	"cold_dmg": 0.25,           # hp per second per °C too cold
	"cold_slow": 0.7,           # you swim this much slower when too cold
	"deep_dmg": 0.4,            # hp per second when too deep ...
	"deep_dmg_per100": 0.6,     # ... plus this much per 100 m past your limit
	"env_dmg_cap": 2.5,
	"resist_step": 0.2,         # each rank of a resistance cuts its ailment's time by this share (5 = immune)
}

## Growth stages: [from mass, name]. Names are translated by the game. Each starts where a size starts
## (Data.LEVELS): sizes 1, 2, 3, 4, 6 and 8.
const STAGES := [[0.0, "Spore"], [14.0, "Microbe"], [30.0, "Amoeba"], [62.0, "Hunter"], [270.0, "Predator"], [1150.0, "Leviathan"]]

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
var xp: float = 0.0       # growth: your mass follows it (`mass_of_xp`); every size needs twice the xp of the one before
var _mass_seen: float = 0.0   # the mass `xp` was last matched to (code that sets player.mass directly gets re-synced)
var _lvl_seen: int = 1    # the biggest size reached (each new one gets a banner)
var dna_bar := 0.0        # 0..1, the 🧬 bar: eating fills it, a full bar = +1 DNA
var _warn_cold := false
var _warn_deep := false
var owned := {}           # tree node id -> points spent (only ids with 1 or more)
var slot_ids: Array = ["", "", "", ""]   # the ability on each of the 4 buttons ("" = none)
var specials := {}        # special trait id -> true
var ailments := {}        # ailment id -> seconds left
var ail_full := {}        # ailment id -> how long it lasted when it started (for the HUD's timer bar)
var ail_count := {}       # ailment id -> times you got it this run (resistances grow from it)
var too_cold: float = 0.0  # °C colder than you can stand (0 = fine)
var too_deep: float = 0.0  # m deeper than you can stand (0 = fine)
var death_cause := ""     # "eaten", "cold" or "deep"
var deaths: int = 0       # endless mode: times you came back this run
var grace: float = 0.0    # seconds left in which nothing can hurt you (after coming back)
var _hunter_cd: float = 0.0
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
var eaten_value: int = 0       # total worth of what you have eaten
var kills: int = 0
var tree_unlocked := false
var seen_surface := false
var surface_hit := false
var max_depth: float = 0.0
var close_call_sent := false
var distance: float = 0.0        # world units swum this run (10 units = 1 m)
var max_stunned: int = 0         # most creatures stunned by one shock
var _comeback_armed := false
var _depth_i := 0
var seen := {}            # species ids already met
var view_r: float = 220.0   # world units the player can see (the game sets it from zoom)
var vision_r: float = 220.0
var missions: Array = []
var missions_done: int = 0
var _story := 0
var _reward_n := 0
var _grow_target := 2.0
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

## Speed multiplier for a cell of this mass: the camera zooms out as it grows, so it moves faster in world
## units and feels the same on screen (it used to slow down, which felt like crawling).
static func size_boost(mass: float) -> float:
	return pow(1.0 / zoom_for(mass), TUNING.size_speed_exp)

## Size level of a mass (1 = the smallest dots and the start; see Data.LEVELS).
static func size_level(mass: float) -> int:
	var lv := 1
	for i in Data.LEVELS.size():
		if mass >= Data.LEVELS[i]:
			lv = i + 1
	return lv

## xp needed to reach a size (size 1 = 0): the sum of the spans below it.
static func xp_at(lv: int) -> float:
	var x := 0.0
	for k in range(1, lv):
		x += xp_span(k)
	return x

## xp it takes to grow from this size to the next: Data.XP_KILLS kills of prey one size below (worth size - 1,
## at size 1 worth 1): 520, 1150, 1760, 2790, 3280, 9500, 13800, 21000, 64000. Past size 10 (the mass keeps growing, the
## size shown stays 10) each span is 1.3 x the one before.
static func xp_span(lv: int) -> float:
	var n: int = Data.XP_KILLS.size()
	if lv < 1:
		return 0.0
	if lv <= n:
		return float(Data.XP_KILLS[lv - 1]) * float(maxi(lv - 1, 1))
	return float(Data.XP_KILLS[n - 1]) * float(n - 1) * pow(1.3, float(lv - n))

## Your mass where size index `i` (0 = size 1) starts. Past size 10 the mass keeps doubling.
static func mass_anchor(i: int) -> float:
	if i <= 0:
		return TUNING.start_mass
	if i < Data.LEVELS.size():
		return Data.LEVELS[i]
	return Data.LEVELS[Data.LEVELS.size() - 1] * pow(2.0, float(i - Data.LEVELS.size() + 1))

## Your mass at this much xp: it climbs in a straight line from one size's start mass to the next.
static func mass_of_xp(x: float) -> float:
	var i := 0
	while i < 40 and x >= xp_at(i + 2):
		i += 1
	var lo := xp_at(i + 1)
	var f := clampf((x - lo) / (xp_at(i + 2) - lo), 0.0, 1.0)
	return lerpf(mass_anchor(i), mass_anchor(i + 1), f)

## The xp that matches a mass (the other way round).
static func xp_of_mass(m: float) -> float:
	var i := 0
	while i < 40 and m >= mass_anchor(i + 1):
		i += 1
	var f := clampf((m - mass_anchor(i)) / (mass_anchor(i + 1) - mass_anchor(i)), 0.0, 1.0)
	return lerpf(xp_at(i + 1), xp_at(i + 2), f)

## Camera zoom (smaller = further out) for the player's mass.
static func zoom_for(mass: float) -> float:
	var over := maxf(sqrt(mass) - sqrt(TUNING.start_mass), 0.0)
	return maxf(TUNING.cam_base / (1.0 + over * TUNING.cam_k), TUNING.cam_min)

# ---------- derived player state ----------

func score() -> int:
	return int(peak_mass * 10.0)

func stage() -> int:
	return stage_index(player.mass)

## 0..1 progress to the next size (the gold XP bar).
func xp_frac() -> float:
	_sync_mass()
	var lv := level()
	if lv >= Data.LEVELS.size():
		return 1.0
	return clampf((xp - xp_at(lv)) / xp_span(lv), 0.0, 1.0)

## If something set player.mass directly (a test, an old save path), match the xp to it.
func _sync_mass() -> void:
	if absf(player.mass - _mass_seen) > 0.0001:
		xp = xp_of_mass(player.mass)
		_mass_seen = player.mass

## Growing: add xp, and the mass follows. Until the eye opens you stay size 1 (owner 2026-10-24: tail and eye
## first, then "eat eat eat" to size 2, which opens the tree). `feeds_dna`: what you eat (and Photosynthesis)
## also fills the 🧬 bar; a mission's xp gift does not (it would pay a lump of DNA).
func _gain_xp(amount: float, feeds_dna: bool = true) -> void:
	_sync_mass()
	var before := xp
	if level() >= 2:
		amount /= float(Data.DIFFICULTY[difficulty].get("slow", 1.0))     # hard: sizes 2+ take 4x as long (owner 2026-10-29)
	var cap := xp_at(2) - 0.5
	if sight_rank < 2 and xp < cap:
		xp = minf(xp + amount, cap)
	else:
		xp += amount
	if feeds_dna and tree_unlocked:
		_fill_dna(xp - before)
	player.mass = mass_of_xp(xp)
	_mass_seen = player.mass
	peak_mass = maxf(peak_mass, player.mass)

## DNA per xp at your size: Data.DNA_PER_SIZE spread over the size's xp (past size 10: one point per
## DNA_PAST_10_KILLS kills of prey worth 9).
func dna_rate() -> float:
	var lv := level()
	if lv >= Data.LEVELS.size():
		return 1.0 / (Data.DNA_PAST_10_KILLS * float(lv - 1))
	return float(Data.DNA_PER_SIZE[clampi(lv - 1, 0, Data.DNA_PER_SIZE.size() - 1)]) / xp_span(lv)

## The 🧬 bar: eating fills it, a full bar is +1 DNA. Never more than one point per meal (owner 2026-10-29).
func _fill_dna(gained: float) -> void:
	if gained <= 0.0:
		return
	dna_bar += minf(gained * dna_rate(), 1.0)
	if dna_bar >= 1.0:
		dna += 1
		dna_bar = minf(dna_bar - 1.0, 0.999)
		events.append({"type": "dna_tick"})

## 0..1: how full the 🧬 bar is.
func dna_frac() -> float:
	return clampf(dna_bar, 0.0, 1.0)

## A new size: a banner and the music; DNA comes from the 🧬 bar, never all at once (owner 2026-10-29).
func _check_level_up() -> void:
	var lv := level()
	while _lvl_seen < lv:
		_lvl_seen += 1
		events.append({"type": "level", "level": _lvl_seen, "dna": 0})

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

## Your own size level.
func level() -> int:
	return size_level(player.mass)

## What eating a creature of this mass is worth to you: its own level, or nothing once it is 3 or more
## levels below you.
func value_of(mass: float) -> int:
	var lv := size_level(mass)
	return 0 if level() - lv >= 3 else lv

## 1 = shown normally, 0.35 = a faint particle (3 levels below you), 0 = invisible (4 or more below).
func visibility_of(mass: float) -> float:
	var diff := level() - size_level(mass)
	if diff >= 4:
		return 0.0
	if diff == 3:
		return 0.35
	return 1.0

## An NPC's speed given the player's reference speed: bigger than you = a little slower, smaller = a little faster.
func _npc_speed(npc_mass: float, ref: float) -> float:
	return ref * clampf(pow(maxf(npc_mass, 1.0) / maxf(player.mass, 1.0), -0.17), 0.7, 1.3)

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

## How many creatures that can eat you may be around at once: one at the first predator size, one more per
## size level after that, never above the difficulty's `hunter_max`. (Early on 5+ hunters was impossible to evade.)
func threat_cap() -> int:
	return clampi(level() - 2, 1, int(Data.DIFFICULTY[difficulty].get("hunter_max", 6)))

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

## How close your swimming speed is to the best a body can have (0..100): all tail ranks, 2 fins, streamlined.
func speed_pct() -> int:
	var best: float = Data.MOVE_MULT[Data.MOVE_MULT.size() - 1] + t("fins_bonus") * 2.0 + t("streamlined_bonus")
	return int(round(100.0 * move_mult() / best))

## Top speed now (without a dash), world units per second.
func top_speed() -> float:
	return t("player_speed") * move_mult() * size_boost(player.mass)

## Depth below the surface in metres.
func depth_m() -> float:
	return maxf(player.pos.y, 0.0) / TUNING.units_per_m

## Water temperature (°C) at a world position.
static func temp_at(pos: Vector2) -> float:
	var d: float = maxf(pos.y, 0.0) / TUNING.units_per_m
	var base: float = TUNING.temp_deep + (TUNING.temp_surface - TUNING.temp_deep) * exp(-d / TUNING.thermo_m)
	var band := pow(maxf(sin(pos.x / TUNING.cold_band_len * TAU + 0.7), 0.0), 2.0)
	return maxf(base - TUNING.cold_band * band, -1.0)     # salt water freezes a little below 0 °C

func temp() -> float:
	return temp_at(player.pos)

## The coldest water (°C) you are fine in.
func min_temp() -> float:
	return t("min_temp") - t("cold_step") * float(rank_of("cold_tol") + rank_of("blubber")) - t("abyss_cold") * float(rank_of("abyssal"))

## The deepest (m) you are fine at.
func max_depth_m() -> float:
	return t("max_depth") + t("pressure_step") * rank_of("pressure_tol") + t("deep_body_step") * rank_of("deep_body") + t("abyss_depth") * rank_of("abyssal")

## Resistance rank 0..5 to an ailment, earned by getting it again and again (Data.RESIST_AT).
func resist_rank(id: String) -> int:
	var n := int(ail_count.get(id, 0))
	var r := 0
	for at in Data.RESIST_AT:
		if n >= int(at):
			r += 1
	return r

## How many more times you must get this ailment for the next resistance rank (0 at 5/5).
func resist_left(id: String) -> int:
	var n := int(ail_count.get(id, 0))
	for at in Data.RESIST_AT:
		if n < int(at):
			return int(at) - n
	return 0

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
	dna_bar = 0.0
	xp = 0.0
	_mass_seen = player.mass
	_lvl_seen = 1
	_warn_cold = false
	_warn_deep = false
	owned = {}
	slot_ids = ["", "", "", ""]
	specials = {}
	ailments = {}
	ail_full = {}
	ail_count = {}
	too_cold = 0.0
	too_deep = 0.0
	death_cause = ""
	deaths = 0
	grace = 0.0
	_hunter_cd = 0.0
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
	eaten_value = 0
	kills = 0
	tree_unlocked = false
	seen_surface = false
	surface_hit = false
	max_depth = 0.0
	close_call_sent = false
	distance = 0.0
	max_stunned = 0
	_comeback_armed = false
	_depth_i = 0
	seen = {}
	missions = []
	missions_done = 0
	_story = 0
	_reward_n = 0
	_grow_target = 2.0
	_jolt_cd = 0.0
	_next_id = 1
	_mission_id = 1
	_add_mission({"kind": "jolts", "target": 5, "text": "Move around", "reward": "none"})
	# First meals near you, so the first steps have a goal (spread out, not in a clump).
	var spawn_max := _spawn_max()
	for i in 6:
		_spawn_npc(_ring_pos_sep(view_r * 0.3, view_r * 1.6))
	for i in _food_target():
		food.append(_ring_pos(view_r * 0.2, spawn_max))
	while npcs.size() < _npc_target():
		if not _spawn_npc(_ring_pos_sep(view_r * 0.9, spawn_max)):
			break

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

## Like _ring_pos but away from other creatures, so they are spread out and not in clumps.
func _ring_pos_sep(r0: float, r1: float, min_d: float = 0.0) -> Vector2:
	var sep := clampf(_spawn_min() * 0.55, 140.0, 420.0)
	var p := _ring_pos(r0, r1)
	for i in 24:
		var ok := p.distance_to(player.pos) >= min_d
		if ok:
			for n in npcs:
				if n.pos.distance_squared_to(p) < sep * sep:
					ok = false
					break
		if ok:
			return p
		p = _ring_pos(r0, r1)
	if p.distance_to(player.pos) < min_d:
		p = player.pos + Vector2(0.0, min_d)      # straight below you, always far enough
	return p

## Which species spawns next. Early on only single cells; chains from size 2; viruses, complex bacteria and
## the first predators from size 3; bigger animals later. Species a few sizes below you stop appearing, and
## only so many of one size are around you at once.
func _pick_species() -> Dictionary:
	var lvl := level()
	if sight_rank >= 2:
		var roll := rng.randf()
		var rares := 0
		for n in npcs:
			if n.role == "rare":
				rares += 1
		if roll < t("rare_chance") and rares < int(t("rare_max")):
			return _pick_rare(lvl)
		if roll < t("rare_chance") + t("toxic_chance"):
			var tox := Data.species_by_role("toxic")
			return tox[rng.randi() % tox.size()]
	# The creatures that carry the first two traits.
	if move_rank == 0 and lvl <= 1 and rng.randf() < t("trait_tail_chance"):
		return Data.species_of("tailed")
	if move_rank >= 1 and sight_rank == 1 and lvl <= 1 and rng.randf() < t("trait_eye_chance"):
		return Data.species_of("eyed")
	var counts := {}
	var threats := 0
	for n in npcs:
		var nl := size_level(n.mass)
		counts[nl] = int(counts.get(nl, 0)) + 1
		if n.role == "hunter" and can_eat(n.mass, player.mass):
			threats += 1
	var cands: Array = []
	var weights: Array = []
	var total := 0.0
	var tier_cap := clampi(lvl, 1, 10)
	for sp in Data.SPECIES:
		if sp.has("trait") or sp.role == "toxic" or sp.role == "rare" or int(sp.tier) > tier_cap or lvl > int(sp.get("until", 99)):
			continue
		if sp.role == "hunter" and (not hunters_on() or threats >= threat_cap() or _hunter_cd > 0.0):
			continue
		var mid: float = (float(sp.mass[0]) + float(sp.mass[1])) * 0.5
		var sl := size_level(mid)
		var diff := sl - lvl
		var w: float = 1.0 if diff >= 3 else float(Data.LEVEL_WEIGHT.get(diff, 0.0))
		if w <= 0.0 or int(counts.get(sl, 0)) >= Data.LEVEL_CAP:
			continue
		if sp.role == "hunter":
			w *= Data.DIFFICULTY[difficulty].hunters * t("hunter_weight")
		cands.append(sp)
		weights.append(w)
		total += w
	if cands.is_empty() or total <= 0.0:
		return {}
	var pick := rng.randf() * total
	for i in cands.size():
		pick -= weights[i]
		if pick <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]

## Which rare creature: the ones your size can meet (`tier`), weighted by `weight` (the rarer, the lower).
func _pick_rare(lvl: int) -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for sp in Data.SPECIES:
		if sp.role == "rare" and int(sp.tier) <= lvl:
			pool.append(sp)
			total += float(sp.get("weight", 1.0))
	var pick := rng.randf() * total
	for sp in pool:
		pick -= float(sp.get("weight", 1.0))
		if pick <= 0.0:
			return sp
	return Data.species_of("gold")

## One new creature, or {} when nothing fits right now. Hunters never spawn near you.
func _new_npc(at: Vector2 = Vector2.INF) -> Dictionary:
	var sp := _pick_species()
	if sp.is_empty():
		return {}
	var m: float
	if Data.MASS_RANGE.has(sp.role):
		var rr: Array = Data.MASS_RANGE[sp.role]
		m = player.mass * rng.randf_range(rr[0], rr[1])
	else:
		m = rng.randf_range(sp.mass[0], sp.mass[1])
	m = maxf(m, t("min_npc_mass"))
	var pos := at
	if pos == Vector2.INF:
		if sp.role == "hunter":
			var near := maxf(_spawn_min(), t("hunter_safe"))
			pos = _ring_pos_sep(near, maxf(_spawn_max(), near * 1.7), near)
		else:
			pos = _ring_pos_sep(_spawn_min(), _spawn_max())
	_next_id += 1
	return {"id": _next_id, "pos": pos, "vel": Vector2.ZERO, "mass": m, "species": sp.id, "role": sp.role,
		"flees": rng.randf() < float(sp.flee), "wander": Vector2.RIGHT.rotated(rng.randf() * TAU), "t": rng.randf_range(0.5, 3.0)}

## Adds a creature if one fits; false when none did.
func _spawn_npc(at: Vector2 = Vector2.INF) -> bool:
	var n := _new_npc(at)
	if n.is_empty():
		return false
	npcs.append(n)
	if n.role == "hunter" and sight_rank >= 2:
		_hunter_cd = t("hunter_gap")
	return true

# ---------- the step ----------

## dir: desired heading, length 0..1 (joystick deflection).
func step(delta: float, dir: Vector2) -> void:
	if not alive:
		return
	time += delta
	events.clear()
	_sync_mass()
	hit_t += delta
	grace = maxf(grace - delta, 0.0)
	_hunter_cd = maxf(_hunter_cd - delta, 0.0)
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
	_environment(delta)
	_heal_and_passives(delta)
	_think(delta)
	_resolve(delta)
	_top_up()
	_recycle()
	_check_level_up()
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
		if too_cold > 0.0:
			want *= t("cold_slow")
		# At the surface, pushing up slides you along it at full speed instead of catching on it.
		var top0: float = radius_of(player.mass) * t("surface_margin")
		if player.pos.y <= top0 + 2.0 and want.y < 0.0:
			var spd := want.length()
			want = Vector2(signf(want.x) * spd, 0.0) if absf(want.x) > spd * 0.2 else Vector2(want.x, 0.0)
		player.vel = player.vel.lerp(want, clampf(t("player_accel") * delta * (2.5 if dash_t > 0.0 else 1.0), 0.0, 1.0))
	player.pos += player.vel * delta
	distance += player.vel.length() * delta
	# The surface: the one wall. Sides and depth never end.
	var top: float = radius_of(player.mass) * t("surface_margin")
	if player.pos.y < top:
		player.pos.y = top
		player.vel.y = maxf(player.vel.y, 0.0)
	if player.vel.length() > 5.0:
		facing = player.vel.normalized()

## Water too cold or too deep for your body hurts (and cold slows you). Only once your eye is open
## (when the health bar and the depth / temperature readout appear).
func _environment(delta: float) -> void:
	if not has_bars():
		too_cold = 0.0
		too_deep = 0.0
		return
	var was_cold := too_cold > 0.0
	var was_deep := too_deep > 0.0
	too_cold = maxf(min_temp() - temp(), 0.0)
	too_deep = maxf(depth_m() - max_depth_m(), 0.0)
	if too_cold > 0.0 and not was_cold:
		events.append({"type": "env", "what": "cold"})
	if too_deep > 0.0 and not was_deep:
		events.append({"type": "env", "what": "deep"})
	# Early warning: a good way before the limit, so the cold or the pressure never comes as a surprise.
	var near_cold: bool = too_cold <= 0.0 and temp() < min_temp() + 3.0
	var near_deep: bool = too_deep <= 0.0 and depth_m() > max_depth_m() * (1.0 - t("warn_margin"))
	if near_cold and not _warn_cold:
		events.append({"type": "env_warn", "what": "cold"})
	if near_deep and not _warn_deep:
		events.append({"type": "env_warn", "what": "deep"})
	_warn_cold = near_cold
	_warn_deep = near_deep
	var dmg := 0.0
	var cause := ""
	if too_cold > 0.0:
		dmg += t("cold_dmg") * too_cold
		cause = "cold"
	if too_deep > 0.0:
		var deep_dmg: float = t("deep_dmg") + t("deep_dmg_per100") * too_deep / 100.0
		if deep_dmg > dmg:
			cause = "deep"
		dmg += deep_dmg
	if dmg <= 0.0 or grace > 0.0:
		return
	var k: float = Data.DIFFICULTY[difficulty].get("env", 1.0)
	player.hp -= minf(dmg, t("env_dmg_cap")) * k * delta
	if player.hp <= 0.0 and alive:
		player.hp = 0.0
		alive = false
		death_cause = cause
		events.append({"type": "death", "pos": player.pos})

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
			var stunned := 0
			for n in npcs:
				if n.pos.distance_to(player.pos) < rad:
					n["stun"] = dur
				if float(n.get("stun", 0.0)) > 0.0:
					stunned += 1
			max_stunned = maxi(max_stunned, stunned)
			events.append({"type": "stun_count", "count": stunned})
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
	if hit_t > t("regen_delay") and player.hp < max_hp() and too_cold <= 0.0 and too_deep <= 0.0:
		var rate: float = t("regen") + t("regen_rank") * rank_of("regen")
		rate *= Data.DIFFICULTY[difficulty].regen
		if ailments.has("slow_heal"):
			rate *= t("slow_heal_mult")
		player.hp = minf(player.hp + rate * delta, max_hp())
	if specials.has("photo"):
		_gain_xp(xp_span(level()) * t("photo_rate") * delta)
	if specials.has("magnet"):
		var rng2: float = t("magnet_range") + radius_of(player.mass)
		for i in food.size():
			var d: Vector2 = player.pos - food[i]
			if d.length() < rng2:
				food[i] += d.normalized() * 220.0 * delta
	peak_mass = maxf(peak_mass, player.mass)
	# Badge: fall below 10% health, then recover all the way.
	if player.hp <= max_hp() * 0.1:
		_comeback_armed = true
	elif _comeback_armed and player.hp >= max_hp() - 0.001:
		_comeback_armed = false
		events.append({"type": "comeback"})

func _tick_ailments(delta: float) -> void:
	for k in ailments.keys():
		ailments[k] -= delta
		if ailments[k] <= 0.0:
			ailments.erase(k)
			ail_full.erase(k)
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
	# Only the nearest few hunters chase you at once (Data.DIFFICULTY chasers); the rest keep to themselves.
	var near: Array = []
	for n in npcs:
		if n.role != "hunter" or float(n.get("stun", 0.0)) > 0.0 or not can_eat(n.mass, player.mass):
			continue
		if ink_t > 0.0 and n.pos.distance_to(ink_pos) < ink_r:
			continue
		var dh: float = n.pos.distance_to(player.pos)
		if dh < maxf(sense_floor, radius_of(n.mass) * 6.0):
			near.append([dh, n.id])
	near.sort_custom(_by_first)
	var allowed := {}
	for i in mini(near.size(), mini(int(Data.DIFFICULTY[difficulty].get("chasers", 3)), threat_cap())):
		allowed[near[i][1]] = true
	_snapshot_npcs()
	for i in npcs.size():
		if i > 0:
			_snap_pos[i - 1] = npcs[i - 1].pos      # the one before has moved: _social sees where it is now
			_snap_mass[i - 1] = npcs[i - 1].mass
		var n: Dictionary = npcs[i]
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
		var speed := _npc_speed(n.mass, base_speed * 0.6)
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
		var in_sight: bool = chase_d < sight
		var hunting: bool = role == "hunter" and in_sight and can_eat(n.mass, player.mass) and (allowed.has(n.id) or chase != to_p)
		if hunting and has("warning") and not n.get("hunting", false):
			n["pause"] = t("warning_pause") * rank_of("warning")             # predators hesitate at the warning colours
		if hunting:
			n["chase_t"] = float(n.get("chase_t", 0.0)) + delta
			if not n.has("chased_lvl"):
				n["chased_lvl"] = level()
		elif n.get("hunting", false):
			if float(n.get("chase_t", 0.0)) >= 4.0 and not in_sight:
				events.append({"type": "evaded"})      # a bigger creature chased you and lost you
			n["chase_t"] = 0.0
		n["hunting"] = hunting
		if n.get("pause", 0.0) > 0.0:
			n["pause"] -= delta
			n.vel = n.vel.lerp(Vector2.ZERO, clampf(8.0 * delta, 0.0, 1.0))
			n.pos += n.vel * delta
			continue
		if hunting:
			steer = chase / maxf(chase_d, 0.001)              # hunt
			speed = _npc_speed(n.mass, hunter_speed)
		elif suction_t > 0.0 and (role == "prey" or role == "rare") and d < ability_radius("suction") and d > radius_of(player.mass) * 0.5 and can_eat(player.mass, n.mass, ratio):
			steer = to_p / maxf(d, 0.001)                     # sucked in
			speed = t("suction_pull")
		elif lure_t > 0.0 and (role == "prey" or role == "rare") and d < ability_radius("lure") and d > radius_of(player.mass):
			steer = to_p / maxf(d, 0.001)                     # drawn by the lure
			speed = t("lure_pull")
		elif n.get("flees", role == "rare") and d < sight * 0.7 and can_eat(player.mass, n.mass, ratio):
			steer = -to_p / maxf(d, 0.001)                    # flee
			speed = _npc_speed(n.mass, base_speed * (1.0 if role == "rare" else t("flee_frac")))
		else:
			if n.t <= 0.0:
				n.wander = Vector2.RIGHT.rotated(rng.randf() * TAU)
				n.t = rng.randf_range(1.5, 4.0)
			steer = n.wander * 0.4
			if move_rank == 0:
				speed = t("drift_speed")
			# Creatures of different species are hostile to each other (once you can see); all keep apart.
			var soc := _social(n, i)
			if soc.has("steer"):
				steer = soc.steer
				speed = _npc_speed(n.mass, base_speed * soc.pace)
			elif soc.sep.length() > 0.01:
				steer = (steer + soc.sep * 1.5).limit_length(1.0)
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

static func _by_first(a: Array, b: Array) -> bool:
	return a[0] < b[0]

## Every creature's position, mass, species and "can fight" flag in packed arrays, made once per step:
## _social and _npcs_eat_each_other compare every pair, and reading these is much cheaper than the
## dictionaries (2026-10-29: the two took 8 of the engine's 9 ms a step with 40 creatures).
var _snap_pos := PackedVector2Array()
var _snap_mass := PackedFloat64Array()
var _snap_species: Array = []
var _snap_fights := PackedByteArray()     # 1 = prey / equal / hunter (they hunt and flee each other)

func _snapshot_npcs() -> void:
	var c := npcs.size()
	_snap_pos.resize(c)
	_snap_mass.resize(c)
	_snap_species.resize(c)
	_snap_fights.resize(c)
	for i in c:
		var n: Dictionary = npcs[i]
		_snap_pos[i] = n.pos
		_snap_mass[i] = n.mass
		_snap_species[i] = n.species
		_snap_fights[i] = 1 if (n.role == "prey" or n.role == "equal" or n.role == "hunter") else 0

## Hunt a smaller creature of another species, run from a bigger one, keep apart from the rest.
## `idx` = its place in npcs (and in the snapshot).
func _social(n: Dictionary, idx: int) -> Dictionary:
	var sep := Vector2.ZERO
	var prey_dir := Vector2.ZERO
	var prey_d: float = t("npc_sight")
	var flee := Vector2.ZERO
	var hostile: bool = sight_rank >= 2 and (n.role == "prey" or n.role == "equal" or n.role == "hunter")
	var near_sep: float = t("npc_sep")
	var flee_r: float = t("npc_flee")
	var reach := maxf(maxf(prey_d, flee_r), near_sep)     # nothing farther away matters
	var reach2 := reach * reach
	var ratio: float = TUNING.eat_ratio
	var p: Vector2 = n.pos
	var nm: float = n.mass
	var sp: String = n.species
	for j in _snap_pos.size():
		if j == idx:
			continue
		var dv: Vector2 = _snap_pos[j] - p
		var d2 := dv.length_squared()
		if d2 >= reach2 or d2 < 0.0001:
			continue
		var dist := sqrt(d2)
		if dist < near_sep:
			sep -= dv / dist * (1.0 - dist / near_sep)
		if not hostile or _snap_fights[j] == 0 or _snap_species[j] == sp:
			continue
		var mm: float = _snap_mass[j]
		if nm >= mm * ratio and dist < prey_d:
			prey_d = dist
			prey_dir = dv / dist
		elif mm >= nm * ratio and dist < flee_r:
			flee -= dv / dist * (1.0 - dist / flee_r)
	if flee.length() > 0.01:
		return {"steer": flee.normalized(), "pace": 0.9, "sep": sep}
	if prey_dir != Vector2.ZERO:
		return {"steer": prey_dir, "pace": 0.7, "sep": sep}
	return {"sep": sep}

## Eating on contact: the eater's centre must be inside the victim's rim
## (overlap by the victim's radius) so a graze doesn't swallow.
func _resolve(delta: float) -> void:
	var pr := radius_of(player.mass)
	var gain_mult: float = t("appetite_mult") if ailments.has("appetite") else 1.0
	# Food
	var fr := radius_of(t("food_mass"))
	var keep: Array = []
	for f in food:
		# Food specks are always there and always edible, at any size (owner 2026-10-24: they used to vanish
		# at size 4, being 3 sizes below you).
		if f.distance_to(player.pos) < pr + fr * 0.5:
			_gain_xp(t("food_xp") / float(maxi(level(), 1)) * gain_mult)   # specks feed less the bigger you are (owner 2026-10-29: too fast)
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
		var worth := value_of(n.mass)
		if n.role == "rare" or n.role == "toxic":
			worth = maxi(worth, 1)              # always worth eating (and always shown)
		if worth > 0 and can_eat(player.mass, n.mass, ratio) and d < pr - nr * 0.35:
			_gain_xp(float(worth) * gain_mult)
			eaten_cells += 1
			kills += 1
			eaten_value += worth
			if int(n.get("chased_lvl", 0)) > 0 and level() > int(n.chased_lvl):
				events.append({"type": "revenge"})     # it chased you once; you grew; now it is food
			var sp := Data.species_of(n.species)
			if sp.has("trait"):
				_grant_trait(sp.trait)
			eaten_species[n.species] = int(eaten_species.get(n.species, 0)) + 1
			events.append({"type": "cell", "pos": n.pos, "mass": n.mass, "species": n.species, "role": n.role})
			if has("meal_heal") and not ailments.has("slow_heal"):
				player.hp = minf(player.hp + float(rank_of("meal_heal")), max_hp())
			if n.role == "toxic":
				_poison(n.species)
			elif n.role == "rare":
				_grant_rare(n.species)
			pr = radius_of(player.mass)
			continue
		if n.role == "hunter" and can_eat(n.mass, player.mass) and d < nr + pr * 0.5 and n.get("stun", 0.0) <= 0.0 and n.get("pause", 0.0) <= 0.0:
			var dmg := 0.0 if grace > 0.0 else bite * delta
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
			if player.hp <= 0.0 and alive:
				player.hp = 0.0
				alive = false
				death_cause = "eaten"
				events.append({"type": "death", "pos": player.pos})
		if has("stinger") and (n.role == "hunter" or n.role == "equal") and d < nr + pr * 1.3:
			n.mass = maxf(n.mass - n.mass * t("stinger_rate") * rank_of("stinger") * delta, t("min_npc_mass"))
		left.append(n)
	npcs = left
	_npcs_eat_each_other()
	peak_mass = maxf(peak_mass, player.mass)

## Different species eat each other when one is clearly bigger (once your eye is open).
func _npcs_eat_each_other() -> void:
	if sight_rank < 2 or npcs.size() < 2:
		return
	_snapshot_npcs()
	var c := npcs.size()
	var rad := PackedFloat64Array()
	rad.resize(c)
	for i in c:
		rad[i] = radius_of(_snap_mass[i])
	var ratio: float = TUNING.eat_ratio
	var dead := PackedByteArray()
	dead.resize(c)
	dead.fill(0)
	var eaten := 0
	for i in c:
		if dead[i] == 1 or _snap_fights[i] == 0:
			continue
		var pa: Vector2 = _snap_pos[i]
		for j in c:
			# cheapest tests first: size, then the rest
			if i == j or _snap_mass[i] < _snap_mass[j] * ratio or dead[j] == 1 or _snap_fights[j] == 0:
				continue
			var lim: float = rad[i] - rad[j] * 0.35
			if lim > 0.0 and pa.distance_squared_to(_snap_pos[j]) < lim * lim and _snap_species[i] != _snap_species[j]:
				var a: Dictionary = npcs[i]
				a.mass += _snap_mass[j] * t("absorb")
				_snap_mass[i] = a.mass
				rad[i] = radius_of(a.mass)
				dead[j] = 1
				eaten += 1
	if eaten == 0:
		return
	var keep: Array = []
	for k in c:
		if dead[k] == 0:
			keep.append(npcs[k])
	npcs = keep

func _top_up() -> void:
	var made := 0
	while food.size() < _food_target() and made < int(t("respawn_per_step")):
		food.append(_ring_pos(_spawn_min(), _spawn_max()))
		made += 1
	made = 0
	while npcs.size() < _npc_target() and made < 1:
		if not _spawn_npc():
			break
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

## Endless mode: after dying you come back at the start of your current size (never below your growth stage), full
## health, out of the water that killed you, with everything you evolved: tail, eye, DNA, traits, missions.
func revive() -> void:
	_sync_mass()
	xp = xp_at(level())
	player.mass = mass_of_xp(xp)
	_mass_seen = player.mass
	player.hp = max_hp()
	player.vel = Vector2.ZERO
	player.pos.y = minf(player.pos.y, t("start_depth"))
	ailments = {}
	ail_full = {}
	shots = []
	decoy.t = 0.0
	too_cold = 0.0
	too_deep = 0.0
	hit_t = 99.0
	deaths += 1
	grace = t("revive_grace")
	var keep: Array = []
	for n in npcs:
		if n.role != "hunter" or n.pos.distance_to(player.pos) > 1400.0:
			keep.append(n)
	npcs = keep
	alive = true
	death_cause = ""

# ---------- poison, rare creatures ----------

## A toxic creature was eaten: its own ailment (each kind always gives the same one). Every time counts
## toward the matching resistance; at 5/5 you are immune.
func _poison(species: String = "") -> void:
	var id: String = str(Data.species_of(species).get("ailment", "")) if species != "" else ""
	if not Data.AILMENTS.has(id):
		id = Data.AILMENT_ORDER[rng.randi() % Data.AILMENT_ORDER.size()]
	var before := resist_rank(id)
	ail_count[id] = int(ail_count.get(id, 0)) + 1
	var r := resist_rank(id)
	if r > before:
		events.append({"type": "resist", "id": id, "rank": r})
	if r >= Data.RESIST_AT.size():
		events.append({"type": "immune", "id": id})
		return
	var dur: float = Data.AILMENTS[id].time * pow(t("tox_res_mult"), rank_of("tox_res")) * (1.0 - t("resist_step") * float(r))
	if dur > float(ailments.get(id, 0.0)):
		ailments[id] = dur
		ail_full[id] = dur
	events.append({"type": "ailment", "id": id})

## Rare creature: a tree trait ahead of time, or a special trait, or (if you have everything) DNA. The rarer
## kinds (starfish, seahorse, mermaid, little Poseidon) also give their `dna` on top.
func _grant_rare(species: String = "gold") -> void:
	var bonus: int = int(Data.species_of(species).get("dna", 0)) if species != "" else 0
	if bonus > 0:
		dna += bonus
		events.append({"type": "rare_dna", "species": species, "dna": bonus})
	var pool: Array = []
	for n in Data.NODES:
		if tree_unlocked and reqs_met(n.id) and rank_of(n.id) < int(n.max):
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
	return tree_unlocked and (st == "available" or st == "owned") and reqs_met(id) and dna >= cost_of(id)

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
# Missions are found, not handed out: the tutorial ones come one at a time, the rest appear when you meet
# a new creature or place. Their goals are hidden (a progress bar only) and so are their rewards.

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
		"value":
			return float(eaten_value)
		"kills":
			return float(kills)
		"species":
			return float(eaten_species.get(species, 0))
		"rare":
			var c := 0
			for sp in Data.species_by_role("rare"):
				c += int(eaten_species.get(sp.id, 0))
			return float(c)
	return 0.0

## Current progress of a mission, in its own units.
func progress_of(m: Dictionary) -> float:
	match m.kind:
		"mass":
			return float(level())
		"jolts":
			return float(jolts)
		"surface":
			return 1.0 if surface_hit else 0.0
		"depth":
			return max_depth
	return _counter(m.kind, m.get("species", "")) - float(m.base)

func _track_missions(delta: float) -> void:
	for n in npcs:
		if n.role == "hunter" and can_eat(n.mass, player.mass) and n.pos.distance_to(player.pos) < vision_r:
			escape_time += delta
			break
	if escape_time >= 8.0 and not close_call_sent:
		close_call_sent = true
		events.append({"type": "close_call"})
	max_depth = maxf(max_depth, player.pos.y)
	if player.pos.y < radius_of(player.mass) * t("surface_margin") + 70.0:
		surface_hit = true
	_discover_places()
	for m in missions:
		if m.done:
			continue
		if progress_of(m) >= float(m.target):
			_complete(m)

## New places give new missions once the evolution tree is open.
func _discover_places() -> void:
	if _story < 4:
		return
	if not seen_surface and player.pos.y < vision_r + radius_of(player.mass):
		seen_surface = true
		events.append({"type": "place", "what": "surface"})
		if _open_count() < 5:
			_add_mission({"kind": "surface", "target": 1, "text": "Touch the surface", "reward": _next_reward()})
	var mk: float = t("units_per_m")
	var marks := [150.0 * mk, 350.0 * mk, 650.0 * mk, 1000.0 * mk, 1500.0 * mk]      # 150 m, 350 m, 650 m ...
	if _depth_i < marks.size() and player.pos.y >= marks[_depth_i]:
		var goal: float = marks[_depth_i + 1] if _depth_i + 1 < marks.size() else marks[_depth_i] * 1.5
		_depth_i += 1
		events.append({"type": "place", "what": "deep"})
		if _open_count() < 5:
			_add_mission({"kind": "depth", "target": goal, "text": "Dive deeper", "reward": _next_reward()})

func _tick_missions(delta: float) -> void:
	var keep: Array = []
	for m in missions:
		if m.done:
			m.linger -= delta
			if m.linger <= 0.0:
				continue
		keep.append(m)
	missions = keep

func _set_tail() -> void:
	if move_rank < 1:
		move_rank = 1
		events.append({"type": "tail"})

func _set_eye() -> void:
	if sight_rank < 2:
		sight_rank = 2
		events.append({"type": "eye"})

## A creature that carried the trait was eaten: you get it at once (and the matching mission is done).
func _grant_trait(which: String) -> void:
	for m in missions:
		if not m.done and m.reward == which:
			_complete(m)
			return
	if which == "tail" and move_rank < 1:
		# The tutorial hands out its missions one at a time: skip ahead.
		for m in missions:
			if not m.done and m.kind == "jolts":
				m.done = true
				m.linger = t("mission_linger")
		_set_tail()
		_story = 2
		_add_mission({"kind": "value", "target": t("eye_value"), "text": "Evolve further", "reward": "eye"})

func _complete(m: Dictionary) -> void:
	m.done = true
	m.linger = t("mission_linger")
	missions_done += 1
	events.append({"type": "mission", "text": m.text})
	match m.reward:
		"tail":
			_set_tail()
		"eye":
			_set_eye()
		"tree":
			tree_unlocked = true
			dna += Data.TREE_DNA        # enough for a first trait right away
			events.append({"type": "tree", "dna": Data.TREE_DNA})
		"size":
			_gain_xp(xp_span(level()) * t("story_xp"), false)
			events.append({"type": "grow"})
		"dna":
			dna += 1
			events.append({"type": "dna"})
	# The first missions are the tutorial, in order: move, tail, eye, then growing to size 2 opens the tree
	# (it used to be 10 kills after the eye, which came at size 4-5).
	if _story == 0 and m.kind == "jolts":
		_story = 1
		_add_mission({"kind": "value", "target": t("tail_value"), "text": "Evolve", "reward": "tail"})
	elif _story <= 1 and m.reward == "tail":
		_story = 2
		_add_mission({"kind": "value", "target": t("eye_value"), "text": "Evolve further", "reward": "eye"})
	elif _story == 2 and m.reward == "eye":
		_story = 3
		_add_mission({"kind": "mass", "target": int(t("tree_size")), "text": "Grow to size %d", "args": [int(t("tree_size"))], "reward": "tree"})
	elif _story == 3 and m.reward == "tree":
		_story = 4
		_grow_mission()
		_fill()
	elif _story >= 4:
		if m.kind == "mass":
			_grow_target = float(level() + 1)
			_grow_mission()
		_fill()

func _next_reward() -> String:
	_reward_n += 1
	return "dna"     # a size gift was pointless at 0.5% of a size

func _grow_mission() -> void:
	_grow_target = maxf(_grow_target, float(level() + 1))
	_add_mission({"kind": "mass", "target": int(_grow_target), "text": "Grow to size %d",
		"args": [int(_grow_target)], "reward": ""})     # no points for growing (owner 2026-10-29)

const FEAST_COUNT := 0     # owner 2026-10-29: "Fill your belly" is the same thing as "Grow to size N": only one of them (the grow mission stays)
const FEAST_TEXTS := ["Feast on creatures", "Keep hunting", "Fill your belly"]

## Keeps two ordinary goals on the list besides the grow mission and what you discover.
func _fill() -> void:
	var ordinary := 0
	for m in missions:
		if not m.done and m.kind == "value":
			ordinary += 1
	while ordinary < FEAST_COUNT:
		var target: int = (5 + missions_done) * 40 * maxi(level(), 1)     # was x1: each mission paid a DNA point every ~15 s (owner 2026-10-29)
		_add_mission({"kind": "value", "target": target, "text": FEAST_TEXTS[rng.randi() % FEAST_TEXTS.size()], "reward": _next_reward()})
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
	events.append({"type": "seen", "species": id, "role": sp.role, "trait": sp.get("trait", "")})
	if _story < 4 or _open_count() >= 5 or sp.has("trait"):
		return
	match sp.role:
		"prey":
			_add_mission({"kind": "species", "species": id, "target": 1, "text": "Eat a %s", "args": [sp.name], "reward": _next_reward()})
		"rare":
			if id == "gold":
				_add_mission({"kind": "rare", "target": 1, "text": "Catch a Golden spore", "reward": "dna"})
			else:
				_add_mission({"kind": "species", "species": id, "target": 1, "text": "Catch: %s", "args": [sp.name], "reward": "dna"})

## Fields for the HUD: each mission as {text, args, frac (0..1, shown as a bar), done, kind}.
func mission_rows() -> Array:
	var out: Array = []
	for m in missions:
		var frac := clampf(progress_of(m) / maxf(float(m.target), 0.001), 0.0, 1.0)
		if m.kind == "mass" and not m.done and int(m.target) == level() + 1:
			frac = xp_frac()        # the real progress to the next size (it used to start at 2/3 full: size / target size)
		out.append({"text": m.text, "args": m.args, "frac": frac, "done": m.done, "kind": m.kind})
	return out
