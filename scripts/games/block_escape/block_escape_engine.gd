extends RefCounted

## Block Escape -- pure logic, no Nodes (headless-testable: tools/test_block_escape.gd).
## A board of cells (some are holes), coloured gates on the frame, coloured blocks
## (polyominoes). Slide a block one cell at a time; when it touches the frame where a
## gate of its own colour is at least as wide as the block, it leaves the board.
## A chained block (lock N) can't move until N other blocks have left.
## An "axis" block only slides sideways (H) or up/down (V).

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # = gate side: 0 top, 1 right, 2 bottom, 3 left
const AXIS_ANY := 0
const AXIS_H := 1
const AXIS_V := 2
const EMPTY := -1
const HOLE := -2

var rows: int = 0
var cols: int = 0
var holes := PackedByteArray()  # 1 = no cell there
var gates: Array = []   # {side, start, len, color}
var blocks: Array = []  # {color, cells: Array[Vector2i], pos: Vector2i, axis, lock, gone}
var time_limit: int = 60
var escaped: int = 0
var moves: int = 0

# ---------- setup / save ----------

func setup(r: int, c: int) -> void:
	rows = r
	cols = c
	holes = PackedByteArray()
	holes.resize(r * c)
	gates = []
	blocks = []
	escaped = 0
	moves = 0

func load_puzzle(p: Dictionary) -> bool:
	if not p.has("rows") or not p.has("cols"):
		return false
	setup(int(p.rows), int(p.cols))
	var h: Array = p.get("holes", [])
	for i in mini(h.size(), holes.size()):
		holes[i] = int(h[i])
	for g in p.get("gates", []):
		gates.append({"side": int(g.side), "start": int(g.start), "len": int(g.len), "color": int(g.color)})
	for b in p.get("blocks", []):
		var cells: Array = []
		for cc in b.cells:
			cells.append(Vector2i(int(cc[0]), int(cc[1])))
		blocks.append({"color": int(b.color), "cells": cells, "pos": Vector2i(int(b.pos[0]), int(b.pos[1])),
			"axis": int(b.get("axis", 0)), "lock": int(b.get("lock", 0)), "gone": bool(b.get("gone", false))})
	time_limit = int(p.get("time", 60))
	escaped = int(p.get("escaped", 0))
	moves = int(p.get("moves", 0))
	return true

func to_dict() -> Dictionary:
	var bl: Array = []
	for b in blocks:
		var cells: Array = []
		for cc in b.cells:
			cells.append([cc.x, cc.y])
		bl.append({"color": b.color, "cells": cells, "pos": [b.pos.x, b.pos.y], "axis": b.axis, "lock": b.lock, "gone": b.gone})
	var h: Array = []
	for v in holes:
		h.append(v)
	return {"rows": rows, "cols": cols, "holes": h, "gates": gates.duplicate(true), "blocks": bl,
		"time": time_limit, "escaped": escaped, "moves": moves}

# ---------- queries ----------

func in_board(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows and holes[c.y * cols + c.x] == 0

func occupancy() -> PackedInt32Array:
	var occ := PackedInt32Array()
	occ.resize(rows * cols)
	for i in occ.size():
		occ[i] = HOLE if holes[i] == 1 else EMPTY
	for bi in blocks.size():
		var b: Dictionary = blocks[bi]
		if b.gone:
			continue
		for cc in b.cells:
			var p: Vector2i = b.pos + cc
			occ[p.y * cols + p.x] = bi
	return occ

func block_at(cell: Vector2i) -> int:
	for bi in blocks.size():
		var b: Dictionary = blocks[bi]
		if not b.gone and b.cells.has(cell - b.pos):
			return bi
	return -1

func left() -> int:
	var n := 0
	for b in blocks:
		if not b.gone:
			n += 1
	return n

func solved() -> bool:
	return left() == 0

## Can `cells` sit at `pos`? Cells owned by `me` count as free.
func fits(cells: Array, pos: Vector2i, occ: PackedInt32Array, me: int) -> bool:
	for cc in cells:
		var p: Vector2i = pos + cc
		if p.x < 0 or p.y < 0 or p.x >= cols or p.y >= rows:
			return false
		var o: int = occ[p.y * cols + p.x]
		if o != EMPTY and o != me:
			return false
	return true

func axis_allows(axis: int, dir: int) -> bool:
	if axis == AXIS_H:
		return dir == 1 or dir == 3
	if axis == AXIS_V:
		return dir == 0 or dir == 2
	return true

## The gate index `b` leaves through when sitting at `pos`, or -1.
func exit_gate_at(b: Dictionary, pos: Vector2i, occ: PackedInt32Array, me: int) -> int:
	if int(b.lock) > 0:
		return -1
	for gi in gates.size():
		var g: Dictionary = gates[gi]
		if int(g.color) != int(b.color) or not axis_allows(int(b.axis), int(g.side)):
			continue
		var side: int = g.side
		var lo := 1 << 20
		var hi := -1
		var touch := false
		for cc in b.cells:
			var p: Vector2i = pos + cc
			var along: int = p.x if side == 0 or side == 2 else p.y
			lo = mini(lo, along)
			hi = maxi(hi, along)
			match side:
				0: touch = touch or p.y == 0
				1: touch = touch or p.x == cols - 1
				2: touch = touch or p.y == rows - 1
				3: touch = touch or p.x == 0
		if not touch or lo < int(g.start) or hi > int(g.start) + int(g.len) - 1:
			continue
		if _slide_clear(b.cells, pos, side, occ, me):
			return gi
	return -1

## Nothing between the block and the frame on its way out.
func _slide_clear(cells: Array, pos: Vector2i, side: int, occ: PackedInt32Array, me: int) -> bool:
	var d: Vector2i = DIRS[side]
	for cc in cells:
		var p: Vector2i = pos + cc + d
		while p.x >= 0 and p.y >= 0 and p.x < cols and p.y < rows:
			var o: int = occ[p.y * cols + p.x]
			if o != EMPTY and o != me:
				return false
			p += d
	return true

## Every position `b` can reach, keyed by Vector2i -> steps to the nearest exit
## (multi-source BFS from the exit positions). Empty when it can't get out.
func flood(b: Dictionary, occ: PackedInt32Array, me: int) -> Dictionary:
	var dist := {}
	var queue: Array = []
	var w := 0
	var h := 0
	for cc in b.cells:
		w = maxi(w, cc.x + 1)
		h = maxi(h, cc.y + 1)
	for y in rows - h + 1:
		for x in cols - w + 1:
			var p := Vector2i(x, y)
			# Only a block whose box touches the frame can be at a gate.
			if (x == 0 or y == 0 or x + w == cols or y + h == rows) and fits(b.cells, p, occ, me) 					and exit_gate_at(b, p, occ, me) >= 0:
				dist[p] = 0
				queue.append(p)
	var qi := 0
	while qi < queue.size():
		var p: Vector2i = queue[qi]
		qi += 1
		for di in 4:
			if not axis_allows(int(b.axis), di):
				continue
			var q: Vector2i = p + DIRS[di]
			if dist.has(q) or not fits(b.cells, q, occ, me):
				continue
			dist[q] = int(dist[p]) + 1
			queue.append(q)
	return dist

# ---------- moves ----------

func can_move(bi: int) -> bool:
	return bi >= 0 and bi < blocks.size() and not blocks[bi].gone and int(blocks[bi].lock) == 0

## One cell in direction `dir` (0..3). True when it moved.
func step(bi: int, dir: int) -> bool:
	if not can_move(bi) or not axis_allows(int(blocks[bi].axis), dir):
		return false
	var b: Dictionary = blocks[bi]
	var np: Vector2i = b.pos + DIRS[dir]
	if not fits(b.cells, np, occupancy(), bi):
		return false
	b.pos = np
	moves += 1
	return true

## Gate the block would leave by right now, or -1.
func exit_now(bi: int) -> int:
	if bi < 0 or blocks[bi].gone:
		return -1
	return exit_gate_at(blocks[bi], blocks[bi].pos, occupancy(), bi)

## The block leaves (through a gate, or smashed by the 🔨). Chains count down.
func remove(bi: int) -> void:
	if bi < 0 or blocks[bi].gone:
		return
	blocks[bi].gone = true
	escaped += 1
	for b in blocks:
		if not b.gone and int(b.lock) > 0:
			b.lock = int(b.lock) - 1

## A block that can get out right now without moving any other: [index, steps], or [] when none.
func hint() -> Array:
	var occ := occupancy()
	var best: Array = []
	for bi in blocks.size():
		if not can_move(bi):
			continue
		var fl := flood(blocks[bi], occ, bi)
		if fl.has(blocks[bi].pos):
			var d: int = fl[blocks[bi].pos]
			if best.is_empty() or d < int(best[1]):
				best = [bi, d]
	return best

static func rotate_cells(cells: Array, turns: int) -> Array:
	var out: Array = cells.duplicate()
	for t in turns % 4:
		var nxt: Array = []
		for cc in out:
			nxt.append(Vector2i(-cc.y, cc.x))
		out = nxt
	var mx := 1 << 20
	var my := 1 << 20
	for cc in out:
		mx = mini(mx, cc.x)
		my = mini(my, cc.y)
	var norm: Array = []
	for cc in out:
		norm.append(Vector2i(cc.x - mx, cc.y - my))
	return norm
