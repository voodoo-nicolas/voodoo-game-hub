extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "hover_duel"
const TITLE := "Thrust - Zero-G Duels"
const GOAL := "Knock the other hovercraft's armour down to zero before it does the same to you."
const HOW := [
	"Hold the phone sideways. Push the stick the way you want to go: your hovercraft turns that way and speeds up. Let go and it drifts.",
	"⌨ On a computer the keys steer from the pilot's seat: W thrusts forward, A / D turn left / right, S brakes (arrows work too). Space or K fires, L missile, J mine, Shift or B boost.",
	"Fire shoots straight ahead, as fast as your guns reload. 🚀 Missile chases the other craft round corners. 💣 Mine drops behind you and blows up anyone who touches it after a second, you too.",
	"Water is slippery and fast; ice too. Grass grips. Climbing a hill slows you down a little; the ground never stops your shots, only grey cliffs do.",
	"Shots and missiles fly over hills, rivers and lava. Grey cliffs stop everything, and ramming them at speed hurts. Blasts leave burnt marks on the ground.",
	"Crates appear now and then: + repairs 30%, M gives 2 missiles, X gives 2 mines, S is a shield for 6 seconds.",
	"In the Ash Fields the rivers are lava: hovering over them burns.",
	"🗺 Campaign: the story of the Long Circuit. Beat 12 rivals across 6 lands, one at a time; each battle opens with a briefing. Win with more armour left for more stars (3 stars = 60% or more).",
	"🎯 Objectives: a new Daily objective every day and a Weekly one every Monday (2 Players doesn't count). Each pays medals (daily 1, weekly 3); medals unlock hull paints. The Story objective is your next Campaign battle.",
	"🛠 Hangar: every battle in the Campaign or vs Computer pays credits (more for wins, stars, a first win over a rival and bosses). Spend them on new ships or on upgrades: each ship is rated 1 to 10 for Attack, Armor, Acceleration, Top speed and Handling, and each rating takes up to 3 upgrades. Better ratings cost more. 2 Players always uses the Skimmer.",
	"⚡ Quick Duel = vs Computer on Normal. vs Computer: a new random land every battle. 2 Players: the left half of the screen is Player 1's, the right half Player 2's; each has a stick wherever the thumb lands and Fire / 🚀 / 💣 at the outer edge.",
	"⏸ pauses; Resume on the Home screen carries on the same battle.",
]
const TIPS := [
	"Fly sideways round the other craft while you shoot: it is harder to hit than one coming straight at it.",
	"Get on top of a hill and let them come to you.",
	"Missiles can't fly through cliffs: fire them across open ground or water.",
	"Lay a mine where you are going to circle back, then lead them over it.",
	"Grab repair crates before the other craft does.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "Campaign stars", "Campaign battles won", "Wins (Easy)", "Wins (Normal)", "Wins (Hard)", "Flawless wins", "Objectives done", "2-player games", "Credits earned"]
const NO_TIER_BADGES := ["Wins (Easy)", "Wins (Normal)", "Wins (Hard)", "Draws", "Flawless wins", "Objectives done", "2-player games"]

const ACHIEVEMENTS := [
	{"id": "first_rival", "icon": "🛸", "title": "First Rival", "key": "Campaign battles won", "at": 1, "xp": 25},
	{"id": "all_lands", "icon": "🗺", "title": "Every Land", "key": "Campaign battles won", "at": 12, "xp": 50},
	{"id": "star_pilot", "icon": "⭐", "title": "Star Pilot", "key": "Campaign stars", "at": 36, "xp": 50},
	{"id": "flawless", "icon": "🛡", "title": "Not a Scratch", "key": "Flawless wins", "at": 1, "xp": 25},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"A hovercraft floats on a cushion of air blown under it and held in by a flexible skirt, so it can cross water, mud, sand and ice.",
	"The first practical hovercraft, the SR.N1, crossed the English Channel in 1959.",
	"With almost no friction under it, a hovercraft slides on when it turns: pilots steer early and use the fans to brake.",
]
