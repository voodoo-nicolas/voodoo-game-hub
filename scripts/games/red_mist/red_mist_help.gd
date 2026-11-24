extends RefCounted

## How to Play text, stats and achievements for GameInfo (scripts/common/game_info.gd).

const ID := "red_mist"
const TITLE := "Red Mist"
const GOAL := "From a hide above the valley, finish each contract: take down the officer with the red armband, clear everyone out, beat the clock or stop the trucks. 30 contracts in 6 places."
const HOW := [
	"Hold the phone sideways. Drag to look around the valley. Pinch out (or tap a spot, or use the zoom bar) to look through the scope; pinch in to take your eye off it.",
	"Through the scope, tap anywhere to fire at the centre of the reticle. Drag to move the aim; a quick tap is a shot.",
	"Your aim moves with your breathing. The breath gauge fills as you breathe; its green part is the pause after breathing out, when the aim goes still and the ring round the dot turns green. Fire then.",
	"Hold 🫁 Hold breath to freeze your breathing: steady for about 3 seconds, then the shakes grow, and after 6 seconds you gasp for air. Each shot makes your heart beat faster for a while, so the aim shakes more.",
	"Bullets take time to arrive (about a second at 600 m), fall as they fly and drift in the wind. Lead a walking target. Smoke, flags and the wind arrow show the wind; later contracts have gusts.",
	"Easy: no drop and no wind. Normal: the scope sets itself for the range under the reticle, so you only aim into the wind. Hard: aim high for the drop as well; the range and the drop in mils are shown, and the reticle has a mark every mil.",
	"Shots raise the alarm. A near miss sends the guards close to it into cover for a few seconds. When the alarm is full, the officer runs for the edge of the valley. Shoot the radio dish to quieten the alarm for 20 seconds.",
	"Red drums explode and take down anyone standing next to them.",
	"🗺 Contracts: 30 jobs, 5 in each of 6 places (Alpine Pass, Dust Basin, Grey Harbour, Canyon Railway, Jungle Temple, Night City), at dawn, by day, at dusk or at night, in fog, snow, rain, dust or storms. Each has a goal: 🎖 the officer (the others may run), 👥 everyone (nobody may get away), ⏱ everyone before the clock runs out, 🚚 stop the trucks before they leave.",
	"🚚 A truck stops when you hit its red-and-white striped fuel tank (it blows up) or the driver through the cab window.",
	"Some contracts have civilians in hi-vis vests and white hard hats. Hitting one ends the contract.",
	"At night the scope shows night vision; towers sweep the ground with searchlights.",
	"Stars: 1 for the goal, 2 for 80% of the targets and trucks, 3 for all of them with 70% of your shots on target.",
	"♾ Survival: they keep crossing a valley you have reached, faster and faster. Endless rounds, 5 to a magazine. Three get across and the run is over.",
	"📅 Daily contract: the same contract for everyone today.",
	"Each contract opens with a briefing: the goal, the time of day, the weather, the wind and your rounds. Tap ▶ Begin when you're ready.",
	"🛠 Armory: won contracts pay cash (a third of the score, half the first time you win one; survival pays too). Spend it on the rifle: a scope that zooms further, a bipod for a steadier aim, a faster bolt, a suppressor that keeps the alarm down. Three upgrades each.",
	"Bullet cam: headshots, shots of 500 m or more, the officer and the shot that finishes a contract follow the bullet in slow motion. Tap to skip; turn it off in ⚙ Options.",
	"⏸ pauses; Resume on the Landing carries on the same contract.",
	"🎓 Tutorial: a quick intro level that explains every gauge and button on the screen, then lets you take one practice shot. It starts by itself the first time; replay it from the Landing.",
	"PC: arrow keys or WASD (or dragging) look around; mouse wheel, + and - zoom; left click or Enter fires; right click or Space holds your breath. Controller: sticks look, RT or A fires, LT, B or X holds breath, LB and RB zoom, D-pad up and down zoom. ⚙ Options can invert the look up / down direction.",
]
const TIPS := [
	"Breathe out, wait for the green ring, then tap.",
	"Shoot the officer first if he is in the open: the others panic and run once he is down.",
	"Patrols turn at the ends of their walk: aim where they will be when the bullet gets there.",
	"Into the wind: aim on the side the wind is coming from.",
	"A guard behind sandbags only shows his head and shoulders: wait for him to stand up, or try a headshot.",
	"A truck far away is slow across the scope: wait for it to come side-on, then go for the tank.",
	"Against the clock, take the patrols first: the ones standing still will still be there.",
]
const STATS := ["Best score", "Games played", "Wins", "Targets down", "Headshots", "Trucks stopped", "Longest shot (m)", "Contracts done", "Contract stars", "Perfect contracts", "Survival best"]
const NO_TIER_BADGES := ["Wins", "Contract stars", "Perfect contracts", "Contracts done", "Longest shot (m)", "Survival best", "Trucks stopped"]

const ACHIEVEMENTS := [
	{"id": "first_contract", "icon": "🎯", "title": "First Contract", "key": "Contracts done", "at": 1, "xp": 25},
	{"id": "two_places", "icon": "🧭", "title": "On the Move", "key": "Contracts done", "at": 10, "xp": 30},
	{"id": "every_valley", "icon": "🗺", "title": "Every Valley", "key": "Contracts done", "at": 30, "xp": 60},
	{"id": "marksman", "icon": "⭐", "title": "Marksman", "key": "Contract stars", "at": 90, "xp": 60},
	{"id": "long_reach", "icon": "📏", "title": "Long Reach", "key": "Longest shot (m)", "at": 800, "xp": 40},
	{"id": "clean_work", "icon": "🧹", "title": "Clean Work", "key": "Perfect contracts", "at": 1, "xp": 25},
	{"id": "convoy_breaker", "icon": "🚚", "title": "Convoy Breaker", "key": "Trucks stopped", "at": 10, "xp": 30},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"A milliradian (a mil) is a thousandth of a radian: at 1,000 metres it spans about 1 metre, at 100 metres about 10 centimetres.",
	"A bullet starts to fall the moment it leaves the barrel. Sights are tilted slightly up so its path crosses the line of sight at the distance the rifle is zeroed for.",
	"Sound travels about 343 metres per second in air at 20 °C, slower than a rifle bullet, so a far target is hit before the shot's sound reaches it.",
	"Marksmen are taught to fire in the natural pause after breathing out, when the chest is still.",
	"How far a crosswind pushes a bullet depends on how much the air slows the bullet down, not only on how long it flies.",
	"Night-vision scopes amplify faint light, and many show the picture in green because the eye can tell more shades of green apart.",
]
