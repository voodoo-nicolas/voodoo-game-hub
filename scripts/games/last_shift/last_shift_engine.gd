extends RefCounted

## Last Shift: pure logic (no Nodes), so it can be tested headless:
##   godot --headless --path . --script res://tests/test_last_shift_engine.gd

## The four directions Nash can face (top-down, 4-way).
enum Facing { DOWN, LEFT, RIGHT, UP }

## How much stronger the new axis must be before facing flips between
## horizontal and vertical. Stops the sprite flickering on diagonal movement.
const FACING_HYSTERESIS := 1.25

## Picks a 4-way facing from a movement vector.
## `current` is kept when the vector is zero or the axes are nearly tied.
static func facing_from_vector(v: Vector2, current: int) -> int:
	if v == Vector2.ZERO:
		return current
	var ax := absf(v.x)
	var ay := absf(v.y)
	var horizontal := current == Facing.LEFT or current == Facing.RIGHT
	# Decide the axis, with hysteresis toward the axis we are already on.
	var use_vertical: bool
	if horizontal:
		use_vertical = ay > ax * FACING_HYSTERESIS
	else:
		use_vertical = not (ax > ay * FACING_HYSTERESIS)
	if use_vertical:
		return Facing.DOWN if v.y > 0.0 else Facing.UP
	return Facing.RIGHT if v.x > 0.0 else Facing.LEFT

## Unit vector for a facing (for attacks, interaction ray, drawing).
static func facing_to_vector(f: int) -> Vector2:
	match f:
		Facing.LEFT:
			return Vector2.LEFT
		Facing.RIGHT:
			return Vector2.RIGHT
		Facing.UP:
			return Vector2.UP
	return Vector2.DOWN

## Lowercase name, used by the debug label and later by sprite animation names.
static func facing_name(f: int) -> String:
	return ["down", "left", "right", "up"][f]

# ---------------------------------------------------------------- Chiller Four puzzle (slice 2)
# Simple heat/flow logic: each valve passes some coolant when open. The chiller needs
# exactly CHILLER_TARGET units: too little and it runs hot, too much trips the pressure relief.

## Coolant each of the 3 valves passes when open (valve 1, 2, 3). Painted on the valves.
const VALVE_FLOWS := [2, 3, 4]
const CHILLER_TARGET := 5

## Total flow for a list of open/closed valves (true = open).
static func chiller_flow(open: Array) -> int:
	var total := 0
	for i in mini(open.size(), VALVE_FLOWS.size()):
		if open[i]:
			total += VALVE_FLOWS[i]
	return total

## Chiller temperature in degrees C: more flow = cooler, never below 18.
static func chiller_temp(flow: int) -> int:
	return maxi(18, 60 - flow * 6)

## "low" (running hot), "ok" (exactly the target), or "high" (pressure relief trips).
static func chiller_status(flow: int) -> String:
	if flow < CHILLER_TARGET:
		return "low"
	if flow == CHILLER_TARGET:
		return "ok"
	return "high"

## Rough on-screen time for a subtitle line, in seconds.
static func line_seconds(text: String) -> float:
	return 2.0 + text.length() * 0.045

# ---------------------------------------------------------------- Lobby vent puzzle (slice 5)
# The lockdown panel is overheating. Four vent dampers each pass some airflow when open.
# The panel only releases the doors at exactly VENT_TARGET units (too much trips it again).

const VENT_FLOWS := [1, 2, 3, 5]
const VENT_TARGET := 7

static func vent_flow(open: Array) -> int:
	var total := 0
	for i in mini(open.size(), VENT_FLOWS.size()):
		if open[i]:
			total += VENT_FLOWS[i]
	return total

## "low", "ok" (exactly the target) or "high".
static func vent_status(flow: int) -> String:
	if flow < VENT_TARGET:
		return "low"
	if flow == VENT_TARGET:
		return "ok"
	return "high"

## Formats play time as m:ss.
static func format_time(seconds: float) -> String:
	var t := int(seconds)
	return "%d:%02d" % [t / 60, t % 60]

# ---------------------------------------------------------------- generic flow puzzles (slice 6)
# Every puzzle is "set the valves/vents so the total flow is exactly the target".
# (Too little = low, too much = high.) Chiller (plant), pump (flooded stairwell), vents (lobby).

const PUZZLES := {
	"chiller": {"flows": [2, 3, 4], "target": 5},
	"pump": {"flows": [1, 2, 4, 5], "target": 8},
	"vents": {"flows": [1, 2, 3, 5], "target": 7},
}

static func puzzle_size(puzzle_id: String) -> int:
	return PUZZLES[puzzle_id].flows.size()

static func puzzle_target(puzzle_id: String) -> int:
	return PUZZLES[puzzle_id].target

static func puzzle_flow_of(puzzle_id: String, index: int) -> int:
	return PUZZLES[puzzle_id].flows[index]

## Total flow for a list of open/closed valves (true = open).
static func puzzle_flow(puzzle_id: String, open: Array) -> int:
	var flows: Array = PUZZLES[puzzle_id].flows
	var total := 0
	for i in mini(open.size(), flows.size()):
		if open[i]:
			total += flows[i]
	return total

## "low", "ok" (exactly the target) or "high".
static func puzzle_status(puzzle_id: String, flow: int) -> String:
	var target: int = PUZZLES[puzzle_id].target
	if flow < target:
		return "low"
	if flow == target:
		return "ok"
	return "high"

# ---------------------------------------------------------------- health and combat numbers (v0.4, v0.5)
# Nash's health is out of 100 (the HUD shows "70/100"). Enemy hit points: a wrench hit or a bullet
# does 2, the knife 3 (v0.4: the knife hits harder than the wrench, but is short and silent), a
# punch or the severed arm 1.
# v0.5 (third playtest: "Normal is too easy", 27 min, no heals used until the last fight): the
# infected have more hit points, are faster and hit a little harder; snacks heal less, there are
# fewer first-aid kits, and health only ticks back part of the way on Normal and Hard.

const NASH_MAX_HP := 100
## Damage each attacker does to Nash on Normal (scaled by DIFFICULTY).
## v0.4: walker 15, runner 25, screamer 8, guard 20, shooter 12, brute 30, crawler 10, gary 18.
const DAMAGE := {"walker": 18, "runner": 28, "screamer": 10, "guard": 20, "shooter": 12,
	"brute": 35, "crawler": 12, "gary": 22}
## Healing items from the bag. v0.4: snack 20.
const HEAL := {"medkit": 50, "snack": 10}
## Hit points of each enemy kind. v0.4: walker 4, screamer 2, runner 6, brute 10, crawler 2, gary 6.
const ENEMY_HP := {"walker": 6, "screamer": 3, "runner": 8, "guard": 4, "shooter": 4,
	"brute": 14, "crawler": 3, "gary": 8}
## Hit points of the people who are NOT enemies (ambient survivors), against the infected.
const PERSON_HP := 3
## How long a person killed by the infected lies there before getting back up as one of them.
const TURN_SECONDS := 7.0
## Armor (worn, not carried): it soaks up ARMOR_SOAK of every hit until its points run out.
const ARMOR := {"vest": 40, "riot": 100}
const ARMOR_SOAK := 0.6
## Bullets Nash can carry (they never take a bag slot).
const AMMO_MAX := 99
## Coolant cans Nash can carry (a counter, like bullets).
const CANS_MAX := 5

## Easy / Normal / Hard (hub STANDARDS section 4 names). damage = multiplier on DAMAGE; regen = health
## ticks back `regen_delay` s after the last threat, 1 HP every `regen_tick` s, up to `regen_cap`.
## Enemies in the room data carry "diff" (0 = always, 1 = Normal and Hard, 2 = Hard only).
## v0.4 Normal: delay 6, tick 0.5, cap 100. Hard: 8, 0.8, 60.
const DIFFICULTY := [
	{"name": "Easy", "damage": 0.6, "regen_delay": 3.0, "regen_tick": 0.25, "regen_cap": 100},
	{"name": "Normal", "damage": 1.0, "regen_delay": 8.0, "regen_tick": 0.7, "regen_cap": 60},
	{"name": "Hard", "damage": 1.4, "regen_delay": 10.0, "regen_tick": 1.0, "regen_cap": 35},
]

## Nash's weapons. Melee: reach (px), damage, cooldown (s), noise (radius in px: infected this
## close hear it and come to look), push (knockback). The pistol has a range instead of a reach.
## The knife is silent, and an infected that hasn't noticed Nash goes down in one stab ("sneak").
## v0.5: the severed arm (weak, but reaches further than the wrench) and the coolant can (thrown:
## it bursts into a freezing cloud that slows every infected in it; it hurts nobody).
const WEAPONS := {
	"fist": {"reach": 36.0, "damage": 1, "cooldown": 0.35, "noise": 120.0, "push": 170.0},
	"knife": {"reach": 40.0, "damage": 3, "cooldown": 0.24, "noise": 0.0, "push": 70.0, "sneak": 99},
	"arm": {"reach": 68.0, "damage": 1, "cooldown": 0.4, "noise": 200.0, "push": 220.0},
	# wrench recovery 0.3 s (was 0.55, shortened on request)
	"wrench": {"reach": 52.0, "damage": 2, "cooldown": 0.3, "noise": 300.0, "push": 240.0},
	"pistol": {"range": 340.0, "damage": 2, "cooldown": 0.25, "noise": 650.0},
	"coolant": {"range": 230.0, "radius": 74.0, "slow": 0.35, "seconds": 7.0, "cooldown": 0.7, "noise": 160.0},
}
## The weapon wheel's order (and the keyboard's 1-6).
const WEAPON_ORDER := ["fist", "knife", "arm", "wrench", "pistol", "coolant"]
## Weapons that hit whoever is in front of Nash.
const MELEE := ["fist", "knife", "arm", "wrench"]

## Damage of one melee hit. Dwayne (the runner) shrugs off all melee: he must be shot.
## Nash never stabs a person: the knife does nothing to guards and shooters (use fists).
## `aware` = the target has noticed Nash (a knife on an unaware infected is a takedown; not on
## the brute, he is too big for that).
static func melee_damage(weapon: String, target_kind: String, aware: bool) -> int:
	if target_kind == "runner":
		return 0
	var w: Dictionary = WEAPONS[weapon]
	if weapon == "knife":
		if target_kind == "guard" or target_kind == "shooter":
			return 0
		if not aware and target_kind != "brute":
			return int(w.sneak)
	return int(w.damage)

## One hit on Nash: {"hp": health lost, "armor": armor lost}. Difficulty scales the hit, armor
## takes ARMOR_SOAK of it while it lasts.
static func hit_on_nash(base: int, difficulty: int, armor: int) -> Dictionary:
	var dmg := maxi(1, int(round(base * float(DIFFICULTY[clampi(difficulty, 0, 2)].damage))))
	var soak := mini(armor, int(round(dmg * ARMOR_SOAK)))
	return {"hp": dmg - soak, "armor": soak}

## Which bag item a quick heal (tap the health bar) uses: a snack for a small wound, else a
## first-aid kit. "" when nothing is missing or nothing is left.
static func quick_heal_item(missing: int, medkits: int, snacks: int) -> String:
	if missing <= 0:
		return ""
	if snacks > 0 and (missing <= HEAL.snack + 10 or medkits == 0):
		return "snack"
	if medkits > 0:
		return "medkit"
	return ""

## What a body holds when it is searched (decided by its id, so it is the same every time).
## Humans (guards, shooters) always carry a few bullets.
static func body_loot(enemy_id: String, kind: String) -> Array:
	if kind == "guard" or kind == "shooter":
		return [{"item": "bullets", "n": 3}]
	if kind == "gary":
		return [{"item": "money", "n": 20}, {"item": "snack", "n": 1}]
	if kind == "brute":
		return [{"item": "money", "n": 4}]      # v0.5: no first-aid kit any more (his hat drops instead)
	# v0.5: infected never carry first-aid kits (fewer kits overall), and fewer snacks.
	var h := absi(enemy_id.hash()) % 100
	if h < 35:
		return [{"item": "money", "n": 1 + h % 3}]
	if h < 48:
		return [{"item": "snack", "n": 1}]
	if h < 62:
		return [{"item": "bullets", "n": 2}]
	return []

# ---------------------------------------------------------------- search, quests

## Searching a locker / desk / cabinet / body takes this long (moving or getting hit cancels it).
const SEARCH_SECONDS := 2.0

## The mission log. Each entry: id -> text key (LsText.QUEST). A quest shows up the first time its
## "show" rule is true and is ticked when its "done" rule is true (see quest_status). Order = order
## in the log.
## v0.5: the night starts as an ordinary shift (no ESCAPE! yet). "escape" is a quest of its own: it
## appears after the first attack and is always listed first (MAIN_QUEST). The quest texts say WHAT
## to do, not the answer (the numbers are in the emails and memos, the places are for the player to
## find): playtest note "don't make the quests easier than they are supposed to be".
const QUESTS := ["enter", "elevator", "chiller", "escape", "hide", "wrench", "inspect", "basement", "keycard",
	"pump", "maint", "nash_locker", "pistol", "sec_key", "alarm", "armory", "gift", "eotm", "promotion",
	"cutters", "fire_exit", "dock", "lockdown", "front"]
## Always listed first (and named in the log's header) once it shows up.
const MAIN_QUEST := "escape"
## Side quests: the header of the closed log only names one of these when no main step is open.
const SIDE_QUESTS := ["inspect", "keycard", "nash_locker", "alarm", "armory", "gift", "eotm", "promotion",
	"cutters", "fire_exit", "dock"]

## "hidden", "active" or "done" for one quest. `st` = the world's state, `ctx` = {"wrench", "pistol",
## "knife", "room"} (things that live on Nash, not in the state).
static func quest_status(id: String, st: Dictionary, ctx: Dictionary) -> String:
	var v: Dictionary = st.get("visited", {})
	var read: Dictionary = st.get("read", {})
	var tried: Dictionary = st.get("tried", {})
	var flags: Dictionary = st.get("flags", {})
	var show := false
	var done := false
	match id:
		"enter":
			show = true
			done = st.entered_lobby
		"elevator":
			show = st.entered_lobby
			done = v.has("plant")
		"chiller":
			show = v.has("plant")
			done = st.solved.chiller
		"escape":
			show = st.attack_done
			done = st.get("exit", "") != ""
		"hide":
			show = st.attack_done
			done = flags.has("hid") or st.kills > 0
		"wrench":
			show = st.attack_done
			done = ctx.get("wrench", false)
		"inspect":
			show = st.kills > 0
			done = flags.has("inspected")
		"basement":
			# the way up out of B2 (pump room -> locker room -> break room)
			show = st.attack_done and ctx.get("wrench", false)
			done = v.has("break_room")
		"keycard":
			show = tried.has("door_cooling")
			done = st.has_keycard
		"pump":
			show = v.has("pump_room")
			done = st.solved.pump
		"maint":
			show = v.has("locker_room") or tried.has("door_to_break")
			done = st.has_maint_key
		"nash_locker":
			show = read.has("dwayne_locker")
			done = st.searched.has("locker_nash")
		"pistol":
			show = v.has("security_hall")
			done = ctx.get("pistol", false)
		"sec_key":
			show = ctx.get("pistol", false)
			done = st.has_sec_key
		"alarm":
			show = v.has("security_office") and st.alarm
			done = flags.has("alarm_off")
		"armory":
			# v0.5: only once the security team's message about the riot gear has been read
			show = read.has("sec_riot")
			done = st.searched.has("riot_rack")
		"gift":
			show = read.has("gift")
			done = ctx.get("knife", false)
		"eotm":
			show = read.has("hr_eotm")
			done = flags.has("eotm_seen")
		"promotion":
			show = v.has("open_office") and st.attack_done
			done = st.dead.has("gary")
		"cutters":
			show = tried.has("door_fire")
			done = flags.has("cutters")
		"fire_exit":
			show = flags.has("cutters") and tried.has("door_fire")
			done = st.get("exit", "") == "fire"
		"dock":
			show = tried.has("door_dock")
			done = st.get("exit", "") == "dock"
		"lockdown":
			show = st.lobby_alarm_seen or tried.has("door_front")
			done = st.solved.vents
		"front":
			show = st.solved.vents
			done = st.get("exit", "") == "front"
	if not show and not done:
		return "hidden"
	return "done" if done else "active"

# ---------------------------------------------------------------- achievements (Viral XP)
# Shown as they unlock and on the end card; kept across runs (last_shift_achievements.gd).
# In the hub these become the game's own badges (<id>_help.gd). The XP is called "<brand> XP"
# ("Viral XP", decided 2026-10-14; the name comes from the hub's Brand, see LsAch.xp_name()).
# XP per achievement:

const ACHIEVEMENTS := {
	"not_my_shift": 25,    # survive the first attack
	"coroner": 25,         # inspect the first zombie
	"promotion": 100,      # take down Gary at his party (from the FPS script: "Promotion")
	"honorable": 10,       # read the Employee of the Month wall
	"lights_out": 25,      # switch off the alarm
	"riot_ready": 25,      # put on the riot gear
	"birthday": 25,        # find Marisol's gift
	"scavenger": 50,       # search 40 things in one run
	"front_door": 50,      # escape through the front doors
	"back_door": 100,      # escape through the loading dock
	"fire_drill": 100,     # escape through the fire exit
	"three_ways": 200,     # escape all three ways (over several runs)
	"veteran": 150,        # escape on Hard
	"party_animal": 25,    # wear the party hat (on Gary's cake table)
	"head_chef": 25,       # wear the cook's hat (the brute cook drops it, v0.5)
}
const SCAVENGER_COUNT := 40
## Which achievement each exit gives.
const EXIT_ACHIEVEMENT := {"front": "front_door", "dock": "back_door", "fire": "fire_drill"}
