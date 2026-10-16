extends RefCounted

## Last Shift statistics (v0.5), kept across runs in user://last_shift_stats.json and shown on the
## Statistics screen (start menu). The kill counter left the HUD: it lives here now.
##   total_kills        infected Nash took down, all runs together
##   best_run_kills     the most in one run
##   weapon_kills       weapon -> infected taken down with it (the favorite = the most)
##   fastest_escape     seconds, the quickest way out (and how: exit + difficulty)
##   most_money         the most cash picked up in one run
##   runs, escapes, deaths, play_time (all runs)
## Pure data + FileAccess (no Nodes), so tests can point `path` at a scratch file.
## Hub: the same numbers also go to GameInfo (`info`, set by last_shift_game.gd; null on apps
## without it and in tests), which shows them under 📊 Statistics, ranks the 🏆 Leaderboard and
## turns them into 🏅 badges. Keys: STATS in last_shift_help.gd.

const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")

static var path := "user://last_shift_stats.json"
## GameInfo, or null.
static var info = null

## Hub stat key per weapon (literals, so the i18n extractor sees them).
const WEAPON_STAT := {
	"fist": "Infected down: fists", "knife": "Infected down: knife", "arm": "Infected down: severed arm",
	"wrench": "Infected down: pipe wrench", "pistol": "Infected down: pistol",
}

static func _info_add(key: String, n: int = 1) -> void:
	if info != null and is_instance_valid(info):
		info.add(key, n)

static func _info_high(key: String, v: float) -> void:
	if info != null and is_instance_valid(info):
		info.high(key, v)

static func _blank() -> Dictionary:
	return {"total_kills": 0, "best_run_kills": 0, "weapon_kills": {}, "fastest_escape": -1.0,
		"fastest_exit": "", "fastest_difficulty": -1, "most_money": 0, "runs": 0, "escapes": 0,
		"deaths": 0, "play_time": 0.0}

static func read() -> Dictionary:
	var d := _blank()
	if not FileAccess.file_exists(path):
		return d
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed:
			d[k] = parsed[k]
	return d

static func _write(d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))

## A new game was started.
static func add_run() -> void:
	var d := read()
	d.runs = int(d.runs) + 1
	_write(d)
	_info_add("Nights started")

## Nash took an infected down with `weapon`. `run_kills` = the run's count so far.
static func add_kill(weapon: String, run_kills: int) -> void:
	var d := read()
	d.total_kills = int(d.total_kills) + 1
	d.best_run_kills = maxi(int(d.best_run_kills), run_kills)
	var wk: Dictionary = d.weapon_kills
	wk[weapon] = int(wk.get(weapon, 0)) + 1
	_write(d)
	_info_add("Infected down")
	_info_high("Most infected in one night", run_kills)
	if WEAPON_STAT.has(weapon):
		_info_add(WEAPON_STAT[weapon])

## The run's cash total went up (it only counts money picked up, not what was spent).
static func note_money(run_money: int) -> void:
	var d := read()
	if run_money > int(d.most_money):
		d.most_money = run_money
		_write(d)
	_info_high("Most money in one night", run_money)

static func add_death() -> void:
	var d := read()
	d.deaths = int(d.deaths) + 1
	_write(d)
	_info_add("Times caught")

## Adds play time (seconds) as it goes (the world flushes it on saves).
static func add_time(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var d := read()
	d.play_time = float(d.play_time) + seconds
	_write(d)
	_info_add("Total time played", roundi(seconds))

## Nash got out. Returns true if it was the fastest escape so far.
static func add_escape(seconds: float, exit_id: String, difficulty: int) -> bool:
	var d := read()
	d.escapes = int(d.escapes) + 1
	var best := float(d.fastest_escape) < 0.0 or seconds < float(d.fastest_escape)
	if best:
		d.fastest_escape = seconds
		d.fastest_exit = exit_id
		d.fastest_difficulty = difficulty
	_write(d)
	_info_add("Escapes")
	if info != null and is_instance_valid(info):
		info.low("Fastest escape time", seconds)
	return best

## The weapon with the most kills ("" before the first kill).
static func favorite_weapon(d: Dictionary) -> String:
	var best := ""
	var n := 0
	for w in LsEngine.WEAPON_ORDER:
		var k := int(d.weapon_kills.get(w, 0))
		if k > n:
			n = k
			best = w
	return best

## Forgets everything (tests only).
static func reset() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
