extends SceneTree

## Presses every button a game's Landing page (home_kit.gd, the Landing kit)
## offers, one game after another, and reports anything that fails.
## Headless is fine:
##
##   godot --headless --path . --script res://tools/crawl.gd -- [id ...]
##
## For each game: the Landing shows, has "← Hub", and the floating drawer is
## gone; each More card (How to Play, Leaderboard, Statistics, Achievements,
## Options) opens with a 🏠 Home corner button that closes it; each setup
## screen opens and its ▶ Start starts a game; then for each way to play, a
## fresh copy of the scene: start it, let it run, open the pause menu (no Hub
## button there; Options from it reads ‹ Back), Resume, Restart if offered.
## Errors show up as Godot's usual SCRIPT ERROR lines; "CRAWL FAIL" lines are
## the crawler's own findings. Ends with a summary.
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
		if cat.get("archived", false):
			continue
		for g in cat.games:
			if g.has("id") and not g.get("archived", false):
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

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## The kit's open cards, newest last.
func _open_cards(kit: Node) -> Array:
	return kit._open_overlays()

func _crawl(id: String, scene: String) -> void:
	print("CRAWL ", id)
	var inst: Node = await _spawn(scene)
	var kit := _find_script(inst, "home_kit.gd")
	if kit == null:
		print("  (no landing kit)")
		await _despawn(inst)
		return
	if not kit.is_home_visible():
		_fail(id, "Landing not showing on open")
	if _button_in(kit.home, tr("← Hub")) == null:
		_fail(id, "no ← Hub on the Landing")
	if _find_script(inst, "settings_drawer.gd") != null:
		_fail(id, "the floating drawer is still there")
	# The More grid and its cards
	for label in ["❓", "🏆", "📊", "🏅", "⚙"]:
		var b := _button_in(kit.home, label)
		if b == null:
			if label in ["❓", "📊", "⚙"]:
				_fail(id, "no %s button" % label)
			continue
		print("  card ", b.text)
		b.pressed.emit()
		await _frames(6)
		var cards := _open_cards(kit)
		if cards.is_empty():
			_fail(id, "%s opened nothing" % label)
		else:
			var nav: Button = cards[-1].get_meta("nav")
			if not nav.text.begins_with(tr("🏠 Home")):
				_fail(id, "%s card says %s, not 🏠 Home" % [label, nav.text])
			nav.pressed.emit()
		await _frames(4)
		if not _open_cards(kit).is_empty():
			_fail(id, "%s card didn't close" % label)
	# Setup screens: open, ▶ Start
	for multi in [false, true]:
		var group: Array = kit._multi if multi else kit._solo
		if group.size() < 2 and not kit.cfg.has("extra"):
			continue
		if group.is_empty():
			continue
		if multi and str(group[0].get("text", "")).contains("Online") and group.size() == 1:
			continue
		inst = await _respawn(inst, scene)
		kit = _find_script(inst, "home_kit.gd")
		kit._open_setup(multi)
		await _frames(6)
		var cards := _open_cards(kit)
		var start: Button = _button_in(cards[-1], "▶  " + tr("Start")) if not cards.is_empty() else null
		if start == null:
			_fail(id, "%s setup has no ▶ Start" % ("multiplayer" if multi else "single player"))
			continue
		print("  setup ", "multi" if multi else "solo", " (", group.size(), " ways)")
		# Online picked by default would need a second phone: pick another.
		var pick: Dictionary = {}
		for m in group:
			if not str(m.get("text", "")).contains("Online") and not str(m.get("text", "")).contains("Invite"):
				pick = m
				break
		if pick.is_empty():
			continue
		kit.start_mode(pick)
		await _frames(30)
		if kit.is_home_visible():
			_fail(id, "setup Start left the Landing showing")
	var modes: Array = kit._solo + kit._multi
	await _despawn(inst)
	# Each way to play, in a fresh copy (online needs a second phone: skipped)
	for m in modes:
		var t := str(m.get("text", ""))
		if t.contains("Online") or t.contains("Invite"):
			continue
		inst = await _spawn(scene)
		kit = _find_script(inst, "home_kit.gd")
		print("  play ", t)
		kit.start_mode(m)
		await _frames(40)
		if kit.is_home_visible():
			_fail(id, "mode %s left the Landing showing" % t)
		if paused and not kit.pause_overlay.visible:
			_fail(id, "mode %s left the game frozen" % t)
		kit.pause()
		await _frames(4)
		if not kit.pause_overlay.visible:
			_fail(id, "pause menu did not open after %s" % t)
		if _button_in(kit.pause_overlay, tr("Back to Hub")) != null or _button_in(kit.pause_overlay, tr("← Hub")) != null:
			_fail(id, "pause menu links to the hub")
		kit._show_options()
		await _frames(4)
		var cards := _open_cards(kit)
		if cards.is_empty() or not cards[-1].get_meta("nav").text.contains(tr("Back")):
			_fail(id, "Options from the pause menu has no ‹ Back")
		elif not cards.is_empty():
			cards[-1].get_meta("nav").pressed.emit()
		await _frames(3)
		kit.resume_play()
		await _frames(10)
		if paused:
			_fail(id, "Resume left the game frozen")
		if kit.cfg.has("restart"):
			kit.pause()
			kit._on_restart()
			await _frames(10)
		await _despawn(inst)
	# Resume, if this left a save behind
	inst = await _spawn(scene)
	kit = _find_script(inst, "home_kit.gd")
	if kit.resume_btn.visible:
		print("  resume ", kit.resume_btn.text)
		kit.resume_btn.pressed.emit()
		await _frames(20)
		if kit.is_home_visible():
			_fail(id, "Resume left the Landing showing")
	await _despawn(inst)

func _respawn(inst: Node, scene: String) -> Node:
	await _despawn(inst)
	return await _spawn(scene)

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
