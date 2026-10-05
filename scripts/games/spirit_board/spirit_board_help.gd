extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "spirit_board"
const TITLE := "Spirit Board"
const GOAL := "Talk to the spirits through the board — and always say goodbye."
const HOW := [
	"Ask the spirits: type a question (or just say it out loud) and tap Ask. The planchette glides by itself and spells the reply.",
	"Yes-or-no questions get YES or NO. Ask its name, how many, what year, when, where, who or why, and it spells an answer.",
	"Séance: everyone puts one finger on the planchette and moves it together. Rest its window on a letter for a moment to write it down.",
	"The letters it lands on appear above the board. 🧹 Clear the board starts a new message.",
	"Moving to GOODBYE (or asking \"goodbye\") sends the spirit away. Ask again to call another.",
	"⏸ pauses. There's nothing to save: every séance is fresh.",
]
const TIPS := [
	"Dim the lights and play it in a group — it's spookier.",
	"Ask the spirit its name first.",
	"It's a game: the replies are random. Don't take them seriously!",
]
const STATS := ["Questions asked", "Letters spelled"]
