extends RefCounted

## Hearts for four: you (seat 0) and three computers. Pass three cards
## (left, right, across, then keep), the 2♣ leads the first trick, follow
## suit if you can, and avoid points: each heart is 1, the Q♠ is 13. Take
## all 26 and you "shoot the moon": everyone else gets 26 instead. When
## someone reaches 100, the lowest score wins. Pure logic, no Nodes.
## Cards are ints 0..51: rank = card % 13 + 1 (Ace = 1), suit = card / 13
## (0 ♠, 1 ♥, 2 ♦, 3 ♣).

const SPADES := 0
const HEARTS := 1
const CLUBS := 3
const QUEEN_SPADES := 11  # suit 0, rank 12
const TWO_CLUBS := 3 * 13 + 1
const END_AT := 100
const PASS_DIRS := [1, 3, 2, 0]  # left, right, across, keep (seat offsets)

var hands: Array = [[], [], [], []]
var scores: Array = [0, 0, 0, 0]
var round_points: Array = [0, 0, 0, 0]
var hand_no: int = 0
var trick: Array = []        # [[seat, card], ...]
var leader: int = 0
var turn: int = 0
var hearts_broken := false
var tricks_played: int = 0
var last_trick: Array = []
var last_winner: int = -1
var passing := false

static func suit(c: int) -> int:
	return c / 13

## Ace high: 2..14.
static func power(c: int) -> int:
	var r := c % 13 + 1
	return 14 if r == 1 else r

static func points(c: int) -> int:
	if c == QUEEN_SPADES:
		return 13
	return 1 if suit(c) == HEARTS else 0

static func sort_hand(h: Array) -> void:
	h.sort_custom(func(a, b):
		var order := [0, 1, 3, 2]  # ♠ ♥ ♣ ♦ alternates colours
		if suit(a) != suit(b):
			return order[suit(a)] < order[suit(b)]
		return power(a) < power(b))

func new_game(rng: RandomNumberGenerator) -> void:
	scores = [0, 0, 0, 0]
	hand_no = 0
	deal(rng)

func pass_dir() -> int:
	return PASS_DIRS[hand_no % 4]

func deal(rng: RandomNumberGenerator) -> void:
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
	round_points = [0, 0, 0, 0]
	trick = []
	hearts_broken = false
	tricks_played = 0
	last_trick = []
	last_winner = -1
	passing = pass_dir() != 0
	if not passing:
		_start_play()

## Everyone passes at once: `picks` holds three cards per seat.
func do_pass(picks: Array) -> void:
	var d := pass_dir()
	for p in 4:
		for c in picks[p]:
			hands[p].erase(c)
	for p in 4:
		hands[(p + d) % 4].append_array(picks[p])
	for h in hands:
		sort_hand(h)
	passing = false
	_start_play()

func _start_play() -> void:
	for p in 4:
		if TWO_CLUBS in hands[p]:
			leader = p
	turn = leader

func legal(p: int) -> Array:
	var h: Array = hands[p]
	if trick.is_empty():
		if tricks_played == 0:
			return [TWO_CLUBS] if TWO_CLUBS in h else h.duplicate()
		if not hearts_broken:
			var non_hearts := h.filter(func(c): return suit(c) != HEARTS)
			if not non_hearts.is_empty():
				return non_hearts
		return h.duplicate()
	var led := suit(trick[0][1])
	var follow := h.filter(func(c): return suit(c) == led)
	if not follow.is_empty():
		return follow
	if tricks_played == 0:
		# No points on the first trick, unless that's all you have.
		var safe := h.filter(func(c): return points(c) == 0)
		if not safe.is_empty():
			return safe
	return h.duplicate()

## Plays a card; false if it isn't allowed. A fourth card finishes the trick.
func play(p: int, c: int) -> bool:
	if passing or p != turn or not c in legal(p):
		return false
	hands[p].erase(c)
	trick.append([p, c])
	if suit(c) == HEARTS or c == QUEEN_SPADES:
		hearts_broken = true
	if trick.size() < 4:
		turn = (turn + 1) % 4
		return true
	_finish_trick()
	return true

func trick_winner() -> int:
	var led := suit(trick[0][1])
	var best: Array = trick[0]
	for t in trick:
		if suit(t[1]) == led and power(t[1]) > power(best[1]):
			best = t
	return best[0]

func _finish_trick() -> void:
	var w := trick_winner()
	for t in trick:
		round_points[w] += points(t[1])
	last_trick = trick.duplicate()
	last_winner = w
	trick = []
	tricks_played += 1
	leader = w
	turn = w

func round_over() -> bool:
	return tricks_played == 13

## Adds the hand's points (handling a moon shot); returns the shooter or -1.
func score_round() -> int:
	var moon := -1
	for p in 4:
		if round_points[p] == 26:
			moon = p
	for p in 4:
		if moon >= 0:
			scores[p] += 0 if p == moon else 26
		else:
			scores[p] += round_points[p]
	hand_no += 1
	return moon

func game_over() -> bool:
	return scores.max() >= END_AT

## Seats with the lowest score.
func leaders() -> Array:
	var low: int = scores.min()
	var out: Array = []
	for p in 4:
		if scores[p] == low:
			out.append(p)
	return out

# ---------- computer players ----------

## The three cards a computer passes: the Q♠ and high spades, then high hearts, then high cards.
func cpu_pass(p: int) -> Array:
	var h: Array = hands[p].duplicate()
	h.sort_custom(func(a, b): return _danger(a) > _danger(b))
	return h.slice(0, 3)

static func _danger(c: int) -> int:
	if c == QUEEN_SPADES:
		return 100
	if suit(c) == SPADES and power(c) > 12:
		return 90 + power(c)
	if suit(c) == HEARTS:
		return 40 + power(c) * 3
	return power(c) * 2

func cpu_play(p: int) -> int:
	var opts := legal(p)
	if opts.size() == 1:
		return opts[0]
	if trick.is_empty():
		# Lead low, preferring suits other than spades while the Q♠ is out there.
		opts.sort_custom(func(a, b): return power(a) < power(b))
		for c in opts:
			if suit(c) != SPADES or QUEEN_SPADES in hands[p] or power(c) < 12:
				return c
		return opts[0]
	var led := suit(trick[0][1])
	var trick_pts := 0
	for t in trick:
		trick_pts += points(t[1])
	var high := 0
	for t in trick:
		if suit(t[1]) == led:
			high = maxi(high, power(t[1]))
	if suit(opts[0]) == led:
		# Following: duck under the winning card if we can, otherwise...
		var under := opts.filter(func(c): return power(c) < high)
		if not under.is_empty():
			under.sort_custom(func(a, b): return power(a) > power(b))
			return under[0]
		if trick.size() == 3 and trick_pts == 0:
			opts.sort_custom(func(a, b): return power(a) > power(b))
			for c in opts:
				if c != QUEEN_SPADES:
					return c  # last to play, nothing to lose: win with the highest
		opts.sort_custom(func(a, b): return power(a) < power(b))
		for c in opts:
			if c != QUEEN_SPADES:
				return c
		return opts[0]
	# Can't follow: dump the worst card.
	opts.sort_custom(func(a, b): return _danger(a) > _danger(b))
	return opts[0]
