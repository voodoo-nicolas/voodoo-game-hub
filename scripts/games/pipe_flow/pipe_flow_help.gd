extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "pipe_flow"
const TITLE := "Wire Up"
const GOAL := "Turn the wire pieces so current from the batteries reaches and lights every bulb."
const HOW := [
	"Tap a piece to turn it a quarter turn clockwise. Pieces with screws are locked.",
	"Current flows through pieces whose ends meet. A bulb lights when current reaches it.",
	"Batteries are blue or yellow. A bulb only lights with its own colour of current.",
	"Never join blue and yellow by accident: a wire touching both batteries carries green current, and blue or yellow bulbs on it stay dark.",
	"A green bulb needs exactly that: blue and yellow current joined in one wire.",
	"A ring around a battery or bulb means you can turn it too. Loose wire ends and spare pieces are decoys.",
	"Campaign: 120 levels in 12 chapters, 3 stars each. Fewer taps and no hints earn more stars.",
	"Daily Challenge: one board a day, the same for everyone. Time Attack: 3 minutes, each board harder than the last.",
	"💡 shows a piece that is wrong (3 stars need no hints). ↶ takes back your last turn.",
]
const TIPS := [
	"Start from a battery and follow the wire: a piece at the edge can only point inwards.",
	"Straight pieces have only two useful positions, so they're quick to settle.",
	"Plan the wire for a green bulb first: it has to touch both batteries.",
	"Locked pieces are always right, so build around them.",
]
const STATS := ["Puzzles solved", "Campaign levels", "Campaign stars", "Perfect levels", "Time attack best", "Daily streak", "Green bulbs lit"]

## Goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "campaign10", "icon": "💡", "title": "First Spark", "key": "Campaign levels", "at": 10},
	{"id": "campaign40", "icon": "🔌", "title": "Apprentice Electrician", "key": "Campaign levels", "at": 40},
	{"id": "campaign80", "icon": "⚡", "title": "Master Wirer", "key": "Campaign levels", "at": 80},
	{"id": "campaign120", "icon": "🏆", "title": "Grid Master", "key": "Campaign levels", "at": 120},
	{"id": "stars60", "icon": "⭐", "title": "Star Collector", "key": "Campaign stars", "at": 60},
	{"id": "stars200", "icon": "🌟", "title": "Constellation", "key": "Campaign stars", "at": 200},
	{"id": "stars360", "icon": "✨", "title": "Perfect Circuit", "key": "Campaign stars", "at": 360},
	{"id": "perfect20", "icon": "🎯", "title": "No Wasted Taps", "key": "Perfect levels", "at": 20},
	{"id": "green25", "icon": "🟢", "title": "Colour Mixer", "key": "Green bulbs lit", "at": 25},
	{"id": "ta8", "icon": "⏱", "title": "Speed Wirer", "key": "Time attack best", "at": 8},
	{"id": "ta15", "icon": "🚀", "title": "Lightning Fast", "key": "Time attack best", "at": 15},
	{"id": "daily7", "icon": "📅", "title": "Week of Light", "key": "Daily streak", "at": 7},
	{"id": "daily30", "icon": "🌞", "title": "Monthly Glow", "key": "Daily streak", "at": 30},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"Electric current needs a complete loop: from a battery, through the bulb, and back.",
	"The first practical light bulbs of the late 1870s used a glowing carbon filament.",
]
