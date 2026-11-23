extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "truco"
const TITLE := "Truco Argentino"
const GOAL := "Be first to 15 points against the computer, winning hands with your cards, your calls and a good bluff."
const HOW := [
	"Spanish cards, 3 each. A hand is the best of three tricks: tap a card to play it, the higher card takes the trick. A tie is a parda.",
	"Order, best first: 1 of espadas, 1 of bastos, 7 of espadas, 7 of oros, all the 3s, the 2s, 1 of copas and oros, the 12s, 11s, 10s, 7 of copas and bastos, the 6s, 5s and 4s.",
	"Win two tricks to win the hand. If the first is a tie, the second decides; if the second is a tie, the first decides; if all tie, the \"mano\" (the player who leads) wins.",
	"Envido (first trick only): two cards of one suit count 20 plus their numbers (10, 11 and 12 count 0), otherwise your best single card counts. Call Envido (2 points), Real envido (3) or Falta envido (the points the leader still needs). The other side answers Quiero or No quiero; a refusal gives the caller 1 point (or the earlier calls).",
	"Truco raises what the hand is worth: Truco 2, Retruco 3, Vale cuatro 4. A refusal gives the caller the points of the call before. Only the player who accepted may raise next.",
	"Al mazo: go to the deck and give up the hand. The other player takes the points at stake (1 before any truco).",
	"This version has no Flor.",
]
const TIPS := [
	"Count your envido before you play your first card: two cards of one suit, a 7 and a 6, make 33.",
	"A strong card kept for the last trick is worth more than a strong card thrown early.",
	"A truco call is also a bluff. Watch how often the computer calls with a weak hand.",
]
const STATS := ["Wins", "Losses", "Best streak", "Hands won", "Envidos won"]
