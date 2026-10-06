extends SceneTree

## Phase 3 media tiers, end to end, headless:
##   godot --headless --path . --script res://tools/test_media.gd
## Needs builds/media/media-common.v<N>.pck and builds/packs/solitaire.pck
## (python tools/hub.py export-media media-common; export solitaire). Serves
## builds/ from a local python http.server, points the Catalog at it and
## checks: requirements parsing, the download chain (media first, sha256,
## versioned file name, mount), the Music tiers, ref counts, Storage
## deletes (deferred while mounted) and launch-time cleanup.
## Writes user://packs/ -- on the main PC back up user data first
## (CLAUDE.md "Tests and the PC build share ...").

const PORT := 8765
var failures := 0
var _server_pid := -1

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog = root.get_node("Catalog")
	var music = root.get_node("Music")
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	var media: Dictionary = m.media_packs["media-common"]
	var media_file := "media-common.v%d.pck" % int(media.version)
	var builds := ProjectSettings.globalize_path("res://builds")
	if not FileAccess.file_exists(builds + "/media/" + media_file) or not FileAccess.file_exists(builds + "/packs/solitaire.pck"):
		print("build media-common and solitaire first (see header)")
		quit(1)
		return
	for py in ["python3", "python"]:
		_server_pid = OS.create_process(py, ["-m", "http.server", str(PORT), "--bind", "127.0.0.1", "--directory", builds])
		if _server_pid > 0:
			break
	await create_timer(1.5).timeout
	# The repo's manifest -- not the cached or live copy, which the Catalog
	# may have adopted meanwhile (the live one has no media_packs yet).
	while catalog._fetch_in_flight:
		await process_frame
	check(catalog._apply_manifest(m), "repo manifest accepted")

	# A clean slate, as on a phone: nothing downloaded, nothing bundled.
	_wipe("user://packs/media")
	DirAccess.remove_absolute("user://packs/solitaire.pck")
	catalog._set_local_version("solitaire", 0)
	catalog._media_bundled.clear()
	catalog._bundled.erase("solitaire")

	# --- parsing
	var reqs: Array = catalog._parse_requirements(["media-common>=2", "media-cat-cards", " x >= 3"])
	check(reqs.size() == 3 and reqs[0].min == 2 and reqs[1].min == 1 and reqs[2].name == "x" and reqs[2].min == 3,
			"requires_media parsing")
	check(catalog.media_root("media-common") == "res://media/common/" and catalog.media_root("media-cat-cards") == "res://media/cat/cards/",
			"media roots")

	# --- point the catalog at the local server
	var base := "http://127.0.0.1:%d/" % PORT
	catalog.media_packs["media-common"].url = base + "media/" + media_file
	catalog._games_by_id["solitaire"].url = base + "packs/solitaire.pck"
	check(catalog.missing_media("solitaire") == ["media-common"], "solitaire misses media-common")
	check(catalog.needs_download("solitaire"), "so it needs a download")

	# --- a damaged media pack (wrong sha256) is refused and removed
	var good_sha: String = catalog.media_packs["media-common"].sha256
	catalog.media_packs["media-common"].sha256 = "0".repeat(64)
	var errs: Array = []
	catalog.download("solitaire", func(e): errs.append(e))
	while errs.is_empty():
		await process_frame
	check(errs[0] != "" and catalog.local_media_version("media-common") == 0, "bad sha256 -> error, nothing kept")
	check(not catalog.is_downloading("solitaire"), "chain ended")
	catalog.media_packs["media-common"].sha256 = good_sha

	# --- the real chain: media first, then the game
	errs.clear()
	var progress: Array = []
	catalog.download("solitaire", func(e): errs.append(e))
	while errs.is_empty():
		progress.append(catalog.download_progress("solitaire"))
		await process_frame
	check(errs[0] == "", "download chain succeeded (%s)" % errs[0])
	check(FileAccess.file_exists("user://packs/media/" + media_file), "media saved as " + media_file)
	check(catalog.local_media_version("media-common") == int(media.version), "local media version")
	check(catalog._media_mounted.has("media-common"), "media mounted at once")
	check(catalog.is_downloaded("solitaire") and not catalog.needs_download("solitaire"), "game downloaded, nothing more needed")
	var monotonic := true
	for i in range(1, progress.size()):
		if progress[i] >= 0.0 and progress[i] + 0.0001 < progress[i - 1]:
			monotonic = false
	check(monotonic, "progress never goes backwards (%d samples)" % progress.size())
	check(catalog.download("solitaire", func(_e): pass) == null, "a second download has nothing to do")

	# --- Music finds the track in the common tier, crossfades, ducks, stops
	check(music.find_track("menu", "solitaire", "cards") == "res://media/common/music/menu.ogg", "menu track found in media-common")
	check(music.play_track("menu", "solitaire", "cards"), "play_track")
	check(music.is_playing(), "music playing")
	check(music.play_track("menu", "solitaire", "cards") and music.current == "res://media/common/music/menu.ogg", "same track again is a no-op")
	check(not music.play_track("no_such_track"), "missing track -> false")
	music.duck(0.5)
	for i in 10:
		await process_frame
	check(music._duck > 0.0, "ducking dips the music")
	music.stop(0.1)
	await create_timer(0.4).timeout
	check(not music.is_playing(), "stop fades out")
	check(AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("UI") != -1 and AudioServer.get_bus_index("SFX") != -1,
			"Music / SFX / UI buses exist")

	# --- ref counts + Storage
	check(catalog.media_users("media-common") == ["solitaire"], "media-common used by solitaire")
	var items: Array = catalog.storage_items()
	var kinds := items.map(func(it): return "%s:%s" % [it.kind, it.id])
	check("game:solitaire" in kinds and "media:media-common" in kinds, "storage lists the game and the media")
	check(catalog.delete_pack("media", "media-common") != "", "media in use can't be deleted")
	catalog._mounted["solitaire"] = true  # as if played this session
	check(catalog.delete_pack("game", "solitaire") == "later", "mounted game: deleted on next launch")
	check(not catalog.storage_items().map(func(it): return it.id).has("solitaire"), "pending delete hidden from Storage")
	catalog._mounted.erase("solitaire")
	check(catalog.media_users("media-common").is_empty(), "no users left once the game is gone")
	check(catalog.delete_pack("media", "media-common") == "later", "mounted media: deleted on next launch")

	# --- next launch: pending deletes run, superseded versions go
	catalog._run_pending_deletes()
	check(not FileAccess.file_exists("user://packs/solitaire.pck"), "game file removed at launch")
	check(not FileAccess.file_exists("user://packs/media/" + media_file), "media file removed at launch")
	_copy(builds + "/media/" + media_file, "user://packs/media/media-common.v1.pck")
	_copy(builds + "/media/" + media_file, "user://packs/media/media-common.v3.pck")
	catalog._media_mounted.clear()
	catalog._mount_local_media()
	check(not FileAccess.file_exists("user://packs/media/media-common.v1.pck"), "older version deleted at launch")
	check(catalog.local_media_version("media-common") == 3, "newest version kept")
	_wipe("user://packs/media")

	OS.kill(_server_pid)
	print("FAILURES: %d" % failures)
	quit(1 if failures else 0)

func _wipe(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))

func _copy(from: String, to: String) -> void:
	DirAccess.copy_absolute(from, to)
