extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Written from the game's code (the_runner_engine.gd, the_runner_battle.gd, the_runner_game.gd,
## the_runner_dock.gd, the_runner_computer.gd, the_runner_create.gd): design doc v2 and the Quest
## Expansion v2.2 (Acts I to III, the Hollow Deep, the endings). FACTS are checked astronomy (the worlds and hazards of the game)
## and one economics fact (the markets); STANDARDS §15.

const ID := "the_runner"
const TITLE := "The Runner"
const GOAL := "Make a captain, fly a broke courier's ship through the Spiral, run cargo the law doesn't like, pick your side (or both) and grow rich without getting caught."
const HOW := [
	"A new run starts with your captain: a name, a race (each has two perks and a flaw), a home faction and two more perks of your choice.",
	"Hold the phone sideways. At a dock, the left column lists what the port offers: Job board, Crew for hire, Market, Shipyard, Fixer jobs, Faction office, Refuel, Repair. 🚀 Launch takes you to the sector map.",
	"On the map, tap a world to see its law level, fuel cost and flight time, then Set course: trips take 20 to 45 seconds. Or fly by hand with the stick; near a world, A docks. 🔭 shows the whole sector.",
	"Buy low, sell high. Each world makes some goods cheap and pays well for others. Prices move when you trade and when news breaks.",
	"◆ Contraband pays far more, but only black markets buy it, and it pays in dirty credits. Dirty credits count only 30% toward your net worth: wash them at a laundry.",
	"Accord patrols scan ships that dock at lawful worlds. Keep contraband in the hidden hold. A failed scan: bribe, bluff, dump the cargo, run, fight or take the fine.",
	"Battles are in real time: steer with the stick (or drag), tap an enemy to target it, your guns fire by themselves in range. Shields, Evade and Flee have cooldowns. Lose and they take your cargo and half your dirty credits.",
	"Ten factions keep a rep with you (−50% to 100%). Quests change only the factions they list. At 10% a faction gives you work, at 25% and 50% discounts, at 50 / 75 / 100% a bonus each. Below −25% their ships attack you.",
	"Quests also fill one of two bars, Paragon or Outlaw. They never go down, and each gives titles and bonuses at 10, 30, 50, 75 and 100.",
	"Crew: do someone's quest on their planet, then hire them there. Each brings two perks and half a flaw, needs a free slot and a wage, and won't share a ship with a race they hate. After three quests together they offer their own ♥ quest: their perk goes to Rank II.",
	"Old Marrow's Runner can be refitted at a shipyard: Skiff, Courier, Corvette, Cruiser. Bigger hulls carry more crew, guns, engines, shields and special parts, and you see each part on the ship.",
	"The gate at the edge of a sector opens once you hold a Rift Key (Act I). The story runs through three Blind Nodes to the Hollow Deep, where one of three endings waits, depending on your bars, your rep and your crew.",
	"☰ Menu opens the ship computer: Inventory, Skill Tree, Missions, Map, Ship Layout, Stats, Factions, Crew and Captain.",
	"Stuck with no money, nothing to sell and no fuel? Mother Kessel lends 500 (you owe 600). The game saves every time you pause.",
]
const TIPS := [
	"The Fixer's tip (💡 in the Market) names the best trade from where you stand. 3 tips, one more every day.",
	"The same perk from two sources counts half the second time, and a stat's bonus stops at +60%: spread your perks.",
	"A Paragon and an Outlaw crew member on one ship each lose 15 loyalty. Playing both sides has a price.",
	"Donating at a faction office buys rep up to 50%; the rest you earn.",
	"Blind spots like Scrapyard Gamma cool your heat twice as fast, and their wrecks hide cargo.",
	"Moving fast in a battle makes you harder to hit.",
]
const STATS := ["Best net worth", "Runs", "Scans passed", "Most contracts done"]
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
	{"id": "crew1", "icon": "🧑‍🚀", "title": "First Mate", "desc": "Have a crew member aboard", "key": "Most crew aboard", "at": 1, "xp": 20},
	{"id": "crew4", "icon": "👥", "title": "Full Crew", "desc": "Have four crew members aboard", "key": "Most crew aboard", "at": 4, "xp": 20},
	{"id": "paragon10", "icon": "☀️", "title": "Respected", "desc": "Reach 10 on the Paragon bar", "key": "Highest Paragon", "at": 10, "xp": 20},
	{"id": "paragon50", "icon": "🌞", "title": "Champion of the Accord", "desc": "Reach 50 on the Paragon bar", "key": "Highest Paragon", "at": 50, "xp": 20},
	{"id": "outlaw10", "icon": "🌙", "title": "Notorious", "desc": "Reach 10 on the Outlaw bar", "key": "Highest Outlaw", "at": 10, "xp": 20},
	{"id": "outlaw50", "icon": "🌑", "title": "Warlord", "desc": "Reach 50 on the Outlaw bar", "key": "Highest Outlaw", "at": 50, "xp": 20},
	{"id": "courier", "icon": "🛠", "title": "Courier Class", "desc": "Refit the Runner into a Courier", "key": "Highest hull tier", "at": 2, "xp": 20},
	{"id": "cruiser", "icon": "🛰", "title": "Cruiser Class", "desc": "Refit the Runner into a Cruiser", "key": "Highest hull tier", "at": 4, "xp": 20},
	{"id": "rep50", "icon": "🤝", "title": "Trusted", "desc": "Reach 50% rep with a faction", "key": "Best faction rep", "at": 50, "xp": 20},
	{"id": "rep100", "icon": "🏛", "title": "Inner Circle", "desc": "Reach 100% rep with a faction", "key": "Best faction rep", "at": 100, "xp": 20},
	{"id": "quests25", "icon": "📜", "title": "Job Hunter", "desc": "Finish 25 quests", "key": "Most quests done", "at": 25, "xp": 20},
	{"id": "ending", "icon": "🌀", "title": "The Ledger's Fate", "desc": "Reach an ending of the story", "key": "Most endings reached", "at": 1, "xp": 50},
]
const FACTS := [
	"A black hole's gravity is so strong that nothing, not even light, escapes from inside its event horizon.",
	"In 2019 the Event Horizon Telescope showed the first picture of a black hole's shadow, in the galaxy M87.",
	"Sunlight takes about 8 minutes and 20 seconds to reach Earth.",
	"Most meteor showers happen when Earth passes through the dust trail left by a comet.",
	"All the asteroids of the main belt, between Mars and Jupiter, add up to only a few percent of the Moon's mass.",
	"Io, a moon of Jupiter, is the most volcanically active body in the Solar System.",
	"Jupiter's moon Europa hides a salty ocean under its ice, likely holding more water than all of Earth's oceans.",
	"The stars of a constellation only look close together: most are at very different distances from us.",
	"A day on Venus (one full turn on its axis) is longer than its year.",
	"Saturn's rings are mostly water ice, from grains of dust to chunks as big as a house, yet in most places they are only about ten metres thick.",
	"A nebula is a cloud of gas and dust in space; many are nurseries where new stars form.",
	"Supply and demand: when many sellers bring the same goods, the price falls; when goods are scarce, it rises.",
]
