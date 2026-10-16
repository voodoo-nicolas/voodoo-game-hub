# Per-game notes, catalog conventions, patterns

## Adding a game
`python tools/hub.py new-game <id> --title "Title" --icon "🎲" --category "Cards"` creates `scripts/games/<id>/<id>_engine.gd`, `_game.gd`, `scenes/games/<id>/<id>.tscn` from `tools/templates/`, adds it to the category (replacing a same-title placeholder), generates its export preset. References: `red_or_black`, `three_man` (simple), `sudoku`/`solitaire` (complex).
1. `_engine.gd`: `extends RefCounted`, pure logic, no Nodes; headless-tested.
2. `_game.gd`: `extends Control`, entire UI in code, Landing kit from template (give it a logo and modes). Always: `Orientation.lock_portrait()` (or landscape) in `_ready()` (never rely on another scene to reset it); GameInfo block with `<id>_help.gd` recording results/records; a pause button; save/load via `SaveUtil` for mid-session state (see `solitaire_game.gd`); a game with nothing worth keeping mid-round may skip saving (say so in help). No `SettingsDrawer` in new games (kit frees it).
3. Async callbacks must not call into the scene after the player leaves: connect **methods**, not lambdas; use the node's `create_tween()` or a child `Timer`, not `await get_tree().create_timer()`.
4. Shared code only from the APK (`scripts/common/`); if it needs something new, `"min_build"` = BUILD_NUMBER of the APK that adds it.
- Keep manifest `modes`/`board` right (see accounts-online.md). Most games draw their board in one Control via `board.draw.connect(_draw_board)`.

## Catalog conventions
- No "coming soon" tiles (only if the owner asks).
- Trademark-safe titles (display names only; ids, files, stat keys keep old words): Block Drop, Sea Battle, Box Pusher, Code Breaker, Calcudoku, Word Hunt, Yacht Dice, Paddle Ball, Brick Breaker, Bird Hop, Alien Attack, Party Spinner; 2026-10-06 audit (`docs/ip-audit-2026-10-06.md`) renamed Othello->Reversi, Connect Four->Four in a Row, Wordle->Five Letters, Simon->Memory Lights, Whack-a-Mole->Bop the Mole, Minesweeper->Mines, Lights Out->Light Flip, Frog Crossing->Road Hopper, Flood It->Color Flood, Sky Raider->Sky Strike, Geometry Wars->Neon Blast, IQ Blitz->Speed Round; Block Drop, Maze Muncher, Fortune Ball moved off originals' looks. Owner 2026-10-02: kept generic names despite requests for Tetris/Battleship/Frogger.
- Card games each carry their own `<id>_cards.gd` (ints 0..51, `draw_card()`); fix bugs in all copies.
- Word lists: Word Hunt/Anagrams ship ENABLE as gzipped `<id>_words.txt.gz` (`decompress_dynamic`, `PackedStringArray.bsearch`). Non-resource files only export via `include_filter`: pack presets include the game folder; `WindowsTest` preset has `scripts/games/*/*.txt.gz` and `scripts/games/*/*.json`. Five Letters also ships `wordle_words_es.txt.gz` (5-letter forms of the LibreOffice es_MX Hunspell dictionary, MPL 1.1 option, accents dropped, ñ kept; licence in `media/licenses/wordlists/`) so Spanish guesses are validated; built 2026-10-12 with `spylls` + `wordfreq` candidates.
- **Drinking Games left the served manifest on 2026-10-12** (compliance: alcohol references must not be listed/downloadable); entries kept in `archive/drinking_games.json`, source + packs + saves untouched; `tools/test_archived.gd` no longer has anything to check against the bundled manifest. Mechanism below still applies to any future archived game.
- Archived (`"archived": true` on category and games; Drinking Games): Catalog drops them (no list/launch/resume/invites; Achievements skips); packs, ids, saves stay; apps before v0.29 still list them; `hub.py` leaves them out of `export --all`, `test`, `i18n`, `verify`, game count.
- Data-driven content (keeps sentences out of es.json): Trivia `trivia_questions.json` (`{"en": [...], "es": [...]}` as `[question, correct, wrong1-3]`, correct first, engine shuffles; add to a topic or `TriviaEngine.TOPICS`; timeless unambiguous facts); Sketch It `sketch_it_words.json`; Would You Rather/Truth or Dare `<id>_cards.json`.

## Intelligence category (6 brain games)
`trivia`, `quick_math`, `memory_grid`, `color_clash`, `number_series` (keeps the rule behind each sequence and shows it after an answer), `reaction` (ms, lower better, no leaderboard). The IQ test is separate (voodoo-iq.md).

## 22 new games + 2-player modes (2026-10-04)
Pipe Flow, Bubble Pop, Sketch It, Five in a Row (online), Dominoes, Mahjong Solitaire (deals by "un-playing" the layout: always solvable), Tri-Peaks, Hearts, Rock Blaster, City Defense, Maze Muncher, Moon Lander, Stack Tower, Sky Hop, Flood It, Block Collapse (`same_game`), Binary Grid (kept only while pure rule-logic solves it), Hex (Monte-Carlo CPU; online), Would You Rather, Truth or Dare, Video Poker, Air Hockey (multi-touch).
- **Pass-and-play pattern** (Sea Battle, Liar's Dice, Crazy Eights, Go Fish, Gin Rummy): full-screen opaque `cover` ("Pass the phone to Player N" + I'm ready) when the phone changes hands; `viewer` = seat whose cards are face up, set on I'm ready; drawing returns early while the cover shows. Engines take a player count (`PLAYERS` var). Yacht 2-4 scorecards swapped into the engine; War has a Flip per player; Speed puts Player 2's hand on top, drawn upside down (`draw_set_transform(c, PI)`).
- Air Hockey: two perfect-defender bots never score; test with a bank-shot bot.
- `--check-only` catches parse errors before a test hangs: `godot --headless --path . --check-only --script res://...` (an engine that fails to parse makes `load().new()` fail and the test never quits).

## Wire Up (id `pipe_flow`, rebuilt 2026-10-13; was Pipe Flow)
Electricity puzzle: batteries (blue/yellow), wire pieces, bulbs (blue/yellow/green). Tap = quarter turn. A network's current = the batteries it touches (blue, yellow, or green when both); a bulb lights only when its network's colour equals its own, so a green bulb needs both batteries and a blue bulb on a mixed wire is shorted. Loose ends are legal (decoys, loops).
- `pipe_flow_engine.gd`: pure logic. Boards are routed first (Dijkstra with random costs from each terminal to its network's wire), then decoys/locks are added and the pieces scrambled, so every board is solvable; `generate(params, seed)` is deterministic. `params_for(level)` = 12 chapters x 10 levels (`CHAPTERS`), sizes up to 8x10. Test: `godot --headless --path . --script res://tools/test_wire_up.gd` (all 120 levels, ~25 s) and `tools/test_wire_up_game.gd` (scene flow; WRITES the real pipe_flow saves, back up first).
- Modes: Campaign (stars: 3 = taps within ~1.3 x par and no hint), Level Select map, Daily (same board for everyone, level 45-94 by day, streak), Easy..Expert random boards (`ZEN_RANGE`), Time Attack (180 s, +5 s per board, ramps 2 levels per board). Progress in `user://pipe_flow_progress.json`; the Resume file is `pipe_flow_save.json` (old Pipe Flow saves have no `mode` and are dropped).
- All art in code (classic = blue tiles, glowing current; voodoo = neon, skull bulbs). Sounds: `pipe_flow_sfx.gd` synthesizes them and plays through `Sfx.play_stream()` (guarded: older apps stay silent). Colour is never the only cue: ring = blue, dot = yellow, both = green.
- Stats keys (GameInfo): Puzzles solved (the leaderboard), Campaign levels, Campaign stars, Perfect levels, Time attack best, Daily streak, Green bulbs lit.
- Open: the old hub tile/hero art (`media/hub/game_art/pipe_flow/`) is the placeholder from the Pipe Flow days (APK side: changes need an app release).

## The last 7 (Arcade, 2026-10-04; Easy/Normal/Hard rows, "Best score (%s)")
- Barrel Climb: six slanted girders (`y_at(floor, x)`, open at the downhill end), random ladders, Bone King throws barrels, hammer, BONUS countdown (0 = life lost).
- Cannon Duel: heightmap ground with craters (`_explode`), wind, 3 weapons, fuel; vs CPU x3 or 2 players. **CPU aim uses `predict()`, a local-variable copy of shell physics** (Dictionary `_advance` was ~30x slower): keep in step with physics.
- Crypt Crawler: DDA raycaster (`engine.cast`, 120 columns), neon wall edges as polylines broken at face changes, billboard sprites hidden by a per-column z-buffer, maze floors, skulls/wraiths/brutes.
- Star Runner: pseudo-3D (x, y, z) with `_proj()`; stretched upright (`V_STRETCH`), camera above the ship, or on a tall phone the ship sits on the horizon.
- Mini Golf: 18 holes as `HOLES` data (outline, blocks, sand, water, slopes, bumpers, mills, sliders; rects `[x0,y0,x1,y1]`), Front 9/Back 9/18, 1-4 players; moving parts also push a resting ball (`_hit_moving`). Check new holes with a brute-force bot (~400 putts per stroke, scored by BFS distance to cup): every hole holed, ball never leaves the outline.
- Pool: 8-ball rules in `resolve()` (targets fixed at `shoot()` in `shot_targets`), ghost-ball guide, ball in hand, vs CPU x3 or 2 players; Hard tries best 4 shots on `clone()`s; CPU thinks on a `WorkerThreadPool` task (`_cpu_think`, awaited in `_exit_tree`).
- Balance with bots in throwaway tests: Star Runner/Sky Raider "random or dodging bot survives Easy, mostly dies on Hard"; Cannon Duel CPU vs CPU shots-to-win by level; Pool Hard beats Easy ~90%.
- Sky Strike: see neon-blast.md.

## Color Sort (id `color_sort`, upgraded 2026-10-16)
- Liquid vials (cap 3-6), 3-14 colours (14 only far into Master), campaign levels 1..: tiers Easy 1, Medium 21, Hard 51, Expert 91, Master 141 (`color_sort_engine.gd` `spec_for`). A pour moves the whole top run that fits. Empty vials go 3 -> 2, never 1 (the reverse scramble cannot mix with one).
- Levels are seeded (`load_level(n)`): solved board + reverse un-pours (two cases, see `_unpour_options`), so always solvable. `color_sort_solver.gd` (A*, weight, optional central vial + rules) gives par; stars: 3 up to par x1.15, 2 up to x1.6.
- Central vial (levels n%3==0 from 6; 2 colours from 40, 3 from 100): takes only the colour it asks for, win = it is full AND the small vials sorted; its colours start in small vials, so extra vials are added (`center_vials`). Pressure (n%9==0 from 27): leaks a layer every 8 pours.
- Special levels (every 10th, boss every 50th): mystery, locked (pours), limited moves, timer, corks (open when the next vial is full), blocked pours. Rules live in `engine.rules`, are proven solvable by the solver at load (`VERIFY_NODES`/`VERIFY_TRIES`); the try that worked is stored in `color_sort_par.gd` `ATT`.
- `color_sort_par.gd` (PAR, ATT) is GENERATED: `godot --headless --path . --script res://tools/gen_color_sort_par.gd` (takes ~1 h; run it again whenever generation or rules change, else par/ATT go stale). Test: `tools/test_color_sort.gd`.
- Economy (no ads): hints/extra vials earned (`_earn`), stock in `user://color_sort_progress.json`. Voodoo skin: bottle shapes, skull corks, candles/bones/doll/book (decor only where the vials leave room), own SFX recipes via `Sfx._render` with fallback to library sounds.

## Misc gotchas
- Bash heredocs mangle `\\` (`"\\n"` becomes a real newline in the .gd): write patch scripts with the Write tool or `grep -n` after.
- Tests and the PC build share `%APPDATA%\Godot\app_userdata\Voodoo`: `hub.py test` and headless tests read/write the user's real saves/stats. Back up that folder before tests that finish games; restore after. Every run refreshes the Supabase session (tokens rotate); a killed run can sign the user out of the PC build (old `auth_session.json` backups don't help).
- Intelligence/other "boot test" scripts: GameInfo's first-play card pauses the tree: `game.info.close()` first.
