extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "word_chain"
const TITLE := "Word Chain"
const GOAL := "Say a word that starts with the last letter of the previous word. Be the last one with an answer."
const HOW := [
	"The chain starts with a letter. Type a word of at least 3 letters that begins with it and tap ✔ Enter.",
	"Your word's last letter is the next player's first letter. A word can't be used twice, and it must be in the word list.",
	"You have a time limit for each word (40, 30 or 20 seconds on Easy, Normal and Hard). Run out of time, or give up, and you lose.",
	"Against the computer: Easy only knows everyday words, Normal adds a random part of the dictionary, Hard knows every word and likes to end on awkward letters. It can still run dry on a long chain.",
	"2 Players: pass the phone back and forth; there is no secret to hide, so the words stay on the screen.",
	"English words only. A game in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"End your word on a hard letter like X, Z, Q or J, so the next player has few answers.",
	"Save short, easy words for later: when the chain gets long you'll be glad to have them.",
	"Start typing early: you only need to type the letters after the first one, and the clock keeps running.",
]
const STATS := ["Wins", "Longest chain", "Words played", "Two-player games"]

const ACHIEVEMENTS := [
	{"id": "chain1", "icon": "🔗", "title": "First Link", "desc": "Build a chain of 10 words", "key": "Longest chain", "at": 10},
	{"id": "chain2", "icon": "⛓️", "title": "Strong Chain", "desc": "Build a chain of 30 words", "key": "Longest chain", "at": 30},
	{"id": "chain3", "icon": "🌐", "title": "Endless Chain", "desc": "Build a chain of 60 words", "key": "Longest chain", "at": 60},
	{"id": "words1", "icon": "📚", "title": "Wordsmith", "desc": "Play 100 words", "key": "Words played", "at": 100},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Japan has a word chain game called shiritori, where each word must start with the last sound of the one before.",
]
