extends RefCounted

## Turned: the pure game state and rules (no Nodes), so tools/test_turned.gd can run it headless.
## Health, Blood, XP, the sun's damage, death penalties, which buttons are unlocked, the Journal,
## the mission line and the sneak toggle. The world (turned_world.gd) feeds it "is the player's
## foot in the sun" and draws the result.

const T = preload("res://scripts/games/turned/turned_tuning.gd")

## Journal and mission texts are ids; the words live in turned_text.gd.
var area := "house"                 # "house" | "street"
var pos := Vector2.ZERO
var hp := 0.0
var max_hp := 0.0
var blood := 0.0
var max_blood := 0.0
var xp := 0.0
var level := 1
var day := 1                        # in-game day; vampirism_level follows it
var tolerance_bonus := 0.0          # feeding raises it (feeding is not built yet)
var feeds_today := 0
var deaths := 0
var buttons: Array = []             # unlocked face buttons: "a", later "b", "x", "y"
var dpad := false                   # the d-pad is shown (it unlocks in the prologue)
var show_bars := false              # Health/Blood/XP are shown (introduced when the sun is)
var mission := ""                   # id in turned_text MISSIONS, "" = none yet
var journal: Array = []             # ids: clue ids and turned_text JOURNAL ids, in order found
var flags: Dictionary = {}          # one-shot story flags
var sneaking := false
var burned_this_visit := false      # for the "it burns" line once

var _since_damage := 99.0

func _init() -> void:
	reset()

func reset() -> void:
	area = "house"
	pos = Vector2.ZERO
	max_hp = T.f("stats.max_hp")
	hp = max_hp
	max_blood = T.f("stats.max_blood")
	blood = T.f("stats.start_blood")
	xp = 0.0
	level = 1
	day = 1
	tolerance_bonus = 0.0
	feeds_today = 0
	deaths = 0
	buttons = ["a"]
	dpad = false
	show_bars = false
	mission = ""
	journal = []
	flags = {}
	sneaking = false
	burned_this_visit = false
	_since_damage = 99.0

# ---------------------------------------------------------------- sun

## 0 on day 1 ... 5 on day 6+ (Turned's CLAUDE.md section 5).
func vampirism_level() -> int:
	return clampi(day - 1, 0, 5)

func effective_level() -> int:
	return int(floorf(maxf(0.0, float(vampirism_level()) - tolerance_bonus)))

## HP lost per second in direct sun at full strength.
func sun_dps() -> float:
	var table := T.arr("sun.dps_by_level")
	if table.is_empty():
		return 0.0
	return float(table[clampi(effective_level(), 0, table.size() - 1)])

## One frame of health: damage if the player's foot is in the sun, slow regeneration otherwise.
## `sun` is the clock's strength 0..1 (0 at night). Returns true when Health just reached 0.
func tick_health(delta: float, in_sun: bool, sun: float) -> bool:
	if in_sun and sun > 0.0:
		_since_damage = 0.0
		hp = maxf(0.0, hp - sun_dps() * sun * delta)
		if hp <= 0.0:
			return true
	else:
		_since_damage += delta
		if _since_damage >= T.f("sun.regen_delay_s") and hp < max_hp:
			hp = minf(max_hp, hp + T.f("sun.regen_per_s") * delta)
	blood = maxf(0.0, blood - T.f("stats.blood_drain_per_s") * delta)
	return false

## Death by sun (CLAUDE.md section 6): half the Health comes back, a quarter of the Blood is lost,
## a tenth of the XP in the current level is lost (never de-levels).
func apply_death() -> void:
	deaths += 1
	hp = max_hp * T.f("death.respawn_hp_frac")
	blood = floorf(blood * (1.0 - T.f("death.blood_loss_frac")))
	var per_level := T.f("stats.xp_per_level")
	var into_level := fmod(xp, per_level)
	xp -= floorf(into_level * T.f("death.xp_loss_frac"))
	_since_damage = 99.0

# ---------------------------------------------------------------- walking and sneaking

func speed() -> float:
	var s := T.f("player.walk_speed")
	return s * T.f("player.sneak_speed_mult") if sneaking else s

## How far (px) an enemy could notice the player. No enemies yet: the world draws it as a ring.
func detect_radius_px() -> float:
	return T.m(T.f("sneak.sneak_detect_radius_m") if sneaking else T.f("sneak.detect_radius_m"))

func noise_radius_px() -> float:
	return T.m(T.f("sneak.sneak_noise_radius_m") if sneaking else T.f("sneak.noise_radius_m"))

func unlock_button(b: String) -> bool:
	if b in buttons:
		return false
	buttons.append(b)
	return true

func has_button(b: String) -> bool:
	return b in buttons

## B toggles sneaking (only once it is unlocked). Returns the new state.
func toggle_sneak() -> bool:
	if not has_button("b"):
		return false
	sneaking = not sneaking
	return sneaking

# ---------------------------------------------------------------- story

func has_flag(f: String) -> bool:
	return flags.has(f)

func set_flag(f: String) -> void:
	flags[f] = true

## Adds a Journal entry; false if it was already there.
func add_journal(id: String) -> bool:
	if id in journal:
		return false
	journal.append(id)
	return true

func set_mission(id: String) -> void:
	mission = id

# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return {
		"area": area, "pos": [pos.x, pos.y], "hp": hp, "max_hp": max_hp, "blood": blood,
		"xp": xp, "level": level, "day": day, "tolerance_bonus": tolerance_bonus,
		"feeds_today": feeds_today, "deaths": deaths, "buttons": buttons.duplicate(),
		"dpad": dpad, "show_bars": show_bars, "mission": mission, "journal": journal.duplicate(),
		"flags": flags.duplicate(), "sneaking": sneaking,
	}

func from_dict(d: Dictionary) -> void:
	reset()
	area = str(d.get("area", "house"))
	var p: Array = d.get("pos", [0.0, 0.0])
	pos = Vector2(float(p[0]), float(p[1])) if p.size() >= 2 else Vector2.ZERO
	max_hp = float(d.get("max_hp", max_hp))
	hp = clampf(float(d.get("hp", max_hp)), 1.0, max_hp)
	blood = clampf(float(d.get("blood", blood)), 0.0, max_blood)
	xp = float(d.get("xp", 0.0))
	level = int(d.get("level", 1))
	day = int(d.get("day", 1))
	tolerance_bonus = float(d.get("tolerance_bonus", 0.0))
	feeds_today = int(d.get("feeds_today", 0))
	deaths = int(d.get("deaths", 0))
	buttons = (d.get("buttons", ["a"]) as Array).duplicate()
	dpad = bool(d.get("dpad", false))
	show_bars = bool(d.get("show_bars", false))
	mission = str(d.get("mission", ""))
	journal = (d.get("journal", []) as Array).duplicate()
	flags = (d.get("flags", {}) as Dictionary).duplicate()
	sneaking = bool(d.get("sneaking", false)) and has_button("b")
