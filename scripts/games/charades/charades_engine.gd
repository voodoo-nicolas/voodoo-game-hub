extends RefCounted

## Charades (forehead style): the guesser holds the phone to their forehead,
## friends act out or describe the word, and each word is marked correct or
## passed until the round's time runs out. Word lists per category, English
## and Spanish; words are dealt from a shuffled bag so none repeats until the
## category has been used up. Pure logic, no Nodes -- the scene owns the clock.

const ROUND_SECONDS := 60

const CATEGORIES := ["Animals", "Actions", "Jobs", "Food", "Sports", "Things"]

const WORDS := {
	"Animals": ["Elephant", "Monkey", "Penguin", "Kangaroo", "Snake", "Giraffe", "Chicken", "Shark", "Frog", "Lion",
		"Horse", "Butterfly", "Crab", "Owl", "Gorilla", "Dog", "Cat", "Rabbit", "Dolphin", "Spider",
		"Duck", "Cow", "Bear", "Crocodile", "Bee", "Turtle", "Peacock", "Octopus", "Camel", "Squirrel",
		"Parrot", "Pig", "Bat", "Zebra", "Mosquito", "Flamingo"],
	"Actions": ["Swimming", "Sneezing", "Brushing teeth", "Dancing", "Juggling", "Climbing a ladder", "Taking a selfie", "Skipping rope", "Fishing", "Painting a wall",
		"Riding a bike", "Crying", "Sleeping", "Typing", "Surfing", "Boxing", "Cooking", "Driving", "Knitting", "Laughing",
		"Washing dishes", "Changing a diaper", "Playing guitar", "Rowing a boat", "Bowling", "Ice skating", "Walking a dog", "Getting dressed", "Proposing", "Flying a kite",
		"Hiccuping", "Doing yoga", "Shoveling snow", "Blowing bubbles", "Milking a cow", "Hammering a nail"],
	"Jobs": ["Doctor", "Firefighter", "Teacher", "Chef", "Pilot", "Police officer", "Dentist", "Waiter", "Farmer", "Hairdresser",
		"Astronaut", "Photographer", "Mechanic", "Lifeguard", "Magician", "Plumber", "Singer", "Painter", "Taxi driver", "Builder",
		"Nurse", "Judge", "Scientist", "Clown", "Fisherman", "Soldier", "Postman", "Baker", "DJ", "Referee",
		"Mime", "Personal trainer", "Pirate", "Cowboy", "Gardener", "Barber"],
	"Food": ["Pizza", "Spaghetti", "Ice cream", "Banana", "Popcorn", "Hamburger", "Taco", "Watermelon", "Sushi", "Pancakes",
		"Hot dog", "Lemon", "Chocolate", "Corn on the cob", "Soup", "Popsicle", "Coconut", "Cotton candy", "French fries", "Cake",
		"Egg", "Steak", "Chewing gum", "Pineapple", "Sandwich", "Cereal", "Lollipop", "Onion", "Burrito", "Grapes",
		"Pretzel", "Cheese", "Carrot", "Donut", "Chili pepper", "Coffee"],
	"Sports": ["Soccer", "Basketball", "Tennis", "Golf", "Boxing", "Baseball", "Swimming", "Skiing", "Surfing", "Volleyball",
		"Karate", "Bowling", "Archery", "Gymnastics", "Fencing", "Cycling", "Hockey", "Rugby", "Skateboarding", "Wrestling",
		"Ping pong", "Rowing", "Diving", "Horse riding", "Weightlifting", "Climbing", "Darts", "Snowboarding", "Running", "Badminton",
		"Sumo", "Hula hoop", "Kayaking", "Pole vault", "Jump rope", "Frisbee"],
	"Things": ["Umbrella", "Toothbrush", "Guitar", "Camera", "Ladder", "Scissors", "Balloon", "Telephone", "Hammer", "Kite",
		"Microwave", "Bicycle", "Clock", "Glasses", "Candle", "Piano", "Vacuum cleaner", "Backpack", "Mirror", "Remote control",
		"Rocket", "Sunglasses", "Washing machine", "Pillow", "Tent", "Key", "Trumpet", "Lawn mower", "Fan", "Hair dryer",
		"Book", "Shopping cart", "Lightbulb", "Elevator", "Skateboard", "Toilet paper"],
}

const WORDS_ES := {
	"Animals": ["Elefante", "Mono", "Pingüino", "Canguro", "Serpiente", "Jirafa", "Gallina", "Tiburón", "Rana", "León",
		"Caballo", "Mariposa", "Cangrejo", "Búho", "Gorila", "Perro", "Gato", "Conejo", "Delfín", "Araña",
		"Pato", "Vaca", "Oso", "Cocodrilo", "Abeja", "Tortuga", "Pavo real", "Pulpo", "Camello", "Ardilla",
		"Loro", "Cerdo", "Murciélago", "Cebra", "Mosquito", "Flamenco"],
	"Actions": ["Nadar", "Estornudar", "Cepillarse los dientes", "Bailar", "Hacer malabares", "Subir una escalera", "Sacarse una selfie", "Saltar la cuerda", "Pescar", "Pintar una pared",
		"Andar en bicicleta", "Llorar", "Dormir", "Escribir en la computadora", "Surfear", "Boxear", "Cocinar", "Manejar", "Tejer", "Reírse",
		"Lavar los platos", "Cambiar un pañal", "Tocar la guitarra", "Remar", "Jugar bolos", "Patinar sobre hielo", "Pasear al perro", "Vestirse", "Pedir matrimonio", "Volar un papalote",
		"Tener hipo", "Hacer yoga", "Palear nieve", "Hacer burbujas", "Ordeñar una vaca", "Clavar un clavo"],
	"Jobs": ["Médico", "Bombero", "Profesor", "Cocinero", "Piloto", "Policía", "Dentista", "Mesero", "Granjero", "Peluquero",
		"Astronauta", "Fotógrafo", "Mecánico", "Salvavidas", "Mago", "Plomero", "Cantante", "Pintor", "Taxista", "Albañil",
		"Enfermero", "Juez", "Científico", "Payaso", "Pescador", "Soldado", "Cartero", "Panadero", "DJ", "Árbitro",
		"Mimo", "Entrenador personal", "Pirata", "Vaquero", "Jardinero", "Barbero"],
	"Food": ["Pizza", "Espaguetis", "Helado", "Plátano", "Palomitas", "Hamburguesa", "Taco", "Sandía", "Sushi", "Panqueques",
		"Hot dog", "Limón", "Chocolate", "Elote", "Sopa", "Paleta helada", "Coco", "Algodón de azúcar", "Papas fritas", "Pastel",
		"Huevo", "Bistec", "Chicle", "Piña", "Sándwich", "Cereal", "Chupetín", "Cebolla", "Burrito", "Uvas",
		"Pretzel", "Queso", "Zanahoria", "Dona", "Chile", "Café"],
	"Sports": ["Fútbol", "Básquetbol", "Tenis", "Golf", "Boxeo", "Béisbol", "Natación", "Esquí", "Surf", "Vóleibol",
		"Karate", "Bolos", "Tiro con arco", "Gimnasia", "Esgrima", "Ciclismo", "Hockey", "Rugby", "Patineta", "Lucha libre",
		"Ping pong", "Remo", "Clavados", "Equitación", "Pesas", "Escalada", "Dardos", "Snowboard", "Correr", "Bádminton",
		"Sumo", "Hula hula", "Kayak", "Salto con garrocha", "Saltar la cuerda", "Frisbee"],
	"Things": ["Paraguas", "Cepillo de dientes", "Guitarra", "Cámara", "Escalera", "Tijeras", "Globo", "Teléfono", "Martillo", "Papalote",
		"Microondas", "Bicicleta", "Reloj", "Lentes", "Vela", "Piano", "Aspiradora", "Mochila", "Espejo", "Control remoto",
		"Cohete", "Lentes de sol", "Lavadora", "Almohada", "Carpa", "Llave", "Trompeta", "Cortacésped", "Ventilador", "Secador de pelo",
		"Libro", "Carrito del súper", "Foco", "Ascensor", "Patineta", "Papel higiénico"],
}

var category := "Animals"
var spanish := false
var bags := {}            # category -> remaining words (shuffled)
var current := ""
var results: Array = []   # [[word, correct], ...] for this round

func start_round(p_category: String, p_spanish: bool) -> void:
	if p_spanish != spanish:
		bags = {}
	category = p_category
	spanish = p_spanish
	results = []
	next_word()

func next_word() -> String:
	var bag: Array = bags.get(category, [])
	if bag.is_empty():
		bag = ((WORDS_ES if spanish else WORDS)[category] as Array).duplicate()
		bag.shuffle()
		bags[category] = bag
	current = bag.pop_back()
	return current

## Marks the current word and deals the next one.
func mark(correct: bool) -> void:
	results.append([current, correct])
	next_word()

func score() -> int:
	var n := 0
	for r in results:
		if r[1]:
			n += 1
	return n
