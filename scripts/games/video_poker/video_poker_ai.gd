extends RefCounted

## The computer players and the training coach. Both work from a copy of
## the table (Table.to_dict()), so they can think on a worker thread.
##
## A hand's strength is its win chance ("equity"): the rest of the hand is
## dealt out many times with random unknown cards and the wins are counted.
## Then the usual poker sums: call when the win chance beats the price
## (pot odds), bet or raise when well ahead, sometimes bluff.

const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")

## Playing styles: [name, tight (0 loose .. 1 tight), aggressive, bluffs].
const STYLES := [
	["Rock", 0.85, 0.3, 0.03],
	["Pro", 0.6, 0.75, 0.14],
	["Maniac", 0.15, 0.95, 0.3],
	["Calling Station", 0.2, 0.12, 0.02],
	["Fox", 0.45, 0.55, 0.1],
]
const STYLE_TIPS := {
	"Rock": "Plays few hands. When a Rock bets, believe it.",
	"Pro": "Solid and aggressive. Picks good spots to bluff.",
	"Maniac": "Bets and raises with anything. Call them down lighter.",
	"Calling Station": "Calls too much, rarely bluffs. Don't bluff them: bet your good hands.",
	"Fox": "Balanced and tricky. Mixes it up.",
}
const NAMES := ["Mama Zuzu", "Bones", "Lucky Lou", "Madame Mojo", "Gator", "Jinx", "Doc Hex",
	"Ruby", "Tex", "Lola", "Skully", "Rook", "Velvet", "Marisol", "Big Moe", "Raven"]

## Per level (0 Easy, 1 Normal, 2 Hard): deals per decision, how far off
## their read of a hand can be, and whether they think about what the
## others' bets mean.
## `work` caps the hands rated per decision and `ms` the thinking time
## (phones are several times slower than a PC).
const LEVELS := [
	{"trials": 70, "work": 200, "ms": 60, "noise": 0.12, "ranges": false, "bluff": 0.6},
	{"trials": 170, "work": 450, "ms": 110, "noise": 0.05, "ranges": false, "bluff": 1.0},
	{"trials": 320, "work": 800, "ms": 170, "noise": 0.02, "ranges": true, "bluff": 1.2},
]
## Relative cost of rating one hand, per game.
const WORK := {"holdem": 1.0, "stud": 1.0, "draw": 2.5, "omaha": 10.0}

# ---------- win chance ----------

## Chen's score for a Hold'em starting hand (-1 .. 20, AA = 20).
static func chen(hole: Array) -> float:
	var a: int = Eval.value(hole[0])
	var b: int = Eval.value(hole[1])
	var hi := maxi(a, b)
	var lo := mini(a, b)
	var pts := {14: 10.0, 13: 8.0, 12: 7.0, 11: 6.0}
	var p: float = pts.get(hi, hi / 2.0)
	if a == b:
		return maxf(5.0, p * 2.0)
	if hole[0] / 13 == hole[1] / 13:
		p += 2.0
	var gap := hi - lo - 1
	p -= [0.0, 1.0, 2.0, 4.0, 5.0][mini(gap, 4)]
	if gap <= 1 and hi < 12:
		p += 1.0
	return ceilf(p)

## Win chance of seat `me` against the other seats still in, from `trials`
## random deals of everything it can't see. `opponents` > 0 counts only
## that many of them (before the flop most players fold). With `ranges`,
## an opponent who has bet or raised is dealt a stronger-looking hand.
static func equity(t, me: int, trials: int, rng: RandomNumberGenerator, opponents: int = 0, ranges: bool = false, max_ms: int = 0) -> float:
	var opps: Array = []
	for i in t.live():
		if i != me:
			opps.append(i)
	if opps.is_empty():
		return 1.0
	if opponents > 0 and opponents < opps.size():
		opps = opps.slice(0, opponents)
	var known := {}
	var mine: Array = t.seats[me].hole.duplicate()
	for c in mine:
		known[c] = true
	for c in t.board:
		known[c] = true
	var opp_known: Array = []
	for i in opps:
		var up: Array = t.upcards(i) if t.variant == "stud" else []
		opp_known.append(up)
		for c in up:
			known[c] = true
	var pool: Array = []
	for c in 52:
		if not known.has(c):
			pool.append(c)
	var board_need: int = (5 - t.board.size()) if (t.variant == "holdem" or t.variant == "omaha") else 0
	var my_need: int = (7 - mine.size()) if t.variant == "stud" else 0
	var my_draw: bool = t.variant == "draw" and int(t.seats[me].drew) < 0
	var wins := 0.0
	var done := 0
	var deadline := Time.get_ticks_msec() + max_ms
	for trial in trials:
		if max_ms > 0 and trial % 8 == 7 and done >= 24 and Time.get_ticks_msec() > deadline:
			break
		var pos := 0
		var board: Array = t.board.duplicate()
		for k in board_need:
			board.append(_take(pool, pos, rng))
			pos += 1
		var hand: Array = mine.duplicate()
		for k in my_need:
			hand.append(_take(pool, pos, rng))
			pos += 1
		if my_draw:
			pos = _simulate_draw(hand, pool, pos, rng)
		var my_score := _score(t.variant, hand, board)
		var best_opp := -1
		var ties := 0
		var ok := true
		for o in opps.size():
			var oi: int = opps[o]
			var oh: Array = opp_known[o].duplicate()
			var need: int = t.hole_count() - oh.size()
			for k in need:
				if pos >= pool.size():
					ok = false
					break
				oh.append(_take(pool, pos, rng))
				pos += 1
			if not ok:
				break
			if ranges and t.variant == "holdem" and int(t.seats[oi].get("aggr", 0)) > 0:
				# A bettor rarely has a weak starting hand: re-deal those.
				var retry := 0
				while chen([oh[0], oh[1]]) < 6.0 + 2.0 * mini(int(t.seats[oi].aggr), 2) and retry < 4 and pos + 2 <= pool.size():
					oh = [_take(pool, pos, rng), _take(pool, pos + 1, rng)]
					pos += 2
					retry += 1
			if t.variant == "draw" and int(t.seats[oi].drew) < 0:
				pos = _simulate_draw(oh, pool, pos, rng)
			var s := _score(t.variant, oh, board)
			if s > best_opp:
				best_opp = s
				ties = 0
			elif s == best_opp:
				ties += 1
		if not ok:
			continue
		done += 1
		if my_score > best_opp:
			wins += 1.0
		elif my_score == best_opp:
			wins += 1.0 / (ties + 2)
	return wins / maxi(done, 1)

## A random card from pool[pos..], swapped to pool[pos] (a partial shuffle,
## so no copying per deal).
static func _take(pool: Array, pos: int, rng: RandomNumberGenerator) -> int:
	var j := rng.randi_range(pos, pool.size() - 1)
	var c: int = pool[j]
	pool[j] = pool[pos]
	pool[pos] = c
	return c

static func _score(variant: String, hand: Array, board: Array) -> int:
	match variant:
		"holdem":
			return Eval.score(hand + board)
		"omaha":
			return Eval.score_omaha(hand, board)
	return Eval.score(hand)

static func _simulate_draw(hand: Array, pool: Array, pos: int, rng: RandomNumberGenerator) -> int:
	for k in choose_discards(hand):
		if pos >= pool.size():
			break
		hand[k] = _take(pool, pos, rng)
		pos += 1
	return pos

# ---------- Five Card Draw ----------

## Which cards to throw away (indices), by the usual draw-poker habits:
## keep any made hand, a pair, two pair or trips; draw to four to a flush
## or an open straight; otherwise keep an Ace (draw 4) or the best two.
static func choose_discards(hand: Array) -> Array:
	var s := Eval.score(hand)
	var cat := Eval.category(s)
	if cat == Eval.STRAIGHT or cat == Eval.FLUSH or cat >= Eval.FULL_HOUSE:
		return []
	var counts := {}
	for c in hand:
		counts[Eval.value(c)] = int(counts.get(Eval.value(c), 0)) + 1
	var out: Array = []
	if cat == Eval.QUADS or cat == Eval.TRIPS or cat == Eval.TWO_PAIR or cat == Eval.PAIR:
		for k in hand.size():
			if counts[Eval.value(hand[k])] == 1:
				out.append(k)
		return out
	# four to a flush
	for suit in 4:
		var same: Array = []
		for k in hand.size():
			if hand[k] / 13 == suit:
				same.append(k)
		if same.size() == 4:
			for k in hand.size():
				if not same.has(k):
					return [k]
	# four in a row (open-ended)
	var vals: Array = []
	for c in hand:
		vals.append(Eval.value(c))
	for k in hand.size():
		var rest: Array = []
		for j in hand.size():
			if j != k:
				rest.append(vals[j])
		rest.sort()
		if rest[3] - rest[0] == 3 and rest[3] < 14 and rest[0] > 2:
			return [k]
	var order: Array = range(hand.size())
	order.sort_custom(func(x, y): return vals[x] > vals[y])
	if vals[order[0]] == 14:
		return order.slice(1)
	return order.slice(2)

# ---------- decisions ----------

## The computer's move for the seat to act in table dict `td`:
## {"action": "fold"|"check"|"call"|"raise", "amount": raise-to}, or for
## the draw phase {"action": "draw", "discards": [indices]}.
static func decide(td: Dictionary, level: int, seed: int) -> Dictionary:
	var t = Table.new()
	t.from_dict(td)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var me: int = t.to_act
	if me < 0:
		return {"action": "check"}
	var seat: Dictionary = t.seats[me]
	if t.phase == "draw":
		return {"action": "draw", "discards": choose_discards(seat.hole)}
	var lv: Dictionary = LEVELS[clampi(level, 0, 2)]
	var style: Array = STYLES[clampi(int(seat.style), 0, STYLES.size() - 1)]
	var tight: float = style[1]
	var aggr: float = style[2]
	var bluff: float = style[3] * lv.bluff
	var l: Dictionary = t.legal()
	var n_opp: int = t.live().size() - 1
	var n_eff := n_opp
	if t.street == 0:
		# Before the flop most players fold: count those who've come in.
		var came_in := 0
		for i in t.live():
			if i != me and t.seats[i].acted and int(t.seats[i].bet) > 0:
				came_in += 1
		n_eff = clampi(1 + came_in, 1, n_opp)
	var cost: float = (1.0 + n_eff) * float(WORK.get(t.variant, 1.0))
	var trials: int = clampi(int(lv.work / cost), 30, lv.trials)
	var eq := equity(t, me, trials, rng, n_eff, lv.ranges, lv.ms)
	eq = clampf(eq + rng.randf_range(-lv.noise, lv.noise), 0.0, 1.0)
	var pot: int = t.pot_total()
	var to_call: int = l.to_call
	var odds: float = float(to_call) / float(pot + to_call) if to_call > 0 else 0.0
	var value_thr: float = clampf(0.64 - 0.1 * (n_eff - 1), 0.34, 0.64) + 0.07 * tight - 0.05 * aggr
	var strong_thr: float = value_thr + 0.16
	var more_cards: bool = t.street < t.last_street()
	var stack_bb: float = float(int(seat.stack) + int(seat.bet)) / maxf(1.0, t.bb)
	# Short stacked before the flop: all in or fold.
	if t.street == 0 and stack_bb <= 10.0 and t.variant != "stud" and l.can_raise:
		if eq >= value_thr - 0.08 - 0.06 * aggr:
			return {"action": "allin"}
		return {"action": "check" if l.can_check else "fold"}
	if l.can_check:
		if eq >= value_thr and l.can_raise and rng.randf() < 0.5 + 0.5 * aggr:
			return _raise(t, l, eq >= strong_thr, rng, aggr)
		if t.street > 0 and l.can_raise and eq < 0.3 and rng.randf() < bluff * (1.5 if n_opp == 1 else 0.4):
			return _raise(t, l, false, rng, aggr)
		if more_cards and l.can_raise and eq >= 0.32 and rng.randf() < aggr * 0.22:
			return _raise(t, l, false, rng, aggr)  # semi-bluff a draw
		return {"action": "check"}
	var margin: float = 0.02 + 0.07 * tight
	if level == 0:
		margin -= 0.09  # Easy players call too much
	if eq >= strong_thr and l.can_raise and rng.randf() < 0.35 + 0.55 * aggr:
		return _raise(t, l, true, rng, aggr)
	if eq >= odds + margin:
		if l.can_raise and eq >= value_thr and rng.randf() < aggr * 0.3:
			return _raise(t, l, false, rng, aggr)
		return {"action": "call"}
	if level == 2 and l.can_raise and more_cards and n_opp == 1 and rng.randf() < bluff * 0.5:
		return _raise(t, l, false, rng, aggr)  # the occasional bluff raise
	return {"action": "fold"}

static func _raise(t, l: Dictionary, big: bool, rng: RandomNumberGenerator, aggr: float) -> Dictionary:
	if t.limit == "fl":
		return {"action": "raise", "amount": l.min_to}
	var pot: int = t.pot_total() + l.to_call
	var frac: float = (0.8 + 0.3 * aggr if big else 0.5 + 0.25 * aggr) * rng.randf_range(0.85, 1.15)
	var to: int
	if t.street == 0 and t.variant != "stud" and t.current_bet <= t.bb:
		to = t.bb * (3 + rng.randi_range(0, 1))  # an opening raise
		for s in t.seats:
			if s.acted and int(s.bet) == t.bb and s.act == "Call":
				to += t.bb  # one more per limper
	elif t.current_bet > 0:
		to = int(t.current_bet * (2.6 + rng.randf() * 0.8))
	else:
		to = int(pot * frac)
	to = _round_chips(to, t.bb)
	to = clampi(to, l.min_to, l.max_to)
	# Most of the stack in anyway: just go all in.
	if l.max_to == l.all_in_to and to > 0.6 * l.all_in_to:
		to = l.all_in_to
	return {"action": "raise", "amount": to}

static func _round_chips(v: int, bb: int) -> int:
	var step := maxi(1, bb / 4)
	return maxi(step, int(round(float(v) / step)) * step)

# ---------- the coach ----------

## Advice for the seat to act (a person): {eq, need, hand, outs, tier,
## advice ("Fold"/"Check"/"Call"/"Bet"/"Raise"/"Draw"), why, discards}.
## Win chance is against random hands, so it's a guide, not a promise.
static func advise(td: Dictionary, seed: int) -> Dictionary:
	var t = Table.new()
	t.from_dict(td)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var me: int = t.to_act
	var out := {"eq": 0.0, "need": 0.0, "hand": "", "outs": -1, "tier": "", "advice": "", "why": "", "discards": []}
	if me < 0:
		return out
	var hole: Array = t.seats[me].hole
	var cur := t.hand_score(me) if hole.size() > 0 else 0
	out.hand = Eval.describe(cur)
	if t.phase == "draw":
		var d := choose_discards(hole)
		out.discards = d
		out.advice = "Draw"
		out.why = _t("Keep the cards that already work and draw %d.") % d.size() if d.size() > 0 else _t("Your hand is made: stand pat.")
		return out
	var n_opp: int = t.live().size() - 1
	var n_eff := n_opp
	if t.street == 0:
		var came_in := 0
		for i in t.live():
			if i != me and t.seats[i].acted and int(t.seats[i].bet) > 0:
				came_in += 1
		n_eff = clampi(1 + came_in, 1, n_opp)
	var trials := clampi(int(2500.0 / ((1.0 + n_eff) * float(WORK.get(t.variant, 1.0)))), 60, 600)
	var eq := equity(t, me, trials, rng, n_eff, false, 300)
	var l: Dictionary = t.legal()
	var pot: int = t.pot_total()
	var need: float = float(l.to_call) / float(pot + l.to_call) if l.to_call > 0 else 0.0
	out.eq = eq
	out.need = need
	if t.variant == "holdem" and t.street == 0:
		var c := chen(hole)
		out.tier = "Premium" if c >= 10 else ("Strong" if c >= 8 else ("Playable" if c >= 6 else "Weak"))
	if (t.variant == "holdem" or t.variant == "omaha") and t.board.size() >= 3 and t.board.size() < 5:
		out.outs = outs(t, me)
	var value_thr: float = clampf(0.64 - 0.1 * (n_eff - 1), 0.34, 0.64)
	if t.variant == "holdem" and t.street == 0:
		_preflop_advice(out, chen(hole), l, t.bb)
		return out
	if l.can_check:
		if eq >= value_thr and l.can_raise:
			out.advice = "Bet"
			out.why = _t("You're likely ahead: bet so worse hands pay you.")
		else:
			out.advice = "Check"
			out.why = _t("Not strong enough to bet. Checking is free.")
	elif eq >= value_thr + 0.12 and eq >= need + 0.15 and l.can_raise:
		out.advice = "Raise"
		out.why = _t("You need %d%% to call and have about %d%%: raise for value.") % [roundi(need * 100), roundi(eq * 100)]
	elif eq >= need:
		out.advice = "Call"
		out.why = _t("You need %d%% to call and have about %d%%: the price is right.") % [roundi(need * 100), roundi(eq * 100)]
	else:
		out.advice = "Fold"
		out.why = _t("You need %d%% to call but have only about %d%%.") % [roundi(need * 100), roundi(eq * 100)]
	return out

## Hold'em before the flop: the starting-hand tiers the drill teaches
## (Chen's points), so the coach and the training agree.
static func _preflop_advice(out: Dictionary, points: float, l: Dictionary, bb: int) -> void:
	var cheap: bool = int(l.to_call) <= bb
	if points >= 10:
		out.advice = "Raise" if l.can_raise else ("Check" if l.can_check else "Call")
		out.why = _t("Premium starting hand: raise and build the pot.")
	elif points >= 8:
		if cheap and l.can_raise:
			out.advice = "Raise"
			out.why = _t("Strong starting hand: raise.")
		else:
			out.advice = "Call"
			out.why = _t("Strong starting hand: worth calling a raise.")
	elif points >= 6:
		if l.can_check:
			out.advice = "Check"
			out.why = _t("Playable hand and the flop is free: check.")
		elif cheap:
			out.advice = "Call"
			out.why = _t("Playable hand: worth a cheap look at the flop.")
		else:
			out.advice = "Fold"
			out.why = _t("Playable hands aren't worth calling a raise: fold.")
	elif l.can_check:
		out.advice = "Check"
		out.why = _t("Weak hand, but the flop is free: check.")
	else:
		out.advice = "Fold"
		out.why = _t("Weak starting hand: fold and wait for a better one.")

## Hold'em / Omaha: unseen cards that would lift your hand to a better
## kind of hand than the board alone makes (the "outs").
static func outs(t, me: int) -> int:
	var hole: Array = t.seats[me].hole
	var mine := _score(t.variant, hole, t.board)
	var cat := Eval.category(mine)
	var seen := {}
	for c in hole + t.board:
		seen[c] = true
	var n := 0
	for c in 52:
		if seen.has(c):
			continue
		var b2: Array = t.board + [c]
		var s := _score(t.variant, hole, b2)
		var c2 := Eval.category(s)
		if c2 > cat and c2 > Eval.category(Eval.score(b2)):
			n += 1
	return n

static func _t(text: String) -> String:
	return str(TranslationServer.translate(text))
