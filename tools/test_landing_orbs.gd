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
	_find(root, "OrbLanding", found)
	if found.is_empty():
		_fail("no OrbLanding in the scene")
		quit(1)
		return
	var land: Control = found[0]
	var view := land.size
	var kit: Control = land.kit
	# 1. orbs: inside the screen, touchable, not overlapping
	var shown: Array = land.orbs.filter(func(o): return o.slot.visible)
	print("orbs shown: ", shown.size(), " of ", land.orbs.size(), " in ", view)
	for o in shown:
		var r := Rect2(o.slot.position, o.slot.size)
		if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > view.x + 0.5 or r.end.y > view.y + 0.5:
			_fail("%s outside the screen: %s" % [o.btn.text, r])
		if r.size.x < 55.0:
			_fail("%s too small: %s" % [o.btn.text, r.size.x])
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			var a: Control = shown[i].slot
			var b: Control = shown[j].slot
			var dist := (a.position + a.size * 0.5).distance_to(b.position + b.size * 0.5)
			if dist < (a.size.x + b.size.x) * 0.5 - 1.0:
				_fail("orbs overlap: %s / %s" % [shown[i].btn.text, shown[j].btn.text])
	# 2. the title column does not run into an orb
	var info: Control = land.info_col
	var info_r := Rect2(info.position, info.size)
	for o in shown:
		var slot_r := Rect2(o.slot.position, o.slot.size)
		if info_r.intersects(slot_r.grow(-slot_r.size.x * 0.15)):
			_fail("title column %s overlaps %s" % [info_r, o.btn.text])
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
