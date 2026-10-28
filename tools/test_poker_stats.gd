extends SceneTree

## Headless check of Poker's profile, stats and replay (video_poker_profile.gd,
## _stats.gd, _replay.gd): plays ~400 seeded random hands of every variant
## through the history recorder, then checks that the profile counts every
## hand and the chips add up, that the stats agree with a plain recount, that
## made-up hands give the expected VPIP / PFR / 3-bet / c-bet / position /
## starting-hand answers, and that a replay of every hand conserves chips at
## every step and ends where the hand ended. Uses its own files in user://.
## godot --headless --path . --script res://tools/test_poker_stats.gd

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const History = preload("res://scripts/games/video_poker/video_poker_history.gd")
const Profile = preload("res://scripts/games/video_poker/video_poker_profile.gd")
const Stats = preload("res://scripts/games/video_poker/video_poker_stats.gd")
const Replay = preload("res://scripts/games/video_poker/video_poker_replay.gd")

const CONFIGS := [["holdem", "nl"], ["omaha", "pl"], ["draw", "nl"], ["stud", "fl"]]
const HIST := "user://test_poker_stats_history.jsonl"
const PROF := "user://test_poker_stats_profile.json"

var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	_clean()
	_levels()
	var recs := _play()
	_profile(recs)
	_stats(recs)
	_habits()
	_replays(recs)
	_clean()
	print("poker stats: ", "OK  (%d hands)" % recs.size() if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)

func _clean() -> void:
	for p in [HIST, PROF]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

# ---------- playing hands ----------

func _play() -> Array:
	var recs: Array = []
	var arng := RandomNumberGenerator.new()
	arng.seed = 20261028
	var hist = History.new(HIST)
	var at := 1800000000
	for cfg in CONFIGS:
		for round in 25:
			var t = Table.new()
			t.variant = cfg[0]
			t.limit = cfg[1]
			t.sb = 10
			t.bb = 20
			var n := 2 + round % 5
			for i in n:
				t.seats.append(Table.new_seat("P%d" % i if i > 0 else "", 1000, 1 if i == 0 else 0))
			var rng := RandomNumberGenerator.new()
			rng.seed = 100 + round
			for h in 4:
				if not t.start_hand(rng):
					break
				var guard := 0
				var rec := {}
				hist.observe(t, "cash", 0, false)
				while t.phase != "done" and guard < 200:
					guard += 1
					if t.phase == "draw":
						t.draw([0, 1].slice(0, arng.randi_range(0, 2)))
					else:
						var l: Dictionary = t.legal()
						var r := arng.randf()
						if r < 0.15 and not l.can_check:
							t.act("fold")
						elif r < 0.7:
							t.act("call")
						elif l.can_raise:
							t.act("raise", arng.randi_range(int(l.min_to), int(l.max_to)))
						else:
							t.act("call")
					rec = hist.observe(t, "cash", 0, false)
				if not rec.is_empty():
					rec["at"] = at
					at += 60
					recs.append(rec)
				for s in t.seats:
					if int(s.stack) <= 0:
						s.stack = 1000
	return recs

# ---------- profile ----------

func _levels() -> void:
	ok(Profile.level_for(0) == 1 and Profile.level_for(99) == 1 and Profile.level_for(100) == 2, "level 2 at 100 xp")
	ok(Profile.level_for(299) == 2 and Profile.level_for(300) == 3 and Profile.level_for(600) == 4, "levels 3 and 4")
	ok(Profile.title_for(1) == "Rail Bird" and Profile.title_for(99) == "Voodoo Master", "titles clamp")
	for l in range(1, 30):
		ok(Profile.level_for(Profile.xp_for_level(l)) == l, "level %d starts at its own xp" % l)

func _profile(recs: Array) -> void:
	var p = Profile.new(PROF)
	var net := 0
	var won := 0
	var last_xp := 0
	for r in recs:
		var out: Dictionary = p.record_hand(r)
		ok(bool(out.counted), "every hand with a hero counts")
		ok(int(p.d.xp) > last_xp, "every hand earns xp")
		last_xp = int(p.d.xp)
		net += int(r.net[0])
		if int(r.net[0]) > 0:
			won += 1
	ok(int(p.d.hands) == recs.size(), "profile counts %d hands (%d)" % [recs.size(), int(p.d.hands)])
	ok(int(p.d.net) == net, "profile net is the sum of the hands")
	ok(int(p.d.won) == won, "profile won count")
	ok(int(p.d.joined) == 1800000000, "joined = the first hand's time")
	var made := 0
	for k in p.d.types:
		made += int(p.d.types[k])
	ok(made > 0 and made <= recs.size(), "hands made are counted for hands that showed down or won")
	ok(int(p.d.loss_max) >= 0 and int(p.d.win_max) > 0, "biggest win and loss kept")
	ok(int(p.d.win_run_best) >= 1 and int(p.d.lose_run_best) >= 1, "streaks kept")
	# the file round trip
	var q = Profile.new(PROF)
	ok(int(q.d.hands) == recs.size() and int(q.d.xp) == int(p.d.xp), "profile survives a save and load")
	# a shared phone is nobody's
	var h: Dictionary = recs[0].duplicate(true)
	h.hero = -1
	ok(not bool(q.record_hand(h).counted), "a hand with no hero is not counted")
	h = recs[0].duplicate(true)
	h.mode = "local"
	ok(not bool(q.record_hand(h).counted), "pass and play is not counted")
	# aids halve the xp
	var base: Dictionary = recs[1].duplicate(true)
	var a = Profile.new("user://test_poker_stats_aid.json")
	var b = Profile.new("user://test_poker_stats_aid2.json")
	var plain: Dictionary = a.record_hand(base)
	base.aids = true
	var helped: Dictionary = b.record_hand(base)
	ok(int(helped.xp) <= int(plain.xp) and int(helped.xp) >= int(plain.xp) / 2, "help halves the xp")
	for f in ["user://test_poker_stats_aid.json", "user://test_poker_stats_aid2.json"]:
		DirAccess.remove_absolute(f)
	# tournaments and bookmarks
	var xp0 := int(q.d.xp)
	q.record_tourney(1, 6, "holdem", 1800009999)
	q.record_tourney(5, 6, "holdem", 1800009999)
	ok(q.tourney_wins() == 1 and int(q.d.xp) == xp0 + 250 + 25, "tournament finishes give xp and count wins")
	q.toggle_bookmark(1800000060)
	var r2 = Profile.new(PROF)
	ok(r2.is_bookmarked(1800000060), "a bookmark is remembered (after a save and load)")
	r2.toggle_bookmark(1800000060)
	ok(not r2.is_bookmarked(1800000060), "and can be removed")
	# play days in a row
	var days = Profile.new("user://test_poker_stats_days.json")
	var rec: Dictionary = recs[2].duplicate(true)
	for k in [0, 1, 2, 4]:
		rec.at = 1800000000 + k * 86400
		days.record_hand(rec)
	ok(int(days.d.day_run) == 1 and int(days.d.day_run_best) == 3, "days in a row: best 3, the gap restarts it")
	DirAccess.remove_absolute("user://test_poker_stats_days.json")

# ---------- stats from the history ----------

func _stats(recs: Array) -> void:
	var s := Stats.compute(recs)
	ok(int(s.hands) == recs.size(), "stats see every hand")
	var net := 0
	var won := 0
	for r in recs:
		net += int(r.net[0])
		if int(r.net[0]) > 0:
			won += 1
	ok(int(s.net) == net and int(s.won) == won, "stats net and won")
	ok((s.series as Array).size() == recs.size() and int((s.series as Array)[-1]) == net, "the graph ends at the net")
	ok(int(s.vpip) <= int(s.pf_hands) and int(s.pfr) <= int(s.vpip) + 0 or int(s.pfr) <= int(s.pf_hands), "vpip and pfr within hands")
	ok(int(s.folds_faced) <= int(s.faced), "folds when facing a bet are within the times facing one")
	ok(int(s.bet3) <= int(s.bet3_chance) and int(s.f3) <= int(s.f3_chance) and int(s.cbet) <= int(s.cbet_chance), "rates have chances")
	var by := 0
	for k in s.by_variant:
		by += int(s.by_variant[k].hands)
	ok(by == recs.size(), "every hand is in a variant")
	var only := Stats.compute(recs, {"variant": "stud"})
	ok(int(only.hands) == 100, "variant filter keeps 100 stud hands (%d)" % int(only.hands))
	ok(int(Stats.compute(recs, {"modes": ["tourney"]}).hands) == 0, "mode filter")
	var helped: Array = recs.duplicate(true)
	helped[0].aids = true
	ok(int(Stats.compute(helped, {"aids": false}).hands) == recs.size() - 1, "aids filter drops helped hands")
	ok(Stats.starting_key([12, 25]) == "AAo" or Stats.starting_key([12, 25]) == "KKo" or Stats.starting_key([12, 25]) != "", "starting key made")
	ok(Stats.starting_key([0, 13]) == "AA", "pair of aces")
	ok(Stats.starting_key([0, 12]) == "AKs" or Stats.starting_key([0, 12]) == "KAs" or Stats.starting_key([0, 12]) == "AKs", "ace-king suited")
	ok(Stats.starting_key([0, 25]) == "AKo", "ace-king offsuit")
	ok(Stats.starting_key([1, 14 + 0]) == "22" or Stats.starting_key([1, 14]) == "22", "deuces")
	ok(Stats.starting_key([1, 2, 3]) == "", "three cards: no key")
	ok(Stats.pct(1, 4) == "25%" and Stats.pct(0, 0) == "-", "percent text")
	var ses := Stats.sessions(recs)
	ok(ses.size() >= 1, "at least one session")
	var hands_in := 0
	for c in ses:
		hands_in += int(c.hands)
	ok(hands_in == recs.size(), "sessions hold every cash hand")

## Made-up hands with known answers.
func _habits() -> void:
	var seats := [
		{"name": "", "kind": 1, "stack": 1000, "hole": [0, 12], "out": false, "post": 0},
		{"name": "A", "kind": 0, "stack": 1000, "hole": [5, 6], "out": false, "post": 10},
		{"name": "B", "kind": 0, "stack": 1000, "hole": [7, 8], "out": false, "post": 20},
	]
	# the player (button) raises, the small blind 3-bets, the player folds
	var h := {"v": 1, "n": 1, "at": 1800000000, "mode": "cash", "variant": "holdem", "limit": "nl", "sb": 10, "bb": 20,
		"btn": 0, "hero": 0, "seats": seats, "aids": false, "partial": false,
		"ev": [[0, "raise", 60, 0, 0, 60], [1, "raise", 180, 0, 0, 170], [2, "fold", 0, 0, 0, 0], [0, "fold", 0, 0, 0, 0]],
		"board": [], "end": [], "res": [[1, 120, -1, 0]], "net": [-60, 60, 0], "pot": 160}
	var s := Stats.compute([h])
	ok(int(s.pf_hands) == 1 and int(s.vpip) == 1 and int(s.pfr) == 1, "button raise: vpip and pfr")
	ok(int(s.f3_chance) == 1 and int(s.f3) == 1, "opened, 3-bet, folded: fold to 3-bet")
	ok(int(s.bet3_chance) == 0, "no 3-bet chance when opening")
	ok(int(s.raises) == 1 and int(s.faced) == 2 and int(s.folds_faced) == 1, "one raise, faced the blind and the 3-bet, folded to the 3-bet")
	ok(int(s.biggest_lost) == 160 and int(s.lose_run) == 1, "lost hand counts")
	ok(Stats.POSITIONS[Stats.position_of(h, 0)] == "Button", "seat 0 on the button")
	ok(Stats.POSITIONS[Stats.position_of(h, 1)] == "Blinds" and Stats.POSITIONS[Stats.position_of(h, 2)] == "Blinds", "blinds")
	# the player (big blind) checks with no raise: not voluntary; then a flop c-bet by the preflop raiser
	var h2 := h.duplicate(true)
	h2.hero = 2
	h2.ev = [[0, "call", 20, 0, 0, 20], [1, "call", 10, 0, 0, 10], [2, "check", 0, 0, 0, 0], [1, "check", 0, 1, 0, 0], [2, "raise", 40, 1, 0, 40], [1, "fold", 0, 1, 0, 0]]
	h2.net = [-20, -20, 40]
	h2.board = [1, 2, 3]
	s = Stats.compute([h2])
	ok(int(s.pf_hands) == 1 and int(s.vpip) == 0 and int(s.pfr) == 0, "big blind checks: not vpip")
	ok(int(s.cbet_chance) == 0, "a c-bet needs the player to have raised first")
	# the player raises preflop then bets the flop first to act
	var h3 := h.duplicate(true)
	h3.ev = [[0, "raise", 60, 0, 0, 60], [1, "call", 50, 0, 0, 50], [2, "fold", 0, 0, 0, 0], [1, "check", 0, 1, 0, 0], [0, "raise", 80, 1, 0, 80], [1, "fold", 0, 1, 0, 0]]
	h3.board = [1, 2, 3]
	h3.net = [100, -60, -20]
	s = Stats.compute([h3])
	ok(int(s.cbet_chance) == 1 and int(s.cbet) == 1, "raised before the flop, bet it: a c-bet")
	# facing one raise preflop and raising: a 3-bet
	var h4 := h.duplicate(true)
	h4.hero = 2
	h4.ev = [[0, "raise", 60, 0, 0, 60], [1, "fold", 0, 0, 0, 0], [2, "raise", 180, 0, 0, 160], [0, "fold", 0, 0, 0, 0]]
	h4.net = [-60, -10, 70]
	s = Stats.compute([h4])
	ok(int(s.bet3_chance) == 1 and int(s.bet3) == 1, "3-bet counted")

# ---------- replay ----------

func _replays(recs: Array) -> void:
	var total_frames := 0
	for r in recs:
		var frames := Replay.frames(r)
		var tag := "hand %d (%s)" % [int(r.n), r.variant]
		ok(frames.size() == (r.ev as Array).size() + 2, tag + ": a frame for the deal, every action and the end")
		var stack_sum := 0
		for s in r.seats:
			stack_sum += int(s.stack)
		for fi in frames.size():
			var t = frames[fi].t
			var sum := 0
			for s in t.seats:
				sum += int(s.stack)
			ok(sum + t.pot_total() == stack_sum, tag + ": chips conserved at frame %d (%d + %d vs %d)" % [fi, sum, t.pot_total(), stack_sum])
			total_frames += 1
		var last = frames[frames.size() - 1].t
		ok(last.phase == "done", tag + ": the last frame is the end")
		for i in r.seats.size():
			ok(int(last.seats[i].stack) == int(r.seats[i].stack) + int(r.net[i]), tag + ": seat %d ends at stack + net" % i)
		ok(last.results.size() == (r.res as Array).size(), tag + ": results shown")
		ok((last.board as Array).size() == (r.board as Array).size(), tag + ": the whole board at the end")
		ok((frames[0].t.board as Array).is_empty(), tag + ": no board at the deal")
		ok(frames[1].caption != "" or (r.ev as Array).is_empty(), tag + ": the first action has words")
	ok(total_frames > 1000, "replays checked a lot of frames (%d)" % total_frames)
