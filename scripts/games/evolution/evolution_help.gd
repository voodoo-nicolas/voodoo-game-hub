extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "evolution"
const TITLE := "Evolution"
const GOAL := "Eat to grow from a tiny cell into the biggest thing in the pond. Don't get eaten."
const HOW := [
	"Touch and drag anywhere to steer: a joystick appears under your finger. On a PC use the mouse, or the arrow keys / WASD.",
	"Glowing dots are food. Swim into them to grow.",
	"Cells smaller than you glow green: swim into them to eat them, but they run away. Cells much bigger than you glow red and hunt you. Cells about your size (white) are safe both ways.",
	"You need to be clearly bigger than a cell to eat it: at least 15% more mass.",
	"The bigger you get, the slower you swim, and the camera pulls back so you can see more of the pond.",
	"If a bigger cell swallows you, the run is over. Your score is your biggest size.",
	"Nothing is saved mid-run, so there is no Resume: every run starts as a tiny cell.",
]
const TIPS := [
	"Eat food while the big cells are far away; grow first, hunt later.",
	"Hunters are a little slower than you at the same size. Keep moving and they can't catch you.",
	"Small cells flee, but they get cornered at the edge of the pond.",
]
const STATS := ["Best score", "Biggest size", "Cells eaten", "Food eaten", "Games played"]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Life on Earth began as single cells, more than 3 billion years ago.",
	"Many one-celled organisms, like amoebas, move and eat by flowing around their food.",
	"Natural selection means the traits that help a living thing survive get passed on more often.",
]
