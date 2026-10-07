# Hub & Minigame Standards — v2

Status legend: **[CURRENT]** already true in code · **[NEW]** decided, to implement · **[CHANGED]** replaces an old rule.
Anything still undecided lives in `docs/HUB_V2_PLAN.md`, not here. Only decided rules belong in this file.

---

## 1. Navigation model [NEW]

```
Hub ──► Game Browser ──► Game Landing ──┬─► Single-player setup ──► Play
 │                          ▲    │      ├─► Multiplayer setup ────► Lobby/Play
 ├─► Profile                │    │      ├─► Leaderboards
 ├─► Friends                │    │      ├─► Achievements
 └─► Options (app)          │    │      ├─► How to Play
                            │    │      └─► Options (game)
                    (every screen inside a game has 🏠 Home → Landing)
                                 └─► ← Hub   (ONLY from Landing)
```

Rules (apply to every game, no exceptions):
- **N1** The **Game Landing** is the only screen in a game with a "← Hub" control.
- **N2** Every other screen inside a game shows **🏠 Home** (→ that game's Landing). Screens deeper than one
  level also show **‹ Back** (one step up).
- **N3** Selecting a game anywhere in the hub (browser, Continue, Favorites, invite) opens its **Landing directly**.
  If the pack isn't downloaded yet, the Landing opens anyway (art + title from manifest) and shows the
  download progress; Play buttons enable once the pack is mounted.
- **N4** Android back button/gesture = one step up. From Landing → Hub. During play → opens the pause menu (never exits).
- **N5** Leaving play by any route saves via `SaveUtil` (local games). Online games offer "Leave match" with a forfeit warning.
- **N6** Max depth from Landing to playing: 2 screens (setup → play). **Resume** and **Quick Play** are 1 tap.
- **N7** Navigation is implemented once, in the **Landing kit** (`tools/templates/home_kit.gd`; `hub.py sync`
  copies it into every pack as `scripts/games/<id>/home_kit.gd`, so it works on every installed app version).
  [CHANGED 2026-10-06: was "APK-side game_router.gd + landing_kit.gd"; per-pack copies need no `min_build` and no
  fallback. The kit's screen handling and Android back cover the router's job.]
  Games register screens/modes; they don't hand-roll back buttons.

## 2. Hub screen [CURRENT since v0.30.0, 2026-10-06]
Goal: fewer buttons, no scrolling on the hub home.
- Top bar: **Profile** (avatar) · **Friends** (badge = pending invites/requests) · **⚙ Options**.
- Body: **Continue** card (last game, 1 tap → that game's Landing with Resume highlighted),
  **Favorites** row (horizontal, optional), one big **🎮 Games** button → Game Browser.
- Hub home must fit one phone screen at text scale 1.4 without vertical scroll.

### 2a. Game Browser [CURRENT since v0.30.0 — except ratings, "Top rated", "New", Newest sort, size badge: no data yet]
- Search box + filter chips: Single player · Same phone · Online · Party · Category ▾ · Top rated ·
  Never played · Downloaded · Favorites · New.
- Sort: A–Z · Recently played · Rating · Newest.
- Ratings: show stars only for well-rated games; **never surface which game is rated worst**.
- Tile: landing art thumbnail, title, mode icons, downloaded/size badge, trial-days/owned badge (from `store.gd`).
- Drinking Games category is **archived** (hidden everywhere; see `HUB_V2_PLAN.md` §6; 8 games, incl. Spin the Bottle
  and Would You Rather). No live game may reference alcohol.

### 2b. Profile [CURRENT since v0.30.0 — ownership waits for the store; Delete account needs docs/delete_my_account.sql run once]
Nickname, avatar, hub-wide stats (games played, time, wins), achievements across all games, ownership /
subscription status, account (sign in/out, sync, delete account), language.

### 2c. Friends [NEW]
Friend list with online status, requests, add by username or friend code, invite to a game (pick game →
goes through that game's multiplayer setup), recent opponents, pending invites (accept → game Landing → lobby).

### 2d. Options (app-wide) [CURRENT since v0.30.0 — Storage + Credits added; Music waits for Phase 3]
Sound on/off + SFX volume, **Music on/off + volume** (new), vibration, UI theme (light/dark), text size,
language, notifications (invites), rotate screen, keep screen on, **Storage** (downloaded games + sizes,
delete), account & privacy, About / Credits / Licences (renders `CREDITS.json`).

## 3. Game Landing page [NEW — replaces "Home screen per game"]
Built with the **Landing kit** (`home_kit.gd`, copied into every pack; see N7) [CURRENT since 2026-10-06].
Contents (show only what applies to the game):
- Per-game hero artwork (one per skin), title, short tagline.
- **Resume** (only if a save exists) · **Quick Play** (last-used mode + difficulty).
- **Single player** · **Multiplayer**.
- **🏆 Leaderboards** · **🏅 Achievements**.
- **❓ How to Play** (Goal / How / Tips / Stats — from GameInfo).
- **⚙ Options** (game).
- **← Hub** (only here — rule N1).
- Trial/purchase state from `store.gd` (badge + paywall entry) when the game is locked.
- Exceptions: Sudoku and Voodoo IQ may keep custom visuals but must expose the same buttons and obey §1.
- Back-compat: packs check `ResourceLoader.exists(LANDING_KIT_PATH)`; on older APKs fall back to the old Home kit.
  If a pack truly needs a newer APK: `"min_build": <BUILD_NUMBER>` on its `games` entry in `manifest.json`.

### 3a. Leaderboards [CURRENT → extended]
- Every game with a score/counter has 🏆 (Everyone / Friends). Lower-is-better games use a growing counter.
- [NEW] Boards split by mode and difficulty where it changes the score meaning. Pin "your rank" row.

### 3b. Achievements [CHANGED]
- Filter: **All / Earned / Locked**. Progress bars for counters. Hidden achievements show "???" until earned.
- Generic badges come free from GameInfo stats; game-specific ones in `<id>_help.gd`.

## 4. Single-player setup [NEW]
One screen: pick **mode** → **difficulty** → mode options → **Start**. Remembers last choice (feeds Quick Play).
Mode vocabulary (use these names/strings so i18n and leaderboards stay consistent; offer only what fits):
Classic · Campaign / Levels · Time Trial · Survival / Endless · Zen / Practice (no score) · Daily Challenge ·
Vs CPU · Custom. Difficulty: Easy · Normal · Hard (+ Expert where meaningful).

## 5. Multiplayer setup [NEW]
- **Local**: pass-and-play / same screen; player count + names (party games).
- **Online**: Invite friend · Create room (shows code + share link + QR) · Join with code · Rejoin current match.
- Then mode / difficulty / rules: host chooses, guests see them read-only.
- Online games **rejoin** instead of resuming locally [CURRENT].
- Join links: `https://<domain>/j/<CODE>` → Android App Link into the app; fallback page sends to the Play Store.
  [CURRENT since v0.31.0, no domain yet] The lobby shows the room code, a QR of
  `https://voodoo-nicolas.github.io/voodoo-game-hub/j/?g=<id>&c=<CODE>` (GitHub Pages, `docs/j/index.html`: code +
  how to join + get the app, EN/ES) and 📋 Copy invite / 💬 WhatsApp (wa.me share link). QR: `scripts/common/qr.gd`
  (pure GDScript, level M, versions 1-6, checked with OpenCV via `tools/test_qr.gd`). App Links wait for a domain.

## 6. In-game: pause / exit / resume [CURRENT → extended]
- Visible pause button inside the safe area.
- Pause menu: Resume · Restart · How to Play · 🏆 Leaderboard · 📊 Stats · 📸 Screenshot · ⚙ Options · 🏠 Home.
  (No Hub link — rule N1.) Online matches: same menu without Restart, game keeps running, "Leave match" replaces Home.
- Save on pause/exit with `SaveUtil`; Resume appears on the Landing.
- [CHANGED] **The floating ⚙ SettingsDrawer is removed.** Its items moved: How to Play, 🏆, 📊, 📸 → pause menu;
  🔊 Sound, 📺 Rotate → Options; 🏠 Hub → dropped (rule N1).
- [CURRENT 2026-10-06] Every Landing-kit game: the kit frees the drawer the game still adds. Sudoku and the IQ Test
  (custom screens) still show it until they get the same pause menu.
- Back-compat: old packs still call `add_child(SettingsDrawer.new())`, so `settings_drawer.gd` stays in the APK as a
  **no-op stub** (keeps the class name, builds nothing, `queue_free()`s itself) until every pack is migrated.
  Never delete the class while any published pack references it.

## 7. Options: global vs per-game [CHANGED — resolves a conflict]
App-wide settings stay in the `Settings` autoload (one source of truth). The game Options screen shows
them too, but editing them changes the global value. Per-game items are stored per game.

| Setting | Scope | Notes |
|---|---|---|
| Sound on/off, SFX volume | Global | `Settings` + `Sfx` groups |
| Music on/off, music volume | Global | new `Music` bus |
| Vibration | Global | |
| UI theme light/dark | Global | applies to menus/chrome |
| Text size (1.0–1.4) | Global | `Settings.content_scale_factor` |
| Rotate screen, keep screen on | Global | |
| Notifications (invites) | Global | |
| **Skin: Classic / Voodoo** | Per game; **default = Classic** (global "Voodoo mode" switch can flip all games) | §9 |
| **Default difficulty / mode** | Per game | feeds Quick Play |
| Game-specific toggles (hints, timer, auto-complete…) | Per game | declared by the game |

## 8. Layout [CURRENT]
- Everything inside the safe area (camera cutout ≈ 24 units top). Nothing important clipped.
- Fit viewport width, not a fixed 720. Landscape scales 1280/720. Test at text scale 1.0 and 1.4.

## 9. Skins & art [CHANGED — "games hard-code dark only" is retired; CURRENT for 4 pilots since 2026-10-06]
Every game ships two skins when feasible. **Classic is the default**; Voodoo is opt-in. Classic always uses the
game's traditional colours (it does not follow the app's light/dark theme; only menus do).
- **Classic**: the game's traditional look (e.g. Solitaire = red/blue card backs, white faces, green felt).
- **Voodoo**: neon on near-black, per `reference/art/ART_STYLE.md`; pieces → skulls/bones, card backs →
  voodoo doll, accents → owner-provided **Lips** motif (`media/common/art/lips.*`, pending delivery).
- [CHANGED 2026-10-06] Implemented in the Landing kit (copied into every pack, like N7) rather than an APK-side
  `skin.gd`/`SkinDef`: `HomeKit.CLASSIC` colour tokens, ⚙ Options → Look (per game, saved in `user://landing_<ID>.json`),
  the game's `_set_skin("classic"|"voodoo")` re-skins in place; `_current_skin()` for a game that kept its own choice;
  older `_set_voodoo(on)` games still work. Games declare `"skins": ["classic","voodoo"]` in the manifest.
  Guides: `reference/art/skins/CLASSIC.md`, `VOODOO.md`. (Was: Implemented through a `SkinDef` resource (colour tokens + texture overrides), APK-side `skin.gd`   (evolution of `voodoo.gd`: load, don't preload). Games declare `"skins": ["classic","voodoo"]` in the manifest.)
- Readability: text contrast ≥ 4.5:1; colour is never the only cue (shape/icon too) — neon palettes fail
  colour-blind players otherwise.
- Art references library: `reference/art/` (`ART_STYLE.md` = the Voodoo skin's guide, `skins/CLASSIC.md`,
  `skins/VOODOO.md`, palette tokens, motif sheet; brand sources in `reference/art/brand/`). All art must be
  original or licensed (see `IP_AUDIT.md`).

## 10. Media libraries (3 tiers) [NEW]
Goal: players with many games download shared media once.

| Tier | Pack | `res://` root | Examples |
|---|---|---|---|
| 0 Hub | in APK | `res://media/hub/` | hub music loop, UI stingers (prefer synthesized `Sfx`) |
| 1 Common | `media-common.v<N>.pck` | `res://media/common/` | menu music, win/lose stingers, skull/bone/doll/lips sprites |
| 2 Category | `media-cat-<cat>.v<N>.pck` | `res://media/cat/<cat>/` | cards: deck art, shuffle/deal/flip; word: tiles; arcade: lasers/explosions; board: piece clacks; dice: rolls |
| 3 Game | `<id>.pck` | `res://games/<id>/` | that game's hero art, unique sounds/music |

Rules:
- Promote an asset to Tier 2 only when ≥ 3 games in the category use it; to Tier 1 when ≥ 2 categories do.
- Manifest: `media_packs` block (version, url, size, sha256) + per game `requires_media: ["media-common>=3", ...]`.
  `catalog.gd` downloads dependencies before the game pack and reference-counts them for Storage deletion.
- Never overwrite a mounted media pack (new filename per version; mount next launch).
- Audio: OGG Vorbis; music ~64–96 kbps with loop points; SFX synthesized via `Sfx` where possible (0 bytes).
- Audio buses: Master / Music / SFX / UI. Music ducks under important SFX.
- Every asset has an entry in `media/CREDITS.json` (file, source, author, licence, URL, date). Allowed: own work,
  CC0, CC-BY (with credit shown in About). **Not allowed: NC or ND licences** (the app is commercial).
  AI-generated assets: record tool + plan; only use tiers whose terms allow commercial use.
- "Royalty-free" ≠ "no licence": keep the licence text/receipt in `media/licenses/` and check app/game use is allowed.
  Proprietary tracks need a written licence (or are owned by Viral) — file it there too.
- Music prep: encode OGG before import (Godot imports OGG without re-encoding, so the file size is what ships);
  music ~96 kbps stereo, set loop + `loop_offset` in the import settings; normalise loudness so tracks match
  (target ≈ −16 LUFS integrated).

## 11. i18n [CURRENT]
- Source of truth `tools/i18n/es.json` (EN string → ES). Generate with `python tools/hub.py i18n`
  → `strings_es.gd` (hub) + each game's `<id>_i18n.gd` (pack).
- Labels auto-translate when the string exists in `es.json`. Formatted: `tr("Score: %d") % score`.
- Never `tr()` data (names, stats, logic). All caps: `tr("Code").to_upper()`.
- New screens (Landing, setup, browser, profile, friends) add every string to `es.json` in the same commit.

## 12. Code patterns [CURRENT]
```gdscript
func _ready():
    Orientation.lock_portrait()            # or lock_landscape()
    # ... build UI ...
    preload("res://scripts/games/<id>/<id>_i18n.gd").install(self)
    # No SettingsDrawer in new/migrated games — pause menu + Options come from the Landing kit.
```
Guarded calls into APK systems (packs run on older apps):
```gdscript
if info:
    info.result("win")          # "win" | "loss" | "draw"
    info.high(key, value)
    info.summary()
if voodoo:
    voodoo._set_voodoo(on)
if Auth.is_logged_in():
    Auth.reconcile_stat(key, value)
    Auth.submit_score(key, value)
    Auth.fetch_leaderboard(game_id, limit)
btn.set_meta("sfx", "win")      # every press plays "tap"; "" silences
if ResourceLoader.exists(ONLINE_LOBBY_PATH):
    var online = OnlineMatch.new(...)
    online.send_move(state_json)
```

## 13. Shared systems (APK-side, reach every game with no game code) [CURRENT + NEW]
| System | File | Purpose |
|---|---|---|
| Auth | `auth.gd` | sign up/in/out, reset, sync, leaderboards |
| Catalog | `catalog.gd` | manifest, download/mount packs, versions; [NEW] media deps + ref counts |
| GameInfo | `game_info.gd` | How to Play card, first-play pause, results/stats |
| Sfx | `sfx.gd` | synthesized sounds, grouped volume |
| Music | `music.gd` [NEW] | music bus, tiered tracks, ducking |
| Settings | `settings.gd` | global options, safe area, landscape boost |
| Skin | `skin.gd` [NEW, from `voodoo.gd`] | Classic/Voodoo skins |
| Online | `online_match.gd`, `online_lobby.gd` | Supabase Realtime rooms, rejoin |
| Social | `social.gd` | friends, invites, online launch |
| Achievements | `achievements.gd` | generic + per-game badges, toasts |
| Lang | `lang.gd` | EN/ES picker |
| Store | `store.gd`, `store_billing.gd`, `paywall.gd` | trials, purchases, entitlements |
| Router | in the Landing kit (N7) | screens, N1–N7 rules, Android back |
| Landing kit | `tools/templates/home_kit.gd` → each pack | Landing, setup screens, pause menu, game Options |
| SettingsDrawer | `settings_drawer.gd` | **retired** — no-op stub kept only for old packs |
| Brand | `brand.gd` [NEW] | hub name, links, store text keys |

## 14. IP / copyright [NEW]
No game may use a trademarked game name, logo, character, card/board art, or copied rules text.
Mechanics are fine; names and look are not. Full checklist: `docs/IP_AUDIT.md`. Every new or modified
game passes it before publishing.

## 15. Learning hook [NEW]
"Learn by playing, never homework." If a game can teach something naturally, it should; if it can't, skip it.
- Each game declares its hooks in the manifest: `"learn": ["vocab","math","logic","memory","art","music","geo","science"]`
  (empty is fine). The Game Browser gets a **Learn** filter chip.
- Hooks live inside the mechanics, not bolted on: word games teach meanings and the *other* language (EN↔ES is
  built in); dice/cards show odds; puzzles name the logic technique used; drawing teaches proportion/colour.
- Never block play, never pop quizzes into arcade games, max one optional "Did you know?" per game over/loading screen.
- Voodoo skin may label bones (skull, femur, ribs…) as a light anatomy hook.
- Facts and translations must be verified; wrong "educational" content is worse than none.
- Track it: generic achievements for learning stats (e.g. "100 new words"), shown in Profile.
- **Do not market the hub as kids' education.** Google Play's Families policy then applies, and it conflicts with
  the Drinking Games category. Position it as "brain-boosting for everyone", rated for teens/adults.
