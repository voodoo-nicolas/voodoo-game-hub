extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "code_breaker"
const TITLE := "Code Breaker"
const GOAL := "Work out the secret code of 4 colours in 10 tries or fewer."
const HOW := [
	"Tap colours to fill the four slots, then tap Check. Colours can repeat.",
	"● means a peg is the right colour in the right spot.",
	"○ means a peg is the right colour but in the wrong spot.",
	"The markers don't tell you which peg they belong to — that's the puzzle.",
	"Two players: the code master secretly picks the code and locks it, then hands the phone to the code breaker.",
	"⏸ pauses and keeps the game; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Start with guesses like two colours in pairs (red, red, blue, blue) to find which colours are in the code.",
	"Change one thing at a time so you know what made the difference.",
	"Every guess should fit everything you've learned so far.",
]
const STATS := ["Wins", "Losses", "Fewest tries", "Best streak", "Codes cracked (2 players)", "Codes kept (2 players)"]
