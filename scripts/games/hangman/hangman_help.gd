extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "hangman"
const TITLE := "Hangman"
const GOAL := "Guess the hidden word one letter at a time before you run out of guesses."
const HOW := [
	"The topic is shown above the word, and each blank is one letter.",
	"Tap a letter to guess it. Right letters fill in every place they appear.",
	"Each wrong letter adds to the drawing. Six wrong guesses and the game is over.",
	"Two players: one types a secret word with the letter keys and locks it, then hands the phone over to guess.",
	"⏸ pauses and keeps the word; Resume on the Home screen carries on.",
]
const TIPS := [
	"Start with common vowels like E, A and O, then common consonants like R, S, T and N.",
	"Use the topic to think of words that fit the length.",
	"Once a few letters are in, look at the pattern and think of whole words.",
]
const STATS := ["Wins", "Losses", "Best streak", "Words guessed (2 players)", "Words kept (2 players)"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"E is the most common letter in English, and in Spanish too, with A close behind.",
]
