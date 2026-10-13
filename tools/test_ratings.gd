extends SceneTree

## Age ratings in Catalog: a 13-15 account doesn't see 16+ games, an 18+ account does,
## a game without a content block is hidden (fail closed) once the manifest has any,
## an old manifest with none is left alone, the "Age-locked" listing marks locked games,
## and the bundled manifest has a valid block on every game.
##   godot --headless --path . --script res://tools/test_ratings.gd
## user://consent.json is backed up and restored.

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _ids(catalog) -> Array:
	var out := []
	for cat in catalog.categories:
		for g in cat.games:
			out.append(str(g.id))
	return out

func _initialize() -> void:
	var C = load("res://scripts/common/consent.gd")
	var path: String = C.PATH
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_string(path) if had else ""
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))

	# every bundled game has a valid block
	for cat in manifest.categories:
		for g in cat.games:
			if g.has("id"):
				var c = g.get("content")
				_check(typeof(c) == TYPE_DICTIONARY and [3, 7, 12, 16, 18].has(int(c.get("min_age", 0))), "%s has a valid content block" % g.id)

	# a test manifest: one 16+ game, one without a block
	var data: Dictionary = manifest.duplicate(true)
	var first: Dictionary = data.categories[0].games[0]
	var second: Dictionary = data.categories[0].games[1]
	var third: Dictionary = data.categories[0].games[2]
	first["content"] = {"min_age": 16, "descriptors": ["violence_cartoon"], "notes": ""}
	second.erase("content")
	var catalog = load("res://scripts/common/catalog.gd").new()
	_check(catalog._apply_manifest(data), "manifest accepted")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))   # a guest: unknown age
	catalog.refilter()
	var ids: Array = _ids(catalog)
	_check(not ids.has(first.id), "a guest doesn't see a 16+ game")
	_check(not ids.has(second.id), "a game without a content block is hidden (fail closed)")
	_check(ids.has(third.id), "a 3+ game is shown")
	_check(catalog.is_age_locked(catalog.get_game(first.id)), "is_age_locked for the 16+ game")

	C.record_age(1, 2012 - 0)   # 13-15 once the current year is 2026
	catalog.refilter()
	_check(C.max_game_age() == 12, "13-15 allows up to 12+")
	_check(not _ids(catalog).has(first.id), "a 13-15 account doesn't see a 16+ game")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	C.record_age(1, 2009)       # 17
	catalog.refilter()
	_check(C.max_game_age() == 16 and _ids(catalog).has(first.id), "a 16-17 account sees a 16+ game")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	C.record_age(1, 1990)
	catalog.refilter()
	_check(_ids(catalog).has(first.id) and C.max_game_age() == 18, "an 18+ account sees it")
	_check(not _ids(catalog).has(second.id), "...but a game with no block stays hidden for everyone")

	# the locked listing
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	C.record_age(1, 2012)
	catalog.show_locked = true
	catalog.refilter()
	_check(_ids(catalog).has(first.id) and catalog.get_game(first.id).get("locked", false) == true, "show_locked lists it, marked locked")
	_check(catalog.locked_count() >= 2, "locked_count counts the hidden games")
	catalog.show_locked = false

	# an old manifest with no content blocks at all: nothing is hidden
	var old: Dictionary = manifest.duplicate(true)
	for cat in old.categories:
		for g in cat.games:
			g.erase("content")
	var old_catalog = load("res://scripts/common/catalog.gd").new()
	old_catalog._apply_manifest(old)
	var visible := 0
	for cat in old_catalog.categories:
		visible += cat.games.size()
	var total := 0
	for cat in manifest.categories:
		total += cat.games.size()
	_check(visible == total, "an old manifest without ratings hides nothing (%d of %d)" % [visible, total])

	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS" if fails == 0 else "FAILED")
	quit(1 if fails > 0 else 0)
