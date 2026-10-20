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
const BLUR := [2.6, 1.5, 0.6]

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
	{"id": "toxin", "name": "Toxic spore", "shape": "spiky", "role": "toxic", "col": Color("c8e03a")},
	{"id": "gold", "name": "Golden spore", "shape": "spiky", "role": "rare", "col": Color("ffd23f")},
]

## Mass of a spawn relative to yours: [low, high] by role.
const MASS_RANGE := {
	"prey": [0.25, 0.8], "equal": [0.88, 1.1], "hunter": [1.3, 2.6], "toxic": [0.4, 0.8], "rare": [0.15, 0.3],
}

## Branch order on the tree screen.
const BRANCHES := ["move", "sense", "defense", "offense"]

## The evolution tree. `after`: the node that must be owned first; `stage`: the
## growth stage (engine STAGES index) you must have reached. Until a node is
## available the tree shows a "?" instead of its name. Nodes with `"ability"` are
## actives: used on command, they spend the blue power bar; the "<id>2" node is their
## upgrade (cheaper, longer, stronger).
const TREE := {
	"move": {"name": "Movement", "nodes": [
		{"id": "tail2", "name": "Longer tail", "desc": "A longer tail pushes you faster.", "cost": 1, "stage": 0, "after": ""},
		{"id": "tail3", "name": "Strong tail", "desc": "More muscle in the tail.", "cost": 2, "stage": 1, "after": "tail2"},
		{"id": "fins", "name": "Fins", "desc": "Fins make you faster.", "cost": 2, "stage": 1, "after": "tail2"},
		{"id": "flagella", "name": "Flagella", "desc": "A second whip drives you forward.", "cost": 3, "stage": 2, "after": "tail3"},
		{"id": "streamlined", "name": "Streamlined body", "desc": "Less drag: a higher top speed.", "cost": 3, "stage": 2, "after": "fins"},
		{"id": "cilia", "name": "Cilia coat", "desc": "Tiny paddles all around. Top speed.", "cost": 4, "stage": 3, "after": "flagella"},
	]},
	"sense": {"name": "Senses", "nodes": [
		{"id": "second_eye", "name": "Second eye", "desc": "A second eye widens what you can see.", "cost": 1, "stage": 0, "after": ""},
		{"id": "sharp1", "name": "Better lens", "desc": "Less blurry vision.", "cost": 1, "stage": 0, "after": ""},
		{"id": "chemical", "name": "Chemical sense", "desc": "Smell food and prey just beyond your sight.", "cost": 2, "stage": 1, "after": "sharp1"},
		{"id": "wide_eyes", "name": "Wide eyes", "desc": "You can see the whole screen.", "cost": 3, "stage": 2, "after": "second_eye"},
		{"id": "sharp2", "name": "Sharp lens", "desc": "Crisp vision.", "cost": 3, "stage": 2, "after": "sharp1"},
		{"id": "listening", "name": "Listening", "desc": "Hear hunters nearby: arrows point to them.", "cost": 2, "stage": 1, "after": "second_eye"},
		{"id": "radar", "name": "Threat radar", "desc": "Hunter arrows reach farther and show how big they are.", "cost": 3, "stage": 3, "after": "listening"},
	]},
	"defense": {"name": "Defense", "nodes": [
		{"id": "meal_heal", "name": "Nutrient store", "desc": "Heal 1 HP with each meal.", "cost": 1, "stage": 0, "after": ""},
		{"id": "membrane", "name": "Tough membrane", "desc": "More maximum health.", "cost": 2, "stage": 1, "after": "meal_heal"},
		{"id": "regen", "name": "Regeneration", "desc": "You heal faster on your own.", "cost": 3, "stage": 2, "after": "meal_heal"},
		{"id": "spikes", "name": "Spikes", "desc": "Bites hurt you less.", "cost": 3, "stage": 2, "after": "membrane"},
		{"id": "warning", "name": "Warning colors", "desc": "Hunters hesitate before they attack.", "cost": 2, "stage": 1, "after": "membrane"},
		{"id": "poison_skin", "name": "Poison skin", "desc": "Whoever bites you gets sick and shrinks.", "cost": 3, "stage": 3, "after": "spikes"},
		{"id": "tox_res", "name": "Toxin resistance", "desc": "Poison ailments wear off much faster.", "cost": 2, "stage": 2, "after": "meal_heal"},
		{"id": "ink", "name": "Ink cloud", "desc": "Release a cloud: hunters inside it lose you. Costs power.", "cost": 2, "stage": 2, "after": "", "ability": true},
		{"id": "ink2", "name": "Thick ink", "desc": "Ink: bigger, longer, cheaper.", "cost": 2, "stage": 3, "after": "ink"},
		{"id": "camo", "name": "Camouflage", "desc": "Blend in: hunters barely notice you for a while. Costs power.", "cost": 3, "stage": 2, "after": "", "ability": true},
		{"id": "camo2", "name": "Perfect camouflage", "desc": "Camouflage: longer and cheaper.", "cost": 3, "stage": 3, "after": "camo"},
		{"id": "spine", "name": "Spine burst", "desc": "Fire your spines: nearby creatures are stunned. Costs power.", "cost": 3, "stage": 2, "after": "spikes", "ability": true},
		{"id": "spine2", "name": "Spine storm", "desc": "Spine burst: wider, longer stun, cheaper.", "cost": 3, "stage": 3, "after": "spine"},
	]},
	"offense": {"name": "Offense", "nodes": [
		{"id": "burst", "name": "Jump boost", "desc": "A short burst of speed to catch your next meal. Costs power.", "cost": 1, "stage": 1, "after": "", "ability": true},
		{"id": "burst2", "name": "Boost II", "desc": "Jump boost: longer and cheaper.", "cost": 2, "stage": 2, "after": "burst"},
		{"id": "jaws", "name": "Strong jaws", "desc": "Eat creatures a little bigger than before.", "cost": 2, "stage": 1, "after": ""},
		{"id": "jaws2", "name": "Crushing jaws", "desc": "Eat even bigger creatures.", "cost": 3, "stage": 3, "after": "jaws"},
		{"id": "spit", "name": "Acid spit", "desc": "Spit acid at what is ahead: it slows down. Costs power.", "cost": 2, "stage": 1, "after": "", "ability": true},
		{"id": "spit2", "name": "Strong acid", "desc": "Acid spit: slows longer, cheaper.", "cost": 2, "stage": 2, "after": "spit"},
		{"id": "lure", "name": "Lure", "desc": "A glowing appendage unfolds and draws prey toward you. Costs power.", "cost": 2, "stage": 1, "after": "", "ability": true},
		{"id": "lure2", "name": "Bright lure", "desc": "Lure: longer, wider, cheaper.", "cost": 2, "stage": 2, "after": "lure"},
		{"id": "shock", "name": "Electric shock", "desc": "A shock stuns every creature nearby. Costs power.", "cost": 3, "stage": 2, "after": "", "ability": true},
		{"id": "shock2", "name": "Strong shock", "desc": "Electric shock: wider, longer stun, cheaper.", "cost": 3, "stage": 3, "after": "shock"},
	]},
}

## The actives, in the order their buttons appear. cost = power points (of POWER_MAX),
## time = seconds of effect (0 = instant), radius = world units.
const ABILITIES := {
	"burst": {"name": "Jump boost", "cost": 35.0, "time": 0.6},
	"spit": {"name": "Acid spit", "cost": 25.0, "time": 4.0},
	"shock": {"name": "Electric shock", "cost": 45.0, "time": 3.0, "radius": 420.0},
	"spine": {"name": "Spine burst", "cost": 40.0, "time": 2.5, "radius": 280.0},
	"lure": {"name": "Lure", "cost": 30.0, "time": 8.0, "radius": 650.0},
	"ink": {"name": "Ink cloud", "cost": 40.0, "time": 6.0, "radius": 280.0},
	"camo": {"name": "Camouflage", "cost": 30.0, "time": 8.0},
}
const ABILITY_ORDER := ["burst", "spit", "shock", "spine", "lure", "ink", "camo"]
const POWER_MAX := 100.0

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

static func species_by_role(role: String) -> Array:
	var out: Array = []
	for s in SPECIES:
		if s.role == role:
			out.append(s)
	return out

static func node_of(id: String) -> Dictionary:
	for b in BRANCHES:
		for n in TREE[b].nodes:
			if n.id == id:
				return n
	return {}
