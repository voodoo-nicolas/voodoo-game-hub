extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "digit_recall"
const TITLE := "Digit Recall"
const GOAL := "Remember longer and longer numbers."
const HOW := [
	"A number appears for a few seconds. Memorize it.",
	"When it disappears, type it back on the keypad. Use ⌫ to fix a slip before you finish.",
	"Get it right and the next number is one digit longer.",
	"Get it wrong and you lose one of your 3 lives; you then try a new number of the same length. Lose all 3 and the game ends.",
	"Your score is the length of the longest number you recalled.",
	"⏸ pauses. A game is quick, so it isn't saved for later.",
]
const TIPS := [
	"Chunk the digits into groups of two or three, like a phone number, instead of memorizing them one by one.",
	"Say the digits quietly to yourself in a steady rhythm while the number is on screen.",
]
const STATS := ["Best score", "Games played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🔢", "title": "Good Memory", "key": "Best score", "at": 6},
	{"id": "goal2", "icon": "🧠", "title": "Number Vault", "key": "Best score", "at": 8},
	{"id": "goal3", "icon": "💾", "title": "Human Hard Drive", "key": "Best score", "at": 10},
]
