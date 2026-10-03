// Loads the reference implementation (docs/voodoo-iq-prototype.html) into Deno so the
// parity tests can run the prototype's own generators, IRT, Runner and scoreIQ next to
// the TypeScript port. Only the logic part of its <script> is evaluated (everything
// before the brain-map drawing); DOM helpers are defined but never called.
// deno-lint-ignore-file no-explicit-any no-eval

const HTML = new URL("../../../docs/voodoo-iq-prototype.html", import.meta.url);

export async function loadPrototype(lang: "en" | "es" = "en", extraExports = "", until = "/* ============ Brain map"): Promise<any> {
  const html = await Deno.readTextFile(HTML);
  const start = html.indexOf("<script>\n'use strict';");
  const end = html.indexOf(until);
  if (start < 0 || end < 0) throw new Error("prototype layout changed: script markers not found");
  let code = html.slice(start + "<script>".length, end);
  // Probe hook: item.mount({ __probe: f => f("<expr>") }) evaluates <expr> inside the
  // generator's own closure, so tests can read the exact values it renders.
  const MOUNT = "mount(el, api) {";
  if (code.split(MOUNT).length - 1 !== 24) throw new Error("prototype layout changed: expected 24 item mount() functions");
  code = code.replaceAll(MOUNT, MOUNT + " if (el && el.__probe) return el.__probe((e) => eval(e));");
  const S = { lang };
  const window = { crypto: globalThis.crypto };
  const exportsList = "GENS, IRT, RNG, hashStr, mulberry32, scoreIQ, Runner, SY_POOL, SY_TERMS, syText, secStanding, viqStanding, nineStanding, SEC_GENS, SELF_POOL, BLITZ_GEN, GATE, CORE, SECS, t";
  const fn = new Function("S", "window", code + `\nreturn { ${exportsList}${extraExports ? ", " + extraExports : ""} };`);
  return fn(S, window);
}

/** Per generator: the prototype's own variables, shaped like the port's `display`. */
export const PROBES: Record<string, string> = {
  series: "({ seq })",
  matrix: "({ cells: cells.slice(0, 8), options: order.map((i) => opts[i]) })",
  digits: "({ digits: ds, back: !!back })",
  arith: "({ a, op, b })",
  topview: "({ stack, options: order.map((i) => all[i]) })",
  rotation: "({ target: pNorm(p), options: order.map((i) => pNorm(all[i])) })",
  rotquick: "({ left: pNorm(p), right: pNorm(q) })",
  corsi: "({ seq })",
  oddword: "({ words })",
  oddquick: "({ words })",
  anagram: "({ letters: sc })",
  analogy: "({ a: it[0], b: it[1], c: it[2], options: order.map((i) => it[3][i]) })",
  pitch: "({ freqs: [0, 1, 2].map((i) => i === odd ? fo : f), autoplay: ctx.blitz, replays: ctx.blitz ? 0 : 1 })",
  pitchhl: "({ f1: f, f2, autoplay: true, replays: 0 })",
  melody: "({ notes1: idx.map((x) => base + scale[x]), notes2: idx2.map((x) => base + scale[x]), noteDur: nd, gap, replays: ctx.blitz ? 0 : 1 })",
  chord: "({ notes, replays: ctx.blitz ? 0 : 1 })",
  natclass: "({ families: ex, query: q })",
  natodd: "({ creatures: all })",
  natquick: "({ creatures: all })",
  tap: "({ window: T, size: sz, wait, px, py })",
  timing: "({ tol, travel, hideFrac, startDelay })",
  face: "({ params: p, face: id, eyesOnly, options: opts })",
  faceodd: "({ faces: faces.map((x) => ({ params: x.p, face: x.id })) })",
  facequick: "({ params: p, face: id, eyesOnly: false, options: opts })",
  syll: "({ premises: [syText(lang, it.p1, names), syText(lang, it.p2, names)], options: opts.map((o) => o === t('none_follows') ? '__none__' : o) })",
  syllquick: "({ premises: [syText(lang, it.p1, names), syText(lang, it.p2, names)], options: opts.map((o) => o === t('none_follows') ? '__none__' : o) })",
  fallacy: "({ argument: ctx.lang === 'es' ? es : en, options: opts })",
};

/** What the prototype item renders, in the port's display shape. */
export function probeDisplay(item: any): unknown {
  return item.mount({ __probe: (f: (e: string) => unknown) => f(PROBES[item.gid]) }, null);
}
