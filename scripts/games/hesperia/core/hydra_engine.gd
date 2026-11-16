extends RefCounted
## Lernaean Hydra (bosses.json b01): hp 24, 2 phases, 5 heads. Sword severs a head (1 dmg) -> stump regrows
## unless burned. Fire on a stump = 4 dmg and the head is gone for good. Phase 2 at hp <= 12.
const HEADS := 5
const REGROW_P1 := 6.0
const REGROW_P2 := 3.5
const SWORD_DMG := 1
const BURN_DMG := 4

var hp: int = 24
var max_hp: int = 24
## per head: "up" | "stump" | "gone"
var heads: Array = []
var regrow: Array = []   ## seconds left per stump
var extra_heads: int = 0 ## regrown stumps in phase 2 sprout a bonus head cap

func _init(boss_hp: int = 24) -> void:
	hp = boss_hp
	max_hp = boss_hp
	for i in HEADS:
		heads.append("up")
		regrow.append(0.0)

func phase() -> int:
	return 2 if hp <= max_hp / 2 else 1

func alive() -> bool:
	return hp > 0

func heads_up() -> int:
	return heads.count("up")

func sword_hit(i: int) -> bool:
	if not alive() or heads[i] != "up":
		return false
	heads[i] = "stump"
	regrow[i] = REGROW_P2 if phase() == 2 else REGROW_P1
	hp = max(0, hp - SWORD_DMG)
	return true

func fire_hit(i: int) -> bool:
	if not alive() or heads[i] != "stump":
		return false
	heads[i] = "gone"
	hp = max(0, hp - BURN_DMG)
	return true

func tick(dt: float) -> void:
	for i in HEADS:
		if heads[i] == "stump":
			regrow[i] -= dt
			if regrow[i] <= 0.0:
				heads[i] = "up"

## True when every head is gone for good or hp is 0: boss defeated.
func defeated() -> bool:
	return hp <= 0

## Softlock guard: sword+fire on every head must be able to kill the boss (5 x (1+4) = 25 >= 24).
static func beatable(boss_hp: int = 24) -> bool:
	return HEADS * (SWORD_DMG + BURN_DMG) >= boss_hp
