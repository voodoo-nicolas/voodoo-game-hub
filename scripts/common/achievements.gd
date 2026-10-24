extends RefCounted

## Achievements (since v0.25): rules that turn a game's GameInfo stats into
## badges, plus the hub-wide ones. Ships in the APK, so every game gets them,
## including packs that never change:
##
## - **Generic, from the stats every game already records**: tiers of each
##   counter ("Wins", "Games played", "Puzzles solved"...), win streaks,
##   online wins, beating your own records (GameInfo counts those in
##   "_records"), and not giving up after losses.
## - **The game's own** (optional): `ACHIEVEMENTS` in `<id>_help.gd`, an Array
##   of {"id", "icon", "title", "desc", "key", "at"} plus "lower": true for
##   records where less is better (times, moves). Leave out "desc" for the
##   automatic "<stat>: <at>" line (only the title then needs Spanish). Unlocks when stats[key]
##   reaches `at`. Titles and descriptions are English literals (es.json).
## - **Hub-wide** (`HUB`): games tried, total badges, friends, invites. Kept in
##   user://achievements.json, checked by the hub's Achievements screen and by
##   Social.
##
## Unlocked badges are kept in the game's stats file as
## stats["_ach"] = {id: [unix_time, icon, title, desc]}, so the hub can list
## them without the game's pack being mounted.

const SaveUtil = preload("res://scripts/common/save_util.gd")

const HUB_PATH := "user://achievements.json"
## The leaderboard row that ranks players by badges (scores table, game id).
const BOARD_ID := "achievements"

## [threshold, icon, title] per tier. "%s" in the description is the stat's
## translated label: "Puzzles solved: 10".
const WIN_TIERS := [[1, "🥉", "First Win"], [10, "🥈", "Winner"], [50, "🥇", "Champion"], [100, "👑", "Legend"]]
const PLAY_TIERS := [[1, "🌱", "First Steps"], [10, "🔁", "Regular"], [50, "🔥", "Devotee"], [100, "💀", "Addict"]]
const COUNT_TIERS := [[1, "✨", "Off the Mark"], [10, "⭐", "Getting Good"], [50, "🌟", "Expert"], [100, "🏅", "Master"]]
const STREAK_TIERS := [[3, "🔥", "On a Roll"], [5, "⚡", "Unstoppable"], [10, "☄️", "Untouchable"]]
const ONLINE_TIERS := [[1, "🌐", "Online Debut"], [10, "📡", "Net Slayer"]]
const RECORD_TIERS := [[1, "📈", "Record Breaker"], [10, "🚀", "Always Improving"]]
const LOSS_TIERS := [[10, "🧟", "Never Give Up"]]

## Counters that count playing, not winning.
const PLAY_KEYS := ["Games played", "Rounds played", "Bus rides", "Tests taken", "Blitz runs", "2-player games", "Spins", "Rolls", "Cards played"]
const WIN_KEYS := ["Wins", "Games won", "Hands won"]
## Counters that are bookkeeping, not achievements (and, for GameInfo's
## record-breaker count, not records: a growing streak isn't "beating a record").
const SKIP_KEYS := ["Best streak", "Losses", "Draws", "Hands lost", "Wrong guesses", "Pushes", "2-player ties", "Online losses", "Online draws"]

## Hub-wide badges: [id, icon, title, description, what, at]. `what` is
## "games" (different games played), "badges" (all badges unlocked),
## "friends" or "invites".
const HUB := [
	["hub_games_1", "🎮", "Welcome!", "Play your first game", "games", 1],
	["hub_games_5", "🧭", "Explorer", "Play 5 different games", "games", 5],
	["hub_games_20", "🗺️", "Globetrotter", "Play 20 different games", "games", 20],
	["hub_games_50", "🌍", "World Tour", "Play 50 different games", "games", 50],
	["hub_badges_10", "🎖️", "Collector", "Unlock 10 achievements", "badges", 10],
	["hub_badges_50", "🏆", "Trophy Case", "Unlock 50 achievements", "badges", 50],
	["hub_badges_150", "💎", "Hall of Fame", "Unlock 150 achievements", "badges", 150],
	["hub_friends_1", "🤝", "Friendly", "Add your first friend", "friends", 1],
	["hub_friends_5", "🎉", "Crew", "Have 5 friends", "friends", 5],
	["hub_invites_1", "📨", "Party Host", "Invite a friend to a game", "invites", 1],
]

## Every achievement a game offers, given its help constants and current
## stats: [{id, icon, title, desc, key, at, lower}]. Titles/descs are English;
## `desc_key` (when set) is a stat label to format into desc.
static func defs_for(consts: Dictionary, stats: Dictionary) -> Array:
	var keys: Array = []
	for k in consts.get("STATS", []):
		keys.append(str(k))
	for k in stats:
		if not str(k).begins_with("_") and not keys.has(str(k)):
			keys.append(str(k))
	var out: Array = []
	for k in keys:
		var tiers: Array = _tiers_for(k)
		for t in tiers:
			out.append({"id": "%s_%d" % [k, t[0]], "icon": t[1], "title": t[2],
				"desc": "%s: %d", "desc_key": k, "key": k, "at": t[0], "lower": false})
	out.append_array(_records_defs())
	for a in consts.get("ACHIEVEMENTS", []):
		if typeof(a) == TYPE_DICTIONARY and a.has("id") and a.has("key"):
			var d := {"id": "g_" + str(a.id), "icon": str(a.get("icon", "🏅")), "title": str(a.get("title", "")),
				"desc": str(a.get("desc", "")), "key": str(a.key), "at": float(a.get("at", 1)),
				"lower": bool(a.get("lower", false))}
			if a.has("xp"):
				d["xp"] = clampi(int(a.xp), 0, XP_CHALLENGE_MAX)
			if d.desc == "":  # no description: "Best score: 500"
				d.desc = "%s: %d"
				d["desc_key"] = d.key
			out.append(d)
	return out

static func _tiers_for(key: String) -> Array:
	if key == "Best streak":
		return STREAK_TIERS
	if key == "Online wins":
		return ONLINE_TIERS
	if key == "Losses":
		return LOSS_TIERS
	if SKIP_KEYS.has(key) or _is_side_counter(key) or _is_record(key) or "time" in key.to_lower():
		return []
	if WIN_KEYS.has(key) or key.begins_with("Wins (") or key.begins_with("Games won ("):
		return WIN_TIERS
	if PLAY_KEYS.has(key):
		return PLAY_TIERS
	return COUNT_TIERS

static func _records_defs() -> Array:
	var out: Array = []
	for t in RECORD_TIERS:
		out.append({"id": "_records_%d" % t[0], "icon": t[1], "title": t[2],
			"desc": "Beat your own record %d times" if t[0] > 1 else "Beat one of your own records",
			"desc_num": t[0], "key": "_records", "at": t[0], "lower": false})
	return out

## "White wins", "Player 1 wins": same-phone side tallies, not your wins.
static func _is_side_counter(key: String) -> bool:
	return key.ends_with(" wins") and not key.begins_with("Online")

static func _is_record(key: String) -> bool:
	var k := key.to_lower()
	for p in ["best", "fewest", "most", "lowest", "fastest", "highest", "longest", "biggest"]:
		if k.begins_with(p):
			return true
	return false

static func is_unlocked(stats: Dictionary, def: Dictionary) -> bool:
	return typeof(stats.get("_ach")) == TYPE_DICTIONARY and stats._ach.has(def.id)

static func reached(stats: Dictionary, def: Dictionary) -> bool:
	if not stats.has(def.key):
		return false
	var v := float(stats[def.key])
	return v <= float(def.at) if def.lower else v >= float(def.at)

## Progress toward a counter badge, 0..1 (records with "lower" are all-or-nothing).
static func progress(stats: Dictionary, def: Dictionary) -> float:
	if reached(stats, def):
		return 1.0
	if def.lower or not stats.has(def.key):
		return 0.0
	return clampf(float(stats[def.key]) / maxf(float(def.at), 1.0), 0.0, 1.0)

## Marks newly reached badges as unlocked in `stats` and returns them.
static func check(consts: Dictionary, stats: Dictionary) -> Array:
	var got: Array = []
	if typeof(stats.get("_ach")) != TYPE_DICTIONARY:
		stats["_ach"] = {}
	for def in defs_for(consts, stats):
		if not stats._ach.has(def.id) and reached(stats, def):
			stats._ach[def.id] = [int(Time.get_unix_time_from_system()), def.icon, def.title, describe(def, false)]
			if def.has("xp"):
				stats._ach[def.id].append(int(def.xp))  # 5th: the game's own XP value
			got.append(def)
	return got

## The description, translated (or the English text to store, translate = false).
static func describe(def: Dictionary, translate: bool = true) -> String:
	var d: String = str(def.get("desc", ""))
	if def.has("desc_key"):
		var k: String = str(def.desc_key)
		return (_tr(d) % [_label(k), int(def.at)]) if translate else (d % [k, int(def.at)])
	if def.has("desc_num") and "%d" in d:
		return (_tr(d) % int(def.desc_num)) if translate else (d % int(def.desc_num))
	return _tr(d) if translate else d

static func _tr(s: String) -> String:
	return str(TranslationServer.translate(s))

## Same rule as GameInfo._label: "Best time (Hard)" -> tr("Best time (%s)") % tr("Hard").
static func _label(key: String) -> String:
	var whole := _tr(key)
	var open_at := key.rfind(" (")
	if whole != key or open_at <= 0 or not key.ends_with(")"):
		return whole
	var inner := key.substr(open_at + 2, key.length() - open_at - 3)
	return _tr(key.substr(0, open_at) + " (%s)").replace("%s", _tr(inner))

# ---------- across all games (hub) ----------

## {game_id: stats} for every game this player has stats for.
static func all_stats() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("user://")
	if dir == null:
		return out
	for f in dir.get_files():
		if f.begins_with("stats_") and f.ends_with(".json"):
			var data = JSON.parse_string(FileAccess.get_file_as_string("user://" + f))
			if typeof(data) == TYPE_DICTIONARY:
				out[f.trim_prefix("stats_").trim_suffix(".json")] = data
	return out

## Games with at least one real result recorded (not just the How to Play card opened).
static func games_played(all: Dictionary) -> int:
	var n := 0
	for id in all:
		for k in all[id]:
			if not str(k).begins_with("_"):
				n += 1
				break
	return n

static func game_badges(all: Dictionary) -> int:
	var n := 0
	for id in all:
		var a = all[id].get("_ach")
		if typeof(a) == TYPE_DICTIONARY:
			n += a.size()
	return n

static func load_hub() -> Dictionary:
	if FileAccess.file_exists(HUB_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(HUB_PATH))
		if typeof(data) == TYPE_DICTIONARY:
			if typeof(data.get("unlocked")) != TYPE_DICTIONARY:
				data["unlocked"] = {}
			return data
	return {"unlocked": {}}

static func save_hub(data: Dictionary) -> void:
	SaveUtil.write(HUB_PATH, data)

## Current value of a hub badge's measure. Friends and invites are counted
## by Social and stored in the hub file ("friends", "invites").
static func hub_value(what: String, all: Dictionary, hub: Dictionary) -> int:
	match what:
		"games":
			return games_played(all)
		"badges":
			return game_badges(all) + hub.unlocked.size()
	return int(hub.get(what, 0))

## Unlocks any hub badges now reached; returns the new ones as [id, icon, title, desc, ...].
static func check_hub(extra: Dictionary = {}) -> Array:
	var hub := load_hub()
	for k in extra:
		hub[k] = maxi(int(hub.get(k, 0)), int(extra[k]))
	var all := all_stats()
	var got: Array = []
	for h in HUB:
		if not hub.unlocked.has(h[0]) and hub_value(h[4], all, hub) >= int(h[5]):
			hub.unlocked[h[0]] = int(Time.get_unix_time_from_system())
			got.append(h)
	save_hub(hub)
	return got

## Unlocks, quietly, every badge already earned in every game's stats --
## from the stats keys alone (a game's own ACHIEVEMENTS need its pack, so
## GameInfo catches those when the game opens). Returns how many.
static func backfill_all() -> int:
	var n := 0
	for id in all_stats():
		var path := "user://stats_%s.json" % id
		var stats = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(stats) != TYPE_DICTIONARY:
			continue
		var got := check({}, stats)
		if not got.is_empty():
			n += got.size()
			SaveUtil.write(path, stats)
	return n

# ---------- Viral XP (since v0.35) ----------
## Each badge is also a "challenge" worth Viral XP: permanent, never spent,
## never decreases. A player's Viral Power is the sum over all games. The
## unlocked badges ARE the award log (id + unlock time); Social.sync_awards
## sends the new ones to the server, which keeps one row per challenge
## (idempotent) with caps per challenge and per game
## (supabase/migrations/20261013000000_awards_player.sql). Client-reported, so
## spoofable: don't use it for anything competitive that matters.
## XP by tier (the badge's threshold): bigger counts are worth more.
const XP_BY_AT := {1: 10, 3: 15, 5: 20, 10: 30, 50: 60, 100: 120, 150: 150}
const XP_DEFAULT := 25
const XP_GAME_OWN := 30  # a game's own ACHIEVEMENTS entry without its own value
const XP_HUB := 20
const HUB_GAME := "hub"

## XP for a game badge id: generic ids end in their threshold ("Wins_10").
static func xp_for(challenge_id: String) -> int:
	if challenge_id.begins_with("g_"):
		return XP_GAME_OWN
	var tail := challenge_id.get_slice("_", challenge_id.get_slice_count("_") - 1)
	return int(XP_BY_AT.get(int(tail), XP_DEFAULT)) if tail.is_valid_int() else XP_DEFAULT

# ---------- Developer API: challenges (since v0.35) ----------
## A game declares its challenges in `<id>_help.gd`:
##   const CHALLENGES := [
##     {"id": "boss_1", "title": "Boss Slayer", "icon": "🐉", "desc": "Beat the first boss",
##      "xp": 40, "hidden": false, "repeatable": false,
##      "event": "bossDefeated", "min": {"boss": 1}},        # optional rule, see on_event
##   ]
## and reports them one of two ways:
##   Achievements.report_challenge("my_game", "boss_1")           # explicit
##   Achievements.on_event("my_game", "bossDefeated", {"boss": 2}) # the declared rules decide
## Both are idempotent (a challenge pays out once; `repeatable` ones up to
## REPEAT_MAX times, each a separate award). Guard calls in packs:
##   var a = load("res://scripts/common/achievements.gd") if ResourceLoader.exists("res://scripts/common/achievements.gd") else null
## Stored apart from the game's stats file (user://challenges_<game>.json) so a
## game's own stats saves can never overwrite them. Log = source of truth: each
## entry is [unix_time, icon, title, desc, xp].
const REPEAT_MAX := 10
const XP_CHALLENGE_MAX := 200

static func challenges_path(game_id: String) -> String:
	return "user://challenges_%s.json" % game_id

## The game's declared CHALLENGES (from its help script), or [].
static func challenges_of(game_id: String) -> Array:
	var path := "res://scripts/games/%s/%s_help.gd" % [game_id, game_id]
	if not ResourceLoader.exists(path):
		return []
	var script = load(path)
	var consts: Dictionary = script.get_script_constant_map() if script != null else {}
	var list = consts.get("CHALLENGES", [])
	return list if list is Array else []

## hub.reportChallenge(gameId, challengeId): looks the challenge up in the
## game's CHALLENGES. Returns true if it newly paid out.
static func report_challenge(game_id: String, challenge_id: String) -> bool:
	for c in challenges_of(game_id):
		if typeof(c) == TYPE_DICTIONARY and str(c.get("id", "")) == challenge_id:
			return report(game_id, c)
	return false

## The adapter: a game says what happened ("levelComplete", {"level": 5}) and
## the declared rules decide. A rule is a CHALLENGES entry with "event" plus
## optional "min": {field: n} (payload[field] >= n), "max": {field: n}
## (<= n) and "equals": {field: value}. Returns the ids newly earned. Pass
## `rules` to use ones the game holds elsewhere.
static func on_event(game_id: String, event: String, payload: Dictionary = {}, rules: Array = []) -> Array:
	var got: Array = []
	for r in (rules if not rules.is_empty() else challenges_of(game_id)):
		if typeof(r) != TYPE_DICTIONARY or str(r.get("event", "")) != event or not _rule_passes(r, payload):
			continue
		if report(game_id, r):
			got.append(str(r.get("id", "")))
	return got

static func _rule_passes(rule: Dictionary, payload: Dictionary) -> bool:
	var mins = rule.get("min", {})
	for f in mins:
		if not payload.has(f) or float(payload[f]) < float(mins[f]):
			return false
	var maxs = rule.get("max", {})
	for f in maxs:
		if not payload.has(f) or float(payload[f]) > float(maxs[f]):
			return false
	var eq = rule.get("equals", {})
	for f in eq:
		if not payload.has(f) or payload[f] != eq[f]:
			return false
	return true

## Records one challenge as earned. Idempotent; false when already earned (or
## the repeat limit is reached, or the arguments are bad). Shows a toast and
## starts a Viral XP sync when it pays out.
static func report(game_id: String, c: Dictionary) -> bool:
	var id := str(c.get("id", ""))
	if id == "" or game_id == "" or "/" in game_id or "\\" in game_id or ".." in game_id:
		return false
	var path := challenges_path(game_id)
	var data := {"done": {}, "rep": {}}
	if FileAccess.file_exists(path):
		var loaded = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(loaded) == TYPE_DICTIONARY and typeof(loaded.get("done")) == TYPE_DICTIONARY:
			data = loaded
			if typeof(data.get("rep")) != TYPE_DICTIONARY:
				data["rep"] = {}
	var key := "c_" + id
	if bool(c.get("repeatable", false)):
		var n := int(data.rep.get(id, 0))
		if n >= REPEAT_MAX:
			return false
		data.rep[id] = n + 1
		key = "c_%s#%d" % [id, n + 1]
	elif data.done.has(key):
		return false
	var xp := clampi(int(c.get("xp", XP_GAME_OWN)), 0, XP_CHALLENGE_MAX)
	data.done[key] = [int(Time.get_unix_time_from_system()), str(c.get("icon", "🏅")),
			str(c.get("title", id)), str(c.get("desc", "")), xp]
	if not SaveUtil.write(path, data):
		return false
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var social = (loop as SceneTree).root.get_node_or_null("Social")
		if social != null:
			social.toast("%s  %s: %s  +%d XP" % [str(c.get("icon", "🏅")), _tr("Achievement unlocked!"), _tr(str(c.get("title", id))), xp])
			social.sync_awards()
	return true

## Everything earned so far as [{game, id, title, icon, xp, at}] (unix seconds):
## every game's badges plus the hub-wide ones (game "hub"). `skip_games` = ids to leave out.
static func collect_awards(skip_games: Array = []) -> Array:
	var out: Array = []
	var all := all_stats()
	for gid in all:
		if skip_games.has(gid):
			continue
		var a = all[gid].get("_ach")
		if typeof(a) != TYPE_DICTIONARY:
			continue
		for id in a:
			var v = a[id]
			if typeof(v) != TYPE_ARRAY or v.size() < 3:
				continue
			out.append({"game": gid, "id": str(id), "title": str(v[2]), "icon": str(v[1]),
					"xp": clampi(int(v[4]), 0, XP_CHALLENGE_MAX) if v.size() > 4 else xp_for(str(id)), "at": int(v[0])})
	var dir := DirAccess.open("user://")
	if dir != null:
		for f in dir.get_files():
			if not (f.begins_with("challenges_") and f.ends_with(".json")):
				continue
			var gid2 := f.trim_prefix("challenges_").trim_suffix(".json")
			if skip_games.has(gid2):
				continue
			var data = JSON.parse_string(FileAccess.get_file_as_string("user://" + f))
			if typeof(data) != TYPE_DICTIONARY or typeof(data.get("done")) != TYPE_DICTIONARY:
				continue
			for key in data.done:
				var v2 = data.done[key]
				if typeof(v2) == TYPE_ARRAY and v2.size() >= 5:
					out.append({"game": gid2, "id": str(key), "title": str(v2[2]), "icon": str(v2[1]),
							"xp": clampi(int(v2[4]), 0, XP_CHALLENGE_MAX), "at": int(v2[0])})
	var hub := load_hub()
	for h in HUB:
		if hub.unlocked.has(h[0]):
			out.append({"game": HUB_GAME, "id": str(h[0]), "title": str(h[2]), "icon": str(h[1]),
					"xp": XP_HUB, "at": int(hub.unlocked[h[0]])})
	return out

## How many awards the local record holds per game: {game_id: n}.
static func local_counts() -> Dictionary:
	var out := {}
	for a in collect_awards():
		out[a.game] = int(out.get(a.game, 0)) + 1
	return out

# ---------- restore from the server (since v0.38.3) ----------
## Reinstalling the app (or a wiped phone/PC) empties user://, but every badge
## earned while signed in is on the server (player_awards). Social calls this
## with one game's rows from player_compare(me, game) ({challenge_id, title,
## icon, xp, mine}) and the missing ones go back where collect_awards reads
## them: hub ones to achievements.json, "c_" ones to challenges_<game>.json,
## the rest to the game's stats file as _ach. Never removes or changes a badge
## already here. Returns the keys added ("game|id").
static func restore(game_id: String, rows: Array) -> Array:
	var added: Array = []
	if game_id == "" or "/" in game_id or "\\" in game_id or ".." in game_id:
		return added
	if game_id == HUB_GAME:
		var hub := load_hub()
		for r in rows:
			if _restorable(r) and not hub.unlocked.has(str(r.challenge_id)):
				hub.unlocked[str(r.challenge_id)] = int(r.mine)
				added.append("%s|%s" % [game_id, r.challenge_id])
		if not added.is_empty():
			save_hub(hub)
		return added
	var stats_path := "user://stats_%s.json" % game_id
	var stats = SaveUtil.read(stats_path)
	if stats == null:
		stats = {}
	if typeof(stats.get("_ach")) != TYPE_DICTIONARY:
		stats["_ach"] = {}
	var ch_path := challenges_path(game_id)
	var ch = SaveUtil.read(ch_path)
	if ch == null or typeof(ch.get("done")) != TYPE_DICTIONARY:
		ch = {"done": {}, "rep": {}}
	if typeof(ch.get("rep")) != TYPE_DICTIONARY:
		ch["rep"] = {}
	var stats_dirty := false
	var ch_dirty := false
	for r in rows:
		if not _restorable(r):
			continue
		var id := str(r.challenge_id)
		var entry := [int(r.mine), str(r.get("icon", "🏅")), str(r.get("title", id)), "",
				clampi(int(r.get("xp", 0)), 0, XP_CHALLENGE_MAX)]
		if id.begins_with("c_"):
			if ch.done.has(id):
				continue
			ch.done[id] = entry
			if "#" in id:  # repeatable: "c_<id>#<n>"
				var base := id.trim_prefix("c_").get_slice("#", 0)
				ch.rep[base] = maxi(int(ch.rep.get(base, 0)), int(id.get_slice("#", 1)))
			ch_dirty = true
		else:
			if stats._ach.has(id):
				continue
			entry[3] = _restored_desc(id)
			stats._ach[id] = entry
			stats_dirty = true
		added.append("%s|%s" % [game_id, id])
	if stats_dirty:
		SaveUtil.write(stats_path, stats)
	if ch_dirty:
		SaveUtil.write(ch_path, ch)
	return added

static func _restorable(r) -> bool:
	return typeof(r) == TYPE_DICTIONARY and str(r.get("challenge_id", "")) != "" \
			and (typeof(r.get("mine")) == TYPE_FLOAT or typeof(r.get("mine")) == TYPE_INT)

## The server doesn't keep descriptions; the generic ones can be rebuilt from
## the id ("Wins_10" -> "Wins: 10", "_records_10"), a game's own stay blank.
static func _restored_desc(id: String) -> String:
	for d in _records_defs():
		if d.id == id:
			return describe(d, false)
	var cut := id.rfind("_")
	if id.begins_with("g_") or cut <= 0 or not id.substr(cut + 1).is_valid_int():
		return ""
	return "%s: %d" % [id.substr(0, cut), int(id.substr(cut + 1))]

## Badges a game's stats file gained on disk (restored from the server) while
## a GameInfo held an older copy in memory: copied in so its next save keeps them.
static func merge_saved(path: String, stats: Dictionary) -> void:
	var disk = SaveUtil.read(path)
	if disk == null or typeof(disk.get("_ach")) != TYPE_DICTIONARY:
		return
	if typeof(stats.get("_ach")) != TYPE_DICTIONARY:
		stats["_ach"] = {}
	for id in disk._ach:
		if not stats._ach.has(id):
			stats._ach[id] = disk._ach[id]

## Viral Power from the local record (what the server will hold once synced).
static func local_power(skip_games: Array = []) -> int:
	var n := 0
	for a in collect_awards(skip_games):
		n += int(a.xp)
	return n

## Every badge unlocked, games and hub together.
static func total_unlocked() -> int:
	return game_badges(all_stats()) + load_hub().unlocked.size()
