extends RefCounted

## How to Play text, stats and badges for GameInfo (scripts/common/game_info.gd).

const ID := "block_escape"
const TITLE := "Block Escape"
const GOAL := "Get every block off the board before the clock runs out. Each block leaves only through a gate of its own colour."
const HOW := [
	"Drag a block with your finger. It slides one square at a time and stops at walls and other blocks.",
	"Gates sit on the frame around the board. A block leaves when it touches a gate of its colour that is at least as wide as the block.",
	"Each colour also has its own mark (● ■ ▲ ◆ ★ ✚ ♥ ⬢), on the blocks and on their gates.",
	"Chained blocks show a number: they can't move until that many other blocks have left.",
	"Blocks with arrows slide only the way the arrows point: sideways or up and down.",
	"Levels: 300 boards against the clock, each one a little harder. 3 ★ = out with half the time left and no help, 2 ★ = a quarter left, 1 ★ = out in time. Daily: one board a day, the same for everyone. Zen: no clock.",
]
const TIPS := [
	"Look for the block that blocks the most others, and free its way first.",
	"Big blocks need wide gates: find where they can leave before you move anything.",
	"Count the chains: get the blocks out that unlock them early.",
]
const STATS := ["Levels cleared", "Boards cleared", "Blocks escaped", "Daily streak"]
## Keep the game under 1000 achievement points (STANDARDS §3b): no tier badges for the big counter.
const NO_TIER_BADGES := ["Blocks escaped"]

const ACHIEVEMENTS := [
	{"id": "lvl10", "icon": "🧱", "title": "Out the Door", "desc": "Clear Levels 1 to 10", "key": "Levels cleared", "at": 10},
	{"id": "lvl100", "icon": "🏗", "title": "Block Buster", "desc": "Clear Levels 1 to 100", "key": "Levels cleared", "at": 100},
	{"id": "lvl300", "icon": "🏆", "title": "Grand Escape", "desc": "Clear all 300 Levels", "key": "Levels cleared", "at": 300},
	{"id": "stars3", "icon": "⭐", "title": "Speed Mover", "desc": "Earn 3 ★ on 25 boards", "key": "3-star clears", "at": 25},
	{"id": "out1000", "icon": "🚪", "title": "Thousand Exits", "desc": "Get 1000 blocks out", "key": "Blocks escaped", "at": 1000},
	{"id": "daily7", "icon": "📅", "title": "Week of Escapes", "desc": "Clear the Daily 7 days in a row", "key": "Daily streak", "at": 7},
]

## Learning hook (STANDARDS §15): sliding-block puzzles and planning.
const FACTS := [
	"Sliding-block puzzles are an old kind of puzzle: deciding whether some of them can be solved at all is known to be a very hard problem for computers.",
	"Planning backwards, from the last block to leave to the first, is a common way to solve sliding puzzles. It is also how these boards were made.",
]
