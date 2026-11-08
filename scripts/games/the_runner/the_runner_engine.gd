extends RefCounted

## The Runner's rules (design doc v2, docs/runner/GAME_DESIGN_THE_RUNNER_V2.md): the captain (race,
## perks), stats from perks / crew / faction rep / alignment bars (stacking and caps, §5.3), money
## (clean / dirty), markets, cargo, fuel and travel between sectors, heat and scans, encounters,
## battles (results only: the real-time fight runs in the_runner_battle.gd), laundering, quests,
## contracts, crew, hull tiers and parts, net worth. No Nodes: tests drive it headless
## (tools/test_the_runner.gd). Content comes from the_runner_data.gd and the_runner_spiral.gd.
## Every message it returns is English; screens translate it (tr) before showing.

const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const S = preload("res://scripts/games/the_runner/the_runner_spiral.gd")

const SAVE_VERSION := 2
const FUEL_PRICE := 25            # clean credits per fuel unit
const FUEL_PER_PX := 1.0 / 90.0   # fuel per map pixel flown (before the engine's factor)
const REPAIR_PRICE := 15          # per hull point
const PX_PER_DAY := 420.0         # map pixels flown = one day
const EVENT_EVERY_PX := 320.0     # a mid-flight event may happen once per this many pixels
const EVENT_CHANCE := 0.22
const SLIP := 0.012               # price moves this much per unit you buy or sell
const LAUNDER_RATE := 0.8
const LAUNDER_MAX := 4000         # per batch
const AUDIT_CHANCE := 0.06
const TOW_PRICE := 500
const HEAT_DECAY := 1.5           # per day
const CONTRACTS_PER_PORT := 2
const XP_STEP := 150              # level n -> n+1 needs XP_STEP * n more
const JUMP_FUEL := 2.0            # a gate jump
const GATE_RANGE := 40.0          # map px around the gate
## Flight time (design doc v2 §1.1): a trip between neighbours takes 20-40 s, farther = longer.
const FLIGHT_MIN_S := 20.0
const FLIGHT_MAX_S := 45.0
const FLIGHT_PX_PER_S := 30.0     # flight time = clamp(16 + px / 30, 20, 45) seconds before speed perks
const HAND_PX_PER_S := 32.0       # flying by hand

var rng := RandomNumberGenerator.new()
var seed_value: int = 0

var captain: Dictionary = {}      # name, gender, race, home, picks
var day: int = 1
var clean: int = 400
var dirty: int = 0
var debt: int = S.START_DEBT
var ship: String = "moth"         # "moth" or "runner"
var tier: int = 1                 # the Runner's hull tier (1 Skiff .. 4 Cruiser)
var modules: Dictionary = {}      # slot -> module id (one model per kind)
var specials: Array = []          # special parts fitted (one per special socket)
var owned: Array = []             # module ids bought (any slot)
var fuel: float = 12.0
var hull: int = 60
var sector: String = "cradle_reach"
var loc: String = D.START_WORLD   # world id, or "" while in flight
var cargo: Dictionary = {}        # good -> qty (open hold)
var hidden: Dictionary = {}       # good -> qty (hidden hold)
var paid: Dictionary = {}         # good -> average price paid per unit (for profit)
var heat: Dictionary = {}         # "accord" -> 0..100
var rep: Dictionary = {}          # faction -> FP (-500 .. 1000)
var bars: Dictionary = {"paragon": 0, "outlaw": 0}
var xp: int = 0
var bonus_points: int = 0
var skills: Array = []            # skill ids
var branches: Array = []          # [primary, secondary]
var flags: Dictionary = {}
var quests: Dictionary = {}       # id -> {"state": "active"|"done", "progress": int}
var crew: Array = []              # {id, loyalty}
var recruitable: Array = []       # crew ids whose discovery quest is done (not aboard)
var lost_crew: Array = []         # crew ids that can never join (Hive Debt: handed over)
var nodes: int = 0                # Blind Nodes found (M06 / M09 / M11): +10% stealth each on the Ghost Core
var tributaries: Array = []       # worlds that pay you tribute every day (O25)
var ending: String = ""           # the ending reached ("" = none yet): unify / rule / ghost
var contracts: Array = []         # accepted: {id, kind, good, qty, from, to, pay, money, due, issuer, enemy}
var offers: Dictionary = {}       # world -> Array of contract offers (made per day)
var offers_day: Dictionary = {}   # world -> day the offers were made
var contract_count: Dictionary = {"paragon": 0, "outlaw": 0}
var supply: Dictionary = {}       # world -> {good -> factor}
var events: Dictionary = {}       # world -> {id, good, until}
var news: Array = []              # newest first, English strings or {text, args}
var seen_prices: Dictionary = {}  # world -> {good -> price} the last time you docked there
var laundry: Array = []           # {amount, ready}
var curses: Dictionary = {}       # flaw id -> last day
var used_calls: Array = []        # once-per-run battle calls used
var encounter: Dictionary = {}    # the open encounter, {} = none
var flown_px: float = 0.0         # since the last event roll
var trip_px: float = 0.0          # this trip, for days
var ghost_used: bool = false
var lucky_used: bool = false
var flare: bool = false           # a solar flare: the next scan sees nothing
var stats := {"runs": 0, "scans_passed": 0, "scans_failed": 0, "bribes": 0, "fights_won": 0,
	"fights_lost": 0, "contracts": 0, "best_haul": 0, "profit": 0, "salvages": 0, "trips": 0,
	"best_net": 0, "captured": 0, "laundered": 0, "quests": 0, "jumps": 0, "boarded": 0, "endings": 0}
var pending_story: Array = []     # story ids for the screens to show
var ship_pos := Vector2.ZERO      # on the sector map (map pixels), kept by the map while flying
var tow_to: String = ""           # set by a tow / capture: the map puts the ship there and docks
var _fx: Dictionary = {}          # cached stat table (see _build_fx)
var _fx_ok := false

func _init() -> void:
	reset()

## A new run. `cap`: the captain from character creation ({name, gender, race, home, picks}); a test
## or a quick start passes nothing and gets a Terran of the Concord with two picks.
func reset(p_seed: int = 0, cap: Dictionary = {}) -> void:
	seed_value = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system()) ^ randi()
	rng.seed = seed_value
	captain = default_captain()
	for k in cap:
		captain[k] = cap[k]
	if not S.RACES.has(str(captain.race)) or not S.RACES[captain.race].playable:
		captain.race = "terran"
	var homes: Array = S.RACES[captain.race].homes
	if not homes.has(str(captain.home)):
		captain.home = homes[0]
	day = 1
	clean = 400
	dirty = 0
	debt = S.START_DEBT
	ship = "moth"
	tier = 1
	modules = D.START_MODULES.duplicate()
	specials = []
	owned = []
	sector = "cradle_reach"
	loc = D.START_WORLD
	cargo = {}
	hidden = {}
	paid = {}
	heat = {"accord": 0.0}
	rep = {}
	for f in S.FACTION_ORDER:
		rep[f] = 0
	rep[str(captain.home)] = S.REP_START
	bars = {"paragon": 0, "outlaw": 0}
	xp = 0
	bonus_points = 0
	skills = []
	branches = []
	flags = {}
	quests = {}
	crew = []
	recruitable = []
	lost_crew = []
	nodes = 0
	tributaries = []
	ending = ""
	contracts = []
	offers = {}
	offers_day = {}
	contract_count = {"paragon": 0, "outlaw": 0}
	supply = {}
	events = {}
	news = []
	seen_prices = {}
	laundry = []
	curses = {}
	used_calls = []
	encounter = {}
	flown_px = 0.0
	trip_px = 0.0
	ghost_used = false
	lucky_used = false
	flare = false
	tow_to = ""
	for k in stats:
		stats[k] = 0
	pending_story = ["prologue"]
	_fx_ok = false
	fuel = float(tank())
	hull = max_hull()
	ship_pos = pos_of(loc)
	accept_quest("N01")
	_remember_prices(loc)

static func default_captain() -> Dictionary:
	return {"name": "Runner", "gender": "Other", "race": "terran", "home": "terran_concord", "picks": ["G09", "G16"]}

## A message for the screens: an English template and its values (strings among them are names,
## translated too). The screen shows tr(text) % args.
static func _l(text: String, args: Array = []) -> Dictionary:
	return {"text": text, "args": args}

# ================================================================ perks and stats (§5)

## Every perk the ship carries: [perk id, strength, source]. Source: "race", "pick", a crew id,
## a faction id (100% rep free perk) or "curse".
func perk_list() -> Array:
	var out := []
	var r: Dictionary = S.RACES[captain.race]
	for p in r.perks:
		out.append([p, 1.0, "race"])
	out.append([r.flaw, 1.0, "race"])
	for p in captain.get("picks", []):
		if S.PERKS.has(p):
			out.append([p, 1.0, "pick"])
	for m in crew:
		var cd: Dictionary = S.CREW[m.id]
		var r2 := int(m.get("rank", 1)) >= 2   # loyalty quest done: personal perk x1.5, quirk at 25%
		out.append([cd.racial, 1.0, m.id])
		out.append([cd.personal, S.RANK2_PERK if r2 else 1.0, m.id])
		out.append([cd.quirk, S.RANK2_QUIRK if r2 else float(D.CONFIG.crew_flaw_strength), m.id])
	for f in S.FACTION_ORDER:
		for t in ["50", "75", "100"]:
			if rep_of(f) >= int(t) * 10 and S.FACTIONS[f].bonuses.has(t):
				var p := str(S.FACTIONS[f].bonuses[t].fx.get("perk", ""))
				if p != "":
					out.append([p, 1.0, f])
	for c in curses:
		if int(curses[c]) >= day:
			out.append([c, 1.0, "curse"])
	return out

## Bonuses from faction rep (50/75/100%) and alignment milestones that are active now: Array of fx.
func active_bonuses() -> Array:
	var out := []
	for f in S.FACTION_ORDER:
		for t in ["50", "75", "100"]:
			if rep_of(f) >= int(t) * 10 and S.FACTIONS[f].bonuses.has(t):
				var fx: Dictionary = S.FACTIONS[f].bonuses[t].fx.duplicate()
				fx["_faction"] = f
				out.append(fx)
	for b in ["paragon", "outlaw"]:
		for m in S.BAR_MILESTONES[b]:
			if int(bars[b]) >= int(m[0]):
				out.append(m[3])
	return out

func _invalidate() -> void:
	_fx_ok = false

## The stat table: same perk from two sources = 100% + 50%, no third (§5.3, perk_stack_cap); good
## perks and bonuses capped at +60% per stat, flaws at -40%.
func _build_fx() -> void:
	var by_perk := {}
	for e in perk_list():
		if not by_perk.has(e[0]):
			by_perk[e[0]] = []
		by_perk[e[0]].append(float(e[1]))
	var good := {}
	var bad := {}
	var flag := {}
	var cap: int = int(D.CONFIG.perk_stack_cap)
	for p in by_perk:
		var ws: Array = by_perk[p]
		ws.sort()
		ws.reverse()
		var strength := 0.0
		for i in mini(cap, ws.size()):
			strength += float(ws[i]) * (1.0 if i == 0 else 0.5)
		var pd: Dictionary = S.PERKS[p]
		for k in pd.fx:
			if S.FLAG_STATS.has(k):
				flag[k] = maxi(int(flag.get(k, 0)), int(pd.fx[k])) if k != "quest_slots" else int(flag.get(k, 0)) + int(pd.fx[k])
			elif pd.kind == "flaw":
				bad[k] = float(bad.get(k, 0.0)) + float(pd.fx[k]) * strength
			else:
				good[k] = float(good.get(k, 0.0)) + float(pd.fx[k]) * strength
	for fx in active_bonuses():
		for k in fx:
			var v = fx[k]
			if str(k).begins_with("_") or str(k).contains("@") or k in ["ability", "perk"]:
				continue
			if S.FLAG_STATS.has(k):
				flag[k] = int(flag.get(k, 0)) + int(v) if k == "quest_slots" else maxi(int(flag.get(k, 0)), int(v))
			elif k == "all_ship":
				for s in ["hull", "shield", "speed", "weapon_damage", "cargo_cap"]:
					good[s] = float(good.get(s, 0.0)) + float(v)
			elif v is float:
				good[k] = float(good.get(k, 0.0)) + float(v)
			else:
				flag[k] = maxi(int(flag.get(k, 0)), int(v))
	if ghost_core() and nodes > 0:
		good["stealth"] = float(good.get("stealth", 0.0)) + S.NODE_STEALTH * nodes
	for pair in S.SYNERGY:
		if _synergy(str(pair[0]), str(pair[1])):
			good[pair[2]] = float(good.get(pair[2], 0.0)) + S.SYNERGY_BONUS
	var out := {}
	for k in good:
		out[k] = clampf(float(good[k]), -S.GOOD_CAP, S.GOOD_CAP)
	for k in bad:
		out[k] = float(out.get(k, 0.0)) + clampf(float(bad[k]), -S.FLAW_CAP, S.FLAW_CAP)
	for k in flag:
		out[k] = int(flag[k])
	_fx = out
	_fx_ok = true

## A stat modifier: 0.15 = +15%. Flags return 0 / 1 (quest_slots a count).
func stat(key: String) -> float:
	if not _fx_ok:
		_build_fx()
	return float(_fx.get(key, 0.0))

func flag(key: String) -> bool:
	return stat(key) > 0.0

## A bonus that only counts at some worlds: "@home" (that faction's worlds), "@paragon" (Accord
## worlds), "@lawless" (law 0). Returns the summed value at world `w`.
func local_bonus(key: String, w: String) -> float:
	if w == "":
		return 0.0
	var wd := world(w)
	var t := 0.0
	for fx in active_bonuses():
		for k in fx:
			if not str(k).begins_with(key + "@"):
				continue
			var scope: String = str(k).split("@")[1]
			var hit := false
			match scope:
				"home": hit = str(wd.get("faction", "")) == str(fx.get("_faction", ""))
				"paragon": hit = bloc_of_world(w) == "paragon"
				"lawless": hit = int(wd.get("law", 0)) == 0
			if hit:
				t += float(fx[k])
	return t

## Races aboard (the captain's and every crew member's).
func races_aboard() -> Array:
	var out := [str(captain.race)]
	for m in crew:
		out.append(str(S.CREW[m.id].race))
	return out

func _synergy(a: String, b: String) -> bool:
	var rs := races_aboard()
	if not rs.has(a):
		return false
	if b == "any":
		return rs.size() > rs.count(a)
	return rs.has(b)

## Battle calls available now (once per run each): ability ids.
func calls() -> Array:
	var out := []
	for fx in active_bonuses():
		var a := str(fx.get("ability", ""))
		if a != "" and not out.has(a):
			out.append(a)
	return out

func call_ready(a: String) -> bool:
	return calls().has(a) and not used_calls.has(a)

# ================================================================ ship stats

func _mod(slot: String) -> Dictionary:
	return D.MODULES.get(modules.get(slot, ""), {})

func _special_sum(key: String) -> float:
	var t := 0.0
	for id in specials:
		t += float(D.MODULES.get(id, {}).get(key, 0.0))
	return t

func has_skill(id: String) -> bool:
	return skills.has(id)

## The hull's numbers: the Moth, or the Runner at its tier.
func hull_data() -> Dictionary:
	if ship == "runner":
		return D.TIERS[clampi(tier, 1, D.TIERS.size()) - 1]
	return D.SHIPS[ship]

func ship_name() -> String:
	return "The Runner" if ship == "runner" else str(D.SHIPS[ship].name)

func sockets(kind: String) -> int:
	return int(hull_data().get(kind, 1))

func crew_slots() -> int:
	return int(hull_data().crew)

func cargo_cap() -> int:
	var base := int(hull_data().cargo) + int(_mod("cargo").get("cargo", 0))
	return maxi(1, int(round(base * (1.0 + stat("cargo_cap")))))

func hidden_cap() -> int:
	var base := int(hull_data().hidden) + int(_mod("hidden").get("hidden", 0)) + (2 if has_skill("sm_hold") else 0)
	return maxi(0, int(round(base * (1.0 + stat("hidden_cap")))))

func tank() -> int:
	return int(round(int(hull_data().tank) * (1.0 + stat("tank"))))

func max_hull() -> int:
	var base := int(hull_data().hull) + (20 if has_skill("en_armor") else 0)
	return maxi(10, int(round(base * (1.0 + stat("hull")))))

## Shield pool for battles: the fitted model on every shield socket.
func shield() -> int:
	return int(round(float(_mod("shields").get("shield", 0)) * sockets("shields") * (1.0 + stat("shield"))))

func guns() -> int:
	return sockets("weapons") + (1 if has_skill("en_gunnery") else 0)

func stealth() -> int:
	var s := int(hull_data().get("stealth", 0)) + int(_special_sum("stealth"))
	if ghost_core():
		s += D.GHOST_STEALTH
	return s

## The Runner's Ghost Core is aboard (not while Queen Vask has it, M10).
func ghost_core() -> bool:
	return ship == "runner" and not flags.has("core_stolen")

func hold_quality() -> int:
	return int(_mod("hidden").get("quality", 0))

func fuel_factor() -> float:
	return clampf(float(_mod("engine").get("fuel", 1.0)) * (1.0 + stat("fuel_use")), 0.25, 3.0)

## Flight speed factor: perks, extra engines, the engine model.
func speed_mult() -> float:
	return maxf(0.4, 1.0 + stat("speed") + 0.08 * (sockets("engines") - 1) + float(_mod("engine").get("speed", 0.0)))

func can_sniff() -> bool:
	return bool(_mod("scanner").get("sniff", false)) or stat("scanner_range") >= 0.10

func used(hold: Dictionary) -> int:
	var n := 0
	for g in hold:
		n += int(hold[g])
	return n

func qty(good: String) -> int:
	return int(cargo.get(good, 0)) + int(hidden.get(good, 0))

func contraband_aboard() -> int:
	var n := 0
	for g in D.GOODS:
		if D.GOODS[g].contraband:
			n += qty(g)
	return n

func contraband_in_open() -> int:
	var n := 0
	for g in cargo:
		if D.GOODS[g].contraband:
			n += int(cargo[g])
	return n

# ================================================================ money

func total_credits() -> int:
	return clean + dirty

## Pays `amount`: "clean" from clean only, "dirty" from dirty first then clean, "any" the same.
func can_pay(amount: int, money: String) -> bool:
	if money == "clean":
		return clean >= amount
	return clean + dirty >= amount

func pay(amount: int, money: String) -> bool:
	if not can_pay(amount, money):
		return false
	if money == "clean":
		clean -= amount
	else:
		var from_dirty := mini(dirty, amount)
		dirty -= from_dirty
		clean -= amount - from_dirty
	return true

func _earn(amount: int, money: String) -> void:
	if money == "dirty":
		dirty += amount
	else:
		clean += amount

func modules_value() -> int:
	var v := 0
	for slot in modules:
		v += int(D.MODULES[modules[slot]].price / 2)
	for id in specials:
		v += int(D.MODULES[id].price / 2)
	if ship == "runner":
		v += int(D.TIERS[tier - 1].cost / 2)
	return v

func cargo_value() -> int:
	var v := 0
	for g in D.GOODS:
		var n := qty(g)
		if n > 0:
			v += n * int(D.GOODS[g].base)
	return v

## Clean + assets + 30% of dirty (minus what you owe).
func net_worth() -> int:
	return clean + modules_value() + cargo_value() + int(dirty * 0.3) - debt

# ================================================================ levels and skills

func level() -> int:
	return int(xp_into_level()[2])

## [xp into this level, xp this level needs, level].
func xp_into_level() -> Array:
	var lv := 1
	var need := XP_STEP
	var left := xp
	while left >= need:
		left -= need
		lv += 1
		need = XP_STEP * lv
	return [left, need, lv]

func skill_points() -> int:
	return level() - 1 + bonus_points - skills.size()

func add_xp(n: int) -> void:
	xp += maxi(0, int(round(n * (1.0 + stat("xp")))))

func branch_open(b: String) -> bool:
	return branches.has(b) or branches.size() < 2

## The next skill to learn in a branch ("" when the branch is full).
func next_skill(b: String) -> String:
	for s in D.SKILLS[b]:
		if not skills.has(s.id):
			return s.id
	return ""

func can_learn(b: String) -> bool:
	return skill_points() > 0 and branch_open(b) and next_skill(b) != ""

func learn(b: String) -> bool:
	if not can_learn(b):
		return false
	if not branches.has(b):
		branches.append(b)
	var id := next_skill(b)
	skills.append(id)
	if id == "en_armor":
		hull = mini(max_hull(), hull + 20)
	return true

## Forger capstone: wipe heat once.
func use_ghost_identity() -> bool:
	if not has_skill("fo_ghost") or ghost_used:
		return false
	ghost_used = true
	heat["accord"] = 0.0
	return true

# ================================================================ factions and bars (§7, §8)

func rep_of(f: String) -> int:
	return int(rep.get(f, 0))

## Rep as a percentage (-50 .. 100).
func rep_pct(f: String) -> int:
	return int(rep_of(f) / 10)

func faction_of(w: String) -> String:
	return str(world(w).get("faction", "none"))

func bloc_of_world(w: String) -> String:
	return str(S.FACTIONS.get(faction_of(w), {}).get("bloc", "neutral"))

## Change a faction's rep. Gains grow with Charismatic (faction_gain). Returns the change made.
func add_rep(f: String, n: int) -> int:
	if not S.FACTIONS.has(f) or f == "none" or n == 0:
		return 0
	if n > 0:
		n = int(round(n * (1.0 + stat("faction_gain"))))
	var before := rep_of(f)
	rep[f] = clampi(before + n, int(D.CONFIG.faction_rep_min), int(D.CONFIG.faction_rep_max))
	_invalidate()
	for t in [500, 750, 1000]:
		if before < t and rep_of(f) >= t:
			news.push_front(_l("%s: you reached %d%% rep. New bonus.", [S.FACTIONS[f].name, t / 10]))
	if before >= 0 and rep_of(f) < 0:
		news.push_front(_l("%s no longer offers you work.", [S.FACTIONS[f].name]))
	if before >= S.REP_HOSTILE and rep_of(f) < S.REP_HOSTILE:
		news.push_front(_l("%s ships will now attack you on sight.", [S.FACTIONS[f].name]))
	if f == "black_meridian" and rep_of(f) >= 1000 and not flags.has("seat") and debt > 0:
		flags["seat"] = true
		debt = 0
		news.push_front(_l("Syndicate Seat: Mother Kessel tears up your debts."))
	return rep_of(f) - before

func hostile(f: String) -> bool:
	return f != "none" and S.FACTIONS.has(f) and rep_of(f) < S.REP_HOSTILE

## Can you buy rep with `f` here? (its office, up to +50%)
func can_buy_rep(f: String) -> bool:
	return loc != "" and has_service("office") and faction_of(loc) == f \
		and rep_of(f) + S.REP_BUY_STEP <= S.REP_BUY_MAX and can_pay(S.REP_BUY_PRICE, "any")

func buy_rep(f: String) -> bool:
	if not can_buy_rep(f):
		return false
	pay(S.REP_BUY_PRICE, "any")
	rep[f] = rep_of(f) + S.REP_BUY_STEP
	_invalidate()
	return true

## Price factor at a world from your rep with its holder: 25% = -5%, 50% = -10%, below 0 = +20%.
func rep_price_factor(w: String) -> float:
	var f := faction_of(w)
	if f == "none":
		return 1.0
	var r := rep_of(f)
	if r < 0:
		return 1.0 + S.REP_PENALTY_PRICES
	if r >= S.REP_DISCOUNT:
		return 0.90
	if r >= S.REP_SAFE:
		return 0.95
	return 1.0

## Ports closed to you (below -25% with the holder). Fuel still sells, so no run can get stuck.
func port_closed(w: String = "") -> bool:
	return hostile(faction_of(w if w != "" else loc))

## Add to the Paragon or Outlaw bar (they never go down, §8).
func add_bar(b: String, n: int) -> void:
	if n <= 0 or not bars.has(b):
		return
	var before := int(bars[b])
	bars[b] = mini(100, before + n)
	_invalidate()
	for m in S.BAR_MILESTONES[b]:
		if before < int(m[0]) and int(bars[b]) >= int(m[0]):
			news.push_front(_l("New title: %s.", [m[1]]))

func title_of(b: String) -> String:
	var t := ""
	for m in S.BAR_MILESTONES[b]:
		if int(bars[b]) >= int(m[0]):
			t = str(m[1])
	return t

# ================================================================ heat

func heat_of(_f: String = "accord") -> float:
	return float(heat.get("accord", 0.0))

func heat_tier(_f: String = "accord") -> String:
	var h := heat_of()
	for t in D.HEAT_TIERS:
		if h <= float(t[0]):
			return str(t[1])
	return "Public Enemy"

func add_heat(_f: String, n: float) -> void:
	if n > 0:
		n *= 1.0 + stat("heat_gain")
		if has_skill("fo_spoof"):
			n *= 0.75
	heat["accord"] = clampf(heat_of() + n, 0.0, 100.0)

func max_heat() -> float:
	return heat_of()

func _cool_heat(days: int) -> void:
	var rate := HEAT_DECAY * (2.0 if has_skill("sm_lanes") else 1.0)
	if loc != "" and bool(world(loc).get("blind", false)):
		rate *= 2.0
	rate *= 1.0 + local_bonus("heat_decay", loc)
	if flags.has("safehouse"):
		rate *= 2.0   # M08
	heat["accord"] = maxf(0.0, heat_of() - rate * days)

# ================================================================ markets

func world(id: String = "") -> Dictionary:
	return D.WORLDS.get(id if id != "" else loc, {})

func has_service(s: String, w: String = "") -> bool:
	if w == "":
		w = loc
	if port_closed(w) and s != "fuel":
		return false
	return world(w).get("services", []).has(s)

func law_at(w: String) -> int:
	var l := int(world(w).get("law", 0))
	if events.has(w):
		for e in D.EVENTS:
			if e.id == events[w].id:
				l += int(e.law)
	return clampi(l, 0, 5)

func black_market_open(w: String = "") -> bool:
	if not flags.has("black_market"):
		return false
	if bool(world(w).get("black", false)):
		return true
	return flag("black_everywhere") and has_service("market", w)

## Can this good be traded here at all?
func trades(good: String, w: String = "") -> bool:
	if not has_service("market", w):
		return false
	if D.GOODS[good].contraband:
		return black_market_open(w)
	return true

func _supply(w: String, good: String) -> float:
	return float(supply.get(w, {}).get(good, 1.0))

func _event_mult(w: String, good: String) -> float:
	if not events.has(w):
		return 1.0
	var ev: Dictionary = events[w]
	for e in D.EVENTS:
		if e.id != ev.id:
			continue
		var hit := false
		match str(e.goods):
			"contraband": hit = D.GOODS[good].contraband
			"festival": hit = good == "food" or good == "medicine"
			"strike": hit = good == "ore" or good == "alloys"
			"one": hit = good == str(ev.get("good", ""))
		return float(e.mult) if hit else 1.0
	return 1.0

## The market's own price of one unit at world `w` (before your perks and rep).
func base_price(good: String, w: String = "") -> int:
	if w == "":
		w = loc
	var g: Dictionary = D.GOODS[good]
	var wd: Dictionary = world(w)
	var f := float(wd.get("makes", {}).get(good, 1.0)) * float(wd.get("wants", {}).get(good, 1.0))
	if g.contraband:
		f *= 1.0 + 0.12 * law_at(w)   # risk premium
	f *= _event_mult(w, good) * _supply(w, good)
	return maxi(1, int(round(float(g.base) * f)))

## What you pay for one unit at `w`.
func price(good: String, w: String = "") -> int:
	if w == "":
		w = loc
	return maxi(1, int(round(base_price(good, w) * (1.0 + stat("buy_price")) * rep_price_factor(w))))

## What one unit sells for at `w`.
func sell_price(good: String, w: String = "") -> int:
	if w == "":
		w = loc
	var f := 0.92 * (1.0 + stat("sell_price"))
	if D.GOODS[good].contraband:
		f *= 1.0 + stat("black_sell")
	if rep_of(faction_of(w)) < 0:
		f /= 1.0 + S.REP_PENALTY_PRICES
	# perks never let you sell above what this dock charges (no buy-and-sell loop)
	return maxi(1, mini(int(base_price(good, w) * f), int(price(good, w) * 0.97)))

func _move_supply(w: String, good: String, units: int) -> void:
	if not supply.has(w):
		supply[w] = {}
	supply[w][good] = clampf(_supply(w, good) + SLIP * units, 0.55, 1.7)

## Free space for a good: contraband fills the hidden hold first.
func space_for(good: String) -> int:
	var free_open := cargo_cap() - used(cargo)
	if D.GOODS[good].contraband:
		return free_open + hidden_cap() - used(hidden)
	return maxi(0, free_open)

func max_buy(good: String) -> int:
	var p := price(good)
	var money := total_credits() if D.GOODS[good].contraband else clean
	return maxi(0, mini(space_for(good), money / maxi(1, p)))

## Buy `n` units (or fewer if space or money run out). Contraband is paid dirty first, legal goods
## clean only. Returns how many were bought.
func buy(good: String, n: int) -> int:
	if loc == "" or not trades(good):
		return 0
	var bought := 0
	var contra: bool = D.GOODS[good].contraband
	for i in n:
		if space_for(good) <= 0:
			break
		var p := price(good)
		if not pay(p, "dirty" if contra else "clean"):
			break
		var old_n := qty(good)
		paid[good] = (float(paid.get(good, 0.0)) * old_n + p) / float(old_n + 1)
		_stow(good, 1)
		_move_supply(loc, good, 1)
		bought += 1
	return bought

func _stow(good: String, n: int) -> void:
	for i in n:
		if D.GOODS[good].contraband and used(hidden) < hidden_cap():
			hidden[good] = int(hidden.get(good, 0)) + 1
		elif used(cargo) < cargo_cap():
			cargo[good] = int(cargo.get(good, 0)) + 1
		elif used(hidden) < hidden_cap():
			hidden[good] = int(hidden.get(good, 0)) + 1

func _take(good: String, n: int) -> int:
	var took := 0
	for i in n:
		if int(cargo.get(good, 0)) > 0:
			cargo[good] = int(cargo[good]) - 1
		elif int(hidden.get(good, 0)) > 0:
			hidden[good] = int(hidden[good]) - 1
		else:
			break
		took += 1
	if int(cargo.get(good, 0)) <= 0:
		cargo.erase(good)
	if int(hidden.get(good, 0)) <= 0:
		hidden.erase(good)
	if qty(good) == 0:
		paid.erase(good)
	return took

## Units of a good that quest or contract cargo still needs (not for sale).
func reserved(good: String) -> int:
	var n := 0
	for c in contracts:
		if str(c.get("kind", "carry")) == "carry" and c.good == good:
			n += int(c.qty)
	for id in quests:
		if quests[id].state == "active" and S.QUESTS[id].get("give", {}).has(good):
			n += int(S.QUESTS[id].give[good])
	return mini(n, qty(good))

## Sell up to `n` units. Contraband pays dirty, legal goods clean. Returns credits earned.
func sell(good: String, n: int) -> int:
	if loc == "" or not trades(good):
		return 0
	n = mini(n, qty(good) - reserved(good))
	var earned := 0
	var cost := float(paid.get(good, 0.0))
	for i in n:
		var p := sell_price(good)
		if _take(good, 1) == 0:
			break
		earned += p
		_move_supply(loc, good, -1)
	if earned <= 0:
		return 0
	_earn(earned, "dirty" if D.GOODS[good].contraband else "clean")
	var profit := earned - int(cost * n)
	if profit > 0:
		stats.profit += profit
		add_xp(profit / 100)
		stats.best_haul = maxi(int(stats.best_haul), profit)
	return earned

## Move contraband between holds (the open hold is seen by any inspection).
func to_hidden(good: String) -> bool:
	if int(cargo.get(good, 0)) <= 0 or used(hidden) >= hidden_cap():
		return false
	cargo[good] = int(cargo[good]) - 1
	if int(cargo[good]) <= 0:
		cargo.erase(good)
	hidden[good] = int(hidden.get(good, 0)) + 1
	return true

## Throw cargo out of the airlock (never what a job or quest still needs).
func dump(good: String, n: int) -> int:
	return _take(good, mini(n, qty(good) - reserved(good)))

func _remember_prices(w: String) -> void:
	if not has_service("market", w):
		return
	var p := {}
	for g in D.GOOD_ORDER:
		if trades(g, w):
			p[g] = price(g, w)
	seen_prices[w] = p
	seen_prices[w]["_day"] = day

# ================================================================ fuel, repair, laundering

func fuel_price() -> int:
	return FUEL_PRICE + (5 if law_at(loc) >= 4 else 0)

func buy_fuel(units: int = -1) -> int:
	if not has_service("fuel"):
		return 0
	var room := int(floor(float(tank()) - fuel))
	if units < 0 or units > room:
		units = room
	var n := mini(units, total_credits() / fuel_price())
	if n <= 0:
		return 0
	pay(n * fuel_price(), "any")
	fuel = minf(float(tank()), fuel + n)
	return n

func repair_unit() -> float:
	if local_bonus("free_repair", loc) > 0:
		return 0.0
	return maxf(1.0, REPAIR_PRICE * (1.0 + stat("repair_cost") + local_bonus("repair_cost", loc)))

func repair_cost() -> int:
	return int(ceil((max_hull() - hull) * repair_unit()))

func repair() -> bool:
	if not has_service("shipyard") or hull >= max_hull():
		return false
	var cost := repair_cost()
	if not can_pay(cost, "any"):
		var pts := int(total_credits() / repair_unit())
		if pts <= 0:
			return false
		pay(int(ceil(pts * repair_unit())), "any")
		hull += pts
		return true
	pay(cost, "any")
	hull = max_hull()
	return true

func launder_rate() -> float:
	var fee := 1.0 - LAUNDER_RATE - (0.08 if has_skill("la_books") else 0.0)
	return clampf(1.0 - fee * (1.0 + stat("launder_fee")), 0.5, 0.98)

func launder(amount: int) -> bool:
	if not has_service("front") or amount <= 0 or amount > dirty or not flags.has("black_market"):
		return false
	amount = mini(amount, LAUNDER_MAX)
	dirty -= amount
	laundry.append({"amount": amount, "ready": day + (1 if has_skill("la_fast") else 2)})
	return true

## Laundry that is ready pays out (an audit may take half and add heat).
func _collect_laundry() -> Array:
	var msgs := []
	var keep := []
	for b in laundry:
		if day < int(b.ready):
			keep.append(b)
			continue
		var out := int(int(b.amount) * launder_rate())
		if not has_skill("la_offshore") and rng.randf() < AUDIT_CHANCE:
			out /= 2
			add_heat("accord", 10)
			msgs.append(_l("Audit at the laundry! Half the batch was seized."))
		clean += out
		stats.laundered += out
		msgs.append(_l("Laundry ready: %d clean credits.", [out]))
	laundry = keep
	return msgs

# ================================================================ travel

func sector_of(w: String) -> String:
	return str(world(w).get("sector", "cradle_reach"))

func sector_open(s: String) -> bool:
	var u := str(D.SECTORS[s].unlock)
	return u == "" or flags.has(u)

func worlds_in(s: String) -> Array:
	var out := []
	for w in D.WORLD_ORDER:
		if sector_of(w) == s:
			out.append(w)
	return out

func pos_of(w: String) -> Vector2:
	var p: Array = D.WORLDS[w].pos
	return Vector2(float(p[0]), float(p[1]))

func gate_pos(s: String = "") -> Vector2:
	var g: Array = D.SECTORS[s if s != "" else sector].gate
	return Vector2(float(g[0]), float(g[1]))

func map_size(s: String = "") -> Vector2:
	var z: Array = D.SECTORS[s if s != "" else sector].size
	return Vector2(float(z[0]), float(z[1]))

func distance_to(w: String) -> float:
	if sector_of(w) != sector:
		return INF
	return pos_of(w).distance_to(ship_pos)

func fuel_for(px: float) -> float:
	return px * FUEL_PER_PX * fuel_factor()

func can_reach(w: String) -> bool:
	return sector_of(w) == sector and fuel_for(distance_to(w)) <= fuel + 0.001

## Seconds an autopilot trip of `px` takes (20-45 s for neighbours, faster with speed perks).
func flight_seconds(px: float) -> float:
	return clampf(16.0 + px / FLIGHT_PX_PER_S, FLIGHT_MIN_S, FLIGHT_MAX_S) / speed_mult()

func hand_speed() -> float:
	return HAND_PX_PER_S * speed_mult()

## Leave the current world (the map then moves the ship and calls fly() as it goes).
func launch() -> bool:
	if loc == "" or not encounter.is_empty():
		return false
	loc = ""
	trip_px = 0.0
	stats.trips += 1
	return true

## The ship flew `px` map pixels: fuel burns, hull self-repairs, and now and then something happens.
## Returns true if an encounter opened (the map stops the ship until it is closed).
func fly(px: float, at: Vector2 = Vector2.ZERO, secs: float = 0.0) -> bool:
	if px <= 0.0 or not encounter.is_empty():
		return false
	fuel = maxf(0.0, fuel - fuel_for(px))
	trip_px += px
	flown_px += px
	_regen(secs)
	if fuel <= 0.0:
		_open({"kind": "no_fuel", "at": [at.x, at.y]})
		return true
	for h in D.SECTORS[sector].hazards:
		var hp := Vector2(float(h.pos[0]), float(h.pos[1]))
		var key := "in_" + str(h.id)
		if at != Vector2.ZERO and at.distance_to(hp) < float(h.r) and not flags.has(key):
			flags[key] = true
			_open({"kind": str(h.kind), "hazard": str(h.name)})
			return true
		if at.distance_to(hp) >= float(h.r) + 20.0:
			flags.erase(key)
	if flown_px >= EVENT_EVERY_PX:
		flown_px = 0.0
		if rng.randf() < EVENT_CHANCE:
			_random_event()
			return true
	return false

## Field Medic, Node Link, Heartwood, Repair Nanites: hull per minute of flight.
var _regen_acc := 0.0
func _regen(secs: float) -> void:
	var r := stat("hull_regen") + _special_sum("regen")
	if r <= 0.0 or secs <= 0.0 or hull >= max_hull():
		return
	_regen_acc += max_hull() * r * secs / 60.0
	if _regen_acc >= 1.0:
		var n := int(_regen_acc)
		_regen_acc -= n
		hull = mini(max_hull(), hull + n)

func _days_for(px: float) -> int:
	return maxi(1, int(ceil(px / PX_PER_DAY)))

## Near the sector's gate?
func at_gate() -> bool:
	return loc == "" and ship_pos.distance_to(gate_pos()) < GATE_RANGE

## Jump through the gate to another sector (arrive at its gate, in flight).
func jump(to: String) -> bool:
	if not at_gate() or to == sector or not D.SECTORS.has(to) or not sector_open(to) or fuel < JUMP_FUEL:
		return false
	fuel -= JUMP_FUEL
	sector = to
	ship_pos = gate_pos(to)
	pass_days(1)
	stats.jumps += 1
	return true

## Dock at world `w` (the ship is on it). Time passes, prices move, then: a quest or bounty battle,
## a hostile faction's ships, a patrol scan or raiders. Returns the encounter opened ({} = none).
func arrive(w: String) -> Dictionary:
	loc = w
	sector = sector_of(w)
	ship_pos = pos_of(w)
	var days := _days_for(trip_px)
	trip_px = 0.0
	stats.runs += 1
	pass_days(days)
	_remember_prices(w)
	_quest_arrival(w)
	if encounter.is_empty() and hostile(faction_of(w)):
		_open_battle("warship", "Their ships attack on sight.", {"faction": faction_of(w)})
	if encounter.is_empty() and not (local_bonus("safe_dock", w) > 0) and str(flags.get("safe_dock", "")) != w:
		_maybe_scan(w)
	var pirate_p := 0.12 + float(bars.outlaw) / 400.0
	if bloc_of_world(w) == "paragon":
		pirate_p *= 1.0 + local_bonus("piracy", w)
	if encounter.is_empty() and law_at(w) <= 1 and rng.randf() < pirate_p:
		_open_pirates("Raiders were waiting at the dock.")
	return encounter

func pass_days(days: int) -> void:
	for i in days:
		day += 1
		_check_burned()   # before the day's cooling: heat 100 and a disloyal crew = Burned
		_cool_heat(1)
		for w in supply:
			for g in supply[w]:
				supply[w][g] = lerpf(float(supply[w][g]), 1.0, 0.15)
		_tick_events()
		for m in _collect_laundry():
			news.push_front(m)
		_pay_crew()
		if not tributaries.is_empty():
			dirty += S.TRIBUTE_PER_DAY * tributaries.size()
	for c in curses.keys():
		if int(curses[c]) < day:
			curses.erase(c)
			_invalidate()
	_expire_contracts()
	while news.size() > 12:
		news.pop_back()

func _tick_events() -> void:
	for w in events.keys():
		if day >= int(events[w].until):
			events.erase(w)
	if rng.randf() < 0.18:
		var markets := []
		for w in D.WORLD_ORDER:
			if world(w).get("services", []).has("market") and not events.has(w):
				markets.append(w)
		if markets.is_empty():
			return
		var w: String = markets[rng.randi() % markets.size()]
		var e: Dictionary = D.EVENTS[rng.randi() % D.EVENTS.size()]
		var ev := {"id": e.id, "until": day + rng.randi_range(3, 6)}
		var wname := str(D.WORLDS[w].name)
		if e.goods == "one":
			var legal := []
			for g in D.GOOD_ORDER:
				if not D.GOODS[g].contraband:
					legal.append(g)
			ev["good"] = legal[rng.randi() % legal.size()]
			news.push_front({"text": e.text, "args": [D.GOODS[ev.good].name, wname]})
		else:
			news.push_front({"text": e.text, "args": [wname]})
		events[w] = ev

# ================================================================ scans

## Accord patrols scan at Accord worlds, and (at half your heat) at lawful independent ones.
func _scan_heat(w: String) -> float:
	return heat_of() if bloc_of_world(w) == "paragon" else heat_of() * 0.5

func scans_here(w: String) -> bool:
	if law_at(w) <= 0 or local_bonus("safe_dock", w) > 0 or str(flags.get("safe_dock", "")) == w:
		return false
	return bloc_of_world(w) != "outlaw"

func scan_chance(w: String) -> float:
	if not scans_here(w):
		return 0.0
	return clampf(0.08 + law_at(w) * 0.12 + _scan_heat(w) / 250.0, 0.0, 0.95)

## Scan pass chance (first design doc §9 + DECISIONS D-8), then stealth perks, skills, the open hold.
func pass_chance(w: String) -> float:
	var h := _scan_heat(w)
	var p := 0.65 + (stealth() - law_at(w)) * 0.05 + hold_quality() * 0.1 - law_at(w) * 0.04 - h / 200.0
	p += float(_mod("scanner").get("scan", 0.0))
	p += (0.10 if has_skill("sm_cool") else 0.0) + (0.08 if has_skill("fo_papers") else 0.0)
	p *= 1.0 + stat("stealth")
	if contraband_in_open() > 0:
		p *= 0.35
	return clampf(p, 0.02, 0.98)

func _maybe_scan(w: String) -> void:
	if not scans_here(w) or rng.randf() >= scan_chance(w):
		return
	if contraband_aboard() == 0:
		_open({"kind": "scan_clean", "faction": "accord"})
		return
	if flare:
		flare = false
		_open({"kind": "scan_blind", "faction": "accord"})
		_scan_passed()
		return
	if rng.randf() < pass_chance(w):
		_open({"kind": "scan_pass", "faction": "accord"})
		_scan_passed()
	elif flag("lucky") and not lucky_used:
		lucky_used = true
		_open({"kind": "scan_lucky", "faction": "accord"})
		_scan_passed()
	else:
		stats.scans_failed += 1
		_open({"kind": "inspect", "faction": "accord", "bribe": bribe_cost(), "fine": int(contraband_value() * 0.3)})

func _scan_passed() -> void:
	stats.scans_passed += 1
	add_xp(15)
	for id in quests:
		var q: Dictionary = quests[id]
		if q.state == "active" and S.QUESTS[id].step.type == "scans":
			q.progress = int(q.progress) + 1
			if id == "N04" and int(q.progress) == 1 and not flags.has("vane"):
				flags["vane"] = true
				pending_story.append("vane")

func contraband_value() -> int:
	var v := 0
	for g in D.GOODS:
		if D.GOODS[g].contraband:
			v += qty(g) * int(D.GOODS[g].base)
	return v

func bribe_cost() -> int:
	var c := 200 + int(contraband_value() * 0.25)
	if has_skill("fx_tongue"):
		c = int(c * 0.75)
	return maxi(50, int(c * (1.0 + stat("bribe_cost"))))

# ================================================================ encounters

## What can be chosen now: Array of [option id, English label, enabled].
func options() -> Array:
	var e := encounter
	match str(e.get("kind", "")):
		"inspect":
			var o := [["bribe", _l("Bribe (%d)", [int(e.bribe)]), can_pay(int(e.bribe), "any")],
				["dump", "Dump the contraband", true], ["run", "Run for it", true],
				["fight", "Fight", true], ["submit", _l("Submit (fine %d)", [int(e.fine)]), true]]
			if not e.get("bluffed", false):
				o.insert(1, ["bluff", "Bluff", true])
			return o
		"pirates":
			var o := [["tribute", _l("Pay tribute (%d)", [tribute_cost()]), can_pay(tribute_cost(), "any")],
				["run", "Run for it", true], ["fight", "Fight", true]]
			if not e.get("bluffed", false):
				o.insert(1, ["bluff", "Bluff", true])
			if used(cargo) + used(hidden) > 0:
				o.append(["surrender", "Surrender the cargo", true])
			if contraband_aboard() > 0:
				o.append(["dump_run", "Dump and run", true])
			if stat("boarding") > 0.0:
				o.append(["board", "Board them", true])
			if bars.outlaw >= 10 or flag("scare"):
				o.insert(0, ["scare", "Scare them off", true])
			return o
		"battle_offer":
			return [["fight", "Fight", true], ["run", "Run for it", true]]
		"derelict":
			return [["salvage", "Salvage it", true], ["leave", "Leave it", true]]
		"distress":
			return [["help", "Answer the call", true], ["leave", "Fly on", true]]
		"pod":
			return [["take", "Take the pod", true], ["leave", "Leave it", true]]
		"bargain":
			return [["accept", _l("Take the deal (+%d)", [int(e.get("cash", 0))]), true], ["leave", "Refuse", true]]
		"no_fuel":
			return [["tow", _l("Call a tow (%d)", [TOW_PRICE]), true]]
		"salvage_site":
			return [["salvage", "Search the wrecks", true], ["leave", "Not now", true]]
	return [["ok", "Continue", true]]

## Raiders want a cut of the cargo (and a little of your purse), never a share of your fortune.
func tribute_cost() -> int:
	return 100 + int(cargo_value() * 0.15) + mini(2000, int(total_credits() * 0.05))

func _open(e: Dictionary) -> void:
	encounter = e
	if not e.has("log"):
		encounter["log"] = []

func _open_pirates(why: String) -> void:
	_open({"kind": "pirates", "enemy": "pirate", "why": why})

## A battle (the screen runs it in real time, then calls end_battle()). `extra`: quest, contract,
## faction (whose ships), duel.
func _open_battle(enemy: String, why: String, extra: Dictionary = {}) -> void:
	var e := {"kind": "battle", "enemy": enemy, "why": why}
	for k in extra:
		e[k] = extra[k]
	_open(e)

func _random_event() -> void:
	var r := rng.randf()
	var pirate_p := 0.28
	if sector == "veil_expanse":
		pirate_p *= 1.0 + _paragon_space_piracy()
	if flags.has("kessel_nemesis") and rng.randf() < 0.12:
		_open_battle("hunter", "Mother Kessel's hunters found you.")
		return
	if r < pirate_p:
		if max_heat() > 60.0 and rng.randf() < 0.5:
			_open_battle("hunter", "A bounty hunter has your face on a poster.")
		else:
			_open_pirates("A raider ship drops out of the dark and hails you.")
	elif r < 0.43:
		_open({"kind": "derelict"})
	elif r < 0.56:
		_open({"kind": "distress"})
	elif r < 0.67:
		_open({"kind": "meteors"})
		var dmg := rng.randi_range(4, 14)
		hull = maxi(1, hull - dmg)
		encounter["log"] = [_l("Rocks hammer the hull: -%d hull.", [dmg])]
	elif r < 0.76:
		_open({"kind": "pod"})
	elif r < 0.84:
		flare = true
		_open({"kind": "flare"})
	elif r < 0.92:
		var c: String = S.CURSE_FLAWS[rng.randi() % S.CURSE_FLAWS.size()]
		_open({"kind": "bargain", "curse": c, "cash": rng.randi_range(8, 20) * 100})
	else:
		_open({"kind": "tip"})
		_give_tip()

func _paragon_space_piracy() -> float:
	var t := 0.0
	for m in S.BAR_MILESTONES.paragon:
		if int(bars.paragon) >= int(m[0]):
			t += float(m[3].get("piracy@paragon", 0.0))
	return t

func _give_tip() -> void:
	var best := []
	var best_gain := 0
	for w in worlds_in(sector):
		for g in D.GOOD_ORDER:
			if not D.GOODS[g].contraband or not D.WORLDS[w].black:
				continue
			var gain := base_price(g, w) - int(D.GOODS[g].base)
			if gain > best_gain:
				best_gain = gain
				best = [g, w]
	if best.is_empty():
		encounter["log"] = ["The informant has nothing worth hearing."]
	else:
		encounter["log"] = [_l("An informant whispers: %s sells high on %s.", [D.GOODS[best[0]].name, D.WORLDS[best[1]].name])]

func _curse(c: String) -> void:
	curses[c] = day + S.CURSE_DAYS
	_invalidate()

## Pick an option. Returns the English lines that describe what happened. When the encounter is
## over, `encounter` is {} again; "fight" turns it into a battle (kind "battle").
func choose(opt: String) -> Array:
	var e := encounter
	if e.is_empty():
		return []
	var kind := str(e.kind)
	var out: Array = []
	var close := true
	match kind:
		"inspect":
			out = _inspect(opt)
			close = str(encounter.get("kind", "")) != "battle" and not encounter.get("keep", false)
		"pirates":
			out = _pirates(opt)
			close = str(encounter.get("kind", "")) != "battle" and not encounter.get("keep", false)
		"battle_offer":
			if opt == "fight":
				encounter["kind"] = "battle"
				close = false
			else:
				out = _flee_offer()
				close = str(encounter.get("kind", "")) != "battle"
		"derelict", "salvage_site":
			if opt == "salvage":
				out = _salvage(kind == "salvage_site")
				close = str(encounter.get("kind", "")) != "battle"
		"distress":
			if opt == "help":
				if rng.randf() < 0.3 * (1.0 + stat("trap_chance")):
					_open_pirates("It was a trap!")
					return ["It was a trap!"]
				var gift := rng.randi_range(200, 600)
				clean += gift
				add_xp(20)
				out = [_l("You patch their engine. They pay %d clean credits.", [gift])]
		"pod":
			if opt == "take":
				if rng.randf() < 0.2 * (1.0 + stat("trap_chance")):
					var c: String = S.CURSE_FLAWS[rng.randi() % S.CURSE_FLAWS.size()]
					_curse(c)
					out = [_l("Cursed cargo! The pod's junk fouls your ship: %s for %d days.", [S.PERKS[c].name, S.CURSE_DAYS])]
				else:
					var g: String = ["forged_ids", "bootleg_data", "weapons"][rng.randi() % 3]
					var n := mini(rng.randi_range(1, 3), space_for(g))
					_stow(g, n)
					out = [_l("Someone's dumped contraband: %d x %s.", [n, D.GOODS[g].name])] if n > 0 else ["No room aboard."]
		"bargain":
			if opt == "accept":
				dirty += int(e.cash)
				_curse(str(e.curse))
				out = [_l("A Faustian bargain: +%d dirty credits, and %s for %d days.", [int(e.cash), S.PERKS[e.curse].name, S.CURSE_DAYS])]
		"no_fuel":
			out = _tow()
		"sun":
			var dmg := rng.randi_range(10, 20)
			hull = maxi(1, hull - dmg)
			out = [_l("Too close to %s: -%d hull.", [str(e.get("hazard", "the star")), dmg])]
		"black_hole":
			var lost := minf(fuel, 2.0)
			fuel -= lost
			out = [_l("%s pulls at the ship. You burn %d fuel to break free.", [str(e.get("hazard", "The Maw")), int(lost)])]
	if close:
		encounter = {}
	else:
		encounter.erase("keep")
		encounter["log"] = out
	return out

func _tow() -> Array:
	var near := ""
	var best := INF
	var a: Array = encounter.get("at", [0, 0])
	var here := Vector2(float(a[0]), float(a[1]))
	for w in worlds_in(sector):
		if not world(w).get("services", []).has("fuel"):
			continue
		var d := pos_of(w).distance_to(here)
		if d < best:
			best = d
			near = w
	if near == "":
		near = D.HUB_WORLD
	if can_pay(TOW_PRICE, "any"):
		pay(TOW_PRICE, "any")
	else:
		debt += TOW_PRICE
	fuel = 2.0
	tow_to = near
	return [_l("A tug drags you to %s.", [D.WORLDS[near].name])]

func _bluff_chance() -> float:
	return clampf(0.30 + stat("stealth") + stat("bribe_success") + stealth() * 0.03, 0.05, 0.85)

func _inspect(opt: String) -> Array:
	var f := "accord"
	match opt:
		"bribe":
			var c := int(encounter.bribe)
			if not pay(c, "dirty"):
				return _confiscate(f, "You can't pay the bribe.")
			var ok := rng.randf() < clampf(0.95 - law_at(loc) * 0.07 - heat_of() / 300.0 + stat("bribe_success"), 0.3, 0.97)
			stats.bribes += 1
			if ok:
				if has_skill("fx_favors"):
					add_heat(f, -8)
				return [_l("The officer pockets %d credits and looks the other way.", [c])]
			add_heat(f, 12)
			return _confiscate(f, "The officer takes the money AND the cargo.")
		"bluff":
			encounter["bluffed"] = true
			if rng.randf() < _bluff_chance():
				_scan_passed()
				return ["Your papers and your smile hold up. They wave you through."]
			add_heat(f, 5)
			encounter["keep"] = true
			return ["They don't buy it. The inspection goes on."]
		"dump":
			for g in D.GOODS:
				if D.GOODS[g].contraband:
					_take(g, qty(g))
			add_heat(f, 5)
			return ["You flush the hold before they board. Nothing to find."]
		"run":
			if rng.randf() < flee_chance():
				add_heat(f, 15)
				return ["You burn hard and lose them. They'll remember your hull, though."]
			_open_battle("patrol", "They cut you off. Weapons hot.", {"faction": "terran_concord", "patrol": true})
			return ["They cut you off. Weapons hot."]
		"fight":
			_open_battle("patrol", "You open fire on the patrol.", {"faction": "terran_concord", "patrol": true})
			add_heat(f, 20)
			return ["You open fire on the patrol."]
		"submit":
			return _confiscate(f, "")
	return []

func _confiscate(f: String, first: String) -> Array:
	var fine := int(contraband_value() * 0.3)
	for g in D.GOODS:
		if D.GOODS[g].contraband:
			_take(g, qty(g))
	if not pay(fine, "any"):
		fine = total_credits()   # they take what you have
		clean = 0
		dirty = 0
		add_heat(f, 5)
	add_heat(f, 10)
	var out := [] if first == "" else [first]
	out.append(_l("Contraband seized. Fine: %d.", [fine]))
	return out

func flee_chance() -> float:
	var p := 0.4 + float(_mod("engine").get("flee", 0.0)) + _special_sum("flee") + stealth() * 0.03
	return clampf(p * (1.0 + stat("flee")), 0.05, 0.9)

func _pirates(opt: String) -> Array:
	match opt:
		"scare":
			if rng.randf() < 0.4 + float(bars.outlaw) / 200.0 + (0.2 if flag("scare") else 0.0) or has_skill("pi_fear"):
				return ["They see whose ship it is and turn tail."]
			_open_battle("pirate", "They aren't impressed.")
			return ["They aren't impressed. Weapons hot."]
		"tribute":
			var c := tribute_cost()
			if not pay(c, "dirty"):
				_open_battle("pirate", "You can't pay.")
				return ["You can't pay. Weapons hot."]
			return [_l("You pay %d. They let you go.", [c])]
		"bluff":
			encounter["bluffed"] = true
			if rng.randf() < _bluff_chance():
				return ["\"Accord patrol, heave to!\" They believe you and scatter."]
			encounter["keep"] = true
			return ["They laugh at your bluff."]
		"surrender":
			cargo = {}
			hidden = {}
			paid = {}
			for id in quests.keys():
				if quests[id].state == "active" and S.QUESTS[id].has("give"):
					quests.erase(id)   # given cargo is gone: the job is lost (take it again)
			contracts = contracts.filter(func(c): return str(c.get("kind", "carry")) != "carry")
			return ["You open the hold. They take everything and let you go."]
		"dump_run":
			for g in D.GOODS:
				if D.GOODS[g].contraband:
					_take(g, qty(g) - reserved(g))
			if rng.randf() < minf(0.95, flee_chance() + 0.25):
				return ["Contraband spills behind you. They stop for it, and you're gone."]
			_open_battle("pirate", "They want more than the scraps.")
			return ["They want more than the scraps. Weapons hot."]
		"board":
			if rng.randf() < clampf(0.25 + stat("boarding"), 0.05, 0.9):
				var loot := int(rng.randi_range(400, 1100) * (1.0 + stat("boarding_loot") + stat("loot")))
				dirty += loot
				stats.boarded += 1
				stats.fights_won += 1
				add_xp(40)
				_fight_progress()
				return [_l("Your boarders take their ship before it can fire: %d dirty credits.", [loot])]
			_open_battle("pirate", "The boarding fails.")
			return ["The boarding fails. Weapons hot."]
		"run":
			if rng.randf() < flee_chance():
				return ["You outrun them."]
			_open_battle("pirate", "They're faster.")
			return ["They're faster. Weapons hot."]
		"fight":
			_open_battle("pirate", "Weapons hot.")
			return ["Weapons hot."]
	return []

func _flee_offer() -> Array:
	if rng.randf() < flee_chance():
		encounter = {}
		return ["You slip away before they close in."]
	encounter["kind"] = "battle"
	return ["They're faster. Weapons hot."]

# ================================================================ battles (results)

## The open battle's enemy wing, ready for the real-time sim: Array of ship dicts.
func battle_enemies() -> Array:
	var e := encounter
	var ed: Dictionary = D.ENEMIES[str(e.enemy)]
	var out := []
	var tier_k := 1.0 + 0.15 * (tier - 1) if str(e.enemy) in ["pirate", "hunter", "warship"] else 1.0
	for i in int(ed.ships):
		out.append({"hull": int(ed.hull * tier_k), "shield": int(ed.shield * tier_k), "guns": int(ed.guns), "dmg": float(ed.dmg),
			"acc": float(ed.acc), "eva": float(ed.eva), "speed": float(ed.speed), "sprite": str(ed.sprite),
			"board": bool(ed.get("board", false))})
	return out

## The player's ship for the real-time sim.
func battle_player() -> Dictionary:
	var w: Dictionary = _mod("weapons")
	var dmg := 6.0 * float(w.get("dmg", 1.0)) * (1.0 + stat("turret_damage") + stat("weapon_damage")
		+ (stat("energy_damage") if w.get("energy", false) else 0.0) + (0.25 if has_skill("pi_board") else 0.0))
	var cd := 1.1 * (1.0 + (stat("cooldown") if w.get("energy", false) else 0.0))
	return {"hull": hull, "max_hull": max_hull(), "shield": shield(), "guns": guns(), "dmg": dmg, "cd": cd,
		"acc": clampf(0.72 * (1.0 + stat("accuracy")), 0.2, 0.98), "eva": clampf(0.10 + stat("evasion"), 0.0, 0.7),
		"speed": 230.0 * speed_mult(), "shield_regen": 4.0 * (1.0 + stat("shield_regen")),
		"flee": flee_chance(), "boarding": clampf(0.35 + stat("boarding"), 0.05, 0.95),
		"lock": stat("enemy_lock"), "hack": flag("hack"), "first_shot": flag("first_shot"),
		"scare": flag("scare") or has_skill("pi_fear"), "surrender": flag("surrender"),
		"ally_damage": stat("ally_damage"), "calls": calls().filter(func(a): return not used_calls.has(a)),
		"duel": not bool(D.ENEMIES[str(encounter.get("enemy", "pirate"))].get("lethal", true)),
		"lucky": flag("lucky") and not lucky_used}

## The battle ended. outcome: "won" / "boarded" / "fled" / "lost" / "cloaked" / "duel_lost".
## info: {hull, used_calls, broken (enemies destroyed), lucky (the Lucky perk saved you)}.
func end_battle(outcome: String, info: Dictionary = {}) -> Array:
	var e := encounter
	if str(e.get("kind", "")) != "battle":
		return []
	for a in info.get("used_calls", []):
		if not used_calls.has(a):
			used_calls.append(a)
	if info.get("lucky", false):
		lucky_used = true
	hull = clampi(int(info.get("hull", hull)), 0, max_hull())
	var ed: Dictionary = D.ENEMIES[str(e.enemy)]
	var out := []
	encounter = {}
	match outcome:
		"won", "boarded":
			hull = maxi(1, hull)
			stats.fights_won += 1
			add_xp(40 + 10 * int(ed.ships))
			var loot := rng.randi_range(int(ed.loot[0]), int(ed.loot[1]))
			loot = int(loot * (1.0 + stat("loot") + stat("raid_tribute") * 0.5) * (1.5 if has_skill("en_warlord") else 1.0))
			if outcome == "boarded":
				loot = int(loot * (1.5 + stat("boarding_loot")))
				stats.boarded += 1
			if e.has("contract"):
				loot = 0
			out.append("They're finished." if outcome == "won" else "Your boarders take the ship.")
			if loot > 0:
				dirty += loot
				out.append(_l("You strip the wreck: %d dirty credits.", [loot]))
			if e.get("patrol", false):
				add_heat("accord", 25)
			_fight_progress()
			if e.has("quest") and quests.has(str(e.quest)):
				quests[str(e.quest)].progress = 1
			if e.has("contract"):
				for c in contracts:
					if c.id == e.contract:
						c["done"] = true
		"fled", "cloaked":
			if e.get("patrol", false):
				add_heat("accord", 10)
			out.append("You break away and run." if outcome == "fled" else "The Shadow Cloak folds around you. You're gone.")
		"duel_lost":
			hull = maxi(1, hull)
			out.append("Your shield breaks first. The duel is theirs; come back when you're ready.")
		_:
			out += _lost_fight()
	return out

func _fight_progress() -> void:
	for id in quests:
		var q: Dictionary = quests[id]
		if q.state == "active" and S.QUESTS[id].step.type == "fights":
			q.progress = int(q.progress) + 1

## Hull at zero: captured. Cargo and half the dirty credits are gone, towed to Cradle Station.
func _lost_fight() -> Array:
	stats.fights_lost += 1
	stats.captured += 1
	cargo = {}
	hidden = {}
	paid = {}
	dirty /= 2
	hull = maxi(10, max_hull() / 3)
	fuel = maxf(fuel, 3.0)
	tow_to = D.HUB_WORLD
	pending_story.append("captured")
	return ["Your ship goes dark."]

func _salvage(site: bool) -> Array:
	stats.salvages += 1
	var mult := (1.5 if has_skill("pi_salvage") else 1.0) * (1.0 + stat("salvage") + _special_sum("salvage"))
	var out := []
	var cash := int(rng.randi_range(80, 400) * mult * (1.5 if site else 1.0))
	dirty += cash
	out.append(_l("You find %d in old credit chips.", [cash]))
	var pool := ["ore", "alloys", "electronics", "stolen_tech", "relics"] if site else ["ore", "alloys", "stolen_tech"]
	var g: String = pool[rng.randi() % pool.size()]
	if rng.randf() < 0.1 * (1.0 + stat("rare_find")):
		g = "relics"
	var n := mini(int(rng.randi_range(1, 3) * mult), space_for(g))
	if n > 0:
		_stow(g, n)
		out.append(_l("And %d x %s.", [n, D.GOODS[g].name]))
	if site and loc != "":
		for id in quests:
			var q: Dictionary = quests[id]
			var st: Dictionary = S.QUESTS[id].step
			if q.state == "active" and st.type == "salvage" and str(st.get("at", loc)) == loc:
				q.progress = int(q.progress) + 1
	if site and rng.randf() < 0.25:
		_open_pirates("Scavengers want the same wrecks.")
		return out + ["Scavengers want the same wrecks."]
	add_xp(10)
	return out

## A wreck field: search it from the dock (one day).
func start_salvage() -> bool:
	if not has_service("salvage") or not encounter.is_empty():
		return false
	pass_days(1)
	_open({"kind": "salvage_site"})
	return true

# ================================================================ quests (§10.1, §11, Quest Expansion v2.2)

func quest_state(id: String) -> String:
	return str(quests.get(id, {}).get("state", ""))

## Kept for the old name used by screens and tests.
func mission_state(id: String) -> String:
	return quest_state(id)

func quest_slots() -> int:
	return S.QUEST_SLOTS + int(stat("quest_slots"))

func side_active() -> int:
	var n := 0
	for id in quests:
		if quests[id].state == "active" and S.QUESTS[id].kind != "main":
			n += 1
	return n

## The faction whose rep gates this quest ("" = none).
func quest_faction(id: String) -> String:
	var q: Dictionary = S.QUESTS[id]
	if q.has("giver_faction"):
		return str(q.giver_faction)
	if str(q.giver) == "any":
		return ""
	return faction_of(str(q.giver))

## Kinds open to everyone (no 10% rep gate with the giver's faction, D-27).
const OPEN_KINDS := ["main", "crew", "neutral", "location", "species", "loyalty"]

## How many factions of a bloc ("paragon" / "outlaw") are at `fp` or more.
func bloc_count(bloc: String, fp: int) -> int:
	var n := 0
	for f in (S.ACCORD if bloc == "paragon" else S.PACT):
		if rep_of(f) >= fp:
			n += 1
	return n

## Quests done with this crew member aboard (loyalty quests open at S.LOYAL_QUESTS).
func crew_quests(cid: String) -> int:
	return int(crew_member(cid).get("q", 0))

## A crew member's rank (2 after their loyalty quest).
func crew_rank(cid: String) -> int:
	var m := crew_member(cid)
	if not m.is_empty():
		return int(m.get("rank", 1))
	return 2 if quest_state(_loyalty_quest(cid)) == "done" else 1

static func _loyalty_quest(cid: String) -> String:
	for id in S.QUESTS:
		if str(S.QUESTS[id].get("crew", "")) == cid:
			return id
	return ""

## Your race or a crew member's matches this quest's race (species quests).
func race_match(id: String) -> bool:
	var r := str(S.QUESTS[id].get("race", ""))
	return r != "" and races_aboard().has(r)

## Is a prereq met? A message why not ({} = met). Only the parts that show as a 🔒 on the board.
func _prereq_block(pre: Dictionary) -> Dictionary:
	for d in pre.get("done", []):
		if quest_state(str(d)) != "done":
			return _l("Not yet")
	var any: Array = pre.get("any_done", [])
	if not any.is_empty() and not any.any(func(d): return quest_state(str(d)) == "done"):
		return _l("Not yet")
	for b in pre.get("bar_min", {}):
		if int(bars[b]) < int(pre.bar_min[b]):
			return _l("Needs Paragon %d" if b == "paragon" else "Needs Outlaw %d", [int(pre.bar_min[b])])
	for f in pre.get("rep_min", {}):
		if rep_of(str(f)) < int(pre.rep_min[f]):
			return _l("Needs %s %d%%", [S.FACTIONS[f].name, int(pre.rep_min[f]) / 10])
	for f in pre.get("rep_max", {}):
		if rep_of(str(f)) > int(pre.rep_max[f]):
			return _l("Only below %s %d%%", [S.FACTIONS[f].name, int(pre.rep_max[f]) / 10])
	if pre.has("bloc_rep"):
		var br: Dictionary = pre.bloc_rep
		if bloc_count(str(br.bloc), int(br.fp)) < int(br.n):
			return _l("Needs %d Accord factions at %d%%" if str(br.bloc) == "paragon" else "Needs %d Pact factions at %d%%", [int(br.n), int(br.fp) / 10])
	if nodes < int(pre.get("nodes", 0)):
		return _l("Needs %d Blind Nodes", [int(pre.nodes)])
	if pre.has("aboard") and crew_member(str(pre.aboard)).is_empty():
		return _l("%s must be aboard", [S.CREW[str(pre.aboard)].name])
	return {}

## Why a quest can't be taken here now: a message ({} = it can).
func quest_block(id: String) -> Dictionary:
	var q: Dictionary = S.QUESTS[id]
	if quests.has(id):
		return _l("Taken")
	var pb := _prereq_block(q.get("prereq", {}))
	if not pb.is_empty():
		return pb
	var f := quest_faction(id)
	if not OPEN_KINDS.has(str(q.kind)) and f != "none" and f != "":
		if rep_of(f) < 0 and not q.get("prereq", {}).has("rep_max"):
			return _l("No work for you")
		if not q.get("open", false) and rep_of(f) < S.REP_QUESTS:
			return _l("Needs 10% rep")
	if q.kind != "main" and side_active() >= quest_slots():
		return _l("Quest slots full")
	if q.has("recruit") and lost_crew.has(str(q.recruit)):
		return _l("Gone")
	var give: Dictionary = _gives(id)
	for g in give:
		if space_for(g) < int(give[g]):
			return _l("No room in the hold")
	return {}

## Cargo handed over when you take it (the quest's "give", plus a race bonus's).
func _gives(id: String) -> Dictionary:
	var q: Dictionary = S.QUESTS[id]
	var out: Dictionary = q.get("give", {}).duplicate()
	if race_match(id):
		var rg: Dictionary = q.get("race_bonus", {}).get("give", {})
		for g in rg:
			out[g] = int(out.get(g, 0)) + int(rg[g])
	return out

## Hidden from the board: a done-prereq not met, another quest of its group taken, a loyalty quest
## whose crew member isn't aboard (or not loyal yet).
func _quest_hidden(id: String) -> bool:
	var q: Dictionary = S.QUESTS[id]
	for d in q.get("prereq", {}).get("done", []):
		if quest_state(str(d)) != "done":
			return true
	if q.has("excl"):
		for other in S.QUESTS:
			if other != id and str(S.QUESTS[other].get("excl", "")) == str(q.excl) and quests.has(other):
				return true
	if q.has("crew"):
		var cid := str(q.crew)
		if crew_member(cid).is_empty() or crew_quests(cid) < S.LOYAL_QUESTS:
			return true
	return false

## Quests offered at this world now: [id, block message] ({} = can be taken).
func quest_offers() -> Array:
	var out := []
	if loc == "" or port_closed():
		return out
	for id in S.QUEST_ORDER:
		var q: Dictionary = S.QUESTS[id]
		if (q.kind == "main" and not q.get("board", false)) or quests.has(id):
			continue
		if str(q.giver) != loc and str(q.giver) != "any":
			continue
		if _quest_hidden(id):
			continue
		out.append([id, quest_block(id)])
	return out

func accept_quest(id: String) -> bool:
	if not S.QUESTS.has(id) or quests.has(id):
		return false
	var q: Dictionary = S.QUESTS[id]
	if (q.kind != "main" or q.get("board", false)) and not quest_block(id).is_empty():
		return false
	var give := _gives(id)
	for g in give:
		if space_for(g) < int(give[g]):
			return false
	quests[id] = {"state": "active", "progress": 0}
	for g in give:
		_stow(g, int(give[g]))
		paid[g] = 0.0
	if q.has("on_accept"):
		flags[str(q.on_accept)] = true
		_invalidate()
	if race_match(id) and q.get("race_bonus", {}).get("skip", false):
		quests[id].progress = 1   # S02: your own kind sees the trap coming
	return true

## Kept for the old name.
func accept_mission(id: String) -> bool:
	return accept_quest(id)

func active_quests() -> Array:
	var out := []
	for id in S.QUEST_ORDER:
		if quest_state(id) == "active":
			out.append(id)
	return out

## The step's progress: [have, need].
func quest_progress(id: String) -> Array:
	var st: Dictionary = S.QUESTS[id].step
	match str(st.type):
		"deliver": return [mini(qty(st.good), int(st.qty)), int(st.qty)]
		"pay": return [maxi(0, S.START_DEBT - debt), S.START_DEBT]
		"spend": return [mini(total_credits(), int(st.amount)), int(st.amount)]
		"scans", "fights", "salvage": return [int(quests[id].progress), int(st.n)]
		"battle": return [int(quests[id].progress), 1]
		"crew": return [mini(crew.size(), int(st.n)), int(st.n)]
		"reach": return [1 if loc == st.to else 0, 1]
		"jump": return [1 if sector == st.to else 0, 1]
		"tour": return [Array(quests[id].get("visited", [])).size(), st.to.size()]
	return [0, 1]

## Can it be handed in here, now?
func can_complete(id: String) -> bool:
	if quest_state(id) != "active":
		return false
	var st: Dictionary = S.QUESTS[id].step
	match str(st.type):
		"deliver": return loc == st.to and qty(st.good) >= int(st.qty)
		"pay": return debt <= 0
		"spend": return loc != "" and can_pay(int(st.amount), "any")
		"scans", "fights", "salvage": return int(quests[id].progress) >= int(st.n)
		"battle": return int(quests[id].progress) >= 1
		"crew": return crew.size() >= int(st.n)
		"reach": return loc == st.to
		"jump": return loc != "" and sector == st.to
		"tour": return loc != "" and Array(quests[id].get("visited", [])).size() >= st.to.size()
	return false

## Does handing it in need a decision (a choice, a faction pick, an ending) or a button (deliver / spend)?
func needs_hand_in(id: String) -> bool:
	var q: Dictionary = S.QUESTS[id]
	return q.has("choices") or q.has("pick") or q.get("endings", false) or str(q.step.type) in ["deliver", "spend"]

## Factions a "pick" quest can credit.
func pick_options(id: String) -> Array:
	var q: Dictionary = S.QUESTS[id]
	var p = q.get("pick", "")
	var out := []
	if p is Array:
		out = Array(p).duplicate()
	elif str(p) == "paragon":
		out = S.ACCORD.duplicate()
	elif str(p) == "outlaw":
		out = S.PACT.duplicate()
	elif str(p) == "any":
		out = S.FACTION_ORDER.duplicate()
	if q.has("pick_min"):
		out = out.filter(func(f): return rep_of(str(f)) >= int(q.pick_min))
	return out

## How many factions the hand-in picks (fewer if fewer qualify).
func pick_count(id: String) -> int:
	return mini(int(S.QUESTS[id].get("pick_n", 1)), pick_options(id).size())

## Why a choice can't be made now ({} = it can): its cost or the cargo it needs.
func choice_block(id: String, i: int) -> Dictionary:
	var q: Dictionary = S.QUESTS[id]
	if q.get("endings", false):
		return ending_block(str(S.ENDING_ORDER[i]))
	var c: Dictionary = q.choices[i]
	if c.has("cost") and not can_pay(int(c.cost), "any"):
		return _l("Can't pay %d", [int(c.cost)])
	var nd: Dictionary = c.get("needs", {})
	for g in nd:
		if qty(g) < int(nd[g]):
			return _l("Needs %d x %s", [int(nd[g]), D.GOODS[g].name])
	return {}

## The choices at hand-in: the quest's choices, or the endings.
func choice_count(id: String) -> int:
	var q: Dictionary = S.QUESTS[id]
	if q.get("endings", false):
		return S.ENDING_ORDER.size()
	return Array(q.get("choices", [])).size()

## Hand a quest in. `choice`: the index of a choice (or ending); `pick`: the faction(s) for a pick
## quest, comma-separated when it picks several. Returns the English lines of what you got.
func complete(id: String, choice: int = -1, pick: String = "") -> Array:
	if not can_complete(id):
		return []
	var q: Dictionary = S.QUESTS[id]
	var nch := choice_count(id)
	if nch > 0 and (choice < 0 or choice >= nch or not choice_block(id, choice).is_empty()):
		return []
	var picks := []
	if q.has("pick"):
		for f in pick.split(",", false):
			if not picks.has(f):
				picks.append(f)
		var opts := pick_options(id)
		if picks.size() != pick_count(id) or not picks.all(func(f): return opts.has(f)):
			return []
	var st: Dictionary = q.step
	if st.type == "deliver":
		_take(st.good, int(st.qty))
	elif st.type == "spend":
		pay(int(st.amount), "any")
	quests[id].state = "done"
	stats.quests += 1
	var out := []
	var r: Dictionary = q.duplicate()
	if race_match(id):
		var rb: Dictionary = q.get("race_bonus", {})
		r.credits = int(round(int(q.get("credits", 0)) * (1.0 + float(rb.get("credits", 0.0)))))
		out.append(_l("Your kind knows this one: %s.", [str(rb.get("text", ""))]))
	_reward(r, out)
	if q.get("endings", false):
		out += _end_story(str(S.ENDING_ORDER[choice]), int(q.get("credits", 0)))
	elif q.has("choices"):
		var c: Dictionary = q.choices[choice]
		if c.has("cost"):
			pay(int(c.cost), "any")
			out.append(_l("Paid %d.", [int(c.cost)]))
		var nd: Dictionary = c.get("needs", {})
		for g in nd:
			_take(g, int(nd[g]))
		_reward(c, out)
		if c.has("heat"):
			add_heat("accord", float(c.heat))
		if c.has("flag"):
			flags[str(c.flag)] = true
		if c.get("recruit_lost", false) and q.has("recruit"):
			lost_crew.append(str(q.recruit))
		if c.has("loyalty"):
			for m in crew:
				m.loyalty = clampi(int(m.loyalty) + int(c.loyalty), 0, 100)
	for f in picks:
		var got := add_rep(f, int(q.pick_fp))
		out.append(_l("%s %+d rep.", [S.FACTIONS[f].name, got]))
	if q.has("recruit") and not lost_crew.has(str(q.recruit)):
		var cid := str(q.recruit)
		if cid == "C01" and crew.size() < crew_slots():
			crew.append({"id": cid, "loyalty": _loyalty_target(cid)})
			_invalidate()
			out.append(_l("%s joins your crew.", [S.CREW[cid].name]))
		elif not recruitable.has(cid):
			recruitable.append(cid)
			out.append(_l("%s will join you at %s (hire them at the dock).", [S.CREW[cid].name, D.WORLDS[S.CREW[cid].planet].name]))
	_quest_extras(id, q, out)
	if q.has("choices") and not q.get("endings", false) and q.choices[choice].get("crew_leaves", false):
		var cid := str(q.get("crew", ""))
		if dismiss(cid):
			out.append(_l("%s leaves for now: hire them again at %s.", [S.CREW[cid].name, D.WORLDS[S.CREW[cid].planet].name]))
	# crew aboard share the quest (loyalty quests open after S.LOYAL_QUESTS)
	for m in crew:
		m["q"] = int(m.get("q", 0)) + 1
	bonus_points += int(q.get("points", 0))
	add_xp(int(q.get("xp", 0)))
	if out.is_empty():
		out.append(_l("Done: %s.", [q.title]))
	if q.has("story"):
		pending_story.append(str(q.story))
	var nxt = q.get("next", "")
	for n in (nxt if nxt is Array else [nxt]):
		if str(n) != "":
			accept_quest(str(n))
	return out

## Everything a quest gives besides credits, rep and bars.
func _quest_extras(id: String, q: Dictionary, out: Array) -> void:
	if q.get("junk", false):
		_stow("ore", mini(2, space_for("ore")))
		out.append("The machine dispenses two crates of ore. Close enough.")
	if q.has("unlock"):
		flags[str(q.unlock)] = true
		if str(q.unlock) == "safehouse":
			out.append("Your safehouse is ready: heat cools twice as fast.")
	if q.has("on_accept"):
		flags.erase(str(q.on_accept))   # M10: the Ghost Core is back
		_invalidate()
	if q.has("ship"):
		ship = str(q.ship)
		tier = 1
		hull = max_hull()
		fuel = float(tank())
		_invalidate()
	if int(q.get("node", 0)) > 0:
		nodes += int(q.node)
		_invalidate()
		out.append(_l("Blind Node %d of 3: the Ghost Core gains +10%% stealth.", [nodes]))
	if q.has("part"):
		_give_part(str(q.part), out)
	if int(q.get("loot", 0)) > 0:
		var g: String = D.GOOD_ORDER[rng.randi() % D.GOOD_ORDER.size()]
		var n := mini(int(q.loot), space_for(g))
		if n > 0:
			_stow(g, n)
			paid[g] = 0.0
			out.append(_l("And %d x %s.", [n, D.GOODS[g].name]))
	if q.has("paint"):
		flags["paint"] = str(q.paint)
		out.append("A new paint job for your ship (Ship Layout).")
	if q.has("safe_dock"):
		flags["safe_dock"] = str(q.safe_dock)
		out.append(_l("%s will never scan you.", [D.WORLDS[str(q.safe_dock)].name]))
	if q.has("tributary"):
		var w := str(q.tributary)
		if not tributaries.has(w):
			tributaries.append(w)
		out.append(_l("%s pays you %d dirty credits a day.", [D.WORLDS[w].name, S.TRIBUTE_PER_DAY]))
	if q.get("heat_reset", false):
		heat["accord"] = 0.0
		out.append("Your heat is gone.")
	if q.get("free_refit", false):
		flags["free_refit"] = true
		out.append("Your next hull refit is free.")
	if q.has("crew"):
		var cid := str(q.crew)
		var m := crew_member(cid)
		if not m.is_empty():
			m["rank"] = 2
			m.loyalty = mini(100, int(m.loyalty) + S.LOYAL_BONUS)
			_invalidate()
		out.append(_l("%s is loyal for good: %s goes to Rank II, their quirk fades.", [S.CREW[cid].name, S.PERKS[S.CREW[cid].personal].name]))
	if race_match(id):
		var rb: Dictionary = q.get("race_bonus", {})
		var fd: Dictionary = rb.get("faction", {})
		for f in fd:
			var got := add_rep(str(f), int(fd[f]))
			out.append(_l("%s %+d rep.", [S.FACTIONS[f].name, got]))
		var gd: Dictionary = rb.get("good", {})
		for g in gd:
			var n := mini(int(gd[g]), space_for(g))
			if n > 0:
				_stow(g, n)
				paid[g] = 0.0
				out.append(_l("And %d x %s.", [n, D.GOODS[g].name]))
		if rb.has("part"):
			_give_part(str(rb.part), out)
		bonus_points += int(rb.get("points", 0))

func _give_part(id: String, out: Array) -> void:
	if not owned.has(id):
		owned.append(id)
	out.append(_l("A part for your shipyard: %s.", [D.MODULES[id].name]))

## Credits, faction FP and bar points of a quest (or one of its choices).
func _reward(r: Dictionary, out: Array) -> void:
	var cr := int(r.get("credits", 0))
	if cr > 0:
		var mult := 1.0 + stat("mission_credits") + (stat("bounty_credits") if r.get("bounty", false) else 0.0)
		cr = int(round(cr * mult))
		_earn(cr, str(r.get("money", "clean")))
		out.append(_l("+%d dirty credits." if str(r.get("money", "clean")) == "dirty" else "+%d clean credits.", [cr]))
	var fd: Dictionary = r.get("faction", {})
	for f in fd:
		var got := add_rep(str(f), int(fd[f]))
		out.append(_l("%s %+d rep.", [S.FACTIONS[f].name, got]))
	var b: Dictionary = r.get("bars", {})
	for k in b:
		add_bar(str(k), int(b[k]))
		out.append(_l("Paragon +%d." if k == "paragon" else "Outlaw +%d.", [int(b[k])]))

## Docking: a tour quest counts this world, then a quest's or bounty's battle opens.
func _quest_arrival(w: String) -> void:
	for id in active_quests():
		var st: Dictionary = S.QUESTS[id].step
		if str(st.type) == "tour" and Array(st.to).has(w):
			var v: Array = quests[id].get("visited", [])
			if not v.has(w):
				v.append(w)
			quests[id]["visited"] = v
	for id in active_quests():
		var st: Dictionary = S.QUESTS[id].step
		if str(st.type) == "battle" and str(st.to) == w and int(quests[id].progress) < 1:
			_open({"kind": "battle_offer", "enemy": str(st.enemy), "quest": id,
				"why": S.QUESTS[id].title, "duel": not bool(D.ENEMIES[str(st.enemy)].get("lethal", true))})
			return
	for c in contracts:
		if str(c.get("kind", "")) == "bounty" and str(c.to) == w and not c.get("done", false):
			_open({"kind": "battle_offer", "enemy": str(c.enemy), "contract": str(c.id), "why": "Bounty"})
			return

## Completes every quest that finishes by itself (reach / scans / fights / battle / pay / salvage /
## crew / jump / tour) and has no choice to make.
func auto_complete() -> Array:
	var done := []
	for id in active_quests():
		if not needs_hand_in(id) and can_complete(id):
			complete(id)
			done.append(id)
	return done

# ================================================================ endings (v2 §12)

## Why this ending isn't open ({} = it is).
func ending_block(id: String) -> Dictionary:
	match id:
		"unify":
			if int(bars.paragon) < 100 or bloc_count("paragon", 750) < 4:
				return _l("Needs Paragon 100 and 4 Accord factions at 75%")
		"rule":
			if int(bars.outlaw) < 100 or bloc_count("outlaw", 750) < 3:
				return _l("Needs Outlaw 100 and 3 Pact factions at 75%")
		"ghost":
			if int(bars.paragon) >= 100 or int(bars.outlaw) >= 100:
				return _l("Neither bar may be at 100")
			if nodes < 3:
				return _l("Needs %d Blind Nodes", [3])
			for cid in S.GHOST_CREW:
				if quest_state(str(cid)) != "done" or lost_crew.has(cid):
					return _l("Needs Pip, Halcyon and Tessa Quill recruited")
	return {}

func _end_story(id: String, _credits: int) -> Array:
	ending = id
	stats.endings += 1
	pending_story.append("ending_" + id)
	return [_l("Ending: %s.", [S.ENDINGS[id].title])]

## Burned (the fail ending): heat at 100 and a crew member at loyalty 20 or less. They sell you out
## once; you lose like a capture and they leave.
func _check_burned() -> void:
	if flags.has("burned") or heat_of() < 100.0 or not encounter.is_empty():
		return
	for m in crew:
		if int(m.loyalty) <= S.BURN_LOYALTY:
			flags["burned"] = true
			crew.erase(m)
			recruitable.append(m.id)
			_invalidate()
			_lost_fight()
			pending_story.erase("captured")
			pending_story.append("burned")
			heat["accord"] = 50.0
			return

# ================================================================ Kessel's debt and the safety net

## Broke and stuck (no credits to speak of, nothing to sell, not enough fuel to go anywhere):
## Mother Kessel wires a loan, any port. The safety net, so no run ever soft-locks.
const LOAN := 500
const LOAN_COST := 600

func can_borrow() -> bool:
	if loc == "" or total_credits() >= 150 or flags.has("kessel_nemesis"):
		return false
	for g in D.GOODS:
		if qty(g) - reserved(g) > 0 and trades(g):
			return false
	return true

func borrow() -> bool:
	if not can_borrow():
		return false
	clean += LOAN
	debt += LOAN_COST
	return true

## Pay Mother Kessel (her collector on Cradle Station).
func pay_debt(amount: int) -> int:
	if not has_service("collector") or debt <= 0:
		return 0
	amount = mini(amount, mini(debt, total_credits()))
	if amount <= 0:
		return 0
	pay(amount, "dirty")
	debt -= amount
	return amount

# ================================================================ crew (§10)

func _loyalty_target(cid: String) -> int:
	var t := float(S.LOYALTY_START) * (1.0 + stat("crew_loyalty"))
	if clash(cid):
		t -= S.CLASH_LOYALTY
	return clampi(int(t), 5, 100)

## A Paragon and an Outlaw crew member on one ship: each loses loyalty (§8).
func clash(cid: String) -> bool:
	var a := str(S.CREW[cid].align)
	if a == "neutral":
		return false
	for m in crew:
		var b := str(S.CREW[m.id].align)
		if m.id != cid and b != "neutral" and b != a:
			return true
	return false

func crew_member(cid: String) -> Dictionary:
	for m in crew:
		if m.id == cid:
			return m
	return {}

func crew_wage(cid: String) -> int:
	var c: Dictionary = S.CREW[cid]
	var m := 1.0 + stat("crew_wages")
	if str(c.align) == "paragon":
		for ms in S.BAR_MILESTONES.paragon:
			if int(bars.paragon) >= int(ms[0]):
				m += float(ms[3].get("crew_wages@paragon", 0.0))
	return int(round(int(c.wage) * maxf(0.0, m)))

## Why a crew member can't be hired here now ({} = they can): a message.
func hire_block(cid: String) -> Dictionary:
	var c: Dictionary = S.CREW[cid]
	if not crew_member(cid).is_empty():
		return _l("Aboard")
	if not recruitable.has(cid):
		return _l("Do their quest first")
	if loc != str(c.planet):
		return _l("Not here")
	if crew.size() >= crew_slots():
		return _l("No free crew slot")
	for r in races_aboard():
		if S.RACES[c.race].hostile.has(r) or S.RACES[r].hostile.has(str(c.race)):
			return _l("Refuses: %s aboard", [S.RACES[r].name])
	if str(c.align) == "paragon" and int(bars.paragon) < S.BAR_CREW_GATE:
		return _l("Needs Paragon %d", [S.BAR_CREW_GATE])
	if str(c.align) == "outlaw" and int(bars.outlaw) < S.BAR_CREW_GATE:
		return _l("Needs Outlaw %d", [S.BAR_CREW_GATE])
	if not can_pay(int(c.fee), "any"):
		return _l("Can't pay the fee")
	return {}

func hire(cid: String) -> bool:
	if not hire_block(cid).is_empty():
		return false
	pay(int(S.CREW[cid].fee), "any")
	recruitable.erase(cid)
	crew.append({"id": cid, "loyalty": 0})
	_invalidate()
	for m in crew:
		m.loyalty = maxi(int(m.loyalty), _loyalty_target(m.id)) if m.id == cid else mini(int(m.loyalty), _loyalty_target(m.id))
	return true

## Let a crew member go: they wait at their home planet.
func dismiss(cid: String) -> bool:
	var m := crew_member(cid)
	if m.is_empty():
		return false
	crew.erase(m)
	if not recruitable.has(cid):
		recruitable.append(cid)
	_invalidate()
	return true

## Wages every day. Unpaid crew lose loyalty; at 0 they leave.
func _pay_crew() -> void:
	var total := 0
	for m in crew:
		total += crew_wage(m.id)
	var ok := total == 0 or pay(total, "any")
	for m in crew.duplicate():
		var target := _loyalty_target(m.id)
		if ok:
			m.loyalty = mini(target, int(m.loyalty) + S.LOYALTY_PAID) if int(m.loyalty) < target else maxi(target, int(m.loyalty) - S.LOYALTY_PAID)
		else:
			m.loyalty = int(m.loyalty) - S.LOYALTY_UNPAID
		if int(m.loyalty) <= 0:
			crew.erase(m)
			recruitable.append(m.id)
			_invalidate()
			news.push_front(_l("%s left the crew: no pay, no loyalty.", [S.CREW[m.id].name]))
	if not ok:
		news.push_front(_l("You couldn't pay the crew today (%d).", [total]))

# ================================================================ contracts (§11.6)

func contract_offers() -> Array:
	if loc == "" or not has_service("fixer"):
		return []
	if int(offers_day.get(loc, -1)) != day:
		_make_offers()
	return offers.get(loc, [])

func _make_offers() -> void:
	var list := []
	var count := CONTRACTS_PER_PORT + (1 if has_skill("fx_contacts") else 0)
	var dests := []
	for w in worlds_in(sector_of(loc)):
		if w != loc and world(w).get("services", []).has("market"):
			dests.append(w)
	var issuer := faction_of(loc)
	for i in count:
		if dests.is_empty():
			break
		var to: String = dests[rng.randi() % dests.size()]
		var dist := pos_of(loc).distance_to(pos_of(to))
		if issuer == "hunt_guilds" or (i == count - 1 and rng.randf() < 0.25):
			var enemy := "hunter" if (issuer == "hunt_guilds" and stat("guild_master") > 0 and rng.randf() < 0.5) else "pirate"
			var bounty := int((600 + dist * 1.5) * (2.0 if enemy == "hunter" else 1.0) * (1.0 + stat("bounty_credits")))
			list.append({"id": "%s_%d_%d" % [loc, day, i], "kind": "bounty", "enemy": enemy, "good": "", "qty": 0,
				"from": loc, "to": to, "pay": bounty, "money": "clean", "due": day + 4 + _days_for(dist) * 2, "issuer": issuer})
			continue
		var shady := flags.has("black_market") and rng.randf() < 0.45
		var pool := []
		for g in D.GOOD_ORDER:
			if bool(D.GOODS[g].contraband) == shady:
				pool.append(g)
		var g: String = pool[rng.randi() % pool.size()]
		var n := rng.randi_range(2, 5)
		var pay_amt := int((120 + dist * 1.1 + n * int(D.GOODS[g].base) * 0.12) * (1.6 if shady else 1.0))
		if has_skill("fx_contacts"):
			pay_amt = int(pay_amt * 1.15)
		list.append({"id": "%s_%d_%d" % [loc, day, i], "kind": "carry", "good": g, "qty": n, "from": loc, "to": to,
			"pay": pay_amt, "money": "dirty" if shady else "clean", "due": day + 3 + _days_for(dist) * 2, "issuer": issuer})
	offers[loc] = list
	offers_day[loc] = day

func take_contract(cid: String) -> bool:
	var list: Array = offers.get(loc, [])
	for c in list:
		if c.id == cid:
			if str(c.kind) == "carry":
				if space_for(c.good) < int(c.qty):
					return false
				_stow(c.good, int(c.qty))
			contracts.append(c)
			list.erase(c)
			return true
	return false

func deliverable_contracts() -> Array:
	var out := []
	for c in contracts:
		if str(c.kind) == "carry" and c.to == loc and qty(c.good) >= int(c.qty):
			out.append(c)
		elif str(c.kind) == "bounty" and c.get("done", false) and c.from == loc:
			out.append(c)
	return out

## Hand in a contract: carry jobs at their destination, bounties back where you took them.
## The issuer gains 50 FP; a dirty job costs the destination's Accord holder 50 FP; every 3rd job of
## a side adds a bar point (§11.6).
func deliver_contract(cid: String) -> bool:
	for c in contracts:
		if c.id != cid or not deliverable_contracts().has(c):
			continue
		contracts.erase(c)
		if str(c.kind) == "carry":
			_take(c.good, int(c.qty))
		_earn(int(c.pay), str(c.money))
		stats.contracts += 1
		add_xp(int(c.pay) / 40)
		var issuer := str(c.get("issuer", "none"))
		add_rep(issuer, S.CONTRACT_FP)
		var side := ""
		if str(c.money) == "dirty":
			side = "outlaw"
			var target := faction_of(str(c.to))
			if S.FACTIONS.get(target, {}).get("bloc", "") == "paragon":
				add_rep(target, -S.CONTRACT_FP)
		elif S.FACTIONS.get(issuer, {}).get("bloc", "") == "paragon":
			side = "paragon"
		if side != "":
			contract_count[side] = int(contract_count[side]) + 1
			if int(contract_count[side]) % S.CONTRACT_BAR_EVERY == 0:
				add_bar(side, 1)
		return true
	return false

func _expire_contracts() -> void:
	for c in contracts.duplicate():
		if day > int(c.due) and not c.get("done", false):
			contracts.erase(c)
			add_rep(str(c.get("issuer", "none")), -S.CONTRACT_FP / 2)
			if str(c.kind) == "carry":
				news.push_front({"text": "Contract failed: %d x %s never reached %s.", "args": [int(c.qty), D.GOODS[c.good].name, D.WORLDS[c.to].name]})
			else:
				news.push_front({"text": "Bounty failed: the target at %s got away.", "args": [D.WORLDS[c.to].name]})

# ================================================================ shipyard and refits (§6)

func part_price(id: String) -> int:
	return int(round(int(D.MODULES[id].price) * (1.0 + stat("upgrade_cost"))))

func shop_modules() -> Array:
	var out := []
	if not has_service("shipyard"):
		return out
	var black: bool = black_market_open() and (bool(world().get("blind", false)) or flags.has("black_shipyard"))
	for id in D.MODULES:
		var m: Dictionary = D.MODULES[id]
		if m.shop == "legal" or (m.shop == "black" and black):
			out.append(id)
	return out

func buy_module(id: String) -> bool:
	var m: Dictionary = D.MODULES[id]
	if not shop_modules().has(id) or modules.get(m.slot) == id or specials.has(id):
		return false
	if not owned.has(id):
		if not pay(part_price(id), str(m.money)):
			return false
		owned.append(id)
	return fit_module(id)

## Owned parts can be swapped anywhere (Ship Layout tab). A special goes into a free special socket.
func fit_module(id: String) -> bool:
	if not D.MODULES.has(id):
		return false
	var m: Dictionary = D.MODULES[id]
	if not (owned.has(id) or D.START_MODULES.values().has(id)):
		return false
	if m.slot == "special":
		if specials.has(id) or specials.size() >= sockets("special"):
			return false
		specials.append(id)
	else:
		modules[m.slot] = id
	hull = mini(hull, max_hull())
	fuel = minf(fuel, float(tank()))
	return true

func unfit_special(id: String) -> bool:
	if not specials.has(id):
		return false
	specials.erase(id)
	return true

func modules_for(slot: String) -> Array:
	var out := []
	for id in D.MODULES:
		if D.MODULES[id].slot == slot and (owned.has(id) or D.START_MODULES.get(slot, "") == id):
			out.append(id)
	return out

## The next hull tier (Runner only, at a shipyard): its price, or -1.
func refit_price() -> int:
	if ship != "runner" or tier >= D.TIERS.size():
		return -1
	if flags.has("free_refit"):
		return 0   # T01: the hermit's hull plates
	return int(round(int(D.TIERS[tier].cost) * (1.0 + stat("upgrade_cost"))))

func can_refit() -> bool:
	var p := refit_price()
	return p >= 0 and has_service("shipyard") and can_pay(p, "any")

func refit() -> bool:
	if not can_refit():
		return false
	pay(refit_price(), "any")
	flags.erase("free_refit")
	tier += 1
	hull = max_hull()
	fuel = minf(float(tank()), fuel + 6.0)
	return true

# ================================================================ hints

## Fixer's tip (a hint): the best trade from here in this sector: [good, world, profit per unit].
## `reach_only`: only worlds this tank can reach now.
func best_trade(reach_only: bool = false) -> Array:
	var best := []
	var best_gain := 0
	for g in D.GOOD_ORDER:
		if not trades(g):
			continue
		var cost := price(g)
		for w in worlds_in(sector_of(loc)):
			if w == loc or not trades(g, w) or (reach_only and not can_reach(w)):
				continue
			var gain := sell_price(g, w) - cost
			if gain > best_gain:
				best_gain = gain
				best = [g, w, gain]
	return best

# ================================================================ save

func to_dict() -> Dictionary:
	return {"v": SAVE_VERSION, "seed": seed_value, "rng_state": str(rng.state), "captain": captain, "day": day,
		"clean": clean, "dirty": dirty, "debt": debt, "ship": ship, "tier": tier, "modules": modules,
		"specials": specials, "owned": owned, "fuel": fuel, "hull": hull, "sector": sector, "loc": loc,
		"cargo": cargo, "hidden": hidden, "paid": paid, "heat": heat, "rep": rep, "bars": bars, "xp": xp,
		"bonus_points": bonus_points, "skills": skills, "branches": branches, "flags": flags, "quests": quests,
		"crew": crew, "recruitable": recruitable, "lost_crew": lost_crew, "contracts": contracts,
		"nodes": nodes, "tributaries": tributaries, "ending": ending,
		"offers": offers, "offers_day": offers_day, "contract_count": contract_count, "supply": supply,
		"events": events, "news": news, "seen_prices": seen_prices, "laundry": laundry, "curses": curses,
		"used_calls": used_calls, "ghost_used": ghost_used, "lucky_used": lucky_used, "flare": flare,
		"stats": stats, "pending_story": pending_story, "encounter": encounter,
		"ship_pos": [ship_pos.x, ship_pos.y], "trip_px": trip_px, "flown_px": flown_px}

## The save's version (1 = the old galaxy, pack v1).
static func save_version(d: Dictionary) -> int:
	return int(d.get("v", 0))

func from_dict(d: Dictionary) -> bool:
	if int(d.get("v", 0)) != SAVE_VERSION:
		return false
	seed_value = int(d.get("seed", 1))
	rng.seed = seed_value
	if d.has("rng_state"):
		rng.state = int(str(d.rng_state))
	captain = default_captain()
	var cap: Dictionary = d.get("captain", {})
	for k in cap:
		captain[k] = cap[k]
	captain.picks = Array(captain.get("picks", [])).filter(func(p): return S.PERKS.has(str(p)))
	if not S.RACES.has(str(captain.race)):
		captain.race = "terran"
	day = int(d.day)
	clean = int(d.clean)
	dirty = int(d.dirty)
	debt = int(d.debt)
	ship = "runner" if str(d.get("ship", "")) == "runner" else "moth"
	tier = clampi(int(d.get("tier", 1)), 1, D.TIERS.size())
	modules = D.START_MODULES.duplicate()
	for slot in d.get("modules", {}):
		if D.MODULES.has(str(d.modules[slot])) and modules.has(slot):
			modules[slot] = str(d.modules[slot])
	specials = Array(d.get("specials", [])).filter(func(id): return D.MODULES.has(str(id)))
	owned = Array(d.get("owned", []))
	fuel = float(d.fuel)
	hull = int(d.hull)
	sector = str(d.get("sector", "cradle_reach"))
	if not D.SECTORS.has(sector):
		sector = "cradle_reach"
	loc = str(d.get("loc", D.START_WORLD))
	var sp: Array = d.get("ship_pos", [0, 0])
	ship_pos = Vector2(float(sp[0]), float(sp[1]))
	if loc != "" and not D.WORLDS.has(loc):
		loc = D.START_WORLD
	if loc == "" and ship_pos == Vector2.ZERO:
		loc = D.START_WORLD
	if loc != "":
		sector = sector_of(loc)
	trip_px = float(d.get("trip_px", 0.0))
	flown_px = float(d.get("flown_px", 0.0))
	cargo = _int_dict(d.get("cargo", {}))
	hidden = _int_dict(d.get("hidden", {}))
	paid = d.get("paid", {})
	heat = {"accord": float(d.get("heat", {}).get("accord", 0.0))}
	rep = {}
	for f in S.FACTION_ORDER:
		rep[f] = int(d.get("rep", {}).get(f, 0))
	bars = {"paragon": int(d.get("bars", {}).get("paragon", 0)), "outlaw": int(d.get("bars", {}).get("outlaw", 0))}
	xp = int(d.get("xp", 0))
	bonus_points = int(d.get("bonus_points", 0))
	skills = Array(d.get("skills", []))
	branches = Array(d.get("branches", []))
	flags = d.get("flags", {})
	quests = {}
	var qd: Dictionary = d.get("quests", {})
	for id in qd:
		if S.QUESTS.has(id):
			quests[id] = {"state": str(qd[id].get("state", "active")), "progress": int(qd[id].get("progress", 0))}
			if qd[id].has("visited"):
				quests[id]["visited"] = Array(qd[id].visited)
	crew = []
	for m in d.get("crew", []):
		if S.CREW.has(str(m.get("id", ""))):
			crew.append({"id": str(m.id), "loyalty": int(m.get("loyalty", 50)), "q": int(m.get("q", 0)), "rank": int(m.get("rank", 1))})
	recruitable = Array(d.get("recruitable", []))
	lost_crew = Array(d.get("lost_crew", []))
	nodes = int(d.get("nodes", 0))
	tributaries = Array(d.get("tributaries", [])).filter(func(w): return D.WORLDS.has(str(w)))
	ending = str(d.get("ending", ""))
	contracts = []
	for c in d.get("contracts", []):
		contracts.append(_contract_ints(c))
	offers = d.get("offers", {})
	for w in offers:
		for c in offers[w]:
			_contract_ints(c)
	offers_day = {}
	for w in d.get("offers_day", {}):
		offers_day[w] = int(d.offers_day[w])
	contract_count = {"paragon": int(d.get("contract_count", {}).get("paragon", 0)), "outlaw": int(d.get("contract_count", {}).get("outlaw", 0))}
	supply = d.get("supply", {})
	events = {}
	for w in d.get("events", {}):
		var ev: Dictionary = d.events[w]
		ev.until = int(ev.until)
		events[w] = ev
	news = Array(d.get("news", []))
	seen_prices = d.get("seen_prices", {})
	laundry = []
	for b in d.get("laundry", []):
		laundry.append({"amount": int(b.amount), "ready": int(b.ready)})
	curses = {}
	for c in d.get("curses", {}):
		if S.PERKS.has(c):
			curses[c] = int(d.curses[c])
	used_calls = Array(d.get("used_calls", []))
	ghost_used = bool(d.get("ghost_used", false))
	lucky_used = bool(d.get("lucky_used", false))
	flare = bool(d.get("flare", false))
	for k in stats:
		stats[k] = int(d.get("stats", {}).get(k, 0))
	pending_story = Array(d.get("pending_story", []))
	encounter = d.get("encounter", {})
	for k in ["bribe", "fine", "cash"]:
		if encounter.has(k):
			encounter[k] = int(encounter[k])
	tow_to = ""
	_migrate_v22()
	_invalidate()
	return true

## A v2 run from before the Quest Expansion (2026-11-08): N04 opened the gates then. Keep them open
## (the Rift Key counts as found) and start the Act I quests that come after N03 / N04.
func _migrate_v22() -> void:
	if quest_state("N03") == "done" and not quests.has("N09"):
		accept_quest("N09")
	if quest_state("N04") == "done" and not quests.has("N10"):
		if flags.has("act1_done"):
			flags["rift_key"] = true
			quests["N10"] = {"state": "done", "progress": 1}
			quests["N11"] = {"state": "done", "progress": 0}
			accept_quest("N12")
			accept_quest("M05")
		else:
			accept_quest("N10")

static func _contract_ints(c: Dictionary) -> Dictionary:
	c.qty = int(c.get("qty", 0))
	c.pay = int(c.pay)
	c.due = int(c.due)
	if not c.has("kind"):
		c["kind"] = "carry"
	return c

static func _int_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		if D.GOODS.has(k) and int(src[k]) > 0:
			out[k] = int(src[k])
	return out
