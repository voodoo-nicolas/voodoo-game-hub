extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Written from what the game's code does; strings go through tools/i18n/es.json.

const ID := "creation"
const TITLE := "Creation"
const GOAL := "Start with Earth, Fire, Wind and Water. Combine items to discover everything: 263 in all."
const HOW := [
	"Drag an item from the shelf onto the table, or just tap it. On a touch screen, hold an item and then drag it.",
	"Drag one item onto another to combine them, or tap one item on the table and then another. Order doesn't matter, and the same item twice is a valid pair (Water + Water).",
	"A new combination gives you a new item for good: the shelf keeps one of everything, so you never run out. One recipe can give more than one item.",
	"If nothing happens, the pair is remembered, so you won't repeat it. Nothing is ever lost.",
	"Double-tap an item on the table to copy it. Drag it to the 🗑 to remove it, or tap Clear.",
	"The shelf has search, sorting (recent, A–Z, tier) and a tier filter. Tap an item to see how many of its recipes you haven't found yet.",
	"💡 shows one ingredient of something you haven't found. You get 3 hints a day; asking again about the same thing shows its other ingredient.",
	"📖 lists your progress in each of the 5 tiers: Nature, Life, Early Civilization, Industry & Modern Life, Space & Future.",
	"Your discoveries are saved automatically every time. ⚙ switches the item names between English and Spanish, and the light and dark theme.",
]
const TIPS := [
	"Start by combining each element with itself and with the others.",
	"Stuck? Think about where things come from: what is a tree made of, what burns, what grows.",
	"Try the same item twice: two of something often make something bigger (House + House = Village).",
	"Tools open up a lot: once you can make a Tool, most of the human world follows.",
]
const STATS := ["Discoveries", "Hints used", "Pairs tried"]

## Collection goals (the 🏅 achievements).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "⚗️", "title": "Apprentice", "key": "Discoveries", "at": 25},
	{"id": "goal2", "icon": "🔥", "title": "Alchemist", "key": "Discoveries", "at": 75},
	{"id": "goal3", "icon": "🌍", "title": "World Builder", "key": "Discoveries", "at": 150},
	{"id": "goal4", "icon": "🚀", "title": "Creator", "key": "Discoveries", "at": 220},
	{"id": "goal5", "icon": "🌌", "title": "Everything", "key": "Discoveries", "at": 263},
]

## Learning hook (STANDARDS §15): one shows on the Landing's "Did you know?"
## card. Checked facts only.
const FACTS := [
	"Lightning heats the air around it to about 30,000 °C, several times hotter than the surface of the Sun.",
	"Glass is made by melting sand at very high temperatures.",
	"Honey is made by bees from the nectar of flowers.",
	"The white cloud above boiling water isn't steam: steam is invisible. What you see is tiny droplets of water.",
	"A rainbow appears when sunlight is split into its colors by raindrops.",
	"Paper was invented in China more than 2,000 years ago.",
	"Charcoal is wood heated with very little air. It burns hotter than the wood it came from.",
]
