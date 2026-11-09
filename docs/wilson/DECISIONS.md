# Beached (wilson): decisions where the design docs are silent or conflict

Source of truth: the owner's docs on Drive, "viral game hub/wilson" (README, KICKOFF, design/GDD.md,
CRAFTING.md, QUESTS.md, DIALOGUE.md, data/*.json). The data files are copied into
`games/wilson/data/`. Everything below is a default chosen while building M0-M2 (2026-11-08); the owner
can overrule any of it.

## Conflicts with hub standards (flagged to the owner)
- **W-1 One repo, not a separate `wilson` project.** README / KICKOFF say "create the Godot project"
  and folder `wilson`; `docs/claude/build-ship.md` says game source lives in the hub project (pack export
  needs it; don't split repos). Built as hub game id `wilson` (title from the manifest, "Beached"), so
  M8 "hub integration" is mostly done already: Landing kit, pause, helps, GameInfo, i18n, pack preset.
- **W-2 Tests in `tools/test_wilson.gd`** (hub convention), not a `tests/` folder.
- **W-3 The name "Johnny".** README: inspired by the Johnny Castaway screensaver (Sierra, 1992). The
  character's name is never shown in the game (code only: `johnny`, `tapped_johnny`). Before release the
  owner should decide whether to keep "Johnny" anywhere visible (IP checklist).

## Time and bars
- **W-4 Online vs offline.** Online = the island is on screen. A gap of more than 4 real seconds
  between frames (app closed, Landing or pause menu up) is caught up with the offline rules.
- **W-5 Asleep drain.** Food and water drain at half speed while asleep or napping; energy does not
  drain during a nap (KICKOFF test: 40 -> 55 -> 63).
- **W-6 Sleep length.** "Sleep" at night lasts to sunrise + 30 min; by day until energy is full (at
  most 4 h). The player can wake him (tap him or the queue row). Energy caps at 100 while asleep.
- **W-7 Rested** lasts 16 h; **Sandy** 8 h (after at least 1 h on sand). Collapse (energy 0, online):
  sleeps on the sand until energy 40. Faint (HP 0, online): wakes at sunrise + 30 min with HP 25 and
  the queue cleared.
- **W-8 Frond shelter = 15/h** added to `balance.json` (README errata / KICKOFF list it, the JSON did not).
- **W-9 Night tint.** CanvasModulate = keyframe light_tint x (0.55 + 0.45 x intensity): the raw
  intensity (0.30 at deep night) made the island unreadable.
- **W-10 Moon** rises and sets around a transit at 12:00 + 24 h x phase (new moon at noon, full at
  midnight), up 6.2 h each side; the lit side is mirrored in the southern hemisphere.
- **W-11 Hemisphere** defaults to south for AR CL UY PY BO PE BR AU NZ ZA locales, else north;
  the debug panel flips it (no player option yet).

## Actions, items, crafting
- **W-12 Costs the docs leave open:** gather 3 min / 2 energy, shake palm 4 min / 2, haul debris 5 min /
  haul 10, chop 30 min / chop 12, fish 15 min / fish 8, relight fire 3 min / 2, tally 1 min / 0.
  Gather spots refill (stones 3/h ... dry fronds 1/h); a palm holds 3 coconuts, +1 every 8 h.
- **W-13 Bag:** 12 slots, **+20 while a barrel is in the bag** (balance.json barrel_bonus; using the
  barrel for the rain catcher gives the room up). What does not fit lies "on the sand" and comes back
  into the bag when there is room. Without this, Day 1's wreck alone fills 8 of 12 slots.
- **W-14 Coconut:** drinking one gives water +20, food +8, a coconut shell and 3 husk fiber (6 fiber
  = 1 rope). Raw fish: food +12 (big +22), nausea 40 % (the first one always: T04 gag); cooked +25.
- **W-15 First fire:** the campfire build fails 3 times (T05 "3+ funny fails"), materials kept; later
  relights fail 25 %, less with fire XP. A new fire burns 3 h; feeding: stick 0.5 h, driftwood 2 h,
  trunk 4 h. Rain turns it to embers, a storm puts it out.
- **W-16 The spark kit is a tool** (campfire "needs", not consumed).
- **W-17 T02's loot is the crate itself** (no double loot). T08's trunk reward comes on top of the 2
  trunks from chopping.
- **W-18 Shore delivery** each morning after sunrise from Day 2: the balance.json rolls by rarity,
  uniform item within the rarity (minus things the sea can't bring: stones, sand, fish...), pity at 14
  / 60 days, plus one bottle with a curated note (checked facts). Streak bonus rolls: M6.
- **W-19 Tier 2 only** on the craft screen (KICKOFF M2). The tent is tier 3 in recipes.json, so it is
  not craftable yet; T09 is the frond shelter.

## Visuals (placeholders)
- **W-20 Art pipeline** (`python tools/wilson_art.py`, then a Godot import): `5.jpg` sky
  keyed out (only palms / rocks connected to the island survive), palms C and D cut out to sprites and
  the sea behind them in-painted (so a chopped palm disappears), `6.jpg` debris keyed off green.
  Johnny, structures, piles and the fire are drawn in code until the Gemini sprites exist.
- **W-21 Fire light** is an additive glow on a canvas layer above the tint (a PointLight2D under the
  CanvasModulate did not light anything on the mobile renderer).
- **W-22 Debug panel** (F9 or 5 quick taps on the clock) ships in the pack for now. Hide it before the
  first public pack.

## M3: crafting and combining (2026-11-08)
- **W-23 Discovery.** Tiers 1-2 are known from the start; the 15 tier 3-4 recipes are hidden ("❔ ???",
  tier, one material shown) until the player combines two of their parts in the bag (drag one item onto
  another, or "🔗 Combine with..." then a second tap). Combining picks the recipe that uses both items,
  preferring one that can be made now, then an unknown one; it queues it when everything is there.
- **W-24 Tool wear.** Uses before breaking: knife 40, stone axe 8, fishing pole 30, spear 20, shovel 15,
  coconut bowl 25, spark kit 12. One use per action that needs the tool (failed fires too).
- **W-25 Spoilage.** Raw fish 24 h, cooked fish 48 h, then fish guts; a stack keeps its oldest time;
  dried / salted food keeps; a smokehouse makes new fresh food last 4x. Clay jars: +10 bag slots each
  (balance.json jar_bonus). No chest recipe exists yet.
- **W-26 Working structures.** Rain catcher fills 0.5 / 1 / 2 drinks an hour in drizzle / rain / storm;
  the water still 1 drink per 3 h of daylight; both hold 4, +25 water a drink. Fish trap: a catch every
  6 h (small fish 80, big 12, boot 4, seaweed 4), holds 3, emptied in 3 min. Canopy +5 mood by day,
  sundial +3. Garden plot: no seeds in items.json yet (bottles, M6).
- **W-27 Skills.** Foraging, woodcutting, fishing, fire, cooking, carpentry, tinkering. Level n at
  10 x n x (n+1) / 2 XP, max 10; each level = 3 % faster at that skill's actions. Weather sense (M4): 8th skill, +3 h of barometer forecast per level.
- **W-28 Looks.** "New island" first asks "Who washed up?" (the 8 sheets); 👕 Change look in the
  castaway's menu. Lines stay gender-neutral (DIALOGUE.md).
- **W-29 Art used in M3:** characters (all 19 poses), inventory + rare icons, camp builds, fire parts,
  HUD bar icons. Not used yet: sky / sea / front-wave / foam / island-only layers (M4 water), horizon
  gags (M4-M5), Grand Projects (M7), moon-phase icons (the sky draws the real phase). The frond
  shelter, canopy, fish trap, SOS flag, smokehouse, kiln, sundial and raft still use placeholders.

## Not built yet (later milestones)
Forecast / tide screen and tide in the water art (the M4 engine is done), full water layers,
quests beyond T01-T12, skills screen, gag album, bottles to other players (M6), login streak,
cave + Grand Projects (M7), Voodoo skin, Pad controller ("Heather controller"), sounds, store art.

- **W-30 Grand Projects (2026-11-08).** 12 of 16 built; no bottle mail (owner: no bottles for now), no arcade / cinema. One build at a time, 1-3 days, materials spent at the start. "Brass fitting" = brass tube, "palm ribs" = sticks. Projects have no art yet.
- **W-31 Cave** left for later (owner, 2026-11-08), with bottles (M6).
