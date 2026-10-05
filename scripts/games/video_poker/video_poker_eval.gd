extends RefCounted

## Poker hand values. A card is an int 0..51: rank = card % 13 (0 = Ace,
## 1 = Two ... 12 = King), suit = card / 13. In here an Ace is worth 14
## (and 1 in the wheel, A-2-3-4-5).
##
## score(cards) rates the best five-card hand inside any 1..7 cards as one
## int: bigger always wins, equal is a split. The category sits in bits
## 20+ (0 high card ... 8 straight flush) and up to five rank values of 4
## bits each below it, most important first.

const HIGH_CARD := 0
const PAIR := 1
const TWO_PAIR := 2
const TRIPS := 3
const STRAIGHT := 4
const FLUSH := 5
const FULL_HOUSE := 6
const QUADS := 7
const STRAIGHT_FLUSH := 8

## Strongest first, as a player learns them. Index 0 is the royal flush
## (a straight flush to the Ace), then categories 8..0.
const RANKINGS := [
	["Royal Flush", "A, K, Q, J, 10, all the same suit."],
	["Straight Flush", "Five in a row, all the same suit."],
	["Four of a Kind", "Four cards of the same rank."],
	["Full House", "Three of a kind plus a pair."],
	["Flush", "Any five cards of the same suit."],
	["Straight", "Five in a row, any suits. The Ace counts high or low."],
	["Three of a Kind", "Three cards of the same rank."],
	["Two Pair", "Two different pairs."],
	["Pair", "Two cards of the same rank."],
	["High Card", "Nothing else: your highest card plays."],
]
## Example hands for RANKINGS, as cards (same order).
const EXAMPLES := [
	[0, 12, 11, 10, 9], [21, 20, 19, 18, 17], [7, 20, 33, 46, 2], [11, 24, 37, 4, 17],
	[27, 35, 30, 33, 36], [8, 20, 45, 5, 4], [6, 19, 32, 12, 2], [10, 23, 4, 30, 39],
	[13, 39, 11, 21, 6], [0, 24, 34, 6, 15],
]

static func value(card: int) -> int:
	var r := card % 13
	return 14 if r == 0 else r + 1

static func category(s: int) -> int:
	return s >> 20

static func is_royal(s: int) -> bool:
	return s >= 0 and category(s) == STRAIGHT_FLUSH and (s >> 16) & 15 == 14

## The highest card of a straight in the rank bit mask (bits 2..14), or 0.
static func _straight_top(mask: int) -> int:
	if mask & (1 << 14):
		mask |= 1 << 1
	var top := 14
	while top >= 5:
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
	# With at most seven cards a flush rules out quads and a full house.
	for s in 4:
		if scount[s] >= 5:
			var sf := _straight_top(smask[s])
			if sf > 0:
				return (STRAIGHT_FLUSH << 20) | (sf << 16)
			var out := FLUSH << 20
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
		return (QUADS << 20) | (quad << 16) | (k << 12)
	if not trips.is_empty() and (trips.size() >= 2 or not pairs.is_empty()):
		var p := 0
		if trips.size() >= 2:
			p = trips[1]
		if not pairs.is_empty():
			p = maxi(p, pairs[0])
		return (FULL_HOUSE << 20) | (trips[0] << 16) | (p << 12)
	var st := _straight_top(mask)
	if st > 0:
		return (STRAIGHT << 20) | (st << 16)
	if not trips.is_empty():
		return (TRIPS << 20) | (trips[0] << 16) | _kickers(singles, 2, 12)
	if pairs.size() >= 2:
		var k2 := 0
		if pairs.size() >= 3:
			k2 = pairs[2]
		if not singles.is_empty():
			k2 = maxi(k2, singles[0])
		return (TWO_PAIR << 20) | (pairs[0] << 16) | (pairs[1] << 12) | (k2 << 8)
	if pairs.size() == 1:
		return (PAIR << 20) | (pairs[0] << 16) | _kickers(singles, 3, 12)
	return (HIGH_CARD << 20) | _kickers(singles, 5, 16)

static func _kickers(vals: Array, n: int, shift: int) -> int:
	var out := 0
	for i in mini(n, vals.size()):
		out |= vals[i] << (shift - 4 * i)
	return out

## score() for exactly five cards, several times faster (Omaha rates 60
## five-card hands per player, so this is what the computer's thinking
## spends its time on there).
static func score5(c0: int, c1: int, c2: int, c3: int, c4: int) -> int:
	var v := [value(c0), value(c1), value(c2), value(c3), value(c4)]
	v.sort()
	var a: int = v[0]
	var b: int = v[1]
	var c: int = v[2]
	var d: int = v[3]
	var e: int = v[4]
	var flush: bool = c0 / 13 == c1 / 13 and c1 / 13 == c2 / 13 and c2 / 13 == c3 / 13 and c3 / 13 == c4 / 13
	if a != b and b != c and c != d and d != e:
		var top := 0
		if e - a == 4:
			top = e
		elif e == 14 and d == 5:
			top = 5
		if top > 0:
			return ((STRAIGHT_FLUSH if flush else STRAIGHT) << 20) | (top << 16)
		if flush:
			return (FLUSH << 20) | (e << 16) | (d << 12) | (c << 8) | (b << 4) | a
		return (e << 16) | (d << 12) | (c << 8) | (b << 4) | a
	var ab := a == b
	var bc := b == c
	var cd := c == d
	var de := d == e
	if ab and bc and cd:
		return (QUADS << 20) | (a << 16) | (e << 12)
	if bc and cd and de:
		return (QUADS << 20) | (e << 16) | (a << 12)
	if ab and bc and de:
		return (FULL_HOUSE << 20) | (a << 16) | (e << 12)
	if ab and cd and de:
		return (FULL_HOUSE << 20) | (e << 16) | (a << 12)
	if ab and bc:
		return (TRIPS << 20) | (a << 16) | (e << 12) | (d << 8)
	if bc and cd:
		return (TRIPS << 20) | (b << 16) | (e << 12) | (a << 8)
	if cd and de:
		return (TRIPS << 20) | (c << 16) | (b << 12) | (a << 8)
	if ab and cd:
		return (TWO_PAIR << 20) | (c << 16) | (a << 12) | (e << 8)
	if ab and de:
		return (TWO_PAIR << 20) | (e << 16) | (a << 12) | (c << 8)
	if bc and de:
		return (TWO_PAIR << 20) | (e << 16) | (b << 12) | (a << 8)
	if ab:
		return (PAIR << 20) | (a << 16) | (e << 12) | (d << 8) | (c << 4)
	if bc:
		return (PAIR << 20) | (b << 16) | (e << 12) | (d << 8) | (a << 4)
	if cd:
		return (PAIR << 20) | (c << 16) | (e << 12) | (b << 8) | (a << 4)
	return (PAIR << 20) | (d << 16) | (c << 12) | (b << 8) | (a << 4)

## Omaha: exactly two of the four hole cards and three from the board.
static func score_omaha(hole: Array, board: Array) -> int:
	var best := -1
	var nb := board.size()
	for i in hole.size():
		for j in range(i + 1, hole.size()):
			var h1: int = hole[i]
			var h2: int = hole[j]
			for x in nb:
				for y in range(x + 1, nb):
					for z in range(y + 1, nb):
						var s := score5(h1, h2, board[x], board[y], board[z])
						if s > best:
							best = s
	return best

## The five cards that make the best hand inside `cards` (5..7 cards);
## `omaha_hole` set means Omaha rules (two of these plus three of `cards`).
static func best_five(cards: Array, omaha_hole: Array = []) -> Array:
	var best := -1
	var best_hand: Array = []
	if not omaha_hole.is_empty():
		for a in omaha_hole.size():
			for b in range(a + 1, omaha_hole.size()):
				for x in cards.size():
					for y in range(x + 1, cards.size()):
						for z in range(y + 1, cards.size()):
							var h := [omaha_hole[a], omaha_hole[b], cards[x], cards[y], cards[z]]
							var s := score(h)
							if s > best:
								best = s
								best_hand = h
		return best_hand
	if cards.size() <= 5:
		return cards.duplicate()
	for combo in combos(cards.size(), 5):
		var h: Array = []
		for i in combo:
			h.append(cards[i])
		var s := score(h)
		if s > best:
			best = s
			best_hand = h
	return best_hand

## Every way to pick k of n indices, as sorted Arrays.
static func combos(n: int, k: int) -> Array:
	var out: Array = []
	var cur: Array = []
	_combos(0, n, k, cur, out)
	return out

static func _combos(start: int, n: int, k: int, cur: Array, out: Array) -> void:
	if cur.size() == k:
		out.append(cur.duplicate())
		return
	for i in range(start, n):
		cur.append(i)
		_combos(i + 1, n, k, cur, out)
		cur.pop_back()

# ---------- names ----------

static func _t(text: String) -> String:
	return str(TranslationServer.translate(text))

## "King", "Kings": the names used in hand descriptions.
static func rank_name(v: int, plural: bool = false) -> String:
	var one := ["", "", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Jack", "Queen", "King", "Ace"]
	var many := ["", "", "Twos", "Threes", "Fours", "Fives", "Sixes", "Sevens", "Eights", "Nines", "Tens", "Jacks", "Queens", "Kings", "Aces"]
	return _t(many[v] if plural else one[v])

## The category's name ("Full House"); a straight flush to the Ace is a royal.
static func category_name(s: int) -> String:
	var cat := category(s)
	if cat == STRAIGHT_FLUSH and (s >> 16) & 15 == 14:
		return _t("Royal Flush")
	return _t(RANKINGS[8 - cat][0])

## "Two Pair, Kings and Sevens" -- what a player would say at showdown.
static func describe(s: int) -> String:
	var a := (s >> 16) & 15
	var b := (s >> 12) & 15
	match category(s):
		STRAIGHT_FLUSH:
			if a == 14:
				return _t("Royal Flush")
			return _t("Straight Flush, %s high") % rank_name(a)
		QUADS:
			return _t("Four of a Kind, %s") % rank_name(a, true)
		FULL_HOUSE:
			return _t("Full House, %s over %s") % [rank_name(a, true), rank_name(b, true)]
		FLUSH:
			return _t("Flush, %s high") % rank_name(a)
		STRAIGHT:
			return _t("Straight, %s high") % rank_name(a)
		TRIPS:
			return _t("Three of a Kind, %s") % rank_name(a, true)
		TWO_PAIR:
			return _t("Two Pair, %s and %s") % [rank_name(a, true), rank_name(b, true)]
		PAIR:
			return _t("Pair of %s") % rank_name(a, true)
	return _t("High Card, %s") % rank_name(a)
