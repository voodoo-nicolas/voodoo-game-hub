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
	"Tournaments: free to enter. Pick Tournament (1 to 5 opponents), Sit & Go (a full table, fast blinds) or Heads-up. Choose the starting chips and how fast the blinds go up; the last player with chips wins. A bigger field gives more XP.",
	"🎯 Career: eight tables, each with a boss and other characters. Win a stage to open the next. Stars: ★ for winning, ★★ if you did not use the coach or win chance, ★★★ if you won fast. Every computer player has its own style: the 🎓 coach shows it, and the character screen on each Career card tells you how to beat the boss.",
	"Video Poker (Jacks or Better): bet 1-5 coins of 10, 50 or 250 chips, tap cards to hold, then draw. 💡 shows the textbook hold.",
	"Pass and play: 2 to 6 people on one phone. The screen hides the cards whenever the phone changes hands. Online: heads-up against a friend; the first to take all the chips wins.",
	"🎓 Training: the coach table, hand rankings and five drills. At any table the 🎓 button turns the coach on: your win chance, the pot odds and what it would do.",
	"📈 My stats (under More on Home) keeps your level and XP, your numbers (VPIP, PFR, bb/100, results by game, stakes and seat), a graph of your chips and every hand you played: tap one to replay it, ⭐ to keep it.",
	"Out of chips with nothing at a table? The house spots you 1,000. ⏸ pauses; tables and the machine are saved, and Resume on Home carries on.",
]
const TIPS := [
	"Call when your chance of winning is bigger than the price: calling 25 into a pot of 75 needs a 25% chance.",
	"Count your outs: with two cards to come, outs × 4 is roughly your percentage; with one card, outs × 2.",
	"Position matters: acting last lets you see what everyone else does first.",
	"Play fewer, stronger starting hands, and bet them. Most hands in Hold'em should be folded before the flop.",
	"Turn the coach on to see each computer player's style: don't bluff a Calling Station, and believe a Rock's bets.",
]
const STATS := ["Most chips", "Hands played", "Hands won", "Biggest pot", "Wins", "Royal flushes", "Showdowns won", "Pots won uncontested", "Tournaments won", "Best hand streak", "Poker level", "Career stages cleared", "Drills done"]
const ACHIEVEMENTS := [
	{"id": "royal", "icon": "👑", "title": "Royal Treatment", "key": "Royal flushes", "at": 1},
	{"id": "pot5k", "icon": "💰", "title": "Big Pot", "key": "Biggest pot", "at": 5000},
	{"id": "pot50k", "icon": "🏦", "title": "Monster Pot", "key": "Biggest pot", "at": 50000},
	{"id": "chips10k", "icon": "🎩", "title": "High Roller", "key": "Most chips", "at": 10000},
	{"id": "chips100k", "icon": "💎", "title": "Whale", "key": "Most chips", "at": 100000},
	{"id": "perfect", "icon": "🎓", "title": "Star Student", "key": "Perfect drills", "at": 1},
	{"id": "hands100", "icon": "🃏", "title": "Regular at the Table", "key": "Hands played", "at": 100},
	{"id": "hands1000", "icon": "🎰", "title": "Grinder", "key": "Hands played", "at": 1000},
	{"id": "hands5000", "icon": "🛣", "title": "Road Warrior", "key": "Hands played", "at": 5000},
	{"id": "straightflush", "icon": "🌈", "title": "Straight to the Flush", "key": "Straight flushes", "at": 1},
	{"id": "quads", "icon": "4️⃣", "title": "Four of a Kind", "key": "Four of a kind made", "at": 1},
	{"id": "fullhouses", "icon": "🏠", "title": "House Rules", "key": "Full houses made", "at": 10},
	{"id": "uncontested25", "icon": "🎭", "title": "Bluffer", "key": "Pots won uncontested", "at": 25},
	{"id": "uncontested100", "icon": "🤫", "title": "Nobody Calls", "key": "Pots won uncontested", "at": 100},
	{"id": "showdowns50", "icon": "⚔️", "title": "Showdown Winner", "key": "Showdowns won", "at": 50},
	{"id": "streak5", "icon": "🔥", "title": "On Fire", "key": "Best hand streak", "at": 5},
	{"id": "tourney1", "icon": "🏅", "title": "Tournament Winner", "key": "Tournaments won", "at": 1},
	{"id": "tourney10", "icon": "🏆", "title": "Champion", "key": "Tournaments won", "at": 10},
	{"id": "level5", "icon": "⭐", "title": "Level 5", "key": "Poker level", "at": 5},
	{"id": "level10", "icon": "👑", "title": "Voodoo Master", "key": "Poker level", "at": 10},
	{"id": "days3", "icon": "📅", "title": "Back Again", "key": "Days in a row", "at": 3},
	{"id": "days7", "icon": "🗓", "title": "A Week at the Tables", "key": "Days in a row", "at": 7},
	{"id": "days30", "icon": "🌙", "title": "Night Owl", "key": "Days in a row", "at": 30},
	{"id": "career1", "icon": "🎯", "title": "First Boss Down", "key": "Career stages cleared", "at": 1},
	{"id": "career4", "icon": "🗝", "title": "Halfway Up the Ladder", "key": "Career stages cleared", "at": 4},
	{"id": "career8", "icon": "👑", "title": "Long Live the Player", "key": "Career stages cleared", "at": 8},
	{"id": "careerstars12", "icon": "🌟", "title": "Star Collector", "key": "Career stars", "at": 12},
	{"id": "careerstars24", "icon": "✨", "title": "Perfect Career", "key": "Career stars", "at": 24},
]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"There are 2,598,960 different five-card poker hands.",
	"A royal flush is dealt about once in 649,740 hands.",
]
