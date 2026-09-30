extends Control

const Version = preload("res://scripts/common/version.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const Config = preload("res://scripts/common/config.gd")

## The game catalog itself lives in manifest.json (see the Catalog autoload),
## not here -- this file only draws it.

const NEON_GREEN := Color(0.15, 1.0, 0.55)
const NEON_GREEN_DIM := Color(0.08, 0.45, 0.28)
const BG_BLACK := Color(0.015, 0.035, 0.03)

## Category headers are electric blue so the tier rows read as a different kind
## of thing from the game tiles underneath them, which are colored by state:
## green = ready to play right now, red = needs downloading first,
## gray = not built yet. One glance should tell you what you can tap.
const ELECTRIC_BLUE := Color(0.15, 0.68, 1.0)
const ELECTRIC_BLUE_DIM := Color(0.06, 0.26, 0.45)
const STATE_READY := Color(0.15, 1.0, 0.55)
const STATE_DOWNLOAD := Color(1.0, 0.32, 0.34)
const STATE_SOON := Color(0.42, 0.46, 0.48)
const STATE_APP_UPDATE := Color(1.0, 0.75, 0.2)

## Height the category rows collapse to once one is expanded, plus roughly how
## much vertical space the VOODOO header + margins eat. Only used to decide how
## tall the rows grow to fill the screen when nothing is expanded.
const HEADER_HEIGHT_COMPACT := 104.0
## VOODOO title + version + account row + the list's own bottom margin, in the
## 720x1280 design space. Constant across devices: stretch mode scales these
## logical sizes, so only the viewport's logical height varies.
const HEADER_CHROME_HEIGHT := 245.0
const LIST_SEPARATION := 14

var list_container: VBoxContainer
var expanded_index: int = -1
var account_status_label: Label
var account_status_btn: Button
## Set while a tap is being resolved (manifest check, download, mount), so a
## second tap -- on the same tile or another -- can't start a parallel flow.
var busy: bool = false
var download_overlay: Control

func _ready() -> void:
	Orientation.lock_portrait()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = BG_BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_top", 36)
	header.add_theme_constant_override("margin_bottom", 20)
	header.add_theme_constant_override("margin_left", 14)
	header.add_theme_constant_override("margin_right", 14)
	root.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	header.add_child(header_box)

	var title := Label.new()
	title.text = "VOODOO"
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", NEON_GREEN)
	title.add_theme_color_override("font_outline_color", Color(NEON_GREEN.r, NEON_GREEN.g, NEON_GREEN.b, 0.5))
	title.add_theme_constant_override("outline_size", 12)
	header_box.add_child(title)

	var version_label := Label.new()
	version_label.text = "v%s (build %d)" % [Version.VERSION, Version.BUILD_NUMBER]
	version_label.add_theme_font_size_override("font_size", 20)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.5))
	header_box.add_child(version_label)

	var account_row := HBoxContainer.new()
	account_row.add_theme_constant_override("separation", 12)
	header_box.add_child(account_row)

	account_status_label = Label.new()
	account_status_label.add_theme_font_size_override("font_size", 22)
	account_status_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7))
	account_row.add_child(account_status_label)

	account_status_btn = Button.new()
	account_status_btn.flat = true
	account_status_btn.add_theme_font_size_override("font_size", 22)
	account_status_btn.add_theme_color_override("font_color", ELECTRIC_BLUE)
	account_status_btn.pressed.connect(_on_account_status_pressed)
	account_row.add_child(account_status_btn)

	# .unbind(2) rather than a lambda on purpose: Godot only auto-disconnects a
	# signal when the connected Callable points at the freed object. A lambda is
	# a separate object that merely captures `self`, so connecting one to a
	# long-lived autoload like Auth survives this scene being freed -- every hub
	# visit would leave another stale connection behind, and the next sign-in
	# would error on each one ("Lambda capture was freed").
	Auth.signed_in.connect(_update_account_status.unbind(2))
	Auth.signed_out.connect(_update_account_status)
	_update_account_status()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", LIST_SEPARATION)
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	# Without EXPAND_FILL a ScrollContainer only gives its child that child's
	# minimum width, which leaves the rows hugging the left edge instead of
	# spanning the screen.
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_child(list_container)
	scroll.add_child(margin)

	# A newer live manifest can add games or change versions while the hub is
	# open. Plain method connection, not a lambda -- see CLAUDE.md gotcha.
	Catalog.catalog_changed.connect(_rebuild_list)
	Catalog.refresh_manifest(Config.MANIFEST_MAX_AGE_SEC)
	_rebuild_list()
	if not Catalog.app_update_checked:
		Catalog.check_app_update(_show_update_dialog)

func _update_account_status() -> void:
	if Auth.is_logged_in():
		account_status_label.text = "👤 %s" % Auth.get_display_name()
		account_status_btn.text = "Sign Out"
	else:
		account_status_label.text = ""
		account_status_btn.text = "Sign In"

func _on_account_status_pressed() -> void:
	if Auth.is_logged_in():
		Auth.sign_out()
	else:
		get_tree().change_scene_to_file("res://scenes/account/account.tscn")

## Shared neon-glow panel style: bright border + a blurred shadow of the same hue
## behind it (Godot's StyleBoxFlat shadow is a real soft blur, not a flat drop shadow),
## which is what actually reads as "glowing" rather than just "outlined."
func _neon_style(fill: Color, border: Color, glow_strength: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border
	sb.shadow_color = Color(border.r, border.g, border.b, glow_strength)
	sb.shadow_size = 10
	return sb

## Accordion: rebuilds the whole category list from scratch each time it's toggled.
## Only expanded_index's games are shown, so opening one category collapses any other.
## Uses queue_free(), not free() -- see the CLAUDE.md gotcha: this runs from inside
## a header button's own `pressed` signal, and Godot refuses to free a node whose
## signal is still emitting, leaking it instead.
func _rebuild_list() -> void:
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.queue_free()

	# With nothing expanded there'd otherwise be dead space under the last row,
	# so the headers grow to divide up whatever height this screen actually has.
	# Once a category opens, they drop back to compact so its games get the room.
	var categories: Array = Catalog.categories
	if expanded_index >= categories.size():
		expanded_index = -1
	var row_height := HEADER_HEIGHT_COMPACT
	if expanded_index == -1 and not categories.is_empty():
		var available: float = get_viewport_rect().size.y - HEADER_CHROME_HEIGHT
		var gaps: float = LIST_SEPARATION * (categories.size() - 1)
		row_height = max(HEADER_HEIGHT_COMPACT, (available - gaps) / categories.size())

	for i in range(categories.size()):
		var category: Dictionary = categories[i]
		list_container.add_child(_make_section_header(category, i, row_height))
		if expanded_index == i:
			var section := VBoxContainer.new()
			section.add_theme_constant_override("separation", 12)
			var section_margin := MarginContainer.new()
			section_margin.add_theme_constant_override("margin_top", 12)
			section_margin.add_child(section)
			list_container.add_child(section_margin)
			for game in category.games:
				section.add_child(_make_tile(game))

func _toggle_category(index: int) -> void:
	expanded_index = -1 if expanded_index == index else index
	_rebuild_list()

func _make_section_header(category: Dictionary, index: int, row_height: float) -> Control:
	var is_open: bool = expanded_index == index
	var available_count := 0
	for game in category.games:
		if game.has("id"):
			available_count += 1

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, row_height)
	var sb: StyleBoxFlat
	if is_open:
		sb = _neon_style(Color(ELECTRIC_BLUE.r, ELECTRIC_BLUE.g, ELECTRIC_BLUE.b, 0.4), ELECTRIC_BLUE, 1.0)
	else:
		sb = _neon_style(Color(0.03, 0.09, 0.16), ELECTRIC_BLUE_DIM, 0.5)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(row)

	var icon_label := Label.new()
	icon_label.text = category.icon
	icon_label.add_theme_font_size_override("font_size", 52)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = category.name.to_upper()
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1) if is_open else ELECTRIC_BLUE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "%d/%d" % [available_count, category.games.size()]
	count_label.add_theme_font_size_override("font_size", 24)
	count_label.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0) if is_open else Color(0.45, 0.65, 0.8))
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count_label)

	var chevron := Label.new()
	chevron.text = "▾" if is_open else "▸"
	chevron.add_theme_font_size_override("font_size", 36)
	chevron.add_theme_color_override("font_color", Color(1, 1, 1) if is_open else ELECTRIC_BLUE)
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(chevron)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_toggle_category.bind(index))
	panel.add_child(button)

	return panel

## Tiles are color-coded by what tapping them will actually do:
## green = playable right now, red = will download first, amber = needs a
## newer app first, gray = not built yet.
func _make_tile(game: Dictionary) -> Control:
	var state: String = Catalog.state_of(game)
	var available: bool = state != Catalog.STATE_SOON

	var state_color: Color
	var tag_text := ""
	match state:
		Catalog.STATE_READY:
			state_color = STATE_READY
			tag_text = "▶ Play"
		Catalog.STATE_DOWNLOAD:
			state_color = STATE_DOWNLOAD
			tag_text = "⬇ Download"
		Catalog.STATE_NEEDS_APP_UPDATE:
			state_color = STATE_APP_UPDATE
			tag_text = "⬆ Update app"
		_:
			state_color = STATE_SOON
			tag_text = "Coming soon"

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 128)
	var sb: StyleBoxFlat
	if available:
		sb = _neon_style(Color(state_color.r, state_color.g, state_color.b, 0.22), state_color, 0.6)
	else:
		sb = _neon_style(Color(0.05, 0.06, 0.06), Color(0.25, 0.28, 0.29), 0.0)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)

	var icon_label := Label.new()
	icon_label.text = game.get("icon", "🎮")
	icon_label.add_theme_font_size_override("font_size", 46)
	icon_label.modulate = Color(1, 1, 1) if available else Color(1, 1, 1, 0.35)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_label)

	var label := Label.new()
	label.text = game.title
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(1, 1, 1) if available else Color(0.5, 0.55, 0.53))
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(label)

	var tag := Label.new()
	tag.text = tag_text
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", state_color)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.disabled = not available
	button.focus_mode = Control.FOCUS_NONE
	if available:
		button.pressed.connect(_on_tile_pressed.bind(str(game.id)))
	panel.add_child(button)

	return panel


## ---------- tapping a game ----------

## Never waits on the network before acting: the manifest is refreshed in the
## background when the hub opens, so by the time a player taps, Catalog
## already knows whether an update exists. Offline, a downloaded game just
## launches, and a failed update download falls back to the copy on disk.
func _on_tile_pressed(id: String) -> void:
	if busy:
		return
	var game: Dictionary = Catalog.get_game(id)
	if game.is_empty():
		return
	if Catalog.state_of(game) == Catalog.STATE_NEEDS_APP_UPDATE:
		_show_dialog("Update Needed", "%s needs a newer version of Voodoo." % game.title, [
			{"text": "Get Update", "action": Callable(OS, "shell_open").bind(Config.RELEASES_PAGE_URL)},
			{"text": "Later", "action": Callable()},
		])
		return
	if Catalog.needs_download(id):
		_start_download(game)
	else:
		_launch(game)

func _launch(game: Dictionary) -> void:
	var error: String = Catalog.mount(game.id)
	if error == "" and get_tree().change_scene_to_file(game.scene) != OK:
		error = "Something went wrong opening this game."
	if error != "":
		busy = false
		_rebuild_list()  # a damaged pack was removed; its tile is red again
		_show_dialog("Couldn't Start %s" % game.title, error, [{"text": "OK", "action": Callable()}])

## ---------- download-on-demand ----------

func _start_download(game: Dictionary) -> void:
	busy = true
	var is_update: bool = Catalog.is_downloaded(game.id)
	download_overlay = _build_download_overlay(
			("Updating %s..." if is_update else "Downloading %s...") % game.title, game.id)
	add_child(download_overlay)
	var http: HTTPRequest = Catalog.download(game.id, _on_download_done.bind(game.id))
	download_overlay.set_meta("http", http)

func _process(_delta: float) -> void:
	if download_overlay == null or not is_instance_valid(download_overlay):
		return
	var http = download_overlay.get_meta("http", null)
	if http == null or not is_instance_valid(http):
		return
	var total: int = http.get_body_size()
	if total > 0:
		var bar: ProgressBar = download_overlay.get_meta("progress_bar")
		bar.value = 100.0 * float(http.get_downloaded_bytes()) / float(total)

func _on_download_done(error: String, id: String) -> void:
	var game: Dictionary = Catalog.get_game(id)
	if error == "" or Catalog.is_downloaded(id):
		# Success -- or an update failed but the previous version is still on
		# disk, which beats blocking play on a flaky connection.
		_close_download_overlay()
		_launch(game)
		return
	if download_overlay and is_instance_valid(download_overlay):
		download_overlay.set_meta("http", null)
		download_overlay.get_meta("status_label").text = error
		download_overlay.get_meta("progress_bar").visible = false
		download_overlay.get_meta("close_button").text = "Close"

## Both "Cancel" mid-download and "Close" after a failure.
func _close_download_overlay(id: String = "") -> void:
	if id != "":
		Catalog.cancel_download(id)
	if download_overlay and is_instance_valid(download_overlay):
		download_overlay.queue_free()
	download_overlay = null
	busy = false
	_rebuild_list()

func _build_download_overlay(status_text: String, id: String) -> Control:
	var parts: Array = _build_dialog_frame("")
	var overlay: Control = parts[0]
	var box: VBoxContainer = parts[1]

	var status_label := _dialog_label(status_text, 30, Color(1, 1, 1))
	box.add_child(status_label)

	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 36)
	progress_bar.max_value = 100
	box.add_child(progress_bar)

	var close_btn := _dialog_button("Cancel")
	close_btn.pressed.connect(_close_download_overlay.bind(id))
	box.add_child(close_btn)

	overlay.set_meta("status_label", status_label)
	overlay.set_meta("progress_bar", progress_bar)
	overlay.set_meta("close_button", close_btn)
	return overlay

## ---------- dialogs ----------

func _show_update_dialog(remote_version: String, apk_url: String) -> void:
	_show_dialog("Update Available", "v%s is out (you have v%s)" % [remote_version, Version.VERSION], [
		{"text": "Update Now", "action": Callable(OS, "shell_open").bind(apk_url)},
		{"text": "Later", "action": Callable()},
	])

## `buttons` is [{"text": String, "action": Callable}]; every button closes
## the dialog, and an empty Callable() means it does nothing else.
func _show_dialog(title_text: String, message: String, buttons: Array) -> void:
	var parts: Array = _build_dialog_frame(title_text)
	var overlay: Control = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_child(_dialog_label(message, 28, Color(0.85, 0.9, 0.87)))
	for spec in buttons:
		var btn := _dialog_button(spec.text)
		btn.pressed.connect(_on_dialog_button.bind(overlay, spec.action))
		box.add_child(btn)
	add_child(overlay)

func _on_dialog_button(overlay: Control, action: Callable) -> void:
	overlay.queue_free()
	if action.is_valid():
		action.call()

## Returns [overlay, content_box]. Sized for the 720x1280 design space.
func _build_dialog_frame(title_text: String) -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var sb := _neon_style(Color(0.06, 0.1, 0.09), NEON_GREEN, 0.7)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.custom_minimum_size = Vector2(520, 0)
	panel.add_child(box)

	if title_text != "":
		box.add_child(_dialog_label(title_text, 40, NEON_GREEN))
	return [overlay, box]

func _dialog_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label

func _dialog_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 72)
	btn.add_theme_font_size_override("font_size", 28)
	btn.focus_mode = Control.FOCUS_NONE
	return btn
