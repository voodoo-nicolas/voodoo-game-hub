extends Control

## Sniper Hold -- a hunting rifle in one valley. Pinch to zoom the scope, wait for the breath to
## steady (or hold it), tap to shoot. One static scene; the aim sways with breath and heartbeat
## (sniper_hold_engine.gd), far shots drop and drift with the wind (Normal / Hard).
## Landing menu style: S7 Diegetic Cinema ("cinema", docs/MENU_STYLES.md): the valley itself is
## the menu's backdrop. The last two games (Arrow Pop, Block Escape) used S10 Bento Grid.
##
## Layers (children of `world`, which the camera scales and moves): sky + land are drawn once
## (static); clouds, water, actors (props + animals, depth-sorted), weather and foreground grass
## redraw each frame. Over them: the Skull-mode thermal filter, the scope, the HUD.

const E = preload("res://scripts/games/sniper_hold/sniper_hold_engine.gd")
const Scenery = preload("res://scripts/games/sniper_hold/sniper_hold_scenery.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/sniper_hold/menu_styles.gd")
const HomeKit = preload("res://scripts/games/sniper_hold/home_kit.gd")
const SoundLib = preload("res://scripts/games/sniper_hold/sound_lib.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const ACH_PATH := "res://scripts/common/achievements.gd"
const HELP := preload("res://scripts/games/sniper_hold/sniper_hold_help.gd")
const SAVE_PATH := "user://sniper_hold_save.json"
const PROGRESS_PATH := "user://sniper_hold_progress.json"   # contract stars
const LANDING_ART := "res://games/sniper_hold/landing.jpg"
const ZOOM_MIN := 1.0
const ZOOM_MAX := 12.0
const SCOPE_AT := 1.6           # zoom from which the view is through the scope
const TAP_MS := 300
const TAP_MOVE := 16.0
const ENV_ICONS := {"dawn": "🌅", "noon": "☀", "autumn": "🍂", "dusk": "🌇", "winter": "❄"}
const ENV_NAMES := {"dawn": "Dawn", "noon": "Midday", "autumn": "Autumn", "dusk": "Dusk", "winter": "Winter"}
const KIND_ICONS := {"buck": "🦌", "doe": "🦌", "fawn": "🦌", "boar": "🐗", "fox": "🦊", "hare": "🐇"}

const THERMAL_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float t = 0.0;
vec3 ramp(float l) {
	vec3 c0 = vec3(0.02, 0.01, 0.06);
	vec3 c1 = vec3(0.10, 0.04, 0.28);
	vec3 c2 = vec3(0.05, 0.42, 0.62);
	vec3 c3 = vec3(1.00, 0.17, 0.84);
	vec3 c4 = vec3(1.00, 0.68, 0.17);
	vec3 c5 = vec3(1.00, 1.00, 0.85);
	if (l < 0.18) return mix(c0, c1, l / 0.18);
	if (l < 0.42) return mix(c1, c2, (l - 0.18) / 0.24);
	if (l < 0.62) return mix(c2, c3, (l - 0.42) / 0.20);
	if (l < 0.82) return mix(c3, c4, (l - 0.62) / 0.20);
	return mix(c4, c5, (l - 0.82) / 0.18);
}
void fragment() {
	vec3 s = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(s, vec3(0.3, 0.55, 0.15));
	vec3 c = ramp(clamp(l, 0.0, 1.0));
	float scan = 0.92 + 0.08 * sin(SCREEN_UV.y * 900.0 + t * 6.0);
	COLOR = vec4(c * scan, 1.0);
}
"""

var info = null
var home
var engine
var scenery
var skin := "classic"
var started := false
var result_recorded := false
var progress: Dictionary = {"stars": {}}
var last_mode := "season"
var last_diff := 1

var view: Control
var world: Control
var sky_l: Control
var cloud_l: Control
var land_l: Control
var water_l: Control
var actor_l: Control
var weather_l: Control
var fg_l: Control
var fx_l: Control
var thermal: ColorRect
var scope: Control
var hud: Control
var pause_btn: Button
var end_card: PanelContainer
var end_title: Label
var end_text: Label
var end_buttons: HFlowContainer

var cam := Vector2(E.W * 0.5, E.H * 0.55)
var zoom := 1.0
var base := 1.0
var slowmo := 0.0
var recoil := 0.0
var flash := 0.0
var puffs: Array = []           # [world pos, age, colour, size]
var popups: Array = []          # [text, world pos, age, colour]
var tracer: Dictionary = {}     # {"to": world, "t": 0..1, "dur": s}
var marks: Dictionary = {}      # animal id -> "target" | "no" (Spotter help)
var spot_t := 0.0
var end_wait := 0.0             # contract: time after the last hit before checking the end
var bolt_snd := 0.0
var bird_t := 3.0
var banner := ""
var banner_t := 0.0
var hint_t := 6.0               # "pinch to zoom" hint at the start

var touches: Dictionary = {}    # index -> {"kind", "pos", "start", "ms", "moved"}
var pinch_d := 0.0
var mouse_down: Dictionary = {}
var key_hold := false

var snd_shot: AudioStreamWAV
var snd_beat: AudioStreamWAV
var snd_breath: AudioStreamWAV
var snd_chirp: AudioStreamWAV
var wind_player: AudioStreamPlayer

# ================================================================ setup

func _ready() -> void:
	preload("res://scripts/games/sniper_hold/sniper_hold_i18n.gd").install(self)
	Orientation.lock_landscape()
	engine = E.new()
	_load_progress()
	engine.reset("season", 1, 0, randi())
	_build_ui()
	_set_scene(engine.env, engine.seed_used)
	_make_sounds()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _layer(draw_fn: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(E.W, E.H)
	c.draw.connect(draw_fn)
	world.add_child(c)
	return c

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme(Color("e8a050"))
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	view = Control.new()
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	world = Control.new()
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.size = Vector2(E.W, E.H)
	view.add_child(world)
	sky_l = _layer(_draw_sky)
	cloud_l = _layer(_draw_clouds)
	land_l = _layer(_draw_land)
	water_l = _layer(_draw_water)
	actor_l = _layer(_draw_actors)
	weather_l = _layer(_draw_weather)
	fx_l = _layer(_draw_fx)
	fg_l = _layer(_draw_fg)
	thermal = ColorRect.new()
	thermal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thermal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = THERMAL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	thermal.material = mat
	thermal.visible = false
	add_child(thermal)
	scope = Control.new()
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope.draw.connect(_draw_scope)
	add_child(scope)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.draw.connect(_draw_hud)
	add_child(hud)
	pause_btn = Button.new()
	pause_btn.text = "❚❚"
	pause_btn.custom_minimum_size = Vector2(72, 60)
	pause_btn.size = Vector2(72, 60)
	pause_btn.add_theme_font_size_override("font_size", 28)
	pause_btn.pressed.connect(_on_pause)
	add_child(pause_btn)
	_build_end_card()
	resized.connect(_layout)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in 3:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "row": "season", "key": "season%d" % i,
			"sub": ["No bullet drop, no wind", "Bullet drop and light wind", "More sway, strong wind"][i],
			"action": _start_season.bind(i)})
	modes.append({"text": "🌿 Practice", "sub": "No clock, no score, as many rounds as you like", "key": "practice", "action": _start_practice})
	var has_art := ResourceLoader.exists(LANDING_ART)
	var cfg := {
		# Menu style (docs/MENU_STYLES.md): S7 Diegetic Cinema; bone white + dawn amber over the valley.
		"landing": "cinema",
		"landing_style": MenuStyles,
		"title_colors": [Color("f4ead2"), Color("f0a858")],
		"landing_colors": [Color("0b0f16"), Color("1d2a1c")],
		"menu_color": Color("f0a858"),
		"help": HELP,
		"info": info,
		"accent": Color("f0a858"),
		"solo_heading": "Open Season",
		"subtitle": "Pinch to zoom, wait for the breath to steady, tap to shoot.",
		"art": LANDING_ART if has_art else "",
		"landing_art": true,
		"landing_art_alpha": 0.95,
		"modes": modes,
		"play": [{"text": "🎯 Contracts", "sub": "24 hunts, up to 3 stars each", "action": _open_contracts, "card": true}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [
			{"text": "🔭 Spotter", "how": "Rings every animal for 20 seconds: gold = yours to take, red = leave it.", "action": _help_spotter},
			{"text": "➕ Extra rounds", "how": "Two more rounds in the rifle (Open Season and Contracts).", "action": _help_rounds},
		],
		"board": "Best score",
		"board_note": "Open Season: points for each animal taken (clean shot x2, head shot x1.5, plus half a point per metre), x1.5 on Normal, x2 on Hard.",
	}
	if not has_art:
		cfg["logo"] = _draw_home_logo
	home = HomeKit.new(cfg)
	add_child(home)
	if info:
		add_child(info)
	_layout()

func _layout() -> void:
	var s := _safe()
	pause_btn.position = Vector2(s.x, s.y)
	if end_card:
		end_card.offset_left = s.x + 8.0
		end_card.offset_right = -s.z - 8.0
		end_card.offset_bottom = -s.w - 8.0

func _safe() -> Vector4:
	var s := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or s.size.x <= 0:
		return Vector4(12, 12, 12, 12)
	var kx := size.x / float(win.x)
	var ky := size.y / float(win.y)
	return Vector4(maxf(12.0, s.position.x * kx), maxf(12.0, s.position.y * ky),
		maxf(12.0, (win.x - s.end.x) * kx), maxf(12.0, (win.y - s.end.y) * ky))

## A new valley: builds the scenery for `env` and redraws the static layers once.
func _set_scene(env: String, sd: int) -> void:
	scenery = Scenery.new(env, sd)
	scenery.voodoo = skin == "voodoo"
	engine.cover = scenery.cover()
	sky_l.queue_redraw()
	land_l.queue_redraw()
	_apply_skin_layers()

func _apply_skin_layers() -> void:
	var v := skin == "voodoo"
	thermal.visible = v
	var dim := Color(0.55, 0.55, 0.6) if v else Color.WHITE
	for l in [sky_l, cloud_l, land_l, water_l, weather_l, fg_l]:
		l.modulate = dim

# ================================================================ starting play

func _start_season(d: int) -> void:
	_begin("season", d, 0)

func _start_practice() -> void:
	_begin("practice", last_diff, 0)

func _start_contract(n: int) -> void:
	_begin("contract", 1, n)

func _restart() -> void:
	_begin(last_mode, last_diff, engine.level)

func _begin(m: String, d: int, lv: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	last_mode = m
	last_diff = d
	engine.reset(m, d, lv, randi())
	_after_reset()
	if m == "contract":
		_show_banner(_contract_line(lv))
	else:
		_show_banner(tr(ENV_NAMES[engine.env]) + " · " + tr(E.DIFFS[engine.diff]))

func _after_reset() -> void:
	_set_scene(engine.env, engine.seed_used)
	started = true
	result_recorded = false
	cam = Vector2(E.W * 0.5, E.H * 0.55)
	zoom = 1.0
	puffs.clear()
	popups.clear()
	tracer = {}
	marks.clear()
	spot_t = 0.0
	end_wait = 0.0
	slowmo = 0.0
	recoil = 0.0
	hint_t = 6.0
	touches.clear()
	mouse_down.clear()
	end_card.visible = false
	_wind_sound(true)
	_music("play", "calm", ["dawn", "noon", "autumn", "dusk", "winter"].find(engine.env))
	if info and info.has_method("reset_result"):
		info.reset_result()

func _contract_line(n: int) -> String:
	var c: Dictionary = E.CONTRACTS[n]
	var parts: Array = []
	for k in c.take:
		parts.append("%d %s" % [int(c.take[k]), tr(E.KIND_NAMES[k])])
	return tr("Contract %d") % (n + 1) + ": " + ", ".join(parts)

# ================================================================ loop

func _process(delta: float) -> void:
	base = maxf(size.x / E.W, size.y / E.H)
	var dt := delta * (0.3 if slowmo > 0.0 else 1.0)
	slowmo = maxf(0.0, slowmo - delta)
	var t: float = engine.t
	if started and not engine.over:
		for ev in engine.step(dt):
			_on_event(ev)
		if engine.mode == "contract" and engine.bullets.is_empty():
			end_wait -= delta
			if end_wait <= 0.0:
				for ev in engine.check_end():
					_on_event(ev)
	elif not started:
		# Under the Landing: the valley idles (animals wander, wind blows).
		engine.t += delta
		engine._step_animals(delta)
	scenery.tick(dt)
	recoil = move_toward(recoil, 0.0, delta * 2.6)
	flash = maxf(0.0, flash - delta * 5.0)
	spot_t = maxf(0.0, spot_t - delta)
	if spot_t <= 0.0:
		marks.clear()
	hint_t = maxf(0.0, hint_t - delta)
	banner_t = maxf(0.0, banner_t - delta)
	if bolt_snd > 0.0:
		bolt_snd -= delta
		if bolt_snd <= 0.0:
			SoundLib.play(self, "rpg/metal_latch", -6.0)
	for p in puffs.duplicate():
		p[1] += delta
		if p[1] > 1.6:
			puffs.erase(p)
	for p in popups.duplicate():
		p[2] += delta
		if p[2] > 2.4:
			popups.erase(p)
	if not tracer.is_empty():
		tracer.t += delta / maxf(0.05, tracer.dur)
		if tracer.t >= 1.0:
			tracer = {}
	_ambient(delta)
	_place_camera()
	for l in [cloud_l, water_l, actor_l, weather_l, fx_l, fg_l, scope, hud]:
		l.queue_redraw()
	if thermal.visible:
		(thermal.material as ShaderMaterial).set_shader_parameter("t", t)

func _aim() -> Vector2:
	return cam + engine.sway()

func _place_camera() -> void:
	var k := base * zoom
	var half := size / (2.0 * k)
	cam.x = clampf(cam.x, half.x, maxf(half.x, E.W - half.x))
	cam.y = clampf(cam.y, half.y, maxf(half.y, E.H - half.y))
	var aim := _aim() if started else cam
	world.scale = Vector2(k, k)
	world.position = size * 0.5 - aim * k + Vector2(0, recoil * size.y * 0.18)

func world_to_screen(p: Vector2) -> Vector2:
	return world.position + p * world.scale.x

func screen_to_world(p: Vector2) -> Vector2:
	return (p - world.position) / world.scale.x

func _view_rect() -> Rect2:
	var a := screen_to_world(Vector2.ZERO)
	var b := screen_to_world(size)
	return Rect2(a, b - a)

func _set_zoom(z: float, focus: Vector2) -> void:
	var before := screen_to_world(focus)
	zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	var k := base * zoom
	cam = before - (focus - size * 0.5) / k
	if started:
		cam -= engine.sway()

func _on_event(ev: Dictionary) -> void:
	match ev.type:
		"hit":
			var p := Vector2(ev.pos[0], ev.pos[1])
			var s := E.scale_at(ev.d)
			puffs.append([p, 0.0, Color(0.85, 0.8, 0.7), s * 0.35])
			var txt := tr(ev.label)
			if ev.pts != 0:
				txt = ("%+d  " % ev.pts) + txt
			txt += "  ·  %d m" % int(round(ev.d))
			popups.append([txt, p - Vector2(0, s * 1.6), 0.0, Color("ffe08a") if ev.ok else Color("ff6a5a")])
			SoundLib.play(self, "impact/soft_heavy", -4.0)
			_vibrate(40)
			if ev.ok:
				if ev.d >= 300.0:
					slowmo = 0.45
				if info:
					info.add("Animals taken")
					if ev.zone == "vital":
						info.add("Clean shots")
					info.high("Longest shot (m)", int(round(ev.d)))
				_report("first_take")
				if ev.zone == "vital" and ev.d >= 400.0:
					_report("long_clean")
			else:
				SoundLib.play(self, "ui/wrong", -4.0)
			end_wait = 1.3
		"miss":
			var p2 := Vector2(ev.pos[0], ev.pos[1])
			var s2 := E.scale_at(ev.d)
			var col := Color(0.55, 0.45, 0.32) if not ev.get("blocked", false) else Color(0.4, 0.55, 0.3)
			if engine.env == "winter":
				col = Color(0.95, 0.97, 1.0)
			puffs.append([p2, 0.0, col, s2 * 0.5])
			if ev.get("blocked", false):
				popups.append([tr("Blocked"), p2 - Vector2(0, s2 * 1.2), 0.0, Color(0.85, 0.9, 1.0)])
		"over":
			_on_over(ev.reason)

# ================================================================ input

func _touch_mode() -> bool:
	return DisplayServer.is_touchscreen_available()

func _hold_center() -> Vector2:
	var s := _safe()
	return Vector2(s.x + 78.0, size.y - s.w - 78.0)

func _fire_center() -> Vector2:
	var s := _safe()
	return Vector2(size.x - s.z - 84.0, size.y - s.w - 84.0)

func _zoom_rect() -> Rect2:
	var s := _safe()
	var top := s.y + 120.0
	var bottom := _fire_center().y - 96.0
	return Rect2(size.x - s.z - 136.0, top, 60.0, maxf(60.0, bottom - top))

func _classify(p: Vector2) -> String:
	if pause_btn.get_global_rect().grow(6.0).has_point(p) or end_card.visible:
		return "ui"
	if p.distance_to(_hold_center()) < 70.0:
		return "hold"
	if p.distance_to(_fire_center()) < 74.0:
		return "fire"
	if _zoom_rect().grow(10.0).has_point(p):
		return "zoom"
	return "view"

func _input(event: InputEvent) -> void:
	if not started or engine.over:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_input(event)
	elif not _touch_mode() and (event is InputEventMouseButton or event is InputEventMouseMotion):
		_mouse_input(event)

func _touch_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			var kind := _classify(st.position)
			if kind == "ui":
				return
			touches[st.index] = {"kind": kind, "pos": st.position, "start": st.position, "ms": Time.get_ticks_msec(), "moved": false}
			_press(kind, st.position)
			if _view_count() == 2:
				pinch_d = _pinch_dist()
				for k in touches:
					touches[k].moved = true   # a pinch never fires
			get_viewport().set_input_as_handled()
		elif touches.has(st.index):
			var tc: Dictionary = touches[st.index]
			touches.erase(st.index)
			_release(tc, st.position)
			get_viewport().set_input_as_handled()
	else:
		var sd := event as InputEventScreenDrag
		if not touches.has(sd.index):
			return
		var tc2: Dictionary = touches[sd.index]
		tc2.pos = sd.position
		if tc2.start.distance_to(sd.position) > TAP_MOVE:
			tc2.moved = true
		match tc2.kind:
			"zoom":
				_zoom_from_slider(sd.position.y)
			"view":
				if _view_count() >= 2:
					var nd := _pinch_dist()
					if pinch_d > 1.0 and nd > 1.0:
						_set_zoom(zoom * nd / pinch_d, _pinch_mid())
					pinch_d = nd
				else:
					_pan(sd.relative)
		get_viewport().set_input_as_handled()

func _view_count() -> int:
	var n := 0
	for k in touches:
		if touches[k].kind == "view":
			n += 1
	return n

func _view_points() -> Array:
	var pts: Array = []
	for k in touches:
		if touches[k].kind == "view":
			pts.append(touches[k].pos)
	return pts

func _pinch_dist() -> float:
	var p := _view_points()
	return (p[0] as Vector2).distance_to(p[1]) if p.size() >= 2 else 0.0

func _pinch_mid() -> Vector2:
	var p := _view_points()
	return ((p[0] as Vector2) + (p[1] as Vector2)) * 0.5 if p.size() >= 2 else size * 0.5

func _press(kind: String, p: Vector2) -> void:
	match kind:
		"hold":
			_hold(true)
		"fire":
			_fire()
		"zoom":
			_zoom_from_slider(p.y)

func _release(tc: Dictionary, _p: Vector2) -> void:
	match tc.kind:
		"hold":
			_hold(false)
		"view":
			if not tc.moved and Time.get_ticks_msec() - int(tc.ms) < TAP_MS and _view_count() == 0:
				_fire()

func _mouse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_zoom(zoom * 1.15, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_zoom(zoom / 1.15, mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_hold(mb.pressed)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var kind := _classify(mb.position)
				if kind == "ui":
					return
				mouse_down = {"kind": kind, "pos": mb.position, "start": mb.position, "ms": Time.get_ticks_msec(), "moved": false}
				_press(kind, mb.position)
			elif not mouse_down.is_empty():
				var tc := mouse_down
				mouse_down = {}
				_release(tc, mb.position)
			else:
				return
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not mouse_down.is_empty():
		var mm := event as InputEventMouseMotion
		if mouse_down.start.distance_to(mm.position) > TAP_MOVE:
			mouse_down.moved = true
		if mouse_down.kind == "view":
			_pan(mm.relative)
		elif mouse_down.kind == "zoom":
			_zoom_from_slider(mm.position.y)

func _unhandled_key_input(event: InputEvent) -> void:
	if not started or engine.over or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.echo:
		return
	match k.keycode:
		KEY_SPACE, KEY_SHIFT:
			_hold(k.pressed)
		KEY_ENTER, KEY_F:
			if k.pressed:
				_fire()
		KEY_EQUAL, KEY_KP_ADD, KEY_PAGEUP:
			if k.pressed:
				_set_zoom(zoom * 1.3, size * 0.5)
		KEY_MINUS, KEY_KP_SUBTRACT, KEY_PAGEDOWN:
			if k.pressed:
				_set_zoom(zoom / 1.3, size * 0.5)
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if k.pressed:
				var dir: Vector2 = {KEY_LEFT: Vector2(1, 0), KEY_RIGHT: Vector2(-1, 0), KEY_UP: Vector2(0, 1), KEY_DOWN: Vector2(0, -1)}[k.keycode]
				_pan(dir * 40.0)

## Dragging moves the valley with the finger (finer the more you zoom).
func _pan(rel: Vector2) -> void:
	cam -= rel / (base * zoom)
	hint_t = minf(hint_t, 2.0)

func _zoom_from_slider(y: float) -> void:
	var r := _zoom_rect()
	var f := clampf(1.0 - (y - r.position.y) / r.size.y, 0.0, 1.0)
	_set_zoom(exp(lerpf(log(ZOOM_MIN), log(ZOOM_MAX), f)), size * 0.5)

func _hold(on: bool) -> void:
	var was: bool = engine.holding
	engine.set_hold(on)
	if engine.holding and not was:
		_play(snd_breath, -16.0, 0.8)
	elif was and not engine.holding:
		_play(snd_breath, -12.0, 1.1)

func _fire() -> void:
	if not engine.can_fire():
		if engine.rounds <= 0 and not engine.over:
			_show_banner(tr("Out of rounds"))
		return
	var aim := _aim()
	engine.fire(aim)
	if info:
		info.add("Shots fired")
	_play(snd_shot, -2.0, randf_range(0.95, 1.05))
	_vibrate(60)
	recoil = 1.0
	flash = 1.0
	bolt_snd = 0.45
	var d := E.dist_at_y(aim.y)
	tracer = {"to": aim, "t": 0.0, "dur": E.flight(minf(d, 900.0)) if d < INF else 0.6}
	scenery.flush_birds(Vector2(randf_range(100.0, E.W - 100.0), 440.0))
	hint_t = 0.0

# ================================================================ drawing (world layers)

func _draw_sky() -> void:
	if scenery:
		scenery.draw_sky(sky_l)

func _draw_land() -> void:
	if scenery:
		scenery.draw_land(land_l)

func _draw_clouds() -> void:
	scenery.draw_clouds(cloud_l, engine.t, engine.wind)

func _draw_water() -> void:
	scenery.draw_water(water_l, engine.t)

func _draw_actors() -> void:
	scenery.draw_actors(actor_l, engine, _view_rect(), engine.t, engine.wind, marks)

func _draw_weather() -> void:
	scenery.draw_weather(weather_l, engine.t, get_process_delta_time(), engine.wind, _view_rect())

func _draw_fg() -> void:
	scenery.draw_foreground(fg_l, engine.t, engine.wind)

func _draw_fx() -> void:
	for p in puffs:
		var a: float = p[1] / 1.6
		var r: float = p[3] * (0.6 + a * 1.8)
		for i in 5:
			var o := Vector2(cos(i * 1.3) * r * 0.5, -sin(i * 0.9 + 0.3) * r * 0.4 - a * r * 0.6)
			fx_l.draw_texture_rect(scenery.blob, Rect2(p[0] + o - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(p[2], 0.55 * (1.0 - a)))

# ================================================================ scope and HUD (screen space)

func _scope_r() -> float:
	return minf(size.x, size.y) * 0.47

func _in_scope() -> bool:
	return zoom >= SCOPE_AT

func _draw_scope() -> void:
	if not started:
		return
	var c := size * 0.5
	var v := skin == "voodoo"
	var line := Color(0.02, 0.02, 0.02, 0.92) if not v else Color("ff2bd6")
	if engine.env == "dusk" and not v:
		line = Color(0.02, 0.02, 0.02, 0.95)
	if not _in_scope():
		# Spotting view: soft dark corners (like looking out of a hide), a small open reticle.
		var vr := size.length() * 0.5
		for i in 8:
			scope.draw_arc(c, vr * (0.78 + i * 0.05), 0, TAU, 64, Color(0, 0, 0, 0.05 + i * 0.012), vr * 0.06, true)
		var gap := 10.0
		var L := 26.0
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			scope.draw_line(c + d * gap, c + d * (gap + L), Color(1, 1, 1, 0.85), 2.0)
			scope.draw_line(c + d * gap, c + d * (gap + L), Color(0, 0, 0, 0.5), 4.0)
		scope.draw_circle(c, 2.5, Color(1, 0.2, 0.15))
		return
	var R := _scope_r()
	var far := size.length()
	# Everything outside the lens is the scope tube: black, with a soft inner shadow.
	scope.draw_arc(c, R + far * 0.5, 0, TAU, 96, Color.BLACK, far, true)
	for i in 6:
		scope.draw_arc(c, R - 2.0 - i * 5.0, 0, TAU, 96, Color(0, 0, 0, 0.32 - i * 0.05), 6.0, true)
	scope.draw_arc(c, R - 4.0, 0, TAU, 128, Color(0.3, 0.6, 1.0, 0.10), 8.0, true)
	scope.draw_arc(c, R - 1.5, 0, TAU, 128, Color(1.0, 0.4, 0.2, 0.10), 3.0, true)
	scope.draw_arc(c, R + 1.0, 0, TAU, 128, Color(0.25, 0.25, 0.28) if not v else Color("29e6ff"), 3.0, true)
	# Mil-dot reticle: 1 dot = 1 mil (1 m at 1000 m) at every distance.
	var mil: float = E.MIL * base * zoom
	var w := 1.4
	scope.draw_line(c + Vector2(-R, 0), c + Vector2(-mil * 0.6, 0), line, w)
	scope.draw_line(c + Vector2(mil * 0.6, 0), c + Vector2(R, 0), line, w)
	scope.draw_line(c + Vector2(0, -R), c + Vector2(0, -mil * 0.6), line, w)
	scope.draw_line(c + Vector2(0, mil * 0.6), c + Vector2(0, R), line, w)
	# Thick posts beyond 5 mils.
	var post := minf(R, mil * 5.5)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]:
		scope.draw_line(c + d * post, c + d * R, line, 6.0)
	if mil > 6.0:
		for i in range(1, 6):
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				var q: Vector2 = c + (d as Vector2) * mil * i
				if q.distance_to(c) < R:
					scope.draw_circle(q, clampf(mil * 0.09, 1.5, 3.5), line)
	if v:
		_draw_skull(c, maxf(5.0, mil * 0.25), Color("ff2bd6"))
	else:
		scope.draw_circle(c, 1.8, Color(1, 0.15, 0.1, 0.9))
	# Lens glint.
	scope.draw_arc(c, R * 0.9, -2.5, -2.0, 24, Color(1, 1, 1, 0.06), R * 0.08)
	# Range and holdover under the crosshair.
	var aim := _aim()
	var d := _range_at(aim)
	var font := get_theme_default_font()
	# The readout sits outside the lens (left of it) so it never hides the target.
	var rx := c.x - R - 24.0
	var y := c.y + 8.0
	var rt := "— m" if d >= INF else "%d m" % int(round(d))
	_shadow_text(scope, font, Vector2(rx - 260.0, y), rt, 260.0, 26, Color(1, 1, 1, 0.9) if not v else Color("29e6ff"), HORIZONTAL_ALIGNMENT_RIGHT)
	if engine.diff == 1 and d < INF:
		var hm: Vector2 = engine.hold_mils(d)
		var hs := ""
		if absf(hm.y) >= 0.1:
			hs += ("▲ %.1f" if hm.y > 0.0 else "▼ %.1f") % absf(hm.y)
		if absf(hm.x) >= 0.1:
			hs += ("   ▶ %.1f" if hm.x > 0.0 else "   ◀ %.1f") % absf(hm.x)
		if hs != "":
			_shadow_text(scope, font, Vector2(rx - 260.0, y + 30.0), tr("Hold over"), 260.0, 16, Color(1, 0.9, 0.6, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
			_shadow_text(scope, font, Vector2(rx - 260.0, y + 54.0), hs + tr(" mil"), 260.0, 18, Color(1, 0.9, 0.6, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_skull(c: Vector2, r: float, col: Color) -> void:
	scope.draw_arc(c + Vector2(0, -r * 0.15), r, PI * 0.95, PI * 2.05, 20, col, 1.6, true)
	scope.draw_line(c + Vector2(-r * 0.75, r * 0.45), c + Vector2(r * 0.75, r * 0.45), col, 1.6)
	scope.draw_circle(c + Vector2(-r * 0.38, -r * 0.1), r * 0.2, col)
	scope.draw_circle(c + Vector2(r * 0.38, -r * 0.1), r * 0.2, col)
	for i in 3:
		var x := (float(i) - 1.0) * r * 0.35
		scope.draw_line(c + Vector2(x, r * 0.45), c + Vector2(x, r * 0.8), col, 1.4)

## What the rangefinder reads at a world point: the animal there, else the ground.
func _range_at(p: Vector2) -> float:
	var best := INF
	for a in engine.animals:
		if a.state != "down" and engine.zone_at(a, p) != "":
			best = minf(best, float(a.d))
	if best < INF:
		return best
	return E.dist_at_y(p.y)

func _shadow_text(c: CanvasItem, font: Font, pos: Vector2, text: String, width: float, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	c.draw_string(font, pos + Vector2(1.5, 1.5), text, align, width, fs, Color(0, 0, 0, 0.75))
	c.draw_string(font, pos, text, align, width, fs, col)

func _draw_hud() -> void:
	var font := get_theme_default_font()
	var s := _safe()
	var hot := Color("f0a858")
	if flash > 0.0:
		hud.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.95, 0.85, 0.18 * flash))
	# Popups and the tracer (world positions).
	for p in popups:
		var a: float = p[2] / 2.4
		var sp := world_to_screen(p[1]) - Vector2(0, a * 40.0)
		_shadow_text(hud, font, sp - Vector2(220, 0), p[0], 440.0, 24, Color(p[3], 1.0 - a * a))
	if not tracer.is_empty():
		var to := world_to_screen(tracer.to)
		var from := Vector2(size.x * 0.56, size.y + 20.0)
		var f: float = tracer.t
		var p0 := from.lerp(to, maxf(0.0, f - 0.12))
		var p1 := from.lerp(to, f)
		hud.draw_line(p0, p1, Color(1, 1, 0.9, 0.35 * (1.0 - f)), 2.0)
	if banner_t > 0.0:
		var ba := clampf(banner_t, 0.0, 1.0)
		_shadow_text(hud, font, Vector2(0, size.y * 0.3), banner, size.x, 30, Color(1, 0.95, 0.8, ba))
	if not started:
		return
	# Top line: what to take (contracts) or the score, the clock and the rounds.
	var top := s.y + 34.0
	var line := ""
	match engine.mode:
		"contract":
			var parts: Array = []
			for k in engine.targets():
				parts.append("%s %s %d/%d" % [KIND_ICONS[k], tr(E.KIND_NAMES[k]), int(engine.taken.get(k, 0)), int(engine.targets()[k])])
			line = "   ".join(parts)
		"season":
			line = tr("Score") + " %d" % engine.score
		_:
			line = tr("Practice")
	_shadow_text(hud, font, Vector2(0, top), line, size.x, 24, Color(1, 1, 1, 0.95))
	var sub := ""
	if engine.mode == "contract":
		var fb: Array = []
		for k in engine.forbidden():
			fb.append(tr(E.KIND_NAMES[k]))
		if not fb.is_empty():
			sub = "🚫 " + tr("Don't shoot") + ": " + ", ".join(fb)
	elif engine.mode == "season":
		sub = "🚫 " + tr("Don't shoot") + ": " + tr("Fawn")
	if sub != "":
		_shadow_text(hud, font, Vector2(0, top + 26.0), sub, size.x, 17, Color(1, 0.75, 0.7, 0.9))
	if engine.mode != "practice":
		var tl := int(ceil(engine.time_left))
		_shadow_text(hud, font, Vector2(s.x + 84.0, top), "⏱ %d:%02d" % [tl / 60, tl % 60], 200.0, 22,
			Color(1, 0.5, 0.4) if tl <= 20 else Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	# Wind (top right) and rounds.
	var wx := size.x - s.z - 14.0
	var wind: float = engine.wind
	var wt := "—" if engine.wind_max <= 0.0 else ("%s %.1f m/s" % ["→" if wind >= 0.0 else "←", absf(wind)])
	_shadow_text(hud, font, Vector2(wx - 220.0, top), "🍃 " + wt, 220.0, 20, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
	if engine.mode != "practice":
		var n := mini(engine.rounds, 12)
		for i in n:
			var bx := wx - 10.0 - i * 13.0
			hud.draw_rect(Rect2(bx - 3.0, top + 12.0, 6.0, 18.0), Color("d9b45a"))
			hud.draw_rect(Rect2(bx - 3.0, top + 12.0, 6.0, 6.0), Color("b0703a"))
		if engine.rounds > 12:
			_shadow_text(hud, font, Vector2(wx - 260.0, top + 30.0), "+%d" % (engine.rounds - 12), 100.0, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	# Hold-breath button with the lungs gauge.
	var hc := _hold_center()
	var holding: bool = engine.holding
	hud.draw_circle(hc, 58.0, Color(0, 0, 0, 0.45))
	hud.draw_arc(hc, 58.0, 0, TAU, 48, Color(1, 1, 1, 0.25), 2.0, true)
	var lungs: float = engine.lungs
	var lc := Color("7fe0ff") if engine.gasp <= 0.0 else Color("ff6a5a")
	hud.draw_arc(hc, 64.0, -PI * 0.5, -PI * 0.5 + TAU * lungs, 48, lc, 6.0, true)
	_shadow_text(hud, font, hc + Vector2(-60, -4), "🫁", 120.0, 34, Color.WHITE)
	_shadow_text(hud, font, hc + Vector2(-80, 28), tr("Holding") if holding else tr("Hold breath"), 160.0, 15, Color(1, 1, 1, 0.85))
	# Steadiness: calm in the natural pause or while holding.
	var lvl: float = engine.sway_level()
	var st := tr("Steady") if lvl <= 0.4 else (tr("Out of breath") if engine.gasp > 0.0 else tr("Breathing"))
	var stc := Color("7dff8a") if lvl <= 0.4 else (Color("ff6a5a") if engine.gasp > 0.0 else Color(1, 1, 1, 0.7))
	_shadow_text(hud, font, hc + Vector2(-120, -84), st, 240.0, 20, stc)
	# Breath wave: a dot riding one breath cycle.
	var wv := PackedVector2Array()
	var wo := hc + Vector2(-56, -112)
	for i in 29:
		var f := float(i) / 28.0
		var yy := 0.0
		if f < 0.4:
			yy = sin(f / 0.4 * PI * 0.5)
		elif f < 0.8:
			yy = cos((f - 0.4) / 0.4 * PI * 0.5)
		wv.append(wo + Vector2(f * 112.0, -yy * 14.0))
	hud.draw_polyline(wv, Color(1, 1, 1, 0.3), 2.0, true)
	hud.draw_rect(Rect2(wo + Vector2(0.8 * 112.0, -16.0), Vector2(0.2 * 112.0, 18.0)), Color(0.5, 1, 0.55, 0.15))
	var bp: float = engine.breath_phase()
	if not holding and engine.gasp <= 0.0:
		var by := 0.0
		if bp < 0.4:
			by = sin(bp / 0.4 * PI * 0.5)
		elif bp < 0.8:
			by = cos((bp - 0.4) / 0.4 * PI * 0.5)
		hud.draw_circle(wo + Vector2(bp * 112.0, -by * 14.0), 4.0, stc)
	# Fire button with the bolt.
	var fc := _fire_center()
	var ready: bool = engine.can_fire()
	hud.draw_circle(fc, 62.0, Color(0.5, 0.08, 0.05, 0.55) if ready else Color(0, 0, 0, 0.45))
	hud.draw_arc(fc, 62.0, 0, TAU, 48, Color(1, 0.6, 0.5, 0.7) if ready else Color(1, 1, 1, 0.2), 2.5, true)
	if engine.bolt > 0.0:
		hud.draw_arc(fc, 68.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - engine.bolt / E.BOLT_TIME), 48, hot, 5.0, true)
	_shadow_text(hud, font, fc + Vector2(-60, 10), tr("FIRE"), 120.0, 24, Color(1, 1, 1, 0.95 if ready else 0.4))
	# Zoom slider.
	var zr := _zoom_rect()
	var zx := zr.position.x + zr.size.x * 0.5
	hud.draw_line(Vector2(zx, zr.position.y), Vector2(zx, zr.end.y), Color(1, 1, 1, 0.35), 4.0)
	var zf := (log(zoom) - log(ZOOM_MIN)) / (log(ZOOM_MAX) - log(ZOOM_MIN))
	var ky := zr.end.y - zf * zr.size.y
	hud.draw_circle(Vector2(zx, ky), 14.0, Color(1, 1, 1, 0.85))
	_shadow_text(hud, font, Vector2(zx - 60.0, zr.position.y - 12.0), "×%.1f" % zoom, 120.0, 18, Color.WHITE)
	_shadow_text(hud, font, Vector2(zx - 60.0, zr.position.y + 6.0 - 40.0), "🔭", 120.0, 20, Color.WHITE)
	if hint_t > 0.0 and zoom < SCOPE_AT:
		_shadow_text(hud, font, Vector2(0, size.y * 0.66), tr("Pinch (or drag the slider) to zoom. Drag to aim. Tap to shoot."), size.x, 20,
			Color(1, 1, 1, clampf(hint_t, 0.0, 1.0)))

func _show_banner(t: String) -> void:
	banner = t
	banner_t = 3.0

# ================================================================ end of a hunt

func _build_end_card() -> void:
	end_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.06, 0.92)
	sb.border_color = Color("f0a858")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	end_card.add_theme_stylebox_override("panel", sb)
	end_card.anchor_left = 0.0
	end_card.anchor_right = 1.0
	end_card.anchor_top = 1.0
	end_card.anchor_bottom = 1.0
	end_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	end_card.offset_top = 0.0
	end_card.offset_left = 12.0
	end_card.offset_right = -12.0
	end_card.offset_bottom = -12.0
	end_card.visible = false
	add_child(end_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	end_card.add_child(box)
	end_title = Label.new()
	end_title.add_theme_font_size_override("font_size", 30)
	end_title.add_theme_color_override("font_color", Color("f0a858"))
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_title)
	end_text = Label.new()
	end_text.add_theme_font_size_override("font_size", 19)
	end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_text)
	end_buttons = HFlowContainer.new()
	end_buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	end_buttons.add_theme_constant_override("h_separation", 10)
	end_buttons.add_theme_constant_override("v_separation", 8)
	box.add_child(end_buttons)

func _end_button(text: String, col: Color, action: Callable) -> void:
	var b := HomeKit.neon_button(text, col, 22, 58)
	b.custom_minimum_size.x = 170.0
	b.pressed.connect(action)
	end_buttons.add_child(b)

func _on_over(reason: String) -> void:
	engine.set_hold(false)
	touches.clear()
	mouse_down.clear()
	SaveUtil.delete(SAVE_PATH)
	_wind_sound(false)
	for ch in end_buttons.get_children():
		ch.queue_free()
	var acc := 0 if engine.shots == 0 else int(round(100.0 * engine.hits / float(engine.shots)))
	var lines: Array = []
	var won: bool = engine.won
	match engine.mode:
		"contract":
			var st: int = engine.stars()
			if won:
				end_title.text = tr("Contract complete!") + "  " + "★".repeat(st) + "☆".repeat(3 - st)
			elif reason == "forbidden":
				end_title.text = tr("Contract failed: wrong animal")
			else:
				end_title.text = tr("Contract failed")
			if won:
				var key := str(engine.level)
				var old := int(progress.stars.get(key, 0))
				if st > old:
					progress.stars[key] = st
					_save_progress()
				lines.append(tr("No missed shots: +1 ★") if engine.misses == 0 else tr("Every shot on target earns a star."))
				lines.append(tr("All clean shots: +1 ★") if engine.clean == engine.hits else tr("Clean shots (heart and lungs) on every animal earn a star."))
		"season":
			end_title.text = tr("Season over") + "  ·  " + tr("Score") + " %d" % engine.score
			lines.append(tr(ENV_NAMES[engine.env]) + " · " + tr(E.DIFFS[engine.diff]))
		_:
			end_title.text = tr("Practice")
	var taken := 0
	for k in engine.taken:
		taken += int(engine.taken[k])
	lines.append(tr("Animals taken: %d") % taken)
	lines.append(tr("Clean shots: %d") % engine.clean)
	lines.append(tr("Accuracy: %d%%") % acc)
	if engine.longest > 0.0:
		lines.append(tr("Longest shot: %d m") % int(round(engine.longest)))
	end_text.text = "\n".join(lines)
	if engine.mode == "contract" and won and engine.level < E.CONTRACTS.size() - 1:
		_end_button(tr("Next contract"), HomeKit.GO, _next_contract)
	_end_button(tr("Play again"), HomeKit.BUTTON, _restart)
	_end_button(tr("🏠 %s Home") % tr(HELP.TITLE), HomeKit.BUTTON, _go_home)
	end_card.visible = true
	_layout()
	_record_result(won)
	SoundLib.play(self, "jingles/win_succeeded" if won else "jingles/lose_failed", -6.0)

func _record_result(won: bool) -> void:
	if result_recorded:
		return
	result_recorded = true
	if not info:
		return
	if engine.mode == "practice":
		return
	info.add("Hunts played")
	if engine.mode == "season":
		info.high("Best score", engine.score)
		info.result("win")
	else:
		info.result("win" if won else "loss")
		if won:
			info.high("Contracts done", _contracts_done())
			info.high("Contract stars", _total_stars())
			if _contracts_done() >= E.CONTRACTS.size():
				_report("all_contracts")
	if info.has_method("summary"):
		info.summary()

func _next_contract() -> void:
	_begin("contract", 1, mini(engine.level + 1, E.CONTRACTS.size() - 1))

func _go_home() -> void:
	home.go_home()

func _on_pause() -> void:
	touches.clear()
	mouse_down.clear()
	engine.set_hold(false)
	home.pause()

# ================================================================ contracts card

func _open_contracts() -> void:
	var parts: Array = home.card("🎯 " + tr("Contracts"))
	var body: VBoxContainer = parts[1]
	var note := Label.new()
	note.text = tr("Take exactly what the contract asks; one wrong animal fails it. Stars: %d / %d") % [_total_stars(), E.CONTRACTS.size() * 3]
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	var reached := _contracts_done()
	for n in E.CONTRACTS.size():
		var c: Dictionary = E.CONTRACTS[n]
		var open := n <= reached
		var st := int(progress.stars.get(str(n), 0))
		var btn := Button.new()
		var line := "%d. %s %s · %s · %s" % [n + 1, ENV_ICONS[c.env], tr(ENV_NAMES[c.env]), _contract_take(n), tr("%d–%d m") % [int(c.d[0]), int(c.d[1])]]
		btn.text = (line + "   " + "★".repeat(st) + "☆".repeat(3 - st)) if open else "🔒 " + line
		btn.disabled = not open
		btn.custom_minimum_size = Vector2(0, 62)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.pressed.connect(_pick_contract.bind(n, parts[0]))
		body.add_child(btn)
	home.show_card(parts[0])

func _contract_take(n: int) -> String:
	var c: Dictionary = E.CONTRACTS[n]
	var out: Array = []
	for k in c.take:
		out.append("%d %s" % [int(c.take[k]), tr(E.KIND_NAMES[k])])
	return ", ".join(out)

func _pick_contract(n: int, c: Control) -> void:
	home.close_card(c)
	home.play_now(_start_contract.bind(n))

func _total_stars() -> int:
	var t := 0
	for k in progress.stars:
		t += int(progress.stars[k])
	return t

## Contracts are played in order: done = the first one without a star.
func _contracts_done() -> int:
	var n := 0
	while n < E.CONTRACTS.size() and int(progress.stars.get(str(n), 0)) > 0:
		n += 1
	return n

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	if d is Dictionary and d.get("stars") is Dictionary:
		progress = d

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)

# ================================================================ save / resume

func _save_game() -> void:
	if not started or engine.over or engine.mode == "practice":
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "cam": [cam.x, cam.y], "zoom": zoom})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("engine"):
		return ""
	var e: Dictionary = d.engine
	if str(e.get("mode", "")) == "contract":
		return tr("Contract %d") % (int(e.get("level", 0)) + 1)
	return tr("Open Season") + " · " + tr(E.DIFFS[clampi(int(e.get("diff", 1)), 0, 2)])

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("engine"):
		_start_season(1)
		return
	engine.from_dict(d.engine)
	last_mode = engine.mode
	last_diff = engine.diff
	_after_reset()
	var c = d.get("cam", null)
	if c is Array and c.size() == 2:
		cam = Vector2(float(c[0]), float(c[1]))
	zoom = clampf(float(d.get("zoom", 1.0)), ZOOM_MIN, ZOOM_MAX)

# ================================================================ helps

## 🔭 Spotter: rings every animal for 20 s (gold = take it, red = leave it).
func _help_spotter() -> bool:
	if not started or engine.over:
		return false
	marks.clear()
	for a in engine.animals:
		if a.state != "down":
			var ok: bool = engine.is_target(a.kind) and not (a.kind in engine.forbidden())
			marks[a.id] = "target" if ok else "no"
	spot_t = 20.0
	return not marks.is_empty()

## ➕ Two more rounds.
func _help_rounds() -> bool:
	if not started or engine.over or engine.mode == "practice":
		return false
	engine.rounds += 2
	SoundLib.play(self, "rpg/metal_click", -4.0)
	return true

# ================================================================ skins

func _set_skin(s: String) -> void:
	skin = "voodoo" if s == "voodoo" else "classic"
	if scenery:
		scenery.voodoo = skin == "voodoo"
		sky_l.queue_redraw()
		land_l.queue_redraw()
		_apply_skin_layers()

func _current_skin() -> String:
	return skin

## Landing hero drawing, used only when the landing picture is missing.
func _draw_home_logo(c: Control) -> void:
	var cc := c.size * 0.5
	var r := minf(c.size.x, c.size.y) * 0.42
	c.draw_arc(cc, r, 0, TAU, 64, Color("f0a858"), 4.0, true)
	c.draw_line(cc - Vector2(r, 0), cc + Vector2(r, 0), Color("f4ead2"), 2.0)
	c.draw_line(cc - Vector2(0, r), cc + Vector2(0, r), Color("f4ead2"), 2.0)
	for i in range(1, 5):
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			c.draw_circle(cc + d * r * 0.2 * i, 2.5, Color("f4ead2"))

# ================================================================ sound

func _ambient(delta: float) -> void:
	if not started:
		return
	bird_t -= delta
	if bird_t <= 0.0:
		bird_t = randf_range(4.0, 11.0)
		if engine.env in ["dawn", "noon", "autumn"]:
			for i in 1 + randi() % 3:
				_play(snd_chirp, -20.0 + randf() * 4.0, randf_range(0.85, 1.35))
		elif engine.env in ["dusk", "winter"] and randf() < 0.25:
			SoundLib.play(self, "wolf/howl_lone", -22.0)
	if engine.holding and fposmod(engine._heart_phase, 1.0) < delta * engine.heart_rate / 60.0 + 0.001:
		_play(snd_beat, -14.0, 1.0)

func _play(stream: AudioStream, db: float, pitch: float) -> void:
	var sfx = get_node_or_null("/root/Sfx")
	if sfx and stream and sfx.has_method("play_stream"):
		sfx.play_stream(stream, db, pitch, "game")

func _wind_sound(on: bool) -> void:
	if wind_player and is_instance_valid(wind_player):
		wind_player.queue_free()
	wind_player = null
	if not on or get_node_or_null("/root/Sfx") == null:
		return
	var db := -26.0
	var settings = get_node_or_null("/root/Settings")
	if settings and settings.has_method("group_db"):
		var extra = settings.group_db("game")
		if extra == null:
			return
		db += float(extra)
	wind_player = AudioStreamPlayer.new()
	wind_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	wind_player.stream = _synth_wind()
	wind_player.volume_db = db + absf(engine.wind) * 0.8
	add_child(wind_player)
	wind_player.play()

## The game's own sounds, synthesized once (no files): rifle crack with valley echoes,
## a heartbeat, a breath, a bird chirp and a wind loop. The shared library has no gunshot.
func _make_sounds() -> void:
	var rate := 22050
	var r := RandomNumberGenerator.new()
	r.seed = 77
	# Rifle: sharp crack + boom, then two echoes off the mountains.
	var n := int(rate * 2.2)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var tt := float(i) / rate
		var noise := r.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.12
		lp2 += (noise - lp2) * 0.03
		var crack := noise * exp(-tt * 70.0)
		var boom := lp * exp(-tt * 9.0) * 2.2 + sin(tt * TAU * 55.0) * exp(-tt * 12.0) * 0.6
		var v := crack * 0.9 + boom
		for e in [[0.38, 0.32], [0.86, 0.16], [1.35, 0.07]]:
			var te: float = tt - e[0]
			if te > 0.0:
				v += lp2 * exp(-te * 5.0) * 3.0 * float(e[1])
		buf[i] = v
	snd_shot = _wav(buf, rate)
	# Heartbeat: two low thumps.
	n = int(rate * 0.5)
	buf = PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var tt2 := float(i) / rate
		var v2 := sin(tt2 * TAU * 48.0) * exp(-tt2 * 28.0)
		if tt2 > 0.16:
			v2 += 0.7 * sin((tt2 - 0.16) * TAU * 44.0) * exp(-(tt2 - 0.16) * 30.0)
		buf[i] = v2 * 0.9
	snd_beat = _wav(buf, rate)
	# Breath: filtered noise swelling and fading.
	n = int(rate * 0.7)
	buf = PackedFloat32Array()
	buf.resize(n)
	lp = 0.0
	for i in n:
		var tt3 := float(i) / rate
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.25
		buf[i] = lp * sin(PI * tt3 / 0.7) * 0.8
	snd_breath = _wav(buf, rate)
	# Bird: two quick rising whistles.
	n = int(rate * 0.32)
	buf = PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var tt4 := float(i) / rate
		var seg := fposmod(tt4, 0.16) / 0.16
		var f := 2600.0 + 1400.0 * seg
		ph += TAU * f / rate
		buf[i] = sin(ph) * sin(PI * seg) * 0.35
	snd_chirp = _wav(buf, rate)

func _synth_wind() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 4
	var buf := PackedFloat32Array()
	buf.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var lp := 0.0
	for i in n:
		var tt := float(i) / rate
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.02
		# Gusts: a slow swell that loops seamlessly (whole cycles in 4 s).
		buf[i] = lp * (0.6 + 0.4 * sin(tt * TAU * 0.25)) * 2.5
	var w := _wav(buf, rate)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

static func _wav(buf: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

func _vibrate(ms: int) -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(ms)

func _music(what: String, style: String, index: int = 0, fade: float = 1.5) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	match what:
		"play":
			m.play(style, self, index, fade)
		"stop":
			if m.has_method("stop"):
				m.stop(fade)

func _report(id: String) -> void:
	if ResourceLoader.exists(ACH_PATH):
		load(ACH_PATH).report_challenge(HELP.ID, id)
