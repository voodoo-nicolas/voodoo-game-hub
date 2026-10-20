extends Control

## Evolution's two in-game screens, both opened from the ℹ button in the middle of the HUD:
##   creature screen : your cell drawn big, with size / speed / strength / health, DNA, ailments
##   evolution tree  : four branches; owned traits, buyable ones, and "?" for the ones not unlocked yet
## The game keeps running state untouched underneath (it just stops stepping while this is up).

const Art = preload("res://scripts/games/evolution/evolution_art.gd")
const EvEngine = preload("res://scripts/games/evolution/evolution_engine.gd")
const Data = preload("res://scripts/games/evolution/evolution_data.gd")
const TreeView = preload("res://scripts/games/evolution/evolution_tree_view.gd")

signal closed
signal home_pressed
signal sfx(sound: String)

var engine
var color := Color("29e6ff")
var col2 := Color("ffd23f")     # the player's secondary colours (set by the game)
var col3 := Color("ff4f9a")
var voodoo := false
var _t := 0.0
var _portrait: Control
var _page: VBoxContainer
var _tree_view := false
var _view: Control
var _sel := ""
var _title: Label
var _detail: Label
var _buy_btn: Button
var _dna_label: Label
var _names := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 24)
	add_child(margin)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 10)
	margin.add_child(_page)

func open_info(eng, col: Color, vood: bool) -> void:
	engine = eng
	color = col
	voodoo = vood
	_tree_view = false
	visible = true
	_build()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		closed.emit()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if visible:
		_t += delta
		if _portrait:
			_portrait.queue_redraw()

func _clear() -> void:
	for ch in _page.get_children():
		_page.remove_child(ch)
		ch.queue_free()
	_portrait = null
	_view = null

func _build() -> void:
	_clear()
	if _tree_view:
		_build_tree()
	else:
		_build_info()

func _label(text: String, size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

## A label that wraps inside a column (needs a width, or it wraps per letter).
func _wrapped(text: String, size: int, col: Color) -> Label:
	var l := _label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _button(text: String, action: Callable, min_w: float = 190.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b

# ---------- creature screen ----------

func _build_info() -> void:
	var title := _label(tr("Your creature"), 38, color.lerp(Color.WHITE, 0.5))
	_page.add_child(title)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	_page.add_child(row)
	_portrait = Control.new()
	_portrait.custom_minimum_size = Vector2(300, 260)
	_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait.size_flags_stretch_ratio = 1.0
	_portrait.draw.connect(_draw_portrait)
	row.add_child(_portrait)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.1
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	var e = engine
	col.add_child(_label(tr(EvEngine.STAGES[e.stage()][1]) + "  ·  " + tr("DNA points: %d") % e.dna, 26, Color("ffd479")))
	_stat(col, tr("Size"), str(e.level()), float(e.level()) / float(Data.LEVELS.size()))
	_stat(col, tr("Speed"), str(int(e.top_speed() / 10.0)), clampf(e.top_speed() / (EvEngine.TUNING.player_speed * 1.15), 0.0, 1.0))
	_stat(col, tr("Strength"), str(e.strength()), float(e.strength()) / 3.0)
	_stat(col, tr("Health"), "%d / %d" % [int(ceil(e.player.hp)), int(e.max_hp())], e.player.hp / e.max_hp())
	for id in e.ailments.keys():
		var a: Dictionary = Data.AILMENTS[id]
		col.add_child(_wrapped("☠ " + tr(a.name) + " (%ds): " % int(ceil(e.ailments[id])) + tr(a.desc), 20, Color("d7ff2a")))
	for s in Data.SPECIALS:
		if e.specials.has(s.id):
			col.add_child(_wrapped("★ " + tr(s.name) + ": " + tr(s.desc), 20, Color("ffd23f")))
	# Resistances grow from getting the same ailment again and again.
	for id in Data.AILMENT_ORDER:
		if int(e.ail_count.get(id, 0)) <= 0:
			continue
		var rs: Dictionary = Data.RESISTS[id]
		var line := "🛡 " + tr(rs.name) + " %d/%d" % [e.resist_rank(id), Data.RESIST_AT.size()]
		if e.resist_rank(id) > 0:
			line += ": " + tr(rs.desc)
		if e.resist_left(id) > 0:
			line += "  (" + tr("next rank after %d more") % e.resist_left(id) + ")"
		col.add_child(_wrapped(line, 20, Color("9fe8c0")))
	col.add_child(_wrapped(tr("Habitat: down to %d m, water as cold as %d °C") % [int(e.max_depth_m()), int(ceil(e.min_temp()))], 20, Color(0.8, 0.92, 1.0)))
	_abilities(col)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	_page.add_child(btns)
	var tree_btn := _button("🧬 " + tr("Evolution tree") if engine.tree_unlocked else "🧬 ?", _show_tree, 260.0)
	tree_btn.disabled = not engine.tree_unlocked
	btns.add_child(tree_btn)
	btns.add_child(_button("✕ " + tr("Close"), _close_pressed))

## The ability buttons: tap one to choose which ability it fires.
func _abilities(parent: Control) -> void:
	parent.add_child(_label(tr("Abilities"), 26, Color("ffd479")))
	var names := [tr("Offense button"), tr("Defense button"), tr("Extra button %d") % 3, tr("Extra button %d") % 4]
	for i in 4:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if engine.slot_visible(i):
			var id: String = engine.slot_ids[i]
			b.text = names[i] + ":  " + (tr(Data.ABILITIES[id].name) if id != "" else "-")
			if engine.eligible(i).size() > 1:
				b.text += "   ↻"
			b.pressed.connect(_cycle.bind(i))
		else:
			b.disabled = true
			if i == 0:
				b.text = names[i] + ":  " + tr("learn an offensive ability first")
			elif i == 1:
				b.text = names[i] + ":  " + tr("learn a defensive ability first")
			else:
				b.text = names[i] + ":  " + tr("reach %s to unlock") % tr(EvEngine.STAGES[Data.SLOT_STAGE[i]][1])
		b.add_theme_font_size_override("font_size", 20)
		parent.add_child(b)

func _cycle(i: int) -> void:
	engine.cycle_slot(i)
	sfx.emit("tap")
	_build()

func _stat(parent: Control, name: String, value: String, frac: float) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var n := _label(name, 24)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(_label(value, 26, color.lerp(Color.WHITE, 0.4)))
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(frac, 0.0, 1.0)
	box.add_child(bar)
	parent.add_child(box)

func _draw_portrait() -> void:
	if engine == null or _portrait == null:
		return
	var s := _portrait.size
	var r := minf(s.x, s.y) * 0.22
	_portrait.draw_circle(s / 2.0, r * 2.1, Color(color, 0.05))
	var st := {
		"move_rank": engine.move_rank, "sight_rank": engine.sight_rank, "eye_open": 1.0,
		"owned": engine.owned, "specials": engine.specials, "ailments": engine.ailments,
		"speed": 0.15, "voodoo": voodoo, "col2": col2, "col3": col3,
	}
	Art.draw_player(_portrait, s / 2.0 + Vector2(r * 0.6, 0), r, color, 0.0, _t, st)

func _show_tree() -> void:
	sfx.emit("tap")
	_tree_view = true
	_build()

func _close_pressed() -> void:
	close()
	closed.emit()

# ---------- evolution tree ----------

func _build_tree() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_page.add_child(head)
	head.add_child(_button("‹ " + tr("Back"), _back_to_info, 150.0))
	var t := _label(tr("Evolution tree"), 34, color.lerp(Color.WHITE, 0.5))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	_dna_label = _label(tr("DNA points: %d") % engine.dna, 28, Color("ffd479"))
	head.add_child(_dna_label)
	head.add_child(_button("🏠 " + tr("Home"), _home_pressed, 150.0))
	_view = TreeView.new()
	_view.engine = engine
	_view.color = color
	_view.col2 = col2
	_view.col3 = col3
	_view.voodoo = voodoo
	_view.show_names = _names
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.selected.connect(_on_node_selected)
	_page.add_child(_view)
	_view.selected_id = _sel
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	_page.add_child(bottom)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(info)
	_title = _label("", 26, Color("ffd479"))
	info.add_child(_title)
	_detail = _label("", 18)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(300, 0)
	info.add_child(_detail)
	var side := VBoxContainer.new()
	bottom.add_child(side)
	_buy_btn = _button("", _buy_selected, 220.0)
	side.add_child(_buy_btn)
	var cb := CheckBox.new()
	cb.text = tr("Show names")
	cb.button_pressed = _names
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(_on_names)
	side.add_child(cb)
	_refresh_detail()
	_view.call_deferred("reset_view")

func _on_names(on: bool) -> void:
	_names = on
	if _view:
		_view.show_names = on

func _on_node_selected(id: String) -> void:
	_sel = id
	sfx.emit("tap")
	_refresh_detail()

func _needs_text(n: Dictionary) -> String:
	var parts: Array = []
	for r in n.req:
		var rn: Dictionary = Data.node_of(r[0])
		parts.append(tr(rn.name) + (" ×%d" % int(r[1]) if int(r[1]) > 1 else ""))
	return ", ".join(parts)

func _refresh_detail() -> void:
	if _title == null:
		return
	_dna_label.text = tr("DNA points: %d") % engine.dna
	if _sel == "":
		_title.text = tr("Evolution tree")
		_detail.text = tr("Drag to look around. Tap a trait to see what it does.")
		_buy_btn.visible = false
		return
	var n := Data.node_of(_sel)
	var state: String = engine.node_state(_sel)
	_buy_btn.visible = true
	if state == "locked":
		_title.text = "?"
		_detail.text = ""
		_buy_btn.visible = false
		return
	_title.text = tr(n.name) + "   " + tr("Points: %d/%d") % [engine.rank_of(_sel), int(n.max)]
	var txt: String = tr(n.desc)
	if n.ability:
		txt += "\n" + tr("Active ability: it uses the power bar. More points make it cheaper, longer and stronger.")
	if not n.req.is_empty():
		txt += "\n" + tr("Needs: %s") % _needs_text(n)
	_detail.text = txt
	if state == "maxed":
		_buy_btn.text = tr("Maxed")
		_buy_btn.disabled = true
	elif state == "stage":
		_detail.text += "\n" + tr("Grow to %s to evolve it.") % tr(EvEngine.STAGES[int(n.stage)][1])
		_buy_btn.text = tr("Buy for %d DNA") % engine.cost_of(_sel)
		_buy_btn.disabled = true
	else:
		_buy_btn.text = tr("Buy for %d DNA") % engine.cost_of(_sel)
		_buy_btn.disabled = not engine.can_buy(_sel)

func _buy_selected() -> void:
	if _sel == "":
		return
	if engine.buy(_sel):
		sfx.emit("powerup")
	else:
		sfx.emit("tap")
	_refresh_detail()
	if _view:
		_view.queue_redraw()

func _back_to_info() -> void:
	_tree_view = false
	_build()

func _home_pressed() -> void:
	home_pressed.emit()
