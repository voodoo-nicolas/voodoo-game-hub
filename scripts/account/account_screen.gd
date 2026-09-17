extends Control

const Orientation = preload("res://scripts/common/orientation.gd")

var mode_sign_up: bool = false

var display_name_row: VBoxContainer
var display_name_field: LineEdit
var email_field: LineEdit
var password_field: LineEdit
var submit_btn: Button
var toggle_btn: Button
var forgot_btn: Button
var status_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	_build_ui()
	Auth.signed_in.connect(_on_signed_in)
	Auth.auth_error.connect(_on_auth_error)

func _exit_tree() -> void:
	if Auth.signed_in.is_connected(_on_signed_in):
		Auth.signed_in.disconnect(_on_signed_in)
	if Auth.auth_error.is_connected(_on_auth_error):
		Auth.auth_error.disconnect(_on_auth_error)

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

	toggle_btn = Button.new()
	toggle_btn.flat = true
	toggle_btn.pressed.connect(_toggle_mode)
	box.add_child(toggle_btn)

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

func _toggle_mode() -> void:
	mode_sign_up = not mode_sign_up
	status_label.text = ""
	_update_mode_ui()

func _update_mode_ui() -> void:
	display_name_row.visible = mode_sign_up
	forgot_btn.visible = not mode_sign_up
	submit_btn.text = "Create Account" if mode_sign_up else "Sign In"
	toggle_btn.text = "Already have an account? Sign in" if mode_sign_up else "New here? Create an account"

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
