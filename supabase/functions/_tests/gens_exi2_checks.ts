// Checks for the second EXI set (gens/exi2.ts), merged into gens_test.ts's CHECKS, plus a
// test of the hand-written banks. Wason and needed-or-enough are re-derived by reading
// the rule text the player sees; think-twice answers are recomputed from scratch.
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkAnswer, type Item } from "../_shared/gens/index.ts";
import { ASSUME, CONTRA, DEONTIC } from "../_shared/gens/exi2_data.ts";

function oneIndex(it: Item, nOpts: number, expected: number) {
  const ok = Array.from({ length: nOpts }, (_, i) => i).filter((i) => checkAnswer(it.key, i));
  assertEquals(ok, [expected], `${it.gid} d${it.d}: correct options ${ok}, expected [${expected}]`);
}
function options4(it: Item) {
  const o = it.display.options as string[];
  assertEquals(o.length, 4);
  assertEquals(new Set(o).size, 4);
  oneIndex(it, 4, o.indexOf((it.meta as any).ans));
}
const CAT: Record<string, string> = {
  "a vowel": "vowel", "a consonant": "consonant", "an even number": "even", "an odd number": "odd",
  "una vocal": "vowel", "una consonante": "consonant", "un número par": "even", "un número impar": "odd",
};
const fits = (cat: string, v: string) =>
  cat === "vowel" ? "AEIOU".includes(v) : cat === "consonant" ? /^[A-Z]$/.test(v) && !"AEIOU".includes(v) : cat === "even" ? /^\d+$/.test(v) && Number(v) % 2 === 0 : /^\d+$/.test(v) && Number(v) % 2 === 1;

export const CHECKS_EXI2: Record<string, (it: Item) => void> = {
  wason(it) {
    const { rule, cards } = it.display as any;
    let must: boolean[];
    const people = [...DEONTIC.en, ...DEONTIC.es].find((x) => x[0] === rule);
    if (people) {
      const [, , pt, pf, qt, qf] = people;
      assertEquals([...cards].sort().join("|"), [pt, pf, qt, qf].sort().join("|"));
      must = cards.map((c: string) => c === pt || c === qf);
    } else {
      const cats = Object.keys(CAT).sort((a, b) => b.length - a.length);
      const found = (s: string) => cats.find((c) => s.includes(c))!;
      const m = rule.match(/^(?:If a card has|Si una carta tiene|A card has|Una carta tiene) (.+?) (?:on one side|de un lado)(.*)$/);
      assert(m, `wason: can't read "${rule}"`);
      const p = CAT[found(m![1])], rest = m![2];
      const neg = /does not have|no tiene/.test(rest);
      const q0 = CAT[found(rest)];
      const q = neg ? ({ even: "odd", odd: "even", vowel: "consonant", consonant: "vowel" } as any)[q0] : q0;
      // a card can break "P -> Q" only if it shows P (P's side up), or shows not-Q (Q's side up)
      const pLetters = ["vowel", "consonant"].includes(p);
      assert(pLetters !== ["vowel", "consonant"].includes(q), "wason: P and Q on the same side");
      must = cards.map((c: string) => (/^[A-Z]$/.test(c) === pLetters ? fits(p, c) : !fits(q, c)));
    }
    const ans = must.map((t, i) => (t ? i : -1)).filter((i) => i >= 0).join(",");
    assert(ans.length > 0);
    assert(checkAnswer(it.key, ans), `wason: key ${JSON.stringify(it.key)} vs ${ans} for "${rule}" ${cards}`);
    assert(!checkAnswer(it.key, ans + ",9") && !checkAnswer(it.key, cards.map((_: any, i: number) => i).join(",")));
  },
  necsuf(it) {
    const { rule, options } = it.display as any;
    const s = rule as string;
    const kind = /if, and only if|si, y solo si|and nobody else|y nadie más/.test(s) ? "both"
      : /^Some people|^Algunos que/.test(s) ? "neither"
      : /only if|solo si|don't have .*can't|^Si no tenés|^Nobody without|^Nadie sin|unless|a menos que/.test(s) ? "need"
      : /^Anyone who has|^Cualquiera que|all it takes|alcanza para/.test(s) ? "enough" : "?";
    assert(kind !== "?", `necsuf: can't read "${s}"`);
    oneIndex(it, 4, options.indexOf(kind));
  },
  assume(it) { options4(it); },
  contradict(it) { options4(it); },
  crt(it) {
    const { id, p } = it.meta as any;
    const want: Record<string, number> = {
      sheep: p[1], race: p[0], eggs: p[0], widgets: p[1], lilies: p[0] - 1, cuts: p[0] - 1, batball: p[2], fence: p[0] / p[1] + 1, socks: 3,
    };
    const v = want[id];
    assert(Number.isInteger(v) && v > 0, `crt ${id}: ${v}`);
    assert(checkAnswer(it.key, String(v)) && !checkAnswer(it.key, String(v + 1)));
    for (const x of p) if (id !== "batball") assert(String(it.display.text).includes(String(x)), `crt ${id}: ${x} not in the text`);
  },
};

Deno.test("EXI banks: 5+ per tier, the answer never among the wrong options", () => {
  for (const [name, bank] of Object.entries({ ASSUME, CONTRA }) as [string, any][]) {
    for (const lang of ["en", "es"]) {
      bank[lang].forEach((tier: any[], t: number) => {
        assert(tier.length >= 5, `${name} ${lang} tier ${t}`);
        for (const item of tier) {
          const ans = name === "ASSUME" ? item[1] : item[0], wrong = name === "ASSUME" ? item[2] : item[1];
          assertEquals(wrong.length, 3);
          assert(!wrong.includes(ans) && new Set(wrong).size === 3, `${name} ${lang}: ${ans}`);
        }
      });
    }
  }
});
