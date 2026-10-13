# Hub v2 screens, brand, learning hooks, hub look

Hub shell internals (hub.gd, Catalog): `scripts/hub/CLAUDE.md`.

## Hub v2 (v0.30+)
- Home view (no scrolling at any text size; wordmark takes leftover height): top bar 👤 Profile · 👥 Friends (waiting requests) · ⚙ Options; small ▶ Continue card (last game opened); one big 🎮 Games button (no count). Home and browser slide past each other (`_slide_to`). No purple in the palette (categories electric blue, games green, not-yet-downloaded game muted green; **never red** for not-downloaded). Panels slightly see-through (`GLASS`); opening a category fades in its picture (`CATEGORY_ART`, `media/hub/categories/`; Other has none). Adventure category (2026-10-12): Neon Blast, Sky Strike, Star Runner (moved from Arcade; still own backgrounds). Sign Out only in Options; home shows name or Sign In.
- **Game Browser** (`browser_view`): search, Filters button (chips + sort folded; "Filters (N)" when on), chips: Single player (no "modes"/"cpu"), Same phone, Online, Party, ★, Downloaded, Never played, 🧠 Learn, 2 Player, Quick (5 min), Viral Original (manifest `"quick"`/`"original"` flags via Catalog); they combine. Sort By category (accordion with pinned header) / A–Z / Recently played. Any filter = one flat list. Opens with ★ Favorites (up to 4, then "+N more") above categories. Tiles carry mode icons and a ★ toggle (row lets clicks through to the tile's flat button except on ★). Android back = home view. "Friends playing" waits for presence to carry the current game.
- **Families + motion (2026-10-12)**: manifest game `"family"` (e.g. "Sudoku", "Solitaire") makes `Catalog._family_less` list a category by family, then English title (no family = its own); test `tools/test_family_order.gd`. Options "Reduce motion" (`Settings.reduce_motion`, `anim_time()`) switches off the home/browser slide, art fade and category fade-in.
- `scripts/common/hub_data.gd`: favourites `user://favorites.json`, last-opened `user://recent_games.json` (written by `_launch`), play time `user://play_time.json` (Settings counts while a game scene is in front).
- **👤 Profile** (`profile_screen.gd`): name/Sign In, hub-wide numbers (games tried, plays, wins, badges, time, favourites), links to Leaderboards/Achievements/Friends/Multiplayer, language, Sign Out, Delete my account (RPC `delete_my_account`, `docs/delete_my_account.sql` run once by owner; until then the button says to use Send feedback).
- Options: Storage (downloaded games + sizes, Remove; pack opened this session shows "In use": `Catalog.can_remove`), Credits & licences (`res://media/CREDITS.json`, ships in APK).
- Not built (no data): ratings/Top rated, "New", size badges, trial/owned badges (store), N3's "Landing before download".
- Tile icons drawn in code: `scripts/common/game_icons.gd` for chess, sudoku, tictactoe, connect4, checkers, reversi, three_man; others use manifest emoji. Add via `_icon_<id>` + id in `IDS`. Owner wants better icons for many more.
- Three Man's dice are drawn: never use Unicode die glyphs (missing from phone fonts).

## Game Browser (2026-10-13, Options > Games menu look: Sliding / Grid)
- `Settings.hub_layout` "strip" (default) | "grid" (old "classic"/"new" values read as "strip"). `hub.gd` always builds `scripts/hub/netflix_browser.gd`; the old accordion code stays in hub.gd as `_build_classic_browser_view` (unused). Chips, sort, search, favourites and `_on_tile_pressed` stay in hub.gd (the view calls them). Layout design, art pipeline and behaviour: STANDARDS §2a "New look".
- Orientation: hub, hub_screen, Options use `Orientation.lock_sensor()` (account_screen still portrait). `project.godot` orientation stays "portrait" (games and old builds); the hub rotates at runtime. Home rearranges in landscape (`_apply_home_orientation`); hub screens cap their content width (`CONTENT_MAX_WIDTH`).
- Art: `python tools/make_hub_art.py` makes self-made placeholders from `media/hub/categories` (hues avoid purple) and writes CREDITS; `--from DIR` converts real art (`<id>.png`, `<id>_tile.png`). ~7 MB for 109 games. Not built: remote hero art from Supabase Storage.
- Import: the game_art `.webp.import` files must say `compress/mode=1` (lossy); Godot defaults to lossless and the APK doubled (96 to 201 MB). Check after adding art.
- Tests: `tools/test_netflix_hub.gd` (headless), `tools/shot_netflix.gd` (screenshots, needs a window: `--resolution 1280x720` / `405x720`).
- Detail preview (2026-10-13): game logo (drawn `GameIcons` icon or manifest emoji) on a transparent box, no art, nothing clips it. Owner wants a custom logo + teaser image per game long-term: when they exist, change `_set_preview` in `netflix_browser.gd` (hook: `HubArt.tile`/`tile_art`, `hero_art`).
- Gotchas: moving a Button to another parent re-fires `node_added` (Settings/Sfx connects now guard); use `set_anchors_and_offsets_preset` on nodes already in the tree; a StyleBoxFlat shadow on a transparent box tints what is inside it (the tile glow is a separate panel under the picture).

## Game art drawn in code (2026-10-13, owner OK'd: separate logo + teaser per game, mini-scene teasers)
- `scripts/common/game_art.gd` facade: `has_logo/draw_logo` (game_icons.gd first seven, `game_logos.gd` rest), `has_teaser/draw_teaser` (`game_teasers.gd`, 160x90 mini scene per game). Used by hub.gd/hub_screen.gd tiles and the Game Browser detail (teaser in a rounded frame; no teaser = bare logo/emoji on transparent). Real art (`HubArt`) is separate.
- Add a game: `_logo_<id>` + id in `IDS` + `match` line (logos); `_teaser_<id>(c, base)` + id + `match` line (teasers). Helpers: `GameLogos.txt/cell/panel/meter/logo_at`, `GameIcons._slab/_sphere/_glow_*`. No emoji/words in the art (translation + phone fonts); digits, ? and ! are fine.
- Batches: 1 Intelligence (12) done; next Arcade (24), Puzzle & Board (22 left), Cards (16), Word 9 + Dice 7 + Party 8 + Adventure 3. The first seven games (chess..three_man) have logos but no teaser yet.
- Review: `godot --path . --resolution 1080x720 --script res://tools/shot_art.gd -- <dir> [ids]` writes one contact sheet. Cloud sessions have no Godot: batch 1 was written blind, check it on a device/PC first.

## Brand (`scripts/common/brand.gd`, APK-side)
- `NAME`, `DEVELOPER`, `TAGLINE` (`tagline()` translates), `STORE_TITLE`, art paths, `backdrop()` (portrait/landscape by shape; mist if art missing). Hub code preloads it; packs `load()` after `ResourceLoader.exists(Brand.PATH)`.
- `hub.py sync` copies `Brand.NAME` into export presets (`package/name`, `application/product_name`); `check` fails on drift. `config/name` stays "Voodoo"; PC window title set from `Brand.NAME` in `Settings._ready()`.
- Art: `python tools/brand/make_brand.py [--preview]` (numpy, scipy, Pillow) rebuilds `media/hub/brand/` from `reference/art/brand/`; never edit outputs. Folders with `.gdignore` (`launcher/`, `store/`, `boot/`, `masters/`) aren't imported (Android exporter reads them from disk). `boot_splash/image.game_pack=""` keeps the 1.9 MB splash out of packs.
- Brand sources (never shipped): `background.jpg` (1266x832), `viral_logo_wordmark.png` (598x393; hub header only, too small for splash/store), `vskull_logo_src.jpg` (fake checkerboard baked in). All in `media/CREDITS.json`.
- Lints: every file under `media/` needs a `CREDITS.json` entry + proof in `media/licenses/`. Name lint: APK-side UI text may say "Voodoo" only for the skin (`VOODOO_TEXT_OK` in hub.py); es.json `null` strings skipped.
- Hub palette (`Settings.DARK`: violet + orange) still follows the old banner; new art is red + cyan. Restyle = Phase 2.
- Art standards: `reference/art/ART_STYLE.md` (Voodoo skin guide, neon vector glow on near-black; images are references only, `.gdignore`). Drawing in code stays preferred, not mandatory. `reference/juegoflix_friend_reference.html` = friend's 20-game hub, inspiration only, never copy.

## Learning hooks (STANDARDS §15)
- Manifest `"learn": ["vocab","math","logic","memory","art","music","geo","science"]` (Catalog copies; 🧠 Learn chip lists games with any tag). `<id>_help.gd` may have `const FACTS := [...]`: kit shows one on a "💡 Did you know?" card at the bottom of Home (tap = next); Sudoku's Home too. English strings translated in es.json; only checked facts about the game's own subject; no pop quizzes in arcade games. Not built: learning stats/achievements in Profile.

## Motion + art refresh (2026-10-12)
- `scripts/common/hub_fx.gd`: `drift` (slow zoom/pan on the Brand backdrop and category art), CPU-particle `embers` over the backdrop, `stagger_in` (home rows, hub-screen cards, a category's games cascade in), `breathe` (wordmark, Games button), `attach` (button press "pop" via `Watcher`, every Button under a hub screen). All skip when `Settings.reduce_motion`. New screens: call `HubFx.attach(self)` / get it free via hub_screen.
- Category art = the owner's 8 images (`media/hub/categories/`; old five in `reference/art/categories_old/`). Hub backdrop now built from `reference/art/brand/hero.jpg` by `make_brand.py` (launcher/store icons still use `background.jpg`). The home view still shows the wordmark scene over it.
- The app reads the live manifest from GitHub (cache `user://manifest_cache.json`): new categories/families only appear on devices after manifest.json is pushed.

- Consent (2026-10-13): after the age gate, ONE screen: links that open `Config.TERMS_URL` / `PRIVACY_URL` (GitHub Pages `docs/legal/`) in the browser + a single "I've read and accept" box. The in-app reader is only in Options > Legal.
