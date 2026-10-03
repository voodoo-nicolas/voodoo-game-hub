extends Control

const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Core = preload("res://scripts/games/geometry_wars/geometry_wars_core.gd")
const HomeKit = preload("res://scripts/games/geometry_wars/home_kit.gd")
const ArenaCanvas = preload("res://scripts/games/geometry_wars/arena_canvas.gd")
const JoystickCanvas = preload("res://scripts/games/geometry_wars/joystick_canvas.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://geometry_wars_save.json"

const START_BOMBS := 3
const MAX_BOMBS := 6
## A free bomb every this many points.
const BOMB_EVERY_POINTS := 2500
const SHOCKWAVE_TIME := 0.6
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
const SPAWN_INTERVAL_START := 1.8
const SPAWN_INTERVAL_MIN := 0.55
const SPAWN_RAMP_TIME := 90.0
const MAX_ENEMIES := 90
## The shield after (re)spawning: a halo for 5 s, and 6 quick beeps in the
## last 1.2 s warn that it is about to drop.
const INVULN_TIME := 5.0
const BEEP_WINDOW := 1.2
const BEEP_COUNT := 6
const STARTING_LIVES := 3
const COMBO_WINDOW := 2.0
const COMBO_STEP := 5
const JOYSTICK_RADIUS := 70.0
const JOYSTICK_DEADZONE := 0.15
const MAX_PARTICLES := 500
const MAX_CRYSTALS := 250

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var arena_size: Vector2 = Vector2(600, 900)
var arena_offset: Vector2 = Vector2(20, 90)

var player_pos: Vector2 = Vector2.ZERO
## The ship points where the move stick points; the aim stick only fires.
var ship_dir: Vector2 = Vector2.RIGHT
var thrust: float = 0.0
var beep_step: int = 99
var burst_count: int = 0
var invuln_timer: float = 0.0
var lives: int = STARTING_LIVES
var score: int = 0
var combo: int = 0
var combo_timer: float = 0.0
var fire_cooldown_timer: float = 0.0
var spawn_timer: float = 0.0
var elapsed_seconds: float = 0.0
var next_entity_id: int = 1
var enemies: Array = []
var bullets: Array = []
var particles: Array = []
## Dropped by every kill; each one picked up adds 1 to the score multiplier.
## They fade after Core.CRYSTAL_LIFE seconds. Dying resets the multiplier.
var crystals: Array = []
var multiplier: int = 1
var bombs: int = START_BOMBS
var next_bomb_at: int = BOMB_EVERY_POINTS
var shockwave_t: float = -1.0  # seconds since the last bomb, -1 = none
var bomb_button: Button
var pause_button: Button

var game_active: bool = false
var paused: bool = false
var game_over: bool = false

var move_touch_index: int = -1
var move_origin: Vector2 = Vector2.ZERO
var move_value: Vector2 = Vector2.ZERO
var aim_touch_index: int = -1
var aim_origin: Vector2 = Vector2.ZERO
var aim_value: Vector2 = Vector2.ZERO

var start_screen: Control
var continue_button: Button
var game_screen: Control
var arena_canvas: Node2D
var joystick_canvas: Node2D
var score_label: Label
var lives_label: Label
var combo_label: Label
var pause_dialog: Control
var game_over_dialog: Control
var game_over_stats: Label
var rotate_hint: Control

func _ready() -> void:
	preload("res://scripts/games/geometry_wars/geometry_wars_i18n.gd").install(self)
	randomize()
	Orientation.lock_landscape()
	_build_ui()
	_show_start_screen()
	start_screen.visible = false  # the Home screen replaces it

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()
	# Leaving the app mid-wave (home button, a phone call) opens the pause
	# menu, so coming back doesn't drop the player straight into enemies.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if game_active and not paused and not game_over:
			_on_pause_pressed()

## The hub locks back to portrait on its own _ready(), so leaving here doesn't need to
## reset orientation itself -- that used to be the only thing restoring portrait, which broke
## whenever a player left by any path other than these exact buttons (e.g. the OS back
## gesture), leaving the whole app stuck in landscape.
func _exit_to_hub() -> void:
	_save_game()
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

func _format_time(s: float) -> String:
	var total := int(s)
	return "%02d:%02d" % [int(total / 60), total % 60]

# ---------- input ----------

## Forget both thumbs. A release that arrives while paused is otherwise
## never seen, leaving a stick "held" forever after resuming: the ship keeps
## drifting and new touches on that side are ignored.
func _release_sticks() -> void:
	move_touch_index = -1
	aim_touch_index = -1
	move_value = Vector2.ZERO
	aim_value = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not game_active or paused or game_over:
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
	if aim_touch_index != -1:
		if aim_value.length() > JOYSTICK_DEADZONE:
			return {"dir": aim_value.normalized(), "firing": true}
		return {"dir": Vector2.ZERO, "firing": false}

	var mouse_pos: Vector2 = get_local_mouse_position() - arena_offset
	var dir: Vector2 = mouse_pos - player_pos
	var firing: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("ui_accept")
	if dir.length() > 0.01:
		return {"dir": dir.normalized(), "firing": firing}
	return {"dir": Vector2.ZERO, "firing": firing}

# ---------- main loop ----------

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _process(delta: float) -> void:
	rotate_hint.visible = get_viewport_rect().size.x < get_viewport_rect().size.y

	if not game_active or paused or game_over:
		return
	elapsed_seconds += delta
	var u: float = Core.U

	var move_dir: Vector2 = _get_move_dir()
	thrust = move_dir.length()
	if thrust > 0.2:
		ship_dir = ship_dir.slerp(move_dir.normalized(), clampf(delta * 20.0, 0.0, 1.0))
	player_pos += move_dir * Core.PLAYER_TOP_SPEED * u * delta + Core.well_pull(enemies, player_pos) * delta
	player_pos.x = clamp(player_pos.x, 0, arena_size.x)
	player_pos.y = clamp(player_pos.y, 0, arena_size.y)

	var aim: Dictionary = _get_aim()
	var aim_dir: Vector2 = aim.dir

	if invuln_timer > 0.0:
		invuln_timer = max(0.0, invuln_timer - delta)
		if invuln_timer < BEEP_WINDOW:
			var step := int(invuln_timer / (BEEP_WINDOW / BEEP_COUNT))
			if step != beep_step:
				beep_step = step
				_sfx("tick")
	if shockwave_t >= 0.0:
		shockwave_t += delta
		if shockwave_t > SHOCKWAVE_TIME:
			shockwave_t = -1.0

	fire_cooldown_timer -= delta
	if aim.firing and aim_dir.length() > 0.01:
		if fire_cooldown_timer <= 0.0:
			_fire_burst(aim_dir)
			fire_cooldown_timer += FIRE_INTERVAL
	elif fire_cooldown_timer < 0.0:
		fire_cooldown_timer = 0.0

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var t: float = clamp(elapsed_seconds / SPAWN_RAMP_TIME, 0.0, 1.0)
		spawn_timer = lerp(SPAWN_INTERVAL_START, SPAWN_INTERVAL_MIN, t)
		if enemies.size() < MAX_ENEMIES:
			for e in Core.spawn_group(arena_size, elapsed_seconds, player_pos):
				e.id = next_entity_id
				next_entity_id += 1
				enemies.append(e)

	for ev in Core.update_enemies(enemies, player_pos, arena_size, delta, bullets, crystals):
		_on_event(ev)
	Core.update_bullets(bullets, arena_size, delta, enemies)
	for w in enemies:
		if w.type == "well" and w.active:
			arena_canvas.pulse(w.pos, -35.0, 5.0 * u)

	for k in Core.resolve_bullet_hits(bullets, enemies, BULLET_RADIUS * u):
		_on_kill(k)

	var picked: int = Core.update_crystals(crystals, player_pos, delta)
	if picked > 0:
		multiplier += picked
		combo = multiplier  # kept for old saves
		_sfx("pickup")

	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.age += delta
		if p.age >= p.lifetime:
			particles.remove_at(i)
			continue
		p.pos += p.vel * delta
		p.vel *= maxf(0.0, 1.0 - 2.4 * delta)

	if invuln_timer <= 0.0 and Core.player_hit(player_pos, enemies, PLAYER_RADIUS * u):
		_on_player_hit()

	_update_hud()
	arena_canvas.queue_redraw()
	joystick_canvas.queue_redraw()

## Three shots in a tight triangle: the middle one leads, and is faster and
## longer-ranged than its two wingmen.
func _fire_burst(dir: Vector2) -> void:
	var u: float = Core.U
	var side := Vector2(-dir.y, dir.x)
	var muzzle: Vector2 = player_pos + dir * 0.6 * u
	bullets.append({"pos": muzzle + dir * 0.3 * u, "vel": dir * MID_BULLET_SPEED * u, "life": MID_BULLET_LIFE})
	for s in [-1.0, 1.0]:
		bullets.append({"pos": muzzle + side * s * 0.32 * u, "vel": dir.rotated(s * 0.04) * BULLET_SPEED * u, "life": BULLET_LIFE})
	burst_count += 1
	if burst_count % 4 == 0:
		_sfx("shoot")

## A shower of sparks in `color`.
func _spark_burst(pos: Vector2, color: Color, n: int, speed: float = 1.0) -> void:
	var u: float = Core.U
	for i in n:
		if particles.size() >= MAX_PARTICLES:
			return
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(3.0, 13.0) * u * speed
		particles.append({"pos": pos, "vel": v, "age": 0.0, "lifetime": randf_range(0.35, 0.8), "color": color, "len": randf_range(0.4, 1.0) * u})

func _on_event(ev: Dictionary) -> void:
	var u: float = Core.U
	match ev.kind:
		"gear_pop":
			_spark_burst(ev.pos, Core.color_of("gear"), 16)
			arena_canvas.pulse(ev.pos, 80.0, 4.0 * u)
		"well_burst":
			_spark_burst(ev.pos, Core.color_of("well"), 40, 1.3)
			arena_canvas.pulse(ev.pos, 280.0, 9.0 * u)
			_sfx("explode")
			for i in int(ev.n):
				var a := TAU * i / float(ev.n) + randf() * 0.4
				var pr := Core.make_enemy(next_entity_id, "proton", ev.pos + Vector2(cos(a), sin(a)) * 0.8 * u)
				pr.vel = Vector2(cos(a), sin(a)) * 9.0 * u
				next_entity_id += 1
				enemies.append(pr)

## Points (times the multiplier), sparks, a ripple through the grid, and
## geoms to collect. Spinners split in three, wells blow up their neighbours.
func _on_kill(k: Dictionary) -> void:
	var u: float = Core.U
	var type: String = k.type
	var eaten := int(k.get("eaten", 0))
	var pts := int(Core.POINTS.get(type, 10))
	if type == "well":
		pts += 100 * eaten
	score += pts * multiplier
	var big: bool = type == "well" or type == "ufo" or type == "snake"
	_spark_burst(k.pos, Core.color_of(type), 30 if big else 12)
	arena_canvas.pulse(k.pos, 260.0 if type == "well" else (120.0 if big else 70.0), (8.0 if big else 3.5) * u)
	_sfx("explode")

	var drops := int(Core.GEOMS.get(type, 1)) + eaten
	if type == "ufo":
		for i in 2:  # the huge ones: +10 multiplier each
			crystals.append({"pos": k.pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * u, "age": 0.0, "v": 10})
	else:
		for i in drops:
			if crystals.size() >= MAX_CRYSTALS:
				break
			var jitter := Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * u if drops > 1 else Vector2.ZERO
			crystals.append({"pos": k.pos + jitter, "age": 0.0, "v": 1})

	if type == "spinner":
		for i in 3:
			var a := TAU * i / 3.0 + randf() * 0.5
			var kid := Core.make_enemy(next_entity_id, "mini", k.pos + Vector2(cos(a), sin(a)) * 0.6 * u)
			kid.vel = Vector2(cos(a), sin(a)) * 8.0 * u
			enemies.append(kid)
			next_entity_id += 1
	elif type == "well":
		for kk in Core.blast(enemies, k.pos, 4.5 * u):
			_on_kill(kk)
	while score >= next_bomb_at:
		next_bomb_at += BOMB_EVERY_POINTS
		bombs = mini(bombs + 1, MAX_BOMBS)

## Smart bomb: a shockwave wipes out every enemy on screen. No points or
## geoms for those -- it's an escape, not a farm.
func _on_bomb_pressed() -> void:
	if not game_active or paused or game_over or bombs <= 0:
		return
	bombs -= 1
	for e in enemies:
		_spark_burst(e.pos, Core.color_of(e.type), 4)
	enemies.clear()
	shockwave_t = 0.0
	spawn_timer = maxf(spawn_timer, 1.0)
	arena_canvas.pulse(player_pos, 300.0, 12.0 * Core.U)
	_sfx("explode")
	_update_hud()

func _on_player_hit() -> void:
	lives -= 1
	_spark_burst(player_pos, Color(0.8, 0.95, 1.0), 45, 1.4)
	arena_canvas.pulse(player_pos, 300.0, 10.0 * Core.U)
	_sfx("lose" if lives <= 0 else "hit")
	enemies.clear()
	bullets.clear()
	crystals.clear()
	combo = 0
	combo_timer = 0.0
	multiplier = 1
	invuln_timer = INVULN_TIME
	beep_step = 99
	spawn_timer = 1.5
	player_pos = arena_size / 2.0
	if lives <= 0:
		_show_game_over()

func _update_hud() -> void:
	score_label.text = tr("Score: %d") % score
	lives_label.text = tr("Lives: %d") % lives
	combo_label.text = tr("x%d") % multiplier
	bomb_button.text = tr("💣 Bomb ×%d") % bombs
	bomb_button.disabled = bombs <= 0

# ---------- UI construction ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	_build_start_screen()
	_build_game_screen()

	joystick_canvas = JoystickCanvas.new()
	joystick_canvas.game = self
	add_child(joystick_canvas)

	_build_pause_dialog()
	_build_game_over_dialog()
	_build_rotate_hint()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/geometry_wars/geometry_wars_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

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

func _build_start_screen() -> void:
	start_screen = CenterContainer.new()
	start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(start_screen)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	start_screen.add_child(box)

	var title := Label.new()
	title.text = tr("Geometry Wars")
	title.add_theme_font_size_override("font_size", 43)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = tr("Dual-stick neon shooter")
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)

	continue_button = Button.new()
	continue_button.text = tr("Continue")
	continue_button.custom_minimum_size = Vector2(240, 56)
	continue_button.add_theme_font_size_override("font_size", 26)
	continue_button.visible = false
	continue_button.pressed.connect(_load_saved_game)
	box.add_child(continue_button)

	var start_btn := Button.new()
	start_btn.text = tr("Start")
	start_btn.custom_minimum_size = Vector2(240, 56)
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.pressed.connect(_start_new_game)
	box.add_child(start_btn)

	var back_btn := Button.new()
	back_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	back_btn.custom_minimum_size = Vector2(320, 64)
	back_btn.pressed.connect(_go_home)
	box.add_child(back_btn)

func _build_game_screen() -> void:
	game_screen = Control.new()
	game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_screen.visible = false
	add_child(game_screen)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 16)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	game_screen.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)

	pause_button = _neon_button("⏸ " + tr("Pause"), Color(0.3, 1.0, 1.0))
	pause_button.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_button)

	score_label = _stat_label(tr("Score: 0"))
	lives_label = _stat_label(tr("Lives: 3"))
	combo_label = _stat_label("")
	combo_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	for l in [score_label, lives_label, combo_label]:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_bar.add_child(l)

	bomb_button = _neon_button(tr("💣 Bomb ×%d") % START_BOMBS, Color(1.0, 0.55, 0.2))
	bomb_button.pressed.connect(_on_bomb_pressed)
	top_bar.add_child(bomb_button)
	var drawer_gap := Control.new()  # keeps Bomb clear of the ⚙ tab
	drawer_gap.custom_minimum_size = Vector2(36, 0)
	top_bar.add_child(drawer_gap)

	arena_canvas = ArenaCanvas.new()
	arena_canvas.game = self
	arena_canvas.position = arena_offset
	game_screen.add_child(arena_canvas)

## A dark button with a bright neon rim, readable over the arena.
func _neon_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(140, 52)
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
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	return l

func _build_pause_dialog() -> void:
	pause_dialog = ColorRect.new()
	pause_dialog.color = Color(0, 0, 0, 0.75)
	pause_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_dialog.visible = false
	add_child(pause_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dialog.add_child(center)

	var panel := PanelContainer.new()
	var sb := Ui.panel_style()
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("Paused")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.CYAN.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.CYAN, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = tr("Resume")
	resume_btn.custom_minimum_size = Vector2(220, 48)
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.custom_minimum_size = Vector2(220, 44)
	restart_btn.pressed.connect(func():
		pause_dialog.visible = false
		SaveUtil.delete(SAVE_PATH)
		_start_new_game()
	)
	box.add_child(restart_btn)

	var exit_btn := Button.new()
	exit_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	exit_btn.custom_minimum_size = Vector2(320, 64)
	exit_btn.pressed.connect(_go_home)
	box.add_child(exit_btn)

func _build_game_over_dialog() -> void:
	game_over_dialog = ColorRect.new()
	game_over_dialog.color = Color(0, 0, 0, 0.8)
	game_over_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_dialog.visible = false
	add_child(game_over_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_dialog.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("Game Over")
	title.add_theme_font_size_override("font_size", 33)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	game_over_stats = Label.new()
	game_over_stats.add_theme_font_size_override("font_size", 24)
	game_over_stats.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	game_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(game_over_stats)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		game_over_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(_go_home)
	box.add_child(menu_btn)

# ---------- screen state ----------

func _show_start_screen() -> void:
	game_active = false
	paused = false
	game_over = false
	start_screen.visible = true
	game_screen.visible = false
	pause_dialog.visible = false
	game_over_dialog.visible = false
	_refresh_continue_button()

# ---------- game flow ----------

func _compute_arena() -> void:
	var vp: Vector2 = get_viewport_rect().size
	arena_offset = Vector2(20, 90)
	arena_size = Vector2(vp.x - 40, vp.y - 90 - 30)
	arena_canvas.position = arena_offset
	# One grid square: the arena is 19 squares tall, as in the original.
	Core.U = arena_size.y / 19.0
	arena_canvas.reset_grid()

func _start_new_game() -> void:
	_compute_arena()
	player_pos = arena_size / 2.0
	ship_dir = Vector2.RIGHT
	lives = STARTING_LIVES
	score = 0
	combo = 0
	combo_timer = 0.0
	invuln_timer = INVULN_TIME
	beep_step = 99
	burst_count = 0
	fire_cooldown_timer = 0.0
	spawn_timer = 0.0
	elapsed_seconds = 0.0
	next_entity_id = 1
	enemies = []
	bullets = []
	particles = []
	crystals = []
	multiplier = 1
	bombs = START_BOMBS
	next_bomb_at = BOMB_EVERY_POINTS
	shockwave_t = -1.0
	move_touch_index = -1
	aim_touch_index = -1
	game_active = true
	paused = false
	game_over = false
	start_screen.visible = false
	game_screen.visible = true
	_update_hud()

func _on_pause_pressed() -> void:
	if not game_active or game_over:
		return
	paused = true
	_save_game()
	pause_dialog.visible = true

func _on_resume_pressed() -> void:
	_release_sticks()
	paused = false
	pause_dialog.visible = false

func _show_game_over() -> void:
	game_over = true
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	game_over_stats.text = tr("Score: %d   Time survived: %s") % [score, _format_time(elapsed_seconds)]
	if info:
		info.add("Games played")
		var record: bool = info.best("Best score", score)
		info.high("Longest time survived", elapsed_seconds)
		info.high("Highest multiplier", multiplier)
		game_over_stats.text += "\n" + (tr("New best!") if record else tr("Best: %d") % int(info.get_stat("Best score")))
	game_over_dialog.visible = true

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active:
		return
	var enemy_data := []
	for e in enemies:
		enemy_data.append({"type": e.type, "px": e.pos.x, "py": e.pos.y, "vx": e.vel.x, "vy": e.vel.y, "hp": e.get("hp", 1)})

	SaveUtil.write(SAVE_PATH, {
		"lives": lives,
		"score": score,
		"combo": combo,
		"multiplier": multiplier,
		"bombs": bombs,
		"next_bomb_at": next_bomb_at,
		"elapsed_seconds": elapsed_seconds,
		"player_x": player_pos.x,
		"player_y": player_pos.y,
		"enemies": enemy_data,
		"next_entity_id": next_entity_id,
	})

func _refresh_continue_button() -> void:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		continue_button.visible = false
		return
	continue_button.visible = true
	continue_button.text = tr("Continue (Score %d)") % int(data.get("score", 0))

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return false

	_compute_arena()
	lives = int(data.lives)
	score = int(data.score)
	combo = int(data.combo)
	combo_timer = 0.0
	multiplier = maxi(1, int(data.get("multiplier", 1)))
	bombs = int(data.get("bombs", START_BOMBS))
	next_bomb_at = int(data.get("next_bomb_at", (score / BOMB_EVERY_POINTS + 1) * BOMB_EVERY_POINTS))
	crystals = []
	shockwave_t = -1.0
	elapsed_seconds = float(data.elapsed_seconds)
	player_pos = Vector2(float(data.player_x), float(data.player_y))
	player_pos.x = clamp(player_pos.x, 0, arena_size.x)
	player_pos.y = clamp(player_pos.y, 0, arena_size.y)

	enemies = []
	next_entity_id = int(data.get("next_entity_id", 1))
	for ed in data.enemies:
		var e: Dictionary = Core.make_enemy(next_entity_id, str(ed.type), Vector2(float(ed.px), float(ed.py)))
		e.vel = Vector2(float(ed.vx), float(ed.vy))
		e.hp = int(ed.get("hp", e.hp))
		enemies.append(e)
		next_entity_id += 1

	bullets = []
	particles = []
	invuln_timer = INVULN_TIME
	beep_step = 99
	fire_cooldown_timer = 0.0
	spawn_timer = 0.5
	move_touch_index = -1
	aim_touch_index = -1
	ship_dir = Vector2.RIGHT

	game_active = true
	paused = false
	game_over = false
	start_screen.visible = false
	game_screen.visible = true
	_update_hud()
	return true

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/geometry_wars/geometry_wars_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/geometry_wars/geometry_wars_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Dual-stick neon shooter. Survive the swarm.",
		"logo": _draw_home_logo,
		"modes": [{"text": "🚀  Play", "sub": "Left thumb moves, right thumb aims", "action": _start_new_game}],
		"save_path": SAVE_PATH,
		"resume": _resume_saved,
		"resume_text": func(): return tr("Score: %d") % int((SaveUtil.read(SAVE_PATH) if SaveUtil.read(SAVE_PATH) else {}).get("score", 0)),
		"board_note": "Your best score.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	# the player's ship, a wanderer and a diamond chasing it
	var ship := PackedVector2Array([ctr + Vector2(h * 0.2, 0), ctr + Vector2(-h * 0.14, -h * 0.13), ctr + Vector2(-h * 0.05, 0), ctr + Vector2(-h * 0.14, h * 0.13)])
	HomeKit.glow_polyline(c, ship, Color.WHITE, 2.5, true)
	var d := ctr + Vector2(h * 0.62, -h * 0.18)
	HomeKit.glow_polyline(c, PackedVector2Array([d + Vector2(0, -h * 0.12), d + Vector2(h * 0.1, 0), d + Vector2(0, h * 0.12), d + Vector2(-h * 0.1, 0)]), HomeKit.CYAN, 2.5, true)
	var p := ctr + Vector2(-h * 0.6, h * 0.18)
	HomeKit.glow_rect(c, Rect2(p - Vector2(h * 0.09, h * 0.09), Vector2(h * 0.18, h * 0.18)), HomeKit.MAGENTA, 2.5)
	for k in 3:
		HomeKit.glow_line(c, ctr + Vector2(h * (0.28 + k * 0.1), 0), ctr + Vector2(h * (0.32 + k * 0.1), 0), HomeKit.GOLD, 2.0)

func _resume_saved() -> void:
	if not _load_saved_game():
		_start_new_game()
