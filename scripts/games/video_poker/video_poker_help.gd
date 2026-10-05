extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## The id stays video_poker: Poker grew out of the Video Poker game.

const ID := "video_poker"
const TITLE := "Poker"
const GOAL := "Win chips with the best hand, or by making everyone else fold. Play chips only: nothing to buy, nothing to win but bragging rights."
const HOW := [
	"Pick the game and the betting on Home: Texas Hold'em, Omaha, Five Card Draw or Seven Card Stud; No limit, Pot limit or Limit (Stud is always Limit).",
	"Hold'em: two cards each and five shared cards on the board; make your best five from all seven. Omaha: four cards each, and you must use exactly two of them with three from the board.",
	"Five Card Draw: five cards each, a round of betting, then swap up to 3 cards (4 if you keep an Ace) and bet again. Seven Card Stud: three down, four up, one more down; antes and a bring-in instead of blinds.",
	"On your turn: Fold, Check or Call, or Bet / Raise. In No limit and Pot limit, size your raise with Min, ½ Pot, Pot, All in, − and +.",
	"Cash game: buy in from your chips at low, mid or high stakes, play as long as you like and Leave table to take your chips home. Busted computer players are replaced.",
	"Tournament: free to enter. Everyone starts with 1,500, the blinds go up every 6 hands, and the last player with chips wins.",
	"Video Poker (Jacks or Better): bet 1-5 coins of 10, 50 or 250 chips, tap cards to hold, then draw. 💡 shows the textbook hold.",
	"Pass and play: 2 to 6 people on one phone. The screen hides the cards whenever the phone changes hands. Online: heads-up against a friend; the first to take all the chips wins.",
	"🎓 Training: the coach table, hand rankings and five drills. At any table the 🎓 button turns the coach on: your win chance, the pot odds and what it would do.",
	"Out of chips with nothing at a table? The house spots you 1,000. ⏸ pauses; tables and the machine are saved, and Resume on Home carries on.",
]
const TIPS := [
	"Call when your chance of winning is bigger than the price: calling 25 into a pot of 75 needs a 25% chance.",
	"Count your outs: with two cards to come, outs × 4 is roughly your percentage; with one card, outs × 2.",
	"Position matters: acting last lets you see what everyone else does first.",
	"Play fewer, stronger starting hands, and bet them. Most hands in Hold'em should be folded before the flop.",
	"Turn the coach on to see each computer player's style: don't bluff a Calling Station, and believe a Rock's bets.",
]
const STATS := ["Most chips", "Hands played", "Hands won", "Biggest pot", "Wins", "Royal flushes", "Drills done"]
const ACHIEVEMENTS := [
	{"id": "royal", "icon": "👑", "title": "Royal Treatment", "key": "Royal flushes", "at": 1},
	{"id": "pot5k", "icon": "💰", "title": "Big Pot", "key": "Biggest pot", "at": 5000},
	{"id": "pot50k", "icon": "🏦", "title": "Monster Pot", "key": "Biggest pot", "at": 50000},
	{"id": "chips10k", "icon": "🎩", "title": "High Roller", "key": "Most chips", "at": 10000},
	{"id": "chips100k", "icon": "💎", "title": "Whale", "key": "Most chips", "at": 100000},
	{"id": "perfect", "icon": "🎓", "title": "Star Student", "key": "Perfect drills", "at": 1},
]
