extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "hangman"
const TITLE := "Hangman"
const GOAL := "Guess the hidden word one letter at a time before you run out of guesses."
const HOW := [
	"The topic is shown above the word, and each blank is one letter.",
	"Tap a letter to guess it. Right letters fill in every place they appear.",
	"Each wrong letter adds to the drawing. Six wrong guesses and the game is over.",
]
const TIPS := [
	"Start with common vowels like E, A and O, then common consonants like R, S, T and N.",
	"Use the topic to think of words that fit the length.",
	"Once a few letters are in, look at the pattern and think of whole words.",
]
const STATS := ["Wins", "Losses", "Best streak"]
