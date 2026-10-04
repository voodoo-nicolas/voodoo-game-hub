extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "tri_peaks"
const TITLE := "Tri-Peaks"
const GOAL := "Clear all 28 cards from the three peaks."
const HOW := [
	"Tap an uncovered card that is one rank higher or lower than the card on the waste pile (suits don't matter). It becomes the new waste card.",
	"In Classic, Ace and King touch, so you can go K–A–2. Strict doesn't allow that.",
	"Cards turn face up as soon as nothing covers them. Face-up cards that don't fit right now are dimmed.",
	"No move? Tap the stock to turn its next card onto the waste.",
	"Each card in a streak scores more: 10, 20, 30... Turning a stock card ends the streak. Clearing a peak's top card is +250; clearing them all is +1000 plus 50 for each stock card left.",
	"↶ Undo takes back moves. The game ends when the peaks are clear, or the stock is empty with no move left.",
	"⏸ pauses and keeps the deal; Resume on the Home screen carries on.",
]
const TIPS := [
	"Before taking a card, look ahead: which choice uncovers cards that keep the run going?",
	"Don't rush to the stock — every card it gives you ends your streak.",
	"Free cards from the peaks' bottom rows early, so more cards turn face up.",
]
const STATS := ["Best score", "Games won", "Games played", "Longest streak"]
