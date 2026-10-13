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
	print("PASS" if fails == 0 else "FAILED")
	quit(1 if fails > 0 else 0)
