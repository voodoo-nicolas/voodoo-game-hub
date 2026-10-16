extends RefCounted

## Color Sort: vials of coloured liquid layers. Pour the top colour run of one
## vial onto another if that vial is empty or its top colour matches, as much as
## fits. Sort every colour into its own vial. Pure logic, no Nodes.
## Levels are made by playing the solved board backwards with random legal
## "un-pours" (seeded, so a level number always gives the same puzzle), so every
## level can be solved. color_sort_solver.gd finds a par for the star rating.

const Solver = preload("res://scripts/games/color_sort/color_sort_solver.gd")
## Par for campaign levels 1..N, written by tools/gen_color_sort_par.gd (do not hand-edit).
const ParTable = preload("res://scripts/games/color_sort/color_sort_par.gd")

## Default vial capacity (older saves and the four classic difficulty buttons).
const CAP := 4
## Old difficulty buttons: colours, empty vials at the start.
const LEVELS := [
	{"colors": 4, "empty": 2},
	{"colors": 6, "empty": 2},
	{"colors": 8, "empty": 2},
	{"colors": 10, "empty": 2},
]
const MAX_EXTRA := 1
const MAX_COLORS := 14
const MAX_VIALS := 18
## First level number of each tier; Master has no end.
const TIER_NAMES := ["Easy", "Medium", "Hard", "Expert", "Master"]
const TIER_START := [1, 21, 51, 91, 141]
## Star limits as a share of par: 3 stars up to PAR_3, 2 stars up to PAR_2.
const PAR_3 := 1.15
const PAR_2 := 1.6

var level: int = 0           # classic difficulty index (0..3), kept for the old buttons
var level_no: int = 0        # campaign level, 1 and up; 0 = a classic-difficulty puzzle
var cap: int = CAP           # layers per vial
var tubes: Array = []        # each: Array of colour ints, bottom first
var moves: int = 0
var history: Array = []      # [from, to, amount] of each pour, for undo
var extra_used: int = 0
var initial: Array = []      # the puzzle as dealt, for Reset
var par: int = 0             # moves a good player needs (0 = unknown)
var gen_moves: int = 0       # length of the scrambling walk: always a valid (loose) par

## ---------- level specs ----------

static func tier_of(n: int) -> int:
	var t := 0
	for i in TIER_START.size():
		if n >= int(TIER_START[i]):
			t = i
	return t

## colours, layers, empty vials for campaign level n (1-based). Empty vials go 3 -> 2
## and never lower: with a single empty vial the reverse scramble cannot mix the board. 14 colours only
## appear far into Master; most of the game stays at 10 or fewer.
static func spec_for(n: int) -> Dictionary:
	n = maxi(1, n)
	var t := tier_of(n)
	var colors := 3
	var capacity := 4
	var empty := 2
	match t:
		0:
			colors = 3 + (n - 1) / 7
			capacity = 3 if n < 8 else 4
			if n <= 10:
				empty = 3
		1:
			colors = 5 + (n - 21) / 10
			capacity = 4
		2:
			colors = 7 + (n - 51) / 20
			capacity = 4 if n < 71 else 5
		3:
			colors = 8 + (n - 91) / 17
			capacity = 5 if n < 125 else 6
		_:
			colors = mini(MAX_COLORS, 10 + (n - 141) / 30)
			capacity = 5 + (n / 5) % 2
	return {"level": n, "tier": t, "colors": colors, "cap": capacity, "empty": empty}

## ---------- creating a puzzle ----------

## Campaign level n (1-based).
func load_level(n: int) -> void:
	var spec := spec_for(n)
	level_no = int(spec.level)
	level = 0
	cap = int(spec.cap)
	_generate(int(spec.colors), int(spec.empty), cap, 7919 * level_no + 17)
	_finish_deal()
	par = int(ParTable.PAR[level_no - 1]) if level_no <= ParTable.PAR.size() else 0
	if par <= 0:
		par = gen_moves

## Old four-difficulty entry (random puzzle).
func new_game(lvl: int) -> void:
	level = clampi(lvl, 0, LEVELS.size() - 1)
	level_no = 0
	cap = CAP
	var spec: Dictionary = LEVELS[level]
	_generate(int(spec.colors), int(spec.empty), CAP, randi())
	_finish_deal()
	par = gen_moves

func _finish_deal() -> void:
	initial = tubes.duplicate(true)
	moves = 0
	history = []
	extra_used = 0

func reset() -> void:
	tubes = initial.duplicate(true)
	moves = 0
	history = []
	extra_used = 0

## Plays the solved board backwards. An un-pour takes k balls off the top run of
## vial b and puts them on vial a, so that the forward pour a -> b moves exactly
## those k balls (see the two cases below). Solvable by construction.
func _generate(n: int, empty: int, capacity: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	for attempt in 150:
		rng.seed = seed_value + attempt * 104729
		tubes = []
		for c in n:
			var t: Array = []
			for k in capacity:
				t.append(c)
			tubes.append(t)
		for e in empty:
			tubes.append([])
		var steps: int = n * capacity * 3
		var done := 0
		while done < steps:
			# Every legal un-pour: [a, b, kmax]. Picking from the list wastes no tries
			# and ends only at a real dead end.
			var options: Array = []
			for b in tubes.size():
				var tb: Array = tubes[b]
				if tb.is_empty():
					continue
				var c: int = tb[tb.size() - 1]
				var r: int = Solver.run_of(tb)
				## b must keep its top colour (or end empty), else the forward pour onto it is illegal.
				var limit: int = r if r == tb.size() else r - 1
				for a in tubes.size():
					var ta: Array = tubes[a]
					if a == b or ta.size() >= capacity:
						continue
					## Landing on a vial that already shows colour c only works if b was full:
					## then the forward pour is cut short by b's room and moves exactly k.
					if not ta.is_empty() and ta[ta.size() - 1] == c and tb.size() != capacity:
						continue
					var kmax: int = mini(limit, capacity - ta.size())
					if kmax >= 1:
						options.append([a, b, kmax])
			if options.is_empty():
				break
			var o: Array = options[rng.randi() % options.size()]
			var k: int = 1 + rng.randi() % int(o[2])
			for i in k:
				tubes[o[0]].append(tubes[o[1]].pop_back())
			done += 1
		gen_moves = done
		cap = capacity
		if done >= steps / 4 and _mixed_enough():
			return

func _mixed_enough() -> bool:
	var sorted_tubes := 0
	for t in tubes:
		if t.size() == cap and _single(t):
			sorted_tubes += 1
	return sorted_tubes <= maxi(0, tubes.size() / 4) and not solved()

func _single(t: Array) -> bool:
	for c in t:
		if c != t[0]:
			return false
	return true

func color_count() -> int:
	if level_no > 0:
		return int(spec_for(level_no).colors)
	return int(LEVELS[level].colors)

## ---------- rules ----------

## Balls a pour from -> to would move (0 if illegal).
func pour_amount(from: int, to: int) -> int:
	if from == to or from < 0 or to < 0 or from >= tubes.size() or to >= tubes.size():
		return 0
	var a: Array = tubes[from]
	var b: Array = tubes[to]
	if a.is_empty() or b.size() >= cap:
		return 0
	if not b.is_empty() and b[b.size() - 1] != a[a.size() - 1]:
		return 0
	return mini(Solver.run_of(a), cap - b.size())

func can_move(from: int, to: int) -> bool:
	return pour_amount(from, to) > 0

func do_move(from: int, to: int) -> bool:
	var n := pour_amount(from, to)
	if n <= 0:
		return false
	for i in n:
		tubes[to].append(tubes[from].pop_back())
	history.append([from, to, n])
	moves += 1
	return true

func can_undo() -> bool:
	return not history.is_empty()

func undo() -> bool:
	if history.is_empty():
		return false
	var m: Array = history.pop_back()
	var n: int = m[2] if m.size() > 2 else 1
	for i in n:
		tubes[m[0]].append(tubes[m[1]].pop_back())
	moves = maxi(0, moves - 1)
	return true

func can_add_tube() -> bool:
	return extra_used < MAX_EXTRA and tubes.size() < MAX_VIALS

func add_tube() -> bool:
	if not can_add_tube():
		return false
	tubes.append([])
	extra_used += 1
	return true

## Every vial is empty or holds a full set of one colour.
func solved() -> bool:
	if tubes.is_empty():
		return false
	for t in tubes:
		if t.is_empty():
			continue
		if t.size() != cap or not _single(t):
			return false
	return true

## Is there any legal move that isn't just shuffling a lone ball onto an empty tube?
func has_useful_move() -> bool:
	for a in tubes.size():
		for b in tubes.size():
			if can_move(a, b):
				var ta: Array = tubes[a]
				if tubes[b].is_empty() and _single(ta):
					continue
				return true
	return false

## 1..3 stars for finishing in `m` moves (3 = at or near par).
func stars_for(m: int) -> int:
	if par <= 0:
		return 1
	if m <= int(ceil(par * PAR_3)):
		return 3
	if m <= int(ceil(par * PAR_2)):
		return 2
	return 1

## Next pour for a hint, or [] if the solver finds none in time.
func hint(node_limit: int = 20000) -> Array:
	var r: Dictionary = Solver.solve(tubes, cap, node_limit, 2.0)
	if r.ok and not r.moves.is_empty():
		return r.moves[0]
	return []

## ---------- save ----------

func to_dict() -> Dictionary:
	return {"level": level, "level_no": level_no, "cap": cap, "par": par, "tubes": tubes, "moves": moves,
		"history": history, "extra": extra_used, "initial": initial}

func from_dict(d: Dictionary) -> bool:
	var tb = d.get("tubes", [])
	if not (tb is Array) or tb.size() < 3:
		return false
	level = clampi(int(d.get("level", 0)), 0, LEVELS.size() - 1)
	level_no = maxi(0, int(d.get("level_no", 0)))
	cap = clampi(int(d.get("cap", CAP)), 2, 8)
	par = int(d.get("par", 0))
	tubes = []
	for t in tb:
		var arr: Array = []
		for c in t:
			arr.append(int(c))
		if arr.size() > cap:
			return false
		tubes.append(arr)
	moves = int(d.get("moves", 0))
	history = []
	for m in d.get("history", []):
		history.append([int(m[0]), int(m[1]), int(m[2]) if m.size() > 2 else 1])
	extra_used = int(d.get("extra", 0))
	initial = []
	for t in d.get("initial", tb):
		var arr2: Array = []
		for c in t:
			arr2.append(int(c))
		initial.append(arr2)
	return true
