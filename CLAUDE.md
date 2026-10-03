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
  Connect Four, Checkers, Reversi, Chess, Mancala, Dots and Boxes.
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
2. **`<id>_game.gd`** — `extends Control`, builds its entire UI in code. Always:
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
     Short round-based games (Simon, Hangman, the drinking games) skip this.
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

- Key: `C:\Users\Cliente\Android\keystore\voodoo-release.keystore`
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

No admin rights on this machine, so everything below was installed as a portable
zip rather than via an installer, and none of it is on PATH. Bash tool calls
`powershell.exe` in a way that mangles `$_`/env-var syntax — use the PowerShell
tool directly for anything needing real PowerShell semantics, not
`Bash("powershell.exe ...")`.

- **Godot 4.7.2**: `C:\Users\Cliente\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- **Android SDK**: `C:\Users\Cliente\Android\sdk` (cmdline-tools, platform-tools, build-tools 34.0.0, platforms)
- **JDK**: `C:\Users\Cliente\Android\jdk-17.0.20.1+1`
- **Debug keystore**: `C:\Users\Cliente\Android\keystore\debug.keystore`
- **Python 3.12** (runs `tools/hub.py`): on PATH as `python`.
- **GitHub CLI**: `C:\Program Files\GitHub CLI\gh.exe` (authenticated as `voodoo-nicolas`)

Second PC (user `nick_`, set up 2026-10-02 for editing and testing only):
Godot 4.7.2 at the same WinGet path (so `hub.py` finds it), Python 3.12 at
`%LOCALAPPDATA%\Programs\Python\Python312\python.exe` (not on PATH), Git at
`C:\Program Files\Git\cmd\git.exe`. No GitHub CLI, Android SDK, JDK or
release keystore there: build the APK, publish packs and release from the
main PC. Windows was reinstalled 2026-10-03; since then the Godot 4.7.2
Windows export templates are installed (only `windows_*` extracted from the
official .tpz into `%APPDATA%\Godot\export_templates\4.7.2.stable`), so
`hub.py pc` works there. Its Desktop is redirected to OneDrive (`hub.py pc`
asks Windows for the Desktop path).

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

## Reference material

`reference/juegoflix_friend_reference.html` — a friend's competing 20-game hub
(single-file HTML), saved for layout/game-idea inspiration. Never copy from it
literally; used so far for the per-game-icon tile layout idea and drinking game
rules.
