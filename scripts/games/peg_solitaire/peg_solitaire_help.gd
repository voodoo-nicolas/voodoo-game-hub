extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "peg_solitaire"
const TITLE := "Peg Solitaire"
const GOAL := "Remove pegs by jumping over them until only one is left."
const HOW := [
	"Tap a peg, then tap an empty hole two spaces away to jump over the peg in between.",
	"The peg you jump over is removed. Jumps go up, down, left or right — never diagonally.",
	"The game ends when no jumps are left. One peg left is a win; one peg in the very centre is perfect.",
	"↶ Undo takes back your last jump.",
	"⏸ pauses and keeps the board; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Work from the outside in, and avoid leaving pegs stranded alone on the arms of the cross.",
	"Clear one arm of the cross at a time.",
	"Save the centre for last.",
]
const STATS := ["Games played", "Games solved", "Perfect games", "Fewest pegs left"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"On this 33-hole cross the puzzle can be solved so that the last peg ends in the centre hole.",
]
