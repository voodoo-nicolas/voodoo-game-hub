extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "pig"
const TITLE := "Pig"
const GOAL := "Be the first to bank 100 points (or 50) by rolling the die, without rolling a 1."
const HOW := [
	"On your turn, roll the die as many times as you like. Each roll adds to your turn total.",
	"✋ Hold banks the turn total into your score and passes the die. But roll a 1 and you lose the turn total and your turn is over.",
	"Big Pig (Dice → Two dice) uses two dice: any other roll adds both dice, a single 1 ends the turn, and rolling two 1s (snake eyes) wipes your whole banked score.",
	"First to the goal wins. Against the computer, Easy holds early, Normal holds at about 20, and Hard plays the score: it takes risks when you are close to winning.",
	"With 2 to 4 players, pass the phone: the scoreboard shows whose turn it is.",
	"A game in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Holding at about 20 is a strong rule of thumb: past 20, the one-in-six chance of losing it all outweighs the average gain of another roll.",
	"If someone is close to winning, take more risks: holding doesn't help if they win next turn.",
	"When you are well ahead, bank sooner. You don't need big turns, just safe ones.",
]
const STATS := ["Wins", "Biggest turn", "Pig outs", "Two-player games"]

const ACHIEVEMENTS := [
	{"id": "turn1", "icon": "🐷", "title": "Pushing Luck", "desc": "Bank 20 or more in one turn", "key": "Biggest turn", "at": 20},
	{"id": "turn2", "icon": "🔥", "title": "On a Roll", "desc": "Bank 40 or more in one turn", "key": "Biggest turn", "at": 40},
	{"id": "turn3", "icon": "💎", "title": "Hog Wild", "desc": "Bank 60 or more in one turn", "key": "Biggest turn", "at": 60},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Pig is a solved game: mathematicians worked out the best possible strategy, and it is a little more subtle than 'hold at 20'.",
	"With one die, holding at 20 is a good rule because the expected gain of rolling once more stops being positive around a turn total of 20.",
]
