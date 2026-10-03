extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "kings_cup"
const TITLE := "Kings Cup"
const GOAL := "A party card game: draw cards, follow their rules, and don't draw the fourth King!"
const HOW := [
	"Choose how many players, then pass the phone around the circle.",
	"On your turn, tap any card from the circle, follow its rule, then tap Done.",
	"The game ends when the last card is drawn.",
	"A — Waterfall: everyone drinks; you can't stop until the person before you does.",
	"2 — You: pick someone to drink.",
	"3 — Me: you drink.",
	"4 — Floor: last to touch the floor drinks.",
	"5 — Guys: all guys drink.",
	"6 — Chicks: all chicks drink.",
	"7 — Heaven: last hand up drinks.",
	"8 — Mate: pick a mate who drinks whenever you do.",
	"9 — Rhyme: say a word; go around rhyming until someone fails.",
	"10 — Categories: name a category; go around until someone repeats or stalls.",
	"J — Make a rule: everyone follows it for the rest of the game.",
	"Q — Question master: anyone who answers your questions drinks.",
	"K — King's cup: pour some of your drink into the cup. The 4th King drinks it!",
	"⏸ pauses. A game is played at the table, so it isn't saved for later.",
]
const TIPS := [
	"Any drink works — water and soda count too. Know your limits and play responsibly.",
	"Make the Jack rules fun, not mean — everyone has to live with them.",
	"Stay sharp as Question Master: anyone who answers your question drinks.",
]
const STATS := ["Games played"]
