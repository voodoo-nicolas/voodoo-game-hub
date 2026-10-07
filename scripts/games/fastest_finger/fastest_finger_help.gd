extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "fastest_finger"
const TITLE := "Fastest Finger"
const GOAL := "Be the first to tap the right answer. First to 5 points wins the match."
const HOW := [
	"Two to four players sit around one phone. Each has their own panel, turned to face them.",
	"Reaction: every pad says WAIT. When it turns green and says TAP!, tap your pad first. Tap early and you are locked out of the round.",
	"Math: a sum shows in the middle. Tap the right answer on your own panel before anyone else. A wrong tap locks you out of that round.",
	"Odd one out: three of the four shapes match. Tap the one that is different.",
	"On the Landing, Challenge picks Reaction, Math, Odd one out, or Mixed. Everyone can tap at the same time.",
	"A match is short, so there is nothing to resume: leaving the game ends it.",
]
const TIPS := [
	"Don't tap before the pad turns green. A guess costs you the round.",
	"In Math, the wrong options are always close to the right one, so check the last digit first.",
	"The Odd one out is easiest if you look at one corner and let the others come to you.",
]
const STATS := ["Matches played", "Rounds played", "Fastest reaction (ms)"]

const ACHIEVEMENTS := [
	{"id": "fast1", "icon": "⚡", "title": "Quick Draw", "desc": "React in under 400 ms", "key": "Fastest reaction (ms)", "at": 400, "lower": true},
	{"id": "fast2", "icon": "🏎️", "title": "Lightning", "desc": "React in under 250 ms", "key": "Fastest reaction (ms)", "at": 250, "lower": true},
	{"id": "match1", "icon": "👆", "title": "Finger Fight", "desc": "Play 10 matches", "key": "Matches played", "at": 10},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"The average human reaction time to a visual signal is about a quarter of a second (250 ms).",
]
