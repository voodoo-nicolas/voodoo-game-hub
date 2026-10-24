extends Control

## Scene mode's interface (docs/turned/SCENE_MODE_PLAN.md, phase S2; look from the owner's mockups):
## top left a gold-ringed portrait with the Health and Blood bars and the objective panel under
## it; top right the Pause button and the day chip; down the right edge a vertical strip of
## the nav buttons (Inventory, Map, Journal, Shelter, Contacts), each shown only once the story
## introduces it. All drawn in code; a picture replaces a piece by file name (see ICON_DIR).
## It reads the world (`world.engine`, `world.clock`, `world.hud` for the reveal state) and tells it
## what was pressed: `pause_pressed`, `nav_pressed(id)`. Walk mode never shows it.

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Text = preload("res://scripts/games/turned/turned_text.gd")
const SceneText = preload("res://scripts/games/turned/turned_scene_text.gd")

signal pause_pressed
## "inventory", "map", "journal", "shelter" or "contacts".
signal nav_pressed(id: String)

const GOLD := Color("ce9e58")
const GOLD_DIM := Color("b6a58d")
const PLATE := Color("16100b")
const CHIP := Color("201d1e")
const HEALTH := Color("8f3634")
const BLOOD := Color("5d91a2")
const TEXT := Color("f3ede2")
const NAV_IDS := ["inventory", "map", "journal", "shelter", "contacts"]
## Optional pictures (the owner's UI-01..UI-09 icons and the player's bust): res://games/turned/art/ui/nav_<id>.png,
## sun.png, crescent.png, portrait_player.png. Missing = drawn here.
const ICON_DIR := "res://games/turned/art/ui/"

var enabled := false                 # the world sets it: false while a dialogue, the menu or the kit has the screen
var world: Node = null               # the Turned world (engine, clock, hud)

var _hp_disp := 0.0
var _blood_disp := 0.0
var _fade := {"cluster": 0.0, "objective": 0.0, "nav": 0.0}
var _icons := {}                     # name -> Texture2D or false (looked up once)
var _box: StyleBoxFlat = null
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE      # taps are read in _input so the painting below still gets its own
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	_box = StyleBoxFlat.new()
	resized.connect(queue_redraw)

# ---------------------------------------------------------------- what is shown

func _engine() -> Object:
	return world.engine if world != null else null

func _clock() -> Object:
	return world.clock if world != null else null

func _revealed(part: String) -> bool:
	return world != null and world.hud != null and world.hud.is_revealed(part)

## The nav buttons to show now: the story introduces each one. Inventory once you carry something,
## Journal once it has a line; Map, Shelter and Contacts when their flag `nav_<id>` is set.
func nav_visible() -> Array:
	var e := _engine()
	var out: Array = []
	if e == null:
		return out
	for id in NAV_IDS:
		var on := false
		match id:
			"inventory": on = not e.items.is_empty()
			"journal": on = not e.journal.is_empty()
			_: on = e.has_flag("nav_" + id)
		if on:
			out.append(id)
	return out

## A red dot on the Journal until it was opened since its last new line.
func journal_unread() -> bool:
	var e := _engine()
	return e != null and not e.journal.is_empty() and not e.has_flag(read_flag(e.journal.size()))

static func read_flag(count: int) -> String:
	return "journal_read_%d" % count

## "morning", "afternoon", "evening" or "night" (a key of SceneText.UI).
static func period_id(hour: float) -> String:
	if hour < 5.0 or hour >= 21.0:
		return "night"
	if hour < 12.0:
		return "morning"
	if hour < 17.0:
		return "afternoon"
	return "evening"

# ---------------------------------------------------------------- geometry

func _k() -> float:
	return clampf(minf(size.x / 900.0, size.y / 640.0), 0.6, 1.0)

## The scale for a screen: the interface shrinks on a short screen (text size 1.4) as well as a narrow one.
static func scale_for(view: Vector2) -> float:
	return clampf(minf(view.x / 900.0, view.y / 640.0), 0.6, 1.0)

## Every rectangle, in screen units, for a screen `view`, scale `k` (scale_for) and the nav ids shown.
## Static so the test can check it at any screen shape.
static func compute_layout(view: Vector2, k: float, nav_ids: Array) -> Dictionary:
	var m := 10.0 * k
	var r := 38.0 * k
	var ring := Rect2(Vector2(m, m), Vector2(r, r) * 2.0)
	var bx := ring.end.x + 10.0 * k
	var bw := 152.0 * k
	var bh := 19.0 * k
	var by := ring.get_center().y - bh - 3.0 * k
	var bars := [Rect2(Vector2(bx, by), Vector2(bw, bh)), Rect2(Vector2(bx, by + bh + 6.0 * k), Vector2(bw, bh))]
	var obj_w := bx + bw - m
	var obj_h := 32.0 * k                   # one line: the text shrinks to fit
	var objective := Rect2(Vector2(m, ring.end.y + 8.0 * k), Vector2(obj_w, obj_h))
	var chip_w := 176.0 * k
	var chip_h := 54.0 * k
	var chip := Rect2(Vector2(view.x - m - chip_w, m), Vector2(chip_w, chip_h))
	var pause := Rect2(Vector2(chip.position.x - 8.0 * k - chip_h, m), Vector2(chip_h, chip_h))
	var slot_w := 72.0 * k
	var slot_h := 80.0 * k
	var nav: Array = []
	var top := chip.end.y + 14.0 * k
	var avail := view.y - top - m - 50.0 * k          # keep the bottom band (the dialogue box) clear
	var step := minf(slot_h, avail / maxf(1.0, float(nav_ids.size())))
	for i in nav_ids.size():
		nav.append({"id": nav_ids[i], "rect": Rect2(Vector2(view.x - m - slot_w, top + step * i), Vector2(slot_w, step))})
	var plate := Rect2()
	if not nav.is_empty():
		plate = Rect2(Vector2(view.x - m - slot_w, top), Vector2(slot_w, step * nav_ids.size()))
	return {"ring": ring, "bars": bars, "objective": objective, "chip": chip, "pause": pause, "nav": nav, "nav_plate": plate}

func _objective_text() -> String:
	var e := _engine()
	if e != null and e.mission != "":
		return tr(Text.MISSIONS.get(e.mission, e.mission))
	return tr(Text.UI["no_mission"])

## The objective on one line: the font shrinks to 12, then the text is cut with an ellipsis.
func _fit_objective(width: float, fs: int) -> Array:
	var f := ThemeDB.fallback_font
	var s := _objective_text()
	while fs > 12 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	while s.length() > 1 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		s = s.substr(0, s.length() - 2).strip_edges() + "..."
	return [s, fs]

func _obj_font() -> int:
	return int(round(19.0 * _k()))

func layout() -> Dictionary:
	return compute_layout(size, _k(), nav_visible())

# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not enabled or not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var lay := layout()
		var p: Vector2 = event.position - global_position
		if (lay["pause"] as Rect2).grow(6.0 * _k()).has_point(p):
			get_viewport().set_input_as_handled()
			pause_pressed.emit()
			return
		if _fade["nav"] > 0.5:
			for n in lay["nav"]:
				if (n["rect"] as Rect2).has_point(p):
					get_viewport().set_input_as_handled()
					nav_pressed.emit(str(n["id"]))
					return

# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if not visible or world == null:
		return
	_t += delta
	var e := _engine()
	if e != null:
		_hp_disp = move_toward(_hp_disp, e.hp, maxf(20.0 * delta, absf(e.hp - _hp_disp) * 8.0 * delta))
		_blood_disp = move_toward(_blood_disp, e.blood, 40.0 * delta)
		if world.hud != null and world.hud.menu_open and world.hud._menu_tab == "journal" and not e.journal.is_empty():
			e.set_flag(read_flag(e.journal.size()))
	var step := delta / maxf(T.f("ui.reveal_s"), 0.05)
	_fade["cluster"] = move_toward(_fade["cluster"], 1.0 if _revealed("bars") else 0.0, step)
	_fade["objective"] = move_toward(_fade["objective"], 1.0 if _revealed("mission") else 0.0, step)
	_fade["nav"] = move_toward(_fade["nav"], 1.0 if not nav_visible().is_empty() else 0.0, step)
	queue_redraw()

# ---------------------------------------------------------------- drawing

func _icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var found: Variant = false
		for ext in ["png", "webp"]:
			var p: String = ICON_DIR + name + "." + ext
			if ResourceLoader.exists(p):
				found = load(p)
				break
		_icons[name] = found
	return _icons[name] if _icons[name] is Texture2D else null

func _text(pos: Vector2, s: String, fs: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, s, align, width, fs, 3, Color(0, 0, 0, col.a * 0.6))
	draw_string(f, pos, s, align, width, fs, col)

func _draw() -> void:
	if size.x < 10.0 or world == null:
		return
	var k := _k()
	var lay := layout()
	var a: float = _fade["cluster"]
	if a > 0.01:
		_draw_ring(lay["ring"], a)
		_draw_bar(lay["bars"][0], _hp_disp / maxf(1.0, _engine().max_hp), HEALTH, tr(Text.UI["health"]), "%d" % int(ceilf(_hp_disp)), a)
		_draw_bar(lay["bars"][1], _blood_disp / maxf(1.0, _engine().max_blood), BLOOD, tr(Text.UI["blood"]), "%d" % int(_blood_disp), a)
		_draw_day_chip(lay["chip"], a)
	if _fade["objective"] > 0.01:
		_draw_objective(lay["objective"], _fade["objective"])
	_draw_pause(lay["pause"])
	if _fade["nav"] > 0.01 and not (lay["nav"] as Array).is_empty():
		_draw_nav(lay["nav_plate"], lay["nav"], _fade["nav"], k)

func _frame(r: Rect2, fill: Color, border: Color, radius: float, bw: float = 1.0) -> void:
	_box.bg_color = fill
	_box.border_color = border
	_box.set_border_width_all(int(maxf(1.0, round(bw))))
	_box.set_corner_radius_all(int(round(radius)))
	draw_style_box(_box, r)

func _draw_ring(r: Rect2, a: float) -> void:
	var c := r.get_center()
	var rad := r.size.x * 0.5
	var k := _k()
	draw_circle(c, rad, Color(0.07, 0.055, 0.045, 0.92 * a))
	var tex := _icon("portrait_player")
	if tex != null:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 48:
			var ang := TAU * float(i) / 48.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad * 0.94)
			uvs.append(Vector2(0.5 + cos(ang) * 0.47, 0.5 + sin(ang) * 0.47))
		draw_polygon(pts, PackedColorArray([Color(1, 1, 1, a)]), uvs, tex)
	else:
		# a silhouette until the player's bust exists: a head and shoulders cut to the ring
		var col := Color(0.5, 0.42, 0.34, 0.6 * a)
		draw_circle(c + Vector2(0, -rad * 0.2), rad * 0.3, col)
		var ring_poly := _circle_poly(c, rad * 0.94, 40)
		var shoulders := _circle_poly(c + Vector2(0, rad * 1.0), rad * 0.66, 40)
		for poly in Geometry2D.intersect_polygons(ring_poly, shoulders):
			draw_colored_polygon(poly, col)
	draw_arc(c, rad, 0.0, TAU, 48, Color(GOLD, a), 3.0 * k + 0.5)
	draw_arc(c, rad + 4.0 * k, 0.0, TAU, 48, Color(GOLD_DIM, 0.8 * a), 1.2 * k + 0.4)

static func _circle_poly(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var ang := TAU * float(i) / float(n)
		p.append(c + Vector2(cos(ang), sin(ang)) * r)
	return p

func _draw_bar(r: Rect2, frac: float, col: Color, label: String, value: String, a: float) -> void:
	_frame(r, Color(PLATE, 0.9 * a), Color(GOLD_DIM, 0.9 * a), r.size.y * 0.5)
	var inner := r.grow(-2.0)
	var w := inner.size.x * clampf(frac, 0.0, 1.0)
	if w > 1.0:
		_frame(Rect2(inner.position, Vector2(maxf(w, inner.size.y), inner.size.y)), Color(col, a), Color(col.lightened(0.25), 0.0), inner.size.y * 0.5, 1.0)
	var fs := maxi(11, int(round(r.size.y * 0.68)))
	var base := r.position.y + r.size.y * 0.5 + fs * 0.34
	_text(Vector2(r.position.x + r.size.y * 0.5, base), label, fs, Color(TEXT, a))
	_text(Vector2(r.end.x - r.size.y * 0.5 - 60.0, base), value, fs, Color(TEXT, a), HORIZONTAL_ALIGNMENT_RIGHT, 60.0)

func _draw_day_chip(r: Rect2, a: float) -> void:
	var k := _k()
	var clock := _clock()
	_frame(r, Color(CHIP, 0.92 * a), Color(GOLD, a), 10.0 * k, 1.5)
	var day := int(clock.day) if clock != null else 1
	var hour := float(clock.hour) if clock != null else 7.0
	var sun: bool = clock == null or float(clock.intensity()) >= float(clock.moon_level())
	var ic := Vector2(r.position.x + r.size.y * 0.5, r.get_center().y)
	var tex := _icon("sun" if sun else "crescent")
	if tex != null:
		draw_texture_rect(tex, Rect2(ic - Vector2(16, 16) * k, Vector2(32, 32) * k), false, Color(1, 1, 1, a))
	elif sun:
		var col := Color(GOLD, a)
		draw_circle(ic, 8.0 * k, col)
		for i in 8:
			var ang := TAU * float(i) / 8.0
			draw_line(ic + Vector2(cos(ang), sin(ang)) * 11.5 * k, ic + Vector2(cos(ang), sin(ang)) * 15.0 * k, col, 2.0 * k + 0.4)
	else:
		draw_arc(ic + Vector2(2.0, 0.0) * k, 8.0 * k, deg_to_rad(105.0), deg_to_rad(255.0), 18, Color(0.82, 0.86, 1.0, a), 6.0 * k)
	var tx := r.position.x + r.size.y
	var fs1 := int(round(21.0 * k))
	var fs2 := int(round(15.0 * k))
	_text(Vector2(tx, r.position.y + r.size.y * 0.46), tr(SceneText.UI["day"]) % day, fs1, Color(TEXT, a))
	var sub := "%s  %s" % [tr(SceneText.UI[period_id(hour)]), clock.hour_text() if clock != null else ""]
	_text(Vector2(tx, r.position.y + r.size.y * 0.82), sub, fs2, Color(GOLD_DIM, a), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - 6.0 * k)

func _draw_objective(r: Rect2, a: float) -> void:
	var k := _k()
	_frame(r, Color(PLATE, 0.86 * a), Color(GOLD_DIM, 0.8 * a), 8.0 * k)
	# the gold diamond bullet
	var c := Vector2(r.position.x + 16.0 * k, r.get_center().y)
	var d := 6.0 * k
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), Color(GOLD, a))
	var tx := r.position.x + 30.0 * k
	var fit := _fit_objective(r.end.x - tx - 8.0 * k, _obj_font())
	_text(Vector2(tx, r.position.y + r.size.y * 0.5 + int(fit[1]) * 0.34), str(fit[0]), int(fit[1]), Color(TEXT, a))

func _draw_pause(r: Rect2) -> void:
	var k := _k()
	_frame(r, Color(CHIP, 0.92), Color(GOLD_DIM, 0.95), 10.0 * k, 1.5)
	var c := r.get_center()
	var bw := 5.0 * k
	var bh := 18.0 * k
	draw_rect(Rect2(c + Vector2(-bw * 1.7, -bh * 0.5), Vector2(bw, bh)), Color(TEXT, 0.95))
	draw_rect(Rect2(c + Vector2(bw * 0.7, -bh * 0.5), Vector2(bw, bh)), Color(TEXT, 0.95))

func _draw_nav(plate: Rect2, slots: Array, a: float, k: float) -> void:
	_frame(plate.grow(4.0 * k), Color(Color("0a0a0a"), 0.88 * a), Color(GOLD_DIM, 0.7 * a), 10.0 * k)
	for n in slots:
		var r: Rect2 = n["rect"]
		var id := str(n["id"])
		var cx := r.get_center().x
		var icy := r.position.y + r.size.y * 0.4
		_draw_nav_icon(id, Vector2(cx, icy), 17.0 * k, a)
		_text(Vector2(r.position.x, r.end.y - 9.0 * k), tr(SceneText.UI["nav_" + id]), int(round(13.0 * k)), Color(GOLD_DIM, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if id == "journal" and journal_unread():
			draw_circle(Vector2(cx + 15.0 * k, icy - 15.0 * k), 6.5 * k, Color("d03030", a))
			_text(Vector2(cx + 11.5 * k, icy - 11.0 * k), "!", int(round(11.0 * k)), Color(1, 1, 1, a))

## Embossed gold icons, drawn in code; nav_<id>.png in ICON_DIR replaces one.
func _draw_nav_icon(id: String, c: Vector2, s: float, a: float) -> void:
	var tex := _icon("nav_" + id)
	if tex != null:
		draw_texture_rect(tex, Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(1, 1, 1, a))
		return
	var col := Color(GOLD, a)
	var w := maxf(1.6, s * 0.12)
	match id:
		"inventory":
			draw_rect(Rect2(c + Vector2(-s, -s * 0.45), Vector2(s * 2.0, s * 1.3)), col, false, w)
			draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.9), Vector2(s * 0.8, s * 0.45)), col, false, w)
			draw_line(c + Vector2(-s, s * 0.1), c + Vector2(s, s * 0.1), col, w)
			draw_rect(Rect2(c + Vector2(-s * 0.14, -s * 0.05), Vector2(s * 0.28, s * 0.3)), col)
		"map":
			var p := PackedVector2Array([c + Vector2(-s, -s * 0.7), c + Vector2(-s * 0.33, -s * 0.9), c + Vector2(s * 0.33, -s * 0.7), c + Vector2(s, -s * 0.9),
				c + Vector2(s, s * 0.7), c + Vector2(s * 0.33, s * 0.9), c + Vector2(-s * 0.33, s * 0.7), c + Vector2(-s, s * 0.9), c + Vector2(-s, -s * 0.7)])
			draw_polyline(p, col, w)
			draw_line(c + Vector2(-s * 0.33, -s * 0.9), c + Vector2(-s * 0.33, s * 0.7), col, w * 0.8)
			draw_line(c + Vector2(s * 0.33, -s * 0.7), c + Vector2(s * 0.33, s * 0.9), col, w * 0.8)
		"journal":
			draw_rect(Rect2(c + Vector2(-s * 0.8, -s), Vector2(s * 1.6, s * 2.0)), col, false, w)
			draw_line(c + Vector2(-s * 0.45, -s), c + Vector2(-s * 0.45, s), col, w * 0.8)
			draw_line(c + Vector2(-s * 0.1, -s * 0.45), c + Vector2(s * 0.5, -s * 0.45), col, w * 0.7)
			draw_line(c + Vector2(-s * 0.1, -s * 0.1), c + Vector2(s * 0.5, -s * 0.1), col, w * 0.7)
			draw_rect(Rect2(c + Vector2(s * 0.2, s * 0.55), Vector2(s * 0.28, s * 0.62)), col)
		"shelter":
			draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.05), c + Vector2(0, -s * 0.95), c + Vector2(s, -s * 0.05)]), col, w)
			draw_rect(Rect2(c + Vector2(-s * 0.72, -s * 0.05), Vector2(s * 1.44, s * 1.0)), col, false, w)
			draw_arc(c + Vector2(s * 0.05, s * 0.45), s * 0.3, deg_to_rad(105.0), deg_to_rad(255.0), 12, col, w * 1.6)
		"contacts":
			draw_circle(c + Vector2(-s * 0.4, -s * 0.4), s * 0.32, col)
			draw_circle(c + Vector2(s * 0.45, -s * 0.3), s * 0.28, Color(col, a * 0.75))
			draw_arc(c + Vector2(-s * 0.4, s * 0.85), s * 0.7, deg_to_rad(200.0), deg_to_rad(340.0), 14, col, w * 1.4)
			draw_arc(c + Vector2(s * 0.45, s * 0.8), s * 0.6, deg_to_rad(200.0), deg_to_rad(340.0), 14, Color(col, a * 0.75), w * 1.2)
