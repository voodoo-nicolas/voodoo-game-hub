extends SceneTree

## Headless check of the Poker hand history recorder (video_poker_history.gd):
## plays ~600 seeded random hands of every variant and checks that three
## recorders each write exactly one correct record per hand and agree with
## each other: the host (told about every state three times, to prove that
## repeats are ignored), a guest (which only ever receives the table through a
## JSON round trip, as online play does) and a game that was saved and
## resumed mid-hand. Also a hand joined mid-way, an abandoned hand, and the
## file trimming. Uses its own files in user://, removed afterwards.
## godot --headless --path . --script res://tools/test_poker_history.gd

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const History = preload("res://scripts/games/video_poker/video_poker_history.gd")

const CONFIGS := [["holdem", "nl"], ["omaha", "pl"], ["draw", "nl"], ["stud", "fl"]]
const FILES := ["host", "guest", "resume", "partial", "abandon", "trim"]

var fails := 0

func _init() -> void:
	_clean()
	_hands()
	_partial()
	_abandon()
	_trim()
	_clean()
	print("poker history: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _p(name: String) -> String:
	return "user://test_poker_history_%s.jsonl" % name

func _clean() -> void:
	for n in FILES:
		for ext in ["", ".tmp"]:
			if FileAccess.file_exists(_p(n) + ext):
				DirAccess.remove_absolute(_p(n) + ext)

func _table(variant: String, limit: String, n: int) -> RefCounted:
	var t = Table.new()
	t.variant = variant
	t.limit = limit
	t.sb = 10
	t.bb = 20
	for i in n:
		t.seats.append(Table.new_seat("P%d" % i, 1000, 1 if i == 0 else 0))
	return t

func _pick(t, arng: RandomNumberGenerator) -> Dictionary:
	if t.phase == "draw":
		var idx: Array = [0, 1, 2, 3, 4].slice(0, arng.randi_range(0, 3))
		return {"kind": "draw", "amount": 0, "idx": idx}
	var l: Dictionary = t.legal()
	var r := arng.randf()
	if r < 0.12:
		return {"kind": "fold", "amount": 0, "idx": []}
	if r < 0.65:
		return {"kind": "call", "amount": 0, "idx": []}
	if r < 0.92 and l.can_raise:
		return {"kind": "raise", "amount": arng.randi_range(int(l.min_to), int(l.max_to)), "idx": []}
	if r >= 0.92:
		return {"kind": "allin", "amount": 0, "idx": []}
	return {"kind": "call", "amount": 0, "idx": []}

func _apply(t, a: Dictionary) -> void:
	if a.kind == "draw":
		ok(t.draw(a.idx), "draw refused")
	else:
		ok(t.act(a.kind, a.amount), "%s refused" % a.kind)

## What the recorder may call each kind of move (the table turns a free fold
## into a check, an all-in into a call or a raise).
const CODES := {"fold": ["fold", "check"], "call": ["call", "check"], "raise": ["raise"],
	"allin": ["call", "raise", "check"], "draw": ["draw"]}

func _guest_copy(t) -> RefCounted:
	var g = Table.new()
	g.from_dict(JSON.parse_string(JSON.stringify(t.to_dict())))
	return g

func _resumed(rr):
	var n = History.new(_p("resume"))
	n.restore(JSON.parse_string(JSON.stringify(rr.current())))
	return n

# ---------- many hands, three recorders ----------

func _hands() -> void:
	var rng := RandomNumberGenerator.new()
	var arng := RandomNumberGenerator.new()
	rng.seed = 424242
	arng.seed = 424243
	var rh = History.new(_p("host"))
	var rg = History.new(_p("guest"))
	var rr = History.new(_p("resume"))
	var expected: Array = []
	for cfg in CONFIGS:
		for n in [2, 3, 6]:
			var t = _table(cfg[0], cfg[1], n)
			for hand in 25:
				if t.players_left() < 2:
					for s in t.seats:
						s.stack = 1000
				var aids_hand: bool = hand % 7 == 3
				var resume_at: int = arng.randi_range(0, 10) if hand % 3 == 0 else -1
				if not t.start_hand(rng):
					continue
				var seq: Array = []
				var step := 0
				_observe(t, rh, rg, rr, false)
				while t.phase != "done" and step < 300:
					var a := _pick(t, arng)
					seq.append([t.to_act, a.kind])
					_apply(t, a)
					step += 1
					_observe(t, rh, rg, rr, aids_hand and step >= 2)
					if step == resume_at and t.phase != "done":
						rr = _resumed(rr)
						rr.observe(t, "cash", 0, aids_hand and step >= 2)  # what _after_change does on load
				var totals: Array = []
				var stacks: Array = []
				for s in t.seats:
					totals.append(int(s.total))
					stacks.append(int(s.stack))
				expected.append({"seq": seq, "totals": totals, "stacks": stacks, "aids": aids_hand and seq.size() >= 2,
					"variant": cfg[0], "board": t.board.duplicate()})
	var h := History.load_all(_p("host"))
	var g := History.load_all(_p("guest"))
	var r := History.load_all(_p("resume"))
	print("hands played and recorded: ", expected.size(), " (host ", h.size(), ", guest ", g.size(), ", resumed ", r.size(), ")")
	if not h.is_empty():
		print("sample: ", JSON.stringify(h[h.size() / 2]))
	ok(h.size() == expected.size(), "host: one record per hand (%d records, %d hands)" % [h.size(), expected.size()])
	ok(g.size() == expected.size(), "guest: one record per hand (%d)" % g.size())
	ok(r.size() == expected.size(), "resumed: one record per hand (%d)" % r.size())
	for k in mini(h.size(), expected.size()):
		_check(h[k], expected[k], "hand %d" % k)
		if k < g.size():
			ok(_same(h[k], g[k]), "hand %d: the guest recorded what the host did" % k)
		if k < r.size():
			ok(_same(h[k], r[k]), "hand %d: the resumed game recorded what the host did" % k)

## Tell all three recorders about the table as it now is. The host hears it
## three times; the guest only ever gets a copy through JSON.
func _observe(t, rh, rg, rr, aids: bool) -> void:
	for i in 3:
		rh.observe(t, "cash", 0, aids)
	rg.observe(_guest_copy(t), "online", 1, aids)
	rr.observe(t, "cash", 0, aids)

func _same(a: Dictionary, b: Dictionary) -> bool:
	var x := a.duplicate(true)
	var y := b.duplicate(true)
	for k in ["at", "hero", "mode"]:
		x.erase(k)
		y.erase(k)
	return JSON.stringify(x) == JSON.stringify(y)

func _check(rec: Dictionary, ex: Dictionary, tag: String) -> void:
	var ev: Array = rec.ev
	var seq: Array = ex.seq
	ok(not bool(rec.partial), tag + ": not partial")
	ok(bool(rec.aids) == bool(ex.aids), tag + ": aids flag")
	ok(ev.size() == seq.size(), tag + ": %d events for %d moves" % [ev.size(), seq.size()])
	var added := {}
	var last_street := 0
	for i in mini(ev.size(), seq.size()):
		var e: Array = ev[i]
		ok(int(e[0]) == int(seq[i][0]), tag + ": event %d is by the seat that moved" % i)
		ok(str(e[1]) in CODES[seq[i][1]], tag + ": event %d code %s for a %s" % [i, e[1], seq[i][1]])
		ok(int(e[3]) >= last_street, tag + ": streets only go up")
		last_street = int(e[3])
		added[int(e[0])] = int(added.get(int(e[0]), 0)) + int(e[5])
	var seats: Array = rec.seats
	var pot := 0
	var won := 0
	for i in seats.size():
		var total: int = int(seats[i].post) + int(added.get(i, 0))
		ok(total == int(ex.totals[i]), tag + ": seat %d put in %d, the table says %d" % [i, total, ex.totals[i]])
		ok(int(seats[i].stack) + int(rec.net[i]) == int(ex.stacks[i]), tag + ": seat %d start stack plus net is its end stack" % i)
		pot += total
	for x in rec.res:
		won += int(x[1])
	ok(int(rec.pot) == pot and won == pot, tag + ": pot %d, paid %d, counted %d" % [rec.pot, won, pot])
	var net := 0
	for v in rec.net:
		net += int(v)
	ok(net == 0, tag + ": nets sum to zero")
	ok(str(rec.board) == str(ex.board) or rec.board.size() == ex.board.size(), tag + ": board")
	ok(str(rec.variant) == str(ex.variant), tag + ": variant")
	if ex.variant == "draw":
		var drew := 0
		for e in ev:
			drew += 1 if e[1] == "draw" else 0
		ok(rec.end.size() <= drew, tag + ": only seats that drew changed their cards")

# ---------- the odd cases ----------

func _partial() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var t = _table("holdem", "nl", 3)
	t.start_hand(rng)
	var fresh = History.new(_p("partial"))
	fresh.observe(t, "cash", 0, false)
	ok(not bool(fresh.cur.partial), "a recorder that sees the hand start is not partial")
	t.act("call")
	t.act("raise", 100)
	var late = History.new(_p("partial"))
	late.observe(t, "cash", 0, false)
	ok(not late.cur.is_empty() and bool(late.cur.partial), "joining mid-hand is partial")
	ok(int(late.cur.seats[0].stack) == 1000, "the start stacks are rebuilt from stack plus chips in")
	while t.phase != "done":
		t.act("call")
		late.observe(t, "cash", 0, false)
	var recs := History.load_all(_p("partial"))
	ok(recs.size() == 1 and bool(recs[0].partial) and recs[0].res.size() > 0, "the partial hand is recorded with its result")
	late.observe(Table.new(), "cash", 0, false)
	ok(History.load_all(_p("partial")).size() == 1, "an idle table records nothing")

func _abandon() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 78
	var rec = History.new(_p("abandon"))
	var t = _table("holdem", "nl", 2)
	t.start_hand(rng)
	rec.observe(t, "cash", 0, false)
	t.act("call")
	rec.observe(t, "cash", 0, false)
	rec.abandon()
	ok(rec.cur.is_empty(), "abandon forgets the hand")
	var t2 = _table("holdem", "nl", 2)  # a new game: hand 1 again
	t2.start_hand(rng)
	rec.observe(t2, "cash", 0, false)
	while t2.phase != "done":
		t2.act("call")
		rec.observe(t2, "cash", 0, false)
	var recs := History.load_all(_p("abandon"))
	ok(recs.size() == 1 and not bool(recs[0].partial) and recs[0].ev.size() > 0, "only the new game's hand is on file, whole")

func _trim() -> void:
	var rec = History.new(_p("trim"), 5)
	for i in 260:
		rec._append({"i": i})
	var all := History.load_all(_p("trim"))
	ok(all.size() == 59 and int(all[0].i) == 201 and int(all[all.size() - 1].i) == 259,
		"trimming keeps the newest hands (%d on file, first %s)" % [all.size(), str(all[0].i) if not all.is_empty() else "-"])
	ok(rec.count() == all.size(), "count() agrees")
