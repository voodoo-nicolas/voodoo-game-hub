# Ink Ninja (id `ink_ninja`)

Side-scrolling ink-wash ninja game: `scripts/games/ink_ninja/` (engine = pure logic, game = drawing + input,
`ink_ninja_scenery.gd` = buildings/statues/bridges/traps drawing, `ink_ninja_dark.gdshader` = dusk/night wash).
Tests: `tools/test_ink_ninja.gd` (`godot --headless --script`), shots: `tools/shot_ink_ninja.gd`.

## Round 11 (owner playtest, 2026-11-16)
- **Length / space**: stages are 15x the old base (boss stages 3x); nothing stands in the last `END_CLEAR` (1500 px).
- **Pickups**: stars/bombs only drop once the hero can use them (`UNLOCK`: star + bomb stage 3); caps `MAX_STARS` 20,
  `MAX_BOMBS` 4; **hearts only from bamboo (33 %)** and torii (first pass, only if hurt). Scrolls no longer heal.
- **Bomb** has its own button (`s`, a 5th pad button via `Layouts.variant`; key B). Crouch + Star is a plain star again.
- **Air cuts**: swing while rising = up, while falling = plunge (2 dmg, bounces); push sideways for the old air slash.
- **Deep lakes + drawbridge** (stage 3+, `_plan_lakes`): `deadly` pool (breath 0.8 s, fast tick, slow, heavy); the raised
  bridge falls when a star hits the rope knot (a jump + throw: the sword cannot reach it). Replaces the old rope gates.
- **Spike boards** (stage 5+, `_plan_traps`): swing down on a 3.4 s beat (`TRAP_PERIOD`), kill foes and hurt the hero;
  3 blades are placed behind each so they run through it.
- **Foes enter water** (slower); 3.5 s in deep water (1.5 s in a deadly lake) drowns them.
- **Structures** (`_plan_structs`, drawn in `ink_ninja_scenery.gd`): houses (walk-in interior, climbable roof), pagodas
  (3 tiers of roofs, secret at the top), shrines, komainu, Hachiko (akita), dragon plinth; **ruin stages**
  (`RUINS_STAGES`): ruin walls/arches/pagodas, terracotta warriors. Roofs are engine solids listed in `roofs`.
  River bridges (`arch_bridges`) over narrow dry-banked pools. Secrets (`secrets`) = golden scrolls: +500, stat
  "Secrets found"; reaching a pagoda top = stat "Pagodas climbed" (two new achievements).
- **Night stages** (`NIGHT_STAGES`): `dim` 0.9 wash, hero swings a torch, dark `night_lanterns` are lit by a swing.
  By day the same shader dims the stage a little so lit checkpoint lanterns glow (warm hole).
- **Torii** are drawn in two halves (left behind the hero, right in front).
- **Boss hall**: each boss stage has a big pagoda behind the arena. The far palace on the horizon grows with progress.
- **Helps = automatic extra lives** (STANDARDS §17 exception). "Lives" on the HUD is the helps left.
- Less telling: no stage/chapter numbers on screen, How to Play = the controller layout only.
- Not built: the weekly-bridge variants (only one drawbridge type), interiors you enter through doors (houses are open
  at the front), real statues as solids beyond the dragon plinth, a distinct torch-only sword for non-night stages.
