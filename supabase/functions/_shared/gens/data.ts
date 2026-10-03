// deno-lint-ignore-file
// GENERATED VERBATIM from docs/voodoo-iq-prototype.html (the reference implementation).
// Do not edit by hand: change the prototype, then re-extract, so EN/ES text stays 1:1.

// Matrix attribute sizes
export const MX_SHAPES = ['circle', 'square', 'triangle', 'diamond', 'hexagon'];
export const MX_N = { shape: 5, count: 3, fill: 3, size: 3 };

// Linguistic word banks
export const CATS = {
  mammals: { g: 'animal', en: ['dog', 'horse', 'lion', 'whale', 'bat', 'tiger', 'rabbit', 'bear'], es: ['perro', 'caballo', 'león', 'ballena', 'murciélago', 'tigre', 'conejo', 'oso'] },
  birds: { g: 'animal', en: ['eagle', 'owl', 'parrot', 'penguin', 'crow', 'swan', 'ostrich', 'sparrow'], es: ['águila', 'búho', 'loro', 'pingüino', 'cuervo', 'cisne', 'avestruz', 'gorrión'] },
  fish: { g: 'animal', en: ['shark', 'salmon', 'tuna', 'trout', 'cod', 'sardine', 'eel', 'carp'], es: ['tiburón', 'salmón', 'atún', 'trucha', 'bacalao', 'sardina', 'anguila', 'carpa'] },
  insects: { g: 'animal', en: ['ant', 'bee', 'beetle', 'butterfly', 'fly', 'mosquito', 'wasp', 'cricket'], es: ['hormiga', 'abeja', 'escarabajo', 'mariposa', 'mosca', 'mosquito', 'avispa', 'grillo'] },
  reptiles: { g: 'animal', en: ['snake', 'lizard', 'turtle', 'crocodile', 'iguana', 'chameleon', 'cobra', 'alligator'], es: ['serpiente', 'lagarto', 'tortuga', 'cocodrilo', 'iguana', 'camaleón', 'cobra', 'caimán'] },
  fruits: { g: 'food', en: ['apple', 'pear', 'mango', 'grape', 'peach', 'cherry', 'banana', 'plum'], es: ['manzana', 'pera', 'mango', 'uva', 'durazno', 'cereza', 'banana', 'ciruela'] },
  vegetables: { g: 'food', en: ['carrot', 'onion', 'lettuce', 'potato', 'spinach', 'celery', 'cabbage', 'beet'], es: ['zanahoria', 'cebolla', 'lechuga', 'papa', 'espinaca', 'apio', 'repollo', 'remolacha'] },
  tools: { g: 'object', en: ['hammer', 'saw', 'wrench', 'drill', 'chisel', 'pliers', 'screwdriver', 'level'], es: ['martillo', 'sierra', 'llave inglesa', 'taladro', 'cincel', 'pinza', 'destornillador', 'nivel'] },
  kitchen: { g: 'object', en: ['spoon', 'fork', 'frying pan', 'ladle', 'whisk', 'grater', 'kettle', 'colander'], es: ['cuchara', 'tenedor', 'sartén', 'cucharón', 'batidor', 'rallador', 'pava', 'colador'] },
  instruments: { g: 'object', en: ['violin', 'drum', 'flute', 'trumpet', 'piano', 'harp', 'guitar', 'cello'], es: ['violín', 'tambor', 'flauta', 'trompeta', 'piano', 'arpa', 'guitarra', 'violonchelo'] },
  metals: { g: 'matter', en: ['iron', 'copper', 'silver', 'gold', 'zinc', 'tin', 'lead', 'nickel'], es: ['hierro', 'cobre', 'plata', 'oro', 'zinc', 'estaño', 'plomo', 'níquel'] },
  gems: { g: 'matter', en: ['ruby', 'emerald', 'sapphire', 'diamond', 'topaz', 'opal', 'amethyst', 'jade'], es: ['rubí', 'esmeralda', 'zafiro', 'diamante', 'topacio', 'ópalo', 'amatista', 'jade'] },
  emotions: { g: 'abstract', en: ['joy', 'anger', 'fear', 'grief', 'pride', 'envy', 'shame', 'awe'], es: ['alegría', 'ira', 'miedo', 'pena', 'orgullo', 'envidia', 'vergüenza', 'asombro'] },
  virtues: { g: 'abstract', en: ['honesty', 'courage', 'patience', 'kindness', 'humility', 'loyalty', 'justice', 'prudence'], es: ['honestidad', 'valentía', 'paciencia', 'bondad', 'humildad', 'lealtad', 'justicia', 'prudencia'] },
  time: { g: 'measure', en: ['second', 'minute', 'hour', 'day', 'week', 'month', 'year', 'decade'], es: ['segundo', 'minuto', 'hora', 'día', 'semana', 'mes', 'año', 'década'] },
  length: { g: 'measure', en: ['meter', 'inch', 'mile', 'yard', 'foot', 'kilometer', 'centimeter', 'league'], es: ['metro', 'pulgada', 'milla', 'yarda', 'pie', 'kilómetro', 'centímetro', 'legua'] },
  organs: { g: 'body', en: ['heart', 'liver', 'lung', 'kidney', 'brain', 'stomach', 'spleen', 'pancreas'], es: ['corazón', 'hígado', 'pulmón', 'riñón', 'cerebro', 'estómago', 'bazo', 'páncreas'] },
  bones: { g: 'body', en: ['femur', 'skull', 'rib', 'spine', 'pelvis', 'tibia', 'jaw', 'collarbone'], es: ['fémur', 'cráneo', 'costilla', 'columna', 'pelvis', 'tibia', 'mandíbula', 'clavícula'] },
  weather: { g: 'nature', en: ['rain', 'snow', 'hail', 'fog', 'thunder', 'frost', 'drizzle', 'wind'], es: ['lluvia', 'nieve', 'granizo', 'niebla', 'trueno', 'escarcha', 'llovizna', 'viento'] },
  landforms: { g: 'nature', en: ['mountain', 'valley', 'canyon', 'plateau', 'island', 'desert', 'glacier', 'cliff'], es: ['montaña', 'valle', 'cañón', 'meseta', 'isla', 'desierto', 'glaciar', 'acantilado'] }
};
export const CLOSE = [['fruits', 'vegetables'], ['metals', 'gems'], ['emotions', 'virtues'], ['time', 'length'], ['organs', 'bones'], ['tools', 'kitchen'], ['weather', 'landforms'], ['mammals', 'birds'], ['fish', 'reptiles']];
export const TRICKS = [
  { en: [['shark', 'salmon', 'tuna', 'trout'], 'whale'], es: [['tiburón', 'salmón', 'atún', 'trucha'], 'ballena'] },
  { en: [['eagle', 'owl', 'crow', 'sparrow'], 'bat'], es: [['águila', 'búho', 'cuervo', 'gorrión'], 'murciélago'] },
  { en: [['ant', 'bee', 'fly', 'beetle'], 'spider'], es: [['hormiga', 'abeja', 'mosca', 'escarabajo'], 'araña'] },
  { en: [['iron', 'copper', 'zinc', 'tin'], 'bronze'], es: [['hierro', 'cobre', 'zinc', 'estaño'], 'bronce'] },
  { en: [['snake', 'lizard', 'crocodile', 'turtle'], 'salamander'], es: [['serpiente', 'lagarto', 'cocodrilo', 'tortuga'], 'salamandra'] },
  { en: [['square', 'rectangle', 'rhombus', 'trapezoid'], 'triangle'], es: [['cuadrado', 'rectángulo', 'rombo', 'trapecio'], 'triángulo'] },
  { en: [['dolphin', 'whale', 'seal', 'otter'], 'shark'], es: [['delfín', 'ballena', 'foca', 'nutria'], 'tiburón'] },
  { en: [['Mercury', 'Venus', 'Mars', 'Jupiter'], 'Moon'], es: [['Mercurio', 'Venus', 'Marte', 'Júpiter'], 'Luna'] },
  { en: [['oak', 'pine', 'maple', 'birch'], 'bamboo'], es: [['roble', 'pino', 'arce', 'abedul'], 'bambú'] }
];

// Anagram lists (no common alternative anagram)
export const ANA = {
  en: { 4: ['bird', 'frog', 'milk', 'duck', 'king', 'jump', 'tree', 'fish'], 5: ['plant', 'river', 'smoke', 'flame', 'brush', 'chair', 'tiger', 'light'], 6: ['pocket', 'winter', 'jungle', 'basket', 'monkey', 'rabbit', 'button', 'bridge'], 7: ['blanket', 'kitchen', 'picture', 'kingdom', 'diamond', 'captain', 'thunder', 'harvest'], 8: ['mountain', 'elephant', 'treasure', 'sandwich', 'children', 'hospital', 'dinosaur', 'umbrella'], 9: ['chocolate', 'telescope', 'adventure', 'butterfly', 'pineapple', 'dangerous', 'knowledge', 'beautiful'] },
  es: { 4: ['flor', 'pozo', 'taza', 'hilo', 'dedo', 'nube', 'mono', 'buzo'], 5: ['perro', 'silla', 'nieve', 'libro', 'campo', 'fuego', 'queso', 'plaza'], 6: ['ciudad', 'camino', 'cabeza', 'bosque', 'puente', 'conejo', 'tomate', 'madera'], 7: ['ventana', 'ballena', 'cuchara', 'caballo', 'abogado', 'manzana', 'naranja', 'pescado'], 8: ['tormenta', 'sombrero', 'estrella', 'elefante', 'mariposa', 'escalera', 'aventura', 'invierno'], 9: ['cocodrilo', 'chocolate', 'mariquita', 'carretera', 'esqueleto', 'zanahoria', 'temporada'] }
};

// Analogies: [difficulty, en, es], answer is option 0 before shuffling
export const ANALOGIES = [
  [1, ['hot', 'cold', 'up', ['down', 'high', 'warm', 'sky']], ['caliente', 'frío', 'arriba', ['abajo', 'alto', 'tibio', 'cielo']]],
  [1, ['bird', 'nest', 'bee', ['hive', 'honey', 'flower', 'wing']], ['pájaro', 'nido', 'abeja', ['colmena', 'miel', 'flor', 'ala']]],
  [1, ['day', 'night', 'summer', ['winter', 'sun', 'heat', 'autumn']], ['día', 'noche', 'verano', ['invierno', 'sol', 'calor', 'otoño']]],
  [2, ['puppy', 'dog', 'kitten', ['cat', 'mouse', 'milk', 'fur']], ['cachorro', 'perro', 'gatito', ['gato', 'ratón', 'leche', 'pelo']]],
  [2, ['pen', 'write', 'knife', ['cut', 'fork', 'sharp', 'kitchen']], ['lapicera', 'escribir', 'cuchillo', ['cortar', 'tenedor', 'filoso', 'cocina']]],
  [2, ['fish', 'water', 'bird', ['air', 'feather', 'nest', 'song']], ['pez', 'agua', 'pájaro', ['aire', 'pluma', 'nido', 'canto']]],
  [3, ['doctor', 'hospital', 'teacher', ['school', 'student', 'book', 'lesson']], ['médico', 'hospital', 'maestro', ['escuela', 'alumno', 'libro', 'lección']]],
  [3, ['seed', 'tree', 'egg', ['bird', 'nest', 'shell', 'yolk']], ['semilla', 'árbol', 'huevo', ['pájaro', 'nido', 'cáscara', 'yema']]],
  [3, ['Monday', 'Wednesday', 'March', ['May', 'April', 'June', 'Friday']], ['lunes', 'miércoles', 'marzo', ['mayo', 'abril', 'junio', 'viernes']]],
  [4, ['author', 'book', 'composer', ['symphony', 'piano', 'orchestra', 'concert hall']], ['autor', 'libro', 'compositor', ['sinfonía', 'piano', 'orquesta', 'teatro']]],
  [4, ['drought', 'water', 'famine', ['food', 'hunger', 'desert', 'poverty']], ['sequía', 'agua', 'hambruna', ['comida', 'hambre', 'desierto', 'pobreza']]],
  [4, ['word', 'sentence', 'brick', ['wall', 'clay', 'mortar', 'factory']], ['palabra', 'oración', 'ladrillo', ['pared', 'arcilla', 'cemento', 'fábrica']]],
  [5, ['cub', 'bear', 'tadpole', ['frog', 'fish', 'pond', 'egg']], ['osezno', 'oso', 'renacuajo', ['rana', 'pez', 'charco', 'huevo']]],
  [5, ['pilot', 'cockpit', 'surgeon', ['operating room', 'scalpel', 'patient', 'hospital']], ['piloto', 'cabina', 'cirujano', ['quirófano', 'bisturí', 'paciente', 'hospital']]],
  [5, ['oasis', 'desert', 'island', ['sea', 'palm tree', 'sand', 'beach']], ['oasis', 'desierto', 'isla', ['mar', 'palmera', 'arena', 'playa']]],
  [5, ['symptom', 'disease', 'smoke', ['fire', 'chimney', 'ash', 'cloud']], ['síntoma', 'enfermedad', 'humo', ['fuego', 'chimenea', 'ceniza', 'nube']]],
  [6, ['map', 'territory', 'sheet music', ['music', 'paper', 'conductor', 'notes']], ['mapa', 'territorio', 'partitura', ['música', 'papel', 'director', 'notas']]],
  [6, ['optimist', 'hope', 'skeptic', ['doubt', 'belief', 'truth', 'fear']], ['optimista', 'esperanza', 'escéptico', ['duda', 'creencia', 'verdad', 'miedo']]],
  [6, ['sculptor', 'marble', 'potter', ['clay', 'vase', 'wheel', 'kiln']], ['escultor', 'mármol', 'alfarero', ['arcilla', 'jarrón', 'torno', 'horno']]],
  [6, ['carnivore', 'meat', 'frugivore', ['fruit', 'plants', 'insects', 'seeds']], ['carnívoro', 'carne', 'frugívoro', ['fruta', 'plantas', 'insectos', 'semillas']]],
  [7, ['odometer', 'distance', 'barometer', ['pressure', 'weather', 'altitude', 'temperature']], ['odómetro', 'distancia', 'barómetro', ['presión', 'clima', 'altitud', 'temperatura']]],
  [7, ['prologue', 'epilogue', 'overture', ['finale', 'opera', 'prelude', 'symphony']], ['prólogo', 'epílogo', 'obertura', ['final', 'ópera', 'preludio', 'sinfonía']]],
  [7, ['vaccine', 'disease', 'firewall', ['intrusion', 'computer', 'fire', 'password']], ['vacuna', 'enfermedad', 'cortafuegos', ['intrusión', 'computadora', 'fuego', 'contraseña']]],
  [7, ['insomnia', 'sleep', 'amnesia', ['memory', 'forgetting', 'brain', 'past']], ['insomnio', 'sueño', 'amnesia', ['memoria', 'olvido', 'cerebro', 'pasado']]],
  [8, ['verbose', 'words', 'spendthrift', ['spending', 'luxury', 'gold', 'debt']], ['verborrágico', 'palabras', 'derrochador', ['gastos', 'lujo', 'oro', 'deuda']]],
  [8, ['cartographer', 'maps', 'lexicographer', ['dictionaries', 'letters', 'languages', 'novels']], ['cartógrafo', 'mapas', 'lexicógrafo', ['diccionarios', 'letras', 'idiomas', 'novelas']]],
  [8, ['hypothesis', 'experiment', 'claim', ['evidence', 'opinion', 'debate', 'lie']], ['hipótesis', 'experimento', 'afirmación', ['evidencia', 'opinión', 'debate', 'mentira']]],
  [8, ['xenophobe', 'foreigners', 'claustrophobe', ['enclosed spaces', 'heights', 'crowds', 'darkness']], ['xenófobo', 'extranjeros', 'claustrofóbico', ['lugares cerrados', 'alturas', 'multitudes', 'oscuridad']]],
  [9, ['numismatist', 'coins', 'philatelist', ['stamps', 'letters', 'records', 'maps']], ['numismático', 'monedas', 'filatelista', ['estampillas', 'cartas', 'discos', 'mapas']]],
  [9, ['loan', 'lender', 'rent', ['landlord', 'tenant', 'house', 'money']], ['préstamo', 'prestamista', 'alquiler', ['propietario', 'inquilino', 'casa', 'dinero']]],
  [10, ['sonnet', '14', 'haiku', ['3', '5', '7', '17']], ['soneto', '14', 'haiku', ['3', '5', '7', '17']]],
  [10, ['hydrogen', '1', 'carbon', ['6', '12', '4', '14']], ['hidrógeno', '1', 'carbono', ['6', '12', '4', '14']]]
];

// Facial-expression action units
export const EMO = {
  happy: { cr: .9, lc: 1, mo: .35, lt: .35 },
  sad: { bi: 1, bl: .35, lc: -.85, ul: -.35, lp: .2 },
  angry: { bl: 1, lt: .7, lp: .9, ul: .45, lc: -.25 },
  fear: { bi: 1, bo: .7, bl: .5, ul: 1, ls: 1, mo: .55 },
  surprise: { bi: 1, bo: 1, ul: 1, mo: 1 },
  disgust: { nw: 1, ur: 1, bl: .55, lc: -.45, lt: .35 }
};
export const EMO_KEYS = Object.keys(EMO);
export const EMO_CONFUSE = { happy: ['surprise', 'disgust', 'fear'], sad: ['fear', 'disgust', 'angry'], angry: ['disgust', 'sad', 'fear'], fear: ['surprise', 'sad', 'disgust'], surprise: ['fear', 'happy', 'angry'], disgust: ['angry', 'sad', 'fear'] };

// Syllogism terms
export const SY_TERMS = {
  en: ['dreamers', 'philosophers', 'ghosts', 'stars', 'shadows', 'travelers', 'poets', 'mortals', 'spirits', 'guardians', 'hermits', 'sages', 'prophets', 'wanderers'],
  es: [['soñador', 'soñadores', 'm'], ['filósofo', 'filósofos', 'm'], ['fantasma', 'fantasmas', 'm'], ['estrella', 'estrellas', 'f'], ['sombra', 'sombras', 'f'], ['viajero', 'viajeros', 'm'], ['poeta', 'poetas', 'm'], ['mortal', 'mortales', 'm'], ['espíritu', 'espíritus', 'm'], ['guardián', 'guardianes', 'm'], ['ermitaño', 'ermitaños', 'm'], ['sabio', 'sabios', 'm'], ['profeta', 'profetas', 'm'], ['máscara', 'máscaras', 'f']]
};

// Fallacies: [difficulty, key, en, es]
export const FALLACY_NAMES = ['adhom', 'dilemma', 'slope', 'circular', 'posthoc', 'hasty', 'bandwagon', 'nature', 'straw', 'authority', 'tradition', 'ignorance', 'composition', 'tuquoque', 'consequent', 'quantifier', 'equivocation'];
export const FALLACIES = [
  [3, 'adhom', 'You can’t trust Ana’s argument about the meaning of life — she failed philosophy in school.', 'No le podés creer a Ana lo que dice sobre el sentido de la vida: reprobó Filosofía en el secundario.'],
  [3, 'dilemma', 'Either life has one fixed purpose given from outside, or nothing anyone does matters at all.', 'O la vida tiene un propósito fijo dado desde afuera, o nada de lo que hacemos importa en absoluto.'],
  [4, 'slope', 'If we start asking why we exist, soon we’ll question everything, then believe nothing, and society will collapse.', 'Si empezamos a preguntarnos por qué existimos, pronto vamos a dudar de todo, después no vamos a creer en nada y la sociedad se va a derrumbar.'],
  [6, 'circular', 'This book tells the absolute truth, because the book itself says it never lies.', 'Este libro dice la verdad absoluta, porque el propio libro dice que nunca miente.'],
  [2, 'posthoc', 'I meditated this morning and then got a raise. Meditation brought me the money.', 'Medité esta mañana y después me aumentaron el sueldo. La meditación me trajo la plata.'],
  [4, 'hasty', 'The two philosophers I met were gloomy, so studying philosophy makes people unhappy.', 'Los dos filósofos que conocí eran tristes, así que estudiar filosofía hace infeliz a la gente.'],
  [2, 'bandwagon', 'Millions of people believe in fate, so fate must be real.', 'Millones de personas creen en el destino, así que el destino tiene que ser real.'],
  [5, 'nature', 'Fear of death is natural, so it must be good for us.', 'El miedo a la muerte es natural, así que debe ser bueno para nosotros.'],
  [6, 'straw', 'Pedro says people should question traditions. So Pedro thinks every tradition is worthless and should be destroyed.', 'Pedro dice que hay que cuestionar las tradiciones. O sea que Pedro cree que todas las tradiciones no valen nada y hay que destruirlas.'],
  [5, 'authority', 'A famous actor says the soul weighs 21 grams, so it does.', 'Un actor famoso dice que el alma pesa 21 gramos, así que es así.'],
  [6, 'tradition', 'People have always believed the stars guide our lives, so it’s true.', 'La gente siempre creyó que las estrellas guían nuestras vidas, así que es verdad.'],
  [7, 'ignorance', 'Nobody has proven that ghosts don’t exist, so ghosts exist.', 'Nadie demostró que los fantasmas no existen, así que los fantasmas existen.'],
  [8, 'composition', 'Every moment of my life is short, so my whole life is short.', 'Cada momento de mi vida es corto, así que mi vida entera es corta.'],
  [7, 'tuquoque', 'You say worrying about the future is pointless, but you worry all the time — so you’re wrong.', 'Decís que preocuparse por el futuro no sirve, pero vos te preocupás todo el tiempo, así que estás equivocado.'],
  [8, 'consequent', 'If someone is wise, they are calm. Lucía is calm. So Lucía is wise.', 'Si alguien es sabio, está tranquilo. Lucía está tranquila. Entonces Lucía es sabia.'],
  [10, 'quantifier', 'Every person has someone who loves them. So there is one person who loves everyone.', 'Toda persona tiene a alguien que la ama. Entonces hay una persona que ama a todos.'],
  [9, 'equivocation', 'The end of a thing is its perfection. Death is the end of life. So death is the perfection of life.', 'El fin de una cosa es su perfección. La muerte es el fin de la vida. Entonces la muerte es la perfección de la vida.']
];
