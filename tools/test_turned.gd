extends SceneTree

## Headless test for Turned: tuning keys, the two maps, the engine's sun/death rules, and a
## scripted playthrough of the slice (wake, mirror, clues, scarf, door, street, sun, shade,
## death and respawn, the alley's B, autosave and resume), driving the world with press_a(),
## press_b(), test_dir and by calling _process().
##   godot --headless --path . --script res://tools/test_turned.gd
## Writes user://turned_save.json (a real save there is backed up and put back).

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Area = preload("res://scripts/games/turned/turned_area.gd")
const EngineScript = preload("res://scripts/games/turned/turned_engine.gd")
const SunClock = preload("res://scripts/games/turned/turned_sun_clock.gd")
const Save = preload("res://scripts/games/turned/turned_save.gd")
const Text = preload("res://scripts/games/turned/turned_text.gd")
const WorldScript = preload("res://scripts/games/turned/turned_world.gd")
const HudScript = preload("res://scripts/games/turned/turned_hud.gd")

const DT := 1.0 / 60.0

var fails := 0
var checks := 0
var world: Node2D
var hud: Control

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _initialize() -> void:
	_run()

func _run() -> void:
	for i in 3:
		await process_frame
	var save_abs := ProjectSettings.globalize_path(Save.PATH)
	var backup := ""
	if FileAccess.file_exists(Save.PATH):
		backup = FileAccess.get_file_as_string(Save.PATH)
	Save.clear()
	_test_tuning_keys()
	_test_areas()
	_test_engine()
	await _test_flow()
	Save.clear()
	if backup != "":
		var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	print("turned: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------- helpers

func _step(seconds: float) -> void:
	var n := int(seconds / DT)
	for i in n:
		world._process(DT)
		hud._process(DT)

func _walk_to(target: Vector2, limit_s: float = 30.0) -> bool:
	var t := 0.0
	while t < limit_s:
		var d: Vector2 = target - world.player.position
		if d.length() < 4.0:
			world.test_dir = Vector2.ZERO
			return true
		world.test_dir = d.normalized()
		_step(DT * 3.0)
		t += DT * 3.0
	world.test_dir = Vector2.ZERO
	return false

func _new_world() -> void:
	if world != null:
		world.discard = true
		world.queue_free()
		hud.queue_free()
	hud = HudScript.new()
	root.add_child(hud)
	world = WorldScript.new()
	root.add_child(world)
	world.attach_hud(hud)
	world.set_view_size(Vector2(1280, 720))

# ---------------------------------------------------------------- tuning

func _test_tuning_keys() -> void:
	var rx := RegEx.new()
	rx.compile("T\\.(?:f|b|v|arr|color|m)\\(\"([a-z_.]+)\"")
	var rx_ui := RegEx.new()
	rx_ui.compile("_ui\\(\"([a-z_]+)\"")
	var seen := {}
	var dir := DirAccess.open("res://scripts/games/turned")
	for file in dir.get_files():
		if not file.ends_with(".gd") or file.ends_with("_i18n.gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/games/turned/" + file)
		for m in rx.search_all(src):
			if not m.get_string(1).ends_with("."):   # a prefix joined with a variable (turned_hud.gd _ui)
				seen[m.get_string(1)] = file
		for m in rx_ui.search_all(src):
			seen["ui." + m.get_string(1)] = file
	check(seen.size() > 40, "found the tuning keys the code uses (%d)" % seen.size())
	for k in seen:
		var found: Variant = T.v(k)
		check(found != null, "tuning.json has %s (used in %s)" % [k, seen[k]])

func _touch(idx: int, p: Vector2, down: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = p
	e.pressed = down
	return e

func _drag(idx: int, p: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = p
	return e

# ---------------------------------------------------------------- the maps

func _test_areas() -> void:
	var house: Area = Area.make("house") as Area
	var down: Area = Area.make("house_down") as Area
	check(house.indoor and house.in_shade(Vector2(100, 100)), "the house is all shade")
	check(down.indoor and down.in_shade(Vector2(100, 100)), "the ground floor is all shade")
	for pair in [[house, "upstairs"], [down, "ground floor"]]:
		var ar: Area = pair[0]
		for k in ar.spawns:
			check(ar.is_free(ar.spawns[k], 9.0) or k == "bed", "%s spawn %s is free" % [pair[1], k])
		for it in ar.interacts:
			check(ar.bounds.has_point(it["pos"]) and ar.is_free(it["pos"], 9.0), "%s interact %s is a free spot inside" % [pair[1], it["id"]])
	# upstairs: bedroom -> landing -> bathroom, study and the stairs must be connected by walking
	check(_reachable(house, house.spawns["bedside"], Vector2(444, 62)), "bedside -> mirror reachable")
	check(_reachable(house, house.spawns["bedside"], house.spawns["from_down"]), "bedside -> stairs reachable")
	for it in house.interacts:
		check(_reachable(house, house.spawns["bedside"], it["pos"]), "upstairs interact %s reachable" % it["id"])
	# ground floor: from the stairs to every room and to the front door
	for it in down.interacts:
		check(_reachable(down, down.spawns["from_up"], it["pos"]), "ground floor interact %s reachable" % it["id"])
	check(_reachable(down, down.spawns["from_up"], down.spawns["from_street"]), "stairs -> front door reachable")
	check(_reachable(down, down.spawns["from_street"], Vector2(80, 350)), "front door -> scarf reachable")
	var ids := {}
	for ar in [house, down]:
		for it in ar.interacts:
			if ar == house or it["id"] != "clock":
				check(not ids.has(it["id"]) or it["id"] in ["clock", "table"], "interact id %s is unique" % it["id"])
			ids[it["id"]] = true
		for it in ar.interacts:
			var vid: String = it["verb"]
			check(Text.VERBS.has(vid), "verb %s has a label" % vid)
	for iid in ["wardrobe", "portrait", "toilet", "cabinet", "washstand", "bath", "desk", "bookshelf", "globe", "clock", "fireplace", "piano", "parlour_books", "stove", "table", "pantry", "shelves"]:
		check(Text.LOOKS.has(iid), "look line for %s" % iid)

	var st: Area = Area.make("street") as Area
	check(not st.indoor, "the street is outdoors")
	check(st.in_shade(st.spawns["from_house"]) and st.is_free(st.spawns["from_house"], 9.0), "leaving the house you stand in the porch shade")
	check(not st.in_shade(Vector2(300, 260)), "the road is in the sun")
	check(st.in_shade(Vector2(1785, 0)), "the alley is shade")
	check(st.in_shade(Vector2(980, 345)) and st.in_shade(Vector2(500, 170)), "tree and awning give shade")
	check(st.npcs.size() >= 5 and st.npcs.size() <= 6, "5-6 villagers (%d)" % st.npcs.size())
	var knowing := 0
	for n in st.npcs:
		var p := Vector2(float(n["pos"][0]), float(n["pos"][1]))
		check(st.is_free(p, 9.0), "npc %s stands on free ground" % n["id"])
		if int(n["knows_player"]) == 2:
			knowing += 1
		if n["behavior"] == "walk":
			var a := Vector2(float(n["path"][0][0]), float(n["path"][0][1]))
			var b := Vector2(float(n["path"][1][0]), float(n["path"][1][1]))
			var ok := true
			for i in 41:
				if not st.is_free(a.lerp(b, float(i) / 40.0), 9.0):
					ok = false
			check(ok, "npc %s path is clear" % n["id"])
	check(knowing == 1, "exactly one Knowing villager (the Watcher)")
	for it in st.interacts:
		check(st.bounds.has_point(it["pos"]), "street interact %s inside the map" % it["id"])
	check(_reachable(st, st.spawns["from_house"], Vector2(1785, 100)), "porch -> alley reachable")
	check(_reachable(st, st.spawns["from_house"], Vector2(1785, -250)), "porch -> end of the alley reachable")
	# how far from any walkable street point to shade? (the owner wants to know)
	var worst := 0.0
	var worst_at := Vector2.ZERO
	var x := 20.0
	while x < 1900.0:
		var y := 160.0
		while y < 385.0:
			var p := Vector2(x, y)
			if st.is_free(p, 9.0):
				var s: Variant = st.nearest_shade(p, T.m(T.f("death.fallback_shade_radius_m")), 9.0, 8.0)
				if s == null:
					check(false, "shade within the fallback radius of %s" % str(p))
				else:
					var d := p.distance_to(s)
					if d > worst:
						worst = d
						worst_at = p
			y += 25.0
		x += 25.0
	print("turned: farthest street point from shade: %.0f px (%.1f m) at %s" % [worst, worst / T.f("world.pixels_per_meter"), str(worst_at)])
	check(worst < T.m(T.f("death.fallback_shade_radius_m")), "every street point has shade nearby")
	# respawn: a point in the open road
	var spot: Variant = st.nearest_shade(Vector2(300, 260), T.m(3.0), 9.0, 8.0)
	check(spot == null or (st.in_shade(spot) and st.is_free(spot, 9.0)), "nearest_shade returns shade")

## Can a circle walk from a to b? Simple grid flood fill.
func _reachable(a: Area, from: Vector2, to: Vector2) -> bool:
	var step := 6.0
	var start := Vector2i((from / step).round())
	var goal := Vector2i((to / step).round())
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		if c.distance_to(goal) <= 5.0:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			seen[n] = true
			if a.is_free(Vector2(n) * step, 9.0):
				q.append(n)
	return false

# ---------------------------------------------------------------- the engine

func _test_engine() -> void:
	var e: EngineScript = EngineScript.new()
	check(is_equal_approx(e.hp, T.f("stats.max_hp")), "starts at full Health")
	check(is_equal_approx(e.sun_dps(), 1.0), "Day 1 sun is 1 HP/s")
	e.tick_health(2.0, true, 1.0)
	check(is_equal_approx(e.hp, T.f("stats.max_hp") - 2.0), "2 s in the sun costs 2 HP")
	e.tick_health(T.f("sun.regen_delay_s") + 0.01, false, 1.0)
	var hp_before := e.hp
	e.tick_health(2.0, false, 1.0)
	check(e.hp > hp_before, "Health regenerates in shade after the delay")
	e.tick_health(5.0, true, 0.0)
	check(e.hp >= hp_before, "no damage when the sun is down")
	e.day = 2
	check(is_equal_approx(e.sun_dps(), 4.0), "Day 2 sun is 4 HP/s")
	e.day = 3
	check(is_equal_approx(e.sun_dps(), 10.0), "Day 3 sun is 10 HP/s")
	e.day = 1
	e.hp = 0.5
	var died := e.tick_health(1.0, true, 1.0)
	check(died and e.hp == 0.0, "Health 0 reports death")
	e.blood = 80.0
	e.apply_death()
	check(is_equal_approx(e.hp, T.f("stats.max_hp") * 0.5), "death gives back half the Health")
	check(is_equal_approx(e.blood, 60.0), "death costs a quarter of the Blood (80 -> 60)")
	check(e.deaths == 1, "deaths counted")
	check(not e.toggle_sneak() and not e.sneaking, "B does nothing until it is unlocked")
	e.unlock_button("b")
	check(e.toggle_sneak() and e.speed() < T.f("player.walk_speed"), "Sneak is slower")
	check(e.detect_radius_px() < T.m(T.f("sneak.detect_radius_m")), "Sneak shrinks the detection radius")
	var back: EngineScript = EngineScript.new()
	back.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	check(back.buttons == e.buttons and back.deaths == 1 and back.sneaking, "state survives a JSON round trip")
	var c: SunClock = SunClock.new()
	check(is_equal_approx(c.intensity(), 1.0), "the clock starts at full sun")

# ---------------------------------------------------------------- the playthrough

func _test_flow() -> void:
	_new_world()
	await process_frame
	world.begin_new()
	check(world.mode == "prologue" and not hud.is_revealed("dpad"), "the game starts in the prologue, no d-pad")
	check(not hud.is_revealed("a") and not hud.is_revealed("bars") and not hud.is_revealed("mission"), "nothing is shown yet")
	world.press_a()
	_step(1.0)
	check(world._pro == "black" or world._pro == "fade_in", "A does nothing during the black screen")
	_step(T.f("prologue.black_s") + T.f("prologue.fade_in_s") + T.f("prologue.thirsty_s") + 0.5)
	check(world._pro == "wait_sit" and hud.is_revealed("a"), "waiting for A to sit up")
	check(not hud.is_revealed("dpad") and not hud.is_revealed("b"), "only A is shown")
	world.test_dir = Vector2.RIGHT
	_step(1.0)
	check(world.player.position.distance_to(world.area.spawns["bed"]) < 1.0, "the arrows do nothing yet")
	world.test_dir = Vector2.ZERO
	world.press_a()
	_step(T.f("prologue.sit_s") + T.f("prologue.sit_gap_s") + 0.5)
	check(world._pro == "wait_wipe" and world.player.sit_t >= 1.0, "sat up, waiting to wipe the face")
	world.press_a()
	_step(T.f("prologue.wipe_s") + 0.2)
	check(world._pro == "felt", "the hand reached the neck")
	_step(0.3)
	check(hud.throb > 0.0, "the screen throbs when the holes are felt")
	check(hud.caption_text() == "What is this?", "the inner line 'What is this?'")
	_step(T.f("prologue.felt_s") + T.f("prologue.unlock_gap_s") + 0.5)
	check(world.mode == "play" and world.engine.dpad, "the d-pad unlocks")
	_step(1.0)
	check(hud.is_revealed("dpad"), "the d-pad is shown")
	check(not hud.is_revealed("bars") and not hud.is_revealed("mission"), "still no bars or Missions")

	# the touch overlay: 8-way d-pad, A, and a locked B that does not react
	var dc: Vector2 = hud._dpad_center()
	hud._input(_touch(0, dc + Vector2(0, 80), true))
	check(Input.is_action_pressed("tn_down") and not Input.is_action_pressed("tn_left") and not Input.is_action_pressed("tn_right"), "thumb below the centre presses Down only")
	hud._input(_drag(0, dc + Vector2(80, 80)))
	check(Input.is_action_pressed("tn_down") and Input.is_action_pressed("tn_right"), "thumb in a corner presses two arrows (diagonal)")
	hud._input(_touch(0, dc + Vector2(80, 80), false))
	check(not Input.is_action_pressed("tn_down") and not Input.is_action_pressed("tn_right"), "releasing frees the arrows")
	hud._input(_touch(1, dc + Vector2(90, 0), true))
	hud._input(_touch(2, dc + Vector2(0, -90), true))
	check(Input.is_action_pressed("tn_right") and Input.is_action_pressed("tn_up"), "two fingers on two arrows walk diagonally")
	hud._input(_touch(1, dc, false))
	hud._input(_touch(2, dc, false))
	check(not Input.is_action_pressed("tn_right") and not Input.is_action_pressed("tn_up"), "both fingers up")
	var a_taps := [0]
	hud.a_pressed.connect(func(): a_taps[0] += 1)
	hud._input(_touch(3, hud._button_center("a"), true))
	hud._input(_touch(3, hud._button_center("a"), false))
	check(a_taps[0] == 1, "tapping A is one press")
	hud._input(_touch(4, hud._button_center("b"), true))
	hud._input(_touch(4, hud._button_center("b"), false))
	check(not world.engine.sneaking, "the locked B does not react")
	var big: float = T.f("ui.button_radius") * 2.0
	check(big >= 69.0 and T.f("ui.dpad_radius") >= 69.0 and hud._pause_rect().size.y >= 60.0, "touch targets are at least 48 dp (about 69 canvas units)")

	# the front door (on the ground floor) says no before the mirror
	world._load_area("house_down")
	world.player.position = Vector2(30, 360)
	_step(0.1)
	world.press_a()
	_step(0.2)
	check(world.mode == "play" and world.area.id == "house_down", "the door stays shut before the mirror")
	world._load_area("house")
	world.player.position = world.area.spawns["bedside"]

	# walk to a clue with the d-pad: bedside -> invitation
	world.player.position = world.area.spawns["bedside"]
	check(_walk_to(Vector2(111, 66)), "walked to the nightstand")
	_step(0.1)
	check(str(world._cand.get("id", "")) == "invitation", "A offers the invitation")
	check(world.player.hobble, "before the mirror the player hobbles")
	world.press_a()
	check(world.engine.journal.has("invitation") and hud.is_revealed("menu"), "the clue is in the Journal and the Menu appears")
	world.player.position = Vector2(241, 76)
	_step(0.1)
	world.press_a()
	world.player.position = Vector2(70, 196)
	_step(0.1)
	world.press_a()
	check(world.engine.journal.size() == 3, "three clues found (%s)" % str(world.engine.journal))
	world.press_a()
	check(world.engine.journal.size() == 3, "a clue is only added once")

	# the mirror
	check(_walk_to(Vector2(135, 250)) and _walk_to(Vector2(135, 340)) and _walk_to(Vector2(430, 345)) and _walk_to(Vector2(430, 280)) and _walk_to(Vector2(444, 64)), "walked bedroom -> hall -> bathroom mirror")
	_step(0.1)
	check(str(world._cand.get("id", "")) == "mirror", "A offers the mirror")
	world.press_a()
	check(world.mode == "closeup", "the neck close-up opens")
	_step(1.7)
	check(hud.closeup >= 1.0, "close-up fully shown")
	check(hud.caption_text() == "What is going on?", "'What is going on?'")
	world.press_a()
	_step(0.8)
	check(world.mode == "play" and world.engine.mission == "find_out" and hud.is_revealed("mission"), "the Missions box shows 'Find out what happened'")

	# after the mirror: no more limp, the thoughts play, then A checks the pockets, then the coat
	check(not world.player.hobble, "after the mirror the limp is gone")
	check(not world.engine.has_flag("pockets"), "the pockets are not offered before the thoughts")
	_step(10.0)
	check(world.engine.has_flag("thought"), "the thoughts after the mirror have played")
	world.engine.journal.erase("coat")        # pretend the coat has not been found yet
	world.player.position = Vector2(430, 280)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "pockets" and world.hud.a_label == "pockets", "A offers 'Check pockets'")
	world.press_a()
	check(world.engine.has_flag("pockets") and world.engine.journal.has("pockets") and world.engine.mission == "find_coat", "empty pockets: the mission is to find the coat")
	check(hud.caption_text() == Text.INNER["pockets_empty"], "'Where is my coat?'")
	_step(0.1)
	check(str(world._cand.get("id", "")) != "pockets", "the pockets are checked once")
	world.player.position = Vector2(241, 76)
	_step(0.1)
	world.press_a()
	check(world.engine.journal.has("coat") and world.engine.mission == "find_out", "the stranger's coat: back to finding out what happened")
	_step(4.2)
	check(hud.caption_text() == Text.INNER["coat_whose"], "'Whose coat is this?'")

	# upstairs extras: the bathroom's towel is a clue, a plain item just talks
	world.player.position = Vector2(500, 110)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "towel", "A offers the towel in the bathroom")
	world.press_a()
	check(world.engine.journal.has("towel"), "the bloodstained towel is a clue")
	world.player.position = Vector2(402, 140)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "washstand", "A offers the washstand")
	world.press_a()
	check(hud.caption_text() == Text.LOOKS["washstand"], "examining the washstand says its line")

	# the stairs down (no autosave on a staircase), then the cellar door, the scarf, the front door
	world.player.position = Vector2(472, 360)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "stairs_down", "A offers the stairs down")
	world.press_a()
	_step(1.5)
	check(world.mode == "play" and world.area.id == "house_down", "downstairs")
	check(world.area.interacts.size() > 5 and world.player.position.distance_to(world.area.spawns["from_up"]) < 1.0, "you arrive at the foot of the stairs")
	world.player.position = Vector2(268, 372)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "cellar_door", "A offers the cellar door")
	world.press_a()
	check(hud.caption_text() == Text.INNER["cellar_locked"] and world.engine.journal.has("cellar"), "the cellar door is locked and noted")
	world.press_a()
	check(world.engine.journal.count("cellar") == 1, "the cellar is noted once")
	check(_walk_to(Vector2(120, 352)) and _walk_to(Vector2(80, 352)), "walked to the scarf")
	_step(0.1)
	check(str(world._cand.get("id", "")) == "scarf", "A offers the scarf")
	world.press_a()
	check(world.engine.has_flag("scarf") and world.player.scarf, "the scarf is on")
	check(_walk_to(Vector2(44, 360)), "walked to the front door")
	_step(0.1)
	world.engine.journal.erase("coat")
	world.press_a()
	_step(0.3)
	check(world.mode == "play" and world.area.id == "house_down" and hud.caption_text() == Text.INNER["door_coat"], "no leaving without a coat")
	world.engine.journal.append("coat")
	world.press_a()
	_step(0.3)
	check(world.mode == "transition", "the door starts the fade")
	_step(1.5)
	check(world.mode == "play" and world.area.id == "street", "out in the street")
	check(Save.has_save(), "autosaved on leaving the house")
	check(hud.is_revealed("bars") and not hud.is_revealed("b"), "the bars appear, B is not there yet")
	check(world.area.in_shade(world.player.position), "you start in the porch shade")
	var hp0: float = world.engine.hp
	_step(2.0)
	check(is_equal_approx(world.engine.hp, hp0), "no damage in the shade")

	# sun damage on the road, then shade
	world.player.position = Vector2(300, 262)
	var hp1: float = world.engine.hp
	_step(3.0)
	check(world.engine.hp < hp1 - 2.5 and world.engine.hp > hp1 - 3.5, "about 1 HP/s in the sun (lost %.2f in 3 s)" % (hp1 - world.engine.hp))
	check(hud.caption_text() != "" or world.engine.has_flag("sun_said"), "the first burn is commented")
	world.player.position = Vector2(560, 170)
	var hp2: float = world.engine.hp
	_step(4.0)
	check(world.engine.hp > hp2, "Health regenerates under the awning")

	# the Watcher
	var watcher: Node2D = null
	for n in world._npcs:
		if n.id == "watcher":
			watcher = n
	check(watcher != null and watcher.position.x > 1000, "the Watcher is in the street")
	world.player.position = Vector2(1250, 200)
	_step(1.0)
	check(watcher.face.x < 0.0 or watcher.face.y < 0.0, "the Watcher turns towards you")
	world.press_a()
	check(hud.caption_text() == "You should not be out in that sun.", "the Watcher's one line")
	check(world.engine.journal.has("watcher"), "it goes in the Journal")

	# death and respawn
	world.player.position = Vector2(640, 262)
	world.engine.blood = 80.0
	world.engine.hp = 1.0
	var from: Vector2 = world.player.position
	_step(1.5)
	check(world.mode == "dying", "dying when Health reaches 0")
	_step(T.f("death.fade_s") + 0.3)
	check(world.mode == "play", "back in play after the 2 s fade")
	check(world.area.in_shade(world.player.position), "respawned in the shade")
	check(world.player.position.distance_to(from) <= T.m(3.0) + 12.0, "within 3 m of where you fell (%.0f px)" % world.player.position.distance_to(from))
	check(world.engine.hp >= T.f("stats.max_hp") * 0.5 and world.engine.hp < T.f("stats.max_hp") * 0.5 + 2.0, "half the Health is back (%.1f)" % world.engine.hp)
	check(is_equal_approx(world.engine.blood, 60.0), "a quarter of the Blood is lost")
	check(world.engine.deaths == 1, "death counted")

	# the alley and B
	world.player.position = Vector2(1785, 160)
	check(not world.engine.has_button("b"), "no B yet")
	check(_walk_to(Vector2(1785, 100)), "walked into the alley mouth")
	_step(0.3)
	check(world.engine.has_button("b") and hud.is_revealed("b"), "B unlocks in the alley")
	check(hud.banner_active(), "the unlock banner shows")
	check(Save.read().get("state", {}).get("buttons", []).has("b"), "autosaved in the alley")
	var walk_speed: float = world.engine.speed()
	world.press_b()
	check(world.engine.sneaking and world.engine.speed() < walk_speed, "B toggles Sneak, slower")
	var before: Vector2 = world.player.position
	world.test_dir = Vector2.UP
	_step(1.0)
	world.test_dir = Vector2.ZERO
	var moved := before.distance_to(world.player.position)
	check(moved < T.f("player.walk_speed") * 0.6 and moved > 5.0, "sneaking covers less ground (%.0f px/s)" % moved)
	_step(1.0)
	check(world.player.ring_detect < T.m(T.f("sneak.detect_radius_m")), "the detection ring shrank")
	world.press_b()
	check(not world.engine.sneaking, "B toggles back")

	# quit and reload from the autosave
	world.save_game()
	var snap: Dictionary = world.engine.to_dict()
	_new_world()
	await process_frame
	check(world.resume(), "resumes from the autosave")
	check(world.area.id == "street" and world.engine.has_button("b") and world.engine.journal == snap["journal"], "resumed state matches")
	check(world.player.position.distance_to(Vector2(snap["pos"][0], snap["pos"][1])) < 1.0, "same position")
	check(hud.is_revealed("b") and hud.is_revealed("bars") and hud.is_revealed("mission") and hud.is_revealed("dpad"), "the HUD comes back as it was")
	check(world.player.scarf, "still wearing the scarf")
	_step(0.5)
	# frozen while the kit is up
	var pos_before: Vector2 = world.player.position
	world.kit_up = true
	world.test_dir = Vector2.RIGHT
	_step(0.5)
	check(world.player.position == pos_before, "the world stands still under the kit")
	world.kit_up = false
	world.test_dir = Vector2.ZERO
