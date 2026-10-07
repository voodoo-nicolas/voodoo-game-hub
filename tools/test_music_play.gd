extends SceneTree

## Tests the Music autoload with downloaded tracks (music.gd + music_library.gd):
## the synth stands in until a download lands, then the real track takes
## over; rotation between tracks; a game set "off"; "Where it plays" on a
## screen change; pausing with the app. Same local server as
## tools/test_music_library.gd (its header), with a list holding two fast
## synthwave tracks:
##
##   godot --headless --path . --script res://tools/test_music_play.gd -- <folder>/list2.json
##
## Leaves user://music/ as it found it (removes the tracks and lists it adds).

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _wait(cond: Callable, ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < ms:
		await process_frame

func _screen(path: String) -> Node:
	var n := Node.new()
	n.scene_file_path = path
	root.add_child(n)
	current_scene = n
	return n

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var list = JSON.parse_string(FileAccess.get_file_as_string(args[0])) if not args.is_empty() else null
	var music = root.get_node_or_null("Music")
	if not list is Dictionary or music == null:
		print("FAIL need the Music autoload and the test list.json")
		quit(1)
		return
	var lib: Node = music.library
	lib.clear()
	check(lib != null and lib.enabled, "Music has its library")
	lib._apply(list)
	lib.base_url = "http://127.0.0.1:8899/"

	# A game asks for "techno": nothing on the phone -> synth + a download.
	var game := _screen("res://scenes/games/snake/snake.tscn")
	music.play("techno", game, 0, 0.1, "synthwave")
	check(music._dl == "" and music._key.begins_with("techno:"), "synth stands in first (%s)" % music._key)
	check(lib.is_downloading(), "a download started")
	await _wait(func(): return music._dl != "", 20000)
	check(music._dl.begins_with("synthwave-fast-"), "the real track took over when it landed (%s)" % music._dl)
	check(music._key.begins_with("techno:dl:"), "key %s" % music._key)
	await _wait(func(): return not lib.is_downloading() and lib._queue.is_empty(), 20000)
	var ready: Array = lib.ready_tracks("techno", ["synthwave"])
	check(ready.size() == 2, "the second synthwave track came too (%d ready)" % ready.size())
	var first: String = music._dl
	check(not music._players[0].stream.get("loop"), "with two on the phone the track doesn't loop")
	music._next_track(0.1)
	check(music._dl != first and music._dl != "", "the next one follows (%s -> %s)" % [first, music._dl])
	music.play("techno", game, 0, 0.1, "synthwave")
	var again: String = music._key
	music.play("techno", game, 0, 0.1, "synthwave")
	check(music._key == again, "asking for what is playing changes nothing")

	# The owner turned music off for this game.
	var simon := _screen("res://scenes/games/simon/simon.tscn")
	game.free()
	music.play("calm", simon, -1, 0.1)
	check(music._key == "", "a game set off gets no music")
	simon.free()

	# "Where it plays": the hub has calm, Arcade lively (+ snake lo-fi).
	var hub := _screen("res://scenes/hub/hub.tscn")
	music._on_scene_changed()
	check(music._auto and music._style == "calm" and music._owner_ref == null, "hub screens get calm by themselves")
	var key_hub: String = music._key
	var opts := _screen("res://scenes/hub/options.tscn")
	hub.free()
	music._on_scene_changed()
	check(music._key == key_hub, "the hub's music carries on to the next hub screen")
	var snake := _screen("res://scenes/games/snake/snake.tscn")
	opts.free()
	music._on_scene_changed()
	check(music._auto and music._style == "lively", "a category's style plays in its game (%s)" % music._style)
	music.play("techno", snake, 0, 0.1)
	var chess := _screen("res://scenes/games/chess/chess.tscn")
	music._on_scene_changed()
	check(music._style == "techno", "a game's own music isn't replaced while it plays")
	snake.free()
	music._on_scene_changed()
	check(music._key == "", "a game with no setting is quiet once the last one's music ends")
	chess.free()

	# The app goes to the background.
	music.play("techno", null, 0, 0.1)
	music.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(music._players.all(func(p): return p.stream_paused), "paused with the app")
	music.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(music._players.all(func(p): return not p.stream_paused), "resumed with the app")
	music.stop(0.05)

	lib.clear()
	for f in DirAccess.get_files_at("user://music/"):
		if f.ends_with(".json"):
			DirAccess.remove_absolute("user://music/" + f)
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
