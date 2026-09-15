extends RefCounted

const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const RANK_VALUES := {
	"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8,
	"9": 9, "10": 10, "J": 11, "Q": 12, "K": 13, "A": 14,
}

const ROUNDS := [
	{"name": "Red or Black", "drink": 1},
	{"name": "Higher or Lower", "drink": 2},
	{"name": "Inside or Outside", "drink": 3},
	{"name": "Guess the Suit", "drink": 4},
]

var deck: Array = []
var num_players: int = 2
var round_index: int = 0
var current_player: int = 0
var player_cards: Array = []  # one card-history array per player
var game_over: bool = false

func reset(players: int) -> void:
	num_players = max(players, 1)
	_build_deck()
	round_index = 0
	current_player = 0
	game_over = false
	player_cards = []
	for i in range(num_players):
		player_cards.append([])

func _build_deck() -> void:
	deck.clear()
	for suit in SUITS:
		for rank in RANKS:
			deck.append({"rank": rank, "suit": suit, "value": RANK_VALUES[rank]})
	deck.shuffle()

func current_round() -> Dictionary:
	return ROUNDS[round_index]

## guess is "red"/"black" (round 0), "higher"/"lower" (round 1),
## "inside"/"outside" (round 2, ties count as outside), or a suit glyph (round 3).
## Returns {card, correct, drink_amount, give, round_finished, game_finished}.
func answer(guess: String) -> Dictionary:
	if deck.is_empty():
		_build_deck()  # reshuffle mid-game if a big player count ever exhausts 52 cards

	var card: Dictionary = deck.pop_back()
	var history: Array = player_cards[current_player]

	var correct := false
	match round_index:
		0:
			var color := "red" if (card.suit == "♥" or card.suit == "♦") else "black"
			correct = guess == color
		1:
			var prev: Dictionary = history[0]
			correct = card.value != prev.value and (guess == "higher") == (card.value > prev.value)
		2:
			var lo: int = min(history[0].value, history[1].value)
			var hi: int = max(history[0].value, history[1].value)
			var inside: bool = card.value > lo and card.value < hi
			correct = (guess == "inside") == inside
		3:
			correct = guess == card.suit

	history.append(card)
	var drink: int = ROUNDS[round_index].drink

	current_player += 1
	var round_finished := false
	var game_finished := false
	if current_player >= num_players:
		current_player = 0
		round_index += 1
		round_finished = true
		if round_index >= ROUNDS.size():
			game_finished = true
			game_over = true

	return {
		"card": card,
		"correct": correct,
		"drink_amount": drink,
		"give": correct,
		"round_finished": round_finished,
		"game_finished": game_finished,
	}
