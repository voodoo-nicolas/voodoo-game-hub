extends SceneTree

## Checks the orb Landing (tools/templates/landing_styles.gd) of one game in the current window size:
## every orb inside the screen and big enough to touch, no two orbs overlapping, the particle budget,
## "Reduce effects" stopping the smoke and glitter. Needs a window (not --headless) so the size is real:
##
##   godot --path . --resolution 405x720 --script res://tools/test_landing_orbs.gd -- res://scenes/games/tarot/tarot.tscn
##
## It writes user://fx.json (the Reduce effects switch) and puts it back afterwards.

var failures := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <scene>")
		quit(2)
		return
	_run(args[0])

func _fail(msg: String) -> void:
	failures += 1
	print("FAIL: ", msg)

func _find(n: Node, cls: String, out: Array) -> void:
	if n.name == cls or n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		_find(c, cls, out)

func _run(scene: String) -> void:
	var fx_path := "user://fx.json"
	var saved := FileAccess.get_file_as_string(fx_path) if FileAccess.file_exists(fx_path) else ""
	# Effects on for this run, whatever the device would choose by itself.
	var fw := FileAccess.open(fx_path, FileAccess.WRITE)
	fw.store_string(JSON.stringify({"reduce": false}))
	fw.close()
	for i in 3:
		await process_frame
	change_scene_to_file(scene)
	for i in 120:
		await process_frame
	var found: Array = []
	_find(root, "StyleLanding", found)
	if found.is_empty():
		_fail("no styled Landing in the scene")
		quit(1)
		return
	var land: Control = found[0]
	var view := land.size
	var kit: Control = land.kit
	var is_list: bool = str(kit.cfg.get("landing", "")) == "list"
	# 1. every shown action: inside the screen, big enough to touch, not overlapping another
	var shown: Array = land.entries.filter(func(e): return e.shown)
	print("style ", kit.cfg.get("landing", ""), ": ", shown.size(), " actions shown of ", land.entries.size(), " in ", view)
	var rects: Array = []
	for e in shown:
		var ctl: Control = e.row if is_list else e.slot
		var r := Rect2(ctl.position, ctl.size)
		rects.append([str(e.nm), r])
		if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > view.x + 0.5 or r.end.y > view.y + 0.5:
			_fail("%s outside the screen: %s" % [e.nm, r])
		if (r.size.y if is_list else r.size.x) < (37.0 if is_list else 55.0):
			_fail("%s too small: %s" % [e.nm, r.size])
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i][1]
			var b: Rect2 = rects[j][1]
			if is_list:
				if a.grow(-1.0).intersects(b.grow(-1.0)):
					_fail("rows overlap: %s / %s" % [rects[i][0], rects[j][0]])
			else:
				var dist := a.get_center().distance_to(b.get_center())
				if dist < (a.size.x + b.size.x) * 0.5 - 1.0:
					_fail("orbs overlap: %s / %s" % [rects[i][0], rects[j][0]])
	# 2. the title column does not run into an action
	var info: Control = land.info_col
	var info_r := Rect2(info.position, info.size)
	for r in rects:
		var rr: Rect2 = r[1]
		if info_r.intersects(rr.grow(-rr.size.y * 0.15)):
			_fail("title column %s overlaps %s" % [info_r, r[0]])
	# 3. particles: budget and the Reduce effects switch
	var parts: Array = []
	_find(land, "CPUParticles2D", parts)
	var total := 0
	for p in parts:
		total += int(p.amount)
	print("particles: ", total, " in ", parts.size(), " emitters")
	if total > 40:
		_fail("particle budget %d > 40" % total)
	land._on_fx_pick(1)
	for p in parts:
		if p.emitting:
			_fail("still emitting after Reduced")
	land._on_fx_pick(0)
	await process_frame
	var emitting := 0
	var all: Array = []
	_find(land, "CPUParticles2D", all)
	for p in all:
		if p.emitting:
			emitting += 1
	var fx: Script = load(kit.get_script().resource_path.get_base_dir().path_join("fx_lib.gd"))
	if all.size() > 0 and emitting == 0 and not fx.reduced():
		_fail("nothing emits after Full")
	# back to how it was
	if saved == "":
		if FileAccess.file_exists(fx_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fx_path))
	else:
		var f := FileAccess.open(fx_path, FileAccess.WRITE)
		f.store_string(saved)
	print("landing orbs test: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(0 if failures == 0 else 1)
