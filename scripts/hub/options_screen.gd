extends Control

## The ⚙ Options screen, opened from the hub. Every value lives in the
## `Settings` autoload (text size, theme, sound -- drawn by sound_options.gd,
## shared with the in-game drawer -- vibration, keep screen on),
## `Lang` (language) or voodoo.gd (skull mode); this file only draws them.
##
## Text size, theme and language reload this scene to apply (sizes and
## translated text are fixed when a scene is built); the on/off rows just
## restyle their own button.

const Orientation = preload("res://scripts/common/orientation.gd")
const Version = preload("res://scripts/common/version.gd")
const Config = preload("res://scripts/common/config.gd")
const Voodoo = preload("res://scripts/common/voodoo.gd")
const DragScroll = preload("res://scripts/common/drag_scroll.gd")
const Mist = preload("res://scripts/common/mist.gd")
const Brand = preload("res://scripts/common/brand.gd")
const SoundOptions = preload("res://scripts/common/sound_options.gd")

const FEEDBACK_URL := Config.REPO_URL + "/issues/new"

var pal: Dictionary
var drag: Node
var account_label: Label
var account_btn: Button
var update_label: Label
var update_btn: Button
var update_url: String = ""

var storage_box: VBoxContainer
var credits_box: VBoxContainer

func _ready() -> void:
	Orientation.lock_portrait()
	pal = Settings.palette()
	_build_ui()
	# Plain method callables (see CLAUDE.md): freed with this scene.
	Auth.signed_in.connect(_update_account.unbind(2))
	Auth.signed_out.connect(_update_account)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_to_hub()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if Settings.is_light():
		var bg := ColorRect.new()
		bg.color = pal.bg
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		add_child(Brand.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 28)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	top_margin.add_child(top_bar)

	var hub_btn := _pill_button(tr("← Hub"), false)
	hub_btn.custom_minimum_size.x = 130
	hub_btn.pressed.connect(_go_to_hub)
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("Options")
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", pal.accent)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	# balances the Hub button so the title stays centered
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(130, 0)
	top_bar.add_child(spacer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	drag = DragScroll.new()
	scroll.add_child(drag)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	margin.add_child(list)

	# ---- Display ----
	var display := _section(list, tr("Display"))
	var size_names: Array = []
	for n in Settings.TEXT_SIZE_NAMES:
		size_names.append(tr(n))
	_choice_row(display, tr("Text & button size"), tr("Makes text, buttons and boards bigger in every game."),
			size_names, Settings.text_size, _on_text_size)
	_choice_row(display, tr("Theme"), tr("The hub and menus. Games keep their own colors."),
			[tr("Dark"), tr("Light")], 1 if Settings.is_light() else 0, _on_theme)
	# Each language's own name, so anyone can find theirs.
	var codes: Array = Lang.SUPPORTED
	var names: Array = []
	for c in codes:
		names.append(Lang.NAMES[c])
	_choice_row(display, tr("Language"), "", names, codes.find(Lang.current), _on_language)

	# ---- Games ----
	var games := _section(list, tr("Games"))
	_toggle_row(games, tr("💀 Skull mode"),
			tr("Skulls, crossbones and voodoo dolls in Tic-Tac-Toe, Connect Four and Reversi."),
			Voodoo.is_on(), _on_skull_mode)

	# ---- Sound ----
	var sound := _section(list, tr("Sound"))
	var sound_opts := SoundOptions.new(pal)
	sound_opts.drag = drag
	sound.add_child(sound_opts)

	# ---- Vibration & screen ----
	var feel := _section(list, tr("Vibration & screen"))
	_toggle_row(feel, tr("📳 Vibration"), tr("A buzz when you tap, win or lose."), Settings.vibrate, Settings.set_vibrate)
	_toggle_row(feel, tr("☀ Keep screen on"), tr("The screen won't turn off while you play."),
			Settings.keep_awake, Settings.set_keep_awake)

	# ---- Notifications ----
	var notes := _section(list, tr("Notifications"))
	var invite_names: Array = []
	for n in Settings.INVITE_MODE_NAMES:
		invite_names.append(tr(n))
	_choice_row(notes, tr("🔔 Game invites from friends"), tr("When a friend invites you to an online game."),
			invite_names, maxi(0, Settings.INVITE_MODES.find(Settings.invites)), _on_invites)

	# ---- Account ----
	var account := _section(list, tr("Account"))
	account_label = _body_label("")
	account.add_child(account_label)
	account_btn = _pill_button("", true)
	account_btn.pressed.connect(_on_account_pressed)
	account.add_child(account_btn)
	_update_account()

	# ---- Storage (STANDARDS §2d, since v0.30) ----
	var storage := _section(list, tr("Storage"))
	storage_box = storage
	_fill_storage()

	# ---- About ----
	var about := _section(list, tr("About"))
	about.add_child(_body_label(tr("%s v%s (build %d)") % [Brand.NAME, Version.VERSION, Version.BUILD_NUMBER]))
	about.add_child(_body_label(Brand.tagline()))
	update_btn = _pill_button(tr("Check for updates"), true)
	update_btn.pressed.connect(_on_update_pressed)
	about.add_child(update_btn)
	update_label = _body_label("")
	update_label.visible = false
	about.add_child(update_label)
	var feedback_btn := _pill_button(tr("Send feedback"), true)
	feedback_btn.pressed.connect(_on_feedback_pressed)
	about.add_child(feedback_btn)
	var credits_btn := _pill_button(tr("Credits & licences"), false)
	credits_btn.pressed.connect(_show_credits)
	about.add_child(credits_btn)
	credits_box = VBoxContainer.new()
	credits_box.visible = false
	about.add_child(credits_box)

## Downloaded games and their sizes; each can be removed (its saves stay)
## unless it was opened this session (Godot is still reading that file).
func _fill_storage() -> void:
	for c in storage_box.get_children():
		c.queue_free()
	var packs: Array = Catalog.downloaded_packs()
	var total := 0
	for pk in packs:
		total += int(pk.bytes)
	storage_box.add_child(_body_label(tr("%d games downloaded · %s") % [packs.size(), _size_text(total)]))
	storage_box.add_child(_body_label(tr("Removing a game frees its space; its saves and records stay, and it downloads again the next time you open it.")))
	for pk in packs:
		var game: Dictionary = Catalog.get_game(str(pk.id))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _body_label("%s  ·  %s" % [Lang.pick(game, "title") if not game.is_empty() else str(pk.id), _size_text(int(pk.bytes))])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var del := _pill_button(tr("Remove") if Catalog.can_remove(str(pk.id)) else tr("In use"), false)
		del.disabled = not Catalog.can_remove(str(pk.id))
		del.pressed.connect(_on_remove_pack.bind(str(pk.id)))
		row.add_child(del)
		storage_box.add_child(row)

func _size_text(bytes: int) -> String:
	if bytes >= 1024 * 1024:
		return "%.1f MB" % (bytes / 1048576.0)
	return "%d KB" % maxi(1, int(bytes / 1024))

func _on_remove_pack(id: String) -> void:
	if drag.moved:
		return
	Catalog.remove_pack(id)
	_fill_storage()

## Every asset and its licence, from media/CREDITS.json (STANDARDS §10).
func _show_credits() -> void:
	if drag.moved:
		return
	credits_box.visible = not credits_box.visible
	if not credits_box.visible or credits_box.get_child_count() > 0:
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://media/CREDITS.json"))
	var assets: Array = data.get("assets", []) if data is Dictionary else []
	credits_box.add_child(_body_label(tr("Code and games: Viral. Sounds and most art are made in code.")))
	for a in assets:
		credits_box.add_child(_body_label("• %s — %s (%s)" % [str(a.get("what", a.get("file", ""))), str(a.get("author", "")), str(a.get("licence", ""))]))

# ---------- building blocks ----------

## A titled card; returns the VBox to put rows in.
func _section(list: VBoxContainer, title_text: String) -> VBoxContainer:
	var heading := Label.new()
	heading.text = title_text.to_upper()
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", pal.link)
	list.add_child(heading)

	var card := PanelContainer.new()
	var sb := _card_style(pal.card_fill, pal.link_dim)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", sb)
	list.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	return box

func _title_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", pal.text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _body_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", pal.text_dim)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Title, optional hint, and a row of tabs -- one per choice, the current one lit.
func _choice_row(box: VBoxContainer, title_text: String, hint: String, choices: Array, selected: int, on_pick: Callable) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	col.add_child(_title_label(title_text))
	if hint != "":
		col.add_child(_body_label(hint))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for i in range(choices.size()):
		var b := _pill_button(str(choices[i]), i == selected)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		# three tabs share one row: tighter, so "Extra large" fits at that size
		b.add_theme_font_size_override("font_size", 21)
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(state)
			sb.content_margin_left = 6
			sb.content_margin_right = 6
		b.pressed.connect(_on_choice.bind(on_pick, i))
		row.add_child(b)

## Title + hint on the left, a big On/Off pill on the right.
func _toggle_row(box: VBoxContainer, title_text: String, hint: String, on: bool, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_title_label(title_text))
	if hint != "":
		col.add_child(_body_label(hint))
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 60)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("on", on)
	_style_toggle(b)
	b.pressed.connect(_on_toggle.bind(b, on_change))
	row.add_child(b)

func _style_toggle(b: Button) -> void:
	var on: bool = b.get_meta("on")
	b.text = tr("On") if on else tr("Off")
	_style_pill(b, on)

func _pill_button(text: String, lit: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	_style_pill(b, lit)
	return b

func _style_pill(b: Button, lit: bool) -> void:
	var sb := _card_style(pal.accent_fill if lit else pal.off_fill, pal.accent if lit else pal.off_border)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	var fc: Color = pal.text_dim
	if lit:
		fc = pal.text if Settings.is_light() else Color(1, 1, 1)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, fc)

func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = border
	return sb

# ---------- actions ----------

## Choice tabs: ignore the release that ends a drag-scroll.
func _on_choice(on_pick: Callable, i: int) -> void:
	if drag.moved:
		return
	on_pick.call(i)

func _on_toggle(b: Button, on_change: Callable) -> void:
	if drag.moved:
		return
	var on: bool = not b.get_meta("on")
	b.set_meta("on", on)
	_style_toggle(b)
	on_change.call(on)

func _on_text_size(i: int) -> void:
	if i != Settings.text_size:
		Settings.set_text_size(i)
		get_tree().reload_current_scene()

func _on_theme(i: int) -> void:
	var t := "light" if i == 1 else "dark"
	if t != Settings.theme:
		Settings.set_theme(t)
		get_tree().reload_current_scene()

func _on_language(i: int) -> void:
	var code: String = Lang.SUPPORTED[i]
	if code != Lang.current:
		Lang.set_language(code)
		get_tree().reload_current_scene()

func _on_skull_mode(on: bool) -> void:
	Voodoo.set_on(on)

func _on_invites(i: int) -> void:
	Settings.set_invites(Settings.INVITE_MODES[i])
	get_tree().reload_current_scene()  # relights the chosen tab

func _update_account() -> void:
	if Auth.is_logged_in():
		account_label.text = tr("Signed in as %s") % Auth.get_display_name()
		account_btn.text = tr("Sign Out")
	else:
		account_label.text = tr("Not signed in. Sign in to keep your best scores on every device.")
		account_btn.text = tr("Sign In")

func _on_account_pressed() -> void:
	if drag.moved:
		return
	if Auth.is_logged_in():
		Auth.sign_out()
	else:
		get_tree().change_scene_to_file("res://scenes/account/account.tscn")

func _on_update_pressed() -> void:
	if drag.moved:
		return
	if update_url != "":
		OS.shell_open(update_url)
		return
	update_btn.disabled = true
	update_label.visible = true
	update_label.text = tr("Checking...")
	Catalog.check_app_update(_on_update_found, _on_no_update)

func _on_update_found(remote_version: String, apk_url: String) -> void:
	update_btn.disabled = false
	update_url = apk_url
	update_label.text = tr("v%s is out (you have v%s)") % [remote_version, Version.VERSION]
	update_btn.text = tr("Update Now")

func _on_no_update(reached: bool) -> void:
	update_btn.disabled = false
	update_label.text = tr("You're up to date!") if reached else tr("Couldn't check. Are you online?")

func _on_feedback_pressed() -> void:
	if drag.moved:
		return
	OS.shell_open(FEEDBACK_URL)

func _go_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
