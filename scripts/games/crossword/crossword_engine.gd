extends RefCounted

## Crossword: a fresh free-form puzzle each time, built by interlocking words
## from a clue list (English or Spanish). Pure logic, no Nodes.

const MAX_SIZE := 13
const TARGET_WORDS := 12

const CLUES_EN := [
	"APPLE|Red or green fruit that keeps the doctor away", "PIANO|Instrument with black and white keys",
	"OCEAN|Huge body of salt water", "TIGER|Striped big cat", "BREAD|Baked loaf used for sandwiches",
	"CLOCK|It tells the time", "RIVER|Water flowing to the sea", "CHAIR|You sit on it",
	"EARTH|Our planet", "MOON|It lights the night sky", "STAR|Twinkles at night", "SNOW|Frozen flakes in winter",
	"LEMON|Sour yellow fruit", "HONEY|Sweet food made by bees", "EAGLE|Bird on many national emblems",
	"CAMEL|Desert animal with humps", "ZEBRA|Horse-like animal with stripes", "OTTER|Playful river swimmer",
	"TRAIN|It runs on rails", "PLANE|It flies passengers", "BOAT|Small vessel on water", "BRIDGE|Crosses a river",
	"CASTLE|Home of a medieval king", "DRAGON|Fire-breathing beast of legend", "WIZARD|Magic-user with a wand",
	"GUITAR|Six-stringed instrument", "DRUM|Instrument you hit with sticks", "VIOLIN|Played with a bow under the chin",
	"SUMMER|Warmest season", "WINTER|Coldest season", "SPRING|Season of blossoms", "AUTUMN|Season of falling leaves",
	"MONDAY|First day of the working week", "FRIDAY|Last working day of the week", "MORNING|Start of the day",
	"NIGHT|Time for sleep", "DREAM|Story in your sleep", "SMILE|Happy face", "LAUGH|Sound of a good joke",
	"TEACHER|Works in a classroom", "DOCTOR|Treats the sick", "PILOT|Flies an aircraft", "CHEF|Cooks in a restaurant",
	"FARMER|Grows crops", "ARTIST|Paints pictures", "NURSE|Helps in a hospital", "BAKER|Makes bread and cakes",
	"COFFEE|Morning drink from beans", "TEA|Drink made from leaves", "MILK|White drink from cows", "WATER|H2O",
	"PIZZA|Italian dish with a cheesy topping", "PASTA|Spaghetti, for example", "SALAD|Bowl of greens", "SOUP|Served in a bowl, hot",
	"CHEESE|Made from milk, loved by mice", "EGG|Laid by a hen", "RICE|Grain eaten all over Asia", "SUGAR|Sweetener",
	"GARDEN|Where flowers grow at home", "FOREST|Many trees together", "DESERT|Dry, sandy region", "ISLAND|Land surrounded by water",
	"VOLCANO|Mountain that erupts", "CANYON|Deep valley carved by a river", "BEACH|Sandy shore", "VALLEY|Low land between hills",
	"RAINBOW|Colourful arc after rain", "THUNDER|Boom after lightning", "CLOUD|White puff in the sky", "WIND|Moving air",
	"HEART|It pumps blood", "BRAIN|You think with it", "HAND|It has five fingers", "EYE|You see with it", "NOSE|You smell with it",
	"BOOK|You read it", "PENCIL|Writing tool with lead", "PAPER|Sheet you write on", "SCHOOL|Place of learning", "LIBRARY|Place to borrow books",
	"KING|Ruler of a kingdom", "QUEEN|Wife of a king", "PRINCE|Son of a king", "CROWN|Royal headwear",
	"PIRATE|Sea robber", "TREASURE|Buried chest of gold", "MAP|It shows the way", "ANCHOR|Keeps a ship in place",
	"ROBOT|Machine that acts like a person", "ROCKET|Launches into space", "PLANET|Mars, for one", "COMET|Icy visitor with a tail",
	"SOCCER|Sport with a round ball and goals", "TENNIS|Sport with rackets and a net", "CHESS|Game with kings and pawns", "GOLF|Sport with clubs and holes",
	"TOMATO|Red fruit used as a vegetable", "CARROT|Orange root rabbits love", "ONION|It makes you cry when cut", "POTATO|Used for fries",
	"ORANGE|Colour and a fruit", "PURPLE|Red plus blue", "GREEN|Colour of grass", "YELLOW|Colour of a banana",
	"MIRROR|Shows your reflection", "WINDOW|Glass in a wall", "DOOR|You open it to go in", "KEY|Opens a lock",
	"SPIDER|Eight-legged web spinner", "ANT|Tiny hard-working insect", "BEE|Buzzing honey maker", "SNAKE|Legless reptile",
	"TURTLE|Reptile with a shell", "RABBIT|Long-eared hopper", "MONKEY|Banana-loving climber", "PENGUIN|Bird that can't fly but swims",
	"UMBRELLA|Keeps you dry in rain", "CANDLE|Wax light", "BALLOON|Fill it with air or helium", "GIFT|Present",
]

const CLUES_ES := [
	"MANZANA|Fruta roja o verde", "PIANO|Instrumento de teclas blancas y negras", "OCEANO|Gran masa de agua salada",
	"TIGRE|Felino con rayas", "PAN|Se hornea y se usa para sándwiches", "RELOJ|Te dice la hora", "RIO|Agua que corre hacia el mar",
	"SILLA|Mueble para sentarse", "TIERRA|Nuestro planeta", "LUNA|Ilumina la noche", "ESTRELLA|Brilla en el cielo nocturno",
	"NIEVE|Copos helados del invierno", "LIMON|Fruta amarilla y ácida", "MIEL|Dulce que hacen las abejas", "AGUILA|Ave rapaz de gran vista",
	"CAMELLO|Animal del desierto con jorobas", "CEBRA|Parece un caballo con rayas", "TREN|Viaja sobre rieles", "AVION|Vuela con pasajeros",
	"BARCO|Navega por el mar", "PUENTE|Cruza sobre un río", "CASTILLO|Casa de un rey medieval", "DRAGON|Bestia que echa fuego",
	"MAGO|Hace trucos con varita", "GUITARRA|Instrumento de seis cuerdas", "TAMBOR|Se toca con palillos", "VIOLIN|Se toca con arco",
	"VERANO|Estación más calurosa", "INVIERNO|Estación más fría", "PRIMAVERA|Estación de las flores", "OTOÑO|Estación en que caen las hojas",
	"LUNES|Primer día de la semana laboral", "VIERNES|Último día laboral de la semana", "MAÑANA|Parte del día antes del mediodía",
	"NOCHE|Hora de dormir", "SUEÑO|Historia mientras duermes", "SONRISA|Cara feliz", "MAESTRO|Enseña en la escuela",
	"MEDICO|Cura a los enfermos", "PILOTO|Maneja un avión", "COCINERO|Prepara la comida", "GRANJERO|Cultiva la tierra",
	"PINTOR|Hace cuadros", "PANADERO|Hace pan", "CAFE|Bebida de la mañana", "LECHE|Bebida blanca de la vaca",
	"AGUA|Se bebe cuando hay sed", "SOPA|Se sirve caliente en un plato hondo", "QUESO|Se hace con leche", "HUEVO|Lo pone la gallina",
	"ARROZ|Grano muy consumido en Asia", "AZUCAR|Endulza el café", "JARDIN|Donde crecen las flores de la casa",
	"BOSQUE|Muchos árboles juntos", "DESIERTO|Región seca y arenosa", "ISLA|Tierra rodeada de agua", "VOLCAN|Montaña que hace erupción",
	"PLAYA|Orilla de arena", "VALLE|Tierra baja entre montañas", "ARCOIRIS|Arco de colores tras la lluvia", "TRUENO|Estruendo tras el rayo",
	"NUBE|Algodón blanco en el cielo", "VIENTO|Aire en movimiento", "CORAZON|Bombea la sangre", "CEREBRO|Con él piensas",
	"MANO|Tiene cinco dedos", "OJO|Con él ves", "NARIZ|Con ella hueles", "LIBRO|Se lee", "LAPIZ|Sirve para escribir y borrar",
	"PAPEL|Hoja para escribir", "ESCUELA|Lugar para aprender", "REY|Gobierna un reino", "REINA|Esposa del rey", "CORONA|La lleva el rey en la cabeza",
	"PIRATA|Ladrón de los mares", "TESORO|Cofre enterrado", "MAPA|Muestra el camino", "ANCLA|Sujeta el barco",
	"ROBOT|Máquina que actúa como persona", "COHETE|Viaja al espacio", "PLANETA|Marte es uno", "COMETA|Juguete que vuela con el viento",
	"FUTBOL|Deporte con arco y pelota", "TENIS|Deporte con raqueta y red", "AJEDREZ|Juego de reyes y peones", "TOMATE|Fruto rojo de las ensaladas",
	"ZANAHORIA|Raíz naranja que come el conejo", "CEBOLLA|Te hace llorar al cortarla", "PAPA|Con ella se hacen papas fritas",
	"NARANJA|Color y fruta", "MORADO|Rojo más azul", "VERDE|Color del pasto", "AMARILLO|Color del plátano",
	"ESPEJO|Muestra tu reflejo", "VENTANA|Vidrio en la pared", "PUERTA|Se abre para entrar", "LLAVE|Abre la cerradura",
	"ARAÑA|Teje su tela", "HORMIGA|Insecto pequeño y trabajador", "ABEJA|Insecto que hace miel", "SERPIENTE|Reptil sin patas",
	"TORTUGA|Reptil con caparazón", "CONEJO|Salta y tiene orejas largas", "MONO|Le encantan las bananas", "PINGUINO|Ave que nada pero no vuela",
	"PARAGUAS|Te protege de la lluvia", "VELA|Luz de cera", "GLOBO|Se infla con aire", "REGALO|Presente de cumpleaños",
]

## Placed entries: {answer, clue, pos: Vector2i, across: bool, number}
var entries: Array = []
var w: int = 0
var h: int = 0
var solution: Dictionary = {}   # Vector2i -> letter
var letters: Dictionary = {}    # player's letters
var numbers: Dictionary = {}    # Vector2i -> clue number

func new_puzzle(spanish: bool, rng_seed: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var pool: Array = (CLUES_ES if spanish else CLUES_EN).duplicate()
	var best: Array = []
	for attempt in 12:
		_shuffle(pool, rng)
		var placed := _build(pool.slice(0, 26), rng)
		if placed.size() > best.size():
			best = placed
		if best.size() >= TARGET_WORDS:
			break
	_finalize(best)

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## Greedy build on an unbounded grid, keeping the result within MAX_SIZE.
func _build(pool: Array, rng: RandomNumberGenerator) -> Array:
	var items: Array = []
	for line in pool:
		var parts: PackedStringArray = line.split("|")
		items.append({"answer": parts[0], "clue": parts[1]})
	items.sort_custom(func(a, b): return a.answer.length() > b.answer.length())
	var grid := {}
	var placed: Array = []
	var first: Dictionary = items[0]
	_put(grid, first.answer, Vector2i(0, 0), true)
	placed.append({"answer": first.answer, "clue": first.clue, "pos": Vector2i(0, 0), "across": true})
	for it in items.slice(1):
		if placed.size() >= TARGET_WORDS:
			break
		var options: Array = []
		var word: String = it.answer
		for p in placed:
			for i in p.answer.length():
				var cell: Vector2i = p.pos + (Vector2i(i, 0) if p.across else Vector2i(0, i))
				for j in word.length():
					if word[j] != p.answer[i]:
						continue
					var across: bool = not p.across
					var start: Vector2i = cell - (Vector2i(j, 0) if across else Vector2i(0, j))
					var crossings := _fits(grid, word, start, across)
					if crossings > 0 and _within(grid, word, start, across):
						options.append([crossings, start, across])
		if options.is_empty():
			continue
		_shuffle(options, rng)
		options.sort_custom(func(a, b): return a[0] > b[0])
		var o: Array = options[0]
		_put(grid, word, o[1], o[2])
		placed.append({"answer": word, "clue": it.clue, "pos": o[1], "across": o[2]})
	return placed

static func _step(across: bool) -> Vector2i:
	return Vector2i(1, 0) if across else Vector2i(0, 1)

static func _put(grid: Dictionary, word: String, start: Vector2i, across: bool) -> void:
	for k in word.length():
		grid[start + _step(across) * k] = word[k]

## Number of crossings if the word fits there legally, else -1.
static func _fits(grid: Dictionary, word: String, start: Vector2i, across: bool) -> int:
	var d := _step(across)
	var side := Vector2i(0, 1) if across else Vector2i(1, 0)
	if grid.has(start - d) or grid.has(start + d * word.length()):
		return -1
	var crossings := 0
	for k in word.length():
		var c := start + d * k
		if grid.has(c):
			if grid[c] != word[k]:
				return -1
			crossings += 1
		elif grid.has(c + side) or grid.has(c - side):
			return -1   # would touch a parallel word
	if crossings == word.length():
		return -1
	return crossings

static func _within(grid: Dictionary, word: String, start: Vector2i, across: bool) -> bool:
	var lo := start
	var hi := start + _step(across) * (word.length() - 1)
	for c in grid:
		lo = Vector2i(min(lo.x, c.x), min(lo.y, c.y))
		hi = Vector2i(max(hi.x, c.x), max(hi.y, c.y))
	return hi.x - lo.x < MAX_SIZE and hi.y - lo.y < MAX_SIZE

func _finalize(placed: Array) -> void:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for p in placed:
		var e: Vector2i = p.pos + _step(p.across) * (p.answer.length() - 1)
		lo = Vector2i(min(lo.x, p.pos.x), min(lo.y, p.pos.y))
		hi = Vector2i(max(hi.x, e.x), max(hi.y, e.y))
	w = hi.x - lo.x + 1
	h = hi.y - lo.y + 1
	solution.clear()
	letters.clear()
	numbers.clear()
	entries.clear()
	for p in placed:
		p.pos -= lo
		for k in p.answer.length():
			solution[p.pos + _step(p.across) * k] = p.answer[k]
	# number clue starts in reading order
	var starts: Array = []
	for p in placed:
		if not starts.has(p.pos):
			starts.append(p.pos)
	starts.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for i in starts.size():
		numbers[starts[i]] = i + 1
	for p in placed:
		p["number"] = numbers[p.pos]
		entries.append(p)
	entries.sort_custom(func(a, b): return (0 if a.across else 1000) + a.number < (0 if b.across else 1000) + b.number)

func is_cell(c: Vector2i) -> bool:
	return solution.has(c)

## The entry through `c` in the given direction, or null.
func entry_at(c: Vector2i, across: bool) -> Variant:
	for e in entries:
		if e.across != across:
			continue
		var off: Vector2i = c - e.pos
		var k: int = off.x if across else off.y
		var other: int = off.y if across else off.x
		if other == 0 and k >= 0 and k < e.answer.length():
			return e
	return null

func is_solved() -> bool:
	for c in solution:
		if letters.get(c, "") != solution[c]:
			return false
	return true

func wrong_cells() -> Array:
	var out: Array = []
	for c in letters:
		if letters[c] != "" and letters[c] != solution[c]:
			out.append(c)
	return out
