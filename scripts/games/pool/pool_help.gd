extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "pool"
const TITLE := "Pool"
const GOAL := "8-ball: pot all of your group — solids (1-7) or stripes (9-15) — then sink the black 8."
const HOW := [
	"Drag on the table to aim: the cue points from the white ball towards your finger. ⟲ ⟳ nudge the aim a tiny bit for fine shots.",
	"The guide shows the first ball you'll hit (a ghost ball where they touch) and the line it will roll along. It turns pink if that ball isn't yours to hit.",
	"Set the power on the bar, then tap 🎱 Shoot.",
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
]
const STATS := ["Wins", "Losses", "Best streak", "Wins (Easy)", "Wins (Normal)", "Wins (Hard)", "Balls potted", "Longest run", "2-player games"]
