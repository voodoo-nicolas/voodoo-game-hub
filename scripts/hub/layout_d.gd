extends Control

## Layout D, the hub's main menu (owner 2026-11-20): a side rail + a Home screen + game grids.
##
##   Rail (top to bottom): Profile & settings (pinned) | Search, Home, Favorites | the
##   categories of scripts/hub/categories.gd, in its order, hiding any with fewer than
##   MIN_GAMES_TO_SHOW live games.
##   Home: featured banner (manifest "featured"), Continue playing (or "Start here" from
##   "starter" on a first launch), New (per-game "added"), Recently updated (pack
##   "updated"; TODO: "Popular this week" once Supabase counts plays). Every row: See all.
##   Category / Favorites / See all: a grid with "N games" (always counted, never typed).
##   Search: name (EN + ES) and tags; chips Multiplayer, Quick play, Offline (downloaded).
##
## Device class comes from the screen's SHORT side in dp (phone < 600 <= tablet < 1000 <= PC;
## a desktop OS with >= 600 dp counts as PC) and never changes on rotation; the layout follows
## the orientation. Sizes are in dp (rail, tiles) so text size 1.0-1.4 only grows the text.
## HUB_DEVICE=phone|tablet|pc and HUB_DP_SHORT=<dp> fake a device for screenshots.
##
## The hub (hub.gd) owns the rest: launching / downloading (_on_tile_pressed), Options as a
## layer (Profile), dialogs, the background. Tiles, the game card and the scroller are the
## Game Browser's own pieces (game_tile.gd, game_detail.gd, touch_scroll.gd), unchanged.

const Categories = preload("res://scripts/hub/categories.gd")
const GameTile = preload("res://scripts/hub/game_tile.gd")
const GameDetail = preload("res://scripts/hub/game_detail.gd")
const TouchScroll = preload("res://scripts/hub/touch_scroll.gd")
const HubLook = preload("res://scripts/hub/hub_look.gd")
const HubArt = preload("res://scripts/hub/hub_art.gd")
const HubData = preload("res://scripts/common/hub_data.gd")
const GameArt = preload("res://scripts/common/game_art.gd")
const Orientation = preload("res://scripts/common/orientation.gd")

const ROW_MAX := 10              # tiles in a Home row before "See all"
const BANNER_SECONDS := 5.0      # featured banner auto-advance
const LONG_PRESS := 0.45         # rail: long-press shows the label when labels are hidden
const FADE := 0.16               # view change
## Rail auto-hide (owner 2026-11-21): RAIL_IDLE s with no touch on the rail slides it away and the
## games take the full width; then a drag from the left edge (EDGE_DP wide) toward the centre
## pulls it back over the games, and it slides away again after RAIL_IDLE s.
const RAIL_IDLE := 15.0
const EDGE_DP := 24.0
const RAIL_SLIDE := 0.22
## Search's Spanish words for tags, so "multijugador" finds multiplayer games too.
const TAG_ES := {"multiplayer": "multijugador", "online": "en línea", "offline": "sin conexión",
	"quick": "rápido", "original": "original"}

var hub: Node
var current := "home"            # home | search | favs | cat:<id> | all:<row key>
var _scroll_of := {}             # view -> vertical scroll, kept across re-layouts
var _search_text := ""
var _chips := {}                 # chip -> true
var _focus_first := true

# metrics (_measure)
var device := "phone"
var landscape := false
var u := 1.0                     # canvas units per dp
var tf := 1.0                    # text factor (Options > Text size)
var labels := false
var rail_w := 56.0
var item_h := 42.0
var icon_px := 24.0
var pad := 8.0

# nodes
var _rail: Panel
var _rail_scroll: ScrollContainer
var _rail_box: VBoxContainer
var _rail_hint: Control
var _rail_items := {}            # key -> Button
var _profile_btn: Button
var _main: Control
var _header: HBoxContainer
var _title: Label
var _count: Label
var _body_scroll: ScrollContainer
var _body_root: Control        # in the scroll: holds the current view (+ parked ones)
var _body: VBoxContainer        # the view being built / shown (cached for grids and Home)
var _view_cache := {}           # view key -> its content VBox (meta: header, tiles, banner)
var _trash: Array = []          # the previous layout's nodes, freed a piece per frame
var _warm_queue: Array = []     # categories to build in the background while Home shows
var _recent_views: Array = []   # parked view keys, most recent first
var _fill_queue: Array = []     # tiles still to add: [{box, games, size, tiles}], a few per frame
const FILL_BUDGET_USEC := 5000
const PARKED := Vector2(-100000, 0)
const TRASH_BUDGET_USEC := 3000
const WARM_DELAY := 1.0
## Views kept parked (built, off-screen): the most recently used. More made every rotation
## slower (the engine re-lays out every parked tile before we get to drop them).
const MAX_PARKED := 4   # s after a (re)build before categories start building in the background
var _prebuilding := false
var _tex_refs := {}             # pictures already loaded (kept, so a revisit doesn't reload them)
var _fav_set := {}              # id -> true; HubData reads favorites.json on every call (a file
var _fav_read := false          #   read per tile on a phone), so a build reads it once
var _art_path_of := {}          # game id -> HubArt.tile_path (two ResourceLoader.exists each)
var scroller: Node
var _tiles: Array = []
var _lazy_dirty := true
var _search_field: LineEdit
var _results: Control
var _banner: Control
var _banner_games: Array = []
var _banner_i := 0
var _banner_timer: Timer
var _dim: Control
var _detail: Control
var _detail_id := ""
var _tooltip: Label
var _press_timer: Timer
var _long_fired := false
var _built_key := ""
var _relayout_queued := false
var _home_key := ""              # refresh_home(): what Home showed last
var _account_key := ""           # update_account(): who the rail showed last
var _rail_docked := true         # the rail takes its own column (until it first auto-hides)
var _rail_open := true           # the rail is on screen (docked, or pulled out over the games)
var _rail_idle: Timer
var _rail_tween: Tween
var _rail_handle: Control        # the little tab at the left edge while the rail is away
var _edge_drag := false          # a drag that started at the left edge, pulling the rail out
var _edge_start := Vector2.ZERO
var _kb_input := false           # last input was keys / pad (focus on the rail keeps it out)

# ---------- setup ----------

func setup(hub_node: Node) -> void:
	hub = hub_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_press_timer = Timer.new()
	_press_timer.one_shot = true
	_press_timer.timeout.connect(_on_rail_long)
	add_child(_press_timer)
	_banner_timer = Timer.new()
	_banner_timer.wait_time = BANNER_SECONDS
	_banner_timer.timeout.connect(_banner_step.bind(1))
	add_child(_banner_timer)
	_rail_idle = Timer.new()
	_rail_idle.one_shot = true
	_rail_idle.wait_time = RAIL_IDLE
	_rail_idle.timeout.connect(_on_rail_idle)
	add_child(_rail_idle)
	resized.connect(_queue_relayout)
	_build()
	# The categories' background pictures load on a worker thread now and stay in memory, so
	# opening a category doesn't wait on a big JPG (~55 ms each on a PC).
	for path in hub.CATEGORY_ART.values():
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path)
	_keep_category_art.call_deferred()

## Holds the preloaded category pictures (load() then finds them in the cache).
func _keep_category_art() -> void:
	for i in 600:
		var pending := false
		for path in hub.CATEGORY_ART.values():
			if _tex_refs.has(path) or not ResourceLoader.exists(path):
				continue
			match ResourceLoader.load_threaded_get_status(path):
				ResourceLoader.THREAD_LOAD_LOADED:
					_tex_refs[path] = ResourceLoader.load_threaded_get(path)
				ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					pending = true
		if not pending or not is_inside_tree():
			return
		await get_tree().process_frame

func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	_relayout.call_deferred()

func _relayout() -> void:
	_relayout_queued = false
	var was_land := landscape
	_measure()
	var key := "%s|%s|%d|%d|%s" % [device, landscape, int(size.x), int(size.y), _rail_docked]
	if key == _built_key:
		return
	if was_land != landscape and _built_key != "":
		Orientation.override_next(landscape)   # a hub reload keeps the way the phone is held
	_build()

## Rebuilds everything, keeping the selected rail item and each view's scroll.
func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_remember_scroll()
	_view_cache.clear()
	_recent_views.clear()
	_fill_queue.clear()
	_warm_queue.clear()
	# The old layout (a rotation, a new manifest...) is hidden now and freed a view per
	# frame (_process): freeing ~100 tiles at once stalled a rotation by ~130 ms on a PC.
	for c in get_children():
		if c != _press_timer and c != _banner_timer and c != _rail_idle and not _trash.has(c):
			if c is CanvasItem:
				c.visible = false
			c.set_process_mode(Node.PROCESS_MODE_DISABLED)
			_trash.append(c)
	_rail_items.clear()
	_rail_styles.clear()   # sizes depend on the device / dp
	_rail_on = ""          # the new buttons are all drawn "off"
	_fav_read = false      # a new manifest / account: read the favorites and art paths again
	_art_path_of.clear()
	_tiles = []
	_measure()
	_built_key = "%s|%s|%d|%d|%s" % [device, landscape, int(size.x), int(size.y), _rail_docked]
	scroller = TouchScroll.new()
	scroller.bounds = self
	scroller.set("skip_press", _on_rail_or_edge)
	add_child(scroller)
	_build_rail()
	_build_main()
	_place_rail()
	get_tree().create_timer(WARM_DELAY, false).timeout.connect(_warm_up)
	_home_key = var_to_str([HubData.recent(), HubData.favorites()])
	_account_key = _profile_name() + str(Auth.is_logged_in())
	_show(current, false)

# ---------- metrics ----------

## {device, short_dp, u}: device class from the short side in dp (fakeable for screenshots).
static func device_info(view_size: Vector2) -> Dictionary:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		win = view_size   # headless (tests): no window, the view is the screen
	var mobile := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var dpi := float(DisplayServer.screen_get_dpi())
	var base := 160.0 if mobile else 96.0   # Android dp / Windows device-independent px
	if dpi <= 0.0:
		dpi = base
	var short_dp := minf(win.x, win.y) * base / dpi
	if OS.get_environment("HUB_DP_SHORT") != "":
		short_dp = float(OS.get_environment("HUB_DP_SHORT"))
	# phone < 600 dp <= tablet < 1000 dp <= PC; a desktop window of 600 dp or more is a PC.
	var dev := "phone"
	if short_dp >= 1000.0 or (short_dp >= 600.0 and not mobile):
		dev = "pc"
	elif short_dp >= 600.0:
		dev = "tablet"
	if OS.get_environment("HUB_DEVICE") in ["phone", "tablet", "pc"]:
		dev = OS.get_environment("HUB_DEVICE")
	var short_cu := minf(view_size.x, view_size.y)
	return {"device": dev, "short_dp": short_dp, "u": short_cu / maxf(short_dp, 1.0)}

func _measure() -> void:
	var info := device_info(size)
	device = info.device
	u = info.u
	landscape = size.x > size.y
	tf = float(Settings.TEXT_SCALES[clampi(Settings.text_size, 0, Settings.TEXT_SCALES.size() - 1)])
	labels = device != "phone"
	pad = dp(8)
	if device == "phone" and not landscape:
		rail_w = dp(56); item_h = dp(42); icon_px = dp(24)
	elif device == "phone":
		rail_w = dp(44); item_h = dp(34); icon_px = dp(20)
	else:
		item_h = dp(46); icon_px = dp(22)
		# label + icon + margins (12 + 8) + icon gap (12) + the button's inset (8) + a little air
		rail_w = clampf(_widest_label() + icon_px + dp(52), dp(160), dp(250))

func dp(x: float) -> float:
	return x * u

## A font size: dp times the text factor (Options > Text size grows the text, not the frame).
func fs(x: float) -> int:
	return maxi(8, int(round(x * u * tf)))

func _widest_label() -> float:
	var font := get_theme_default_font()
	var w := 0.0
	var names: Array = [tr("Search"), tr("Home"), tr("Favorites"), _profile_name()]
	for c in _visible_categories():
		names.append(Categories.label(c, true))
	for n in names:
		w = maxf(w, font.get_string_size(str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(15)).x)
	return w

func _visible_categories() -> Array:
	var out: Array = []
	for id in Categories.ids():
		if Catalog.games_in(id).size() >= Categories.MIN_GAMES_TO_SHOW:
			out.append(id)
	return out

# ---------- rail ----------

func _build_rail() -> void:
	_rail = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.07, 0.86)
	sb.border_color = Color(0.25, 0.4, 0.6, 0.35)
	sb.border_width_right = maxi(1, int(dp(1)))
	_rail.add_theme_stylebox_override("panel", sb)
	_rail.position = Vector2.ZERO
	_rail.size = Vector2(rail_w, size.y)
	add_child(_rail)
	var v := VBoxContainer.new()
	v.position = Vector2(0, dp(6))
	v.size = Vector2(rail_w, size.y - dp(6))
	v.add_theme_constant_override("separation", int(dp(4)))
	_rail.add_child(v)

	# 1. Profile & settings, pinned (the rest scrolls on a short screen).
	_profile_btn = _rail_button("profile", _profile_name(), null)
	_profile_btn.pressed.connect(_on_rail_pressed.bind("profile"))
	_profile_btn.custom_minimum_size.y = item_h + dp(6)
	_draw_avatar(_profile_btn)
	v.add_child(_profile_btn)
	v.add_child(_divider())

	_rail_scroll = ScrollContainer.new()
	_rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_rail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rail_scroll.follow_focus = true
	v.add_child(_rail_scroll)
	var drag = preload("res://scripts/common/drag_scroll.gd").new()
	_rail_scroll.add_child(drag)
	_rail_scroll.set_meta("drag", drag)
	_rail_box = VBoxContainer.new()
	_rail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail_box.add_theme_constant_override("separation", int(dp(3)))
	_rail_scroll.add_child(_rail_box)

	for spec in [["search", tr("Search"), "search"], ["home", tr("Home"), "home"], ["favs", tr("Favorites"), "star"]]:
		_add_rail_item(spec[0], spec[1], spec[2])
	_rail_box.add_child(_divider())
	for c in _visible_categories():
		_add_rail_item("cat:" + c, Categories.label(c, true), str(Categories.info(c).icon))

	# Phone landscape: the list scrolls; a fade + chevron says there is more below.
	_rail_hint = TextureRect.new()
	(_rail_hint as TextureRect).texture = HubArt.scrim_bottom()
	(_rail_hint as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	(_rail_hint as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
	_rail_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail.add_child(_rail_hint)
	var chev := TextureRect.new()
	chev.texture = Categories.icon("chevron-right")
	chev.rotation_degrees = 90
	chev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chev.size = Vector2(dp(16), dp(16))
	chev.pivot_offset = chev.size / 2.0
	chev.modulate = Color(1, 1, 1, 0.7)
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chev.name = "Chevron"
	_rail_hint.add_child(chev)
	_rail_scroll.get_v_scroll_bar().value_changed.connect(_update_rail_hint.unbind(1))
	_update_rail_hint.call_deferred()

func _add_rail_item(key: String, text: String, icon_name: String) -> void:
	var b := _rail_button(key, text, Categories.icon(icon_name))
	b.pressed.connect(_on_rail_pressed.bind(key))
	_rail_box.add_child(b)

func _rail_button(key: String, text: String, tex: Texture2D) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(rail_w - dp(8), item_h)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.text = text if labels else ""
	b.tooltip_text = text
	b.icon = tex
	b.expand_icon = true   # scaled to icon_max_width (the SVGs import at 4x, so they stay sharp)
	b.add_theme_constant_override("icon_max_width", int(icon_px))
	b.add_theme_constant_override("h_separation", int(dp(12)))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if labels else HORIZONTAL_ALIGNMENT_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if labels else HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.add_theme_font_size_override("font_size", fs(15))
	b.set_meta("key", key)
	b.button_down.connect(_on_rail_down.bind(b))
	b.button_up.connect(_press_timer.stop)
	_style_rail(b, false)
	_rail_items[key] = b
	return b

var _rail_styles := {}   # "on"/"off" -> {state: StyleBoxFlat}, made once per build
var _rail_on := ""       # the rail item drawn highlighted

func _style_rail(b: Button, on: bool) -> void:
	var accent: Color = HubLook.pal().link
	var key := "on" if on else "off"
	if _rail_styles.has(key):
		for state in _rail_styles[key]:
			b.add_theme_stylebox_override(state, _rail_styles[key][state])
		_rail_colors(b, on, accent)
		return
	_rail_styles[key] = {}
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(accent.r, accent.g, accent.b, 0.22) if on else Color(1, 1, 1, 0.0)
		if state == "hover" or state == "pressed":
			s.bg_color = s.bg_color.lerp(Color(1, 1, 1, 0.1), 0.6)
		s.set_corner_radius_all(int(dp(10)))
		s.content_margin_left = dp(12) if labels else dp(4)
		s.content_margin_right = dp(8) if labels else dp(4)
		if on:
			s.border_width_left = maxi(2, int(dp(3)))
			s.border_color = accent
		if state == "focus":
			s.set_border_width_all(maxi(2, int(dp(2))))
			s.border_color = Color(1, 1, 1, 0.9)   # visible focus ring (keyboard / controller)
		b.add_theme_stylebox_override(state, s)
		_rail_styles[key][state] = s
	_rail_colors(b, on, accent)

func _rail_colors(b: Button, on: bool, accent: Color) -> void:
	var c := Color.WHITE if on else Color(0.78, 0.82, 0.9)
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color"]:
		b.add_theme_color_override(k, c if not k.begins_with("icon") else (accent.lightened(0.25) if on else c))

func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.12)
	line.custom_minimum_size = Vector2(rail_w - dp(20), maxf(1.0, dp(1)))
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _profile_name() -> String:
	return Auth.get_display_name() if Auth.is_logged_in() else tr("Sign in")

## Round avatar with the player's initial (or a key when signed out), left of the name.
func _draw_avatar(b: Button) -> void:
	var dot := Control.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := icon_px * 0.72
	dot.custom_minimum_size = Vector2(r * 2, r * 2)
	dot.size = dot.custom_minimum_size
	b.add_child(dot)
	var place := func():
		var x: float = (dp(12) if labels else (b.size.x - r * 2) / 2.0)
		dot.position = Vector2(x, (b.size.y - r * 2) / 2.0)
	b.resized.connect(place)
	place.call()
	var name := Auth.get_display_name() if Auth.is_logged_in() else ""
	dot.draw.connect(func():
		var col: Color = HubLook.pal().account if name != "" else HubLook.pal().ready
		dot.draw_circle(Vector2(r, r), r, col.darkened(0.45))
		dot.draw_arc(Vector2(r, r), r - 1.0, 0, TAU, 32, col, maxf(1.5, dp(1.5)), true)
		var font := get_theme_default_font()
		var ch := name.substr(0, 1).to_upper() if name != "" else "🔑"
		var size_px := int(r * 1.1)
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
		dot.draw_string(font, Vector2(r - w.x / 2.0, r + size_px * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color.WHITE))
	# The avatar takes the icon's place: an empty icon of its size keeps the name clear of it.
	var img := Image.create(maxi(1, int(r * 2)), maxi(1, int(r * 2)), false, Image.FORMAT_RGBA8)
	b.icon = ImageTexture.create_from_image(img)
	b.expand_icon = false
	if labels:
		b.text = _profile_name()

func _update_rail_hint() -> void:
	if _rail_hint == null or not is_instance_valid(_rail_hint):
		return
	var bar := _rail_scroll.get_v_scroll_bar()
	var more := bar.max_value - bar.page > 1.0 and bar.value < bar.max_value - bar.page - 2.0
	_rail_hint.visible = more
	var h := dp(36)
	_rail_hint.position = Vector2(0, size.y - h)
	_rail_hint.size = Vector2(rail_w, h)
	var chev := _rail_hint.get_node_or_null("Chevron") as Control
	if chev:
		chev.position = Vector2((rail_w - chev.size.x) / 2.0, h - chev.size.y - dp(4))

func _select_rail(key: String) -> void:
	var rail_key := key
	if key.begins_with("all:"):
		rail_key = "home"
	# Only the item that loses the highlight and the one that gets it: restyling all ~14
	# buttons (13 theme overrides each) cost ~20 ms on every switch.
	if rail_key == _rail_on and _rail_items.has(rail_key):
		return
	if _rail_items.has(_rail_on):
		_style_rail(_rail_items[_rail_on], false)
	if _rail_items.has(rail_key):
		_style_rail(_rail_items[rail_key], true)
	_rail_on = rail_key

func _on_rail_down(b: Button) -> void:
	_long_fired = false
	if not labels:
		_press_timer.set_meta("button", b)
		_press_timer.start(LONG_PRESS)

## Long-press (labels hidden): the item's name floats next to it for a moment.
func _on_rail_long() -> void:
	var b = _press_timer.get_meta("button") if _press_timer.has_meta("button") else null
	if b == null or not is_instance_valid(b):
		return
	var drag = _rail_scroll.get_meta("drag") if _rail_scroll.has_meta("drag") else null
	if drag != null and drag.moved:
		return
	_long_fired = true
	Settings.buzz(20)
	_show_tooltip(b.tooltip_text, b)

func _show_tooltip(text: String, near: Control) -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = Label.new()
	_tooltip.text = text
	_tooltip.add_theme_font_size_override("font_size", fs(15))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.14, 0.96)
	sb.border_color = HubLook.pal().link
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(dp(8)))
	sb.set_content_margin_all(dp(8))
	_tooltip.add_theme_stylebox_override("normal", sb)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)
	var r := near.get_global_rect()
	_tooltip.global_position = Vector2(r.end.x + dp(6), r.position.y + (r.size.y - dp(34)) / 2.0)
	var tw := _tooltip.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_tooltip, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_tooltip.queue_free)

func _on_rail_pressed(key: String) -> void:
	var drag = _rail_scroll.get_meta("drag") if _rail_scroll != null and _rail_scroll.has_meta("drag") else null
	if _long_fired or (drag != null and drag.moved):
		_long_fired = false
		return
	if key == "profile":
		hub._open_options()   # account, friends, language, skin, text size, sound, downloads, membership
		return
	_show(key)

# ---------- rail auto-hide + edge swipe ----------

## After a (re)build: a docked rail stays put; an undocked one starts away, above the games.
func _place_rail() -> void:
	_edge_drag = false
	_rail_handle = Panel.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(HubLook.pal().link, 0.55)
	hs.set_corner_radius_all(int(dp(3)))
	_rail_handle.add_theme_stylebox_override("panel", hs)
	_rail_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_handle.size = Vector2(maxf(2.0, dp(4)), dp(48))
	_rail_handle.position = Vector2(dp(2), (size.y - dp(48)) / 2.0)
	add_child(_rail_handle)
	if _rail_docked:
		_rail_open = true
		_rail.position.x = 0.0
		_rail_handle.visible = false
		_rail_idle.start()
	else:
		move_child(_rail, -1)   # drawn over the games
		_set_rail_x(0.0 if _rail_open else -rail_w)
		if _rail_open:
			_rail_idle.start()

func _set_rail_x(x: float) -> void:
	_rail.position.x = x
	_rail.visible = x > -rail_w + 0.5
	_rail_handle.visible = not _rail_docked and x <= -rail_w + 0.5

func _slide_rail(to_x: float, done: Callable = Callable()) -> void:
	if _rail_tween != null and _rail_tween.is_valid():
		_rail_tween.kill()
	_rail.visible = true
	_rail_handle.visible = false
	if Settings.reduce_motion:
		_set_rail_x(to_x)
		if done.is_valid():
			done.call()
		return
	_rail_tween = _rail.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rail_tween.tween_method(_set_rail_x, _rail.position.x, to_x, RAIL_SLIDE)
	if done.is_valid():
		_rail_tween.tween_callback(done)

func _open_rail() -> void:
	if _rail == null or not is_instance_valid(_rail):
		return
	_rail_idle.start()
	if _rail_open and _rail.position.x >= 0.0:
		return
	_rail_open = true
	_slide_rail(0.0)

func _close_rail() -> void:
	_rail_idle.stop()
	_rail_open = false
	var f := get_viewport().gui_get_focus_owner()
	if f != null and _rail.is_ancestor_of(f):
		f.release_focus()
	if _rail_docked:
		# First hide: slide away, then lay the games out over the full width (once).
		_slide_rail(-rail_w, _undock)
	else:
		_slide_rail(-rail_w)

func _undock() -> void:
	_rail_docked = false
	_build()

func _on_rail_idle() -> void:
	if _rail == null or not is_instance_valid(_rail) or not _rail_open:
		return
	if not is_visible_in_tree() or _overlay_open() or _press_timer.time_left > 0.0:
		_rail_idle.start()   # Options / a dialog is up, or a finger is down on the rail
		return
	var f := get_viewport().gui_get_focus_owner()
	if _kb_input and f != null and _rail.is_ancestor_of(f):
		_rail_idle.start()   # walking the rail with keys / a pad
		return
	_close_rail()

func _overlay_open() -> bool:
	for n in get_tree().get_nodes_in_group("modal_overlay"):
		if not n.is_queued_for_deletion() and n.is_visible_in_tree():
			return true
	return false

## TouchScroll asks this on every press: the rail (when it is over the games) and the edge
## strip are not the games' scroll area.
func _on_rail_or_edge(pos: Vector2) -> bool:
	if _rail_docked or _rail == null or not is_instance_valid(_rail):
		return false
	if _rail.visible and _rail.get_global_rect().has_point(pos):
		return true
	return not _rail_open and pos.x - get_global_rect().position.x <= dp(EDGE_DP)

func _input(e: InputEvent) -> void:
	if not (e is InputEventMouse):
		if e is InputEventKey or e is InputEventJoypadButton or e is InputEventJoypadMotion:
			_kb_input = true
			if _rail_open and _rail != null and is_instance_valid(_rail):
				var f := get_viewport().gui_get_focus_owner()
				if f != null and _rail.is_ancestor_of(f):
					_rail_idle.start()
		return
	if _rail == null or not is_instance_valid(_rail) or not is_visible_in_tree():
		return
	var pos: Vector2 = e.position
	var touch := DisplayServer.is_touchscreen_available()
	if e is InputEventMouseButton or (e as InputEventMouseMotion).button_mask != 0 or not touch:
		_kb_input = false
	# Any touch on the rail while it is out: it stays another RAIL_IDLE s.
	if _rail_open and _rail.visible and _rail.get_global_rect().has_point(pos):
		if e is InputEventMouseButton or (e as InputEventMouseMotion).button_mask != 0 or not touch:
			_rail_idle.start()
	if _rail_docked or _overlay_open():
		return
	var edge_x := pos.x - get_global_rect().position.x
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and not _rail_open and edge_x <= dp(EDGE_DP):
			_edge_drag = true
			_edge_start = pos
			get_viewport().set_input_as_handled()   # not a tap on the banner / tile under it
		elif not e.pressed and _edge_drag:
			_edge_drag = false
			get_viewport().set_input_as_handled()
			if _rail.position.x > -rail_w * 0.66:
				_open_rail()
			else:
				_slide_rail(-rail_w)
	elif e is InputEventMouseMotion:
		if _edge_drag and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			get_viewport().set_input_as_handled()
			var dx := pos.x - _edge_start.x
			if _rail_tween != null and _rail_tween.is_valid():
				_rail_tween.kill()
			_rail.visible = true
			_rail_handle.visible = false
			_rail.position.x = clampf(-rail_w + dx, -rail_w, 0.0)   # the rail follows the finger
		elif e.button_mask == 0 and not _rail_open and edge_x <= dp(4) and not touch:
			_open_rail()   # a mouse pushed against the left edge (PC)

# ---------- main area ----------

func _build_main() -> void:
	_main = Control.new()
	_main.position = Vector2(_main_x(), 0)
	_main.size = Vector2(size.x - _main_x(), size.y)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	_main.add_child(v)
	var hm := MarginContainer.new()
	for side in ["left", "right"]:
		hm.add_theme_constant_override("margin_" + side, int(dp(16)))
	hm.add_theme_constant_override("margin_top", int(dp(12)))
	hm.add_theme_constant_override("margin_bottom", int(dp(6)))
	v.add_child(hm)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", int(dp(12)))
	hm.add_child(_header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", fs(24))
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", fs(15))
	_count.add_theme_color_override("font_color", Color(0.7, 0.76, 0.86))
	_count.size_flags_vertical = Control.SIZE_SHRINK_END
	_header.add_child(_count)

	_body_scroll = ScrollContainer.new()
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_body_scroll.follow_focus = true
	v.add_child(_body_scroll)
	scroller.vertical = _body_scroll
	_body_scroll.get_v_scroll_bar().value_changed.connect(_mark_lazy.unbind(1))
	var bm := MarginContainer.new()
	bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		bm.add_theme_constant_override("margin_" + side, int(dp(16)))
	bm.add_theme_constant_override("margin_bottom", int(dp(24)))
	_body_scroll.add_child(bm)
	# Not a container: the shown view sits at the top, remembered ones are parked far
	# off-screen but stay visible -- hiding / showing would re-run every drawn logo's
	# _draw (~3 ms a tile), parking costs nothing (off-screen items aren't drawn).
	_body_root = Control.new()
	_body_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bm.add_child(_body_root)

func _avail_w() -> float:
	return size.x - _main_x() - dp(32)

## Where the games start: after the rail while it is docked, at the left edge once it hides.
func _main_x() -> float:
	return rail_w if _rail_docked else 0.0

## Shows a view. `animate`: a short fade + rise (off with Reduce motion).
func _show(key: String, animate: bool = true) -> void:
	if key != current:
		_remember_scroll()
		_close_detail()
	current = key
	_select_rail(key)
	_banner_timer.stop()
	_banner = null
	# Remembered views stay in the tree, hidden: showing one again is a visibility flip
	# (taking 30 tiles out of the tree and back in cost ~70 ms on a PC).
	for c in _body_root.get_children():
		if c.has_meta("cached"):
			c.position = PARKED
		else:
			_body_root.remove_child(c)
			c.queue_free()
	_search_field = null
	_results = null
	hub._set_category_art(Categories.art_group(key.trim_prefix("cat:")) if key.begins_with("cat:") else "")
	var content: VBoxContainer = _view_cache.get(key)
	if content != null and is_instance_valid(content):
		# Built before: show it again (a category you go back to opens at once).
		_body = content
		_tiles = content.get_meta("tiles")
	else:
		content = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", int(dp(18)))
		_body = content
		_tiles = []
		content.set_meta("tiles", _tiles)
		_build_view(key)
		if key == "home" or key.begins_with("cat:") or key.begins_with("all:"):
			content.set_meta("cached", true)
			_view_cache[key] = content
	_touch_view(key)
	if content.get_parent() == null:
		_body_root.add_child(content)
		content.minimum_size_changed.connect(_fit_body.bind(content))
	content.position = Vector2.ZERO
	_fit_body(content)
	# get_meta(key, null) errors when the key is missing (null = "no default"): ask first.
	var head = content.get_meta("header") if content.has_meta("header") else null
	_header.visible = head != null
	if head != null:
		_title.text = str(head[0])
		_count.text = tr("1 game") if int(head[1]) == 1 else tr("%d games") % int(head[1])
	_banner = content.get_meta("banner") if content.has_meta("banner") else null
	if _banner != null and _banner_games.size() > 1:
		_banner_games = content.get_meta("banner_games", _banner_games)
		_banner_timer.start()
	_restore_scroll(key)
	_mark_lazy()
	if animate and not Settings.reduce_motion:
		_body_root.modulate.a = 0.0
		_body_root.position.y = dp(10)
		var tw := _body_root.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_body_root, "modulate:a", 1.0, FADE)
		tw.tween_property(_body_root, "position:y", 0.0, FADE)

func _build_view(key: String) -> void:
	if key == "home":
		_view_home()
		if _banner != null:
			_body.set_meta("banner", _banner)
			_body.set_meta("banner_games", _banner_games)
	elif key == "search":
		_view_search()
	elif key == "favs":
		var favs := _favorites()
		_set_header("★ " + tr("Favorites"), favs.size())
		_body.add_child(_grid(favs, tr("No favorites yet. Press and hold a game to add it.")))
	elif key.begins_with("cat:"):
		var id := key.trim_prefix("cat:")
		var games := Catalog.games_in(id)
		_set_header(Categories.label(id), games.size())
		_body.add_child(_grid(games, tr("No games here yet.")))
	elif key.begins_with("all:"):
		var row := key.trim_prefix("all:")
		var games := _row_games(row, 1000)
		_set_header(_row_title(row), games.size())
		_body.add_child(_back_link())
		_body.add_child(_grid(games, ""))

## The shown view: as wide as the main area, as tall as its content; the scroll follows it.
func _fit_body(content: Control) -> void:
	if content != _body or not is_instance_valid(content):
		return
	var w := _avail_w()
	var h := content.get_combined_minimum_size().y
	content.size = Vector2(w, h)
	_body_root.custom_minimum_size = Vector2(w, h)

## Back to where the player was in this view, once its content has its height.
## The view's lower tiles join a few per frame (_drain_fill_queue), so this keeps trying until
## the view is tall enough (or fully built); it gives up when the player scrolls or leaves.
func _restore_scroll(key: String) -> void:
	var at := int(_scroll_of.get(key, 0))
	var view := _body
	var scroll := _body_scroll
	for i in 120:
		await get_tree().process_frame
		if current != key or _body != view or scroll != _body_scroll or not is_instance_valid(scroll):
			return
		if i > 0 and (scroll.scroll_vertical != _set_to or _busy_input()):
			return   # the player moved it
		scroll.scroll_vertical = at
		_set_to = scroll.scroll_vertical
		if _set_to >= at or not _filling(view):
			if i >= 2:
				break
	_mark_lazy()

var _set_to := 0   # _restore_scroll: where it last put the scroll

## True while tiles of `view` are still queued.
func _filling(view: Control) -> bool:
	for job in _fill_queue:
		if job.get("view") == view and not (job.games as Array).is_empty():
			return true
	return false

func _set_header(text: String, n: int) -> void:
	_body.set_meta("header", [text, n])   # shown by _show (and again when the view is re-attached)

func _back_link() -> Control:
	var b := HubLook.ghost_button("‹ " + tr("Home"), fs(16), HubLook.pal().link)
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(_show.bind("home"))
	return b

func _remember_scroll() -> void:
	if _body_scroll != null and is_instance_valid(_body_scroll):
		_scroll_of[current] = _body_scroll.scroll_vertical

# ---------- Home ----------

func _view_home() -> void:
	var feats: Array = Catalog.featured.map(func(id): return Catalog.get_game(id)).filter(_listed)
	var cont_key := "recent" if not _row_games("recent", 1).is_empty() else "start"
	# Landscape (any device): a 16:9 banner (max 35-38% of the height) left of Continue
	# playing. Full width, a wide screen made it a long empty strip with a small logo.
	var bh := size.y * (0.35 if device == "phone" else 0.38)
	var side_by_side := landscape and not feats.is_empty() and _avail_w() - bh * 16.0 / 9.0 - dp(14) >= dp(260)
	if side_by_side:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", int(dp(14)))
		_body.add_child(hb)
		hb.add_child(_build_banner(feats, Vector2(bh * 16.0 / 9.0, bh)))
		var side := _row(cont_key, _avail_w() - bh * 16.0 / 9.0 - dp(14))
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(side)
	else:
		if not feats.is_empty():
			var bw := _avail_w()
			var full_h := minf(bw * 9.0 / 16.0, size.y * (0.38 if landscape else 0.34))
			_body.add_child(_build_banner(feats, Vector2(bw, full_h)))
		_body.add_child(_row(cont_key, _avail_w()))
	for key in ["new", "updated"]:
		if not _row_games(key, 1).is_empty():
			_body.add_child(_row(key, _avail_w()))

func _row_title(key: String) -> String:
	match key:
		"recent": return tr("Continue playing")
		"start": return tr("Start here")
		"new": return tr("New")
		"updated": return tr("Recently updated")   # TODO: "Popular this week" once Supabase counts plays
	return ""

## A Home row's games, newest first; `limit` (ROW_MAX for the row itself).
func _row_games(key: String, limit: int) -> Array:
	var all: Array = Catalog.all_games().filter(_listed)
	var out: Array = []
	match key:
		"recent":
			var rec := HubData.recent()
			var ids: Array = rec.keys()
			ids.sort_custom(func(a, b): return float(rec[a]) > float(rec[b]))
			for id in ids:
				var g := Catalog.get_game(str(id))
				if _listed(g):
					out.append(g)
		"start":
			out = Catalog.starter.map(func(id): return Catalog.get_game(id)).filter(_listed)
		"new":
			out = all.filter(func(g): return str(g.get("added", "")) != "")
			out.sort_custom(func(a, b): return str(a.added) > str(b.added) or (str(a.added) == str(b.added) and str(a.id) < str(b.id)))
		"updated":
			out = all.filter(func(g): return str(g.get("updated", "")) != "")
			out.sort_custom(func(a, b): return str(a.updated) > str(b.updated) or (str(a.updated) == str(b.updated) and str(a.id) < str(b.id)))
	return out.slice(0, limit)

func _listed(g: Dictionary) -> bool:
	return not g.is_empty() and str(g.get("id", "")) != "" and not Catalog.is_archived(str(g.id))

## Visible tiles in a row by device: phone portrait 3, tablet portrait 5, else 6-8 across the
## full width (fewer, 3+, in the narrower row beside a landscape banner).
func _row_tile_w(avail: float) -> float:
	var n := 3.0
	var full := avail >= _avail_w() - 1.0
	if device == "phone" and landscape:
		n = clampf(floor(avail / dp(120)), 6.0 if full else 3.0, 8.0)
	elif device == "tablet" and not landscape:
		n = 5.0
	elif device != "phone":
		n = clampf(floor(avail / dp(170)), 6.0 if full else 3.0, 8.0)
	var gap := dp(12)
	return (avail - gap * (n - 1.0)) / (n + 0.3)   # a third of the next tile peeks out: "there's more"

func _row(key: String, avail: float) -> Control:
	var games := _row_games(key, ROW_MAX)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(dp(8)))
	var head := HBoxContainer.new()
	box.add_child(head)
	var t := Label.new()
	t.text = _row_title(key)
	t.add_theme_font_size_override("font_size", fs(18))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if _row_games(key, ROW_MAX + 1).size() > 0:
		var all := HubLook.ghost_button(tr("See all") + " ›", fs(15), HubLook.pal().link)
		all.focus_mode = Control.FOCUS_ALL
		all.pressed.connect(_show.bind("all:" + key))
		head.add_child(all)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.follow_focus = true
	sc.add_to_group("nx_row_scroll")
	sc.get_h_scroll_bar().value_changed.connect(_mark_lazy.unbind(1))
	box.add_child(sc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(dp(12)))
	sc.add_child(hb)
	var tw := _row_tile_w(avail)
	var ts := Vector2(tw, tw * 9.0 / 16.0)
	sc.set_meta("snap_step", tw + dp(12))
	_add_tiles(hb, games, ts, int(ceil(avail / (tw + dp(12)))) + 1)
	sc.custom_minimum_size.y = ts.y + GameTile.TITLE_H + dp(6)
	return box

# ---------- featured banner ----------

func _build_banner(games: Array, box: Vector2) -> Control:
	_banner_games = games
	_banner_i = posmod(_banner_i, games.size())
	var b := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1)
	sb.set_corner_radius_all(int(dp(14)))
	b.add_theme_stylebox_override("panel", sb)
	b.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	b.custom_minimum_size = box
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.gui_input.connect(_on_banner_input)
	_banner = b
	var art := TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	# No picture: the game's drawn teaser fills the banner, or its logo sits on the right.
	var drawn := Control.new()
	drawn.name = "Drawn"
	drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawn.draw.connect(_draw_banner_art.bind(drawn))
	b.add_child(drawn)
	var emoji := Label.new()
	emoji.name = "Emoji"
	emoji.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(emoji)
	var scrim := TextureRect.new()
	scrim.texture = HubArt.scrim_bottom()
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(scrim)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.anchor_right = 1.0
	info.offset_left = dp(52) if games.size() > 1 else dp(16)   # clear of the ‹ arrow
	info.offset_right = -dp(16)
	info.offset_bottom = -dp(14)
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info.add_theme_constant_override("separation", int(dp(6)))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(info)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "★ " + tr("Featured")
	tag.add_theme_font_size_override("font_size", fs(12))
	tag.add_theme_color_override("font_color", HubLook.pal().accent)
	info.add_child(tag)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", fs(22 if box.y > dp(140) else 18))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", int(dp(4)))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(title)
	var play := HubLook.pill_button("▶  " + tr("Play"), HubLook.pal().ready.darkened(0.35), HubLook.pal().ready, fs(16))
	play.name = "Play"
	play.focus_mode = Control.FOCUS_ALL
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play.custom_minimum_size = Vector2(dp(110), dp(40))
	play.pressed.connect(_on_banner_play)
	info.add_child(play)
	if games.size() > 1:
		for side in [-1, 1]:
			var arrow := Button.new()
			arrow.icon = Categories.icon("chevron-left" if side < 0 else "chevron-right")
			arrow.add_theme_constant_override("icon_max_width", int(dp(22)))
			arrow.flat = true
			arrow.focus_mode = Control.FOCUS_ALL
			arrow.custom_minimum_size = Vector2(dp(40), dp(56))
			arrow.anchor_top = 0.5
			arrow.anchor_bottom = 0.5
			arrow.anchor_left = 0.0 if side < 0 else 1.0
			arrow.anchor_right = arrow.anchor_left
			arrow.offset_top = -dp(28)
			arrow.offset_bottom = dp(28)
			arrow.offset_left = dp(4) if side < 0 else -dp(44)
			arrow.offset_right = dp(44) if side < 0 else -dp(4)
			arrow.modulate = Color(1, 1, 1, 0.85)
			arrow.pressed.connect(_banner_step.bind(side, true))
			b.add_child(arrow)
		var dots := HBoxContainer.new()
		dots.name = "Dots"
		dots.alignment = BoxContainer.ALIGNMENT_END
		dots.anchor_left = 1.0
		dots.anchor_right = 1.0
		dots.anchor_top = 1.0
		dots.anchor_bottom = 1.0
		dots.offset_left = -dp(140)
		dots.offset_right = -dp(16)
		dots.offset_top = -dp(26)
		dots.offset_bottom = -dp(16)
		dots.add_theme_constant_override("separation", int(dp(6)))
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in games.size():
			var d := Panel.new()
			d.custom_minimum_size = Vector2(dp(8), dp(8))
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dots.add_child(d)
		b.add_child(dots)
		_banner_timer.start()
	_banner_show(false)
	return b

func _banner_show(animate: bool) -> void:
	if _banner == null or not is_instance_valid(_banner) or _banner_games.is_empty():
		return
	var g: Dictionary = _banner_games[_banner_i]
	var art := _banner.get_node("Art") as TextureRect
	var id := str(g.get("id", ""))
	var tex := HubArt.hero(g)
	if tex == null and HubArt.has_custom_tile(g):
		tex = HubArt.tile(g)
	var has_pic := tex != null
	if tex == null:
		tex = HubArt.fallback_gradient(HubArt.category_color(Categories.art_group(str(g.get("category", "")))))
	art.texture = tex
	var box: Vector2 = _banner.custom_minimum_size
	var drawn := _banner.get_node("Drawn") as Control
	var emoji := _banner.get_node("Emoji") as Label
	var mode := "" if has_pic else ("teaser" if GameArt.has_teaser(id) else ("logo" if GameArt.has_logo(id) else "emoji"))
	drawn.set_meta("id", id)
	drawn.set_meta("mode", mode)
	if mode == "teaser":
		drawn.position = Vector2.ZERO
		drawn.size = box
	else:   # the logo on the right, clear of the title on the left
		var s := box.y * 0.86
		drawn.size = Vector2(s, s)
		drawn.position = Vector2(box.x - s - dp(48), (box.y - s) / 2.0)
	drawn.visible = mode == "teaser" or mode == "logo"
	drawn.queue_redraw()
	emoji.visible = mode == "emoji"
	emoji.text = str(g.get("icon", "🎮"))
	emoji.add_theme_font_size_override("font_size", int(box.y * 0.5))
	emoji.position = drawn.position if mode != "teaser" else Vector2(box.x * 0.5, 0)
	emoji.size = Vector2(box.y * 0.86, box.y * 0.86)
	(_banner.get_node("Info/Title") as Label).text = Lang.pick(g, "title")
	var dots := _banner.get_node_or_null("Dots")
	if dots:
		for i in dots.get_child_count():
			var s := StyleBoxFlat.new()
			s.bg_color = Color(1, 1, 1, 0.95 if i == _banner_i else 0.35)
			s.set_corner_radius_all(int(dp(4)))
			(dots.get_child(i) as Panel).add_theme_stylebox_override("panel", s)
	if animate and not Settings.reduce_motion:
		art.modulate.a = 0.35
		art.create_tween().set_trans(Tween.TRANS_SINE).tween_property(art, "modulate:a", 1.0, 0.35)

func _draw_banner_art(c: Control) -> void:
	var id := str(c.get_meta("id", ""))
	match str(c.get_meta("mode", "")):
		"teaser": GameArt.draw_teaser(c, id)
		"logo": GameArt.draw_logo(c, id)

## Next / previous featured game. `by_hand`: the player moved it, so the timer restarts.
func _banner_step(dir: int, by_hand: bool = false) -> void:
	if _banner_games.size() < 2:
		return
	_banner_i = posmod(_banner_i + dir, _banner_games.size())
	_banner_show(true)
	if by_hand:
		_banner_timer.start()

var _banner_press := Vector2.ZERO
var _banner_down := false

func _on_banner_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_banner_down = true
			_banner_press = e.position
			_banner_timer.stop()
		elif _banner_down:
			_banner_down = false
			var dx: float = e.position.x - _banner_press.x
			if absf(dx) > dp(40) and absf(dx) > absf(e.position.y - _banner_press.y):
				_banner_step(-1 if dx > 0 else 1, true)   # swipe
			elif _banner_games.size() > 1:
				_banner_timer.start()

func _on_banner_play() -> void:
	if _banner_games.is_empty():
		return
	hub._on_tile_pressed(str(_banner_games[_banner_i].id))

# ---------- grids ----------

func _grid_cols(avail: float) -> int:
	if device == "phone":
		return 3 if not landscape else clampi(int(avail / dp(130)), 5, 6)
	if device == "tablet":
		return 4 if not landscape else clampi(int(avail / dp(170)), 5, 6)
	return clampi(int(avail / dp(180)), 5, 8)

func _grid(games: Array, empty_text: String) -> Control:
	if games.is_empty():
		var l := Label.new()
		l.text = empty_text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", fs(16))
		l.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
		l.custom_minimum_size = Vector2(0, dp(120))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return l
	var avail := _avail_w()
	var cols := _grid_cols(avail)
	var gap := dp(12)
	var tw := (avail - gap * (cols - 1)) / cols
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", int(gap))
	g.add_theme_constant_override("v_separation", int(dp(14)))
	# About half a screen of tiles now, the rest a few per frame (_process) while the view
	# fades in: opening a big category doesn't stall (a full screen + 1 row at once was
	# ~24 tiles = a 100 ms frame on a phone-sized window).
	var ts := Vector2(tw, tw * 9.0 / 16.0)
	var rows_now := maxi(2, int(ceil(size.y * 0.5 / (ts.y + GameTile.TITLE_H + dp(14)))))
	_add_tiles(g, games, ts, cols * rows_now)
	return g

## One remembered view of the old layout per frame (then the rest of it).
func _empty_trash() -> void:
	var t0 := Time.get_ticks_usec()
	while not _trash.is_empty() and Time.get_ticks_usec() - t0 < TRASH_BUDGET_USEC:
		var node: Node = _trash[0]
		if not is_instance_valid(node):
			_trash.pop_front()
			continue
		var tile := _first_tile(node)
		if tile != null:
			tile.free()   # hidden and disabled: safe to free here, outside any signal
			continue
		_trash.pop_front()
		node.queue_free()

func _first_tile(n: Node) -> Node:
	for c in n.get_children():
		if c is GameTile:
			return c
		var deep := _first_tile(c)
		if deep != null:
			return deep
	return null

## `key` was just used: it moves to the front; past MAX_PARKED the oldest view is freed
## (a piece per frame, like a rotation's old layout).
func _touch_view(key: String) -> void:
	if not _view_cache.has(key):
		return
	_recent_views.erase(key)
	_recent_views.push_front(key)
	while _recent_views.size() > MAX_PARKED:
		var old: String = _recent_views.pop_back()
		var v = _view_cache.get(old)
		_view_cache.erase(old)
		if v != null and is_instance_valid(v) and v != _body:
			# Already parked off-screen (not drawn): no visible = false, which notified every
			# node of the view (~10 ms for a big category) in the frame a new one opens.
			v.position = PARKED
			v.set_process_mode(Node.PROCESS_MODE_DISABLED)
			_trash.append(v)

## The player is dragging: background building waits (no stutter under the finger).
func _busy_input() -> bool:
	return scroller != null and bool(scroller.get("_tracking"))

## Builds a category's view off-screen, its tiles a few per frame (_drain_fill_queue), so
## opening it later is instant. Started once Home is up (_warm_up).
func _prebuild(key: String) -> void:
	if _view_cache.has(key) or key == current:
		return
	var keep_body := _body
	var keep_tiles := _tiles
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(dp(18)))
	_body = content
	_tiles = []
	content.set_meta("tiles", _tiles)
	_prebuilding = true
	_build_view(key)
	_prebuilding = false
	content.set_meta("cached", true)
	_view_cache[key] = content
	_recent_views.append(key)   # warmed views are the least recent
	_body_root.add_child(content)
	content.minimum_size_changed.connect(_fit_body.bind(content))
	content.position = PARKED
	content.size.x = _avail_w()
	_body = keep_body
	_tiles = keep_tiles

func _warm_up() -> void:
	_warm_queue.clear()
	# Only as many as fit in the parked views (Home + the first categories on the rail).
	var room := MAX_PARKED - _view_cache.size()
	for c in _visible_categories():
		if room <= 0:
			break
		if not _view_cache.has("cat:" + c):
			_warm_queue.append("cat:" + c)
			room -= 1

## Adds `now` tiles at once and queues the rest (they join a few per frame, in order).
func _add_tiles(box: Control, games: Array, ts: Vector2, now: int) -> void:
	if _prebuilding:
		now = 0   # background build: every tile comes from the queue
	for i in mini(now, games.size()):
		box.add_child(_tile(games[i], ts))
	if games.size() > now:
		_fill_queue.append({"box": box, "games": games.slice(now), "size": ts, "tiles": _tiles, "view": _body})

func _drain_fill_queue() -> void:
	# The view on screen first; background ones after.
	for i in _fill_queue.size():
		if _fill_queue[i].get("view") == _body and i > 0:
			_fill_queue.push_front(_fill_queue.pop_at(i))
			break
	var t0 := Time.get_ticks_usec()
	while not _fill_queue.is_empty() and Time.get_ticks_usec() - t0 < FILL_BUDGET_USEC:
		var job: Dictionary = _fill_queue[0]
		if not is_instance_valid(job.box) or (job.games as Array).is_empty():
			_fill_queue.pop_front()
			continue
		var g: Dictionary = (job.games as Array).pop_front()
		job.box.add_child(_tile(g, job.size, job.tiles))
	_mark_lazy()

func _favorites() -> Array:
	return HubData.favorites().map(func(id): return Catalog.get_game(str(id))).filter(_listed)

# ---------- tiles + the game card ----------

func _tile(g: Dictionary, art_size: Vector2, into: Variant = null) -> Control:
	var t := GameTile.new()
	t.setup(g, Categories.art_group(str(g.get("category", ""))), art_size, scroller)
	t.set_favorite(_is_fav(str(g.id)))
	# Readable names on phones / tablets (the default, 14 px x tile width / 140, got ~8 px there).
	# Never smaller than before; at most ~60% of the title strip (text size 1.4 still fits).
	t.set_title_px(maxi(int(14.0 * art_size.x / 140.0), mini(fs(12), int(GameTile.TITLE_H * 0.62))))
	t.tapped.connect(_open_detail)
	t.long_pressed.connect(_toggle_favorite)
	# Keyboard / controller: the tile itself takes focus; Enter / A opens it.
	t.focus_mode = Control.FOCUS_ALL
	t.focus_entered.connect(func(): t.set_selected(true))
	t.focus_exited.connect(func(): t.set_selected(false))
	t.gui_input.connect(func(e):
		if e.is_action_pressed("ui_accept"):
			_open_detail(t.id)
			accept_event())
	(into if into is Array else _tiles).append(t)
	return t

func _is_fav(id: String) -> bool:
	if not _fav_read:
		_fav_set.clear()
		for f in HubData.favorites():
			_fav_set[str(f)] = true
		_fav_read = true
	return _fav_set.has(id)

func _tile_path(g: Dictionary) -> String:
	var id := str(g.get("id", ""))
	if not _art_path_of.has(id):
		_art_path_of[id] = HubArt.tile_path(g)
	return _art_path_of[id]

func _mark_lazy() -> void:
	_lazy_dirty = true

func _process(_delta: float) -> void:
	if not _trash.is_empty():
		_empty_trash()
	if not _fill_queue.is_empty():
		_drain_fill_queue()
	elif not _warm_queue.is_empty() and not _busy_input():
		_prebuild(_warm_queue.pop_front())
	if _lazy_dirty:
		_lazy_dirty = false
		_load_visible_tiles()

## Pictures load only for tiles near the screen (one screen ahead), like the Game Browser.
func _load_visible_tiles() -> void:
	var view := get_global_rect().grow(maxf(size.x, size.y) * 0.5)
	var waiting := false
	for t in _tiles:
		if not is_instance_valid(t) or not t.is_visible_in_tree():
			continue
		var near: bool = view.intersects(t.get_global_rect())
		if not near:
			t.set_loaded(false)
			continue
		if t.is_loaded():
			continue
		# The picture loads on a worker thread; the tile shows it once it's there (no stall).
		var path := _tile_path(t.game)
		if path == "" or _tex_refs.has(path):
			t.set_loaded(true)
			continue
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_tex_refs[path] = ResourceLoader.load_threaded_get(path)
			t.set_loaded(true)
		elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			waiting = true
		elif st == ResourceLoader.THREAD_LOAD_FAILED:
			t.set_loaded(true)   # falls back to the gradient, as before
		else:
			ResourceLoader.load_threaded_request(path)
			waiting = true
	if waiting:
		_lazy_dirty = true   # look again next frame

func _toggle_favorite(id: String) -> void:
	var on: bool = HubData.toggle_favorite(id)
	_fav_read = false
	var all_tiles: Array = _tiles.duplicate()
	for k in _view_cache:
		if is_instance_valid(_view_cache[k]):
			all_tiles.append_array(_view_cache[k].get_meta("tiles", []))
	for t in all_tiles:
		if is_instance_valid(t) and t.id == id:
			t.set_favorite(on)
	if _detail_id == id and _detail != null and is_instance_valid(_detail):
		_detail.set_favorite(on)
	if current == "favs":
		_show("favs", false)

func _open_detail(id: String) -> void:
	var g := Catalog.get_game(id)
	if g.is_empty():
		return
	_close_detail()
	_detail_id = id
	_dim = Button.new()
	_dim.flat = true
	_dim.focus_mode = Control.FOCUS_NONE
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0, 0, 0, 0.62)
	for s in ["normal", "hover", "pressed", "focus"]:
		_dim.add_theme_stylebox_override(s, dsb)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.pressed.connect(_close_detail)
	_dim.add_to_group("modal_overlay")
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(center)
	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.01, 0.03, 0.08, 0.97)
	csb.border_color = HubLook.pal().link
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(int(dp(16)))
	csb.set_content_margin_all(dp(16))
	card.add_theme_stylebox_override("panel", csb)
	var cw := minf(dp(520), size.x - dp(32))
	card.custom_minimum_size = Vector2(cw, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(dp(10)))
	card.add_child(v)
	var hero := HubArt.hero(g)
	if hero != null and size.y > dp(420):
		var pic := TextureRect.new()
		pic.texture = hero
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2(0, minf((cw - dp(32)) * 9.0 / 16.0, size.y * 0.3))
		v.add_child(pic)
	var d := GameDetail.new()
	d.custom_minimum_size = Vector2(0, dp(150))
	v.add_child(d)
	d.play_pressed.connect(_on_detail_play)
	d.favorite_pressed.connect(_toggle_favorite)
	d.close_pressed.connect(_close_detail)
	var cat_name := Categories.label(str(g.get("category", "")))
	var parts: PackedStringArray = [cat_name]
	if bool(g.get("has_content", false)):
		parts.append(tr("Ages %d+") % int(g.get("min_age", 3)))
	d.show_game(g, " · ".join(parts), Lang.pick(g, "desc"), HubData.is_favorite(id))
	d.set_compact(size.y < dp(500), fs(26))
	_detail = d
	_dim.modulate.a = 0.0
	_dim.create_tween().tween_property(_dim, "modulate:a", 1.0, FADE)
	var play = d.get("_play")
	if play is Control:
		(play as Control).focus_mode = Control.FOCUS_ALL   # Enter / A plays straight away
		_focus_play.call_deferred(d, play)

## The card's Play takes focus next frame, unless the card was closed meanwhile (back pressed
## at once): a late grab_focus on a freed card used to leave nothing focused.
func _focus_play(d: Control, play: Control) -> void:
	if _detail == d and is_instance_valid(play) and play.is_inside_tree():
		play.grab_focus()

func _on_detail_play(id: String) -> void:
	_close_detail()
	hub._on_tile_pressed(id)   # the hub's own flow: age, app update, store, download, launch

func _close_detail() -> void:
	if _dim != null and is_instance_valid(_dim):
		_dim.queue_free()
	_dim = null
	_detail = null
	_detail_id = ""

# ---------- search ----------

func _view_search() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(dp(12)))
	_body.add_child(box)
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "🔍  " + tr("Search %d games") % Catalog.all_games().filter(_listed).size()
	_search_field.text = _search_text
	_search_field.clear_button_enabled = true
	_search_field.add_theme_font_size_override("font_size", fs(18))
	_search_field.custom_minimum_size = Vector2(0, dp(48))
	for st in ["normal", "focus", "read_only"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.04, 0.06, 0.12, 0.92)
		s.border_color = HubLook.pal().link if st == "focus" else Color(1, 1, 1, 0.22)
		s.set_border_width_all(maxi(1, int(dp(1.5))))
		s.set_corner_radius_all(int(dp(24)))
		s.content_margin_left = dp(18)
		s.content_margin_right = dp(12)
		_search_field.add_theme_stylebox_override(st, s)
	_search_field.text_changed.connect(_on_search_text)
	box.add_child(_search_field)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", int(dp(8)))
	chips.add_theme_constant_override("v_separation", int(dp(8)))
	box.add_child(chips)
	for spec in [["multiplayer", tr("Multiplayer")], ["quick", tr("Quick play")], ["offline", tr("Offline")]]:
		var c := Button.new()
		c.toggle_mode = true
		c.focus_mode = Control.FOCUS_ALL
		c.text = spec[1]
		c.button_pressed = _chips.has(spec[0])
		c.add_theme_font_size_override("font_size", fs(15))
		c.custom_minimum_size = Vector2(0, dp(38))
		_style_chip(c)
		c.toggled.connect(_on_chip.bind(spec[0]))
		chips.add_child(c)
	_results = VBoxContainer.new()
	box.add_child(_results)
	_fill_results()
	if not OS.has_feature("mobile"):
		_search_field.grab_focus.call_deferred()   # PC: type straight away (phones: no surprise keyboard)

func _style_chip(c: Button) -> void:
	var accent: Color = HubLook.pal().link
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var s := StyleBoxFlat.new()
		var on: bool = st == "pressed" or st == "hover_pressed"
		s.bg_color = Color(accent.r, accent.g, accent.b, 0.3) if on else Color(1, 1, 1, 0.06)
		s.border_color = accent if on else Color(1, 1, 1, 0.25)
		s.set_border_width_all(maxi(1, int(dp(1.5))))
		if st == "focus":
			s.border_color = Color.WHITE
		s.set_corner_radius_all(int(dp(19)))
		s.content_margin_left = dp(14)
		s.content_margin_right = dp(14)
		c.add_theme_stylebox_override(st, s)

func _on_search_text(t: String) -> void:
	_search_text = t
	_fill_results()

func _on_chip(on: bool, key: String) -> void:
	if on:
		_chips[key] = true
	else:
		_chips.erase(key)
	_fill_results()

func _fill_results() -> void:
	if _results == null:
		return
	for c in _results.get_children():
		_results.remove_child(c)
		c.queue_free()
	_tiles = _tiles.filter(func(t): return is_instance_valid(t) and t.is_inside_tree())
	var found := search(_search_text, _chips)
	if _search_text.strip_edges() == "" and _chips.is_empty():
		found = []
	var head := Label.new()
	head.add_theme_font_size_override("font_size", fs(15))
	head.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	head.text = "" if (_search_text.strip_edges() == "" and _chips.is_empty()) else (tr("1 game") if found.size() == 1 else tr("%d games") % found.size())
	_results.add_child(head)
	if _search_text.strip_edges() != "" or not _chips.is_empty():
		_results.add_child(_grid(found, tr("No games match.")))
	_mark_lazy()

## Matches every word of `text` against the name (EN + ES), tags (EN + ES) and category;
## chips narrow it further. Archived games never show (Catalog drops them).
static func search(text: String, chips: Dictionary) -> Array:
	var words := text.strip_edges().to_lower().split(" ", false)
	var out: Array = []
	for g in Catalog.all_games():
		var tags: Array = g.get("tags", [])
		if chips.has("multiplayer") and not tags.has("multiplayer"):
			continue
		if chips.has("quick") and not (tags.has("quick") or bool(g.get("quick", false))):
			continue
		if chips.has("offline") and (not tags.has("offline") or Catalog.needs_download(str(g.id))):
			continue   # Offline = can be played right now with no connection (downloaded)
		var hay := " ".join(PackedStringArray([str(g.get("title", "")), str(g.get("title_es", "")),
			Categories.label(str(g.get("category", ""))), str(Categories.info(str(g.get("category", ""))).get("es", ""))]))
		for t in tags:
			hay += " " + str(t) + " " + str(TAG_ES.get(t, ""))
		hay = hay.to_lower()
		var ok := true
		for w in words:
			if not hay.contains(w):
				ok = false
				break
		if ok:
			out.append(g)
	return out

# ---------- back / input ----------

## Android back / Esc / B: close the card, leave search or a grid for Home, then Home -> rail.
## true = handled (the hub doesn't quit).
func handle_back() -> bool:
	if _dim != null and is_instance_valid(_dim):
		_close_detail()
		return true
	if current != "home":
		_show("home")
		return true
	return false

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if handle_back():
			get_viewport().set_input_as_handled()
		elif _rail_items.has("home"):
			_open_rail()
			(_rail_items["home"] as Control).grab_focus()
			get_viewport().set_input_as_handled()
		return
	# First arrow / d-pad press on a screen with nothing focused: start on the rail.
	# Any input mapped to an arrow action (keys, d-pad, stick, remapped); a mouse never is.
	if not (e is InputEventMouse) and get_viewport().gui_get_focus_owner() == null \
			and (e.is_action_pressed("ui_down") or e.is_action_pressed("ui_up") or e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right")):
		var key := current if _rail_items.has(current) else "home"
		_open_rail()
		(_rail_items[key] as Control).grab_focus()
		get_viewport().set_input_as_handled()

# ---------- refresh (hub calls these) ----------

## The catalog or the store changed: rebuild what shows games, same place.
func rebuild() -> void:
	_build()

func refresh_home() -> void:
	# Only when what Home / Favorites show changed (closing Options must not cost a rebuild).
	var key := var_to_str([HubData.recent(), HubData.favorites()])
	if key == _home_key:
		return
	_home_key = key
	_fav_read = false   # favorites may have come from another device (account sync)
	if _view_cache.has("home") and is_instance_valid(_view_cache["home"]):
		_view_cache["home"].queue_free()
	_view_cache.erase("home")   # Continue playing changed: build Home again
	if current == "home" or current == "favs":
		_show(current, false)

func update_account() -> void:
	if _profile_btn == null or not is_instance_valid(_profile_btn):
		return
	var name := _profile_name() + str(Auth.is_logged_in())
	if name == _account_key:
		return   # same player: nothing to redraw
	_account_key = name
	_build()   # the name and avatar are part of the rail's width on tablets / PC
