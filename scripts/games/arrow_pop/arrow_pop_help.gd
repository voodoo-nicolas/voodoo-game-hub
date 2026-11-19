extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "arrow_pop"
const TITLE := "Arrow Pop"
const GOAL := "Fire every arrow so it pops the bubbles of its own colour, and clear the board."
const HOW := [
	"Tap an arrow to fire it. It flies the way it points, pops every bubble of ITS colour on the way, and leaves the board.",
	"An arrow can never hit a bubble of another colour, or another arrow. If one is in its way, the arrow bumps, comes back, and you lose a heart.",
	"Empty cells don't stop an arrow: it flies straight over them.",
	"Clear every bubble and every arrow to win. You have 3 hearts per level: lose them all and you try the level again.",
	"Stars: 3 for a level with no bump, 2 with one, 1 otherwise.",
	"There are 320 levels. Boards grow, colours are added and the order you must fire in gets longer as you go.",
	"Turn on Color-blind shapes in the setup screen: every colour then gets its own mark.",
	"⏸ pauses and keeps the board; Resume on the Landing carries on.",
]
const TIPS := [
	"Look along each arrow's line before you tap: any other colour in the way means \"not yet\".",
	"Start with arrows on the edge pointing out: often nothing stands in their way.",
	"Every arrow you fire clears a line, and may free the arrows behind it.",
	"Every level can be solved, and a free arrow never spoils it: fire any arrow whose way is clear.",
]
const STATS := ["Levels cleared", "Total stars", "3-star levels", "Highest level", "Bubbles popped", "Wins", "Losses", "Best streak"]
## STANDARDS §3b (1000 points per game): these counters get no tier badges.
const NO_TIER_BADGES := ["Total stars", "3-star levels", "Bubbles popped", "Highest level"]

const ACHIEVEMENTS := [
	{"id": "lvl10", "icon": "🎯", "title": "On Target", "desc": "Clear 10 levels", "key": "Levels cleared", "at": 10},
	{"id": "lvl50", "icon": "🏹", "title": "Sharpshooter", "desc": "Clear 50 levels", "key": "Levels cleared", "at": 50},
	{"id": "lvl150", "icon": "🎖", "title": "Marksman", "desc": "Clear 150 levels", "key": "Levels cleared", "at": 150},
	{"id": "lvl320", "icon": "👑", "title": "Every Bubble", "desc": "Clear all 320 levels", "key": "Levels cleared", "at": 320},
	{"id": "star50", "icon": "⭐", "title": "Star Catcher", "desc": "Earn 50 stars", "key": "Total stars", "at": 50},
	{"id": "star300", "icon": "🌟", "title": "Starburst", "desc": "Earn 300 stars", "key": "Total stars", "at": 300},
	{"id": "perfect25", "icon": "💎", "title": "Clean Shots", "desc": "Clear 25 levels with 3 stars", "key": "3-star levels", "at": 25},
	{"id": "pop1000", "icon": "🫧", "title": "Pop Star", "desc": "Pop 1000 bubbles", "key": "Bubbles popped", "at": 1000},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"A soap bubble is round because a sphere holds the most air for the least surface, and the soap film pulls itself as small as it can.",
	"The colours on a soap bubble come from light bouncing off both sides of a film thinner than a hair, not from any dye.",
	"Working out which arrow must go first is a dependency puzzle, the same kind of thinking computers use to decide which task to run first.",
]
