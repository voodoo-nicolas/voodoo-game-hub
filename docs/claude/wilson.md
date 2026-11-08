# Beached (id `wilson`, castaway sim, Adventure, landscape)

Owner's game, started 2026-11-08 (M0-M2 built, **not published**, not phone-tested). Design on Drive "viral game hub/wilson" (README, KICKOFF with the milestone list M0-M8 and acceptance tests, design/GDD.md, CRAFTING.md, QUESTS.md (121 quests), DIALOGUE.md, art/ART_PROMPTS.md). Data copied to `games/wilson/data/*.json` (read at runtime). Decisions and what is not built: `docs/wilson/DECISIONS.md`; history: `docs/wilson/CHANGELOG.md`. Never ship the word "Wilson" (README); "Johnny" is code-only (DECISIONS W-3).

## Files (`scripts/games/wilson/`)
| File | What |
|---|---|
| `wilson_data.gd` | JSON loader (cached) + the game's own tuning: island layout in plate pixels (lanes, palms, debris, spots, camp), action times / costs, food values, fishing table, lines (DIALOGUE.md), quest hints, bottle notes |
| `wilson_sky.gd` | sun times, keyframe colours, star fade, sun / moon arcs, moon phase (static) |
| `wilson_engine.gd` | the rules (RefCounted): `advance(to, online)` in 10-min steps; bars + offline floor; queue (`enqueue` / `action_block` / `cancel`, absolute end times); sleep / naps / buffs; fire; crafting; shore delivery; tutorial quests (`_emit` events); journal (`log_entry` args: `@id` item, `%id` debris, `#text` / `~text` sentence); `to_dict` / `from_dict` |
| `wilson_world.gd` | the island node: plate + sea shader, palms C / D sprites (sway), debris, props, fire, Johnny, foreground waves; `hit(p)` tap targets |
| `wilson_skyview.gd` | sky gradient, stars, sun, moon with phase, clouds (screen pixels, own layer) |
| `wilson_fire.gd` / `wilson_castaway.gd` / `wilson_props.gd` | campfire, placeholder Johnny, placeholder structures and piles |
| `wilson_debug.gd` | debug panel (F9 / 5 taps on the clock): time x1 / x60 / x3600, jump to an hour, away hours, bars, items, weather, hemisphere, reset |
| `wilson_game.gd` | Landing kit, layers (sky -3, world -2 with CanvasModulate, glow -1, HUD), clock (real + debug offset), catch-up, HUD, context menus, bag / craft / journal panels, save, help "⏩ Hurry up" |

## Tests and tools
- `godot --headless --path . --script res://tools/test_wilson.gd`: 551 checks (KICKOFF acceptance tests, queue / offline, inventory, shore + pity, a full T01-T12 run, save round trip). Pure engine, no saves touched.
- `godot --path . --resolution 1280x720 --script res://tools/shot_wilson.gd -- <dir> [en|es]`: screenshots (backs up and restores the save + debug files).
- `python tools/wilson_art.py`: rebuilds `games/wilson/art/` from `D:/dev/Wilson` (reproducible).

## Rules to keep
- Timers are absolute timestamps; never tick counters. New actions: `action_block` + `_finish` + `D.ACT` + `_stand_spot` in the game.
- Engine messages are English templates + args, translated on screen (`format_entry`); every new string through es.json.
- Single lowercase words are skipped by the i18n extractor: use two words for anything shown (`"wrecked crate"`).
- Packs: no autoloads; GameInfo / Music / Sfx guarded.
