extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "color_sort"
const TITLE := "Color Sort"
const GOAL := "Pour the liquid until every vial holds a single color."
const HOW := [
	"Tap a vial to lift it, then tap another vial to pour its top color there. Tap the same vial again to put it down.",
	"You can pour onto the same color, or into an empty vial, if there is room. A pour moves the whole top run of one color, as much as fits.",
	"You win when every vial is empty or full of one color. There are eighteen colors, and more vials than before.",
	"For color-blind players: turn on Color-blind shapes on the setup screen, and every color gets its own shape. There is also a color-blind palette.",
	"Some levels have a big central vial, in different shapes. It only takes the color shown above it, in that order. Fill it completely and sort every small vial to win.",
	"Some plain levels hide layers too: a layer stays hidden until it reaches the top of its vial.",
	"↩ Undo takes back a move. ⟲ Reset puts the puzzle back as dealt. ➕ Tube adds an empty vial. 💡 Hint shows the next pour. In the campaign, hints and extra vials are earned: win a level with 3 stars, clear a special level, or just play every day.",
	"Every 10th level is special: mystery layers, padlocks, a move limit, a timer, sealed corks, blocked pours, and bosses with several rules at once. The banner above the vials tells you the rule.",
	"⏱ Timed is its own run of levels with a clock on every level. Beat the level before the clock runs out to move on; if it runs out, try the same level again.",
	"Stars: 3 for finishing within about 15% of the par (the fewest moves we know), 2 within 60%, otherwise 1.",
	"Turn on Color names on the setup screen to see the name of a color when you pick it up, in your language or in English and Spanish.",
	"A puzzle in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Free up an empty vial first: it is your most useful tool.",
	"Don't bury a color you need under another one if you can avoid it.",
	"Plan two or three pours ahead: look for a layer that unlocks the next one.",
	"On a mystery level, uncover the vials with the fewest hidden layers first.",
	"Use a hint when you are stuck, not when you are rushed: stars are worth more.",
]
const STATS := ["Puzzles solved", "Levels cleared", "Total stars", "3-star levels", "Highest level", "Special levels cleared",
	"Bosses beaten", "Timed levels beaten", "Fastest level (seconds)", "Fewest moves (Easy)", "Fewest moves (Normal)", "Fewest moves (Hard)", "Fewest moves (Expert)"]

const ACHIEVEMENTS := [
	{"id": "solved1", "icon": "🧪", "title": "First Sort", "desc": "Solve 5 puzzles", "key": "Puzzles solved", "at": 5},
	{"id": "solved2", "icon": "🎨", "title": "Color Master", "desc": "Solve 50 puzzles", "key": "Puzzles solved", "at": 50},
	{"id": "solved3", "icon": "🌈", "title": "Rainbow Keeper", "desc": "Solve 200 puzzles", "key": "Puzzles solved", "at": 200},
	{"id": "lvl10", "icon": "⚗", "title": "Apprentice Alchemist", "desc": "Clear 10 levels", "key": "Levels cleared", "at": 10},
	{"id": "lvl50", "icon": "🔮", "title": "Potion Master", "desc": "Clear 50 levels", "key": "Levels cleared", "at": 50},
	{"id": "lvl150", "icon": "🏺", "title": "Grand Alchemist", "desc": "Clear 150 levels", "key": "Levels cleared", "at": 150},
	{"id": "star30", "icon": "⭐", "title": "Star Collector", "desc": "Earn 30 stars", "key": "Total stars", "at": 30},
	{"id": "star150", "icon": "🌟", "title": "Starstruck", "desc": "Earn 150 stars", "key": "Total stars", "at": 150},
	{"id": "star450", "icon": "🌌", "title": "Galaxy of Stars", "desc": "Earn 450 stars", "key": "Total stars", "at": 450},
	{"id": "special5", "icon": "🎭", "title": "Rule Breaker", "desc": "Clear 5 special levels", "key": "Special levels cleared", "at": 5},
	{"id": "boss1", "icon": "👑", "title": "Boss Slayer", "desc": "Beat a boss level", "key": "Bosses beaten", "at": 1},
	{"id": "boss3", "icon": "💀", "title": "Boss Hunter", "desc": "Beat 3 boss levels", "key": "Bosses beaten", "at": 3},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Newton showed in the 1660s that white light is made of all the colors of the rainbow, by splitting it with a prism.",
	"Mixing red, green and blue light makes white, but mixing lots of different paints makes a muddy brown.",
	"Around 1 in 12 men and 1 in 200 women have some form of color blindness, so patterns help as much as colors.",
	"Orange the color is named after the fruit; in English the fruit came first.",
]
