extends RefCounted

## Tilt Maze -- pure logic, no Nodes (headless-tested by tools/test_tilt_maze.gd).
## Tilt the phone to roll a marble through a maze into the goal hole, around
## the holes that swallow it (back to the start).
##
## Campaign schedule = Maze Trail's (owner, 2026-11-06): six tiers of 30 --
## Very Easy, Easy, Medium, Hard, Very Hard, Insane -- and after every 10 mazes
## one "challenge" maze from the next tier (10 + 1, three times per tier block;
## Insane's block is just 30). 195 levels.
##
## Units are cells: the maze is w x h cells, walls lie on cell edges. Holes:
## "dead" ones fill dead ends, "corner" ones sit in the outer corner of a turn
## on the way (take the bend on the inside), "side" ones on one side of a
## straight stretch (keep to the other side). Every hole is kept only if a
## fine-grid search still finds a safe way from start to goal with room to
## spare, so every level can be done. `generate(params, seed)` is deterministic.

const TIERS := ["Very Easy", "Easy", "Medium", "Hard", "Very Hard", "Insane"]
const PER_TIER := 30
const SNEAK_EVERY := 10
const SNEAKS_PER_TIER := 3
const LEVEL_COUNT := 5 * (PER_TIER + SNEAKS_PER_TIER) + PER_TIER  # 195

const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const BITS := [N, E, S, W]
const OPP := [S, W, N, E]

const BALL_R := 0.24
const WALL_HALF := 0.07
const HOLE_R := 0.3  # drawn size
const FALL_R := 0.22  # the marble drops once its centre is this close to a hole's
const PULL_R := 0.32  # within this, the hole's rim pulls the marble in
const GOAL_R := 0.24
const ACCEL := 15.0  # cells/s^2 at full tilt
const MAX_SPEED := 7.0
const BOUNCE := 0.35
const FALL_TIME := 0.5
const GRID := 8  # fine-grid nodes per cell for the safe-way search
const SAFE_MARGIN := 0.08

## [first, last] of each tier; "friction" = how fast the marble slows (per second).
const TIER_SPEC := [
	{"w": [4, 5], "h": [6, 7], "newest": [1.0, 0.95], "dead": [0, 1], "corner": [0, 0], "side": [0, 0], "friction": 2.2},
	{"w": [5, 6], "h": [7, 9], "newest": [0.95, 0.85], "dead": [1, 3], "corner": [0, 1], "side": [0, 0], "friction": 2.0},
	{"w": [6, 7], "h": [9, 10], "newest": [0.85, 0.7], "dead": [2, 3], "corner": [1, 3], "side": [0, 1], "friction": 1.8},
	{"w": [7, 8], "h": [10, 12], "newest": [0.7, 0.55], "dead": [2, 4], "corner": [2, 4], "side": [1, 3], "friction": 1.6},
	{"w": [8, 9], "h": [12, 13], "newest": [0.55, 0.45], "dead": [3, 4], "corner": [3, 5], "side": [2, 4], "friction": 1.3},
	{"w": [9, 10], "h": [13, 15], "newest": [0.45, 0.35], "dead": [3, 5], "corner": [4, 7], "side": [3, 6], "friction": 0.9},
]

var w: int = 0
var h: int = 0
var walls: PackedByteArray = PackedByteArray()
var start: Vector2i = Vector2i.ZERO
var goal: Vector2i = Vector2i.ZERO
var holes: Array = []  # Vector2 centres (cells)
var friction: float = 2.0
var par: float = 10.0  # seconds for 3 stars
var route_len: float = 0.0  # length of the safe way (cells)

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var time: float = 0.0
var falls: int = 0
var won := false
var falling_t: float = -1.0  # >= 0 while dropping into a hole
var fall_hole := Vector2.ZERO

var _segs := PackedVector2Array()  # wall segments, two points each
var _bucket: Array = []  # cell -> PackedInt32Array of segment indices near it
var _hole_bucket: Array = []  # cell -> Array of hole indices near it
var _wall_free := PackedByteArray()  # fine-grid nodes clear of the walls
var _free := PackedByteArray()  # ... and of the holes

# ---------- the campaign schedule (same as Maze Trail) ----------

static var _schedule: Array = []

static func schedule() -> Array:
	if not _schedule.is_empty():
		return _schedule
	for t in TIERS.size():
		if t < TIERS.size() - 1:
			for r in SNEAKS_PER_TIER:
				for i in SNEAK_EVERY:
					_schedule.append({"tier": t, "idx": r * SNEAK_EVERY + i, "sneak": false})
				_schedule.append({"tier": t + 1, "idx": (r + 1) * 4, "sneak": true})
		else:
			for i in PER_TIER:
				_schedule.append({"tier": t, "idx": i, "sneak": false})
	return _schedule

static func level_info(n: int) -> Dictionary:
	var s := schedule()
	return s[clampi(n, 1, s.size()) - 1]

static func block_of(n: int) -> int:
	return mini((n - 1) / (PER_TIER + SNEAKS_PER_TIER), TIERS.size() - 1)

static func first_level_of_block(b: int) -> int:
	return b * (PER_TIER + SNEAKS_PER_TIER) + 1

static func last_level_of_block(b: int) -> int:
	return LEVEL_COUNT if b >= TIERS.size() - 1 else (b + 1) * (PER_TIER + SNEAKS_PER_TIER)

static func seed_for(n: int) -> int:
	return n * 6151 + 37

static func params_for_tier(t: int, idx: int) -> Dictionary:
	var spec: Dictionary = TIER_SPEC[clampi(t, 0, TIER_SPEC.size() - 1)]
	var f: float = clampf(idx / float(PER_TIER - 1), 0.0, 1.0)
	return {
		"w": int(round(lerpf(spec.w[0], spec.w[1], f))),
		"h": int(round(lerpf(spec.h[0], spec.h[1], f))),
		"newest": lerpf(spec.newest[0], spec.newest[1], f),
		"dead": int(round(lerpf(spec.dead[0], spec.dead[1], f))),
		"corner": int(round(lerpf(spec.corner[0], spec.corner[1], f))),
		"side": int(round(lerpf(spec.side[0], spec.side[1], f))),
		"friction": float(spec.friction),
		"tier": t,
	}

static func params_for(n: int) -> Dictionary:
	var li := level_info(n)
	return params_for_tier(int(li.tier), int(li.idx))

# ---------- generation ----------

func generate(params: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	w = maxi(2, int(params.w))
	h = maxi(2, int(params.h))
	friction = float(params.get("friction", 2.0))
	walls = PackedByteArray()
	walls.resize(w * h)
	walls.fill(N | E | S | W)
	_grow(rng, float(params.get("newest", 1.0)))
	start = Vector2i(rng.randi_range(0, w - 1), h - 1)
	var dist := _cell_distances(start)
	var best := -1
	for x in w:
		if dist[x] > best:
			best = dist[x]
			goal = Vector2i(x, 0)
	_build_segments()
	_build_wall_free()
	holes.clear()
	_place_holes(rng, params)
	var way := safe_way(Vector2(start) + Vector2(0.5, 0.5))
	route_len = _length(way)
	# Par: about 2.1 cells a second along the safe way, plus a moment per hole
	# on it and 1.5 s to get going. Tuned with the bot in tools/test_tilt_maze.gd.
	par = snappedf(route_len / 2.1 + 1.5 + _holes_near(way) * 0.4, 0.5)
	reset()

func _grow(rng: RandomNumberGenerator, newest: float) -> void:
	var visited := PackedByteArray()
	visited.resize(w * h)
	var first := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
	var active: Array = [first]
	visited[_i(first)] = 1
	while not active.is_empty():
		var k: int = active.size() - 1 if rng.randf() < newest else rng.randi_range(0, active.size() - 1)
		var c: Vector2i = active[k]
		var options: Array = []
		for d in 4:
			var nb: Vector2i = c + DIRS[d]
			if _inside(nb) and visited[_i(nb)] == 0:
				options.append(d)
		if options.is_empty():
			active.remove_at(k)
			continue
		var dd: int = options[rng.randi_range(0, options.size() - 1)]
		var nxt: Vector2i = c + DIRS[dd]
		walls[_i(c)] &= ~BITS[dd]
		walls[_i(nxt)] &= ~OPP[dd]
		visited[_i(nxt)] = 1
		active.append(nxt)

func _build_segments() -> void:
	_segs = PackedVector2Array()
	_bucket = []
	_bucket.resize(w * h)
	for i in w * h:
		_bucket[i] = PackedInt32Array()
	for y in h:
		for x in w:
			var wv: int = walls[y * w + x]
			var p := Vector2(x, y)
			if wv & N:
				_add_seg(p, p + Vector2(1, 0))
			if wv & W:
				_add_seg(p, p + Vector2(0, 1))
			if x == w - 1 and wv & E:
				_add_seg(p + Vector2(1, 0), p + Vector2(1, 1))
			if y == h - 1 and wv & S:
				_add_seg(p + Vector2(0, 1), p + Vector2(1, 1))

## A segment goes into the bucket of every cell whose 3x3 block it touches.
func _add_seg(a: Vector2, b: Vector2) -> void:
	var idx := _segs.size() / 2
	_segs.append(a)
	_segs.append(b)
	var lo := Vector2i(int(minf(a.x, b.x)) - 1, int(minf(a.y, b.y)) - 1)
	var hi := Vector2i(int(maxf(a.x, b.x)), int(maxf(a.y, b.y)))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if x >= 0 and y >= 0 and x < w and y < h:
				var arr: PackedInt32Array = _bucket[y * w + x]
				arr.append(idx)
				_bucket[y * w + x] = arr

func _place_holes(rng: RandomNumberGenerator, params: Dictionary) -> void:
	_rebuild_hole_buckets()
	var path := _cell_route(start, goal)
	var on_path := {}
	for c in path:
		on_path[c] = true
	var near_ends := {start: true, goal: true}
	for d in 4:
		near_ends[start + DIRS[d]] = true
		near_ends[goal + DIRS[d]] = true
	# Dead ends off the way.
	var dead: Array = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not on_path.has(c) and not near_ends.has(c) and _open_count(c) == 1:
				dead.append(c)
	_shuffle(dead, rng)
	var want_dead: int = int(params.get("dead", 0))
	for c in dead:
		if want_dead <= 0:
			break
		if _try_hole(Vector2(c) + Vector2(0.5, 0.5)):
			want_dead -= 1
	# Turns and straights on the way.
	var corners: Array = []
	var sides: Array = []
	for i in range(1, path.size() - 1):
		var c: Vector2i = path[i]
		if near_ends.has(c):
			continue
		var a: Vector2i = path[i - 1] - c
		var b: Vector2i = path[i + 1] - c
		if a + b == Vector2i.ZERO:
			sides.append([c, Vector2(a.y, -a.x)])  # perpendicular to the way
		else:
			corners.append([c, -Vector2(a + b)])  # towards the outer corner
	_shuffle(corners, rng)
	_shuffle(sides, rng)
	var want_corner: int = int(params.get("corner", 0))
	for spec in corners:
		if want_corner <= 0:
			break
		if _try_hole(Vector2(spec[0]) + Vector2(0.5, 0.5) + spec[1] * 0.21):
			want_corner -= 1
	var want_side: int = int(params.get("side", 0))
	for spec in sides:
		if want_side <= 0:
			break
		var sgn: float = 1.0 if rng.randf() < 0.5 else -1.0
		if _try_hole(Vector2(spec[0]) + Vector2(0.5, 0.5) + spec[1] * 0.26 * sgn):
			want_side -= 1

## Adds a hole if the marble can still get from start to goal safely.
func _try_hole(c: Vector2) -> bool:
	for o in holes:
		if (o - c).length() < HOLE_R * 2.2:
			return false
	holes.append(c)
	_rebuild_hole_buckets()
	if not _reachable():
		holes.pop_back()
		_rebuild_hole_buckets()
		return false
	return true

## Quick flood fill on the fine grid: can the marble still reach the goal?
func _reachable() -> bool:
	var gw := w * GRID
	var gh := h * GRID
	var s := _node_near(Vector2(start) + Vector2(0.5, 0.5))
	if s < 0:
		return false
	var seen := PackedByteArray()
	seen.resize(gw * gh)
	seen[s] = 1
	var gx0 := goal.x * GRID
	var gy0 := goal.y * GRID
	var q := PackedInt32Array([s])
	var head := 0
	while head < q.size():
		var node: int = q[head]
		head += 1
		var nx := node % gw
		var ny := node / gw
		if nx >= gx0 + 2 and nx < gx0 + GRID - 2 and ny >= gy0 + 2 and ny < gy0 + GRID - 2:
			return true  # in the middle of the goal cell
		if nx > 0 and _free[node - 1] == 1 and seen[node - 1] == 0:
			seen[node - 1] = 1
			q.append(node - 1)
		if nx < gw - 1 and _free[node + 1] == 1 and seen[node + 1] == 0:
			seen[node + 1] = 1
			q.append(node + 1)
		if ny > 0 and _free[node - gw] == 1 and seen[node - gw] == 0:
			seen[node - gw] = 1
			q.append(node - gw)
		if ny < gh - 1 and _free[node + gw] == 1 and seen[node + gw] == 0:
			seen[node + gw] = 1
			q.append(node + gw)
	return false

## The nearest free fine-grid node to `p` in its cell (-1 if none).
func _node_near(p: Vector2) -> int:
	var gw := w * GRID
	var gh := h * GRID
	var cell := Vector2i(clampi(int(p.x), 0, w - 1), clampi(int(p.y), 0, h - 1))
	var best := -1
	var best_d := 1e9
	for gy in range(cell.y * GRID, mini(gh, cell.y * GRID + GRID)):
		for gx in range(cell.x * GRID, mini(gw, cell.x * GRID + GRID)):
			if _free[gy * gw + gx] == 1:
				var d := Vector2((gx + 0.5) / GRID, (gy + 0.5) / GRID).distance_to(p)
				if d < best_d:
					best_d = d
					best = gy * gw + gx
	return best

## A fine-grid node is clear when it is far enough from its own cell's walls
## and from any cell corner where a wall ends or meets (the only other places a
## wall can come close). Same answer as testing every segment, much quicker.
func _build_wall_free() -> void:
	var gw := w * GRID
	var gh := h * GRID
	_wall_free = PackedByteArray()
	_wall_free.resize(gw * gh)
	var need := BALL_R + WALL_HALF + SAFE_MARGIN * 0.25
	var corner := PackedByteArray()
	corner.resize((w + 1) * (h + 1))
	for k in _segs.size():
		var p: Vector2 = _segs[k]
		corner[int(round(p.y)) * (w + 1) + int(round(p.x))] = 1
	for gy in gh:
		for gx in gw:
			var cx := gx / GRID
			var cy := gy / GRID
			var fx := ((gx % GRID) + 0.5) / GRID
			var fy := ((gy % GRID) + 0.5) / GRID
			var wv: int = walls[cy * w + cx]
			var ok := 1
			if (wv & N and fy < need) or (wv & S and 1.0 - fy < need) or (wv & W and fx < need) or (wv & E and 1.0 - fx < need):
				ok = 0
			else:
				for c in 4:
					var ox: int = c % 2
					var oy: int = c / 2
					if corner[(cy + oy) * (w + 1) + cx + ox] == 1 and Vector2(fx - ox, fy - oy).length() < need:
						ok = 0
						break
			_wall_free[gy * gw + gx] = ok
	_free = _wall_free.duplicate()

func _rebuild_hole_buckets() -> void:
	if not _wall_free.is_empty():
		_free = _wall_free.duplicate()
		var gw := w * GRID
		var keep := FALL_R + SAFE_MARGIN
		for hc in holes:
			for gy in range(maxi(0, int((hc.y - 1.0) * GRID)), mini(h * GRID, int((hc.y + 1.0) * GRID))):
				for gx in range(maxi(0, int((hc.x - 1.0) * GRID)), mini(gw, int((hc.x + 1.0) * GRID))):
					if Vector2((gx + 0.5) / GRID, (gy + 0.5) / GRID).distance_to(hc) < keep:
						_free[gy * gw + gx] = 0
	_hole_bucket = []
	_hole_bucket.resize(w * h)
	for i in w * h:
		_hole_bucket[i] = []
	for k in holes.size():
		var hc: Vector2 = holes[k]
		var cx := int(hc.x)
		var cy := int(hc.y)
		for y in range(cy - 1, cy + 2):
			for x in range(cx - 1, cx + 2):
				if x >= 0 and y >= 0 and x < w and y < h:
					_hole_bucket[y * w + x].append(k)

# ---------- the safe way (fine grid) ----------

## Fine-grid points from `from` to the goal (empty if there is no safe way).
## Cheaper through the middle of corridors (keeps the line off the walls).
func safe_way(from: Vector2) -> Array:
	var gw := w * GRID
	var gh := h * GRID
	var cost := PackedFloat64Array()
	cost.resize(gw * gh)
	cost.fill(-1.0)
	var free := _free
	var s0 := _node_near(from)
	if s0 < 0:
		return []
	var s := Vector2i(s0 % gw, s0 / gw)
	var goal_p := Vector2(goal) + Vector2(0.5, 0.5)
	var prev := PackedInt32Array()
	prev.resize(gw * gh)
	prev.fill(-1)
	# Dijkstra with a tiny binary heap (Arrays of [cost, node]).
	var heap: Array = [[0.0, s.y * gw + s.x]]
	cost[s.y * gw + s.x] = 0.0
	var end := -1
	var steps := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var node: int = top[1]
		if top[0] > cost[node]:
			continue
		var nx := node % gw
		var ny := node / gw
		var np := Vector2((nx + 0.5) / GRID, (ny + 0.5) / GRID)
		if np.distance_to(goal_p) < GOAL_R:
			end = node
			break
		for st in steps:
			var mx: int = nx + st.x
			var my: int = ny + st.y
			if mx < 0 or my < 0 or mx >= gw or my >= gh:
				continue
			var m := my * gw + mx
			if free[m] == 0:
				continue
			if st.x != 0 and st.y != 0 and (free[ny * gw + mx] == 0 or free[my * gw + nx] == 0):
				continue
			var step_len: float = 1.4142 if st.x != 0 and st.y != 0 else 1.0
			# Stay near the middle of the corridor: extra cost close to the cell edge.
			var fx: float = fposmod((mx + 0.5) / GRID, 1.0)
			var fy: float = fposmod((my + 0.5) / GRID, 1.0)
			var edge: float = maxf(absf(fx - 0.5), absf(fy - 0.5))
			var nc: float = cost[node] + step_len * (1.0 + edge * 1.5)
			if cost[m] < 0.0 or nc < cost[m]:
				cost[m] = nc
				prev[m] = node
				_heap_push(heap, [nc, m])
	if end < 0:
		return []
	var out: Array = []
	var cur := end
	while cur >= 0:
		out.push_front(Vector2((cur % gw + 0.5) / GRID, (cur / gw + 0.5) / GRID))
		cur = prev[cur]
	out.append(goal_p)
	return out

static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if heap[p][0] <= heap[i][0]:
			break
		var t = heap[p]
		heap[p] = heap[i]
		heap[i] = t
		i = p

static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and heap[l][0] < heap[m][0]:
			m = l
		if r < n and heap[r][0] < heap[m][0]:
			m = r
		if m == i:
			break
		var t = heap[m]
		heap[m] = heap[i]
		heap[i] = t
		i = m
	return top

static func _length(pts: Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] as Vector2).distance_to(pts[i - 1])
	return total

func _holes_near(pts: Array) -> int:
	var n := 0
	for hc in holes:
		for i in range(0, pts.size(), 2):
			if (pts[i] as Vector2).distance_to(hc) < 0.8:
				n += 1
				break
	return n

# ---------- play ----------

func reset() -> void:
	pos = Vector2(start) + Vector2(0.5, 0.5)
	vel = Vector2.ZERO
	time = 0.0
	falls = 0
	won = false
	falling_t = -1.0

## Advances the marble by `dt` seconds under `tilt` (each axis -1..1; +x = right
## side down, +y = top raised, so the marble rolls down the screen). Returns
## events: ["hit", speed] on a wall knock, ["fall"] into a hole, ["back"] once
## it is back at the start, ["win"].
func update(dt: float, tilt: Vector2) -> Array:
	var ev: Array = []
	if won:
		return ev
	time += dt
	if falling_t >= 0.0:
		falling_t += dt
		pos = pos.lerp(fall_hole, minf(1.0, dt * 12.0))
		if falling_t >= FALL_TIME:
			falling_t = -1.0
			pos = Vector2(start) + Vector2(0.5, 0.5)
			vel = Vector2.ZERO
			ev.append(["back"])
		return ev
	if tilt.length() > 1.0:
		tilt = tilt.normalized()
	var steps := maxi(1, ceili((vel.length() * dt) / 0.06))
	var sdt := dt / steps
	var hit_speed := 0.0
	for _i2 in steps:
		vel += tilt * ACCEL * sdt
		# Rim of a nearby hole pulls the marble in a little.
		var cell := Vector2i(int(pos.x), int(pos.y))
		if _inside(cell):
			for k in _hole_bucket[_i(cell)]:
				var to: Vector2 = holes[k] - pos
				var d := to.length()
				if d < PULL_R and d > 0.001:
					vel += to / d * 3.0 * (1.0 - d / PULL_R) * sdt
		vel *= 1.0 / (1.0 + friction * sdt)
		if vel.length() > MAX_SPEED:
			vel = vel.normalized() * MAX_SPEED
		pos += vel * sdt
		hit_speed = maxf(hit_speed, _collide())
		# Goal and holes.
		var goal_p := Vector2(goal) + Vector2(0.5, 0.5)
		if pos.distance_to(goal_p) < GOAL_R:
			won = true
			vel = Vector2.ZERO
			ev.append(["win"])
			return ev
		cell = Vector2i(int(pos.x), int(pos.y))
		if _inside(cell):
			for k in _hole_bucket[_i(cell)]:
				if pos.distance_to(holes[k]) < FALL_R:
					falls += 1
					falling_t = 0.0
					fall_hole = holes[k]
					vel = Vector2.ZERO
					ev.append(["fall"])
					return ev
	if hit_speed > 0.8:
		ev.append(["hit", hit_speed])
	return ev

## Pushes the marble out of any wall it overlaps; returns the hardest knock.
func _collide() -> float:
	var cell := Vector2i(clampi(int(pos.x), 0, w - 1), clampi(int(pos.y), 0, h - 1))
	var need := BALL_R + WALL_HALF
	var knock := 0.0
	for _pass in 2:
		var segs: PackedInt32Array = _bucket[_i(cell)]
		for s in segs:
			var q := Geometry2D.get_closest_point_to_segment(pos, _segs[s * 2], _segs[s * 2 + 1])
			var off := pos - q
			var d := off.length()
			if d < need:
				var n := off / d if d > 0.0001 else Vector2(0, -1)
				pos = q + n * need
				var vn := vel.dot(n)
				if vn < 0.0:
					knock = maxf(knock, -vn)
					vel -= n * vn * (1.0 + BOUNCE)
		var nc := Vector2i(clampi(int(pos.x), 0, w - 1), clampi(int(pos.y), 0, h - 1))
		if nc == cell:
			break
		cell = nc
	# Never leave the board.
	pos.x = clampf(pos.x, need, w - need)
	pos.y = clampf(pos.y, need, h - need)
	return knock

## 3 stars: no falls and within par; 2: at most one fall and within 1.6x par; else 1.
func stars() -> int:
	if falls == 0 and time <= par:
		return 3
	if falls <= 1 and time <= par * 1.6:
		return 2
	return 1

# ---------- helpers ----------

func _cell_distances(from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	dist[_i(from)] = 0
	var q: Array = [from]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d in 4:
			if walls[_i(cur)] & BITS[d]:
				continue
			var nb: Vector2i = cur + DIRS[d]
			if dist[_i(nb)] < 0:
				dist[_i(nb)] = dist[_i(cur)] + 1
				q.append(nb)
	return dist

func _cell_route(from: Vector2i, to: Vector2i) -> Array:
	var prev := {from: from}
	var q: Array = [from]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		if cur == to:
			break
		for d in 4:
			if walls[_i(cur)] & BITS[d]:
				continue
			var nb: Vector2i = cur + DIRS[d]
			if not prev.has(nb):
				prev[nb] = cur
				q.append(nb)
	var path: Array = [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return path

func _open_count(c: Vector2i) -> int:
	var n := 0
	for d in 4:
		if walls[_i(c)] & BITS[d] == 0:
			n += 1
	return n

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t

func _i(c: Vector2i) -> int:
	return c.y * w + c.x

func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h
