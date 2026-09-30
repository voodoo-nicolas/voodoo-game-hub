extends RefCounted

## Go Fish, you (0) vs the computer (1). Ask for a rank you hold; if they
## have any they hand them all over and you ask again. If not, "go fish":
## draw a card, and if it's the rank you asked for, go again. Four of a rank
## make a book. Most books when all 13 are made wins. Pure logic, no Nodes.

const START_HAND := 7

var hands: Array = [[], []]
var deck: Array = []
var books: Array = [[], []]    # ranks (1..13) collected
var turn: int = 0
var cpu_memory: Dictionary = {}  # ranks the player has asked for

static func rank(card: int) -> int:
	return card % 13 + 1

func new_game() -> void:
	deck = []
	for c in 52:
		deck.append(c)
	deck.shuffle()
	hands = [deck.slice(0, START_HAND), deck.slice(START_HAND, START_HAND * 2)]
	deck = deck.slice(START_HAND * 2)
	books = [[], []]
	turn = 0
	cpu_memory = {}
	for p in 2:
		_collect_books(p)

func count_rank(p: int, r: int) -> int:
	var n := 0
	for c in hands[p]:
		if rank(c) == r:
			n += 1
	return n

func ranks_in_hand(p: int) -> Array:
	var out: Array = []
	for c in hands[p]:
		if not out.has(rank(c)):
			out.append(rank(c))
	return out

func is_over() -> bool:
	return books[0].size() + books[1].size() == 13

## If the player to move has no cards, they draw one (or the turn passes if
## the deck is empty too). Returns false when the turn had to be skipped.
func prepare_turn() -> bool:
	if not hands[turn].is_empty():
		return true
	if deck.is_empty():
		turn = 1 - turn
		return false
	hands[turn].append(deck.pop_back())
	return true

## Asks the opponent for rank r. Returns {got: int, drew: int (card or -1),
## again: bool, new_books: Array}.
func ask(r: int) -> Dictionary:
	var p := turn
	var o := 1 - p
	var result := {"got": 0, "drew": -1, "again": false, "new_books": []}
	if p == 0:
		cpu_memory[r] = true
	var taken: Array = hands[o].filter(func(c): return rank(c) == r)
	if not taken.is_empty():
		for c in taken:
			hands[o].erase(c)
		hands[p].append_array(taken)
		result.got = taken.size()
		result.again = true
	elif not deck.is_empty():
		var c: int = deck.pop_back()
		hands[p].append(c)
		result.drew = c
		result.again = rank(c) == r
	result.new_books = _collect_books(p)
	if p == 1 and result.got > 0:
		cpu_memory.erase(r)   # the player no longer holds it
	if not result.again or is_over():
		turn = o
	return result

func _collect_books(p: int) -> Array:
	var made: Array = []
	for r in ranks_in_hand(p):
		if count_rank(p, r) == 4:
			hands[p] = hands[p].filter(func(c): return rank(c) != r)
			books[p].append(r)
			made.append(r)
			if cpu_memory.has(r):
				cpu_memory.erase(r)
	return made

func cpu_pick() -> int:
	var mine := ranks_in_hand(1)
	var remembered: Array = mine.filter(func(r): return cpu_memory.has(r))
	if not remembered.is_empty():
		return remembered[randi() % remembered.size()]
	mine.sort_custom(func(a, b): return count_rank(1, a) > count_rank(1, b))
	# mostly ask for what we hold most of, sometimes mix it up
	return mine[0] if randf() < 0.6 else mine[randi() % mine.size()]
