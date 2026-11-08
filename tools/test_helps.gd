extends SceneTree

## Helps pool (STANDARDS §17, Landing kit): 3 max, one back 24 h after the
## LAST help used, then one per 24 h. Restores the player's real
## user://helps.json afterwards.
##   godot --headless --path . --script res://tools/test_helps.gd

const Kit = preload("res://tools/templates/home_kit.gd")
const DAY := 86400
const ID := "test_helps_game"

var fails := 0

func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func put(left: int, ago: int) -> void:
	var all: Dictionary = Kit._helps_all()
	all[ID] = {"left": left, "stamp": int(Time.get_unix_time_from_system()) - ago}
	var f := FileAccess.open(Kit.HELPS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(all))
	f = null

func _init() -> void:
	var backup := ""
	if FileAccess.file_exists(Kit.HELPS_PATH):
		backup = FileAccess.get_file_as_string(Kit.HELPS_PATH)
	var all: Dictionary = Kit._helps_all()
	all.erase(ID)
	var f := FileAccess.open(Kit.HELPS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(all))
	f = null

	check(Kit.helps_left(ID) == 3, "a new game has 3")
	check(Kit.help_wait(ID) == 0, "full: no wait")
	check(Kit.use_help(ID) and Kit.use_help(ID) and Kit.use_help(ID), "spend 3")
	check(Kit.helps_left(ID) == 0, "then 0")
	check(not Kit.use_help(ID), "can't spend a 4th")
	check(abs(Kit.help_wait(ID) - DAY) <= 2, "wait is 24 h after the last use")
	# Clock starts at the LAST use: 0 left, used 23 h ago -> still 0.
	put(0, DAY - 3600)
	check(Kit.helps_left(ID) == 0, "23 h after the last use: still 0")
	check(abs(Kit.help_wait(ID) - 3600) <= 2, "1 h to go")
	put(0, DAY + 5)
	check(Kit.helps_left(ID) == 1, "24 h: one back")
	put(0, 2 * DAY + 5)
	check(Kit.helps_left(ID) == 2, "48 h: two back")
	put(0, 10 * DAY)
	check(Kit.helps_left(ID) == 3, "capped at 3")
	check(Kit.help_wait(ID) == 0, "full again: no wait")
	# 1 left, 20 h since the last use; using it now restarts the clock.
	put(1, 20 * 3600)
	check(Kit.helps_left(ID) == 1, "1 left")
	check(Kit.use_help(ID), "use the last one")
	check(Kit.helps_left(ID) == 0 and abs(Kit.help_wait(ID) - DAY) <= 2, "clock restarted: 24 h, not 4 h")
	# A clock set back (stamp in the future) counts from now, never negative.
	put(1, -5 * DAY)
	check(Kit.helps_left(ID) == 1, "future stamp: no gain, no loss")
	check(Kit.help_wait_text(ID) != "", "wait text")

	if backup != "":
		f = FileAccess.open(Kit.HELPS_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f = null
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Kit.HELPS_PATH))
	print("helps: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
