extends RefCounted

## Arrow Cube -- pure logic, no Nodes (tools/test_arrow_cube.gd runs it headless).
## Design: GAME_DESIGN_ARROW_CUBE.md (owner's design folder).
##
## The shape is a polycube: a set of unit blocks ("voxels"). Every block is cut into n x n x n
## small cubes, so every face of the shape carries an n x n grid. A surface CELL is one small
## cube p with one of its faces pointing out: (p, normal) with p solid and p + normal empty.
##
## An arrow is a path of cells. Tap it: it looks along its RAY -- the cells ahead of its head,
## walking the surface. Concave corners always lead up the wall. A convex edge is a CLIFF
## (the arrow lifts off there and flies away) unless it is a WRAP edge (the arrow bends over
## it onto the next face). Rules:
##   - the ray reaches a cliff with nothing in the way -> the arrow leaves (removed);
##   - the ray meets a STOP first, with nothing in the way -> the arrow slides forward until its
##     head sits on the stop; the stop is used up (disappears);
##   - anything else in the way (another arrow, its own body, a loop with no cliff) -> BUMP.
## Two-way arrows have a head at each end; the player picks the end. Forks have 2-3 heads:
## every head's ray must reach a cliff (stops count as walls for forks), then all of it leaves.
##
## Levels are built backwards (see generate()): each new arrow must be free while only the
## arrows placed before it exist, so removing them in reverse order solves the level.

const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const LEVEL_COUNT := 500
const MAX_HEARTS := 3
const GEN_VERSION := 1  # bump if generate() changes, and re-bake the levels file

const KIND_ONE := "one"   # one head
const KIND_TWO := "two"   # a head at each end
const KIND_FORK := "fork" # one tail, 2-3 heads

## Named block shapes (coarse voxels). Original arrangements.
const SHAPES := {
	"cube": [[0, 0, 0]],
	"bar": [[0, 0, 0], [1, 0, 0]],
	"slab": [[0, 0, 0], [1, 0, 0], [0, 0, 1], [1, 0, 1]],
	"tower": [[0, 0, 0], [0, 1, 0], [0, 2, 0]],
	"ell": [[0, 0, 0], [1, 0, 0], [0, 1, 0]],
	"tee": [[0, 0, 0], [1, 0, 0], [2, 0, 0], [1, 1, 0]],
	"block": [[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0], [0, 0, 1], [1, 0, 1], [0, 1, 1], [1, 1, 1]],
	"plus": [[1, 0, 0], [0, 1, 0], [1, 1, 0], [2, 1, 0], [1, 2, 0]],
	"tripod": [[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]],
	"stairs": [[0, 0, 0], [1, 0, 0], [2, 0, 0], [1, 1, 0], [2, 1, 0], [2, 2, 0]],
	"arch": [[0, 0, 0], [0, 1, 0], [1, 1, 0], [2, 1, 0], [2, 0, 0]],
	"jack": [[1, 1, 1], [0, 1, 1], [2, 1, 1], [1, 0, 1], [1, 2, 1], [1, 1, 0], [1, 1, 2]],
	"ring": [[0, 0, 0], [1, 0, 0], [2, 0, 0], [0, 1, 0], [2, 1, 0], [0, 2, 0], [1, 2, 0], [2, 2, 0]],
	"zig": [[0, 0, 0], [1, 0, 0], [1, 1, 0], [1, 1, 1], [2, 1, 1]],
}

# ---------- state ----------

var n: int = 3                 # small cubes per block edge
var voxels: Dictionary = {}    # Vector3i block -> true
var wraps: Dictionary = {}     # edge key -> true (convex edges an arrow bends over)
var cells: Array = []          # every surface cell key (int)
var arrows: Array = []         # [{id, kind, cells: [key...], heads: [{at, dir}], color}]
var stops: Dictionary = {}     # cell key -> true
var occ: Dictionary = {}       # cell key -> arrow id
var hearts: int = MAX_HEARTS
var bumps: int = 0
var level_no: int = 1
var history: Array = []        # snapshots for Undo
var _next_id: int = 0

# ---------- cell keys ----------

## A cell packs the small cube p (each coord -64..63) and its normal (0..5).
static func key(p: Vector3i, nd: int) -> int:
	return ((((p.x + 64) * 128) + (p.y + 64)) * 128 + (p.z + 64)) * 8 + nd

static func key_pos(k: int) -> Vector3i:
	var r := k / 8
	var z := r % 128
	r /= 128
	var y := r % 128
	var x := r / 128
	return Vector3i(x - 64, y - 64, z - 64)

static func key_normal(k: int) -> int:
	return k % 8

static func opp(d: int) -> int:
	return d ^ 1

static func axis(d: int) -> int:
	return d / 2

func block_of(p: Vector3i) -> Vector3i:
	return Vector3i(floori(float(p.x) / n), floori(float(p.y) / n), floori(float(p.z) / n))

func solid(p: Vector3i) -> bool:
	return voxels.has(block_of(p))

## Convex edge between face `a` and face `b` of block v (order free).
static func edge_key(v: Vector3i, a: int, b: int) -> int:
	return key(v, 0) * 64 + mini(a, b) * 8 + maxi(a, b)

static func edge_block(e: int) -> Vector3i:
	return key_pos(e / 64)

static func edge_faces(e: int) -> Array:
	return [(e % 64) / 8, e % 8]

# ---------- shape ----------

func set_shape(blocks: Array, size: int) -> void:
	n = size
	voxels.clear()
	for b in blocks:
		voxels[Vector3i(int(b[0]), int(b[1]), int(b[2]))] = true
	cells.clear()
	for v in voxels:
		for nd in 6:
			if voxels.has(v + DIRS[nd]):
				continue
			var ax := axis(nd)
			for i in n:
				for j in n:
					var c := [0, 0, 0]
					var free_axes: Array = []
					for a in 3:
						if a == ax:
							c[a] = n - 1 if DIRS[nd][a] > 0 else 0
						else:
							free_axes.append(a)
					c[free_axes[0]] = i
					c[free_axes[1]] = j
					cells.append(key(v * n + Vector3i(c[0], c[1], c[2]), nd))

## All convex edges of the shape, each once.
func convex_edges() -> Array:
	var out: Array = []
	for v in voxels:
		for a in 6:
			if voxels.has(v + DIRS[a]):
				continue
			for b in range(a + 1, 6):
				if axis(a) == axis(b) or voxels.has(v + DIRS[b]):
					continue
				if voxels.has(v + DIRS[a] + DIRS[b]):
					continue  # diagonal neighbour: the step climbs it instead (concave)
				out.append(edge_key(v, a, b))
	return out

## One step along the surface from cell k heading d. Returns [next_key, next_dir, edge]
## where edge is 0 for flat/concave, else the convex edge key + 1.
func step(k: int, d: int) -> Array:
	var p := key_pos(k)
	var nd := key_normal(k)
	var dv: Vector3i = DIRS[d]
	var nv: Vector3i = DIRS[nd]
	if solid(p + dv + nv):  # concave: climb the wall
		return [key(p + dv + nv, opp(d)), nd, 0]
	if solid(p + dv):       # flat
		return [key(p + dv, nd), d, 0]
	return [key(p, d), opp(nd), edge_key(block_of(p), nd, d) + 1]  # convex: over the edge

func is_cliff(s: Array) -> bool:
	return int(s[2]) != 0 and not wraps.has(int(s[2]) - 1)

## The direction at cell a that steps onto neighbour b, or -1.
func dir_between(a: int, b: int) -> int:
	var nd := key_normal(a)
	for d in 6:
		if axis(d) != axis(nd) and int(step(a, d)[0]) == b:
			return d
	return -1

## The direction an arrow has on arriving at b from a, or -1.
func arrive_dir(a: int, b: int) -> int:
	var d := dir_between(a, b)
	return -1 if d < 0 else int(step(a, d)[1])

## Walk the ray from cell k heading d. Returns {"result": "exit"|"stop"|"blocked",
## "path": [cells walked, the stop or blocker included], "dir": dir at the last cell}.
func ray(k: int, d: int, stops_are_walls: bool = false) -> Dictionary:
	var path: Array = []
	var cur := k
	var dir := d
	for _i in cells.size() + 4:
		var s := step(cur, dir)
		if is_cliff(s):
			return {"result": "exit", "path": path, "dir": dir}
		cur = int(s[0])
		dir = int(s[1])
		path.append(cur)
		if occ.has(cur):
			return {"result": "blocked", "path": path, "dir": dir, "by": int(occ[cur])}
		if stops.has(cur):
			return {"result": "blocked" if stops_are_walls else "stop", "path": path, "dir": dir, "by": -2}
	return {"result": "blocked", "path": path, "dir": dir, "by": -3}  # a loop with no cliff

# ---------- arrows ----------

func arrow_by_id(id: int) -> Dictionary:
	for a in arrows:
		if int(a.id) == id:
			return a
	return {}

func _occupy(a: Dictionary) -> void:
	for c in a.cells:
		occ[int(c)] = int(a.id)

func _vacate(a: Dictionary) -> void:
	for c in a.cells:
		if int(occ.get(int(c), -1)) == int(a.id):
			occ.erase(int(c))

func add_arrow(kind: String, path: Array, heads: Array, color: int = 0) -> Dictionary:
	var a := {"id": _next_id, "kind": kind, "cells": path.duplicate(), "heads": heads.duplicate(true), "color": color}
	_next_id += 1
	arrows.append(a)
	_occupy(a)
	return a

func remove_arrow(id: int) -> void:
	var a := arrow_by_id(id)
	if a.is_empty():
		return
	_vacate(a)
	arrows.erase(a)

## How many heads the player can choose between (forks fire all at once).
static func choices(a: Dictionary) -> int:
	return 1 if a.kind == KIND_FORK else a.heads.size()

## What tapping head `hi` of arrow `id` would do, without doing it.
## {"result": "exit"|"stop"|"blocked", "paths": [ray path per moving head], "dir", "head"}
func preview(id: int, hi: int = 0) -> Dictionary:
	var a := arrow_by_id(id)
	if a.is_empty():
		return {"result": "blocked", "paths": [], "head": 0}
	if a.kind == KIND_FORK:
		var paths: Array = []
		var res := "exit"
		for h in a.heads:
			var r := ray(int(h.at), int(h.dir), true)
			paths.append(r.path)
			if r.result != "exit":
				res = "blocked"
		return {"result": res, "paths": paths, "head": 0}
	hi = clampi(hi, 0, a.heads.size() - 1)
	var h: Dictionary = a.heads[hi]
	var r := ray(int(h.at), int(h.dir))
	return {"result": r.result, "paths": [r.path], "dir": r.dir, "head": hi}

## Do the tap. Returns the preview plus "moved" (false = bump, which costs a heart).
func tap(id: int, hi: int = 0) -> Dictionary:
	var pv := preview(id, hi)
	if pv.result == "blocked":
		bumps += 1
		hearts = maxi(0, hearts - 1)
		pv["moved"] = false
		return pv
	_push_history()
	if pv.result == "exit":
		remove_arrow(id)
	else:
		_park(id, int(pv.head), pv.paths[0], int(pv.dir))
	pv["moved"] = true
	return pv

## Remove any arrow (the "Remove" help). Undo-able.
func pluck(id: int) -> bool:
	if arrow_by_id(id).is_empty():
		return false
	_push_history()
	remove_arrow(id)
	return true

## Slide arrow id head-first along `path` until its head is on the stop at the path's end.
func _park(id: int, hi: int, path: Array, dir: int) -> void:
	var a := arrow_by_id(id)
	_vacate(a)
	var body: Array = a.cells.duplicate()
	if a.kind == KIND_TWO and hi == 0:
		body.reverse()  # the moving end goes last
	var seq: Array = body + path
	var cut := path.size()
	var nb: Array = seq.slice(cut, cut + body.size())
	stops.erase(int(path[path.size() - 1]))
	if a.kind == KIND_TWO:
		var other := {"at": int(nb[0]), "dir": arrive_dir(int(nb[1]), int(nb[0]))}
		var moving := {"at": int(nb[nb.size() - 1]), "dir": dir}
		if hi == 0:
			nb.reverse()
			a.heads = [moving, other]
		else:
			a.heads = [other, moving]
	else:
		a.heads = [{"at": int(nb[nb.size() - 1]), "dir": dir}]
	a.cells = nb
	_occupy(a)

func won() -> bool:
	return arrows.is_empty()

func lost() -> bool:
	return hearts <= 0

## Ids of arrows that can leave the shape right now (the "Show safe" help).
func free_arrows() -> Array:
	var out: Array = []
	for a in arrows:
		for hi in choices(a):
			if preview(int(a.id), hi).result == "exit":
				out.append(int(a.id))
				break
	return out

## Any legal move at all (leave or park)?
func any_move() -> bool:
	for a in arrows:
		for hi in choices(a):
			if preview(int(a.id), hi).result != "blocked":
				return true
	return false

# ---------- undo / save ----------

func snapshot() -> Dictionary:
	return {"arrows": arrows.duplicate(true), "stops": stops.keys(), "next": _next_id}

func restore(s: Dictionary) -> void:
	arrows = s.arrows.duplicate(true)
	stops.clear()
	for k in s.stops:
		stops[int(k)] = true
	_next_id = int(s.get("next", 0))
	occ.clear()
	for a in arrows:
		_occupy(a)

func _push_history() -> void:
	history.append(snapshot())
	if history.size() > 80:
		history.pop_front()

func undo() -> bool:
	if history.is_empty():
		return false
	restore(history.pop_back())
	return true

## Level as plain data (also the format of the baked levels file).
func level_dict() -> Dictionary:
	var vx: Array = []
	for v in voxels:
		vx.append([v.x, v.y, v.z])
	var ar: Array = []
	for a in arrows:
		var hs: Array = []
		for h in a.heads:
			hs.append([int(h.at), int(h.dir)])
		ar.append({"k": a.kind, "c": a.cells.duplicate(), "h": hs, "col": int(a.color)})
	return {"n": n, "v": vx, "w": wraps.keys(), "s": stops.keys(), "a": ar}

func load_dict(d: Dictionary) -> bool:
	if not d.has("v") or not d.has("a"):
		return false
	set_shape(d.v, int(d.get("n", 3)))
	wraps.clear()
	for w in d.get("w", []):
		wraps[int(w)] = true
	stops.clear()
	for s in d.get("s", []):
		stops[int(s)] = true
	arrows.clear()
	occ.clear()
	_next_id = 0
	for a in d.a:
		var hs: Array = []
		for h in a.h:
			hs.append({"at": int(h[0]), "dir": int(h[1])})
		var cl: Array = []
		for c in a.c:
			cl.append(int(c))
		add_arrow(str(a.k), cl, hs, int(a.get("col", 0)))
	hearts = MAX_HEARTS
	bumps = 0
	history.clear()
	return true

func to_save() -> Dictionary:
	var d := level_dict()
	d["hearts"] = hearts
	d["bumps"] = bumps
	d["level"] = level_no
	return d

func from_save(d: Dictionary) -> bool:
	if not load_dict(d):
		return false
	hearts = clampi(int(d.get("hearts", MAX_HEARTS)), 1, MAX_HEARTS)
	bumps = int(d.get("bumps", 0))
	level_no = int(d.get("level", 1))
	return true

# ---------- solver ----------

## Can the position still be cleared? Leaving never hurts (it only frees cells), so every
## free arrow leaves first; only stop-parks are searched. Returns the first move of a solution
## as [id, head], [-1, 0] if already clear, or [] if none found within `budget` positions.
func solve_first(budget: int = 4000) -> Array:
	var start := snapshot()
	var res := _solve({}, [budget])
	restore(start)
	return res

func _solve(seen: Dictionary, budget: Array) -> Array:
	var first: Array = []
	var progress := true
	while progress:
		progress = false
		for a in arrows.duplicate():
			for hi in choices(a):
				if preview(int(a.id), hi).result == "exit":
					if first.is_empty():
						first = [int(a.id), hi]
					remove_arrow(int(a.id))
					progress = true
					break
	if arrows.is_empty():
		return first if not first.is_empty() else [-1, 0]
	var h := hash(_sig())
	if seen.has(h) or budget[0] <= 0:
		return []
	seen[h] = true
	budget[0] -= 1
	for a in arrows.duplicate():
		if a.kind == KIND_FORK:
			continue
		for hi in a.heads.size():
			var pv := preview(int(a.id), hi)
			if pv.result != "stop":
				continue
			var s := snapshot()
			_park(int(a.id), hi, pv.paths[0], int(pv.dir))
			var sub := _solve(seen, budget)
			restore(s)
			if not sub.is_empty():
				return first if not first.is_empty() else [int(a.id), hi]
	return []

func _sig() -> String:
	var parts: Array = []
	for a in arrows:
		parts.append(str(a.cells[0]) + ":" + str(a.cells[a.cells.size() - 1]))
	parts.sort()
	var st: Array = stops.keys()
	st.sort()
	return ",".join(parts) + "|" + str(st)

# ---------- level shape ----------

static func level_seed(lv: int) -> int:
	return lv * 7919 + 104729

## What level `lv` is made of. Every number here is the difficulty curve.
static func params(lv: int) -> Dictionary:
	var shapes: Array = ["cube"]
	if lv > 16:
		shapes += ["bar"]
	if lv > 30:
		shapes += ["slab", "ell"]
	if lv > 60:
		shapes += ["tower", "tee", "block", "plus"]
	if lv > 100:
		shapes += ["tripod", "arch", "zig"]
	if lv > 160:
		shapes += ["stairs", "ring", "jack"]
		shapes.erase("cube")
	var t := clampf(float(lv - 1) / (LEVEL_COUNT - 1), 0.0, 1.0)
	return {
		"shapes": shapes,
		"cells": int(lerpf(54.0, 560.0, t)),       # surface cells wanted
		"fill": lerpf(0.45, 0.86, sqrt(t)),          # share of cells under arrows
		"max_len": 3 + mini(7, lv / 25),
		"wrap": 0.0 if lv < 25 else minf(0.45, 0.15 + lv * 0.0008),
		"two": 0.0 if lv < 45 else 0.14,
		"stop": 0.0 if lv < 80 else 0.10,
		"fork": 0.0 if lv < 120 else 0.12,
		"pick": minf(0.9, 0.3 + lv * 0.003),        # how hard it tries to block earlier arrows
		"turn": minf(0.45, 0.15 + lv * 0.002),
	}

## Endless mode past the last level: a random polycube, everything on.
static func endless_params(i: int) -> Dictionary:
	var p := params(LEVEL_COUNT)
	p["random_shape"] = 4 + (i % 9)
	return p

func load_level(lv: int) -> void:
	var p := params(lv) if lv <= LEVEL_COUNT else endless_params(lv - LEVEL_COUNT)
	generate(p, level_seed(lv))
	level_no = lv

# ---------- generator ----------

func generate(p: Dictionary, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var blocks: Array
	if p.has("random_shape"):
		blocks = _random_polycube(rng, int(p.random_shape))
	else:
		blocks = SHAPES[p.shapes[rng.randi_range(0, p.shapes.size() - 1)]]
	set_shape(blocks, 1)
	var faces := cells.size()
	set_shape(blocks, clampi(int(round(sqrt(float(p.cells) / faces))), 3, 8))
	wraps.clear()
	for e in convex_edges():
		if rng.randf() < float(p.wrap):
			wraps[e] = true
	arrows.clear()
	occ.clear()
	stops.clear()
	_next_id = 0
	var want := int(cells.size() * float(p.fill))
	var covered := 0
	var fails := 0
	_ray_map = {}
	while covered < want and fails < 40:
		var best: Dictionary = {}
		var best_score := -1
		for _t in 6:
			var cand := _candidate(rng, p)
			if cand.is_empty():
				continue
			var sc := _blocking_score(cand)
			if rng.randf() > float(p.pick):
				sc = rng.randi_range(0, 2)
			if sc > best_score:
				best_score = sc
				best = cand
		if best.is_empty():
			fails += 1
			continue
		var a := add_arrow(best.kind, best.cells, best.heads, _next_id)
		covered += a.cells.size()
		if best.has("stop"):
			stops[int(best.stop)] = true
		_build_ray_map()
	hearts = MAX_HEARTS
	bumps = 0
	history.clear()

var _ray_map: Dictionary = {}  # generator only: cell -> {arrow id: true} for rays over it

func _build_ray_map() -> void:
	_ray_map = {}
	for a in arrows:
		for h in a.heads:
			for c in ray(int(h.at), int(h.dir)).path:
				if not _ray_map.has(c):
					_ray_map[c] = {}
				_ray_map[c][int(a.id)] = true

## How many placed arrows this candidate would block (more = deeper puzzle).
func _blocking_score(cand: Dictionary) -> int:
	var hit := {}
	for c in cand.cells:
		if _ray_map.has(int(c)):
			hit.merge(_ray_map[int(c)])
	return hit.size()

func _free_cell(k: int) -> bool:
	return not occ.has(k) and not stops.has(k)

## A new arrow that is free right now, or {}. Its ray must reach a cliff with stops counted as
## walls, so arrows placed later never meet an earlier stop. It may bring its own stop.
func _candidate(rng: RandomNumberGenerator, p: Dictionary) -> Dictionary:
	for _attempt in 12:
		var head := int(cells[rng.randi_range(0, cells.size() - 1)])
		if not _free_cell(head):
			continue
		var d := rng.randi_range(0, 5)
		if axis(d) == axis(key_normal(head)):
			continue
		var r := ray(head, d, true)
		if r.result != "exit":
			continue
		var roll := rng.randf()
		var kind := KIND_ONE
		if roll < float(p.fork):
			kind = KIND_FORK
		elif roll < float(p.fork) + float(p.two):
			kind = KIND_TWO
		if kind == KIND_FORK:
			var f := _make_fork(rng, head, d, p)
			if not f.is_empty():
				return f
			continue
		var minl := 1 if kind == KIND_ONE else 3
		var body := _grow(rng, head, d, rng.randi_range(minl, int(p.max_len)), float(p.turn), r.path)
		if body.size() < minl:
			continue
		var path: Array = body.duplicate()
		path.reverse()  # arrow cells go tail -> head
		var heads: Array = [{"at": head, "dir": d}]
		if kind == KIND_TWO:
			# the tail end must be able to see out too, or it is just a one-way arrow
			var tail_dir := arrive_dir(int(path[1]), int(path[0]))
			heads = [{"at": int(path[0]), "dir": tail_dir}, {"at": head, "dir": d}]
		var cand := {"kind": kind, "cells": path, "heads": heads}
		if rng.randf() < float(p.stop) and r.path.size() >= 2:
			cand["stop"] = int(r.path[rng.randi_range(1, r.path.size() - 1)])
		return cand
	return {}

## Random walk backwards from the head: free cells only, convex edges only where they wrap.
## Returns [head, ..., tail] (may be shorter than `length`).
func _grow(rng: RandomNumberGenerator, head: int, d: int, length: int, turn: float, avoid: Array) -> Array:
	var body: Array = [head]
	var seen := {head: true}
	var cur := head
	var dir := opp(d)
	for _i in length - 1:
		var options: Array = [dir]
		var nd := key_normal(cur)
		var side: Array = []
		for t in 6:
			if axis(t) != axis(nd) and axis(t) != axis(dir):
				side.append(t)
		if rng.randf() < 0.5:
			side.reverse()
		if rng.randf() < turn:
			options = side + options
		else:
			options += side
		var moved := false
		for t in options:
			var s := step(cur, int(t))
			if is_cliff(s):
				continue
			var nk := int(s[0])
			if seen.has(nk) or not _free_cell(nk) or avoid.has(nk):
				continue
			body.append(nk)
			seen[nk] = true
			cur = nk
			dir = int(s[1])
			moved = true
			break
		if not moved:
			break
	return body

## A fork: branch 1 runs back from (head, d) to a junction; 1-2 more branches leave the junction
## sideways, each with its own head; a trunk runs on back from the junction.
func _make_fork(rng: RandomNumberGenerator, head: int, d: int, p: Dictionary) -> Dictionary:
	var b1 := _grow(rng, head, d, rng.randi_range(2, 3), 0.0, [])
	if b1.size() < 2:
		return {}
	var j := int(b1[b1.size() - 1])
	var back := arrive_dir(int(b1[b1.size() - 2]), j)  # from the junction away from head 1
	var used := {}
	for c in b1:
		used[int(c)] = true
	var heads: Array = [{"at": head, "dir": d}]
	var cells_all: Array = b1.duplicate()
	var nd := key_normal(j)
	var sides: Array = []
	for t in 6:
		if axis(t) != axis(nd) and axis(t) != axis(back):
			sides.append(t)
	if rng.randf() < 0.5:
		sides.reverse()
	for t in sides:
		var cur := j
		var dir := int(t)
		var br: Array = []
		for _i in rng.randi_range(1, 2):
			var s := step(cur, dir)
			if is_cliff(s):
				break
			var nk := int(s[0])
			if used.has(nk) or not _free_cell(nk):
				break
			br.append(nk)
			cur = nk
			dir = int(s[1])
		if br.is_empty():
			continue
		var r := ray(cur, dir, true)
		if r.result != "exit":
			continue
		var clash := false
		for c in r.path:
			if used.has(int(c)) or br.has(c):
				clash = true
		if clash:
			continue
		for c in br:
			used[int(c)] = true
			cells_all.append(int(c))
		heads.append({"at": cur, "dir": dir})
	if heads.size() < 2:
		return {}
	var trunk := _grow(rng, j, opp(back), rng.randi_range(2, maxi(2, int(p.max_len) - 1)), float(p.turn), [])
	for i in range(1, trunk.size()):
		if used.has(int(trunk[i])):
			break
		cells_all.append(int(trunk[i]))
		used[int(trunk[i])] = true
	for h in heads:
		var r := ray(int(h.at), int(h.dir), true)
		for c in r.path:
			if used.has(int(c)):
				return {}
	return {"kind": KIND_FORK, "cells": cells_all, "heads": heads, "junction": j}

func _random_polycube(rng: RandomNumberGenerator, count: int) -> Array:
	var have := {Vector3i.ZERO: true}
	var guard := 0
	while have.size() < count and guard < 500:
		guard += 1
		var ks: Array = have.keys()
		var v: Vector3i = ks[rng.randi_range(0, ks.size() - 1)] + DIRS[rng.randi_range(0, 5)]
		if v.x < 0 or v.y < 0 or v.z < 0 or v.x > 3 or v.y > 3 or v.z > 3:
			continue
		have[v] = true
	var out: Array = []
	for v in have:
		out.append([v.x, v.y, v.z])
	return out

# ---------- geometry for the view ----------

## World position of a cell's centre (block size 1), lifted `lift` off the face.
func cell_center(k: int, lift: float = 0.0) -> Vector3:
	var p := key_pos(k)
	var nv := Vector3(DIRS[key_normal(k)])
	return (Vector3(p) + Vector3(0.5, 0.5, 0.5) + nv * 0.5) / n + nv * lift

## The point where a line from cell a to neighbour b turns over an edge (faces differ).
func corner_point(a: int, b: int, lift: float = 0.0) -> Vector3:
	var ca := cell_center(a)
	var cb := cell_center(b)
	var ax := axis(key_normal(b))
	var out := ca
	out[ax] = cb[ax]
	var lv := Vector3(DIRS[key_normal(a)]) + Vector3(DIRS[key_normal(b)])
	return out + lv.normalized() * lift

func shape_center() -> Vector3:
	var s := Vector3.ZERO
	for v in voxels:
		s += Vector3(v) + Vector3(0.5, 0.5, 0.5)
	return s / maxf(1.0, voxels.size())

func shape_radius() -> float:
	var c := shape_center()
	var r := 0.0
	for v in voxels:
		for i in 8:
			r = maxf(r, c.distance_to(Vector3(v) + Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)))
	return r
