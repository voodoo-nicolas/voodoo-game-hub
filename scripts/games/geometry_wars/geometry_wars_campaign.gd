extends Control

## The Adventure map: every campaign level by world with its stars, the drone
## picker, and the Hardcore tab (the same levels with no drone, starred
## apart). Built in code like the rest of the game; the game listens to
## play_level and closed.
##
## Progress lives in user://geometry_wars_campaign.json:
##   {stars: {"<id>": 0..3}, hard: {...}, best: {"<id>": score}, hbest: {...},
##    drone: "attack"}
## A level opens once the one before it has a star (Ultimate: once level 30
## has one); Hardcore opens a level once it's cleared in Adventure.

signal play_level(id: int, hardcore: bool, drone: String)
signal closed

const HomeKit = preload("res://scripts/games/geometry_wars/home_kit.gd")
const Levels = preload("res://scripts/games/geometry_wars/geometry_wars_levels.gd")
const Drones = preload("res://scripts/games/geometry_wars/geometry_wars_drones.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")

const PATH := "user://geometry_wars_campaign.json"

var data: Dictionary = {}
var hardcore := false
var _list: VBoxContainer
var _drones_row: HBoxContainer
var _stars_label: Label
var _title: Label
var _scroll: ScrollContainer
var _drag: Node
var _card: Control
var _card_box: VBoxContainer
var _tabs: Array = []

# ---------- progress ----------

static func load_progress() -> Dictionary:
	var d = SaveUtil.read(PATH)
	if not (d is Dictionary):
		d = {}
	for k in ["stars", "hard", "best", "hbest"]:
		if not (d.get(k) is Dictionary):
			d[k] = {}
	if not d.has("drone"):
		d["drone"] = "attack"
	return d

static func save_progress(d: Dictionary) -> void:
	SaveUtil.write(PATH, d)

static func stars_of(d: Dictionary, id: int, hard: bool) -> int:
	return int((d["hard" if hard else "stars"] as Dictionary).get(str(id), 0))

static func total_stars(d: Dictionary, hard: bool) -> int:
	var n := 0
	for k in (d["hard" if hard else "stars"] as Dictionary):
		n += int(d["hard" if hard else "stars"][k])
	return n

static func is_open(d: Dictionary, id: int, hard: bool) -> bool:
	if hard:
		return stars_of(d, id, false) > 0
	if id == 1:
		return true
	if id == Levels.ULTIMATE_FIRST:
		return stars_of(d, Levels.ULTIMATE_FIRST - 1, false) > 0
	return stars_of(d, id - 1, false) > 0

static func drone_open(d: Dictionary, kind: String) -> bool:
	return total_stars(d, false) >= int(Drones.UNLOCK.get(kind, 999))

static func drones_open(d: Dictionary) -> int:
	var n := 0
	for k in Drones.KINDS:
		if drone_open(d, k):
			n += 1
	return n

## Records a cleared level; returns the drones this unlocked.
static func record(d: Dictionary, id: int, hard: bool, stars: int, score: int) -> Array:
	var before: Array = []
	for k in Drones.KINDS:
		if drone_open(d, k):
			before.append(k)
	var key := str(id)
	var sk := "hard" if hard else "stars"
	var bk := "hbest" if hard else "best"
	d[sk][key] = maxi(int(d[sk].get(key, 0)), stars)
	d[bk][key] = maxi(int(d[bk].get(key, 0)), score)
	save_progress(d)
	var fresh: Array = []
	for k in Drones.KINDS:
		if drone_open(d, k) and not k in before:
			fresh.append(k)
	return fresh

# ---------- screen ----------

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = HomeKit.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid := Control.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.draw.connect(HomeKit.draw_grid.bind(grid))
	add_child(grid)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	var back := HomeKit.neon_button("◀ " + tr("Home"), HomeKit.CYAN, 22, 52)
	back.custom_minimum_size.x = 130
	back.pressed.connect(_on_back)
	top.add_child(back)
	_title = HomeKit.label("", 32, HomeKit.GOLD)
	_title.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.45))
	_title.add_theme_constant_override("outline_size", 8)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_stars_label = HomeKit.label("", 26, HomeKit.GOLD)
	top.add_child(_stars_label)
	for i in 2:
		var tab := HomeKit.neon_button(tr("🗺 Adventure") if i == 0 else tr("💀 Hardcore"), HomeKit.GOLD if i == 0 else HomeKit.PINK, 20, 52)
		tab.toggle_mode = true
		tab.custom_minimum_size.x = 150
		tab.pressed.connect(_set_hardcore.bind(i == 1))
		top.add_child(tab)
		_tabs.append(tab)

	_drones_row = HBoxContainer.new()
	_drones_row.add_theme_constant_override("separation", 8)
	col.add_child(_drones_row)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_drag = HomeKit._DragScroll.new()
	_scroll.add_child(_drag)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

	_build_card()
	refresh()

func _dragged() -> bool:
	return _drag != null and _drag.moved

func open(hard: bool = false) -> void:
	data = load_progress()
	hardcore = hard
	visible = true
	refresh()

func refresh() -> void:
	if _list == null:
		return
	data = load_progress() if data.is_empty() else data
	_title.text = tr("Hardcore") if hardcore else tr("Adventure")
	_title.add_theme_color_override("font_color", HomeKit.PINK if hardcore else HomeKit.GOLD)
	var max_stars := Levels.count() * 3
	_stars_label.text = "★ %d / %d" % [total_stars(data, hardcore), max_stars]
	for i in _tabs.size():
		(_tabs[i] as Button).set_pressed_no_signal((i == 1) == hardcore)
	_build_drones()
	for c in _list.get_children():
		c.queue_free()
	for w in Levels.WORLDS.size():
		var world: Dictionary = Levels.WORLDS[w]
		var ids: Array = Levels.world_levels(w)
		var wcol: Color = (world.grid as Color).lightened(0.35)
		var head := HomeKit.label("%s  ·  %s" % [tr("World %d") % (w + 1), tr(str(world.name))], 24, wcol)
		if w == 5:
			head.text = "🔥 " + tr(str(world.name))
		_list.add_child(head)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		_list.add_child(flow)
		for id in ids:
			flow.add_child(_level_button(id, wcol))
	_list.add_child(HomeKit.gap(20))

func _build_drones() -> void:
	for c in _drones_row.get_children():
		c.queue_free()
	if hardcore:
		var note := HomeKit.label(tr("💀 Hardcore: no drone, stars counted apart."), 22, HomeKit.PINK)
		_drones_row.add_child(note)
		return
	var lbl := HomeKit.label(tr("Drone:"), 22, HomeKit.DIM)
	_drones_row.add_child(lbl)
	for k in Drones.KINDS:
		var open := drone_open(data, k)
		var text := "%s %s" % [Drones.ICONS[k], tr(str(Drones.NAMES[k]))] if open else "🔒 %d★" % int(Drones.UNLOCK[k])
		var b := HomeKit.neon_button(text, Drones.color_of(k), 19, 48)
		b.toggle_mode = true
		b.disabled = not open
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(open and str(data.drone) == k)
		b.tooltip_text = tr(str(Drones.DESCS[k]))
		b.pressed.connect(_pick_drone.bind(k))
		_drones_row.add_child(b)

func _pick_drone(kind: String) -> void:
	data.drone = kind
	save_progress(data)
	_build_drones()

func _level_button(id: int, wcol: Color) -> Button:
	var open := is_open(data, id, hardcore)
	var stars := stars_of(data, id, hardcore)
	var boss := Levels.is_boss(id)
	var text := ""
	if not open:
		text = "🔒\n%d" % id
	else:
		text = ("☠ %d" if boss else "%d") % id + "\n" + "★".repeat(stars) + "☆".repeat(3 - stars)
	var color: Color = HomeKit.PINK if boss else wcol
	var b := HomeKit.neon_button(text, color, 22, 84)
	b.custom_minimum_size.x = 104
	b.disabled = not open
	b.pressed.connect(_show_card.bind(id))
	return b

func _set_hardcore(on: bool) -> void:
	if _dragged():
		return
	hardcore = on
	refresh()

func _on_back() -> void:
	visible = false
	closed.emit()

# ---------- a level's card ----------

func _build_card() -> void:
	_card = ColorRect.new()
	(_card as ColorRect).color = Color(0, 0, 0, 0.7)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_card.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 10)
	panel.add_child(_card_box)

func _show_card(id: int) -> void:
	if _dragged():
		return
	for c in _card_box.get_children():
		c.queue_free()
	var r := Levels.level(id)
	var wcol: Color = (r.grid as Color).lightened(0.35)
	var world_name := tr(str(Levels.WORLDS[r.world].name))
	_card_box.add_child(HomeKit.label("%s · %s" % [world_name, tr("Level %d") % id], 20, HomeKit.DIM, false, true))
	var name_l := HomeKit.label(tr(str(r.name)), 38, wcol, false, true)
	name_l.add_theme_color_override("font_outline_color", Color(wcol, 0.45))
	name_l.add_theme_constant_override("outline_size", 8)
	_card_box.add_child(name_l)
	_card_box.add_child(HomeKit.label("🎯 " + Levels.goal_text(r), 26, HomeKit.WHITE, true, true))
	var notes := Levels.rule_notes(r)
	if hardcore:
		notes = tr("💀 Hardcore: no drone") + (" · " + notes if notes != "" else "")
	if notes != "":
		_card_box.add_child(HomeKit.label(notes, 20, HomeKit.DIM, true, true))
	_card_box.add_child(HomeKit.label("★ %s   ·   ★★ %s   ·   ★★★ %s" % [tr("Finish"), tr("No lives lost"), tr("%s points") % _num(int(r.target))], 22, HomeKit.GOLD, true, true))
	var best := int((data["hbest" if hardcore else "best"] as Dictionary).get(str(id), 0))
	if best > 0:
		_card_box.add_child(HomeKit.label(tr("Best: %s") % _num(best), 22, HomeKit.LIME, false, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card_box.add_child(row)
	var close := HomeKit.neon_button(tr("Close"), HomeKit.DIM, 24, 64)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func(): _card.visible = false)
	row.add_child(close)
	var play := HomeKit.neon_button("▶  " + tr("Play"), HomeKit.LIME, 28, 64)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(_on_play.bind(id))
	row.add_child(play)
	_card.visible = true

func _on_play(id: int) -> void:
	_card.visible = false
	visible = false
	var drone := "" if hardcore else str(data.drone)
	if drone != "" and not drone_open(data, drone):
		drone = "attack"
	play_level.emit(id, hardcore, drone)

static func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
