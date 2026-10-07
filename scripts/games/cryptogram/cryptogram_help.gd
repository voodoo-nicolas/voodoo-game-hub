extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "cryptogram"
const TITLE := "Cryptogram"
const GOAL := "Decode the proverb. Every letter has been swapped for a different one."
const HOW := [
	"Each box shows a coded letter (small) and your guess for it (big). Tap a box to pick that coded letter, then tap a key to say what it stands for.",
	"The same coded letter fills in everywhere it appears. A coded letter never stands for itself, and each real letter is used for only one coded letter.",
	"The proverb is in the language of your app (English or Spanish). Spanish keeps the Ñ and drops accents.",
	"Easy is a short proverb, Normal a medium one, Hard a long one.",
	"✔ Check lights up the wrong guesses for a moment. 💡 Hint reveals the most common letter you haven't got. ⌫ Clear empties the picked letter.",
	"Your time and hints are recorded. A puzzle in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Start with one-letter words: in English they are almost always A or I.",
	"Look for short, common words like THE, AND and TO, and for double letters.",
	"The most common coded letter is often E (English). Spanish favors A and E.",
]
const STATS := ["Puzzles solved", "Best time (Easy)", "Best time (Normal)", "Best time (Hard)", "No-hint solves", "Hints used"]

const ACHIEVEMENTS := [
	{"id": "solved1", "icon": "🔐", "title": "Code Cracker", "desc": "Decode your first cryptogram", "key": "Puzzles solved", "at": 1},
	{"id": "solved2", "icon": "🕵️", "title": "Codebreaker", "desc": "Decode 25 cryptograms", "key": "Puzzles solved", "at": 25},
	{"id": "solved3", "icon": "🧠", "title": "Enigma", "desc": "Decode 100 cryptograms", "key": "Puzzles solved", "at": 100},
	{"id": "clean1", "icon": "🎯", "title": "No Peeking", "desc": "Decode a puzzle without hints", "key": "No-hint solves", "at": 1},
	{"id": "clean2", "icon": "💎", "title": "Pure Logic", "desc": "10 puzzles without hints", "key": "No-hint solves", "at": 10},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Julius Caesar protected his messages by shifting each letter a few places along the alphabet.",
	"In English, E is the most common letter, followed by T and A.",
]
