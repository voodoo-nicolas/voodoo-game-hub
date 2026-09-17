extends RefCounted

const SIZE := 5

var grid: Array = []  # SIZE x SIZE bool
var moves: int = 0

## Scrambles by toggling from the solved (all-off) state -- toggling the same
## set of cells again returns to solved, so every scramble is guaranteed
## solvable no matter how many random toggles are applied.
func reset() -> void:
	grid = []
	for r in range(SIZE):
		var row: Array = []
		for c in range(SIZE):
			row.append(false)
		grid.append(row)
	moves = 0

	var attempts := 0
	while true:
		for i in range(20):
			toggle(randi() % SIZE, randi() % SIZE)
		attempts += 1
		if not is_solved() or attempts > 10:
			break
	moves = 0

## Flips (r,c) and its orthogonal neighbors. Does not count as a player move
## by itself -- callers track that separately via `moves`.
func toggle(r: int, c: int) -> void:
	_flip(r, c)
	_flip(r - 1, c)
	_flip(r + 1, c)
	_flip(r, c - 1)
	_flip(r, c + 1)

func _flip(r: int, c: int) -> void:
	if r >= 0 and r < SIZE and c >= 0 and c < SIZE:
		grid[r][c] = not grid[r][c]

## Player-facing move: toggles and increments the move counter.
func press(r: int, c: int) -> void:
	toggle(r, c)
	moves += 1

func is_solved() -> bool:
	for row in grid:
		for v in row:
			if v:
				return false
	return true
