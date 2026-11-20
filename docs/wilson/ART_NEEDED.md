# Beached: castaway poses still missing (2026-11-20)

For Claude chat to turn into image prompts. Every item already has an icon and every structure has its art, so what is missing is **castaway poses**. Right now these actions borrow a pose that doesn't fit (in brackets: what shows today).

## Match the existing sheets
- Same style as the current character sheets in `games/wilson/art/chars/` (cartoon, bold dark outline, warm flat colours, ragged castaway clothes).
- One full body per image, transparent background, feet at the bottom, side or three-quarter view.
- **Face RIGHT** (the game mirrors her to face left).
- Start with the blonde (`female5`): she's the only look with extra poses. The other 7 looks (male1-4, female1, female3, female4) can come later, or keep the basic poses.
- Same height and proportions as `female5_idle.webp`.

## 1. In the water (the priority)
| Pose name | Used by | What it shows |
|---|---|---|
| `wade` | Splash in the shallows (wave) | standing knee-deep, kicking up a splash, happy |
| `swim1`, `swim2` | Go for a swim (wave) | head and arms above the water, front crawl, 2 frames to loop |
| `float` | Go for a swim, 2nd half | floating on her back, arms out, relaxed |
| `water_scoop` | Get seawater (craft) | crouched at the waterline, filling a coconut shell |
| `spear_ready`, `spear_throw` | Spear fishing (fish pole cycle) | knee-deep, spear raised; spear thrust down into the water |
| `cast` | Practise casting (wave) | standing, swinging an empty rod forward |
| `skip_stone` | Skip a stone (wave) | side-arm throw, low to the water |

Draw the water line on her body (for example at the knees or chest) so she looks like she's in the sea. Keep the water itself see-through or very light: the game's own sea goes behind her.

## 2. On the beach
| Pose name | Used by | What it shows |
|---|---|---|
| `pick_up` | Gather pebbles / sticks / fronds / shells (basket weaving) | bending at the waist, picking something up off the sand |
| `kneel_dig` | Dig a hole, Dig for clay, Search the sand, Plant (craft) | kneeling, digging with both hands or a shell shovel |
| `shake_tree` | Shake a palm (wave) | both hands on a palm trunk, shaking it |
| `haul` | Salvage debris: crate, planks, barrel (craft) | leaning back, dragging something heavy with a rope |
| `fan` | Fan the fire, Light the fire (craft) | crouched, fanning with a palm frond / blowing on a spark |
| `cook` | Cook at the campfire, Practise roasting (craft) | sitting, holding a stick over the fire |
| `catch_crab` | Catch a crab, Rock pools (craft) | crouched, reaching for a crab |
| `tally` | Scratch a tally mark (craft) | scratching on a wooden stump with a stone |
| `sandcastle` | Build a sandcastle, Draw in the sand, Crab race (craft) | kneeling, shaping sand |
| `stretch` | Stretch, Sunrise stretch (wave / sit) | standing, arms over head (yoga) |
| `lie_back` | Stargaze, Watch the sunset (sit) | lying on her back, hands behind head |
| `look_out` | Scan the horizon, Read the sky (idle) | hand shading her eyes, looking far away |
| `drum` | Play the drum (sit) | sitting, drumming on a coconut drum |
| `carry` | Walking with a load (walk) | 4 walk frames, arms carrying a bundle (optional) |

## 3. Other things that are not built
- Glow / feel pass on the bag, craft and journal panels (no art needed from you).
- The foreground sea is a still picture: a 4-frame loop of the near waves would bring it to life (`art/sea`).
- The other 7 looks have none of the extras (fishing cycle, carve / tool / weave): they reuse the basic craft pose.

## Licence
Your own AI art (Gemini / ChatGPT): add each new file to `media/CREDITS.json` as before.
