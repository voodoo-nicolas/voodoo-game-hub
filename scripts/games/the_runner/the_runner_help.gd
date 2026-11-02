extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Written from the game's code (the_runner_engine.gd, the_runner_game.gd, the_runner_dock.gd,
## the_runner_computer.gd): Act I in the Cradle Reach system. FACTS are checked astronomy (the worlds
## and hazards of the game) and one economics fact (the markets); STANDARDS §15.

const ID := "the_runner"
const TITLE := "The Runner"
const GOAL := "Earth is dead and everyone lives on the Moon. Start as a broke courier in debt, run cargo the law doesn't like, and grow rich without getting caught."
const HOW := [
	"Hold the phone sideways. At a dock, the left column lists what the port offers: Market, Shipyard, Fixer jobs, Refuel, Repair. 🚀 Launch takes you to the system map.",
	"On the map, tap a world to see its law level, fuel cost and travel time, then Set course. Or fly by hand with the stick (lower left); near a world, A docks. B stops the autopilot.",
	"Buy low, sell high. Each world makes some goods cheap and pays well for others. Prices move when you trade and when news breaks (crackdowns, shortages, strikes).",
	"◆ Contraband (forged IDs, bootleg data, weapons, stolen tech, Hollow relics) pays far more, but only black markets buy it, and it pays in dirty credits.",
	"Dirty credits pay for black-market parts, bribes, fuel, repairs and Kessel's debt, but not legal goods or legal parts, and they count only 30% toward your net worth. Wash them at the Moonwash Laundry on Luna (it opens after Kessel's first job).",
	"Patrols scan ships that dock at lawful worlds. Keep contraband in the hidden hold: anything in the open hold is found. A failed scan: bribe, dump the cargo, run, fight or submit to a fine.",
	"Heat rises with every run-in with the law and cools day by day (faster in blind spots like Old Earth and Gravel Belt). High heat means more scans and bounty hunters.",
	"Between worlds things happen: raiders, wrecks to salvage, distress calls, meteor showers. Don't fly through the Sun or the Maw (the black hole).",
	"Fights take turns: Attack, Evade (they hit less) or Run. Lose and they take your cargo and half your dirty credits.",
	"☰ Menu opens the ship computer: Inventory, Skill Tree, Missions, Map, Ship Layout and Stats.",
	"XP from trading, jobs and scans gives skill points. Spend them in the Skill Tree: your first branch is primary, the second secondary.",
	"Stuck with no money, nothing to sell and no fuel? Mother Kessel lends 500 (you owe 600).",
	"The game saves every time you pause. ▶ Resume picks up where you were, even mid-flight.",
]
const TIPS := [
	"The Fixer's tip (💡 in the Market) names the best trade from where you stand. 3 tips, one more every day.",
	"A Patrol Sniffer scanner shows the law level of every world on the map and the scan chance of a trip.",
	"Contracts give you the cargo for free: a good way to earn when you're broke.",
	"Blind spots cool your heat twice as fast. Old Earth is one, and its wrecks hide cargo.",
	"The Runner's Ghost Core makes it far harder to scan than the old Moth.",
]
const STATS := ["Best net worth", "Runs", "Scans passed", "Contracts done"]
const ACHIEVEMENTS := [
	{"id": "kessel", "icon": "💸", "title": "Square with Kessel", "desc": "Pay off Mother Kessel", "key": "Debt paid", "at": 1, "xp": 25},
	{"id": "runner", "icon": "🚀", "title": "Dead Man's Ship", "desc": "Get the Runner", "key": "Runner", "at": 1, "xp": 25},
	{"id": "act1", "icon": "🌌", "title": "Ghost in the Net", "desc": "Finish Act I", "key": "Act I", "at": 1, "xp": 25},
	{"id": "nw10k", "icon": "🪙", "title": "Small Fry", "desc": "Reach a net worth of 10,000", "key": "Best net worth", "at": 10000, "xp": 25},
	{"id": "nw100k", "icon": "💰", "title": "Somebody", "desc": "Reach a net worth of 100,000", "key": "Best net worth", "at": 100000, "xp": 25},
	{"id": "nw1m", "icon": "💎", "title": "Kingpin in the Making", "desc": "Reach a net worth of 1,000,000", "key": "Best net worth", "at": 1000000, "xp": 25},
	{"id": "nw1b", "icon": "👑", "title": "The Billion", "desc": "Reach a net worth of 1,000,000,000", "key": "Best net worth", "at": 1000000000, "xp": 25},
	{"id": "fights10", "icon": "🏴", "title": "Black Flag", "desc": "Win 10 fights", "key": "Fights won", "at": 10, "xp": 25},
	{"id": "skills5", "icon": "🌟", "title": "Specialist", "desc": "Learn 5 skills", "key": "Skills learned", "at": 5, "xp": 25},
	{"id": "laundry", "icon": "🧺", "title": "Squeaky Clean", "desc": "Launder 10,000 credits", "key": "Laundered", "at": 10000, "xp": 25},
]
const FACTS := [
	"A black hole's gravity is so strong that nothing, not even light, escapes from inside its event horizon.",
	"In 2019 the Event Horizon Telescope showed the first picture of a black hole's shadow, in the galaxy M87.",
	"The Moon is about 384,400 km from Earth on average.",
	"Sunlight takes about 8 minutes and 20 seconds to reach Earth.",
	"Most meteor showers happen when Earth passes through the dust trail left by a comet.",
	"All the asteroids of the main belt, between Mars and Jupiter, add up to only a few percent of the Moon's mass.",
	"Io, a moon of Jupiter, is the most volcanically active body in the Solar System.",
	"Jupiter's moon Europa hides a salty ocean under its ice, likely holding more water than all of Earth's oceans.",
	"The stars of a constellation only look close together: most are at very different distances from us.",
	"A day on Venus (one full turn on its axis) is longer than its year.",
	"Supply and demand: when many sellers bring the same goods, the price falls; when goods are scarce, it rises.",
]
