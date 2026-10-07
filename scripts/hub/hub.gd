extends Control

const Version = preload("res://scripts/common/version.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const Config = preload("res://scripts/common/config.gd")
const DragScroll = preload("res://scripts/common/drag_scroll.gd")
const Mist = preload("res://scripts/common/mist.gd")
const GameIcons = preload("res://scripts/common/game_icons.gd")
const Brand = preload("res://scripts/common/brand.gd")
const HubData = preload("res://scripts/common/hub_data.gd")
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
## The Game Browser's header (title bar, search, filter chips, sort) + the
## list's own bottom margin, in the 720x1280 design space. Constant across
## devices: stretch mode scales these logical sizes, so only the viewport's
## logical height varies.
const HEADER_CHROME_HEIGHT := 420.0
const LIST_SEPARATION := 14
const PROFILE_SCENE := "res://scenes/hub/profile.tscn"
const FRIENDS_SCENE := "res://scenes/hub/friends.tscn"
## Game Browser filter chips (STANDARDS §2a): [key, English label]. They
## combine (all must match). "Top rated" / "New" / rating sort wait for
## ratings and release dates in the manifest.
const CHIPS := [
	["single", "🤖 Single player"], ["local", "👥 Same phone"], ["online", "🌐 Online"],
	["party", "🎉 Party"], ["fav", "★ Favorites"], ["downloaded", "⬇ Downloaded"],
	["unplayed", "✨ Never played"], ["learn", "🧠 Learn"],
]
const SORTS := [["cat", "By category"], ["az", "A–Z"], ["recent", "Recently played"]]
## Mode icons on a tile, from the manifest's "modes".
const MODE_ICONS := {"cpu": "🤖", "local": "👥", "online": "🌐", "party": "🎉"}

var list_container: VBoxContainer
## Hub v2 (STANDARDS §2, since v0.30): the home view (no scrolling) and the
## Game Browser, two views of this one scene.
var home_view: Control
var browser_view: Control
var profile_btn: Button
var friends_btn: Button
var continue_box: VBoxContainer
var favorites_box: VBoxContainer
var games_btn: Button
var search_box: LineEdit
var chips: Dictionary = {}       # key -> true while that chip is on
var sort_mode: String = "cat"
var _chip_buttons: Dictionary = {}
var _sort_buttons: Dictionary = {}
var expanded_index: int = -1
var account_status_label: Label
var account_status_btn: Button
## Set while a tap is being resolved (manifest check, download, mount), so a
## second tap -- on the same tile or another -- can't start a parallel flow.
var busy: bool = false
var download_overlay: Control
var list_scroll: ScrollContainer
## The open category's header, pinned to the top of the list while its games
## scroll under it, so it can be closed (and another one opened) without
## scrolling back up. Lives on its own layer over the list.
var sticky_layer: Control
var _sticky: Control
var _open_header: Control
var _open_section: Control
## After closing a category, bring its header back into view once the
## shorter list has been laid out (two frames).
var _scroll_back_index := -1
var _scroll_back_frames := 0
## Drag-anywhere scrolling; tap handlers ignore a press that became a drag.
var drag: Node

func _ready() -> void:
	Orientation.lock_portrait()
	pal = Settings.palette()

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

	_build_browser_view()
	_build_home_view()

	# .unbind(2) rather than a lambda on purpose: Godot only auto-disconnects a
	# signal when the connected Callable points at the freed object. A lambda is
	# a separate object that merely captures `self`, so connecting one to a
	# long-lived autoload like Auth survives this scene being freed -- every hub
	# visit would leave another stale connection behind, and the next sign-in
	# would error on each one ("Lambda capture was freed").
	Auth.signed_in.connect(_update_account_status.unbind(2))
	Auth.signed_out.connect(_update_account_status)
	_update_account_status()
	Social.friends_changed.connect(_update_friend_badge)
	_update_friend_badge()

	# A newer live manifest can add games or change versions while the hub is
	# open. Plain method connection, not a lambda -- see CLAUDE.md gotcha.
	Catalog.catalog_changed.connect(_on_catalog_changed)
	Catalog.refresh_manifest(Config.MANIFEST_MAX_AGE_SEC)
	_rebuild_list()
	_refresh_home()
	_show_home()
	if not Catalog.app_update_checked:
		Catalog.check_app_update(_show_update_dialog)
	var requested: String = Social.take_launch_request()
	if requested != "":
		# A game opened from Multiplayer / Friends / an invite: same path as a tile tap.
		Settings.take_resume_scene()  # an invite wins over reopening the last game
		call_deferred("_on_tile_pressed", requested)
	else:
		_resume_last_game()

func _on_catalog_changed() -> void:
	_rebuild_list()
	_refresh_home()

## Android back: the browser goes back to the home view.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and browser_view and browser_view.visible \
			and get_tree().get_nodes_in_group("modal_overlay").filter(func(n): return n.is_visible_in_tree()).is_empty():
		_show_home()

# ---------- home view (STANDARDS §2: fits one screen, no scrolling) ----------

func _build_home_view() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	home_view = margin
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	# Top bar: Profile · Friends · Options.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	profile_btn = _hub_pill("👤", pal.account)
	profile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	profile_btn.custom_minimum_size.x = 60
	profile_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	profile_btn.pressed.connect(_open_screen.bind(PROFILE_SCENE))
	top.add_child(profile_btn)
	friends_btn = _hub_pill(tr("👥 Friends"), pal.ready)
	friends_btn.pressed.connect(_open_screen.bind(FRIENDS_SCENE))
	top.add_child(friends_btn)
	var options_btn := _hub_pill(tr("⚙ Options"), pal.accent)
	options_btn.pressed.connect(_open_options)
	top.add_child(options_btn)

	# The wordmark takes whatever height is left, so nothing else has to scroll.
	var banner_panel := PanelContainer.new()
	banner_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	banner_panel.custom_minimum_size = Vector2(0, 150)
	banner_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(banner_panel)
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
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		banner_panel.add_child(title)

	continue_box = VBoxContainer.new()
	col.add_child(continue_box)
	favorites_box = VBoxContainer.new()
	favorites_box.add_theme_constant_override("separation", 8)
	col.add_child(favorites_box)

	games_btn = Button.new()
	games_btn.custom_minimum_size = Vector2(0, 124)
	games_btn.focus_mode = Control.FOCUS_NONE
	games_btn.add_theme_font_size_override("font_size", 40)
	games_btn.add_theme_color_override("font_color", pal.header_open_text)
	var gsb := _neon_style(_tinted_fill(pal.link), pal.link, 1.0)
	for state in ["normal", "hover", "pressed", "focus"]:
		games_btn.add_theme_stylebox_override(state, gsb)
	games_btn.pressed.connect(_show_browser)
	col.add_child(games_btn)

	var version_label := Label.new()
	version_label.text = "%s · %s" % [Brand.tagline(), tr("v%s (build %d)") % [Version.VERSION, Version.BUILD_NUMBER]]
	version_label.add_theme_font_size_override("font_size", 18)
	version_label.add_theme_color_override("font_color", pal.version)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(version_label)

## Continue (the last game opened) and the ★ Favorites row.
func _refresh_home() -> void:
	if continue_box == null:
		return
	for c in continue_box.get_children() + favorites_box.get_children():
		c.queue_free()
	var count := 0
	for cat in Catalog.categories:
		for g in cat.games:
			if g.has("id"):
				count += 1
	games_btn.text = "🎮  " + tr("Games") + "\n" + tr("%d games") % count
	var last := HubData.last_played()
	var game: Dictionary = Catalog.get_game(last)
	if last != "" and not game.is_empty():
		continue_box.add_child(_make_tile(game, tr("▶ Continue")))
	var favs: Array = HubData.favorites().filter(func(id): return not Catalog.get_game(id).is_empty())
	var head := Label.new()
	head.text = tr("★ Favorites").to_upper()
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", pal.count)
	favorites_box.add_child(head)
	if favs.is_empty():
		var hint := Label.new()
		hint.text = tr("Tap ☆ on any game in 🎮 Games to pin it here.")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 20)
		hint.add_theme_color_override("font_color", pal.text_dim)
		favorites_box.add_child(hint)
		return
	# Four fit across a phone; the rest are a tap away in the browser.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	favorites_box.add_child(row)
	for id in favs.slice(0, 4 if favs.size() <= 4 else 3):
		row.add_child(_fav_tile(Catalog.get_game(id)))
	if favs.size() > 4:
		var more := _hub_pill(tr("+%d more") % (favs.size() - 3), pal.count)
		more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		more.custom_minimum_size.y = 120
		more.pressed.connect(_show_browser_with.bind("fav"))
		row.add_child(more)

func _fav_tile(game: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 120)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var color: Color = pal.ready if Catalog.state_of(game) == Catalog.STATE_READY else pal.download
	var sb := _neon_style(_tinted_fill(color), color, 0.5)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_child(_game_icon(game, 52.0))
	var t := Label.new()
	t.text = Lang.pick(game, "title")
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", pal.text)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.clip_text = true
	t.custom_minimum_size = Vector2(10, 0)
	col.add_child(t)
	b.pressed.connect(_on_tile_pressed.bind(str(game.id)))
	return b

func _game_icon(game: Dictionary, size: float) -> Control:
	if GameIcons.has(str(game.get("id", ""))):
		var art := Control.new()
		art.custom_minimum_size = Vector2(size, size)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.draw.connect(GameIcons.draw.bind(art, str(game.id)))
		return art
	var l := Label.new()
	l.text = str(game.get("icon", "🎮"))
	l.add_theme_font_size_override("font_size", int(size * 0.62))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l

func _hub_pill(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color)
	b.add_theme_color_override("font_pressed_color", color)
	var sb := _neon_style(pal.header_fill, color, 0.5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	return b

func _show_home() -> void:
	home_view.visible = true
	browser_view.visible = false
	sticky_layer.visible = false
	_refresh_home()

func _show_browser() -> void:
	if busy:
		return
	home_view.visible = false
	browser_view.visible = true
	sticky_layer.visible = true
	_rebuild_list()

func _show_browser_with(chip: String) -> void:
	chips = {chip: true}
	_sync_chip_buttons()
	_show_browser()

# ---------- Game Browser (STANDARDS §2a) ----------

func _build_browser_view() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	browser_view = root

	var head_margin := MarginContainer.new()
	for side in ["left", "right"]:
		head_margin.add_theme_constant_override("margin_" + side, 14)
	head_margin.add_theme_constant_override("margin_top", 16)
	head_margin.add_theme_constant_override("margin_bottom", 10)
	root.add_child(head_margin)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head_margin.add_child(head)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	head.add_child(bar)
	var back := _hub_pill(tr("← Hub"), pal.link)
	back.custom_minimum_size.x = 130
	back.pressed.connect(_show_home)
	bar.add_child(back)
	var title := Label.new()
	title.text = tr("🎮 Games")
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", pal.accent)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var balance := Control.new()
	balance.custom_minimum_size.x = 40
	bar.add_child(balance)
	search_box = LineEdit.new()
	search_box.placeholder_text = tr("🔍 Search games")
	search_box.clear_button_enabled = true
	search_box.custom_minimum_size = Vector2(0, 60)
	search_box.add_theme_font_size_override("font_size", 26)
	search_box.text_changed.connect(_on_search_changed)
	head.add_child(search_box)
	var chip_flow := HFlowContainer.new()
	chip_flow.add_theme_constant_override("h_separation", 8)
	chip_flow.add_theme_constant_override("v_separation", 8)
	head.add_child(chip_flow)
	for c in CHIPS:
		var b := _chip(tr(c[1]))
		b.pressed.connect(_on_chip.bind(c[0]))
		chip_flow.add_child(b)
		_chip_buttons[c[0]] = b
	var sort_row := HFlowContainer.new()
	sort_row.add_theme_constant_override("h_separation", 8)
	head.add_child(sort_row)
	var sort_label := Label.new()
	sort_label.text = tr("Sort:")
	sort_label.add_theme_font_size_override("font_size", 20)
	sort_label.add_theme_color_override("font_color", pal.text_dim)
	sort_row.add_child(sort_label)
	for so in SORTS:
		var b := _chip(tr(so[1]))
		b.pressed.connect(_on_sort.bind(so[0]))
		sort_row.add_child(b)
		_sort_buttons[so[0]] = b
	_sync_chip_buttons()

	# The list scrolls under the browser's header.
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
	sticky_layer = Control.new()
	sticky_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	sticky_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sticky_layer)

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

func _chip(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", pal.text)
	b.add_theme_color_override("font_pressed_color", pal.header_open_text)
	b.add_theme_color_override("font_hover_pressed_color", pal.header_open_text)
	var off := _neon_style(pal.header_fill, pal.link_dim, 0.2)
	var on := _neon_style(_tinted_fill(pal.link), pal.link, 0.8)
	for sb in [off, on]:
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, off)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	return b

func _sync_chip_buttons() -> void:
	for k in _chip_buttons:
		_chip_buttons[k].set_pressed_no_signal(chips.has(k))
	for k in _sort_buttons:
		_sort_buttons[k].set_pressed_no_signal(k == sort_mode)

func _on_chip(key: String) -> void:
	if chips.has(key):
		chips.erase(key)
	else:
		chips[key] = true
	_sync_chip_buttons()
	_rebuild_list()

func _on_sort(key: String) -> void:
	sort_mode = key
	_sync_chip_buttons()
	_rebuild_list()

func _on_search_changed(_text: String) -> void:
	_rebuild_list()

## Search, a chip or a sort other than "By category" turns the category
## list into one filtered list of games.
func _filtering() -> bool:
	return (search_box != null and search_box.text.strip_edges() != "") or not chips.is_empty() or sort_mode != "cat"

func _matches(game: Dictionary, recent: Dictionary) -> bool:
	var q := search_box.text.strip_edges().to_lower()
	if q != "" and not Lang.pick(game, "title").to_lower().contains(q) and not str(game.get("title", "")).to_lower().contains(q):
		return false
	var modes := str(game.get("modes", ""))
	var id := str(game.id)
	for key in chips:
		match key:
			"single":
				if modes != "" and not modes.contains("cpu"):
					return false
			"local", "online", "party":
				if not modes.contains(key):
					return false
			"fav":
				if not HubData.is_favorite(id):
					return false
			"downloaded":
				if Catalog.state_of(game) != Catalog.STATE_READY:
					return false
			"unplayed":
				if recent.has(id) or FileAccess.file_exists("user://stats_%s.json" % id):
					return false
			"learn":
				if (game.get("learn", []) as Array).is_empty():
					return false
	return true

func _filtered_games() -> Array:
	var recent := HubData.recent()
	var out: Array = []
	for cat in Catalog.categories:
		for g in cat.games:
			if g.has("id") and _matches(g, recent):
				out.append(g)
	match sort_mode:
		"recent":
			out.sort_custom(func(a, b):
				var ta := float(recent.get(a.id, 0))
				var tb := float(recent.get(b.id, 0))
				return ta > tb if ta != tb else Lang.pick(a, "title") < Lang.pick(b, "title"))
		_:
			out.sort_custom(func(a, b): return Lang.pick(a, "title").naturalnocasecmp_to(Lang.pick(b, "title")) < 0)
	return out

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
	if not busy:
		get_tree().change_scene_to_file("res://scenes/hub/options.tscn")

func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _open_screen(scene: String) -> void:
	if not busy:
		get_tree().change_scene_to_file(scene)

## "👥 Friends" shows how many requests are waiting.
func _update_friend_badge() -> void:
	if friends_btn == null:
		return
	var waiting := 0
	for f in Social.friends:
		if str(f.get("status", "")) == "incoming":
			waiting += 1
	friends_btn.text = tr("👥 Friends") + (" (%d)" % waiting if waiting > 0 else "")

## The top bar's Profile button: the player's name, or "Sign In".
func _update_account_status() -> void:
	if profile_btn == null:
		return
	if Auth.is_logged_in():
		profile_btn.text = "👤 %s" % Auth.get_display_name()
	else:
		profile_btn.text = "👤 " + tr("Profile")

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
	_open_header = null
	_open_section = null
	_clear_sticky()

	# With nothing expanded there'd otherwise be dead space under the last row,
	# so the headers grow to divide up whatever height this screen actually has.
	# Once a category opens, they drop back to compact so its games get the room.
	if _filtering():
		var found := _filtered_games()
		for g in found:
			list_container.add_child(_make_tile(g))
		if found.is_empty():
			var none := Label.new()
			none.text = tr("No games match.")
			none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			none.add_theme_font_size_override("font_size", 26)
			none.add_theme_color_override("font_color", pal.text_dim)
			list_container.add_child(none)
		return
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
		var header := _make_section_header(category, i, row_height)
		list_container.add_child(header)
		if expanded_index == i:
			var section := VBoxContainer.new()
			section.add_theme_constant_override("separation", 12)
			var section_margin := MarginContainer.new()
			section_margin.add_theme_constant_override("margin_top", 12)
			section_margin.add_child(section)
			list_container.add_child(section_margin)
			for game in category.games:
				section.add_child(_make_tile(game))
			_open_header = header
			_open_section = section_margin
	_update_sticky.call_deferred()

func _toggle_category(index: int) -> void:
	if drag.moved:
		return
	var closing := expanded_index == index
	expanded_index = -1 if closing else index
	_rebuild_list()
	if closing:
		# Closed from the pinned header far down the list: the list is now
		# short, so bring that category's row back into view.
		_scroll_back_index = index
		_scroll_back_frames = 2

## Shows the open category's header pinned at the top of the list once the
## real one has scrolled out of view, until its games have scrolled past.
## Its button is the same toggle, so tapping it closes the category.
func _update_sticky() -> void:
	if expanded_index < 0 or not is_instance_valid(_open_header) or not is_instance_valid(_open_section) \
			or not _open_header.is_inside_tree():
		_clear_sticky()
		return
	var top: float = list_scroll.get_global_rect().position.y
	var head: Rect2 = _open_header.get_global_rect()
	var games_end: float = _open_section.get_global_rect().end.y
	if head.position.y >= top or games_end <= top + head.size.y:
		_clear_sticky()
		return
	if _sticky == null:
		_sticky = _make_section_header(Catalog.categories[expanded_index], expanded_index, head.size.y)
		sticky_layer.add_child(_sticky)
	var origin: Vector2 = sticky_layer.get_global_rect().position
	_sticky.position = Vector2(head.position.x - origin.x, top - origin.y)
	_sticky.size = head.size

## queue_free, not free: this can run from the pinned header's own `pressed`.
func _clear_sticky() -> void:
	if _sticky != null and is_instance_valid(_sticky):
		_sticky.queue_free()
	_sticky = null

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
func _make_tile(game: Dictionary, heading: String = "") -> Control:
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

	# The whole tile is one flat button underneath; the row above it lets
	# clicks through except on its ★ (STANDARDS §2a favourites).
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.disabled = not available
	button.focus_mode = Control.FOCUS_NONE
	if available:
		button.pressed.connect(_on_tile_pressed.bind(str(game.id)))
	panel.add_child(button)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	var text_col := VBoxContainer.new()
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 0)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)
	if heading != "":
		var head := Label.new()
		head.text = heading
		head.add_theme_font_size_override("font_size", 20)
		head.add_theme_color_override("font_color", state_color)
		text_col.add_child(head)
	var label := Label.new()
	label.text = Lang.pick(game, "title")
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", pal.text if available else pal.soon_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# One line that shortens with "…" ("Backgammon" at Extra large) instead
	# of running under ▶ Play.
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 40
	text_col.add_child(label)
	var icons := ""
	for m in str(game.get("modes", "")).split(",", false):
		icons += str(MODE_ICONS.get(m.strip_edges(), ""))
	if icons != "":
		var modes_label := Label.new()
		modes_label.text = icons
		modes_label.add_theme_font_size_override("font_size", 20)
		modes_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		text_col.add_child(modes_label)

	var tag := Label.new()
	tag.text = tag_text
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", state_color)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)

	if available and heading == "":
		var star := Button.new()
		star.text = "★" if HubData.is_favorite(str(game.id)) else "☆"
		star.flat = true
		star.focus_mode = Control.FOCUS_NONE
		star.custom_minimum_size = Vector2(56, 56)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		star.add_theme_font_size_override("font_size", 34)
		star.add_theme_color_override("font_color", pal.update)
		star.add_theme_color_override("font_hover_color", pal.update)
		star.add_theme_color_override("font_pressed_color", pal.update)
		star.pressed.connect(_on_star.bind(str(game.id), star))
		row.add_child(star)

	return panel

func _on_star(id: String, star: Button) -> void:
	if drag and drag.moved:
		return
	star.text = "★" if HubData.toggle_favorite(id) else "☆"
	if chips.has("fav"):
		_rebuild_list.call_deferred()


## ---------- tapping a game ----------

## Never waits on the network before acting: the manifest is refreshed in the
## background when the hub opens, so by the time a player taps, Catalog
## already knows whether an update exists. Offline, a downloaded game just
## launches, and a failed update download falls back to the copy on disk.
func _on_tile_pressed(id: String) -> void:
	if busy or (browser_view.visible and drag.moved):
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
	if error == "":
		HubData.record_play(str(game.id))
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
	# Checked every frame while a category is open: a scroll signal fires
	# before the list has moved, and drags, flings and relayouts all count.
	if expanded_index >= 0 or _sticky != null:
		_update_sticky()
	if _scroll_back_frames > 0:
		_scroll_back_frames -= 1
		if _scroll_back_frames == 0 and _scroll_back_index >= 0 and _scroll_back_index < list_container.get_child_count():
			list_scroll.ensure_control_visible(list_container.get_child(_scroll_back_index))
			_scroll_back_index = -1
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
