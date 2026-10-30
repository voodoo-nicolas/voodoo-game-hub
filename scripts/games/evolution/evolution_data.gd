extends RefCounted

## Evolution: the lookup tables (colours, difficulty, creatures, evolution tree,
## ailments, vision rings). No logic here; the engine and the screens read it.

## Primary colour choices on the setup screen: [English name, colour].
const COLORS := [
	["Cyan", Color("29e6ff")], ["Lime", Color("7dff3a")], ["Pink", Color("ff4f9a")], ["Gold", Color("ffd23f")],
	["Violet", Color("b57dff")], ["Orange", Color("ff9f43")], ["Sky", Color("5aa8ff")], ["White", Color("e6f0ff")],
]

## hunters: share of spawns that hunt you; bite: damage per second of contact;
## regen: multiplier on natural healing; speed: hunter speed vs your top speed;
## chasers: at most this many creatures chase you at once (the nearest ones); hunter_max: at most this many
## creatures that can eat you are around you (no more spawn); env: damage from water too cold or too deep.
const DIFFICULTY := {
	"easy": {"hunters": 0.10, "bite": 1.2, "regen": 1.5, "speed": 0.78, "chasers": 2, "hunter_max": 4, "env": 0.6},
	"normal": {"hunters": 0.20, "bite": 2.0, "regen": 1.0, "speed": 0.88, "chasers": 3, "hunter_max": 6, "env": 1.0},
	"hard": {"hunters": 0.30, "bite": 3.0, "regen": 0.7, "speed": 0.98, "chasers": 4, "hunter_max": 8, "env": 1.3, "slow": 4.0},
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

## Growing (owner 2026-10-29, Evolution phase 2): kills it takes to grow from each size to the next (index =
## size - 1), counting prey one size below you (worth size - 1; at size 1 the smallest dots, worth 1). The xp is
## kills x that worth (engine `xp_span`): 520, 1150, 1760, 2790, 3280, 9500, 13800, 21000, 64000. 19,500 kills to size 10 (owner 2026-10-29 "size 2 should take 10 minutes, size 3 another 20, size 4 another 30": sized from a greedy bot earning ~1 xp/s at sizes 1-5, so about 10 / 20 / 30 / 40 / 50 min for sizes 1-5, then longer);
## creatures your own size are worth more, so real runs are a little quicker. Size 1 -> 2 stays 30: tail at 5,
## eye at 12, then eat to size 2 (owner 2026-10-24). (Before: 30 xp, 50 xp, then x1.5 each: ~500 kills; then [30,40,60,80,110,150,200,260,340] = 1,270.)
const XP_KILLS := [520, 1150, 880, 930, 820, 1900, 2300, 3000, 8000]

## DNA earned while growing from each size to the next, ONE point at a time: what you eat fills the 🧬 bar and
## each full bar is +1 (owner 2026-10-29: "you should never earn more than 1 or 2 dna points at a time, except
## when eating rare creatures"; "52 dna lands all at once... seems VERY wrong"). About 1 point every 3 kills at
## size 2, every 10 kills at size 9. Growing to size 2 opens the tree with TREE_DNA. 196 by size 10, plus
## missions (+1) and rare creatures (+2 to +8): about 230. Past size 10, 1 point every DNA_PAST_10_KILLS kills.
## (Before, LEVEL_DNA paid each new size at once: [0, 52, 27, 26, 26, 26, 26, 27, 26, 26], the whole 262-DNA
## tree by size 10. Owner 2026-10-29: the tree will hold 300+ and no run gets all of it: phase 4.)
const DNA_PER_SIZE := [0, 12, 16, 20, 24, 28, 30, 32, 34]
const TREE_DNA := 2
const DNA_PAST_10_KILLS := 10.0

## Speed multiplier by movement rank (0 = jolting, no tail). Owner 2026-10-29 "the swimming needs to seem fast,
## agile": the first tail starts at 0.8 (was 0.55), the top stays 1.15. Hunters and fleeing prey scale with your
## top speed, so the chase balance holds. (Before: [0.0, 0.55, 0.72, 0.88, 1.02, 1.15].)
const MOVE_MULT := [0.0, 0.8, 0.9, 1.0, 1.08, 1.15]

## Creatures. Sizes are absolute (`mass`), so as you grow they shrink next to you. `tier` is the player
## size level from which a species can appear (prey: its own size; hunters: one size earlier, so they are
## ahead of you). `until` = the biggest player size that still meets it: single cells and viruses stop at
## size 3 (they stopped at 4 before 2026-10-24), so from size 4 on only animals swim around you. By your size
## (owner 2026-10-24): 1-3 bacteria and viruses, 3-6 fish, 5-10 all sorts (squid, octopus, jellyfish, whales,
## pufferfish ...), 9-10 sea monsters (Leviathan, Kraken, Sea serpent, Abyss maw). Look by size: cells (sizes 1-2) have cell
## parts, viruses and bacteria are plain, from size 3 on the creatures are fish, jellyfish, squid, rays and
## snakes with fins, teeth, tentacles and spines; the bigger, the more of them. `flee` = share of the
## species that swim away from something that can eat them. role: prey (grazer), hunter (eats you if it is
## bigger), toxic (poisonous), rare (gives a trait). `feats` are extra body parts the art draws on cells: tail,
## fins, arms, cilia, eye. `shape` is drawn by evolution_art.gd; the animals carry `fish` = their body plan
## (see `Art._fish`, `_jelly`, `_squid`, `_ray`, `_snake`, `_octopus`, `_turtle`; the rare ones `_star`,
## `_seahorse`, `_merfolk`).
## `adv` (toxic and rare ones, which are sized relative to you): the animal they turn into once they are
## size 3 or bigger, so a size 8 player never meets a giant bacterium. It has its own name.
const SPECIES := [
	{"id": "coccus", "name": "Coccus", "shape": "beads", "role": "prey", "col": Color("9bd34a"), "mass": [2.0, 4.0], "tier": 1, "until": 3, "flee": 0.0, "feats": []},
	{"id": "bacillus", "name": "Bacillus", "shape": "rod", "role": "prey", "col": Color("4fb3e8"), "mass": [3.0, 6.0], "tier": 1, "until": 3, "flee": 0.0, "feats": []},
	{"id": "amoeba", "name": "Amoeba", "shape": "blob", "role": "prey", "col": Color("d9c27a"), "mass": [5.0, 9.0], "tier": 1, "until": 3, "flee": 0.0, "feats": []},
	{"id": "strepto", "name": "Strep chain", "shape": "chain", "role": "prey", "col": Color("7a8cff"), "mass": [7.0, 13.0], "tier": 2, "until": 3, "flee": 0.4, "feats": []},
	{"id": "spirillum", "name": "Spirillum", "shape": "spiral", "role": "prey", "col": Color("5fd0b0"), "mass": [8.0, 15.0], "tier": 2, "until": 3, "flee": 0.5, "feats": ["tail"]},
	{"id": "ciliate", "name": "Ciliate", "shape": "blob", "role": "prey", "col": Color("f08fb0"), "mass": [10.0, 18.0], "tier": 2, "until": 3, "flee": 0.5, "feats": ["cilia"]},
	{"id": "herpes", "name": "Herpes", "shape": "spiky", "role": "prey", "col": Color("e6b84a"), "mass": [16.0, 30.0], "tier": 3, "until": 3, "flee": 0.6, "feats": []},
	{"id": "papilloma", "name": "Papilloma", "shape": "bumpy", "role": "prey", "col": Color("a35dd8"), "mass": [18.0, 34.0], "tier": 3, "until": 3, "flee": 0.4, "feats": []},
	{"id": "zika", "name": "Zika", "shape": "bumpy", "role": "prey", "col": Color("e8693a"), "mass": [20.0, 36.0], "tier": 3, "until": 3, "flee": 0.5, "feats": []},
	{"id": "swimmer", "name": "Swimmer", "shape": "rod", "role": "prey", "col": Color("6ad4ff"), "mass": [14.0, 26.0], "tier": 3, "until": 3, "flee": 0.8, "feats": ["tail", "fins"]},
	{"id": "corona", "name": "Corona", "shape": "corona", "role": "hunter", "col": Color("e0405a"), "mass": [40.0, 75.0], "tier": 3, "until": 3, "flee": 1.0, "feats": []},
	{"id": "ebola", "name": "Ebola", "shape": "worm", "role": "hunter", "col": Color("e0405a"), "mass": [45.0, 90.0], "tier": 3, "until": 3, "flee": 1.0, "feats": []},
	{"id": "phage", "name": "Phage", "shape": "phage", "role": "hunter", "col": Color("e0603a"), "mass": [50.0, 100.0], "tier": 3, "until": 3, "flee": 1.0, "feats": []},
	{"id": "rota", "name": "Rotavirus", "shape": "spiky", "role": "hunter", "col": Color("78c43a"), "mass": [40.0, 80.0], "tier": 3, "until": 3, "flee": 1.0, "feats": []},
	# From here on: animals. Prey first (by size), then hunters.
	{"id": "guppy", "name": "Guppy", "shape": "fish", "role": "prey", "col": Color("ff9fd0"), "mass": [24.0, 46.0], "tier": 3, "flee": 0.6, "feats": [],
		"fish": {"len": 1.3, "hgt": 0.55, "tail": "fan", "spots": true}},
	{"id": "perch", "name": "Perch", "shape": "fish", "role": "hunter", "col": Color("9ab84a"), "mass": [45.0, 90.0], "tier": 3, "flee": 1.0, "feats": [],
		"fish": {"len": 1.45, "hgt": 0.55, "tail": "fork", "teeth": true, "stripes": true, "dorsal": 1}},
	{"id": "fry", "name": "Fry", "shape": "fish", "role": "prey", "col": Color("8fd8ff"), "mass": [28.0, 50.0], "tier": 3, "flee": 0.7, "feats": [],
		"fish": {"len": 1.35, "hgt": 0.5, "tail": "fork"}},
	{"id": "jelly", "name": "Jellyfish", "shape": "jelly", "role": "prey", "col": Color("c9a8ff"), "mass": [60.0, 115.0], "tier": 5, "flee": 0.7, "feats": [],
		"fish": {"arms": 6}},
	{"id": "darter", "name": "Darter", "shape": "fish", "role": "prey", "col": Color("ffd06a"), "mass": [65.0, 120.0], "tier": 4, "flee": 0.8, "feats": [],
		"fish": {"len": 1.5, "hgt": 0.42, "tail": "fork", "stripes": true, "pect": true}},
	{"id": "plated", "name": "Plated fish", "shape": "fish", "role": "prey", "col": Color("8fb0a0"), "mass": [80.0, 130.0], "tier": 4, "flee": 0.6, "feats": [],
		"fish": {"len": 1.3, "hgt": 0.6, "tail": "fan", "plates": true, "pect": true}},
	{"id": "silverfin", "name": "Silverfin", "shape": "fish", "role": "prey", "col": Color("c8d8e8"), "mass": [140.0, 240.0], "tier": 5, "flee": 0.8, "feats": [],
		"fish": {"len": 1.55, "hgt": 0.5, "tail": "fork", "pect": true, "dorsal": 1, "barbels": 2}},
	{"id": "puffer", "name": "Pufferfish", "shape": "fish", "role": "prey", "col": Color("e8c36a"), "mass": [150.0, 260.0], "tier": 5, "flee": 0.5, "feats": [],
		"fish": {"len": 1.05, "hgt": 0.9, "tail": "fan", "round": true, "spines": 9, "pect": true}},
	{"id": "bluefin", "name": "Bluefin", "shape": "fish", "role": "prey", "col": Color("4f8fe0"), "mass": [300.0, 520.0], "tier": 6, "flee": 0.8, "feats": [],
		"fish": {"len": 1.7, "hgt": 0.55, "tail": "fork", "pect": true, "dorsal": 2, "stripes": true}},
	{"id": "lionfish", "name": "Lionfish", "shape": "fish", "role": "prey", "col": Color("e0705a"), "mass": [330.0, 540.0], "tier": 6, "flee": 0.5, "feats": [],
		"fish": {"len": 1.35, "hgt": 0.55, "tail": "fan", "stripes": true, "fans": true, "barbels": 2}},
	{"id": "beluga", "name": "Beluga", "shape": "fish", "role": "prey", "col": Color("dde8f0"), "mass": [640.0, 1100.0], "tier": 7, "flee": 0.6, "feats": [],
		"fish": {"len": 1.7, "hgt": 0.55, "tail": "fluke", "pect": true}},
	{"id": "orca", "name": "Orca", "shape": "fish", "role": "hunter", "col": Color("56627a"), "mass": [1250.0, 2300.0], "tier": 7, "flee": 1.0, "feats": [],
		"fish": {"len": 1.85, "hgt": 0.58, "tail": "fluke", "teeth": true, "pect": true, "dorsal": 1, "spots": true}},
	{"id": "sunfish", "name": "Sunfish", "shape": "fish", "role": "prey", "col": Color("b8c8d8"), "mass": [600.0, 1000.0], "tier": 7, "flee": 0.6, "feats": [],
		"fish": {"len": 1.15, "hgt": 1.0, "tail": "fan", "round": true, "pect": true, "dorsal": 2, "glow": true}},
	{"id": "swordfish", "name": "Swordfish", "shape": "fish", "role": "prey", "col": Color("5aa0c8"), "mass": [620.0, 1050.0], "tier": 7, "flee": 0.8, "feats": [],
		"fish": {"len": 1.8, "hgt": 0.45, "tail": "fork", "pect": true, "dorsal": 2, "sword": true}},
	{"id": "manta", "name": "Manta", "shape": "ray", "role": "prey", "col": Color("6a8fc8"), "mass": [1250.0, 2200.0], "tier": 8, "flee": 0.6, "feats": [],
		"fish": {"horns": true, "span": 1.9}},
	{"id": "grouper", "name": "Giant grouper", "shape": "fish", "role": "prey", "col": Color("a88a5a"), "mass": [1300.0, 2200.0], "tier": 8, "flee": 0.5, "feats": [],
		"fish": {"len": 1.45, "hgt": 0.75, "tail": "fan", "plates": true, "pect": true, "dorsal": 2, "barbels": 4, "glow": true}},
	{"id": "whaleshark", "name": "Whale shark", "shape": "fish", "role": "prey", "col": Color("5a7a9a"), "mass": [2500.0, 4600.0], "tier": 9, "flee": 0.4, "feats": [],
		"fish": {"len": 1.9, "hgt": 0.6, "tail": "fork", "pect": true, "dorsal": 2, "spots": true, "glow": true}},
	{"id": "bluewhale", "name": "Blue whale", "shape": "fish", "role": "prey", "col": Color("3f6fb0"), "mass": [5000.0, 8500.0], "tier": 10, "flee": 0.3, "feats": [],
		"fish": {"len": 2.0, "hgt": 0.6, "tail": "fluke", "pect": true, "dorsal": 1, "stripes": true}},
	{"id": "hydra", "name": "Squid", "shape": "squid", "role": "hunter", "col": Color("e0527a"), "mass": [120.0, 220.0], "tier": 5, "flee": 1.0, "feats": [],
		"fish": {"arms": 8, "long": 2}},
	{"id": "ray", "name": "Stingray", "shape": "ray", "role": "hunter", "col": Color("e0705a"), "mass": [150.0, 260.0], "tier": 4, "flee": 1.0, "feats": [],
		"fish": {"sting": true, "span": 1.5}},
	{"id": "barracuda", "name": "Barracuda", "shape": "fish", "role": "hunter", "col": Color("9aa8b8"), "mass": [160.0, 270.0], "tier": 4, "flee": 1.0, "feats": [],
		"fish": {"len": 1.8, "hgt": 0.38, "tail": "fork", "teeth": true, "pect": true, "dorsal": 1}},
	{"id": "moray", "name": "Moray eel", "shape": "snake", "role": "hunter", "col": Color("7a9a4a"), "mass": [290.0, 520.0], "tier": 5, "flee": 1.0, "feats": [],
		"fish": {"fangs": true, "len": 1.5, "spots": true}},
	{"id": "angler", "name": "Anglerfish", "shape": "fish", "role": "hunter", "col": Color("7a5a9a"), "mass": [300.0, 540.0], "tier": 5, "flee": 1.0, "feats": [],
		"fish": {"len": 1.15, "hgt": 0.85, "tail": "fan", "teeth": true, "lure": true, "pect": true, "spines": 5}},
	{"id": "octopus", "name": "Reef octopus", "shape": "octopus", "role": "hunter", "col": Color("c8603a"), "mass": [560.0, 1000.0], "tier": 6, "flee": 1.0, "feats": [],
		"fish": {"suckers": true, "spots": true}},
	{"id": "shark", "name": "Shark", "shape": "fish", "role": "hunter", "col": Color("7d8ea0"), "mass": [600.0, 1100.0], "tier": 6, "flee": 1.0, "feats": [],
		"fish": {"len": 1.85, "hgt": 0.5, "tail": "fork", "teeth": true, "pect": true, "dorsal": 1, "gills": true}},
	{"id": "seasnake", "name": "Sea snake", "shape": "snake", "role": "hunter", "col": Color("d8c040"), "mass": [1200.0, 2200.0], "tier": 7, "flee": 1.0, "feats": [],
		"fish": {"fangs": true, "len": 1.9, "bands": true, "crest": true}},
	{"id": "greatwhite", "name": "Great white", "shape": "fish", "role": "hunter", "col": Color("90a0b0"), "mass": [1300.0, 2300.0], "tier": 7, "flee": 1.0, "feats": [],
		"fish": {"len": 1.95, "hgt": 0.55, "tail": "fork", "teeth": true, "pect": true, "dorsal": 2, "gills": true, "scars": true}},
	{"id": "giantsquid", "name": "Giant squid", "shape": "squid", "role": "hunter", "col": Color("a03a50"), "mass": [2500.0, 4600.0], "tier": 8, "flee": 1.0, "feats": [],
		"fish": {"arms": 10, "long": 2, "big": true, "suckers": true, "glow": true}},
	{"id": "megalodon", "name": "Megalodon", "shape": "fish", "role": "hunter", "col": Color("6a7a8a"), "mass": [2600.0, 4700.0], "tier": 8, "flee": 1.0, "feats": [],
		"fish": {"len": 2.0, "hgt": 0.62, "tail": "fork", "teeth": true, "pect": true, "dorsal": 2, "gills": true, "scars": true, "glow": true}},
	{"id": "leviathan", "name": "Leviathan", "shape": "snake", "role": "hunter", "col": Color("b03060"), "mass": [5000.0, 8000.0], "tier": 9, "flee": 1.0, "feats": [],
		"fish": {"fangs": true, "len": 2.1, "crest": true, "fins": true, "big": true, "glow": true}},
	# Sea monsters: what lives around you at sizes 9 and 10 (owner 2026-10-24). The kraken used to be a size 6 hunter.
	{"id": "kraken", "name": "Kraken", "shape": "squid", "role": "hunter", "col": Color("c03a6a"), "mass": [3600.0, 7000.0], "tier": 9, "flee": 1.0, "feats": [],
		"fish": {"arms": 10, "long": 2, "big": true, "suckers": true, "glow": true}},
	{"id": "serpent", "name": "Sea serpent", "shape": "snake", "role": "hunter", "col": Color("3fa070"), "mass": [8000.0, 14000.0], "tier": 10, "flee": 1.0, "feats": [],
		"fish": {"fangs": true, "len": 2.2, "crest": true, "fins": true, "big": true, "bands": true, "glow": true}},
	{"id": "maw", "name": "Abyss maw", "shape": "fish", "role": "hunter", "col": Color("5a3a7a"), "mass": [8500.0, 15000.0], "tier": 10, "flee": 1.0, "feats": [],
		"fish": {"len": 1.4, "hgt": 0.9, "tail": "fan", "round": true, "teeth": true, "lure": true, "pect": true, "spines": 7, "glow": true, "scars": true}},
	{"id": "wyrm", "name": "Sea wyrm", "shape": "snake", "role": "prey", "col": Color("4a7ab0"), "mass": [2400.0, 4400.0], "tier": 9, "flee": 0.6, "feats": [],
		"fish": {"len": 2.0, "crest": true, "fins": true, "spots": true, "glow": true}},
	{"id": "titanturtle", "name": "Titan turtle", "shape": "turtle", "role": "prey", "col": Color("6a9a5a"), "mass": [5500.0, 9500.0], "tier": 9, "flee": 0.4, "feats": [],
		"fish": {"big": true}},
	{"id": "tailed", "name": "Flagellate", "shape": "tailed", "role": "prey", "col": Color("ffb35a"), "mass": [3.0, 5.0], "tier": 1, "flee": 0.0, "feats": [], "trait": "tail"},
	{"id": "eyed", "name": "Eyed cell", "shape": "eyed", "role": "prey", "col": Color("e0a3ff"), "mass": [3.0, 5.0], "tier": 1, "flee": 0.0, "feats": [], "trait": "eye"},
	# Toxic creatures: each kind always gives the same ailment (`ailment`), so players learn which to avoid.
	{"id": "toxin", "name": "Toxic spore", "shape": "spiky", "role": "toxic", "col": Color("c8e03a"), "mass": [0.0, 0.0], "tier": 1, "flee": 0.0, "feats": [], "ailment": "brittle",
		"adv": {"name": "Spiny pufferfish", "shape": "fish", "fish": {"len": 1.05, "hgt": 0.9, "tail": "fan", "round": true, "spines": 11, "pect": true}}},
	{"id": "glowspore", "name": "Glow spore", "shape": "bumpy", "role": "toxic", "col": Color("7affe0"), "mass": [0.0, 0.0], "tier": 1, "flee": 0.0, "feats": [], "ailment": "glow",
		"adv": {"name": "Lantern fish", "shape": "fish", "fish": {"len": 1.3, "hgt": 0.7, "tail": "fan", "teeth": true, "lure": true, "pect": true, "glow": true}}},
	{"id": "gutworm", "name": "Gut worm", "shape": "worm", "role": "toxic", "col": Color("e8d84a"), "mass": [0.0, 0.0], "tier": 1, "flee": 0.0, "feats": [], "ailment": "appetite",
		"adv": {"name": "Venom snake", "shape": "snake", "fish": {"fangs": true, "len": 1.7, "bands": true}}},
	{"id": "mold", "name": "Mold spore", "shape": "beads", "role": "toxic", "col": Color("9aa83a"), "mass": [0.0, 0.0], "tier": 1, "flee": 0.0, "feats": [], "ailment": "slow_heal",
		"adv": {"name": "Venom jelly", "shape": "jelly", "fish": {"arms": 8, "glow": true}}},
	# Rare creatures (owner 2026-10-24: "a larger variety ... make them rare!"). `tier` = from which of YOUR sizes it can
	# turn up, `weight` = how often next to the others (the rarer, the lower), `dna` = extra DNA on top of the free trait.
	{"id": "gold", "name": "Golden spore", "shape": "spiky", "role": "rare", "col": Color("ffd23f"), "mass": [0.0, 0.0], "tier": 1, "flee": 1.0, "feats": [], "weight": 6.0, "dna": 0,
		"adv": {"name": "Golden fish", "shape": "fish", "fish": {"len": 1.5, "hgt": 0.55, "tail": "fork", "pect": true, "dorsal": 2, "plates": true, "glow": true}}},
	{"id": "starfish", "name": "Starfish", "shape": "star", "role": "rare", "col": Color("ffa94d"), "mass": [0.0, 0.0], "tier": 3, "flee": 1.0, "feats": [], "weight": 4.0, "dna": 2},
	{"id": "seahorse", "name": "Seahorse", "shape": "seahorse", "role": "rare", "col": Color("ffcf4a"), "mass": [0.0, 0.0], "tier": 3, "flee": 1.0, "feats": [], "weight": 3.0, "dna": 3},
	{"id": "mermaid", "name": "Mermaid", "shape": "mermaid", "role": "rare", "col": Color("3fd0c0"), "mass": [0.0, 0.0], "tier": 5, "flee": 1.0, "feats": [], "weight": 1.5, "dna": 5},
	{"id": "poseidon", "name": "Little Poseidon", "shape": "poseidon", "role": "rare", "col": Color("2fa88a"), "mass": [0.0, 0.0], "tier": 7, "flee": 1.0, "feats": [], "weight": 0.6, "dna": 8},
]

## Toxic and rare creatures are sized relative to you: [low, high] x your mass.
## (Rare ones used to be 0.15-0.3, which made them 3 size levels below you: invisible and worth nothing.)
const MASS_RANGE := {"toxic": [0.4, 0.8], "rare": [0.3, 0.55]}

## How likely a species is to spawn by how many size levels its typical mass is above (+) or below (-) yours.
const LEVEL_WEIGHT := {-2: 1.0, -1: 3.0, 0: 4.0, 1: 3.0, 2: 2.0}
## At most this many creatures of one size level around you at once.
const LEVEL_CAP := 10

## The evolution tree is a graph (like a skill tree): the creature sits at the far left and four
## branches grow to the right. Each node: `req` = every [node, minimum points] that must be owned first
## (some need more than one), `max` = how many points it takes (extra points strengthen it),
## `cost` = DNA for the first point (each further point costs one more), `stage` = growth stage
## (engine STAGES index) needed, x / y = place on the tree screen in grid cells.
## `ability` nodes are actives (used on command, they spend the blue power bar; more points make them
## cheaper, longer, stronger). A node whose prerequisites are not owned shows "?".
const BRANCH_ORDER := ["offense", "sense", "move", "defense", "habitat", "growth", "plan"]
const BRANCH := {
	"offense": {"name": "Offense", "col": Color("ff6a4a")},
	"sense": {"name": "Senses", "col": Color("29e6ff")},
	"move": {"name": "Movement", "col": Color("7dff3a")},
	"defense": {"name": "Defense", "col": Color("6aa8ff")},
	"habitat": {"name": "Habitat", "col": Color("c48bff")},
	"growth": {"name": "Growth", "col": Color("ffd23a")},
	"plan": {"name": "Body plan", "col": Color("ff8fd0")},
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
	# Habitat: where you can live. Cold and depth limits (engine `min_temp` / `max_depth_m`).
	{"id": "cold_tol", "branch": "habitat", "x": 1, "y": 15.0, "max": 3, "cost": 1, "stage": 0, "req": [], "name": "Antifreeze", "desc": "Antifreeze proteins keep your cell from freezing: you can swim in colder water.", "ability": false},
	{"id": "pressure_tol", "branch": "habitat", "x": 1, "y": 16.2, "max": 3, "cost": 1, "stage": 0, "req": [], "name": "Pressure cells", "desc": "Tougher cell walls: you can dive deeper without being crushed.", "ability": false},
	{"id": "blubber", "branch": "habitat", "x": 2, "y": 15.0, "max": 2, "cost": 2, "stage": 2, "req": [["cold_tol", 2]], "name": "Fat layer", "desc": "A layer of fat keeps the cold out: even colder water.", "ability": false},
	{"id": "deep_body", "branch": "habitat", "x": 2, "y": 16.2, "max": 2, "cost": 3, "stage": 2, "req": [["pressure_tol", 2]], "name": "Deep-sea body", "desc": "A body built for the deep: you can dive much deeper.", "ability": false},
	{"id": "abyssal", "branch": "habitat", "x": 3, "y": 15.6, "max": 1, "cost": 4, "stage": 3, "req": [["blubber", 1], ["deep_body", 1]], "name": "Abyss dweller", "desc": "At home in the cold, dark deep: the coldest water and the deepest dives.", "ability": false},
	# Growth (owner 2026-10-29: "a DNA tree branch for the size, where you have to spend a good amount of points to grow"):
	# eating fills the gold bar, but you only reach size 3 and up by buying this. Rank r lets you grow to size 2 + r
	# (engine `size_cap`); 8 ranks = size 10. 6 + 7 + ... + 13 = 76 DNA in all.
	# Body plan (owner 2026-10-29: "a body plan decides which abilities you can even see"): at size 3 pick ONE; the
	# others close, and traits that do not belong to your plan are hidden (NODE_PLANS; no entry = every plan).
	{"id": "plan_marlin", "branch": "plan", "x": 1, "y": 20.0, "max": 1, "cost": 4, "stage": 2, "req": [], "name": "Marlin", "desc": "Built for speed: a spear bill and a sickle tail. Faster than anything, but fragile.", "ability": false, "excl": "plan"},
	{"id": "plan_lionfish", "branch": "plan", "x": 1, "y": 21.2, "max": 1, "cost": 4, "stage": 2, "req": [], "name": "Lionfish", "desc": "Spines all over and venom: biters get hurt. Slow.", "ability": false, "excl": "plan"},
	{"id": "plan_puffer", "branch": "plan", "x": 1, "y": 22.4, "max": 1, "cost": 4, "stage": 2, "req": [], "name": "Pufferfish", "desc": "Looks harmless, until something bites: tough and poisonous. Weak at hunting.", "ability": false, "excl": "plan"},
	{"id": "plan_crab", "branch": "plan", "x": 1, "y": 23.6, "max": 1, "cost": 4, "stage": 2, "req": [], "name": "Crab", "desc": "A heavy shell and claws that grab. Very tough, but slow.", "ability": false, "excl": "plan"},
	{"id": "plan_squid", "branch": "plan", "x": 1, "y": 24.8, "max": 1, "cost": 4, "stage": 2, "req": [], "name": "Squid", "desc": "Tentacles, ink and tricks. Soft body, but hard to catch.", "ability": false, "excl": "plan"},
	{"id": "plan_eel", "branch": "plan", "x": 1, "y": 26.0, "max": 1, "cost": 4, "stage": 2, "req": [], "name": "Eel", "desc": "A long snake-like body with electric shocks. Quick and slippery.", "ability": false, "excl": "plan"},
	{"id": "growth", "branch": "growth", "x": 1, "y": 18.0, "max": 8, "cost": 6, "stage": 0, "req": [], "name": "Growth", "desc": "Your body can grow one size bigger. Without this you stop growing, however much you eat.", "ability": false},
]

## Which body plans may have a trait; a trait that is not listed is open to every plan.
const NODE_PLANS := {
	"spit": ["lionfish", "puffer", "squid"], "jaws": ["marlin", "crab", "eel"], "harpoon": ["marlin", "squid"],
	"lure": ["lionfish", "eel"], "shock": ["eel"], "tentacles": ["squid"], "stinger": ["squid", "lionfish"],
	"suction": ["squid"], "grab": ["squid", "crab"],
	"flagella": ["marlin", "eel", "squid"], "streamlined": ["marlin", "eel"], "cilia": ["puffer", "squid"],
	"spikes": ["lionfish", "puffer", "crab"], "warning": ["lionfish", "puffer"], "slime": ["eel", "puffer", "squid"],
	"ink": ["squid"], "shell": ["crab"], "poison_skin": ["lionfish", "puffer"], "camo": ["squid", "eel"],
	"decoy": ["squid", "eel"], "spine": ["lionfish", "puffer"], "limb": ["crab", "squid"],
}
## Body plan passives: speed and health multipliers.
const PLAN_SPEED := {"marlin": 1.12, "lionfish": 0.92, "puffer": 0.95, "crab": 0.85, "squid": 1.0, "eel": 1.05}
const PLAN_HP := {"marlin": 0.8, "lionfish": 0.95, "puffer": 1.25, "crab": 1.5, "squid": 0.9, "eel": 1.0}

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

## Getting the same ailment again and again teaches your body to resist it: the matching trait comes free,
## one rank at each of these totals (10, then every 20 more), up to 5/5 = immune.
const RESIST_AT := [10, 30, 50, 70, 90]
const RESISTS := {
	"glow": {"name": "Shadow skin", "desc": "The glow fades faster."},
	"brittle": {"name": "Hard cells", "desc": "Brittleness fades faster."},
	"appetite": {"name": "Strong gut", "desc": "The bottomless appetite fades faster."},
	"slow_heal": {"name": "Fast recovery", "desc": "Slow healing fades faster."},
}

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
