extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "arrow_cube"
const TITLE := "Arrow Cube"  # working title -- name still OPEN (GAME_DESIGN_ARROW_CUBE.md)
const GOAL := "Clear every arrow off the shape."
const HOW := [
	"Drag to turn the shape. Pinch (or the mouse wheel) to zoom. ⟲ puts the view back.",
	"Tap an arrow: it slides the way its head points, along the faces of the shape. If it reaches an edge with nothing in its way, it flies off.",
	"If another arrow is in its way, it bumps back and you lose a heart. You have 3 hearts per level; lose them all and you try the level again.",
	"Blue edges bend: an arrow that reaches one carries on along the next face. Inside corners always lead up the wall.",
	"Two-way lines (green and yellow) have a head at each end. Tap near the end you want it to leave from.",
	"Red stops: an arrow slides onto the stop and waits there. The stop is used up. Tap the arrow again to send it on.",
	"Forks (orange) have several heads. Every head needs a clear way out, then the whole fork flies.",
	"↶ Undo takes back a move (not a heart). It matters with stops: a parked arrow can block others.",
	"Helps: 👁 Safe lights up every arrow that can leave now. ✂ Remove takes away any arrow you pick.",
	"Stars: 3 with no bump and no help, 2 with one, 1 otherwise. No timer: take your time.",
	"500 levels; the shapes grow and change as you go. After level 500, Endless makes new shapes forever.",
]
const TIPS := [
	"Turn the shape all the way round before you tap: the free arrow is often on the back.",
	"Follow the line in front of a head to the edge. Anything on it means \"not yet\".",
	"Every level can be solved. An arrow that leaves never spoils it, so take any free one.",
	"Watch the blue edges: a line can run round a corner and hit something on the next face.",
]
const STATS := ["Levels cleared", "Total stars", "3-star levels", "Highest level", "Arrows cleared", "Endless cleared", "Wins", "Losses"]
## STANDARDS §3b (1000 points per game): these counters get no tier badges.
const NO_TIER_BADGES := ["Total stars", "3-star levels", "Arrows cleared", "Highest level"]

const ACHIEVEMENTS := [
	{"id": "lvl10", "icon": "🧊", "title": "First Turns", "desc": "Clear 10 levels", "key": "Levels cleared", "at": 10},
	{"id": "lvl50", "icon": "🔄", "title": "All Sides", "desc": "Clear 50 levels", "key": "Levels cleared", "at": 50},
	{"id": "lvl150", "icon": "📐", "title": "Shape Shifter", "desc": "Clear 150 levels", "key": "Levels cleared", "at": 150},
	{"id": "lvl500", "icon": "👑", "title": "Every Face", "desc": "Clear all 500 levels", "key": "Levels cleared", "at": 500},
	{"id": "star100", "icon": "⭐", "title": "Star Stacker", "desc": "Earn 100 stars", "key": "Total stars", "at": 100},
	{"id": "perfect50", "icon": "💎", "title": "Clean Lines", "desc": "Clear 50 levels with 3 stars", "key": "3-star levels", "at": 50},
	{"id": "arrows2000", "icon": "➶", "title": "Quiver Empty", "desc": "Clear 2000 arrows", "key": "Arrows cleared", "at": 2000},
	{"id": "endless25", "icon": "♾", "title": "No End", "desc": "Clear 25 Endless shapes", "key": "Endless cleared", "at": 25},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"A cube has 6 faces, 12 edges and 8 corners. For any solid without holes, faces minus edges plus corners is always 2 (Euler's formula).",
	"Shapes made by gluing cubes face to face are called polycubes. There are 8 different ones made of 4 cubes if mirror images count as different.",
	"Deciding which arrow has to go first is a dependency puzzle, the same kind of thinking computers use to order tasks.",
]
