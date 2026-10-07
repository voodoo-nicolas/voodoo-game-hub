extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "emoji_guess"
const TITLE := "Emoji Guess"
const GOAL := "Work out the word or phrase the emoji spell, and type it in."
const HOW := [
	"Each puzzle shows some emoji and a hint about the kind of answer. The slots show how many letters each word has.",
	"Type the answer on the keyboard. Capitals, accents and spaces don't matter, and it is accepted as soon as it is right.",
	"A puzzle is worth 100 points. Each 💡 Hint types the next letter for you and costs 30 points (never less than 10). Skip shows the answer and moves on.",
	"Easy has simple words, Normal two-word phrases, Hard sayings and idioms. A round is 8 puzzles, in your app's language (English or Spanish).",
	"With 2 to 4 players, pass the phone: you take turns, one puzzle each, and the highest score wins.",
	"A round in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Say each emoji out loud: the answer is often the sounds put together, like a compound word.",
	"Use the hint about the answer: a food, an animal, a saying. It rules out most of the guesses.",
	"Stuck? Count the letters of each word in the slots and think of phrases with that shape.",
]
const STATS := ["Best score", "Best score (Easy)", "Best score (Normal)", "Best score (Hard)", "Puzzles solved", "Solved without hints", "Rounds played"]

const ACHIEVEMENTS := [
	{"id": "solved1", "icon": "🤔", "title": "Decoder", "desc": "Solve 10 puzzles", "key": "Puzzles solved", "at": 10},
	{"id": "solved2", "icon": "😎", "title": "Emoji Expert", "desc": "Solve 50 puzzles", "key": "Puzzles solved", "at": 50},
	{"id": "solved3", "icon": "🧠", "title": "Picture Perfect", "desc": "Solve 150 puzzles", "key": "Puzzles solved", "at": 150},
	{"id": "clean1", "icon": "💡", "title": "No Clues Needed", "desc": "Solve 25 puzzles without a hint", "key": "Solved without hints", "at": 25},
	{"id": "score1", "icon": "🏆", "title": "Full Marks", "desc": "Score 700 in a solo round", "key": "Best score", "at": 700},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"The first emoji set was drawn in 1999 by Shigetaka Kurita for a Japanese mobile phone service.",
	"The word 'emoji' comes from Japanese: 'e' means picture and 'moji' means character.",
]
