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
const Scenes = preload("res://scripts/games/turned/turned_scenes.gd")
const SceneText = preload("res://scripts/games/turned/turned_scene_text.gd")
const SceneViewScript = preload("res://scripts/games/turned/turned_scene_view.gd")
const SceneHudScript = preload("res://scripts/games/turned/turned_scene_hud.gd")
const CardsScript = preload("res://scripts/games/turned/turned_cards.gd")
const CardViewScript = preload("res://scripts/games/turned/turned_card_view.gd")

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
	await _test_scenes()
	await _test_scene_hud()
	await _test_cards()
	await _test_scene_dialogue()
	await _test_bedroom()
	await _test_house_rooms()
	await _test_bar()
	await _test_follower()
	await _test_scene6()
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

# ---------------------------------------------------------------- Scene mode (a painting with hotspots)

const SCENE_FIXTURE := {
	"a": {"art": "a", "variants": [{"when": ["hour>=18"], "art": "a_night"}], "hotspots": [
		{"id": "x", "label": "hs_dev_lamp", "pos": [0.40, 0.50], "once": true, "do": ["look:dev_lamp", "flag:took"]},
		{"id": "y", "label": "hs_dev_box", "pos": [0.60, 0.50], "when": ["flag:took"], "do": ["item:+matches", "journal:coat"]},
	]},
}

var sview: Control = null
var shud: Control = null
var cview: Control = null

func _new_scene_world() -> void:
	if sview != null:
		sview.queue_free()
	_new_world()
	sview = SceneViewScript.new()
	root.add_child(sview)
	sview.set_anchors_preset(Control.PRESET_TOP_LEFT)   # a fixed size for the test (no resize warning)
	sview.size = Vector2(1280, 720)
	world.attach_scene_view(sview)
	if shud != null:
		shud.queue_free()
	shud = SceneHudScript.new()
	root.add_child(shud)
	shud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shud.size = Vector2(1280, 720)
	world.attach_scene_hud(shud)
	if cview != null:
		cview.queue_free()
	cview = CardViewScript.new()
	root.add_child(cview)
	cview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cview.size = Vector2(1280, 720)
	world.attach_card_view(cview)

func _scene_ready_world() -> void:
	_new_scene_world()
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
	sview.size = Vector2(1280, 720)

## A tap on a chip, the way a phone sends it (a left MouseButton press).
func _tap_chip(id: String) -> void:
	var lay: Array = sview.layout()
	for c in lay:
		if str(c["id"]) == id:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = (c["hit"] as Rect2).get_center()
			sview._gui_input(ev)
			return
	check(false, "there is a chip '%s' to tap" % id)

## Presses A through the dialogue on screen until it ends.
func _finish_dialogue() -> void:
	var guard := 0
	while world.mode == "dialogue" and guard < 60:
		hud.dialogue_skip()
		world.press_a()
		guard += 1
	_step(0.05)                       # the world tells the painting it may listen again

## Rebuilds the world and resumes the autosave, expecting `expect_mode` and the scene `sid`.
func _scene_resume_check(sid: String, expect_mode: String, what: String) -> void:
	_new_scene_world()
	await process_frame
	var ok: bool = world.resume()
	hud.size = Vector2(1280, 720)
	sview.size = Vector2(1280, 720)
	check(ok and world.mode == expect_mode and world.in_scene and world.scene_id == sid and sview.visible, what)

func _test_scenes() -> void:
	# the data
	check(Scenes.validate(Scenes.shipped()).is_empty(), "the shipped scenes are valid: %s" % str(Scenes.validate(Scenes.shipped())))
	check(Scenes.validate(SCENE_FIXTURE).is_empty(), "the test scenes are valid: %s" % str(Scenes.validate(SCENE_FIXTURE)))
	var bad := {"x": {"art": "", "hotspots": [
		{"id": "a", "label": "nope", "pos": [0.01, 0.5], "do": ["scene:zz", "bogus"]},
		{"id": "a", "label": "hs_dev_lamp", "pos": [0.02, 0.5], "when": ["wat:1"], "do": []}]}}
	var problems: Array = Scenes.validate(bad)
	check(problems.size() >= 8, "bad scenes are caught: %d problems" % problems.size())
	for id in Scenes.shipped():
		if str(id).begins_with("dev_"):
			check(Scenes.painting(str((Scenes.shipped()[id] as Dictionary).get("art", ""))) == null, "the dev scene '%s' has no painting file (a placeholder is drawn)" % id)
	check(Scenes.painting("SC-01") != null and Scenes.painting("SC-02") != null and Scenes.has_painting("SC-01"), "the bedroom's two paintings load")
	check(Scenes.painting("") == null and Scenes.painting("does_not_exist") == null, "a missing painting is null, not an error")
	# the fit: the whole painting, never cropped
	for sz in [Vector2(1280, 720), Vector2(1600, 738), Vector2(1024, 768), Vector2(914, 514), Vector2(720, 1280)]:
		var pr: Rect2 = SceneViewScript.fit_rect(sz, Scenes.PAINTING_ASPECT)
		check(Rect2(Vector2.ZERO, sz).grow(0.01).encloses(pr) and absf(pr.size.x / pr.size.y - 1.5) < 0.001, "the painting fits whole into %s" % str(sz))
		check(absf(pr.position.x * 2.0 + pr.size.x - sz.x) < 0.01 and absf(pr.position.y * 2.0 + pr.size.y - sz.y) < 0.01, "and is centred in %s" % str(sz))
		check(is_equal_approx(pr.size.x, sz.x) or is_equal_approx(pr.size.y, sz.y), "and touches the screen on one axis at %s" % str(sz))
	# the chips: on screen, never over each other, big enough to hit, at every size
	for sz in [Vector2(1280, 720), Vector2(1600, 738), Vector2(1024, 768), Vector2(914, 514), Vector2(1370, 720) / 1.4]:
		var pr2: Rect2 = SceneViewScript.fit_rect(sz, Scenes.PAINTING_ASPECT)
		var k := clampf(sz.x / 900.0, 0.6, 1.0)
		for sid in Scenes.shipped():
			var items: Array = []
			for h in (Scenes.shipped()[sid]["hotspots"] as Array):
				items.append({"id": h["id"], "text": SceneText.HOTSPOTS[h["label"]], "pos": h["pos"]})
			var strip: Rect2 = SceneViewScript.nav_keep_out(sz)
			var lay: Array = SceneViewScript.compute_layout(sz, pr2, items, k, ThemeDB.fallback_font, [strip])
			check(lay.size() == items.size(), "%s at %s: a chip for every hotspot" % [sid, str(sz)])
			for c in lay:
				check(not (c["label_rect"] as Rect2).intersects(strip), "%s at %s: the label of '%s' is clear of the nav strip" % [sid, str(sz), c["id"]])
			var boxes: Array = []
			for c in lay:
				var circle := Rect2((c["center"] as Vector2) - Vector2(c["r"], c["r"]), Vector2(c["r"], c["r"]) * 2.0)
				boxes.append([circle, str(c["id"])])
				boxes.append([c["label_rect"], str(c["id"])])
				check(Rect2(Vector2.ZERO, sz).encloses(c["label_rect"]), "%s at %s: the label of '%s' is on screen" % [sid, str(sz), c["id"]])
				check((c["hit"] as Rect2).size.y >= T.f("scene.chip_hit_min") * k - 0.01, "%s at %s: '%s' is tall enough to hit" % [sid, str(sz), c["id"]])
			var clash := false
			for i in boxes.size():
				for j in range(i + 1, boxes.size()):
					if boxes[i][1] != boxes[j][1] and (boxes[i][0] as Rect2).intersects(boxes[j][0]):
						clash = true
			check(not clash, "%s at %s: no chip overlaps another" % [sid, str(sz)])
	# in the world
	await _scene_ready_world()
	check(not world.enter_scene("nope"), "an unknown scene does not open")
	hud.set_revealed("dpad", true)
	check(hud._role_at(hud._dpad_center()) == "dpad", "the d-pad answers a tap while walking")
	var hour0: float = world.clock.hour
	var pos0: Vector2 = world.player.position
	check(world.enter_scene("dev_room") and world.mode == "scene" and world.in_scene and sview.visible and hud.scene_mode, "a scene opens from free play")
	check(hud._role_at(hud._dpad_center()) == "", "the d-pad is gone while a painting is up")
	_step(0.1)
	check(sview.enabled and sview.spots.size() == 5 and sview.selected == 0, "the painting shows its 5 hotspots and is listening")
	world.test_dir = Vector2.RIGHT
	_step(2.0)
	world.test_dir = Vector2.ZERO
	check(world.player.position.distance_to(pos0) < 0.5 and is_equal_approx(world.clock.hour, hour0), "the player and the clock stand still in Scene mode")
	_tap_chip("lamp")
	check(world.engine.has_flag(Scenes.seen_flag("dev_room", "lamp")) and hud.caption_text() == SceneText.LOOKS["dev_lamp"], "tapping a chip examines it: a thought, and the hotspot is remembered")
	_tap_chip("box")
	check(world.engine.has_flag("dev_box") and sview.spots.size() == 5, "a hotspot's effects apply and it stays (it is not 'once')")
	# a dialogue from a painting returns to the painting
	_tap_chip("talk")
	check(world.mode == "dialogue" and world.in_scene and hud.dialogue_active(), "a hotspot can start a dialogue scene")
	_step(0.05)
	check(not sview.enabled, "the chips stop listening while the dialogue has the screen")
	_finish_dialogue()
	check(world.mode == "scene" and world.in_scene and sview.visible and not hud.dialogue_active(), "when the dialogue ends the painting is back")
	# an exit, and the keyboard: arrows move the highlight, A examines
	_tap_chip("door")
	check(world.scene_id == "dev_hall" and sview.spots.size() == 2, "an exit chip goes to another scene")
	_step(0.1)
	check(sview.selected == 0, "the first chip is highlighted")
	sview.move_selection(Vector2.RIGHT)
	check(sview.selected == 1, "right moves the highlight to the chip on the right")
	sview.move_selection(Vector2.RIGHT)
	check(sview.selected == 1, "and stays when there is nothing further right")
	sview.move_selection(Vector2.LEFT)
	check(sview.selected == 0, "left moves it back")
	sview.move_selection(Vector2.RIGHT)
	world.press_a()
	check(world.mode == "play" and not world.in_scene and not sview.visible and not hud.scene_mode, "A on 'Leave' goes back to walking")
	check(hud._role_at(hud._dpad_center()) == "dpad", "and the d-pad is back")
	# save and resume inside a painting
	world.enter_scene("dev_hall")
	world.save_game()
	check(str(Save.read().get("scene", "")) == "dev_hall", "the autosave keeps the painting that was up")
	await _scene_resume_check("dev_hall", "scene", "Resume puts the painting back")
	# ... and a dialogue that began on it
	check(world.enter_scene("dev_room") and world.start_dialogue("dev_demo"), "a dialogue starts from a painting")
	world.save_game()
	await _scene_resume_check("dev_room", "dialogue", "Resume puts the dialogue back over its painting")
	_finish_dialogue()
	check(world.mode == "scene" and world.scene_id == "dev_room", "and finishing it returns to the painting")
	world.leave_scene()
	world.save_game()
	check(not Save.read().has("scene"), "no scene in the autosave when none is up")
	# conditions, 'once', the night variant, and what an action can give
	world.scene_data = SCENE_FIXTURE
	check(world.enter_scene("a") and sview.spots.size() == 1 and str(sview.spots[0]["id"]) == "x", "a hotspot whose condition fails is not shown")
	_step(0.05)
	check(sview._art_id == "a", "by day the painting is the day one")
	_tap_chip("x")
	check(sview.spots.size() == 1 and str(sview.spots[0]["id"]) == "y", "a 'once' hotspot goes away after it is used, and the one it unlocked appears")
	world.clock.hour = 20.0
	sview.refresh()
	check(sview._art_id == "a_night", "in the evening the night painting is chosen")
	_tap_chip("y")
	check(world.engine.has_item("matches") and world.engine.journal.has("coat") and hud.is_revealed("menu"), "an item and a Journal line from a hotspot reveal the Menu")
	world.leave_scene()
	world.scene_data = {}
	# a new game leaves any painting
	world.enter_scene("dev_room")
	world.begin_new()
	check(not world.in_scene and not sview.visible and not hud.scene_mode and world.mode == "prologue", "a new game leaves the painting")

# ---------------------------------------------------------------- the Scene HUD (phase S2)

func _test_scene_hud() -> void:
	# the day's periods
	check(SceneHudScript.period_id(4.9) == "night" and SceneHudScript.period_id(5.0) == "morning" and SceneHudScript.period_id(11.99) == "morning", "night until 05:00, then morning")
	check(SceneHudScript.period_id(12.0) == "afternoon" and SceneHudScript.period_id(16.99) == "afternoon" and SceneHudScript.period_id(17.0) == "evening", "afternoon from 12:00, evening from 17:00")
	check(SceneHudScript.period_id(20.99) == "evening" and SceneHudScript.period_id(21.0) == "night" and SceneHudScript.period_id(23.5) == "night", "night from 21:00")
	for id in ["day", "morning", "afternoon", "evening", "night"]:
		check(SceneText.UI.has(id), "the HUD has words for '%s'" % id)
	for id in SceneHudScript.NAV_IDS:
		check(SceneText.UI.has("nav_" + id), "the nav button '%s' has a label" % id)
	# the layout at every screen shape: on screen, nothing overlapping, the painting's safe zone left alone
	for sz in [Vector2(1280, 720), Vector2(1560, 720), Vector2(1024, 768), Vector2(1170, 540), Vector2(914, 514)]:
		var k: float = SceneHudScript.scale_for(sz)
		for lines in [1]:
			var lay: Dictionary = SceneHudScript.compute_layout(sz, k, SceneHudScript.NAV_IDS)
			var parts: Array = [["ring", lay["ring"]], ["bar 1", lay["bars"][0]], ["bar 2", lay["bars"][1]], ["objective", lay["objective"]], ["chip", lay["chip"]], ["pause", lay["pause"]], ["nav", lay["nav_plate"]]]
			var screen := Rect2(Vector2.ZERO, sz)
			for a in parts:
				check(screen.encloses(a[1]), "%s, %d line(s): %s is on screen" % [str(sz), lines, a[0]])
			var overlap := false
			for i in parts.size():
				for j in range(i + 1, parts.size()):
					if (parts[i][1] as Rect2).intersects(parts[j][1]):
						overlap = true
			check(not overlap, "%s, %d line(s): the HUD pieces do not overlap" % [str(sz), lines])
			var pr: Rect2 = SceneViewScript.fit_rect(sz, Scenes.PAINTING_ASPECT)
			var sx := T.arr("scene.safe_x")
			var sy := T.arr("scene.safe_y")
			var safe := Rect2(pr.position + pr.size * Vector2(float(sx[0]), float(sy[0])), pr.size * Vector2(float(sx[1]) - float(sx[0]), float(sy[1]) - float(sy[0]))).grow(-6.0 * k)
			var hit_safe := false
			for a in parts:
				if (a[1] as Rect2).intersects(safe):
					hit_safe = true
					print("  covers the safe zone at %s: %s" % [str(sz), a[0]])
			check(not hit_safe, "%s, %d line(s): the HUD leaves the painting's safe zone free" % [str(sz), lines])
			for n in lay["nav"]:
				check((n["rect"] as Rect2).size.x >= 72.0 * k - 0.01 and (n["rect"] as Rect2).size.y >= 56.0 * k, "%s: the nav button '%s' is big enough to hit" % [str(sz), n["id"]])
	# what is shown follows the story
	await _scene_ready_world()
	check(shud.nav_visible().is_empty(), "no nav button at the start")
	world.engine.add_item("matches")
	check(shud.nav_visible() == ["inventory"], "Inventory appears with the first item")
	world.engine.add_journal("coat")
	world.engine.set_flag("nav_shelter")
	world.engine.set_flag("nav_map")
	check(shud.nav_visible() == ["inventory", "map", "journal", "shelter"], "Journal with its first line, Map and Shelter by their flags, in a fixed order")
	check(shud.journal_unread(), "the Journal has a red dot until it is opened")
	world.enter_scene("dev_room")
	hud.set_revealed("bars", false)
	hud.set_revealed("mission", false)
	for i in 30:
		shud._process(0.1)
	check(shud.visible and shud._fade["cluster"] == 0.0 and shud._fade["objective"] == 0.0, "the portrait, bars and objectives wait for the story (progressive reveal)")
	check(shud._fade["nav"] == 1.0, "while the nav strip is up")
	hud.set_revealed("bars", true)
	hud.set_revealed("mission", true)
	for i in 30:
		shud._process(0.1)
	check(shud._fade["cluster"] == 1.0 and shud._fade["objective"] == 1.0, "and appear when revealed")
	# taps
	_step(0.1)
	check(shud.enabled and sview.enabled, "the HUD listens while the painting does")
	var pauses := [0]
	world.hosted = true
	world.pause_requested.connect(func(): pauses[0] += 1)
	var lay2: Dictionary = shud.layout()
	_hud_tap((lay2["pause"] as Rect2).get_center())
	check(pauses[0] == 1, "the Pause button asks the world to pause")
	for n in lay2["nav"]:
		if n["id"] == "map":
			_hud_tap((n["rect"] as Rect2).get_center())
	check(not hud.menu_open, "Map does nothing yet (a later phase)")
	for n in lay2["nav"]:
		if n["id"] == "inventory":
			_hud_tap((n["rect"] as Rect2).get_center())
	check(hud.menu_open and hud._menu_tab == "items", "Inventory opens the Items tab")
	hud.close_menu()
	for n in lay2["nav"]:
		if n["id"] == "journal":
			_hud_tap((n["rect"] as Rect2).get_center())
	check(hud.menu_open and hud._menu_tab == "journal", "Journal opens the Journal")
	shud._process(0.1)
	check(not shud.journal_unread(), "and the red dot is gone")
	hud.close_menu()
	world.engine.add_journal("towel")
	check(shud.journal_unread(), "a new Journal line brings the dot back")
	check(hud._role_at((lay2["pause"] as Rect2).get_center()) == "", "the walk HUD does not answer in Scene mode")
	_step(0.05)
	# a tap on the HUD is not also a tap on the painting
	var under := _chip_center("lamp")
	var before: bool = world.engine.has_flag(Scenes.seen_flag("dev_room", "lamp"))
	check(not before, "the lamp has not been examined yet")
	world.leave_scene()
	check(not shud.visible and not shud.enabled, "the HUD goes away with the painting")
	hud.set_revealed("bars", true)
	check(under != Vector2.ZERO, "(the chip positions were known)")

func _hud_tap(p: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p
	shud._input(ev)

func _chip_center(id: String) -> Vector2:
	for c in sview.layout():
		if str(c["id"]) == id:
			return (c["hit"] as Rect2).get_center()
	return Vector2.ZERO

# ---------------------------------------------------------------- zoom cards (phase S3)

const CARD_FIXTURE := {
	"cards": {"page": {"art": "x", "kind": "paper", "text_rect": [0.1, 0.1, 0.8, 0.5]}},
	"items": {"thing": "page"},
}

func _test_cards() -> void:
	# the data
	check(CardsScript.validate(CardsScript.shipped()).is_empty(), "the shipped cards are valid: %s" % str(CardsScript.validate(CardsScript.shipped())))
	var bad := {"cards": {"a": {"art": "", "ink": "red", "text_rect": [0.5, 0.5, 0.8, 0.8]}, "note": {"art": "q"}}, "items": {"x": "nope", "y": [{"when": ["wat:1"], "card": "a"}]}}
	var problems: Array = CardsScript.validate(bad)
	check(problems.size() >= 8, "bad cards are caught: %d problems" % problems.size())
	check(CardsScript.card("note").has("text_rect") and CardsScript.card("nope").is_empty(), "a card is found by id")
	check(CardsScript.art("CD-03") == null and CardsScript.art("") == null, "a card with no picture file has a placeholder (null art)")
	for id in SceneText.CARDS:
		check(not CardsScript.card(id).is_empty(), "the words for card '%s' have a card in turned_cards.json" % id)
	# which card an item opens
	var eng: EngineScript = EngineScript.new()
	check(CardsScript.for_item("matches", eng) == "matches" and CardsScript.for_item("note", eng) == "note", "matches and the note open their cards")
	check(CardsScript.for_item("watch", eng) == "watch" and CardsScript.for_item("nothing", eng) == "", "the watch opens its card; an unknown item has none")
	eng.set_flag("watch_broken")
	check(CardsScript.for_item("watch", eng) == "watch_broken", "a broken watch opens the broken watch's card")
	check(CardsScript.for_item("thing", eng, CARD_FIXTURE) == "page", "a plain string maps an item to a card")
	# the layout at every screen shape
	for sz in [Vector2(1280, 720), Vector2(1560, 720), Vector2(1024, 768), Vector2(1170, 540), Vector2(914, 514), Vector2(720, 1280)]:
		var k := clampf(minf(sz.x / 900.0, sz.y / 640.0), 0.6, 1.0)
		var lay: Dictionary = CardViewScript.compute_layout(sz, k)
		var frame: Rect2 = lay["frame"]
		var pic: Rect2 = lay["picture"]
		check(Rect2(Vector2.ZERO, sz).grow(0.01).encloses(frame), "%s: the card's frame is on screen" % str(sz))
		check(frame.encloses(pic) and frame.encloses(lay["title"]) and frame.encloses(lay["caption"]), "%s: the picture, title and caption are inside the frame" % str(sz))
		check(absf(pic.size.x - pic.size.y) < 0.01 and pic.size.x >= T.f("card.min_picture") * minf(k, 1.0) * 0.99, "%s: the picture is square and big enough (%d)" % [str(sz), int(pic.size.x)])
		check(not (lay["title"] as Rect2).intersects(pic) and not (lay["caption"] as Rect2).intersects(pic), "%s: the title and the caption do not cover the picture" % str(sz))
	# in the world
	await _scene_ready_world()
	world.engine.add_item("matches")
	world.engine.add_item("watch")
	check(not world.show_card("nope") and not cview.is_open, "an unknown card does not open")
	world.enter_scene("dev_room")
	_step(0.1)
	var pauses := [0]
	world.hosted = true
	world.pause_requested.connect(func(): pauses[0] += 1)
	_tap_chip("paper")
	check(cview.is_open and cview.card_id == "note" and world.engine.has_flag(CardsScript.seen_flag("note")), "a hotspot opens a zoom card and remembers it was seen")
	_step(0.1)
	check(world._frozen() and not sview.enabled and not shud.enabled, "the painting and the HUD stand still while a card is open")
	_tap_chip("lamp")
	check(not world.engine.has_flag(Scenes.seen_flag("dev_room", "lamp")), "a tap under the card does not examine the lamp")
	var hour0: float = world.clock.hour
	_step(2.0)
	check(is_equal_approx(world.clock.hour, hour0), "the clock stands still under a card")
	world.press_a()
	check(not cview.is_open and world.mode == "scene", "A closes the card and the painting is back")
	_step(0.1)
	check(sview.enabled, "and listens again")
	world.show_card("note")
	var esc := InputEventAction.new()
	esc.action = "tn_pause"
	esc.pressed = true
	world._unhandled_input(esc)
	check(not cview.is_open and pauses[0] == 0, "Esc closes the card first, it does not pause")
	world.show_card("note")
	world._request_pause()
	check(not cview.is_open and pauses[0] == 0, "Back / the Pause button also close the card first")
	world._request_pause()
	check(pauses[0] == 1, "and the next one pauses")
	world.show_card("matches")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = Vector2(10, 10)
	cview._gui_input(tap)
	check(not cview.is_open, "a tap anywhere closes the card")
	check(not Save.read().has("card") and not str(world.engine.to_dict()).contains("card_open"), "an open card is not part of the save")
	# from the Items tab
	world.leave_scene()
	hud.open_menu("items")
	var looks: Array = []
	for b in hud._menu_body.find_children("*", "Button", true, false):
		if (b as Button).text == SceneText.UI["items_look"]:
			looks.append(b)
	check(looks.size() == 2, "the Items tab has a 'Look closer' button for each of the 2 items with a card (%d)" % looks.size())
	(looks[0] as Button).pressed.emit()
	check(cview.is_open and cview.card_id == "matches" and hud.menu_open, "it opens the card over the menu")
	cview.close()
	world.engine.set_flag("watch_broken")
	hud._fill_menu()
	looks = []
	for b in hud._menu_body.find_children("*", "Button", true, false):
		if (b as Button).text == SceneText.UI["items_look"]:
			looks.append(b)
	(looks[1] as Button).pressed.emit()
	check(cview.card_id == "watch_broken", "a broken watch shows the broken watch's card")
	cview.close()
	hud.close_menu()

# ---------------------------------------------------------------- dialogue in scenes (phase S4)

func _dlg_fixture() -> Dictionary:
	var tid: String = str(Text.DIALOGUE.keys()[0])
	return {
		"fx_card": {"start": "n1", "nodes": {
			"n1": {"speaker": "tavernkeep", "mood": "afraid", "text": tid, "effects": ["card:matches"], "next": "n2"},
			"n2": {"speaker": "", "text": tid, "effects": ["scene:dev_hall"]},
		}},
		"fx_bad": {"start": "n1", "nodes": {"n1": {"speaker": "tavernkeep", "mood": "furious", "text": tid}}},
	}

func _test_scene_dialogue() -> void:
	var fx := _dlg_fixture()
	var only_good := {"fx_card": fx["fx_card"]}
	check(DialogueScript.validate(only_good).is_empty(), "scene: and card: effects and a mood are valid: %s" % str(DialogueScript.validate(only_good)))
	check(not DialogueScript.validate({"fx_bad": fx["fx_bad"]}).is_empty(), "an unknown mood is caught")
	# every scene: and card: effect in the shipped dialogues points at something that exists
	var dangling := 0
	var shipped := DialogueScript.shipped()
	for sid in shipped:
		for nid in shipped[sid]["nodes"]:
			var n: Dictionary = shipped[sid]["nodes"][nid]
			var effects: Array = (n.get("effects", []) as Array).duplicate()
			for o in (n.get("options", []) as Array):
				effects.append_array((o as Dictionary).get("effects", []))
			for e in effects:
				var s := str(e)
				if s.begins_with("scene:") and not Scenes.shipped().has(s.substr(6)):
					dangling += 1
				if s.begins_with("card:") and CardsScript.card(s.substr(5)).is_empty():
					dangling += 1
	check(dangling == 0, "no shipped dialogue points at a missing scene or card")
	var runner := DialogueScript.new(fx)
	runner.start("fx_card")
	check(str(runner.view().get("mood", "")) == "afraid", "the view carries the line's mood")
	check(runner.take_events() == ["card:matches"], "a card: effect is left for the world")
	runner.advance()
	check(str(runner.view().get("mood", "")) == "neutral", "a line with no mood is neutral")
	# the box in a painting: at every screen shape
	await _scene_ready_world()
	var long_text := "This is a rather long line of speech, long enough to wrap over two lines of the dialogue box at any size."
	for sz in [Vector2(1280, 720), Vector2(1560, 720), Vector2(1024, 768), Vector2(1170, 540), Vector2(914, 514)]:
		hud.size = sz
		hud.scene_mode = true
		hud.scene_rect = SceneViewScript.fit_rect(sz, Scenes.PAINTING_ASPECT)
		hud.show_dialogue({"kind": "line", "speaker": "tavernkeep", "speaker_name": "Tavernkeep", "text": long_text, "options": [], "selected": 0, "mood": "afraid"})
		var lay: Dictionary = hud._dlg_layout()
		var box: Rect2 = lay["box"]
		var bust: Rect2 = lay["bust"]
		var screen := Rect2(Vector2.ZERO, sz)
		check(screen.grow(0.01).encloses(box) and screen.grow(0.01).encloses(bust), "%s: the box and the bust are on screen" % str(sz))
		check(box.position.x >= hud.scene_rect.position.x and box.end.x <= hud.scene_rect.end.x + 0.01, "%s: the box stays inside the painting's width" % str(sz))
		check(bust.size.x > 0.0 and bust.end.x < box.position.x and not bust.intersects(box), "%s: the speaker's bust is on the left of the box" % str(sz))
		check(box.end.y <= sz.y and box.size.x >= 300.0, "%s: the box sits at the bottom and is wide enough (%d)" % [str(sz), int(box.size.x)])
		hud.show_dialogue({"kind": "choice", "speaker": "", "speaker_name": "", "text": "", "options": ["First choice", "Second choice"], "selected": 0})
		var lay2: Dictionary = hud._dlg_layout()
		check((lay2["bust"] as Rect2).size.x == 0.0, "%s: a thought has no bust" % str(sz))
		for row in (lay2["opts"] as Array):
			check((lay2["box"] as Rect2).encloses(row) and screen.grow(0.01).encloses(row), "%s: every choice row is in the box and on screen" % str(sz))
	hud.scene_mode = false
	hud.scene_rect = Rect2()
	hud.size = Vector2(1280, 720)
	hud.show_dialogue({"kind": "line", "speaker": "tavernkeep", "speaker_name": "Tavernkeep", "text": long_text, "options": [], "selected": 0})
	check((hud._dlg_layout()["bust"] as Rect2).size.x == 0.0, "walking: the box has no bust and keeps its place")
	hud.hide_dialogue()
	# a dialogue that shows a card and ends in a painting
	await _scene_ready_world()
	world.dlg.scenes = _dlg_fixture()
	world.hud.reveal("menu")
	check(world.start_dialogue("fx_card"), "the test dialogue starts")
	check(cview.is_open and cview.card_id == "matches", "its card: effect opens the card at once")
	world.press_a()
	check(not cview.is_open and world.dlg.node_id == "n1" and world.mode == "dialogue", "A closes the card first; the line has not gone on")
	hud.dialogue_skip()
	world.press_a()
	check(world.dlg.node_id == "n2", "then A goes on")
	hud.dialogue_skip()
	world.press_a()
	check(world.mode == "scene" and world.scene_id == "dev_hall" and sview.visible, "a scene: effect opens the painting when the dialogue is over")
	_step(0.1)
	check(hud.scene_rect == sview.painting_rect() and hud.scene_rect.size.x > 0.0, "the world tells the HUD where the painting is")
	# from a painting: the same
	world.leave_scene()
	world.enter_scene("dev_room")
	world.start_dialogue("fx_card")
	cview.close()
	for i in 2:
		hud.dialogue_skip()
		world.press_a()
	check(world.mode == "scene" and world.scene_id == "dev_hall", "started from a painting, it also ends in the painting it names")
	# the crossfade between paintings
	world.leave_scene()
	world.enter_scene("dev_room")
	check(sview._xfade == 0.0 and sview._fade == 1.0, "the first painting fades in from black")
	world.enter_scene("dev_hall")
	check(sview._xfade == 1.0 and sview._fade == 0.0 and sview._prev_art == "dev_room", "the next one crossfades from the one before")
	sview._process(0.2)
	check(sview._xfade < 1.0 and sview._xfade > 0.0, "the old painting is fading out")
	sview._process(1.0)
	check(sview._xfade == 0.0, "and is gone after half a second")
	world.leave_scene()
	check(sview._prev_art == "" and sview._prev_tex == null, "leaving clears it")
	world.dlg.scenes = DialogueScript.shipped()

# ---------------------------------------------------------------- the bar (scene 2)

## S5: the bedroom painting opens as you walk in (after checking your pockets) and does what the Walk room did.
func _test_bedroom() -> void:
	await _scene_ready_world()
	world._load_area("house")
	world.clock.hour = 9.0
	world.player.position = Vector2(200, 150)
	_step(0.1)
	check(world.mode == "play" and not world.in_scene, "before the pockets are checked the Walk bedroom is used")
	world.engine.set_flag("pockets")
	_step(0.1)
	check(world.mode == "scene" and world.scene_id == "bedroom" and sview.visible, "walking in the bedroom after the pockets opens its painting")
	check(sview._art_id == "SC-01" and sview._tex != null, "by day it is SC-01, a real picture")
	check(not sview.spots.any(func(h): return h["id"] == "matches"), "no matches on the nightstand before the coat says so")
	# the coat: the Walk scene, from the painting, with the zoom card when the stitches tear
	_tap_chip("coat")
	check(world.mode == "dialogue" and world.dlg.scene_id == "coat" and world.engine.journal.has("coat"), "the coat chip starts the coat scene")
	_dlg_lines()
	_pick("coat_opt_right")
	_dlg_lines()
	_pick("coat_opt_inner")
	_dlg_lines()
	_pick("coat_opt_tear")
	var guard := 0
	while world.mode == "dialogue" and not world._card_open() and guard < 20:
		hud.dialogue_skip()
		world.press_a()
		guard += 1
	check(world._card_open() and cview.card_id == "coat_pocket", "tearing the stitches shows the coat-pocket card")
	world.press_a()
	check(not world._card_open(), "A closes the card")
	_dlg_lines()
	_pick("coat_opt_done")
	_step(0.05)
	check(world.mode == "scene" and world.in_scene and world.engine.has_item("note"), "back on the painting with the note")
	# the matches now wait on the nightstand
	check(sview.spots.any(func(h): return h["id"] == "matches"), "the matches appear on the nightstand")
	_tap_chip("matches")
	check(world.engine.has_item("matches") and not sview.spots.any(func(h): return h["id"] == "matches"), "tapping them takes them, and the chip goes")
	_tap_chip("calendar")
	check(world.engine.journal.has("calendar") and hud.caption_text() == Text.CLUES["calendar"]["say"], "the calendar is the same clue as in Walk mode")
	_tap_chip("wardrobe")
	check(hud.caption_text() == Text.LOOKS["wardrobe"], "the wardrobe says its Walk-mode line")
	_tap_chip("bed")
	check(hud.caption_text() == SceneText.LOOKS["bed_pillow"], "the bed has its own line")
	# night: the other painting
	world.clock.hour = 21.0
	sview.refresh()
	check(sview._art_id == "SC-02", "at night it is SC-02")
	world.clock.hour = 3.0
	sview.refresh()
	check(sview._art_id == "SC-02", "and still SC-02 before dawn")
	world.clock.hour = 9.0
	sview.refresh()
	# Resume returns to the painting
	world.save_game()
	await _scene_resume_check("bedroom", "scene", "Resume returns to the bedroom painting")
	_step(0.05)                       # the world lets the painting listen
	# leaving by the door: the painting stays up while the screen goes black, then the landing
	_tap_chip("landing")
	check(world.mode == "transition" and world.in_scene, "the door fades out over the painting")
	_step(1.2)
	check(world.mode == "play" and not world.in_scene and world.area.id == "house", "then you walk again in the house")
	check(world.player.position.distance_to(world.area.spawns["bedroom_door"]) < 1.0, "on the landing outside the bedroom door")
	_step(0.3)
	check(world.mode == "play", "the landing does not reopen the painting")
	world.test_dir = Vector2.UP                  # back through the bedroom door
	var t_up := 0.0
	while world.mode == "play" and t_up < 4.0:
		_step(DT * 3.0)
		t_up += DT * 3.0
	world.test_dir = Vector2.ZERO
	check(world.mode == "scene" and world.scene_id == "bedroom" and world.player.position.y < 304.0, "walking back in through the door opens it again")
	_tap_chip("bathroom")
	_step(1.2)
	check(world.mode == "scene" and world.scene_id == "bathroom" and world.player.position.distance_to(world.area.spawns["bathroom_door"]) < 1.0, "the other door leads to the bathroom, a painting too")
	check(not Rect2(16, 16, 320, 288).has_point(world.area.spawns["bathroom_door"]) and not Rect2(16, 16, 320, 288).has_point(world.area.spawns["bedroom_door"]), "both doors land outside the bedroom")

## Steps until the world is in `want` (or `limit_s` passes) while walking `dir`.
func _walk_until(dir: Vector2, want: String, limit_s: float = 4.0) -> void:
	world.test_dir = dir
	var t := 0.0
	while world.mode != want and t < limit_s:
		_step(DT * 3.0)
		t += DT * 3.0
	world.test_dir = Vector2.ZERO

## The bathroom, the study and the hall as paintings (SC-03, SC-04, SC-05), and the doors between them.
func _test_house_rooms() -> void:
	await _scene_ready_world()
	world._load_area("house")
	world.engine.set_flag("pockets")
	world.clock.hour = 9.0
	world.player.position = world.area.spawns["bathroom_out"]
	_step(0.1)
	check(world.mode == "play" and not world.in_scene, "the landing stays a Walk room")
	# arriving through a door: the painting is up before the screen lights again
	world._go_area("house", "bathroom_door", false)
	_step(0.6)
	check(world.in_scene and world.scene_id == "bathroom" and world.mode == "transition" and hud.fade > 0.5, "arriving in the bathroom through a door: its painting is up while the screen is still dark")
	_step(0.7)
	check(world.mode == "scene" and sview._art_id == "SC-03" and sview._tex != null, "then the bathroom painting, SC-03")
	# the mirror from the painting: the close-up, then back to the painting
	_tap_chip("mirror")
	check(world.mode == "closeup", "the looking glass opens the mirror close-up")
	_step(0.7 + T.f("prologue.closeup_min_s"))
	world.press_a()
	_step(0.6)
	check(world.mode == "scene" and world.in_scene and world.scene_id == "bathroom", "closing it goes back to the painting")
	_tap_chip("towel")
	check(world.engine.journal.has("towel") and hud.caption_text() == Text.CLUES["towel"]["say"], "the towel is the same clue as in Walk mode")
	_tap_chip("landing")
	_step(1.2)
	check(world.mode == "play" and not world.in_scene and world.player.position.distance_to(world.area.spawns["bathroom_out"]) < 1.0, "the bathroom door leads to the landing")
	# the study: walk in from the landing
	world.player.position = world.area.spawns["study_out"]
	_walk_until(Vector2.DOWN, "scene")
	check(world.mode == "scene" and world.scene_id == "study" and sview._art_id == "SC-04", "walking into the study opens SC-04")
	_tap_chip("globe")
	check(hud.caption_text() == Text.LOOKS["globe"], "the globe says its Walk-mode line")
	_tap_chip("desk")
	check(hud.caption_text() == SceneText.LOOKS["study_desk"], "the desk has its own line (the painting has papers on it)")
	_tap_chip("landing")
	_step(1.2)
	check(world.mode == "play" and world.player.position.distance_to(world.area.spawns["study_out"]) < 1.0, "the study door leads to the landing")
	# downstairs into the hall painting
	world._interact({"id": "stairs_down"})
	_step(1.2)
	check(world.area.id == "house_down" and world.mode == "scene" and world.scene_id == "hall" and sview._art_id == "SC-05", "going downstairs lands in the hall painting")
	check(sview.spots.any(func(h): return h["id"] == "scarf"), "the scarf hangs on the coat stand")
	_tap_chip("scarf")
	check(world.engine.has_flag("scarf") and not sview.spots.any(func(h): return h["id"] == "scarf"), "taking the scarf: the chip goes")
	_tap_chip("cellar")
	check(world.engine.journal.has("cellar") and hud.caption_text() == Text.INNER["cellar_locked"], "the cellar door is locked, as in Walk mode")
	_tap_chip("front_door")
	check(world.mode == "scene" and hud.caption_text() == Text.INNER["door_coat"], "the front door says no until the coat (the Walk door's rules)")
	world.engine.add_journal("coat")
	world.engine.add_item("note")
	_tap_chip("front_door")
	_step(1.2)
	check(world.area.id == "street" and world.mode == "play" and not world.in_scene, "with the note it opens onto the street")
	world._interact({"id": "house_door"})
	_step(1.2)
	check(world.area.id == "house_down" and world.mode == "scene" and world.scene_id == "hall", "coming home through the front door: the hall painting")
	_tap_chip("kitchen")
	_step(1.2)
	check(world.mode == "play" and world.player.position.distance_to(world.area.spawns["kitchen_door"]) < 1.0, "the kitchen door leads to the Walk kitchen")
	# while the witness waits in the hall it stays a Walk room (he is not in the painting)
	world.engine.set_flag("witness_home")
	world.player.position = Vector2(300, 360)
	_step(0.1)
	check(world.mode == "play", "while the witness waits in the hall, the hall is the Walk room")
	world.engine.set_flag("matches_shown")
	_step(0.1)
	check(world.mode == "scene" and world.scene_id == "hall", "once he has gone it is the painting again")
	_tap_chip("stairs")
	_step(1.2)
	check(world.area.id == "house" and world.mode == "play" and world.player.position.distance_to(world.area.spawns["from_down"]) < 1.0, "the stairs lead up to the landing")
	for sp in ["bathroom_out", "study_out", "from_down", "bedroom_door"]:
		check(Scenes.zone_at(Scenes.shipped(), "house", world.area.spawns[sp], world._scene_holds) == "", "the landing spawn '%s' is outside every painted room" % sp)
	world._load_area("house_down")
	for sp in ["parlour_door", "kitchen_door"]:
		check(Scenes.zone_at(Scenes.shipped(), "house_down", world.area.spawns[sp], world._scene_holds) == "", "the spawn '%s' is outside the hall" % sp)

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
	var shop: Area = Area.make("cigar_shop") as Area
	check(shop.indoor and shop.in_shade(Vector2(100, 100)), "the cigar shop is indoors, all shade")
	for k in shop.spawns:
		check(shop.is_free(shop.spawns[k], 9.0), "shop spawn %s is free" % k)
	for it in shop.interacts:
		check(shop.is_free(it["pos"], 9.0) and Text.VERBS.has(it["verb"]) and _reachable(shop, shop.spawns["from_harbor"], it["pos"]), "shop interact %s is free, labelled and reachable" % it["id"])
	check(_reachable(shop, shop.spawns["from_harbor"], shop.spawns["storeroom"]), "the street door -> the storeroom is reachable (through the doorway)")
	check(shop.npcs.size() == 1 and shop.is_free(Vector2(float(shop.npcs[0]["pos"][0]), float(shop.npcs[0]["pos"][1])), 9.0), "the shopkeeper stands on free ground")
	check(shop.is_free(Vector2(306, 134), 9.0) and shop.is_free(Vector2(340, 150), 9.0), "the spots by the cot are free")
	var har: Area = Area.make("harbor") as Area
	check(har.is_free(har.spawns["from_shop"], 9.0), "leaving the shop you stand on the pavement")
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
	check(absf(hour_in - 20.5) < 0.05, "going in at 14:00 the day passes until the pub opens: it is 20:30 inside (%.2f)" % hour_in)
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
	check(world.engine.mission == "follower" and Text.INNER["door_followed"].contains("side lane"), "...and the refusal points at the side lane and sets the mission")
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
	check(world.mode == "transition" and world.engine.has_flag("witness_met") and world.engine.has_flag("witness_home") and world.engine.journal.has("witness") and world.engine.journal.has("same_note"), "'...It's really you.', what he saw, the same note, 'take me to your house'")
	check(world.engine.mission == "show_matches", "the mission is to go home with him")
	_step(1.6)
	check(world.area.id == "house_down" and world.mode == "play", "at the player's house")
	var wit: Node2D = null
	for n in world._npcs:
		if n.id == "witness":
			wit = n
	check(wit != null and wit.position.distance_to(Vector2(110, 372)) < 2.0, "the witness waits in the hall")
	world.player.position = Vector2(135, 350)
	_step(0.2)
	check(str(world._cand.get("id", "")) == "npc:witness", "A offers to talk to him")
	world.press_a()
	check(hud.caption_text() == Text.INNER["wit_wait"] and world.mode == "play", "he waits until you have looked at the coat again and brought the matches")
	# upstairs the coat ticks
	world.player.position = Vector2(472, 360)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "stairs_up", "A offers the stairs up")
	world.press_a()
	_step(1.5)
	check(world.area.id == "house", "upstairs")
	var upstairs_witness := false
	for n in world._npcs:
		if n.id == "witness":
			upstairs_witness = true
	check(not upstairs_witness and world._follower == null, "he waits downstairs")
	world.player.position = Vector2(241, 76)
	_step(0.1)
	world.press_a()
	_dlg_lines()
	check(world.dlg.view()["options"].has(Text.DIALOGUE["coat_opt_tick"]), "the coat ticks: a new thing to do")
	_pick("coat_opt_tick")
	_dlg_lines()
	check(world.engine.has_item("watch") and world.engine.has_flag("watch_found") and world.engine.journal.has("watch"), "the hidden pocket: a silver pocket watch")
	check(not world.dlg.view()["options"].has(Text.DIALOGUE["coat_opt_tick"]), "it is found once")
	_pick("coat_opt_done")
	world.engine.set_flag("matches_home")
	world._apply_item_state()
	world.player.position = Vector2(111, 66)
	_step(0.1)
	check(str(world._cand.get("id", "")) == "matches", "A offers the matches on the nightstand")
	world.press_a()
	check(world.engine.has_item("matches"), "the matches are in your pocket")
	_step(0.1)
	check(str(world._cand.get("id", "")) != "matches", "taken once")
	# back down: show him
	world.player.position = Vector2(472, 360)
	_step(0.1)
	world.press_a()
	_step(1.5)
	check(world.area.id == "house_down", "downstairs again")
	world.player.position = Vector2(135, 350)
	_step(0.2)
	world.press_a()
	check(world.mode == "dialogue" and world.dlg.view()["text"] == Text.DIALOGUE["w4m_here"], "you show him the matches")
	_dlg_lines()
	check(world.mode == "transition" and world.engine.has_flag("matches_shown") and world.engine.journal.has("cigar") and world.engine.mission == "cigar", "he knows the logo: the cigar shop by the harbor")
	check(world.engine.has_item("watch"), "and the watch stays hidden in your pocket")
	_step(1.6)
	check(world.area.id == "harbor" and world.mode == "play", "the harbor")
	check(absf(world.clock.hour - 22.5) < 0.05, "22:30")
	check(world.engine.has_flag("senses") and world._follower != null and world._fol_state == "companion", "he walks with you, and your senses are sharp")
	_step(0.5)
	var lamp: Dictionary = world._lamps[0]
	check(float(lamp["light"].energy) > float(lamp["base"]) * 2.0, "the gas lamps glare (%.2f against %.2f)" % [float(lamp["light"].energy), float(lamp["base"])])
	check(_walk_to(Vector2(400, 250), 30.0) and world.engine.has_flag("sense1"), "the first sense beat: the lamps")
	check(world._follower.position.distance_to(world.player.position) < 140.0, "he keeps close, at your side")
	check(_walk_to(Vector2(1100, 250), 40.0) and world.engine.has_flag("sense2") and world.engine.has_flag("sense3"), "the dog and the smells")
	check(_walk_to(Vector2(1340, 250), 20.0) and world.engine.has_flag("sense4"), "the thirst")
	check(_walk_to(Vector2(1521, 176), 20.0), "walked to the cigar shop")
	_step(0.2)
	check(str(world._cand.get("id", "")) == "cigar_door", "A offers the shop door")
	world.press_a()
	check(world.mode == "transition", "the shop door starts the fade")
	_step(1.6)
	check(world.area.id == "cigar_shop" and world.mode == "dialogue", "inside the cigar shop the scene starts by itself")
	var keeper: Node2D = null
	var friend: Node2D = null
	for n in world._npcs:
		if n.id == "shopkeeper":
			keeper = n
		if n.id == "witness":
			friend = n
	check(keeper != null and friend != null, "the shopkeeper behind the counter, the man from the bar beside you")
	check(world.dlg.view()["text"] == Text.DIALOGUE["shop_bell"], "a bell over the door")
	var hp_before: float = world.engine.hp
	_dlg_lines()
	check(world.mode == "transition" and world.engine.has_flag("blackout") and world.engine.hp < hp_before, "he gives you the water: it burns, you black out, and it hurts")
	_step(1.0)
	check(hud.fade >= 0.99 and world.area.id == "cigar_shop", "black")
	_step(1.5)
	check(hud.fade >= 0.99, "and staying black a while")
	_step(2.5)
	check(world.mode == "dialogue" and world.dlg.view()["text"] == Text.DIALOGUE["sto_wake"], "you wake in the storeroom")
	check(absf(world.clock.hour - 23.75) < 0.05, "it is nearly midnight")
	var friend_still := false
	for n in world._npcs:
		if n.id == "witness":
			friend_still = true
	check(not friend_still, "the man from the bar is gone")
	check(world.player.position.distance_to(world.area.spawns["storeroom"]) < 2.0, "on the cot at the back")
	_dlg_lines()
	check(world.mode == "play" and world.engine.has_flag("storeroom_scene") and world.engine.mission == "priest" and world.engine.journal.has("shop"), "'two or three days': the priest is the mission")
	keeper = null
	for n in world._npcs:
		if n.id == "shopkeeper":
			keeper = n
	check(keeper != null and keeper.position.distance_to(Vector2(306, 134)) < 2.0, "the shopkeeper sits by the cot")
	world.player.position = Vector2(340, 150)
	_step(0.2)
	check(str(world._cand.get("id", "")) == "npc:shopkeeper", "A offers to talk to him")
	world.engine.set_flag("watch_shown")          # (scene 6 starts from this talk; here we only check his plain line)
	world.press_a()
	check(hud.caption_text() == Text.NPC_LINES["shopkeeper"]["all"], "'Rest a little. Then we go to the priest.'")
	world.player.position = Vector2(280, 382)
	_step(0.2)
	check(str(world._cand.get("id", "")) == "cigar_exit", "A offers the street door")
	world.press_a()
	_step(1.6)
	check(world.area.id == "harbor" and world._follower == null, "back in the harbor, alone")
	check(Text.ITEMS["watch"]["variants"].size() == 1 and Text.SPEAKERS.has("witness"), "texts for the watch and the witness exist")
	await _street_world_after_bar()
	world.engine.set_flag("followed")
	world._on_area_ready()
	world.player.position = Vector2(600, 205)
	world.save_game()
	_new_world()
	await process_frame
	check(world.resume() and world.area.id == "street" and world._follower != null and world._fol_state == "tail", "Resume mid-chase puts him behind you again")
	check(world._follower.position.distance_to(world.player.position) > 200.0, "and he is not on top of you")

# ---------------------------------------------------------------- scene 6: the watch, the night walk, the forest, the arm, the house

func _walk_into_scene(dir: Vector2, limit_s: float = 12.0) -> void:
	world.test_dir = dir
	var t := 0.0
	while t < limit_s and world.mode == "play":
		_step(0.1)
		t += 0.1
	world.test_dir = Vector2.ZERO

func _test_scene6() -> void:
	var road: Area = Area.make("night_road") as Area
	check(not road.indoor and road.is_free(road.spawns["start"], 9.0), "the night road starts on free ground")
	check(_reachable(road, road.spawns["start"], Vector2(2566, 176)) and road.is_free(Vector2(2566, 176), 9.0), "the road leads to the vine house door")
	for it in road.interacts:
		check(Text.VERBS.has(it["verb"]), "road interact %s has a label" % it["id"])
	for tr in road.triggers:
		check(road.bounds.encloses(tr["rect"]) and _reachable(road, road.spawns["start"], (tr["rect"] as Rect2).get_center() + Vector2(0, 40)), "road trigger %s is on the way" % tr["id"])
	var poly: Array = T.arr("road.path")
	check(poly.size() >= 3 and _reachable(road, road.spawns["start"], Vector2(float(poly[poly.size() - 1][0]), float(poly[poly.size() - 1][1]))), "the leader's path ends on the walkable road")
	# the shop, after the storeroom: show him the watch
	_new_world()
	await process_frame
	world.begin_new()
	_step(1.0)
	for f in ["control", "mirror", "pockets", "bar_scene", "bar_thrown", "followed", "witness_met", "witness_home", "matches_shown", "shop_scene", "blackout", "witness_gone", "storeroom_scene", "senses"]:
		world.engine.set_flag(f)
	for it in ["note", "matches", "watch"]:
		world.engine.add_item(it)
	world.engine.dpad = true
	world.engine.show_bars = true
	world.engine.set_mission("priest")
	world.mode = "play"
	world._pro = "done"
	world.hud.fade = 0.0
	world._load_area("cigar_shop")
	world.clock.hour = 23.75
	world._on_area_ready()
	world.player.position = Vector2(340, 150)
	_step(0.2)
	check(str(world._cand.get("id", "")) == "npc:shopkeeper", "A offers to talk to the shopkeeper")
	var hp_before: float = world.engine.hp
	world.press_a()
	check(world.mode == "dialogue" and world.dlg.view()["text"] == Text.DIALOGUE["w6_show"], "you show him the watch")
	_dlg_lines()
	check(world.mode == "transition" and world.engine.has_flag("watch_broken") and world.engine.has_flag("owner_has_watch") and not world.engine.has_item("watch"), "it burned you, broke, and he keeps it")
	check(world.engine.hp < hp_before and world.engine.journal.has("watch_burn") and world.engine.mission == "to_priest", "your palm hurts; the mission is to follow him")
	_step(3.5)
	check(world.area.id == "night_road" and world.mode == "play", "out on the night road")
	check(int(world.clock.day) == 2 and world.clock.hour < 0.6, "it is past midnight: Saturday")
	_step(0.2)
	check(world.engine.day == 2, "the sun is one level worse from now on (day 2)")
	check(world._follower != null and world._fol_state == "leader" and world._owner_light != null, "the shopkeeper walks ahead with his oil lamp")
	var night_hour: float = world.clock.hour
	_step(20.0)
	check(is_equal_approx(world.clock.hour, night_hour), "on the night road time does not pass: dawn cannot come")
	check(Text.MISSIONS["priest"] == "Talk to the shopkeeper in the cigar shop", "the mission after the storeroom says where he is")
	# the priest, told on the way
	world.player.position = Vector2(110, 245)
	_walk_into_scene(Vector2.RIGHT)
	check(world.mode == "dialogue" and world.dlg.view()["text"] == Text.DIALOGUE["r1_o1"], "'He was a priest...'")
	_dlg_lines()
	check(world.mode == "play" and world.engine.journal.has("road"), "told, and in the Journal")
	check(_walk_to(Vector2(400, 245), 20.0), "walked on")
	_step(1.0)
	var ahead: float = world._follower.position.x - world.player.position.x
	check(ahead > 30.0 and ahead < 220.0, "he walks ahead of you (%.0f px)" % ahead)
	# the senses and the last lamp
	world.player.position = Vector2(480, 245)
	_walk_into_scene(Vector2.RIGHT, 0.8)
	check(world.engine.has_flag("walk2") and hud.caption_text() == Text.INNER["road_sens2"], "restless, a racing heart")
	world.player.position = Vector2(800, 245)
	_walk_into_scene(Vector2.RIGHT, 0.8)
	check(world.engine.has_flag("walk3"), "every latch and shutter")
	world.player.position = Vector2(990, 240)
	_walk_into_scene(Vector2.RIGHT, 0.8)
	check(world.engine.has_flag("gate") and hud.caption_text() == Text.INNER["road_gate"], "the last gas lamp, then the forest")
	# the branch
	world.player.position = Vector2(1650, 232)
	_step(0.3)
	_walk_into_scene(Vector2.RIGHT, 3.0)
	check(world.mode == "dialogue" and world.dlg.view()["text"] == Text.DIALOGUE["br_scrape"], "a branch scrapes his arm")
	_dlg_lines()
	check(world.engine.has_flag("hungry") and world.dlg.view()["options"].size() == 2, "you smell the blood, and you are hungry: two ways to hold on")
	_step(1.0)
	check(world._hunger > 0.5 and hud.throb > 0.05, "the hunger shows (%.2f)" % world._hunger)
	_pick("br_opt_see")
	_dlg_lines()
	check(world.mode == "play" and not world.engine.has_flag("hungry") and world.engine.has_flag("owner_behind") and world.engine.has_flag("arm_asked") and world.engine.journal.has("arm"), "he covers it with cloth and dirt; the hunger fades")
	_step(2.5)
	check(world._hunger < 0.05, "the hunger is gone (%.2f)" % world._hunger)
	check(world._fol_state == "behind", "from now on he walks behind you")
	check(_walk_to(Vector2(1900, 230), 20.0), "walked on through the forest")
	_step(1.5)
	check(world._follower.position.x < world.player.position.x - 80.0, "he stays behind, hiding his arm (%.0f px)" % (world.player.position.x - world._follower.position.x))
	# the house
	world.player.position = Vector2(2330, 230)
	_walk_into_scene(Vector2.RIGHT, 0.8)
	check(world.engine.has_flag("house") and hud.caption_text() == Text.INNER["road_house"], "a light between the trees")
	check(_walk_to(Vector2(2566, 182), 20.0), "walked to the door")
	_step(0.2)
	check(str(world._cand.get("id", "")) == "priest_door", "A offers the door")
	world.press_a()
	check(world.mode == "dialogue" and world.dlg.view()["text"] == Text.DIALOGUE["hs_see"], "a small house covered in vines")
	_dlg_lines()
	check(world.mode == "play" and world.engine.has_flag("house_reached") and world.engine.mission == "priest_in" and hud.banner_active(), "'We go in.' ... to be continued")
	world.press_a()
	check(hud.caption_text() == Text.INNER["house_tbc"], "the door says the rest is not written yet")
	# a game saved on the road comes back with him
	world.save_game()
	_new_world()
	await process_frame
	check(world.resume() and world.area.id == "night_road" and world._follower != null and world._fol_state == "behind", "Resume on the road puts the shopkeeper behind you again")

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
	check(world.engine.has_flag("matches_home") and world.engine.journal.has("matches") and not world.engine.has_item("matches"), "the right pocket has the matches, and they stay on the nightstand")
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
	check(world.engine.journal.size() == 4 and world.engine.items == ["note"], "the coat gives its things only once")

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
