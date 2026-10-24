# Turned: art direction v2 ("make it look like that")

2026-10-23. The owner supplied six pictures (`reference/art/turned/mockups/`, not committed: licence not recorded yet; the owner's art is made with ChatGPT, see `media/licenses/OWNER_GAME_ART.md`): four **portrait mockups of a hypothetical game** (a bedroom, a shop, a wet tram street, a foyer) and two **landscape night paintings** of a gothic city, its west gate and the forest road. The owner's question: can Turned look like that?

## 1. What "that" is (measured on the four mockups, 941 x 1672)

| Trait | What the pictures do | Rule for Turned |
|---|---|---|
| Camera | High three-quarter view, looking down about 55 degrees into a room with the front wall removed (a cutaway diorama). The whole room is visible; the person is small (about 22% of the height), centred, lower third | every scene painting uses this camera; outdoors the same angle on a street |
| Light | One warm key (a lamp, a fire, a window) against cold teal-blue shadow; deep vignette; dust and haze in the beams | amber `#c29d84` / `#ce9e58` on near-black `#0e0c0a` `#1a120d`; shadows `#091318` `#1b1e20` at night |
| Depth | Blurred foreground objects in the lower corners (books, a barrel) frame the scene | ask for it in every prompt |
| Finish | Painted-realistic, film grain, wet reflective surfaces, rich fabric, brick and wood detail | one master style paragraph pasted into every prompt (`ART_PROMPTS_V2.md`) |
| Interaction | Round **hotspot chips** with a magnifier and a label sit on the things you can examine; some open a **zoom card** (a macro painting of the item, a gold frame, a title) | the chips and cards are drawn by the game in EN and ES; the painting has no text |
| HUD | Top-left a round portrait ring and two bars (Health red `#8f3634`, Sanity blue `#5d91a2`); under it the objective panel (three diamond bullets); top-right the day chip (sun or moon, "Day 1 / Morning"); bottom a five-slot bar (Inventory, Map, Journal with a red badge, Home, Contacts) | built in code in the same style, see section 3 |
| Palette of the UI | panels `#16100b` (black-brown, translucent), chip `#201d1e`, nav `#0a0a0a`, muted gold line `#b6a58d`, bright gold `#ce9e58`, white serif text | one token set, in `turned_tuning.json` when built |
| The night city | Wide painted view: a walled city on the left, a stone gate with banners in the middle, a wet cobbled road, a dark forest and a river on the right, ships and a harbor in the far left, a full moon and mist | these two are the look of "Vellmoor from outside" (`SC-30`, `SC-31`) and of the map |

## 2. What can and cannot be done

- **Code cannot paint this.** The game today draws everything in code (lit shader cobbles, outlined people). That is a flat top-down look and it will never reach a painted, lit, photoreal diorama. Do not expect a shader pass to turn one into the other.
- **The owner paints it** with ChatGPT image generation, as with the Landing and the other owner art: `ART_PROMPTS_V2.md` has every prompt (master style, the player's sheet, 34 scenes, 18 cards, 7 characters, UI icons, the map), so every picture matches. I cannot generate or paint images from this session; there is no image tool here.
- **Claude Code does the rest**: the pipeline (convert, size, credit, drop in), the Scene mode that shows a painting with hotspots, the zoom cards, the HUD in this style, the map screen with its routes, the dialogue over a scene, the saves and tests. None of this is built yet.

## 3. The HUD and hotspot style (to build in code, no picture needed)

### Landscape layout
The painting (3:2) is shown **whole, fitted to the height** of the safe area, centred; nothing is cropped. Phones are wider than 3:2 (16:9 is 1.78, 19.5:9 is 2.17, 20:9 is 2.22), so the leftover width becomes two side margins (8% each at 16:9, 17% each at 2.17, 18% each at 2.22) filled with the painting's own edge, blurred, darkened and vignetted (no stretch, no black bars). The interface sits like this:

| Where | What | When the margin is too thin (about 16:9) |
|---|---|---|
| Left margin, top | portrait ring, the two bars | overlaps the painting's top-left corner (kept calm by the prompts) |
| Left margin, middle | objective panel | same, smaller |
| Right margin, top | day chip | top-right corner |
| Right margin, bottom to top | the nav bar as a **vertical** strip of five slots (Inventory, Map, Journal, Shelter, Contacts) | a strip over the painting's right edge (the prompts keep it calm) |
| On the painting | hotspot chips, zoom cards, the dialogue box (bottom, over the lower 12%) | same |
| A window narrower than 3:2 (tablet, 4:3) | the painting is fitted to the width and the HUD overlays the corners | |

The built Walk-mode controls (pad, A/B, Pause, Menu: `docs/claude/pad.md`) stay as they are; Scene mode needs only taps, so it shows no pad.

### Pieces

| Piece | Spec (in units of a 941-wide picture, the mockup's scale; the game scales it to the screen) |
|---|---|
| Portrait ring | 145 across, a gold double ring, the player's bust inside (`CS-01` mood busts) |
| Bars | two rounded bars about 165 x 16 inside a dark pill with a thin gold border; Health red, and the second bar (see decision 3) |
| Objective panel | dark translucent `#16100b` at 85%, thin gold line, small filigree corners, 3 lines max, a gold diamond bullet, white serif text 21 |
| Day chip | gold-bordered dark box at the top right: a sun (day) or crescent (night) and two lines "Day 1" / "Morning" (the game's clock already has the hour) |
| Nav bar | five equal slots over a near-black bar with a gold top line; embossed gold icons (briefcase, folded map, journal, house or bed, two heads) and a serif label; a red dot on Journal for a new entry |
| Hotspot chip | a dark pill `#201d1e` with a gold hairline, a round magnifier at the left, a white serif label 18; sits on the object; a tap examines |
| Zoom card | 40% of the width, a gold ornate frame, a title at the top, the macro painting, a small caption chip at the bottom; fades in near the hotspot |
| Type | a free (OFL) serif: **Cinzel** for titles and **Cormorant Garamond** for text are the nearest. The hub ships no such font; adding one needs `media/CREDITS.json` and a licence file (the owner's rule) |

Icons (the five nav icons, the sun and the crescent, the magnifier, the diamond) are the only HUD pieces worth generating as pictures (`UI-01`..`UI-09`). Frames, bars and panels are cheaper and sharper in code.

## 4. How it fits the game as it is built

| | **Walk mode** (built) | **Scene mode** (new) |
|---|---|---|
| What | Real-time top-down walking with the sun clock, shade and death | A painted scene with hotspots, zoom cards, dialogue over it |
| Good for | Streets, the sun trek, the forest path, stealth, the night crossing | Rooms: the bedroom, the shop, the foyer, the captain's quarters, the Old Man's house; investigations, the story |
| Look | Drawn in code; painted props, people and tiles swap in by file name (`ART_SPEC.md`) | The mockups' look: the whole room is one painting |
| Orientation | landscape, locked | landscape, locked (decision 1): a 3:2 painting, interface in the side margins |

**Proposal**: keep both. Rooms and story beats are Scene mode (this is the look of the mockups, and it is the spec's own "hybrid: short tap-to-explore moments plus dialogue scenes"). Outdoor sun sections stay Walk mode and get the painted look over time through the PNG overrides (people, props, ground). The map screen is a painted picture with the districts as hotspots (`WORLD_MAP_AND_QUESTS.md`).

## 5. Conflicts and decisions (the owner's)

1. **DECIDED 2026-10-23: landscape.** The mockups are portrait phone shots; Turned stays locked landscape (`Orientation.lock_landscape()`, decision 28), and so does Scene mode. Every scene is painted **1536 x 1024 (3:2)**; the mockups' look, camera and interface are kept, only the format changes. The interface moves to the screen's sides (section 3, "Landscape layout"). The prompts in `ART_PROMPTS_V2.md` are already 1536 x 1024; the mockups' portrait framing is not to be copied.
2. **The mockups' story is not Turned's.** Bellmere Lane, the City of Ardbrook, the caretaker, the missing poster, the address card, "Shop Keys" and a shop where the player works are the mockup's. Turned's bible has no job for the player yet (bible 3 DECIDE) and the shopkeeper is a different person (PE-06). Use the pictures for **look and interface only**.
3. **Sanity vs Blood.** The mockup has Health + Sanity; the built engine has Health + Blood (hunger) + XP. A hunger bar fits the story. Sanity is not in the bible. Proposed: Health + Blood in the same style; no Sanity until the owner asks.
4. **"Home" in the nav bar** collides with the hub's N2 (🏠 Home = back to the Landing). Proposed label: **Shelter** (your day hiding place, SQ-21); the pause menu keeps 🏠 Home.
5. **No baked text.** The mockups have text in the picture (labels, "OPEN", "TICKETS", street names, a newspaper). The game is EN + ES, so every painting must have blank signs and unreadable scribbles; the game draws all labels.
6. **The player's look.** The mockups show one young man (dark wavy hair, brown waistcoat, cream shirt). The bible says both genders are playable (DECIDE). The prompts use the mockup's man as the reference; a second sheet for a woman is a prompt swap. **DECIDED (owner, 2026-10-24): the player is a young woman, no male version.** She keeps the mockup's hair, eyes, waistcoat and colours (blouse and walking skirt instead of shirt and trousers); `ART_PROMPTS_V2.md` THE PLAYER has her.
7. **Alcohol.** The bar scenes (`SC-10`, `SC-11`) are allowed (the owner's Turned exception, decision 46); keep bottles as background only, never a feature.
8. **Pack size.** 35 scenes (1536 x 1024) + 18 cards at about 300-450 KB each (webp or JPEG q84) is about 15-20 MB. Fine for a GitHub Releases pack; say if there is a cap.
9. **Licence record.** Add the Turned scenes to `media/licenses/OWNER_GAME_ART.md` with the ChatGPT plan used and each prompt's source file (kept unshipped in `reference/art/turned/gen/`), and a `media/CREDITS.json` entry per shipped file. Never ship the mockups themselves.
10. **The player is not painted into the scenes.** The mockups show him standing in every room. A painting with him in it cannot change with the story (coat on, hat, burns). The prompts paint the rooms empty; the player is the HUD portrait and, if wanted, a sprite the game places. Say if you want him painted in (a prompt swap, one variant per outfit).
11. **Initials and the sigil are the owner's.** The watch's initials belong to B (canon); the sigil's design is unwritten. The prompts leave the initials as an ornate blank and ask for three sigil options to choose from.

## 6. Pipeline (what happens to a picture)

1. The owner generates it with the prompt of the same id; saves the PNG as `reference/art/turned/gen/<id>.png` (source, never shipped).
2. Claude converts it: `games/turned/art/scenes/<id>.webp` (quality 84, 1536 x 1024), a `CREDITS.json` entry, a hotspot file `scenes/<id>.json` (label ids and positions, found by looking at the picture), and the Spanish labels in `es.json`.
3. Checks: `python tools/hub.py check`, the Turned test, a screenshot at text scale 1.0 and 1.4 at 16:9, 19.5:9 and 4:3 (the painting is fitted whole, so nothing is cropped; the interface may cover the top corners and the bottom 12%, which the prompts keep calm).

## 7. Not built (said plainly)

No painted image exists yet. Scene mode, zoom cards, the new HUD, the map screen, the Journal tabs and the Shelter system are not built. The hub's `turned` pack on the Landing is unchanged. The owner's first step is the master style and the player's sheet (`ART_PROMPTS_V2.md`, batch 0).
