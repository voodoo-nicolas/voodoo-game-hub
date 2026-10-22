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
  - `build-ship.md`: architecture, hub.py, shipping steps, signing, local tool paths, rename safety
  - `landing-kit-skins.md`: Landing/Home kit, skins, Voodoo Mode, Options/Settings, text size, safe area, orientation, resume
  - `i18n-gameinfo-sfx.md`: es.json/i18n, GameInfo (How to Play, stats), Sfx
  - `music.md`: Music autoload, music library, Viral Music Drop
  - `accounts-online.md`: Auth, OnlineMatch/lobby, friends/invites, leaderboards, achievements
  - `hub-v2.md`: hub home/browser/profile, brand, learning hooks, hub look
  - `web-build.md`: iPhone/Safari build (no threads!)
  - `games-notes.md`: adding a game, catalog conventions, per-game notes, arcade batch, test gotchas
  - `evolution.md`: Evolution (microbe pond: engine, endless mode, owner's trait list, what is not built)
  - `neon-blast.md` (+ Sky Strike) · `poker.md` · `voodoo-iq.md` · `trace-it.md` · `creation.md` (alchemy game: data pipeline, tiers, monetization seam)
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

## Build / ship / architecture (read `docs/claude/build-ship.md` before exporting, shipping, signing or touching APK-side code)
Covers: architecture (Option B packs, manifest, autoloads), `tools/hub.py` commands, the 8-step shipping flow, app signing, local tool paths, rename safety. Hard rules that stay here:
- APK holds only shared code (`scripts/common/`, `scripts/hub/`, `scripts/account/`); games live in packs and never reference hub internals.
- Package ID `com.viral.voodoo`, keystore `voodoo-release.*`, repo name, tag `packs-v1`, game ids, Supabase names, save keys: NEVER rename. Never commit the keystore or print its password.
- `python tools/hub.py check` is read-only: run before committing. Set `PYTHONIOENCODING=utf-8` before `hub.py` in Bash.
- `manifest.json` is committed last, only after packs are uploaded.

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
