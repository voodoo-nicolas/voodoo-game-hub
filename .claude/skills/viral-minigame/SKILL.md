---
name: viral-minigame
description: Build or modify a minigame for Viral Game Hub (Godot 4 / GDScript, downloadable .pck packs). Use when creating a new game, restyling or fixing an existing one, or checking a game against the hub's standards and Definition of done.
---

# Viral Game Hub — minigame standards and creation

Read `docs/STANDARDS.md` for full text and `docs/claude/*.md` for system details (landing-kit-skins, i18n-gameinfo-sfx, music, accounts-online, games-notes, web-build). This skill is the checklist.

## 1. Create
1. `python tools/hub.py new-game <id> --title "Title" --icon "🎲" --category "Cards"` → makes `scripts/games/<id>/<id>_engine.gd`, `<id>_game.gd`, `scenes/games/<id>/<id>.tscn` from `tools/templates/`, adds the manifest entry and export preset. References: `red_or_black`, `three_man` (simple); `sudoku`, `solitaire` (complex).
2. Files per game:
   - `<id>_engine.gd`: `extends RefCounted`, pure logic, no Nodes, headless-testable.
   - `<id>_game.gd`: `extends Control`, whole UI built in code, Landing kit wired in.
   - `<id>_help.gd`: constants only: `ID`, `TITLE`, `GOAL`, `HOW`, `TIPS`, `STATS`, optional `ACHIEVEMENTS`, `FACTS`. Written from the game's actual code.
   - `<id>_i18n.gd`: generated (`python tools/hub.py i18n`); never hand-edit.
3. `_ready()`: `Orientation.lock_portrait()` (or landscape) first; `preload("res://scripts/games/<id>/<id>_i18n.gd").install(self)`; build UI. No `SettingsDrawer` (the kit frees it).
4. Set manifest fields: category entry, `title_es`, `modes` ("online,local,party,cpu"), `board` (stat ranked; omitted = "Best score", `"none"` = no board), `learn` tags, `skins`, `quick`/`original` flags, `min_build` only if unavoidable.
5. Never edit generated things: pack presets, `games` url/scene, `strings_es.gd`, `<id>_i18n.gd`, kit copies (edit `tools/templates/home_kit.gd`, run `hub.py sync`).

## 2. Navigation (every game, no exceptions)
- Landing is the only screen with "← Hub". Every other screen has 🏠 Home → Landing; deeper screens also ‹ Back.
- Selecting a game anywhere opens its Landing. Android back = one step up (Landing → Hub; during play → pause menu, never exits).
- Leaving play saves via `SaveUtil`. Landing → play ≤ 2 screens; Resume and Quick Play = 1 tap.
- Navigation comes from the Landing kit; games register modes, never hand-roll back buttons.

## 3. Landing, setup, pause
- Landing (kit): hero art/title/tagline, ▶ Resume (only if a save exists), ⚡ Quick Play (last mode+difficulty), 🎮 Single player, 👥 Multiplayer, 🏆, 🏅, ❓, ⚙ Options, ← Hub.
- Setup: mode → difficulty → mode options → Start; remembers last choice. Mode names: Classic, Campaign/Levels, Time Trial, Survival/Endless, Zen/Practice, Daily Challenge, Vs CPU, Custom. Difficulty: Easy, Normal, Hard (+Expert).
- Multiplayer: local (player count, names) or online (invite friend, create room with code+link+QR, join by code, rejoin).
- Pause (visible button in safe area; timers/animations/AI stop): Resume / Restart / How to Play / 🏆 / 📊 / 📸 / ⚙ Options / 🏠 Home. Online: no Restart, "Leave match" with forfeit warning.
- Saves: only Home "New …" buttons delete a save; `_ready()` must not (use a `started` flag; `_save_game()` skips when false). Save on pause, exit, app suspend. A game with nothing worth keeping may skip saving (say so in help).
- Kit pauses the tree while Home/pause shows: a game that starts in `_ready()` waits underneath; mode buttons must start a fresh game.

## 4. Options and layout
- App-wide settings (sound, volume, vibration, theme, text size, rotate, notifications) come from `Settings` via `get_node_or_null("/root/Settings")`; games never reference it directly. Per-game: skin, default mode/difficulty, game toggles.
- Everything inside the safe area (≈24 units top); lay out from the root Control's rect, never window coordinates, never assume 720 wide. Test text scale 1.0 and 1.4, portrait and landscape; `VOODOO_SAFE_INSET="l,t,r,b"`.

## 5. Skins and art
- Classic (default; traditional colours, ignores light/dark theme) and Voodoo (neon on near-black, opt-in; skulls/bones/dolls). Implement `_set_skin("classic"|"voodoo")` (re-skin in place, no reload) and `_current_skin()` if the game keeps its own choice; declare `"skins"` in the manifest. Older `_set_voodoo(on)` still works.
- Kit screens use one blue button colour, green only for Start/Resume. Default backgrounds: felt for card games, leather for others; arcade games keep their own background.
- Contrast ≥ 4.5:1; colour never the only cue. Draw in code where possible; never use Unicode die glyphs (draw dice).
- Original or licensed art only; no trademarked names, logos, characters, card/board art or copied rules text. Generic titles (see IP audit). Pass `docs/IP_AUDIT.md` checklist.

## 6. Shared systems (all APK-side: guard every use)
Packs run on older apps: use `get_node_or_null()` / `ResourceLoader.exists()` + `load()`; never `preload` APK-side scripts (online, GameInfo, Voodoo). New APK need → `"min_build"`.
- **GameInfo**: `var info = null`, load via `GAME_INFO_PATH`, guard with `if info:`. `info.result("win"|"loss"|"draw")` exactly once per game (flag reset on new game), `info.add/high/low`, `info.summary()`. Games with their own best file keep it and also feed `high()`.
- **Sfx**: tiny `_sfx(name)` via `get_node_or_null("/root/Sfx")`; every button already taps; `set_meta("sfx", "")` silences. New tap/result/alert sounds → `Sfx.GROUP_OF`.
- **Music**: only from the shared `Music` autoload via a guarded `_music()`; never synthesize or ship own music.
- **Leaderboards**: game with a score/counter has 🏆 (Everyone/Friends). Lower-is-better → growing counter or none.
- **Achievements**: 🏅 generic badges come free from stats; add `ACHIEVEMENTS` in `_help.gd` for bragging moments.
- **Online** (if applicable): `OnlineMatch` from `scripts/common/online_match.gd`; game supplies `_online_state()` (JSON-safe whole state), applies `remote_move`/`remote_state`, calls `send_move()`. Host is authority. Online games are never saved locally; an online end must not delete the local save. Add a driver in `tools/test_online_pair.gd`.
- **Pass-and-play**: opaque "Pass the phone to Player N" cover whenever the phone changes hands; `viewer` seat set on "I'm ready".
- Anything that must run while paused: `process_mode = PROCESS_MODE_ALWAYS`.

## 7. i18n
- Every string EN + ES: add to `tools/i18n/es.json`, then `python tools/hub.py i18n`. Spanish: neutral Latin American, "tú". Game/category names via `title_es`/`name_es`.
- Formatted text through `tr()` first: `tr("Score: %d") % score`; not in `const`; static functions use `str(TranslationServer.translate(...))`. Never `tr()` data (server-bound or logic-compared). ALL-CAPS: `tr("Code").to_upper()`. Same English word, different Spanish → distinct key.
- Word games switch word lists by locale.

## 8. Media and licences
- Free/CC0/self-made first. Every asset: `media/CREDITS.json` entry + licence proof in `media/licenses/`. Allowed: own, CC0, CC-BY (credit in About). Never NC/ND. AI assets: record tool + plan.
- Tiers: hub (APK) → common → category (needs ≥ 3 games) → game (`res://games/<id>/`). OGG Vorbis, music ~96 kbps, ≈ −16 LUFS. Never overwrite a mounted pack; namespace media paths.

## 9. Learning hook and content rules
- Manifest `learn` tags; optional `const FACTS` in `_help.gd` (checked facts about the game's own subject; no pop quizzes in arcade games; never block play). Don't market as kids' education.
- **No alcohol references anywhere** (Drinking Games category is archived).

## 10. Code rules
- Async callbacks must not touch a freed scene: connect methods, not lambdas; use node `create_tween()` or child `Timer`; never `await get_tree().create_timer()`; `create_timer(t, false)` if used.
- `queue_free()` (never `free()`) when rebuilding nodes inside their own signal handler.
- Never connect lambdas to autoload signals (`.unbind(n)` methods instead).
- Phones send taps twice: handle `MouseButton` only for single taps; multi-touch games ignore mouse when `DisplayServer.is_touchscreen_available()`.
- `font_disabled_color` for disabled buttons; `set_anchors_and_offsets_preset()` on nodes already in the tree.
- Every `HTTPRequest` sets `timeout = Config.HTTP_TIMEOUT`.
- Web build has no threads: avoid `Thread`; otherwise branch on `OS.has_feature("web")` (lint enforces).
- Card games carry their own `<id>_cards.gd`; fix bugs in all copies.
- Never remove owner comments (`//`, `/* */`, `#`).

## 11. Definition of done
Meets every applicable section above: navigation, Landing, setup, pause/save/resume, options, 🏆 + 🏅, both skins (or documented why not), safe area, text scale 1.0–1.4, EN+ES complete, shared media tiers, `CREDITS.json`, IP checklist, `python tools/hub.py check` green.

## 12. Ship (ask the owner before publish-packs and release)
1. Headless logic test (throwaway `SceneTree` script; randomness → many trials asserting invariants).
2. `python tools/hub.py check` and `python tools/hub.py test <id>` (back up `%APPDATA%\Godot\app_userdata\Voodoo` first: tests touch real saves).
3. `python tools/hub.py bump-pack <id>`.
4. `python tools/hub.py export <id>`.
5. Ask → `python tools/hub.py publish-packs <id>`.
6. Commit + push; **`manifest.json` last**.
7. `python tools/hub.py verify`. Summarize in ≤ 5 lines.
8. Optional: `python tools/hub.py pc` (PC build) / `web --publish` (iPhone build).
