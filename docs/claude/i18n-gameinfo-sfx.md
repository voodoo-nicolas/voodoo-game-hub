# Languages, GameInfo, Sfx (APK-side)

## Languages EN/ES
- `Lang` autoload (`lang.gd`): first launch follows the phone; hub Options switches (`user://language.json`). Godot translates Label/Button text automatically when an exact English-string translation exists.
- Source of truth `tools/i18n/es.json` (English -> Spanish; `null` = not UI text). `python tools/hub.py i18n` regenerates `scripts/common/strings_es.gd` (APK) and each catalog game's `scripts/games/<id>/<id>_i18n.gd` (pack). Unfound strings go to `tools/i18n/untranslated.json`: translate, rerun. Never hand-edit generated files.
- Every game's `_ready()` starts with `preload("res://scripts/games/<id>/<id>_i18n.gd").install(self)` (registers with TranslationServer, so packs work on pre-Lang apps).
- Formatted/concatenated text goes through `tr()` first: `tr("Score: %d") % score`, `tr("Your turn (%s)") % tr("White")`. Not in `const` initialisers (call `tr()` where used). Static functions: `str(TranslationServer.translate("..."))`.
- Never `tr()` data: server-bound or logic-compared text stays English (e.g. default display name "Player").
- Extractor skips ALL-CAPS literals (word lists): write `tr("Code").to_upper()`.
- Names: `"title_es"`/`"name_es"` in manifest (`Lang.pick(entry, "title")`).
- Word games switch content when `TranslationServer.get_locale().begins_with("es")` (Hangman, Wordle: accents dropped, Ñ kept, Ñ key). Wordle English guesses checked against `wordle_words.txt.gz` (ENABLE 5-letter + answers); Spanish accepts any 5 letters. Word Hunt English-only; Word Search, Crossword, Anagrams switch.
- Same English word, different Spanish per game: use a distinct key (Poker's `"Check "` with trailing space -> "Pasar"; plain "Check" is "Revisar").
- Spanish style: neutral Latin American, "tú". Game Home is "🏠 Menú", hub is "Inicio".

## GameInfo (`game_info.gd`; header = how-to)
- How to Play card (🎯 Goal, 📋 How, 💡 Tips, 📊 Your Stats) opened from the Landing ❓ or the pause menu (not automatically). Pauses the tree.
- Text in `scripts/games/<id>/<id>_help.gd` (pack): constants only: `ID`, `TITLE`, `GOAL`, `HOW`, `TIPS`, `STATS` (keys always shown, in order); optional `ACHIEVEMENTS`, `FACTS`. Write from the game's actual code, not general knowledge. Strings go through es.json.
- Stats in `user://stats_<id>.json`: `info.result("win"|"loss"|"draw")` (streaks/win rate free; online passes `true` for "Online wins"), `info.add(key)`, `info.high(key,v)`, `info.low(key,v)` (true on new record), `info.summary()`, `start_clock()`/`stop_clock()`. Keys containing "time" show m:ss. Per-variant keys: `"Best time (%s)" % "Hard"`.
- **Load, never preload** (`GAME_INFO_PATH`, `var info = null`, guard every use with `if info:`).
- Record each result once: `result_recorded` flag reset on new game, or `just_ended := game_active` guard in `_show_result()`.
- Games with their own best file (and account-synced Snake/Simon/Whack-a-Mole) keep it AND feed GameInfo `high()`, including when `reconcile_stat` merges a higher cloud value.
- Anything that must run while paused sets `process_mode = PROCESS_MODE_ALWAYS`.
- Test scripts driving a game must call `game.info.close()` first (its first-play card pauses the tree).
- Confetti "triangulation failed" in headless tests is harmless.

## Sfx (`sfx.gd`, autoload `Sfx`; header lists every name)
- Basic (tap, back, toggle, invalid, win, lose, draw, record, tick, notify) + sets (Cards, Board, Dice & Party, Arcade, Word). All synthesized in code on a worker thread at launch (web: one sound per frame). `assets/sfx/<name>.ogg` replaces one with a recording, no code change.
- Free: every button press plays "tap"; GameInfo plays win/lose/draw/record. `btn.set_meta("sfx", "key")` changes it, `""` silences (when the game plays its own).
- **Games never reference `Sfx` directly**: tiny `_sfx(name)` using `get_node_or_null("/root/Sfx")`. No `min_build`.
- A sound only one game uses lives in its pack, played with `Sfx.play_stream(stream, 0.0, 1.0, group)`.
- Every sound belongs to a group (`Sfx.GROUP_OF`; unlisted = "game"); `play_stream` applies Settings (`group_db`). New tap/result/alert library sounds must be added to `GROUP_OF`.
- Every game plays its own action sounds. Number-pad puzzles rely on free key taps. Arcade engines that don't report events derive sounds from per-frame state deltas.

## Shared sound library (`media/common/sfx/`; catalog `docs/claude/sfx-library.md`)
Owner rule (2026-10-24): **games take their recorded sounds from the shared library**; a sound goes into one game's `games/<id>/` only when the library has nothing that fits (and if more games could use it, it goes into the library instead).
- 112 sounds in 7 sets, 356 files, 6.1 MB: `casino` (cards, chips, dice), `rpg` (books, doors, footsteps, cloth, coins, knives, metal), `impact` (glass, metal, wood, plates, punches, footsteps on 5 surfaces), `scifi` (lasers, explosions, engines, force field, doors), `voice` (announcer: fight, round_1..5, count_1..10, you_win, you_lose, its_a_tie, game_over...), `ambient/crowd_chatter`, `weather/thunder_rain`. Kenney CC0 packs + two owner-supplied files.
- Owner's master copy: `D:/dev/audio`. Add sounds there, then `python tools/sfx_import.py D:/dev/audio`: names to snake_case, takes to `<name>_1.._N`, a name repeating its set drops it (`impact/metal_heavy`), heavy OGGs and other formats encoded by ffmpeg, folder credit in `media/CREDITS.json` (one entry per set folder, `"file"` ends in `/`), licence proof in `media/licenses/sfx/`, catalog regenerated. Then Godot `--headless --import`, `hub.py sync`. It never deletes; NC/ND refused; a set without a licence file is recorded as the owner's statement (`OWNER_SFX.md`).
- **Player**: `scripts/games/<id>/sound_lib.gd`, copied from `tools/templates/sound_lib.gd` by `sync` (like `home_kit.gd`; edit the template only). `const SoundLib = preload("res://scripts/games/<id>/sound_lib.gd")`, then `SoundLib.play(self, "casino/card_slide")` (a random take, never the same twice running; `volume_db`, `group`, `pitch` optional) or `var p := SoundLib.loop(self, "weather/thunder_rain", -10.0)` (child player; `queue_free()` stops it). Goes through `Sfx.play_stream`, so the player's sound groups apply; silent on apps before v0.23. No `min_build`.
- **Write each id as a full string literal** (`"casino/chip_lay"`): `hub.py sync` scans the game's scripts and adds exactly those files to its pack preset, so the pack carries them (~20-80 KB a sound) and they play on every app version. The APK, AndroidPlay and HubOnly presets exclude `media/common/sfx/*`; the Web build carries the whole library. `hub.py check` fails on an id the library lacks. A changed sound list = bump the pack.
- Keep synthesized `Sfx` for UI (taps, keys, toggles, results, alerts: 0 bytes, app-wide). Use the library for physical game actions and voice.
- **Existing games, next update** (when a game is touched for any reason, swap its synth action sounds where the library has a real one; leave the rest). Suggested swaps: `card_deal` → `casino/card_slide`, `card_place` → `casino/card_place`, `card_shuffle` → `casino/card_shuffle`, `card_flip` → `casino/card_shove`, `chip` → `casino/chip_lay` (stacks: `casino/chips_stack`), `dice_roll` → `casino/dice_shake` + `casino/dice_throw` (one die: `casino/die_throw`), `place`/`capture` (wooden pieces) → `impact/wood_light` / `impact/wood_medium`, `slide` (stone/tiles) → `impact/plate_light`, `shoot` → `scifi/laser_small` (retro games: `scifi/laser_retro`), `explode` → `scifi/explosion_crunch` (big: `scifi/low_frequency_explosion`), `hit` → `impact/punch_medium` or `scifi/impact_metal`. Versus/arcade starts can add `voice/ready`, `voice/fight`, `voice/round_N`, countdowns `voice/count_N`. Listen first; keep a synth sound that fits better. `voice/kill_*` only where the game's rating allows.
- Test: `godot --headless --path . --script res://tools/test_sound_lib.gd`.
