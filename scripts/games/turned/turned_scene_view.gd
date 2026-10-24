extends Control

## Scene mode's screen (docs/turned/SCENE_MODE_PLAN.md): one painting (3:2) fitted whole to the
## height of the safe area, the leftover width filled with the painting's own edge (blurred,
## darkened), a vignette, and a chip (magnifier + label) on every hotspot. A tap (MouseButton only:
## phones send every tap twice) or A on the highlighted chip emits `hotspot_activated`; the world
## runs the actions. Arrows move the highlight. A scene with no painting file yet draws a placeholder.
## The world owns the state: it sets `holds` / `seen`, calls show_scene / refresh / hide_scene and
## `enabled` (false while a dialogue, the menu or the kit has the screen).

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Scenes = preload("res://scripts/games/turned/turned_scenes.gd")
const SceneText = preload("res://scripts/games/turned/turned_scene_text.gd")

## A chip was tapped or chosen with A: the hotspot's dictionary (id, do, ...).
signal hotspot_activated(hotspot: Dictionary)

const GOLD := Color("ce9e58")
const GOLD_DIM := Color("b6a58d")
const PLATE := Color("201d1e")

var enabled := false
var holds: Callable = Callable()        # Callable(conditions: Array) -> bool
var seen: Callable = Callable()         # Callable(flag: String) -> bool
var scene_id := ""
var scene: Dictionary = {}
var spots: Array = []                   # the hotspots shown now
var selected := -1
var keyboard_nav := false               # the highlight is drawn once arrows or A were used

var _art_id := ""
var _tex: Texture2D = null
var _blur: ImageTexture = null
var _fade := 0.0
var _xfade := 0.0                       # 1 right after a painting replaced another, down to 0: the old one fades out
var _prev_tex: Texture2D = null
var _prev_blur: ImageTexture = null
var _prev_art := ""
var _chip_a := 1.0
var _t := 0.0
var _layout: Array = []
var _layout_key := ""
var _vig: GradientTexture2D = null
var _plate_box: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
	_vig = GradientTexture2D.new()
	_vig.gradient = g
	_vig.fill = GradientTexture2D.FILL_RADIAL
	_vig.fill_from = Vector2(0.5, 0.5)
	_vig.fill_to = Vector2(1.0, 0.5)
	_vig.width = 256
	_vig.height = 256
	_plate_box = StyleBoxFlat.new()
	_plate_box.bg_color = Color(PLATE, 0.9)
	_plate_box.border_color = GOLD_DIM
	_plate_box.set_border_width_all(1)
	_plate_box.set_corner_radius_all(14)
	resized.connect(queue_redraw)

# ---------------------------------------------------------------- state

## Shows a scene (data from turned_scenes.json).
func show_scene(id: String, data: Dictionary) -> void:
	var had := visible and _art_id != "" and _art_id != "<reload>"
	if had:
		_prev_tex = _tex
		_prev_blur = _blur
		_prev_art = _art_id
	scene_id = id
	scene = data
	_art_id = "<reload>"          # force a reload (no painting has this id)
	selected = -1
	refresh()
	selected = 0 if not spots.is_empty() else -1
	_fade = 0.0 if had else 1.0            # from black the first time, a crossfade from painting to painting
	_xfade = 1.0 if had else 0.0
	visible = true
	queue_redraw()

func hide_scene() -> void:
	visible = false
	enabled = false
	scene_id = ""
	scene = {}
	spots = []
	_tex = null
	_blur = null
	_art_id = ""
	_prev_tex = null
	_prev_blur = null
	_prev_art = ""
	_xfade = 0.0
	_layout = []
	_layout_key = ""

## After the state changed (a flag, an item, the hour): the painting variant and the chips.
func refresh() -> void:
	if scene.is_empty() or not holds.is_valid() or not seen.is_valid():
		return
	var art := Scenes.pick_art(scene, holds)
	if art != _art_id:
		_art_id = art
		_load_art(art)
	var old_id := str((spots[selected] as Dictionary).get("id", "")) if selected >= 0 and selected < spots.size() else ""
	spots = Scenes.visible_hotspots(scene_id, scene, holds, seen)
	selected = -1
	for i in spots.size():
		if str((spots[i] as Dictionary).get("id", "")) == old_id:
			selected = i
	if selected < 0 and not spots.is_empty():
		selected = 0
	_layout_key = ""
	queue_redraw()

func _load_art(art: String) -> void:
	_tex = Scenes.painting(art)
	_blur = null
	if _tex == null:
		return
	var img := _tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	img.resize(48, 32, Image.INTERPOLATE_BILINEAR)
	_blur = ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- geometry

func _k() -> float:
	return clampf(size.x / 900.0, 0.6, 1.0)

## The painting fitted whole into `view` (contain), centred.
static func fit_rect(view: Vector2, aspect: float) -> Rect2:
	var w := minf(view.x, view.y * aspect)
	var h := w / aspect
	return Rect2(Vector2((view.x - w) * 0.5, (view.y - h) * 0.5), Vector2(w, h))

func painting_rect() -> Rect2:
	return fit_rect(size, Scenes.PAINTING_ASPECT)

## Where every chip goes: the circle on the hotspot, the label beside it on the first side that
## stays on screen and overlaps nothing (right, left, below, above). `items` = [{id, text, pos}].
## Returns [{id, center, r, side, label_rect, hit}] (hit = what a tap counts for, at least
## `scene.chip_hit_min` tall).
static func compute_layout(view: Vector2, prect: Rect2, items: Array, k: float, font: Font) -> Array:
	var r := T.f("scene.chip_circle_r") * k
	var h := T.f("scene.chip_h") * k
	var fs := int(round(T.f("scene.chip_font") * k))
	var pad := T.f("scene.chip_pad") * k
	var gap := T.f("scene.chip_gap") * k
	var hit_min := T.f("scene.chip_hit_min") * k
	var bounds := Rect2(Vector2(6, 6), view - Vector2(12, 12))
	var placed: Array = []
	var out: Array = []
	for it in items:
		var c: Vector2 = prect.position + prect.size * Vector2(float(it["pos"][0]), float(it["pos"][1]))
		placed.append(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
		out.append({"id": it["id"], "center": c, "r": r})
	for i in items.size():
		var c: Vector2 = out[i]["center"]
		var w: float = font.get_string_size(str(items[i]["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad * 2.0
		var cands := {
			"r": Rect2(Vector2(c.x + r + gap, c.y - h * 0.5), Vector2(w, h)),
			"l": Rect2(Vector2(c.x - r - gap - w, c.y - h * 0.5), Vector2(w, h)),
			"b": Rect2(Vector2(c.x - w * 0.5, c.y + r + gap), Vector2(w, h)),
			"t": Rect2(Vector2(c.x - w * 0.5, c.y - r - gap - h), Vector2(w, h)),
		}
		var pick := ""
		for side in ["r", "l", "b", "t"]:
			var rc: Rect2 = cands[side]
			if not bounds.encloses(rc):
				continue
			var clash := false
			for j in placed.size():
				if j != i and (placed[j] as Rect2).intersects(rc):    # own circle is index i
					clash = true
					break
			if not clash:
				pick = side
				break
		if pick == "":
			for side in ["r", "l", "b", "t"]:
				if bounds.encloses(cands[side]):
					pick = side
					break
		if pick == "":
			pick = "r"
		var lr: Rect2 = cands[pick]
		placed.append(lr)
		var hit: Rect2 = Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0).merge(lr)
		if hit.size.y < hit_min:
			hit = hit.grow_individual(0.0, (hit_min - hit.size.y) * 0.5, 0.0, (hit_min - hit.size.y) * 0.5)
		out[i]["side"] = pick
		out[i]["label_rect"] = lr
		out[i]["hit"] = hit
	return out

func layout() -> Array:
	var key := "%s|%s" % [str(size), ",".join(PackedStringArray(spots.map(func(s): return str(s.get("id", "")))))]
	if key != _layout_key:
		_layout_key = key
		var items: Array = []
		for s in spots:
			items.append({"id": s.get("id", ""), "text": tr(str(SceneText.HOTSPOTS.get(str(s.get("label", "")), "?"))), "pos": s.get("pos", [0.5, 0.5])})
		_layout = compute_layout(size, painting_rect(), items, _k(), ThemeDB.fallback_font)
	return _layout

# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if not enabled or not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var lay := layout()
		for i in range(lay.size() - 1, -1, -1):
			if (lay[i]["hit"] as Rect2).has_point(event.position):
				selected = i
				keyboard_nav = false
				activate_selected()
				accept_event()
				return
	elif event is InputEventMouseMotion:
		keyboard_nav = false

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not visible:
		return
	var d := Vector2.ZERO
	if event.is_action_pressed("tn_left"):
		d = Vector2.LEFT
	elif event.is_action_pressed("tn_right"):
		d = Vector2.RIGHT
	elif event.is_action_pressed("tn_up"):
		d = Vector2.UP
	elif event.is_action_pressed("tn_down"):
		d = Vector2.DOWN
	if d != Vector2.ZERO:
		keyboard_nav = true
		move_selection(d)
		get_viewport().set_input_as_handled()

## The chip nearest in a direction (a cone of about 70 degrees), if any.
func move_selection(dir: Vector2) -> void:
	var lay := layout()
	if selected < 0 or selected >= lay.size():
		return
	var from: Vector2 = lay[selected]["center"]
	var best := -1
	var best_score := INF
	for i in lay.size():
		if i == selected:
			continue
		var delta: Vector2 = (lay[i]["center"] as Vector2) - from
		if delta.length() < 1.0 or delta.normalized().dot(dir) < 0.34:
			continue
		var score := delta.length() * (2.0 - delta.normalized().dot(dir))
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		selected = best
		queue_redraw()

func activate_selected() -> void:
	if selected >= 0 and selected < spots.size():
		hotspot_activated.emit(spots[selected])

# ---------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_fade = move_toward(_fade, 0.0, delta / maxf(T.f("scene.fade_in_s"), 0.05))
	_xfade = move_toward(_xfade, 0.0, delta / maxf(T.f("scene.crossfade_s"), 0.05))
	queue_redraw()

func _draw() -> void:
	if size.x < 10.0:
		return
	var full := Rect2(Vector2.ZERO, size)
	var pr := painting_rect()
	draw_rect(full, Color(0.02, 0.016, 0.014))
	if _blur != null:
		var m := T.f("scene.margin_dark")
		draw_texture_rect(_blur, full, false, Color(m, m, m, 1.0))
	if _tex != null:
		draw_texture_rect(_tex, pr, false)
	else:
		_draw_placeholder(pr, _art_id, 1.0)
	if _xfade > 0.001:                       # the painting that is leaving, fading out over the new one
		if _prev_blur != null:
			var m2 := T.f("scene.margin_dark")
			draw_texture_rect(_prev_blur, full, false, Color(m2, m2, m2, _xfade))
		if _prev_tex != null:
			draw_texture_rect(_prev_tex, pr, false, Color(1, 1, 1, _xfade))
		else:
			_draw_placeholder(pr, _prev_art, _xfade)
	draw_texture_rect(_vig, full, false, Color(0, 0, 0, T.f("scene.vignette")))
	_chip_a = 1.0 - _xfade
	var lay := layout()
	for i in lay.size():
		_draw_chip(lay[i], i == selected and keyboard_nav)
	if _fade > 0.001:
		draw_rect(full, Color(0, 0, 0, clampf(_fade, 0.0, 1.0)))

func _draw_placeholder(pr: Rect2, art: String, alpha: float) -> void:
	var top := Color("17171d", alpha)
	var bottom := Color("3a2a1f", alpha)
	draw_polygon(PackedVector2Array([pr.position, pr.position + Vector2(pr.size.x, 0), pr.end, pr.position + Vector2(0, pr.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var line := Color(0.8, 0.62, 0.35, 0.09 * alpha)
	for i in range(1, 12):
		var y := pr.position.y + pr.size.y * float(i) / 12.0
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), line, 1.0)
	for i in range(1, 18):
		var x := pr.position.x + pr.size.x * float(i) / 18.0
		draw_line(Vector2(x, pr.position.y), Vector2(x, pr.end.y), line, 1.0)
	var fs := int(round(30.0 * _k()))
	var font := ThemeDB.fallback_font
	var msg := tr(SceneText.UI["no_painting"])
	draw_string(font, Vector2(pr.position.x, pr.get_center().y - fs * 0.2), msg, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, fs, Color(0.8, 0.74, 0.66, 0.5 * alpha))
	draw_string(font, Vector2(pr.position.x, pr.get_center().y + fs * 1.1), art, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, int(fs * 0.7), Color(0.8, 0.74, 0.66, 0.35 * alpha))
	draw_rect(pr, Color(0.8, 0.62, 0.35, 0.35 * alpha), false, 1.5)

func _draw_chip(c: Dictionary, lit: bool) -> void:
	var k := _k()
	var ctr: Vector2 = c["center"]
	var r: float = c["r"]
	var spot: Dictionary = {}
	for s in spots:
		if str(s.get("id", "")) == str(c["id"]):
			spot = s
	var exit := str(spot.get("kind", "look")) == "exit"
	var used: bool = seen.is_valid() and seen.call(Scenes.seen_flag(scene_id, str(c["id"])))
	var a := (0.72 if used else 1.0) * _chip_a
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	if lit:
		draw_circle(ctr, r * (1.35 + 0.1 * pulse), Color(GOLD, 0.25 + 0.25 * pulse))
	draw_circle(ctr, r, Color(0.07, 0.055, 0.045, 0.88 * a))
	draw_arc(ctr, r, 0.0, TAU, 40, Color(GOLD, a), 2.4 * k + 0.6)
	if exit:
		var s := r * 0.42
		var ang: float = {"right": 0.0, "down": PI * 0.5, "left": PI, "up": -PI * 0.5}.get(str(spot.get("dir", "right")), 0.0)
		var pts := PackedVector2Array([Vector2(-s * 0.4, -s), Vector2(s * 0.7, 0), Vector2(-s * 0.4, s)])
		for i in pts.size():
			pts[i] = ctr + pts[i].rotated(ang)
		draw_polyline(pts, Color(GOLD, a), 2.8 * k + 0.4)
	else:
		var gr := r * 0.36
		var gc := ctr + Vector2(-r * 0.1, -r * 0.1)
		draw_arc(gc, gr, 0.0, TAU, 24, Color(GOLD, a), 2.4 * k + 0.4)
		draw_line(gc + Vector2(gr, gr) * 0.72, gc + Vector2(gr, gr) * 1.75, Color(GOLD, a), 3.0 * k + 0.4)
	var lr: Rect2 = c["label_rect"]
	_plate_box.bg_color = Color(PLATE, 0.9 * a)
	_plate_box.border_color = Color(GOLD if lit else GOLD_DIM, a)
	draw_style_box(_plate_box, lr)
	var fs := int(round(T.f("scene.chip_font") * k))
	var text := tr(str(SceneText.HOTSPOTS.get(str(spot.get("label", "")), "?")))
	var font := ThemeDB.fallback_font
	var baseline := lr.position.y + lr.size.y * 0.5 + fs * 0.32
	draw_string(font, Vector2(lr.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, fs, Color(0.96, 0.93, 0.88, a))
