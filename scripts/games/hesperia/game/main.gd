extends Node2D
const Prefs = preload("res://scripts/games/hesperia/game/prefs.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
const WorldState = preload("res://scripts/games/hesperia/world_state.gd")
## Game flow: title -> new game / continue -> prologue -> free play. Owns the Area, Player, camera and UI layers.

const AREA := preload("res://scripts/games/hesperia/game/area.gd")
const PLAYER := preload("res://scripts/games/hesperia/game/player.gd")
const HUD := preload("res://scripts/games/hesperia/game/hud.gd")
const UI := preload("res://scripts/games/hesperia/game/ui_layer.gd")
const TOUCH := preload("res://scripts/games/hesperia/game/touch_controls.gd")
const T := 16

var world: Node2D
var area
var player
const CAM_ZOOM := 4.0 / 3.0  ## world appears 33% bigger (UI layers unaffected)
var camera: Camera2D
var hud
var ui
var touch
var fade: ColorRect
var in_game: bool = false
var busy: bool = false          # mid-transition
var prologue_running: bool = false

func _ready() -> void:
	Data.load_all()
	WorldState.new_state()
	_register_inputs()
	Prefs.load_prefs()
	Data.lang = Prefs.lang
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.07))
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	camera = Camera2D.new()
	add_child(camera)
	camera.position = Vector2(192, 108)
	camera.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	hud = HUD.new()
	hud.visible = false
	layer.add_child(hud)
	touch = TOUCH.new()
	layer.add_child(touch)
	ui = UI.new()
	layer.add_child(ui)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	ui.new_game_requested.connect(_on_new_game)
	ui.continue_requested.connect(_on_continue)
	ui.save_requested.connect(_manual_save)
	ui.dialogue_closed.connect(_on_dialogue_closed)
	ui.quit_to_title_requested.connect(_to_title)
	ui.language_changed.connect(_on_prefs_changed)
	_to_title()
	# Dev shortcut: godot --path . -- --dev-area=b7 [--dev-female]  (skips title + prologue; screenshots/tests)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dev-area="):
			ui.close()
			WorldState.new_state()
			WorldState.hero_name = "Dev"
			WorldState.male = not OS.get_cmdline_user_args().has("--dev-female")
			WorldState.set_flag("prologue_done")
			WorldState.area = a.get_slice("=", 1)
			WorldState.pos = Vector2(256, 300)
			_begin_game()

func _register_inputs() -> void:
	var map := {
		"mv_left": [KEY_A, KEY_LEFT], "mv_right": [KEY_D, KEY_RIGHT], "mv_up": [KEY_W, KEY_UP], "mv_down": [KEY_S, KEY_DOWN],
		"btn_a": [KEY_J, KEY_Z, KEY_SPACE], "btn_b": [KEY_K, KEY_X], "btn_x": [KEY_U, KEY_C], "btn_y": [KEY_I, KEY_V],
		"pause": [KEY_ESCAPE, KEY_P], "menu": [KEY_TAB, KEY_M],
	}
	for a in map.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
		for k in map[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)

# ------------------------------------------------------------------------------------------ flow
func _to_title() -> void:
	in_game = false
	hud.visible = false
	touch.visible = false
	if area != null:
		area.queue_free()
		area = null
	if player != null:
		player.queue_free()
		player = null
	WorldState.new_state()
	ui.open_title()

func _on_new_game(hero_name: String, male: bool) -> void:
	WorldState.new_state()
	WorldState.hero_name = hero_name
	WorldState.male = male
	WorldState.hair = ui.hair_pick
	WorldState.start_quest("m01")
	_begin_game()
	# Prologue: the raid on Halcyon Cove
	prologue_running = true
	area.fire_overlay = true
	player.cant_die = true
	ui.start_dialogue("_prologue")

func _on_continue() -> void:
	if not WorldState.load_game():
		_to_title()
		return
	_begin_game()

func _begin_game() -> void:
	in_game = true
	hud.visible = true
	hud.apply_text_size()
	hud.refresh_quest()
	touch.visible = Prefs.touch_visible()
	player = PLAYER.new()
	world.add_child(player)
	_load_area(WorldState.area, WorldState.pos)

func _on_dialogue_closed() -> void:
	if prologue_running and WorldState.has_flag("prologue_done"):
		prologue_running = false
		area.fire_overlay = false
		player.cant_die = false
		WorldState.respawn_area = "b7"
		WorldState.respawn_pos = Vector2(256, 400)
		WorldState.save_game()
		WorldState.bus.emit_signal("toast", Data.tr_ui("saved"))

func _load_area(id: String, pos: Vector2) -> void:
	if area != null:
		area.queue_free()
	area = AREA.new()
	world.add_child(area)
	world.move_child(area, 0)
	area.setup(id, player)
	area.warp.connect(_on_warp)
	area.edge.connect(_on_edge)
	area.talk.connect(ui.start_dialogue)
	area.read_text.connect(_on_read)
	area.boss_won.connect(_on_boss_won)
	player.area = area
	player.position = pos
	player.dead = false
	WorldState.area = id
	WorldState.pos = pos
	_cam_snap()

func _on_read(t) -> void:
	ui.show_text(t)

func _on_boss_won(bid: String) -> void:
	WorldState.bus.emit_signal("toast", Data.tr_ui("boss_down"))
	if bid == "b01":
		await get_tree().create_timer(2.5, false).timeout
		if in_game:
			ui.show_text(Data.ui["slice_end"])

func _on_warp(map_id: String, tx: int, ty: int) -> void:
	if busy:
		return
	busy = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.18)
	await tw.finished
	var kind_from: String = area.def.get("kind", "outdoor")
	var dest: Dictionary = Data.maps[map_id]
	var pos := Vector2(tx * T + T * 0.5, ty * T + T * 0.5)
	_load_area(map_id, pos)
	# entrance respawn: where you came in from the outside world / first dungeon room
	if dest.get("kind", "outdoor") != "dungeon" or kind_from != "dungeon":
		WorldState.respawn_area = map_id
		WorldState.respawn_pos = pos
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.18)
	await tw2.finished
	busy = false

func _on_edge(dir: String) -> void:
	if busy:
		return
	var target: String = area.def["edges"][dir]
	var tdef: Dictionary = Data.maps[target]
	var p: Vector2 = player.position
	var tw_px := float(tdef["w"]) * T
	var th_px := float(tdef["h"]) * T
	match dir:
		"n": p = Vector2(p.x, th_px - 10.0)
		"s": p = Vector2(p.x, 10.0)
		"w": p = Vector2(tw_px - 10.0, p.y)
		"e": p = Vector2(10.0, p.y)
	busy = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.15)
	await tw.finished
	_load_area(target, p)
	WorldState.respawn_area = target
	WorldState.respawn_pos = p
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.15)
	await tw2.finished
	busy = false

# ------------------------------------------------------------------------------------------ death
func _on_player_died() -> void:
	WorldState.bus.emit_signal("toast", Data.tr_ui("died"))
	busy = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	await tw.finished
	WorldState.half_hearts = WorldState.max_half_hearts
	WorldState.bus.emit_signal("changed")
	_load_area(WorldState.respawn_area, WorldState.respawn_pos)
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.4)
	await tw2.finished
	busy = false

# ------------------------------------------------------------------------------------------ frame
func _process(dt: float) -> void:
	WorldState.play_seconds += dt
	if not in_game or area == null or player == null:
		return
	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	WorldState.pos = player.position
	WorldState.area = area.map_id
	_cam_follow()
	touch.visible = Prefs.touch_visible() and not ui.is_open()
	if not ui.is_open() and not busy and not prologue_running:
		if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("menu"):
			ui.open_menu()

func _cam_axis(p: float, view: float, size: float) -> float:
	if size <= view:
		return size * 0.5
	return clampf(p, view * 0.5, size - view * 0.5)

func _cam_follow() -> void:
	var sz: Vector2 = area.pixel_size()
	var c := Vector2(_cam_axis(player.position.x, 384.0 / CAM_ZOOM, sz.x), _cam_axis(player.position.y, 216.0 / CAM_ZOOM, sz.y))
	if area.shake_t > 0.0:
		c += Vector2(randf_range(-2, 2), randf_range(-2, 2))
	camera.position = c

func _cam_snap() -> void:
	_cam_follow()

func _manual_save() -> void:
	if WorldState.save_game():
		WorldState.bus.emit_signal("toast", Data.tr_ui("saved"))

func _on_prefs_changed() -> void:
	hud.apply_text_size()

func _notification(what: int) -> void:
	# Android: autosave when the app is suspended (hub rule: pause/resume safe).
	if what == NOTIFICATION_APPLICATION_PAUSED and in_game and not prologue_running:
		WorldState.save_game()
		if not ui.is_open():
			ui.open_menu()
