extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "wolf_pack"
const TITLE := "Wolf Pack"
const GOAL := "Lead your wolf pack through the wild, hunt to keep it fed, and raise pups to make it grow."
const HOW := [
	"Push the stick (or hold a finger on the screen) the way you want the lead wolf to run. The rest of the pack follows you.",
	"Hold Sprint (or Shift) to run faster. Sprinting tires the leader out; the bar refills when you stop sprinting.",
	"Run close to an animal and the pack joins the chase. Animals run away, but they get tired.",
	"A hare needs only one wolf. A deer needs 2 wolves round it, an elk 3, a bison 5, and the bigger ones must be held for a moment.",
	"Elk and bison kick back when too few wolves are round them: the wolves are knocked away and the pack gets hungrier.",
	"Hunger goes down all the time, faster with a bigger pack and much faster in winter. When it runs out, one wolf leaves the pack. If the leader is alone and starving, the game ends.",
	"Meat the pack can't eat is saved: every 60 spare raises a new pup, up to 10 wolves.",
	"One Year: live through spring, summer, autumn and winter (75 seconds each). Endless: keep going for as long as you can. Your score is the meat the pack has eaten, in kg.",
	"⏸ pauses; Resume on the Home screen carries on the same hunt.",
]
const TIPS := [
	"Hares are easy food early on; save your sprint for the big chases.",
	"Grow the pack before winter: a pack of 2 can't take an elk.",
	"Chase an animal for a while before going in: a tired one runs slower.",
	"A bison feeds the whole pack and raises pups, but only bring 5 wolves or more.",
]
const STATS := ["Best score", "Games played", "Years survived", "Biggest pack", "Hares caught", "Deer caught", "Elk caught", "Bison caught"]
const NO_TIER_BADGES := ["Games played", "Hares caught", "Bison caught"]

const ACHIEVEMENTS := [
	{"id": "first_elk", "icon": "🦌", "title": "Elk Hunters", "key": "Elk caught", "at": 1, "xp": 25},
	{"id": "first_bison", "icon": "🦬", "title": "Bison Down", "key": "Bison caught", "at": 1, "xp": 50},
	{"id": "full_pack", "icon": "🐺", "title": "Full Pack", "key": "Biggest pack", "at": 10, "xp": 50},
	{"id": "one_year", "icon": "❄", "title": "Through the Winter", "key": "Years survived", "at": 1, "xp": 25},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"A wolf pack is usually one family: a mother and father wolf and their young from the last few years.",
	"Gray wolves were brought back to Yellowstone National Park in 1995, about 70 years after they had been wiped out there.",
	"Elk are the main prey of the wolves in Yellowstone.",
	"Most wolf hunts fail: the prey escapes far more often than it is caught.",
	"A hungry wolf can eat about 9 kg of meat in one meal, then go days without food.",
	"Wolves howl to find each other and to tell other packs to keep away; a howl can carry for kilometres.",
]
