# TURNED — project brief (v0.2)

> Copy of the owner's `CLAUDE.md` for Turned (Google Drive: Viral Game Hub → `vampire` → `05_godot_project`), renamed `BRIEF.md` so it cannot be confused with the hub's own `CLAUDE.md`, which wins wherever they differ (hub navigation/pause/save/i18n/pack rules). The owner's first-slice prompt (2026-10-22) overrides this brief where they differ. What was decided where they met: `docs/turned/DECISIONS.md`.
> Original text follows; its "Read this fully" line referred to `../02_story/story_bible.md` (here: `docs/turned/story_bible.md`) and `../04_audio/audio_plan.md` (not in this repo yet).

Changes from v0.1: controls now match the owner's layout sketch; button unlocks added; "Knowing" villagers (recognition system) added; "gets smarter" reworked as progressive unlocks, with adaptive AI optional.

## 0. Rules for Claude Code
- Engine: **Godot 4.x**, **GDScript**, typed variables. 2D top-down, 3rd person view. Target: **Android (Google Play)**, landscape, touch first.
- Build in **vertical slices**. After every milestone the project must run. Commit after each milestone.
- **Data-driven:** tuning numbers live in `res://data/*.json` or `.tres`, never hardcoded.
- **Never delete or rewrite code the owner commented out or marked.** Leave it and ask.
- Do not forget small details: safe-area insets, touch targets ≥ 48 dp, pause when the app goes to background, autosave, text scaling, 8-way d-pad dead zones.
- Placeholder art is fine (colored shapes). The owner makes the artwork. Load sprites by file name from `res://art/` so swapping is easy.
- If a requirement is ambiguous, pick the default listed here, note it in `DECISIONS.md`, and continue.

## 1. Assumptions to confirm (owner)
1. Visual style: 2D (sprites + tilemaps + 2D lights), not 3D.
2. The blue bar is **Blood** (hunger + power fuel). No separate hunger bar. Sun tolerance is shown as a small sun icon, not a 4th bar.
3. Which buttons unlock when (section 3 table) is a default.
4. "Progressively better" is handled by unlocks and escalating content. The adaptive AI Director (section 9) is OPTIONAL, build last.

## 2. Core loop
Hunt at night, feed to stay alive, hide before sunrise. The sun gets worse each day. Feeding partially restores day-tolerance. Stealth first, combat if needed. Some villagers know what you are becoming. You don't.

## 3. Controls and layout (from owner's sketch, landscape)
```
[HP bar ] [Missions]
[Blood ]
[XP bar ]

D-pad [Pause][Menu] (Y)
 (left)        (X) (B)
               (A)
```
- **D-pad (bottom-left):** 4 arrows. Move 8-way by pressing two arrows. Walk by default. (Sneak is a button, see below.)
- **Face buttons (bottom-right, diamond):** A bottom, B right, X left, Y top. **Start with 2, add 2 later.**

| Button | Function | Unlocks |
|---|---|---|
| A | Context: interact, open, hide, feed, takedown. | Start |
| B | Sneak toggle (slower, quieter, smaller detection). | Start |
| X | Attack (claws, short range). | After the first feeding, Day 3 (**default, tunable**). |
| Y | Power: uses the equipped power. Tap = use, hold = quick-swap radial. | Act 2 (**default, tunable**). |

- Locked buttons are hidden, not greyed. When one unlocks, play a short animation and a message ("Something new is awake.").
- **Bottom-center, two small buttons:** **Pause** and **Menu** (menu = inventory, skill tree, map, journal, settings).
- **Top-right:** **Missions** tracker. Tap to open the quest log. Shows the current objective in one line.
- **Top-left:** three bars (red Health, blue Blood, yellow XP) as in the sketch.
- Keyboard/gamepad for testing: arrows or WASD = d-pad, E = A, Shift = B, Space/J = X, K = Y, Esc = Pause, Tab = Menu.
- Button size and position adjustable in settings. Optional vibration on press.

## 4. Stats and HUD
- **Health** (red): reaches 0 → death (section 6).
- **Blood** (blue per sketch, final color is art's call): hunger AND power fuel. Drains slowly. At 0, Health drains and the screen desaturates. Abilities cost Blood.
- **XP** (yellow): level number beside it.
- **Sun Tolerance:** small sun icon beside the bars, fills or cracks by level (never color-only). Also a screen edge effect in sunlight.
- **Buff row:** under the bars. Icon + timer. **Power cooldown:** ring around button Y.
- HUD never blocks the d-pad or face buttons.

## 5. Sun system (core mechanic)
- World clock: dawn, day, dusk, night. Day length tunable (default 12 real minutes).
- `vampirism_level` rises with each in-game day (0 → 5).
- `tolerance_bonus` gained by feeding, decays each day.
- `effective_level = max(0, vampirism_level - tolerance_bonus)`.
- Feed gain: `bonus = 1.0 * 0.75^(feeds_today)` (diminishing returns).

| effective_level | Sun in open |
|---|---|
| 0 (day 1) | 1 HP/s, slight brightness. Uncomfortable. |
| 1 (day 2) | 4 HP/s, squint + blur. It hurts. |
| 2 (day 3) | 10 HP/s, tunnel vision, audio muffle. "This is not OK." |
| 3+ | Near lethal in about 5 s. |

- Shade zones (tile layer or `Area2D`): roofs, alleys, awnings, canopies. Interiors are always safe. Evaluate at the player's feet.
- If the player dies from sun, respawn at the **nearest shade within 3 m**.

## 6. Death and respawn
- On death: 2 s fade, then respawn in the **same location** (shade-corrected).
- Penalties (tunable): restore 50% Health, lose 25% Blood, lose 10% of current-level XP (never de-level), nearby alerted enemies reset to patrol.
- Track `death_count`.

## 7. Progression
- XP from: feeding, takedowns, puzzles, locks, secrets, clues, avoiding detection.
- Skill points: 1 per level. Slice cap level 10, full game 30.
- **Three branches** (4 slice nodes each): **Shadow** (Soft Steps, Shade Hug, Vanish, Backstab), **Blood** (Efficient Feeding, Quick Heal, Blood Rush, Hunger Resist), **Night** (Sun Resist, Night Sight, Mist Skin, Strength).
- Data: `data/skills.json` with `id, branch, cost, requires[], effects[]`.
- **Progressive growth** (the game "gets better"): mechanics unlock over time through story and levels: buttons X and Y, powers, new areas, new lock types, new town (Act 2), more enemy types. Plan content so each night adds something new.

## 8. Buffs, effects, powers
- Effect system: `id, duration, cooldown, stacking (refresh|stack|ignore), modifiers{}`.
- Powers (equipped to Y): **Night Veil** (near-invisible 8 s, 30 s cd), **Blood Rush** (+30% speed 6 s, 25 s cd), **Mist Skin** (+1 tolerance 20 s, 60 s cd), **Hunter's Sense** (see heartbeats through walls 10 s, 20 s cd). Cost Blood. Cooldowns survive pause and save.

## 9. Stealth, combat, enemies
- Enemies: vision cone, hearing radius, memory; states: Patrol, Suspicious, Search, Chase, Return.
- Lamp light raises visibility, shade lowers it. Hide spots. Takedown from behind. Feeding = silent takedown if unseen.
- Combat: simple, costly (noise, health). Stealth is better.
- **Optional (M8, last): adaptive Director.** Enemies learn habits (e.g. repeatedly used hiding spot gets checked). Difficulty tier rises each night. Capped and telegraphed. Only if time allows.

## 10. The Knowing (recognition system)
Some villagers know who you are and what you are becoming. You don't. Most villagers don't.
- Each NPC has `knows_player`: 0 = unaware, 1 = suspects, 2 = knows.
- Slice target: 3–5 Knowing NPCs in Vellmoor. Roles: **Friend** (warns you, gives clues), **Watcher** (observes, reports), **Hunter** (tracks you), **Devotee** (wants to serve you).
- Their dialogue and behavior change with `vampirism_level` (they notice pallor, flinching, eyes).
- They hold fragments of the mystery. Their lines unlock Missions and journal entries.
- Unaware villagers react to visible signs only (pale, bleeding neck if uncovered, daylight pain), never to the truth.
- Data: `data/npcs.json` with `id, knows_player, role, lines_by_level[], clue_ids[]`.

## 11. Puzzles and locks
- Types: **key**, **combination** (clues in notes/world), **lever / pressure plate**, **light and mirror** (reflect sunlight), **sequence** (bell tones), **lockpick** (timing minigame).
- Data: `data/locks.json` with `id, type, tier(1–5), solution, hint_ids[]`. Higher tiers need clues, items or skills. Notes/journal screen keeps hints.
- Puzzles give XP and unlock areas or shortcuts.

## 12. Save and settings
- Autosave at checkpoints and each new day. `user://save.json` with version number.
- Settings: Master/Music/SFX sliders, text size 1× / 1.15× / 1.3×, layout editing, vibration.

## 13. Project structure
```
res://
 autoload/ (GameState, EventBus, SaveSystem, AudioManager, SunClock, QuestLog)
 scenes/ (prologue, towns, ui, actors)
 scripts/
 data/ (skills, locks, powers, enemies, npcs, quests, tuning)
 art/ audio/ fonts/
```

## 14. Milestones (acceptance test)
| # | Milestone | Done when |
|---|---|---|
| M0 | Project, camera, d-pad + A/B buttons | Move a placeholder on phone/emulator. |
| M1 | Prologue room | Bed → neck → mirror → exit (story bible §8). |
| M2 | HUD, stats, death/respawn | 3 bars + Missions box. Die and respawn in place. |
| M3 | Sun clock + shade | Damage per level, shade protects, feeding changes tolerance. |
| M4 | Stealth | Vision cones, noise, hide, takedown, feed. |
| M5 | Combat + button X unlock | Claws, dodge, unlock animation. |
| M6 | XP, skills, powers, buffs | Level up, spend points, button Y, cooldown ring. |
| M7 | Puzzles and locks | One of each lock type playable. |
| M8 | The Knowing + quests | 3 Knowing NPCs, Missions list updates. |
| M9 | Audio hookup | Per `audio_plan.md`. |
| M10 | Vertical slice | Prologue + Day 1–3 in Vellmoor, Android build runs. |
| M11 (optional) | Adaptive Director | Guards adapt to repeated hiding spots. |

## 15. Out of scope for the slice
Towns 2–4, full ending branches, multiplayer, ads/monetization.
