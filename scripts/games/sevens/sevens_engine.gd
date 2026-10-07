extends RefCounted

## Sevens (Fan Tan): four players, 13 cards each. The player with the 7♦ starts.
## After that you may play any 7 to open a suit, or the next rank up or down in
## a suit that is open. No card you can play: you pass. The first to play every
## card wins. Pure logic, no Nodes.
## Cards are ints 0..51: rank = card % 13 + 1 (Ace = 1 ... King = 13),
## suit = card / 13 (0 ♠, 1 ♥, 2 ♦, 3 ♣).

const SEVEN_DIAMONDS := 2 * 13 + 6

var hands: Array = [[], [], [], []]
var low: Array = [0, 0, 0, 0]    # lowest rank on the table per suit (0 = suit not opened)
var high: Array = [0, 0, 0, 0]
var turn: int = 0
var passes: Array = [0, 0, 0, 0]
var winner: int = -1
var level: int = 1               # computer skill: 0 easy, 1 normal, 2 hard
var plays: int = 0

static func rank(c: int) -> int:
	return c % 13 + 1

static func suit(c: int) -> int:
	return c / 13

static func sort_hand(h: Array) -> void:
	h.sort_custom(func(a, b):
		var order := [0, 1, 3, 2]
		if suit(a) != suit(b):
			return order[suit(a)] < order[suit(b)]
		return rank(a) < rank(b))

func new_game(lvl: int, rng: RandomNumberGenerator) -> void:
	level = clampi(lvl, 0, 2)
	var deck: Array = range(52)
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	hands = []
	for p in 4:
		var h: Array = deck.slice(p * 13, (p + 1) * 13)
		sort_hand(h)
		hands.append(h)
	low = [0, 0, 0, 0]
	high = [0, 0, 0, 0]
	passes = [0, 0, 0, 0]
	winner = -1
	plays = 0
	for p in 4:
		if SEVEN_DIAMONDS in hands[p]:
			turn = p

func table_empty() -> bool:
	return plays == 0

func on_table(c: int) -> bool:
	var s := suit(c)
	return high[s] > 0 and rank(c) >= low[s] and rank(c) <= high[s]

func can_play_card(c: int) -> bool:
	var s := suit(c)
	var r := rank(c)
	if table_empty():
		return c == SEVEN_DIAMONDS
	if high[s] == 0:
		return r == 7
	return r == low[s] - 1 or r == high[s] + 1

func legal(p: int) -> Array:
	var out: Array = []
	for c in hands[p]:
		if can_play_card(c):
			out.append(c)
	return out

## Plays a card; false if it isn't allowed or isn't p's turn.
func play(p: int, c: int) -> bool:
	if winner >= 0 or p != turn or not c in hands[p] or not can_play_card(c):
		return false
	var s := suit(c)
	var r := rank(c)
	hands[p].erase(c)
	if high[s] == 0:
		low[s] = r
		high[s] = r
	elif r < low[s]:
		low[s] = r
	else:
		high[s] = r
	plays += 1
	if hands[p].is_empty():
		winner = p
		return true
	turn = (turn + 1) % 4
	return true

## Pass (only when nothing is playable).
func pass_turn(p: int) -> bool:
	if winner >= 0 or p != turn or not legal(p).is_empty():
		return false
	passes[p] += 1
	turn = (turn + 1) % 4
	return true

## Points left in a hand (Ace 1 ... King 13).
func hand_points(p: int) -> int:
	var t := 0
	for c in hands[p]:
		t += rank(c)
	return t

# ---------- computer players ----------

## How many more of p's cards would become playable in sequence after playing c.
func _unlocks(p: int, c: int) -> int:
	var s := suit(c)
	var r := rank(c)
	var n := 0
	if r == 7:
		# opening a suit unlocks both directions
		for k in range(1, 7):
			if (s * 13 + (7 - k) - 1) in hands[p] and (7 - k) >= 1:
				n += 1
			else:
				break
		for k in range(1, 7):
			if 7 + k <= 13 and (s * 13 + (7 + k) - 1) in hands[p]:
				n += 1
			else:
				break
		return n
	var step := -1 if r < 7 else 1
	var q := r + step
	while q >= 1 and q <= 13 and (s * 13 + q - 1) in hands[p]:
		n += 1
		q += step
	return n

func cpu_play(p: int) -> int:
	var opts := legal(p)
	if opts.is_empty():
		return -1
	if level == 0 or opts.size() == 1:
		return opts[randi() % opts.size()]
	var best: int = opts[0]
	var best_score := -1000.0
	for c in opts:
		var sc := float(_unlocks(p, c)) * 2.0
		var r := rank(c)
		# Opening a suit with a 7 helps everybody: do it late unless it unlocks my own cards.
		if r == 7:
			sc -= 1.5
		if level == 2:
			# Hold the card that others need: don't hand over the next rank if I can't use it.
			var nxt := r - 1 if r < 7 else (r + 1 if r > 7 else -1)
			if nxt >= 1 and nxt <= 13 and not (suit(c) * 13 + nxt - 1) in hands[p]:
				sc -= 1.0
			# Getting rid of high cards first keeps the hand's penalty low if somebody else goes out.
			sc += float(r) * 0.05
		sc += randf() * 0.3
		if sc > best_score:
			best_score = sc
			best = c
	return best
