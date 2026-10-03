extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "red_or_black"
const TITLE := "Red or Black"
const GOAL := "A party card game: guess right to hand out drinks, guess wrong to take them."
const HOW := [
	"Choose how many players, then pass the phone around. Each player gets four guesses, one per round.",
	"Round 1: red or black? Round 2: higher or lower than your first card?",
	"Round 3: inside or outside your first two cards? (A tie counts as outside.) Round 4: guess the suit.",
	"Right guesses let you give drinks away; wrong ones mean you drink. Later rounds are worth more.",
	"⏸ pauses. A round is quick and played at the table, so it isn't saved for later.",
]
const TIPS := [
	"Any drink works — water and soda count too. Know your limits and play responsibly.",
	"In round 2, go higher when your first card is low and lower when it's high.",
	"In round 3, the wider the gap between your first two cards, the better inside looks.",
]
const STATS := ["Games played", "Right guesses", "Wrong guesses"]
