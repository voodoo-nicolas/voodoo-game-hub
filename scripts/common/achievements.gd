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
	["hub_games_1", "🎮", "Welcome to Voodoo", "Play your first game", "games", 1],
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

## Every badge unlocked, games and hub together.
static func total_unlocked() -> int:
	return game_badges(all_stats()) + load_hub().unlocked.size()
