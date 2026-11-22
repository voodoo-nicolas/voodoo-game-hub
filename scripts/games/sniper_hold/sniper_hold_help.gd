extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd), written from
## sniper_hold_engine.gd / sniper_hold_game.gd. Run `hub.py i18n` after editing.

const ID := "sniper_hold"
const TITLE := "Sniper Hold"
const GOAL := "Take the right animals with clean shots, from far away, before the time or the rounds run out."
const HOW := [
	"Hold the phone sideways. You look out over one valley. Drag to aim; pinch (or drag the 🔭 slider on the right) to zoom the scope up to x12.",
	"The rifle never stays still: your aim sways with every breath and twitches with every heartbeat. Watch the breath line above 🫁: the green part at the end of each breath is the calm pause.",
	"Press and hold 🫁 to hold your breath: the sway almost stops. You can hold it only a few seconds (5 on Easy, 4 on Normal, 3 on Hard); then you gasp and shake until you get your breath back.",
	"Tap anywhere on the view (or FIRE) to shoot. Then the bolt takes a second before you can fire again. Every shot makes the animals look up; a miss close to them sends them running.",
	"Clean shot = heart and lungs, just behind the front leg: double points. Head shot: x1.5. Anywhere else on the body: x1. Every metre adds half a point.",
	"The bullet takes time to fly. On Normal and Hard it falls on long shots and the wind pushes it sideways: aim higher, into the wind, and ahead of a moving animal. The scope shows the range under the crosshair; on Normal it also shows how many mil-dots to hold over.",
	"Each dot on the scope is one mil: 1 metre at 1000 metres, 50 cm at 500 metres. The rifle is zeroed at 200 m.",
	"Bushes, rocks, logs and tree trunks stop bullets.",
	"Never shoot a fawn (the small spotted deer that follows its mother): -200 points, and in a Contract it fails the contract.",
	"Open Season: 3 minutes, 10 rounds, any animal but fawns. Easy has no drop and no wind; Normal x1.5 points; Hard x2 with more sway and strong wind.",
	"🎯 Contracts: 24 hunts in order, each asking for certain animals and forbidding others. One wrong animal fails it. Stars: 1 for finishing, +1 with no missed shot, +1 if every animal was a clean shot.",
	"🌿 Practice: no clock, no score, as many rounds as you like.",
	"PC: drag with the mouse to aim, wheel to zoom, right button or Space to hold your breath, click (or Enter) to shoot.",
	"⏸ pauses; Resume on the Home screen carries on the same hunt.",
]
const TIPS := [
	"Shoot in the calm pause at the end of a breath, or hold your breath only when the crosshair is already close.",
	"Zoom out to find animals, then zoom in on one.",
	"Wait for a broadside animal standing still: running ones are hard to lead.",
	"Long shot? Read the range, then put the right mil-dot (not the centre) on the target.",
]
const STATS := ["Best score", "Hunts played", "Animals taken", "Clean shots", "Longest shot (m)", "Contracts done", "Contract stars", "Shots fired"]
const NO_TIER_BADGES := ["Contracts done", "Contract stars", "Shots fired"]

const CHALLENGES := [
	{"id": "first_take", "icon": "🦌", "title": "First Take", "desc": "Take your first animal.", "xp": 20},
	{"id": "long_clean", "icon": "🎯", "title": "Four Hundred", "desc": "A clean shot from 400 metres or more.", "xp": 60},
	{"id": "all_contracts", "icon": "🏆", "title": "Master Hunter", "desc": "Finish all 24 contracts.", "xp": 150},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"A mil (milliradian) is one thousandth of a radian: it covers about 1 metre at 1000 metres, so shooters use it to judge distance and to hold over.",
	"A bullet starts falling the moment it leaves the barrel, like a dropped stone; sights are angled slightly up so the path crosses the line of sight at the zero distance.",
	"Red deer stags grow a new set of antlers every year and shed them in late winter or spring.",
	"A fox's tail is called a brush; foxes curl it around themselves to keep warm.",
	"Hares are born with fur and open eyes and can move about within hours; rabbits are born blind and hairless.",
	"Wild boar have a keen sense of smell but rather poor eyesight.",
	"Hunters aim for the heart and lungs, just behind the front leg, because it is the quickest and most humane shot.",
]
