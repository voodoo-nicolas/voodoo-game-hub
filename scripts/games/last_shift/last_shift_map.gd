extends Control

## The building map (v0.5, playtest: "add a map we can access?"). Opens from the map button left of
## pause, the pause menu, or the M key; the game is paused while it is up. A schematic, not to
## scale: one box per room, laid out the way the doors connect them (east doors lead right, north
## doors up...). Only rooms Nash has been in are drawn; rooms next to them show as "?" outlines.
## The room he is in is amber, with a dot where he stands. The elevator (lobby <-> cooling plant) is
## the dashed line along the bottom.
## The world owns the data; this only draws it. Taps are mouse-button events (phones send them for
## touches too), never ScreenTouch.

const LsText = preload("res://scripts/games/last_shift/last_shift_text.gd")
const LsUi = preload("res://scripts/games/last_shift/last_shift_ui.gd")
const A = preload("res://scripts/games/last_shift/last_shift_art.gd")

signal closed

## Grid spot of each room: x = column, y = row (0 = the main route; negative = north of it).
const LAYOUT := {
	"plant": Vector2i(0, 0), "corridor": Vector2i(1, 0), "pump_room": Vector2i(2, 0),
	"locker_room": Vector2i(3, 0), "break_room": Vector2i(4, 0), "security_hall": Vector2i(5, 0),
	"security_office": Vector2i(6, 0), "open_office": Vector2i(7, 0), "call_center": Vector2i(8, 0),
	"lobby_hall": Vector2i(9, 0), "lobby": Vector2i(10, 0), "parking_lot": Vector2i(11, 0),
	"cooling_floor": Vector2i(1, -1), "armory": Vector2i(6, -1), "cs_offices": Vector2i(8, -1),
	"server_room": Vector2i(6, -2), "server_floor": Vector2i(7, -2), "side_street": Vector2i(8, -2),
	"cafeteria": Vector2i(4, 1), "loading_dock": Vector2i(5, 1), "service_yard": Vector2i(6, 1),
	"janitor": Vector2i(9, 1),
}
const COLS := 12
const ROW_MIN := -2
const ROW_MAX := 1
## Ways out: drawn with a green edge.
const EXITS := ["parking_lot", "service_yard", "side_street"]

var rooms := {}            # the room data (LsRooms.rooms()), for the doors between rooms
var visited := {}          # room id -> true
var current := ""
var nash_frac := Vector2(0.5, 0.5)   # where Nash stands in the current room (0..1 each way)
var _t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # works while the game is paused
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func open(room_data: Dictionary, visited_rooms: Dictionary, current_room: String, frac: Vector2) -> void:
	rooms = room_data
	visited = visited_rooms
	current = current_room
	nash_frac = frac
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()       # the "you are here" dot pulses

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		closed.emit()

## Every pair of rooms joined by a door (each pair once).
func _links() -> Array:
	var out: Array = []
	var seen := {}
	for rid in rooms:
		for pd in rooms[rid].props:
			if not (pd.kind in ["door", "elevator"]) or not pd.has("to"):
				continue
			if pd.kind == "elevator":
				continue          # drawn as the dashed elevator line instead
			var a: String = rid
			var b: String = pd.to
			var key := a + "|" + b if a < b else b + "|" + a
			if seen.has(key) or not LAYOUT.has(a) or not LAYOUT.has(b):
				continue
			seen[key] = true
			out.append([a, b])
	return out

## Shown: visited, or next to a visited room ("?").
func _known(rid: String) -> int:
	if visited.has(rid):
		return 2
	for l in _links():
		if (l[0] == rid and visited.has(l[1])) or (l[1] == rid and visited.has(l[0])):
			return 1
	return 0

func _cell_rect(rid: String) -> Rect2:
	var g: Vector2i = LAYOUT[rid]
	var area := Rect2(Vector2(40, 96), size - Vector2(80, 170))
	var col_w := area.size.x / COLS
	var row_h := area.size.y / float(ROW_MAX - ROW_MIN + 1)
	var box := Vector2(col_w - 12.0, minf(64.0, row_h - 30.0))
	var c := area.position + Vector2((g.x + 0.5) * col_w, (g.y - ROW_MIN + 0.5) * row_h)
	return Rect2(c - box * 0.5, box)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.045, 0.94))
	var font := ThemeDB.fallback_font
	var title := tr(LsText.UI.map_title)
	draw_string_outline(font, Vector2(40, 58), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color.BLACK)
	draw_string(font, Vector2(40, 58), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("ffd479"))
	var hint := tr(LsText.UI.map_close)
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(size.x - hw - 40, 56), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.55))
	# doors between rooms
	for l in _links():
		var ka := _known(l[0])
		var kb := _known(l[1])
		if ka == 0 or kb == 0 or (ka < 2 and kb < 2):
			continue
		var ra := _cell_rect(l[0])
		var rb := _cell_rect(l[1])
		draw_line(ra.get_center(), rb.get_center(), Color(1, 1, 1, 0.35), 4.0)
	# the elevator, lobby <-> cooling plant (dashed, under everything)
	if visited.has("lobby") and visited.has("plant"):
		var rl := _cell_rect("lobby")
		var rp := _cell_rect("plant")
		var y := size.y - 84.0
		var pts := [Vector2(rl.get_center().x, rl.end.y), Vector2(rl.get_center().x, y),
			Vector2(rp.get_center().x, y), Vector2(rp.get_center().x, rp.end.y)]
		for i in 3:
			draw_dashed_line(pts[i], pts[i + 1], Color(1, 1, 1, 0.3), 2.0, 8.0)
		var el := tr(LsText.UI.elevator).strip_edges().to_upper()
		draw_string(font, Vector2((pts[1].x + pts[2].x) * 0.5 - 30, y - 6), el, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.45))
	# the rooms
	for rid in LAYOUT:
		var k := _known(rid)
		if k == 0:
			continue
		var r := _cell_rect(rid)
		if k == 1:
			draw_rect(r, Color(1, 1, 1, 0.04))
			draw_rect(r, Color(1, 1, 1, 0.25), false, 2.0)
			var qw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(font, r.get_center() + Vector2(-qw * 0.5, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.4))
			continue
		var here: bool = rid == current
		var fill := Color(0.88, 0.6, 0.1, 0.85) if here else Color(0.16, 0.17, 0.2, 0.95)
		draw_rect(r, fill)
		var edge := Color("6fd05a") if rid in EXITS else (A.AMBER if here else Color(1, 1, 1, 0.55))
		draw_rect(r, edge, false, 3.0 if here or rid in EXITS else 2.0)
		var name := tr(String(LsText.ROOM_NAMES.get(rid, rid)))
		var fs := 13
		var tcol := Color("0e0e12") if here else Color(1, 1, 1, 0.9)
		draw_multiline_string(font, r.position + Vector2(5, 5 + font.get_ascent(fs)), name, HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x - 10, fs, 3, tcol)
		if here:
			var p := r.position + Vector2(r.size.x * clampf(nash_frac.x, 0.05, 0.95), r.size.y * clampf(nash_frac.y, 0.1, 0.95))
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			draw_circle(p, 7.0 + pulse * 2.0, Color(0.9, 0.1, 0.1, 0.35))
			draw_circle(p, 5.0, A.INK)
			draw_circle(p, 3.6, Color("ff4a3a"))
	if current != "" and LAYOUT.has(current):
		var r2 := _cell_rect(current)
		var you := tr(LsText.UI.map_you)
		var yw := font.get_string_size(you, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string_outline(font, Vector2(r2.get_center().x - yw * 0.5, r2.position.y - 8), you, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(font, Vector2(r2.get_center().x - yw * 0.5, r2.position.y - 8), you, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd479"))
