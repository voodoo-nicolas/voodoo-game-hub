extends Control

## Memory Grid -- watch the lit tiles, then tap them from memory. Builds its whole UI in code.

const MemoryGridEngine = preload("res://scripts/games/memory_grid/memory_grid_engine.gd")
const HomeKit = preload("res://scripts/games/memory_grid/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_IDLE := Color(0.08, 0.12, 0.26)
const COLOR_LIT := Color("ffae2b")
const COLOR_HIT := Color("7dff3a")
const COLOR_MISS := Color("ff4f6a")

enum Phase { IDLE, SHOW, RECALL, BETWEEN, OVER }

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var phase: int = Phase.IDLE
var phase_id: int = 0  # bumped on every change, so a stale timer is ignored

var start_box: Control
var play_box: Control
var end_box: Control
var level_label: Label
var lives_label: Label
var status_label: Label
var grid_holder: CenterContainer
var grid: GridContainer
var tiles: Array = []
var end_label: Label

func _ready() -> void:
	preload("res://scripts/games/memory_grid/memory_grid_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MemoryGridEngine.new()
	_build_ui()
	_show_start()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)

	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("🔲 Memory Grid")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(spacer)

	_build_start(root)
	_build_play(root)
	_build_end(root)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/memory_grid/memory_grid_help.gd"))
	_build_home()
	if info:
		add_child(info)
	# Must stay the last child so its tab sits above any dialog.
	add_child(SettingsDrawer.new())

func _build_start(root: VBoxContainer) -> void:
	start_box = CenterContainer.new()
	start_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(start_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	start_box.add_child(box)
	box.add_child(_label(tr("Watch the tiles light up, then tap them from memory."), 30, Color(1, 1, 1), 440))
	var go := Button.new()
	go.text = tr("Start")
	go.custom_minimum_size = Vector2(300, 80)
	go.add_theme_font_size_override("font_size", 34)
	go.pressed.connect(_start_game)
	box.add_child(go)

func _build_play(root: VBoxContainer) -> void:
	play_box = MarginContainer.new()
	play_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.add_theme_constant_override("margin_left", 16)
	play_box.add_theme_constant_override("margin_right", 16)
	play_box.add_theme_constant_override("margin_bottom", 24)
	root.add_child(play_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	play_box.add_child(box)

	var hud := HBoxContainer.new()
	box.add_child(hud)
	level_label = _label("", 34, Color(1, 0.84, 0.3))
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud.add_child(level_label)
	lives_label = _label("", 34, Color(1, 0.4, 0.5))
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(lives_label)

	status_label = _label("", 28, Color(1, 1, 1))
	box.add_child(status_label)

	grid_holder = CenterContainer.new()
	grid_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(grid_holder)

func _build_end(root: VBoxContainer) -> void:
	end_box = CenterContainer.new()
	end_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(end_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	end_box.add_child(box)
	box.add_child(_label(tr("Game Over"), 44, Color(1, 0.84, 0.3)))
	end_label = _label("", 30, Color(1, 1, 1), 440)
	box.add_child(end_label)
	var again := Button.new()
	again.text = tr("Play Again")
	again.custom_minimum_size = Vector2(300, 72)
	again.add_theme_font_size_override("font_size", 30)
	again.pressed.connect(_start_game)
	box.add_child(again)
	var hub := Button.new()
	hub.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	hub.custom_minimum_size = Vector2(320, 64)
	hub.pressed.connect(_go_home)
	box.add_child(hub)

func _label(text: String, size: int, color: Color, width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l

func _show_start() -> void:
	phase = Phase.IDLE
	start_box.visible = true
	play_box.visible = false
	end_box.visible = false

func _start_game() -> void:
	engine.reset()
	start_box.visible = false
	end_box.visible = false
	play_box.visible = true
	_begin_round()

## Builds the grid for the current level and lights the pattern.
func _begin_round() -> void:
	_build_grid()
	_update_hud()
	phase = Phase.SHOW
	phase_id += 1
	status_label.text = tr("Remember these tiles…")
	for i in engine.target:
		_paint(i, COLOR_LIT)
	_wait(engine.show_secs(), _begin_recall)

func _begin_recall() -> void:
	phase = Phase.RECALL
	phase_id += 1
	for i in tiles.size():
		_paint(i, COLOR_IDLE)
	status_label.text = tr("Tap the tiles that lit up")

func _build_grid() -> void:
	for c in grid_holder.get_children():
		grid_holder.remove_child(c)
		c.queue_free()
	tiles.clear()
	var side: int = engine.side
	var gap := 8
	var avail := get_viewport_rect().size.x - 32.0 - gap * (side - 1)
	var size_px := clampf(avail / side, 40.0, 130.0)
	grid = GridContainer.new()
	grid.columns = side
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	grid_holder.add_child(grid)
	for i in side * side:
		var b := Button.new()
		b.custom_minimum_size = Vector2(size_px, size_px)
		b.set_meta("sfx", "")  # the game plays its own tile sounds
		b.pressed.connect(_on_tile.bind(i))
		grid.add_child(b)
		tiles.append(b)
		_paint(i, COLOR_IDLE)

func _paint(index: int, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	var b: Button = tiles[index]
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, sb)

func _update_hud() -> void:
	level_label.text = tr("Level %d") % engine.level
	lives_label.text = "♥".repeat(maxi(engine.lives, 0))

## A one-shot pause that dies with the scene, and is ignored if the phase
## has moved on (the player can leave or restart meanwhile).
func _wait(secs: float, then: Callable) -> void:
	var id := phase_id
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(_after_wait.bind(id, then))

func _after_wait(id: int, then: Callable) -> void:
	if id == phase_id:
		then.call()

func _on_tile(index: int) -> void:
	if phase != Phase.RECALL:
		return
	var result: String = engine.tap(index)
	match result:
		"ignored":
			return
		"hit":
			_paint(index, COLOR_HIT)
			_sfx("letter_right")
		"clear":
			_paint(index, COLOR_HIT)
			_sfx("win")
			phase = Phase.BETWEEN
			phase_id += 1
			status_label.text = tr("Level cleared!")
			_wait(0.9, _new_round)
		"miss":
			_paint(index, COLOR_MISS)
			_sfx("letter_wrong")
			_reveal_missed()
			phase = Phase.BETWEEN
			phase_id += 1
			status_label.text = tr("Wrong tile! Try again.")
			_update_hud()
			_wait(1.5, _new_round)
		"over":
			_paint(index, COLOR_MISS)
			_reveal_missed()
			phase = Phase.BETWEEN
			phase_id += 1
			_update_hud()
			_wait(1.5, _finish)

## Shows the tiles the player didn't get to.
func _reveal_missed() -> void:
	for i in engine.target:
		if not engine.found.has(i):
			_paint(i, COLOR_LIT)

## A fresh pattern: for the next level after a clear, or the same level after a miss.
func _new_round() -> void:
	engine.start_round()
	_begin_round()

func _finish() -> void:
	phase = Phase.OVER
	phase_id += 1
	play_box.visible = false
	end_box.visible = true
	var text := tr("Levels cleared: %d") % engine.cleared
	if info:
		info.add("Games played")
		var record: bool = info.high("Best score", engine.cleared) and engine.cleared > 0
		if record:
			text += "\n" + tr("New best!")
			info.celebrate("New best!")
		else:
			text += "\n" + tr("Best: %d") % int(info.get_stat("Best score", 0))
	end_label.text = text

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/memory_grid/memory_grid_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"retro": true,
		"help": preload("res://scripts/games/memory_grid/memory_grid_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Tiles light up — tap the same ones back. The grid keeps growing.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  Play", "sub": "Three misses and you're out", "action": _start_game}],
		"restart": _start_game,
		"board_note": "Your best score.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 4.3, 40.0)
	var o := Vector2(c.size.x / 2.0 - k * 2, c.size.y / 2.0 - k * 2)
	var lit := [1, 6, 8, 11, 14]
	for i in 16:
		var r := Rect2(o + Vector2(i % 4, int(i / 4)) * k, Vector2(k, k)).grow(-3)
		if lit.has(i):
			HomeKit.glow_rect(c, r, COLOR_LIT, 2.0, 0.5)
		else:
			HomeKit.glow_rect(c, r, HomeKit.BLUE, 1.0, 0.06)
