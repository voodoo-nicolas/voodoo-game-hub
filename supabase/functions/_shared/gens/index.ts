// All generators, registered in GENS by id. Import this (not the section files).
// The prototype's 27, then the sets added since (served by client version: engine.ts secGens).
import "./log.ts";
import "./log2.ts";
import "./spa.ts";
import "./spa2.ts";
import "./lin.ts";
import "./lin2.ts";
import "./mus.ts";
import "./mus2.ts";
import "./nat.ts";
import "./nat2.ts";
import "./kin.ts";
import "./kin2.ts";
import "./int.ts";
import "./exi.ts";
import "./exi2.ts";
import "./self2.ts";

export { checkAnswer, GENS, recallScore } from "./registry.ts";
export type { Ctx, GenDef, Item, Key, Lang } from "./registry.ts";
