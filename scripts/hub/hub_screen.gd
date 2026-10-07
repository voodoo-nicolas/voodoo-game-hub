extends Control

## Base for the hub's own full screens (🏆 Leaderboards, 🏅 Achievements,
## 👥 Friends, 🎮 Multiplayer -- since v0.25): the Options screen's look
## (mist, "← Hub" bar, titled cards, pill buttons, palette colours), so each
## screen only fills `list` in `_build()`.
##
## Opening a game from one of them goes through the hub
## (`open_game` / `Social.launch_online`), so downloading, updating and
## "needs a newer app" work exactly as for a tile.

const Orientation = preload("res://scripts/common/orientation.gd")
const DragScroll = preload("res://scripts/common/drag_scroll.gd")
const Mist = preload("res://scripts/common/mist.gd")
const Brand = preload("res://scripts/common/brand.gd")
const GameIcons = preload("res://scripts/common/game_icons.gd")
const HUB_SCENE := "res://scenes/hub/hub.tscn"

var pal: Dictionary
var drag: Node
var list: VBoxContainer
var _overlay: Control

func _ready() -> void:
	Orientation.lock_portrait()
	pal = Settings.palette()
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
	var hub_btn := pill(tr("← Hub"), false)
	hub_btn.custom_minimum_size.x = 130
	hub_btn.pressed.connect(go_hub)
	top_bar.add_child(hub_btn)
	var title := Label.new()
	title.text = _title()
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", pal.accent)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	top_bar.add_child(title)
	# a smaller balance than the Hub button: long titles ("Clasificaciones") need the room
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(40, 0)
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
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	margin.add_child(list)
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _overlay and is_instance_valid(_overlay):
			close_dialog()
		else:
			go_hub()

## Overridden: the screen's name and content.
func _title() -> String:
	return ""

func _build() -> void:
	pass

## Empties `list` and builds it again (after data arrives).
func rebuild() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	_build()

func go_hub() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)

## Opens a game the way its hub tile would (download / update first).
func open_game(id: String) -> void:
	Social.launch_request = id
	go_hub()

func tapped() -> bool:
	return not drag.moved

# ---------- building blocks ----------

## A titled card; returns the VBox to put rows in.
func section(title_text: String, parent: Control = null) -> VBoxContainer:
	var into: Control = parent if parent else list
	if title_text != "":
		var heading := Label.new()
		heading.text = title_text.to_upper()
		heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		heading.add_theme_font_size_override("font_size", 22)
		heading.add_theme_color_override("font_color", pal.link)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		into.add_child(heading)
	var card := PanelContainer.new()
	var sb := card_style(pal.card_fill, pal.link_dim)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	into.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	return box

func label(text: String, size: int = 24, color: Variant = null, wrap: bool = true, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color if color != null else pal.text)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func dim(text: String, size: int = 21) -> Label:
	return label(text, size, pal.text_dim)

## A game's icon: the drawn neon one when there is one, else its emoji.
func game_icon(game: Dictionary, size: float = 56.0) -> Control:
	var id := str(game.get("id", ""))
	if GameIcons.has(id):
		var art := Control.new()
		art.custom_minimum_size = Vector2(size, size)
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.draw.connect(GameIcons.draw.bind(art, id))
		return art
	var l := label(str(game.get("icon", "🎮")), int(size * 0.62), null, false)
	l.custom_minimum_size = Vector2(size, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## Icon + title (+ a dim line under it), expanding; the caller adds buttons after.
func game_row(game: Dictionary, sub: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(game_icon(game))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(label(Lang.pick(game, "title"), 27))
	if sub != "":
		col.add_child(dim(sub, 19))
	row.add_child(col)
	return row

func pill(text: String, lit: bool, size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	style_pill(b, lit)
	return b

func style_pill(b: Button, lit: bool, color: Variant = null) -> void:
	var border: Color = color if color != null else (pal.accent if lit else pal.off_border)
	var fill: Color = pal.accent_fill if lit else pal.off_fill
	if color != null and lit:
		fill = Color(Color(color).lerp(Color(0.0, 0.02, 0.06), 0.7), 0.93) if not Settings.is_light() else Color(color).lerp(Color.WHITE, 0.82)
	var sb := card_style(fill, border)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, sb)
	var fc: Color = pal.text_dim
	if lit:
		fc = pal.text if Settings.is_light() else Color(1, 1, 1)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(key, fc)

## Tabs in one row, the chosen one lit; on_pick(i).
func tabs(names: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in names.size():
		var b := pill(str(names[i]), i == selected, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(_on_tab.bind(on_pick, i))
		row.add_child(b)
	return row

func _on_tab(on_pick: Callable, i: int) -> void:
	if tapped():
		on_pick.call(i)

func card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.shadow_color = Color(border, 0.35 * pal.glow)
	sb.shadow_size = 6
	return sb

# ---------- dialogs ----------

## A card over the screen; returns its VBox. Tapping outside closes it.
func dialog(title_text: String) -> VBoxContainer:
	close_dialog()
	_overlay = ColorRect.new()
	_overlay.color = pal.overlay
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_to_group("modal_overlay")
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := card_style(pal.card_fill, pal.accent)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vp: Vector2 = get_viewport_rect().size
	var w: float = minf(vp.x - 80.0, 580.0)
	scroll.custom_minimum_size = Vector2(w, 0)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(w - 12.0, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	if title_text != "":
		box.add_child(label(title_text, 32, pal.accent, true, true))
	# grow with the content up to most of the screen, then scroll
	box.resized.connect(_fit_dialog.bind(scroll, box))
	return box

func _fit_dialog(scroll: ScrollContainer, box: VBoxContainer) -> void:
	var max_h: float = get_viewport_rect().size.y * 0.78
	scroll.custom_minimum_size.y = minf(box.size.y, max_h)

func close_dialog() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null

func _on_overlay_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		close_dialog()

## OK-only message.
func message(title_text: String, text: String) -> void:
	var box := dialog(title_text)
	box.add_child(label(text, 24, pal.card_message, true, true))
	var ok := pill(tr("OK"), true, 26)
	ok.pressed.connect(close_dialog)
	box.add_child(ok)

## Games that can be played `mode` ("online", "local", "cpu"), from the
## manifest's "modes", in catalog order.
func games_with_mode(mode: String) -> Array:
	var out: Array = []
	for cat in Catalog.categories:
		for g in cat.get("games", []):
			if g.has("id") and mode in str(g.get("modes", "")).split(","):
				out.append(g)
	return out

## Picks an online game to invite `friend` into, then opens it hosting.
func pick_game_for(friend: Dictionary) -> void:
	var box := dialog(tr("Invite %s to...") % str(friend.get("display_name", "Player")))
	for g in games_with_mode("online"):
		var b := pill("", false, 26)
		b.text = "%s  %s" % [str(g.get("icon", "🎮")), Lang.pick(g, "title")]
		b.custom_minimum_size.y = 68
		b.pressed.connect(_invite_into.bind(str(g.id), friend))
		box.add_child(b)
	var cancel := pill(tr("Cancel"), false)
	cancel.pressed.connect(close_dialog)
	box.add_child(cancel)

func _invite_into(game_id: String, friend: Dictionary) -> void:
	close_dialog()
	Social.launch_online(game_id, "host", "", str(friend.user_id), str(friend.get("display_name", "")))
