extends RefCounted

## Truco argentino for two (seat 0 = you, seat 1 = the computer), Spanish deck, to 15 points.
## Three cards each, best of three tricks. Calls: Envido / Real envido / Falta envido (first trick
## only), Truco / Retruco / Vale cuatro, and "al mazo" (fold). No flor. Pure logic, no Nodes.

const Cards = preload("res://scripts/games/truco/truco_cards.gd")

var target: int = 15
var score: Array = [0, 0]
var hands: Array = [[], []]      # cards still in hand
var dealt: Array = [[], []]      # the three cards dealt (envido counts these)
var played: Array = [[], []]     # cards played this round, in order
var tricks: Array = []           # winner of each finished trick: 0, 1, or -1 (parda / tie)
var mano: int = 0                # who leads the first trick this round
var turn: int = 0
var winner: int = -1             # game winner
var round_winner: int = -1       # set when a round ends, until new_round()
var round_points: int = 0
var level: int = 0               # accepted truco level: 0 none, 1 truco, 2 retruco, 3 vale cuatro
var truco_owner: int = -1        # who may raise next (-1 = anyone)
var pending: Dictionary = {}     # {} | {"kind":"truco","by":p,"level":n} | {"kind":"envido","by":p,"calls":[..]}
var envido_done: bool = false
var envido_result: Dictionary = {}   # {"winner","points","vals":[a,b],"rejected"} of this round
var events: Array = []           # what just happened, for the UI to show

const ENVIDO_VALUE := {"envido": 2, "real": 3}

# ---------- cards ----------

## Strength in a trick (higher wins). Order: 1 espadas, 1 bastos, 7 espadas, 7 oros, 3s, 2s,
## 1 copas / 1 oros, 12s, 11s, 10s, 7 copas / 7 bastos, 6s, 5s, 4s.
static func power(card: int) -> int:
	var s := Cards.suit(card)
	var n := Cards.number(card)
	match n:
		1: return 14 if s == 2 else (13 if s == 3 else 8)
		7: return 12 if s == 2 else (11 if s == 0 else 4)
		3: return 10
		2: return 9
		12: return 7
		11: return 6
		10: return 5
		6: return 3
		5: return 2
	return 1

static func env_val(card: int) -> int:
	var n := Cards.number(card)
	return n if n <= 7 else 0

## Envido points of a hand: 20 + the two cards of one suit, else the best single card.
static func envido_points(hand: Array) -> int:
	var best := 0
	for i in hand.size():
		for j in range(i + 1, hand.size()):
			if Cards.suit(hand[i]) == Cards.suit(hand[j]):
				best = maxi(best, 20 + env_val(hand[i]) + env_val(hand[j]))
	if best == 0:
		for c in hand:
			best = maxi(best, env_val(c))
	return best

# ---------- rounds ----------

func new_game(first_mano: int = -1) -> void:
	score = [0, 0]
	winner = -1
	mano = randi() % 2 if first_mano < 0 else first_mano
	_deal()

func new_round() -> void:
	if winner != -1:
		return
	mano = 1 - mano
	_deal()

func _deal() -> void:
	var d := Cards.new_deck()
	hands = [d.slice(0, 3), d.slice(3, 6)]
	dealt = [hands[0].duplicate(), hands[1].duplicate()]
	played = [[], []]
	tricks = []
	turn = mano
	round_winner = -1
	round_points = 0
	level = 0
	truco_owner = -1
	pending = {}
	envido_done = false
	envido_result = {}
	events = []

func stake() -> int:
	return level + 1

func round_on() -> bool:
	return winner == -1 and round_winner == -1

func can_play(p: int, card: int) -> bool:
	return round_on() and pending.is_empty() and turn == p and hands[p].has(card)

func play(p: int, card: int) -> bool:
	if not can_play(p, card):
		return false
	events = []
	hands[p].erase(card)
	played[p].append(card)
	if played[1 - p].size() < played[p].size():
		turn = 1 - p
		return true
	var t: int = played[0].size() - 1
	var a: int = power(played[0][t])
	var b: int = power(played[1][t])
	var w: int = -1 if a == b else (0 if a > b else 1)
	tricks.append(w)
	events.append("trick:" + str(w))
	var r: int = _decide()
	if r >= 0:
		_end_round(r, stake())
	else:
		turn = w if w != -1 else mano
	return true

## -2 = the round goes on, otherwise the round winner.
func _decide() -> int:
	var n := tricks.size()
	var w0 := tricks.count(0)
	var w1 := tricks.count(1)
	if n >= 2:
		if w0 >= 2:
			return 0
		if w1 >= 2:
			return 1
		if tricks[0] == -1 and tricks[1] != -1:
			return tricks[1]
		if tricks[0] != -1 and tricks[1] == -1:
			return tricks[0]
	if n == 3:
		if tricks[2] != -1:
			return tricks[2]
		return tricks[0] if tricks[0] != -1 else mano
	return -2

func _end_round(w: int, pts: int) -> void:
	round_winner = w
	round_points = pts
	pending = {}
	_award(w, pts)

func _award(w: int, pts: int) -> void:
	score[w] = mini(target, score[w] + pts)
	if score[w] >= target:
		winner = w

## Fold ("al mazo"): the other player takes the stake.
func fold(p: int) -> bool:
	if not round_on() or not pending.is_empty() or turn != p:
		return false
	_end_round(1 - p, stake())
	events = ["fold:" + str(p)]
	return true

# ---------- envido ----------

func _envido_allowed(calls: Array, kind: String) -> bool:
	if calls.is_empty():
		return true
	var last: String = calls.back()
	match kind:
		"envido": return last == "envido" and calls.count("envido") < 2
		"real": return last == "envido"
		"falta": return last == "envido" or last == "real"
	return false

func can_call_envido(p: int, kind: String) -> bool:
	if not round_on() or envido_done or level != 0 or not tricks.is_empty():
		return false
	if pending.is_empty():
		return turn == p and _envido_allowed([], kind)
	return pending.kind == "envido" and pending.by != p and _envido_allowed(pending.calls, kind)

func call_envido(p: int, kind: String) -> bool:
	if not can_call_envido(p, kind):
		return false
	var calls: Array = pending.calls.duplicate() if not pending.is_empty() else []
	calls.append(kind)
	pending = {"kind": "envido", "by": p, "calls": calls}
	events = ["envido:" + str(p) + ":" + kind]
	return true

func _envido_stake(calls: Array) -> int:
	if calls.has("falta"):
		return maxi(1, target - maxi(score[0], score[1]))
	var s := 0
	for c in calls:
		s += int(ENVIDO_VALUE[c])
	return s

## Answer a pending envido: accept (quiero) or refuse (no quiero).
func answer_envido(p: int, accept: bool) -> bool:
	if pending.is_empty() or pending.kind != "envido" or pending.by == p:
		return false
	var calls: Array = pending.calls
	var caller: int = pending.by
	envido_done = true
	pending = {}
	if accept:
		var v0 := envido_points(dealt[0])
		var v1 := envido_points(dealt[1])
		var w: int = mano if v0 == v1 else (0 if v0 > v1 else 1)
		var pts := _envido_stake(calls)
		envido_result = {"winner": w, "points": pts, "vals": [v0, v1], "rejected": false}
		_award(w, pts)
	else:
		var prior: Array = calls.slice(0, calls.size() - 1)
		var pts := maxi(1, _envido_stake(prior))
		envido_result = {"winner": caller, "points": pts, "vals": [], "rejected": true}
		_award(caller, pts)
	events = ["envido_done"]
	return true

# ---------- truco ----------

func can_call_truco(p: int) -> bool:
	if not round_on() or level >= 3:
		return false
	if pending.is_empty():
		return turn == p and (truco_owner == -1 or truco_owner == p)
	return pending.kind == "truco" and pending.by != p and pending.level < 3

func call_truco(p: int) -> bool:
	if not can_call_truco(p):
		return false
	if not pending.is_empty():
		level = pending.level       # answering by raising accepts the call before it
		truco_owner = p
	pending = {"kind": "truco", "by": p, "level": level + 1}
	events = ["truco:" + str(p) + ":" + str(level + 1)]
	return true

func answer_truco(p: int, accept: bool) -> bool:
	if pending.is_empty() or pending.kind != "truco" or pending.by == p:
		return false
	if accept:
		level = pending.level
		truco_owner = p
		pending = {}
		events = ["truco_accepted"]
	else:
		var caller: int = pending.by
		_end_round(caller, stake())   # the stake before the refused call
		events = ["truco_refused:" + str(p)]
	return true

# ---------- save ----------

func to_dict() -> Dictionary:
	return {"target": target, "score": score, "hands": hands, "dealt": dealt, "played": played, "tricks": tricks,
		"mano": mano, "turn": turn, "level": level, "owner": truco_owner, "envido_done": envido_done}

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func from_dict(d: Dictionary) -> void:
	target = int(d.get("target", 15))
	score = _ints(d.score)
	hands = [_ints(d.hands[0]), _ints(d.hands[1])]
	dealt = [_ints(d.dealt[0]), _ints(d.dealt[1])]
	played = [_ints(d.played[0]), _ints(d.played[1])]
	tricks = _ints(d.tricks)
	mano = int(d.mano)
	turn = int(d.turn)
	level = int(d.level)
	truco_owner = int(d.owner)
	envido_done = bool(d.envido_done)
	pending = {}
	winner = -1
	round_winner = -1
	events = []

# ---------- the computer ----------

## 0..1 guess of how strong p's dealt cards are for the tricks.
func strength(p: int) -> float:
	var ps: Array = []
	for c in dealt[p]:
		ps.append(power(c))
	ps.sort()
	ps.reverse()
	return (ps[0] * 0.5 + ps[1] * 0.35 + ps[2] * 0.15) / 14.0

## What seat p does now: {"do": "play"|"envido"|"truco"|"yes"|"no", "card", "kind"}.
## skill 0 easy, 1 normal, 2 hard.
func cpu_action(p: int, skill: int = 1) -> Dictionary:
	var rnd := randf()
	var st := strength(p)
	if not pending.is_empty():
		if pending.kind == "envido":
			var e := envido_points(dealt[p])
			var need: int = 23 + pending.calls.size() * 2 - skill
			if e >= 31 and can_call_envido(p, "real"):
				return {"do": "envido", "kind": "real"}
			if e >= 33 and can_call_envido(p, "falta"):
				return {"do": "envido", "kind": "falta"}
			if e >= need or rnd < 0.08:
				return {"do": "yes"}
			return {"do": "no"}
		var lv: int = pending.level
		var th := 0.45 + 0.1 * lv - 0.03 * skill
		if st >= 0.85 and lv < 3 and rnd < 0.6:
			return {"do": "truco"}
		if st >= th or rnd < 0.07:
			return {"do": "yes"}
		return {"do": "no"}
	if tricks.is_empty() and not envido_done and level == 0 and played[p].is_empty():
		var e2 := envido_points(dealt[p])
		if e2 >= 27 and rnd < 0.8:
			return {"do": "envido", "kind": "real" if e2 >= 31 and rnd < 0.4 else "envido"}
		if e2 >= 24 and rnd < 0.4:
			return {"do": "envido", "kind": "envido"}
		if skill >= 1 and e2 < 20 and rnd < 0.06:
			return {"do": "envido", "kind": "envido"}
	if can_call_truco(p):
		var cur := clampf(st + 0.2 * tricks.count(p) - 0.2 * tricks.count(1 - p), 0.0, 1.0)
		if cur >= 0.72 and randf() < 0.45:
			return {"do": "truco"}
		if skill >= 1 and cur < 0.4 and randf() < 0.05:
			return {"do": "truco"}
	return {"do": "play", "card": pick_card(p)}

func pick_card(p: int) -> int:
	var hand: Array = hands[p].duplicate()
	hand.sort_custom(func(a, b): return power(a) < power(b))
	var q := 1 - p
	if played[q].size() > played[p].size():
		var theirs := power(played[q].back())
		for c in hand:               # the lowest card that wins
			if power(c) > theirs:
				return c
		return hand[0]              # cannot win: throw the lowest
	if tricks.is_empty():
		return hand.back() if strength(p) > 0.7 or hand.size() == 1 else hand[hand.size() / 2]
	return hand.back()
