extends RefCounted

## Hesperia's pure logic lives in core/ (generated from the standalone project by its tools/port_to_hub.py):
## quest_engine.gd, hydra_engine.gd, cond.gd, combat.gd, tokens.gd, save_engine.gd. Headless test:
## tools/test_hesperia.gd. This file only gathers them so the hub's "<id>_engine.gd" convention holds.

const QuestEngine = preload("res://scripts/games/hesperia/core/quest_engine.gd")
const HydraEngine = preload("res://scripts/games/hesperia/core/hydra_engine.gd")
const Cond = preload("res://scripts/games/hesperia/core/cond.gd")
const Combat = preload("res://scripts/games/hesperia/core/combat.gd")
const Tokens = preload("res://scripts/games/hesperia/core/tokens.gd")
const SaveEngine = preload("res://scripts/games/hesperia/core/save_engine.gd")
