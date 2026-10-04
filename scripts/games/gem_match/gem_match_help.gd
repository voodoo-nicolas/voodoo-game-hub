extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "gem_match"
const TITLE := "Gem Match"
const GOAL := "Score as many points as you can before the clock runs out."
const HOW := [
	"Swap two neighbouring gems to line up three or more of the same kind.",
	"You start with 60 seconds. Every match adds time: 3 in a row +2 s, 4 in a row +4 s, 5 or more +6 s.",
	"Match quickly to build a multiplier (up to ×8) — wait too long between matches and it drops back to ×1.",
	"4 in a row leaves a 💣 bomb. A bomb is a wild card: line it up with 2 or more alike gems and it explodes, clearing the 3×3 square around it.",
	"5 in a row clears every gem of that kind from the board.",
	"Gems fall into the gaps and new ones drop in; falls that make new matches are chains and score extra.",
	"💡 Hint shows you a swap that works.",
	"⏸ pauses the clock. A round is short, so it isn't saved for later.",
]
const TIPS := [
	"Keep moving — a fast ×5 is worth much more than one perfect move.",
	"Make matches near the bottom: more gems fall, so more chains happen.",
	"Save a bomb next to a crowded spot, then set it off with a match.",
]
const STATS := ["Best score", "Longest chain", "Games played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "💎", "title": "Gem Finder", "key": "Best score", "at": 2000},
	{"id": "goal2", "icon": "💍", "title": "Jeweler", "key": "Best score", "at": 8000},
	{"id": "goal3", "icon": "👑", "title": "Crown Jewels", "key": "Best score", "at": 20000},
]
