// BODILY-KINESTHETIC: pass/fail motor trials (tap, timing). Ported 1:1 from the prototype.
// The client runs the trial and reports the outcome:
//   tap:    'hit' | 'slow' | 'early' | 'miss'
//   timing: signed ms offset from the crossing (number) | 'early' | 'late'
import { defGen, mkItem } from "./registry.ts";

defGen({
  id: "tap", sec: "KIN", a: 1.2, k: 0, minMs: 0, maxMs: 4000, w: 1,
  make(d, r) {
    const T = [1300, 1150, 1000, 900, 800, 700, 620, 560, 500, 450][d - 1];
    const sz = [84, 74, 66, 58, 52, 46, 42, 38, 34, 30][d - 1];
    const wait = r.int(450, 1100), px = r.n(), py = r.n();
    // target of `size` px appears after `wait` ms at (px, py) of the free arena; must be hit within `window` ms
    return mkItem(this, d, { deferTimer: true, noTimerBar: true, display: { window: T, size: sz, wait, px, py }, key: { t: "hit" } });
  },
});
defGen({
  id: "timing", sec: "KIN", a: 1.2, k: 0, minMs: 0, maxMs: 6000,
  make(d, r) {
    const tol = [120, 100, 85, 70, 60, 50, 42, 35, 30, 25][d - 1];
    const travel = [1800, 1700, 1600, 1500, 1400, 1300, 1200, 1100, 1000, 900][d - 1];
    const hideFrac = d <= 5 ? 1 : d <= 7 ? 0.7 : 0.5;
    const startDelay = r.int(500, 900);
    // dot travels from x=14 to the line at 78% width in `travel` ms, hidden after hideFrac of the way;
    // 'late' after travel + 300 + tol ms
    return mkItem(this, d, { deferTimer: true, noTimerBar: true, display: { tol, travel, hideFrac, startDelay }, key: { t: "tol", v: tol } });
  },
});
