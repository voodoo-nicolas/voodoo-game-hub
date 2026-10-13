extends SceneTree

## Viral XP: XP per badge tier, award collection from the local record
## (read-only), and the "sent once" bookkeeping in Social (user://awards_synced.json
## is backed up and restored).
##   godot --headless --path . --script res://tools/test_xp.gd

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _initialize() -> void:
	var A = load("res://scripts/common/achievements.gd")
	_check(A.xp_for("Wins_1") == 10, "first tier = 10")
	_check(A.xp_for("Games played_100") == 120, "100 = 120")
	_check(A.xp_for("Best streak_3") == 15, "streak 3 = 15")
	_check(A.xp_for("g_speedrun") == A.XP_GAME_OWN, "game's own")
	_check(A.xp_for("Weird") == A.XP_DEFAULT, "unknown id gets the default")
	var awards: Array = A.collect_awards()
	var seen := {}
	for a in awards:
		var key := "%s|%s" % [a.game, a.id]
		_check(not seen.has(key), "duplicate award " + key)
		seen[key] = true
		_check(int(a.xp) >= 0 and int(a.xp) <= 200, "xp out of range for " + key)
		_check(str(a.game) != "" and str(a.id) != "", "empty game/id")
	var hub_total: int = A.local_power()
	var sum := 0
	for a in awards:
		sum += int(a.xp)
	_check(hub_total == sum, "local_power = sum of awards")
	print("local awards: %d, Viral Power %d" % [awards.size(), sum])

	var social = root.get_node("Social")
	var backup := ""
	var had := FileAccess.file_exists(social.SYNCED_PATH)
	if had:
		backup = FileAccess.get_file_as_string(social.SYNCED_PATH)
	var auth = root.get_node("Auth")
	auth.user_id = "test-user"
	var sent := [{"game": "chess", "id": "Wins_1"}, {"game": "chess", "id": "Wins_10"}]
	social._awards_busy = true
	social._on_awards(true, 40, sent)
	_check(social.my_power == 40, "power taken from the server's answer")
	var keys: Dictionary = social._synced_keys()
	_check(keys.has("chess|Wins_1") and keys.has("chess|Wins_10") and keys.size() == 2, "sent awards are remembered")
	auth.user_id = "someone-else"
	_check(social._synced_keys().is_empty(), "another account starts from nothing")
	if had:
		var f := FileAccess.open(social.SYNCED_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(social.SYNCED_PATH))
	_test_challenges(A)
	print("PASS" if fails == 0 else "FAILED")
	quit(1 if fails > 0 else 0)

## The developer API on a throwaway game id ("zz_test"): idempotent report,
## repeatable limit, event rules (min / max / equals), bad ids, XP clamp,
## and that collect_awards sees them. user://challenges_zz_test.json is removed.
func _test_challenges(A) -> void:
	var path: String = A.challenges_path("zz_test")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var c := {"id": "boss", "title": "Boss Slayer", "icon": "🐉", "xp": 40}
	_check(A.report("zz_test", c), "first report pays out")
	_check(not A.report("zz_test", c), "second report of the same challenge does nothing")
	var rep := {"id": "lap", "title": "Lap", "xp": 5, "repeatable": true}
	var paid := 0
	for i in 15:
		if A.report("zz_test", rep):
			paid += 1
	_check(paid == A.REPEAT_MAX, "repeatable pays %d times, got %d" % [A.REPEAT_MAX, paid])
	_check(not A.report("", c) and not A.report("zz/test", c) and not A.report("zz_test", {"title": "no id"}), "bad arguments are refused")
	A.report("zz_test", {"id": "huge", "title": "Huge", "xp": 99999})
	var rules := [
		{"id": "lvl5", "title": "Level 5", "xp": 20, "event": "levelComplete", "min": {"level": 5}},
		{"id": "fast", "title": "Fast", "xp": 20, "event": "levelComplete", "max": {"seconds": 30}},
		{"id": "hard", "title": "Hard", "xp": 20, "event": "levelComplete", "equals": {"mode": "hard"}},
	]
	_check(A.on_event("zz_test", "levelComplete", {"level": 3, "seconds": 45, "mode": "easy"}, rules).is_empty(), "no rule matches")
	_check(A.on_event("zz_test", "somethingElse", {"level": 9}, rules).is_empty(), "other event ignored")
	var got: Array = A.on_event("zz_test", "levelComplete", {"level": 5, "seconds": 20, "mode": "hard"}, rules)
	_check(got.size() == 3, "three rules match, got %d" % got.size())
	_check(A.on_event("zz_test", "levelComplete", {"level": 5, "seconds": 20, "mode": "hard"}, rules).is_empty(), "events are idempotent too")
	var mine := []
	for a in A.collect_awards():
		if a.game == "zz_test":
			mine.append(a)
			_check(int(a.xp) <= A.XP_CHALLENGE_MAX, "xp clamped for " + str(a.id))
	_check(mine.size() == 1 + A.REPEAT_MAX + 1 + 3, "collect_awards sees every reported award, got %d" % mine.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
