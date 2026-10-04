extends RefCounted

## Flood It: the top-left cell starts a flood. Pick a colour and the flood
## takes it, swallowing every touching cell of that colour. Make the whole
## board one colour within the move limit. Pure logic, no Nodes.

var size: int = 12
var colors: int = 6
var grid: Array = []      # size*size colour indices
var moves: int = 0
var limit: int = 22

func new_board(n: int, n_colors: int, rng: RandomNumberGenerator) -> void:
	size = n
	colors = n_colors
	grid = []
	for i in n * n:
		grid.append(rng.randi_range(0, n_colors - 1))
	moves = 0
	# The limit: what a greedy player needs, with a little slack.
	limit = greedy_moves() + maxi(1, n / 6)

func flooded() -> Dictionary:
	var c: int = grid[0]
	var seen := {0: true}
	var todo: Array = [0]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		for j in _neighbours(i):
			if not seen.has(j) and grid[j] == c:
				seen[j] = true
				todo.append(j)
	return seen

func _neighbours(i: int) -> Array:
	var out: Array = []
	var x := i % size
	var y := i / size
	if x > 0:
		out.append(i - 1)
	if x < size - 1:
		out.append(i + 1)
	if y > 0:
		out.append(i - size)
	if y < size - 1:
		out.append(i + size)
	return out

## Recolours the flood; false if that colour is already the flood's.
func pick(c: int) -> bool:
	if c == grid[0] or won():
		return false
	for i in flooded():
		grid[i] = c
	moves += 1
	return true

func won() -> bool:
	var c: int = grid[0]
	for v in grid:
		if v != c:
			return false
	return true

func lost() -> bool:
	return not won() and moves >= limit

## How many cells picking colour c would flood (for hints and the greedy count).
func gain(c: int) -> int:
	var saved := grid.duplicate()
	for i in flooded():
		grid[i] = c
	var n := flooded().size()
	grid = saved
	return n

func greedy_moves() -> int:
	var saved := grid.duplicate()
	var n := 0
	while not won() and n < 200:
		var best := -1
		var best_gain := -1
		for c in colors:
			if c == grid[0]:
				continue
			var g := gain(c)
			if g > best_gain:
				best_gain = g
				best = c
		for i in flooded():
			grid[i] = best
		n += 1
	grid = saved
	return n
