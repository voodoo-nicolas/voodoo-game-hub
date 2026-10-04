extends RefCounted

## Would You Rather: a shuffled deck of two-way dilemmas, in English or
## Spanish. The table votes by tapping A or B; the deck reshuffles when it
## runs out. Pure logic, no Nodes.

const CARDS_PATH := "res://scripts/games/would_you_rather/would_you_rather_cards.json"
const DECKS := ["classic", "spicy", "mixed"]

var cards: Dictionary = {}
var deck: Array = []
var deck_name := "classic"
var lang := "en"
var current: Array = ["", ""]
var votes: Array = [0, 0]
var played: int = 0

func load_cards(path: String = CARDS_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	cards = parsed
	return true

func start(p_deck: String, p_lang: String, rng: RandomNumberGenerator) -> void:
	deck_name = p_deck
	lang = p_lang
	deck = []
	played = 0
	next_card(rng)

func _refill(rng: RandomNumberGenerator) -> void:
	var pool: Array = []
	for key in (["classic", "spicy"] if deck_name == "mixed" else [deck_name]):
		for c in cards.get(key, []):
			var pair: Array = c.get(lang, c.get("en", ["", ""]))
			pool.append(pair)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	deck = pool

func next_card(rng: RandomNumberGenerator) -> void:
	if deck.is_empty():
		_refill(rng)
	current = deck.pop_back() if not deck.is_empty() else ["?", "?"]
	votes = [0, 0]
	played += 1

func vote(side: int) -> void:
	votes[side] += 1

func percent(side: int) -> int:
	var total: int = votes[0] + votes[1]
	return 0 if total == 0 else int(round(100.0 * votes[side] / total))
