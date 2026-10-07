extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "hex"
const TITLE := "Hex"
const GOAL := "Link your two sides of the board with an unbroken chain of your hexagons."
const HOW := [
	"Red owns the top and bottom edges and moves first. Blue owns the left and right edges.",
	"Take turns tapping an empty hexagon to claim it. Hexagons never move and are never taken.",
	"The first player whose hexagons form a chain joining their two edges wins. There are no draws in Hex: someone always gets through.",
	"Against the computer you play Red. Easy, Normal or Hard.",
	"Two players can share one phone, or tap 🌐 Online to play a friend on another phone (the host is Red).",
	"⏸ pauses and keeps the game; Resume on the Home screen carries on.",
]
const TIPS := [
	"The centre is the strongest opening — it's close to every edge.",
	"A \"bridge\" (two of your hexagons with two empty cells between them) can't be cut: if they block one, take the other.",
	"Blocking from a distance works better than blocking right next to the enemy's chain.",
]
const STATS := ["Wins", "Losses", "Best streak", "Wins (Hard)", "Red wins", "Blue wins", "Online wins"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Hex can never end in a draw: someone always connects. This is linked to a famous result in maths, the Brouwer fixed-point theorem.",
	"Hex was invented by Piet Hein in 1942 and again, on his own, by John Nash in 1948.",
]
