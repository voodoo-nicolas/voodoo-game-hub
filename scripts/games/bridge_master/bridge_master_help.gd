extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Describes what bridge_master_game.gd / bridge_master_engine.gd actually do.

const ID := "bridge_master"
const TITLE := "Bridge Master"
const GOAL := "Build a bridge across the gap that carries the vehicle to the other side, within the budget."
const HOW := [
	"Drag from a bolt to lay a piece of the chosen material. Red bolts are fixed to the rock; every piece adds a new bolt at its end.",
	"Road is what the vehicle drives on: join the two cliffs with road. Wood and steel hold the road up. Cables only pull, they cannot push.",
	"Each material has a longest piece and a price per metre. The cost of your bridge must stay within the level's budget.",
	"▶ Test sends the vehicle across. Pieces turn from green to yellow to red as they work harder, and snap when pushed past their strength.",
	"■ Edit stops the test and puts your bridge back. 🗑 removes pieces, ↶ undoes, 🧹 clears.",
	"Stars: 1 for crossing, 2 for a cheaper bridge, 3 for matching the engineer's bridge price or beating it.",
	"After a crossing, 🏋 Load test sends the vehicle again with more weight each time until the bridge gives way. The heaviest load ranks you on the leaderboard.",
	"300 levels in 10 chapters: the gaps get wider, the vehicles heavier, and steel, cables and steel road open on the way. Some levels have a rock pillar in the river to build on.",
	"⏭ Skip opens the next level. You hold up to 3 skips; one comes back 24 hours after the last one you used.",
	"Your bridge on each level is kept, so you can come back and build it cheaper.",
]
const TIPS := [
	"Triangles keep their shape; squares fold. Brace every square with a diagonal.",
	"A road alone sags and snaps. Hang it from a truss above or prop it from below.",
	"Higher trusses take less force in the top and bottom pieces, but their diagonals are longer.",
	"Use steel only where the pieces turn red; wood is cheaper everywhere else.",
	"Cables are cheap and strong when pulled: use them where a piece is stretched, never where it is squeezed.",
]
## Counting stats earn generic badges; keep them few (1000-point cap, STANDARDS §3b).
const STATS := ["Heaviest load (kg)", "Bridges built", "Campaign stars", "Highest level cleared", "Beat the engineer"]

## Goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "all", "icon": "🏆", "title": "Bridge Master", "key": "Highest level cleared", "at": 300},
	{"id": "load10", "icon": "🏋", "title": "Ten Tonnes", "key": "Heaviest load (kg)", "at": 10000},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"A triangle is the only polygon that cannot change shape without changing the length of a side. That is why bridges, cranes and roofs are full of them.",
	"In a truss, each piece is either pulled (tension) or squeezed (compression). Steel cables are strong in tension but useless in compression.",
	"The Warren truss, made of equal triangles, was patented in 1848 by the British engineers James Warren and Willoughby Monzani.",
	"In a simple bridge resting on its two ends, the top chord is squeezed and the bottom chord is stretched when a load stands in the middle.",
]
