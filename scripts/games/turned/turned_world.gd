extends Node2D

## The Turned world: the house and Vellmoor's street, the player and villagers, the prologue
## beats, the sun and its shade, the alley's Sneak unlock, death and respawn, autosave.
## Lives in a SubViewport (turned_game.gd) so its darkness and camera stay off the Landing and
## the pause menu; the HUD (turned_hud.gd) is a sibling Control in the game, over the world.
##
## Modes: "prologue" (scripted waking, only A works), "play", "closeup" (the mirror), "transition"
## (fade between house and street), "dying" (the 2 s fade and respawn), "dialogue" (a scene from
## turned_dialogues.json is on screen: the clock and the player stand still; A, up/down and taps work).
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
const DialogueScript = preload("res://scripts/games/turned/turned_dialogue.gd")
const Scenes = preload("res://scripts/games/turned/turned_scenes.gd")
const SceneText = preload("res://scripts/games/turned/turned_scene_text.gd")
const Cards = preload("res://scripts/games/turned/turned_cards.gd")

signal pause_requested
## A stat for GameInfo: "died", "clue".
signal stat_event(kind: String)

var hosted := false
var kit_up := false           # the kit's Landing / pause menu is showing: the world stands still
var discard := false          # this world is being replaced: do not save it
var engine: Engine_ = Engine_.new()
var clock: SunClock = SunClock.new()
var dlg: DialogueScript = DialogueScript.new()
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
var _decor: Node2D = null
var _sun_light: DirectionalLight2D = null
var _moon_light: DirectionalLight2D = null
var _glow: AreaView = null      # the additive glow layer (lit windows at night)
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
var _tr_hour := -1.0           # a story hour to jump to while the screen is black (-1 = none)
var _tr_hold := 0.0            # seconds to stay black after the new area is loaded (a blackout)
# the man who follows you (scene 3)
var _follower: Node2D = null
var _fol_state := "off"        # off, exit, wait_far, tail, lane, mouth, flee, witness
var _fol_trail: Array = []     # where the player has walked (the man walks the same way, lagging behind)
var _fol_t := 0.0
var _fol_step_t := 0.0
var _fol_steps := 0
var _fol_still := 0.0
var _fol_stuck := 0.0
var _owner_light: PointLight2D = null   # the shopkeeper's oil lamp on the night road
var _hunger := 0.0             # 0..1, eased towards the flag "hungry" (the blood on the forest path)
var _hun_t := 0.0
var _watch_t := 0.0            # the watch's tick
var _bark_t := 6.0             # the next far-off dog
var _fol_last_pp := Vector2.ZERO
# dying
var _die_t := 0.0
var _die_done := false
# throb
var _throb_t := -1.0
# dialogue
var _dlg_dir_prev := 0
var _dlg_area := ""            # an "area:" effect waits until the scene is over
var _dlg_hour := -1.0          # so does an "hour:" one (-1 = none)
var _dlg_hold := 0.0           # ... and "hold:" (seconds the screen stays black on the way)
var _dlg_journal := 0
var _dlg_items := 0
var _dlg_scene := ""           # a "scene:" effect waits until the dialogue is over
var _dlg_back := "play"        # the mode a dialogue returns to ("scene" when it started from a painting)
# scene mode (docs/turned/SCENE_MODE_PLAN.md)
var in_scene := false          # a painting is on screen (mode "scene", or a dialogue started from it)
var scene_id := ""
var scene_view: Control = null
var scene_hud: Control = null     # Scene mode's interface (turned_scene_hud.gd)
var card_view: Control = null     # a zoom card (turned_card_view.gd): the world stands still while one is open
var scene_data: Dictionary = {}   # tests put their own scenes here; empty = turned_scenes.json

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
	hud.dialogue_option.connect(_on_dialogue_option)
	hud.card_requested.connect(show_card)

## Scene mode's screen (turned_scene_view.gd), shown over the world while a painting is up.
func attach_scene_view(v: Control) -> void:
	scene_view = v
	v.holds = Callable(self, "_scene_holds")
	v.seen = Callable(self, "_scene_seen")
	v.hotspot_activated.connect(_on_hotspot)

## The zoom card's screen (turned_card_view.gd).
func attach_card_view(v: Control) -> void:
	card_view = v
	v.closed.connect(_on_card_closed)

func _card_open() -> bool:
	return card_view != null and card_view.is_open

## Opens a zoom card (turned_cards.json) over everything; the world stands still until it is closed
## (a tap, A or Esc). False if there is no such card.
func show_card(id: String) -> bool:
	if card_view == null or discard or not card_view.open(id):
		return false
	engine.set_flag(Cards.seen_flag(id))
	if hud != null:
		hud.release_inputs()
	return true

func _on_card_closed(_id: String) -> void:
	if in_scene and scene_view != null:
		scene_view.refresh()

## Scene mode's interface: portrait, bars, objectives, day chip, nav strip (turned_scene_hud.gd).
func attach_scene_hud(h: Control) -> void:
	scene_hud = h
	h.world = self
	h.pause_pressed.connect(_request_pause)
	h.nav_pressed.connect(_on_scene_nav)

## A nav button of the Scene HUD. Inventory and Journal open the menu; Map, Shelter and Contacts
## are for later phases (they only show once a flag `nav_<id>` is set, and do nothing yet).
func _on_scene_nav(id: String) -> void:
	match id:
		"inventory":
			hud.open_menu("items")
		"journal":
			hud.open_menu("journal")

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
	dlg.stop()
	_dlg_back = "play"
	leave_scene()
	hud.hide_dialogue()
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
	dlg.engine = engine
	dlg.clock = clock
	dlg.from_dict(d.get("dialogue", {}))
	if dlg.active:
		mode = "dialogue"
		_dlg_journal = engine.journal.size()
		_dlg_items = engine.items.size()
	if engine.has_flag("mirror"):
		engine.set_flag("thought_started")
		engine.set_flag("thought")
	_load_area(engine.area)
	player.position = engine.pos
	if not area.is_free(player.position, player.radius):
		var p: Variant = area.nearest_shade(player.position, 300.0, player.radius, 8.0)
		player.position = p if p != null else area.spawns.values()[0]
	player.pose = "stand"
	player.scarf = engine.has_flag("scarf")
	player.sneak = engine.sneaking
	_restore_hud()
	if dlg.active:
		hud.show_dialogue(dlg.view())
	hud.fade = 0.0
	_snap_camera()
	_on_area_ready()
	var sid := str(d.get("scene", ""))
	if sid != "" and scene_view != null and _scenes().has(sid):
		var back := mode                    # "play", or "dialogue" when a scene was on the painting
		mode = "play"
		if enter_scene(sid) and back == "dialogue":
			_dlg_back = "scene"
			mode = "dialogue"
		elif not in_scene:
			mode = back
	return true

func _restore_hud() -> void:
	hud.set_revealed("dpad", engine.dpad)
	hud.set_revealed("a", true)
	hud.set_revealed("b", engine.has_button("b"))
	hud.set_revealed("bars", engine.show_bars)
	hud.set_revealed("mission", engine.has_flag("mirror"))
	hud.set_revealed("menu", not engine.journal.is_empty() or not engine.items.is_empty())
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
	_follower = null
	_owner_light = null
	_fol_state = "off"
	_area_root = Node2D.new()
	add_child(_area_root)
	_ground = AreaView.new()
	_ground.setup(area, "ground")
	_area_root.add_child(_ground)
	_decor = AreaView.new()
	_decor.setup(area, "decor")
	_area_root.add_child(_decor)
	_apply_item_state()
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
	_glow = AreaView.new()
	_glow.setup(area, "glow")
	_area_root.add_child(_glow)
	for lp in area.lamps:
		_add_light(lp, T.color("light.lamp_color"), T.f("light.lamp_energy"), T.f("light.lamp_radius_px"), true)
	for ls in area.light_spots:
		_add_light(ls["pos"], ls["color"], float(ls["energy"]), float(ls["radius"]), false)
	if not area.indoor and T.f("light.sun_energy") > 0.0:
		# the sun: a directional light, so the cobbles and walls show relief by day
		_sun_light = DirectionalLight2D.new()
		_sun_light.color = T.color("light.sun_color")
		_sun_light.rotation = deg_to_rad(T.f("light.sun_angle_deg"))
		_sun_light.height = T.f("light.sun_height")
		_sun_light.energy = T.f("light.sun_energy") * clock.intensity()
		_area_root.add_child(_sun_light)
		# the moon: a cool directional light that crosses the sky between moonrise and moonset
		_moon_light = DirectionalLight2D.new()
		_moon_light.color = T.color("moon.color")
		_moon_light.height = T.f("moon.height")
		_area_root.add_child(_moon_light)
		_update_sky()
	else:
		_sun_light = null
		_moon_light = null
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
	l.height = T.f("light.lamp_height_px")
	l.position = pos
	_area_root.add_child(l)
	if flicker:
		_lamps.append({"light": l, "base": energy, "seed": pos.x * 0.37})

## Which clue items are taken (not drawn) and which still glint, from the engine's state.
func _apply_item_state() -> void:
	if _decor == null:
		return
	var hidden := {}
	var fresh := {}
	if engine.has_flag("scarf"):
		hidden["scarf"] = true
	if not engine.has_flag("matches_home") or engine.has_item("matches"):
		hidden["matches"] = true
	if area.indoor and engine.has_flag("control"):
		for k in ["coat", "calendar", "towel"]:
			if not (k in engine.journal):
				fresh[k] = true
		if engine.journal.has("coat") and not engine.has_item("note"):
			fresh["coat"] = true                 # still something in the coat
		if engine.has_flag("witness_home") and not engine.has_flag("watch_found"):
			fresh["coat"] = true                 # the coat is ticking
		if engine.has_flag("matches_home") and not engine.has_item("matches") and engine.has_flag("witness_home"):
			fresh["matches"] = true
		if not engine.has_flag("scarf") and engine.has_flag("mirror"):
			fresh["scarf"] = true
	_decor.taken = hidden
	_decor.glint = fresh
	_decor.refresh()

func _snap_camera() -> void:
	if _camera == null or player == null:
		return
	_camera.position = player.position + Vector2(0, -12)
	_camera.reset_smoothing()
	_apply_zoom(1.0)

## The scene's overall colour (CanvasModulate): day = cool shade or bright sun, night = dark blue
## that the moon lifts, with a warm tint at dusk and dawn. Interiors only dim a little at night.
func _ambient_color() -> Color:
	var day_i := clock.intensity()
	if area.indoor:
		return T.color("moon.indoor_night_color").lerp(T.color("light.indoor_color"), day_i)
	var shade := T.color("light.shade_color")
	var sun_c := T.color("light.sun_color")
	var day_c := shade.lerp(sun_c, _sun_mix * day_i)
	var night_c := T.color("moon.night_ambient_color").lerp(T.color("moon.moon_ambient_color"), clock.moon_level())
	var c := night_c.lerp(day_c, day_i)
	var dusk := 1.0 - absf(2.0 * day_i - 1.0)      # 0 in full day or dark, 1 halfway through sunrise/sunset
	return c.lerp(T.color("moon.dusk_color"), dusk * T.f("moon.dusk_mix"))

## Sun and moon lights follow the clock (the sun fades with day_i, the moon sweeps across).
func _update_sky() -> void:
	# a light with no energy is hidden: every light costs a pass on a weak phone
	if _sun_light != null:
		_sun_light.energy = T.f("light.sun_energy") * clock.intensity()
		_sun_light.visible = _sun_light.energy > 0.001
	if _moon_light != null:
		_moon_light.energy = T.f("moon.energy") * clock.moon_level()
		_moon_light.visible = _moon_light.energy > 0.001
		_moon_light.rotation = deg_to_rad(lerpf(T.f("moon.angle_from_deg"), T.f("moon.angle_to_deg"), clock.moon_progress()))

# ---------------------------------------------------------------- input

func _input_dir() -> Vector2:
	var d := Input.get_vector("tn_left", "tn_right", "tn_up", "tn_down")
	return d + test_dir

func _unhandled_input(event: InputEvent) -> void:
	if kit_up or discard:
		return
	if event.is_action_pressed("tn_pause"):
		if _card_open():
			card_view.close()
		elif hud != null and hud.menu_open:
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
	elif event.is_action_pressed("tn_debug_time") and OS.is_debug_build():
		clock.advance_hours(1.0)
	elif event.is_action_pressed("tn_debug_dialogue") and OS.is_debug_build():
		start_dialogue("dev_demo")
	elif event.is_action_pressed("tn_debug_scene") and OS.is_debug_build():
		enter_scene("dev_room")

func _request_pause() -> void:
	if _card_open():
		card_view.close()                  # Back / Pause first closes the card
		return
	if hosted:
		if not kit_up:
			pause_requested.emit()

func _frozen() -> bool:
	return kit_up or discard or hud == null or area == null or hud.menu_open or _card_open()

# ---------------------------------------------------------------- the frame

func _process(delta: float) -> void:
	if in_scene and scene_view != null:
		scene_view.enabled = mode == "scene" and not (kit_up or discard or hud == null or hud.menu_open or _card_open())
		if scene_hud != null:
			scene_hud.visible = true
			scene_hud.enabled = scene_view.enabled
	if _frozen():
		return
	delta = minf(delta, 0.1)
	_t += delta
	if mode == "play" and (not area.indoor or T.b("sun.run_indoors")) and not _night_is_held():
		clock.advance(delta)
	_run_pending(delta)
	match mode:
		"prologue": _tick_prologue(delta)
		"play": _tick_play(delta)
		"closeup": _tick_closeup(delta)
		"transition": _tick_transition(delta)
		"dying": _tick_dying(delta)
		"dialogue": _tick_dialogue(delta)
		"scene": player.moving = false
	_tick_visuals(delta)

## The story's night: on the night road, and from the house door on (until the priest's house is
## written), time does not pass, so dawn cannot come and burn you while you read or wait.
func _night_is_held() -> bool:
	return area.id == "night_road" or engine.has_flag("house_reached")

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
	_hunger = move_toward(_hunger, 1.0 if engine.has_flag("hungry") else 0.0, delta * 1.5)
	if _hunger > 0.01:
		hud.throb = maxf(hud.throb, _hunger * (0.4 + 0.25 * sin(_t * 7.0)))
		_hun_t -= delta
		if _hun_t <= 0.0:
			_hun_t = 0.8
			TSfx.play(self, "pulse", -10.0)
	# light colour: brighter standing in the sun, cooler in shade
	var in_sun := mode != "prologue" and not area.indoor and not area.in_shade(player.position)
	_sun_mix = move_toward(_sun_mix, 1.0 if in_sun else 0.0, T.f("light.mix_speed") * delta)
	_canvas_mod.color = _ambient_color()
	_update_sky()
	var lamp_boost := 1.0 + T.f("moon.lamp_night_boost") * clock.night()
	var glare := engine.has_flag("senses") and not area.indoor
	if glare:
		lamp_boost *= T.f("senses.lamp_mult")
	if _glow != null:
		_glow.night = clock.night()
		_glow.overbright = T.f("senses.glow_mult") if glare else 1.0
	hud.clock_text = clock.hour_text()
	hud.clock_sun = clock.intensity()
	hud.clock_moon = clock.moon_level()
	for l in _lamps:
		var li: PointLight2D = l["light"]
		li.energy = lamp_boost * float(l["base"]) * (0.93 + 0.07 * sin(_t * 5.0 + float(l["seed"])) + 0.03 * sin(_t * 13.0 + float(l["seed"])))
	hud.scene_rect = scene_view.painting_rect() if in_scene and scene_view != null else Rect2()
	hud.burn = 0.0 if in_scene else _burn_amt        # no white-hot glow over a painting

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
				hud.say(Text.INNER["achy"])
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
	_after(T.f("prologue.thought_gap_s") + 0.6, _say_thought.bind("need_mirror"))
	_set_pro("done")
	mode = "play"
	_apply_item_state()

## An inner line said a little later, only if the player is still just walking about.
func _say_thought(key: String) -> void:
	if mode == "play":
		hud.say(Text.INNER[key])

## The thoughts after the mirror: what happened, can't remember, figure it out; then the pockets can be checked.
func _think_after_mirror() -> void:
	if engine.has_flag("thought_started"):
		return
	engine.set_flag("thought_started")
	var g := T.f("prologue.thought_gap_s")
	_after(0.6, _say_thought.bind("what_happened"))
	_after(0.6 + g, _say_thought.bind("cant_remember"))
	_after(0.6 + g * 2.0, _say_thought.bind("figure_out"))
	_after(0.6 + g * 2.0 + 2.2, _thoughts_done)

func _thoughts_done() -> void:
	engine.set_flag("thought")

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
	# until you have seen yourself in the mirror you ache: slower, with a limp
	var hobbling := not engine.has_flag("mirror")
	player.hobble = hobbling
	player.walk(dir, delta, area, engine.speed() * (T.f("prologue.hobble_speed_mult") if hobbling else 1.0), _npcs)
	engine.pos = player.position
	_footsteps(delta, player.position.distance_to(was))
	for n in _npcs:
		n.tick(delta, player, _npcs)
	engine.day = maxi(engine.day, int(clock.day))        # past midnight the sun is one level worse (bible section 8)
	_tick_follower(delta)
	_tick_senses(delta)
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
	var trig := area.trigger_at(player.position)
	if trig == "alley" and not engine.has_flag("alley"):
		_enter_alley()
	elif trig.begins_with("sense") and not engine.has_flag(trig):
		_sense_beat(trig)
	elif trig in ["walk1", "walk2", "walk3", "gate", "branch", "house"] and not engine.has_flag(trig):
		_road_beat(trig)
	# a room with a painting opens in Scene mode as you walk in (turned_scenes.json "walk_zone")
	var zone := Scenes.zone_at(_scenes(), area.id, player.position, _scene_holds)
	if zone != "" and enter_scene(zone):
		return
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
		if iid == "matches" and (not engine.has_flag("matches_home") or engine.has_item("matches")):
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
	if _fol_state == "mouth" and _follower != null and player.position.distance_to(_follower.position) <= T.f("follower.grab_px"):
		best = {"id": "grab_follower", "verb": "grab"}
	# nothing to examine here: after the mirror's thoughts, A checks your pockets (once)
	if best.is_empty() and engine.has_flag("thought") and not engine.has_flag("pockets") and area.indoor:
		best = {"id": "pockets", "verb": "pockets"}
	return best

func press_a() -> void:
	if _card_open():
		card_view.close()
		return
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
		"dialogue":
			_dialogue_a()
		"scene":
			if scene_view != null:
				scene_view.keyboard_nav = true
				scene_view.activate_selected()

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
		"towel", "calendar":
			_clue(iid)
		"coat":
			start_dialogue("coat")
		"pockets":
			engine.set_flag("pockets")
			TSfx.play(self, "breath", -6.0)
			hud.say(Text.INNER["pockets_empty"])
			_add_journal("pockets")
			if engine.mission != "go_bar":          # the note already points further
				engine.set_mission("find_out" if engine.journal.has("coat") else "find_coat")
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
			elif not engine.journal.has("coat"):
				hud.say(Text.INNER["door_coat"])
			elif not engine.has_item("note"):
				hud.say(Text.INNER["door_note"])
			else:
				TSfx.play(self, "door", -4.0)
				_go_area("street", "from_house", true)
		"house_door":
			if engine.has_flag("followed") and not engine.has_flag("witness_met"):
				hud.say(Text.INNER["door_followed"], "inner", "", 6.0)
				if engine.mission != "follower":
					engine.set_mission("follower")
				engine.set_flag("fol_h3")                # the hint about the lane is in the line itself
			else:
				TSfx.play(self, "door", -4.0)
				_go_area("house_down", "from_street", false)
		"grab_follower":
			_fol_state = "caught"
			var to_him: Vector2 = _follower.position - player.position
			player.face = to_him.normalized()
			_follower.drive(_follower.position, -to_him, false, 0.0)
			start_dialogue("follower_grab")
		"bar_door":
			if engine.has_flag("bar_thrown"):
				TSfx.play(self, "door", -14.0, 0.7)
				hud.say(Text.INNER["bar_locked"])
			else:
				TSfx.play(self, "door", -4.0)
				if clock.hour >= T.f("moon.set_hour") and clock.hour < T.f("bar.opens_hour"):
					hud.say(Text.INNER["bar_late"])       # the note says night: the day passes until the pub opens
					_go_area("bar", "from_street", true)
					_tr_hour = T.f("bar.arrive_hour")
				else:
					_go_area("bar", "from_street", true)
		"matches":
			engine.add_item("matches")
			TSfx.play(self, "pickup", -4.0)
			hud.reveal("menu")
			hud.say(Text.INNER["matches_take"])
			_apply_item_state()
		"cigar_door":
			TSfx.play(self, "door", -4.0)
			_go_area("cigar_shop", "from_harbor", true)
		"priest_door":
			if engine.has_flag("house_reached"):
				hud.say(Text.INNER["house_tbc"])
			else:
				start_dialogue("house_arrive")
		"cigar_exit":
			TSfx.play(self, "door", -4.0)
			_go_area("harbor", "from_shop", true)
		"bar_exit":
			TSfx.play(self, "door", -4.0)
			_go_area("street", "from_bar", true)
		"stairs_down":
			TSfx.play(self, "step", -8.0)
			_go_area("house_down", "from_up", false)
		"stairs_up":
			TSfx.play(self, "step", -8.0)
			_go_area("house", "from_down", false)
		"cellar_door":
			TSfx.play(self, "door", -14.0, 0.7)
			hud.say(Text.INNER["cellar_locked"])
			_add_journal("cellar")
		"alley_door":
			hud.say(Text.INNER["locked_end"])
		_:
			if Text.LOOKS.has(iid):
				hud.say(Text.LOOKS[iid], "inner", "", maxf(3.0, float(Text.LOOKS[iid].length()) * 0.055))

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
	if n.id == "witness":
		_talk_witness(n)
		return
	if n.id == "shopkeeper" and engine.has_flag("storeroom_scene") and not engine.has_flag("watch_shown"):
		n.talk_to(player.position)
		start_dialogue("watch_show")
		return
	var lines: Dictionary = Text.NPC_LINES.get(n.id, {})
	var line: String = str(lines.get("all", lines.get("covered" if engine.has_flag("scarf") else "exposed", "")))
	n.talk_to(player.position)
	hud.say(line, "speech", Text.SPEAKERS.get(n.id, ""))
	if n.knows_player >= 2 and not (n.data.get("clue_ids", ["watcher"]) as Array).is_empty():
		_add_journal(str((n.data.get("clue_ids", ["watcher"]) as Array)[0]))

## The witness at your house: he waits until you have seen the coat again and have the matches.
func _talk_witness(n: Node2D) -> void:
	n.talk_to(player.position)
	if engine.has_flag("witness_home") and not engine.has_flag("matches_shown"):
		if engine.has_item("matches") and engine.has_flag("watch_found"):
			start_dialogue("witness_matches")
		else:
			hud.say(Text.INNER["wit_wait"])
	else:
		hud.say(Text.NPC_LINES["witness"]["all"], "speech", Text.SPEAKERS["witness"])

# ---------------------------------------------------------------- dialogue scenes

## Starts a scene from turned_dialogues.json (only from free play). The player and the clock
## stand still until it ends; false if it cannot start.
func start_dialogue(id: String) -> bool:
	if mode != "play" and mode != "scene":
		return false
	dlg.engine = engine
	dlg.clock = clock
	_dlg_journal = engine.journal.size()
	_dlg_items = engine.items.size()
	_dlg_area = ""
	_dlg_scene = ""
	if not dlg.start(id):
		return false
	_dlg_back = mode                   # "play", or "scene" when it was started from a painting
	mode = "dialogue"
	player.moving = false
	_dlg_dir_prev = 0
	hud.clear_caption()
	_after_dialogue_step()
	return true

func _tick_dialogue(delta: float) -> void:
	player.moving = false
	for n in _npcs:
		n.tick(delta, player, _npcs)
	# up / down move the highlight on a choice (an edge, so a held arrow moves one step)
	var dy := _input_dir().y
	var sy := 0 if absf(dy) < 0.5 else int(signf(dy))
	if sy != 0 and sy != _dlg_dir_prev:
		dlg.move(sy)
		hud.show_dialogue(dlg.view())
	_dlg_dir_prev = sy
	var v := dlg.view()
	hud.a_label = "choose" if str(v.get("kind", "")) == "choice" and hud.dialogue_typed() else "continue"
	hud.a_active = true

func _dialogue_a() -> void:
	if not dlg.active:
		return
	if not hud.dialogue_typed():
		hud.dialogue_skip()           # the first A shows the whole line, the next one goes on
		return
	dlg.advance()
	_after_dialogue_step()

func _on_dialogue_option(i: int) -> void:
	if mode != "dialogue" or not dlg.active:
		return
	if not hud.dialogue_typed():
		hud.dialogue_skip()
		return
	dlg.choose(i)
	_after_dialogue_step()

## After a scene moved on: the effects meant for the world, new Journal lines and items, the end.
func _after_dialogue_step() -> void:
	for e in dlg.take_events():
		var s := str(e)
		if s.begins_with("hour:"):
			_dlg_hour = s.substr(5).to_float()
		elif s.begins_with("sfx:"):
			TSfx.play(self, s.substr(4), -6.0)
		elif s.begins_with("area:"):
			_dlg_area = s.substr(5)
		elif s.begins_with("hold:"):
			_dlg_hold = s.substr(5).to_float()
		elif s.begins_with("hurt:"):
			engine.hp = maxf(1.0, engine.hp * (1.0 - s.substr(5).to_float()))
		elif s == "throb":
			_throb_t = 0.0
		elif s.begins_with("hunger:"):
			if s.substr(7).to_float() > 0.0:
				engine.set_flag("hungry")
			else:
				engine.clear_flag("hungry")
		elif s == "to_be_continued":
			hud.banner(Text.BANNER_TBC)
		elif s.begins_with("scene:"):
			_dlg_scene = s.substr(6)
		elif s.begins_with("card:"):
			show_card(s.substr(5))
	if engine.journal.size() > _dlg_journal:
		hud.reveal("menu")
		_apply_item_state()
	if engine.items.size() > _dlg_items:
		hud.reveal("menu")
		TSfx.play(self, "pickup", -4.0)
	_dlg_journal = engine.journal.size()
	_dlg_items = engine.items.size()
	if dlg.active:
		hud.show_dialogue(dlg.view())
		return
	hud.hide_dialogue()
	hud.a_label = ""
	mode = _dlg_back
	_dlg_back = "play"
	if mode == "scene" and scene_view != null:
		scene_view.refresh()
	if _dlg_scene != "":
		var go := _dlg_scene
		_dlg_scene = ""
		enter_scene(go)                     # a "scene:" effect: the painting opens when the dialogue is over
	if engine.has_flag("witness_met") and not engine.has_flag("witness_home") and area.id == "street" and _fol_state != "witness":
		_spawn_witness()                          # (scene 3 only: after it he is at your house, then gone)
	var hour_to := _dlg_hour
	_dlg_hour = -1.0
	if _dlg_area != "":
		leave_scene()                       # an "area:" effect from a scene that began on a painting
		mode = "play"
		var parts := _dlg_area.split(":")
		_dlg_area = ""
		_go_area(parts[0], parts[1] if parts.size() > 1 else "", true)
		if hour_to >= 0.0:
			_tr_hour = hour_to              # the clock jumps while the screen is black
		_tr_hold = _dlg_hold
		_dlg_hold = 0.0
	elif hour_to >= 0.0:
		clock.skip_to(hour_to)

# ---------------------------------------------------------------- the man who follows you (scene 3)
# He steps out of the bar and runs, then keeps a fixed distance behind you along your own trail,
# so his footsteps start, slow down and stop exactly when yours do. If you wait round the corner of
# the side lane he comes to the corner and A grabs him. In the open he keeps away.

func _follower_look() -> Dictionary:
	return {"coat": "1d2029", "hat": "flat", "skin": "b9a89a", "accent": "3a3f4e"}

func _make_follower(at: Vector2, companion: bool = false) -> void:
	if _follower != null:
		_follower.queue_free()
	_follower = NpcScript.new()
	var look := {"coat": "4a4a44", "hat": "flat", "skin": "d0bfae", "accent": "6a6a62"} if companion else _follower_look()
	_follower.setup({"id": "follower", "pos": [at.x, at.y], "face": [0, -1], "look": look, "knows_player": 1})
	_entities.add_child(_follower)

func _follower_begin() -> void:
	if area.id != "street" or engine.has_flag("followed") or mode != "play":
		return
	engine.set_flag("followed")
	TSfx.play(self, "door", -8.0)
	_make_follower(area.spawns["from_bar"] + Vector2(0, -22.0))
	_fol_state = "exit"
	_fol_steps = 0
	hud.say(Text.INNER["fol_door"])

func _fol_begin_tail() -> void:
	_fol_trail = [_follower.position, player.position]
	_fol_state = "tail"
	_fol_last_pp = player.position

func _fol_record() -> void:
	if _fol_trail.is_empty() or player.position.distance_to(_fol_trail.back()) > 6.0:
		_fol_trail.append(player.position)
		if _fol_trail.size() > 300:
			_fol_trail = _fol_trail.slice(100)

## The point on your trail `lag` px behind you.
func _fol_target(lag: float) -> Vector2:
	var acc := 0.0
	var prev: Vector2 = player.position
	var i := _fol_trail.size() - 1
	while i >= 0:
		var pt: Vector2 = _fol_trail[i]
		var seg := prev.distance_to(pt)
		if acc + seg >= lag:
			return prev.lerp(pt, (lag - acc) / maxf(seg, 0.001))
		acc += seg
		prev = pt
		i -= 1
	return _fol_trail[0] if not _fol_trail.is_empty() else player.position

func _in_lane() -> bool:
	return area.trigger_at(player.position) == "lane" and player.position.y < T.f("follower.lane_inside_y")

## The shopkeeper on the night road: the person you walk with, with his oil lamp.
func _make_owner(at: Vector2) -> void:
	if _follower != null:
		_follower.queue_free()
	_follower = NpcScript.new()
	_follower.setup({"id": "owner", "pos": [at.x, at.y], "face": [1, 0], "knows_player": 2,
			"look": {"coat": "5a4a38", "hat": "", "skin": "caa488", "accent": "c9a15b"}})
	_entities.add_child(_follower)
	_owner_light = PointLight2D.new()
	_owner_light.texture = _light_tex
	_owner_light.texture_scale = T.f("road.lamp_radius_px") / 128.0
	_owner_light.color = Color("ffb45a")
	_owner_light.energy = T.f("road.lamp_energy")
	_owner_light.height = T.f("light.lamp_height_px")
	_owner_light.position = Vector2(8, -14)
	_follower.add_child(_owner_light)

## Arc length along the road's waypoints (tuning road.path) of the point nearest to `p`.
func _road_s(p: Vector2) -> float:
	var pts := T.arr("road.path")
	var best_s := 0.0
	var best_d := INF
	var acc := 0.0
	for i in pts.size() - 1:
		var a := Vector2(float(pts[i][0]), float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var seg := b - a
		var t := clampf((p - a).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		var q := a + seg * t
		if p.distance_to(q) < best_d:
			best_d = p.distance_to(q)
			best_s = acc + seg.length() * t
		acc += seg.length()
	return best_s

func _road_point(s: float) -> Vector2:
	var pts := T.arr("road.path")
	var acc := 0.0
	for i in pts.size() - 1:
		var a := Vector2(float(pts[i][0]), float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var len := a.distance_to(b)
		if s <= acc + len:
			return a.lerp(b, (s - acc) / maxf(len, 0.001))
		acc += len
	var last: Array = pts[pts.size() - 1]
	return Vector2(float(last[0]), float(last[1]))

## The beats along the night road: the priest (told by the shopkeeper), the senses, the gate, the branch.
func _road_beat(id: String) -> void:
	engine.set_flag(id)
	match id:
		"walk1":
			start_dialogue("road_priest")
		"walk2":
			hud.say(Text.INNER["road_sens2"])
		"walk3":
			hud.say(Text.INNER["road_sens3"])
		"gate":
			hud.say(Text.INNER["road_gate"])
		"branch":
			if _follower != null:
				_follower.drive(player.position + Vector2(46, -4), Vector2(1, 0), false, 0.0)    # beside you, on the path
			start_dialogue("branch_arm")
		"house":
			hud.say(Text.INNER["road_house"])

func _fol_mouth() -> Vector2:
	var a := T.arr("follower.mouth")
	return Vector2(float(a[0]), float(a[1]))

## Walks the man towards `p` (sliding along walls) and plays his footsteps, quieter the further he is.
func _fol_move_to(p: Vector2, speed: float, delta: float, quiet: bool = false) -> void:
	var d := p - _follower.position
	if d.length() <= 2.0:
		_follower.drive(_follower.position, _follower.face, false, delta)
		_fol_step_t = 0.0
		return
	# steer round corners: try the straight way, then turned aside, and keep the step that gets closest
	var dir := d.normalized()
	var want := minf(d.length(), speed * delta)
	var np: Vector2 = _follower.position
	var best := 0.0
	for ang in [0.0, 0.7, -0.7, 1.4, -1.4]:
		var cand: Vector2 = area.move_circle(_follower.position, dir.rotated(ang) * want, 9.0)
		var gain := (cand - _follower.position).dot(dir)
		if gain > best + 0.001:
			best = gain
			np = cand
		if ang == 0.0 and gain > want * 0.9:
			break
	var moved := np.distance_to(_follower.position)
	if moved <= 0.01:
		# caught on a corner (a lamp post in the straight way): after a moment hop to the free spot
		# round it that lies most towards the goal
		_fol_stuck += delta
		if _fol_stuck > 0.25:
			_fol_stuck = 0.0
			var best_hop := -2.0
			for i in 16:
				var hop: Vector2 = _follower.position + Vector2.from_angle(TAU * float(i) / 16.0) * 16.0
				if area.is_free(hop, 9.0) and (hop - _follower.position).normalized().dot(dir) > best_hop:
					best_hop = (hop - _follower.position).normalized().dot(dir)
					np = hop
			moved = np.distance_to(_follower.position)
	else:
		_fol_stuck = 0.0
	_follower.drive(np, d, moved > 0.01, delta)
	if moved <= 0.01:
		_fol_step_t = 0.0
		return
	_fol_step_t -= delta
	if _fol_step_t <= 0.0:
		_fol_step_t = T.f("player.step_interval_s") * (1.6 if engine.sneaking else 1.0)
		_fol_steps += 1
		if quiet:
			return
		var far := clampf(player.position.distance_to(np) / 60.0, 0.0, 12.0)
		TSfx.play(self, "step", T.f("player.step_volume_db") - far, 0.85)

func _tick_follower(delta: float) -> void:
	if _follower == null or _fol_state == "off" or _fol_state == "witness" or _fol_state == "caught" or _fol_state == "still":
		return
	if _owner_light != null:
		_owner_light.energy = T.f("road.lamp_energy") * (0.92 + 0.08 * sin(_t * 6.0) + 0.03 * sin(_t * 15.0))
	if _fol_state == "leader" and engine.has_flag("owner_behind"):
		_fol_begin_tail()                       # after the branch he walks behind you
		_fol_state = "behind"
	var dist := player.position.distance_to(_follower.position)
	if player.position.distance_to(_fol_last_pp) < 0.05:
		_fol_still += delta
	else:
		_fol_still = 0.0
	_fol_last_pp = player.position
	match _fol_state:
		"exit":
			var to := Vector2(float(T.arr("follower.exit_to")[0]), float(T.arr("follower.exit_to")[1]))
			_fol_move_to(to, T.f("follower.exit_run_speed"), delta)
			if _follower.position.distance_to(to) < 4.0:
				_fol_state = "wait_far"
		"wait_far":
			_follower.drive(_follower.position, player.position - _follower.position, false, delta)
			if dist < T.f("follower.flee_px"):
				_fol_state = "flee"
				_fol_t = 0.0
			elif dist > T.f("follower.start_distance_px") and not _in_lane():
				_fol_begin_tail()
		"tail":
			_fol_record()
			if _in_lane():
				_fol_state = "lane"
				if engine.mission != "follower":
					engine.set_mission("follower")
				return
			if dist < T.f("follower.flee_px"):
				_fol_state = "flee"
				_fol_t = 0.0
				return
			_fol_move_to(_fol_target(T.f("follower.lag_px")), engine.speed() * T.f("follower.speed_mult"), delta)
			_follower_hints()
		"lane":
			if not _in_lane():
				_fol_state = "wait_far"
				return
			_fol_move_to(_fol_mouth(), T.f("player.walk_speed") * 0.9, delta)
			if _follower.position.distance_to(_fol_mouth()) < 10.0:
				_fol_state = "mouth"
		"mouth":
			_follower.drive(_follower.position, Vector2(0, -1), false, delta)
			if not _in_lane():
				_fol_state = "flee"
				_fol_t = 0.0
		"leader":
			var lead_s := _road_s(player.position) + T.f("road.lead_px")
			var lead_to := _road_point(lead_s)
			if dist > T.f("road.lead_wait_px"):
				lead_to = _follower.position            # too far ahead: wait for you
			_fol_move_to(lead_to, engine.speed() * T.f("road.owner_speed_mult"), delta, true)
		"behind":
			_fol_record()
			_fol_move_to(_fol_target(T.f("road.behind_lag_px")), engine.speed() * T.f("follower.companion_speed_mult"), delta, true)
		"companion":
			_fol_record()
			_fol_move_to(_fol_target(T.f("follower.companion_lag_px")), engine.speed() * T.f("follower.companion_speed_mult"), delta, true)
		"flee":
			_fol_t += delta
			var away := (_follower.position - player.position).normalized()
			if away.length() < 0.1:
				away = Vector2.RIGHT
			_fol_move_to(_follower.position + away * 80.0, T.f("follower.exit_run_speed"), delta)
			if _fol_t > 1.8:
				_fol_state = "wait_far"

## The three thoughts while he follows: footsteps, "I stop, they stop", and the side lane.
func _follower_hints() -> void:
	if not engine.has_flag("fol_h1") and _fol_steps >= int(T.f("follower.first_hint_steps")):
		engine.set_flag("fol_h1")
		hud.say(Text.INNER["fol_steps"])
	elif engine.has_flag("fol_h1") and not engine.has_flag("fol_h2") and _fol_still >= T.f("follower.still_hint_s") and not hud.caption_busy():
		engine.set_flag("fol_h2")
		engine.set_mission("follower")
		hud.say(Text.INNER["fol_stop"])
	elif engine.has_flag("fol_h2") and not engine.has_flag("fol_h3") and player.position.distance_to(_fol_mouth()) < T.f("follower.lane_hint_px") and not hud.caption_busy():
		engine.set_flag("fol_h3")
		hud.say(Text.INNER["fol_lane"])

## After the scene he stays at the corner as a person you can talk to (his one line, for now).
func _spawn_witness() -> void:
	_spawn_witness_at(_fol_mouth(), Vector2(0, -1))

func _spawn_witness_at(m: Vector2, face: Vector2) -> void:
	if _follower != null:
		_follower.queue_free()
		_follower = null
	var n := NpcScript.new()
	n.setup({"id": "witness", "knows_player": 2, "role": "witness", "behavior": "stand", "stare": true,
			"pos": [m.x, m.y], "face": [face.x, face.y], "clue_ids": [],
			"look": {"coat": "4a4a44", "hat": "flat", "skin": "d0bfae", "accent": "6a6a62"}})
	_npcs.append(n)
	_entities.add_child(n)
	_fol_state = "witness"

# ---------------------------------------------------------------- the watch and the senses (scene 4)

## The coat's tick before you find the watch (louder close to the coat, upstairs), the watch's own tick
## once you carry it (only you seem to hear it), the far-off dog, in the harbor.
func _tick_senses(delta: float) -> void:
	var ticking_coat := engine.has_flag("witness_home") and not engine.has_flag("watch_found") and area.id == "house"
	var ticking_watch := engine.has_item("watch") and not engine.has_flag("watch_broken")
	if ticking_coat or ticking_watch:
		_watch_t -= delta
		if _watch_t <= 0.0:
			_watch_t = T.f("senses.tick_interval_s")
			if ticking_coat:
				TSfx.play(self, "tick", T.f("senses.tick_coat_db") - clampf(player.position.distance_to(Vector2(241, 60)) / 40.0, 0.0, 14.0))
			else:
				TSfx.play(self, "tick", T.f("senses.tick_db"))
	if engine.has_flag("senses") and area.id == "harbor":
		_bark_t -= delta
		if _bark_t <= 0.0:
			_bark_t = randf_range(T.f("senses.bark_min_s"), T.f("senses.bark_max_s"))
			TSfx.play(self, "bark", -12.0, randf_range(0.85, 1.1))

## The four beats along the harbor street: lamps too bright, a dog, the smells, the thirst.
func _sense_beat(id: String) -> void:
	engine.set_flag(id)
	var key: String = {"sense1": "sense_lamps", "sense2": "sense_dog", "sense3": "sense_smell", "sense4": "sense_thirst"}.get(id, "")
	if key != "":
		hud.say(Text.INNER[key])
	if id == "sense2":
		TSfx.play(self, "bark", -6.0)


# ---------------------------------------------------------------- scene mode (a painting with hotspots)

func _scene_holds(conds: Array) -> bool:
	dlg.engine = engine
	dlg.clock = clock
	return dlg.holds(conds)

func _scene_seen(flag: String) -> bool:
	return engine.has_flag(flag)

func _scenes() -> Dictionary:
	return scene_data if not scene_data.is_empty() else Scenes.shipped()

## Shows a scene from turned_scenes.json (or `scene_data`); only from free play or from another
## painting. The walk, the clock and the sun stand still: time passes in Scene mode only through
## the story and travel (the plan's decision 3).
func enter_scene(id: String) -> bool:
	if scene_view == null or not mode in ["play", "scene", "transition"]:
		return false
	var fading := mode == "transition"          # arriving through a door: the fade goes on over the painting
	var sc: Dictionary = _scenes().get(id, {})
	if sc.is_empty():
		return false
	in_scene = true
	scene_id = id
	mode = "transition" if fading else "scene"
	player.moving = false
	hud.clear_caption()
	hud.release_inputs()
	hud.scene_mode = true
	hud.a_label = ""
	scene_view.show_scene(id, sc)
	if scene_hud != null:
		scene_hud.visible = true
	return true

## Back to walking (also called when a new game starts).
func leave_scene() -> void:
	if not in_scene:
		return
	in_scene = false
	scene_id = ""
	if scene_view != null:
		scene_view.hide_scene()
	if scene_hud != null:
		scene_hud.visible = false
		scene_hud.enabled = false
	if hud != null:
		hud.scene_mode = false
	if mode == "scene":
		mode = "play"

func _on_hotspot(hs: Dictionary) -> void:
	if mode != "scene":
		return
	engine.set_flag(Scenes.seen_flag(scene_id, str(hs.get("id", ""))))
	var journal_n := engine.journal.size()
	var items_n := engine.items.size()
	var walk_code := false                      # an interact: plays its own sounds
	for a in (hs.get("do", []) as Array):
		walk_code = walk_code or str(a).begins_with("interact:")
		_scene_action(str(a))
		if not in_scene or mode == "transition":
			break                               # it left the painting (walk, area)
	if engine.journal.size() > journal_n:
		hud.reveal("menu")
	if engine.items.size() > items_n:
		hud.reveal("menu")
		if not walk_code:
			TSfx.play(self, "pickup", -4.0)
		_apply_item_state()
	if in_scene and scene_view != null:
		scene_view.refresh()

func _scene_action(s: String) -> void:
	if s.begins_with("look:"):
		hud.say(str(SceneText.LOOKS.get(s.substr(5), "TODO " + s.substr(5))))
	elif s.begins_with("interact:"):
		_interact({"id": s.substr(9)})
	elif s.begins_with("dialogue:"):
		start_dialogue(s.substr(9))
	elif s.begins_with("scene:"):
		enter_scene(s.substr(6))
	elif s.begins_with("card:"):
		show_card(s.substr(5))
	elif s == "leave":
		leave_scene()
	elif s.begins_with("area:"):
		# the painting stays up until the screen is black (_tick_transition closes it)
		var p := s.substr(5).split(":")
		_go_area(p[0], p[1] if p.size() > 1 else "", true)
	elif s.begins_with("hour:"):
		clock.skip_to(s.substr(5).to_float())
	elif s.begins_with("sfx:"):
		TSfx.play(self, s.substr(4), -6.0)
	else:
		dlg.engine = engine
		dlg.clock = clock
		dlg.apply([s])
		dlg.take_events()

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
				mode = "scene" if in_scene else "play"   # the mirror can be opened from the bathroom painting
				if engine.mission != "go_bar":
					engine.set_mission("find_out")
				hud.reveal("mission")
				_apply_item_state()
				_think_after_mirror()

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
			leave_scene()                     # an area: exit from a painting
			_load_area(_tr_area)
			player.position = area.spawns[_tr_spawn]
			engine.pos = player.position
			if _tr_area == "street":
				# the sun is introduced here: the bars and the burning light
				engine.show_bars = true
				hud.reveal("bars")
				engine.burned_this_visit = false
			if _tr_hour >= 0.0:
				clock.skip_to(_tr_hour)
				_tr_hour = -1.0
			_snap_camera()
			_apply_item_state()
			_sun_mix = 0.0
			# arriving in a room that has a painting: it is up before the screen lights again
			var zone := Scenes.zone_at(_scenes(), area.id, player.position, _scene_holds)
			if zone != "":
				enter_scene(zone)
			_tr_phase = 1
			_tr_t = 0.0
	else:
		if _tr_hold > 0.0:
			_tr_hold -= delta                 # a blackout: stay in the dark a while
			_tr_t = 0.0
			hud.fade = 1.0
			return
		hud.fade = clampf(1.0 - _tr_t / half, 0.0, 1.0)
		if _tr_t >= half:
			hud.fade = 0.0
			mode = "scene" if in_scene else "play"
			if _tr_save:
				save_game()
			_on_area_ready()

## What happens on arriving somewhere (after the fade in, and on Resume): the bar's scene.
func _on_area_ready() -> void:
	if area.id == "bar" and not engine.has_flag("bar_scene"):
		start_dialogue("bar_shout")
	elif area.id == "house_down" and engine.has_flag("witness_home") and not engine.has_flag("matches_shown"):
		var hall := T.arr("follower.hall")
		_spawn_witness_at(Vector2(float(hall[0]), float(hall[1])), Vector2(-1, 0))
	elif area.id == "cigar_shop":
		if not engine.has_flag("shop_scene"):
			_spawn_witness_at(area.spawns["from_harbor"] + Vector2(60, -14), Vector2(-1, 0))
			start_dialogue("shop_visit")
		elif engine.has_flag("blackout") and not engine.has_flag("storeroom_scene"):
			start_dialogue("storeroom_wake")
		if engine.has_flag("blackout"):
			for n in _npcs:
				if n.id == "shopkeeper":
					n.position = Vector2(306, 134)          # on his stool by the cot
					n.face = Vector2(1, 0)
	elif area.id == "night_road":
		engine.set_flag("senses")
		_make_owner(player.position + Vector2(T.f("road.lead_px"), 0.0))
		if engine.has_flag("owner_behind"):
			_fol_begin_tail()
			_fol_state = "behind"
		else:
			_fol_state = "leader"
	elif area.id == "harbor":
		engine.set_flag("senses")
		if engine.has_flag("matches_shown") and not engine.has_flag("witness_gone"):
			_make_follower(player.position + Vector2(-T.f("follower.companion_lag_px"), 0.0), true)
			_fol_begin_tail()
			_fol_state = "companion"
	elif area.id == "street":
		if engine.has_flag("witness_met") and engine.has_flag("witness_home"):
			pass                                  # he is in the house
		elif engine.has_flag("witness_met"):
			_spawn_witness()
		elif engine.has_flag("followed"):
			_make_follower(player.position + Vector2(T.f("follower.lag_px") + 40.0, 0.0))
			_fol_begin_tail()
		elif engine.has_flag("bar_thrown"):
			_after(2.5, _follower_begin)

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
	Save.write(engine, clock, dlg, scene_id if in_scene else "")
