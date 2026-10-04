extends RefCounted

## Liar's Dice for 2-4 players (vs the computer: you = 0, computers = 1
## and 2; pass-and-play: everyone is a person). Everyone rolls
## their dice in secret. In turn, raise the bid -- "at least N dice on the
## whole table show face F" -- by bidding more dice, or the same number of a
## higher face. Or call "Liar!": if the bid was wrong the bidder loses a die,
## otherwise the caller does. Lose all your dice and you're out.
## Pure logic, no Nodes.

const START_DICE := 5

var PLAYERS: int = 3  # seats this game (kept in caps: it used to be a const)

var dice: Array = []          # per player: Array of faces
var counts: Array = []        # dice per player
var turn: int = 0
var bid := Vector2i.ZERO      # (quantity, face); zero = no bid yet this round
var bidder: int = -1
var last_result: Dictionary = {}
var winner: int = -1

func reset(n: int = 3) -> void:
	PLAYERS = n
	counts = []
	for p in PLAYERS:
		counts.append(START_DICE)
	winner = -1
	turn = 0
	new_round(0)

func new_round(starter: int) -> void:
	dice = []
	for p in PLAYERS:
		var d: Array = []
		for i in counts[p]:
			d.append(randi_range(1, 6))
		d.sort()
		dice.append(d)
	bid = Vector2i.ZERO
	bidder = -1
	turn = starter
	while counts[turn] == 0:
		turn = (turn + 1) % PLAYERS

func total_dice() -> int:
	var t := 0
	for c in counts:
		t += c
	return t

func alive(p: int) -> bool:
	return counts[p] > 0

func next_alive(p: int) -> int:
	var q := (p + 1) % PLAYERS
	while not alive(q):
		q = (q + 1) % PLAYERS
	return q

static func beats(new_bid: Vector2i, old: Vector2i) -> bool:
	if new_bid.x < 1 or new_bid.y < 1 or new_bid.y > 6:
		return false
	return new_bid.x > old.x or (new_bid.x == old.x and new_bid.y > old.y)

func place_bid(b: Vector2i) -> bool:
	if not beats(b, bid) or b.x > total_dice():
		return false
	bid = b
	bidder = turn
	turn = next_alive(turn)
	return true

func count_face(face: int) -> int:
	var n := 0
	for d in dice:
		n += d.count(face)
	return n

## The current player calls "Liar!" on the standing bid.
func challenge() -> Dictionary:
	var actual := count_face(bid.y)
	var bid_true: bool = actual >= bid.x
	var loser: int = turn if bid_true else bidder
	counts[loser] -= 1
	last_result = {"caller": turn, "bidder": bidder, "bid": bid, "actual": actual, "loser": loser, "dice": dice.duplicate(true)}
	var left: Array = []
	for p in PLAYERS:
		if alive(p):
			left.append(p)
	if left.size() == 1:
		winner = left[0]
	return last_result

## Who starts the next round: the loser (or the next player if they're out).
func next_starter() -> int:
	var l: int = last_result.loser
	return l if alive(l) else next_alive(l)

# ---------- computer ----------

## Expected number of `face` on the table from player p's point of view.
func expected(p: int, face: int) -> float:
	return dice[p].count(face) + (total_dice() - counts[p]) / 6.0

## Returns Vector2i bid, or Vector2i.ZERO to call "Liar!".
func cpu_decide(p: int) -> Vector2i:
	if bid != Vector2i.ZERO:
		var belief := expected(p, bid.y)
		if bid.x > belief + randf_range(0.6, 1.6):
			return Vector2i.ZERO
	# build the best raise: favour faces we hold
	var best := Vector2i.ZERO
	var best_margin := -INF
	for face in range(1, 7):
		var q: int = bid.x if face > bid.y else bid.x + 1
		q = max(q, 1)
		var margin := expected(p, face) - q
		if margin > best_margin:
			best_margin = margin
			best = Vector2i(q, face)
	if bid != Vector2i.ZERO and best_margin < -1.2:
		return Vector2i.ZERO
	if best.x > total_dice():
		return Vector2i.ZERO
	return best
