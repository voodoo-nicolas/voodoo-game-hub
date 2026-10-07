extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "cannon_duel"
const TITLE := "Cannon Duel"
const GOAL := "Knock the other cannon's armour down to zero before it does the same to you."
const HOW := [
	"Players take turns. On your turn, drag on the field to aim: the direction sets the angle, how far you drag sets the power. ∠− ∠+ and ⚡− ⚡+ fine-tune them.",
	"Tap 🔥 Fire. The shell flies in an arc, pulled down by gravity and pushed sideways by the wind (the arrow at the top; it changes every turn).",
	"Shells blow craters in the ground. A cannon whose ground is blown away drops down, and a long fall hurts.",
	"The closer the blast, the more armour it takes: a direct hit with a Shell takes about 40 of 100. Your own shells can hurt you too.",
	"Tap the weapon button to switch: Shell (unlimited), Mega Bomb (huge blast, 2 per game) and Triple Shot (three shells in a fan, 2 per game).",
	"◀ ⛽ and ⛽ ▶ drive your cannon a little each turn, as far as its fuel goes — handy to get out of a crater or round a hill.",
	"vs Computer: you're the cyan cannon on the left. 2 Players: pass the phone each turn.",
	"⏸ pauses; Resume on the Home screen carries on the same battle.",
]
const TIPS := [
	"Your first shot is a sighter: see where it lands, then change only the power, a little at a time.",
	"Shooting into the wind needs more power; with the wind behind you, less.",
	"A high, steep shot clears the hill but drifts more in the wind.",
	"Save the Mega Bomb for when your aim is already landing close.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "Wins (Easy)", "Wins (Normal)", "Wins (Hard)", "Direct hits", "Fewest shots to win", "2-player games"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"With no wind and no air, a shot fired at 45° flies the farthest.",
	"Wind pushes a shell the whole time it flies, so long, high shots drift the most.",
]
