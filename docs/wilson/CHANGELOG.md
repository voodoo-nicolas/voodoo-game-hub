# Beached (wilson) changelog

## 2026-11-09: review round: fixes, 10 items, 8 recipes, 52 quests (built, not published)
Bugs fixed
- Clay and wax could not be got anywhere, so the kiln, clay jars, the fish-oil lamp, the barometer (and with it weather sense and "Cloud Reader") and the Cellar were impossible. Clay: new odd job "Dig for clay" (shovel, 2 clay, one shovel use). Wax: a shaken palm drops old beeswax now and then (6 %, never the first shake), and candle wax may wash ashore.
- The wreck's knife is the only one and it broke for good after 40 uses (no more fishing poles or coconut bowls), and there was one hook. A worn knife now goes blunt (`D.BLUNT`, item `blunt_knife`) and a stone sharpens it (recipe `sharpen_knife`); fish bones make hooks (`bone_hook`).
- Combining never found a hidden recipe when a known one used the same two things (stick + stone was always "spark kit", so the sundial could only come from a bottle). A recipe still to find now wins, and finding one no longer queues it (it could have spent the only sailcloth on a tent).
- `bottle_post` put a "message from a pen pal" in your own bag (and every third one taught a recipe). The bottle now goes out to sea; half the time one more bottle comes in with the next morning's delivery (2 at most).
- Reasons with a name in them showed half English in Spanish ("Needs a Caña de pescar."): `_why()` in the game translates the frame and keeps the name. Also the streak's "best" and the Shellphone's sunrise / sunset labels (single lowercase words never reach the game's translation file).
- Taps on ✕ in the action list were often lost: the list was rebuilt twice a second, and a rebuild between finger down and finger up swallowed the tap. It is rebuilt only when the list changes; countdowns are rewritten in place.
- `debris_crate.webp.import` was committed as `valid=false` (a failed first import): the crate had no texture in local runs and tests ("Failed loading resource"), so it could not be seen or tapped there. Re-imported.
- Food that had been lying on the sand (bag full) came back without a spoil time. Low bars flickered instead of pulsing. Built structures no longer sit in the craft list as "Already built" rows. The journal no longer ends with a raw list of quest ids. Help text said the first fire fails (it has not since round 4).
- Spanish: the dailies and a few hints were in voseo ("Pescá", "Juntá", "¿Cómo te llamás?"); STANDARDS asks for "tú".
- `tools/test_wilson_pad.gd` had two checks that had been failing since the lanes and the A button changed; brought up to date.

New
- Story quests T13-T20 after the tally: cook a fish, rain catcher, fish trap, shovel, garden plot, plant, harvest, sundial. Saves that had finished T12 pick the story up (`from_dict`), and what was already done counts (`_complete_if_met`).
- Garden: the plot finally does something. `plant` (1 seed, + 1 compost if there is any: twice as fast, one more) -> 20 h -> `harvest` 3 sweet potatoes and a seed back. The plot shows the owner's sprouts sprite while it grows. Seeds: T16 / T17 rewards, shore delivery, "Green Thumb".
- Spear fishing (the spear had no use): 1 minute, no bait, 18 % misses, crabs; at low tide no misses and twice the big fish. Bait (had no use) goes on the hook by itself: no empty lines, twice the big fish.
- 10 items: blunt knife, seeds, sweet potato, roast sweet potato, crab, cooked crab, fish stew, seaweed crisps, seaweed bandage (+25 health, the first way to heal), wind chime. 8 recipes: sharpen knife, bone hook, cook crab, bandage, fish stew, roast potato, seaweed crisps, wind chime. None of the new items has an icon yet.
- Things that had no use now have one: frond hat (heatwave thirst x1.4 instead of x2), fish-oil lamp / torch (+5 mood at night with no fire), drum (pastime), compost (garden), tin cans (wind chime, +2 mood, +4 in wind).
- Mood matters: 80 or more = 5 % faster, under 25 = 10 % slower (the opening's card already promised it).
- 4 pastimes / odd jobs: dig for clay, go for a swim (washes "Sandy" off), watch the sunset, play the drum.
- 38 side quests (93 in all), 6 dailies (14 in the pool). The journal lists open side quests first (furthest along on top) and the finished ones on one line.
- Sounds from the shared library: chop, salvage, craft, gather, lying down, and a rain loop in rain / storm (`sound_lib.gd`; none of it heard on a phone yet).
- Tests: `test_wilson.gd` 1229 checks (incl. "every material has a source"), new `test_wilson_review.gd` (26, real scene), opening 19, Pad 12.

## 2026-11-09: owner's phone feedback round 4 (built, not published)
- First campfire lights on the first try (`FIRST_FIRE_FAILS` 0; the 3 gag fails read as "it won't build").
- Wood step: once the 6 sticks are in, only the dry frond pile glows and the HUD says "Find a dry frond" (and the reverse), so "6 of 7" no longer leaves the player guessing.
- Craft list: a recipe is listed only when every material it needs is in the bag at least once; in the opening only the spark kit and the campfire.
- Odd jobs and Pastimes appear in the castaway menu only after the campfire is built.
- Painted sea: the scrolling shader foam lines are off (the "sea mist"); A / Y / X were already direct / menu / bag.
- New 9th look: the blonde (`female5`, 19 poses cut from her sheet; picker shows 5 per row). Her extra poses (`tools/wilson_art_blonde.py`, hand-measured boxes): handwork (weave, carve, tool) alternates while crafting, and a 7-step fishing cycle loops while fishing (`Castaway.FISH_CYCLE`). Only she has them; other looks keep the single poses. The spear, dock and exhausted-with-fish poses are on her sheets but unused.
- Tests: 850 checks.

## 2026-11-09: guided opening, locked identity, dawn start (built, not published)
- Owner's feedback: the HUD builds up one part at a time (`D.TUT`, `engine.tut`, `tut_step()` / `tut_reached()` / `tut_event()` / `tut_ack()`). Only the stick at first; then A + B; a pebble; the bag button; more pebbles; wood; the craft button (spark kit, campfire); then one "Got it" card per HUD part (health, food, water, energy, mood, day) and the journal + pause. Old saves and tests have `tut = -1` = everything visible. `_start_island` sets `tut = 0`.
- HUD quest line is under 5 words (`D.QUEST_SHORT`, `D.TUT.short`, `D.INTRO.hint`); the journal lists the full text (new "Story quests" section).
- Circles and boxes gone: quest items get a golden soft glow along their border, usable items a soft warm one (`GLOW_SHADER` in `wilson_world.gd`, a rounded-box light on a ColorRect). The little bobbing arrow stays.
- Name box sits at the top, on one row with OK / Skip (the phone keyboard covered it). Look and name are locked once chosen (menu entries removed; `_change_look` / `_change_name` kept for the future "message in a bottle" one-time change).
- New island starts 24 min after sunrise (`_set_clock_to_dawn` moves the game clock; the debug offset file holds it).
- Walking: x and y move separately, the lane limit never pushes him back (the "right goes up and left" slide at the cave).
- A quest whose goal was already met in the opening completes at once (T05 campfire).
- Tests: `tools/test_wilson.gd` 852 checks, `tools/test_wilson_opening.gd` (real scene), `tools/shot_wilson_opening.gd` (screenshots).

## 2026-11-09: owner's phone feedback round 3 (pack v8)
- Quest objectives get a pulsing green ring and a bobbing arrow (the Day 1 checklist's pile, the crate, palms A / B / C, the shore pile, the stump...); the 🔨 button pulses when the answer is "craft".
- He keeps facing the way he last walked (the sheets face right; every standing pose is mirrored when facing left).
- Running actions count down as 1:34 (m:ss), under a minute as "45 s", in the queue and the sleep row.
- Pad: X = the castaway's action menu (sleep, nap, craft, bag, odd jobs, pastimes), Y = the bag.
- Discovery: the HUD shows only "Day N". The hour needs a sundial (or the Shellphone); the tide needs a tide chart (quest W07) or the Shellphone; weather is never named, you see it (the barometer's forecast still names it, in "in N h" instead of clock times). Journal lines carry the hour only once the time is known. They all still happen.
- Tests: 835 checks.

## 2026-11-09: owner's phone feedback + pastimes, sky events, streak, recipe bottles (pack v7)
- Fixed: walking faced the wrong way (the walk sheets face right; they are mirrored when walking left).
- Quick start: actions are seconds, not minutes (haul 21 s, gather / shake 12 s, seawater 6 s, fishing 3 min, chopping 6 min, tier 1-2 crafts at 1/5 of the design time); energy per action scaled down with it (chop 6 not 12, haul 2). 12 odd jobs of 5-25 s (search the sand, skip a stone, splash, comb the tideline, catch a crab, dig, fan the fire, tidy, stretch, wave, scan the horizon, rock pools) under "⚡ Odd jobs" in the castaway's menu, 8 longer pastimes under "🧘 Pastimes" (stargaze, sunrise stretch, stare at the horizon, crab race, sandcastle, draw in the sand, coconut friend + chat). Odd jobs and pastimes you cannot do yet (no shovel, no fire) are not listed.
- Craft tree (Terraria-style): a recipe is listed only when the bag holds one of its materials, or it was made before; tier 2 opens after two tier-1 things are made; craftable ones first. Grand Projects moved into the craft panel (no 🏗 button), shown once you hold one of their materials.
- A glowing outline on whatever the castaway is facing (within 110 px); the Pad's A uses the same target.
- Sky events: eclipse days (new moon, seeded; the sky dims, a meteorite shard washes up), tropical storms (rare storm spells, +3 shore rolls), full-moon nights (mood, a pearl when fishing), forecast checks (barometer). Login streak: 30-day calendar with a reward per day, +1 shore roll on days 7 / 14 / 28, one grace tide a week; journal shows the calendar. Curated recipe bottles: every 3rd bottle carries a tier 3-4 recipe.
- Phone feedback round 2: the Pad is smaller and tucked into the corners (a custom layout; the big ring covered the wreck pile); "Collect: pebbles / shells / sticks / fronds / dry fronds / seaweed" are the first entries of the ⚡ Odd jobs menu (the gather spots, from anywhere); a Day 1 checklist on the HUD (8 pebbles, 6 sticks, 10 fronds, a frond bed, bed time) replaces the goal line until done and pays rope + stones; a new castaway starts at 65 energy and gathering / hauling cost more (haul 4, gather 1.5), so the first day really tires them out.
- 23 more side quests (W01 W02 W06 W08 W09 W10, A01 A03 A05 A07 A08 A10, B08, L07, L28 ...). Tests: 830 checks.

## 2026-11-08: the Viral Pad (pack v6)
- Stick + A B X Y on the shared Pad (`stick_4`): stick walks (the three depth lanes blend into one free strip, `pad_limits`), A uses the nearest thing within 140 px (its tap menu, or the castaway's menu if nothing is near; at the waterline the shallows menu), B closes a menu or cancels the running action, X = nap, Y = sleep, info pill = journal, pause pill = pause. Keyboard: WASD + K L J I (the Pad's defaults), arrows still step. Taps work as before.
- Apps without the Pad (older than v0.40.0 here) keep taps and the 💤 😴 buttons; with the Pad those buttons are hidden. Pad is APK-side, already in v0.40.0: no app release needed.
- Tests: `tools/test_wilson_pad.gd` (10 checks on the real scene, backs up and restores the desktop save). Not built: Options screen for the Pad (kit "Controls" stays hidden, like the other adopters).

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

## 2026-11-10: wide island
- New plate `art/plate.webp` 2087x768 (from `D:/dev/Wilson/island wide.jpg`, built by `tools/wilson_art_new.py`; the old one is `plate_old.webp`). `D.W` = 2087, `HORIZON_Y` 324; the camera already follows the castaway, so it just pans further.
- Every layout position was mapped x' = 1.1x + 250 (the old content sits on the middle of the sand; the rock outcrop on the left is the sealed cave; the right spit is scenery, not walkable). Lanes, cave, shore, foam, shallows hit box updated.
- Palms: the old plate had A and B painted in; now all six are sprites (palm_C / palm_D art). New choppable palms E and F; old saves get them fresh (`from_dict`). No bamboo yet (needs art + items + recipes).
- Art batch: 58 icons, 8 builds, 4 Grand Projects (cellar, desalinator, museum, shrine) placed; crate / barrel smaller, campfire right; Grand Project previews hidden in the craft list.
