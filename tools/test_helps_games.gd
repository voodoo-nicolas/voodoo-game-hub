extends SceneTree

## Drives each game's helps (STANDARDS §17): opens the game, starts its first
## single-player mode, calls every cfg "helps" action straight (the pool is
## not touched) and prints what it returned. Script errors show in the log.
## The player's top-level user:// files are copied first and put back after,
## so the run leaves their saves as they were.
##   godot --headless --path . --script res://tools/test_helps_games.gd -- chess hangman ...
## No ids: every game whose script has "helps".

var _saved: Dictionary = {}  # file name -> bytes

func _init() -> void:
	_snapshot()
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		for d in DirAccess.get_directories_at("res://scripts/games"):
			var f := "res://scripts/games/%s/%s_game.gd" % [d, d]
			if FileAccess.file_exists(f) and "\"helps\":" in FileAccess.get_file_as_string(f):
				ids.append(d)
	_run(ids)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run(ids: Array) -> void:
	var bad := 0
	for gid in ids:
		var path := "res://scenes/games/%s/%s.tscn" % [gid, gid]
		if not ResourceLoader.exists(path):
			print("%s: no scene" % gid)
			bad += 1
			continue
		var game: Node = load(path).instantiate()
		root.add_child(game)
		await _frames(4)
		if "info" in game and game.info and game.info.has_method("close"):
			game.info.close()
		var home = game.get("home")
		if home == null or not "cfg" in home:
			print("%s: no kit" % gid)
			bad += 1
			game.queue_free()
			await _frames(2)
			continue
		var helps: Array = home.cfg.get("helps", [])
		if helps.is_empty():
			print("%s: no helps" % gid)
			bad += 1
		var mode = null
		for m in home.cfg.get("modes", []):
			if not m.get("multi", false):
				mode = m
				break
		if mode == null and not home.cfg.get("modes", []).is_empty():
			mode = home.cfg.modes[0]
		if mode != null:
			home.start_mode(mode)
		else:
			home.hide_home()
		paused = false
		await _frames(30)
		var out: Array = []
		for h in helps:
			var a: Callable = h.get("action", Callable())
			out.append("%s=%s" % [h.get("text", "?"), str(a.call()) if a.is_valid() else "INVALID"])
			await _frames(10)
		print("%s: %s" % [gid, ", ".join(out)])
		paused = false
		game.queue_free()
		await _frames(4)
	_restore()
	print("helps games: %d checked, %d problem(s)" % [ids.size(), bad])
	quit(1 if bad else 0)

func _snapshot() -> void:
	for f in DirAccess.get_files_at("user://"):
		_saved[f] = FileAccess.get_file_as_bytes("user://" + f)

func _restore() -> void:
	for f in DirAccess.get_files_at("user://"):
		if not _saved.has(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	for f in _saved:
		var h := FileAccess.open("user://" + f, FileAccess.WRITE)
		if h:
			h.store_buffer(_saved[f])
