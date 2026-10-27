extends RefCounted

## Hand history for Poker (id video_poker): one record per hand played, kept
## on the device in a JSON-lines file, so stats, replay and review can be built
## on it later. Nothing here changes how the game plays.
##
## It watches the table instead of being told about moves: the game calls
## observe() after every change to the table (a deal, the player's move, a
## computer's move, a move from the other phone, a resumed save). That way the
## host, the guest and a resumed game all record the same hand, and the
## table's own state (what is saved and sent online) does not grow. Calling it
## again for a state it has already seen does nothing.
##
## A record (one line of the file):
##   n          hand number at its table      at      unix time
##   mode       cash | tourney | local | practice | online
##   variant, limit, sb, bb, btn (dealer seat), hero (the local player's seat, -1 none)
##   seats      [{name, kind, stack (before blinds), hole (dealt), out, post (blinds/antes)}]
##   ev         actions in order: [seat, code, amount, street, allin, added]
##              code fold | check | call | raise | draw; amount = raise-to (a
##              call's chips, an all-in's whole bet; a draw's cards swapped);
##              street = betting round (0 first); added = chips it put in
##   board      community cards at the end
##   end        [[seat, hole]] for seats whose cards changed (Draw, Stud's later cards)
##   res        [[seat, won, score, shown]] at the end (score is video_poker_eval's)
##   net        chips won minus put in, per seat        pot  total chips in
##   aids       the coach was on at some point (leaderboards can skip such hands)
##   partial    the recorder joined mid-hand (a save from before this existed):
##              `ev` has gaps, the rest is right
## Cards are ints 0..51 (video_poker_eval.gd).

const PATH := "user://video_poker_history.jsonl"
## Hands kept; the file is trimmed back to this once it holds SLACK more.
const KEEP := 1000
const SLACK := 200

var path: String
var keep: int
## The hand in progress ({} between hands). Keys starting with _ are the
## recorder's own bookkeeping and never reach the file; the whole thing goes
## into the game's save (current() / restore()) so a resumed hand carries on.
var cur: Dictionary = {}
var _done_n := -1
var _count := -1

func _init(file_path: String = PATH, keep_hands: int = KEEP) -> void:
	path = file_path
	keep = keep_hands

## Call after every change to table `t`. `hero` is the local player's seat
## (-1 on a shared phone), `aids` whether the coach is on.
func observe(t, mode: String, hero: int, aids: bool) -> void:
	if t.seats.is_empty() or t.phase == "idle":
		return
	var sig := _signature(t)
	if not cur.is_empty():
		if int(cur.n) != t.hand_no:
			cur = {}  # a hand that never finished (left the table, a new match)
		elif str(cur.get("_sig", "")) == sig:
			return
	var fresh := false
	if cur.is_empty():
		if t.phase == "done" and t.hand_no == _done_n:
			return  # the hand just recorded, seen again
		_begin(t, mode, hero)
		fresh = true
	if aids:
		cur.aids = true
	if not fresh:
		_event(t)
	cur._sig = sig
	cur._pa = t.to_act
	cur._pcb = t.current_bet
	cur._pst = t.street
	if t.phase == "done":
		_finish(t)

## Forget the hand in progress (a new game or match started).
func abandon() -> void:
	cur = {}

## The hand in progress, for the game's save.
func current() -> Dictionary:
	return cur.duplicate(true)

## Takes back what current() gave (read from JSON: numbers come back as floats).
func restore(d: Variant) -> void:
	cur = {}
	if typeof(d) == TYPE_DICTIONARY and d.has("n") and d.has("seats") and d.has("ev"):
		cur = _norm(d)

# ---------- recording ----------

func _signature(t) -> String:
	var parts := PackedStringArray([str(t.hand_no), str(t.phase), str(t.street), str(t.to_act), str(t.pot_total()),
		str(t.current_bet), str(t.last_event)])
	for s in t.seats:
		parts.append("%d.%d.%s.%d" % [int(s.stack), int(s.bet), "f" if s.folded else "-", int(s.drew)])
	return "|".join(parts)

## True when the table is as start_hand left it: only forced bets made.
func _fresh(t) -> bool:
	if t.street != 0:
		return false
	for s in t.seats:
		if s.folded or not (str(s.act) in ["", "Small blind", "Big blind", "Ante", "Bring-in"]):
			return false
	return true

func _begin(t, mode: String, hero: int) -> void:
	var seats: Array = []
	var tot: Array = []
	for s in t.seats:
		seats.append({"name": str(s.name), "kind": int(s.kind), "stack": int(s.stack) + int(s.total),
			"hole": s.hole.duplicate(), "out": bool(s.out), "post": int(s.total)})
		tot.append(int(s.total))
	cur = {"v": 1, "n": t.hand_no, "at": int(Time.get_unix_time_from_system()), "mode": mode, "variant": t.variant,
		"limit": t.limit, "sb": t.sb, "bb": t.bb, "btn": t.button, "hero": hero, "seats": seats, "ev": [],
		"aids": false, "partial": not _fresh(t), "_tot": tot, "_sig": "", "_pa": -1, "_pcb": 0, "_pst": 0}

## The move that took the table from the last state seen to this one. The last
## move of a hand is not in t.last_event (that says who won), so it is read off
## the seat that was to act: a seat keeps its action label until the next round.
func _event(t) -> void:
	var actor: int = int(cur._pa)
	var le: Dictionary = t.last_event
	var code := ""
	var amount := 0
	if not le.is_empty() and str(le.get("action", "")) != "win":
		actor = int(le.seat)
		code = str(le.action)
		amount = int(le.amount)
	elif actor >= 0 and actor < t.seats.size():
		var s: Dictionary = t.seats[actor]
		amount = int(s.amt)
		match str(s.act):
			"Fold": code = "fold"
			"Check": code = "check"
			"Call": code = "call"
			"Bet", "Raise", "Complete": code = "raise"
			"All in": code = "raise" if amount > int(cur._pcb) else "call"
			"Draw", "Stand pat": code = "draw"
	var tot: Array = cur._tot
	if code != "" and actor >= 0 and actor < t.seats.size():
		var s2: Dictionary = t.seats[actor]
		cur.ev.append([actor, code, amount, int(cur._pst), 1 if s2.allin else 0, int(s2.total) - int(tot[actor])])
	for i in mini(tot.size(), t.seats.size()):
		tot[i] = int(t.seats[i].total)

func _finish(t) -> void:
	cur.board = t.board.duplicate()
	var ends: Array = []
	var net: Array = []
	var pot := 0
	for i in t.seats.size():
		var s: Dictionary = t.seats[i]
		if i < cur.seats.size() and s.hole != cur.seats[i].hole:
			ends.append([i, s.hole.duplicate()])
		net.append(int(s.won) - int(s.total))
		pot += int(s.total)
	cur.end = ends
	cur.net = net
	cur.pot = pot
	var res: Array = []
	for r in t.results:
		res.append([int(r.seat), int(r.won), int(r.score), 1 if r.shown else 0])
	cur.res = res
	var rec := {}
	for k in cur:
		if not str(k).begins_with("_"):
			rec[k] = cur[k]
	_append(rec)
	_done_n = t.hand_no
	cur = {}

# ---------- the file ----------

func _append(rec: Dictionary) -> void:
	if _count < 0:
		_count = count()
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(rec))
	f.close()
	_count += 1
	if _count > keep + SLACK:
		_trim()

## Hands in the file.
func count() -> int:
	return load_all(path).size()

## Keeps the last `keep` hands (written to a temp file and renamed, so a kill
## mid-write leaves the old file whole).
func _trim() -> void:
	var all := load_all(path)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	for d in all.slice(maxi(0, all.size() - keep)):
		f.store_line(JSON.stringify(d))
	f.close()
	if DirAccess.rename_absolute(tmp, path) == OK:
		_count = mini(all.size(), keep)

## Every hand in the file, oldest first. Numbers come back as floats (JSON).
static func load_all(file_path: String = PATH) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(file_path):
		return out
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line == "":
			continue
		var d = JSON.parse_string(line)
		if typeof(d) == TYPE_DICTIONARY:
			out.append(d)
	f.close()
	return out

## Whole floats back to ints, all the way down.
static func _norm(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floorf(v) else v
		TYPE_ARRAY:
			var a: Array = []
			for x in v:
				a.append(_norm(x))
			return a
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = _norm(v[k])
			return d
	return v
