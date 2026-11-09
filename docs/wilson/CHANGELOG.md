# Beached (wilson) changelog

## 2026-11-08: M5 side quests + sea report (not published)
- `wilson_quests.gd`: 21 side quests (S, W, A series) that watch engine counters (`stats`, `bump()`): made:<recipe>, ev:<event>[:id], wx:<weather>, reef, low_tides. Pay XP / items / gag / decor once, journal line "Quest done".
- Journal panel: sea report (tide now, next low tide, barometer forecast) and the quest list with progress.
- Tests: 698 checks. Not built (needs systems that don't exist yet): bottle quests B (M6), cave C (M7), Grand Projects G (M7), escape gags E, dailies D, most of A, W01 / W02 / W06 / W08-W10, S08 / S11 / S14-S17 / S20 / S21 / S23-S25.

## 2026-11-08: M4 weather + tides (not published)
- Weather controller: seeded per island, 3 h spells (merge to 6 h), season weights for the player's hemisphere (no heatwave in winter, no cold snap in summer); drives the engine through `advance`, so offline catch-up replays it. Debug panel: "auto" or force a state.
- Effects: fog +1 bottle ashore, rain bites (fishing), wind / storm regrow coconuts x2, storm log line; heatwave thirst x2, rain catcher and fire were already wired.
- Tides: 12 h 25 min cycle, seeded phase, low = under 0.2 (~29 %); at low tide gathering shells / seaweed also finds a reef item (REEF_TABLE). HUD clock shows weather + tide.
- Barometer forecast (12 h) + new skill "weather sense" (+3 h per level, 3 XP a day with a barometer in the bag): engine API `forecast()`, no screen yet.
- Tests: 688 checks. Not built: forecast / tide screen, tide in the water art, tropical storm, weekly events.

## 2026-11-08: M3 crafting and combining (not published)
- All 42 recipes (tiers 1-4); tier 3-4 found by dragging two materials together in the bag (or two taps); "❔ ???" list with hints.
- Tool wear (7 tools), food spoilage (fish -> guts; smokehouse slows it), clay jars +10 slots, skills (7, levels speed actions up).
- Working structures: rain catcher + water still give drinks, fish trap catches on its own, stump / kiln / campfire menus craft there.
- Owner art in: 8 castaway looks (19 poses, pick one on a new island), item icons, camp builds, fire parts, HUD icons.
- Tests: 671 checks (every recipe made end to end, combine / discovery, wear, spoilage, structures, skills, storage).

## 2026-11-08: M0 + M1 + M2 (not published)
- M0: island scene (owner's clean plate, sky cut out), real-clock day/night from daynight.json (12 keyframes on sunrise/sunset, sun + moon arcs, real moon phase, stars), sea shader (foam lines, sparkles, plankton at night), campfire (3 flame layers, sparks, smoke, flickering glow), debug panel.
- M1: placeholder castaway; tap to walk (3 depth lanes) or tap wreckage / palms / piles / shallows / camp for actions; queue of 5 with absolute end times, caught up by timestamp while away; thought bubbles (EN/ES); journal + "While you were away".
- M2: HP / food / energy / water from balance.json with the offline floor of 15; sleep on 5 bed types with all modifiers, power naps (2 a day), Rested / Sandy, collapse and faint; tutorial T01-T12; bag (12 slots, +20 with the barrel); tier 1-2 crafting (27 recipes); daily shore delivery with a bottle.
- Tests: `tools/test_wilson.gd` (551 checks incl. every KICKOFF acceptance test and a T01-T12 run-through); screenshots: `tools/shot_wilson.gd`.
- Stubbed / not built: weather controller (debug-forced only), tides, Johnny's real sprites, structure art, sounds, Pad controller, Voodoo skin, M3+ (see DECISIONS.md).
