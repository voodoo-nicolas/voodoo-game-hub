extends RefCounted

## El 9 (ladder game, Spanish 48-card deck) for 2-4 seats (seat 0 = you). The whole deck is dealt
## evenly (2 seats: 12 cards each, the other 24 stay out of play). Whoever holds the 9 of oros
## opens with it. After that a card is playable if it is a 9 (starts that suit's ladder) or the
## number right below or above its suit's ladder. No playable card = you pass. First to empty
## their hand wins. Pure logic, no Nodes.

const Cards = preload("res://scripts/games/el_9/el_9_cards.gd")

const OPEN := 8                       # the 9 of oros: suit 0, number 9
var seats: int = 3
var hands: Array = []
var lo: Array = [0, 0, 0, 0]          # lowest number on each suit's ladder (0 = not started)
var hi: Array = [0, 0, 0, 0]
var turn: int = 0
var winner: int = -1
var passes: int = 0                   # consecutive passes
var last: Dictionary = {}             # {"p", "card"} or {"p", "pass": true}

func new_game(n: int = 3) -> void:
	seats = n
	var d := Cards.new_deck()
	var per := 12 if n == 2 else 48 / n
	hands = []
	for p in n:
		var h: Array = d.slice(p * per, (p + 1) * per)
		h.sort()
		hands.append(h)
	lo = [0, 0, 0, 0]
	hi = [0, 0, 0, 0]
	winner = -1
	passes = 0
	last = {}
	# the 9 of oros may sit in the unused part of a 2-seat deal: hand it to seat 0's pile
	var holder := -1
	for p in n:
		if hands[p].has(OPEN):
			holder = p
	if holder == -1:
		holder = 0
		hands[0].append(OPEN)
		hands[0].sort()
	play(holder, OPEN)

func can_play(card: int) -> bool:
	var s := Cards.suit(card)
	var num := Cards.number(card)
	if hi[s] == 0:
		return num == 9 and (s == 0 or hi[0] != 0)
	return num == lo[s] - 1 or num == hi[s] + 1

func playable(p: int) -> Array:
	return hands[p].filter(can_play)

func play(p: int, card: int) -> bool:
	if winner != -1 or p != turn and not last.is_empty() or not hands[p].has(card) or not can_play(card):
		return false
	var s := Cards.suit(card)
	var num := Cards.number(card)
	if hi[s] == 0:
		lo[s] = num
		hi[s] = num
	elif num < lo[s]:
		lo[s] = num
	else:
		hi[s] = num
	hands[p].erase(card)
	passes = 0
	last = {"p": p, "card": card}
	if hands[p].is_empty():
		winner = p
	else:
		turn = (p + 1) % seats
	return true

## A player with nothing playable passes. Returns false if they actually can play.
func pass_turn(p: int) -> bool:
	if winner != -1 or p != turn or not playable(p).is_empty():
		return false
	passes += 1
	last = {"p": p, "pass": true}
	turn = (p + 1) % seats
	if passes >= seats:      # nobody can move (cards out of play block the ladders): fewest cards wins
		var w := 0
		for q in seats:
			if hands[q].size() < hands[w].size():
				w = q
		winner = w
	return true

## Which card the computer plays: prefers cards that open the way for its own cards in that suit,
## and ones that close a ladder end (1 or 12); -1 if it has to pass.
func cpu_pick(p: int) -> int:
	var best := -1
	var best_score := -1.0
	for c in playable(p):
		var s := Cards.suit(c)
		var num := Cards.number(c)
		var sc := randf() * 0.3
		for o in hands[p]:
			if o != c and Cards.suit(o) == s:
				var d := absi(Cards.number(o) - num)
				sc += 1.0 / d if d > 0 else 0.0
		if num == 1 or num == 12:
			sc += 0.8
		if num == 9:
			sc -= 0.4   # opening a suit helps everybody
		if sc > best_score:
			best_score = sc
			best = c
	return best

func to_dict() -> Dictionary:
	return {"seats": seats, "hands": hands, "lo": lo, "hi": hi, "turn": turn, "passes": passes}

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func from_dict(d: Dictionary) -> void:
	seats = int(d.seats)
	hands = []
	for h in d.hands:
		hands.append(_ints(h))
	lo = _ints(d.lo)
	hi = _ints(d.hi)
	turn = int(d.turn)
	passes = int(d.get("passes", 0))
	winner = -1
	last = {}
