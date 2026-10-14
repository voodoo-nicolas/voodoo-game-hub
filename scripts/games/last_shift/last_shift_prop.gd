extends StaticBody2D

## A room object drawn in the comic-ink style (see last_shift_art.gd): valves, chiller, gauges,
## terminals, lockers, doors, vending machine, desks, cars, signs, plants and so on.
## Data comes from last_shift_rooms.gd. The world script decides what interacting does; this class
## only draws and blocks movement. Tall props draw ABOVE their tile (negative y) and are y-sorted
## by their bottom edge, so Nash walks behind them correctly.
##
## Containers (v0.3): any prop with a "loot" list, and every locker, can be SEARCHED (2 s). After
## that a locker can be hidden in; other containers are done. (State lives in world.state.searched.)
## NOTE: cyan only on the lockdown panel (cyan = lockdown / infected). Brand = white on purple.

const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")
const LsText = preload("res://scripts/games/last_shift/last_shift_text.gd")
const LsFx = preload("res://scripts/games/last_shift/last_shift_fx.gd")
const Icons = preload("res://scripts/games/last_shift/last_shift_icons.gd")
const A = preload("res://scripts/games/last_shift/last_shift_art.gd")

const GREEN := Color("4fbf5a")
const RED_LAMP := Color("d9402f")
const GRASS := Color("3f6a35")
const LEAF := Color("2f5a2a")
const CONCRETE := Color("8f8b84")
const LINE_PAINT := Color(0.92, 0.92, 0.88, 0.85)
## Flat things lying on the floor: drawn under characters.
const FLAT_KINDS := ["ammo", "medkit", "keycard", "snack", "money", "knife", "body", "vent", "corpse",
	"arm", "coolant", "chef_hat"]
## Painted / ground-level surfaces: drawn under everything else.
const GROUND_KINDS := ["parking", "sidewalk", "lawn", "arrow", "rug", "doormat", "blood", "dock_stripes"]
## Picked up by walking over them.
## v0.5: the severed arm, coolant cans and the cook's hat too.
const PICKUP_KINDS := ["ammo", "medkit", "keycard", "snack", "money", "knife", "arm", "coolant", "chef_hat"]
## Used with A (containers are added on top of these, see can_use()).
const USE_KINDS := ["valve", "terminal", "locker", "door", "vending", "chiller", "workbench", "gun_cabinet",
	"vent", "lockdown_panel", "npc_dwayne", "plaque", "elevator", "sealed_door", "cake", "alarm_panel",
	"eotm_wall", "corkboard"]
const BLOOD := Color("6e0a0e")
const CAR_COLORS := {
	"red": Color("8a3a3a"), "blue": Color("3a4a6a"), "white": Color("c9ccd3"), "black": Color("2a2c32"),
	"silver": Color("8d939c"), "green": Color("3d5a3a"), "rust": Color("9c4a1e"), "gold": Color("c9a227"),
}

var id := ""
var kind := ""
var data: Dictionary = {}
var size_px := Vector2.ZERO
var world: Node = null       # the world script (owns the game state)
var hint := false            # shows the little bubble when Nash can use it
## 0..1 while Nash is searching this container (a ring fills above it), -1 otherwise.
var search_progress := -1.0
var _shape: CollisionShape2D = null
var _light: PointLight2D = null

func setup(prop_data: Dictionary, world_node: Node) -> void:
	data = prop_data
	id = prop_data.id
	kind = prop_data.kind
	world = world_node
	var r: Rect2i = prop_data.rect
	position = Vector2(r.position * 32)
	size_px = Vector2(r.size * 32)
	# Dropped items are placed by pixel position (centered) instead of by tile.
	if prop_data.has("pos"):
		position = Vector2(prop_data.pos) - size_px * 0.5
	# Drawn in front of / behind characters by their bottom edge (z = pixel y).
	if kind in GROUND_KINDS:
		z_index = -8 if kind != "blood" else -7
	elif kind == "facade_sign":
		z_index = 1      # on the building front, under everyone walking on the sidewalk
	elif kind in FLAT_KINDS:
		z_index = -5
	else:
		z_index = int(position.y + size_px.y)
	# Solid box for the whole prop (unless the data says "solid": false, e.g. a body on the floor).
	if prop_data.get("solid", true):
		_shape = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size_px
		_shape.shape = rect
		_shape.position = size_px * 0.5
		add_child(_shape)
	if kind == "lamp_post":
		# a warm sodium lamp, lit at dusk (the world turns it on and off)
		_light = PointLight2D.new()
		_light.texture = LsFx.light_texture()
		_light.texture_scale = 1.5
		_light.color = Color(1.0, 0.74, 0.45)
		_light.energy = 0.0
		_light.position = Vector2(size_px.x * 0.5, 4)
		add_child(_light)

## Can this be searched (lockers, and anything with a "loot" list)?
func is_container() -> bool:
	return kind == "locker" or data.has("loot")

func searched() -> bool:
	return world.state.searched.has(id)

## Does A do something here right now?
func can_use() -> bool:
	if kind in USE_KINDS:
		return true
	return is_container() and not searched()

## An open door lets people through: turn its collision off.
func set_open(on: bool) -> void:
	if _shape != null:
		_shape.set_deferred("disabled", on)
	queue_redraw()

## Rectangle in room (world) pixels.
func rect_px() -> Rect2:
	return Rect2(position, size_px)

func set_hint(on: bool) -> void:
	if on != hint:
		hint = on
		queue_redraw()

func refresh() -> void:
	queue_redraw()

func set_lamp(on: bool) -> void:
	if _light != null:
		_light.energy = 1.1 if on else 0.0
		queue_redraw()

func _process(_delta: float) -> void:
	# Pickups glow, the hint bubble bobs, racks blink: they redraw every frame.
	if hint or kind in PICKUP_KINDS or search_progress >= 0.0 or kind in ["server_rack", "cctv", "alarm_panel"]:
		queue_redraw()

func _pulse() -> float:
	return 0.5 + 0.5 * sin(float(world._clock) * 4.0)

func _draw() -> void:
	match kind:
		"valve": _draw_valve()
		"chiller": _draw_chiller()
		"gauge": _draw_gauge()
		"terminal": _draw_terminal()
		"locker": _draw_locker()
		"door": _draw_door()
		"vending": _draw_vending()
		"workbench": _draw_workbench()
		"body": _draw_body()
		"desk": _draw_desk()
		"gun_cabinet": _draw_gun_cabinet()
		"ammo": _draw_ammo()
		"medkit": _draw_medkit()
		"keycard": _draw_keycard()
		"snack", "money", "knife", "arm", "coolant", "chef_hat": _draw_item_pickup()
		"crate": _draw_crate()
		"pillar": _draw_pillar()
		"vent": _draw_vent()
		"lockdown_panel": _draw_lockdown_panel()
		"car": _draw_car()
		"npc_dwayne": _draw_npc_dwayne()
		"plaque": _draw_plaque()
		"elevator": _draw_elevator()
		"bench": _draw_bench()
		"banner": _draw_banner()
		"sealed_door": _draw_sealed_door()
		# outdoors
		"parking": _draw_parking()
		"sidewalk": _draw_sidewalk()
		"lawn": _draw_lawn()
		"arrow": _draw_arrow()
		"bush": _draw_bush()
		"tree": _draw_tree()
		"lamp_post": _draw_lamp_post()
		"monument": _draw_monument()
		"sign_post": _draw_sign_post()
		"bollard": _draw_bollard()
		"hydrant": _draw_hydrant()
		"trash": _draw_trash()
		"park_bench": _draw_park_bench()
		"gate": _draw_gate()
		"planter": _draw_planter()
		# indoors
		"chair": _draw_chair()
		"plant": _draw_plant()
		"water_cooler": _draw_water_cooler()
		"printer": _draw_printer()
		"filing": _draw_filing()
		"sofa": _draw_sofa()
		"coffee_table": _draw_coffee_table()
		"counter": _draw_counter()
		"fridge": _draw_fridge()
		"table": _draw_table()
		"whiteboard": _draw_whiteboard()
		"tv": _draw_tv()
		"cake": _draw_cake()
		"wet_sign": _draw_wet_sign()
		"boxes": _draw_boxes()
		"shelf": _draw_shelf()
		"first_aid": _draw_first_aid()
		"rug": _draw_rug()
		"doormat": _draw_doormat()
		# v0.4
		"corpse": _draw_corpse()
		"blood": _draw_blood()
		"alarm_panel": _draw_alarm_panel()
		"eotm_wall": _draw_eotm_wall()
		"riot_rack": _draw_riot_rack()
		"server_rack": _draw_server_rack()
		"cafe_table": _draw_cafe_table()
		"kitchen": _draw_kitchen()
		"poster": _draw_poster()
		"facade_sign": _draw_facade_sign()
		"cctv": _draw_cctv()
		"dumpster": _draw_dumpster()
		"truck": _draw_truck()
		"pallet": _draw_pallet()
		"tool_cage": _draw_tool_cage()
		"crac": _draw_crac()
		"corkboard": _draw_corkboard()
		"dock_stripes": _draw_dock_stripes()
		"window": _draw_window()
	if search_progress >= 0.0:
		# the search ring: fills up over the 2 seconds
		var c := Vector2(size_px.x * 0.5, -26.0)
		draw_circle(c, 12.0, A.INK)
		draw_circle(c, 10.0, Color(0.1, 0.1, 0.12))
		draw_arc(c, 7.5, -PI * 0.5, -PI * 0.5 + TAU * search_progress, 24, A.AMBER, 4.0)
	elif hint:
		var bob := sin(float(world._clock) * 6.0) * 2.0
		var c := Vector2(size_px.x * 0.5, -22.0 + bob)
		draw_circle(c, 9.5, A.INK)
		draw_circle(c, 7.5, A.AMBER)
		# three dots = "you can do something here" (the A button says what)
		for i in 3:
			draw_circle(c + Vector2(-3.5 + i * 3.5, 0.5), 1.2, A.INK)

# ---------------------------------------------------------------- machines

func _draw_valve() -> void:
	var puzzle: String = data.puzzle
	var idx: int = data.index
	var open: bool = world.state.puzzles[puzzle][idx]
	A.shadow(self, Vector2(16, 29), 13, 4)
	# pipe stub and riser
	A.ink_rect(self, Rect2(1, 17, 30, 9), A.STEEL)
	A.ink_rect(self, Rect2(11, 2, 10, 16), A.STEEL)
	# wheel: spokes lie flat when closed, upright when open
	var hub := Vector2(16, 6)
	A.ink_circle(self, hub, 9.0, A.BLOOD)
	var spoke := Vector2(0, -7) if open else Vector2(7, 0)
	draw_line(hub - spoke, hub + spoke, A.INK, 4.0)
	draw_line(hub - spoke, hub + spoke, A.shade(A.BLOOD, 0.45), 2.0)
	draw_circle(hub, 2.5, A.INK)
	# amber number plate (how much flow this valve passes) and a status lamp
	A.flat_rect(self, Rect2(9, 19, 14, 9), A.AMBER, 1.5)
	A.text(self, Vector2(13, 27), str(LsEngine.puzzle_flow_of(puzzle, idx)), 11, A.INK)
	A.flat_rect(self, Rect2(25, 1, 5, 5), GREEN if open else Color("552222"), 1.2)

func _draw_chiller() -> void:
	var w := size_px.x
	var h := size_px.y
	A.shadow(self, Vector2(w * 0.5, h - 2), w * 0.52, 8)
	# pipes rising from the top, with frost
	A.ink_rect(self, Rect2(18, -22, 14, 26), A.STEEL_HI)
	A.ink_rect(self, Rect2(w - 34, -22, 14, 26), A.STEEL_HI)
	A.ink_rect(self, Rect2(14, -26, 22, 8), A.STEEL)
	A.ink_rect(self, Rect2(w - 38, -26, 22, 8), A.STEEL)
	# main body
	A.ink_rect(self, Rect2(0, -6, w, h + 2), A.STEEL)
	A.ink_rect(self, Rect2(8, 0, w - 16, 16), A.shade(A.STEEL, -0.15), 1.5)
	# vent grille
	for i in 7:
		draw_rect(Rect2(14 + i * 20, 4, 12, 8), A.INK)
		draw_rect(Rect2(15 + i * 20, 5, 10, 2), A.STEEL_HI)
	# panel with the big "4"
	A.ink_rect(self, Rect2(w * 0.5 - 24, 26, 48, 38), A.CONC_D, 1.5)
	A.text(self, Vector2(w * 0.5 - 11, 58), "4", 34, A.WHITE)
	# frost on the top edge
	for i in 14:
		var x := 6.0 + i * (w - 12.0) / 14.0
		var ih := 5.0 + float((i * 7) % 5)
		draw_colored_polygon(PackedVector2Array([Vector2(x, -6), Vector2(x + 7, -6), Vector2(x + 3.5, -6 + ih)]), Color("e8f0f6"))
	# status lamp: red until the flow is right
	var ok: bool = LsEngine.puzzle_status("chiller", world.puzzle_flow("chiller")) == "ok"
	A.flat_rect(self, Rect2(w - 26, 28, 12, 12), GREEN if ok else RED_LAMP, 1.5)

func _draw_gauge() -> void:
	var puzzle: String = data.get("puzzle", "chiller")
	A.ink_rect(self, Rect2(0, 0, size_px.x, 28), A.CONC_D)
	A.flat_rect(self, Rect2(5, 4, size_px.x - 10, 20), Color("14181c"), 1.5)
	var flow: int = world.puzzle_flow(puzzle)
	var target: int = LsEngine.puzzle_target(puzzle)
	var status: String = LsEngine.puzzle_status(puzzle, flow)
	var color := GREEN if status == "ok" else (A.AMBER if status == "low" else RED_LAMP)
	var label := ""
	if puzzle == "chiller":
		label = tr(LsText.UI.gauge_flow) % [flow, target, LsEngine.chiller_temp(flow)]
		if status == "high":
			label = tr(LsText.UI.gauge_high) % [flow, target]
	else:
		label = tr(LsText.UI.gauge_pump) % [flow, target]
	A.text(self, Vector2(10, 20), label, 13, color)
	# one lamp per valve, right under the reading, so the effect shows next to the valves
	var n: int = LsEngine.puzzle_size(puzzle)
	for i in n:
		var on: bool = world.state.puzzles[puzzle][i]
		A.flat_rect(self, Rect2(size_px.x - 12 - (n - i) * 9, 27, 6, 4), GREEN if on else Color("552222"), 1.0)

func _draw_terminal() -> void:
	A.shadow(self, Vector2(16, 30), 13, 4)
	A.ink_rect(self, Rect2(2, 18, 28, 12), Color("8a6a3a"))               # desk
	A.ink_rect(self, Rect2(6, -4, 20, 18), A.CONC_D)                       # monitor
	draw_rect(Rect2(8, -2, 16, 12), Color("2a2410"))
	for i in 4:
		draw_line(Vector2(10, 0 + i * 3), Vector2(22 - (i % 2) * 5, 0 + i * 3), A.AMBER, 1.6)
	A.ink_rect(self, Rect2(12, 14, 8, 5), A.CONC_D, 1.5)                   # stand
	A.flat_rect(self, Rect2(8, 22, 16, 5), A.CONC_M, 1.2)                  # keyboard

func _draw_locker() -> void:
	var opened := searched()
	A.shadow(self, Vector2(16, 31), 13, 4)
	var body := Color("5f7480") if not opened else Color("4a5a64")
	A.ink_rect(self, Rect2(3, -10, 26, 41), body)
	A.ink_rect(self, Rect2(6, -7, 20, 16), A.shade(body, -0.12), 1.5)
	for i in 4:
		draw_rect(Rect2(9, -4 + i * 3, 14, 1.6), A.INK)                    # vent slits
	A.flat_rect(self, Rect2(21, 14, 4, 8), A.STEEL_HI, 1.2)                  # handle
	A.flat_rect(self, Rect2(9, 22, 8, 5), A.AMBER, 1.0)                      # number plate
	if data.get("dent", false):
		# Nash's locker: the one with the dent
		draw_arc(Vector2(14, 10), 5.0, PI * 0.1, PI * 0.9, 8, A.shade(body, -0.35), 2.0)
		draw_arc(Vector2(14, 9), 5.0, PI * 0.1, PI * 0.9, 8, A.shade(body, 0.25), 1.0)
	if opened:
		# searched: the door hangs a little open (a dark gap on the hinge side)
		draw_rect(Rect2(4, -9, 3, 39), Color("15181c"))
	if world.nash.in_locker and world.hide_prop == self:
		# two eyes peeking through the slits
		draw_circle(Vector2(12, -2), 2.2, Color.WHITE)
		draw_circle(Vector2(20, -2), 2.2, Color.WHITE)
		draw_circle(Vector2(12, -2), 1.0, A.INK)
		draw_circle(Vector2(20, -2), 1.0, A.INK)

func _draw_door() -> void:
	if world.state.door_open and id == "door_east":
		# forced open during the scene: a dark doorway
		A.ink_rect(self, Rect2(2, -10, 28, 42), Color("0c0d10"))
		return
	var locked: bool = world.door_locked(data)
	A.shadow(self, Vector2(16, 31), 13, 3)
	match data.get("style", ""):
		"rollup":
			_draw_rollup(locked)
			return
		"fire":
			_draw_fire_door(locked)
			return
	if data.get("glass", false):
		# the building's front entrance: glass double door with the brand mark
		A.ink_rect(self, Rect2(-6, -14, 44, 46), A.STEEL)
		A.ink_rect(self, Rect2(-2, -10, 18, 42), Color("2a3442"), 1.5)
		A.ink_rect(self, Rect2(16, -10, 18, 42), Color("2a3442"), 1.5)
		draw_line(Vector2(0, 24), Vector2(12, -6), Color(1, 1, 1, 0.18), 3.0)
		draw_line(Vector2(18, 24), Vector2(30, -6), Color(1, 1, 1, 0.18), 3.0)
		draw_rect(Rect2(12, 6, 2, 8), A.STEEL_HI)
		draw_rect(Rect2(18, 6, 2, 8), A.STEEL_HI)
		A.flat_rect(self, Rect2(13, -20, 7, 5), RED_LAMP if locked else GREEN, 1.4)
		return
	A.ink_rect(self, Rect2(0, -12, 32, 44), A.STEEL)                          # frame
	A.ink_rect(self, Rect2(4, -8, 24, 40), A.shade(A.STEEL, 0.08), 1.5)       # slab
	draw_rect(Rect2(8, -3, 16, 9), A.INK)                                     # window slit
	draw_rect(Rect2(9, -2, 14, 3), Color("2c3a46"))
	for i in 4:                                                               # hazard stripe low on the slab
		draw_rect(Rect2(5 + i * 6, 24, 3, 6), A.YELLOW)
	A.flat_rect(self, Rect2(13, -17, 7, 6), RED_LAMP if locked else GREEN, 1.4)  # status lamp above
	draw_circle(Vector2(23, 14), 2.2, A.STEEL_HI)                             # handle

func _draw_elevator() -> void:
	var out: bool = world.state.alarm
	A.shadow(self, Vector2(size_px.x * 0.5, 31), size_px.x * 0.45, 3)
	A.ink_rect(self, Rect2(0, -14, size_px.x, 46), A.CONC_M)
	var hw := size_px.x * 0.5 - 4.0
	A.ink_rect(self, Rect2(4, -8, hw, 38), A.STEEL_HI, 1.5)
	A.ink_rect(self, Rect2(size_px.x * 0.5, -8, hw, 38), A.STEEL_HI, 1.5)
	for i in 6:
		draw_line(Vector2(8, -4 + i * 6), Vector2(size_px.x * 0.5 - 4, -4 + i * 6), Color(1, 1, 1, 0.25), 1.0)
	A.flat_rect(self, Rect2(size_px.x * 0.5 - 8, -24, 16, 8), Color("14181c"), 1.5)
	A.text(self, Vector2(size_px.x * 0.5 - 6, -17), "v" if not out else "x", 9, RED_LAMP if out else GREEN)

func _draw_vending() -> void:
	A.shadow(self, Vector2(16, 31), 13, 4)
	A.ink_rect(self, Rect2(2, -12, 28, 44), Color("b03030"))
	A.ink_rect(self, Rect2(5, -8, 18, 24), Color("1a1d22"), 1.5)
	for row in 3:
		for col in 3:
			draw_rect(Rect2(7 + col * 5.5, -6 + row * 7.5, 4, 5), [A.YELLOW, A.FIRE, A.WHITE][(row + col) % 3])
	draw_rect(Rect2(24, -4, 4, 12), A.CONC_D)
	A.flat_rect(self, Rect2(8, 22, 14, 6), A.INK, 1.2)
	A.flat_rect(self, Rect2(23, 10, 6, 4), Color("14181c"), 1.0)            # price display
	A.text(self, Vector2(23.5, 13.5), "$%d" % world.VENDING_PRICE, 5, A.AMBER)

func _draw_workbench() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 30), w * 0.5, 4)
	# pegboard on the wall behind it, with tool outlines (the wrench is gone once Nash takes it)
	A.ink_rect(self, Rect2(6, -22, w - 12, 20), Color("8a7a5a"))
	for i in 3:
		draw_line(Vector2(14 + i * 26, -18), Vector2(14 + i * 26, -6), A.STEEL_HI, 3.0)
	A.ink_rect(self, Rect2(2, 2, w - 4, 10), Color("7a5a3a"))
	A.ink_rect(self, Rect2(4, 12, w - 8, 18), Color("5a4430"))
	draw_line(Vector2(w * 0.5 - 8, 21), Vector2(w * 0.5 + 8, 21), A.INK, 2.0)
	if not world.nash.has_wrench:
		draw_line(Vector2(w * 0.5 - 18, 6), Vector2(w * 0.5 + 16, 4), A.INK, 7.0)
		draw_line(Vector2(w * 0.5 - 18, 6), Vector2(w * 0.5 + 16, 4), A.BLOOD, 4.5)
		draw_circle(Vector2(w * 0.5 + 18, 4), 5.0, A.STEEL_HI)

func _draw_body() -> void:
	# The grabbed coworker, lying still in a pool of blood.
	_pool(Vector2(14, 18), 18.0)
	A.shadow(self, Vector2(16, 20), 16, 6)
	A.ink_rect(self, Rect2(2, 9, 26, 14), Color("4f8f5a"))
	A.ink_rect(self, Rect2(22, 6, 9, 9), Color("d2a07a"))
	A.ink_rect(self, Rect2(-4, 12, 8, 8), Color("2a2a32"))

func _draw_desk() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 31), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, 6, w, 24), Color("9a8a6e"))
	A.ink_rect(self, Rect2(0, 22, w, 8), Color("6a5a44"))
	# drawers on the right (pulled out once searched)
	var open := is_container() and searched()
	A.flat_rect(self, Rect2(w - 16, 22 + (3 if open else 0), 12, 6), Color("7a6a50"), 1.0)
	draw_rect(Rect2(w - 12, 24 + (3 if open else 0), 4, 1.5), A.STEEL_HI)
	# monitor, keyboard, papers, mug
	A.ink_rect(self, Rect2(w * 0.5 - 9, -10, 18, 14), A.CONC_D, 1.5)
	draw_rect(Rect2(w * 0.5 - 7, -8, 14, 9), Color("c9d4e0") if id != "reception" else Color("e8dcc0"))
	A.flat_rect(self, Rect2(w * 0.5 - 8, 9, 16, 5), A.CONC_M, 1.2)
	A.flat_rect(self, Rect2(6, 10, 9, 7), A.WHITE, 1.0)
	A.flat_rect(self, Rect2(w - 14, 10, 6, 6), Color("e8e8f0"), 1.0)
	if w >= 96:
		# a little desk plant and a photo frame on the wide desks
		A.ink_circle(self, Vector2(20, 6), 4.0, A.shade(GRASS, 0.15), 1.2)
		A.flat_rect(self, Rect2(w - 30, 4, 7, 8), Color("6a5a44"), 1.0)
	# office chair tucked in under the desk
	draw_circle(Vector2(w * 0.5, 36), 8.0, A.INK)
	draw_circle(Vector2(w * 0.5, 36), 6.5, Color("3a3d44"))

func _draw_gun_cabinet() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 31), w * 0.45, 4)
	A.ink_rect(self, Rect2(0, -14, w, 46), Color("40444c"))
	A.ink_rect(self, Rect2(6, -8, w - 12, 30), Color("14181c"), 1.5)
	draw_rect(Rect2(8, -6, w - 16, 26), Color(0.7, 0.8, 0.9, 0.12))
	if not world.nash.has_pistol:
		draw_line(Vector2(w * 0.5 - 12, 4), Vector2(w * 0.5 + 10, 4), A.INK, 7.0)
		draw_line(Vector2(w * 0.5 - 12, 4), Vector2(w * 0.5 + 10, 4), Color("2b2d33"), 5.0)
		draw_line(Vector2(w * 0.5 - 8, 5), Vector2(w * 0.5 - 8, 14), A.INK, 7.0)
		draw_line(Vector2(w * 0.5 - 8, 5), Vector2(w * 0.5 - 8, 14), Color("2b2d33"), 5.0)
	A.flat_rect(self, Rect2(w * 0.5 - 4, 24, 8, 5), GREEN if world.nash.has_pistol else RED_LAMP, 1.2)

# ---------------------------------------------------------------- pickups (amber glow)

func _glow() -> void:
	var p := _pulse()
	draw_circle(Vector2(16, 18), 14.0 + p * 3.0, Color(A.AMBER.r, A.AMBER.g, A.AMBER.b, 0.20 + 0.12 * p))
	A.shadow(self, Vector2(16, 26), 10, 3, 0.3)

func _draw_ammo() -> void:
	_glow()
	A.ink_rect(self, Rect2(5, 12, 22, 14), Color("6b7a3a"))
	for i in 4:
		A.flat_rect(self, Rect2(8 + i * 5, 6, 3.5, 8), A.YELLOW, 1.0)

func _draw_medkit() -> void:
	_glow()
	A.ink_rect(self, Rect2(5, 9, 22, 17), A.WHITE)
	draw_rect(Rect2(14, 12, 4, 11), A.BLOOD)
	draw_rect(Rect2(10, 15.5, 12, 4), A.BLOOD)

func _draw_keycard() -> void:
	_glow()
	A.ink_rect(self, Rect2(6, 10, 20, 14), A.WHITE)
	draw_rect(Rect2(8, 13, 16, 3), A.PURPLE)
	draw_rect(Rect2(8, 18, 6, 3), A.CONC_M)

## Snacks, money, the knife (and v0.5: the arm, coolant cans, the cook's hat) on the floor use
## their bag icons.
func _draw_item_pickup() -> void:
	_glow()
	Icons.draw(self, kind, Vector2(16, 17), 22.0)

# ---------------------------------------------------------------- big dressing

func _draw_crate() -> void:
	A.shadow(self, Vector2(16, 30), 14, 4)
	A.ink_rect(self, Rect2(1, -4, 30, 34), Color("8a6a3a"))
	draw_line(Vector2(3, -2), Vector2(29, 28), Color("5a4424"), 3.0)
	draw_line(Vector2(29, -2), Vector2(3, 28), Color("5a4424"), 3.0)
	for y in [0, 24]:
		draw_rect(Rect2(1, y, 30, 4), Color("6a5230"))

func _draw_pillar() -> void:
	var w := size_px.x
	var h := size_px.y
	A.shadow(self, Vector2(w * 0.5, h - 2), w * 0.55, 6)
	# a concrete column: lit cap on top, shaded front, hazard band at the base
	A.ink_rect(self, Rect2(2, -22, w - 4, h + 20), A.CONC_M)
	A.ink_rect(self, Rect2(2, -22, w - 4, 12), A.CONC_L)
	draw_rect(Rect2(6, -8, 4, h + 4), A.shade(A.CONC_M, 0.18))
	draw_rect(Rect2(w - 12, -8, 8, h + 4), A.shade(A.CONC_M, -0.18))
	for i in 6:
		draw_rect(Rect2(2 + i * (w - 4) / 6.0, h - 10, (w - 4) / 12.0, 8), A.YELLOW)
	draw_rect(Rect2(2, h - 10, w - 4, 2), A.INK)

func _draw_vent() -> void:
	var puzzle: String = data.puzzle
	var idx: int = data.index
	var open: bool = world.state.puzzles[puzzle][idx]
	A.ink_rect(self, Rect2(2, 2, 28, 28), A.CONC_D)
	for i in 4:
		var y := 7.0 + i * 6.0
		if open:
			draw_line(Vector2(6, y + 3), Vector2(26, y - 2), A.WHITE, 3.0)
		else:
			draw_line(Vector2(6, y), Vector2(26, y), A.CONC_M, 3.0)
	A.text(self, Vector2(11, 30), str(LsEngine.puzzle_flow_of(puzzle, idx)), 12, A.AMBER)
	A.flat_rect(self, Rect2(25, 3, 4, 4), GREEN if open else Color("552222"), 1.0)

## The lockdown panel: the one place cyan is allowed on a prop (cyan = lockdown / infected only).
func _draw_lockdown_panel() -> void:
	var flow: int = world.puzzle_flow("vents")
	var status: String = LsEngine.puzzle_status("vents", flow)
	var released: bool = world.state.solved.vents
	var frame := GREEN if released else A.CYAN_CORE
	A.ink_rect(self, Rect2(0, -6, size_px.x, 34), A.SHADOW_DEEP)
	draw_rect(Rect2(3, -3, size_px.x - 6, 28), frame, false, 2.5)
	draw_rect(Rect2(-2, -9, size_px.x + 4, 2), Color(frame.r, frame.g, frame.b, 0.5))   # glow line
	var color := GREEN if status == "ok" else (A.AMBER if status == "low" else RED_LAMP)
	if released:
		A.text(self, Vector2(10, 16), tr(LsText.UI.released).to_upper(), 15, GREEN)
	else:
		A.text(self, Vector2(10, 16), tr(LsText.UI.panel_air) % [flow, LsEngine.puzzle_target("vents")], 15, color)
	# one lamp per vent, right above it
	for i in LsEngine.puzzle_size("vents"):
		var on: bool = world.state.puzzles.vents[i]
		A.flat_rect(self, Rect2(12 + i * 64, 20, 8, 5), GREEN if on else Color("552222"), 1.0)

# ---------------------------------------------------------------- cars (top-down, v0.3)

## Maps a y in "nose up" car coordinates to this car (flipped when the nose points down).
func _cy(y: float) -> float:
	return y if data.get("nose", "up") == "up" else size_px.y - y

func _crect(x: float, y: float, w: float, h: float) -> Rect2:
	if data.get("nose", "up") == "up":
		return Rect2(x, y, w, h)
	return Rect2(x, size_px.y - y - h, w, h)

func _cpoly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x, _cy(p.y)))
	return out

## A parked car seen from above. data: "model" sedan | hatch | pickup | van | sport,
## "color" (CAR_COLORS key), "nose" up | down. Rect is 2 x 3 tiles.
func _draw_car() -> void:
	var w := size_px.x
	var h := size_px.y
	var model: String = data.get("model", "sedan")
	var col: Color = CAR_COLORS.get(data.get("color", "blue"), CAR_COLORS.blue)
	var glass := Color("2a3340")
	var x0 := 7.0
	var x1 := w - 7.0
	var front := 5.0
	var back := h - 4.0
	A.shadow(self, Vector2(w * 0.5 + 3, h * 0.5 + 5), w * 0.46, h * 0.47, 0.4)
	# tyres peeking out at the four corners
	for ty in [front + 12.0, back - 26.0]:
		draw_rect(_crect(x0 - 3, ty, 6, 15), A.INK)
		draw_rect(_crect(x1 - 3, ty, 6, 15), A.INK)
	# body: a long box with cut corners
	var c := 7.0
	var body := _cpoly([Vector2(x0 + c, front), Vector2(x1 - c, front), Vector2(x1, front + c),
		Vector2(x1, back - c), Vector2(x1 - c, back), Vector2(x0 + c, back), Vector2(x0, back - c), Vector2(x0, front + c)])
	A.ink_poly(self, body, col, 2.5)
	# side shade on the right, lit edge on the left (light from the top-left)
	draw_rect(_crect(x1 - 5, front + 8, 4, back - front - 16), A.shade(col, -0.18))
	draw_rect(_crect(x0 + 1, front + 8, 2, back - front - 16), A.shade(col, 0.25))
	# mirrors
	A.flat_rect(self, _crect(x0 - 4, front + 26, 4, 5), A.shade(col, -0.1), 1.2)
	A.flat_rect(self, _crect(x1, front + 26, 4, 5), A.shade(col, -0.1), 1.2)
	# lights
	draw_rect(_crect(x0 + 4, front + 1, 9, 3), Color("f4e8b0"))
	draw_rect(_crect(x1 - 13, front + 1, 9, 3), Color("f4e8b0"))
	draw_rect(_crect(x0 + 4, back - 4, 8, 3), Color("c0282c"))
	draw_rect(_crect(x1 - 12, back - 4, 8, 3), Color("c0282c"))
	match model:
		"pickup":
			_car_cabin(col, glass, x0, x1, front + 22, front + 32, front + 46)
			# open bed with ribs and a toolbox
			A.ink_rect(self, _crect(x0 + 4, front + 50, x1 - x0 - 8, back - front - 54), A.shade(col, -0.35), 1.5)
			for i in 4:
				draw_rect(_crect(x0 + 6, front + 56 + i * 8, x1 - x0 - 12, 1.5), A.shade(col, -0.5))
			A.ink_rect(self, _crect(x0 + 5, front + 51, x1 - x0 - 10, 7), Color("b8402a"), 1.5)
		"van":
			# short hood, then one long roof with ribs
			A.ink_poly(self, _cpoly([Vector2(x0 + 6, front + 12), Vector2(x1 - 6, front + 12), Vector2(x1 - 3, front + 22),
				Vector2(x0 + 3, front + 22)]), glass, 1.5)
			A.ink_rect(self, _crect(x0 + 3, front + 22, x1 - x0 - 6, back - front - 26), A.shade(col, 0.08), 1.5)
			for i in 5:
				draw_rect(_crect(x0 + 6, front + 30 + i * 11, x1 - x0 - 12, 1.5), A.shade(col, -0.12))
		"sport":
			_car_cabin(col, glass, x0, x1, front + 32, front + 42, front + 62)
			# racing stripes and a spoiler
			draw_rect(_crect(w * 0.5 - 6, front, 4, back - front), Color(1, 1, 1, 0.75))
			draw_rect(_crect(w * 0.5 + 2, front, 4, back - front), Color(1, 1, 1, 0.75))
			A.ink_rect(self, _crect(x0 + 1, back - 10, x1 - x0 - 2, 4), A.shade(col, -0.3), 1.5)
		"hatch":
			_car_cabin(col, glass, x0, x1, front + 22, front + 32, front + 66)
			A.ink_poly(self, _cpoly([Vector2(x0 + 7, front + 66), Vector2(x1 - 7, front + 66), Vector2(x1 - 4, front + 76),
				Vector2(x0 + 4, front + 76)]), glass, 1.5)
		_:
			_car_cabin(col, glass, x0, x1, front + 26, front + 36, front + 60)
			A.ink_poly(self, _cpoly([Vector2(x0 + 7, front + 60), Vector2(x1 - 7, front + 60), Vector2(x1 - 4, front + 70),
				Vector2(x0 + 4, front + 70)]), glass, 1.5)
			draw_line(Vector2(x0 + 8, _cy(back - 12)), Vector2(x1 - 8, _cy(back - 12)), A.shade(col, -0.25), 1.2)
	# hood crease
	draw_line(Vector2(w * 0.5, _cy(front + 6)), Vector2(w * 0.5, _cy(front + 18)), A.shade(col, -0.2), 1.2)

## Windshield (wind0..wind1) and roof (wind1..roof_end) of a car.
func _car_cabin(col: Color, glass: Color, x0: float, x1: float, wind0: float, wind1: float, roof_end: float) -> void:
	A.ink_poly(self, _cpoly([Vector2(x0 + 4, wind0), Vector2(x1 - 4, wind0), Vector2(x1 - 7, wind1),
		Vector2(x0 + 7, wind1)]), glass, 1.5)
	draw_line(Vector2(x0 + 9, _cy(wind0 + 2)), Vector2(x0 + 16, _cy(wind1 - 2)), Color(1, 1, 1, 0.3), 2.0)
	A.ink_rect(self, _crect(x0 + 7, wind1, x1 - x0 - 14, roof_end - wind1), A.shade(col, 0.1), 1.5)
	draw_rect(_crect(x0 + 9, wind1 + 2, x1 - x0 - 18, 2), A.shade(col, 0.3))
	# side windows along the roof
	draw_rect(_crect(x0 + 3, wind1 + 2, 3, roof_end - wind1 - 4), glass)
	draw_rect(_crect(x1 - 6, wind1 + 2, 3, roof_end - wind1 - 4), glass)

func _draw_npc_dwayne() -> void:
	# Dwayne at the front desk (calm, before the alarms): navy uniform, a friendly face.
	A.person(self, {"facing": Vector2.DOWN, "t": float(world._clock), "body": Color("2f3f6a"),
		"band": Color(0, 0, 0, 0), "pouches": false, "stubble": false, "hair": Color("6a6a70"),
		"skin": Color("d8a07a"), "badge": true})

func _draw_plaque() -> void:
	A.ink_rect(self, Rect2(4, -2, 24, 22), Color("c9a227"))
	A.ink_rect(self, Rect2(8, 2, 16, 4), Color("6a5410"), 1.0)
	A.ink_rect(self, Rect2(8, 9, 12, 3), Color("6a5410"), 1.0)
	A.ink_rect(self, Rect2(8, 14, 9, 3), Color("6a5410"), 1.0)

func _draw_bench() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 30), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, 8, w, 10), Color("8a6a3a"))
	A.ink_rect(self, Rect2(3, 18, 5, 12), Color("5a4430"), 1.5)
	A.ink_rect(self, Rect2(w - 8, 18, 5, 12), Color("5a4430"), 1.5)

func _draw_banner() -> void:
	var w := size_px.x
	A.ink_rect(self, Rect2(0, 2, w, 22), A.PURPLE)
	A.text(self, Vector2(12, 19), tr(String(data.get("text", ""))), 14, A.WHITE)
	# streamers and balloons
	for x in [6.0, w * 0.5, w - 8.0]:
		draw_line(Vector2(x, 24), Vector2(x + 3, 34), A.YELLOW, 2.0)
		A.ink_circle(self, Vector2(x + 3, 38), 5.0, A.PURPLE if x < w * 0.5 else A.FIRE, 1.5)

func _draw_sealed_door() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 31), w * 0.5, 3)
	A.ink_rect(self, Rect2(0, -14, w, 46), A.CONC_D)
	A.ink_rect(self, Rect2(5, -9, w - 10, 38), A.STEEL, 1.5)
	for i in 4:
		draw_circle(Vector2(10 + i * (w - 20) / 3.0, -2), 2.5, A.INK)
		draw_circle(Vector2(10 + i * (w - 20) / 3.0, 22), 2.5, A.INK)
	for i in 5:
		draw_rect(Rect2(8 + i * 11, 26, 6, 3), A.YELLOW)
	A.flat_rect(self, Rect2(w * 0.5 - 22, 5, 44, 12), A.WHITE, 1.5)
	A.text(self, Vector2(w * 0.5 - 18, 15), tr(LsText.UI.hall_c), 11, A.INK)

# ---------------------------------------------------------------- outdoors (v0.3)

## Painted parking spots: white lines every `spot` tiles, concrete wheel stops at the nose end,
## and optional words painted in one spot ("label" = a key of LsText.SIGNS, in "label_spot").
func _draw_parking() -> void:
	var spot := float(data.get("spot", 2)) * 32.0
	var n := int(size_px.x / spot)
	var nose_up: bool = data.get("nose", "up") == "up"
	for i in n + 1:
		var x := i * spot
		draw_rect(Rect2(x - 1.5, 2, 3, size_px.y - 4), LINE_PAINT)
	for i in n:
		var x := i * spot
		var stop_y := 6.0 if nose_up else size_px.y - 12.0
		A.flat_rect(self, Rect2(x + 10, stop_y, spot - 20, 5), A.CONC_L, 1.2)
	if data.has("label"):
		var i := int(data.get("label_spot", 0))
		var tx := i * spot + 6
		var lines: PackedStringArray = tr(String(LsText.SIGNS.get(data.label, ""))).strip_edges().to_upper().split("\n")
		for j in lines.size():
			A.text(self, Vector2(tx, size_px.y * 0.5 + (j - lines.size() * 0.5 + 0.8) * 9), lines[j], 7,
				Color(A.YELLOW.r, A.YELLOW.g, A.YELLOW.b, 0.9))

func _draw_sidewalk() -> void:
	draw_rect(Rect2(Vector2.ZERO, size_px), CONCRETE)
	for x in range(0, int(size_px.x), 32):
		draw_rect(Rect2(x, 0, 1, size_px.y), A.shade(CONCRETE, -0.15))
	for y in range(0, int(size_px.y), 32):
		draw_rect(Rect2(0, y, size_px.x, 1), A.shade(CONCRETE, -0.15))
	for i in int(size_px.x / 9):
		var x := fmod(i * 37.0, size_px.x)
		var y := fmod(i * 23.0, size_px.y - 6)
		draw_rect(Rect2(x, y, 2, 1), A.shade(CONCRETE, -0.08 if i % 2 == 0 else 0.08))
	# curb at the edge of the road
	draw_rect(Rect2(0, size_px.y - 5, size_px.x, 5), A.CONC_L)
	draw_rect(Rect2(0, size_px.y - 1.5, size_px.x, 1.5), A.INK)

## Grass (lawns, the median strip) with a concrete curb around it.
func _draw_lawn() -> void:
	draw_rect(Rect2(Vector2.ZERO, size_px), A.CONC_L)
	var g := Rect2(Vector2(3, 3), size_px - Vector2(6, 6))
	draw_rect(g, GRASS)
	for i in int(g.size.x * g.size.y / 70.0):
		var x := g.position.x + fmod(i * 13.7, g.size.x - 2)
		var y := g.position.y + fmod(i * 7.3 + (i % 5) * 3.1, g.size.y - 3)
		draw_line(Vector2(x, y + 3), Vector2(x + 1, y), A.shade(GRASS, 0.2 if i % 3 == 0 else -0.15), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size_px), A.INK, false, 1.5)

## An arrow painted on the asphalt ("dir": left | right | up | down).
func _draw_arrow() -> void:
	var d: Vector2 = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}[data.get("dir", "left")]
	var c := size_px * 0.5
	var n := Vector2(-d.y, d.x)
	draw_line(c - d * 18.0, c + d * 6.0, LINE_PAINT, 5.0)
	draw_colored_polygon(PackedVector2Array([c + d * 18.0, c + d * 4.0 + n * 9.0, c + d * 4.0 - n * 9.0]), LINE_PAINT)

func _draw_bush() -> void:
	var c := size_px * 0.5 + Vector2(0, 2)
	A.shadow(self, c + Vector2(2, 10), 15, 5)
	for p in [Vector2(-7, 2), Vector2(7, 2), Vector2(0, -6), Vector2(-4, -2), Vector2(5, -3)]:
		A.ink_circle(self, c + p, 9.0, LEAF, 2.0)
	for p in [Vector2(-7, 2), Vector2(7, 2), Vector2(0, -6), Vector2(-4, -2), Vector2(5, -3)]:
		draw_circle(c + p + Vector2(-1, -1), 7.0, A.shade(LEAF, 0.12))
	for i in 6:
		draw_circle(c + Vector2(-8 + i * 3.2, -6 + (i % 3) * 4), 1.6, A.shade(LEAF, 0.35))

## A tree: trunk on its tile, a big round canopy above (Nash walks behind it).
func _draw_tree() -> void:
	var c := Vector2(size_px.x * 0.5, size_px.y - 6)
	A.shadow(self, c + Vector2(6, 0), 26, 9, 0.35)
	A.ink_rect(self, Rect2(c.x - 4, c.y - 22, 8, 22), Color("5a3a22"))
	var top := c + Vector2(0, -44)
	for p in [Vector2(-14, 6), Vector2(14, 6), Vector2(0, -10), Vector2(-10, -6), Vector2(10, -6), Vector2(0, 8)]:
		A.ink_circle(self, top + p, 15.0, LEAF, 2.2)
	for p in [Vector2(-14, 6), Vector2(14, 6), Vector2(0, -10), Vector2(-10, -6), Vector2(10, -6)]:
		draw_circle(top + p + Vector2(-2, -2), 11.0, A.shade(LEAF, 0.12))
	for i in 10:
		draw_circle(top + Vector2(-16 + i * 3.5, -12 + (i % 4) * 6), 2.0, A.shade(LEAF, 0.35))

func _draw_lamp_post() -> void:
	var cx := size_px.x * 0.5
	A.shadow(self, Vector2(cx, 28), 7, 3)
	A.ink_rect(self, Rect2(cx - 5, 22, 10, 8), A.CONC_D)                    # base
	A.ink_rect(self, Rect2(cx - 2, -64, 4, 88), Color("4a4e56"), 1.5)      # pole
	A.ink_rect(self, Rect2(cx - 2, -66, 16, 4), Color("4a4e56"), 1.5)      # arm
	var lit: bool = _light != null and _light.energy > 0.0
	A.ink_rect(self, Rect2(cx + 8, -64, 10, 5), Color("f4e8b0") if lit else A.CONC_L, 1.5)
	if lit:
		draw_circle(Vector2(cx + 13, -58), 8.0, Color(1.0, 0.8, 0.5, 0.25))

## The company's monument sign by the entrance: stone base, purple panel, white logo + name.
## Branding is fine (spec v0.4): white on Ascend purple, never cyan, never highlighted.
func _draw_monument() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 30), w * 0.52, 6)
	A.ink_rect(self, Rect2(0, 16, w, 14), Color("7d796f"))                 # stone base
	A.ink_rect(self, Rect2(6, -22, w - 12, 40), A.PURPLE)
	draw_rect(Rect2(6, -22, w - 12, 3), A.shade(A.PURPLE, 0.3))
	# chevron logo
	var lc := Vector2(22, -2)
	for i in 6:
		draw_rect(Rect2(lc.x - 1 - i * 1.4, lc.y - 7 + i * 2.4, 2.4, 2.4), A.WHITE)
		draw_rect(Rect2(lc.x - 1 + i * 1.4, lc.y - 7 + i * 2.4, 2.4, 2.4), A.WHITE)
	draw_rect(Rect2(lc.x - 4, lc.y + 4, 8, 1.6), A.WHITE)
	A.text(self, Vector2(36, 2), "ASCEND AI", 13, A.WHITE)
	# flowers along the base
	for i in int(w / 10):
		draw_circle(Vector2(5 + i * 10, 15), 2.2, [A.YELLOW, A.WHITE, A.FIRE][i % 3])

## A post with a sign plate. data "sign" (a key of LsText.SIGNS), "color" plate color name.
func _draw_sign_post() -> void:
	var cx := size_px.x * 0.5
	A.shadow(self, Vector2(cx, 29), 6, 2.5)
	A.ink_rect(self, Rect2(cx - 1.5, -18, 3, 46), Color("6b6e75"), 1.2)
	var plate: Color = {"blue": Color("2f4f8a"), "red": Color("a8282c"), "white": A.WHITE,
		"yellow": A.YELLOW}.get(data.get("color", "white"), A.WHITE)
	var ink := A.INK if plate == A.WHITE or plate == A.YELLOW else A.WHITE
	var lines: PackedStringArray = tr(String(LsText.SIGNS.get(data.get("sign", ""), ""))).strip_edges().to_upper().split("\n")
	var pw := 40.0
	var ph := 6.0 + lines.size() * 7.0
	A.ink_rect(self, Rect2(cx - pw * 0.5, -22 - ph, pw, ph), plate, 1.5)
	for j in lines.size():
		var tw := ThemeDB.fallback_font.get_string_size(lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		A.text(self, Vector2(cx - tw * 0.5, -22 - ph + 9 + j * 7), lines[j], 6, ink)

func _draw_bollard() -> void:
	var c := Vector2(size_px.x * 0.5, 22)
	A.shadow(self, c + Vector2(0, 6), 6, 2.5)
	A.ink_rect(self, Rect2(c.x - 4, c.y - 16, 8, 20), A.YELLOW, 1.5)
	draw_rect(Rect2(c.x - 4, c.y - 10, 8, 3), A.INK)
	A.ink_circle(self, Vector2(c.x, c.y - 16), 4.0, A.YELLOW, 1.5)

func _draw_hydrant() -> void:
	var c := Vector2(16, 22)
	A.shadow(self, c + Vector2(0, 6), 7, 3)
	A.ink_rect(self, Rect2(c.x - 5, c.y - 14, 10, 18), Color("c0282c"), 1.5)
	A.ink_rect(self, Rect2(c.x - 9, c.y - 9, 18, 4), Color("a01c20"), 1.5)
	A.ink_circle(self, Vector2(c.x, c.y - 15), 5.0, Color("c0282c"), 1.5)

func _draw_trash() -> void:
	A.shadow(self, Vector2(16, 29), 10, 3)
	A.ink_rect(self, Rect2(7, -2, 18, 30), Color("3d5a3a"))
	for i in 3:
		draw_rect(Rect2(10 + i * 5, 2, 2, 22), A.shade(Color("3d5a3a"), -0.2))
	A.ink_rect(self, Rect2(5, -6, 22, 5), Color("2f472d"), 1.5)

func _draw_park_bench() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 29), w * 0.5, 4)
	A.ink_rect(self, Rect2(2, -6, w - 4, 7), Color("8a6a3a"), 1.5)          # backrest
	A.ink_rect(self, Rect2(2, 6, w - 4, 12), Color("9a7a4a"), 1.5)          # seat
	for x in [6.0, w - 10.0]:
		A.ink_rect(self, Rect2(x, 18, 4, 10), Color("2a2c32"), 1.2)

func _draw_planter() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 30), w * 0.5, 4)
	A.ink_rect(self, Rect2(1, 8, w - 2, 22), A.CONC_L)
	draw_rect(Rect2(4, 8, w - 8, 6), Color("3a2e22"))
	for i in int(w / 8):
		A.ink_circle(self, Vector2(6 + i * 8, 6 - (i % 2) * 3), 5.0, LEAF, 1.2)
		draw_circle(Vector2(6 + i * 8, 4 - (i % 2) * 3), 1.8, [A.YELLOW, A.FIRE, A.WHITE][i % 3])

## The parking lot's exit: a little booth and a striped barrier arm across the gap.
func _draw_gate() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 30), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, -22, 30, 52), A.CONC_L)                      # booth
	A.ink_rect(self, Rect2(4, -16, 22, 14), Color("2a3442"), 1.5)           # window
	A.ink_rect(self, Rect2(-2, -28, 34, 7), Color("4a4e56"), 1.5)           # roof
	A.ink_rect(self, Rect2(30, 6, w - 32, 6), A.WHITE, 1.5)                 # arm
	for i in int((w - 32) / 16):
		draw_rect(Rect2(34 + i * 16, 7, 8, 4), A.BLOOD)

# ---------------------------------------------------------------- indoors (v0.3)

func _draw_chair() -> void:
	var c := Vector2(16, 18)
	A.shadow(self, c + Vector2(0, 10), 10, 3)
	for a in 5:
		var d := Vector2.RIGHT.rotated(a * TAU / 5.0) * 9.0
		draw_line(c + Vector2(0, 8), c + Vector2(0, 8) + Vector2(d.x, d.y * 0.4), A.INK, 2.5)
	A.ink_circle(self, c, 8.5, Color("3a3d44"), 2.0)
	A.ink_rect(self, Rect2(c.x - 9, c.y - 16, 18, 8), Color("2e3138"), 1.5)  # backrest

func _draw_plant() -> void:
	A.shadow(self, Vector2(16, 29), 10, 3)
	A.ink_rect(self, Rect2(8, 14, 16, 15), Color("b0602a"), 1.5)           # pot
	draw_rect(Rect2(8, 14, 16, 3), A.shade(Color("b0602a"), 0.25))
	for i in 7:
		var a := -PI * 0.5 + (i - 3) * 0.42
		var tip := Vector2(16, 14) + Vector2(cos(a), sin(a)) * (18.0 + (i % 2) * 6.0)
		draw_line(Vector2(16, 14), tip, A.INK, 5.0)
		draw_line(Vector2(16, 14), tip, A.shade(LEAF, 0.2 if i % 2 == 0 else 0.0), 3.0)

func _draw_water_cooler() -> void:
	A.shadow(self, Vector2(16, 30), 10, 3)
	A.ink_rect(self, Rect2(8, 4, 16, 26), A.WHITE)
	A.ink_circle(self, Vector2(16, -4), 8.0, Color(0.55, 0.7, 0.9, 0.85), 1.5)
	draw_rect(Rect2(12, 10, 3, 3), A.BLOOD)
	draw_rect(Rect2(17, 10, 3, 3), Color("2f4f8a"))

func _draw_printer() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 30), w * 0.48, 4)
	A.ink_rect(self, Rect2(2, 4, w - 4, 26), A.CONC_L)
	A.ink_rect(self, Rect2(6, -4, w - 12, 10), A.shade(A.CONC_L, 0.15), 1.5)
	A.flat_rect(self, Rect2(w - 16, 8, 10, 6), Color("14181c"), 1.0)
	draw_rect(Rect2(w - 14, 10, 3, 2), GREEN)
	A.flat_rect(self, Rect2(10, 16, w - 26, 4), A.WHITE, 1.0)               # paper tray

func _draw_filing() -> void:
	var opened := searched()
	A.shadow(self, Vector2(16, 30), 12, 3)
	A.ink_rect(self, Rect2(4, -8, 24, 38), Color("7a8088"))
	for i in 3:
		var y := -4.0 + i * 11.0 + (3.0 if opened and i == 1 else 0.0)
		A.flat_rect(self, Rect2(6, y, 20, 9), A.shade(Color("7a8088"), 0.1), 1.0)
		draw_rect(Rect2(13, y + 3, 6, 2), A.STEEL_HI)

func _draw_sofa() -> void:
	var w := size_px.x
	var col := Color("6a4a3a")
	A.shadow(self, Vector2(w * 0.5, 30), w * 0.5, 5)
	A.ink_rect(self, Rect2(0, -6, w, 14), A.shade(col, -0.1))              # back
	A.ink_rect(self, Rect2(0, 6, w, 22), col)
	for i in int(w / 32):
		A.flat_rect(self, Rect2(4 + i * 32, 9, 26, 14), A.shade(col, 0.12), 1.0)
	A.ink_rect(self, Rect2(-2, 0, 6, 28), A.shade(col, -0.05), 1.5)         # arms
	A.ink_rect(self, Rect2(w - 4, 0, 6, 28), A.shade(col, -0.05), 1.5)

func _draw_coffee_table() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 26), w * 0.45, 4)
	A.ink_rect(self, Rect2(2, 8, w - 4, 14), Color("5a4430"))
	A.flat_rect(self, Rect2(10, 10, 14, 8), A.WHITE, 1.0)                   # magazines
	A.ink_circle(self, Vector2(w - 14, 14), 3.5, A.WHITE, 1.2)              # mug

## Kitchen counter: sink, microwave, drawers (searchable when it has loot).
func _draw_counter() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 31), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, 2, w, 28), Color("c9ccd3"))
	A.ink_rect(self, Rect2(0, 14, w, 16), Color("8a6a3a"))
	var opened := is_container() and searched()
	for i in int(w / 32):
		A.flat_rect(self, Rect2(4 + i * 32, 16 + (3 if opened and i == 0 else 0), 24, 6), A.shade(Color("8a6a3a"), 0.12), 1.0)
	A.flat_rect(self, Rect2(8, 4, 20, 9), A.STEEL, 1.2)                     # sink
	draw_rect(Rect2(16, 0, 3, 5), A.STEEL_HI)
	if w >= 96:
		A.ink_rect(self, Rect2(w - 34, -10, 28, 16), A.CONC_D, 1.5)         # microwave
		draw_rect(Rect2(w - 31, -7, 16, 10), Color("1a1d22"))
		draw_rect(Rect2(w - 12, -6, 3, 3), GREEN)

func _draw_fridge() -> void:
	A.shadow(self, Vector2(16, 31), 13, 4)
	A.ink_rect(self, Rect2(3, -16, 26, 47), A.WHITE)
	draw_line(Vector2(3, 0), Vector2(29, 0), A.INK, 2.0)
	A.flat_rect(self, Rect2(23, -10, 3, 8), A.STEEL, 1.0)
	A.flat_rect(self, Rect2(23, 4, 3, 12), A.STEEL, 1.0)
	A.flat_rect(self, Rect2(8, -12, 6, 5), A.YELLOW, 1.0)                    # sticky note
	if is_container() and searched():
		draw_rect(Rect2(4, 1, 3, 29), Color("d8dce4"))

func _draw_table() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 28), w * 0.48, 5)
	A.ink_rect(self, Rect2(2, 4, w - 4, 20), Color("a08a6a"))
	draw_rect(Rect2(2, 4, w - 4, 3), A.shade(Color("a08a6a"), 0.2))
	A.ink_circle(self, Vector2(12, 12), 3.5, A.WHITE, 1.2)
	A.ink_circle(self, Vector2(w - 14, 15), 3.5, Color("c9a227"), 1.2)

## A whiteboard on the wall with a few scribbles (purely decorative).
func _draw_whiteboard() -> void:
	var w := size_px.x
	A.ink_rect(self, Rect2(2, -18, w - 4, 26), A.WHITE)
	draw_rect(Rect2(2, 6, w - 4, 3), A.CONC_M)
	for i in 3:
		draw_line(Vector2(8, -12 + i * 6), Vector2(w * 0.5 + i * 6, -12 + i * 6), [Color("2f4f8a"), A.BLOOD, Color("2a2c32")][i], 1.4)
	draw_arc(Vector2(w - 16, -6), 6.0, 0.0, TAU, 12, A.BLOOD, 1.4)

## A wall screen showing the employer's logo (white on purple, background only).
func _draw_tv() -> void:
	var w := size_px.x
	A.ink_rect(self, Rect2(2, -20, w - 4, 26), Color("14181c"))
	draw_rect(Rect2(5, -17, w - 10, 20), A.PURPLE if not world.state.alarm else Color("2a1416"))
	if not world.state.alarm:
		A.text(self, Vector2(w * 0.5 - 18, -4), "ASCEND AI", 7, A.WHITE)
	else:
		A.text(self, Vector2(w * 0.5 - 16, -4), tr(LsText.UI.no_signal), 6, Color("c04040"))

## Gary's cake on the party table, with a sticky note (A reads it).
func _draw_cake() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 28), w * 0.48, 5)
	A.ink_rect(self, Rect2(2, 6, w - 4, 20), A.WHITE)                       # tablecloth
	A.ink_rect(self, Rect2(w * 0.5 - 12, -4, 24, 14), Color("f0d8c8"), 1.5)
	draw_rect(Rect2(w * 0.5 - 12, -4, 24, 4), Color("e86a8a"))
	for i in 3:
		draw_rect(Rect2(w * 0.5 - 7 + i * 6, -9, 2, 5), A.YELLOW)
	A.flat_rect(self, Rect2(w * 0.5 + 14, 8, 8, 7), A.YELLOW, 1.0)          # the note
	for i in 4:
		A.ink_circle(self, Vector2(6 + i * 4, 18), 2.4, [A.BLOOD, A.WHITE][i % 2], 1.0)   # cups

func _draw_wet_sign() -> void:
	A.shadow(self, Vector2(16, 29), 8, 3)
	A.ink_poly(self, PackedVector2Array([Vector2(16, -6), Vector2(25, 28), Vector2(7, 28)]), A.YELLOW, 2.0)
	A.text(self, Vector2(14, 18), "!", 12, A.INK)

func _draw_boxes() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 30), w * 0.5, 4)
	A.ink_rect(self, Rect2(2, 8, 18, 22), Color("b08a5a"))
	A.ink_rect(self, Rect2(w - 20, 12, 16, 18), Color("a07a4a"))
	A.ink_rect(self, Rect2(6, -6, 16, 15), Color("c09a6a"))
	draw_rect(Rect2(12, -6, 3, 15), Color("d8c090"))

## Metal shelving with boxes and spare parts (plant). Searchable when it has loot.
func _draw_shelf() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 31), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, -20, 3, 50), A.STEEL)
	A.ink_rect(self, Rect2(w - 3, -20, 3, 50), A.STEEL)
	for i in 3:
		var y := -18.0 + i * 16.0
		A.ink_rect(self, Rect2(0, y + 10, w, 3), A.STEEL_HI, 1.2)
		for j in int(w / 18):
			if (i + j) % 3 != 2:
				A.flat_rect(self, Rect2(4 + j * 18, y + 1, 13, 9), [Color("b08a5a"), A.CONC_M, Color("6b7a3a")][(i + j) % 3], 1.0)

## A white first-aid cabinet on the wall (searchable: usually a kit inside).
func _draw_first_aid() -> void:
	A.ink_rect(self, Rect2(4, -14, 24, 22), A.WHITE)
	draw_rect(Rect2(14, -11, 4, 14), A.BLOOD)
	draw_rect(Rect2(9, -6, 14, 4), A.BLOOD)
	if searched():
		draw_rect(Rect2(5, -13, 4, 20), Color("c8ccd4"))

func _draw_rug() -> void:
	draw_rect(Rect2(Vector2.ZERO, size_px), Color("4a3f6a"))
	draw_rect(Rect2(Vector2(4, 4), size_px - Vector2(8, 8)), Color("5a4f7c"), false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, size_px), A.INK, false, 1.5)

func _draw_doormat() -> void:
	draw_rect(Rect2(Vector2(2, 6), size_px - Vector2(4, 12)), Color("3a3430"))
	for i in int(size_px.x / 6):
		draw_rect(Rect2(4 + i * 6, 8, 2, size_px.y - 16), Color("4a4440"))

# ---------------------------------------------------------------- v0.4: doors

## The loading dock's roll-up door (corrugated steel, yellow-black edge).
func _draw_rollup(locked: bool) -> void:
	A.ink_rect(self, Rect2(-2, -16, 36, 48), A.STEEL)
	for i in 8:
		draw_rect(Rect2(1, -13 + i * 5.5, 30, 2), A.shade(A.STEEL, -0.2 if i % 2 == 0 else 0.12))
	for i in 5:
		draw_rect(Rect2(-2 + i * 8, 28, 4, 4), A.YELLOW if i % 2 == 0 else A.INK)
	A.flat_rect(self, Rect2(13, -21, 7, 5), RED_LAMP if locked else GREEN, 1.4)

## The fire exit: a red door with a push bar, chained shut until the chain is cut.
func _draw_fire_door(locked: bool) -> void:
	A.ink_rect(self, Rect2(0, -12, 32, 44), Color("a8282c"))
	A.ink_rect(self, Rect2(4, -8, 24, 40), Color("c03034"), 1.5)
	A.ink_rect(self, Rect2(5, 10, 22, 4), A.STEEL_HI, 1.2)                  # push bar
	A.flat_rect(self, Rect2(6, -6, 20, 6), A.WHITE, 1.0)
	A.text(self, Vector2(8, -1.5), tr(LsText.SIGNS.exit).strip_edges().to_upper(), 6, Color("a8282c"))   # was "EXIT" (never translated)
	if locked:
		for i in 6:
			var a := Vector2(2 + i * 5, 4 + (i % 2) * 6)
			draw_circle(a, 2.6, A.INK)
			draw_circle(a, 1.6, A.STEEL_HI)
		A.ink_rect(self, Rect2(13, 12, 7, 7), Color("c9a227"), 1.2)          # padlock

# ---------------------------------------------------------------- v0.4: bodies and blood

## A body on the floor in a pool of blood. data "look": "zombie" | "coworker" | "office" |
## "hidden" (a knocked-out guard draws himself; this prop only makes him searchable).
## v0.5: "shirt" (hex) overrides the shirt color; "pool" = the size of the pool; "gore": true = the
## body the infected were eating (torn open, more blood around it).
func _draw_corpse() -> void:
	var look: String = data.get("look", "zombie")
	if look == "hidden":
		return
	var c := Vector2(16, 18)
	_pool(c + Vector2(2, 2), float(data.get("pool", 17.0)))
	var shirt := Color("4f8f5a")
	var skin := Color("d2a07a")
	match look:
		"zombie":
			shirt = [Color("5a6a7a"), Color("7a5a4a"), Color("4a5a4a"), Color("6a4a5a")][absi(id.hash()) % 4]
			skin = A.ZOMBIE
		"office":
			shirt = [Color("c9ccd3"), Color("9a4a5a"), Color("4a6a9a")][absi(id.hash()) % 3]
		"guard":
			shirt = Color("3a4a5e")
	if data.has("shirt"):
		shirt = Color(str(data.shirt))
	A.ink_rect(self, Rect2(c.x - 13, c.y - 6, 24, 13), shirt)
	draw_circle(Vector2(c.x - 4, c.y), 3.0, BLOOD)
	A.ink_rect(self, Rect2(c.x + 10, c.y - 8, 9, 9), skin)                 # head
	A.ink_rect(self, Rect2(c.x - 21, c.y - 4, 9, 8), Color("2a2a32"))      # legs
	A.ink_rect(self, Rect2(c.x - 6, c.y + 6, 4, 8), shirt, 1.2)            # an arm flung out
	if data.get("gore", false):
		# torn open: a dark wound across the middle and bits strewn around
		draw_rect(Rect2(c.x - 9, c.y - 4, 14, 8), Color("4a0608"))
		draw_circle(Vector2(c.x - 2, c.y), 3.5, A.BLOOD)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id) + 7
		for i in 7:
			var d := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(16.0, 30.0)
			draw_circle(c + Vector2(d.x, d.y * 0.6), rng.randf_range(1.5, 3.2), Color("6e0a0e"))
	if searched():
		draw_rect(Rect2(c.x - 13, c.y + 6, 6, 2), Color(1, 1, 1, 0.25))     # pockets turned out

## A dark red pool with a few drops around it (stable shape: seeded by the prop id).
func _pool(c: Vector2, r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var rr := r * rng.randf_range(0.7, 1.15)
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.6))
	draw_colored_polygon(pts, BLOOD)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.15), r * 0.25, A.shade(BLOOD, 0.15))
	for i in 5:
		draw_circle(c + Vector2(rng.randf_range(-r * 1.6, r * 1.6), rng.randf_range(-r, r)), rng.randf_range(1.0, 2.6), BLOOD)

## Blood on the floor (decoration). data "shape": "pool" | "splat" | "smear".
func _draw_blood() -> void:
	var c := size_px * 0.5
	match data.get("shape", "splat"):
		"pool":
			_pool(c, minf(size_px.x, size_px.y * 1.6) * 0.42)
		"smear":
			# a drag mark across the rect
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(id)
			var horiz := size_px.x >= size_px.y
			var n := int((size_px.x if horiz else size_px.y) / 6.0)
			for i in n:
				var t := float(i) / maxf(1.0, n - 1)
				var p := Vector2(size_px.x * t, c.y + sin(t * 6.0) * 3.0) if horiz else Vector2(c.x + sin(t * 6.0) * 3.0, size_px.y * t)
				draw_circle(p, rng.randf_range(2.5, 4.5) * (1.0 - t * 0.5), BLOOD)
		_:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(id)
			draw_circle(c, 7.0, BLOOD)
			for i in 9:
				var d := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(6.0, 15.0)
				draw_circle(c + d, rng.randf_range(1.2, 3.2), BLOOD)

# ---------------------------------------------------------------- v0.4: security

## The building alarm's control panel (security office). Red switch up = on; green = off.
func _draw_alarm_panel() -> void:
	var off: bool = world.state.flags.has("alarm_off")
	A.ink_rect(self, Rect2(2, -16, 28, 30), A.CONC_D)
	A.flat_rect(self, Rect2(6, -12, 20, 8), Color("14181c"), 1.2)
	A.text(self, Vector2(7.5, -5.5), tr(LsText.UI.alarm_panel).to_upper(), 6, GREEN if off else RED_LAMP)
	A.ink_rect(self, Rect2(10, 0, 12, 10), A.STEEL, 1.2)
	var blink: bool = int(float(world._clock) * 3.0) % 2 == 0
	var lamp := GREEN if off else (RED_LAMP if blink else Color("552222"))
	A.flat_rect(self, Rect2(13, 2 + (4 if off else 0), 6, 4), lamp, 1.0)

## Monitors on a security desk (static and grainy camera views).
func _draw_cctv() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 31), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, 8, w, 22), Color("40444c"))
	for i in int(w / 22):
		var r := Rect2(3 + i * 22, -14, 19, 15)
		A.ink_rect(self, r, Color("14181c"), 1.5)
		var t := float(world._clock)
		var g := 0.25 + 0.2 * absf(sin(t * 3.0 + i * 1.7))
		draw_rect(r.grow(-2), Color(g * 0.8, g, g * 0.9) if not world.state.alarm else Color(g, g * 0.4, g * 0.4))
		draw_line(r.position + Vector2(2, fmod(t * 20.0 + i * 7.0, r.size.y)), r.position + Vector2(r.size.x - 2, fmod(t * 20.0 + i * 7.0, r.size.y)), Color(1, 1, 1, 0.25), 1.0)
	A.flat_rect(self, Rect2(w * 0.5 - 10, 14, 20, 6), A.CONC_M, 1.2)

## The armory rack: riot helmets, vests and shields (searchable: the riot gear).
func _draw_riot_rack() -> void:
	var w := size_px.x
	var taken := searched()
	A.shadow(self, Vector2(w * 0.5, 31), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, -20, w, 50), Color("3a3e46"))
	for i in int(w / 22):
		var x := 4.0 + i * 22.0
		if taken and i == 0:
			continue
		A.ink_circle(self, Vector2(x + 9, -12), 6.0, Color("2a3448"), 1.4)     # helmet
		A.ink_rect(self, Rect2(x + 2, -4, 14, 14), Color("2a3448"), 1.4)        # vest
		A.ink_rect(self, Rect2(x + 1, 12, 16, 14), Color(0.78, 0.84, 0.9, 0.6), 1.2)   # shield

# ---------------------------------------------------------------- v0.4: Employee of the Month

## Gary's Employee of the Month wall: framed portraits (all Gary), Nash's tiny plaque underneath.
func _draw_eotm_wall() -> void:
	var w := size_px.x
	A.ink_rect(self, Rect2(0, -22, w, 8), A.PURPLE)
	var title := tr(LsText.SIGNS.eotm)
	A.text(self, Vector2(6, -16), title, 6, A.WHITE)
	var n := int(w / 18)
	for i in n:
		var r := Rect2(3 + i * 18, -12, 14, 18)
		A.ink_rect(self, r, Color("c9a227"), 1.2)
		draw_rect(r.grow(-2), Color("dde4ec"))
		var face := r.get_center() + Vector2(0, -1)
		draw_circle(face, 3.6, Color("f1c7a3"))
		draw_rect(Rect2(face.x - 3.6, face.y - 4, 7.2, 2.4), Color("8a5a2a"))         # Gary's hair
		draw_rect(Rect2(face.x - 4, face.y + 4, 8, 4), Color("d8dce4"))               # white shirt
		draw_rect(Rect2(face.x - 0.5, face.y + 4, 1, 3), A.BLOOD)                     # tie
		if i % 4 == 1:
			draw_rect(Rect2(face.x - 3, face.y - 1, 6, 1.5), A.INK)                   # sunglasses
		if world.state.alarm and i % 3 == 0:
			draw_line(r.position + Vector2(2, 2), r.end - Vector2(2, 2), BLOOD, 1.2)     # smeared
	A.flat_rect(self, Rect2(w * 0.5 - 6, 9, 12, 4), Color("c9a227"), 1.0)             # Nash's plaque

# ---------------------------------------------------------------- v0.4: server floor, cooling floor

## A server rack: dark cabinet, rows of blinking lights. data "spark": sparks fly from it.
func _draw_server_rack() -> void:
	var w := size_px.x
	var h := size_px.y
	A.shadow(self, Vector2(w * 0.5, h - 1), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, -22, w, h + 22), Color("1e2128"))
	var t := float(world._clock)
	var rows := int((h + 18) / 6)
	for j in rows:
		for i in int(w / 8):
			var on: bool = int(t * 6.0 + i * 3 + j * 7 + hash(id) % 5) % 5 != 0
			var col := GREEN if (i + j) % 4 != 0 else A.AMBER
			if world.state.alarm and (i + j) % 3 == 0:
				col = RED_LAMP
			draw_rect(Rect2(3 + i * 8, -19 + j * 6, 3, 2), col if on else Color(0.1, 0.1, 0.12))
	if data.get("spark", false) and int(t * 7.0) % 3 == 0:
		for k in 4:
			var a := Vector2(w * 0.6, -6) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
			draw_line(a, a + Vector2(randf_range(-5, 5), randf_range(-5, 5)), Color("fff0a0"), 1.5)

## A computer-room cooling unit (CRAC): a big grey box with fan grilles.
func _draw_crac() -> void:
	var w := size_px.x
	var h := size_px.y
	A.shadow(self, Vector2(w * 0.5, h - 1), w * 0.5, 5)
	A.ink_rect(self, Rect2(0, -14, w, h + 14), A.CONC_L)
	for i in int(w / 30):
		var cc := Vector2(15 + i * 30, h * 0.5 - 4)
		A.ink_circle(self, cc, 10.0, A.CONC_D, 1.5)
		var a := float(world._clock) * (6.0 if not world.state.alarm else 1.0)
		for k in 3:
			var d := Vector2.RIGHT.rotated(a + k * TAU / 3.0) * 8.0
			draw_line(cc, cc + d, A.STEEL_HI, 2.0)
	A.flat_rect(self, Rect2(4, -10, 18, 6), Color("14181c"), 1.0)
	draw_rect(Rect2(6, -8, 4, 2), GREEN)

## The tool cage on the cooling floor: a wire cage with tools (searchable: the bolt cutters).
func _draw_tool_cage() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 31), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, -20, w, 50), Color(0.2, 0.22, 0.25, 0.85))
	for i in int(w / 6) + 1:
		draw_line(Vector2(i * 6, -20), Vector2(i * 6, 30), Color(0.6, 0.65, 0.7, 0.6), 1.0)
	for j in 9:
		draw_line(Vector2(0, -20 + j * 6), Vector2(w, -20 + j * 6), Color(0.6, 0.65, 0.7, 0.6), 1.0)
	if not searched():
		draw_line(Vector2(8, 0), Vector2(26, 14), A.BLOOD, 3.0)             # bolt cutters (red grips)
		draw_line(Vector2(26, 0), Vector2(8, 14), A.BLOOD, 3.0)
	draw_line(Vector2(w - 20, -6), Vector2(w - 6, -6), A.STEEL_HI, 3.0)

# ---------------------------------------------------------------- v0.4: cafeteria

## A long cafeteria table with trays.
func _draw_cafe_table() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 28), w * 0.5, 5)
	A.ink_rect(self, Rect2(0, 2, w, 22), Color("c9b896"))
	draw_rect(Rect2(0, 2, w, 3), Color("ddd0b4"))
	for i in int(w / 30):
		var x := 6.0 + i * 30.0
		A.flat_rect(self, Rect2(x, 7, 18, 12), [Color("b03030"), Color("2f4f8a"), Color("4f8f5a")][i % 3], 1.0)
		draw_circle(Vector2(x + 6, 13), 3.0, A.WHITE)
		if world.state.alarm and i % 2 == 0:
			draw_circle(Vector2(x + 14, 10), 2.5, BLOOD)

## The kitchen line: stove, fryer, steel counter (searchable when it has loot).
func _draw_kitchen() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 31), w * 0.5, 4)
	A.ink_rect(self, Rect2(0, -8, w, 38), A.STEEL_HI)
	A.ink_rect(self, Rect2(0, 12, w, 18), A.STEEL)
	for i in int(w / 32):
		var x := 4.0 + i * 32.0
		if i % 2 == 0:
			for k in 4:
				A.ink_circle(self, Vector2(x + 7 + (k % 2) * 12, -2 + (k / 2) * 9), 3.5, Color("2a2c32"), 1.0)   # burners
		else:
			A.ink_rect(self, Rect2(x + 2, -6, 22, 14), Color("8a6a3a"), 1.2)    # fryer oil
			draw_rect(Rect2(x + 4, -4, 18, 3), Color("c9a24a"))

## A notice board on the wall (A reads the note pinned to it).
func _draw_corkboard() -> void:
	A.ink_rect(self, Rect2(2, -18, 28, 22), Color("a0784a"))
	A.flat_rect(self, Rect2(5, -15, 10, 9), A.WHITE, 1.0)
	A.flat_rect(self, Rect2(17, -14, 9, 8), A.YELLOW, 1.0)
	A.flat_rect(self, Rect2(8, -5, 12, 6), Color("e8b0c0"), 1.0)
	for p in [Vector2(10, -15), Vector2(21, -14), Vector2(14, -5)]:
		draw_circle(p, 1.2, A.BLOOD)

# ---------------------------------------------------------------- v0.4: branding

## A wall poster. data "sign": key of LsText.SIGNS; "product": true = the CLAUDIUS product poster
## (white wordmark on Ascend purple, background only, never cyan, never interactive).
func _draw_poster() -> void:
	var w := size_px.x
	if data.get("product", false):
		A.ink_rect(self, Rect2(3, -20, w - 6, 26), A.PURPLE)
		draw_rect(Rect2(5, -18, w - 10, 3), A.shade(A.PURPLE, 0.25))
		var word := tr(LsText.SIGNS.product)
		var fw := ThemeDB.fallback_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		A.text(self, Vector2(w * 0.5 - fw * 0.5, -7), word, 8, A.WHITE)
		var tag := tr(LsText.SIGNS.product_tag)
		var tw := ThemeDB.fallback_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
		A.text(self, Vector2(w * 0.5 - tw * 0.5, 1), tag, 5, Color(1, 1, 1, 0.8))
		return
	var text := tr(String(LsText.SIGNS.get(data.get("sign", ""), ""))).strip_edges().to_upper()
	A.ink_rect(self, Rect2(2, -14, w - 4, 14), Color("14181c"))
	var fw2 := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	A.text(self, Vector2(w * 0.5 - fw2 * 0.5, -4.5), text, 7, A.AMBER)

## The company name in big letters across the building front (lot).
func _draw_facade_sign() -> void:
	var w := size_px.x
	var text := tr(LsText.SIGNS.company)
	var fs := 15
	var fw := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var band := Rect2(w * 0.5 - fw * 0.5 - 30, -60, fw + 60, 24)
	A.ink_rect(self, band, A.PURPLE, 2.0)
	# the logo chevron on the left of the name
	var lc := band.position + Vector2(15, 7)
	for i in 5:
		draw_rect(Rect2(lc.x - 1 - i * 1.4, lc.y + i * 2.2, 2.2, 2.2), A.WHITE)
		draw_rect(Rect2(lc.x - 1 + i * 1.4, lc.y + i * 2.2, 2.2, 2.2), A.WHITE)
	A.text(self, Vector2(band.position.x + 30, band.position.y + 18), text, fs, A.WHITE)

# ---------------------------------------------------------------- v0.4: outside (service yard)

func _draw_dumpster() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 30), w * 0.5, 5)
	A.ink_rect(self, Rect2(0, -8, w, 38), Color("2f5a3a"))
	A.ink_rect(self, Rect2(-2, -12, w + 4, 8), Color("234a2c"), 1.5)
	draw_rect(Rect2(6, 4, w - 12, 2), A.shade(Color("2f5a3a"), -0.25))
	draw_rect(Rect2(6, 14, w - 12, 2), A.shade(Color("2f5a3a"), -0.25))

## A plain white box truck seen from above (no logos: nothing from Act 2).
func _draw_truck() -> void:
	var w := size_px.x
	var h := size_px.y
	A.shadow(self, Vector2(w * 0.5 + 3, h * 0.5 + 5), w * 0.48, h * 0.48, 0.4)
	A.ink_rect(self, Rect2(4, 0, w - 8, h * 0.68), Color("dcdcd6"), 2.5)                  # box
	for i in 4:
		draw_rect(Rect2(6, 6 + i * (h * 0.16), w - 12, 1.5), Color("b8b8b0"))
	A.ink_rect(self, Rect2(8, h * 0.7, w - 16, h * 0.28), Color("c9ccd3"), 2.0)           # cab
	draw_rect(Rect2(12, h * 0.73, w - 24, h * 0.09), Color("2a3340"))                    # windshield
	draw_rect(Rect2(10, h - 5, 8, 3), Color("f4e8b0"))
	draw_rect(Rect2(w - 18, h - 5, 8, 3), Color("f4e8b0"))

func _draw_pallet() -> void:
	var w := size_px.x
	A.shadow(self, Vector2(w * 0.5, 28), w * 0.5, 4)
	A.ink_rect(self, Rect2(1, 6, w - 2, 22), Color("b08a5a"))
	for i in 4:
		draw_rect(Rect2(1, 8 + i * 5, w - 2, 1.5), Color("8a6a3a"))
	A.ink_rect(self, Rect2(4, -6, w - 8, 14), Color("c09a6a"))

## Yellow-black stripes painted along the dock edge.
func _draw_dock_stripes() -> void:
	for i in int(size_px.x / 12) + 1:
		draw_rect(Rect2(i * 12, 0, 6, size_px.y), A.YELLOW)
		draw_rect(Rect2(i * 12 + 6, 0, 6, size_px.y), A.INK)

## v0.5: a window in the wall (data "flag": the story flag that breaks it). Intact: a dark pane with
## a frame and a glint. Broken: jagged glass in the frame, shards and a smear of blood on the floor
## under it (an infected came in through it).
func _draw_window() -> void:
	var w := size_px.x
	var broken: bool = world.state.flags.has(str(data.get("flag", "")))
	var frame := Rect2(2, -24, w - 4, 24)
	A.ink_rect(self, frame, Color("2a2e36"), 2.0)
	var pane := frame.grow(-3.0)
	if not broken:
		draw_rect(pane, Color("1c2a3a"))
		draw_line(pane.position + Vector2(4, pane.size.y - 4), pane.position + Vector2(14, 4), Color(1, 1, 1, 0.35), 2.0)
		draw_line(Vector2(w * 0.5, frame.position.y), Vector2(w * 0.5, frame.end.y), A.INK, 2.0)
		return
	draw_rect(pane, Color("0a0c10"))
	# jagged teeth of glass left in the frame
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var x := pane.position.x
	while x < pane.end.x - 2.0:
		var tw := rng.randf_range(4.0, 8.0)
		var tip := Vector2(x + tw * 0.5, pane.position.y + rng.randf_range(4.0, 11.0))
		draw_colored_polygon(PackedVector2Array([Vector2(x, pane.position.y), Vector2(x + tw, pane.position.y), tip]),
			Color(0.7, 0.8, 0.9, 0.55))
		var btip := Vector2(x + tw * 0.5, pane.end.y - rng.randf_range(3.0, 8.0))
		draw_colored_polygon(PackedVector2Array([Vector2(x, pane.end.y), Vector2(x + tw, pane.end.y), btip]),
			Color(0.7, 0.8, 0.9, 0.45))
		x += tw
	draw_rect(Rect2(pane.position.x + 4, pane.end.y - 3, pane.size.x - 8, 3), A.BLOOD)
	# shards and blood on the floor below
	for i in 12:
		var p := Vector2(rng.randf_range(2.0, w - 2.0), rng.randf_range(4.0, 26.0))
		var r := rng.randf_range(1.2, 2.6)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-r, 0), p + Vector2(0, -r * 0.6), p + Vector2(r, 0.4)]),
			Color(0.82, 0.9, 1.0, 0.75))
	for i in 4:
		draw_circle(Vector2(rng.randf_range(6.0, w - 6.0), rng.randf_range(8.0, 24.0)), rng.randf_range(2.0, 4.0), BLOOD)
