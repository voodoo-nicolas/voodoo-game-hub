extends Control

## Trivia -- pick a topic, answer ten questions. Builds its whole UI in code.

const TriviaEngine = preload("res://scripts/games/trivia/trivia_engine.gd")
const HomeKit = preload("res://scripts/games/trivia/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_RIGHT := Color("7dff3a")
const COLOR_WRONG := Color("ff4f6a")
const COLOR_BUTTON := Color("29e6ff")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var answering: bool = false
var elapsed: float = 0.0
var topic: String = ""

var topic_box: Control
var play_box: Control
var end_box: Control
var count_label: Label
var score_label: Label
var time_bar: ProgressBar
var question_label: Label
var feedback_label: Label
var answer_buttons: Array = []
var end_label: Label

func _ready() -> void:
	preload("res://scripts/games/trivia/trivia_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = TriviaEngine.new()
	engine.load_bank()
	_build_ui()
	_show_topics()  # behind the Home screen

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
	title.text = tr("❓ Trivia")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(spacer)

	_build_topics(root)
	_build_play(root)
	_build_end(root)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/trivia/trivia_help.gd"))
	_build_home()
	if info:
		add_child(info)
	# Must stay the last child so its tab sits above any dialog.
	add_child(SettingsDrawer.new())

func _build_topics(root: VBoxContainer) -> void:
	topic_box = MarginContainer.new()
	topic_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	topic_box.add_theme_constant_override("margin_left", 16)
	topic_box.add_theme_constant_override("margin_right", 16)
	topic_box.add_theme_constant_override("margin_bottom", 24)
	root.add_child(topic_box)
	var center := CenterContainer.new()
	topic_box.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	box.add_child(_label(tr("Choose a topic"), 36, Color(1, 1, 1)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for t in engine.TOPICS:
		var b := Button.new()
		b.text = t.icon + "\n" + tr(t.name)
		b.custom_minimum_size = Vector2(300, 120)
		b.add_theme_font_size_override("font_size", 28)
		_paint(b, COLOR_BUTTON)
		b.pressed.connect(_start_game.bind(t.id))
		grid.add_child(b)

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
	count_label = _label("", 28, Color(1, 0.84, 0.3))
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud.add_child(count_label)
	score_label = _label("", 28, Color(0.5, 1, 0.6))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(score_label)

	time_bar = ProgressBar.new()
	time_bar.show_percentage = false
	time_bar.min_value = 0.0
	time_bar.max_value = TriviaEngine.TIME_LIMIT
	time_bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(time_bar)

	var q_center := CenterContainer.new()
	q_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(q_center)
	var q_box := VBoxContainer.new()
	q_box.add_theme_constant_override("separation", 14)
	q_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_center.add_child(q_box)
	question_label = _label("", 38, Color(1, 1, 1), 640)
	q_box.add_child(question_label)
	feedback_label = _label(" ", 26, Color(1, 1, 1), 640)
	q_box.add_child(feedback_label)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	box.add_child(list)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 28)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.set_meta("sfx", "")  # the game plays its own right / wrong sound
		b.pressed.connect(_on_answer.bind(i))
		list.add_child(b)
		answer_buttons.append(b)

func _build_end(root: VBoxContainer) -> void:
	end_box = CenterContainer.new()
	end_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(end_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	end_box.add_child(box)
	box.add_child(_label(tr("Quiz complete!"), 44, Color(1, 0.84, 0.3)))
	end_label = _label("", 30, Color(1, 1, 1), 440)
	box.add_child(end_label)
	var again := Button.new()
	again.text = tr("Play Again")
	again.custom_minimum_size = Vector2(300, 72)
	again.add_theme_font_size_override("font_size", 30)
	again.pressed.connect(_start_game.bind(topic))
	box.add_child(again)
	var other := Button.new()
	other.text = tr("Change topic")
	other.custom_minimum_size = Vector2(300, 64)
	other.add_theme_font_size_override("font_size", 26)
	other.pressed.connect(_show_topics)
	box.add_child(other)
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
	var sb := HomeKit.neon_box(color, "normal")
	sb.bg_color = Color(color, 0.12 if color == COLOR_BUTTON else 0.35)
	sb.set_corner_radius_all(14)
	for st in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(st, sb)
	button.add_theme_stylebox_override("pressed", HomeKit.neon_box(color, "pressed"))

func _show_topics() -> void:
	answering = false
	topic_box.visible = true
	play_box.visible = false
	end_box.visible = false

func _start_game(topic_id: String) -> void:
	topic = topic_id
	var spanish := TranslationServer.get_locale().begins_with("es")
	engine.start(topic, spanish)
	topic_box.visible = false
	end_box.visible = false
	if engine.total() == 0:
		_show_topics()
		return
	play_box.visible = true
	_show_question()

func _show_question() -> void:
	var q: Dictionary = engine.current()
	question_label.text = q.text
	for i in 4:
		answer_buttons[i].text = q.choices[i]
		_paint(answer_buttons[i], COLOR_BUTTON)
	count_label.text = tr("Question %d of %d") % [engine.index + 1, engine.total()]
	score_label.text = tr("Score: %d") % engine.score
	feedback_label.text = " "
	elapsed = 0.0
	time_bar.value = engine.TIME_LIMIT
	answering = true

func _process(delta: float) -> void:
	if not answering:
		return
	elapsed += delta
	time_bar.value = maxf(0.0, engine.TIME_LIMIT - elapsed)
	if elapsed >= engine.TIME_LIMIT:
		_resolve(-1)

func _on_answer(index: int) -> void:
	if answering:
		_resolve(index)

## Marks the answer, then moves on shortly.
func _resolve(choice: int) -> void:
	answering = false
	var correct: int = engine.current().correct
	var earned: int = engine.submit(choice, elapsed)
	var ok := choice == correct
	_sfx("letter_right" if ok else "letter_wrong")
	_paint(answer_buttons[correct], COLOR_RIGHT)
	if not ok and choice >= 0:
		_paint(answer_buttons[choice], COLOR_WRONG)
	if ok:
		feedback_label.text = tr("Correct! +%d") % earned
	elif choice < 0:
		feedback_label.text = tr("Time's up!")
	else:
		feedback_label.text = tr("Not quite.")
	feedback_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6) if ok else Color(1, 0.55, 0.5))
	score_label.text = tr("Score: %d") % engine.score
	var tw := create_tween()
	tw.tween_interval(1.3 if ok else 2.0)
	tw.tween_callback(_next)

func _next() -> void:
	engine.advance()
	if engine.is_done():
		_finish()
	else:
		_show_question()

func _finish() -> void:
	play_box.visible = false
	end_box.visible = true
	var text := tr("Score: %d") % engine.score + "\n" + tr("Correct: %d of %d") % [engine.correct_count, engine.total()]
	if info:
		info.add("Games played")
		info.add("Correct answers", engine.correct_count)
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

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/trivia/trivia_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"retro": true,
		"help": preload("res://scripts/games/trivia/trivia_help.gd"),
		"info": info,
		"accent": HomeKit.PURPLE,
		"subtitle": "Ten questions. Answer fast for more points.",
		"logo": _draw_home_logo,
		"modes": [{"text": "🧠  Play", "sub": "Pick a topic", "action": _show_topics}],
		"restart": _show_topics,
		"board_note": "Your best score in one game.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	HomeKit.glow_circle(c, ctr, h * 0.42, HomeKit.PURPLE, 3.0, 0.1)
	HomeKit.glow_text(c, ctr + Vector2(0, h * 0.03), "?", int(h * 0.6), HomeKit.GOLD)
