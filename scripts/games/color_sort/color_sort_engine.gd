extends RefCounted

## Color Sort: tubes of coloured balls. Move the top ball of one tube onto
## another tube if that tube has room and its top ball is the same colour (or
## it is empty). Sort every colour into its own tube. Pure logic, no Nodes.
## Puzzles are made by playing a solved board backwards with random legal
## "un-moves", so every puzzle can be solved.

const CAP := 4
## colours, empty tubes at the start, per level
const LEVELS := [
	{"colors": 4, "empty": 2},
	{"colors": 6, "empty": 2},
	{"colors": 8, "empty": 2},
	{"colors": 10, "empty": 2},
]
const MAX_EXTRA := 1

var level: int = 0
var tubes: Array = []        # each: Array of colour ints, bottom first
var moves: int = 0
var history: Array = []      # [from, to] of each move, for undo
var extra_used: int = 0
var initial: Array = []      # the puzzle as dealt, for Reset

func new_game(lvl: int) -> void:
	level = clampi(lvl, 0, LEVELS.size() - 1)
	var spec: Dictionary = LEVELS[level]
	for attempt in 30:
		_scramble(int(spec.colors), int(spec.empty))
		if _mixed_enough():
			break
	initial = tubes.duplicate(true)
	moves = 0
	history = []
	extra_used = 0

func reset() -> void:
	tubes = initial.duplicate(true)
	moves = 0
	history = []
	extra_used = 0

func _scramble(n: int, empty: int) -> void:
	tubes = []
	for c in n:
		var t: Array = []
		for k in CAP:
			t.append(c)
		tubes.append(t)
	for e in empty:
		tubes.append([])
	var steps: int = 60 + 14 * n
	var done := 0
	var guard := 0
	while done < steps and guard < steps * 30:
		guard += 1
		var a: int = randi() % tubes.size()
		var b: int = randi() % tubes.size()
		if a == b or tubes[a].is_empty() or tubes[b].size() >= CAP:
			continue
		# un-move: the top ball may only leave if the ball under it matches (or it is alone),
		# because only then could it have been poured there.
		var ta: Array = tubes[a]
		if ta.size() >= 2 and ta[ta.size() - 2] != ta[ta.size() - 1]:
			continue
		tubes[b].append(ta.pop_back())
		done += 1

func _mixed_enough() -> bool:
	var sorted_tubes := 0
	for t in tubes:
		if t.size() == CAP and _single(t):
			sorted_tubes += 1
	return sorted_tubes <= maxi(0, tubes.size() / 4) and not solved()

func _single(t: Array) -> bool:
	for c in t:
		if c != t[0]:
			return false
	return true

func color_count() -> int:
	return int(LEVELS[level].colors)

func can_move(from: int, to: int) -> bool:
	if from == to or from < 0 or to < 0 or from >= tubes.size() or to >= tubes.size():
		return false
	var a: Array = tubes[from]
	var b: Array = tubes[to]
	if a.is_empty() or b.size() >= CAP:
		return false
	return b.is_empty() or b[b.size() - 1] == a[a.size() - 1]

func do_move(from: int, to: int) -> bool:
	if not can_move(from, to):
		return false
	tubes[to].append(tubes[from].pop_back())
	history.append([from, to])
	moves += 1
	return true

func can_undo() -> bool:
	return not history.is_empty()

func undo() -> bool:
	if history.is_empty():
		return false
	var m: Array = history.pop_back()
	tubes[m[0]].append(tubes[m[1]].pop_back())
	moves = maxi(0, moves - 1)
	return true

func can_add_tube() -> bool:
	return extra_used < MAX_EXTRA

func add_tube() -> bool:
	if not can_add_tube():
		return false
	tubes.append([])
	extra_used += 1
	return true

## Every tube is empty or holds a full set of one colour.
func solved() -> bool:
	if tubes.is_empty():
		return false
	for t in tubes:
		if t.is_empty():
			continue
		if t.size() != CAP or not _single(t):
			return false
	return true

## Is there any legal move that isn't just shuffling a lone ball onto an empty tube?
func has_useful_move() -> bool:
	for a in tubes.size():
		for b in tubes.size():
			if can_move(a, b):
				var ta: Array = tubes[a]
				if tubes[b].is_empty() and (ta.size() == 1 or _single(ta)):
					continue
				return true
	return false

func to_dict() -> Dictionary:
	return {"level": level, "tubes": tubes, "moves": moves, "history": history, "extra": extra_used, "initial": initial}

func from_dict(d: Dictionary) -> bool:
	var tb = d.get("tubes", [])
	if not (tb is Array) or tb.size() < 3:
		return false
	level = clampi(int(d.get("level", 0)), 0, LEVELS.size() - 1)
	tubes = []
	for t in tb:
		var arr: Array = []
		for c in t:
			arr.append(int(c))
		if arr.size() > CAP:
			return false
		tubes.append(arr)
	moves = int(d.get("moves", 0))
	history = []
	for m in d.get("history", []):
		history.append([int(m[0]), int(m[1])])
	extra_used = int(d.get("extra", 0))
	initial = []
	for t in d.get("initial", tb):
		var arr2: Array = []
		for c in t:
			arr2.append(int(c))
		initial.append(arr2)
	return true
