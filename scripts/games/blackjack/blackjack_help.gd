extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "blackjack"
const TITLE := "Blackjack"
const GOAL := "Beat the dealer by getting closer to 21 without going over."
const HOW := [
	"Tap the + buttons to build your bet, then Deal. You and the dealer each get two cards.",
	"Number cards count their number, J, Q and K count 10, and an Ace counts 1 or 11.",
	"Hit to take another card, Stand to keep your hand. Go over 21 and you bust.",
	"Double doubles your bet on your first two cards and gives you exactly one more card.",
	"The dealer must hit until 17. Win and you double your bet; a Blackjack (Ace + 10 on the first two cards) pays 3 to 2; a tie returns your bet.",
	"These are play chips only. Run out and you get a fresh stack.",
	"Your chips are kept between visits. ⏸ pauses; leaving mid-hand returns that bet to your chips.",
]
const TIPS := [
	"Always stand on hard 17 or more.",
	"Hit on 12–16 when the dealer shows 7 or higher; stand when the dealer shows 2–6 — they're likely to bust.",
	"Double on 11, and on 10 unless the dealer shows a 10 or Ace.",
	"An Ace that can still count as 11 (a soft hand) can't bust on the next card, so hit soft 17 or less.",
]
const STATS := ["Hands won", "Hands lost", "Pushes", "Blackjacks", "Most chips"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"16 of the 52 cards are worth 10 (10, J, Q, K), so a hidden card is a ten-value card about 4 times in 13.",
]
