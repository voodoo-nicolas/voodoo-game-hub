extends RefCounted

## Evolution: the lookup tables (colours, difficulty, creatures, evolution tree,
## ailments, vision rings). No logic here; the engine and the screens read it.

## Primary colour choices on the setup screen: [English name, colour].
const COLORS := [
	["Cyan", Color("29e6ff")], ["Lime", Color("7dff3a")], ["Pink", Color("ff4f9a")], ["Gold", Color("ffd23f")],
	["Violet", Color("b57dff")], ["Orange", Color("ff9f43")], ["Sky", Color("5aa8ff")], ["White", Color("e6f0ff")],
]

## hunters: share of spawns that hunt you; bite: damage per second of contact;
## regen: multiplier on natural healing; speed: hunter speed vs your top speed.
const DIFFICULTY := {
	"easy": {"hunters": 0.10, "bite": 1.2, "regen": 1.5, "speed": 0.78},
	"normal": {"hunters": 0.20, "bite": 2.0, "regen": 1.0, "speed": 0.88},
	"hard": {"hunters": 0.30, "bite": 3.0, "regen": 0.7, "speed": 0.98},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard"]

## Vision rings (the target picture: rank 1 = small blurry circle, rank 4 = everything).
## Radius as a fraction of the screen height.
const SIGHT_FRAC := [0.26, 0.5, 0.8, 1.7]
## Blur strength (mip level) by clarity level 0..2.
const BLUR := [2.6, 1.5, 0.6, 0.0]

## Size levels by mass: level L starts at LEVELS[L - 1]. The smallest dots are level 1 and worth 1;
## a creature worth eating is worth its own level. Anything 3 or more levels below you is worth
## nothing (it shows as a faint particle, and at 4 or more levels below it is invisible).
const LEVELS := [0.0, 14.0, 30.0, 62.0, 130.0, 270.0, 560.0, 1150.0, 2350.0, 4800.0]

## Speed multiplier by movement rank (0 = jolting, no tail).
const MOVE_MULT := [0.0, 0.55, 0.72, 0.88, 1.02, 1.15]

## Creatures. role: prey (smaller than you), equal (about your size), hunter
## (bigger, bites), toxic (poisonous, uncommon), rare (grants a trait).
## shape is drawn by evolution_art.gd.
const SPECIES := [
	{"id": "coccus", "name": "Coccus", "shape": "beads", "role": "prey", "col": Color("9bd34a")},
	{"id": "bacillus", "name": "Bacillus", "shape": "rod", "role": "prey", "col": Color("4fb3e8")},
	{"id": "strepto", "name": "Strep chain", "shape": "chain", "role": "prey", "col": Color("7a8cff")},
	{"id": "papilloma", "name": "Papilloma", "shape": "bumpy", "role": "equal", "col": Color("a35dd8")},
	{"id": "zika", "name": "Zika", "shape": "bumpy", "role": "equal", "col": Color("e8693a")},
	{"id": "herpes", "name": "Herpes", "shape": "spiky", "role": "equal", "col": Color("e6b84a")},
	{"id": "corona", "name": "Corona", "shape": "corona", "role": "hunter", "col": Color("e0405a")},
	{"id": "ebola", "name": "Ebola", "shape": "worm", "role": "hunter", "col": Color("e0405a")},
	{"id": "phage", "name": "Phage", "shape": "phage", "role": "hunter", "col": Color("e0603a")},
	{"id": "rota", "name": "Rotavirus", "shape": "spiky", "role": "hunter", "col": Color("78c43a")},
	{"id": "tailed", "name": "Flagellate", "shape": "tailed", "role": "prey", "col": Color("ffb35a"), "trait": "tail"},
	{"id": "eyed", "name": "Eyed cell", "shape": "eyed", "role": "prey", "col": Color("e0a3ff"), "trait": "eye"},
	{"id": "toxin", "name": "Toxic spore", "shape": "spiky", "role": "toxic", "col": Color("c8e03a")},
	{"id": "gold", "name": "Golden spore", "shape": "spiky", "role": "rare", "col": Color("ffd23f")},
]

## Mass of a spawn relative to yours: [low, high] by role.
const MASS_RANGE := {
	"prey": [0.25, 0.8], "equal": [0.88, 1.1], "hunter": [1.3, 2.6], "toxic": [0.4, 0.8], "rare": [0.15, 0.3],
}

## The evolution tree is a graph (like a skill tree): the creature sits at the far left and four
## branches grow to the right. Each node: `req` = every [node, minimum points] that must be owned first
## (some need more than one), `max` = how many points it takes (extra points strengthen it),
## `cost` = DNA for the first point (each further point costs one more), `stage` = growth stage
## (engine STAGES index) needed, x / y = place on the tree screen in grid cells.
## `ability` nodes are actives (used on command, they spend the blue power bar; more points make them
## cheaper, longer, stronger). A node whose prerequisites are not owned shows "?".
const BRANCH_ORDER := ["offense", "sense", "move", "defense"]
const BRANCH := {
	"offense": {"name": "Offense", "col": Color("ff6a4a")},
	"sense": {"name": "Senses", "col": Color("29e6ff")},
	"move": {"name": "Movement", "col": Color("7dff3a")},
	"defense": {"name": "Defense", "col": Color("6aa8ff")},
}
const NODES := [
	{"id": "burst", "branch": "offense", "x": 1, "y": 1.5, "max": 3, "cost": 1, "stage": 1, "req": [], "name": "Jump boost", "desc": "A short burst of speed to catch your next meal. Costs power.", "ability": true},
	{"id": "spit", "branch": "offense", "x": 2, "y": 0.5, "max": 3, "cost": 2, "stage": 1, "req": [["burst", 1]], "name": "Acid spit", "desc": "Spit acid at what is ahead: it slows down. Costs power.", "ability": true},
	{"id": "jaws", "branch": "offense", "x": 2, "y": 2.5, "max": 2, "cost": 2, "stage": 1, "req": [["burst", 1]], "name": "Strong jaws", "desc": "Eat creatures a little bigger than before.", "ability": false},
	{"id": "harpoon", "branch": "offense", "x": 3, "y": 0, "max": 3, "cost": 3, "stage": 2, "req": [["spit", 2]], "name": "Harpoon", "desc": "A venom harpoon: the target weakens and shrinks. Costs power.", "ability": true},
	{"id": "lure", "branch": "offense", "x": 3, "y": 1.5, "max": 3, "cost": 2, "stage": 2, "req": [["spit", 1], ["jaws", 1]], "name": "Lure", "desc": "A glowing appendage unfolds and draws prey toward you. Costs power.", "ability": true},
	{"id": "shock", "branch": "offense", "x": 4, "y": 0.8, "max": 3, "cost": 3, "stage": 2, "req": [["lure", 1], ["harpoon", 1]], "name": "Electric shock", "desc": "A shock stuns every creature nearby. Costs power.", "ability": true},
	{"id": "tentacles", "branch": "offense", "x": 4, "y": 2.6, "max": 1, "cost": 3, "stage": 3, "req": [["jaws", 2], ["lure", 1]], "name": "Tentacles", "desc": "Grow tentacles. They open new options.", "ability": false},
	{"id": "stinger", "branch": "offense", "x": 5, "y": 2.0, "max": 2, "cost": 2, "stage": 3, "req": [["tentacles", 1]], "name": "Stinger tentacle", "desc": "Stinging tips hurt anything that touches you.", "ability": false},
	{"id": "suction", "branch": "offense", "x": 5, "y": 3.0, "max": 3, "cost": 3, "stage": 3, "req": [["tentacles", 1]], "name": "Suction feed", "desc": "Pull small prey in toward your mouth. Costs power.", "ability": true},
	{"id": "grab", "branch": "offense", "x": 6, "y": 2.6, "max": 3, "cost": 3, "stage": 4, "req": [["tentacles", 1], ["stinger", 1]], "name": "Grab tentacles", "desc": "Hold a creature in place and reel it in. Costs power.", "ability": true},
	{"id": "second_eye", "branch": "sense", "x": 1, "y": 5.2, "max": 1, "cost": 1, "stage": 0, "req": [], "name": "Second eye", "desc": "A second eye widens what you can see.", "ability": false},
	{"id": "lens", "branch": "sense", "x": 1, "y": 6.4, "max": 2, "cost": 1, "stage": 0, "req": [], "name": "Better lens", "desc": "Less blurry vision.", "ability": false},
	{"id": "night_vision", "branch": "sense", "x": 2, "y": 4.8, "max": 1, "cost": 2, "stage": 1, "req": [["second_eye", 1]], "name": "Night vision", "desc": "You see farther in the dark.", "ability": false},
	{"id": "listening", "branch": "sense", "x": 2, "y": 5.8, "max": 1, "cost": 2, "stage": 1, "req": [["second_eye", 1]], "name": "Listening", "desc": "Hear hunters nearby: arrows point to them.", "ability": false},
	{"id": "chemical", "branch": "sense", "x": 2, "y": 6.9, "max": 1, "cost": 2, "stage": 1, "req": [["lens", 1]], "name": "Chemical sense", "desc": "Smell food and prey just beyond your sight.", "ability": false},
	{"id": "wide_eyes", "branch": "sense", "x": 3, "y": 4.8, "max": 1, "cost": 3, "stage": 2, "req": [["night_vision", 1]], "name": "Wide eyes", "desc": "You can see the whole screen.", "ability": false},
	{"id": "radar", "branch": "sense", "x": 3, "y": 5.7, "max": 1, "cost": 3, "stage": 3, "req": [["listening", 1]], "name": "Threat radar", "desc": "Hunter arrows reach farther and show how big they are.", "ability": false},
	{"id": "sonar", "branch": "sense", "x": 3, "y": 6.8, "max": 3, "cost": 3, "stage": 2, "req": [["listening", 1], ["chemical", 1]], "name": "Sonar", "desc": "Send a ping: every creature around lights up for a while. Costs power.", "ability": true},
	{"id": "real_eyes", "branch": "sense", "x": 4, "y": 5.3, "max": 1, "cost": 4, "stage": 3, "req": [["lens", 2], ["night_vision", 1]], "name": "Real eyes", "desc": "Camera-like eyes: perfectly sharp vision.", "ability": false},
	{"id": "tail", "branch": "move", "x": 1, "y": 8.0, "max": 2, "cost": 1, "stage": 0, "req": [], "name": "Longer tail", "desc": "A longer tail pushes you faster.", "ability": false},
	{"id": "fins", "branch": "move", "x": 2, "y": 7.6, "max": 2, "cost": 2, "stage": 1, "req": [["tail", 1]], "name": "Fins", "desc": "Fins make you faster.", "ability": false},
	{"id": "flagella", "branch": "move", "x": 2, "y": 8.8, "max": 1, "cost": 3, "stage": 2, "req": [["tail", 2]], "name": "Flagella", "desc": "A second whip drives you forward.", "ability": false},
	{"id": "streamlined", "branch": "move", "x": 3, "y": 7.6, "max": 1, "cost": 3, "stage": 2, "req": [["fins", 1], ["flagella", 1]], "name": "Streamlined body", "desc": "Less drag: a higher top speed.", "ability": false},
	{"id": "cilia", "branch": "move", "x": 3, "y": 8.8, "max": 1, "cost": 4, "stage": 3, "req": [["flagella", 1]], "name": "Cilia coat", "desc": "Tiny paddles all around. Top speed.", "ability": false},
	{"id": "meal_heal", "branch": "defense", "x": 1, "y": 11.0, "max": 3, "cost": 1, "stage": 0, "req": [], "name": "Nutrient store", "desc": "Heal 1 HP with each meal.", "ability": false},
	{"id": "membrane", "branch": "defense", "x": 2, "y": 10.0, "max": 3, "cost": 2, "stage": 1, "req": [["meal_heal", 1]], "name": "Tough membrane", "desc": "More maximum health.", "ability": false},
	{"id": "tox_res", "branch": "defense", "x": 2, "y": 11.4, "max": 2, "cost": 2, "stage": 1, "req": [["meal_heal", 1]], "name": "Toxin resistance", "desc": "Poison ailments wear off much faster.", "ability": false},
	{"id": "regen", "branch": "defense", "x": 2, "y": 12.8, "max": 3, "cost": 3, "stage": 2, "req": [["meal_heal", 2]], "name": "Regeneration", "desc": "You heal faster on your own.", "ability": false},
	{"id": "spikes", "branch": "defense", "x": 3, "y": 10.0, "max": 2, "cost": 2, "stage": 2, "req": [["membrane", 1]], "name": "Spikes", "desc": "Bites hurt you less.", "ability": false},
	{"id": "warning", "branch": "defense", "x": 3, "y": 11.0, "max": 2, "cost": 2, "stage": 1, "req": [["membrane", 1]], "name": "Warning colors", "desc": "Hunters hesitate before they attack.", "ability": false},
	{"id": "slime", "branch": "defense", "x": 3, "y": 12.0, "max": 1, "cost": 3, "stage": 2, "req": [["tox_res", 1]], "name": "Slime", "desc": "Slime clogs the jaws: biters slow down.", "ability": false},
	{"id": "ink", "branch": "defense", "x": 3, "y": 13.2, "max": 3, "cost": 2, "stage": 2, "req": [["regen", 1]], "name": "Ink cloud", "desc": "Release a cloud: hunters inside it lose you. Costs power.", "ability": true},
	{"id": "shell", "branch": "defense", "x": 4, "y": 10.0, "max": 1, "cost": 3, "stage": 3, "req": [["membrane", 3], ["spikes", 1]], "name": "Shell", "desc": "A hard shell: bites hurt much less.", "ability": false},
	{"id": "poison_skin", "branch": "defense", "x": 4, "y": 11.0, "max": 1, "cost": 3, "stage": 3, "req": [["spikes", 1], ["warning", 1]], "name": "Poison skin", "desc": "Whoever bites you gets sick and shrinks.", "ability": false},
	{"id": "camo", "branch": "defense", "x": 4, "y": 12.2, "max": 3, "cost": 3, "stage": 2, "req": [["warning", 1], ["slime", 1]], "name": "Camouflage", "desc": "Blend in: hunters barely notice you for a while. Costs power.", "ability": true},
	{"id": "decoy", "branch": "defense", "x": 4, "y": 13.4, "max": 3, "cost": 3, "stage": 2, "req": [["ink", 1]], "name": "Decoy clone", "desc": "Leave a copy of yourself: hunters chase it while you swim away. Costs power.", "ability": true},
	{"id": "spine", "branch": "defense", "x": 5, "y": 10.5, "max": 3, "cost": 3, "stage": 2, "req": [["spikes", 2]], "name": "Spine burst", "desc": "Fire your spines: nearby creatures are stunned. Costs power.", "ability": true},
	{"id": "limb", "branch": "defense", "x": 5, "y": 13.0, "max": 1, "cost": 3, "stage": 3, "req": [["regen", 2], ["decoy", 1]], "name": "Drop a limb", "desc": "Sacrifice a limb: hunters grab it and you escape. Costs health and lots of power.", "ability": true},
]

## The actives, in the order they are offered. cost = power points (of POWER_MAX), time = seconds of
## effect (0 = instant), radius = world units. kind: "off" fits the offensive button, "def" the defensive
## one; the 3rd and 4th buttons (later in the game) take either.
const ABILITIES := {
	"burst": {"name": "Jump boost", "kind": "off", "cost": 35.0, "time": 0.6},
	"spit": {"name": "Acid spit", "kind": "off", "cost": 25.0, "time": 4.0},
	"harpoon": {"name": "Harpoon", "kind": "off", "cost": 35.0, "time": 6.0},
	"shock": {"name": "Electric shock", "kind": "off", "cost": 45.0, "time": 3.0, "radius": 420.0},
	"lure": {"name": "Lure", "kind": "off", "cost": 30.0, "time": 8.0, "radius": 650.0},
	"suction": {"name": "Suction feed", "kind": "off", "cost": 30.0, "time": 2.5, "radius": 380.0},
	"grab": {"name": "Grab tentacles", "kind": "off", "cost": 35.0, "time": 3.0, "radius": 320.0},
	"spine": {"name": "Spine burst", "kind": "def", "cost": 40.0, "time": 2.5, "radius": 280.0},
	"ink": {"name": "Ink cloud", "kind": "def", "cost": 40.0, "time": 6.0, "radius": 280.0},
	"camo": {"name": "Camouflage", "kind": "def", "cost": 30.0, "time": 8.0},
	"decoy": {"name": "Decoy clone", "kind": "def", "cost": 40.0, "time": 6.0},
	"limb": {"name": "Drop a limb", "kind": "def", "cost": 70.0, "time": 3.0, "radius": 700.0},
	"sonar": {"name": "Sonar", "kind": "def", "cost": 25.0, "time": 4.0, "radius": 1100.0},
}
const ABILITY_ORDER := ["burst", "spit", "harpoon", "shock", "lure", "suction", "grab", "spine", "ink", "camo", "decoy", "limb", "sonar"]
const POWER_MAX := 100.0
## The ability buttons on the right: 1 offensive, 1 defensive, then two open ones that arrive later
## (growth stage needed).
const SLOT_TYPE := ["off", "def", "any", "any"]
const SLOT_STAGE := [0, 0, 3, 4]

## Special traits that only rare creatures give (not on the tree).
const SPECIALS := [
	{"id": "magnet", "name": "Food magnet", "desc": "Food drifts toward you."},
	{"id": "armor", "name": "Armor plating", "desc": "Take less damage."},
	{"id": "photo", "name": "Photosynthesis", "desc": "You slowly grow in the light."},
]

## Poisonous meals. Each lasts `time` seconds.
const AILMENTS := {
	"glow": {"name": "Glow", "desc": "You glow: bigger creatures notice you from farther away.", "time": 25.0},
	"brittle": {"name": "Brittle", "desc": "You take more damage.", "time": 25.0},
	"appetite": {"name": "Bottomless appetite", "desc": "Eating only counts half.", "time": 25.0},
	"slow_heal": {"name": "Slow healing", "desc": "You heal slowly.", "time": 25.0},
}
const AILMENT_ORDER := ["glow", "brittle", "appetite", "slow_heal"]

static func species_of(id: String) -> Dictionary:
	for s in SPECIES:
		if s.id == id:
			return s
	return SPECIES[0]

## The ordinary species of a role (the two creatures that carry a trait are spawned on their own).
static func species_by_role(role: String) -> Array:
	var out: Array = []
	for s in SPECIES:
		if s.role == role and not s.has("trait"):
			out.append(s)
	return out

static func node_of(id: String) -> Dictionary:
	for n in NODES:
		if n.id == id:
			return n
	return {}
