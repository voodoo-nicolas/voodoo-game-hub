# Evolution (game notes)

Endless pond, landscape, missions + evolution tree. Files in `scripts/games/evolution/`: `evolution_engine.gd` (rules, TUNING), `evolution_data.gd` (species, tree, abilities), `evolution_art.gd` (all drawing), `evolution_controls.gd` (stick + ability buttons, Last Shift layout), `evolution_screens.gd` (creature + tree screens), `evolution_game.gd` (HUD, vision overlay shader). Test: `tools/test_evolution.gd`.

- World: `y = 0` is the water surface (the only wall); sides and depth are endless. Spawns come in a ring just outside the player's view and recycle behind.
- Progression: blind blob (jolts) -> mission "eat 1" gives a tail -> "eat 10" gives an eye (bars + hunters start) -> missions alternate size / DNA; an eat-and-grow mission always exists.
- Blue power bar: actives (`Data.ABILITIES`) spend it, it refills slowly. More points in an active make it cheaper, longer, stronger.
- Evolution tree = a graph (`Data.NODES`): creature at far left, 4 branches (Offense, Senses, Movement, Defense; Tentacles sit inside Offense behind the "Tentacles" node). Each node has `max` points, several `req` prerequisites, and can open several nodes. Locked nodes show "?". Screen: `evolution_tree_view.gd` (drag to pan, tap to select).
- Ability buttons (right thumb, max 4, none at the start): 1 = offensive, 2 = defensive (auto-assigned, the player picks which on the creature screen), 3 and 4 arrive at growth stages Hunter / Predator and take either kind. Rules in the engine: `slot_visible`, `eligible`, `auto_assign`, `cycle_slot`, `use_slot`.
- Vision rings = `Data.SIGHT_FRAC` of screen height; blur by lens points (`Data.BLUR`).

## Built from the owner's 2026-10-20 trait list
Movement: tail, fins, streamlined, flagella, cilia. Senses: second eye, wide eyes, lens, real eyes, night vision, chemical, listening, threat radar, sonar. Defense: nutrient store, tough membrane, shell, regeneration, spikes, warning colors, poison skin, slime, toxin resistance; actives ink cloud, camouflage, spine burst, decoy clone, drop a limb. Offense: jump boost, strong jaws, acid spit, harpoon, lure, electric shock; tentacles: stinger, suction feed, grab.

## NOT built yet (owner's list)
Cold/heat/radiation/pressure tolerance (need depth zones); swim bladder (depth control), sucker, burrowing, wings/gliding; electroreception, heat sense, depth/pressure sense, magnetic sense, UV/polarized vision. (Sonar is built as a ping; "real eyes" as the sharpest lens.)
