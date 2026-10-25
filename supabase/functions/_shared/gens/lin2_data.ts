// Hand-written banks for the second LIN set (gens/lin2.ts), 2026-10-25. NOT from the
// prototype. EN and ES are written separately (Spanish links, sayings and word order
// don't survive translation); ES is rioplatense like the rest of the test. Each bank has
// three tiers: d 1-3, 4-7, 8-10. Rule for every item: exactly one option is right; each
// wrong option may fit part of the clue, never all of it.

export type Tiers<T> = [T[], T[], T[]];

/** Missing link: three words that each join the answer (before or after). [w1, w2, w3, answer, wrong x3] */
export type Rat = [string, string, string, string, string[]];
export const RAT: { en: Tiers<Rat>; es: Tiers<Rat> } = {
  en: [
    [
      ["news", "wall", "sand", "paper", ["flash", "street", "castle"]],
      ["fish", "mine", "rush", "gold", ["sword", "field", "hour"]],
      ["night", "wrist", "stop", "watch", ["club", "band", "sign"]],
      ["flower", "friend", "scout", "girl", ["pot", "ship", "camp"]],
      ["home", "sea", "bed", "sick", ["work", "shell", "room"]],
      ["light", "birthday", "stick", "candle", ["house", "party", "lip"]],
      ["playing", "credit", "report", "card", ["field", "union", "ground"]],
      ["snow", "down", "out", "fall", ["man", "town", "side"]],
      ["sleeping", "bean", "trash", "bag", ["pill", "sprout", "can"]],
    ],
    [
      ["sore", "shoulder", "sweat", "cold", ["throat", "blade", "shirt"]],
      ["pine", "crab", "sauce", "apple", ["cone", "cake", "pan"]],
      ["board", "magic", "death", "black", ["game", "trick", "bed"]],
      ["cross", "rain", "tie", "bow", ["word", "coat", "break"]],
      ["wheel", "hand", "shopping", "cart", ["chair", "bag", "list"]],
      ["age", "mile", "sand", "stone", ["old", "post", "dune"]],
      ["salt", "deep", "foam", "sea", ["shaker", "end", "rubber"]],
      ["duck", "fold", "dollar", "bill", ["pond", "paper", "sign"]],
      ["tooth", "potato", "heart", "sweet", ["brush", "chip", "beat"]],
    ],
    [
      ["cracker", "union", "rabbit", "jack", ["fire", "trade", "hole"]],
      ["type", "ghost", "screen", "writer", ["face", "story", "saver"]],
      ["bump", "egg", "step", "goose", ["speed", "shell", "ladder"]],
      ["rain", "test", "stomach", "acid", ["coat", "drive", "ache"]],
      ["measure", "worm", "video", "tape", ["book", "game", "clip"]],
      ["ball", "print", "note", "foot", ["base", "finger", "book"]],
      ["shine", "glasses", "flower", "sun", ["moon", "eye", "wall"]],
    ],
  ],
  es: [
    [
      ["platos", "ropas", "manos", "lava", ["pasa", "guarda", "juego"]],
      ["latas", "botellas", "cartas", "abre", ["vacías", "tapa", "juego"]],
      ["noche", "día", "luna", "media", ["llena", "fría", "feriado"]],
      ["aviones", "retratos", "lápices", "porta", ["papel", "colores", "marco"]],
      ["corchos", "puntas", "bocados", "saca", ["vino", "lápiz", "ricos"]],
      ["cabezas", "olas", "hielos", "rompe", ["grandes", "cubitos", "frías"]],
    ],
    [
      ["tiempo", "montañas", "manos", "pasa", ["lava", "perder", "altas"]],
      ["mesa", "nombre", "dosis", "sobre", ["ratona", "propio", "alta"]],
      ["barros", "ropa", "espaldas", "guarda", ["lava", "sucia", "dolor"]],
      ["uñas", "fuegos", "césped", "corta", ["esmalte", "artificiales", "sintético"]],
      ["sellos", "moscas", "fuegos", "mata", ["corta", "colección", "atrapa"]],
      ["vidas", "manteles", "pantallas", "salva", ["dos", "planas", "individuales"]],
      ["manchas", "esmalte", "nieves", "quita", ["saca", "uñas", "eternas"]],
    ],
    [
      ["fiestas", "nieve", "marina", "agua", ["patrias", "bola", "mercante"]],
      ["pista", "retrato", "estima", "auto", ["baile", "familia", "gran"]],
      ["gotas", "kilómetros", "revoluciones", "cuenta", ["lluvia", "cien", "industrial"]],
      ["humor", "estar", "trato", "mal", ["bien", "buen", "sentido"]],
      ["aguas", "brisas", "caídas", "para", ["termales", "marinas", "libres"]],
      ["sol", "rayos", "golpes", "para", ["gira", "láser", "bajos"]],
    ],
  ],
};

/** Same meaning / opposite: [word, answer, wrong x3, "same" | "opp"] */
export type Syn = [string, string, string[], "same" | "opp"];
export const SYN: { en: Tiers<Syn>; es: Tiers<Syn> } = {
  en: [
    [
      ["brief", "short", ["loud", "bright", "early"], "same"],
      ["begin", "start", ["finish", "follow", "borrow"], "same"],
      ["quick", "fast", ["quiet", "sharp", "safe"], "same"],
      ["huge", "enormous", ["heavy", "hollow", "humble"], "same"],
      ["angry", "furious", ["anxious", "tired", "curious"], "same"],
      ["ancient", "modern", ["old", "broken", "distant"], "opp"],
      ["generous", "selfish", ["kind", "wealthy", "honest"], "opp"],
    ],
    [
      ["reluctant", "unwilling", ["unable", "unusual", "unaware"], "same"],
      ["fragile", "delicate", ["frequent", "flexible", "fragrant"], "same"],
      ["cautious", "careful", ["curious", "nervous", "clever"], "same"],
      ["abundant", "plentiful", ["ancient", "rare", "available"], "same"],
      ["vague", "unclear", ["empty", "valuable", "vast"], "same"],
      ["scarce", "plentiful", ["rare", "expensive", "hidden"], "opp"],
      ["transparent", "opaque", ["clear", "shiny", "fragile"], "opp"],
    ],
    [
      ["ubiquitous", "omnipresent", ["unique", "ambiguous", "unanimous"], "same"],
      ["candid", "frank", ["sweet", "cautious", "hidden"], "same"],
      ["lethargic", "sluggish", ["deadly", "nervous", "logical"], "same"],
      ["ephemeral", "fleeting", ["eternal", "ethereal", "emotional"], "same"],
      ["meticulous", "thorough", ["quick", "sloppy", "ridiculous"], "same"],
      ["frugal", "wasteful", ["thrifty", "fragile", "fruitful"], "opp"],
      ["benevolent", "malicious", ["kind", "lazy", "wealthy"], "opp"],
    ],
  ],
  es: [
    [
      ["breve", "corto", ["ruidoso", "brillante", "temprano"], "same"],
      ["comenzar", "empezar", ["terminar", "seguir", "pedir"], "same"],
      ["rápido", "veloz", ["callado", "filoso", "seguro"], "same"],
      ["enorme", "gigante", ["pesado", "hueco", "humilde"], "same"],
      ["enojado", "furioso", ["ansioso", "cansado", "curioso"], "same"],
      ["antiguo", "moderno", ["viejo", "roto", "lejano"], "opp"],
      ["generoso", "egoísta", ["amable", "rico", "honesto"], "opp"],
    ],
    [
      ["cauteloso", "prudente", ["curioso", "nervioso", "astuto"], "same"],
      ["frágil", "delicado", ["frecuente", "flexible", "fragante"], "same"],
      ["abundante", "copioso", ["ausente", "escaso", "disponible"], "same"],
      ["difuso", "borroso", ["vacío", "valioso", "extenso"], "same"],
      ["sereno", "tranquilo", ["seco", "serio", "sincero"], "same"],
      ["escaso", "abundante", ["raro", "caro", "oculto"], "opp"],
      ["transparente", "opaco", ["claro", "brillante", "frágil"], "opp"],
    ],
    [
      ["efímero", "fugaz", ["eterno", "etéreo", "emotivo"], "same"],
      ["meticuloso", "minucioso", ["rápido", "descuidado", "ridículo"], "same"],
      ["apático", "indiferente", ["patético", "simpático", "apurado"], "same"],
      ["ubicuo", "omnipresente", ["único", "ambiguo", "unánime"], "same"],
      ["franco", "sincero", ["dulce", "cauto", "oculto"], "same"],
      ["austero", "derrochador", ["ahorrativo", "frágil", "fructífero"], "opp"],
      ["benévolo", "malévolo", ["bondadoso", "perezoso", "adinerado"], "opp"],
    ],
  ],
};

/** Finish the sentence: [sentence with ___, answer, wrong x3] */
export type Cloze = [string, string, string[]];
export const CLOZE: { en: Tiers<Cloze>; es: Tiers<Cloze> } = {
  en: [
    [
      ["The bridge was closed because the storm had made it ___.", "unsafe", ["unusual", "unkind", "untidy"]],
      ["She put on her coat because it was ___ outside.", "cold", ["hungry", "loud", "early"]],
      ["Please ___ the door; the cat keeps getting out.", "close", ["open", "paint", "knock"]],
      ["He was so tired that he fell ___ on the sofa.", "asleep", ["awake", "aside", "alone"]],
      ["The museum is free, so you don't have to ___ for a ticket.", "pay", ["spend", "cost", "buying"]],
    ],
    [
      ["Although the test was difficult, most students ___ it.", "passed", ["failed", "missed", "feared"]],
      ["The recipe needs two cups of flour, but we only have one, so we must ___ every amount.", "halve", ["double", "triple", "ignore"]],
      ["Her explanation was so ___ that even the children understood it.", "clear", ["complicated", "technical", "quiet"]],
      ["The more you practise, the ___ you get.", "better", ["worse", "older", "slower"]],
      ["After weeks of discussion, they finally reached a ___.", "decision", ["question", "problem", "holiday"]],
    ],
    [
      ["His story was so ___ that nobody believed a word of it.", "far-fetched", ["convincing", "detailed", "honest"]],
      ["The new rule was ___: it applied to everyone, without exception.", "universal", ["optional", "temporary", "local"]],
      ["She is usually talkative, but today she was unusually ___.", "quiet", ["cheerful", "chatty", "busy"]],
      ["The evidence was ___, so the judge could not reach a verdict.", "inconclusive", ["overwhelming", "convincing", "clear"]],
      ["Prices rose so ___ that the shop changed its labels every week.", "rapidly", ["slightly", "rarely", "cheaply"]],
    ],
  ],
  es: [
    [
      ["Cerraron el puente porque la tormenta lo había dejado ___.", "peligroso", ["aburrido", "limpio", "ordenado"]],
      ["Se puso la campera porque afuera hacía ___.", "frío", ["calor", "sueño", "tarde"]],
      ["Cerrá la puerta, que el gato se ___ a la calle.", "escapa", ["duerme", "ríe", "baña"]],
      ["Estaba tan cansado que se quedó ___ en el sillón.", "dormido", ["despierto", "parado", "apurado"]],
      ["El museo es gratis, así que no hace falta ___ la entrada.", "pagar", ["cobrar", "perder", "romper"]],
    ],
    [
      ["Aunque el examen era difícil, la mayoría de los alumnos lo ___.", "aprobó", ["desaprobó", "odió", "olvidó"]],
      ["Cuanto más practicás, ___ te sale.", "mejor", ["peor", "menos", "tarde"]],
      ["Su explicación fue tan ___ que hasta los chicos la entendieron.", "clara", ["complicada", "técnica", "larga"]],
      ["Después de semanas de discusión, por fin llegaron a un ___.", "acuerdo", ["problema", "viaje", "error"]],
      ["La receta pide dos tazas de harina y tenemos una sola, así que hay que hacer ___ de la receta.", "la mitad", ["el doble", "el triple", "la cena"]],
    ],
    [
      ["Su historia era tan ___ que nadie le creyó.", "inverosímil", ["convincente", "detallada", "sincera"]],
      ["La norma era ___: valía para todos, sin excepción.", "universal", ["optativa", "temporaria", "local"]],
      ["Suele ser muy charlatana, pero hoy estuvo extrañamente ___.", "callada", ["alegre", "conversadora", "ocupada"]],
      ["Las pruebas no eran ___, así que el juez no pudo dictar sentencia.", "concluyentes", ["falsas", "escasas", "ruidosas"]],
      ["Los precios subían tan ___ que el almacén cambiaba las etiquetas cada semana.", "rápido", ["poco", "raramente", "barato"]],
    ],
  ],
};

/** Unscramble: the sentence, then any other correct order of the same tiles. The first
 *  tile is capitalised and the last carries the full stop, which fixes most of the order. */
export type Scramble = [string, string[]];
export const SCRAMBLE: { en: Tiers<Scramble>; es: Tiers<Scramble> } = {
  en: [
    [
      ["The cat is sleeping on the sofa.", []],
      ["My brother plays the guitar every day.", []],
      ["She drinks a glass of water.", []],
      ["Please close the window before you leave.", []],
      ["The bus to town leaves at noon.", ["The bus leaves to town at noon."]],
    ],
    [
      ["Our teacher gave us a difficult test on Friday.", []],
      ["It was too cold to go swimming in the lake.", []],
      ["My grandmother bakes a cake every Sunday morning.", []],
      ["He finished his homework before dinner.", []],
      ["The baker sold bread to all the neighbours.", []],
    ],
    [
      ["Although it was raining, we decided to walk home.", []],
      ["The scientist who discovered the vaccine won an award.", []],
      ["If you had told me earlier, I would have helped you.", []],
      ["Not only did she win the race, but she also broke the record.", []],
      ["The book that you lent me was really interesting.", []],
    ],
  ],
  es: [
    [
      ["El gato duerme en el sillón.", []],
      ["Mi hermano toca la guitarra todos los días.", []],
      ["Ella toma un vaso de agua.", []],
      ["Por favor cerrá la ventana antes de salir.", []],
      ["El colectivo al centro sale al mediodía.", ["El colectivo sale al centro al mediodía."]],
    ],
    [
      ["Nuestra profesora nos tomó un examen difícil el viernes.", ["Nuestra profesora nos tomó un difícil examen el viernes."]],
      ["Hacía demasiado frío para nadar en el lago.", []],
      ["Mi abuela hace una torta todos los domingos.", []],
      ["Él terminó la tarea antes de la cena.", []],
      ["El panadero les vendió pan a todos los vecinos.", []],
    ],
    [
      ["Aunque llovía, decidimos volver a casa caminando.", []],
      ["La científica que descubrió la vacuna ganó un premio.", []],
      ["Si me lo hubieras dicho antes, te habría ayudado.", []],
      ["No solo ganó la carrera, sino que también rompió el récord.", []],
      ["El libro que me prestaste era muy interesante.", []],
    ],
  ],
};

/** Proverbs: [saying, meaning, wrong meanings x3] */
export type Prov = [string, string, string[]];
export const PROVERB: { en: Tiers<Prov>; es: Tiers<Prov> } = {
  en: [
    [
      ["Don't count your chickens before they hatch.", "Don't rely on something good before it actually happens.", ["Look after your animals.", "Patience always brings rewards.", "Count carefully before you decide."]],
      ["The early bird catches the worm.", "People who start early get the best chances.", ["Birds should eat in the morning.", "Small problems are easy to catch.", "Waiting is better than hurrying."]],
      ["Actions speak louder than words.", "What people do shows more than what they say.", ["Loud people get noticed.", "It is rude to talk while working.", "Words can hurt more than actions."]],
      ["Don't judge a book by its cover.", "Don't judge someone or something only by how it looks.", ["Read a book before you buy it.", "Covers are the best part of a book.", "Don't lend your books to others."]],
      ["Practice makes perfect.", "Doing something many times makes you good at it.", ["Nobody is perfect.", "Perfect people don't need to practise.", "Practice is boring but necessary."]],
    ],
    [
      ["Every cloud has a silver lining.", "Something good can come out of a bad situation.", ["Bad weather never lasts long.", "Rich people have problems too.", "Rain is useful for the fields."]],
      ["Too many cooks spoil the broth.", "When too many people work on one thing, the result gets worse.", ["Big kitchens make better food.", "Cooking needs many people.", "Don't eat too much soup."]],
      ["Where there's smoke, there's fire.", "Rumours or signs usually point to something real.", ["Fires are always dangerous.", "Smoking is bad for you.", "Problems hide in plain sight."]],
      ["A bird in the hand is worth two in the bush.", "Something you already have is worth more than something better you might get.", ["Birds are easier to catch in bushes.", "Two people can do more than one.", "Take care of the animals you own."]],
      ["Don't put all your eggs in one basket.", "Don't risk everything on a single plan.", ["Carry eggs carefully.", "Share your food with others.", "Finish one job before you start another."]],
    ],
    [
      ["Still waters run deep.", "Quiet people can have deep thoughts or feelings.", ["Calm seas are dangerous.", "Slow work is better work.", "Lakes are deeper than rivers."]],
      ["The proof of the pudding is in the eating.", "You can only judge something by trying it.", ["Dessert is the best part of a meal.", "Evidence must always be written down.", "Good cooks never taste their food."]],
      ["Necessity is the mother of invention.", "People invent things when they really need them.", ["Mothers are the best inventors.", "Inventions are rarely necessary.", "Only rich people can invent."]],
      ["You can't have your cake and eat it.", "You can't keep something and use it up at the same time.", ["Sharing cake is polite.", "Eat dessert last.", "Don't take more than you need."]],
      ["Let sleeping dogs lie.", "Don't stir up an old problem that is quiet now.", ["Never trust a sleeping dog.", "Let tired people rest.", "Animals should sleep outside."]],
    ],
  ],
  es: [
    [
      ["Más vale pájaro en mano que cien volando.", "Es mejor algo seguro que mucho que tal vez no llegue.", ["Hay que cuidar a los animales.", "Cuantos más, mejor.", "Los pájaros vuelan mejor en grupo."]],
      ["No hay mal que por bien no venga.", "Algo malo puede traer algo bueno.", ["Lo malo siempre vuelve.", "El bien y el mal son lo mismo.", "Hay que alejarse de la gente mala."]],
      ["Al que madruga, Dios lo ayuda.", "Quien empieza temprano tiene más oportunidades.", ["Hay que rezar a la mañana.", "Dormir mucho es saludable.", "La ayuda siempre llega tarde."]],
      ["En boca cerrada no entran moscas.", "A veces conviene callarse.", ["Hay que cuidar la higiene.", "Las moscas son peligrosas.", "Masticar con la boca cerrada es de buena educación."]],
      ["Ojos que no ven, corazón que no siente.", "Lo que no sabemos no nos hace sufrir.", ["Hay que ir al oculista.", "El amor es ciego.", "Mirar mucho cansa la vista."]],
    ],
    [
      ["Perro que ladra no muerde.", "Quien amenaza mucho rara vez hace daño.", ["Los perros chicos son peligrosos.", "Hay que tener cuidado con los perros.", "Quien grita tiene razón."]],
      ["A caballo regalado no se le miran los dientes.", "Un regalo se acepta sin buscarle defectos.", ["Hay que revisar bien lo que se compra.", "Los caballos viejos tienen malos dientes.", "No hay que regalar animales."]],
      ["Camarón que se duerme se lo lleva la corriente.", "Si te descuidás, perdés la oportunidad.", ["Hay que dormir bien.", "El mar es peligroso.", "Lo pequeño siempre pierde."]],
      ["Dime con quién andas y te diré quién eres.", "Tus amistades dicen mucho de vos.", ["Hay que caminar acompañado.", "Nadie se conoce a sí mismo.", "Los amigos siempre dicen la verdad."]],
      ["Del dicho al hecho hay mucho trecho.", "Es fácil decir algo y difícil hacerlo.", ["Los caminos largos cansan.", "Hay que hablar menos.", "Lo que se dice siempre se cumple."]],
    ],
    [
      ["El que se quema con leche, ve una vaca y llora.", "Quien tuvo una mala experiencia desconfía de todo lo parecido.", ["La leche caliente es peligrosa.", "Las vacas asustan a los chicos.", "Llorar alivia el dolor."]],
      ["Cría cuervos y te sacarán los ojos.", "Si ayudás a alguien desagradecido, puede volverse contra vos.", ["Los cuervos son peligrosos.", "Los pájaros negros traen mala suerte.", "No hay que tener mascotas."]],
      ["No por mucho madrugar amanece más temprano.", "Apurarse no hace que las cosas pasen antes.", ["Hay que levantarse tarde.", "El sol sale siempre a la misma hora.", "Madrugar es malo para la salud."]],
      ["A río revuelto, ganancia de pescadores.", "Algunos sacan provecho del desorden.", ["Pescar es más fácil con agua limpia.", "Los ríos crecen después de la lluvia.", "El trabajo duro da ganancias."]],
      ["Muerto el perro, se acabó la rabia.", "Si eliminás la causa, se termina el problema.", ["Los perros enfermos son peligrosos.", "El enojo dura poco.", "Hay que vacunar a las mascotas."]],
    ],
  ],
};

/** Read between the lines: [passage, question, answer, wrong x3]. The answer MUST follow
 *  from the passage; each wrong option might be true but doesn't have to be. */
export type Infer = [string, string, string, string[]];
export const INFER: { en: Tiers<Infer>; es: Tiers<Infer> } = {
  en: [
    [
      ["The shop opens at 9:00. Rosa got there at 8:40 and waited 25 minutes for the doors to open.", "What must be true?", "The shop opened late.", ["Rosa arrived late.", "The shop opened early.", "Rosa left before it opened."]],
      ["All the cups in the cupboard are blue. Tom took a cup from the cupboard.", "What must be true?", "Tom's cup is blue.", ["Tom's cup is clean.", "Tom likes blue.", "The cupboard is empty now."]],
      ["Lena is taller than her brother. Her brother is taller than their dad.", "What must be true?", "Lena is taller than her dad.", ["Their dad is the oldest.", "Lena is the oldest child.", "Her brother is the shortest."]],
      ["A train leaves every 20 minutes. One left at 10:15.", "What must be true?", "Another one leaves at 10:35.", ["The next one leaves at 10:30.", "The train is always late.", "It is now 10:15."]],
      ["Nobody in the class has a dog. Sam is in the class.", "What must be true?", "Sam doesn't have a dog.", ["Sam has a cat.", "Sam wants a dog.", "Sam doesn't like dogs."]],
    ],
    [
      ["If it rains, the match is cancelled. The match was not cancelled.", "What must be true?", "It didn't rain.", ["It was sunny.", "The home team won.", "It rained after the match."]],
      ["Every student who passed got a certificate. Mia didn't get a certificate.", "What must be true?", "Mia didn't pass.", ["Mia didn't take the test.", "Mia lost her certificate.", "Mia failed on purpose."]],
      ["Ana is older than Ben but younger than Cleo. Dev is younger than Ben.", "What must be true?", "Cleo is older than Dev.", ["Ana is the oldest.", "Dev is older than Ana.", "Ben is the youngest."]],
      ["The museum is closed on Mondays and on public holidays. Today the museum is open.", "What must be true?", "Today is not a Monday.", ["Today is a weekend.", "Today is a public holiday.", "Tomorrow the museum is closed."]],
      ["Half of the 20 guests drank tea. Everyone else drank coffee.", "What must be true?", "At least 10 guests drank coffee.", ["Most guests drank tea.", "All 20 guests drank coffee.", "Nobody drank both."]],
    ],
    [
      ["Some painters are musicians. All musicians can read music.", "What must be true?", "Some painters can read music.", ["All painters can read music.", "Some musicians can't paint.", "No painter is a musician."]],
      ["Only people with a ticket may go in. Leo went in.", "What must be true?", "Leo had a ticket.", ["Leo bought a ticket.", "Everyone with a ticket went in.", "Leo went in first."]],
      ["Kim always takes the bus when it rains. Today Kim walked all the way.", "What must be true?", "It isn't raining today.", ["It is sunny today.", "Kim missed the bus.", "Kim likes walking."]],
      ["Box A weighs more than box B. Box C weighs less than box B. Box D weighs more than box A.", "What must be true?", "Box D is the heaviest.", ["Box A is the heaviest.", "Box B is the lightest.", "Box C weighs more than box A."]],
      ["No reptile has fur. Some pets are reptiles.", "What must be true?", "Some pets have no fur.", ["No pet has fur.", "All reptiles are pets.", "Some reptiles have fur."]],
    ],
  ],
  es: [
    [
      ["El negocio abre a las 9:00. Rosa llegó a las 8:40 y esperó 25 minutos hasta que abrieron.", "¿Qué tiene que ser cierto?", "El negocio abrió tarde.", ["Rosa llegó tarde.", "El negocio abrió temprano.", "Rosa se fue antes de que abrieran."]],
      ["Todas las tazas del armario son azules. Tomás sacó una taza del armario.", "¿Qué tiene que ser cierto?", "La taza de Tomás es azul.", ["La taza de Tomás está limpia.", "A Tomás le gusta el azul.", "El armario quedó vacío."]],
      ["Lena es más alta que su hermano. Su hermano es más alto que el papá.", "¿Qué tiene que ser cierto?", "Lena es más alta que su papá.", ["El papá es el mayor.", "Lena es la mayor de los hijos.", "El hermano es el más bajo."]],
      ["Sale un tren cada 20 minutos. Uno salió a las 10:15.", "¿Qué tiene que ser cierto?", "Sale otro a las 10:35.", ["El próximo sale a las 10:30.", "El tren siempre llega tarde.", "Ahora son las 10:15."]],
      ["Nadie del curso tiene perro. Sami es del curso.", "¿Qué tiene que ser cierto?", "Sami no tiene perro.", ["Sami tiene un gato.", "Sami quiere un perro.", "A Sami no le gustan los perros."]],
    ],
    [
      ["Si llueve, se suspende el partido. El partido no se suspendió.", "¿Qué tiene que ser cierto?", "No llovió.", ["Hubo sol.", "Ganó el equipo local.", "Llovió después del partido."]],
      ["Todos los que aprobaron recibieron un certificado. Mía no recibió certificado.", "¿Qué tiene que ser cierto?", "Mía no aprobó.", ["Mía no rindió el examen.", "Mía perdió el certificado.", "Mía desaprobó a propósito."]],
      ["Ana es mayor que Beto pero menor que Clara. Dani es menor que Beto.", "¿Qué tiene que ser cierto?", "Clara es mayor que Dani.", ["Ana es la mayor.", "Dani es mayor que Ana.", "Beto es el menor."]],
      ["El museo cierra los lunes y los feriados. Hoy el museo está abierto.", "¿Qué tiene que ser cierto?", "Hoy no es lunes.", ["Hoy es fin de semana.", "Hoy es feriado.", "Mañana el museo está cerrado."]],
      ["La mitad de los 20 invitados tomó té. Todos los demás tomaron café.", "¿Qué tiene que ser cierto?", "Al menos 10 invitados tomaron café.", ["La mayoría tomó té.", "Los 20 invitados tomaron café.", "Nadie tomó las dos cosas."]],
    ],
    [
      ["Algunos pintores son músicos. Todos los músicos saben leer partituras.", "¿Qué tiene que ser cierto?", "Algunos pintores saben leer partituras.", ["Todos los pintores saben leer partituras.", "Algunos músicos no saben pintar.", "Ningún pintor es músico."]],
      ["Solo puede entrar la gente con entrada. Leo entró.", "¿Qué tiene que ser cierto?", "Leo tenía entrada.", ["Leo compró una entrada.", "Entraron todos los que tenían entrada.", "Leo entró primero."]],
      ["Kim siempre se toma el colectivo cuando llueve. Hoy Kim hizo todo el camino a pie.", "¿Qué tiene que ser cierto?", "Hoy no llueve.", ["Hoy hay sol.", "Kim perdió el colectivo.", "A Kim le gusta caminar."]],
      ["La caja A pesa más que la B. La caja C pesa menos que la B. La caja D pesa más que la A.", "¿Qué tiene que ser cierto?", "La caja D es la más pesada.", ["La caja A es la más pesada.", "La caja B es la más liviana.", "La caja C pesa más que la A."]],
      ["Ningún reptil tiene pelo. Algunas mascotas son reptiles.", "¿Qué tiene que ser cierto?", "Algunas mascotas no tienen pelo.", ["Ninguna mascota tiene pelo.", "Todos los reptiles son mascotas.", "Algunos reptiles tienen pelo."]],
    ],
  ],
};
