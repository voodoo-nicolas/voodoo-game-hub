extends Node2D

## The Turned world: the house and Vellmoor's street, the player and villagers, the prologue
## beats, the sun and its shade, the alley's Sneak unlock, death and respawn, autosave.
## Lives in a SubViewport (turned_game.gd) so its darkness and camera stay off the Landing and
## the pause menu; the HUD (turned_hud.gd) is a sibling Control in the game, over the world.
##
## Modes: "prologue" (scripted waking, only A works), "play", "closeup" (the mirror), "transition"
## (fade between house and street), "dying" (the 2 s fade and respawn).
## Progressive rule (Turned CLAUDE.md): d-pad + A (prologue) -> sun and shade (Day 1 street) ->
## B sneak (alley). Nothing is shown before its moment.
## Headless tests drive it through press_a(), press_b(), test_dir and by calling _process().

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Art = preload("res://scripts/games/turned/turned_art.gd")
const Text = preload("res://scripts/games/turned/turned_text.gd")
const Area = preload("res://scripts/games/turned/turned_area.gd")
const AreaView = preload("res://scripts/games/turned/turned_area_view.gd")
const PlayerScript = preload("res://scripts/games/turned/turned_player.gd")
const NpcScript = preload("res://scripts/games/turned/turned_npc.gd")
const PropScript = preload("res://scripts/games/turned/turned_prop.gd")
const HudScript = preload("res://scripts/games/turned/turned_hud.gd")
const Engine_ = preload("res://scripts/games/turned/turned_engine.gd")
const SunClock = preload("res://scripts/games/turned/turned_sun_clock.gd")
const TSfx = preload("res://scripts/games/turned/turned_sfx.gd")
const Save = preload("res://scripts/games/turned/turned_save.gd")
const InputMapper = preload("res://scripts/games/turned/turned_input.gd")

signal pause_requested
## A stat for GameInfo: "died", "clue".
signal stat_event(kind: String)

var hosted := false
var kit_up := false           # the kit's Landing / pause menu is showing: the world stands still
var discard := false          # this world is being replaced: do not save it
var engine: Engine_ = Engine_.new()
var clock: SunClock = SunClock.new()
var hud: HudScript = null
var area: Area = null
var player: PlayerScript = null
var mode := "prologue"
var test_dir := Vector2.ZERO  # tests push the player with this

var _view_size := Vector2(1280, 720)
var _camera: Camera2D = null
var _canvas_mod: CanvasModulate = null
var _area_root: Node2D = null
var _entities: Node2D = null
var _ground: Node2D = null
var _overlay: Node2D = null
var _npcs: Array = []
var _lamps: Array = []         # {"light": PointLight2D, "base": float, "seed": float}
var _light_tex: GradientTexture2D = null
var _sun_mix := 0.0            # 0 shade ... 1 standing in the sun (eases)
var _t := 0.0
var _step_t := 0.0
var _burn_snd_t := 0.0
var _burn_amt := 0.0
var _cand: Dictionary = {}     # what A would do now
var _pending: Array = []       # [seconds_left, Callable] timed things (unpaused play only)

# prologue
var _pro := "black"
var _pt := 0.0
var _pro_flag := {}
# close-up
var _cu := "in"
var _cu_t := 0.0
# transition
var _tr_phase := 0
var _tr_t := 0.0
var _tr_area := ""
var _tr_spawn := ""
var _tr_save := false
# dying
var _die_t := 0.0
var _die_done := false
# throb
var _throb_t := -1.0

func _ready() -> void:
	InputMapper.ensure_actions()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_light_tex = GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_light_tex.gradient = g
	_light_tex.fill = GradientTexture2D.FILL_RADIAL
	_light_tex.fill_from = Vector2(0.5, 0.5)
	_light_tex.fill_to = Vector2(1.0, 0.5)
	_light_tex.width = 256
	_light_tex.height = 256
	_canvas_mod = CanvasModulate.new()
	add_child(_canvas_mod)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	player = PlayerScript.new()
	player.name = "Player"

func attach_hud(h: HudScript) -> void:
	hud = h
	hud.engine = engine
	hud.a_pressed.connect(press_a)
	hud.b_pressed.connect(press_b)
	hud.pause_pressed.connect(_request_pause)

## The SubViewport's size in canvas units: the camera zoom keeps ~360 world px visible vertically
## (landscape), or ~520 across when the screen is narrow (portrait).
func set_view_size(v: Vector2) -> void:
	_view_size = v
	_apply_zoom(1.0)

func _apply_zoom(pulse: float) -> void:
	if _camera == null:
		return
	var z := minf(_view_size.y / T.f("world.camera_view_height_px"), _view_size.x / T.f("world.camera_view_width_px")) * pulse
	_camera.zoom = Vector2(z, z)

# ---------------------------------------------------------------- starting

## A new game: the prologue in the bed.
func begin_new() -> void:
	engine.reset()
	clock = SunClock.new()
	hud.engine = engine
	_pro = "black"
	_pt = 0.0
	_pro_flag = {}
	mode = "prologue"
	_load_area("house")
	player.position = area.spawns["bed"]
	player.pose = "lying"
	player.sit_t = 0.0
	player.wipe_t = -1.0
	player.holding_head = false
	player.scarf = false
	player.sneak = false
	hud.set_revealed("dpad", false)
	hud.set_revealed("a", false)
	hud.set_revealed("b", false)
	hud.set_revealed("bars", false)
	hud.set_revealed("mission", false)
	hud.set_revealed("menu", false)
	hud.a_label = ""
	hud.fade = 1.0
	_snap_camera()

## Continues from the autosave. Returns false (and does nothing) if there is none.
func resume() -> bool:
	var d := Save.read()
	if d.is_empty():
		return false
	engine.from_dict(d["state"])
	clock.from_dict(d.get("clock", {}))
	hud.engine = engine
	if not engine.has_flag("control"):
		return false
	mode = "play"
	_pro = "done"
	_load_area(engine.area)
	player.position = engine.pos
	if not area.is_free(player.position, player.radius):
		var p: Variant = area.nearest_shade(player.position, 300.0, player.radius, 8.0)
		player.position = p if p != null else area.spawns.values()[0]
	player.pose = "stand"
	player.scarf = engine.has_flag("scarf")
	player.sneak = engine.sneaking
	_restore_hud()
	hud.fade = 0.0
	_snap_camera()
	return true

func _restore_hud() -> void:
	hud.set_revealed("dpad", engine.dpad)
	hud.set_revealed("a", true)
	hud.set_revealed("b", engine.has_button("b"))
	hud.set_revealed("bars", engine.show_bars)
	hud.set_revealed("mission", engine.has_flag("mirror"))
	hud.set_revealed("menu", not engine.journal.is_empty())
	player.show_rings = engine.has_button("b")

# ---------------------------------------------------------------- areas

func _load_area(name: String) -> void:
	if _area_root != null:
		if player.get_parent() != null:
			player.get_parent().remove_child(player)
		_area_root.queue_free()
		_area_root = null
	area = Area.make(name) as Area
	engine.area = name
	_npcs = []
	_lamps = []
	_area_root = Node2D.new()
	add_child(_area_root)
	_ground = AreaView.new()
	_ground.setup(area, "ground")
	_apply_item_state()
	_area_root.add_child(_ground)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	_area_root.add_child(_entities)
	for p in area.props:
		var node := PropScript.new()
		node.setup(p)
		_entities.add_child(node)
	for d in area.npcs:
		var n := NpcScript.new()
		n.setup(d)
		_npcs.append(n)
		_entities.add_child(n)
	_entities.add_child(player)
	_overlay = AreaView.new()
	_overlay.setup(area, "overlay")
	_area_root.add_child(_overlay)
	for lp in area.lamps:
		_add_light(lp, T.color("light.lamp_color"), T.f("light.lamp_energy"), T.f("light.lamp_radius_px"), true)
	for ls in area.light_spots:
		_add_light(ls["pos"], ls["color"], float(ls["energy"]), float(ls["radius"]), false)
	_camera.limit_left = int(area.bounds.position.x)
	_camera.limit_top = int(area.bounds.position.y)
	_camera.limit_right = int(area.bounds.end.x)
	_camera.limit_bottom = int(area.bounds.end.y)
	_canvas_mod.color = _ambient_color()

func _add_light(pos: Vector2, color: Color, energy: float, radius: float, flicker: bool) -> void:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.texture_scale = radius / 128.0
	l.color = color
	l.energy = energy
	l.position = pos
	_area_root.add_child(l)
	if flicker:
		_lamps.append({"light": l, "base": energy, "seed": pos.x * 0.37})

## Which clue items are taken (not drawn) and which still glint, from the engine's state.
func _apply_item_state() -> void:
	if _ground == null:
		return
	var hidden := {}
	var fresh := {}
	if engine.has_flag("scarf"):
		hidden["scarf"] = true
	if area.id == "house" and engine.has_flag("control"):
		for k in ["invitation", "coat", "note"]:
			if not (k in engine.journal):
				fresh[k] = true
		if not engine.has_flag("scarf") and engine.has_flag("mirror"):
			fresh["scarf"] = true
	_ground.taken = hidden
	_ground.glint = fresh
	_ground.refresh()

func _snap_camera() -> void:
	if _camera == null or player == null:
		return
	_camera.position = player.position + Vector2(0, -12)
	_camera.reset_smoothing()
	_apply_zoom(1.0)

func _ambient_color() -> Color:
	if area.indoor:
		return T.color("light.indoor_color")
	var shade := T.color("light.shade_color")
	var sun_c := T.color("light.sun_color")
	return shade.lerp(sun_c, _sun_mix * clock.intensity())

# ---------------------------------------------------------------- input

func _input_dir() -> Vector2:
	var d := Input.get_vector("tn_left", "tn_right", "tn_up", "tn_down")
	return d + test_dir

func _unhandled_input(event: InputEvent) -> void:
	if kit_up or discard:
		return
	if event.is_action_pressed("tn_pause"):
		if hud != null and hud.menu_open:
			hud.close_menu()
		else:
			_request_pause()
	elif event.is_action_pressed("tn_menu"):
		if hud != null:
			hud.toggle_menu()
	elif event.is_action_pressed("tn_a"):
		press_a()
	elif event.is_action_pressed("tn_b"):
		press_b()
	elif event.is_action_pressed("tn_debug_hurt") and OS.is_debug_build():
		engine.hp = minf(engine.hp, 3.0)

func _request_pause() -> void:
	if hosted:
		if not kit_up:
			pause_requested.emit()

func _frozen() -> bool:
	return kit_up or discard or hud == null or area == null or hud.menu_open

# ---------------------------------------------------------------- the frame

func _process(delta: float) -> void:
	if _frozen():
		return
	delta = minf(delta, 0.1)
	_t += delta
	clock.advance(delta)
	_run_pending(delta)
	match mode:
		"prologue": _tick_prologue(delta)
		"play": _tick_play(delta)
		"closeup": _tick_closeup(delta)
		"transition": _tick_transition(delta)
		"dying": _tick_dying(delta)
	_tick_visuals(delta)

func _after(seconds: float, fn: Callable) -> void:
	_pending.append([seconds, fn])

func _run_pending(delta: float) -> void:
	var keep: Array = []
	for item in _pending:
		item[0] -= delta
		if item[0] <= 0.0:
			(item[1] as Callable).call()
		else:
			keep.append(item)
	_pending = keep

func _tick_visuals(delta: float) -> void:
	player.sneak = engine.sneaking
	if player.show_rings:
		player.set_rings(engine.detect_radius_px(), engine.noise_radius_px(), delta, T.f("sneak.ring_speed"))
	# camera
	var target := player.position + Vector2(0, -12)
	_camera.position = _camera.position.lerp(target, 1.0 - exp(-T.f("world.camera_follow") * delta))
	# throb: the heartbeat pulse of the screen and the camera
	var pulse := 1.0
	if _throb_t >= 0.0:
		_throb_t += delta
		var len := T.f("ui.throb_s")
		var env := clampf(1.0 - _throb_t / len, 0.0, 1.0)
		var beat := 0.5 + 0.5 * sin(_throb_t * 9.0 - PI * 0.5)
		hud.throb = env * (0.35 + 0.65 * beat)
		pulse = 1.0 + 0.03 * env * beat
		if _throb_t >= len:
			_throb_t = -1.0
			hud.throb = 0.0
	_apply_zoom(pulse)
	# light colour: brighter standing in the sun, cooler in shade
	var in_sun := mode != "prologue" and not area.indoor and not area.in_shade(player.position)
	_sun_mix = move_toward(_sun_mix, 1.0 if in_sun else 0.0, T.f("light.mix_speed") * delta)
	_canvas_mod.color = _ambient_color()
	for l in _lamps:
		var li: PointLight2D = l["light"]
		li.energy = float(l["base"]) * (0.93 + 0.07 * sin(_t * 5.0 + float(l["seed"])) + 0.03 * sin(_t * 13.0 + float(l["seed"])))
	hud.burn = _burn_amt

# ---------------------------------------------------------------- prologue (story bible section 10)

func _set_pro(s: String) -> void:
	_pro = s
	_pt = 0.0

func _tick_prologue(delta: float) -> void:
	_pt += delta
	var P := "prologue."
	hud.a_active = false
	match _pro:
		"black":
			hud.fade = 1.0
			_heartbeat()
			if _pt >= T.f(P + "black_s"):
				_set_pro("fade_in")
		"fade_in":
			var len := T.f(P + "fade_in_s")
			hud.fade = clampf(1.0 - _pt / len, 0.0, 1.0)
			_heartbeat()
			if _pt >= len * 0.5 and not _pro_flag.has("thirsty"):
				_pro_flag["thirsty"] = true
				hud.say(Text.INNER["thirsty"])
			if _pt >= len:
				hud.fade = 0.0
				_set_pro("thirsty")
		"thirsty":
			_heartbeat()
			if _pt >= T.f(P + "thirsty_s"):
				hud.reveal("a")
				_set_pro("wait_sit")
		"wait_sit":
			_heartbeat()
			hud.a_label = "sit"
			hud.a_active = true
		"sit":
			var sit_s := T.f(P + "sit_s")
			player.sit_t = clampf(_pt / sit_s, 0.0, 1.0)
			player.holding_head = _pt >= sit_s * 0.45
			if _pt >= 0.3 and not _pro_flag.has("what"):
				_pro_flag["what"] = true
				hud.say(Text.INNER["what_happened"])
			if _pt >= sit_s + 0.5 and not _pro_flag.has("fever"):
				_pro_flag["fever"] = true
				hud.say(Text.INNER["fever"])
			if _pt >= sit_s + T.f(P + "sit_gap_s"):
				player.holding_head = false
				_set_pro("wait_wipe")
		"wait_wipe":
			hud.a_label = "wipe"
			hud.a_active = true
		"wipe":
			var wipe_s := T.f(P + "wipe_s")
			player.wipe_t = clampf(_pt / wipe_s, 0.0, 1.0)
			if _pt >= wipe_s:
				_set_pro("felt")
		"felt":
			if not _pro_flag.has("felt"):
				_pro_flag["felt"] = true
				_throb_t = 0.0
				TSfx.play(self, "pulse", -4.0)
				hud.say(Text.INNER["what_is_this"])
			if _pt >= T.f(P + "felt_s"):
				player.wipe_t = -1.0
				_set_pro("unlock")
		"unlock":
			if _pt >= T.f(P + "unlock_gap_s"):
				_prologue_done()

func _heartbeat() -> void:
	_step_t -= get_process_delta_time()
	if _step_t <= 0.0:
		_step_t = T.f("prologue.heartbeat_interval_s")
		TSfx.play(self, "heartbeat", -8.0)

func _prologue_done() -> void:
	player.position = area.spawns["bedside"]
	player.pose = "stand"
	player.face = Vector2.DOWN
	engine.dpad = true
	engine.set_flag("control")
	hud.reveal("dpad")
	hud.say(Text.INNER["hint_move"])
	_set_pro("done")
	mode = "play"
	_apply_item_state()

func _prologue_a() -> void:
	match _pro:
		"wait_sit":
			TSfx.play(self, "whoosh", -6.0)
			_set_pro("sit")
			hud.a_label = ""
		"wait_wipe":
			TSfx.play(self, "breath", -4.0)
			_set_pro("wipe")
			hud.a_label = ""

# ---------------------------------------------------------------- free play

func _tick_play(delta: float) -> void:
	var dir := _input_dir()
	var was := player.position
	player.walk(dir, delta, area, engine.speed(), _npcs)
	engine.pos = player.position
	_footsteps(delta, player.position.distance_to(was))
	for n in _npcs:
		n.tick(delta, player, _npcs)
	# sun
	var intensity := clock.intensity()
	var in_sun := not area.in_shade(player.position)
	var burning := in_sun and intensity > 0.0
	_burn_amt = move_toward(_burn_amt, (0.35 + 0.25 * sin(_t * 9.0)) * (0.5 + 0.5 * minf(1.0, engine.sun_dps())) if burning else 0.0, delta * 2.0)
	if burning:
		player.hurt = 0.55
		_burn_snd_t -= delta
		if _burn_snd_t <= 0.0:
			_burn_snd_t = T.f("sun.burn_sound_interval_s")
			TSfx.play(self, "burn", -8.0)
		if not engine.burned_this_visit:
			engine.burned_this_visit = true
			if not engine.has_flag("sun_said"):
				engine.set_flag("sun_said")
				hud.say(Text.INNER["sun_first"])
				_add_journal("sun")
	elif engine.burned_this_visit and not engine.has_flag("shade_said") and area.in_shade(player.position):
		engine.set_flag("shade_said")
		hud.say(Text.INNER["shade_first"])
	if engine.tick_health(delta, in_sun, intensity):
		_start_dying()
		return
	# triggers
	if area.trigger_at(player.position) == "alley" and not engine.has_flag("alley"):
		_enter_alley()
	# what A would do
	_cand = _nearest_interact()
	hud.a_label = str(_cand.get("verb", ""))
	hud.a_active = not _cand.is_empty()

func _footsteps(delta: float, moved: float) -> void:
	if moved <= 0.001:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = T.f("player.step_interval_s") * (1.6 if engine.sneaking else 1.0)
		TSfx.play(self, "step", T.f("player.sneak_step_volume_db") if engine.sneaking else T.f("player.step_volume_db"))

func _nearest_interact() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	var reach := T.f("interact.radius_px")
	for it in area.interacts:
		var iid: String = it["id"]
		if iid == "scarf" and engine.has_flag("scarf"):
			continue
		var d := player.position.distance_to(it["pos"])
		if d <= float(it["r"]) and d < best_d:
			best = it
			best_d = d
	for n in _npcs:
		var d2: float = player.position.distance_to(n.position)
		if d2 <= reach + 14.0 and d2 < best_d:
			best = {"id": "npc:" + n.id, "verb": "talk", "npc": n}
			best_d = d2
	return best

func press_a() -> void:
	if _frozen():
		return
	match mode:
		"prologue":
			_prologue_a()
		"closeup":
			if _cu == "hold" and _cu_t >= T.f("prologue.closeup_min_s"):
				_cu = "out"
				_cu_t = 0.0
		"play":
			if not _cand.is_empty():
				_interact(_cand)

func press_b() -> void:
	if _frozen() or mode != "play" or not engine.has_button("b"):
		return
	var on: bool = engine.toggle_sneak()
	TSfx.play(self, "whoosh", -10.0, 0.8 if on else 1.2)
	hud.say(Text.INNER["sneak_on"] if on else Text.INNER["sneak_off"], "inner", "", 1.2)

func _interact(c: Dictionary) -> void:
	var iid: String = c["id"]
	if iid.begins_with("npc:"):
		_talk(c["npc"])
		return
	match iid:
		"invitation", "coat", "note":
			_clue(iid)
		"mirror":
			_open_mirror()
		"scarf":
			engine.set_flag("scarf")
			player.scarf = true
			TSfx.play(self, "pickup", -4.0)
			hud.say(Text.INNER["scarf"])
			_apply_item_state()
		"front_door":
			if not engine.has_flag("mirror"):
				hud.say(Text.INNER["door_first"])
			else:
				TSfx.play(self, "door", -4.0)
				_go_area("street", "from_house", true)
		"house_door":
			TSfx.play(self, "door", -4.0)
			_go_area("house", "from_street", false)
		"alley_door":
			hud.say(Text.INNER["locked_end"])

func _clue(id: String) -> void:
	TSfx.play(self, "pickup", -4.0)
	hud.say(Text.CLUES[id]["say"], "inner", "", maxf(3.4, float(Text.CLUES[id]["say"].length()) * 0.055))
	if _add_journal(id):
		stat_event.emit("clue")

## Adds a Journal entry; the Menu button appears with the first one.
func _add_journal(id: String) -> bool:
	var added: bool = engine.add_journal(id)
	if added:
		hud.reveal("menu")
		_apply_item_state()
	return added

func _talk(n: Node2D) -> void:
	var lines: Dictionary = Text.NPC_LINES.get(n.id, {})
	var line: String = str(lines.get("all", lines.get("covered" if engine.has_flag("scarf") else "exposed", "")))
	n.talk_to(player.position)
	hud.say(line, "speech", Text.SPEAKERS.get(n.id, ""))
	if n.knows_player >= 2:
		_add_journal(str((n.data.get("clue_ids", ["watcher"]) as Array)[0]))

# ---------------------------------------------------------------- the mirror

func _open_mirror() -> void:
	mode = "closeup"
	_cu = "in"
	_cu_t = 0.0
	player.moving = false
	engine.set_flag("mirror")
	TSfx.play(self, "pulse", -8.0)
	_throb_t = 0.0
	_add_journal("neck")
	hud.say(Text.INNER["mirror"], "inner", "", 3.0)

func _tick_closeup(delta: float) -> void:
	_cu_t += delta
	match _cu:
		"in":
			hud.closeup = clampf(_cu_t / 0.6, 0.0, 1.0)
			if _cu_t >= 0.6:
				_cu = "hold"
				_cu_t = 0.0
		"hold":
			hud.closeup = 1.0
			hud.a_label = "ok"
			hud.a_active = true
		"out":
			hud.closeup = clampf(1.0 - _cu_t / 0.4, 0.0, 1.0)
			if _cu_t >= 0.4:
				hud.closeup = 0.0
				mode = "play"
				engine.set_mission("find_out")
				hud.reveal("mission")
				_apply_item_state()

# ---------------------------------------------------------------- house <-> street

func _go_area(name: String, spawn: String, autosave: bool) -> void:
	mode = "transition"
	_tr_phase = 0
	_tr_t = 0.0
	_tr_area = name
	_tr_spawn = spawn
	_tr_save = autosave
	player.moving = false

func _tick_transition(delta: float) -> void:
	_tr_t += delta
	var half := 0.5
	if _tr_phase == 0:
		hud.fade = clampf(_tr_t / half, 0.0, 1.0)
		if _tr_t >= half:
			_load_area(_tr_area)
			player.position = area.spawns[_tr_spawn]
			engine.pos = player.position
			if _tr_area == "street":
				# the sun is introduced here: the bars and the burning light
				engine.show_bars = true
				hud.reveal("bars")
				engine.burned_this_visit = false
			_snap_camera()
			_apply_item_state()
			_sun_mix = 0.0
			_tr_phase = 1
			_tr_t = 0.0
	else:
		hud.fade = clampf(1.0 - _tr_t / half, 0.0, 1.0)
		if _tr_t >= half:
			hud.fade = 0.0
			mode = "play"
			if _tr_save:
				save_game()

# ---------------------------------------------------------------- the alley: B unlocks

func _enter_alley() -> void:
	engine.set_flag("alley")
	if engine.unlock_button("b"):
		hud.reveal("b")
		hud.banner(Text.BANNER_NEW)
		TSfx.play(self, "unlock", -4.0)
		player.show_rings = true
		_add_journal("alley")
		_after(3.4, _say_alley_hint)
	save_game()

func _say_alley_hint() -> void:
	if mode == "play":
		hud.say(Text.INNER["alley_hint"])

# ---------------------------------------------------------------- death by sun

func _start_dying() -> void:
	mode = "dying"
	_die_t = 0.0
	_die_done = false
	player.moving = false
	_burn_amt = 0.0
	TSfx.play(self, "death", -2.0)
	hud.release_inputs()

func _tick_dying(delta: float) -> void:
	_die_t += delta
	var total := T.f("death.fade_s")
	var half := total * 0.5
	if _die_t < half:
		hud.fade = clampf(_die_t / half, 0.0, 1.0)
		return
	if not _die_done:
		_die_done = true
		_respawn()
	hud.fade = clampf(1.0 - (_die_t - half) / half, 0.0, 1.0)
	if _die_t >= total:
		hud.fade = 0.0
		mode = "play"

## Back in the same place, moved to the nearest shade within 3 m (else the nearest shade anywhere nearby).
func _respawn() -> void:
	var spot: Variant = area.nearest_shade(player.position, T.m(T.f("death.shade_radius_m")), player.radius, T.f("death.search_step_px"))
	if spot == null:
		spot = area.nearest_shade(player.position, T.m(T.f("death.fallback_shade_radius_m")), player.radius, T.f("death.search_step_px"))
	if spot != null:
		player.position = spot
	engine.apply_death()
	engine.pos = player.position
	player.hurt = 0.0
	_sun_mix = 0.0
	_snap_camera()
	stat_event.emit("died")
	hud.say(Text.INNER["died_first"] if engine.deaths <= 1 else Text.INNER["died_again"])

# ---------------------------------------------------------------- save

func save_game() -> void:
	if discard or mode == "transition" or mode == "dying" or not engine.has_flag("control"):
		return
	engine.pos = player.position
	Save.write(engine, clock)
