extends Control

const ReactionEngine = preload("res://scripts/games/reaction_test/reaction_test_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const COLOR_IDLE := Color(0.16, 0.16, 0.22)
const COLOR_WAITING := Color(0.55, 0.15, 0.15)
const COLOR_READY := Color(0.15, 0.55, 0.2)
const COLOR_TOO_EARLY := Color(0.6, 0.4, 0.05)

var engine
var pad: PanelContainer
var pad_label: Label
var result_label: Label
var best_label: Label
var ready_started_at: int = 0

func _ready() -> void:
	Orientation.lock_portrait()
	engine = ReactionEngine.new()
	_build_ui()
	_show_idle("Tap the button below to start")

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_margin.add_child(top_bar)

	var hub_btn := Button.new()
	hub_btn.text = "Hub"
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = "⏱️ Reaction Test"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(spacer)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 18)
	best_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(best_label)

	pad = PanelContainer.new()
	pad.custom_minimum_size = Vector2(280, 280)
	box.add_child(pad)

	var pad_button := Button.new()
	pad_button.flat = true
	pad_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad_button.focus_mode = Control.FOCUS_NONE
	pad_button.pressed.connect(_on_pad_pressed)
	pad.add_child(pad_button)

	pad_label = Label.new()
	pad_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pad_label.add_theme_font_size_override("font_size", 26)
	pad_label.add_theme_color_override("font_color", Color(1, 1, 1))
	pad_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	pad_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(pad_label)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 20)
	result_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	result_label.custom_minimum_size = Vector2(280, 0)
	box.add_child(result_label)

	add_child(SettingsDrawer.new())

# ---------- flow ----------
# States: idle (waiting for a tap to arm) -> waiting (red, don't tap) ->
# ready (green, tap now!) -> result / too_early -> back to idle on next tap.

func _on_pad_pressed() -> void:
	match engine.state:
		ReactionEngine.State.IDLE, ReactionEngine.State.RESULT, ReactionEngine.State.TOO_EARLY:
			_arm()
		ReactionEngine.State.WAITING:
			engine.tap(0)
			_show_too_early()
		ReactionEngine.State.READY:
			var reaction_ms: int = Time.get_ticks_msec() - ready_started_at
			engine.tap(reaction_ms)
			_show_result(reaction_ms)

func _arm() -> void:
	engine.start_waiting()
	_set_pad(COLOR_WAITING, "Wait for green...")
	result_label.text = ""
	var delay := randf_range(1.0, 4.0)
	get_tree().create_timer(delay).timeout.connect(_on_delay_elapsed.bind(engine.state))

## Bound arg guards against a stale timer firing after the player already
## false-started and re-armed a new round in the meantime.
func _on_delay_elapsed(state_when_started: int) -> void:
	if engine.state != ReactionEngine.State.WAITING:
		return
	engine.mark_ready()
	ready_started_at = Time.get_ticks_msec()
	_set_pad(COLOR_READY, "TAP NOW!")

func _show_too_early() -> void:
	_set_pad(COLOR_TOO_EARLY, "Too soon!\nTap to try again")

func _show_result(reaction_ms: int) -> void:
	_set_pad(COLOR_IDLE, "%d ms\nTap to try again" % reaction_ms)
	result_label.text = "Attempt #%d" % engine.attempts
	_update_best_label()

func _show_idle(text: String) -> void:
	_set_pad(COLOR_IDLE, text)
	_update_best_label()

func _update_best_label() -> void:
	best_label.text = "Best: %d ms" % engine.best_ms if engine.best_ms >= 0 else "Best: —"

func _set_pad(color: Color, text: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	pad.add_theme_stylebox_override("panel", sb)
	pad_label.text = text
