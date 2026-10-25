extends SceneTree

## Game versions + game updates: Catalog.version_text / has_update /
## updates_available, the version line in the Game Browser detail, and the
## Options "Game updates" section (no network: the list comes from a fake game).
##   godot --headless --path . --script res://tools/test_game_updates.gd
## Uses a made-up game id ("zz_test_update") and removes its fake pack and
## version entry afterwards, so the real saves are left as they were.

const FAKE := "zz_test_update"

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _initialize() -> void:
	var catalog = root.get_node("Catalog")
	await process_frame   # autoloads load their saved data in _ready
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")   # the strings below are the English ones

	# A bundled game (editor run): the published version, never an update.
	var chess: Dictionary = catalog.get_game("chess")
	_check(catalog.version_text(chess) == "Version %d" % int(chess.version), "bundled game shows its version: " + catalog.version_text(chess))
	_check(not catalog.has_update("chess"), "bundled game has no update")
	_check(catalog.version_text({"title": "Soon"}) == "", "coming-soon placeholder has no version line")

	# A downloaded game whose published pack is newer.
	var fake := {"id": FAKE, "title": "Test Update", "icon": "🎮", "scene": "res://nope.tscn", "version": 5}
	catalog._games_by_id[FAKE] = fake
	var f := FileAccess.open(catalog._pack_path(FAKE), FileAccess.WRITE)
	f.store_string("GDPC fake")
	f.close()
	catalog._set_local_version(FAKE, 3)

	_check(catalog.has_update(FAKE), "older copy has an update")
	_check(catalog.updates_available().has(FAKE), "listed in updates_available")
	_check(catalog.version_text(fake).begins_with("Version 3 · update to version 5"), "version line names both: " + catalog.version_text(fake))
	catalog._mounted[FAKE] = true
	_check(not catalog.updates_available().has(FAKE), "a mounted pack waits for a restart")
	_check(catalog.updates_available(true).has(FAKE), "...but counts with include_mounted")
	_check(catalog.version_text(fake).contains("restart"), "mounted: says restart: " + catalog.version_text(fake))
	catalog._mounted.erase(FAKE)
	catalog._set_local_version(FAKE, 5)
	_check(not catalog.has_update(FAKE), "same version: no update")
	_check(catalog.version_text(fake) == "Version 5", "up to date: plain version")
	catalog._set_local_version(FAKE, 3)

	# The detail under the title in the Game Browser.
	var hub = load("res://scenes/hub/hub.tscn").instantiate()
	root.add_child(hub)
	for i in 5:
		await process_frame
	var nx = hub.netflix
	nx.select("chess")
	await process_frame
	_check(nx.detail._version.visible and nx.detail._version.text == "Version %d" % int(chess.version), "detail shows the version under the title")
	var kids: Array = nx.detail.get_children()
	_check(kids.find(nx.detail._version) == 1, "version line sits right under the title row")
	hub.queue_free()
	await process_frame

	# Options > Game updates: the list and the button.
	var opts = load("res://scenes/hub/options.tscn").instantiate() if ResourceLoader.exists("res://scenes/hub/options.tscn") else null
	_check(opts != null, "options scene exists")
	if opts:
		root.add_child(opts)
		await process_frame
		_check(opts.games_update_btn != null, "Game updates section is built")
		opts._on_game_updates_checked(true)
		_check(opts._game_updates.has(FAKE), "check lists the fake game")
		_check(opts.games_update_label.text.contains("v3 → v5"), "label shows old → new: " + opts.games_update_label.text)
		_check(opts.games_update_btn.text.begins_with("Update "), "button offers the update: " + opts.games_update_btn.text)
		opts.queue_free()
		await process_frame

	# Clean up.
	DirAccess.remove_absolute(catalog._pack_path(FAKE))
	catalog._set_local_version(FAKE, 0)
	catalog._games_by_id.erase(FAKE)
	_check(not FileAccess.file_exists(catalog._pack_path(FAKE)), "fake pack removed")

	TranslationServer.set_locale(locale)
	print("test_game_updates: %s" % ("OK" if fails == 0 else "%d FAIL(S)" % fails))
	quit(1 if fails > 0 else 0)
