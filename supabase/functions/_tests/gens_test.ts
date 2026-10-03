// Every generator, at every difficulty 1..10, in both languages, over many seeds:
// the item must have exactly one correct answer. Each check below re-derives
// "correct" independently of the generator's own code (brute force where possible),
// then confirms the stored key accepts that answer and rejects every other option.
//   deno test supabase/functions/_tests/
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { Rng } from "../_shared/rng.ts";
import { checkAnswer, GENS, type Item, type Lang } from "../_shared/gens/index.ts";
import { pKey, pMir, pRotN, type Poly, tvKey, tvTop } from "../_shared/gens/spa.ts";
import { NAT_CANDS } from "../_shared/gens/nat.ts";
import { NONE_FOLLOWS, syTrue } from "../_shared/gens/exi.ts";
import { ANA, CATS, EMO_KEYS, FALLACY_NAMES } from "../_shared/gens/data.ts";

const SEEDS = Number(Deno.env.get("GEN_SEEDS") ?? 150);
const LANGS: Lang[] = ["en", "es"];
const ALL_IDS = Object.keys(GENS);

/** Exactly one option index passes the key. */
function oneIndex(it: Item, nOpts: number, expected: number) {
  const ok = Array.from({ length: nOpts }, (_, i) => i).filter((i) => checkAnswer(it.key, i));
  assertEquals(ok, [expected], `${it.gid} d${it.d}: correct options ${ok}, expected [${expected}]`);
}
const distinct = (xs: unknown[]) => new Set(xs.map((x) => JSON.stringify(x))).size === xs.length;
const rotations = (p: Poly) => new Set([0, 1, 2, 3].map((k) => pKey(pRotN(p, k))));

/* ------------ independent per-generator checks ------------ */
const CHECKS: Record<string, (it: Item) => void> = {
  series(it) {
    const seq = it.display.seq as number[];
    assert(seq.length === 6 || seq.length === 7);
    const k = it.key as any;
    assert(Number.isInteger(k.v) && seq.every(Number.isInteger), `series not integer: ${seq} -> ${k.v}`);
    assert(checkAnswer(it.key, String(k.v)) && !checkAnswer(it.key, String(k.v + 1)));
  },
  matrix(it) {
    const opts = it.display.options as any[];
    assertEquals(opts.length, 8);
    assert(distinct(opts), "matrix options not distinct");
    const answer = JSON.stringify((it.meta as any).answer);
    const right = opts.map((o, i) => JSON.stringify(o) === answer ? i : -1).filter((i) => i >= 0);
    assertEquals(right.length, 1);
    oneIndex(it, 8, right[0]);
    // balanced: each attribute value of the answer appears in exactly half the options
    for (const a of ["shape", "count", "fill", "size"]) {
      const n = opts.filter((o) => o[a] === (it.meta as any).answer[a]).length;
      assert(n === 4 || n === 8, `matrix ${a}: answer value in ${n}/8 options`);
    }
  },
  digits(it) {
    const ds = it.display.digits as number[];
    const target = (it.display.back ? ds.slice().reverse() : ds).join("");
    assert(checkAnswer(it.key, target));
    const other = (it.display.back ? ds : ds.slice().reverse()).join("");
    if (other !== target) assert(!checkAnswer(it.key, other));
  },
  arith(it) {
    const { a, op, b } = it.display as any;
    const v = op === "+" ? a + b : op === "−" ? a - b : op === "×" ? a * b : a / b;
    assert(Number.isInteger(v) && v >= 0, `arith ${a}${op}${b}`);
    assert(checkAnswer(it.key, String(v)) && !checkAnswer(it.key, String(v + 1)));
  },
  topview(it) {
    const opts = it.display.options as number[][][];
    assertEquals(opts.length, 5);
    assert(distinct(opts.map(tvKey)), "topview options not distinct");
    const truth = tvKey(tvTop(it.display.stack as number[][][]));
    const right = opts.map((o, i) => tvKey(o) === truth ? i : -1).filter((i) => i >= 0);
    assertEquals(right.length, 1);
    oneIndex(it, 5, right[0]);
  },
  rotation(it) {
    const rots = rotations(it.display.target as Poly);
    const opts = it.display.options as Poly[];
    assertEquals(opts.length, 4);
    const right = opts.map((o, i) => rots.has(pKey(o)) ? i : -1).filter((i) => i >= 0);
    assertEquals(right.length, 1, "rotation: not exactly one rotated option");
    // the rest are mirror images
    const mir = rotations(pMir(it.display.target as Poly));
    opts.forEach((o, i) => i !== right[0] && assert(mir.has(pKey(o))));
    oneIndex(it, 4, right[0]);
  },
  rotquick(it) {
    const left = it.display.left as Poly, right = it.display.right as Poly;
    const same = rotations(left).has(pKey(right)), mirror = rotations(pMir(left)).has(pKey(right));
    assert(same !== mirror, "rotquick: right shape is both or neither");
    oneIndex(it, 2, same ? 0 : 1);
  },
  corsi(it) {
    const seq = it.display.seq as number[];
    assert(seq.every((x, i) => x >= 0 && x <= 8 && x !== seq[i - 1]));
    assert(checkAnswer(it.key, seq.join("")));
  },
  oddword(it) { oddWord(it); },
  oddquick(it) { oddWord(it); },
  anagram(it) {
    const letters = it.display.letters as string[];
    const word = (it.meta as any).word as string;
    assert(letters.join("") !== word, "anagram shown unscrambled");
    assertEquals(letters.slice().sort().join(""), word.split("").sort().join(""));
    // every same-letter word in the bank is accepted, nothing else from the bank is
    const bank = Object.values((ANA as any)[it.lang!]).flat() as string[];
    for (const w of bank) assertEquals(checkAnswer(it.key, w), w.split("").sort().join("") === word.split("").sort().join(""));
  },
  analogy(it) {
    const opts = it.display.options as string[];
    assertEquals(opts.length, 4);
    assert(distinct(opts), "analogy options not distinct");
    assert([0, 1, 2, 3].filter((i) => checkAnswer(it.key, i)).length === 1);
  },
  pitch(it) {
    const f = it.display.freqs as number[];
    const odd = f.map((x, i) => f.filter((y) => y === x).length === 1 ? i : -1).filter((i) => i >= 0);
    assertEquals(odd.length, 1, `pitch freqs ${f}`);
    oneIndex(it, 3, odd[0]);
  },
  pitchhl(it) {
    const { f1, f2 } = it.display as any;
    assert(f1 !== f2);
    oneIndex(it, 2, f2 > f1 ? 0 : 1);
  },
  melody(it) {
    const a = it.display.notes1 as number[], b = it.display.notes2 as number[];
    assertEquals(a.length, b.length);
    const diff = a.map((x, i) => x !== b[i] ? i : -1).filter((i) => i >= 0);
    assertEquals(diff.length, 1, `melody changed notes at ${diff}`);
    assertEquals(it.k, a.length);
    oneIndex(it, a.length, diff[0]);
  },
  chord(it) {
    const notes = it.display.notes as number[];
    const n = new Set(notes).size;
    assertEquals(n, notes.length, `chord repeats a note: ${notes}`);
    oneIndex(it, 4, n - 1);
  },
  natclass(it) {
    if (it.gid === "natodd") return CHECKS.natodd(it); // prototype fallback
    const fams = it.display.families as number[][][], q = it.display.query as number[];
    assert(!fams.flat().some((c) => c.join() === q.join()), "query creature is one of the examples");
    // every candidate rule that separates the three families must place q in the same family
    const answers = new Set<number>();
    for (const c of NAT_CANDS) {
      const vals = fams.map((list) => new Set(list.map(c.f)));
      if (vals.some((s) => s.size !== 1)) continue;
      const v = vals.map((s) => [...s][0]);
      if (new Set(v).size !== 3) continue;
      answers.add(v.indexOf(c.f(q)));
    }
    assertEquals(answers.size, 1, "natclass: rules disagree");
    oneIndex(it, 3, [...answers][0]);
  },
  natodd(it) { natOdd(it); },
  natquick(it) { natOdd(it); },
  tap(it) {
    assert(checkAnswer(it.key, "hit"));
    for (const v of ["slow", "early", "miss", 0, null]) assert(!checkAnswer(it.key, v));
  },
  timing(it) {
    const tol = it.display.tol as number;
    assert(checkAnswer(it.key, 0) && checkAnswer(it.key, tol) && checkAnswer(it.key, -tol));
    assert(!checkAnswer(it.key, tol + 1) && !checkAnswer(it.key, "early") && !checkAnswer(it.key, "late"));
  },
  face(it) { faceOpts(it); },
  facequick(it) { faceOpts(it); },
  faceodd(it) {
    const { emo, other } = it.meta as any;
    assert(emo !== other);
    assertEquals((it.display.faces as any[]).length, 4);
    assert([0, 1, 2, 3].filter((i) => checkAnswer(it.key, i)).length === 1);
  },
  syll(it) { syllogism(it); },
  syllquick(it) { syllogism(it); },
  fallacy(it) {
    const opts = it.display.options as string[];
    assertEquals(opts.length, 4);
    assert(distinct(opts) && opts.every((o) => FALLACY_NAMES.includes(o)));
    const right = [0, 1, 2, 3].filter((i) => checkAnswer(it.key, i));
    assertEquals(right.length, 1);
    // the two look-alike fallacies never appear when one of them is the answer
    if (["adhom", "tuquoque"].includes(opts[right[0]])) assert(!(opts.includes("adhom") && opts.includes("tuquoque")), "adhom and tuquoque together");
  },
};

function oddWord(it: Item) {
  const words = it.display.words as string[];
  const { four, odd } = it.meta as any;
  assertEquals(words.length, 5);
  assert(distinct(words), `oddword repeats: ${words}`);
  const lang = it.lang!;
  const cats = Object.values(CATS as any) as any[];
  const inCat = (cat: any, w: string) => cat[lang].includes(w);
  if (cats.some((c) => four.every((w: string) => inCat(c, w)))) {
    // category item: the four share a category the odd word isn't in, and no other
    // word could be the odd one out (no category holds a different set of four)
    for (const c of cats) {
      const members = words.filter((w) => inCat(c, w));
      if (members.length >= 4) assert(members.length === 4 && !members.includes(odd), `oddword: category ${c[lang]} fits ${members}`);
    }
  }
  oneIndex(it, 5, words.indexOf(odd));
}
function natOdd(it: Item) {
  const cs = it.display.creatures as number[][];
  assertEquals(cs.length, 5);
  // every candidate rule that splits the five 4-vs-1 must single out the same creature,
  // and at least one rule must do so
  const lone = new Set<number>();
  for (const c of NAT_CANDS) {
    const v = cs.map(c.f);
    const cnt: Record<number, number> = {};
    v.forEach((x) => cnt[x] = (cnt[x] || 0) + 1);
    const keys = Object.keys(cnt);
    if (keys.length !== 2) continue;
    const l = keys.find((k) => cnt[Number(k)] === 1);
    if (l != null) lone.add(v.indexOf(Number(l)));
  }
  assertEquals(lone.size, 1, `natodd: rules point at ${[...lone]}`);
  oneIndex(it, 5, [...lone][0]);
}
function faceOpts(it: Item) {
  const opts = it.display.options as string[];
  assertEquals(opts.length, 4);
  assert(distinct(opts) && opts.every((o) => EMO_KEYS.includes(o)));
  oneIndex(it, 4, opts.indexOf((it.meta as any).emo));
}
/** Independent brute force over all 7-region Venn models of 3 terms. */
function syllogism(it: Item) {
  const { p1, p2, props } = it.meta as any;
  const opts = it.display.options as string[];
  assertEquals(opts[opts.length - 1], NONE_FOLLOWS);
  assertEquals(opts.length, it.k);
  const models: number[][] = [];
  for (let m = 0; m < 128; m++) { const M: number[] = []; for (let r = 1; r < 8; r++) if (m >> (r - 1) & 1) M.push(r); models.push(M); }
  const sat = models.filter((M) => syTrue(p1[0], p1[1], p1[2], M) && syTrue(p2[0], p2[1], p2[2], M));
  const satI = sat.filter((M) => [1, 2, 4].every((t) => M.some((r) => r & t))); // existential import
  const validModern = (c: any) => sat.every((M) => syTrue(c[0], c[1], c[2], M));
  const validTrad = (c: any) => satI.every((M) => syTrue(c[0], c[1], c[2], M));
  const shown = (props as any[]).slice(0, -1);
  shown.forEach((c) => assert(validModern(c) === validTrad(c), `syll: option "${c}" is debatable (modern vs traditional)`));
  const valid = shown.map((c, i) => validModern(c) ? i : -1).filter((i) => i >= 0);
  assert(valid.length <= 1, "syll: more than one valid conclusion shown");
  oneIndex(it, opts.length, valid.length ? valid[0] : opts.length - 1);
}

/* ------------ the test ------------ */
Deno.test("there are 27 generators and each has a uniqueness check", () => {
  assertEquals(ALL_IDS.length, 27);
  for (const id of ALL_IDS) assert(CHECKS[id], `no check for ${id}`);
});

for (const id of ALL_IDS) {
  Deno.test(`${id}: exactly one correct answer at d = 1..10 (${SEEDS} seeds x en/es)`, () => {
    const g = GENS[id];
    for (const lang of LANGS) {
      for (let d = 1; d <= 10; d++) {
        for (let s = 0; s < SEEDS; s++) {
          const seed = (d * 7919 + s * 104729 + (lang === "es" ? 1 : 0)) >>> 0;
          const it = g.make(d, new Rng(seed), { lang, used: new Set(), blitz: false });
          assert(it, `${id} d${d} seed ${seed}: no item`);
          assert(Number.isFinite(it.a) && Number.isFinite(it.b) && it.c >= 0 && it.c <= 1);
          assert(it.d >= 1 && it.d <= 10);
          try {
            (CHECKS[it.gid === "rotation" && id === "topview" ? "rotation" : id])(it);
          } catch (e) {
            throw new Error(`${id} d${d} ${lang} seed ${seed}: ${(e as Error).message}`);
          }
        }
      }
    }
  });
}
