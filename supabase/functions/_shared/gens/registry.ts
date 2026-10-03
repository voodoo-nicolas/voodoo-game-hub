// Generator registry + item shape. Mirrors the prototype's defGen / mkItem, with one
// change the server needs: an item is split into `display` (render params sent to
// the client) and `key` (kept server-side in responses.answer_key, never sent).
// The prototype's `check` closures become serializable keys judged by checkAnswer().

import { bOf } from "../irt.ts";
import type { Rng } from "../rng.ts";

export type Lang = "en" | "es";
export interface Ctx { lang: Lang; used: Set<string>; blitz: boolean }

export type Key =
  | { t: "idx"; v: number } // option index:              v === ansIdx
  | { t: "num"; v: number } // typed number:              Number(v) === ans
  | { t: "str"; v: string; strict?: boolean } // typed string: String(v) === target (strict: v === target)
  | { t: "any"; v: string[] } // anagram: any listed word
  | { t: "hit" } // tap trial: v === 'hit'
  | { t: "tol"; v: number }; // timing: |v| <= tol ms

export interface Item {
  gid: string;
  sec: string;
  d: number;
  a: number;
  b: number;
  c: number;
  /** number of options (0 = typed / performance item) */
  k: number;
  minMs: number;
  maxMs: number;
  /** Blitz weight */
  w: number;
  lang?: Lang;
  /** item timer starts when the client says it's ready (after a clip / sequence plays) */
  deferTimer?: boolean;
  noTimerBar?: boolean;
  /** render params for the client */
  display: Record<string, unknown>;
  /** server-only answer key */
  key: Key;
  /** server-only extra detail for tests (e.g. syllogism option forms) */
  meta?: Record<string, unknown>;
}

export interface GenDef {
  id: string;
  sec: string;
  a: number;
  k: number;
  minMs?: number;
  maxMs?: number;
  w?: number;
  make(this: GenDef, d: number, r: Rng, ctx: Ctx): Item | null;
}

export const GENS: Record<string, GenDef> = {};

export function defGen(g: GenDef): GenDef {
  GENS[g.id] = g;
  return g;
}

type ItemData = Partial<Item> & { display: Record<string, unknown>; key: Key };

export function mkItem(g: GenDef, d: number, data: ItemData): Item {
  const k = data.k != null ? data.k : g.k;
  return Object.assign(
    { gid: g.id, sec: g.sec, d, a: g.a, b: bOf(d), c: k ? 1 / k : 0, k, minMs: g.minMs || 0, maxMs: g.maxMs || 60000, w: g.w || 1 },
    data,
    { k },
  );
}

/** Same judgement as the prototype item's check(v). */
export function checkAnswer(key: Key, v: unknown): boolean {
  switch (key.t) {
    case "idx": return v === key.v;
    case "num": return Number(v) === key.v;
    case "str": return key.strict ? v === key.v : String(v) === key.v;
    case "any": return key.v.includes(String(v));
    case "hit": return v === "hit";
    case "tol": return typeof v === "number" && Math.abs(v) <= key.v;
  }
}
