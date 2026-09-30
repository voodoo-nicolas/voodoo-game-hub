extends RefCounted

## Word Search: themed words hidden in a letter grid in any of 8 directions.
## Pure logic, no Nodes.

const SIZE := 10
const WORD_COUNT := 8
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 1)]
const ALPHABET_EN := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const ALPHABET_ES := "ABCDEFGHIJLMNÑOPQRSTUVXYZ"

const THEMES_EN := {
	"Animals": ["TIGER", "ZEBRA", "MONKEY", "RABBIT", "TURTLE", "DOLPHIN", "EAGLE", "SHARK", "PANDA", "CAMEL", "HORSE", "OTTER", "KOALA", "LIZARD", "PARROT"],
	"Fruits": ["APPLE", "BANANA", "CHERRY", "GRAPE", "LEMON", "MANGO", "PEACH", "PLUM", "ORANGE", "MELON", "KIWI", "PAPAYA", "GUAVA", "LIME", "PEAR"],
	"Colors": ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE", "ORANGE", "PINK", "BROWN", "BLACK", "WHITE", "GRAY", "CYAN", "GOLD", "SILVER", "VIOLET"],
	"Sports": ["SOCCER", "TENNIS", "GOLF", "RUGBY", "HOCKEY", "BOXING", "SKIING", "ROWING", "KARATE", "CYCLING", "DIVING", "SURFING", "BASEBALL", "CHESS", "POLO"],
	"Weather": ["RAIN", "SNOW", "WIND", "STORM", "CLOUD", "SUNNY", "THUNDER", "FOG", "HAIL", "FROST", "BREEZE", "RAINBOW", "TORNADO", "HEAT", "MIST"],
	"Kitchen": ["SPOON", "FORK", "KNIFE", "PLATE", "BOWL", "OVEN", "KETTLE", "PAN", "GRATER", "TOASTER", "FRIDGE", "LADLE", "WHISK", "SINK", "MUG"],
	"Ocean": ["WAVE", "CORAL", "SHELL", "WHALE", "SQUID", "SAND", "REEF", "TIDE", "CRAB", "SEAL", "ANCHOR", "ISLAND", "OYSTER", "SALT", "KELP"],
	"Space": ["PLANET", "STAR", "MOON", "COMET", "ORBIT", "GALAXY", "ROCKET", "MARS", "VENUS", "SATURN", "NEBULA", "METEOR", "SUN", "ALIEN", "COSMOS"],
	"Music": ["PIANO", "GUITAR", "DRUMS", "VIOLIN", "FLUTE", "TRUMPET", "HARP", "SONG", "RHYTHM", "CHORUS", "BASS", "TEMPO", "OPERA", "BAND", "BANJO"],
	"Body": ["HEART", "BRAIN", "HAND", "FOOT", "KNEE", "ELBOW", "SHOULDER", "NOSE", "MOUTH", "TOOTH", "FINGER", "ANKLE", "WRIST", "LUNGS", "SKIN"],
}
const THEMES_ES := {
	"Animales": ["TIGRE", "CEBRA", "MONO", "CONEJO", "TORTUGA", "DELFIN", "AGUILA", "TIBURON", "PANDA", "CAMELLO", "CABALLO", "NUTRIA", "LORO", "LAGARTO", "OVEJA"],
	"Frutas": ["MANZANA", "BANANA", "CEREZA", "UVA", "LIMON", "MANGO", "DURAZNO", "CIRUELA", "NARANJA", "MELON", "KIWI", "PAPAYA", "PIÑA", "PERA", "FRESA"],
	"Colores": ["ROJO", "AZUL", "VERDE", "AMARILLO", "MORADO", "NARANJA", "ROSADO", "MARRON", "NEGRO", "BLANCO", "GRIS", "CELESTE", "DORADO", "PLATEADO", "VIOLETA"],
	"Deportes": ["FUTBOL", "TENIS", "GOLF", "RUGBY", "HOCKEY", "BOXEO", "ESQUI", "REMO", "KARATE", "CICLISMO", "BUCEO", "SURF", "BEISBOL", "AJEDREZ", "VOLEY"],
	"Clima": ["LLUVIA", "NIEVE", "VIENTO", "TORMENTA", "NUBE", "SOLEADO", "TRUENO", "NIEBLA", "GRANIZO", "HELADA", "BRISA", "ARCOIRIS", "TORNADO", "CALOR", "RAYO"],
	"Cocina": ["CUCHARA", "TENEDOR", "CUCHILLO", "PLATO", "TAZON", "HORNO", "OLLA", "SARTEN", "RALLADOR", "TOSTADORA", "NEVERA", "BATIDOR", "FREGADERO", "TAZA", "VASO"],
	"Mar": ["OLA", "CORAL", "CONCHA", "BALLENA", "CALAMAR", "ARENA", "ARRECIFE", "MAREA", "CANGREJO", "FOCA", "ANCLA", "ISLA", "OSTRA", "SAL", "ALGA"],
	"Espacio": ["PLANETA", "ESTRELLA", "LUNA", "COMETA", "ORBITA", "GALAXIA", "COHETE", "MARTE", "VENUS", "SATURNO", "NEBULOSA", "METEORO", "SOL", "COSMOS", "ASTRO"],
	"Musica": ["PIANO", "GUITARRA", "TAMBOR", "VIOLIN", "FLAUTA", "TROMPETA", "ARPA", "CANCION", "RITMO", "CORO", "BAJO", "TEMPO", "OPERA", "BANDA", "MARACAS"],
	"Cuerpo": ["CORAZON", "CEREBRO", "MANO", "PIE", "RODILLA", "CODO", "HOMBRO", "NARIZ", "BOCA", "DIENTE", "DEDO", "TOBILLO", "MUÑECA", "PULMON", "PIEL"],
}

var grid: Array = []          # SIZE*SIZE letters
var words: Array = []         # [{word, start: Vector2i, dir: Vector2i, found: bool}]
var theme: String = ""

func new_puzzle(spanish: bool, rng_seed: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var themes: Dictionary = THEMES_ES if spanish else THEMES_EN
	var names: Array = themes.keys()
	theme = names[rng.randi_range(0, names.size() - 1)]
	var pool: Array = themes[theme].duplicate()
	for attempt in 50:
		_shuffle(pool, rng)
		if _place_all(pool, rng):
			break
	var alphabet: String = ALPHABET_ES if spanish else ALPHABET_EN
	for i in SIZE * SIZE:
		if grid[i] == "":
			grid[i] = alphabet[rng.randi_range(0, alphabet.length() - 1)]

func _place_all(pool: Array, rng: RandomNumberGenerator) -> bool:
	grid.clear()
	grid.resize(SIZE * SIZE)
	grid.fill("")
	words.clear()
	for w in pool:
		if words.size() == WORD_COUNT:
			break
		if w.length() > SIZE:
			continue
		for attempt in 100:
			var d: Vector2i = DIRS[rng.randi_range(0, DIRS.size() - 1)]
			var s := Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
			if _fits(w, s, d):
				for k in w.length():
					var p: Vector2i = s + d * k
					grid[p.y * SIZE + p.x] = w[k]
				words.append({"word": w, "start": s, "dir": d, "found": false})
				break
	return words.size() == WORD_COUNT

func _fits(w: String, s: Vector2i, d: Vector2i) -> bool:
	var e := s + d * (w.length() - 1)
	if e.x < 0 or e.y < 0 or e.x >= SIZE or e.y >= SIZE:
		return false
	for k in w.length():
		var p := s + d * k
		var ch: String = grid[p.y * SIZE + p.x]
		if ch != "" and ch != w[k]:
			return false
	return true

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## Cells from a to b if they form a straight line (row, column or diagonal).
static func line(a: Vector2i, b: Vector2i) -> Array:
	var d := b - a
	if not (d.x == 0 or d.y == 0 or abs(d.x) == abs(d.y)):
		return []
	var n: int = max(abs(d.x), abs(d.y))
	var step := Vector2i(signi(d.x), signi(d.y))
	var out: Array = []
	for k in n + 1:
		out.append(a + step * k)
	return out

## Marks and returns the index of the word selected from a to b (either way
## round), or -1.
func try_select(a: Vector2i, b: Vector2i) -> int:
	for i in words.size():
		var w: Dictionary = words[i]
		if w.found:
			continue
		var end: Vector2i = w.start + w.dir * (w.word.length() - 1)
		if (a == w.start and b == end) or (a == end and b == w.start):
			w.found = true
			return i
	return -1

func all_found() -> bool:
	for w in words:
		if not w.found:
			return false
	return true
