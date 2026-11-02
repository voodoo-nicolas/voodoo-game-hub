extends RefCounted

## The Runner's rules: money (clean / dirty), markets, cargo, fuel and travel, heat and scans,
## encounters and fights, laundering, missions, contracts, skills, modules, net worth. No Nodes:
## tests drive it headless (tools/test_the_runner.gd). Content comes from the_runner_data.gd.
## Formulas: design doc §9 (docs/runner/GAME_DESIGN_THE_RUNNER.md), numbers here.
## Every message it returns is English; screens translate it (tr) before showing.

const D = preload("res://scripts/games/the_runner/the_runner_data.gd")

const SAVE_VERSION := 1
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

var rng := RandomNumberGenerator.new()
var seed_value: int = 0

var day: int = 1
var clean: int = 400
var dirty: int = 0
var debt: int = D.START_DEBT
var ship: String = "moth"
var modules: Dictionary = {}      # slot -> module id
var owned: Array = []             # module ids bought (any slot)
var fuel: float = 12.0
var hull: int = 60
var loc: String = D.START_WORLD   # world id, or "" while in flight
var cargo: Dictionary = {}        # good -> qty (open hold)
var hidden: Dictionary = {}       # good -> qty (hidden hold)
var paid: Dictionary = {}         # good -> average price paid per unit (for profit)
var heat: Dictionary = {}         # police faction -> 0..100
var infamy: int = 0
var cred: int = 0
var xp: int = 0
var bonus_points: int = 0
var skills: Array = []            # skill ids
var branches: Array = []          # [primary, secondary]
var flags: Dictionary = {}
var missions: Dictionary = {}     # id -> {"state": "active"|"done", "progress": int}
var contracts: Array = []         # accepted: {id, good, qty, from, to, pay, money, due}
var offers: Dictionary = {}       # world -> Array of contract offers (made per day)
var offers_day: Dictionary = {}   # world -> day the offers were made
var supply: Dictionary = {}       # world -> {good -> factor} (moves with your trades, eases back)
var events: Dictionary = {}       # world -> {id, good, until}
var news: Array = []              # newest first, English strings
var seen_prices: Dictionary = {}  # world -> {good -> price} the last time you docked there
var laundry: Array = []           # {amount, ready}
var encounter: Dictionary = {}    # the open encounter, {} = none
var flown_px: float = 0.0         # since the last event roll
var trip_px: float = 0.0          # this trip, for days
var ghost_used: bool = false
var flare: bool = false           # a solar flare: the next scan sees nothing
var stats := {"runs": 0, "scans_passed": 0, "scans_failed": 0, "bribes": 0, "fights_won": 0,
	"fights_lost": 0, "contracts": 0, "best_haul": 0, "profit": 0, "salvages": 0, "trips": 0,
	"best_net": 0, "captured": 0, "laundered": 0}
var pending_story: Array = []     # story ids for the screens to show
var ship_pos := Vector2.ZERO      # on the map (map pixels), kept by the map while flying

func _init() -> void:
	reset()

func reset(p_seed: int = 0) -> void:
	seed_value = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system()) ^ randi()
	rng.seed = seed_value
	day = 1
	clean = 400
	dirty = 0
	debt = D.START_DEBT
	ship = "moth"
	modules = D.START_MODULES.duplicate()
	owned = []
	loc = D.START_WORLD
	cargo = {}
	hidden = {}
	paid = {}
	heat = {}
	for f in D.POLICE:
		heat[f] = 0.0
	infamy = 0
	cred = 0
	xp = 0
	bonus_points = 0
	skills = []
	branches = []
	flags = {}
	missions = {}
	contracts = []
	offers = {}
	offers_day = {}
	supply = {}
	events = {}
	news = []
	seen_prices = {}
	laundry = []
	encounter = {}
	flown_px = 0.0
	trip_px = 0.0
	ghost_used = false
	flare = false
	for k in stats:
		stats[k] = 0
	pending_story = ["prologue"]
	fuel = float(tank())
	hull = max_hull()
	accept_mission("M01")
	_remember_prices(loc)

## A message for the screens: an English template and its values (strings among them are names,
## translated too). The screen shows tr(text) % args.
static func _l(text: String, args: Array = []) -> Dictionary:
	return {"text": text, "args": args}

# ================================================================ ship stats

func _mod(slot: String) -> Dictionary:
	return D.MODULES.get(modules.get(slot, ""), {})

func _mod_sum(key: String) -> float:
	var t := 0.0
	for slot in D.SLOTS:
		t += float(_mod(slot).get(key, 0.0))
	return t

func has_skill(id: String) -> bool:
	return skills.has(id)

func cargo_cap() -> int:
	return int(D.SHIPS[ship].cargo) + int(_mod_sum("cargo"))

func hidden_cap() -> int:
	return int(D.SHIPS[ship].hidden) + int(_mod_sum("hidden")) + (2 if has_skill("sm_hold") else 0)

func tank() -> int:
	return int(D.SHIPS[ship].tank)

func max_hull() -> int:
	return int(D.SHIPS[ship].hull) + (20 if has_skill("en_armor") else 0)

func shield() -> int:
	return int(_mod_sum("shield"))

func guns() -> int:
	return int(D.SHIPS[ship].guns) + (1 if has_skill("en_gunnery") else 0)

func stealth() -> int:
	return int(D.SHIPS[ship].stealth) + int(_mod_sum("stealth"))

func hold_quality() -> int:
	return int(_mod_sum("quality"))

func fuel_factor() -> float:
	return float(_mod("engine").get("fuel", 1.0))

func can_sniff() -> bool:
	return bool(_mod("scanner").get("sniff", false))

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

func modules_value() -> int:
	var v := 0
	for slot in modules:
		v += int(D.MODULES[modules[slot]].price / 2)
	return v

func cargo_value() -> int:
	var v := 0
	for g in D.GOODS:
		var n := qty(g)
		if n > 0:
			v += n * int(D.GOODS[g].base)
	return v

## Design doc §3.3: clean + assets + 30% of dirty (minus what you owe).
func net_worth() -> int:
	return clean + modules_value() + cargo_value() + int(dirty * 0.3) - debt

# ================================================================ levels and skills

func level() -> int:
	var lv := 1
	var need := XP_STEP
	var left := xp
	while left >= need:
		left -= need
		lv += 1
		need = XP_STEP * lv
	return lv

func xp_into_level() -> Array:
	var lv := 1
	var need := XP_STEP
	var left := xp
	while left >= need:
		left -= need
		lv += 1
		need = XP_STEP * lv
	return [left, need]

func skill_points() -> int:
	return level() - 1 + bonus_points - skills.size()

func add_xp(n: int) -> void:
	xp += maxi(0, n)

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

## Forger capstone: wipe Concord heat once.
func use_ghost_identity() -> bool:
	if not has_skill("fo_ghost") or ghost_used:
		return false
	ghost_used = true
	heat["concord"] = 0.0
	return true

# ================================================================ heat

func heat_of(f: String) -> float:
	return float(heat.get(f, 0.0))

func heat_tier(f: String) -> String:
	var h := heat_of(f)
	for t in D.HEAT_TIERS:
		if h <= float(t[0]):
			return str(t[1])
	return "Public Enemy"

func add_heat(f: String, n: float) -> void:
	if not D.POLICE.has(f):
		f = "concord"
	if n > 0 and has_skill("fo_spoof"):
		n *= 0.75
	heat[f] = clampf(heat_of(f) + n, 0.0, 100.0)

func max_heat() -> float:
	var m := 0.0
	for f in heat:
		m = maxf(m, float(heat[f]))
	return m

func _cool_heat(days: int) -> void:
	var rate := HEAT_DECAY * (2.0 if has_skill("sm_lanes") else 1.0)
	if loc != "" and D.WORLDS[loc].blind:
		rate *= 2.0
	for f in heat:
		heat[f] = maxf(0.0, float(heat[f]) - rate * days)

# ================================================================ markets

func world(id: String = "") -> Dictionary:
	return D.WORLDS.get(id if id != "" else loc, {})

func has_service(s: String, w: String = "") -> bool:
	return world(w).get("services", []).has(s)

func law_at(w: String) -> int:
	var l := int(world(w).get("law", 0))
	if events.has(w):
		for e in D.EVENTS:
			if e.id == events[w].id:
				l += int(e.law)
	return clampi(l, 0, 5)

func black_market_open(w: String = "") -> bool:
	return bool(world(w).get("black", false)) and flags.has("black_market")

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

## The price of one unit at world `w` (what you pay to buy; selling gets 92% of it).
func price(good: String, w: String = "") -> int:
	if w == "":
		w = loc
	var g: Dictionary = D.GOODS[good]
	var wd: Dictionary = world(w)
	var f := float(wd.get("makes", {}).get(good, 1.0)) * float(wd.get("wants", {}).get(good, 1.0))
	if g.contraband:
		f *= 1.0 + 0.12 * law_at(w)   # risk premium (design doc §9)
	f *= _event_mult(w, good) * _supply(w, good)
	return maxi(1, int(round(float(g.base) * f)))

func sell_price(good: String, w: String = "") -> int:
	return maxi(1, int(price(good, w) * 0.92))

func _move_supply(w: String, good: String, units: int) -> void:
	if not supply.has(w):
		supply[w] = {}
	supply[w][good] = clampf(_supply(w, good) + SLIP * units, 0.55, 1.7)

## Free space for a good: contraband fills the hidden hold first.
func space_for(good: String) -> int:
	var free_open := cargo_cap() - used(cargo)
	if D.GOODS[good].contraband:
		return free_open + hidden_cap() - used(hidden)
	return free_open

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

## Units of a good that mission or contract cargo still needs (not for sale).
func reserved(good: String) -> int:
	var n := 0
	for c in contracts:
		if c.good == good:
			n += int(c.qty)
	for id in missions:
		if missions[id].state == "active" and D.MISSIONS[id].get("give", {}).has(good):
			n += int(D.MISSIONS[id].give[good])
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
	if D.GOODS[good].contraband:
		dirty += earned
	else:
		clean += earned
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

## Throw cargo out of the airlock (never what a job or mission still needs).
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

func repair_cost() -> int:
	return (max_hull() - hull) * REPAIR_PRICE

func repair() -> bool:
	if not has_service("shipyard") or hull >= max_hull():
		return false
	var cost := repair_cost()
	if not can_pay(cost, "any"):
		var pts := total_credits() / REPAIR_PRICE
		if pts <= 0:
			return false
		pay(pts * REPAIR_PRICE, "any")
		hull += pts
		return true
	pay(cost, "any")
	hull = max_hull()
	return true

func launder_rate() -> float:
	return LAUNDER_RATE + (0.08 if has_skill("la_books") else 0.0)

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
			add_heat("concord", 10)
			msgs.append(_l("Audit at the laundry! Half the batch was seized."))
		clean += out
		stats.laundered += out
		msgs.append(_l("Laundry ready: %d clean credits.", [out]))
	laundry = keep
	return msgs

# ================================================================ travel

func distance_to(w: String) -> float:
	return pos_of(w).distance_to(pos_of(loc)) if loc != "" else 0.0

func pos_of(w: String) -> Vector2:
	var p: Array = D.WORLDS[w].pos
	return Vector2(float(p[0]), float(p[1]))

func fuel_for(px: float) -> float:
	return px * FUEL_PER_PX * fuel_factor()

func can_reach(w: String) -> bool:
	return fuel_for(distance_to(w)) <= fuel + 0.001

## Leave the current world (the map then moves the ship and calls fly() as it goes).
func launch() -> bool:
	if loc == "" or not encounter.is_empty():
		return false
	loc = ""
	trip_px = 0.0
	stats.trips += 1
	return true

## The ship flew `px` map pixels: fuel burns, and now and then something happens. Returns true if an
## encounter opened (the map stops the ship until it is closed).
func fly(px: float, at: Vector2 = Vector2.ZERO) -> bool:
	if px <= 0.0 or not encounter.is_empty():
		return false
	fuel = maxf(0.0, fuel - fuel_for(px))
	trip_px += px
	flown_px += px
	if fuel <= 0.0:
		_open({"kind": "no_fuel", "at": [at.x, at.y]})
		return true
	for h in D.HAZARDS:
		var hp := Vector2(float(h.pos[0]), float(h.pos[1]))
		if at != Vector2.ZERO and at.distance_to(hp) < float(h.r) and not flags.has("in_" + str(h.id)):
			flags["in_" + str(h.id)] = true
			_open({"kind": str(h.kind)})
			return true
		if at.distance_to(hp) >= float(h.r) + 20.0:
			flags.erase("in_" + str(h.id))
	if flown_px >= EVENT_EVERY_PX:
		flown_px = 0.0
		if rng.randf() < EVENT_CHANCE:
			_random_event()
			return true
	return false

func _days_for(px: float) -> int:
	return maxi(1, int(ceil(px / PX_PER_DAY)))

## Dock at world `w` (the ship is on it). Time passes, prices move, a patrol may scan you.
## Returns the encounter opened on arrival ({} = none).
func arrive(w: String) -> Dictionary:
	loc = w
	var days := _days_for(trip_px)
	trip_px = 0.0
	stats.runs += 1
	pass_days(days)
	_remember_prices(w)
	if encounter.is_empty():
		_maybe_scan(w)
	if encounter.is_empty() and law_at(w) <= 1 and w != "gravel" and rng.randf() < 0.12 + float(infamy) / 400.0:
		_open_fight("pirate", "Raiders were waiting at the dock.")
	return encounter

func pass_days(days: int) -> void:
	for i in days:
		day += 1
		_cool_heat(1)
		for w in supply:
			for g in supply[w]:
				supply[w][g] = lerpf(float(supply[w][g]), 1.0, 0.15)
		_tick_events()
		for m in _collect_laundry():
			news.push_front(m)
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
			if has_service("market", w) and not events.has(w):
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

func scan_chance(w: String) -> float:
	var f: String = D.WORLDS[w].faction
	var h := heat_of(f) if D.POLICE.has(f) else heat_of("concord") * 0.5
	return clampf(0.08 + law_at(w) * 0.12 + h / 250.0, 0.0, 0.95)

## Design doc §9 scan_pass_chance, plus skills and the open hold.
func pass_chance(w: String) -> float:
	var f: String = D.WORLDS[w].faction
	var h := heat_of(f) if D.POLICE.has(f) else heat_of("concord") * 0.5
	var p := 0.65 + (stealth() - law_at(w)) * 0.05 + hold_quality() * 0.1 - law_at(w) * 0.04 - h / 200.0
	p += float(_mod("scanner").get("scan", 0.0))
	p += (0.10 if has_skill("sm_cool") else 0.0) + (0.08 if has_skill("fo_papers") else 0.0)
	if contraband_in_open() > 0:
		p *= 0.35
	return clampf(p, 0.02, 0.98)

func _maybe_scan(w: String) -> void:
	if law_at(w) <= 0:
		return
	if rng.randf() >= scan_chance(w):
		return
	var police: String = D.WORLDS[w].faction if D.POLICE.has(D.WORLDS[w].faction) else "concord"
	if contraband_aboard() == 0:
		_open({"kind": "scan_clean", "faction": police})
		return
	if flare:
		flare = false
		_open({"kind": "scan_blind", "faction": police})
		_scan_passed()
		return
	if rng.randf() < pass_chance(w):
		_open({"kind": "scan_pass", "faction": police})
		_scan_passed()
	else:
		stats.scans_failed += 1
		_open({"kind": "inspect", "faction": police, "bribe": bribe_cost(), "fine": int(contraband_value() * 0.3)})

func _scan_passed() -> void:
	stats.scans_passed += 1
	add_xp(15)
	for id in missions:
		var m: Dictionary = missions[id]
		if m.state == "active" and D.MISSIONS[id].steps[0].type == "scans":
			m.progress = int(m.progress) + 1
			if id == "M04" and int(m.progress) == 1 and not flags.has("vane"):
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
	return c

# ================================================================ encounters

## What can be chosen now: Array of [option id, English label, enabled].
func options() -> Array:
	var e := encounter
	match str(e.get("kind", "")):
		"inspect":
			return [["bribe", _l("Bribe (%d)", [int(e.bribe)]), can_pay(int(e.bribe), "any")],
				["dump", "Dump the contraband", true], ["run", "Run for it", true],
				["fight", "Fight", true], ["submit", _l("Submit (fine %d)", [int(e.fine)]), true]]
		"pirates":
			var o := [["tribute", _l("Pay tribute (%d)", [tribute_cost()]), can_pay(tribute_cost(), "any")],
				["run", "Run for it", true], ["fight", "Fight", true]]
			if infamy >= 25:
				o.insert(0, ["scare", "Scare them off", true])
			return o
		"fight":
			return [["attack", "Open fire", true], ["evade", "Evade", true], ["run", "Run for it", true]]
		"derelict":
			return [["salvage", "Salvage it", true], ["leave", "Leave it", true]]
		"distress":
			return [["help", "Answer the call", true], ["leave", "Fly on", true]]
		"pod":
			return [["take", "Take the pod", true], ["leave", "Leave it", true]]
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

func _open_fight(enemy: String, why: String) -> void:
	var ed: Dictionary = D.ENEMIES[enemy]
	_open({"kind": "pirates" if enemy == "pirate" else "fight", "enemy": enemy, "ehull": int(ed.hull),
		"emax": int(ed.hull), "why": why, "evading": false})

func _random_event() -> void:
	var r := rng.randf()
	if r < 0.28:
		_open_fight("pirate", "A raider ship drops out of the dark and hails you.")
	elif r < 0.45:
		_open({"kind": "derelict"})
	elif r < 0.58:
		_open({"kind": "distress"})
	elif r < 0.70:
		_open({"kind": "meteors"})
		var dmg := rng.randi_range(4, 14)
		hull = maxi(1, hull - dmg)
		encounter["log"] = [_l("Rocks hammer the hull: -%d hull.", [dmg])]
	elif r < 0.80:
		_open({"kind": "pod"})
	elif r < 0.90:
		flare = true
		_open({"kind": "flare"})
	else:
		_open({"kind": "tip"})
		_give_tip()
	if r < 0.28 and max_heat() > 60.0 and rng.randf() < 0.5:
		_open_fight("hunter", "A bounty hunter has your face on a poster.")

func _give_tip() -> void:
	var best := []
	var best_gain := 0
	for w in D.WORLD_ORDER:
		for g in D.GOOD_ORDER:
			if not D.GOODS[g].contraband or not D.WORLDS[w].black:
				continue
			var gain := price(g, w) - int(D.GOODS[g].base)
			if gain > best_gain:
				best_gain = gain
				best = [g, w]
	if best.is_empty():
		encounter["log"] = ["The informant has nothing worth hearing."]
	else:
		encounter["log"] = [_l("An informant whispers: %s sells high on %s.", [D.GOODS[best[0]].name, D.WORLDS[best[1]].name])]

## Pick an option. Returns the English lines that describe what happened (also in encounter.log).
## When the encounter is over, `encounter` is {} again.
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
			close = encounter.get("kind", "") != "fight"
		"pirates":
			out = _pirates(opt)
			close = encounter.get("kind", "") != "fight"
		"fight":
			out = _fight_round(opt)
			close = encounter.get("done", false)
		"derelict", "salvage_site":
			if opt == "salvage":
				out = _salvage(kind == "salvage_site")
		"distress":
			if opt == "help":
				if rng.randf() < 0.3:
					_open_fight("pirate", "It was a trap!")
					return ["It was a trap!"]
				var gift := rng.randi_range(200, 600)
				clean += gift
				cred = mini(100, cred + 3)
				add_xp(20)
				out = [_l("You patch their engine. They pay %d clean credits.", [gift])]
		"pod":
			if opt == "take":
				var g: String = ["forged_ids", "bootleg_data", "weapons"][rng.randi() % 3]
				var n := mini(rng.randi_range(1, 3), space_for(g))
				_stow(g, n)
				out = [_l("Someone's dumped contraband: %d x %s.", [n, D.GOODS[g].name])] if n > 0 else ["No room aboard."]
		"no_fuel":
			out = _tow()
		"sun":
			var dmg := rng.randi_range(10, 20)
			hull = maxi(1, hull - dmg)
			out = [_l("Too close to the Sun: -%d hull.", [dmg])]
		"black_hole":
			var lost := minf(fuel, 2.0)
			fuel -= lost
			out = [_l("The Maw pulls at the ship. You burn %d fuel to break free.", [int(lost)])]
	if close:
		encounter = {}
	else:
		encounter["log"] = out
	return out

func _tow() -> Array:
	var near := ""
	var best := INF
	var a: Array = encounter.get("at", [0, 0])
	var here := Vector2(float(a[0]), float(a[1]))
	for w in D.WORLD_ORDER:
		if not has_service("fuel", w):
			continue
		var d := pos_of(w).distance_to(here)
		if d < best:
			best = d
			near = w
	if near == "":
		near = D.START_WORLD
	if can_pay(TOW_PRICE, "any"):
		pay(TOW_PRICE, "any")
	else:
		debt += TOW_PRICE
	fuel = 2.0
	tow_to = near
	return [_l("A tug drags you to %s.", [D.WORLDS[near].name])]

var tow_to: String = ""   # set by a tow: the map puts the ship there and docks

func _inspect(opt: String) -> Array:
	var f := str(encounter.faction)
	match opt:
		"bribe":
			var c := int(encounter.bribe)
			if not pay(c, "dirty"):
				return _confiscate(f, "You can't pay the bribe.")
			var ok := rng.randf() < clampf(0.95 - law_at(loc) * 0.07 - heat_of(f) / 300.0, 0.3, 0.95)
			stats.bribes += 1
			if ok:
				if has_skill("fx_favors"):
					add_heat(f, -8)
				return [_l("The officer pockets %d credits and looks the other way.", [c])]
			add_heat(f, 12)
			return _confiscate(f, "The officer takes the money AND the cargo.")
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
			_open_fight("patrol", "They cut you off. Weapons hot.")
			encounter["faction"] = f
			return ["They cut you off. Weapons hot."]
		"fight":
			_open_fight("patrol", "You open fire on the patrol.")
			encounter["faction"] = f
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
	return clampf(0.4 + _mod_sum("flee") + stealth() * 0.03, 0.1, 0.9)

func _pirates(opt: String) -> Array:
	match opt:
		"scare":
			if rng.randf() < 0.4 + infamy / 200.0 or has_skill("pi_fear"):
				infamy = mini(100, infamy + 2)
				return ["They see whose ship it is and turn tail."]
			encounter["kind"] = "fight"
			return ["They aren't impressed. Weapons hot."]
		"tribute":
			var c := tribute_cost()
			if not pay(c, "dirty"):
				encounter["kind"] = "fight"
				return ["You can't pay. Weapons hot."]
			return [_l("You pay %d. They let you go.", [c])]
		"run":
			if rng.randf() < flee_chance():
				return ["You outrun them."]
			encounter["kind"] = "fight"
			return ["They're faster. Weapons hot."]
		"fight":
			encounter["kind"] = "fight"
			return ["Weapons hot."]
	return []

func _damage() -> int:
	var d := 0
	for i in guns():
		d += rng.randi_range(8, 14)
	d = int(d * float(_mod("weapons").get("dmg", 1.0)) * (1.25 if has_skill("pi_board") else 1.0))
	return d

func _fight_round(opt: String) -> Array:
	var e := encounter
	var ed: Dictionary = D.ENEMIES[e.enemy]
	var out := []
	e.evading = false
	if opt == "run":
		if rng.randf() < flee_chance() * 0.8:
			e.done = true
			if e.enemy == "patrol":
				add_heat(str(e.get("faction", "concord")), 10)
			return ["You break away and run."]
		out.append("You can't shake them!")
	elif opt == "evade":
		e.evading = true
		out.append("You jink and roll.")
	else:
		var d := _damage()
		e.ehull = maxi(0, int(e.ehull) - d)
		out.append(_l("You hit them for %d.", [d]))
		if int(e.ehull) <= 0:
			e.done = true
			return out + _won_fight()
	var hit := rng.randi_range(int(ed.dmg[0]), int(ed.dmg[1]))
	if e.evading:
		hit = int(hit * 0.4)
	var absorbed := mini(hit, shield())
	hit -= absorbed / 2
	hull -= hit
	out.append(_l("They hit you for %d.", [hit]))
	if hull <= 0:
		e.done = true
		return out + _lost_fight()
	return out

func _won_fight() -> Array:
	var e := encounter
	var ed: Dictionary = D.ENEMIES[e.enemy]
	stats.fights_won += 1
	add_xp(40)
	var loot := rng.randi_range(int(ed.loot[0]), int(ed.loot[1]))
	if has_skill("en_warlord"):
		loot = int(loot * 1.5)
	dirty += loot
	var out := ["They're finished."]
	if loot > 0:
		out.append(_l("You strip the wreck: %d dirty credits.", [loot]))
	if e.enemy == "patrol":
		infamy = mini(100, infamy + 8)
		add_heat(str(e.get("faction", "concord")), 25)
	else:
		infamy = mini(100, infamy + 3)
	for id in missions:
		var m: Dictionary = missions[id]
		if m.state == "active" and D.MISSIONS[id].steps[0].type == "fights":
			m.progress = int(m.progress) + 1
	return out

## Hull at zero: captured. Cargo and half the dirty credits are gone, towed to Luna.
func _lost_fight() -> Array:
	stats.fights_lost += 1
	stats.captured += 1
	cargo = {}
	hidden = {}
	paid = {}
	dirty /= 2
	hull = maxi(10, max_hull() / 3)
	fuel = maxf(fuel, 3.0)
	tow_to = D.START_WORLD
	pending_story.append("captured")
	return ["Your ship goes dark."]

func _salvage(site: bool) -> Array:
	stats.salvages += 1
	var mult := 1.5 if has_skill("pi_salvage") else 1.0
	var out := []
	var cash := int(rng.randi_range(80, 400) * mult * (1.5 if site else 1.0))
	dirty += cash
	out.append(_l("You find %d in old credit chips.", [cash]))
	var pool := ["ore", "alloys", "electronics", "stolen_tech", "relics"] if site else ["ore", "alloys", "stolen_tech"]
	var g: String = pool[rng.randi() % pool.size()]
	var n := mini(int(rng.randi_range(1, 3) * mult), space_for(g))
	if n > 0:
		_stow(g, n)
		out.append(_l("And %d x %s.", [n, D.GOODS[g].name]))
	if site and rng.randf() < 0.25:
		_open_fight("pirate", "Scavengers want the same wrecks.")
		return out + ["Scavengers want the same wrecks."]
	add_xp(10)
	return out

## Old Earth's wreck ring: search it from the dock (one day).
func start_salvage() -> bool:
	if not has_service("salvage") or not encounter.is_empty():
		return false
	pass_days(1)
	_open({"kind": "salvage_site"})
	return true

# ================================================================ missions

func mission_state(id: String) -> String:
	return str(missions.get(id, {}).get("state", ""))

func accept_mission(id: String) -> bool:
	if missions.has(id):
		return false
	var m: Dictionary = D.MISSIONS[id]
	var give: Dictionary = m.get("give", {})
	for g in give:
		if space_for(g) < int(give[g]):
			return false
	missions[id] = {"state": "active", "progress": 0}
	for g in give:
		_stow(g, int(give[g]))
		paid[g] = 0.0
	return true

## Side missions offered at this world right now.
func side_offers() -> Array:
	var out := []
	for id in D.SIDE_ORDER:
		if D.MISSIONS[id].giver == loc and not missions.has(id):
			out.append(id)
	return out

func active_missions() -> Array:
	var out := []
	for id in D.MAIN_ORDER + D.SIDE_ORDER:
		if mission_state(id) == "active":
			out.append(id)
	return out

## The step's progress text values: [have, need].
func mission_progress(id: String) -> Array:
	var st: Dictionary = D.MISSIONS[id].steps[0]
	match str(st.type):
		"deliver": return [mini(qty(st.good), int(st.qty)), int(st.qty)]
		"pay": return [maxi(0, D.START_DEBT - debt), D.START_DEBT]
		"scans", "fights": return [int(missions[id].progress), int(st.n)]
		"reach": return [1 if loc == st.to else 0, 1]
	return [0, 1]

## Can it be completed here, now?
func can_complete(id: String) -> bool:
	if mission_state(id) != "active":
		return false
	var st: Dictionary = D.MISSIONS[id].steps[0]
	match str(st.type):
		"deliver": return loc == st.to and qty(st.good) >= int(st.qty)
		"pay": return debt <= 0
		"scans", "fights": return int(missions[id].progress) >= int(st.n)
		"reach": return loc == st.to
	return false

func complete(id: String) -> bool:
	if not can_complete(id):
		return false
	var m: Dictionary = D.MISSIONS[id]
	var st: Dictionary = m.steps[0]
	if st.type == "deliver":
		_take(st.good, int(st.qty))
	missions[id].state = "done"
	var r: Dictionary = m.reward
	clean += int(r.get("clean", 0))
	dirty += int(r.get("dirty", 0))
	add_xp(int(r.get("xp", 0)))
	bonus_points += int(r.get("points", 0))
	cred = mini(100, cred + int(r.get("cred", 0)))
	infamy = mini(100, infamy + int(r.get("infamy", 0)))
	if r.has("unlock"):
		flags[str(r.unlock)] = true
	if r.has("ship"):
		ship = str(r.ship)
		hull = max_hull()
		fuel = float(tank())
	if r.has("module"):
		modules[D.MODULES[r.module].slot] = str(r.module)
	if m.has("story_done"):
		pending_story.append(str(m.story_done))
	var nxt := str(m.get("next", ""))
	if nxt != "":
		accept_mission(nxt)
	return true

## Broke and stuck (no credits to speak of, nothing to sell, not enough fuel to go anywhere):
## Mother Kessel wires a loan, any port. The safety net, so no run ever soft-locks.
const LOAN := 500
const LOAN_COST := 600

func can_borrow() -> bool:
	if loc == "" or total_credits() >= 150:
		return false
	for g in D.GOODS:
		if qty(g) - reserved(g) > 0 and trades(g):
			return false
	return true

func borrow() -> bool:
	if not can_borrow():
		return false
	clean += LOAN
	debt += LOAN_COST   # paid back at Luna like the first debt (Kessel's Terms pays its reward once)
	return true

## Pay Mother Kessel (at Luna).
func pay_debt(amount: int) -> int:
	if loc != "luna" or debt <= 0:
		return 0
	amount = mini(amount, mini(debt, total_credits()))
	if amount <= 0:
		return 0
	pay(amount, "dirty")
	debt -= amount
	return amount

## Completes every mission that is done (reach / scans / fights / pay finish by themselves).
func auto_complete() -> Array:
	var done := []
	for id in active_missions():
		var t := str(D.MISSIONS[id].steps[0].type)
		if t != "deliver" and can_complete(id):
			complete(id)
			done.append(id)
	return done

# ================================================================ contracts

func contract_offers() -> Array:
	if loc == "" or not has_service("fixer"):
		return []
	if int(offers_day.get(loc, -1)) != day:
		_make_offers()
	return offers.get(loc, [])

func _make_offers() -> void:
	var list := []
	var count := CONTRACTS_PER_PORT + (1 if has_skill("fx_contacts") else 0)
	for i in count:
		var to: String = loc
		while to == loc or not has_service("market", to):
			to = D.WORLD_ORDER[rng.randi() % D.WORLD_ORDER.size()]
		var shady := flags.has("black_market") and rng.randf() < 0.45
		var pool := []
		for g in D.GOOD_ORDER:
			if bool(D.GOODS[g].contraband) == shady:
				pool.append(g)
		var g: String = pool[rng.randi() % pool.size()]
		var n := rng.randi_range(2, 5)
		var dist := pos_of(loc).distance_to(pos_of(to))
		var pay_amt := int((120 + dist * 1.1 + n * int(D.GOODS[g].base) * 0.12) * (1.6 if shady else 1.0))
		if has_skill("fx_contacts"):
			pay_amt = int(pay_amt * 1.15)
		list.append({"id": "%s_%d_%d" % [loc, day, i], "good": g, "qty": n, "from": loc, "to": to,
			"pay": pay_amt, "money": "dirty" if shady else "clean", "due": day + 3 + _days_for(dist) * 2})
	offers[loc] = list
	offers_day[loc] = day

func take_contract(cid: String) -> bool:
	var list: Array = offers.get(loc, [])
	for c in list:
		if c.id == cid:
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
		if c.to == loc and qty(c.good) >= int(c.qty):
			out.append(c)
	return out

func deliver_contract(cid: String) -> bool:
	for c in contracts:
		if c.id == cid and c.to == loc and qty(c.good) >= int(c.qty):
			contracts.erase(c)
			_take(c.good, int(c.qty))
			if c.money == "dirty":
				dirty += int(c.pay)
			else:
				clean += int(c.pay)
			cred = mini(100, cred + 1)
			stats.contracts += 1
			add_xp(int(c.pay) / 40)
			return true
	return false

func _expire_contracts() -> void:
	for c in contracts.duplicate():
		if day > int(c.due):
			contracts.erase(c)
			cred = maxi(0, cred - 3)
			news.push_front({"text": "Contract failed: %d x %s never reached %s.", "args": [int(c.qty), D.GOODS[c.good].name, D.WORLDS[c.to].name]})

# ================================================================ shipyard

func shop_modules() -> Array:
	var out := []
	if not has_service("shipyard"):
		return out
	var black: bool = black_market_open() and (loc == "gravel" or flags.has("black_shipyard"))
	for id in D.MODULES:
		var m: Dictionary = D.MODULES[id]
		if m.shop == "legal" or (m.shop == "black" and black):
			out.append(id)
	return out

func buy_module(id: String) -> bool:
	var m: Dictionary = D.MODULES[id]
	if not shop_modules().has(id) or modules.get(m.slot) == id:
		return false
	if not owned.has(id):
		if not pay(int(m.price), str(m.money)):
			return false
		owned.append(id)
	modules[m.slot] = id
	hull = mini(hull, max_hull())
	fuel = minf(fuel, float(tank()))
	return true

## Owned modules can be swapped anywhere (Ship Layout tab).
func fit_module(id: String) -> bool:
	if not (owned.has(id) or D.START_MODULES.values().has(id) or (id == "spc_ghost" and mission_state("M03") == "done")):
		return false
	modules[D.MODULES[id].slot] = id
	return true

func modules_for(slot: String) -> Array:
	var out := []
	for id in D.MODULES:
		if D.MODULES[id].slot == slot and (owned.has(id) or D.START_MODULES[slot] == id or (id == "spc_ghost" and mission_state("M03") == "done")):
			out.append(id)
	return out

# ================================================================ hints

## Fixer's tip (a hint): the best legal-or-black trade from here: [good, world, profit per unit].
## `reach_only`: only worlds this tank can reach now.
func best_trade(reach_only: bool = false) -> Array:
	var best := []
	var best_gain := 0
	for g in D.GOOD_ORDER:
		if not trades(g):
			continue
		var cost := price(g)
		for w in D.WORLD_ORDER:
			if w == loc or not trades(g, w) or (reach_only and not can_reach(w)):
				continue
			var gain := sell_price(g, w) - cost
			if gain > best_gain:
				best_gain = gain
				best = [g, w, gain]
	return best

# ================================================================ save

func to_dict() -> Dictionary:
	return {"v": SAVE_VERSION, "seed": seed_value, "rng_state": str(rng.state), "day": day, "clean": clean,
		"dirty": dirty, "debt": debt, "ship": ship, "modules": modules, "owned": owned, "fuel": fuel,
		"hull": hull, "loc": loc, "cargo": cargo, "hidden": hidden, "paid": paid, "heat": heat,
		"infamy": infamy, "cred": cred, "xp": xp, "bonus_points": bonus_points, "skills": skills,
		"branches": branches, "flags": flags, "missions": missions, "contracts": contracts,
		"offers": offers, "offers_day": offers_day, "supply": supply, "events": events, "news": news,
		"seen_prices": seen_prices, "laundry": laundry, "ghost_used": ghost_used, "flare": flare,
		"stats": stats, "pending_story": pending_story, "encounter": encounter,
		"ship_pos": [ship_pos.x, ship_pos.y], "trip_px": trip_px, "flown_px": flown_px}

func from_dict(d: Dictionary) -> bool:
	if int(d.get("v", 0)) != SAVE_VERSION:
		return false
	seed_value = int(d.get("seed", 1))
	rng.seed = seed_value
	if d.has("rng_state"):
		rng.state = int(str(d.rng_state))
	day = int(d.day)
	clean = int(d.clean)
	dirty = int(d.dirty)
	debt = int(d.debt)
	ship = str(d.ship) if D.SHIPS.has(str(d.ship)) else "moth"
	modules = D.START_MODULES.duplicate()
	for slot in d.get("modules", {}):
		if D.MODULES.has(str(d.modules[slot])):
			modules[slot] = str(d.modules[slot])
	owned = Array(d.get("owned", []))
	fuel = float(d.fuel)
	hull = int(d.hull)
	loc = str(d.get("loc", D.START_WORLD))
	var sp: Array = d.get("ship_pos", [0, 0])
	ship_pos = Vector2(float(sp[0]), float(sp[1]))
	if loc != "" and not D.WORLDS.has(loc):
		loc = D.START_WORLD
	if loc == "" and ship_pos == Vector2.ZERO:
		loc = D.START_WORLD
	trip_px = float(d.get("trip_px", 0.0))
	flown_px = float(d.get("flown_px", 0.0))
	cargo = _int_dict(d.get("cargo", {}))
	hidden = _int_dict(d.get("hidden", {}))
	paid = d.get("paid", {})
	heat = d.get("heat", {})
	for f in D.POLICE:
		heat[f] = float(heat.get(f, 0.0))
	infamy = int(d.get("infamy", 0))
	cred = int(d.get("cred", 0))
	xp = int(d.get("xp", 0))
	bonus_points = int(d.get("bonus_points", 0))
	skills = Array(d.get("skills", []))
	branches = Array(d.get("branches", []))
	flags = d.get("flags", {})
	missions = d.get("missions", {})
	for id in missions:
		missions[id].progress = int(missions[id].get("progress", 0))
	contracts = []
	for c in d.get("contracts", []):
		c.qty = int(c.qty)
		c.pay = int(c.pay)
		c.due = int(c.due)
		contracts.append(c)
	offers = d.get("offers", {})
	for w in offers:
		for c in offers[w]:
			c.qty = int(c.qty)
			c.pay = int(c.pay)
			c.due = int(c.due)
	offers_day = {}
	for w in d.get("offers_day", {}):
		offers_day[w] = int(d.offers_day[w])
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
	ghost_used = bool(d.get("ghost_used", false))
	flare = bool(d.get("flare", false))
	for k in stats:
		stats[k] = int(d.get("stats", {}).get(k, 0))
	pending_story = Array(d.get("pending_story", []))
	encounter = d.get("encounter", {})
	for k in ["ehull", "emax", "bribe", "fine"]:
		if encounter.has(k):
			encounter[k] = int(encounter[k])
	tow_to = ""
	return true

static func _int_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		if D.GOODS.has(k) and int(src[k]) > 0:
			out[k] = int(src[k])
	return out
