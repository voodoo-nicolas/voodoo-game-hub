extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "bunco"
const TITLE := "Bunco"
const GOAL := "Win the most of the six rounds by being first to 21 points, or by rolling a Bunco."
const HOW := [
	"There are six rounds, one for each number from 1 to 6. Round 1 is about 1s, round 2 about 2s, and so on.",
	"On your turn tap Roll to throw three dice. Every die showing the round's number scores 1 point (shown lit up).",
	"Three of a kind of any other number scores 5. Three of the round's number is a BUNCO: 21 points and the round is yours at once.",
	"If you score, you roll again. A roll with no points ends your turn and the dice pass to the next player.",
	"The first player to 21 points in a round wins it. After round 6, the most rounds won wins the game, and points break ties.",
	"Against the computer, or 2 to 4 players passing the phone. A game in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Bunco is a game of luck, so the best strategy is to enjoy the rolls. Cheer for your friends' misses!",
	"Rolling three of a kind of the wrong number still pays 5 points, so every triple is welcome.",
	"A Bunco is the best roll in the game: it wins the round outright, whatever the score.",
]
const STATS := ["Wins", "Buncos", "Two-player games"]

const ACHIEVEMENTS := [
	{"id": "bunco1", "icon": "🎲", "title": "Bunco!", "desc": "Roll a Bunco", "key": "Buncos", "at": 1},
	{"id": "bunco2", "icon": "🍀", "title": "Lucky Roller", "desc": "Roll 10 Buncos", "key": "Buncos", "at": 10},
	{"id": "bunco3", "icon": "👑", "title": "Bunco Baron", "desc": "Roll 25 Buncos", "key": "Buncos", "at": 25},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"The chance of rolling three of a kind on three dice is 1 in 36, so a Bunco on a given roll is a 1 in 216 event.",
]
