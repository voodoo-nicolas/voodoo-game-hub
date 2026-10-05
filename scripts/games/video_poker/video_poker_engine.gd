extends RefCounted

## Video Poker, Jacks or Better: bet 1-5 coins, get five cards, hold the
## ones you like, draw new ones for the rest, and get paid by the final
## hand. Coins come out of the player's poker chips (`credits`; a coin is
## `coin` chips). Pure logic, no Nodes. Cards are ints 0..51: rank =
## card % 13 + 1 (Ace = 1), suit = card / 13.

const COINS := [10, 50, 250]
## [name, payout per coin bet]; a royal flush on 5 coins pays 800 each.
const PAYS := [
	["Royal Flush", 250], ["Straight Flush", 50], ["Four of a Kind", 25], ["Full House", 9],
	["Flush", 6], ["Straight", 4], ["Three of a Kind", 3], ["Two Pair", 2], ["Jacks or Better", 1],
]

var credits: int = 0
var coin: int = 10
var bet: int = 1
var hand: Array = []
var held: Array = [false, false, false, false, false]
var deck: Array = []
var phase := "bet"   # bet -> hold -> (draw) -> bet
var last_win: int = 0
var last_hand := ""

func new_session(chips: int) -> void:
	credits = chips
	hand = []
	phase = "bet"
	last_win = 0
	last_hand = ""

func stake() -> int:
	return bet * coin

func can_deal() -> bool:
	return phase == "bet" and credits >= stake()

func deal(rng: RandomNumberGenerator) -> bool:
	if not can_deal():
		return false
	credits -= stake()
	deck = range(52)
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	hand = deck.slice(0, 5)
	deck = deck.slice(5)
	held = [false, false, false, false, false]
	phase = "hold"
	last_win = 0
	last_hand = ""
	return true

func toggle(i: int) -> void:
	if phase == "hold":
		held[i] = not held[i]

## Replaces the cards not held and pays out. Returns the winnings in chips.
func draw() -> int:
	if phase != "hold":
		return 0
	for i in 5:
		if not held[i]:
			hand[i] = deck.pop_back()
	var k := evaluate(hand)
	last_hand = PAYS[k][0] if k >= 0 else ""
	last_win = 0
	if k >= 0:
		last_win = pays(k, bet) * coin
	credits += last_win
	phase = "bet"
	return last_win

## Coins paid for row k of PAYS on a bet of `coins`.
static func pays(k: int, coins: int) -> int:
	if k == 0 and coins == 5:
		return 4000
	return PAYS[k][1] * coins

static func rank(c: int) -> int:
	return c % 13 + 1

## Index into PAYS, or -1 for no win.
static func evaluate(cards: Array) -> int:
	var ranks: Array = []
	var suits := {}
	var counts := {}
	for c in cards:
		var r := rank(c)
		ranks.append(r)
		suits[c / 13] = true
		counts[r] = counts.get(r, 0) + 1
	ranks.sort()
	var flush := suits.size() == 1
	var straight := false
	var royal := false
	if counts.size() == 5:
		if ranks[4] - ranks[0] == 4:
			straight = true
		elif ranks == [1, 10, 11, 12, 13]:
			straight = true
			royal = true
	var groups: Array = counts.values()
	groups.sort()
	groups.reverse()
	if straight and flush:
		return 0 if royal else 1
	if groups[0] == 4:
		return 2
	if groups[0] == 3 and groups[1] == 2:
		return 3
	if flush:
		return 4
	if straight:
		return 5
	if groups[0] == 3:
		return 6
	if groups[0] == 2 and groups[1] == 2:
		return 7
	if groups[0] == 2:
		for r in counts:
			if counts[r] == 2 and (r == 1 or r >= 11):
				return 8
	return -1

## Out of chips for even one coin: the session is over.
func broke() -> bool:
	return phase == "bet" and credits < coin

# ---------- the coach: Jacks or Better "simple strategy" ----------

## Which cards to hold, from the standard simple strategy for this pay
## table (first rule that fits wins): [held indices, the rule's name].
static func hint(cards: Array) -> Array:
	var k := evaluate(cards)
	var all5: Array = [0, 1, 2, 3, 4]
	if k >= 0 and k <= 2:
		if k == 2:
			return [_of_rank_count(cards, 4), "Four of a kind: keep it"]
		return [all5, "Made hand: keep all five"]
	var r4 := _to_royal(cards, 4)
	if not r4.is_empty():
		return [r4, "Four to a royal flush"]
	if k >= 3 and k <= 6:
		if k == 6:
			return [_of_rank_count(cards, 3), "Three of a kind"]
		return [all5, "Made hand: keep all five"]
	var sf4 := _to_straight_flush(cards, 4)
	if not sf4.is_empty():
		return [sf4, "Four to a straight flush"]
	if k == 7:
		return [_of_rank_count(cards, 2), "Two pair"]
	if k == 8:
		return [_of_rank_count(cards, 2), "High pair (Jacks or better)"]
	var r3 := _to_royal(cards, 3)
	if not r3.is_empty():
		return [r3, "Three to a royal flush"]
	var f4 := _suited(cards, 4)
	if not f4.is_empty():
		return [f4, "Four to a flush"]
	var low_pair := _of_rank_count(cards, 2)
	if not low_pair.is_empty():
		return [low_pair, "Low pair"]
	var os4 := _outside_straight(cards)
	if not os4.is_empty():
		return [os4, "Four to an outside straight"]
	var sh := _suited_high(cards)
	if not sh.is_empty():
		return [sh, "Two suited high cards"]
	var sf3 := _to_straight_flush(cards, 3)
	if not sf3.is_empty():
		return [sf3, "Three to a straight flush"]
	var highs := _high_cards(cards)
	if highs.size() >= 2:
		highs.sort_custom(func(a, b): return _hv(cards[a]) < _hv(cards[b]))
		return [highs.slice(0, 2), "Two high cards"]
	var ten := _suited_ten(cards)
	if not ten.is_empty():
		return [ten, "Suited 10 with a high card"]
	if highs.size() == 1:
		return [highs, "One high card"]
	return [[], "Nothing worth keeping: draw five"]

## Ace high (14) for strategy purposes.
static func _hv(c: int) -> int:
	var r := rank(c)
	return 14 if r == 1 else r

static func _of_rank_count(cards: Array, n: int) -> Array:
	var counts := {}
	for c in cards:
		counts[rank(c)] = int(counts.get(rank(c), 0)) + 1
	var out: Array = []
	for i in cards.size():
		if counts[rank(cards[i])] == n:
			out.append(i)
	return out

static func _high_cards(cards: Array) -> Array:
	var out: Array = []
	for i in cards.size():
		if _hv(cards[i]) >= 11:
			out.append(i)
	return out

static func _to_royal(cards: Array, n: int) -> Array:
	for suit in 4:
		var out: Array = []
		for i in cards.size():
			if cards[i] / 13 == suit and _hv(cards[i]) >= 10:
				out.append(i)
		if out.size() == n:
			return out
	return []

static func _suited(cards: Array, n: int) -> Array:
	for suit in 4:
		var out: Array = []
		for i in cards.size():
			if cards[i] / 13 == suit:
				out.append(i)
		if out.size() == n:
			return out
	return []

## n cards of one suit that fit inside five ranks in a row (Ace high or low).
static func _to_straight_flush(cards: Array, n: int) -> Array:
	for suit in 4:
		var idx: Array = []
		for i in cards.size():
			if cards[i] / 13 == suit:
				idx.append(i)
		if idx.size() < n:
			continue
		for low in range(1, 11):
			var fit: Array = []
			for i in idx:
				var v := _hv(cards[i])
				if (v >= low and v <= low + 4) or (low == 1 and v == 14):
					fit.append(i)
			if fit.size() == n:
				return fit
	return []

## Four ranks in a row, open at both ends (not A-2-3-4 or J-Q-K-A).
static func _outside_straight(cards: Array) -> Array:
	for low in range(2, 11):
		var out: Array = []
		var used := {}
		for i in cards.size():
			var v := _hv(cards[i])
			if v >= low and v <= low + 3 and not used.has(v):
				used[v] = true
				out.append(i)
		if out.size() == 4:
			return out
	return []

static func _suited_high(cards: Array) -> Array:
	var highs := _high_cards(cards)
	for a in highs:
		for b in highs:
			if a < b and cards[a] / 13 == cards[b] / 13:
				return [a, b]
	return []

static func _suited_ten(cards: Array) -> Array:
	for i in cards.size():
		if _hv(cards[i]) != 10:
			continue
		for j in cards.size():
			var v := _hv(cards[j])
			if v >= 11 and v <= 13 and cards[j] / 13 == cards[i] / 13:
				return [i, j]
	return []
