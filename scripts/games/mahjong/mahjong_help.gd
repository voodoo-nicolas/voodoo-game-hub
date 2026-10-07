extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "mahjong"
const TITLE := "Mahjong Solitaire"
const GOAL := "Clear every tile from the table by taking matching pairs."
const HOW := [
	"Tap two free tiles with the same picture to take them away.",
	"A tile is free when no tile lies on top of it and its left or right side is open. Free tiles are bright; blocked ones are dim.",
	"Every deal can be cleared — but the order matters.",
	"↶ Undo takes back your last pair. 💡 Hint shows a pair you can take. 🔀 Shuffle deals the remaining pictures again when you're stuck.",
	"Easy has two layers, Normal a pyramid of four, Hard a fortress with wings and towers.",
	"⏸ pauses the clock and keeps the table; Resume on the Home screen carries on.",
]
const TIPS := [
	"Free the tall stacks and the long rows first — tiles at the ends of rows unlock the most.",
	"When all four of a picture are free, take them all: they can't block each other later.",
	"If two pairs match the same picture, take the one that frees more tiles.",
]
const STATS := ["Games solved", "Solved without help", "Best time (Easy)", "Best time (Normal)", "Best time (Hard)"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"This solitaire uses the tiles of mahjong, a four-player game from China — but it's a matching puzzle, not the original game.",
]
