extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "anagrams"
const TITLE := "Anagrams"
const GOAL := "Unscramble the letters into a word — ten words per round."
const HOW := [
	"Tap the letters in order to spell your answer. Clear starts the word again.",
	"Any real word that uses every letter counts, not just the one we picked.",
	"A right answer scores 10 points per letter.",
	"💡 Hint reveals the next letter but halves the points for that word. Skip moves on with no points.",
	"🔀 Shuffle mixes the letters up again — a fresh order often shows you the word.",
	"⏸ pauses; a round in progress is kept, and Resume on the Home screen carries on.",
]
const TIPS := [
	"Look for common endings first: -ING, -ED, -ER, -LY, -TION.",
	"Put the vowels between the consonants and try it out loud.",
	"Long words are worth the most, so a single hint on one is often still a good deal.",
]
const STATS := ["Best score", "Rounds played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🔤", "title": "Word Juggler", "key": "Best score", "at": 50},
	{"id": "goal2", "icon": "📚", "title": "Letter Wizard", "key": "Best score", "at": 150},
	{"id": "goal3", "icon": "🧙", "title": "Anagram Master", "key": "Best score", "at": 300},
]
