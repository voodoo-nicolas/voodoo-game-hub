# Turned — decisions (first slice: Prologue + Day 1 street)

Every default chosen where the owner's prompt (2026-10-22), `BRIEF.md` (the Turned CLAUDE.md v0.2) and the hub's `CLAUDE.md` were silent or disagreed. Change a value here and in the code (or in `turned_tuning.json`) together.

## Where it lives
1. **A hub pack game**, id `turned`, category Adventure, landscape, "Turned" (working title from the bible), Spanish title "Convertido". The prompt's "standalone project" folders map to the hub's pack layout:

   | Brief / prompt | In the hub |
   |---|---|
   | Godot project, 1280x720, `canvas_items` | The hub's project (Godot 4.7.2); the game fills the safe area, so its canvas is about 1280x720 in landscape, smaller at larger text sizes. The world runs in a SubViewport (like Last Shift) so its darkness and camera stay off the Landing and pause menu |
   | `autoload/` (GameState, SunClock, ...) | A pack cannot add autoloads. `turned_engine.gd` is GameState (pure logic), `turned_sun_clock.gd` is SunClock (the world owns one; `TurnedSunClock.instance` reaches it), `turned_save.gd` is SaveSystem |
   | `data/tuning.json` | `scripts/games/turned/turned_tuning.json` (a pack ships the game folders; `games/<id>/` files need a credits entry). Read through `turned_tuning.gd`; `tools/test_turned.gd` checks every key the code asks for exists |
   | `data/npcs.json` | `scripts/games/turned/turned_npcs.json` (ids, roles, `knows_player`, positions, paths). Their *lines* are in `turned_text.gd` so they go through es.json |
   | `art/` | `res://games/turned/art/<name>.png`, empty for now: `turned_art.gd` uses the PNG if it exists, else draws the placeholder. Names: player, npc_<id>, lamp, tree, stall, carriage, crate, barrel, bed. Each file needs a `media/CREDITS.json` entry |
   | Android export | Through the hub: see README |
2. Landing kit, pause menu, safe area, `SaveUtil`, EN+ES, Sfx volume groups: the hub's. Not built: Classic/Voodoo skins (Turned has its own gothic look; documented, no `skins` in the manifest), a learning hook (a gothic story has none, STANDARDS §15), a leaderboard (`board: "none"`: nothing to rank yet).
3. Rating: manifest `content` = 16+, blood, horror, realistic violence (neck bite wounds, blood, sunlight burns; no combat yet). The hub is already 16+ because of Last Shift. **Owner to confirm.**

## Story and text
4. **No alcohol (superseded by 46: alcohol is allowed in Turned since 2026-10-23).** The bible's "Like a hangover. But I didn't drink." breaks the hub rule (no alcohol references anywhere). The game says *"Like a fever. But I'm not sick."* The bible's §1 and §10 still say hungover; please reword them.
5. Invented placeholder text, to be replaced by canon: the three clues (a torn invitation "You are requested at midnight...", a stranger's coat that smells of cold stone, a note "Ask for Sera..." as the half name), the scarf by the door, the Journal lines, the Watcher's speaker name ("Man in the grey coat"), and the five neighbours' lines.
6. Both genders playable is not built: one unisex figure, no name. Spanish lines are gender-neutral where they can be.
7. Knowing/Mystery options ([DECIDE] in the bible) are not needed by the slice. The Watcher says only "You should not be out in that sun." and nothing else, and nothing about why.
8. Unaware villagers react to the marks: with the neck uncovered their lines are worried or rude and they glance at you within 3 m; with the scarf on they are friendly. The Watcher is the one villager with `knows_player` 2 and does not care about the scarf. `lines_by_level` is not used yet (only Day 1 exists).

## Prologue (bible §10)
9. Beat times are in the `prologue` block of the tuning file (black 2.6 s, fade-in 2.2 s, ...). Only A works until the "What is this?" beat ends, then the d-pad unlocks with a short hint. The heartbeat plays until then (placeholder sound).
10. The bed is not solid for the player at the start; after the d-pad unlocks they stand beside it.
11. The front door will not open until you have looked in the mirror ("I can't go out like this. I need to see myself first."). The Missions box and the first Journal entry for the neck appear at the end of the mirror close-up (A or a tap closes it after 0.9 s).
12. The scarf by the door is optional: A puts it on (drawn on the figure, saved).

## Progressive rule (the owner's "one new mechanic at a time")
13. Shown only when introduced: A (after the black screen), d-pad (after "What is this?"), the Menu button (first Journal entry), Missions box (after the mirror), the Health/Blood/XP bars and the sun icon (first time you step outside), B and the detection/noise rings (alley). Pause is always there (Android back / pause rule N4). X and Y do not exist yet (not shown, no keyboard effect).
14. The **Menu** is a stub: Journal (clue and story lines) and Quest log (the one mission). Nothing else is listed until it exists. Settings are the hub's (Pause → Options).

## Sun, health, death (CLAUDE.md §5, §6)
15. 1 m = 32 px (so "within 3 m" = 96 px). Characters are drawn about 35 px tall: placeholders, not to scale.
16. **Max Health 40** (not 100) so the sun matters on Day 1: 1 HP/s at full strength gives 40 s in the open; crossing the whole street takes about 21 s. Tunable (`stats.max_hp`).
17. Regeneration: 0.75 HP/s in shade or indoors, after 1.5 s without sun damage.
18. Sun strength comes from the clock; `sun.freeze_clock` is **true** for the slice (10:00 on Day 1, full sun). With it false the day runs 12 real minutes and the sun fades at dawn and dusk. `effective_level = floor(max(0, vampirism_level - tolerance_bonus))`; `vampirism_level = day - 1` (0..5). Day 2+ and feeding are not reachable yet.
19. Evaluated at the player's feet (`area.in_shade(player.position)`). Shade zones in Vellmoor: the porch roof over the front door, the bakery and tailor awnings, the stall awning, four trees, the alley. Houses are always safe; the front door lets you back in.
20. The screen brightens (cold white) while you stand in the sun and cools in shade, plus a white edge glow and a skin-sizzle tick while burning.
21. Blood starts at 80/100 and does not drain yet (`stats.blood_drain_per_s` 0), so only dying costs Blood. XP is 0, level 1 (nothing gives XP yet); the death penalty for XP is coded.
22. Death: 1 s fade out, respawn, 1 s fade in (2 s in all). Respawn = the nearest shade within 3 m of where you fell (preferring a point with 10 px of shade around it); if there is none within 3 m, the nearest shade within 40 m. The farthest point of the street from any shade is 6.2 m (the test prints it). 50% Health back, 25% of the Blood lost (rounded down).

## B / Sneak (alley)
23. First time you step into the alley (the autosave happens too): B pops in with a glow ring, the banner "Something new is awake." and an unlock chime; a few seconds later a one-line hint says what B does.
24. Sneak = half speed, footsteps 16 dB quieter, detection radius 6 m → 2.5 m, noise radius 4 m → 1.2 m. Rings around the feet show both (only after B exists). No enemy reads them yet.

## Input and screen
25. D-pad: four arrows in a ring, 8-way: a thumb on an axis presses one arrow, in a corner two (the axis must be twice the other); two fingers on two arrows work too. Dead zone 22 units. Keyboard: arrows/WASD, E = A, Shift = B, Space/J = X and K = Y (registered, unused), Esc = Pause, Tab = Menu, F10 = drop to 3 Health (debug builds only).
26. Touch targets: A/B 92 units across, arrows 108 units long, Pause/Menu 112x66 (landscape phone: about 64 dp, 78 dp, 78x46 dp). In portrait or narrow windows the cluster shrinks to 0.6x (still 48 dp or more there). Button positions are not editable yet (brief §3 "adjustable in settings": not built).
27. Pause (button, Esc, Android back, window/app focus lost) opens the hub's pause menu, which saves and stops the world.
28. Landscape is locked (`Orientation.lock_landscape()`); the hub's Options "Rotate" still works, the HUD and camera adapt (tested at 405x720).

## Save
29. `user://turned_save.json`, version 1. Autosaves: leaving the house (street door, once the fade is done), first time in the alley, every pause / Home / app suspend. Nothing is saved before the prologue's wake-up is over (nothing worth keeping). ▶ Resume restores area, position, Health, Blood, buttons, Journal, flags and the HUD as it was; Health is at least 1 on load. "Begin the story" and Restart delete it (the only way).

## Audio
30. All sounds are synthesized placeholders (`turned_sfx.gd`) through the hub's Sfx volume groups: heartbeat, pulse, breath, pickup, unlock chime, burn crackle, footsteps, door, whoosh, death. No music (the shared Music autoload is for later; `audio_plan.md` is not in the repo).

## Art pass (2026-10-22, after the owner's moodboard)
31. Reference only: `reference/art/turned/` holds the moodboard and two top-down map images (not committed: their origin and licence are unknown). Nothing from them is used in the game; the look is made in code.
32. The ground and walls are lit shader surfaces (`turned_ground.gdshader`): cobbles, flagstones, planks, bathroom tiles, grass, brick, slate, with height maps, so the lamps and a weak sun directional light show relief. No textures, no memory, no tiling seams. Houses have their own brick and slate, eaves, plinths, chimneys, windows (some lit), doors, shop fronts with glowing goods; the street has kerbs, puddles, manholes, leaves; lamps get an additive bloom and a slow mist drifts along the street; trees, carriage, horse, stall, crates and barrels are drawn with outlines, shading and contact shadows; people are outlined and shaded.
33. Quality switches in `turned_tuning.json` `art`: `use_shaders` (false = flat colours), `glow_layer`, `decals`. On this PC's Intel UHD 600 the frame time went from about 20 ms to about 28 ms (noisy); not yet tried on a phone. If a phone is slow, set `use_shaders` false first.
34. Painted art swaps in by file name (`docs/turned/ART_SPEC.md`: sizes at 2x, anchors, directions, tiles). Tested with temporary PNGs: crate, player_down and a cobble tile replaced the drawn ones.
35. Still drawn in code, flat: awnings, the porch roof, window frames, rugs, furniture, the HUD and the neck close-up.

## The two-floor house (2026-10-23, owner approved the plan)
36. The house is two maps of 560 px width: `house` (upstairs: bedroom unchanged, bathroom with 9 things, landing, study and library) and `house_down` (ground floor: parlour, kitchen, entrance hall). The stairs are the same block (x 496..544, y 320..400) on both floors, so you arrive where you left. Old saves in `house` still load (a position that is now inside the stairs is moved to the nearest free spot).
37. The front door moved to the ground floor (west end of the entrance hall) and stays shut until the mirror. The scarf hangs by the coat stand there. The street door now leads into `house_down`. Stairs do not autosave; leaving by the front door still does.
38. The cellar door (hall, south wall) is locked: "no key", and the Journal notes it once. It is only a hook for a later key/puzzle.
39. New clue: the bloodstained towel in the bathroom (a fourth Journal clue, `towel`). The other new objects only say a line (`Text.LOOKS`): wardrobe, portrait, toilet, cabinet, washstand, bath, desk, bookshelf, globe, clock, fireplace, piano, parlour books, stove, kitchen table (two cups), pantry, shelves. All are **placeholders** written for the slice: the hints (warm ashes, two cups, the stopped clock, the globe turned to Marrowgate, the missing book, the empty-handed hunger) are the owner's to keep, change or cut.
40. Painted furniture: `furn_<kind>.png` fills the footprint of that piece (kinds: nightstand, chair, dresser, sink, bath, stool, wardrobe, candlestand, toilet, cabinet, washstand, towelrail, plant, clock, desk, bookshelf, globe, armchair, floorlamp, fireplace, sofa, piano, stove, basin, shelves, table, cupboard, console, coatstand; the bed is `bed.png`). Footprints are in `turned_area.gd`.

## The prologue as the owner told it (2026-10-23)
41. Beats now: wake ("I'm thirsty") -> A: get up, achy ("Ugh. Everything aches.", hands on the head, "Like a fever. But I'm not sick.") -> A: rub the face and eyes, the hand slides down to the neck, two holes ("What is this?") -> stand and walk to the bathroom **hobbling** (60% speed, a sway; tuning `prologue.hobble_speed_mult` / `hobble_sway`; ends when you have looked in the mirror; "I need a mirror." after a few seconds) -> A at the mirror: the neck close-up ("What is going on?").
42. After the close-up, three thoughts a few seconds apart ("What happened last night?", "I can't remember.", "I need to figure this out."), then A (when nothing else is in reach, indoors) = **Check pockets**: empty, "Where is my coat?", Journal entry, mission "Find your coat". Examining the coat on the chair in the bedroom is the stranger's coat ("This isn't my coat..."): mission back to "Find out what happened" and "Whose coat is this? What did I do?". If the coat was examined before the pockets, the mission goes straight to "Find out what happened".
43. The front door now also needs the coat found ("I'm not going out without my coat."), after the mirror gate. Easy to drop if you do not want it: one `elif` in `turned_world.gd` (`front_door`).

## Owner's scenes 1-6 (2026-10-23, `story_scenes_1-6.md`)
44. Saved as **story only**; no code was changed. The spec's engine plan (data-driven scenes, dialogue runner, tap-to-explore, `thirst`/`days_left` stats) is not used: the game is the real-time top-down one above.
45. Where it overlaps what is built: Scene 1 = the built prologue (wake, neck, mirror, pockets, stranger's coat). The built clues are placeholders (decision 5); the spec's canon replaces them when scenes 2+ are built: right pocket matches (cigar company), inside pocket sewn shut with the note "Meet me at ... Wednesday. 10 PM. Come alone.", wall calendar showing Friday (two days lost).
46. **Owner's answers (2026-10-23), replacing the conflict list:**
   - **Alcohol: allowed in Turned.** The bar stays; alcohol is only a story location and is never promoted. CLAUDE.md, STANDARDS.md (Game Browser section) and the viral-minigame skill now carry this one exception. Decision 4 (no hangover line) is no longer forced: the bible's hangover wording can return if the owner wants it. **Still to do when the bar is built:** add `alcohol_reference` to Turned's manifest `content.descriptors` (manifest is committed last, so not touched now), re-run `python tools/rating_report.py`, and change the Play/IARC answers (the hub is already 16+, so the age does not move).
   - **Timeline.** They went to the bar on Wednesday. The player wakes on **Friday** (= Day 1, vampirism level 0) and meets these people all of Friday; Friday night they reach the old man's cabin in the woods. The shopkeeper's "2 or 3 more days" fits Days 2-3 of the bible table.
   - **A real day/night clock is needed.** Sun and shade by day, **a moon light that comes and goes at night**, time that runs in game. The slice's `sun.freeze_clock` (true, 10:00 full sun) must become false for the Friday; the moon, night lighting and shade rules for night are not built.
   - **Setting.** One place with three areas, all **Vellmoor**: Vellmoor City (the built street, the bar), Vellmoor Harbor (the cigar shop is across town by the harbor), Vellmoor Forest (the path to the cabin). The seaside city replaces "a village street" in the bible's wording.
   - **Vampire rules** went into the bible, section 8b: sun, silver, garlic, a stake through the chest, no reflection ("supposedly"), hunger that makes them weak, thin, aggravated and low, fixed by feeding. Needs the owner's call: how the built mirror (it shows the neck) fits "no reflection" (proposed: dim and fading with the turning).
   - **Watcher vs witness.** Still different people unless the owner says otherwise; the built Watcher (grey coat) stays a placeholder. The Knowing (bible section 5) would cover the shop owner and the ex-priest.
   - **"Bulls"**: the owner said "there's definitely going to be bulls" (voice note). Unclear what it means (bars? bulls as animals or enemies? pubs?). Asked, not guessed.
47. Spec [OPEN] flags (9 vs 10 PM, bar name, names for the witness and shop owner (never "Elias"), why the owner knows, who bit the player, who wrote the note, what the watch does) are the owner's to answer; nothing is hardcoded.

## Not built (as the prompt says)
Combat, buttons X/Y, skill tree, XP gain, feeding, puzzles and locks, other towns, days 2-3, the AI Director, final audio, button layout editing, the Hunter/Friend/Devotee villagers, vision cones and enemies.
