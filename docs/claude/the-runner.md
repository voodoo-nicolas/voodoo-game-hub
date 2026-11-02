# The Runner (id `the_runner`, space smuggling story, Adventure, landscape)

Owner's game, started 2026-11-02. Read first: `docs/runner/BRIEF.md` (hub brief: art map, screens, scope), `docs/runner/GAME_DESIGN_THE_RUNNER.md` (owner's full design doc, Acts I-III, factions, missions), `docs/runner/DECISIONS.md` (every default chosen, and what is not built). Art: owner's paintings from `D:/dev/minigame art/runner/` in `games/the_runner/art/*.webp` (26 files, credited).

## Files (`scripts/games/the_runner/`)
| File | What |
|---|---|
| `the_runner_data.gd` | all content as constants: goods, worlds (positions on `system_1.webp`), factions, ships, modules, skills, missions, events, enemies, story cards |
| `the_runner_engine.gd` | the rules (RefCounted, no Nodes): money clean/dirty, markets + supply, holds, fuel/travel (`launch` / `fly(px, at)` / `arrive`), heat + scans, encounters (`options()` / `choose()`), fights, laundering, missions, contracts, skills, modules, Kessel's loan, `best_trade` (hint), `to_dict/from_dict` (v1). Messages are `String` or `{"text", "args"}` (`_l()`): screens show them with `UI.msg()` |
| `the_runner_ui.gd` | looks (Classic / Voodoo palettes as static vars), panel / button / label helpers, `num()` (thousands separators), `msg()` |
| `the_runner_game.gd` | Landing kit, status bar, Pad, screen switching (map / dock), encounter + result cards, story cards, hints file, stats for GameInfo, save, `_set_skin` |
| `the_runner_map.gd` | system map Control: picture fitted whole, worlds, course line, ship sprite (shared library), autopilot + stick flight, docking range |
| `the_runner_dock.gd` | a world's dock (its picture) + pages: Market (💡 tip), Shipyard, Fixer jobs, Moonwash Laundry, Mother Kessel, side-mission offers |
| `the_runner_computer.gd` | Menu: Inventory, Skill Tree, Missions, Map, Ship Layout, Stats |

## Tests and tools
- `godot --headless --path . --script res://tools/test_the_runner.gd`: ~2000 checks (data, market, travel, scans, fights, laundry, M01-M04, side jobs, contracts, skills, modules, save incl. in-flight, every message's format) + a 10,000-trip trader bot (net worth must grow, no runaway, no debt spiral, the loan stays rare). Prints the sim summary.
- `godot --path . --resolution 1280x720 --script res://tools/shot_the_runner.gd -- <dir> [text size] [skin]`: screenshots of every screen (backs up and restores the save).

## Rules to keep
- New content goes in the data file; the engine reads it. New words: `tools/i18n/es.json` then `hub.py i18n` (data names are translated at display time with `UI.tr_s`).
- Engine messages with numbers or names: `_l("template %d", [n])`, never `"..." % n` (the screen must translate the template first).
- No alcohol, no real drugs among goods (DECISIONS D-7). The content test fails on alcohol words.
- Packs: no autoloads, Pad / GameInfo / Music / Sfx guarded; `sprite_lib.gd` and `sound_lib.gd` are synced copies (ids as full string literals).
