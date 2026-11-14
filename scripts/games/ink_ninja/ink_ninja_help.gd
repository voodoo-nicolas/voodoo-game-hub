extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "ink_ninja"
const TITLE := "Ink Ninja"
const GOAL := "Run, leap and cut your way through 10 ink-painted stages and defeat the boss waiting at the end of each one."
const HOW := [
	"Push the stick left or right to run. Pull it down to crouch: low enemy stars fly over your head, and your slash cuts low.",
	"A jumps. Press it again in the air for a double jump. Hold the stick against a wall while falling to slide down it, then press A to kick off.",
	"B slashes your sword in front of you. A slash also cuts enemy throwing stars out of the air.",
	"X throws a star. You start each stage with at least 8; star throwers sometimes drop 2 more.",
	"Y dashes forward. While dashing, attacks pass straight through you.",
	"Blade ninjas raise their sword before they cut, leapers jump at you, brutes take 3 hits and hit twice as hard.",
	"You have 5 hearts and 3 lives. Falling into a pit costs a life and restarts the stage.",
	"At the end of each stage a gate shuts and a boss attacks. Watch for the pause before each move: a charge, a leap that shakes the ground, or a fan of stars.",
	"Kills in a row score 100, 200, 300... up to 500 each. Scrolls score 50. A boss scores 2000 plus a bonus for speed.",
	"The story runs over 10 chapters: a card before each stage tells the next part, and the ▸ line under the progress bar shows the stage's goal.",
	"Objectives (on the Landing): one daily goal and one weekly goal. Finishing one adds 1000 (daily) or 5000 (weekly) points to the run you are playing.",
	"⏸ pauses; Resume on the Home screen keeps your score, lives and stars and restarts the stage.",
]
const TIPS := [
	"Dash through a boss's charge instead of jumping over it.",
	"Jump when a boss lands from a leap: the shockwave only hits you on the ground.",
	"Keep a few stars for the boss and slash the small fry.",
	"Crouch under a star thrower's stars instead of jumping them.",
]
const STATS := ["Best score", "Highest stage", "Bosses defeated", "Ninjas defeated", "Stars parried", "Daily objectives", "Weekly objectives", "Games played"]
const ACHIEVEMENTS := [
	{"id": "boss1", "icon": "🗡️", "title": "First Duel", "key": "Bosses defeated", "at": 1, "xp": 12},
	{"id": "stage5", "icon": "⛩️", "title": "Halfway Up the Mountain", "key": "Highest stage", "at": 5, "xp": 12},
	{"id": "stage10", "icon": "🥷", "title": "Master of Ink", "key": "Highest stage", "at": 10, "xp": 12},
	{"id": "kills500", "icon": "🖌️", "title": "Five Hundred Strokes", "key": "Ninjas defeated", "at": 500, "xp": 12},
	{"id": "daily7", "icon": "📅", "title": "Daily Discipline", "key": "Daily objectives", "at": 7, "xp": 12},
	{"id": "weekly4", "icon": "🗓️", "title": "A Month of Ink", "key": "Weekly objectives", "at": 4, "xp": 12},
	{"id": "parry50", "icon": "✨", "title": "Star Cutter", "key": "Stars parried", "at": 50, "xp": 12},
]
## Learning hook (STANDARDS §15): checked facts about real ninja (shinobi) history and ink painting.
const FACTS := [
	"Real ninja were called shinobi in Japan; they worked mostly as spies and scouts, not as warriors in black suits.",
	"The all-black ninja outfit comes from kabuki theatre, where stagehands dressed in black so the audience would ignore them.",
	"The Iga and Kōga regions of Japan were famous for their shinobi in the 1400s and 1500s.",
	"Throwing stars are called shuriken; many were meant to distract or slow an enemy, not to kill.",
	"Sumi-e is Japanese ink-wash painting: black ink thinned with water to make every shade of grey.",
]
