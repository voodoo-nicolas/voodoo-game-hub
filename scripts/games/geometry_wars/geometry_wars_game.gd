extends Control

## Neon Blast (internal id geometry_wars; the name is a placeholder, set in
## geometry_wars_help.gd TITLE + manifest.json): a dual-stick neon voodoo
## shooter. Your ship is a horned skull firing a storm of pins. The classic
## modes (Endless, Time Attack, Unarmed, Sanctuary, Stampede, Coffin, Boss
## Rush) and the Campaign (40 levels in 6 worlds, bosses, familiars, Cursed
## runs) all run on one rule set per game (geometry_wars_levels.gd).
##
## Files: _core (enemies, bullets, collisions), _bosses, _drones, _levels
## (modes + campaign data), _sounds (effects + adaptive music), _campaign
## (the level map), arena_canvas (drawing + the springy grid).
##
## The maps are bigger than the screen: the view shows 19 grid squares top
## to bottom and a camera follows the ship (a minimap shows the rest).

const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
const Core = preload("res://scripts/games/geometry_wars/geometry_wars_core.gd")
const Bosses = preload("res://scripts/games/geometry_wars/geometry_wars_bosses.gd")
const Drones = preload("res://scripts/games/geometry_wars/geometry_wars_drones.gd")
const Levels = preload("res://scripts/games/geometry_wars/geometry_wars_levels.gd")
const Sounds = preload("res://scripts/games/geometry_wars/geometry_wars_sounds.gd")
const Campaign = preload("res://scripts/games/geometry_wars/geometry_wars_campaign.gd")
const HomeKit = preload("res://scripts/games/geometry_wars/home_kit.gd")
const ArenaCanvas = preload("res://scripts/games/geometry_wars/arena_canvas.gd")
const JoystickCanvas = preload("res://scripts/games/geometry_wars/joystick_canvas.gd")
const HELP = preload("res://scripts/games/geometry_wars/geometry_wars_help.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://geometry_wars_save.json"

const SHOCKWAVE_TIME := 0.8
## Hit circles, in grid squares (Core.U pixels each).
const PLAYER_RADIUS := 0.35
const BULLET_RADIUS := 0.2
## A burst of three shots, ten bursts a second = 30 rounds a second. The
## middle shot is faster and flies farther than the two beside it.
const FIRE_INTERVAL := 0.1
const BULLET_SPEED := 22.0
const MID_BULLET_SPEED := 27.0
const BULLET_LIFE := 0.6
const MID_BULLET_LIFE := 1.0
const MAX_ENEMIES := 90
const MAX_BOMBS := 9
## The shield after (re)spawning: a halo for 5 s, and 6 quick beeps in the
## last 1.2 s warn that it is about to drop.
const INVULN_TIME := 5.0
const BEEP_WINDOW := 1.2
const BEEP_COUNT := 6
## After a death the ship is gone this long before it reappears.
const RESPAWN_TIME := 1.3
const JOYSTICK_RADIUS := 70.0
const JOYSTICK_DEADZONE := 0.15
const MAX_PARTICLES := 600
const MAX_CRYSTALS := 300
## The view is this many grid squares tall.
const VIEW_SQUARES := 19.0
const HUD_H := 76.0
## Gates flown through within this long of each other build a combo.
const GATE_COMBO_WINDOW := 2.5
const KING_ZONES := 3
## All spawn intervals are scaled by this (lower = busier).
const SPAWN_PACE := 0.8
const KING_ZONE_R := 3.6
const KING_ZONE_LIFE := 7.0
const MULT_MILESTONES := [10, 25, 50, 100, 200, 500, 1000, 2000, 5000]
const SMALL_POP := ["grunt", "wanderer", "duck", "rocket", "neutron", "mini", "proton", "layer", "nufo"]
const BIG_POP := ["well", "ufo", "repulsor", "golden"]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var sounds: Node
var campaign: Control

## The rules of the game being played (a classic mode or a campaign level).
var rules: Dictionary = {}
var mode := ""  # "evolved", ... or "campaign"
var level_id := 0
var hardcore := false
var drone_kind := ""

var arena_size: Vector2 = Vector2(600, 900)
var view_rect := Rect2()
var view_size := Vector2(600, 400)
var cam := Vector2.ZERO
var shake := 0.0

var player_pos: Vector2 = Vector2.ZERO
var player_prev: Vector2 = Vector2.ZERO
## The ship points where the move stick points; the aim stick only fires.
var ship_dir: Vector2 = Vector2.RIGHT
var thrust: float = 0.0
## Set by the first real touch; from then on the mouse/Enter test controls are off.
var touch_seen: bool = false
var beep_step: int = 99
var invuln_timer: float = 0.0
var respawn_t: float = 0.0
var lives: int = 3
var score: int = 0
var multiplier: int = 1
var peak_mult: int = 1
var bombs: int = 3
var next_bomb_at: int = 0
var next_life_at: int = 0
var fire_cooldown_timer: float = 0.0
var spawn_timer: float = 0.0
var elapsed_seconds: float = 0.0
var next_entity_id: int = 1
var kills: int = 0
var gates_passed: int = 0
var geoms_got: int = 0
var bosses_beaten: int = 0
var deaths: int = 0
var gate_combo: int = 0
var gate_combo_t: float = 0.0
var geom_chain: int = 0
var geom_chain_t: float = 0.0
var ev_next: Array = []
var gate_t: float = 0.0
var wave_t: float = 0.0
var zone_t: float = 0.0
var rush_index: int = 0
var rush_t: float = -1.0
var boss_events_left: int = 0
var ending: float = -1.0
var won: bool = false
var tick_shown: int = -1

var enemies: Array = []
var bullets: Array = []
var ebullets: Array = []
var particles: Array = []
## Dropped by every kill; each one picked up adds 1 to the score multiplier.
## They fade after Core.CRYSTAL_LIFE seconds. Dying resets the multiplier.
var crystals: Array = []
var mines: Array = []
var zones: Array = []
var king_zone: int = -1
var bosses: Array = []
var drones: Array = []
var rays: Array = []
var popups: Array = []
var shockwave_t: float = -1.0  # seconds since the last bomb, -1 = none
var bomb_pos := Vector2.ZERO

var game_active: bool = false
var game_over: bool = false
## Test hook: when set, returns {move, aim, fire} instead of reading input.
var autopilot: Callable

var move_touch_index: int = -1
var move_origin: Vector2 = Vector2.ZERO
var move_value: Vector2 = Vector2.ZERO
var aim_touch_index: int = -1
var aim_origin: Vector2 = Vector2.ZERO
var aim_value: Vector2 = Vector2.ZERO

var game_screen: Control
var view_clip: Control
var arena_canvas: Node2D
var joystick_canvas: Node2D
var minimap: Control
var boss_bar: Control
var score_label: Label
var lives_label: Label
var combo_label: Label
var goal_label: Label
var banner: Label
var bomb_button: Button
var pause_button: Button
var result_dialog: Control
var result_box: VBoxContainer
var rotate_hint: Control

func _ready() -> void:
	preload("res://scripts/games/geometry_wars/geometry_wars_i18n.gd").install(self)
	randomize()
	Orientation.lock_landscape()
	# A save from before the Adventure update can't be resumed: drop it so
	# Home doesn't offer a Resume that starts a new game.
	var old = SaveUtil.read(SAVE_PATH)
	if old is Dictionary and not old.has("blob"):
		SaveUtil.delete(SAVE_PATH)
	_build_ui()
	resized.connect(_layout)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
	elif what == NOTIFICATION_UNPAUSED:
		# A release that arrived while paused was never seen: forget both thumbs.
		_release_sticks()

func _exit_to_hub() -> void:
	_save_game()
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

func _format_time(s: float) -> String:
	var total := int(maxf(s, 0.0))
	return "%d:%02d" % [int(total / 60), total % 60]

func _sfx(key: String, db: float = 0.0, pitch: float = 1.0, gap_ms: int = 30) -> void:
	if sounds:
		sounds.play(key, db, pitch, gap_ms)

## Quieter when it happens off screen.
func _sfx_at(key: String, pos: Vector2, db: float = 0.0, pitch: float = 1.0, gap_ms: int = 30) -> void:
	var on_screen := Rect2(cam, view_size).grow(Core.U * 2.0).has_point(pos)
	_sfx(key, db + (0.0 if on_screen else -9.0), pitch, gap_ms)

# ---------- input ----------

## Forget both thumbs. A release that arrives while paused is otherwise
## never seen, leaving a stick "held" forever after resuming.
func _release_sticks() -> void:
	move_touch_index = -1
	aim_touch_index = -1
	move_value = Vector2.ZERO
	aim_value = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_seen = true
	if not game_active or game_over:
		_release_sticks()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _on_hud_button(event.position):
			return  # a tap on Pause / Bomb isn't a thumbstick
		if event.pressed:
			var is_left: bool = event.position.x < get_viewport_rect().size.x / 2.0
			if is_left and move_touch_index == -1:
				move_touch_index = event.index
				move_origin = event.position
				move_value = Vector2.ZERO
			elif not is_left and aim_touch_index == -1:
				aim_touch_index = event.index
				aim_origin = event.position
				aim_value = Vector2.ZERO
		else:
			if event.index == move_touch_index:
				move_touch_index = -1
				move_value = Vector2.ZERO
			if event.index == aim_touch_index:
				aim_touch_index = -1
				aim_value = Vector2.ZERO
	elif event is InputEventScreenDrag:
		if event.index == move_touch_index:
			move_value = _clamp_stick(event.position - move_origin)
		elif event.index == aim_touch_index:
			aim_value = _clamp_stick(event.position - aim_origin)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		_on_bomb_pressed()

func _on_hud_button(p: Vector2) -> bool:
	for b in [bomb_button, pause_button]:
		if b and b.is_visible_in_tree() and b.get_global_rect().grow(8).has_point(p):
			return true
	return false

func _clamp_stick(delta: Vector2) -> Vector2:
	var length: float = delta.length()
	if length > JOYSTICK_RADIUS:
		delta = delta.normalized() * JOYSTICK_RADIUS
	return delta / JOYSTICK_RADIUS

func _get_move_dir() -> Vector2:
	if autopilot.is_valid():
		return (autopilot.call(self).get("move", Vector2.ZERO) as Vector2).limit_length(1.0)
	var v: Vector2
	if move_touch_index != -1:
		v = move_value
	else:
		v = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if v == Vector2.ZERO:
			v = Vector2(
				float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
				float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if v.length() > 1.0:
		v = v.normalized()
	return v

## Returns {dir: Vector2, firing: bool}. Prefers the touch aim stick; falls back
## to mouse-aim + click/Enter-to-fire for desktop testing.
func _get_aim() -> Dictionary:
	if autopilot.is_valid():
		var a: Dictionary = autopilot.call(self)
		var d: Vector2 = a.get("aim", Vector2.ZERO)
		return {"dir": d.normalized() if d != Vector2.ZERO else Vector2.ZERO, "firing": bool(a.get("fire", false))}
	if aim_touch_index != -1:
		if aim_value.length() > JOYSTICK_DEADZONE:
			return {"dir": aim_value.normalized(), "firing": true}
		return {"dir": Vector2.ZERO, "firing": false}

	# Only the aim stick fires on a touchscreen. A finger on the MOVE stick is
	# also reported as an emulated left-mouse click, which used to make the ship
	# shoot toward that finger while merely flying.
	if touch_seen:
		return {"dir": Vector2.ZERO, "firing": false}

	var mouse_world: Vector2 = get_local_mouse_position() - view_rect.position + cam
	var dir: Vector2 = mouse_world - player_pos
	var firing: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("ui_accept")
	if dir.length() > 0.01:
		return {"dir": dir.normalized(), "firing": firing}
	return {"dir": Vector2.ZERO, "firing": firing}

func can_fire() -> bool:
	return bool(rules.get("gun", true)) and (not rules.get("king", false) or king_zone >= 0) and respawn_t <= 0.0

# ---------- main loop ----------

func _process(delta: float) -> void:
	rotate_hint.visible = get_viewport_rect().size.x < get_viewport_rect().size.y
	if not game_active:
		if game_over and ending >= 0.0:
			_step_effects(delta)
		return
	if ending >= 0.0:
		ending -= delta
		_step_effects(delta)
		_update_camera(delta)
		arena_canvas.queue_redraw()
		if ending < 0.0:
			_show_result()
		return
	delta = minf(delta, 0.05)
	elapsed_seconds += delta
	var u: float = Core.U

	# --- the ship ---
	player_prev = player_pos
	if respawn_t > 0.0:
		respawn_t -= delta
		if respawn_t <= 0.0:
			_respawn()
	else:
		var move_dir: Vector2 = _get_move_dir()
		thrust = move_dir.length()
		if thrust > 0.2:
			ship_dir = ship_dir.slerp(move_dir.normalized(), clampf(delta * 20.0, 0.0, 1.0))
			if Engine.get_process_frames() % 3 == 0:
				arena_canvas.pulse(player_pos - ship_dir * 0.6 * u, 25.0 * thrust, 1.6 * u)
		var pull := Core.well_pull(enemies, player_pos)
		for b in bosses:
			pull += Bosses.pull(b, player_pos)
		player_pos += move_dir * Core.PLAYER_TOP_SPEED * u * delta + pull * delta
		player_pos = player_pos.clamp(Vector2.ZERO, arena_size)

	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)
		if invuln_timer < BEEP_WINDOW:
			var step := int(invuln_timer / (BEEP_WINDOW / BEEP_COUNT))
			if step != beep_step:
				beep_step = step
				_sfx("shield_beep", -4.0)
	if shockwave_t >= 0.0:
		shockwave_t += delta
		if shockwave_t > SHOCKWAVE_TIME:
			shockwave_t = -1.0

	# --- King zones (before firing: they decide whether you may) ---
	if rules.king:
		_update_zones(delta)

	# --- firing ---
	var aim: Dictionary = _get_aim()
	var aim_dir: Vector2 = aim.dir
	var firing: bool = aim.firing and aim_dir.length() > 0.01 and can_fire()
	fire_cooldown_timer -= delta
	if firing:
		if fire_cooldown_timer <= 0.0:
			_fire_burst(aim_dir)
			fire_cooldown_timer += FIRE_INTERVAL
	elif fire_cooldown_timer < 0.0:
		fire_cooldown_timer = 0.0

	# --- spawning ---
	if respawn_t <= 0.0:
		_spawn_step(delta)

	# --- enemies ---
	for ev in Core.update_enemies(enemies, player_pos, arena_size, delta, bullets, crystals):
		_on_event(ev)
	var benders: Array = []
	for b in bosses:
		var bd := Bosses.bender(b)
		if not bd.is_empty():
			benders.append(bd)
	Core.update_bullets(bullets, arena_size, delta, enemies, benders)
	Core.update_enemy_bullets(ebullets, arena_size, delta)
	if rules.king:
		Core.push_out_of_zones(enemies, zones)
	for w in enemies:
		if w.type == "well" and w.warm <= 0.0:
			arena_canvas.pulse(w.pos, -45.0 if w.active else -12.0, Core.well_range(w) * 0.7 * u)
	for b in bosses:
		if b.kind == "lord" and float(b.warm) <= 0.0:
			arena_canvas.pulse(b.pos, -70.0, 8.0 * u)

	# --- bosses ---
	for i in range(bosses.size() - 1, -1, -1):
		var b: Dictionary = bosses[i]
		for ev in Bosses.update(b, player_pos, arena_size, delta):
			_on_boss_event(b, ev)
	_bullets_on_bosses()

	# --- drones ---
	if not drones.is_empty() and respawn_t <= 0.0:
		var ctx := {"player_pos": player_pos, "ship_dir": ship_dir, "aim_dir": aim_dir, "firing": firing,
			"enemies": enemies, "crystals": crystals, "bosses": bosses, "bullets": bullets, "arena": arena_size}
		for d in drones:
			for ev in Drones.update(d, ctx, delta):
				_on_drone_event(ev)

	# --- hits ---
	for k in Core.resolve_bullet_hits(bullets, enemies, BULLET_RADIUS * u):
		_on_kill(k)
	for mi in Core.bullets_on_mines(bullets, mines, BULLET_RADIUS * u):
		if mi < mines.size():
			_detonate_mine(mi)
	if respawn_t <= 0.0:
		for mi in Core.update_mines(mines, player_pos, PLAYER_RADIUS * u, delta):
			if mi < mines.size():
				_detonate_mine(mi)
		_check_gates()
	else:
		Core.update_mines(mines, Vector2(-9999, -9999), 0.0, delta)

	var picked: int = Core.update_crystals(crystals, player_pos, delta) if respawn_t <= 0.0 else 0
	if picked > 0:
		_add_geoms(picked)
	geom_chain_t -= delta
	gate_combo_t -= delta

	_step_effects(delta)

	if respawn_t <= 0.0 and invuln_timer <= 0.0:
		var hit := Core.player_hit(player_pos, enemies, PLAYER_RADIUS * u) or Core.enemy_bullet_hit(player_pos, ebullets, PLAYER_RADIUS * u)
		if not hit:
			for b in bosses:
				if Bosses.touches(b, player_pos, PLAYER_RADIUS * u):
					hit = true
					break
		if hit:
			_on_player_hit()

	_check_goal()
	_update_audio()
	_update_camera(delta)
	_update_hud()
	arena_canvas.queue_redraw()
	joystick_canvas.queue_redraw()
	minimap.queue_redraw()
	boss_bar.queue_redraw()

## Sparks, popups, snipe rays, the wake of bullets in the grid.
func _step_effects(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.age += delta
		if p.age >= p.lifetime:
			particles.remove_at(i)
			continue
		p.pos += p.vel * delta
		p.vel *= maxf(0.0, 1.0 - 2.4 * delta)
	for i in range(popups.size() - 1, -1, -1):
		popups[i].age = float(popups[i].age) + delta
		if float(popups[i].age) >= 1.2:
			popups.remove_at(i)
	for i in range(rays.size() - 1, -1, -1):
		rays[i].age = float(rays[i].age) + delta
		if float(rays[i].age) >= 0.25:
			rays.remove_at(i)
	if Engine.get_process_frames() % 3 == 0:
		var u: float = Core.U
		for i in range(0, bullets.size(), 2):
			arena_canvas.pulse(bullets[i].pos, 24.0, 0.9 * u)
	shake = maxf(0.0, shake - delta * 2.5)

## Three shots in a tight triangle: the middle one leads, and is faster and
## longer-ranged than its two wingmen.
func _fire_burst(dir: Vector2) -> void:
	var u: float = Core.U
	var side := Vector2(-dir.y, dir.x)
	var muzzle: Vector2 = player_pos + dir * 0.6 * u
	bullets.append({"pos": muzzle + dir * 0.3 * u, "vel": dir * MID_BULLET_SPEED * u, "life": MID_BULLET_LIFE})
	for s in [-1.0, 1.0]:
		bullets.append({"pos": muzzle + side * s * 0.32 * u, "vel": dir.rotated(s * 0.04) * BULLET_SPEED * u, "life": BULLET_LIFE})
	_sfx("shot", -7.0, randf_range(0.93, 1.07), 55)

## A shower of sparks in `color`.
func _spark_burst(pos: Vector2, color: Color, n: int, speed: float = 1.0) -> void:
	var u: float = Core.U
	for i in n:
		if particles.size() >= MAX_PARTICLES:
			return
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(3.0, 13.0) * u * speed
		particles.append({"pos": pos, "vel": v, "age": 0.0, "lifetime": randf_range(0.35, 0.8), "color": color, "len": randf_range(0.4, 1.0) * u})

func _popup(pos: Vector2, text: String, color: Color, size: int = 22) -> void:
	if popups.size() < 30:
		popups.append({"pos": pos, "text": text, "color": color, "age": 0.0, "size": size})

func _new_id() -> int:
	next_entity_id += 1
	return next_entity_id

func _add_enemies(list: Array, sound: bool = true) -> void:
	if list.is_empty():
		return
	for e in list:
		if enemies.size() >= MAX_ENEMIES and not e.type in Core.GATES:
			break
		e.id = _new_id()
		enemies.append(e)
	if sound:
		var e0: Dictionary = list[0]
		var key: String = "spawn_" + ("gate" if e0.type == "golden" else ("well" if e0.type == "proton" else e0.type))
		if e0.type != "proton" and e0.type != "mini":
			_sfx_at(key, e0.pos, -3.0, 1.0, 140)

# ---------- spawning ----------

func _spawn_step(delta: float) -> void:
	var u: float = Core.U
	# The steady trickle.
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var rate: Array = rules.rate
		var k: float = clampf(elapsed_seconds / float(rate[2]), 0.0, 1.0)
		spawn_timer = lerpf(float(rate[0]), float(rate[1]), k) * SPAWN_PACE
		var table: Dictionary = {}
		if rules.spawn is String:
			table = Core.spawn_table(elapsed_seconds * float(rules.ramp_speed))
		else:
			table = rules.spawn
		# The swarm thickens: more spawns per tick as the game goes on.
		var groups := 1 + mini(3, int(elapsed_seconds * float(rules.ramp_speed) / 35.0))
		for i in groups:
			if table.is_empty() or enemies.size() >= MAX_ENEMIES:
				break
			_add_enemies(Core.spawn_group(arena_size, elapsed_seconds, player_pos, table), i == 0)
	# Timed events (hordes, rings, bosses...).
	var evs: Array = rules.events
	for i in evs.size():
		if elapsed_seconds >= float(ev_next[i]):
			var ev: Array = evs[i]
			ev_next[i] = float(ev_next[i]) + float(ev[1]) if float(ev[1]) > 0.0 else INF
			_fire_event(ev)
	# Gates keep coming.
	if not (rules.gates as Array).is_empty():
		gate_t -= delta
		if gate_t <= 0.0:
			gate_t = float(rules.gates[0])
			var n := 0
			for e in enemies:
				if e.type in Core.GATES:
					n += 1
			if n < int(rules.gates[1]):
				_add_enemies(Core.spawn_of("gate", arena_size, player_pos))
	# Walls of rockets.
	if not (rules.waves as Array).is_empty():
		wave_t -= delta
		if wave_t <= 0.0:
			var k2: float = clampf(elapsed_seconds / 150.0, 0.0, 1.0)
			wave_t = lerpf(float(rules.waves[0]), float(rules.waves[1]), k2)
			_add_enemies(Core.rocket_wall(arena_size, randi() % 4, maxf(2.2, 4.0 - k2 * 1.5)))
	# Boss Rush: the next boss after a breather.
	if rush_t >= 0.0:
		rush_t -= delta
		if rush_t < 0.0:
			var next: Array = rules.rush[rush_index]
			rush_index += 1
			_spawn_boss(str(next[0]), int(next[1]) == 1)

func _fire_event(ev: Array) -> void:
	var what: String = ev[2]
	var arg: String = str(ev[3])
	var n: int = int(ev[4])
	var u: float = Core.U
	match what:
		"horde":
			if arg == "mayfly":
				_add_enemies(Core.spawn_of("mayfly", arena_size, player_pos, n))
			else:
				var corner := Core.horde_corner(arena_size, player_pos)
				var list: Array = []
				for i in n:
					var p := (corner + Vector2(randf_range(-2, 2), randf_range(-2, 2)) * u).clamp(Vector2.ZERO, arena_size)
					list.append(Core.make_enemy(0, arg, p, Core.WARM_TIME + randf() * 0.4))
				_add_enemies(list)
		"cluster":
			# A pack arriving at one spot near the edge of the fight.
			var count := n + int(elapsed_seconds / 25.0)
			var spot := _edge_spot()
			var list: Array = []
			for i in count:
				var p := (spot + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) * u).clamp(Vector2.ZERO, arena_size)
				list.append(Core.make_enemy(0, arg, p, Core.WARM_TIME + randf() * 0.3))
			_add_enemies(list)
		"ring":
			_add_enemies(Core.ring_of(arg, player_pos, 8.0, n, arena_size))
		"line":
			_add_enemies(Core.rocket_line(arena_size, player_pos, maxi(3, n)))
		"wall":
			_add_enemies(Core.rocket_wall(arena_size, randi() % 4, float(arg) if arg != "" else 3.0))
		"nufo":
			_add_enemies(Core.nufo_horde(arena_size, player_pos, maxi(4, n)))
		"ufo":
			_add_enemies(Core.spawn_of("ufo", arena_size, player_pos))
		"spawn":
			var list: Array = []
			for i in n:
				list.append_array(Core.spawn_of(arg, arena_size, player_pos))
			_add_enemies(list)
		"gates", "golden":
			for i in maxi(1, n):
				_add_enemies(Core.spawn_of("golden" if what == "golden" else "gate", arena_size, player_pos))
		"boss":
			boss_events_left -= 1
			_spawn_boss(arg, n == 1)

## A spot on the map's edge within reach of the player.
func _edge_spot() -> Vector2:
	var u: float = Core.U
	var near := (player_pos + Vector2(randf_range(-14, 14), randf_range(-9, 9)) * u).clamp(Vector2(u, u), arena_size - Vector2(u, u))
	match randi() % 4:
		0:
			return Vector2(1.5 * u, near.y)
		1:
			return Vector2(arena_size.x - 1.5 * u, near.y)
		2:
			return Vector2(near.x, 1.5 * u)
	return Vector2(near.x, arena_size.y - 1.5 * u)

func _spawn_boss(kind: String, hard: bool) -> void:
	var u: float = Core.U
	# Across the map from the player, but not in a corner.
	var p := arena_size - player_pos
	p = p.clamp(Vector2(7, 7) * u, arena_size - Vector2(7, 7) * u)
	if p.distance_to(player_pos) < 9.0 * u:
		p = (player_pos + Vector2(12, 0).rotated(randf() * TAU) * u).clamp(Vector2(7, 7) * u, arena_size - Vector2(7, 7) * u)
	var b := Bosses.make(kind, p, hard)
	bosses.append(b)
	_sfx("boss_warn", 0.0, 1.0, 400)
	_show_banner("⚠ " + tr(Bosses.name_of(b)).to_upper() + " ⚠", Bosses.color_of(b))
	shake = 0.6

# ---------- events ----------

func _on_event(ev: Dictionary) -> void:
	var u: float = Core.U
	match ev.kind:
		"gear_pop":
			_spark_burst(ev.pos, Core.color_of("gear"), 16)
			arena_canvas.pulse(ev.pos, 120.0, 4.0 * u)
			_sfx_at("pop_m", ev.pos)
		"gulp":
			_sfx_at("well_gulp", ev.pos, -2.0, 1.0 + float(ev.n) * 0.04, 80)
			arena_canvas.pulse(ev.pos, -120.0, 4.0 * u)
		"well_burst":
			# The bubble pops, everything goes quiet... then the skittering.
			_spark_burst(ev.pos, Core.color_of("well"), 50, 1.4)
			_spark_burst(ev.pos, Core.color_of("proton"), 30, 1.0)
			arena_canvas.pulse(ev.pos, 500.0, 10.0 * u)
			shake = maxf(shake, 0.5)
			_sfx("well_pop", 2.0, 1.0, 0)
			if sounds:
				sounds.duck(1.1)
			var list: Array = []
			for i in int(ev.n):
				var a := TAU * i / float(ev.n) + randf() * 0.4
				var pr := Core.make_enemy(0, "proton", ev.pos + Vector2(cos(a), sin(a)) * 0.8 * u)
				pr.vel = Vector2(cos(a), sin(a)) * randf_range(7.0, 11.0) * u
				list.append(pr)
			_add_enemies(list, false)
		"mine":
			if mines.size() < Core.MAX_MINES:
				mines.append({"pos": ev.pos, "age": 0.0})
				_sfx_at("mine_drop", ev.pos, -6.0, 1.0, 200)
		"charge":
			_sfx_at("repulsor_charge", ev.pos, -2.0, 1.0, 150)
		"gate_gone":
			_spark_burst(ev.pos, Core.color_of("golden"), 10, 0.5)

func _on_boss_event(b: Dictionary, ev: Dictionary) -> void:
	var u: float = Core.U
	match ev.kind:
		"spawn":
			var e := Core.make_enemy(0, str(ev.type), (ev.pos as Vector2).clamp(Vector2.ZERO, arena_size), Core.WARM_TIME)
			if ev.get("active", false):
				e.active = true
			_add_enemies([e], ev.type == "well")
		"shots":
			ebullets.append_array(ev.list)
			_sfx_at("enemy_shot", b.pos, -4.0, randf_range(0.9, 1.1), 90)
		"phase":
			_sfx("boss_phase", 0.0, 1.0, 500)
			shake = maxf(shake, 0.8)
			arena_canvas.pulse(ev.pos, 600.0, 10.0 * u)
			_popup(ev.pos, tr("ENRAGED!"), Color(1, 0.3, 0.3), 30)
		"part":
			_spark_burst(ev.pos, ev.color, 26, 1.2)
			arena_canvas.pulse(ev.pos, 300.0, 5.0 * u)
			_sfx_at("boss_part", ev.pos, 0.0, randf_range(0.95, 1.05), 60)
			var pts := 250 * multiplier
			score += pts
			_popup(ev.pos, _num(pts), Color(1, 0.9, 0.5))
			for i in 3:
				_drop_geom(ev.pos, 1)

func _bullets_on_bosses() -> void:
	if bosses.is_empty():
		return
	var u: float = Core.U
	var br := BULLET_RADIUS * u
	for bi in range(bullets.size() - 1, -1, -1):
		var p: Vector2 = bullets[bi].pos
		for b in bosses:
			var ev: Array = []
			var res := Bosses.bullet_hit(b, p, br, ev)
			if res == "":
				continue
			bullets.remove_at(bi)
			match res:
				"block":
					_sfx_at("boss_block", p, -6.0, randf_range(0.9, 1.1), 70)
				"hit":
					score += 5 * multiplier
					_sfx_at("boss_hit", p, -4.0, randf_range(0.92, 1.08), 60)
			for e in ev:
				_on_boss_event(b, e)
			break
	_check_bosses_dead()

func _check_bosses_dead() -> void:
	var u: float = Core.U
	for i in range(bosses.size() - 1, -1, -1):
		var b: Dictionary = bosses[i]
		if not Bosses.is_dead(b):
			continue
		bosses.remove_at(i)
		bosses_beaten += 1
		var pos: Vector2 = b.pos
		var col := Bosses.color_of(b)
		_spark_burst(pos, col, 120, 2.0)
		_spark_burst(pos, Color.WHITE, 60, 1.5)
		arena_canvas.shock(pos, 1.4)
		shake = 1.4
		_sfx("boss_die", 2.0, 1.0, 0)
		var pts: int = int(Bosses.POINTS.get(b.kind, 20000)) * (2 if b.hard else 1) * multiplier
		score += pts
		_popup(pos, _num(pts), Color(1, 0.95, 0.5), 40)
		for k in 6:
			crystals.append({"pos": pos + Vector2(randf_range(-2, 2), randf_range(-2, 2)) * u, "age": -2.0, "v": 10})
		for k in 20:
			_drop_geom(pos + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)) * u, 1)
		# Its minions and shots go with it.
		for e in enemies:
			_spark_burst(e.pos, Core.color_of(e.type), 3)
		enemies = enemies.filter(func(e): return e.type in Core.GATES)
		ebullets.clear()
		if not (rules.get("rush", []) as Array).is_empty() and rush_index < (rules.rush as Array).size() and bosses.is_empty():
			rush_t = 3.0

func _on_drone_event(ev: Dictionary) -> void:
	match ev.kind:
		"kills":
			for k in ev.list:
				_on_kill(k)
			if drone_kind == "ram":
				_sfx("ram", -4.0, randf_range(0.9, 1.1), 80)
		"geoms":
			_add_geoms(int(ev.v))
		"boss":
			Bosses.damage(ev.boss, int(ev.n))
			_check_bosses_dead()
		"ray":
			rays.append({"from": ev.from, "to": ev.to, "age": 0.0})
			_sfx("snipe", -4.0, randf_range(0.95, 1.05), 100)
		"shot":
			_sfx("drone_shot", -10.0, 1.0, 120)

func _add_geoms(v: int) -> void:
	var before := multiplier
	multiplier += v
	geoms_got += v
	peak_mult = maxi(peak_mult, multiplier)
	geom_chain = geom_chain + 1 if geom_chain_t > 0.0 else 0
	geom_chain_t = 0.35
	_sfx("geom", -2.0, 1.0 + minf(geom_chain, 14) * 0.055, 20)
	for m in MULT_MILESTONES:
		if before < m and multiplier >= m:
			_sfx("mult", 0.0, 1.0, 0)
			_popup(player_pos + Vector2(0, -1.5) * Core.U, "×%d!" % m, Color(0.4, 1.0, 0.55), 30)

func _drop_geom(pos: Vector2, v: int) -> void:
	if crystals.size() < MAX_CRYSTALS:
		crystals.append({"pos": pos, "age": 0.0, "v": v})

## Points (times the multiplier), sparks, a ripple through the grid, and
## geoms to collect. Spinners split in three, wells blow up their neighbours.
## `bonus` multiplies the points (gate combos, gold shots).
func _on_kill(k: Dictionary, bonus: float = 1.0) -> void:
	var u: float = Core.U
	var type: String = k.type
	var eaten := int(k.get("eaten", 0))
	var pts := int(Core.POINTS.get(type, 10))
	if type == "well":
		pts += 100 * eaten
	if k.get("gold", false):
		bonus *= 4.0
	var got := int(pts * multiplier * bonus)
	score += got
	kills += 1
	var big: bool = type in BIG_POP or type == "snake"
	_spark_burst(k.pos, Core.color_of(type), 30 if big else 12)
	arena_canvas.pulse(k.pos, 380.0 if type == "well" else (200.0 if big else 110.0), (8.0 if big else 3.5) * u)
	if type == "mayfly":
		_sfx_at("pop_tiny", k.pos, -4.0, randf_range(0.9, 1.2), 25)
	elif type in SMALL_POP:
		_sfx_at("pop_s", k.pos, -2.0, randf_range(0.85, 1.2), 30)
	elif big:
		_sfx_at("pop_l", k.pos, 0.0, randf_range(0.9, 1.1), 60)
	else:
		_sfx_at("pop_m", k.pos, -1.0, randf_range(0.9, 1.15), 40)
	if got >= 1000 or k.get("gold", false):
		_popup(k.pos, _num(got), Color(1, 0.85, 0.3) if k.get("gold", false) else Color(1, 1, 1))

	var drops := int(Core.GEOMS.get(type, 1)) + eaten
	if type == "ufo":
		for i in 2:  # the huge ones: +10 multiplier each
			_drop_geom(k.pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * u, 10)
	else:
		for i in drops:
			var jitter := Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * u if drops > 1 else Vector2.ZERO
			_drop_geom(k.pos + jitter, 1)

	if type == "spinner":
		var kids: Array = []
		for i in 3:
			var a := TAU * i / 3.0 + randf() * 0.5
			var kid := Core.make_enemy(0, "mini", k.pos + Vector2(cos(a), sin(a)) * 0.6 * u)
			kid.vel = Vector2(cos(a), sin(a)) * 8.0 * u
			kids.append(kid)
		_add_enemies(kids, false)
	elif type == "well":
		shake = maxf(shake, 0.4)
		for kk in Core.blast(enemies, k.pos, 4.5 * u):
			_on_kill(kk)
	_check_extras()

func _check_extras() -> void:
	while int(rules.bomb_every) > 0 and score >= next_bomb_at:
		next_bomb_at += int(rules.bomb_every)
		if bombs < MAX_BOMBS:
			bombs += 1
			_sfx("extra_bomb", 0.0, 1.0, 300)
			_popup(player_pos + Vector2(0, -2) * Core.U, tr("+1 Bomb"), Color(1, 0.6, 0.25), 24)
	while int(rules.life_every) > 0 and score >= next_life_at:
		next_life_at += int(rules.life_every)
		if int(rules.lives) > 0:
			lives += 1
			_sfx("extra_life", 0.0, 1.0, 300)
			_popup(player_pos + Vector2(0, -2.5) * Core.U, tr("+1 Life"), Color(0.5, 1, 0.6), 26)

## Flying through the middle of a gate blows it up, and everything near it.
func _check_gates() -> void:
	var u: float = Core.U
	for i in range(enemies.size() - 1, -1, -1):
		if i >= enemies.size():
			continue
		var g: Dictionary = enemies[i]
		if not g.type in Core.GATES or not Core.gate_crossed(g, player_prev, player_pos):
			continue
		enemies.remove_at(i)
		gates_passed += 1
		gate_combo = gate_combo + 1 if gate_combo_t > 0.0 else 1
		gate_combo_t = GATE_COMBO_WINDOW
		var bonus := 1.0 + (gate_combo - 1) * 0.5
		var golden: bool = g.type == "golden"
		var pts := int(int(Core.POINTS[g.type]) * multiplier * bonus)
		score += pts
		var col := Core.color_of(g.type)
		_spark_burst(g.pos, col, 40, 1.5)
		_spark_burst(g.pos, Color(1, 1, 0.9), 20, 1.0)
		arena_canvas.pulse(g.pos, 700.0, Core.GATE_BLAST * 1.6 * u)
		shake = maxf(shake, 0.35)
		_sfx("gate_boom", 0.0, minf(1.0 + (gate_combo - 1) * 0.08, 1.8), 0)
		var label := _num(pts) if gate_combo <= 1 else "%s  ×%d" % [_num(pts), gate_combo]
		_popup(g.pos, label, col.lightened(0.3), 26 if gate_combo <= 1 else 30)
		for k in int(Core.GEOMS[g.type]):
			_drop_geom(g.pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) * u, 1)
		for kk in Core.blast(enemies, g.pos, Core.GATE_BLAST * (1.4 if golden else 1.0) * u):
			_on_kill(kk, bonus)
		for b in bosses:
			if (b.pos as Vector2).distance_to(g.pos) < Core.GATE_BLAST * u + Bosses.body_radius(b):
				Bosses.damage(b, 25)
		_check_bosses_dead()
		# Mines in the blast go up too.
		for mi in range(mines.size() - 1, -1, -1):
			if mi < mines.size() and (mines[mi].pos as Vector2).distance_to(g.pos) < Core.GATE_BLAST * u:
				_detonate_mine(mi)

## A mine blows up the enemies around it, and sets off its neighbours.
func _detonate_mine(mi: int) -> void:
	var u: float = Core.U
	var pos: Vector2 = mines[mi].pos
	mines.remove_at(mi)
	_spark_burst(pos, Color(1.0, 0.35, 0.3), 26, 1.2)
	arena_canvas.pulse(pos, 450.0, Core.MINE_BLAST * 1.5 * u)
	_sfx_at("mine_boom", pos, 0.0, randf_range(0.9, 1.1), 50)
	shake = maxf(shake, 0.25)
	for kk in Core.blast(enemies, pos, Core.MINE_BLAST * u):
		_on_kill(kk)
	for i in range(mines.size() - 1, -1, -1):
		if i < mines.size() and (mines[i].pos as Vector2).distance_to(pos) < Core.MINE_BLAST * u:
			_detonate_mine(i)
			break  # the chain carries on from there

## Smart bomb: a shockwave wipes out every enemy on screen. No points or
## geoms for those -- it's an escape, not a farm. Bosses only take a dent.
func _on_bomb_pressed() -> void:
	if not game_active or game_over or ending >= 0.0 or bombs <= 0 or respawn_t > 0.0:
		return
	bombs -= 1
	for e in enemies:
		_spark_burst(e.pos, Core.color_of(e.type), 5, 1.4)
	enemies.clear()
	ebullets.clear()
	for b in bosses:
		Bosses.damage(b, 40)
		_spark_burst(b.pos, Bosses.color_of(b), 20, 1.4)
	_check_bosses_dead()
	shockwave_t = 0.0
	bomb_pos = player_pos
	spawn_timer = maxf(spawn_timer, 1.2)
	arena_canvas.shock(player_pos, 1.0)
	shake = 1.2
	_sfx("bomb", 3.0, 1.0, 0)
	_update_hud()

func _on_player_hit() -> void:
	var u: float = Core.U
	if int(rules.lives) > 0:
		lives -= 1
	deaths += 1
	_spark_burst(player_pos, Color(0.8, 0.95, 1.0), 70, 1.8)
	_spark_burst(player_pos, Color(1.0, 0.6, 0.3), 40, 1.2)
	arena_canvas.shock(player_pos, 0.8)
	shake = 1.3
	_sfx("death", 3.0, 1.0, 0)
	# Everything on screen goes with the ship (no points), like the original.
	for e in enemies:
		_spark_burst(e.pos, Core.color_of(e.type), 4, 1.2)
	enemies = enemies.filter(func(e): return e.type in Core.GATES and not rules.gun)
	bullets.clear()
	ebullets.clear()
	crystals.clear()
	mines.clear()
	multiplier = 1
	geom_chain = 0
	gate_combo = 0
	if sounds:
		sounds.reset_calm()  # the screen is empty again: back to calm music
		sounds.silence_loops()
	if int(rules.lives) > 0 and lives <= 0:
		_end_game(false)
		return
	respawn_t = RESPAWN_TIME
	spawn_timer = RESPAWN_TIME + 1.0

func _respawn() -> void:
	var u: float = Core.U
	# Back in the middle -- or, with a boss about, as far from it as possible.
	var p := arena_size / 2.0
	for b in bosses:
		var away: Vector2 = arena_size - (b.pos as Vector2)
		p = away.clamp(Vector2(4, 4) * u, arena_size - Vector2(4, 4) * u)
	player_pos = p
	player_prev = p
	invuln_timer = INVULN_TIME
	beep_step = 99
	_release_sticks()
	_sfx("respawn", -2.0)
	arena_canvas.pulse(p, -300.0, 6.0 * u)

# ---------- King ----------

func _update_zones(delta: float) -> void:
	var u: float = Core.U
	king_zone = -1
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		if z.active:
			z.left = float(z.left) - delta
			z.r = lerpf(1.3, KING_ZONE_R, clampf(float(z.left) / KING_ZONE_LIFE, 0.0, 1.0))
			if float(z.left) <= 0.0:
				zones.remove_at(i)
				_sfx("zone_off", -2.0)
				continue
		else:
			z.idle = float(z.idle) - delta
			if float(z.idle) <= 0.0:
				zones.remove_at(i)
				continue
	if respawn_t <= 0.0:
		var zi := Core.in_zone(player_pos, zones)
		if zi >= 0:
			if not zones[zi].active:
				zones[zi].active = true
				zones[zi].left = KING_ZONE_LIFE
				_sfx("zone_on", -2.0)
			king_zone = zi
	zone_t -= delta
	if zones.size() < KING_ZONES and zone_t <= 0.0:
		zone_t = 2.0
		var p := Core.spawn_point(arena_size, player_pos, 6.0, 14.0).clamp(Vector2(4, 4) * u, arena_size - Vector2(4, 4) * u)
		zones.append({"pos": p, "r": KING_ZONE_R, "active": false, "left": KING_ZONE_LIFE, "life": KING_ZONE_LIFE, "idle": 18.0})

# ---------- goals, endings ----------

func _check_goal() -> void:
	if ending >= 0.0 or not game_active:
		return
	var t: int = int(rules.time)
	if t > 0:
		var left := float(t) - elapsed_seconds
		if left <= 10.0 and int(ceil(left)) != tick_shown and left > 0.0:
			tick_shown = int(ceil(left))
			_sfx("tick", -2.0, 1.0 + (10.0 - left) * 0.03, 0)
		if left <= 0.0:
			# Deadline ends here; a "survive" level is won.
			_end_game(rules.goal == "survive")
			return
	match str(rules.goal):
		"kills":
			if kills >= int(rules.n):
				_end_game(true)
		"gates":
			if gates_passed >= int(rules.n):
				_end_game(true)
		"geoms":
			if geoms_got >= int(rules.n):
				_end_game(true)
		"boss":
			var rush_left: bool = not (rules.get("rush", []) as Array).is_empty() and (rush_index < (rules.rush as Array).size() or rush_t >= 0.0)
			if bosses.is_empty() and boss_events_left <= 0 and not rush_left:
				_end_game(true)

## The game is over: won (a level cleared, Boss Rush beaten, or simply the
## end of a classic game) or lost. A short pause, then the result card.
func _end_game(success: bool) -> void:
	if ending >= 0.0:
		return
	won = success
	ending = 1.6
	SaveUtil.delete(SAVE_PATH)
	if sounds:
		sounds.stop_music(2.0)
		sounds.silence_loops()
	if success:
		for e in enemies:
			_spark_burst(e.pos, Core.color_of(e.type), 6, 1.2)
		enemies.clear()
		ebullets.clear()
		arena_canvas.shock(player_pos, 0.6)
		if rules.campaign or mode == "bossrush":
			_show_banner(tr("LEVEL COMPLETE!") if rules.campaign else tr("BOSS RUSH CLEARED!"), Color(1, 0.9, 0.4))
	elif rules.campaign:
		_sfx("level_fail", 0.0, 1.0, 0)

func _show_result() -> void:
	game_active = false
	game_over = true
	for c in result_box.get_children():
		c.queue_free()
	var title := ""
	var color := HomeKit.CYAN
	var lines: Array = []
	var record := false
	if info:
		info.add("Games played")
		if bosses_beaten > 0:
			info.add("Bosses defeated", bosses_beaten)
		if gates_passed > 0:
			info.add("Seals broken", gates_passed)
		info.high("Highest multiplier", peak_mult)
		if mode == "evolved":
			info.high("Longest time survived", elapsed_seconds)
	if rules.campaign:
		var data := Campaign.load_progress()
		if won:
			var stars := Levels.stars_for(level_id, score, deaths)
			var fresh: Array = Campaign.record(data, level_id, hardcore, stars, score)
			title = tr("Level complete!")
			color = HomeKit.GOLD
			lines.append("★".repeat(stars) + "☆".repeat(3 - stars))
			if deaths > 0:
				lines.append(tr("★★ needs a run without losing a life"))
			if score < int(rules.target):
				lines.append(tr("★★★ needs %s points") % _num(int(rules.target)))
			for k in fresh:
				lines.append(tr("New familiar: %s") % tr(str(Drones.LABELS[k])))
			if info:
				info.high("Campaign stars", Campaign.total_stars(data, false))
				info.high("Cursed stars", Campaign.total_stars(data, true))
				info.high("Familiars unlocked", Campaign.drones_open(data))
				info.add("Levels cleared")
				info.celebrate("Level complete!")
			else:
				_sfx("level_clear")
		else:
			title = tr("Out of lives")
			color = HomeKit.PINK
		var best := int((data["hbest" if hardcore else "best"] as Dictionary).get(str(level_id), 0))
		lines.push_front(tr("Level %d · %s") % [level_id, tr(str(rules.name))])
		lines.append(tr("Score: %s") % _num(score))
		if best > 0:
			lines.append(tr("Best: %s") % _num(best))
	else:
		title = tr("BOSS RUSH CLEARED!") if (mode == "bossrush" and won) else tr("Game Over")
		color = HomeKit.GOLD if won else HomeKit.PINK
		lines.append(tr(str(rules.title)))
		lines.append(tr("Score: %s") % _num(score))
		lines.append(tr("Time: %s") % _format_time(elapsed_seconds) + "   ·   " + tr("Best multiplier: ×%d") % peak_mult)
		if info:
			if mode == "bossrush" and won:
				info.add("Boss Rush clears")
			record = info.best(str(rules.stat), score)
			var best_now := int(info.get_stat(str(rules.stat), score))
			lines.append(tr("New best!") if record else tr("Best: %s") % _num(best_now))
		if not record:
			_sfx("level_fail" if not won else "level_clear", -3.0)
	var t := HomeKit.label(title, 40, color, false, true)
	t.add_theme_color_override("font_outline_color", Color(color, 0.45))
	t.add_theme_constant_override("outline_size", 8)
	result_box.add_child(t)
	for l in lines:
		# Only the row of stars itself is drawn big.
		var big: bool = str(l) != "" and str(l).replace("★", "").replace("☆", "") == ""
		result_box.add_child(HomeKit.label(str(l), 46 if big else 24, HomeKit.GOLD if big else HomeKit.WHITE, true, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	result_box.add_child(row)
	if rules.campaign:
		var data2 := Campaign.load_progress()
		if won and level_id < Levels.count() and Campaign.is_open(data2, level_id + 1, hardcore):
			row.add_child(_result_button("Next ▶", HomeKit.LIME, _start_level.bind(level_id + 1, hardcore, drone_kind)))
		row.add_child(_result_button("Retry", HomeKit.CYAN, _restart_current))
		row.add_child(_result_button("🗺 Levels", HomeKit.GOLD, _open_campaign.bind(hardcore)))
	else:
		row.add_child(_result_button("Play Again", HomeKit.LIME, _restart_current))
	row.add_child(_result_button("🏠 Home", HomeKit.PURPLE, _go_home))
	result_dialog.visible = true

func _result_button(text: String, color: Color, action: Callable) -> Button:
	var b := HomeKit.neon_button(tr(text), color, 24, 62)
	b.custom_minimum_size.x = 150
	b.pressed.connect(action)
	return b

# ---------- audio ----------

## Tells the music how crowded it is, and drives the loops (an awake well's
## hum, the skittering of loose protons).
func _update_audio() -> void:
	if sounds == null:
		return
	var u: float = Core.U
	var reach := 24.0 * u
	var crowd := 0.0
	var protons := 0
	var hum := 0.0
	for e in enemies:
		var d: float = (e.pos as Vector2).distance_to(player_pos)
		if d > reach:
			continue
		match e.type:
			"gate", "golden":
				pass
			"mayfly":
				crowd += 0.4
			"well":
				crowd += 2.0
				if e.active:
					hum = maxf(hum, 1.0 - d / (Core.well_range(e) * u * 1.6))
			"snake", "repulsor":
				crowd += 2.0
			"proton":
				crowd += 1.0
				protons += 1
			_:
				crowd += 1.0
	if not bosses.is_empty():
		crowd += 60.0
	sounds.set_intensity(crowd)
	sounds.set_loop("hum", hum * 0.8)
	sounds.set_loop("skitter", minf(1.0, protons / 10.0) * 0.9)

# ---------- camera ----------

func _update_camera(delta: float) -> void:
	var target := player_pos - view_size / 2.0
	var u: float = Core.U
	for ax in 2:
		if arena_size[ax] + 2.0 * u <= view_size[ax]:
			target[ax] = (arena_size[ax] - view_size[ax]) / 2.0
		else:
			target[ax] = clampf(target[ax], -u, arena_size[ax] - view_size[ax] + u)
	cam = cam.lerp(target, clampf(delta * 7.0, 0.0, 1.0))
	var jolt := Vector2.ZERO
	if shake > 0.0:
		jolt = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 0.45 * u
	arena_canvas.position = -cam + jolt

func _update_hud() -> void:
	score_label.text = _num(score)
	if int(rules.lives) == 0:
		lives_label.text = "♥ ∞"
	else:
		lives_label.text = "♥ %d" % lives
	combo_label.text = "×%d" % multiplier
	bomb_button.text = "💣 ×%d" % bombs
	bomb_button.disabled = bombs <= 0
	bomb_button.visible = int(rules.bombs) > 0 or int(rules.bomb_every) > 0 or bombs > 0
	var g := ""
	match str(rules.goal):
		"kills":
			g = tr("Kills %d/%d") % [mini(kills, int(rules.n)), int(rules.n)]
		"gates":
			g = tr("Seals %d/%d") % [mini(gates_passed, int(rules.n)), int(rules.n)]
		"geoms":
			g = tr("Souls %d/%d") % [mini(geoms_got, int(rules.n)), int(rules.n)]
	if int(rules.time) > 0:
		var clock := "⏱ " + _format_time(float(rules.time) - elapsed_seconds)
		g = clock if g == "" else g + "  " + clock
	if rules.king:
		g = (tr("🕯 Fire!") if king_zone >= 0 else tr("🕯 Find a circle")) + ("  " + g if g != "" else "")
	goal_label.text = g
	goal_label.visible = g != ""

static func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

func _show_banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_outline_color", Color(color, 0.5))
	banner.modulate.a = 1.0
	banner.visible = true
	var tw := banner.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.8)

# ---------- UI construction ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	sounds = Sounds.new()
	add_child(sounds)

	_build_game_screen()

	joystick_canvas = JoystickCanvas.new()
	joystick_canvas.game = self
	add_child(joystick_canvas)

	_build_result_dialog()

	campaign = Campaign.new()
	campaign.visible = false
	campaign.play_level.connect(_on_campaign_play)
	campaign.closed.connect(_on_campaign_closed)
	add_child(campaign)

	_build_rotate_hint()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
		_move_renamed_stats()
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

## Stats saved under the names from before the re-theme move to the new ones
## (the higher value wins; counters add up), so no record is lost.
func _move_renamed_stats() -> void:
	if not ("stats" in info) or not info.has_method("_save"):
		return
	var stats: Dictionary = info.stats
	var moved := false
	for old in HELP.RENAMED_STATS:
		if not stats.has(old):
			continue
		var new_key: String = HELP.RENAMED_STATS[old]
		var v: float = float(stats[old])
		if old == "Gates exploded":
			stats[new_key] = int(stats.get(new_key, 0)) + int(v)
		else:
			stats[new_key] = maxf(float(stats.get(new_key, v)), v)
		stats.erase(old)
		moved = true
	# Badges earned under an old name ("<stat>_<tier>") move too, or the
	# same badge would unlock again under the new name and count twice.
	var ach = stats.get("_ach")
	if typeof(ach) == TYPE_DICTIONARY:
		for id in ach.keys():
			for old in HELP.RENAMED_STATS:
				var prefix: String = old + "_"
				if str(id).begins_with(prefix) and str(id).substr(prefix.length()).is_valid_int():
					var new_id: String = HELP.RENAMED_STATS[old] + "_" + str(id).substr(prefix.length())
					if not ach.has(new_id):
						ach[new_id] = ach[id]
					ach.erase(id)
					moved = true
	if moved:
		info._save()

func _build_rotate_hint() -> void:
	rotate_hint = ColorRect.new()
	rotate_hint.color = Color(0.04, 0.04, 0.07, 0.96)
	rotate_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	rotate_hint.visible = false
	add_child(rotate_hint)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_hint.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var icon := Label.new()
	icon.text = "⟳"
	icon.add_theme_font_size_override("font_size", 52)
	icon.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(icon)

	var label := Label.new()
	label.text = tr("Rotate your device to landscape")
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

func _build_game_screen() -> void:
	game_screen = Control.new()
	game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_screen.visible = false
	add_child(game_screen)

	view_clip = Control.new()
	view_clip.clip_contents = true
	view_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_screen.add_child(view_clip)

	arena_canvas = ArenaCanvas.new()
	arena_canvas.game = self
	view_clip.add_child(arena_canvas)

	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 40)
	banner.add_theme_constant_override("outline_size", 10)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	game_screen.add_child(banner)

	minimap = Control.new()
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	game_screen.add_child(minimap)

	boss_bar = Control.new()
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.draw.connect(_draw_boss_bar)
	game_screen.add_child(boss_bar)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 8)
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_right", 12)
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_screen.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_child(top_bar)

	pause_button = _neon_button("⏸ " + tr("Pause"), Color(0.3, 1.0, 1.0))
	pause_button.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_button)

	score_label = _stat_label("0")
	lives_label = _stat_label("♥ 3")
	combo_label = _stat_label("×1")
	combo_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	goal_label = _stat_label("")
	goal_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	for l in [score_label, lives_label, combo_label, goal_label]:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_bar.add_child(l)

	bomb_button = _neon_button("💣 ×3", Color(1.0, 0.55, 0.2))
	bomb_button.pressed.connect(_on_bomb_pressed)
	bomb_button.set_meta("sfx", "")
	top_bar.add_child(bomb_button)
	var drawer_gap := Control.new()  # keeps Bomb clear of the ⚙ tab
	drawer_gap.custom_minimum_size = Vector2(40, 0)
	top_bar.add_child(drawer_gap)

## The view, the minimap and the banner follow the screen's size.
func _layout() -> void:
	if game_screen == null:
		return
	view_rect = Rect2(Vector2(0, HUD_H), Vector2(size.x, maxf(100.0, size.y - HUD_H)))
	view_size = view_rect.size
	view_clip.position = view_rect.position
	view_clip.size = view_rect.size
	banner.position = Vector2(view_rect.position.x + 40, view_rect.position.y + view_rect.size.y * 0.22)
	banner.size = Vector2(view_rect.size.x - 80, 120)
	# Top left, under the Pause button: the bottom of the screen is the thumbs'.
	var mw := clampf(size.x * 0.13, 100.0, 170.0)
	var aspect := arena_size.y / maxf(arena_size.x, 1.0)
	minimap.size = Vector2(mw, mw * aspect)
	minimap.position = Vector2(12.0, HUD_H + 8.0)
	boss_bar.position = Vector2(size.x * 0.25, HUD_H + 6)
	boss_bar.size = Vector2(size.x * 0.5, 34)

## A dark button with a bright neon rim, readable over the arena.
func _neon_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 52)
	b.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.06, 0.12, 0.9) if state != "pressed" else Color(color, 0.3)
		sb.set_border_width_all(2)
		sb.border_color = color if state != "disabled" else Color(color, 0.3)
		sb.set_corner_radius_all(10)
		sb.shadow_color = Color(color, 0.35)
		sb.shadow_size = 6 if state != "disabled" else 0
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, color.lightened(0.3))
	b.add_theme_color_override("font_disabled_color", Color(color, 0.35))
	return b

func _stat_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _build_result_dialog() -> void:
	result_dialog = ColorRect.new()
	(result_dialog as ColorRect).color = Color(0, 0, 0, 0.72)
	result_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_dialog.visible = false
	add_child(result_dialog)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 10)
	panel.add_child(result_box)

## The overview map: the whole arena, the view, the ship, enemies, bosses.
func _draw_minimap() -> void:
	if not game_active or arena_size.x <= view_size.x + 2.0 * Core.U and arena_size.y <= view_size.y + 2.0 * Core.U:
		return
	var s: Vector2 = minimap.size
	var k := s.x / arena_size.x
	minimap.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.08, 0.55))
	minimap.draw_rect(Rect2(Vector2.ZERO, s), Color(arena_canvas.grid_color.lightened(0.3), 0.7), false, 1.5)
	minimap.draw_rect(Rect2(cam * k, view_size * k), Color(1, 1, 1, 0.25), false, 1.0)
	for e in enemies:
		if e.warm > 0.0:
			continue
		minimap.draw_rect(Rect2((e.pos as Vector2) * k - Vector2(1, 1), Vector2(2.5, 2.5)), Color(Core.color_of(e.type), 0.85))
	for z in zones:
		minimap.draw_arc((z.pos as Vector2) * k, float(z.r) * Core.U * k, 0, TAU, 12, Color(1, 0.85, 0.3, 0.8), 1.0)
	for b in bosses:
		minimap.draw_circle((b.pos as Vector2) * k, 5.0, Color(Bosses.color_of(b), 0.9))
	minimap.draw_circle(player_pos * k, 3.0, Color.WHITE)

func _draw_boss_bar() -> void:
	if bosses.is_empty() or not game_active:
		return
	var s: Vector2 = boss_bar.size
	var hp := 0
	var mx := 0
	var names: PackedStringArray = []
	var col := Color.WHITE
	for b in bosses:
		hp += Bosses.total_hp(b)
		mx += int(b.max_hp)
		names.append(tr(Bosses.name_of(b)))
		col = Bosses.color_of(b)
	var k := float(hp) / maxf(1.0, mx)
	var bar := Rect2(Vector2(0, 18), Vector2(s.x, 12))
	boss_bar.draw_rect(bar, Color(0, 0, 0, 0.6))
	boss_bar.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color(col, 0.85))
	boss_bar.draw_rect(bar, Color(col.lightened(0.4), 0.9), false, 1.5)
	var font := ThemeDB.fallback_font
	var text := " + ".join(names)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	boss_bar.draw_string_outline(font, Vector2((s.x - w) / 2.0, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
	boss_bar.draw_string(font, Vector2((s.x - w) / 2.0, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col.lightened(0.5))

# ---------- game flow ----------

## A classic mode from Home: a fresh game (any saved one is dropped).
func _start_mode(m: String) -> void:
	SaveUtil.delete(SAVE_PATH)
	mode = m
	level_id = 0
	hardcore = false
	drone_kind = ""
	rules = Levels.classic(m)
	_begin()

func _start_level(id: int, hard: bool, drone: String) -> void:
	SaveUtil.delete(SAVE_PATH)
	mode = "campaign"
	level_id = id
	hardcore = hard
	drone_kind = "" if hard else drone
	rules = Levels.level(id)
	_begin()
	_show_banner("%s %d · %s\n%s" % [tr("Level"), id, tr(str(rules.name)), Levels.goal_text(rules)], (rules.grid as Color).lightened(0.4))

func _restart_current() -> void:
	if mode == "campaign":
		_start_level(level_id, hardcore, drone_kind)
	elif mode != "":
		_start_mode(mode)

func _begin(fresh: bool = true) -> void:
	_layout()
	if fresh:
		Core.U = view_size.y / VIEW_SQUARES
	var u: float = Core.U
	arena_size = Vector2(float(rules.map[0]), float(rules.map[1])) * u
	_layout()  # the minimap's shape follows the map
	arena_canvas.grid_color = rules.grid
	arena_canvas.reset_grid()
	if fresh:
		player_pos = arena_size / 2.0
		player_prev = player_pos
		ship_dir = Vector2.RIGHT
		lives = int(rules.lives)
		score = 0
		multiplier = 1
		peak_mult = 1
		bombs = int(rules.bombs)
		next_bomb_at = int(rules.bomb_every)
		next_life_at = int(rules.life_every)
		elapsed_seconds = 0.0
		kills = 0
		gates_passed = 0
		geoms_got = 0
		bosses_beaten = 0
		deaths = 0
		enemies = []
		bullets = []
		ebullets = []
		crystals = []
		mines = []
		zones = []
		bosses = []
		ev_next = []
		for ev in rules.events:
			ev_next.append(float(ev[0]))
		boss_events_left = 0
		for ev in rules.events:
			if str(ev[2]) == "boss":
				boss_events_left += 1
		rush_index = 0
		rush_t = -1.0
		gate_t = 1.5
		wave_t = 3.0
		zone_t = 0.0
		spawn_timer = 0.6
		next_entity_id = 1
	particles = []
	popups = []
	rays = []
	drones = []
	if drone_kind != "":
		drones.append(Drones.make(drone_kind, player_pos))
	invuln_timer = INVULN_TIME
	respawn_t = 0.0
	beep_step = 99
	fire_cooldown_timer = 0.0
	shockwave_t = -1.0
	gate_combo = 0
	geom_chain = 0
	king_zone = -1
	ending = -1.0
	won = false
	tick_shown = -1
	shake = 0.0
	_release_sticks()
	cam = player_pos - view_size / 2.0
	_update_camera(1.0)
	game_active = true
	game_over = false
	result_dialog.visible = false
	campaign.visible = false
	game_screen.visible = true
	if sounds:
		sounds.silence_loops()
		sounds.start_music()
		sounds.play("level_start", -3.0, 1.0, 0)
	_update_hud()

func _on_pause_pressed() -> void:
	if not game_active or game_over:
		return
	home.pause()

func _go_home() -> void:
	home.go_home()

func _open_campaign(hard: bool = false) -> void:
	game_active = false
	game_over = false
	result_dialog.visible = false
	game_screen.visible = false
	if sounds:
		sounds.stop_music(0.8)
		sounds.silence_loops()
	if home.is_home_visible():
		home.hide_home()
	campaign.open(hard)

func _on_campaign_play(id: int, hard: bool, drone: String) -> void:
	_start_level(id, hard, drone)

func _on_campaign_closed() -> void:
	home.show_home()

# ---------- save / load ----------

## Everything needed to carry on, as a var_to_str() blob (it keeps Vector2s
## and nested arrays exact, which JSON wouldn't).
func _save_game() -> void:
	if not game_active or game_over or ending >= 0.0:
		return
	var state := {
		"mode": mode, "level": level_id, "hardcore": hardcore, "drone": drone_kind, "U": Core.U,
		"player": player_pos, "lives": lives, "score": score, "multiplier": multiplier, "peak": peak_mult,
		"bombs": bombs, "next_bomb_at": next_bomb_at, "next_life_at": next_life_at,
		"elapsed": elapsed_seconds, "kills": kills, "gates": gates_passed, "geoms": geoms_got,
		"bosses_beaten": bosses_beaten, "enemies": enemies, "mines": mines, "zones": zones, "bosses": bosses,
		"ev_next": ev_next.map(func(x): return -1.0 if is_inf(float(x)) else x),
		"boss_events_left": boss_events_left, "rush_index": rush_index, "rush_t": rush_t,
		"gate_t": gate_t, "wave_t": wave_t, "next_id": next_entity_id,
	}
	SaveUtil.write(SAVE_PATH, {"v": 2, "mode": mode, "level": level_id, "score": score, "blob": var_to_str(state)})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary):
		return ""
	var what := ""
	if str(d.get("mode", "")) == "campaign":
		what = tr("Level %d") % int(d.get("level", 1))
	elif Levels.CLASSIC.has(str(d.get("mode", ""))):
		what = tr(str(Levels.CLASSIC[str(d.mode)].title))
	return (what + " · " if what != "" else "") + tr("Score: %s") % _num(int(d.get("score", 0)))

func _resume_saved() -> void:
	if not _load_saved_game():
		_start_mode("evolved")

func _load_saved_game() -> bool:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("blob"):
		return false  # nothing, or a save from before the campaign update
	var s = str_to_var(str(d.blob))
	if not (s is Dictionary):
		return false
	mode = str(s.mode)
	level_id = int(s.level)
	hardcore = bool(s.hardcore)
	drone_kind = str(s.drone)
	if mode == "campaign":
		if level_id < 1 or level_id > Levels.count():
			return false
		rules = Levels.level(level_id)
	elif Levels.CLASSIC.has(mode):
		rules = Levels.classic(mode)
	else:
		return false
	Core.U = float(s.U)
	player_pos = s.player
	player_prev = player_pos
	ship_dir = Vector2.RIGHT
	lives = int(s.lives)
	score = int(s.score)
	multiplier = int(s.multiplier)
	peak_mult = int(s.peak)
	bombs = int(s.bombs)
	next_bomb_at = int(s.next_bomb_at)
	next_life_at = int(s.next_life_at)
	elapsed_seconds = float(s.elapsed)
	kills = int(s.kills)
	gates_passed = int(s.gates)
	geoms_got = int(s.geoms)
	bosses_beaten = int(s.bosses_beaten)
	enemies = s.enemies
	mines = s.mines
	zones = s.zones
	bosses = s.bosses
	ev_next = (s.ev_next as Array).map(func(x): return INF if float(x) < 0.0 else float(x))
	while ev_next.size() < (rules.events as Array).size():
		ev_next.append(INF)
	boss_events_left = int(s.boss_events_left)
	rush_index = int(s.rush_index)
	rush_t = float(s.rush_t)
	gate_t = float(s.gate_t)
	wave_t = float(s.wave_t)
	next_entity_id = int(s.next_id)
	bullets = []
	ebullets = []
	crystals = []
	spawn_timer = 1.0
	_begin(false)
	return true

# ---------- Home screen (home_kit.gd) ----------

func _build_home() -> void:
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "A neon voodoo shooter. Break the swarm with a storm of pins.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "💀  Endless", "sub": "3 lives, bombs, the full swarm", "action": _start_mode.bind("evolved")},
			{"text": "🗺  Campaign", "sub": "40 levels · bosses · familiars", "action": _open_campaign.bind(false), "color": HomeKit.GOLD},
			{"text": "⏱ Time Attack", "sub": "3 minutes", "row": 1, "action": _start_mode.bind("deadline"), "color": HomeKit.LIME},
			{"text": "✋ Unarmed", "sub": "No pins: break seals", "row": 1, "action": _start_mode.bind("pacifism"), "color": HomeKit.LIME},
			{"text": "🕯 Sanctuary", "sub": "Shoot from the circles", "row": 1, "action": _start_mode.bind("king"), "color": HomeKit.LIME},
			{"text": "🐃 Stampede", "sub": "Walls of darts", "row": 2, "action": _start_mode.bind("waves"), "color": HomeKit.PINK},
			{"text": "⚰ Coffin", "sub": "A tiny box", "row": 2, "action": _start_mode.bind("claustro"), "color": HomeKit.PINK},
			{"text": "☠ Boss Rush", "sub": "Every boss", "row": 2, "action": _start_mode.bind("bossrush"), "color": HomeKit.PINK},
		],
		"save_path": SAVE_PATH,
		"resume": _resume_saved,
		"resume_text": _resume_text,
		"restart": _restart_current,
		"board_note": "Your best Endless score.",
		"extra": _add_options,
	})
	add_child(home)

func _add_options(box: Control) -> void:
	box.add_child(home.section("🎵 Music"))
	box.add_child(home.choice_row(["On", "Off"], 0 if sounds.music_on else 1, _on_music_pick, HomeKit.PURPLE))

func _on_music_pick(i: int) -> void:
	sounds.set_music_on(i == 0)

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0) + Vector2(-h * 0.35, 0)
	var k := h * 0.42  # the skull's size
	var at := func(x: float, y: float) -> Vector2: return ctr + Vector2(x, y) * k
	# The horned skull, facing right, firing pins.
	var skull := PackedVector2Array()
	for i in 11:
		var a := -PI * 0.55 + PI * 1.1 * i / 10.0
		skull.append(at.call(0.05 + cos(a) * 0.42, sin(a) * 0.42))
	for v in [Vector2(-0.3, 0.3), Vector2(-0.55, 0.2), Vector2(-0.55, -0.2), Vector2(-0.3, -0.3)]:
		skull.append(at.call(v.x, v.y))
	HomeKit.glow_polyline(c, skull, Color(0.9, 0.96, 1.0), 2.5, true)
	for side in [-1.0, 1.0]:
		var horn := PackedVector2Array([at.call(0.18, side * 0.36), at.call(0.25, side * 0.62), at.call(0.52, side * 0.78),
			at.call(0.85, side * 0.7), at.call(1.05, side * 0.5)])
		HomeKit.glow_polyline(c, horn, Color(1.0, 0.95, 0.85), 2.2)
		HomeKit.glow_circle(c, at.call(0.08, side * 0.17), k * 0.09, HomeKit.PURPLE, 2.0, 0.8)
	# The pin storm.
	for i in 3:
		var y := (i - 1) * 0.22
		var tail: Vector2 = at.call(1.25 + i * 0.12, y)
		HomeKit.glow_line(c, tail, tail + Vector2(k * 0.45, 0), Color(0.95, 0.95, 1.0), 1.6)
		HomeKit.glow_circle(c, tail, k * 0.06, HomeKit.GOLD, 1.6, 1.0)
	# A stalker eye in their path, crossbones tumbling behind it.
	var eye := ctr + Vector2(h * 1.15, -h * 0.05)
	var lid := PackedVector2Array()
	for i in 13:
		var x := -1.0 + i / 6.0
		lid.append(eye + Vector2(x * h * 0.16, -(1.0 - x * x) * h * 0.1))
	for i in range(11, 0, -1):
		var x := -1.0 + i / 6.0
		lid.append(eye + Vector2(x * h * 0.16, (1.0 - x * x) * h * 0.1))
	HomeKit.glow_polyline(c, lid, HomeKit.PINK, 2.2, true)
	HomeKit.glow_circle(c, eye - Vector2(h * 0.04, 0), h * 0.05, HomeKit.PINK, 1.8)
	var cb := ctr + Vector2(h * 1.55, h * 0.25)
	for s in [-1.0, 1.0]:
		HomeKit.glow_line(c, cb + Vector2(-h * 0.11, -h * 0.11 * s), cb + Vector2(h * 0.11, h * 0.11 * s), Color("f2e6b8"), 2.0)
