extends HBoxContainer

## The category bar of the new Game Browser: text tabs (★ Favoritos, 🔍, Continue
## playing, then every category from the manifest) in a sideways-scrolling strip, and
## the Filtros button pinned at the end. The open tab is bright with an underline;
## the others are dimmed. Dragging uses the browser's TouchScroll (group
## "nx_row_scroll"); a tap that ended a drag is ignored.

const HubLook = preload("res://scripts/hub/hub_look.gd")

signal tab_selected(key: String)
signal search_pressed
signal filters_pressed

var scroll: ScrollContainer
var filters_button: Button
var scroller: Node
var _row: HBoxContainer
var _buttons: Dictionary = {}
var _active := ""
var _search_on := false

func build(scroller_node: Node) -> void:
	scroller = scroller_node
	add_theme_constant_override("separation", 8)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_to_group("nx_row_scroll")
	add_child(scroll)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", HubLook.SIDE)
	pad.add_theme_constant_override("margin_right", 24)
	scroll.add_child(pad)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	pad.add_child(_row)

	filters_button = make_filters_button()
	filters_button.pressed.connect(filters_pressed.emit)
	var edge := MarginContainer.new()
	edge.add_theme_constant_override("margin_right", HubLook.SIDE)
	edge.add_child(filters_button)
	add_child(edge)

## The Filtros toggle (also used in the grid look's top bar).
static func make_filters_button() -> Button:
	var filters_button := Button.new()
	filters_button.toggle_mode = true
	filters_button.focus_mode = Control.FOCUS_NONE
	filters_button.custom_minimum_size = Vector2(0, 56)
	HubLook.text(filters_button, 24)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(0, 0, 0, 0.3)
	off.border_color = Color(1, 1, 1, 0.4)
	off.set_border_width_all(1)
	off.set_corner_radius_all(12)
	off.content_margin_left = 16
	off.content_margin_right = 16
	var on: StyleBoxFlat = off.duplicate()
	on.bg_color = Color(HubLook.pal().link, 0.45)
	on.border_color = HubLook.pal().link
	for s in ["normal", "hover", "focus"]:
		filters_button.add_theme_stylebox_override(s, off)
	for s in ["pressed", "hover_pressed"]:
		filters_button.add_theme_stylebox_override(s, on)
	return filters_button

## items: [{key, title}]. The key "_search" is the 🔍 tab (opens the search field).
func set_tabs(items: Array, active: String) -> void:
	for b in _row.get_children():
		_row.remove_child(b)
		b.queue_free()
	_buttons.clear()
	for it in items:
		var b := Button.new()
		b.text = str(it.title)
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(_on_pressed.bind(str(it.key)))
		_row.add_child(b)
		_buttons[str(it.key)] = b
	set_active(active)

func set_active(key: String) -> void:
	_active = key
	_style()
	if is_inside_tree():
		_reveal.call_deferred(key)

## Scrolls the bar so the open tab is in view (looked up late: tabs get rebuilt).
func _reveal(key: String) -> void:
	var b: Control = _buttons.get(key)
	if key in ["results", "favs", "_search", "recent"]:
		scroll.scroll_horizontal = 0   # the first tabs: start of the bar
		return
	if b != null and is_instance_valid(b) and scroll.is_ancestor_of(b):
		if b.position.x + b.size.x + HubLook.SIDE + 24 <= scroll.size.x:
			scroll.scroll_horizontal = 0   # fits: keep ★ Favoritos at the start
		else:
			scroll.ensure_control_visible(b)

func set_search_open(on: bool) -> void:
	_search_on = on
	_style()

func set_title(key: String, title: String) -> void:
	if _buttons.has(key):
		_buttons[key].text = title

func has_tab(key: String) -> bool:
	return _buttons.has(key)

func _style() -> void:
	var p := HubLook.pal()
	for key in _buttons:
		var b: Button = _buttons[key]
		var open: bool = (key == _active) or (key == "_search" and _search_on)
		HubLook.text(b, 26, p.header_open_text if open else Color(1, 1, 1, 0.55))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(p.link, 1.0) if open else Color(0, 0, 0, 0)
		sb.border_width_bottom = 4
		sb.shadow_color = Color(p.link, 0.5 if open else 0.0)
		sb.shadow_size = 8 if open else 0
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, sb)

func _on_pressed(key: String) -> void:
	if scroller != null and bool(scroller.get("moved")):
		return
	if key == "_search":
		search_pressed.emit()
	else:
		tab_selected.emit(key)
