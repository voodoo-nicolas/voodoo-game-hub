# Evolution (game notes)

Endless pond, landscape, missions + evolution tree. Files in `scripts/games/evolution/`: `evolution_engine.gd` (rules, TUNING), `evolution_data.gd` (species, tree, abilities), `evolution_art.gd` (all drawing), `evolution_controls.gd` (stick + ability buttons, Last Shift layout), `evolution_screens.gd` (creature + tree screens), `evolution_game.gd` (HUD, vision overlay shader). Test: `tools/test_evolution.gd`.

- World: `y = 0` is the water surface (the only wall); sides and depth are endless. Spawns come in a ring just outside the player's view and recycle behind.
- Progression: blind blob (jolts) -> mission "eat 1" gives a tail -> "eat 10" gives an eye (bars + hunters start) -> missions alternate size / DNA; an eat-and-grow mission always exists.
- Blue power bar: actives (`Data.ABILITIES`) spend it, it refills slowly; `"<id>2"` tree nodes upgrade an active (cheaper, longer).
- Vision rings = `Data.SIGHT_FRAC` of screen height; blur by lens nodes (`Data.BLUR`).

## Built from the owner's 2026-10-20 trait list
Movement: tail ranks, fins, streamlined, flagella, cilia. Senses: eyes (view rank), lens (blur), chemical, listening, threat radar. Defense: nutrient store, tough membrane, regeneration, spikes, warning colors, poison skin, toxin resistance; actives ink cloud, camouflage, spine burst. Offense: jump boost, jaws, acid spit, lure, electric shock.

## NOT built yet (owner's list)
Harpoon (venom); tentacle secondary tree (stinger, suction feed, grab); decoy clone; drop-a-limb escape; shell/scales evolution; slime; cold/heat/radiation/pressure tolerance (need depth zones); swim bladder (depth control), sucker, burrowing, wings/gliding; sonar, real eyes, night vision, electroreception, heat sense, depth/pressure sense, magnetic sense, UV/polarized vision.
