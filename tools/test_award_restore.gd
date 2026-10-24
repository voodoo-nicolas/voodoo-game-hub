extends SceneTree

## Restoring badges from the server (Achievements.restore): what player_compare
## returns goes back into a game's stats file (_ach), its challenges file and
## the hub file, never twice, never over a badge already here; GameInfo's save
## keeps badges restored while it held an older copy (merge_saved).
## Uses a made-up game id; user://achievements.json is backed up and restored.
##   godot --headless --path . --script res://tools/test_award_restore.gd

const GAME := "zz_restore_test"

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _initialize() -> void:
	var A = load("res://scripts/common/achievements.gd")
	var stats_path := "user://stats_%s.json" % GAME
	var ch_path: String = A.challenges_path(GAME)
	DirAccess.remove_absolute(stats_path)
	DirAccess.remove_absolute(ch_path)
	var hub_backup := FileAccess.get_file_as_string(A.HUB_PATH) if FileAccess.file_exists(A.HUB_PATH) else ""

	# A badge already here keeps its own time.
	A.SaveUtil.write(stats_path, {"Wins": 3, "_ach": {"Wins_1": [111, "🥉", "First Win", "Wins: 1"]}})
	var rows := [
		{"challenge_id": "Wins_1", "title": "First Win", "icon": "🥉", "xp": 10, "mine": 999.0, "theirs": 999.0},
		{"challenge_id": "Wins_10", "title": "Winner", "icon": "🥈", "xp": 30, "mine": 1000.0, "theirs": 1000.0},
		{"challenge_id": "_records_10", "title": "Always Improving", "icon": "🚀", "xp": 30, "mine": 1001.0},
		{"challenge_id": "g_boss", "title": "Boss", "icon": "🐉", "xp": 40, "mine": 1002.0},
		{"challenge_id": "c_level5", "title": "Level 5", "icon": "⭐", "xp": 50, "mine": 1003.0},
		{"challenge_id": "c_daily#3", "title": "Daily", "icon": "📅", "xp": 20, "mine": 1004.0},
		{"challenge_id": "nobody", "title": "Not mine", "icon": "?", "xp": 5, "mine": null},
	]
	var added: Array = A.restore(GAME, rows)
	_check(added.size() == 5, "5 added, got %d: %s" % [added.size(), added])
	_check(not added.has(GAME + "|Wins_1"), "existing badge not re-added")
	var stats = A.SaveUtil.read(stats_path)
	_check(int(stats._ach.Wins_1[0]) == 111, "existing badge keeps its time")
	_check(int(stats.Wins) == 3, "stats kept")
	_check(stats._ach.has("Wins_10") and str(stats._ach.Wins_10[3]) == "Wins: 10", "generic desc rebuilt")
	_check(str(stats._ach._records_10[3]) == "Beat your own record 10 times", "records desc rebuilt")
	_check(str(stats._ach.g_boss[3]) == "" and int(stats._ach.g_boss[4]) == 40, "own badge: blank desc, server xp")
	var ch = A.SaveUtil.read(ch_path)
	_check(ch.done.has("c_level5") and ch.done.has("c_daily#3"), "challenges restored")
	_check(int(ch.rep.daily) == 3, "repeat count restored")
	_check(not A.report(GAME, {"id": "level5"}), "restored challenge doesn't pay out again")
	_check(A.restore(GAME, rows).is_empty(), "second restore adds nothing")

	# collect_awards sees them (so Viral Power and the 🏅 screen count them).
	var n := 0
	for a in A.collect_awards():
		if a.game == GAME:
			n += 1
	_check(n == 6, "collect_awards finds 6, got %d" % n)
	_check(int(A.local_counts().get(GAME, 0)) == 6, "local_counts")

	# A GameInfo holding an older copy keeps the restored badges when it saves.
	var held := {"Wins": 4, "_ach": {"Wins_1": [111, "🥉", "First Win", "Wins: 1"]}}
	A.merge_saved(stats_path, held)
	_check(held._ach.has("Wins_10") and held._ach.has("g_boss") and int(held.Wins) == 4, "merge_saved")

	# Hub badges go to achievements.json.
	var got_hub: Array = A.restore(A.HUB_GAME, [{"challenge_id": "hub_games_1", "title": "Welcome!", "icon": "🎮", "xp": 20, "mine": 5.0}])
	_check(A.load_hub().unlocked.has("hub_games_1"), "hub badge present")
	_check(got_hub.size() <= 1, "hub restore adds at most one")
	_check(A.restore("../evil", rows).is_empty(), "bad game id refused")

	DirAccess.remove_absolute(stats_path)
	DirAccess.remove_absolute(ch_path)
	if hub_backup != "":
		var f := FileAccess.open(A.HUB_PATH, FileAccess.WRITE)
		f.store_string(hub_backup)
		f.close()
	else:
		DirAccess.remove_absolute(A.HUB_PATH)
	print("award restore: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
