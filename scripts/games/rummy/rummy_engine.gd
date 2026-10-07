extends RefCounted

## Rummy, you (0) against the computer (1). Each turn: draw (from the stock or
## the top of the discard pile), put down any melds, lay cards off on melds on
## the table (yours or theirs), then discard one card. Melds are sets (3-4 of a
## rank) and runs (3+ in a suit; the Ace is low or high but a run can't wrap).
## Go out by playing your last card; if the stock runs out the hand is a draw. The winner scores the points left in the
## other hand (Ace 1, face cards 10); first to 100 wins the match.
## Pure logic, no Nodes. Cards are ints 0..51: rank = card % 13 + 1
## (Ace = 1), suit = card / 13 (0 ♠, 1 ♥, 2 ♦, 3 ♣).

const TARGET := 100
const HAND := 10

var hands: Array = [[], []]
var stock: Array = []
var discard: Array = []
var melds: Array = []          # {"kind": "set"|"run", "cards": [...], "suit": s, "lo": l, "hi": h, "owner": p}
var turn: int = 0
var phase: String = "draw"     # "draw", "play", "over"
var starter: int = 0
var scores: Array = [0, 0]
var winner: int = -1           # of the hand: 0, 1, or -1 (a draw)
var hand_points: int = 0       # what the winner scored
var drew_discard: int = -1     # card just taken from the discard: it can't be discarded straight back

static func rank(c: int) -> int:
	return c % 13 + 1

static func suit(c: int) -> int:
	return c / 13

static func value(c: int) -> int:
	return mini(10, rank(c))

static func sort_hand(h: Array) -> void:
	h.sort_custom(func(a, b):
		var order := [0, 1, 3, 2]
		if suit(a) != suit(b):
			return order[suit(a)] < order[suit(b)]
		return rank(a) < rank(b))

func new_match() -> void:
	scores = [0, 0]
	starter = 0
	new_hand()

func new_hand() -> void:
	var deck: Array = range(52)
	deck.shuffle()
	hands = [deck.slice(0, HAND), deck.slice(HAND, HAND * 2)]
	sort_hand(hands[0])
	sort_hand(hands[1])
	discard = [deck[HAND * 2]]
	stock = deck.slice(HAND * 2 + 1)
	melds = []
	turn = starter
	phase = "draw"
	winner = -1
	hand_points = 0
	drew_discard = -1

func match_over() -> bool:
	return scores[0] >= TARGET or scores[1] >= TARGET

func deadwood(p: int) -> int:
	var t := 0
	for c in hands[p]:
		t += value(c)
	return t

# ---------- melds ----------

## What `cards` make: "set", "run" or "" (not a meld). Fills `info` with the run's suit / lo / hi.
static func classify(cards: Array, info: Dictionary = {}) -> String:
	if cards.size() < 3:
		return ""
	var r0 := rank(cards[0])
	var same_rank := true
	var seen_suits := {}
	for c in cards:
		if rank(c) != r0:
			same_rank = false
		seen_suits[suit(c)] = true
	if same_rank and cards.size() <= 4 and seen_suits.size() == cards.size():
		return "set"
	var s0 := suit(cards[0])
	for c in cards:
		if suit(c) != s0:
			return ""
	for ace_high in [false, true]:
		var ranks: Array = []
		for c in cards:
			var r := rank(c)
			ranks.append(14 if (r == 1 and ace_high) else r)
		ranks.sort()
		var ok := true
		for i in range(1, ranks.size()):
			if ranks[i] != ranks[i - 1] + 1:
				ok = false
				break
		if ok:
			info["suit"] = s0
			info["lo"] = ranks[0]
			info["hi"] = ranks[ranks.size() - 1]
			return "run"
	return ""

## Puts `cards` from player p's hand on the table as a meld. Returns false if it isn't one.
func meld(p: int, cards: Array) -> bool:
	if phase != "play" or p != turn:
		return false
	for c in cards:
		if not c in hands[p]:
			return false
	var info := {}
	var kind := classify(cards, info)
	if kind == "":
		return false
	var m := {"kind": kind, "cards": cards.duplicate(), "owner": p}
	if kind == "run":
		m["suit"] = info.suit
		m["lo"] = info.lo
		m["hi"] = info.hi
	for c in cards:
		hands[p].erase(c)
	melds.append(m)
	_check_out(p)
	return true

## Can `card` be added to meld m?
func can_lay_off(card: int, m: Dictionary) -> bool:
	if m.kind == "set":
		return rank(card) == rank(m.cards[0]) and m.cards.size() < 4 and not _has_suit(m, suit(card))
	if suit(card) != int(m.suit):
		return false
	var r := rank(card)
	if r == int(m.lo) - 1 or r == int(m.hi) + 1:
		return true
	return r == 1 and int(m.hi) == 13

func _has_suit(m: Dictionary, s: int) -> bool:
	for c in m.cards:
		if suit(c) == s:
			return true
	return false

func lay_off(p: int, card: int, index: int) -> bool:
	if phase != "play" or p != turn or not card in hands[p] or index < 0 or index >= melds.size():
		return false
	var m: Dictionary = melds[index]
	if not can_lay_off(card, m):
		return false
	m.cards.append(card)
	if m.kind == "run":
		var r := rank(card)
		if r == int(m.lo) - 1:
			m["lo"] = r
		elif r == int(m.hi) + 1:
			m["hi"] = r
		else:
			m["hi"] = 14   # an Ace on the top of a Q-K run
	hands[p].erase(card)
	_check_out(p)
	return true

## Cards of p's hand that could be laid off somewhere right now.
func layoff_options(p: int) -> Array:
	var out: Array = []
	for c in hands[p]:
		for m in melds:
			if can_lay_off(c, m):
				out.append(c)
				break
	return out

func _check_out(p: int) -> void:
	if hands[p].is_empty():
		_finish(p)

func _finish(p: int) -> void:
	phase = "over"
	winner = p
	hand_points = deadwood(1 - p)
	scores[p] += hand_points

# ---------- turns ----------

func can_draw_stock() -> bool:
	return phase == "draw" and not stock.is_empty()

func draw_stock(p: int) -> int:
	if p != turn or not can_draw_stock():
		return -1
	var c: int = stock.pop_back()
	hands[p].append(c)
	sort_hand(hands[p])
	phase = "play"
	drew_discard = -1
	return c

func draw_discard(p: int) -> int:
	if p != turn or phase != "draw" or discard.is_empty():
		return -1
	var c: int = discard.pop_back()
	hands[p].append(c)
	sort_hand(hands[p])
	phase = "play"
	drew_discard = c
	return c

## Ends the turn by discarding. A card just taken from the discard can't be put straight back.
func do_discard(p: int, card: int) -> bool:
	if phase != "play" or p != turn or not card in hands[p] or card == drew_discard:
		return false
	hands[p].erase(card)
	discard.append(card)
	if hands[p].is_empty():
		_finish(p)
		return true
	turn = 1 - p
	phase = "draw"
	drew_discard = -1
	# The stock ran out: the hand is a draw.
	if stock.is_empty():
		phase = "over"
		winner = -1
		hand_points = 0
	return true

func next_hand() -> void:
	starter = 1 - starter
	new_hand()

# ---------- the computer ----------

## The best way to split `cards` into melds: a list of melds (each an Array of cards)
## covering as much value as possible.
static func best_melds(cards: Array) -> Array:
	# depth-first over non-overlapping candidates (hands are small)
	return _search(_candidates(cards), 0, [], 0)[0]

static func _candidates(cards: Array) -> Array:
	var out: Array = []
	var by_rank := {}
	var by_suit := {}
	for c in cards:
		by_rank[rank(c)] = by_rank.get(rank(c), []) + [c]
		by_suit[suit(c)] = by_suit.get(suit(c), []) + [c]
	for r in by_rank:
		var g: Array = by_rank[r]
		if g.size() >= 3:
			out.append(g.duplicate())
			if g.size() == 4:
				for skip in 4:
					var sub: Array = g.duplicate()
					sub.remove_at(skip)
					out.append(sub)
	for s in by_suit:
		var g: Array = by_suit[s]
		for ace_high in [false, true]:
			var items: Array = []
			for c in g:
				var r := rank(c)
				items.append([14 if (r == 1 and ace_high) else r, c])
			items.sort_custom(func(a, b): return a[0] < b[0])
			var i := 0
			while i < items.size():
				var j := i
				while j + 1 < items.size() and items[j + 1][0] == items[j][0] + 1:
					j += 1
				# every sub-run of length >= 3 inside [i, j]
				for a in range(i, j + 1):
					for b in range(a + 2, j + 1):
						var run: Array = []
						for k in range(a, b + 1):
							run.append(items[k][1])
						if ace_high and not _has_ace_high(run):
							continue
						out.append(run)
				i = j + 1
	return out

static func _has_ace_high(run: Array) -> bool:
	for c in run:
		if rank(c) == 1:
			return true
	return false

static func _search(cands: Array, from: int, used: Array, val: int) -> Array:
	var best_list: Array = []
	var best_val := val
	for i in range(from, cands.size()):
		var cm: Array = cands[i]
		var clash := false
		for c in cm:
			if c in used:
				clash = true
				break
		if clash:
			continue
		var next_used: Array = used.duplicate()
		var v := 0
		for c in cm:
			next_used.append(c)
			v += value(c)
		var sub := _search(cands, i + 1, next_used, val + v)
		if sub[1] > best_val:
			best_val = sub[1]
			best_list = [cm] + sub[0]
	return [best_list, best_val]

## Plays the computer's whole turn and returns a short steps of what it did.
func cpu_turn() -> Array:
	var steps: Array = []
	if phase != "draw" or turn != 1:
		return steps
	# Draw: take the top discard if it helps, else the stock.
	var took := false
	if not discard.is_empty():
		var top: int = discard[discard.size() - 1]
		var test: Array = hands[1].duplicate()
		test.append(top)
		var helps := false
		for m in melds:
			if can_lay_off(top, m):
				helps = true
		if _meld_value(test) > _meld_value(hands[1]):
			helps = true
		if helps:
			draw_discard(1)
			steps.append("discard")
			took = true
	if not took:
		if draw_stock(1) < 0:
			# no stock: take the discard (or the hand is a draw)
			if draw_discard(1) < 0:
				phase = "over"
				return steps
			steps.append("discard")
		else:
			steps.append("stock")
	# Put down melds.
	var groups: Array = best_melds(hands[1])
	for g in groups:
		if meld(1, g):
			steps.append("meld")
		if phase == "over":
			return steps
	# Lay off whatever fits.
	var changed := true
	while changed and not hands[1].is_empty():
		changed = false
		for c in hands[1].duplicate():
			for i in melds.size():
				if can_lay_off(c, melds[i]):
					lay_off(1, c, i)
					steps.append("layoff")
					changed = true
					break
			if phase == "over":
				return steps
			if changed:
				break
	if phase == "over":
		return steps
	# Discard the most useless high card.
	var worst := -1
	var worst_score := -1000
	for c in hands[1]:
		if c == drew_discard:
			continue
		var sc := value(c) * 3 - _links(hands[1], c) * 8
		if sc > worst_score:
			worst_score = sc
			worst = c
	if worst < 0:
		worst = hands[1][0]
	do_discard(1, worst)
	return steps

static func _meld_value(cards: Array) -> int:
	var t := 0
	for g in best_melds(cards):
		for c in g:
			t += value(c)
	return t

## How many other cards in `cards` could join `c` in a set or run (close ranks, same suit / same rank).
static func _links(cards: Array, c: int) -> int:
	var n := 0
	for d in cards:
		if d == c:
			continue
		if rank(d) == rank(c):
			n += 1
		elif suit(d) == suit(c) and absi(rank(d) - rank(c)) <= 2:
			n += 1
	return n

func to_dict() -> Dictionary:
	return {"hands": hands, "stock": stock, "discard": discard, "melds": melds, "turn": turn, "phase": phase, "starter": starter,
		"scores": scores, "winner": winner, "points": hand_points, "drew": drew_discard}

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func from_dict(d: Dictionary) -> bool:
	var h = d.get("hands", [])
	if not (h is Array) or h.size() != 2:
		return false
	hands = [_ints(h[0]), _ints(h[1])]
	stock = _ints(d.get("stock", []))
	discard = _ints(d.get("discard", []))
	melds = []
	for m in d.get("melds", []):
		var mm := {"kind": str(m.kind), "cards": _ints(m.cards), "owner": int(m.owner)}
		if mm.kind == "run":
			mm["suit"] = int(m.suit)
			mm["lo"] = int(m.lo)
			mm["hi"] = int(m.hi)
		melds.append(mm)
	turn = clampi(int(d.get("turn", 0)), 0, 1)
	phase = str(d.get("phase", "draw"))
	starter = clampi(int(d.get("starter", 0)), 0, 1)
	scores = _ints(d.get("scores", [0, 0]))
	winner = int(d.get("winner", -1))
	hand_points = int(d.get("points", 0))
	drew_discard = int(d.get("drew", -1))
	return true
