extends RefCounted

## Table poker for 2-6 seats: Texas Hold'em, Omaha, Five Card Draw and Seven
## Card Stud, with No limit / Pot limit / Limit betting, blinds (or antes and
## a bring-in in Stud), all-ins and side pots. Pure logic, no Nodes.
##
## The whole table is JSON-safe (to_dict / from_dict): it is the save, the
## online state (the host deals: the shuffled deck is part of it) and what
## the computer players think about on a worker thread.
##
## Flow: start_hand() -> the seat in `to_act` calls act() (or draw() in the
## draw phase of Five Card Draw) until `phase` is "done"; `results` then
## says who won what. Cards are ints 0..51 (see video_poker_eval.gd).

const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")

## What differs per variant lives in video_poker_rules_<variant>.gd; this file
## is the shared engine. Add a variant there, then list it here and in VARIANTS.
const RulesHoldem = preload("res://scripts/games/video_poker/video_poker_rules_holdem.gd")
const RulesOmaha = preload("res://scripts/games/video_poker/video_poker_rules_omaha.gd")
const RulesDraw = preload("res://scripts/games/video_poker/video_poker_rules_draw.gd")
const RulesStud = preload("res://scripts/games/video_poker/video_poker_rules_stud.gd")

const VARIANTS := ["holdem", "omaha", "draw", "stud"]
const LIMITS := ["nl", "pl", "fl"]

static var _rules_cache := {}

## The (stateless, shared) rules of a variant; Hold'em for an unknown name.
static func rules_for(name: String):
	if _rules_cache.is_empty():
		_rules_cache = {"holdem": RulesHoldem.new(), "omaha": RulesOmaha.new(), "draw": RulesDraw.new(), "stud": RulesStud.new()}
	return _rules_cache.get(name, _rules_cache["holdem"])
## Limit games cap each betting round at a bet and three raises.
const MAX_RAISES := 4
## Five Card Draw: swap up to 3 cards, or 4 when the card you keep is an Ace.
const MAX_DRAW := 3

var variant := "holdem":
	set(v):
		variant = v
		_rules = rules_for(v)
var _rules = rules_for("holdem")
var limit := "nl"
var seats: Array = []
var button := -1
var sb := 10
var bb := 20
var deck: Array = []
var muck: Array = []      # Draw: thrown-away cards, reshuffled if the deck runs out
var board: Array = []
var street := 0           # betting round of this hand, 0 = the first
var phase := "idle"       # idle | bet | draw | done
var to_act := -1
var current_bet := 0      # the highest bet this round
var last_raise := 0       # size of the last full raise (No / Pot limit minimum)
var raises := 0           # bets and raises this round (Limit cap)
var pot := 0              # chips from finished rounds
var hand_no := 0
var bring_in := -1        # Stud: the seat that was forced to open
## After a hand: [{seat, won, score, desc, best: [cards], shown}] for every
## seat still in at the end (shown = their cards went face up).
var results: Array = []
## The last thing that happened: {seat, action, amount} (for the log / sounds).
var last_event: Dictionary = {}

## kind: 0 = computer, 1.. = a person (the local player is 1; on one phone
## the players are 1..N; online the host is 1 and the guest 2).
static func new_seat(name: String, stack: int, kind: int, style: int = 0) -> Dictionary:
	return {"name": name, "stack": stack, "kind": kind, "style": style, "out": false,
		"hole": [], "up": [], "folded": false, "allin": false, "bet": 0, "total": 0,
		"acted": false, "act": "", "amt": 0, "drew": -1, "won": 0, "sitout": false, "aggr": 0}

# ---------- save / online ----------

func to_dict() -> Dictionary:
	return {"variant": variant, "limit": limit, "seats": seats, "button": button, "sb": sb, "bb": bb,
		"deck": deck, "muck": muck, "board": board, "street": street, "phase": phase, "to_act": to_act,
		"current_bet": current_bet, "last_raise": last_raise, "raises": raises, "pot": pot,
		"hand_no": hand_no, "bring_in": bring_in, "results": results, "last_event": last_event}

## Adopts a dict made by to_dict(), also after a JSON round trip (numbers
## come back as floats).
func from_dict(d: Dictionary) -> void:
	variant = str(d.get("variant", "holdem"))
	limit = str(d.get("limit", "nl"))
	button = int(d.get("button", -1))
	sb = int(d.get("sb", 10))
	bb = int(d.get("bb", 20))
	deck = _ints(d.get("deck", []))
	muck = _ints(d.get("muck", []))
	board = _ints(d.get("board", []))
	street = int(d.get("street", 0))
	phase = str(d.get("phase", "idle"))
	to_act = int(d.get("to_act", -1))
	current_bet = int(d.get("current_bet", 0))
	last_raise = int(d.get("last_raise", 0))
	raises = int(d.get("raises", 0))
	pot = int(d.get("pot", 0))
	hand_no = int(d.get("hand_no", 0))
	bring_in = int(d.get("bring_in", -1))
	seats = []
	for s in d.get("seats", []):
		var n := new_seat(str(s.get("name", "")), int(s.get("stack", 0)), int(s.get("kind", 0)), int(s.get("style", 0)))
		for k in ["out", "folded", "allin", "acted", "sitout"]:
			n[k] = bool(s.get(k, false))
		for k in ["bet", "total", "amt", "drew", "won", "aggr"]:
			n[k] = int(s.get(k, n[k]))
		n.act = str(s.get("act", ""))
		n.hole = _ints(s.get("hole", []))
		n.up = []
		for u in s.get("up", []):
			n.up.append(bool(u))
		seats.append(n)
	results = []
	for r in d.get("results", []):
		results.append({"seat": int(r.get("seat", 0)), "won": int(r.get("won", 0)), "score": int(r.get("score", -1)),
			"desc": str(r.get("desc", "")), "best": _ints(r.get("best", [])), "shown": bool(r.get("shown", false))})
	var e: Dictionary = d.get("last_event", {})
	last_event = {}
	if not e.is_empty():
		last_event = {"seat": int(e.get("seat", -1)), "action": str(e.get("action", "")), "amount": int(e.get("amount", 0))}

static func _ints(a: Variant) -> Array:
	var out: Array = []
	if typeof(a) == TYPE_ARRAY:
		for v in a:
			out.append(int(v))
	return out

func clone() -> RefCounted:
	var t = get_script().new()
	t.from_dict(JSON.parse_string(JSON.stringify(to_dict())))
	return t

# ---------- questions ----------

func hole_count() -> int:
	return _rules.hole_count()

func last_street() -> int:
	return _rules.last_street()

## Seats that can still win this hand.
func live() -> Array:
	var out: Array = []
	for i in seats.size():
		if in_hand(i):
			out.append(i)
	return out

func in_hand(i: int) -> bool:
	var s: Dictionary = seats[i]
	return not s.out and not s.folded and phase != "idle"

## Seats with chips (still at the table).
func players_left() -> int:
	var n := 0
	for s in seats:
		if int(s.stack) > 0:
			n += 1
	return n

func pot_total() -> int:
	var t := pot
	for s in seats:
		t += int(s.bet)
	return t

## The size of a bet or raise in Limit games this round (and the minimum
## raise elsewhere).
func bet_unit() -> int:
	if limit == "fl":
		return bb * 2 if _rules.big_street(street) else bb
	return bb

## Stud's forced bets, from the big blind: ante a quarter, bring-in a half.
func stud_ante() -> int:
	return maxi(1, bb / 4)

func stud_bring_in() -> int:
	return maxi(1, bb / 2)

## What the seat to act may do: {to_call, can_check, can_raise, min_to,
## max_to, all_in_to}. Raise amounts are the total bet this round
## ("raise to"), not the extra.
func legal() -> Dictionary:
	var out := {"to_call": 0, "can_check": false, "can_raise": false, "min_to": 0, "max_to": 0}
	if phase != "bet" or to_act < 0:
		return out
	var s: Dictionary = seats[to_act]
	var stack: int = s.stack
	var mine: int = s.bet
	out.to_call = mini(current_bet - mine, stack)
	out.can_check = current_bet <= mine
	var all_in_to: int = mine + stack
	out.all_in_to = all_in_to
	if all_in_to <= current_bet:
		return out
	# Nobody left who could call a raise: no point raising.
	var callers := 0
	for i in seats.size():
		if i != to_act and in_hand(i) and not seats[i].allin:
			callers += 1
	if callers == 0:
		return out
	var unit := bet_unit()
	if limit == "fl":
		if raises >= MAX_RAISES:
			return out
		var to: int = unit if current_bet < unit else current_bet + unit
		out.min_to = mini(to, all_in_to)
		out.max_to = out.min_to
	else:
		var min_to: int = current_bet + maxi(last_raise, unit)
		if current_bet < unit:
			min_to = maxi(min_to, unit)
		var max_to: int = all_in_to
		if limit == "pl":
			max_to = mini(all_in_to, current_bet + pot_total() + (current_bet - mine))
		out.min_to = mini(min_to, all_in_to)
		out.max_to = maxi(max_to, out.min_to)
	out.can_raise = true
	return out

# ---------- a hand ----------

## Deals a new hand. Seats without chips sit out. Returns false when fewer
## than two seats can play.
func start_hand(rng: RandomNumberGenerator) -> bool:
	var playing: Array = []
	for i in seats.size():
		var s: Dictionary = seats[i]
		s.out = int(s.stack) <= 0 or bool(s.sitout)
		s.hole = []
		s.up = []
		s.folded = false
		s.allin = false
		s.bet = 0
		s.total = 0
		s.acted = false
		s.act = ""
		s.amt = 0
		s.drew = -1
		s.won = 0
		s.aggr = 0
		if not s.out:
			playing.append(i)
	results = []
	last_event = {}
	board = []
	muck = []
	pot = 0
	street = 0
	raises = 0
	bring_in = -1
	if playing.size() < 2:
		phase = "idle"
		to_act = -1
		return false
	hand_no += 1
	phase = "bet"
	deck = range(52)
	for i in range(51, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	button = _next_seat(button, true)
	_rules.start(self)
	return true

func _post(i: int, amount: int, label: String) -> void:
	var s: Dictionary = seats[i]
	var a: int = mini(amount, int(s.stack))
	s.stack -= a
	s.bet += a
	s.total += a
	if s.stack == 0:
		s.allin = true
	s.act = label
	s.amt = a

func _deal() -> int:
	if deck.is_empty():
		# Only Five Card Draw can run out: the discards are shuffled back.
		deck = muck.duplicate()
		muck = []
		deck.shuffle()
	return deck.pop_back()

## Next seat after i that is in the hand (any = also all-in seats).
func _next_seat(i: int, any: bool) -> int:
	var n := seats.size()
	for k in range(1, n + 1):
		var j := (i + k + n) % n
		var s: Dictionary = seats[j]
		if s.out or s.folded:
			continue
		if any or not s.allin:
			return j
	return -1

## The first seat after i still needing to act this round, or -1.
func _next_to_act(i: int) -> int:
	var n := seats.size()
	for k in range(1, n + 1):
		var j := (i + k) % n
		var s: Dictionary = seats[j]
		if s.out or s.folded or s.allin:
			continue
		if not s.acted or int(s.bet) < current_bet:
			return j
	return -1

## The seat to act does `action`: "fold", "check", "call", "raise" (to
## `amount`, clamped to what's legal) or "allin". Returns false if it
## wasn't allowed.
func act(action: String, amount: int = 0) -> bool:
	if phase != "bet" or to_act < 0:
		return false
	var l := legal()
	var i := to_act
	var s: Dictionary = seats[i]
	if action == "allin":
		if l.can_raise and l.max_to == l.all_in_to:
			action = "raise"
			amount = l.all_in_to
		elif l.to_call >= s.stack:
			action = "call"
		elif l.can_raise:
			action = "raise"
			amount = l.max_to
		else:
			action = "call" if l.to_call > 0 else "check"
	match action:
		"fold":
			if l.can_check:
				action = "check"  # never fold for free
				s.act = "Check"
				s.amt = 0
			else:
				s.folded = true
				s.act = "Fold"
				s.amt = 0
		"check":
			if not l.can_check:
				return false
			s.act = "Check"
			s.amt = 0
		"call":
			if l.can_check:
				action = "check"
				s.act = "Check"
				s.amt = 0
			else:
				var a: int = l.to_call
				s.stack -= a
				s.bet += a
				s.total += a
				s.act = "Call"
				s.amt = a
		"raise":
			if not l.can_raise:
				return false
			var to: int = clampi(amount, l.min_to, l.max_to)
			var add: int = to - int(s.bet)
			s.stack -= add
			s.bet = to
			s.total += add
			if to - current_bet >= last_raise:
				last_raise = to - current_bet
			if current_bet == 0:
				s.act = "Bet"
			elif current_bet < bet_unit():
				s.act = "Complete"  # Stud: from the bring-in up to a full bet
			else:
				s.act = "Raise"
			s.amt = to
			current_bet = to
			raises += 1
			s.aggr += 1
			for j in seats.size():
				if j != i:
					seats[j].acted = false
		_:
			return false
	if s.stack == 0 and not s.folded:
		s.allin = true
		s.act = "All in"
		s.amt = int(s.bet)
	s.acted = true
	last_event = {"seat": i, "action": action, "amount": int(s.amt)}
	_settle(i)
	return true

## Moves the hand on after seat `after` acted (or posted): the next player,
## the next round, or the end.
func _settle(after: int) -> void:
	var alive := live()
	if alive.size() <= 1:
		_finish_uncontested(alive[0] if alive.size() == 1 else -1)
		return
	var cur := after
	for guard in seats.size() + 1:
		var nxt := _next_to_act(cur)
		if nxt < 0:
			break
		# Everyone else is all in and this seat has nothing to call: done.
		var others := 0
		for i in alive:
			if i != nxt and not seats[i].allin:
				others += 1
		if others == 0 and int(seats[nxt].bet) >= current_bet:
			seats[nxt].acted = true
			cur = nxt
			continue
		to_act = nxt
		return
	_end_round()

func _end_round() -> void:
	for s in seats:
		pot += int(s.bet)
		s.bet = 0
		s.acted = false
	current_bet = 0
	last_raise = bb
	raises = 0
	if _rules.draw_phase_after(street):
		phase = "draw"
		to_act = _first_after_button(true)
		return
	if street >= last_street():
		_showdown()
		return
	street += 1
	_deal_street()
	_open_round()

## Starts a betting round, or runs straight on when nobody can bet.
func _open_round() -> void:
	var can_bet := 0
	for i in live():
		if not seats[i].allin:
			can_bet += 1
	if can_bet <= 1:
		# Everyone's all in: deal the rest and show down.
		while street < last_street():
			street += 1
			_deal_street()
		_showdown()
		return
	phase = "bet"
	for s in seats:
		s.act = "" if not s.folded and not s.allin else s.act
	to_act = -1
	_rules.open_round(self)

func _first_after_button(any: bool) -> int:
	return _next_seat(button, any)

func _deal_street() -> void:
	_rules.deal_street(self)

func upcards(i: int) -> Array:
	var out: Array = []
	var s: Dictionary = seats[i]
	for k in s.hole.size():
		if k < s.up.size() and s.up[k]:
			out.append(s.hole[k])
	return out

## Five Card Draw: the seat to act throws away the cards at `indices` and
## gets new ones. Returns false if that many isn't allowed.
func draw(indices: Array) -> bool:
	if phase != "draw" or to_act < 0:
		return false
	if not can_discard(seats[to_act].hole, indices):
		return false
	var s: Dictionary = seats[to_act]
	var keep: Array = indices.duplicate()
	keep.sort()
	for k in keep:
		muck.append(s.hole[k])
	for k in keep:
		s.hole[k] = _deal()
	s.drew = keep.size()
	s.act = "Stand pat" if keep.is_empty() else "Draw"
	s.amt = keep.size()
	s.acted = true
	last_event = {"seat": to_act, "action": "draw", "amount": keep.size()}
	var nxt := -1
	var n := seats.size()
	for k in range(1, n + 1):
		var j := (to_act + k) % n
		if in_hand(j) and not seats[j].acted:
			nxt = j
			break
	if nxt >= 0:
		to_act = nxt
		return true
	for t in seats:
		t.acted = false
	street = 1
	_open_round()
	return true

static func can_discard(hand: Array, indices: Array) -> bool:
	if indices.size() <= MAX_DRAW:
		return true
	if indices.size() == MAX_DRAW + 1:
		for k in hand.size():
			if not indices.has(k):
				return Eval.value(hand[k]) == 14
	return false

# ---------- the end of a hand ----------

func hand_score(i: int) -> int:
	return _rules.hand_score(seats[i].hole, board)

func best_cards(i: int) -> Array:
	return _rules.best_cards(seats[i].hole, board)

func _finish_uncontested(winner: int) -> void:
	for s in seats:
		pot += int(s.bet)
		s.bet = 0
	results = []
	if winner >= 0:
		seats[winner].stack += pot
		seats[winner].won = pot
		results.append({"seat": winner, "won": pot, "score": -1, "desc": "", "best": [], "shown": false})
		last_event = {"seat": winner, "action": "win", "amount": pot}
	pot = 0
	phase = "done"
	to_act = -1

## Splits the chips into the main pot and side pots by what each seat put
## in, and pays each pot to the best hand among the seats that covered it.
func _showdown() -> void:
	for s in seats:
		pot += int(s.bet)
		s.bet = 0
	var alive := live()
	var scores := {}
	for i in alive:
		scores[i] = hand_score(i)
	var levels: Array = []
	for s in seats:
		if int(s.total) > 0 and not levels.has(int(s.total)):
			levels.append(int(s.total))
	levels.sort()
	var won := {}
	var prev := 0
	var carry := 0
	for level in levels:
		var amount := carry
		for s in seats:
			amount += clampi(int(s.total), prev, level) - prev
		var eligible: Array = []
		for i in alive:
			if int(seats[i].total) >= level:
				eligible.append(i)
		prev = level
		if eligible.is_empty():
			carry = amount  # only folded chips at this level: it joins the next pot
			continue
		carry = 0
		var best := -1
		for i in eligible:
			best = maxi(best, scores[i])
		var winners: Array = []
		# Odd chips go to the first winner after the button.
		for k in range(1, seats.size() + 1):
			var j := (button + k) % seats.size()
			if eligible.has(j) and scores[j] == best:
				winners.append(j)
		var share := amount / winners.size()
		var odd := amount - share * winners.size()
		for w in winners:
			won[w] = int(won.get(w, 0)) + share + (1 if odd > 0 else 0)
			odd -= 1
	if carry > 0 and not alive.is_empty():
		won[alive[0]] = int(won.get(alive[0], 0)) + carry
	results = []
	for i in alive:
		var w: int = won.get(i, 0)
		seats[i].stack += w
		seats[i].won = w
		results.append({"seat": i, "won": w, "score": scores[i], "desc": Eval.describe(scores[i]),
			"best": best_cards(i), "shown": true})
	results.sort_custom(func(a, b): return a.won > b.won)
	if not results.is_empty():
		last_event = {"seat": results[0].seat, "action": "win", "amount": results[0].won}
	pot = 0
	phase = "done"
	to_act = -1

## Every chip at the table (stacks + bets + pot): never changes in a hand.
func chips_total() -> int:
	var t := pot
	for s in seats:
		t += int(s.stack) + int(s.bet)
	return t
