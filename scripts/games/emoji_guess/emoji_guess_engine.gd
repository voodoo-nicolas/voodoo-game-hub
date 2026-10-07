extends RefCounted

## Emoji Guess: work out the word or phrase the emoji spell. Pure logic, no
## Nodes. The puzzles are data (emoji_guess_puzzles.json, with their own
## Spanish); answers are compared with case, accents, spaces and punctuation
## ignored. 1-4 players take turns, one puzzle each in turn.

const PUZZLES_PATH := "res://scripts/games/emoji_guess/emoji_guess_puzzles.json"
const ROUND := 8
const BASE_POINTS := 100
const HINT_COST := 30
const MIN_POINTS := 10
const ACCENTS := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}

var data := {"en": {}, "es": {}}
var spanish: bool = false
var tier: int = 0               # 0 easy, 1 normal, 2 hard
var players: int = 1
var current: int = 0            # whose turn it is
var queue: Array = []           # puzzle indices for this round
var index: int = 0
var scores: Array = []
var hints: int = 0
var solved: Array = []          # per player: puzzles solved

func load_data() -> void:
	if not data.en.is_empty():
		return
	var f := FileAccess.open(PUZZLES_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary:
		data = {"en": d.get("en", {}), "es": d.get("es", {})}

static func normalize(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		var c: String = ACCENTS.get(ch, ch)
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
	return out

func _pool() -> Array:
	return data["es" if spanish else "en"].get(["easy", "normal", "hard"][tier], [])

func new_game(t: int, p: int, use_spanish: bool) -> void:
	spanish = use_spanish
	tier = clampi(t, 0, 2)
	players = clampi(p, 1, 4)
	var all: Array = []
	for i in _pool().size():
		all.append(i)
	all.shuffle()
	queue = all.slice(0, mini(ROUND, all.size()))
	index = 0
	current = 0
	hints = 0
	scores = []
	solved = []
	for i in players:
		scores.append(0)
		solved.append(0)

func is_over() -> bool:
	return index >= queue.size()

func total() -> int:
	return queue.size()

func puzzle() -> Dictionary:
	return _pool()[queue[index]]

func emoji() -> String:
	return str(puzzle().e)

func category() -> String:
	return str(puzzle().c)

func answer() -> String:
	return normalize(str(puzzle().a[0]))

## Letter counts of each word of the main answer, e.g. [3, 4].
func pattern() -> Array:
	var out: Array = []
	for w in str(puzzle().a[0]).split(" ", false):
		out.append(normalize(w).length())
	return out

func check(typed: String) -> bool:
	var t := normalize(typed)
	if t == "":
		return false
	for a in puzzle().a:
		if normalize(str(a)) == t:
			return true
	return false

func points_now() -> int:
	return maxi(MIN_POINTS, BASE_POINTS - HINT_COST * hints)

## Banks the points and moves on. Call only after check() was true.
func solve_current() -> int:
	var pts := points_now()
	scores[current] += pts
	solved[current] += 1
	_advance()
	return pts

func skip() -> void:
	_advance()

func _advance() -> void:
	index += 1
	hints = 0
	current = (current + 1) % players

## Reveals one more letter of the answer; returns what is revealed so far.
func hint() -> String:
	var a := answer()
	if hints < a.length() - 1:
		hints += 1
	return a.substr(0, hints)

func prefix() -> String:
	return answer().substr(0, hints)

func winner() -> int:
	var best := 0
	var tie := false
	for i in range(1, players):
		if scores[i] > scores[best]:
			best = i
			tie = false
		elif scores[i] == scores[best]:
			tie = true
	return -1 if tie else best

func to_dict() -> Dictionary:
	return {"spanish": spanish, "tier": tier, "players": players, "current": current, "queue": queue, "index": index,
		"scores": scores, "hints": hints, "solved": solved}

func from_dict(d: Dictionary) -> bool:
	var q = d.get("queue", [])
	if not (q is Array) or q.is_empty():
		return false
	spanish = bool(d.get("spanish", false))
	tier = clampi(int(d.get("tier", 0)), 0, 2)
	players = clampi(int(d.get("players", 1)), 1, 4)
	queue = []
	for i in q:
		var n := int(i)
		if n < 0 or n >= _pool().size():
			return false
		queue.append(n)
	index = clampi(int(d.get("index", 0)), 0, queue.size())
	current = clampi(int(d.get("current", 0)), 0, players - 1)
	hints = int(d.get("hints", 0))
	scores = []
	solved = []
	var sc = d.get("scores", [])
	var sv = d.get("solved", [])
	for i in players:
		scores.append(int(sc[i]) if i < sc.size() else 0)
		solved.append(int(sv[i]) if i < sv.size() else 0)
	return true
