extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "backgammon"
const TITLE := "Backgammon"
const GOAL := "Move all 15 of your white checkers into your home board and bear them off before the computer does."
const HOW := [
	"Tap 🎲 Roll, then tap a checker and a highlighted point to move it by one of the dice. Doubles let you move four times.",
	"Your checkers travel up the left side, across the top and down the right side into your home board (bottom right).",
	"You can't land on a point with two or more enemy checkers. Land on a single one (a blot) to hit it and send it to the bar.",
	"A checker on the bar must come back in before you move anything else.",
	"Once all your checkers are home, bear them off into the tray below. If the loser hasn't borne off any, it's a gammon (2×); with a checker still in the winner's home or on the bar, a backgammon (3×).",
	"You must use both dice if you can. ↶ Undo takes back moves this turn.",
]
const TIPS := [
	"Don't leave single checkers where the computer can hit them — stack them in pairs.",
	"Build points (two or more checkers) in a row to block the enemy's path.",
	"Hitting a blot costs your opponent a lot of ground — take the chance when it's safe.",
	"When you're far ahead, just race home.",
]
const STATS := ["Wins", "Losses", "Gammons won", "Best streak"]
