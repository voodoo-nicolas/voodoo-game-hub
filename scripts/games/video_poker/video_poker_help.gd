extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "video_poker"
const TITLE := "Video Poker"
const GOAL := "Build your credits as high as they'll go. Play money only — nothing to buy, nothing to win but bragging rights."
const HOW := [
	"You start with 100 credits. Set your bet (1 to 5) with − and +, then tap Deal.",
	"Tap the cards you want to keep — they rise and show HELD. Tap Draw to replace the others.",
	"Your final hand pays by the table at the top, times your bet. The lowest win is a pair of Jacks or better (J, Q, K or A).",
	"A Royal Flush on a 5-credit bet pays 4000.",
	"Run out of credits and the session ends; start a new one any time.",
	"⏸ pauses and keeps your credits (and the hand you're holding); Resume on the Home screen carries on.",
]
const TIPS := [
	"Always keep a pair of Jacks or better — it already pays back your bet.",
	"Four cards to a flush or straight flush are worth holding; four to an inside straight usually aren't.",
	"Bet 5 if you can: the Royal Flush pays far more on a full bet.",
]
const STATS := ["Most credits", "Biggest win", "Hands played", "Royal flushes", "Sessions played"]
