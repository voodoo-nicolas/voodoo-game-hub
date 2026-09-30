extends RefCounted

## Anagrams: unscramble the letters into a word. Ten words per round; a hint
## reveals the next letter but halves that word's points. In English any
## real word that uses every letter counts (checked against the bundled
## public-domain word list); in Spanish, any word from the Spanish list.
## Pure logic, no Nodes.

const WORDS_PATH := "res://scripts/games/anagrams/anagrams_words.txt.gz"
const ROUND := 10

const EN := ["PLANET", "GARDEN", "SILVER", "BRIDGE", "CASTLE", "WINTER", "SUMMER", "SPRING", "AUTUMN", "ORANGE",
	"PURPLE", "YELLOW", "PENCIL", "WINDOW", "MIRROR", "BASKET", "BUTTER", "CANDLE", "CARPET", "CIRCLE",
	"COFFEE", "COOKIE", "DINNER", "DOCTOR", "DRAGON", "FAMILY", "FLOWER", "FOREST", "FRIEND", "GUITAR",
	"HAMMER", "ISLAND", "JUNGLE", "KITTEN", "LADDER", "LETTER", "MARKET", "MONKEY", "NUMBER", "PALACE",
	"PARROT", "PEPPER", "PICNIC", "PILLOW", "POCKET", "POTATO", "PUZZLE", "RABBIT", "ROCKET", "SCHOOL",
	"SHADOW", "SPIDER", "STREET", "SUNSET", "TICKET", "TOMATO", "TRAVEL", "TURTLE", "VALLEY", "WALLET",
	"ANCHOR", "BEACON", "BOTTLE", "BUCKET", "CAMERA", "CANYON", "CHEESE", "CHERRY", "CLOUDY", "COTTON",
	"DESERT", "ENGINE", "FINGER", "GALAXY", "GOLDEN", "HELMET", "INSECT", "JACKET", "KETTLE", "LEMONS",
	"MAGNET", "MEADOW", "NAPKIN", "OYSTER", "PEANUT", "PIRATE", "PLANTS", "RIBBON", "SADDLE", "SALMON",
	"STABLE", "TEMPLE", "THRONE", "TUNNEL", "VIOLIN", "WAFFLE", "WIZARD", "ZIPPER", "BREEZE", "CRAYON",
	"APPLE", "BEACH", "BREAD", "CHAIR", "CLOUD", "DANCE", "EAGLE", "FIELD", "GHOST", "GRAPE",
	"HEART", "HOUSE", "JUICE", "KNIFE", "LEMON", "LIGHT", "MANGO", "MUSIC", "NIGHT", "OCEAN",
	"PAINT", "PIANO", "QUEEN", "RIVER", "SMILE", "SNAKE", "STORM", "SUGAR", "TABLE", "TIGER",
	"TRAIN", "WATER", "WHALE", "ZEBRA", "BRAIN", "CANDY", "DREAM", "FROST", "GLOVE", "HONEY",
	"JEWEL", "MAPLE", "OLIVE", "PEARL", "ROBIN", "SHELL", "SPOON", "TOAST", "BLANKET", "CABBAGE",
	"CAPTAIN", "CHICKEN", "COUNTRY", "DOLPHIN", "EXAMPLE", "FEATHER", "HARBOUR", "JOURNEY", "KITCHEN", "LIBRARY",
	"MONSTER", "MORNING", "PENGUIN", "PICTURE", "RAINBOW", "SANDWICH", "THUNDER", "TRUMPET", "VOLCANO", "WEATHER",
	"BALLOON", "BICYCLE", "CARTOON", "CONCERT", "CRYSTAL", "DIAMOND", "FACTORY", "HOLIDAY", "LANTERN", "MUSTARD",
	"OCTOPUS", "PANTHER", "PYRAMID", "SHAMPOO", "SQUIRREL", "STADIUM", "TEACHER", "TORNADO", "UNICORN", "VILLAGE"]

const ES := ["CASA", "PERRO", "GATO", "ARBOL", "PLAYA", "LIBRO", "MESA", "SILLA", "VENTANA", "PUERTA",
	"CAMINO", "CIUDAD", "PUEBLO", "MONTE", "MONTAÑA", "RIO", "LAGO", "NUBE", "LLUVIA", "SOL",
	"LUNA", "ESTRELLA", "PLANETA", "JARDIN", "FLOR", "ROSA", "HOJA", "RAMA", "FRUTA", "MANZANA",
	"NARANJA", "LIMON", "BANANA", "UVA", "PERA", "FRESA", "CEREZA", "SANDIA", "MELON", "TOMATE",
	"PAPA", "CEBOLLA", "QUESO", "LECHE", "PAN", "HUEVO", "ARROZ", "SOPA", "CAFE", "AZUCAR",
	"CUCHARA", "TENEDOR", "CUCHILLO", "PLATO", "VASO", "BOTELLA", "COCINA", "HORNO", "CAMA", "ALMOHADA",
	"ESPEJO", "RELOJ", "LAMPARA", "CUADRO", "ALFOMBRA", "ESCUELA", "MAESTRO", "ALUMNO", "LAPIZ", "PAPEL",
	"CUADERNO", "PIZARRA", "MOCHILA", "AMIGO", "FAMILIA", "MADRE", "PADRE", "HERMANO", "ABUELO", "PRIMO",
	"CABALLO", "VACA", "OVEJA", "CERDO", "CONEJO", "RATON", "TIGRE", "LEON", "MONO", "OSO",
	"LOBO", "ZORRO", "PAJARO", "AGUILA", "PALOMA", "PATO", "PEZ", "BALLENA", "DELFIN", "TIBURON",
	"TORTUGA", "SERPIENTE", "ARAÑA", "HORMIGA", "ABEJA", "MARIPOSA", "CAMISA", "ZAPATO", "SOMBRERO", "VESTIDO",
	"GUANTE", "BUFANDA", "CHAQUETA", "BOLSILLO", "BOTON", "CARRO", "AVION", "BARCO", "TREN", "BICICLETA",
	"CALLE", "PUENTE", "TORRE", "CASTILLO", "IGLESIA", "MERCADO", "TIENDA", "BANCO", "PARQUE", "ESTADIO",
	"MUSICA", "GUITARRA", "PIANO", "TAMBOR", "CANCION", "BAILE", "FIESTA", "REGALO", "GLOBO", "PASTEL",
	"VERANO", "INVIERNO", "OTOÑO", "PRIMAVERA", "MAÑANA", "TARDE", "NOCHE", "SEMANA", "DOMINGO", "SABADO",
	"CORAZON", "CABEZA", "MANO", "PIERNA", "BRAZO", "NARIZ", "BOCA", "OREJA", "DIENTE", "CABELLO",
	"DOCTOR", "BOMBERO", "PIRATA", "PRINCESA", "REINA", "DRAGON", "TESORO", "MAPA", "ISLA", "SELVA",
	"DESIERTO", "VOLCAN", "OCEANO", "PLANTA", "SEMILLA", "TIERRA", "FUEGO", "VIENTO", "HIELO", "NIEVE",
	"PELOTA", "JUGUETE", "MUÑECA", "COMETA", "CUENTO", "PELICULA", "CAMARA", "TELEFONO", "LLAVE", "CANDADO",
	"VENTILADOR", "ESCALERA", "TIJERAS", "MARTILLO", "CLAVO", "PINTURA", "COLOR", "AMARILLO", "MORADO", "VERDE"]

var words := PackedStringArray()   # English validation list, sorted
var spanish := false
var queue: Array = []
var target: String = ""
var letters: Array = []            # scrambled letters for this word
var index: int = 0                 # words played this round
var score: int = 0
var hints: int = 0                 # hints used on the current word

func load_words() -> void:
	if not words.is_empty():
		return
	var f := FileAccess.open(WORDS_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_buffer(f.get_length())
	f.close()
	words = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8().split("\n", false)

func new_round(use_spanish: bool) -> void:
	spanish = use_spanish
	var pool: Array = (ES if spanish else EN).filter(func(w): return w.length() >= 4 and w.length() <= 8)
	pool.shuffle()
	queue = pool.slice(0, ROUND)
	index = 0
	score = 0
	_next()

func _next() -> void:
	target = queue[index]
	hints = 0
	letters = []
	for ch in target:
		letters.append(ch)
	# scramble until it isn't the answer itself
	for attempt in 20:
		letters.shuffle()
		if "".join(letters) != target:
			break

func is_over() -> bool:
	return index >= queue.size()

static func _sorted(w: String) -> String:
	var a: Array = []
	for ch in w:
		a.append(ch)
	a.sort()
	return "".join(a)

## Does `guess` use exactly these letters and form a valid word?
func accepts(guess: String) -> bool:
	guess = guess.to_upper()
	if guess == target:
		return true
	if _sorted(guess) != _sorted(target):
		return false
	if spanish:
		return ES.has(guess)
	var lower := guess.to_lower()
	var i := words.bsearch(lower)
	return i < words.size() and words[i] == lower

func points_for_current() -> int:
	return max(1, (target.length() * 10) >> hints)

## Scores the guess and advances. Returns true if it was right.
func submit(guess: String) -> bool:
	if not accepts(guess):
		return false
	score += points_for_current()
	index += 1
	if not is_over():
		_next()
	return true

func skip() -> void:
	index += 1
	if not is_over():
		_next()
