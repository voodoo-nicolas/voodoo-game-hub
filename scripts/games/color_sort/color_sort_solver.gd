extends RefCounted

## Solver for Color Sort (same rules as color_sort_engine.gd: a pour moves the
## whole top run of one colour, as much as fits). A* over the vial arrangement.
## Heuristic: (colour runs on the board) - (colours), which never overestimates
## because one pour removes at most one run. weight 1.0 = optimal; a bigger
## weight finds a good (not always shortest) answer much faster on big boards.
## Vials are interchangeable, so states are keyed with the vials sorted -- unless
## the level has locks or blocked pours, which tie rules to particular vials.
##
## `center` ({} = none, else {"order": colours, "seg": balls per colour, "size": filled
## now}) is the big central vial: only the colour it wants next may be poured in,
## and it must be full at the end. Pours into it are move [from, -2].
##
## `rules` (all optional) are the special-level rules:
##   "locks":   [{"v": vial, "pours": N} | {"v": vial, "after": other vial}, ...]
##              a locked vial can be neither poured from nor into; it opens once N
##              pours were made, or while the other vial is complete (full, one colour)
##   "blocked": [[a, b], ...]  no pour between these two vials, either way
##   "drain":   D  every D-th pour the central vial leaks its top layer back into
##              the first vial with room (if it is not full)
##   "moves0":  pours already made (so "pours" locks and the drain stay in step)

const NO_VIAL := -1

var _tubes_n: int = 0
var _cap: int = 0
var _order: Array = []
var _seg: int = 0
var _total: int = 0
var _targets := {}
var _locks: Array = []
var _blocked := {}
var _drain: int = 0
var _identity: bool = false
var _max_pours: int = 0

var _states: Array = []
var _csize := PackedInt32Array()
var _mvs := PackedInt32Array()
var _parent := PackedInt32Array()
var _move_from := PackedInt32Array()
var _move_to := PackedInt32Array()
var _gs := PackedInt32Array()
var _best := {}
var _heap_pri := PackedFloat64Array()
var _heap_idx := PackedInt32Array()
var _weight: float = 1.0

## Returns {"ok": bool, "moves": [[from, to], ...], "optimal": bool, "nodes": int}
## `moves` index the vials of `tubes` as given. Stops after `node_limit` states.
static func solve(tubes: Array, cap: int, node_limit: int = 40000, weight: float = 1.0, center: Dictionary = {}, rules: Dictionary = {}) -> Dictionary:
	var s = new()
	return s._run(tubes, cap, node_limit, weight, center, rules)

func _run(tubes: Array, cap: int, node_limit: int, weight: float, center: Dictionary, rules: Dictionary) -> Dictionary:
	_tubes_n = tubes.size()
	_cap = cap
	_weight = weight
	_order = center.get("order", [])
	_seg = int(center.get("seg", 0))
	_total = _order.size() * _seg
	for c in _order:
		_targets[c] = true
	_locks = rules.get("locks", [])
	for p in rules.get("blocked", []):
		_blocked["%d,%d" % [p[0], p[1]]] = true
		_blocked["%d,%d" % [p[1], p[0]]] = true
	_drain = int(rules.get("drain", 0))
	_identity = not _locks.is_empty() or not _blocked.is_empty()
	for l in _locks:
		_max_pours = maxi(_max_pours, int(l.get("pours", 0)))
	var mv0: int = int(rules.get("moves0", 0))
	_states = [_copy(tubes)]
	_csize = PackedInt32Array([int(center.get("size", 0))])
	_mvs = PackedInt32Array([mv0])
	_parent = PackedInt32Array([-1])
	_move_from = PackedInt32Array([-1])
	_move_to = PackedInt32Array([-1])
	_gs = PackedInt32Array([0])
	_best = {_key(tubes, _csize[0], mv0): 0}
	_push(weight * _h(tubes), 0)
	var nodes := 0
	while _heap_idx.size() > 0 and nodes < node_limit:
		var cur: int = _pop()
		var st: Array = _states[cur]
		var cs: int = _csize[cur]
		var mv: int = _mvs[cur]
		nodes += 1
		if cs == _total and _is_solved(st, cap):
			var path: Array = []
			var n := cur
			while _parent[n] >= 0:
				path.push_front([_move_from[n], _move_to[n]])
				n = _parent[n]
			return {"ok": true, "moves": path, "optimal": weight <= 1.0 and _drain == 0, "nodes": nodes}
		var g: int = _gs[cur] + 1
		for a in st.size():
			var ta: Array = st[a]
			if ta.is_empty() or locked(st, cap, a, mv, _locks):
				continue
			var run := run_of(ta)
			var mono: bool = run == ta.size()
			for b in st.size():
				if a == b or _blocked.has("%d,%d" % [a, b]):
					continue
				var tb: Array = st[b]
				if tb.size() >= cap or locked(st, cap, b, mv, _locks):
					continue
				if tb.is_empty():
					if mono and not _identity:
						continue  # only moves a whole vial to another place
				elif tb[tb.size() - 1] != ta[ta.size() - 1]:
					continue
				var amount: int = mini(run, cap - tb.size())
				var nxt: Array = _copy(st)
				for i in amount:
					nxt[b].append(nxt[a].pop_back())
				_add(nxt, cs, mv + 1, cur, a, b, g)
			if cs < _total and ta[ta.size() - 1] == _order[cs / _seg]:
				var seg_end: int = (cs / _seg + 1) * _seg
				var amount2: int = mini(run, seg_end - cs)
				var nxt2: Array = _copy(st)
				for i in amount2:
					nxt2[a].pop_back()
				_add(nxt2, cs + amount2, mv + 1, cur, a, -2, g)
	return {"ok": false, "moves": [], "optimal": false, "nodes": nodes}

## Adds a reached state (after the drain, if one is due) unless a path at least as short is known.
func _add(nxt: Array, ncs: int, nmv: int, cur: int, a: int, b: int, g: int) -> void:
	if _drain > 0 and nmv % _drain == 0 and ncs > 0 and ncs < _total:
		var v := leak_target(nxt, _cap)
		if v != NO_VIAL:
			nxt[v].append(_order[(ncs - 1) / _seg])
			ncs -= 1
	var k := _key(nxt, ncs, nmv)
	if _best.has(k) and int(_best[k]) <= g:
		return
	_best[k] = g
	_states.append(nxt)
	_csize.append(ncs)
	_mvs.append(nmv)
	_parent.append(cur)
	_move_from.append(a)
	_move_to.append(b)
	_gs.append(g)
	_push(g + _weight * _h(nxt) - g * 0.001, _states.size() - 1)

## ---------- rules shared with the engine ----------

## Is vial v locked now? `mv` = pours made so far.
static func locked(tubes: Array, cap: int, v: int, mv: int, locks: Array) -> bool:
	for l in locks:
		if int(l.v) != v:
			continue
		if l.has("pours"):
			if mv < int(l.pours):
				return true
		elif l.has("after"):
			var o: Array = tubes[int(l.after)]
			if o.size() != cap or run_of(o) != cap:
				return true
	return false

## The vial a draining central vial leaks into: the first with room, or NO_VIAL.
static func leak_target(tubes: Array, cap: int) -> int:
	for i in tubes.size():
		if tubes[i].size() < cap:
			return i
	return NO_VIAL

## Length of the colour run on top of a vial.
static func run_of(t: Array) -> int:
	var n := 1
	while n < t.size() and t[t.size() - 1 - n] == t[t.size() - 1]:
		n += 1
	return n

static func _is_solved(tubes: Array, cap: int) -> bool:
	for t in tubes:
		if t.is_empty():
			continue
		if t.size() != cap:
			return false
		for c in t:
			if c != t[0]:
				return false
	return true

## (colour runs on the board) - (colours that stay in small vials); every run of a
## central-vial colour must still be poured in, so those count fully.
func _h(tubes: Array) -> float:
	var runs := 0
	var seen := {}
	for t in tubes:
		for i in t.size():
			if not _targets.has(t[i]):
				seen[t[i]] = true
			if i == 0 or t[i] != t[i - 1]:
				runs += 1
	return float(runs - seen.size())

static func _copy(tubes: Array) -> Array:
	var out: Array = []
	for t in tubes:
		out.append(t.duplicate())
	return out

func _key(tubes: Array, cs: int, mv: int) -> String:
	var parts := PackedStringArray()
	for t in tubes:
		var s := ""
		for c in t:
			s += char(97 + int(c))
		parts.append(s)
	if not _identity:
		parts.sort()
	var tail: String = "#" + str(cs)
	if _max_pours > 0:
		tail += "#" + str(mini(mv, _max_pours))
	if _drain > 0:
		tail += "#" + str(mv % _drain)
	return "|".join(parts) + tail

# ---------- binary min-heap on parallel arrays ----------

func _push(p: float, i: int) -> void:
	_heap_pri.append(p)
	_heap_idx.append(i)
	var c := _heap_pri.size() - 1
	while c > 0:
		var par := (c - 1) / 2
		if _heap_pri[par] <= _heap_pri[c]:
			break
		var tp := _heap_pri[par]
		_heap_pri[par] = _heap_pri[c]
		_heap_pri[c] = tp
		var ti := _heap_idx[par]
		_heap_idx[par] = _heap_idx[c]
		_heap_idx[c] = ti
		c = par

func _pop() -> int:
	var top := _heap_idx[0]
	var last := _heap_pri.size() - 1
	_heap_pri[0] = _heap_pri[last]
	_heap_idx[0] = _heap_idx[last]
	_heap_pri.resize(last)
	_heap_idx.resize(last)
	var c := 0
	while true:
		var l := c * 2 + 1
		var r := l + 1
		var m := c
		if l < last and _heap_pri[l] < _heap_pri[m]:
			m = l
		if r < last and _heap_pri[r] < _heap_pri[m]:
			m = r
		if m == c:
			break
		var tp := _heap_pri[m]
		_heap_pri[m] = _heap_pri[c]
		_heap_pri[c] = tp
		var ti := _heap_idx[m]
		_heap_idx[m] = _heap_idx[c]
		_heap_idx[c] = ti
		c = m
	return top
