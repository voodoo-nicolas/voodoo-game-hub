# Hub v2 screens, brand, learning hooks, hub look

Hub shell internals (hub.gd, Catalog): `scripts/hub/CLAUDE.md`.

## Hub v2 (v0.30+)
- Home view (no scrolling at any text size; wordmark takes leftover height): top bar 👤 Profile · 👥 Friends (waiting requests) · ⚙ Options; small ▶ Continue card (last game opened); one big 🎮 Games button (no count). Home and browser slide past each other (`_slide_to`). No purple in the palette (categories electric blue, games green, not-yet-downloaded game muted green; **never red** for not-downloaded). Panels slightly see-through (`GLASS`); opening a category fades in its picture (`CATEGORY_ART`, `media/hub/categories/`; Dice & Party and Other have none). Sign Out only in Options; home shows name or Sign In.
- **Game Browser** (`browser_view`): search, Filters button (chips + sort folded; "Filters (N)" when on), chips: Single player (no "modes"/"cpu"), Same phone, Online, Party, ★, Downloaded, Never played, 🧠 Learn, 2 Player, Quick (5 min), Viral Original (manifest `"quick"`/`"original"` flags via Catalog); they combine. Sort By category (accordion with pinned header) / A–Z / Recently played. Any filter = one flat list. Opens with ★ Favorites (up to 4, then "+N more") above categories. Tiles carry mode icons and a ★ toggle (row lets clicks through to the tile's flat button except on ★). Android back = home view. "Friends playing" waits for presence to carry the current game.
- `scripts/common/hub_data.gd`: favourites `user://favorites.json`, last-opened `user://recent_games.json` (written by `_launch`), play time `user://play_time.json` (Settings counts while a game scene is in front).
- **👤 Profile** (`profile_screen.gd`): name/Sign In, hub-wide numbers (games tried, plays, wins, badges, time, favourites), links to Leaderboards/Achievements/Friends/Multiplayer, language, Sign Out, Delete my account (RPC `delete_my_account`, `docs/delete_my_account.sql` run once by owner; until then the button says to use Send feedback).
- Options: Storage (downloaded games + sizes, Remove; pack opened this session shows "In use": `Catalog.can_remove`), Credits & licences (`res://media/CREDITS.json`, ships in APK).
- Not built (no data): ratings/Top rated, "New", size badges, trial/owned badges (store), N3's "Landing before download".
- Tile icons drawn in code: `scripts/common/game_icons.gd` for chess, sudoku, tictactoe, connect4, checkers, reversi, three_man; others use manifest emoji. Add via `_icon_<id>` + id in `IDS`. Owner wants better icons for many more.
- Three Man's dice are drawn: never use Unicode die glyphs (missing from phone fonts).

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
