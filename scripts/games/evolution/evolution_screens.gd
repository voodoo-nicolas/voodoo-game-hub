extends Control

## Evolution's two in-game screens, both opened from the ℹ button in the middle of the HUD:
##   creature screen : your cell drawn big, with size / speed / strength / health, DNA, ailments
##   evolution tree  : four branches; owned traits, buyable ones, and "?" for the ones not unlocked yet
## The game keeps running state untouched underneath (it just stops stepping while this is up).

const Art = preload("res://scripts/games/evolution/evolution_art.gd")
const EvEngine = preload("res://scripts/games/evolution/evolution_engine.gd")
const Data = preload("res://scripts/games/evolution/evolution_data.gd")

signal closed
signal home_pressed
signal sfx(sound: String)

var engine
var color := Color("29e6ff")
var voodoo := false
var _t := 0.0
var _portrait: Control
var _page: VBoxContainer
var _tree_view := false
var _msg: Label

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
	_msg = null

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
	_stat(col, tr("Size"), str(int(e.player.mass)), minf(e.player.mass / 600.0, 1.0))
	_stat(col, tr("Speed"), str(int(e.top_speed() / 10.0)), clampf(e.top_speed() / (EvEngine.TUNING.player_speed * 1.15), 0.0, 1.0))
	_stat(col, tr("Strength"), str(e.strength()), float(e.strength()) / 3.0)
	_stat(col, tr("Health"), "%d / %d" % [int(ceil(e.player.hp)), int(e.max_hp())], e.player.hp / e.max_hp())
	for id in e.ailments.keys():
		var a: Dictionary = Data.AILMENTS[id]
		col.add_child(_wrapped("☠ " + tr(a.name) + " (%ds): " % int(ceil(e.ailments[id])) + tr(a.desc), 20, Color("d7ff2a")))
	for s in Data.SPECIALS:
		if e.specials.has(s.id):
			col.add_child(_wrapped("★ " + tr(s.name) + ": " + tr(s.desc), 20, Color("ffd23f")))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	_page.add_child(btns)
	btns.add_child(_button("🧬 " + tr("Evolution tree"), _show_tree, 260.0))
	btns.add_child(_button("✕ " + tr("Close"), _close_pressed))

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
	var r := minf(s.x, s.y) * 0.3
	_portrait.draw_circle(s / 2.0, r * 2.1, Color(color, 0.05))
	var st := {
		"move_rank": engine.move_rank, "sight_rank": engine.sight_rank, "eye_open": 1.0,
		"owned": engine.owned, "specials": engine.specials, "ailments": engine.ailments,
		"speed": 0.15, "voodoo": voodoo,
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
	var t := _label(tr("Evolution tree"), 36, color.lerp(Color.WHITE, 0.5))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	head.add_child(_label(tr("DNA points: %d") % engine.dna, 28, Color("ffd479")))
	head.add_child(_button("🏠 " + tr("Home"), _home_pressed, 150.0))
	_msg = _label("", 22, Color("ff9f9f"))
	_page.add_child(_msg)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	scroll.add_child(cols)
	for b in Data.BRANCHES:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 8)
		cols.add_child(col)
		col.add_child(_label(tr(Data.TREE[b].name), 28, Color("ffd479")))
		for n in Data.TREE[b].nodes:
			col.add_child(_node_button(n))

func _node_button(n: Dictionary) -> Button:
	var state: String = engine.node_state(n.id)
	var mark := "⚡ " if n.get("ability", false) else ""
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match state:
		"owned":
			b.text = "✔ " + mark + tr(n.name) + "\n" + tr(n.desc)
			b.modulate = Color(color.lerp(Color.WHITE, 0.5), 1.0)
		"available":
			b.text = mark + tr(n.name) + "  ·  " + tr("%d DNA") % int(n.cost) + "\n" + tr(n.desc)
			b.pressed.connect(_buy.bind(n.id))
		_:
			b.text = "?"
			b.disabled = true
			b.add_theme_font_size_override("font_size", 40)
			b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	if state != "locked":
		b.add_theme_font_size_override("font_size", 20)
	return b

func _buy(id: String) -> void:
	if engine.buy(id):
		sfx.emit("powerup")
		_build()
	else:
		var n := Data.node_of(id)
		if _msg:
			_msg.text = tr("Not enough DNA: %d needed.") % int(n.cost)
		sfx.emit("tap")

func _back_to_info() -> void:
	_tree_view = false
	_build()

func _home_pressed() -> void:
	home_pressed.emit()
