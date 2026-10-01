extends RefCounted

## Ride the Bus, a pass-the-phone drinking card game in three phases.
##  1. Guessing: four rounds, every player once per round -- red or black,
##     higher or lower, inside or outside, then the suit. The card goes into
##     that player's hand either way; a wrong guess drinks 1 / 2 / 3 / 4.
##  2. Pyramid: ten face-down cards in rows of 4, 3, 2, 1. Flip them one at a
##     time; any player holding the same rank gives out drinks (1 on the
##     bottom row up to 4 at the top) and lays that card down.
##  3. The bus: whoever holds the most cards rides it -- the four guesses
##     again, in a row, with fresh cards, until all four are right. A wrong
##     guess drinks and starts over.
## Ties count as wrong in higher/lower; inside/outside ties count as outside.
## Pure logic, no Nodes. Cards are {rank (2..14, ace high), suit (0..3)}.

const ROUNDS := 4
const PYRAMID_ROWS := [4, 3, 2, 1]   # cards per row, bottom first
const MAX_PLAYERS := 10              # 4 cards each + 10 pyramid cards <= 52

var players := 2
var phase := "guess"      # guess | pyramid | bus | done
var deck: Array = []
var hands: Array = []     # per player
var round_index := 0      # guessing round 0..3 (also the bus step)
var current := 0          # whose turn in the guessing phase
var pyramid: Array = []   # 10 cards, bottom row first
var flipped := 0          # pyramid cards turned so far
var rider := -1
var bus_cards: Array = [] # the rider's current attempt
var bus_attempts := 0

static func is_red(card: Dictionary) -> bool:
	return card.suit == 1 or card.suit == 2

func reset(p_players: int) -> void:
	players = clampi(p_players, 2, MAX_PLAYERS)
	deck = _new_deck()
	hands = []
	for i in players:
		hands.append([])
	phase = "guess"
	round_index = 0
	current = 0
	pyramid = []
	flipped = 0
	rider = -1
	bus_cards = []
	bus_attempts = 0

func _new_deck() -> Array:
	var d: Array = []
	for s in 4:
		for r in range(2, 15):
			d.append({"rank": r, "suit": s})
	d.shuffle()
	return d

## Is `guess` right for `card`, given the earlier cards of this run?
## guess: "red"/"black", "higher"/"lower", "inside"/"outside", or "0".."3" (a suit).
static func judge(step: int, guess: String, card: Dictionary, earlier: Array) -> bool:
	match step:
		0:
			return guess == ("red" if is_red(card) else "black")
		1:
			var prev: int = earlier[0].rank
			return card.rank != prev and (guess == "higher") == (card.rank > prev)
		2:
			var lo: int = mini(earlier[0].rank, earlier[1].rank)
			var hi: int = maxi(earlier[0].rank, earlier[1].rank)
			return (guess == "inside") == (card.rank > lo and card.rank < hi)
	return guess == str(card.suit)

## Guessing phase: the current player guesses. Returns {card, correct,
## drinks, player}. Moves on to the next player / round / the pyramid.
func guess(g: String) -> Dictionary:
	var p := current
	var card: Dictionary = deck.pop_back()
	var ok := judge(round_index, g, card, hands[p])
	hands[p].append(card)
	var res := {"card": card, "correct": ok, "drinks": 0 if ok else round_index + 1, "player": p}
	current += 1
	if current >= players:
		current = 0
		round_index += 1
		if round_index >= ROUNDS:
			_start_pyramid()
	return res

func _start_pyramid() -> void:
	phase = "pyramid"
	pyramid = []
	for i in 10:
		pyramid.append(deck.pop_back())
	flipped = 0

## Row (0 = bottom) of pyramid card i, and the drinks it's worth.
static func row_of(i: int) -> int:
	var start := 0
	for r in PYRAMID_ROWS.size():
		if i < start + PYRAMID_ROWS[r]:
			return r
		start += PYRAMID_ROWS[r]
	return PYRAMID_ROWS.size() - 1

## Pyramid phase: turns the next card. Returns {card, index, row, drinks,
## matches: Array of [player, count]}. Matching cards leave the hands.
func flip_next() -> Dictionary:
	var i := flipped
	var card: Dictionary = pyramid[i]
	flipped += 1
	var row := row_of(i)
	var matches: Array = []
	for p in players:
		var n := 0
		for c in hands[p].duplicate():
			if c.rank == card.rank:
				hands[p].erase(c)
				n += 1
		if n > 0:
			matches.append([p, n])
	if flipped >= pyramid.size():
		_start_bus()
	return {"card": card, "index": i, "row": row, "drinks": row + 1, "matches": matches}

## Most cards left rides the bus; ties go to the first of them in seat order.
func _start_bus() -> void:
	phase = "bus"
	rider = 0
	for p in players:
		if hands[p].size() > hands[rider].size():
			rider = p
	deck = _new_deck()
	bus_cards = []
	round_index = 0
	bus_attempts = 1

## Bus phase: the rider guesses. Returns {card, correct, drinks, off (got off
## the bus)}. A wrong guess drinks and starts the four steps over.
func bus_guess(g: String) -> Dictionary:
	if deck.size() < 4:
		deck = _new_deck()
	var card: Dictionary = deck.pop_back()
	var ok := judge(round_index, g, card, bus_cards)
	var res := {"card": card, "correct": ok, "drinks": 0 if ok else round_index + 1, "off": false}
	if ok:
		bus_cards.append(card)
		round_index += 1
		if round_index >= ROUNDS:
			phase = "done"
			res.off = true
	else:
		bus_cards = []
		round_index = 0
		bus_attempts += 1
	return res
