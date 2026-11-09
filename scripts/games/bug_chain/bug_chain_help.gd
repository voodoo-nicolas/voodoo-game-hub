extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Describes what bug_chain_game.gd / bug_chain_engine.gd actually do.

const ID := "bug_chain"
const TITLE := "Bug Chain"
const GOAL := "Pop every bug in the crawling chain before it reaches the pit."
const HOW := [
	"Chains of beetles crawl along a garden path toward a pit. If a chain reaches its pit, you lose a life and the level starts again.",
	"Your launcher slides along the rail at the bottom. Touch and drag to move it; lift your finger to fire the bug it holds straight up.",
	"The bug you fire joins the chain where it hits. Three or more bugs of one colour touching pop.",
	"Tap the launcher to swap the bug you hold with the next one.",
	"When a pop leaves a gap and the bugs on both sides of it share a colour, the front part crawls back to close it. If that makes three, they pop too: a chain reaction, worth more points at every step.",
	"Each colour has its own shell pattern (spots, stripes, big spots, diamonds, dots or rings), so you can tell them apart by more than colour.",
	"Glowing bugs carry a power. Pop one to use it: 💣 blasts the bugs around it, ⏳ slows the chains, ⏪ sends them backwards, 🌈 gives you a rainbow bug that matches any colour.",
	"Clear a level to earn a bonus: 1000 points, more for every spare life and for later levels. An extra life comes every 25,000 points (up to 5).",
	"Campaign: 30 levels on 6 garden paths, 5 levels each. Your furthest level is kept for each difficulty; 📋 Level Select replays any level you have reached.",
	"Endless: wave after wave on random paths, faster and with more colours, until your lives run out.",
	"Easy has one colour fewer and slower chains; Hard has faster chains.",
	"🛟 Helps (pause menu, or ⏪ in the top bar): ⏪ pushes every chain back for a few seconds, 💣 pops the 8 bugs nearest each pit. You hold up to 3; one comes back 24 hours after the last one you used.",
	"Keyboard: arrow keys move, Space fires, X or Down swaps.",
]
const TIPS := [
	"Watch the bug nearest the pit: the closer it gets, the slower the chain crawls, but there is no time to waste.",
	"Set up chain reactions: pop the middle of a run whose ends share a colour.",
	"A shot only hits the first bug in its way. Look for gaps to reach a row behind.",
	"Swap early: the next bug is shown beside the launcher.",
	"Save the 🌈 rainbow bug for a spot where it makes a chain reaction.",
]
## Counting stats earn generic badges; keep them few (1000-point cap, STANDARDS §3b).
const STATS := ["Best score", "Levels cleared", "Highest level", "Longest chain reaction", "Most endless waves", "Games played"]

## Goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "level5", "icon": "🌱", "title": "Garden Keeper", "key": "Highest level", "at": 5},
	{"id": "level15", "icon": "🐌", "title": "Snail Shell Survivor", "key": "Highest level", "at": 15},
	{"id": "level30", "icon": "🏆", "title": "Bug Wrangler", "key": "Highest level", "at": 30},
	{"id": "chain3", "icon": "⛓", "title": "Chain Reaction", "key": "Longest chain reaction", "at": 3},
	{"id": "chain5", "icon": "💥", "title": "Domino Bugs", "key": "Longest chain reaction", "at": 5},
	{"id": "waves10", "icon": "♾", "title": "Endless Swarm", "key": "Most endless waves", "at": 10},
	{"id": "score100k", "icon": "⭐", "title": "Six Figures", "key": "Best score", "at": 100000},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"Beetles are the largest group of insects: about 400,000 species have been named.",
	"A beetle's hard front wings, the elytra, close over its back like a case and protect the thin flying wings folded underneath.",
	"Ladybirds (ladybugs) are beetles; many of them eat aphids, which is why gardeners welcome them.",
	"The bright colours of many ladybirds warn birds that they taste bad.",
	"Dung beetles roll balls of dung, and some species steer by the light of the Milky Way.",
	"All insects have six legs and three body parts: head, thorax and abdomen.",
]
