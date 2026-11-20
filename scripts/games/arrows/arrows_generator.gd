extends RefCounted

## Arrows level generator. Pure logic, seeded, so level N is the same on every phone.
##
## Every level is solvable by construction (see generate()).
## Harder levels: bigger grids, longer and twistier arrows, and heads aimed across the
## board (long paths cross more arrows, so more arrows depend on each other).

const LEVELS := 360
## Picture outlines (all original; drawn from simple maths or the little bitmaps below).
const SHAPES := ["circle", "heart", "arrow", "diamond", "dog", "plus", "house", "ring", "tree", "cat", "hourglass"]

const BITMAPS := {
	"dog": [
		"..............##",
		"............####",
		"#..........#####",
		"#.#############.",
		"##############..",
		".#############..",
		".##.........##..",
		".##.........##..",
		".##.........##..",
		".##.........##..",
	],
	"cat": [
		"#...#...........",
		"##.##...........",
		"#####..........#",
		"#####.........#.",
		".###.........#..",
		".##########..#..",
		".############...",
		".###########....",
		".##.......##....",
		".##.......##....",
	],
}

## The recipe for Classic level `lvl` (1-based).
## [CHANGED 2026-11-20, owner: levels 1-3 easy, then much harder and a much bigger board at once]
## Was: w = 5 + lvl*0.06 (5 wide until level 17), max_len 3 + lvl/15, aim lvl/240.
static func classic_spec(lvl: int) -> Dictionary:
	var w: int
	var t: float  # 0..1 hardness
	if lvl <= 3:
		w = 4 + lvl            # 5, 6, 7: the tutorial
		t = 0.05 * lvl
	else:
		var k := float(lvl - 4) / float(LEVELS - 4)
		# w = 11 + int(round(15.0 * k))   # 11 wide at level 4 .. 26 at 360
		# t = 0.45 + 0.55 * k
		w = 12 + int(round(14.0 * k))   # 12 wide at level 4 .. 26 at 360
		t = 0.65 + 0.35 * k
	var h := int(round(w * 1.45))
	var shape := "rect"
	if w >= 9 and lvl % 4 != 0:
		shape = SHAPES[(lvl * 7) % SHAPES.size()]
	return {
		"cols": w, "rows": h, "shape": shape, "seed": lvl * 7919 + 101,
		"max_len": clampi(3 + int(9.0 * t), 3, 12),  # long but not few: more arrows tangle more
		"turn": 0.2 + 0.4 * t,
		"aim": minf(0.85, 0.9 * t),
	}

static func difficulty(lvl: int) -> String:
	if lvl <= 3:
		return "Easy"
	if lvl < 60:
		return "Normal"
	if lvl < 180:
		return "Hard"
	return "Expert"

static func classic(lvl: int) -> Dictionary:
	var p := generate(classic_spec(lvl))
	p.id = "classic-%03d" % lvl
	return p

## Builds the picture mask: 1 where arrows may go.
static func make_mask(cols: int, rows: int, shape: String) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(cols * rows)
	for r in rows:
		for c in cols:
			var x := (c + 0.5) / cols * 2.0 - 1.0
			var y := (r + 0.5) / rows * 2.0 - 1.0
			m[r * cols + c] = 1 if _in_shape(shape, x, y, c, r, cols, rows) else 0
	return m

static func _in_shape(shape: String, x: float, y: float, c: int, r: int, cols: int, rows: int) -> bool:
	match shape:
		"circle":
			return x * x + y * y <= 1.0
		"diamond":
			return absf(x) + absf(y) <= 1.05
		"heart":
			var X := x * 1.25
			var Y := -y * 1.35 + 0.35
			return pow(X * X + Y * Y - 1.0, 3.0) - X * X * Y * Y * Y <= 0.0
		"arrow":
			if y < 0.0:
				return absf(x) <= y + 1.05
			return absf(x) <= 0.45
		"plus":
			return absf(x) <= 0.38 or absf(y) <= 0.3
		"house":
			if y < -0.15:
				return absf(x) <= (y + 1.05) / 0.9
			return absf(x) <= 0.8
		"ring":
			var d := x * x + y * y
			return d <= 1.0 and d >= 0.2
		"tree":
			if y < 0.55:
				return absf(x) <= (y + 1.05) / 1.6
			return absf(x) <= 0.22
		"hourglass":
			return absf(x) <= absf(y) * 0.9 + 0.18
		"dog", "cat":
			var bm: Array = BITMAPS[shape]
			var bh := bm.size()
			var bw: int = bm[0].length()
			# Sideways pictures on a tall board: centre them in a band.
			var band := int(round(cols * float(bh) / bw))
			var top := (rows - band) / 2
			if r < top or r >= top + band:
				return false
			var by := int(float(r - top) / band * bh)
			var bx := int(float(c) / cols * bw)
			return bm[clampi(by, 0, bh - 1)][clampi(bx, 0, bw - 1)] == "#"
	return true

## spec: cols, rows, shape, seed, max_len, turn (0..1 chance a body bends), aim (0..1 chance
## the head points the long way across).
##
## Solvable by construction: each arrow gets a rank (its turn to leave, low first). A new
## arrow X fits when every arrow on X's way out leaves before it (rank < X) and every arrow
## whose way out crosses X's body leaves after it (rank > X): it is slotted between them.
## Removing in rank order always works, and since removing never blocks anything, the
## greedy solver (engine.solvable) finds a way whenever one exists.
static func generate(spec: Dictionary) -> Dictionary:
	var cols: int = spec.cols
	var rows: int = spec.rows
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.seed)
	var mask := make_mask(cols, rows, str(spec.get("shape", "rect")))
	var st := {
		"cols": cols, "rows": rows, "mask": mask,
		"occ": PackedInt32Array(),   # arrow index per cell, -1 empty
		"cover": {},                 # cell -> [arrow indices whose way out crosses it]
		"rank": [],                  # arrow index -> float
	}
	st.occ.resize(cols * rows)
	st.occ.fill(-1)
	var cells: Array = []
	for i in cols * rows:
		if mask[i]:
			cells.append(Vector2i(i % cols, i / cols))
	_shuffle(cells, rng)
	var arrows: Array = []
	for pass_n in 3:
		for h in cells:
			if st.occ[h.y * cols + h.x] >= 0:
				continue
			var g := _grow(h, st, rng, spec)
			if g.is_empty():
				continue
			var idx := arrows.size()
			var a: Array = g.body
			for c in a:
				st.occ[c.y * cols + c.x] = idx
			for c in g.ray:
				if not st.cover.has(c):
					st.cover[c] = []
				st.cover[c].append(idx)
			st.rank.append(g.rank)
			var flat: Array = []
			for c in a:
				flat.append(c.x)
				flat.append(c.y)
			arrows.append(flat)
	var m := ""
	for i in mask.size():
		m += "1" if mask[i] else "0"
	return {"cols": cols, "rows": rows, "arrows": arrows, "mask": m, "shape": str(spec.get("shape", "rect"))}

## One arrow with its head on `h`: {body (tail first), ray (cells of its way out), rank}; {} if none fits.
static func _grow(h: Vector2i, st: Dictionary, rng: RandomNumberGenerator, spec: Dictionary) -> Dictionary:
	var cols: int = st.cols
	var rows: int = st.rows
	var mask: PackedByteArray = st.mask
	var occ: PackedInt32Array = st.occ
	var rank: Array = st.rank
	var cover: Dictionary = st.cover
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	_shuffle(dirs, rng)
	if rng.randf() < float(spec.get("aim", 0.0)):
		# Longest way across first: these paths cross the most arrows.
		var lens := {}
		for d in dirs:
			lens[d] = _ray_len(h, d, cols, rows)
		dirs.sort_custom(func(a, b): return lens[a] > lens[b])
	for d in dirs:
		# lo: the latest-leaving arrow on the way out; X must leave after it.
		var lo := -INF
		var ray: Array = []
		var on_ray := {}
		var c: Vector2i = h + d
		while c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows:
			var o := occ[c.y * cols + c.x]
			if o >= 0:
				lo = maxf(lo, rank[o])
			ray.append(c)
			on_ray[c] = true
			c += d
		# hi: the earliest-leaving arrow whose way out crosses X's body; X must leave before it.
		var hi := INF
		var ok_cell := func(n: Vector2i, cur_hi: float) -> float:
			# Returns the new hi if the cell can join the body, NAN if not.
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				return NAN
			if mask[n.y * cols + n.x] == 0 or occ[n.y * cols + n.x] >= 0 or on_ray.has(n):
				return NAN
			var nh := cur_hi
			for k in cover.get(n, []):
				nh = minf(nh, rank[k])
			return nh if nh > lo else NAN
		var r0: float = ok_cell.call(h, hi)
		if is_nan(r0):
			continue
		var prev: Vector2i = h - d
		var r1: float = ok_cell.call(prev, r0)
		if is_nan(r1):
			continue
		hi = r1
		var body: Array = [h, prev]
		var own := {h: true, prev: true}
		var want := rng.randi_range(2, int(spec.get("max_len", 4)))
		var back: Vector2i = -d  # walking from head toward tail
		while body.size() < want:
			var cur: Vector2i = body[body.size() - 1]
			var opts: Array = []
			var his: Array = []
			for nd in [back, Vector2i(back.y, back.x), Vector2i(-back.y, -back.x)]:
				var n: Vector2i = cur + nd
				if own.has(n):
					continue
				var nh: float = ok_cell.call(n, hi)
				if not is_nan(nh):
					opts.append(nd)
					his.append(nh)
			if opts.is_empty():
				break
			var k := 0
			if opts.size() > 1 and (opts[0] != back or rng.randf() < float(spec.get("turn", 0.3))):
				k = rng.randi_range(1 if opts[0] == back else 0, opts.size() - 1)
			back = opts[k]
			hi = his[k]
			var n2: Vector2i = cur + back
			body.append(n2)
			own[n2] = true
		body.reverse()
		var rk: float
		if lo == -INF and hi == INF:
			rk = 0.0
		elif lo == -INF:
			rk = hi - 1.0
		elif hi == INF:
			rk = lo + 1.0
		else:
			rk = (lo + hi) / 2.0
		return {"body": body, "ray": ray, "rank": rk}
	return {}

static func _ray_len(h: Vector2i, d: Vector2i, cols: int, rows: int) -> int:
	match d:
		Vector2i(1, 0):
			return cols - 1 - h.x
		Vector2i(-1, 0):
			return h.x
		Vector2i(0, 1):
			return rows - 1 - h.y
	return h.y

## Fisher-Yates with our own RNG (Array.shuffle uses the global one: not reproducible).
static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
