extends Control

## Bridge Master -- build a bridge across a gap, then send a vehicle over it.
## Drag from a joint (a bolt) to lay a piece of the chosen material; road pieces
## carry the vehicle, wood/steel make the truss, cables only pull. Test runs the
## truss physics (bridge_master_engine.gd): pieces glow from green to red with
## the load and snap past their strength. 300 levels in 10 chapters; stars for
## building cheap; a Load Test after a win piles weight on until the bridge gives.
## Owner's art (2026-11-12): Landing picture + three canyon backdrops; the cliffs,
## bridge and vehicles are drawn in code.

const E = preload("res://scripts/games/bridge_master/bridge_master_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SoundLib = preload("res://scripts/games/bridge_master/sound_lib.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/bridge_master/home_kit.gd")
## Landing layout: docs/MENU_STYLES.md S6 "Stone Slabs", told as wooden road planks (landing_slabs.gd).
const LandingSlabs = preload("res://scripts/games/bridge_master/landing_slabs.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/bridge_master/bridge_master_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://bridge_master_save.json"
const PROGRESS_PATH := "user://bridge_master_progress.json"
const ART_LANDING := "res://games/bridge_master/landing_bg.jpg"
const BACKDROPS := ["res://games/bridge_master/bg_forest.jpg", "res://games/bridge_master/bg_desert.jpg", "res://games/bridge_master/bg_mesa.jpg"]
## Owner's cut-out art (2026-11-13), made by tools/bridge_master_cutout.py; Classic
## only (Voodoo keeps the neon lines). Fractions of each picture, from that tool:
## cliffs [ground line from the top, cliff face from the left], vehicles [rear, front wheel].
const PARTS_DIR := "res://games/bridge_master/parts/"
const CLIFF_SETS := ["forest", "desert", "mesa"]
const CLIFF_META := {
	"cliff_forest_l": [0.24, 0.95], "cliff_forest_r": [0.05, 0.04],
	"cliff_desert_l": [0.06, 0.96], "cliff_desert_r": [0.05, 0.025],
	"cliff_mesa_l": [0.09, 0.97], "cliff_mesa_r": [0.07, 0.027],
}
const VEH_META := {"car": [0.18, 0.79], "van": [0.19, 0.77], "bus": [0.22, 0.78], "truck": [0.21, 0.80], "heavy": [0.18, 0.82]}
const MAT_TEX := {"road": "road_wood", "sroad": "road_steel", "wood": "beam_wood", "steel": "beam_steel", "cable": "cable"}
const TEX_WIDTH := {"road": 0.42, "sroad": 0.5, "wood": 0.24, "steel": 0.26, "cable": 0.1}
const TEX_LEN := 4.0  # metres the whole picture of a piece stands for
const BOARD := "Heaviest load (kg)"
const ACCENT := Color("ffb74d")
const TOP_BAR := 100.0
const BOTTOM_BAR := 96.0
const LOAD_STEP := 0.25   # each Load Test round adds this much of the vehicle's weight
const TEST_SPEED := 1.0
const LOAD_SPEED := 2.0

const MAT_COLORS := {
	"road": Color("6d4c33"), "sroad": Color("4f5b66"), "wood": Color("c08a4a"),
	"steel": Color("9aa9b6"), "cable": Color("2b2b2b"),
}
const MAT_NEON := {
	"road": Color("ffb74d"), "sroad": Color("ff7043"), "wood": Color("ffd54f"),
	"steel": Color("4dd0e1"), "cable": Color("e040fb"),
}
const MAT_WIDTH := {"road": 0.30, "sroad": 0.32, "wood": 0.16, "steel": 0.17, "cable": 0.06}
const VEH_COLORS := {"car": Color("e53935"), "van": Color("1e88e5"), "bus": Color("fdd835"), "truck": Color("43a047"), "heavy": Color("fb8c00")}

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var lv: Dictionary = {}
var cur_level := 1
var design: Array = []
var undo_stack: Array = []
var mat := "road"
var erase := false
var testing := false
var load_test := false
var load_mult := 1.0
var load_best := 0.0
var started := false
var result_shown := false
var progress: Dictionary = {}
var skin := "classic"

var drag_on := false
var drag_from := Vector2i.ZERO
var drag_to := Vector2i.ZERO
var drag_ok := false

var board: Control
var title_label: Label
var cost_label: Label
var skip_btn: Button
var clear_btn: Button
var mat_bar: HBoxContainer
var mat_buttons := {}
var erase_btn: Button
var undo_btn: Button
var test_btn: Button
var toast_label: Label
var budget_bar: ProgressBar
var fx_layer: Control
var _broken_prev := PackedByteArray()
var _splashed := false
var toast_t := 0.0
var end_card: Control
var map_layer: Control
var map_drag = null
var map_from_landing := false
var _backdrops: Array = []
var _disc: Texture2D
var _parts := {}
var vs := 40.0
var vo := Vector2.ZERO
## Zoom (owner 2026-11-13): pinch with two fingers, mouse wheel on PC; two fingers (or the right /
## middle mouse button) drag the view. zoom 1 = the whole level fits (_layout).
const ZOOM_MAX := 4.0
var zoom := 1.0
var _fit_vs := 40.0
var _fit_vo := Vector2.ZERO
var _touches := {}          # finger index -> screen position
var _pinch_d := 0.0
var _pinch_mid := Vector2.ZERO
var _pinching := false      # true from the second finger down until every finger is up
var _pan_mouse := false
var _press_at := Vector2.ZERO
var fit_btn: Button
var grid_btn: Button
## Build grid: "dots" (default), "lines" (a 1 m grid with every 5th line stronger), "off".
const GRID_MODES := ["dots", "lines", "off"]
var grid_mode := "dots"

func _ready() -> void:
	preload("res://scripts/games/bridge_master/bridge_master_i18n.gd").install(self)
	Orientation.lock_landscape()
	engine = E.new()
	E.load_table()
	_disc = _make_disc()
	for p in BACKDROPS:
		_backdrops.append(load(p) if ResourceLoader.exists(p) else null)
	_load_progress()
	grid_mode = str(progress.get("grid", "dots"))
	if not grid_mode in GRID_MODES:
		grid_mode = "dots"
	_build_ui()
	_play_music()
	_begin(_next_level())
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(_on_board_resized)
	add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 24)
	top.add_theme_constant_override("margin_left", 14)
	top.add_theme_constant_override("margin_right", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(68, 68)
	LandingSlabs.dress(pause_btn, "bolt")
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	bar.add_child(title_label)
	var cost_box := VBoxContainer.new()
	cost_box.add_theme_constant_override("separation", 2)
	cost_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(cost_box)
	cost_label = Label.new()
	cost_label.add_theme_font_size_override("font_size", 28)
	cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	cost_label.add_theme_constant_override("outline_size", 8)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_box.add_child(cost_label)
	# How much of the budget is spent: green, then amber, red past the budget.
	budget_bar = ProgressBar.new()
	budget_bar.show_percentage = false
	budget_bar.custom_minimum_size = Vector2(200, 12)
	budget_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.set_corner_radius_all(6)
	back.set_border_width_all(2)
	back.border_color = Color(1, 1, 1, 0.35)
	budget_bar.add_theme_stylebox_override("background", back)
	cost_box.add_child(budget_bar)
	skip_btn = Button.new()
	skip_btn.custom_minimum_size = Vector2(76, 68)
	skip_btn.pressed.connect(_on_skip)
	bar.add_child(skip_btn)
	clear_btn = Button.new()
	clear_btn.text = "🧹"
	clear_btn.tooltip_text = tr("Clear the bridge")
	clear_btn.custom_minimum_size = Vector2(68, 68)
	clear_btn.pressed.connect(_clear_design)
	bar.add_child(clear_btn)
	grid_btn = Button.new()
	grid_btn.text = "#"
	grid_btn.tooltip_text = tr("Grid: dots, lines or off")
	grid_btn.custom_minimum_size = Vector2(68, 68)
	grid_btn.add_theme_font_size_override("font_size", 30)
	grid_btn.pressed.connect(_cycle_grid)
	bar.add_child(grid_btn)
	bar.move_child(grid_btn, clear_btn.get_index())
	fit_btn = Button.new()
	fit_btn.text = "⤢"
	fit_btn.tooltip_text = tr("Show the whole level")
	fit_btn.custom_minimum_size = Vector2(68, 68)
	fit_btn.add_theme_font_size_override("font_size", 30)
	fit_btn.pressed.connect(_zoom_reset)
	fit_btn.visible = false
	bar.add_child(fit_btn)
	bar.move_child(fit_btn, grid_btn.get_index())
	LandingSlabs.dress(skip_btn, "bolt")
	LandingSlabs.dress(clear_btn, "bolt")
	LandingSlabs.dress(grid_btn, "bolt")
	LandingSlabs.dress(fit_btn, "bolt")

	var bottom := MarginContainer.new()
	bottom.add_theme_constant_override("margin_bottom", 14)
	bottom.add_theme_constant_override("margin_left", 14)
	bottom.add_theme_constant_override("margin_right", 14)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 8)
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bb)
	mat_bar = HBoxContainer.new()
	mat_bar.add_theme_constant_override("separation", 6)
	mat_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bb.add_child(mat_bar)
	erase_btn = Button.new()
	erase_btn.text = "🗑"
	erase_btn.tooltip_text = tr("Remove pieces")
	erase_btn.toggle_mode = true
	erase_btn.custom_minimum_size = Vector2(68, 68)
	erase_btn.toggled.connect(_on_erase_toggled)
	bb.add_child(erase_btn)
	undo_btn = Button.new()
	undo_btn.text = "↶"
	undo_btn.tooltip_text = tr("Undo")
	undo_btn.custom_minimum_size = Vector2(68, 68)
	undo_btn.pressed.connect(_undo)
	bb.add_child(undo_btn)
	test_btn = Button.new()
	test_btn.text = tr("▶ Test")
	test_btn.custom_minimum_size = Vector2(190, 68)
	test_btn.add_theme_font_size_override("font_size", 30)
	test_btn.pressed.connect(_on_test)
	bb.add_child(test_btn)
	LandingSlabs.dress(erase_btn, "bolt")
	LandingSlabs.dress(undo_btn, "bolt")
	LandingSlabs.dress(test_btn, "go")

	# Particles (sparks, splash, confetti) over the board, under the bars.
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(fx_layer, board.get_index() + 1)

	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 26)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 96
	toast_label.offset_left = 40
	toast_label.offset_right = -40

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": ACCENT,
		"subtitle": "Build it, then drive across. 300 levels.",
		"art": ART_LANDING,
		"landing": "slabs",
		"landing_style": LandingSlabs,
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🌉 Campaign", "sub": "300 levels · build cheap for stars", "action": _start_campaign},
		],
		"play": [
			{"text": "📋 Level Select", "sub": "Pick any level you have opened", "action": _open_map_from_landing, "card": true},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "⏭ Skip level", "how": "Opens the next level without building this one.", "action": _skip_now}],
		"board": BOARD,
		"board_note": "The heaviest load one of your bridges carried in a Load Test.",
	})
	add_child(home)
	home.track_help_button(skip_btn, "⏭")
	if info:
		add_child(info)

func _on_board_resized() -> void:
	_layout()
	board.queue_redraw()

func _toast(text: String, secs: float = 2.5) -> void:
	toast_label.text = text
	toast_t = secs
	toast_label.visible = true

# ---------- game flow ----------

func _start_campaign() -> void:
	_start_level(_next_level())

func _start_level(n: int) -> void:
	_close_map()
	_begin(n)

func _restart() -> void:
	_stop_test()
	_begin(cur_level)

func _begin(n: int) -> void:
	cur_level = clampi(n, 1, E.LEVEL_COUNT)
	lv = E.level(cur_level)
	var saved = progress.designs.get(str(cur_level))
	design = []
	# Levels were remade (2026-11-13): keep only the saved pieces that still fit this layout.
	if saved is Array:
		for m in saved:
			if m is Array and m.size() == 5 and str(m[4]) in lv.mats 					and E.check_member(lv, design, int(m[0]), int(m[1]), int(m[2]), int(m[3]), str(m[4])) == "":
				design.append(m.duplicate())
	undo_stack.clear()
	testing = false
	load_test = false
	result_shown = false
	erase = false
	erase_btn.set_pressed_no_signal(false)
	started = true
	drag_on = false
	_close_end()
	_build_mat_bar()
	_labels()
	_layout()
	_set_editing(true)
	var lvl_info := _level_tip()
	if lvl_info != "":
		_toast(lvl_info, 5.0)
	board.queue_redraw()
	_save_game()

## A one-line note when a level brings something new.
func _level_tip() -> String:
	var n := cur_level
	if n == 1:
		return tr("Drag from a bolt to lay road. Join both cliffs, add triangles, then ▶ Test.")
	for k in E.MAT_ORDER:
		if int(E.MATS[k].unlock) == n and n > 1:
			return tr("New material: %s") % tr(E.MATS[k].name)
	if lv.pier != null and (n == 1 or E.generate(n - 1).pier == null):
		return tr("A rock pillar in the river: build onto its bolt.")
	if n == 3:
		return tr("Too heavy for road alone: add wood under or above it in triangles.")
	if int(lv.dh) != 0 and int(E.generate(n - 1).dh) == 0:
		return tr("The cliffs are at different heights: the road can slope.")
	if lv.anchors.size() > 2 and E.generate(n - 1).anchors.size() == 2 and lv.pier == null:
		return tr("Extra bolts lower down the cliff: brace from them.")
	return ""

func _labels() -> void:
	var c: int = lv.chapter
	title_label.text = tr("Level %d") % cur_level + " · " + tr(E.CHAPTERS[c]) + " · " + tr(E.VEHICLES[lv.vehicle].name)
	_cost_label()
	_help_label()

func _cost_label() -> void:
	var cost := E.design_cost(design)
	cost_label.text = "$%s / $%s" % [_money(cost), _money(int(lv.budget))]
	cost_label.add_theme_color_override("font_color", Color("ff5252") if cost > int(lv.budget) else Color.WHITE)
	var share := float(cost) / maxf(1.0, float(lv.budget))
	budget_bar.max_value = 100.0
	budget_bar.value = clampf(share * 100.0, 0.0, 100.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("66bb6a") if share <= 0.75 else (Color("ffb300") if share <= 1.0 else Color("ff1744"))
	fill.set_corner_radius_all(6)
	budget_bar.add_theme_stylebox_override("fill", fill)

static func _money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out

func _build_mat_bar() -> void:
	for ch in mat_bar.get_children():
		ch.queue_free()
	mat_buttons.clear()
	if not mat in lv.mats:
		mat = "road"
	for k in lv.mats:
		var b := Button.new()
		b.text = tr(E.MATS[k].name) + "\n$%d/m" % int(E.MATS[k].cost)
		b.toggle_mode = true
		b.button_pressed = k == mat
		b.custom_minimum_size = Vector2(0, 68)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_pick_mat.bind(k))
		mat_bar.add_child(b)
		LandingSlabs.dress(b, "wood")
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var sb: StyleBox = b.get_theme_stylebox(st).duplicate()
			sb.content_margin_left = 58
			b.add_theme_stylebox_override(st, sb)
		var sw := TextureRect.new()
		sw.texture = _part(MAT_TEX[k])
		sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sw.stretch_mode = TextureRect.STRETCH_SCALE
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.custom_minimum_size = Vector2(44, 18)
		b.add_child(sw)
		sw.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		sw.offset_left = 12
		sw.offset_right = 56
		sw.offset_top = -10 if k != "cable" else -4
		sw.offset_bottom = 10 if k != "cable" else 4
		mat_buttons[k] = b

func _pick_mat(k: String) -> void:
	mat = k
	erase = false
	erase_btn.set_pressed_no_signal(false)
	for key in mat_buttons:
		(mat_buttons[key] as Button).set_pressed_no_signal(key == k)

func _on_erase_toggled(on: bool) -> void:
	erase = on

func _set_editing(on: bool) -> void:
	for b in [erase_btn, undo_btn, clear_btn]:
		b.disabled = not on
	for k in mat_buttons:
		(mat_buttons[k] as Button).disabled = not on
	test_btn.text = tr("▶ Test") if on else tr("■ Edit")

# ---------- editing ----------

func _joints() -> Array:
	var seen := {}
	var out: Array = []
	for a in lv.anchors:
		var k := Vector2i(int(a[0]), int(a[1]))
		if not seen.has(k):
			seen[k] = true
			out.append(k)
	for m in design:
		for k in [Vector2i(int(m[0]), int(m[1])), Vector2i(int(m[2]), int(m[3]))]:
			if not seen.has(k):
				seen[k] = true
				out.append(k)
	return out

func _nearest_joint(w: Vector2, reach: float) -> Variant:
	var best = null
	var bd := reach
	for j in _joints():
		var d := w.distance_to(Vector2(j))
		if d < bd:
			bd = d
			best = j
	return best

func _push_undo() -> void:
	undo_stack.append(design.duplicate(true))
	if undo_stack.size() > 60:
		undo_stack.pop_front()

func _undo() -> void:
	if testing or undo_stack.is_empty():
		return
	design = undo_stack.pop_back()
	_design_changed()

func _clear_design() -> void:
	if testing or design.is_empty():
		return
	_push_undo()
	design.clear()
	_design_changed()
	_toast(tr("Cleared. ↶ brings it back."))

func _design_changed() -> void:
	progress.designs[str(cur_level)] = design.duplicate(true)
	_save_progress()
	_cost_label()
	board.queue_redraw()

func _on_board_input(event: InputEvent) -> void:
	if not started:
		return
	if _zoom_input(event):
		return
	if testing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var w := _to_world(event.position)
		if erase:
			# Erase on release, and only for a tap (a pinch must not remove anything).
			if event.pressed:
				_press_at = event.position
			elif event.position.distance_to(_press_at) < 14.0:
				_erase_at(w)
			return
		if event.pressed:
			var j = _nearest_joint(w, 0.75)
			if j == null:
				_toast(tr("Start from a bolt: a cliff bolt or the end of a piece."))
				return
			drag_on = true
			drag_from = j
			_update_drag(w)
		elif drag_on:
			drag_on = false
			_update_drag(w)
			_finish_drag()
	elif event is InputEventMouseMotion and drag_on:
		_update_drag(_to_world(event.position))

## Pinch / two-finger drag / wheel / right-drag. Returns true when the event was a view move.
func _zoom_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2:
			_pinching = true
			drag_on = false   # a second finger cancels the piece being laid
			board.queue_redraw()
			var pts: Array = _touches.values()
			_pinch_d = (pts[0] as Vector2).distance_to(pts[1])
			_pinch_mid = ((pts[0] as Vector2) + pts[1]) * 0.5
		elif _touches.is_empty():
			_pinching = false
		return _pinching
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var d := (pts[0] as Vector2).distance_to(pts[1])
			var mid: Vector2 = ((pts[0] as Vector2) + pts[1]) * 0.5
			if _pinch_d > 1.0:
				_zoom_at(mid, d / _pinch_d)
			_pan(mid - _pinch_mid)
			_pinch_d = d
			_pinch_mid = mid
			return true
		return _pinching
	# While two fingers are (or were) down, the phone's emulated mouse events are ignored.
	if _pinching and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return true
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.15)
			return true
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / 1.15)
			return true
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_pan_mouse = event.pressed
			return true
	if event is InputEventMouseMotion and _pan_mouse:
		_pan(event.relative)
		return true
	if event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
		return true
	if event is InputEventPanGesture:
		_pan(-event.delta * 12.0)
		return true
	return false

## Zooms by `k` keeping the world point under `at` still.
func _zoom_at(at: Vector2, k: float) -> void:
	var nz := clampf(zoom * k, 1.0, ZOOM_MAX)
	if absf(nz - zoom) < 0.0001:
		return
	var w := _to_world(at)
	zoom = nz
	vs = _fit_vs * zoom
	vo = at - Vector2(w.x, -w.y) * vs
	_clamp_view()

func _pan(d: Vector2) -> void:
	if zoom <= 1.0001:
		return
	vo += d
	_clamp_view()

## Keeps the level on screen: at zoom 1 exactly the fitted view; zoomed, the level's edges
## can't move inside the screen.
func _clamp_view() -> void:
	if zoom <= 1.0001:
		zoom = 1.0
		vs = _fit_vs
		vo = _fit_vo
	else:
		# The fitted view's world rectangle, scaled: keep it covering the fitted screen area.
		var fit_tl := _fit_vo + Vector2(-2.5, -(float(E.top_limit(lv)) + 0.4)) * _fit_vs
		var fit_br := _fit_vo + Vector2(float(lv.w) + 2.5, -(float(lv.water) - 0.5)) * _fit_vs
		var cur_tl := vo + Vector2(-2.5, -(float(E.top_limit(lv)) + 0.4)) * vs
		var cur_br := vo + Vector2(float(lv.w) + 2.5, -(float(lv.water) - 0.5)) * vs
		var shift := Vector2.ZERO
		if cur_tl.x > fit_tl.x:
			shift.x = fit_tl.x - cur_tl.x
		elif cur_br.x < fit_br.x:
			shift.x = fit_br.x - cur_br.x
		if cur_tl.y > fit_tl.y:
			shift.y = fit_tl.y - cur_tl.y
		elif cur_br.y < fit_br.y:
			shift.y = fit_br.y - cur_br.y
		vo += shift
	if fit_btn:
		fit_btn.visible = zoom > 1.0001
	board.queue_redraw()

func _zoom_reset() -> void:
	zoom = 1.0
	_clamp_view()

func _cycle_grid() -> void:
	var i := GRID_MODES.find(grid_mode)
	grid_mode = GRID_MODES[(i + 1) % GRID_MODES.size()]
	progress["grid"] = grid_mode
	_save_progress()
	_toast({"dots": tr("Grid: dots"), "lines": tr("Grid: lines"), "off": tr("Grid: off")}[grid_mode], 1.5)
	board.queue_redraw()

func _update_drag(w: Vector2) -> void:
	var snap = _nearest_joint(w, 0.45)
	var target: Vector2i
	if snap != null and Vector2(snap - drag_from).length() <= float(E.MATS[mat].max) + 0.001:
		target = snap
	else:
		target = E.clamp_reach(drag_from.x, drag_from.y, w.x, w.y, mat)
	drag_to = target
	drag_ok = E.check_member(lv, design, drag_from.x, drag_from.y, target.x, target.y, mat) == ""
	board.queue_redraw()

func _finish_drag() -> void:
	board.queue_redraw()
	if drag_to == drag_from:
		return
	var why := E.check_member(lv, design, drag_from.x, drag_from.y, drag_to.x, drag_to.y, mat)
	if why == "same":
		return
	if why != "":
		_toast(tr(why))
		return
	_push_undo()
	design.append([drag_from.x, drag_from.y, drag_to.x, drag_to.y, mat])
	_design_changed()
	match mat:
		"steel", "sroad":
			SoundLib.play(self, "impact/metal_light", -6.0)
		"cable":
			SoundLib.play(self, "rpg/creak", -8.0)
		_:
			SoundLib.play(self, "impact/wood_light", -6.0)

func _erase_at(w: Vector2) -> void:
	var best := -1
	var bd := 0.45
	for i in design.size():
		var m: Array = design[i]
		var a := Vector2(float(m[0]), float(m[1]))
		var b := Vector2(float(m[2]), float(m[3]))
		var d := w.distance_to(Geometry2D.get_closest_point_to_segment(w, a, b))
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return
	_push_undo()
	design.remove_at(best)
	_design_changed()
	SoundLib.play(self, "impact/wood_light", -12.0)

func _unhandled_input(event: InputEvent) -> void:
	if not started or not is_visible_in_tree() or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_Z and event.ctrl_pressed:
		_undo()
		get_viewport().set_input_as_handled()

# ---------- testing ----------

func _on_test() -> void:
	if testing:
		_stop_test()
		return
	if E.design_cost(design) > int(lv.budget):
		_toast(tr("Over budget: remove something first."))
		return
	if design.is_empty():
		_toast(tr("Build a bridge first: drag from a bolt."))
		return
	load_test = false
	load_mult = 1.0
	_run_test()

func _run_test() -> void:
	_close_end()
	testing = true
	result_shown = false
	drag_on = false
	_broken_seen = 0
	_broken_prev = PackedByteArray()
	_splashed = false
	engine.setup(lv, design, load_mult)
	_set_editing(false)
	if load_test:
		_toast(tr("Load test: %s kg") % _money(_load_kg(load_mult)), 2.0)
	board.queue_redraw()

func _stop_test() -> void:
	testing = false
	load_test = false
	_close_end()
	engine.status = "idle"
	_set_editing(true)
	board.queue_redraw()

func _load_kg(mult: float) -> int:
	return int(round(float(E.VEHICLES[lv.vehicle].mass) * mult * 1000.0))

var _broken_seen := 0

func _process(delta: float) -> void:
	if toast_t > 0.0:
		toast_t -= delta
		toast_label.modulate.a = clampf(toast_t * 2.0, 0.0, 1.0)
	if not testing:
		return
	engine.advance(delta * (LOAD_SPEED if load_test else TEST_SPEED))
	var nb: int = engine.broken_count()
	if nb > _broken_seen:
		SoundLib.play(self, "impact/wood_heavy" if randf() < 0.5 else "impact/metal_heavy", -4.0)
		for i in engine.broken.size():
			if engine.broken[i] and (i >= _broken_prev.size() or not _broken_prev[i]):
				var mid: Vector2 = (engine.pos[engine.ma[i]] + engine.pos[engine.mb[i]]) * 0.5
				_burst(_to_screen(mid), "sparks")
		_broken_prev = engine.broken.duplicate()
	_broken_seen = nb
	if engine.vstate == "fall" and not _splashed and engine.fall_pos.y < float(lv.water):
		_splashed = true
		_burst(_to_screen(Vector2(engine.fall_pos.x, float(lv.water))), "splash")
	board.queue_redraw()
	if result_shown:
		return
	if engine.status == "win":
		result_shown = true
		_on_crossed()
	elif engine.status == "fail":
		result_shown = true
		_on_failed()

func _on_crossed() -> void:
	if load_test:
		load_best = load_mult
		load_mult += LOAD_STEP
		var t := create_tween()
		t.tween_interval(0.6)
		t.tween_callback(_run_test)
		return
	SoundLib.play(self, "reward/accomplished")
	_sfx("win")
	_burst(_to_screen(Vector2(float(lv.w) + 1.0, float(lv.dh) + 1.0)), "confetti")
	var cost := E.design_cost(design)
	var stars := _stars_for(cost)
	var key := str(cur_level)
	var first := int(progress.stars.get(key, 0)) == 0
	if stars > int(progress.stars.get(key, 0)):
		progress.stars[key] = stars
	var best := int(progress.best.get(key, 0))
	if best == 0 or cost < best:
		progress.best[key] = cost
	progress.skipped.erase(key)
	_save_progress()
	if info:
		info.add("Bridges built")
		info.result("win")
		info.high("Highest level cleared", _cleared())
		info.high("Campaign stars", _total_stars())
		if stars == 3:
			info.add("Beat the engineer")
		info.celebrate(tr("It holds!"))
	var msg := tr("Cost: $%s of $%s") % [_money(cost), _money(int(lv.budget))]
	if int(lv.ref) > 0:
		msg += "\n" + tr("The engineer's bridge: $%s") % _money(int(lv.ref))
	if first:
		msg += "\n" + tr("Level %d opened.") % mini(cur_level + 1, E.LEVEL_COUNT)
	var t2 := create_tween()
	t2.tween_interval(1.2)
	t2.tween_callback(_show_win_card.bind(stars, msg))

## One-shot particles in screen space: "sparks" (a piece snaps), "splash" (into the river),
## "confetti" (across!). Fewer with Reduce effects on.
func _burst(at: Vector2, kind: String) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.position = at
	var few := LandingSlabs.reduced()
	match kind:
		"sparks":
			p.amount = 10 if few else 22
			p.lifetime = 0.6
			p.spread = 180.0
			p.initial_velocity_min = 120.0
			p.initial_velocity_max = 260.0
			p.gravity = Vector2(0, 600)
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = Color("ffcc66")
		"splash":
			p.amount = 16 if few else 40
			p.lifetime = 1.0
			p.direction = Vector2(0, -1)
			p.spread = 35.0
			p.initial_velocity_min = 220.0
			p.initial_velocity_max = 420.0
			p.gravity = Vector2(0, 900)
			p.scale_amount_min = 3.0
			p.scale_amount_max = 7.0
			p.color = Color(0.85, 0.95, 1.0, 0.9)
		_:
			p.amount = 30 if few else 90
			p.lifetime = 2.2
			p.direction = Vector2(-0.4, -1)
			p.spread = 60.0
			p.initial_velocity_min = 300.0
			p.initial_velocity_max = 620.0
			p.gravity = Vector2(0, 520)
			p.scale_amount_min = 4.0
			p.scale_amount_max = 8.0
			var g := Gradient.new()
			g.set_color(0, Color("ffd54f"))
			g.set_color(1, Color("29b6f6"))
			g.add_point(0.33, Color("ef5350"))
			g.add_point(0.66, Color("66bb6a"))
			p.color_initial_ramp = g
	fx_layer.add_child(p)
	p.emitting = true
	var t := Timer.new()
	t.wait_time = p.lifetime + 0.5
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(p.queue_free)
	p.add_child(t)

func _stars_for(cost: int) -> int:
	var budget := int(lv.budget)
	var ref := int(lv.ref) if int(lv.ref) > 0 else budget * 2 / 3
	if cost <= ref:
		return 3
	if cost <= (ref + budget) / 2:
		return 2
	return 1

func _on_failed() -> void:
	SoundLib.play(self, "impact/soft_heavy", -2.0)
	if load_test:
		var kg := _load_kg(load_best)
		if info and load_best > 0.0:
			info.high(BOARD, kg)
		var key := str(cur_level)
		if kg > int(progress.loads.get(key, 0)):
			progress.loads[key] = kg
			_save_progress()
		var msg := tr("Your bridge carried %s kg.") % _money(kg) if load_best > 0.0 else tr("It gave way under the first extra load.")
		msg += "\n" + tr("It broke at %s kg.") % _money(_load_kg(load_mult))
		var t := create_tween()
		t.tween_interval(1.2)
		t.tween_callback(_show_card.bind(tr("🏋 Load test"), "", msg, [
			{"text": tr("Next level"), "action": _start_level.bind(cur_level + 1)} if cur_level < E.LEVEL_COUNT else {"text": tr("📋 Levels"), "action": _open_map.bind(false)},
			{"text": tr("✏ Edit bridge"), "action": _stop_test},
			{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
		]))
		return
	var why: String = engine.reason
	if why == "":
		why = "The vehicle fell."
	var t2 := create_tween()
	t2.tween_interval(1.0)
	t2.tween_callback(_show_card.bind(tr("It fell!"), "", tr(why) + "\n" + tr("Red pieces were near breaking. Add triangles or stronger pieces."), [
		{"text": tr("✏ Fix the bridge"), "action": _stop_test},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	]))

func _show_win_card(stars: int, msg: String) -> void:
	var star_text := ""
	for i in 3:
		star_text += "★" if i < stars else "☆"
	var buttons: Array = []
	if cur_level < E.LEVEL_COUNT:
		buttons.append({"text": tr("Next level"), "action": _start_level.bind(cur_level + 1)})
	else:
		msg += "\n" + tr("All 300 levels built!")
	buttons.append({"text": tr("🏋 Load test"), "action": _start_load_test})
	if stars < 3:
		buttons.append({"text": tr("✏ Build cheaper"), "action": _stop_test})
	buttons.append({"text": tr("📋 Levels"), "action": _open_map.bind(false)})
	_show_card(tr("It holds!"), star_text, msg, buttons)

func _start_load_test() -> void:
	load_test = true
	load_best = 1.0  # the plain crossing already carried the vehicle
	load_mult = 1.0 + LOAD_STEP
	_run_test()

# ---------- helps: skip ----------

func _help_label() -> void:
	if home:
		home.refresh_helps()

func _on_skip() -> void:
	if home:
		home.try_help(_skip_now)

## ⏭ help: opens the next level and goes there (no stars for this one).
func _skip_now() -> bool:
	if not started or cur_level >= E.LEVEL_COUNT:
		return false
	var key := str(cur_level)
	if int(progress.stars.get(key, 0)) > 0 or progress.skipped.has(key):
		_start_level(cur_level + 1)  # already open: no help needed
		return false
	progress.skipped[key] = true
	_save_progress()
	_stop_test()
	_start_level(cur_level + 1)
	return true

# ---------- result card ----------

func _show_card(title_text: String, stars_text: String, msg: String, buttons: Array) -> void:
	_close_end()
	end_card = ColorRect.new()
	(end_card as ColorRect).color = Color(0, 0, 0, 0.6)
	end_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(end_card)
	end_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	end_card.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3a2414").darkened(0.15) if skin == "classic" else Color(0.05, 0.07, 0.16, 0.96)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = ACCENT
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if stars_text != "":
		var s := Label.new()
		s.text = stars_text
		s.add_theme_font_size_override("font_size", 60)
		s.add_theme_color_override("font_color", Color("ffd54f"))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
	var m := Label.new()
	m.text = msg
	m.add_theme_font_size_override("font_size", 24)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size = Vector2(520, 0)
	box.add_child(m)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var first := true
	for spec in buttons:
		var b := Button.new()
		b.text = spec.text
		b.custom_minimum_size = Vector2(255, 62)
		b.add_theme_font_size_override("font_size", 23)
		b.pressed.connect(_card_button.bind(spec.action))
		grid.add_child(b)
		if first:
			LandingSlabs.dress(b, "go")
		else:
			LandingSlabs.dress(b, "wood")
		first = false

func _card_button(action: Callable) -> void:
	if action.is_valid():
		action.call()

func _close_end() -> void:
	if end_card and is_instance_valid(end_card):
		end_card.queue_free()
	end_card = null

# ---------- progress and the level map ----------

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	progress = d if d is Dictionary else {}
	for k in ["stars", "best", "designs", "skipped", "loads"]:
		if not progress.get(k) is Dictionary:
			progress[k] = {}

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)

func _cleared() -> int:
	var n := 0
	for k in progress.stars:
		if int(progress.stars[k]) > 0:
			n = maxi(n, int(k))
	return n

func _total_stars() -> int:
	var n := 0
	for k in progress.stars:
		n += int(progress.stars[k])
	return n

## Sum over built levels of budget minus the cheapest bridge that crossed.
func _money_saved() -> int:
	var s := 0
	for k in progress.best:
		s += maxi(0, int(E.level(int(k)).budget) - int(progress.best[k]))
	return s

func _done(n: int) -> bool:
	return int(progress.stars.get(str(n), 0)) > 0 or progress.skipped.has(str(n))

func _next_level() -> int:
	for n in range(1, E.LEVEL_COUNT + 1):
		if not _done(n):
			return n
	return E.LEVEL_COUNT

func _unlocked(n: int) -> bool:
	return n <= 1 or _done(n - 1)

func _open_map_from_landing() -> void:
	_open_map(true)

func _open_map(from_landing: bool) -> void:
	_close_end()
	_close_map()
	if testing:
		_stop_test()
	map_from_landing = from_landing
	map_layer = ColorRect.new()
	(map_layer as ColorRect).color = Color(0.08, 0.06, 0.04, 0.98) if skin == "classic" else Color(0.03, 0.04, 0.1, 0.98)
	map_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	map_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(map_layer)
	map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_layer.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_drag = HomeKit._DragScroll.new()
	scroll.add_child(map_drag)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	box.add_child(bar)
	var home_btn := HomeKit.neon_button(tr("🏠 Home"), HomeKit.BUTTON, 24, 60)
	home_btn.custom_minimum_size.x = 170
	home_btn.pressed.connect(_map_home)
	bar.add_child(home_btn)
	if not from_landing:
		var back := HomeKit.neon_button(tr("‹ Back"), HomeKit.BUTTON, 24, 60)
		back.custom_minimum_size.x = 150
		back.pressed.connect(_map_back)
		bar.add_child(back)
	var heading := Label.new()
	heading.text = tr("Levels") + "   ★ %d / %d" % [_total_stars(), E.LEVEL_COUNT * 3]
	heading.add_theme_font_size_override("font_size", 32)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(heading)
	var scroll_to: Control = null
	var next := _next_level()
	for c in E.CHAPTERS.size():
		var name_label := Label.new()
		name_label.text = tr("Chapter %d") % (c + 1) + " · " + tr(E.CHAPTERS[c])
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.add_theme_color_override("font_color", ACCENT)
		box.add_child(name_label)
		var grid := GridContainer.new()
		grid.columns = 10
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		box.add_child(grid)
		for n in range(c * E.PER_CHAPTER + 1, (c + 1) * E.PER_CHAPTER + 1):
			var stars: int = int(progress.stars.get(str(n), 0))
			var open := _unlocked(n)
			var bt := Button.new()
			var mark := "★".repeat(stars) + "☆".repeat(3 - stars)
			if progress.skipped.has(str(n)) and stars == 0:
				mark = "⏭"
			bt.text = str(n) + "\n" + ("🔒" if not open else mark)
			bt.custom_minimum_size = Vector2(0, 80)
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bt.add_theme_font_size_override("font_size", 20)
			bt.disabled = not open
			if stars == 3:
				bt.add_theme_color_override("font_color", Color("ffd54f"))
			bt.pressed.connect(_map_pick.bind(n))
			grid.add_child(bt)
			if n == next:
				scroll_to = bt
	if scroll_to:
		scroll.call_deferred("ensure_control_visible", scroll_to)

func _map_pick(n: int) -> void:
	if map_drag and map_drag.moved:
		return
	if not _unlocked(n):
		return
	if map_from_landing:
		home.play_now(_start_level.bind(n))
	else:
		_start_level(n)

func _map_home() -> void:
	if map_drag and map_drag.moved:
		return
	var from_landing := map_from_landing
	_close_map()
	if not from_landing:
		_go_home()

func _map_back() -> void:
	if map_drag and map_drag.moved:
		return
	_close_map()

func _close_map() -> void:
	if map_layer and is_instance_valid(map_layer):
		map_layer.queue_free()
	map_layer = null
	map_drag = null

# ---------- drawing ----------

func _layout() -> void:
	if lv.is_empty() or board == null:
		return
	var x0 := -2.5
	var x1 := float(lv.w) + 2.5
	var y0 := float(lv.water) - 0.5
	var y1 := float(E.top_limit(lv)) + 0.4
	var area := Rect2(Vector2(10, TOP_BAR), board.size - Vector2(20, TOP_BAR + BOTTOM_BAR))
	var fit := minf(area.size.x / (x1 - x0), area.size.y / (y1 - y0))
	var span := Vector2((x1 - x0) * fit, (y1 - y0) * fit)
	var tl := area.position + (area.size - span) / 2.0
	_fit_vs = fit
	_fit_vo = Vector2(tl.x - x0 * fit, tl.y + y1 * fit)
	# A new level or a new screen size starts from the whole level.
	zoom = 1.0
	_clamp_view()

func _to_screen(p: Vector2) -> Vector2:
	return vo + Vector2(p.x, -p.y) * vs

func _to_world(s: Vector2) -> Vector2:
	return Vector2((s.x - vo.x) / vs, -(s.y - vo.y) / vs)

static func _make_disc() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * n / 2.0, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _disc_at(c: Vector2, r: float, col: Color) -> void:
	board.draw_texture_rect(_disc, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

func _draw_board() -> void:
	if lv.is_empty():
		return
	var classic := skin == "classic"
	var sz := board.size
	# Backdrop (cover) — the owner's canyon art; darker in Voodoo.
	var art: int = E.art_of(cur_level)
	var tex: Texture2D = _backdrops[art]
	if tex:
		var k := maxf(sz.x / tex.get_width(), sz.y / tex.get_height())
		var ts := Vector2(tex.get_width(), tex.get_height()) * k
		if E.flip_of(cur_level):
			board.draw_set_transform(Vector2(sz.x, 0), 0.0, Vector2(-1, 1))
		board.draw_texture_rect(tex, Rect2((sz - ts) / 2.0, ts), false, E.tint_of(cur_level) if classic else Color(0.25, 0.22, 0.4))
		board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		board.draw_rect(Rect2(Vector2.ZERO, sz), Color("8fc6e8") if classic else HomeKit.BG)
	var rock: Color = [Color("7a5a3c"), Color("b5582f"), Color("a24a26")][art] if classic else Color("0b0f1e")
	var top_col: Color = [Color("5f9e3a"), Color("e0b878"), Color("d9a560")][art] if classic else HomeKit.CYAN
	var w: float = lv.w
	var dh: float = lv.dh
	var bottom := sz.y + 10.0
	var wy := _to_screen(Vector2(0, float(lv.water))).y
	var l_edge := _to_screen(Vector2(0, 0))
	var r_edge := _to_screen(Vector2(w, dh))
	var set_name: String = CLIFF_SETS[art]
	if classic and _part("cliff_%s_l" % set_name) and _part("cliff_%s_r" % set_name):
		_draw_cliff("cliff_%s_l" % set_name, l_edge, false, wy)
		_draw_cliff("cliff_%s_r" % set_name, r_edge, true, wy)
		if lv.pier != null and _part("pier"):
			var pt0 := _to_screen(Vector2(float(lv.pier[0]), float(lv.pier[1])))
			var ptex := _part("pier")
			var pw0 := vs * 1.4
			var ptop := pt0.y - pw0 * 0.08
			board.draw_texture_rect(ptex, Rect2(Vector2(pt0.x - pw0 / 2.0, ptop), Vector2(pw0, wy + vs - ptop)), false)
		_draw_water(wy, bottom, classic)
	else:
		_draw_code_cliffs(classic, rock, top_col, l_edge, r_edge, bottom)
		_draw_water(wy, bottom, classic)
	_draw_grid_and_bridge(classic, w)

func _draw_code_cliffs(classic: bool, rock: Color, top_col: Color, l_edge: Vector2, r_edge: Vector2, bottom: float) -> void:
	var sz := board.size
	board.draw_colored_polygon(PackedVector2Array([Vector2(-10, l_edge.y), l_edge, Vector2(l_edge.x, bottom), Vector2(-10, bottom)]), rock)
	board.draw_colored_polygon(PackedVector2Array([r_edge, Vector2(sz.x + 10, r_edge.y), Vector2(sz.x + 10, bottom), Vector2(r_edge.x, bottom)]), rock)
	var lip := maxf(4.0, vs * 0.22)
	board.draw_rect(Rect2(Vector2(-10, l_edge.y - lip * 0.3), Vector2(l_edge.x + 10, lip)), top_col)
	board.draw_rect(Rect2(Vector2(r_edge.x, r_edge.y - lip * 0.3), Vector2(sz.x + 10 - r_edge.x, lip)), top_col)
	# Rock strata lines for texture.
	var strata := Color(0, 0, 0, 0.18) if classic else Color(HomeKit.CYAN, 0.15)
	for i in range(1, 12):
		var yy := l_edge.y + i * vs * 1.3
		board.draw_line(Vector2(0, yy), Vector2(l_edge.x - 2, yy + vs * 0.2), strata, 2.0)
		var yr := r_edge.y + i * vs * 1.3
		board.draw_line(Vector2(r_edge.x + 2, yr + vs * 0.2), Vector2(sz.x, yr), strata, 2.0)
	if not classic:
		board.draw_line(l_edge, Vector2(l_edge.x, bottom), HomeKit.CYAN, 2.0)
		board.draw_line(r_edge, Vector2(r_edge.x, bottom), HomeKit.CYAN, 2.0)
	# Pier.
	if lv.pier != null:
		var pt := _to_screen(Vector2(float(lv.pier[0]), float(lv.pier[1])))
		var pw := vs * 1.0
		board.draw_rect(Rect2(Vector2(pt.x - pw / 2.0, pt.y), Vector2(pw, bottom - pt.y)), rock)
		board.draw_rect(Rect2(Vector2(pt.x - pw / 2.0, pt.y - lip * 0.3), Vector2(pw, lip)), top_col)

## The river: the owner's wave strip along the waterline over deep blue (Classic).
func _draw_water(wy: float, bottom: float, classic: bool) -> void:
	var sz := board.size
	var wt := _part("water") if classic else null
	if wt:
		var sh := vs * 1.5
		var sw := sh * wt.get_width() / wt.get_height()
		var top := wy - sh * 0.2
		board.draw_rect(Rect2(Vector2(0, top + sh * 0.6), Vector2(sz.x, bottom - top)), Color("1d4f8c"))
		var x := -fmod(sw * 0.37, sw)
		while x < sz.x:
			board.draw_texture_rect(wt, Rect2(Vector2(x, top), Vector2(sw, sh)), false)
			x += sw - 1.0
		return
	board.draw_rect(Rect2(Vector2(0, wy), Vector2(sz.x, bottom - wy)), Color(0.15, 0.45, 0.7, 0.75) if classic else Color(0.1, 0.2, 0.5, 0.6))
	board.draw_line(Vector2(0, wy), Vector2(sz.x, wy), Color(1, 1, 1, 0.5), 2.0)

## One painted cliff: its ground line on the level's ground, its face on the gap's edge,
## tall enough to reach under the water; the far side is filled with a strip of it.
func _draw_cliff(name: String, edge: Vector2, right: bool, wy: float) -> void:
	var t := _part(name)
	var meta: Array = CLIFF_META[name]
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var k: float = maxf(1.0, wy + vs * 1.2 - edge.y) / ((1.0 - float(meta[0])) * th)
	var size := Vector2(tw, th) * k
	var pos := Vector2(edge.x - float(meta[1]) * size.x, edge.y - float(meta[0]) * size.y)
	board.draw_texture_rect(t, Rect2(pos, size), false)
	# Fill the rest of the screen with mirrored copies: the joins match pixel for pixel.
	var sz := board.size
	var x := pos.x
	var flip := true
	while (not right and x > 0.0) or (right and x + size.x < sz.x):
		x += -size.x if not right else size.x
		if flip:
			board.draw_set_transform(Vector2(x + size.x, pos.y), 0.0, Vector2(-1, 1))
			board.draw_texture_rect(t, Rect2(Vector2.ZERO, size), false)
			board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			board.draw_texture_rect(t, Rect2(Vector2(x, pos.y), size), false)
		flip = not flip

func _part(name: String) -> Texture2D:
	if not _parts.has(name):
		var path := PARTS_DIR + name + ".png"
		_parts[name] = load(path) if ResourceLoader.exists(path) else null
	return _parts[name]

func _draw_grid_and_bridge(classic: bool, w: float) -> void:
	# Build grid while editing.
	if not testing and grid_mode == "lines":
		var lc := Color(1, 1, 1, 0.22) if classic else Color(HomeKit.CYAN, 0.2)
		var lc5 := Color(1, 1, 1, 0.45) if classic else Color(HomeKit.CYAN, 0.42)
		var y_lo := int(lv.water) + 1
		var y_hi := E.top_limit(lv)
		var thin := PackedVector2Array()
		var thick := PackedVector2Array()
		for gx in range(-3, int(w) + 4):
			var arr := thick if gx % 5 == 0 else thin
			arr.append_array([_to_screen(Vector2(gx, y_lo)), _to_screen(Vector2(gx, y_hi))])
		for gy in range(y_lo, y_hi + 1):
			var arr2 := thick if gy % 5 == 0 else thin
			arr2.append_array([_to_screen(Vector2(-3, gy)), _to_screen(Vector2(w + 3, gy))])
		board.draw_multiline(thin, lc, maxf(1.0, vs * 0.025))
		board.draw_multiline(thick, lc5, maxf(1.5, vs * 0.04))
	if not testing and grid_mode == "dots":
		var gc := Color(1, 1, 1, 0.6) if classic else Color(HomeKit.CYAN, 0.5)
		var gs := maxf(3.0, vs * 0.09)
		for gx in range(-3, int(w) + 4):
			for gy in range(int(lv.water) + 1, E.top_limit(lv) + 1):
				if E.can_place(lv, gx, gy):
					var p := _to_screen(Vector2(gx, gy))
					board.draw_rect(Rect2(p - Vector2(gs, gs) / 2.0, Vector2(gs, gs)), gc)
	# Members.
	if testing:
		_draw_sim_members(classic)
	else:
		for m in design:
			_draw_member(_to_screen(Vector2(float(m[0]), float(m[1]))), _to_screen(Vector2(float(m[2]), float(m[3]))), str(m[4]), -1.0, classic)
		for j in _joints():
			_draw_bolt(_to_screen(Vector2(j)), E.is_anchor(lv, j.x, j.y), classic)
		if drag_on and drag_to != drag_from:
			var a := _to_screen(Vector2(drag_from))
			var b := _to_screen(Vector2(drag_to))
			_draw_member(a, b, mat, -1.0, classic, 0.6)
			var col := Color("76ff03") if drag_ok else Color("ff5252")
			_disc_at(b, vs * 0.2, col)
			var len_txt := "%.1f m  $%d" % [Vector2(drag_to - drag_from).length(), int(round(Vector2(drag_to - drag_from).length() * float(E.MATS[mat].cost)))]
			var font := get_theme_default_font()
			board.draw_string_outline(font, b + Vector2(12, -14), len_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color.BLACK)
			board.draw_string(font, b + Vector2(12, -14), len_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	# Vehicle (parked on the left cliff while editing).
	_draw_vehicle(classic)
	# Shade under the top and bottom bars so their text reads over the scene.
	var sz2 := board.size
	var dark := Color(0.03, 0.02, 0.01, 0.55)
	var clear := Color(0.03, 0.02, 0.01, 0.0)
	board.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sz2.x, 0), Vector2(sz2.x, TOP_BAR + 10), Vector2(0, TOP_BAR + 10)]), PackedColorArray([dark, dark, clear, clear]))
	board.draw_polygon(PackedVector2Array([Vector2(0, sz2.y - BOTTOM_BAR - 20), Vector2(sz2.x, sz2.y - BOTTOM_BAR - 20), Vector2(sz2.x, sz2.y), Vector2(0, sz2.y)]), PackedColorArray([clear, clear, dark, dark]))

func _draw_member(a: Vector2, b: Vector2, m: String, stress: float, classic: bool, alpha: float = 1.0) -> void:
	var t := _part(MAT_TEX[m]) if classic else null
	if t:
		var ln := a.distance_to(b)
		var th := maxf(4.0, vs * float(TEX_WIDTH[m]))
		var tint := Color(1, 1, 1, alpha)
		if stress >= 0.0:
			var st := clampf(stress, 0.0, 1.0)
			var sc2 := Color("66bb6a").lerp(Color("ffee58"), st * 2.0) if st < 0.5 else Color("ffee58").lerp(Color("ff1744"), (st - 0.5) * 2.0)
			tint = Color.WHITE.lerp(sc2, 0.35 + 0.5 * st)
			tint.a = alpha
		var src_w: float = minf(t.get_width(), t.get_width() * (ln / vs) / TEX_LEN)
		# Roads hang under the line (the vehicle drives on their top); the rest is centred.
		var y0 := -th * 0.15 if (m == "road" or m == "sroad") else -th * 0.5
		board.draw_set_transform(a, (b - a).angle(), Vector2.ONE)
		board.draw_texture_rect_region(t, Rect2(Vector2(0, y0), Vector2(ln, th)), Rect2(0, 0, src_w, t.get_height()), tint)
		board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var wpx: float = maxf(2.0, vs * float(MAT_WIDTH[m]))
	var col: Color = MAT_COLORS[m] if classic else MAT_NEON[m]
	if stress >= 0.0:
		var s := clampf(stress, 0.0, 1.0)
		var sc := Color("43a047").lerp(Color("fdd835"), s * 2.0) if s < 0.5 else Color("fdd835").lerp(Color("e53935"), (s - 0.5) * 2.0)
		col = col.lerp(sc, 0.75)
	col.a *= alpha
	if m == "road" or m == "sroad":
		board.draw_line(a, b, Color(0, 0, 0, 0.5 * alpha), wpx + 3.0)
		board.draw_line(a, b, col, wpx)
		var n := (b - a).normalized().orthogonal() * wpx * 0.32
		board.draw_line(a - n, b - n, Color(1, 1, 1, 0.25 * alpha), maxf(1.0, wpx * 0.15))
	elif m == "cable":
		board.draw_line(a, b, col, wpx)
	else:
		board.draw_line(a, b, Color(0, 0, 0, 0.45 * alpha), wpx + 2.0)
		board.draw_line(a, b, col, wpx)
		if m == "steel":
			board.draw_line(a, b, Color(1, 1, 1, 0.3 * alpha), maxf(1.0, wpx * 0.25))

func _draw_bolt(p: Vector2, anchor: bool, classic: bool) -> void:
	var r := maxf(4.0, vs * (0.17 if anchor else 0.12))
	var bt := _part("anchor" if anchor else "bolt") if classic else null
	if bt:
		var rr := r * 1.35
		board.draw_texture_rect(bt, Rect2(p - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false)
		return
	if classic:
		_disc_at(p, r + 2.0, Color(0, 0, 0, 0.55))
		_disc_at(p, r, Color("d32f2f") if anchor else Color("cfd8dc"))
	else:
		_disc_at(p, r + 3.0, Color(HomeKit.MAGENTA if anchor else HomeKit.CYAN, 0.35))
		_disc_at(p, r, HomeKit.MAGENTA if anchor else Color.WHITE)

func _draw_sim_members(classic: bool) -> void:
	for i in engine.ma.size():
		if engine.broken[i]:
			continue
		_draw_member(_to_screen(engine.pos[engine.ma[i]]), _to_screen(engine.pos[engine.mb[i]]), engine.mat_of[i], engine.stress(i), classic)
	for i in engine.pos.size():
		_draw_bolt(_to_screen(engine.pos[i]), engine.fixed[i] == 1, classic)

func _draw_vehicle(classic: bool) -> void:
	var vd: Dictionary = E.VEHICLES[lv.vehicle]
	var p: Vector2
	var ang := 0.0
	if testing:
		p = engine.vehicle_pos()
		ang = engine.vehicle_angle()
	else:
		p = Vector2(-1.0 - float(vd.base) * 0.5 - 0.3, 0.0)
	var base: float = vd.base
	var vt := _part("veh_" + str(lv.vehicle)) if classic else null
	if vt:
		var vm: Array = VEH_META[lv.vehicle]
		var px_w := float(vt.get_width())
		var k := base / ((float(vm[1]) - float(vm[0])) * px_w) * vs
		var vsize := Vector2(vt.get_width(), vt.get_height()) * k
		var mid := (float(vm[0]) + float(vm[1])) * 0.5
		var tint := Color.WHITE
		if load_test and testing:
			tint = Color.WHITE.lerp(Color("ff8a80"), clampf((load_mult - 1.0) / 3.0, 0.0, 0.8))
		board.draw_set_transform(_to_screen(p), -ang, Vector2.ONE)
		board.draw_texture_rect(vt, Rect2(Vector2(-mid * vsize.x, -vsize.y), vsize), false, tint)
		board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var ln: float = vd.len
	var ht: float = vd.h
	var wr := 0.32 if lv.vehicle == "car" else 0.42
	var col: Color = VEH_COLORS[lv.vehicle] if classic else HomeKit.LIME
	if load_test and testing:
		col = col.lerp(Color("ff1744"), clampf((load_mult - 1.0) / 3.0, 0.0, 1.0))
	var c := _to_screen(p)
	board.draw_set_transform(c, -ang, Vector2.ONE)
	var s := vs
	var body := Rect2(Vector2(-ln * 0.5, -(wr + ht * 0.95)) * s, Vector2(ln, ht * 0.75) * s)
	board.draw_rect(body.grow(2.0), Color(0, 0, 0, 0.6))
	board.draw_rect(body, col)
	match lv.vehicle:
		"car", "van":
			var cab := Rect2(Vector2(-ln * 0.25, -(wr + ht * 1.25)) * s, Vector2(ln * (0.55 if lv.vehicle == "car" else 0.75), ht * 0.35) * s)
			board.draw_rect(cab.grow(2.0), Color(0, 0, 0, 0.6))
			board.draw_rect(cab, col.darkened(0.15))
			board.draw_rect(Rect2(cab.position + Vector2(cab.size.x * 0.55, cab.size.y * 0.18), Vector2(cab.size.x * 0.38, cab.size.y * 0.7)), Color("b3e5fc"))
		"bus":
			for wi in 5:
				board.draw_rect(Rect2(Vector2(-ln * 0.42 + wi * ln * 0.17, -(wr + ht * 0.88)) * s, Vector2(ln * 0.12, ht * 0.25) * s), Color("b3e5fc"))
		_:
			var cab2 := Rect2(Vector2(ln * 0.2, -(wr + ht * 1.15)) * s, Vector2(ln * 0.3, ht * 0.95) * s)
			board.draw_rect(cab2.grow(2.0), Color(0, 0, 0, 0.6))
			board.draw_rect(cab2, col.darkened(0.25))
			board.draw_rect(Rect2(cab2.position + Vector2(cab2.size.x * 0.45, cab2.size.y * 0.12), Vector2(cab2.size.x * 0.45, cab2.size.y * 0.35)), Color("b3e5fc"))
			board.draw_rect(Rect2(Vector2(-ln * 0.5, -(wr + ht * 0.95)) * s, Vector2(ln * 0.68, ht * 0.75) * s), col.lightened(0.15))
	for wx in [-base * 0.5, base * 0.5]:
		var wc := Vector2(wx, -wr) * s
		_disc_at(wc, wr * s, Color("212121"))
		_disc_at(wc, wr * s * 0.45, Color("9e9e9e"))
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 4.0, 40.0)
	var o := Vector2(c.size.x / 2.0, c.size.y / 2.0 + k)
	var col := ACCENT
	var pts := []
	for i in 5:
		pts.append(o + Vector2((i - 2) * k * 1.2, 0))
	for i in 4:
		HomeKit.glow_line(c, pts[i], pts[i + 1], col, maxf(3.0, k * 0.16))
		var top: Vector2 = (pts[i] + pts[i + 1]) / 2.0 - Vector2(0, k * 1.1)
		HomeKit.glow_line(c, pts[i], top, HomeKit.CYAN, maxf(2.0, k * 0.08))
		HomeKit.glow_line(c, pts[i + 1], top, HomeKit.CYAN, maxf(2.0, k * 0.08))
		if i < 3:
			HomeKit.glow_line(c, top, top + Vector2(k * 1.2, 0), HomeKit.CYAN, maxf(2.0, k * 0.08))

## Look (STANDARDS §9): "classic" = the owner's painted canyons, wood and steel
## colours (default); "voodoo" = the canyon dimmed to night, neon pieces.
func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if home and home.get("_style") != null and home._style.has_method("set_voodoo"):
		home._style.set_voodoo(skin == "voodoo")
	if board:
		board.queue_redraw()

func _current_skin() -> String:
	return skin

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	_stop_test()
	home.go_home()

## The bridge itself lives in the progress file (per level); the save only says
## which level was on.
func _save_game() -> void:
	if not started:
		return
	SaveUtil.write(SAVE_PATH, {"level": cur_level})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary or not d.has("level"):
		return ""
	return tr("Level %d") % int(d.level)

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary or not d.has("level"):
		_start_campaign()
		return
	_start_level(int(d.level))

# ---------- sound and music ----------

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

## Music from the hub's shared library (apps before v0.33 play none).
func _play_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, -1, 2.0)
