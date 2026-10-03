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
	"⏸ pauses and keeps the score card; Resume on the Home screen carries on.",
]
const TIPS := [
	"Aim for three of each number in the upper section — that's exactly 63 and the bonus.",
	"Keep Chance for a bad turn.",
	"If a turn goes badly, put a 0 in a box you're unlikely to fill anyway, like Yacht or Ones.",
]
const STATS := ["Best score", "Games played"]
