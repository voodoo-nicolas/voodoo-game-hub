extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "sevens"
const TITLE := "Sevens"
const GOAL := "Be the first to play all your cards."
const HOW := [
	"You and three computers each get 13 cards. Whoever holds the 7♦ must play it first.",
	"After that, on your turn play one card: any 7 (opening that suit), or the next card up or down from the cards already on the table in a suit that is open, so 6 or 8 next to a 7, then 5 or 9, and so on.",
	"Playable cards glow in your hand. If you have no playable card you pass automatically. Passing isn't a penalty here, but it means you are stuck while others get ahead.",
	"The first player to play every card wins. When somebody goes out, each other hand is worth the ranks of its cards left (Ace 1 ... King 13): fewer is better.",
	"Easy plays any legal card, Normal plays to keep its own runs open, Hard also tries not to hand over cards the others need.",
	"A game in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Hold back the 6 or 8 that others are waiting for, as long as you can: blocking is the heart of the game.",
	"Play a card when it opens up several of your own: a chain you hold can then go out in a few turns.",
	"Don't open a suit with a 7 unless you must or you hold much of the suit.",
]
const STATS := ["Wins", "Losses", "Best streak", "Wins without passing"]

const ACHIEVEMENTS := [
	{"id": "nopass", "icon": "7️⃣", "title": "Smooth Sailing", "desc": "Win a game without passing once", "key": "Wins without passing", "at": 1},
	{"id": "nopass2", "icon": "🃏", "title": "Never Stuck", "desc": "Win 5 games without passing", "key": "Wins without passing", "at": 5},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Sevens is also known as Fan Tan, Parliament, or Domino in different parts of the world.",
]
