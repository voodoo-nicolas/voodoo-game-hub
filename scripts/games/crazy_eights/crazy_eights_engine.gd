extends RefCounted

## Crazy Eights for 2-4 players (vs the computer: you = 0, computers = 1
## and 2; pass-and-play: every seat is a person). Match the top
## card's suit or rank; an 8 is wild and names the next suit. If you can't
## play, draw until you can (or the deck runs out, then pass). First to empty
## their hand wins. Pure logic, no Nodes. Cards are ints 0..51.

const HAND := 7

var PLAYERS: int = 3  # seats this game (kept in caps: it used to be a const)

var hands: Array = []
var deck: Array = []
var discard: Array = []
var suit_now: int = 0
var turn: int = 0
var winner: int = -1
var passes: int = 0   # consecutive passes; everyone passing ends in a draw

static func rank(card: int) -> int:
	return card % 13 + 1

static func suit(card: int) -> int:
	return card / 13

func new_game(n: int = 3) -> void:
	PLAYERS = n
	deck = []
	for c in 52:
		deck.append(c)
	deck.shuffle()
	hands = []
	for p in PLAYERS:
		hands.append(deck.slice(0, HAND))
		deck = deck.slice(HAND)
	# never start on an 8
	var i := 0
	while rank(deck[i]) == 8:
		i += 1
	discard = [deck[i]]
	deck.remove_at(i)
	suit_now = suit(discard[0])
	turn = 0
	winner = -1
	passes = 0

func top() -> int:
	return discard.back()

func can_play(card: int) -> bool:
	return rank(card) == 8 or suit(card) == suit_now or rank(card) == rank(top())

func playable(p: int) -> Array:
	return hands[p].filter(can_play)

func play(p: int, card: int, chosen_suit: int = -1) -> bool:
	if p != turn or winner != -1 or not hands[p].has(card) or not can_play(card):
		return false
	hands[p].erase(card)
	discard.append(card)
	suit_now = chosen_suit if rank(card) == 8 and chosen_suit >= 0 else suit(card)
	passes = 0
	if hands[p].is_empty():
		winner = p
	else:
		turn = (turn + 1) % PLAYERS
	return true

func can_draw() -> bool:
	return not deck.is_empty() or discard.size() > 1

## Draws one card for the current player (reshuffling the discards if
## needed). Returns the card, or -1 if nothing is left.
func draw() -> int:
	if deck.is_empty():
		if discard.size() <= 1:
			return -1
		var keep: int = discard.pop_back()
		deck = discard
		deck.shuffle()
		discard = [keep]
	var c: int = deck.pop_back()
	hands[turn].append(c)
	return c

func pass_turn() -> void:
	passes += 1
	if passes >= PLAYERS:
		winner = PLAYERS   # nobody can move: draw
		return
	turn = (turn + 1) % PLAYERS

## The computer's choice: [card, suit] or [] if it must draw.
func cpu_choice(p: int) -> Array:
	var options := playable(p)
	if options.is_empty():
		return []
	var counts := [0, 0, 0, 0]
	for c in hands[p]:
		if rank(c) != 8:
			counts[suit(c)] += 1
	var best_suit := counts.find(counts.max())
	var non_eights := options.filter(func(c): return rank(c) != 8)
	if not non_eights.is_empty():
		# prefer the suit we hold most of, then high cards
		non_eights.sort_custom(func(a, b): return counts[suit(a)] * 20 + rank(a) > counts[suit(b)] * 20 + rank(b))
		return [non_eights[0], -1]
	return [options[0], best_suit]
