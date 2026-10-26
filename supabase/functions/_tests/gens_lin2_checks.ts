// Checks for the second LIN set (gens/lin2.ts), merged into gens_test.ts's CHECKS, plus
// a test of the hand-written banks themselves. The banks can't be re-derived by a
// program (meaning is a judgement), so these check shape: one answer among distinct
// options, the answer never repeated as a wrong option or as a clue word, and every
// accepted word order of an unscramble using exactly the tiles shown.
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkAnswer, type Item } from "../_shared/gens/index.ts";
import { CLOZE, INFER, PROVERB, RAT, SCRAMBLE, SYN } from "../_shared/gens/lin2_data.ts";

function oneIndex(it: Item, nOpts: number, expected: number) {
  const ok = Array.from({ length: nOpts }, (_, i) => i).filter((i) => checkAnswer(it.key, i));
  assertEquals(ok, [expected], `${it.gid} d${it.d}: correct options ${ok}, expected [${expected}]`);
}
function options4(it: Item) {
  const o = it.display.options as string[];
  assertEquals(o.length, 4);
  assertEquals(new Set(o.map((x) => x.toLowerCase())).size, 4, `${it.gid}: options not distinct ${o}`);
  const ans = (it.meta as any).ans;
  assertEquals(o.filter((x) => x === ans).length, 1);
  oneIndex(it, 4, o.indexOf(ans));
  return o;
}
const bag = (words: string[]) => words.slice().sort().join("|");

export const CHECKS_LIN2: Record<string, (it: Item) => void> = {
  remote(it) {
    const o = options4(it), w = it.display.words as string[];
    assertEquals(w.length, 3);
    assert(!o.some((x) => w.includes(x)), "remote: an option is one of the clue words");
  },
  synonym(it) {
    const o = options4(it);
    assert(!o.includes(it.display.word as string));
    assert(["same", "opp"].includes(it.display.kind as string));
  },
  cloze(it) {
    options4(it);
    assertEquals((it.display.sentence as string).split("___").length, 2, "cloze: needs exactly one gap");
  },
  proverb(it) { options4(it); },
  inference(it) { options4(it); assert(String(it.display.q).includes("?")); },
  unscramble(it) {
    const tiles = it.display.tiles as string[], ok = (it.key as any).v as string[];
    assert(ok.length >= 1);
    for (const s of ok) {
      assertEquals(bag(s.split(" ")), bag(tiles), `unscramble: "${s}" doesn't use exactly the tiles`);
      assert(checkAnswer(it.key, s));
    }
    assert(!ok.includes(tiles.join(" ")), "unscramble: tiles shown already in order");
    assert(!checkAnswer(it.key, tiles.join(" ")));
  },
};

Deno.test("LIN banks: 5+ items per tier, distinct items, the answer never among the wrong options", () => {
  const banks: Record<string, any> = { RAT, SYN, CLOZE, PROVERB, INFER, SCRAMBLE };
  for (const [name, bank] of Object.entries(banks)) {
    for (const lang of ["en", "es"]) {
      const seen = new Set<string>();
      bank[lang].forEach((tier: any[], t: number) => {
        assert(tier.length >= 5, `${name} ${lang} tier ${t}: only ${tier.length} items`);
        for (const item of tier) {
          const key = JSON.stringify(item);
          assert(!seen.has(key), `${name} ${lang}: duplicate ${key}`);
          seen.add(key);
          if (name === "SCRAMBLE") {
            const [s, alts] = item as [string, string[]];
            assert(/^[A-ZÁÉÍÓÚÑ]/.test(s) && /\.$/.test(s), `${name}: "${s}" needs a capital and a full stop`);
            for (const a of alts) assertEquals(bag(a.split(" ")), bag(s.split(" ")), `${name}: alt "${a}"`);
            continue;
          }
          const ans = name === "RAT" ? item[3] : name === "INFER" ? item[2] : item[1];
          const wrong: string[] = name === "RAT" ? item[4] : name === "INFER" ? item[3] : item[2];
          assertEquals(wrong.length, 3, `${name} ${lang} ${key}`);
          assert(!wrong.includes(ans), `${name} ${lang}: answer among wrong options in ${key}`);
          assertEquals(new Set(wrong).size, 3, `${name} ${lang}: repeated wrong option in ${key}`);
          if (name === "RAT") assert(!item.slice(0, 3).includes(ans));
          // each sentence-ending and read-between-the-lines item explains its answer (2026-10-25)
          if (name === "CLOZE" || name === "INFER") assert(typeof item[item.length - 1] === "string" && item[item.length - 1].length > 20, `${name} ${lang}: no why in ${key}`);
        }
      });
    }
  }
});
