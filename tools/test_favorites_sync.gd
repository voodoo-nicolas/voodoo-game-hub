extends SceneTree

## Headless test of ★ favorites across devices (scripts/common/hub_data.gd, owner 2026-11-20):
##   godot --headless --path . --script res://tools/test_favorites_sync.gd
## No network: feeds _on_cloud_favorites() what load_favorites would return.
## Backs up and restores user://favorites.json.

const HubData = preload("res://scripts/common/hub_data.gd")
var fails := 0

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func _set_local(ids: Array, at: int, uid: String) -> void:
	HubData._write(HubData.FAVORITES_PATH, {"ids": ids, "at": at, "uid": uid})

func _local() -> Dictionary:
	return HubData._read(HubData.FAVORITES_PATH)

func _run() -> void:
	await process_frame
	var A = root.get_node("Auth")
	var bak := FileAccess.get_file_as_string(HubData.FAVORITES_PATH) if FileAccess.file_exists(HubData.FAVORITES_PATH) else ""
	var was := [A.user_id, A.access_token]
	A.user_id = "me"
	A.access_token = ""   # not really signed in: any push fails quietly, no network

	_set_local(["a", "b"], 50, "")
	HubData._on_cloud_favorites(true, {"ids": ["b", "c"], "at": 100}, "me")
	ok(_local().ids == ["b", "c", "a"] and _local().uid == "me", "a guest's favorites join the account (%s)" % str(_local().ids))

	_set_local(["x"], 200, "me")
	HubData._on_cloud_favorites(true, {"ids": ["y"], "at": 100}, "me")
	ok(_local().ids == ["x"], "this device changed last: its list wins")

	_set_local(["x"], 100, "me")
	HubData._on_cloud_favorites(true, {"ids": ["y"], "at": 200}, "me")
	ok(_local().ids == ["y"] and int(_local().at) == 200, "another device changed last: its list wins (a removal too)")

	_set_local(["theirs"], 300, "someone_else")
	HubData._on_cloud_favorites(true, {"ids": ["mine"], "at": 10}, "me")
	ok(_local().ids == ["mine"] and _local().uid == "me", "another account's list on this device is replaced by mine")

	_set_local(["x", "z"], 100, "me")
	HubData._on_cloud_favorites(true, null, "me")
	ok(_local().ids == ["x", "z"], "nothing in the cloud yet: the device list stays (and goes up)")

	_set_local(["x"], 100, "me")
	HubData._on_cloud_favorites(false, null, "me")
	ok(_local().ids == ["x"] and int(_local().at) == 100, "no table / offline: nothing changes")

	A.user_id = "other"
	_set_local(["x"], 100, "me")
	HubData._on_cloud_favorites(true, {"ids": ["late"], "at": 999}, "me")
	ok(_local().ids == ["x"], "a reply for an account that's no longer signed in is ignored")

	A.user_id = ""
	_set_local(["x"], 100, "me")
	HubData.toggle_favorite("q")
	ok(_local().ids == ["x", "q"] and _local().uid == "me", "signed out: a change keeps whose list it is")

	A.user_id = was[0]
	A.access_token = was[1]
	if bak == "":
		DirAccess.remove_absolute(HubData.FAVORITES_PATH)
	else:
		var f := FileAccess.open(HubData.FAVORITES_PATH, FileAccess.WRITE)
		f.store_string(bak)
		f.close()
	print("favorites sync: %d failure(s)" % fails)
	quit(fails)
