# Beached (wilson) changelog

## 2026-11-08: the owner's water, sky and logo art (pack v5)
- Sea: `sea layer.jpg` scrolls over the painted sea (same blue mask as before, the island is untouched; faster and wavier with the weather). Foam: three arcs from `sea foam2.jpg` pulse (+-4 % scale / alpha) at the shoreline. Front waves: `front waves.jpg` rises along the bottom in rain / wind / storm (nothing in calm weather).
- Sky: the painted sun (cut from `sky layer.jpg`) replaces the drawn disc, two painted clouds join the drifting ones. The painted sky gradient itself is not used (the game's sky changes through the day and night).
- Landing: `landing_logo.webp` = the old Landing + the wooden "Beached" logo (cut from `landing screen.jpg`), told to the kit with `art_title`.
- Hub tile + 16:9 hero: `media/hub/game_art/wilson/` (+ `tile_art` / `hero_art` in the manifest). Art is APK-side: phones see it only after the next app release.
- `tools/wilson_art.py water` rebuilds all of it. Not used: `island only.jpg` (plate comes from 5.jpg), `preview.jpg`, the portrait landing as such, the unused front-wave / foam variants, fire1/2 (not opened).

## 2026-11-08: names + Grand Project art (pack v4)
- The player names the castaway: a name card after picking the look on a new island (16 characters, Skip allowed), "✏ Change name" in the castaway's menu. Shown in the menu title and the journal ("<Name>'s journal"), saved (`engine.cname`). "Castaway" when unnamed. The character is no longer implied to be a fixed "Johnny" anywhere on screen.
- Owner's grand.jpg cut into `art/projects/` (11 sprites): Shellphone, Windmill, Coconut Radio, Spyglass Tower, Treehouse, Lighthouse, Glider, Submarine are placed on the island when built; tapping one shows its effect, the Treehouse is a bed. Slingshot, arcade and cinema are cut but their projects (GP09 / GP11 / GP12) are not built. Cellar, Desalinator, Museum, Shrine still have no art.
- Tests: 747 checks.

## 2026-11-08: daily quests + more side quests (pack v3)
- Three daily quests a day (8 in the pool, picked from the island seed, counters reset each day), listed under "Today" in the journal, small material rewards, never required.
- Five more side quests from what exists: Seeds of Doubt, Raft #1 / #2 (escape gags), SOS in the Sand, Talent Show. Side quests: 40 in all.
- Tests: 741 checks.
- Still not built: cave (C), bottles (B), most W / A quests that need new actions (stargazing, yoga, crab race...), project art, sounds, Voodoo skin, Pad controller.

## 2026-11-08: Grand Projects (pack v2)
- `wilson_projects.gd`: 12 projects (GP01-08, GP13-16). Paying the materials starts a 1-3 day build (absolute end time, one at a time); the finished project sits in `engine.structures` and its effect applies: Shellphone (moon / sun in the sea report), Windmill (power), Coconut Radio (daily broadcast, mood; needs the windmill), Desalinator (thirst -60 %), Spyglass Tower (+6 h forecast, ships), Cellar (no spoilage, +20 slots), Treehouse (26 energy / h bed), Lighthouse (ships always leave), Glider + Submarine (escape gags, a plaque each), Museum (needs 2 plaques, mood), Golden Coconut Shrine (+10 % luck on the shore roll).
- 🏗 panel: every project with materials owned / needed, pin one for the wishlist (missing items + where they come from), Build button, progress bar. 11 G-series side quests.
- Not built (owner): GP09 / GP10 (bottle mail), GP11 beach arcade (hub tie-in), GP12 cinema. No art for the projects yet (they show in the panel and the journal only).
- Tests: 725 checks.

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
