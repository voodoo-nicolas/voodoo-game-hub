extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "ink_ninja"
const TITLE := "Ink Ninja"
const GOAL := "Run, leap and cut your way through a painted scroll."
## Owner 2026-11-16: How to Play is the controller layout, nothing after it.
const HOW := [
	"Stick: push left or right to run. Pull down to crouch and creep. Push up to jump; push up again in the air to jump higher. Against a wall, push up to kick off.",
	"A (Swing): cut. Crouch and swing for a low jab. While rising, the cut goes straight up; while falling, it plunges down onto a foe.",
	"Y (Block): hold to stop stars and blades from the front.",
	"X (Star): throw a star.",
	"B (Thrust): lunge forward and run your blade through a foe. While lunging, attacks pass through you.",
	"Bomb: drop a smoke bomb. Foes in the cloud are blinded.",
]
const TIPS := []
const STATS := ["Best score", "Highest stage", "Bosses defeated", "Ninjas defeated", "Stars parried", "Daily objectives", "Weekly objectives", "Hearts carved", "Secrets found", "Pagodas climbed", "Games played"]
const ACHIEVEMENTS := [
	{"id": "boss1", "icon": "🗡️", "title": "First Duel", "key": "Bosses defeated", "at": 1, "xp": 12},
	{"id": "stage5", "icon": "⛩️", "title": "Halfway Up the Mountain", "key": "Highest stage", "at": 12, "xp": 12},
	{"id": "stage10", "icon": "🥷", "title": "Master of Ink", "key": "Highest stage", "at": 24, "xp": 12},
	{"id": "kills500", "icon": "🖌️", "title": "Five Hundred Strokes", "key": "Ninjas defeated", "at": 500, "xp": 12},
	{"id": "daily7", "icon": "📅", "title": "Daily Discipline", "key": "Daily objectives", "at": 7, "xp": 12},
	{"id": "weekly4", "icon": "🗓️", "title": "A Month of Ink", "key": "Weekly objectives", "at": 4, "xp": 12},
	{"id": "hearts24", "icon": "❤️", "title": "Heart Carver", "key": "Hearts carved", "at": 24, "xp": 12},
	{"id": "parry50", "icon": "✨", "title": "Star Cutter", "key": "Stars parried", "at": 50, "xp": 12},
	{"id": "secrets10", "icon": "📜", "title": "Keeper of Secrets", "key": "Secrets found", "at": 10, "xp": 12},
	{"id": "pagodas5", "icon": "🏯", "title": "Rooftop Runner", "key": "Pagodas climbed", "at": 5, "xp": 12},
]
## Learning hook (STANDARDS §15): checked facts about real ninja (shinobi) history and ink painting.
const FACTS := [
	"Real ninja were called shinobi in Japan; they worked mostly as spies and scouts, not as warriors in black suits.",
	"The all-black ninja outfit comes from kabuki theatre, where stagehands dressed in black so the audience would ignore them.",
	"The Iga and Kōga regions of Japan were famous for their shinobi in the 1400s and 1500s.",
	"Throwing stars are called shuriken; many were meant to distract or slow an enemy, not to kill.",
	"Sumi-e is Japanese ink-wash painting: black ink thinned with water to make every shade of grey.",
]
