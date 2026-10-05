extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Describe what this game's code actually does; then run `hub.py i18n`.

const ID := "trace_it"
const TITLE := "Trace It"
const GOAL := "Learn to draw by tracing: the camera shows your paper with the picture on top, so you can follow its lines with your pencil."
const HOW := [
	"Prop the phone 25-35 cm above the paper, camera facing down (on a stack of books, a glass or a stand). Good light, no hand shadow.",
	"Free mode: pick a photo from your gallery, take one with the camera, or choose one of the drawings.",
	"Place the picture: drag with one finger; pinch, turn and move it with two.",
	"Tap 🔒 Lock before you draw, so your hand can't move the picture. Hold 🔒 to unlock.",
	"Opacity, the look (photo, gray, lines, inverted), the line colour, flips and a grid are in the tools.",
	"🪜 Steps: draw it the way artists do -- big shapes first, then the main lines, then the details and the shading. Next shows the next step.",
	"Tap ✓ Done when your drawing is finished.",
]
const TIPS := [
	"Draw lightly at first: early lines are guides you can erase or draw over.",
	"Turn the opacity down as you go, to see your own lines better.",
	"On dark paper, use white lines.",
	"Your pictures never leave your phone.",
]
const STATS := ["Drawings finished", "Time drawing", "Photos traced"]
