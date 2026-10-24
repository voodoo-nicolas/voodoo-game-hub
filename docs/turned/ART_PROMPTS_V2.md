# Turned: art prompts v2 (the mockup look, ChatGPT image generation)

For `ART_DIRECTION_V2.md`. Every picture is **assembled from blocks**: `MASTER STYLE` + a camera block + `LAYOUT` + the picture's own line from the tables + `NEGATIVE`. Paste the blocks unchanged so all 34 scenes match. Ids are the file names (`SC-01` = `reference/art/turned/gen/SC-01.png`) and match `WORLD_LIST.md` (places `PL-`, objects `OB-`, people `PE-`).

**Ready to paste:** `ART_PROMPTS_V2_READY.md` has the prompts of steps 1-3 of "Order to make them" fully assembled (CS-01 busts, SC-01..SC-07, CD-01, CD-02, CD-03, CD-05, CS-02, CS-03, SC-10..SC-14); regenerate them there when a block here changes.

## How to run it with ChatGPT
1. One chat per batch (the style drifts in a long chat). **Attach the references first**: the four `mockup_*.webp` and `city_gate_night_*.webp` from `reference/art/turned/mockups/`, then say: *"Match the look, lighting, camera angle and painting style of the attached pictures. Ignore their interface, labels and any text: do not draw any."*
2. Sizes (ChatGPT's native ones): every **scene is landscape 1536 x 1024** (3:2; Turned stays landscape, decided 2026-10-23); cards, busts, icons are square **1024 x 1024**.
3. A night or day version of a scene: in the same chat say *"same room, same camera, same furniture, same colours, now at night, lit only by ..."* (it edits instead of redrawing).
4. If any text appears: *"Remove every letter and number; signs and papers must be blank or unreadable scribble."*
5. Save the PNG as `reference/art/turned/gen/<id>.png` and tell Claude the ids: it converts, credits and wires them. Say which ChatGPT plan you used (for the licence record).

## Blocks (paste as written)

**MASTER STYLE**
> Hyper-detailed painted game concept art for a dark gothic narrative adventure, year 1900, Victorian. Painted-realistic with rich texture: wood grain, brick, wet cobblestone, heavy wool and brocade, tarnished brass, dust and haze in the light, fine film grain, a deep vignette. Warm amber lamp, candle or fire light (like #c29d84 and #ce9e58) against cold desaturated blue-teal shadow (like #091318 and #1b1e20); near-black browns (#0e0c0a, #1a120d) and warm mid-browns (#553a2a, #755846). Slightly blurred foreground objects in the lower corners for depth.

**CAMERA ROOM** (indoors)
> Camera: high three-quarter view looking down about 55 degrees into the room as if the front wall had been removed, the whole room visible like a cutaway diorama, wide landscape framing.

**CAMERA OUTDOOR**
> Camera: high three-quarter view looking down about 55 degrees onto the street, wide landscape framing, the street running left to right with depth up the picture.

**LAYOUT** (landscape, every scene)
> Composition for a wide landscape phone screen, 3:2: lay the room or street out horizontally so the eye travels left to right. Keep every important object inside the central 80% of the width and between 20% and 86% of the height (the top-left and top-right corners and the bottom 12% will be covered by an interface; keep them to dark, calm detail such as ceiling, sky or foreground blur). Objects the player can examine must be clearly visible and separate from each other. No person in the picture unless the line says so.

**NEGATIVE**
> No text, no letters, no numbers, no readable signs (signs and papers blank or unreadable scribble), no interface, no health bars, no icons, no labels, no watermark, no border, no logo, no modern objects, no cars, no phones, no neon.

**THE PLAYER** (paste when a person is the player; the player is a young woman, owner 2026-10-24: no male version)
> A young woman in her early twenties, pale, long dark auburn wavy hair (a deep reddish-brown with copper glints where the light catches it) worn down, falling past her shoulders, a few loose strands across her face; a soft, clearly feminine face: a delicate jaw and chin, high cheekbones, full lips, soft arched brows, long dark lashes, a slender neck; tired grey-brown eyes; a brown wool waistcoat over a cream high-collared blouse with rolled sleeves, a dark brown ankle-length walking skirt, black leather lace-up boots.

**SHEET** (character turnarounds only: replaces the vignette and corner blur of MASTER STYLE, which would spoil the green cut-out; leave those two phrases out of MASTER STYLE for sheets)
> A character turnaround sheet: front, back, and side facing right, full body, neutral pose, plain flat bright green background, no ground shadow, no vignette, no foreground objects, no blur; the green must be flat and even edge to edge. The three views side by side, same scale, evenly spaced. Landscape, 1536 x 1024.

**THE STRANGE COAT** (paste when the coat is shown, so it is the same prop everywhere)
> A heavy dark charcoal wool coat with a high collar and a subtle tone-on-tone floral brocade pattern, a worn dark red-grey lining, slightly too elegant for its owner.

## Batch 0: the player and the cast

For each: **Sheet** = MASTER STYLE (without the vignette and corner blur) + SHEET + the description line + NEGATIVE, landscape 1536 x 1024 (three full bodies are cramped in a square) = also the Walk-mode sprite source (`ART_PROMPTS.md` section 1 cuts it into `_down`, `_up`, `_side`); **Busts** = four head-and-shoulders portraits in a 2 x 2 sheet on a dark warm background (neutral, afraid, angry, tired/hungry), 1024 x 1024: the dialogue portraits and the HUD ring.

| Id | Who | Description line (add after MASTER STYLE) | Variants |
|---|---|---|---|
| CS-01 | You (PE-01) | THE PLAYER | sheet a) waistcoat and blouse; b) wearing THE STRANGE COAT, collar up; c) with a wide-brimmed hat and a scarf wrapped around the lower face (sun gear); d) skin red, blistered and swollen on the hands and face (sun burns); e) very pale, dark under the eyes, trembling (thirst). Busts: neutral, scared, angry, drained |

**Variants b-e of CS-01, said in the same chat after a)** (so ChatGPT edits instead of redrawing):
- b) *"Same character, same three views, same background, now wearing a heavy dark charcoal wool coat with a high collar and a subtle tone-on-tone floral brocade pattern, a worn dark red-grey lining, slightly too elegant for its owner; collar up."*
- c) *"Same character, same three views, same background, same clothes, now with a wide-brimmed hat pulled low and a scarf wrapped around the lower face, only the eyes showing."*
- d) *"Same character, same three views, same background, same clothes. Her skin is sunburned: the face, neck, hands and forearms red and swollen, with blisters and peeling patches, the worst on the cheeks, the nose and the backs of the hands; the covered skin stays pale. She holds her hands slightly away from her body as if they hurt."*
- e) *"Same character, same three views, same background, same clothes. She is starving with thirst: deathly pale, almost grey-white skin, dark hollows under the eyes, dry cracked lips, hair tangled and lank, shoulders hunched, arms wrapped around herself, visibly trembling."*
| CS-02 | Tavernkeep (PE-02) | A broad man in his fifties, thick grey-brown moustache, rolled shirt sleeves, a stained leather apron, a damp cloth over one shoulder | busts: afraid, hard |
| CS-03 | Witness (PE-04) | A thin nervous man in his thirties, unshaven, a worn flat cap and a threadbare grey jacket, wide eyes, pale | busts: scared, relieved, suspicious |
| CS-04 | Shopkeeper (PE-06) | A stocky man of about fifty-five, grey whiskers, round wire spectacles, a waistcoat with a watch pocket, rolled sleeves, tobacco-stained fingers | sheet a) shop outfit; b) heavy travel coat and a brimmed hat holding an oil lamp; c) the left forearm wrapped in torn cloth smeared with dirt. Busts: guarded, kind, afraid |
| CS-05 | Old Man (PE-07) | A gaunt man of seventy, long white-grey hair, deep-set pale eyes, a worn black clerical coat with the collar removed and a shawl over it, ink-stained fingers, a walking stick | busts: weary, sharp, ashamed |
| CS-06 | Harbor Man (PE-08) | A tall weathered ship's captain in his fifties, salt-and-pepper beard, a navy double-breasted coat with brass buttons, a peaked cap, a silver watch chain across the waistcoat | busts: calm, assessing, grave |
| CS-07 | Priest (PE-13) | A lean man in his forties, black cassock with a white collar, a hawkish face, a thin cold smile | busts: courteous, cold |

Crowds (PE-03 bar patrons, PE-09 harbor locals) are 4-6 sprites each, made later from one prompt per type (`ART_PROMPTS.md` swaps); not needed for the first scenes.

## Batch 1: the scenes

Formula: **MASTER STYLE + CAMERA + LAYOUT + line below + NEGATIVE** (all scenes 1536 x 1024). "Must show" = the hotspots (the game puts a labelled chip on each, in EN and ES).

| Id | Size | Place and time | Must show | People |
|---|---|---|---|---|
| SC-01 | 1536x1024 | Small Victorian bedroom, grey Friday morning light through a tall window, a small coal stove glowing | iron bed with a rumpled blanket and a faint dark stain on the pillow; THE STRANGE COAT draped over a wooden chair; a wall calendar (a blank grid, no numbers); a wardrobe; a desk with a candle and papers; a nightstand; the window; a door to the landing; a doorway to the bathroom | none |
| SC-02 | 1536x1024 | The same bedroom at night, one candle and moonlight through the window (edit SC-01) | the coat on the chair with its inner lining slightly open and a faint warm glow from inside; the calendar; the door | none |
| SC-03 | 1536x1024 | A narrow Victorian bathroom, black-and-white tile, cold light | a pedestal sink with a large mirror above it whose reflection is faint, dim and wrong; a clawfoot bath; a towel on the rail with a dark stain; a washstand with a jug and bowl; a toilet with a high tank; a shelf of bottles; a small rug; a small window | none |
| SC-04 | 1536x1024 | A study and library at dusk | a heavy desk with a green-shaded lamp and papers; a globe; a tall bookshelf with one clear gap where a book is missing; an armchair; the window | none |
| SC-05 | 1536x1024 | The ground-floor entrance hall, warm hall lamp | a heavy front door with an iron bolt; a coat stand with a scarf on it; a console table with a stopped clock; a low iron-banded cellar door; the stairs going up; a framed family portrait whose faces are dark and unclear; a long runner rug | none |
| SC-06 | 1536x1024 | The parlour, curtains drawn, dust | sofa; two armchairs; a piano; a fireplace with cold grey ashes; a bookcase; a portrait over the fireplace (faces unclear); a side table | none |
| SC-07 | 1536x1024 | The kitchen, early light | an iron stove; a long table with two cups; a pantry door; shelves of jars; a stone sink; hanging pans; a bread bin | none |
| SC-08 | 1536x1024 | CAMERA OUTDOOR. Your street by day, harsh white-gold sun, cold blue shade | your house's porch; a baker's stall with an awning and bread; a gas lamp post; a big tree; a carriage with a horse; a bench; shade patches under the awning, tree and porch clearly separate from sunlit patches | none |
| SC-09 | 1536x1024 | CAMERA OUTDOOR. The same street at night, a full moon, lit windows, lit lamps, mist, wet cobbles (edit SC-08) | the porch; the lamps; the baker's stall closed; a figure far down the street under a lamp, seen very small | a tiny distant figure |
| SC-10 | 1536x1024 | CAMERA OUTDOOR. A corner tavern at night: stone and timber, a hanging iron lantern, a blank painted sign | the heavy door with an iron bolt and lock; steamed windows with silhouettes of people inside; steps; barrels; a lamp; wet cobbles | none |
| SC-11 | 1536x1024 | Inside the tavern: low timbers, a hearth, round tables, a long counter; bottles only as background | the long counter; the hearth; the door; the stairs; the room is silent and every person is turned toward the door, afraid | the tavernkeep behind the counter (CS-02), six patrons as dark figures |
| SC-12 | 1536x1024 | CAMERA OUTDOOR. A narrow brick alley at night with a sharp corner, one gas lamp, fog | the corner; puddles; crates and a barrel; a drainpipe; a lit window high up | none |
| SC-13 | 1536x1024 | CAMERA OUTDOOR. A wide gas-lit street at night where every lamp is almost blinding: huge soft halos, harsh reflections in the wet stone, as if seen with painfully sensitive eyes | shuttered shops; a dog barking on a step; a cart; a steam vent | none |
| SC-14 | 1536x1024 | CAMERA OUTDOOR. An iron bridge over a canal and a tram stop in wet night rain, a red tram far away | a tram stop shelter with blank signs; a ticket booth; a blank street-map board; a striped barrier; wet tram rails | none |
| SC-15 | 1536x1024 | A narrow cigar shop on the harbor, lamp-lit, masts in the window | a counter with a brass scale; a wall of wooden cigar boxes; jars; a ledger; a glass of water on the counter; a stool; the door to the back room | none |
| SC-16 | 1536x1024 | The cigar shop's back storeroom: tobacco leaves hung to dry in rows, smoke haze | the drying racks; stacked crates; a cot with a rough blanket; a hanging oil lamp; a small barred window; a barrel | none |
| SC-17 | 1536x1024 | CAMERA OUTDOOR. The docks by day: harsh sun, deep shade under a customs shed | a tall moored ship with a gangway; crates; ropes; the customs shed; a fish stall; gulls | none |
| SC-18 | 1536x1024 | The same docks at night, fog, lamp reflections on the water (edit SC-17) | the ship with lit windows; the gangway; lamps | none |
| SC-19 | 1536x1024 | The ship's deck by day | rigging; a hatch down; the wheel; coiled rope; barrels; the door to the captain's quarters | none |
| SC-20 | 1536x1024 | The captain's quarters: a low cabin with stern windows, a swinging brass lamp | a chart table with a harbor map; a ship's log; a cot; a sea chest; a tin cup of water; a locked drawer; a silver pocket watch on a chain lying on the desk | none |
| SC-21 | 1536x1024 | CAMERA OUTDOOR. The city's west gate at night. Attach `city_gate_night_2` and redraw it clean | the stone gate with two towers and plain dark-red banners (a plain pale vertical mark, no emblem); torch posts; wet cobbles; the road leaving into the forest | none |
| SC-22 | 1536x1024 | A forest path at night: dense dark trees, roots, fog, moonlight through the canopy | a narrow path; a low hanging branch; a warm pool of lamp light on the path ahead | none |
| SC-23 | 1536x1024 | CAMERA OUTDOOR. A small stone cottage swallowed by ivy and vines at night, a dim amber window, thin smoke | the door; the window; herb beds; a woodpile; an old well | none |
| SC-24 | 1536x1024 | The Old Man's main room: a hearth with a low fire, drying herbs on the beams | shelves of old books and jars; a big table with an open book; two chairs; a cot; a kettle; a cracked window | none |
| SC-25 | 1536x1024 | The Old Man's study: cluttered, one candle | a desk of papers and handwritten notes (unreadable); glass retorts and small scales; shelves of herb jars and bottles; a stack of books; a magnifier; a locked cabinet | none |
| SC-26 | 1536x1024 | CAMERA OUTDOOR. The forest road at 7 am: a wide dirt road through tall trees, a low golden sun, long dramatic shadows, dust; the city walls and spires far ahead in haze | patches of tree shade clearly visible along the road; a milestone | none |
| SC-27 | 1536x1024 | CAMERA OUTDOOR. A market edge in full midday sun, white-gold, high contrast | a hat stall with one hat hanging unattended on a hook; awnings; barrels; a lamp post | none |
| SC-28 | 1536x1024 | CAMERA OUTDOOR. A stone colonnade with strong stripes of shade and sun | a clothes line with cloth and a scarf; a fountain; a narrow side street | none |
| SC-29 | 1536x1024 | CAMERA OUTDOOR. A cathedral square at dusk: the gothic facade looming, gargoyles, a rose window | a wide stair; candles at the door; pigeons; long cold shadows | a priest as a small silhouette |
| SC-30 | 1536x1024 | The whole city from outside at night. Attach `city_gate_night_1` and redraw it clean | a walled gothic city with spires and lit windows on the left; masted ships in a harbor far back; a stone gate in the centre; a wet cobbled road to the foreground; a forest and a river on the right; a full moon; mist | none |
| SC-31 | 1536x1024 | The gate and the forest road close up. Attach `city_gate_night_2` and redraw it clean | the gate; torches; the road; the dark forest; the river | none |
| SC-32 | 1536x1024 | A memory fragment: a sound. Soft focus, desaturated, a heavy vignette | a bell swinging in the dark, motion blur, a blurred bright lantern | none |
| SC-33 | 1536x1024 | A memory fragment: a smell | cigar smoke curling around a glowing ember in the dark | none |
| SC-34 | 1536x1024 | A memory fragment: half a face | half a face lit from the side, one eye, a high collar, the other half in darkness, a hand with a ring at the edge (no one the viewer can identify) | half a face |
| SC-35 | 1536x1024 | **Extra, not in the 34**: the map of Vellmoor, an illustrated aerial map, dark parchment, gold hairlines | eight districts (market quarter in the centre, lantern row east, residential west, old town hill north, railway and works south, harbor south-east, west gate and the forest beyond); a river entering from the west and a canal to the harbor; blank cartouches for labels | none |

**Assembled example (SC-01), paste as one prompt:**
> *[MASTER STYLE] [CAMERA ROOM] [LAYOUT] Small Victorian bedroom, grey Friday morning light through a tall window, a small coal stove glowing. Must show, each clearly visible and separate: an iron bed with a rumpled blanket and a faint dark stain on the pillow; [THE STRANGE COAT] draped over a wooden chair; a wall calendar; a wardrobe; a desk with a candle and papers; a nightstand; the window; a door to the landing; a doorway to the bathroom. No person. [NEGATIVE]*

## Batch 2: the zoom cards (18, 1024 x 1024)

Formula: **MASTER STYLE** + *"Macro close-up of [the line], shallow depth of field, a warm key light, a dark vignette, a young woman's pale slender hand at the edge of the frame for scale"* + **NEGATIVE**, the CS-01 sheet attached so her hand and sleeve match (all writing is unreadable scribble: the game overlays the real text in EN and ES).

| Id | Object | Line |
|---|---|---|
| CD-01 | OB-01 the sewn pocket | a pale hand pulling a folded note out of a torn-open inner pocket of THE STRANGE COAT, crude black stitches hanging from the cut seam |
| CD-02 | OB-02 matches | a worn cardboard matchbox with an oval emblem of a crossed cigar and a leaf (no letters) |
| CD-03 | OB-03 the note | a folded off-white aged note with a crease, rows of unreadable handwriting-like scribble, a faint ink thumbprint |
| CD-04 | OB-04 the witness's note | the same kind of note held in a shaking hand with a frayed cuff, a different crease |
| CD-05 | OB-05 watch, closed | a silver pocket watch with a closed engraved case, a small ornate emblem at the centre, a short chain, a faint warm glow |
| CD-06 | OB-05 watch, open | the same watch open: a white dial, black hands, the inner lid with an empty ornate cartouche (leave it blank) |
| CD-07 | OB-05 watch, broken | the same watch cracked, the glass split, the gears and spring spilling, lying in a red, blistered, swollen palm |
| CD-08 | OB-10 water | a clear glass of water on a wooden counter, trembling ripples, the light on the water almost too bright |
| CD-09 | OB-11 cigar logo | a wooden cigar box lid from above with a gold-leaf embossed emblem (no letters) |
| CD-10 | OB-14 the arm | a forearm with a shallow scratch beaded with blood, half wrapped in torn cloth, dirt rubbed over it; a hand holding an oil lamp at the edge |
| CD-11 | OB-16 notes page, initials | a page of cramped unreadable handwriting, a sketch of a vial and herbs, a blank cartouche stamp in the corner |
| CD-12 | OB-16 recipe page | a page laid out like a recipe: drawn herb sprigs in a column, unreadable lines |
| CD-13 | OB-16 "first batch" page | a page with a large underlined unreadable heading, a dark brown stain, a pressed leaf |
| CD-14 | OB-17 herb list | a thin strip torn from a notebook, a short column of scribbled lines and small herb sketches, a round harbor stamp (no letters) |
| CD-15 | OB-20 the sigil | an engraved emblem on dark metal. **Make three options** for the owner to pick: A an eye in a circle crossed by two keys; B a crescent over a key and a thorn branch; C a serpent biting a clock gear |
| CD-16 | OB-22 harbor man's watch | a weathered hand holding the same silver watch by its chain, identical engraving, a navy sleeve cuff with a brass button |
| CD-17 | OB-23 calming dose | a small glass vial of dark amber liquid with a cork, held up to candlelight, a blank paper label |
| CD-18 | OB-26 family portrait | an old framed portrait of a stern family of five in 1860s clothes, the faces dark and unclear, an ornate dark frame, dusty glass |

The neck close-up (OB-07 / OB-27) is the Landing art: already made.

## Batch 3: interface icons (one sheet, 1024 x 1024)

> MASTER STYLE. A sheet of nine embossed antique-gold icons on a plain dark near-black background, arranged in a 3 x 3 grid, equal size, centred, no text, soft gold highlights and a dark inner shadow: 1 a leather briefcase; 2 a folded map; 3 a journal with a ribbon bookmark; 4 a small house with a crescent moon over it; 5 two people's heads side by side; 6 a sun with rays; 7 a crescent moon; 8 a round magnifying glass; 9 a diamond (lozenge) bullet. NEGATIVE.

Ids: `UI-01`..`UI-09` in that order (inventory, map, journal, shelter, contacts, sun, crescent, magnifier, diamond). Frames, bars and panels are made in code.

## Order to make them (so the first playable step comes early)

1. **Batch 0 first**: CS-01 only (the player), then the MASTER STYLE test: SC-01. If the two feel right, the rest follow.
2. Day-1 rooms: SC-02..SC-07, CD-01, CD-02, CD-03, CD-05.
3. Day-1 bar and crossing: SC-10, SC-11, SC-12, SC-13, SC-14, CS-02, CS-03.
4. Shop, gate, forest, the Old Man: SC-15, SC-16, SC-21..SC-25, CS-04, CS-05, CD-06, CD-07, CD-10.
5. Saturday: SC-26..SC-29, SC-17..SC-20, CS-06, CD-16, CD-17.
6. The rest: SC-30..SC-35, CS-07, CD-04, CD-08, CD-09, CD-11..CD-15, CD-18, UI-01..UI-09.
