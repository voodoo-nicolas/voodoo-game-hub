extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "roman_voyage"
const TITLE := "Voyage of Aeneas"
const GOAL := "Lead the Trojan fleet from fallen Troy to the mouth of the Tiber in Italy with as many ships and men as you can."
const HOW := [
	"Every stop on the way is a scene from Virgil's Aeneid. Read it, then tap one of the choices.",
	"⛵ Ships, 👥 Crew and 🌾 Food are your fleet. Each ship carries at most 20 men, so losing a ship loses men too.",
	"Between two stops the fleet eats. If the food runs out, some men desert.",
	"🌿 Favor is the gods' goodwill. Some choices cost favor: praying to Neptune can calm a storm.",
	"⚡ Wrath is Juno's anger. The higher it is, the more storms you meet and the more ships each storm sinks.",
	"Some choices are a gamble: they can go well or badly.",
	"You lose if your last ship sinks or your last man is gone. Reach the Tiber to win.",
	"Score: 100 per ship, 3 per man, 2 per food, 20 per favor, minus 10 per wrath; ×1.5 on Normal, ×2 on Hard.",
	"📅 Daily Voyage: today's seas are the same for everyone (Normal).",
	"🎯 Story: each stop shows its goal on the way to Italy. The Chronicle keeps every myth you meet, on any voyage.",
	"📅 Daily objective: a new one every day. 🗓 Weekly objective: counted over all your voyages that week. Each one done earns laurels 🌿 (1 a day, 3 a week). See them on the Home screen under 🎯 Objectives.",
	"⏸ pauses; Resume on the Home screen carries on the same voyage.",
]
const TIPS := [
	"Listen to the seers: what Helenus tells you can save ships later.",
	"Keep some favor for Juno's great storm.",
	"Honouring the gods costs food now and saves ships later.",
	"Lowering Juno's wrath makes the open sea much safer.",
]
const STATS := ["Wins", "Losses", "Best score", "Most ships at the Tiber", "Voyages won (Easy)", "Voyages won (Normal)", "Voyages won (Hard)", "Daily voyages won", "Underworld visits", "Myths met", "Laurels", "Myths in the Chronicle"]
const NO_TIER_BADGES := ["Voyages won (Easy)", "Voyages won (Normal)", "Daily voyages won", "Most ships at the Tiber", "Myths met", "Laurels", "Myths in the Chronicle", "Underworld visits"]

const ACHIEVEMENTS := [
	{"id": "landfall", "icon": "🏛", "title": "Founder", "key": "Wins", "at": 1, "xp": 25},
	{"id": "hard_voyage", "icon": "🦅", "title": "Pius Aeneas", "key": "Voyages won (Hard)", "at": 1, "xp": 50},
	{"id": "underworld", "icon": "🌿", "title": "The Golden Bough", "key": "Underworld visits", "at": 1, "xp": 25},
	{"id": "laurels10", "icon": "🌿", "title": "Crowned in Laurel", "key": "Laurels", "at": 10, "xp": 50},
	{"id": "chronicle", "icon": "📜", "title": "Chronicler", "key": "Myths in the Chronicle", "at": 20, "xp": 50},
	{"id": "full_fleet", "icon": "⛵", "title": "Whole Fleet", "key": "Most ships at the Tiber", "at": 10, "xp": 50},
]

## Learning hook (STANDARDS §15): checked facts only. More facts appear in play, one per stop.
const FACTS := [
	"The Aeneid is an epic poem by Virgil, written in Latin between about 29 and 19 BC, under the emperor Augustus.",
	"Most Roman gods matched Greek ones: Jupiter was Zeus, Juno Hera, Neptune Poseidon, Venus Aphrodite, Mars Ares, Mercury Hermes.",
	"Romans told two founding stories: Aeneas the Trojan, and his descendants Romulus and Remus, raised by a she-wolf.",
	"Classical Latin had no letter U: it was written V, as in IVPPITER on old inscriptions.",
]
