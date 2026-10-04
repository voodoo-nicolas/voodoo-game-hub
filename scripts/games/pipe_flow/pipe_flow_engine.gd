extends RefCounted

## Pipe Flow: a grid of pipe pieces, each turned at random. Tap a piece to
## turn it a quarter clockwise; connect every piece to the pump in the
## middle with no open ends. Pure logic, no Nodes.
##
## Each cell is a 4-bit mask of its openings: N = 1, E = 2, S = 4, W = 8.
## Boards are a random spanning tree of the grid, so every board is
## solvable (and the pieces of the tree are the answer).

const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := [[N, 0, -1, S], [E, 1, 0, W], [S, 0, 1, N], [W, -1, 0, E]]  # bit, dx, dy, opposite

var size: int = 5
var mask: Array = []       # size*size ints, current openings
var solution: Array = []   # the generated tree (one valid answer)
var source: int = 0
var moves: int = 0

func new_board(n: int, rng: RandomNumberGenerator) -> void:
	size = n
	source = (n / 2) * n + n / 2
	solution = []
	solution.resize(n * n)
	solution.fill(0)
	# Randomised Prim: grow the tree from the pump, one random frontier edge at a time.
	var in_tree := {source: true}
	var frontier: Array = []
	_add_frontier(source, in_tree, frontier)
	while not frontier.is_empty():
		var k := rng.randi_range(0, frontier.size() - 1)
		var edge: Array = frontier[k]
		frontier.remove_at(k)
		var to: int = edge[1]
		if in_tree.has(to):
			continue
		var d: Array = DIRS[edge[2]]
		solution[edge[0]] |= d[0]
		solution[to] |= d[3]
		in_tree[to] = true
		_add_frontier(to, in_tree, frontier)
	mask = solution.duplicate()
	# Scramble: turn every piece a random number of times, and make sure
	# the board doesn't start solved.
	for i in mask.size():
		for t in rng.randi_range(0, 3):
			mask[i] = rotated(mask[i])
	if is_solved():
		for i in mask.size():
			if rotated(mask[i]) != mask[i]:
				mask[i] = rotated(mask[i])
				break
	moves = 0

func _add_frontier(cell: int, in_tree: Dictionary, frontier: Array) -> void:
	var x := cell % size
	var y := cell / size
	for k in 4:
		var d: Array = DIRS[k]
		var nx: int = x + d[1]
		var ny: int = y + d[2]
		if nx >= 0 and ny >= 0 and nx < size and ny < size and not in_tree.has(ny * size + nx):
			frontier.append([cell, ny * size + nx, k])

## The mask turned a quarter clockwise (N->E->S->W->N).
static func rotated(m: int) -> int:
	return ((m << 1) | (m >> 3)) & 15

func rotate(cell: int) -> void:
	mask[cell] = rotated(mask[cell])
	moves += 1

## Neighbour of `cell` in direction k (0..3), or -1 off the board.
func neighbour(cell: int, k: int) -> int:
	var d: Array = DIRS[k]
	var nx: int = cell % size + d[1]
	var ny: int = cell / size + d[2]
	if nx < 0 or ny < 0 or nx >= size or ny >= size:
		return -1
	return ny * size + nx

## Cells the water reaches from the pump through matching openings.
func filled() -> Dictionary:
	var seen := {source: true}
	var todo: Array = [source]
	while not todo.is_empty():
		var c: int = todo.pop_back()
		for k in 4:
			var d: Array = DIRS[k]
			if mask[c] & d[0] == 0:
				continue
			var n := neighbour(c, k)
			if n >= 0 and not seen.has(n) and mask[n] & d[3] != 0:
				seen[n] = true
				todo.append(n)
	return seen

## Openings that lead nowhere (off the board or into a closed side).
func leaks(cell: int) -> int:
	var out := 0
	for k in 4:
		var d: Array = DIRS[k]
		if mask[cell] & d[0] == 0:
			continue
		var n := neighbour(cell, k)
		if n < 0 or mask[n] & d[3] == 0:
			out |= d[0]
	return out

func is_solved() -> bool:
	if filled().size() != size * size:
		return false
	for i in mask.size():
		if leaks(i) != 0:
			return false
	return true

## A one-opening piece (a tap / drain at the end of a line).
static func is_end(m: int) -> bool:
	return m in [N, E, S, W]
