extends SceneTree

## Archived games (HUB_V2_PLAN §6): Catalog must drop them from the hub's
## categories and from get_game(), so nothing lists, launches, resumes or
## accepts invites for them, while every live game stays.
##   godot --headless --path . --script res://tools/test_archived.gd

const ARCHIVED := ["kings_cup", "red_or_black", "three_man", "never_have_i_ever",
		"most_likely_to", "ride_the_bus", "spin_the_bottle", "would_you_rather"]

func _initialize() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	var catalog = load("res://scripts/common/catalog.gd").new()
	var fails := 0
	if not catalog._apply_manifest(data):
		print("FAIL: manifest rejected")
		quit(1)
		return
	var listed := {}
	for cat in catalog.categories:
		if str(cat.name) == "Drinking Games":
			print("FAIL: the archived category is still listed")
			fails += 1
		for g in cat.games:
			listed[str(g.get("id", ""))] = true
	for id in ARCHIVED:
		if listed.has(id):
			print("FAIL: %s is listed" % id)
			fails += 1
		if not catalog.get_game(id).is_empty():
			print("FAIL: get_game(%s) still finds it" % id)
			fails += 1
		if not catalog.is_archived(id):
			print("FAIL: is_archived(%s) is false" % id)
			fails += 1
	var live := 0
	for raw_cat in data.categories:
		for g in raw_cat.games:
			if not g.get("archived", false) and not raw_cat.get("archived", false):
				live += 1
				if not listed.has(g.id) or catalog.get_game(g.id).is_empty():
					print("FAIL: live game %s missing" % g.id)
					fails += 1
	# An app before v0.29 has no archive support: the same manifest must still
	# parse there (it simply lists the category) -- the flag is an extra key.
	print("%d live games listed, %d archived hidden, %d failure(s)" % [live, ARCHIVED.size(), fails])
	catalog.free()
	quit(1 if fails else 0)
