extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "evolution"
const TITLE := "Evolution"
const GOAL := "Start as a blind one-cell blob and evolve: eat to grow, finish missions for new body parts and DNA, and survive the bigger creatures."
const HOW := [
	"Pick your colour and difficulty on the setup screen. The game plays sideways on a phone.",
	"Steer with the stick on the left. On a PC use the arrow keys or WASD, Space for the jump boost, Tab for the creature screen.",
	"The pond has no edges. At first your cell can only jerk sideways, and you can only see a small, blurry circle around you.",
	"Missions are on the right. Move around, eat a creature to grow a tail (you swim much faster), then eat 10 more to open an eye (you see farther).",
	"After that, each mission gives either one size or one DNA point. There is always an eat-and-grow mission, and new creatures you meet bring new missions.",
	"The red bar is your health, the gold bar your growth. Bigger creatures bite when they touch you. If your health runs out the run is over.",
	"Open the 🧬 screen (middle, next to pause) to see your creature's size, speed, strength and health, and to spend DNA on the evolution tree: movement, senses, defense and offense. Traits you haven't unlocked yet show a ?.",
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

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Life on Earth began as single cells, more than 3 billion years ago.",
	"Many one-celled organisms, like amoebas, move and eat by flowing around their food.",
	"Natural selection means the traits that help a living thing survive get passed on more often.",
	"Many bacteria swim by spinning long whip-like tails called flagella.",
	"Viruses are not cells: they are much smaller than bacteria and need a living cell to copy themselves.",
]
