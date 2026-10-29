extends SceneTree

## Headless checks for Last Shift's controls on the shared Pad (stick + A + B + wheel button + bag + map + pause):
##   godot --headless --path . --script res://tools/test_last_shift_pad.gd
## The older test (test_last_shift_touch.gd) runs before _ready, so it covers the fallback (no Pad).

const TC = preload("res://scripts/games/last_shift/last_shift_touch_controls.gd")
const LsInput = preload("res://scripts/games/last_shift/last_shift_input.gd")

var fails := 0

func check(label: String, got, want) -> void:
	if got != want:
		fails += 1
		print("FAIL ", label, ": got ", got, " want ", want)

func ok(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("FAIL ", label)

func _initialize() -> void:
	_run()

func _part(pad: Control, id: String) -> Dictionary:
	for el in pad.parts():
		if el["id"] == id and el["kind"] != "plate":
			return el
	return {}

func _at(el: Dictionary) -> Vector2:
	return el["rect"].get_center() if el["kind"] == "pill" else el["pos"]

func _run() -> void:
	LsInput.ensure_actions()
	for i in 2:
		await process_frame
	var c := TC.new()
	root.add_child(c)
	await process_frame
	await process_frame
	var pad: Control = c._pad
	ok("the Pad is used", pad != null)
	check("stick + 4 buttons", pad.layout_id(), "stick_4")
	var got: Array = []
	c.pause_pressed.connect(func(): got.append("pause"))
	c.bag_pressed.connect(func(): got.append("bag"))
	c.map_pressed.connect(func(): got.append("map"))
	c.wheel_pressed.connect(func(): got.append("wheel"))
	# the stick walks Nash (ls_move_* actions)
	var st := _part(pad, "move")
	pad._press(1, st["pos"], true)
	pad._move(1, st["pos"] + Vector2(0, st["r"]))
	ok("down on the stick = ls_move_down", Input.get_vector("ls_move_left", "ls_move_right", "ls_move_up", "ls_move_down").y > 0.9)
	pad._press(1, Vector2.ZERO, false)
	check("let go = still", Input.get_vector("ls_move_left", "ls_move_right", "ls_move_up", "ls_move_down"), Vector2.ZERO)
	# A and B press the keyboard's actions
	pad._press(2, _at(_part(pad, "a")), true)
	check("A = ls_action_a", Input.is_action_pressed("ls_action_a"), true)
	pad._press(2, Vector2.ZERO, false)
	check("A released", Input.is_action_pressed("ls_action_a"), false)
	pad._press(3, _at(_part(pad, "b")), true)
	check("B = ls_action_b", Input.is_action_pressed("ls_action_b"), true)
	pad._press(3, Vector2.ZERO, false)
	# pause, bag, map
	pad._press(4, _at(_part(pad, "pause")), true)
	pad._press(4, Vector2.ZERO, false)
	pad._press(5, _at(_part(pad, "y")), true)
	pad._press(5, Vector2.ZERO, false)
	pad._press(6, _at(_part(pad, "info")), true)
	pad._press(6, Vector2.ZERO, false)
	check("pause, bag, map signals", got, ["pause", "bag", "map"])
	# the weapon-wheel button only exists with two weapons
	c._process(0.016)
	check("wheel button hidden with one weapon", pad.visibility_of("x"), 0.0)
	check("a tap there does nothing", pad._press(7, _at(_part(pad, "x")), true), false)
	c.show_swap = true
	c._process(0.016)
	check("wheel button shown with two", pad.visibility_of("x"), 1.0)
	pad._press(7, _at(_part(pad, "x")), true)
	pad._press(7, Vector2.ZERO, false)
	check("wheel signal", got.back(), "wheel")
	# the words and the search ring on A, the weapon on B
	c.a_label = "SEARCH"
	c.a_active = true
	c.a_progress = 0.5
	c.b_icon = "pistol"
	c.b_count = "6"
	c._process(0.016)
	check("A says what it does", pad._props["a"]["sub"], "SEARCH")
	check("search ring", pad._props["a"]["fill"], 0.5)
	check("B shows the bullets", pad._props["b"]["sub"], "6")
	# world tap areas still work, outside the Pad's parts
	c.tap_regions = {"log": Rect2(1000, 10, 200, 40)}
	var regions: Array = []
	c.region_tapped.connect(func(n): regions.append(n))
	c._on_press(8, Vector2(1100, 30), true)
	c._on_press(8, Vector2.ZERO, false)
	check("mission log tap", regions, ["log"])
	# the open wheel takes every tap and the Pad steps aside
	c.wheel_open = true
	c._process(0.016)
	check("Pad hidden while the wheel is open", pad.visible, false)
	var picked: Array = []
	c.weapon_chosen.connect(func(w): picked.append(w))
	var wc: Vector2 = c._wheel_center()
	c._on_press(9, wc + Vector2(0, -100), true)
	c._on_press(9, Vector2.ZERO, false)
	check("wheel pick", picked, ["fist"])
	c.wheel_open = false
	c._process(0.016)
	check("Pad back after the wheel", pad.visible, true)
	c.queue_free()
	await process_frame
	print("test_last_shift_pad: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
