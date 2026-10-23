# Pad: the shared on-screen controller (started 2026-10-23, owner + Heather's idea)

One controller for many games: a layout (stick / D-pad + buttons), a look (skin), size, opacity, handedness, all chosen **once by the player** and applied to every game that uses it. Games stop writing their own joystick code (today Last Shift, Evolution, Geometry Wars and Turned each have one). Design source: the owner's mock-ups in `D:\Dev\controls` (proportions are copied: stick ring 130, knob 60, face buttons 47 on a 79 diamond, pause/info pills 112x64, in units of a 720-high screen).

## Files (`scripts/common/pad/`, APK side)
| File | What |
|---|---|
| `pad_controller.gd` | the `Control` a game adds. Touch -> Godot actions, drawing, hit tests, `get_vector()`, `is_down()`, `set_map()`, `set_hidden()`, `set_button()`, `release_all()`, `apply_prefs()`, `step_layout()`, `step_skin()` |
| `pad_layouts.gd` | layout catalogue as DATA (`LAYOUTS`) + `place()` -> pixel shapes. Add a layout = add a dictionary |
| `pad_draw.gd` | looks (`SKINS`: neon, mono, outline) + draw functions. Add a skin = add a dictionary |
| `pad_prefs.gd` | `user://pad.json` (layout, skin, size, opacity, right_handed, floating, deadzone, dpad8, show_map) |
| `pad_options.gd` | settings panel (layout cards with live previews, look, sliders, toggles). Same pattern as `sound_options.gd`; `hub.py i18n`/lint cover this folder |

Layouts now: `stick_4`, `dpad_4`, `stick_2`, `dpad_2`, `stick_arc` (Evolution-style), `dual_stick` (move + aim, aim stick holds `pad_fire`), `stick_1`.

## Using it in a game (landscape)
```gdscript
var Pad = load("res://scripts/common/pad/pad_controller.gd")   # load(), never preload(): packs run on older apps
var pad = Pad.new()
pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
add_child(pad)
pad.set_map({"move": ["tn_left", "tn_right", "tn_up", "tn_down"], "a": ["tn_a"], "pause": ["tn_pause"]})  # optional: your own action names
# in _physics_process: pad.get_vector("move") (analog), pad.is_down("a"); or just read the actions
```
- Actions pressed: `pad_move_left/right/up/down` (analog strength), `pad_aim_*`, `pad_a/b/x/y`, `pad_pause`, `pad_info`, `pad_fire`. Keyboard defaults are registered in code (`ensure_actions`): WASD move, arrows aim, K L J I = A B X Y, Space fire, Esc pause, Tab info, so a pad game also plays on PC.
- `layout_override = "stick_2"` forces a layout; the player's look/size/opacity still apply. `default_layout` = what the game wants until the player picks one in Options (changing size/opacity does not lock it). `allowed_layouts` = the layouts the game can work with (e.g. needs A, B, Pause and Menu): Options offers only those and a saved one outside the list is ignored.
- Progressive reveal: `set_hidden(id, true)` hides a part at once (parts the game never uses: X, Y, the aim stick); `reveal(id)` shows it with a pop-in + pulse ring; `visibility_of(id)`. The face-button plate appears once two of its buttons are shown.
- `set_state(id, {"sub": "USE", "enabled": bool, "ring": bool, "icon": "menu"})`: a word under a button (shrunk to fit), dimmed when not usable (still pressable), an amber ring (sneaking), a pill's icon (pause / info / menu). `set_button(id, label, enabled)` is the older form.
- The pad **pauses with the game** (process mode pausable + lets go on `NOTIFICATION_PAUSED`), so the kit's pause menu is never pressed through; `works_while_paused = true` opts out. Parts light up from their mapped actions too (a keyboard key lights A).
- Sizing: `k = min(height/720, width/1280) * the player's size`: a tablet or portrait screen shrinks the pad instead of blowing it up.
- Opacity 0 = invisible but fully working (a touched part lights faintly). **Show button map** draws the hit areas and action names over the controller at full strength.
- Guard for old apps: `ResourceLoader.exists("res://scripts/common/pad/pad_controller.gd")`, else keep the game's own controls.

## Pad Lab (dev only, not in the catalog or manifest)
`scenes/games/pad_lab/` + `scripts/games/pad_lab/`: a ship, targets, a live readout (stick vectors, buttons down, fingers, fps), top bar to cycle layout and look, a settings drawer between the thumbs, pause = settings, info = button map. The live APK excludes `scenes/games/*`, so the Lab never ships.
- Phone: preset **PadLabDev** (package `com.viral.voodoo.padlab`, app name "<Brand> Pad Lab", arm64, every other game excluded, feature `pad_lab` main-scene override; installs beside the real app and TraceDev). Build (debug key, like TraceDev): `GODOT_ANDROID_KEYSTORE_RELEASE_PATH=<Keystore>/debug.keystore GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android godot --headless --path . --export-release PadLabDev <abs>/builds/pad_lab.apk`. Its `exclude_filter` names every other game's `scenes/games/<id>/*, scripts/games/<id>/*` (like TraceDev's): when a game is added, add it there, or the dev APK just gets bigger.
- PC: `godot --path . res://scenes/games/pad_lab/pad_lab.tscn --resolution 1280x720` (a mouse is one finger; multi-touch needs the phone).
- Screenshots: `godot --path . --resolution 1280x720 --script res://tools/shot_pad.gd -- <out_dir>` (every layout + looks + settings/map).
- Logic test: `godot --headless --path . --script res://tools/test_pad.gd` (layouts inside the screen and not overlapping at size 0.6/1.0/1.4, analog strength, dead zone, multi-finger, D-pad 4/8, floating stick, mirror, opacity 0, action map, release_all).

## Turned on the Pad (2026-10-23, owner OK with fallback)
`turned_game.gd` `_add_pad()` creates the pad under the HUD (so fades and the close-up draw over it) when `ResourceLoader.exists(PAD_PATH)`; `turned_hud.gd` `use_pad()` maps it to `tn_*`, reveals parts as the story unlocks them (`HUD name -> pad part`: dpad -> move, a, b, menu -> info), pushes the word under A and the sneak ring every frame, hides the pad during the close-up and the Journal, and forwards the pad's button signals to `a_pressed` / `b_pressed` / `pause_pressed` / `open_menu` (Input.action_press makes no input events, so the world's `_unhandled_input` never sees touch). Bars, Missions (its own tap), captions, close-up and fades stay the HUD's. **Without the pad (older apps) the HUD draws and reads its own controls exactly as before.** Allowed layouts: dpad_4 (default), stick_4, dpad_2, stick_2, stick_arc. A stick gives direction only (the player normalizes it: full speed). Tests: `tools/test_turned_pad.gd` (real Turned scene), `tools/test_turned.gd` unchanged (200 checks, fallback path). Pack not bumped or published; the new controls reach players with the next app release + pack.
- Phone test without a release: preset **TurnedDev** (`com.viral.voodoo.turneddev`, "<Brand> Turned Dev", everything but Turned excluded, feature `turned_dev`): same export command as PadLabDev with `--export-release TurnedDev builds/turned_dev.apk`.

## In-game Options hook (done 2026-10-23, option A, owner OK)
`tools/templates/home_kit.gd`: `_show_options()` adds a "🎮 Controls" section (a `PadOptions` panel, one layout card per row) when the game defines `_pad() -> Control` (returns its PadController; `_game_pad()` in the kit) and `res://scripts/common/pad/pad_options.gd` exists (older apps: no section). Games without `_pad()` look unchanged. `hub.py sync` copied the kit into every game folder (112 files) and `hub.py i18n` regenerated the game translation files; **no pack was republished and no app version was bumped**: a game gets the new kit at its next pack bump, and the section only appears on apps that carry `scripts/common/pad/` (next app release). `tools/test_pad.gd` covers the hook with a fake game.

## Not built yet (say so, don't assume)
- Only Turned uses the Pad (code on master, pack not published); the Controls section shows there once a new app + pack are out. Turned is the planned first adopter (its HUD already has D-pad, A B X Y, pause, menu, missions); then Last Shift and Evolution.
- Per-game layout memory, HUD widgets (HP/MP/XP bars, Missions chip from the mock-ups), the fantasy "gem" skin with icon buttons, sliding a thumb between face buttons, dragging parts to custom positions.
- Universal overlay (Heather's idea): an APK-side layer that sits over any game and presses its actions. Needs a per-game `controls` map in the manifest; raw-touch games (Geometry Wars, Pool, card games) would need adapters.
- APK side: `scripts/common/pad/`, `project.godot` (`run/main_scene.pad_lab`) changed, **no `bump-app` yet**. Packs that use the Pad need `min_build` or the `ResourceLoader.exists` fallback. Add a STANDARDS section + a `hub.py check` lint when the first game adopts it.
