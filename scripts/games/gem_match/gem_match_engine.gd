extends RefCounted

## Gem Match: swap two neighbouring gems to line up 3 or more of a kind,
## against the clock. Pure logic, no Nodes -- the game scene animates.
##
## - Time: the game starts with START_TIME seconds; every match adds time
##   (3 in a row +2 s, 4 +4 s, 5 or more +6 s).
## - Speed multiplier: a swap made within FAST_WINDOW seconds of the last
##   successful one raises the multiplier (up to MAX_MULT); a slow one resets it.
## - A match of 4 leaves a BOMB where the swap happened. A bomb is a wild
##   card: it matches with any 2 (or more) gems of one kind, and when it goes
##   off it clears the 3x3 square around it (setting off any bomb in there).
## - A match of 5 or more clears every gem of that kind on the board.
## - Cleared gems let the ones above fall; falls that line up make chains,
##   and every link of a chain scores more.

const SIZE := 8
const KINDS := 6
const BOMB := 6            # a cell value; not one of the KINDS
const EMPTY := -1
const START_TIME := 60.0
const TIME_BONUS := {3: 2.0, 4: 4.0, 5: 6.0}
const FAST_WINDOW := 3.0
const MAX_MULT := 8

var grid: Array = []      # SIZE*SIZE: 0..KINDS-1, BOMB or EMPTY
var score: int = 0
var time_left: float = START_TIME
var chain: int = 0
var multiplier: int = 1
var best_chain: int = 0
var _since_last_match: float = 999.0
## Where the last swap landed: a match of 4 drops its bomb there.
var _swap_cells: Array = []

func reset() -> void:
	score = 0
	time_left = START_TIME
	chain = 0
	multiplier = 1
	best_chain = 0
	_since_last_match = 999.0
	_swap_cells = []
	_fill_fresh()

## The clock and the multiplier window run on real time.
func tick(delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)
	_since_last_match += delta

func multiplier_window() -> float:
	return clampf(1.0 - _since_last_match / FAST_WINDOW, 0.0, 1.0)

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

# ---------- finding matches ----------

## Runs of 3+ along rows and columns. A bomb counts as any kind, but a run
## needs at least two real gems of one kind (or is all bombs).
## Returns [{cells: Array, kind: int}] (kind BOMB for an all-bomb run).
func _runs() -> Array:
	var out: Array = []
	for line in 2:
		for a in SIZE:
			var b := 0
			while b < SIZE:
				var run: Array = []
				var kind := -1
				var k := b
				while k < SIZE:
					var i: int = a * SIZE + k if line == 0 else k * SIZE + a
					var v: int = grid[i]
					if v == EMPTY:
						break
					if v != BOMB:
						if kind == -1:
							kind = v
						elif v != kind:
							break
					run.append(i)
					k += 1
				var real := 0
				for i in run:
					if grid[i] != BOMB:
						real += 1
				if run.size() >= 3 and (real >= 2 or real == 0):
					out.append({"cells": run, "kind": kind if kind >= 0 else BOMB})
					# Bombs at the end may also start the next run (R R B G G).
					var trailing := 0
					while trailing < run.size() and grid[run[run.size() - 1 - trailing]] == BOMB:
						trailing += 1
					b = k - trailing if trailing < run.size() else k
				else:
					# A run cut short by a different kind may start again at
					# the first cell of that kind (bombs before it included).
					b += 1
	return out

## Overlapping runs of one kind (L and T shapes) merge into one group.
## Returns [{cells: Array, kind: int}].
func find_groups() -> Array:
	var runs := _runs()
	var groups: Array = []
	for r in runs:
		var merged := false
		for g in groups:
			if g.kind != r.kind:
				continue
			for c in r.cells:
				if g.cells.has(c):
					merged = true
					break
			if merged:
				for c in r.cells:
					if not g.cells.has(c):
						g.cells.append(c)
				break
		if not merged:
			groups.append({"cells": r.cells.duplicate(), "kind": r.kind})
	return groups

func find_matches() -> Array:
	var hits := {}
	for g in find_groups():
		for c in g.cells:
			hits[c] = true
	return hits.keys()

func _swap(a: int, b: int) -> void:
	var t = grid[a]
	grid[a] = grid[b]
	grid[b] = t

## Swaps if it makes a match. Returns true if it did. Updates the speed
## multiplier: quick matches raise it, slow ones start again at x1.
func try_swap(a: int, b: int) -> bool:
	if time_left <= 0.0 or not adjacent(a, b):
		return false
	_swap(a, b)
	if find_matches().is_empty():
		_swap(a, b)
		return false
	multiplier = mini(multiplier + 1, MAX_MULT) if _since_last_match <= FAST_WINDOW else 1
	_since_last_match = 0.0
	chain = 0
	_swap_cells = [a, b]
	return true

# ---------- clearing ----------

## Clears the current matches (with bombs and colour clears) and scores them.
## Returns {cleared: Array of cells, bombs: Array of cells that exploded,
## new_bombs: Array of cells, color_clears: Array of kinds, time: float} --
## empty `cleared` if nothing matched.
func clear_matches() -> Dictionary:
	var result := {"cleared": [], "bombs": [], "new_bombs": [], "color_clears": [], "time": 0.0}
	var groups := find_groups()
	if groups.is_empty():
		return result
	chain += 1
	best_chain = maxi(best_chain, chain)
	var gone := {}
	var keep_as_bomb := {}
	for g in groups:
		var n: int = g.cells.size()
		var bonus: float = TIME_BONUS[mini(n, 5)]
		result.time += bonus
		for c in g.cells:
			gone[c] = true
		if n >= 5 and g.kind != BOMB:
			result.color_clears.append(g.kind)
			for i in SIZE * SIZE:
				if grid[i] == g.kind:
					gone[i] = true
		elif n == 4:
			# The bomb appears where the player swapped, if that's in the group.
			var at: int = g.cells[1]
			for c in _swap_cells:
				if g.cells.has(c):
					at = c
			keep_as_bomb[at] = true
	# Bombs caught in anything that clears go off (and set each other off).
	var pending: Array = []
	for c in gone:
		if grid[c] == BOMB:
			pending.append(c)
	var exploded := {}
	while not pending.is_empty():
		var bc: int = pending.pop_back()
		if exploded.has(bc):
			continue
		exploded[bc] = true
		var br := bc / SIZE
		var bcol := bc % SIZE
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var r: int = br + dr
				var c: int = bcol + dc
				if r < 0 or c < 0 or r >= SIZE or c >= SIZE:
					continue
				var i := r * SIZE + c
				gone[i] = true
				if grid[i] == BOMB and not exploded.has(i):
					pending.append(i)
	result.bombs = exploded.keys()
	var count := 0
	for c in gone:
		if keep_as_bomb.has(c):
			continue
		if grid[c] != EMPTY:
			count += 1
		grid[c] = EMPTY
		result.cleared.append(c)
	for c in keep_as_bomb:
		grid[c] = BOMB
		result.new_bombs.append(c)
	score += count * 10 * chain * multiplier + result.color_clears.size() * 200 * multiplier \
			+ result.bombs.size() * 50 * multiplier
	time_left += result.time
	_swap_cells = []  # later links of the chain drop bombs mid-group
	return result

## Drops gems into gaps and fills the top with new ones. Returns, per
## cell, how many rows its gem fell (new gems come from above the board),
## so the scene can animate the fall.
func collapse() -> Array:
	var fell: Array = []
	fell.resize(SIZE * SIZE)
	fell.fill(0)
	for c in SIZE:
		var write := SIZE - 1
		for r in range(SIZE - 1, -1, -1):
			var k: int = grid[r * SIZE + c]
			if k != EMPTY:
				grid[write * SIZE + c] = k
				fell[write * SIZE + c] = write - r
				write -= 1
		var new_count := write + 1
		for r in range(write, -1, -1):
			grid[r * SIZE + c] = randi() % KINDS
			fell[r * SIZE + c] = new_count
	return fell

func has_moves() -> bool:
	return not hint().is_empty()

func reshuffle() -> void:
	# Keep the bombs the player earned; shuffle everything else.
	var bombs := 0
	for v in grid:
		if v == BOMB:
			bombs += 1
	_fill_fresh()
	var cells := range(SIZE * SIZE)
	cells.shuffle()
	for i in mini(bombs, cells.size()):
		grid[cells[i]] = BOMB

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
