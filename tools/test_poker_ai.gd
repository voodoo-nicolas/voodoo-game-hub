extends SceneTree

## Headless baseline for the poker computer players and coach
## (video_poker_ai.gd): win-chance sums, outs, draw discards and the coach's
## deterministic parts, taken at ~200 states of seeded random hands of every
## variant. The fingerprint (GOLDEN) must stay the same through refactors and
## change only on purpose. Win chances are taken with no time cap, so the run
## is repeatable on any machine. Pure logic: touches no saves.
## godot --headless --path . --script res://tools/test_poker_ai.gd

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const AI = preload("res://scripts/games/video_poker/video_poker_ai.gd")

const RulesHoldem = preload("res://scripts/games/video_poker/video_poker_rules_holdem.gd")

const GOLDEN := "31c7f1cd424fe044eff1b163e5819c7a"

## A Hold'em with a 36-card deck (no 2-5) that counts every card it is asked to
## rate that isn't in that deck: the AI must deal from the table's deck only.
class Probe extends RulesHoldem:
	static var stray := 0
	func new_deck() -> Array:
		return range(52).filter(func(c): return c % 13 == 0 or c % 13 >= 5)
	func hand_score(hole: Array, board: Array) -> int:
		for c in hole + board:
			if c % 13 != 0 and c % 13 < 5:
				stray += 1
		return super(hole, board)

const CONFIGS := [["holdem", "nl"], ["holdem", "fl"], ["omaha", "pl"], ["omaha", "nl"], ["draw", "nl"],
	["draw", "fl"], ["stud", "fl"]]

var fails := 0

func _init() -> void:
	var a := _run(20261028)
	var b := _run(20261028)
	if a != b:
		fails += 1
		print("FAIL: the run is not repeatable")
	_probe()
	var fingerprint := a.md5_text()
	print("golden fingerprint: ", fingerprint, "  (", a.count("\n") + 1, " lines)")
	if GOLDEN != "" and fingerprint != GOLDEN:
		fails += 1
		print("FAIL: the AI's results changed (fingerprint is not GOLDEN)")
	print("poker ai: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)

## The AI works out win chances and outs on a table whose rules have another deck.
func _probe() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var t = Table.new()
	t._rules = Probe.new()
	for i in 3:
		t.seats.append(Table.new_seat("P%d" % i, 1000, 0, i))
	t.start_hand(rng)
	while t.board.size() < 3 and t.phase != "done":
		t.act("call")
	if t.board.size() < 3:
		fails += 1
		print("FAIL: the probe hand did not reach the flop")
		return
	var me: int = t.to_act
	var eq := AI.equity(t, me, 300, rng, 0, false, 0)
	var outs := AI.outs(t, me)
	if eq < 0.0 or eq > 1.0 or outs < 0 or outs > 36 - 5:
		fails += 1
		print("FAIL: odd result on a 36-card deck: eq ", eq, " outs ", outs)
	if Probe.stray > 0:
		fails += 1
		print("FAIL: the AI rated %d cards that are not in the table's deck" % Probe.stray)

func _run(seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	var arng := RandomNumberGenerator.new()
	rng.seed = seed_value
	arng.seed = seed_value + 1
	var lines := PackedStringArray()
	var count := 0
	for cfg in CONFIGS:
		for n in [3, 6]:
			var t = Table.new()
			t.variant = cfg[0]
			t.limit = cfg[1]
			t.sb = 10
			t.bb = 20
			for i in n:
				t.seats.append(Table.new_seat("P%d" % i, 1000, 0, i % 5))
			for hand in 3:
				if t.players_left() < 2:
					for s in t.seats:
						s.stack = 1000
				if not t.start_hand(rng):
					continue
				var guard := 0
				while t.phase != "done" and guard < 300:
					guard += 1
					if arng.randf() < 0.3:
						count += 1
						lines.append(_snapshot(t, count))
					_move(t, arng)
	return "\n".join(lines)

## Everything the AI says about the state in front of the seat to act.
func _snapshot(t, k: int) -> String:
	var me: int = t.to_act
	var parts := PackedStringArray(["%s/%s/%d/%d" % [t.variant, t.limit, t.seats.size(), k]])
	if t.phase == "draw":
		parts.append("discards " + str(AI.choose_discards(t.seats[me].hole)))
	else:
		var r := RandomNumberGenerator.new()
		r.seed = k
		parts.append("eq %.6f" % AI.equity(t, me, 30, r, 0, false, 0))
		r.seed = k + 1000
		parts.append("eq2 %.6f" % AI.equity(t, me, 30, r, 1, true, 0))
		if (t.variant == "holdem" or t.variant == "omaha") and t.board.size() >= 3 and t.board.size() < 5:
			parts.append("outs %d" % AI.outs(t, me))
	if k % 3 == 0:
		var a := AI.advise(t.to_dict(), k)
		parts.append("coach hand=%s tier=%s outs=%d disc=%s" % [a.hand, a.tier, a.outs, str(a.discards)])
		if t.variant == "holdem" and t.street == 0:
			parts.append("advice=%s why=%s" % [a.advice, a.why])
	return "|".join(parts)

func _move(t, arng: RandomNumberGenerator) -> void:
	if t.phase == "draw":
		var k := arng.randi_range(0, 3)
		var idx: Array = [0, 1, 2, 3, 4].slice(0, k)
		t.draw(idx)
		return
	var l: Dictionary = t.legal()
	var r := arng.randf()
	if r < 0.1:
		t.act("fold")
	elif r < 0.7:
		t.act("call")
	elif l.can_raise:
		t.act("raise", arng.randi_range(int(l.min_to), int(l.max_to)))
	else:
		t.act("call")
