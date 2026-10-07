extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "trivia_battle"
const TITLE := "Trivia Battle"
const GOAL := "Answer first. The player with the most points after 10 questions wins."
const HOW := [
	"Two to four players sit around one phone. Each has their own panel with four possible answers, turned to face them.",
	"Everyone sees the same question in the middle. The first player to tap the right answer scores 1 point and the round ends.",
	"A wrong tap locks you out of that question. If everyone is wrong, or the 15 seconds run out, nobody scores and the answer is shown.",
	"On the Landing, Topic picks Science, Nature & Animals, History, Geography, Arts & Culture, Sports & Games, or all of them mixed. Questions come in your app's language (English or Spanish).",
	"Everyone can tap at the same time. A match is short, so there is nothing to resume: leaving the game ends it.",
]
const TIPS := [
	"Read the answers while the question is still being read: they often give it away.",
	"Don't tap a guess unless you must. A wrong tap costs you the whole question.",
	"Pick the topic you know best against friends who know it least!",
]
const STATS := ["Matches played", "Questions won"]

const ACHIEVEMENTS := [
	{"id": "won1", "icon": "🥊", "title": "Quick Thinker", "desc": "Win 25 questions", "key": "Questions won", "at": 25},
	{"id": "won2", "icon": "🧠", "title": "Know-It-All", "desc": "Win 100 questions", "key": "Questions won", "at": 100},
	{"id": "match1", "icon": "🏆", "title": "Quiz Night", "desc": "Play 10 matches", "key": "Matches played", "at": 10},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Octopuses have three hearts and blue blood.",
	"The Great Wall of China is made up of many walls built over centuries, not one single wall.",
]
