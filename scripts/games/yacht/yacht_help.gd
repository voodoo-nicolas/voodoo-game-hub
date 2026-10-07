extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "yacht"
const TITLE := "Yacht Dice"
const GOAL := "Score as many points as you can by filling all 13 boxes."
const HOW := [
	"Each turn, roll the five dice up to three times. Tap dice to hold them between rolls.",
	"Then pick a box to score your dice in. Each box can be used only once, even if it scores 0.",
	"Ones to Sixes: the total of that number. 3 and 4 of a Kind and Chance: the total of all dice.",
	"Full House is 25, Small Straight (4 in a row) is 30, Large Straight (5 in a row) is 40, and Yacht (five of a kind) is 50.",
	"63 or more in Ones to Sixes earns a 35-point bonus. Every extra Yacht after the first is worth 100.",
	"2 to 4 players can share one phone: each has their own score card and you take turns, passing the phone. Highest total wins.",
	"⏸ pauses and keeps the score card; Resume on the Home screen carries on.",
]
const TIPS := [
	"Aim for three of each number in the upper section — that's exactly 63 and the bonus.",
	"Keep Chance for a bad turn.",
	"If a turn goes badly, put a 0 in a box you're unlikely to fill anyway, like Yacht or Ones.",
]
const STATS := ["Best score", "Games played", "Multiplayer games"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🎲", "title": "Roller", "key": "Best score", "at": 150},
	{"id": "goal2", "icon": "🎯", "title": "High Roller", "key": "Best score", "at": 200},
	{"id": "goal3", "icon": "⛵", "title": "Yacht Captain", "key": "Best score", "at": 250},
]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"The chance of five of a kind in one roll of five dice is 1 in 1,296.",
	"With three rolls, keeping the matching dice, you get five of a kind about 4.6% of the time.",
]
