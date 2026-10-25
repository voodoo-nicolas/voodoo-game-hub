// EXISTENTIAL, second set (2026-10-25; NOT in the prototype): wason (turn the cards),
// necsuf (needed or enough), assume (what's assumed), contradict (says and unsays),
// crt (think twice). Logic, not beliefs. Served only to clients that send gv >= 7.
import { type Ctx, defGen, type GenDef, type Lang, mkItem, say } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { ASSUME, CONTRA, DEONTIC, NECSUF_DOMAINS } from "./exi2_data.ts";
import { tierOf } from "./lin2.ts";

function pickFrom<T>(g: GenDef, bank: { en: T[][]; es: T[][] }, d: number, r: Rng, ctx: Ctx): T {
  const t = tierOf(d), list = bank[ctx.lang][t];
  const fresh = list.map((_, i) => i).filter((i) => !ctx.used.has(`${g.id}${t}:${i}`));
  const i = r.pick(fresh.length ? fresh : list.map((_, i) => i));
  ctx.used.add(`${g.id}${t}:${i}`);
  return list[i];
}

/* ---------------- wason: which cards must you turn? (answer "i,j" sorted) ----------------
   A card must be turned when its hidden side could break the rule: it shows P true, or
   it shows Q false. d 1-3: people and what they do; d 4-7: letters and numbers;
   d 8-10: the same rule worded as "does not", "only if" or from the number side, 6 cards. */
const VOW = ["A", "E", "I", "O", "U"], CON = ["B", "K", "M", "R", "T"], EVEN = [2, 4, 6, 8], ODD = [3, 5, 7, 9];
export const isCat = (cat: string, v: string) =>
  cat === "vowel" ? VOW.includes(v) : cat === "consonant" ? CON.includes(v) : cat === "even" ? Number(v) % 2 === 0 : Number(v) % 2 === 1;
const W_TXT: Record<Lang, Record<string, string>> = {
  en: {
    note: "Each card has a letter on one side and a number on the other.",
    vowel: "a vowel", consonant: "a consonant", even: "an even number", odd: "an odd number",
    plain: "If a card has {p} on one side, it has {q} on the other.",
    not: "If a card has {p} on one side, it does not have {q} on the other.",
    onlyif: "A card has {p} on one side only if it has {q} on the other.",
  },
  es: {
    note: "Cada carta tiene una letra de un lado y un número del otro.",
    vowel: "una vocal", consonant: "una consonante", even: "un número par", odd: "un número impar",
    plain: "Si una carta tiene {p} de un lado, tiene {q} del otro.",
    not: "Si una carta tiene {p} de un lado, no tiene {q} del otro.",
    onlyif: "Una carta tiene {p} de un lado solo si tiene {q} del otro.",
  },
};
defGen({
  id: "wason", sec: "EXI", a: 1.4, k: 0, minMs: 3000, maxMs: 90000,
  make(d, r, ctx) {
    let rule: string, note: string, cards: string[], turn: boolean[];
    if (d <= 3) {
      const [txt, nt, pt, pf, qt, qf] = r.pick(DEONTIC[ctx.lang]);
      const deck = r.shuffle([[pt, true], [pf, false], [qt, false], [qf, true]] as [string, boolean][]);
      rule = txt; note = nt; cards = deck.map((c) => c[0]); turn = deck.map((c) => c[1]);
    } else {
      const T = W_TXT[ctx.lang];
      const letterSide = d <= 7 || r.chance(.65);
      const form = d <= 7 ? "plain" : letterSide ? r.pick(["not", "onlyif"]) : "plain";
      const pCat = letterSide ? r.pick(["vowel", "consonant"]) : r.pick(["even", "odd"]);
      const qCat = letterSide ? r.pick(["even", "odd"]) : r.pick(["vowel", "consonant"]);
      // what the hidden side must be when P holds
      const must = form === "not" ? ({ even: "odd", odd: "even", vowel: "consonant", consonant: "vowel" } as Record<string, string>)[qCat] : qCat;
      rule = T[form].replace("{p}", T[pCat]).replace("{q}", T[qCat]);
      note = T.note;
      const letters = [r.pick(VOW), r.pick(CON)], numbers = [String(r.pick(EVEN)), String(r.pick(ODD))];
      if (d >= 8) { letters.push(r.pick([...VOW, ...CON].filter((x) => !letters.includes(x)))); numbers.push(String(r.pick([...EVEN, ...ODD].filter((x) => !numbers.includes(String(x)))))); }
      cards = r.shuffle([...letters, ...numbers]);
      const pSideL = letterSide;
      turn = cards.map((c) => { const isL = /[A-Z]/.test(c); return isL === pSideL ? isCat(pCat, c) : !isCat(must, c); });
    }
    const ans = turn.map((t, i) => (t ? i : -1)).filter((i) => i >= 0).join(",");
    const pick = cards.filter((_, i) => turn[i]).join(", ");
    const why = say(ctx.lang, `Turn over only the cards that could break the rule: ${pick}. A card breaks it only if one side has the “if” part and the other side lacks the “then” part. Whatever is on the back of the other cards, they can't break it.`,
      `Hay que dar vuelta solo las cartas que podrían romper la regla: ${pick}. Una carta la rompe solo si de un lado tiene la parte del “si” y del otro le falta la parte del “entonces”. Tengan lo que tengan atrás, las demás no pueden romperla.`);
    return mkItem(this, d, { display: { rule, note, cards }, key: { t: "str", v: ans, strict: true }, meta: { turn }, why });
  },
});

/* ---------------- necsuf: needed or enough? (4 options) ---------------- */
export const NS_FORMS: Record<Lang, Record<string, string>> = {
  en: {
    onlyif: "You can {a} only if you have {c}.", if: "Anyone who has {c} can {a}.", iff: "You can {a} if, and only if, you have {c}.",
    neither: "Some people who have {c} can't {a}, and some who don't have {c} can.", contra: "If you don't have {c}, you can't {a}.",
    nobody: "Nobody without {c} can {a}.", unless: "You can't {a} unless you have {c}.", alltakes: "Having {c} is all it takes to {a}.",
    whoever: "Whoever has {c} can {a}, and nobody else can.",
    q: "What does this tell you for sure about having {c}?",
  },
  es: {
    onlyif: "Podés {a} solo si tenés {c}.", if: "Cualquiera que tenga {c} puede {a}.", iff: "Podés {a} si, y solo si, tenés {c}.",
    neither: "Algunos que tienen {c} no pueden {a}, y algunos que no tienen {c} sí pueden.", contra: "Si no tenés {c}, no podés {a}.",
    nobody: "Nadie sin {c} puede {a}.", unless: "No podés {a} a menos que tengas {c}.", alltakes: "Con tener {c} alcanza para {a}.",
    whoever: "Quien tenga {c} puede {a}, y nadie más puede.",
    q: "¿Qué te dice seguro esto sobre tener {c}?",
  },
};
export const NS_ANSWER: Record<string, string> = { onlyif: "need", contra: "need", nobody: "need", unless: "need", if: "enough", alltakes: "enough", iff: "both", whoever: "both", neither: "neither" };
const NS_TIERS = [["onlyif", "if"], ["iff", "neither", "contra"], ["unless", "nobody", "alltakes", "whoever"]];
defGen({
  id: "necsuf", sec: "EXI", a: 1.3, k: 4, minMs: 2500, maxMs: 70000,
  make(d, r, ctx) {
    const form = r.pick(NS_TIERS[tierOf(d)]);
    const [a, c] = r.pick(NECSUF_DOMAINS[ctx.lang]);
    const F = NS_FORMS[ctx.lang];
    const options = ["need", "enough", "both", "neither"];
    return mkItem(this, d, {
      display: { rule: F[form].replaceAll("{a}", a).replaceAll("{c}", c), q: F.q.replace("{c}", c), options },
      key: { t: "idx", v: options.indexOf(NS_ANSWER[form]) }, meta: { form },
      why: {
        need: say(ctx.lang, `Without ${c} you can't, so ${c} is needed. But the rule never says that ${c} on its own is enough.`, `Sin ${c} no se puede, así que ${c} es necesario. Pero la regla nunca dice que ${c} solo alcance.`),
        enough: say(ctx.lang, `Having ${c} is enough. But the rule doesn't say it's the only way, so it isn't necessarily needed.`, `Tener ${c} alcanza. Pero la regla no dice que sea la única forma, así que no es necesariamente necesario.`),
        both: say(ctx.lang, `Having ${c} is enough, and nobody without it can: it is needed and enough.`, `Tener ${c} alcanza, y nadie sin eso puede: es necesario y suficiente.`),
        neither: say(ctx.lang, `Some people with ${c} can't and some without it can, so it is neither needed nor enough.`, `Algunos con ${c} no pueden y algunos sin eso sí, así que no es ni necesario ni suficiente.`),
      }[NS_ANSWER[form]],
    });
  },
});

/* ---------------- assume / contradict: hand-written banks (4 options) ---------------- */
defGen({
  id: "assume", sec: "EXI", a: 1.3, k: 4, minMs: 2500, maxMs: 70000,
  make(d, r, ctx) {
    const [arg, ans, wrong] = pickFrom(this, ASSUME, d, r, ctx);
    const options = r.shuffle([ans, ...wrong]);
    const why = say(ctx.lang, `The argument only works if “${ans}” is true, and it never says so: that is the hidden step. The other options may be true, but the argument doesn't depend on them.`, `El argumento solo funciona si “${ans}” es verdad, y nunca lo dice: ese es el paso escondido. Las otras opciones pueden ser ciertas, pero el argumento no depende de ellas.`);
    return mkItem(this, d, { display: { argument: arg, options }, key: { t: "idx", v: options.indexOf(ans) }, meta: { ans }, why });
  },
});
defGen({
  id: "contradict", sec: "EXI", a: 1.2, k: 4, minMs: 2000, maxMs: 60000,
  make(d, r, ctx) {
    const [ans, wrong] = pickFrom(this, CONTRA, d, r, ctx);
    const options = r.shuffle([ans, ...wrong]);
    const why = say(ctx.lang, `“${ans}” undoes itself: one part of it rules out the other. Each of the other three can be true as it stands.`, `“${ans}” se contradice: una parte anula a la otra. Cada una de las otras tres puede ser cierta tal como está.`);
    return mkItem(this, d, { display: { options }, key: { t: "idx", v: options.indexOf(ans) }, meta: { ans }, why });
  },
});

/* ---------------- crt: think twice (typed) ----------------
   Questions with a quick wrong answer; new numbers every time. meta = template + params. */
const ORD_EN = (k: number) => k + (k % 10 === 1 && k !== 11 ? "st" : k % 10 === 2 && k !== 12 ? "nd" : k % 10 === 3 && k !== 13 ? "rd" : "th");
export const CRT: { id: string; tier: number; make: (r: Rng) => { p: number[] } ; text: Record<Lang, (p: number[]) => string>; ans: (p: number[]) => number }[] = [
  { id: "sheep", tier: 0, make: (r) => ({ p: [r.int(12, 20), r.int(3, 9)] }),
    text: { en: ([n, k]) => `A farmer has ${n} sheep. All but ${k} run away. How many sheep are left?`, es: ([n, k]) => `Un granjero tiene ${n} ovejas. Se escapan todas menos ${k}. ¿Cuántas ovejas le quedan?` },
    ans: ([, k]) => k },
  { id: "race", tier: 0, make: (r) => ({ p: [r.int(2, 9)] }),
    text: { en: ([k]) => `In a race, you overtake the runner in ${ORD_EN(k)} place. What place are you in now?`, es: ([k]) => `En una carrera pasás al corredor que va en el puesto ${k}. ¿En qué puesto quedás vos?` },
    ans: ([k]) => k },
  { id: "eggs", tier: 0, make: (r) => ({ p: [r.int(4, 9), r.int(3, 6)] }),
    text: { en: ([m, k]) => `It takes ${m} minutes to boil one egg. How many minutes does it take to boil ${k} eggs together in one big pot?`, es: ([m, k]) => `Hervir un huevo lleva ${m} minutos. ¿Cuántos minutos lleva hervir ${k} huevos juntos en una olla grande?` },
    ans: ([m]) => m },
  { id: "widgets", tier: 1, make: (r) => ({ p: [r.int(3, 8), r.int(3, 9), r.pick([50, 100, 200])] }),
    text: { en: ([n, m, k]) => `If ${n} machines take ${m} minutes to make ${n} toys, how many minutes would ${k} machines take to make ${k} toys?`, es: ([n, m, k]) => `Si ${n} máquinas tardan ${m} minutos en hacer ${n} juguetes, ¿cuántos minutos tardarían ${k} máquinas en hacer ${k} juguetes?` },
    ans: ([, m]) => m },
  { id: "lilies", tier: 1, make: (r) => ({ p: [r.int(20, 60)] }),
    text: { en: ([n]) => `A patch of water lilies doubles in size every day. It takes ${n} days to cover the whole pond. How many days does it take to cover half the pond?`, es: ([n]) => `Una mancha de camalotes duplica su tamaño cada día. Tarda ${n} días en cubrir toda la laguna. ¿Cuántos días tarda en cubrir la mitad?` },
    ans: ([n]) => n - 1 },
  { id: "cuts", tier: 1, make: (r) => ({ p: [r.int(5, 12)] }),
    text: { en: ([n]) => `You cut a straight rope into ${n} pieces. How many cuts do you make?`, es: ([n]) => `Cortás una soga recta en ${n} pedazos. ¿Cuántos cortes hacés?` },
    ans: ([n]) => n - 1 },
  { id: "batball", tier: 2, make: (r) => ({ p: [r.int(0, 2), r.int(10, 20) * 10, r.int(2, 9) * 5] }),
    text: {
      en: ([w, dd, y]) => { const [a, b] = [["bat", "ball"], ["book", "pencil"], ["pizza", "drink"]][w]; return `A ${a} and a ${b} cost ${dd + 2 * y} cents in total. The ${a} costs ${dd} cents more than the ${b}. How many cents does the ${b} cost?`; },
      es: ([w, dd, y]) => { const [a, b] = [["un bate", "la pelota"], ["un libro", "el lápiz"], ["una pizza", "la bebida"]][w]; const [a2, b2] = [["una pelota", "El bate"], ["un lápiz", "El libro"], ["una bebida", "La pizza"]][w]; return `${a[0].toUpperCase() + a.slice(1)} y ${a2} cuestan ${dd + 2 * y} centavos en total. ${b2} cuesta ${dd} centavos más que ${b}. ¿Cuántos centavos cuesta ${b}?`; },
    },
    ans: ([, , y]) => y },
  { id: "fence", tier: 2, make: (r) => { const s = r.pick([2, 3, 4, 5]); return { p: [s * r.int(5, 12), s] }; },
    text: { en: ([l, s]) => `A straight fence is ${l} metres long, with a post every ${s} metres, including one at each end. How many posts are there?`, es: ([l, s]) => `Un alambrado recto mide ${l} metros y tiene un poste cada ${s} metros, incluido uno en cada punta. ¿Cuántos postes hay?` },
    ans: ([l, s]) => l / s + 1 },
  { id: "socks", tier: 2, make: (r) => ({ p: [r.int(6, 20), r.int(6, 20)] }),
    text: { en: ([b, w]) => `A drawer has ${b} black socks and ${w} white socks, all mixed up. In the dark, how many socks must you take out to be sure of a matching pair?`, es: ([b, w]) => `En un cajón hay ${b} medias negras y ${w} blancas, todas mezcladas. A oscuras, ¿cuántas medias tenés que sacar para estar seguro de tener un par del mismo color?` },
    ans: () => 3 },
];
/** Why the quick answer is wrong and the slow one is right, per CRT template. */
function crtWhy(id: string, p: number[], ans: number, lang: Lang): string {
  switch (id) {
    case "sheep": return say(lang, `“All but ${p[1]} run away” means ${p[1]} stay behind.`, `“Se escapan todas menos ${p[1]}” quiere decir que quedan ${p[1]}.`);
    case "race": return say(lang, `Passing the runner in ${ORD_EN(p[0])} place puts you in their place: ${ORD_EN(p[0])}, not ${ORD_EN(p[0] - 1)}.`, `Al pasar al que va en el puesto ${p[0]}, quedás en su lugar: el ${p[0]}, no el ${p[0] - 1}.`);
    case "eggs": return say(lang, `The eggs boil at the same time, so it still takes ${p[0]} minutes.`, `Los huevos se hierven al mismo tiempo, así que sigue llevando ${p[0]} minutos.`);
    case "widgets": return say(lang, `Each machine makes one toy in ${p[1]} minutes, so ${p[2]} machines make ${p[2]} toys in the same ${p[1]} minutes.`, `Cada máquina hace un juguete en ${p[1]} minutos, así que ${p[2]} máquinas hacen ${p[2]} juguetes en los mismos ${p[1]} minutos.`);
    case "lilies": return say(lang, `It doubles every day, so one day before it covers the pond it covers half of it: ${p[0]} − 1 = ${ans}.`, `Se duplica cada día, así que un día antes de cubrir la laguna cubre la mitad: ${p[0]} − 1 = ${ans}.`);
    case "cuts": return say(lang, `Each cut adds one piece, and you start with one: ${p[0]} pieces need ${ans} cuts.`, `Cada corte suma un pedazo, y empezás con uno: ${p[0]} pedazos necesitan ${ans} cortes.`);
    case "batball": { const total = p[1] + 2 * p[2];
      return say(lang, `If the cheaper one costs x, the other costs x + ${p[1]}. Together: 2x + ${p[1]} = ${total}, so x = ${ans} (not ${total - p[1]}: then the difference would only be ${total - 2 * (total - p[1])}).`, `Si el más barato cuesta x, el otro cuesta x + ${p[1]}. Juntos: 2x + ${p[1]} = ${total}, así que x = ${ans} (no ${total - p[1]}: así la diferencia sería solo ${total - 2 * (total - p[1])}).`); }
    case "fence": return say(lang, `${p[0]} ÷ ${p[1]} = ${p[0] / p[1]} gaps between posts, and a straight fence has one more post than gaps: ${ans}.`, `${p[0]} ÷ ${p[1]} = ${p[0] / p[1]} espacios entre postes, y un alambrado recto tiene un poste más que espacios: ${ans}.`);
    case "socks": return say(lang, "There are only two colours, so among any 3 socks two must be the same colour. The numbers of socks don't matter.", "Hay solo dos colores, así que entre 3 medias cualesquiera dos tienen que ser del mismo color. La cantidad de medias no importa.");
  }
  return "";
}
defGen({
  id: "crt", sec: "EXI", a: 1.3, k: 0, minMs: 2500, maxMs: 70000,
  make(d, r, ctx) {
    const pool = CRT.filter((c) => c.tier === tierOf(d));
    const fresh = pool.filter((c) => !ctx.used.has("crt:" + c.id));
    const c = r.pick(fresh.length ? fresh : pool);
    ctx.used.add("crt:" + c.id);
    const { p } = c.make(r);
    return mkItem(this, d, { display: { text: c.text[ctx.lang](p) }, key: { t: "num", v: c.ans(p) }, meta: { id: c.id, p }, why: crtWhy(c.id, p, c.ans(p), ctx.lang) });
  },
});
