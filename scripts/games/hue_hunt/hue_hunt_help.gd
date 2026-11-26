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
	"🛟 Helps: Hot / Cold, Peek, Second Chance and More Time. You have 3; one comes back 24 hours after you last used one.",
]
const TIPS := [
	"Good, even daylight gives the truest colours.",
	"Avoid shiny spots and shadows: tap a flat, evenly lit part.",
	"Photos never leave your phone and are never saved.",
]
const STATS := ["Best score", "Best match", "Colors found", "Best daily match", "Hunts played"]
