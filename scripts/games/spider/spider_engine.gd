extends RefCounted

## Spider Solitaire (two decks, 10 columns). Build down regardless of suit,
## but only a same-suit run moves together; a full K..A same-suit run is
## removed. Deal a new row from the stock when stuck (no empty columns
## allowed). Clear all 8 runs to win. Pure logic, no Nodes.
## Cards are ints 0..51 (see spider_cards.gd); suit = card / 13.

var cols: Array = []        # 10 Arrays of cards, bottom -> top
var down: Array = []        # face-down count per column
var stock: Array = []
var completed: int = 0
var moves: int = 0
var suits: int = 1
var history: Array = []

func new_game(suit_count: int) -> void:
	suits = suit_count
	var deck: Array = []
	for i in 104:
		var s: int = (i / 13) % suits
		deck.append(s * 13 + i % 13)
	deck.shuffle()
	cols.clear()
	down.clear()
	for c in 10:
		var n := 6 if c < 4 else 5
		cols.append(deck.slice(0, n))
		deck = deck.slice(n)
		down.append(n - 1)
	stock = deck
	completed = 0
	moves = 0
	history.clear()

static func rank(card: int) -> int:
	return card % 13 + 1

## Index where the movable same-suit run at the bottom of column c starts.
func run_start(c: int) -> int:
	var col: Array = cols[c]
	if col.is_empty():
		return -1
	var k := col.size() - 1
	while k > down[c]:
		var a: int = col[k - 1]
		var b: int = col[k]
		if a / 13 == b / 13 and rank(a) == rank(b) + 1:
			k -= 1
		else:
			break
	return k

func can_move(from: int, k: int, to: int) -> bool:
	if from == to or k < run_start(from) or k >= cols[from].size():
		return false
	if cols[to].is_empty():
		return true
	return rank(cols[to].back()) == rank(cols[from][k]) + 1

func _snapshot() -> void:
	var saved_cols: Array = []
	for col in cols:
		saved_cols.append(col.duplicate())
	history.append([saved_cols, down.duplicate(), stock.duplicate(), completed, moves])

func undo() -> bool:
	if history.is_empty():
		return false
	var h: Array = history.pop_back()
	cols = h[0]
	down = h[1]
	stock = h[2]
	completed = h[3]
	moves = h[4]
	return true

func move(from: int, k: int, to: int) -> bool:
	if not can_move(from, k, to):
		return false
	_snapshot()
	var run: Array = cols[from].slice(k)
	cols[from] = cols[from].slice(0, k)
	cols[to].append_array(run)
	moves += 1
	_after(from)
	_after(to)
	return true

## Best destination for the run from k: same-suit build, then any build,
## then an empty column. -1 if none.
func best_target(from: int, k: int) -> int:
	var card: int = cols[from][k]
	var any_build := -1
	var empty := -1
	for to in 10:
		if to == from or not can_move(from, k, to):
			continue
		if cols[to].is_empty():
			if empty == -1 and k > 0:
				empty = to
		elif cols[to].back() / 13 == card / 13:
			return to
		elif any_build == -1:
			any_build = to
	return any_build if any_build != -1 else empty

func can_deal() -> bool:
	if stock.is_empty():
		return false
	for col in cols:
		if col.is_empty():
			return false
	return true

func deal() -> bool:
	if not can_deal():
		return false
	_snapshot()
	for c in 10:
		cols[c].append(stock.pop_back())
	moves += 1
	for c in 10:
		_after(c)
	return true

func _after(c: int) -> void:
	var col: Array = cols[c]
	# remove a finished K..A run
	if col.size() - down[c] >= 13:
		var s := run_start(c)
		if s >= 0 and col.size() - s >= 13 and rank(col[col.size() - 13]) == 13:
			cols[c] = col.slice(0, col.size() - 13)
			completed += 1
			col = cols[c]
	if down[c] > 0 and down[c] >= col.size():
		down[c] = col.size() - 1
	if down[c] < 0:
		down[c] = 0

func is_won() -> bool:
	return completed == 8
