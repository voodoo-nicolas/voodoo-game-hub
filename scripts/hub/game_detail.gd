extends VBoxContainer

## The text block of a selected game: large title, 2-3 line description, mode badges,
## with a ☆/★ favourite toggle beside the title, and the buttons ✕ Back and ▶ Play. The picture behind it is the
## browser's background; this only holds text, over the left-hand gradient.

const HubLook = preload("res://scripts/hub/hub_look.gd")

const MODE_ICONS := {"cpu": "🤖", "local": "👥", "online": "🌐", "party": "🎉"}
const MODE_WORDS := {"cpu": "vs. computer", "local": "same phone", "online": "online", "party": "group"}

signal play_pressed(id: String)
signal favorite_pressed(id: String)
signal close_pressed

var game: Dictionary = {}
var _title: Label
var _meta: Label
var _desc: Label
var _badges: HFlowContainer
var _play: Button
var _fav: Button
var _close: Button
var _buttons: HFlowContainer
var _title_size := 56

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Title with the ★ favourite toggle beside it.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_row)
	_title = HubLook.label("", 56)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.max_lines_visible = 2
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF   # one line; _fit_title() shrinks long names
	title_row.add_child(_title)
	_fav = HubLook.ghost_button("☆", 56, Settings.DARK.update)
	_fav.custom_minimum_size = Vector2(72, 72)
	_fav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fav.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_fav.pressed.connect(_on_fav)
	title_row.add_child(_fav)
	_meta = HubLook.label("", 24, Settings.DARK.count)
	_meta.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_meta)
	_desc = HubLook.label("", 26, Color(1, 1, 1, 0.9))
	_desc.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.max_lines_visible = 3
	_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_desc)
	_badges = HFlowContainer.new()
	_badges.add_theme_constant_override("h_separation", 8)
	_badges.add_theme_constant_override("v_separation", 6)
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badges)
	_buttons = HFlowContainer.new()
	_buttons.add_theme_constant_override("h_separation", 12)
	_buttons.add_theme_constant_override("v_separation", 8)
	add_child(_buttons)
	_close = HubLook.pill_button(tr("✕ Back"), Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.5), 26)
	_close.custom_minimum_size.y = 64
	_close.pressed.connect(close_pressed.emit)
	_buttons.add_child(_close)
	_play = HubLook.pill_button(tr("▶ Play"), Color(Settings.DARK.ready, 0.9).darkened(0.45), Settings.DARK.ready, 30)
	_play.custom_minimum_size = Vector2(190, 64)
	_play.pressed.connect(_on_play)
	_buttons.add_child(_play)

## `meta`: category · age line. `desc`: already localised.
func show_game(g: Dictionary, meta: String, desc: String, favorite: bool) -> void:
	game = g
	_title.text = ("🔒 " if g.get("locked", false) == true else "") + Lang.pick(g, "title")
	_fit_title()
	_meta.text = meta
	_desc.text = desc
	_desc.visible = desc != ""
	for c in _badges.get_children():
		_badges.remove_child(c)
		c.queue_free()
	for m in str(g.get("modes", "")).split(",", false):
		var mode := m.strip_edges()
		if MODE_ICONS.has(mode):
			_badges.add_child(_badge("%s %s" % [MODE_ICONS[mode], tr(MODE_WORDS[mode])]))
	set_favorite(favorite)

func set_favorite(on: bool) -> void:
	_fav.text = "★" if on else "☆"

## Short screens (landscape at large text) trim the detail so the buttons stay in view.
func set_compact(on: bool, title_size: int) -> void:
	_title_size = title_size
	_fit_title()
	_desc.max_lines_visible = 2 if on else 3
	_badges.visible = not on

## The title is one line next to the ★; a long name gets a smaller font until it fits.
func _fit_title() -> void:
	if _title == null:
		return
	var room := maxf(120.0, size.x - 96.0)
	var font := _title.get_theme_font("font")
	var px := _title_size
	while px > 30 and font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
		px -= 4
	_title.add_theme_font_size_override("font_size", px)

func _badge(text: String) -> Control:
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = Color(1, 1, 1, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := HubLook.label(text, 20)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pill.add_child(l)
	return pill

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_title()

func _on_play() -> void:
	if not game.is_empty():
		play_pressed.emit(str(game.id))

func _on_fav() -> void:
	if not game.is_empty():
		favorite_pressed.emit(str(game.id))
