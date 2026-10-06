extends Control

## Frog Crossing -- swipe (or use the arrows) to hop.

const FCEngine = preload("res://scripts/games/frog_crossing/frog_crossing_engine.gd")
const HomeKit = preload("res://scripts/games/frog_crossing/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://frog_crossing_best.json"
const CAR_COLORS := [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 1), Color(1, 0.8, 0.2), Color(0.8, 0.4, 1), Color(1, 0.55, 0.2)]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
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

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
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
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🐸 Road Hopper")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
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
			b.set_meta("sfx", "")  # a hop plays "jump"
			b.pressed.connect(_hop.bind(arrows[i][1]))
			pad.add_child(b)
		else:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(120, 64 if i < 3 or i > 5 else 64)
			pad.add_child(gap)

	start_dialog = UI.build_dialog(tr("🐸 Road Hopper"), [
		{"text": tr("Start"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	start_dialog.get_meta("message_label").text = tr("Swipe to hop. Dodge the cars, ride the logs, and land on all five glowing lily pads at the top!")
	add_child(start_dialog)
	over_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(over_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	])
	add_child(pause_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/frog_crossing/frog_crossing_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best > 0:
			info.high("Best score", best)
	add_child(SettingsDrawer.new())

func _start() -> void:
	engine.reset()
	over_dialog.visible = false
	running = true

func _resume() -> void:
	running = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running and home:
			home.pause()

func _hop(d: Vector2i) -> void:
	if running:
		_sfx("jump")
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
		var pre := [engine.lives, engine.level]
		engine.step(min(delta, 0.05))
		if engine.lives < pre[0]:
			_sfx("hit")
		elif engine.level > pre[1]:
			_sfx("powerup")
		if engine.over:
			running = false
			if engine.score > best:
				best = engine.score
				SaveUtil.write(BEST_PATH, {"best": best})
			if info:
				info.add("Games played")
				info.best("Best score", best)
				info.high("Highest level", engine.level)
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
	var t := Time.get_ticks_msec() / 1000.0
	var field := Rect2(o.x, o.y, width, c * FCEngine.ROWS)
	for r in FCEngine.ROWS:
		var y := o.y + r * c
		var lane: Dictionary = engine.lanes[r]
		var row_rect := Rect2(o.x, y, width, c)
		if r == 0:
			_draw_hedge(row_rect, c)
		elif lane.kind == "river":
			_draw_water(row_rect, c, t, lane.speed)
		elif lane.kind == "road":
			board.draw_rect(row_rect, Color(0.04, 0.04, 0.08))
			if r < 11:  # dashed line between this road lane and the next
				var x := 0.0
				while x < width:
					board.draw_rect(Rect2(o.x + x + c * 0.3, y + c - 2, c * 0.45, 4), Color(HomeKit.MAGENTA, 0.6))
					x += c
		else:
			_draw_grass(row_rect, c, r)
		for i in lane.objects.size():
			var obj: Dictionary = lane.objects[i]
			var ox := FCEngine.object_x(obj)
			for shift in [-span, 0.0, span]:
				var full := Rect2(o.x + (ox + shift) * c, y + c * 0.12, obj.len * c, c * 0.76)
				if full.intersection(row_rect).size.x <= 1.0:
					continue
				if lane.kind == "river":
					_draw_log(full, c)
				else:
					_draw_car(full, c, CAR_COLORS[(r + i) % CAR_COLORS.size()], lane.speed > 0)
	# Cars and logs wrap around; cover what's drawn past the sides.
	board.draw_rect(Rect2(0, field.position.y, field.position.x, field.size.y), HomeKit.BG)
	board.draw_rect(Rect2(field.end.x, field.position.y, board.size.x - field.end.x, field.size.y), HomeKit.BG)
	# homes: lily pads in gaps of the hedge, pulsing gold while still empty
	for k in FCEngine.HOMES.size():
		var hc := Vector2(o.x + (FCEngine.HOMES[k] + 0.5) * c, o.y + c * 0.5)
		if engine.homes[k]:
			_draw_lily_pad(hc, c, 0.0)
			_draw_frog(hc, c * 0.8)
		else:
			_draw_lily_pad(hc, c, 0.5 + 0.5 * sin(t * 4.0 + k))
	if not engine.over:
		var alpha := 1.0 if engine.death_flash <= 0.0 else 0.4
		_draw_frog(o + (engine.frog + Vector2(0.5, 0.5)) * c, c * 0.8, alpha)

## The goal row: a dark band edged in purple, with a nook at each home.
func _draw_hedge(row: Rect2, c: float) -> void:
	board.draw_rect(row, Color(0.06, 0.03, 0.12))
	HomeKit.glow_line(board, Vector2(row.position.x, row.end.y - 1), Vector2(row.end.x, row.end.y - 1), HomeKit.PURPLE, 2.0)
	for hx in FCEngine.HOMES:
		var nook := Rect2(row.position.x + hx * c + c * 0.06, row.position.y + c * 0.1, c * 0.88, c * 0.9)
		board.draw_rect(nook, Color(0.03, 0.08, 0.2))
		HomeKit.glow_rect(board, nook, HomeKit.BLUE, 1.5)

## A neon lily pad; `glow` (0..1) rings it in gold to say "jump in here".
func _draw_lily_pad(center: Vector2, c: float, glow: float) -> void:
	var r := c * 0.36
	if glow > 0.0:
		board.draw_arc(center, r + c * 0.07, 0, TAU, 32, Color(HomeKit.GOLD, 0.3 + 0.6 * glow), c * 0.06, true)
	var pad := PackedVector2Array()
	for i in 29:  # a circle missing a wedge
		var a := deg_to_rad(20.0 + i * 11.4)
		pad.append(center + Vector2(cos(a), sin(a)) * r)
	pad.append(center)
	board.draw_colored_polygon(pad, Color(HomeKit.LIME, 0.2))
	HomeKit.glow_polyline(board, pad, HomeKit.LIME, maxf(1.5, c * 0.03), true)
	board.draw_circle(center + Vector2(-r * 0.35, -r * 0.35), c * 0.07, HomeKit.PINK)

## Deep water with cyan ripples drifting the way the current flows.
func _draw_water(row: Rect2, c: float, t: float, speed: float) -> void:
	board.draw_rect(row, Color(0.02, 0.07, 0.18))
	var drift := fmod(t * speed * 0.6, 1.0)
	for j in 2:
		var y := row.position.y + c * (0.3 + 0.4 * j)
		var x := row.position.x + (drift + 0.5 * j) * c - c
		while x < row.end.x:
			board.draw_line(Vector2(x, y), Vector2(x + c * 0.35, y), Color(HomeKit.CYAN, 0.35), maxf(1.0, c * 0.04))
			x += c * 1.3

## The safe banks: dark ground with faint lime tufts.
func _draw_grass(row: Rect2, c: float, r: int) -> void:
	board.draw_rect(row, Color(0.03, 0.09, 0.06))
	for i in int(row.size.x / c):
		var k := (i * 7 + r * 13) % 5
		var p := Vector2(row.position.x + (i + 0.2 + k * 0.12) * c, row.position.y + c * (0.3 + 0.1 * (k % 3)))
		for dx in [-1.0, 0.0, 1.0]:
			board.draw_line(p + Vector2(dx * c * 0.05, c * 0.12), p + Vector2(dx * c * 0.09, -c * 0.02), Color(HomeKit.LIME, 0.3), maxf(1.0, c * 0.035))

func _draw_log(rect: Rect2, c: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(HomeKit.GOLD, 0.18)
	sb.set_corner_radius_all(int(c * 0.3))
	sb.border_color = HomeKit.GOLD
	sb.set_border_width_all(maxi(2, int(c * 0.05)))
	sb.shadow_color = Color(HomeKit.GOLD, 0.3)
	sb.shadow_size = int(c * 0.12)
	board.draw_style_box(sb, rect)
	var y1 := rect.position.y + rect.size.y * 0.5
	var x := rect.position.x + c * 0.4
	while x < rect.end.x - c * 0.5:  # grain
		board.draw_line(Vector2(x, y1), Vector2(x + c * 0.4, y1), Color(HomeKit.GOLD, 0.45), maxf(1.0, c * 0.03))
		x += c * 0.9

## Car (1 cell) or truck (longer): a glowing outline in the car's colour,
## a windshield and headlights at the front (the way it drives).
func _draw_car(full: Rect2, c: float, color: Color, right: bool) -> void:
	var body := full.grow(-c * 0.06)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.22)
	sb.set_corner_radius_all(int(c * 0.18))
	sb.border_color = color
	sb.set_border_width_all(maxi(2, int(c * 0.05)))
	sb.shadow_color = Color(color, 0.35)
	sb.shadow_size = int(c * 0.12)
	board.draw_style_box(sb, body)
	var dir := 1.0 if right else -1.0
	var front_x: float = body.end.x if right else body.position.x
	var glass_x: float = front_x - dir * c * 0.42 - (c * 0.18 if right else 0.0)
	board.draw_rect(Rect2(glass_x, body.position.y + body.size.y * 0.2, c * 0.16, body.size.y * 0.6), Color(color.lightened(0.5), 0.8))
	var hl_x: float = front_x - (c * 0.08 if right else 0.0)
	for hy in [body.position.y + body.size.y * 0.15, body.end.y - body.size.y * 0.15 - c * 0.08]:
		board.draw_rect(Rect2(hl_x, hy, c * 0.08, c * 0.08), Color.WHITE)

func _draw_frog(center: Vector2, size: float, alpha: float = 1.0) -> void:
	var green := Color(HomeKit.LIME, alpha)
	for sx in [-1, 1]:
		board.draw_circle(center + Vector2(sx * size * 0.36, size * 0.3), size * 0.12, Color(green, alpha * 0.6))
		board.draw_circle(center + Vector2(sx * size * 0.36, -size * 0.2), size * 0.11, Color(green, alpha * 0.6))
	HomeKit.glow_circle(board, center, size * 0.36, green, maxf(2.0, size * 0.05), 0.35 * alpha)
	for sx in [-1, 1]:
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

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/frog_crossing/frog_crossing_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/frog_crossing/frog_crossing_help.gd"),
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Hop across the road and the river into all five homes.",
		"logo": _draw_home_logo,
		"modes": [{"text": "🐸  Play", "sub": "Three lives", "action": _start}],
		"restart": _start,
		"board_note": "Your best score.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var w := h * 1.5
	var o := Vector2((c.size.x - w) / 2.0, (c.size.y - h) / 2.0)
	# road lanes, a river, and the frog
	for i in 3:
		c.draw_line(o + Vector2(0, h * (0.25 + i * 0.25)), o + Vector2(w, h * (0.25 + i * 0.25)), Color(HomeKit.BLUE, 0.4), 1.5)
	HomeKit.glow_rect(c, Rect2(o + Vector2(w * 0.1, h * 0.04), Vector2(w * 0.45, h * 0.16)), HomeKit.GOLD, 2.0, 0.2)
	HomeKit.glow_rect(c, Rect2(o + Vector2(w * 0.55, h * 0.54), Vector2(w * 0.3, h * 0.17)), HomeKit.PINK, 2.0, 0.2)
	HomeKit.glow_rect(c, Rect2(o + Vector2(w * 0.05, h * 0.3), Vector2(w * 0.25, h * 0.16)), HomeKit.CYAN, 2.0, 0.2)
	var f := o + Vector2(w * 0.5, h * 0.88)
	HomeKit.glow_circle(c, f, h * 0.09, HomeKit.LIME, 2.5, 0.4)
	c.draw_circle(f + Vector2(-h * 0.04, -h * 0.07), h * 0.03, Color.WHITE)
	c.draw_circle(f + Vector2(h * 0.04, -h * 0.07), h * 0.03, Color.WHITE)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
