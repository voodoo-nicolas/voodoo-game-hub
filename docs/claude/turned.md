# Turned (id `turned`, gothic vampire story, Adventure, landscape)

Owner's project 2026-10-22; first slice = Prologue + Day 1 in Vellmoor. Read first: `docs/turned/story_bible.md`, `docs/turned/BRIEF.md` (the owner's own Turned CLAUDE.md; the hub's CLAUDE.md wins on navigation/pause/save/i18n/packs), `docs/turned/DECISIONS.md` (every default chosen, and what is not built), `docs/turned/README.md` (run, test, ship).

## Layout (`scripts/games/turned/`, same shape as Last Shift)
- `turned_game.gd`: Landing kit (one mode, "quick_with_save": false, `board: "none"`), builds the world in a SubViewport under the kit and the HUD over it; tells the world when the kit is up (`world.kit_up`); pause on focus loss; kit calls `_save_game()`.
- `turned_world.gd`: Node2D. Modes `prologue` / `play` / `closeup` / `transition` / `dying`; owns the engine, the sun clock, the player, NPCs, camera, CanvasModulate + PointLights. Prologue = a timed state machine (`_pro`). Tests drive it with `press_a()`, `press_b()`, `test_dir`, `_process(dt)`.
- `turned_engine.gd`: pure state/rules (Health, Blood, sun damage, death penalties, buttons, Journal, flags, sneak) + `to_dict/from_dict`. `turned_sun_clock.gd`, `turned_save.gd` (`user://turned_save.json`, v1).
- `turned_area.gd`: the maps as data (**three areas since 2026-10-23: `house` = upstairs (bedroom, bathroom, landing, study), `house_down` = ground floor (parlour, kitchen, entrance hall with the front door and the locked cellar door), `street`**; the stairs are the same block on both floors)  + geometry (`solids`, `shades`, `interacts`, `triggers`, `is_free`, `move_circle`, `nearest_shade`). Edit the maps here; `turned_area_view.gd` draws them (mode "ground" below the people, "overlay" for awnings/canopies above); `turned_prop.gd` = y-sorted props; `turned_art.gd` = placeholder drawing + PNG override by name.
- Art: `turned_ground.gdshader` (lit procedural cobbles/flags/planks/tiles/grass/brick/slate, kind 0-6, one surface evaluation per pixel, normal from screen-space height slope), `turned_area_view.gd` layers: `ground` (shader ColorRects) < `decor` < people < `overlay` < `glow` (additive). PNG override by name: see `docs/turned/ART_SPEC.md`; `art.*` tuning switches for weak devices. `tools/shot_turned_area.gd` = screenshots + ms/frame of both areas.
- `turned_player.gd`, `turned_npc.gd`, `turned_npcs.json` (villagers), `turned_hud.gd` (all HUD drawing + touch + captions + close-up + Menu stub), `turned_text.gd` (all player-facing English), `turned_sfx.gd` (synthesized sounds), `turned_input.gd` (tn_* keyboard actions), `turned_tuning.gd` + `.json` (every number).
- **Controls (2026-10-23)**: when the app has the shared Pad (`scripts/common/pad/`, `docs/claude/pad.md`) the game gives the HUD a PadController (`turned_game.gd _add_pad`, `turned_hud.gd use_pad`) that draws/reads the d-pad, A, B, Pause and Menu (layout/look/size/opacity are the player's, ⚙ Options shows "🎮 Controls"); the HUD's own controls stay as the fallback for older apps. Progressive reveal still goes through `hud.reveal(...)`. Tests: `tools/test_turned_pad.gd`.
- Tests: `tools/test_turned.gd` (330 checks, headless), `tools/shot_turned.gd` (screenshots in a window).

## Rules to keep
- Progressive reveal: a control or system is shown only once the story introduces it (`hud.reveal(...)`). New mechanic = new reveal, in order: d-pad + A → sun/shade → B.
- New numbers go into `turned_tuning.json` (the test fails if a key the code asks for is missing). New words go in `turned_text.gd` (+ es.json). `_ui("...")` in the HUD scales with screen width.
- A lamp, awning or tree must also be in the area's data (shade/solid) or it only looks right. After changing the street, run the test: it prints the farthest point from shade and checks every NPC, path and spawn is free and reachable.
- Sun = `area.in_shade(player.position)` (feet). Interiors are all shade.
- Packs: no autoloads, no `preload` of APK-side scripts; the JSON files live in the game folder (a `games/turned/` file needs a CREDITS entry).
- Do not publish the pack or push `manifest.json` without asking the owner (the manifest entry exists already).
