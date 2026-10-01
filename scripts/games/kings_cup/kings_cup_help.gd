extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "kings_cup"
const TITLE := "Kings Cup"
const GOAL := "A party card game: draw cards, follow their rules, and don't draw the fourth King!"
const HOW := [
	"Choose how many players, then pass the phone around the circle.",
	"On your turn, tap any card from the circle. Its rule appears on screen — follow it, then tap Done.",
	"A: make a rule. 2: pick someone to drink. 3: you drink. 4: last to touch the floor drinks. 7: last hand up drinks. 8: pick a mate who drinks with you.",
	"9: rhyme. 10: categories. J: never have I ever. Q: question master — anyone who answers your questions drinks.",
	"Each King: pour some of your drink into the cup in the middle. Whoever draws the fourth King drinks the cup!",
]
const TIPS := [
	"Any drink works — water and soda count too. Know your limits and play responsibly.",
	"Make the Ace rules fun, not mean — everyone has to live with them.",
	"Stay sharp as Question Master: anyone who answers your question drinks.",
]
const STATS := ["Games played"]
