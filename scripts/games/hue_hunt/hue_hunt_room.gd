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
##   vote_order, vote_i, votes {"n": {"voter": yes}}, best {"voter": n},
##   vote_end, best_end      Object rounds: the players' vote (hue_hunt_judge.gd)
##   powers, granted, used, active, peeks   power-ups (hue_hunt_powerups.gd)
## Thumbnails never go in the state: they travel once as their own event and
## are dropped after the reveal.

const E = preload("res://scripts/games/hue_hunt/hue_hunt_engine.gd")
const P = preload("res://scripts/games/hue_hunt/hue_hunt_powerups.gd")
const Judge = preload("res://scripts/games/hue_hunt/hue_hunt_judge.gd")

const REVEAL_TIME := 25.0
const VOTE_TIME := 10.0     # per photo: is this a teacup?
const BEST_TIME := 15.0     # the best-find vote
const DEFAULTS := {"rounds": 10, "selection": "classic", "place": "local", "difficulty": "normal", "powerups": true, "objects": true}


static func new_match(settings: Dictionary, seats: Array, seed_v: int, now: float) -> Dictionary:
	var s := DEFAULTS.duplicate()
	s.merge(settings, true)
	var plan := E.plan_match({"seed": seed_v, "rounds": int(s.rounds), "selection": s.selection,
		"solo": false, "objects": E.object_ids() if s.objects else [], "place": s.place})
	var scores := {}
	for n in seats:
		scores[str(n)] = 0
	var st := {"ver": 0, "match_id": seed_v, "phase": "round", "settings": s, "plan": plan, "round_i": 0, "seats": seats.duplicate(),
		"scores": scores, "lockins": {}, "flags": {}, "awards": [], "first_close_t": -1.0,
		"started": now, "deadline": 0.0, "reveal_end": 0.0, "now": now,
		"powers": {}, "granted": {}, "used": {}, "active": {}, "peeks": {},
		"vote_order": [], "vote_i": 0, "votes": {}, "best": {}, "vote_end": 0.0, "best_end": 0.0}
	st.deadline = E.round_deadline(plan[0], now, -1.0)
	if s.powerups:
		for n in seats:
			for i in P.START_WITH:
				_grant(st, int(n))
	return st


# ---------- power-ups (hue_hunt_powerups.gd) ----------

static func _grant(st: Dictionary, n: int) -> bool:
	var key := str(n)
	if int(st.granted.get(key, 0)) >= P.MAX_PER_MATCH:
		return false
	var held: Array = st.powers.get(key, [])
	held.append(P.pick(int(st.match_id), n * 100 + int(st.granted.get(key, 0)) + int(st.round_i) * 7))
	st.powers[key] = held
	st.granted[key] = int(st.granted.get(key, 0)) + 1
	return true


## Catch-up: after each round the player(s) with the fewest points get one
## more, while they are under the match cap (ties all get one; nobody when
## everyone is level).
static func catch_up(st: Dictionary) -> Array:
	if not st.settings.get("powerups", true):
		return []
	var low := 1 << 30
	var high := -1
	for k in st.scores:
		low = mini(low, int(st.scores[k]))
		high = maxi(high, int(st.scores[k]))
	var got := []
	if low == high:
		return got
	for k in st.scores:
		if int(st.scores[k]) == low and _grant(st, int(k)):
			got.append(int(k))
	return got


## Player n uses power-up `id`. Host time `now`. True if it happened.
static func use_power(st: Dictionary, n: int, id: String, now: float) -> bool:
	var key := str(n)
	var held: Array = st.powers.get(key, [])
	if not held.has(id) or not P.can_use(st, n, id, now):
		return false
	match id:
		"hot_cold":
			st.active[key] = {"id": id, "until": now + float(P.POWERS[id].seconds)}
		"peek":
			st.peeks[key] = int(st.round_i)
		"second_chance":
			st.lockins.erase(key)
	held.erase(id)
	st.powers[key] = held
	st.used[key] = int(st.used.get(key, 0)) + 1
	_bump(st)
	return true


## Is power-up `id` running for n at host time `now`?
static func active(st: Dictionary, n: int, id: String, now: float) -> bool:
	var a: Dictionary = st.get("active", {}).get(str(n), {})
	return a.get("id", "") == id and now < float(a.get("until", 0.0))


static func peeked(st: Dictionary, n: int) -> bool:
	return int(st.get("peeks", {}).get(str(n), -1)) == int(st.round_i)


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
				st.flags = {}
				if spec(st).judge == "vote" and not st.lockins.is_empty():
					_start_votes(st, now)
				else:
					_to_reveal(st, now)
				_bump(st)
				return true
		"vote":
			var cur := str(st.vote_order[int(st.vote_i)])
			var done := true
			for n in present:
				if str(n) != cur and st.scores.has(str(n)) and not st.votes.get(cur, {}).has(str(n)):
					done = false
			if now >= float(st.vote_end) or done:
				st.vote_i = int(st.vote_i) + 1
				if int(st.vote_i) >= st.vote_order.size():
					_start_best(st, now)
				else:
					st.vote_end = now + VOTE_TIME
				_bump(st)
				return true
		"best":
			var all_best := true
			for n in present:
				if st.scores.has(str(n)) and not st.best.has(str(n)) and _best_choices(st, int(n)).size() > 0:
					all_best = false
			if now >= float(st.best_end) or all_best:
				_to_reveal(st, now)
				_bump(st)
				return true
		"reveal":
			if now >= float(st.reveal_end):
				return end_reveal(st, now)
	return false


static func _to_reveal(st: Dictionary, now: float) -> void:
	st.phase = "reveal"
	st.reveal_end = now + REVEAL_TIME
	st.awards = resolve(st)


# ---------- Object rounds: the players judge (hue_hunt_judge.gd) ----------

## One photo at a time, earliest lock-in first, VOTE_TIME each.
static func _start_votes(st: Dictionary, now: float) -> void:
	var keys: Array = st.lockins.keys()
	keys.sort_custom(func(a, b): return float(st.lockins[a].t) < float(st.lockins[b].t))
	st.phase = "vote"
	st.vote_order = keys
	st.vote_i = 0
	st.votes = {}
	st.best = {}
	st.vote_end = now + VOTE_TIME


static func _start_best(st: Dictionary, now: float) -> void:
	st.phase = "best"
	st.best_end = now + BEST_TIME
	var anyone := false
	for k in st.scores:
		if _best_choices(st, int(k)).size() > 0:
			anyone = true
	if not anyone:
		_to_reveal(st, now)


## The photo being voted on now ("" when not voting).
static func voting_on(st: Dictionary) -> String:
	if st.phase != "vote":
		return ""
	return str(st.vote_order[int(st.vote_i)])


## "Is this a teacup?" -- yes / no on the current photo; not on your own.
static func vote(st: Dictionary, voter: int, target: int, yes: bool) -> bool:
	var key := str(target)
	if voting_on(st) != key or voter == target or not st.scores.has(str(voter)):
		return false
	var v: Dictionary = st.votes.get(key, {})
	if v.has(str(voter)):
		return false
	v[str(voter)] = yes
	st.votes[key] = v
	_bump(st)
	return true


static func valid(st: Dictionary, key: String) -> bool:
	return bool(Judge.judge(str(spec(st).prompt), null, st.get("votes", {}).get(key, {})).valid) and not flagged(st, int(key))


## Photos n may pick as the best find: valid ones, not n's own.
static func _best_choices(st: Dictionary, n: int) -> Array:
	var out := []
	for k in st.lockins:
		if str(k) != str(n) and valid(st, str(k)):
			out.append(str(k))
	return out


static func best_vote(st: Dictionary, voter: int, target: int) -> bool:
	if st.phase != "best" or st.best.has(str(voter)) or not _best_choices(st, voter).has(str(target)):
		return false
	st.best[str(voter)] = target
	_bump(st)
	return true


## The awards for the current round, given the flags (and votes) so far.
static func resolve(st: Dictionary) -> Array:
	var voters: int = maxi(0, st.seats.size() - 1)
	var list := []
	var best_count := {}
	for v in st.get("best", {}).values():
		best_count[str(int(v))] = int(best_count.get(str(int(v)), 0)) + 1
	for key in st.lockins:
		var e: Dictionary = st.lockins[key].duplicate()
		e.player = key
		e.flagged = E.flag_majority(st.flags.get(key, []).size(), voters)
		if spec(st).judge == "vote":
			var j := Judge.judge(str(spec(st).prompt), null, st.get("votes", {}).get(key, {}))
			e.yes = j.yes
			e.no = j.no
			e.best_votes = int(best_count.get(str(key), 0))
		list.append(e)
	return E.resolve(spec(st), list).awards


## A vote to flag n's photo (people, something rude, a fake). Voters can't
## flag themselves or vote twice. Awards are worked out again at once.
static func flag(st: Dictionary, voter: int, target: int) -> bool:
	var key := str(target)
	if st.phase not in ["reveal", "vote", "best"] or voter == target or not st.lockins.has(key) or not st.scores.has(str(voter)):
		return false
	var votes: Array = st.flags.get(key, [])
	for v in votes:
		if int(v) == voter:   # JSON makes ints floats
			return false
	votes.append(voter)
	st.flags[key] = votes
	if st.phase == "reveal":
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
	st.active = {}
	if int(st.round_i) + 1 >= st.plan.size():
		st.phase = "final"
	else:
		st.round_i = int(st.round_i) + 1
		st.phase = "round"
		st.lockins = {}
		st.flags = {}
		st.votes = {}
		st.best = {}
		st.vote_order = []
		st.vote_i = 0
		st.first_close_t = -1.0
		st.started = now
		st.deadline = E.round_deadline(spec(st), now, -1.0)
		catch_up(st)
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
