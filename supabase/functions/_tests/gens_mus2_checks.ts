// Uniqueness checks for the second MUS set (gens/mus2.ts), merged into gens_test.ts's
// CHECKS. Each re-derives the answer from the notes / times that will actually play.
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkAnswer, type Item } from "../_shared/gens/index.ts";

function oneIndex(it: Item, nOpts: number, expected: number) {
  const ok = Array.from({ length: nOpts }, (_, i) => i).filter((i) => checkAnswer(it.key, i));
  assertEquals(ok, [expected], `${it.gid} d${it.d}: correct options ${ok}, expected [${expected}]`);
}
const signs = (xs: number[]) => xs.slice(1).map((x, i) => Math.sign(x - xs[i])).join(",");
const rough = (chord: number[]) => chord.some((a, i) => chord.some((b, j) => j > i && [1, 2, 6, 10, 11].includes(((b - a) % 12 + 12) % 12)));

export const CHECKS_MUS2: Record<string, (it: Item) => void> = {
  rhythm(it) {
    const { a, b } = it.display as any;
    assertEquals(a.length, b.length);
    for (const x of [a, b]) assertEquals(new Set(x).size, x.length, "rhythm: two onsets at once");
    oneIndex(it, 2, a.join() === b.join() ? 0 : 1);
  },
  transpose(it) {
    const { notes1: a, notes2: b } = it.display as any;
    const shifts = a.map((x: number, i: number) => b[i] - x);
    const same = shifts.every((s: number) => s === shifts[0]);
    assert(shifts[0] !== 0 && shifts[0] % 12 !== 0, "transpose: not moved to a new key");
    if (!same) assertEquals(shifts.filter((s: number) => s !== shifts[0]).length, 1, "transpose: more than one note changed");
    oneIndex(it, 2, same ? 0 : 1);
  },
  beat(it) {
    const { offset } = it.display as any;
    if (offset !== 0) assert(Math.abs(offset) >= 0.025, "beat: offset too small to hear");
    oneIndex(it, 2, offset === 0 ? 0 : 1);
  },
  contour(it) {
    const { notes, options } = it.display as any;
    assert(!signs(notes).includes("0"), "contour: repeated note");
    const match = options.map((o: number[]) => signs(o) === signs(notes));
    assertEquals(match.filter(Boolean).length, 1, "contour: not exactly one matching line");
    assertEquals(new Set(options.map(signs)).size, 4);
    oneIndex(it, 4, match.indexOf(true));
  },
  cadence(it) {
    const { chord, a, b } = it.display as any;
    assertEquals(a.length, b.length);
    assertEquals(a.slice(0, -1).join(), b.slice(0, -1).join(), "cadence: phrases differ before the last note");
    const home = (n: number) => ((n - chord[0]) % 12 + 12) % 12 === 0;
    const ends = [home(a[a.length - 1]), home(b[b.length - 1])];
    assertEquals(ends.filter(Boolean).length, 1, "cadence: not exactly one phrase ends on the key note");
    oneIndex(it, 2, ends.indexOf(true));
  },
  consonance(it) {
    const { chord1, chord2 } = it.display as any;
    const smooth = [!rough(chord1), !rough(chord2)];
    assertEquals(smooth.filter(Boolean).length, 1, "consonance: not exactly one smooth chord");
    oneIndex(it, 2, smooth.indexOf(true));
  },
};
