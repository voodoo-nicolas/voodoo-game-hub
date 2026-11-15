extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Stonewater, M0 vertical slice: describes what the code does today.

const ID := "wolf_pack"
const TITLE := "Stonewater"
const GOAL := "Lead your pack to bring down two elk and feed everyone."
const HOW := [
	"Move with the stick (or W A S D). Hold Sprint (Shift) to run: it uses stamina, and the bar fills again when you stop.",
	"Elk run when wolves come near, and a running elk gets tired. A herd always has a few weak animals, and the strong ones are much harder to catch.",
	"Sense (E) shows scent trails, marks the weak elk with a ◆ and shows each elk's stamina. The line on the bar is where an elk is tired enough to be held. It lasts 4 seconds and then needs a rest.",
	"Tap Howl (Q) to call the pack back to you. Hold Howl to open the command wheel (time slows down) and tap a command, or press 1 to 6.",
	"Rally: follow me. Hold: stay here. Scout ahead: the scout runs in front and shows more of the map. Drive: the chaser runs the elk down and tires it. Flank: wolves cut off its escape. Strike: the pack closes in and bites.",
	"When an elk is tired, get close and hold Bite. A bar fills: each wolf biting helps. A healthy elk kicks, which breaks your hold and hurts; grab it again and the bar carries on.",
	"Mud (brown, dashed edge) slows everyone, and slows elk the most. The den (marked on the map) is where you wake up if you go down.",
	"The pack has a hunger bar. Eating fills it. When it is empty, wolves recover stamina slower, but you never lose the game for it.",
	"⏸ pauses; Resume on the Home screen carries on the same hunt.",
]
const TIPS := [
	"Aim for the weak elk first: use Sense and look for the ◆.",
	"Send the chaser (Drive) first, then Strike when the elk is tired.",
	"Don't sprint straight at a herd: it runs early. Walk close, then sprint.",
	"A kicked bite isn't lost: grab again and the bar carries on.",
	"Drive the elk into the mud: it slows them more than you.",
]
const STATS := ["Elk caught", "Games played"]
const NO_TIER_BADGES := ["Games played"]

const ACHIEVEMENTS := [
	{"id": "first_elk", "icon": "🦌", "title": "First Elk", "key": "Elk caught", "at": 1, "xp": 25},
	{"id": "ten_elk", "icon": "🐺", "title": "Pack Hunters", "key": "Elk caught", "at": 10, "xp": 50},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"Most wild wolf packs are families: a mother and father and their young.",
	"Young wolves usually become pack leaders by leaving home, finding a mate and starting their own pack.",
	"Most wolf hunts fail: wolves test a herd and go after the animals that are weak, old or young.",
	"Wolves use scent marks and howls to tell other packs where their land begins.",
	"Elk are the main prey of the wolves in Yellowstone National Park.",
]

## Quotes shown on the Landing, at the start of a hunt, when you go down and at the end.
## [text, who said it]. Gervais and Carlin lines are marked Unknown: no verified source (owner, 2026-11-15).
const QUOTES := [
	["I am not a wolf in sheep's clothing, I'm a wolf in wolf's clothing.", "Unknown"],
	["A gentleman is simply a patient wolf.", "Lana Turner"],
	["There are nights when the wolves are silent and only the moon howls.", "Unknown"],
	["A fox is a wolf who sends flowers.", "Ruth Brown"],
	["All stories are about wolves. All worth repeating, that is. Anything else is sentimental drivel.", "Margaret Atwood"],
	["The lion may be more powerful, but the wolf does not perform in the circus.", "Unknown"],
]
