extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "truth_or_dare"
const TITLE := "Truth or Dare"
const GOAL := "Answer honestly or do the dare. Done cards score a point, skipped cards lose one."
const HOW := [
	"Choose how many players on the Home screen (2 to 8), then Mild or Spicy cards. Pass the phone round the circle.",
	"On your turn, tap Truth or Dare and read your card out loud.",
	"Answered the truth or did the dare? Tap ✔ Done for +1. Chickened out? ✖ Skip, −1.",
	"Then it's the next player's turn. The scores are at the top.",
	"Mild cards are fine for any group; Spicy adds cards for friends and dates. The cards follow the app's language.",
	"⏸ pauses; Resume on the Home screen keeps the scores and whose turn it is.",
]
const TIPS := [
	"The group decides whether a truth was honest enough.",
	"Dares are meant to be fun, not mean — anyone can skip, it just costs a point.",
	"Feeling brave? Pick Dare three times in a row.",
]
const STATS := ["Cards played", "Truths told", "Dares done"]
