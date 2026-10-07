extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "color_sort"
const TITLE := "Color Sort"
const GOAL := "Sort the balls until every tube holds a single color."
const HOW := [
	"Tap a tube to pick up its top ball, then tap another tube to put it there. Tap the same tube again to put it back.",
	"A ball can go into an empty tube, or onto a ball of the same color, as long as the tube has room. Every tube holds 4 balls.",
	"You win when every tube is either empty or full of one color. Every color has its own little symbol too, so you never have to rely on color alone.",
	"↩ Undo takes back your last move. ⟲ Reset puts the puzzle back as it was dealt. ➕ Tube adds one extra empty tube, once per puzzle.",
	"Easy has 4 colors, Normal 6, Hard 8 and Expert 10. Every puzzle can be solved. Fewer moves is better.",
	"A puzzle in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Free up an empty tube first: it is your most useful tool.",
	"Don't bury a color you need under another one if you can avoid it.",
	"Plan two or three moves ahead: look for a ball that unlocks the next one.",
]
const STATS := ["Puzzles solved", "Fewest moves (Easy)", "Fewest moves (Normal)", "Fewest moves (Hard)", "Fewest moves (Expert)"]

const ACHIEVEMENTS := [
	{"id": "solved1", "icon": "🧪", "title": "First Sort", "desc": "Solve 5 puzzles", "key": "Puzzles solved", "at": 5},
	{"id": "solved2", "icon": "🎨", "title": "Color Master", "desc": "Solve 50 puzzles", "key": "Puzzles solved", "at": 50},
	{"id": "solved3", "icon": "🌈", "title": "Rainbow Keeper", "desc": "Solve 200 puzzles", "key": "Puzzles solved", "at": 200},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Newton showed in the 1660s that white light is made of all the colors of the rainbow, by splitting it with a prism.",
]
