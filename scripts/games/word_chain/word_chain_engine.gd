extends RefCounted

## Word Chain: take turns saying a word that starts with the last letter of
## the previous word. No repeats, at least 3 letters. Whoever can't (or runs
## out of time) loses. Pure logic, no Nodes. The computer plays from a word
## list sized by the level: Easy knows everyday words only, Normal adds a
## random part of the dictionary, Hard knows every word and likes to end on
## awkward letters.

const WORDS_PATH := "res://scripts/games/word_chain/word_chain_words.txt.gz"
const COMMON_PATH := "res://scripts/games/word_chain/word_chain_common.txt.gz"
const MIN_LEN := 3
const START_LETTERS := "abcdefghilmnoprstw"
## Seconds to answer, per level (Easy, Normal, Hard); two players use TWO_PLAYER_TIME.
const TIMES := [40, 30, 20]
const TWO_PLAYER_TIME := 30
const NORMAL_SHARE := 0.15

var valid := {}          # word -> true (3-9 letters)
var by_first := {}       # letter -> Array of every word starting with it
var common_by_first := {}
var normal_extra := {}   # letter -> Array: the random part of the dictionary Normal knows
var remaining := {}      # letter -> how many unused words start with it

var mode: String = "cpu"   # "cpu" or "two"
var level: int = 1
var used := {}
var chain: Array = []      # [{"who": 0|1, "word": String}]
var need: String = ""      # the letter the next word starts with
var turn: int = 0
var winner: int = -1       # 0 / 1 once someone has lost
var reason: String = ""    # "timeout", "stumped" or "gave_up"

func load_words() -> void:
	if not valid.is_empty():
		return
	for w in _read_lines(WORDS_PATH):
		valid[w] = true
		var f: String = w[0]
		if not by_first.has(f):
			by_first[f] = []
		by_first[f].append(w)
	for f in by_first:
		remaining[f] = by_first[f].size()
	for w in _read_lines(COMMON_PATH):
		if valid.has(w):
			var f: String = w[0]
			if not common_by_first.has(f):
				common_by_first[f] = []
			common_by_first[f].append(w)

func _read_lines(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var raw := f.get_buffer(f.get_length())
	f.close()
	return raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8().split("\n", false)

func time_limit() -> int:
	return TWO_PLAYER_TIME if mode == "two" else TIMES[clampi(level, 0, 2)]

func new_game(game_mode: String, lvl: int) -> void:
	mode = game_mode
	level = clampi(lvl, 0, 2)
	used = {}
	for f in by_first:
		remaining[f] = by_first[f].size()
	chain = []
	turn = 0
	winner = -1
	reason = ""
	need = START_LETTERS[randi() % START_LETTERS.length()]
	normal_extra = {}
	if mode == "cpu" and level == 1:
		for f in by_first:
			var part: Array = []
			for w in by_first[f]:
				if w.length() <= 7 and randf() < NORMAL_SHARE:
					part.append(w)
			normal_extra[f] = part

func is_over() -> bool:
	return winner >= 0

## "ok", or why not: "short", "letter" (wrong first letter), "used", "not_word".
func check(word: String) -> String:
	if word.length() < MIN_LEN:
		return "short"
	if word[0] != need:
		return "letter"
	if used.has(word):
		return "used"
	if not valid.has(word):
		return "not_word"
	return "ok"

func play(word: String) -> String:
	var r := check(word)
	if r != "ok" or is_over():
		return r
	used[word] = true
	remaining[word[0]] = int(remaining.get(word[0], 1)) - 1
	chain.append({"who": turn, "word": word})
	need = word[word.length() - 1]
	turn = 1 - turn
	return "ok"

## The player whose turn it is loses.
func lose_turn(why: String) -> void:
	winner = 1 - turn
	reason = why

func words_by(who: int) -> int:
	var n := 0
	for e in chain:
		if e.who == who:
			n += 1
	return n

func _free(arr: Array) -> Array:
	var out: Array = []
	for w in arr:
		if not used.has(w) and w.length() >= MIN_LEN:
			out.append(w)
	return out

## How many unused words start with `letter` (what the next player has to choose from).
func options_after(letter: String) -> int:
	return int(remaining.get(letter, 0))

## The computer's word, or "" when it can't think of one.
func cpu_pick() -> String:
	# Even the computer runs dry after a long chain: a chance of giving up that grows with its own words.
	var own := words_by(1)
	var tired: float = [0.04 * maxi(0, own - 6), 0.02 * maxi(0, own - 10), 0.01 * maxi(0, own - 15)][level]
	if randf() < minf(tired, 0.5):
		return ""
	var pool: Array = _free(common_by_first.get(need, []))
	if level == 0:
		return "" if pool.is_empty() else pool[randi() % pool.size()]
	if level == 1:
		pool = _free(common_by_first.get(need, [])) + _free(normal_extra.get(need, []))
		if pool.is_empty():
			return ""
		var pick: String = pool[randi() % pool.size()]
		if randf() < 0.4:
			for attempt in 8:
				var alt: String = pool[randi() % pool.size()]
				if options_after(alt[alt.length() - 1]) < options_after(pick[pick.length() - 1]):
					pick = alt
		return pick
	var all: Array = by_first.get(need, [])
	if int(remaining.get(need, 0)) <= 0:
		return ""
	# Hard: sample a lot of words and keep the one that leaves you the fewest answers.
	var best: String = ""
	var best_n := 1 << 30
	for attempt in 150:
		var w: String = all[randi() % all.size()]
		if used.has(w) or w.length() > 8:
			continue
		var n := options_after(w[w.length() - 1])
		if n < best_n:
			best = w
			best_n = n
	if best != "":
		return best
	for w in all:
		if not used.has(w):
			return w
	return ""

func to_dict() -> Dictionary:
	return {"mode": mode, "level": level, "chain": chain, "need": need, "turn": turn, "winner": winner, "reason": reason,
		"normal_extra": normal_extra}

func from_dict(d: Dictionary) -> bool:
	var ch = d.get("chain", [])
	if not (ch is Array) or str(d.get("need", "")) == "":
		return false
	mode = "two" if str(d.get("mode", "cpu")) == "two" else "cpu"
	level = clampi(int(d.get("level", 1)), 0, 2)
	chain = []
	used = {}
	for e in ch:
		chain.append({"who": int(e.who), "word": str(e.word)})
		used[str(e.word)] = true
	for f in by_first:
		remaining[f] = by_first[f].size()
	for w in used:
		remaining[w[0]] = int(remaining.get(w[0], 1)) - 1
	need = str(d.need)
	turn = int(d.get("turn", 0))
	winner = int(d.get("winner", -1))
	reason = str(d.get("reason", ""))
	normal_extra = {}
	var ne = d.get("normal_extra", {})
	if ne is Dictionary:
		for k in ne:
			normal_extra[str(k)] = Array(ne[k])
	return true
