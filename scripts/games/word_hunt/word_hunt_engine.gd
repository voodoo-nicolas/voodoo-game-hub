extends RefCounted

## Word Hunt: find words in a 4×4 grid of letter dice by chaining touching
## tiles (diagonals count), each tile at most once per word. Words of 3+
## letters from the English word list score by length. Pure logic, no Nodes.
##
## The word list (public-domain ENABLE, gzipped) ships in this folder; it is
## kept as one sorted PackedStringArray and searched with bsearch(), which
## also answers "is this a prefix of any word?" for the solver.

const WORDS_PATH := "res://scripts/games/word_hunt/word_hunt_words.txt.gz"
const SIZE := 4
const DICE := ["AAEEGN", "ABBJOO", "ACHOPS", "AFFKPS", "AOOTTW", "CIMOTU", "DEILRX", "DELRVY",
	"DISTTY", "EEGHNW", "EEINSU", "EHRTVW", "EIOSST", "ELRTTY", "HIMNUQ", "HLNNRZ"]

var words := PackedStringArray()
var grid: Array = []          # 16 strings ("A".."Z", "QU")
var found: Array = []
var score: int = 0

func load_words() -> bool:
	if not words.is_empty():
		return true
	var f := FileAccess.open(WORDS_PATH, FileAccess.READ)
	if f == null:
		return false
	var raw := f.get_buffer(f.get_length())
	f.close()
	var text := raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	words = text.split("\n", false)
	return not words.is_empty()

func new_board(rng_seed: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var dice: Array = DICE.duplicate()
	for i in range(dice.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = dice[i]
		dice[i] = dice[j]
		dice[j] = t
	grid.clear()
	for d in dice:
		var face: String = d[rng.randi_range(0, 5)]
		grid.append("QU" if face == "Q" else face)
	found.clear()
	score = 0

func is_word(w: String) -> bool:
	var i := words.bsearch(w)
	return i < words.size() and words[i] == w

func is_prefix(p: String) -> bool:
	var i := words.bsearch(p)
	return i < words.size() and words[i].begins_with(p)

static func adjacent(a: int, b: int) -> bool:
	return a != b and abs(a / SIZE - b / SIZE) <= 1 and abs(a % SIZE - b % SIZE) <= 1

func path_word(path: Array) -> String:
	var s := ""
	for i in path:
		s += grid[i]
	return s.to_lower()

static func points(w: String) -> int:
	match w.length():
		3, 4: return 1
		5: return 2
		6: return 3
		7: return 5
	return 11

## "ok", "short", "unknown" or "repeat".
func submit(path: Array) -> String:
	var w := path_word(path)
	if w.length() < 3:
		return "short"
	if found.has(w):
		return "repeat"
	if not is_word(w):
		return "unknown"
	found.append(w)
	score += points(w)
	return "ok"

## Every word on the board, longest first.
func all_words() -> Array:
	var out := {}
	for start in SIZE * SIZE:
		_dfs(start, [start], grid[start].to_lower(), out)
	var list: Array = out.keys()
	list.sort_custom(func(a, b): return a.length() > b.length() or (a.length() == b.length() and a < b))
	return list

func _dfs(cell: int, path: Array, s: String, out: Dictionary) -> void:
	if not is_prefix(s):
		return
	if s.length() >= 3 and is_word(s):
		out[s] = true
	for nb in SIZE * SIZE:
		if adjacent(cell, nb) and not path.has(nb):
			path.append(nb)
			_dfs(nb, path, s + grid[nb].to_lower(), out)
			path.pop_back()
