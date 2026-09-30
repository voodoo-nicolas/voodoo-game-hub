extends RefCounted

## Tower of Hanoi: move the whole stack to the right-hand peg, one disc at a
## time, never a bigger disc on a smaller one. Pure logic, no Nodes.

const MIN_DISCS := 3
const MAX_DISCS := 8

var discs: int = 4
var pegs: Array = [[], [], []]   # bottom -> top, disc sizes 1..discs
var moves: int = 0

func reset(n: int = discs) -> void:
	discs = clampi(n, MIN_DISCS, MAX_DISCS)
	pegs = [[], [], []]
	for s in range(discs, 0, -1):
		pegs[0].append(s)
	moves = 0

func optimal_moves() -> int:
	return (1 << discs) - 1

func can_move(from: int, to: int) -> bool:
	if from == to or pegs[from].is_empty():
		return false
	return pegs[to].is_empty() or pegs[to].back() > pegs[from].back()

func move(from: int, to: int) -> bool:
	if not can_move(from, to):
		return false
	pegs[to].append(pegs[from].pop_back())
	moves += 1
	return true

func is_solved() -> bool:
	return pegs[2].size() == discs
