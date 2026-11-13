extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "tarot"
const TITLE := "Tarot"
const GOAL := "Sit with the fortune teller, draw cards from the Major Arcana and read what they say. Collect all 22."
const HOW := [
	"Pick a reading: the Card of the Day (the same card all day), a Three-Card spread (past, present, future) or a Five-Card spread (you, the challenge, the past, the future, the outcome).",
	"Think of a question, then tap each face-down card to turn it over.",
	"Tap a card to read what it means. A card can fall upright or reversed, and each way says something different.",
	"After the last card turns, the fortune teller sums up your reading.",
	"📖 opens your collection: every card you have turned, upright and reversed. Each one is saved.",
	"Come back each day for your Card of the Day to build a streak.",
	"⏸ pauses. A reading is quick, so there is nothing to save halfway: only your collection is kept.",
]
const TIPS := [
	"The Card of the Day is the same for everyone on the same day, and it doesn't change if you reopen the game.",
	"Three- and Five-Card readings are fresh every time, so ask as many questions as you like.",
	"A hard card is a warning, not a sentence. Every card has something useful to say.",
	"This is entertainment: tarot can't predict the future, so don't make big decisions with it.",
]
const STATS := ["Readings given", "Cards discovered", "Daily streak"]
## Checked facts about tarot itself (shown on the Landing as "Did you know?").
const FACTS := [
	"A tarot deck has 78 cards: 22 Major Arcana and 56 Minor Arcana.",
	"Tarot cards first appeared in northern Italy in the 1400s as a card game called tarocchi.",
	"The Major Arcana are numbered 0 to 21, and The Fool is number 0.",
	"Fortune telling with tarot became popular in the 1700s, long after the cards were invented.",
]
