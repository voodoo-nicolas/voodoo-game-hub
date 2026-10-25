// BODILY-KINESTHETIC, second set (2026-10-25; NOT in the prototype): gonogo, pursuit,
// trace, tapbeat, dragfit. Pass / fail motor trials like tap / timing: the client runs
// the trial and reports what it measured; the key is the pass mark for this level.
//   gonogo:  number of mistakes (greens missed + reds tapped)   key le
//   pursuit: % of the time the finger was on the target          key ge
//   trace:   % of the drawn path inside the track (0 if let go)  key ge
//   tapbeat: mean ms between taps and clicks (9999 if < 5 taps)   key le
//   dragfit: "hit" | "miss" | "slow"                              key hit
// Arena coordinates are fractions (0..1) of the trial area; sizes are design px
// (the game is 720 wide). Served only to clients that send gv >= 6 (engine.ts).
import { defGen, mkItem } from "./registry.ts";

const at = (d: number, xs: number[]) => xs[d - 1];

defGen({
  id: "gonogo", sec: "KIN", a: 1.2, k: 0, minMs: 0, maxMs: 60000,
  make(d, r) {
    const n = at(d, [12, 12, 13, 13, 14, 14, 15, 15, 16, 16]);
    // no-go trials never first, never two in a row; at d >= 6 each follows at least two
    // goes (tapping becomes a habit). Built directly: the goes are shared out between them.
    const gap = d >= 6 ? 2 : 1;
    const nogo = Math.min(Math.round(n * at(d, [.25, .25, .28, .28, .3, .3, .32, .32, .35, .35])), Math.floor(n / (gap + 1)));
    const runs = Array(nogo + 1).fill(0).map((_, i) => (i < nogo ? gap : 0));
    for (let left = n - nogo - gap * nogo; left > 0; left--) runs[r.int(0, nogo)]++;
    const kinds: string[] = runs.flatMap((g, i) => [...Array(g).fill("g"), ...(i < nogo ? ["r"] : [])]);
    const trials = kinds.map((c) => ({ c, wait: r.int(350, 850), x: Math.round((0.15 + r.n() * 0.7) * 1000) / 1000, y: Math.round((0.15 + r.n() * 0.7) * 1000) / 1000 }));
    return mkItem(this, d, { deferTimer: true, noTimerBar: true, display: { trials, window: at(d, [900, 850, 800, 750, 700, 650, 600, 550, 500, 450]) }, key: { t: "le", v: at(d, [2, 2, 2, 1, 1, 1, 1, 0, 0, 0]) } });
  },
});

defGen({
  id: "pursuit", sec: "KIN", a: 1.2, k: 0, minMs: 0, maxMs: 40000,
  make(d, r) {
    const s = at(d, [.6, .7, .8, .9, 1, 1.1, 1.2, 1.35, 1.5, 1.65]);
    return mkItem(this, d, {
      deferTimer: true, noTimerBar: true,
      display: {
        dur: 6000, radius: at(d, [36, 34, 32, 30, 28, 26, 24, 22, 21, 20]),
        // target centre = (0.5 + ax sin(fx t + px), 0.5 + ay sin(fy t + py)), t in seconds
        ax: 0.38, ay: 0.36, fx: Math.round(s * (1.1 + r.n() * .4) * 1000) / 1000, fy: Math.round(s * (1.6 + r.n() * .6) * 1000) / 1000,
        px: Math.round(r.n() * 6283) / 1000, py: Math.round(r.n() * 6283) / 1000,
      },
      key: { t: "ge", v: at(d, [55, 60, 60, 65, 65, 70, 70, 75, 75, 80]) },
    });
  },
});

defGen({
  id: "trace", sec: "KIN", a: 1.2, k: 0, minMs: 0, maxMs: 60000,
  make(d, r) {
    const n = at(d, [5, 6, 6, 7, 7, 8, 8, 9, 9, 10]);
    const pts: number[][] = [];
    let y = 0.3 + r.n() * 0.4;
    for (let i = 0; i < n; i++) {
      pts.push([Math.round((0.08 + 0.84 * i / (n - 1)) * 1000) / 1000, Math.round(y * 1000) / 1000]);
      y = Math.min(0.85, Math.max(0.15, y + (r.n() - 0.5) * at(d, [.35, .4, .45, .5, .55, .6, .62, .65, .68, .7])));
    }
    // the client draws a smooth curve through `pts`; `half` = half the track width
    return mkItem(this, d, { deferTimer: true, noTimerBar: true, display: { pts, half: at(d, [30, 27, 24, 22, 20, 18, 16, 15, 14, 13]) }, key: { t: "ge", v: 85 } });
  },
});

defGen({
  id: "tapbeat", sec: "KIN", a: 1.2, k: 0, minMs: 0, maxMs: 40000,
  make(d) {
    // 12 clicks every `interval` ms (with a flash); taps from the 4th click on count
    return mkItem(this, d, { deferTimer: true, noTimerBar: true, display: { interval: at(d, [650, 620, 600, 580, 560, 540, 520, 500, 470, 440]), clicks: 12, from: 3 }, key: { t: "le", v: at(d, [110, 95, 85, 75, 65, 58, 50, 45, 40, 35]) } });
  },
});

defGen({
  id: "dragfit", sec: "KIN", a: 1.2, k: 0, minMs: 0, maxMs: 30000,
  make(d, r) {
    return mkItem(this, d, {
      deferTimer: true, noTimerBar: true,
      display: {
        bx: 0.14, by: Math.round((0.25 + r.n() * 0.5) * 1000) / 1000, ball: 22,
        rx: Math.round((0.62 + r.n() * 0.26) * 1000) / 1000, ry: Math.round((0.2 + r.n() * 0.6) * 1000) / 1000,
        ring: at(d, [70, 62, 55, 48, 42, 37, 33, 30, 28, 26]), limit: at(d, [4000, 3600, 3200, 2900, 2600, 2300, 2100, 1900, 1700, 1500]),
      },
      key: { t: "hit" },
    });
  },
});
