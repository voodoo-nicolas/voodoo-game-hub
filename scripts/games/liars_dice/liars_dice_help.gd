extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "liars_dice"
const TITLE := "Liar's Dice"
const GOAL := "Be the last player with dice left — against two computers, or 2 to 4 friends passing the phone."
const HOW := [
	"Everyone rolls five dice in secret. You can only see your own.",
	"In turn, each player raises the bid: \"at least N dice on the whole table show face F\".",
	"A raise must be more dice, or the same number of a higher face.",
	"Instead of raising, call Liar! on the last bid. All dice are shown: if the bid was wrong, the bidder loses a die; if it was right, the caller does.",
	"Lose all your dice and you're out.",
	"Pass the phone (2-4 players): only the player whose turn it is sees their own dice; a cover screen hides the table between turns.",
	"⏸ pauses the game. A game isn't saved for later: leaving it ends it.",
]
const TIPS := [
	"On average, one in six of the other players' dice shows any given face. Add that to what you hold.",
	"Bid on faces you have plenty of — it's safer, and it makes the others doubt you.",
	"When the bid goes way past what's likely, call Liar!",
	"With fewer dice on the table, bids should drop — keep count.",
]
const STATS := ["Wins", "Losses", "Best streak", "Pass-and-play games"]
