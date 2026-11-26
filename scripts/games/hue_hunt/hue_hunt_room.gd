extends RefCounted

## Camera Hunter multiplayer: the table's state machine, pure (no Nodes, no
## network), so it runs headless (tools/test_hue_hunt.gd). The acting host
## (hue_hunt_game.gd: the lowest-numbered player still at the table) calls
## these and broadcasts the whole state; everyone else only draws it.
##
## State (JSON-safe; seats are strings because JSON keys are strings):
##   ver        bumps on every change; a client takes a state with ver >= its own
##   match_id   new for every match (the seed), so a fresh match always wins
##   phase      "round" / "reveal" / "final"
##   settings   {rounds, selection, place, difficulty}
##   plan       RoundSpecs (hue_hunt_engine.gd)
##   round_i, started (host s), first_close_t (host s, -1), deadline (host s)
##   seats      [n, ...] who plays (player numbers from OnlineTable)
##   scores     {"n": points}
##   lockins    {"n": {t, labs:[[L,a,b]...], value, de, pct, close}}
##   flags      {"n": [voter n, ...]}   votes against n's photo this round
##   awards     last round's awards [{player, award, points}]
##   reveal_end host s when the reveal closes by itself
##   now        host s when this state was sent (clients derive their offset)
## Thumbnails never go in the state: they travel once as their own event and
## are dropped after the reveal.

const E = preload("res://scripts/games/hue_hunt/hue_hunt_engine.gd")

const REVEAL_TIME := 25.0
const DEFAULTS := {"rounds": 10, "selection": "classic", "place": "local", "difficulty": "normal"}


static func new_match(settings: Dictionary, seats: Array, seed_v: int, now: float) -> Dictionary:
	var s := DEFAULTS.duplicate()
	s.merge(settings, true)
	var plan := E.plan_match({"seed": seed_v, "rounds": int(s.rounds), "selection": s.selection,
		"solo": false, "objects": [], "place": s.place})
	var scores := {}
	for n in seats:
		scores[str(n)] = 0
	var st := {"ver": 0, "match_id": seed_v, "phase": "round", "settings": s, "plan": plan, "round_i": 0, "seats": seats.duplicate(),
		"scores": scores, "lockins": {}, "flags": {}, "awards": [], "first_close_t": -1.0,
		"started": now, "deadline": 0.0, "reveal_end": 0.0, "now": now}
	st.deadline = E.round_deadline(plan[0], now, -1.0)
	return st


static func spec(st: Dictionary) -> Dictionary:
	return st.plan[int(st.round_i)]


## A player locks in. Returns true if the state changed. One lock-in per
## round; late ones (after the deadline / outside a round) are refused.
static func lock_in(st: Dictionary, n: int, labs: Array, now: float) -> bool:
	var key := str(n)
	if st.phase != "round" or not st.scores.has(key) or st.lockins.has(key) or now > float(st.deadline):
		return false
	var v3 := []
	for l in labs:
		v3.append(Vector3(float(l[0]), float(l[1]), float(l[2])))
	if v3.size() < int(spec(st).taps):
		return false
	var sc := E.score(spec(st), v3, st.settings.difficulty)
	st.lockins[key] = {"t": now, "labs": labs, "value": sc.value, "de": sc.de, "pct": E.solo_pct(spec(st), v3), "close": sc.close}
	if sc.close and float(st.first_close_t) < 0.0:
		st.first_close_t = now
		st.deadline = E.round_deadline(spec(st), float(st.started), now)
	_bump(st)
	return true


## Second Chance (power-up, phase 5): take a lock-in back.
static func unlock(st: Dictionary, n: int) -> bool:
	if st.phase != "round" or not st.lockins.has(str(n)):
		return false
	st.lockins.erase(str(n))
	# First Close stays where it was: the countdown already started for everyone.
	_bump(st)
	return true


## Moves the clock on. `present` = player numbers at the table now: the round
## ends when the time is up or every present player has locked in.
static func tick(st: Dictionary, present: Array, now: float) -> bool:
	match st.phase:
		"round":
			var all_in := true
			var anyone := false
			for n in present:
				if st.scores.has(str(n)):
					anyone = true
					if not st.lockins.has(str(n)):
						all_in = false
			if now >= float(st.deadline) or (anyone and all_in):
				st.phase = "reveal"
				st.reveal_end = now + REVEAL_TIME
				st.flags = {}
				st.awards = resolve(st)
				_bump(st)
				return true
		"reveal":
			if now >= float(st.reveal_end):
				return end_reveal(st, now)
	return false


## The awards for the current round, given the flags so far.
static func resolve(st: Dictionary) -> Array:
	var voters: int = maxi(0, st.seats.size() - 1)
	var list := []
	for key in st.lockins:
		var e: Dictionary = st.lockins[key].duplicate()
		e.player = key
		e.flagged = E.flag_majority(st.flags.get(key, []).size(), voters)
		list.append(e)
	return E.resolve(spec(st), list).awards


## A vote to flag n's photo (people, something rude, a fake). Voters can't
## flag themselves or vote twice. Awards are worked out again at once.
static func flag(st: Dictionary, voter: int, target: int) -> bool:
	var key := str(target)
	if st.phase != "reveal" or voter == target or not st.lockins.has(key) or not st.scores.has(str(voter)):
		return false
	var votes: Array = st.flags.get(key, [])
	for v in votes:
		if int(v) == voter:   # JSON makes ints floats
			return false
	votes.append(voter)
	st.flags[key] = votes
	st.awards = resolve(st)
	_bump(st)
	return true


static func flagged(st: Dictionary, n: int) -> bool:
	return E.flag_majority(st.flags.get(str(n), []).size(), maxi(0, st.seats.size() - 1))


## Reveal over: points go on the board, next round or the final.
static func end_reveal(st: Dictionary, now: float) -> bool:
	if st.phase != "reveal":
		return false
	E.add_awards(st.scores, st.awards)
	if int(st.round_i) + 1 >= st.plan.size():
		st.phase = "final"
	else:
		st.round_i = int(st.round_i) + 1
		st.phase = "round"
		st.lockins = {}
		st.flags = {}
		st.first_close_t = -1.0
		st.started = now
		st.deadline = E.round_deadline(spec(st), now, -1.0)
	_bump(st)
	return true


## Reveal order: worst first (the best is the last to slide in). Flagged
## photos go first, then by value high to low.
static func reveal_order(st: Dictionary) -> Array:
	var keys: Array = st.lockins.keys()
	var out := []
	for k in keys:
		out.append(k)
	out.sort_custom(func(a, b):
		var fa := flagged(st, int(a))
		var fb := flagged(st, int(b))
		if fa != fb:
			return fa
		var la: Dictionary = st.lockins[a]
		var lb: Dictionary = st.lockins[b]
		if not is_equal_approx(float(la.value), float(lb.value)):
			return float(la.value) > float(lb.value)
		return float(la.t) > float(lb.t))
	return out


## The acting host: the lowest-numbered player who is here.
static func acting_host(present: Array) -> int:
	var best := 0
	for n in present:
		if best == 0 or int(n) < best:
			best = int(n)
	return best


## Final standings: [[n, points], ...] best first; ties share a place.
static func standings(st: Dictionary) -> Array:
	var out := []
	for k in st.scores:
		out.append([int(k), int(st.scores[k])])
	out.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	return out


static func _bump(st: Dictionary) -> void:
	st.ver = int(st.ver) + 1
