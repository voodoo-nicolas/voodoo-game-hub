extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "evolution"
const TITLE := "Evolution"
const GOAL := "Start as a blind one-cell blob and evolve: eat to grow, finish missions for new body parts and DNA, and survive the bigger creatures."
const HOW := [
	"Pick your colours (one main colour and two secondary ones for the tail, fins, spikes, spots and stripes) and difficulty on the setup screen. The game plays sideways on a phone.",
	"Steer with the stick on the left. On a PC use the arrow keys or WASD, Space for the jump boost, Tab for the creature screen.",
	"The pond has no edges. At first your cell can only jerk sideways, and you can only see a small, blurry circle around you.",
	"You must eat. You must not be eaten. Some food will speed up your evolution greatly; some may slow it down.",
	"Missions are on the right, and they turn up as you discover things.",
	"The smallest dots are worth the least; the bigger the creature, the more it is worth. Things far smaller than you are worth nothing.",
	"The red bar is your health, the gold bar your growth. Bigger creatures bite when they touch you; they glow red. If your health runs out the run is over. Different kinds of creature also hunt each other.",
	"Getting the eye opens the evolution tree and gives 2 DNA. After that, everything you eat fills the green 🧬 bar under your growth bar: each time it is full you get 1 DNA. Bigger meals fill it faster. Rare creatures give extra DNA.",
	"Once the tree is open, use the 🧬 screen (middle, next to pause): the game stops while you look. It shows your creature's size, speed, strength and health, and lets you spend DNA on the evolution tree: offense, senses, movement, defense and habitat. A trait shows a ? until you own the traits before it.",
	"Creatures that can eat you glow red. Toxic ones glow yellow-green, and each kind always causes the same ailment: spiky spores make you brittle, glow spores make you glow, gut worms give a bottomless appetite, mold spores slow your healing. A bar under your health shows how long the ailment lasts.",
	"Get the same ailment often enough and your body learns to resist it, for free: 10 times for 1/5, then every 20 more, up to 5/5 (immune). The 🧬 screen shows how far you are.",
	"Rare creatures glow gold, shimmer and send ripples through the water, even just past what you can see. Eat one for a free trait. The bigger you are, the more kinds turn up, and the rarest ones also give DNA.",
	"Bosses: at sizes 3, 5, 7, 8 and 10 something huge comes for you (\"Something huge is stirring…\"), always in the same order: Old Snapjaw, Lantern Mother, Ironclaw, the Grey Kraken and the Hollow Leviathan. Its name and health bar show at the top.",
	"To fight a boss, swim into it to bite it: each bite chips its health bar and pushes you back off it. Watch for its warning (a glowing snout, a flaring lure, a raised claw, rearing tentacles, a deep breath) and get out of the way. After its attack it is dizzy (stars over its head): bite it then for double. Shocks stun it too, and acid and harpoons hurt it from afar.",
	"Swim far away from a boss and it gives up, then comes back later. Beat one for a big lump of DNA (15 to 40). In Normal, dying sends it away for a while.",
	"Under your health bar: your depth and the water temperature, with the limits your body can take. Water that is too cold slows you down and hurts; too deep, the pressure hurts. The Habitat branch (Antifreeze, Pressure cells and more) lets you swim colder and deeper.",
	"When you die (setup screen): Normal brings you back at the start of your size with everything you evolved. Hardcore gives you one life, is harder than Hard whichever difficulty you tap, and has its own badges for each size you reach.",
	"Nothing is saved mid-run, so there is no Resume: every run starts as a tiny cell.",
]
const TIPS := [
	"Eat while the big creatures are far away; grow first, hunt later.",
	"Hunters are a little slower than your top speed. Keep moving and they can't catch you. The jump boost gets you out of trouble.",
	"Upgrade your senses early: seeing a hunter coming is half of surviving it.",
	"Only the nearest few hunters chase you at once (2 on Easy, 3 on Normal, 4 on Hard), and only so many are around.",
	"Bosses: never bite them head-on unless they are dizzy. Old Snapjaw's snout jabs back and Ironclaw's shell blocks you: go round the side.",
	"Toxic creatures are tempting: a glow makes hunters notice you, brittle makes bites hurt more. Wait out the ailment somewhere quiet.",
]
const STATS := ["Best score", "Biggest size", "Cells eaten", "Rare eaten", "Food eaten", "Distance swum (m)", "Missions done", "Games played"]

## Badges (achievements.gd): they unlock when the stat reaches `at`. Stats are lifetime totals ("Distance swum (m)":
## 10 world units = 1 m) or records ("Biggest size", "Top speed" = % of the best possible swimming speed).
const ACHIEVEMENTS := [
	{"id": "first_bite", "icon": "🦠", "title": "First bite", "desc": "Eat a creature", "key": "Cells eaten", "at": 1, "xp": 10},
	{"id": "eat100", "icon": "🍽️", "title": "Hungry", "desc": "Eat 100 creatures", "key": "Cells eaten", "at": 100, "xp": 10},
	{"id": "eat1000", "icon": "🦈", "title": "Glutton", "desc": "Eat 1,000 creatures", "key": "Cells eaten", "at": 1000, "xp": 10},
	{"id": "eat10000", "icon": "👹", "title": "Devourer", "desc": "Eat 10,000 creatures", "key": "Cells eaten", "at": 10000, "xp": 10},
	{"id": "rare1", "icon": "✨", "title": "Lucky find", "desc": "Eat a rare creature", "key": "Rare eaten", "at": 1, "xp": 10},
	{"id": "rare10", "icon": "🌟", "title": "Treasure hunter", "desc": "Eat 10 rare creatures", "key": "Rare eaten", "at": 10, "xp": 10},
	{"id": "rare100", "icon": "💎", "title": "Rare collector", "desc": "Eat 100 rare creatures", "key": "Rare eaten", "at": 100, "xp": 10},
	{"id": "got_better", "icon": "🤒", "title": "I got better", "desc": "Get sick and survive until it wears off", "key": "Recoveries", "at": 1, "xp": 10},
	{"id": "big_fish", "icon": "🐋", "title": "Big fish", "desc": "Reach size 6", "key": "Biggest size", "at": 6, "xp": 10},
	{"id": "max_size", "icon": "🌊", "title": "Colossus", "desc": "Grow to the maximum size", "key": "Biggest size", "at": 10, "xp": 10},
	{"id": "max_speed", "icon": "💨", "title": "Speed demon", "desc": "Reach the maximum swimming speed", "key": "Top speed", "at": 100, "xp": 10},
	{"id": "evade", "icon": "🐟", "title": "Slippery", "desc": "Get away from a bigger creature that was chasing you", "key": "Creatures evaded", "at": 1, "xp": 10},
	{"id": "stun5", "icon": "⚡", "title": "Shock and awe", "desc": "Stun 5 creatures at the same time", "key": "Most stunned", "at": 5, "xp": 10},
	{"id": "swim1", "icon": "🏊", "title": "One kilometre", "desc": "Swim 1 km", "key": "Distance swum (m)", "at": 1000, "xp": 10},
	{"id": "swim10", "icon": "🚤", "title": "Long haul", "desc": "Swim 10 km", "key": "Distance swum (m)", "at": 10000, "xp": 10},
	{"id": "marathon", "icon": "🏅", "title": "Marathon", "desc": "Swim 28 km", "key": "Distance swum (m)", "at": 28000, "xp": 10},
	{"id": "want_to_live", "icon": "❤️‍🩹", "title": "I want to live", "desc": "Drop below 10% health, then get back to full health", "key": "Comebacks", "at": 1, "xp": 10},
	{"id": "be_back", "icon": "🔁", "title": "I'll be back", "desc": "Get chased by a bigger creature, grow, and then eat it", "key": "Revenge", "at": 1, "xp": 10},
	{"id": "close_call", "icon": "😰", "title": "Close call", "desc": "Stay alive for 8 seconds close to a hunter", "key": "Close call", "at": 8, "xp": 10},
	{"id": "score1", "icon": "🏆", "title": "Microbe master", "key": "Best score", "at": 1000, "xp": 10},
	# Hardcore (owner 2026-10-31): sizes 1 to 10 reached in a Hardcore run (one life). Key "Best Hardcore size" (was
	# Hardcore size, never published): a Best ... record gets no generic count badges on top.
	{"id": "hc_size1", "icon": "💀", "title": "Hardcore: first breath", "desc": "Start a Hardcore run", "key": "Best Hardcore size", "at": 1, "xp": 5},
	{"id": "hc_size2", "icon": "💀", "title": "Hardcore: size 2", "desc": "Reach size 2 in Hardcore", "key": "Best Hardcore size", "at": 2, "xp": 5},
	{"id": "hc_size3", "icon": "💀", "title": "Hardcore: size 3", "desc": "Reach size 3 in Hardcore", "key": "Best Hardcore size", "at": 3, "xp": 5},
	{"id": "hc_size4", "icon": "💀", "title": "Hardcore: size 4", "desc": "Reach size 4 in Hardcore", "key": "Best Hardcore size", "at": 4, "xp": 5},
	{"id": "hc_size5", "icon": "💀", "title": "Hardcore: size 5", "desc": "Reach size 5 in Hardcore", "key": "Best Hardcore size", "at": 5, "xp": 5},
	{"id": "hc_size6", "icon": "☠️", "title": "Hardcore: size 6", "desc": "Reach size 6 in Hardcore", "key": "Best Hardcore size", "at": 6, "xp": 5},
	{"id": "hc_size7", "icon": "☠️", "title": "Hardcore: size 7", "desc": "Reach size 7 in Hardcore", "key": "Best Hardcore size", "at": 7, "xp": 5},
	{"id": "hc_size8", "icon": "☠️", "title": "Hardcore: size 8", "desc": "Reach size 8 in Hardcore", "key": "Best Hardcore size", "at": 8, "xp": 5},
	{"id": "hc_size9", "icon": "☠️", "title": "Hardcore: size 9", "desc": "Reach size 9 in Hardcore", "key": "Best Hardcore size", "at": 9, "xp": 5},
	{"id": "hc_size10", "icon": "👑", "title": "Hardcore: size 10", "desc": "Reach size 10 in Hardcore", "key": "Best Hardcore size", "at": 10, "xp": 5},
	# Bosses (owner 2026-11-01): they come in the same order every run, so "Best bosses in a run" = how far you got.
	{"id": "boss1", "icon": "🦠", "title": "Snapped back", "desc": "Defeat Old Snapjaw", "key": "Best bosses in a run", "at": 1, "xp": 10},
	{"id": "boss2", "icon": "🏮", "title": "Lights out", "desc": "Defeat Lantern Mother", "key": "Best bosses in a run", "at": 2, "xp": 10},
	{"id": "boss3", "icon": "🦀", "title": "Shell shocked", "desc": "Defeat Ironclaw", "key": "Best bosses in a run", "at": 3, "xp": 10},
	{"id": "boss4", "icon": "🦑", "title": "Release the Kraken", "desc": "Defeat the Grey Kraken", "key": "Best bosses in a run", "at": 4, "xp": 10},
	{"id": "boss5", "icon": "🐋", "title": "Leviathan slayer", "desc": "Defeat the Hollow Leviathan: all five bosses in one run", "key": "Best bosses in a run", "at": 5, "xp": 20},
	{"id": "hc_boss1", "icon": "💀", "title": "Hardcore: first boss", "desc": "Defeat a boss in Hardcore", "key": "Best Hardcore bosses", "at": 1, "xp": 10},
	{"id": "hc_boss5", "icon": "👑", "title": "Hardcore: all five", "desc": "Defeat all five bosses in one Hardcore run", "key": "Best Hardcore bosses", "at": 5, "xp": 25},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Life on Earth began as single cells, more than 3 billion years ago.",
	"Many one-celled organisms, like amoebas, move and eat by flowing around their food.",
	"Natural selection means the traits that help a living thing survive get passed on more often.",
	"Many bacteria swim by spinning long whip-like tails called flagella.",
	"Viruses are not cells: they are much smaller than bacteria and need a living cell to copy themselves.",
	"Most of the deep ocean is cold, around 0 to 4 °C, even under the tropics.",
	"Every 10 m deeper in water adds about one more atmosphere of pressure.",
	"Some polar fish make antifreeze proteins that stop ice crystals from growing in their blood.",
	"Diatoms are single cells that build their walls out of glass (silica).",
	"Euglena can make food from sunlight like a plant, and also swallow food like an animal.",
	"An octopus has three hearts and blue blood.",
	"A starfish can grow back a lost arm.",
	"In seahorses it is the father who carries the eggs until they hatch.",
	"Didinium, a single cell, can swallow a Paramecium as big as itself.",
	"Deep-sea anglerfish lure prey with a glowing bait full of light-making bacteria.",
	"The Japanese spider crab has the longest legs of any crab: up to 3.7 m from claw tip to claw tip.",
	"Giant squid have eyes as big as a dinner plate.",
	"Sperm whales dive deeper than 2,000 m to hunt squid, and have the biggest brain of any animal.",
]
