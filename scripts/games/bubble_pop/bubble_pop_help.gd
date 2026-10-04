extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "bubble_pop"
const TITLE := "Bubble Pop"
const GOAL := "Pop as many bubbles as you can before the pile reaches the line at the bottom."
const HOW := [
	"Touch and drag to aim — the dotted line shows the path — and let go to fire.",
	"Bubbles bounce off the side walls and stick to the first bubble they touch.",
	"Join three or more of the same colour to pop them: 10 points each.",
	"Bubbles left hanging from nothing fall. Falling bubbles are worth much more, and more the more fall at once.",
	"Tap the small bubble beside the shooter to swap it with the one you're holding.",
	"Every few shots without a pop, the whole ceiling drops a row. Clear the board for a 500-point bonus.",
	"Easy has 4 colours, Normal 5 and Hard 6, with the ceiling dropping sooner.",
	"⏸ pauses and keeps the game; Resume on the Home screen carries on.",
]
const TIPS := [
	"Aim for the bubbles holding up a big cluster: dropping them is worth far more than popping.",
	"Bank shots off the walls to reach bubbles hidden behind others.",
	"Keep an eye on the counter: when the ceiling is about to drop, make a pop count.",
]
const STATS := ["Best score", "Games played", "Most bubbles in one shot"]
