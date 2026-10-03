extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "word_hunt"
const TITLE := "Word Hunt"
const GOAL := "Find as many words as you can in the letter grid before the 3 minutes run out."
const HOW := [
	"Drag across touching letters to make a word. Diagonals count.",
	"Each letter can be used only once in a word.",
	"Words need at least 3 letters. They're checked against an English dictionary.",
	"3–4 letters score 1 point, 5 letters 2, 6 letters 3, 7 letters 5, and 8 or more 11.",
	"When time's up you'll see how many words were hiding in the grid. Tap Show missed words, then any word, to see its path on the board.",
	"⏸ pauses the clock. A round is only 3 minutes, so it isn't saved for later.",
]
const TIPS := [
	"Once you find a word, try adding S, ED or ER to the end.",
	"Hunt around the vowels — most words go through them.",
	"Long words are worth far more than short ones.",
]
const STATS := ["Best score", "Most words found", "Rounds played"]
