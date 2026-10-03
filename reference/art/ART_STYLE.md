# Voodoo Game Hub — Art / Graphics Standards

The target look for the hub and for every minigame. The images in this folder
are **mood references only**: never ship them or trace them (05 is a
watermarked stock image; 06 is a found image). Everything in-game stays drawn
in code, like `voodoo.gd` and the synthesized sounds: no image assets.

**In one line: neon vector glow on near-black, with a voodoo soul.**

## The references

| File | What to take from it |
|---|---|
| `01_neon_vector_swarm.jpg` | Geometry-Wars-style: thin glowing outline shapes (diamonds, squares, pinwheels) on black with a faint grid. Each enemy type = one shape + one color. Retro digital HUD font in the corners. |
| `02_neon_vector_trails.jpg` | Same, at peak chaos: particle trails, sparks, dozens of shapes on screen and still readable because every shape is an outline with a distinct hue. |
| `03_glow_ship_warp_grid.png` | The modern, polished version: deep navy background, a grid that *bends* around the action, soft bloom, white-hot cores fading to colored edges, motion trails on bullets. This is the quality bar. |
| `04_neon_tube_signs.jpg` | Real neon tubes: continuous outlines with rounded corners, a white-pink core and a colored halo, glow bleeding onto dark surroundings. Good model for hub titles and tile borders. |
| `05_neon_wireframe_city.jpg` (watermarked stock image, kept out of the repo) | Cyan + magenta wireframe architecture with reflections on a glossy black floor. Model for backgrounds / hub banner: layered outline shapes, depth through dimming. |
| `06_voodoo_shaman_flames.jpg` | The theme: skull face paint, horns, feathers, beads, torches with **purple-blue fire**. Gives the voodoo motifs and the "magic" accent colors. |

| `tavern/07_category_pages_burlap_doll.webp` | **Idea for per-category landing pages** (not built yet, see below). A different mood from 01–06: a warm, candle-lit tavern in place of the cold neon. The mascot is a burlap voodoo doll (button X eyes, stitched grin, pins in the head, small top hat) shown playing each category's games on a dark wooden table. Each page has a carved/parchment sign with the category name at the top and a parchment card listing its games. |

> **Decision (2026-10-03): stay neon for now.** Rules 1–7 below are the
> current standard for the hub, category pages and games. The warm tavern (07)
> is a *possible future change-over*: collect its reference images in
> `reference/art/tavern/`, but build nothing in that style until the user
> decides to switch.

### Category landing pages (proposal from 07, not decided)

The idea: tapping a category on the hub opens that category's own page in place
of the flat list. The page has a header sign, an illustrated scene of the doll
playing that kind of game, and the category's games. What to keep from 07:

- **One mascot, one scene per category**: the doll hunched over a chessboard and
  sudoku (Puzzle & Board), holding a hand of cards (Cards), letter tiles
  spelling VOODOO (Word), at an arcade stick with a block-stack and frog
  (Arcade), dice cup and Yacht score pad (Dice & Party), shot cups (Drinking),
  a spinner wheel (Other). Intelligence would need its own scene; 07 doesn't
  have one.
- **Signage**: an aged parchment/wood plaque with a heavy serif title and
  flourishes, and the game list on a second plaque.
- **Palette**: browns, burlap tan, parchment `#d9b98a`-ish, candle orange;
  black accents (hat, buttons); small bright pin heads as the only saturated
  color.

**Open questions before building it:**
- *Warm tavern vs. neon*: 07 is the opposite of rules 1–3 below. Options:
  category pages warm and games neon (the tavern is the "lobby"); or redraw the
  same scenes in neon outline; or a mix, like neon signs glowing in the dark
  tavern (as 04 does).
- *Painted art needs image assets*: the doll scenes can't be drawn in code at
  this quality. That means shipping ~8 images in the APK (WebP, ~50–150 KB each
  at phone size) or downloading them like packs. This would be the hub's first
  real image art.
- The game list on each page must come from `manifest.json` (it grows), not be
  painted into the image. 07's lists are already out of date: Cards has 11
  games, Puzzle & Board 22.

## Rules for new art

1. **Background**: near-black or deep navy (`#05070d` – `#0a1322`), never flat
   grey or white. Optional faint grid (1 px, ~10–15% alpha), which may ripple
   or bend on impacts.
2. **Shapes are outlines, not fills**: 2–3 px strokes in a bright color, with a
   glow made of the same path drawn 2–3 more times, wider and more transparent
   (e.g. 3 px @ 100%, 7 px @ 30%, 14 px @ 10%). Fills, when used, are dark and
   translucent. Hot spots (bullets, the player, selected items) get a near-white
   core.
3. **Palette** (saturated neons, one meaning per color inside a game):
   - Cyan `#29e6ff` / electric blue `#3a8cff` — player, primary UI
   - Magenta `#ff2bd6` / hot pink `#ff4f9a` — enemies, danger, opponent
   - Lime `#7dff3a` — score, success, "go"
   - Orange-gold `#ffae2b` — bullets, fire, rewards
   - Voodoo purple `#9b4dff` — magic, special moves, the brand accent
   - White — cores and text only
4. **Motion**: things leave trails; explosions are bursts of short glowing line
   particles; hits flash briefly. Effects stay short so the board stays readable.
5. **Text**: bold, wide, slightly retro digital lettering for scores and
   titles, in a neon color with the same glow treatment. Body text stays plain
   and legible.
6. **The voodoo layer**: skulls, crossbones, the X-eyed stitched doll with
   its pin, horns, feathers, beads, purple-blue flame. Use them as accents
   (icons, win/loss moments, hub decoration, Voodoo Mode skins), drawn in the
   same neon-outline style — a neon skull, not a painted one.
7. **Readability beats spectacle**: board/card/word games (Chess, Sudoku,
   Wordle…) take the palette, dark background and glowing outlines, but no
   particles or warping behind the pieces. Arcade games get the full treatment.

## Godot notes

- Glow = draw the same `draw_polyline`/`draw_arc` several times with growing
  width and falling alpha (cheap, works on every phone, no shaders needed).
- Additive blending (`CanvasItemMaterial.BLEND_MODE_ADD`) makes overlapping
  glows brighten like real light.
- `WorldEnvironment` glow/bloom is a real option on the Forward+/Mobile
  renderers, but test it on a budget phone before relying on it.
