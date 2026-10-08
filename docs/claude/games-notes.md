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
- Word lists: Word Hunt/Anagrams ship ENABLE as gzipped `<id>_words.txt.gz` (`decompress_dynamic`, `PackedStringArray.bsearch`). Non-resource files only export via `include_filter`: pack presets include the game folder; `WindowsTest` preset has `scripts/games/*/*.txt.gz` and `scripts/games/*/*.json`.
- Archived (`"archived": true` on category and games; Drinking Games): Catalog drops them (no list/launch/resume/invites; Achievements skips); packs, ids, saves stay; apps before v0.29 still list them; `hub.py` leaves them out of `export --all`, `test`, `i18n`, `verify`, game count.
- Data-driven content (keeps sentences out of es.json): Trivia `trivia_questions.json` (`{"en": [...], "es": [...]}` as `[question, correct, wrong1-3]`, correct first, engine shuffles; add to a topic or `TriviaEngine.TOPICS`; timeless unambiguous facts); Sketch It `sketch_it_words.json`; Would You Rather/Truth or Dare `<id>_cards.json`.

## Intelligence category (6 brain games)
`trivia`, `quick_math`, `memory_grid`, `color_clash`, `number_series` (keeps the rule behind each sequence and shows it after an answer), `reaction` (ms, lower better, no leaderboard). The IQ test is separate (voodoo-iq.md).

## 22 new games + 2-player modes (2026-10-04)
Pipe Flow, Bubble Pop, Sketch It, Five in a Row (online), Dominoes, Mahjong Solitaire (deals by "un-playing" the layout: always solvable), Tri-Peaks, Hearts, Rock Blaster, City Defense, Maze Muncher, Moon Lander, Stack Tower, Sky Hop, Flood It, Block Collapse (`same_game`), Binary Grid (kept only while pure rule-logic solves it), Hex (Monte-Carlo CPU; online), Would You Rather, Truth or Dare, Video Poker, Air Hockey (multi-touch).
- **Pass-and-play pattern** (Sea Battle, Liar's Dice, Crazy Eights, Go Fish, Gin Rummy): full-screen opaque `cover` ("Pass the phone to Player N" + I'm ready) when the phone changes hands; `viewer` = seat whose cards are face up, set on I'm ready; drawing returns early while the cover shows. Engines take a player count (`PLAYERS` var). Yacht 2-4 scorecards swapped into the engine; War has a Flip per player; Speed puts Player 2's hand on top, drawn upside down (`draw_set_transform(c, PI)`).
- Air Hockey: two perfect-defender bots never score; test with a bank-shot bot.
- `--check-only` catches parse errors before a test hangs: `godot --headless --path . --check-only --script res://...` (an engine that fails to parse makes `load().new()` fail and the test never quits).

## The last 7 (Arcade, 2026-10-04; Easy/Normal/Hard rows, "Best score (%s)")
- Barrel Climb: six slanted girders (`y_at(floor, x)`, open at the downhill end), random ladders, Bone King throws barrels, hammer, BONUS countdown (0 = life lost).
- Cannon Duel: heightmap ground with craters (`_explode`), wind, 3 weapons, fuel; vs CPU x3 or 2 players. **CPU aim uses `predict()`, a local-variable copy of shell physics** (Dictionary `_advance` was ~30x slower): keep in step with physics.
- Crypt Crawler: DDA raycaster (`engine.cast`, 120 columns), neon wall edges as polylines broken at face changes, billboard sprites hidden by a per-column z-buffer, maze floors, skulls/wraiths/brutes.
- Star Runner: pseudo-3D (x, y, z) with `_proj()`; stretched upright (`V_STRETCH`), camera above the ship, or on a tall phone the ship sits on the horizon.
- Mini Golf: 18 holes as `HOLES` data (outline, blocks, sand, water, slopes, bumpers, mills, sliders; rects `[x0,y0,x1,y1]`), Front 9/Back 9/18, 1-4 players; moving parts also push a resting ball (`_hit_moving`). Check new holes with a brute-force bot (~400 putts per stroke, scored by BFS distance to cup): every hole holed, ball never leaves the outline.
- Pool: 8-ball rules in `resolve()` (targets fixed at `shoot()` in `shot_targets`), ghost-ball guide, ball in hand, vs CPU x3 or 2 players; Hard tries best 4 shots on `clone()`s; CPU thinks on a `WorkerThreadPool` task (`_cpu_think`, awaited in `_exit_tree`).
- Balance with bots in throwaway tests: Star Runner/Sky Raider "random or dodging bot survives Easy, mostly dies on Hard"; Cannon Duel CPU vs CPU shots-to-win by level; Pool Hard beats Easy ~90%.
- Sky Strike: see neon-blast.md.

## Misc gotchas
- Bash heredocs mangle `\\` (`"\\n"` becomes a real newline in the .gd): write patch scripts with the Write tool or `grep -n` after.
- Tests and the PC build share `%APPDATA%\Godot\app_userdata\Voodoo`: `hub.py test` and headless tests read/write the user's real saves/stats. Back up that folder before tests that finish games; restore after. Every run refreshes the Supabase session (tokens rotate); a killed run can sign the user out of the PC build (old `auth_session.json` backups don't help).
- Intelligence/other "boot test" scripts: GameInfo's first-play card pauses the tree: `game.info.close()` first.
