extends RefCounted

## Chinchón for two (seat 0 = you, seat 1 = the computer), Spanish 40-card deck, 7 cards each.
## Each turn: draw (stock or the top discard), then discard one card, or discard and CLOSE the
## round when the 7 cards left have at most 5 points that belong to no meld.
## Melds: 3-4 cards of the same number, or 3+ cards of one suit in a row (1-7, then 10, 11, 12:
## 7 is followed by 10). Cards are worth their number, 10-12 are worth 10.
## Closing with every card melded takes 10 points off; seven of one suit in a row is a Chinchón
## and wins the match at once. Unmelded points are added to your score; whoever reaches 100
## first loses the match. Pure logic, no Nodes.

const Cards = preload("res://scripts/games/chinchon/chinchon_cards.gd")

const LIMIT := 100
const CLOSE_MAX := 5

var score: Array = [0, 0]
var hands: Array = [[], []]
var stock: Array = []
var discard: Array = []
var turn: int = 0
var phase: String = "draw"       # "draw" then "discard"
var drawn: int = -1              # the card just taken from the discard pile (cannot be thrown back)
var dealer: int = 1
var round_over: bool = false
var winner: int = -1             # match winner (-1 while playing)
var result: Dictionary = {}      # last round: {"closer","dead":[a,b],"delta":[a,b],"chinchon","clean"}

# ---------- hand maths ----------

## Position in a suit's row: 1-7, then 10, 11, 12 -> 8, 9, 10.
static func pos(card: int) -> int:
	var n := Cards.number(card)
	return n if n <= 7 else n - 2

static func points(card: int) -> int:
	var n := Cards.number(card)
	return n if n <= 7 else 10

static func is_meld(cards: Array) -> bool:
	if cards.size() < 3:
		return false
	var n0 := Cards.number(cards[0])
	var same_num := true
	var same_suit := true
	for c in cards:
		if Cards.number(c) != n0:
			same_num = false
		if Cards.suit(c) != Cards.suit(cards[0]):
			same_suit = false
	if same_num:
		return cards.size() <= 4        # four suits, so the cards are distinct
	if not same_suit:
		return false
	var ps: Array = []
	for c in cards:
		ps.append(pos(c))
	ps.sort()
	for i in range(1, ps.size()):
		if ps[i] != ps[i - 1] + 1:
			return false
	return true

## The best way to meld `hand`: {"melds": [[cards]...], "dead": [cards], "points": int}.
static func best_melds(hand: Array) -> Dictionary:
	var n := hand.size()
	var valid: Array = []            # [mask, ...] of every meld inside the hand
	for mask in range(1, 1 << n):
		var sub: Array = []
		for i in n:
			if mask & (1 << i):
				sub.append(hand[i])
		if sub.size() >= 3 and is_meld(sub):
			valid.append(mask)
	var memo := {}
	var full := (1 << n) - 1
	var res := _solve(hand, valid, full, memo)
	var melds: Array = []
	for m in res.masks:
		var g: Array = []
		for i in n:
			if m & (1 << i):
				g.append(hand[i])
		melds.append(g)
	var dead: Array = []
	var used := 0
	for m in res.masks:
		used |= m
	for i in n:
		if not (used & (1 << i)):
			dead.append(hand[i])
	return {"melds": melds, "dead": dead, "points": res.points}

static func _solve(hand: Array, valid: Array, left: int, memo: Dictionary) -> Dictionary:
	if left == 0:
		return {"points": 0, "masks": []}
	if memo.has(left):
		return memo[left]
	var low := 0
	while not (left & (1 << low)):
		low += 1
	# the lowest card stays unmelded ...
	var sub := _solve(hand, valid, left & ~(1 << low), memo)
	var best := {"points": sub.points + points(hand[low]), "masks": sub.masks}
	# ... or goes in a meld that fits what is left
	for m in valid:
		if (m & (1 << low)) and (m & left) == m:
			var r := _solve(hand, valid, left & ~m, memo)
			if r.points < best.points:
				best = {"points": r.points, "masks": r.masks + [m]}
	memo[left] = best
	return best

static func deadwood(hand: Array) -> int:
	return int(best_melds(hand).points)

## Seven cards of one suit in a row.
static func is_chinchon(hand: Array) -> bool:
	return hand.size() == 7 and is_meld(hand)

# ---------- rounds ----------

func new_game() -> void:
	score = [0, 0]
	winner = -1
	dealer = 1
	new_round()

func new_round() -> void:
	dealer = 1 - dealer
	var d := Cards.new_deck()
	hands = [d.slice(0, 7), d.slice(7, 14)]
	discard = [d[14]]
	stock = d.slice(15)
	turn = 1 - dealer
	phase = "draw"
	drawn = -1
	round_over = false
	result = {}

func _refill() -> void:
	if stock.is_empty() and discard.size() > 1:
		var top: int = discard.pop_back()
		stock = discard.duplicate()
		stock.shuffle()
		discard = [top]

func can_draw_stock() -> bool:
	return not stock.is_empty() or discard.size() > 1

func draw_stock(p: int) -> int:
	if winner != -1 or round_over or turn != p or phase != "draw":
		return -1
	_refill()
	if stock.is_empty():
		return -1
	var c: int = stock.pop_back()
	hands[p].append(c)
	drawn = -1
	phase = "discard"
	return c

func draw_discard(p: int) -> int:
	if winner != -1 or round_over or turn != p or phase != "draw" or discard.is_empty():
		return -1
	var c: int = discard.pop_back()
	hands[p].append(c)
	drawn = c
	phase = "discard"
	return c

func can_discard(p: int, card: int) -> bool:
	return winner == -1 and not round_over and turn == p and phase == "discard" and hands[p].has(card) and card != drawn

## Discard a card (ends the turn).
func throw(p: int, card: int) -> bool:
	if not can_discard(p, card):
		return false
	hands[p].erase(card)
	discard.append(card)
	phase = "draw"
	drawn = -1
	turn = 1 - p
	return true

## Could p close by throwing `card`?
func can_close(p: int, card: int) -> bool:
	if not can_discard(p, card):
		return false
	var rest: Array = hands[p].duplicate()
	rest.erase(card)
	return is_chinchon(rest) or deadwood(rest) <= CLOSE_MAX

## The card whose throw leaves the fewest unmelded points (ties: throw the dearest).
func best_throw(p: int) -> int:
	var best := -1
	var best_pts := 9999
	for c in hands[p]:
		if c == drawn:
			continue
		var rest: Array = hands[p].duplicate()
		rest.erase(c)
		var pts := deadwood(rest) * 100 - points(c)
		if pts < best_pts:
			best_pts = pts
			best = c
	return best

## Throw `card` and close the round, scoring it. Returns false if not allowed.
func close(p: int, card: int) -> bool:
	if not can_close(p, card):
		return false
	hands[p].erase(card)
	discard.append(card)
	var q := 1 - p
	var chin := is_chinchon(hands[p])
	var dead := [0, 0]
	dead[p] = 0 if chin else deadwood(hands[p])
	dead[q] = deadwood(hands[q])
	var delta := [0, 0]
	var clean: bool = dead[p] == 0 and not chin
	if chin:
		delta = [0, 0]
	else:
		delta[p] = -10 if clean else dead[p]
		delta[q] = dead[q]
	score[0] += delta[0]
	score[1] += delta[1]
	result = {"closer": p, "dead": dead, "delta": delta, "chinchon": chin, "clean": clean}
	round_over = true
	phase = "draw"
	if chin:
		winner = p
	elif score[0] >= LIMIT or score[1] >= LIMIT:
		if score[0] == score[1]:
			winner = q
		else:
			winner = 0 if score[0] < score[1] else 1
	return true

# ---------- save ----------

func to_dict() -> Dictionary:
	return {"score": score, "hands": hands, "stock": stock, "discard": discard, "turn": turn, "phase": phase,
		"drawn": drawn, "dealer": dealer}

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func from_dict(d: Dictionary) -> void:
	score = _ints(d.score)
	hands = [_ints(d.hands[0]), _ints(d.hands[1])]
	stock = _ints(d.stock)
	discard = _ints(d.discard)
	turn = int(d.turn)
	phase = str(d.phase)
	drawn = int(d.drawn)
	dealer = int(d.dealer)
	round_over = false
	winner = -1
	result = {}

# ---------- the computer ----------

## Should the computer take the top discard instead of the stock?
func cpu_take_discard(p: int) -> bool:
	if discard.is_empty():
		return false
	var now := deadwood(hands[p])
	var with: Array = hands[p].duplicate()
	with.append(discard.back())
	var best := 9999
	for i in with.size() - 1:      # (never throw the card just taken)
		var rest: Array = with.duplicate()
		rest.remove_at(i)
		best = mini(best, deadwood(rest))
	return best < now

## After drawing: {"close": bool, "card": int}.
func cpu_finish(p: int, skill: int = 1) -> Dictionary:
	var c := best_throw(p)
	var rest: Array = hands[p].duplicate()
	rest.erase(c)
	var want := CLOSE_MAX if skill >= 1 else 2
	if is_chinchon(rest) or deadwood(rest) <= mini(want, CLOSE_MAX):
		return {"close": true, "card": c}
	return {"close": false, "card": c}
