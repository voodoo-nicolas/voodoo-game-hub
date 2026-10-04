extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "trivia"
const TITLE := "Trivia"
const GOAL := "Answer ten questions and score as many points as you can."
const HOW := [
	"Pick a topic (or Mixed for questions from all of them).",
	"Each question has four answers and you have 20 seconds. Tap the right one.",
	"A right answer scores 10 points, plus up to 5 bonus points for answering quickly. A wrong answer or running out of time scores nothing.",
	"The questions come in your app's language, English or Spanish.",
	"⏸ pauses the clock. A game is ten quick questions, so it isn't saved for later.",
]
const TIPS := [
	"Rule out the answers you know are wrong first; it is faster than hunting for the right one.",
	"Don't linger: the speed bonus shrinks every 3 seconds.",
]
const STATS := ["Best score", "Best streak", "Correct answers", "Games played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "❓", "title": "Know-It-Some", "key": "Best score", "at": 80},
	{"id": "goal2", "icon": "🎓", "title": "Scholar", "key": "Best score", "at": 120},
	{"id": "goal3", "icon": "🦉", "title": "Walking Encyclopedia", "key": "Best score", "at": 145},
]
