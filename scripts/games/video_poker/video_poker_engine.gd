extends RefCounted

## Video Poker, Jacks or Better: bet 1-5 credits, get five cards, hold the
## ones you like, draw new ones for the rest, and get paid by the final
## hand. Pure logic, no Nodes. Cards are ints 0..51: rank = card % 13 + 1
## (Ace = 1), suit = card / 13.

const START_CREDITS := 100
## [name, payout per credit bet]; a royal flush on 5 credits pays 800 each.
const PAYS := [
	["Royal Flush", 250], ["Straight Flush", 50], ["Four of a Kind", 25], ["Full House", 9],
	["Flush", 6], ["Straight", 4], ["Three of a Kind", 3], ["Two Pair", 2], ["Jacks or Better", 1],
]

var credits: int = START_CREDITS
var bet: int = 1
var hand: Array = []
var held: Array = [false, false, false, false, false]
var deck: Array = []
var phase := "bet"   # bet -> hold -> (draw) -> bet
var last_win: int = 0
var last_hand := ""

func new_session() -> void:
	credits = START_CREDITS
	bet = 1
	hand = []
	phase = "bet"
	last_win = 0
	last_hand = ""

func can_deal() -> bool:
	return phase == "bet" and credits >= bet

func deal(rng: RandomNumberGenerator) -> bool:
	if not can_deal():
		return false
	credits -= bet
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

## Replaces the cards not held and pays out. Returns the winnings.
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
		last_win = PAYS[k][1] * bet
		if k == 0 and bet == 5:
			last_win = 4000
	credits += last_win
	phase = "bet"
	return last_win

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

## Out of credits with no way to bet: the session is over.
func broke() -> bool:
	return phase == "bet" and credits <= 0
