extends RefCounted

## Teaching hints: finds the next logical step on the board and describes
## it, without filling anything in. Pure logic (no nodes), so it can be
## tested headlessly. Text is built by the game (it needs tr()).
##
## Steps, easiest first: a hidden single (a number with only one place in a
## box / row / column), a naked single (a square with only one number left),
## then two elimination techniques -- pointing (a number locked to one row
## or column inside a box) and naked pairs. Eliminations only cross numbers
## out; the game keeps them (`elim`) so the next hint can build on them.
## Last resort: the square with the fewest possible numbers.

const KIND_NAMES := ["row", "column", "box"]

## The 27 units as arrays of cell indices (r * 9 + c): rows, columns, boxes.
static func units() -> Array:
	var out := []
	for r in range(9):
		var u := []
		for c in range(9):
			u.append(r * 9 + c)
		out.append(u)
	for c in range(9):
		var u := []
		for r in range(9):
			u.append(r * 9 + c)
		out.append(u)
	for b in range(9):
		var u := []
		var br := int(b / 3) * 3
		var bc := (b % 3) * 3
		for i in range(9):
			u.append((br + int(i / 3)) * 9 + bc + i % 3)
		out.append(u)
	return out

static func unit_kind(ui: int) -> String:
	return KIND_NAMES[int(ui / 9)]

## Candidates per cell (index -> Array of digits), 0-valued cells only.
## `grid` is a flat Array of 81 ints (0 = empty); `elim` holds "idx:d" keys
## of candidates already crossed out by earlier hints.
static func candidates(grid: Array, elim: Dictionary) -> Dictionary:
	var out := {}
	for i in range(81):
		if grid[i] != 0:
			continue
		var r := int(i / 9)
		var c := i % 9
		var used := {}
		for k in range(9):
			used[grid[r * 9 + k]] = true
			used[grid[k * 9 + c]] = true
		var br := int(r / 3) * 3
		var bc := int(c / 3) * 3
		for k in range(9):
			used[grid[(br + int(k / 3)) * 9 + bc + k % 3]] = true
		var list := []
		for d in range(1, 10):
			if not used.has(d) and not elim.has("%d:%d" % [i, d]):
				list.append(d)
		out[i] = list
	return out

## Digits already placed in the row, column and box of cell i, sorted.
static func seen_digits(grid: Array, i: int) -> Array:
	var r := int(i / 9)
	var c := i % 9
	var br := int(r / 3) * 3
	var bc := int(c / 3) * 3
	var seen := {}
	for k in range(9):
		for j in [r * 9 + k, k * 9 + c, (br + int(k / 3)) * 9 + bc + k % 3]:
			if grid[j] != 0:
				seen[grid[j]] = true
	var out := seen.keys()
	out.sort()
	return out

## The next step. Returns {} when the board is full. Keys:
##   kind   "hidden" | "naked" | "pointing" | "pair" | "fewest"
##   cell   the target square (hidden, naked, fewest), else -1
##   cells  squares that make the point (pointing / pair)
##   unit   the unit's cell indices; unit_kind "row" | "column" | "box"
##   digit / digits, seen (naked), line_kind (pointing)
##   elim   Array of "idx:d" keys this step crosses out (pointing / pair)
## `prefer` (cell index or -1): if that square is a single, it wins.
static func find(grid: Array, elim: Dictionary, prefer: int = -1) -> Dictionary:
	var cand := candidates(grid, elim)
	if cand.is_empty():
		return {}
	var all_units := units()

	if prefer >= 0 and cand.has(prefer):
		var h := _hidden_single(cand, all_units, prefer)
		if not h.is_empty():
			return h
		if cand[prefer].size() == 1:
			return _naked(grid, cand, prefer)

	# Boxes first: "where does the 5 go in this box" is the easiest scan.
	for order in [[18, 27], [0, 18]]:
		for ui in range(order[0], order[1]):
			var h := _hidden_in_unit(cand, all_units, ui)
			if not h.is_empty():
				return h
	for i in cand:
		if cand[i].size() == 1:
			return _naked(grid, cand, i)

	var p := _pointing(cand, all_units)
	if not p.is_empty():
		return p
	p = _naked_pair(cand, all_units)
	if not p.is_empty():
		return p

	var best := -1
	for i in cand:
		if best < 0 or cand[i].size() < cand[best].size():
			best = i
	return {"kind": "fewest", "cell": best, "cells": [], "unit": [],
		"unit_kind": "", "digit": 0, "digits": cand[best], "elim": []}

static func _hidden_single(cand: Dictionary, all_units: Array, cell: int) -> Dictionary:
	var r := int(cell / 9)
	var c := cell % 9
	var b := int(r / 3) * 3 + int(c / 3)
	for ui in [18 + b, r, 9 + c]:
		var h := _hidden_in_unit(cand, all_units, ui)
		if not h.is_empty() and h.cell == cell:
			return h
	return {}

static func _hidden_in_unit(cand: Dictionary, all_units: Array, ui: int) -> Dictionary:
	var unit: Array = all_units[ui]
	for d in range(1, 10):
		var spots := []
		for i in unit:
			if cand.has(i) and d in cand[i]:
				spots.append(i)
		if spots.size() == 1:
			return {"kind": "hidden", "cell": spots[0], "cells": [], "unit": unit,
				"unit_kind": unit_kind(ui), "digit": d, "digits": [d], "elim": []}
	return {}

static func _naked(grid: Array, cand: Dictionary, i: int) -> Dictionary:
	return {"kind": "naked", "cell": i, "cells": [], "unit": [], "unit_kind": "",
		"digit": cand[i][0], "digits": cand[i], "seen": seen_digits(grid, i), "elim": []}

## A digit whose spots in a box all share one row (or column): it can't go
## anywhere else in that row. Only returned if it crosses something out.
static func _pointing(cand: Dictionary, all_units: Array) -> Dictionary:
	for b in range(9):
		var box: Array = all_units[18 + b]
		for d in range(1, 10):
			var spots := []
			for i in box:
				if cand.has(i) and d in cand[i]:
					spots.append(i)
			if spots.size() < 2:
				continue
			for line in ["row", "column"]:
				var k := _line_of(spots[0], line)
				var same := true
				for i in spots:
					if _line_of(i, line) != k:
						same = false
				if not same:
					continue
				var unit: Array = all_units[k if line == "row" else 9 + k]
				var out := []
				for i in unit:
					if not (i in box) and cand.has(i) and d in cand[i]:
						out.append("%d:%d" % [i, d])
				if not out.is_empty():
					return {"kind": "pointing", "cell": -1, "cells": spots, "unit": box,
						"unit_kind": "box", "line": unit, "line_kind": line,
						"digit": d, "digits": [d], "elim": out}
	return {}

static func _line_of(i: int, line: String) -> int:
	return int(i / 9) if line == "row" else i % 9

## Two squares in a unit that can only be the same two numbers: those
## numbers are used up, so the unit's other squares can't be either.
static func _naked_pair(cand: Dictionary, all_units: Array) -> Dictionary:
	for ui in range(27):
		var unit: Array = all_units[ui]
		var twos := []
		for i in unit:
			if cand.has(i) and cand[i].size() == 2:
				twos.append(i)
		for a in range(twos.size()):
			for b in range(a + 1, twos.size()):
				var pa: Array = cand[twos[a]]
				if pa != cand[twos[b]]:
					continue
				var out := []
				for i in unit:
					if i == twos[a] or i == twos[b] or not cand.has(i):
						continue
					for d in pa:
						if d in cand[i]:
							out.append("%d:%d" % [i, d])
				if not out.is_empty():
					return {"kind": "pair", "cell": -1, "cells": [twos[a], twos[b]],
						"unit": unit, "unit_kind": unit_kind(ui), "digit": pa[0],
						"digits": pa, "elim": out}
	return {}
