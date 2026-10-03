extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "ride_the_bus"
const TITLE := "Ride the Bus"
const GOAL := "Guess well, get rid of your cards in the pyramid — and don't be the one who rides the bus!"
const HOW := [
	"Choose how many players (2–10) and pass the phone around.",
	"Part 1 — four rounds, each player once per round: red or black? Higher or lower than your first card? Inside or outside your first two? Then guess the suit. Every card you're dealt goes into your hand.",
	"A wrong guess drinks: 1 in round one, 2 in round two, 3 in round three and 4 in round four. (Higher/lower ties count as wrong; inside/outside ties count as outside.)",
	"Part 2 — the pyramid: ten cards in rows of 4, 3, 2 and 1. Flip them one at a time. Anyone holding the same rank gives out drinks — 1 for the bottom row up to 4 at the top — and lays that card down.",
	"Part 3 — whoever has the most cards left rides the bus: the four guesses again with fresh cards, in a row. Any wrong guess drinks and starts over, until all four are right.",
	"⏸ pauses. A game is played at the table, so it isn't saved for later.",
]
const TIPS := [
	"Any drink works — water and soda count too. Know your limits and play responsibly.",
	"Higher or lower: go higher when your first card is low and lower when it's high.",
	"Inside or outside: the wider the gap between your first two cards, the better inside looks.",
]
const STATS := ["Games played", "Bus rides", "Longest bus ride (tries)"]
