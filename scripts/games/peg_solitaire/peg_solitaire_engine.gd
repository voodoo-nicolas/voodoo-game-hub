extends RefCounted

## English peg solitaire: a 33-hole cross, every hole filled but the centre.
## Jump a peg over a neighbour into an empty hole to remove the neighbour.
## Pure logic -- no Nodes -- so it can be tested headlessly.

const SIZE := 7
const INVALID := -1
const EMPTY := 0
const PEG := 1

var grid: Array = []      # SIZE*SIZE ints
var history: Array = []   # [from, over, to] per move, for undo

static func is_hole(r: int, c: int) -> bool:
	if r < 0 or c < 0 or r >= SIZE or c >= SIZE:
		return false
	return (r >= 2 and r <= 4) or (c >= 2 and c <= 4)

func reset() -> void:
	grid.clear()
	history.clear()
	for r in SIZE:
		for c in SIZE:
			grid.append(PEG if is_hole(r, c) else INVALID)
	grid[3 * SIZE + 3] = EMPTY

func at(r: int, c: int) -> int:
	if not is_hole(r, c):
		return INVALID
	return grid[r * SIZE + c]

func peg_count() -> int:
	return grid.count(PEG)

## Destinations (as Vector2i(col,row)) the peg at r,c can jump to.
func targets_from(r: int, c: int) -> Array:
	var out: Array = []
	if at(r, c) != PEG:
		return out
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if at(r + d.y, c + d.x) == PEG and at(r + 2 * d.y, c + 2 * d.x) == EMPTY:
			out.append(Vector2i(c + 2 * d.x, r + 2 * d.y))
	return out

func try_move(r: int, c: int, tr_: int, tc: int) -> bool:
	if not Vector2i(tc, tr_) in targets_from(r, c):
		return false
	var mr := (r + tr_) / 2
	var mc := (c + tc) / 2
	grid[r * SIZE + c] = EMPTY
	grid[mr * SIZE + mc] = EMPTY
	grid[tr_ * SIZE + tc] = PEG
	history.append([r * SIZE + c, mr * SIZE + mc, tr_ * SIZE + tc])
	return true

func undo() -> bool:
	if history.is_empty():
		return false
	var m: Array = history.pop_back()
	grid[m[0]] = PEG
	grid[m[1]] = PEG
	grid[m[2]] = EMPTY
	return true

func has_moves() -> bool:
	for r in SIZE:
		for c in SIZE:
			if not targets_from(r, c).is_empty():
				return true
	return false
