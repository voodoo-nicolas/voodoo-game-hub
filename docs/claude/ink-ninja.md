# Ink Ninja (id `ink_ninja`)

Side-scrolling ink-wash ninja game: `scripts/games/ink_ninja/` (engine = pure logic, game = drawing + input,
`ink_ninja_scenery.gd` = buildings/statues/bridges/traps drawing, `ink_ninja_dark.gdshader` = dusk/night wash).
Tests: `tools/test_ink_ninja.gd` (`godot --headless --script`), shots: `tools/shot_ink_ninja.gd`.

## Round 12 (owner, 2026-11-17, pack v11)
- Pagodas bigger (`PAG_H0` 140, `PAG_DH` 136, `PAG_TAPER` 80, width 400); about half the regular ones (seed even) are
  open **gazebos** (posts, rail, hanging lantern; `open_sides` in `scenery.pagoda`). Statues drawn 1.4-1.6x; dragon plinth solid 154x126.
- Arch-bridge decks (`bridge_decks`) allow a 60 px step up (banks dip away from the deck, which used to wall you off at the first bridge). Not reproduced headless, not phone-tested.
- `test_ink_ninja.gd`: the lake test checks the lowest hp (a later heart may heal you); the random-bot "reaches the boss" check already failed before this round (65/72).

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

## Round 13 (owner, 2026-11-19)
- **Owner artwork** in `games/ink_ninja/art/` (cut from `D:/Dev/Minigame Art/ink ninja/artwork`: white made transparent,
  saturation 45 %, slightly warm, max 420 px). Drawn by `scenery.art(c, name, X, Y, h, k, flip)` (false when missing ->
  the drawn fallback). Komainu, dragon (plinth solid `DRAGON_PLINTH` 200x78, statue `DRAGON_H` 470) and shrine use it;
  new decor kinds `kitsune`, `jizo`, `lantern`, `bell`, `gate` (village pool) and `nio`, `ruin_house`, `ruin_stones` (ruins).
  New kinds change the stage layouts. The pagoda stays drawn (its roofs are climbable solids) with a stone base,
  bracket bands, railed balconies and a nine-ring spire; the drawn komainu/dragon were redrawn too (fallback only now).
- **Pickups**: `engine.scrolls` are drawn as gold koban coins (goal text "Collect %d gold coins"); secrets are jade
  magatama (pagoda one sits on the top roof beside the spire).
- **Less telling**: no "A secret!" / "You reached the top" text (sound + sparks only); the two secret badges say
  "Keep playing to find out." (`desc` in `ink_ninja_help.gd`).

## Round 14 (owner, 2026-11-20)
- **Phone zoom** (`_fit_field`): the field is scaled up to 1.4x as far as the screen still shows the whole
  arena width (`VIEW_W`); the cut height comes mostly off the sky and follows the hero up. `dark` is a child of the field.
- Pagodas a fainter brown; no red-tree hint text or "walk up" toast.
- Owner art sits on the ground (`scenery._bottom_pad` drops the picture's empty bottom rows, sinks 10 px). Komainu pair
  stands 230-320 apart (`STRUCT_W` 860). Decor lantern is 150 tall; checkpoint + night lanterns use the same picture
  (grey when unlit, glow when lit; drawn lantern is the fallback).
- `_prop`: each decor picture gets size 80-125 %, a contact shadow, a seed-picked mist veil, ground mist, and for a third
  a pine trunk in front.
- Pines: feathered dry-brush tiers (`_pine_span`), darker, plus a dark near row (`pines_near`).
- Not built: the intro video `D:/Dev/hub/ink ninja final1.mp4` (95 MB mp4; Godot plays only Ogg Theora).
