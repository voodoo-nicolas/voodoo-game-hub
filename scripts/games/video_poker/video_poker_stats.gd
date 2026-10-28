extends RefCounted

## Numbers worked out from the hand history (video_poker_history.gd records,
## the last 1000 hands): rates, habits, results by variant, stake, position and
## starting hand, sessions, streaks and the running total for the graph.
## Pure functions of the records, so they can be tested on made-up hands. The
## lifetime totals (biggest loss, hands made, level...) are in video_poker_profile.gd.
##
## compute(hands, opts) -> Dictionary. opts: {"aids": bool = true  count hands
## played with the coach / win chance on, "modes": Array = [] keep these modes
## (empty: all), "variant": String = "" keep this variant}.

const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")

const SESSION_GAP := 1800
const POSITIONS := ["Dealer seat", "Cutoff", "Blinds", "Early"]

## The hands that are the player's own (a hero seat, not a shared phone) after the filters.
static func mine(hands: Array, opts: Dictionary = {}) -> Array:
	var out: Array = []
	var modes: Array = opts.get("modes", [])
	var variant := str(opts.get("variant", ""))
	var aids: bool = bool(opts.get("aids", true))
	for h in hands:
		if int(h.get("hero", -1)) < 0 or str(h.get("mode", "")) == "local":
			continue
		if not aids and bool(h.get("aids", false)):
			continue
		if not modes.is_empty() and not modes.has(str(h.get("mode", ""))):
			continue
		if variant != "" and str(h.get("variant", "")) != variant:
			continue
		out.append(h)
	return out

static func compute(hands: Array, opts: Dictionary = {}) -> Dictionary:
	var list := mine(hands, opts)
	var s := {
		"hands": list.size(), "won": 0, "net": 0, "showdowns": 0, "showdowns_won": 0,
		"biggest_won": 0, "biggest_lost": 0, "win_run": 0, "lose_run": 0, "cur_run": 0,
		"vpip_n": 0, "vpip": 0, "pfr": 0, "pf_hands": 0,
		"raises": 0, "calls": 0, "faced": 0, "folds_faced": 0,
		"bet3_chance": 0, "bet3": 0, "f3_chance": 0, "f3": 0, "cbet_chance": 0, "cbet": 0,
		"by_variant": {}, "by_stake": {}, "by_position": {}, "starting": {},
		"sessions": [], "series": [], "first_at": 0, "last_at": 0,
	}
	var total := 0
	var run := 0
	for h in list:
		var hero := int(h.hero)
		var net := int((h.net as Array)[hero]) if hero < (h.net as Array).size() else 0
		var at := int(h.get("at", 0))
		if s.first_at == 0:
			s.first_at = at
		s.last_at = at
		total += net
		s.net = total
		(s.series as Array).append(total)
		if net > 0:
			s.won += 1
			s.biggest_won = maxi(int(s.biggest_won), int(h.get("pot", 0)))
		elif net < 0:
			s.biggest_lost = maxi(int(s.biggest_lost), int(h.get("pot", 0)))
		# streaks
		if net > 0:
			run = run + 1 if run > 0 else 1
		elif net < 0:
			run = run - 1 if run < 0 else -1
		else:
			run = 0
		s.win_run = maxi(int(s.win_run), run)
		s.lose_run = maxi(int(s.lose_run), -run)
		s.cur_run = run
		# showdown
		var shown := 0
		for r in h.get("res", []):
			shown += int(r[3])
		var folded := _folded(h, hero)
		if shown >= 2 and not folded:
			s.showdowns += 1
			if net > 0:
				s.showdowns_won += 1
		_bucket(s.by_variant, str(h.get("variant", "holdem")), net, 1)
		_bucket(s.by_stake, "%d/%d" % [int(h.get("sb", 0)), int(h.get("bb", 0))], net, 1)
		var rules = Table.rules_for(str(h.get("variant", "holdem")))
		if not bool(h.get("partial", false)):
			_habits(s, h, hero, rules)
		if rules.has_blinds() and (h.seats as Array).size() >= 2:
			_bucket(s.by_position, POSITIONS[position_of(h, hero)], float(net) / float(maxi(1, int(h.get("bb", 20)))), 1)
		if str(h.get("variant", "")) == "holdem":
			var key := starting_key((h.seats as Array)[hero].hole)
			if key != "":
				_bucket(s.starting, key, net, 1)
	s.sessions = sessions(list)
	return s

# ---------- habits (VPIP, PFR, aggression, 3-bet, c-bet) ----------

static func _habits(s: Dictionary, h: Dictionary, hero: int, rules) -> void:
	var blinds: bool = rules.has_blinds()
	var posted := int((h.seats as Array)[hero].get("post", 0))
	var is_bb: bool = blinds and posted >= int(h.get("bb", 0)) and int(h.get("bb", 0)) > 0
	var pre_raises := 0          # raises before the player's action this hand, preflop
	var round_raises := {}       # street -> raises so far
	var vpip := false
	var pfr := false
	var seen_pre := false
	var aggressor := false       # the last preflop raiser is the player
	var hero_open_raise := false
	var faced_3bet_checked := false
	var cbet_checked := false
	for e in h.get("ev", []):
		var seat := int(e[0])
		var code := str(e[1])
		var street := int(e[3])
		var before := int(round_raises.get(street, 0))
		if seat == hero and code in ["fold", "call", "raise", "check"]:
			var faced := before > 0 or (street == 0 and blinds and not is_bb)
			if code == "raise":
				s.raises += 1
			elif code == "call":
				s.calls += 1
			if faced and code in ["fold", "call", "raise"]:
				s.faced += 1
				if code == "fold":
					s.folds_faced += 1
			if street == 0 and blinds:
				seen_pre = true
				if code in ["call", "raise"]:
					vpip = true
				if code == "raise":
					pfr = true
				# 3-bet: the player's action facing exactly one raise
				if pre_raises == 1 and code in ["fold", "call", "raise"] and not hero_open_raise:
					s.bet3_chance += 1
					if code == "raise":
						s.bet3 += 1
				if code == "raise" and pre_raises == 0:
					hero_open_raise = true
				elif hero_open_raise and pre_raises >= 2 and not faced_3bet_checked and code in ["fold", "call", "raise"]:
					faced_3bet_checked = true
					s.f3_chance += 1
					if code == "fold":
						s.f3 += 1
			elif street == 1 and rules.board_size() > 0 and aggressor and not cbet_checked and before == 0 and code in ["check", "raise"]:
				cbet_checked = true
				s.cbet_chance += 1
				if code == "raise":
					s.cbet += 1
		if code == "raise":
			round_raises[street] = before + 1
			if street == 0:
				pre_raises += 1
				aggressor = seat == hero
	if seen_pre:
		s.pf_hands += 1
		if vpip:
			s.vpip += 1
		if pfr:
			s.pfr += 1

static func _folded(h: Dictionary, hero: int) -> bool:
	for e in h.get("ev", []):
		if int(e[0]) == hero and str(e[1]) == "fold":
			return true
	return false

# ---------- helpers ----------

static func _bucket(into: Dictionary, key: String, net: Variant, hands: int) -> void:
	var b: Dictionary = into.get(key, {"hands": 0, "net": 0})
	b.hands = int(b.hands) + hands
	b.net = b.net + net
	into[key] = b

## Where the player sat: an index into POSITIONS. "Early" covers everything not
## on the button, cutoff or blinds.
static func position_of(h: Dictionary, hero: int) -> int:
	var seats: Array = h.seats
	var btn := int(h.get("btn", 0))
	var order: Array = []   # seats dealt in, from the button on
	for k in seats.size():
		var i := (btn + k) % seats.size()
		if not bool(seats[i].get("out", false)):
			order.append(i)
	var n := order.size()
	var idx := order.find(hero)
	if idx < 0 or n < 2:
		return 3
	if n == 2:
		return 0 if idx == 0 else 2
	if idx == 0:
		return 0
	if idx == 1 or idx == 2:
		return 2
	if idx == n - 1:
		return 1
	return 3

## "AKs", "QJo", "77": the two hole cards as a starting hand; "" unless exactly two.
static func starting_key(hole: Array) -> String:
	if hole.size() != 2:
		return ""
	var a := Eval.value(int(hole[0]))
	var b := Eval.value(int(hole[1]))
	var sa := int(hole[0]) / 13
	var sb := int(hole[1]) / 13
	if b > a:
		var tmp := a
		a = b
		b = tmp
	var names := ["", "", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
	if a == b:
		return names[a] + names[b]
	return names[a] + names[b] + ("s" if sa == sb else "o")

## Cash sessions: runs of hands less than SESSION_GAP apart:
## [{start, end, hands, net, per_hour}], oldest first.
static func sessions(list: Array) -> Array:
	var out: Array = []
	var cur: Dictionary = {}
	for h in list:
		if str(h.get("mode", "")) != "cash":
			continue
		var at := int(h.get("at", 0))
		var hero := int(h.hero)
		var net := int((h.net as Array)[hero]) if hero < (h.net as Array).size() else 0
		if cur.is_empty() or at - int(cur.end) > SESSION_GAP:
			if not cur.is_empty():
				out.append(cur)
			cur = {"start": at, "end": at, "hands": 0, "net": 0, "per_hour": 0.0}
		cur.end = at
		cur.hands = int(cur.hands) + 1
		cur.net = int(cur.net) + net
	if not cur.is_empty():
		out.append(cur)
	for c in out:
		var secs := int(c.end) - int(c.start)
		c.per_hour = float(c.net) * 3600.0 / float(secs) if secs >= 600 else 0.0
	return out

## 0..1 for a rate, as a whole percent text ("38%"), "-" when it has no chances.
static func pct(part: int, whole: int) -> String:
	return "-" if whole <= 0 else "%d%%" % roundi(100.0 * float(part) / float(whole))

## The starting hands with at least `min_hands` hands, best and worst by net:
## [[key, hands, net]] ordered best first.
static func starting_ranked(starting: Dictionary, min_hands: int = 3) -> Array:
	var out: Array = []
	for k in starting:
		if int(starting[k].hands) >= min_hands:
			out.append([k, int(starting[k].hands), int(starting[k].net)])
	out.sort_custom(func(a, b): return a[2] > b[2])
	return out
