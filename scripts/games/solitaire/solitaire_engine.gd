extends RefCounted

const CardData = preload("res://scripts/games/solitaire/card_data.gd")

var tableau: Array = []      # 7 arrays of CardData, tableau[i].back() is the top (front-most) card
var foundations: Array = []  # 4 arrays of CardData, indexed by suit
var stock: Array = []        # face-down draw pile, stock.back() is next to draw
var waste: Array = []        # face-up drawn cards, waste.back() is the playable top
var move_count: int = 0

var _history: Array = []

func new_game() -> void:
	var deck: Array = []
	for s in range(4):
		for r in range(1, 14):
			deck.append(CardData.new(r, s, false))
	deck.shuffle()

	tableau = []
	for col in range(7):
		var pile: Array = []
		for i in range(col + 1):
			var card = deck.pop_back()
			card.face_up = (i == col)
			pile.append(card)
		tableau.append(pile)

	stock = deck
	waste = []
	foundations = [[], [], [], []]
	move_count = 0
	_history = []

func is_won() -> bool:
	for f in foundations:
		if f.size() != 13:
			return false
	return true

func can_undo() -> bool:
	return _history.size() > 0

func undo() -> void:
	if _history.is_empty():
		return
	var snap: Dictionary = _history.pop_back()
	tableau = snap.tableau
	foundations = snap.foundations
	stock = snap.stock
	waste = snap.waste
	move_count = snap.move_count

func draw_from_stock() -> void:
	_push_history()
	if stock.is_empty():
		while not waste.is_empty():
			var c = waste.pop_back()
			c.face_up = false
			stock.append(c)
	else:
		var c: RefCounted = stock.pop_back()
		c.face_up = true
		waste.append(c)

## Attempts to move `count` cards starting at `card_index` in tableau[from_col] onto tableau[to_col].
func move_tableau_to_tableau(from_col: int, card_index: int, to_col: int) -> bool:
	if from_col == to_col:
		return false
	var src: Array = tableau[from_col]
	if card_index < 0 or card_index >= src.size() or not src[card_index].face_up:
		return false

	var moving_card = src[card_index]
	var dest: Array = tableau[to_col]
	var valid: bool
	if dest.is_empty():
		valid = moving_card.rank == 13
	else:
		valid = _can_stack_tableau(moving_card, dest.back())
	if not valid:
		return false

	_push_history()
	var moving_run: Array = src.slice(card_index, src.size())
	tableau[from_col] = src.slice(0, card_index)
	for c in moving_run:
		tableau[to_col].append(c)
	if not tableau[from_col].is_empty():
		tableau[from_col].back().face_up = true
	move_count += 1
	return true

func move_waste_to_tableau(to_col: int) -> bool:
	if waste.is_empty():
		return false
	var moving_card = waste.back()
	var dest: Array = tableau[to_col]
	var valid: bool
	if dest.is_empty():
		valid = moving_card.rank == 13
	else:
		valid = _can_stack_tableau(moving_card, dest.back())
	if not valid:
		return false

	_push_history()
	tableau[to_col].append(waste.pop_back())
	move_count += 1
	return true

func move_tableau_to_foundation(from_col: int) -> bool:
	var src: Array = tableau[from_col]
	if src.is_empty() or not src.back().face_up:
		return false
	var card = src.back()
	if not _can_place_on_foundation(card, card.suit):
		return false

	_push_history()
	foundations[card.suit].append(src.pop_back())
	if not tableau[from_col].is_empty():
		tableau[from_col].back().face_up = true
	move_count += 1
	return true

func move_waste_to_foundation() -> bool:
	if waste.is_empty():
		return false
	var card = waste.back()
	if not _can_place_on_foundation(card, card.suit):
		return false

	_push_history()
	foundations[card.suit].append(waste.pop_back())
	move_count += 1
	return true

func _can_stack_tableau(card, on_top_of) -> bool:
	return on_top_of.rank == card.rank + 1 and card.is_red() != on_top_of.is_red()

func _can_place_on_foundation(card, suit_index: int) -> bool:
	if card.suit != suit_index:
		return false
	var pile: Array = foundations[suit_index]
	if pile.is_empty():
		return card.rank == 1
	return pile.back().rank == card.rank - 1

func _push_history() -> void:
	_history.append({
		"tableau": _deep_copy_piles(tableau),
		"foundations": _deep_copy_piles(foundations),
		"stock": _deep_copy_pile(stock),
		"waste": _deep_copy_pile(waste),
		"move_count": move_count,
	})
	if _history.size() > 200:
		_history.pop_front()

func _deep_copy_pile(pile: Array) -> Array:
	var out: Array = []
	for c in pile:
		out.append(c.duplicate_card())
	return out

func _deep_copy_piles(piles: Array) -> Array:
	var out: Array = []
	for p in piles:
		out.append(_deep_copy_pile(p))
	return out
