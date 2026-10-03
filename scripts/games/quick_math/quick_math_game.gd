extends Control

## Quick Math -- 60 seconds of multiple-choice arithmetic. Builds its whole UI in code.

const QuickMathEngine = preload("res://scripts/games/quick_math/quick_math_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var running: bool = false

var start_box: Control
var play_box: Control
var end_box: Control
var time_label: Label
var score_label: Label
var level_label: Label
var question_label: Label
var feedback_label: Label
var answer_buttons: Array = []
var end_label: Label

func _ready() -> void:
	preload("res://scripts/games/quick_math/quick_math_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = QuickMathEngine.new()
	_build_ui()
	_show_start()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	hub_btn.text = tr("Hub")
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("➕ Quick Math")
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
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/quick_math/quick_math_help.gd"))
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
	box.add_child(_label(tr("How many sums can you solve in 60 seconds?"), 30, Color(1, 1, 1), 440))
	var go := Button.new()
	go.text = tr("Start")
	go.custom_minimum_size = Vector2(300, 80)
	go.add_theme_font_size_override("font_size", 34)
	go.pressed.connect(_start_round)
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
	time_label = _label("", 34, Color(1, 0.84, 0.3))
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(time_label)
	level_label = _label("", 24, Color(0.7, 0.7, 0.78))
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(level_label)
	score_label = _label("", 34, Color(0.5, 1, 0.6))
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(score_label)

	var q_center := CenterContainer.new()
	q_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(q_center)
	var q_box := VBoxContainer.new()
	q_center.add_child(q_box)
	question_label = _label("", 84, Color(1, 1, 1))
	q_box.add_child(question_label)
	feedback_label = _label(" ", 30, Color(1, 1, 1))
	q_box.add_child(feedback_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 130)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 48)
		b.set_meta("sfx", "")  # the game plays its own right / wrong sound
		_paint(b, Color(0.22, 0.26, 0.4))
		b.pressed.connect(_on_answer.bind(i))
		grid.add_child(b)
		answer_buttons.append(b)

func _build_end(root: VBoxContainer) -> void:
	end_box = CenterContainer.new()
	end_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(end_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	end_box.add_child(box)
	box.add_child(_label(tr("Time's up!"), 44, Color(1, 0.84, 0.3)))
	end_label = _label("", 30, Color(1, 1, 1), 440)
	box.add_child(end_label)
	var again := Button.new()
	again.text = tr("Play Again")
	again.custom_minimum_size = Vector2(300, 72)
	again.add_theme_font_size_override("font_size", 30)
	again.pressed.connect(_start_round)
	box.add_child(again)
	var hub := Button.new()
	hub.text = tr("Back to Hub")
	hub.custom_minimum_size = Vector2(300, 60)
	hub.add_theme_font_size_override("font_size", 24)
	hub.pressed.connect(UI.exit_to_hub.bind(self))
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(14)
	var pressed := sb.duplicate()
	pressed.bg_color = color.lightened(0.25)
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", sb)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", sb)

func _show_start() -> void:
	running = false
	start_box.visible = true
	play_box.visible = false
	end_box.visible = false

func _start_round() -> void:
	engine.reset()
	running = true
	start_box.visible = false
	end_box.visible = false
	play_box.visible = true
	feedback_label.text = " "
	_render()

func _process(delta: float) -> void:
	if not running:
		return
	engine.tick(delta)
	time_label.text = tr("⏱ %d") % ceili(engine.time_left)
	if engine.is_over():
		_finish()

func _render() -> void:
	question_label.text = engine.question
	for i in 4:
		answer_buttons[i].text = str(engine.choices[i])
	score_label.text = tr("Score: %d") % engine.score
	level_label.text = tr("Level %d") % (engine.level() + 1)
	time_label.text = tr("⏱ %d") % ceili(engine.time_left)

func _on_answer(index: int) -> void:
	if not running:
		return
	var ok: bool = engine.submit(index)
	_sfx("letter_right" if ok else "letter_wrong")
	feedback_label.text = tr("✔") if ok else tr("✖ −3 s")
	feedback_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6) if ok else Color(1, 0.4, 0.4))
	feedback_label.modulate.a = 1.0
	create_tween().tween_property(feedback_label, "modulate:a", 0.0, 0.6)
	if engine.is_over():
		_finish()
	else:
		_render()

func _finish() -> void:
	if not running:
		return
	running = false
	play_box.visible = false
	end_box.visible = true
	var text := tr("Score: %d") % engine.score + "\n" + tr("Best streak: %d") % engine.best_streak
	if info:
		info.add("Games played")
		info.high("Best streak", engine.best_streak)
		var record: bool = info.high("Best score", engine.score) and engine.score > 0
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
