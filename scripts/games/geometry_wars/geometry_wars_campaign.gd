extends Control

## The Campaign map: two star maps (the owner's pictures, 2026-10-07) where
## every star is a level -- tap one for its card -- with the familiar picker
## and the Cursed tab (the same levels with no familiar, starred apart).
## Built in code like the rest of the game; the game listens to play_level
## and closed.
##
## Progress lives in user://geometry_wars_campaign.json:
##   {stars: {"<id>": 0..3}, hard: {...}, best: {"<id>": score}, hbest: {...},
##    beaten: {"<id>": true} (boss levels whose boss was beaten, not just
##    outlasted), drone: "attack" or "" (none), fam: {"<kind>": {xp: points
##    earned with it, up: {"armor": 0..5, ...}}}}
## (Saves from the shop days also hold "points" and "owned"; nothing reads
## them now.)
## A level opens once the one before it has a star (Ultimate: once level 30
## has one); Cursed opens a level once it's cleared in the Campaign.
## Familiars (owner, 2026-10-07): none at first; beating the first boss
## brings the Raven, and the others come with campaign stars
## (Drones.UNLOCK_STARS); each one's own xp buys its upgrades. Beating a boss
## also opens a classic mode (Levels.MODE_UNLOCK).

signal play_level(id: int, hardcore: bool, drone: String)
signal closed

const HomeKit = preload("res://scripts/games/geometry_wars/home_kit.gd")
const Levels = preload("res://scripts/games/geometry_wars/geometry_wars_levels.gd")
const Drones = preload("res://scripts/games/geometry_wars/geometry_wars_drones.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")

const PATH := "user://geometry_wars_campaign.json"

## The star maps. "nodes" are the levels in order, from "first": [x, y, r] in
## the picture's pixels, r = the star's radius there. Bosses sit on the big
## flaring stars and each map ends at its centre: the sun is level 24
## (Titan), the black hole level 40 (Twin Terror). Positions were measured
## from the pictures (bright-spot detection), not guessed.
const MAPS := [
	{"name": "☀ Solar Path", "image": "res://games/geometry_wars/map_sun.jpg", "size": Vector2(1547, 1017), "first": 1,
		"nodes": [[294, 757, 22], [35, 478, 16], [831, 111, 22], [1121, 145, 30], [1340, 252, 30], [1444, 406, 38],
			[638, 860, 28], [954, 708, 28], [517, 709, 26], [332, 640, 26], [278, 383, 26], [312, 213, 62],
			[632, 221, 26], [871, 263, 30], [1303, 370, 22], [1230, 598, 30], [1083, 503, 22], [1204, 801, 66],
			[1145, 382, 24], [579, 310, 26], [349, 489, 34], [486, 575, 16], [571, 417, 26], [770, 470, 125]]},
	{"name": "🕳 Black Hole", "image": "res://games/geometry_wars/map_blackhole.jpg", "size": Vector2(1672, 941), "first": 25,
		"nodes": [[67, 263, 28], [496, 55, 18], [792, 104, 20], [1202, 215, 26], [1491, 351, 18], [1598, 558, 56],
			[1194, 790, 30], [798, 811, 30], [371, 686, 42], [401, 407, 18], [172, 363, 56], [439, 239, 14],
			[734, 252, 14], [1134, 356, 14], [1025, 618, 18], [885, 447, 100]]},
]
## Smallest tap target around a star, in screen units.
const TAP_MIN := 30.0

var data: Dictionary = {}
var hardcore := false
var _drones_row: HBoxContainer
var _stars_label: Label
var _title: Label
var _map: Control
var _map_i := 0
var _map_name: Label
var _map_tex: Array = []
var _prev_btn: Button
var _next_btn: Button
var _pulse := 0.0
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
	if not (d.get("beaten") is Dictionary):
		# Before 2026-10-07 a boss level was only cleared by beating its boss.
		var beaten := {}
		for id in range(1, Levels.count() + 1):
			if Levels.is_boss(id) and (stars_of(d, id, false) > 0 or stars_of(d, id, true) > 0):
				beaten[str(id)] = true
		d["beaten"] = beaten
	if not d.has("drone"):
		d["drone"] = ""
	if not (d.get("fam") is Dictionary):
		d["fam"] = {}
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

static func boss_beaten(d: Dictionary, id: int) -> bool:
	return bool((d.beaten as Dictionary).get(str(id), false))

## Earned: the first boss beaten, and enough campaign stars.
static func drone_open(d: Dictionary, kind: String) -> bool:
	return boss_beaten(d, Levels.first_boss()) and total_stars(d, false) >= int(Drones.UNLOCK_STARS[kind])

static func open_familiars(d: Dictionary) -> Array:
	return Drones.KINDS.filter(func(k): return drone_open(d, k))

## The next familiar still to come, or "".
static func next_familiar(d: Dictionary) -> String:
	for k in Drones.KINDS:
		if not drone_open(d, k):
			return k
	return ""

## The familiar that flies with you ("" = none yet).
static func chosen_drone(d: Dictionary) -> String:
	var k := str(d.get("drone", ""))
	if k != "" and drone_open(d, k):
		return k
	var open := open_familiars(d)
	return str(open[0]) if not open.is_empty() else ""

static func mode_open(d: Dictionary, mode: String) -> bool:
	if not Levels.MODE_UNLOCK.has(mode):
		return true
	return boss_beaten(d, int(Levels.MODE_UNLOCK[mode]))

## A familiar's own record: {xp, up}.
static func fam_of(d: Dictionary, kind: String) -> Dictionary:
	var fam: Dictionary = d.fam
	if not (fam.get(kind) is Dictionary):
		fam[kind] = {"xp": 0, "up": {}}
	var f: Dictionary = fam[kind]
	if not (f.get("up") is Dictionary):
		f["up"] = {}
	return f

## Points for the next level of a stat, or -1 when it is maxed.
static func upgrade_cost(d: Dictionary, kind: String, stat: String) -> int:
	var lv := int(fam_of(d, kind).up.get(stat, 0))
	return -1 if lv >= Drones.MAX_LEVEL else int(Drones.UPGRADE_COST[lv])

static func upgrade(d: Dictionary, kind: String, stat: String) -> bool:
	var cost := upgrade_cost(d, kind, stat)
	var f := fam_of(d, kind)
	if cost < 0 or int(f.xp) < cost:
		return false
	f.xp = int(f.xp) - cost
	f.up[stat] = int(f.up.get(stat, 0)) + 1
	save_progress(d)
	return true

## A campaign level's score, won or lost, goes to the familiar that flew it.
static func add_points(d: Dictionary, score: int, drone: String) -> void:
	if drone == "":
		return
	var f := fam_of(d, drone)
	f.xp = int(f.xp) + maxi(score, 0)
	save_progress(d)

static func drones_open(d: Dictionary) -> int:
	return open_familiars(d).size()

## Picks the first familiar for you when one arrives and none was chosen.
static func _settle_drone(d: Dictionary) -> void:
	if str(d.get("drone", "")) == "" or not drone_open(d, str(d.drone)):
		d.drone = chosen_drone(d)

## Records a cleared level; returns the familiars its stars brought.
static func record(d: Dictionary, id: int, hard: bool, stars: int, score: int) -> Array:
	var before := open_familiars(d)
	var key := str(id)
	var sk := "hard" if hard else "stars"
	var bk := "hbest" if hard else "best"
	d[sk][key] = maxi(int(d[sk].get(key, 0)), stars)
	d[bk][key] = maxi(int(d[bk].get(key, 0)), score)
	_settle_drone(d)
	save_progress(d)
	return open_familiars(d).filter(func(k): return not k in before)

## A boss level's bosses are all beaten: returns what that opened,
## {modes: [...], familiars: [...]} (empty lists if it was beaten before).
static func beat_boss_level(d: Dictionary, id: int) -> Dictionary:
	var out := {"modes": [], "familiars": []}
	if boss_beaten(d, id):
		return out
	var before := open_familiars(d)
	d.beaten[str(id)] = true
	out.modes = Levels.modes_opened_by(id)
	out.familiars = open_familiars(d).filter(func(k): return not k in before)
	_settle_drone(d)
	save_progress(d)
	return out

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
	var back := HomeKit.neon_button("◀ " + tr("Home"), HomeKit.BUTTON, 22, 52)
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
		var tab := HomeKit.neon_button(tr("🗺 Campaign") if i == 0 else tr("💀 Cursed"), HomeKit.BUTTON, 20, 52)
		tab.toggle_mode = true
		tab.custom_minimum_size.x = 150
		tab.pressed.connect(_set_hardcore.bind(i == 1))
		top.add_child(tab)
		_tabs.append(tab)

	_drones_row = HBoxContainer.new()
	_drones_row.add_theme_constant_override("separation", 8)
	col.add_child(_drones_row)

	for m in MAPS:
		_map_tex.append(load(m.image) if ResourceLoader.exists(m.image) else null)
	_map = Control.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	col.add_child(_map)
	_map_name = HomeKit.label("", 24, HomeKit.WHITE, false, true)
	_map_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_map_name.add_theme_constant_override("outline_size", 8)
	_map_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(_map_name)
	_map_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_map_name.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_map_name.position.y = 6
	_prev_btn = HomeKit.neon_button("◀", HomeKit.BUTTON, 30, 70)
	_next_btn = HomeKit.neon_button("▶", HomeKit.BUTTON, 30, 70)
	for b in [_prev_btn, _next_btn]:
		b.custom_minimum_size.x = 64
		_map.add_child(b)
	_prev_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_next_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_next_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prev_btn.pressed.connect(_switch_map.bind(-1))
	_next_btn.pressed.connect(_switch_map.bind(1))

	_build_card()
	refresh()

func _process(delta: float) -> void:
	if visible and _map:
		_pulse = fmod(_pulse + delta, 1.2)
		_map.queue_redraw()

func open(hard: bool = false) -> void:
	data = load_progress()
	hardcore = hard
	visible = true
	_map_i = _map_of(_next_level())
	refresh()

func refresh() -> void:
	if _map == null:
		return
	data = load_progress() if data.is_empty() else data
	_title.text = tr("Cursed") if hardcore else tr("Campaign")
	_title.add_theme_color_override("font_color", HomeKit.PINK if hardcore else HomeKit.GOLD)
	var max_stars := Levels.count() * 3
	_stars_label.text = "★ %d / %d" % [total_stars(data, hardcore), max_stars]
	for i in _tabs.size():
		(_tabs[i] as Button).set_pressed_no_signal((i == 1) == hardcore)
	_build_drones()
	_map_name.text = tr(str(MAPS[_map_i].name))
	_prev_btn.visible = _map_i > 0
	_next_btn.visible = _map_i < MAPS.size() - 1
	_map.queue_redraw()

func _build_drones() -> void:
	for c in _drones_row.get_children():
		c.queue_free()
	if hardcore:
		var note := HomeKit.label(tr("💀 Cursed: no familiar, stars counted apart."), 22, HomeKit.PINK)
		_drones_row.add_child(note)
		return
	var lbl := HomeKit.label(tr("Familiar:"), 22, HomeKit.DIM)
	_drones_row.add_child(lbl)
	var open := open_familiars(data)
	var chosen := chosen_drone(data)
	for k in open:
		var b := HomeKit.neon_button(tr(str(Drones.LABELS[k])), HomeKit.BUTTON, 19, 48)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(chosen == k)
		b.tooltip_text = tr(str(Drones.DESCS[k]))
		b.pressed.connect(_pick_drone.bind(k))
		_drones_row.add_child(b)
	# What brings the next one: the first boss, then stars.
	var nxt := next_familiar(data)
	if nxt != "":
		var text := ""
		if not boss_beaten(data, Levels.first_boss()):
			text = tr("🔒 Beat the %s (level %d) for your first familiar") % [tr(Levels.boss_name(Levels.bosses_of(Levels.first_boss())[0][0])), Levels.first_boss()]
		else:
			text = "🔒 %s  ★ %d / %d" % [tr(str(Drones.LABELS[nxt])), total_stars(data, false), int(Drones.UNLOCK_STARS[nxt])]
		var hint := HomeKit.label(text, 20, HomeKit.GOLD)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_drones_row.add_child(hint)
	if not open.is_empty():
		var up := HomeKit.neon_button(tr("⬆ Upgrade"), HomeKit.GO, 19, 48)
		up.custom_minimum_size.x = 150
		up.pressed.connect(_show_upgrades)
		_drones_row.add_child(up)

func _pick_drone(kind: String) -> void:
	data.drone = kind
	save_progress(data)
	_build_drones()

# ---------- the star map ----------

## The next level to play: the first open one without a star (else the last).
func _next_level() -> int:
	for id in range(1, Levels.count() + 1):
		if is_open(data, id, hardcore) and stars_of(data, id, hardcore) == 0:
			return id
	return Levels.count()

func _map_of(id: int) -> int:
	var i := 0
	for m in MAPS.size():
		if id >= int(MAPS[m].first):
			i = m
	return i

func _switch_map(step: int) -> void:
	_map_i = clampi(_map_i + step, 0, MAPS.size() - 1)
	refresh()

## Where the picture sits (all of it shows) and its scale.
func _fit() -> Array:
	var ms: Vector2 = MAPS[_map_i].size
	var k := minf(_map.size.x / ms.x, _map.size.y / ms.y)
	var sz := ms * k
	return [Rect2((_map.size - sz) / 2.0, sz), k]

func _draw_map() -> void:
	var tex: Texture2D = _map_tex[_map_i]
	var fit := _fit()
	var r: Rect2 = fit[0]
	var k: float = fit[1]
	if tex:
		# The same picture, cropped to fill and dimmed, behind the whole map.
		var ms: Vector2 = MAPS[_map_i].size
		var kc := maxf(_map.size.x / ms.x, _map.size.y / ms.y)
		var cs := ms * kc
		_map.draw_texture_rect(tex, Rect2((_map.size - cs) / 2.0, cs), false, Color(0.3, 0.3, 0.36))
		_map.draw_texture_rect(tex, r, false)
	var nodes: Array = MAPS[_map_i].nodes
	var first: int = MAPS[_map_i].first
	var font := get_theme_default_font()
	var nxt := _next_level()
	# The path so far: a faint line through the levels already open.
	for i in range(1, nodes.size()):
		if is_open(data, first + i, hardcore):
			_map.draw_line(_node_pos(nodes[i - 1], r, k), _node_pos(nodes[i], r, k), Color(1, 0.95, 0.8, 0.35), 2.0, true)
	for i in nodes.size():
		var id := first + i
		var p := _node_pos(nodes[i], r, k)
		var rr := maxf(float(nodes[i][2]) * k, 10.0)
		var open := is_open(data, id, hardcore)
		var stars := stars_of(data, id, hardcore)
		var boss := Levels.is_boss(id)
		if not open:
			_map.draw_circle(p, rr * 1.05, Color(0, 0, 0, 0.6))
			_map.draw_arc(p, rr + 3.0, 0, TAU, 32, Color(0.6, 0.62, 0.7, 0.5), 1.5, true)
		else:
			var col := HomeKit.PINK if hardcore else (Color(1, 0.3, 0.38) if boss else HomeKit.BUTTON)
			if stars > 0:
				col = HomeKit.GO
			_map.draw_arc(p, rr + 4.0, 0, TAU, 40, Color(col, 0.9), 2.5, true)
			if id == nxt:
				var t := _pulse / 1.2
				_map.draw_arc(p, rr + 6.0 + t * 18.0, 0, TAU, 40, Color(1, 1, 1, 0.8 * (1.0 - t)), 2.5, true)
		var tag := ("☠ %d" if boss else "%d") % id
		var fs := 22 if boss else 20
		var at := p + Vector2(rr * 0.75 + 4.0, -rr * 0.75 - 2.0)
		if rr > 60.0:
			at = p + Vector2(-font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2.0, -rr - 8.0)
		var tcol := HomeKit.WHITE if open else Color(0.7, 0.72, 0.8, 0.8)
		_map.draw_string_outline(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.9))
		_map.draw_string(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)
		if open:
			var st := "★".repeat(stars) + "☆".repeat(3 - stars)
			var sw := font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var sp := p + Vector2(-sw / 2.0, rr + 20.0)
			_map.draw_string_outline(font, sp, st, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, 0.9))
			_map.draw_string(font, sp, st, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HomeKit.GOLD)

func _node_pos(n: Array, r: Rect2, k: float) -> Vector2:
	return r.position + Vector2(float(n[0]), float(n[1])) * k

## A tap on a star opens its card (mouse only: a phone's tap also arrives as a
## mouse click, so taking touches too would open it twice).
func _on_map_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		return
	var fit := _fit()
	var nodes: Array = MAPS[_map_i].nodes
	var best := -1
	var best_d := INF
	for i in nodes.size():
		var p := _node_pos(nodes[i], fit[0], fit[1])
		var reach := maxf(float(nodes[i][2]) * float(fit[1]) + 6.0, TAP_MIN)
		var d: float = p.distance_to(event.position)
		if d <= reach and d < best_d:
			best = i
			best_d = d
	if best < 0:
		return
	var id: int = int(MAPS[_map_i].first) + best
	if is_open(data, id, hardcore):
		_show_card(id)

func _set_hardcore(on: bool) -> void:
	hardcore = on
	_map_i = _map_of(_next_level())
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
		notes = tr("💀 Cursed: no familiar") + (" · " + notes if notes != "" else "")
	if notes != "":
		_card_box.add_child(HomeKit.label(notes, 20, HomeKit.DIM, true, true))
	var first := tr("Survive") if str(r.goal) == "survive" else tr("Finish")
	var st: Array = r.stars
	_card_box.add_child(HomeKit.label("★ %s   ·   ★★ %s   ·   ★★★ %s" % [first, _num(int(st[0])), _num(int(st[1]))], 22, HomeKit.GOLD, true, true))
	if str(r.goal) == "survive":
		_card_box.add_child(HomeKit.label(tr("When the clock runs out, keep going: every point counts for the stars"), 18, HomeKit.DIM, true, true))
	# A boss: what beating it opens.
	if Levels.is_boss(id):
		var names: PackedStringArray = []
		for bk in Levels.bosses_of(id):
			names.append(tr(Levels.boss_name(str(bk[0]))))
		if boss_beaten(data, id):
			_card_box.add_child(HomeKit.label(tr("☠ %s beaten ✔") % " + ".join(names), 22, HomeKit.LIME, true, true))
		else:
			var prizes: PackedStringArray = []
			for m in Levels.modes_opened_by(id):
				prizes.append(Levels.MODE_ICONS[m] + " " + tr(str(Levels.CLASSIC[m].title)))
			if id == Levels.first_boss():
				prizes.append(tr(str(Drones.LABELS["attack"])))
			var line := tr("☠ Beat %s") % " + ".join(names)
			if not prizes.is_empty():
				line += ": " + tr("unlocks %s") % ", ".join(prizes)
			_card_box.add_child(HomeKit.label(line, 22, Color(1, 0.45, 0.5), true, true))
	var best := int((data["hbest" if hardcore else "best"] as Dictionary).get(str(id), 0))
	if best > 0:
		_card_box.add_child(HomeKit.label(tr("Best: %s") % _num(best), 22, HomeKit.LIME, false, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card_box.add_child(row)
	var close := HomeKit.neon_button(tr("Close"), HomeKit.BUTTON, 24, 64)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(_close_card)
	row.add_child(close)
	var play := HomeKit.neon_button("▶  " + tr("Play"), HomeKit.GO, 28, 64)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(_on_play.bind(id))
	row.add_child(play)
	_card.visible = true

func _clear_card() -> void:
	for c in _card_box.get_children():
		c.queue_free()

func _card_title(text: String) -> void:
	var l := HomeKit.label(text, 36, HomeKit.WHITE, false, true)
	l.add_theme_color_override("font_outline_color", Color(HomeKit.BUTTON, 0.5))
	l.add_theme_constant_override("outline_size", 8)
	_card_box.add_child(l)

func _card_buttons(main: Button) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card_box.add_child(row)
	var close := HomeKit.neon_button(tr("Close"), HomeKit.BUTTON, 24, 60)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(_close_card)
	row.add_child(close)
	if main:
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(main)

func _close_card() -> void:
	_card.visible = false

## The chosen familiar's upgrades, paid from the points it earned itself.
func _show_upgrades() -> void:
	var kind := chosen_drone(data)
	if kind == "":
		return
	_clear_card()
	_card_title(tr(str(Drones.LABELS[kind])))
	var f := fam_of(data, kind)
	_card_box.add_child(HomeKit.label(tr("Points earned with it: %s") % _num(int(f.xp)), 24, HomeKit.GOLD, false, true))
	for st in Drones.STATS:
		var lv := int(f.up.get(st, 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_card_box.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(HomeKit.label(tr(str(Drones.STAT_LABELS[st])) + "   " + "●".repeat(lv) + "○".repeat(Drones.MAX_LEVEL - lv), 24, HomeKit.WHITE))
		col.add_child(HomeKit.label(tr(str(Drones.STAT_DESCS[st])), 18, HomeKit.DIM, true))
		var cost := upgrade_cost(data, kind, st)
		var b := HomeKit.neon_button(("⬆ " + _num(cost)) if cost >= 0 else tr("Max"), HomeKit.GO, 22, 56)
		b.custom_minimum_size.x = 170
		b.disabled = cost < 0 or int(f.xp) < cost
		b.pressed.connect(_on_upgrade.bind(kind, st))
		row.add_child(b)
	_card_buttons(null)
	_card.visible = true

func _on_upgrade(kind: String, stat: String) -> void:
	if upgrade(data, kind, stat):
		_show_upgrades()

func _on_play(id: int) -> void:
	_card.visible = false
	visible = false
	play_level.emit(id, hardcore, "" if hardcore else chosen_drone(data))

static func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
