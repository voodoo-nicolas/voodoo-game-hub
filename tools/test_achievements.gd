extends SceneTree

## Headless test for scripts/common/achievements.gd and its GameInfo hooks.
##   godot --headless --path . --script res://tools/test_achievements.gd
## Uses a throwaway game id ("zz_ach_test") and removes its stats file, but
## check_hub() writes user://achievements.json -- back up user data first.

const Achievements = preload("res://scripts/common/achievements.gd")
const GameInfo = preload("res://scripts/common/game_info.gd")

var fails := 0

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _help(src_consts: String) -> Script:
	var s := GDScript.new()
	s.source_code = "extends RefCounted\nconst ID := \"zz_ach_test\"\nconst TITLE := \"Test\"\n" + src_consts
	s.reload()
	return s

func _run() -> void:
	await process_frame
	var path := "user://stats_zz_ach_test.json"
	DirAccess.remove_absolute(path)
	var hub_before := FileAccess.get_file_as_string(Achievements.HUB_PATH) if FileAccess.file_exists(Achievements.HUB_PATH) else ""

	# --- pure rules ---
	var consts := {"STATS": ["Wins", "Losses", "Draws", "Best streak", "White wins", "Best score", "Puzzles solved", "Best time"]}
	var defs := Achievements.defs_for(consts, {})
	var ids := defs.map(func(d): return d.id)
	ok(ids.has("Wins_1") and ids.has("Wins_100"), "win tiers")
	ok(ids.has("Best streak_3") and ids.has("Best streak_10"), "streak tiers")
	ok(ids.has("Losses_10") and not ids.has("Losses_1"), "loss tier only at 10")
	ok(not ids.has("Draws_1") and not ids.has("White wins_1"), "draws / side counters skipped")
	ok(not ids.has("Best score_1") and not ids.has("Best time_1"), "records get no count tiers")
	ok(ids.has("Puzzles solved_10"), "other counters get tiers")
	ok(ids.has("_records_1") and ids.has("_records_10"), "record-breaker badges")
	var custom := Achievements.defs_for({"STATS": [], "ACHIEVEMENTS": [
		{"id": "fast", "title": "Speedy", "desc": "Under a minute", "key": "Best time", "at": 60, "lower": true}]}, {})
	var fast: Dictionary = custom.filter(func(d): return d.id == "g_fast")[0]
	ok(not Achievements.reached({"Best time": 75}, fast) and Achievements.reached({"Best time": 59}, fast), "lower-is-better custom badge")
	ok(not Achievements.reached({}, fast), "missing stat is not reached")
	var st := {"Wins": 12}
	var got := Achievements.check(consts, st)
	ok(got.size() == 2 and st._ach.has("Wins_1") and st._ach.has("Wins_10"), "check unlocks reached tiers once (%d)" % got.size())
	ok(Achievements.check(consts, st).is_empty(), "no double unlock")
	ok(is_equal_approx(Achievements.progress({"Wins": 25}, defs.filter(func(d): return d.id == "Wins_50")[0]), 0.5), "progress")
	ok(Achievements.describe(defs.filter(func(d): return d.id == "Wins_10")[0], false) == "Wins: 10", "stored description")

	# --- GameInfo hooks ---
	var info = GameInfo.new(_help("const STATS := [\"Wins\", \"Losses\", \"Best streak\", \"Best score\"]\n"))
	info.stats["_seen"] = 1  # no first-play card
	root.add_child(info)
	await process_frame
	for i in 3:
		info.result("win")
	ok(info.stats._ach.has("Wins_1") and info.stats._ach.has("Best streak_3"), "first win + on a roll after 3 wins")
	info.high("Best score", 10)
	ok(int(info.stats.get("_records", 0)) == 0, "first best is not a record break")
	info.high("Best score", 20)
	info.high("Best score", 15)
	ok(int(info.stats.get("_records", 0)) == 1, "beating it counts once (%s)" % info.stats.get("_records"))
	ok(info.stats._ach.has("_records_1"), "record breaker unlocked")
	var rows: Array = info.achievement_rows()
	ok(rows.size() > 5 and rows[0].unlocked and not rows[-1].unlocked, "rows: unlocked first")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	ok(typeof(saved) == TYPE_DICTIONARY and saved._ach.size() == info.stats._ach.size(), "badges saved with the stats")
	for i in 240:  # let the toasts run
		await process_frame
	info.queue_free()
	await process_frame

	# --- hub-wide ---
	var all := Achievements.all_stats()
	ok(all.has("zz_ach_test"), "all_stats reads stats files")
	ok(Achievements.games_played(all) >= 1, "games played counted")
	ok(Achievements.load_hub().unlocked.has("hub_games_1"), "hub badge after the first game")

	DirAccess.remove_absolute(path)
	if hub_before == "":
		DirAccess.remove_absolute(Achievements.HUB_PATH)
	else:
		var f := FileAccess.open(Achievements.HUB_PATH, FileAccess.WRITE)
		f.store_string(hub_before)
	print("ACHIEVEMENTS TEST: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
