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
