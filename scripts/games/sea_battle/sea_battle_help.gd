extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "sea_battle"
const TITLE := "Sea Battle"
const GOAL := "Sink the enemy's whole fleet before they sink yours — the computer's, or a friend's."
const HOW := [
	"Both fleets have five ships: 5, 4, 3, 3 and 2 squares long. Ships never touch, not even at the corners.",
	"Tap 🔀 Shuffle to rearrange your ships before your first shot.",
	"Tap a square in the enemy waters to fire. A hit, or sinking a ship, lets you fire again.",
	"The first to sink every enemy ship wins.",
	"2 Players: pass the phone. A cover screen hides the boards every time it changes hands — tap I'm ready only when it's your turn.",
	"⏸ pauses and keeps the battle; Resume on the Home screen carries on.",
]
const TIPS := [
	"Fire in a checkerboard pattern — every ship covers at least two squares, so you can't miss one.",
	"After a hit, try the squares above, below, left and right to find which way the ship runs.",
	"Once a ship is sunk, skip the squares around it — ships never touch.",
]
const STATS := ["Wins", "Losses", "Best streak", "2-player games"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Firing on a checkerboard pattern hits every ship of length 2 or more in half the shots of a full sweep.",
]
