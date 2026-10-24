# Turned — how to run it and ship it

Gothic top-down story game, 1900, in the Viral Game Hub (Adventure category, landscape). First slice: the prologue and Day 1 in Vellmoor. Brief: [BRIEF.md](BRIEF.md). Story: [story_bible.md](story_bible.md). Choices: [DECISIONS.md](DECISIONS.md). Code notes: `docs/claude/turned.md`.

## Run it (PC, keyboard)
Godot 4.7.2 (`C:\Users\nick_\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\`):

```bash
godot --path . res://scenes/games/turned/turned.tscn
```

Or open the project in the editor and press F6 on `scenes/games/turned/turned.tscn`; or run the hub (F5), open Adventure → Turned. Tap **Begin the story**.

| Key | Does |
|---|---|
| Arrows / WASD | D-pad (two together walk diagonally) |
| E | A: sit up, wipe your face, read, take, talk, open |
| Shift | B: sneak (after the alley) |
| Esc | Pause (the hub's pause menu) |
| Tab | Menu: Journal, Quest log (after your first clue) |
| F10 | (debug builds) drop to 3 Health, to see a death quickly |
| F9 | (debug builds) move the clock on one hour, to see dusk, night and the moon |
| F8 | (debug builds) play the dialogue test scene (a line, a choice, an item) |

The mouse works on the on-screen buttons too (until the first real touch).

The path of the slice: wake in bed → A (sit up) → A (wipe your face) → the d-pad appears → read the three clues → bathroom mirror → (optional) the scarf by the front door → front door → the street: the sun burns, find shade (porch, awnings, trees) → talk to the man in the grey coat → the alley at the east end gives you B → die in the sun to see the respawn → Esc, then Home and ▶ Resume to reload the autosave.

## Test it
```bash
godot --headless --path . --script res://tools/test_turned.gd      # 1030 checks: tuning, maps, rules, the whole slice, touch overlay, day/night
python tools/hub.py check
python tools/hub.py test turned
godot --path . --resolution 1280x720 --script res://tools/shot_turned.gd -- <out_dir> [text size 0|1|2]   # plays the slice and saves 25 screenshots (needs a window)
godot --path . --resolution 1280x720 --script res://tools/shot_turned_scene.gd -- <out_dir> [text size 0|1|2]   # Scene mode (the dev_ scenes, placeholder paintings): the fit, margins and chips; try 1560x720, 1024x768
```
`shot_turned.gd` and `test_turned.gd` write `user://turned_save.json` and put a real one back afterwards. Try `--resolution 1170x540` (phone), `405x720` (portrait) and text size `2` (1.4x).

## Tuning
Everything numeric is in `scripts/games/turned/turned_tuning.json` (speeds, Health, sun damage, death penalties, sneak radii, prologue timings, HUD sizes, camera). Nothing to rebuild; run the game again.

## Art
The look is made in code (lit shader surfaces, outlined people). Painted art swaps in by file name: see [ART_SPEC.md](ART_SPEC.md) (names, 2x sizes, anchors, tiles, AI prompt). Screenshots of both areas: `godot --path . --resolution 1280x720 --script res://tools/shot_turned_area.gd -- <out_dir>` (also prints ms/frame). If a phone is slow set `art.use_shaders` to false in the tuning file.

## Android
The hub ships games as packs on GitHub Releases, so there is no separate Turned APK:

1. `python tools/hub.py check` and `python tools/hub.py test turned` (green).
2. `python tools/hub.py export turned` → `builds/packs/turned.pck` (about 170 KB).
3. **Ask the owner**, then `python tools/hub.py publish-packs turned`.
4. Commit and push, `manifest.json` **last** (its `turned` entry is already added: pushing it before step 3 would list a game whose download fails).
5. `python tools/hub.py verify`.
6. On the phone, update the hub app (`python tools/hub.py apk` for a new APK; Turned needs no new APK: it only uses what the app has) and open Turned from Adventure.

For testing on a PC before publishing, `python tools/hub.py pc` builds the Windows version with every game built in (`%LOCALAPPDATA%\VoodooGameHub\Voodoo.exe`). A phone gets Turned only through the published pack.
