extends Control

## The evolution tree as a map (like a skill tree): your creature at the far left, four branches growing
## to the right. Drag to move around, tap a trait to select it. Owned traits glow in their branch colour,
## ones you can buy pulse white, ones not unlocked yet show a "?". Lines join each trait to the ones it
## needs (some need several) and to the ones it opens (some open several).

const Art = preload("res://scripts/games/evolution/evolution_art.gd")
const Data = preload("res://scripts/games/evolution/evolution_data.gd")

signal selected(id: String)

const CELL := Vector2(150.0, 92.0)
const PAD := 40.0
const ROOT_X := 120.0
const NODE_R := 28.0

var engine
var color := Color("29e6ff")
var col2 := Color("ffd23f")
var col3 := Color("ff4f9a")
var voodoo := false
var show_names := false:
	set(v):
		show_names = v
		queue_redraw()
var selected_id := ""
var pan := Vector2.ZERO
var _t := 0.0
var _press := Vector2.ZERO
var _pressing := false
var _dragged := false
var _touch_seen := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()

## Size of the whole map in pixels.
func map_size() -> Vector2:
	var max_x := 0.0
	var max_y := 0.0
	for n in Data.NODES:
		max_x = maxf(max_x, float(n.x))
		max_y = maxf(max_y, float(n.y))
	return Vector2(ROOT_X + (max_x + 1.0) * CELL.x + PAD, (max_y + 1.0) * CELL.y + PAD * 2.0)

func root_pos() -> Vector2:
	return Vector2(ROOT_X, map_size().y * 0.5)

func node_pos(n: Dictionary) -> Vector2:
	return Vector2(ROOT_X + float(n.x) * CELL.x, PAD + float(n.y) * CELL.y + CELL.y * 0.5)

## Starts with the creature in view, vertically centred.
func reset_view() -> void:
	pan = Vector2(0.0, size.y * 0.5 - root_pos().y)
	_clamp_pan()
	queue_redraw()

func _clamp_pan() -> void:
	var m := map_size()
	pan.x = clampf(pan.x, minf(size.x - m.x, 0.0), 0.0)
	pan.y = clampf(pan.y, minf(size.y - m.y, 0.0), 0.0)

## Touch screens: drag with a finger (the emulated mouse is ignored once a real touch is seen).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_touch_seen = true
		var inside := get_global_rect().has_point(event.position)
		if event.pressed and inside:
			_pressing = true
			_dragged = false
			_press = event.position - global_position
		elif not event.pressed and _pressing:
			if not _dragged:
				_tap(event.position - global_position)
			_pressing = false
	elif event is InputEventScreenDrag and _pressing:
		if not _dragged and (event.position - global_position).distance_to(_press) > 10.0:
			_dragged = true
		if _dragged:
			pan += event.relative
			_clamp_pan()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				pan.x += 80.0
			KEY_RIGHT:
				pan.x -= 80.0
			KEY_UP:
				pan.y += 80.0
			KEY_DOWN:
				pan.y -= 80.0
		_clamp_pan()

func _gui_input(event: InputEvent) -> void:
	if _touch_seen and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressing = true
				_dragged = false
				_press = event.position
			else:
				if _pressing and not _dragged:
					_tap(event.position)
				_pressing = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			pan.y += 60.0
			_clamp_pan()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pan.y -= 60.0
			_clamp_pan()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			pan.x += 60.0
			_clamp_pan()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			pan.x -= 60.0
			_clamp_pan()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragged and event.position.distance_to(_press) > 10.0:
			_dragged = true
		if _dragged:
			pan += event.relative
			_clamp_pan()

func _tap(pos: Vector2) -> void:
	var p := pos - pan
	var hit := ""
	for n in Data.NODES:
		if node_pos(n).distance_to(p) <= NODE_R + 10.0:
			hit = n.id
			break
	selected_id = hit
	selected.emit(hit)
	queue_redraw()

# ---------- drawing ----------

func _branch_col(n: Dictionary) -> Color:
	return Data.BRANCH[n.branch].col

func _draw() -> void:
	if engine == null:
		return
	draw_set_transform(pan, 0.0, Vector2.ONE)
	var rp := root_pos()
	# branch titles
	for b in Data.BRANCH_ORDER:
		var y0 := 1.0e9
		var x0 := 1.0e9
		for n in Data.NODES:
			if n.branch == b:
				y0 = minf(y0, node_pos(n).y)
				x0 = minf(x0, node_pos(n).x)
		draw_string(ThemeDB.fallback_font, Vector2(x0 - NODE_R, y0 - NODE_R - 14.0), tr(Data.BRANCH[b].name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Data.BRANCH[b].col, 0.85))
	# lines first
	for n in Data.NODES:
		var to := node_pos(n)
		var col := _branch_col(n)
		var sources: Array = []
		if n.req.is_empty():
			sources.append(["", 0])
		else:
			for r in n.req:
				sources.append(r)
		for r in sources:
			var from := rp
			var lit: bool = engine.rank_of(n.id) > 0
			if r[0] != "":
				var fn: Dictionary = Data.node_of(r[0])
				from = node_pos(fn)
				lit = engine.rank_of(r[0]) >= int(r[1]) and engine.rank_of(n.id) > 0
			else:
				lit = engine.rank_of(n.id) > 0
			var mid := Vector2((from.x + to.x) * 0.5, to.y)
			var pts := PackedVector2Array([from, Vector2(mid.x, from.y), mid, to]) if absf(from.y - to.y) > 4.0 else PackedVector2Array([from, to])
			if lit:
				Art.strip(self, pts, Color(col, 0.35), 8.0, true)
			Art.strip(self, pts, Color(col, 0.95) if lit else Color(1, 1, 1, 0.16), 3.0, true)
	# the creature
	Art.disc(self, rp, 74.0, Color(color, 0.08))
	Art.arc(self, rp, 64.0, 0.0, TAU, 40, Color(color, 0.6), 3.0, true)
	var st := {"move_rank": engine.move_rank, "sight_rank": engine.sight_rank, "eye_open": 1.0, "owned": engine.owned, "specials": engine.specials, "speed": 0.0, "voodoo": voodoo, "col2": col2, "col3": col3}
	Art.draw_player(self, rp + pan, 40.0, color, 0.0, _t, st)
	draw_set_transform(pan, 0.0, Vector2.ONE)
	# nodes
	for n in Data.NODES:
		_draw_node(n)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# thin scroll bars, so it is clear the map goes on
	var m := map_size()
	if m.y > size.y:
		var h := size.y * size.y / m.y
		var y0 := -pan.y / m.y * size.y
		draw_rect(Rect2(size.x - 6.0, y0, 4.0, h), Color(1, 1, 1, 0.35))
	if m.x > size.x:
		var w := size.x * size.x / m.x
		var x0 := -pan.x / m.x * size.x
		draw_rect(Rect2(x0, size.y - 6.0, w, 4.0), Color(1, 1, 1, 0.35))

func _draw_node(n: Dictionary) -> void:
	var c := node_pos(n)
	var col := _branch_col(n)
	var state: String = engine.node_state(n.id)
	var rank: int = engine.rank_of(n.id)
	var mx := int(n.max)
	var can: bool = engine.can_buy(n.id)
	var glow := 0.5 + 0.5 * sin(_t * 4.0)
	Art.disc(self, c, NODE_R, Color(0.03, 0.05, 0.1, 0.95))
	match state:
		"maxed", "owned":
			Art.disc(self, c, NODE_R + 6.0, Color(col, 0.18))
			Art.arc(self, c, NODE_R, 0.0, TAU, 32, col, 4.0 if state == "maxed" else 3.0, true)
			Art.disc(self, c, NODE_R * 0.55, Color(col, 0.75 if state == "maxed" else 0.45))
		"available":
			Art.arc(self, c, NODE_R, 0.0, TAU, 32, Color(1, 1, 1, 0.55 + 0.4 * glow), 3.0, true)
			Art.disc(self, c, NODE_R * 0.4, Color(col, 0.35))
		"stage":
			# Readable (the trait before it is owned), but you must grow first: dim, no pulse.
			Art.arc(self, c, NODE_R, 0.0, TAU, 32, Color(col, 0.45), 2.0, true)
			Art.disc(self, c, NODE_R * 0.4, Color(col, 0.18))
		_:
			Art.arc(self, c, NODE_R, 0.0, TAU, 32, Color(1, 1, 1, 0.2), 2.0, true)
			draw_string(ThemeDB.fallback_font, c + Vector2(-8.0, 9.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.4))
	var known: bool = state != "locked"
	if n.ability and known:
		draw_colored_polygon(PackedVector2Array([c + Vector2(3, -12), c + Vector2(-6, 2), c + Vector2(-1, 2), c + Vector2(-4, 13), c + Vector2(7, -3), c + Vector2(2, -3)]), Color(1, 0.9, 0.4, 0.95))
	# points: one pip per point
	if mx > 1 and known:
		var w := float(mx - 1) * 11.0
		for i in mx:
			var p := c + Vector2(-w * 0.5 + float(i) * 11.0, NODE_R + 10.0)
			if i < rank:
				Art.disc(self, p, 4.0, col)
			else:
				Art.arc(self, p, 4.0, 0.0, TAU, 10, Color(1, 1, 1, 0.5), 1.5, true)
	if n.id == selected_id:
		Art.arc(self, c, NODE_R + 9.0, 0.0, TAU, 40, Color("ffd479"), 3.0, true)
	if (show_names or n.id == selected_id) and known:
		var label := tr(n.name)
		var f := ThemeDB.fallback_font
		var wd := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var at := c + Vector2(-wd * 0.5, NODE_R + (36.0 if mx > 1 else 26.0))
		draw_string_outline(f, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
		draw_string(f, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.95))
