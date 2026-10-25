// Checks for the second Self set (gens/self2.ts), merged into gens_test.ts's CHECKS, plus a
// test of the word bank. recall has no single right answer: the key must score a guess
// against what was recalled (perfect recall with guess n is "right", any other guess isn't).
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkAnswer, type Item, recallScore } from "../_shared/gens/index.ts";
import { RECALL_WORDS } from "../_shared/gens/self2.ts";

export const CHECKS_SELF2: Record<string, (it: Item) => void> = {
  recall(it) {
    const { pairs, order, options, studyMs } = it.display as any;
    const n = pairs.length;
    assertEquals(n, it.d <= 3 ? 3 : it.d <= 6 ? 4 : it.d <= 9 ? 5 : 6);
    assertEquals(studyMs, 1000 + 1500 * n);
    const words = pairs.flat();
    assertEquals(new Set(words).size, 2 * n, `recall repeats a word: ${words}`);
    assert(words.every((w: string) => RECALL_WORDS[it.lang!].includes(w)));
    assertEquals([...order].sort().join(), pairs.map((_: any, i: number) => i).join());
    assertEquals(options.length, n + 2);
    assertEquals(new Set(options).size, n + 2);
    // the two extra options were not studied
    assertEquals(options.filter((o: string) => !words.includes(o)).length, 2);
    // independent answer: question i asks for the partner of pairs[order[i]][0]
    const truth = order.map((p: number) => options.indexOf(pairs[p][1]));
    assert(truth.every((x: number) => x >= 0));
    const wrong = truth.map((x: number) => (x + 1) % options.length);
    assertEquals(recallScore(it.key, { g: n, picks: truth }), { g: n, s: n, n });
    assertEquals(recallScore(it.key, { g: 0, picks: wrong })?.s, 0);
    assert(checkAnswer(it.key, { g: n, picks: truth }) && checkAnswer(it.key, { g: 0, picks: wrong }));
    assert(!checkAnswer(it.key, { g: n - 1, picks: truth }) && !checkAnswer(it.key, { g: 1, picks: wrong }));
    // malformed answers are never scored
    for (const v of [null, "x", 0, { g: n + 1, picks: truth }, { g: n, picks: truth.slice(1) }, { g: 1.5, picks: truth }, { picks: truth }]) {
      assertEquals(recallScore(it.key, v), null);
    }
  },
};

Deno.test("recall word bank: EN and ES line up, no repeats, single words, enough for a long test", () => {
  for (const lang of ["en", "es"] as const) {
    const w = RECALL_WORDS[lang];
    assertEquals(w.length, RECALL_WORDS.en.length);
    assertEquals(new Set(w).size, w.length, `${lang} repeats a word`);
    assert(w.every((x) => /^[a-záéíóúñ]+$/.test(x)), `${lang}: not one plain word`);
  }
  assert(RECALL_WORDS.en.length >= 120);
});
