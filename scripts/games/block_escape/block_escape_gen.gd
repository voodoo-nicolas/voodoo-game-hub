extends RefCounted

## Block Escape level generator. Same level + seed = same board on every phone, so
## the 300 Levels need no data file.
##
## Every board is solvable by construction: blocks are placed in REVERSE exit order.
## Each new block must be able to reach a gate of its colour past the blocks placed
## before it (those leave after it, so they are still there). Blocks placed after it
## leave first, so they never matter for it. Chains: a block placed k-th from the end
## has at most k blocks leaving before it, so its lock is at most that.

const Engine_ = preload("res://scripts/games/block_escape/block_escape_engine.gd")

const LEVELS := 300

## [name, cells, first level it appears]
const SHAPES := [
	["dot", [Vector2i(0, 0)], 1],
	["bar2", [Vector2i(0, 0), Vector2i(1, 0)], 1],
	["square", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], 4],
	["bar3", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 8],
	["corner", [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)], 16],
	["ell", [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)], 35],
	["tee", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], 50],
	["slab", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)], 70],
	["hook", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)], 110],
]

## [CHANGED 2026-11-20, owner: "levels 1-3 easy, then significantly harder right away"]
## Levels 1-3 stay the tutorial. From level 4 the generator plays as if it were level 40,
## climbing to 300 by the last level, so the old 4x4 / 2-colour stretch is gone.
static func effective(level: int) -> int:
	if level <= 3:
		return level
	return clampi(40 + int(round(float(level - 4) * 260.0 / float(LEVELS - 4))), 40, LEVELS)

## 0..1 over the 300 levels, with a small saw-tooth: every 10th level is a little
## harder, the one after it a breather. `level` here is already effective().
static func difficulty(level: int) -> float:
	var t := clampf(float(level - 1) / 220.0, 0.0, 1.0)
	var saw := float((level - 1) % 10) / 9.0
	return clampf(t * (0.88 + 0.12 * saw) + (0.04 if level % 10 == 0 else 0.0), 0.0, 1.0)

## `fast`: one try and fewer placement attempts (boards made on the phone: Daily, Zen).
static func generate(level: int, seed_val: int, fast: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var best: Dictionary = {}
	# A few tries; keep the fullest board (rare dead ends leave a sparse one).
	for attempt in (1 if fast else 3):
		var p := _try(effective(level), rng, fast)
		if best.is_empty() or p.blocks.size() > best.blocks.size():
			best = p
		if p.get("full", false):
			break
	best.erase("full")
	best.level = level
	return best

static func _try(level: int, rng: RandomNumberGenerator, fast: bool) -> Dictionary:
	var d := difficulty(level)
	var e := Engine_.new()
	# var n := 4 + mini(4, (level + 10) / 35)          # 4x4 at level 1 .. 8 wide from level 130
	# 4x4 tutorial (levels 1-3), then 6 wide at once, 7 from effective 120, 8 from 220.
	var n := 4 if level <= 3 else 6 + mini(2, maxi(0, level - 20) / 100)
	var rows := n + (1 if level > 45 and rng.randf() < 0.5 else 0)
	e.setup(rows, n)
	var colours := clampi(2 + level / 18, 2, 8)
	if level <= 3:
		colours = 2
	_holes(e, level, rng)
	_gates(e, colours, level, rng)
	var used_colours: Array = []
	for g in e.gates:
		if not used_colours.has(g.color):
			used_colours.append(g.color)

	var free := 0
	for v in e.holes:
		if v == 0:
			free += 1
	# var fill := lerpf(0.45, 0.78, d)
	var fill := lerpf(0.45, 0.78, d) if level <= 3 else lerpf(0.66, 0.9, d)  # denser boards from level 4
	var target := int(round(free * fill))
	if level <= 2:
		target = mini(target, 4 + level)
	var filled := 0
	# var lock_p := 0.0 if level < 20 else lerpf(0.10, 0.30, d)
	# var axis_p := 0.0 if level < 40 else lerpf(0.12, 0.30, d)
	var lock_p := 0.0 if level < 20 else lerpf(0.18, 0.40, d)
	var axis_p := 0.0 if level < 40 else lerpf(0.20, 0.40, d)
	var pool: Array = []
	for s in SHAPES:
		if level >= int(s[2]):
			pool.append(s[1])
	var fails := 0
	while filled < target and fails < (30 if fast else 40 + int(d * 80.0)):
		var shape: Array = Engine_.rotate_cells(pool[rng.randi() % pool.size()], rng.randi() % 4)
		if filled + shape.size() > target + 1:
			shape = [Vector2i(0, 0), Vector2i(1, 0)] if target - filled >= 2 else [Vector2i(0, 0)]
		var axis := Engine_.AXIS_ANY
		if rng.randf() < axis_p:
			axis = Engine_.AXIS_H if rng.randf() < 0.5 else Engine_.AXIS_V
		var b := {"color": used_colours[rng.randi() % used_colours.size()], "cells": shape,
			"pos": Vector2i.ZERO, "axis": axis, "lock": 0, "gone": false}
		var occ := e.occupancy()
		var fl := e.flood(b, occ, -1)
		var cands: Array = []
		for p in fl:
			if int(fl[p]) >= 1:
				cands.append(p)
		if cands.is_empty():
			fails += 1
			continue
		# Harder levels prefer starts far from the gate (more of the board in the way).
		var pick: Vector2i = cands[rng.randi() % cands.size()]
		var tries := 1 + int(d * 5.0)
		for i in tries:
			var q: Vector2i = cands[rng.randi() % cands.size()]
			if int(fl[q]) > int(fl[pick]):
				pick = q
		b.pos = pick
		e.blocks.append(b)
		filled += shape.size()
	# Chains (see the header for why this stays solvable).
	var count := e.blocks.size()
	for k in count:
		var after := count - 1 - k
		if after >= 2 and rng.randf() < lock_p:
			e.blocks[k].lock = rng.randi_range(1, mini(after, 2 + int(d * 5.0)))
	# Shuffle the list so its order gives nothing away (locks move with their block).
	for i in range(count - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = e.blocks[i]
		e.blocks[i] = e.blocks[j]
		e.blocks[j] = tmp
	e.time_limit = time_for(level, e.blocks.size())
	var out := e.to_dict()
	out.full = filled >= target
	return out

## Seconds on the clock: generous early, tight late. Rounded up to 5 s.
static func time_for(level: int, block_count: int) -> int:
	var d := difficulty(level)
	# var per := lerpf(9.0, 4.6, d)
	var per := lerpf(9.0, 4.6, d) if level <= 3 else lerpf(6.5, 3.6, d)  # tighter clock from level 4
	var s := 15.0 + per * block_count
	return int(ceil(s / 5.0)) * 5

## Holes: cut corners and a few inner cells from level 12.
static func _holes(e, level: int, rng: RandomNumberGenerator) -> void:
	if level < 12:
		return
	var corners := [Vector2i(0, 0), Vector2i(e.cols - 1, 0), Vector2i(0, e.rows - 1), Vector2i(e.cols - 1, e.rows - 1)]
	for c in corners:
		if rng.randf() < 0.35:
			e.holes[c.y * e.cols + c.x] = 1
	var inner := rng.randi_range(0, mini(3, level / 70))
	for i in inner:
		var x := rng.randi_range(1, e.cols - 2)
		var y := rng.randi_range(1, e.rows - 2)
		e.holes[y * e.cols + x] = 1

## Gates: at least one per colour, a few spares on bigger boards; 1 frame cell between gates.
static func _gates(e, colours: int, level: int, rng: RandomNumberGenerator) -> void:
	var want := colours + (0 if level < 25 else rng.randi_range(0, 2))
	var taken := {}  # "side:i" -> true (gate cells plus a gap)
	var made := 0
	var guard := 0
	while made < want and guard < 400:
		guard += 1
		var side := rng.randi() % 4
		var edge: int = e.cols if side == 0 or side == 2 else e.rows
		var glen := 3 if rng.randf() < 0.5 else 2
		if level <= 3:
			glen = 3
		glen = mini(glen, edge)
		var start := rng.randi_range(0, edge - glen)
		var ok := true
		for i in range(start - 1, start + glen + 1):
			if taken.has("%d:%d" % [side, i]):
				ok = false
		for i in range(start, start + glen):
			var cell: Vector2i
			match side:
				0: cell = Vector2i(i, 0)
				1: cell = Vector2i(e.cols - 1, i)
				2: cell = Vector2i(i, e.rows - 1)
				_: cell = Vector2i(0, i)
			if not e.in_board(cell):
				ok = false
		if not ok:
			continue
		for i in range(start, start + glen):
			taken["%d:%d" % [side, i]] = true
		var colour: int = made if made < colours else rng.randi() % colours
		e.gates.append({"side": side, "start": start, "len": glen, "color": colour})
		made += 1

## The seed of Levels mode level `level` (the tool and the game must agree).
static func seed_for(level: int) -> int:
	return level * 7919 + 17
