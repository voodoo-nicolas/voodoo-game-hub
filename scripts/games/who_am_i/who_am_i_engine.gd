extends RefCounted

## Who Am I?: five clues about a secret animal, food, thing or job, from the
## vaguest to the giveaway. Everybody picks from four names on their own panel;
## the sooner you get it right, the more it is worth (5 points after the first
## clue ... 1 after the last). A wrong pick locks you out of that round. Pure
## logic, no Nodes. The items are data (who_am_i_items.json, with their own
## Spanish).

const ITEMS_PATH := "res://scripts/games/who_am_i/who_am_i_items.json"
const ROUND := 8
const CLUES := 5
## Seconds between clues: Relaxed, Normal, Fast.
const PACES := [7.0, 5.0, 3.5]

var data := {"en": [], "es": []}
var spanish: bool = false
var pace: int = 1
var players: int = 1
var scores: Array = []
var queue: Array = []
var index: int = 0
var clue: int = 1            # how many clues are showing
var phase: String = "done"   # ready, live, done
var winner: int = -1
var locked: Array = []
var options: Array = []      # per player: 4 names
var correct: Array = []      # per player: index of the right name
var solved: Array = []

func load_items() -> void:
	if not data.en.is_empty():
		return
	var f := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary:
		data = {"en": d.get("en", []), "es": d.get("es", [])}

func _pool() -> Array:
	return data["es" if spanish else "en"]

func new_game(p: int, pc: int, use_spanish: bool) -> void:
	spanish = use_spanish
	players = clampi(p, 1, 4)
	pace = clampi(pc, 0, 2)
	var all: Array = []
	for i in _pool().size():
		all.append(i)
	all.shuffle()
	queue = all.slice(0, mini(ROUND, all.size()))
	index = 0
	scores = []
	solved = []
	for i in players:
		scores.append(0)
		solved.append(0)
	phase = "done"
	winner = -1

func is_over() -> bool:
	return index >= queue.size()

func total_rounds() -> int:
	return queue.size()

func item() -> Dictionary:
	return _pool()[queue[index]]

func name_of() -> String:
	return str(item().n)

func clues_shown() -> Array:
	var out: Array = []
	for i in clue:
		out.append(str(item().k[i]))
	return out

func new_round() -> void:
	winner = -1
	clue = 1
	phase = "ready"
	locked = []
	options = []
	correct = []
	var it: Dictionary = item()
	var same: Array = []
	var other: Array = []
	for x in _pool():
		if x.n == it.n:
			continue
		if x.c == it.c:
			same.append(str(x.n))
		else:
			other.append(str(x.n))
	same.shuffle()
	other.shuffle()
	for p in players:
		locked.append(false)
		var opts: Array = [str(it.n)]
		var extra: Array = (same.duplicate() + other)
		if not same.is_empty():
			same.shuffle()
			extra = same.duplicate() + other
		for e in extra:
			if opts.size() >= 4:
				break
			opts.append(e)
		opts.shuffle()
		options.append(opts)
		correct.append(opts.find(str(it.n)))

func begin() -> void:
	phase = "live"

func points_now() -> int:
	return CLUES + 1 - clue

## The next clue, if there is one. Returns false when all five are showing already.
func reveal() -> bool:
	if clue >= CLUES:
		return false
	clue += 1
	return true

func all_locked() -> bool:
	return not locked.has(false)

## "win", "wrong" or "ignored".
func tap_option(p: int, i: int) -> String:
	if phase != "live" or locked[p] or winner >= 0:
		return "ignored"
	if i == correct[p]:
		winner = p
		scores[p] += points_now()
		solved[p] += 1
		phase = "done"
		return "win"
	locked[p] = true
	if all_locked():
		phase = "done"
	return "wrong"

## Time ran out with nobody right.
func give_up_round() -> void:
	phase = "done"

func next_round() -> void:
	index += 1

func match_winner() -> int:
	var best := 0
	var tie := false
	for i in range(1, players):
		if scores[i] > scores[best]:
			best = i
			tie = false
		elif scores[i] == scores[best]:
			tie = true
	return -1 if tie else best
