extends RefCounted

## Sea Battle: you and the computer each hide a fleet on a 10×10 grid and take
## turns firing one shot. Sink the whole enemy fleet first. Pure logic.

const SIZE := 10
const SHIPS := [5, 4, 3, 3, 2]
const NONE := 0
const MISS := 1
const HIT := 2

## Per side (0 = player, 1 = computer):
var ship_at: Array = [[], []]    # SIZE*SIZE -> ship index or -1
var ships: Array = [[], []]      # [{cells: Array, hits: int}]
var shots: Array = [[], []]      # shots fired AT this side's grid
var winner: int = -1

func new_game() -> void:
	winner = -1
	for side in 2:
		random_fleet(side)
		shots[side] = []
		shots[side].resize(SIZE * SIZE)
		shots[side].fill(NONE)

func random_fleet(side: int) -> void:
	while true:
		if _try_fleet(side):
			return

func _try_fleet(side: int) -> bool:
	var grid: Array = []
	grid.resize(SIZE * SIZE)
	grid.fill(-1)
	var list: Array = []
	for si in SHIPS.size():
		var length: int = SHIPS[si]
		var placed := false
		for attempt in 200:
			var horizontal := randi() % 2 == 0
			var r := randi() % (SIZE - (0 if horizontal else length - 1))
			var c := randi() % (SIZE - (length - 1 if horizontal else 0))
			var cells: Array = []
			var ok := true
			for k in length:
				var idx := (r * SIZE + c + k) if horizontal else ((r + k) * SIZE + c)
				if grid[idx] != -1 or _touches(grid, idx):
					ok = false
					break
				cells.append(idx)
			if ok:
				for idx in cells:
					grid[idx] = si
				list.append({"cells": cells, "hits": 0})
				placed = true
				break
		if not placed:
			return false
	ship_at[side] = grid
	ships[side] = list
	return true

## Ships never touch each other, not even at the corners.
static func _touches(grid: Array, idx: int) -> bool:
	var r := idx / SIZE
	var c := idx % SIZE
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			var rr: int = r + dr
			var cc: int = c + dc
			if rr >= 0 and cc >= 0 and rr < SIZE and cc < SIZE and grid[rr * SIZE + cc] != -1:
				return true
	return false

## Fire at `side`'s grid. Returns {valid, hit, sunk (ship length or 0), win}.
func fire(side: int, idx: int) -> Dictionary:
	var result := {"valid": false, "hit": false, "sunk": 0, "win": false}
	if winner != -1 or shots[side][idx] != NONE:
		return result
	result.valid = true
	var si: int = ship_at[side][idx]
	if si == -1:
		shots[side][idx] = MISS
		return result
	shots[side][idx] = HIT
	result.hit = true
	ships[side][si].hits += 1
	if ships[side][si].hits == ships[side][si].cells.size():
		result.sunk = ships[side][si].cells.size()
		# the water around a sunk ship can't hold anything: mark it
		for cell in ships[side][si].cells:
			for nb in _around(cell):
				if shots[side][nb] == NONE:
					shots[side][nb] = MISS
	if ships_left(side) == 0:
		winner = 1 - side
		result.win = true
	return result

func ships_left(side: int) -> int:
	var n := 0
	for s in ships[side]:
		if s.hits < s.cells.size():
			n += 1
	return n

func is_sunk_cell(side: int, idx: int) -> bool:
	var si: int = ship_at[side][idx]
	return si != -1 and ships[side][si].hits == ships[side][si].cells.size()

static func _around(idx: int) -> Array:
	var out: Array = []
	var r := idx / SIZE
	var c := idx % SIZE
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			var rr: int = r + dr
			var cc: int = c + dc
			if rr >= 0 and cc >= 0 and rr < SIZE and cc < SIZE:
				out.append(rr * SIZE + cc)
	return out

## Computer's aim at the player's grid: finish off wounded ships along their
## line, otherwise hunt on a checkerboard pattern.
func cpu_pick() -> int:
	var grid: Array = shots[0]
	var wounded: Array = []
	for i in SIZE * SIZE:
		if grid[i] == HIT and not is_sunk_cell(0, i):
			wounded.append(i)
	if not wounded.is_empty():
		var candidates: Array = []
		if wounded.size() >= 2:
			var same_row := true
			var same_col := true
			for i in wounded:
				same_row = same_row and i / SIZE == wounded[0] / SIZE
				same_col = same_col and i % SIZE == wounded[0] % SIZE
			var lo: int = wounded.min()
			var hi: int = wounded.max()
			if same_row:
				if lo % SIZE > 0: candidates.append(lo - 1)
				if hi % SIZE < SIZE - 1: candidates.append(hi + 1)
			elif same_col:
				if lo >= SIZE: candidates.append(lo - SIZE)
				if hi < SIZE * (SIZE - 1): candidates.append(hi + SIZE)
		candidates = candidates.filter(func(i): return grid[i] == NONE)
		if candidates.is_empty():
			for i in wounded:
				var r: int = i / SIZE
				var c: int = i % SIZE
				if r > 0: candidates.append(i - SIZE)
				if r < SIZE - 1: candidates.append(i + SIZE)
				if c > 0: candidates.append(i - 1)
				if c < SIZE - 1: candidates.append(i + 1)
			candidates = candidates.filter(func(i): return grid[i] == NONE)
		if not candidates.is_empty():
			return candidates[randi() % candidates.size()]
	var hunt: Array = []
	var any: Array = []
	for i in SIZE * SIZE:
		if grid[i] == NONE:
			any.append(i)
			if (i / SIZE + i % SIZE) % 2 == 0:
				hunt.append(i)
	var pool := hunt if not hunt.is_empty() else any
	return pool[randi() % pool.size()]
