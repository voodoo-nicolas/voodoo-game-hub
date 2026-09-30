extends RefCounted

## Gin Rummy, you (0) vs the computer (1). Each turn: draw (stock or the top
## discard), then discard. Melds are sets (3-4 of a rank) and runs (3+ in a
## suit, ace low). Knock when your unmatched "deadwood" is 10 or less; gin
## is zero deadwood. The defender may lay deadwood off on the knocker's
## melds. First to 100 points wins the match. Pure logic, no Nodes.

const TARGET := 100
const GIN_BONUS := 25
const UNDERCUT_BONUS := 25

var hands: Array = [[], []]
var stock: Array = []
var discard: Array = []
var turn: int = 0
var phase: String = "draw"     # "draw", "discard", "over"
var taken_discard: int = -1    # a card just taken from the discard can't go straight back
var scores: Array = [0, 0]
var starter: int = 0
var result: Dictionary = {}

static func rank(card: int) -> int:
	return card % 13 + 1

static func suit(card: int) -> int:
	return card / 13

static func value(card: int) -> int:
	return min(10, rank(card))

func new_match() -> void:
	scores = [0, 0]
	starter = 0
	new_hand()

func new_hand() -> void:
	var deck: Array = []
	for c in 52:
		deck.append(c)
	deck.shuffle()
	hands = [deck.slice(0, 10), deck.slice(10, 20)]
	discard = [deck[20]]
	stock = deck.slice(21)
	turn = starter
	phase = "draw"
	taken_discard = -1
	result = {}

func match_over() -> bool:
	return scores[0] >= TARGET or scores[1] >= TARGET

# ---------- melds ----------

## Every possible meld in `cards` (as Arrays of cards).
static func candidate_melds(cards: Array) -> Array:
	var out: Array = []
	var by_rank := {}
	for c in cards:
		by_rank[rank(c)] = by_rank.get(rank(c), []) + [c]
	for r in by_rank:
		var g: Array = by_rank[r]
		if g.size() >= 3:
			if g.size() == 4:
				out.append(g.duplicate())
				for skip in 4:
					var three: Array = g.duplicate()
					three.remove_at(skip)
					out.append(three)
			else:
				out.append(g.duplicate())
	for s in 4:
		var ranks := {}
		for c in cards:
			if suit(c) == s:
				ranks[rank(c)] = c
		for start in range(1, 12):
			var run: Array = []
			var r := start
			while ranks.has(r):
				run.append(ranks[r])
				if run.size() >= 3:
					out.append(run.duplicate())
				r += 1
	return out

## {melds: Array, deadwood: Array, points: int} with the least deadwood.
static func best_melds(cards: Array) -> Dictionary:
	var cands := candidate_melds(cards)
	var best := {"melds": [], "points": 1 << 30}
	_search(cards, cands, 0, [], {}, best)
	var used := {}
	for m in best.melds:
		for c in m:
			used[c] = true
	var dead: Array = cards.filter(func(c): return not used.has(c))
	var pts := 0
	for c in dead:
		pts += value(c)
	return {"melds": best.melds, "deadwood": dead, "points": pts}

static func _search(cards: Array, cands: Array, i: int, chosen: Array, used: Dictionary, best: Dictionary) -> void:
	if i == cands.size():
		var pts := 0
		for c in cards:
			if not used.has(c):
				pts += value(c)
		if pts < best.points:
			best.points = pts
			best.melds = chosen.duplicate()
		return
	var m: Array = cands[i]
	var free := true
	for c in m:
		if used.has(c):
			free = false
			break
	if free:
		for c in m:
			used[c] = true
		chosen.append(m)
		_search(cards, cands, i + 1, chosen, used, best)
		chosen.pop_back()
		for c in m:
			used.erase(c)
	_search(cards, cands, i + 1, chosen, used, best)

static func deadwood(cards: Array) -> int:
	return best_melds(cards).points

# ---------- turn actions ----------

func draw_stock() -> int:
	if phase != "draw" or stock.is_empty():
		return -1
	var c: int = stock.pop_back()
	hands[turn].append(c)
	taken_discard = -1
	phase = "discard"
	return c

func draw_discard() -> int:
	if phase != "draw" or discard.is_empty():
		return -1
	var c: int = discard.pop_back()
	hands[turn].append(c)
	taken_discard = c
	phase = "discard"
	return c

func can_discard(card: int) -> bool:
	return phase == "discard" and hands[turn].has(card) and card != taken_discard

## Deadwood left after discarding `card` (for the knock button).
func deadwood_after(card: int) -> int:
	var rest: Array = hands[turn].duplicate()
	rest.erase(card)
	return deadwood(rest)

## Discards; with knock=true also ends the hand (needs deadwood <= 10).
func do_discard(card: int, knock: bool = false) -> bool:
	if not can_discard(card):
		return false
	if knock and deadwood_after(card) > 10:
		return false
	hands[turn].erase(card)
	discard.append(card)
	if knock:
		_score_hand(turn)
		return true
	# two cards left in the stock: nobody wins this hand
	if stock.size() <= 2:
		result = {"draw": true}
		phase = "over"
		starter = 1 - starter
		return true
	turn = 1 - turn
	phase = "draw"
	return true

func _score_hand(knocker: int) -> void:
	var defender := 1 - knocker
	var k := best_melds(hands[knocker])
	var d := best_melds(hands[defender])
	var gin: bool = k.points == 0
	var laid: Array = []
	var d_dead: Array = d.deadwood.duplicate()
	if not gin:
		var melds: Array = []
		for m in k.melds:
			melds.append(m.duplicate())
		var changed := true
		while changed:
			changed = false
			for c in d_dead.duplicate():
				for m in melds:
					if _fits(m, c):
						m.append(c)
						d_dead.erase(c)
						laid.append(c)
						changed = true
						break
	var d_points := 0
	for c in d_dead:
		d_points += value(c)
	var winner: int
	var points: int
	var kind: String
	if gin:
		winner = knocker
		points = GIN_BONUS + d_points
		kind = "gin"
	elif k.points < d_points:
		winner = knocker
		points = d_points - k.points
		kind = "knock"
	else:
		winner = defender
		points = k.points - d_points + UNDERCUT_BONUS
		kind = "undercut"
	scores[winner] += points
	result = {"draw": false, "knocker": knocker, "winner": winner, "points": points, "kind": kind,
		"knocker_deadwood": k.points, "defender_deadwood": d_points, "laid_off": laid}
	phase = "over"
	starter = winner

static func _fits(meld: Array, c: int) -> bool:
	var is_set := true
	for m in meld:
		if rank(m) != rank(meld[0]):
			is_set = false
	if is_set:
		return rank(c) == rank(meld[0]) and meld.size() < 4
	if suit(c) != suit(meld[0]):
		return false
	var lo := 14
	var hi := 0
	for m in meld:
		lo = min(lo, rank(m))
		hi = max(hi, rank(m))
	return rank(c) == lo - 1 or rank(c) == hi + 1

# ---------- computer player ----------

func cpu_wants_discard() -> bool:
	if discard.is_empty():
		return false
	var hand: Array = hands[1]
	var top: int = discard.back()
	var now := deadwood(hand)
	var with_top: Array = hand + [top]
	var best := 1 << 30
	for c in hand:
		var rest: Array = with_top.duplicate()
		rest.erase(c)
		best = min(best, deadwood(rest))
	return best < now - 1

## [card, knock]
func cpu_discard() -> Array:
	var hand: Array = hands[1]
	var best_card: int = -1
	var best_dw := 1 << 30
	for c in hand:
		if c == taken_discard:
			continue
		var dw := deadwood_after(c)
		if dw < best_dw or (dw == best_dw and value(c) > value(best_card)):
			best_dw = dw
			best_card = c
	var knock: bool = best_dw == 0 or best_dw <= 6 or (best_dw <= 10 and stock.size() < 14)
	return [best_card, knock]
