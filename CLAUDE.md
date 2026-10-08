# Viral Game Hub — Claude Code instructions

Developer **Viral**; hub **"Viral Game Hub"** (pending INPI/EUIPO check, `docs/HUB_V2_PLAN.md` §1). "Voodoo" is ONLY the neon-skull skin name.
Never hard-code the hub name, package display name or store text: read `Brand.NAME` (`scripts/common/brand.gd`; create if missing).
Free, ad-free (**no ads, ever**), ever-growing mini-game hub: Godot 4.7.2 / GDScript, no Gradle. Public repo https://github.com/voodoo-nicolas/voodoo-game-hub. ~100 games as downloadable `.pck` packs on GitHub Releases (tag `packs-v1`); goal: 100 games live before monetization ("a million games behind one icon"). Supabase: auth, leaderboards, friends/invites, Realtime rooms, entitlements. Bilingual EN/ES.
Monetization is built but **not live**: `store.gd`, `store_billing.gd`, `paywall.gd` on branch `store` (worktree `../voodoo-game-hub-store`), not merged. Don't rebuild; integrate only when the owner says (2026-10-06: hub and games first). Plan `docs/monetization/PLAN.md`: 3-day trials for signed-in players, $0.99/game (Voodoo IQ $1.99), $4.99/month hub (7-day trial + $2.99 x 3 intro), 15 games always free.

## Owner
- Terse, often voice. Prefer doing over discussing. Ask only for **OPEN** plan decisions or conflicting standards.
- Checks precision: double-check counts, maths, versions, paths.
- **Never remove code/comments he marked `//`, `/* */`, `#`**; move, never delete.
- Cost-conscious: free/CC0/self-made assets first; record every asset's licence.
- Don't skip small steps. Changing a standard = update `docs/STANDARDS.md` in the same commit. If a request contradicts a standard, say so and propose the fix; don't silently pick.
- After each step: `python tools/hub.py check` + `python tools/hub.py test <id>` on touched games, commit, summarize in ≤ 5 lines.
- **Ask before**: `publish-packs`, `release`, `bump-app major`, deleting anything, Supabase schema changes, store-listing text.
- At the start of each v2 phase (`docs/HUB_V2_PLAN.md` §2) propose a task list and wait for OK.

## Docs (not auto-loaded; read before the work they cover)
- **Creating/modifying a game: use the `viral-minigame` skill** (checklist: `.claude/skills/viral-minigame/SKILL.md`). **`docs/STANDARDS.md`: full rules; read for hub screens or when the skill is unclear.** Digest below.
- `docs/HUB_V2_PLAN.md` roadmap/decisions/open questions · `docs/IP_AUDIT.md` · `reference/art/ART_STYLE.md` (+ `skins/`) · `docs/KICKOFF_PROMPT.md` (owner's v2 kickoff 2026-10-06).
- `docs/claude/` topic notes — read the one(s) for what you touch:
  - `landing-kit-skins.md`: Landing/Home kit, skins, Voodoo Mode, Options/Settings, text size, safe area, orientation, resume
  - `i18n-gameinfo-sfx.md`: es.json/i18n, GameInfo (How to Play, stats), Sfx
  - `music.md`: Music autoload, music library, Viral Music Drop
  - `accounts-online.md`: Auth, OnlineMatch/lobby, friends/invites, leaderboards, achievements
  - `hub-v2.md`: hub home/browser/profile, brand, learning hooks, hub look
  - `web-build.md`: iPhone/Safari build (no threads!)
  - `games-notes.md`: adding a game, catalog conventions, per-game notes, arcade batch, test gotchas
  - `neon-blast.md` (+ Sky Strike) · `poker.md` · `voodoo-iq.md` · `trace-it.md`
  - Hub shell internals (hub.gd, Catalog): `scripts/hub/CLAUDE.md`. Working on one game: you shouldn't need `hub.gd`; working on the hub: shouldn't need `scripts/games/`.

## Standing rules (add a matching lint to `hub.py check` when checkable)
- Every new/modified game meets "Definition of done" below.
- Only the Landing links to the hub; every other game screen has 🏠 Home → Landing.
- Packs must work on older APKs: guard every call into APK systems (`get_node_or_null()`, `ResourceLoader.exists()`, `load()` never `preload()` for APK-side scripts); `"min_build": <BUILD_NUMBER>` on the `games` entry only if unavoidable (older apps then show "Update app").
- Never overwrite a mounted `.pck`. Never delete owner comments.
- EN + ES for every string (`tools/i18n/es.json`, then `python tools/hub.py i18n`).
- Learning hook where natural (STANDARDS §15). **No alcohol references anywhere.**
- Every asset: `media/CREDITS.json` entry + licence proof in `media/licenses/`; OGG pre-encoded (~96 kbps music). Never NC/ND licences.
- Music: only from the shared `Music` autoload (docs/claude/music.md).
- `manifest.json` is committed last.

## STANDARDS digest (full text: docs/STANDARDS.md)
- N1 only the Landing has "← Hub"; N2 every other screen 🏠 Home (deeper ones also ‹ Back); N3 selecting a game anywhere opens its Landing; N4 Android back = one step up (Landing → Hub; during play → pause menu); N5 leaving play saves via `SaveUtil`; N6 Landing → play ≤ 2 screens, Resume/Quick Play 1 tap; N7 navigation lives in the Landing kit.
- Pause menu: Resume / Restart / How to Play / 🏆 / 📊 / 📸 / ⚙ Options / 🏠 Home. Floating SettingsDrawer retired (stub for old packs; never delete the class).
- Skins: Classic default, Voodoo opt-in. Kit buttons one blue colour, green only for Start/Resume. Arcade games keep their own backgrounds.
- Layout: inside safe area, fit viewport width, test text scale 1.0 and 1.4.
- Don't market as kids' education (Google Play Families policy conflicts with Drinking Games).

## Definition of done (any game you touch)
Every applicable STANDARDS section: navigation rules, Landing, setup screens, pause/save/resume, options, 🏆 + 🏅, both skins (or documented why not), safe area, text scale 1.0–1.4, EN+ES complete, shared media tiers where possible, `CREDITS.json`, IP checklist, `hub.py check` green. Modify an old game → bring it to standard or tell the owner what's missing. No sweep across games: apply as each is touched.

## Architecture
- **APK holds only shared code**: `scripts/common/`, `scripts/hub/`, `scripts/account/`. Games live in packs and never reference hub internals. Per game: `<id>_engine.gd` (pure logic, headless-testable) + `<id>_game.gd` (Control, UI in code, Landing kit) + `<id>_help.gd` (how-to + achievements + facts) + `<id>_i18n.gd` (generated). Media in tiered packs (STANDARDS §10).
- **Option B**: base APK = hub shell. Each game is a `.pck` on GitHub Releases (tag `packs-v1`), downloaded to `user://packs/<pack_id>.pck` on first tap, mounted via `ProjectSettings.load_resource_pack()` (`replace_files = false`: a pack may only add its own files). Game source lives in this one Godot project (pck export requires it; don't split repos) but is excluded from the APK by preset 0's `exclude_filter="scenes/games/*, scripts/games/*"`; each game has its own preset (generated by `sync`, game folder only, `game_pack` custom feature excludes shared folders + project icon/boot splash). Apps ≤ v0.12 read only `games.<id>.version`: never rename/drop manifest fields.
- `manifest.json` = catalog + version list: `categories` drive the hub list, `games` holds version/url/scene (+ `min_build`, `modes`, `board`, `learn`, `quick`, `original`, `skins`, `archived`, `title_es`). `Catalog` autoload reads best of: live raw.githubusercontent copy, `user://manifest_cache.json`, bundled copy. A new game appears in installed apps once manifest + pack are pushed; no APK release needed.
- Hub compares manifest versions with `user://pack_versions.json` for download/update/launch. Downloads go to `.part`, checked for `GDPC` magic, then swapped; a failed update keeps the old copy; a pack that fails to mount is deleted (next tap re-downloads). `Catalog` only updates packs not mounted this session. Media packs get a new filename per version (`<name>.v<N>.pck`), mount next launch. Two mounted packs with the same `res://` path: last wins; namespace media (`res://media/common/`, `res://media/cat/<cat>/`, `res://games/<id>/`).
- App self-updates: checks GitHub Releases API on launch; prompts when latest tag > `VERSION` in `scripts/common/version.gd`.
- Autoloads: Auth, Catalog, Settings, Lang, Sfx, Music, Social, OnlineSession (those that must run while paused use `PROCESS_MODE_ALWAYS`).

## `tools/hub.py` (`python tools/hub.py -h`)
| Hand-edit | Generated by `sync` — never hand-edit |
|---|---|
| `manifest.json` (catalog, titles, icons, pack versions) | per-game pack presets in `export_presets.cfg` |
| `scripts/common/version.gd` (`VERSION`, `BUILD_NUMBER`) | Android preset `version/name` + `version/code` |
| `scripts/common/config.gd` (repo, release tag, Supabase, timeouts) | `games` entries (url/scene) for new ids |
| `scripts/common/brand.gd` | app name in presets (Android label, Windows product name) |
| `reference/art/brand/` (owner's art) | `media/hub/brand/` (`tools/brand/make_brand.py`) |
- `check` validates everything, changes nothing: run before committing. `tools/` has a `.gdignore`.
- **PC test build**: `python tools/hub.py pc` exports all games to `%LOCALAPPDATA%\VoodooGameHub\Voodoo.exe` + desktop shortcut; re-run after game changes.
- Web (iPhone): `python tools/hub.py web [--publish]` (docs/claude/web-build.md).
- Kit copies: `sync` copies `tools/templates/home_kit.gd` into each pack; edit only the template.

## Shipping a change
1. Headless logic test: throwaway `SceneTree` script, `godot --headless --script path/test.gd`; randomness → hundreds/thousands of trials asserting invariants.
2. Boot test: `python tools/hub.py test <id>` (none = hub, account screen, every game); fails on `SCRIPT ERROR`/`Parse Error`.
3. Version: game changed → `python tools/hub.py bump-pack <id>`; anything APK-side (`scripts/common/`, `scripts/hub/`, `scripts/account/`, `project.godot`) → `python tools/hub.py bump-app [patch|minor|major]` (bumps `VERSION` + `BUILD_NUMBER`, syncs preset).
4. Build: `python tools/hub.py export <id>...|--all`; `python tools/hub.py apk` (release-signed; fails if arm64-v8a, armeabi-v7a or x86_64 missing; copies to `builds/voodoo-vX.Y.Z.apk`).
5. **Ask owner**, then `python tools/hub.py publish-packs <id>...` (media packs too).
6. Commit + push source incl. `manifest.json` **last** (not `builds/`, gitignored); pushing it announces versions, so only after packs are uploaded.
7. **Ask owner**, then (if the app was bumped) `python tools/hub.py release --notes "..."`.
8. `python tools/hub.py verify` compares live manifest + pack URLs with local builds.

## App signing
- `hub.py apk` makes a **release** build signed with `C:\Users\nick_\Android\Keystore\voodoo-release.keystore` (alias `voodoo`; password in `voodoo-release.json` beside it), passed via `GODOT_ANDROID_KEYSTORE_RELEASE_*` env vars. **Never commit either file, never print the password.** Losing the key = installed apps can never update; owner keeps a backup. `hub.py apk --debug` = local testing only.
- **Package ID `com.viral.voodoo`: never change** (a different ID = a different app; Google developer verification registers ID + key).
- Developer verification (Google, mandatory for sideloading from Sept 2026/2027): Android Developer Console account "Viral", Personal (Limited distribution: max 20 devices, invitation); `com.viral.voodoo` + release key Registered. Public sharing needs Full distribution ($25, ID check). Until then Play Protect may block installs: temporarily turn off "Scan apps with Play Protect".
- v0.14→v0.15 changed the key (users reinstalled once).

## Local tools (portable, not on PATH; this PC `nick_` is the main PC: builds APK, publishes packs/releases; no admin rights)
- Godot 4.7.2: `C:\Users\nick_\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` (Windows templates in `%APPDATA%\Godot\export_templates\4.7.2.stable`)
- Android SDK `C:\Users\nick_\Android\sdk` (build-tools 34.0.0) · JDK `C:\Users\nick_\Android\jdk-17.0.20.1+1` · Keystores `C:\Users\nick_\Android\Keystore\` (`debug.keystore`, `voodoo-release.keystore`, `voodoo-release.json`)
- Python 3.12 `%LOCALAPPDATA%\Programs\Python\Python312\python.exe` (`python` resolves in Bash) · `gh` `C:\Program Files\GitHub CLI\gh.exe` (as `voodoo-nicolas`) · Git `C:\Program Files\Git\cmd\git.exe`
- Bash calling `powershell.exe` mangles `$_`/env syntax: use the PowerShell tool for real PowerShell. Set `PYTHONIOENCODING=utf-8` before `tools/hub.py` in Bash (emoji crash cp1252). Desktop is OneDrive-redirected (`hub.py pc` asks Windows).

## Rename safety (Voodoo → Viral, owner 2026-10-06): visible text only
NEVER rename: Android package/applicationId (`com.viral.voodoo`), keystore (`voodoo-release.*`) or `VOODOO_RELEASE_KEY`, Supabase project/table/column names, save paths and keys (`user://...`, stat keys), game ids in `manifest.json`, repo `voodoo-game-hub`, tag `packs-v1`. Internal identifiers may keep "voodoo" (classes, `VOODOO_SAFE_INSET`, Realtime topic `voodoo-<game>-<code>`, User-Agent, `builds/` names). `project.godot` `config/name` stays "Voodoo" (PC save folder `%APPDATA%\Godot\app_userdata\Voodoo`); visible name comes from export presets (synced from `Brand.NAME`) and the runtime window title.

## Gotchas (don't reintroduce)
- `font_color` override does nothing on a disabled Button: use `font_disabled_color`.
- `window/stretch/aspect` must be `"expand"` (`"keep"` letterboxes).
- `--export-pack`: CLI path always wins over the preset's `export_path`; pass the exact path (`hub.py export` does).
- Nested Dictionary inside a top-level `const Array` is read-only: `.duplicate()` before mutating.
- Preset 0 needs `architectures/armeabi-v7a=true` (else 32-bit phones rejected).
- Godot force-includes the project icon and autoload scripts in every `.pck`; presets carry the `game_pack` feature (`project.godot` has `config/icon.game_pack=""`) and exclude shared folders (`sync` generates). A tiny game pack is ~10 KB.
- **`queue_free()` not `free()`** when rebuilding nodes inside their own signal handler (free is refused, node leaks, container ends a child short).
- **Never connect a lambda to an autoload's long-lived signal** (stale connections error "Lambda capture ... was freed"): connect a method, `.unbind(n)` to drop args (`Auth.signed_in.connect(_update.unbind(2))`).
- Every `HTTPRequest` needs `timeout` = `Config.HTTP_TIMEOUT` (default 0 waits forever).
- Phones send every tap twice (`ScreenTouch` + emulated `MouseButton`, mouse first): single taps handle `MouseButton` only; real multi-touch games (Speed, Air Hockey) ignore mouse when `DisplayServer.is_touchscreen_available()`.
- `get_tree().create_timer(t)` keeps running while paused: pass `create_timer(t, false)` or use the scene's tween.
- `await get_tree().create_timer()` resumes into a freed scene: use tween / child `Timer`.
- `set_anchors_preset()` on a node already in the tree keeps its size: use `set_anchors_and_offsets_preset()`.
- `Auth.reconcile_stat` and `Catalog` skip callbacks whose object is freed via `Callable.is_valid()`: pass methods, not lambdas.
- Never use Unicode die glyphs (missing on phones); draw dice.
- Bash heredocs mangle `\\`; headless tests and `hub.py test` share and modify the user's real saves (docs/claude/games-notes.md).
