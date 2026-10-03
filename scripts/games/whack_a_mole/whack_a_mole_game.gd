extends Control

const WhackEngine = preload("res://scripts/games/whack_a_mole/whack_a_mole_engine.gd")
const HomeKit = preload("res://scripts/games/whack_a_mole/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://whackamole_best.json"
const COLOR_HOLE := Color(0.07, 0.05, 0.16)
const COLOR_HOLE_VOODOO := Color(0.2, 0.1, 0.24)
const COLOR_MOLE := Color(0.5, 0.32, 0.15)
## Skull mode (skulls and voodoo dolls instead of moles). Loaded, never
## preloaded: packs also run on apps before v0.21, which keep the moles.
const VOODOO_PATH := "res://scripts/common/voodoo.gd"
var Voodoo = load(VOODOO_PATH) if ResourceLoader.exists(VOODOO_PATH) else null
var voodoo_on: bool = false

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var best_score: int = 0
var hole_buttons: Array = []
var mole_labels: Array = []
var score_label: Label
var time_label: Label
var best_label: Label
var start_btn: Button
var result_dialog: Control
var result_label: Label
var mole_timer: Timer
var mole_visible_timer: Timer
var pause_dialog: Control
var bg_rect: ColorRect

func _ready() -> void:
	preload("res://scripts/games/whack_a_mole/whack_a_mole_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = WhackEngine.new()
	engine.running = false
	_load_best()
	voodoo_on = Voodoo != null and Voodoo.is_on()
	_build_ui()
	_set_voodoo(voodoo_on)
	_update_labels()

## Skull mode: skulls and voodoo dolls pop up instead of moles. Called by the
## ⚙ drawer's toggle too, so it re-skins in place.
func _set_voodoo(on: bool) -> void:
	voodoo_on = on and Voodoo != null
	for m in mole_labels:
		m.get_child(0).visible = not voodoo_on
		if m.get_child_count() > 1:
			m.get_child(1).visible = voodoo_on
	for h in hole_buttons:
		_style_hole(h, COLOR_HOLE_VOODOO if voodoo_on else COLOR_HOLE)
	bg_rect.color = Voodoo.BG if voodoo_on else HomeKit.BG

func _process(delta: float) -> void:
	if engine.running:
		if engine.tick(delta):
			_end_round()
		else:
			time_label.text = tr("Time: %d") % ceili(engine.time_remaining)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	theme = HomeKit.neon_theme()
	bg_rect = HomeKit.backdrop()
	add_child(bg_rect)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
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
	title.text = tr("🔨 Whack-a-Mole")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.GOLD.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(spacer)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 30)
	root.add_child(stats_row)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	stats_row.add_child(score_label)

	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 26)
	time_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	stats_row.add_child(time_label)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 26)
	best_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	stats_row.add_child(best_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var viewport_width: float = get_viewport_rect().size.x
	var outer_margin := 30.0
	var separation := 10
	var hole_size: float = floor((viewport_width - outer_margin * 2.0 - separation * 2.0) / 3.0)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	box.add_child(grid)

	for i in range(WhackEngine.HOLE_COUNT):
		var hole := Button.new()
		hole.custom_minimum_size = Vector2(hole_size, hole_size)
		hole.flat = false
		hole.focus_mode = Control.FOCUS_NONE
		_style_hole(hole, COLOR_HOLE)
		hole.pressed.connect(_on_hole_pressed.bind(i))
		grid.add_child(hole)
		hole_buttons.append(hole)

		# The mole: a holder (so hits can squash it from its centre) with the
		# 🐹 and, in Skull mode, a drawn skull or voodoo doll instead.
		var mole := Control.new()
		mole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mole.size = Vector2(hole_size, hole_size)
		mole.pivot_offset = Vector2(hole_size, hole_size) / 2.0
		mole.visible = false
		hole.add_child(mole)
		var face := Label.new()
		face.text = "🐹"
		face.size = Vector2(hole_size, hole_size)
		face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		face.add_theme_font_size_override("font_size", int(hole_size * 0.55))
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mole.add_child(face)
		if Voodoo:
			var skin = Voodoo.new()
			skin.span = 0.7
			skin.kind = Voodoo.DOLL if i % 3 == 1 else Voodoo.SKULL
			mole.add_child(skin)
			skin.size = Vector2(hole_size, hole_size)
		mole_labels.append(mole)

	start_btn = Button.new()
	start_btn.text = tr("Start Round")
	start_btn.custom_minimum_size = Vector2(220, 56)
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.pressed.connect(_start_round)
	box.add_child(start_btn)

	_build_result_dialog()
	_build_pause_dialog()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/whack_a_mole/whack_a_mole_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best_score > 0:
			info.high("Best score", best_score)
	add_child(SettingsDrawer.new())

func _build_result_dialog() -> void:
	result_dialog = ColorRect.new()
	result_dialog.color = Color(0, 0, 0, 0.75)
	result_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_dialog.visible = false
	add_child(result_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_dialog.add_child(center)

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

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 31)
	result_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_label)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		result_dialog.visible = false
		_start_round()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(_go_home)
	box.add_child(menu_btn)

# ---------- game flow ----------

func _start_round() -> void:
	engine.reset()
	result_dialog.visible = false
	start_btn.visible = false
	for m in mole_labels:
		m.visible = false
	_update_labels()
	_schedule_next_pop()

func _schedule_next_pop() -> void:
	if not engine.running:
		return
	if is_instance_valid(mole_timer):
		mole_timer.queue_free()
	mole_timer = Timer.new()
	mole_timer.wait_time = randf_range(0.5, 1.1)
	mole_timer.one_shot = true
	add_child(mole_timer)
	mole_timer.timeout.connect(_pop_mole)
	mole_timer.start()

func _pop_mole() -> void:
	if not engine.running:
		return
	var hole: int = engine.pop_random_hole()
	mole_labels[hole].visible = true

	if is_instance_valid(mole_visible_timer):
		mole_visible_timer.queue_free()
	mole_visible_timer = Timer.new()
	mole_visible_timer.wait_time = randf_range(0.6, 0.9)
	mole_visible_timer.one_shot = true
	add_child(mole_visible_timer)
	mole_visible_timer.timeout.connect(_on_mole_timeout)
	mole_visible_timer.start()

func _on_mole_timeout() -> void:
	if engine.active_hole >= 0:
		mole_labels[engine.active_hole].visible = false
		engine.hide_mole()
	_schedule_next_pop()

func _on_hole_pressed(hole: int) -> void:
	if not engine.running:
		return
	if engine.whack(hole):
		_hit_effect(hole)
		score_label.text = tr("Score: %d") % engine.score
		_schedule_next_pop()
	else:
		_miss_effect(hole)

## Bonk: the mole squashes down and vanishes, a 💥 bursts and "+1" floats up.
func _hit_effect(hole: int) -> void:
	var mole: Control = mole_labels[hole]
	var squash := mole.create_tween()
	squash.tween_property(mole, "scale", Vector2(1.25, 0.55), 0.07)
	squash.tween_property(mole, "scale", Vector2(0.2, 0.2), 0.1)
	squash.tween_callback(_hide_mole.bind(mole))
	var hb: Button = hole_buttons[hole]
	var s: float = hb.size.x
	_float_label(hb, "💥", s * 0.6, Vector2(0, 0), Vector2(1.6, 1.6), 0.0, 0.35)
	_float_label(hb, "+1", s * 0.28, Vector2(0, -s * 0.45), Vector2(1, 1), -s * 0.35, 0.6,
			Color(1, 0.85, 0.2))

func _hide_mole(mole: Control) -> void:
	mole.visible = false
	mole.scale = Vector2.ONE

## A tap on an empty hole kicks up a little dust cloud that drifts and fades.
func _miss_effect(hole: int) -> void:
	var hb: Button = hole_buttons[hole]
	var s: float = hb.size.x
	_float_label(hb, "💨", s * 0.35, Vector2(0, s * 0.1), Vector2(1.5, 1.5), -s * 0.12, 0.5)

## A label centred in `parent`, offset by `at`, that grows to `grow`, rises
## by `rise` px and fades over `secs`, then frees itself.
func _float_label(parent: Control, text: String, font_px: float, at: Vector2, grow: Vector2,
		rise: float, secs: float, color: Color = Color(1, 1, 1)) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(font_px))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", int(font_px * 0.12))
	l.size = parent.size
	l.position = at
	l.pivot_offset = parent.size / 2.0
	l.scale = Vector2(0.6, 0.6)
	parent.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", grow, secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", at.y + rise, secs)
	tw.tween_property(l, "modulate:a", 0.0, secs * 0.6).set_delay(secs * 0.4)
	tw.chain().tween_callback(l.queue_free)

func _end_round() -> void:
	for m in mole_labels:
		m.visible = false
	if is_instance_valid(mole_timer):
		mole_timer.queue_free()
	if is_instance_valid(mole_visible_timer):
		mole_visible_timer.queue_free()

	if engine.score > best_score:
		best_score = engine.score
		_save_best()

	_update_labels()
	if info:
		info.add("Rounds played")
		info.best("Best score", best_score)
	result_label.text = tr("Time's up!\nScore: %d") % engine.score
	result_dialog.visible = true
	start_btn.visible = true
	start_btn.text = tr("Play Again")

func _update_labels() -> void:
	score_label.text = tr("Score: %d") % engine.score
	time_label.text = tr("Time: %d") % ceili(engine.time_remaining)
	best_label.text = tr("Best: %d") % best_score

func _style_hole(hole: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = HomeKit.PURPLE if color == COLOR_HOLE else color.lightened(0.4)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(sb.border_color, 0.3)
	sb.shadow_size = 8
	var radius: int = int(hole.custom_minimum_size.x * 0.2)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		hole.add_theme_stylebox_override(state, sb)

# ---------- persistence ----------

func _save_best() -> void:
	SaveUtil.write(BEST_PATH, {"best": best_score})
	if Auth.is_logged_in():
		Auth.push_stat("whackamole_best", best_score)

func _load_best() -> void:
	var data = SaveUtil.read(BEST_PATH)
	best_score = int(data.get("best", 0)) if data != null else 0
	if Auth.is_logged_in():
		# A method, not a lambda: if the player leaves before the reply lands,
		# a method callable on a freed scene is skipped instead of erroring.
		Auth.reconcile_stat("whackamole_best", best_score, _on_best_reconciled)

func _on_best_reconciled(merged: int) -> void:
	best_score = merged
	if info:
		info.high("Best score", merged)
	SaveUtil.write(BEST_PATH, {"best": merged})
	if is_node_ready():  # can land before _build_ui() if the request fails instantly
		_update_labels()

# ---------- auto-pause ----------

## Leaving the app (home button, a phone call) pauses mid-round instead of
## letting the game run on unseen. Pausing the whole tree stops this scene's
## Timers and _process; the dialog itself keeps processing so it can resume.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and engine.running and not get_tree().paused and home:
			home.pause()

func _resume() -> void:
	get_tree().paused = false

func _exit_paused_to_hub() -> void:
	get_tree().paused = false
	Ui.exit_to_hub(self)

## Never leave the tree paused behind us -- the next scene would be frozen.
func _exit_tree() -> void:
	get_tree().paused = false

func _build_pause_dialog() -> void:
	pause_dialog = Ui.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("Exit to Hub"), "action": _exit_paused_to_hub},
	])
	pause_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_dialog)

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/whack_a_mole/whack_a_mole_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/whack_a_mole/whack_a_mole_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Whack as many moles as you can in 30 seconds!",
		"logo": _draw_home_logo,
		"modes": [{"text": "🔨  Play", "sub": "30-second round", "action": _start_round}],
		"restart": _start_round,
		"board_note": "Your best score in one round.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 170.0)
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0 + h * 0.15)
	# a hole, a mole popping out, and the hammer
	var hole := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		hole.append(ctr + Vector2(cos(a) * h * 0.38, sin(a) * h * 0.1))
	HomeKit.glow_polyline(c, hole, HomeKit.PURPLE, 2.5)
	HomeKit.glow_circle(c, ctr + Vector2(0, -h * 0.16), h * 0.17, HomeKit.GOLD, 2.5, 0.25)
	c.draw_circle(ctr + Vector2(-h * 0.06, -h * 0.2), h * 0.025, Color.WHITE)
	c.draw_circle(ctr + Vector2(h * 0.06, -h * 0.2), h * 0.025, Color.WHITE)
	HomeKit.glow_line(c, ctr + Vector2(h * 0.25, -h * 0.55), ctr + Vector2(h * 0.55, -h * 0.25), HomeKit.CYAN, 3.0)
	HomeKit.glow_rect(c, Rect2(ctr + Vector2(h * 0.08, -h * 0.72), Vector2(h * 0.26, h * 0.16)), HomeKit.CYAN, 2.5, 0.2)
