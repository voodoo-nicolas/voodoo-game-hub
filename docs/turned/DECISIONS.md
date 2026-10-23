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
4. **No alcohol.** The bible's "Like a hangover. But I didn't drink." breaks the hub rule (no alcohol references anywhere). The game says *"Like a fever. But I'm not sick."* The bible's §1 and §10 still say hungover; please reword them.
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

## Not built (as the prompt says)
Combat, buttons X/Y, skill tree, XP gain, feeding, puzzles and locks, other towns, days 2-3, the AI Director, final audio, button layout editing, the Hunter/Friend/Devotee villagers, vision cones and enemies.
