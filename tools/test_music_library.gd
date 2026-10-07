extends SceneTree

## Tests scripts/common/music_library.gd (the downloaded half of Music):
## list checks, where-it-plays lookups, download + sha256 check, playing
## from the file, storage and clear. Needs the files from a local server:
##
##   python -m http.server 8899 --bind 127.0.0.1     (in a folder holding
##   list.json + the OGG files it names; see the music library notes in
##   CLAUDE.md)
##   godot --headless --path . --script res://tools/test_music_library.gd -- <folder>/list.json
##
## Uses user://music/ (the same user data the PC build plays with): it backs
## up what is there first and puts it back at the end.

const Library = preload("res://scripts/common/music_library.gd")
var fails := 0
var lib: Node
var ready_ids: Array = []

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var list = JSON.parse_string(FileAccess.get_file_as_string(args[0])) if not args.is_empty() else null
	if not list is Dictionary:
		print("FAIL need the test list.json as the argument")
		quit(1)
		return
	var backup := "user://music_test_backup/"
	if DirAccess.dir_exists_absolute("user://music/"):
		DirAccess.rename_absolute("user://music/", backup)

	lib = Library.new()
	root.add_child(lib)
	lib.track_ready.connect(func(id): ready_ids.append(id))
	check(lib.enabled, "enabled off the web")

	check(not lib._apply({"tracks": []}), "a list without base_url is refused")
	check(not lib._apply({"base_url": "http://x/", "tracks": []}), "a non-https base_url is refused")
	check(lib._apply(list), "the test list is adopted")
	check(lib.tracks.size() == 3, "3 tracks pass the checks (%d)" % lib.tracks.size())
	var bad: Dictionary = list.duplicate(true)
	bad.tracks.append({"id": "x", "pace": "fast", "file": "../evil.ogg", "size": 5, "sha256": "0".repeat(64)})
	bad.tracks.append({"id": "y", "pace": "medium", "file": "y.ogg", "size": 5, "sha256": "0".repeat(64)})
	lib._apply(bad)
	bad.tracks.append({"id": "z", "pace": "fast", "file": bad.tracks[0].file, "size": 5, "sha256": "0".repeat(64)})
	lib._apply(bad)
	check(lib.tracks.size() == 3, "unsafe or repeated file names and bad paces are dropped")
	lib.base_url = "http://127.0.0.1:8899/"  # the local stand-in for the release

	# where it plays
	var hub := Node.new()
	hub.scene_file_path = "res://scenes/hub/hub.tscn"
	var snake := Node.new()
	snake.scene_file_path = "res://scenes/games/snake/snake.tscn"
	var simon := Node.new()
	simon.scene_file_path = "res://scenes/games/simon/simon.tscn"
	var chess := Node.new()
	chess.scene_file_path = "res://scenes/games/chess/chess.tscn"
	check(lib.setting_for(hub) == {"style": "calm", "genres": []}, "hub screens: %s" % str(lib.setting_for(hub)))
	var s_snake: Dictionary = lib.setting_for(snake)
	check(s_snake.style == "lively" and s_snake.genres == ["lo-fi"], "a game's genres win, its category's style stays: %s" % str(s_snake))
	check(lib.setting_for(simon).style == "off", "a game set Off")
	check(lib.setting_for(chess) == {"style": "", "genres": []}, "a category with no entry: nothing")
	for n in [hub, snake, simon, chess]:
		n.free()

	# choosing
	check(lib.candidates("techno").size() == 2, "fast tracks for techno")
	check(lib.candidates("techno", ["synthwave"]).size() == 1, "genre filter")
	check(lib.candidates("techno", ["jazz"]).size() == 2, "a genre with no fast track falls back to every fast track")
	check(lib.candidates("calm").size() == 1 and lib.candidates("nope").is_empty(), "calm = slow; unknown style = none")
	check(lib.ready_tracks("techno").is_empty(), "nothing on the phone yet")

	# downloading
	var good: Dictionary = lib.candidates("techno", ["synthwave"])[0]
	var wrong: Dictionary = lib.candidates("techno", ["rock"])[0]
	lib.want(good)
	lib.want(good)  # asked twice: one download
	lib.want(wrong)
	var t0 := Time.get_ticks_msec()
	while (lib.is_downloading() or not lib._queue.is_empty()) and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	check(ready_ids == [good.id], "the good track downloaded once, the wrong-sha one refused: %s" % str(ready_ids))
	check(FileAccess.file_exists("user://music/" + good.file), "saved under user://music/")
	check(not FileAccess.file_exists("user://music/" + good.file + ".part"), "no .part left")
	check(lib._failed.has(wrong.id), "a failed track isn't retried this session")
	check(lib.ready_tracks("techno", ["synthwave"]).size() == 1, "now ready")
	var s: AudioStream = lib.stream_of(good)
	check(s is AudioStreamOggVorbis, "plays from the file (AudioStreamOggVorbis)")
	check(s != null and s.loop and absf(s.loop_offset - 2.5) < 0.01, "loops from loop_start")
	check(s != null and absf(s.get_length() - 40.0) < 0.5, "length %.1f s" % (s.get_length() if s else -1.0))
	check(lib.stream_of(good) == s, "loaded once")
	var st: Dictionary = lib.storage()
	check(st.count == 1 and st.bytes == int(good.size), "storage: %s" % str(st))
	check(lib.credits().size() == 3, "credits for every track")

	# a list without the track removes its file
	var fewer: Dictionary = list.duplicate(true)
	fewer.tracks = fewer.tracks.filter(func(t): return t.id != good.id)
	lib._apply(fewer)
	lib._forget_removed()
	check(not FileAccess.file_exists("user://music/" + good.file), "a track taken off the list is deleted")
	lib._apply(list)
	lib.base_url = "http://127.0.0.1:8899/"
	lib._failed.clear()
	lib._ok.clear()
	lib.want(good)
	t0 = Time.get_ticks_msec()
	while lib.is_downloading() and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	lib.clear()
	check(lib.storage().count == 0, "clear() empties it")

	# put the player's music folder back
	for f in DirAccess.get_files_at("user://music/"):
		DirAccess.remove_absolute("user://music/" + f)
	DirAccess.remove_absolute("user://music/")
	if DirAccess.dir_exists_absolute(backup):
		DirAccess.rename_absolute(backup, "user://music/")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
