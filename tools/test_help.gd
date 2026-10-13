extends SceneTree

## Crisis help: region from the locale, no pending numbers, tel: digits, newest
## data wins, the screen shows one big button per line (offline), a country with
## no data gets the fallback link. user://crisis_cache.json is backed up/restored.
##   godot --headless --path . --script res://tools/test_help.gd

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _initialize() -> void:
	var H = load("res://scripts/common/crisis_help.gd")
	_check(H.country("es_AR") == "AR" and H.country("es-AR") == "AR" and H.country("en_US") == "US", "country from locale")
	_check(H.country("es") == "" and H.country("") != null, "no country in a bare language")
	_check(H.dial_digits("0800 345 1435") == "08003451435" and H.dial_digits("(011) 5275-1135") == "01152751135", "dial digits")
	var path: String = H.CACHE_PATH
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_string(path) if had else ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var data: Dictionary = H.load_data()
	_check(not data.is_empty(), "bundled data loads")
	var ar: Array = H.resources_for(data, "AR")
	_check(ar.size() >= 3, "Argentina has its lines")
	for r in ar:
		_check(str(r.get("dial", "")) != "", "every line has a number")
	_check(H.resources_for(data, "ZZ").is_empty(), "unknown country has none")
	var raw := FileAccess.get_file_as_string("res://scripts/common/crisis_data.gd")
	_check(not ("pending_verification" in raw), "pending numbers are not in the bundle")

	# newest data wins; an older or broken cache is ignored
	var newer: Dictionary = data.duplicate(true)
	newer["updated"] = "2999-01-01"
	newer["emergency_note"] = {"es": "NEWER", "en": "NEWER"}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(newer))
	f.close()
	_check(str(H.load_data().get("emergency_note", {}).get("en", "")) == "NEWER", "a newer cached copy is used")
	newer["updated"] = "2000-01-01"
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(newer))
	f.close()
	_check(str(H.load_data().get("emergency_note", {}).get("en", "")) != "NEWER", "an older cached copy is ignored")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not json {")
	f.close()
	_check(not H.load_data().is_empty(), "a broken cache falls back to the bundle")
	if had:
		f = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# the screen: Argentina gets call buttons, an unknown country the fallback link
	for code in ["AR", "ZZ"]:
		H.forced_country = code
		var screen = load("res://scenes/hub/help.tscn").instantiate()
		root.add_child(screen)
		for i in 4:
			await process_frame
		var buttons := []
		_collect(screen, buttons)
		var dial_buttons := 0
		for b in buttons:
			if "📞" in (b as Button).text:
				dial_buttons += 1
		if code == "AR":
			_check(dial_buttons >= 3, "Argentina: a call button per line, got %d" % dial_buttons)
		else:
			_check(dial_buttons == 0 and buttons.size() >= 2, "unknown country: fallback link, no numbers")
		screen.queue_free()
	H.forced_country = ""
	print("PASS" if fails == 0 else "FAILED")
	quit(1 if fails > 0 else 0)

func _collect(n: Node, into: Array) -> void:
	if n is Button:
		into.append(n)
	for c in n.get_children():
		_collect(c, into)
