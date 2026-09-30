# scripts/hub — internals

You're here because you're fixing or changing the hub shell itself (the category
list, the tiles, the update flow, the download flow) — not a specific game. You
should not need to open any file under `scripts/games/` or `scenes/games/` for
this; if you find yourself doing that, the bug is probably actually inside that
game, not the hub, and belongs in a different session/scope. See the root
`CLAUDE.md` for the shared architecture and the hub↔game contract (the
`manifest.json` format) — that's the only surface games and the hub share.

Everything below is hub-only implementation detail.

## Layout

`hub.gd` is UI only. Everything stateful lives in the `Catalog` autoload
(`scripts/common/catalog.gd`), because the hub scene is freed every time a
game starts but "which packs are mounted", "did we fetch the manifest" and
"did we already check for an app update" must survive that.

- **The catalog** is `Catalog.categories`, parsed from `manifest.json` (live →
  `user://manifest_cache.json` → bundled `res://manifest.json`). A game is
  `{title, icon}` for a "coming soon" placeholder, or `{id, title, icon, scene,
  version, url, min_build}`. `_apply_manifest` rejects a malformed manifest
  wholesale, so a bad push can't blank the hub. `Catalog.catalog_changed`
  fires when a newer live manifest lands; the hub just rebuilds.
- **Accordion UI** (`_rebuild_list`, `_toggle_category`, `_make_section_header`,
  `_make_tile`): fully rebuilds the visible list from `Catalog.categories` +
  `expanded_index` on every change rather than showing/hiding pre-built
  nodes. Simpler than diffing, cheap at a few dozen tiles.
- **Tile state** is `Catalog.state_of(game)`: green ready, red download, amber
  needs a newer app (`min_build` > this `BUILD_NUMBER`), gray coming soon.
- **`_neon_style()`**: the shared Tron-glow `StyleBoxFlat` builder (bright
  border + a blurred shadow of the same hue — Godot's StyleBoxFlat shadow is a
  real soft blur, which is what reads as "glowing"). Used by headers, tiles and
  the hub's dialogs (`_show_dialog` / `_build_dialog_frame`), so the whole hub
  reads as one visual system; use it for any new hub element.
- **Tapping a game** (`_on_tile_pressed` → `_start_download` or `_launch`):
  never waits on the network first — the manifest is refreshed in the
  background when the hub opens. `busy` blocks a second tap while one is being
  resolved. `Catalog.needs_download()` decides; a failed update falls back to
  the copy already on disk; the download overlay's Cancel aborts the request.
  `_launch` surfaces mount failures (a damaged pack is deleted by `Catalog`,
  so its tile turns red again and the next tap re-downloads).
- **App self-update**: `Catalog.check_app_update()` runs once per app session,
  not per hub visit — the GitHub API is rate-limited and "Later" should stick.
- **Editor / full desktop builds**: games whose scene already exists before
  anything is mounted count as bundled and launch from local source, so
  running the hub from the editor plays your working copy, not the published
  pack.

## Things that look like bugs but aren't

- Tiles for undownloaded games show a "⬇ Download" tag but are still tappable —
  intentional, tapping starts the download+launch flow.
- The category header shows `available/total` — `available` counts every game
  with an `id`, downloaded or not. It is not an "already downloaded" count.
- Playing a game, returning to the hub, and not getting an update that was
  published meanwhile: by design, a mounted pack is never replaced
  mid-session (see root `CLAUDE.md` gotchas). The next app start updates it.
- The live manifest being rejected (`refresh_manifest` reports `ok=false`)
  while GitHub still serves a format-1 manifest (no `categories`): the app
  keeps using its cached/bundled catalog until the new one is pushed.
