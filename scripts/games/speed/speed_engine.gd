extends RefCounted

## Speed: a real-time race against the computer. Play any hand card that is
## one rank above or below either centre pile (Ace and King wrap). Your hand
## refills to 5 from your draw pile. When neither player can play, a card is
## flipped from each side pile onto the centre. Empty your hand and draw pile
## first to win. Pure logic, no Nodes (the game scene supplies the clock).

const HAND := 5

var hands: Array = [[], []]
var draws: Array = [[], []]
var sides: Array = [[], []]    # face-down reserve piles
var centers: Array = [[], []]
var winner: int = -1

static func rank(card: int) -> int:
	return card % 13 + 1

static func adjacent(a: int, b: int) -> bool:
	var d: int = abs(rank(a) - rank(b))
	return d == 1 or d == 12

func new_game() -> void:
	var deck: Array = []
	for c in 52:
		deck.append(c)
	deck.shuffle()
	for p in 2:
		hands[p] = deck.slice(0, HAND)
		draws[p] = deck.slice(HAND, 20)
		deck = deck.slice(20)
	sides = [deck.slice(0, 6), deck.slice(6, 12)]
	centers = [[], []]
	winner = -1
	flip()

func top(pile: int) -> int:
	return centers[pile].back() if not centers[pile].is_empty() else -1

## Centre pile the card can go on (-1 if none), preferring `prefer`.
func target_for(card: int, prefer: int = 0) -> int:
	for k in [prefer, 1 - prefer]:
		if top(k) >= 0 and adjacent(card, top(k)):
			return k
	return -1

func can_play(p: int) -> bool:
	for c in hands[p]:
		if target_for(c) >= 0:
			return true
	return false

func play(p: int, card: int, pile: int = -1) -> bool:
	if winner != -1 or not hands[p].has(card):
		return false
	if pile < 0:
		pile = target_for(card)
	if pile < 0 or not adjacent(card, top(pile)):
		return false
	hands[p].erase(card)
	centers[pile].append(card)
	if not draws[p].is_empty():
		hands[p].append(draws[p].pop_back())
	if hands[p].is_empty() and draws[p].is_empty():
		winner = p
	return true

func stuck() -> bool:
	return winner == -1 and not can_play(0) and not can_play(1)

## Turns one card from each side pile onto the centre piles, recycling the
## centre piles into the side piles when those have run out.
func flip() -> void:
	if sides[0].is_empty() or sides[1].is_empty():
		var pool: Array = []
		for k in 2:
			var pile: Array = centers[k]
			if pile.size() > 1:
				pool.append_array(pile.slice(0, pile.size() - 1))
				centers[k] = [pile.back()]
		pool.append_array(sides[0])
		pool.append_array(sides[1])
		pool.shuffle()
		var half := pool.size() / 2
		sides = [pool.slice(0, half), pool.slice(half)]
	for k in 2:
		if not sides[k].is_empty():
			centers[k].append(sides[k].pop_back())

func cards_left(p: int) -> int:
	return hands[p].size() + draws[p].size()
