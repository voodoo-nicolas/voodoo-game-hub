extends RefCounted

## Rectangles solver: candidate rectangles per clue, exact-cover solution count
## (uniqueness check), and a logic-only solver used for difficulty ratings and hints.
## Pure static helpers, no Nodes. A rect is [r, c, h, w]; a clue is {"r", "c", "n"}.

## Clue index of every cell (-1 = no clue), row-major.
static func clue_grid(rows: int, cols: int, clues: Array) -> Array:
	var g: Array = []
	g.resize(rows * cols)
	g.fill(-1)
	for k in clues.size():
		g[int(clues[k].r) * cols + int(clues[k].c)] = k
	return g

## Every rectangle of area n that holds clue k, fits the board and holds no other clue.
## Returns one Array of rects per clue.
static func candidates(rows: int, cols: int, clues: Array) -> Array:
	var g := clue_grid(rows, cols, clues)
	var out: Array = []
	for k in clues.size():
		var cr: int = int(clues[k].r)
		var cc: int = int(clues[k].c)
		var n: int = int(clues[k].n)
		var list: Array = []
		for h in range(1, n + 1):
			if n % h != 0 or h > rows:
				continue
			var w: int = n / h
			if w > cols:
				continue
			for r0 in range(maxi(0, cr - h + 1), mini(cr, rows - h) + 1):
				for c0 in range(maxi(0, cc - w + 1), mini(cc, cols - w) + 1):
					if _only_clue(g, cols, [r0, c0, h, w], k):
						list.append([r0, c0, h, w])
		out.append(list)
	return out

static func _only_clue(g: Array, cols: int, rc: Array, k: int) -> bool:
	for r in range(rc[0], rc[0] + rc[2]):
		for c in range(rc[1], rc[1] + rc[3]):
			var v: int = g[r * cols + c]
			if v >= 0 and v != k:
				return false
	return true

static func cells_of(rc: Array, cols: int) -> Array:
	var out: Array = []
	for r in range(rc[0], rc[0] + rc[2]):
		for c in range(rc[1], rc[1] + rc[3]):
			out.append(r * cols + c)
	return out

## Number of complete solutions, counting stops at `limit` (2 is enough to prove uniqueness).
## Search: the first uncovered cell (row-major) must be the top-left corner of its rectangle,
## so only candidates starting there are tried.
static func count_solutions(rows: int, cols: int, clues: Array, limit: int = 2) -> int:
	var total := 0
	for cl in clues:
		total += int(cl.n)
	if total != rows * cols:
		return 0
	var cands := candidates(rows, cols, clues)
	var by_tl: Array = []
	by_tl.resize(rows * cols)
	for i in by_tl.size():
		by_tl[i] = []
	for k in cands.size():
		if cands[k].is_empty():
			return 0
		for rc in cands[k]:
			by_tl[rc[0] * cols + rc[1]].append([k, rc])
	var covered: Array = []
	covered.resize(rows * cols)
	covered.fill(false)
	var used: Array = []
	used.resize(clues.size())
	used.fill(false)
	var state := {"count": 0}
	_search(cols, by_tl, covered, used, 0, state, limit)
	return int(state.count)

static func _search(cols: int, by_tl: Array, covered: Array, used: Array, start: int, state: Dictionary, limit: int) -> void:
	var i := start
	while i < covered.size() and covered[i]:
		i += 1
	if i == covered.size():
		state.count += 1  # every cell covered; clue areas sum to the board, so every clue is used
		return
	for opt in by_tl[i]:
		var k: int = opt[0]
		if used[k]:
			continue
		var rc: Array = opt[1]
		if not _fits(covered, cols, rc):
			continue
		_mark(covered, cols, rc, true)
		used[k] = true
		_search(cols, by_tl, covered, used, i + 1, state, limit)
		_mark(covered, cols, rc, false)
		used[k] = false
		if state.count >= limit:
			return

static func _fits(covered: Array, cols: int, rc: Array) -> bool:
	for r in range(rc[0], rc[0] + rc[2]):
		for c in range(rc[1], rc[1] + rc[3]):
			if covered[r * cols + c]:
				return false
	return true

static func _mark(covered: Array, cols: int, rc: Array, v: bool) -> void:
	for r in range(rc[0], rc[0] + rc[2]):
		for c in range(rc[1], rc[1] + rc[3]):
			covered[r * cols + c] = v

## Logic-only solve, no guessing. `preplaced` = {clue index: rect} already on the board.
## Techniques: 1 = a clue has one shape left; 2 = a cell only one clue can reach;
## 3 = cells every shape of a clue shares belong to that clue.
## Returns {"solved", "steps": [[k, rect], ...] in the order found, "passes", "tech"}.
static func logic_solve(rows: int, cols: int, clues: Array, preplaced: Dictionary = {}) -> Dictionary:
	var n_cells := rows * cols
	var cands := candidates(rows, cols, clues)
	var owner: Array = []
	owner.resize(n_cells)
	owner.fill(-1)
	var claim: Array = []  # cell -> clue that must cover it (not yet placed)
	claim.resize(n_cells)
	claim.fill(-1)
	var placed := {}
	var steps: Array = []
	var tech := 0
	var passes := 0
	for k in preplaced:
		placed[int(k)] = preplaced[k]
		for i in cells_of(preplaced[k], cols):
			owner[i] = int(k)
	var dead := false
	while placed.size() < clues.size():
		passes += 1
		var progress := false
		# prune: shapes must avoid owned cells and other clues' claims, and cover their own claims
		for k in clues.size():
			if placed.has(k):
				continue
			var keep: Array = []
			for rc in cands[k]:
				if _shape_ok(rc, k, cols, owner, claim):
					keep.append(rc)
			cands[k] = keep
			if keep.is_empty():
				dead = true
		if dead:
			break
		# (1) only one shape left
		for k in clues.size():
			if not placed.has(k) and cands[k].size() == 1:
				var rc: Array = cands[k][0]
				if not _shape_ok(rc, k, cols, owner, claim):
					continue
				placed[k] = rc
				steps.append([k, rc])
				for i in cells_of(rc, cols):
					owner[i] = k
					claim[i] = -1
				tech = maxi(tech, 1)
				progress = true
		if progress:
			continue
		# (2) a free cell that only one clue's shapes reach
		var reach: Array = []
		reach.resize(n_cells)
		for i in n_cells:
			reach[i] = {}
		for k in clues.size():
			if placed.has(k):
				continue
			for rc in cands[k]:
				for i in cells_of(rc, cols):
					reach[i][k] = true
		for i in n_cells:
			if owner[i] >= 0:
				continue
			if reach[i].is_empty():
				dead = true
				break
			if reach[i].size() == 1 and claim[i] < 0:
				claim[i] = int(reach[i].keys()[0])
				tech = maxi(tech, 2)
				progress = true
		if dead:
			break
		if progress:
			continue
		# (3) cells shared by every shape of a clue
		for k in clues.size():
			if placed.has(k) or cands[k].is_empty():
				continue
			var common := {}
			for i in cells_of(cands[k][0], cols):
				common[i] = true
			for j in range(1, cands[k].size()):
				var here := {}
				for i in cells_of(cands[k][j], cols):
					if common.has(i):
						here[i] = true
				common = here
			for i in common:
				if claim[i] < 0:
					claim[i] = k
					tech = maxi(tech, 3)
					progress = true
		if not progress:
			break
	return {"solved": placed.size() == clues.size() and not dead, "steps": steps, "passes": passes, "tech": tech}

static func _shape_ok(rc: Array, k: int, cols: int, owner: Array, claim: Array) -> bool:
	var inside := {}
	for i in cells_of(rc, cols):
		if owner[i] >= 0 or (claim[i] >= 0 and claim[i] != k):
			return false
		inside[i] = true
	for i in claim.size():
		if claim[i] == k and not inside.has(i):
			return false
	return true

## Difficulty 1-5 from board size and what the logic solver needed.
## A puzzle the logic solver can't finish (it needs a guess) is always 5.
static func rate(rows: int, cols: int, clues: Array) -> Dictionary:
	var res := logic_solve(rows, cols, clues)
	if not res.solved:
		return {"difficulty": 5, "guess": true, "score": 1000 + rows * cols}
	var d := 1
	if rows * cols >= 36:
		d += 1
	if rows * cols >= 64:
		d += 1
	if int(res.tech) >= 3:
		d += 1
	if int(res.passes) > clues.size() / 2 + 2:
		d += 1
	# finer score for ordering levels: hardest technique, then rounds of reasoning, then piece size
	var score: int = int(res.tech) * 100 + int(res.passes) * 10 + (rows * cols * 3) / maxi(1, clues.size())
	return {"difficulty": clampi(d, 1, 5), "guess": false, "score": score}
