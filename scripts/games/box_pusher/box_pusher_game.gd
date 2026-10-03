extends Control

## Box Pusher -- swipe on the board (or use the arrows) to walk; push every
## box onto a goal. Levels unlock one after another; progress is saved.

const BoxEngine = preload("res://scripts/games/box_pusher/box_pusher_engine.gd")
const HomeKit = preload("res://scripts/games/box_pusher/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://box_pusher.json"
const COLOR_WALL := Color(0.45, 0.25, 0.85)
const COLOR_FLOOR := Color(0.05, 0.07, 0.14)
const COLOR_GOAL := Color("ff2bd6")
const COLOR_BOX := Color("ffae2b")
const COLOR_BOX_DONE := Color("7dff3a")
const COLOR_PLAYER := Color("29e6ff")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: BoxEngine
var board: Control
var level_label: Label
var stats_label: Label
var prev_btn: Button
var next_btn: Button
var win_dialog: ColorRect
var level: int = 1
var unlocked: int = 1
var swipe_start := Vector2.ZERO
var swiping := false

func _ready() -> void:
	preload("res://scripts/games/box_pusher/box_pusher_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BoxEngine.new()
	var data = SaveUtil.read(SAVE_PATH)
	if data != null:
		unlocked = max(1, int(data.get("unlocked", 1)))
		level = clampi(int(data.get("level", unlocked)), 1, unlocked)
	_build_ui()
	_load_level(level)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
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
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("📦 Box Pusher")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_on_restart)
	bar.add_child(restart_btn)

	var level_row := HBoxContainer.new()
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	level_row.add_theme_constant_override("separation", 20)
	root.add_child(level_row)
	prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(70, 56)
	prev_btn.add_theme_font_size_override("font_size", 28)
	prev_btn.pressed.connect(_change_level.bind(-1))
	level_row.add_child(prev_btn)
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 30)
	level_row.add_child(level_label)
	next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(70, 56)
	next_btn.add_theme_font_size_override("font_size", 28)
	next_btn.pressed.connect(_change_level.bind(1))
	level_row.add_child(next_btn)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 24)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(stats_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 24)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 30)
	cm.add_child(controls)
	root.add_child(cm)
	var undo_btn := Button.new()
	undo_btn.text = tr("↶ Undo")
	undo_btn.custom_minimum_size = Vector2(170, 80)
	undo_btn.add_theme_font_size_override("font_size", 26)
	undo_btn.pressed.connect(_on_undo)
	controls.add_child(undo_btn)
	controls.add_child(_build_dpad())

	win_dialog = UI.build_dialog(tr("Level Complete!"), [
		{"text": tr("Next Level"), "action": _change_level.bind(1)},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/box_pusher/box_pusher_help.gd"))
	_build_home()
	if info:
		add_child(info)
		info.high("Highest level unlocked", unlocked)
	add_child(SettingsDrawer.new())

func _build_dpad() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var arrows := {1: ["▲", 0], 3: ["◀", 3], 5: ["▶", 1], 7: ["▼", 2]}
	for i in 9:
		if arrows.has(i):
			var b := Button.new()
			b.text = arrows[i][0]
			b.custom_minimum_size = Vector2(76, 70)
			b.add_theme_font_size_override("font_size", 30)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_on_move.bind(arrows[i][1]))
			grid.add_child(b)
		else:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(76, 70)
			grid.add_child(gap)
	return grid

func _load_level(n: int) -> void:
	level = n
	engine.load_level(level)
	win_dialog.visible = false
	SaveUtil.write(SAVE_PATH, {"unlocked": unlocked, "level": level})
	_refresh()

func _change_level(delta: int) -> void:
	var n := clampi(level + delta, 1, unlocked)
	if n != level:
		_load_level(n)

func _on_restart() -> void:
	engine.restart()
	win_dialog.visible = false
	_refresh()

func _on_undo() -> void:
	engine.undo()
	_refresh()

func _on_move(dir_index: int) -> void:
	if win_dialog.visible:
		return
	if engine.move(BoxEngine.DIRS[dir_index]):
		_refresh()
		if engine.is_solved():
			if level == unlocked:
				unlocked += 1
			SaveUtil.write(SAVE_PATH, {"unlocked": unlocked, "level": level})
			_refresh()
			win_dialog.get_meta("message_label").text = tr("%d moves, %d pushes") % [engine.moves, engine.pushes]
			if info:
				info.add("Levels solved")
				info.celebrate("Solved!")
				info.high("Highest level unlocked", unlocked)
			win_dialog.visible = true

func _refresh() -> void:
	level_label.text = tr("Level %d") % level
	stats_label.text = tr("Moves: %d   Pushes: %d") % [engine.moves, engine.pushes]
	prev_btn.disabled = level <= 1
	next_btn.disabled = level >= unlocked
	board.queue_redraw()

# ---------- drawing & input ----------

func _cell_size() -> float:
	return floor(min((board.size.x - 24.0) / engine.w, (board.size.y - 8.0) / engine.h))

func _origin() -> Vector2:
	var cs := _cell_size()
	return Vector2((board.size.x - cs * engine.w) / 2.0, (board.size.y - cs * engine.h) / 2.0)

func _draw_board() -> void:
	var cs := _cell_size()
	var o := _origin()
	for y in engine.h:
		for x in engine.w:
			var p := Vector2i(x, y)
			var rect := Rect2(o + Vector2(x, y) * cs, Vector2(cs, cs))
			if engine.walls.has(p):
				# only draw walls that touch the floor, so the outside stays empty
				var edge := false
				for d in BoxEngine.DIRS:
					if engine.is_floor(p + d):
						edge = true
				if edge:
					board.draw_rect(rect.grow(-1), Color(COLOR_WALL, 0.35))
					board.draw_rect(rect.grow(-2), COLOR_WALL, false, 2.0)
				continue
			board.draw_rect(rect, COLOR_FLOOR)
			if engine.goals.has(p):
				HomeKit.glow_circle(board, rect.get_center(), cs * 0.16, COLOR_GOAL, 2.0, 0.5)
	for b in engine.boxes:
		var rect := Rect2(o + Vector2(b) * cs, Vector2(cs, cs)).grow(-cs * 0.1)
		HomeKit.glow_rect(board, rect, COLOR_BOX_DONE if engine.goals.has(b) else COLOR_BOX, maxf(2.0, cs * 0.05), 0.3)
	var pc := o + (Vector2(engine.player) + Vector2(0.5, 0.5)) * cs
	HomeKit.glow_circle(board, pc, cs * 0.34, COLOR_PLAYER, maxf(2.0, cs * 0.05), 0.5)
	board.draw_circle(pc + Vector2(-cs * 0.11, -cs * 0.06), cs * 0.06, Color(0.05, 0.05, 0.1))
	board.draw_circle(pc + Vector2(cs * 0.11, -cs * 0.06), cs * 0.06, Color(0.05, 0.05, 0.1))

func _on_board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			swipe_start = event.position
			swiping = true
		elif swiping:
			swiping = false
			var d: Vector2 = event.position - swipe_start
			if d.length() < 30.0:
				_step_towards_tap(event.position)
				return
			if abs(d.x) > abs(d.y):
				_on_move(1 if d.x > 0 else 3)
			else:
				_on_move(2 if d.y > 0 else 0)

## A tap next to the player steps that way (handy for one-square moves).
func _step_towards_tap(pos: Vector2) -> void:
	var cs := _cell_size()
	var cell: Vector2 = (pos - _origin()) / cs
	var d := Vector2(cell.x - (engine.player.x + 0.5), cell.y - (engine.player.y + 0.5))
	if d.length() < 0.5:
		return
	if abs(d.x) > abs(d.y):
		_on_move(1 if d.x > 0 else 3)
	else:
		_on_move(2 if d.y > 0 else 0)

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/box_pusher/box_pusher_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/box_pusher/box_pusher_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Push every box onto a goal. You can't pull!",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  Play", "sub": "Pick up at your latest level", "action": _play_latest}],
		"can_resume": func(): return level > 1 or unlocked > 1,
		"resume": func(): _load_level(level),
		"resume_text": func(): return tr("Level %d") % level,
		"restart": _on_restart,
		"board": "Levels solved",
		"board_note": "Levels solved, all time.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 4.0, 44.0)
	var o := Vector2(c.size.x / 2.0 - k * 2.5, c.size.y / 2.0 - k * 1.5)
	for x in 5:
		for y in 3:
			var r := Rect2(o + Vector2(x, y) * k, Vector2(k, k))
			if y == 0 or y == 2 or x == 0 or x == 4:
				c.draw_rect(r.grow(-2), Color(COLOR_WALL, 0.5))
				c.draw_rect(r.grow(-2), COLOR_WALL.lightened(0.3), false, 1.5)
	HomeKit.glow_circle(c, o + Vector2(1.5, 1.5) * k, k * 0.32, COLOR_PLAYER, 2.5, 0.35)
	HomeKit.glow_rect(c, Rect2(o + Vector2(2, 1) * k, Vector2(k, k)).grow(-k * 0.12), COLOR_BOX, 2.5, 0.3)
	HomeKit.glow_circle(c, o + Vector2(3.5, 1.5) * k, k * 0.16, COLOR_GOAL, 2.0, 0.6)

func _play_latest() -> void:
	_load_level(unlocked)
