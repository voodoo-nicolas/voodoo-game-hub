extends SceneTree

## Headless checks for the on-screen controls (layout logic only, no real touches):
##   godot --headless --path . --script res://tools/test_last_shift_touch.gd

const TC = preload("res://scripts/games/last_shift/last_shift_touch_controls.gd")
const LsInput = preload("res://scripts/games/last_shift/last_shift_input.gd")

var fails := 0

func check(label: String, got, want) -> void:
	if got != want:
		fails += 1
		print("FAIL ", label, ": got ", got, " want ", want)

func _init() -> void:
	LsInput.ensure_actions()
	var c := TC.new()
	root.add_child(c)
	c.size = Vector2(1280, 720)
	# weapon wheel: segments clockwise from the top
	var wc: Vector2 = c._wheel_center()
	check("wheel top", c._wheel_segment(wc + Vector2(0, -100)), "fist")
	# v0.5: six segments of 60 degrees, the first one centered on top
	check("wheel top right", c._wheel_segment(wc + Vector2(87, -50)), "knife")
	check("wheel right", c._wheel_segment(wc + Vector2(100, 0)), "arm")
	check("wheel bottom", c._wheel_segment(wc + Vector2(0, 100)), "wrench")
	check("wheel bottom left", c._wheel_segment(wc + Vector2(-87, 50)), "pistol")
	check("wheel left", c._wheel_segment(wc + Vector2(-100, 0)), "coolant")
	check("wheel middle closes", c._wheel_segment(wc), "")
	check("far away closes", c._wheel_segment(wc + Vector2(400, 0)), "")
	c.wheel_open = true
	check("A is not pressed through the open wheel", c._role_at(c._a_center()), "wheel:")
	c.wheel_open = false
	check("A button", c._role_at(c._a_center()), "a")
	check("B button", c._role_at(c._b_center()), "b")
	check("bag button right of pause", c._role_at(c._bag_rect().get_center()), "bag")
	check("pause button", c._role_at(c._pause_rect().get_center()), "pause")
	check("wheel button hidden with one weapon", c._role_at(c._swap_center()), "")
	c.show_swap = true
	check("wheel button shown", c._role_at(c._swap_center()), "swap")
	c.tap_regions = {"log": Rect2(1000, 10, 260, 40)}
	check("mission log tap", c._role_at(Vector2(1100, 30)), "region:log")
	# A press -> action, release -> no action
	c._on_press(3, c._a_center(), true)
	check("A presses ls_action_a", Input.is_action_pressed("ls_action_a"), true)
	c._on_press(3, c._a_center(), false)
	check("A released", Input.is_action_pressed("ls_action_a"), false)
	# D-pad: a thumb near the diagonal keeps the current direction (no flicker)
	var dc: Vector2 = c._dpad_center()
	c._on_press(5, dc + Vector2(80, 10), true)
	check("d-pad right", c._dpad_dir, Vector2.RIGHT)
	c._on_move(5, dc + Vector2(60, 66))      # just past 45 degrees: still right
	check("d-pad keeps right near the diagonal", c._dpad_dir, Vector2.RIGHT)
	c._on_move(5, dc + Vector2(30, 80))      # clearly down now
	check("d-pad switches when clearly down", c._dpad_dir, Vector2.DOWN)
	c._on_press(5, dc, false)
	check("d-pad released", c._dpad_dir, Vector2.ZERO)
	print("touch tests: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
