extends SceneTree

## Headless test of the cloud-progress merge (STANDARDS §18):
##   godot --headless --path . --script res://tools/test_cloud_save.gd
## GameInfo.merge_stats only; no save data written, no network.

const GameInfo = preload("res://scripts/common/game_info.gd")
var fails := 0

func _initialize() -> void:
	var local := {"Wins": 3, "Best score": 500, "Best time (Hard)": 90.0, "Fewest moves": 20, "_seen": 1, "Only here": 7}
	var cloud := {"Wins": 5, "Best score": 400, "Best time (Hard)": 70.0, "Fewest moves": 25, "Only cloud": 2}
	var m: Dictionary = GameInfo.merge_stats(local, cloud)
	ok(int(m["Wins"]) == 5, "counts keep the bigger")
	ok(int(m["Best score"]) == 500, "highs keep the bigger")
	ok(float(m["Best time (Hard)"]) == 70.0, "best time keeps the smaller")
	ok(int(m["Fewest moves"]) == 20, "fewest keeps the smaller")
	ok(int(m["Only here"]) == 7 and int(m["Only cloud"]) == 2, "keys from both sides")
	ok(int(local["Wins"]) == 3, "local not changed in place")
	ok(GameInfo.merge_stats(m, m) == m, "merging equal copies changes nothing")
	print("FAILED %d" % fails if fails else "ALL OK")
	quit(1 if fails else 0)

func ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1
