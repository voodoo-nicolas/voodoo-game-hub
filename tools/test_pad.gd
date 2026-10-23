extends SceneTree

## Headless checks for the shared on-screen controller (no real touches; presses are simulated):
##   godot --headless --path . --script res://tools/test_pad.gd
## Covers every layout (parts exist, stay inside the screen, don't overlap), sticks (analog strength,
## dead zone, floating origin), the D-pad (4 / 8 way), buttons, multi-finger, left-handed mirror,
## opacity 0, game action maps, release_all and the prefs round trip. Writes no saves.

const Pad = preload("res://scripts/common/pad/pad_controller.gd")
const Layouts = preload("res://scripts/common/pad/pad_layouts.gd")
const Prefs = preload("res://scripts/common/pad/pad_prefs.gd")

var fails := 0
const SIZE := Vector2(1280, 720)

func check(label: String, got, want) -> void:
	if got != want:
		fails += 1
		print("FAIL ", label, ": got ", got, " want ", want)

func ok(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("FAIL ", label)

func _make(layout: String, tweak: Dictionary = {}) -> Control:
	var p: Dictionary = Prefs.DEFAULTS.duplicate()
	p["layout"] = layout
	for k in tweak:
		p[k] = tweak[k]
	var c: Control = Pad.new()
	c.prefs = p
	root.add_child(c)
	c.size = SIZE
	c._replace()
	return c

func _part(c: Control, id: String) -> Dictionary:
	for el in c.parts():
		if el["id"] == id and el["kind"] != "plate":
			return el
	return {}

## What a game like Turned needs: reveal, pause, narrow screens, a default layout, button words.
func _game_features() -> void:
	var had_prefs := FileAccess.file_exists(Prefs.PATH)
	var saved_prefs := FileAccess.get_file_as_string(Prefs.PATH) if had_prefs else ""
	# reveal: a hidden part is invisible and untouchable until it pops in
	var c := _make("dpad_4")
	c.set_hidden("a", true)
	check("hidden: not visible", c.visibility_of("a"), 0.0)
	check("hidden: not touchable", c._press(1, _part(c, "a")["pos"], true), false)
	c.reveal("a")
	check("revealing starts at zero", c.visibility_of("a"), 0.0)
	c._process(0.2)
	ok("half way in is touchable", c.visibility_of("a") > 0.5 and c._press(2, _part(c, "a")["pos"], true))
	c._press(2, Vector2.ZERO, false)
	c._process(0.5)
	check("fully in", c.visibility_of("a"), 1.0)
	c.reveal("b")   # b was never hidden: nothing happens
	check("reveal of a shown part is a no-op", c.visibility_of("b"), 1.0)
	c.set_hidden("x", true)
	c.set_hidden("y", true)
	var plate_ok := true
	for el in c.parts():
		if el["kind"] == "plate":
			plate_ok = el["ids"].has("a")
	ok("plate follows its buttons", plate_ok)
	c.set_hidden("b", true)
	c.set_hidden("a", false)
	var lone := true
	for el in c.parts():
		if el["kind"] == "plate":
			var vis: Array = []
			for bid in el["ids"]:
				vis.append(c.visibility_of(str(bid)))
			vis.sort()
			lone = vis[vis.size() - 2] == 0.0
	ok("a lone button has no plate", lone)
	c.set_hidden("b", false)
	# words under buttons, ring, icon
	c.set_state("a", {"sub": "USE", "enabled": false})
	c.set_state("b", {"ring": true})
	c.set_state("info", {"icon": "menu"})
	check("sub kept", c._props["a"]["sub"], "USE")
	check("state merges", c._props["a"]["enabled"], false)
	# lit from a mapped action (a keyboard key lights the button too)
	if not InputMap.has_action("tn_a2"):
		InputMap.add_action("tn_a2")
	c.set_map({"a": ["tn_a2"]})
	Input.action_press("tn_a2")
	check("lit by its mapped action", c._lit("a"), true)
	Input.action_release("tn_a2")
	c.queue_free()
	# pausing the game lets go of everything
	c = _make("stick_4")
	var st := _part(c, "move")
	c._press(1, st["pos"], true)
	c._move(1, st["pos"] + Vector2(st["r"], 0))
	ok("held before the pause", c.get_vector("move").x > 0.9)
	paused = true
	await process_frame
	check("pause releases the stick", c.get_vector("move"), Vector2.ZERO)
	check("pause releases the finger", c.finger_count(), 0)
	paused = false
	c.queue_free()
	# a narrow (portrait / tablet) screen shrinks the pad instead of blowing it up
	for lid in Layouts.ids():
		var c2: Control = Pad.new()
		var p2: Dictionary = Prefs.DEFAULTS.duplicate()
		p2["layout"] = lid
		c2.prefs = p2
		root.add_child(c2)
		c2.size = Vector2(720, 1280)
		c2._replace()
		for el in c2.parts():
			if el["kind"] == "plate":
				continue
			var r: float = el["r"] if el.has("r") else maxf(Rect2(el["rect"]).size.x, Rect2(el["rect"]).size.y) * 0.5
			var p: Vector2 = el["pos"]
			ok("%s %s inside a 720x1280 screen" % [lid, el["id"]], p.x - r >= 0.0 and p.y - r >= 0.0 and p.x + r <= 720.0 and p.y + r <= 1280.0)
		c2.queue_free()
	# a game's default layout holds until the player picks one
	if FileAccess.file_exists(Prefs.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.PATH))
	var g: Control = Pad.new()
	g.default_layout = "dpad_2"
	root.add_child(g)
	g.size = SIZE
	check("default layout used", g.layout_id(), "dpad_2")
	g.set_pref("opacity", 0.5)
	ok("changing opacity does not lock the layout", not Prefs.has_saved("layout"))
	var g2: Control = Pad.new()
	g2.default_layout = "dpad_2"
	root.add_child(g2)
	g2.size = SIZE
	check("still the default after a reload", g2.layout_id(), "dpad_2")
	check("opacity was saved", float(g2.prefs["opacity"]), 0.5)
	g2.set_pref("layout", "stick_1")
	var g3: Control = Pad.new()
	g3.default_layout = "dpad_2"
	root.add_child(g3)
	g3.size = SIZE
	check("the player's pick wins", g3.layout_id(), "stick_1")
	for n in [g, g2, g3]:
		n.queue_free()
	if had_prefs:
		var f := FileAccess.open(Prefs.PATH, FileAccess.WRITE)
		f.store_string(saved_prefs)
	elif FileAccess.file_exists(Prefs.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.PATH))

## The Landing kit's Options shows "Controls" only for a game that defines _pad().
func _kit_hook() -> void:
	var Kit = load("res://scripts/games/tictactoe/home_kit.gd")
	var had_prefs := FileAccess.file_exists(Prefs.PATH)
	var saved_prefs := FileAccess.get_file_as_string(Prefs.PATH) if had_prefs else ""
	var pad := _make("stick_4")
	var with_pad := _FakeGame.new()
	with_pad.the_pad = pad
	var without := _FakeGameNoPad.new()
	var counts := {}
	for pair in [["with", with_pad], ["without", without]]:
		var game: Control = pair[1]
		root.add_child(game)
		var kit = Kit.new({"accent": Kit.CYAN, "modes": []})
		game.add_child(kit)
		await process_frame
		kit._show_options()
		await process_frame
		counts[pair[0]] = _count_class(game, "pad_options.gd")
		check("%s: kit found the pad" % pair[0], kit._game_pad() != null, pair[0] == "with")
		if pair[0] == "with":
			var opts: Node = _find_script(game, "pad_options.gd")
			ok("options panel targets the game's pad", opts != null and opts.target == pad)
			# a change in the panel reaches the live controller and the saved prefs
			opts.prefs["layout"] = "dpad_2"
			opts._commit()
			check("panel change reaches the pad", pad.layout_id(), "dpad_2")
	check("Controls section shown for a game with _pad()", counts["with"], 1)
	check("no Controls section without _pad()", counts["without"], 0)
	# leave the player's real prefs as they were
	if had_prefs:
		var f := FileAccess.open(Prefs.PATH, FileAccess.WRITE)
		f.store_string(saved_prefs)
	elif FileAccess.file_exists(Prefs.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.PATH))

class _FakeGame extends Control:
	var the_pad: Control = null
	func _pad() -> Control:
		return the_pad

class _FakeGameNoPad extends Control:
	pass

func _count_class(node: Node, file: String) -> int:
	var n := 1 if (node.get_script() != null and str(node.get_script().resource_path).ends_with(file)) else 0
	for c in node.get_children():
		n += _count_class(c, file)
	return n

func _find_script(node: Node, file: String) -> Node:
	if node.get_script() != null and str(node.get_script().resource_path).ends_with(file):
		return node
	for c in node.get_children():
		var f := _find_script(c, file)
		if f != null:
			return f
	return null

func _init() -> void:
	_run()

func _run() -> void:
	Pad.ensure_actions()
	# --- every layout: parts inside the screen, no two touchable parts overlapping
	for lid in Layouts.ids():
		for size_scale in [0.6, 1.0, 1.4]:
			var c := _make(lid, {"size": size_scale})
			var els: Array = []
			for el in c.parts():
				if el["kind"] != "plate":
					els.append(el)
			ok(lid + " has parts", els.size() > 0)
			for el in els:
				var r: float = el["r"] if el.has("r") else maxf(Rect2(el["rect"]).size.x, Rect2(el["rect"]).size.y) * 0.5
				var p: Vector2 = el["pos"]
				ok("%s %s inside the screen at %.1f" % [lid, el["id"], size_scale], p.x - r >= 0.0 and p.y - r >= 0.0 and p.x + r <= SIZE.x and p.y + r <= SIZE.y)
			for i in els.size():
				for j in range(i + 1, els.size()):
					var a: Dictionary = els[i]
					var b: Dictionary = els[j]
					var ra: float = a["r"] if a.has("r") else Rect2(a["rect"]).size.y * 0.5
					var rb: float = b["r"] if b.has("r") else Rect2(b["rect"]).size.y * 0.5
					ok("%s: %s and %s do not overlap at %.1f" % [lid, a["id"], b["id"], size_scale], a["pos"].distance_to(b["pos"]) >= (ra + rb) * 0.9)
			c.queue_free()
	# --- stick: analog strength, dead zone, release
	var c := _make("stick_4")
	var st := _part(c, "move")
	c._press(1, st["pos"], true)
	check("finger on stick", c.finger_count(), 1)
	c._move(1, st["pos"] + Vector2(st["r"], 0))
	var v: Vector2 = c.get_vector("move")
	ok("full right", v.x > 0.99 and absf(v.y) < 0.01)
	c._move(1, st["pos"] + Vector2(st["r"] * 0.575, 0))   # halfway between dead zone (.15) and the rim -> ~0.5
	v = c.get_vector("move")
	ok("half push is about half strength (%.2f)" % v.x, v.x > 0.4 and v.x < 0.6)
	c._move(1, st["pos"] + Vector2(st["r"] * 0.1, 0))
	check("inside the dead zone is zero", c.get_vector("move"), Vector2.ZERO)
	c._move(1, st["pos"] + Vector2(0, -st["r"] * 3.0))
	ok("pushed far beyond the rim is clamped", c.get_vector("move").length() <= 1.001 and c.get_vector("move").y < -0.99)
	c._press(1, Vector2.ZERO, false)
	check("released", c.get_vector("move"), Vector2.ZERO)
	check("no fingers left", c.finger_count(), 0)
	# --- buttons + multi finger (stick and A together)
	var a_btn := _part(c, "a")
	c._press(1, st["pos"], true)
	c._move(1, st["pos"] + Vector2(st["r"], 0))
	c._press(2, a_btn["pos"], true)
	ok("stick and A at once", c.get_vector("move").x > 0.9 and c.is_down("a"))
	check("two fingers", c.finger_count(), 2)
	c._press(2, a_btn["pos"], false)
	check("A released", c.is_down("a"), false)
	ok("stick still held", c.get_vector("move").x > 0.9)
	c._press(1, Vector2.ZERO, false)
	# a second finger can't re-press a held button
	c._press(3, a_btn["pos"], true)
	c._press(4, a_btn["pos"], true)
	check("one finger per button", c.finger_count(), 1)
	c._press(3, a_btn["pos"], false)
	check("the other finger does not hold it", c.is_down("a"), false)
	c._press(4, a_btn["pos"], false)
	# --- pause pill + signals
	var got: Array = []
	c.button_pressed.connect(func(id): got.append(id))
	var pause := _part(c, "pause")
	c._press(5, pause["rect"].get_center(), true)
	c._press(5, Vector2.ZERO, false)
	check("pause signal", got, ["pause"])
	# --- a press that misses everything is ignored
	check("miss", c._press(6, Vector2(640, 20), true), false)
	check("miss leaves no finger", c.finger_count(), 0)
	c.queue_free()
	# --- game action map
	c = _make("stick_4")
	c.set_map({"move": ["tn_left", "tn_right", "tn_up", "tn_down"], "a": ["tn_a"]})
	for n in ["tn_left", "tn_right", "tn_up", "tn_down", "tn_a"]:
		if not InputMap.has_action(n):
			InputMap.add_action(n)
	st = _part(c, "move")
	c._press(1, st["pos"], true)
	c._move(1, st["pos"] + Vector2(-st["r"], 0))
	ok("mapped left pressed", Input.is_action_pressed("tn_left") and not Input.is_action_pressed("tn_right"))
	c._press(2, _part(c, "a")["pos"], true)
	check("mapped A", Input.is_action_pressed("tn_a"), true)
	c.release_all()
	check("release_all frees the stick", Input.is_action_pressed("tn_left") or Input.is_action_pressed("pad_move_left"), false)
	check("release_all frees A", Input.is_action_pressed("tn_a") or Input.is_action_pressed("pad_a"), false)
	check("release_all frees fingers", c.finger_count(), 0)
	c.queue_free()
	# --- D-pad: 8 way, then 4 way with hysteresis
	c = _make("dpad_4", {"dpad8": true})
	var dp := _part(c, "move")
	c._press(1, dp["pos"], true)
	c._move(1, dp["pos"] + Vector2(dp["r"] * 0.5, -dp["r"] * 0.5))
	check("8-way diagonal", Vector2(c._vec["move"]), Vector2(1, -1))
	check("8-way: both arrows pressed", Input.is_action_pressed("pad_move_right") and Input.is_action_pressed("pad_move_up"), true)
	c._move(1, dp["pos"] + Vector2(dp["r"] * 0.6, 0))
	check("8-way straight right", Vector2(c._vec["move"]), Vector2(1, 0))
	c._press(1, Vector2.ZERO, false)
	c.queue_free()
	c = _make("dpad_4", {"dpad8": false})
	dp = _part(c, "move")
	c._press(1, dp["pos"], true)
	c._move(1, dp["pos"] + Vector2(dp["r"] * 0.6, dp["r"] * 0.2))
	check("4-way right", Vector2(c._vec["move"]), Vector2(1, 0))
	c._move(1, dp["pos"] + Vector2(dp["r"] * 0.5, dp["r"] * 0.55))   # near the diagonal: keeps right
	check("4-way keeps the axis near the diagonal", Vector2(c._vec["move"]), Vector2(1, 0))
	c._move(1, dp["pos"] + Vector2(dp["r"] * 0.2, dp["r"] * 0.7))
	check("4-way switches when clearly down", Vector2(c._vec["move"]), Vector2(0, 1))
	c._move(1, dp["pos"] + Vector2(2.0, 2.0))
	check("D-pad centre is nothing", Vector2(c._vec["move"]), Vector2.ZERO)
	c._press(1, Vector2.ZERO, false)
	c.queue_free()
	# --- floating stick: the ring appears under the thumb, in its half of the screen
	c = _make("stick_4", {"floating": true})
	var spot := Vector2(300, 400)
	c._press(1, spot, true)
	check("floating origin is the touch", Vector2(c._origin["move"]), spot)
	c._move(1, spot + Vector2(80, 0))
	ok("floating push right", c.get_vector("move").x > 0.3)
	c._press(1, Vector2.ZERO, false)
	check("floating: a touch on the right half is not the stick", c._press(2, Vector2(900, 300), true), false)
	c.queue_free()
	# --- twin stick: aim fires, left-handed mirrors
	c = _make("dual_stick")
	var aim := _part(c, "aim")
	c._press(1, aim["pos"], true)
	c._move(1, aim["pos"] + Vector2(0, -aim["r"]))
	check("aim fires when pushed", Input.is_action_pressed("pad_fire"), true)
	ok("aim up", c.get_vector("aim").y < -0.9)
	c._move(1, aim["pos"] + Vector2(aim["r"] * 0.1, 0))
	check("aim stops firing near centre", Input.is_action_pressed("pad_fire"), false)
	c._press(1, Vector2.ZERO, false)
	c.queue_free()
	var right_h := _make("stick_4", {"right_handed": true})
	var left_h := _make("stick_4", {"right_handed": false})
	ok("right-handed: stick on the left", _part(right_h, "move")["pos"].x < SIZE.x * 0.5)
	ok("left-handed: stick on the right", _part(left_h, "move")["pos"].x > SIZE.x * 0.5)
	ok("left-handed: A on the left", _part(left_h, "a")["pos"].x < SIZE.x * 0.5)
	right_h.queue_free()
	left_h.queue_free()
	# --- opacity 0 still works
	c = _make("stick_4", {"opacity": 0.0})
	c._press(1, _part(c, "a")["pos"], true)
	check("opacity 0 still presses", c.is_down("a"), true)
	c._press(1, Vector2.ZERO, false)
	c.queue_free()
	# --- hidden parts do not react
	c = _make("stick_4")
	c.set_hidden("a", true)
	check("hidden A ignores touch", c._press(1, _part(c, "a")["pos"], true), false)
	c.set_hidden("a", false)
	check("shown again", c._press(1, _part(c, "a")["pos"], true), true)
	c._press(1, Vector2.ZERO, false)
	c.queue_free()
	# --- prefs round trip + clamping
	var p: Dictionary = Prefs.DEFAULTS.duplicate()
	p["size"] = 5.0
	p["opacity"] = -2.0
	var cl := Prefs.clean(p)
	check("size clamped", cl["size"], 1.4)
	check("opacity clamped", cl["opacity"], 0.0)
	# --- catalogue
	check("layout step wraps forward", Layouts.step(Layouts.ids()[Layouts.ids().size() - 1], 1), Layouts.ids()[0])
	check("layout step wraps back", Layouts.step(Layouts.ids()[0], -1), Layouts.ids()[Layouts.ids().size() - 1])
	check("unknown layout falls back", Layouts.get_layout("nope")["id"], Layouts.LAYOUTS[0]["id"])
	await _game_features()
	await _kit_hook()
	print("test_pad: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
