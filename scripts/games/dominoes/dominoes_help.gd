extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "dominoes"
const TITLE := "Dominoes"
const GOAL := "Be the first to score 100 points by emptying your hand before the computers do."
const HOW := [
	"A double-six set: you get 7 tiles against one computer, 5 against two or three. The rest are the boneyard.",
	"The highest double starts the line. Then each turn, play one tile that matches an open end of the line.",
	"Tap a glowing tile to play it. If it fits both ends, tap the glowing end you want.",
	"No tile fits? Draw from the boneyard until one does. If the boneyard is empty, pass.",
	"Empty your hand to win the round and score every pip left in the other hands.",
	"If nobody can play, the round is blocked: the lightest hand wins the others' pips minus its own.",
	"The first to 100 points wins the game.",
	"⏸ pauses and keeps the game; Resume on the Home screen carries on.",
]
const TIPS := [
	"Play your heavy tiles early: if someone else goes out, they count against you.",
	"Keep a variety of numbers in your hand so you can always match an end.",
	"Watch which numbers the computers can't match — they drew when that number was open.",
]
const STATS := ["Wins", "Losses", "Best streak", "Rounds won"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"A double-six set has 28 tiles: every pair of numbers from 0 to 6 appears exactly once.",
]
