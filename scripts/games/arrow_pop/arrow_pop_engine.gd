extends RefCounted

## Arrow Pop -- pure logic, no Nodes (tools/test_arrow_pop.gd runs it headless).
##
## The board is a grid of cells: empty, a bubble (a colour) or an arrow (a colour and a
## direction). Tapping an arrow fires it in its direction. It flies over empty cells and pops
## every bubble of ITS colour on the way, then leaves the board. If its way holds a bubble of
## another colour, or another arrow, it can't go: it bumps, comes back, and costs a heart.
## Clear every bubble and arrow to win. 3 hearts per level.
##
## Levels are made backwards from an empty board (see _build), so every level can be solved.
## Firing a legal arrow only ever removes things, so a legal move can never spoil a level:
## the whole puzzle is seeing which arrows are free right now.

const EMPTY := 0
const BUBBLE := 1
const ARROW := 2
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # up, right, down, left
const LEVEL_COUNT := 320
const MAX_HEARTS := 3
const MAX_COLORS := 6

var w: int = 4
var h: int = 4
var colors: int = 2
var level_no: int = 1
var kind: Array = []   # EMPTY / BUBBLE / ARROW per cell
var col: Array = []    # colour index per cell
var dir: Array = []    # 0..3 per arrow cell
var hearts: int = MAX_HEARTS
var mistakes: int = 0

# ---------- level shape ----------

## Board width, height, colours, fill and how deep the chain of "fire this first" should be.
static func params(n: int) -> Dictionary:
	n = clampi(n, 1, LEVEL_COUNT)
	var wd: int = 4
	for step in [12, 35, 75, 130, 200, 270]:
		if n > step:
			wd += 1
	wd = mini(wd, 9)
	var extra: int = mini(4, n / 40)
	var nc: int = 2
	for step in [5, 20, 55, 120, 200]:
		if n > step:
			nc += 1
	var fill: float = minf(1.0, 0.72 + n * 0.0015)
	var depth: int = 2 + int(float(n) / 30.0)
	return {"w": wd, "h": wd + extra, "colors": mini(nc, MAX_COLORS), "fill": fill, "depth": depth}

static func level_seed(n: int) -> int:
	return int(n) * 7919 + 104729

## Levels ship pre-made in arrow_pop_levels.gd (tools/gen_arrow_pop_levels.gd writes it with
## generate()), because making one takes too long on a phone. One character per cell:
## "." empty, "a".."f" a bubble of colour 0..5, "A".."X" an arrow (colour * 4 + direction).
const LEVELS_PATH := "res://scripts/games/arrow_pop/arrow_pop_levels.gd"

func load_level(n: int) -> void:
	level_no = clampi(n, 1, LEVEL_COUNT)
	if ResourceLoader.exists(LEVELS_PATH):
		var data: Array = load(LEVELS_PATH).LEVELS
		if level_no <= data.size() and decode(data[level_no - 1]):
			level_no = clampi(n, 1, LEVEL_COUNT)
			hearts = MAX_HEARTS
			mistakes = 0
			return
	generate(level_no)

## Make level n from its seed (slow: tools only, or if the data file is missing).
func generate(n: int) -> void:
	level_no = clampi(n, 1, LEVEL_COUNT)
	var p := params(level_no)
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed(level_no)
	var best: Dictionary = {}
	var best_score := -1.0e9
	# A few tries; keep the one closest to the wanted chain depth and fullest.
	for attempt in 4:
		_build(p.w, p.h, p.colors, p.fill, p.depth, rng)
		var cells := w * h
		var filled := cells - count(EMPTY)
		var d := depth()
		var score: float = float(filled) / cells * 10.0 - absf(float(mini(d, p.depth) - p.depth)) * 3.0
		if _colors_used() < p.colors:
			score -= 5.0
		if d < 1:
			score -= 1000.0  # can't happen (built backwards), but never ship a stuck board
		if score > best_score:
			best_score = score
			best = to_dict()
	from_dict(best)
	level_no = clampi(n, 1, LEVEL_COUNT)
	hearts = MAX_HEARTS
	mistakes = 0

## Backwards: start empty. Each step puts an arrow on an empty cell whose way out is empty
## (that's how the board looks right after firing it) and fills some of that way with
## bubbles of the arrow's colour. Played forwards, the last arrow placed is free first.
## To make levels harder, a new arrow is placed so its cells sit in the way of arrows
## already placed (those must then wait for it): chain[] is how long that "wait" chain is.
func _build(bw: int, bh: int, nc: int, fill: float, want_depth: int, rng: RandomNumberGenerator) -> void:
	w = bw
	h = bh
	colors = nc
	kind = []
	col = []
	dir = []
	kind.resize(w * h)
	kind.fill(EMPTY)
	col.resize(w * h)
	col.fill(0)
	dir.resize(w * h)
	dir.fill(0)
	var watchers: Array = []  # cell -> arrows whose way crosses it
	for i in w * h:
		watchers.append([])
	var chain := {}  # arrow cell -> chain length
	var top := 0
	var target: int = int(round(w * h * fill))
	var filled := 0
	var last_color := -1
	while filled < target:
		var k := rng.randi_range(0, colors - 1)
		if k == last_color and colors > 1:
			k = (k + 1 + rng.randi_range(0, colors - 2)) % colors
		var pick: Dictionary = {}
		var pick_score := -1.0
		for full_scan in 2:
			var tries: Array = []
			if full_scan == 0:
				for t in 70:
					tries.append(rng.randi_range(0, w * h * 4 - 1))
			else:
				for t in w * h * 4:
					tries.append(t)
			for t in tries:
				var c: int = t / 4
				var d: int = t % 4
				if kind[c] != EMPTY:
					continue
				var way := path(c, d)
				if way.is_empty() or not _all_empty(way):
					continue
				var run: int = rng.randi_range(1, mini(way.size(), 3) if top < want_depth else way.size())
				var link := 0
				var cells: Array = [c] + way.slice(0, run)
				for s in cells:
					for a in watchers[s]:
						if s == c or col[a] != k:
							link = maxi(link, int(chain[a]))
				var sc: float = run + rng.randf() * 3.0
				if top < want_depth:
					sc += (link + 1) * 10.0
				if sc > pick_score:
					pick_score = sc
					pick = {"c": c, "d": d, "way": way, "run": run, "chain": link + 1}
			if not pick.is_empty():
				break
		if pick.is_empty():
			break  # nowhere left to put an arrow
		last_color = k
		var c0: int = pick.c
		kind[c0] = ARROW
		col[c0] = k
		dir[c0] = pick.d
		chain[c0] = pick.chain
		top = maxi(top, pick.chain)
		filled += 1
		for i in pick.way.size():
			var cell: int = pick.way[i]
			watchers[cell].append(c0)
			if i < pick.run:
				kind[cell] = BUBBLE
				col[cell] = k
				filled += 1

func _all_empty(cells: Array) -> bool:
	for c in cells:
		if kind[c] != EMPTY:
			return false
	return true

func _colors_used() -> int:
	var seen := {}
	for i in w * h:
		if kind[i] != EMPTY:
			seen[col[i]] = true
	return seen.size()

# ---------- rules ----------

## Cells from the one after `c` to the edge, in direction `d`.
func path(c: int, d: int) -> Array:
	var out: Array = []
	var step: Vector2i = DIRS[d]
	var p: Vector2i = Vector2i(c % w, c / w) + step
	while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
		out.append(p.y * w + p.x)
		p += step
	return out

## What firing the arrow at `c` would do: {"ok", "pops" (cells popped, in order),
## "block" (the cell it bumps into, -1 if none), "way" (its whole path)}.
func check(c: int) -> Dictionary:
	if c < 0 or c >= kind.size() or kind[c] != ARROW:
		return {"ok": false, "pops": [], "block": -1, "way": []}
	var way := path(c, dir[c])
	var pops: Array = []
	for cell in way:
		if kind[cell] == EMPTY:
			continue
		if kind[cell] == BUBBLE and col[cell] == col[c]:
			pops.append(cell)
			continue
		return {"ok": false, "pops": [], "block": cell, "way": way}
	return {"ok": true, "pops": pops, "block": -1, "way": way}

## Fire the arrow at `c`. Legal: pops and leaves. Blocked: costs a heart, stays put.
func fire(c: int) -> Dictionary:
	var r := check(c)
	if c < 0 or c >= kind.size() or kind[c] != ARROW:
		return r
	if r.ok:
		kind[c] = EMPTY
		for p in r.pops:
			kind[p] = EMPTY
	else:
		hearts -= 1
		mistakes += 1
	return r

func free_arrows() -> Array:
	var out: Array = []
	for i in w * h:
		if kind[i] == ARROW and check(i).ok:
			out.append(i)
	return out

func count(k: int) -> int:
	var n := 0
	for v in kind:
		if v == k:
			n += 1
	return n

func won() -> bool:
	return count(EMPTY) == w * h

func lost() -> bool:
	return hearts <= 0 and not won()

## Stars for a win: 3 with no slip, 2 with one, 1 otherwise.
func stars() -> int:
	return clampi(MAX_HEARTS - mistakes, 1, 3)

## Rounds needed if every free arrow is fired at once, round after round (-1 if stuck).
## A rough measure of how long the "fire this first" chain is.
func depth() -> int:
	var saved: Array = kind.duplicate()
	var rounds := 0
	while not won():
		var free := free_arrows()
		if free.is_empty():
			rounds = -1
			break
		for c in free:
			var r := check(c)
			if r.ok:
				kind[c] = EMPTY
				for p in r.pops:
					kind[p] = EMPTY
		rounds += 1
	kind = saved
	return rounds

func solvable() -> bool:
	return depth() >= 0

# ---------- level text ----------

func encode() -> String:
	var t := "%d,%d,%d," % [w, h, colors]
	for i in w * h:
		if kind[i] == EMPTY:
			t += "."
		elif kind[i] == BUBBLE:
			t += char(97 + col[i])
		else:
			t += char(65 + col[i] * 4 + dir[i])
	return t

func decode(t: String) -> bool:
	var parts := t.split(",")
	if parts.size() != 4:
		return false
	var dw := int(parts[0])
	var dh := int(parts[1])
	var cells: String = parts[3]
	if dw < 1 or dh < 1 or cells.length() != dw * dh:
		return false
	w = dw
	h = dh
	colors = clampi(int(parts[2]), 1, MAX_COLORS)
	kind = []
	col = []
	dir = []
	for i in cells.length():
		var ch := cells.unicode_at(i)
		if ch >= 97 and ch < 97 + MAX_COLORS:
			kind.append(BUBBLE)
			col.append(ch - 97)
			dir.append(0)
		elif ch >= 65 and ch < 65 + MAX_COLORS * 4:
			kind.append(ARROW)
			col.append((ch - 65) / 4)
			dir.append((ch - 65) % 4)
		else:
			kind.append(EMPTY)
			col.append(0)
			dir.append(0)
	return true

# ---------- save ----------

func to_dict() -> Dictionary:
	return {"w": w, "h": h, "colors": colors, "level": level_no, "kind": kind.duplicate(), "col": col.duplicate(),
		"dir": dir.duplicate(), "hearts": hearts, "mistakes": mistakes}

func from_dict(d: Dictionary) -> bool:
	var dw := int(d.get("w", 0))
	var dh := int(d.get("h", 0))
	var k: Array = d.get("kind", [])
	if dw < 1 or dh < 1 or k.size() != dw * dh or d.get("col", []).size() != k.size() or d.get("dir", []).size() != k.size():
		return false
	w = dw
	h = dh
	colors = clampi(int(d.get("colors", 2)), 1, MAX_COLORS)
	level_no = clampi(int(d.get("level", 1)), 1, LEVEL_COUNT)
	kind = []
	col = []
	dir = []
	for i in k.size():
		kind.append(clampi(int(k[i]), 0, 2))
		col.append(clampi(int(d.col[i]), 0, MAX_COLORS - 1))
		dir.append(clampi(int(d.dir[i]), 0, 3))
	hearts = clampi(int(d.get("hearts", MAX_HEARTS)), 1, MAX_HEARTS + 3)
	mistakes = maxi(0, int(d.get("mistakes", 0)))
	return true
