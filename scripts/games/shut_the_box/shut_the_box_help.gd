extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "shut_the_box"
const TITLE := "Shut the Box"
const GOAL := "Flip down all nine tiles — or leave as few points standing as you can."
const HOW := [
	"Roll the two dice, then tap tiles that add up to the roll. They flip down as soon as the sum is right.",
	"Any combination works: a roll of 8 can be the 8, 5 and 3, or 1, 3 and 4.",
	"Once 7, 8 and 9 are all down, you may roll just one die.",
	"When no tiles add up to your roll, the round is over. Your score is the total of the tiles still up — lower is better.",
	"Flip every tile and you've shut the box: an instant win!",
	"vs Computer: you play your round, then the computer plays its own. The lower score wins. Solo: chase your lowest score.",
]
const TIPS := [
	"Knock down the high tiles first — 7, 8 and 9 are the hardest to get rid of later.",
	"Use fewer, bigger tiles when you can, and keep the small ones for small rolls.",
	"Totals of 6, 7 and 8 come up most often with two dice.",
	"With only small tiles left, roll one die: low totals are much easier to hit.",
]
const STATS := ["Wins", "Losses", "Draws", "Boxes shut", "Lowest score"]
