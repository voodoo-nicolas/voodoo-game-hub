extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "charades"
const TITLE := "Charades"
const GOAL := "Guess as many words as you can in 60 seconds — with the phone on your forehead."
const HOW := [
	"Pick a category, then hold the phone sideways against your forehead, screen facing your friends.",
	"After the 3-2-1 countdown a word appears. Your friends act it out or describe it — without saying it!",
	"Guessed it? Tilt the phone down. Want to pass? Tilt it up. The screen flashes green or orange.",
	"No tilt sensor, or it feels backwards? Tap the right half of the screen for ✓ and the left half to pass — or swap the tilt on the category screen.",
	"When time's up you'll see every word and how many you got. Pass the phone to the next player!",
]
const TIPS := [
	"Friends: act it out for actions and animals, describe it for jobs and things.",
	"Don't waste time on a tough word — pass and come back to it next round.",
	"Play in teams and add up each team's rounds.",
]
const STATS := ["Rounds played", "Words guessed", "Most words in a round"]
