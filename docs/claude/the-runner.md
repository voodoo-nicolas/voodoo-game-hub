# The Runner (id `the_runner`, space smuggling story, Adventure, landscape)

Owner's game, started 2026-11-02; **v2 "the Spiral" applied 2026-11-07, pack v2 LIVE the same day (not phone-tested)** (character creation, 9 races, 46 perks, 10 factions + Hunt-Guilds, Paragon / Outlaw bars, 16 crew, 56 quests, 3 sectors / 19 planets, hull tiers, real-time battles). Read first: `docs/runner/GAME_DESIGN_THE_RUNNER_V2.md` (owner's v2 doc, source of truth for its tables), `docs/runner/DECISIONS.md` (D-18..D-34 = v2 defaults, and what is not built), `docs/runner/BRIEF.md` (hub brief: art map, screens), `docs/runner/GAME_DESIGN_THE_RUNNER.md` (v1 doc, superseded). Art: owner's paintings from `D:/dev/minigame art/runner/` in `games/the_runner/art/*.webp` (26 files, credited); ships and parts from the shared sprite library.

## Files (`scripts/games/the_runner/`)
| File | What |
|---|---|
| `the_runner_data.gd` | the world as constants: `CONFIG` (v2 §0 flags), goods, `SECTORS` (picture, size, gate, hazards, unlock flag), `WORLDS` (19 planets, positions on their sector picture), the Moth + `TIERS` (Skiff..Cruiser), part models, skills, events, `ENEMIES` (battle stats, full sprite ids), story cards |
| `the_runner_spiral.gd` | the people as constants: `RACES`, `PERKS` (31 good + 15 flaws, `fx` = stat fractions), `FACTIONS` (bloc, 50/75/100 bonuses), `BAR_MILESTONES`, `ABILITIES` (battle calls), `CREW`, `QUESTS` (one step + rewards + choices / picks), rep constants |
| `the_runner_engine.gd` | the rules (RefCounted, no Nodes): captain; `stat(key)` / `flag()` / `local_bonus()` (perks from race / picks / crew / rep / curses, stacking and caps, cached: call `_invalidate()` after changing crew, rep, bars or curses by hand); money clean/dirty, markets + supply, holds; sectors, gates and flight time (`launch` / `fly(px, at, secs)` / `arrive` / `jump`); heat + scans; encounters (`options()` / `choose()`); battle setup and results (`battle_player()` / `battle_enemies()` / `end_battle()`); rep + bars; quests (`quest_offers` / `quest_block` / `complete(id, choice, pick)`); crew (`hire_block` / `hire` / wages); contracts and bounties; refits; `to_dict/from_dict` (v2; v1 refused, `save_version()` tells). Messages are `String` or `{"text", "args"}` (`_l()`, `{}` = none): screens show them with `UI.msg()` |
| `the_runner_battle.gd` | the real-time battle sim (RefCounted): `setup`, `tick(dt, move)`, `use(ability)`, `pick_target`, `outcome`, `result_info()`, `autopilot_move()` (tests and the sim) |
| `the_runner_ui.gd` | looks (Classic / Voodoo palettes as static vars), panel / button / label / `meter` helpers, `num()`, `msg()` (`%+d` keeps its sign), name helpers (perk, faction, race, sector) |
| `the_runner_ship_art.gd` | draws a ship from its parts (`spec_of(engine)`, `spec_enemy()`, `draw()`): the map, battles and Ship Layout use it |
| `the_runner_game.gd` | Landing kit, creation → run, v1-save notice, status bar, Pad (map: DOCK / JUMP / GO / STOP; battle: TARGET / SHIELD), screen switching (map / dock), gate card, encounter + result cards, battle view, story cards (`%s` = captain's name), hints file, stats for GameInfo, save, `_set_skin` |
| `the_runner_create.gd` | character creation: name, gender, race, home faction (Terran / Ssaryn), 2 perks, summary |
| `the_runner_map.gd` | sector map Control: follow camera (2.3×) / 🔭 overview, worlds, gate, course line + ETA, the ship drawn from its parts, autopilot (20-45 s) + stick flight, docking and gate range |
| `the_runner_battle_view.gd` | the battle screen: backdrop, ships, shots, bars, ability column (right edge, clear of the Pad's A / B), drag / stick steering, tap to target |
| `the_runner_dock.gd` | a world's dock + pages: Job board, hand-in (choices / picks), Crew for hire, Market (💡 tip), Shipyard (parts, specials, refits), Fixer (contracts, bounties), Faction office (rep repair), laundry, Kessel's collector |
| `the_runner_computer.gd` | Menu: Inventory, Skill Tree, Missions, Map (all sectors), Ship Layout (sockets, specials, the drawn ship), Stats, Factions (bars, milestones, rep, bonuses, calls), Crew, Captain (every perk and its source) |

## Tests and tools
- `godot --headless --path . --script res://tools/test_the_runner.gd`: ~2400 checks (v2 data against the doc's counts, perk stacking / caps, rep + bars, market, sectors + gates + flight time, scans, battles through the sim's autopilot incl. win rates, quests N01-N04 / choices / picks / battle quests, crew gates + clash + wages, contracts, refits, save v2 + v1 refused, every message's format) + a 10,000-trip trader bot that fights its battles (net worth must grow, no runaway, no debt spiral, the loan stays rare). Prints the sim summary. ~90 s.
- `godot --path . --resolution 1280x720 --script res://tools/shot_the_runner.gd -- <dir> [text size] [skin] [locale]`: screenshots of every screen incl. creation, battle, gate and the 9 Menu tabs (backs up and restores the run save; the locale is set for that session only). Like `hub.py test`, it adds to the real GameInfo stats file.

## Rules to keep
- New content goes in the data files; the engine reads it. New words: `tools/i18n/es.json` then `hub.py i18n` (data names are translated at display time with `UI.tr_s`).
- Engine messages with numbers or names: `_l("template %d", [n])`, never `"..." % n` (the screen must translate the template first).
- No alcohol, no real drugs among goods (DECISIONS D-7). The content test fails on alcohol words.
- Quests change only the factions they list (v2 §7.4): never add automatic rival penalties.
- New GameInfo stats: name them "Highest / Most / Best ..." (or reuse a key). A plain counter adds 4 generic badges, and the game sits at 950 of its 1000 achievement points.
- Pad sub-labels: `UI.tr_s("Dock").to_upper()`, never an ALL-CAPS literal (the extractor skips those, so Spanish never reaches the pack).
- Packs: no autoloads, Pad / GameInfo / Music / Sfx guarded; `sprite_lib.gd` and `sound_lib.gd` are synced copies (ids as full string literals, enemy sprites in `ENEMIES` too).
