// LINGUISTIC (ES / EN banks): oddword, oddquick, anagram, analogy. Ported 1:1 from the prototype.
// deno-lint-ignore-file no-explicit-any
import { defGen, type GenDef, type Lang, mkItem, say } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { ANA, ANALOGIES, CATS, CLOSE, TRICKS } from "./data.ts";
import { ANALOGY_WHY } from "./analogy_why.ts";

const CATS_: Record<string, { g: string; en: string[]; es: string[] }> = CATS;
const TRICKS_: any[] = TRICKS;
const ANA_: Record<string, Record<number, string[]>> = ANA;
// Two d10 analogies were ambiguous (players' audit, 2026-10-27): "sonnet : 14" never said lines (a haiku's
// famous 17 is syllables) and "hydrogen : 1" fits atomic number AND mass (carbon: 6 or 12). data.ts is
// extracted from the prototype and never hand-edited, so the clarified wording is applied here, by index.
const ANALOGY_FIX: Record<number, [any, any]> = {
  30: [["sonnet", "14 lines", "haiku", ["3 lines", "5 lines", "7 lines", "17 lines"]], ["soneto", "14 versos", "haiku", ["3 versos", "5 versos", "7 versos", "17 versos"]]],
  31: [["hydrogen", "1 proton", "carbon", ["6 protons", "12 protons", "4 protons", "14 protons"]], ["hidrógeno", "1 protón", "carbono", ["6 protones", "12 protones", "4 protones", "14 protones"]]],
};
const ANALOGIES_: any[] = (ANALOGIES as any[]).map((x, i) => (ANALOGY_FIX[i] ? [x[0], ANALOGY_FIX[i][0], ANALOGY_FIX[i][1]] : x));

/** Category names (data.ts CATS keys) and why each odd-one-out trick is odd, for `why`. */
const CAT_NAME: Record<string, [string, string]> = {
  mammals: ["mammals", "mamíferos"], birds: ["birds", "aves"], fish: ["fish", "peces"], insects: ["insects", "insectos"],
  reptiles: ["reptiles", "reptiles"], fruits: ["fruits", "frutas"], vegetables: ["vegetables", "verduras"], tools: ["tools", "herramientas"],
  kitchen: ["kitchen utensils", "utensilios de cocina"], instruments: ["musical instruments", "instrumentos musicales"],
  metals: ["metals", "metales"], gems: ["gems", "piedras preciosas"], emotions: ["emotions", "emociones"], virtues: ["virtues", "virtudes"],
  time: ["units of time", "unidades de tiempo"], length: ["units of length", "unidades de longitud"], organs: ["organs", "órganos"],
  bones: ["bones", "huesos"], weather: ["kinds of weather", "fenómenos del tiempo"], landforms: ["landforms", "formas del relieve"],
};
const TRICK_WHY: [string, string][] = [ // by TRICKS index
  ["The others are fish; a whale is a mammal that lives in the sea.", "Los demás son peces; la ballena es un mamífero que vive en el mar."],
  ["The others are birds; a bat is a mammal that flies.", "Los demás son aves; el murciélago es un mamífero que vuela."],
  ["The others are insects (6 legs); a spider has 8 legs and is not an insect.", "Los demás son insectos (6 patas); la araña tiene 8 patas y no es un insecto."],
  ["The others are pure metals; bronze is a mix of metals (copper and tin).", "Los demás son metales puros; el bronce es una mezcla de metales (cobre y estaño)."],
  ["The others are reptiles; a salamander is an amphibian.", "Los demás son reptiles; la salamandra es un anfibio."],
  ["The others have four sides; a triangle has three.", "Los demás tienen cuatro lados; el triángulo tiene tres."],
  ["The others are mammals; a shark is a fish.", "Los demás son mamíferos; el tiburón es un pez."],
  ["The others are planets; the Moon goes around the Earth, not the Sun.", "Los demás son planetas; la Luna gira alrededor de la Tierra, no del Sol."],
  ["The others are trees; bamboo is a giant grass.", "Los demás son árboles; el bambú es una hierba gigante."],
];

function oddWordItem(g: GenDef, d: number, r: Rng, lang: Lang) {
  let four: string[], odd: string, why: string;
  if (d >= 9 || (d === 8 && r.chance(.5))) {
    const t = r.pick(TRICKS_), tr = t[lang]; four = tr[0].slice(); odd = tr[1];
    const w = TRICK_WHY[TRICKS_.indexOf(t)]; why = say(lang, w[0], w[1]);
  } else {
    let A: string, B: string;
    const names = Object.keys(CATS_);
    if (d <= 2) { A = r.pick(names); B = r.pick(names.filter((n) => CATS_[n].g !== CATS_[A].g)); }
    else if (d <= 5) { A = r.pick(names); const same = names.filter((n) => n !== A && CATS_[n].g === CATS_[A].g); B = same.length ? r.pick(same) : r.pick(names.filter((n) => n !== A)); }
    else { const pr = r.shuffle(r.pick(CLOSE)); A = pr[0]; B = pr[1]; }
    four = r.shuffle(CATS_[A][lang]).slice(0, 4);
    odd = r.pick(CATS_[B][lang]);
    why = say(lang, `${four.join(", ")} are all ${CAT_NAME[A][0]}; ${odd} is from another group: ${CAT_NAME[B][0]}.`, `${four.join(", ")} son ${CAT_NAME[A][1]}; ${odd} es de otro grupo: ${CAT_NAME[B][1]}.`);
  }
  const words = r.shuffle([...four, odd]);
  const ansIdx = words.indexOf(odd);
  return mkItem(g, d, { lang, display: { words }, key: { t: "idx", v: ansIdx }, meta: { four, odd }, why });
}
defGen({ id: "oddword", sec: "LIN", a: 1.3, k: 5, minMs: 1200, maxMs: 30000, make(d, r, ctx) { return oddWordItem(this, d, r, ctx.lang); } });
defGen({ id: "oddquick", sec: "LIN", a: 1.1, k: 5, minMs: 500, maxMs: 15000, w: 2, make(_d, r, ctx) { return oddWordItem(this, r.int(1, 3), r, ctx.lang); } });

/* Anagrams with letter tiles. Word lists chosen to have no common alternative anagram. */
defGen({
  id: "anagram", sec: "LIN", a: 1.4, k: 0, minMs: 1500, maxMs: 60000,
  make(d, r, ctx) {
    const lang = ctx.lang;
    const len = [4, 4, 5, 5, 6, 6, 7, 7, 8, 9][d - 1];
    // never repeat a word within a session (ctx.used persists in sessions.state)
    const used = ctx.used || new Set<string>();
    const pool = ANA_[lang][len].filter((w) => !used.has("ag" + w));
    const word = r.pick(pool.length ? pool : ANA_[lang][len]);
    used.add("ag" + word);
    let sc: string[];
    do { sc = r.shuffle(word.split("")); } while (sc.join("") === word);
    const sig = (w: string) => w.split("").sort().join("");
    const valid = [...new Set(Object.values(ANA_[lang]).flat().filter((w) => sig(w) === sig(word)))];
    const why = say(lang, `The letters ${sc.join(" ").toUpperCase()} spell ${word.toUpperCase()}${valid.length > 1 ? ` (${valid.filter((w) => w !== word).join(", ").toUpperCase()} also counts)` : ""}.`, `Las letras ${sc.join(" ").toUpperCase()} forman ${word.toUpperCase()}${valid.length > 1 ? ` (${valid.filter((w) => w !== word).join(", ").toUpperCase()} también vale)` : ""}.`);
    return mkItem(this, d, { lang, display: { letters: sc }, key: { t: "any", v: valid }, meta: { word }, why });
  },
});

/* Analogies — curated, parallel ES/EN, answer is always option 0 before shuffling */
defGen({
  id: "analogy", sec: "LIN", a: 1.4, k: 4, minMs: 1500, maxMs: 45000,
  make(d, r, ctx) {
    const lang = ctx.lang;
    const used = ctx.used || new Set();
    let best: [number, any] | null = null, bd = 99;
    for (const [i, it] of r.shuffle(ANALOGIES_.map((x, i) => [i, x] as [number, any]))) {
      if (used.has("an" + i)) continue;
      const dd = Math.abs(it[0] - d);
      if (dd < bd) { bd = dd; best = [i, it]; }
    }
    if (!best) best = [0, ANALOGIES_[0]];
    used.add("an" + best[0]);
    const [dd, en, es] = best[1];
    const it = lang === "es" ? es : en;
    const order = r.shuffle([0, 1, 2, 3]);
    const ansIdx = order.indexOf(0);
    // the link itself (analogy_why.ts, by bank index); the general sentence only if one is missing
    const w = ANALOGY_WHY[best[0]];
    const why = w && w[0] === en[0] ? say(lang, w[1], w[2])
      : say(lang, `${it[0]} is to ${it[1]} as ${it[2]} is to ${it[3][0]}: the same link joins both pairs. The other options are linked to ${it[2]} in a different way, or not at all.`,
        `${it[0]} es a ${it[1]} como ${it[2]} es a ${it[3][0]}: la misma relación une los dos pares. Las otras opciones se relacionan con ${it[2]} de otra manera, o no se relacionan.`);
    return mkItem(this, dd, { lang, display: { a: it[0], b: it[1], c: it[2], options: order.map((i) => it[3][i]) }, key: { t: "idx", v: ansIdx, rev: 2 }, why });
  },
});
