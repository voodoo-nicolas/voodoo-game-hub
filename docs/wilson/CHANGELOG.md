# Beached (wilson) changelog

## 2026-11-08: M0 + M1 + M2 (not published)
- M0: island scene (owner's clean plate, sky cut out), real-clock day/night from daynight.json (12 keyframes on sunrise/sunset, sun + moon arcs, real moon phase, stars), sea shader (foam lines, sparkles, plankton at night), campfire (3 flame layers, sparks, smoke, flickering glow), debug panel.
- M1: placeholder castaway; tap to walk (3 depth lanes) or tap wreckage / palms / piles / shallows / camp for actions; queue of 5 with absolute end times, caught up by timestamp while away; thought bubbles (EN/ES); journal + "While you were away".
- M2: HP / food / energy / water from balance.json with the offline floor of 15; sleep on 5 bed types with all modifiers, power naps (2 a day), Rested / Sandy, collapse and faint; tutorial T01-T12; bag (12 slots, +20 with the barrel); tier 1-2 crafting (27 recipes); daily shore delivery with a bottle.
- Tests: `tools/test_wilson.gd` (551 checks incl. every KICKOFF acceptance test and a T01-T12 run-through); screenshots: `tools/shot_wilson.gd`.
- Stubbed / not built: weather controller (debug-forced only), tides, Johnny's real sprites, structure art, sounds, Pad controller, Voodoo skin, M3+ (see DECISIONS.md).
