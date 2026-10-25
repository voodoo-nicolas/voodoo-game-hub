extends SceneTree

## A player bot: plays Turned from a new game to the vine-covered house the way a player would
## (walking with the d-pad, pressing A, tapping the chips of painted rooms, choosing dialogue options),
## and prints what it sees as it goes: the state after each stage and every line spoken ("the screenplay").
## It stops at the first place it cannot go on ("STUCK") so a soft lock is found, not guessed.
##   godot --headless --path . --script res://tools/playthrough_turned.gd
## Backs up and restores the player's real Turned save (like test_turned.gd).

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Save = preload("res://scripts/games/turned/turned_save.gd")
const Text = preload("res://scripts/games/turned/turned_text.gd")
const WorldScript = preload("res://scripts/games/turned/turned_world.gd")
const HudScript = preload("res://scripts/games/turned/turned_hud.gd")
const SceneViewScript = preload("res://scripts/games/turned/turned_scene_view.gd")
const SceneHudScript = preload("res://scripts/games/turned/turned_scene_hud.gd")
const CardViewScript = preload("res://scripts/games/turned/turned_card_view.gd")

const DT := 1.0 / 60.0

var world: Node2D
var hud: Control
var sview: Control
var shud: Control
var cview: Control
var stuck := false
var _lines := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	for i in 3:
		await process_frame
	var backup := ""
	if FileAccess.file_exists(Save.PATH):
		backup = FileAccess.get_file_as_string(Save.PATH)
	Save.clear()
	_mount()
	await process_frame
	_play()
	Save.clear()
	if backup != "":
		var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	print("\nPLAYTHROUGH ", "STOPPED (stuck)" if stuck else "REACHED THE END", ", %d spoken lines" % _lines)
	quit(1 if stuck else 0)

func _mount() -> void:
	hud = HudScript.new()
	root.add_child(hud)
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.size = Vector2(1280, 720)
	world = WorldScript.new()
	root.add_child(world)
	world.attach_hud(hud)
	world.set_view_size(Vector2(1280, 720))
	sview = SceneViewScript.new()
	root.add_child(sview)
	sview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sview.size = Vector2(1280, 720)
	world.attach_scene_view(sview)
	shud = SceneHudScript.new()
	root.add_child(shud)
	shud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shud.size = Vector2(1280, 720)
	world.attach_scene_hud(shud)
	cview = CardViewScript.new()
	root.add_child(cview)
	cview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cview.size = Vector2(1280, 720)
	world.attach_card_view(cview)

# ---------------------------------------------------------------- helpers

func note(msg: String) -> void:
	print("  ", msg)

func state(stage: String) -> void:
	var e = world.engine
	print("\n== %s | area=%s mode=%s scene=%s | mission=%s | %s day %d | hp %d/%d blood %d | items=%s | flags=%d journal=%d" % [
		stage, world.area.id, world.mode, world.scene_id, e.mission, world.clock.hour_text(), world.clock.day,
		int(e.hp), int(e.max_hp), int(e.blood), str(e.items), e.flags.size(), e.journal.size()])

func fail(msg: String) -> void:
	stuck = true
	print("\n!! STUCK: ", msg, "  [player at ", world.player.position, ", mode ", world.mode, ", caption '", hud.caption_text(), "']")
	state("at the stuck point")

func step(seconds: float) -> void:
	for i in int(seconds / DT):
		world._process(DT)
		hud._process(DT)

func until(cond: Callable, limit_s: float = 10.0) -> bool:
	var t := 0.0
	while t < limit_s:
		if cond.call():
			return true
		step(0.1)
		t += 0.1
	return cond.call()

func walk_to(target: Vector2, limit_s: float = 30.0) -> bool:
	var t := 0.0
	while t < limit_s:
		if world.mode != "play":
			world.test_dir = Vector2.ZERO
			return false
		var d: Vector2 = target - world.player.position
		if d.length() < 4.0:
			world.test_dir = Vector2.ZERO
			return true
		world.test_dir = d.normalized()
		step(0.03)
		t += 0.03
	world.test_dir = Vector2.ZERO
	return false

## Walks a list of points; false if one cannot be reached (or a scene started on the way).
func route(points: Array, limit_each: float = 30.0) -> bool:
	for p in points:
		if not walk_to(p, limit_each):
			return false
	return true

func chips() -> Array:
	var ids: Array = []
	for c in sview.layout():
		ids.append(str(c["id"]))
	return ids

func tap(id: String) -> bool:
	until(func(): return sview.enabled, 3.0)                # a painting takes taps once its fade-in is over
	for c in sview.layout():
		if str(c["id"]) == id:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = (c["hit"] as Rect2).get_center()
			sview._gui_input(ev)
			step(0.2)
			return true
	return false

## Reads the dialogue on screen like a player: prints each line, presses A (twice if the line was typing),
## stops at a choice or at the end. `picks`: option texts (ids in Text.DIALOGUE) to choose, in order.
func read(picks: Array = []) -> void:
	var guard := 0
	var pick_i := 0
	while world.mode == "dialogue" and guard < 80:
		guard += 1
		var v: Dictionary = world.dlg.view()
		if v.is_empty():
			break
		var who := str(v.get("speaker_name", ""))
		if str(v.get("kind", "")) == "choice":
			var opts: Array = v.get("options", [])
			print("    ", "(%s) %s" % ["choice", str(v.get("text", ""))])
			for o in opts:
				print("       - ", o)
			if pick_i < picks.size():
				var want: String = str(Text.DIALOGUE.get(picks[pick_i], picks[pick_i]))
				var idx := opts.find(want)
				if idx < 0:
					fail("the option '%s' is not offered" % picks[pick_i])
					return
				world.dlg.selected = idx
				hud.dialogue_skip()
				world.press_a()
				pick_i += 1
				_lines += 1
				continue
			return                                  # a choice we have no pick for: let the caller decide
		print("    ", ("%s: " % who) if who != "" else "(thought) ", str(v.get("text", "")))
		_lines += 1
		hud.dialogue_skip()
		world.press_a()
		step(0.05)
	step(0.1)

func press(label: String = "") -> void:
	if label != "":
		note("A: " + label)
	world.press_a()
	step(0.1)

func is_play() -> bool:
	return world.mode == "play"

# ---------------------------------------------------------------- the game

func _play() -> void:
	world.begin_new()
	state("new game")
	# --- the prologue, the way the owner told it
	step(T.f("prologue.black_s") + T.f("prologue.fade_in_s") + T.f("prologue.thirsty_s") + 0.5)
	press("sit up")
	step(T.f("prologue.sit_s") + T.f("prologue.sit_gap_s") + 0.5)
	press("wipe face")
	step(T.f("prologue.wipe_s") + T.f("prologue.felt_s") + T.f("prologue.unlock_gap_s") + 1.0)
	if not world.engine.dpad:
		return fail("the d-pad did not unlock")
	state("the prologue is over, free in the bedroom (walk mode)")
	# the bedroom is still a walk room: the front door will say no. Try it like a player would? No: go to the mirror.
	if not route([Vector2(135, 250), Vector2(135, 340), Vector2(430, 345), Vector2(430, 280), Vector2(444, 64)]):
		return fail("could not walk bedroom -> bathroom mirror (mode %s)" % world.mode)
	press("the mirror")
	step(1.8)
	press("close the close-up")
	step(0.8)
	state("after the mirror")
	step(10.0)
	if not world.engine.has_flag("thought"):
		return fail("the thoughts after the mirror never played")
	if not walk_to(Vector2(430, 280)):
		return fail("could not step away from the mirror (at %s, mode %s)" % [str(world.player.position), world.mode])
	step(0.2)
	press("check pockets")
	state("after checking the pockets (the painted rooms open)")
	if world.mode != "scene":
		note("note: no painting opened in the bathroom (mode %s)" % world.mode)
	else:
		note("in the bathroom painting, chips: " + str(chips()))
		if tap("towel"):
			note("tapped the towel: " + hud.caption_text())
		if not tap("landing"):
			return fail("no 'landing' chip in the bathroom painting")
		until(func(): return world.mode == "play", 4.0)
	state("on the landing")
	# --- the bedroom (coat, calendar)
	route([Vector2(160, 340), Vector2(160, 300)])          # (the painting opens as you walk in, which ends the walk)
	until(func(): return world.mode == "scene", 2.0)
	state("walked into the bedroom")
	if world.mode != "scene":
		return fail("the bedroom did not open as a painting")
	note("bedroom chips: " + str(chips()))
	if not tap("calendar"):
		return fail("no calendar chip in the bedroom")
	note("calendar: " + hud.caption_text())
	if not tap("coat"):
		return fail("no coat chip in the bedroom")
	if world.mode != "dialogue":
		return fail("tapping the coat did not start the coat scene (mode %s)" % world.mode)
	read(["coat_opt_right"])
	read(["coat_opt_inner"])
	read(["coat_opt_tear"])
	read(["coat_opt_done"])
	state("the coat is done")
	if not world.engine.has_item("note"):
		return fail("no note after the coat")
	if world.mode != "scene":
		note("note: after the coat scene the mode is %s (expected the bedroom painting)" % world.mode)
	note("chips now: " + str(chips()))
	step(0.2)
	if not tap("landing"):
		return fail("no way out of the bedroom painting")
	until(func(): return world.mode == "play", 4.0)
	# --- downstairs and out
	if not route([Vector2(300, 340), Vector2(476, 340), Vector2(476, 360)]):
		return fail("could not walk to the stairs")
	step(0.1)
	press("stairs down")
	until(func(): return world.mode in ["play", "scene"] and world.area.id == "house_down", 4.0)
	state("downstairs")
	if world.mode == "scene":
		note("hall chips: " + str(chips()))
		if not tap("front_door"):
			return fail("no front door chip in the hall painting")
	else:
		if not route([Vector2(120, 352), Vector2(44, 360)]):
			return fail("could not walk to the front door")
		press("front door")
	until(func(): return world.mode == "play" and world.area.id == "street", 5.0)
	state("in the street")
	if world.area.id != "street":
		return fail("the front door did not lead to the street")
	# --- to the pub
	if not route([Vector2(232, 235), Vector2(1069, 235), Vector2(1069, 176)], 40.0):
		return fail("could not walk to the pub door (mode %s, hp %d)" % [world.mode, int(world.engine.hp)])
	state("at the pub door")
	step(0.2)
	press("the pub door")
	until(func(): return world.mode == "dialogue", 5.0)
	read()
	until(func(): return world.mode == "play" and world.area.id == "street", 6.0)
	state("thrown out of the bar")
	# --- the follower
	step(3.0)
	if world._follower == null:
		return fail("nobody stepped out of the bar")
	note("caption: " + hud.caption_text())
	if not route([Vector2(1069, 250), Vector2(900, 250), Vector2(800, 250)], 40.0):
		return fail("could not walk west along the road")
	step(2.0)
	note("a pause: he stops too. caption: " + hud.caption_text() + " | follower state " + world._fol_state)
	step(1.5)
	note("caption after the pause: " + hud.caption_text())
	if not route([Vector2(735, 250), Vector2(735, 175), Vector2(722, 118)], 30.0):
		return fail("could not walk into the side lane")
	step(12.0)
	state("waiting in the lane")
	if str(world._cand.get("id", "")) != "grab_follower":
		return fail("the follower did not come to the corner (state %s)" % world._fol_state)
	press("grab him")
	read()
	until(func(): return world.mode == "play" and world.area.id == "house_down", 6.0)
	state("home with the witness")
	if world.area.id != "house_down":
		return fail("the scene did not take us home")
	note("what is the player's view: mode %s" % world.mode)
	# --- the coat again, the watch, the matches
	if not route([Vector2(120, 345), Vector2(476, 345), Vector2(476, 360)]):
		return fail("could not walk to the stairs at home")
	press("stairs up")
	until(func(): return world.mode in ["play", "scene"] and world.area.id == "house", 4.0)
	state("upstairs again")
	route([Vector2(440, 340), Vector2(300, 340), Vector2(160, 340), Vector2(160, 300)])
	until(func(): return world.mode == "scene", 2.0)
	if world.mode != "scene":
		return fail("the bedroom painting did not open again")
	note("bedroom chips: " + str(chips()))
	for c in sview.layout():
		if str(c["id"]) in ["coat", "matches", "calendar"]:
			note("chip %s hit %s" % [str(c["id"]), str(c["hit"])])
	world.engine.flags.erase("seen:bedroom:coat")
	if not tap("coat"):
		return fail("no coat chip the second time")
	note("after tapping the coat again: mode %s, dialogue active %s, caption '%s', card open %s" % [world.mode, str(world.dlg.active), hud.caption_text(), str(world._card_open())])
	if world.mode != "dialogue":
		var r: bool = world.start_dialogue("coat")
		note("start_dialogue('coat') directly -> %s, mode %s, dlg.active %s, node %s" % [str(r), world.mode, str(world.dlg.active), world.dlg.node_id])
		var hs: Dictionary = {}
		for h in sview.spots:
			if str(h.get("id", "")) == "coat":
				hs = h
		note("coat hotspot: " + str(hs))
	read(["coat_opt_tick"])
	read(["coat_opt_done"])
	if not world.engine.has_item("watch"):
		return fail("no watch after following the ticking")
	if not tap("matches"):
		return fail("no matches chip on the nightstand")
	note("matches: " + hud.caption_text())
	if not tap("landing"):
		return fail("no way out of the bedroom painting the second time")
	until(func(): return world.mode == "play", 4.0)
	if not route([Vector2(300, 340), Vector2(476, 340), Vector2(476, 360)]):
		return fail("could not walk to the stairs")
	press("stairs down")
	until(func(): return world.area.id == "house_down" and world.mode in ["play", "scene"], 4.0)
	state("downstairs, to show the witness")
	if world.mode == "scene":
		return fail("the hall opened as a painting while the witness waits (walk_zone not_while failed)")
	if not walk_to(Vector2(135, 350)):
		return fail("could not walk to the witness")
	step(0.2)
	press("talk to the witness")
	if world.mode != "dialogue":
		return fail("the witness did not start the matches scene (caption: %s)" % hud.caption_text())
	read()
	until(func(): return world.mode == "play" and world.area.id == "harbor", 6.0)
	state("in the harbor")
	if world.area.id != "harbor":
		return fail("did not reach the harbor")
	if not route([Vector2(400, 250), Vector2(1100, 250), Vector2(1340, 250), Vector2(1521, 176)], 60.0):
		return fail("could not walk the harbor to the shop (mode %s)" % world.mode)
	step(0.2)
	press("the shop door")
	until(func(): return world.mode == "dialogue", 5.0)
	read()
	until(func(): return world.mode == "dialogue", 8.0)
	state("the storeroom")
	read()
	until(func(): return world.mode == "play", 3.0)
	state("after the storeroom")
	if str(world._cand.get("id", "")) == "":
		world.player.position = Vector2(340, 150)
		step(0.3)
	note("candidate: " + str(world._cand))
	press("talk to the shopkeeper")
	if world.mode != "dialogue":
		return fail("the shopkeeper did not start the watch scene (caption: %s)" % hud.caption_text())
	read()
	until(func(): return world.mode == "play" and world.area.id == "night_road", 8.0)
	state("on the night road")
	if world.area.id != "night_road":
		return fail("did not reach the night road")
	var gaps := 0
	for stop in [Vector2(300, 245), Vector2(560, 245), Vector2(860, 245), Vector2(1100, 235), Vector2(1660, 232)]:
		walk_to(stop, 40.0)
		if world.mode == "dialogue":
			read()
		step(0.3)
		note("at %s: caption '%s'" % [str(stop), hud.caption_text()])
	world.test_dir = Vector2.RIGHT                          # on along the path: the branch is at x 1700
	until(func(): return world.mode == "dialogue", 4.0)
	world.test_dir = Vector2.ZERO
	state("the branch")
	read(["br_opt_see"])
	state("after the branch")
	if not route([Vector2(2330, 230), Vector2(2566, 182)], 60.0):
		return fail("could not walk to the house door")
	press("the house door")
	read()
	state("the end of what is built")
	print("")
