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
const DialogueScript = preload("res://scripts/games/turned/turned_dialogue.gd")

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
	await _test_night()
	_test_dialogue_runner()
	await _test_dialogue_world()
	await _test_bar()
	await _test_follower()
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

## Presses A through the lines of the scene on screen until a choice appears or the scene ends.
func _dlg_lines() -> void:
	var guard := 0
	while world.mode == "dialogue" and str(world.dlg.view().get("kind", "")) != "choice" and guard < 60:
		hud.dialogue_skip()
		world.press_a()
		guard += 1
	if world.mode == "dialogue":
		hud.dialogue_skip()

## Takes the option of the choice on screen whose text is the dialogue text `text_id`.
func _pick(text_id: String) -> void:
	hud.dialogue_skip()
	var opts: Array = world.dlg.view().get("options", [])
	var i := opts.find(Text.DIALOGUE[text_id])
	check(i >= 0, "the option '%s' is offered" % text_id)
	if i >= 0:
		world.dlg.selected = i
		world.press_a()

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
	check(is_equal_approx(c.hour, 7.0) and c.day == 1 and c.hour_text() == "07:00", "Friday starts at dawn, 07:00, day 1")
	check(not T.b("sun.freeze_clock"), "the clock runs")
	c.hour = 12.0
	check(is_equal_approx(c.intensity(), 1.0) and c.moon_level() == 0.0, "noon: full sun, no moon")
	c.hour = 17.5
	check(c.intensity() > 0.0 and c.intensity() < 1.0 and c.moon_level() == 0.0, "17:30: the sun is fading, the moon is not up")
	c.hour = 18.5
	check(c.intensity() == 0.0 and not c.is_day() and c.moon_level() == 0.0 and is_equal_approx(c.night(), 1.0), "18:30: sunset is over, moonrise starts at zero")
	c.hour = 21.0
	check(c.intensity() == 0.0 and is_equal_approx(c.moon_level(), 1.0), "21:00: dark, the moon is high")
	c.hour = 2.0
	check(is_equal_approx(c.moon_level(), 1.0) and c.moon_progress() > 0.5, "02:00: the moon is still up, past the middle of its way")
	c.hour = 5.75
	check(c.moon_level() == 0.0 and c.intensity() == 0.0, "05:45: the moon has set and it is still dark")
	c.hour = 6.5
	check(c.intensity() > 0.0 and c.intensity() < 1.0, "06:30: dawn")
	c.hour = 23.5
	c.advance_hours(1.0)
	check(c.day == 2 and is_equal_approx(c.hour, 0.5), "past midnight it is the next day")
	c.skip_to(7.0)
	check(c.day == 2 and is_equal_approx(c.hour, 7.0), "skip_to a later time stays on the same day")
	c.skip_to(6.0)
	check(c.day == 3 and is_equal_approx(c.hour, 6.0), "skip_to an earlier time goes to tomorrow")
	var c2: SunClock = SunClock.new()
	c2.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(c2.day == 3 and is_equal_approx(c2.hour, 6.0), "the clock survives a JSON round trip")

# ---------------------------------------------------------------- day, dusk, night and the moon

func _test_night() -> void:
	_new_world()
	await process_frame
	world.begin_new()
	_step(3.0)
	check(is_equal_approx(world.clock.hour, 7.0), "the clock stands still during the prologue")
	world.engine.set_flag("control")
	world.engine.set_flag("mirror")
	world.mode = "play"
	world._pro = "done"
	world.hud.fade = 0.0
	world.hud.fade = 0.0
	_step(5.0)
	check(is_equal_approx(world.clock.hour, 7.0), "the clock stands still indoors (sun.run_indoors is false)")
	world._load_area("street")
	world.player.position = world.area.spawns.values()[0]
	var h0: float = world.clock.hour
	_step(10.0)
	check(world.clock.hour > h0 + 0.3 and world.clock.hour < h0 + 0.5, "in free play 10 s = 1/3 of a game hour (720 s per day)")
	check(world.hud.clock_text == world.clock.hour_text(), "the HUD shows the game time")
	world.clock.hour = 12.0
	_step(1.0)
	var day_c: Color = world._ambient_color()
	check(world._sun_light != null and world._moon_light != null, "the street has a sun and a moon light")
	check(world._sun_light.energy > 0.0 and world._moon_light.energy == 0.0, "noon: sun light on, moon light off")
	world.clock.hour = 23.0
	_step(1.0)
	var night_c: Color = world._ambient_color()
	check(night_c.get_luminance() < day_c.get_luminance() * 0.6, "the street is much darker at night (%.2f vs %.2f)" % [night_c.get_luminance(), day_c.get_luminance()])
	check(world._sun_light.energy == 0.0 and world._moon_light.energy > 0.0, "23:00: sun light off, moon light on")
	check(world.hud.clock_moon > world.hud.clock_sun, "the HUD shows the moon at night")
	world.clock.hour = 3.0
	_step(1.0)
	var a0: float = world._moon_light.rotation
	world.clock.hour = 5.0
	_step(1.0)
	check(world._moon_light.rotation > a0, "the moon light sweeps across as the night goes on")
	world.clock.hour = 23.0
	check(world._glow != null and world._glow.night > 0.9, "the glow layer knows it is night (windows light up)")
	world.clock.hour = 23.0
	var hp0: float = world.engine.hp
	world.player.position = Vector2(330, 262)
	_step(2.0)
	check(world.engine.hp >= hp0, "no sun damage at night, in the open street")
	world.save_game()
	var d := Save.read()
	check(not d.is_empty() and is_equal_approx(float(d["clock"]["hour"]), world.clock.hour), "the autosave keeps the time")
	world.discard = false
	world.clock.hour = 1.0
	world._load_area("house_down")
	_step(0.5)
	var in_night: Color = world._ambient_color()
	world.clock.hour = 12.0
	_step(0.5)
	check(in_night.get_luminance() < world._ambient_color().get_luminance(), "indoors is dimmer at night than by day")

# ---------------------------------------------------------------- dialogue runner and items

const FIXTURE := {
	"t": {
		"start": "a",
		"nodes": {
			"a": {"speaker": "watcher", "text": "dev_hello", "next": "b"},
			"b": {"type": "do", "effects": ["item:+matches", "flag:f1", "journal:neck", "mission:find_out", "hour:21.5", "sfx:door"], "next": "c"},
			"c": {"type": "branch", "if": ["item:matches", "flag:f1", "!flag:nope"], "then": "d", "else": "z"},
			"d": {"type": "choice", "text": "dev_ask", "options": [
				{"text": "dev_opt_take", "if": ["!item:matches"], "next": "z"},
				{"text": "dev_opt_have", "if": ["item:matches", "journal:neck", "mission:find_out"], "effects": ["flag:chose_have", "item:-matches"], "next": "e"},
				{"text": "dev_opt_look", "effects": ["unflag:f1"], "next": "e"}]},
			"e": {"speaker": "", "text": "dev_quiet", "if": ["flag:never"], "next": "f"},
			"f": {"speaker": "", "text": "dev_end", "if": ["hour>=21", "day>=1", "hour<23"]},
			"z": {"type": "end", "effects": ["flag:ended_bad"]},
		},
	},
}

func _test_dialogue_runner() -> void:
	var e: EngineScript = EngineScript.new()
	var clk: SunClock = SunClock.new()
	clk.hour = 22.0
	check(DialogueScript.validate(DialogueScript.shipped()).is_empty(), "the shipped dialogue scenes are valid: %s" % str(DialogueScript.validate(DialogueScript.shipped())))
	check(DialogueScript.validate(FIXTURE).is_empty(), "the test scene is valid: %s" % str(DialogueScript.validate(FIXTURE)))
	for text_id in Text.DIALOGUE:
		check(str(Text.DIALOGUE[text_id]) != "", "dialogue text %s is not empty" % text_id)
	# items and flags in the engine
	check(not e.has_item("matches") and e.add_item("matches") and not e.add_item("matches") and e.has_item("matches"), "items: add once, no duplicates")
	check(e.remove_item("matches") and not e.remove_item("matches"), "items: remove once")
	e.add_item("watch")
	e.set_flag("x")
	e.clear_flag("x")
	check(not e.has_flag("x"), "a flag can be cleared")
	var back: EngineScript = EngineScript.new()
	back.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	check(back.items == ["watch"], "items survive a JSON round trip")
	for id in Text.ITEMS:
		check(Text.ITEMS[id].has("name") and Text.ITEMS[id].has("desc"), "item %s has a name and a description" % id)
	var eb: EngineScript = EngineScript.new()
	check(HudScript.item_desc("watch", eb).contains("ticks"), "the watch ticks until it breaks")
	eb.set_flag("watch_broken")
	check(HudScript.item_desc("watch", eb).contains("stopped"), "a broken watch has its own description")
	e = EngineScript.new()
	# a whole scene
	var d: DialogueScript = DialogueScript.new(FIXTURE)
	d.engine = e
	d.clock = clk
	check(not d.start("nope") and not d.active, "an unknown scene does not start")
	check(d.start("t") and d.active and d.node_id == "a", "the scene starts on its first line")
	var v := d.view()
	check(v["kind"] == "line" and v["speaker"] == "watcher" and v["speaker_name"] == Text.SPEAKERS["watcher"] and v["text"] == Text.DIALOGUE["dev_hello"], "a line shows its speaker and text")
	d.advance()
	check(e.has_item("matches") and e.has_flag("f1") and e.journal.has("neck") and e.mission == "find_out", "the do node applied its effects")
	check(d.take_events() == ["hour:21.5", "sfx:door"] and d.take_events().is_empty(), "effects for the world are handed over once, in order")
	check(d.node_id == "d" and d.view()["kind"] == "choice", "the branch took its 'then' path to the choice")
	check(d.view()["text"] == Text.DIALOGUE["dev_ask"] and d.view()["options"].size() == 2, "options whose condition fails are hidden (2 of 3 shown)")
	check(d.view()["options"][0] == Text.DIALOGUE["dev_opt_have"], "the first shown option is the one whose conditions hold")
	d.move(1)
	check(d.selected == 1, "down moves the highlight")
	d.move(1)
	check(d.selected == 0, "the highlight wraps")
	d.advance()
	check(e.has_flag("chose_have") and not e.has_item("matches"), "A takes the highlighted option and applies its effects")
	check(d.node_id == "f", "a line whose 'if' fails is skipped (e -> f)")
	d.clock.hour = 22.0
	check(d.holds(["hour>=21", "hour<23", "day>=1"]) and not d.holds(["hour<21"]), "clock conditions work")
	var saved := d.to_dict()
	var d2: DialogueScript = DialogueScript.new(FIXTURE)
	d2.engine = e
	d2.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(d2.active and d2.node_id == "f", "a scene resumes where it was saved")
	d.advance()
	check(not d.active and d.view().is_empty() and d.to_dict().is_empty(), "a node with no next ends the scene")
	d2.from_dict({"scene": "gone", "node": "x"})
	check(not d2.active, "a saved scene that no longer exists is dropped")
	# an end node applies its effects and stops the scene
	var e3: EngineScript = EngineScript.new()
	var d4: DialogueScript = DialogueScript.new({"u": {"start": "c", "nodes": {"c": {"type": "branch", "if": ["item:matches"], "then": "a", "else": "z"}, "a": {"text": "dev_end"}, "z": {"type": "end", "effects": ["flag:ended_bad"]}}}})
	d4.engine = e3
	d4.start("u")
	check(not d4.active and e3.has_flag("ended_bad"), "an end node applies its effects and stops the scene")
	# missing text is marked TODO, and the validator says so
	var missing := {"m": {"start": "a", "nodes": {"a": {"speaker": "ghost", "text": "no_such_text", "if": ["bogus:1"], "effects": ["explode"], "next": "q"}}}}
	var errs := DialogueScript.validate(missing)
	check(errs.size() == 5, "the validator finds the unknown text, speaker, condition, effect and target (%d: %s)" % [errs.size(), str(errs)])
	var d5: DialogueScript = DialogueScript.new({"m": {"start": "a", "nodes": {"a": {"text": "no_such_text"}}}})
	d5.start("m")
	check(d5.view()["text"] == "TODO no_such_text", "missing text shows as TODO <id>")
	check(DialogueScript.validate({"m": {"start": "a", "nodes": {"a": {"type": "choice", "options": []}}}}).size() >= 1, "a choice with no options is an error")
	var loop := {"l": {"start": "a", "nodes": {"a": {"type": "do", "next": "b"}, "b": {"type": "do", "next": "a"}}}}
	var d6: DialogueScript = DialogueScript.new(loop)
	d6.start("l")
	check(not d6.active, "a loop of silent nodes ends instead of hanging")

# ---------------------------------------------------------------- dialogue in the world

func _test_dialogue_world() -> void:
	_new_world()
	await process_frame
	world.begin_new()
	_step(1.0)
	world.engine.set_flag("control")
	world.engine.set_flag("mirror")
	world.engine.dpad = true
	world.mode = "play"
	world._pro = "done"
	world.hud.fade = 0.0
	world._load_area("street")
	world.player.position = world.area.spawns.values()[0]
	world.clock.hour = 12.0
	hud.size = Vector2(1280, 720)
	check(not world.start_dialogue("nope"), "an unknown scene does not start in the world")
	check(world.start_dialogue("dev_demo") and world.mode == "dialogue" and hud.dialogue_active(), "a scene starts from free play and shows the box")
	check(not world.start_dialogue("dev_demo"), "a scene cannot start inside a scene")
	check(not hud.dialogue_typed(), "the first line is still typing out")
	world.press_a()
	check(hud.dialogue_typed() and world.dlg.node_id == "n1", "the first A shows the whole line, it does not go on")
	_step(0.05)
	check(world.hud.a_label == "continue", "A says Continue on a line")
	var pos0: Vector2 = world.player.position
	var hour0: float = world.clock.hour
	world.test_dir = Vector2.RIGHT
	_step(2.0)
	world.test_dir = Vector2.ZERO
	check(world.player.position.distance_to(pos0) < 0.5 and is_equal_approx(world.clock.hour, hour0), "the player and the clock stand still during a scene")
	world.press_a()
	check(world.dlg.node_id == "n2" and hud.dialogue_active() and not hud.dialogue_typed(), "the next A goes to the choice, which starts typing")
	world.press_a()
	_step(0.1)
	check(world.dlg.node_id == "n2" and world.hud.a_label == "choose", "A says Choose on a choice once it has typed out")
	var lay: Dictionary = hud._dlg_layout()
	check((lay["opts"] as Array).size() == 2, "the box has a row for each option shown (2: the one that needs the matches is hidden)")
	world.test_dir = Vector2.DOWN
	_step(0.1)
	world.test_dir = Vector2.ZERO
	_step(0.1)
	check(world.dlg.selected == 1, "down moves the highlight (one step per press)")
	world.test_dir = Vector2.DOWN
	_step(1.0)
	world.test_dir = Vector2.ZERO
	check(world.dlg.selected == 0, "a held arrow moves only one step (1 -> 0, wrapping, not round and round)")
	world.test_dir = Vector2.UP
	_step(0.1)
	world.test_dir = Vector2.ZERO
	_step(0.1)
	check(world.dlg.selected == 1, "up moves the highlight back (0 -> 1, wrapping)")
	# a mid-scene save and resume
	world.save_game()
	var d := Save.read()
	check(d.has("dialogue") and str(d["dialogue"]["node"]) == "n2", "the autosave keeps a scene that is on screen")
	_new_world()
	await process_frame
	check(world.resume() and world.mode == "dialogue" and world.dlg.node_id == "n2" and hud.dialogue_active(), "Resume puts the scene back on screen")
	hud.size = Vector2(1280, 720)
	_step(1.0)
	hud.dialogue_skip()
	# tap the first option: the box's row, not A
	var tap: Rect2 = (hud._dlg_layout()["opts"] as Array)[0]
	hud._on_press(-1, tap.get_center(), true)
	hud._on_press(-1, tap.get_center(), false)
	check(world.engine.has_item("matches") and world.engine.has_flag("dev_took"), "tapping an option takes it, with its effects")
	check(hud.is_revealed("menu"), "the Menu button appears when the first item is picked up")
	check(world.dlg.node_id == "n3", "and the scene goes on to its next line")
	world.press_a()
	world.press_a()
	check(world.dlg.node_id == "n4", "the scene reaches its last line")
	world.press_a()
	world.press_a()
	check(world.mode == "play" and not hud.dialogue_active() and not world.dlg.active, "when the scene ends the world is back in free play")
	hud.open_menu("items")
	check(hud._menu_tab == "items" and hud.menu_open, "the Items tab opens once there is an item")
	hud.close_menu()
	world.save_game()
	check(not Save.read().has("dialogue"), "no scene in the autosave when none is running")

# ---------------------------------------------------------------- the bar (scene 2)

func _test_bar() -> void:
	var bar: Area = Area.make("bar") as Area
	check(bar.indoor and bar.in_shade(Vector2(100, 100)), "the bar is indoors, all shade")
	for k in bar.spawns:
		check(bar.is_free(bar.spawns[k], 9.0), "bar spawn %s is free" % k)
	for it in bar.interacts:
		check(bar.bounds.has_point(it["pos"]) and bar.is_free(it["pos"], 9.0) and Text.VERBS.has(it["verb"]), "bar interact %s is a free spot with a verb label" % it["id"])
		check(_reachable(bar, bar.spawns["from_street"], it["pos"]), "bar interact %s reachable" % it["id"])
	var afraid := 0
	var keepers := 0
	for n in bar.npcs:
		var pp := Vector2(float(n["pos"][0]), float(n["pos"][1]))
		check(bar.is_free(pp, 9.0), "bar person %s stands on free ground" % n["id"])
		check(Text.SPEAKERS.has(n["id"]), "bar person %s has a speaker name" % n["id"])
		if bool(n.get("afraid", false)):
			afraid += 1
		if n["id"] == "tavernkeep":
			keepers += 1
	check(afraid == 4 and keepers == 1, "a tavernkeep and four afraid patrons")
	var st: Area = Area.make("street") as Area
	var door: Dictionary = {}
	for it in st.interacts:
		if it["id"] == "bar_door":
			door = it
	check(not door.is_empty() and _reachable(st, st.spawns["from_house"], Vector2(door["pos"].x, door["pos"].y + 16.0)), "the pub door in the street is reachable from the porch")
	check(st.is_free(st.spawns["from_bar"], 9.0) and st.in_shade(st.spawns["from_bar"]), "thrown out of the bar you land in the awning's shade")
	# the whole of scene 2, from the street
	_new_world()
	await process_frame
	world.begin_new()
	_step(1.0)
	for f in ["control", "mirror", "pockets"]:
		world.engine.set_flag(f)
	world.engine.dpad = true
	world.engine.show_bars = true
	world.engine.add_item("note")
	world.engine.set_mission("go_bar")
	world.mode = "play"
	world._pro = "done"
	world.hud.fade = 0.0
	world._load_area("street")
	world.clock.hour = 14.0
	world.player.position = Vector2(1069, 170)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "bar_door", "A offers the pub door")
	world.press_a()
	check(world.mode == "transition", "the door starts the fade")
	_step(1.6)
	check(world.area.id == "bar" and world.mode == "dialogue", "inside The Crooked Lantern the scene starts by itself")
	check(world.dlg.view()["speaker"] == "tavernkeep" and world.dlg.view()["text"] == Text.DIALOGUE["bar_shout"], "the tavernkeep shouts")
	var hour_in: float = world.clock.hour
	# the patrons turn their backs on you
	var patron: Node2D = null
	var dist := INF
	for n in world._npcs:
		if n.id == "patron" and n.position.distance_to(world.player.position) < dist:
			patron = n
			dist = n.position.distance_to(world.player.position)
	_step(1.5)
	check(is_equal_approx(world.clock.hour, hour_in), "no game time passes in the scene")
	check(patron != null and patron.face.dot((world.player.position - patron.position).normalized()) < 0.0, "a patron has turned away from you")
	var guard := 0
	while world.mode == "dialogue" and guard < 40:
		hud.dialogue_skip()
		world.press_a()
		guard += 1
	check(world.mode == "transition", "after the last line you are put out of the door")
	check(world.engine.has_flag("bar_scene") and world.engine.has_flag("bar_thrown") and world.engine.journal.has("bar"), "the scene is remembered and the Journal has it")
	_step(1.6)
	check(world.area.id == "street" and world.mode == "play", "back in the street")
	check(world.player.position.distance_to(world.area.spawns["from_bar"]) < 2.0, "just outside the pub door")
	check(absf(world.clock.hour - 21.0) < 0.05 and world.clock.moon_level() > 0.9, "it is 21:00 and the moon is up")
	check(world.engine.mission == "find_out", "the mission goes back to finding out what happened")
	check(not world.dlg.active and not hud.dialogue_active(), "the scene is over")
	world.player.position = Vector2(1069, 170)
	_step(0.1)
	world.press_a()
	check(hud.caption_text() == Text.INNER["bar_locked"] and world.mode == "play", "the door is bolted now")
	# a game saved inside the bar before the scene is over resumes into the scene
	world.engine.clear_flag("bar_scene")
	world._load_area("bar")
	world.player.position = world.area.spawns["from_street"]
	world.save_game()
	_new_world()
	await process_frame
	check(world.resume() and world.area.id == "bar" and world.mode == "dialogue", "Resume inside the bar starts the scene")

# ---------------------------------------------------------------- the follower (scene 3)

func _street_world_after_bar() -> void:
	_new_world()
	await process_frame
	world.begin_new()
	_step(1.0)
	for f in ["control", "mirror", "pockets", "bar_scene", "bar_thrown"]:
		world.engine.set_flag(f)
	world.engine.dpad = true
	world.engine.show_bars = true
	world.engine.add_item("note")
	world.mode = "play"
	world._pro = "done"
	world.hud.fade = 0.0
	world._load_area("street")
	world.clock.hour = 21.0
	world.player.position = world.area.spawns["from_bar"]

func _test_follower() -> void:
	var st: Area = Area.make("street") as Area
	check(st.in_shade(Vector2(720, 60)) and st.trigger_at(Vector2(720, 60)) == "lane" and st.trigger_at(Vector2(300, 260)) == "", "the side lane is shade and a trigger")
	check(st.is_free(Vector2(720, 100), 9.0) and not st.is_free(Vector2(680, 100), 9.0) and not st.is_free(Vector2(760, 100), 9.0), "the lane is 48 px wide between two walls")
	check(_reachable(st, st.spawns["from_house"], Vector2(720, 60)), "the lane is reachable from the porch")
	check(Text.VERBS.has("grab") and Text.SPEAKERS.has("witness") and Text.MISSIONS.has("follower"), "verb, speaker and mission are written")
	# the house door will not open with someone behind you
	await _street_world_after_bar()
	world.engine.set_flag("followed")
	world.player.position = Vector2(232, 170)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "house_door", "A offers the house door")
	world.press_a()
	_step(0.2)
	check(world.mode == "play" and hud.caption_text() == Text.INNER["door_followed"], "no going home with someone behind you")
	# the man steps out of the bar
	await _street_world_after_bar()
	world._on_area_ready()
	_step(1.0)
	check(world._follower == null and not world.engine.has_flag("followed"), "he does not come out at once")
	_step(2.0)
	check(world._follower != null and world.engine.has_flag("followed") and world._fol_state == "exit", "after a moment a man steps out of the pub")
	check(hud.caption_text() == Text.INNER["fol_door"], "'... sees me, and runs'")
	_step(3.0)
	check(world._fol_state == "wait_far" and world._follower.position.distance_to(Vector2(1215, 172)) < 6.0, "he ran off along the pavement and watches you")
	# he keeps away in the open
	world.player.position = Vector2(1180, 190)
	_step(0.3)
	check(world._fol_state == "flee", "walk up to him and he runs")
	_step(2.5)
	check(world.player.position.distance_to(world._follower.position) > 110.0, "he keeps his distance in the open")
	# walking home: he tails you along your own trail
	world.player.position = Vector2(1069, 250)
	_step(0.5)
	check(_walk_to(Vector2(800, 250), 40.0), "walked west along the road")
	_step(0.5)
	check(world._fol_state == "tail", "he follows once you are far enough away")
	check(_walk_to(Vector2(770, 250), 10.0), "walked on")
	_step(3.0)
	var behind: float = world.player.position.distance_to(world._follower.position)
	check(behind > 180.0 and behind < 320.0, "he stays about 8 m behind (%.0f px; state %s, he at %s, you at %s)" % [behind, world._fol_state, str(world._follower.position), str(world.player.position)])
	check(world._fol_steps >= 6, "his footsteps have played (%d)" % world._fol_steps)
	# I stop, he stops
	_step(1.5)
	var held: Vector2 = world._follower.position
	var steps_now: int = world._fol_steps
	_step(3.0)
	check(world._follower.position.distance_to(held) < 1.0 and world._fol_steps == steps_now, "when you stop, he stops and his footsteps stop")
	check(world.engine.has_flag("fol_h1") and world.engine.has_flag("fol_h2") and world.engine.mission == "follower", "the thoughts came: 'when I slow down', 'I stop, they stop'; the mission is to find out who")
	# the corner
	check(_walk_to(Vector2(735, 250), 10.0) and _walk_to(Vector2(735, 175), 20.0), "walked to the lane mouth")
	check(not world._fol_state == "mouth", "he is not at the corner yet")
	check(_walk_to(Vector2(722, 118), 10.0), "stepped round the corner into the lane")
	_step(12.0)
	check(world._fol_state == "mouth" and world._follower.position.distance_to(Vector2(720, 172)) < 12.0, "he came to the corner to look for you")
	_step(0.2)
	check(str(world._cand.get("id", "")) == "grab_follower" and world.hud.a_label == "grab", "A offers to grab him")
	world.press_a()
	check(world.mode == "dialogue" and world.dlg.view()["speaker"] == "you" and world.dlg.view()["text"] == Text.DIALOGUE["fol_why"], "'Why are you following me?!'")
	_dlg_lines()
	check(world.mode == "play" and world.engine.has_flag("witness_met") and world.engine.journal.has("witness"), "'...It's really you.' and the scene is over")
	check(world._fol_state == "witness" and world._follower == null, "he stays at the corner")
	var wit: Node2D = null
	for n in world._npcs:
		if n.id == "witness":
			wit = n
	check(wit != null, "the man is now somebody you can talk to")
	world.player.position = Vector2(720, 140)
	_step(0.2)
	check(str(world._cand.get("id", "")) == "npc:witness", "A offers to talk to him")
	world.press_a()
	check(hud.caption_text() == Text.NPC_LINES["witness"]["all"], "his one line, for now")
	# the house door works again, and Resume brings him back
	world.player.position = Vector2(232, 170)
	_step(0.1)
	world.press_a()
	check(world.mode == "transition", "now the house door opens")
	await _street_world_after_bar()
	world.engine.set_flag("followed")
	world._on_area_ready()
	world.player.position = Vector2(600, 205)
	world.save_game()
	_new_world()
	await process_frame
	check(world.resume() and world.area.id == "street" and world._follower != null and world._fol_state == "tail", "Resume mid-chase puts him behind you again")
	check(world._follower.position.distance_to(world.player.position) > 200.0, "and he is not on top of you")

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

	# walk to a clue with the d-pad: bedside -> the wall calendar
	world.player.position = world.area.spawns["bedside"]
	check(_walk_to(Vector2(300, 120)), "walked to the wall calendar")
	_step(0.1)
	check(str(world._cand.get("id", "")) == "calendar", "A offers the calendar")
	check(world.player.hobble, "before the mirror the player hobbles")
	world.press_a()
	check(world.engine.journal.has("calendar") and hud.is_revealed("menu"), "the clue is in the Journal and the Menu appears")
	check(hud.caption_text() == Text.CLUES["calendar"]["say"], "the calendar says it is Friday")
	# the coat is a scene: the pockets, the matches, the note sewn into the lining
	world.player.position = Vector2(241, 76)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "coat", "A offers the coat")
	world.press_a()
	check(world.mode == "dialogue" and world.engine.journal.has("coat"), "the coat starts its scene and goes in the Journal")
	_dlg_lines()
	check(world.dlg.view()["options"].size() == 5, "five things to do with the coat (tearing the stitches needs the inside pocket first)")
	_pick("coat_opt_left")
	_dlg_lines()
	check(not world.engine.has_item("matches"), "the left pocket is empty")
	_pick("coat_opt_right")
	_dlg_lines()
	check(world.engine.has_item("matches") and world.engine.journal.has("matches"), "the right pocket has the matches")
	_pick("coat_opt_inner")
	_dlg_lines()
	check(world.dlg.view()["options"].has(Text.DIALOGUE["coat_opt_tear"]), "now the stitches can be torn")
	check(not world.engine.has_item("note"), "the inside pocket is sewn shut")
	_pick("coat_opt_tear")
	_dlg_lines()
	check(world.engine.has_item("note") and world.engine.journal.has("note") and world.engine.mission == "go_bar", "the note: the mission is to go to The Crooked Lantern")
	_pick("coat_opt_wear")
	_dlg_lines()
	check(world.dlg.view()["options"].size() == 1, "only 'leave the coat' is left")
	_pick("coat_opt_done")
	check(world.mode == "play" and world.engine.journal.size() == 4, "back in free play, four clues so far (%s)" % str(world.engine.journal))
	_step(0.1)
	world.press_a()
	_dlg_lines()
	_pick("coat_opt_done")
	check(world.engine.journal.size() == 4 and world.engine.items == ["matches", "note"], "the coat gives its things only once")

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
	check(world.mode == "play" and world.engine.mission == "go_bar" and hud.is_revealed("mission"), "the Missions box shows the mission (the note already says: go to The Crooked Lantern)")

	# after the mirror: no more limp, the thoughts play, then A checks the pockets, then the coat
	check(not world.player.hobble, "after the mirror the limp is gone")
	check(not world.engine.has_flag("pockets"), "the pockets are not offered before the thoughts")
	_step(10.0)
	check(world.engine.has_flag("thought"), "the thoughts after the mirror have played")
	world.engine.journal.erase("coat")        # pretend the coat has not been found yet
	world.engine.set_mission("find_out")
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
	check(world.engine.journal.has("coat"), "the stranger's coat is in the Journal")
	_dlg_lines()
	check(world.engine.mission == "find_out", "after the first line: back to finding out what happened")
	check(world.dlg.view()["text"] == Text.DIALOGUE["coat_whose"], "'Whose coat is this?'")
	_pick("coat_opt_done")

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
	world.engine.remove_item("note")
	world.press_a()
	_step(0.3)
	check(world.mode == "play" and world.area.id == "house_down" and hud.caption_text() == Text.INNER["door_note"], "no leaving before looking through the coat")
	world.engine.add_item("note")
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
