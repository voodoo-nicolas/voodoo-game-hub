extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "word_ladder"
const TITLE := "Word Ladder"
const GOAL := "Turn the start word into the goal word, changing one letter at a time. Every step must be a real word."
const HOW := [
	"Tap a letter of the word on the bottom rung, then pick the letter to put there. The new word becomes the next rung.",
	"Each rung changes exactly one letter, and a word can't be used twice. The changed letter is lit up on the rung.",
	"Easy uses 3-letter words, Normal 4, Hard 5. A round is five ladders.",
	"Par is the shortest ladder there is. A ladder is worth 100 points, minus 15 for every step beyond par and 25 for every hint.",
	"↩ Undo takes back the last rung. 💡 Hint plays the next word of a shortest ladder from where you are. Skip shows the shortest ladder and moves on.",
	"English words only. A round in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Work from both ends: think of words that are close to the goal word too.",
	"Vowels are the easiest letters to swap. Try them first when you're stuck.",
	"Rare words are in the list, so an odd word you know may well be accepted.",
]
const STATS := ["Best score", "Best score (Easy)", "Best score (Normal)", "Best score (Hard)", "Ladders solved", "Perfect ladders", "Rounds played"]

const ACHIEVEMENTS := [
	{"id": "ladders1", "icon": "🪜", "title": "First Rung", "desc": "Solve 1 ladder", "key": "Ladders solved", "at": 1},
	{"id": "ladders2", "icon": "🧗", "title": "Climber", "desc": "Solve 25 ladders", "key": "Ladders solved", "at": 25},
	{"id": "ladders3", "icon": "🏔️", "title": "Summit", "desc": "Solve 100 ladders", "key": "Ladders solved", "at": 100},
	{"id": "perfect1", "icon": "🎯", "title": "Shortest Way", "desc": "Solve a ladder in par steps with no hints", "key": "Perfect ladders", "at": 1},
	{"id": "perfect2", "icon": "💎", "title": "Perfectionist", "desc": "10 perfect ladders", "key": "Perfect ladders", "at": 10},
	{"id": "score1", "icon": "🏆", "title": "Word Smith", "desc": "Score 400 in a round", "key": "Best score", "at": 400},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Lewis Carroll invented word ladders in 1877 and called them 'Doublets'.",
	"COLD to WARM takes four steps: COLD, CORD, CARD, WARD, WARM.",
]
