extends RefCounted

## Ink Ninja's story line: one chapter card before each stage (title + 2 lines)
## and the stage's story objective shown in the HUD. Bosses follow the engine's
## BOSS_NAMES rotation: stage 1 Iron Monk, 2 Twin Blade, 3 Paper Crane, 4 Shadow
## Daimyo, 5 Iron Monk... so the story treats stages 1-9 as his guards and
## stage 10 as the last duel. Translated through the game's tr().

const PROLOGUE := "The Great Brush painted the world. The Shadow Daimyo stole it, and the colours ran out of everything. Only ink is left."

## [chapter title, text, objective]
const CHAPTERS := [
	["The Empty Temple", "Sumi, the last student of the Ink Temple, finds her master's scroll: \"Follow the black road to the mountain.\"", "Reach the temple gate"],
	["Bamboo Road", "The Daimyo's ninjas guard the road. Their leader carries two swords and never sleeps.", "Get through the bamboo forest"],
	["River of Paper", "A folded crane drifts over the river. It was once a messenger; now it spits steel.", "Cross the river"],
	["The First Shadow", "In a burnt village, the Daimyo himself waits. It is only his shadow, but it bites.", "Drive off the Daimyo's shadow"],
	["Monks of Iron", "The mountain monastery has closed its gates to the world. Its monks now serve the Daimyo.", "Climb to the monastery"],
	["Cliffs of Mist", "The mist hides the edge of every cliff. The Twin Blade has come back to finish what he started.", "Find a path along the cliffs"],
	["The Silent Garden", "Not a sound in the garden. The crane is waiting among the stones, sharper than before.", "Pass through the garden"],
	["Ash Fields", "Fields painted grey to the horizon. Sumi's own footprints are the only marks left.", "Cross the ash fields"],
	["The Inner Wall", "The castle wall. The Iron Monk guards the last door with the strength of three men.", "Break through the inner wall"],
	["The Daimyo", "The throne room. The Great Brush hangs on the wall behind him. One duel to bring the world its colours back.", "Defeat the Shadow Daimyo"],
]

const EPILOGUE := "Sumi lifts the Great Brush. One stroke, and the world remembers its colours. She paints herself in black, and walks home."
