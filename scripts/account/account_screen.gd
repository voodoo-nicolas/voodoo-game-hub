extends Control

const Orientation = preload("res://scripts/common/orientation.gd")

var mode_sign_up: bool = false

var display_name_row: VBoxContainer
var display_name_field: LineEdit
var email_field: LineEdit
var password_field: LineEdit
var submit_btn: Button
var sign_in_tab: Button
var sign_up_tab: Button
var forgot_btn: Button
var status_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	_build_ui()
	Auth.signed_in.connect(_on_signed_in)
	Auth.auth_error.connect(_on_auth_error)

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
	title.text = "Account"
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
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(280, 0)
	center.add_child(box)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	box.add_child(tab_row)

	sign_in_tab = Button.new()
	sign_in_tab.text = "Sign In"
	sign_in_tab.custom_minimum_size = Vector2(0, 46)
	sign_in_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_in_tab.add_theme_font_size_override("font_size", 17)
	sign_in_tab.focus_mode = Control.FOCUS_NONE
	sign_in_tab.pressed.connect(func(): _set_mode(false))
	tab_row.add_child(sign_in_tab)

	sign_up_tab = Button.new()
	sign_up_tab.text = "Sign Up"
	sign_up_tab.custom_minimum_size = Vector2(0, 46)
	sign_up_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_up_tab.add_theme_font_size_override("font_size", 17)
	sign_up_tab.focus_mode = Control.FOCUS_NONE
	sign_up_tab.pressed.connect(func(): _set_mode(true))
	tab_row.add_child(sign_up_tab)

	var sep := HSeparator.new()
	box.add_child(sep)

	display_name_row = VBoxContainer.new()
	display_name_row.add_theme_constant_override("separation", 4)
	box.add_child(display_name_row)
	var dn_label := Label.new()
	dn_label.text = "Display name"
	dn_label.add_theme_font_size_override("font_size", 13)
	dn_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	display_name_row.add_child(dn_label)
	display_name_field = LineEdit.new()
	display_name_field.placeholder_text = "What should we call you?"
	display_name_field.custom_minimum_size = Vector2(0, 44)
	display_name_row.add_child(display_name_field)

	var email_label := Label.new()
	email_label.text = "Email"
	email_label.add_theme_font_size_override("font_size", 13)
	email_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	box.add_child(email_label)
	email_field = LineEdit.new()
	email_field.placeholder_text = "you@example.com"
	email_field.custom_minimum_size = Vector2(0, 44)
	box.add_child(email_field)

	var password_label := Label.new()
	password_label.text = "Password"
	password_label.add_theme_font_size_override("font_size", 13)
	password_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	box.add_child(password_label)
	password_field = LineEdit.new()
	password_field.secret = true
	password_field.placeholder_text = "At least 6 characters"
	password_field.custom_minimum_size = Vector2(0, 44)
	box.add_child(password_field)

	submit_btn = Button.new()
	submit_btn.custom_minimum_size = Vector2(0, 52)
	submit_btn.add_theme_font_size_override("font_size", 18)
	submit_btn.pressed.connect(_on_submit)
	box.add_child(submit_btn)

	forgot_btn = Button.new()
	forgot_btn.text = "Forgot password?"
	forgot_btn.flat = true
	forgot_btn.pressed.connect(_on_forgot_password)
	box.add_child(forgot_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(status_label)

	_update_mode_ui()

func _set_mode(is_sign_up: bool) -> void:
	if mode_sign_up == is_sign_up:
		return
	mode_sign_up = is_sign_up
	status_label.text = ""
	_update_mode_ui()

func _update_mode_ui() -> void:
	display_name_row.visible = mode_sign_up
	forgot_btn.visible = not mode_sign_up
	submit_btn.text = "Create Account" if mode_sign_up else "Sign In"
	_style_tab(sign_in_tab, not mode_sign_up)
	_style_tab(sign_up_tab, mode_sign_up)

## Active tab gets a filled neon-green background (matching the hub's own
## accent color) so it's unmistakably the one you're on; the inactive tab
## stays visible but clearly secondary. Previously this was a single small
## flat text toggle, which a real user testing this build could not find --
## don't reintroduce a low-visibility way to reach sign-up.
func _style_tab(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.45, 0.28) if active else Color(0.16, 0.16, 0.2)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.15, 1.0, 0.55) if active else Color(0.35, 0.35, 0.4)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1) if active else Color(0.65, 0.65, 0.7))

func _on_submit() -> void:
	var email: String = email_field.text.strip_edges()
	var password: String = password_field.text
	if email == "" or password == "":
		_show_status("Enter an email and password.", false)
		return

	submit_btn.disabled = true
	if mode_sign_up:
		var chosen_name: String = display_name_field.text.strip_edges()
		_show_status("Creating your account...", true)
		Auth.sign_up(email, password, chosen_name if chosen_name != "" else "Player")
	else:
		_show_status("Signing in...", true)
		Auth.sign_in(email, password)

func _on_forgot_password() -> void:
	var email: String = email_field.text.strip_edges()
	if email == "":
		_show_status("Enter your email above first, then tap Forgot password.", false)
		return
	Auth.request_password_reset(email)
	_show_status("If that email has an account, a reset link is on its way.", true)

func _on_signed_in(_user_id: String, name: String) -> void:
	submit_btn.disabled = false
	_show_status("Signed in as %s!" % name, true)
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

func _on_auth_error(_context: String, message: String) -> void:
	submit_btn.disabled = false
	_show_status(message, false)

func _show_status(text: String, positive: bool) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6) if positive else Color(0.9, 0.5, 0.4))
