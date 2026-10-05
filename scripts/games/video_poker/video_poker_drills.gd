extends RefCounted

## Training drills: each question is a Dictionary the training screen draws.
## Pure logic, no Nodes, so the answers can be checked headlessly.
##
##   {"kind", "prompt", "hole": [cards], "board": [cards], "hole2": [cards],
##    "choices": [text], "answer": index (or for "best5" the best score),
##    "explain": text, "best": [cards to highlight afterwards]}
##
## Kinds: "winner" (which Hold'em hand wins), "best5" (tap the five cards
## that make the best hand), "outs" (count the cards that complete a
## draw), "odds" (call or fold against the pot odds), "start" (rate a
## Hold'em starting hand by Chen's points).

const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const AI = preload("res://scripts/games/video_poker/video_poker_ai.gd")

## [kind, name, one-line description]; names are also the stat variants.
const DRILLS := [
	["winner", "Who wins?", "Two Hold'em hands, one board: pick the winner."],
	["best5", "Best five", "Seven cards: tap the five that make the best hand."],
	["outs", "Count the outs", "How many cards complete your draw?"],
	["odds", "Pot odds", "Is the price right? Call or fold."],
	["start", "Starting hands", "Rate a Hold'em starting hand."],
]
const QUESTIONS := 10

static func _t(text: String) -> String:
	return str(TranslationServer.translate(text))

static func question(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	match kind:
		"winner": return _winner(rng)
		"best5": return _best5(rng)
		"outs": return _outs(rng)
		"odds": return _odds(rng)
	return _start(rng)

static func _deck(rng: RandomNumberGenerator) -> Array:
	var d: Array = range(52)
	for i in range(51, 0, -1):
		var j := rng.randi_range(0, i)
		var t = d[i]
		d[i] = d[j]
		d[j] = t
	return d

static func _q(kind: String) -> Dictionary:
	return {"kind": kind, "prompt": "", "hole": [], "board": [], "hole2": [], "choices": [],
		"answer": 0, "explain": "", "best": []}

# ---------- who wins ----------

static func _winner(rng: RandomNumberGenerator) -> Dictionary:
	var q := _q("winner")
	# Half the time both hands are the same kind, so kickers decide.
	var want_same := rng.randf() < 0.5
	var d: Array
	var a := 0
	var b := 0
	for attempt in 200:
		d = _deck(rng)
		a = Eval.score([d[0], d[1]] + d.slice(4, 9))
		b = Eval.score([d[2], d[3]] + d.slice(4, 9))
		if (Eval.category(a) == Eval.category(b)) == want_same:
			break
	q.hole = [d[0], d[1]]
	q.hole2 = [d[2], d[3]]
	q.board = d.slice(4, 9)
	q.prompt = _t("Which hand wins?")
	q.choices = [_t("Player A"), _t("Player B"), _t("Split pot")]
	q.answer = 0 if a > b else (1 if b > a else 2)
	q.explain = "A: %s\nB: %s" % [Eval.describe(a), Eval.describe(b)]
	if a == b:
		q.explain += "\n" + _t("The same five cards play for both: split the pot.")
	elif Eval.category(a) == Eval.category(b):
		q.explain += "\n" + _t("Same kind of hand: the higher cards (kickers) decide.")
	var w: Array = q.hole if a >= b else q.hole2
	q.best = Eval.best_five(w + q.board)
	return q

# ---------- best five ----------

static func _best5(rng: RandomNumberGenerator) -> Dictionary:
	var q := _q("best5")
	var d := _deck(rng)
	# Mostly hands with something in them: a dull high-card hand teaches less.
	for attempt in 30:
		if Eval.category(Eval.score(d.slice(0, 7))) >= Eval.PAIR and rng.randf() < 0.9:
			break
		d = _deck(rng)
	q.hole = [d[0], d[1]]
	q.board = d.slice(2, 7)
	var best := Eval.score(d.slice(0, 7))
	q.answer = best
	q.prompt = _t("Tap the 5 cards that make the best hand.")
	q.best = Eval.best_five(d.slice(0, 7))
	q.explain = Eval.describe(best)
	return q

## Is this pick of five cards the best hand? (Several picks can tie.)
static func best5_correct(q: Dictionary, picked: Array) -> bool:
	return picked.size() == 5 and Eval.score(picked) == int(q.answer)

# ---------- outs ----------

static func _outs(rng: RandomNumberGenerator) -> Dictionary:
	var q := _q("outs")
	var hole: Array = []
	var board: Array = []
	var target := Eval.FLUSH
	var count := 0
	for attempt in 400:
		var d := _deck(rng)
		hole = [d[0], d[1]]
		board = d.slice(2, 5 if rng.randf() < 0.65 else 6)
		var cur := Eval.category(Eval.score(hole + board))
		# Ask about the best kind of hand the next card can still make
		# often enough to be a real draw (flush, straight, or a set).
		var options: Array = []
		for cat in [Eval.FLUSH, Eval.STRAIGHT, Eval.TRIPS]:
			if cat <= cur:
				continue
			var n := count_outs(hole, board, cat)
			if n >= 2 and n <= 15:
				options.append([cat, n])
		if options.is_empty():
			continue
		var pick: Array = options[rng.randi_range(0, options.size() - 1)]
		target = pick[0]
		count = pick[1]
		break
	q.hole = hole
	q.board = board
	q.answer = 0
	q.prompt = _t("How many cards give you a %s or better on the next card?") % _t(Eval.RANKINGS[8 - target][0])
	var choices: Array = [count]
	var deltas: Array = [-4, -3, -2, -1, 1, 2, 3, 4]
	deltas.shuffle()
	for dl in deltas:
		if choices.size() >= 4:
			break
		if count + dl > 0 and not choices.has(count + dl):
			choices.append(count + dl)
	choices.sort()
	q.answer = choices.find(count)
	q.choices = []
	for c in choices:
		q.choices.append(str(c))
	var unseen := 52 - hole.size() - board.size()
	if board.size() == 3:
		var exact := 1.0 - float((unseen - count) * (unseen - count - 1)) / float(unseen * (unseen - 1))
		q.explain = _t("%d outs. With two cards to come, outs × 4 ≈ %d%% (exactly %d%%).") % [count, count * 4, roundi(exact * 100)]
	else:
		q.explain = _t("%d outs. With one card to come, outs × 2 ≈ %d%% (exactly %d%%).") % [count, count * 2, roundi(100.0 * count / unseen)]
	return q

## Unseen cards that would make the hand at least category `cat`.
static func count_outs(hole: Array, board: Array, cat: int) -> int:
	var seen := {}
	for c in hole + board:
		seen[c] = true
	var n := 0
	for c in 52:
		if not seen.has(c) and Eval.category(Eval.score(hole + board + [c])) >= cat:
			n += 1
	return n

# ---------- pot odds ----------

## Common draws: [outs, name].
const DRAWS := [[4, "Inside straight draw"], [8, "Open-ended straight draw"], [9, "Flush draw"],
	[12, "Flush draw + inside straight draw"], [15, "Flush draw + open-ended straight draw"], [6, "Two overcards"]]

static func _odds(rng: RandomNumberGenerator) -> Dictionary:
	var q := _q("odds")
	var pot := 0
	var bet := 0
	var eq := 0.0
	var need := 0.0
	var draw: Array = DRAWS[0]
	var two_cards := false
	for attempt in 200:
		draw = DRAWS[rng.randi_range(0, DRAWS.size() - 1)]
		two_cards = rng.randf() < 0.35
		pot = rng.randi_range(4, 40) * 25
		bet = maxi(25, int(pot * rng.randf_range(0.2, 1.2) / 25.0) * 25)
		var outs: int = draw[0]
		eq = (1.0 - float((47 - outs) * (46 - outs)) / (47.0 * 46.0)) if two_cards else outs / 46.0
		need = float(bet) / float(pot + 2 * bet)
		if absf(eq - need) >= 0.03:
			break
	q.prompt = _t("Pot %d. Your opponent bets %d.") % [pot, bet] + "\n" + _t(draw[1]) + " (" + _t("%d outs") % draw[0] + ")"
	q.prompt += "\n" + (_t("They're all in: you see both cards.") if two_cards else _t("One card to come."))
	q.choices = [_t("Call"), _t("Fold")]
	q.answer = 0 if eq >= need else 1
	q.explain = _t("Calling %d to win %d needs %d%%. You hit about %d%% of the time.") % [bet, pot + bet, roundi(need * 100), roundi(eq * 100)]
	q.explain += "\n" + (_t("Good price: call.") if eq >= need else _t("Not enough: fold."))
	return q

# ---------- starting hands ----------

const TIERS := ["Premium", "Strong", "Playable", "Weak"]

static func tier_of(points: float) -> int:
	if points >= 10:
		return 0
	if points >= 8:
		return 1
	if points >= 6:
		return 2
	return 3

static func _start(rng: RandomNumberGenerator) -> Dictionary:
	var q := _q("start")
	var d := _deck(rng)
	# Every tier about equally often (most random hands are weak).
	var want := rng.randi_range(0, 3)
	for attempt in 300:
		if tier_of(AI.chen([d[0], d[1]])) == want:
			break
		d = _deck(rng)
	q.hole = [d[0], d[1]]
	var pts := AI.chen(q.hole)
	q.prompt = _t("How good is this Hold'em starting hand?")
	q.choices = []
	for t in TIERS:
		q.choices.append(_t(t))
	q.answer = tier_of(pts)
	q.explain = chen_explain(q.hole) + "\n" + _t("10+ Premium · 8-9 Strong · 6-7 Playable · 5 or less Weak")
	return q

## Chen's points, step by step: "K high = 8, suited +2, one gap -1 = 9".
static func chen_explain(hole: Array) -> String:
	var a: int = Eval.value(hole[0])
	var b: int = Eval.value(hole[1])
	var hi := maxi(a, b)
	var lo := mini(a, b)
	var pts := {14: 10.0, 13: 8.0, 12: 7.0, 11: 6.0}
	var base: float = pts.get(hi, hi / 2.0)
	var parts: Array = []
	if a == b:
		parts.append(_t("Pair: %s × 2") % _num(base))
		if base * 2.0 < 5.0:
			parts.append(_t("at least 5"))
	else:
		parts.append(_t("%s high = %s") % [Eval.rank_name(hi), _num(base)])
		if hole[0] / 13 == hole[1] / 13:
			parts.append(_t("suited +2"))
		var gap := hi - lo - 1
		if gap > 0:
			parts.append(_t("gap of %d: -%s") % [gap, _num([0.0, 1.0, 2.0, 4.0, 5.0][mini(gap, 4)])])
		if gap <= 1 and hi < 12:
			parts.append(_t("connected, below a Queen +1"))
	return _t("Chen points: %s → %s") % [", ".join(parts), _num(AI.chen(hole))]

static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else "%.1f" % v
