extends Control

## Red Mist: one static valley, one rifle. Pinch to zoom the scope, wait for
## the breath to steady (or hold it), tap to shoot. Bullets drop and drift in
## the wind and take time to arrive; the officer with the red armband must not
## get away. An original game (no other sniper game's names, art or levels).
##
## Modes: 🗺 Contracts (30, 5 in each of 6 places, each with its own hour,
## weather and goal: the officer, everyone, beat the clock, stop the trucks;
## some have civilians who must not be hit), ♾ Survival (they keep crossing a
## valley you have reached; 3 get through and it's over), 📅 Daily contract.
## Difficulty: Easy (no drop, no wind), Normal (the scope dials the drop for the
## range under the reticle; you hold for the wind), Hard (hold for both).
##
## Each contract opens on a briefing card (goal, hour, weather, wind, rounds).
## Wins pay cash for the 🛠 Armory: scope, bipod, bolt and suppressor upgrades
## (red_mist_engine.gd UPGRADES). Headshots, long shots and the officer get the
## bullet cam: slow motion riding the bullet in (tap skips; off in Options).
##
## The world is painted in code (red_mist_scenery.gd) into a SubViewport; the
## Landing draws that same picture full-screen behind its menu, so the valley
## is alive behind the title.
##
## Landing menu style: S7 Diegetic Cinema (docs/MENU_STYLES.md): the live valley
## is the menu's backdrop; not one of the last two games' styles (Arrow Pop and
## Block Escape, both Bento).

const E = preload("res://scripts/games/red_mist/red_mist_engine.gd")
const Scenery = preload("res://scripts/games/red_mist/red_mist_scenery.gd")
const HELP = preload("res://scripts/games/red_mist/red_mist_help.gd")
const MenuStyles = preload("res://scripts/games/red_mist/menu_styles.gd")
const HomeKit = preload("res://scripts/games/red_mist/home_kit.gd")
const SoundLib = preload("res://scripts/games/red_mist/sound_lib.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SAVE_PATH := "user://red_mist_save.json"
const PROGRESS_PATH := "user://red_mist_progress.json"
const PREFS_PATH := "user://red_mist_prefs.json"

const ZOOM_MIN := 1.0
const ZOOM_SCOPE := 1.6       # at or above this the view is through the scope
const TAP_PX := 16.0
const TAP_MS := 450
const RED := Color("e8322a")
const ACCENT := Color("ff5a3c")

## A drawing layer in the world: calls `fn(self)`; `live` ones redraw every frame.
class Layer extends Node2D:
	var fn: Callable
	var live := false
	func _draw() -> void:
		# A layer of the previous valley can get one more draw after the world is
		# rebuilt (with the new place's palette): skip it.
		if fn.is_valid() and not is_queued_for_deletion():
			fn.call(self)

## Keeps the scenery moving while the Landing or the pause menu has the tree paused.
class Ticker extends Node:
	var fn: Callable
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(delta: float) -> void:
		if fn.is_valid():
			fn.call(delta)

var info = null
var home
var engine
var skin := "classic"
var pal: Dictionary = {}
var level := 1
var playing := false
var result_shown := false
var progress: Dictionary = {"reached": 0, "stars": {}, "daily": {}, "cash": 0, "kit": {}}
var prefs: Dictionary = {"level": 1, "effect": 0, "reticle": 0, "left": false, "bulletcam": 0, "invy": 0}
var briefing := false               # the briefing card is up: the contract waits
var brief_panel: Control
var brief_title: Label
var brief_sub: Label
var brief_text: Label
var bcam: Dictionary = {}           # bullet cam: {"from", "to", "tof", "t", "id", "d", "z0", "cam0", "hold"}
var rifle_layer: Control
var smoke: Array = []               # screen-space muzzle smoke: {"p", "v", "t"}
var cash_won := 0

# World
var vpc: SubViewportContainer
var vp: SubViewport
var world: Node2D
var layers_live: Array = []
var target_nodes: Dictionary = {}   # id -> Layer
var prop_nodes: Dictionary = {}     # id -> Layer
var effects: Array = []             # {"k": kind, "p": world pos, "d": range, "t": age, "life", "node": Layer, "seed"}
var cam := Vector2(E.W * 0.5, E.H * 0.6)
var zoom := 1.0
var zoom_target := 1.0
var anim_t := 0.0
var recoil := 0.0
var shake := 0.0
var birds_scatter := 0.0
var flash := 0.0
var flash_t := 6.0
var precip: Array = []              # screen-space snow / rain / dust: Vector3(x, y, speed)
var _landing_logo: Control = null

# Overlays
var precip_layer: Control
var scope_rect: ColorRect
var scope_mat: ShaderMaterial
var reticle: Control
var hud: Control
var hold_btn: Button
var zoom_slider: VSlider
var pause_btn: Button
var hint: Label
var hint_t := 0.0
var banner := ""
var banner_t := 0.0
var end_dialog: Control
var end_title: Label
var end_msg: Label
var next_btn: Button
var see_btn: Button
var results_chip: Button
var tracers: Array = []             # {"from": world, "to": world, "t", "tof"}
var spotter_t := 0.0
var floating: Array = []            # {"text", "p" (world), "t"}

# Input
var fingers: Dictionary = {}        # touch index -> position
var pinch_d0 := 0.0
var pinch_z0 := 1.0
var gesture_multi := false
var press_pos := Vector2.ZERO
var press_ms := 0
var pressing := false
var drag_last := Vector2.ZERO
var dragged := false
var key_hold := false
var tutorial := false         # the intro level is running
var coaching := false         # a tutorial card is up: the world waits
var tut_step := 0
var tut_level := 1            # the real difficulty, put back when the tutorial ends
var tut_fired := false
var coach: Control
var coach_card: PanelContainer
var coach_text: Label
var coach_next: Button
var pad_hold := false      # gamepad: left trigger / B / X
var pad_fire_down := false  # right trigger edge detector
var mouse_hold := false
var shot_sound: AudioStreamWAV = null
var rain_loop: Node = null
var snd_beat: AudioStreamWAV = null
var snd_breath: AudioStreamWAV = null
var wind_player: AudioStreamPlayer = null
var last_beat := 0.0
var was_gasping := false

func _ready() -> void:
	preload("res://scripts/games/red_mist/red_mist_i18n.gd").install(self)
	Orientation.lock_landscape()
	_load_progress()
	engine = E.new()
	level = int(prefs.get("level", 1))
	engine.reset("contract", level, mini(int(progress.reached), E.CONTRACTS.size() - 1))
	_build_ui()
	_build_world()
	_frame_landing()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _exit_tree() -> void:
	get_tree().paused = false

# ---------- building ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vpc)
	vp = SubViewport.new()
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	vpc.add_child(vp)
	var vbg := ColorRect.new()
	vbg.color = Color.BLACK
	vbg.size = Vector2(8000, 8000)
	vbg.position = Vector2(-4000, -4000)
	vbg.z_index = RenderingServer.CANVAS_ITEM_Z_MIN  # under every scenery layer (they use z -4000..3600)
	vp.add_child(vbg)
	world = Node2D.new()
	world.name = "World"
	vp.add_child(world)

	precip_layer = _overlay_control(_draw_precip)
	rifle_layer = _overlay_control(_draw_rifle)
	scope_rect = ColorRect.new()
	scope_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_mat = ShaderMaterial.new()
	scope_mat.shader = _scope_shader()
	scope_rect.material = scope_mat
	add_child(scope_rect)
	reticle = _overlay_control(_draw_reticle)
	hud = _overlay_control(_draw_hud)

	_build_coach()
	hint = HomeKit.label("", 26, Color(1, 1, 1, 0.92), true, true)
	hint.add_theme_constant_override("outline_size", 8)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -420
	hint.offset_right = 420
	hint.offset_top = -250
	hint.offset_bottom = -150
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	pause_btn = Button.new()
	pause_btn.text = "⏸"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.add_theme_font_size_override("font_size", 28)
	pause_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pause_btn.offset_left = -36
	pause_btn.offset_right = 36
	pause_btn.offset_top = 22
	pause_btn.offset_bottom = 82
	pause_btn.pressed.connect(_on_pause)
	_glass(pause_btn)
	add_child(pause_btn)

	hold_btn = Button.new()
	hold_btn.text = tr("🫁 Hold\nbreath")
	hold_btn.focus_mode = Control.FOCUS_NONE
	hold_btn.add_theme_font_size_override("font_size", 22)
	hold_btn.button_down.connect(_on_hold.bind(true))
	hold_btn.button_up.connect(_on_hold.bind(false))
	_glass(hold_btn, 70)
	add_child(hold_btn)

	zoom_slider = VSlider.new()
	zoom_slider.min_value = ZOOM_MIN
	zoom_slider.max_value = _zoom_max()
	zoom_slider.step = 0.05
	zoom_slider.value = 1.0
	zoom_slider.focus_mode = Control.FOCUS_NONE
	zoom_slider.value_changed.connect(_on_zoom_slider)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.04, 0.03, 0.03, 0.55)
	track.set_corner_radius_all(14)
	track.set_border_width_all(2)
	track.border_color = Color(ACCENT, 0.5)
	track.content_margin_left = 10
	track.content_margin_right = 10
	zoom_slider.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(ACCENT, 0.45)
	fill.set_corner_radius_all(14)
	fill.content_margin_left = 10
	fill.content_margin_right = 10
	zoom_slider.add_theme_stylebox_override("grabber_area", fill)
	zoom_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	add_child(zoom_slider)
	resized.connect(_layout_controls)
	call_deferred("_layout_controls")

	end_dialog = UI.build_dialog("", [
		{"text": tr("▶ Next contract"), "action": _next_contract},
		{"text": tr("↺ Try again"), "action": _retry},
		{"text": tr("👁 See the valley"), "action": _see_valley},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)
	end_msg = end_dialog.get_meta("message_label")
	end_msg.add_theme_font_size_override("font_size", 24)
	end_msg.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	end_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_msg.custom_minimum_size = Vector2(280, 0)
	var box: VBoxContainer = end_msg.get_parent()
	end_title = HomeKit.label("", 44, ACCENT, true, true)
	end_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_title)
	box.move_child(end_title, 0)
	next_btn = _find_button(end_dialog, tr("▶ Next contract"))
	see_btn = _find_button(end_dialog, tr("👁 See the valley"))
	for b in [next_btn, see_btn, _find_button(end_dialog, tr("↺ Try again")), _find_button(end_dialog, tr("🏠 %s Home") % tr(HELP.TITLE))]:
		if b:
			b.custom_minimum_size = Vector2(260, 58)
			b.add_theme_font_size_override("font_size", 24)
	var panel := box.get_parent() as PanelContainer
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.05, 0.94)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(ACCENT, 0.7)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	results_chip = Button.new()
	results_chip.text = tr("📋 Results")
	results_chip.focus_mode = Control.FOCUS_NONE
	results_chip.visible = false
	results_chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	results_chip.offset_left = -110
	results_chip.offset_right = 110
	results_chip.offset_top = -86
	results_chip.offset_bottom = -26
	results_chip.pressed.connect(_show_results_again)
	_glass(results_chip)
	add_child(results_chip)

	_build_briefing()
	var ticker := Ticker.new()
	ticker.fn = _tick_always
	add_child(ticker)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S7 Diegetic Cinema; colours: blood red + dusk amber on the live valley.
		"landing": "cinema",
		"landing_style": MenuStyles,
		"title_font": "res://games/red_mist/title.ttf",
		"title_colors": [Color("ff4a3a"), Color("ffb26a")],
		"landing_colors": [Color("0b0608"), Color("2a1010")],
		"menu_color": ACCENT,
		"landing_stars": 0,
		"help": HELP,
		"info": info,
		"accent": ACCENT,
		"subtitle": "One valley. One rifle. Wait for the breath, then squeeze.",
		"logo": _draw_landing_scene,
		"solo_heading": "🎮 Single player",
		"extra": _add_setup,
		"modes": [
			{"text": "🎯 Next contract", "sub": "Pick up where you left off", "action": _start_next_contract},
			{"text": "♾ Survival", "sub": "They keep crossing the valley. Let 3 through and it's over.", "action": _start_survival},
			{"text": "📅 Daily contract", "sub": "The same valley and targets for everyone today", "action": _start_daily},
		],
		"play": [
			{"text": "🎓 Tutorial", "sub": "A quick intro: the scope, every HUD gauge and the controls", "action": _start_tutorial},
			{"text": "🗺 Contracts", "sub": "30 contracts in 6 places", "action": _open_contracts, "card": true},
			{"text": "🛠 Armory", "sub": "Spend your pay on rifle upgrades", "action": _open_armory, "card": true},
		],
		"options": _add_game_options,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _retry,
		"helps": [
			{"text": "🔭 Spotter", "how": "For 20 seconds a red diamond shows exactly where to aim for the officer (or the target in your sights): drop and wind worked out.", "action": _help_spotter},
			{"text": "📦 3 rounds", "how": "Three more rounds for this contract.", "action": _help_rounds},
		],
		"board": "Best score",
		"board_note": "Your best score in one contract, daily contract or survival run.",
	})
	add_child(home)
	if info:
		add_child(info)

## The briefing card: what this contract wants, then ▶ Begin.
func _build_briefing() -> void:
	brief_panel = ColorRect.new()
	(brief_panel as ColorRect).color = Color(0, 0, 0, 0.45)
	brief_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	brief_panel.visible = false
	add_child(brief_panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief_panel.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.05, 0.92)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(ACCENT, 0.7)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(minf(620.0, 560.0), 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	brief_title = HomeKit.label("", 32, ACCENT, true, true)
	brief_sub = HomeKit.label("", 20, Color(1, 1, 1, 0.75), true, true)
	brief_text = HomeKit.label("", 22, Color(0.95, 0.95, 0.97), true, true)
	for l in [brief_title, brief_sub, brief_text]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		box.add_child(l)
	var go := HomeKit.neon_button(tr("▶ Begin"), HomeKit.GO, 26, 64)
	go.pressed.connect(_on_begin)
	box.add_child(go)

func _overlay_control(fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(fn)
	add_child(c)
	return c

func _glass(b: Button, radius: int = 18) -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.03, 0.03, 0.55 if st != "pressed" else 0.85)
		sb.set_corner_radius_all(radius)
		sb.set_border_width_all(2)
		sb.border_color = Color(ACCENT, 0.85 if st == "pressed" else 0.5)
		b.add_theme_stylebox_override(st, sb)

func _find_button(n: Node, text: String) -> Button:
	for ch in n.get_children():
		if ch is Button and ch.text == text:
			return ch
		var f := _find_button(ch, text)
		if f:
			return f
	return null

## Hold button and zoom slider sit on the right (left-handed: on the left), inside the safe area.
func _layout_controls() -> void:
	var s := size
	var safe := 24.0
	var left: bool = prefs.get("left", false)
	var bw := 128.0
	var bh := 112.0
	hold_btn.size = Vector2(bw, bh)
	hold_btn.position = Vector2((safe + 8.0) if left else (s.x - bw - safe - 8.0), s.y - bh - 24.0)
	zoom_slider.size = Vector2(56, clampf(s.y * 0.42, 160.0, 320.0))
	zoom_slider.position = Vector2((safe + 36.0) if left else (s.x - 56.0 - safe - 44.0), s.y * 0.22)

func _scope_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 size = vec2(1280.0, 720.0);
uniform vec2 center = vec2(640.0, 360.0);
uniform float radius = 300.0;
uniform float amount = 1.0;
uniform vec3 tint = vec3(0.0);
uniform float nv = 0.0;
uniform float time = 0.0;
uniform vec2 eye = vec2(0.0);
uniform float kick = 0.0;
void fragment() {
	vec2 p = UV * size;
	float d = length(p - center);
	float outside = smoothstep(radius - 1.5, radius + 1.5, d);
	float vig = smoothstep(radius * 0.5, radius, d) * 0.6;
	float rim = smoothstep(radius - 16.0, radius - 2.0, d) * (1.0 - outside);
	float grain = fract(sin(dot(p + time, vec2(12.9898, 78.233))) * 43758.5453);
	// The eye off-centre behind the glass: a dark crescent on the far side.
	float de = length(p - (center + eye));
	float cres = smoothstep(radius * 0.84, radius * 0.99, de) * (1.0 - outside) * 0.92;
	// A thin coloured fringe just inside the tube, as real glass gives.
	float fringe = smoothstep(radius - 7.0, radius - 4.5, d) * (1.0 - smoothstep(radius - 4.5, radius - 2.0, d));
	vec3 col = mix(vec3(0.0), vec3(0.03, 0.08, 0.12), rim);
	col = mix(col, vec3(0.55, 0.12, 0.25), fringe * 0.7);
	float a = max(outside, max(max(vig, rim * 0.8), max(cres, fringe * 0.5)));
	a = max(a, kick * 0.35 * (1.0 - outside));
	vec4 nvc = vec4(0.1, 0.5, 0.15, 0.10 + 0.06 * grain) * nv * (1.0 - outside);
	COLOR = vec4(mix(col, nvc.rgb, nvc.a), max(a, nvc.a)) * vec4(1.0, 1.0, 1.0, amount);
}
"""
	return sh

# ---------- the world ----------

func _clear_world() -> void:
	for ch in world.get_children():
		ch.queue_free()
	layers_live.clear()
	target_nodes.clear()
	prop_nodes.clear()
	for fx in effects:
		if is_instance_valid(fx.node):
			fx.node.queue_free()
	effects.clear()
	tracers.clear()
	floating.clear()

## `tinted`: the layer takes the hour's light (pal.tint, dark blue at night); the
## sky, lights, flames and rays don't.
func _layer(z: int, fn: Callable, live: bool, tinted: bool = true) -> Layer:
	var l := Layer.new()
	l.fn = fn
	l.live = live
	l.z_index = z
	if tinted:
		l.modulate = pal.get("tint", Color.WHITE)
	world.add_child(l)
	if live:
		layers_live.append(l)
	return l

func _build_world() -> void:
	_clear_world()
	pal = Scenery.palette(engine.loc, skin, engine.tod, engine.wx)
	var lay: Dictionary = E.LAYOUT[engine.loc]
	_layer(-4000, func(ci): Scenery.draw_sky(ci, pal, anim_t, engine.wind, flash), true, false)
	_layer(-3990, func(ci): Scenery.draw_rays(ci, pal, anim_t), true, false)
	_layer(-3950, func(ci): Scenery.draw_birds(ci, pal, anim_t, birds_scatter), true)
	_layer(-3900, func(ci): Scenery.draw_far(ci, pal), false)
	_layer(-3895, func(ci): Scenery.draw_far_lights(ci, pal), false, false)
	_layer(-3800, func(ci): Scenery.draw_ground(ci, pal, lay), false)
	if engine.loc == "city":
		_layer(-3785, func(ci): Scenery.draw_street_lights(ci, pal, lay), false, false)
	if lay.has("sea"):
		_layer(-3790, func(ci): Scenery.draw_water(ci, pal, lay, anim_t), true)
	for s in lay.structures:
		var z := Scenery.z_for(float(s.get("zd", s.d)))
		_layer(z, func(ci): Scenery.draw_structure(ci, s, pal), false)
		_layer(z, func(ci): Scenery.draw_structure_live(ci, s, pal, anim_t, engine.wind), true, false)
		_layer(z, func(ci): Scenery.draw_lights(ci, s, pal, anim_t), true, false)
		if str(s.t) in ["tower", "stilt", "ship", "block", "watertower", "trestle"]:
			# A rail or parapet in front of anyone standing up there (they stand a few metres nearer).
			_layer(Scenery.z_for(float(s.d) - 6.0) + 2, func(ci): Scenery.draw_front_rail(ci, s, pal), false)
	if float(pal.get("fog", 0.0)) > 0.0:
		for i in 4:
			var fd: float = [260.0, 420.0, 640.0, 900.0][i]
			_layer(Scenery.z_for(fd) + 5, func(ci): Scenery.draw_fog(ci, pal, anim_t, engine.wind, fd, 900 + i), true)
	for pr in engine.props:
		_add_prop_node(pr)
	_sync_targets()
	_layer(3300, _draw_truck_lights, true, false)
	_layer(3500, func(ci): Scenery.draw_front(ci, pal, anim_t, engine.wind), true)
	_layer(3600, _draw_world_fx_top, true, false)
	_reset_precip()
	_update_rain_loop()

func _add_prop_node(pr: Dictionary) -> void:
	var z := Scenery.z_for(float(pr.d)) + 1
	var id: int = pr.id
	if pr.kind == "drum":
		prop_nodes[id] = _layer(z, func(ci): Scenery.draw_drum(ci, _prop(id), pal), true)
	elif pr.kind == "truck":
		prop_nodes[id] = _layer(z, func(ci): _draw_truck(ci, id), true)
	else:
		prop_nodes[id] = _layer(Scenery.z_for(float(pr.d)) + 3, func(ci): Scenery.draw_dish(ci, _prop(id), pal, anim_t), true)

func _prop(id: int) -> Dictionary:
	for pr in engine.props:
		if int(pr.id) == id:
			return pr
	return {"id": id, "kind": "drum", "x": 0.0, "d": 100.0, "h": 0.0, "alive": false}

func _draw_truck(ci: CanvasItem, id: int) -> void:
	var tr_ := _prop(id)
	if tr_.kind == "truck":
		Scenery.draw_truck(ci, tr_, engine.truck_pos(tr_), pal, anim_t, engine.wind)

func _draw_truck_lights(ci: CanvasItem) -> void:
	for pr in engine.props:
		if pr.kind == "truck":
			Scenery.draw_truck_lights(ci, pr, engine.truck_pos(pr), pal)

## Trucks change range as they drive: keep their layer sorted.
func _sort_trucks() -> void:
	for pr in engine.props:
		if pr.kind == "truck" and prop_nodes.has(int(pr.id)):
			(prop_nodes[int(pr.id)] as Layer).z_index = Scenery.z_for(float(pr.d)) + 1

## One node per target (created as they appear, freed when gone).
func _sync_targets() -> void:
	var seen := {}
	for tg in engine.targets:
		var id: int = tg.id
		seen[id] = true
		if not target_nodes.has(id):
			var l := _layer(Scenery.z_for(float(tg.d)) + 1, _draw_target.bind(id), true)
			target_nodes[id] = l
	for id in target_nodes.keys():
		if not seen.has(id):
			var l: Layer = target_nodes[id]
			layers_live.erase(l)
			l.queue_free()
			target_nodes.erase(id)

func _draw_target(ci: CanvasItem, id: int) -> void:
	for tg in engine.targets:
		if int(tg.id) == id:
			Scenery.draw_guard(ci, tg, engine.target_pos(tg), pal, anim_t, level < 2 and engine.mode != "survival")
			return

# ---------- every frame ----------

## Runs even while the tree is paused (Landing, pause menu): the valley stays alive.
func _tick_always(delta: float) -> void:
	anim_t += delta
	birds_scatter = maxf(0.0, birds_scatter - delta * 0.08) if birds_scatter < 0.98 else birds_scatter - delta * 0.02
	if pal.get("wx", "") == "storm":
		flash_t -= delta
		if flash_t <= 0.0:
			flash = 1.0
			flash_t = randf_range(5.0, 12.0)
			if playing and not get_tree().paused:
				SoundLib.play(self, "scifi/low_frequency_explosion", -16.0, "game", 0.5)
		flash = maxf(0.0, flash - delta * 3.0)
	if home and home.is_home_visible():
		# The Landing: a slow pan across the valley at the naked eye.
		zoom = 1.0
		zoom_target = 1.0
		cam = Vector2(E.W * 0.5 + sin(anim_t * 0.05) * 260.0, E.H * 0.58)
		_apply_camera()
		if is_instance_valid(_landing_logo):
			_landing_logo.queue_redraw()
	_step_precip(delta)
	for sm in smoke.duplicate():
		sm.t += delta
		if sm.t > 1.6:
			smoke.erase(sm)
	for l in layers_live:
		if is_instance_valid(l):
			l.queue_redraw()
	precip_layer.queue_redraw()

func _process(delta: float) -> void:
	if not playing:
		_apply_camera()
		_draw_overlays()
		return
	if coaching:
		coach.queue_redraw()
		_apply_camera()
		_draw_overlays()
		return
	if briefing:
		# The contract waits under the briefing card; the camera drifts over the valley.
		cam = Vector2(E.W * 0.5 + sin(anim_t * 0.08) * 200.0, E.H * 0.6)
		_apply_camera()
		_draw_overlays()
		return
	if not bcam.is_empty():
		_step_bullet_cam(delta)
		return
	engine.step(delta)
	_handle_events()
	_sync_targets()
	_sort_trucks()
	_body_sounds()
	_pad_aim(delta)
	zoom = lerpf(zoom, zoom_target, minf(1.0, delta * 12.0))
	recoil = move_toward(recoil, 0.0, delta * 9.0)
	shake = maxf(0.0, shake - delta * 4.0)
	spotter_t = maxf(0.0, spotter_t - delta)
	hint_t = maxf(0.0, hint_t - delta)
	banner_t = maxf(0.0, banner_t - delta)
	hint.modulate.a = clampf(hint_t, 0.0, 1.0)
	hint.visible = bcam.is_empty() and not briefing
	_step_effects(delta)
	_apply_camera()
	_draw_overlays()
	if tutorial and tut_fired and bcam.is_empty() and (not engine.over or effects.is_empty()):
		tut_fired = false
		_coach_show(_tut_steps().size() - 1)
	if engine.over and not result_shown and effects.is_empty() and bcam.is_empty() and not tutorial:
		_show_result()

## Bullet cam: the world runs at 1/8 speed while the camera rides the bullet in
## and closes on the target; it holds on the hit for a moment, then hands back.
func _step_bullet_cam(delta: float) -> void:
	var slow := 0.125
	if bcam.hold < 0.0:
		bcam.t += delta * slow
		engine.step(delta * slow)
		_handle_events()
		_sync_targets()
		_sort_trucks()
		_step_effects(delta * slow)
		var f := clampf(float(bcam.t) / float(bcam.tof), 0.0, 1.0)
		var e := f * f * (3.0 - 2.0 * f)
		hint.visible = false
		zoom = float(bcam.zs) * pow(float(bcam.z1) / float(bcam.zs), e)  # pull back, then fly in
		cam = (bcam.from as Vector2).lerp(bcam.to, f)
		if f >= 1.0:
			bcam.hold = 1.1
	else:
		bcam.hold -= delta
		engine.step(delta * 0.35)
		_handle_events()
		_sync_targets()
		_step_effects(delta * 0.35)
		cam = bcam.to
		if bcam.hold <= 0.0:
			_end_bullet_cam()
			if engine.over and not result_shown:
				_show_result()
			return
	recoil = 0.0
	shake = 0.0
	_apply_camera()
	_draw_overlays()

func _end_bullet_cam() -> void:
	if bcam.is_empty():
		return
	cam = bcam.cam0
	zoom = bcam.z0
	zoom_target = bcam.z0
	bcam = {}
	_apply_camera()

func _draw_overlays() -> void:
	var scoped := zoom >= ZOOM_SCOPE and bcam.is_empty()
	scope_rect.visible = scoped and playing
	if scope_rect.visible:
		var s := size
		scope_mat.set_shader_parameter("size", s)
		scope_mat.set_shader_parameter("center", _scope_center())
		scope_mat.set_shader_parameter("radius", _scope_radius())
		scope_mat.set_shader_parameter("amount", clampf((zoom - ZOOM_SCOPE) / 0.4 + 0.3, 0.0, 1.0))
		scope_mat.set_shader_parameter("nv", 1.0 if pal.get("night", false) and skin == "classic" else 0.0)
		scope_mat.set_shader_parameter("time", anim_t)
		var eye: Vector2 = -engine.sway_mils() * E.MIL * _scale() * 0.45 + Vector2(0, recoil * 40.0)
		var rr := _scope_radius()
		if eye.length() > rr * 0.14:
			eye = eye.normalized() * rr * 0.14
		scope_mat.set_shader_parameter("eye", eye)
		scope_mat.set_shader_parameter("kick", recoil)
	world.modulate = _world_tint(scoped)
	if not zoom_slider.has_focus() and absf(zoom_slider.value - zoom_target) > 0.01:
		zoom_slider.set_value_no_signal(zoom_target)
	for c in [hold_btn, zoom_slider, pause_btn]:
		c.visible = playing and not engine.over and not briefing and bcam.is_empty()
	rifle_layer.queue_redraw()
	reticle.queue_redraw()
	hud.queue_redraw()

## The night itself is in each layer's tint; through the scope at night the
## picture turns night-vision green.
func _world_tint(scoped: bool) -> Color:
	if pal.get("night", false) and skin == "classic" and scoped and playing:
		return Color(1.5, 3.4, 1.6)
	return Color.WHITE

func _scope_center() -> Vector2:
	return size * 0.5

func _scope_radius() -> float:
	return minf(size.y * 0.47, size.x * 0.4)

func _base_scale() -> float:
	var s := size if size.x > 0.0 else Vector2(1280, 720)
	return maxf(s.x / E.W, s.y / E.H)

func _scale() -> float:
	return _base_scale() * zoom

## Where the reticle points in the world now: the camera, the breathing sway, the kick.
func _aim_world() -> Vector2:
	var a := cam
	if zoom >= ZOOM_SCOPE and playing and bcam.is_empty() and not briefing:
		a += engine.sway_mils() * E.MIL
	a += Vector2(0.0, -recoil * 6.0 * E.MIL)
	if shake > 0.0:
		a += Vector2(sin(anim_t * 60.0), cos(anim_t * 53.0)) * shake * 2.0 * E.MIL
	return a

func _apply_camera() -> void:
	var s := size if size.x > 0.0 else Vector2(1280, 720)
	var sc := _scale()
	var half := s / (2.0 * sc)
	cam.x = clampf(cam.x, minf(half.x, E.W * 0.5), maxf(E.W - half.x, E.W * 0.5))
	cam.y = clampf(cam.y, minf(half.y, E.H * 0.5), maxf(E.H - half.y, E.H * 0.5))
	var c := _aim_world()
	world.scale = Vector2(sc, sc)
	world.position = s * 0.5 - c * sc

func _world_to_screen(p: Vector2) -> Vector2:
	return world.position + p * world.scale.x

# ---------- events from the engine ----------

func _handle_events() -> void:
	for ev in engine.events:
		match str(ev.e):
			"down":
				var tg := _target(int(ev.id))
				var u := E.upm(float(ev.d))
				var p: Vector2 = engine.target_pos(tg) + Vector2(0, -(1.65 if ev.head else 1.2) * u) if not tg.is_empty() else Vector2(float(ev.x), E.ground_y(float(ev.d)))
				_add_effect("mist" if int(prefs.get("effect", 0)) == 0 and not ev.get("civ", false) else "dust", p, float(ev.d), 1.4)
				if not ev.get("civ", false):
					_float_text(("+%d" % int(ev.points)) + ("  " + tr("HEADSHOT") if ev.head else ""), p + Vector2(0, -1.2 * u))
				SoundLib.play(self, "impact/soft_heavy", -12.0 if float(ev.d) < 400.0 else -18.0)
				if ev.primary:
					_banner(tr("Officer down!"))
				_vibrate(30)
			"civilian":
				_banner(tr("You hit a civilian. Contract over."))
			"truck":
				_banner(tr("A truck is on the move!"))
			"truck_escape":
				_banner(tr("A truck got away"))
			"cab":
				var p := Vector2(float(ev.x), E.ground_y(float(ev.d)) - 2.0 * E.upm(float(ev.d)))
				_add_effect("spark", p, float(ev.d), 0.8)
				_float_text("+%d  " % int(ev.points) + tr("DRIVER"), p)
				SoundLib.play(self, "impact/glass_light", -8.0)
				_banner(tr("Truck stopped!"))
			"boom":
				var p := Vector2(float(ev.x), E.ground_y(float(ev.d)) - (float(ev.get("h", 0.0)) + 0.6) * E.upm(float(ev.d)))
				_add_effect("boom", p, float(ev.d), 2.2)
				get_tree().create_timer(float(ev.d) / 343.0, false).timeout.connect(_boom_sound)
				birds_scatter = 1.0
			"dish":
				var pr := _prop(int(ev.id))
				_add_effect("spark", Vector2(float(pr.x), E.ground_y(float(pr.d)) - (float(pr.h) + 0.6) * E.upm(float(pr.d))), float(pr.d), 0.8)
				SoundLib.play(self, "impact/metal_heavy", -10.0)
				_banner(tr("Dish down: the alarm is quiet for 20 seconds"))
			"flee":
				if ev.primary:
					_banner(tr("The officer is running for it!"))
			"escape":
				if engine.mode == "survival":
					_banner(tr("One got through (%d / 3)") % engine.escapes)
				elif ev.primary:
					_banner(tr("The officer got away"))
	engine.events.clear()

func _target(id: int) -> Dictionary:
	for tg in engine.targets:
		if int(tg.id) == id:
			return tg
	return {}

func _boom_sound() -> void:
	SoundLib.play(self, "scifi/explosion_crunch", -6.0)

func _banner(text: String) -> void:
	banner = text
	banner_t = 2.6

func _hint(text: String, secs: float = 3.5) -> void:
	hint.text = text
	hint_t = secs

func _float_text(text: String, p: Vector2) -> void:
	floating.append({"text": text, "p": p, "t": 0.0})

# ---------- effects (world space) ----------

func _add_effect(kind: String, p: Vector2, d: float, life: float) -> void:
	var fx := {"k": kind, "p": p, "d": d, "t": 0.0, "life": life, "seed": randi()}
	fx["node"] = _layer(Scenery.z_for(d) + 4, _draw_effect.bind(fx), true, kind != "mist" and kind != "dust" and kind != "puff")
	effects.append(fx)

func _step_effects(delta: float) -> void:
	for fx in effects.duplicate():
		fx.t += delta
		if fx.t >= fx.life:
			layers_live.erase(fx.node)
			fx.node.queue_free()
			effects.erase(fx)
	for tr_ in tracers.duplicate():
		tr_.t += delta
		if tr_.t >= tr_.tof:
			tracers.erase(tr_)
	for f in floating.duplicate():
		f.t += delta
		if f.t > 1.6:
			floating.erase(f)

func _draw_effect(ci: CanvasItem, fx: Dictionary) -> void:
	var u := E.upm(float(fx.d))
	var k: float = fx.t / fx.life
	var p: Vector2 = fx.p
	var drift := Vector2(engine.wind * 0.35 * u * fx.t, 0.0)
	var r := RandomNumberGenerator.new()
	r.seed = int(fx.seed)
	match str(fx.k):
		"mist":
			# The red mist: a soft cloud that spreads and drifts with the wind, and a few drops.
			var base := Color("b3121a") if skin == "classic" else Color("ff2bd6")
			for i in 7:
				var o := Vector2(r.randf_range(-0.35, 0.35), r.randf_range(-0.3, 0.2)) * u
				var rad := (0.25 + k * 0.9 + r.randf() * 0.2) * u
				ci.draw_circle(p + o + drift * (1.0 + i * 0.1), rad, Color(base, 0.22 * (1.0 - k)))
			for i in 10:
				var v := Vector2(r.randf_range(-1.0, 1.0), r.randf_range(-1.4, 0.2)) * 1.6 * u
				var q: Vector2 = p + v * float(fx.t) + Vector2(0, 4.9 * fx.t * fx.t * u) + drift
				ci.draw_circle(q, maxf(0.5, 0.05 * u), Color(base.darkened(0.2), 0.8 * (1.0 - k)))
		"dust":
			var base := Color(0.75, 0.68, 0.55) if skin == "classic" else Color("29e6ff")
			for i in 6:
				var o := Vector2(r.randf_range(-0.5, 0.5), r.randf_range(-0.4, 0.1)) * u
				ci.draw_circle(p + o + drift + Vector2(0, -k * 0.6 * u), (0.2 + k * 0.8) * u, Color(base, 0.35 * (1.0 - k)))
		"boom":
			var fire := clampf(1.0 - k * 2.5, 0.0, 1.0)
			ci.draw_circle(p, (1.0 + k * 6.0) * u, Color(1.0, 0.9, 0.6, 0.12 * (1.0 - k)))
			for i in 9:
				var a := TAU * i / 9.0 + r.randf()
				var q := p + Vector2(cos(a), sin(a) * 0.6 - 0.5) * (0.5 + k * 3.0) * u + drift
				ci.draw_circle(q, (0.9 + k * 2.2) * u, Color(0.12, 0.1, 0.1, 0.5 * (1.0 - k)))
				if fire > 0.0:
					ci.draw_circle(q, (0.8 + k * 1.2) * u, Color(1.0, 0.55 + 0.3 * r.randf(), 0.1, 0.85 * fire))
		"spark":
			for i in 12:
				var a := TAU * i / 12.0 + r.randf()
				var q := p + Vector2(cos(a), sin(a)) * k * 2.0 * u + Vector2(0, 4.9 * fx.t * fx.t * u)
				ci.draw_line(q, q + Vector2(cos(a), sin(a)) * 0.25 * u, Color(1.0, 0.85, 0.4, 1.0 - k), maxf(0.6, 0.05 * u))
		"puff":
			ci.draw_circle(p + drift, (0.2 + k * 0.6) * u, Color(0.8, 0.75, 0.65, 0.4 * (1.0 - k)))

## Bullet traces and the floating score text, over everything in the world.
func _draw_world_fx_top(ci: CanvasItem) -> void:
	if not bcam.is_empty() and bcam.hold < 0.0:
		var f := clampf(float(bcam.t) / float(bcam.tof), 0.0, 1.0)
		var bp: Vector2 = (bcam.from as Vector2).lerp(bcam.to, f)
		var px := 1.0 / world.scale.x  # one screen pixel in world units
		var dir: Vector2 = ((bcam.to as Vector2) - (bcam.from as Vector2)).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		# A swirl of disturbed air behind it, then the bullet: brass-tipped, spinning.
		for k in 5:
			var rr := (10.0 + k * 9.0 + fposmod(anim_t * 120.0, 9.0)) * px
			ci.draw_arc(bp - dir * k * 8.0 * px, rr, 0, TAU, 24, Color(1, 1, 1, 0.12 - k * 0.02), 1.5 * px)
		ci.draw_circle(bp, 7.0 * px, Color(0.55, 0.4, 0.18))
		ci.draw_circle(bp + Vector2(-2, -2) * px, 3.0 * px, Color(0.95, 0.8, 0.5))
		var spin := anim_t * 40.0
		ci.draw_line(bp + Vector2(cos(spin), sin(spin)) * 6.0 * px, bp - Vector2(cos(spin), sin(spin)) * 6.0 * px, Color(0.3, 0.2, 0.1, 0.8), 1.5 * px)
	for tr_ in (tracers if bcam.is_empty() else []):
		var f: float = tr_.t / tr_.tof
		if f < 0.15:
			continue
		var a: Vector2 = tr_.from
		var b: Vector2 = tr_.to
		var p := a.lerp(b, f) + Vector2(0, -sin(f * PI) * a.distance_to(b) * 0.04)
		var q := a.lerp(b, maxf(0.0, f - 0.12)) + Vector2(0, -sin(maxf(0.0, f - 0.12) * PI) * a.distance_to(b) * 0.04)
		var w := 2.0 / world.scale.x
		ci.draw_line(q, p, Color(1.0, 0.95, 0.8, 0.35), w * 2.0)
		ci.draw_circle(p, w * 1.5, Color(1.0, 0.95, 0.85, 0.8))
	var font := ThemeDB.fallback_font
	for f in floating:
		var fs := int(maxf(6.0, 22.0 / world.scale.x))
		var p: Vector2 = f.p + Vector2(0, -f.t * 20.0 / world.scale.x)
		var c := Color(1.0, 0.85, 0.3, clampf(1.6 - f.t, 0.0, 1.0))
		ci.draw_string_outline(font, p - Vector2(fs * 2.0, 0), str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 5), Color(0, 0, 0, c.a))
		ci.draw_string(font, p - Vector2(fs * 2.0, 0), str(f.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

# ---------- precipitation (screen space) ----------

func _reset_precip() -> void:
	precip.clear()
	var n := 0
	match str(pal.get("wx", "")):
		"snow":
			n = 110
		"rain":
			n = 150
		"storm":
			n = 220
		"dust":
			n = 40
	for i in n:
		precip.append(Vector3(randf() * 1600.0, randf() * 900.0, randf_range(0.5, 1.0)))

func _step_precip(delta: float) -> void:
	var s := size
	var wx: String = pal.get("wx", "")
	for i in precip.size():
		var p: Vector3 = precip[i]
		match wx:
			"snow":
				p.x += (engine.wind * 18.0 + sin(anim_t + i) * 10.0) * delta * p.z
				p.y += 40.0 * delta * p.z
			"rain", "storm":
				p.x += engine.wind * (40.0 if wx == "rain" else 70.0) * delta
				p.y += 900.0 * delta * p.z
			"dust":
				p.x += (engine.wind * 30.0 + 12.0) * delta * p.z
				p.y += sin(anim_t * 0.7 + i) * 6.0 * delta
		if p.y > s.y + 10.0:
			p.y = -10.0
			p.x = randf() * s.x
		if p.x > s.x + 10.0:
			p.x = -10.0
		elif p.x < -10.0:
			p.x = s.x + 10.0
		precip[i] = p

func _draw_precip() -> void:
	var wx: String = pal.get("wx", "")
	var scoped := zoom >= ZOOM_SCOPE and playing
	var a := 0.45 if scoped else 1.0
	var neon: bool = skin == "voodoo"
	var night: bool = pal.get("night", false)
	for p in precip:
		match wx:
			"snow":
				precip_layer.draw_circle(Vector2(p.x, p.y), 1.2 + p.z * 1.6, Color(1, 1, 1, (0.75 if not night else 0.45) * a) if not neon else Color("29e6ff", 0.6 * a))
			"rain", "storm":
				var v: Vector2 = Vector2(engine.wind * 0.04, 1.0).normalized() * 18.0 * p.z
				precip_layer.draw_line(Vector2(p.x, p.y), Vector2(p.x, p.y) + v, Color(0.7, 0.8, 0.95, (0.3 if not night else 0.2) * a) if not neon else Color("7dff3a", 0.35 * a), 1.2)
			"dust":
				precip_layer.draw_circle(Vector2(p.x, p.y), 1.0 + p.z, Color(0.95, 0.85, 0.65, 0.35 * a))
	if flash > 0.0:
		precip_layer.draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.85, 1.0, flash * 0.18))

func _update_rain_loop() -> void:
	if is_instance_valid(rain_loop):
		rain_loop.queue_free()
	rain_loop = null
	if pal.get("wx", "") in ["rain", "storm"] and playing:
		rain_loop = SoundLib.loop(self, "weather/thunder_rain", -14.0)

# ---------- the scope, reticle and HUD ----------

func _draw_reticle() -> void:
	if not playing or engine.over or briefing or not bcam.is_empty():
		return
	var c := _scope_center()
	if zoom < ZOOM_SCOPE:
		# Naked eye: a small ring where a tap will look.
		reticle.draw_arc(c, 10.0, 0, TAU, 24, Color(1, 1, 1, 0.5), 1.5)
		return
	var r := _scope_radius()
	var neon: bool = skin == "voodoo"
	var line := Color(0.02, 0.02, 0.02, 0.95) if not (pal.get("night", false) and skin == "classic") else Color(0.1, 0.3, 0.1, 0.95)
	if neon:
		line = Color("29e6ff")
	var dot: Color = [RED, Color("4dff6a")][int(prefs.get("reticle", 0))] if not neon else Color("ff2bd6")
	var mil := E.MIL * _scale()
	# Thick posts from the edge, thin wires in the middle.
	var inner := minf(r * 0.55, mil * 11.0)
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		reticle.draw_line(c + dir * inner, c + dir * r, line, 5.0)
		reticle.draw_line(c + dir * 3.0, c + dir * inner, line, 1.4)
	# Mil dots / hash marks (every 1 mil when there is room, else every 2 or 5).
	var every := 1 if mil >= 7.0 else (2 if mil >= 3.5 else 5)
	var m := every
	while m <= 10:
		var off := mil * m
		if off > inner:
			break
		var big := m % 5 == 0
		var ln := 7.0 if big else 4.0
		for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			var p: Vector2 = c + dir * off
			var side := Vector2(dir.y, dir.x)
			reticle.draw_line(p - side * ln, p + side * ln, line, 1.6 if big else 1.2)
		if big and mil * m < inner - 20.0:
			var font := ThemeDB.fallback_font
			reticle.draw_string(font, c + Vector2(10, mil * m + 5), str(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, line)
		m += every
	reticle.draw_circle(c, 2.6, dot)
	reticle.draw_circle(c, 5.0, Color(dot, 0.25))
	# The steady ring: tightens and turns green as the aim settles.
	var st: float = engine.steady()
	var ring_r := lerpf(34.0, 12.0, st)
	var ring_c := Color(1.0, 0.35, 0.25, 0.55).lerp(Color(0.35, 1.0, 0.45, 0.85), smoothstep(0.55, 0.85, st))
	reticle.draw_arc(c, ring_r, 0, TAU, 40, ring_c, 1.6, true)
	# Spotter help: where to hold for the chosen target.
	if spotter_t > 0.0:
		var tg := _spotter_target()
		if not tg.is_empty():
			var hold := _hold_point(tg)
			var sp := _world_to_screen(hold)
			if sp.distance_to(c) < r:
				var k := 7.0
				reticle.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -k), sp + Vector2(k, 0), sp + Vector2(0, k), sp + Vector2(-k, 0)]), Color(1.0, 0.15, 0.1, 0.9))
				reticle.draw_arc(sp, k + 4.0, 0, TAU, 20, Color(1, 1, 1, 0.7), 1.2)
	# Bolt cycling: the picture dips and a small label says so.
	if engine.bolt_t > 0.0 or engine.reload_t > 0.0:
		var font := ThemeDB.fallback_font
		var txt := tr("Reloading…") if engine.reload_t > 0.0 else tr("Bolt…")
		reticle.draw_string_outline(font, c + Vector2(-60, r * 0.62), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, 4, Color(0, 0, 0, 0.8))
		reticle.draw_string(font, c + Vector2(-60, r * 0.62), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(1, 0.9, 0.7))

func _spotter_target() -> Dictionary:
	var aim := _aim_world()
	if engine.goal == "convoy":
		for pr in engine.props:
			if pr.kind == "truck" and pr.state == "drive" and not pr.get("doomed", false):
				return pr
	var under: Dictionary = engine.target_at(aim)
	if not under.is_empty() and engine._live(under):
		return under
	for tg in engine.targets:
		if tg.primary and engine._live(tg):
			return tg
	var best := {}
	var bd := INF
	for tg in engine.targets:
		if engine._live(tg):
			var dd: float = engine.target_pos(tg).distance_to(aim)
			if dd < bd:
				bd = dd
				best = tg
	return best

## Where to put the reticle so the bullet meets the chest (drop, wind, lead).
func _hold_point(tg: Dictionary) -> Vector2:
	var d: float = tg.d
	if tg.get("kind", "") == "truck":
		var foot: Vector2 = engine.truck_pos(tg, E.tof(d))
		var tank: Rect2 = engine.truck_spots(tg, foot)[0]
		return tank.get_center() - engine.impact_mils(d, d) * E.MIL
	var chest: Vector2 = engine.target_pos(tg, E.tof(d)) + Vector2(0, -1.25 * E.upm(d))
	return chest - engine.impact_mils(d, d) * E.MIL

func _lased_range() -> float:
	return engine.range_at(_aim_world())

func _draw_hud() -> void:
	if not playing or briefing:
		return
	if not bcam.is_empty():
		# Letterbox bars and a quiet label: the bullet cam.
		var bar := size.y * 0.1
		hud.draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, 0.85))
		hud.draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.85))
		_text(ThemeDB.fallback_font, Vector2(28, size.y - bar * 0.35), tr("BULLET CAM · tap to skip"), 16, Color(1, 1, 1, 0.6))
		_text_r(ThemeDB.fallback_font, Vector2(size.x - 28, size.y - bar * 0.35), "%d m" % int(bcam.d), 18, Color(1, 0.85, 0.6, 0.9))
		return
	var s := size
	var font := ThemeDB.fallback_font
	var white := Color(1, 1, 1, 0.92)
	var dim := Color(1, 1, 1, 0.6)
	var x0 := 28.0
	var y0 := 30.0
	# Top left: the job.
	var title := _job_title()
	_text(font, Vector2(x0, y0 + 18), title, 20, white)
	var left_n: int = engine.targets_left()
	var line2 := (tr("Through: %d / 3") % engine.escapes) if engine.mode == "survival" else _goal_line(left_n)
	_text(font, Vector2(x0, y0 + 46), line2 + "   " + tr("Score %d") % engine.score, 18, dim)
	if engine.limit > 0.0 and engine.mode != "survival":
		var tl: float = engine.time_left()
		var urgent := tl < 15.0
		var clock := "⏱ %d:%02d" % [int(tl) / 60, int(tl) % 60]
		_text_c(font, Vector2(s.x * 0.5, 120 if banner_t <= 0.0 else 168), clock, 30 if urgent else 24, RED if urgent and fmod(anim_t, 0.6) < 0.3 else white)
	# Alarm bar.
	if engine.mode != "survival":
		var bar := Rect2(x0, y0 + 58, 180, 8)
		hud.draw_rect(bar, Color(1, 1, 1, 0.15))
		hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * engine.alarm / 100.0, bar.size.y)), Color(1.0, 0.75, 0.2).lerp(RED, engine.alarm / 100.0))
		_text(font, Vector2(x0 + 190, y0 + 67), tr("ALARM") if engine.dish_quiet_t <= 0.0 else tr("DISH DOWN"), 13, dim)
	# Top right: wind, range, rounds.
	var xr := s.x - 30.0
	var w: float = engine.wind
	var arrow_c := Vector2(xr - 150, y0 + 14)
	var dir := 1.0 if w >= 0.0 else -1.0
	var len_ := 18.0 + absf(w) * 5.0
	hud.draw_line(arrow_c - Vector2(len_ * 0.5 * dir, 0), arrow_c + Vector2(len_ * 0.5 * dir, 0), white, 3.0)
	hud.draw_colored_polygon(PackedVector2Array([arrow_c + Vector2(len_ * 0.5 * dir + 8 * dir, 0), arrow_c + Vector2(len_ * 0.5 * dir, -6), arrow_c + Vector2(len_ * 0.5 * dir, 6)]), white)
	_text_r(font, Vector2(xr, y0 + 20), tr("Wind %.1f m/s") % absf(w) if level > 0 else tr("Wind: off (Easy)"), 18, white)
	var lr := _lased_range()
	var rng_txt := tr("Range %d m") % int(round(lr)) if lr > 1.0 and zoom >= ZOOM_SCOPE else tr("Range —")
	_text_r(font, Vector2(xr, y0 + 46), rng_txt, 18, white)
	if level == 2 and zoom >= ZOOM_SCOPE and lr > 1.0:
		_text_r(font, Vector2(xr, y0 + 70), tr("Drop %.1f mil") % E.drop_mils(lr), 16, dim)
	elif level == 1 and zoom >= ZOOM_SCOPE and lr > 1.0:
		_text_r(font, Vector2(xr, y0 + 70), tr("Scope set for %d m") % int(round(lr)), 16, dim)
	# Rounds: the magazine as cartridges, the rest as a number.
	var ry := s.y - 44.0
	var rx := 150.0 if not prefs.get("left", false) else s.x - 330.0
	for i in E.MAG:
		var full: bool = i < engine.mag
		var r := Rect2(rx + i * 18, ry - 30, 9, 30)
		hud.draw_rect(Rect2(r.position + Vector2(0, 8), Vector2(9, 22)), Color(0.85, 0.65, 0.25, 0.95) if full else Color(1, 1, 1, 0.12))
		hud.draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(5, 9)), Color(0.75, 0.55, 0.3, 0.95) if full else Color(1, 1, 1, 0.08))
	var spare := "∞" if engine.ammo < 0 else str(maxi(0, engine.ammo - engine.mag))
	_text(font, Vector2(rx + E.MAG * 18 + 8, ry - 6), "+ " + spare, 18, dim)
	# Bottom left: the breath and the heart.
	_draw_breath(Vector2(s.x - 78.0 if prefs.get("left", false) else 78.0, s.y - 78))  # opposite the hold button
	# Zoom readout by the slider.
	if zoom_slider.visible:
		_text(font, zoom_slider.position + Vector2(-6, -12), "%.1f×" % zoom_target, 16, white)
	# Banner (officer down, ran for it...).
	if banner_t > 0.0:
		var a := clampf(banner_t, 0.0, 1.0)
		var bw := 640.0
		hud.draw_rect(Rect2(s.x * 0.5 - bw * 0.5, 96, bw, 44), Color(0, 0, 0, 0.55 * a))
		hud.draw_string_outline(font, Vector2(s.x * 0.5 - bw * 0.5, 126), banner, HORIZONTAL_ALIGNMENT_CENTER, bw, 24, 6, Color(0, 0, 0, a))
		hud.draw_string(font, Vector2(s.x * 0.5 - bw * 0.5, 126), banner, HORIZONTAL_ALIGNMENT_CENTER, bw, 24, Color(1.0, 0.85, 0.75, a))

func _goal_line(left_n: int) -> String:
	match engine.goal:
		"convoy":
			return tr("Trucks: %d to stop") % engine.trucks_left() + "  ·  " + tr("Targets: %d left") % left_n
		"officer":
			return tr("Goal: the officer") + "  ·  " + tr("Targets: %d left") % left_n
		_:
			return tr("Goal: everyone") + "  ·  " + tr("Targets: %d left") % left_n

func _job_title() -> String:
	var place: String = tr(E.LOC_NAMES[engine.loc])
	match engine.mode:
		"survival":
			return tr("♾ Survival · %s") % place
		"daily":
			return tr("📅 Daily · %s") % place
	return tr("Contract %d · %s") % [engine.contract + 1, place]

## The breath gauge: a ring that fills with the breath; its green arc is the pause
## (the steady moment). Holding: a countdown ring. The heart rate under it.
func _draw_breath(c: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var r := 34.0
	hud.draw_circle(c, r + 8.0, Color(0, 0, 0, 0.45))
	var start := -PI * 0.5
	hud.draw_arc(c, r, start + TAU * E.BREATH_MOVE, start + TAU, 24, Color(0.35, 1.0, 0.45, 0.55), 6.0)
	hud.draw_arc(c, r, start, start + TAU * E.BREATH_MOVE, 32, Color(1, 1, 1, 0.18), 6.0)
	if engine.holding:
		var left: float = 1.0 - engine.hold_t / E.HOLD_MAX
		var col := Color(0.35, 0.8, 1.0) if engine.hold_t < E.HOLD_GOOD else Color(1.0, 0.5, 0.3)
		hud.draw_arc(c, r - 10.0, start, start + TAU * left, 32, col, 5.0)
		_text_c(font, c + Vector2(0, 6), "%.1f" % (E.HOLD_MAX - engine.hold_t), 16, col)
	else:
		var a: float = start + TAU * engine.breath_phase()
		hud.draw_circle(c + Vector2(cos(a), sin(a)) * r, 6.0, Color(1, 1, 1))
		var st: float = engine.steady()
		var txt := tr("STEADY") if st >= 0.8 else (tr("GASP") if engine.gasp_t > 0.0 else "")
		if txt != "":
			_text_c(font, c + Vector2(0, 6), txt, 13, Color(0.4, 1.0, 0.5) if st >= 0.8 else Color(1.0, 0.5, 0.3))
	var beat := fposmod(engine.t * engine.heart / 60.0, 1.0)
	var hk := 1.0 + exp(-beat * 10.0) * 0.25
	var hx := r + 18.0 if c.x < size.x * 0.5 else -(r + 80.0)
	_text(font, c + Vector2(hx, -24), "♥ %d" % int(engine.heart), int(18 * hk), Color(1.0, 0.45, 0.45, 0.9))

func _text(font: Font, p: Vector2, t: String, fs: int, col: Color) -> void:
	hud.draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.7 * col.a))
	hud.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _text_r(font: Font, p: Vector2, t: String, fs: int, col: Color) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(font, p - Vector2(w, 0), t, fs, col)

func _text_c(font: Font, p: Vector2, t: String, fs: int, col: Color) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(font, p - Vector2(w * 0.5, 0), t, fs, col)

# ---------- the Landing ----------

## The Landing's hero art: the live valley, full-screen behind the menu, letterboxed (S7).
func _draw_landing_scene(c: Control) -> void:
	_landing_logo = c
	if vp == null:
		return
	c.draw_set_transform_matrix(c.get_global_transform().affine_inverse())
	var s := get_viewport_rect().size
	c.draw_texture_rect(vp.get_texture(), Rect2(Vector2.ZERO, s), false)
	# Darken the left, where the title and rows sit.
	c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x * 0.62, 0), Vector2(s.x * 0.62, s.y), Vector2(0, s.y)]),
		PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.75)]))
	var bar := s.y * (0.11 if s.x > s.y else 0.06)
	c.draw_rect(Rect2(0, 0, s.x, bar), Color.BLACK)
	c.draw_rect(Rect2(0, s.y - bar, s.x, bar), Color.BLACK)
	# A faint scope circle drifting over the valley.
	var sc := Vector2(s.x * 0.72 + sin(anim_t * 0.3) * 40.0, s.y * 0.5 + cos(anim_t * 0.23) * 20.0)
	var rr := s.y * 0.22
	c.draw_arc(sc, rr, 0, TAU, 64, Color(1, 1, 1, 0.22), 2.0, true)
	c.draw_line(sc - Vector2(rr, 0), sc + Vector2(rr, 0), Color(1, 1, 1, 0.16), 1.0)
	c.draw_line(sc - Vector2(0, rr), sc + Vector2(0, rr), Color(1, 1, 1, 0.16), 1.0)
	c.draw_circle(sc, 3.0, Color(RED, 0.8))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _frame_landing() -> void:
	zoom = 1.0
	zoom_target = 1.0
	cam = Vector2(E.W * 0.5, E.H * 0.58)
	_apply_camera()

func _add_setup(body: VBoxContainer) -> void:
	body.add_child(home.section("Difficulty"))
	body.add_child(home.choice_row(E.LEVELS, level, _pick_level))
	body.add_child(HomeKit.label(tr(["Easy: no bullet drop, no wind, a slower officer.", "Normal: the scope sets itself for the range under the reticle; you allow for the wind.", "Hard: you allow for drop and wind yourself, with the reticle's mil marks."][level]), 20, HomeKit.DIM, true))

func _pick_level(i: int) -> void:
	level = clampi(i, 0, 2)
	prefs["level"] = level
	SaveUtil.write(PREFS_PATH, prefs)

func _add_game_options(body: VBoxContainer) -> void:
	body.add_child(home.section("Hit effect"))
	body.add_child(home.choice_row(["Red mist", "Dust"], int(prefs.get("effect", 0)), _pick_pref.bind("effect")))
	body.add_child(home.section("Reticle dot"))
	body.add_child(home.choice_row(["Red", "Green"], int(prefs.get("reticle", 0)), _pick_pref.bind("reticle")))
	body.add_child(home.section("Bullet cam"))
	body.add_child(home.choice_row(["On", "Off"], int(prefs.get("bulletcam", 0)), _pick_pref.bind("bulletcam")))
	body.add_child(home.section("Look up / down (drag, stick, keys)"))
	body.add_child(home.choice_row(["Normal", "Inverted"], int(prefs.get("invy", 0)), _pick_pref.bind("invy")))
	body.add_child(home.section("Hold button and zoom"))
	body.add_child(home.choice_row(["Right hand", "Left hand"], 1 if prefs.get("left", false) else 0, _pick_hand))

func _pick_pref(i: int, key: String) -> void:
	prefs[key] = i
	SaveUtil.write(PREFS_PATH, prefs)

## Look-Y option: Normal (drag the world, push the stick to look that way) or Inverted.
func _ysign() -> float:
	return -1.0 if int(prefs.get("invy", 0)) == 1 else 1.0

func _pick_hand(i: int) -> void:
	prefs["left"] = i == 1
	SaveUtil.write(PREFS_PATH, prefs)
	_layout_controls()

## Skins (STANDARDS §9): Classic = each place's natural light; Skull mode = neon on black.
func _set_skin(name_: String) -> void:
	skin = "voodoo" if name_ == "voodoo" else "classic"
	if engine:
		_build_world()

# ---------- Contracts card ----------

const GOAL_ICON := {"officer": "🎖", "all": "👥", "timed": "⏱", "convoy": "🚚"}
const TOD_ICON := {"dawn": "🌅", "day": "☀", "dusk": "🌇", "night": "🌙"}
const WX_ICON := {"clear": "🌤", "fog": "🌫", "snow": "❄", "rain": "🌧", "dust": "💨", "storm": "⛈"}

func _open_contracts() -> void:
	var parts: Array = home.card("🗺 Contracts")
	var body: VBoxContainer = parts[1]
	body.add_child(home.section("Difficulty"))
	body.add_child(home.choice_row(E.LEVELS, level, _pick_level))
	var total := 0
	for k in progress.stars:
		total += int(progress.stars[k])
	body.add_child(HomeKit.label(tr("Stars: %d / %d") % [total, E.CONTRACTS.size() * 3], 22, HomeKit.DIM))
	body.add_child(HomeKit.label(tr("🎖 the officer · 👥 everyone · ⏱ against the clock · 🚚 stop the trucks"), 18, HomeKit.DIM, true))
	for ch in E.LOCATIONS.size():
		var first := ch * E.PER_PLACE
		var open_ch := first <= int(progress.reached)
		body.add_child(home.section(tr(E.LOC_NAMES[E.LOCATIONS[ch]]) + ("" if open_ch else "  🔒")))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		body.add_child(grid)
		for i in range(first, first + E.PER_PLACE):
			var c := E.contract_def(i)
			var open: bool = i <= int(progress.reached)
			var st := int(progress.stars.get(str(i), 0))
			var txt := "%d  %s%s%s\n%s" % [i + 1, GOAL_ICON[c.goal], TOD_ICON[c.tod], "" if c.wx == "clear" else WX_ICON[c.wx], ("★".repeat(st) + "☆".repeat(3 - st)) if open else "🔒"]
			var b := HomeKit.neon_button(txt, HomeKit.BUTTON, 18, 78)
			b.custom_minimum_size.x = 132
			b.disabled = not open
			b.pressed.connect(_pick_contract.bind(i, parts[0]))
			grid.add_child(b)
	home.show_card(parts[0])

func _pick_contract(i: int, card: Control) -> void:
	home.close_card(card)
	home.play_now(_start_contract.bind(i))

# ---------- Armory ----------

func _open_armory() -> void:
	var parts: Array = home.card("🛠 Armory")
	_fill_armory(parts)
	home.show_card(parts[0])

func _fill_armory(parts: Array) -> void:
	var body: VBoxContainer = parts[1]
	for ch in body.get_children():
		ch.queue_free()
	body.add_child(HomeKit.label(tr("Cash: %d") % int(progress.cash), 28, Color("ffd36a"), false, true))
	body.add_child(HomeKit.label(tr("Win contracts to get paid: a third of the score, half on a first win. Survival pays too."), 18, HomeKit.DIM, true, true))
	for key in ["scope", "bipod", "bolt", "supp"]:
		var u: Dictionary = E.UPGRADES[key]
		var lv := clampi(int(progress.kit.get(key, 0)), 0, 3)
		body.add_child(home.section(str(u.name)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var info_l := HomeKit.label(tr(str(u.what)) + "\n" + "■".repeat(lv) + "□".repeat(3 - lv) + "  " + _upgrade_value(key, lv), 20, Color(1, 1, 1, 0.85), true)
		info_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info_l)
		var b: Button
		if lv >= 3:
			b = HomeKit.neon_button(tr("Maxed"), HomeKit.BUTTON, 20, 58)
			b.disabled = true
		else:
			var cost := int(u.cost[lv])
			b = HomeKit.neon_button(tr("Buy · %d") % cost, HomeKit.GO if int(progress.cash) >= cost else HomeKit.BUTTON, 20, 58)
			b.disabled = int(progress.cash) < cost
			b.pressed.connect(_buy.bind(key, parts))
		b.custom_minimum_size.x = 170
		row.add_child(b)
		body.add_child(row)

func _upgrade_value(key: String, lv: int) -> String:
	var u: Dictionary = E.UPGRADES[key]
	match key:
		"scope":
			return tr("up to %dx") % int(u.zoom[lv])
		"bipod":
			return tr("sway %d%%") % int(round(float(u.sway[lv]) * 100.0))
		"bolt":
			return tr("bolt %.2f s") % float(u.bolt[lv])
	return tr("alarm per shot %d%%") % int(round(float(u.alarm[lv]) * 100.0))

func _buy(key: String, parts: Array) -> void:
	var lv := clampi(int(progress.kit.get(key, 0)), 0, 3)
	if lv >= 3:
		return
	var cost := int(E.UPGRADES[key].cost[lv])
	if int(progress.cash) < cost:
		return
	progress.cash = int(progress.cash) - cost
	progress.kit[key] = lv + 1
	_save_progress()
	engine.set_kit(progress.kit)
	SoundLib.play(self, "rpg/metal_latch", -6.0)
	_fill_armory(parts)

# ---------- the rifle in view ----------

## Naked eye: the rifle lies along the bottom right, on its bipod, pointing in;
## it kicks back when fired. Muzzle smoke drifts off with the wind (also seen
## at the bottom of the scope).
func _draw_rifle() -> void:
	if not playing or briefing or not bcam.is_empty():
		return
	var s := size
	var scoped := zoom >= ZOOM_SCOPE
	var left: bool = prefs.get("left", false)
	var sx := -1.0 if left else 1.0
	var tint: Color = pal.get("tint", Color.WHITE)
	if not scoped:
		var kick := recoil * 26.0
		var base := Vector2(s.x * 0.5 + sx * s.x * 0.36, s.y + 30.0)
		var tip := Vector2(s.x * 0.5 + sx * s.x * 0.06, s.y * 0.66)
		var dir := (tip - base).normalized()
		var n := dir.orthogonal()
		base -= dir * kick
		tip -= dir * kick
		var dark := Color(0.09, 0.09, 0.1) * Color(tint, 1.0)
		var mid := Color(0.18, 0.18, 0.2) * Color(tint, 1.0)
		var len_ := base.distance_to(tip)
		var at := func(f: float, off: float) -> Vector2: return base + dir * len_ * f + n * off
		# Bipod legs down to the ground, then stock, body, barrel, scope.
		var leg: Vector2 = at.call(0.62, 0.0)
		rifle_layer.draw_line(leg, leg + Vector2(-sx * 26.0, 70.0), dark, 6.0)
		rifle_layer.draw_line(leg, leg + Vector2(sx * 22.0, 74.0), dark, 6.0)
		rifle_layer.draw_colored_polygon(PackedVector2Array([at.call(0.0, -34.0), at.call(0.0, 34.0), at.call(0.32, 16.0), at.call(0.32, -12.0)]), mid)
		rifle_layer.draw_colored_polygon(PackedVector2Array([at.call(0.28, -14.0), at.call(0.28, 16.0), at.call(0.7, 10.0), at.call(0.7, -9.0)]), dark)
		rifle_layer.draw_line(at.call(0.68, 0.0), tip, dark, 9.0)
		rifle_layer.draw_line(at.call(0.96, 0.0), tip, Color(0.05, 0.05, 0.05) * Color(tint, 1.0), 13.0)  # muzzle brake
		rifle_layer.draw_colored_polygon(PackedVector2Array([at.call(0.3, -16.0), at.call(0.3, -42.0), at.call(0.62, -36.0), at.call(0.62, -14.0)]), mid)
		rifle_layer.draw_circle(at.call(0.3, -29.0), 15.0, dark)
		rifle_layer.draw_circle(at.call(0.62, -25.0), 12.0, dark)
		rifle_layer.draw_line(at.call(0.33, -40.0), at.call(0.6, -35.0), Color(1, 1, 1, 0.12), 3.0)
		# A gloved hand on the grip.
		rifle_layer.draw_circle(at.call(0.22, 26.0), 20.0, Color(0.16, 0.14, 0.12) * Color(tint, 1.0))
		if skin == "voodoo":
			rifle_layer.draw_polyline(PackedVector2Array([at.call(0.0, -34.0), at.call(0.3, -42.0), at.call(0.62, -36.0), tip]), Color("29e6ff"), 2.0)
		_draw_smoke(tip)
	else:
		_draw_smoke(Vector2(s.x * 0.5, s.y * 0.5 + _scope_radius() * 0.95))

func _draw_smoke(origin: Vector2) -> void:
	for sm in smoke:
		var k: float = sm.t / 1.6
		var p: Vector2 = origin + sm.p + sm.v * sm.t
		rifle_layer.draw_circle(p, 10.0 + k * 40.0, Color(0.85, 0.85, 0.85, 0.22 * (1.0 - k)))

# ---------- flow ----------

func _start_next_contract() -> void:
	if not progress.get("tut_done", false) and int(progress.reached) == 0:
		_start_tutorial()
		return
	_start_contract(mini(int(progress.reached), E.CONTRACTS.size() - 1))

func _start_contract(i: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset("contract", level, i)
	_begin()

func _start_survival() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset("survival", level, 0, randi() % 100000 + 1, _survival_place())
	_begin()

## Survival is played in one of the places the contracts have opened.
func _survival_place() -> String:
	var open := E.chapter_of(int(progress.reached)) + 1
	return E.LOCATIONS[randi() % clampi(open, 1, E.LOCATIONS.size())]

func _start_daily() -> void:
	SaveUtil.delete(SAVE_PATH)
	var dt := Time.get_date_dict_from_system()
	var seed := int(dt.year) * 10000 + int(dt.month) * 100 + int(dt.day)
	engine.reset("daily", level, 0, seed)
	_begin()

func _retry() -> void:
	SaveUtil.delete(SAVE_PATH)
	match engine.mode:
		"survival":
			engine.reset("survival", level, 0, randi() % 100000 + 1, engine.loc)
		"daily":
			engine.reset("daily", level, 0, engine.seed_used)
		_:
			engine.reset("contract", level, engine.contract)
	_begin()

func _next_contract() -> void:
	if engine.mode != "contract":
		_retry()
		return
	_start_contract(mini(engine.contract + 1, E.CONTRACTS.size() - 1))

func _begin() -> void:
	if not tutorial:
		level = int(prefs.get("level", 1))
	end_dialog.visible = false
	results_chip.visible = false
	result_shown = false
	playing = true
	recoil = 0.0
	spotter_t = 0.0
	engine.hold_breath(false)
	engine.set_kit(progress.kit)
	zoom_slider.max_value = _zoom_max()
	bcam = {}
	smoke.clear()
	_build_world()
	zoom = 1.0
	zoom_target = 1.0
	cam = Vector2(E.W * 0.5, E.H * 0.62)
	_apply_camera()
	if info and info.has_method("start_clock"):
		info.start_clock()
	if tutorial:
		_coach_show(0)
	else:
		_briefing()
	_music("play", "calm")

const TOD_NAMES := {"dawn": "Dawn", "day": "Day", "dusk": "Dusk", "night": "Night"}
const WX_NAMES := {"clear": "Clear", "fog": "Fog", "snow": "Snow", "rain": "Rain", "dust": "Dust", "storm": "Storm"}

func _briefing() -> void:
	var lines := ""
	if engine.mode == "survival":
		lines = tr("Stop anyone crossing the valley. Three get through and it's over.")
	else:
		match engine.goal:
			"all":
				lines = tr("Take them all down. Nobody may get away. %d targets, %d rounds.") % [engine.count_targets(), engine.ammo]
			"timed":
				lines = tr("Take them all down before the clock runs out: %d seconds. %d targets, %d rounds.") % [int(engine.limit), engine.count_targets(), engine.ammo]
			"convoy":
				lines = tr("Stop the trucks before they leave: shoot the striped fuel tank, or the driver through the cab window. %d rounds.") % engine.ammo
			_:
				lines = tr("Take down the officer (red armband) before he runs. %d targets, %d rounds.") % [engine.count_targets(), engine.ammo]
	var civ := 0
	for tg in engine.targets:
		if tg.civ:
			civ += 1
	if civ > 0:
		lines += "\n" + tr("Civilians in hi-vis vests are about: don't hit them.")
	var wind_txt := tr("No wind (Easy).")
	if level > 0:
		wind_txt = tr("Calm.") if absf(engine.wind) < 0.5 else (tr("Wind %.1f m/s from the left.") if engine.wind > 0.0 else tr("Wind %.1f m/s from the right.")) % absf(engine.wind)
		if engine.gust > 1.3:
			wind_txt += " " + tr("Gusty.")
	brief_title.text = _job_title()
	brief_sub.text = "%s %s  ·  %s %s  ·  %s" % [TOD_ICON[engine.tod], tr(TOD_NAMES[engine.tod]), WX_ICON[engine.wx], tr(WX_NAMES[engine.wx]), tr(E.LEVELS[level])]
	brief_text.text = lines + "\n" + wind_txt
	if engine.mode == "contract":
		var st := int(progress.stars.get(str(engine.contract), 0))
		if st > 0:
			brief_text.text += "\n" + tr("Your best: %s") % ("★".repeat(st) + "☆".repeat(3 - st))
	brief_panel.visible = true
	briefing = true

func _on_begin() -> void:
	brief_panel.visible = false
	briefing = false
	_wind_sound(true)
	_hint(tr("Pinch (or tap) to look through the scope."), 3.5)

func _on_pause() -> void:
	engine.hold_breath(false)
	home.pause()

func _go_home() -> void:
	_tut_end()
	home.go_home()

func _see_valley() -> void:
	end_dialog.visible = false
	results_chip.visible = true

func _show_results_again() -> void:
	results_chip.visible = false
	end_dialog.visible = true

func _show_result() -> void:
	result_shown = true
	playing = false
	_wind_sound(false)
	engine.hold_breath(false)
	SaveUtil.delete(SAVE_PATH)
	zoom_target = 1.0
	zoom = 1.0
	_update_rain_loop()
	var won: bool = engine.won
	var lines: Array = []
	lines.append(tr("Score: %d") % engine.score)
	if engine.mode == "survival":
		lines.append(tr("Targets down: %d") % engine.kills)
	else:
		lines.append(tr("Targets down: %d of %d") % [engine.kills, engine.count_targets()])
		if engine.trucks_total() > 0:
			lines.append(tr("Trucks stopped: %d of %d") % [engine.stopped, engine.trucks_total()])
	lines.append(tr("Accuracy: %d%%") % int(round(engine.accuracy() * 100.0)))
	if engine.heads > 0:
		lines.append(tr("Headshots: %d") % engine.heads)
	if engine.longest > 0.0:
		lines.append(tr("Longest shot: %d m") % int(engine.longest))
	var stars := 0
	match engine.mode:
		"survival":
			end_title.text = tr("RUN OVER")
			end_title.add_theme_color_override("font_color", ACCENT)
		_:
			stars = engine.stars()
			end_title.text = tr("CONTRACT COMPLETE") if won else tr("CONTRACT FAILED")
			end_title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if won else ACCENT)
			if won:
				lines.insert(0, "★".repeat(stars) + "☆".repeat(3 - stars))
			else:
				lines.insert(0, _fail_text())
	cash_won = _pay(won)
	if cash_won > 0:
		lines.append(tr("Pay: +%d") % cash_won + "  ·  " + tr("Cash: %d") % int(progress.cash))
	end_msg.text = "\n".join(lines)
	next_btn.visible = engine.mode == "contract" and won and engine.contract < E.CONTRACTS.size() - 1
	_record(won, stars)
	end_dialog.visible = true
	_music("stop", "")
	SoundLib.play(self, "jingles/win_succeeded" if won else "jingles/lose_failed", -6.0)

func _fail_text() -> String:
	match engine.reason:
		"civilian":
			return tr("You hit a civilian.")
		"time":
			return tr("Time ran out.")
		"convoy":
			return tr("A truck got away.")
		"escaped":
			return tr("The officer got away.") if engine.goal == "officer" else tr("One of them got away.")
	return tr("Out of rounds.")

## Cash for the Armory: a won contract pays a third of its score (half on a first
## win), a survival run a sixth of its score.
func _pay(won: bool) -> int:
	var c := 0
	match engine.mode:
		"survival":
			c = engine.score / 6
		_:
			if won:
				var first: bool = engine.mode == "contract" and int(progress.stars.get(str(engine.contract), 0)) == 0
				c = engine.score / (2 if first else 3)
	progress.cash = int(progress.get("cash", 0)) + c
	_save_progress()
	return c

func _record(won: bool, stars: int) -> void:
	if engine.mode == "contract" and won:
		var key := str(engine.contract)
		progress.stars[key] = maxi(int(progress.stars.get(key, 0)), stars)
		progress.reached = maxi(int(progress.reached), mini(engine.contract + 1, E.CONTRACTS.size() - 1))
		if engine.contract == E.CONTRACTS.size() - 1:
			progress["all_done"] = true
		_save_progress()
	if info == null:
		return
	info.add("Games played")
	if engine.kills > 0:
		info.add("Targets down", engine.kills)
	if engine.heads > 0:
		info.add("Headshots", engine.heads)
	if engine.stopped > 0:
		info.add("Trucks stopped", engine.stopped)
	if engine.longest > 0.0:
		info.high("Longest shot (m)", int(engine.longest))
	info.best("Best score", engine.score)
	match engine.mode:
		"survival":
			info.best("Survival best", engine.score)
		"daily":
			info.result("win" if won else "loss")
		_:
			info.result("win" if won else "loss")
			var done := 0
			var total := 0
			for k in progress.stars:
				if int(progress.stars[k]) > 0:
					done += 1
				total += int(progress.stars[k])
			info.high("Contracts done", done)
			info.high("Contract stars", total)
			if won and stars == 3:
				info.add("Perfect contracts")
	if won and info.has_method("celebrate"):
		info.celebrate(tr("Contract complete!"))

# ---------- shooting ----------

func _fire() -> void:
	if not playing or engine.over:
		return
	if zoom < ZOOM_SCOPE:
		return
	if not engine.can_fire():
		if engine.ammo == 0 and engine.mag <= 0:
			_hint(tr("Out of rounds"), 1.5)
		return
	var aim := _aim_world()
	var lased := _lased_range()
	var r: Dictionary = engine.fire(aim, lased)
	if r.is_empty():
		return
	recoil = 1.0
	shake = 0.6
	birds_scatter = 1.0 if int(progress.kit.get("supp", 0)) < 2 else 0.5
	_play_shot()
	for k in 7:
		smoke.append({"p": Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0)), "v": Vector2(randf_range(-30.0, 30.0) + engine.wind * 25.0, randf_range(-70.0, -30.0)), "t": 0.0})
	if _bullet_cam_worthy(r):
		bcam = {"from": aim, "to": r.impact, "tof": float(r.tof), "t": 0.0, "id": int(r.id), "d": float(r.d),
			"z0": zoom, "zs": maxf(ZOOM_MIN, zoom * 0.55), "z1": clampf(0.42 * size.y / (1.8 * E.upm(float(r.d)) * _base_scale()), zoom, 60.0), "cam0": cam, "hold": -1.0}
	get_tree().create_timer(0.45, false).timeout.connect(_bolt_sound)
	_vibrate(45)
	if tutorial:
		tut_fired = true
	tracers.append({"from": aim + Vector2(0, 30.0 * E.MIL), "to": r.impact, "t": 0.0, "tof": float(r.tof)})
	if r.kind == "miss" and float(r.d) > 0.0:
		get_tree().create_timer(float(r.tof), false).timeout.connect(_add_effect.bind("puff", r.impact, float(r.d), 0.9))
		if r.get("blocked", false):
			_float_text(tr("Blocked"), r.impact)
			get_tree().create_timer(float(r.tof), false).timeout.connect(func(): SoundLib.play(self, "impact/wood_medium", -10.0))
	if engine.ammo == 0 and engine.mag <= 0:
		_hint(tr("Last round fired"), 1.5)
	elif engine.mag <= 0:
		_hint(tr("Reloading…"), 1.2)

## Headshots, long shots (500 m and more), the officer, and the shot that
## finishes a contract ride the bullet in, unless Options turned it off.
func _bullet_cam_worthy(r: Dictionary) -> bool:
	if int(prefs.get("bulletcam", 0)) == 1 or r.get("kind", "") != "target":
		return false
	var tg := _target(int(r.id))
	return bool(r.head) or float(r.d) >= 500.0 or bool(tg.get("primary", false)) or engine.targets_left() == 0

func _bolt_sound() -> void:
	SoundLib.play(self, "rpg/metal_latch", -10.0)
	get_tree().create_timer(0.25, false).timeout.connect(func(): SoundLib.play(self, "rpg/metal_click", -10.0))

## The rifle report, made in code (0 bytes): a crack, a thump and the valley's echo.
func _play_shot() -> void:
	var sfx = get_node_or_null("/root/Sfx")
	if sfx == null or not sfx.has_method("play_stream"):
		return
	if shot_sound == null:
		shot_sound = _make_shot()
	var supp := int(progress.kit.get("supp", 0))
	sfx.play_stream(shot_sound, -4.0 - supp * 4.0, randf_range(0.95, 1.05) - supp * 0.08, "game")

## The game's own sounds, synthesized once (no files; the approach and the recipes
## come from The Hunt): a rifle crack with three valley echoes, a heartbeat, a breath
## and a wind loop. The shared library has no gunshot.
static func _make_shot() -> AudioStreamWAV:
	var rate := 22050
	var r := RandomNumberGenerator.new()
	r.seed = 77
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
	return _wav(buf, rate)

static func _make_beat() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.5)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var tt := float(i) / rate
		var v := sin(tt * TAU * 48.0) * exp(-tt * 28.0)
		if tt > 0.16:
			v += 0.7 * sin((tt - 0.16) * TAU * 44.0) * exp(-(tt - 0.16) * 30.0)
		buf[i] = v * 0.9
	return _wav(buf, rate)

static func _make_breath() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.7)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 78
	var lp := 0.0
	for i in n:
		var tt := float(i) / rate
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.25
		buf[i] = lp * sin(PI * tt / 0.7) * 0.8
	return _wav(buf, rate)

static func _make_wind() -> AudioStreamWAV:
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
		buf[i] = lp * (0.6 + 0.4 * sin(tt * TAU * 0.25)) * 2.5  # gusts that loop in whole cycles
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

func _play(stream: AudioStream, db: float, pitch: float = 1.0) -> void:
	var sfx = get_node_or_null("/root/Sfx")
	if sfx and stream and sfx.has_method("play_stream"):
		sfx.play_stream(stream, db, pitch, "game")

## The heart you can hear while holding your breath (or racing after shots), the
## breath let out after a gasp.
func _body_sounds() -> void:
	if not playing or briefing or not bcam.is_empty() or engine.over:
		return
	if snd_beat == null:
		snd_beat = _make_beat()
		snd_breath = _make_breath()
	var beat := fposmod(engine.t * engine.heart / 60.0, 1.0)
	if beat < last_beat and (engine.holding or engine.heart > 95.0):
		_play(snd_beat, -16.0 if engine.holding else -20.0)
	last_beat = beat
	if engine.gasp_t > 0.0 and not was_gasping:
		_play(snd_breath, -10.0, 0.9)
	was_gasping = engine.gasp_t > 0.0

## A wind loop, louder in stronger wind (made once, from The Hunt's recipe).
func _wind_sound(on: bool) -> void:
	if is_instance_valid(wind_player):
		wind_player.queue_free()
	wind_player = null
	if not on or get_node_or_null("/root/Sfx") == null:
		return
	var db := -28.0
	var settings = get_node_or_null("/root/Settings")
	if settings and settings.has_method("group_db"):
		var extra = settings.group_db("game")
		if extra == null:
			return
		db += float(extra)
	wind_player = AudioStreamPlayer.new()
	wind_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	wind_player.stream = _make_wind()
	wind_player.volume_db = db + absf(engine.wind) * 1.0
	add_child(wind_player)
	wind_player.play()

func _vibrate(ms: int) -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(ms)

func _music(what: String, style: String) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	if what == "play":
		m.play(style, self, 1, 2.0)
	elif m.has_method("stop"):
		m.stop(1.5)

# ---------- input ----------

func _on_hold(on: bool) -> void:
	if playing:
		engine.hold_breath(on)

## The scope's top zoom: 12x, more with the Armory's scope upgrades.
func _zoom_max() -> float:
	return float(E.UPGRADES.scope.zoom[clampi(int(progress.kit.get("scope", 0)), 0, 3)])

func _on_zoom_slider(v: float) -> void:
	zoom_target = clampf(v, ZOOM_MIN, _zoom_max())

func _set_zoom(z: float) -> void:
	zoom_target = clampf(z, ZOOM_MIN, _zoom_max())

## Fingers: one drags the view, two pinch the zoom. A short tap fires (through the
## scope) or looks through the scope at that spot (naked eye). Taps come from the
## mouse events Android makes of the first finger (CLAUDE.md: never ScreenTouch for taps).
func _input(event: InputEvent) -> void:
	if not playing or engine.over or get_tree().paused:
		return
	if coaching:
		if (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A) \
				or (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]):
			get_viewport().set_input_as_handled()
			_coach_next()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = event.position
		else:
			fingers.erase(event.index)
		if fingers.size() >= 2:
			gesture_multi = true
			var pts: Array = fingers.values()
			pinch_d0 = maxf(20.0, (pts[0] as Vector2).distance_to(pts[1]))
			pinch_z0 = zoom_target
		if fingers.is_empty():
			call_deferred("_end_multi")
	elif event is InputEventScreenDrag:
		fingers[event.index] = event.position
		if fingers.size() >= 2 and pinch_d0 > 0.0:
			var pts: Array = fingers.values()
			var dd := (pts[0] as Vector2).distance_to(pts[1])
			_set_zoom(pinch_z0 * dd / pinch_d0)
			zoom = zoom_target
	elif event is InputEventMagnifyGesture:
		_set_zoom(zoom_target * event.factor)
	elif event is InputEventJoypadButton:
		_pad_button(event)
	elif event is InputEventJoypadMotion:
		_pad_axis(event)
	elif event is InputEventKey:
		if event.keycode in [KEY_SPACE, KEY_SHIFT]:
			key_hold = event.pressed
			engine.hold_breath(key_hold or mouse_hold or pad_hold or hold_btn.button_pressed)
		elif event.pressed and event.keycode in [KEY_ENTER, KEY_F]:
			_fire()
		elif event.pressed and event.keycode in [KEY_EQUAL, KEY_KP_ADD]:
			_set_zoom(zoom_target * 1.25)
		elif event.pressed and event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_set_zoom(zoom_target / 1.25)

## PC controller layout (gamepad + keyboard). Sticks / arrows / WASD aim (slower the
## more you zoom), RT or A fires, LT / B / X holds breath, bumpers (or D-pad up/down) zoom.
const PAD_DEAD := 0.2
const PAD_SPEED := 700.0  # screen px per second at full deflection

func _pad_aim(delta: float) -> void:
	var v := Vector2.ZERO
	for dev in Input.get_connected_joypads():
		for pair in [[JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y], [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]]:
			var a := Vector2(Input.get_joy_axis(dev, pair[0]), Input.get_joy_axis(dev, pair[1]))
			if a.length() > PAD_DEAD:
				v += a * ((a.length() - PAD_DEAD) / (1.0 - PAD_DEAD))
	var kx := int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var ky := int(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	v += Vector2(kx, ky)
	if v == Vector2.ZERO or briefing or coaching or not bcam.is_empty():
		return
	v = v.limit_length(1.0)
	v.y *= _ysign()
	cam += v * PAD_SPEED * delta / _scale()

func _pad_button(e: InputEventJoypadButton) -> void:
	match e.button_index:
		JOY_BUTTON_A:
			if e.pressed:
				_on_tap(size * 0.5)
		JOY_BUTTON_B, JOY_BUTTON_X:
			pad_hold = e.pressed
			engine.hold_breath(key_hold or mouse_hold or pad_hold or hold_btn.button_pressed)
		JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_UP:
			if e.pressed:
				_set_zoom(zoom_target * 1.25)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_DOWN:
			if e.pressed:
				_set_zoom(zoom_target / 1.25)

func _pad_axis(e: InputEventJoypadMotion) -> void:
	if e.axis == JOY_AXIS_TRIGGER_RIGHT:
		var down := e.axis_value > 0.5
		if down and not pad_fire_down:
			_on_tap(size * 0.5)
		pad_fire_down = down
	elif e.axis == JOY_AXIS_TRIGGER_LEFT:
		pad_hold = e.axis_value > 0.3
		engine.hold_breath(key_hold or mouse_hold or pad_hold or hold_btn.button_pressed)

func _end_multi() -> void:
	if fingers.is_empty():
		gesture_multi = false
		pinch_d0 = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not playing or engine.over:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_set_zoom(zoom_target * 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_set_zoom(zoom_target / 1.15)
			MOUSE_BUTTON_RIGHT:
				mouse_hold = event.pressed
				engine.hold_breath(key_hold or mouse_hold or pad_hold or hold_btn.button_pressed)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					pressing = true
					dragged = false
					press_pos = event.position
					drag_last = event.position
					press_ms = Time.get_ticks_msec()
					if fingers.size() < 2:
						gesture_multi = false
				elif pressing:
					pressing = false
					var quick := Time.get_ticks_msec() - press_ms <= TAP_MS
					if not dragged and quick and not gesture_multi:
						_on_tap(event.position)
	elif event is InputEventMouseMotion and pressing and not gesture_multi and fingers.size() < 2:
		var delta: Vector2 = event.position - drag_last
		drag_last = event.position
		if not dragged and event.position.distance_to(press_pos) > TAP_PX:
			dragged = true
		if dragged:
			cam -= Vector2(delta.x, delta.y * _ysign()) / _scale()

func _on_tap(p: Vector2) -> void:
	if not bcam.is_empty():
		# Skip: let the bullet land at full speed and hand back the scope.
		var left := maxf(0.0, float(bcam.tof) - float(bcam.t))
		_end_bullet_cam()
		engine.step(left + 0.01)
		_handle_events()
		_sync_targets()
		return
	if briefing or coaching:
		return
	if zoom_target < ZOOM_SCOPE:
		# Naked eye: look through the scope where the tap was.
		cam = _aim_world() + (p - size * 0.5) / _scale()
		_set_zoom(4.0)
		return
	_fire()

# ---------- helps (STANDARDS §17) ----------

func _help_spotter() -> bool:
	if not playing or engine.over or _spotter_target().is_empty():
		return false
	spotter_t = 20.0
	_hint(tr("Spotter: put the reticle on the red diamond"), 3.0)
	return true

func _help_rounds() -> bool:
	if not playing or engine.over or engine.mode == "survival":
		return false
	engine.ammo += 3
	if engine.mag <= 0 and engine.reload_t <= 0.0:
		engine.reload_t = 0.5
	return true

# ---------- save / progress ----------

func _save_game() -> void:
	if not playing or engine == null or engine.over:
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "cam": [cam.x, cam.y], "zoom": zoom_target})

func _load_saved_game() -> void:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null or not data.has("engine"):
		_start_next_contract()
		return
	engine.from_dict(data.engine)
	if engine.over:
		_start_next_contract()
		return
	level = engine.level
	_begin_resumed(data)

func _begin_resumed(data: Dictionary) -> void:
	end_dialog.visible = false
	results_chip.visible = false
	result_shown = false
	playing = true
	briefing = false
	bcam = {}
	engine.set_kit(progress.kit)
	zoom_slider.max_value = _zoom_max()
	_build_world()
	var c: Array = data.get("cam", [E.W * 0.5, E.H * 0.6])
	cam = Vector2(float(c[0]), float(c[1]))
	zoom_target = float(data.get("zoom", 1.0))
	zoom = zoom_target
	_apply_camera()
	_banner(_job_title())
	_wind_sound(true)
	_music("play", "calm")

func _resume_text() -> String:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null or not data.has("engine"):
		return ""
	var e: Dictionary = data.engine
	var place: String = tr(E.LOC_NAMES.get(str(e.get("loc", "alpine")), ""))
	match str(e.get("mode", "contract")):
		"survival":
			return tr("♾ Survival · %s") % place + "  " + tr("Score %d") % int(e.get("score", 0))
		"daily":
			return tr("📅 Daily · %s") % place
	return tr("Contract %d · %s") % [int(e.get("contract", 0)) + 1, place]

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	if d is Dictionary:
		progress.reached = int(d.get("reached", 0))
		progress.stars = d.get("stars", {})
		progress["all_done"] = bool(d.get("all_done", false))
		progress["cash"] = int(d.get("cash", 0))
		progress["kit"] = d.get("kit", {}) if d.get("kit", {}) is Dictionary else {}
	var p = SaveUtil.read(PREFS_PATH)
	if p is Dictionary:
		for k in p:
			prefs[k] = p[k]

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)


# ---------- tutorial (the intro level) ----------
# Easy contract 1 with a coach card per HUD element: a spotlight on the thing, a few
# words, Next. The last step is one practice shot. Nothing is paid or recorded.

func _start_tutorial() -> void:
	SaveUtil.delete(SAVE_PATH)
	tutorial = true
	tut_level = level
	level = 0
	engine.reset("contract", 0, 0)
	_begin()

func _tut_end() -> void:
	if not tutorial:
		return
	tutorial = false
	coaching = false
	tut_fired = false
	if coach:
		coach.visible = false
	level = int(prefs.get("level", tut_level))

func _tut_steps() -> Array:
	var s := size
	var left: bool = prefs.get("left", false)
	var gx := s.x - 78.0 if left else 78.0
	var rx := 150.0 if not left else s.x - 330.0
	return [
		{"t": "Welcome to Red Mist. This is a quick tour of the screen. Tap Next (or press Enter / the A button) to go on.", "r": Rect2()},
		{"t": "Top left: the job, what is left to do, and your score. The bar under it is the ALARM: shots and near misses fill it, and when it is full the officer runs.", "r": Rect2(16, 24, 460, 82)},
		{"t": "Top right: the WIND arrow and speed (it points where the wind blows to), and the RANGE to whatever is under the reticle once you look through the scope.", "r": Rect2(s.x - 400, 24, 384, 84)},
		{"t": "The green ring (bottom corner) is your BREATH. The white dot goes round with each breath; the green part is the pause after breathing out. Fire there: the aim goes still and the ring on the reticle turns green. The heart number is your pulse: it climbs with every shot and makes the aim shake more.", "r": Rect2(gx - 60, s.y - 138, 120, 120)},
		{"t": "HOLD BREATH freezes the breathing for about 3 seconds of steady aim, then the shakes start, and at 6 seconds you gasp. On PC: hold Space or the right mouse button. On a controller: hold the left trigger, B or X.", "r": Rect2(hold_btn.position, hold_btn.size)},
		{"t": "ROUNDS: the cartridges are the rounds in the magazine; the number after the + is what is left in your pack. After the last round in the magazine you reload.", "r": Rect2(rx - 10, s.y - 84, E.MAG * 18 + 96, 64)},
		{"t": "The ZOOM bar looks through the scope. Slide it up, pinch, or use the mouse wheel, + / -, the bumpers or D-pad up / down. Zoomed out you look around the valley; zoomed in, a tap fires.", "r": Rect2(zoom_slider.position - Vector2(10, 34), zoom_slider.size + Vector2(20, 44))},
		{"t": "PAUSE stops the game; Resume on the Landing carries on the same contract.", "r": Rect2(pause_btn.position - Vector2(8, 8), pause_btn.size + Vector2(16, 16))},
		{"t": "CONTROLS\nTouch: drag to look, pinch to zoom, tap to fire.\nMouse: drag or the arrow keys / WASD to look, wheel to zoom, left click or Enter to fire, right click or Space to hold breath.\nController: sticks look, RT or A fires, LT / B / X holds breath, LB / RB zoom out / in, D-pad up / down zoom.\nOptions can flip the look up / down direction.", "r": Rect2()},
		{"t": "Your turn. Zoom in on the guard in the valley, breathe out, and when the ring goes green take ONE shot. Then we are done.", "r": Rect2()},
		{"t": "Good shooting. Easy mode has no drop or wind; Normal and Hard add them. Tap Finish to go back, then start your first contract.", "r": Rect2()},
	]

func _build_coach() -> void:
	coach = Control.new()
	coach.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	coach.mouse_filter = Control.MOUSE_FILTER_STOP
	coach.visible = false
	coach.draw.connect(_draw_coach)
	add_child(coach)
	coach_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.05, 0.94)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(ACCENT, 0.8)
	sb.set_content_margin_all(18)
	coach_card.add_theme_stylebox_override("panel", sb)
	coach.add_child(coach_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	coach_card.add_child(box)
	coach_text = HomeKit.label("", 22, Color(0.96, 0.96, 0.98), false, true)
	coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_text.custom_minimum_size = Vector2(520, 0)
	box.add_child(coach_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var skip := HomeKit.neon_button(tr("Skip tutorial"), HomeKit.BUTTON, 20, 52)
	skip.pressed.connect(_coach_skip)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(skip)
	coach_next = HomeKit.neon_button(tr("Next"), HomeKit.GO, 22, 52)
	coach_next.pressed.connect(_coach_next)
	coach_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(coach_next)

func _coach_show(i: int) -> void:
	var steps := _tut_steps()
	tut_step = clampi(i, 0, steps.size() - 1)
	var last := tut_step == steps.size() - 1
	var practice := tut_step == steps.size() - 2
	coach_text.text = _tr_lines(String(steps[tut_step].t))
	coach_next.text = tr("Finish") if last else (tr("Start practice") if practice else tr("Next"))
	coaching = true
	coach.visible = true
	move_child(coach, -1)
	engine.hold_breath(false)
	coach.queue_redraw()
	coach_card.reset_size()
	await get_tree().process_frame
	if not coach.visible:
		return
	# Park the card on the side away from the spotlight.
	var r: Rect2 = steps[tut_step].r
	var cs := coach_card.size
	var y := size.y * 0.5 - cs.y * 0.5
	if r.size != Vector2.ZERO:
		y = size.y - cs.y - 30.0 if r.position.y + r.size.y * 0.5 < size.y * 0.5 else 30.0
	coach_card.position = Vector2((size.x - cs.x) * 0.5, clampf(y, 10.0, maxf(10.0, size.y - cs.y - 10.0)))

func _tr_lines(t: String) -> String:
	var out := []
	for l in t.split("\n"):
		out.append(tr(l))
	return "\n".join(out)

func _coach_next() -> void:
	var steps := _tut_steps()
	if tut_step >= steps.size() - 1:
		progress["tut_done"] = true
		_save_progress()
		_go_home()
		return
	if tut_step == steps.size() - 2:
		# Practice: hand the world back until the shot is fired.
		coaching = false
		coach.visible = false
		_set_zoom(4.0)
		_hint(tr("Look through the scope, breathe out, then fire."), 5.0)
		return
	_coach_show(tut_step + 1)

func _coach_skip() -> void:
	progress["tut_done"] = true
	_save_progress()
	_go_home()

func _draw_coach() -> void:
	var s := size
	var steps := _tut_steps()
	var r: Rect2 = steps[clampi(tut_step, 0, steps.size() - 1)].r
	var dim := Color(0, 0, 0, 0.62)
	if r.size == Vector2.ZERO:
		coach.draw_rect(Rect2(Vector2.ZERO, s), dim)
		return
	# Dim everything except the spotlight.
	coach.draw_rect(Rect2(0, 0, s.x, r.position.y), dim)
	coach.draw_rect(Rect2(0, r.end.y, s.x, s.y - r.end.y), dim)
	coach.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	coach.draw_rect(Rect2(r.end.x, r.position.y, s.x - r.end.x, r.size.y), dim)
	var pulse := 0.6 + 0.4 * sin(anim_t * 5.0)
	coach.draw_rect(r, Color(1.0, 0.85, 0.3, pulse), false, 3.0)
