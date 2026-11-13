# Landing styles (orbs) and the shared effects helper

Owner request 2026-11-13: every Landing is the same full-width stack of rectangles, and long ones run off the
screen ("More" cut off). Prototype on **Tarot of Destiny** only; no other game uses it yet.

## App release or pack update?
**Pack update only.** `landing_styles.gd` and `fx_lib.gd` are templates in `tools/templates/` that `hub.py sync`
copies into each game that names them (same mechanism as `home_kit.gd`, `sound_lib.gd`, `sprite_lib.gd`), so they
run on any app version and need no `min_build`. The hooks are a few lines in `home_kit.gd`; every game's kit copy
is regenerated (121 identical one-off diffs, no change in behaviour: a game without cfg `"landing"` still builds the
stack) and each one reaches players with that game's next pack. Putting `fx_lib.gd` in `scripts/common/` (the
first idea) would have been an APK file: an app release, and old apps would lack it.

## Architecture: a Landing style is a layout, not new navigation
```
HomeKit (home_kit.gd)  owns the actions, saves, overlays, pause, Options  -- unchanged
   |  cfg "landing": "orbs"  +  cfg "landing_style": LandingStyles (the game's preload)
   v
landing_styles.gd  build(kit, home) -> Control or null (null = the stack)
   |-- "orbs"      round floating buttons (built)
   |-- "carousel"  swipeable card fan for the ways to play (NOT built; the name is reserved)
   |-- "scene"     tap things in a picture (NOT built)
   `-- fx_lib.gd   smoke, glitter, press squash, pop-in, "Reduce effects"
```
- The style calls the kit's own handlers (`_on_resume`, `_on_quick`, `_on_mode`, `_on_group`, `_on_play_item`,
  `_show_*`, `_on_hub_pressed`), so Resume / Quick Play / 🏆 / 🏅 / ❓ / 📊 / ⚙ / cfg `more` / ← Hub behave exactly as
  in the stack. `kit.resume_btn` / `quick_btn` are hidden dummies the kit's `refresh()` writes into; the style reads
  them back (`OrbLanding.refresh()`), so a game's `can_resume` / `resume_text` / `quick_with_save` work unchanged.
- Kit hooks: `_style` var; `_build_home()` (after the background); `_split_modes()` (extracted so the style can
  use it); `refresh()`, `show_home()`, `hide_home()` (motion and particles run only while the Landing is up);
  `_show_options()` (adds ✨ Effects).
- A style is chosen per game in cfg. Unknown name = the stack. Nothing else changes (nav rules N1-N7 stand: ← Hub
  only on the Landing; a way to play starts in one tap, N6).

## Orbs (what it does)
- Title column (painted title art while the title is English, else the kit's text title; subtitle; age rating; the
  "Did you know?" card; version line) at the top (portrait) or left 40 % (landscape).
- Main orbs (Resume, Quick Play, cfg `play`, Single/Multiplayer if the ways to play don't fit the bottom row,
  cfg `more`, How to Play, 🏆, 🏅, 📊, ⚙): an uneven grid, 2-4 columns whichever makes them biggest, alternate rows
  nudged, sizes by rank (`FACTORS`), never overlapping, minimum 56 units.
- Bottom row: the solo ways to play when there are 5 or fewer and no cfg `extra` (cfg mode keys `"orb"` = big glyph,
  `"orb_name"` = short name), sizes and heights uneven. ← Hub is a small round button bottom-left.
- The fact card and version line hide when they would squeeze the orbs (portrait: orbs under 100 units; landscape:
  column would reach the bottom row). A name that cannot fit its orb even at 11 pt is left out (glyph only,
  tooltip keeps it).
- Motion (Tween): pop-in with a stagger on show, one looping `tween_method` drives a sine float (each orb its own
  phase and amplitude, one full turn per loop so it never jumps), press = squash then elastic spring.
- Effects (`fx_lib.gd`): smoke (12) behind the title and glitter (24) over the screen, 36 CPUParticles2D in all
  (budget `Fx.BUDGET` = 40), only while the Landing shows.

## Reduce effects
`user://fx.json` `{"reduce": bool}`, app-wide, set in ⚙ Options ▸ ✨ Effects (Full / Reduced) of any game with a
styled Landing. Until the player chooses it follows the device: **on** for the web build and phones with 4 or fewer
cores; the app's own Settings "reduce motion" switch (newer apps) always forces it on. Reduced = no smoke, no
glitter, no floating; press squash and a short fade-in stay. (The Intel UHD 600 dev PC reports 4 cores, so it is
"reduced" by default: set Full in Options to see the effects there.)

## Adding it to another game
1. `const LandingStyles = preload("res://scripts/games/<id>/landing_styles.gd")`; cfg `"landing": "orbs"`,
   `"landing_style": LandingStyles` (+ optional `orb_color`, `orb_glitter`, `landing_title_art`, `landing_colors`,
   modes' `orb` / `orb_name`).
2. `python tools/hub.py sync` (copies `landing_styles.gd` + `fx_lib.gd` into the game), `i18n`, `check`.
3. `python tools/test_landing_orbs.gd` equivalent: `godot --path . --resolution 405x720 --script
   res://tools/test_landing_orbs.gd -- res://scenes/games/<id>/<id>.tscn` (orbs inside the screen, not
   overlapping, 56+ units, particle budget, Reduce effects). Run at 405x720 and 720x405, text size 1.0 and 1.4.
4. Strings: "✨ Effects", "Full", "Reduced", the Options line and each `orb_name` are in `tools/i18n/es.json`.

## Not built / known limits
- `carousel` and `scene` styles; the swipeable card fan for the spreads.
- `tools/crawl.gd` was not run on the orb Landing (orb buttons do carry their text, so it should find them).
- Orb screens were checked headlessly and by screenshot on a PC window (405x720, 720x405, text 1.0 and 1.4), not on a
  phone. At text 1.4 in landscape, the small orbs (Leaderboard, Statistics) show only their glyph.
- The painted title is English only; Spanish shows the text title.
