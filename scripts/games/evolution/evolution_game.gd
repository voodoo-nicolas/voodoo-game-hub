extends Control

## Evolution: start as a blind one-cell blob in an endless dark pond. Missions give you a
## tail, an eye, size and DNA; spend DNA on the evolution tree. Landscape, with Last Shift's
## button layout. All rules live in the engine; this file is the screen.

const EvEngine = preload("res://scripts/games/evolution/evolution_engine.gd")
const Data = preload("res://scripts/games/evolution/evolution_data.gd")
const Art = preload("res://scripts/games/evolution/evolution_art.gd")
const Controls = preload("res://scripts/games/evolution/evolution_controls.gd")
const Screens = preload("res://scripts/games/evolution/evolution_screens.gd")
const Sound = preload("res://scripts/games/evolution/evolution_sound.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/evolution/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/evolution/evolution_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const PREFS_PATH := "user://evolution_prefs.json"
## The Landing picture (kit: used when the file exists, else the plain Landing).
const LANDING_ART := "res://games/evolution/landing_bg.jpg"

const BG := Color(0.012, 0.016, 0.03)
const MINE := Color("29e6ff")     # accent of the menus; the cell uses the colour the player picked
const FOOD := [Color("ffd23f"), Color("ff9f43"), Color("c77dff")]
const ZOOM_SMOOTH := 3.0
const VISION_SMOOTH := 2.2
const OVERLAY_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center = vec2(0.0);
uniform vec2 rect_size = vec2(1.0);
uniform float radius = 200.0;
uniform float soft = 0.4;
uniform float darkness = 0.97;
uniform float blur = 2.0;
uniform float radial = 0.0;   // radial (zoom) blur: streaks burst out from the centre, stronger toward the edge of sight
uniform float lod_ok = 1.0;   // 0 on the web build: read only the full-size screen there
// 2026-10-29 (slow on phones): 15 reads per pixel instead of 35, from the screen's pre-blurred smaller copies
// (mip levels) so fewer reads still look smooth, and a single read outside your sight, which is dark anyway.
void fragment() {
	vec2 p = UV * rect_size;
	float d = length(p - center);
	float edge = smoothstep(radius * (1.0 - soft), radius, d);
	if (edge >= 1.0) {
		COLOR = vec4(textureLod(screen_tex, SCREEN_UV, 0.0).rgb * (1.0 - darkness), 1.0);
	} else {
		float far = smoothstep(radius * 0.15, radius, d);
		float r = blur * far;
		vec3 col = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
		if (radial > 0.001 && far > 0.0) {
			vec2 to_c = (center - p) / rect_size;
			float gap = length(to_c * rect_size) * radial * far / 5.0;
			float lod_r = clamp(log2(max(gap, 1.0)), 0.0, 3.0) * lod_ok;
			vec3 acc_r = col;
			for (int i = 1; i <= 5; i++) {
				acc_r += textureLod(screen_tex, SCREEN_UV + to_c * (float(i) / 5.0 * radial * far), lod_r).rgb;
			}
			col = acc_r / 6.0;
		}
		if (r > 0.5) {
			vec2 px = SCREEN_PIXEL_SIZE * r;
			float lod_d = clamp(log2(max(r * 0.6, 1.0)), 0.0, 3.0) * lod_ok;
			vec3 acc = col;
			for (int i = 0; i < 8; i++) {
				float a = 6.2831853 * float(i) / 8.0 + 0.2;
				acc += textureLod(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * px * 0.75, lod_d).rgb;
			}
			col = acc / 9.0;
		}
		COLOR = vec4(mix(col, vec3(0.0), darkness * edge), 1.0);
	}
}
"""
## Once your eyes are perfectly sharp there is nothing to blur: only the dark edge of your sight, drawn on top
## without reading the screen back (no screen copy at all).
const DARK_SHADER := """
shader_type canvas_item;
uniform vec2 center = vec2(0.0);
uniform vec2 rect_size = vec2(1.0);
uniform float radius = 200.0;
uniform float soft = 0.4;
uniform float darkness = 0.97;
void fragment() {
	float d = length(UV * rect_size - center);
	COLOR = vec4(0.0, 0.0, 0.0, darkness * smoothstep(radius * (1.0 - soft), radius, d));
}
"""
## The water behind everything: big faint light blobs and three parallax layers of drifting plankton, all in ONE
## draw call: a MultiMesh of small quads that this shader places on the grid cells you can see (2026-10-29: it was
## ~1,500 circles a frame from GDScript, 28-117 ms on a PC; a full-screen shader still cost the GPU 25-35 ms).
## Layer 0 = blobs (cell 900, parallax 0.25, 6 soft rings each), layers 1-3 = plankton specks.
const WATER_SHADER := """
shader_type canvas_item;
uniform vec2 cam = vec2(0.0);       // the player's world position
uniform float zoom = 1.0;
uniform vec2 rect_size = vec2(1.0);
uniform float clock = 0.0;          // the game's pulse
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform ivec4 lay_start = ivec4(0); // first instance of each layer
uniform ivec4 lay_cols = ivec4(1);  // grid columns of each layer
const float PAR[4] = float[4](0.25, 0.45, 0.75, 1.0);
const float CS[4] = float[4](900.0, 240.0, 190.0, 160.0);
const float SZ[4] = float[4](0.0, 1.6, 2.2, 2.6);
const float ALPHA[4] = float[4](0.0, 0.16, 0.22, 0.30);
const float KEY[4] = float[4](0.0, 17.0, 34.0, 51.0);
varying float v_r;      // radius in pixels
varying float v_a;
varying float v_blob;

// Four 0..1 values, fixed per grid cell
vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

void vertex() {
	int id = INSTANCE_ID;
	int L = 0;
	if (id >= lay_start.w) {
		L = 3;
	} else if (id >= lay_start.z) {
		L = 2;
	} else if (id >= lay_start.y) {
		L = 1;
	}
	int local = id - lay_start[L];
	int cols = max(lay_cols[L], 1);
	float cs = CS[L];
	float par = PAR[L];
	vec2 c = floor((cam * par - rect_size * 0.5 / zoom) / cs) - 1.0 + vec2(float(local % cols), float(local / cols));
	vec2 ctr;
	float r;
	if (L == 0) {
		vec4 h = hash42(c);
		ctr = (c + 0.3 + 0.4 * h.xy) * cs;
		r = (260.0 + 240.0 * h.z) * zoom;
		v_a = 1.0;
		v_blob = 1.0;
	} else {
		vec4 a = hash42(c + KEY[L]);
		vec4 b = hash42(c + KEY[L] + 91.7);
		ctr = (c + 0.2 + 0.6 * a.xy) * cs + vec2(sin(clock * 0.4 + a.z * 6.0), cos(clock * 0.35 + a.w * 6.0)) * 14.0;
		r = SZ[L] * (0.6 + b.y) * max(zoom, 0.5);
		v_a = ALPHA[L] * (0.6 + 0.4 * sin(clock * 1.5 + b.x * 9.0));
		v_blob = 0.0;
	}
	v_r = r;
	VERTEX = (ctr - cam * par) * zoom + rect_size * 0.5 + VERTEX * 2.0 * (r + 1.0);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0 * (v_r + 1.0);
	if (v_blob > 0.5) {
		float f = d / v_r;
		float n = f < 1.0 ? min(floor((1.0 - f) / 0.15) + 1.0, 6.0) : 0.0;
		COLOR = vec4(tint.rgb, 1.0 - pow(0.91, n));
	} else {
		COLOR = vec4(0.55, 0.9, 1.0, v_a * clamp(v_r - d + 0.5, 0.0, 1.0));
	}
}
"""

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var result_sent := false
var _flushed := {"cells": 0, "food": 0, "dist": 0.0}
var _flush_t := 0.0
var zoom: float = 1.0
var vis_r: float = 160.0            # screen pixels the cell can see
var keys := Vector2.ZERO
var voodoo := false
var pulse: float = 0.0
var particles: Array = []
var bump: float = 0.0               # body pop after eating
var hurt: float = 0.0               # red screen-edge warning
var lurch: float = 0.0              # body stretch after a jolt
var heading: float = 0.0
var eye_open: float = 1.0
var tail_grow: float = 1.0
var banners: Array = []             # [{"text","t"}], shown one after another
## color = primary; color2 / color3 = the two secondary colours (indexes into Data.COLORS).
var prefs := {"color": 0, "color2": 3, "color3": 2, "diff": "normal", "endless": false, "picked": false}
var diff := "normal"
var endless := false                    # dying sends you back to the start of your size instead of ending the run
var color: Color = MINE
var color2: Color = Data.COLORS[3][1]   # tail, fins, spikes, tentacles, hairs
var color3: Color = Data.COLORS[2][1]   # spots, stripes, small details
var _mission_sig := ""
var _swatches := {}                     # pref key -> its row of swatch buttons
var _preview: Control
var _creature_ui: Control               # the "Choose your creature" screen

var field: Control
var overlay: ColorRect
var water: ColorRect
var _wake_t := 0.0                       # next wake bubble
var _water_mm: MultiMesh                # the blobs and plankton specks (one quad each)
var _water_specks: MultiMeshInstance2D
var _blur_mat: ShaderMaterial    # the overlay while your sight is blurry (reads the screen back)
var _dark_mat: ShaderMaterial    # ... once it is sharp: only the dark edge, much cheaper
var controls: Controls
var fx: Control
var screens: Screens
var popup: Control
var popup_title: Label
var popup_text: Label
var _popup_queue: Array = []
var end_dialog: Control
var hp_bar: ProgressBar
var sp_bar: ProgressBar
var xp_bar: ProgressBar
var hp_row: Control
var sp_row: Control
var xp_row: Control
var dna_bar: ProgressBar    # the 🧬 bar: what you eat fills it, a full bar = +1 DNA (owner 2026-10-29)
var dna_row: Control
var stage_label: Label
var env_label: Label
var ail_box: VBoxContainer
var _ail_sig := ""
var info_btn: Button
var mission_box: VBoxContainer
var mission_panel: Control
var bars_panel: Control

func _ready() -> void:
	preload("res://scripts/games/evolution/evolution_i18n.gd").install(self)
	Orientation.lock_landscape()
	_load_prefs()
	engine = EvEngine.new()
	_build_ui()
	engine.reset(-1, diff)
	_apply_view(1.0, true)
	_music_node_call("prepare", "calm", 0)

# ---------- preferences ----------

func _load_prefs() -> void:
	if FileAccess.file_exists(PREFS_PATH):
		var f := FileAccess.open(PREFS_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				for key in ["color", "color2", "color3"]:
					prefs[key] = clampi(int(parsed.get(key, prefs[key])), 0, Data.COLORS.size() - 1)
				var d := str(parsed.get("diff", "normal"))
				prefs["diff"] = d if Data.DIFFICULTY.has(d) else "normal"
				prefs["endless"] = bool(parsed.get("endless", false))
				prefs["picked"] = bool(parsed.get("picked", false))
	diff = prefs.diff
	_apply_colors()

func _apply_colors() -> void:
	color = Data.COLORS[prefs.color][1]
	color2 = Data.COLORS[prefs.color2][1]
	color3 = Data.COLORS[prefs.color3][1]

func _save_prefs() -> void:
	var f := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(prefs))
		f.close()

# ---------- UI ----------

func _bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(230, 20)
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(6)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.55)
	bgs.border_color = Color(1, 1, 1, 0.35)
	bgs.set_border_width_all(2)
	bgs.set_corner_radius_all(6)
	b.add_theme_stylebox_override("fill", f)
	b.add_theme_stylebox_override("background", bgs)
	return b

func _bar_row(tag: String, bar: ProgressBar) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = tag
	l.custom_minimum_size = Vector2(46, 0)
	l.add_theme_font_size_override("font_size", 22)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	row.add_child(bar)
	return row

## A full-rect margin box that keeps its one child in a corner / edge of the safe area.
func _corner(child: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 18)
	child.size_flags_horizontal = h
	child.size_flags_vertical = v
	m.add_child(child)
	return m

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	# The water: a plain colour, with the blobs and plankton on top as one MultiMesh (WATER_SHADER places them).
	water = ColorRect.new()
	water.set_anchors_preset(Control.PRESET_FULL_RECT)
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.color = BG
	add_child(water)
	_water_mm = MultiMesh.new()
	_water_mm.transform_format = MultiMesh.TRANSFORM_2D
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_water_mm.mesh = quad
	_water_mm.custom_aabb = AABB(Vector3(-1e5, -1e5, -1.0), Vector3(2e5, 2e5, 2.0))   # never culled
	_grow_water(3000)
	var wsh := Shader.new()
	wsh.code = WATER_SHADER
	var wmat := ShaderMaterial.new()
	wmat.shader = wsh
	_water_specks = MultiMeshInstance2D.new()
	_water_specks.multimesh = _water_mm
	_water_specks.material = wmat
	water.add_child(_water_specks)

	field = Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.draw.connect(_draw_field)
	add_child(field)

	# What the cell can see: darkness outside the vision ring, blur growing toward its edge.
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = OVERLAY_SHADER
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = sh
	_blur_mat.set_shader_parameter("lod_ok", 0.0 if OS.has_feature("web") else 1.0)
	var dsh := Shader.new()
	dsh.code = DARK_SHADER
	_dark_mat = ShaderMaterial.new()
	_dark_mat.shader = dsh
	overlay.material = _blur_mat
	add_child(overlay)

	fx = Control.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_draw_fx)
	add_child(fx)

	controls = Controls.new()
	controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls.accent = MINE
	controls.ability_pressed.connect(_on_ability)
	add_child(controls)

	# top left: HP / special / XP bars (they appear with the first eye)
	bars_panel = VBoxContainer.new()
	bars_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars_panel.add_theme_constant_override("separation", 6)
	hp_bar = _bar(Color("e63946"))
	sp_bar = _bar(Color("3ac7ff"))
	xp_bar = _bar(Color("ffc233"))
	hp_row = _bar_row("HP", hp_bar)
	sp_row = _bar_row("⚡", sp_bar)
	xp_row = _bar_row("XP", xp_bar)
	dna_bar = _bar(Color("7dff3a"))
	dna_row = _bar_row("🧬", dna_bar)
	bars_panel.add_child(hp_row)
	bars_panel.add_child(sp_row)
	bars_panel.add_child(xp_row)
	bars_panel.add_child(dna_row)
	stage_label = Label.new()
	stage_label.add_theme_font_size_override("font_size", 20)
	stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars_panel.add_child(stage_label)
	# depth and water temperature, with the limits your body can take
	env_label = Label.new()
	env_label.add_theme_font_size_override("font_size", 18)
	env_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars_panel.add_child(env_label)
	# ailments, each with a timer bar running down
	ail_box = VBoxContainer.new()
	ail_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ail_box.add_theme_constant_override("separation", 2)
	bars_panel.add_child(ail_box)
	add_child(_corner(bars_panel, Control.SIZE_SHRINK_BEGIN, Control.SIZE_SHRINK_BEGIN))

	# right side: the mission list
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(290, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.03, 0.05, 0.1, 0.72)
	ps.border_color = Color(1, 1, 1, 0.25)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	ps.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	mission_box = VBoxContainer.new()
	mission_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_box.add_theme_constant_override("separation", 6)
	panel.add_child(mission_box)
	mission_panel = panel
	add_child(_corner(panel, Control.SIZE_SHRINK_END, Control.SIZE_SHRINK_BEGIN))

	# bottom middle: pause and the creature screen
	var mid := HBoxContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_theme_constant_override("separation", 18)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(96, 56)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(_on_pause)
	mid.add_child(pause_btn)
	info_btn = Button.new()
	info_btn.text = "🧬"
	info_btn.custom_minimum_size = Vector2(96, 56)
	info_btn.focus_mode = Control.FOCUS_NONE
	info_btn.pressed.connect(_open_info)
	mid.add_child(info_btn)
	add_child(_corner(mid, Control.SIZE_SHRINK_CENTER, Control.SIZE_SHRINK_END))

	screens = Screens.new()
	screens.closed.connect(_on_screens_closed)
	screens.home_pressed.connect(_go_home)
	screens.sfx.connect(_sfx)
	add_child(screens)
	_build_popup()

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": MINE,
		"subtitle": "Eat to grow. Evolve. Don't get eaten.",
		"logo": _draw_home_logo,
		"art": LANDING_ART,
		"art_title": [0.22, 0.36],  # "Evolution" is painted in the art
		"extra": _add_options,
		"more": [["🎨 Your creature", HomeKit.BUTTON, _open_creature.bind(false)]],
		"modes": [
			{"text": "Easy", "key": "easy", "row": "diff", "action": _start_run.bind("easy")},
			{"text": "Normal", "key": "normal", "row": "diff", "action": _start_run.bind("normal")},
			{"text": "Hard", "key": "hard", "row": "diff", "action": _start_run.bind("hard")},
		],
		"restart": _new_game,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	_update_hud()

## The setup screen's own picker: the cell's primary colour and two secondary colours, with a live preview
## (drawn with a tail, fins and spikes so the secondary colours show).
func _add_options(body: VBoxContainer) -> void:
	_add_colour_pickers(body)
	body.add_child(home.section("When you die"))
	body.add_child(home.choice_row(["Game over", "Endless"], 1 if bool(prefs.endless) else 0, _pick_endless))
	var note := Label.new()
	note.text = tr("Game over: a new run starts from zero.") + "\n" + tr("Endless: you come back at the start of your size, keeping everything you evolved.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(80, 0)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_size_override("font_size", 20)
	note.add_theme_color_override("font_color", HomeKit.DIM)
	body.add_child(note)
	if not bool(prefs.picked):        # the player has now seen the colour pickers
		prefs["picked"] = true
		_save_prefs()

func _pick_endless(i: int) -> void:
	prefs["endless"] = i == 1
	_save_prefs()

## The cell's colours with a live preview (the setup screen and "Choose your creature" both use it).
func _add_colour_pickers(body: VBoxContainer) -> void:
	body.add_child(home.section("Your colour"))
	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(0, 150)
	_preview.draw.connect(_draw_preview)
	body.add_child(_preview)
	_swatches.clear()
	_swatch_row(body, "color", "Main colour")
	_swatch_row(body, "color2", "Secondary colour 1: tail, fins, spikes")
	_swatch_row(body, "color3", "Secondary colour 2: spots, stripes, details")
	_style_swatches()

func _swatch_row(body: VBoxContainer, key: String, title: String) -> void:
	if title != "":
		var l := Label.new()
		l.text = tr(title)
		l.add_theme_font_size_override("font_size", 20)
		body.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var btns: Array = []
	for i in Data.COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = tr(Data.COLORS[i][0])
		b.pressed.connect(_pick_color.bind(key, i))
		row.add_child(b)
		btns.append(b)
	_swatches[key] = btns

func _style_swatches() -> void:
	for key in _swatches:
		var btns: Array = _swatches[key]
		for i in btns.size():
			var sel: bool = i == int(prefs[key])
			for st in ["normal", "hover", "pressed", "focus"]:
				var sb := StyleBoxFlat.new()
				sb.bg_color = Data.COLORS[i][1]
				sb.set_corner_radius_all(10)
				sb.set_border_width_all(6 if sel else 2)
				sb.border_color = Color.WHITE if sel else Color(1, 1, 1, 0.3)
				btns[i].add_theme_stylebox_override(st, sb)
	if _preview:
		_preview.queue_redraw()

func _pick_color(key: String, i: int) -> void:
	prefs[key] = i
	_apply_colors()
	_save_prefs()
	_style_swatches()

func _draw_preview() -> void:
	if _preview == null:
		return
	var s := _preview.size
	var r := minf(s.y * 0.36, 58.0)
	Art.draw_player(_preview, s / 2.0 + Vector2(r * 0.7, 0), r, color, 0.0, pulse, {"move_rank": 2, "sight_rank": 3, "owned": {"fins": 1, "spikes": 1}, "speed": 0.2, "voodoo": voodoo, "col2": color2, "col3": color3})

# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				keys.x = -1.0 if event.pressed else (0.0 if keys.x < 0.0 else keys.x)
			KEY_RIGHT, KEY_D:
				keys.x = 1.0 if event.pressed else (0.0 if keys.x > 0.0 else keys.x)
			KEY_UP, KEY_W:
				keys.y = -1.0 if event.pressed else (0.0 if keys.y < 0.0 else keys.y)
			KEY_DOWN, KEY_S:
				keys.y = 1.0 if event.pressed else (0.0 if keys.y > 0.0 else keys.y)
			KEY_SPACE, KEY_1:
				if event.pressed:
					_on_ability(0)
			KEY_2, KEY_3, KEY_4:
				if event.pressed:
					_on_ability(int(event.keycode) - KEY_1)
			KEY_TAB, KEY_I:
				if event.pressed and started:
					_open_info()
			KEY_ESCAPE:
				if screens.visible:
					screens.close()
					_on_screens_closed()

func _direction() -> Vector2:
	if controls.dir.length() > 0.0:
		return controls.dir
	return keys.limit_length(1.0)

func _on_ability(i: int) -> void:
	if not started or screens.visible:
		return
	if engine.use_slot(i):
		pass            # the ability's own event plays its sound
	elif engine.slot_visible(i):
		_sfx("tick")

# ---------- game flow ----------

func _start_run(d: String) -> void:
	diff = d
	prefs["diff"] = d
	endless = bool(prefs.endless)
	_save_prefs()
	if not bool(prefs.picked):
		_open_creature(true)      # Quick Play skips the setup screen: the first run still asks for the colours
		return
	_new_game()

## "Choose your creature": the three colours with a live preview. Opens by itself before the first run
## (go = true: ▶ Start begins the run) and from the Landing's "🎨 Your creature" (✓ Done).
func _open_creature(go: bool) -> void:
	if _creature_ui != null and is_instance_valid(_creature_ui):
		return
	var ui := Control.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_creature_ui = ui
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.97)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 32)
	ui.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var title := Label.new()
	title.text = tr("Choose your creature")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.5))
	page.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	_add_colour_pickers(body)
	var ok := Button.new()
	ok.text = ("▶  " + tr("Start")) if go else ("✓  " + tr("Done"))
	ok.custom_minimum_size = Vector2(0, 72)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_close_creature.bind(go))
	page.add_child(ok)

func _close_creature(go: bool) -> void:
	prefs["picked"] = true
	_save_prefs()
	_swatches.clear()
	_preview = null
	if _creature_ui != null and is_instance_valid(_creature_ui):
		_creature_ui.queue_free()
	_creature_ui = null
	if go:
		_new_game()

## Sends this run's progress to the stats (lifetime totals behind the badges).
func _flush_stats() -> void:
	if info == null or engine == null:
		return
	var dc: int = engine.eaten_cells - int(_flushed.cells)
	if dc > 0:
		info.add("Cells eaten", dc)
		_flushed.cells = engine.eaten_cells
	var df: int = engine.eaten_food - int(_flushed.food)
	if df > 0:
		info.add("Food eaten", df)
		_flushed.food = engine.eaten_food
	var meters := int((engine.distance - float(_flushed.dist)) / 10.0)
	if meters > 0:
		info.add("Distance swum (m)", meters)
		_flushed.dist = float(_flushed.dist) + float(meters) * 10.0
	info.high("Biggest size", engine.level())
	info.high("Top speed", engine.speed_pct())

func _new_game() -> void:
	_flush_stats()
	_flushed = {"cells": 0, "food": 0, "dist": 0.0}
	_flush_t = 0.0
	vis_r = field.size.y * Data.SIGHT_FRAC[0]
	zoom = 1.0
	_apply_view(1.0, true)
	engine.reset(-1, diff)
	started = true
	result_sent = false
	_play_music()
	particles.clear()
	banners.clear()
	bump = 0.0
	hurt = 0.0
	lurch = 0.0
	heading = 0.0
	eye_open = 1.0
	tail_grow = 1.0
	_mission_sig = ""
	controls.release()
	screens.close()
	end_dialog.visible = false
	_update_hud()
	_show_popup(tr("Survive"), tr("You must eat.\nYou must not be eaten.\nSome food will speed up your evolution greatly. Some may slow it down."))

func _process(delta: float) -> void:
	pulse += delta
	if not started or screens.visible:
		return
	# A slow frame runs up to 3 engine steps of at most 0.05 s, so the game keeps real time down to ~7 fps
	# (2026-10-29: delta used to be capped at 0.05, so under 20 fps the whole game ran in slow motion).
	delta = minf(delta, 0.15)
	_apply_view(delta)
	var steps := int(ceilf(delta / 0.05))
	if steps <= 1:
		engine.step(delta, _direction())
	else:
		var evs: Array = []
		for i in steps:
			engine.step(delta / float(steps), _direction())
			evs.append_array(engine.events)
		engine.events = evs
	_flush_t += delta
	if _flush_t >= 20.0:
		_flush_t = 0.0
		_flush_stats()
	_handle_events()
	_update_particles(delta)
	_check_danger()
	_animate(delta)
	_update_hud()
	if not engine.alive:
		if endless:
			_revive()
		else:
			_game_over()
	field.queue_redraw()
	fx.queue_redraw()

## Vision radius (the rings of the target picture), camera zoom, and what the engine may spawn near.
func _apply_view(delta: float, snap: bool = false) -> void:
	var s := field.size
	if s.x < 10.0:
		s = size
	var target: float = s.y * Data.SIGHT_FRAC[clampi(engine.sight_rank - 1, 0, Data.SIGHT_FRAC.size() - 1)]
	if engine.has("night_vision"):
		target *= 1.2
	var k := 1.0 if snap else clampf(VISION_SMOOTH * delta, 0.0, 1.0)
	vis_r = lerpf(vis_r, target, k)
	var tz := EvEngine.zoom_for(engine.player.mass)
	zoom = tz if snap else lerpf(zoom, tz, clampf(ZOOM_SMOOTH * delta, 0.0, 1.0))
	var half_diag := s.length() * 0.5
	engine.vision_r = vis_r / maxf(zoom, 0.05)
	engine.view_r = minf(vis_r, half_diag) / maxf(zoom, 0.05)

func _animate(delta: float) -> void:
	lurch = maxf(lurch - delta * 3.0, 0.0)
	eye_open = minf(eye_open + delta * 0.6, 1.0)
	tail_grow = minf(tail_grow + delta * 0.9, 1.0)
	if engine.player.vel.length() > 8.0:
		heading = lerp_angle(heading, engine.player.vel.angle(), clampf(16.0 * delta, 0.0, 1.0))
	_wake(delta)
	if banners.size() > 0:
		banners[0].t -= delta
		if banners[0].t <= 0.0:
			banners.pop_front()

## A trail of tiny bubbles behind you while you swim fast (owner 2026-10-29: the swimming should feel fast).
func _wake(delta: float) -> void:
	var v: Vector2 = engine.player.vel
	var top: float = engine.top_speed()
	if engine.move_rank <= 0 or top <= 0.0 or v.length() < top * 0.45:
		return
	_wake_t -= delta
	if _wake_t > 0.0:
		return
	_wake_t = 0.06
	var pr := EvEngine.radius_of(engine.player.mass)
	var back := -v.normalized()
	particles.append({"pos": engine.player.pos + back * pr * 1.1 + back.orthogonal() * randf_range(-0.4, 0.4) * pr,
		"vel": back * v.length() * 0.12 + Vector2(0.0, -20.0).rotated(randf_range(-0.5, 0.5)),
		"life": 0.45, "max": 0.9, "col": Color(0.75, 0.95, 1.0), "size": pr * randf_range(0.06, 0.12), "ring": 0.0})

func _banner(text: String) -> void:
	banners.append({"text": text, "t": 2.6})

## Raises the red edge warning while a hunter is close.
func _check_danger() -> void:
	if not engine.has_bars():
		return
	for n in engine.npcs:
		if n.role == "hunter" and EvEngine.can_eat(n.mass, engine.player.mass) and n.pos.distance_to(engine.player.pos) < 420.0 + EvEngine.radius_of(n.mass) * 2.0:
			hurt = maxf(hurt, 0.6)
			return

## Why you died, with the numbers (the depth and the water temperature are what killed you, not only "cold").
func _death_text() -> String:
	var how := tr("You were eaten!")
	if engine.death_cause == "cold":
		how = tr("You froze in the cold water!") + "\n" + tr("%d m deep, water at %d °C (your limit: %d °C)") % [int(engine.depth_m()), int(round(engine.temp())), int(ceil(engine.min_temp()))]
	elif engine.death_cause == "deep":
		how = tr("The pressure crushed you!") + "\n" + tr("%d m deep (your limit: %d m)") % [int(engine.depth_m()), int(engine.max_depth_m())]
	return how

## Endless mode: you died, you come back at the start of your size with everything you evolved.
func _revive() -> void:
	controls.release()
	_sfx("explode")
	var how := _death_text()
	engine.revive()
	hurt = 0.0
	_flush_stats()
	_show_popup(tr("You died"), how + "\n" + tr("Back to size %d. Everything you evolved is still yours.") % engine.level())

func _game_over() -> void:
	started = false
	controls.release()
	_sfx("explode")
	var how := _death_text()
	var msg := how + "\n" + tr("Score: %d") % engine.score() + "   ·   " + tr("Size %d") % EvEngine.size_level(engine.peak_mass)
	if info and not result_sent:
		result_sent = true
		_flush_stats()
		info.add("Games played")
		info.add("Missions done", engine.missions_done)
		info.high("Biggest size", EvEngine.size_level(engine.peak_mass))
		info.high("Close call", int(minf(engine.escape_time, 8.0)))
		if info.high("Best score", engine.score()):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- HUD ----------

func _update_hud() -> void:
	if engine == null:
		return
	var e = engine
	bars_panel.visible = e.has_bars()
	if e.has_bars():
		hp_bar.value = e.player.hp / e.max_hp()
		xp_bar.value = e.xp_frac()
		dna_row.visible = e.tree_unlocked
		dna_bar.value = e.dna_frac()
		sp_row.visible = e.has_actives()
		sp_bar.value = e.power_frac()
		stage_label.text = tr(EvEngine.STAGES[e.stage()][1]) + "  ·  " + tr("Size %d") % e.level()
		_update_env()
		_update_ailments()
	var ids: Array = []
	var fills: Array = []
	for i in 4:
		var id: String = e.slot_ids[i] if e.slot_visible(i) else ""
		ids.append(id)
		fills.append(clampf(e.power / e.ability_cost(id), 0.0, 1.0) if id != "" else 0.0)
	controls.set_slots(ids, fills)
	info_btn.visible = e.has_bars()
	info_btn.text = "🧬 %d" % e.dna if e.dna > 0 else "🧬"
	_update_missions()

func _update_env() -> void:
	var e = engine
	var depth_txt: String = tr("Depth: %d m (limit %d m)") % [int(e.depth_m()), int(e.max_depth_m())]
	var temp_txt: String = tr("Water: %d °C (limit %d °C)") % [int(round(e.temp())), int(ceil(e.min_temp()))]
	if e.too_deep > 0.0:
		depth_txt = "⚠ " + depth_txt
	if e.too_cold > 0.0:
		temp_txt = "⚠ " + temp_txt
	env_label.text = depth_txt + "\n" + temp_txt
	var warn: bool = e.too_deep > 0.0 or e.too_cold > 0.0
	# Amber while you are close to a limit: the cold comes from depth AND from cold currents sideways.
	var near: bool = e.temp() < e.min_temp() + 2.5 or e.depth_m() > e.max_depth_m() - 25.0
	env_label.add_theme_color_override("font_color", Color("ff8a8a") if warn else (Color("ffd479") if near else Color(0.8, 0.92, 1.0, 0.9)))

## One row per ailment: its name, the seconds left and a bar that empties as it wears off.
func _update_ailments() -> void:
	var e = engine
	var ids: Array = e.ailments.keys()
	ids.sort()
	var sig := ",".join(ids)
	if sig != _ail_sig:
		_ail_sig = sig
		for ch in ail_box.get_children():
			ail_box.remove_child(ch)
			ch.queue_free()
		for id in ids:
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 18)
			l.add_theme_color_override("font_color", Color("d7ff2a"))
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ail_box.add_child(l)
			var bar := _bar(Color("b8e02a"))
			bar.custom_minimum_size = Vector2(230, 8)
			ail_box.add_child(bar)
	for i in ids.size():
		var id: String = ids[i]
		var left: float = e.ailments[id]
		var full: float = maxf(float(e.ail_full.get(id, left)), 0.01)
		(ail_box.get_child(i * 2) as Label).text = "☠ " + tr(Data.AILMENTS[id].name) + "  " + tr("%ds") % int(ceil(left))
		(ail_box.get_child(i * 2 + 1) as ProgressBar).value = clampf(left / full, 0.0, 1.0)

func _update_missions() -> void:
	var rows: Array = engine.mission_rows()
	var sig := ""
	for r in rows:
		sig += "%s|%d|%s;" % [r.text, int(r.frac * 20.0), str(r.done)]
	if sig == _mission_sig:
		return
	_mission_sig = sig
	for ch in mission_box.get_children():
		mission_box.remove_child(ch)
		ch.queue_free()
	mission_panel.visible = not rows.is_empty()
	var head := Label.new()
	head.text = tr("Missions")
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", Color("ffd479"))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_box.add_child(head)
	for r in rows:
		var l := Label.new()
		var text: String = tr(r.text)
		if r.args.size() > 0:
			var args: Array = []
			for a in r.args:
				args.append(tr(a) if typeof(a) == TYPE_STRING else a)
			text = text % args
		l.text = ("✔ " if r.done else "▸ ") + text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5) if r.done else Color.WHITE)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mission_box.add_child(l)
		var bar := _bar(Color("ffc233") if not r.done else Color("6fbf5a"))
		bar.custom_minimum_size = Vector2(0, 8)
		bar.value = r.frac
		mission_box.add_child(bar)

func _open_info() -> void:
	if screens.visible or not started or not engine.has_bars():
		return
	controls.release()
	get_tree().paused = true                  # the world stands still while you look at your creature
	screens.col2 = color2
	screens.col3 = color3
	screens.open_info(engine, color, voodoo)

func _on_screens_closed() -> void:
	controls.release()
	get_tree().paused = false

# ---------- "you unlocked ..." pop-ups: the game stops and tells you what happened ----------

func _build_popup() -> void:
	popup = Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(dim)
	var box := CenterContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(box)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.08, 0.16, 0.97)
	ps.border_color = Color("29e6ff")
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(14)
	ps.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", ps)
	box.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	popup_title = Label.new()
	popup_title.add_theme_font_size_override("font_size", 34)
	popup_title.add_theme_color_override("font_color", Color("ffd479"))
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(popup_title)
	popup_text = Label.new()
	popup_text.add_theme_font_size_override("font_size", 24)
	popup_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_text.custom_minimum_size = Vector2(560, 0)
	popup_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(popup_text)
	var ok := Button.new()
	ok.text = tr("Continue")
	ok.custom_minimum_size = Vector2(0, 64)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_close_popup)
	v.add_child(ok)
	add_child(popup)

func _show_popup(title: String, text: String) -> void:
	_popup_queue.append([title, text])
	if not popup.visible:
		_next_popup()

func _next_popup() -> void:
	if _popup_queue.is_empty():
		popup.visible = false
		get_tree().paused = false
		return
	var item: Array = _popup_queue.pop_front()
	popup_title.text = item[0]
	popup_text.text = item[1]
	popup.visible = true
	controls.release()
	get_tree().paused = true

func _close_popup() -> void:
	_sfx("tap")
	_next_popup()

# ---------- effects ----------

func _spawn_burst(p: Vector2, col: Color, n: int, speed: float, size_: float, ring_r: float) -> void:
	for i in n:
		var a := randf() * TAU
		particles.append({"pos": p, "vel": Vector2.RIGHT.rotated(a) * randf_range(0.3, 1.0) * speed,
			"life": randf_range(0.4, 0.9), "max": 0.9, "col": col, "size": size_ * randf_range(0.6, 1.2), "ring": 0.0})
	if ring_r > 0.0:
		particles.append({"pos": p, "vel": Vector2.ZERO, "life": 0.5, "max": 0.5, "col": col, "size": 0.0, "ring": ring_r})

func _handle_events() -> void:
	for ev in engine.events:
		match ev.type:
			"food":
				_spawn_burst(ev.pos, FOOD[int(ev.pos.x) % FOOD.size()], 3, 70.0, 3.0, 0.0)
				bump = maxf(bump, 0.03)
				_snd("speck", randf_range(0.9, 1.25), -6.0)
			"cell":
				if ev.role == "rare" and info:
					info.add("Rare eaten")
				var sp := Data.species_of(ev.species)
				_spawn_burst(ev.pos, sp.col, 14, 220.0, 5.0, EvEngine.radius_of(ev.mass) * 1.6)
				bump = 0.1
				var vl := EvEngine.size_level(ev.mass)
				_snd("gulp" if vl >= 3 else "eat", 1.35 / (1.0 + 0.15 * float(vl - 1)) * randf_range(0.95, 1.05))
			"jolt":
				lurch = 1.0
				_spawn_burst(engine.player.pos - ev.dir * EvEngine.radius_of(engine.player.mass), color, 4, 90.0, 3.0, 0.0)
			"tail":
				tail_grow = 0.0
				_snd("evolve")
				_show_popup(tr("You unlocked a tail!"), tr("A small tail grows out of your body. You swim much faster."))
			"eye":
				eye_open = 0.0
				_snd("evolve")
				_show_popup(tr("You unlocked an eye!"), tr("A slit opens in a lump on your body: an eye! You see farther, and your health and growth bars appear."))
			"tree":
				_snd("evolve")
				_show_popup(tr("The evolution tree is open!"), tr("Spend your DNA on the 🧬 screen, next to pause.") + "\n" + tr("Eating fills the green 🧬 bar: each time it is full you get 1 DNA."))
				_banner(tr("+%d DNA") % int(ev.get("dna", 0)))
			"ailment_end":
				if info:
					info.add("Recoveries")             # got sick and lived until it wore off
			"evaded":
				if info:
					info.add("Creatures evaded")
			"comeback":
				if info:
					info.add("Comebacks")
			"revenge":
				if info:
					info.add("Revenge")
			"stun_count":
				if info:
					info.high("Most stunned", ev.count)
			"close_call":
				_banner(tr("Close call! You stayed alive near a hunter."))
				if info:
					info.high("Close call", 8)
			"place":
				_banner(tr("You can see the surface!") if ev.what == "surface" else tr("You are entering deeper waters."))
			"mission":
				_banner(tr("Mission complete!"))
				_snd("chime")
			"grow":
				_banner(tr("You grew!"))
				bump = 0.25
			"level":
				_banner(tr("Size %d!") % int(ev.level))     # DNA comes one point at a time from the 🧬 bar
				_play_music()
				_snd("evolve")
				bump = 0.3
			"dna":
				_banner(tr("+1 DNA"))
			"dna_tick":
				# A full 🧬 bar: a green sparkle on you and a soft chime, no banner (it comes every few meals).
				_spawn_burst(engine.player.pos, Color("7dff3a"), 8, 140.0, 3.0, EvEngine.radius_of(engine.player.mass) * 1.6)
				_snd("chime", 1.5, -10.0)
			"seen":
				pass                # no labels: you find out what things are by meeting them
			"ailment":
				_banner(tr("Poisoned: %s") % tr(Data.AILMENTS[ev.id].name))
				_snd("poison")
			"resist":
				var rs: Dictionary = Data.RESISTS[ev.id]
				var rank_txt := "%d/%d" % [int(ev.rank), Data.RESIST_AT.size()]
				_snd("evolve")
				if int(ev.rank) == 1:
					_show_popup(tr("Your body adapted!"), tr("You got %s so often that you resist it now: %s %s, free.") % [tr(Data.AILMENTS[ev.id].name), tr(rs.name), rank_txt] + "\n" + tr(rs.desc))
				else:
					_banner(tr(rs.name) + " " + rank_txt)
			"immune":
				_banner(tr("Immune to %s") % tr(Data.AILMENTS[ev.id].name))
			"env":
				_banner(tr("Too cold! Swim toward warmer water, or evolve Antifreeze.") if ev.what == "cold" else tr("Too deep! The pressure hurts: swim up, or evolve Pressure cells."))
				hurt = 1.0
				_snd("bite", 0.6)
			"env_warn":
				_banner(tr("The water is getting colder. Turn back soon!") if ev.what == "cold" else tr("The water is getting deeper. Turn back soon!"))
			"rare_dna":
				_banner(tr("%s: +%d DNA") % [tr(str(Data.species_of(ev.species).name)), int(ev.dna)])
			"rare":
				_banner(tr("Rare trait: %s") % tr(str(ev.name)))
				_spawn_burst(engine.player.pos, Color("ffd23f"), 24, 260.0, 5.0, EvEngine.radius_of(engine.player.mass) * 2.0)
				_snd("evolve")
			"hurt":
				hurt = 1.0
				_snd("bite")
			"dash":
				_spawn_burst(ev.pos, color, 10, 300.0, 4.0, 0.0)
				_snd("whoosh")
			"spit":
				_snd("spit")
			"ink", "lure", "camo", "decoy", "suction", "grab", "sonar":
				_snd("whoosh", 0.8)
			"spit_hit":
				_spawn_burst(ev.pos, Color("9bff5a"), 8, 140.0, 4.0, 0.0)
			"shock":
				var shock_col := Color("7be0ff") if ev.id == "shock" else Color("ffffff")
				_spawn_burst(ev.pos, shock_col, 24, 420.0, 4.0, ev.radius)
				_snd("zap")
			"death":
				_spawn_burst(ev.pos, color, 46, 420.0, 7.0, EvEngine.radius_of(engine.player.mass) * 2.2)

func _update_particles(delta: float) -> void:
	for p in particles:
		p.pos += p.vel * delta
		p.vel *= maxf(0.0, 1.0 - 2.2 * delta)
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0.0)
	bump = maxf(0.0, bump - delta * 0.5)
	hurt = maxf(0.0, hurt - delta * 1.5)

# ---------- drawing ----------

func _w2s(p: Vector2) -> Vector2:
	return (p - engine.player.pos) * zoom + field.size / 2.0

## The cell parts on your body (nucleus, vacuoles ...) fade out between size 2 and size 3.
func _cell_fade() -> float:
	var pm: float = engine.player.mass
	return clampf((Data.LEVELS[2] - pm) / (Data.LEVELS[2] - Data.LEVELS[1]), 0.0, 1.0)

func _player_state() -> Dictionary:
	return {
		"cell": _cell_fade(),
		"move_rank": engine.move_rank, "sight_rank": engine.sight_rank, "eye_open": eye_open, "tail_grow": tail_grow,
		"owned": engine.owned, "specials": engine.specials, "ailments": engine.ailments,
		"speed": clampf(engine.player.vel.length() / 300.0, 0.0, 1.0), "voodoo": voodoo,
		"dash": engine.dash_t > 0.0, "lurch": lurch, "col2": color2, "col3": color3,
	}

func _draw_field() -> void:
	var s := field.size
	_update_water(s)
	if engine == null:
		return
	_update_overlay(s)
	_draw_surface(s)
	var c := s / 2.0
	var lim := vis_r * 1.3
	var margin := 40.0
	# Food: glowing spores that breathe.
	var fr: float = maxf(EvEngine.radius_of(EvEngine.TUNING.food_mass) * zoom, 3.0)
	# Food specks are always there, at every size (owner 2026-10-24: they used to vanish at size 4); once they are
	# far smaller than you they are drawn a little fainter, as specks in the water.
	var food_a: float = 1.0 if engine.visibility_of(EvEngine.TUNING.food_mass) >= 1.0 else 0.7
	for i in engine.food.size():
		var sp := _w2s(engine.food[i])
		if sp.x < -margin or sp.y < -margin or sp.x > s.x + margin or sp.y > s.y + margin or sp.distance_to(c) > lim:
			continue
		var col: Color = FOOD[i % FOOD.size()]
		var br := 1.0 + 0.18 * sin(pulse * 3.0 + float(i) * 1.7)
		Art.disc(field, sp, fr * 3.4 * br, Color(col, 0.07 * food_a))
		Art.disc(field, sp, fr * 2.0 * br, Color(col, 0.16 * food_a))
		Art.disc(field, sp, fr * br, Color(col, food_a))
		Art.disc(field, sp - Vector2(fr, fr) * 0.25, fr * 0.35, Color(1, 1, 1, 0.8 * food_a))
	# Other creatures, small first so big ones cover them.
	var pm: float = engine.player.mass
	var ratio: float = engine.eat_ratio()
	var list: Array = engine.npcs.duplicate()
	list.sort_custom(_by_mass)
	for n in list:
		var sp2 := _w2s(n.pos)
		var r: float = EvEngine.radius_of(n.mass) * zoom
		if sp2.x < -r * 2.0 - margin or sp2.y < -r * 2.0 - margin or sp2.x > s.x + r * 2.0 + margin or sp2.y > s.y + r * 2.0 + margin or sp2.distance_to(c) > lim + r:
			continue
		var vis: float = engine.visibility_of(n.mass)
		if n.role == "rare" or n.role == "toxic":
			vis = 1.0             # special creatures are always shown
		if vis <= 0.0:
			continue
		if vis < 1.0:
			Art.disc(field, sp2, maxf(r * 0.6, 2.0), Color(1, 1, 1, 0.28))   # worth nothing to you: a drifting particle
			continue
		var kind := "none"
		if n.role == "toxic" or n.role == "rare":
			kind = n.role
		elif n.role == "hunter" and EvEngine.can_eat(n.mass, pm):
			kind = "hunter"           # just a red glow, no label
		var hd: float = n.vel.angle() if n.vel.length() > 4.0 else n.wander.angle()
		Art.draw_halo(field, sp2, r, kind, pulse)
		Art.draw_creature(field, sp2, r, Data.species_of(n.species), hd, pulse, float(int(n.id) % 97) * 1.37, voodoo, EvEngine.size_level(n.mass), engine.level() <= 2)
	# Effects under the player's own cell
	for p in particles:
		var a2: float = clampf(p.life / p.max, 0.0, 1.0)
		var pp: Vector2 = _w2s(p.pos)
		if p.ring > 0.0:
			var rr: float = p.ring * zoom * (1.2 - a2 * 0.6)
			Art.arc(field, pp, rr, 0.0, TAU, 40, Color(p.col, a2 * 0.7), 3.0, true)
		else:
			Art.disc(field, pp, p.size * zoom + 1.0, Color(p.col, a2))
	# Ability effects: the ink cloud, acid shots, the lure's glow.
	if engine.ink_t > 0.0:
		var ir: float = engine.ability_radius("ink") * zoom
		var ic := _w2s(engine.ink_pos)
		for q in 7:
			var off := Vector2.RIGHT.rotated(float(q) * 0.9 + pulse * 0.2) * ir * 0.45
			Art.disc(field, ic + off, ir * (0.55 + 0.05 * sin(pulse + float(q))), Color(0.25, 0.15, 0.4, 0.28 * minf(engine.ink_t, 1.0)))
	for sh in engine.shots:
		var sp3 := _w2s(sh.pos)
		if sh.get("kind", "spit") == "harpoon":
			var back: Vector2 = sh.vel.normalized() * 44.0 * zoom
			field.draw_line(sp3 - back, sp3, Color("d58bff"), 4.0, true)
			Art.disc(field, sp3, 6.0 * zoom + 2.0, Color("f0c8ff"))
		else:
			Art.disc(field, sp3, 10.0 * zoom + 3.0, Color("9bff5a", 0.25))
			Art.disc(field, sp3, 5.0 * zoom + 2.0, Color("c8ff8a"))
	# The decoy: a pale copy of you.
	if engine.decoy.t > 0.0:
		var dc := _w2s(engine.decoy.pos)
		var dr: float = EvEngine.radius_of(pm) * zoom
		Art.draw_player(field, dc, dr, color, engine.decoy.vel.angle() if engine.decoy.vel.length() > 5.0 else heading, pulse, _player_state())
		Art.disc(field, dc, dr * 1.2, Color(BG, 0.4))
		Art.arc(field, dc, dr * 1.3, 0.0, TAU, 24, Color(color, 0.5), 2.0, true)
	# Tentacles holding a creature; suction pulling prey in.
	for n in engine.npcs:
		if n.get("held", 0.0) > 0.0:
			var hp3 := _w2s(n.pos)
			field.draw_line(c, hp3, Color(color, 0.8), maxf(EvEngine.radius_of(pm) * zoom * 0.12, 3.0), true)
	if engine.suction_t > 0.0:
		var sr: float = engine.ability_radius("suction") * zoom
		for q in 10:
			var f := fposmod(pulse * 1.3 + float(q) * 0.1, 1.0)
			var dir := Vector2.RIGHT.rotated(TAU * float(q) / 10.0)
			field.draw_line(c + dir * sr * (1.0 - f), c + dir * sr * (1.0 - f - 0.1), Color(color, 0.5 * f), 3.0, true)
	if engine.alive:
		var pr: float = EvEngine.radius_of(pm) * zoom * (1.0 + bump)
		if engine.lure_t > 0.0:
			var tip := c + Vector2.RIGHT.rotated(heading) * pr * 2.1
			field.draw_line(c + Vector2.RIGHT.rotated(heading) * pr * 0.8, tip, Color(color, 0.8), maxf(pr * 0.08, 2.0), true)
			var lg := 1.0 + 0.2 * sin(pulse * 6.0)
			Art.disc(field, tip, pr * 0.5 * lg, Color(1, 0.95, 0.5, 0.9))
			Art.disc(field, tip, pr * 1.2 * lg, Color(1, 0.95, 0.5, 0.18))
			Art.arc(field, c, engine.ability_radius("lure") * zoom, 0.0, TAU, 64, Color(1, 0.95, 0.5, 0.12), 2.0, true)
		Art.draw_player(field, c, pr, color, heading, pulse, _player_state())
		if engine.camo_t > 0.0:
			Art.disc(field, c, pr * 1.15, Color(BG, 0.55))
			Art.arc(field, c, pr * 1.3, 0.0, TAU, 24, Color(1, 1, 1, 0.3), 2.0, true)

func _update_overlay(s: Vector2) -> void:
	var blur: float = Data.BLUR[engine.clarity()]
	if engine.sight_rank <= 1:
		blur += 0.9
	var mat: ShaderMaterial = _blur_mat if blur > 0.01 else _dark_mat
	if mat == null:
		return
	if overlay.material != mat:
		overlay.material = mat
	mat.set_shader_parameter("center", s / 2.0)
	mat.set_shader_parameter("rect_size", s)
	mat.set_shader_parameter("radius", vis_r)
	if mat == _blur_mat:
		mat.set_shader_parameter("blur", blur * 2.5)      # a circle of this many pixels, wider toward the edge of your sight
		mat.set_shader_parameter("radial", blur * 0.035)  # ... and streaks bursting out from you (radial blur)

## The water darkens with depth: a pale blue near the surface, almost black below about 150 m. It is the
## cue that tells you how far down you are (a number alone did not: owner 2026-10-23).
func _water_col() -> Color:
	var shallow := Color(0.03, 0.12, 0.19) if not voodoo else Color(0.12, 0.04, 0.2)
	var f := clampf(engine.depth_m() / 150.0, 0.0, 1.0)
	return shallow.lerp(BG, 1.0 - pow(1.0 - f, 2.0))

static func _by_mass(x, y) -> bool:
	return x.mass < y.mass

## Grid cell size and parallax of the water's layers (the same numbers as CS / PAR in WATER_SHADER).
const WATER_LAYERS := [[900.0, 0.25], [240.0, 0.45], [190.0, 0.75], [160.0, 1.0]]

## The water behind the field: its colour, and how many blobs / specks each layer needs to fill the screen.
func _update_water(s: Vector2) -> void:
	water.color = BG if engine == null else _water_col()
	var mat := _water_specks.material as ShaderMaterial
	if engine == null or mat == null:
		_water_mm.visible_instance_count = 0
		return
	var z := maxf(zoom, 0.05)
	var starts := [0, 0, 0, 0]
	var cols := [1, 1, 1, 1]
	var total := 0
	for i in WATER_LAYERS.size():
		var cs: float = WATER_LAYERS[i][0]
		starts[i] = total
		cols[i] = int(ceilf(s.x / (cs * z))) + 3
		total += cols[i] * (int(ceilf(s.y / (cs * z))) + 3)
	if total > _water_mm.instance_count:
		_grow_water(total + 500)
	_water_mm.visible_instance_count = total
	mat.set_shader_parameter("cam", engine.player.pos)
	mat.set_shader_parameter("zoom", z)
	mat.set_shader_parameter("rect_size", s)
	mat.set_shader_parameter("clock", pulse)
	mat.set_shader_parameter("tint", Color("0b2f4a") if not voodoo else Color("2a0b46"))
	mat.set_shader_parameter("lay_start", Vector4i(starts[0], starts[1], starts[2], starts[3]))
	mat.set_shader_parameter("lay_cols", Vector4i(cols[0], cols[1], cols[2], cols[3]))

## Room for n quads (the shader moves them; each only needs an identity transform).
func _grow_water(n: int) -> void:
	_water_mm.instance_count = n
	for i in n:
		_water_mm.set_instance_transform_2d(i, Transform2D.IDENTITY)

## The surface of the water: the only edge of the pond (sides and depth never end).
func _draw_surface(s: Vector2) -> void:
	var sy := _w2s(Vector2.ZERO).y
	if sy < -30.0:
		return
	var lit := Color("5fb4d8") if not voodoo else Color("b57dff")
	var dark := Color("0b1522") if not voodoo else Color("14081f")
	# the air above
	field.draw_polygon(PackedVector2Array([Vector2(0, -10), Vector2(s.x, -10), Vector2(s.x, sy), Vector2(0, sy)]), PackedColorArray([dark, dark, lit, lit]))
	# light rays under the surface
	for i in 9:
		var x := fposmod(float(i) * s.x / 8.0 + engine.player.pos.x * 0.05 * zoom + sin(pulse * 0.3 + float(i)) * 30.0, s.x + 200.0) - 100.0
		var wdt := (50.0 + 30.0 * float(i % 3)) * zoom
		field.draw_polygon(PackedVector2Array([Vector2(x - wdt * 0.2, sy), Vector2(x + wdt * 0.2, sy), Vector2(x + wdt * 1.6, sy + 520.0 * zoom), Vector2(x - wdt * 1.2, sy + 520.0 * zoom)]),
			PackedColorArray([Color(lit, 0.10), Color(lit, 0.10), Color(lit, 0.0), Color(lit, 0.0)]))
	# the wavy line
	var pts := PackedVector2Array()
	var step := 20.0
	var xs := -step
	while xs <= s.x + step:
		pts.append(Vector2(xs, sy + sin(xs * 0.03 + pulse * 1.6 + engine.player.pos.x * 0.02 * zoom) * 3.5 * zoom + sin(xs * 0.011 - pulse * 0.9) * 2.0))
		xs += step
	Art.strip(field, pts, Color(lit, 0.25), 12.0, true)
	Art.strip(field, pts, Color(0.85, 0.97, 1.0, 0.95), 3.0, true)

## Above the vision overlay: what the other senses pick up, the red damage edge and the banners.
func _draw_senses() -> void:
	var s := fx.size
	var c := s / 2.0
	var pm: float = engine.player.mass
	# Rare creatures send ripples through the water: faint rings show a little past the edge of your sight.
	for n in engine.npcs:
		if n.role != "rare":
			continue
		var spr: Vector2 = _w2s(n.pos)
		var dr := spr.distance_to(c)
		if dr > vis_r * 0.9 and dr < vis_r * 1.8:
			Art.draw_ripples(fx, spr, maxf(EvEngine.radius_of(n.mass) * zoom, 8.0), pulse, 0.5)
	if engine.has("chemical"):
		var lim := vis_r * 1.9
		for f in engine.food:
			var sp: Vector2 = _w2s(f)
			var dd := sp.distance_to(c)
			if dd > vis_r and dd < lim and sp.x > 0.0 and sp.y > 0.0 and sp.x < s.x and sp.y < s.y:
				Art.disc(fx, sp, 3.0, Color("ffd23f", 0.55))
		for n in engine.npcs:
			if n.role == "hunter":
				continue
			var sp2: Vector2 = _w2s(n.pos)
			var d2 := sp2.distance_to(c)
			if d2 > vis_r and d2 < lim and sp2.x > 0.0 and sp2.y > 0.0 and sp2.x < s.x and sp2.y < s.y:
				Art.disc(fx, sp2, 6.0, Color("7dff3a", 0.6) if EvEngine.can_eat(pm, n.mass, engine.eat_ratio()) else Color(1, 1, 1, 0.4))
	if engine.sonar_t > 0.0:
		var rad: float = engine.ability_radius("sonar") * zoom
		var wave := fposmod(pulse * 0.8, 1.0)
		Art.arc(fx, c, rad * wave, 0.0, TAU, 64, Color("7be0ff", 0.5 * (1.0 - wave)), 4.0, true)
		for n in engine.npcs:
			var sp4: Vector2 = _w2s(n.pos)
			if sp4.distance_to(c) > rad or sp4.x < 0.0 or sp4.y < 0.0 or sp4.x > s.x or sp4.y > s.y:
				continue
			var rr: float = maxf(EvEngine.radius_of(n.mass) * zoom, 6.0)
			var col4 := Color("ff4f9a") if n.role == "hunter" and EvEngine.can_eat(n.mass, pm) else (Color("7dff3a") if EvEngine.can_eat(pm, n.mass, engine.eat_ratio()) else Color(1, 1, 1, 0.8))
			Art.arc(fx, sp4, rr * 1.2, 0.0, TAU, 20, Color(col4, 0.9), 2.5, true)
	if engine.has("listening"):
		var reach := vis_r * (3.5 if engine.has("radar") else 1.8)
		for n in engine.npcs:
			if n.role != "hunter" or not EvEngine.can_eat(n.mass, pm):
				continue
			var d: Vector2 = (n.pos - engine.player.pos) * zoom
			var dist := d.length()
			if dist < vis_r * 0.95 or dist > reach:
				continue
			var dir := d / dist
			var at := c + dir * minf(minf(s.x, s.y) * 0.44, vis_r * 0.92)
			var k := 1.0
			if engine.has("radar"):
				k = clampf(n.mass / maxf(pm, 1.0) / 1.5, 0.8, 2.4)
			var al := clampf(1.3 - dist / reach, 0.35, 1.0)
			var perp := dir.orthogonal()
			var tri := PackedVector2Array([at + dir * 18.0 * k, at - dir * 10.0 * k + perp * 12.0 * k, at - dir * 10.0 * k - perp * 12.0 * k])
			fx.draw_colored_polygon(tri, Color("ff4f9a", 0.4 * al))
			tri.append(tri[0])
			Art.strip(fx, tri, Color("ff4f9a", al), 2.5, true)

## Above the vision overlay: the red damage edge and the banners.
func _draw_fx() -> void:
	var s := fx.size
	if engine != null and started:
		_draw_senses()
	if engine != null and started and engine.has_bars():
		var chill := clampf((engine.min_temp() + 3.0 - engine.temp()) / 6.0, 0.0, 1.0)   # icy tint as the water nears your cold limit
		if chill > 0.0:
			fx.draw_rect(Rect2(Vector2.ZERO, s), Color(0.55, 0.85, 1.0, 0.16 * chill))
	if hurt > 0.0:
		var h := Color("ff4f9a")
		h.a = 0.28 * minf(hurt, 1.0)
		var z := Color(h, 0.0)
		var w := minf(s.x, s.y) * 0.28
		fx.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, s.y), Vector2(0, s.y)]), PackedColorArray([h, z, z, h]))
		fx.draw_polygon(PackedVector2Array([Vector2(s.x, 0), Vector2(s.x - w, 0), Vector2(s.x - w, s.y), Vector2(s.x, s.y)]), PackedColorArray([h, z, z, h]))
	if banners.size() > 0:
		var b: Dictionary = banners[0]
		var al := clampf(b.t, 0.0, 1.0)
		# Between the left HUD and the mission list when there is room (landscape), else under the HUD;
		# long banners shrink to fit.
		var side: float = (bars_panel.size.x + 40.0) if bars_panel.visible else 0.0
		var avail := s.x - 2.0 * side
		var by := s.y * 0.2
		if avail < 360.0:
			avail = s.x * 0.92
			by = maxf(by, bars_panel.get_global_rect().end.y - fx.get_global_rect().position.y + 30.0) if bars_panel.visible else by
		var bw := ThemeDB.fallback_font.get_string_size(str(b.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var fs := clampi(int(34.0 * minf(1.0, avail / maxf(bw, 1.0))), 16, 34)
		HomeKit.glow_text(fx, Vector2(s.x / 2.0, by), str(b.text), fs, Color(color.lerp(Color.WHITE, 0.4), al))

func _draw_home_logo(c: Control) -> void:
	var o := c.size / 2.0
	var k := minf(c.size.y / 3.0, 44.0)
	Art.draw_halo(c, o + Vector2(-2.7, 0.5) * k, 0.6 * k, "prey", pulse)
	Art.draw_creature(c, o + Vector2(-2.7, 0.5) * k, 0.6 * k, Data.species_of("bacillus"), 0.4, pulse, 3.0, false)
	Art.draw_halo(c, o + Vector2(2.5, -0.3) * k, 1.35 * k, "hunter", pulse)
	Art.draw_creature(c, o + Vector2(2.5, -0.3) * k, 1.35 * k, Data.species_of("corona"), PI, pulse, 5.0, false)
	Art.draw_player(c, o + Vector2(-0.3, 0.0) * k, 1.05 * k, color, 0.0, pulse, {"move_rank": 2, "sight_rank": 3, "owned": {}, "speed": 0.3, "voodoo": false, "col2": color2, "col3": color3})

# ---------- pause / skin ----------

func _on_pause() -> void:
	_flush_stats()
	controls.release()
	home.pause()

func _go_home() -> void:
	_flush_stats()
	home.go_home()

## Called by the Landing kit's skin switch: re-skin in place.
func _set_skin(skin: String) -> void:
	voodoo = skin == "voodoo"
	if field:
		field.queue_redraw()
	if _preview:
		_preview.queue_redraw()

func _current_skin() -> String:
	return "voodoo" if voodoo else "classic"

## Evolution's own synthesized sounds, through the app's Sfx (older apps without it stay silent).
var _snd_ms := {}
func _snd(sound: String, pitch: float = 1.0, db: float = 0.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_snd_ms.get(sound, -1000)) < 40:
		return
	_snd_ms[sound] = now
	var sfx = get_node_or_null("/root/Sfx")
	if sfx and sfx.has_method("play_stream"):
		sfx.play_stream(Sound.stream(sound), db, pitch, "game")

## Music from the shared Music autoload (owner rule: every game; older apps without it stay silent).
## Calm while you are small, lively from size 6 (Predator) on. Asking for what already plays does nothing.
const MUSIC_LIVELY_AT := 6
func _play_music() -> void:
	if engine.level() >= MUSIC_LIVELY_AT:
		_music_node_call("play", "lively", 1)
	else:
		_music_node_call("play", "calm", 0)

func _music_node_call(what: String, style: String, index: int) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	if what == "prepare":
		m.prepare(style, index)
	else:
		m.play(style, self, index)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
