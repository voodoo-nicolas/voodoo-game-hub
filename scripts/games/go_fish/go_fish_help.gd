extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "go_fish"
const TITLE := "Go Fish"
const GOAL := "Collect the most books — sets of all four cards of one rank. Play the computer or a friend."
const HOW := [
	"On your turn, tap one of your cards to ask the computer for that rank.",
	"If it has any, it hands them all over and you ask again.",
	"If not, \"go fish\": you draw a card. If it's the rank you asked for, you go again.",
	"Four of a kind make a book. When all 13 books are made, the most books wins.",
	"2 Players: pass the phone. A cover screen hides the hands whenever it changes hands — tap I'm ready only when it's your turn.",
	"⏸ pauses and keeps the game; Resume on the Home screen carries on.",
]
const TIPS := [
	"Ask for ranks the computer asked you for earlier — it probably still has them.",
	"Ask for the rank you hold the most of: you're closest to a book.",
	"Remember what you've handed over, so you know which ranks the computer is collecting.",
]
const STATS := ["Wins", "Losses", "Best streak", "2-player games"]
