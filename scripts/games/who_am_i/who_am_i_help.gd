extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "who_am_i"
const TITLE := "Who Am I?"
const GOAL := "Guess the secret animal, food, thing or job from five clues. The sooner you get it, the more it's worth."
const HOW := [
	"Each round hides a secret. The clues arrive one at a time, from vague to obvious, and the newest one is shown in the middle.",
	"Pick the name you think it is from the four on your panel. It is worth 5 points after the first clue, 4 after the second, and so on down to 1.",
	"One guess per round: a wrong pick locks you out until the next round. If everybody is locked out, or the clues run out, nobody scores.",
	"Alone you play 8 rounds for a score out of 40. With 2 to 4 players around one phone, each panel is turned to face its player and everyone can tap at once. Most points wins.",
	"On the Landing, Clue speed sets how long each clue stays alone: Relaxed, Normal or Fast. Secrets come in your app's language (English or Spanish).",
	"A game is short, so there is nothing to resume: leaving the game ends it.",
]
const TIPS := [
	"The first clue is deliberately vague. Guess early only when the clue really narrows it down.",
	"Look at the four names first: the kinds of things they are (all animals, say) tell you what the clues are about.",
	"Fast clues mean bigger risks and bigger rewards: a first-clue guess is worth five times the last one.",
]
const STATS := ["Best score", "Best score (Relaxed)", "Best score (Normal)", "Best score (Fast)", "Secrets guessed", "Guessed on the first clue", "Matches played"]

const ACHIEVEMENTS := [
	{"id": "guess1", "icon": "🕵️", "title": "Detective", "desc": "Guess 20 secrets", "key": "Secrets guessed", "at": 20},
	{"id": "guess2", "icon": "🔍", "title": "Sherlock", "desc": "Guess 100 secrets", "key": "Secrets guessed", "at": 100},
	{"id": "first1", "icon": "⚡", "title": "Sixth Sense", "desc": "Guess 5 secrets on the first clue", "key": "Guessed on the first clue", "at": 5},
	{"id": "score1", "icon": "🏆", "title": "Sharp Mind", "desc": "Score 30 in a solo round", "key": "Best score", "at": 30},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"An octopus has three hearts and blue blood.",
	"Bats are the only mammals that can truly fly.",
	"A rainbow is really a full circle; from the ground we only see the top half.",
]
