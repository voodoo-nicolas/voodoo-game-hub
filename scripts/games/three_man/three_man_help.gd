extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "three_man"
const TITLE := "Three Man"
const GOAL := "A party dice game: roll two dice and follow what they say. Whoever becomes 3 Man drinks a lot!"
const HOW := [
	"Choose how many players. Everyone rolls one die: the lowest goes first.",
	"On your turn, roll two dice. Any roll that does something lets you roll again; a roll where nothing happens passes the dice on.",
	"A 3 on either die (or a 1 and 2) makes you 3 Man if nobody is yet. After that, every 3 makes the 3 Man drink.",
	"A total of 7: the player to your right drinks. 11: the player to your left drinks.",
	"Doubles: give out that many drinks. Double 3s: give out 3 drinks, and 3 Man drinks twice.",
	"Roll a 3 and a 4 as 3 Man and you're free — the next 3 makes someone else 3 Man.",
]
const TIPS := [
	"Any drink works — water and soda count too. Know your limits and play responsibly.",
	"The screen tells you what each roll means, so nobody has to remember the rules.",
]
const STATS := ["Games played", "Rolls"]
