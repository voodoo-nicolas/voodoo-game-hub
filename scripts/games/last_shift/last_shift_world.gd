extends Node2D

## Last Shift world: rooms (ASCII data), interactable props, three flow puzzles, atmosphere
## (thuds, light flicker), alarms + red emergency lights + the calm building intercom, the scripted
## attack on a coworker, hiding in lockers, fists / knife / wrench / pistol, walkers / runner /
## screamers, guards and barricade shooters, save + continue, pause menu, English/Spanish, and the
## dawn ending. Placeholder art and synthesized sounds only. Day 0 rule: nobody explains anything.
##
## v0.3: health out of 100 that ticks back when nobody hunts Nash; a bag (inventory) with slots;
## searching lockers / desks / cabinets (2 s) and hiding in searched lockers; infected that lose
## the trail when Nash hides out of sight; a weapon wheel; a mission log; context words on the A
## button and the weapon on B; ambient people; chill music before the alarm; a short siren.
##
## v0.4: 22 rooms, three ways out (front doors, loading dock, fire exit) with achievements + XP;
## a quest log under the pinned main quest ESCAPE!, quests started by emails and notes; Easy /
## Normal / Hard; far more infected (each one weaker), Gary at his party, a brute, crawlers; armor
## (Nash's vest, riot gear); searchable bodies; blood; the first attack shown with a camera pan.
##
## v0.5 (third playtest, "Normal is too easy"): the night starts as a normal shift (ESCAPE! only after
## the first attack, then always first in the log); the infected go after every living person
## (guards fight back, survivors run in a panic, the dead get back up); tougher, faster infected and
## more of them; fewer first-aid kits, smaller snacks, less health regen; the siren sounds until it is
## switched off; one subtitle line at the bottom (Nash's lines come before the intercom); the severed
## arm and the coolant can; the cook's hat; a window an infected breaks in through; infected eating a
## body; a building map; options, statistics; no kill counter on screen (it is in Statistics).
##
## Route (see last_shift_rooms.gd): parking lot at dusk -> lobby (Dwayne, Wall of Excellence) ->
## elevator -> cooling plant (fix Chiller Four -> alarms -> coworker is grabbed -> wrench) ->
## corridor -> pump room (drain puzzle) -> locker room (maintenance key) -> break room ->
## security hall (guard) -> security office (Dwayne, pistol, key) -> open office (the party) ->
## call center (screamers, sealed Hall C) -> lobby hall (guard) -> lobby (barricade, vent puzzle)
## -> parking lot at dawn.

const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")
const LsInput = preload("res://scripts/games/last_shift/last_shift_input.gd")
const LsRooms = preload("res://scripts/games/last_shift/last_shift_rooms.gd")
const LsText = preload("res://scripts/games/last_shift/last_shift_text.gd")
const LsSfx = preload("res://scripts/games/last_shift/last_shift_sfx.gd")
const LsSave = preload("res://scripts/games/last_shift/last_shift_save.gd")
const Nash = preload("res://scripts/games/last_shift/last_shift_nash.gd")
const Prop = preload("res://scripts/games/last_shift/last_shift_prop.gd")
const Walker = preload("res://scripts/games/last_shift/last_shift_walker.gd")
const Guard = preload("res://scripts/games/last_shift/last_shift_guard.gd")
const Shooter = preload("res://scripts/games/last_shift/last_shift_shooter.gd")
const Npc = preload("res://scripts/games/last_shift/last_shift_npc.gd")
const Birds = preload("res://scripts/games/last_shift/last_shift_birds.gd")
const LsTiles = preload("res://scripts/games/last_shift/last_shift_tiles.gd")
const LsFx = preload("res://scripts/games/last_shift/last_shift_fx.gd")
const HudLabel = preload("res://scripts/games/last_shift/last_shift_hud_label.gd")
const LsUi = preload("res://scripts/games/last_shift/last_shift_ui.gd")
const TouchControls = preload("res://scripts/games/last_shift/last_shift_touch_controls.gd")
const HealthBar = preload("res://scripts/games/last_shift/last_shift_health_bar.gd")
const MissionLog = preload("res://scripts/games/last_shift/last_shift_mission_log.gd")
const BagPanel = preload("res://scripts/games/last_shift/last_shift_bag_panel.gd")
const Inventory = preload("res://scripts/games/last_shift/last_shift_inventory.gd")
const LsAch = preload("res://scripts/games/last_shift/last_shift_achievements.gd")
const LsSettings = preload("res://scripts/games/last_shift/last_shift_settings.gd")
const LsStats = preload("res://scripts/games/last_shift/last_shift_stats.gd")
const MapPanel = preload("res://scripts/games/last_shift/last_shift_map.gd")

## The prototype's start page. In the hub there is none: the world is "hosted" by
## last_shift_game.gd (the Landing kit), and the signals below go to it instead.
const MENU_SCENE := "res://scenes/games/last_shift/menu.tscn"

## Hub: the ⏸ button / Esc asks the host for the kit's pause menu (STANDARDS §6).
signal pause_requested
## Hub: the end card's "Back to menu" goes to the game's Landing.
signal menu_requested
## Set by last_shift_game.gd before the world enters the tree.
var hosted := false
## Set every frame by the host: a kit screen (Landing, pause menu, a card) covers the world, so
## the world ignores its own keys (the kit handles Back).
var kit_up := false
## Set by the host when this night is thrown away (new night / Resume / Restart): never save it.
var discard := false

const TILE := 32
const SOURCE_ID := 0
const FLOOR_ATLAS := Vector2i(0, 0)
const WALL_ATLAS := Vector2i(1, 0)
const SIGN_ATLAS := Vector2i(2, 0)

## The world (map, Nash, props) is drawn 2.25x bigger (1.5 x 1.5) than the 32 px tile grid.
## The HUD and the touch controls are NOT zoomed. Game logic works in plain world pixels.
const WORLD_ZOOM := 2.25

const FLOOR_COLOR := Color("5c6068")
const FLOOR_LINE := Color("50545b")
const WALL_COLOR := Color("23262d")
const WALL_TOP := Color("3a3f49")
const BACKGROUND := Color("0d0e11")
# Employer logo colors: white on Ascend purple. NEVER cyan (cyan = infected / lockdown only).
const LOGO_PURPLE := Color("7a4fc9")
const DUSK_LIGHT := Color(1.0, 0.78, 0.6)
const DAWN_LIGHT := Color(1.0, 0.9, 0.82)

const INTERACT_REACH := 20.0     # how far in front of Nash we look for something to use
const SCENE_DELAY := 14.0        # seconds after the alarm starts until the coworker runs in
const PICKUP_REACH := 22.0       # walk this close to an ammo box / first aid kit / key to take it
const PISTOL_START_AMMO := 6     # bullets in Dwayne's pistol
## The three ways out: the room you step into -> exit id (see LsEngine.EXIT_ACHIEVEMENT).
const EXIT_ROOMS := {"parking_lot": "front", "service_yard": "dock", "side_street": "fire"}
const MAX_DECALS := 160          # blood splats on the floor per room (oldest go first; v0.4: 60)
const NOTICE_SECONDS := 2.6      # how long a "New quest" / achievement notice stays up
## v0.5: the siren sounds until Nash switches the alarm off in the security office (v0.4: 10 s).
const SIREN_DB := -16.0
const SEARCH_NOISE := 90.0       # rummaging in a locker: infected this close come to look
const SEE_HIDE_RANGE := 260.0    # an infected this close, with a clear line, sees Nash climb in
const VENDING_PRICE := 2         # dollars per snack
const VENDING_STOCK := 2         # snacks in each machine
const BUMP_SECONDS := 0.18       # walking into a door this long opens it (no A needed)
const WHEEL_TIME_SCALE := 0.25   # the game slows down while the weapon wheel is up
const BAG_FULL_COOLDOWN := 2.5   # "Bag full" is not repeated more often than this
const SUBTITLE_GAP := 104.0      # v0.5: the subtitle line sits this far above the bottom edge
const DRIP_EVERY := 0.35         # v0.5: a wounded infected leaves a drop of blood this often
const CHEW_EVERY := 2.6          # v0.5: the feeding sounds repeat this often
const GUARD_SHOUT_GAP := 2.5     # v0.5: guard shouts are not shown more often than this
const WINDOW_TRIGGER_X := 8      # v0.5: the call-center window breaks when Nash passes this column

## Everything the story needs to remember between rooms (and in the save file).
var state := _new_state()

var nash: CharacterBody2D
var camera: Camera2D
var room_root: Node2D
var props := {}                 # id -> Prop, for the current room
var enemies: Array = []         # live enemies (walkers, runner, screamers, guards, shooters)
var hide_prop: Prop = null      # the locker Nash is hiding in
var current_room := ""
var checkpoint := {"room": "parking_lot", "spawn": "start"}   # where death / Continue sends Nash
var _rooms := {}
var actors: Node2D            # y-sorted container: Nash, props, enemies (tall things hide who is behind)
var _room_nodes: Array = []   # this room's nodes inside `actors`
var _room_lights: Array = []  # this room's ceiling lights (PointLight2D)
var _astar: AStarGrid2D       # walkable grid of the room, for enemy pathfinding
var _theme := "plant"
var _flicker_mult := 1.0
var _shake := 0.0
var _hurt := 0.0
var _vignette: ColorRect
var _nash_light: PointLight2D
var _prev_interpolation := false
const SHOW_DEBUG := false

# Lighting and atmosphere
var _light: CanvasModulate
var _clock := 0.0
var _alarm_t := 0.0
var _thud_t := 9.0
var _flicker_t := 25.0
var _siren: AudioStreamPlayer
var _dusk := false
var _dawn := false

# Timed tasks that stop while paused: {t: seconds left, fn: Callable}
var _tasks: Array = []

# Scripted scene
var _scene_active := false
var _scene_npc: Node2D = null
var _scene_walker: Node2D = null
var _controls: Control = null
var _drop_count := 0

# Searching, healing, doors
var _search_prop: Prop = null
var _search_t := 0.0
var _since_threat := 99.0       # seconds since anyone hunted / hurt Nash
var _regen_acc := 0.0
var _regenerating := false
var _bump_t := 0.0
var _bag_full_t := 0.0
var _knife_said := false
var _decals: Array = []          # this room's blood splats (not saved)
var _scene_cam: Camera2D = null  # the camera that pans to the first attack
var _notices: Array = []         # queued "New quest" / "Done" / achievement lines: [text, color]
var _notice_t := 0.0
var _gary_said := false
# v0.5
var _people: Array = []          # this room's survivors (not enemies)
var _clouds: Array = []          # coolant clouds: {"pos", "t", "node"}
var _drip_t := 0.0
var _chew_t := 0.0
var _guard_shout_t := 0.0
var _stat_time := 0.0            # play time not yet added to the statistics
var _sub_queue: Array = []       # subtitle lines waiting: {"kind", "text", "secs"}
var _sub_cur := {}               # the line on screen
var _sub_t := 0.0
var _map_open := false
var _new_record := false

# HUD
var _debug_label: Label
var _objective_text := ""       # the current objective line (shown in the mission log)
var _toast_label: Label
## v0.5: ONE subtitle line at the bottom for both the intercom and Nash (they used to overlap).
var _sub_label: Label
var _health: Control
var _kills_label: Label
var _notice_label: Label
var _log: Control
var _map: Control
var _bag: Control
var _bag_open := false
var _fade: ColorRect
var _end_label: Label
var _panel: Panel
var _panel_text: Label
var _pause_box: Panel
var _pause_title: Label
var _btn_resume: Button
var _btn_map: Button
var _btn_lang: Button
var _btn_quit: Button
var _toast_id := 0

var _fading := false
var _modal_open := false
var _modal_frame := 0
var _hide_frame := 0
var _end_ready := false

static func _new_state() -> Dictionary:
	return {
		"puzzles": {"chiller": [false, false, false], "pump": [false, false, false, false],
			"vents": [false, false, false, false]},
		"solved": {"chiller": false, "pump": false, "vents": false},
		"has_keycard": false,
		"has_sec_key": false,   # Dwayne's security key (opens the office east door)
		"has_maint_key": false, # maintenance key (locker room east door)
		"searched": {},         # container id -> true once searched (lockers, desks, cabinets)
		"alarm": false,
		"scene_started": false,
		"attack_done": false,   # the coworker scene has played (or was skipped)
		"door_open": false,     # plant east door forced open during the scene
		"dead": {},             # enemy id -> true once killed / knocked out
		"kills": 0,
		"deaths": 0,
		"play_time": 0.0,
		"taken": {},            # static pickups already collected (prop id -> true)
		"left": {},             # static pickups partly taken (bag full): prop id -> amount left
		"drops": [],            # dropped items: {room, data}
		"vending_used": {},     # machine id -> snacks sold
		"visited": {},          # room id -> true
		"difficulty": 1,        # 0 Easy, 1 Normal, 2 Hard (LsEngine.DIFFICULTY)
		"read": {},             # email / note id -> true once read (some start quests)
		"tried": {},            # locked door id -> true once Nash tried it (some start quests)
		"flags": {},            # one-off story flags: hid, inspected, alarm_off, cutters, fire_cut, eotm_seen...
		"quests": [],           # quest ids in the order they appeared in the log
		"quests_done": {},      # quest id -> true once ticked (for the "Done" notice)
		"room_said": {},        # room id -> true once Nash said his line there
		"exit": "",             # "front" | "dock" | "fire" once out
		"searches": 0,          # things searched this run (Scavenger)
		"achieved": [],         # achievements unlocked during this run (end card)
		"turned": {},           # v0.5: person id -> {"room", "x", "y", "shirt"} (killed by the infected, got up)
		"money_earned": 0,      # v0.5: cash picked up this run (Statistics)
		"weapon_kills": {},     # v0.5: weapon -> infected Nash took down with it this run
		"entered_lobby": false,
		"hall_intro": false,
		"lobby_intro": false,
		"lobby_alarm_seen": false,
		"guard_down_said": false,
		"wrench_useless_said": false,
		"ended": false,
	}

func _ready() -> void:
	# (Prototype: LsI18n.install() here. In the hub the Spanish comes from tools/i18n/es.json via the
	# generated last_shift_i18n.gd, installed by last_shift_game.gd; the language is the app's.)
	LsInput.ensure_actions()
	# Bodies move at 60 physics ticks per second and are drawn smoothly in between, so movement
	# doesn't judder on 90 / 120 Hz phones. Set here (not in project.godot) so it also works when
	# the game runs as a pack inside the hub; put back on exit.
	_prev_interpolation = get_tree().physics_interpolation
	get_tree().physics_interpolation = true
	# The world keeps ticking while paused so it can hear the pause key; gameplay nodes do not.
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(BACKGROUND)
	_rooms = LsRooms.rooms()
	_light = CanvasModulate.new()
	add_child(_light)
	actors = Node2D.new()
	actors.process_mode = Node.PROCESS_MODE_PAUSABLE   # enemies and props freeze while paused
	add_child(actors)
	nash = Nash.new()
	nash.footstep.connect(_on_nash_footstep)
	actors.add_child(nash)
	# A small warm light that follows Nash so he never disappears into the dark.
	_nash_light = PointLight2D.new()
	_nash_light.texture = LsFx.light_texture()
	_nash_light.texture_scale = 0.9
	_nash_light.energy = 0.45
	_nash_light.color = Color(1.0, 0.92, 0.8)
	nash.add_child(_nash_light)
	camera = Camera2D.new()
	# follows Nash in the physics step (needed for smooth physics interpolation)
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.zoom = Vector2(WORLD_ZOOM, WORLD_ZOOM)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0     # was 6: the camera trailed Nash and felt sluggish
	nash.add_child(camera)
	camera.make_current()
	_siren = AudioStreamPlayer.new()
	_siren.stream = LsSfx.siren()
	_siren.volume_db = SIREN_DB + LsSettings.sfx_db()
	_siren.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_siren)
	_build_hud()
	var start_room := "parking_lot"
	var start_spawn := "start"
	state.difficulty = LsSave.new_difficulty
	LsSettings.apply_music()
	var continued := false
	if LsSave.continue_requested:
		LsSave.continue_requested = false
		var data := LsSave.read()
		if not data.is_empty():
			_apply_save(data)
			start_room = data.room
			start_spawn = data.spawn
			continued = true
	if not continued:
		LsStats.add_run()
	_load_room(start_room, start_spawn)
	_update_hp_hud()
	if start_room == "parking_lot" and not state.alarm:
		_after(1.2, _nash_say.bind(LsText.NASH.vo_nash_day0_07))

func _exit_tree() -> void:
	_flush_stats()
	Engine.time_scale = 1.0
	get_tree().physics_interpolation = _prev_interpolation

# ---------------------------------------------------------------- frame loops

func _process(delta: float) -> void:
	_debug_label.visible = SHOW_DEBUG
	if SHOW_DEBUG:
		_debug_label.text = "DEBUG  room: %s   hp: %d   ammo: %d   fps: %d" % [current_room, nash.hp, nash.ammo, Engine.get_frames_per_second()]
	if get_tree().paused:
		return
	_clock += delta
	state.play_time += delta
	_stat_time += delta
	# screen shake and the red hurt flash fade out
	_shake = move_toward(_shake, 0.0, delta * 28.0)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_hurt = move_toward(_hurt, 0.0, delta * 2.2)
	(_vignette.material as ShaderMaterial).set_shader_parameter("hurt", _hurt)
	_bag_full_t = maxf(0.0, _bag_full_t - delta)
	_run_tasks(delta)
	_run_atmosphere(delta)
	_update_search(delta)
	_update_regen(delta)
	_update_controls()
	_update_notices(delta)
	_update_subtitle(delta)
	_update_clouds(delta)
	_update_drips(delta)
	_guard_shout_t = maxf(0.0, _guard_shout_t - delta)
	# The coworker scene starts a while after the alarms begin.
	if state.alarm and not state.scene_started and not _fading and not _modal_open:
		_alarm_t += delta
		if _alarm_t >= SCENE_DELAY:
			_attack_scene_start()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if _end_ready:
		if Input.is_action_just_pressed("ls_action_a") or Input.is_action_just_pressed("ls_action_b"):
			_back_to_menu()
		return
	if _fading:
		return
	if _modal_open:
		# A or B closes the note (ignore the very press that opened it).
		if Engine.get_physics_frames() > _modal_frame + 2 \
				and (Input.is_action_just_pressed("ls_action_a") or Input.is_action_just_pressed("ls_action_b")):
			_close_modal()
		return
	if nash.in_locker:
		# A or B steps out of the locker (ignore the press that went in; not during the first attack).
		if not _scene_active and Engine.get_physics_frames() > _hide_frame + 2 \
				and (Input.is_action_just_pressed("ls_action_a") or Input.is_action_just_pressed("ls_action_b")):
			_leave_locker()
		return
	if state.ended or _scene_active:
		return
	if _search_prop != null:
		return      # searching: _update_search() watches for a cancel
	_check_pickups()
	_check_triggers()
	if Input.is_action_just_pressed("ls_swap"):
		_equip(nash.inv.cycle_weapon())
	var target := _find_target()
	for p in props.values():
		p.set_hint(p == target)
	if target != null and Input.is_action_just_pressed("ls_action_a"):
		_interact(target)
	elif Input.is_action_just_pressed("ls_action_b") and not _scene_active and not _controls.wheel_open:
		_attack()
	_bump_doors(delta, target)

## Keyboard: pause (Esc / P), bag (I), mission log (L), quick heal (H), wheel (Tab), weapons 1-6,
## map (M).
func _unhandled_input(event: InputEvent) -> void:
	if _end_ready or kit_up:
		return
	if event.is_action_pressed("ls_pause"):
		if _bag_open:
			_close_bag()
		elif _map_open:
			_close_map()
		else:
			_toggle_pause()
	elif event.is_action_pressed("ls_map"):
		_toggle_map()
	elif event.is_action_pressed("ls_bag"):
		_toggle_bag()
	elif event.is_action_pressed("ls_log"):
		_log.toggle()
	elif get_tree().paused:
		return
	elif event.is_action_pressed("ls_heal"):
		_quick_heal()
	elif event.is_action_pressed("ls_wheel"):
		_toggle_wheel()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
		var w: String = LsEngine.WEAPON_ORDER[event.physical_keycode - KEY_1]
		if nash.inv.has_weapon(w):
			_equip(w)

func _toggle_pause() -> void:
	if state.ended:
		return
	if _bag_open:
		_close_bag()
		return
	if _map_open:
		_close_map()
		return
	_close_wheel()
	if hosted:
		# Hub: the kit's pause menu (it pauses the tree and saves through the host).
		if not kit_up:
			pause_requested.emit()
		return
	get_tree().paused = not get_tree().paused
	_pause_box.visible = get_tree().paused
	if get_tree().paused:
		_save_game()

func _notification(what: int) -> void:
	# Phones suspend apps: keep the room checkpoint up to date.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

## Runs `fn` after `sec` seconds of unpaused play. (Not create_timer: that keeps running while paused.)
func _after(sec: float, fn: Callable) -> void:
	_tasks.append({"t": sec, "fn": fn})

func _run_tasks(delta: float) -> void:
	var due: Array = []
	for task in _tasks:
		task.t -= delta
		if task.t <= 0.0:
			due.append(task)
	for task in due:
		_tasks.erase(task)
		task.fn.call()

# ---------------------------------------------------------------- save / continue

func _save_game() -> void:
	_flush_stats()
	if state.ended or current_room == "" or discard:
		return
	LsSave.save(self)

## Adds the play time since the last flush to the statistics.
func _flush_stats() -> void:
	if _stat_time > 0.0:
		LsStats.add_time(_stat_time)
		_stat_time = 0.0

func _apply_save(data: Dictionary) -> void:
	var st: Dictionary = data.state
	for k in st:
		state[k] = st[k]
	# JSON gives numbers back as floats.
	state.kills = int(state.kills)
	state.deaths = int(state.deaths)
	state.play_time = float(state.play_time)
	var n: Dictionary = data.nash
	nash.hp = int(n.hp)
	nash.inv.from_dict(n.get("inv", {}))
	nash.armor = int(n.get("armor", 0))
	nash.armor_kind = str(n.get("armor_kind", ""))
	state.difficulty = int(state.get("difficulty", 1))
	state.searches = int(state.get("searches", 0))
	_drop_count = int(data.get("drop_count", 0))
	_controls.show_swap = nash.inv.weapons.size() >= 2
	state.money_earned = int(state.get("money_earned", 0))
	# v0.5: the siren goes on until the alarm is switched off (also after Continue).
	if state.alarm:
		if not state.flags.has("alarm_off"):
			_siren.play()
		_after(25.0, _intercom_03)

func _back_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if hosted:
		menu_requested.emit()     # hub: the game's Landing
		return
	get_tree().change_scene_to_file(MENU_SCENE)


# ---------------------------------------------------------------- rooms

## Is a prop / enemy / person with this "when" tag present right now?
func _present(when: String) -> bool:
	match when:
		"calm":
			return not state.alarm
		"alarm":
			return state.alarm
		"after_attack":
			return state.attack_done
		"window":
			return state.flags.has("window_broken")     # v0.5: came in through the call-center window
	return true

func _load_room(room_id: String, spawn_name: String) -> void:
	_cancel_search()
	if room_root != null:
		remove_child(room_root)
		room_root.queue_free()
	for n in _room_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_room_nodes.clear()
	_room_lights.clear()
	var data: Dictionary = _rooms[room_id]
	_theme = data.get("theme", "plant")
	room_root = Node2D.new()
	add_child(room_root)
	move_child(room_root, 0)   # behind the actors
	var rows: Array = data.rows
	room_root.add_child(_build_tiles(rows, _theme))
	props.clear()
	enemies.clear()
	_people.clear()
	_clouds.clear()
	hide_prop = null
	current_room = room_id
	_dusk = room_id == "parking_lot" and not state.alarm
	_dawn = EXIT_ROOMS.has(room_id) and state.alarm
	_decals.clear()
	for pd in data.props:
		if not _present(pd.get("when", "")) or state.taken.has(pd.id):
			continue
		_make_prop(pd)
	for d in state.drops:
		if d.room == room_id:
			_make_prop(d.data)
	checkpoint = {"room": room_id, "spawn": spawn_name}
	_build_astar(rows)
	# Place Nash.
	var sp: Dictionary = data.spawns[spawn_name]
	nash.teleport((Vector2(sp.cell) + Vector2(0.5, 0.5)) * TILE)
	nash.set_facing({"down": LsEngine.Facing.DOWN, "left": LsEngine.Facing.LEFT,
		"right": LsEngine.Facing.RIGHT, "up": LsEngine.Facing.UP}[sp.face])
	_spawn_enemies()
	_spawn_people()
	if _theme != "lot":
		_build_lights(rows)
	_fit_camera(Vector2(rows[0].length(), rows.size()) * TILE)
	camera.reset_smoothing()
	_on_room_entered()

func _add_actor(n: Node) -> void:
	actors.add_child(n)
	_room_nodes.append(n)

## Floor and wall tiles for the room: walls know which sides touch open floor (ink lines, front
## face when a floor is south of them), floors get variants and a shadow under north walls.
## Hedges ('H', outdoors) work the same way with their own tiles.
func _build_tiles(rows: Array, theme: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = LsTiles.build(theme)
	layer.z_index = -10
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			var h: int = _cell_hash(x, y)
			if ch == "H":
				layer.set_cell(Vector2i(x, y), LsTiles.SOURCE_ID, LsTiles.hedge_coord(_open_mask(rows, x, y)))
			elif ch == "#" or ch == "A":
				var mask: int = _open_mask(rows, x, y)
				var variant: int = 0
				if mask & 4 != 0:
					variant = 0 if h % 8 < 5 else (1 if h % 8 < 7 else 2)
					if theme == "lot":
						variant = 1 + h % 2    # the building front: windows everywhere
				layer.set_cell(Vector2i(x, y), LsTiles.SOURCE_ID, LsTiles.wall_coord(mask, variant, ch == "A"))
			else:
				var v: int = (x + y) % 2
				if h % 29 == 0:
					v = 2
				elif h % 37 == 0:
					v = 3
				var shadow: bool = y > 0 and _is_wall(rows, x, y - 1)
				layer.set_cell(Vector2i(x, y), LsTiles.SOURCE_ID, LsTiles.floor_coord(v, shadow))
	return layer

func _is_wall(rows: Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return true
	var ch: String = rows[y][x]
	return ch == "#" or ch == "A" or ch == "H"

## Bit mask of the sides (N=1 E=2 S=4 W=8) that touch open floor.
func _open_mask(rows: Array, x: int, y: int) -> int:
	var m := 0
	if not _is_wall(rows, x, y - 1):
		m |= 1
	if not _is_wall(rows, x + 1, y):
		m |= 2
	if not _is_wall(rows, x, y + 1):
		m |= 4
	if not _is_wall(rows, x - 1, y):
		m |= 8
	return m

func _cell_hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % 100003

## Ceiling lights on a loose grid (white pools of light on the floor). Not outdoors.
func _build_lights(rows: Array) -> void:
	var th := LsTiles.theme_of(_theme)
	var cols: int = rows[0].length()
	for cy in range(3, rows.size() - 1, 6):
		for cx in range(4, cols - 1, 8):
			if _is_wall(rows, cx, cy):
				continue
			var l := PointLight2D.new()
			l.texture = LsFx.light_texture()
			l.texture_scale = 1.6
			l.energy = 0.9
			l.color = th.light
			l.position = (Vector2(cx, cy) + Vector2(0.5, 0.5)) * TILE
			room_root.add_child(l)
			_room_lights.append(l)

# ---------------------------------------------------------------- pathfinding

func _build_astar(rows: Array) -> void:
	var cols: int = rows[0].length()
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, cols, rows.size())
	_astar.cell_size = Vector2(TILE, TILE)
	_astar.offset = Vector2(TILE, TILE) * 0.5
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	for y in rows.size():
		for x in cols:
			if _is_wall(rows, x, y):
				_astar.set_point_solid(Vector2i(x, y), true)
	for p in props.values():
		if p.data.get("solid", true) and not p.data.has("pos"):
			var r: Rect2i = p.data.rect
			for cy in range(r.position.y, r.end.y):
				for cx in range(r.position.x, r.end.x):
					if _astar.is_in_boundsv(Vector2i(cx, cy)):
						_astar.set_point_solid(Vector2i(cx, cy), true)

func _cell_of(px: Vector2) -> Vector2i:
	var c := Vector2i(int(floorf(px.x / TILE)), int(floorf(px.y / TILE)))
	var reg := _astar.region
	return Vector2i(clampi(c.x, 0, reg.size.x - 1), clampi(c.y, 0, reg.size.y - 1))

func _nearest_open(c: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if _astar.is_in_boundsv(n) and not _astar.is_point_solid(n):
					return n
	return c

## Waypoints (tile centers) from one pixel position to another, around walls and solid props.
func path_to(from_px: Vector2, to_px: Vector2) -> PackedVector2Array:
	if _astar == null:
		return PackedVector2Array([to_px])
	var a := _cell_of(from_px)
	var b := _cell_of(to_px)
	if _astar.is_point_solid(a):
		a = _nearest_open(a)
	if _astar.is_point_solid(b):
		b = _nearest_open(b)
	return _astar.get_point_path(a, b, true)

## The center of a walkable tile at or near a pixel position (searching infected wander there).
func open_point_near(px: Vector2) -> Vector2:
	if _astar == null:
		return px
	var c := _cell_of(px)
	if _astar.is_point_solid(c):
		c = _nearest_open(c)
	return (Vector2(c) + Vector2(0.5, 0.5)) * TILE

## Makes a prop from room data (birds become a flock node instead). Returns the node.
func _make_prop(pd: Dictionary) -> Node:
	if pd.kind == "birds":
		var b := Birds.new()
		b.setup(pd, self, nash, _dawn)
		_add_actor(b)
		return b
	if state.left.has(pd.id):
		pd = pd.duplicate()
		pd["amount"] = int(state.left[pd.id])
	var prop := Prop.new()
	prop.setup(pd, self)
	_add_actor(prop)
	props[pd.id] = prop
	# The plant's east door stays open after the scene.
	if pd.id == "door_east" and state.door_open:
		prop.refresh()
	return prop

func _spawn_enemies() -> void:
	var data: Dictionary = _rooms[current_room]
	for ed in data.get("enemies", []):
		if not _present(ed.get("when", "")) or int(ed.get("diff", 0)) > int(state.difficulty):
			continue
		if state.turned.has(ed.id):
			continue      # v0.5: killed by the infected: he is one of them now (spawned below)
		_spawn_enemy(ed)
	# v0.5: people the infected killed in this room are infected now
	for pid in state.turned:
		var t: Dictionary = state.turned[pid]
		if t.room != current_room or state.dead.has(pid + "_z"):
			continue
		_spawn_enemy(_turned_data(pid, t))

## The walker a dead person becomes (room data built from state.turned).
func _turned_data(pid: String, t: Dictionary) -> Dictionary:
	var pos := Vector2(float(t.x), float(t.y))
	return {"id": pid + "_z", "kind": "walker", "cell": Vector2i(int(pos.x / TILE), int(pos.y / TILE)),
		"pos": pos, "shirt": str(t.get("shirt", "6a6a70")), "patrol": []}

## One enemy from room data. Returns the node (or null for one already dead).
func _spawn_enemy(ed: Dictionary) -> Node2D:
	var dead: bool = state.dead.has(ed.id)
	match ed.kind:
		"guard":
			var g := Guard.new()
			g.setup(ed, self, nash)
			if dead:
				g.set_down()
			_add_actor(g)
			if not dead:
				enemies.append(g)
			return g
		"shooter":
			var sh := Shooter.new()
			sh.setup(ed, self, nash)
			if dead:
				sh.set_down()
			_add_actor(sh)
			if not dead:
				enemies.append(sh)
			return sh
	if dead:
		return null
	var w := Walker.new()
	w.setup(ed, self, nash)
	_add_actor(w)
	enemies.append(w)
	return w

## Ambient people (a cleaner, a tech, survivors hiding...). Not enemies.
## v0.5: they react to how far the night has gone (react()), and the ones the infected killed are gone.
func _spawn_people() -> void:
	var stage := _night_stage()
	for nd in _rooms[current_room].get("npcs", []):
		if not _present(nd.get("when", "")) or state.dead.has(nd.id) or state.turned.has(nd.id):
			continue
		var p := Npc.new()
		p.setup(nd, self, nash)
		_add_actor(p)
		_people.append(p)
		var order := ["alarm", "attack", "kill"]
		for st in order.slice(0, order.find(stage) + 1):     # "calm": none
			p.react(st)

## How far the night has gone, for the survivors: "calm", "alarm", "attack" or "kill" (Nash has
## taken one down).
func _night_stage() -> String:
	if state.kills > 0:
		return "kill"
	if state.attack_done:
		return "attack"
	if state.alarm:
		return "alarm"
	return "calm"

## Tells every survivor in the room that the night moved on (shouted, it just happened).
func _people_react(stage: String) -> void:
	for p in _people:
		if is_instance_valid(p):
			p.react(stage, true)

# ---------------------------------------------------------------- who is who (v0.5)

## Every living person in the room the infected can go after: Nash, guards, barricade shooters and
## survivors. (Each one says itself whether it can be seen right now: is_prey().)
func humans() -> Array:
	var out: Array = [nash]
	for e in enemies:
		if is_instance_valid(e) and not e is Walker:
			out.append(e)
	for p in _people:
		if is_instance_valid(p):
			out.append(p)
	return out

## The living infected in the room.
func infected() -> Array:
	var out: Array = []
	for e in enemies:
		if is_instance_valid(e) and e is Walker:
			out.append(e)
	return out

func is_live_enemy(e: Node) -> bool:
	return is_instance_valid(e) and e in enemies

## Per-room things: light, music, story flags, objective, checkpoint save.
func _on_room_entered() -> void:
	_flicker_mult = 1.0
	state.visited[current_room] = true
	for p in props.values():
		if p.kind == "lamp_post":
			p.set_lamp(_dusk)
	# Chill music until the alarm: lo-fi outside and in the plant, lounge in the lobby.
	if not state.alarm:
		_music("lounge" if current_room == "lobby" else "lofi")
	if current_room == "lobby":
		state.entered_lobby = true
		if state.alarm and not state.lobby_alarm_seen:
			state.lobby_alarm_seen = true
			_after(1.2, _intercom_say.bind("vo_claudius_day0_intercom_07"))
	if current_room == "security_hall" and not state.hall_intro:
		# Nash is climbing through the building: the intercom tells everybody to go back.
		state.hall_intro = true
		_after(1.0, _intercom_say.bind("vo_claudius_day0_intercom_05"))
		_after(6.5, _nash_say.bind(LsText.NASH.vo_nash_day0_05))
	# Nash's line the first time he walks into some rooms (after the alarm, so the calm opening
	# stays quiet), and a few special ones.
	if state.alarm and LsText.ROOM_LINES.has(current_room) and not state.room_said.has(current_room):
		state.room_said[current_room] = true
		_after(0.8, _nash_think.bind(LsText.ROOM_LINES[current_room]))
	if current_room == "server_room" and not state.room_said.has("server_room"):
		# the one time Nash guesses (spec: "some AI thing went wrong", generic, in passing)
		state.room_said["server_room"] = true
		_after(1.2, _nash_say.bind(LsText.NASH.vo_nash_day0_15))
	if current_room == "open_office" and state.attack_done and not state.dead.has("gary") and not _gary_said:
		_gary_said = true
		_after(3.2, _nash_think.bind(LsText.NASH.vo_nash_day0_16))
	if current_room == "cafeteria" and state.attack_done and not state.dead.has("brute_cook") \
			and not state.room_said.has("brute"):
		state.room_said["brute"] = true
		_after(3.6, _nash_think.bind(LsText.NASH.vo_nash_day0_25))
	_refresh_objective()
	if _dawn and not state.ended:
		_start_ending(EXIT_ROOMS[current_room])
	else:
		_save_game()

## Camera never shows outside the room; rooms smaller than the screen are centered.
## (The visible world area is the screen size divided by the zoom.)
func _fit_camera(room_px: Vector2) -> void:
	var view := get_viewport_rect().size / WORLD_ZOOM
	var pad := Vector2(maxf(0.0, (view.x - room_px.x) * 0.5), maxf(0.0, (view.y - room_px.y) * 0.5))
	camera.limit_left = int(-pad.x)
	camera.limit_top = int(-pad.y)
	camera.limit_right = int(room_px.x + pad.x)
	camera.limit_bottom = int(room_px.y + pad.y)

## Fade out, swap rooms, fade in. `heal` = the death respawn (full health back).
func _change_room(room_id: String, spawn_name: String, heal: bool = false) -> void:
	_cancel_search()
	_close_wheel()
	_fading = true
	nash.frozen = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.2)
	tw.tween_callback(_swap_room.bind(room_id, spawn_name, heal))
	tw.tween_property(_fade, "color:a", 0.0, 0.25)
	tw.tween_callback(_end_fade)

func _swap_room(room_id: String, spawn_name: String, heal: bool) -> void:
	if nash.in_locker:
		nash.set_hidden(false)
	_load_room(room_id, spawn_name)
	if heal:
		nash.heal_full()
		_save_game()
		_update_hp_hud()

func _end_fade() -> void:
	_fading = false
	if not state.ended:
		nash.frozen = false

# ---------------------------------------------------------------- objective and mission log

## Updates the quest log from the story state (LsEngine.quest_status): new quests are added (with
## a "New quest" notice), finished ones ticked ("Done"). ESCAPE! stays pinned on top.
func _refresh_objective() -> void:
	if state.ended:
		_objective_text = ""
		_log.visible = false
		return
	var ctx := {"wrench": nash.has_wrench, "pistol": nash.has_pistol, "knife": nash.inv.has_weapon("knife"),
		"room": current_room}
	var entries: Array = []
	var newest_open := ""
	for qid in LsEngine.QUESTS:
		var st := LsEngine.quest_status(qid, state, ctx)
		if st == "hidden":
			continue
		if not qid in state.quests:
			state.quests.append(qid)
			if st == "active" and state.quests.size() > 1:
				_notice(tr(LsText.MSG.new_quest) % tr(LsText.QUEST[qid]), Color("ffd479"))
		if st == "done" and not state.quests_done.has(qid):
			state.quests_done[qid] = true
			if qid != "enter":
				_notice(tr(LsText.MSG.quest_done) % tr(LsText.QUEST[qid]), Color("8fe07a"))
	# v0.5: ESCAPE! is flagged "main" (listed first), side quests "side" (the header prefers the main
	# route: playtest "I have the keycard, but the only quest is Marisol's gift").
	var newest_side := ""
	for qid in state.quests:
		var done: bool = state.quests_done.has(qid)
		var side: bool = qid in LsEngine.SIDE_QUESTS
		entries.append({"text": LsText.QUEST[qid], "done": done, "main": qid == LsEngine.MAIN_QUEST, "side": side})
		if not done and qid != LsEngine.MAIN_QUEST:
			if side:
				newest_side = qid
			else:
				newest_open = qid
	if newest_open == "":
		newest_open = newest_side
	_objective_text = tr(LsText.QUEST[newest_open]) if newest_open != "" else ""
	_log.set_entries(entries)
	_log.visible = true

## The newest open main-route step (else side quest) as shown in the log's header (tests read this).
func objective_text() -> String:
	return _objective_text

## Is this quest open (in the log, not ticked)? (tests)
func quest_open(qid: String) -> bool:
	return qid in state.quests and not state.quests_done.has(qid)

# ---------------------------------------------------------------- interaction

func puzzle_flow(puzzle_id: String) -> int:
	return LsEngine.puzzle_flow(puzzle_id, state.puzzles[puzzle_id])

## Is this door still locked? (see the "lock" values in last_shift_rooms.gd)
func door_locked(door_data: Dictionary) -> bool:
	match door_data.get("lock", ""):
		"keycard":
			return not state.has_keycard and not state.door_open
		"sec_key":
			return not state.has_sec_key
		"maint":
			return not state.has_maint_key
		"pump":
			return not state.solved.pump
		"lockdown":
			return state.alarm and not state.solved.vents
		"staff":
			return not state.attack_done
		"elevator":
			return state.alarm      # "Please do not use the elevators."
		"card":
			return not state.has_keycard     # the cooling floor (the coworker's keycard)
		"dock":
			return not state.has_sec_key     # the loading dock roll-up door
		"chain":
			return not state.flags.has("fire_cut")   # the fire exit, chained shut
	return false

## The prop just in front of Nash that A can do something with, or null.
func _find_target() -> Prop:
	var point := nash.position + LsEngine.facing_to_vector(nash.facing) * INTERACT_REACH
	var best: Prop = null
	var best_d := INF
	for p in props.values():
		if p.can_use() and p.rect_px().grow(6.0).has_point(point):
			var d: float = p.rect_px().get_center().distance_to(nash.position)
			if d < best_d:
				best_d = d
				best = p
	return best

## The word on the A button for this target (a UI key in last_shift_text.gd).
func _a_action(target: Prop) -> String:
	if nash.in_locker:
		return "act_exit"
	if _search_prop != null:
		return "act_searching"
	if target == null:
		return "act_use"
	match target.kind:
		"door", "elevator":
			if target.data.get("lock", "") == "chain" and door_locked(target.data) and state.flags.has("cutters"):
				return "act_cut"
			return "act_open"
		"terminal", "plaque", "cake":
			return "act_read"
		"npc_dwayne":
			return "act_talk"
		"valve", "vent":
			return "act_turn"
		"workbench", "gun_cabinet":
			return "act_take"
		"vending":
			return "act_buy"
		"chiller", "lockdown_panel", "sealed_door", "gauge":
			return "act_look"
		"locker":
			return "act_hide" if target.searched() else "act_search"
		"alarm_panel":
			return "act_switch"
		"eotm_wall", "corkboard":
			return "act_read"
		"corpse":
			if target.data.get("first", false) and not target.searched():
				return "act_inspect"
	if target.is_container() and not target.searched():
		return "act_search"
	return "act_use"

func _interact(p: Prop) -> void:
	if _scene_active:
		return       # the first attack is playing (camera on the scene)
	if p.is_container() and not p.searched():
		_start_search(p)
		return
	match p.kind:
		"valve", "vent": _use_dial(p)
		"terminal", "plaque", "npc_dwayne", "cake", "corkboard": _open_note(p.data.email)
		"alarm_panel": _use_alarm_panel()
		"eotm_wall": _read_eotm_wall()
		"locker": enter_locker(p)
		"door", "elevator": _use_door(p)
		"workbench": _use_workbench()
		"vending": _use_vending(p)
		"gun_cabinet": _use_gun_cabinet()
		"gauge": _use_gauge(p)
		"lockdown_panel":
			var n := LsEngine.puzzle_target("vents")
			_toast(tr(LsText.MSG.panel_hint) % [n, puzzle_flow("vents")])
		"sealed_door":
			_play(LsSfx.buzz())
			_toast(LsText.MSG.hallc)
		"chiller":
			_toast(LsText.MSG.chiller_hint)

func _use_gauge(p: Prop) -> void:
	var puzzle: String = p.data.get("puzzle", "chiller")
	if puzzle == "pump":
		_toast(tr(LsText.MSG.pump_hint) % [LsEngine.puzzle_target("pump"), puzzle_flow("pump")])
	else:
		_toast(LsText.MSG.chiller_hint)

## Valves and vents: toggle one; at exactly the target flow the puzzle is solved.
func _use_dial(p: Prop) -> void:
	var puzzle: String = p.data.puzzle
	if state.solved[puzzle]:
		_toast(LsText.MSG.vent_done if puzzle == "vents" else LsText.MSG.valve_done)
		return
	var i: int = p.data.index
	state.puzzles[puzzle][i] = not state.puzzles[puzzle][i]
	_play(LsSfx.click())
	_refresh_dials()
	if LsEngine.puzzle_status(puzzle, puzzle_flow(puzzle)) == "ok":
		_on_puzzle_solved(puzzle)

func _refresh_dials() -> void:
	for q in props.values():
		if q.kind in ["valve", "vent", "gauge", "chiller", "lockdown_panel", "tv"]:
			q.refresh()

func _refresh_doors() -> void:
	for q in props.values():
		if q.kind == "door" or q.kind == "elevator":
			q.refresh()

func _on_puzzle_solved(puzzle: String) -> void:
	state.solved[puzzle] = true
	_play(LsSfx.pickup())
	match puzzle:
		"chiller":
			_on_chiller_solved()
		"pump":
			_toast(LsText.MSG.pump_done)
		"vents":
			_toast(LsText.MSG.vents_set)
	_refresh_doors()
	_refresh_objective()

## Walking into a door for a moment opens it (A still works too). A locked door only complains
## once per push.
func _bump_doors(delta: float, target: Prop) -> void:
	var dir: Vector2 = nash.input_dir()
	if dir.length() < 0.5:
		_bump_t = 0.0
		return
	if target == null or not (target.kind in ["door", "elevator"]) or _bump_t < 0.0:
		return
	var f := LsEngine.facing_to_vector(nash.facing)
	if dir.normalized().dot(f) > 0.7 and nash.get_real_velocity().length() < 30.0:
		_bump_t += delta
		if _bump_t >= BUMP_SECONDS:
			_bump_t = -1.0      # wait for the stick / key to be let go before trying again
			_interact(target)
	else:
		_bump_t = 0.0

# ---------------------------------------------------------------- searching and hiding

## Starts searching a locker / desk / cabinet: 2 seconds, Nash stands still, a ring fills.
## Moving (or getting hit) cancels it. Rummaging is a little noisy.
func _start_search(p: Prop) -> void:
	_search_prop = p
	_search_t = 0.0
	p.search_progress = 0.0
	nash.frozen = true
	_play(LsSfx.rummage(), -6.0)
	for e in enemies:
		if is_instance_valid(e) and e.position.distance_to(nash.position) < SEARCH_NOISE:
			e.investigate(nash.position)

func _update_search(delta: float) -> void:
	if _search_prop == null:
		return
	if not is_instance_valid(_search_prop) or nash.input_dir().length() > 0.3:
		_cancel_search()
		return
	_search_t += delta
	_search_prop.search_progress = clampf(_search_t / LsEngine.SEARCH_SECONDS, 0.0, 1.0)
	if _search_t >= LsEngine.SEARCH_SECONDS:
		_finish_search()

func _cancel_search() -> void:
	if _search_prop == null:
		return
	if is_instance_valid(_search_prop):
		_search_prop.search_progress = -1.0
		_search_prop.refresh()
	_search_prop = null
	if not _fading and not _modal_open and not nash.in_locker:
		nash.frozen = false

## The search is done: everything that fits goes in the bag, the rest is left on the floor.
func _finish_search() -> void:
	var p := _search_prop
	_cancel_search()
	state.searched[p.id] = true
	_play(LsSfx.click())
	var found: Array = []
	var full := false
	for entry in p.data.get("loot", []):
		var item: String = entry.item
		var n := int(entry.n)
		var got := _give(item, n)
		if got > 0:
			found.append(_loot_label(item, got))
			_play(LsSfx.pickup())
		if got < n:
			full = true
			_drop(_pickup_kind(item), nash.position + Vector2(0, 14), {"amount": n - got, "fresh": true})
	var msg := tr(LsText.MSG.found) % ", ".join(found) if not found.is_empty() else tr(LsText.MSG.found_nothing)
	if full:
		msg += "\n" + tr(LsText.MSG.bag_full)
	_toast(msg, 2.6)
	state.searches = int(state.searches) + 1
	if state.searches >= LsEngine.SCAVENGER_COUNT:
		_achieve("scavenger")
	p.refresh()
	# Some things come with something to read (Nash's locker, Marisol's gift, the first body).
	if p.data.get("first", false):
		state.flags["inspected"] = true
		_open_note("zombie_body")
		_after(0.4, _nash_say.bind(LsText.NASH.vo_nash_day0_12))
		_achieve("coroner")
	elif p.data.has("note"):
		_open_note(p.data.note)
	_refresh_doors()
	_refresh_objective()
	_update_hp_hud()

## The alarm panel in the security office: the siren and the red lights go off for good.
func _use_alarm_panel() -> void:
	if not state.alarm or state.flags.has("alarm_off"):
		_toast(LsText.MSG.alarm_already, 1.6)
		return
	state.flags["alarm_off"] = true
	_siren.stop()
	_play(LsSfx.click())
	_toast(LsText.MSG.alarm_off, 2.4)
	_after(1.0, _nash_think.bind(LsText.NASH.vo_nash_day0_18))
	_achieve("lights_out")
	for q in props.values():
		q.refresh()
	_refresh_objective()

## Gary's Employee of the Month wall: 36 Garys and Nash's misspelled Honorable Mention.
func _read_eotm_wall() -> void:
	_open_note("eotm_wall")
	if not state.flags.has("eotm_seen"):
		state.flags["eotm_seen"] = true
		_after(0.3, _nash_say.bind(LsText.NASH.vo_nash_day0_13))
		_after(2.6, _nash_say.bind(LsText.NASH.vo_nash_day0_14))
		_achieve("honorable")
		_refresh_objective()

## "2 x bullets", "$3", "first-aid kit"... for the "Found:" message.
func _loot_label(item: String, n: int) -> String:
	if item == "money":
		return "$%d" % n
	var name := tr(LsText.LOOT_NAMES.get(item, item)).to_lower()   # hub: "Snack", "Bullets" are keys
	return name if n <= 1 else "%d x %s" % [n, name]

## Pickup prop kind for a loot item (what lies on the floor when the bag is full).
func _pickup_kind(item: String) -> String:
	return "ammo" if item == "bullets" else item

## Gives Nash `n` of `item`. Returns how many he could take (the bag may be full).
func _give(item: String, n: int) -> int:
	match item:
		"money":
			nash.inv.money += n
			state.money_earned = int(state.money_earned) + n
			LsStats.note_money(int(state.money_earned))
			return n
		# v0.5
		"arm":
			if nash.inv.add_weapon("arm"):
				_toast(LsText.MSG.got_arm, 3.0)
				_on_weapons_changed()
				_after(3.2, _nash_say.bind(LsText.NASH.vo_nash_day0_30))
			return 1
		"coolant":
			var first: bool = not nash.inv.has_weapon("coolant")
			var got: int = nash.inv.add_cans(n)
			if got > 0:
				_toast(tr(LsText.MSG.got_coolant) % got, 2.6)
				_on_weapons_changed()
				if first:
					_after(2.8, _nash_say.bind(LsText.NASH.vo_nash_day0_31))
			return got
		"chef_hat":
			if nash.inv.add_hat("chef"):
				_toast(LsText.MSG.got_chef_hat, 2.6)
			return 1
		"knife":
			if nash.inv.add_weapon("knife"):
				_toast(LsText.MSG.got_knife, 3.0)
				_on_weapons_changed()
				_after(3.2, _nash_say.bind(LsText.NASH.vo_nash_day0_20))
				_achieve("birthday")
			return 1
		"keycard":
			state.has_keycard = true
			return 1
		"maint_key":
			state.has_maint_key = true
			return 1
		"sec_key":
			state.has_sec_key = true
			return 1
		"bullets":
			return nash.inv.add_ammo(n)
		"vest":
			if nash.wear("vest", LsEngine.ARMOR.vest):
				_toast(tr(LsText.MSG.got_vest) % nash.armor, 2.6)
				_after(2.8, _nash_say.bind(LsText.NASH.vo_nash_day0_24))
			else:
				_toast(LsText.MSG.armor_better, 1.8)
			return 1
		"riot":
			nash.wear("riot", LsEngine.ARMOR.riot)
			_toast(tr(LsText.MSG.got_riot) % nash.armor, 2.6)
			_after(2.8, _nash_say.bind(LsText.NASH.vo_nash_day0_19))
			_achieve("riot_ready")
			return 1
		"cutters":
			state.flags["cutters"] = true
			return 1
		"party_hat":
			if nash.inv.add_hat("party"):
				_toast(LsText.MSG.got_hat, 2.6)
			return 1
	return nash.inv.add(item, n)

## Climbs into a searched locker. Whoever was hunting Nash either saw it (close, clear line: it
## comes to drag him out) or not (it has lost the trail and searches in a random direction).
func enter_locker(p: Prop) -> void:
	hide_prop = p
	_hide_frame = Engine.get_physics_frames()
	var hunted := false
	var seen := false
	for e in enemies:
		if not is_instance_valid(e) or not e.is_hunting():
			continue
		hunted = true
		if e.position.distance_to(nash.position) < SEE_HIDE_RANGE and e.has_line_to_nash():
			e.saw_hide(p)
			seen = seen or e is Walker
		else:
			e.lose_trail()
	nash.set_hidden(true)
	state.flags["hid"] = true
	p.refresh()
	_play(LsSfx.click())
	_refresh_objective()
	if seen:
		_toast(LsText.MSG.seen_hiding, 2.0)
	elif hunted:
		_toast(LsText.MSG.lost_trail, 2.4)
	elif _toast_label.text == "":
		_toast(LsText.MSG.hiding, 2.0)

func _leave_locker() -> void:
	nash.set_hidden(false)
	if hide_prop != null:
		hide_prop.refresh()
	hide_prop = null
	_play(LsSfx.click())

## An infected saw Nash climb in: it bangs on the door and pulls him out (and hits him).
func drag_out_of_locker(e: Node2D) -> void:
	if not nash.in_locker:
		return
	_play(LsSfx.thud(), -2.0)
	shake(5.0)
	_leave_locker()
	_toast(LsText.MSG.dragged_out, 1.6)
	damage_nash(LsEngine.DAMAGE.get(e.kind, 30), e.position)

func _use_door(p: Prop) -> void:
	if p.data.get("lock", "") == "chain" and door_locked(p.data) and state.flags.has("cutters"):
		# cut the chain on the fire exit
		state.flags["fire_cut"] = true
		_play(LsSfx.click())
		_play(LsSfx.hit(), -6.0)
		_toast(LsText.MSG.chain_cut, 2.0)
		p.refresh()
		_refresh_objective()
		return
	if door_locked(p.data):
		_play(LsSfx.buzz())
		if not state.tried.has(p.id):
			state.tried[p.id] = true
			_refresh_objective()
		match p.data.get("lock", ""):
			"card":
				_toast(LsText.MSG.locked)
			"dock":
				_toast(LsText.MSG.locked_dock)
			"chain":
				_toast(LsText.MSG.locked_chain)
				if not state.room_said.has("chain"):
					state.room_said["chain"] = true
					_after(0.8, _nash_think.bind(LsText.NASH.vo_nash_day0_21))
			"lockdown":
				_toast(LsText.MSG.locked_lockdown)
				if not state.lobby_intro:
					state.lobby_intro = true
					_after(1.0, _intercom_say.bind("vo_claudius_day0_intercom_06"))
			"sec_key":
				_toast(LsText.MSG.locked_sec)
			"maint":
				_toast(LsText.MSG.locked_maint)
			"pump":
				_toast(LsText.MSG.locked_pump)
			"staff":
				_toast(LsText.MSG.locked_staff)
			"elevator":
				_toast(LsText.MSG.elevator_down)
			_:
				_toast(LsText.MSG.locked)
				_nash_say(LsText.MSG.locked_bark)
		return
	_play(LsSfx.click())
	_change_room(p.data.to, p.data.spawn)

func _use_workbench() -> void:
	if not state.attack_done:
		_toast(LsText.MSG.workbench_early)
		return
	if nash.has_wrench:
		_toast(LsText.MSG.empty)
		return
	nash.inv.add_weapon("wrench")
	nash.inv.equip("wrench")
	_play(LsSfx.pickup())
	_toast(LsText.MSG.got_wrench, 3.0)
	_on_weapons_changed()
	for q in props.values():
		if q.kind == "workbench":
			q.refresh()
	_refresh_objective()

# ---------------------------------------------------------------- weapons

## The weapon list changed (picked one up): wheel button, B icon, Nash's hands.
func _on_weapons_changed() -> void:
	_controls.show_swap = nash.inv.weapons.size() >= 2
	nash.queue_redraw()
	_update_hp_hud()

func _equip(w: String) -> void:
	if nash.inv.equip(w):
		nash.queue_redraw()
		_play(LsSfx.click(), -8.0)
		_update_controls()

func _toggle_wheel() -> void:
	if _controls.wheel_open:
		_close_wheel()
	elif nash.inv.weapons.size() >= 2 and not state.ended and not _fading:
		var items := {}
		var names := {}
		for w in LsEngine.WEAPON_ORDER:
			items[w] = {"owned": nash.inv.has_weapon(w), "count": nash.inv.count_for(w)}
			names[w] = tr(LsText.UI["w_" + w])
		_controls.wheel_items = items
		_controls.wheel_names = names
		_controls.wheel_equipped = nash.inv.equipped
		_controls.wheel_open = true
		Engine.time_scale = WHEEL_TIME_SCALE    # slow motion while choosing (like GTA)

func _close_wheel() -> void:
	if _controls != null and _controls.wheel_open:
		_controls.wheel_open = false
	Engine.time_scale = 1.0

func _on_weapon_chosen(w: String) -> void:
	if w != "" and nash.inv.has_weapon(w):
		_equip(w)
	_close_wheel()

func _attack() -> void:
	if not nash.can_attack():
		return
	match nash.inv.equipped:
		"pistol":
			_shoot()
		"coolant":
			_throw_coolant()
		_:
			_melee(nash.inv.equipped)

## Fists / knife / wrench: hits whoever is in front of Nash. Damage per weapon and target (see
## LsEngine.melee_damage). The swing's noise draws nearby infected (the knife is silent).
func _melee(w: String) -> void:
	var st: Dictionary = LsEngine.WEAPONS[w]
	nash.start_swing(st.cooldown)
	_play(LsSfx.swing())
	var f := LsEngine.facing_to_vector(nash.facing)
	for e in enemies.duplicate():
		var d: Vector2 = e.position - nash.position
		if d.length() >= st.reach or not (d.length() < 14.0 or d.normalized().dot(f) > 0.2):
			continue
		var dmg := LsEngine.melee_damage(w, e.kind, e.is_aware())
		if e.kind == "runner":
			e.hit(nash.position, 0, 0.0)      # Dwayne shrugs it off (and says so)
			continue
		if dmg <= 0:
			if not _knife_said:
				_knife_said = true
				_toast(LsText.MSG.knife_people, 2.2)
			continue
		_play(LsSfx.hit())
		LsFx.burst(actors, e.position + Vector2(0, -4), Color("e8e8f0"), 8, 120.0, 0.3)
		shake(2.0 if w != "fist" else 1.2)
		e.hit(nash.position, dmg, st.push, w)
	if st.noise > 0.0:
		for e in enemies:
			if is_instance_valid(e) and e.position.distance_to(nash.position) < st.noise:
				e.investigate(nash.position)

## An infected went down. v0.5: only Nash's kills count (a guard's or a shooter's do not), they go
## into the statistics per weapon, and there is no "Infected down: N" message any more.
func on_walker_killed(w: Node2D) -> void:
	state.dead[w.id] = true
	var by: String = w.last_hit_by
	var nash_kill: bool = by == "" or by in LsEngine.WEAPON_ORDER
	if nash_kill:
		state.kills += 1
		var wid: String = by if by != "" else nash.inv.equipped
		state.weapon_kills[wid] = int(state.weapon_kills.get(wid, 0)) + 1
		LsStats.add_kill(wid, state.kills)
		LsSettings.buzz(30)
	enemies.erase(w)
	_play(LsSfx.hit())
	var where: Vector2 = w.position
	var was_runner: bool = w.is_runner
	var kind: String = w.kind
	var shirt := ""
	if w._shirt.a > 0.0:
		shirt = w._shirt.to_html(false)
	w.queue_free()
	# v0.5: more blood: a big burst, chunks, and splats all around
	LsFx.burst(actors, where, Color("8a0e12"), 28, 190.0, 0.55, 3.4)
	LsFx.burst(actors, where + Vector2(0, -6), Color("4a0608"), 10, 120.0, 0.6, 4.2)
	for i in 6:
		_splat(where + Vector2(randf_range(-30, 30), randf_range(-14, 22)), randf_range(3.0, 7.0))
	# The body stays, in a pool of blood, and can be searched. The very first one is the
	# "Inspect the body" quest.
	var first: bool = nash_kill and not state.flags.has("first_body") and not state.flags.has("inspected")
	if first:
		state.flags["first_body"] = true
	var extra := {"look": "zombie", "loot": LsEngine.body_loot(w.id, kind), "first": first, "pool": 22.0}
	if shirt != "":
		extra["shirt"] = shirt
	_drop("corpse", where + Vector2(0, 4), extra)
	if was_runner:
		# Dwayne drops his security key.
		_drop("keycard", where + Vector2(22, 10), {})
		_toast(LsText.MSG.dwayne_dropped, 2.5)
		# v0.5: and Nash has a word for him
		_after(1.2, _nash_think.bind(LsText.NASH.vo_nash_day0_27))
	if kind == "brute":
		# v0.5: the cook's hat falls off (wearable, Head Chef)
		_drop("chef_hat", where + Vector2(-20, 8), {})
		_after(1.0, _nash_say.bind(LsText.NASH.vo_nash_day0_34))
	if nash_kill and state.kills == 1:
		_people_react("kill")       # the plant tech screams about it
	if kind == "gary":
		_after(0.8, _nash_say.bind(LsText.NASH.vo_nash_day0_17))
		_achieve("promotion")
	_refresh_objective()
	_update_hp_hud()

## A human (guard or shooter) was knocked out, never killed. He can be searched (bullets).
func on_guard_down(g: Node2D) -> void:
	state.dead[g.id] = true
	enemies.erase(g)
	_play(LsSfx.hit())
	_drop("corpse", g.position, {"look": "hidden", "loot": LsEngine.body_loot(g.id, g.kind)})
	if not state.guard_down_said:
		state.guard_down_said = true
		_nash_say(LsText.NASH.vo_nash_day0_04)
		# v0.5: and then, to himself
		_after(LsEngine.line_seconds(LsText.NASH.vo_nash_day0_04) + 0.3, _nash_think.bind(LsText.NASH.vo_nash_day0_26))

# ---------------------------------------------------------------- the infected and other people (v0.5)

## An infected bit a guard, a shooter or a survivor.
func on_person_bitten(p: Node2D, from_pos: Vector2) -> void:
	var away: Vector2 = (p.position - from_pos).normalized()
	LsFx.burst(actors, p.position + Vector2(0, -6), Color("a8141a"), 16, 160.0, 0.4, 3.0)
	for i in 2:
		_splat(p.position + away * randf_range(6.0, 22.0) + Vector2(randf_range(-8, 8), 10), randf_range(3.0, 6.0))
	_play(LsSfx.scream(), -10.0 if p.position.distance_to(nash.position) > 200.0 else -5.0)

## An infected killed a person: a pool of blood now, one of them in a few seconds.
func on_person_killed(p: Node2D) -> void:
	state.dead[p.id] = true
	var shirt := "6a6a70"
	if p is Guard:
		shirt = Guard.UNIFORM.to_html(false)
	elif p is Shooter:
		shirt = Shooter.JACKET.to_html(false)
	elif p is Npc:
		shirt = (Npc.LOOKS.get(p.look, Npc.LOOKS.coworker).body as Color).to_html(false)
	state.turned[p.id] = {"room": current_room, "x": p.position.x, "y": p.position.y, "shirt": shirt}
	enemies.erase(p)
	_people.erase(p)
	LsFx.burst(actors, p.position, Color("8a0e12"), 26, 170.0, 0.55, 3.4)
	for i in 5:
		_splat(p.position + Vector2(randf_range(-26, 26), randf_range(-10, 20)), randf_range(3.5, 7.5))
	_after(LsEngine.TURN_SECONDS, _turn.bind(p))

## The dead person gets back up as a walker (if Nash is still in that room).
func _turn(p: Node2D) -> void:
	if not is_instance_valid(p) or not state.turned.has(p.id) or state.turned[p.id].room != current_room:
		return
	var w := _spawn_enemy(_turned_data(p.id, state.turned[p.id]))
	p.queue_free()
	if w != null:
		w.idle(0.6)
	_play(LsSfx.roar(), -6.0)
	shake(2.0)
	if not state.flags.has("saw_turn"):
		state.flags["saw_turn"] = true
		_nash_think(LsText.NASH.vo_nash_day0_33)

## A guard's baton on an infected.
func guard_hits_infected(g: Node2D, z: Node2D, dmg: int) -> void:
	if not is_live_enemy(z):
		return
	_play(LsSfx.hit(), -8.0)
	z.hit(g.position, dmg, 160.0, "guard")
	if not state.flags.has("guards_busy") and g.position.distance_to(nash.position) < 420.0:
		state.flags["guards_busy"] = true
		_after(0.6, _nash_think.bind(LsText.NASH.vo_nash_day0_32))

## A barricade shooter's bullet on an infected.
func shooter_hits_infected(sh: Node2D, z: Node2D) -> void:
	if not is_live_enemy(z):
		return
	_trace(sh.position, z.position)
	z.shot(sh.position, "shooter")

## Every hit on an infected: a red spray, a splat on the floor.
## v0.5: more of it (a bigger spray, and two or three splats thrown away from the hit).
func on_enemy_hit(e: Node2D, from_pos: Vector2) -> void:
	var away: Vector2 = (e.position - from_pos).normalized()
	LsFx.burst(actors, e.position + Vector2(0, -6), Color("a8141a"), 16, 170.0, 0.4, 3.0)
	for i in randi_range(2, 3):
		_splat(e.position + away * randf_range(8.0, 34.0) + Vector2(randf_range(-6, 6), 10), randf_range(2.5, 6.5))

## A blood splat on the floor of this room (decoration, not saved; the oldest go first).
func _splat(pos: Vector2, r: float) -> void:
	var d := Splat.new()
	d.position = pos
	d.radius = r
	d.z_index = -7
	room_root.add_child(d)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()

## A few dark red drops (drawn once).
class Splat extends Node2D:
	var radius := 4.0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x * 13.0 + position.y * 7.0)
		var col := Color("6e0a0e")
		draw_circle(Vector2.ZERO, radius, col)
		for i in 6:
			var d := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(radius, radius * 2.6)
			draw_circle(d, rng.randf_range(0.8, radius * 0.45), col)

func guard_shout(text: String, _who: Node2D = null) -> void:
	if _guard_shout_t > 0.0:
		return
	_guard_shout_t = GUARD_SHOUT_GAP
	_toast(tr(LsText.UI.guard) + ": " + tr(text), 2.0)

## Melee on Dwayne (the runner) does nothing.
func on_wrench_useless() -> void:
	_play(LsSfx.click())
	if not state.wrench_useless_said:
		state.wrench_useless_said = true
		_toast(LsText.MSG.melee_useless, 2.5)

func on_runner_woke(_r: Node2D) -> void:
	_play(LsSfx.roar())

## A screamer noticed Nash: it shrieks and every infected in the room comes to look.
func on_screamer_shriek(s: Node2D) -> void:
	_play(LsSfx.scream(), -6.0)
	shake(3.0)
	for e in enemies.duplicate():
		if e != s and is_instance_valid(e):
			e.investigate(nash.position)

func on_shooter_fired(_s: Node2D) -> void:
	_play(LsSfx.shot(), -4.0)

func on_birds_scared(_b: Node2D) -> void:
	_play(LsSfx.flutter(), -8.0)

## Pistol: auto-aims at the nearest enemy with a clear line, in ANY direction (phone-friendly,
## Nash only has 4 facings), and turns Nash toward it. Gunshots are loud and draw infected.
func _shoot() -> void:
	var st: Dictionary = LsEngine.WEAPONS.pistol
	if nash.ammo <= 0:
		nash.start_shot(st.cooldown)
		_play(LsSfx.click())
		_toast(LsText.MSG.no_ammo, 1.2)
		return
	nash.inv.bullets -= 1
	nash.start_shot(st.cooldown)
	_play(LsSfx.shot())
	var f := LsEngine.facing_to_vector(nash.facing)
	var best: Node2D = null
	var best_d := INF
	for e in enemies:
		var d: Vector2 = e.position - nash.position
		var dist := d.length()
		if dist > float(st["range"]) or dist < 1.0:
			continue
		if not _clear_line(nash.position, e):
			continue
		if dist < best_d:
			best_d = dist
			best = e
	var end_point := nash.position + f * float(st["range"])
	if best != null:
		end_point = best.position
		nash.set_facing(LsEngine.facing_from_vector(best.position - nash.position, nash.facing))
	_trace(nash.position, end_point)
	shake(2.5)
	LsFx.burst(actors, nash.position + f * 20.0 + Vector2(0, 2), Color("ffe08a"), 6, 130.0, 0.15)
	if best != null:
		LsFx.burst(actors, best.position + Vector2(0, -4), Color("ffe08a"), 8, 120.0, 0.3)
		best.shot(nash.position, "pistol")
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.position.distance_to(nash.position) < st.noise:
			e.investigate(nash.position)
	_update_hp_hud()

## True if no wall is between Nash and `target`. (Crates do not block shots.)
func _clear_line(from: Vector2, target: Node2D) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, target.position)
	var skip: Array = [nash.get_rid(), target.get_rid()]
	skip.append_array(crate_rids())
	q.exclude = skip
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

## Physics bodies of the barricade crates (people shoot over cover).
func crate_rids() -> Array:
	var rids: Array = []
	for p in props.values():
		if p.kind == "crate":
			rids.append(p.get_rid())
	return rids

## A short bright line for the bullet, gone after a moment.
func _trace(a: Vector2, b: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([a, b])
	line.width = 2.0
	line.default_color = Color("ffe08a")
	line.z_index = 2000
	actors.add_child(line)
	_after(0.07, _free_node.bind(line))

func _free_node(n) -> void:
	if is_instance_valid(n):
		n.queue_free()

## v0.5: the coolant can. Thrown at the closest infected in range with a clear line (else a little
## ahead of Nash); it bursts into a cold cloud that slows every infected in it while it lasts. It
## hurts nobody. The hiss draws infected nearby. When the last can is gone, B goes back to a melee
## weapon.
func _throw_coolant() -> void:
	var st: Dictionary = LsEngine.WEAPONS.coolant
	if nash.inv.cans <= 0:
		_toast(LsText.MSG.no_coolant, 1.2)
		_equip_best_melee()
		return
	nash.inv.cans -= 1
	nash.start_swing(st.cooldown)
	_play(LsSfx.swing())
	var f := LsEngine.facing_to_vector(nash.facing)
	var best: Node2D = null
	var best_d := float(st["range"])
	for e in infected():
		var d := nash.position.distance_to(e.position)
		if d < best_d and _clear_line(nash.position, e):
			best_d = d
			best = e
	var target := nash.position + f * 110.0
	if best != null:
		target = best.position
		nash.set_facing(LsEngine.facing_from_vector(best.position - nash.position, nash.facing))
	else:
		# stop at a wall
		var q := PhysicsRayQueryParameters2D.create(nash.position, target)
		q.exclude = [nash.get_rid()]
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			target = hit.position - f * 10.0
	var can := CanToss.new()
	can.position = nash.position + Vector2(0, -6)
	can.z_index = 2000
	_add_actor(can)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(can, "position", target, 0.32)
	tw.tween_callback(_coolant_burst.bind(can, target))
	if nash.inv.cans <= 0:
		_after(0.5, _equip_best_melee)
	_update_hp_hud()

func _coolant_burst(can: Node2D, at: Vector2) -> void:
	_free_node(can)
	var st: Dictionary = LsEngine.WEAPONS.coolant
	_play(LsSfx.frost(), -2.0)
	LsFx.burst(actors, at, Color(0.92, 0.96, 1.0, 0.9), 26, 160.0, 0.7, 3.4)
	var cloud := FrostCloud.new()
	cloud.position = at
	cloud.radius = float(st.radius)
	cloud.life = float(st.seconds)
	cloud.z_index = int(at.y) + 30
	_add_actor(cloud)
	_clouds.append({"pos": at, "t": float(st.seconds), "node": cloud})
	for e in infected():
		if e.position.distance_to(at) < float(st.noise):
			e.investigate(at)

## Every infected inside a cold cloud is slowed (a little longer than the frame, so it holds).
func _update_clouds(delta: float) -> void:
	if _clouds.is_empty():
		return
	var st: Dictionary = LsEngine.WEAPONS.coolant
	for c in _clouds.duplicate():
		c.t -= delta
		if c.t <= 0.0:
			_clouds.erase(c)
			_free_node(c.node)
			continue
		for e in infected():
			if e.position.distance_to(c.pos) < float(st.radius):
				e.slow(float(st.slow), 0.6)

func _equip_best_melee() -> void:
	if nash.inv.equipped != "coolant":
		return
	for w in ["wrench", "arm", "knife", "fist"]:
		if nash.inv.has_weapon(w):
			_equip(w)
			return

## A thrown coolant can (a little white-and-blue can, spinning).
class CanToss extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		rotation = _t * 14.0
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-4, -6, 8, 12), Color("0e0e12"))
		draw_rect(Rect2(-3, -5, 6, 10), Color("e8eef4"))
		draw_rect(Rect2(-3, -1, 6, 3), Color("4a7ac0"))

## The cold cloud: a pale, drifting white-blue haze with frost specks; fades out at the end.
## (White-blue, never cyan: cyan is the infected glow only.)
class FrostCloud extends Node2D:
	var radius := 70.0
	var life := 7.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((life - _t) / 1.2, 0.0, 1.0) * clampf(_t / 0.2, 0.0, 1.0)
		for i in 4:
			var r := radius * (0.55 + 0.15 * i) + sin(_t * 1.7 + i) * 4.0
			draw_circle(Vector2(sin(_t + i) * 6.0, cos(_t * 0.8 + i) * 4.0), r, Color(0.86, 0.92, 1.0, 0.09 * fade))
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 26:
			var a := rng.randf() * TAU + _t * rng.randf_range(-0.4, 0.4)
			var d := rng.randf_range(0.0, radius)
			draw_circle(Vector2(cos(a) * d, sin(a) * d * 0.7), rng.randf_range(1.0, 2.2), Color(1, 1, 1, 0.55 * fade))

# ---------------------------------------------------------------- pickups and the bag

## Creates a dropped item (ammo / keycard / medkit / snack...) at a pixel position; it survives
## leaving the room. "fresh" drops are not picked up again until Nash steps away from them.
func _drop(kind: String, pos: Vector2, extra: Dictionary) -> void:
	_drop_count += 1
	var data := {"id": "drop_%d" % _drop_count, "kind": kind, "rect": Rect2i(0, 0, 1, 1),
		"pos": pos, "solid": false}
	data.merge(extra)
	state.drops.append({"room": current_room, "data": data})
	_make_prop(data)

## Walking over an item picks it up (if it fits in the bag).
func _check_pickups() -> void:
	for p in props.values().duplicate():
		if not p.kind in Prop.PICKUP_KINDS:
			continue
		var dist: float = nash.position.distance_to(p.rect_px().get_center())
		if p.data.get("fresh", false):
			if dist > PICKUP_REACH * 2.0:
				p.data.erase("fresh")      # walked away from it: it can be picked up again
			continue
		if dist > PICKUP_REACH:
			continue
		var n := int(p.data.get("amount", 3 if p.kind == "ammo" else 1))
		if p.kind in ["arm", "coolant", "chef_hat"]:
			# v0.5: these say what they are themselves (in _give)
			var got2 := _give(p.kind, n)
			if got2 <= 0:
				continue
			_play(LsSfx.pickup())
			if got2 < n:
				_leave_some(p, n - got2)
			else:
				_remove_pickup(p)
			_update_hp_hud()
			continue
		var item: String = "bullets" if p.kind == "ammo" else ("sec_key" if p.kind == "keycard" else p.kind)
		var got := _give(item, n)
		if got <= 0:
			if _bag_full_t <= 0.0:
				_bag_full_t = BAG_FULL_COOLDOWN
				_toast(LsText.MSG.bag_full, 1.6)
			continue
		match p.kind:
			"ammo":
				_toast(tr(LsText.MSG.got_ammo) % got, 1.8)
			"medkit":
				_toast(LsText.MSG.got_medkit_bag, 2.4)
			"snack":
				_toast(LsText.MSG.got_snack, 1.6)
			"money":
				_toast(tr(LsText.MSG.got_money) % got, 1.6)
			"keycard":
				_toast(LsText.MSG.got_sec_key, 2.2)
				_refresh_doors()
				_refresh_objective()
		_play(LsSfx.pickup())
		if got < n:
			_leave_some(p, n - got)
			if _bag_full_t <= 0.0:
				_bag_full_t = BAG_FULL_COOLDOWN
				_toast(LsText.MSG.bag_full, 1.6)
		else:
			_remove_pickup(p)
		_update_hp_hud()

## The bag only had room for part of a pickup: the rest stays (also after leaving the room).
func _leave_some(p: Node, amount: int) -> void:
	p.data["amount"] = amount
	for d in state.drops:
		if d.data.id == p.id:
			d.data["amount"] = amount
			return
	state.left[p.id] = amount

func _remove_pickup(p: Node) -> void:
	state.taken[p.id] = true
	state.left.erase(p.id)
	for d in state.drops.duplicate():
		if d.data.id == p.id:
			state.drops.erase(d)
	props.erase(p.id)
	p.queue_free()

func _use_vending(p: Prop) -> void:
	var sold := int(state.vending_used.get(p.id, 0))
	if sold >= VENDING_STOCK:
		_toast(LsText.MSG.vending_empty)
		return
	if nash.inv.money < VENDING_PRICE:
		_toast(tr(LsText.MSG.vending_money) % VENDING_PRICE)
		return
	if nash.inv.space_for("snack") <= 0:
		_toast(LsText.MSG.bag_full)
		return
	nash.inv.money -= VENDING_PRICE
	nash.inv.add("snack", 1)
	state.vending_used[p.id] = sold + 1
	_play(LsSfx.pickup())
	_toast(LsText.MSG.snack)
	_update_hp_hud()

## Dwayne's pistol: the story item. Taking it wakes Dwayne.
func _use_gun_cabinet() -> void:
	if nash.has_pistol:
		_toast(LsText.MSG.empty)
		return
	nash.inv.add_weapon("pistol")
	nash.inv.equip("pistol")
	nash.inv.add_ammo(PISTOL_START_AMMO)
	_on_weapons_changed()
	_play(LsSfx.pickup())
	_toast(LsText.MSG.got_pistol, 3.0)
	for q in props.values():
		if q.kind == "gun_cabinet":
			q.refresh()
	for e in enemies:
		if e.has_method("wake"):
			e.wake()
	_refresh_objective()
	_update_hp_hud()

## Heals with what is in the bag: a snack for a small wound, else a first-aid kit (H key, or tap
## the health bar).
func _quick_heal() -> void:
	if state.ended or nash.hp <= 0:
		return
	var item := LsEngine.quick_heal_item(nash.MAX_HP - nash.hp, nash.inv.count("medkit"), nash.inv.count("snack"))
	if item == "":
		_toast(LsText.MSG.health_full if nash.hp >= nash.MAX_HP else LsText.MSG.nothing_to_heal, 1.4)
		return
	_heal_with(item)

func _heal_with(item: String) -> void:
	nash.inv.remove(item, 1)
	var before: int = nash.hp
	nash.heal(LsEngine.HEAL[item])
	_play(LsSfx.pickup())
	_toast(tr(LsText.MSG.healed) % (nash.hp - before), 1.4)
	_update_hp_hud()

func _toggle_bag() -> void:
	if _bag_open:
		_close_bag()
	elif not state.ended and not _fading and not _modal_open and not get_tree().paused:
		_close_wheel()
		_cancel_search()
		_bag_open = true
		get_tree().paused = true
		_bag.open(nash.inv, _key_list())

func _close_bag() -> void:
	if not _bag_open:
		return
	_bag_open = false
	_bag.visible = false
	get_tree().paused = false
	_update_hp_hud()

func _key_list() -> Array:
	var keys: Array = []
	if state.has_keycard:
		keys.append("keycard")
	if state.has_maint_key:
		keys.append("maint_key")
	if state.has_sec_key:
		keys.append("sec_key")
	return keys

func _on_bag_use(i: int) -> void:
	if i < 0 or i >= nash.inv.slots.size() or nash.inv.slots[i].is_empty():
		return
	var kind: String = nash.inv.slots[i].kind
	if not kind in LsEngine.HEAL:
		return
	if nash.hp >= nash.MAX_HP:
		_toast(LsText.MSG.health_full, 1.4)
		return
	_heal_with(kind)
	_bag.refresh(_key_list())

func _on_bag_drop(i: int) -> void:
	var s: Dictionary = nash.inv.take_slot(i)
	if s.is_empty():
		return
	_drop(_pickup_kind(s.kind), nash.position + Vector2(0, 14), {"amount": int(s.n), "fresh": true})
	_play(LsSfx.click())
	_bag.refresh(_key_list())
	_update_hp_hud()

func _on_bag_equip(w: String) -> void:
	_equip(w)
	_bag.refresh(_key_list())

## A hat (bag screen): on / off (one at a time). Wearing the party hat once = Party Animal, the
## cook's hat = Head Chef (v0.5).
func _on_bag_toggle_hat(h: String = "party") -> void:
	if not nash.inv.hats.has(h):
		return
	var worn: String = nash.inv.toggle_hat(h)
	nash.queue_redraw()
	_play(LsSfx.click(), -6.0)
	match worn:
		"party":
			_toast(LsText.MSG.hat_on, 1.4)
			_achieve("party_animal")
		"chef":
			_toast(LsText.MSG.chef_hat_on, 1.4)
			_achieve("head_chef")
		_:
			_toast(LsText.MSG.hat_off, 1.4)
	_bag.refresh(_key_list())

# ---------------------------------------------------------------- the map (v0.5)

func _toggle_map() -> void:
	if _map_open:
		_close_map()
	elif not state.ended and not _fading and not _modal_open and not _bag_open:
		if get_tree().paused:
			_pause_box.visible = false       # opened from the pause menu: back to the game after
		_close_wheel()
		_cancel_search()
		_map_open = true
		get_tree().paused = true
		var room_px := Vector2(_rooms[current_room].rows[0].length(), _rooms[current_room].rows.size()) * TILE
		_map.open(_rooms, state.visited, current_room, nash.position / room_px)

func _close_map() -> void:
	if not _map_open:
		return
	_map_open = false
	_map.visible = false
	get_tree().paused = false

# ---------------------------------------------------------------- set pieces (v0.5)

## Things that happen when Nash walks somewhere: the call-center window.
func _check_triggers() -> void:
	if current_room == "call_center" and state.attack_done and not state.flags.has("window_broken") \
			and nash.position.x > WINDOW_TRIGGER_X * TILE:
		_break_window()

## Glass explodes inward and two infected climb in through the window.
func _break_window() -> void:
	state.flags["window_broken"] = true
	_play(LsSfx.glass())
	shake(5.0)
	var win: Prop = props.get("window_cc")
	var at: Vector2 = win.rect_px().get_center() + Vector2(0, -8) if win != null else nash.position
	if win != null:
		win.refresh()
	LsFx.burst(actors, at, Color(0.82, 0.9, 1.0, 0.95), 34, 230.0, 0.7, 2.6)
	var i := 0
	for ed in _rooms[current_room].get("enemies", []):
		if ed.get("when", "") != "window" or int(ed.get("diff", 0)) > int(state.difficulty):
			continue
		var w := _spawn_enemy(ed)
		if w == null:
			continue
		var land: Vector2 = w.position
		w.position = at + Vector2(i * 20 - 10, -10)
		w.set_scripted(true)
		var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.tween_interval(0.25 + i * 0.5)
		tw.tween_property(w, "position", land, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_window_walker_in.bind(w))
		i += 1
	_after(0.7, _nash_say.bind(LsText.NASH.vo_nash_day0_28))

func _window_walker_in(w: Node2D) -> void:
	if is_instance_valid(w):
		w.set_scripted(false)
		_splat(w.position + Vector2(0, 10), 5.0)
		w.investigate(nash.position)

## Wounded infected leave drops of blood as they move; the feeding ones make their noise.
func _update_drips(delta: float) -> void:
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = DRIP_EVERY
		for e in infected():
			if e.hp < LsEngine.ENEMY_HP.get(e.kind, 6) and e.velocity.length() > 10.0:
				_splat(e.position + Vector2(randf_range(-5, 5), 12), randf_range(1.5, 3.0))
	_chew_t -= delta
	if _chew_t <= 0.0:
		_chew_t = CHEW_EVERY
		for e in infected():
			if e.state == Walker.S.FEED and e.position.distance_to(nash.position) < 360.0:
				_play(LsSfx.chew(), -8.0)
				if not state.flags.has("saw_feeding"):
					state.flags["saw_feeding"] = true
					_after(1.0, _nash_think.bind(LsText.NASH.vo_nash_day0_29))
				break

func shake(amount: float) -> void:
	if not LsSettings.shake_on():
		return      # v0.5: Options -> Screen shake off
	_shake = maxf(_shake, amount)

## Little dust puffs under Nash's boots.
func _on_nash_footstep(pos: Vector2) -> void:
	if get_tree().paused:
		return
	LsFx.burst(actors, pos + Vector2(0, 14), Color(0.8, 0.8, 0.78, 0.5), 3, 30.0, 0.35, 2.2)

## Called by enemies when their attack lands.
## `amount` is the attacker's Normal damage: difficulty scales it, armor soaks part of it.
func damage_nash(amount: int, _from_pos: Vector2) -> void:
	_since_threat = 0.0
	var hit := LsEngine.hit_on_nash(amount, int(state.difficulty), nash.armor)
	if not nash.take_hit(int(hit.hp), int(hit.armor)):
		return
	_cancel_search()
	LsFx.burst(actors, nash.position + Vector2(0, -6), Color("a8141a"), 12, 140.0, 0.35, 2.8)
	_splat(nash.position + Vector2(randf_range(-8, 8), 12), randf_range(2.5, 4.5))
	LsSettings.buzz(70)
	_hurt = 1.0
	shake(6.0)
	_play(LsSfx.hurt())
	_update_hp_hud()
	if nash.hp <= 0:
		_die()

## Health ticks back while nobody is chasing, attacking or searching for Nash.
func _update_regen(delta: float) -> void:
	var hunted := false
	for e in enemies:
		if is_instance_valid(e) and e.is_hunting():
			hunted = true
			break
	if hunted:
		_since_threat = 0.0
	else:
		_since_threat += delta
	var diff: Dictionary = LsEngine.DIFFICULTY[clampi(int(state.difficulty), 0, 2)]
	var on: bool = _since_threat >= float(diff.regen_delay) and nash.hp > 0 and nash.hp < int(diff.regen_cap) \
		and not state.ended
	if on:
		_regen_acc += delta
		while _regen_acc >= float(diff.regen_tick):
			_regen_acc -= float(diff.regen_tick)
			nash.heal(1)
	else:
		_regen_acc = 0.0
	if on != _regenerating or on:
		_regenerating = on
		_update_hp_hud()

## Death = restart the room (full health, killed enemies stay down).
func _die() -> void:
	if _fading:
		return
	state.deaths += 1
	LsStats.add_death()
	_toast(LsText.MSG.caught, 1.5)
	_change_room(checkpoint.room, checkpoint.spawn, true)

# ---------------------------------------------------------------- story beats

func _on_chiller_solved() -> void:
	_toast(LsText.MSG.chiller_ok)
	_nash_say(LsText.MSG.chiller_bark)
	_thud_t = 3.0
	_after(5.0, _start_alarm)

## Alarms, red emergency lights, then the calm intercom: 01, 02, 03 (03 repeats).
## The music stops; v0.5: the siren sounds until the alarm is switched off (security office).
## (v0.4 faded it out after 10 s with _siren_fade(); that is not called any more.)
func _start_alarm() -> void:
	state.alarm = true
	_music("")
	_siren.volume_db = SIREN_DB + LsSettings.sfx_db()
	_siren.play()        # v0.5: until Nash switches it off in the security office
	_people_react("alarm")
	_refresh_dials()
	_refresh_doors()
	_refresh_objective()
	var t := 1.5
	for line_id in ["vo_claudius_day0_intercom_01", "vo_claudius_day0_intercom_02"]:
		_after(t, _intercom_say.bind(line_id))
		t += LsEngine.line_seconds(LsText.INTERCOM[line_id]) + 2.0
	_after(t, _intercom_03)

func _siren_fade() -> void:
	if state.ended or not _siren.playing:
		return
	var tw := create_tween()
	tw.tween_property(_siren, "volume_db", -60.0, 2.5)
	tw.tween_callback(_siren.stop)

func _intercom_03() -> void:
	if state.ended:
		return
	_intercom_say("vo_claudius_day0_intercom_03")
	if not state.attack_done:
		_after(2.8, _nash_say.bind(LsText.NASH.vo_nash_day0_01))
	# The announcement repeats every so often, like a real PA loop.
	_after(40.0, _intercom_03)

## The Day 0 scene: the east door bursts open, a coworker runs in and is grabbed.
## v0.4: the camera pans to the door so the player SEES it (it used to happen off screen), Nash
## stands still for those few seconds and thinks out loud; then the camera comes back to him and
## he can move again. If Nash is not in the plant when it is due, it is skipped.
func _attack_scene_start() -> void:
	state.scene_started = true
	if current_room != "plant":
		_finish_attack(false)
		return
	_scene_active = true
	_cancel_search()
	_close_wheel()
	nash.frozen = true
	state.door_open = true
	var door: Prop = props["door_east"]
	door.refresh()
	_play(LsSfx.thud(), -2.0)
	shake(3.0)
	_nash_think(LsText.NASH.vo_nash_day0_09)
	_scene_camera_to(Vector2(34.0, 10.5) * TILE)
	_after(0.8, _scene_spawn_npc)
	_after(1.9, _nash_think.bind(LsText.NASH.vo_nash_day0_10))
	_after(2.0, _scene_spawn_walker)
	_after(4.4, _scene_grab)
	_after(5.0, _nash_think.bind(LsText.NASH.vo_nash_day0_11))
	_after(6.6, _scene_camera_back)
	_after(7.4, _scene_end)

## A second camera glides from where the player was looking to the attack.
func _scene_camera_to(target: Vector2) -> void:
	_scene_cam = Camera2D.new()
	_scene_cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_scene_cam.zoom = camera.zoom
	_scene_cam.limit_left = camera.limit_left
	_scene_cam.limit_top = camera.limit_top
	_scene_cam.limit_right = camera.limit_right
	_scene_cam.limit_bottom = camera.limit_bottom
	_scene_cam.position = camera.get_screen_center_position()
	add_child(_scene_cam)
	_scene_cam.make_current()
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_scene_cam, "position", target, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## ...and back to Nash, then Nash's own camera takes over again.
func _scene_camera_back() -> void:
	if _scene_cam == null or not is_instance_valid(_scene_cam):
		return
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_scene_cam, "position", camera.get_screen_center_position(), 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_scene_camera_done)

func _scene_camera_done() -> void:
	camera.make_current()
	if _scene_cam != null and is_instance_valid(_scene_cam):
		_scene_cam.queue_free()
	_scene_cam = null

func _scene_spawn_npc() -> void:
	if current_room != "plant":
		return
	_scene_npc = Npc.new()
	_scene_npc.scripted = true
	_scene_npc.look = "coworker"
	_scene_npc.position = Vector2(38.5, 10.5) * TILE
	_add_actor(_scene_npc)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_scene_npc, "position", Vector2(30.5, 10.5) * TILE, 2.0)

func _scene_spawn_walker() -> void:
	if current_room != "plant":
		return
	var data: Dictionary = _rooms["plant"]
	var ed: Dictionary = data.enemies[0]
	_scene_walker = Walker.new()
	_scene_walker.setup(ed, self, nash)
	_scene_walker.position = Vector2(38.5, 10.5) * TILE
	_scene_walker.set_scripted(true)
	_add_actor(_scene_walker)
	enemies.append(_scene_walker)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_scene_walker, "position", Vector2(32.0, 10.5) * TILE, 2.2)

func _scene_grab() -> void:
	_play(LsSfx.scream())
	shake(4.0)
	if _scene_npc != null and is_instance_valid(_scene_npc):
		_scene_npc.set_down(true)
		LsFx.burst(actors, _scene_npc.position + Vector2(0, -4), Color("a8141a"), 22, 170.0, 0.5, 3.2)
		for i in 5:
			_splat(_scene_npc.position + Vector2(randf_range(-22, 22), randf_range(-6, 16)), randf_range(3.0, 7.0))

func _scene_end() -> void:
	_finish_attack(true)

## Ends the scene (or skips it): body on the floor, infected patrol, new objective.
func _finish_attack(played: bool) -> void:
	state.attack_done = true
	state.door_open = true
	_scene_active = false
	_people_react("attack")
	if _scene_cam != null:
		_scene_camera_done()
	# Never leave Nash frozen after the scene (unless he is hiding or reading).
	if not nash.in_locker and not _modal_open and not _fading:
		nash.frozen = false
	_achieve("not_my_shift")
	if played and current_room == "plant":
		if _scene_npc != null and is_instance_valid(_scene_npc):
			_scene_npc.queue_free()
		_scene_npc = null
		for pd in _rooms["plant"].props:
			if pd.id == "body_1":
				_make_prop(pd)
		if _scene_walker != null and is_instance_valid(_scene_walker):
			_scene_walker.set_scripted(false)
			_scene_walker.idle(3.0)
		_after(0.3, _nash_say.bind(LsText.NASH.vo_nash_day0_02))
		_after(7.0, _intercom_say.bind("vo_claudius_day0_intercom_04"))
	else:
		_spawn_enemies()
	_refresh_doors()
	_refresh_objective()

## The ending: out at dawn through one of three exits (front doors -> parking lot, loading dock ->
## service yard, fire exit -> side street). Quiet, distant sirens, Nash's line, black.
func _start_ending(exit_id: String = "front") -> void:
	state.exit = exit_id
	_refresh_objective()       # v0.5: ticks ESCAPE! (and the exit's quest) before the log goes away
	state.ended = true
	LsSave.clear()
	nash.frozen = true
	_close_wheel()
	_refresh_objective()
	_siren.stop()
	_siren.volume_db = -34.0     # distant sirens
	_siren.play()
	_achieve(LsEngine.EXIT_ACHIEVEMENT[exit_id])
	_flush_stats()
	_new_record = LsStats.add_escape(float(state.play_time), exit_id, int(state.difficulty))
	if LsAch.add_exit(exit_id) >= 3:
		_achieve("three_ways")
	if int(state.difficulty) == 2:
		_achieve("veteran")
	match exit_id:
		"dock":
			_after(2.0, _nash_say.bind(LsText.NASH.vo_nash_day0_22))
		"fire":
			_after(2.0, _nash_say.bind(LsText.NASH.vo_nash_day0_23))
	_after(5.0, _nash_say.bind(LsText.NASH.vo_nash_day0_06))
	_after(10.0, _fade_to_black)

func _fade_to_black() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.4)
	tw.tween_callback(_show_end_card)

func _show_end_card() -> void:
	var names: Array = []
	for id in state.achieved:
		names.append(tr(LsText.ACH[id].name).strip_edges())
	var text := tr(LsText.UI.end_title) + "\n" + tr(LsText.UI["end_exit_" + str(state.exit)]) + "\n\n" \
		+ tr(LsText.UI.end_stats) % [state.kills, state.deaths, LsEngine.format_time(state.play_time)]
	if _new_record:
		text += "\n" + tr(LsText.UI.end_record)
	if not names.is_empty():
		text += "\n\n" + tr(LsText.UI.end_new) % ", ".join(names)
	text += "\n" + tr(LsText.UI.xp_line) % [LsAch.xp(), LsAch.xp_name(), LsAch.count(), LsAch.total()]
	_end_label.text = text + "\n\n" + tr(LsText.UI.back_menu)
	_end_label.visible = true
	_end_ready = true

# ---------------------------------------------------------------- atmosphere

func _run_atmosphere(delta: float) -> void:
	if not (_dusk or _dawn):
		var indoors_quiet: bool = not state.alarm and current_room == "lobby"
		_thud_t -= delta
		if _thud_t <= 0.0:
			if not indoors_quiet:
				_play(LsSfx.thud(), randf_range(-14.0, -7.0))
			_thud_t = randf_range(5.0, 9.0) if state.solved.chiller else randf_range(12.0, 22.0)
		if not state.alarm:
			_flicker_t -= delta
			if _flicker_t <= 0.0:
				_flicker_t = randf_range(18.0, 34.0)
				if not indoors_quiet:
					_flicker()
	_update_light()

## Room light = the theme's ambient + ceiling lights; red and pulsing during the alarm (slower and
## softer once the siren has stopped); warm dusk / pale dawn in the parking lot.
func _update_light() -> void:
	var th := LsTiles.theme_of(_theme)
	var amb: Color = th.ambient
	var light_col: Color = th.light
	var energy := 0.75
	if _dusk:
		amb = DUSK_LIGHT
		energy = 0.0
	elif _dawn:
		amb = DAWN_LIGHT
		energy = 0.0
	elif state.alarm and state.flags.has("alarm_off"):
		energy = 0.6
		amb = amb.darkened(0.15)
	elif state.alarm:
		var speed := 3.0 if _siren.playing else 1.4
		var k := 0.5 + 0.5 * sin(_clock * speed)
		amb = Color(0.5, 0.2 + 0.07 * k, 0.2 + 0.07 * k)
		light_col = Color(1.0, 0.3 + 0.1 * k, 0.27 + 0.08 * k)
		energy = 0.75
	var m := _flicker_mult
	_light.color = Color(amb.r * m, amb.g * m, amb.b * m, 1.0)
	for l in _room_lights:
		l.color = light_col
		l.energy = energy * m
	_nash_light.energy = 0.0 if (_dusk or _dawn) else 0.45

## A quick double flicker of the room lights.
func _flicker() -> void:
	for i in 2:
		_after(0.0 + i * 0.22, _set_flicker.bind(0.45))
		_after(0.08 + i * 0.22, _set_flicker.bind(1.0))

func _set_flicker(m: float) -> void:
	_flicker_mult = m

## Plays a sound once and cleans up. `volume_db` 0 = full.
func _play(stream: AudioStream, volume_db: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db + LsSettings.sfx_db()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

## Background music from the hub's library (guarded: older hub apps have none). "" = stop.
## The prototype used the `music` branch's moods ("lofi", "lounge"); the hub's library has styles
## (calm / lively / techno), so both are calm tracks: lounge = track 1, lo-fi = track 0. Asking for
## the track already playing does nothing (Music.play), so every room can call this.
const MUSIC_TRACKS := {"lofi": 0, "lounge": 1}

func _music(mood: String) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null or not m.is_node_ready():
		return
	if mood == "":
		m.stop(2.0)
	else:
		m.play("calm", self, int(MUSIC_TRACKS.get(mood, 0)))

# ---------------------------------------------------------------- HUD

func _label(font_size: int, color: Color) -> Label:
	var l := HudLabel.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A plain label (no panel) for the pause title and the end card.
func _plain_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(380, 64)
	LsUi.style_button(b)
	return b

func _build_hud() -> void:
	# Vignette (dark edges) and the red hurt flash: under the HUD, over the world.
	var vlayer := CanvasLayer.new()
	vlayer.layer = 1
	add_child(vlayer)
	_vignette = ColorRect.new()
	_vignette.material = LsFx.vignette_material()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vlayer.add_child(_vignette)
	var hud := CanvasLayer.new()
	add_child(hud)
	var controls := TouchControls.new()
	_controls = controls
	controls.pause_pressed.connect(_toggle_pause)
	controls.bag_pressed.connect(_toggle_bag)
	controls.map_pressed.connect(_toggle_map)
	controls.wheel_pressed.connect(_toggle_wheel)
	controls.weapon_chosen.connect(_on_weapon_chosen)
	controls.region_tapped.connect(_on_region_tapped)
	hud.add_child(controls)
	_debug_label = Label.new()     # debug readout; remove later
	_debug_label.position = Vector2(12, 4)
	hud.add_child(_debug_label)
	_toast_label = _label(26, Color.WHITE)
	hud.add_child(_toast_label)
	# v0.5: one subtitle line, low on the screen (just above the pause / bag buttons)
	_sub_label = _label(24, Color("ff8a1f"))
	hud.add_child(_sub_label)
	# Health bar + number (top-left), money under it (v0.5: no kill counter), the mission log (top-right).
	_health = HealthBar.new()
	hud.add_child(_health)
	_notice_label = _label(19, Color("ffd479"))
	_notice_label.centered = false
	hud.add_child(_notice_label)
	_kills_label = _label(18, Color.WHITE)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_kills_label.centered = false
	hud.add_child(_kills_label)
	_log = MissionLog.new()
	hud.add_child(_log)
	# Note / email panel.
	_panel = Panel.new()
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", LsUi.panel_style())
	hud.add_child(_panel)
	_panel_text = Label.new()
	_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_text.add_theme_font_size_override("font_size", 22)
	_panel.add_child(_panel_text)
	# The bag (inventory) screen.
	_bag = BagPanel.new()
	_bag.use_slot.connect(_on_bag_use)
	_bag.drop_slot.connect(_on_bag_drop)
	_bag.equip.connect(_on_bag_equip)
	_bag.toggle_hat.connect(_on_bag_toggle_hat)
	_bag.closed.connect(_close_bag)
	hud.add_child(_bag)
	# v0.5: the building map
	_map = MapPanel.new()
	_map.closed.connect(_close_map)
	hud.add_child(_map)
	# Pause menu.
	_pause_box = Panel.new()
	_pause_box.visible = false
	_pause_box.add_theme_stylebox_override("panel", LsUi.panel_style())
	hud.add_child(_pause_box)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_box.add_child(box)
	_pause_title = _plain_label(36, Color.WHITE)
	box.add_child(_pause_title)
	_btn_resume = _button("")
	_btn_resume.pressed.connect(_toggle_pause)
	box.add_child(_btn_resume)
	_btn_map = _button("")
	_btn_map.pressed.connect(_toggle_map)
	box.add_child(_btn_map)
	_btn_lang = _button("")
	_btn_lang.pressed.connect(_on_language_pressed)
	box.add_child(_btn_lang)
	_btn_quit = _button("")
	_btn_quit.pressed.connect(_on_quit_pressed)
	box.add_child(_btn_quit)
	_update_pause_texts()
	# Fade to black for room changes + end card (kept above everything else).
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	_end_label = _plain_label(34, Color.WHITE)
	_end_label.visible = false
	fade_layer.add_child(_end_label)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()

func _update_pause_texts() -> void:
	_pause_title.text = tr(LsText.UI.paused).to_upper()
	_btn_resume.text = tr(LsText.UI.resume)
	_btn_map.text = tr(LsText.UI.map)
	_btn_lang.text = "Español" if not TranslationServer.get_locale().begins_with("es") else "English"
	_btn_quit.text = tr(LsText.UI.quit_menu)

## Prototype pause menu only (never shown in the hub, where the language is the app's setting).
func _on_language_pressed() -> void:
	TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("es") else "es")
	_update_pause_texts()
	_refresh_objective()
	_update_hp_hud()

func _on_quit_pressed() -> void:
	_save_game()
	_back_to_menu()

## Taps on HUD areas that the touch controls report: the mission log, the health bar.
func _on_region_tapped(region: String) -> void:
	match region:
		"log":
			_log.toggle()
		"heal":
			if not get_tree().paused:
				_quick_heal()

## CanvasLayer children get no anchor sizing, so place them from the viewport size by hand.
## Spoken lines (intercom, Nash) go at the bottom middle, between the thumb controls, just above the
## pause / bag buttons (v0.5: lower than before, one line at a time); the mission log sits top-right,
## health top-left.
func _layout_hud() -> void:
	var v := get_viewport_rect().size
	_vignette.size = v
	# as wide as the gap between the D-pad and the weapon-wheel button allows (they sit on that line)
	var half := minf(v.x * 0.5 - 320.0, (v.x - 433.0) - v.x * 0.5)
	_sub_label.max_width = clampf(half * 2.0, 380.0, 600.0)
	_place_subtitle()
	_toast_label.max_width = minf(820.0, v.x - 40.0)
	_toast_label.position.y = v.y * 0.36
	_health.position = Vector2(16, 18)
	_kills_label.position = Vector2(16, 62)
	_log.position = Vector2(v.x - MissionLog.WIDTH - 16.0, 14)
	_notice_label.max_width = MissionLog.WIDTH
	_notice_label.position = Vector2(v.x - MissionLog.WIDTH - 16.0, 62)
	_controls.tap_regions = {"log": _log.header_rect(),
		"heal": Rect2(_health.position - Vector2(6, 6), _health.size + Vector2(12, 12))}
	_update_hp_hud()
	_fade.size = v
	_map.position = Vector2.ZERO
	_map.size = v
	_end_label.position = Vector2((v.x - minf(900.0, v.x - 40.0)) * 0.5, v.y * 0.25)
	_end_label.size = Vector2(minf(900.0, v.x - 40.0), v.y * 0.5)
	var pw := minf(760.0, v.x - 60.0)
	var ph := minf(440.0, v.y - 80.0)
	_panel.position = Vector2((v.x - pw) * 0.5, (v.y - ph) * 0.5)
	_panel.size = Vector2(pw, ph)
	_panel_text.position = Vector2(24, 20)
	_panel_text.size = Vector2(pw - 48, ph - 40)
	var bw2 := minf(900.0, v.x - 60.0)
	var bh2 := minf(500.0, v.y - 120.0)
	_bag.position = Vector2((v.x - bw2) * 0.5, (v.y - bh2) * 0.5 - 30.0)
	_bag.size = Vector2(bw2, bh2)
	var bw := 440.0
	var bh := 470.0
	_pause_box.position = Vector2((v.x - bw) * 0.5, (v.y - bh) * 0.5)
	_pause_box.size = Vector2(bw, bh)

func _update_hp_hud() -> void:
	if _health == null or nash == null:
		return
	_health.set_values(nash.hp, nash.MAX_HP, _regenerating, nash.inv.count("medkit"), nash.inv.count("snack"), nash.armor)
	# v0.5 (playtest): no kill counter next to the health; the count is in Statistics. Money only.
	_kills_label.text = "$%d" % nash.inv.money if nash.inv.money > 0 else ""
	_update_controls()

## What the A and B buttons show right now.
func _update_controls() -> void:
	if _controls == null or nash == null:
		return
	var target: Prop = null if (nash.in_locker or _search_prop != null) else _find_target()
	var act := _a_action(target)
	_controls.a_label = tr(LsText.UI[act]).to_upper()
	_controls.a_active = target != null or nash.in_locker or _search_prop != null
	_controls.a_progress = (_search_t / LsEngine.SEARCH_SECONDS) if _search_prop != null else -1.0
	_controls.b_icon = nash.inv.equipped
	_controls.b_count = nash.inv.count_for(nash.inv.equipped)

func _toast(text: String, secs: float = 2.2) -> void:
	_toast_id += 1
	_toast_label.text = text
	_after(secs, _clear_toast.bind(_toast_id))

func _clear_toast(id: int) -> void:
	if id == _toast_id:
		_toast_label.text = ""

## Plays the chime and shows one intercom line as a subtitle.
## v0.5: through the subtitle queue: it waits while Nash is talking (his lines come first).
func _intercom_say(line_id: String) -> void:
	var text: String = LsText.INTERCOM[line_id]
	_subtitle("intercom", text, LsEngine.line_seconds(text) + 0.9)

# ---------------------------------------------------------------- the subtitle line (v0.5)
# Playtest: "the intercom / dialog should be closer to the bottom of the screen, and they shouldn't
# fight over each other. Dialog takes priority." One line on screen at a time:
# - Nash speaks: his line shows at once. An intercom line on screen is put back at the front of the
#   queue and shown again (in full) once he is done.
# - The intercom speaks: it waits in the queue while anything else is on screen (the same line is
#   never queued twice).

func _subtitle(kind: String, text: String, secs: float) -> void:
	var line := {"kind": kind, "text": text, "secs": secs}
	if kind == "intercom":
		if not _sub_cur.is_empty():
			if _sub_cur.text == text:
				return
			for q in _sub_queue:
				if q.text == text:
					return
			_sub_queue.append(line)
			return
		_show_subtitle(line)
		return
	# Nash: now. An interrupted intercom line goes back to the front of the queue.
	if not _sub_cur.is_empty() and _sub_cur.kind == "intercom":
		_sub_queue.push_front(_sub_cur)
	_show_subtitle(line)

func _show_subtitle(line: Dictionary) -> void:
	_sub_cur = line
	_sub_t = float(line.secs)
	if line.kind == "intercom":
		_play(LsSfx.chime(), -6.0)
		_sub_label.text = tr(LsText.UI.intercom) + "  " + tr(line.text)
		_sub_label.add_theme_color_override("font_color", Color("e8e8f4"))
	else:
		_sub_label.text = line.text      # already "Nash: ..." and translated
		_sub_label.add_theme_color_override("font_color", Color("ff8a1f"))
	_place_subtitle()

func _update_subtitle(delta: float) -> void:
	if _sub_cur.is_empty():
		return
	_sub_t -= delta
	if _sub_t > 0.0:
		_place_subtitle()
		return
	_sub_cur = {}
	_sub_label.text = ""
	if not _sub_queue.is_empty():
		_show_subtitle(_sub_queue.pop_front())

## The subtitle panel grows upward from just above the bottom buttons.
func _place_subtitle() -> void:
	if _sub_label == null:
		return
	var v := get_viewport_rect().size
	_sub_label.position.y = v.y - SUBTITLE_GAP - maxf(_sub_label.size.y, 34.0)

## What the subtitle line says right now (tests).
func subtitle_text() -> String:
	return _sub_label.text

## Quest and achievement lines under the mission log, one after the other.
func _notice(text: String, color: Color) -> void:
	_notices.append([text, color])

func _update_notices(delta: float) -> void:
	if _log.expanded:
		_notice_label.text = ""     # the open log already shows it; keep them queued
		return
	_notice_t -= delta
	if _notice_t > 0.0:
		return
	if _notices.is_empty():
		_notice_label.text = ""
		return
	var n: Array = _notices.pop_front()
	_notice_label.text = n[0]
	_notice_label.add_theme_color_override("font_color", n[1])
	_notice_t = NOTICE_SECONDS

## Unlocks an achievement (kept across runs) and shows it with its XP. Once only.
func _achieve(id: String) -> void:
	if not LsAch.unlock(id):
		return
	state.achieved.append(id)
	_play(LsSfx.pickup(), -4.0)
	# Hub: the challenge goes into the hub's Viral XP log, which shows its own toast.
	if LsAch.report_hub(id):
		return
	_notice(tr(LsText.MSG.achievement) % [tr(LsText.ACH[id].name).strip_edges(), int(LsEngine.ACHIEVEMENTS[id]), LsAch.xp_name()],
		Color("ffcf3a"))

## Nash thinking out loud (in brackets: his inner voice).
func _nash_think(text: String) -> void:
	_subtitle("nash", "Nash: (" + tr(text) + ")", LsEngine.line_seconds(text) + 0.4)

func _nash_say(text: String) -> void:
	_subtitle("nash", "Nash: " + tr(text), LsEngine.line_seconds(text))

## Shows an email or a note (Dwayne's chat, a plaque, Gary's cake) in the panel.
func _open_note(note_id: String) -> void:
	var e: Dictionary = LsText.EMAILS[note_id]
	if e.get("note", false):
		_panel_text.text = tr(e.subject) + "\n\n" + tr(e.body) + "\n\n" + tr(LsText.UI.close)
	else:
		_panel_text.text = tr(LsText.UI.from) % tr(e.from) + "\n" + tr(LsText.UI.subject) % tr(e.subject) \
			+ "\n\n" + tr(e.body) + "\n\n" + tr(LsText.UI.close)
	_panel.visible = true
	_modal_open = true
	_modal_frame = Engine.get_physics_frames()
	nash.frozen = true
	# reading some emails and notes starts a quest
	if not state.read.has(note_id):
		state.read[note_id] = true
		_refresh_objective()

func _close_modal() -> void:
	_panel.visible = false
	_modal_open = false
	nash.frozen = false
