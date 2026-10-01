extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "reaction_test"
const TITLE := "Reaction Test"
const GOAL := "Tap as fast as you can the moment the pad turns green."
const HOW := [
	"Tap the pad to start, then wait while it's red.",
	"After a random delay it turns green — tap it right away.",
	"Your reaction time is shown in milliseconds (1000 ms = 1 second).",
	"Tap before it turns green and it counts as a false start.",
]
const TIPS := [
	"Don't try to guess the moment — the delay is random every time.",
	"Most people land between 200 and 300 ms. Under 200 is very fast!",
	"Relax your hand and keep your finger just above the screen.",
]
const STATS := ["Fastest reaction (ms)", "Tests taken"]
