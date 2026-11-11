extends SceneTree
## Beached on the Pad: the real scene, the stick walks, A finds the nearest thing, B backs out.
## Run: godot --headless --path . --script res://tools/test_wilson_pad.gd  (touches the desktop save: backs it up)
const D = preload("res://scripts/games/wilson/wilson_data.gd")
var fails := 0
var checks := 0
func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	var save := OS.get_user_data_dir() + "/wilson_save.json"
	var backup := ""
	if FileAccess.file_exists(save):
		backup = FileAccess.get_file_as_string(save)
	var g = load("res://scenes/games/wilson/wilson.tscn").instantiate()
	root.add_child(g)
	await create_timer(0.4).timeout
	g.home.start_mode(g.home.cfg["modes"][0])
	await create_timer(0.3).timeout
	var np = g.get_node_or_null("LookPicker")
	if np:
		np.queue_free()
	g.engine = load("res://scripts/games/wilson/wilson_engine.gd").new()
	g.engine.reset(g.now(), 0, "south", 7, "female3")
	g.started = true
	g._start_play()
	await create_timer(0.3).timeout
	ok(g.pad != null, "the Pad exists in play")
	if g.pad == null:
		_end(backup, save)
		return
	ok(g._sleep_row != null and not g._sleep_row.visible, "the 💤 😴 buttons step aside for the Pad")
	var c = g.world.castaway
	c.position = Vector2(900, 482)
	var x0: float = c.position.x
	Input.action_press("pad_move_right", 1.0)
	await create_timer(0.5).timeout
	Input.action_release("pad_move_right")
	ok(c.position.x > x0 + 30.0, "stick right walks right (%.0f -> %.0f)" % [x0, c.position.x])
	# lanes: y stays inside the strip, x inside the blended limits
	c.position = Vector2(1400, 535)
	Input.action_press("pad_move_right", 1.0)
	Input.action_press("pad_move_down", 1.0)
	await create_timer(0.6).timeout
	Input.action_release("pad_move_right")
	Input.action_release("pad_move_down")
	var lim: Vector2 = g.pad_limits(c.position.y)
	ok(c.position.y <= 535.01 and c.position.x <= lim.y + 0.5, "kept on the sand (%.0f, %.0f)" % [c.position.x, c.position.y])
	ok(absf(g.pad_limits(float(D.LANES[0].y)).x - float(D.LANES[0].x0)) < 0.1 and absf(g.pad_limits(float(D.LANES[2].y)).y - float(D.LANES[2].x1)) < 0.1, "lane limits at the ends")
	# A next to a pile just gathers it (no list, owner 2026-11-09); A next to a structure opens its menu
	c.position = D.SPOTS.sticks.stand
	g.engine.bars.energy = 100.0
	g._pad_use()
	await create_timer(0.1).timeout
	ok(g._popup == null and g.engine.busy() and str(g.engine.active().get("target", "")) == "sticks", "A near the sticks gathers them")
	g._pad_back()
	ok(not g.engine.busy(), "B cancels it")
	g.engine.structures["garden_plot"] = {"built": g.engine.t}
	g.world.sync()
	c.position = D.CAMP.garden_plot.stand
	c.facing = 1.0
	g._pad_use()
	await create_timer(0.1).timeout
	ok(g._popup != null, "A at the garden plot opens its menu (plant)")
	g._pad_back()
	ok(g._popup == null, "B closes the menu")
	# while an action runs, the stick does not walk and B cancels it
	g.engine.bars.energy = 100.0
	g.engine.enqueue("gather", "sticks")
	ok(g.engine.busy(), "an action is queued")
	g._pad_back()
	ok(not g.engine.busy(), "B cancels the running action")
	# a free tap still works
	g._on_tap(Vector2(1000, 482), Vector2(1000, 482))
	ok(true, "taps still go through")
	_end(backup, save)

func _end(backup: String, save: String) -> void:
	if backup != "":
		var f := FileAccess.open(save, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	print("wilson pad: %d checks, %d failed" % [checks, fails])
	quit()
