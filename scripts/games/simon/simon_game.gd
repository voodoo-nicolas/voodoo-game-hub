extends Control

const SimonEngine = preload("res://scripts/games/simon/simon_engine.gd")
const HomeKit = preload("res://scripts/games/simon/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://simon_best.json"

const PAD_COLORS := [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.95), Color(0.95, 0.75, 0.2), Color(0.4, 0.85, 0.4)]
const PAD_DIM := 0.45
## Each pad's tone (Hz), the classic four: red, blue, yellow, green.
const PAD_TONES := [310.0, 209.0, 252.0, 415.0]
const FLASH_DURATION := 0.4
const GAP_DURATION := 0.2

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var accepting_input: bool = false
var playing_sequence: bool = false

var status_label: Label
var best_label: Label
var pads: Array = []  # 4 PanelContainer
var start_dialog: Control
var game_over_label: Label
var best_level: int = 0
var tones: Array = []  # AudioStreamWAV per pad, made in _ready

func _ready() -> void:
	preload("res://scripts/games/simon/simon_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = SimonEngine.new()
	for f in PAD_TONES:
		tones.append(_make_tone(f, FLASH_DURATION))
	_build_ui()
	_load_best()
	_show_start_dialog()
	start_dialog.visible = false  # the Home screen replaces it

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
	title.text = tr("Memory Lights")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.LIME.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.LIME, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 24)
	best_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	top_bar.add_child(best_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)

	var viewport_width: float = get_viewport_rect().size.x
	var pad_size: float = min(280.0, floor((viewport_width - 24.0 * 2.0 - 12.0) / 2.0))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)

	for i in range(4):
		var pad := PanelContainer.new()
		pad.custom_minimum_size = Vector2(pad_size, pad_size)
		_set_pad_color(pad, i, false)

		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_meta("sfx", "")  # the pad plays its own tone
		btn.pressed.connect(_on_pad_pressed.bind(i))
		pad.add_child(btn)

		grid.add_child(pad)
		pads.append(pad)

	_build_start_dialog()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/simon/simon_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best_level > 0:
			info.high("Best level", best_level)
	add_child(SettingsDrawer.new())

func _set_pad_color(pad: PanelContainer, i: int, lit: bool) -> void:
	var sb := StyleBoxFlat.new()
	var c: Color = PAD_COLORS[i]
	sb.bg_color = c if lit else Color(c.r * PAD_DIM, c.g * PAD_DIM, c.b * PAD_DIM)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	pad.add_theme_stylebox_override("panel", sb)

func _build_start_dialog() -> void:
	start_dialog = ColorRect.new()
	start_dialog.color = Color(0, 0, 0, 0.8)
	start_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	start_dialog.visible = false
	add_child(start_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_dialog.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.18)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	game_over_label = Label.new()
	game_over_label.text = tr("Memory Lights")
	game_over_label.add_theme_font_size_override("font_size", 31)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(game_over_label)

	var start_btn := Button.new()
	start_btn.text = tr("Start")
	start_btn.custom_minimum_size = Vector2(200, 48)
	start_btn.pressed.connect(_start_game)
	box.add_child(start_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(_go_home)
	box.add_child(menu_btn)

# ---------- game flow ----------

func _show_start_dialog() -> void:
	game_over_label.text = tr("Memory Lights")
	status_label.text = tr("Watch, then repeat the sequence")
	start_dialog.visible = true

func _start_game() -> void:
	start_dialog.visible = false
	engine.reset()
	_next_round()

func _next_round() -> void:
	engine.next_round()
	status_label.text = tr("Level %d") % engine.level
	_play_sequence()

## A Tween owned by this scene rather than a chain of awaits on SceneTree
## timers: leaving mid-sequence frees the tween with the scene, where an
## await would try to resume into the freed scene.
func _play_sequence() -> void:
	playing_sequence = true
	accepting_input = false
	var tween := create_tween()
	for pad_index in engine.sequence:
		tween.tween_callback(_light_pad.bind(pad_index))
		tween.tween_interval(FLASH_DURATION)
		tween.tween_callback(_set_pad_color.bind(pads[pad_index], pad_index, false))
		tween.tween_interval(GAP_DURATION)
	tween.tween_callback(_on_sequence_done)

func _on_sequence_done() -> void:
	playing_sequence = false
	accepting_input = true

func _on_pad_pressed(i: int) -> void:
	if not accepting_input or playing_sequence:
		return
	_light_pad(i)
	create_tween().tween_callback(_set_pad_color.bind(pads[i], i, false)).set_delay(0.15)

	var result: String = engine.tap(i)
	match result:
		"correct":
			pass
		"round_complete":
			accepting_input = false
			if engine.level > best_level:
				best_level = engine.level
				_save_best()
				_update_best_label()
			# The scene's own tween: it stops while paused and dies with the scene.
			create_tween().tween_callback(_next_round).set_delay(0.6)
		"wrong":
			accepting_input = false
			_sfx("buzzer")
			if info:
				info.add("Games played")
				info.best("Best level", best_level)
			game_over_label.text = tr("Game Over — reached level %d") % engine.level
			status_label.text = ""
			start_dialog.visible = true

func _light_pad(i: int) -> void:
	_set_pad_color(pads[i], i, true)
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play_stream(tones[i])

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

## A soft square-ish tone with a short fade in and out, as 16-bit mono WAV.
static func _make_tone(freq: float, length: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for k in n:
		var t := float(k) / rate
		var v := sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 3.0 * t) / 3.0
		var env := minf(1.0, minf(t / 0.01, (length - t) / 0.06))
		data.encode_s16(k * 2, int(clampf(v * env * 0.45, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _update_best_label() -> void:
	best_label.text = tr("Best: %d") % best_level

func _save_best() -> void:
	SaveUtil.write(BEST_PATH, {"best_level": best_level})
	if Auth.is_logged_in():
		Auth.push_stat("simon_best_level", best_level)

func _load_best() -> void:
	var data = SaveUtil.read(BEST_PATH)
	best_level = int(data.get("best_level", 0)) if data != null else 0
	_update_best_label()
	if Auth.is_logged_in():
		# A method, not a lambda: if the player leaves before the reply lands,
		# a method callable on a freed scene is skipped instead of erroring.
		Auth.reconcile_stat("simon_best_level", best_level, _on_best_reconciled)

func _on_best_reconciled(merged: int) -> void:
	best_level = merged
	if info:
		info.high("Best level", merged)
	SaveUtil.write(BEST_PATH, {"best_level": merged})
	_update_best_label()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/simon/simon_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/simon/simon_help.gd"),
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Watch the lights, then repeat the sequence. It grows every round.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  Play", "sub": "One mistake ends it", "action": _start_game}],
		"restart": _start_game,
		"board": "Best level",
		"board_note": "The longest sequence you've repeated.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var r := minf(c.size.y * 0.45, 80.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	var cols := [HomeKit.LIME, HomeKit.PINK, HomeKit.GOLD, HomeKit.CYAN]
	for k in 4:
		var pts := PackedVector2Array()
		for i in 13:
			var a := TAU * (k + 0.06 + i * 0.88 / 12.0) / 4.0 - PI
			pts.append(ctr + Vector2(cos(a), sin(a)) * r)
		for i in range(12, -1, -1):
			var a := TAU * (k + 0.06 + i * 0.88 / 12.0) / 4.0 - PI
			pts.append(ctr + Vector2(cos(a), sin(a)) * r * 0.45)
		c.draw_colored_polygon(pts, Color(cols[k], 0.5 if k == 1 else 0.15))
		HomeKit.glow_polyline(c, pts, cols[k], 2.0, true)
