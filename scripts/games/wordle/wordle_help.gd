extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "wordle"
const TITLE := "Wordle"
const GOAL := "Guess the hidden five-letter word in six tries."
const HOW := [
	"Type a five-letter word on the keyboard and tap Enter.",
	"🟩 Green means the letter is in the word, in that spot.",
	"🟨 Yellow means the letter is in the word, but in a different spot.",
	"⬜ Grey means the letter isn't in the word at all.",
	"The keyboard shows what you've learned about each letter.",
]
const TIPS := [
	"Start with a word full of common letters, like CRANE, SLATE or AUDIO.",
	"Use your second guess to try five new letters.",
	"Remember that letters can appear twice.",
]
const STATS := ["Wins", "Losses", "Best streak", "Fewest guesses"]
