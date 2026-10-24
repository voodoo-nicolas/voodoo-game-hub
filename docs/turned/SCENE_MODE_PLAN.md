# Turned: Scene mode plan (landscape)

2026-10-23. Decided by the owner: Turned stays landscape, scenes are painted 1536 x 1024 (`ART_DIRECTION_V2.md`). **Nothing here is built.** Per the owner's rule, each phase starts with a task list and waits for the OK; phases S1-S7 below are the proposal, S1 is the first to approve.

**Status (2026-10-24): S1, S2 and S3 are built** (the foundation with a drawn placeholder instead of paintings, the Scene HUD, and the zoom cards; decisions S1-1..S1-8, S2-1..S2-6 and S3-1..S3-7 in `DECISIONS.md`). S4-S7 are not.

## 1. What Scene mode is

A new world mode `"scene"` next to `play`, `dialogue`, `closeup`: the screen shows one painting with labelled hotspot chips. A tap (or A / Enter on the highlighted chip) examines: a line of text, a zoom card, a dialogue scene, an item, a flag, or a move to another scene or to a Walk-mode area. Rooms and story beats are Scene mode; streets, the sun, stealth and the forest stay Walk mode (`ART_DIRECTION_V2.md` section 4).

## 2. How it fits the built code

| Piece | Plan |
|---|---|
| Where it lives | `turned_scene_view.gd` (a Control: the painting, the margin fill, the chips, the cards), shown by `turned_game.gd` between the world and the HUD, like the Pad is. The world gets `mode = "scene"`, which freezes the walk (`_frozen()`), keeps `engine`, `clock`, `dlg` and the save as they are |
| Scene HUD | A **new** `turned_scene_hud.gd` (ring, bars, objectives, time chip, vertical nav strip) rather than rework `turned_hud.gd`, so Walk mode and the HUD another session is editing do not move. It reads `engine` (Health, Blood, missions, journal) and the clock, and honours `hud.reveal(...)` (progressive reveal: Map, Shelter, Contacts stay hidden until introduced) |
| Dialogue | Reuses `turned_dialogue.gd` and `turned_dialogues.json` unchanged; the box is drawn in the painting's bottom band. New effects `scene:<id>` and `card:<id>` are added to the runner (`area:` already exists) |
| Menu, Journal, Items | The existing menu (`open_menu(tab)`); nav buttons open its tabs. Items get their card art |
| Data | `scripts/games/turned/turned_scenes.json` (scenes) and `turned_cards.json` (cards); words by id in `turned_text.gd` + `es.json`; numbers in `turned_tuning.json` (a missing key fails the test, as today) |
| Conditions | The runner's own (`flag: item: journal: mission: hour>= hour< day>=`): one evaluator, exposed for hotspots |
| Save | `engine` flags keep what was examined (`seen:<scene>:<hotspot>`); the save gets one `scene` key (current id) so Resume returns to the same painting; old saves load unchanged |
| Pack rules | No autoload, no `preload` of APK-side scripts, JSON and art in the game folder (`games/turned/art/scenes/`), every file credited; works on the web build (synchronous `load`, one painting resident at a time plus the next) |
| Navigation rules | Pause menu on Android back (N4), saves on leaving (N5), kit `kit_up` freezes it like the world |

### Scene data (one entry)
```json
{ "id": "bedroom", "art": "SC-01", "variants": [{"when": "hour>=18", "art": "SC-02"}],
  "walk_area": "house",
  "hotspots": [
    {"id": "coat", "label": "hs_coat", "pos": [0.62, 0.55], "when": "", "once": false,
     "do": ["dialogue:coat_examine"]},
    {"id": "calendar", "label": "hs_calendar", "pos": [0.30, 0.30], "do": ["look:calendar", "journal:calendar"]},
    {"id": "door", "label": "hs_door", "pos": [0.93, 0.60], "kind": "exit", "do": ["scene:landing"]} ] }
```
`pos` is a fraction of the painting, so the same data fits every screen. `walk_area` links the room to its Walk map: while there is no painting the Walk room is used, and when the painting exists entering the area opens the scene (nothing breaks; one room at a time).

### Fit and chips
- Painting fitted whole to the safe-area height; side margins filled with the painting's own edge (mirrored, blurred, darkened, vignette), built once at load; narrower than 3:2 fits the width (`ART_DIRECTION_V2.md` section 3).
- Chip: a gold magnifier circle and a serif label, at least 48 dp tall, scaled with `_ui()` and the text size (tested at 1.0 and 1.4); label to the right of its circle, flipped left near the edge, nudged so two chips never overlap; a chip never sits under the HUD (the test checks `pos` against the safe zone: central 80% width, 20%-86% height).
- Input: one tap on a chip examines (`MouseButton` only: phones send every tap twice); keyboard/pad: Tab or arrows move a highlight, E or A examines; the Pad is hidden in Scene mode.
- Hotspot visibility option (Pause, Options): **always** (the mockups), **on tap** (a Look button flashes them), **off after found**. Default: always.

## 3. Phases

| Phase | Builds | Needs |
|---|---|---|
| **S1 Foundation** | `turned_scene_view.gd`, the loader and validator for `turned_scenes.json`, world mode `scene`, input (tap, keyboard), examine actions (`look`, `journal`, `item`, `flag`, `dialogue`, `scene`, `area`), Resume, tests, a screenshot tool. Placeholder paintings are generated by a small tool (a dark gradient with the room's boxes labelled) so it all runs and is tested with no art | nothing from the owner |
| **S2 Scene HUD** | `turned_scene_hud.gd`: ring (a drawn silhouette until `CS-01` busts exist), Health and Blood bars, objective panel, time chip with the clock, the vertical nav strip with reveal rules; the margins at 16:9, 19.5:9 and 4:3; text scale 1.0 and 1.4; screenshots | the HUD style is in code, no pictures |
| **S3 Zoom cards** | `turned_cards.json`, the card view (gold frame, title, caption), the card text drawn by the game in EN/ES over the paper picture, the Items tab showing the card art | the 18 cards as they come (or placeholders) |
| **S4 Dialogue in scenes** | the box in the bottom band, the bust to its left (placeholder until the busts exist), `scene:` and `card:` effects, a fade between scenes | busts as they come |
| **S5 First real room** | the bedroom: `SC-01` and `SC-02` as the first painting, hotspots placed by looking at the picture, the Walk bedroom kept for the prologue (below); the checklist for adding any scene | `CS-01`, `SC-01`, `SC-02` from the owner |
| **S6 The map screen** | `SC-35` with the eight districts as hotspots, the routes and their costs (`WORLD_MAP_AND_QUESTS.md` section 2), time passing, travel into Walk mode areas | `SC-35` |
| **S7 Life and polish** | flickering candle and lamp light, dust motes, a slow drift, ambience per scene (synthesized, the hub's Sfx groups), `art.*` switches for weak devices, a memory check on a phone | none |

After S5 each content phase of `WORLD_MAP_AND_QUESTS.md` section 9 (C1-C6) adds its scenes in the order of `ART_PROMPTS_V2.md`.

## 4. Decisions needed from the owner (my recommendation first)

1. **The prologue**: keep it as the built Walk sequence (wake, hobble, mirror), and use Scene mode from the first revisit of a room? Or rebuild the wake-up as painted scenes too? *Recommend: keep it; it is built, tested and yours; revisit later.*
2. **Outdoor paintings (SC-08 street, SC-13/14 the night crossing, SC-17 docks...)**: (a) only as backdrops for dialogue and the map, (b) also as location screens with hotspots, no sun damage, (c) with the sun: every examine costs game time and burns in unshaded spots. *Recommend: (a) now, (b) later; the sun stays a Walk-mode mechanic.*
3. **Time in Scene mode**: does examining cost game minutes (the 2-3 day pressure), or is time only story and travel? *Recommend: only travel and story, at first.*
4. **Hotspot labels**: always visible like the mockups (the default above), or only on request?
5. **A serif font** for titles and card text: Cinzel + Cormorant Garamond (both OFL) need `media/CREDITS.json` and a licence file; or keep the hub's default font.
6. **A handwriting font** for the note and the pages (the paintings have no text): same question.
7. **Texture memory**: a 1536 x 1024 painting is about 6 MB of video memory; I keep one resident plus the next. Say if older phones are a target (then 1024 x 683 for the web build).

## 5. Not built (said plainly)
Everything above. The only things that exist for it today are the planning documents, the prompts and the six reference pictures; no painted art has been made.
