extends RefCounted

## Seeded Rectangles puzzle generator: the same (rows, cols, seed, tier) always gives the
## same puzzle on every device (Godot's RandomNumberGenerator is PCG32, platform-stable).
## 1. random rectangle packing  2. one clue per rectangle  3. reject unless exactly one
## solution  4. rate with the logic solver. Used at runtime (Daily, Weekly, Zen, and Classic
## levels missing from the shipped JSON) and by tools/rectangles_gen.gd for the level packs.

const Solver = preload("res://scripts/games/rectangles/rectangles_solver.gd")

## Largest piece per tier (0 easy ... 3 expert).
const MAX_AREA := [6, 8, 9, 12]

## Returns {"id", "size": [rows, cols], "clues", "solution", "difficulty", "seed"}.
## `allow_guess` keeps puzzles the logic solver can't finish (top difficulty only).
static func generate(rows: int, cols: int, seed_value: int, tier: int = 1, allow_guess: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var max_area: int = MAX_AREA[clampi(tier, 0, MAX_AREA.size() - 1)]
	var fallback := {}
	for attempt in 400:
		var rects := _partition(rows, cols, max_area, rng)
		if rects.is_empty():
			continue
		for roll in 6:
			var clues := _place_clues(rects, tier, rng)
			if Solver.count_solutions(rows, cols, clues, 2) != 1:
				continue
			var rating := Solver.rate(rows, cols, clues)
			var p := _pack(rows, cols, clues, rects, int(rating.difficulty), seed_value)
			p["score"] = int(rating.score)
			if not rating.guess or allow_guess:
				return p
			if fallback.is_empty():
				fallback = p
	return fallback  # empty only if 400 partitions all failed (never seen in tests)

static func _pack(rows: int, cols: int, clues: Array, rects: Array, difficulty: int, seed_value: int) -> Dictionary:
	var total := 0
	for cl in clues:
		total += int(cl.n)
	assert(total == rows * cols, "Rectangles: clue sum must equal the cell count")
	var sol: Array = []
	for rc in rects:
		sol.append({"r": rc[0], "c": rc[1], "h": rc[2], "w": rc[3]})
	return {"id": "", "size": [rows, cols], "clues": clues, "solution": sol, "difficulty": difficulty, "seed": seed_value}

## Random rectangle packing: take the first free cell (in a shuffled order), grow a rectangle
## from it over free cells with an area picked toward 2..max_area. Area-1 pieces only when
## nothing else fits, and at most ~10% of the pieces.
static func _partition(rows: int, cols: int, max_area: int, rng: RandomNumberGenerator) -> Array:
	var free: Array = []
	free.resize(rows * cols)
	free.fill(true)
	var order: Array = range(rows * cols)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var rects: Array = []
	var ones := 0
	for cell in order:
		if not free[cell]:
			continue
		var r: int = cell / cols
		var c: int = cell % cols
		var opts: Array = []
		var weights: Array = []
		for h in range(1, max_area + 1):
			for w in range(1, max_area / h + 1):
				var a := h * w
				if a < 2 or a > max_area or h > rows or w > cols:
					continue
				for r0 in range(maxi(0, r - h + 1), mini(r, rows - h) + 1):
					for c0 in range(maxi(0, c - w + 1), mini(c, cols - w) + 1):
						if _all_free(free, cols, [r0, c0, h, w]):
							opts.append([r0, c0, h, w])
							# favour mid-size pieces; long thin strips a little less
							var wt := 3.0 if a >= 3 and a <= 6 else 2.0
							if mini(h, w) == 1 and a >= 5:
								wt *= 0.5
							weights.append(wt)
		var pick: Array
		if opts.is_empty():
			pick = [r, c, 1, 1]
			ones += 1
		else:
			pick = opts[_weighted(weights, rng)]
		for i in Solver.cells_of(pick, cols):
			free[i] = false
		rects.append(pick)
	if ones > maxi(1, rects.size() / 10):
		return []
	return rects

static func _all_free(free: Array, cols: int, rc: Array) -> bool:
	for r in range(rc[0], rc[0] + rc[2]):
		for c in range(rc[1], rc[1] + rc[3]):
			if not free[r * cols + c]:
				return false
	return true

static func _weighted(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var x := rng.randf() * total
	for i in weights.size():
		x -= weights[i]
		if x <= 0.0:
			return i
	return weights.size() - 1

## One clue per rectangle. Easy tiers lean toward corners and the middle (friendlier spots);
## harder tiers place clues anywhere inside.
static func _place_clues(rects: Array, tier: int, rng: RandomNumberGenerator) -> Array:
	var clues: Array = []
	for rc in rects:
		var r: int = rc[0] + rng.randi_range(0, rc[2] - 1)
		var c: int = rc[1] + rng.randi_range(0, rc[3] - 1)
		if tier <= 1 and rng.randf() < (0.5 if tier == 0 else 0.3):
			if rng.randf() < 0.5:
				r = rc[0] + (rc[2] - 1) * rng.randi_range(0, 1)
				c = rc[1] + (rc[3] - 1) * rng.randi_range(0, 1)
			else:
				r = rc[0] + (rc[2] - 1) / 2
				c = rc[1] + (rc[3] - 1) / 2
		clues.append({"r": r, "c": c, "n": rc[2] * rc[3]})
	clues.sort_custom(func(a, b): return a.r * 1000 + a.c < b.r * 1000 + b.c)
	return clues

## Classic plan (300 levels): 1-10 5x5, 11-30 6x6, 31-100 7x7, 101-180 8x8, 181-240 9x9, 241-300 10x10.
static func classic_spec(level: int) -> Dictionary:
	var size := 5
	var tier := 0
	if level > 240:
		size = 10
		tier = 3
	elif level > 180:
		size = 9
		tier = 2 if level <= 210 else 3
	elif level > 100:
		size = 8
		tier = 2
	elif level > 30:
		size = 7
		tier = 1 if level <= 60 else 2
	elif level > 20:
		size = 6
		tier = 1
	elif level > 10:
		size = 6
		tier = 1 if level > 15 else 0
	return {"size": size, "tier": tier, "seed": 7001 + level * 7919}
