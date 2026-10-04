extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "war"
const TITLE := "War"
const GOAL := "Win all 52 cards — against the computer or a friend."
const HOW := [
	"The deck is split in two. Tap Play Round and each player turns over their top card.",
	"The higher card wins both. Aces are high.",
	"A tie means War: each player puts three cards face down and one face up. The higher face-up card takes them all.",
	"Run out of cards and you lose.",
	"2 Players: share the phone. Each player has a Flip button; the round is played when both have flipped.",
	"⏸ pauses and keeps the game; Resume on the Home screen carries on.",
]
const TIPS := [
	"War is pure luck — there's nothing to decide, so just enjoy it.",
	"A long War can swing the game in one go!",
]
const STATS := ["Wins", "Losses", "Best streak", "2-player games"]
