extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "pool"
const TITLE := "Pool"
const GOAL := "8-ball: pot all of your group — solids (1-7) or stripes (9-15) — then sink the black 8."
const HOW := [
	"Drag on the table to aim: the cue points from the white ball towards your finger. ⟲ ⟳ nudge the aim a tiny bit for fine shots.",
	"The guide shows the first ball you'll hit (a ghost ball where they touch) and the line it will roll along. It turns pink if that ball isn't yours to hit.",
	"Tap the white ball next to ⟲ to pick where the cue hits it. Above the middle = top spin: after hitting a ball, the white ball follows it. Below = back spin: it comes back towards you. Left or right = side spin: it kicks that way off a cushion. The guide's faint line shows where the white ball will go.",
	"Set the power on the bar, then tap 🎱 Shoot. The cue doesn't aim for you: line up every shot yourself. Spin goes back to the middle after each shot.",
	"The break comes from behind the line. After the break, the first ball you pot makes that group yours; the other player gets the other group.",
	"Pot one of your balls and you shoot again. Otherwise it's the other player's turn.",
	"Fouls give the other player ball in hand — they drag the white ball anywhere, then shoot: potting the white, hitting nothing, or hitting a ball that isn't yours first.",
	"Pot the 8 after clearing your group to win. Pot it early — or foul while potting it — and you lose. An 8 potted on the break comes back to its spot.",
	"⏸ pauses; Resume on the Home screen sets the table up as it was before the last shot.",
]
const TIPS := [
	"Thin cuts are hard: pick balls that are nearly straight in line with a pocket.",
	"Softer is safer — a gentle shot that drops leaves the white ball close to the next one.",
	"With ball in hand, put the white straight behind your easiest ball.",
	"Back spin wears off as the white ball rolls: for a strong draw, hit harder or pick a ball close to the white.",
	"Straight-in shot? Hit dead centre and the white ball stops close by. Plain hits also roll on a little after the ball they hit.",
]
const STATS := ["Wins", "Losses", "Best streak", "Wins (Easy)", "Wins (Normal)", "Wins (Hard)", "Balls potted", "Longest run", "Pots with spin", "2-player games"]

const ACHIEVEMENTS := [
	{"id": "spin10", "icon": "🌀", "title": "Spin Doctor", "key": "Pots with spin", "at": 10},
	{"id": "run5", "icon": "🎱", "title": "On a Roll", "key": "Longest run", "at": 5},
]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"When a moving ball hits a still ball of the same weight off-centre, they roll away at about a right angle (90°) to each other.",
	"A pool table's playing surface is twice as long as it is wide, and the diamonds on the rails mark quarters of the short side and eighths of the long side.",
	"A ball hit below its centre slides with back spin; the cloth's friction slowly turns that into forward roll, which is why a draw shot works best from close up.",
]
