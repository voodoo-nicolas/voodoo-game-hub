# The Runner: hub brief (2026-11-02)

Hand-off for the session that builds the game. Read in this order: this file, `GAME_DESIGN_THE_RUNNER.md` (owner's design doc, copied unchanged from `D:/dev/minigame art/runner/`), the `viral-minigame` skill, `docs/claude/pad.md`, `docs/claude/turned.md` (closest existing game: story + painted scenes + Pad + in-game Menu).

**Where the two disagree, the hub's CLAUDE.md / STANDARDS win** (navigation, pause, save, i18n, packs, media). The design doc was written for a stand-alone game (`/data`, `/scripts/core`, placeholder shapes, "ask about monetization"): adapt as listed in section 3.

## 1. Owner's words (2026-11-02)
- Earth is destroyed, resources dried up, people moved to the Moon. The hero explores the universe, skirting authority and making money.
- Views: the owner's images as they are, **or** a solar system with the ship floating from one planet to the next.
- Uses the shared Pad, sticks/buttons not seen or mostly transparent (Pad default opacity is already 25%; owner 2026-11-02).
- Single player only.
- A Menu button opens an in-game menu with tabs: **Inventory, Skill Tree, Missions, Map, Ship Layout, Stats**.

## 2. The art (`D:/dev/minigame art/runner/`, owner-made with ChatGPT / Gemini, 1408x768 JPG unless noted)
| Use | Files |
|---|---|
| Landing hero / title | `runner landing.jpg` (hero in a hangar, "THE RUNNER" painted in) |
| Prologue | `earth.jpg` (ruined Earth in a debris ring), `moon.jpg` (lunar colony domes) |
| Docked views (Scene mode: painting + hotspot chips, like Turned) | `moon port.jpg`, `port2.jpg`, `spaceport.jpg` (hangars seen from the cockpit) |
| Arrival views (cockpit window over a world) | `fire planet`, `ice planet`, `jungle`, `fungus`, `rocky`, `sandy`, `waterworld`, `asteroid` |
| Solar-system map (ship travels along the orbits) | `system1`, `system2`, `system3`, `371efe74-...jpg` (1024x673, numbered stops 1-12), `ChatGPT Image ... 07_34_40.png` (1547x1017), `... 07_35_40.png` (1672x941, black-hole centre) |
| Galaxy map / jump backdrop | `constellation.jpg`, `dragon.jpg` (dragon constellation), `Gemini_Generated_Image_...jpg` (Milky Way over a ridge) |
| Encounters / hazards | `meteor shower.jpg`, `black holes.jpg` (binary black hole) |
| Ship Layout tab | `ship.jpg` (ship + exploded module diagram + hangar parts) |

Prep: convert to WebP (~150-250 KB each) into `games/the_runner/art/`, one `media/CREDITS.json` entry per file (AI: tool + plan, owner-made), licence note in `media/licenses/`. All art is landscape 16:9 → **landscape game**. Orbit images: planet positions are traced as fractions of the picture (same trick as Turned's painted house), the ship is drawn in code over them.

## 3. Adaptations to the hub (decided here unless marked OPEN)
- Files: `scripts/games/the_runner/` (engine `RefCounted` = all rules, headless-testable; game `Control`; help; i18n generated), data JSON in the game folder (`games/the_runner/data/*.json`), not repo-root `/data`. Pack-safe: no autoloads, `load()` never `preload()` for APK-side scripts.
- Title text from the hub (`title` / `title_es` in the manifest); the painted title in the hero art stays as art.
- Art: the owner's images, not placeholder shapes; shapes only where no picture exists yet (list them in `DECISIONS.md`).
- Monetization: none (hub rule). Multiplayer: none (owner). Platform: phone + PC (Pad maps keyboard).
- Navigation: Landing kit (Resume / Quick Play = 1 tap, New game, 🏆, 🏅, ❓, ⚙). **Pause pill = kit pause menu** (standard). **Menu pill = the ship computer** (the six tabs). Android back during play = pause menu.
- Save: versioned JSON via `SaveUtil`, from day one (design doc §0 agrees).
- Content: contraband stays **fictional** (forged IDs, stolen tech, relics, bootleg data, "stims" with invented names; no real drug names). **No alcohol as cargo, label or reward** (hub rule). No trafficking / slavery / sexual content (design doc §0 agrees). Manifest `content` gets crime/violence descriptors; never market as kids' education.
- Combat: turn-based cards of choices (fight / flee / bribe / bluff / dump cargo) first, per design doc §3.11.
- Every game rule: hint system (3 max, +1 per 24 h), 🏆 board = **net worth** (higher is better), 🏅 achievements (first run, first bribe, first blind spot, 1M / 10M / 1B net worth...), EN + ES, both skins or a documented reason (Voodoo skin = neon HUD over the same art).
- Learning hook (owner likes games that teach): real astronomy facts on each world type and hazard (black holes, meteor showers, ice / lava / ocean worlds, constellations) as optional `FACTS`; supply and demand shown on the market price chart. Switchable, never blocking.
- Audio: shared `Music` autoload (a calm space style in port, tense style on a run); sounds from the shared library `scifi/*` (engine, doors, computer, force field, impacts, explosions). Sprites if needed: shared `space/*` (Kenney, CC0).

## 4. Screens
1. **Prologue** (skippable, 3-4 cards): Earth in debris → the Moon colony → a broke courier in debt to Mother Kessel → Old Marrow hands over the Runner.
2. **Dock** (painted port + hotspots): Market (legal + black), Shipyard, Fixer / job board, Launch.
3. **System map** (orbit image): stick moves a selection ring between bodies, A = plot course (shows fuel, law level, heat risk), the ship glides along the orbit, a random encounter may stop it halfway.
4. **Arrival** (cockpit window painting): scan check / patrol / land.
5. **Encounter** (hazard or ship over a backdrop): choice cards, turn-based.
6. **Galaxy map** (constellation art): later milestone (gates, Rift Keys).
7. **Ship computer** (Menu pill), tabs:
   - **Inventory**: legal hold + hidden hold, cargo value, dirty / clean credits.
   - **Skill Tree**: the six specializations of design doc §7.2 as six branches (Smuggler, Pirate, Fixer, Forger, Enforcer, Launderer); 1 primary + 1 secondary, points from XP.
   - **Missions**: main / side / contracts, tracked one pinned on the HUD.
   - **Map**: system + galaxy, known blind spots, heat by faction coloured on it.
   - **Ship Layout**: `ship.jpg` as the backdrop, slots (engine, cargo, shields, weapons, scanner, special, hidden hold) tappable to swap modules.
   - **Stats**: net worth, heat per faction, infamy / street cred, runs, scans passed, best haul.

## 5. Suggested extra tabs / ideas (owner to pick)
- **Contacts / Factions** tab (reputation, heat, bounty per faction): the design doc leans on 7 factions; Stats gets crowded without it.
- **Log** tab (story so far, informant tips, news events that move prices).
- **Crew** tab once crew exists (milestone M9).
- A **News ticker** on the dock (crackdowns, festivals, blockades) so price swings feel earned.
- **Ghost Core meter** on the HUD: the one thing that makes this ship special, always visible.

## 6. Build order (design doc §11, cut for the first pack)
- **Pack v1 (first playable):** prologue, Moon port + 4 worlds of `system1`, 10 goods (4 contraband), legal + black market, fuel and travel along orbits, scan check with bribe / flee / dump, heat for one faction (Concord), dirty vs clean credits + one laundering front, Menu with all six tabs (Skill Tree with the Smuggler branch live, the others shown locked), save / resume, M01-M02, economy simulation test (10,000 runs, no infinite money).
- Then: encounters + combat (M4) → missions M03-M04 + 5 side jobs (M5) → factions / infamy / cred (M6) → network (M7) → piracy (M8) → crew (M9) → galaxies 2-4 + endings (M10).

## 7. Answered (owner, 2026-11-02)
1. Id `the_runner`, title "The Runner" (same in Spanish).
2. Hero: fixed, the man in the landing art.
3. Category: Adventure.
Pack v1 as built: `docs/runner/DECISIONS.md` (defaults + what is not built), code map `docs/claude/the-runner.md`.
