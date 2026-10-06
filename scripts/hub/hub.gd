extends Control

const Version = preload("res://scripts/common/version.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const Config = preload("res://scripts/common/config.gd")
const DragScroll = preload("res://scripts/common/drag_scroll.gd")
const Mist = preload("res://scripts/common/mist.gd")
const GameIcons = preload("res://scripts/common/game_icons.gd")
const Brand = preload("res://scripts/common/brand.gd")
## The title art: the V-skull + VIRAL wordmark (Brand.WORDMARK), its own
## backdrop faded out at the edges so the hub background shows through. If
## it's ever missing, the hub falls back to the plain text title.
const BANNER_PATH := Brand.WORDMARK
const BANNER_HEIGHT := 330.0

## The game catalog itself lives in manifest.json (see the Catalog autoload),
## not here -- this file only draws it.

## Colors come from Settings.palette() (dark or light theme, chosen in
## Options). Category headers use "link" (electric blue) so the tier rows read
## as a different kind of thing from the game tiles underneath them, which are
## colored by state: "ready" green = play right now, "download" dim blue =
## needs downloading first (never red: red reads as "bad"), "update" amber = needs a newer app, "soon" gray = not
## built yet. One glance should tell you what you can tap.
var pal: Dictionary

## Height the category rows collapse to once one is expanded, plus roughly how
## much vertical space the VOODOO header + margins eat. Only used to decide how
## tall the rows grow to fill the screen when nothing is expanded.
const HEADER_HEIGHT_COMPACT := 104.0
## Banner + version + account row + the Leaderboards/Achievements/Friends/
## Multiplayer row + the list's own bottom margin, in the 720x1280 design
## space. Constant across devices: stretch mode scales these logical sizes,
## so only the viewport's logical height varies.
const HEADER_CHROME_HEIGHT := 580.0
## The four hub screens (since v0.25): [icon, label, scene, colour key].
const HUB_SCREENS := [
	["🏆", "Leaderboards", "res://scenes/hub/leaderboards.tscn", "update"],
	["🏅", "Achievements", "res://scenes/hub/achievements.tscn", "accent"],
	["👥", "Friends", "res://scenes/hub/friends.tscn", "ready"],
	["🎮", "Multiplayer", "res://scenes/hub/multiplayer.tscn", "link"],
]
const LIST_SEPARATION := 14

var list_container: VBoxContainer
var expanded_index: int = -1
var account_status_label: Label
var account_status_btn: Button
## Set while a tap is being resolved (manifest check, download, mount), so a
## second tap -- on the same tile or another -- can't start a parallel flow.
var busy: bool = false
var download_overlay: Control
var list_scroll: ScrollContainer
## Drag-anywhere scrolling; tap handlers ignore a press that became a drag.
var drag: Node

func _ready() -> void:
	Orientation.lock_portrait()
	pal = Settings.palette()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Dark theme: the brand background fills the screen. Light theme: a
	# plain background, with the mist only behind the banner so the art
	# never sits on white.
	var bg: Control
	if Settings.is_light():
		bg = ColorRect.new()
		bg.color = pal.bg
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		bg = Brand.backdrop()
	add_child(bg)
	move_child(bg, 0)

	# The banner, account line and screens row scroll away with the list (on
	# a short/wide desktop window they used to pin ~75% of the screen), so
	# everything lives in one ScrollContainer.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	list_scroll = scroll
	drag = DragScroll.new()
	scroll.add_child(drag)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var banner_panel := PanelContainer.new()
	banner_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	banner_panel.custom_minimum_size = Vector2(0, BANNER_HEIGHT)
	content.add_child(banner_panel)
	if Settings.is_light():
		banner_panel.add_child(Mist.new())
	if ResourceLoader.exists(BANNER_PATH):
		var banner := TextureRect.new()
		banner.texture = load(BANNER_PATH)
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner_panel.add_child(banner)
	else:
		var title := Label.new()
		title.text = Brand.NAME.to_upper()
		title.add_theme_font_size_override("font_size", 56)
		title.add_theme_color_override("font_color", pal.accent)
		title.add_theme_color_override("font_outline_color", Color(pal.accent, 0.5 * pal.glow))
		title.add_theme_constant_override("outline_size", 12)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		banner_panel.add_child(title)

	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_top", 6)
	header.add_theme_constant_override("margin_bottom", 16)
	header.add_theme_constant_override("margin_left", 14)
	header.add_theme_constant_override("margin_right", 14)
	content.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	header.add_child(header_box)

	var version_label := Label.new()
	version_label.text = tr("v%s (build %d)") % [Version.VERSION, Version.BUILD_NUMBER]
	version_label.add_theme_font_size_override("font_size", 20)
	version_label.add_theme_color_override("font_color", pal.version)
	header_box.add_child(version_label)

	var account_row := HBoxContainer.new()
	account_row.add_theme_constant_override("separation", 12)
	header_box.add_child(account_row)

	account_status_label = Label.new()
	account_status_label.add_theme_font_size_override("font_size", 22)
	account_status_label.add_theme_color_override("font_color", pal.account)
	# Takes the free space but clips a long name, so Options never gets pushed
	# off-screen (at large text sizes the row is tight).
	account_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	account_status_label.clip_text = true
	account_row.add_child(account_status_label)

	account_status_btn = Button.new()
	account_status_btn.flat = true
	account_status_btn.add_theme_font_size_override("font_size", 22)
	account_status_btn.add_theme_color_override("font_color", pal.link)
	account_status_btn.pressed.connect(_on_account_status_pressed)
	account_row.add_child(account_status_btn)

	# Language, text size, theme, skull mode, sound, vibration... all live in
	# Options. A bordered pill, not flat text, so it's easy to find.
	var options_btn := Button.new()
	options_btn.text = tr("⚙ Options")
	options_btn.add_theme_font_size_override("font_size", 26)
	options_btn.add_theme_color_override("font_color", pal.accent)
	options_btn.add_theme_color_override("font_hover_color", pal.accent)
	options_btn.add_theme_color_override("font_pressed_color", pal.accent)
	var opt_sb := _neon_style(pal.header_fill, pal.accent, 0.5)
	opt_sb.content_margin_left = 18
	opt_sb.content_margin_right = 18
	opt_sb.content_margin_top = 6
	opt_sb.content_margin_bottom = 6
	for state in ["normal", "hover", "pressed", "focus"]:
		options_btn.add_theme_stylebox_override(state, opt_sb)
	options_btn.focus_mode = Control.FOCUS_NONE
	options_btn.pressed.connect(_open_options)
	account_row.add_child(options_btn)

	# .unbind(2) rather than a lambda on purpose: Godot only auto-disconnects a
	# signal when the connected Callable points at the freed object. A lambda is
	# a separate object that merely captures `self`, so connecting one to a
	# long-lived autoload like Auth survives this scene being freed -- every hub
	# visit would leave another stale connection behind, and the next sign-in
	# would error on each one ("Lambda capture was freed").
	Auth.signed_in.connect(_update_account_status.unbind(2))
	Auth.signed_out.connect(_update_account_status)
	_update_account_status()

	var screens_row := HBoxContainer.new()
	screens_row.add_theme_constant_override("separation", 10)
	header_box.add_child(_gap(10))
	header_box.add_child(screens_row)
	for spec in HUB_SCREENS:
		screens_row.add_child(_screen_button(spec))
	Social.friends_changed.connect(_update_friend_badge)
	_update_friend_badge()

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
	content.add_child(margin)

	# A newer live manifest can add games or change versions while the hub is
	# open. Plain method connection, not a lambda -- see CLAUDE.md gotcha.
	Catalog.catalog_changed.connect(_rebuild_list)
	Catalog.refresh_manifest(Config.MANIFEST_MAX_AGE_SEC)
	_rebuild_list()
	if not Catalog.app_update_checked:
		Catalog.check_app_update(_show_update_dialog)
	var requested: String = Social.take_launch_request()
	if requested != "":
		# A game opened from Multiplayer / Friends / an invite: same path as a tile tap.
		Settings.take_resume_scene()  # an invite wins over reopening the last game
		call_deferred("_on_tile_pressed", requested)
	else:
		_resume_last_game()

## Android kills apps left in the background; if that happened mid-game,
## go straight back into it (games with a save pick up where they were).
func _resume_last_game() -> void:
	var scene: String = Settings.take_resume_scene()
	if scene == "":
		return
	for category in Catalog.categories:
		for entry in category.get("games", []):
			var game: Dictionary = Catalog.get_game(entry.get("id", ""))
			if game.get("scene", "") == scene and Catalog.state_of(game) == Catalog.STATE_READY:
				busy = true
				call_deferred("_launch", game)
				return

func _open_options() -> void:
	if drag.moved:
		return
	get_tree().change_scene_to_file("res://scenes/hub/options.tscn")

func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

var friends_label: Label

## Icon over a short label, glowing in its own colour; the four share the
## row. The text is two Labels over a flat Button (a Button's own text can't
## size its emoji line apart from the word, and the emoji came out tiny).
func _screen_button(spec: Array) -> Button:
	var color: Color = pal[spec[3]]
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var sb := _neon_style(_tinted_fill(color), color, 0.55)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := Label.new()
	icon.text = spec[0]
	icon.add_theme_font_size_override("font_size", 36)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(icon)
	var name_label := Label.new()
	name_label.text = tr(spec[1])
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", pal.text)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(10, 0)  # lets the four share the row however long the word
	col.add_child(name_label)
	b.pressed.connect(_open_screen.bind(str(spec[2])))
	if spec[1] == "Friends":
		friends_label = name_label
	return b

func _open_screen(scene: String) -> void:
	if not busy and not drag.moved:
		get_tree().change_scene_to_file(scene)

## "👥 Friends" shows how many requests are waiting.
func _update_friend_badge() -> void:
	if friends_label == null:
		return
	var waiting := 0
	for f in Social.friends:
		if str(f.get("status", "")) == "incoming":
			waiting += 1
	friends_label.text = tr("Friends") + (" (%d)" % waiting if waiting > 0 else "")

func _update_account_status() -> void:
	if Auth.is_logged_in():
		account_status_label.text = "👤 %s" % Auth.get_display_name()
		# Signing out lives in Options, not on the home screen.
		account_status_btn.visible = false
	else:
		account_status_label.text = ""
		account_status_btn.text = tr("Sign In")
		account_status_btn.visible = true

func _on_account_status_pressed() -> void:
	if drag.moved:
		return
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
	sb.shadow_color = Color(border.r, border.g, border.b, glow_strength * pal.glow)
	sb.shadow_size = 10
	return sb

## A panel fill tinted with `color` but nearly opaque: a see-through fill
## lets the glow (drawn behind the panel) shine through and wash the panel
## out to a pale pastel that white text can't be read on.
func _tinted_fill(color: Color) -> Color:
	if Settings.is_light():
		return color.lerp(Color(1, 1, 1), 0.85)
	return Color(color.lerp(Color(0.03, 0.0, 0.06), 0.72), 0.93)

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
	if drag.moved:
		return
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
		sb = _neon_style(_tinted_fill(pal.link), pal.link, 1.0)
	else:
		sb = _neon_style(pal.header_fill, pal.link_dim, 0.5)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(row)

	var icon_label := Label.new()
	icon_label.text = category.icon
	icon_label.add_theme_font_size_override("font_size", 52)
	icon_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = Lang.pick(category, "name").to_upper()
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.add_theme_color_override("font_color", pal.header_open_text if is_open else pal.link)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Wraps to a second line rather than cutting off at large text sizes.
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)

	var count_label := Label.new()
	# Just "22" when every game in it is real; "3/5" only while some are
	# "coming soon". Short, so long category names fit at large text sizes.
	if available_count == category.games.size():
		count_label.text = str(available_count)
	else:
		count_label.text = "%d/%d" % [available_count, category.games.size()]
	count_label.add_theme_font_size_override("font_size", 24)
	count_label.add_theme_color_override("font_color", pal.count_open if is_open else pal.count)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count_label)

	var chevron := Label.new()
	chevron.text = "▾" if is_open else "▸"
	chevron.add_theme_font_size_override("font_size", 36)
	chevron.add_theme_color_override("font_color", pal.header_open_text if is_open else pal.link)
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
## green = playable right now, dim blue = will download first, amber = needs a
## newer app first, gray = not built yet.
func _make_tile(game: Dictionary) -> Control:
	var state: String = Catalog.state_of(game)
	var available: bool = state != Catalog.STATE_SOON

	var state_color: Color
	var tag_text := ""
	match state:
		Catalog.STATE_READY:
			state_color = pal.ready
			tag_text = tr("▶ Play")
		Catalog.STATE_DOWNLOAD:
			state_color = pal.download
			tag_text = tr("⬇ Download")
		Catalog.STATE_NEEDS_APP_UPDATE:
			state_color = pal.update
			tag_text = tr("⬆ Update app")
		_:
			state_color = pal.soon
			tag_text = tr("Coming soon")

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 128)
	var sb: StyleBoxFlat
	if available:
		sb = _neon_style(_tinted_fill(state_color), state_color, 0.6)
	else:
		sb = _neon_style(pal.soon_fill, pal.soon_border, 0.0)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)

	if GameIcons.has(str(game.get("id", ""))):
		var icon_art := Control.new()
		icon_art.custom_minimum_size = Vector2(76, 76)
		icon_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_art.draw.connect(GameIcons.draw.bind(icon_art, str(game.id)))
		row.add_child(icon_art)
	else:
		var icon_label := Label.new()
		icon_label.text = game.get("icon", "🎮")
		icon_label.add_theme_font_size_override("font_size", 46)
		icon_label.modulate = Color(1, 1, 1) if available else Color(1, 1, 1, 0.35)
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(icon_label)

	var label := Label.new()
	label.text = Lang.pick(game, "title")
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", pal.text if available else pal.soon_text)
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
	if busy or drag.moved:
		return
	var game: Dictionary = Catalog.get_game(id)
	if game.is_empty():
		return
	if Catalog.state_of(game) == Catalog.STATE_NEEDS_APP_UPDATE:
		_show_dialog(tr("Update Needed"), tr("%s needs a newer version of %s.") % [Lang.pick(game, "title"), Brand.NAME], [
			{"text": tr("Get Update"), "action": Callable(OS, "shell_open").bind(Config.RELEASES_PAGE_URL)},
			{"text": tr("Later"), "action": Callable()},
		])
		return
	if Catalog.needs_download(id):
		_start_download(game)
	else:
		_launch(game)

func _launch(game: Dictionary) -> void:
	var error: String = Catalog.mount(game.id)
	if error == "" and get_tree().change_scene_to_file(game.scene) != OK:
		error = tr("Something went wrong opening this game.")
	if error != "":
		busy = false
		_rebuild_list()  # a damaged pack was removed; its tile is blue again
		_show_dialog(tr("Couldn't Start %s") % Lang.pick(game, "title"), error, [{"text": "OK", "action": Callable()}])

## ---------- download-on-demand ----------

func _start_download(game: Dictionary) -> void:
	busy = true
	var is_update: bool = Catalog.is_downloaded(game.id)
	download_overlay = _build_download_overlay(
			(tr("Updating %s...") if is_update else tr("Downloading %s...")) % Lang.pick(game, "title"), game.id)
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
		download_overlay.get_meta("close_button").text = tr("Close")

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

	var status_label := _dialog_label(status_text, 30, pal.text)
	box.add_child(status_label)

	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 36)
	progress_bar.max_value = 100
	box.add_child(progress_bar)

	var close_btn := _dialog_button(tr("Cancel"))
	close_btn.pressed.connect(_close_download_overlay.bind(id))
	box.add_child(close_btn)

	overlay.set_meta("status_label", status_label)
	overlay.set_meta("progress_bar", progress_bar)
	overlay.set_meta("close_button", close_btn)
	return overlay

## ---------- dialogs ----------

func _show_update_dialog(remote_version: String, apk_url: String) -> void:
	_show_dialog(tr("Update Available"), tr("v%s is out (you have v%s)") % [remote_version, Version.VERSION], [
		{"text": tr("Update Now"), "action": Callable(OS, "shell_open").bind(apk_url)},
		{"text": tr("Later"), "action": Callable()},
	])

## `buttons` is [{"text": String, "action": Callable}]; every button closes
## the dialog, and an empty Callable() means it does nothing else.
func _show_dialog(title_text: String, message: String, buttons: Array) -> void:
	var parts: Array = _build_dialog_frame(title_text)
	var overlay: Control = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_child(_dialog_label(message, 28, pal.card_message))
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
	overlay.color = pal.overlay
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_to_group("modal_overlay")  # stops the list's drag-scrolling

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var sb := _neon_style(pal.card_fill, pal.accent, 0.7)
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
		box.add_child(_dialog_label(title_text, 40, pal.accent))
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
