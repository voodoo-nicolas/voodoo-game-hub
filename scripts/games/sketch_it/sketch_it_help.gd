extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "sketch_it"
const TITLE := "Sketch It"
const GOAL := "Draw the secret word so your team can guess it. The first team to 5 points wins."
const HOW := [
	"Split into 2, 3 or 4 teams and share one phone. Teams take turns.",
	"Each turn, one player from the team is the artist. Tap \"I'm the artist\" to see the secret word — nobody else looks!",
	"You may swap the word once. Then tap Start drawing: the clock starts.",
	"Draw on the canvas while your team shouts out guesses. No letters, numbers or talking!",
	"Pick colours and a thin or thick pen; ↶ undoes a line and 🗑 clears the canvas. Hold 👁 Word to check the word.",
	"Guessed? Tap ✔ Guessed it! for a point. Tap ✖ Give up or run out of time and the turn passes.",
	"On the Home screen, choose easy, hard or mixed words and 45, 60 or 90 seconds to draw.",
	"⏸ pauses the clock. Resume on the Home screen keeps the scores; an unfinished drawing starts over.",
]
const TIPS := [
	"Start with the big shape, then add the one detail that gives it away.",
	"Draw an arrow to point at the part that matters.",
	"Acting out is not allowed — but nodding when they get close is fair.",
]
const STATS := ["Drawings guessed", "Fastest guess time", "Games played"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Artists often start with simple shapes — circles, boxes, lines — and add the details last.",
]
