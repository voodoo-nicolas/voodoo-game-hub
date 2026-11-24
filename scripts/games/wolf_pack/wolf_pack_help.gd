extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Stonewater: campaign (10 missions, ranks) + Quick Mission (map type + role).

const ID := "wolf_pack"
const TITLE := "Stonewater"
const GOAL := "Rise from pup to Elder: complete missions, earn renown and lead the pack."
const HOW := [
	"Campaign: ten missions on hand-made maps. Each win earns renown, and renown raises your rank: Pup, Hunter, Tracker, Warden, Pack Leader, Elder. A new rank gives you a stronger body, new abilities, new orders and a new packmate.",
	"Quick Mission: pick a map type and a role (Leader, Chaser, Striker or Scout) and the game builds a short mission on a new map. Only the Leader gives orders; for the other roles, Sable leads the pack and you play your part.",
	"Move with the stick (or W A S D). Hold Sprint (Shift) to run: it uses stamina, and the bar fills again when you stop. Hills slow you when you climb and help a little when you run down.",
	"Prey run when wolves come near, and a running animal gets tired. A herd always has a few weak animals, and the strong ones are much harder to catch. Deer are quick but small, elk tougher, bison enormous.",
	"Sense (E) shows scent trails, marks the weak animals with a ◆ and shows each one's stamina. The line on the bar is where an animal is tired enough to be held. It lasts a few seconds and then needs a rest.",
	"Tap Howl (Q) to call the pack back to you. Hold Howl to open the command wheel (time slows down) and tap a command, or press 1 to 7. Orders you have not earned yet are locked.",
	"Rally: follow me. Hold: stay here. Scout ahead: the scout runs in front. Drive: the chaser runs the prey down. Flank: wolves cut off its escape. Strike: the pack closes in and bites. Guard: the pack stays close and fights rivals.",
	"When an animal is tired, get close and hold Bite. A bar fills: each wolf biting helps, and a bigger bite holds faster. A healthy animal kicks, which breaks your hold and hurts; grab it again and the bar carries on.",
	"Tracker rank: Pounce. Sprint at a running animal and press Bite to leap on it. Warden rank: tap Rally for a Rallying Howl that heals the pack and makes it faster. Elder: every order works better.",
	"Scent posts: walk to a post to mark it. Rival wolves defend their ground: bite them, and the pack will join in. A rival with little strength left runs away, and that counts as driven off.",
	"Defending the den: raiders walk in from the edge of the map. If they reach the den its bar drains, and when it is empty the mission is lost. Keep the pack close with Guard.",
	"Stars: one for finishing, one for beating the par time, one for no wolf going down. Missions are unlocked in order. Replays pay a third of the renown.",
	"⏸ pauses; Resume on the Home screen carries on the same mission.",
]
const TIPS := [
	"Aim for the weak animal first: use Sense and look for the ◆.",
	"Send the chaser (Drive) first, then Strike when the animal is tired.",
	"Don't sprint straight at a herd: it runs early. Walk close, then sprint.",
	"A kicked bite isn't lost: grab again and the bar carries on.",
	"Drive prey into the mud: it slows them more than you.",
	"Scouts and Sense show you where the herds are; the minimap remembers what you have seen.",
	"Keep a downed packmate safe: Rally and they rise again after a few seconds.",
]
const STATS := ["Prey caught", "Missions won", "Rival wolves driven off", "Quick missions won", "Games played"]
const NO_TIER_BADGES := ["Games played"]

const ACHIEVEMENTS := [
	{"id": "first_prey", "icon": "🦌", "title": "First Catch", "key": "Prey caught", "at": 1, "xp": 5},
	{"id": "ten_prey", "icon": "🐺", "title": "Pack Hunters", "key": "Prey caught", "at": 10, "xp": 5},
	{"id": "fifty_prey", "icon": "🍖", "title": "Full Bellies", "key": "Prey caught", "at": 50, "xp": 10},
	{"id": "rank_hunter", "icon": "🦷", "title": "Hunter", "key": "Rank", "at": 2, "xp": 5},
	{"id": "rank_tracker", "icon": "👃", "title": "Tracker", "key": "Rank", "at": 3, "xp": 5},
	{"id": "rank_warden", "icon": "🛡", "title": "Warden", "key": "Rank", "at": 4, "xp": 10},
	{"id": "rank_leader", "icon": "👑", "title": "Pack Leader", "key": "Rank", "at": 5, "xp": 10},
	{"id": "rank_elder", "icon": "🌕", "title": "Elder", "key": "Rank", "at": 6, "xp": 15},
	{"id": "borders", "icon": "🚩", "title": "Border Keepers", "key": "Rival wolves driven off", "at": 20, "xp": 10},
	{"id": "quick_five", "icon": "⚡", "title": "Quick Hunters", "key": "Quick missions won", "at": 5, "xp": 5},
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
