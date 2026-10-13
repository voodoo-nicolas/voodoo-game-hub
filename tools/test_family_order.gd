extends SceneTree

## Catalog orders each category by family, then title (similar games sit
## together), placeholders last.
##   godot --headless --path . --script res://tools/test_family_order.gd

func _initialize() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	var catalog = load("res://scripts/common/catalog.gd").new()
	if not catalog._apply_manifest(data):
		print("FAIL: manifest rejected")
		quit(1)
		return
	var fails := 0
	for cat in catalog.categories:
		var seen := {}
		var prev := ""
		for g in cat.games:
			var fam := str(g.get("family", ""))
			if fam != "" and fam != prev and seen.has(fam):
				print("FAIL: %s: family '%s' is split (at %s)" % [cat.name, fam, g.get("id", "?")])
				fails += 1
			seen[fam] = true
			prev = fam
		var ids := []
		for g in cat.games:
			ids.append(str(g.get("id", "?")))
		print("%s: %s" % [cat.name, ", ".join(ids)])
	if fails == 0:
		print("PASS")
	quit(1 if fails > 0 else 0)
