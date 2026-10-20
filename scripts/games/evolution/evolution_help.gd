extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "evolution"
const TITLE := "Evolution"
const GOAL := "Start as a blind one-cell blob and evolve: eat to grow, finish missions for new body parts and DNA, and survive the bigger creatures."
const HOW := [
	"Pick your colour and difficulty on the setup screen. The game plays sideways on a phone.",
	"Steer with the stick on the left. On a PC use the arrow keys or WASD, Space for the jump boost, Tab for the creature screen.",
	"The pond has no edges. At first your cell can only jerk sideways, and you can only see a small, blurry circle around you.",
	"Missions are on the right, and they turn up as you discover things. A bar shows how far along each one is. First: move around, then eat lots of small creatures to grow a tail (you swim much faster). The quick way: eat a little creature that already has a tail. The same goes for your first eye.",
	"Everything has a size. The smallest dots are worth 1; a bigger creature is worth its size. Once you are 3 sizes bigger than something it is worth nothing and shows as a faint particle, and 4 sizes bigger it is invisible.",
	"With a tail and an eye, hunt 10 creatures and the evolution tree opens. After that, missions give you size or DNA points.",
	"The red bar is your health, the gold bar your growth. Bigger creatures bite when they touch you. If your health runs out the run is over. Different kinds of creature also hunt each other.",
	"Once the tree is open, use the 🧬 screen (middle, next to pause): the game stops while you look. It shows your creature's size, speed, strength and health, and lets you spend DNA on the evolution tree: movement, senses, defense and offense. Traits you haven't unlocked yet show a ?.",
	"Green rings mark creatures you can eat, red rings hunters, white rings creatures your size. Yellow-green spiky ones are toxic: they cause an ailment for a while. Rare golden ones give a free trait.",
	"Nothing is saved mid-run, so there is no Resume: every run starts as a tiny cell.",
]
const TIPS := [
	"Eat while the big creatures are far away; grow first, hunt later.",
	"Hunters are a little slower than your top speed. Keep moving and they can't catch you. The jump boost gets you out of trouble.",
	"Upgrade your senses early: seeing a hunter coming is half of surviving it.",
	"Toxic creatures are tempting: a glow makes hunters notice you, brittle makes bites hurt more. Wait out the ailment somewhere quiet.",
]
const STATS := ["Best score", "Biggest size", "Cells eaten", "Food eaten", "Missions done", "Games played"]

## Badges (achievements.gd). "Close call" is the longest time (up to 8 s) you stayed near a hunter and lived.
const ACHIEVEMENTS := [
	{"id": "close_call", "icon": "😰", "title": "Close call", "desc": "Stay alive for 8 seconds close to a hunter", "key": "Close call", "at": 8},
	{"id": "big_fish", "icon": "🐋", "title": "Big fish", "desc": "Reach size 6", "key": "Biggest size", "at": 6},
	{"id": "score1", "icon": "🦠", "title": "Microbe master", "key": "Best score", "at": 1000},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Life on Earth began as single cells, more than 3 billion years ago.",
	"Many one-celled organisms, like amoebas, move and eat by flowing around their food.",
	"Natural selection means the traits that help a living thing survive get passed on more often.",
	"Many bacteria swim by spinning long whip-like tails called flagella.",
	"Viruses are not cells: they are much smaller than bacteria and need a living cell to copy themselves.",
]
