extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "speed"
const TITLE := "Speed"
const GOAL := "Get rid of all your cards before your opponent does. It's a race — no turns!"
const HOW := [
	"Tap a card in your hand to play it on a centre pile that is one higher or one lower. Ace and King connect.",
	"Your hand refills up to five from your draw pile.",
	"When neither of you can play, a new card is flipped onto each centre pile.",
	"The first to empty their hand and draw pile wins.",
	"Choose how fast the computer plays: Relaxed, Quick or Lightning.",
	"2 Players: sit face to face with the phone flat between you. Player 2's cards are at the top, upside down — both of you play at the same time.",
	"⏸ pauses the race. A race is quick, so it isn't saved for later.",
]
const TIPS := [
	"Look at both centre piles at once — there's often a play on the other one.",
	"Look for runs in your hand, like 5-6-7, and play them one after another.",
	"Speed matters more than perfection: just keep playing.",
]
const STATS := ["Wins", "Losses", "Best streak", "2-player games"]
