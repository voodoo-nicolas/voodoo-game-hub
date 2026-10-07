extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "hearts"
const TITLE := "Hearts"
const GOAL := "Have the lowest score when someone reaches 100 points. Points are bad!"
const HOW := [
	"Four players: you and three computers (West on your left, North, East). Everyone gets 13 cards.",
	"Before each hand, pass 3 cards: to the left, then right, then across; every fourth hand nobody passes. Cards passed to you are raised.",
	"The 2♣ leads the first trick. Everyone must follow the suit that was led if they can; otherwise play anything.",
	"The highest card of the suit led wins the trick and leads the next one. Aces are high.",
	"Each heart you take is 1 point and the Q♠ is 13. You can't lead hearts until a heart (or the Q♠) has been played, and no points may be played on the first trick.",
	"Shoot the moon: take all 13 hearts and the Q♠ and you score 0 while everyone else gets 26.",
	"Your playable cards glow. ⏸ pauses and keeps the game; Resume on the Home screen carries on.",
]
const TIPS := [
	"Pass away the A♠ and K♠ if you don't hold enough low spades to protect them from the Queen.",
	"Get rid of a whole suit early: then you can throw your dangerous cards when that suit is led.",
	"Play under the winning card whenever you can — let someone else take the points.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "Moons shot", "Clean hands"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Each hand has 26 penalty points: 13 hearts plus 13 for the queen of spades.",
]
