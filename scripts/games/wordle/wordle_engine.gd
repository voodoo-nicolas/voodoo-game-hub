extends RefCounted

## Wordle: guess a 5-letter word in 6 tries. After each guess every letter is
## marked CORRECT (right spot), PRESENT (in the word, elsewhere) or ABSENT.
## English guesses must be real words: every 5-letter word of the
## public-domain ENABLE list (plus all ANSWERS) ships gzipped in this folder.
## Spanish has no dictionary yet, so any 5 letters are accepted there.

const WORD_LENGTH := 5
const WORDS_PATH := "res://scripts/games/wordle/wordle_words.txt.gz"
const MAX_GUESSES := 6

enum Mark { ABSENT, PRESENT, CORRECT }

const ANSWERS := [
	"ABOUT", "ABOVE", "ACTOR", "ACUTE", "ADMIT", "ADOPT", "ADULT", "AFTER", "AGAIN", "AGENT",
	"AGREE", "AHEAD", "ALARM", "ALBUM", "ALERT", "ALIKE", "ALIVE", "ALLOW", "ALONE", "ALONG",
	"ALTER", "AMONG", "ANGER", "ANGLE", "ANGRY", "APART", "APPLE", "APPLY", "ARENA", "ARGUE",
	"ARISE", "ARMOR", "ARROW", "ASIDE", "ASSET", "AUDIO", "AVOID", "AWARD", "AWARE", "BACON",
	"BADGE", "BAKER", "BASIC", "BASIN", "BEACH", "BEARD", "BEAST", "BEGIN", "BEING", "BELOW",
	"BENCH", "BERRY", "BIRTH", "BLACK", "BLADE", "BLAME", "BLANK", "BLAST", "BLEND", "BLIND",
	"BLOCK", "BLOOD", "BLOOM", "BOARD", "BOAST", "BONUS", "BOOST", "BOOTH", "BRAIN", "BRAND",
	"BRAVE", "BREAD", "BREAK", "BRICK", "BRIDE", "BRIEF", "BRING", "BROAD", "BROWN", "BRUSH",
	"BUILD", "BUNCH", "BURST", "BUYER", "CABIN", "CABLE", "CAMEL", "CANDY", "CANOE", "CARGO",
	"CARRY", "CATCH", "CAUSE", "CHAIN", "CHAIR", "CHALK", "CHARM", "CHART", "CHASE", "CHEAP",
	"CHECK", "CHEEK", "CHEER", "CHESS", "CHEST", "CHIEF", "CHILD", "CHILL", "CHOIR", "CLAIM",
	"CLASS", "CLEAN", "CLEAR", "CLERK", "CLICK", "CLIFF", "CLIMB", "CLOCK", "CLOSE", "CLOTH",
	"CLOUD", "CLOWN", "COACH", "COAST", "COCOA", "COLOR", "COMET", "CORAL", "COUCH", "COUNT",
	"COURT", "COVER", "CRAFT", "CRANE", "CRASH", "CRAZY", "CREAM", "CRIME", "CRISP", "CROWD",
	"CROWN", "CRUSH", "CURVE", "CYCLE", "DAILY", "DAIRY", "DAISY", "DANCE", "DEALT", "DEATH",
	"DELAY", "DEPTH", "DIARY", "DINER", "DIRTY", "DITCH", "DIZZY", "DOUBT", "DOUGH", "DRAFT",
	"DRAIN", "DRAMA", "DRANK", "DREAM", "DRESS", "DRIFT", "DRILL", "DRINK", "DRIVE", "EAGER",
	"EAGLE", "EARLY", "EARTH", "EIGHT", "ELBOW", "EMPTY", "ENEMY", "ENJOY", "ENTER", "ENTRY",
	"EQUAL", "ERROR", "EVENT", "EVERY", "EXACT", "EXIST", "EXTRA", "FABLE", "FAINT", "FAIRY",
	"FAITH", "FALSE", "FANCY", "FEAST", "FENCE", "FERRY", "FEVER", "FIFTH", "FIGHT",
	"FINAL", "FIRST", "FLAME", "FLASH", "FLEET", "FLOAT", "FLOOD", "FLOOR", "FLOUR", "FLUTE",
	"FOCUS", "FORCE", "FORGE", "FORTH", "FORUM", "FOUND", "FRAME", "FRESH", "FRONT", "FROST",
	"FRUIT", "FUNNY", "GHOST", "GIANT", "GLASS", "GLOBE", "GLORY", "GLOVE", "GRACE", "GRADE",
	"GRAIN", "GRAND", "GRANT", "GRAPE", "GRAPH", "GRASS", "GRAVY", "GREAT", "GREEN", "GREET",
	"GRILL", "GROUP", "GUARD", "GUESS", "GUEST", "GUIDE", "HABIT", "HAPPY", "HEART", "HEAVY",
	"HELLO", "HONEY", "HORSE", "HOTEL", "HOUSE", "HUMAN", "HUMOR", "IDEAL", "IMAGE", "INDEX",
	"INNER", "INPUT", "ISSUE", "IVORY", "JELLY", "JEWEL", "JOINT", "JUDGE", "JUICE", "KNIFE",
	"KNOCK", "KOALA", "LABEL", "LARGE", "LASER", "LATER", "LAUGH", "LAYER", "LEARN", "LEASH",
	"LEAST", "LEMON", "LEVEL", "LIGHT", "LIMIT", "LINEN", "LLAMA", "LOCAL", "LOGIC", "LOOSE",
	"LUCKY", "LUNCH", "MAGIC", "MAJOR", "MANGO", "MAPLE", "MARCH", "MATCH", "MAYOR", "MEDAL",
	"MELON", "MERCY", "METAL", "MIGHT", "MINOR", "MINUS", "MODEL", "MONEY", "MONTH", "MORAL",
	"MOTOR", "MOUNT", "MOUSE", "MOUTH", "MOVIE", "MUSIC", "NERVE", "NEVER", "NIGHT", "NOBLE",
	"NOISE", "NORTH", "NOVEL", "NURSE", "OCEAN", "OFFER", "OFTEN", "OLIVE", "ONION", "OPERA",
	"ORBIT", "ORDER", "OTHER", "OTTER", "OUTER", "OWNER", "PAINT", "PANEL", "PANIC", "PAPER",
	"PARTY", "PASTA", "PATCH", "PEACE", "PEACH", "PEARL", "PEDAL", "PENNY", "PHONE", "PHOTO",
	"PIANO", "PIECE", "PILOT", "PITCH", "PIZZA", "PLACE", "PLAIN", "PLANE", "PLANT", "PLATE",
	"POINT", "POLAR", "POUND", "POWER", "PRESS", "PRICE", "PRIDE", "PRIME", "PRINT", "PRIZE",
	"PROOF", "PROUD", "PUPIL", "PUPPY", "QUEEN", "QUEST", "QUICK", "QUIET", "QUILT", "QUOTE",
	"RADIO", "RAINY", "RANCH", "RANGE", "RAPID", "RATIO", "RAVEN", "REACH", "READY", "REALM",
	"REBEL", "RELAX", "REPLY", "RHYME", "RIDER", "RIDGE", "RIGHT", "RIVER", "ROAST", "ROBIN",
	"ROBOT", "ROCKY", "ROUGH", "ROUND", "ROUTE", "ROYAL", "RULER", "RURAL", "SALAD", "SAUCE",
	"SCALE", "SCARF", "SCENE", "SCOUT", "SCREW", "SEVEN", "SHADE", "SHAKE", "SHAPE", "SHARE",
	"SHARK", "SHARP", "SHEEP", "SHELF", "SHELL", "SHIFT", "SHINE", "SHIRT", "SHOCK", "SHORE",
	"SHORT", "SHOUT", "SIGHT", "SKATE", "SKILL", "SKIRT", "SLEEP", "SLICE", "SLIDE", "SMALL",
	"SMART", "SMILE", "SMOKE", "SNACK", "SNAKE", "SOLAR", "SOLID", "SOLVE", "SOUND", "SOUTH",
	"SPACE", "SPARE", "SPARK", "SPEAK", "SPEED", "SPELL", "SPEND", "SPICE", "SPINE", "SPOON",
	"SPORT", "SQUAD", "STACK", "STAFF", "STAGE", "STAIR", "STAMP", "STAND", "STARE", "START",
	"STEAM", "STEEL", "STICK", "STILL", "STONE", "STOOL", "STORM", "STORY", "STOVE", "STRAW",
	"STUDY", "STYLE", "SUGAR", "SUNNY", "SUPER", "SWEET", "SWIFT", "SWING", "SWORD", "TABLE",
	"TASTE", "TEACH", "TEETH", "THANK", "THEME", "THICK", "THIEF", "THING", "THINK", "THIRD",
	"THORN", "THREE", "THROW", "THUMB", "TIGER", "TIMER", "TIRED", "TITLE", "TOAST", "TODAY",
	"TOOTH", "TOPIC", "TORCH", "TOTAL", "TOUCH", "TOUGH", "TOWEL", "TOWER", "TRACK", "TRADE",
	"TRAIL", "TRAIN", "TREAT", "TREND", "TRIAL", "TRIBE", "TRICK", "TRUCK", "TRULY", "TRUNK",
	"TRUST", "TRUTH", "TULIP", "TWIST", "UNCLE", "UNDER", "UNION", "UNITY", "UNTIL", "UPPER",
	"UPSET", "URBAN", "USUAL", "VALUE", "VIDEO", "VISIT", "VITAL", "VIVID", "VOICE", "WAGON",
	"WASTE", "WATCH", "WATER", "WHALE", "WHEAT", "WHEEL", "WHITE", "WHOLE", "WIDTH", "WITCH",
	"WOMAN", "WORLD", "WORRY", "WORTH", "WOUND", "WRIST", "WRITE", "WRONG", "YACHT", "YIELD",
	"YOUNG", "YOUTH", "ZEBRA",
]

## Spanish answers: accents dropped, as Spanish Wordle games do.
const ANSWERS_ES := [
	"ABRIL", "ACERO", "ACTOR", "AGUDO", "AHORA", "AJENO", "ALBUM", "ALDEA", "ALGUN", "ALMAS",
	"ALTAR", "ALTOS", "AMIGO", "ANCHO", "ANGEL", "ANIMO", "ANTES", "APODO", "ARBOL", "ARCOS",
	"ARENA", "ARMAR", "AROMA", "ARROZ", "ASADO", "ATLAS", "AUDIO", "AVION", "AYUDA", "BAILE",
	"BAJAR", "BALON", "BANCO", "BARCO", "BARRO", "BASTA", "BEBER", "BELLO", "BESOS", "BICHO",
	"BLUSA", "BOCAS", "BOLSA", "BOMBA", "BORDE", "BOTAS", "BRAZO", "BREVE", "BRISA", "BROMA",
	"BUENO", "BURRO", "CABLE", "CABRA", "CACAO", "CAJON", "CALLE", "CALMA", "CALOR", "CAMPO",
	"CANAL", "CANTO", "CAPAZ", "CARGA", "CARNE", "CARTA", "CASAS", "CAUSA", "CAZAR", "CEBRA",
	"CERCA", "CERDO", "CHICO", "CIELO", "CIFRA", "CINCO", "CINTA", "CIRCO", "CLARO", "CLASE",
	"CLAVO", "CLIMA", "COBRE", "COCHE", "COMER", "COPAS", "CORAL", "CORTO", "COSTA", "CREMA",
	"CRUCE", "CUERO", "CUEVA", "CULPA", "CURSO", "DANZA", "DATOS", "DEBER", "DECIR", "DEDOS",
	"DEJAR", "DESDE", "DICHA", "DIETA", "DOLOR", "DONDE", "DUCHA", "DUDAS", "DULCE", "DUROS",
	"ECHAR", "ENERO", "ENTRE", "ERROR", "ESTAR", "ETAPA", "EXITO", "FALDA", "FALSO", "FALTA",
	"FAROL", "FECHA", "FELIZ", "FERIA", "FIBRA", "FIRMA", "FLACO", "FLOTA", "FONDO",
	"FORMA", "FOTOS", "FRASE", "FRENO", "FRESA", "FRUTA", "FUEGO", "FUERA", "FUMAR", "GAFAS",
	"GALLO", "GANAR", "GANSO", "GASTO", "GATOS", "GENTE", "GIRAR", "GLOBO", "GOLPE", "GORDO",
	"GORRA", "GOTAS", "GRADO", "GRANO", "GRASA", "GRAVE", "GRITO", "GRUPO", "GUAPO", "GUSTO",
	"HABER", "HABLA", "HACER", "HASTA", "HIELO", "HIGOS", "HILOS", "HOJAS", "HONOR", "HORAS",
	"HOTEL", "HUEVO", "HUMOR", "IDEAS", "IGUAL", "ISLAS", "JABON", "JAMON", "JARRA", "JAULA",
	"JOVEN", "JUEGO", "JUGAR", "JUNIO", "JUNTO", "JUSTO", "LABIO", "LADOS", "LAGOS", "LANZA",
	"LAPIZ", "LARGO", "LATAS", "LAVAR", "LECHE", "LEGAL", "LEJOS", "LENTO", "LETRA", "LIBRO",
	"LIGAR", "LIMON", "LINEA", "LISTO", "LLAMA", "LLAVE", "LLENO", "LOBOS", "LOCAL", "LOMAS",
	"LUCHA", "LUGAR", "LUNES", "MADRE", "MAGIA", "MALLA", "MANGO", "MANOS", "MANTA", "MARCO",
	"MAREA", "MARZO", "MASAS", "MAYOR", "MEDIA", "MEDIO", "MELON", "MENTA", "MENOR", "MENTE",
	"MESAS", "METAL", "METRO", "MIEDO", "MIRAR", "MISMO", "MITAD", "MODAS", "MONTE", "MORAL",
	"MORIR", "MOTOR", "MUCHO", "MUNDO", "MUSEO", "NACER", "NADAR", "NARIZ", "NIEVE", "NIÑOS",
	"NIVEL", "NOCHE", "NORTE", "NOTAS", "NOVIA", "NUEVO", "NUNCA", "OBRAS", "OCASO", "ODIAR",
	"OLIVO", "ONDAS", "ORDEN", "OREJA", "PADRE", "PAGAR", "PAJAR", "PALMA", "PALOS", "PANAL",
	"PAPEL", "PARED", "PARTE", "PASAR", "PASEO", "PASTA", "PATIO", "PECES", "PEDIR", "PEINE",
	"PELEA", "PERRO", "PESCA", "PIANO", "PIEZA", "PILAS", "PINTA", "PISAR", "PISTA", "PIZZA",
	"PLATA", "PLATO", "PLAYA", "PLAZA", "PLUMA", "POBRE", "POCOS", "PODER", "POEMA", "POLLO",
	"PONER", "PRADO", "PRESO", "PRIMO", "PULGA", "PUNTA", "PUNTO", "QUESO", "RADIO", "RAMAS",
	"RATON", "RAZON", "REGLA", "RELOJ", "REMOS", "RESTO", "REYES", "RIEGO", "RISAS", "RITMO",
	"ROBOT", "ROCAS", "RONDA", "ROPAS", "RUBIO", "RUEDA", "RUIDO", "RUMBO", "SABER", "SABOR",
	"SACAR", "SALIR", "SALSA", "SALTO", "SALUD", "SANTO", "SELVA", "SEÑAL", "SERIE", "SIGLO",
	"SILLA", "SITIO", "SOBRE", "SOLAR", "SOÑAR", "SUAVE", "SUBIR", "SUCIO", "SUELO", "SUEÑO",
	"SUMAR", "TABLA", "TACOS", "TALLA", "TANGO", "TARDE", "TAREA", "TAXIS", "TECHO", "TEJER",
	"TELAS", "TEMAS", "TENER", "TENIS", "TIGRE", "TIMON", "TINTA", "TIRAR", "TOCAR", "TODOS",
	"TOMAR", "TORRE", "TORTA", "TOSER", "TOTAL", "TRAJE", "TRAMO", "TRATO", "TRIGO", "TROZO",
	"TUMBA", "TURNO", "UNION", "UNICO", "USUAL", "VACAS", "VAGON", "VALLE", "VAPOR", "VASOS",
	"VECES", "VELAS", "VENTA", "VERDE", "VIAJE", "VIDEO", "VIEJO", "VINOS", "VIRUS", "VISTA",
	"VIVIR", "VOLAR", "VOTAR", "VUELO", "YEGUA", "YERBA", "ZORRO", "ZUMOS",
]

var answer: String = ""
var guesses: Array = []  # submitted words
var marks: Array = []    # per guess, Array of Mark
var game_over: bool = false
var won: bool = false
var _bags: Dictionary = {}
## Spanish word list instead of English.
var spanish: bool = false
## Sorted lowercase English guesses; empty if the file couldn't be read, in
## which case any 5 letters are accepted rather than blocking play.
var _valid: PackedStringArray = PackedStringArray()

func _init() -> void:
	if not FileAccess.file_exists(WORDS_PATH):
		return
	var raw := FileAccess.get_file_as_bytes(WORDS_PATH)
	if raw.is_empty():
		return
	_valid = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8().split("\n", false)

func is_valid_guess(guess: String) -> bool:
	if spanish or _valid.is_empty():
		return true
	var w := guess.to_lower()
	var i := _valid.bsearch(w)
	return i < _valid.size() and _valid[i] == w

## Deals the next answer from a shuffled bag (per language) so none repeats
## until every word has come up. Pass `word` to force one (tests).
func reset(word: String = "") -> void:
	if word != "":
		answer = word.to_upper()
	else:
		var list: Array = ANSWERS_ES if spanish else ANSWERS
		var bag: Array = _bags.get(spanish, [])
		if bag.is_empty():
			bag = range(list.size())
			bag.shuffle()
			_bags[spanish] = bag
		answer = list[bag.pop_back()]
	guesses = []
	marks = []
	game_over = false
	won = false

## Returns "ok", "won", "lost", or an error ("short", "not_word", "over").
func submit(guess: String) -> String:
	if game_over:
		return "over"
	guess = guess.to_upper()
	if guess.length() != WORD_LENGTH:
		return "short"
	if not is_valid_guess(guess):
		return "not_word"
	guesses.append(guess)
	marks.append(score_guess(guess, answer))
	if guess == answer:
		game_over = true
		won = true
		return "won"
	if guesses.size() >= MAX_GUESSES:
		game_over = true
		return "lost"
	return "ok"

## Two passes so repeated letters are marked like the real game: exact hits
## first, then PRESENT only while unmatched copies of that letter remain.
static func score_guess(guess: String, target: String) -> Array:
	var result: Array = []
	result.resize(WORD_LENGTH)
	result.fill(Mark.ABSENT)
	var remaining := {}
	for i in range(WORD_LENGTH):
		if guess[i] == target[i]:
			result[i] = Mark.CORRECT
		else:
			remaining[target[i]] = int(remaining.get(target[i], 0)) + 1
	for i in range(WORD_LENGTH):
		if result[i] == Mark.CORRECT:
			continue
		var n: int = remaining.get(guess[i], 0)
		if n > 0:
			result[i] = Mark.PRESENT
			remaining[guess[i]] = n - 1
	return result

## Best-known mark per letter across all guesses, for coloring the keyboard.
func letter_states() -> Dictionary:
	var states := {}
	for g in range(guesses.size()):
		for i in range(WORD_LENGTH):
			var letter: String = guesses[g][i]
			var m: int = marks[g][i]
			if not states.has(letter) or m > states[letter]:
				states[letter] = m
	return states
