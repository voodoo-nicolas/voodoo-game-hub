extends RefCounted

## Backgammon rules and a computer player. Pure logic, no Nodes.
##
## State: {pts: 24 ints (+ = player 0's checkers, - = player 1's), bar: [p0, p1],
## off: [p0, p1]}. Point index 0 is player 0's 1-point; player 0 moves 23 -> 0,
## player 1 moves 0 -> 23. Most helpers work in "relative" positions: rel 0..23
## counted from the mover's own 1-point (their home board is rel 0..5), rel 24
## = the bar, and a move to rel < 0 bears off.

const BAR := 24

var state: Dictionary = {}

func new_game() -> void:
	var pts: Array = []
	pts.resize(24)
	pts.fill(0)
	for spec in [[23, 2], [12, 5], [7, 3], [5, 5]]:
		pts[spec[0]] = spec[1]
		pts[23 - spec[0]] = -spec[1]
	state = {"pts": pts, "bar": [0, 0], "off": [0, 0]}

static func idx(p: int, rel: int) -> int:
	return rel if p == 0 else 23 - rel

static func sgn(p: int) -> int:
	return 1 if p == 0 else -1

static func own_at(s: Dictionary, p: int, rel: int) -> int:
	return max(0, s.pts[idx(p, rel)] * sgn(p))

static func opp_at(s: Dictionary, p: int, rel: int) -> int:
	return max(0, -s.pts[idx(p, rel)] * sgn(p))

static func can_bear_off(s: Dictionary, p: int) -> bool:
	if s.bar[p] > 0:
		return false
	for rel in range(6, 24):
		if own_at(s, p, rel) > 0:
			return false
	return true

## Relative source positions that can move `d` pips.
static func sources(s: Dictionary, p: int, d: int) -> Array:
	var out: Array = []
	if s.bar[p] > 0:
		if opp_at(s, p, BAR - d) < 2:
			out.append(BAR)
		return out
	var bear := can_bear_off(s, p)
	for r in 24:
		if own_at(s, p, r) == 0:
			continue
		var t := r - d
		if t >= 0:
			if opp_at(s, p, t) < 2:
				out.append(r)
		elif bear:
			if t == -1:
				out.append(r)
			else:
				var higher := false
				for k in range(r + 1, 6):
					if own_at(s, p, k) > 0:
						higher = true
						break
				if not higher:
					out.append(r)
	return out

static func apply(s: Dictionary, p: int, from: int, d: int) -> Dictionary:
	var n := {"pts": s.pts.duplicate(), "bar": s.bar.duplicate(), "off": s.off.duplicate()}
	if from == BAR:
		n.bar[p] -= 1
	else:
		n.pts[idx(p, from)] -= sgn(p)
	var t := from - d
	if t < 0:
		n.off[p] += 1
	else:
		var i := idx(p, t)
		if opp_at(n, p, t) == 1:
			n.pts[i] = 0
			n.bar[1 - p] += 1
		n.pts[i] += sgn(p)
	return n

static func key(s: Dictionary) -> String:
	return str(s.pts) + str(s.bar) + str(s.off)

static func roll_dice() -> Array:
	var a := randi_range(1, 6)
	var b := randi_range(1, 6)
	return [a, a, a, a] if a == b else [a, b]

# ---------- legal moves (maximal dice use) ----------

## Longest number of dice playable from `s` with `dice`.
static func max_playable(s: Dictionary, p: int, dice: Array, memo: Dictionary = {}) -> int:
	var k := key(s) + str(dice)
	if memo.has(k):
		return memo[k]
	var best := 0
	var tried := {}
	for d in dice:
		if tried.has(d):
			continue
		tried[d] = true
		var rest: Array = dice.duplicate()
		rest.erase(d)
		for from in sources(s, p, d):
			best = max(best, 1 + max_playable(apply(s, p, from, d), p, rest, memo))
			if best == dice.size():
				memo[k] = best
				return best
	memo[k] = best
	return best

## Single moves [from, die] the player may make now. Enforces the rules that
## as many dice as possible must be used, and the higher die if only one can.
static func legal_moves(s: Dictionary, p: int, dice: Array, memo: Dictionary = {}) -> Array:
	var total := max_playable(s, p, dice, memo)
	if total == 0:
		return []
	var out: Array = []
	var tried := {}
	for d in dice:
		if tried.has(d):
			continue
		tried[d] = true
		var rest: Array = dice.duplicate()
		rest.erase(d)
		for from in sources(s, p, d):
			if 1 + max_playable(apply(s, p, from, d), p, rest, memo) == total:
				out.append([from, d])
	if total == 1 and dice.size() == 2 and dice[0] != dice[1]:
		var hi: int = max(dice[0], dice[1])
		var with_hi := out.filter(func(m): return m[1] == hi)
		if not with_hi.is_empty():
			out = with_hi
	return out

# ---------- computer player ----------

## Every distinct end position reachable with a legal full turn, with the
## moves that reach it: [{state, moves}].
static func turn_outcomes(s: Dictionary, p: int, dice: Array) -> Array:
	var ends: Array = []
	_collect(s, p, dice, [], ends, {})
	var most := 0
	for e in ends:
		most = max(most, e.moves.size())
	var out := {}
	var hi: int = max(dice[0], dice[1])
	var only_one_distinct: bool = most == 1 and dice.size() == 2 and dice[0] != dice[1]
	var hi_possible := false
	if only_one_distinct:
		for e in ends:
			if e.moves.size() == 1 and e.moves[0][1] == hi:
				hi_possible = true
	for e in ends:
		if e.moves.size() != most:
			continue
		if hi_possible and e.moves[0][1] != hi:
			continue
		var k := key(e.state)
		if not out.has(k):
			out[k] = e
	return out.values()

## Plays every ordering of the dice (skipping positions already explored).
static func _collect(s: Dictionary, p: int, dice: Array, path: Array, ends: Array, seen: Dictionary) -> void:
	var k := key(s) + str(dice)
	if seen.has(k):
		return
	seen[k] = true
	var any := false
	var tried := {}
	for d in dice:
		if tried.has(d):
			continue
		tried[d] = true
		var rest: Array = dice.duplicate()
		rest.erase(d)
		for from in sources(s, p, d):
			any = true
			_collect(apply(s, p, from, d), p, rest, path + [[from, d]], ends, seen)
	if not any:
		ends.append({"state": s, "moves": path})

static func best_turn(s: Dictionary, p: int, dice: Array) -> Array:
	var best: Array = []
	var best_score := -INF
	for o in turn_outcomes(s, p, dice):
		var sc := evaluate(o.state, p) + randf() * 0.05
		if sc > best_score:
			best_score = sc
			best = o.moves
	return best

static func pips(s: Dictionary, p: int) -> int:
	var total: int = s.bar[p] * 25
	for rel in 24:
		total += own_at(s, p, rel) * (rel + 1)
	return total

static func evaluate(s: Dictionary, p: int) -> float:
	var o := 1 - p
	var score := float(pips(s, o) - pips(s, p))
	# Opponent's rearmost checker, in my relative terms (they move up my rels).
	var opp_back := 24 if s.bar[o] > 0 else -1
	if opp_back < 0:
		for rel in 24:
			if opp_at(s, p, rel) > 0:
				opp_back = rel
				break
	var my_back := 24 if s.bar[p] > 0 else -1
	if my_back < 0:
		for rel in range(23, -1, -1):
			if own_at(s, p, rel) > 0:
				my_back = rel
				break
	var contact: bool = opp_back >= 0 and my_back > opp_back or s.bar[o] > 0 or s.bar[p] > 0
	if not contact:
		return score + 2.0 * s.off[p]
	for rel in 24:
		var n := own_at(s, p, rel)
		if n == 1 and _exposed(s, p, rel):
			score -= 3.0 + (4.0 if rel < 6 else 0.0)
		elif n >= 2:
			score += 3.0 if rel < 6 else (2.0 if rel < 8 else 0.8)
	score += 6.0 * s.bar[o]
	score -= 6.0 * s.bar[p]
	return score

## Can any opposing checker (or one entering from the bar) reach `rel`?
static func _exposed(s: Dictionary, p: int, rel: int) -> bool:
	if s.bar[1 - p] > 0 and rel >= 12:
		return true
	for k in range(max(0, rel - 12), rel):
		if opp_at(s, p, k) > 0:
			return true
	return false

static func winner(s: Dictionary) -> int:
	for p in 2:
		if s.off[p] == 15:
			return p
	return -1

## 1 = single, 2 = gammon (loser bore off nothing), 3 = backgammon.
static func win_kind(s: Dictionary, p: int) -> int:
	var o := 1 - p
	if s.off[o] > 0:
		return 1
	if s.bar[o] > 0:
		return 3
	for rel in range(18, 24):   # loser still in the winner's home board
		if own_at(s, o, rel) > 0:
			return 3
	return 2
