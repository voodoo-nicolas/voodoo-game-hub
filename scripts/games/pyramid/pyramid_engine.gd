extends RefCounted

## Pyramid Solitaire: remove pairs of uncovered cards that add up to 13
## (J = 11, Q = 12, K = 13 on its own). Flip the stock one card at a time;
## the top of the waste pile can pair too. Three passes through the stock.
## Clear the pyramid to win. Pure logic, no Nodes.

const ROWS := 7
const PASSES := 3

var pyramid: Array = []    # 28 cards, -1 once removed; index = r*(r+1)/2 + i
var stock: Array = []
var waste: Array = []
var pass_no: int = 1
var history: Array = []

static func rank(card: int) -> int:
	return card % 13 + 1

static func index(r: int, i: int) -> int:
	return r * (r + 1) / 2 + i

func new_game() -> void:
	var deck: Array = []
	for c in 52:
		deck.append(c)
	deck.shuffle()
	pyramid = deck.slice(0, 28)
	stock = deck.slice(28)
	waste = []
	pass_no = 1
	history.clear()

func is_free(p: int) -> bool:
	if p < 0 or pyramid[p] == -1:
		return false
	var r := _row_of(p)
	if r == ROWS - 1:
		return true
	var i := p - index(r, 0)
	return pyramid[index(r + 1, i)] == -1 and pyramid[index(r + 1, i + 1)] == -1

static func _row_of(p: int) -> int:
	var r := 0
	while index(r + 1, 0) <= p:
		r += 1
	return r

func _snapshot() -> void:
	history.append([pyramid.duplicate(), stock.duplicate(), waste.duplicate(), pass_no])

func undo() -> bool:
	if history.is_empty():
		return false
	var h: Array = history.pop_back()
	pyramid = h[0]
	stock = h[1]
	waste = h[2]
	pass_no = h[3]
	return true

## A "slot" is a pyramid index 0..27, or 100 for the waste top.
func card_at(slot: int) -> int:
	if slot == 100:
		return waste.back() if not waste.is_empty() else -1
	return pyramid[slot] if is_free(slot) else -1

func try_remove(a: int, b: int = -1) -> bool:
	var ca := card_at(a)
	if ca == -1:
		return false
	if b == -1:
		if rank(ca) != 13:
			return false
		_snapshot()
		_clear(a)
		return true
	var cb := card_at(b)
	if cb == -1 or a == b or rank(ca) + rank(cb) != 13:
		return false
	_snapshot()
	_clear(a)
	_clear(b)
	return true

func _clear(slot: int) -> void:
	if slot == 100:
		waste.pop_back()
	else:
		pyramid[slot] = -1

func can_draw() -> bool:
	return not stock.is_empty() or (pass_no < PASSES and not waste.is_empty())

func draw() -> bool:
	if not stock.is_empty():
		_snapshot()
		waste.append(stock.pop_back())
		return true
	if pass_no < PASSES and not waste.is_empty():
		_snapshot()
		stock = waste.duplicate()
		stock.reverse()
		waste = []
		pass_no += 1
		return true
	return false

func is_won() -> bool:
	return pyramid.count(-1) == 28

func has_pair_move() -> bool:
	var free: Array = []
	for p in 28:
		if is_free(p):
			free.append(pyramid[p])
	if not waste.is_empty():
		free.append(waste.back())
	for i in free.size():
		if rank(free[i]) == 13:
			return true
		for j in range(i + 1, free.size()):
			if rank(free[i]) + rank(free[j]) == 13:
				return true
	return false

func is_stuck() -> bool:
	return not is_won() and not can_draw() and not has_pair_move()
