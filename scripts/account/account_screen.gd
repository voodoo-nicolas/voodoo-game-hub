extends Control

const Orientation = preload("res://scripts/common/orientation.gd")
const Consent = preload("res://scripts/common/consent.gd")

var mode_sign_up: bool = false

var display_name_row: VBoxContainer
var display_name_field: LineEdit
var email_field: LineEdit
var password_field: LineEdit
var show_password_check: CheckBox
var submit_btn: Button
var sign_in_tab: Button
var sign_up_tab: Button
var forgot_btn: Button
var status_label: Label
var social_box: VBoxContainer
## True between opening Google/Facebook in the browser and getting the code back.
var waiting_for_code: bool = false
var remember_check: CheckBox
var quick_box: VBoxContainer
var _confirm: Control
var _other_btn: Button
var _form_nodes: Array = []
var _form_shown := true
var _drag: Node   # drag_scroll.gd: a drag that started on a button doesn't press it

func _ready() -> void:
	Orientation.lock_portrait()
	_build_ui()
	Auth.signed_in.connect(_on_signed_in)
	Auth.auth_error.connect(_on_auth_error)
	Auth.reset_requested.connect(_on_reset_requested)
	# Back from the consent screens with a sign-up half filled in.
	if not Consent.draft.is_empty():
		var provider := str(Consent.draft.get("oauth", ""))
		_set_mode(bool(Consent.draft.get("sign_up", false)))
		email_field.text = str(Consent.draft.get("email", ""))
		display_name_field.text = str(Consent.draft.get("name", ""))
		Consent.draft = {}
		if provider != "" and Consent.has_accepted():
			_on_oauth(provider)

## The sign-in code is copied by the callback page; when the player comes back
## to the app, pick it up from the clipboard.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and waiting_for_code:
		_try_clipboard_code()

func _try_clipboard_code() -> void:
	var clip := DisplayServer.clipboard_get()
	if Auth.looks_like_code(clip):
		waiting_for_code = false
		DisplayServer.clipboard_set("")
		_show_status(tr("Signing in..."), true)
		Auth.sign_in_with_code(clip)

func _on_paste_code() -> void:
	var clip := DisplayServer.clipboard_get()
	if Auth.looks_like_code(clip):
		_try_clipboard_code()
	else:
		_show_status(tr("Nothing to paste yet. Sign in with Google or Facebook in the browser, copy the code, then tap this."), false)

func _on_oauth(provider: String) -> void:
	# A brand-new account made this way still needs the age gate and the acceptances.
	if Consent.is_blocked():
		_show_status(tr("Accounts are for players %d and older. You can still play every game without an account.") % Consent.min_age(), false)
		return
	if not Consent.has_accepted():
		Consent.draft = {"sign_up": true, "oauth": provider}
		Consent.return_scene = Consent.ACCOUNT_SCENE
		get_tree().change_scene_to_file(Consent.CONSENT_SCENE)
		return
	_show_status(tr("Signing in..."), true)
	Auth.provider_enabled(provider, _on_provider_checked.bind(provider))

func _on_provider_checked(enabled, provider: String) -> void:
	# enabled == null: couldn't tell (offline); the browser will show what's wrong.
	if enabled == false:
		_show_status(tr("%s sign-in isn't available yet. Use your email and password for now.") % provider.capitalize(), false)
		return
	waiting_for_code = true
	_show_status(tr("Finish signing in in your browser, then come back here."), true)
	OS.shell_open(Auth.oauth_url(provider))

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
	hub_btn.text = tr("Hub")
	# A real tap target (it was text-sized; owner 2026-11-20: ease of use).
	hub_btn.text = "← " + tr("Hub")
	hub_btn.custom_minimum_size = Vector2(120, 60)
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(_go_to_hub)
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("Account")
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(spacer)

	# var center := CenterContainer.new()
	# center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# root.add_child(center)
	# Scrolls when it doesn't fit (remembered accounts + the form, text size 1.4), centred when it does.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_drag = preload("res://scripts/common/drag_scroll.gd").new()
	scroll.add_child(_drag)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	scroll.resized.connect(func(): center.custom_minimum_size.y = scroll.size.y)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(minf(620.0, get_viewport_rect().size.x - 48.0), 0)
	center.add_child(box)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	box.add_child(tab_row)

	sign_in_tab = Button.new()
	sign_in_tab.text = tr("Sign In")
	sign_in_tab.custom_minimum_size = Vector2(0, 64)
	sign_in_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_in_tab.add_theme_font_size_override("font_size", 28)
	sign_in_tab.focus_mode = Control.FOCUS_NONE
	sign_in_tab.pressed.connect(func(): _set_mode(false))
	tab_row.add_child(sign_in_tab)

	sign_up_tab = Button.new()
	sign_up_tab.text = tr("Sign Up")
	sign_up_tab.custom_minimum_size = Vector2(0, 64)
	sign_up_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_up_tab.add_theme_font_size_override("font_size", 28)
	sign_up_tab.focus_mode = Control.FOCUS_NONE
	sign_up_tab.pressed.connect(func(): _set_mode(true))
	tab_row.add_child(sign_up_tab)

	var sep := HSeparator.new()
	box.add_child(sep)

	# Quick sign-in (owner 2026-11-20): this device's remembered accounts. Tap, confirm, done.
	quick_box = VBoxContainer.new()
	quick_box.add_theme_constant_override("separation", 10)
	box.add_child(quick_box)
	box.move_child(quick_box, 0)   # first thing on the screen: the fastest way in
	_fill_quick_box()

	display_name_row = VBoxContainer.new()
	display_name_row.add_theme_constant_override("separation", 4)
	box.add_child(display_name_row)
	var dn_label := Label.new()
	dn_label.text = tr("Display name")
	dn_label.add_theme_font_size_override("font_size", 26)
	dn_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	display_name_row.add_child(dn_label)
	display_name_field = LineEdit.new()
	display_name_field.placeholder_text = tr("What should we call you?")
	display_name_field.custom_minimum_size = Vector2(0, 72)
	display_name_field.add_theme_font_size_override("font_size", 28)
	display_name_row.add_child(display_name_field)

	var email_label := Label.new()
	email_label.text = tr("Email")
	email_label.add_theme_font_size_override("font_size", 26)
	email_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	box.add_child(email_label)
	email_field = LineEdit.new()
	email_field.placeholder_text = tr("you@example.com")
	email_field.custom_minimum_size = Vector2(0, 72)
	email_field.add_theme_font_size_override("font_size", 28)
	box.add_child(email_field)

	var password_label := Label.new()
	password_label.text = tr("Password")
	password_label.add_theme_font_size_override("font_size", 26)
	password_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	box.add_child(password_label)
	password_field = LineEdit.new()
	password_field.secret = true
	password_field.placeholder_text = tr("At least 6 characters")
	password_field.custom_minimum_size = Vector2(0, 72)
	password_field.add_theme_font_size_override("font_size", 28)
	box.add_child(password_field)

	show_password_check = CheckBox.new()
	show_password_check.text = tr("Show password")
	show_password_check.add_theme_font_size_override("font_size", 26)
	show_password_check.focus_mode = Control.FOCUS_NONE
	show_password_check.toggled.connect(_on_show_password_toggled)
	box.add_child(show_password_check)

	# Remember me (owner 2026-11-20): next time this account is two taps away (On this device).
	remember_check = CheckBox.new()
	remember_check.text = tr("Remember me on this device")
	remember_check.add_theme_font_size_override("font_size", 26)
	remember_check.focus_mode = Control.FOCUS_NONE
	remember_check.button_pressed = Auth.remember_me
	remember_check.toggled.connect(Auth.set_remember_me)
	box.add_child(remember_check)

	submit_btn = Button.new()
	submit_btn.custom_minimum_size = Vector2(0, 76)
	submit_btn.add_theme_font_size_override("font_size", 30)
	submit_btn.pressed.connect(_on_submit)
	_quick_style(submit_btn, true)   # the main action looks like one (was plain text)
	box.add_child(submit_btn)

	forgot_btn = Button.new()
	forgot_btn.text = tr("Forgot password?")
	forgot_btn.flat = true
	forgot_btn.add_theme_font_size_override("font_size", 24)
	forgot_btn.pressed.connect(_on_forgot_password)
	box.add_child(forgot_btn)

	social_box = VBoxContainer.new()
	social_box.add_theme_constant_override("separation", 8)
	box.add_child(social_box)
	var or_label := Label.new()
	or_label.text = tr("or continue with")
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	or_label.add_theme_font_size_override("font_size", 22)
	or_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	social_box.add_child(or_label)
	for spec in [["google", "Google"], ["facebook", "Facebook"]]:
		var b := Button.new()
		b.text = tr("Continue with %s") % spec[1]
		b.custom_minimum_size = Vector2(0, 68)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_on_oauth.bind(spec[0]))
		_quick_style(b, false)
		social_box.add_child(b)
	var paste := Button.new()
	paste.text = tr("Paste sign-in code")
	paste.flat = true
	paste.add_theme_font_size_override("font_size", 24)
	paste.pressed.connect(_on_paste_code)
	social_box.add_child(paste)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(status_label)

	_update_mode_ui()
	# With remembered accounts, the long form waits behind "Sign in another way" (cleaner, and it
	# can't push Google / Facebook off a small phone).
	for c in box.get_children():
		if c != quick_box and c != status_label:
			_form_nodes.append(c)
	_show_form(Auth.known_accounts().is_empty() or not Consent.draft.is_empty())

func _on_show_password_toggled(on: bool) -> void:
	password_field.secret = not on

func _set_mode(is_sign_up: bool) -> void:
	if mode_sign_up == is_sign_up:
		return
	mode_sign_up = is_sign_up
	status_label.text = ""
	_update_mode_ui()

func _update_mode_ui() -> void:
	display_name_row.visible = mode_sign_up
	forgot_btn.visible = not mode_sign_up
	submit_btn.text = tr("Create Account") if mode_sign_up else tr("Sign In")
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
		_show_status(tr("Enter an email and password."), false)
		return

	if mode_sign_up:
		# No account without the age gate and the two acceptances (compliance pack).
		if Consent.is_blocked():
			_show_status(tr("Accounts are for players %d and older. You can still play every game without an account.") % Consent.min_age(), false)
			return
		if not Consent.has_accepted():
			Consent.draft = {"sign_up": true, "email": email, "name": display_name_field.text.strip_edges()}
			Consent.return_scene = Consent.ACCOUNT_SCENE
			get_tree().change_scene_to_file(Consent.CONSENT_SCENE)
			return
	submit_btn.disabled = true
	if mode_sign_up:
		var chosen_name: String = display_name_field.text.strip_edges()
		_show_status(tr("Creating your account..."), true)
		Auth.sign_up(email, password, chosen_name if chosen_name != "" else "Player")
	else:
		_show_status(tr("Signing in..."), true)
		Auth.sign_in(email, password)

func _on_forgot_password() -> void:
	var email: String = email_field.text.strip_edges()
	if email == "":
		_show_status(tr("Enter your email above first, then tap Forgot password."), false)
		return
	forgot_btn.disabled = true
	_show_status(tr("Sending..."), true)
	Auth.request_password_reset(email)

func _on_reset_requested(ok: bool, message: String) -> void:
	forgot_btn.disabled = false
	if ok:
		_show_status(tr("If that email has an account, a reset link is on its way. Check your spam folder too."), true)
	else:
		_show_status(tr(message), false)

func _on_signed_in(_user_id: String, name: String) -> void:
	submit_btn.disabled = false
	_show_status(tr("Signed in as %s!") % name, true)
	# Timer owned by this scene: if the player taps Hub first, it's freed
	# along with the scene instead of firing into a node that's gone.
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 0.6
	# An account that hasn't accepted the current Terms/Privacy yet (made before
	# this screen existed, or a newer version) is asked on the way in.
	t.timeout.connect(_after_sign_in)
	add_child(t)
	t.start()

func _after_sign_in() -> void:
	# Accepted before on this account (then the app was reinstalled)? Not asked again.
	Consent.restore(_after_consent_restore)

func _after_consent_restore() -> void:
	if Consent.needs_prompt():
		Consent.return_scene = Consent.HUB_SCENE
		get_tree().change_scene_to_file(Consent.CONSENT_SCENE)
	else:
		_go_to_hub()

func _go_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

# ---------- On this device: quick sign-in (owner 2026-11-20) ----------

const QUICK_GREEN := Color(0.08, 1.0, 0.55)

func _fill_quick_box() -> void:
	for c in quick_box.get_children():
		c.queue_free()
	var accounts: Array = Auth.known_accounts()
	quick_box.visible = not accounts.is_empty()
	if accounts.is_empty():
		return
	var welcome := Label.new()
	welcome.text = tr("Welcome back! Who's playing?")
	welcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	welcome.add_theme_font_size_override("font_size", 32)
	quick_box.add_child(welcome)
	var head := Label.new()
	head.text = tr("On this device")
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	quick_box.add_child(head)
	for a in accounts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		quick_box.add_child(row)
		var b := Button.new()
		var hint := str(a.email_hint)
		b.text = "👤  " + str(a.name) + ("\n      " + hint if hint != "" else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 27)
		b.focus_mode = Control.FOCUS_ALL
		_quick_style(b, false)
		b.pressed.connect(_on_quick_pick.bind(a))
		row.add_child(b)
		var x := Button.new()
		x.text = "✕"
		x.tooltip_text = tr("Forget this account on this device")
		x.custom_minimum_size = Vector2(72, 84)
		x.add_theme_font_size_override("font_size", 26)
		x.pressed.connect(_on_quick_forget.bind(a))
		row.add_child(x)
	_other_btn = Button.new()
	_other_btn.text = tr("Sign in another way ▾")
	_other_btn.flat = true
	_other_btn.custom_minimum_size = Vector2(0, 64)
	_other_btn.add_theme_font_size_override("font_size", 24)
	_other_btn.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	_other_btn.pressed.connect(func(): _show_form(not _form_shown))
	quick_box.add_child(_other_btn)

## The email / Google / Facebook part: shown, or folded behind "Sign in another way".
func _show_form(on: bool) -> void:
	_form_shown = on
	for n in _form_nodes:
		if is_instance_valid(n):
			n.visible = on
	if on:
		_update_mode_ui()   # the name row's own rule
	if _other_btn != null and is_instance_valid(_other_btn):
		_other_btn.text = tr("Hide other ways ▴") if on else tr("Sign in another way ▾")

func _quick_style(b: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.32, 0.2) if primary else Color(0.12, 0.14, 0.2)
		if state == "hover" or state == "pressed":
			sb.bg_color = sb.bg_color.lightened(0.12)
		sb.border_color = QUICK_GREEN if (primary or state == "focus") else Color(0.25, 0.3, 0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		b.add_theme_stylebox_override(state, sb)

## Tap 1: who. A small card asks to confirm (tap 2), so a shared phone isn't one stray tap away.
func _on_quick_pick(a: Dictionary) -> void:
	if _drag != null and _drag.moved:
		return
	_close_confirm()
	var hint := str(a.email_hint)
	_confirm = _confirm_card(tr("Sign in as %s?") % str(a.name), hint, tr("Sign in"), _on_quick_confirm.bind(a))

func _on_quick_confirm(a: Dictionary) -> void:
	_close_confirm()
	_show_status(tr("Signing in..."), true)
	Auth.quick_sign_in(str(a.user_id), _on_quick_done)

func _on_quick_done(ok: bool, why: String) -> void:
	if not is_inside_tree() or ok:
		return   # ok: _on_signed_in takes it from here
	_fill_quick_box()
	_show_form(_form_shown or Auth.known_accounts().is_empty())
	if why == "offline":
		_show_status(tr("No internet connection. Connect and try again."), false)
	else:
		_show_status(tr("That sign-in has expired. Sign in once more and it's remembered again."), false)

func _on_quick_forget(a: Dictionary) -> void:
	if _drag != null and _drag.moved:
		return
	_close_confirm()
	_confirm = _confirm_card(tr("Forget %s on this device?") % str(a.name),
		tr("You'll need your email and password (or Google / Facebook) next time."), tr("Forget"), _on_forget_confirm.bind(a))

func _on_forget_confirm(a: Dictionary) -> void:
	_close_confirm()
	Auth.forget_account(str(a.user_id))
	_fill_quick_box()
	_show_form(_form_shown or Auth.known_accounts().is_empty())

func _close_confirm() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = null

## A dim layer with a small card: title, a line, [action] and Cancel. Fades in.
func _confirm_card(title_text: String, line: String, action: String, on_yes: Callable) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.add_to_group("modal_overlay")   # the list behind doesn't scroll under the card
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.18)
	sb.border_color = QUICK_GREEN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(26)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x - 48.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var t := Label.new()
	t.text = title_text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 30)
	v.add_child(t)
	if line != "":
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 23)
		l.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		v.add_child(l)
	var yes := Button.new()
	yes.text = action
	yes.custom_minimum_size = Vector2(0, 76)
	yes.add_theme_font_size_override("font_size", 28)
	_quick_style(yes, true)
	yes.pressed.connect(on_yes)
	v.add_child(yes)
	var no := Button.new()
	no.text = tr("Cancel")
	no.flat = true
	no.custom_minimum_size = Vector2(0, 64)
	no.add_theme_font_size_override("font_size", 25)
	no.pressed.connect(_close_confirm)
	v.add_child(no)
	dim.modulate.a = 0.0
	create_tween().tween_property(dim, "modulate:a", 1.0, 0.14)
	yes.grab_focus.call_deferred()   # Enter / A on a pad confirms
	return dim

func _on_auth_error(_context: String, message: String) -> void:
	submit_btn.disabled = false
	_show_status(tr(message), false)

func _show_status(text: String, positive: bool) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6) if positive else Color(0.9, 0.5, 0.4))
