extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Describe what this game's code actually does; then run `hub.py i18n`.

const ID := "trace_it"
const TITLE := "Trace It"
const GOAL := "Learn to draw by tracing: the camera shows your paper with the picture on top, so you can follow its lines with your pencil."
const HOW := [
	"Prop the phone 25-35 cm above the paper, camera facing down (on a stack of books, a glass or a stand). Good light, no hand shadow.",
	"Free mode: pick a photo from your gallery, take one with the camera, or a drawing from one of the studies: warm-up, golden ratio, perspective, ornament, shading techniques and drawing styles. Each study has a short 📖 lesson.",
	"Place the picture: drag with one finger; pinch, turn and move it with two.",
	"Tap 🔒 Lock before you draw, so your hand can't move the picture. Hold 🔒 to unlock.",
	"The tools: opacity, the look (photo, gray, lines, inverted, hatching, dots), the line colour, flips, and guides -- a grid, the golden ratio lines or the golden spiral.",
	"🪜 Steps: draw it the way artists do -- big shapes first, then the main lines, then the details and the shading. Next shows the next step. A photo's shading can be tones, hatching or dots.",
	"Tap ✓ Done when your drawing is finished.",
	"🎯 Accuracy check (Relaxed / Normal / Strict, or Off for free sketching): when you lock, the camera photographs the blank paper; after ✓ Done it photographs your drawing and shows how much landed on the lines, a map of what was on, off and missed, and what to work on.",
]
const TIPS := [
	"Draw lightly at first: early lines are guides you can erase or draw over.",
	"Turn the opacity down as you go, to see your own lines better.",
	"On dark paper, use white lines.",
	"If the picture slowly zooms in and out by itself, the camera is refocusing: tap 📷 to try another camera -- the wide one often has fixed focus.",
	"For the accuracy check, don't move the phone or the paper while you draw, and use a pen or a dark pencil.",
	"Your pictures never leave your phone.",
]
const STATS := ["Drawings finished", "Time drawing", "Photos traced", "Accuracy checks", "Best accuracy"]
