extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "color_clash"
const TITLE := "Color Clash"
const GOAL := "Say whether each color word matches its ink, as fast as you can."
const HOW := [
	"A color name appears, printed in a color: for example the word RED written in blue ink.",
	"Tap ✔ Match if the word names the color it is printed in, or ✖ No match if it doesn't.",
	"Every right answer scores a point. A wrong answer breaks your streak and costs 2 seconds.",
	"You have 45 seconds.",
]
const TIPS := [
	"Ignore what the word says and look only at the ink, then compare in your head.",
	"Your brain reads before it sees color; that clash is what makes this a real attention workout.",
]
const STATS := ["Best score", "Best streak", "Games played"]
