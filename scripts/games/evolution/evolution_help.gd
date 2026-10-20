extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "evolution"
const TITLE := "Evolution"
const GOAL := "Start as a blind one-cell blob and evolve: eat to grow, finish missions for new body parts and DNA, and survive the bigger creatures."
const HOW := [
	"Pick your colour and difficulty on the setup screen. The game plays sideways on a phone.",
	"Steer with the stick on the left. On a PC use the arrow keys or WASD, Space for the jump boost, Tab for the creature screen.",
	"The pond has no edges. At first your cell can only jerk sideways, and you can only see a small, blurry circle around you.",
	"You must eat. You must not be eaten. Some food will speed up your evolution greatly; some may slow it down.",
	"Missions are on the right, and they turn up as you discover things.",
	"The smallest dots are worth the least; the bigger the creature, the more it is worth. Things far smaller than you are worth nothing.",
	"The red bar is your health, the gold bar your growth. Bigger creatures bite when they touch you; they glow red. If your health runs out the run is over. Different kinds of creature also hunt each other.",
	"Once the tree is open, use the 🧬 screen (middle, next to pause): the game stops while you look. It shows your creature's size, speed, strength and health, and lets you spend DNA on the evolution tree: movement, senses, defense and offense. Traits you haven't unlocked yet show a ?.",
	"Creatures that can eat you glow red. Yellow-green spiky ones are toxic: they cause an ailment for a while. Rare golden ones give a free trait.",
	"Nothing is saved mid-run, so there is no Resume: every run starts as a tiny cell.",
]
const TIPS := [
	"Eat while the big creatures are far away; grow first, hunt later.",
	"Hunters are a little slower than your top speed. Keep moving and they can't catch you. The jump boost gets you out of trouble.",
	"Upgrade your senses early: seeing a hunter coming is half of surviving it.",
	"Toxic creatures are tempting: a glow makes hunters notice you, brittle makes bites hurt more. Wait out the ailment somewhere quiet.",
]
const STATS := ["Best score", "Biggest size", "Cells eaten", "Rare eaten", "Food eaten", "Distance swum (m)", "Missions done", "Games played"]

## Badges (achievements.gd): they unlock when the stat reaches `at`. Stats are lifetime totals ("Distance swum (m)":
## 10 world units = 1 m) or records ("Biggest size", "Top speed" = % of the best possible swimming speed).
const ACHIEVEMENTS := [
	{"id": "first_bite", "icon": "🦠", "title": "First bite", "desc": "Eat a creature", "key": "Cells eaten", "at": 1},
	{"id": "eat100", "icon": "🍽️", "title": "Hungry", "desc": "Eat 100 creatures", "key": "Cells eaten", "at": 100},
	{"id": "eat1000", "icon": "🦈", "title": "Glutton", "desc": "Eat 1,000 creatures", "key": "Cells eaten", "at": 1000},
	{"id": "eat10000", "icon": "👹", "title": "Devourer", "desc": "Eat 10,000 creatures", "key": "Cells eaten", "at": 10000},
	{"id": "rare1", "icon": "✨", "title": "Lucky find", "desc": "Eat a rare creature", "key": "Rare eaten", "at": 1},
	{"id": "rare10", "icon": "🌟", "title": "Treasure hunter", "desc": "Eat 10 rare creatures", "key": "Rare eaten", "at": 10},
	{"id": "rare100", "icon": "💎", "title": "Rare collector", "desc": "Eat 100 rare creatures", "key": "Rare eaten", "at": 100},
	{"id": "got_better", "icon": "🤒", "title": "I got better", "desc": "Get sick and survive until it wears off", "key": "Recoveries", "at": 1},
	{"id": "big_fish", "icon": "🐋", "title": "Big fish", "desc": "Reach size 6", "key": "Biggest size", "at": 6},
	{"id": "max_size", "icon": "🌊", "title": "Colossus", "desc": "Grow to the maximum size", "key": "Biggest size", "at": 10},
	{"id": "max_speed", "icon": "💨", "title": "Speed demon", "desc": "Reach the maximum swimming speed", "key": "Top speed", "at": 100},
	{"id": "evade", "icon": "🐟", "title": "Slippery", "desc": "Get away from a bigger creature that was chasing you", "key": "Creatures evaded", "at": 1},
	{"id": "stun5", "icon": "⚡", "title": "Shock and awe", "desc": "Stun 5 creatures at the same time", "key": "Most stunned", "at": 5},
	{"id": "swim1", "icon": "🏊", "title": "One kilometre", "desc": "Swim 1 km", "key": "Distance swum (m)", "at": 1000},
	{"id": "swim10", "icon": "🚤", "title": "Long haul", "desc": "Swim 10 km", "key": "Distance swum (m)", "at": 10000},
	{"id": "marathon", "icon": "🏅", "title": "Marathon", "desc": "Swim 28 km", "key": "Distance swum (m)", "at": 28000},
	{"id": "want_to_live", "icon": "❤️‍🩹", "title": "I want to live", "desc": "Drop below 10% health, then get back to full health", "key": "Comebacks", "at": 1},
	{"id": "be_back", "icon": "🔁", "title": "I'll be back", "desc": "Get chased by a bigger creature, grow, and then eat it", "key": "Revenge", "at": 1},
	{"id": "close_call", "icon": "😰", "title": "Close call", "desc": "Stay alive for 8 seconds close to a hunter", "key": "Close call", "at": 8},
	{"id": "score1", "icon": "🏆", "title": "Microbe master", "key": "Best score", "at": 1000},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Life on Earth began as single cells, more than 3 billion years ago.",
	"Many one-celled organisms, like amoebas, move and eat by flowing around their food.",
	"Natural selection means the traits that help a living thing survive get passed on more often.",
	"Many bacteria swim by spinning long whip-like tails called flagella.",
	"Viruses are not cells: they are much smaller than bacteria and need a living cell to copy themselves.",
]
