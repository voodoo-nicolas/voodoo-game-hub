extends RefCounted

## Maze Trail -- pure logic, no Nodes (headless-tested by tools/test_maze_trail.gd).
##
## Campaign (owner, 2026-11-06): six tiers of 30 mazes -- Very Easy, Easy,
## Medium, Hard, Very Hard, Insane. While you play a tier, every 10th maze is
## followed by one maze from the NEXT tier (a "challenge" maze), so a tier block
## reads 10 + 1 + 10 + 1 + 10 + 1. Insane has no next tier: its block is just 30.
## 5 x 33 + 30 = 195 levels.
##
## A maze is a perfect maze (one way between any two cells) grown by a seeded
## "growing tree": newest-cell picking makes long winding corridors (easy),
## random picking makes many short dead ends (hard). Medium and up may add
## gates that only open with their key; Very Hard and Insane may add fog
## (you only see near you and where you have been). `generate(params, seed)`
## is deterministic, so a level is the same maze on every phone.

const TIERS := ["Very Easy", "Easy", "Medium", "Hard", "Very Hard", "Insane"]
const PER_TIER := 30
const SNEAK_EVERY := 10
const SNEAKS_PER_TIER := 3
const LEVEL_COUNT := 5 * (PER_TIER + SNEAKS_PER_TIER) + PER_TIER  # 195

## Walls: bit set = wall on that side.
const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const BITS := [N, E, S, W]
const OPP := [S, W, N, E]

## Per tier: width and height at the first and last maze of the tier, how
## often the generator picks the newest cell (1 = long corridors), keys
## (gates) and fog radius (0 = none), each as [first, last] or a rule.
const TIER_SPEC := [
	{"w": [5, 6], "h": [7, 9], "newest": [1.0, 0.95], "keys": 0, "fog": 0},
	{"w": [6, 8], "h": [9, 12], "newest": [0.95, 0.8], "keys": 0, "fog": 0},
	{"w": [8, 10], "h": [12, 14], "newest": [0.8, 0.6], "keys": 1, "fog": 0},
	{"w": [10, 11], "h": [14, 16], "newest": [0.6, 0.45], "keys": 1, "fog": 0},
	{"w": [11, 13], "h": [16, 19], "newest": [0.45, 0.35], "keys": 2, "fog": 4},
	{"w": [13, 15], "h": [19, 22], "newest": [0.35, 0.25], "keys": 2, "fog": 3},
]

var w: int = 0
var h: int = 0
var walls: PackedByteArray = PackedByteArray()
var start: Vector2i = Vector2i.ZERO
var exit: Vector2i = Vector2i.ZERO
var player: Vector2i = Vector2i.ZERO
## Keys and gates: key i opens gate i. {"pos": Vector2i, "got"/"open": bool}
var keys: Array = []
var gates: Array = []
var fog: int = 0
var steps: int = 0
var par: int = 0  # fewest steps from start to exit (keys included)
var seen: PackedByteArray = PackedByteArray()  # cells revealed (fog levels)
var trail: Array = []  # cells from the start to the player (back-steps pop it)
var won := false

# ---------- the campaign schedule ----------

static var _schedule: Array = []

## Every level as {"tier", "idx" (0..29 in its tier), "sneak" (a challenge from the next tier)}.
static func schedule() -> Array:
	if not _schedule.is_empty():
		return _schedule
	for t in TIERS.size():
		if t < TIERS.size() - 1:
			for r in SNEAKS_PER_TIER:
				for i in SNEAK_EVERY:
					_schedule.append({"tier": t, "idx": r * SNEAK_EVERY + i, "sneak": false})
				# One maze from the next tier, from its easy end (4, 8, 12 of 30).
				_schedule.append({"tier": t + 1, "idx": (r + 1) * 4, "sneak": true})
		else:
			for i in PER_TIER:
				_schedule.append({"tier": t, "idx": i, "sneak": false})
	return _schedule

static func level_info(n: int) -> Dictionary:
	var s := schedule()
	return s[clampi(n, 1, s.size()) - 1]

## The tier whose block a level sits in (a challenge maze belongs to the block before its own tier).
static func block_of(n: int) -> int:
	return mini((n - 1) / (PER_TIER + SNEAKS_PER_TIER), TIERS.size() - 1)

static func first_level_of_block(b: int) -> int:
	return b * (PER_TIER + SNEAKS_PER_TIER) + 1

static func last_level_of_block(b: int) -> int:
	return LEVEL_COUNT if b >= TIERS.size() - 1 else (b + 1) * (PER_TIER + SNEAKS_PER_TIER)

static func seed_for(n: int) -> int:
	return n * 7919 + 101

## Generator settings for tier `t`, maze `idx` (0..29) of that tier.
static func params_for_tier(t: int, idx: int) -> Dictionary:
	var spec: Dictionary = TIER_SPEC[clampi(t, 0, TIER_SPEC.size() - 1)]
	var f: float = clampf(idx / float(PER_TIER - 1), 0.0, 1.0)
	var keys_n: int = 0
	match int(spec.keys):
		1:
			keys_n = 1 if idx % 3 == 2 or (t >= 3 and idx % 2 == 1) else 0
		2:
			keys_n = 2 if idx % 3 == 2 else (1 if idx % 3 == 1 else 0)
	var fog_r: int = 0
	if int(spec.fog) > 0:
		# Very Hard: every other maze in fog; Insane: all of them.
		fog_r = int(spec.fog) if (t >= 5 or idx % 2 == 1) else 0
	return {
		"w": int(round(lerpf(spec.w[0], spec.w[1], f))),
		"h": int(round(lerpf(spec.h[0], spec.h[1], f))),
		"newest": lerpf(spec.newest[0], spec.newest[1], f),
		"keys": keys_n,
		"fog": fog_r,
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
	fog = int(params.get("fog", 0))
	walls = PackedByteArray()
	walls.resize(w * h)
	walls.fill(N | E | S | W)
	_grow(rng, float(params.get("newest", 1.0)))
	# Start on the bottom row, exit the farthest top-row cell from it.
	start = Vector2i(rng.randi_range(0, w - 1), h - 1)
	var dist := distances(start)
	var best := -1
	for x in w:
		var d: int = dist[x]
		if d > best:
			best = d
			exit = Vector2i(x, 0)
	keys.clear()
	gates.clear()
	var want: int = int(params.get("keys", 0))
	if want > 0:
		_place_keys(rng, want)
	reset()

## Growing tree: pick the newest cell with probability `newest`, else a random one.
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

## Gates sit on the one way from start to exit (the maze is perfect, so there is
## no way round). Key i lies in a side branch you can reach before gate i, as
## deep in its branch as possible, and after gate i-1 when it can.
func _place_keys(rng: RandomNumberGenerator, count: int) -> void:
	var path := route(start, exit, false)
	if path.size() < 8:
		return
	var on_path := {}
	for c in path:
		on_path[c] = true
	var depth := _depth_map(path)
	var spans := [[0.45, 0.7]] if count == 1 else [[0.3, 0.45], [0.6, 0.8]]
	for k in count:
		var lo: int = maxi(2, int(path.size() * spans[k][0]))
		var hi: int = mini(path.size() - 3, int(path.size() * spans[k][1]))
		if hi < lo:
			continue
		var gpos: Vector2i = path[rng.randi_range(lo, hi)]
		# Cells reachable from the start with this gate (and later ones) shut.
		var blocked := {gpos: true}
		var reach_now := _reach(start, blocked)
		var reach_before := {}
		if not gates.is_empty():
			var prev_block := {gates[gates.size() - 1].pos: true, gpos: true}
			reach_before = _reach(start, prev_block)
		# Depth of each candidate from the main path.
		var best_c := Vector2i(-1, -1)
		var best_score := -1.0
		for c in reach_now:
			if on_path.has(c) or c == start:
				continue
			var taken := false
			for kk in keys:
				if kk.pos == c:
					taken = true
			if taken:
				continue
			var score: float = depth[_i(c)] + rng.randf() * 0.5
			if not gates.is_empty() and not reach_before.has(c):
				score += 100.0  # needs the first gate open: keeps the order
			if score > best_score:
				best_score = score
				best_c = c
		if best_c.x < 0:
			continue
		gates.append({"pos": gpos, "open": false})
		keys.append({"pos": best_c, "got": false})

## Steps from each cell to the nearest cell of `path` (one BFS from all of it).
func _depth_map(path: Array) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	var q: Array = []
	for c in path:
		dist[_i(c)] = 0
		q.append(c)
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

func _reach(from: Vector2i, blocked: Dictionary) -> Dictionary:
	var out := {from: true}
	var q: Array = [from]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in 4:
			if walls[_i(cur)] & BITS[d]:
				continue
			var nb: Vector2i = cur + DIRS[d]
			if out.has(nb) or blocked.has(nb):
				continue
			out[nb] = true
			q.append(nb)
	return out

# ---------- play ----------

func reset() -> void:
	player = start
	steps = 0
	won = false
	for k in keys:
		k.got = false
	for g in gates:
		g.open = false
	seen = PackedByteArray()
	seen.resize(w * h)
	trail = [start]
	_reveal()
	par = _solve_steps()

func is_open(c: Vector2i, d: int) -> bool:
	return _inside(c) and walls[_i(c)] & BITS[d] == 0

## Index of the gate at `c` (-1 if none).
func gate_at(c: Vector2i) -> int:
	for i in gates.size():
		if gates[i].pos == c:
			return i
	return -1

func key_at(c: Vector2i) -> int:
	for i in keys.size():
		if keys[i].pos == c and not keys[i].got:
			return i
	return -1

func can_enter(c: Vector2i) -> bool:
	var g := gate_at(c)
	return g < 0 or gates[g].open or keys[g].got

## One step in direction `d` (0 N, 1 E, 2 S, 3 W). Returns "" (blocked),
## "move", "key" (picked a key up), "gate" (opened one) or "win".
func step(d: int) -> String:
	if won or not is_open(player, d):
		return ""
	var nxt: Vector2i = player + DIRS[d]
	if not can_enter(nxt):
		return "locked"
	player = nxt
	steps += 1
	if trail.size() >= 2 and trail[trail.size() - 2] == nxt:
		trail.pop_back()
	else:
		trail.append(nxt)
	_reveal()
	var result := "move"
	var g := gate_at(nxt)
	if g >= 0 and not gates[g].open:
		gates[g].open = true
		result = "gate"
	var k := key_at(nxt)
	if k >= 0:
		keys[k].got = true
		result = "key"
	if player == exit:
		won = true
		result = "win"
	return result

## Open directions out of `c` (count).
func exits_of(c: Vector2i) -> int:
	var n := 0
	for d in 4:
		if is_open(c, d):
			n += 1
	return n

## Runs in direction `d` until a junction, a dead end, a key/gate or the exit.
## Returns the list of step results (empty = could not move).
func run(d: int) -> Array:
	var out: Array = []
	var dir := d
	var guard := w * h
	while guard > 0:
		guard -= 1
		var r := step(dir)
		if r == "" or r == "locked":
			if out.is_empty():
				out.append(r)
			break
		out.append(r)
		if r != "move" or exits_of(player) != 2:
			break
		# Follow the corridor round its bend (never turn back).
		var back: int = (dir + 2) % 4
		var nd := -1
		for dd in 4:
			if dd != back and is_open(player, dd):
				nd = dd
		if nd < 0:
			break
		dir = nd
	return out

func _reveal() -> void:
	if fog <= 0:
		seen.fill(1)
		return
	for y in range(player.y - fog, player.y + fog + 1):
		for x in range(player.x - fog, player.x + fog + 1):
			var c := Vector2i(x, y)
			if _inside(c) and (c - player).length_squared() <= fog * fog + 1:
				seen[_i(c)] = 1

func is_seen(c: Vector2i) -> bool:
	return _inside(c) and seen[_i(c)] != 0

## Within the light radius right now (fog levels).
func is_lit(c: Vector2i) -> bool:
	return fog <= 0 or (c - player).length_squared() <= fog * fog + 1

# ---------- solving ----------

## Fewest steps between two cells ignoring gates (perfect maze: the one way).
func route(from: Vector2i, to: Vector2i, honour_gates: bool = true) -> Array:
	var prev := {from: from}
	var q: Array = [from]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur == to:
			break
		for d in 4:
			if not is_open(cur, d):
				continue
			var nb: Vector2i = cur + DIRS[d]
			if prev.has(nb):
				continue
			if honour_gates and not can_enter(nb):
				continue
			prev[nb] = cur
			q.append(nb)
	if not prev.has(to):
		return []
	var path: Array = [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return path

func distances(from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	dist[_i(from)] = 0
	var q: Array = [from]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in 4:
			if not is_open(cur, d):
				continue
			var nb: Vector2i = cur + DIRS[d]
			if dist[_i(nb)] < 0:
				dist[_i(nb)] = dist[_i(cur)] + 1
				q.append(nb)
	return dist

## The whole way to the exit from where the player stands, with the keys still
## to fetch: a list of cells (first = the next cell to step on). Empty if won.
func solution_from_here() -> Array:
	if won:
		return []
	var mask := 0
	for i in keys.size():
		if keys[i].got:
			mask |= 1 << i
	var res := _bfs_state(player, mask)
	return res

func _solve_steps() -> int:
	var p := _bfs_state(start, 0)
	return p.size()

## BFS over (cell, keys held). Returns the cells after `from` up to the exit.
func _bfs_state(from: Vector2i, mask0: int) -> Array:
	var start_key := _skey(from, _pick(from, mask0))
	var prev := {start_key: -1}
	var q: Array = [start_key]
	var goal := -1
	while not q.is_empty():
		var s: int = q.pop_front()
		var c := Vector2i((s >> 4) % w, (s >> 4) / w)
		var mask: int = s & 15
		if c == exit:
			goal = s
			break
		for d in 4:
			if not is_open(c, d):
				continue
			var nb: Vector2i = c + DIRS[d]
			var g := gate_at(nb)
			if g >= 0 and not gates[g].open and mask & (1 << g) == 0:
				continue
			var ns := _skey(nb, _pick(nb, mask))
			if prev.has(ns):
				continue
			prev[ns] = s
			q.append(ns)
	if goal < 0:
		return []
	var out: Array = []
	var cur := goal
	while cur != start_key:
		out.push_front(Vector2i((cur >> 4) % w, (cur >> 4) / w))
		cur = prev[cur]
	return out

func _pick(c: Vector2i, mask: int) -> int:
	for i in keys.size():
		if keys[i].pos == c:
			mask |= 1 << i
	return mask

func _skey(c: Vector2i, mask: int) -> int:
	return (_i(c) << 4) | mask

## 3 stars: within 30% of the fewest steps; 2: within 2.2x; else 1.
func stars() -> int:
	if steps <= ceili(par * 1.3):
		return 3
	if steps <= ceili(par * 2.2):
		return 2
	return 1

# ---------- save ----------

func to_dict() -> Dictionary:
	var kg: Array = []
	for k in keys:
		kg.append(1 if k.got else 0)
	var go: Array = []
	for g in gates:
		go.append(1 if g.open else 0)
	var tr_out: Array = []
	for c in trail:
		tr_out.append(_i(c))
	return {"p": _i(player), "steps": steps, "keys": kg, "gates": go,
		"seen": Array(seen), "trail": tr_out}

func from_dict(d: Dictionary) -> void:
	var p: int = int(d.get("p", _i(start)))
	if p < 0 or p >= w * h:
		return
	player = Vector2i(p % w, p / w)
	steps = int(d.get("steps", 0))
	var kg: Array = d.get("keys", [])
	for i in mini(kg.size(), keys.size()):
		keys[i].got = int(kg[i]) == 1
	var go: Array = d.get("gates", [])
	for i in mini(go.size(), gates.size()):
		gates[i].open = int(go[i]) == 1
	var sn: Array = d.get("seen", [])
	if sn.size() == w * h:
		for i in sn.size():
			seen[i] = int(sn[i])
	trail.clear()
	for v in d.get("trail", []):
		var iv := int(v)
		if iv >= 0 and iv < w * h:
			trail.append(Vector2i(iv % w, iv / w))
	if trail.is_empty() or trail[trail.size() - 1] != player:
		trail = [player]
	_reveal()

# ---------- helpers ----------

func _i(c: Vector2i) -> int:
	return c.y * w + c.x

func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h
