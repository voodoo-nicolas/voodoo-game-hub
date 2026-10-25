// Uniqueness checks for the second NAT set (gens/nat2.ts), merged into gens_test.ts's
// CHECKS. Each re-derives the answer from what the player sees.
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkAnswer, type Item } from "../_shared/gens/index.ts";
import { webClear } from "../_shared/gens/nat2.ts";

function oneIndex(it: Item, nOpts: number, expected: number) {
  const ok = Array.from({ length: nOpts }, (_, i) => i).filter((i) => checkAnswer(it.key, i));
  assertEquals(ok, [expected], `${it.gid} d${it.d}: correct options ${ok}, expected [${expected}]`);
}
const N = [3, 3, 3, 3, 3, 2, 2];
const eq = (a: number[], b: number[]) => a.length === b.length && a.every((v, i) => v === b[i]);

export const CHECKS_NAT2: Record<string, (it: Item) => void> = {
  inherit(it) {
    const { families, parents: [q1, q2], options } = it.display as any;
    // per trait, every rule that fits all families: from parent 1, from parent 2, or always value v
    const baby: number[] = [];
    for (let t = 0; t < 7; t++) {
      const rules: ((a: number[], b: number[]) => number)[] = [(a) => a[t], (_a, b) => b[t]];
      for (let v = 0; v < N[t]; v++) rules.push(() => v);
      const fit = rules.filter((f) => families.every(([a, b, c]: number[][]) => f(a, b) === c[t]));
      const preds = new Set(fit.map((f) => f(q1, q2)));
      assertEquals(preds.size, 1, `inherit: trait ${t} could be ${[...preds]}`);
      baby.push([...preds][0]);
    }
    const hit = options.map((o: number[]) => eq(o, baby));
    assertEquals(hit.filter(Boolean).length, 1, "inherit: not exactly one baby fits");
    oneIndex(it, 4, hit.indexOf(true));
  },
  foodweb(it) {
    const { edges, text, options, nodes } = it.display as any;
    const { x, y } = it.meta as any;
    assert(nodes.some((n: any) => n.id === x) && nodes.some((n: any) => n.id === y));
    assert(text.includes("?"));
    assert(webClear(nodes, edges), "foodweb: an arrow runs behind another animal (or boxes overlap)");
    const eaters = (s: string) => edges.filter((e: string[]) => e[0] === s).map((e: string[]) => e[1]);
    const foods = (s: string) => edges.filter((e: string[]) => e[1] === s).map((e: string[]) => e[0]);
    let ans = "";
    if (foods(x).includes(y)) {
      assert(!eaters(y).some((e: string) => e !== x && foods(x).includes(e)), "foodweb: prey's other predator is also eaten");
      ans = "more";
    } else if (eaters(x).includes(y)) {
      assertEquals(foods(y).length, 1, "foodweb: removed food isn't the only food");
      ans = "fewer";
    } else {
      const mid = foods(x).filter((p: string) => eaters(p).length === 1 && foods(p).includes(y) && eaters(y).length === 1);
      assert(mid.length >= 1, `foodweb: no clear effect of ${x} on ${y}`);
      ans = "fewer";
    }
    oneIndex(it, 3, options.indexOf(ans));
  },
  idkey(it) {
    const { creature: x, couplets, options } = it.display as any;
    const test: Record<string, boolean> = {
      tail: x[6] === 1, ant: x[5] === 1, spots: x[2] === 1, stripes: x[2] === 2, plain: x[2] === 0, six: x[3] === 2, two: x[3] === 0,
      oneeye: x[4] === 0, threeeyes: x[4] === 2, round: x[0] === 0, tall: x[0] === 1, box: x[0] === 2, morelegs: x[3] > 0, moreeyes: x[4] > 0,
    };
    let at: any = 1, steps = 0;
    while (typeof at === "number") { const c = couplets[at - 1]; assert(c.t in test); at = test[c.t] ? c.y : c.n; assert(++steps < 10); }
    assertEquals(new Set(options).size, 4);
    oneIndex(it, 4, options.indexOf(at));
  },
  camo(it) {
    const { q, px, py, size } = it.display as any;
    for (const p of [px, py]) assert(p - size / 2 >= 0 && p + size / 2 <= 0.5, "camo: creature crosses into another quarter");
    oneIndex(it, 4, q);
  },
  spotdiff(it) {
    const { left, right, options } = it.display as any;
    const diff = left.map((v: number, i: number) => (v !== right[i] ? i : -1)).filter((i: number) => i >= 0);
    const hit = options.map((o: number[]) => eq(o, diff));
    assertEquals(hit.filter(Boolean).length, 1, "spotdiff: not exactly one matching option");
    assertEquals(new Set(options.map((o: number[]) => o.join())).size, 4);
    oneIndex(it, 4, hit.indexOf(true));
  },
};
