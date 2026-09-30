extends RefCounted

## Gem Match: swap two neighbouring gems to line up 3 or more of a kind.
## Matches clear, gems fall, new ones drop in and chains score extra.
## 30 moves per game. Pure logic, no Nodes.

const SIZE := 8
const KINDS := 6
const MOVES := 30

var grid: Array = []      # SIZE*SIZE kinds (0..KINDS-1), -1 = empty
var score: int = 0
var moves_left: int = MOVES
var chain: int = 0

func reset() -> void:
	score = 0
	moves_left = MOVES
	chain = 0
	_fill_fresh()

## A full board with no ready-made matches and at least one move.
func _fill_fresh() -> void:
	while true:
		grid.clear()
		for i in SIZE * SIZE:
			var r := i / SIZE
			var c := i % SIZE
			var k := randi() % KINDS
			while (c >= 2 and grid[i - 1] == k and grid[i - 2] == k) or (r >= 2 and grid[i - SIZE] == k and grid[i - 2 * SIZE] == k):
				k = randi() % KINDS
			grid.append(k)
		if has_moves():
			return

static func adjacent(a: int, b: int) -> bool:
	return (abs(a - b) == 1 and a / SIZE == b / SIZE) or abs(a - b) == SIZE

func find_matches() -> Array:
	var hits := {}
	for r in SIZE:
		for c in SIZE:
			var i := r * SIZE + c
			var k: int = grid[i]
			if k < 0:
				continue
			if c <= SIZE - 3 and grid[i + 1] == k and grid[i + 2] == k:
				var n := c
				while n < SIZE and grid[r * SIZE + n] == k:
					hits[r * SIZE + n] = true
					n += 1
			if r <= SIZE - 3 and grid[i + SIZE] == k and grid[i + 2 * SIZE] == k:
				var n := r
				while n < SIZE and grid[n * SIZE + c] == k:
					hits[n * SIZE + c] = true
					n += 1
	return hits.keys()

func _swap(a: int, b: int) -> void:
	var t = grid[a]
	grid[a] = grid[b]
	grid[b] = t

## Swaps if it makes a match (and uses a move). Returns true if it did.
func try_swap(a: int, b: int) -> bool:
	if moves_left <= 0 or not adjacent(a, b):
		return false
	_swap(a, b)
	if find_matches().is_empty():
		_swap(a, b)
		return false
	moves_left -= 1
	chain = 0
	return true

## Clears current matches and scores them. Returns the cleared cells.
func clear_matches() -> Array:
	var cells := find_matches()
	if cells.is_empty():
		return cells
	chain += 1
	score += cells.size() * 10 * chain + max(0, cells.size() - 3) * 20
	for i in cells:
		grid[i] = -1
	return cells

## Drops gems into gaps and fills the top with new ones.
func collapse() -> void:
	for c in SIZE:
		var write := SIZE - 1
		for r in range(SIZE - 1, -1, -1):
			var k: int = grid[r * SIZE + c]
			if k >= 0:
				grid[write * SIZE + c] = k
				write -= 1
		for r in range(write, -1, -1):
			grid[r * SIZE + c] = randi() % KINDS

func has_moves() -> bool:
	for i in SIZE * SIZE:
		for j in [i + 1, i + SIZE]:
			if j >= SIZE * SIZE or not adjacent(i, j):
				continue
			_swap(i, j)
			var ok := not find_matches().is_empty()
			_swap(i, j)
			if ok:
				return true
	return false

func reshuffle() -> void:
	_fill_fresh()

## A swap that works, for the hint button ([a, b] or []).
func hint() -> Array:
	for i in SIZE * SIZE:
		for j in [i + 1, i + SIZE]:
			if j >= SIZE * SIZE or not adjacent(i, j):
				continue
			_swap(i, j)
			var ok := not find_matches().is_empty()
			_swap(i, j)
			if ok:
				return [i, j]
	return []
