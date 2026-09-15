extends RefCounted

const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

## title/desc pairs shown on reveal, e.g. "TWO IS YOU" / "Give 1 drink to another player."
const RULES := {
	"A": {"title": "MAKE A RULE", "desc": "Create a new rule everyone must follow for the rest of the game."},
	"2": {"title": "TWO IS YOU", "desc": "Give 1 drink to another player."},
	"3": {"title": "THREE IS ME", "desc": "You drink 1."},
	"4": {"title": "FLOOR", "desc": "Last hand to touch the floor drinks."},
	"5": {"title": "GUYS", "desc": "All guys drink."},
	"6": {"title": "CHICKS", "desc": "All chicks drink."},
	"7": {"title": "HEAVEN", "desc": "Last hand up drinks."},
	"8": {"title": "PICK A MATE", "desc": "Choose a drinking buddy — they drink whenever you do, for the rest of the game."},
	"9": {"title": "BUST A RHYME", "desc": "Say a word. Go around rhyming until someone fails — they drink."},
	"10": {"title": "CATEGORIES", "desc": "Name a category. Go around with examples until someone repeats or hesitates — they drink."},
	"J": {"title": "NEVER HAVE I EVER", "desc": "Say something you've never done. Anyone who has, drinks."},
	"Q": {"title": "QUESTION MASTER", "desc": "Ask a question. Whoever answers you drinks — until the next Q is drawn."},
}

var deck: Array = []  # circle of {id, rank, suit}, shrinks as cards are picked
var king_count: int = 0
var current_player: int = 0
var num_players: int = 4
var game_over: bool = false

func reset(players: int) -> void:
	num_players = max(players, 1)
	deck.clear()
	var id := 0
	for suit in SUITS:
		for rank in RANKS:
			deck.append({"id": id, "rank": rank, "suit": suit})
			id += 1
	deck.shuffle()
	king_count = 0
	current_player = 0
	game_over = false

## Removes the card with this id from the circle (order-independent — the deck was
## already shuffled, so which card a player taps doesn't affect randomness).
## Returns {rank, suit, title, desc, is_king, king_number, deck_empty}.
func pick_by_id(card_id: int) -> Dictionary:
	var index := -1
	for i in range(deck.size()):
		if deck[i].id == card_id:
			index = i
			break
	var card: Dictionary = deck[index]
	deck.remove_at(index)

	var title: String
	var desc: String
	var king_number := 0
	if card.rank == "K":
		king_count += 1
		king_number = king_count
		if king_count >= 4:
			title = "DRINK THE CUP!"
			desc = "You drew the 4th king. Chug the cup!"
			game_over = true
		else:
			title = "KING'S CUP"
			desc = "Pour a bit of your drink into the cup. (King %d/4)" % king_count
	else:
		var rule: Dictionary = RULES.get(card.rank, {"title": "", "desc": ""})
		title = rule.title
		desc = rule.desc

	if deck.is_empty():
		game_over = true

	return {
		"rank": card.rank,
		"suit": card.suit,
		"title": title,
		"desc": desc,
		"is_king": card.rank == "K",
		"king_number": king_number,
		"deck_empty": deck.is_empty(),
	}

func advance_player() -> void:
	current_player = (current_player + 1) % num_players
