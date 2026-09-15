# scripts/hub — internals

You're here because you're fixing or changing the hub shell itself (the category
list, the tiles, the update flow, the download flow) — not a specific game. You
should not need to open any file under `scripts/games/` or `scenes/games/` for
this; if you find yourself doing that, the bug is probably actually inside that
game, not the hub, and belongs in a different session/scope. See the root
`CLAUDE.md` for the shared architecture and the hub↔game contract (the
`CATEGORIES` entry format, manifest format, export preset format) — that's the
only surface games and the hub share.

Everything below is hub-only implementation detail.

## `hub.gd` layout

- **`CATEGORIES`** (top of file): the entire game catalog, grouped into sections.
  A game entry with no `pack_id` and `scene: ""` renders as a disabled "Coming
  soon" tile. Adding/removing/reordering games or categories only ever touches
  this array — see root `CLAUDE.md`'s "Adding a new game" section.
- **Accordion UI** (`_rebuild_list`, `_toggle_category`, `_make_section_header`,
  `_make_tile`): fully rebuilds the visible list from `CATEGORIES` +
  `expanded_index` every time a category is tapped, rather than
  showing/hiding pre-built nodes. Simpler than diffing, cheap enough at this
  scale (a few dozen tiles) not to matter.
- **`_neon_style()`**: the shared Tron-glow `StyleBoxFlat` builder (bright
  border + a blurred shadow of the same hue — Godot's StyleBoxFlat shadow is a
  real soft blur, not a flat drop shadow, which is what actually reads as
  "glowing"). Used by both section headers and tiles so the whole hub reads as
  one visual system; if you're styling a new hub element, use this rather than
  inventing a new stylebox from scratch.
- **App self-update** (`_check_for_update` → `_on_update_check_completed` →
  `_show_update_dialog`): pings the GitHub Releases API once per hub load,
  compares the latest release tag against `Version.VERSION`
  (`_is_newer_version`, plain dotted-segment comparison), and offers
  `OS.shell_open()` on the APK download URL if newer. Fails silently offline —
  never blocks using the app.
- **Download-on-demand** (`_check_and_launch` → `_start_download` →
  `_on_download_completed`, plus `_ensure_mounted`/`_launch`): the runtime half
  of Option B. `_check_and_launch` is the single entry point every downloadable
  tile calls — it always pings `manifest.json` first to decide between
  first download, silent re-download (newer `version` in the manifest than
  `user://pack_versions.json` has locally), or just launching what's already on
  disk. If the manifest is unreachable and the pack is already downloaded, it
  launches with the local copy rather than blocking play on a network check.

## Things that look like bugs but aren't

- Tiles for undownloaded games show a "⬇ Download" tag but are still tappable —
  that's intentional, tapping starts the download+launch flow
  (`_check_and_launch`). Only truly unbuilt "coming soon" placeholders
  (`scene: ""`) are disabled.
- The category header shows `available/total` — `available` counts every game
  with a non-empty `scene`, whether bundled or downloadable. It is not "already
  downloaded" count.
