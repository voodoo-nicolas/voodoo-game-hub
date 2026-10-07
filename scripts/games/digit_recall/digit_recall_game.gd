extends Control

## Digit Recall -- memorize a number, type it back, get one digit longer.
## Builds its whole UI in code.

const DigitRecallEngine = preload("res://scripts/games/digit_recall/digit_recall_engine.gd")
const HomeKit = preload("res://scripts/games/digit_recall/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_KEY := Color(0.22, 0.26, 0.4)

enum Phase { IDLE, SHOW, ENTER, BETWEEN, OVER }

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
var number_label: Label
var time_bar: ProgressBar
var keys: Array = []
var end_label: Label
var show_tween: Tween

func _ready() -> void:
	preload("res://scripts/games/digit_recall/digit_recall_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = DigitRecallEngine.new()
	_build_ui()
	_show_start()  # Home covers it

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
	title.text = tr("🔟 Digit Recall")
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
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/digit_recall/digit_recall_help.gd"))
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
	box.add_child(_label(tr("Memorize the number, then type it back. How long can you go?"), 30, Color(1, 1, 1), 440))
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
	level_label = _label("", 30, Color(1, 0.84, 0.3))
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud.add_child(level_label)
	lives_label = _label("", 30, Color(1, 0.4, 0.5))
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(lives_label)

	status_label = _label("", 26, Color(1, 1, 1))
	box.add_child(status_label)

	time_bar = ProgressBar.new()
	time_bar.show_percentage = false
	time_bar.min_value = 0.0
	time_bar.max_value = 1.0
	time_bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(time_bar)

	var n_center := CenterContainer.new()
	n_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(n_center)
	number_label = _label("", 72, Color(1, 1, 1), 640)
	n_center.add_child(number_label)

	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 12)
	pad.add_theme_constant_override("v_separation", 12)
	box.add_child(pad)
	for label in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", ""]:
		if label == "":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 96)
			pad.add_child(gap)
			continue
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 40)
		b.set_meta("sfx", "")  # the game plays its own sounds
		_paint(b, COLOR_KEY)
		if label == "⌫":
			b.pressed.connect(_on_backspace)
		else:
			b.pressed.connect(_on_key.bind(int(label)))
		pad.add_child(b)
		keys.append(b)

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

func _paint(button: Button, color: Color) -> void:
	var rim: Color = HomeKit.CYAN if color == COLOR_KEY else color
	var sb := HomeKit.neon_box(rim, "normal")
	sb.bg_color = Color(rim, 0.1)
	sb.set_corner_radius_all(14)
	var pressed := HomeKit.neon_box(rim, "pressed")
	pressed.set_corner_radius_all(14)
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", sb)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", sb)

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

## Shows the number, then hides it and waits for the player's entry.
func _begin_round() -> void:
	phase = Phase.SHOW
	phase_id += 1
	_update_hud()
	status_label.text = tr("Memorize the number…")
	number_label.add_theme_color_override("font_color", Color(1, 1, 1))
	number_label.text = _spaced(engine.digits)
	time_bar.value = 1.0
	time_bar.visible = true
	if show_tween:
		show_tween.kill()
	show_tween = create_tween()
	show_tween.tween_property(time_bar, "value", 0.0, engine.show_secs())
	show_tween.tween_callback(_after_wait.bind(phase_id, _begin_enter))

func _begin_enter() -> void:
	phase = Phase.ENTER
	phase_id += 1
	time_bar.visible = false
	status_label.text = tr("Type the number")
	_show_entry()

func _after_wait(id: int, then: Callable) -> void:
	if id == phase_id:
		then.call()

func _wait(secs: float, then: Callable) -> void:
	var id := phase_id
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(_after_wait.bind(id, then))

## "4 8 1" -- digits spaced so long numbers wrap neatly.
func _spaced(list: Array) -> String:
	var parts: PackedStringArray = []
	for d in list:
		parts.append(str(d))
	return " ".join(parts)

## The typed digits, then an underscore for each one still to come.
func _show_entry() -> void:
	var parts: PackedStringArray = []
	for d in engine.entry:
		parts.append(str(d))
	for i in engine.length - engine.entry.size():
		parts.append("_")
	number_label.add_theme_color_override("font_color", Color(1, 0.84, 0.3))
	number_label.text = " ".join(parts)

func _update_hud() -> void:
	level_label.text = tr("%d digits") % engine.length
	lives_label.text = "♥".repeat(maxi(engine.lives, 0))

func _on_key(digit: int) -> void:
	if phase != Phase.ENTER:
		return
	var result: String = engine.press(digit)
	if result == "ignored":
		return
	_show_entry()
	match result:
		"typing":
			_sfx("tap")
		"clear":
			_sfx("win")
			phase = Phase.BETWEEN
			phase_id += 1
			number_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
			status_label.text = tr("Correct!")
			_wait(1.0, _new_round)
		"miss":
			_sfx("letter_wrong")
			_reveal()
			phase = Phase.BETWEEN
			phase_id += 1
			status_label.text = tr("Not quite. The number was:")
			_update_hud()
			_wait(2.2, _new_round)
		"over":
			_sfx("letter_wrong")
			_reveal()
			phase = Phase.BETWEEN
			phase_id += 1
			status_label.text = tr("Not quite. The number was:")
			_update_hud()
			_wait(2.2, _finish)

## A keyboard works too: digits / numpad type, Backspace erases.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or get_tree().paused or phase != Phase.ENTER:
		return
	var code := k.physical_keycode
	if code >= KEY_0 and code <= KEY_9:
		_on_key(code - KEY_0)
	elif code >= KEY_KP_0 and code <= KEY_KP_9:
		_on_key(code - KEY_KP_0)
	elif code == KEY_BACKSPACE or code == KEY_DELETE:
		_on_backspace()
	else:
		return
	get_viewport().set_input_as_handled()

func _on_backspace() -> void:
	if phase == Phase.ENTER:
		engine.backspace()
		_show_entry()

func _reveal() -> void:
	number_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	number_label.text = _spaced(engine.digits)

## A fresh number: one digit longer after a clear, the same length after a miss.
func _new_round() -> void:
	engine.start_round()
	_begin_round()

func _finish() -> void:
	phase = Phase.OVER
	phase_id += 1
	play_box.visible = false
	end_box.visible = true
	var text := tr("Longest number: %d digits") % engine.best_length
	if info:
		info.add("Games played")
		var record: bool = info.high("Best score", engine.best_length) and engine.best_length > 0
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

const TITLE_FOR_HOME := preload("res://scripts/games/digit_recall/digit_recall_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"retro": true,
		"help": preload("res://scripts/games/digit_recall/digit_recall_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Remember the number, then type it back. It grows every round.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  Play", "sub": "Until you miss", "action": _start_game}],
		"restart": _start_game,
		"board_note": "Your best score.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	HomeKit.glow_text(c, ctr + Vector2(0, -h * 0.18), "3 1 4 1 5", int(h * 0.3), HomeKit.CYAN)
	HomeKit.glow_text(c, ctr + Vector2(0, h * 0.22), "3 1 4 _ _", int(h * 0.24), HomeKit.LIME)
