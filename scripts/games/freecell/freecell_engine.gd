extends RefCounted

## FreeCell. All cards face up in 8 columns; build down in alternating
## colours, use the 4 free cells as temporary space, and build each suit up
## A..K on the foundations. Several cards move together when there's room
## ((free cells + 1) × 2^empty columns). Pure logic, no Nodes.

var cols: Array = []          # 8 Arrays, bottom -> top
var cells: Array = [-1, -1, -1, -1]
var found: Array = [0, 0, 0, 0]   # highest rank on each suit's foundation
var moves: int = 0
var history: Array = []

static func rank(card: int) -> int:
	return card % 13 + 1

static func suit(card: int) -> int:
	return card / 13

static func red(card: int) -> bool:
	return suit(card) == 1 or suit(card) == 2

func new_game(deck: Array = []) -> void:
	if deck.is_empty():
		for c in 52:
			deck.append(c)
		deck.shuffle()
	cols.clear()
	for c in 8:
		cols.append([])
	for i in 52:
		cols[i % 8].append(deck[i])
	cells = [-1, -1, -1, -1]
	found = [0, 0, 0, 0]
	moves = 0
	history.clear()

func _snapshot() -> void:
	var saved: Array = []
	for col in cols:
		saved.append(col.duplicate())
	history.append([saved, cells.duplicate(), found.duplicate(), moves])

func undo() -> bool:
	if history.is_empty():
		return false
	var h: Array = history.pop_back()
	cols = h[0]
	cells = h[1]
	found = h[2]
	moves = h[3]
	return true

func free_cells() -> int:
	return cells.count(-1)

func empty_cols(except: int = -1) -> int:
	var n := 0
	for c in 8:
		if c != except and cols[c].is_empty():
			n += 1
	return n

func max_run(to: int) -> int:
	return (free_cells() + 1) * (1 << empty_cols(to))

## Index where the alternating-colour descending run at the bottom starts.
func run_start(c: int) -> int:
	var col: Array = cols[c]
	if col.is_empty():
		return -1
	var k := col.size() - 1
	while k > 0:
		var a: int = col[k - 1]
		var b: int = col[k]
		if red(a) != red(b) and rank(a) == rank(b) + 1:
			k -= 1
		else:
			break
	return k

func can_found(card: int) -> bool:
	return found[suit(card)] == rank(card) - 1

func fits_on(card: int, to: int) -> bool:
	if cols[to].is_empty():
		return true
	var top: int = cols[to].back()
	return red(top) != red(card) and rank(top) == rank(card) + 1

## Moves card(s) from column c starting at k (or from cell `cell` when c = -1)
## to the best destination. Returns true if something moved.
func auto_move(c: int, k: int, cell: int = -1) -> bool:
	var card: int = cells[cell] if c == -1 else cols[c][k]
	var single: bool = c == -1 or k == cols[c].size() - 1
	if c >= 0 and k < run_start(c):
		return false
	# 1) foundation
	if single and can_found(card):
		_snapshot()
		_take(c, k, cell)
		found[suit(card)] += 1
		_finish()
		return true
	var count: int = 1 if c == -1 else cols[c].size() - k
	# 2) a non-empty column, 3) an empty column
	for want_empty in [false, true]:
		for to in 8:
			if to == c or cols[to].is_empty() != want_empty:
				continue
			if count > max_run(to if want_empty else -1):
				continue
			if not fits_on(card, to):
				continue
			if want_empty and c >= 0 and k == 0:
				continue   # pointless: whole column to an empty column
			_snapshot()
			var run: Array = [card] if c == -1 else cols[c].slice(k)
			_take(c, k, cell)
			cols[to].append_array(run)
			_finish()
			return true
	# 4) a free cell
	if single and c >= 0 and free_cells() > 0:
		_snapshot()
		cells[cells.find(-1)] = card
		cols[c].pop_back()
		_finish()
		return true
	return false

func _take(c: int, k: int, cell: int) -> void:
	if c == -1:
		cells[cell] = -1
	else:
		cols[c] = cols[c].slice(0, k)

func _finish() -> void:
	moves += 1
	auto_foundation()

## Sends cards up that can't be needed any more (both opposite-colour
## foundations are high enough).
func auto_foundation() -> void:
	var moved := true
	while moved:
		moved = false
		for c in 8:
			if cols[c].is_empty():
				continue
			var card: int = cols[c].back()
			if can_found(card) and _safe(card):
				found[suit(card)] += 1
				cols[c].pop_back()
				moved = true
		for i in 4:
			if cells[i] != -1 and can_found(cells[i]) and _safe(cells[i]):
				found[suit(cells[i])] += 1
				cells[i] = -1
				moved = true

func _safe(card: int) -> bool:
	var r := rank(card)
	if r <= 2:
		return true
	var opp: Array = [0, 3] if red(card) else [1, 2]
	return found[opp[0]] >= r - 1 and found[opp[1]] >= r - 1

func is_won() -> bool:
	return found == [13, 13, 13, 13]
