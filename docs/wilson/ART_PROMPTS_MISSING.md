# Beached: missing artwork, prompts for Gemini / ChatGPT

Written 2026-11-10 by scanning `games/wilson/art/`, `data/items.json`, `data/recipes.json` and `wilson_data.gd` for anything with no art.
Style to match: `games/wilson/art/icons/bottle.webp` (icons) and `art/camp/*.webp` (builds).
Drop finished files in `D:/dev/Wilson` and tell Claude to cut / import them (icons -> `art/icons/<id>.webp`, builds -> `art/camp/<id>.webp`, Grand Projects -> `art/projects/<id>.webp`).

## Shared style (paste at the start of every prompt)

Hand-drawn cartoon illustration, clean dark-brown outline of even weight, flat colours with soft cel shading and a little paper-grain texture, warm sunny castaway palette (sand, driftwood browns, teal sea, faded rope), matching the existing Beached art. Transparent background (or plain flat white to cut out). No text, no frame, no shadow box.

Tip: ask for a **sheet** (6-12 items, 3-4 columns, each cell 1024x1024, wide gaps, same scale, plain background) so the style stays consistent, as with the earlier sheets. Claude cuts them.

## A. Item icons (41)

ICON: single object, centred, three-quarter view, fills about 85% of a square 512x512 canvas, readable shrunk to 44 px.

| # | File | Name | Prompt after the style block |
|---|---|---|---|
| 1 | `bait.webp` | Bait | Icon of a few small chopped bits of fish and seaweed in a small shell. |
| 2 | `bandage.webp` | Seaweed bandage | Icon of a rolled green seaweed strip wrapped round a small bundle, tied with thread. |
| 3 | `barrel.webp` | Barrel | Icon of a small wooden wreck barrel with two iron hoops, one stave cracked. |
| 4 | `blunt_knife.webp` | Blunt knife | Icon of a home-made knife: chipped grey stone blade lashed to a short stick, edge visibly dull. |
| 5 | `boot.webp` | Old boot | Icon of a single soggy leather boot with a hole in the toe and a strand of seaweed. |
| 6 | `clay.webp` | Clay | Icon of a lump of wet grey-orange clay with a thumbprint in it. |
| 7 | `clay_jar.webp` | Clay jar | Icon of a small round hand-made clay jar, wide mouth, wooden lid. |
| 8 | `cloth_scrap.webp` | Cloth scrap | Icon of a small torn piece of faded cream cloth with frayed edges. |
| 9 | `compost.webp` | Compost | Icon of a little heap of dark rotting leaves, peel and soil with one tiny worm. |
| 10 | `copper_tube.webp` | Copper tube | Icon of a short bent copper pipe, green patina at the ends. |
| 11 | `crab.webp` | Crab | Icon of a small live orange-red beach crab, claws raised. |
| 12 | `crab_cooked.webp` | Cooked crab | Icon of a bright red cooked crab on a palm leaf. |
| 13 | `driftwood.webp` | Driftwood | Icon of a bleached, twisted piece of silver driftwood. |
| 14 | `drum.webp` | Coconut drum | Icon of a coconut-shell drum with a stretched sailcloth skin laced with rope, two small sticks. |
| 15 | `dry_frond.webp` | Dry frond | Icon of a single dried yellow-brown palm frond. |
| 16 | `fish_big.webp` | Big fish | Icon of one big silver-blue fish, fat body, open mouth, proud catch. |
| 17 | `fish_bone.webp` | Fish bone | Icon of a clean white fish skeleton. |
| 18 | `fish_guts.webp` | Fish guts | Icon of a small unappetising pile of pink-grey fish innards on a leaf. |
| 19 | `fish_oil.webp` | Fish oil | Icon of a small shell or bottle of golden glossy oil. |
| 20 | `fish_oil_lamp.webp` | Fish-oil lamp | Icon of a clay lamp with a rope wick and a small steady flame. |
| 21 | `fish_stew.webp` | Fish stew | Icon of a coconut-shell bowl of steaming stew with fish chunks and green bits. |
| 22 | `frond_hat.webp` | Frond hat | Icon of a woven palm-frond sun hat with a wide brim. |
| 23 | `husk_fiber.webp` | Husk fiber | Icon of a tuft of tan coconut-husk fibres. |
| 24 | `nail.webp` | Nail | Icon of one bent rusty iron nail. |
| 25 | `oar.webp` | Broken oar | Icon of a snapped wooden oar with a worn blade and splintered end. |
| 26 | `paper.webp` | Paper | Icon of a single yellowed, slightly damp sheet of paper with a curled corner. |
| 27 | `plank.webp` | Plank | Icon of a flat weathered wooden plank with two nail holes. |
| 28 | `rubber_sling.webp` | Rubber sling | Icon of a forked stick with a strip of black rubber stretched across, a pebble in the pouch. |
| 29 | `sailcloth.webp` | Torn sailcloth | Icon of a folded piece of torn white-grey sailcloth with stitched seams. |
| 30 | `sand.webp` | Sand | Icon of a small neat pile of golden sand with a few specks of shell. |
| 31 | `seawater.webp` | Seawater | Icon of a bottle of clear blue-green water with a tiny wave inside. |
| 32 | `seaweed_crisps.webp` | Seaweed crisps | Icon of a small stack of thin dark-green crispy seaweed sheets. |
| 33 | `seeds.webp` | Seeds | Icon of a small cloth pouch tipped open, a few striped seeds spilled out. |
| 34 | `spark_kit.webp` | Spark kit | Icon of a flint stone, a bent steel striker and a pinch of dry tinder together. |
| 35 | `spyglass.webp` | Spyglass | Icon of a hand-made brass-and-wood telescope, two sections extended. |
| 36 | `sweet_potato.webp` | Sweet potato | Icon of one purple-skinned sweet potato with a little soil. |
| 37 | `sweet_potato_roast.webp` | Roast sweet potato | Icon of a split roasted sweet potato, orange inside, steam rising. |
| 38 | `tin_can.webp` | Tin can | Icon of a dented rusty tin can with a torn label. |
| 39 | `trunk.webp` | Palm trunk | Icon of a short cut section of palm trunk, rings visible, rough bark. |
| 40 | `wax.webp` | Wax | Icon of a pale yellow lump of wax, slightly melted. |
| 41 | `wind_chime.webp` | Wind chime | Icon of shells and small bones hanging from a driftwood crossbar on thin cords. |

## B. Craft-list icons for built things (17)

Same style as A, simplified front-on view of the build, 512x512.

| # | File | Name | Prompt |
|---|---|---|---|
| 1 | `campfire.webp` | Campfire | Icon of stones in a ring with crossed logs, lit, small flame. |
| 2 | `canopy.webp` | Canopy | Icon of a sailcloth sheet on four poles, a shady corner. |
| 3 | `crafting_stump.webp` | Crafting stump | Icon of a flat-topped stump with a few tool marks. |
| 4 | `drying_rack.webp` | Drying rack | Icon of a wooden A-frame rack with a few hanging fish strips. |
| 5 | `fish_trap.webp` | Fish trap | Icon of a woven wicker cone trap with a funnel mouth. |
| 6 | `frond_bed.webp` | Frond bed | Icon of a low pile of palm fronds laid as a bed. |
| 7 | `frond_shelter.webp` | Frond shelter | Icon of a small lean-to roofed with layered palm fronds. |
| 8 | `garden_plot.webp` | Garden plot | Icon of a square of dark soil edged with stones, a stick fence on one side. |
| 9 | `hammock.webp` | Hammock | Icon of a rope-and-cloth hammock slung between two sticks. |
| 10 | `kiln.webp` | Kiln | Icon of a squat domed clay kiln with a small mouth and short chimney. |
| 11 | `raft_section.webp` | Raft section | Icon of a short bundle of lashed logs, first piece of a raft. |
| 12 | `rain_catcher.webp` | Rain catcher | Icon of a sailcloth funnel on a stick tripod above a clay pot. |
| 13 | `smokehouse.webp` | Smokehouse | Icon of a tiny leaf-and-plank hut with a thin curl of smoke. |
| 14 | `sos_flag.webp` | SOS flag | Icon of a tall pole with a bright red-orange rag flag. |
| 15 | `sundial.webp` | Sundial | Icon of a flat round stone with a stick gnomon and scratched hour marks. |
| 16 | `tent.webp` | Tent | Icon of a sailcloth A-frame tent with a rope guy line. |
| 17 | `water_still.webp` | Water still | Icon of a solar still: a pit under a cloth sheet weighted by one stone, a cup below. |

Skip tent, hammock, frond_bed, drying_rack, rain_catcher, garden_plot, crafting_stump and water_still if you like: they already have in-world sprites in `art/camp/` and Claude can crop icons from those (saves 8 prompts).

## C. In-world sprites with no art yet (12)

WORLD SPRITE: the object standing on sand, slight front-above angle like the existing camp builds, only a small contact shadow, transparent background, 1024 px on the long side.

| # | File | Name | Prompt |
|---|---|---|---|
| 1 | `frond_shelter.webp` | Frond shelter | World sprite of a small lean-to roofed with layered palm fronds, open front, about 1.2 m tall. |
| 2 | `fish_trap.webp` | Fish trap | World sprite of a woven wicker cone trap half in shallow water, rope to a stake. |
| 3 | `sos_flag.webp` | SOS flag | World sprite of a tall driftwood pole with a bright red-orange rag flag blowing, stones piled at the base. |
| 4 | `canopy.webp` | Canopy | World sprite of a sailcloth sheet stretched between four poles. |
| 5 | `smokehouse.webp` | Smokehouse | World sprite of a leaf-and-plank hut with a thin curl of smoke, fish hanging in the open door. |
| 6 | `kiln.webp` | Kiln | World sprite of a squat domed clay kiln with a glowing mouth and short chimney. |
| 7 | `sundial.webp` | Sundial | World sprite of a flat round stone with a stick gnomon and scratched hour marks. |
| 8 | `raft_section.webp` | Raft section | World sprite of a bundle of lashed logs on the sand, rope ends trailing. |
| 9 | `desalinator.webp` | Desalinator (Grand Project) | World sprite of a ramshackle copper-tube and clay-jar desalination rig with a small fire under it, steam into a collecting jar. |
| 10 | `cellar.webp` | Cellar (Grand Project) | World sprite of a wooden hatch door set into the sand with a stone-lined edge, a lantern beside it. |
| 11 | `museum.webp` | Museum of Failure (Grand Project) | World sprite of a little open-air shed with shelves of broken tools and wreck bits lined up like exhibits, two small plaques on stakes. |
| 12 | `shrine.webp` | Golden Coconut Shrine (Grand Project) | World sprite of a stone plinth with a single gleaming golden coconut on it, shells and flowers around, soft glow. |

These are drawn as placeholder shapes now; the four Grand Projects work but are not drawn at all.

## D. Not needed

- Characters: female2 was dropped on 2026-11-10; the 8 looks are complete.
- Campfire in the world: the owner's pit and flame sprites exist (`art/fire/`); only its icon (B1) is missing.
