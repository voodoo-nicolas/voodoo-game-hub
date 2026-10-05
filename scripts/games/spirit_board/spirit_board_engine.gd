extends RefCounted

## Spirit Board: a talking board (letters, numbers, YES / NO / GOODBYE) and
## its planchette. Pure logic, no Nodes.
##
## Board coordinates are normalized: x 0..1 across, y 0..1 down, and the
## board is ASPECT times wider than tall. Distances are measured in board
## heights (`dist()`), so hit areas stay round.
##
## Two ways to play:
## - Ask: answer_for() reads the question (EN/ES keywords) and picks a reply;
##   begin_spell() turns it into stops, step_spirit() glides the planchette.
## - Séance: the players move the planchette; seance_step() reports a symbol
##   once the planchette has rested on it for DWELL seconds.

const ASPECT := 1.45
const REST := Vector2(0.5, 1.07)    # just below the board, waiting
const GAP := Vector2(0.5, 0.71)     # the clear band between the letters and numbers
const HIT := 0.06            # how close (board heights) counts as "on" a symbol
const HIT_WORD := 0.085      # YES / NO / GOODBYE are bigger
const DWELL := 0.9           # séance: seconds resting on a symbol to pick it
const SLOW := 0.25           # séance: slower than this (heights/s) is resting
const HOP_BASE := 0.45       # spirit: seconds per hop, plus HOP_PER per height
const HOP_PER := 1.1
const LINGER := 0.6          # spirit: seconds it stays on each symbol
const WORDS := ["YES", "NO", "GOODBYE"]

## Replies, all caps, no accents or Ñ (the board has A-Z only). ALL-CAPS
## literals are skipped by the i18n extractor, so they stay out of es.json.
const NAMES := ["MARIE", "ELIAS", "ODETTE", "LUCIEN", "CLAIRE", "HENRI", "AGATHA", "JEAN",
	"DELPHINE", "MORTIMER", "VIOLETTE", "AUGUSTE"]
const REPLIES := {
	"en": {
		"hello": ["HELLO"],
		"when": ["SOON", "NEVER", "TONIGHT", "IN A MONTH", "NOW", "ON MONDAY"],
		"where": ["HERE", "BEHIND YOU", "BELOW", "FAR AWAY", "HOME", "NORTH"],
		"who": ["YOU", "A FRIEND", "ME", "NOBODY", "YOUR EX"],
		"why": ["FATE", "LOVE", "MONEY", "SECRETS", "YOU KNOW"],
		"maybe": ["MAYBE", "SOON", "ASK LATER", "NOT YET"],
	},
	"es": {
		"hello": ["HOLA"],
		"when": ["PRONTO", "NUNCA", "ESTA NOCHE", "EN UN MES", "YA", "EL LUNES"],
		"where": ["AQUI", "DETRAS DE TI", "ABAJO", "MUY LEJOS", "EN CASA", "AL NORTE"],
		"who": ["TU", "UN AMIGO", "YO", "NADIE", "TU EX"],
		"why": ["DESTINO", "AMOR", "DINERO", "SECRETOS", "TU SABES"],
		"maybe": ["QUIZAS", "PRONTO", "MAS TARDE", "AUN NO"],
	},
}
## Question keywords, matched on the normalized question (lowercase, no
## accents, ñ -> n, punctuation -> spaces, padded with spaces). First match wins.
const KINDS := [
	["bye", [" goodbye ", " bye ", " farewell ", " adios ", " chau ", " hasta luego "]],
	["name", [" your name ", " who are you ", " who is this ", " como te llamas ", " tu nombre ", " quien eres ", " su nombre "]],
	["hello", [" hello ", " hi ", " hey ", " hola ", " buenas "]],
	["year", [" what year ", " which year ", " que ano ", " en que ano ", " cual ano "]],
	["number", [" how many ", " how old ", " how much ", " what number ", " cuantos ", " cuantas ", " cuanto ", " cuanta ", " que edad ", " que numero "]],
	["when", [" when ", " cuando "]],
	["where", [" where ", " donde ", " adonde "]],
	["who", [" who ", " whom ", " quien ", " quienes "]],
	["why", [" why ", " por que ", " porque "]],
]

var symbols: Array = []      # [{key, pos: Vector2, rot: float}]
var spirit_name := ""

# The planchette (both modes).
var pos := REST
# Ask mode: the stops still to make.
var stops: Array = []        # keys; "" = a pause between words
var moving := false
var _from := REST
var _to := REST
var _hop_t := 0.0
var _hop_len := 1.0
var _linger := 0.0
var _key := ""               # the stop being travelled to
var _sway := 0.0
# Séance mode.
var _dwell_key := ""
var _dwell_t := 0.0
var _picked := ""            # must leave this symbol before it counts again

func _init() -> void:
	_layout()

func _layout() -> void:
	symbols = []
	symbols.append({"key": "YES", "pos": Vector2(0.2, 0.13), "rot": 0.0})
	symbols.append({"key": "NO", "pos": Vector2(0.8, 0.13), "rot": 0.0})
	_arc("ABCDEFGHIJKLM", 0.5, 0.17)
	_arc("NOPQRSTUVWXYZ", 0.68, 0.15)
	var digits := "1234567890"
	for i in digits.length():
		symbols.append({"key": digits[i], "pos": Vector2(0.2 + 0.6 * i / 9.0, 0.79), "rot": 0.0})
	symbols.append({"key": "GOODBYE", "pos": Vector2(0.5, 0.94), "rot": 0.0})

## Letters along an arch: `base` is the height at the ends, `rise` how much
## higher the middle is. Each letter leans with the curve.
func _arc(letters: String, base: float, rise: float) -> void:
	var n := letters.length()
	for i in n:
		var x := 0.08 + 0.84 * i / float(n - 1)
		var d := (x - 0.5) / 0.42
		var y := base - rise * (1.0 - d * d)
		var slope := rise * 2.0 * d / 0.42  # dy/dx in board units
		symbols.append({"key": letters[i], "pos": Vector2(x, y), "rot": atan(slope / ASPECT)})

func start(rng: RandomNumberGenerator) -> void:
	spirit_name = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	pos = REST
	stops = []
	moving = false
	_dwell_key = ""
	_dwell_t = 0.0
	_picked = ""

## Distance in board heights.
static func dist(a: Vector2, b: Vector2) -> float:
	return Vector2((a.x - b.x) * ASPECT, a.y - b.y).length()

func pos_of(key: String) -> Vector2:
	for s in symbols:
		if s["key"] == key:
			return s["pos"]
	return REST

## The symbol under the planchette's window, or "".
func nearest(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for s in symbols:
		var d := dist(p, s["pos"])
		var limit := HIT_WORD if s["key"].length() > 1 else HIT
		if d < limit and d < best_d:
			best_d = d
			best = s["key"]
	return best

# ---------- Ask: what the spirit replies ----------

static func normalize(q: String) -> String:
	var s := q.to_lower()
	var from := "áéíóúüñàèìòùâêîôûç"
	var to := "aeiouunaeiouaeiouc"
	for i in from.length():
		s = s.replace(from[i], to[i])
	var out := ""
	for ch in s:
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else " "
	while out.contains("  "):
		out = out.replace("  ", " ")
	return " " + out.strip_edges() + " "

static func kind_of(question: String) -> String:
	var q := normalize(question)
	for k in KINDS:
		for word in k[1]:
			if q.contains(word):
				return k[0]
	return "yesno"

## The spirit's reply: "YES", "NO", "GOODBYE", or a word / number to spell.
func answer_for(question: String, lang: String, rng: RandomNumberGenerator) -> String:
	var replies: Dictionary = REPLIES.get(lang, REPLIES["en"])
	match kind_of(question):
		"bye":
			return "GOODBYE"
		"name":
			return spirit_name
		"year":
			return str(rng.randi_range(1888, 2066))
		"number":
			return str(rng.randi_range(1, 12) if rng.randf() < 0.7 else rng.randi_range(13, 99))
		"who":
			if rng.randf() < 0.55:
				return "ABCDEFGHIJKLMNOPRSTVW"[rng.randi_range(0, 20)]
			return _pick(replies["who"], rng)
		"hello", "when", "where", "why":
			return _pick(replies[kind_of(question)], rng)
	var r := rng.randf()
	if r < 0.45:
		return "YES"
	if r < 0.85:
		return "NO"
	return _pick(replies["maybe"], rng)

static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	return list[rng.randi_range(0, list.size() - 1)]

## The stops that spell `reply`: a word symbol, or one stop per character
## ("" between words).
static func spell(reply: String) -> Array:
	if reply in WORDS:
		return [reply]
	var out: Array = []
	for ch in reply:
		if ch == " ":
			out.append("")
		elif (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out.append(ch)
	return out

# ---------- Ask: the planchette gliding by itself ----------

func begin_spell(reply: String) -> void:
	stops = spell(reply)
	moving = true
	_next_hop()

func _next_hop() -> void:
	_from = pos
	if stops.is_empty():
		_key = "<rest>"
		_to = REST
	else:
		_key = stops.pop_front()
		# A pause between words: drift along the clear band above the numbers.
		_to = pos_of(_key) if _key != "" else Vector2(GAP.x + randf_range(-0.1, 0.1), GAP.y)
	_hop_t = 0.0
	_hop_len = HOP_BASE + HOP_PER * dist(_from, _to)
	_sway = randf_range(-0.06, 0.06)
	_linger = 0.0

## Moves the planchette. Returns the key on the frame it reaches a symbol,
## " " for a word gap, "done" when it is back at rest, else "".
func step_spirit(delta: float) -> String:
	if not moving:
		return ""
	if _hop_t < _hop_len:
		_hop_t = minf(_hop_t + delta, _hop_len)
		var t := _hop_t / _hop_len
		var e := t * t * (3.0 - 2.0 * t)
		var d := _to - _from
		var side := Vector2(-d.y, d.x * ASPECT).normalized() * _sway * sin(PI * t)
		pos = _from.lerp(_to, e) + Vector2(side.x / ASPECT, side.y)
		if _hop_t >= _hop_len:
			pos = _to
			if _key == "<rest>":
				moving = false
				return "done"
			return _key if _key != "" else " "
		return ""
	_linger += delta
	if _linger >= (LINGER if _key != "" else LINGER * 0.6):
		_next_hop()
	return ""

# ---------- Séance: the players move it ----------

## Call every frame with the planchette's position and speed (heights/s).
## Returns a symbol's key once it has rested on it for DWELL seconds.
func seance_step(p: Vector2, speed: float, delta: float) -> String:
	pos = p
	var k := nearest(p)
	if k != _picked:
		_picked = ""
	if k != _dwell_key:
		_dwell_key = k
		_dwell_t = 0.0
	if k == "" or k == _picked:
		return ""
	if speed < SLOW:
		_dwell_t += delta
	else:
		_dwell_t = maxf(0.0, _dwell_t - delta)
	if _dwell_t >= DWELL:
		_picked = k
		_dwell_t = 0.0
		return k
	return ""

## 0..1 how far the current symbol is towards being picked (for a glow).
func dwell_progress() -> float:
	if _dwell_key == "" or _dwell_key == _picked:
		return 0.0
	return clampf(_dwell_t / DWELL, 0.0, 1.0)

func dwell_key() -> String:
	return _dwell_key
