extends RefCounted

## How to Play text, stats and achievements for GameInfo (scripts/common/game_info.gd).
## Written from ancient_assassins_engine.gd / _game.gd; run `hub.py i18n` after a change.

const ID := "ancient_assassins"
const TITLE := "Amazonia"
const GOAL := "Throw your weapons across the water and bring your rival's health to zero before she does it to you."
const HOW := [
	"You see the fight over your assassin's shoulder; your rival waits on the island across the water. Players take turns.",
	"On your turn, hold anywhere and drag up or down to set the angle (the ruler on the left). Your aim always faces your rival and the power is the weapon's own: the angle is all you choose. Let go to throw.",
	"While you hold, the striped ribbon shows the first stretch of the arc. It does not show the wind: that part is up to you.",
	"After your first throw, its flight stays on screen as a see-through arc, with its angle on the ruler: aim a little higher or lower from there.",
	"Where it hits matters: head ×2 damage, body ×1, legs ×0.6. Both assassins start with 100 health.",
	"Weapons, at the bottom: 🗡 Javelin (34, unlimited), 🪓 Throwing Axe (46, 2 per fight; heavy, the wind barely moves it, but it doesn't fly far) and ⭕ Chakram (26, 3 per fight; fast and flat, the wind throws it around).",
	"Columns and rocks block throws; a throw that falls short lands in the water.",
	"📜 Contracts: 8 rivals in a row, each tougher than the last, with stars for the health you keep. vs Computer: Easy, Normal, Hard or Expert. 2 Players: pass the phone each turn. 🌐 Online: play a friend on another phone.",
	"⏸ pauses; Resume on the Landing carries on the same fight (not online fights).",
]
const TIPS := [
	"Throw once, then use the see-through arc: if it fell short, go a few degrees higher; if it flew over, lower.",
	"Into a strong wind, take the axe: it hardly drifts.",
	"The wind (top middle) blows along the line and changes every turn: arrows up carry your throw further, arrows down cut it short.",
	"The head is small but worth double: go for it once your throws land close.",
]
const STATS := ["Wins", "Losses", "Best streak", "Wins (Easy)", "Wins (Normal)", "Wins (Hard)", "Wins (Expert)",
	"Headshots", "Flawless wins", "Contracts completed", "Contract stars", "2-player games", "Online wins", "Online losses"]
## STANDARDS §3b (1000 points per game): these counters get no tier badges.
const NO_TIER_BADGES := ["Losses", "Wins (Easy)", "Wins (Normal)", "Wins (Hard)", "Wins (Expert)", "Contract stars",
	"2-player games", "Online losses", "Contracts completed", "Flawless wins"]

const ACHIEVEMENTS := [
	{"id": "first_blood", "icon": "🎯", "title": "First Contract", "key": "Contracts completed", "at": 1, "xp": 20},
	{"id": "all_contracts", "icon": "📜", "title": "Guild Master", "key": "Contracts completed", "at": 8, "xp": 80},
	{"id": "all_stars", "icon": "⭐", "title": "Perfect Ledger", "key": "Contract stars", "at": 24, "xp": 80},
	{"id": "headhunter", "icon": "💀", "title": "Headhunter", "key": "Headshots", "at": 25, "xp": 40},
	{"id": "untouched", "icon": "🛡", "title": "Untouched", "key": "Flawless wins", "at": 1, "xp": 30},
	{"id": "expert", "icon": "👑", "title": "Beat the Expert", "key": "Wins (Expert)", "at": 1, "xp": 50},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"With no wind and no air, a throw at 45° goes the farthest on level ground.",
	"Wind pushes a light weapon more than a heavy one of the same size: the same push moves less mass less.",
	"Ancient Greek javelin throwers wound a leather thong around the shaft; it set the javelin spinning and made it fly farther.",
	"The Franks were known for a throwing axe, the francisca, named after them.",
	"The chakram, a sharp-edged steel ring for throwing, comes from India.",
]
