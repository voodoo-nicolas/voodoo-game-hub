extends Control

## Frog Crossing -- swipe (or use the arrows) to hop.

const FCEngine = preload("res://scripts/games/frog_crossing/frog_crossing_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")

const BEST_PATH := "user://frog_crossing_best.json"
const CAR_COLORS := [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 1), Color(1, 0.8, 0.2), Color(0.8, 0.4, 1), Color(1, 0.55, 0.2)]

var engine: FCEngine
var board: Control
var info_label: Label
var start_dialog: ColorRect
var over_dialog: ColorRect
var pause_dialog: ColorRect
var running := false
var best: int = 0
var swipe_start := Vector2.ZERO

func _ready() -> void:
	preload("res://scripts/games/frog_crossing/frog_crossing_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = FCEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	_build_ui()
	engine.reset()
	_update_info()
	start_dialog.visible = true

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🐸 Frog Crossing")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 25)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.clip_contents = true
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	root.add_child(board)

	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 8)
	pad.add_theme_constant_override("v_separation", 4)
	var pc := CenterContainer.new()
	pc.add_child(pad)
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_bottom", 24)
	pm.add_child(pc)
	root.add_child(pm)
	var arrows := {1: ["▲", Vector2i(0, -1)], 3: ["◀", Vector2i(-1, 0)], 5: ["▶", Vector2i(1, 0)], 7: ["▼", Vector2i(0, 1)]}
	for i in 9:
		if arrows.has(i):
			var b := Button.new()
			b.text = arrows[i][0]
			b.custom_minimum_size = Vector2(120, 64)
			b.add_theme_font_size_override("font_size", 30)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_hop.bind(arrows[i][1]))
			pad.add_child(b)
		else:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(120, 64 if i < 3 or i > 5 else 64)
			pad.add_child(gap)

	start_dialog = UI.build_dialog(tr("🐸 Frog Crossing"), [
		{"text": tr("Start"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	start_dialog.get_meta("message_label").text = tr("Swipe to hop. Dodge the cars, ride the logs, and fill all five homes!")
	add_child(start_dialog)
	over_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(over_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("Exit to Hub"), "action": UI.exit_to_hub.bind(self)},
	])
	add_child(pause_dialog)
	add_child(SettingsDrawer.new())

func _start() -> void:
	engine.reset()
	over_dialog.visible = false
	running = true

func _resume() -> void:
	running = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running:
			running = false
			pause_dialog.visible = true

func _hop(d: Vector2i) -> void:
	if running:
		engine.hop(d)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_UP: _hop(Vector2i(0, -1))
		KEY_DOWN: _hop(Vector2i(0, 1))
		KEY_LEFT: _hop(Vector2i(-1, 0))
		KEY_RIGHT: _hop(Vector2i(1, 0))

func _update_info() -> void:
	info_label.text = tr("Level %d   Score: %d   Lives: %s   Best: %d") % [engine.level, engine.score, "♥".repeat(max(0, engine.lives)), best]

func _process(delta: float) -> void:
	if running:
		engine.step(min(delta, 0.05))
		if engine.over:
			running = false
			if engine.score > best:
				best = engine.score
				SaveUtil.write(BEST_PATH, {"best": best})
			over_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score + "\n" + tr("Best: %d") % best
			over_dialog.visible = true
	_update_info()
	board.queue_redraw()

# ---------- drawing ----------

func _cell() -> float:
	return floor(min(board.size.x / FCEngine.COLS, board.size.y / (FCEngine.ROWS + 0.6)))

func _origin() -> Vector2:
	var c := _cell()
	return Vector2((board.size.x - c * FCEngine.COLS) / 2.0, (board.size.y - c * (FCEngine.ROWS + 0.6)) / 2.0 + c * 0.6)

func _draw_board() -> void:
	if engine.lanes.is_empty():
		return
	var c := _cell()
	var o := _origin()
	var width := c * FCEngine.COLS
	var span := float(FCEngine.COLS + 4)
	# time bar
	board.draw_rect(Rect2(o + Vector2(0, -c * 0.45), Vector2(width * engine.time_left / FCEngine.LIFE_TIME, c * 0.25)),
		Color(0.4, 0.9, 0.4) if engine.time_left > 8.0 else Color(1, 0.4, 0.3))
	for r in FCEngine.ROWS:
		var y := o.y + r * c
		var lane: Dictionary = engine.lanes[r]
		var col := Color(0.25, 0.55, 0.25)
		if lane.kind == "river":
			col = Color(0.15, 0.35, 0.7)
		elif lane.kind == "road":
			col = Color(0.2, 0.2, 0.23)
		elif r == 0:
			col = Color(0.1, 0.3, 0.12)
		board.draw_rect(Rect2(o.x, y, width, c), col)
		if lane.kind == "road" and r < 11:
			var x := 0.0
			while x < width:
				board.draw_rect(Rect2(o.x + x, y + c - 2, c * 0.4, 3), Color(1, 1, 1, 0.3))
				x += c
		for i in lane.objects.size():
			var obj: Dictionary = lane.objects[i]
			var ox := FCEngine.object_x(obj)
			for shift in [-span, 0.0, span]:
				var full := Rect2(o.x + (ox + shift) * c, y + c * 0.12, obj.len * c, c * 0.76)
				# only the part inside the playfield
				var rect := full.intersection(Rect2(o.x, y, width, c))
				if rect.size.x <= 1.0:
					continue
				if lane.kind == "river":
					var sb := StyleBoxFlat.new()
					sb.bg_color = Color(0.55, 0.35, 0.18)
					sb.set_corner_radius_all(int(c * 0.3))
					board.draw_style_box(sb, rect)
				else:
					var sb := StyleBoxFlat.new()
					sb.bg_color = CAR_COLORS[(r + i) % CAR_COLORS.size()]
					sb.set_corner_radius_all(int(c * 0.18))
					board.draw_style_box(sb, rect.grow(-c * 0.04))
					var front: float = full.end.x - c * 0.25 if lane.speed > 0 else full.position.x + c * 0.1
					if front < rect.position.x or front + c * 0.15 > rect.end.x:
						continue
					board.draw_rect(Rect2(front, rect.position.y + c * 0.12, c * 0.15, rect.size.y - c * 0.24), Color(0.8, 0.95, 1, 0.8))
	# homes
	for k in FCEngine.HOMES.size():
		var hx: float = o.x + FCEngine.HOMES[k] * c
		board.draw_rect(Rect2(hx + 3, o.y + 3, c - 6, c - 6), Color(0.15, 0.35, 0.7))
		if engine.homes[k]:
			_draw_frog(Vector2(hx + c / 2.0, o.y + c / 2.0), c * 0.8)
	if not engine.over:
		var alpha := 1.0 if engine.death_flash <= 0.0 else 0.4
		_draw_frog(o + (engine.frog + Vector2(0.5, 0.5)) * c, c * 0.8, alpha)

func _draw_frog(center: Vector2, size: float, alpha: float = 1.0) -> void:
	var green := Color(0.35, 0.9, 0.35, alpha)
	board.draw_circle(center, size * 0.38, green)
	for sx in [-1, 1]:
		board.draw_circle(center + Vector2(sx * size * 0.36, size * 0.3), size * 0.13, green)
		board.draw_circle(center + Vector2(sx * size * 0.36, -size * 0.2), size * 0.12, green)
		board.draw_circle(center + Vector2(sx * size * 0.16, -size * 0.32), size * 0.12, Color(1, 1, 1, alpha))
		board.draw_circle(center + Vector2(sx * size * 0.16, -size * 0.34), size * 0.06, Color(0, 0, 0, alpha))

func _on_board_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			swipe_start = event.position
		else:
			var d: Vector2 = event.position - swipe_start
			if d.length() < 20.0:
				_hop(Vector2i(0, -1))   # a plain tap hops forward
			elif abs(d.x) > abs(d.y):
				_hop(Vector2i(1 if d.x > 0 else -1, 0))
			else:
				_hop(Vector2i(0, 1 if d.y > 0 else -1))
