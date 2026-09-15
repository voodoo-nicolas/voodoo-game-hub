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
- `manifest.json` (fetched live from `raw.githubusercontent.com`) is the source of
  truth for what version of each pack is current; the hub compares it against
  `user://pack_versions.json` to decide download vs. silent update vs. launch-as-is.
- The **app itself** also self-updates: the hub checks the GitHub Releases API on
  launch and prompts to install a newer APK if the latest release tag is newer
  than `scripts/common/version.gd`'s `VERSION`.

Don't try to split this into multiple repos/projects per game — Godot's `.pck`
export requires the source to be inside this one project, and the shared helpers
below need to stay trivially reusable. The games are logically independent (that's
the whole point of Option B); the repo/project is not.

## Adding a new game — the pattern

Every shipped game follows the same shape. Look at `red_or_black` or `three_man`
(drinking games, simple) or `sudoku`/`solitaire` (more complex board state) as
templates before writing anything new.

1. **`scripts/games/<id>/<id>_engine.gd`** — `extends RefCounted`, pure game logic,
   no Godot UI/Node dependencies. This is what gets unit-tested headlessly.
2. **`scripts/games/<id>/<id>_game.gd`** — `extends Control`, builds its entire UI
   in code (no hand-authored scene trees beyond the root). Always:
   - `Orientation.lock_portrait()` (or `lock_landscape()`) in `_ready()` — every
     scene declares its own required orientation; never rely on another scene to
     reset it on exit (see Gotchas below for why).
   - `add_child(SettingsDrawer.new())` as the **last** child of `_build_ui()` —
     gives every game the floating settings tab (timer, rotate, screenshot, hub).
   - A "Hub" button reachable at all times, in addition to the settings drawer.
   - If the game has meaningful mid-session state worth resuming, save/load via
     `SaveUtil` (see `solitaire_game.gd` for the full pause/save/resume pattern).
     Short round-based games (Simon, Hangman, the drinking games) skip this.
3. **`scenes/games/<id>/<id>.tscn`** — minimal: a root `Control` with the game
   script attached, nothing else. Copy an existing one and change the two paths.
4. **Register in `scripts/hub/hub.gd`**: add `{"title": ..., "icon": "<emoji>",
   "pack_id": "<id>", "scene": "res://scenes/games/<id>/<id>.tscn"}` to the right
   category in the `CATEGORIES` array. Every game — including "coming soon"
   placeholders — has an `icon` now; pick something distinct within its category.
5. **Add an export preset** in `export_presets.cfg`: copy the most recent
   `[preset.N]` / `[preset.N.options]` pair, bump `N`, set `name`, `include_filter`
   to `"scenes/games/<id>/*, scripts/games/<id>/*"`, and `export_path` to
   `"builds/packs/<id>.pck"`.
6. **Add to `manifest.json`**: `"<id>": {"version": 1, "url":
   "https://github.com/voodoo-nicolas/voodoo-game-hub/releases/download/packs-v1/<id>.pck",
   "scene": "res://scenes/games/<id>/<id>.tscn"}`.
7. **Bump the version** — in **both** places, they don't sync automatically:
   - `scripts/common/version.gd`: `VERSION` (PATCH for fixes/content, MINOR for a
     new game/feature, MAJOR once out of early testing) and `BUILD_NUMBER`
     (must strictly increase every time an APK is built, independent of VERSION —
     Android rejects an install otherwise).
   - `export_presets.cfg` preset 0's `version/name` and `version/code` — Godot's
     exporter does not read these from GDScript, they have to match by hand.

## Shipping a change — the checklist

A game isn't done when the code is written. Every shipped change in this repo's
history followed this sequence; skipping steps is exactly how the version-sync gap
happened once already:

1. **Headless logic test**: write a throwaway `SceneTree`-extending test script
   (see git history for examples — `test_three_man.gd` style), run with
   `godot --headless --script path/to/test.gd`. For anything with randomness
   (dice, shuffled decks), run hundreds/thousands of trials per branch and assert
   invariants rather than exact outcomes.
2. **Real boot test**: temporarily set `run/main_scene` in `project.godot` to the
   new scene, run `godot --headless --path . --quit-after 40`, confirm no
   `SCRIPT ERROR` / `Parse Error` output, then set `run/main_scene` back to
   `res://scenes/hub/hub.tscn`. `--script` mode alone won't catch real
   Viewport/DisplayServer issues — this step does.
3. **Export the game's `.pck`**: `godot --headless --export-pack "<PresetName>"
   "builds/packs/<id>.pck"`.
4. **Rebuild the base Android APK** (required any time `hub.gd`, `version.gd`, or
   any shared/common file changed — those are baked into the base app, not a
   pack): `godot --headless --export-debug "Android" "builds/game-hub.apk"`, then
   copy to `builds/voodoo-vX.Y.Z.apk`. Sanity-check architectures are all still
   bundled: `unzip -l builds/game-hub.apk | grep lib/`  should show
   `arm64-v8a`, `armeabi-v7a`, and `x86_64`.
5. **Commit and push** the source changes (not the `builds/` output — that's
   gitignored/uploaded separately as release assets).
6. **Upload the pack**: `gh release upload packs-v1 builds/packs/<id>.pck
   --clobber`.
7. **Create the APK release**: `gh release create vX.Y.Z
   builds/voodoo-vX.Y.Z.apk --title "vX.Y.Z" --notes "..."`.
8. **Verify live**, don't just trust the upload succeeded — `curl -sL -o /dev/null
   -w "%{http_code} size=%{size_download}\n"` each release asset URL and the raw
   `manifest.json`, and confirm the sizes match the local files byte-for-byte.

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
- **GitHub CLI**: `C:\Program Files\GitHub CLI\gh.exe` (authenticated as `voodoo-nicolas`)

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
  explicitly, don't rely on the preset default.
- **Nested `Dictionary` inside a top-level `const Array`** is read-only; call
  `.duplicate()` before mutating a copy pulled from `CATEGORIES` or similar.
- **32-bit ARM devices**: `export_presets.cfg` preset 0 needs
  `architectures/armeabi-v7a=true` — without it, older/budget Android phones
  are silently rejected as "incompatible" on install.

## Reference material

`reference/juegoflix_friend_reference.html` — a friend's competing 20-game hub
(single-file HTML), saved for layout/game-idea inspiration. Never copy from it
literally; used so far for the per-game-icon tile layout idea and drinking game
rules.
