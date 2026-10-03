extends SceneTree

## Presses every button a game's Home screen (home_kit.gd) offers, one game
## after another, and reports anything that fails. Headless is fine:
##
##   godot --headless --path . --script res://tools/crawl.gd -- [id ...]
##
## For each game: open each "More" card (How to Play, Leaderboard,
## Statistics, Sound) and close it; then for each way to play, a fresh copy
## of the scene: start it, let it run, open the pause menu, Continue, Restart
## if offered, pause again. Errors show up as Godot's usual SCRIPT ERROR lines;
## "CRAWL FAIL" lines are the crawler's own findings. Ends with a summary.
## It plays real games, so back up the user data first (CLAUDE.md).

var fails: Array = []

func _initialize() -> void:
	_run(OS.get_cmdline_user_args())

func _ids(args: Array) -> Array:
	if not args.is_empty():
		return args
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	var out: Array = []
	for cat in m.categories:
		for g in cat.games:
			if g.has("id"):
				out.append(g.id)
	return out

func _run(args: Array) -> void:
	for i in 3:
		await process_frame
	for id in _ids(args):
		var scene := "res://scenes/games/%s/%s.tscn" % [id, id]
		if not ResourceLoader.exists(scene):
			continue
		await _crawl(id, scene)
	print("CRAWL DONE: %d problem(s)" % fails.size())
	for f in fails:
		print("  - ", f)
	paused = false
	quit(1 if not fails.is_empty() else 0)

func _fail(id: String, what: String) -> void:
	fails.append("%s: %s" % [id, what])
	print("CRAWL FAIL ", id, ": ", what)

func _spawn(scene: String) -> Node:
	paused = false
	var inst: Node = load(scene).instantiate()
	root.add_child(inst)
	current_scene = inst
	for i in 8:
		await process_frame
	var gi := _find_script(inst, "game_info.gd")
	if gi and gi.get("overlay") and gi.overlay.visible:
		gi.close()
	return inst

func _despawn(inst: Node) -> void:
	paused = false
	if is_instance_valid(inst):
		root.remove_child(inst)
		inst.queue_free()
	for i in 3:
		await process_frame

func _crawl(id: String, scene: String) -> void:
	print("CRAWL ", id)
	var inst: Node = await _spawn(scene)
	var kit := _find_script(inst, "home_kit.gd")
	if kit == null:
		print("  (no home kit)")
		await _despawn(inst)
		return
	if not kit.is_home_visible():
		_fail(id, "Home not showing on open")
	# The More grid and its cards
	for label in ["❓", "🏆", "📊", "🔊"]:
		var b := _button_in(kit.home, label)
		if b == null:
			if label != "🔊":
				_fail(id, "no %s button" % label)
			continue
		print("  card ", b.text)
		b.pressed.emit()
		for i in 6:
			await process_frame
		var opened := false
		for o in kit.get_children():
			if o is ColorRect and o.visible and o != kit.pause_overlay:
				opened = true
				var close := _button_in(o, tr("Close"))
				if close:
					close.pressed.emit()
		if not opened:
			_fail(id, "%s opened nothing" % label)
		for i in 3:
			await process_frame
	var modes: Array = kit.cfg.get("modes", [])
	await _despawn(inst)
	# Each way to play, in a fresh copy (online needs a second phone: skipped)
	for m in modes:
		if str(m.get("text", "")).contains("Online"):
			continue
		inst = await _spawn(scene)
		kit = _find_script(inst, "home_kit.gd")
		var b := _button_in(kit.home, tr(str(m.text)).split("\n")[0])
		if b == null:
			_fail(id, "no button for mode %s" % m.text)
			await _despawn(inst)
			continue
		print("  play ", b.text.replace("
", " / "))
		b.pressed.emit()
		for i in 40:
			await process_frame
		if kit.is_home_visible():
			_fail(id, "mode %s left Home showing" % m.text)
		if paused and not kit.pause_overlay.visible:
			_fail(id, "mode %s left the game frozen" % m.text)
		kit.pause()
		for i in 4:
			await process_frame
		if not kit.pause_overlay.visible:
			_fail(id, "pause menu did not open after %s" % m.text)
		kit.resume_play()
		for i in 10:
			await process_frame
		if paused:
			_fail(id, "Continue left the game frozen")
		if kit.cfg.has("restart"):
			kit.pause()
			kit._on_restart()
			for i in 10:
				await process_frame
		await _despawn(inst)
	# Resume, if this left a save behind
	inst = await _spawn(scene)
	kit = _find_script(inst, "home_kit.gd")
	if kit.resume_btn.visible:
		print("  resume ", kit.resume_btn.text)
		kit.resume_btn.pressed.emit()
		for i in 20:
			await process_frame
		if kit.is_home_visible():
			_fail(id, "Resume left Home showing")
	await _despawn(inst)

func _button_in(n: Node, text: String) -> Button:
	if n is Button and n.is_visible_in_tree() and n.text.begins_with(text):
		return n
	for c in n.get_children():
		var r := _button_in(c, text)
		if r:
			return r
	return null

func _find_script(n: Node, file: String) -> Node:
	if n.get_script() and str(n.get_script().resource_path).ends_with(file):
		return n
	for c in n.get_children():
		var r := _find_script(c, file)
		if r:
			return r
	return null
