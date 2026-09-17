extends RefCounted

const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const RANK_VALUES := {
	"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8,
	"9": 9, "10": 10, "J": 11, "Q": 12, "K": 13, "A": 14,
}
const SUITS := ["♠", "♥", "♦", "♣"]

var p1_pile: Array = []  # [0] = next card to play
var p2_pile: Array = []
var game_over: bool = false
var winner: int = 0

func reset() -> void:
	var deck: Array = []
	for suit in SUITS:
		for rank in RANKS:
			deck.append({"rank": rank, "suit": suit, "value": RANK_VALUES[rank]})
	deck.shuffle()
	p1_pile = deck.slice(0, 26)
	p2_pile = deck.slice(26, 52)
	game_over = false
	winner = 0

func _draw(player: int, table: Array):
	var pile: Array = p1_pile if player == 1 else p2_pile
	if pile.is_empty():
		return null
	var card = pile.pop_front()
	table.append(card)
	return card

## Plays one full round, including any chained wars on ties. Returns
## {game_over, winner (this round only; 0 if game ended mid-war before a flip),
## p1_card, p2_card, war_happened, cards_won, ran_out (0/1/2)} -- some keys are
## absent when the round/game ended before a final face-up flip happened.
func play_round() -> Dictionary:
	if game_over:
		return {"game_over": true}

	var table: Array = []
	var p1_card = _draw(1, table)
	var p2_card = _draw(2, table)
	if p1_card == null:
		game_over = true
		winner = 2
		return {"game_over": true, "winner": 2, "ran_out": 1}
	if p2_card == null:
		game_over = true
		winner = 1
		return {"game_over": true, "winner": 1, "ran_out": 2}

	var war_happened := false
	while p1_card.value == p2_card.value:
		war_happened = true
		for i in range(3):
			if _draw(1, table) == null:
				game_over = true
				winner = 2
				return {"game_over": true, "winner": 2, "ran_out": 1, "war_happened": true}
		for i in range(3):
			if _draw(2, table) == null:
				game_over = true
				winner = 1
				return {"game_over": true, "winner": 1, "ran_out": 2, "war_happened": true}
		p1_card = _draw(1, table)
		if p1_card == null:
			game_over = true
			winner = 2
			return {"game_over": true, "winner": 2, "ran_out": 1, "war_happened": true}
		p2_card = _draw(2, table)
		if p2_card == null:
			game_over = true
			winner = 1
			return {"game_over": true, "winner": 1, "ran_out": 2, "war_happened": true}

	var round_winner: int = 1 if p1_card.value > p2_card.value else 2
	if round_winner == 1:
		p1_pile.append_array(table)
	else:
		p2_pile.append_array(table)

	if p1_pile.is_empty():
		game_over = true
		winner = 2
	elif p2_pile.is_empty():
		game_over = true
		winner = 1

	return {
		"game_over": game_over,
		"round_winner": round_winner,
		"p1_card": p1_card,
		"p2_card": p2_card,
		"war_happened": war_happened,
		"cards_won": table.size(),
	}
