extends RefCounted

## Truth or Dare: players take turns; each picks Truth or Dare and gets a
## card from that pile (mild, or mild + spicy). A skipped card costs a
## point; done cards earn one. Pure logic, no Nodes.

const CARDS_PATH := "res://scripts/games/truth_or_dare/truth_or_dare_cards.json"

var cards: Dictionary = {}
var piles: Dictionary = {"truth": [], "dare": []}
var spicy := false
var lang := "en"
var players: Array = []    # names
var points: Array = []
var turn: int = 0
var card := ""
var kind := ""
var played: int = 0

func load_cards(path: String = CARDS_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	cards = parsed
	return true

func start(names: Array, p_spicy: bool, p_lang: String) -> void:
	players = names.duplicate()
	points = []
	points.resize(players.size())
	points.fill(0)
	spicy = p_spicy
	lang = p_lang
	turn = 0
	played = 0
	piles = {"truth": [], "dare": []}
	card = ""
	kind = ""

func _refill(k: String, rng: RandomNumberGenerator) -> void:
	var pool: Array = []
	var src: Dictionary = cards.get(k, {})
	for level in (["mild", "spicy"] if spicy else ["mild"]):
		for c in src.get(level, []):
			pool.append(str(c.get(lang, c.get("en", ""))))
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	piles[k] = pool

func draw(k: String, rng: RandomNumberGenerator) -> String:
	if piles[k].is_empty():
		_refill(k, rng)
	kind = k
	card = piles[k].pop_back() if not piles[k].is_empty() else "?"
	return card

## The player finished (true) or skipped (false) their card; next player's turn.
func finish(done: bool) -> void:
	points[turn] += 1 if done else -1
	played += 1
	card = ""
	turn = (turn + 1) % players.size()
