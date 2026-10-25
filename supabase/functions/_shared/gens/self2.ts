// INTRAPERSONAL, second set (2026-10-25; NOT in the prototype): recall ("Will you remember?",
// feeling of knowing). The player studies word pairs, says how many they will remember, then
// is shown each first word and picks its partner. What counts is how close the guess was, not
// how many were remembered: session-finish turns the guesses into recallErr / recallBias
// (engine.ts scoreIQ), and they stay out of the confidence rows the Self score is built from.
// Served only in the Self test, to clients that send gv >= 8 (engine.ts nextIqItem).
import { defGen, mkItem } from "./registry.ts";

/** Concrete nouns, EN and ES at the same index (a pair is two indexes, so both languages
 *  draw the same way). No alcohol, nothing rude in rioplatense Spanish (no "concha"). */
export const RECALL_WORDS: { en: string[]; es: string[] } = {
  en: [
    "apple", "anchor", "arrow", "bag", "ball", "balloon", "banana", "basket", "bed", "bell",
    "bench", "bicycle", "blanket", "boat", "bone", "book", "boot", "bowl", "box", "branch",
    "bread", "bridge", "broom", "brush", "bucket", "button", "cake", "camel", "candle", "car",
    "carpet", "carrot", "castle", "cat", "chair", "cheese", "cherry", "clock", "cloud", "coat",
    "coin", "comb", "cow", "crown", "cup", "desk", "dog", "door", "drum", "duck",
    "eagle", "egg", "elephant", "feather", "finger", "fish", "flag", "flower", "fork", "frog",
    "garden", "glove", "goat", "guitar", "hammer", "hat", "horse", "house", "island", "jacket",
    "key", "kite", "knife", "ladder", "lamp", "leaf", "lemon", "lion", "lock", "map",
    "mirror", "moon", "mountain", "mouse", "nail", "needle", "nest", "onion", "owl", "pencil",
    "piano", "pillow", "plate", "pocket", "potato", "rabbit", "ring", "river", "road", "rock",
    "rope", "rose", "sand", "scarf", "sheep", "shoe", "shovel", "sock", "spoon", "star",
    "sun", "table", "tiger", "tooth", "towel", "tower", "train", "tree", "truck", "umbrella",
    "wall", "whale", "wheel", "window", "wolf", "zebra", "violin", "tent", "lizard", "soap",
    "snake", "rocket", "pumpkin", "parrot", "orange", "mask", "magnet", "hook", "helmet", "honey",
  ],
  es: [
    "manzana", "ancla", "flecha", "bolsa", "pelota", "globo", "banana", "canasta", "cama", "campana",
    "banco", "bicicleta", "manta", "barco", "hueso", "libro", "bota", "cuenco", "caja", "rama",
    "pan", "puente", "escoba", "cepillo", "balde", "botón", "torta", "camello", "vela", "auto",
    "alfombra", "zanahoria", "castillo", "gato", "silla", "queso", "cereza", "reloj", "nube", "abrigo",
    "moneda", "peine", "vaca", "corona", "taza", "escritorio", "perro", "puerta", "tambor", "pato",
    "águila", "huevo", "elefante", "pluma", "dedo", "pez", "bandera", "flor", "tenedor", "rana",
    "jardín", "guante", "cabra", "guitarra", "martillo", "sombrero", "caballo", "casa", "isla", "campera",
    "llave", "barrilete", "cuchillo", "escalera", "lámpara", "hoja", "limón", "león", "candado", "mapa",
    "espejo", "luna", "montaña", "ratón", "clavo", "aguja", "nido", "cebolla", "búho", "lápiz",
    "piano", "almohada", "plato", "bolsillo", "papa", "conejo", "anillo", "río", "camino", "piedra",
    "soga", "rosa", "arena", "bufanda", "oveja", "zapato", "pala", "media", "cuchara", "estrella",
    "sol", "mesa", "tigre", "diente", "toalla", "torre", "tren", "árbol", "camión", "paraguas",
    "pared", "ballena", "rueda", "ventana", "lobo", "cebra", "violín", "carpa", "lagarto", "jabón",
    "serpiente", "cohete", "calabaza", "loro", "naranja", "máscara", "imán", "gancho", "casco", "miel",
  ],
};

/* ---------------- recall: study pairs, guess how many you'll remember, then recall ----------------
   d 1-3: 3 pairs, 4-6: 4, 7-9: 5, 10: 6; 1.5 s of study per pair (plus 1 s). Each first word
   is asked once, in a new order; the options are every partner plus 2 words not studied.
   display: pairs [[cue, partner]...], order (pair index per question), options, studyMs.
   key v: the right option per question. The player sends { g: guess, picks: [option...] }. */
defGen({
  id: "recall", sec: "SELF", a: 1, k: 0, minMs: 0, maxMs: 120000,
  make(d, r, ctx) {
    const n = d <= 3 ? 3 : d <= 6 ? 4 : d <= 9 ? 5 : 6;
    const all = RECALL_WORDS.en.map((_, i) => i);
    let fresh = all.filter((i) => !ctx.used.has(`rc${i}`));
    if (fresh.length < 2 * n + 2) fresh = all; // a very long test: words come round again
    const ids = r.shuffle(fresh).slice(0, 2 * n + 2);
    ids.forEach((i) => ctx.used.add(`rc${i}`));
    const w = (i: number) => RECALL_WORDS[ctx.lang][i];
    const pairs = Array.from({ length: n }, (_, p) => [w(ids[2 * p]), w(ids[2 * p + 1])]);
    const options = r.shuffle([...pairs.map((p) => p[1]), w(ids[2 * n]), w(ids[2 * n + 1])]);
    const order = r.shuffle(pairs.map((_, p) => p));
    return mkItem(this, d, {
      lang: ctx.lang, deferTimer: true, noTimerBar: true,
      display: { pairs, order, options, studyMs: 1000 + 1500 * n },
      key: { t: "recall", v: order.map((p) => options.indexOf(pairs[p][1])) },
    });
  },
});
