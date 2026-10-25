// Checks for the second KIN set (gens/kin2.ts), merged into gens_test.ts's CHECKS.
// Motor trials have no options: the check is that the pass mark judges correctly
// (passes at the mark, fails just past it, rejects anything that isn't a measurement)
// and that the trial itself is playable (targets inside the area, a fair sequence).
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkAnswer, type Item } from "../_shared/gens/index.ts";

function markLe(it: Item) {
  const v = (it.key as any).v;
  assertEquals(it.key.t, "le");
  assert(checkAnswer(it.key, 0) && checkAnswer(it.key, v), `${it.gid}: rejects a pass`);
  assert(!checkAnswer(it.key, v + 1) && !checkAnswer(it.key, -1) && !checkAnswer(it.key, "0") && !checkAnswer(it.key, null) && !checkAnswer(it.key, NaN));
}
function markGe(it: Item) {
  const v = (it.key as any).v;
  assertEquals(it.key.t, "ge");
  assert(checkAnswer(it.key, v) && checkAnswer(it.key, 100), `${it.gid}: rejects a pass`);
  assert(!checkAnswer(it.key, v - 1) && !checkAnswer(it.key, "100") && !checkAnswer(it.key, Infinity) && !checkAnswer(it.key, null));
}
const inside = (x: number) => x >= 0 && x <= 1;

export const CHECKS_KIN2: Record<string, (it: Item) => void> = {
  gonogo(it) {
    markLe(it);
    const t = (it.display as any).trials as { c: string; x: number; y: number; wait: number }[];
    assert(t.length >= 12 && t[0].c === "g", "gonogo: must open with a go");
    assert(t.filter((x) => x.c === "r").length >= 3 && t.filter((x) => x.c === "g").length >= 8);
    assert(!t.some((x, i) => x.c === "r" && t[i - 1]?.c === "r"), "gonogo: two no-gos in a row");
    if (it.d >= 6) assert(t.every((x, i) => x.c === "g" || (t[i - 1]?.c === "g" && t[i - 2]?.c === "g")), "gonogo: a no-go without two goes before it");
    for (const x of t) assert(inside(x.x) && inside(x.y) && x.wait >= 300);
  },
  pursuit(it) {
    markGe(it);
    const D = it.display as any;
    assert(0.5 - D.ax > 0.05 && 0.5 - D.ay > 0.05, "pursuit: target leaves the area");
    assert(D.fx > 0 && D.fy > 0 && D.dur >= 4000);
  },
  trace(it) {
    markGe(it);
    const pts = (it.display as any).pts as number[][];
    assert(pts.length >= 5);
    pts.forEach((p, i) => { assert(inside(p[0]) && p[1] >= 0.1 && p[1] <= 0.9); if (i) assert(p[0] > pts[i - 1][0]); });
  },
  tapbeat(it) {
    markLe(it);
    const D = it.display as any;
    assert(D.clicks - D.from >= 6 && D.interval >= 300);
  },
  dragfit(it) {
    assert(checkAnswer(it.key, "hit") && !checkAnswer(it.key, "miss") && !checkAnswer(it.key, "slow"));
    const D = it.display as any;
    assert(D.rx - D.bx > 0.4, "dragfit: ring too close to the ball");
    assert(D.ring > D.ball && D.limit >= 1000);
  },
};
