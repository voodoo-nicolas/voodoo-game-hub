extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Matches the vertical slice: Halcyon Cove, the marsh, the Sea Caves, two bosses.

const ID := "hesperia"
const TITLE := "Hesperia"
const GOAL := "Drive the raiders out of Halcyon Cove and free the sea caves from the Hydra."
const HOW := [
	"Move with the stick. A swings the gaff, or talks / opens when something is in front of you.",
	"Hold B to raise the wicker shield: it blocks hits from the front.",
	"X and Y use the items you equip in the menu (torch, fire rod, honey).",
	"The menu button opens items, quests, saving and options.",
	"Shelled foes block the front: hit them from the side or behind.",
]
const TIPS := [
	"The Stone-Back Crab stuns itself when it charges into a wall.",
	"Cut a Hydra head, then burn the stump before it grows back.",
	"Your game saves at the inn, from the menu, and when you leave.",
]
const STATS := ["Bosses beaten", "Games played"]
