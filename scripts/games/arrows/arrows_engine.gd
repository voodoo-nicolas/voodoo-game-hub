extends RefCounted

## Arrows -- pure logic (no Nodes, tested headlessly by tools/arrows_test.gd).
## The board is a cols x rows grid. Each arrow is a chain of cells, tail first, head last;
## it points the way its last step goes. Tapping an arrow slides it out along that way:
## it leaves when nothing stands between its head and the edge of the grid. If another
## arrow is in the way, it bumps, turns red and costs a heart.

const HEARTS := 3
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var cols: int = 0
var rows: int = 0
var mask: PackedByteArray = PackedByteArray()  # 1 = part of the picture (dots are drawn there)
var arrows: Array = []    # [{cells: Array[Vector2i], dir: Vector2i, alive: bool, red: bool}]
var occ: PackedInt32Array = PackedInt32Array()  # arrow index per cell, -1 = empty
var hearts: int = HEARTS
var mistakes: int = 0
var id: String = ""
var shape: String = "rect"

func load_puzzle(p: Dictionary) -> void:
	cols = int(p.cols)
	rows = int(p.rows)
	id = str(p.get("id", ""))
	shape = str(p.get("shape", "rect"))
	mask = PackedByteArray()
	mask.resize(cols * rows)
	var m: String = str(p.get("mask", ""))
	for i in cols * rows:
		mask[i] = 1 if m.length() != cols * rows or m[i] == "1" else 0
	arrows = []
	for a in p.arrows:
		var cells: Array = []
		for k in range(0, a.size(), 2):
			cells.append(Vector2i(int(a[k]), int(a[k + 1])))
		var n: int = cells.size()
		arrows.append({"cells": cells, "dir": cells[n - 1] - cells[n - 2], "alive": true, "red": false})
	hearts = HEARTS
	mistakes = 0
	_rebuild_occ()

## The puzzle as data (cells flattened x, y, x, y ...), for saves and level files.
func puzzle_dict() -> Dictionary:
	var list: Array = []
	for a in arrows:
		var flat: Array = []
		for c in a.cells:
			flat.append(c.x)
			flat.append(c.y)
		list.append(flat)
	var m := ""
	for i in mask.size():
		m += "1" if mask[i] else "0"
	return {"cols": cols, "rows": rows, "arrows": list, "mask": m, "id": id, "shape": shape}

func to_dict() -> Dictionary:
	var d := puzzle_dict()
	var alive: Array = []
	var red: Array = []
	for a in arrows:
		alive.append(1 if a.alive else 0)
		red.append(1 if a.red else 0)
	d["alive"] = alive
	d["red"] = red
	d["hearts"] = hearts
	d["mistakes"] = mistakes
	return d

func from_dict(d: Dictionary) -> bool:
	if not d.has("arrows") or not d.has("cols"):
		return false
	load_puzzle(d)
	var alive: Array = d.get("alive", [])
	var red: Array = d.get("red", [])
	for i in arrows.size():
		if i < alive.size():
			arrows[i].alive = int(alive[i]) == 1
		if i < red.size():
			arrows[i].red = int(red[i]) == 1
	hearts = int(d.get("hearts", HEARTS))
	mistakes = int(d.get("mistakes", 0))
	_rebuild_occ()
	return true

func _rebuild_occ() -> void:
	occ = PackedInt32Array()
	occ.resize(cols * rows)
	occ.fill(-1)
	for i in arrows.size():
		if arrows[i].alive:
			for c in arrows[i].cells:
				occ[c.y * cols + c.x] = i

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func at(c: Vector2i) -> int:
	return occ[c.y * cols + c.x] if inside(c) else -1

func head(i: int) -> Vector2i:
	return arrows[i].cells[arrows[i].cells.size() - 1]

## {"blocker": index of the first arrow in the way or -1, "free": empty cells before it,
##  "to_edge": cells from the head to just past the edge}.
func path_info(i: int) -> Dictionary:
	var d: Vector2i = arrows[i].dir
	var c: Vector2i = head(i) + d
	var n := 0
	while inside(c):
		var o := at(c)
		if o >= 0 and o != i:
			return {"blocker": o, "free": n, "to_edge": -1}
		n += 1
		c += d
	return {"blocker": -1, "free": n, "to_edge": n + 1}

func can_remove(i: int) -> bool:
	return arrows[i].alive and path_info(i).blocker < 0

## Taps arrow `i`. Returns path_info plus "ok" (it left) -- a bump costs a heart and paints it red.
func tap(i: int) -> Dictionary:
	if i < 0 or i >= arrows.size() or not arrows[i].alive or failed() or solved():
		return {"ok": false, "blocker": -1, "free": 0, "to_edge": 0, "ignored": true}
	var info := path_info(i)
	if info.blocker < 0:
		arrows[i].alive = false
		for c in arrows[i].cells:
			occ[c.y * cols + c.x] = -1
		info["ok"] = true
	else:
		arrows[i].red = true
		hearts -= 1
		mistakes += 1
		info["ok"] = false
	return info

## One arrow that can leave now (prefers one that isn't red), or -1.
func hint() -> int:
	var fallback := -1
	for i in arrows.size():
		if can_remove(i):
			if not arrows[i].red:
				return i
			fallback = i
	return fallback

func alive_count() -> int:
	var n := 0
	for a in arrows:
		if a.alive:
			n += 1
	return n

func solved() -> bool:
	return arrows.size() > 0 and alive_count() == 0

func failed() -> bool:
	return hearts <= 0

## Extra heart (❤ help), up to the start count.
func add_heart() -> bool:
	if hearts >= HEARTS:
		return false
	hearts += 1
	return true

## Every arrow can still leave in some order? (Always true for generated levels; used by tests.)
func solvable() -> bool:
	var saved_occ := occ.duplicate()
	var alive: Array = []
	for a in arrows:
		alive.append(a.alive)
	var progress := true
	while progress:
		progress = false
		for i in arrows.size():
			if arrows[i].alive and path_info(i).blocker < 0:
				arrows[i].alive = false
				for c in arrows[i].cells:
					occ[c.y * cols + c.x] = -1
				progress = true
	var ok := alive_count() == 0
	for i in arrows.size():
		arrows[i].alive = alive[i]
	occ = saved_occ
	return ok
