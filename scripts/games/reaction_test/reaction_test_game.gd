extends Control

const ReactionEngine = preload("res://scripts/games/reaction_test/reaction_test_engine.gd")
const HomeKit = preload("res://scripts/games/reaction_test/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_IDLE := Color("3a8cff")
const COLOR_WAITING := Color("ff2b6b")
const COLOR_READY := Color("7dff3a")
const COLOR_TOO_EARLY := Color("ffae2b")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var pad: PanelContainer
var pad_label: Label
var result_label: Label
var best_label: Label
var ready_started_at: int = 0
## Counts every arming; each delay timer carries the count it was armed with.
var arm_count: int = 0

func _ready() -> void:
	preload("res://scripts/games/reaction_test/reaction_test_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = ReactionEngine.new()
	_build_ui()
	_show_idle(tr("Tap the button below to start"))

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
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
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("⏱️ Reaction Test")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.LIME.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.LIME, 0.5))
	title.add_theme_constant_override("outline_size", 8)
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
	best_label.add_theme_font_size_override("font_size", 24)
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
	pad_label.add_theme_font_size_override("font_size", 33)
	pad_label.add_theme_color_override("font_color", Color(1, 1, 1))
	pad_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	pad_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(pad_label)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 26)
	result_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	result_label.custom_minimum_size = Vector2(280, 0)
	box.add_child(result_label)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/reaction_test/reaction_test_help.gd"))
	_build_home()
	if info:
		add_child(info)
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
	_set_pad(COLOR_WAITING, tr("Wait for green..."))
	result_label.text = ""
	var delay := randf_range(1.0, 4.0)
	arm_count += 1
	get_tree().create_timer(delay).timeout.connect(_on_delay_elapsed.bind(arm_count))

## A timer from an earlier arming (the player false-started and re-armed
## before it fired) must not turn the pad green early -- the state alone
## can't tell them apart, both are WAITING.
func _on_delay_elapsed(armed_as: int) -> void:
	if armed_as != arm_count or engine.state != ReactionEngine.State.WAITING:
		return
	engine.mark_ready()
	ready_started_at = Time.get_ticks_msec()
	_set_pad(COLOR_READY, tr("TAP NOW!"))

func _show_too_early() -> void:
	_set_pad(COLOR_TOO_EARLY, tr("Too soon!\nTap to try again"))

func _show_result(reaction_ms: int) -> void:
	if info:
		info.add("Tests taken")
		info.best("Fastest reaction (ms)", reaction_ms, true)
	_set_pad(COLOR_IDLE, tr("%d ms\nTap to try again") % reaction_ms)
	result_label.text = tr("Attempt #%d") % engine.attempts
	_update_best_label()

func _show_idle(text: String) -> void:
	_set_pad(COLOR_IDLE, text)
	_update_best_label()

func _update_best_label() -> void:
	var best_ms: int = engine.best_ms
	if info and int(info.get_stat("Fastest reaction (ms)", -1)) >= 0:
		var saved := int(info.get_stat("Fastest reaction (ms)"))
		best_ms = saved if best_ms < 0 else mini(best_ms, saved)
	best_label.text = tr("Best: %d ms") % best_ms if best_ms >= 0 else tr("Best: —")

func _set_pad(color: Color, text: String) -> void:
	# a glowing neon pad: the colour is the signal, so the fill stays strong
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.12 if color == COLOR_IDLE else 0.45)
	sb.border_color = color
	sb.set_border_width_all(4)
	sb.shadow_color = Color(color, 0.5)
	sb.shadow_size = 18
	sb.set_corner_radius_all(24)
	pad.add_theme_stylebox_override("panel", sb)
	pad_label.text = text

# ---------- Home screen (home_kit.gd) ----------

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/reaction_test/reaction_test_help.gd"),
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Wait for green… then tap as fast as you can.",
		"logo": _draw_home_logo,
		"modes": [{"text": "⚡  Start", "sub": "Tap the pad when it turns green", "action": _start_test}],
		"board": "Tests taken",
		"board_note": "Tests taken, all time. (Your fastest time is in Statistics.)",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	var bolt := PackedVector2Array([ctr + Vector2(h * 0.08, -h * 0.45), ctr + Vector2(-h * 0.2, h * 0.05), ctr + Vector2(0, h * 0.05),
		ctr + Vector2(-h * 0.08, h * 0.45), ctr + Vector2(h * 0.2, -h * 0.05), ctr + Vector2(0, -h * 0.05)])
	c.draw_colored_polygon(bolt, Color(HomeKit.LIME, 0.25))
	HomeKit.glow_polyline(c, bolt, HomeKit.LIME, 3.0, true)

func _start_test() -> void:
	_show_idle(tr("Tap the pad to start"))
