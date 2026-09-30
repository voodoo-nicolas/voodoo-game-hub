extends RefCounted

## Sliding 15-puzzle. tiles[i] is the number on square i (row-major), 0 is
## the gap. Tapping any tile in the gap's row or column slides that whole
## line toward the gap, like the physical toy.

const SIZE := 4

var tiles: Array = []
var moves: int = 0

## Scrambles with random legal slides from the solved state, so the puzzle
## is always solvable (half of all random arrangements are not).
func reset() -> void:
	tiles = []
	for i in range(1, SIZE * SIZE):
		tiles.append(i)
	tiles.append(0)
	var last_gap := -1
	for i in range(300):
		var gap: int = tiles.find(0)
		var options: Array = []
		for n in _neighbors(gap):
			if n != last_gap:  # don't immediately undo the previous slide
				options.append(n)
		var pick: int = options.pick_random()
		tiles[gap] = tiles[pick]
		tiles[pick] = 0
		last_gap = gap
	if is_solved():
		reset()
		return
	moves = 0

func _neighbors(i: int) -> Array:
	var r: int = i / SIZE
	var c: int = i % SIZE
	var out: Array = []
	if r > 0: out.append(i - SIZE)
	if r < SIZE - 1: out.append(i + SIZE)
	if c > 0: out.append(i - 1)
	if c < SIZE - 1: out.append(i + 1)
	return out

## Slides every tile between square `i` and the gap one step toward the gap.
## Returns false if `i` isn't in the gap's row or column.
func tap(i: int) -> bool:
	var gap: int = tiles.find(0)
	if i == gap:
		return false
	var gr: int = gap / SIZE
	var gc: int = gap % SIZE
	var r: int = i / SIZE
	var c: int = i % SIZE
	var step: int
	if r == gr:
		step = 1 if c > gc else -1
	elif c == gc:
		step = SIZE if r > gr else -SIZE
	else:
		return false
	var pos := gap
	while pos != i:
		tiles[pos] = tiles[pos + step]
		pos += step
	tiles[i] = 0
	moves += 1
	return true

func is_solved() -> bool:
	for i in range(SIZE * SIZE - 1):
		if tiles[i] != i + 1:
			return false
	return tiles[SIZE * SIZE - 1] == 0
