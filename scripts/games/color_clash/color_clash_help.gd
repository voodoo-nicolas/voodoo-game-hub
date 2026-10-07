extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "color_clash"
const TITLE := "Color Clash"
const GOAL := "Say whether each color word matches its ink, as fast as you can."
const HOW := [
	"A color name appears, printed in a color: for example the word RED written in blue ink.",
	"Tap ✔ Match if the word names the color it is printed in, or ✖ No match if it doesn't.",
	"Every right answer scores a point. A wrong answer breaks your streak and costs 2 seconds.",
	"You have 45 seconds.",
	"⏸ pauses the clock. A round is only a minute, so it isn't saved for later.",
]
const TIPS := [
	"Ignore what the word says and look only at the ink, then compare in your head.",
	"Your brain reads before it sees color; that clash is what makes this a real attention workout.",
]
const STATS := ["Best score", "Best streak", "Games played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🎨", "title": "Sharp Eyes", "key": "Best score", "at": 15},
	{"id": "goal2", "icon": "🌈", "title": "Color Sense", "key": "Best score", "at": 30},
	{"id": "goal3", "icon": "🧠", "title": "Unfoolable", "key": "Best score", "at": 50},
]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Naming the ink colour of a word that spells a different colour is slow: it's the Stroop effect, described in 1935.",
]
