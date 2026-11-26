extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Describes what hue_hunt_game.gd does now (solo, phase 3); then `hub.py i18n`.

const ID := "hue_hunt"
const TITLE := "Camera Hunter"
const GOAL := "Find real things whose colour matches the target, photograph them and tap the right spot."
const HOW := [
	"Point the camera at something that matches the colour and press 📸 to freeze the picture.",
	"Tap the spot to sample: the game reads a small square there and shows your % match.",
	"Lock it in, or retake as often as you like before you lock.",
	"Close matches go into your Color Book.",
	"Time Attack: 5 colours in 3 minutes; your score is the sum of your match %.",
	"Free Hunt: pick any colour from the book. Daily Color: one colour for everyone each day.",
	"Twists: Duo (two colours in one photo, tap both), Mix (find the blend of two), Opposite (find the complement), Blind (name only) and Darkest / Lightest / Most vivid.",
	"🛟 Helps (solo): Hot / Cold, Peek, Second Chance and More Time. You have 3; one comes back 24 hours after you last used one.",
	"With friends (2-8 phones): everyone hunts the same colour. The first close lock-in scores ⚡ First Close (+1) and starts a 30-second countdown; the closest photo scores 🥇 Closest (+1). Darkest / Lightest / Most vivid rounds give the winner 2.",
	"After each round every photo is shown, worst to best. Tap 🚩 on a photo that shows people or shouldn't be there: if most players flag it, it's out.",
	"Object rounds (with friends): find a thing, a shape or something special (\"a teacup\", \"a pentagon\", \"something older than you\"). The phone can't tell what's in a photo, so the others vote Yes or No on each one. 🔎 First Find (+1) = the first photo that counts; 😂 Best Find (+1) = the favourite.",
	"Power-ups (with friends): everyone starts with one; whoever is last after a round gets another, 3 at most per match. 🌡 Hot / Cold, 👁 Peek, 🔁 Second Chance. The host can switch them off.",
]
const TIPS := [
	"Good, even daylight gives the truest colours.",
	"Avoid shiny spots and shadows: tap a flat, evenly lit part.",
	"Photos never leave your phone and are never saved.",
	"▶ Resume brings back a Time Attack. Free Hunt and Daily Color are one photo each, so there is nothing to resume.",
]
const STATS := ["Best score", "Best match", "Colors found", "Easy colors found", "Color families found",
	"Best daily match", "Hunts played", "Wins without power-ups", "Object rounds won"]

## Our own badges below cover these, so no generic tier badges for them
## (keeps the game within 1000 points, STANDARDS §3b).
const NO_TIER_BADGES := ["Colors found", "Easy colors found", "Color families found", "Best match",
	"Best daily match", "Wins without power-ups", "Object rounds won"]

## Owner's list (2026-11-26): 10/50/100 colours, a 95%+ match, all easy
## colours (35 of them), one colour per family (10: nine hues + neutrals),
## win a match without a power-up, win an Object round (First or Best Find).
const ACHIEVEMENTS := [
	{"id": "found10", "icon": "🎨", "title": "Colour Spotter", "desc": "Find 10 colours for your Color Book", "key": "Colors found", "at": 10},
	{"id": "found50", "icon": "📖", "title": "Colour Collector", "desc": "Find 50 colours for your Color Book", "key": "Colors found", "at": 50},
	{"id": "found100", "icon": "🌈", "title": "Colour Hunter", "desc": "Find 100 colours for your Color Book", "key": "Colors found", "at": 100},
	{"id": "match95", "icon": "🎯", "title": "Spot On", "desc": "Get a 95% match or better", "key": "Best match", "at": 95},
	{"id": "all_easy", "icon": "✅", "title": "Easy Does It", "desc": "Find every easy colour", "key": "Easy colors found", "at": 35},
	{"id": "rainbow", "icon": "🌈", "title": "Rainbow", "desc": "Find a colour in every family", "key": "Color families found", "at": 10},
	{"id": "no_powers", "icon": "💪", "title": "No Help Needed", "desc": "Win a match with friends without using a power-up", "key": "Wins without power-ups", "at": 1},
	{"id": "object_win", "icon": "🔎", "title": "Sharp Eyes", "desc": "Win First Find or Best Find in an Object round", "key": "Object rounds won", "at": 1},
]
