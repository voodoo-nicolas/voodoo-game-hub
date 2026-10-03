extends Control

## A small pull-out tab docked to the right edge, available in every game screen.
## Add with `add_child(SettingsDrawer.new())` as the LAST child in a game's _build_ui()
## so its tab stays clickable even over pause/win dialogs, while everywhere else on
## this full-rect Control lets clicks fall through (mouse_filter = IGNORE) to whatever
## is actually underneath -- the dialog if one is open, or the game board otherwise.
##
## The tab is the only floating button in a game: GameInfo's "How to Play"
## lives inside the drawer. It sits low on the right edge, half see-through,
## and the player can drag it up or down; where it was left is remembered
## per game (`user://drawer_pos.json`).
const Orientation = preload("res://scripts/common/orientation.gd")
const Voodoo = preload("res://scripts/common/voodoo.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")

const TAB_SIZE := 40.0
const DRAWER_WIDTH := 210.0
const POS_PATH := "user://drawer_pos.json"
## Default height of the tab's centre, as a fraction of the screen.
const DEFAULT_FRAC := 0.94
## How far a press must move before it's a drag rather than a tap.
const DRAG_SLOP := 10.0
const IDLE_ALPHA := 0.55

var is_open: bool = false
var timer_running: bool = false
var timer_elapsed: float = 0.0

var tab_button: Button
var panel: PanelContainer
var timer_label: Label
var timer_button: Button
var voodoo_button: Button

var _frac: float = DEFAULT_FRAC
var _press_y: float = -1.0
var _dragged: bool = false

func _ready() -> void:
	# In the tree already, so set_anchors_preset alone would keep our 0×0 size
	# and the tab would sit off-screen above the top-left corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frac = _load_frac()
	_build_panel()
	_build_tab()
	resized.connect(_place_tab)

func _process(delta: float) -> void:
	if timer_running:
		timer_elapsed += delta
		timer_label.text = _format_time(timer_elapsed)

func _format_time(s: float) -> String:
	var total := int(s)
	return "%02d:%02d" % [int(total / 60), total % 60]

func _build_tab() -> void:
	tab_button = Button.new()
	tab_button.text = "⚙"
	tab_button.add_theme_font_size_override("font_size", 22)
	tab_button.focus_mode = Control.FOCUS_NONE
	tab_button.anchor_left = 1.0
	tab_button.anchor_right = 1.0
	tab_button.offset_left = -TAB_SIZE
	tab_button.offset_right = 0.0
	tab_button.modulate.a = IDLE_ALPHA

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	sb.corner_radius_top_left = 10
	sb.corner_radius_bottom_left = 10
	for state in ["normal", "hover", "pressed", "focus"]:
		tab_button.add_theme_stylebox_override(state, sb)

	tab_button.pressed.connect(_on_tab_pressed)
	tab_button.gui_input.connect(_on_tab_input)
	add_child(tab_button)
	_place_tab()

## Anchored at _frac of the height, clamped so it never leaves the screen.
func _place_tab() -> void:
	if tab_button == null:
		return
	var h: float = size.y
	var half := TAB_SIZE / 2.0
	var y := _frac * h
	if h > TAB_SIZE:
		y = clampf(y, half, h - half)
	tab_button.anchor_top = 0.0
	tab_button.anchor_bottom = 0.0
	tab_button.offset_top = y - half
	tab_button.offset_bottom = y + half
	if is_open:
		_center_panel()

func _on_tab_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_y = event.global_position.y
			_dragged = false
		elif _dragged:
			_save_frac()
			_press_y = -1.0
	elif event is InputEventMouseMotion and _press_y >= 0.0:
		var dy: float = event.global_position.y - _press_y
		if _dragged or absf(dy) > DRAG_SLOP:
			_dragged = true
			var local_y: float = event.global_position.y - global_position.y
			_frac = clampf(local_y / maxf(size.y, 1.0), 0.0, 1.0)
			_place_tab()

func _on_tab_pressed() -> void:
	if _dragged:  # the release that ended a drag isn't a tap
		_dragged = false
		return
	_toggle_drawer()

func _load_frac() -> float:
	var data = SaveUtil.read(POS_PATH)
	var key := _scene_key()
	if data != null and data.has(key):
		return clampf(float(data[key]), 0.0, 1.0)
	return DEFAULT_FRAC

func _save_frac() -> void:
	var data = SaveUtil.read(POS_PATH)
	if data == null:
		data = {}
	data[_scene_key()] = snappedf(_frac, 0.001)
	SaveUtil.write(POS_PATH, data)

func _scene_key() -> String:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene and scene.scene_file_path != "":
		return scene.scene_file_path
	return get_parent().scene_file_path if get_parent() else "default"

## GameInfo (the How to Play card), if this game has one: a sibling with open().
func _find_game_info() -> Node:
	if get_parent() == null:
		return null
	for c in get_parent().get_children():
		if c != self and c.has_method("open") and c.has_method("celebrate"):
			return c
	return null

func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.custom_minimum_size = Vector2(DRAWER_WIDTH, 0)
	panel.visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.13, 0.17, 0.97)
	sb.corner_radius_top_left = 14
	sb.corner_radius_bottom_left = 14
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("Quick Settings")
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	box.add_child(title)

	if _find_game_info():
		var help_btn := Button.new()
		help_btn.text = tr("❓ How to Play")
		help_btn.pressed.connect(_on_help_pressed)
		box.add_child(help_btn)

	timer_label = Label.new()
	timer_label.text = "00:00"
	timer_label.add_theme_font_size_override("font_size", 26)
	timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(timer_label)

	timer_button = Button.new()
	timer_button.text = tr("▶ Start Timer")
	timer_button.pressed.connect(_on_timer_toggle)
	box.add_child(timer_button)

	var reset_btn := Button.new()
	reset_btn.text = tr("↺ Reset Timer")
	reset_btn.pressed.connect(_on_timer_reset)
	box.add_child(reset_btn)

	var sep := HSeparator.new()
	box.add_child(sep)

	var rotate_btn := Button.new()
	rotate_btn.text = tr("🔄 Rotate Screen")
	rotate_btn.pressed.connect(_on_rotate_pressed)
	box.add_child(rotate_btn)

	# Only games that support the skin (they define _set_voodoo) get the toggle.
	if get_parent() and get_parent().has_method("_set_voodoo"):
		voodoo_button = Button.new()
		voodoo_button.pressed.connect(_on_voodoo_pressed)
		box.add_child(voodoo_button)
		_update_voodoo_button()

	var screenshot_btn := Button.new()
	screenshot_btn.text = tr("📷 Screenshot")
	screenshot_btn.pressed.connect(_on_screenshot_pressed)
	box.add_child(screenshot_btn)

	var hub_btn := Button.new()
	hub_btn.text = tr("🏠 Main Hub")
	hub_btn.pressed.connect(_on_hub_pressed)
	box.add_child(hub_btn)


## Beside the tab, centred on it but kept fully on screen. Offsets, not
## `position`: position is measured from our top-left corner, so the old
## `position = (-width, ...)` put the whole drawer off-screen.
func _center_panel() -> void:
	var w: float = maxf(DRAWER_WIDTH, panel.get_combined_minimum_size().x)
	var h: float = panel.get_combined_minimum_size().y
	var tab_mid: float = (tab_button.offset_top + tab_button.offset_bottom) / 2.0
	var top: float = clampf(tab_mid - h / 2.0, 4.0, maxf(4.0, size.y - h - 4.0))
	panel.offset_right = -TAB_SIZE - 4.0
	panel.offset_left = panel.offset_right - w
	panel.offset_top = top
	panel.offset_bottom = top + h

func _toggle_drawer() -> void:
	is_open = not is_open
	panel.visible = is_open
	tab_button.text = "✕" if is_open else "⚙"
	tab_button.modulate.a = 1.0 if is_open else IDLE_ALPHA
	if is_open:
		_center_panel()

func _on_help_pressed() -> void:
	_toggle_drawer()
	var info := _find_game_info()
	if info:
		info.open()

func _on_timer_toggle() -> void:
	timer_running = not timer_running
	timer_button.text = tr("⏸ Pause Timer") if timer_running else tr("▶ Start Timer")

func _on_timer_reset() -> void:
	timer_running = false
	timer_elapsed = 0.0
	timer_label.text = "00:00"
	timer_button.text = tr("▶ Start Timer")

func _on_rotate_pressed() -> void:
	_save_current_scene_if_possible()
	var vp_size: Vector2 = get_viewport_rect().size
	# The reloaded scene's _ready() re-locks its default orientation; the
	# override makes that one call rotate instead.
	Orientation.override_next(vp_size.x <= vp_size.y)
	get_tree().reload_current_scene()

func _update_voodoo_button() -> void:
	voodoo_button.text = tr("💀 Voodoo: On") if Voodoo.is_on() else tr("💀 Voodoo: Off")

## Re-skins the game in place rather than reloading it, so an online match
## keeps going.
func _on_voodoo_pressed() -> void:
	var on := not Voodoo.is_on()
	Voodoo.set_on(on)
	_update_voodoo_button()
	get_parent()._set_voodoo(on)

func _on_hub_pressed() -> void:
	_save_current_scene_if_possible()
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

func _save_current_scene_if_possible() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene and current_scene.has_method("_save_game"):
		current_scene._save_game()

func _on_screenshot_pressed() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var dir := "user://screenshots"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_absolute(dir)
	var stamp: int = Time.get_unix_time_from_system()
	img.save_png("%s/screenshot_%d.png" % [dir, stamp])

	# Best-effort: also try the device's public Pictures folder so it's easy to find
	# and share. This can silently no-op on newer Android's scoped storage -- the
	# user:// copy above is the guaranteed fallback either way.
	var pictures_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures_dir != "":
		img.save_png(pictures_dir.path_join("voodoo_screenshot_%d.png" % stamp))

	_show_toast(tr("Screenshot saved!"))

func _show_toast(text: String) -> void:
	var toast_panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.85)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	toast_panel.add_theme_stylebox_override("panel", sb)
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_top = 0.92
	toast_panel.anchor_bottom = 0.92
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	toast_panel.add_child(label)
	add_child(toast_panel)

	# grow_horizontal BOTH centers it on the anchor without waiting a frame
	# for its size. The tween belongs to the toast, so leaving the scene
	# mid-toast just frees both -- no timer resuming into a freed node.
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var tween := toast_panel.create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(toast_panel.queue_free)
