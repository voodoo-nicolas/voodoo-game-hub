extends RefCounted

## Cryptogram: a proverb with every letter swapped for another. Decode it.
## Pure logic, no Nodes. The quotes are data (cryptogram_quotes.json, EN and
## ES); Spanish text drops its accents but keeps the Ñ as a letter.

const QUOTES_PATH := "res://scripts/games/cryptogram/cryptogram_quotes.json"
const EN_ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const ES_ALPHABET := "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ"
const ACCENTS := {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ü": "U"}

var quotes := {"en": [], "es": []}
var spanish: bool = false
var level: int = 0               # 0 short, 1 medium, 2 long
var plain: String = ""           # the answer, upper case, accents removed
var cipher := {}                 # plain letter -> cipher letter
var truth := {}                  # cipher letter -> plain letter
var encoded: String = ""
var guess := {}                  # cipher letter -> the player's guess ("" = none)
var given := {}                  # cipher letters a hint revealed
var hints: int = 0

func load_quotes() -> void:
	if not quotes.en.is_empty():
		return
	var f := FileAccess.open(QUOTES_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary:
		quotes = {"en": d.get("en", []), "es": d.get("es", [])}

func alphabet() -> String:
	return ES_ALPHABET if spanish else EN_ALPHABET

static func normalize(s: String) -> String:
	var out := ""
	for ch in s.to_upper():
		out += ACCENTS.get(ch, ch)
	return out

func _letters_of(s: String) -> Array:
	var seen := {}
	var out: Array = []
	for ch in s:
		if alphabet().contains(ch) and not seen.has(ch):
			seen[ch] = true
			out.append(ch)
	return out

func _count_letters(s: String) -> int:
	var n := 0
	for ch in s:
		if alphabet().contains(ch):
			n += 1
	return n

## lvl 0/1/2 = the shortest / middle / longest third of the quotes.
func new_game(lvl: int, use_spanish: bool) -> void:
	spanish = use_spanish
	level = clampi(lvl, 0, 2)
	var pool: Array = []
	for q in quotes["es" if spanish else "en"]:
		pool.append(normalize(q))
	pool.sort_custom(func(a, b): return _count_letters(a) < _count_letters(b))
	var third: int = maxi(1, pool.size() / 3)
	var from: int = level * third
	var to: int = pool.size() if level == 2 else from + third
	plain = pool[from + randi() % (to - from)]
	_make_cipher()

func _make_cipher() -> void:
	var alpha := alphabet()
	var letters: Array = []
	for ch in alpha:
		letters.append(ch)
	var shuffled: Array = letters.duplicate()
	for attempt in 300:
		shuffled.shuffle()
		var clash := false
		for i in letters.size():
			if letters[i] == shuffled[i]:
				clash = true
				break
		if not clash:
			break
	cipher = {}
	truth = {}
	for i in letters.size():
		cipher[letters[i]] = shuffled[i]
		truth[shuffled[i]] = letters[i]
	encoded = ""
	for ch in plain:
		encoded += cipher.get(ch, ch)
	guess = {}
	given = {}
	hints = 0
	for c in _letters_of(encoded):
		guess[c] = ""

func cipher_letters() -> Array:
	return guess.keys()

func count_of(c: String) -> int:
	return encoded.count(c)

## Puts `p` ("" clears) under cipher letter `c`. A guess is used for one
## cipher letter at a time, so it moves if it was already placed elsewhere.
func set_guess(c: String, p: String) -> bool:
	if not guess.has(c) or given.has(c):
		return false
	if p != "":
		for k in guess:
			if guess[k] == p:
				if given.has(k):
					return false
				guess[k] = ""
	guess[c] = p
	return true

func is_filled() -> bool:
	for c in guess:
		if guess[c] == "":
			return false
	return true

func wrong_letters() -> Array:
	var out: Array = []
	for c in guess:
		if guess[c] != "" and guess[c] != truth[c]:
			out.append(c)
	return out

func solved() -> bool:
	if guess.is_empty():
		return false
	for c in guess:
		if guess[c] != truth[c]:
			return false
	return true

## Reveals the most common cipher letter that isn't right yet. Returns it ("" if none).
func hint() -> String:
	var best := ""
	for c in guess:
		if guess[c] == truth[c]:
			continue
		if best == "" or count_of(c) > count_of(best):
			best = c
	if best == "":
		return ""
	for k in guess:
		if guess[k] == truth[best] and k != best:
			guess[k] = ""
	guess[best] = truth[best]
	given[best] = true
	hints += 1
	return best

func filled_count() -> int:
	var n := 0
	for c in guess:
		if guess[c] != "":
			n += 1
	return n

func to_dict() -> Dictionary:
	return {"spanish": spanish, "level": level, "plain": plain, "cipher": cipher, "guess": guess, "given": given, "hints": hints}

func from_dict(d: Dictionary) -> bool:
	var pl := str(d.get("plain", ""))
	var ci = d.get("cipher", {})
	if pl == "" or not (ci is Dictionary) or ci.is_empty():
		return false
	spanish = bool(d.get("spanish", false))
	level = clampi(int(d.get("level", 0)), 0, 2)
	plain = pl
	cipher = {}
	truth = {}
	for k in ci:
		cipher[str(k)] = str(ci[k])
		truth[str(ci[k])] = str(k)
	encoded = ""
	for ch in plain:
		encoded += cipher.get(ch, ch)
	guess = {}
	given = {}
	for c in _letters_of(encoded):
		guess[c] = ""
	var g = d.get("guess", {})
	if g is Dictionary:
		for c in g:
			if guess.has(str(c)):
				guess[str(c)] = str(g[c])
	var gv = d.get("given", {})
	if gv is Dictionary:
		for c in gv:
			if guess.has(str(c)):
				given[str(c)] = true
	hints = int(d.get("hints", 0))
	return true
