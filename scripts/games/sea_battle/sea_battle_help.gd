extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "sea_battle"
const TITLE := "Sea Battle"
const GOAL := "Sink the computer's whole fleet before it sinks yours."
const HOW := [
	"Both fleets have five ships: 5, 4, 3, 3 and 2 squares long. Ships never touch, not even at the corners.",
	"Tap 🔀 Shuffle to rearrange your ships before the first shot.",
	"Tap a square in the enemy waters to fire. A hit, or sinking a ship, lets you fire again.",
	"The first to sink every enemy ship wins.",
	"⏸ pauses and keeps the battle; Resume on the Home screen carries on.",
]
const TIPS := [
	"Fire in a checkerboard pattern — every ship covers at least two squares, so you can't miss one.",
	"After a hit, try the squares above, below, left and right to find which way the ship runs.",
	"Once a ship is sunk, skip the squares around it — ships never touch.",
]
const STATS := ["Wins", "Losses", "Best streak"]
