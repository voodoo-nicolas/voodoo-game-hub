extends RefCounted

## Mahjong Solitaire: tiles stacked in layers; remove matching pairs of free
## tiles until the table is clear. A tile is free when nothing lies on top
## of it and its left or right side is open. Pure logic, no Nodes.
##
## Positions are in half-tile units: a tile at (x, y) covers x..x+2 and
## y..y+2 on its layer, so upper layers can sit half a tile over.
## Every deal is solvable: symbols are handed out by "un-playing" the full
## layout -- repeatedly taking two tiles that would be free -- so the
## reverse order is a winning game.

## Layouts: one array per layer of [x, y] origins (half units).
static func layout(kind: int) -> Array:
	var layers: Array = []
	match kind:
		0:  # Easy: a 6 x 8 floor with a 4 x 6 roof (72 tiles)
			layers.append(_rect(0, 0, 6, 8))
			layers.append(_rect(2, 2, 4, 6))
		1:  # Normal: a pyramid (82 tiles)
			layers.append(_rect(0, 0, 6, 8))
			layers.append(_rect(2, 2, 4, 6))
			layers.append(_rect(4, 4, 2, 4))
			layers.append(_rect(5, 6, 1, 2))
		_:  # Hard: a fortress with wings, towers and half-offset layers (98 tiles)
			var floor_: Array = _rect(0, 0, 6, 8)
			floor_.append_array([[-2, 7], [12, 7]])  # side wings
			layers.append(floor_)
			layers.append(_rect(2, 1, 4, 7))
			var top: Array = _rect(2, 2, 2, 2)
			top.append_array(_rect(6, 2, 2, 2))
			top.append_array(_rect(2, 10, 2, 2))
			top.append_array(_rect(6, 10, 2, 2))
			layers.append(top)
			layers.append([[3, 3], [7, 3], [3, 11], [7, 11]])
	return layers

static func _rect(x0: int, y0: int, cols: int, rows: int) -> Array:
	var out: Array = []
	for r in rows:
		for c in cols:
			out.append([x0 + c * 2, y0 + r * 2])
	return out

## tiles: [{"x", "y", "z", "s" (symbol), "on" (still on the table)}]
var tiles: Array = []
var kinds: int = 18
var history: Array = []  # removed pairs, for Undo
var moves: int = 0
var shuffles: int = 0
## Deals that had to fall back to unchecked pairs (should stay 0; tests read it).
var fallbacks: int = 0

func deal(kind: int, n_kinds: int, rng: RandomNumberGenerator) -> void:
	kinds = n_kinds
	tiles = []
	var layers := layout(kind)
	for z in layers.size():
		for p in layers[z]:
			tiles.append({"x": p[0], "y": p[1], "z": z, "s": -1, "on": true})
	_assign(range(tiles.size()), rng)
	history = []
	moves = 0
	shuffles = 0

## Gives the listed tiles symbols so they can all be cleared: take away
## random free pairs one by one, giving each pair one symbol.
func _assign(ids: Array, rng: RandomNumberGenerator) -> void:
	for attempt in 50:
		var on := {}
		for i in ids:
			on[i] = true
		var order: Array = []
		var stuck := false
		while not on.is_empty():
			var free: Array = []
			for i in on:
				if _free_among(i, on):
					free.append(i)
			if free.size() < 2:
				stuck = true
				break
			var a: int = free.pop_at(rng.randi_range(0, free.size() - 1))
			var b: int = free.pop_at(rng.randi_range(0, free.size() - 1))
			on.erase(a)
			on.erase(b)
			order.append([a, b])
		if stuck:
			continue
		# Symbols come in sets of four where possible: pairs share symbols.
		var syms: Array = []
		for k in order.size():
			syms.append((k / 2) % kinds)
		for i in range(syms.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = syms[i]
			syms[i] = syms[j]
			syms[j] = t
		for k in order.size():
			tiles[order[k][0]].s = syms[k]
			tiles[order[k][1]].s = syms[k]
		return
	# Only when the tiles left can't be cleared in any order (e.g. two tiles
	# stacked on each other): plain pairs, so the game still plays.
	fallbacks += 1
	for k in ids.size():
		tiles[ids[k]].s = (k / 2) % kinds

func _overlap(a: Dictionary, b: Dictionary) -> bool:
	return absi(a.x - b.x) < 2 and absi(a.y - b.y) < 2

## Is tile i free, counting only the tiles whose ids are keys of `on`?
func _free_among(i: int, on: Dictionary) -> bool:
	var t: Dictionary = tiles[i]
	var left := false
	var right := false
	for j in on:
		if j == i:
			continue
		var o: Dictionary = tiles[j]
		if o.z == t.z + 1 and _overlap(t, o):
			return false
		if o.z == t.z and absi(o.y - t.y) < 2:
			if o.x == t.x - 2:
				left = true
			elif o.x == t.x + 2:
				right = true
	return not (left and right)

func _on_ids() -> Dictionary:
	var on := {}
	for i in tiles.size():
		if tiles[i].on:
			on[i] = true
	return on

func is_free(i: int) -> bool:
	return tiles[i].on and _free_among(i, _on_ids())

func remaining() -> int:
	var n := 0
	for t in tiles:
		if t.on:
			n += 1
	return n

## Removes the pair if both are free and match.
func remove_pair(a: int, b: int) -> bool:
	if a == b or not is_free(a) or not is_free(b) or tiles[a].s != tiles[b].s:
		return false
	tiles[a].on = false
	tiles[b].on = false
	history.append([a, b])
	moves += 1
	return true

func undo() -> bool:
	if history.is_empty():
		return false
	var p: Array = history.pop_back()
	tiles[p[0]].on = true
	tiles[p[1]].on = true
	return true

## A matching free pair, or [] if none.
func hint() -> Array:
	var on := _on_ids()
	var by_sym := {}
	for i in on:
		if _free_among(i, on):
			var s: int = tiles[i].s
			if by_sym.has(s):
				return [by_sym[s], i]
			by_sym[s] = i
	return []

## Deals the remaining tiles' symbols again so the rest can be cleared.
func reshuffle(rng: RandomNumberGenerator) -> void:
	var ids: Array = _on_ids().keys()
	_assign(ids, rng)
	history = []
	shuffles += 1

func won() -> bool:
	return remaining() == 0
