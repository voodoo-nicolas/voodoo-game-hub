extends Control

## Ink Ninja cutscenes: procedural sumi-e painted in _draw(), every frame computed from
## the scene time t (a port of the owner's D:\Dev\ink_ninja_cutscenes.html, 2026-11-15).
## Everything is drawn in a 1280 x 720 frame, centred and scaled to fit the height.
##
##   var cut = load("res://scripts/games/ink_ninja/cutscene.gd").new()
##   add_child(cut); cut.finished.connect(_on_cut_done)
##   cut.play("intro")
##
## All 12 scenes of the storyboard are here (_draw matches the id). Two wait for the
## player: 'seal' holds on the SLASH prompt until a Slash (tap, J, Space or Enter);
## 'ending-b' holds for a Slash (refuse the face) or 10 s (the brush lowers and leaves).
## Colour rule (owner): RED is Lord Shu's only; the one exception is the crane's crown.
##
## Helpers ported from the HTML: brush (bristle stroke, one draw_multiline_colors call),
## wash (radial texture), bloom, mountains (polygon + gradient texture by UV), fog, pine,
## grass, ground, stamp, caption, sumi, crane, hand, rain, cam, vignette, black, ink_wipe,
## freed_bow, region_shot. Seal glyphs are drawn as strokes (CJK glyphs are missing on
## many phones).

signal finished(id: String)

const SoundLib = preload("res://scripts/games/ink_ninja/sound_lib.gd")
const W := 1280.0
const H := 720.0
const INK := Color("141210")
const RED := Color("a3201a")   # Lord Shu only (and the crane's crown)
const PAPER := Color("ece4d3")
const WASH_INK := Color(20 / 255.0, 18 / 255.0, 16 / 255.0)
const WASH_RED := Color(163 / 255.0, 32 / 255.0, 26 / 255.0)
const WASH_FOG := Color(240 / 255.0, 234 / 255.0, 222 / 255.0)
const SEEN_PATH := "user://ink_ninja_cutscenes.json"

## id -> duration and cue list [time, sound] (cue names from the HTML). "wait": [hold at,
## resume at, idle timeout or 0]: the scene stops at `hold` until slash_input().
const SCENES := {
	"intro": {"dur": 30.0, "cues": [[1.0, "bell"], [9.5, "stamp"], [21.0, "flute"]]},
	"drip": {"dur": 12.0, "cues": [[3.0, "drip"], [6.5, "stamp"]]},
	"after-1B": {"dur": 16.0, "cues": [[1.0, "crack"], [3.0, "flute"], [8.0, "wind"]]},
	"after-2B": {"dur": 16.0, "cues": [[1.0, "roar"], [4.0, "whoosh"], [8.0, "water"]]},
	"after-3B": {"dur": 22.0, "cues": [[1.0, "flute"], [11.0, "stamp"], [13.0, "fall"]]},
	"act4": {"dur": 14.0, "cues": [[1.0, "lantern"], [6.0, "flute"]]},
	"after-4B": {"dur": 18.0, "cues": [[1.0, "crack"], [6.0, "flute"]]},
	"act5": {"dur": 14.0, "cues": [[2.0, "thunder"], [7.0, "thunder"], [9.5, "stamp"]]},
	"after-5B": {"dur": 18.0, "cues": [[1.0, "crack"], [3.5, "flute"], [9.0, "silence"]]},
	"seal": {"dur": 16.0, "cues": [[1.5, "stamp"], [4.0, "silence"]], "wait": [12.5, 14.0, 0.0]},
	"ending-a": {"dur": 30.0, "cues": [[1.0, "flute"], [20.0, "bell"]]},
	"ending-b": {"dur": 22.0, "cues": [[2.0, "flute"], [16.0, "bell"]], "wait": [10.7, 10.8, 10.0]},
}

## Where each scene plays: the story bible's own slots, now that the game has its
## 24 stages (owner 2026-11-15). Stage n of act a = (a - 1) * 4 + n; 4, 8... are bosses.
const SLOTS := {
	"before:1": ["intro"],              # before 1-1
	"before:3": ["drip"],               # before 1-3
	"before:5": ["after-1B"],           # after 1-B, before 2-1
	"before:9": ["after-2B"],           # after 2-B, before 3-1
	"before:13": ["after-3B", "act4"],  # after 3-B; before 4-1
	"before:17": ["after-4B", "act5"],  # after 4-B; before 5-1
	"before:21": ["after-5B"],          # after 5-B, before 6-1
	"final": ["seal", "ending-a"],      # 6-B phase 3 (waits for Slash), then Ending A
	"final_all_scrolls": ["ending-b"],  # after Ending A when every scroll was found
}

var id := ""
var t := 0.0
var last := -1.0
var playing := false
var seen := {}
var skip_btn: Button
var paper_fx: ColorRect
var wait_done := false   # the scene's input wait is over (slashed or timed out)
var wait_t := 0.0
var idle := false        # ending-b: the player let the brush go (no Slash)

var _xf := Transform2D.IDENTITY
var _a := 1.0
var _stack: Array = []
var _base := Transform2D.IDENTITY
var _font: Font
var _italic: FontVariation
var _bold: FontVariation
var _wash_tex: Texture2D
var _vig_tex: Texture2D
var _mtn_tex: Texture2D
var _fade_tex: Texture2D
var _cache := {}   # finished brush strokes: shape key -> [points, colours, width] (local to the first point)

## The scenes for a slot, in order ([] = none). Duplicated: arrays in a const are read-only.
static func for_slot(key: String) -> Array:
	return (SLOTS.get(key, []) as Array).duplicate()

## The scenes that play before this stage.
static func for_stage(stage: int) -> Array:
	return for_slot("before:%d" % stage)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # nothing under a cutscene is pressed through
	visible = false
	_font = ThemeDB.fallback_font
	_italic = FontVariation.new()
	_italic.base_font = _font
	_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	_bold = FontVariation.new()
	_bold.base_font = _font
	_bold.variation_embolden = 1.0
	_wash_tex = _radial([0.0, 0.6, 1.0], [1.0, 0.55, 0.0])
	_vig_tex = _radial([0.0, 0.42, 1.0], [0.0, 0.0, 1.0])
	_mtn_tex = _vertical([0.0, 0.55, 1.0], [Color(30 / 255.0, 28 / 255.0, 26 / 255.0, 1.0), Color(60 / 255.0, 56 / 255.0, 50 / 255.0, 0.45), Color(60 / 255.0, 56 / 255.0, 50 / 255.0, 0.0)])
	_fade_tex = _vertical([0.0, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	# The game's paper grain over the painting (the HTML multiplies its paper on top).
	var sh = load("res://scripts/games/ink_ninja/ink_ninja_paper.gdshader")
	if sh:
		paper_fx = ColorRect.new()
		paper_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		paper_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("grain_col", Color(0.3, 0.27, 0.22))
		m.set_shader_parameter("edge_col", Color(0.27, 0.2, 0.12))
		m.set_shader_parameter("grain", 0.12)
		m.set_shader_parameter("edge", 0.3)
		paper_fx.material = m
		add_child(paper_fx)
	skip_btn = Button.new()
	skip_btn.text = tr("Skip ›")
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_btn.offset_left = -170
	skip_btn.offset_top = -78
	skip_btn.offset_right = -24
	skip_btn.offset_bottom = -24
	skip_btn.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(20 / 255.0, 18 / 255.0, 16 / 255.0, 0.55)
	sb.border_color = Color(1, 1, 1, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	for st in ["normal", "hover", "pressed"]:
		skip_btn.add_theme_stylebox_override(st, sb)
	skip_btn.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93))
	skip_btn.set_meta("sfx", "")
	skip_btn.pressed.connect(_end)
	skip_btn.visible = false
	add_child(skip_btn)
	_load_seen()

func has_scene(scene: String) -> bool:
	return SCENES.has(scene)

func was_seen(scene: String) -> bool:
	return seen.has(scene)

func play(scene: String) -> void:
	if not SCENES.has(scene):
		finished.emit(scene)
		return
	id = scene
	t = 0.0
	last = -1.0
	playing = true
	visible = true
	skip_btn.visible = false
	wait_done = false
	wait_t = 0.0
	idle = false
	_cache.clear()
	var m = get_node_or_null("/root/Music")
	if m and m.has_method("stop"):
		m.stop(1.0)
	queue_redraw()

func _process(delta: float) -> void:
	if not playing:
		return
	t += minf(delta, 0.1)
	var sc: Dictionary = SCENES[id]
	if sc.has("wait") and not wait_done and t >= sc.wait[0]:
		t = sc.wait[0]   # hold the frame until the player slashes
		wait_t += minf(delta, 0.1)
		if sc.wait[2] > 0.0 and wait_t >= sc.wait[2]:
			idle = true
			wait_done = true
	for c in sc.cues:
		if c[0] > last and c[0] <= t:
			_cue(c[1])
	last = t
	# Skip after 1 s; the intro only once it has been seen in full or skipped before.
	skip_btn.visible = t >= 1.0 and (id != "intro" or seen.has("intro"))
	if t >= sc.dur:
		_end()
	queue_redraw()

## The player's Slash during a scene that waits for it. True when it was used.
func slash_input() -> bool:
	if not playing or wait_done or not SCENES[id].has("wait") or t < SCENES[id].wait[0] - 0.01:
		return false
	wait_done = true
	t = SCENES[id].wait[1]
	last = t
	_cue("slash")
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if slash_input():
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if playing and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_J, KEY_SPACE, KEY_ENTER]:
		if slash_input():
			get_viewport().set_input_as_handled()

func _end() -> void:
	if not playing:
		return
	playing = false
	visible = false
	skip_btn.visible = false
	seen[id] = true
	_save_seen()
	finished.emit(id)

func _load_seen() -> void:
	if not FileAccess.file_exists(SEEN_PATH):
		return
	var f := FileAccess.open(SEEN_PATH, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			seen = d

func _save_seen() -> void:
	var f := FileAccess.open(SEEN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(seen))

# ---------- sound (placeholders from the shared sound library; cue names from the HTML) ----------

func _cue(name: String) -> void:
	match name:
		"bell":
			SoundLib.play(self, "impact/bell_heavy", -8.0, "game", 1.6)
		"stamp":
			SoundLib.play(self, "impact/wood_heavy", 0.0, "game", 0.55)
			SoundLib.play(self, "impact/punch_heavy", -2.0, "game", 0.5)
		"crack":
			SoundLib.play(self, "impact/mining", -4.0, "game", 0.7)
		"wind":
			SoundLib.play(self, "weather/thunder_rain", -16.0)
		"drip":
			SoundLib.play(self, "impact/glass_light", -10.0, "game", 2.0)
		"roar":
			SoundLib.play(self, "scifi/low_frequency_explosion", -10.0, "game", 0.6)
		"whoosh":
			SoundLib.play(self, "rpg/draw_knife", -4.0, "game", 0.6)
		"water":
			SoundLib.play(self, "weather/thunder_rain", -20.0, "game", 0.8)
		"fall":
			SoundLib.play(self, "rpg/cloth", -6.0, "game", 0.7)
		"lantern":
			SoundLib.play(self, "impact/glass_light", -14.0, "game", 1.5)
		"thunder":
			SoundLib.play(self, "scifi/low_frequency_explosion", -4.0, "game", 0.5)
		"slash":
			SoundLib.play(self, "rpg/knife_slice", -2.0, "game", 0.9)
		"silence":
			var ms = get_node_or_null("/root/Music")
			if ms and ms.has_method("stop"):
				ms.stop(0.4)
		"flute":
			# No flute in the sound library yet: the shakuhachi phrase is the calm Asian
			# music track fading in (Music library, genre "asian"; older apps: any calm).
			var m = get_node_or_null("/root/Music")
			if m:
				if "library" in m:
					m.play("calm", self, 0, 2.5, "asian")
				else:
					m.play("calm", self, 0, 2.5)

# ---------- drawing ----------

var draw_ms := 0.0   # cost of the last _draw (tools/shot_ink_cutscenes.gd reports it)

func _draw() -> void:
	if not playing:
		return
	var t_start := Time.get_ticks_usec()
	var k := size.y / H
	_base = Transform2D(0.0, Vector2(k, k), 0.0, Vector2((size.x - W * k) / 2.0, 0.0))
	_xf = Transform2D.IDENTITY
	_a = 1.0
	_stack.clear()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_apply()
	var sc: Dictionary = SCENES[id]
	var tt := minf(t, float(sc.dur))
	match id:
		"intro":
			_intro(tt)
		"drip":
			_drip(tt)
		"after-1B":
			_after_1b(tt)
		"after-2B":
			_after_2b(tt)
		"after-3B":
			_after_3b(tt)
		"act4":
			_act4(tt)
		"after-4B":
			_after_4b(tt)
		"act5":
			_act5(tt)
		"after-5B":
			_after_5b(tt)
		"seal":
			_seal(tt)
		"ending-a":
			_ending_a(tt)
		"ending-b":
			_ending_b(tt)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# A thin progress line (grey: red is Lord Shu's).
	draw_rect(Rect2(0, size.y - 2, size.x * tt / float(sc.dur), 2), Color(INK, 0.35))
	draw_ms = (Time.get_ticks_usec() - t_start) / 1000.0

# ----- transform / alpha stack (canvas save / restore) -----

func _apply() -> void:
	draw_set_transform_matrix(_base * _xf)

func _save() -> void:
	_stack.append([_xf, _a])

func _restore() -> void:
	var s: Array = _stack.pop_back()
	_xf = s[0]
	_a = s[1]
	_apply()

func _translate(x: float, y: float) -> void:
	_xf = _xf * Transform2D(0.0, Vector2(x, y))
	_apply()

func _scale(sx: float, sy: float) -> void:
	_xf = _xf * Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2.ZERO)
	_apply()

func _rotate(r: float) -> void:
	_xf = _xf * Transform2D(r, Vector2.ZERO)
	_apply()

func _cam(z: float, px := 0.0, py := 0.0) -> void:
	_translate(W / 2 + px, H / 2 + py)
	_scale(z, z)
	_translate(-W / 2, -H / 2)

func _col(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a * _a)

# ----- maths (same as the HTML) -----

static func cl(v: float, a := 0.0, b := 1.0) -> float:
	return maxf(a, minf(b, v))

static func ss(a: float, b: float, v: float) -> float:
	v = cl((v - a) / (b - a))
	return v * v * (3.0 - 2.0 * v)

static func hsh(n: float) -> float:
	n = sin(n * 127.1 + 311.7) * 43758.5453
	return n - floorf(n)

static func h2(a: float, b: float) -> float:
	return hsh(a * 57.3 + b * 13.7)

# ----- textures -----

func _radial(offs: Array, alphas: Array) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	var cols := PackedColorArray()
	for a in alphas:
		cols.append(Color(1, 1, 1, a))
	g.colors = cols
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 128
	tx.height = 128
	return tx

func _vertical(offs: Array, cols: Array) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill_from = Vector2(0, 0)
	tx.fill_to = Vector2(0, 1)
	tx.width = 4
	tx.height = 64
	return tx

# ----- brush primitives -----

## Catmull-Rom through the control points, `steps` samples per span.
static func _curve(c: Array, steps := 12) -> Array:
	var o := []
	for i in c.size() - 1:
		var p0: Vector2 = c[maxi(0, i - 1)]
		var p1: Vector2 = c[i]
		var p2: Vector2 = c[i + 1]
		var p3: Vector2 = c[mini(c.size() - 1, i + 2)]
		for s in steps:
			var tt := float(s) / steps
			var t2 := tt * tt
			var t3 := t2 * tt
			o.append(0.5 * ((2.0 * p1) + (-p0 + p2) * tt + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	o.append(c[c.size() - 1])
	return o

## Bristle brush: w width, prog 0..1 draws it on, dry 0..1 dry-brush breaks, taper 0/1.
## All bristles go out in one draw_multiline_colors call (draw_polyline is slow in 4.7).
func brush(ctrl: Array, w: float, o := {}) -> void:
	var prog: float = o.get("prog", 1.0)
	if prog <= 0.0:
		return
	var col: Color = o.get("col", INK)
	var a: float = o.get("a", 1.0)
	var dry: float = o.get("dry", 0.35)
	var seed: float = o.get("seed", 1.0)
	var taper: bool = float(o.get("taper", 1)) != 0.0
	# A finished stroke is the same shape every frame (it may only move or sway): reuse it.
	var o0: Vector2 = ctrl[0]
	var rel := []
	for c in ctrl:
		rel.append(c - o0)
	var key := 0
	if prog >= 1.0:
		key = hash([rel, w, seed, dry, taper, col, snappedf(a * _a, 1.0 / 16.0)])
		if _cache.has(key):
			var e: Array = _cache[key]
			draw_set_transform_matrix(_base * _xf * Transform2D(0.0, o0))
			draw_multiline_colors(e[0], e[1], e[2])
			_apply()
			return
	ctrl = rel
	var P := _curve(ctrl, int(o.get("steps", 12)))
	var n := P.size()
	var lim := maxi(2, int(n * cl(prog)))
	var nb := maxi(5, mini(int(o.get("bristles", 22)), int(w / 1.4)))   # fewer for big strokes that change every frame
	var lw := maxf(0.6, w / nb * 1.9)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for b in nb:
		var off := float(b) / (nb - 1) - 0.5
		var ca := Color(col, col.a * snappedf(a * _a, 1.0 / 16.0) * (0.35 + 0.65 * h2(b, seed)))
		var pen := false
		var prev := Vector2.ZERO
		for i in lim:
			var u := float(i) / (n - 1)
			var q: Vector2 = P[i]
			var d: Vector2 = P[mini(n - 1, i + 1)] - P[maxi(0, i - 1)]
			var L := d.length()
			if L == 0.0:
				L = 1.0
			var tp := pow(sin(PI * cl(u * 0.92 + 0.04)), 0.55) if taper else 1.0
			var p := Vector2(q.x - d.y / L * off * w * tp, q.y + d.x / L * off * w * tp)
			if h2(b * 7 + i, seed) < dry * u * u * (absf(off) * 1.6 + 0.2):
				pen = false
				continue
			if pen:
				pts.append(prev)
				pts.append(p)
				cols.append(ca)
			prev = p
			pen = true
	if pts.size() < 2:
		return
	if prog >= 1.0:
		if _cache.size() > 4000:
			_cache.clear()
		_cache[key] = [pts, cols, lw]
	draw_set_transform_matrix(_base * _xf * Transform2D(0.0, o0))
	draw_multiline_colors(pts, cols, lw)
	_apply()

func wash(x: float, y: float, r: float, a: float, col := WASH_INK) -> void:
	if r <= 0.0 or a <= 0.0:
		return
	draw_texture_rect(_wash_tex, Rect2(x - r, y - r, r * 2, r * 2), false, _col(col, a))

## Ink blooming into wet paper: an irregular cluster of washes.
func bloom(x: float, y: float, r: float, a: float, seed: float, col := WASH_INK) -> void:
	for i in 7:
		var an := h2(i, seed) * 6.28
		var d := r * 0.35 * h2(i + 9, seed)
		wash(x + cos(an) * d, y + sin(an) * d, r * (0.5 + 0.5 * h2(i + 3, seed)), a * 0.45, col)

func mountains(base: float, amp: float, seed: float, a: float, shade := 0.9) -> void:
	if a <= 0.0:
		return
	var foot := base + 60.0   # the wash is clear from here down: no need to go to the bottom
	var pts := PackedVector2Array([Vector2(-20, foot)])
	var x := -20.0
	while x <= W + 20:
		var y := base - amp * (0.5 + 0.5 * sin(x * 0.004 + seed) * sin(x * 0.0013 + seed * 2)) - amp * 0.25 * sin(x * 0.02 + seed * 5) * h2(int(x) >> 6, seed)
		pts.append(Vector2(x, y))
		x += 8.0
	pts.append(Vector2(W + 20, foot))
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(Vector2(0.5, cl((minf(p.y, foot) - (base - amp)) / (amp + 60.0), 0.0, 1.0)))
	draw_polygon(pts, PackedColorArray([_col(Color(1, 1, 1, shade), a)]), uvs, _mtn_tex)

func fog(tt: float, a := 0.6, y0 := H * 0.55, spread := H * 0.5) -> void:
	for i in 9:
		var x := fmod(h2(i, 4) * W * 1.6 + tt * (8 + i * 3), W * 1.6) - W * 0.3
		var y := y0 + (h2(i, 8) - 0.5) * spread
		var r := 90.0 + h2(i, 5) * 80.0
		draw_texture_rect(_wash_tex, Rect2(x - r * 3.4, y - r, r * 6.8, r * 2), false, _col(WASH_FOG, 0.9 * a * (0.4 + 0.6 * h2(i, 2))))

func pine(x: float, y: float, s: float, seed: float, a := 1.0) -> void:
	if a <= 0.0:
		return
	brush([Vector2(x, y), Vector2(x + 6 * s, y - 60 * s), Vector2(x - 4 * s, y - 140 * s), Vector2(x + 5 * s, y - 220 * s)], 9 * s, {"a": a, "seed": seed, "dry": 0.5})
	for i in 7:
		var yy := y - (60 + i * 24) * s
		var dir := 1.0 if i % 2 else -1.0
		var ln := (70 - i * 7) * s
		brush([Vector2(x, yy), Vector2(x + dir * ln * 0.5, yy - 6 * s), Vector2(x + dir * ln, yy + 4 * s)], 4 * s, {"a": a, "seed": seed + i, "dry": 0.6})
		for kk in 4:
			wash(x + dir * ln * (0.3 + kk * 0.2), yy - 4 * s, 16 * s, 0.35 * a)

func grass(y: float, seed: float, a := 0.8) -> void:
	if a <= 0.0:
		return
	for i in 70:
		var x := h2(i, seed) * W
		var hh := 10.0 + h2(i, seed + 1) * 26.0
		brush([Vector2(x, y + 4), Vector2(x + 3, y - hh * 0.6), Vector2(x + 8 * (h2(i, 9) - 0.3), y - hh)], 2.2, {"a": a * 0.8, "seed": i, "dry": 0.3})

func ground(y: float, prog: float, seed := 2.0, a := 1.0) -> void:
	brush([Vector2(-40, y + 6), Vector2(W * 0.25, y - 4), Vector2(W * 0.55, y + 5), Vector2(W * 0.8, y - 3), Vector2(W + 40, y + 4)], 22, {"prog": prog, "a": a, "seed": seed, "dry": 0.55, "taper": 0})
	if prog > 0.0:
		draw_texture_rect(_fade_tex, Rect2(0, y, W * prog, 120), false, _col(Color(30 / 255.0, 28 / 255.0, 25 / 255.0, 0.55), a * 0.5))

## Lord Shu's seal: a red square with chipped edges and a carved glyph in paper strokes.
## glyph: 0 = "collect" (收), 1 = "seal" (印), drawn as strokes, not a font glyph.
func stamp(glyph: int, x: float, y: float, s: float, prog: float, rot := -0.05) -> void:
	if prog <= 0.0:
		return
	var sc := 1.0 + 2.5 * (1.0 - ss(0, 1, prog))
	_save()
	_translate(x, y)
	_rotate(rot)
	_scale(sc, sc)
	_a *= ss(0, 0.5, prog) * 0.92
	draw_rect(Rect2(-s / 2, -s / 2, s, s), _col(RED, 1.0))
	var paper := _col(PAPER, 1.0)
	for i in 30:   # chipped edges / worn carving
		draw_rect(Rect2(-s / 2 + h2(i, 1) * s, -s / 2 + h2(i, 2) * s, (2 + h2(i, 3) * 4) * s / 58.0, (1 + h2(i, 4) * 2) * s / 58.0), paper)
	var lw := s * 0.07
	var g := s * 0.3
	if glyph == 0:
		draw_line(Vector2(-g, -g), Vector2(-g, g * 0.6), paper, lw)
		draw_line(Vector2(-g * 0.4, -g * 0.9), Vector2(-g * 0.4, g), paper, lw)
		draw_line(Vector2(-g, g * 0.6), Vector2(-g * 0.4, g * 0.2), paper, lw)
		draw_line(Vector2(0.05 * s, -g), Vector2(g * 0.6, -g * 0.2), paper, lw)
		draw_line(Vector2(0.1 * s, -g * 0.2), Vector2(g, -g * 0.2), paper, lw)
		draw_line(Vector2(g * 0.2, -g * 0.1), Vector2(g, g), paper, lw)
		draw_line(Vector2(g * 0.9, -g * 0.1), Vector2(0.05 * s, g), paper, lw)
	else:
		draw_line(Vector2(-g, -g), Vector2(-g, g), paper, lw)
		draw_line(Vector2(-g, -g), Vector2(-g * 0.2, -g), paper, lw)
		draw_line(Vector2(-g, 0), Vector2(-g * 0.2, 0), paper, lw)
		draw_line(Vector2(-g, g), Vector2(-g * 0.2, g), paper, lw)
		draw_line(Vector2(g * 0.2, -g), Vector2(g, -g), paper, lw)
		draw_line(Vector2(g, -g), Vector2(g, g * 0.4), paper, lw)
		draw_line(Vector2(g * 0.2, -g), Vector2(g * 0.2, g * 1.1), paper, lw)
	_restore()

func caption(txt: String, x: float, y: float, sz: float, a: float, col := Color(60 / 255.0, 55 / 255.0, 48 / 255.0), italic := true) -> void:
	if a <= 0.0:
		return
	var f: Font = _italic if italic else _font
	# A soft plate behind the words so busy scenes (bamboo, rain, the crane's legs, the scroll's
	# rod) never cover them (owner 2026-11-15: captions overlapped by the pictures).
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz)).x
	var plate := WASH_FOG if (col.r + col.g + col.b) / 3.0 < 0.5 else Color(0.05, 0.04, 0.04)
	for i in 3:
		var grow := 10.0 + i * 12.0
		draw_rect(Rect2(x - tw / 2.0 - grow - 8.0, y - sz * 0.95 - grow * 0.5, tw + grow * 2.0 + 16.0, sz * 1.4 + grow), _col(plate, 0.2 * a))
	draw_string(f, Vector2(x - W / 2, y), txt, HORIZONTAL_ALIGNMENT_CENTER, W, int(sz), _col(col, a))

## Points along a quadratic curve (for the filled shapes the HTML builds with quadraticCurveTo).
static func _quad(p0: Vector2, c: Vector2, p1: Vector2, n := 8) -> Array:
	var o := []
	for i in range(1, n + 1):
		var u := float(i) / n
		o.append(p0.lerp(c, u).lerp(c.lerp(p1, u), u))
	return o

func _fill(pts: Array, col: Color) -> void:
	var pk := PackedVector2Array(pts)
	if Geometry2D.triangulate_polygon(pk).is_empty():
		return
	draw_colored_polygon(pk, col)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot := 0.0, n := 20) -> void:
	var pts := []
	for i in n:
		var an := TAU * i / n
		pts.append(c + Vector2(cos(an) * rx, sin(an) * ry).rotated(rot))
	_fill(pts, col)

## Sumi, the faceless ninja. pose: 0 stand, 1 run, 2 slash, 3 crouch; dir 1 / -1.
func sumi(x: float, y: float, s: float, tt: float, o := {}) -> void:
	var pose: int = o.get("pose", 0)
	var a: float = o.get("a", 1.0)
	if a <= 0.0:
		return
	_save()
	_translate(x, y)
	_scale(s * float(o.get("dir", 1)), s)
	_a *= a
	var ink := _col(INK, 1.0)
	var run := sin(tt * 10.0) if pose == 1 else 0.0
	var cr := 14.0 if pose == 3 else 0.0
	draw_multiline(PackedVector2Array([
		Vector2(-4, -40 + cr), Vector2(-10 - run * 12, -18 + cr * 0.5), Vector2(-10 - run * 12, -18 + cr * 0.5), Vector2(-8 - run * 16, 0),
		Vector2(4, -40 + cr), Vector2(10 + run * 12, -18 + cr * 0.5), Vector2(10 + run * 12, -18 + cr * 0.5), Vector2(12 + run * 14, 0)]), ink, 9.0)
	var lean := 6.0 if pose == 1 else 0.0
	var body := [Vector2(-13, -40 + cr)]
	body.append_array(_quad(Vector2(-13, -40 + cr), Vector2(-16, -68 + cr), Vector2(-6 + lean, -82 + cr)))
	body.append(Vector2(10 + lean, -82 + cr))
	body.append_array(_quad(Vector2(10 + lean, -82 + cr), Vector2(16, -62 + cr), Vector2(13, -40 + cr)))
	_fill(body, ink)
	var hx := 9.0 if pose == 1 else 2.0
	var hy := -96.0 + cr
	_ellipse(Vector2(hx, hy), 12, 12, ink)
	_ellipse(Vector2(hx + 5, hy + 1), 5, 3.2, _col(PAPER, 0.9))   # no face: a blank paper mask
	if o.get("band", 1):
		var b1 := PackedVector2Array()
		var b2 := PackedVector2Array()
		var prev := Vector2(hx - 10, hy - 4)
		for i in range(1, 7):
			var p := Vector2(hx - 10 - i * 7, hy - 4 + sin(tt * 6 + i * 0.9) * 4 * i / 3.0 + i * 1.2)
			b1.append(prev)
			b1.append(p)
			prev = p
		prev = Vector2(hx - 10, hy - 2)
		for i in range(1, 6):
			var p := Vector2(hx - 10 - i * 6, hy + 2 + sin(tt * 6 + i) * 3 * i / 3.0 + i * 2)
			b2.append(prev)
			b2.append(p)
			prev = p
		draw_multiline(b1, ink, 3.0)
		draw_multiline(b2, ink, 2.0)
	if pose == 2:
		draw_line(Vector2(6, -74), Vector2(26, -80), ink, 7.0)
		draw_line(Vector2(26, -80), Vector2(80, -100), ink, 3.0)
	else:
		draw_multiline(PackedVector2Array([Vector2(0, -74), Vector2(-6 - run * 8, -54), Vector2(6, -74), Vector2(12 + run * 8, -56)]), ink, 7.0)
		draw_line(Vector2(-12, -80), Vector2(14, -44), ink, 3.0)
	_restore()

## Tsuru, the crane. fly 0/1, sealed (red square), wing_broken. The red crown is the one
## red that is not Lord Shu's (owner's rule).
func crane(x: float, y: float, s: float, tt: float, o := {}) -> void:
	var a: float = o.get("a", 1.0)
	if a <= 0.0:
		return
	var sealed: bool = o.get("sealed", false)
	var broken: bool = o.get("wing_broken", false)
	_save()
	_translate(x, y)
	_scale(s, s)
	_a *= a
	var ink := _col(INK, 1.0)
	if o.get("fly", false):
		var f := sin(tt * 5.0) * (0.2 if broken else 1.0)
		draw_line(Vector2(-60, 4), Vector2(70, -4), ink, 4.0)
		_ellipse(Vector2.ZERO, 30, 10, ink)
		for sd in [-1.0, 1.0]:
			var wing := [Vector2(-10, 0)]
			wing.append_array(_quad(Vector2(-10, 0), Vector2(-20, -60 * f * sd - 10), Vector2(-70, -80 * f * sd)))
			wing.append_array(_quad(Vector2(-70, -80 * f * sd), Vector2(-30, -30 * f * sd), Vector2(20, 0)))
			_fill(wing, ink)
		_ellipse(Vector2(72, -5), 5, 5, ink)
		draw_line(Vector2(76, -5), Vector2(96, -2), ink, 2.0)
		if sealed:
			draw_rect(Rect2(-6, -8, 12, 12), _col(RED, 1.0))
	else:
		draw_multiline(PackedVector2Array([Vector2(-4, 0), Vector2(-6, 40), Vector2(4, 0), Vector2(8, 40)]), ink, 2.5)
		_ellipse(Vector2(0, -12), 24, 13, ink, -0.3)
		var neck := PackedVector2Array([Vector2(16, -20)])
		neck.append_array(PackedVector2Array(_quad(Vector2(16, -20), Vector2(26, -50), Vector2(18, -70))))
		for i in neck.size() - 1:
			draw_line(neck[i], neck[i + 1], ink, 4.0)
		_ellipse(Vector2(18, -72), 5, 5, ink)
		draw_line(Vector2(22, -72), Vector2(42, -68), ink, 2.0)
		_ellipse(Vector2(17, -76), 2.6, 2.6, _col(RED, 1.0 if sealed else 0.9))   # the crown
		if sealed:
			draw_rect(Rect2(-8, -18, 12, 12), _col(RED, 1.0))
		if broken:
			draw_line(Vector2(-14, -20), Vector2(-4, -4), _col(PAPER, 1.0), 3.0)
	_restore()

## Lord Shu's hand from above the frame, the signet ring red.
func hand(x: float, y: float, s: float, a := 1.0) -> void:
	_save()
	_translate(x, y)
	_scale(s, s)
	_a *= a
	var c := _col(Color("211d1a"), 1.0)
	var pts := [Vector2(-80, -900), Vector2(-70, -40)]
	pts.append_array(_quad(Vector2(-70, -40), Vector2(-60, 20), Vector2(0, 30)))
	pts.append_array(_quad(Vector2(0, 30), Vector2(70, 20), Vector2(80, -40)))
	pts.append(Vector2(90, -900))
	_fill(pts, c)
	for i in 4:
		_ellipse(Vector2(-55 + i * 36, 30), 14, 40, c)
	_ellipse(Vector2(-20, 10), 12, 8, _col(RED, 1.0))
	_restore()

func rain(tt: float, a: float, ang := 0.25, n := 160) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var x := fmod(h2(i, 1) * W * 1.3 + tt * 200 * ang, W * 1.3) - W * 0.15
		var y := fmod(h2(i, 2) * H + tt * (600 + h2(i, 3) * 300), H + 40) - 20
		pts.append(Vector2(x, y))
		pts.append(Vector2(x - ang * 24, y - 24))
	draw_multiline(pts, _col(INK, a), 1.0)

## Screen-space layers (cover the whole Control, also past 16:9).
func vignette(a := 0.5) -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var r := maxf(size.x, size.y) * 0.62
	draw_texture_rect(_vig_tex, Rect2(size / 2 - Vector2(r * 1.25, r * 0.85), Vector2(r * 2.5, r * 1.7)), false, Color(10 / 255.0, 8 / 255.0, 6 / 255.0, a))
	_apply()

func black(a: float) -> void:
	if a <= 0.0:
		return
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_rect(Rect2(Vector2.ZERO, size), Color(14 / 255.0, 12 / 255.0, 10 / 255.0, minf(a, 1.0)))
	_apply()

func ink_wipe(p: float, seed := 3.0) -> void:
	if p <= 0.0:
		return
	for i in 14:
		bloom(h2(i, seed) * W, h2(i, seed + 1) * H, p * (260 + 200 * h2(i, seed + 2)), cl(p * 1.4), seed + i)
	black(ss(0.6, 1, p))

## Shared "red washes out + bow" (Lord Shu's red leaving a freed creature).
func freed_bow(cx: float, cy: float, p: float, creature: Callable) -> void:
	creature.call(p)
	var r := 1.0 - ss(0.15, 0.7, p)
	if r > 0.0:
		bloom(cx, cy, 40 + 120 * (1 - r), 0.55 * r, 9, WASH_RED)
	for i in 10:
		var kk := ss(0.2, 0.9, p)
		wash(cx + (h2(i, 3) - 0.5) * 200 * kk, cy + kk * 160 * h2(i, 4), 10 * (1 - kk), 0.5 * (1 - kk), WASH_RED)

func region_shot(kind: String, tt: float) -> void:
	if kind == "bamboo":
		mountains(H * 0.4, 90, 6, 0.35, 0.5)
		fog(tt, 0.5, H * 0.5, 200)
		for i in 14:
			var x := i * 95 + h2(i, 1) * 60 - 40 + sin(tt * 0.7 + i) * 6
			var a := 0.35 + 0.65 * h2(i, 2)
			for kk in 6:
				brush([Vector2(x, H - kk * 130), Vector2(x + 1, H - kk * 130 - 118)], 10 + h2(i, 3) * 8, {"a": a, "seed": i * 9 + kk, "dry": 0.4})
			for l in 4:
				var ly := H * 0.15 + h2(i, l) * H * 0.5
				var d := 1.0 if l % 2 else -1.0
				brush([Vector2(x, ly), Vector2(x + d * 40, ly + 10 + roundf(sin(tt + i) * 4)), Vector2(x + d * 70, ly + 26)], 7, {"a": a * 0.8, "seed": l + i})
		rain(tt, 0.18, 0.15, 90)
	elif kind == "river":
		mountains(H * 0.36, 150, 9, 0.5, 0.6)
		fog(tt, 0.45, H * 0.42, 100)
		for i in 3:
			draw_rect(Rect2(W * 0.62 + i * 20, 0, 8, H * 0.62), _col(Color.WHITE, 0.25))
			brush([Vector2(W * 0.6 + i * 30, H * 0.05), Vector2(W * 0.61 + i * 30, H * 0.62)], 4, {"a": 0.25, "seed": i, "dry": 0.7})
		for i in 10:
			var y := H * 0.68 + i * 12
			var o := sin(tt * 1.2 + i) * 20
			brush([Vector2(W * 0.05 + o, y), Vector2(W * 0.45 + o, y + 2), Vector2(W * 0.95 + o, y)], 1.6, {"a": 0.4 - i * 0.03, "seed": i, "dry": 0.5})
		_save()
		_translate(W * 0.3 + sin(tt * 0.5) * 10, H * 0.72)
		var ink := _col(INK, 1.0)
		var boat := [Vector2(-60, 0)]
		boat.append_array(_quad(Vector2(-60, 0), Vector2(0, 22), Vector2(60, 0)))
		boat.append_array([Vector2(50, -4), Vector2(-50, -4)])
		_fill(boat, ink)
		draw_line(Vector2(10, -4), Vector2(26, -60), ink, 2.0)
		_restore()
	elif kind == "margin":
		for i in 6:   # Lord Shu's red veins creeping down the blank paper
			var p := ss(i * 0.6, 3 + i * 0.6, tt)
			var pts := PackedVector2Array()
			var x := h2(i, 1) * W
			var y := 0.0
			pts.append(Vector2(x, y))
			for kk in int(30 * p):
				x += (h2(i, kk) - 0.5) * 40
				y += H / 30.0
				pts.append(Vector2(x, y))
			if pts.size() >= 2:
				draw_polyline(pts, _col(RED, 0.35 * p), 1.5)

## Lord Shu's words: red text slammed onto the screen, worn by paper specks.
func red_text(txt: String, x: float, y: float, sz: float, prog: float, col := RED, speck := PAPER) -> void:
	if prog <= 0.0:
		return
	var sc := 1.0 + 1.8 * (1.0 - ss(0, 1, prog))
	_save()
	_translate(x, y)
	_scale(sc, sc)
	_a *= ss(0, 0.4, prog)
	draw_string(_bold, Vector2(-W / 2, sz * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, W, int(sz), _col(col, 1.0))
	var sp := _col(speck, 1.0)
	for i in 60:
		draw_rect(Rect2((h2(i, 7) - 0.5) * sz * txt.length() * 0.6, (h2(i, 8) - 0.5) * sz, 1 + h2(i, 9) * 3, 1), sp)
	_restore()

## Full-screen colour (past 16:9 too).
func _screen(c: Color) -> void:
	if c.a <= 0.0:
		return
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_rect(Rect2(Vector2.ZERO, size), c)
	_apply()

# ---------- scenes ----------

## 1 INTRO, before 1-1: the unfinished scroll, Lord Shu's seal lands and bleeds; cut to
## the pine forest, the ground is painted, Sumi inks in, Tsuru lands, nods, flies off.
func _intro(tt: float) -> void:
	var z := 1.0 + tt * 0.008
	_save()
	_cam(z)
	if tt < 16.0:
		bloom(W / 2, H * 0.48, ss(0.5, 4, tt) * 420, 0.06, 2)
		var a := ss(0, 2.5, tt)
		_save()
		_a *= a
		brush([Vector2(W / 2 - 170, 60), Vector2(W / 2 + 170, 60)], 12, {"prog": ss(0.5, 2, tt), "seed": 4, "taper": 0})
		brush([Vector2(W / 2 - 170, H - 60), Vector2(W / 2 + 170, H - 60)], 12, {"prog": ss(1, 2.5, tt), "seed": 5, "taper": 0})
		draw_rect(Rect2(W / 2 - 150, 70, 300, H - 140), _col(Color("5c564e"), 0.5), false, 1.0)
		_restore()
		# The tiny painting inside the scroll.
		_save()
		_translate(W / 2 - 150, 70)
		_scale(300 / W, (H - 140) / H)
		mountains(H * 0.45, 180, 1, ss(2, 5, tt) * 0.7)
		mountains(H * 0.65, 120, 3, ss(3, 6, tt) * 0.8)
		pine(W * 0.2, H * 0.95, 1.6, 3, ss(4, 7, tt))
		pine(W * 0.75, H * 0.98, 1.3, 5, ss(4.5, 7.5, tt))
		_restore()
		stamp(0, W / 2 + 110, 140, 58, ss(9.5, 10.1, tt))
		if tt > 10.0:
			var d := ss(10.5, 15, tt)
			_save()
			_a *= 0.8
			brush([Vector2(W / 2 + 110, 168), Vector2(W / 2 + 112, 168 + d * 120), Vector2(W / 2 + 106, 168 + d * 260)], 5 * (1 - d * 0.4), {"col": RED, "prog": d, "seed": 7, "dry": 0.2})
			_restore()
			wash(W / 2 + 108, 168 + d * 260, 8 + d * 8, 0.5 * d, WASH_RED)
		_restore()
		# Captions outside the camera, so the push-in never crops them.
		caption(tr("The world is a scroll. Its painter died before he finished."), W / 2, H - 8, 22, ss(3, 4.5, tt) * (1 - ss(8, 9, tt)))
		caption(tr("A collector stamped his seal on it. The red began to spread."), W / 2, H - 8, 22, ss(11, 12, tt) * (1 - ss(14.5, 15.5, tt)))
		# Fade through clean paper into the forest.
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_rect(Rect2(Vector2.ZERO, size), Color(PAPER, ss(14.8, 16, tt)))
		return
	var u := tt - 16.0
	_translate(-u * 4, 0)
	mountains(H * 0.42, 170, 2, ss(0, 3, u) * 0.55, 0.6)
	fog(tt, 0.55, H * 0.45, 140)
	mountains(H * 0.6, 120, 7, ss(0.5, 3.5, u) * 0.75)
	pine(W * 0.18, H * 0.8, 1.5, 2, ss(1, 3.5, u))
	pine(W * 0.82, H * 0.8, 1.7, 9, ss(1.5, 4, u))
	pine(W * 0.66, H * 0.82, 1.1, 4, ss(2, 4.5, u) * 0.7)
	ground(H * 0.8, ss(1, 4, u))
	grass(H * 0.8, 3, ss(3.5, 5, u))
	sumi(W * 0.42, H * 0.8, 1.15, tt, {"a": ss(5, 7, u)})
	# Tsuru lands on the tall pine, nods toward the right, flies off.
	var land := ss(6, 8, u)
	var off := ss(10, 13, u)
	if off <= 0.0:
		crane(lerpf(W + 80, W * 0.82 + 30, land), lerpf(-60, H * 0.8 - 170 * 1.7 + 40, land), 1, tt, {"fly": land < 1.0})
	else:
		crane(W * 0.82 + 30 + off * 600, H * 0.8 - 250 - off * 300, 1, tt, {"fly": true})
	fog(tt * 1.3, 0.35, H * 0.85, 60)
	_restore()
	caption(tr("A seal can only bind what is finished."), W / 2, H - 30, 22, ss(8, 9, u) * (1 - ss(12.5, 13.5, u)))
	vignette(0.35)
	black(1 - ss(16, 17, tt))
	black(ss(28.6, 30, tt))

## Boss-freed template (the HTML's bossScene): boss part until `split`, ink wipe, then the
## next region's establishing shot with its name.
func _boss_scene(tt: float, dur: float, split: float, region: String, region_name: String, region_sub: String, boss: Callable, seed: float) -> void:
	_save()
	_cam(1.02 + tt * 0.006)
	if tt < split:
		boss.call(tt)
	else:
		var u := tt - split
		region_shot(region, u)
		var out := 1.0 - ss(dur - split - 2.0, dur - split - 0.8, u)
		caption(region_name, W / 2, H * 0.18, 46, ss(1, 2.5, u) * out, Color(40 / 255.0, 36 / 255.0, 32 / 255.0), false)
		caption(region_sub, W / 2, H * 0.18 + 40, 20, ss(1.8, 3, u) * out)
	_restore()
	vignette(0.35)
	black(1 - ss(0, 0.8, tt))
	if tt > split - 1.2 and tt < split + 1.0:
		var p := ss(split - 1.2, split, tt) if tt < split else 1.0 - ss(split, split + 1.0, tt)
		ink_wipe(p, seed)
	black(ss(dur - 1.0, dur, tt))

## 3 AFTER-1B, before 2-1: the Gate Warden's seal cracks, red drains, the lion-dog settles
## into stone and bows; its paw leaves claw marks (Dry Brush). Wipe to the Bamboo Grove.
func _after_1b(tt: float) -> void:
	_boss_scene(tt, 16.0, 8.0, "bamboo", tr("II · BAMBOO GROVE"), tr("Green without green."), _warden.bind(), 8.0)

func _warden(tt: float) -> void:
	mountains(H * 0.36, 100, 3, 0.35, 0.5)
	fog(tt, 0.5, H * 0.4, 120)
	ground(H * 0.82, 1, 5)
	freed_bow(W * 0.45, H * 0.6, ss(0.5, 4, tt), _warden_body.bind(tt))
	stamp(1, W * 0.45 + 30, H * 0.82 - 160, 26, 1 - ss(0.5, 2, tt), 0.0)
	for i in 3:
		brush([Vector2(W * 0.12 + i * 18, H * 0.4), Vector2(W * 0.15 + i * 18, H * 0.6)], 6, {"prog": ss(5 + i * 0.4, 5.8 + i * 0.4, tt), "seed": i, "dry": 0.7})
	sumi(W * 0.75, H * 0.82, 1, tt, {"dir": -1})

func _warden_body(_p: float, tt: float) -> void:
	_save()
	_translate(W * 0.45, H * 0.82)
	var bow := ss(3.5, 5, tt) * 0.25
	_rotate(bow * 0.3)
	var pts := [Vector2(-110, 0)]
	pts.append_array(_quad(Vector2(-110, 0), Vector2(-120, -90), Vector2(-60, -120)))
	pts.append_array(_quad(Vector2(-60, -120), Vector2(-10, -150 + bow * 40), Vector2(40, -130 + bow * 60)))
	pts.append_array(_quad(Vector2(40, -130 + bow * 60), Vector2(110, -110), Vector2(110, 0)))
	_fill(pts, _col(Color("2a2622"), 1.0))
	wash(20, -150 + bow * 50, 70, 0.5)
	_ellipse(Vector2(46, -140 + bow * 60), 6, 6, _col(PAPER, 0.4))
	_restore()

## 2 DRIP, before 1-3: the first red drop falls; where it lands a fox turns Sealed.
func _drip(tt: float) -> void:
	_save()
	_cam(1.05 - tt * 0.004, 0, -tt * 3)
	mountains(H * 0.3, 120, 4, 0.4, 0.5)
	fog(tt, 0.6, H * 0.35, 120)
	_save()
	_a *= 0.55
	wash(W * 0.7, H * 0.25, 110, 0.4)
	brush([Vector2(W * 0.64, H * 0.32), Vector2(W * 0.64, H * 0.18)], 10, {"seed": 2})
	brush([Vector2(W * 0.76, H * 0.32), Vector2(W * 0.76, H * 0.18)], 10, {"seed": 3})
	brush([Vector2(W * 0.61, H * 0.19), Vector2(W * 0.79, H * 0.17)], 14, {"seed": 4})
	_restore()
	for i in 8:
		var y := H * 0.92 - i * 48
		var x := W * 0.15 + i * 70
		brush([Vector2(x, y), Vector2(x + 170, y - 2)], 10, {"seed": i, "a": 0.85 - i * 0.06, "dry": 0.6, "taper": 0})
	var drop := ss(2, 4.5, tt)
	var dy := lerpf(-20, H * 0.66, drop * drop)
	if tt < 4.6:
		_ellipse(Vector2(W * 0.55, dy), 5, 8, _col(RED, 1.0))
	if tt > 4.5:
		bloom(W * 0.55, H * 0.66, ss(4.5, 6, tt) * 50, 0.45, 3, WASH_RED)
	var fx := W * 0.55
	var fy := H * 0.73
	var turn := ss(6.5, 8, tt)
	_save()
	_translate(fx, fy)
	_scale(-1.0 if turn > 0.5 else 1.0, 1.0)
	var ink := _col(INK, 1.0)
	_ellipse(Vector2(0, -20), 32, 13, ink)
	_fill([Vector2(26, -26), Vector2(46, -34), Vector2(52, -50), Vector2(58, -34), Vector2(48, -22)], ink)
	var tail := [Vector2(-28, -20)]
	tail.append_array(_quad(Vector2(-28, -20), Vector2(-60, -40 - turn * 20), Vector2(-70, -14)))
	draw_polyline(PackedVector2Array(tail), ink, 4.0)
	for lx in [-18, -8, 12, 22]:
		draw_line(Vector2(lx, -12), Vector2(lx, 0), ink, 3.0)
	_restore()
	stamp(1, fx + (-2.0 if turn > 0.5 else 2.0), fy - 22, 18, ss(6.5, 7, tt), 0.0)
	sumi(W * 0.3, H * 0.84 - 24, 1, tt, {"pose": 3 if ss(7, 8, tt) > 0.0 else 0})
	_restore()
	vignette(0.4)
	black(1 - ss(0, 1, tt))
	ink_wipe(ss(10.5, 12, tt), 5)

## 4 AFTER-2B, before 3-1: Tora freed, tosses Sumi into the canopy; wipe to the river.
func _after_2b(tt: float) -> void:
	_boss_scene(tt, 16.0, 8.0, "river", tr("III · RIVER OF WASH"), tr("Water is the part he did not paint."), _tora.bind(), 8.0)

func _tora(tt: float) -> void:
	region_shot("bamboo", tt)
	var cy := H * 0.84
	freed_bow(W * 0.4, cy - 60, ss(0.3, 3.5, tt), _tora_body.bind(tt))
	stamp(1, W * 0.4 - 30, cy - 70, 22, 1 - ss(0.3, 1.8, tt), 0.0)
	var th := ss(4.5, 6.5, tt)
	sumi(lerpf(W * 0.6, W * 0.7, th), lerpf(cy, -80, th * th), 1, tt, {"pose": 1 if th > 0.0 else 0, "dir": -1})

func _tora_body(_p: float, tt: float) -> void:
	_save()
	_translate(W * 0.4, H * 0.84)
	wash(0, -55, 120, 0.4)
	var c := _col(Color("24201c"), 1.0)
	_ellipse(Vector2(0, -55), 130, 48, c)
	_ellipse(Vector2(130, -90 + ss(3, 4, tt) * 20), 34, 34, c)
	for i in 7:
		brush([Vector2(-90 + i * 28, -95), Vector2(-80 + i * 28, -60), Vector2(-88 + i * 28, -25)], 5, {"col": PAPER, "a": 0.55, "seed": i, "dry": 0.6})
	_restore()

## 5 AFTER-3B, before 4-1: the dragon carries Sumi; Lord Shu's hand stamps Tsuru out of the sky.
func _after_3b(tt: float) -> void:
	_save()
	_cam(1 + tt * 0.004)
	mountains(H * 0.5, 140, 9, 0.4, 0.5)
	fog(tt, 0.6, H * 0.5, 260)
	var pts := []
	for i in 9:
		pts.append(Vector2(i * 190 - 120, H * 0.6 + sin(i * 1.1 + tt * 1.5) * 70))
	brush(pts, 46, {"a": 0.9, "seed": 3, "dry": 0.25, "bristles": 11, "steps": 6})   # the coiling body is new every frame: a lighter brush
	var pts2 := []
	for p in pts:
		pts2.append(p + Vector2(0, -4))
	brush(pts2, 20, {"col": Color("3a3530"), "a": 0.6, "seed": 4, "dry": 0.6, "bristles": 8, "steps": 6})
	var head: Vector2 = pts[7]
	var ink := _col(INK, 1.0)
	_save()
	_translate(head.x + 40, head.y - 10)
	_ellipse(Vector2.ZERO, 46, 24, ink, -0.2)
	for sd in [-1.0, 1.0]:
		var wh := [Vector2(30, 0)]
		wh.append_array(_quad(Vector2(30, 0), Vector2(80, sd * 30 + sin(tt * 3) * 10), Vector2(120, sd * 10)))
		draw_polyline(PackedVector2Array(wh), ink, 2.0)
	_restore()
	var sp: Vector2 = pts[4]
	sumi(sp.x, sp.y - 22, 0.8, tt, {"pose": 2})
	var fall := ss(11.6, 16, tt)
	if tt < 16.0:
		crane(lerpf(W * 0.75, W * 0.65, ss(0, 11, tt)) + fall * 80, H * 0.22 + fall * fall * H * 0.9, 0.8, tt + fall * 10, {"fly": true, "sealed": tt > 11.2, "a": 1 - ss(15, 16, tt)})
	if fall > 0.0:
		for i in 12:
			_save()
			_translate(W * 0.66 + fall * 80 + (h2(i, 1) - 0.5) * 200 * fall, H * 0.22 + fall * H * 0.6 * h2(i, 2))
			_rotate(tt * 2 + i)
			_ellipse(Vector2.ZERO, 8, 2, _col(INK, 1 - fall))
			_restore()
	var hd := ss(8, 11, tt)
	var hu := ss(12, 14, tt)
	hand(W * 0.66, lerpf(-200, H * 0.22 - 40, hd * hd) - hu * 500, 1.1, 1.0)
	_restore()
	if tt > 11.0 and tt < 11.6:
		_screen(Color(RED, 0.15))   # the stamp lands: a red flash (Lord Shu)
	vignette(0.35 + ss(9, 12, tt) * 0.3)
	black(1 - ss(0, 1, tt))
	black(ss(16.5, 18, tt))
	caption(tr("The crane fell into the town below."), W / 2, H / 2, 24, ss(18, 19, tt) * (1 - ss(20.5, 21.5, tt)), Color(190 / 255.0, 182 / 255.0, 170 / 255.0))

const PALE := Color(236 / 255.0, 228 / 255.0, 211 / 255.0)

## 6 ACT4, before 4-1: Lantern Town at night, white lines on black, red stamps on every door.
func _act4(tt: float) -> void:
	_screen(Color("121110"))
	_save()
	_cam(1.1 - tt * 0.006, 0, lerpf(-80, 40, ss(0, 10, tt)))
	wash(W * 0.78, H * 0.18, 70, 0.9, PALE)
	for i in 7:
		var x := i * 200.0 - 40
		var y := H * 0.48 + h2(i, 2) * 40
		brush([Vector2(x, y), Vector2(x + 100, y - 50), Vector2(x + 200, y)], 3, {"col": PAPER, "a": 0.55, "seed": i, "dry": 0.5, "taper": 0})
		brush([Vector2(x + 20, y + 4), Vector2(x + 20, H * 0.75)], 2, {"col": PAPER, "a": 0.4, "seed": i + 2})
		brush([Vector2(x + 180, y + 4), Vector2(x + 180, H * 0.75)], 2, {"col": PAPER, "a": 0.4, "seed": i + 3})
		stamp(1, x + 100, H * 0.65, 20, ss(2 + i * 0.5, 2.4 + i * 0.5, tt), 0.0)
	for i in 5:
		var x := 120.0 + i * 260
		var y := H * 0.56 + sin(tt * 1.3 + i) * 5
		wash(x, y + 80, 130, 0.12, PALE)
		_ellipse(Vector2(x, y), 12, 17, _col(PAPER, 0.85))
	brush([Vector2(-20, H * 0.88), Vector2(W * 0.5, H * 0.85), Vector2(W + 20, H * 0.88)], 10, {"col": PAPER, "a": 0.7, "seed": 5, "taper": 0})
	var land := ss(7, 8.5, tt)
	var sy := lerpf(H * 0.3, H * 0.85, land * land)
	sumi(W * 0.38, sy, 1, tt)
	draw_arc(Vector2(W * 0.38 + 2, sy - 96), 13, 0, TAU, 24, _col(PAPER, 0.8), 1.5)
	_restore()
	caption(tr("IV · LANTERN TOWN"), W / 2, H * 0.16, 42, ss(9, 10, tt) * (1 - ss(12.5, 13.4, tt)), PALE, false)
	black(1 - ss(0, 1.5, tt))
	black(ss(13, 14, tt))

## 7 AFTER-4B, before 5-1: Tsuru freed, wing stamped through; the only spoken line.
func _after_4b(tt: float) -> void:
	var dawn := ss(1, 7, tt)
	_screen(Color(18 / 255.0, 17 / 255.0, 16 / 255.0, 1 - dawn))
	_save()
	_cam(1 + tt * 0.005, 0, -ss(10, 16, tt) * 120)
	mountains(H * 0.1, 260, 11, dawn * 0.8, 0.8)
	fog(tt, 0.4 * dawn, H * 0.25, 100)
	brush([Vector2(-20, H * 0.82), Vector2(W + 20, H * 0.82)], 14, {"a": 0.8, "seed": 1, "taper": 0})
	freed_bow(W * 0.4, H * 0.65, ss(0.3, 3.5, tt), _tsuru_grounded.bind(tt))
	stamp(1, W * 0.4 - 10, H * 0.78 - 48, 22, 1 - ss(0.3, 1.8, tt), 0.0)
	sumi(W * 0.6, H * 0.82, 1, tt, {"dir": -1})
	_restore()
	var line := tr("\"It reads from the bottom. So we go up.\"")
	var n := int(line.length() * ss(6, 9, tt))
	caption(line.substr(0, n), W / 2, H * 0.93, 28, 1 - ss(15, 16, tt), Color(40 / 255.0, 36 / 255.0, 32 / 255.0) if dawn > 0.5 else Color(230 / 255.0, 222 / 255.0, 208 / 255.0))
	vignette(0.4)
	black(1 - ss(0, 1, tt))
	black(ss(17, 18, tt))

func _tsuru_grounded(_p: float, tt: float) -> void:
	crane(W * 0.4, H * 0.78, 2, tt, {"wing_broken": true})

## 8 ACT5, before 5-1: Storm Mountain; lightning shows the sketch-line path; "MINE."
func _act5(tt: float) -> void:
	var fl := maxf(exp(-(tt - 2) * 6) if tt > 2.0 else 0.0, exp(-(tt - 7) * 6) if tt > 7.0 else 0.0)
	_save()
	_cam(1 + fl * 0.02)
	wash(W * 0.5, H * 0.1, 700, 0.75)
	mountains(H * 0.3, 300, 13, 0.9, 0.95)
	for i in 6:
		brush([Vector2(W * 0.1 + i * 170, H * 0.95), Vector2(W * 0.18 + i * 170, H * 0.5 - h2(i, 1) * 100), Vector2(W * 0.22 + i * 170, H * 0.3)], 14, {"a": 0.85, "seed": i, "dry": 0.7})
	if fl > 0.0:
		for i in 5:
			draw_dashed_line(Vector2(W * 0.45 + i * 90, H * 0.4 - i * 40), Vector2(W * 0.52 + i * 90, H * 0.4 - i * 40), _col(INK, fl * 0.9), 2.0, 7.0)
	sumi(W * 0.7, H * 0.3, 0.5, tt)
	crane(W * 0.42, H * 0.62, 0.7, tt, {"wing_broken": true})
	var snow := _col(PAPER, 0.7)
	for i in 120:
		var x := fmod(h2(i, 1) * W * 1.4 + tt * (300 + h2(i, 2) * 200), W * 1.4) - W * 0.2
		var y := h2(i, 3) * H + sin(tt + i) * 20
		draw_rect(Rect2(x, y, 2, 2), snow)
	_restore()
	_screen(Color(PALE, fl * 0.8))
	caption(tr("V · STORM MOUNTAIN"), W / 2, H * 0.88, 40, ss(3, 4, tt) * (1 - ss(8, 8.8, tt)), PALE, false)
	red_text(tr("MINE."), W / 2, H * 0.4, 130, ss(9.5, 10, tt))
	vignette(0.4)
	black(1 - ss(0, 1, tt))
	black(ss(13, 14, tt))

## 9 AFTER-5B, before 6-1: the Calligrapher freed, hands over the splinter; wipe to the Margin.
func _after_5b(tt: float) -> void:
	_boss_scene(tt, 18.0, 9.0, "margin", tr("VI · THE MARGIN"), tr("If you are reading this, you got further than I did."), _monk.bind(), 8.0)

func _monk(tt: float) -> void:
	mountains(H * 0.5, 200, 13, ss(4, 8, tt) * 0.6, 0.7)
	fog(tt, 0.4, H * 0.55, 100)
	ground(H * 0.82, 1, 6, 0.8)
	freed_bow(W * 0.45, H * 0.65, ss(0.3, 3, tt), _monk_body)
	stamp(1, W * 0.45 + 60, H * 0.82 - 70, 22, 1 - ss(0.3, 1.8, tt), 0.0)
	var g := ss(3.5, 6, tt)
	draw_line(Vector2(lerpf(W * 0.5, W * 0.62, g), H * 0.72), Vector2(lerpf(W * 0.5, W * 0.62, g) + 24, H * 0.7), _col(INK, 1.0), 3.0)
	sumi(W * 0.66, H * 0.82, 1, tt, {"dir": -1})

func _monk_body(_p: float) -> void:
	_save()
	_translate(W * 0.45, H * 0.82)
	var ink := _col(INK, 1.0)
	var body := [Vector2(-60, 0)]
	body.append_array(_quad(Vector2(-60, 0), Vector2(-50, -90), Vector2(0, -100)))
	body.append_array(_quad(Vector2(0, -100), Vector2(50, -90), Vector2(60, 0)))
	_fill(body, ink)
	_ellipse(Vector2(0, -115), 18, 18, ink)
	draw_line(Vector2(40, -60), Vector2(120, -200), ink, 6.0)
	wash(122, -205, 18, 0.9)
	_restore()

## 10 SEAL, 6-B phase 3: the Seal stamps Sumi; red; nothing happens; Sumi walks out.
## Holds on the SLASH prompt until the player slashes (slash_input).
func _seal(tt: float) -> void:
	var sl := ss(0.5, 1.5, tt)
	_save()
	var sh := (h2(floorf(tt * 60.0), 3) - 0.5) * 14.0 if tt > 1.5 and tt < 2.0 else 0.0
	_translate(sh, sh)
	sumi(W / 2, H * 0.8, 1.3, tt, {"a": 1.0 if tt < 1.5 else 0.0})
	var s := lerpf(H * 2.4, H * 1.3, sl)
	draw_rect(Rect2(W / 2 - s / 2, H / 2 - s / 2, s, s), _col(Color("7d1813"), sl))   # the Seal itself
	_restore()
	if tt > 1.5:
		_screen(RED)
		for i in 8:
			wash(h2(i, 1) * W, h2(i, 2) * H, 300, 0.25, Color(90 / 255.0, 15 / 255.0, 12 / 255.0))
	var walk := ss(8.5, 12, tt)
	if walk > 0.0:
		# Sumi re-inks from the feet up: drawn whole, the part not yet inked hidden in red.
		sumi(W / 2 - 60 + walk * 60, H * 0.8, 1.3, tt, {"pose": 1 if walk < 1.0 else 0})
		draw_rect(Rect2(-W, -H, W * 3, H + H * 0.8 - 130 * 1.3 * walk), _col(RED, 1.0))
	red_text(tr("MINE."), W / 2, H * 0.3, 90, ss(1.6, 2, tt) * (1 - ss(3.5, 4.2, tt)), Color("5a0f0c"), RED)
	caption(tr("A seal binds only what is finished."), W / 2, H * 0.3, 30, ss(6, 7, tt), PALE)
	if tt >= 12.5 and not wait_done:
		caption(tr("— SLASH —"), W / 2, H * 0.93, 22, 0.5 + 0.5 * sin(wait_t * 5.0), PALE, false)
	if tt > 14.0:
		_save()
		_a *= ss(14, 14.3, tt)
		brush([Vector2(W * 0.2, H * 0.75), Vector2(W * 0.5, H * 0.42), Vector2(W * 0.82, H * 0.2)], 18, {"prog": ss(14, 14.4, tt), "seed": 2, "dry": 0.4})
		_restore()
	if tt > 14.3:
		_screen(Color(PALE, ss(14.3, 16, tt)))

## 11 ENDING A: red drains down the whole scroll; pull back to the scroll on an empty wall.
func _ending_a(tt: float) -> void:
	var pan := ss(1, 18, tt)
	var pull := ss(18, 25, tt)
	var th := H * 5
	_save()
	_cam(lerpf(1, 0.28, pull))
	_translate(0, -pan * (th - H) * (1 - pull))
	for i in 6:
		var r: String = ["margin", "storm", "town", "river", "bamboo", "pine"][i]
		_save()
		_translate(0, i * H * 0.8)
		match r:
			"storm":
				mountains(H * 0.6, 280, 13, 0.8, 0.8)
				crane(W * 0.4, H * 0.6, 1, tt, {"wing_broken": true})
			"town":
				for kk in 6:
					brush([Vector2(kk * 220, H * 0.6), Vector2(kk * 220 + 110, H * 0.5), Vector2(kk * 220 + 220, H * 0.6)], 5, {"seed": kk, "a": 0.7})
			"river":
				for kk in 6:
					brush([Vector2(0, H * 0.5 + kk * 10), Vector2(W, H * 0.52 + kk * 10)], 1.5, {"a": 0.4, "seed": kk})
				var pts := []
				for kk in 8:
					pts.append(Vector2(kk * 180, H * 0.4 + sin(kk) * 50))
				brush(pts, 26, {"a": 0.8, "seed": 2})
			"bamboo":
				for kk in 10:
					brush([Vector2(kk * 140, H * 0.8), Vector2(kk * 140, H * 0.1)], 10, {"a": 0.7, "seed": kk})
			"pine":
				mountains(H * 0.5, 140, 2, 0.6, 0.6)
				pine(W * 0.3, H * 0.9, 1.4, 2)
				pine(W * 0.7, H * 0.9, 1.6, 5)
				sumi(W * 0.5, H * 0.9, 1, tt)
		_restore()
	var drain := ss(0.5, 17, tt)
	draw_rect(Rect2(-W, drain * th, W * 3, th), _col(RED, 0.35))   # Lord Shu's red draining away
	if pull > 0.0:
		draw_rect(Rect2(0, -20, W, th * 0.86), _col(INK, pull), false, 14.0)
	_restore()
	if pull > 0.0:
		brush([Vector2(0, H * 0.86), Vector2(W, H * 0.86)], 4, {"seed": 3, "taper": 0, "a": pull * 0.6})
	caption(tr("INK NINJA"), W / 2, H * 0.5, 64, ss(25, 27, tt) * (1 - ss(29, 30, tt)), Color(20 / 255.0, 18 / 255.0, 16 / 255.0), false)
	black(1 - ss(0, 1, tt))

## 12 ENDING B (every scroll found): Hakuu's brush offers a face. Slash refuses (Sumi cuts
## the headband tip and leaves it as the signature); 10 s of nothing and the brush lowers
## and leaves. There is no accept.
func _ending_b(tt: float) -> void:
	_save()
	_cam(2.4 + tt * 0.02, 0, 40)
	sumi(W / 2, H * 0.8, 1.6, tt)
	var go := ss(12, 15, tt)
	var bx := lerpf(W * 0.9, W * 0.58, ss(1, 6, tt)) + go * 300
	var by := lerpf(H * 0.2, H * 0.47, ss(1, 6, tt)) + (go * 260 if idle else -go * 200)
	draw_line(Vector2(bx, by), Vector2(bx + 120, by - 120), _col(Color("6a5a40"), 1.0), 5.0)
	_ellipse(Vector2(bx - 6, by + 6), 8, 16, _col(INK, 1.0), -0.8)
	if tt > 11.0 and not idle:
		var f := ss(11, 15, tt)
		_save()
		_translate(W / 2 - 60 - f * 40, H * 0.8 - 150 + f * 220)
		_rotate(f * 4)
		draw_rect(Rect2(-10, -2, 22, 5), _col(INK, 1.0))
		_restore()
	_restore()
	if tt > 10.8 and tt < 11.3 and not idle:
		brush([Vector2(W * 0.3, H * 0.7), Vector2(W * 0.7, H * 0.3)], 10, {"prog": ss(10.8, 11, tt), "seed": 9})
	if tt > 15.5:
		_screen(Color(PAPER, ss(15.5, 16.5, tt)))
		if not idle:
			_save()
			_translate(W * 0.86, H * 0.86)
			_rotate(-0.3)
			draw_rect(Rect2(-30, -5, 60, 10), _col(INK, ss(16, 17, tt)))
			_restore()
		caption(tr("Unfinished. — H."), W / 2, H * 0.5, 40, ss(17, 18.5, tt), Color(40 / 255.0, 36 / 255.0, 32 / 255.0))
	vignette(0.3)
	black(1 - ss(0, 1, tt))
	black(ss(21, 22, tt))
