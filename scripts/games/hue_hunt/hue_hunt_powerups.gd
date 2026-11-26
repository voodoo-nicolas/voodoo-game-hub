extends RefCounted

## Camera Hunter: the power-up registry (multiplayer only; solo has the kit's
## helps instead, STANDARDS §17). Pure data + rules, used by hue_hunt_room.gd.
##
## Add a power-up: one entry in POWERS, a `can_use` rule below, and its effect
## in hue_hunt_room.gd use_power() + hue_hunt_game.gd (drawing it).
##   icon, name, how  -- shown on the button / in How to Play (English; es.json)
##   seconds          -- how long it lasts (0 = instant)
##   rounds           -- round types it works in ([] = all)
##   needs            -- "hunting" (not locked in yet) / "locked" (after lock-in)

const E = preload("res://scripts/games/hue_hunt/hue_hunt_engine.gd")

const MAX_PER_MATCH := 3    # a player gets at most this many in one match
const START_WITH := 1       # everyone starts with one

const POWERS := {
	"hot_cold": {"icon": "🌡", "name": "Hot / Cold", "seconds": 10.0, "needs": "hunting",
		"rounds": [E.T_CLASSIC, E.T_DUO, E.T_MIX, E.T_OPPOSITE, E.T_BLIND],
		"how": "For 10 seconds a meter shows how close the middle of your camera is."},
	"peek": {"icon": "👁", "name": "Peek", "seconds": 0.0, "needs": "hunting",
		"rounds": [E.T_BLIND],
		"how": "Shows the colour in a Blind round."},
	"second_chance": {"icon": "🔁", "name": "Second Chance", "seconds": 0.0, "needs": "locked",
		"rounds": [],
		"how": "Take back your lock-in and shoot again."},
}


static func ids() -> Array:
	return POWERS.keys()


## Can player n use `id` right now in state st?
static func can_use(st: Dictionary, n: int, id: String, now: float) -> bool:
	if not POWERS.has(id) or st.phase != "round" or now > float(st.deadline):
		return false
	var p: Dictionary = POWERS[id]
	var spec: Dictionary = st.plan[int(st.round_i)]
	if not p.rounds.is_empty() and spec.type not in p.rounds:
		return false
	var locked: bool = st.lockins.has(str(n))
	if p.needs == "hunting" and locked:
		return false
	if p.needs == "locked" and not locked:
		return false
	if id == "peek" and int(st.get("peeks", {}).get(str(n), -1)) == int(st.round_i):
		return false
	return true


## A power-up for a player, picked from the seed so every host picks the same.
static func pick(seed_v: int, salt: int) -> String:
	var all := ids()
	return all[absi(hash([seed_v, salt])) % all.size()]
