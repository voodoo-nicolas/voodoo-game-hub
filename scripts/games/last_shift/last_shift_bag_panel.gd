extends Control

## The bag screen (inventory). Opens from the bag button next to pause (or the I key); the game
## is paused while it is up. Shows:
##   - the 6 bag slots (tap one to select it; Use heals with a first-aid kit / snack, Drop puts the
##     stack on the floor at Nash's feet),
##   - the weapons Nash owns (tap one to equip it),
##   - the key ring and the wallet (they take no slot),
##   - v0.5: the hats he found (party hat, the cook's hat: tap one to wear it), bullets and coolant cans.
## The world owns the data; this only draws it and reports taps through signals.
## Taps are mouse-button events (phones send them for touches too), never ScreenTouch.

const Icons = preload("res://scripts/games/last_shift/last_shift_icons.gd")
const LsText = preload("res://scripts/games/last_shift/last_shift_text.gd")
const LsUi = preload("res://scripts/games/last_shift/last_shift_ui.gd")
const A = preload("res://scripts/games/last_shift/last_shift_art.gd")

signal use_slot(index: int)
signal drop_slot(index: int)
signal equip(weapon: String)
## A hat was tapped (wear / take off): "party" or "chef".
signal toggle_hat(hat: String)
signal closed

const SLOT := 104.0
const GAP := 12.0
const COLS := 3

var inv: RefCounted = null      # last_shift_inventory.gd
var keys: Array = []            # "keycard", "maint_key", "sec_key" that Nash has
var selected := -1
var _btn_use: Button
var _btn_drop: Button
var _btn_close: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # works while the game is paused
	mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_use = _button()
	_btn_use.pressed.connect(func(): use_slot.emit(selected))
	_btn_drop = _button()
	_btn_drop.pressed.connect(func(): drop_slot.emit(selected))
	_btn_close = _button()
	_btn_close.pressed.connect(func(): closed.emit())
	visible = false

func _button() -> Button:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(170, 56)
	LsUi.style_button(b)
	add_child(b)
	return b

## Shows the panel for this inventory and key list.
func open(inventory: RefCounted, key_list: Array) -> void:
	inv = inventory
	keys = key_list
	if selected >= 0 and inv.slots[selected].is_empty():
		selected = -1
	visible = true
	_layout()
	queue_redraw()

func refresh(key_list: Array) -> void:
	keys = key_list
	if selected >= 0 and inv.slots[selected].is_empty():
		selected = -1
	_layout()
	queue_redraw()

func _grid_origin() -> Vector2:
	return Vector2(36, 92)

func _slot_rect(i: int) -> Rect2:
	var col := i % COLS
	var row := i / COLS
	return Rect2(_grid_origin() + Vector2(col * (SLOT + GAP), row * (SLOT + GAP)), Vector2(SLOT, SLOT))

func _weapon_rect(i: int) -> Rect2:
	var x0 := _grid_origin().x + COLS * (SLOT + GAP) + 28.0
	return Rect2(Vector2(x0 + i * 76.0, 120), Vector2(68, 68))

## The gear slots (hats), right of the key ring. v0.4.1 had one, right of the weapons; v0.5 has six
## weapons, so the hats moved down a row.
func _hat_rect(i: int) -> Rect2:
	var x0 := _grid_origin().x + COLS * (SLOT + GAP) + 28.0
	return Rect2(Vector2(x0 + 330.0 + i * 68.0, 236), Vector2(60, 60))

func _layout() -> void:
	var details_x := _grid_origin().x + COLS * (SLOT + GAP) + 28.0
	_btn_use.text = tr(LsText.UI.bag_use)
	_btn_drop.text = tr(LsText.UI.bag_drop)
	_btn_close.text = tr(LsText.UI.bag_close)
	var item: Dictionary = {} if selected < 0 or inv == null else inv.slots[selected]
	_btn_use.visible = not item.is_empty() and item.kind in ["medkit", "snack"]
	_btn_drop.visible = not item.is_empty()
	_btn_use.position = Vector2(details_x, size.y - 90)
	_btn_drop.position = Vector2(details_x + 186, size.y - 90)
	_btn_close.position = Vector2(size.x - 196, 22)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	for i in inv.slots.size():
		if _slot_rect(i).has_point(p):
			selected = i if not inv.slots[i].is_empty() else -1
			_layout()
			queue_redraw()
			accept_event()
			return
	for i in inv.weapons.size():
		if _weapon_rect(i).has_point(p):
			equip.emit(inv.weapons[i])
			queue_redraw()
			accept_event()
			return
	for i in inv.hats.size():
		if _hat_rect(i).has_point(p):
			toggle_hat.emit(inv.hats[i])
			queue_redraw()
			accept_event()
			return

func _text(pos: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw() -> void:
	if inv == null:
		return
	draw_style_box(LsUi.panel_style(), Rect2(Vector2.ZERO, size))
	_text(Vector2(36, 58), tr(LsText.UI.bag_title).to_upper() + "   %d/%d" % [inv.used_slots(), inv.SLOTS], 30, Color("ffd479"))
	# slots
	for i in inv.slots.size():
		var r := _slot_rect(i)
		var s: Dictionary = inv.slots[i]
		draw_rect(r, Color(1, 1, 1, 0.07))
		draw_rect(r, A.AMBER if i == selected else Color(1, 1, 1, 0.3), false, 4.0 if i == selected else 2.0)
		if not s.is_empty():
			Icons.draw(self, s.kind, r.get_center() + Vector2(0, -8), 60.0)
			var n := "x%d" % int(s.n)
			var w := ThemeDB.fallback_font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			_text(r.end - Vector2(w + 8, 8), n, 22, Color.WHITE)
	# weapons (tap to equip)
	var dx := _grid_origin().x + COLS * (SLOT + GAP) + 28.0
	_text(Vector2(dx, 108), tr(LsText.UI.bag_weapons), 20, Color(1, 1, 1, 0.7))
	for i in inv.weapons.size():
		var r := _weapon_rect(i)
		var wid: String = inv.weapons[i]
		draw_rect(r, Color(1, 1, 1, 0.07))
		draw_rect(r, A.AMBER if wid == inv.equipped else Color(1, 1, 1, 0.3), false, 3.0 if wid == inv.equipped else 2.0)
		Icons.draw(self, wid, r.get_center(), 50.0)
	if not inv.hats.is_empty():
		_text(Vector2(dx + 330, 226), tr(LsText.UI.bag_gear), 20, Color(1, 1, 1, 0.7))
	for i in inv.hats.size():
		var hr := _hat_rect(i)
		var worn: bool = inv.hat_worn == inv.hats[i]
		draw_rect(hr, Color(1, 1, 1, 0.07))
		draw_rect(hr, A.AMBER if worn else Color(1, 1, 1, 0.3), false, 3.0 if worn else 2.0)
		Icons.draw(self, "party_hat" if inv.hats[i] == "party" else "chef_hat", hr.get_center(), 46.0)
	# keys and money
	_text(Vector2(dx, 226), tr(LsText.UI.bag_keys), 20, Color(1, 1, 1, 0.7))
	for i in keys.size():
		Icons.draw(self, keys[i], Vector2(dx + 30 + i * 60, 262), 44.0)
	# wallet and bullets (v0.4: bullets never take a bag slot)
	Icons.draw(self, "money", Vector2(dx + 30, 306), 44.0)
	_text(Vector2(dx + 58, 316), "$%d" % inv.money, 24, Color("9fe08a"))
	Icons.draw(self, "bullets", Vector2(dx + 150, 306), 44.0)
	_text(Vector2(dx + 176, 316), "x%d" % inv.bullets, 24, Color.WHITE)
	if inv.has_weapon("coolant"):
		Icons.draw(self, "coolant", Vector2(dx + 260, 306), 40.0)
		_text(Vector2(dx + 284, 316), "x%d" % inv.cans, 24, Color.WHITE)
	# the selected item: name + what it does
	if selected >= 0 and not inv.slots[selected].is_empty():
		var k: String = inv.slots[selected].kind
		var info: Dictionary = LsText.ITEMS.get(k, {"name": k, "desc": ""})
		_text(Vector2(dx, 360), tr(info.name), 24, Color.WHITE)
		var desc := tr(info.desc)
		draw_multiline_string(ThemeDB.fallback_font, Vector2(dx, 388), desc, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - dx - 30, 18, -1, Color(1, 1, 1, 0.75))
	else:
		_text(Vector2(dx, 360), tr(LsText.UI.bag_hint), 18, Color(1, 1, 1, 0.55))
