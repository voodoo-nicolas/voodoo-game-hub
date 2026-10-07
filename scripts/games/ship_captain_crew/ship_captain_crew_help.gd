extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "ship_captain_crew"
const TITLE := "Ship, Captain, Crew"
const GOAL := "Find a 6 (ship), a 5 (captain) and a 4 (crew) in order, then bring home the biggest cargo."
const HOW := [
	"On your turn you have three rolls of five dice. Tap Roll to throw them.",
	"First you need a 6: the ship. Once you have it, you need a 5: the captain. Then a 4: the crew. They are set aside as you find them, and they must come in that order, though one roll can find more than one.",
	"Once the crew is aboard, the two other dice are your cargo, and their total is your score for the turn. With rolls left, tap a cargo die to keep it, and Roll to throw the others again for a bigger haul.",
	"✔ Done banks the cargo and passes the dice. If you run out of rolls with no crew, you score 0.",
	"Five rounds. Highest total wins, against the computer (Easy stops early, Hard pushes for more cargo) or with 2 to 4 players passing the phone.",
	"A game in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Keep any cargo die that is a 5 or a 6, and roll the small ones again.",
	"With only one roll left, a 3 or less is worth rolling again: the average die is 3.5.",
	"Finding the crew on your first roll is rare, so don't worry about the early rolls: it's all about finishing the job.",
]
const STATS := ["Wins", "Best turn", "Crews found", "Two-player games"]

const ACHIEVEMENTS := [
	{"id": "cargo1", "icon": "⛵", "title": "Full Hold", "desc": "Bank a cargo of 10 or more", "key": "Best turn", "at": 10},
	{"id": "cargo2", "icon": "💰", "title": "Treasure Fleet", "desc": "Bank the biggest cargo of all: 12", "key": "Best turn", "at": 12},
	{"id": "crew1", "icon": "⚓", "title": "All Hands", "desc": "Find the crew 25 times", "key": "Crews found", "at": 25},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Two dice add up to 7 more often than to any other total: 6 ways out of 36.",
]
