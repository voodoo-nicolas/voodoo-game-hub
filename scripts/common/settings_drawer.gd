extends Control

## A small pull-out tab docked to the right edge, available in every game screen.
## Add with `add_child(SettingsDrawer.new())` as the LAST child in a game's _build_ui()
## so its tab stays clickable even over pause/win dialogs, while everywhere else on
## this full-rect Control lets clicks fall through (mouse_filter = IGNORE) to whatever
## is actually underneath -- the dialog if one is open, or the game board otherwise.
const Orientation = preload("res://scripts/common/orientation.gd")

const TAB_SIZE := 44.0
const DRAWER_WIDTH := 190.0

var is_open: bool = false
var timer_running: bool = false
var timer_elapsed: float = 0.0

var tab_button: Button
var panel: PanelContainer
var timer_label: Label
var timer_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel()
	_build_tab()

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
	tab_button.add_theme_font_size_override("font_size", 24)
	tab_button.focus_mode = Control.FOCUS_NONE
	tab_button.anchor_left = 1.0
	tab_button.anchor_right = 1.0
	tab_button.anchor_top = 0.5
	tab_button.anchor_bottom = 0.5
	tab_button.position = Vector2(-TAB_SIZE, -TAB_SIZE / 2.0)
	tab_button.size = Vector2(TAB_SIZE, TAB_SIZE)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	sb.corner_radius_top_left = 10
	sb.corner_radius_bottom_left = 10
	for state in ["normal", "hover", "pressed", "focus"]:
		tab_button.add_theme_stylebox_override(state, sb)

	tab_button.pressed.connect(_toggle_drawer)
	add_child(tab_button)

func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
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
	title.text = "Quick Settings"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	box.add_child(title)

	timer_label = Label.new()
	timer_label.text = "00:00"
	timer_label.add_theme_font_size_override("font_size", 26)
	timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(timer_label)

	timer_button = Button.new()
	timer_button.text = "▶ Start Timer"
	timer_button.pressed.connect(_on_timer_toggle)
	box.add_child(timer_button)

	var reset_btn := Button.new()
	reset_btn.text = "↺ Reset Timer"
	reset_btn.pressed.connect(_on_timer_reset)
	box.add_child(reset_btn)

	var sep := HSeparator.new()
	box.add_child(sep)

	var rotate_btn := Button.new()
	rotate_btn.text = "🔄 Rotate Screen"
	rotate_btn.pressed.connect(_on_rotate_pressed)
	box.add_child(rotate_btn)

	var screenshot_btn := Button.new()
	screenshot_btn.text = "📷 Screenshot"
	screenshot_btn.pressed.connect(_on_screenshot_pressed)
	box.add_child(screenshot_btn)

	var hub_btn := Button.new()
	hub_btn.text = "🏠 Main Hub"
	hub_btn.pressed.connect(_on_hub_pressed)
	box.add_child(hub_btn)

	# vertical size isn't known until children are laid out; center after one frame
	call_deferred("_center_panel")

func _center_panel() -> void:
	panel.position = Vector2(-TAB_SIZE - DRAWER_WIDTH, -panel.size.y / 2.0)

func _toggle_drawer() -> void:
	is_open = not is_open
	panel.visible = is_open
	tab_button.text = "✕" if is_open else "⚙"
	if is_open:
		_center_panel()

func _on_timer_toggle() -> void:
	timer_running = not timer_running
	timer_button.text = "⏸ Pause Timer" if timer_running else "▶ Start Timer"

func _on_timer_reset() -> void:
	timer_running = false
	timer_elapsed = 0.0
	timer_label.text = "00:00"
	timer_button.text = "▶ Start Timer"

func _on_rotate_pressed() -> void:
	_save_current_scene_if_possible()
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x > vp_size.y:
		Orientation.lock_portrait()
	else:
		Orientation.lock_landscape()
	get_tree().reload_current_scene()

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

	_show_toast("Screenshot saved!")

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

	await get_tree().create_timer(0.01).timeout
	toast_panel.position = Vector2(-toast_panel.size.x / 2.0, 0)

	await get_tree().create_timer(1.5).timeout
	toast_panel.queue_free()
