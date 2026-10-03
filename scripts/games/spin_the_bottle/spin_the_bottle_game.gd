extends Control

## Spin the Bottle -- drag the bottle round and let go (or tap Spin); it
## slows down and points at one of the seats around it.

const SBEngine = preload("res://scripts/games/spin_the_bottle/spin_the_bottle_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SEAT_COLORS := [Color(1, 0.4, 0.45), Color(0.4, 0.75, 1), Color(1, 0.8, 0.3), Color(0.5, 0.95, 0.5),
	Color(0.85, 0.55, 1), Color(1, 0.6, 0.3)]

var info = null  # GameInfo; null on apps without it, so guard every use
var engine: SBEngine
var board: Control
var result_label: Label
var players_label: Label
var spin_btn: Button
var dragging := false
var drag_angle := 0.0     # pointer angle around the centre last frame
var drag_speed := 0.0     # smoothed rad/s while dragging
var winner := -1
var glow := 0.0           # pulse on the chosen seat

func _ready() -> void:
	preload("res://scripts/games/spin_the_bottle/spin_the_bottle_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = SBEngine.new()
	_build_ui()
	_update_players()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.07, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
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
	title.text = tr("🍾 Spin the Bottle")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	bar.add_child(spacer)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 40)
	result_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.custom_minimum_size = Vector2(0, 70)
	root.add_child(result_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	root.add_child(board)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_theme_constant_override("margin_left", 24)
	bm.add_theme_constant_override("margin_right", 24)
	root.add_child(bm)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	bm.add_child(bottom)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	bottom.add_child(row)
	var minus := Button.new()
	minus.text = "－"
	minus.custom_minimum_size = Vector2(70, 64)
	minus.add_theme_font_size_override("font_size", 32)
	minus.pressed.connect(_change_players.bind(-1))
	row.add_child(minus)
	players_label = Label.new()
	players_label.add_theme_font_size_override("font_size", 28)
	players_label.custom_minimum_size = Vector2(220, 0)
	players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(players_label)
	var plus := Button.new()
	plus.text = "＋"
	plus.custom_minimum_size = Vector2(70, 64)
	plus.add_theme_font_size_override("font_size", 32)
	plus.pressed.connect(_change_players.bind(1))
	row.add_child(plus)
	spin_btn = Button.new()
	spin_btn.text = tr("🍾 Spin!")
	spin_btn.custom_minimum_size = Vector2(0, 90)
	spin_btn.add_theme_font_size_override("font_size", 32)
	spin_btn.pressed.connect(_on_spin)
	spin_btn.set_meta("sfx", "")  # the spin whooshes (_started) instead of a tap
	bottom.add_child(spin_btn)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/spin_the_bottle/spin_the_bottle_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _change_players(d: int) -> void:
	if engine.spinning:
		return
	engine.set_players(engine.players + d)
	winner = -1
	_update_players()

func _update_players() -> void:
	players_label.text = tr("%d players") % engine.players
	result_label.text = tr("Drag the bottle or tap Spin!")
	board.queue_redraw()

func _on_spin() -> void:
	if engine.spinning:
		return
	engine.spin_random()
	_started()

func _started() -> void:
	winner = -1
	result_label.text = tr("Spinning…")
	_sfx("whoosh")
	if info:
		info.add("Spins")

func _process(delta: float) -> void:
	var before := engine.angle
	if engine.step(delta):
		winner = engine.chosen()
		result_label.text = tr("Player %d!") % (winner + 1)
		_sfx("notify")
	elif engine.spinning:
		_tick_past_seats(before, engine.angle)
	if winner >= 0:
		glow += delta
	if engine.spinning or dragging or winner >= 0:
		board.queue_redraw()

## A click each time the neck swings past a seat, like a prize wheel.
func _tick_past_seats(a: float, b: float) -> void:
	var step := TAU / engine.players
	# Seats sit at -PI/2 + i*step; tick when the neck crosses one.
	if floori(fposmod(a + PI / 2.0, TAU) / step) != floori(fposmod(b + PI / 2.0, TAU) / step):
		_sfx("spin_tick")

## Plays a sound from the app's library (silent on apps from before v0.23).
func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

# ---------- input: grab the bottle and fling it ----------

func _center() -> Vector2:
	return board.size / 2.0

func _pointer_angle(pos: Vector2) -> float:
	return (pos - _center()).angle()

func _on_board_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and dragging:
		var a := _pointer_angle(event.position)
		var d := angle_difference(drag_angle, a)
		engine.angle = wrapf(engine.angle + d, -PI, PI)
		var dt: float = maxf(get_process_delta_time(), 0.001)
		drag_speed = lerpf(drag_speed, d / dt, 0.5)
		drag_angle = a
		return
	if pressed and not engine.spinning:
		dragging = true
		drag_angle = _pointer_angle(pos)
		drag_speed = 0.0
		winner = -1
	elif released and dragging:
		dragging = false
		if absf(drag_speed) > 3.0:
			engine.spin(drag_speed * 1.2)
			_started()
		elif (pos - _center()).length() < _radius() * 0.4:
			_on_spin()  # a plain tap on the bottle spins it too

# ---------- drawing ----------

func _radius() -> float:
	return minf(board.size.x, board.size.y) * 0.42

func _draw_board() -> void:
	var c := _center()
	var r := _radius()
	var font: Font = ThemeDB.fallback_font
	board.draw_circle(c, r * 1.08, Color(0.2, 0.12, 0.22))
	board.draw_arc(c, r * 1.08, 0, TAU, 96, Color(1, 1, 1, 0.12), 4)
	for i in engine.players:
		var a := engine.seat_angle(i)
		var p := c + Vector2.from_angle(a) * r
		var col: Color = SEAT_COLORS[i % SEAT_COLORS.size()]
		var rad := r * 0.15
		if i == winner:
			rad *= 1.25 + 0.08 * sin(glow * 8.0)
			board.draw_circle(p, rad * 1.35, Color(col, 0.35))
		board.draw_circle(p, rad, col)
		board.draw_string(font, p + Vector2(-rad, rad * 0.35), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, int(rad * 1.1), Color(0.1, 0.05, 0.1))
	_draw_bottle(c, engine.angle, r * 0.62)

## A green glass bottle; its neck points along `a`.
func _draw_bottle(c: Vector2, a: float, length: float) -> void:
	board.draw_set_transform(c, a, Vector2.ONE)
	var w := length * 0.3
	var body := Rect2(Vector2(-length * 0.5, -w / 2.0), Vector2(length * 0.62, w))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.55, 0.3, 0.95)
	sb.set_corner_radius_all(int(w * 0.35))
	board.draw_style_box(sb, body)
	# shoulder and neck
	board.draw_colored_polygon(PackedVector2Array([
		Vector2(length * 0.1, -w / 2.0), Vector2(length * 0.28, -w * 0.17),
		Vector2(length * 0.28, w * 0.17), Vector2(length * 0.1, w / 2.0)]), Color(0.15, 0.55, 0.3, 0.95))
	board.draw_rect(Rect2(Vector2(length * 0.27, -w * 0.17), Vector2(length * 0.2, w * 0.34)), Color(0.15, 0.55, 0.3, 0.95))
	board.draw_rect(Rect2(Vector2(length * 0.45, -w * 0.2), Vector2(length * 0.06, w * 0.4)), Color(0.85, 0.7, 0.3))
	# label and shine
	board.draw_rect(Rect2(Vector2(-length * 0.32, -w / 2.0), Vector2(length * 0.24, w)), Color(0.95, 0.9, 0.75, 0.9))
	board.draw_rect(Rect2(Vector2(-length * 0.45, -w * 0.38), Vector2(length * 0.5, w * 0.1)), Color(1, 1, 1, 0.3))
	board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
