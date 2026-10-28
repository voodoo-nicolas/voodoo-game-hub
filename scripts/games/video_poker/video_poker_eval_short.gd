extends RefCounted

## Hand scores for Short Deck (6+) Hold'em: a 36-card deck without the 2s to 5s.
## The usual rules of the Triton game: a Flush beats a Full House and Three of a
## Kind beats a Straight (the rarer hand wins), and the Ace plays low in the
## straight A-6-7-8-9. Scores have the layout of video_poker_eval.gd (a bigger
## number wins) but the category number is the hand's ORDER here, not its type:
## `type_of(score)` gives the usual category (Eval.PAIR, Eval.FLUSH...) for names
## and statistics.

const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")

## Order -> usual category: high card, pair, two pair, STRAIGHT, TRIPS, FULL HOUSE, FLUSH, quads, straight flush.
const TYPE_OF_ORDER := [0, 1, 2, 4, 3, 6, 5, 7, 8]
const ORDER_OF_TYPE := [0, 1, 2, 4, 3, 6, 5, 7, 8]  # the same swaps, both ways

static func type_of(score: int) -> int:
	return TYPE_OF_ORDER[clampi(score >> 20, 0, 8)]

static func _straight_top(mask: int) -> int:
	if mask & (1 << 14):
		mask |= 1 << 5  # the Ace is a 5 here: A-6-7-8-9
	var top := 14
	while top >= 9:
		if (mask >> (top - 4)) & 31 == 31:
			return top
		top -= 1
	return 0

static func score(cards: Array) -> int:
	var counts := PackedInt32Array()
	counts.resize(15)
	var smask := PackedInt32Array([0, 0, 0, 0])
	var scount := PackedInt32Array([0, 0, 0, 0])
	var mask := 0
	for c in cards:
		var r: int = c % 13
		var v: int = 14 if r == 0 else r + 1
		var s: int = c / 13
		counts[v] += 1
		smask[s] |= 1 << v
		scount[s] += 1
		mask |= 1 << v
	for s in 4:
		if scount[s] >= 5:
			var sf := _straight_top(smask[s])
			if sf > 0:
				return (ORDER_OF_TYPE[Eval.STRAIGHT_FLUSH] << 20) | (sf << 16)
			var out: int = ORDER_OF_TYPE[Eval.FLUSH] << 20
			var shift := 16
			var v := 14
			while shift >= 0:
				if smask[s] & (1 << v):
					out |= v << shift
					shift -= 4
				v -= 1
			return out
	var quad := 0
	var trips: Array = []
	var pairs: Array = []
	var singles: Array = []
	var v := 14
	while v >= 2:
		match counts[v]:
			4: quad = v
			3: trips.append(v)
			2: pairs.append(v)
			1: singles.append(v)
		v -= 1
	if quad > 0:
		var k := 0
		for arr in [trips, pairs, singles]:
			if not arr.is_empty():
				k = maxi(k, arr[0])
		return (ORDER_OF_TYPE[Eval.QUADS] << 20) | (quad << 16) | (k << 12)
	if not trips.is_empty() and (trips.size() >= 2 or not pairs.is_empty()):
		var p := 0
		if trips.size() >= 2:
			p = trips[1]
		if not pairs.is_empty():
			p = maxi(p, pairs[0])
		return (ORDER_OF_TYPE[Eval.FULL_HOUSE] << 20) | (trips[0] << 16) | (p << 12)
	if not trips.is_empty():
		# three of a kind beats a straight here
		return (ORDER_OF_TYPE[Eval.TRIPS] << 20) | (trips[0] << 16) | Eval._kickers(singles, 2, 12)
	var st := _straight_top(mask)
	if st > 0:
		return (ORDER_OF_TYPE[Eval.STRAIGHT] << 20) | (st << 16)
	if pairs.size() >= 2:
		var k2 := 0
		if pairs.size() >= 3:
			k2 = pairs[2]
		if not singles.is_empty():
			k2 = maxi(k2, singles[0])
		return (ORDER_OF_TYPE[Eval.TWO_PAIR] << 20) | (pairs[0] << 16) | (pairs[1] << 12) | (k2 << 8)
	if pairs.size() == 1:
		return (ORDER_OF_TYPE[Eval.PAIR] << 20) | (pairs[0] << 16) | Eval._kickers(singles, 3, 12)
	return (ORDER_OF_TYPE[Eval.HIGH_CARD] << 20) | Eval._kickers(singles, 5, 16)

## The best five of `cards` (all of them when fewer).
static func best_five(cards: Array) -> Array:
	if cards.size() <= 5:
		return cards.duplicate()
	var best := -1
	var out: Array = []
	for combo in Eval.combos(cards.size(), 5):
		var five: Array = []
		for i in combo:
			five.append(cards[i])
		var s := score(five)
		if s > best:
			best = s
			out = five
	return out

## A score in words: the usual description of the usual category.
static func describe(s: int) -> String:
	return Eval.describe((type_of(s) << 20) | (s & 0xFFFFF))
