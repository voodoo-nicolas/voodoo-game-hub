# Turned: short art prompts (swap the [WORDS], get many files)

Use with any image AI. Keep the STYLE line identical in every prompt so everything matches. Paste your two moodboard images as the style reference when the tool allows it.

**STYLE** (paste at the end of every prompt):
> painted gothic game art, 1900 Victorian, cold desaturated blue-grey, warm amber lamp light, soft light from upper left, highly detailed, visible texture

**Background**: most tools cannot make transparency. Ask for `plain flat bright green background` (characters, props) and drop the file in; a script removes the green. Tiles need no background.

**Scale.** The player is about 46 game px tall (the first placeholder was 35, your reference image about 58). Generate people **big and detailed**: square 1024 x 1024, whole figure about 3/4 of the height, feet near the bottom, centred. The game shrinks any resolution into the same size, so the detail is kept. Everything else is sized against the player (1 metre = 32 game px, so the player is about 1.45 m), keep the people the same height in every picture.

## 1. Player (one sheet, three views, so they match)
> Character sheet, the same person shown three times in a row: front view, back view, side view facing right. Top-down 3/4 angle, full body, feet visible, neutral standing pose. [young woman / young man], [dark hair], [long black wool coat with high collar, buttoned], [dark trousers, leather boots], no hat. Plain flat bright green background, no ground shadow. STYLE

Swap: `[young woman / young man]`, `[dark hair / red hair / blonde hair]`, `[black / navy / burgundy coat]`, `[scarf / no scarf]`. For villagers swap the clothes: `[grey coat and bowler hat]`, `[baker, white apron and cap]`, `[woman with a lace parasol]`, `[man with newspaper, flat cap]`, `[coachman, top hat]`, `[lamplighter with a long pole]`.

## 2. House outside
> [Victorian Gothic townhouse], [three floors], [steep slate mansard roof], [dark red brick], tall windows glowing [amber], chimneys, small front porch. 3/4 isometric view from above, whole building visible, plain flat bright green background, no ground shadow. STYLE

Swap: `[townhouse / manor / cottage / bakery shop / chapel]`, floors, brick colour (`[grey stone]`), window glow.

## 3. Rooms (inside, one picture per room)
> Top-down cutaway view of a [BEDROOM] in a 1900 Victorian house, straight down with a little of the front wall, [ITEMS], [FLOOR], [WALLS], warm [candle] light, no people. STYLE

| ROOM | ITEMS | FLOOR / WALLS |
|---|---|---|
| bedroom | iron bed, nightstand with candle, wardrobe, desk, rug, window with curtains | dark planks / faded wallpaper |
| bathroom | clawfoot tub, pedestal sink, mirror above sink, toilet with high tank, towel rail, washstand with jug, small rug, shelf with bottles | black and white tiles / white tile half-wall |
| hallway | long runner rug, coat stand, console table, clock, portraits, front door | planks / wallpaper |
| kitchen | iron stove, table, shelves with jars, sink, hanging pans, bread bin | stone flags / plaster |
| parlour | sofa, armchairs, fireplace, piano, bookcase, side tables | rug over planks / dark wood panels |
| study | big desk, leather chair, shelves full of books, globe, lamp | planks / dark panels |
| cellar | stone steps, barrels, shelves, crates, cobwebs | rough stone / brick |
| stairs | wooden stairs with banister seen from above, landing, window | planks |

## 4. Single props (furniture, decoration)
> [Clawfoot bathtub], top-down 3/4 view, single object, centered, plain flat bright green background, no ground shadow. STYLE

Swap the object: `[pedestal sink]`, `[standing mirror]`, `[toilet with high tank]`, `[iron bed]`, `[wardrobe]`, `[candlestick]`, `[armchair]`, `[grandfather clock]`, `[piano]`, `[wooden crate]`, `[barrel]`, `[gas lamp post]`, `[market stall with bread]`, `[carriage with horse]`.

## 5. Textures (seamless tiles, this is where "needs texture" is fixed)
> Seamless tileable texture, [wet cobblestones], seen straight from above, flat even lighting, no perspective, no baked shadows, no lamp light, heavy surface detail: cracks, grain, moss, wear, dirt in the gaps. 1024 x 1024. STYLE

Swap: `[wet cobblestones]`, `[worn stone flagstones]`, `[old wooden planks]`, `[black and white bathroom tiles, chipped]`, `[dark red brick wall]`, `[grey slate roof tiles]`, `[overgrown grass and weeds]`, `[faded floral wallpaper]`, `[threadbare red rug]`, `[dark wood panelling]`, `[rough cellar stone]`.

Note: a painted tile replaces the game's lit shader and loses the lamp relief, so use it where the painting is clearly better than the shader.

## 6. Landing picture (done)
The neck close-up with the two marks (the mirror moment) is the Landing: `games/turned/landing_bg.jpg`, cropped to landscape and mirrored so the marks sit right of the text. The portrait original is in `reference/art/games/turned_landing_src.webp`.
