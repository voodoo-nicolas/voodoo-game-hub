extends RefCounted

## Solver for Color Sort (same rules as color_sort_engine.gd: a pour moves the
## whole top run of one colour, as much as fits). A* over the vial arrangement.
## Heuristic: (colour runs on the board) - (colours), which never overestimates
## because one pour removes at most one run. weight 1.0 = optimal; a bigger
## weight finds a good (not always shortest) answer much faster on big boards.
## Vials are interchangeable, so states are keyed with the vials sorted.
## `center` ({} = none, else {"order": colours, "seg": balls per colour, "size": filled
## now}) is the big central vial: only the colour it wants next may be poured in,
## and it must be full at the end. Pours into it are move [from, -2].

## Returns {"ok": bool, "moves": [[from, to], ...], "optimal": bool, "nodes": int}
## `moves` index the vials of `tubes` as given. Stops after `node_limit` states.
static func solve(tubes: Array, cap: int, node_limit: int = 40000, weight: float = 1.0, center: Dictionary = {}) -> Dictionary:
	var order: Array = center.get("order", [])
	var seg: int = int(center.get("seg", 0))
	var total: int = order.size() * seg
	var targets := {}
	for c in order:
		targets[c] = true
	var states: Array = [_copy(tubes)]
	var csize := PackedInt32Array([int(center.get("size", 0))])
	var parent := PackedInt32Array([-1])
	var move_from := PackedInt32Array([-1])
	var move_to := PackedInt32Array([-1])
	var gs := PackedInt32Array([0])
	var best := {_key(tubes, csize[0]): 0}
	var heap_pri := PackedFloat64Array()
	var heap_idx := PackedInt32Array()
	_push(heap_pri, heap_idx, weight * _h(tubes, targets), 0)
	var nodes := 0
	while heap_idx.size() > 0 and nodes < node_limit:
		var cur: int = _pop(heap_pri, heap_idx)
		var st: Array = states[cur]
		var cs: int = csize[cur]
		nodes += 1
		if cs == total and _is_solved(st, cap):
			var path: Array = []
			var n := cur
			while parent[n] >= 0:
				path.push_front([move_from[n], move_to[n]])
				n = parent[n]
			return {"ok": true, "moves": path, "optimal": weight <= 1.0, "nodes": nodes}
		var g: int = gs[cur] + 1
		for a in st.size():
			var ta: Array = st[a]
			if ta.is_empty():
				continue
			var run := run_of(ta)
			var mono: bool = run == ta.size()
			for b in st.size():
				if a == b:
					continue
				var tb: Array = st[b]
				if tb.size() >= cap:
					continue
				if tb.is_empty():
					if mono:
						continue  # only moves a whole vial to another place
				elif tb[tb.size() - 1] != ta[ta.size() - 1]:
					continue
				var amount: int = mini(run, cap - tb.size())
				var nxt: Array = _copy(st)
				for i in amount:
					nxt[b].append(nxt[a].pop_back())
				_add(nxt, cs, cur, a, b, g, weight, targets, best, states, parent, move_from, move_to, gs, csize, heap_pri, heap_idx)
			if cs < total and ta[ta.size() - 1] == order[cs / seg]:
				var seg_end: int = (cs / seg + 1) * seg
				var amount2: int = mini(run, seg_end - cs)
				var nxt2: Array = _copy(st)
				for i in amount2:
					nxt2[a].pop_back()
				_add(nxt2, cs + amount2, cur, a, -2, g, weight, targets, best, states, parent, move_from, move_to, gs, csize, heap_pri, heap_idx)
	return {"ok": false, "moves": [], "optimal": false, "nodes": nodes}

## Adds a reached state to the search unless a path at least as short is known.
static func _add(nxt: Array, ncs: int, cur: int, a: int, b: int, g: int, weight: float, targets: Dictionary,
		best: Dictionary, states: Array, parent: PackedInt32Array, move_from: PackedInt32Array,
		move_to: PackedInt32Array, gs: PackedInt32Array, csize: PackedInt32Array,
		heap_pri: PackedFloat64Array, heap_idx: PackedInt32Array) -> void:
	var k := _key(nxt, ncs)
	if best.has(k) and int(best[k]) <= g:
		return
	best[k] = g
	states.append(nxt)
	parent.append(cur)
	move_from.append(a)
	move_to.append(b)
	gs.append(g)
	csize.append(ncs)
	_push(heap_pri, heap_idx, g + weight * _h(nxt, targets) - g * 0.001, states.size() - 1)

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
static func _h(tubes: Array, targets: Dictionary) -> float:
	var runs := 0
	var seen := {}
	for t in tubes:
		for i in t.size():
			if not targets.has(t[i]):
				seen[t[i]] = true
			if i == 0 or t[i] != t[i - 1]:
				runs += 1
	return float(runs - seen.size())

static func _copy(tubes: Array) -> Array:
	var out: Array = []
	for t in tubes:
		out.append(t.duplicate())
	return out

static func _key(tubes: Array, cs: int = 0) -> String:
	var parts := PackedStringArray()
	for t in tubes:
		var s := ""
		for c in t:
			s += char(97 + int(c))
		parts.append(s)
	parts.sort()
	return "|".join(parts) + "#" + str(cs)

# ---------- binary min-heap on parallel arrays ----------

static func _push(pri: PackedFloat64Array, idx: PackedInt32Array, p: float, i: int) -> void:
	pri.append(p)
	idx.append(i)
	var c := pri.size() - 1
	while c > 0:
		var par := (c - 1) / 2
		if pri[par] <= pri[c]:
			break
		var tp := pri[par]
		pri[par] = pri[c]
		pri[c] = tp
		var ti := idx[par]
		idx[par] = idx[c]
		idx[c] = ti
		c = par

static func _pop(pri: PackedFloat64Array, idx: PackedInt32Array) -> int:
	var top := idx[0]
	var last := pri.size() - 1
	pri[0] = pri[last]
	idx[0] = idx[last]
	pri.resize(last)
	idx.resize(last)
	var c := 0
	while true:
		var l := c * 2 + 1
		var r := l + 1
		var m := c
		if l < last and pri[l] < pri[m]:
			m = l
		if r < last and pri[r] < pri[m]:
			m = r
		if m == c:
			break
		var tp := pri[m]
		pri[m] = pri[c]
		pri[c] = tp
		var ti := idx[m]
		idx[m] = idx[c]
		idx[c] = ti
		c = m
	return top
