extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd), written from what the code
## does (wilson_engine.gd, wilson_game.gd). Strings go through tools/i18n/es.json (`hub.py i18n`).

const ID := "wilson"
const TITLE := "Beached"
const GOAL := "Keep a sarcastic castaway alive on a tiny island. He will never escape. That's the joke."
const HOW := [
	"The island runs on your real clock. Day and night, the sun, the moon and its phase follow the real sky.",
	"Tap the sand to walk. Tap something (wreckage, a palm, the shallows, a pile of sticks) to see what he can do there.",
	"Actions take real minutes and keep going while you're away. Up to 5 wait in the list on the left; tap one to cancel it.",
	"Watch the bars: ❤ health, 🐟 food, ⚡ energy and 💧 water. Eat and drink from the 🎒 bag.",
	"While you're away food, water and energy never drop below 15, and health never drops.",
	"Sleep at night (💤). Better beds restore more energy: sand, frond bed, hammock, frond shelter. Two power naps a day (😴).",
	"At 0 energy he collapses on the sand. Sleep 6 hours on a hammock or better to wake up Rested (works faster).",
	"Craft in 🔨: rope, tools, a campfire, a hammock, a shelter. Some need a station like the campfire or the crafting stump.",
	"Every morning the sea washes something ashore, often a bottle with a note. The 📓 journal tells you what he did.",
]
const TIPS := [
	"Follow the 📜 goal at the top: it walks you through the first days.",
	"Lighting the first fire takes a few tries. That's normal. He's not great at this.",
	"Raw fish is food, but cooked fish won't make him sick.",
	"Drinking seawater makes you thirstier. Coconuts are the safe bet.",
]
const STATS := ["Most days survived"]
const FACTS := [
	"High tide comes back about every 12 hours and 25 minutes, because the Moon moves on a little each day.",
	"The Moon takes about 29.5 days to go from new moon to new moon.",
	"Drinking seawater makes you more dehydrated: your kidneys need extra water to get rid of the salt.",
	"Days are longest in December in the southern hemisphere and in June in the northern one.",
	"In the southern hemisphere the Moon looks mirrored: a waxing Moon is lit on the left.",
]
