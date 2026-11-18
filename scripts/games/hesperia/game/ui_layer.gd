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
const UiTheme := preload("res://scripts/games/hesperia/game/ui_theme.gd")
const Sounds := preload("res://scripts/games/hesperia/hesperia_sounds.gd")
const TITLE_BG := preload("res://scripts/games/hesperia/game/title_bg.gd")
var title_bg: Control = null     # animated backdrop, survives _clear() while on title / new-game
var shown_mode: String = ""      # panel pop-in plays once per opened screen, not on every rebuild
var line_done: bool = false      # dialogue: line fully typed and no choices -> draw the advance arrow
var ui_t: float = 0.0

func _input(ev: InputEvent) -> void:
	if (mode == "dialogue" or mode == "text") and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		tap = true

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	theme = UiTheme.build()

func is_open() -> bool:
	return mode != ""

func _clear() -> void:
	for c in get_children():
		if c != title_bg:
			c.queue_free()
	panel = null
	line_done = false
	text_label = null
	choices_box = null

func _mk_panel(rect: Rect2) -> VBoxContainer:
	_clear()
	panel = PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var sb := UiTheme.panel_box()   # visual pass: bronze-rimmed lacquer panel with drop shadow (was flat navy + 1px border)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	panel.draw.connect(_draw_arrow)
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	if shown_mode != mode:
		shown_mode = mode
		_pop(panel, rect)
	return vbox

## Pop-in: fade + slight rise and scale with a soft overshoot. Runs while paused (UI is PROCESS_MODE_ALWAYS).
func _pop(c: Control, rect: Rect2) -> void:
	c.pivot_offset = rect.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(0.94, 0.94)
	c.position = rect.position + Vector2(0, 4)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.14)
	tw.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", rect.position, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Speaker nameplate: gold tab above the dialogue text.
func _nameplate(text: String) -> void:
	var l := _lbl(text, 8, Color(0.12, 0.07, 0.04), false)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.BRONZE
	sb.border_color = UiTheme.GOLD
	sb.border_width_top = 1
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.anti_aliasing = false
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0))
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

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

## Spoken line: 2x the pixel font (crisp, readable on phones) when it fits the box, else the native 1x size.
func _say(text: String, has_choices: bool = false) -> Label:
	var big := Prefs.fs(20)
	var f := UiTheme.font()
	var lines := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, 320.0, big).y / maxf(1.0, f.get_height(big))
	if lines <= (2.0 if has_choices else 3.0) + 0.1:
		var l := _lbl(text, 20)
		l.add_theme_constant_override("line_spacing", -int(big * 0.3))
		return l
	return _lbl(text, 9)

func close() -> void:
	_clear()
	_drop_title_bg()
	var was := mode
	if was == "menu" or was == "shop":
		Sounds.menu_close(self)
	mode = ""
	shown_mode = ""
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
		_nameplate(speaker)
	text_label = _say(Tokens.resolve(Data.loc(t), WorldState.hero_name, WorldState.male))
	text_label.visible_characters = 0
	typing_t = 0.0

func _show_node(id: String) -> void:
	node_id = id
	Sounds.page(self)
	var n: Dictionary = dlg["nodes"][id]
	_mk_panel(Rect2(24, 118, 336, 78))
	var who: String = n.get("speaker", "")
	if who != "":
		_nameplate(Data.name_of(who) if who != "hero" else WorldState.hero_name)
	text_label = _say(Tokens.resolve(Data.loc(n["text"]), WorldState.hero_name, WorldState.male), n.has("choices"))
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
	ui_t += dt
	if mode == "dialogue" or mode == "text":
		var nch := choices_box != null and choices_box.get_child_count() > 0
		line_done = text_label != null and text_label.visible_characters >= text_label.text.length() and not nch
		if panel != null and is_instance_valid(panel):
			panel.queue_redraw()
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
	Sounds.buy(self)
	WorldState.bus.emit_signal("toast", Data.tr_ui("bought"))
	open_shop()

# ---------------------------------------------------------------------------------------------- menu
func open_menu() -> void:
	get_tree().paused = true
	Sounds.menu_open(self)
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
	# Landing style S4 "Monument" (MENU_STYLES.md): huge logo top-left, 3 tiny title-case rows centred under it,
	# no boxes, selected = white, hero large on the right of the animated backdrop (title_bg.gd).
	_clear()
	_ensure_title_bg()
	var vw: float = get_viewport_rect().size.x
	var vh: float = get_viewport_rect().size.y
	var logo := Label.new()
	logo.text = Data.tr_ui("title")
	var ls := LabelSettings.new()
	ls.font = UiTheme.font()
	ls.font_size = 40
	ls.font_color = Color(0.98, 0.8, 0.42)
	ls.outline_size = 6
	ls.outline_color = Color(0.22, 0.09, 0.07)
	ls.shadow_size = 2
	ls.shadow_color = Color(0.05, 0.02, 0.08, 0.8)
	ls.shadow_offset = Vector2(0, 3)
	logo.label_settings = ls
	logo.position = Vector2(roundf(vw * 0.05), roundf(vh * 0.02))
	add_child(logo)
	var sub := Label.new()
	sub.text = Data.tr_ui("subtitle")
	var ss := LabelSettings.new()
	ss.font = UiTheme.font()
	ss.font_size = 10
	ss.font_color = Color(0.55, 0.85, 0.85)       # the one accent colour on the logo block (sea-teal)
	ss.outline_size = 2
	ss.outline_color = Color(0.08, 0.04, 0.1)
	sub.label_settings = ss
	sub.position = Vector2(roundf(vw * 0.05) + 2, roundf(vh * 0.255))
	add_child(sub)
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.position = Vector2(roundf(vw * 0.27) - 60.0, roundf(vh * 0.36))
	vbox.size = Vector2(120, 40)
	add_child(vbox)
	var rows: Array = []
	rows.append(_btn(Data.tr_ui("new_game"), _open_new_game))
	var c := _btn(Data.tr_ui("continue"), func(): _leave_title(); emit_signal("continue_requested"))
	c.disabled = not WorldState.has_save()
	c.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))
	rows.append(c)
	rows.append(_btn(Data.tr_ui("language"), func(): _toggle_lang_title()))
	for b in rows:
		UiTheme.flat_button(b)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", Prefs.fs(9))
	if not c.disabled:
		c.grab_focus.call_deferred()      # returning player: Continue is the obvious choice
	else:
		rows[0].grab_focus.call_deferred()
	# entrance: logo drops in, rows stagger
	logo.modulate.a = 0.0
	sub.modulate.a = 0.0
	var tw := logo.create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 0.5).set_delay(0.1)
	tw.parallel().tween_property(logo, "position:y", logo.position.y, 0.6).from(logo.position.y - 8.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.1)
	tw.tween_property(sub, "modulate:a", 1.0, 0.35)
	for i in rows.size():
		var b: Button = rows[i]
		b.modulate.a = 0.0
		var tb := b.create_tween()
		tb.tween_property(b, "modulate:a", 1.0, 0.3).set_delay(0.55 + 0.08 * float(i))
	title_bg.male = male_pick
	title_bg.hair = hair_pick

func _ensure_title_bg() -> void:
	if title_bg == null or not is_instance_valid(title_bg):
		title_bg = Control.new()
		title_bg.set_script(TITLE_BG)
		add_child(title_bg)
		move_child(title_bg, 0)

func _drop_title_bg() -> void:
	if title_bg != null and is_instance_valid(title_bg):
		title_bg.queue_free()
	title_bg = null

func _toggle_lang_title() -> void:
	Data.lang = "es" if Data.lang == "en" else "en"
	Prefs.lang = Data.lang
	Prefs.save_prefs()
	open_title()

func _leave_title() -> void:
	_clear()
	_drop_title_bg()
	mode = ""
	shown_mode = ""
	get_tree().paused = false

func _open_new_game() -> void:
	mode = "newgame"
	_ensure_title_bg()
	title_bg.male = male_pick
	title_bg.hair = hair_pick
	_mk_panel(Rect2(24, 30, 224, 156))   # left of the hero so the backdrop previews the chosen look
	mode = "title"
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

## Dialogue advance arrow: small bobbing gold chevron at the panel's bottom-right once the line is fully typed.
## Drawn through the panel's draw signal so it sits on top of the panel background.
func _draw_arrow() -> void:
	if not line_done or panel == null or not is_instance_valid(panel):
		return
	var p := panel.size - Vector2(10, 7) + Vector2(0, roundf(sin(ui_t * 6.0) * 1.5))
	panel.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -2), p + Vector2(3, -2), p + Vector2(0, 2)]), UiTheme.GOLD)
	panel.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -2), p + Vector2(0, -2), p + Vector2(0, 2)]), UiTheme.BRONZE)
