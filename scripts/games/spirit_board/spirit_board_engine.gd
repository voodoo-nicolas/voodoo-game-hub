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
		"here": ["YES", "YES", "I AM HERE", "ALWAYS"],
		"feel": ["COLD", "LONELY", "RESTLESS", "AT PEACE", "TIRED", "WATCHING"],
		"when": ["SOON", "NEVER", "TONIGHT", "IN A MONTH", "NEXT YEAR", "ON MONDAY", "NOT YET"],
		"where": ["HERE", "BEHIND YOU", "BELOW", "FAR AWAY", "HOME", "NORTH", "BY THE SEA"],
		"who": ["YOU", "A FRIEND", "ME", "NOBODY", "SOMEONE NEW", "FAMILY"],
		"why": ["FATE", "LOVE", "MONEY", "SECRETS", "YOU KNOW", "FEAR"],
		"how": ["SLOWLY", "WITH LOVE", "BY CHANCE", "IN SECRET", "TOGETHER", "WITH PATIENCE"],
		"what": ["LOVE", "A SECRET", "CHANGE", "A JOURNEY", "THE TRUTH", "A GIFT", "LUCK"],
		"color": ["RED", "BLUE", "GREEN", "BLACK", "WHITE", "GOLD", "PURPLE"],
		"day": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"],
		"maybe": ["MAYBE", "ASK LATER", "NOT YET", "UNCLEAR"],
	},
	"es": {
		"hello": ["HOLA"],
		"here": ["SI", "SI", "ESTOY AQUI", "SIEMPRE"],
		"feel": ["FRIO", "SOLO", "INQUIETO", "EN PAZ", "CANSADO", "VIGILANDO"],
		"when": ["PRONTO", "NUNCA", "ESTA NOCHE", "EN UN MES", "EL OTRO ANO", "EL LUNES", "AUN NO"],
		"where": ["AQUI", "DETRAS DE TI", "ABAJO", "MUY LEJOS", "EN CASA", "AL NORTE", "JUNTO AL MAR"],
		"who": ["TU", "UN AMIGO", "YO", "NADIE", "ALGUIEN NUEVO", "FAMILIA"],
		"why": ["DESTINO", "AMOR", "DINERO", "SECRETOS", "TU SABES", "MIEDO"],
		"how": ["DESPACIO", "CON AMOR", "POR AZAR", "EN SECRETO", "JUNTOS", "CON PACIENCIA"],
		"what": ["AMOR", "UN SECRETO", "UN CAMBIO", "UN VIAJE", "LA VERDAD", "UN REGALO", "SUERTE"],
		"color": ["ROJO", "AZUL", "VERDE", "NEGRO", "BLANCO", "DORADO", "VIOLETA"],
		"day": ["LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SABADO", "DOMINGO"],
		"maybe": ["QUIZAS", "MAS TARDE", "AUN NO", "NO SE"],
	},
}
## Question keywords, matched on the normalized question (lowercase, no
## accents, ñ -> n, punctuation -> spaces, padded with spaces). Checked in
## order, first match wins. [kind, English words, Spanish words]. A word
## starting with "^" only counts at the start of the question (Spanish "que"
## is everywhere: "¿crees que...?" is a yes/no question). The language of the
## matched word picks the language of the reply.
const KINDS := [
	["bye", [" goodbye ", " bye ", " farewell ", " good night "], [" adios ", " chau ", " chao ", " hasta luego ", " buenas noches "]],
	["name", [" your name ", " who are you ", " who is this ", " who is there ", " who s there ", " who is here ", " who are u "],
		[" como te llamas ", " tu nombre ", " quien eres ", " su nombre ", " quien esta ahi ", " quien anda ahi ", " quien esta aqui ", " quien sos "]],
	["here", [" are you there ", " are you here ", " is anyone there ", " is anybody there ", " is anyone here ", " is anybody here ", " is someone there ", " is someone here ", " any spirits "],
		[" estas ahi ", " estas aqui ", " hay alguien ", " hay algun espiritu ", " hay espiritus ", " sigues ahi "]],
	["feel", [" how are you ", " how do you feel ", " are you ok ", " are you okay ", " are you happy ", " are you sad "],
		[" como estas ", " como te sientes ", " estas bien ", " que tal "]],
	["year", [" what year ", " which year "], [" que ano ", " cual ano ", " que fecha "]],
	["age", [" how old ", " what age "], [" que edad ", " cuantos anos "]],
	["time", [" what time ", " what hour "], [" que hora "]],
	["day", [" what day ", " which day "], [" que dia ", " cual dia "]],
	["color", [" what colour ", " what color ", " which colour ", " which color ", " favourite colour ", " favorite color "], [" que color ", " cual color ", " color favorito "]],
	["number", [" how many ", " how much ", " what number ", " which number ", " how long "], [" cuantos ", " cuantas ", " cuanto ", " cuanta ", " que numero ", " cual numero "]],
	["when", ["^when ", "^and when "], [" cuando "]],
	["where", ["^where ", "^and where "], [" donde ", " adonde "]],
	["who", ["^who ", "^whom ", "^whose ", "^and who "], ["^quien ", "^quienes ", "^a quien ", "^con quien ", "^de quien "]],
	["why", ["^why ", "^and why "], [" por que "]],
	["how", ["^how "], ["^como ", "^de que manera "]],
	["what", ["^what ", "^which ", "^whats "], ["^que ", "^cual ", "^cuales ", "^de que ", "^en que "]],
	# Question words further on ("so when will...", "tell me where..."), unless
	# the question starts like a yes/no one ("will I be happy when I move?").
	["when", [" when "], []],
	["where", [" where "], []],
	["who", [" who "], []],
	["why", [" why "], []],
]
## English yes/no questions start with one of these.
const YESNO_START := [" is ", " are ", " am ", " do ", " does ", " did ", " will ", " would ",
	" can ", " could ", " should ", " shall ", " may ", " might ", " must ", " have ", " has ",
	" had ", " was ", " were ", " isn ", " aren ", " don ", " doesn ", " won ", " didn "]
## Common words that tell Spanish from English when no keyword matched.
const ES_HINTS := [" voy ", " vas ", " va ", " soy ", " eres ", " es ", " estoy ", " esta ", " mi ",
	" te ", " el ", " la ", " los ", " las ", " de ", " que ", " un ", " una ", " tengo ",
	" tiene ", " hay ", " manana ", " sera ", " seria ", " puedo ", " debo ", " con ",
	" si ", " ella ", " ellos ", " novio ", " novia ", " amor ", " y ", " por ", " para "]
const EN_HINTS := [" i ", " you ", " the ", " is ", " are ", " will ", " my ", " a ", " do ",
	" does ", " should ", " can ", " it ", " be ", " to ", " of ", " and ", " get ", " am ", " have "]
## Words that never make sense as one side of an "or" choice.
const OR_SKIP := ["not", "no", "nope", "what", "que", "it", "this", "that", "eso", "esto",
	"i", "you", "me", "yo", "tu", "a", "an", "the", "el", "la", "un", "una", "something", "algo"]

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
# Ask: the same question to the same spirit gets the same reply.
var _asked := {}             # normalized question -> reply

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
	_asked = {}

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

## The kind of question ("yesno" when nothing else fits).
static func kind_of(question: String) -> String:
	return classify(question, "en")[0]

## [kind, language]. The language is the matched keyword's, else a guess
## from common words, else `lang` (the app's language).
static func classify(question: String, lang: String) -> Array:
	var q := normalize(question)
	if q.strip_edges() == "":
		return ["yesno", lang]
	var yesno_start := false
	for w in YESNO_START:
		if q.begins_with(w):
			yesno_start = true
	for k in KINDS:
		for li in [1, 2]:
			for word in k[li]:
				var anchored: bool = word.begins_with("^")
				var hit := q.begins_with(" " + word.substr(1)) if anchored else q.contains(word)
				if not hit:
					continue
				if yesno_start and not anchored and li == 1 and k[0] in ["when", "where", "who", "why"]:
					continue
				return [k[0], "en" if li == 1 else "es"]
	# A greeting: short, and starts with hello / hola.
	var words := q.strip_edges().split(" ")
	if words.size() <= 3 and words[0] in ["hello", "hi", "hey", "greetings", "hola", "buenas", "buenos", "saludos"]:
		return ["hello", "es" if words[0] in ["hola", "buenas", "buenos", "saludos"] else "en"]
	return ["yesno", guess_lang(q, lang)]

## "es" or "en" by counting common words; `fallback` on a tie.
static func guess_lang(q: String, fallback: String) -> String:
	var es := 0
	var en := 0
	for w in ES_HINTS:
		if q.contains(w):
			es += 1
	for w in EN_HINTS:
		if q.contains(w):
			en += 1
	if es != en:
		return "es" if es > en else "en"
	return fallback

## "Pizza or tacos?" -> ["PIZZA", "TACOS"]: the word either side of the last
## "or" / "o" / "u". [] when there is no such choice ("...or not?").
static func choices(question: String) -> Array:
	var q := normalize(question)
	for sep in [" or ", " o ", " u "]:
		var i := q.rfind(sep)
		if i < 0:
			continue
		var before := q.substr(0, i).strip_edges().split(" ")
		var after := q.substr(i + sep.length()).strip_edges().split(" ")
		var x: String = before[before.size() - 1]
		var y: String = after[0]
		if x == "" or y == "" or x == y or x.length() > 12 or y.length() > 12:
			continue
		if x in OR_SKIP or y in OR_SKIP:
			continue
		return [x.to_upper(), y.to_upper()]
	return []

## The spirit's reply: "YES", "NO", "GOODBYE", or a word / number to spell.
## `lang` is the app's language, used when the question doesn't show its own.
## Asking the same spirit the same question again gets the same reply.
func answer_for(question: String, lang: String, rng: RandomNumberGenerator) -> String:
	var key := normalize(question)
	var typed := key.strip_edges() != ""
	if typed and _asked.has(key):
		return _asked[key]
	var r := _answer(question, lang, rng)
	if typed and r != "GOODBYE":
		_asked[key] = r
	return r

func _answer(question: String, lang: String, rng: RandomNumberGenerator) -> String:
	var c := classify(question, lang)
	var kind: String = c[0]
	var replies: Dictionary = REPLIES.get(c[1], REPLIES["en"])
	if kind in ["yesno", "who", "what"]:
		var pair := choices(question)
		if not pair.is_empty():
			return _pick(pair, rng)
	match kind:
		"bye":
			return "GOODBYE"
		"name":
			return spirit_name
		"year":
			return str(rng.randi_range(1888, 2066))
		"age":
			return str(rng.randi_range(16, 99))
		"time":
			return str(rng.randi_range(1, 12))
		"number":
			return str(rng.randi_range(1, 12) if rng.randf() < 0.7 else rng.randi_range(13, 99))
		"here":
			var h: String = _pick(replies["here"], rng)
			return "YES" if h == "SI" else h
		"who":
			if rng.randf() < 0.45:
				return "ABCDEFGHIJKLMNOPRSTVW"[rng.randi_range(0, 20)]
			return _pick(replies["who"], rng)
		"hello", "feel", "when", "where", "why", "how", "what", "color", "day":
			return _pick(replies[kind], rng)
	var roll := rng.randf()
	if roll < 0.45:
		return "YES"
	if roll < 0.85:
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
