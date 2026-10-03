extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "pyramid"
const TITLE := "Pyramid"
const GOAL := "Clear all 28 cards from the pyramid."
const HOW := [
	"Tap two uncovered cards that add up to 13 to remove them. A card is uncovered when no card overlaps it from below.",
	"Aces are 1, Jacks 11, Queens 12. Kings are 13 on their own — tap one to remove it.",
	"Tap the stock to turn over a card onto the waste pile. The top waste card can pair too.",
	"You can go through the stock three times. The game ends when no pairs are left.",
	"⏸ pauses and keeps the game; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Before pairing, check which pair uncovers more cards.",
	"Plan for cards you'll need later: remember what's still in the stock.",
	"Remove Kings as soon as they're uncovered — they don't need a partner.",
]
const STATS := ["Wins", "Losses", "Best streak"]
