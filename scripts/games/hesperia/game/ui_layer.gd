extends Control
const Cond = preload("res://scripts/games/hesperia/core/cond.gd")
const Tokens = preload("res://scripts/games/hesperia/core/tokens.gd")
const Art = preload("res://scripts/games/hesperia/game/art.gd")
const Prefs = preload("res://scripts/games/hesperia/game/prefs.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
const WorldState = preload("res://scripts/games/hesperia/world_state.gd")
## Modal UI: dialogue (JSON, branching, conditions, tokens), shop, pause menu (items/quests/options), title + new-game.
## Emits requests; main.gd owns game flow. Runs while the tree is paused.

signal new_game_requested(hero_name, male)
signal continue_requested
signal resume_requested
signal quit_to_title_requested
signal save_requested
signal dialogue_closed
signal language_changed

var panel: PanelContainer
var vbox: VBoxContainer
var mode: String = ""          # "", dialogue, shop, menu, title, text
var npc_id: String = ""
var node_id: String = ""
var dlg: Dictionary = {}
var shop_after_close: bool = false
var typing_t: float = 0.0
var text_label: Label
var choices_box: VBoxContainer
var tab: String = "items"
var male_pick: bool = true
var hair_pick: String = "brown"
const HAIRS := {"brown": Color(0.45, 0.26, 0.1), "black": Color(0.12, 0.11, 0.16), "blonde": Color(0.85, 0.7, 0.32),
	"orange": Color(0.85, 0.35, 0.09), "white": Color(0.88, 0.87, 0.86)}
var name_edit: LineEdit
var tap: bool = false

func _input(ev: InputEvent) -> void:
	if (mode == "dialogue" or mode == "text") and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		tap = true

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true

func is_open() -> bool:
	return mode != ""

func _clear() -> void:
	for c in get_children():
		c.queue_free()
	panel = null
	text_label = null
	choices_box = null

func _mk_panel(rect: Rect2) -> VBoxContainer:
	_clear()
	panel = PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.12, 0.93)
	sb.border_color = Color(0.85, 0.7, 0.35)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	return vbox

func _btn(text: String, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", Prefs.fs(9))
	b.pressed.connect(cb)
	(parent if parent != null else vbox).add_child(b)
	return b

func _lbl(text: String, size: int = 9, col: Color = Color.WHITE, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Prefs.fs(size))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 220
	vbox.add_child(l)
	return l

func close() -> void:
	_clear()
	var was := mode
	mode = ""
	get_tree().paused = false
	if was == "dialogue" or was == "text":
		emit_signal("dialogue_closed")
	if shop_after_close:
		shop_after_close = false
		open_shop()

# ------------------------------------------------------------------------------------------ dialogue
func start_dialogue(id: String) -> void:
	if not Data.dialogue.has(id):
		return
	npc_id = id
	dlg = Data.dialogue[id]
	var start := ""
	for e in dlg["entries"]:
		if Cond.eval(e.get("if", ""), WorldState):
			start = e["node"]
			break
	if start == "":
		return
	get_tree().paused = true
	mode = "dialogue"
	_show_node(start)

func show_text(t, speaker: String = "") -> void:
	## One-off line (signs, chest messages).
	get_tree().paused = true
	mode = "text"
	_mk_panel(Rect2(24, 128, 336, 62))
	if speaker != "":
		_lbl(speaker, 8, Color(1, 0.85, 0.4), false)
	text_label = _lbl(Tokens.resolve(Data.loc(t), WorldState.hero_name, WorldState.male), 9)
	text_label.visible_characters = 0
	typing_t = 0.0

func _show_node(id: String) -> void:
	node_id = id
	var n: Dictionary = dlg["nodes"][id]
	_mk_panel(Rect2(24, 118, 336, 78))
	var who: String = n.get("speaker", "")
	if who != "":
		_lbl(Data.name_of(who) if who != "hero" else WorldState.hero_name, 8, Color(1, 0.85, 0.4), false)
	text_label = _lbl(Tokens.resolve(Data.loc(n["text"]), WorldState.hero_name, WorldState.male), 9)
	text_label.visible_characters = 0
	typing_t = 0.0
	choices_box = VBoxContainer.new()
	vbox.add_child(choices_box)
	var shown := 0
	if n.has("choices"):
		for c in n["choices"]:
			if not Cond.eval(c.get("if", ""), WorldState):
				continue
			var b := _btn(Tokens.resolve(Data.loc(c["text"]), WorldState.hero_name, WorldState.male), _choose.bind(c), choices_box)
			b.visible = false
			shown += 1
	if n.has("do"):
		_run_actions(n["do"])

func _choose(c: Dictionary) -> void:
	if c.has("do"):
		_run_actions(c["do"])
	if mode == "shop":
		return
	if c.has("goto"):
		_show_node(c["goto"])
	else:
		close()

func _advance() -> void:
	if mode == "text":
		close()
		return
	var n: Dictionary = dlg["nodes"][node_id]
	if n.has("choices"):
		return
	if n.has("next"):
		_show_node(n["next"])
	else:
		close()

func _run_actions(list: Array) -> void:
	for a in list:
		var p: PackedStringArray = String(a).split(":")
		match p[0]:
			"flag":
				WorldState.set_flag(p[1])
			"quest":
				WorldState.start_quest(p[1])
			"give":
				var n := int(p[2]) if p.size() > 2 else 1
				WorldState.add_item(p[1], n)
				WorldState.bus.emit_signal("toast", "%s %s" % [Data.tr_ui("got_item"), Data.name_of(p[1])])
			"take":
				WorldState.remove_item(p[1], int(p[2]) if p.size() > 2 else 1)
			"obol":
				var amt := int(p[1])
				if amt >= 0:
					WorldState.add_item("obol", amt)
				else:
					WorldState.remove_item("obol", -amt)
			"heal":
				WorldState.heal(int(p[1]))
				if int(p[1]) >= 99:
					WorldState.magic = WorldState.max_magic
			"renown":
				WorldState.renown += int(p[1])
			"event":
				WorldState.notify_event(p[1])
			"save":
				if WorldState.save_game():
					WorldState.bus.emit_signal("toast", Data.tr_ui("saved"))
			"shop":
				shop_after_close = true

## Stick up/down moves between buttons, A presses the focused one (dialogue choices, shop, menu):
## on a phone the Pad feeds these actions, so lists work without tapping.
func _pad_nav() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not is_ancestor_of(f) or not f.is_visible_in_tree():
		var first := _first_button(panel if panel != null else self)
		if first != null and (Input.is_action_just_pressed("mv_down") or Input.is_action_just_pressed("mv_up")):
			first.grab_focus()
		return false
	if Input.is_action_just_pressed("mv_down") or Input.is_action_just_pressed("mv_right"):
		var n := f.find_next_valid_focus()
		if n != null and is_ancestor_of(n):
			n.grab_focus()
	elif Input.is_action_just_pressed("mv_up") or Input.is_action_just_pressed("mv_left"):
		var p := f.find_prev_valid_focus()
		if p != null and is_ancestor_of(p):
			p.grab_focus()
	elif Input.is_action_just_pressed("btn_a") and f is BaseButton and not f.disabled:
		f.emit_signal("pressed")
		return true
	return false

func _first_button(n: Node) -> Button:
	if n == null:
		return null
	for c in n.get_children():
		if c is Button and c.is_visible_in_tree() and not c.disabled:
			return c
		var b := _first_button(c)
		if b != null:
			return b
	return null

func _process(dt: float) -> void:
	if mode == "dialogue" and choices_box != null and choices_box.get_child_count() > 0 and choices_box.get_child(0).visible:
		if _pad_nav():
			return
	elif mode == "shop" or mode == "menu":
		if _pad_nav():
			return
	if mode == "dialogue" or mode == "text":
		if text_label != null:
			typing_t += dt * 60.0
			var total := text_label.text.length()
			text_label.visible_characters = int(typing_t)
			if text_label.visible_characters >= total and choices_box != null:
				for b in choices_box.get_children():
					b.visible = true
				if choices_box.get_child_count() > 0 and not choices_box.get_child(0).has_focus():
					choices_box.get_child(0).grab_focus()
		var pressed := Input.is_action_just_pressed("btn_a") or Input.is_action_just_pressed("btn_b") or tap
		tap = false
		if pressed:
			var total2 := text_label.text.length() if text_label else 0
			if text_label != null and text_label.visible_characters < total2:
				typing_t = float(total2)         # first tap finishes the line
			else:
				var has_choices := choices_box != null and choices_box.get_child_count() > 0
				if not has_choices:
					_advance()
	elif mode == "menu" or mode == "shop":
		if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("btn_b"):
			if mode == "menu":
				emit_signal("resume_requested")
			close()

# ---------------------------------------------------------------------------------------------- shop
func open_shop() -> void:
	get_tree().paused = true
	mode = "shop"
	_mk_panel(Rect2(60, 20, 264, 170))
	_lbl("%s     %s %d" % [Data.tr_ui("shop_title"), Data.tr_ui("obol"), WorldState.item_count("obol")], 10, Color(1, 0.85, 0.4), false)
	for s in Data.shop["stock"]:
		var id: String = s["item"]
		var sold: bool = s.get("once", false) and WorldState.item_count(id) > 0
		var label := "%s - %d" % [Data.name_of(id), int(s["price"])]
		if sold:
			label = "%s (%s)" % [Data.name_of(id), Data.tr_ui("sold_out")]
		var b := _btn(label, _buy.bind(s))
		b.disabled = sold
		b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	_btn(Data.tr_ui("close"), close)
	var fb := _first_button(panel)
	if fb != null:
		fb.grab_focus()   # stick + A work straight away

func _buy(s: Dictionary) -> void:
	if WorldState.item_count("obol") < int(s["price"]):
		WorldState.bus.emit_signal("toast", Data.tr_ui("not_enough"))
		return
	WorldState.remove_item("obol", int(s["price"]))
	WorldState.add_item(s["item"], 1)
	WorldState.bus.emit_signal("toast", Data.tr_ui("bought"))
	open_shop()

# ---------------------------------------------------------------------------------------------- menu
func open_menu() -> void:
	get_tree().paused = true
	mode = "menu"
	_build_menu()

func _build_menu() -> void:
	_mk_panel(Rect2(40, 10, 304, 196))
	var tabs := HBoxContainer.new()
	vbox.add_child(tabs)
	for t in [["items", "tab_items"], ["quests", "tab_quests"], ["options", "tab_options"]]:
		var b := _btn(Data.tr_ui(t[1]), _set_tab.bind(t[0]), tabs)
		b.disabled = (tab == t[0])
		b.add_theme_color_override("font_disabled_color", Color(1, 0.85, 0.4))
	match tab:
		"items":
			_lbl("%d / %d" % [WorldState.half_hearts, WorldState.max_half_hearts], 8, Color(0.9, 0.4, 0.4), false)
			var any := false
			for id in WorldState.inventory.keys():
				if id == "obol":
					continue
				any = true
				var row := HBoxContainer.new()
				vbox.add_child(row)
				var l := Label.new()
				var cnt: int = WorldState.item_count(id)
				l.text = Data.name_of(id) + (" x%d" % cnt if cnt > 1 else "")
				l.add_theme_font_size_override("font_size", Prefs.fs(9))
				l.custom_minimum_size.x = 150
				row.add_child(l)
				if WorldState.is_equippable(id):
					_btn("X" + (" *" if WorldState.equipped_x == id else ""), _equip.bind(id, "x"), row)
					_btn("Y" + (" *" if WorldState.equipped_y == id else ""), _equip.bind(id, "y"), row)
			if not any:
				_lbl(Data.tr_ui("empty"), 9, Color(0.7, 0.7, 0.7))
		"quests":
			var any2 := false
			for id in WorldState.quests.state.keys():
				var st: String = WorldState.quests.state[id]["state"]
				var col := Color.WHITE if st == "active" else Color(0.55, 0.55, 0.55)
				_lbl(("%s%s" % [Data.name_of(id), "" if st == "active" else " ✓"]), 9, col)
				if st == "active":
					_lbl("  " + WorldState.quests.current_text(id, Data.lang), 8, Color(0.85, 0.85, 0.6))
				any2 = true
			if not any2:
				_lbl(Data.tr_ui("no_quests"), 9, Color(0.7, 0.7, 0.7))
		"options":
			_btn(Data.tr_ui("language"), _toggle_lang)
			_btn("%s: %.1f" % [Data.tr_ui("text_size"), Prefs.text_scale], _cycle_scale)
			_btn("Touch: %s" % Prefs.touch_mode, _cycle_touch)
			_btn(Data.tr_ui("save"), func(): emit_signal("save_requested"))
			_btn(Data.tr_ui("quit_title"), func(): close(); emit_signal("quit_to_title_requested"))
	_btn(Data.tr_ui("resume"), func(): emit_signal("resume_requested"); close())

func _set_tab(t: String) -> void:
	tab = t
	_build_menu()

func _equip(id: String, slot: String) -> void:
	if slot == "x":
		if WorldState.equipped_y == id:
			WorldState.equipped_y = WorldState.equipped_x
		WorldState.equipped_x = id
	else:
		if WorldState.equipped_x == id:
			WorldState.equipped_x = WorldState.equipped_y
		WorldState.equipped_y = id
	WorldState.bus.emit_signal("changed")
	_build_menu()

func _toggle_lang() -> void:
	Data.lang = "es" if Data.lang == "en" else "en"
	Prefs.lang = Data.lang
	Prefs.save_prefs()
	emit_signal("language_changed")
	_build_menu()

func _cycle_scale() -> void:
	Prefs.text_scale = 1.2 if Prefs.text_scale < 1.1 else (1.4 if Prefs.text_scale < 1.3 else 1.0)
	Prefs.save_prefs()
	emit_signal("language_changed")
	_build_menu()

func _cycle_touch() -> void:
	Prefs.touch_mode = {"auto": "on", "on": "off", "off": "auto"}[Prefs.touch_mode]
	Prefs.save_prefs()
	emit_signal("language_changed")
	_build_menu()

# ---------------------------------------------------------------------------------------------- title
func open_title() -> void:
	get_tree().paused = true
	mode = "title"
	_mk_panel(Rect2(92, 40, 200, 140))
	_lbl(Data.tr_ui("title"), 18, Color(0.95, 0.8, 0.35), false)
	_lbl(Data.tr_ui("subtitle"), 9, Color(0.8, 0.8, 0.9), false)
	_btn(Data.tr_ui("new_game"), _open_new_game)
	var c := _btn(Data.tr_ui("continue"), func(): _leave_title(); emit_signal("continue_requested"))
	c.disabled = not WorldState.has_save()
	c.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))
	_btn(Data.tr_ui("language"), func(): _toggle_lang_title())

func _toggle_lang_title() -> void:
	Data.lang = "es" if Data.lang == "en" else "en"
	Prefs.lang = Data.lang
	Prefs.save_prefs()
	open_title()

func _leave_title() -> void:
	_clear()
	mode = ""
	get_tree().paused = false

func _open_new_game() -> void:
	mode = "title"
	_mk_panel(Rect2(80, 30, 224, 156))
	_lbl(Data.tr_ui("choose_name"), 9, Color(1, 0.85, 0.4), false)
	name_edit = LineEdit.new()
	name_edit.max_length = 12
	name_edit.placeholder_text = Data.tr_ui("default_name_m") if male_pick else Data.tr_ui("default_name_f")
	name_edit.add_theme_font_size_override("font_size", Prefs.fs(10))
	vbox.add_child(name_edit)
	_lbl(Data.tr_ui("choose_body"), 9, Color(1, 0.85, 0.4), false)
	var row := HBoxContainer.new()
	vbox.add_child(row)
	var bm := _btn(Data.tr_ui("body_male"), _pick_body.bind(true), row)
	var bf := _btn(Data.tr_ui("body_female"), _pick_body.bind(false), row)
	bm.disabled = male_pick
	bf.disabled = not male_pick
	bm.add_theme_color_override("font_disabled_color", Color(1, 0.85, 0.4))
	bf.add_theme_color_override("font_disabled_color", Color(1, 0.85, 0.4))
	_lbl(Data.tr_ui("choose_hair"), 9, Color(1, 0.85, 0.4), false)
	var hrow := HBoxContainer.new()
	vbox.add_child(hrow)
	for h in HAIRS:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(22, 16)
		sw.tooltip_text = Data.tr_ui("hair_" + h)
		var sb := StyleBoxFlat.new()
		sb.bg_color = HAIRS[h]
		sb.set_border_width_all(2 if h == hair_pick else 1)
		sb.border_color = Color(1, 0.85, 0.4) if h == hair_pick else Color(0.3, 0.3, 0.35)
		for st in ["normal", "hover", "pressed", "focus"]:
			sw.add_theme_stylebox_override(st, sb)
		sw.pressed.connect(_pick_hair.bind(h))
		hrow.add_child(sw)
	var base := "hero_m" if male_pick else "hero_f"
	var pv := TextureRect.new()   # preview of the chosen look
	pv.texture = Art.anim_frame_tex(base + ("" if hair_pick == "brown" else "_" + hair_pick) + "_walk_down")
	pv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pv.custom_minimum_size = Vector2(26, 24)
	pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hrow.add_child(pv)
	_btn(Data.tr_ui("start"), _begin)

func _pick_body(m: bool) -> void:
	var keep := name_edit.text if name_edit else ""
	male_pick = m
	_open_new_game()
	name_edit.text = keep

func _pick_hair(h: String) -> void:
	var keep := name_edit.text if name_edit else ""
	hair_pick = h
	_open_new_game()
	name_edit.text = keep

func _begin() -> void:
	var nm := name_edit.text.strip_edges()
	if nm == "":
		nm = Data.tr_ui("default_name_m") if male_pick else Data.tr_ui("default_name_f")
	_leave_title()
	emit_signal("new_game_requested", nm, male_pick)
