# Voodoo Game Hub

Free, ad-free, ever-growing mini-game hub. Godot 4.7.2 / GDScript, no Gradle build.
Public repo: https://github.com/voodoo-nicolas/voodoo-game-hub

## Architecture: "Option B" — download-on-demand games

The hub app ships as a small base APK containing only the hub shell. Every game
lives in its own `.pck` resource pack, hosted on GitHub Releases (tag `packs-v1`),
and is downloaded to `user://packs/<pack_id>.pck` the first time a player taps it,
then mounted at runtime with `ProjectSettings.load_resource_pack()`.

This means:
- A game's code/scenes are physically in this repo and this Godot project (Godot
  can only export a `.pck` from scenes/scripts that live inside its own project),
  but they're **excluded from the base Android build** via
  `export_presets.cfg` preset 0's `exclude_filter="scenes/games/*, scripts/games/*"`.
- Each game gets its own export preset (`resources` filter, `include_filter`
  scoped to just that game's folder) that produces its standalone `.pck`.
- `manifest.json` is the **game catalog and version list in one file**: its
  `categories` drive the hub's list (titles, icons, order, "coming soon"
  placeholders) and its `games` block holds each pack's version/url/scene. The
  `Catalog` autoload (`scripts/common/catalog.gd`) reads it from, best first:
  the live copy on `raw.githubusercontent.com`, the last live copy cached in
  `user://manifest_cache.json`, or the copy bundled in the APK. So **a new game
  appears in installed apps as soon as `manifest.json` is pushed and its pack
  uploaded — no APK release needed** — unless the pack needs newer shared code;
  then set `"min_build": <BUILD_NUMBER>` on its `games` entry and older apps
  show "Update app" instead of launching it. Apps ≤ v0.12 only read
  `games.<id>.version`, so never rename or drop those fields.
- The hub compares manifest versions against `user://pack_versions.json` to
  decide download vs. update vs. launch-as-is. Downloads go to a `.part` file,
  are checked for the `GDPC` magic, then swapped in — a failed update keeps
  (and launches) the old copy. A pack that fails to mount is deleted so the
  next tap re-downloads it.
- The **app itself** also self-updates: the hub checks the GitHub Releases API on
  launch and prompts to install a newer APK if the latest release tag is newer
  than `scripts/common/version.gd`'s `VERSION`.

Don't try to split this into multiple repos/projects per game — Godot's `.pck`
export requires the source to be inside this one project, and the shared helpers
below need to stay trivially reusable. The games are logically independent (that's
the whole point of Option B); the repo/project is not.

## Accounts (Supabase) — the project's first backend

Everything above is static hosting only. Accounts are the one exception: real
per-user sign-up/sign-in backed by a live Supabase project, added so high
scores can sync across devices and so later phases (multiplayer, paid
memberships — see the long-term roadmap the user and Claude discussed) have
real identity to build on. The app stays fully playable with zero account —
this is an additive layer, never a login wall.

- **`scripts/common/auth.gd`** — this project's first-ever autoload
  (registered in `project.godot`'s `[autoload]` section as `Auth`). Wraps
  Supabase's Auth + PostgREST HTTP APIs over plain `HTTPRequest` (no official
  Godot Supabase SDK exists), following `hub.gd`'s established HTTP-calling
  convention exactly. Exposes `sign_up`, `sign_in`, `sign_out`,
  `request_password_reset`, `is_logged_in`, `get_display_name`,
  `reconcile_stat`/`push_stat` (for syncing a named integer stat), plus
  `signed_in`/`signed_out`/`auth_error` signals.
- **Only the publishable/anon Supabase key lives in this repo** (in
  `scripts/common/config.gd` and in `docs/reset-password.html`) — it's safe to embed because it
  ships inside the APK either way and only grants what the project's Row
  Level Security policies allow. The secret/`service_role` key must never
  appear in this codebase; it lives only in the Supabase dashboard.
- **`scripts/account/account_screen.gd`** — the sign-in/sign-up UI, following
  every game's own-scene pattern. This is the app's first use of `LineEdit`.
- **Synced data**: only the three *persistent* best-score files (Snake,
  Whack-a-Mole, Simon) sync to a `player_stats` table — every other game's
  save is mid-game state deleted on game-over, not worth syncing. Sync is
  lazy and per-game: each game's own `_load_best()`/`_save_best()` calls
  `Auth.reconcile_stat`/`push_stat` if `Auth.is_logged_in()`, never blocking
  local play if logged out or offline. Reconciliation always takes the max
  of local vs. cloud, so progress is never silently lost either direction.
- **Password reset** redirects to `docs/reset-password.html`, a static page
  published via GitHub Pages — not a deep link into the app. Supabase's
  recovery email is designed for a web redirect, and this project has no
  Android deep-linking infrastructure; building that would be a much bigger
  addition than password reset itself warrants.
- **Session persistence**: `user://auth_session.json` via the existing
  `SaveUtil` (access token, refresh token, expiry, user id, display name).
  Access tokens expire hourly; `Auth` refreshes automatically ~60s before
  expiry, and Supabase rotates the refresh token on every use — the new one
  must overwrite the stored one, not just the access token.
- Schema/RLS policy SQL lives only in the Supabase dashboard's SQL editor,
  not in this repo (nothing here runs migrations) — see conversation history
  or ask the user if you need to see the current schema.

## Online two-player (Supabase Realtime) -- no tables, nothing stored

`scripts/common/online_session.gd` speaks Supabase Realtime's Phoenix
WebSocket protocol directly: a room is a broadcast channel named
`voodoo-<game_id>-<4-letter code>`, presence shows who's in it (roles
`host` / `guest`), and moves are broadcast messages. Nothing is written to
the database, so there's no schema to maintain and it works with the anon
key as-is. `online_lobby.gd` is the shared Host / Join-by-code screen.

- **Wiring a game**: use `scripts/common/online_match.gd` (`OnlineMatch`) --
  it owns the lobby, roles, sync and consistency checks; its header comment
  is the how-to. The game supplies `_online_state()` (whole game as
  JSON-safe values), applies `remote_move` / `remote_state`, and calls
  `send_move()` after a local move. Host = player 1 and the authority: it
  pushes full state when the guest (re)appears or asks; every move carries
  the sender's resulting state and a mismatch triggers a resync, so missed
  messages heal. Online games are never saved locally, and an online game
  ending must not delete the local save. Online so far: Tic-Tac-Toe,
  Connect Four, Checkers, Reversi, Chess, Mancala, Dots and Boxes, Morris,
  Backgammon, Memory, Five in a Row, Hex (2026-10-04). Games with dice or a shuffle send the whole
  state as the move (Backgammon: every roll and checker move; Memory: the host
  deals, each flip is a move).
- **Testing online without the server**: `tools/test_online_pair.gd` plays
  whole games between two copies of a game joined by a fake session (JSON
  round trip) and checks they never disagree; add a driver there when wiring
  a new game. It records online results: back up user data first.
- **Seat view**: in Chess and Checkers the guest's board is drawn rotated
  180 degrees (`flipped`, `_view_index()`) so their pieces are at the bottom;
  only drawing and tap handling convert, the engine always uses real
  coordinates.
- **Never `preload` the online scripts from a game**: they ship in the APK
  (v0.14+), and packs also run on older apps. Check
  `ResourceLoader.exists(ONLINE_LOBBY_PATH)` and `load()` it; without it the
  game simply has no Online button.
- **Free Supabase projects pause after ~1 week idle** -- the project's domain
  then stops resolving and sign-in, score sync and online play all fail.
  The user restores it from supabase.com/dashboard. (Happened 2026-09-30.)

## Languages (English / Spanish) -- since v0.16.0

The `Lang` autoload (`scripts/common/lang.gd`) holds the language: first
launch follows the phone's language, the hub's 🌐 button switches it (saved
in `user://language.json`). Translation is Godot's own: every Label/Button
translates its text automatically when a translation for that exact English
string exists.

- **Source of truth: `tools/i18n/es.json`** -- English string -> Spanish
  (`null` = not UI text). `python tools/hub.py i18n` regenerates
  `scripts/common/strings_es.gd` (hub + shared screens, in the APK) and each
  catalog game's `scripts/games/<id>/<id>_i18n.gd` (in its pack, so new games
  bring their own Spanish). Anything new it can't find in es.json goes to
  `tools/i18n/untranslated.json`; translate it and rerun. Never hand-edit the
  generated files.
- **Every game's `_ready()` starts with**
  `preload("res://scripts/games/<id>/<id>_i18n.gd").install(self)` -- it
  registers straight with TranslationServer (not Lang), so packs also work
  on apps from before Lang existed (those just follow the phone's language).
- **Formatted / concatenated text must go through `tr()` first**:
  `tr("Score: %d") % score`, `tr("Your turn (%s)") % tr("White")`. Plain
  `label.text = "Play Again"` needs nothing. Not in `const` initializers (tr
  isn't constant) -- call tr() where the const value is used. In static
  functions use `str(TranslationServer.translate("..."))`.
- **Never tr() data**: text sent to the server or compared in logic stays
  English (e.g. the default account display name "Player").
- The extractor skips ALL-CAPS literals (word lists), so an all-caps label
  must be written `tr("Code").to_upper()`.
- **Game and category names**: `"title_es"` / `"name_es"` in manifest.json
  (`Lang.pick(entry, "title")` chooses).
- **Word games switch content, not just buttons**: Hangman and Wordle use
  Spanish word lists (accents dropped, Ñ kept, Ñ key added) when
  `TranslationServer.get_locale().begins_with("es")`.
- Spanish style: neutral Latin American with "tú".

## How to Play + stats (GameInfo) -- since v0.20.0

`scripts/common/game_info.gd` (ships in the APK) gives every game a How to
Play card, opened from the ⚙ drawer (a "?" tab before v0.22). It pauses the game (`get_tree().paused`) and opens a
card with 🎯 Goal, 📋 How to Play, 💡 Tips and 📊 Your Stats, and opens by
itself the first time a game is played. Its header comment is the how-to.

- **Text lives in `scripts/games/<id>/<id>_help.gd`** (in the pack): only
  constants -- `ID`, `TITLE`, `GOAL`, `HOW`, `TIPS`, `STATS` (stat keys always
  shown, in order). Write it from the game's actual code, not from general
  knowledge of the game (controls, variants, limits differ). The strings go
  through es.json like any other text.
- **Stats** are saved to `user://stats_<id>.json`: `info.result("win" |
  "loss" | "draw")` (streaks and win rate come free; online games pass
  `true` to count "Online wins" apart), `info.add(key)`, `info.high(key, v)`,
  `info.low(key, v)` (both return true on a new record), `info.summary()`
  for the game-over text, and `start_clock()` / `stop_clock()` for puzzles
  without their own timer. Keys containing "time" show as m:ss. Per-variant
  keys are written `"Best time (%s)" % "Hard"` so the extractor sees both parts.
- **Load it, never preload it** (`GAME_INFO_PATH`, `var info = null`, guard
  every use with `if info:`), like the online scripts: packs also run on
  apps before v0.20, which simply have no ? button.
- **Record each result once.** End checks often run again after a game is
  over (a refresh, an online resync); games keep a `result_recorded` flag
  reset on new game, or a `just_ended := game_active` guard in `_show_result()`.
- Games that already had their own best-score file (and the account-synced
  Snake / Simon / Whack-a-Mole bests) keep it -- packs must work without
  GameInfo -- and also feed it into GameInfo with `high()`, including when
  `Auth.reconcile_stat` merges a higher cloud value.
- Anything that must keep running while a game is paused sets
  `process_mode = PROCESS_MODE_ALWAYS` (Auth, Catalog, OnlineSession do).

## Voodoo Mode (skulls skin) -- since v0.21.0

`scripts/common/voodoo.gd` (ships in the APK) is an optional skin that swaps
game pieces for skulls, crossbones and voodoo dolls (the doll is the app
logo: button X eyes, stitched seam, a pin), all drawn in code -- no image
assets. One global switch, saved in `user://voodoo_mode.json`: "💀 Skull
mode" in the hub's Options screen, and a "💀 Voodoo" button in the ⚙ drawer
of games that support it. Its header comment is the how-to.

- So far: Tic-Tac-Toe (crossbones vs skulls), Connect Four (red skulls vs
  yellow dolls), Reversi (black skulls with red eyes vs white skulls).
  Pieces keep each player's color, so turn/result text and stats keys don't
  change meaning; only the displayed names do ("Bones", "Skull", "Doll").
- **Load it, never preload it** (`VOODOO_PATH`, `var voodoo = null`), like
  GameInfo: packs also run on apps before v0.21, which keep plain pieces.
- A game opts in by defining `_set_voodoo(on)` (re-skin + re-render in
  place). The ⚙ drawer shows the toggle only then, and calls it instead of
  reloading the scene, so an online match keeps going.
- Each player's skin is local: online opponents can see different pieces.

## Options screen + Settings autoload -- since v0.21.0

The hub's "⚙ Options" button (replacing the old 🌐 / 💀 header buttons) opens
`scenes/hub/options.tscn` (`scripts/hub/options_screen.gd`): text size,
theme, language, skull mode, sound, vibration, keep screen on, account,
check for updates, send feedback (GitHub issues). Values live in the
`Settings` autoload (`scripts/common/settings.gd`, `user://settings.json`);
its header comment is the how-to.

- **Text size works through `root.content_scale_factor`** (Normal 1.0 /
  Large 1.2 / Extra large 1.4; new installs start at Large because players
  everywhere found 1.0 too small). It reaches every game and every pack
  with no game code -- but many games have fixed-pixel parts laid out for
  720 wide, so `Settings._fit_scene()` measures each new screen (on
  `SceneTree.scene_changed`) and backs the scale off just enough to fit,
  never below 1.0. As of v0.21 Wordle, Crossword and Anagrams fit only
  ~1.0 (fixed-width keyboards) and Blackjack, Block Drop, Liar's Dice and
  Morris ~1.1-1.2: making their fixed sizes follow the viewport width is
  how to give them the full size. New UI should size from the viewport,
  not assume 720.
- **Theme** covers the hub and Options only (`Settings.palette()`, keys
  like `bg`, `text`, `accent`, `link`, `ready`...). Games keep their own
  colors -- a games-wide light theme would mean touching every game.
- **Sound** (its own section since v0.23): "🔊 Sound" Off = mute all
  (mutes the Master bus), a Volume slider (Master bus volume), and an
  on/off + volume per sound group (`Settings.SOUND_GROUPS`: taps & keys,
  game sounds, wins & losses, notifications). Drawn by
  `scripts/common/sound_options.gd`, which the in-game ⚙ drawer's "🔊 Sound"
  button also opens, so it can be changed mid-game. Sliders apply live and
  save on release (`set_volume(v, save)`), and every change plays a sample.
- **Vibration**: `Settings` connects every `BaseButton.pressed` in the tree
  (`node_added`) to a 12 ms tick, and GameInfo buzzes 70 ms on a win
  (`celebrate()`) or loss. Needs `permissions/vibrate=true` in the Android
  preset. Games must not reference `Settings` directly:
  `get_node_or_null("/root/Settings")` (packs run on older apps).
- **Drag-to-scroll** for lists of buttons is `scripts/common/drag_scroll.gd`
  (child of a ScrollContainer; tap handlers check its `moved`); dialogs
  over such a list join the `modal_overlay` group.
- `python tools/hub.py test` boots the Options screen too.

## Screen edges, the ⚙ tab, resuming, names, leaderboards -- since v0.22.0

From the 2026-10-02 round of player feedback. All of it is in the APK
(`scripts/common/`) and reaches every game with no game code, except where
noted.

- **Safe area**: `Settings._apply_safe_area()` insets each screen's root
  Control by the phone's camera cutout (`DisplayServer.get_display_safe_area`,
  min 24 units at the top in portrait) and the clear color goes black, like a
  status bar. Test on PC with `VOODOO_SAFE_INSET="l,t,r,b"` (canvas units).
- **Landscape is scaled up**: the design is 720x1280 and "expand" keeps the
  1280 sideways, so landscape screens used to render at ~56% (Geometry Wars'
  Pause "barely visible"). `Settings._landscape_boost()` multiplies the
  content scale by 1280/720 when the window is wider than tall.
  **Gotcha**: the root's `size_changed` also fires when the content scale
  changes; refit only when the *window* size changed (`_on_root_resized`),
  or a screen that `_fit_scene` shrinks (Block Drop) loops forever.
- **One floating tab**: GameInfo no longer draws its "?" tab -- "❓ How to
  Play" is a button in the ⚙ drawer. The ⚙ tab is small, half see-through,
  draggable (position saved per scene in `user://drawer_pos.json`), and until
  the player moves it, it slides off any button/board under it
  (`_avoid_controls`). A game whose whole table is one tap area can set a
  default: `drawer.set("default_frac", 0.6)` (set(), so packs run on older
  apps). The drawer's panel is placed with offsets -- `position` on an
  anchored Control is from its top-left, which had the drawer off-screen
  ("the settings button does nothing").
- **Resume after Android kills the app**: on pause inside a game, Settings
  writes `user://resume.json`; the hub's first `_ready` reopens that game
  (`Settings.take_resume_scene()`), and games with `_save_game` continue.
- **Online names + rejoin** (`online_match.gd` header): the lobby has a "Your
  name" field (saved, defaults to the account name) carried in presence;
  `my_name()` / `opponent_name()`; `status_text`/`result_text` use them. The
  room is saved in `user://online_room.json` during a match; a killed app
  reopens to "↩ Rejoin game XXXX" with the same code, role and presence key.
  A returning host asks the guest for the game (`state_please`) instead of
  pushing a blank board. Tested with two Godot processes on the live project.
- **Leaderboards**: table `scores` (one best per player per game), created by
  `docs/leaderboards.sql` (run once in the Supabase SQL editor). GameInfo
  posts a new "Best score" via `Auth.submit_score` when signed in and shows a
  🏆 Top 10 on the card (`Auth.fetch_leaderboard`); if the table isn't there
  the section simply hides. Only games whose STATS include "Best score".
- **Names stay generic** (user's decision 2026-10-02): players asked for
  Tetris / Battleship / Frogger; kept Block Drop / Sea Battle / Frog Crossing
  for trademark safety.
- Wordle checks English guesses against `wordle_words.txt.gz` (the 5-letter
  ENABLE words + every answer); Spanish has no dictionary, so any 5 letters.

## Sound library (Sfx autoload) -- since v0.23.0

`scripts/common/sfx.gd` (ships in the APK, autoload `Sfx`) is the shared
sound library: Basic (tap, back, toggle, invalid, win, lose, draw, record,
tick, notify) plus per-category sets (Cards, Board, Dice & Party, Arcade,
Word). Its header comment lists every name and is the how-to.

- **Every sound is synthesized in code** (sfxr-style recipes, rendered on a
  worker thread at launch, ~0.5 s total on PC) -- no audio files, no
  download cost. Dropping `assets/sfx/<name>.ogg` in replaces one with a
  recording, no code change (the user's decision 2026-10-03: synth first,
  real recordings for cards/dice later if the synth ones sound too fake).
- **Free with no game code**: every button press plays "tap" (like the
  vibration tick), and GameInfo plays win / lose / draw / record with
  `result()` and `celebrate()`. A button that should sound different gets
  `btn.set_meta("sfx", "key")`, or `""` for silence when the game plays its
  own sound for that action (Yacht's Roll, Spin the Bottle's Spin, the
  Wordle keyboard).
- **Games never reference `Sfx` directly** (packs run on older apps): each
  wired game has a tiny `_sfx(name)` that does
  `get_node_or_null("/root/Sfx")`. No `min_build` needed -- older apps are
  simply silent.
- A sound only one game uses goes in that game's folder (its pack) and plays
  with `Sfx.play_stream(stream, 0.0, 1.0, group)`.
- **Player controls**: every sound belongs to a group (`Sfx.GROUP_OF`;
  unlisted = "game"), and `play_stream` skips it or adjusts its volume from
  Settings (`group_db`). A new library sound that's a tap, a result or an
  alert must be added to `GROUP_OF`, or the player's switches won't cover it.
- Wired so far, one per category: Chess, Blackjack, Wordle, Snake, Yacht,
  King's Cup, Spin the Bottle (Dots & Boxes still has its own chime from
  before the library).

## Achievements, friends, invites, hub screens -- since v0.25.0 (2026-10-04)

All APK-side (`scripts/common/`, `scripts/hub/`), so every game gets them
with no game code; the Home kit shows them when the app has them.

- **Achievements** (`scripts/common/achievements.gd`, header is the how-to):
  generic badges derived from each game's GameInfo stats (tiers of "Wins",
  "Games played", any other counter, "Best streak", "Online wins", beating
  your own records -- GameInfo counts those in `_records`), plus optional
  per-game `ACHIEVEMENTS` in `<id>_help.gd` ({id, icon, title, desc, key,
  at, lower}), plus hub-wide ones (`HUB`: games tried, badges, friends,
  invites; `user://achievements.json`). Unlocked badges live in the stats
  file as `_ach`. GameInfo checks on every save and slides a toast; earned
  badges backfill silently. The total goes on the leaderboard as game id
  `achievements`. Test: `tools/test_achievements.gd`.
- **Friends + invites**: `Social` autoload (`scripts/common/social.gd`) over
  `Auth.db_call()` (PostgREST RPC; never name it `rpc` -- clashes with
  Node.rpc). Server: `supabase/migrations/20261004000000_friends.sql`, run
  once in the SQL editor by the user (Claude can't touch the prod DB).
  Until it exists `Social.available` is false and friend UI hides.
  Friend codes (6 letters), requests, online status (heartbeat 60 s),
  invites polled every 12 s and popped up anywhere ("Join" / "Not now";
  Options "🔔 Game invites": Always / Not during games / Off).
- **Opening a game into online play**: `Social.launch_online(id, mode,
  code, invite_to)` -> hub (`Social.take_launch_request()`, same path as a
  tile tap) -> the game's OnlineMatch `take_pending()` -> lobby
  `auto_start()` ("host" + invite, "join", "invite", "lobby"). The kit hides
  Home when the lobby opens. Test: `tools/test_social_launch.gd`.
- **Hub screens** (`scripts/hub/hub_screen.gd` base): 🏆 Leaderboards (every
  board, Everyone / Friends), 🏅 Achievements, 👥 Friends, 🎮 Multiplayer --
  the row of four under the account line. Multiplayer and the board names
  come from the manifest's per-game `"modes"` ("online,local,party,cpu")
  and `"board"` (stat ranked; omitted = "Best score", "none" = no board);
  Catalog carries both. Keep them right when adding a game.

## Scoping your work: hub vs. a specific game

The only thing connecting a game to the hub is its `manifest.json` entry (a
line in a category + its `games` entry) — a game's code never reads hub
internals, and the hub never reads a game's internals beyond its `.tscn` path.

- **Fixing or building a specific game?** You need `scripts/games/<id>/`,
  `scenes/games/<id>/`, this file's "Adding a new game" and "Shipping a change"
  sections, and nothing else. You should not need to open `scripts/hub/hub.gd`.
- **Working on the hub shell itself** (the category list, tiles, update flow,
  download flow)? Read `scripts/hub/CLAUDE.md` instead — it covers `hub.gd`'s
  and `Catalog`'s internals. You should not need to open any file under
  `scripts/games/` or `scenes/games/`.

## Project tool: `tools/hub.py`

Every chore that used to be a hand-edit across several files is one command
(`python tools/hub.py -h` lists them all). What's hand-edited vs. generated:

| Edit by hand | Generated by `sync` — never hand-edit |
|---|---|
| `manifest.json` — catalog, titles, icons, pack versions | pack presets in `export_presets.cfg` (one per game) |
| `scripts/common/version.gd` — `VERSION`, `BUILD_NUMBER` | Android preset's `version/name` + `version/code` |
| `scripts/common/config.gd` — repo, release tag, Supabase, timeouts | `games` entries (url/scene) for new ids in `manifest.json` |

**PC test build**: `python tools/hub.py pc` exports every game bundled into
`%LOCALAPPDATA%\VoodooGameHub\Voodoo.exe` and (re)creates the "Voodoo Game
Hub" desktop shortcut. The user plays it to test games before release --
re-run it after changing any game so their copy stays current.

`python tools/hub.py check` validates all of it (scenes exist, ids unique,
presets and version in sync) and changes nothing — run it before committing.
`tools/` has a `.gdignore`, so Godot never imports or exports it.

## Minigame standards (the user's rules, 2026-10-03)

Apply these to **every new game and every existing game you modify** (when
touching an older game, bring it up to these standards as part of the change,
or tell the user what's still missing).

1. **Follow every other project standard**, especially the art standards in
   `reference/art/ART_STYLE.md` (neon vector glow on near-black), plus the
   i18n, GameInfo, Sfx and "Adding a new game" rules in this file.
2. **Each game has its own Home / landing screen**, designed for that game
   and built in the game's own code (in its pack) -- not one shared screen
   for all games. Tapping a game's tile opens its Home screen, never
   straight into play. Today a game opens on the How to Play card and then
   play; a few already have a setup screen (number of players, basic
   options) -- grow those into the full Home screen. A game's Home screen
   offers, where they apply:
   - **Single player** (with that game's own options: difficulty, size...).
   - **Multiplayer**, where the game allows it:
     - one phone, several players (pass-and-play / same screen);
     - several phones (online room, `OnlineMatch` / `online_lobby.gd`);
     - **invite another online player** to the game.
   - **Leaderboard** info (GameInfo's 🏆 Top 10 / the player's bests).
   - **Gameplay info** (the How to Play card from `<id>_help.gd`).
   - **Options / settings**: sound, vibration, blocking notifications.
   - **Resume** a game in progress (shown only when a saved game exists).
   Shared pieces (GameInfo card, sound options, online lobby) are reused by
   `load()`ing them from `scripts/common/`, never `preload`, so the pack
   still runs on older apps (those simply lack that button).
   "Invite an online player" and "block notifications" exist since v0.25
   (lobby / kit "📨 Invite a friend", Options "🔔 Game invites").
   **Reference Home screen: Sudoku** (`scripts/games/sudoku/sudoku_home.gd`,
   2026-10-03): neon title + drawn logo, Resume, one button per difficulty
   showing its best, and How to Play / 🏆 Leaderboard / 📊 Statistics /
   🔊 Sound / Hub, each opening its own screen in the game's style. Players
   never found the leaderboard on the GameInfo card, so every Home screen
   gets its own 🏆 button (`Auth.fetch_leaderboard`, guarded).
   **Every other game uses the Home screen kit** (next section).

## Home screen kit (`home_kit.gd`) -- since 2026-10-03

Every game except Sudoku (its own reference Home) and Voodoo IQ (its brain
map) builds its Home screen, pause menu and neon look with the kit.
`tools/templates/home_kit.gd` is the only copy ever edited: `hub.py sync`
copies it to `scripts/games/<id>/home_kit.gd` for every game that mentions
it, so each pack carries its own copy and runs on any app version, and
`hub.py check` fails if a copy differs. Its header comment is the how-to.

- **What the game supplies** (`HomeKit.new({...})`): its logo
  (`_draw_home_logo(c)`, drawn with the kit's `glow_line/rect/circle/text`
  helpers -- that is what makes each Home the game's own), accent colour,
  subtitle, and `modes` -- one button per way to play
  (`"row"` puts difficulty levels side by side, `"multi": true` files it
  under Multiplayer; `solo_heading` / `multi_heading` rename the sections;
  `"extra"` adds the game's own pickers, e.g. Block Drop's board size).
  Plus `save_path` + `resume` (+ `resume_text`) for the Resume button,
  `restart`, `board` (the stat the 🏆 Leaderboard ranks -- default
  "Best score", else e.g. "Wins" or "Puzzles solved") and `online`.
- **What the kit does**: Home (Resume, the modes, How to Play, 🏆
  Leaderboard, 📊 Statistics, 🔊 Sound, Back to Hub); the pause menu
  (`home.pause()` from the game's ⏸ button: Continue, Restart, How to Play,
  Sound, the game's Home, Hub -- two columns in landscape); Android's back
  gesture; `neon_theme()` (set as the game root's `theme`: neon buttons and
  26 px default text) and `backdrop()` (near-black + faint grid).
- **The tree is paused while Home or the pause menu shows** (the kit runs
  with PROCESS_MODE_ALWAYS), so a game that starts itself in `_ready()`
  simply waits underneath. A mode button un-pauses and calls its action,
  which must start a fresh game. "Home" from the pause menu saves
  (`_save_game()`) and reloads the scene. After a mode starts, the kit asks
  Settings to re-fit the screen (`_fit_scene`), because a game screen that
  was hidden behind Home was not measured at load.
- **Saves**: only the Home "New …" buttons delete a save. `_ready()` may
  start a game behind Home, so it must NOT delete the save (Resume would
  find nothing) -- games keep a `started` flag that `_ready()` clears, and
  `_save_game()` skips when it's false.
- **Leaderboard metric**: the `scores` table keeps each player's highest
  number, so games without a "Best score" rank a counter that only grows
  ("Wins" vs the computer, "Puzzles solved", "Cards played"...). The kit
  posts it whenever Home shows (signed in).
- **Two-player modes added 2026-10-03**: vs-computer AIs for Tic-Tac-Toe,
  Connect Four, Checkers, Reversi, Chess (alpha-beta in a thread, time
  budget per level), Mancala; same-phone 2 Players for Backgammon, Farkle,
  Morris, Memory, Shut the Box; "one sets, one guesses" for Code Breaker,
  Hangman and Wordle.
- **Card games** draw neon cards (dark face, pink/cyan rim): the shared
  `<id>_cards.gd` copies are still identical, and Solitaire's `card_view.gd`
  matches them.
- **Testing**: `godot --headless --path . --script res://tools/crawl.gd -- [ids]`
  presses every Home card, every (offline) mode, the pause menu and Resume
  for each game and prints a summary; `tools/shot.gd` drives one scene and
  saves screenshots (`--resolution 405x720` for a phone, 720x405 landscape;
  steps listed in its header). Both play real games: back up user data.
3. **Nothing important under the camera**: the game's title, HUD, scores and
   board stay fully inside the phone's safe area. `Settings._apply_safe_area()`
   insets the scene's root Control, so lay out from the root's own rect, never
   absolute window coordinates or draw outside it. Check with
   `VOODOO_SAFE_INSET="l,t,r,b"` on PC (e.g. a big top notch).
4. **The floating ⚙ tab never covers anything that matters**: board,
   cards, HUD, scores, the title or buttons. `_avoid_controls` only dodges
   Buttons/Controls, not things drawn inside a board Control, so each game
   sets a safe default spot (`drawer.set("default_frac", ...)`) or leaves a
   clear margin for it, and you check it on the game screen and the Home
   screen, portrait and landscape.
5. **Pause, exit, recover**: every game can be paused (a visible Pause
   button / menu, not only the ⚙ drawer; timers, animations and AI stop),
   exited to its Home screen or the hub at any moment, and its progress
   recovered whenever possible -- saved with `SaveUtil` on pause, exit and
   app suspend, and offered as **Resume** on the Home screen (Android
   killing the app already reopens the last game via `user://resume.json`).
   Only a game with nothing worth keeping mid-round may skip saving; say so
   in its help text if a round can't be resumed. Online matches aren't saved
   locally (they rejoin instead, see OnlineMatch).

## Adding a new game — the pattern

```
python tools/hub.py new-game <id> --title "Title" --icon "🎲" --category "Cards"
```

creates `scripts/games/<id>/<id>_engine.gd`, `<id>_game.gd` and
`scenes/games/<id>/<id>.tscn` from `tools/templates/`, adds the game to the
category (replacing a "coming soon" placeholder with the same title), and
generates its export preset. Then build the game — `red_or_black` or
`three_man` (simple) and `sudoku`/`solitaire` (complex board state) are good
references.

1. **`<id>_engine.gd`** — `extends RefCounted`, pure game logic, no Godot
   UI/Node dependencies. This is what gets unit-tested headlessly.
2. **`<id>_game.gd`** — `extends Control`, builds its entire UI in code, with
   its Home screen from the kit (see "Home screen kit"; the template already
   wires it -- give it a real logo and its modes). Always:
   - `Orientation.lock_portrait()` (or `lock_landscape()`) in `_ready()` — every
     scene declares its own required orientation; never rely on another scene to
     reset it on exit (see Gotchas below for why).
   - `add_child(SettingsDrawer.new())` as the **last** child of `_build_ui()` —
     gives every game the floating settings tab (timer, rotate, screenshot, hub).
     Just before it, the GameInfo block (see "How to Play + stats") with the
     game's `<id>_help.gd`, and record results/records at the game's end.
   - A "Hub" button reachable at all times, in addition to the settings drawer.
   - If the game has meaningful mid-session state worth resuming, save/load via
     `SaveUtil` (see `solitaire_game.gd` for the full pause/save/resume pattern).
     The Minigame standards above require pause / exit / Resume; only a game
     with nothing worth keeping mid-round may skip saving (its Home screen
     just shows no Resume button).
   - Anything asynchronous (network replies, delays) must not call back into
     the scene after the player leaves: connect **methods**, not lambdas, and
     prefer the node's own `create_tween()` or a child `Timer` (both freed
     with the scene) over `await get_tree().create_timer()`.
3. A game may only use shared code (`scripts/common/`) that ships in the APK.
   If it needs something new there, set `"min_build"` on its `games` entry to
   the `BUILD_NUMBER` of the APK that adds it.

## Shipping a change — the checklist

1. **Headless logic test**: write a throwaway `SceneTree`-extending test script
   (see git history for examples — `test_three_man.gd` style), run with
   `godot --headless --script path/to/test.gd`. For anything with randomness
   (dice, shuffled decks), run hundreds/thousands of trials per branch and assert
   invariants rather than exact outcomes.
2. **Boot test**: `python tools/hub.py test <id>` (no ids = hub, account screen
   and every game). Boots each scene headless and fails on any `SCRIPT ERROR` /
   `Parse Error` — no need to edit `run/main_scene` for this anymore.
3. **Version bump**:
   - A game changed → `python tools/hub.py bump-pack <id>` (installed apps
     re-download it on their next tap).
   - Anything baked into the APK changed (`scripts/common/`, `scripts/hub/`,
     `scripts/account/`, `project.godot`) →
     `python tools/hub.py bump-app [patch|minor|major]` — bumps `VERSION` and
     `BUILD_NUMBER` together and syncs the Android preset.
4. **Build**: `python tools/hub.py export <id>...` (or `--all`) for packs;
   `python tools/hub.py apk` for the release-signed APK (see "App signing") (fails if any of arm64-v8a,
   armeabi-v7a, x86_64 is missing; copies to `builds/voodoo-vX.Y.Z.apk`).
5. **Upload packs**: `python tools/hub.py publish-packs <id>...`
6. **Commit and push** source changes including `manifest.json` (not
   `builds/` — gitignored). Pushing `manifest.json` is what tells installed
   apps about new versions/games, so do it *after* the packs are uploaded.
7. **APK release** (only if step 3 bumped the app):
   `python tools/hub.py release --notes "..."`
8. **Verify live**: `python tools/hub.py verify` fetches every pack URL and the
   live manifest and compares them with the local builds.

## App signing (since v0.15.0)

Up to v0.14.0 every APK was a debug build signed with the shared Android
debug key -- Play Protect flags that ("App blocked to protect your
device"). From v0.15.0, `python tools/hub.py apk` makes a **release** build
signed with the project's own key:

- Key: `C:\Users\nick_\Android\Keystore\voodoo-release.keystore`
  (alias `voodoo`); its password is in `voodoo-release.json` next to it.
  `hub.py` passes them to Godot via the `GODOT_ANDROID_KEYSTORE_RELEASE_*`
  environment variables, so they never appear in `export_presets.cfg` or
  the repo. **Never commit either file, never print the password.**
- **If this key is lost, installed apps can never be updated again**
  (Android only accepts updates signed with the same key). The user keeps a
  backup copy of both files somewhere safe (USB drive / cloud).
- The v0.14 -> v0.15 switch changed the signing key, so Android refused to
  update in place: users had to uninstall once and reinstall (losing
  phone-only saves). Later updates install normally.
- `hub.py apk --debug` still makes a debug build for local testing only.
- **Package ID is `com.viral.voodoo`** (developer "viral", app "Voodoo") since
  v0.15.1. It was `com.voodoo.app` before -- changed because "Voodoo" is also
  a big mobile-game publisher, and the ID must be registrable under the
  user's own identity. A package ID change is a different app to Android,
  so testers uninstalled the old one. Never change it again: the ID and the
  signing key are what Google's developer verification registers.
- **Developer verification** (Google, mandatory for sideloaded installs on
  certified devices: some countries from Sept 2026, everywhere in 2027):
  until the user registers (one-time $25 per developer account, government
  ID) and registers `com.viral.voodoo` + the release key in the Android
  Developer Console, Play Protect blocks installs with "hasn't seen an app
  from this developer". Workaround: temporarily turn off "Scan apps with
  Play Protect" in the Play Store.
- **Status (2026-09-30):** Android Developer Console account "Viral" created
  as **Personal (Limited distribution)** -- the free tier: max 20 devices,
  installs by invitation. `com.viral.voodoo` + the release key are
  **Registered**. Sharing publicly needs an upgrade to Full distribution
  ($25 one-time, ID check).

## Local tool locations (portable installs, not on PATH)

**This PC (user `nick_`) is the main PC** (since 2026-10-03): it builds the
APK, publishes packs and releases. No admin rights, so everything is a
portable copy and none of it is on PATH. Bash tool calls `powershell.exe` in
a way that mangles `$_`/env-var syntax -- use the PowerShell tool directly
for anything needing real PowerShell semantics, not
`Bash("powershell.exe ...")`. Set `PYTHONIOENCODING=utf-8` before running
`tools/hub.py` from Bash, or `-h` and some output crash on emoji (cp1252).

- **Godot 4.7.2**: `C:\Users\nick_\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
  (Windows export templates are installed in
  `%APPDATA%\Godot\export_templates\4.7.2.stable`, so `hub.py pc` works)
- **Android SDK**: `C:\Users\nick_\Android\sdk` (cmdline-tools, platform-tools, build-tools 34.0.0, platforms)
- **JDK**: `C:\Users\nick_\Android\jdk-17.0.20.1+1`
- **Keystores**: `C:\Users\nick_\Android\Keystore\` (`debug.keystore`,
  `voodoo-release.keystore`, `voodoo-release.json`); rules in "App signing".
- **Python 3.12** (runs `tools/hub.py`): `%LOCALAPPDATA%\Programs\Python\Python312\python.exe`; `python` also resolves in the Bash tool.
- **GitHub CLI**: `C:\Program Files\GitHub CLI\gh.exe` (authenticated as `voodoo-nicolas`)
- **Git**: `C:\Program Files\Git\cmd\git.exe`

The old PC (user `Cliente`) used the same layout under `C:\Users\Cliente\`.
This PC's Desktop is redirected to OneDrive (`hub.py pc` asks Windows for the
Desktop path). Windows was reinstalled 2026-10-03.

## Gotchas already found and fixed (don't reintroduce)

- **`font_color` vs `font_disabled_color`**: `add_theme_color_override("font_color",
  ...)` on a `Button` does nothing once `disabled = true`. Use
  `font_disabled_color` for disabled-state text color.
- **Orientation enum names**: `DisplayServer.SCREEN_SENSOR_LANDSCAPE` /
  `SCREEN_SENSOR_PORTRAIT`, not `SCREEN_ORIENTATION_*` (doesn't exist, fails
  silently). Always go through `scripts/common/orientation.gd`.
- **`window/stretch/aspect`**: must be `"expand"`, not `"keep"` — `"keep"`
  letterboxes on any device whose aspect ratio doesn't match the design
  resolution, which reads to a player as "the game is tiny" or "UI elements are
  clipped off-screen."
- **`--export-pack` output path**: the CLI-provided path always wins over the
  preset's own configured `export_path` — always pass the exact intended path
  explicitly (`tools/hub.py export` does).
- **Nested `Dictionary` inside a top-level `const Array`** is read-only; call
  `.duplicate()` before mutating a copy pulled from a const table.
- **32-bit ARM devices**: `export_presets.cfg` preset 0 needs
  `architectures/armeabi-v7a=true` — without it, older/budget Android phones
  are silently rejected as "incompatible" on install.
- **`free()` vs `queue_free()` inside a signal handler**: never call `.free()`
  on a node from inside a signal callback that node itself (or an ancestor of
  it in the same rebuild) is still emitting. Godot 4.7 refuses the call
  ("Attempted to free a locked object (calling or emitting)") rather than
  crashing, but the consequence is worse than an error line: the node was
  already `remove_child()`'d, so refusing to free it **leaks it** — one
  orphaned node per interaction, which adds up over a long session — and the
  rebuilt container is left a child short. `hub.gd`'s `_rebuild_list()` hit
  this, as did `solitaire`, `kings_cup`, `red_or_black` and `g2048`. Always use
  `queue_free()` when rebuilding a list of nodes in response to one of those
  nodes' own signal; it defers past the emission, so nothing is locked.

- **Connecting a lambda to a long-lived signal (an autoload like `Auth`)**:
  Godot only auto-disconnects a connection when the connected `Callable` points
  at the freed object. A lambda is a separate object that merely *captures*
  `self`, so it outlives the scene that created it — every visit leaves another
  stale connection on the autoload, and the next emission errors once per stale
  copy ("Lambda capture at index 0 was freed"). Connect a plain method instead,
  using `.unbind(n)` to drop unwanted signal arguments
  (`Auth.signed_in.connect(_update_account_status.unbind(2))`). Plain method
  callables — including `.unbind()`ed ones — are cleaned up automatically, which
  is also why games don't need manual `disconnect()` calls in `_exit_tree()`.
- **Godot force-includes the project icon (and autoload scripts) in every
  `.pck`**, ignoring include filters. Until this was caught every pack was
  ~1.1 MB, 98% of it `assets/icon.png`. Pack presets therefore carry the
  `game_pack` custom feature (`project.godot` has `config/icon.game_pack=""`)
  and exclude the shared folders — `tools/hub.py sync` generates both. A
  Lights Out pack is ~9.5 KB now.
- **Packs are mounted with `replace_files = false`**: a pack may only add its
  own files. Packs exported before the fix above contain stray copies of
  `auth.gd` / `project.binary`; with replace on, a pack could shadow the APK's
  own shared scripts.
- **Never overwrite a mounted `.pck`**: Godot reads a mounted pack lazily by
  file offset, so replacing the file underneath feeds the game garbage.
  `Catalog` only updates packs not yet mounted this session; an update found
  after playing that game applies on the next app start.
- **Every `HTTPRequest` needs `timeout` set** (`Config.HTTP_TIMEOUT`): the
  default 0 waits forever on a dead connection, which looked like a tile tap
  doing nothing.
- **Auth refresh**: only a 4xx from Supabase signs the player out; a network
  failure keeps the session (launching offline used to log everyone out).
  Refreshes are single-flight because Supabase rotates the refresh token on
  each use — two overlapping refreshes spend it twice and the second can
  revoke the session.
- **`await get_tree().create_timer(...)` in a scene**: if the player leaves
  before it fires, the coroutine resumes into a freed scene. Use the node's
  own `create_tween()` or a child `Timer` — both die with the scene.
- **`set_anchors_preset()` on a node already in the tree keeps its size**
  (a full-rect preset from `_ready()` leaves a 0×0 Control). Use
  `set_anchors_and_offsets_preset()` there. SettingsDrawer had this until
  v0.20: its ⚙ tab was drawn off-screen above the top-left corner.
- **Tests and the PC build share `%APPDATA%\Godot\app_userdata\Voodoo`**:
  `hub.py test` and any headless test script read and write the same saves,
  best scores and stats the user plays with. Back that folder up before a
  test that finishes games, and restore it afterwards. Every run also
  refreshes the user's Supabase session (refresh tokens rotate), so a
  killed or failed run can sign them out of the PC build -- an old
  `auth_session.json` from a backup doesn't help; they sign in again.
- **Settings drawer "Rotate Screen"** reloads the scene, whose `_ready()`
  re-locks its default orientation — which used to undo the rotation
  instantly. `Orientation.override_next()` makes that one next lock rotate.
- **Callbacks into scenes from autoloads** (`Auth.reconcile_stat`,
  `Catalog`): both skip a callback whose object is gone via
  `Callable.is_valid()` — which only detects freed *method* callables, so
  pass methods, not lambdas.

## Intelligence category (2026-10-03)

Six brain games, one pack each, all following the usual game pattern (engine
tested headlessly, UI in code, GameInfo with "Best score" so they appear on
the leaderboards): `trivia`, `quick_math`, `memory_grid`, `color_clash`,
`number_series`, `reaction` (Reaction Test; milliseconds, lower is better, so
no leaderboard). **The IQ test is deliberately not here** -- it is its own
planned project, with its own code session.

- **Trivia's questions are data, not code**: `scripts/games/trivia/
  trivia_questions.json`, each question `{"en": [...], "es": [...]}` as
  `[question, correct, wrong1, wrong2, wrong3]` (the correct answer is always
  listed first; the engine shuffles). Keeping them out of `.gd` files keeps
  hundreds of sentences out of `es.json` -- the bank carries its own Spanish
  and the game picks by `TranslationServer.get_locale()`. Pack presets already
  include the whole game folder; the PC build's `WindowsTest` preset needed
  `scripts/games/*/*.json` added to its `include_filter`. To add questions,
  append to a topic (or add a topic id to `TriviaEngine.TOPICS`); keep facts
  timeless and the answer unambiguous.
- **Number Series** keeps the rule behind every sequence and shows it after
  an answer, so a miss teaches something.
- **GameInfo's first-play card pauses the tree**: any test script that drives a
  game must call `game.info.close()` first, or its timers and tweens never fire.

## Voodoo IQ backend (Phase 1, 2026-10-03)

Spec: `docs/voodoo-iq-spec.md`. Reference implementation: `docs/voodoo-iq-prototype.html`
(its generators, scoring math, gates and EN/ES text are final -- port, don't redesign).
Phases: 1 backend (done), 2 Godot screens (brain menu, test runner, results),
3 leaderboards / Daily Brain / Duels, 4 certificate + Google Play build.
Live since 2026-10-03: migration run in the SQL editor, functions deployed with the
Supabase CLI (`%LOCALAPPDATA%\Programs\supabase\supabase.exe functions deploy
--project-ref swyzfsyvmqxabhvvhhtn --use-api`, PowerShell needs `& "..."`).

**Phase 2 client (pack `voodoo_iq`, released 2026-10-03, `min_build` 30)** in
`scripts/games/voodoo_iq/`: `_game.gd` (brain-map home + setup, profile form, runner for
IQ Test and Blitz, results), `_items.gd` (one view per generator, a port of each
prototype `mount()`; emits the value the server's checkAnswer expects), `_art.gd`
(the prototype's SVG drawings as draw calls, in the prototype's own coordinates via
an SVG viewBox mapping + a small SVG path parser), `_audio.gd` (tones rendered to
AudioStreamWAV), `_api.gd` (Edge Function calls), `_text.gd` + `_data.json`.
- **The pack's text is the prototype's**: `voodoo_iq_data.json` (STR in EN/ES, colors,
  icons, brain map, palettes) is generated by `deno run --allow-read --allow-write
  tools/iq_extract.ts`; never hand-edit it. Only the few new client strings and the
  help card go through es.json.
- **Token**: `_api.gd` reads `Auth.access_token` and calls `Auth._ensure_fresh_token()`
  (refresh + single-flight), both in every app since accounts -- no APK change needed.
- Blitz gets no per-item right/wrong feedback (the client never has keys); the score
  arrives from blitz-submit at the end.
- **No daily limit on ranked IQ** (user's decision 2026-10-03, after a disconnect
  cost them the day's attempt): spec §2's one-per-scope-per-day is gone from
  session-start; the Daily Brain keeps its once a day. Standings still combine the
  last 3 sessions and rank by estimate - 2 SE.
- **Leaderboards** (pack v2): the `leaderboard` function builds the Voodoo IQ, 9-Mind,
  section and Blitz boards server-side with `standings.ts` + filters; the 🏆 screen
  (home top bar, under Setup, and on results) is the prototype's boards page.
- **Width comes from the visible screen**, never 680: `_fit_width()` = viewport width
  minus the safe-area offsets, re-run on `size_changed` (Settings applies the text size
  after `_ready`). At Large text a phone has ~600 units; measuring the root Control was
  wrong because too-wide content stretches it. Test phone layouts in a phone-shaped
  window (`--resolution 300x650`): a 540x960 request gets shrunk by Windows to a wider
  shape that hides the bug.
- **∞ Endless IQ tests are the default** (`dur: 0`, user 2026-10-03): no clock and no
  per-question limit (`judge(..., untimed)`; the motor trials keep their own speed and
  the too-fast rule stays). The player taps Finish. A test left open is scored with its
  answers by `closeStaleSessions()`: on the next session-start, and by `leaderboard`
  after 30 idle minutes.
- **Nothing hidden or capped** (user 2026-10-03, replacing spec §3's cautious rank score,
  the 129 cap and the 55-145 display clamp): boards rank everyone by IQ(theta) and mark
  `verified` with a ✓; `fmt_iq` shows the real number. `standings.ts` itself stays 1:1
  with the prototype (the parity tests check it); the policy lives in `leaderboard`.
  The EAP grid (theta -4..4) still bounds estimates to IQ 40-160.
- Not built yet: the prototype's untimed "Try an example" (needs a server endpoint),
  its fonts, Daily Brain / Duels (Phase 3). Cube stacks use the prototype's
  2D isometric drawing, not the spec's "real 3D", because the server's visibility check
  uses exactly that projection.
- Testing without a release: the hub lists games from the LIVE manifest, so a new
  game has no tile until manifest.json is pushed. Run the scene directly instead:
  `godot --path . res://scenes/games/voodoo_iq/voodoo_iq.tscn` (same user data, so
  the PC build's sign-in carries over).

- **The server is the referee**: items are generated and scored in Supabase Edge
  Functions (`supabase/functions/`, TypeScript/Deno). The client gets render params
  (`display`) only; answer keys stay in `responses.answer_key`.
- `supabase/functions/_shared/`: `rng.ts` (mulberry32 -- its whole state is one int32,
  saved in `sessions.state.rng` so an adaptive test resumes across calls), `irt.ts`,
  `gens/` (all 27 generators; `gens/data.ts` is extracted verbatim from the prototype --
  re-extract, don't hand-edit), `engine.ts` (next item, scoreIQ, Blitz), `standings.ts`
  (gates), `session.ts` (finishing + board writes), `http.ts`.
- Functions: `session-start`, `item-answer`, `session-finish`, `blitz-submit`, plus
  `profile-save` (clients can't write `profiles`). Each has `index.ts` (just `serve`) and
  `handler.ts` (the logic, imported by the tests). Request/response shapes are in each
  handler's header comment.
- **Tables + RLS**: `supabase/migrations/20261003000000_voodoo_iq.sql` (spec §4 plus a
  `sessions.state` column and the `profiles_public` view). Clients read the leaderboard
  tables; nothing is client-writable. Run it once in the SQL editor / `supabase db push`.
- **Tests** (`supabase/functions/_tests/`, Deno): `gens_test` (every generator, d 1..10,
  en/es: exactly one correct answer, checked independently), `parity_test` (the port vs
  the prototype's own JS, seed for seed: metadata, display params via a probe injected into
  each `mount()`, RNG consumption, adaptive sequences, scoreIQ, standings), `engine_test`,
  `functions_test` (handlers end to end on an in-memory `FakeDb`). Run:
  `deno test --allow-read --allow-env supabase/functions/_tests/` (`GEN_SEEDS=1000` for a
  deeper run, ~2 min).
- **One deliberate deviation**: `melody` rebuilds a melody when no note can change validly
  (the prototype keeps an unchanged copy, ~1 in 100,000 items at d = 8, no correct answer).
- **`real` columns are never used for math**: `responses.a/b/c` are float4; the engine rebuilds them
  from the generator and stored key so estimates match the prototype's doubles.

## Catalog conventions (since the catalog was completed, 2026-09-30)

- **No "coming soon" tiles**: every catalog entry is a real game. Add a
  placeholder only if the user asks for one.
- **Trademark-safe titles**: the app is heading for public distribution, so
  games use generic names, not brand names (Block Drop, not Tetris; Sea
  Battle, Box Pusher, Code Breaker, Calcudoku, Word Hunt, Yacht Dice, Paddle
  Ball, Brick Breaker, Bird Hop, Alien Attack, Frog Crossing, Party Spinner).
  "Wordle" predates this and is a NYT trademark -- rename it before a public
  store listing.
- **Card games** each carry their own copy of `<id>_cards.gd` (ints 0..51,
  `draw_card()`), so every pack stays self-contained; fix bugs in all copies.
- **Word lists**: Word Hunt and Anagrams ship the public-domain ENABLE list as
  gzipped text (`<id>_words.txt.gz`, read with `decompress_dynamic` and
  searched with `PackedStringArray.bsearch`). Non-resource files only get
  into an export through `include_filter`: pack presets already include the
  game folder; the `WindowsTest` preset has `scripts/games/*/*.txt.gz`.
  Word Hunt is English-only (no Spanish dictionary yet); Word Search,
  Crossword and Anagrams switch to Spanish content.
- Most new games draw their board in one Control via its `draw` signal
  (`board.draw.connect(_draw_board)`) instead of a grid of Buttons.

## 22 new games + 2-player modes -- 2026-10-04 (93 games)

All packs only (no APK change), built with the usual pattern (engine tested
headlessly, Home kit, GameInfo, Sfx, EN/ES, save/Resume).

- **New**: Pipe Flow, Bubble Pop, Sketch It (draw-and-guess, word list in
  `sketch_it_words.json`), Five in a Row (online), Dominoes, Mahjong Solitaire
  (deals made by "un-playing" the layout, so always solvable), Tri-Peaks,
  Hearts, Rock Blaster, City Defense, Maze Muncher, Moon Lander, Stack Tower,
  Sky Hop, Flood It, Block Collapse (`same_game`), Binary Grid (puzzles kept
  only while pure rule-logic still solves them -- fast and no guessing), Hex
  (Monte-Carlo playout computer; online), Would You Rather + Truth or Dare
  (decks in `<id>_cards.json`, EN/ES, like Trivia), Video Poker (play credits
  only), Air Hockey (multi-touch 2 players).
- **Pass-and-play pattern** (Sea Battle, Liar's Dice, Crazy Eights, Go Fish,
  Gin Rummy): a full-screen opaque `cover` ("Pass the phone to Player N" +
  I'm ready) whenever the phone changes hands; `viewer` = the seat whose cards
  are face up, set when I'm ready is tapped; drawing returns early while the
  cover shows. Engines that assumed "seat 0 = you" now take a player count
  (`PLAYERS` is a var). Yacht is 2-4 scorecards swapped into the engine;
  War has a Flip button per player; Speed puts Player 2's hand at the top,
  drawn upside down (`draw_set_transform(c, PI)`), both tapping at once.
- **Air Hockey bots**: two perfect-defender bots never score -- test the
  engine with a bank-shot bot, not two mirror bots.
- **Bash heredocs mangle `\\`**: a `"\\n"` inside a heredoc'd Python patch
  becomes a real newline in the .gd file. Write patch scripts with the Write
  tool (or check with `grep -n` after) -- it broke three files this session.
- `--check-only` catches GDScript parse errors in an engine before a test
  hangs on it: `godot --headless --path . --check-only --script res://...`.
  An engine that fails to parse makes `load(...).new()` fail and a test
  script never reaches `quit()`.
- GameInfo's confetti (`game_info.gd` `_draw_party`) logs "triangulation
  failed" in headless tests at zero size -- harmless, APK-side.

## The last 7 to 100 games -- 2026-10-04

Packs only, all in Arcade, each with Home kit, GameInfo, Sfx, EN/ES and
save/Resume. The arcade ones have Easy / Normal / Hard rows on Home and a
"Best score (%s)" stat per level.

- **Barrel Climb** (`barrel_climb`, Donkey Kong-like): six slanted girders
  (`y_at(floor, x)`; each leans down the way barrels roll and is open at
  that end), random ladders per level, the Bone King throws barrels, a
  hammer pickup, a BONUS countdown (0 = a life lost).
- **Cannon Duel** (`cannon_duel`, Worms-like): heightmap ground with
  craters (`_explode` removes the circle's overlap, what was above falls),
  wind, 3 weapons, driving with fuel; vs CPU x3 or 2 players.
  **The CPU's aim search uses `predict()`, a tight local-variable copy of
  the shell physics** -- going through the Dictionary-based `_advance` was
  ~30x slower (minutes per test). Keep the two in step if the physics change.
- **Crypt Crawler** (`crypt_crawler`, Doom-like): a DDA raycaster
  (`engine.cast`, 120 columns), neon wall edges drawn as polylines broken
  at every face change, billboard sprites hidden by a per-column z-buffer,
  maze floors (backtracker + loops + halls), skulls / wraiths / brutes.
- **Star Runner** (`star_runner`, Star Fox-like): pseudo-3D (x, y, z) with
  `_proj()`; the view is stretched upright (`V_STRETCH`) and the camera
  rides above the ship, or on a tall phone the ship sits on the horizon.
- **Sky Raider** (`sky_raider`): vertical shooter, relative-drag steering,
  tiny hitbox, P / B / 1UP drops, a battleship per stage.
- **Mini Golf** (`mini_golf`): 18 holes as data in `HOLES` (outline,
  blocks, sand, water, slopes, bumpers, mills, sliders; rects are
  `[x0, y0, x1, y1]`); Front 9 / Back 9 / 18 picker; 1-4 players pass the
  phone. Moving parts also push a resting ball (`_hit_moving`). New holes:
  check them with a brute-force bot (try ~400 putts per stroke, score by
  BFS path distance to the cup) -- every hole must be holed and the ball
  must never leave the outline.
- **Pool** (`pool`): 8-ball with the rules in `resolve()` (targets fixed at
  `shoot()` time in `shot_targets`), ghost-ball guide, ball in hand, vs CPU
  x3 or 2 players. Hard tries its best 4 shots on `clone()`s; **the CPU
  thinks on a `WorkerThreadPool` task** (`_cpu_think`, waited for in
  `_exit_tree`) so the table keeps animating.
- Balance was set with bots in throwaway tests: Star Runner / Sky Raider
  "a random or dodging bot survives Easy, mostly dies on Hard", Cannon Duel
  CPU vs CPU shots-to-win by level, Pool Hard beats Easy ~90%.

## Hub look changes -- since v0.24.0 (2026-10-03)

- **Sign Out is only in Options**; the home screen shows the name (signed in)
  or a Sign In button.
- **Not-downloaded tiles are dim blue, never red** (red reads as "bad").
- **Tile icons drawn in code**: `scripts/common/game_icons.gd` (neon vector
  with depth: shaded spheres, stacked discs, bevelled slabs) for chess,
  sudoku, tictactoe, connect4, checkers, reversi, three_man. Other games
  still use their manifest emoji; add more by adding `_icon_<id>` + the id to
  `IDS` (header comment). The user wants better icons for "many more".
- **Three Man's dice are drawn** (the Unicode die glyphs are missing from
  phone fonts). Never use those glyphs for dice in a game.

## Reference material

**Art / graphics standards: `reference/art/ART_STYLE.md`** -- the target
look for the hub and every game (neon vector glow on near-black, voodoo
motifs), with the user's mood-board images beside it. Read it before
designing or restyling any visuals. The images are references only (never
shipped; `reference/art/` has a `.gdignore`); art stays drawn in code.

`reference/juegoflix_friend_reference.html` — a friend's competing 20-game hub
(single-file HTML), saved for layout/game-idea inspiration. Never copy from it
literally; used so far for the per-game-icon tile layout idea and drinking game
rules.
