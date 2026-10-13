extends RefCounted

## Wire Up (game id `pipe_flow`): a board of wire pieces, batteries and bulbs.
## Tap a piece to turn it a quarter clockwise until every bulb is lit.
## Pure logic, no Nodes.
##
## Each cell is a 4-bit mask of its openings: N = 1, E = 2, S = 4, W = 8.
## Current runs through pieces whose openings meet. Everything joined to a
## battery carries that battery's colour; a network that touches both a blue
## and a yellow battery carries GREEN (blue + yellow). A bulb lights only when
## the current reaching it is exactly its own colour, so a blue bulb on a
## mixed network is shorted, and a green bulb needs both batteries.
##
## Boards are built by routing wires between the batteries and bulbs first
## and scrambling afterwards, so every board is solvable. Level N always
## builds the same board (seeded), so campaign stars mean the same for everyone.

const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := [[N, 0, -1, S], [E, 1, 0, W], [S, 0, 1, N], [W, -1, 0, E]]  # bit, dx, dy, opposite

const EMPTY := 0
const WIRE := 1
const SOURCE := 2
const BULB := 3

const BLUE := 1
const YELLOW := 2
const GREEN := 3  # blue + yellow

const LEVEL_COUNT := 120
const CHAPTER_SIZE := 10

## Chapters of 10 levels. Sizes and bulb counts ease up from the first level of
## the chapter to the last. nets: [colour, bulbs at level 1 of chapter, bulbs at level 10].
## decoy = share of spare cells filled with dead wire, lock = share of pieces
## that start already correct and can't turn, loops = chance of extra wire
## that makes a circle, free = share of batteries and bulbs that can turn too.
const CHAPTERS := [
	{"name": "First Spark", "w": [3, 4], "h": [3, 4], "nets": [[2, 1, 2]], "decoy": 0.0, "lock": 0.4, "loops": 0.0, "free": 0.0},
	{"name": "Branching Out", "w": [4, 5], "h": [4, 5], "nets": [[2, 2, 3]], "decoy": 0.3, "lock": 0.3, "loops": 0.0, "free": 0.0},
	{"name": "Around the Block", "w": [4, 5], "h": [5, 6], "nets": [[2, 2, 3]], "decoy": 0.5, "lock": 0.25, "loops": 0.35, "free": 0.0},
	{"name": "Two Currents", "w": [5, 5], "h": [5, 6], "nets": [[1, 1, 2], [2, 1, 2]], "decoy": 0.4, "lock": 0.25, "loops": 0.2, "free": 0.0},
	{"name": "Cross Wires", "w": [5, 6], "h": [6, 7], "nets": [[1, 2, 3], [2, 2, 3]], "decoy": 0.5, "lock": 0.2, "loops": 0.3, "free": 0.2},
	{"name": "Green Light", "w": [5, 5], "h": [5, 6], "nets": [[3, 1, 2], [2, 1, 1]], "decoy": 0.4, "lock": 0.25, "loops": 0.2, "free": 0.0},
	{"name": "Mixing Desk", "w": [5, 6], "h": [6, 7], "nets": [[3, 1, 2], [1, 1, 2], [2, 1, 2]], "decoy": 0.5, "lock": 0.2, "loops": 0.3, "free": 0.2},
	{"name": "Live Wires", "w": [6, 7], "h": [7, 8], "nets": [[3, 2, 2], [1, 2, 3], [2, 2, 3]], "decoy": 0.5, "lock": 0.15, "loops": 0.3, "free": 0.3},
	{"name": "Overload", "w": [6, 7], "h": [7, 8], "nets": [[3, 2, 3], [1, 2, 3], [2, 2, 3]], "decoy": 0.5, "lock": 0.1, "loops": 0.35, "free": 0.4},
	{"name": "High Voltage", "w": [7, 8], "h": [8, 9], "nets": [[3, 2, 3], [1, 3, 3], [2, 3, 3]], "decoy": 0.55, "lock": 0.05, "loops": 0.35, "free": 0.5},
	{"name": "Blackout", "w": [7, 8], "h": [8, 10], "nets": [[3, 3, 3], [1, 3, 4], [2, 3, 4]], "decoy": 0.6, "lock": 0.0, "loops": 0.4, "free": 0.6},
	{"name": "Grid Master", "w": [8, 8], "h": [10, 10], "nets": [[3, 3, 4], [1, 3, 4], [2, 3, 4]], "decoy": 0.6, "lock": 0.0, "loops": 0.4, "free": 0.7},
]

var w: int = 3
var h: int = 3
var kind: Array = []       # EMPTY / WIRE / SOURCE / BULB per cell
var mask: Array = []       # current openings
var solution: Array = []   # the generated answer (one valid layout)
var color: Array = []      # SOURCE: its current colour; BULB: the colour it needs
var fixed: Array = []      # true = can't be turned
var moves: int = 0
var par: int = 0           # taps the generator's own answer needs
var level: int = 0         # campaign level, 0 = not a campaign board

# Results of analyze():
var power: Array = []      # colour bits (BLUE | YELLOW) of the current in each cell
var depth: Array = []      # steps from the nearest battery, -1 = no current
var lit_bulbs: int = 0
var bulb_total: int = 0

var _owner: Array = []

# ---------- levels ----------

static func chapter_of(lvl: int) -> int:
	return clampi((lvl - 1) / CHAPTER_SIZE, 0, CHAPTERS.size() - 1)

static func chapter_name(lvl: int) -> String:
	return CHAPTERS[chapter_of(lvl)].name

## Board settings for campaign level `lvl` (1-based). Past the last level
## the final chapter just keeps going.
static func params_for(lvl: int) -> Dictionary:
	var ch: Dictionary = CHAPTERS[chapter_of(lvl)]
	var t: float = float(clampi((lvl - 1) % CHAPTER_SIZE, 0, CHAPTER_SIZE - 1)) / float(CHAPTER_SIZE - 1)
	var nets: Array = []
	for n in ch.nets:
		nets.append([int(n[0]), int(roundf(lerpf(n[1], n[2], t)))])
	return {
		"w": int(roundf(lerpf(ch.w[0], ch.w[1], t))),
		"h": int(roundf(lerpf(ch.h[0], ch.h[1], t))),
		"nets": nets,
		"decoy": ch.decoy, "lock": ch.lock, "loops": ch.loops, "free": ch.free,
	}

static func seed_for(lvl: int) -> int:
	return lvl * 2654435 + 17

func new_level(lvl: int) -> void:
	generate(params_for(lvl), seed_for(lvl))
	level = lvl

## Builds a board for `p` (see params_for). Same params + seed = same board.
func generate(p: Dictionary, seed_value: int) -> void:
	level = 0
	var q: Dictionary = p.duplicate(true)
	for attempt in 120:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + attempt * 104729
		# A crowded board that won't route loses its last network, then shrinks to one.
		if attempt == 40 and q.nets.size() > 1:
			q.nets.pop_back()
		if attempt == 80 and q.nets.size() > 1:
			q.nets = [q.nets[0]]
		if _try(q, rng):
			return
	_plain_fallback()

func _plain_fallback() -> void:
	w = 3
	h = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var p := {"w": 3, "h": 3, "nets": [[YELLOW, 1]], "decoy": 0.0, "lock": 0.0, "loops": 0.0, "free": 0.0}
	for i in 400:
		if _try(p, rng):
			return
	push_error("pipe_flow: could not build a board")

func _try(p: Dictionary, rng: RandomNumberGenerator) -> bool:
	w = int(p.w)
	h = int(p.h)
	var n := w * h
	kind = _filled(n, EMPTY)
	mask = _filled(n, 0)
	solution = _filled(n, 0)
	color = _filled(n, 0)
	fixed = _filled(n, false)
	_owner = _filled(n, -1)
	moves = 0

	var terminals := 0
	for net in p.nets:
		terminals += (2 if net[0] == GREEN else 1) + int(net[1])
	if terminals * 2 > n:
		return false

	# Batteries and bulbs first, anywhere free.
	var free_cells: Array = range(n)
	_shuffle(free_cells, rng)
	var nets_cells: Array = []  # per network: {"srcs": [...], "bulbs": [...]}
	for ni in p.nets.size():
		var net: Array = p.nets[ni]
		var info := {"srcs": [], "bulbs": []}
		var src_colours: Array = [BLUE, YELLOW] if net[0] == GREEN else [net[0]]
		for sc in src_colours:
			var c: int = free_cells.pop_back()
			kind[c] = SOURCE
			color[c] = sc
			_owner[c] = ni
			info.srcs.append(c)
		for b in int(net[1]):
			var c2: int = free_cells.pop_back()
			kind[c2] = BULB
			color[c2] = net[0]
			_owner[c2] = ni
			info.bulbs.append(c2)
		nets_cells.append(info)

	# Wire each network: sources first (so a mixed network is joined), then bulbs.
	for ni in nets_cells.size():
		var info: Dictionary = nets_cells[ni]
		var root: int = info.srcs[0]
		var tree := {root: true}
		var todo: Array = info.srcs.slice(1) + info.bulbs
		for t in todo:
			var path := _route(t, ni, tree, root, rng)
			if path.is_empty():
				return false
			for k in path.size() - 1:
				_link(path[k], path[k + 1])
			for k in path.size():
				tree[path[k]] = true
				if k > 0 and k < path.size() - 1:
					kind[path[k]] = WIRE
					_owner[path[k]] = ni

	# Extra wire between neighbours of the same network: circles.
	var loops: float = p.loops
	if loops > 0.0:
		for c in n:
			if kind[c] != WIRE:
				continue
			for k in [1, 2]:  # east and south only, so each pair is looked at once
				var nb := neighbour(c, k)
				if nb >= 0 and kind[nb] == WIRE and _owner[nb] == _owner[c] \
						and solution[c] & DIRS[k][0] == 0 and rng.randf() < loops * 0.5:
					_link(c, nb)

	# Dead wire in spare cells, turned so it touches nothing.
	var decoy: float = p.decoy
	for c in n:
		if _owner[c] != -1 or kind[c] != EMPTY or rng.randf() >= decoy:
			continue
		var shape: int = _random_shape(rng)
		var turns := [0, 1, 2, 3]
		_shuffle(turns, rng)
		for t in turns:
			var m: int = shape
			for _i in t:
				m = rotated(m)
			if _touches_nothing(c, m):
				kind[c] = WIRE
				_owner[c] = -2
				solution[c] = m
				break

	# Which pieces may turn.
	var lock: float = p.lock
	var free_terms: float = p.free
	for c in n:
		if kind[c] == EMPTY:
			continue
		if kind[c] == WIRE:
			fixed[c] = rotated(solution[c]) == solution[c] or rng.randf() < lock
		else:
			fixed[c] = rng.randf() >= free_terms

	# Scramble the pieces that may turn.
	mask = solution.duplicate()
	for c in n:
		if kind[c] != EMPTY and not fixed[c]:
			for _t in rng.randi_range(0, 3):
				mask[c] = rotated(mask[c])
	analyze()
	if bulb_total == 0:
		return false
	var guard := 0
	while lit_bulbs == bulb_total and guard < 50:
		guard += 1
		var c: int = rng.randi_range(0, n - 1)
		if kind[c] != EMPTY and not fixed[c] and rotated(mask[c]) != mask[c]:
			mask[c] = rotated(mask[c])
			analyze()
	if lit_bulbs == bulb_total:
		return false
	par = 0
	for c in n:
		var m: int = mask[c]
		var k := 0
		while m != solution[c] and k < 4:
			m = rotated(m)
			k += 1
		par += k
	# The generator's own layout must light everything: a self-check.
	var scrambled: Array = mask
	mask = solution
	analyze()
	var ok: bool = lit_bulbs == bulb_total
	mask = scrambled
	analyze()
	return ok

func _filled(n: int, v: Variant) -> Array:
	var a: Array = []
	a.resize(n)
	a.fill(v)
	return a

func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp

func _random_shape(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < 0.15:
		return N  # a stub
	if r < 0.45:
		return N | S  # straight
	if r < 0.75:
		return N | E  # corner
	if r < 0.95:
		return N | E | S  # T
	return 15  # cross

## True when no opening of `m` at `cell` meets an opening of a neighbour.
func _touches_nothing(cell: int, m: int) -> bool:
	for k in 4:
		if m & DIRS[k][0] == 0:
			continue
		var nb := neighbour(cell, k)
		if nb >= 0 and solution[nb] & DIRS[k][3] != 0:
			return false
	return true

func _link(a: int, b: int) -> void:
	for k in 4:
		if neighbour(a, k) == b:
			solution[a] |= DIRS[k][0]
			solution[b] |= DIRS[k][3]
			return

## A winding path from terminal `t` through free cells to the network's wire
## (or to its first battery while that has no wire yet): [t, ..., join cell].
## Empty when there is no way through.
func _route(t: int, ni: int, tree: Dictionary, root: int, rng: RandomNumberGenerator) -> Array:
	var n := w * h
	var cost: Array = []
	for i in n:
		cost.append(1.0 + rng.randf() * 2.0)
	var dist: Array = _filled(n, INF)
	var prev: Array = _filled(n, -1)
	var done: Array = _filled(n, false)
	dist[t] = 0.0
	while true:
		var u := -1
		var best := INF
		for i in n:
			if not done[i] and dist[i] < best:
				best = dist[i]
				u = i
		if u == -1:
			break
		done[u] = true
		for k in 4:
			var nb := neighbour(u, k)
			if nb >= 0 and not done[nb] and _owner[nb] == -1 and kind[nb] == EMPTY and dist[u] + cost[nb] < dist[nb]:
				dist[nb] = dist[u] + cost[nb]
				prev[nb] = u
	# Cheapest reachable cell that borders a place to join.
	var pick_u := -1
	var pick_v := -1
	var pick_cost := INF
	for u in n:
		if dist[u] == INF:
			continue
		for k in 4:
			var v := neighbour(u, k)
			if v < 0 or not tree.has(v) or v == u:
				continue
			var joinable: bool = (kind[v] == WIRE and _owner[v] == ni) or (v == root and solution[root] == 0)
			if joinable and dist[u] + rng.randf() * 0.5 < pick_cost:
				pick_cost = dist[u] + rng.randf() * 0.5
				pick_u = u
				pick_v = v
	if pick_u == -1:
		return []
	var path: Array = [pick_v]
	var c := pick_u
	while c != -1:
		path.append(c)
		c = prev[c]
	path.reverse()
	return path

# ---------- play ----------

## The mask turned a quarter clockwise (N->E->S->W->N).
static func rotated(m: int) -> int:
	return ((m << 1) | (m >> 3)) & 15

## Whether tapping `cell` does anything.
func can_turn(cell: int) -> bool:
	return kind[cell] != EMPTY and not fixed[cell] and rotated(mask[cell]) != mask[cell]

func rotate(cell: int) -> void:
	mask[cell] = rotated(mask[cell])
	moves += 1
	analyze()

## Takes back one tap of `cell` (three more quarter turns).
func unrotate(cell: int) -> void:
	for _i in 3:
		mask[cell] = rotated(mask[cell])
	moves = maxi(moves - 1, 0)
	analyze()

## Neighbour of `cell` in direction k (0..3), or -1 off the board.
func neighbour(cell: int, k: int) -> int:
	var d: Array = DIRS[k]
	var nx: int = cell % w + d[1]
	var ny: int = cell / w + d[2]
	if nx < 0 or ny < 0 or nx >= w or ny >= h:
		return -1
	return ny * w + nx

## True when the opening k of `cell` meets an opening of its neighbour.
func linked(cell: int, k: int) -> bool:
	if mask[cell] & DIRS[k][0] == 0:
		return false
	var nb := neighbour(cell, k)
	return nb >= 0 and mask[nb] & DIRS[k][3] != 0

## True for an opening that leads nowhere (off the board or into a closed side).
func open_end(cell: int, k: int) -> bool:
	return mask[cell] & DIRS[k][0] != 0 and not linked(cell, k)

## Works out which current reaches which cell, and which bulbs are lit.
func analyze() -> void:
	var n := w * h
	power = _filled(n, 0)
	depth = _filled(n, -1)
	var seen: Array = _filled(n, false)
	for start in n:
		if seen[start] or kind[start] == EMPTY:
			continue
		var comp: Array = [start]
		seen[start] = true
		var i := 0
		var bits := 0
		while i < comp.size():
			var c: int = comp[i]
			i += 1
			if kind[c] == SOURCE:
				bits |= color[c]
			for k in 4:
				if linked(c, k):
					var nb := neighbour(c, k)
					if not seen[nb]:
						seen[nb] = true
						comp.append(nb)
		for c in comp:
			power[c] = bits
	# Steps from the nearest battery, for the running-current animation.
	var queue: Array = []
	for c in n:
		if kind[c] == SOURCE:
			depth[c] = 0
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c2: int = queue[head]
		head += 1
		for k in 4:
			if linked(c2, k):
				var nb2 := neighbour(c2, k)
				if depth[nb2] == -1:
					depth[nb2] = depth[c2] + 1
					queue.append(nb2)
	lit_bulbs = 0
	bulb_total = 0
	for c in n:
		if kind[c] == BULB:
			bulb_total += 1
			if is_lit(c):
				lit_bulbs += 1

func is_lit(cell: int) -> bool:
	return kind[cell] == BULB and power[cell] == color[cell]

## A bulb with current of the wrong colour (blue on yellow, or a mixed network
## feeding a single-colour bulb).
func is_shorted(cell: int) -> bool:
	return kind[cell] == BULB and power[cell] != 0 and power[cell] != color[cell]

func is_won() -> bool:
	return bulb_total > 0 and lit_bulbs == bulb_total

## Stars for the taps used: 3 near the generator's own answer, 2 for fair, 1 for solved.
func stars(hints_used: int = 0) -> int:
	var s := 3
	if moves > int(ceilf(par * 1.3)) + 1:
		s = 2
	if moves > int(ceilf(par * 1.9)) + 3:
		s = 1
	if hints_used > 0:
		s = mini(s, 2)
	return s

## A piece that differs from the generator's answer (for the hint), or -1.
## Prefers pieces that don't change the lit bulbs when left alone last.
func hint_cell(rng: RandomNumberGenerator) -> int:
	var wrong: Array = []
	for c in w * h:
		if kind[c] != EMPTY and not fixed[c] and mask[c] != solution[c]:
			wrong.append(c)
	if wrong.is_empty():
		return -1
	return wrong[rng.randi_range(0, wrong.size() - 1)]

static func is_end(m: int) -> bool:
	return m in [N, E, S, W]
