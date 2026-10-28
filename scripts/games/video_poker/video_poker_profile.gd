extends RefCounted

## The player's lifetime numbers for Poker, kept in user://video_poker_profile.json:
## XP and level, totals, the owner's list (biggest single-hand loss, hands made,
## most won per hand type, worst winning hand, best chips an hour, bb/100, date
## joined), streaks, tournament finishes and bookmarked hands. Fed one finished
## hand record at a time (video_poker_history.gd's format) by the game; the
## screens read it. Hands played on a shared phone (hero -1) are nobody's.
##
## Hands played with the coach or the win chance on (`aids`) count for half XP.

const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")

const PATH := "user://video_poker_profile.json"
## Hands this far apart (seconds) belong to different sessions.
const SESSION_GAP := 1800
## A session counts for "best chips an hour" from this long and this many hands.
const SESSION_MIN_SECONDS := 600
const SESSION_MIN_HANDS := 10
const KEEP_TOURNEYS := 200
const KEEP_BOOKMARKS := 300
const TITLES := ["Rail Bird", "Kibitzer", "Fish", "Grinder", "Regular", "Shark", "Pro", "High Roller", "Legend", "Voodoo Master"]
## XP for finishing a tournament 1st, 2nd, 3rd and lower.
const FINISH_XP := [250, 120, 60, 25]

var path: String
var d: Dictionary = {}

func _init(file_path: String = PATH) -> void:
	path = file_path
	load_file()

static func fresh() -> Dictionary:
	return {
		"v": 1, "joined": 0, "xp": 0, "hands": 0, "won": 0, "showdowns": 0, "showdowns_won": 0, "net": 0,
		"loss_max": 0, "win_max": 0,
		"types": {}, "type_best": {},                # hero's hand category (as text) -> count / most won
		"cash_hands": 0, "cash_bb": 0.0,              # for bb/100
		"cph_best": 0.0, "sess": {},                  # best chips an hour, the session in progress
		"win_run": 0, "win_run_best": 0, "lose_run": 0, "lose_run_best": 0,
		"day_last": 0, "day_run": 0, "day_run_best": 0,
		"by_variant": {}, "tourneys": [], "bookmarks": [],
		"career": {},                                  # stage id -> best stars (0-3)
	}

func load_file() -> void:
	d = fresh()
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in parsed:
		d[k] = parsed[k]

func save_file() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()

# ---------- XP and levels ----------

## XP needed to reach `level` (level 1 needs none): 100, 300, 600, 1000...
static func xp_for_level(level: int) -> int:
	return 50 * level * (level - 1)

static func level_for(xp: int) -> int:
	var l := 1
	while xp >= xp_for_level(l + 1):
		l += 1
	return l

static func title_for(level: int) -> String:
	return TITLES[clampi(level - 1, 0, TITLES.size() - 1)]

func level() -> int:
	return level_for(int(d.xp))

## Fraction of the way from this level to the next.
func level_progress() -> float:
	var l := level()
	var lo := xp_for_level(l)
	return float(int(d.xp) - lo) / float(maxi(1, xp_for_level(l + 1) - lo))

# ---------- feeding it ----------

## Counts one finished hand. Returns what happened, for the game's GameInfo
## counters and toasts: {counted, won, cat, showdown, uncontested, xp, level_up,
## net, pot}. {counted: false} for a hand nobody here played.
func record_hand(rec: Dictionary) -> Dictionary:
	var hero := int(rec.get("hero", -1))
	var out := {"counted": false}
	if hero < 0 or not rec.has("net") or hero >= (rec.net as Array).size() or str(rec.get("mode", "")) == "local":
		return out
	if int(d.joined) == 0:
		d.joined = int(rec.get("at", Time.get_unix_time_from_system()))
	var net := int(rec.net[hero])
	var won: bool = net > 0
	var mode := str(rec.get("mode", ""))
	var cat := _hero_category(rec, hero)
	var folded := _hero_folded(rec, hero)
	var shown := 0
	for r in rec.get("res", []):
		shown += int(r[3])
	var showdown := shown >= 2 and not folded
	d.hands = int(d.hands) + 1
	d.net = int(d.net) + net
	if won:
		d.won = int(d.won) + 1
		d.win_max = maxi(int(d.win_max), net)
		d.win_run = int(d.win_run) + 1
		d.win_run_best = maxi(int(d.win_run_best), int(d.win_run))
		d.lose_run = 0
	elif net < 0:
		d.loss_max = maxi(int(d.loss_max), -net)
		d.lose_run = int(d.lose_run) + 1
		d.lose_run_best = maxi(int(d.lose_run_best), int(d.lose_run))
		d.win_run = 0
	if showdown:
		d.showdowns = int(d.showdowns) + 1
		if won:
			d.showdowns_won = int(d.showdowns_won) + 1
	if cat >= 0 and not folded and (showdown or won):
		var key := str(cat)
		d.types[key] = int(d.types.get(key, 0)) + 1
		if won:
			d.type_best[key] = maxi(int(d.type_best.get(key, 0)), net)
	var v := str(rec.get("variant", "holdem"))
	var bv: Dictionary = d.by_variant.get(v, {"hands": 0, "won": 0, "net": 0})
	bv.hands = int(bv.hands) + 1
	bv.net = int(bv.net) + net
	if won:
		bv.won = int(bv.won) + 1
	d.by_variant[v] = bv
	if mode == "cash":
		d.cash_hands = int(d.cash_hands) + 1
		d.cash_bb = float(d.cash_bb) + float(net) / float(maxi(1, int(rec.get("bb", 20))))
		_session(int(rec.get("at", 0)), net)
	var before := level()
	var xp := 2 + (5 if won else 0) + (maxi(0, cat) * 3 if showdown and won else 0)
	if bool(rec.get("aids", false)):
		xp = int(ceil(xp / 2.0))
	d.xp = int(d.xp) + xp
	_day(int(rec.get("at", 0)))
	out.counted = true
	out.won = won
	out.cat = cat if not folded else -1
	out.showdown = showdown
	out.uncontested = won and not showdown
	out.xp = xp
	out.level_up = level() > before
	out.net = net
	out.pot = int(rec.get("pot", 0))
	save_file()
	return out

## A tournament ended for the player: `place` of `of`.
func record_tourney(place: int, of: int, variant: String, at: int = 0) -> int:
	var list: Array = d.tourneys
	list.append({"at": at if at > 0 else int(Time.get_unix_time_from_system()), "place": place, "of": of, "variant": variant})
	while list.size() > KEEP_TOURNEYS:
		list.pop_front()
	# a bigger field is worth more (a heads-up match half, a full table of six the base)
	var xp: int = roundi(FINISH_XP[clampi(place - 1, 0, FINISH_XP.size() - 1)] * clampf(float(of) / 6.0, 0.5, 1.2))
	d.xp = int(d.xp) + xp
	save_file()
	return xp

## A Career stage was played: `stars` earned (0 = lost). Keeps the best, and
## returns the XP: the stage's own XP the first time it is cleared, 30 for every
## star added after that. {} -> {"xp", "first", "added"}.
func record_career(id: String, stars: int, stage_xp: int) -> Dictionary:
	var best := int(d.career.get(id, 0))
	var out := {"xp": 0, "first": false, "added": 0}
	if stars > best:
		out.first = best == 0
		out.added = stars - best
		out.xp = stage_xp if best == 0 else 30 * (stars - best)
		d.career[id] = stars
		d.xp = int(d.xp) + int(out.xp)
		save_file()
	return out

func career_stars(id: String) -> int:
	return int(d.career.get(id, 0))

func tourney_wins() -> int:
	var n := 0
	for t in d.tourneys:
		if int(t.place) == 1:
			n += 1
	return n

# ---------- bookmarks ----------

func _bookmark_index(at: int) -> int:
	var list: Array = d.bookmarks
	for i in list.size():
		if int(list[i]) == at:  # numbers come back from JSON as floats
			return i
	return -1

func is_bookmarked(at: int) -> bool:
	return _bookmark_index(at) >= 0

func toggle_bookmark(at: int) -> void:
	var list: Array = d.bookmarks
	var i := _bookmark_index(at)
	if i >= 0:
		list.remove_at(i)
	else:
		list.append(at)
		while list.size() > KEEP_BOOKMARKS:
			list.pop_front()
	save_file()

# ---------- internals ----------

## Category (Eval.HIGH_CARD..) of the player's final hand, -1 when unknown.
func _hero_category(rec: Dictionary, hero: int) -> int:
	for r in rec.get("res", []):
		if int(r[0]) == hero and int(r[2]) >= 0:
			return Eval.category(int(r[2]))
	var seats: Array = rec.get("seats", [])
	if hero >= seats.size():
		return -1
	var hole: Array = seats[hero].hole
	for e in rec.get("end", []):
		if int(e[0]) == hero:
			hole = e[1]
	if hole.size() < 2:
		return -1
	var rules = Table.rules_for(str(rec.get("variant", "holdem")))
	var board: Array = rec.get("board", [])
	if hole.size() + board.size() < 5:
		return -1
	return Eval.category(rules.hand_score(hole, board))

func _hero_folded(rec: Dictionary, hero: int) -> bool:
	for e in rec.get("ev", []):
		if int(e[0]) == hero and str(e[1]) == "fold":
			return true
	return false

## Sessions: cash hands less than SESSION_GAP apart. The best chips an hour
## counts a session once it has run long enough to mean something.
func _session(at: int, net: int) -> void:
	var s: Dictionary = d.sess
	if s.is_empty() or at - int(s.last) > SESSION_GAP:
		s = {"start": at, "last": at, "net": 0, "hands": 0}
	s.last = at
	s.net = int(s.net) + net
	s.hands = int(s.hands) + 1
	var secs := int(s.last) - int(s.start)
	if secs >= SESSION_MIN_SECONDS and int(s.hands) >= SESSION_MIN_HANDS and int(s.net) > 0:
		d.cph_best = maxf(float(d.cph_best), float(s.net) * 3600.0 / float(secs))
	d.sess = s

## Days played in a row (UTC days).
func _day(at: int) -> void:
	var day := at / 86400
	var last := int(d.day_last)
	if day == last:
		return
	d.day_run = int(d.day_run) + 1 if day == last + 1 else 1
	d.day_last = day
	d.day_run_best = maxi(int(d.day_run_best), int(d.day_run))
