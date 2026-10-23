# Turned: art list for real sprites and tiles

The game draws everything in code (lit shader cobbles, flagstones, planks, brick and slate; outlined people and props). Painted art replaces any piece by **file name**: put a PNG in `games/turned/art/` and the code uses it instead of the drawing. Nothing else to change. Pieces without a file keep the drawn look, so you can replace them one at a time.

Style target: your moodboard (`reference/art/turned/`): cold desaturated blues and greys, warm amber lamp light, wet cobbles, slate roofs, brick. Seen from above at a slight angle (the in-game camera is top-down with a little of the front wall showing).

## Rules for every PNG
- **Transparent background** (except tiles). RGBA, PNG.
- **Painted at 2x**: 1 world pixel = 2 PNG pixels (1 metre = 32 world px = 64 PNG px). The game scales them down by half, so they stay sharp when the camera zooms in.
- **Light from the upper left**, lamp light warm. Paint no cast shadow on the ground for people and props: the game adds a soft contact shadow and lights them itself.
- Every file needs an entry in `media/CREDITS.json` and a licence proof in `media/licenses/` (the hub's rule; `python tools/hub.py check` fails without it). For AI-made art record the tool and the plan/terms you used, and that the rights are yours to use commercially. Never NC/ND licences.
- Anchor = the point of the picture that sits on the spot in the world (a fraction of the picture size). Keep it in the same place in every direction of one character.

## Characters (one set each; a single `name.png` also works)
Each as `name_down.png` (faces the camera / walks down), `name_up.png` (back view), `name_side.png` (faces **right**; the game mirrors it for left).

| Name | Who | Canvas | Anchor (x, y) | Notes |
|---|---|---|---|---|
| `player` | the player (unisex, 1900 clothes: dark coat, no hat) | 128 x 128 | 0.5, 0.92 | about 90 px tall, feet at the anchor. A scarf is drawn over it in code for now |
| `npc_watcher` | man in a grey coat, bowler hat, still, watching | 128 x 128 | 0.5, 0.92 | the only villager that stares |
| `npc_vendor` | baker, apron, cap | 128 x 128 | 0.5, 0.92 | stands behind the stall: front view matters most |
| `npc_parasol` | woman with a parasol | 128 x 128 | 0.5, 0.92 | walks left/right: side view matters most |
| `npc_newspaper` | man with a newspaper, flat cap | 128 x 128 | 0.5, 0.92 | walks left/right |
| `npc_coachman` | coachman, top hat | 128 x 128 | 0.5, 0.92 | |
| `npc_lamplighter` | lamplighter with a pole | 128 x 128 | 0.5, 0.92 | |

**People are resolution-independent (2026-10-23).** A person PNG is drawn into a canvas 64 world px tall (`PERSON_CANVAS_H`) whatever its pixel size, so paint them big: **1024 x 1024**, figure about 72% of the height (about 740 px), feet at 92% of the height, centred. In game the figure is about 46 px tall (1.45 m): midway between the first placeholder (35 px) and your reference (58 px). The 128 x 128 canvases above still work. The placeholder drawing is 1.3x its old size (`PERSON_SCALE`), all villagers too, so they stay in proportion.

Walk animation frames are not supported yet (one picture per direction); say so when you have them and I will add `name_down_1.png ...`.

## Props
| Name | What | Canvas | Anchor |
|---|---|---|---|
| `lamp` | gas lamp post with lantern (no glow: the game adds it) | 64 x 128 | 0.5, 0.9 |
| `tree` | a tree trunk and roots only | 64 x 96 | 0.5, 0.9 |
| `tree_canopy` | the leaves seen from above, round, soft edge, a little transparent underneath | 256 x 256 | centre (the game sizes it to the shade circle: 90-120 px across) |
| `stall` | the baker's stall counter with bread | 256 x 128 | 0.5, 0.2 |
| `carriage` | carriage and horse, side view from slightly above, horse on the left | 320 x 160 | 0.5, 0.9 |
| `crate` | wooden crate | 64 x 64 | 0.5, 0.5 |
| `barrel` | barrel | 48 x 48 | 0.5, 0.5 |
| `bed` | bed seen from above, head at the top, blanket folded at the foot (the player is drawn on it in the prologue) | 128 x 256 | top-left corner |

## Tiles (seamless, tile in both directions)
Replace the lit shader surfaces. A painted tile loses the lamp relief (flat), so only worth it when the painting beats the shader. Size 256 x 256, or 512 x 512.

| Name | Where |
|---|---|
| `ground_cobble` | the road and the alley |
| `ground_flagstone` | the pavements |
| `ground_planks` | wooden floors indoors |
| `ground_tile` | the bathroom |
| `ground_grass` | the gardens beyond the fence |
| `wall_brick` | the street walls of the houses |
| `roof_slate` | the roofs |

## Still drawn in code (can be painted later)
Awnings, the porch roof, window frames and doors, the shop fronts and signs, rugs and furniture, puddles, leaves, the HUD and the neck close-up. The neck close-up is the best next picture to paint: `neck_closeup.png`, 1024 x 1024, a neck with two small marks (not wired in yet).

## Prompt template if you generate with an AI tool
> Top-down 3/4 view game asset, painted, dark gothic 1900 street, cold desaturated blue-grey palette with warm amber accents, soft light from the upper left, [WHAT: e.g. "wooden crate"], isolated on a transparent background, no ground shadow, centered, consistent with a moodboard of wet cobblestones, slate roofs and gas lamps.

Make one sheet of a character in all three directions in one go so they match, then cut it into `_down`, `_up`, `_side`.
