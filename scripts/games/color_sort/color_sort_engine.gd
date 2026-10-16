extends RefCounted

## Color Sort: vials of coloured liquid layers. Pour the top colour run of one
## vial onto another if that vial is empty or its top colour matches, as much as
## fits. Sort every colour into its own vial. Pure logic, no Nodes.
## Levels are made by playing the solved board backwards with random legal
## "un-pours" (seeded, so a level number always gives the same puzzle), so every
## level can be solved. color_sort_solver.gd finds a par for the star rating.
##
## Every tenth level is special (mystery layers, locked vials, move cap, timer,
## corked vials, blocked pours, boss): the rules sit in `rules` and are checked by
## the solver (color_sort_solver.gd) when the level is made, so they stay solvable.
## Some levels have a big central vial. It takes only the colour(s) it asks for
## (one colour, or two / three stacked in order), only by pouring into it, and
## the level is won when it is full AND every small vial is sorted.

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
## `to` of a pour (and of its history entry) that goes into the central vial.
const CENTER := -2
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
## Central vial. Empty center_order = this level has none.
var center_order: Array = [] # colours it takes, bottom to top (one layer block each)
var center_seg: int = 0      # balls of each colour it holds
var center: Array = []       # what is in it now, bottom first
## Special-level rules: {"kind", "locks", "blocked", "drain", "mystery", "cap_moves",
## "time"}; see color_sort_solver.gd. Empty = a plain level.
var rules: Dictionary = {}
var hidden: Array = []       # mystery: per vial, bottom layers still hidden
var initial_hidden: Array = []
var attempt_used: int = 0    # which generator try gave this level (stored in the par table)
## How hard the engine tries to prove a special level solvable before it changes the deal.
const VERIFY_NODES := 1500
const VERIFY_TRIES := 80
const KINDS := ["mystery", "locked", "moves", "timer", "corks", "mixed"]

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
## "center" = number of colours the central vial takes (0 = no central vial): every
## third level from 6, two colours from 40 and three from 100 on. They count inside "colors".
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
	var special := special_kind(n)
	if special == "boss":
		colors = mini(MAX_COLORS, colors + 3)
	var center_colors := 0
	if n >= 6 and n % 3 == 0:
		center_colors = 1
		if n >= 40 and n % 6 == 0:
			center_colors = 2
		if n >= 100 and n % 12 == 0:
			center_colors = 3
	# the central vial leaks every 8 pours on every ninth level from 27 (not on special ones)
	var drain := 8 if (center_colors > 0 and n >= 27 and n % 9 == 0 and special == "") else 0
	# The central vial's colours start in small vials too: room for them is added.
	var vials: int = colors + empty
	if center_colors > 0:
		vials = colors - center_colors + center_vials(capacity, center_colors) + empty
	return {"level": n, "tier": t, "colors": colors, "cap": capacity, "empty": empty, "center": center_colors,
		"vials": vials, "special": special, "drain": drain}

## "" for a plain level; every tenth level is special, every fiftieth a boss.
static func special_kind(n: int) -> String:
	if n < 10 or n % 10 != 0:
		return ""
	if n % 50 == 0:
		return "boss"
	return KINDS[(n / 10 - 1) % KINDS.size()]

## Balls of each colour the central vial holds: one and a half small vials' worth.
static func center_seg_for(capacity: int) -> int:
	return capacity * 3 / 2

## Small vials' worth of room the central vial's balls need at the start.
static func center_vials(capacity: int, center_colors: int) -> int:
	return int(ceil(center_colors * center_seg_for(capacity) / float(capacity)))

## ---------- creating a puzzle ----------

## Campaign level n (1-based). Special levels are generated until the solver
## proves them solvable under their rules; the try that worked is kept in the par
## table (ATT), so for levels in the table nothing is searched here.
func load_level(n: int) -> void:
	var spec := spec_for(n)
	level_no = int(spec.level)
	level = 0
	cap = int(spec.cap)
	rules = {}
	attempt_used = 0
	var seed_value: int = 7919 * level_no + 17
	var special: String = spec.special
	var sol_len := 0
	var in_table: bool = level_no <= ParTable.PAR.size()
	if special != "" or int(spec.drain) > 0:
		var att := -2  # -2 = not known yet, -1 = the plain fallback, else the try to use
		if level_no <= ParTable.ATT.size():
			att = int(ParTable.ATT[level_no - 1])
		var tries: Array = range(VERIFY_TRIES) if att == -2 else ([att] if att >= 0 else [])
		var found := false
		for a in tries:
			_generate(int(spec.colors), int(spec.empty), cap, seed_value + a * 31337, int(spec.center))
			rules = _make_rules(spec, seed_value + a * 7)
			_finish_deal()
			if att >= 0:
				found = true
				attempt_used = a
				break
			var r: Dictionary = Solver.solve(tubes, cap, VERIFY_NODES, 3.0, _center_info(), _solver_rules())
			if r.ok:
				found = true
				attempt_used = a
				sol_len = r.moves.size()
				break
		if not found:
			rules = {}
			attempt_used = -1
			_generate(int(spec.colors), int(spec.empty), cap, seed_value, int(spec.center))
			_finish_deal()
			sol_len = 0
	else:
		_generate(int(spec.colors), int(spec.empty), cap, seed_value, int(spec.center))
		_finish_deal()
	par = int(ParTable.PAR[level_no - 1]) if in_table else 0
	if par <= 0:
		par = sol_len if sol_len > 0 else gen_moves
	_set_limits()

## Rules for special level `spec` on the dealt vials (see color_sort_solver.gd).
func _make_rules(spec: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kind: String = spec.special
	var r := {"kind": kind if kind != "" else "pressure"}
	var n: int = tubes.size()
	var used := {}
	var locks: Array = []
	var blocked: Array = []
	var pours_locks := 0
	var corks := 0
	var pipes := 0
	match kind:
		"mystery":
			r["mystery"] = true
		"locked":
			pours_locks = mini(3, 1 + level_no / 60)
		"corks":
			corks = mini(4, 2 + level_no / 80)
		"mixed":
			pipes = mini(4, 2 + level_no / 80)
		"moves", "timer":
			pass
		"boss":
			pours_locks = 1
			corks = 1
			pipes = 2
	for i in pours_locks:
		var v := _pick_vial(rng, used, n)
		locks.append({"v": v, "pours": 3 + rng.randi() % 4})
	for i in corks:
		var v2 := _pick_vial(rng, used, n)
		locks.append({"v": v2, "after": v2 + 1 if v2 + 1 < n else v2 - 1, "cork": true})
	for i in pipes:
		var a: int = rng.randi() % n
		var b: int = (a + 1 + rng.randi() % (n - 1)) % n
		blocked.append([a, b])
	if not locks.is_empty():
		r["locks"] = locks
	if not blocked.is_empty():
		r["blocked"] = blocked
	if int(spec.drain) > 0:
		r["drain"] = int(spec.drain)
	return r

func _pick_vial(rng: RandomNumberGenerator, used: Dictionary, n: int) -> int:
	var v: int = rng.randi() % n
	for i in n:
		if not used.has(v):
			break
		v = (v + 1) % n
	used[v] = true
	return v

## Move cap and time limit come from par, so they follow the level's own difficulty.
func _set_limits() -> void:
	if rules.is_empty():
		return
	var kind: String = rules.get("kind", "")
	if kind == "moves" or kind == "boss":
		rules["cap_moves"] = int(ceil(par * PAR_2)) + 1
	if kind == "timer":
		rules["time"] = par * 5 + 25

func _solver_rules() -> Dictionary:
	return {"locks": rules.get("locks", []), "blocked": rules.get("blocked", []),
		"drain": int(rules.get("drain", 0)), "moves0": moves}

## Old four-difficulty entry (random puzzle).
func new_game(lvl: int) -> void:
	level = clampi(lvl, 0, LEVELS.size() - 1)
	level_no = 0
	cap = CAP
	var spec: Dictionary = LEVELS[level]
	_generate(int(spec.colors), int(spec.empty), CAP, randi(), 0)
	_finish_deal()
	par = gen_moves

func _finish_deal() -> void:
	initial = tubes.duplicate(true)
	moves = 0
	history = []
	extra_used = 0
	hidden = []
	if rules.get("mystery", false):
		for t in tubes:
			hidden.append(0 if t.is_empty() else t.size() - Solver.run_of(t))
	initial_hidden = hidden.duplicate(true)

func reset() -> void:
	tubes = initial.duplicate(true)
	hidden = initial_hidden.duplicate(true)
	center = []
	moves = 0
	history = []
	extra_used = 0

## Plays the solved board backwards. An un-pour takes k balls off the top run of
## vial b (or of the central vial) and puts them on vial a, so that the forward
## pour a -> b moves exactly those k balls (see the two cases below). Solvable
## by construction. `center_colors` of the n colours go to the central vial.
func _generate(n: int, empty: int, capacity: int, seed_value: int, center_colors: int) -> void:
	var rng := RandomNumberGenerator.new()
	var small: int = n - center_colors
	var seg: int = center_seg_for(capacity)
	for attempt in 150:
		rng.seed = seed_value + attempt * 104729
		tubes = []
		for c in small:
			var t: Array = []
			for k in capacity:
				t.append(c)
			tubes.append(t)
		for e in empty + (center_vials(capacity, center_colors) if center_colors > 0 else 0):
			tubes.append([])
		center_order = []
		center_seg = 0
		center = []
		if center_colors > 0:
			center_seg = seg
			for c in center_colors:
				center_order.append(small + c)
				for k in seg:
					center.append(small + c)
		var steps: int = n * capacity * 3
		var done := 0
		while done < steps:
			var options := _unpour_options(capacity, false)
			if options.is_empty():
				break
			var o: Array = options[rng.randi() % options.size()]
			_unpour(o, 1 + rng.randi() % int(o[2]))
			done += 1
		# The central vial starts empty: keep un-pouring from it alone.
		while not center.is_empty():
			var options := _unpour_options(capacity, true)
			if options.is_empty():
				break
			var o: Array = options[rng.randi() % options.size()]
			_unpour(o, 1 + rng.randi() % int(o[2]))
			done += 1
		gen_moves = done
		cap = capacity
		if center.is_empty() and done >= steps / 4 and _mixed_enough():
			_shuffle_colors(n, rng)
			return

## Every legal un-pour as [a, b, kmax]: balls come off the top of b (b == CENTER:
## the central vial) and go onto vial a.
func _unpour_options(capacity: int, center_only: bool) -> Array:
	var options: Array = []
	var sources: Array = []
	if not center_only:
		for b in tubes.size():
			sources.append(b)
	if not center.is_empty():
		sources.append(CENTER)
	for b in sources:
		var tb: Array
		var limit: int
		var full: bool
		if b == CENTER:
			tb = center
			var s: int = (center.size() - 1) / center_seg
			limit = center.size() - s * center_seg  # only the top block can come off
			full = center.size() == (s + 1) * center_seg
		else:
			tb = tubes[b]
			if tb.is_empty():
				continue
			var r: int = Solver.run_of(tb)
			## b must keep its top colour (or end empty), else the forward pour onto it is illegal.
			limit = r if r == tb.size() else r - 1
			full = tb.size() == capacity
		var c: int = tb[tb.size() - 1]
		for a in tubes.size():
			var ta: Array = tubes[a]
			if a == b or ta.size() >= capacity:
				continue
			## Landing on a vial that already shows colour c only works if b was full:
			## then the forward pour is cut short by b's room and moves exactly k.
			if not ta.is_empty() and ta[ta.size() - 1] == c and not full:
				continue
			var kmax: int = mini(limit, capacity - ta.size())
			if kmax >= 1:
				options.append([a, b, kmax])
	return options

func _unpour(o: Array, k: int) -> void:
	var src: Array = center if int(o[1]) == CENTER else tubes[o[1]]
	for i in k:
		tubes[o[0]].append(src.pop_back())

## Hands the colours out in a seeded random order, so level 1 isn't always the
## first palette colour, and the central vial's colour varies.
func _shuffle_colors(n: int, rng: RandomNumberGenerator) -> void:
	var perm: Array = range(n)
	for i in range(n - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = perm[i]
		perm[i] = perm[j]
		perm[j] = tmp
	for t in tubes:
		for i in t.size():
			t[i] = perm[t[i]]
	for i in center_order.size():
		center_order[i] = perm[center_order[i]]
	for i in center.size():
		center[i] = perm[center[i]]

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

## ---------- central vial ----------

func has_center() -> bool:
	return not center_order.is_empty()

func center_total() -> int:
	return center_order.size() * center_seg

func center_full() -> bool:
	return has_center() and center.size() >= center_total()

## Colour the central vial wants next, or -1 (none / already full).
func center_need() -> int:
	if not has_center() or center.size() >= center_total():
		return -1
	return int(center_order[center.size() / center_seg])

## Balls a pour from vial `from` into the central vial would move (0 if illegal).
func center_amount(from: int) -> int:
	var need := center_need()
	if need < 0 or from < 0 or from >= tubes.size() or is_locked(from):
		return 0
	var a: Array = tubes[from]
	if a.is_empty() or a[a.size() - 1] != need:
		return 0
	var seg_end: int = (center.size() / center_seg + 1) * center_seg
	return mini(Solver.run_of(a), seg_end - center.size())

## ---------- rules ----------

## Balls a pour from -> to would move (0 if illegal). to == CENTER: the central vial.
func pour_amount(from: int, to: int) -> int:
	if to == CENTER:
		return center_amount(from)
	if from == to or from < 0 or to < 0 or from >= tubes.size() or to >= tubes.size():
		return 0
	if is_locked(from) or is_locked(to) or is_blocked(from, to):
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

## Is vial v locked (a padlock or a cork) right now?
func is_locked(v: int) -> bool:
	if rules.is_empty() or not rules.has("locks"):
		return false
	return Solver.locked(tubes, cap, v, moves, rules.locks)

## Pours left until a "pours" lock on v opens (0 if it has none / opens another way).
func lock_pours_left(v: int) -> int:
	for l in rules.get("locks", []):
		if int(l.v) == v and l.has("pours"):
			return maxi(0, int(l.pours) - moves)
	return 0

func is_blocked(a: int, b: int) -> bool:
	for p in rules.get("blocked", []):
		if (int(p[0]) == a and int(p[1]) == b) or (int(p[0]) == b and int(p[1]) == a):
			return true
	return false

## Mystery levels: is layer k of vial v still hidden ("?")?
func is_hidden(v: int, k: int) -> bool:
	return v < hidden.size() and k < int(hidden[v])

## Out of moves on a move-capped level?
func failed() -> bool:
	return int(rules.get("cap_moves", 0)) > 0 and moves >= int(rules.cap_moves) and not solved()

func moves_left() -> int:
	return maxi(0, int(rules.get("cap_moves", 0)) - moves)

func do_move(from: int, to: int) -> bool:
	var n := pour_amount(from, to)
	if n <= 0:
		return false
	var dest: Array = center if to == CENTER else tubes[to]
	for i in n:
		dest.append(tubes[from].pop_back())
	moves += 1
	# Pressure: every D-th pour the central vial leaks its top layer back into the
	# first vial with room (not once it is full).
	var leak := -1
	var drain: int = int(rules.get("drain", 0))
	if drain > 0 and moves % drain == 0 and not center.is_empty() and not center_full():
		leak = Solver.leak_target(tubes, cap)
		if leak >= 0:
			tubes[leak].append(center.pop_back())
	history.append([from, to, n, leak])
	_reveal()
	return true

## Mystery: a layer shows once it is in the top run of its vial.
func _reveal() -> void:
	for i in hidden.size():
		if i < tubes.size():
			var t: Array = tubes[i]
			hidden[i] = mini(int(hidden[i]), 0 if t.is_empty() else t.size() - Solver.run_of(t))

func can_undo() -> bool:
	return not history.is_empty()

func undo() -> bool:
	if history.is_empty():
		return false
	var m: Array = history.pop_back()
	var n: int = m[2] if m.size() > 2 else 1
	if m.size() > 3 and int(m[3]) >= 0:
		center.append(tubes[m[3]].pop_back())
	var src: Array = center if int(m[1]) == CENTER else tubes[m[1]]
	for i in n:
		tubes[m[0]].append(src.pop_back())
	moves = maxi(0, moves - 1)
	return true

func can_add_tube() -> bool:
	return extra_used < MAX_EXTRA and tubes.size() < MAX_VIALS

func add_tube() -> bool:
	if not can_add_tube():
		return false
	tubes.append([])
	if not hidden.is_empty():
		hidden.append(0)
	extra_used += 1
	return true

## Every small vial is empty or holds a full set of one colour, and the central
## vial (if any) is full.
func solved() -> bool:
	if tubes.is_empty():
		return false
	if has_center() and not center_full():
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
		if center_amount(a) > 0:
			return true
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

## Next pour [from, to] for a hint (to == CENTER: the central vial), or [] if the
## solver finds none in time.
func hint(node_limit: int = 20000) -> Array:
	var r: Dictionary = Solver.solve(tubes, cap, node_limit, 2.0, _center_info(), _solver_rules())
	if r.ok and not r.moves.is_empty():
		return r.moves[0]
	return []

## Solver's view of the central vial ({} = none).
func _center_info() -> Dictionary:
	if not has_center():
		return {}
	return {"order": center_order, "seg": center_seg, "size": center.size()}

## ---------- save ----------

func to_dict() -> Dictionary:
	return {"level": level, "level_no": level_no, "cap": cap, "par": par, "tubes": tubes, "moves": moves,
		"history": history, "extra": extra_used, "initial": initial,
		"center_order": center_order, "center_seg": center_seg, "center": center,
		"rules": rules, "hidden": hidden, "initial_hidden": initial_hidden}

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
		history.append([int(m[0]), int(m[1]), int(m[2]) if m.size() > 2 else 1, int(m[3]) if m.size() > 3 else -1])
	extra_used = int(d.get("extra", 0))
	initial = []
	for t in d.get("initial", tb):
		var arr2: Array = []
		for c in t:
			arr2.append(int(c))
		initial.append(arr2)
	center_order = []
	for c in d.get("center_order", []):
		center_order.append(int(c))
	center_seg = int(d.get("center_seg", 0))
	center = []
	for c in d.get("center", []):
		center.append(int(c))
	if center_order.is_empty() != (center_seg == 0) or center.size() > center_total():
		return false
	rules = {}
	var rd = d.get("rules", {})
	if rd is Dictionary:
		rules = rd.duplicate(true)
		if rules.has("locks"):
			for l in rules.locks:
				for key in l:
					if key != "cork":
						l[key] = int(l[key])
		if rules.has("blocked"):
			for p in rules.blocked:
				p[0] = int(p[0])
				p[1] = int(p[1])
		for key in ["drain", "cap_moves", "time"]:
			if rules.has(key):
				rules[key] = int(rules[key])
	hidden = []
	for v in d.get("hidden", []):
		hidden.append(int(v))
	initial_hidden = []
	for v in d.get("initial_hidden", d.get("hidden", [])):
		initial_hidden.append(int(v))
	return true
