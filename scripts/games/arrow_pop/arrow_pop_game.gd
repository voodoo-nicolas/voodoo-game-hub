extends Control

## Arrow Pop: tap an arrow, it flies the way it points and pops the bubbles of its own
## colour. It can never hit a bubble of another colour or another arrow: that bump costs a
## heart. Clear the board. 320 levels (arrow_pop_levels.gd), 3 hearts each, stars by hearts.

## Landing menu style: bento (docs/MENU_STYLES.md) -- not used by the last 2 games
## (Hesperia: rail, Mini Golf 3D: stickers, Wolf Pack: ghost).
const MenuStyles = preload("res://scripts/games/arrow_pop/menu_styles.gd")
const ApEngine = preload("res://scripts/games/arrow_pop/arrow_pop_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Landing + pause menu + neon look, copied into this game's folder by `hub.py sync`.
const HomeKit = preload("res://scripts/games/arrow_pop/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/arrow_pop/arrow_pop_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://arrow_pop_save.json"
const PROGRESS_PATH := "user://arrow_pop_progress.json"

const SPEED := 15.0  # cells per second
const POP_TIME := 0.35
## Look (STANDARDS §9): "classic" = glossy bubbles on a pale sky board (default);
## "voodoo" = neon rings on black. Set by the kit (Options → Look).
const CLASSIC_PAL := [Color("e5484d"), Color("3fbf5a"), Color("9a5be0"), Color("f39a2e"), Color("3a8ee8"), Color("f2c230")]
const NEON_PAL := [Color("ff3b5c"), Color("7dff3a"), Color("b04dff"), Color("ffae2b"), Color("29e6ff"), Color("fff23a")]
const CLASSIC_BG := Color("cfe8f3")
const CLASSIC_INK := Color("2b3a55")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var level: int = 1
var started := false
var finished := false
var progress := {"level": 1, "best": {}, "shapes": false}
var skin: String = "classic"

# Animation state (drawing only; the engine has already moved on).
var flights: Array = []     # {src, d, k, way, ok, block, bd, t, pops: {cell: index}}
var ghosts: Dictionary = {}  # cell -> colour: bubbles popped by a flight that hasn't reached them yet
var held: Dictionary = {}  # cell -> true: a bumping arrow, drawn by its flight instead
var pops_fx: Array = []      # {cell, k, t}
var shake: Dictionary = {}   # cell -> time left
var hint_cell := -1
var hint_t := 0.0

var bg: ColorRect
var board: Control
var level_label: Label
var hearts_label: Label
var bar: HBoxContainer
var win_dialog: Control
var lose_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/arrow_pop/arrow_pop_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = ApEngine.new()
	_load_progress()
	_build_ui()
	_deal(clampi(int(progress.level), 1, ApEngine.LEVEL_COUNT))
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 34)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(level_label)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	hearts_label = Label.new()
	hearts_label.add_theme_font_size_override("font_size", 40)
	hearts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hearts_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)
	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, 40)
	root.add_child(bottom)

	win_dialog = UI.build_dialog("", [
		{"text": tr("Next level"), "action": _next_level},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	lose_dialog = UI.build_dialog("", [
		{"text": tr("Try again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(lose_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): bento, own title font + bubble colours.
		"landing": "bento",
		"landing_style": MenuStyles,
		"title_font": "res://games/arrow_pop/title.ttf",
		"title_colors": [CLASSIC_PAL[0], CLASSIC_PAL[3], CLASSIC_PAL[5], CLASSIC_PAL[1], CLASSIC_PAL[4], CLASSIC_PAL[2]],
		"landing_colors": [Color("0d1830"), Color("1d3358")],
		"menu_color": Color("6fc8ff"),
		"menu_font": true,
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Fire each arrow at its own colour. Never hit another colour.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  Play", "sub": "320 levels", "key": "campaign", "color": HomeKit.CYAN, "action": _continue}],
		"extra": _add_options,
		"more": [["🗺 Levels", HomeKit.CYAN, _show_levels]],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [
			{"text": "💡 Hint", "how": "Lights up an arrow that is free to fire right now.", "action": _help_hint},
			{"text": "❤ Extra heart", "how": "Gives you one more heart on this level.", "action": _help_heart},
		],
		"board": "Total stars",
		"board_note": "Stars earned on all levels.",
	})
	add_child(home)
	if home.has_method("help_button"):
		var hb: Button = home.help_button("💡", _help_hint)
		hb.custom_minimum_size = Vector2(76, 64)
		bar.add_child(hb)
		bar.move_child(hb, 2)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.06)
	add_child(drawer)
	_apply_colors()

## The game's own picker on the setup screen.
func _add_options(box: VBoxContainer) -> void:
	box.add_child(home.section(tr("Color-blind shapes")))
	box.add_child(home.choice_row(["Off", "On"], 1 if progress.shapes else 0, _on_pick_shapes))

func _on_pick_shapes(i: int) -> void:
	progress.shapes = i == 1
	_save_progress()
	board.queue_redraw()

# ---------- progress ----------

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	if d is Dictionary:
		progress.level = clampi(int(d.get("level", 1)), 1, ApEngine.LEVEL_COUNT)
		progress.best = d.get("best", {}) if d.get("best", {}) is Dictionary else {}
		progress.shapes = bool(d.get("shapes", false))

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)

func _total_stars() -> int:
	var t := 0
	for k in progress.best:
		t += int(progress.best[k])
	return t

# ---------- game flow ----------

func _continue() -> void:
	SaveUtil.delete(SAVE_PATH)
	_deal(clampi(int(progress.level), 1, ApEngine.LEVEL_COUNT))

func _restart() -> void:
	_deal(level)

func _next_level() -> void:
	_deal(mini(level + 1, ApEngine.LEVEL_COUNT))

func _deal(n: int) -> void:
	level = clampi(n, 1, ApEngine.LEVEL_COUNT)
	engine.load_level(level)
	started = true
	finished = false
	flights.clear()
	ghosts.clear()
	held.clear()
	pops_fx.clear()
	shake.clear()
	hint_cell = -1
	win_dialog.visible = false
	lose_dialog.visible = false
	_render()

func _render() -> void:
	level_label.text = tr("Level %d") % level
	var lost: int = maxi(0, ApEngine.MAX_HEARTS - engine.hearts)
	hearts_label.text = " ".join(_hearts_list(engine.hearts, lost))
	board.queue_redraw()

func _hearts_list(full: int, lost: int) -> Array:
	var out: Array = []
	for i in full:
		out.append("❤")
	for i in lost:
		out.append("🤍")
	return out

func _on_board_input(event: InputEvent) -> void:
	# MouseButton only (phones send taps twice).
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if finished or not started:
		return
	var g := _geom()
	var p: Vector2 = (event.position - g.o) / g.cs
	if p.x < 0 or p.y < 0 or p.x >= engine.w or p.y >= engine.h:
		return
	var c: int = int(p.y) * engine.w + int(p.x)
	if engine.kind[c] != ApEngine.ARROW or held.has(c):
		return
	_fire(c)

func _fire(c: int) -> void:
	var k: int = engine.col[c]
	var d: int = engine.dir[c]
	var r: Dictionary = engine.fire(c)
	if hint_cell == c:
		hint_cell = -1
	var f := {"src": c, "d": d, "k": k, "way": r.way, "ok": r.ok, "block": r.block, "t": 0.0, "pops": {}}
	if r.ok:
		_sfx("pickup")
		for p in r.pops:
			f.pops[p] = r.way.find(p)
			ghosts[p] = k
		if info and not r.pops.is_empty():
			info.add("Bubbles popped", r.pops.size())
	else:
		_sfx("invalid")
		f.bd = float(r.way.find(r.block) + 1)
		held[c] = true
	flights.append(f)
	_render()
	if engine.lost():
		finished = true
		SaveUtil.delete(SAVE_PATH)
		_end_later(false)
	elif engine.won():
		finished = true
		SaveUtil.delete(SAVE_PATH)
		_end_later(true)

func _end_later(won: bool) -> void:
	var t := create_tween()
	t.tween_interval(0.75)
	t.tween_callback(_finish.bind(won))

func _finish(won: bool) -> void:
	if not finished:
		return
	if won:
		var st: int = engine.stars()
		var key := str(level)
		var had: int = int(progress.best.get(key, 0))
		progress.best[key] = maxi(had, st)
		if level >= int(progress.level):
			progress.level = mini(level + 1, ApEngine.LEVEL_COUNT)
		_save_progress()
		var msg := tr("Level %d cleared!") % level + "\n" + "★".repeat(st) + "☆".repeat(3 - st)
		if level == ApEngine.LEVEL_COUNT:
			msg += "\n" + tr("All %d levels cleared!") % ApEngine.LEVEL_COUNT
		if info:
			info.result("win")
			var threes := 0
			for k in progress.best:
				if int(progress.best[k]) >= 3:
					threes += 1
			info.high("Levels cleared", progress.best.size())
			info.high("Total stars", _total_stars())
			info.high("3-star levels", threes)
			info.high("Highest level", level)
			msg += "\n" + info.summary(["Levels cleared", "Total stars"])
		_sfx("win")
		win_dialog.get_meta("message_label").text = msg
		win_dialog.visible = true
	else:
		if info:
			info.result("loss")
		_sfx("lose")
		lose_dialog.get_meta("message_label").text = tr("Out of hearts!") + "\n" + tr("Level %d") % level
		lose_dialog.visible = true

# ---------- animation ----------

func _process(delta: float) -> void:
	var busy := false
	for f in flights.duplicate():
		busy = true
		f.t += delta
		var dist: float = f.t * SPEED
		if f.ok:
			for p in f.pops.keys():
				if dist >= float(f.pops[p]) + 1.0:
					ghosts.erase(p)
					pops_fx.append({"cell": p, "k": f.k, "t": 0.0})
					f.pops.erase(p)
					_sfx("pop")
			if dist > f.way.size() + 2.0:
				flights.erase(f)
		else:
			var reach: float = maxf(0.25, f.bd - 0.55)
			if dist >= reach and not f.has("hit"):
				f.hit = true
				shake[f.block] = 0.35
			if dist >= reach * 2.0:
				held.erase(f.src)
				flights.erase(f)
	for fx in pops_fx.duplicate():
		busy = true
		fx.t += delta
		if fx.t > POP_TIME:
			pops_fx.erase(fx)
	for c in shake.keys():
		busy = true
		shake[c] -= delta
		if shake[c] <= 0.0:
			shake.erase(c)
	if hint_cell >= 0:
		busy = true
		hint_t -= delta
		if hint_t <= 0.0:
			hint_cell = -1
	if busy:
		board.queue_redraw()

## Where a flight's arrow is now, in cells from its start.
func _flight_dist(f: Dictionary) -> float:
	var dist: float = f.t * SPEED
	if f.ok:
		return dist
	var reach: float = maxf(0.25, f.bd - 0.55)
	return dist if dist < reach else maxf(0.0, reach * 2.0 - dist)

# ---------- drawing ----------

func _geom() -> Dictionary:
	var cs: float = floor(minf((board.size.x - 28.0) / engine.w, (board.size.y - 12.0) / engine.h))
	cs = clampf(cs, 8.0, 150.0)
	var span := Vector2(cs * engine.w, cs * engine.h)
	return {"cs": cs, "o": ((board.size - span) / 2.0).floor()}

func _pal(k: int) -> Color:
	return CLASSIC_PAL[k % CLASSIC_PAL.size()] if skin == "classic" else NEON_PAL[k % NEON_PAL.size()]

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	_apply_colors()
	if board:
		board.queue_redraw()

func _apply_colors() -> void:
	if bg:
		bg.color = CLASSIC_BG if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	var ink: Color = CLASSIC_INK if skin == "classic" else HomeKit.WHITE
	for l in [level_label, hearts_label]:
		if l:
			l.add_theme_color_override("font_color", ink)
	if hearts_label:
		hearts_label.add_theme_color_override("font_color", Color("e5484d") if skin == "classic" else HomeKit.PINK)

func _draw_board() -> void:
	if engine.kind.is_empty():
		return
	var g := _geom()
	var cs: float = g.cs
	var classic := skin == "classic"
	var tile := StyleBoxFlat.new()
	tile.set_corner_radius_all(int(cs * 0.2))
	if not classic:
		tile.set_border_width_all(2)
	for i in engine.w * engine.h:
		var cell := Rect2(g.o + Vector2(i % engine.w, i / engine.w) * cs, Vector2(cs, cs)).grow(-cs * 0.05)
		var off := Vector2.ZERO
		if shake.has(i):
			off = Vector2(sin(shake[i] * 60.0) * cs * 0.08, 0)
		var kd: int = engine.kind[i]
		var showing_ghost := ghosts.has(i)
		var k: int = ghosts[i] if showing_ghost else engine.col[i]
		var filled := kd != ApEngine.EMPTY or showing_ghost
		# Tile.
		if classic:
			tile.bg_color = Color(1, 1, 1, 0.92) if filled else Color(1, 1, 1, 0.35)
			if kd == ApEngine.ARROW and not held.has(i):
				tile.bg_color = _pal(k).lerp(Color.WHITE, 0.8)
			tile.shadow_color = Color(0.2, 0.35, 0.5, 0.18) if filled else Color(0, 0, 0, 0)
			tile.shadow_size = 3
			tile.shadow_offset = Vector2(0, 3)
		else:
			tile.bg_color = Color(0.06, 0.07, 0.14, 0.9)
			tile.border_color = Color(_pal(k), 0.55) if kd == ApEngine.ARROW and not held.has(i) else Color(1, 1, 1, 0.08)
		if shake.has(i):
			tile.bg_color = tile.bg_color.lerp(Color("ff3b3b"), 0.45)
		tile.draw(board.get_canvas_item(), Rect2(cell.position + off, cell.size))
		var center := cell.get_center() + off
		if hint_cell == i:
			var a := 0.5 + 0.5 * sin(hint_t * 10.0)
			board.draw_arc(center, cs * 0.5, 0, TAU, 40, Color(Color("ffd84d"), 0.4 + 0.6 * a), maxf(3.0, cs * 0.07))
		if showing_ghost or kd == ApEngine.BUBBLE:
			_draw_bubble(center, cs * 0.37, k, 1.0)
		elif kd == ApEngine.ARROW and not held.has(i):
			_draw_arrow(center, cs, engine.dir[i], k)
	# Flying arrows on top.
	for f in flights:
		var start: Vector2 = g.o + (Vector2(f.src % engine.w, f.src / engine.w) + Vector2(0.5, 0.5)) * cs
		var v: Vector2 = Vector2(ApEngine.DIRS[f.d])
		_draw_arrow(start + v * _flight_dist(f) * cs, cs, f.d, f.k)
	for fx in pops_fx:
		var c: Vector2 = g.o + (Vector2(fx.cell % engine.w, fx.cell / engine.w) + Vector2(0.5, 0.5)) * cs
		var p: float = fx.t / POP_TIME
		var col: Color = _pal(fx.k)
		board.draw_arc(c, cs * (0.3 + 0.35 * p), 0, TAU, 32, Color(col, 1.0 - p), maxf(2.0, cs * 0.06 * (1.0 - p)))
		for j in 8:
			var ang := TAU * j / 8.0 + 0.3
			board.draw_circle(c + Vector2(cos(ang), sin(ang)) * cs * (0.25 + 0.45 * p), cs * 0.05 * (1.0 - p) + 1.0, Color(col.lightened(0.3), 1.0 - p))

func _draw_bubble(c: Vector2, r: float, k: int, a: float) -> void:
	var base: Color = _pal(k)
	if skin == "classic":
		board.draw_circle(c + Vector2(0, r * 0.1), r, Color(base.darkened(0.45), 0.35 * a))
		board.draw_circle(c, r, Color(base.darkened(0.12), a))
		board.draw_circle(c - Vector2(r, r) * 0.1, r * 0.82, Color(base, a))
		board.draw_circle(c - Vector2(r, r) * 0.2, r * 0.5, Color(base.lightened(0.18), a))
		board.draw_circle(c - Vector2(r * 0.38, r * 0.42), r * 0.2, Color(1, 1, 1, 0.6 * a))
	else:
		board.draw_circle(c, r, Color(base, 0.18 * a))
		board.draw_arc(c, r * 1.08, 0, TAU, 40, Color(base, 0.25 * a), r * 0.2)
		board.draw_arc(c, r, 0, TAU, 40, Color(base, a), maxf(2.0, r * 0.12))
		board.draw_circle(c - Vector2(r * 0.35, r * 0.4), r * 0.14, Color(1, 1, 1, 0.7 * a))
	if progress.shapes:
		_draw_mark(c, r * 0.32, k, Color(1, 1, 1, 0.9 * a) if skin == "classic" else Color(base.lightened(0.5), a))

## Arrow pointing up in a -0.5..0.5 cell, turned to `d`.
const ARROW_SHAPE := [Vector2(0, -0.40), Vector2(0.34, -0.02), Vector2(0.13, -0.02), Vector2(0.13, 0.38),
	Vector2(-0.13, 0.38), Vector2(-0.13, -0.02), Vector2(-0.34, -0.02)]

func _draw_arrow(c: Vector2, cs: float, d: int, k: int) -> void:
	var base: Color = _pal(k)
	var ang := d * PI / 2.0
	var pts := PackedVector2Array()
	for p in ARROW_SHAPE:
		pts.append(c + (p as Vector2).rotated(ang) * cs)
	if skin == "classic":
		var under := PackedVector2Array()
		for p in pts:
			under.append(p + Vector2(0, cs * 0.05))
		board.draw_colored_polygon(under, base.darkened(0.35))
		board.draw_colored_polygon(pts, base)
	else:
		board.draw_colored_polygon(pts, Color(base, 0.3))
		var loop := pts.duplicate()
		loop.append(pts[0])
		board.draw_polyline(loop, Color(base, 0.35), maxf(4.0, cs * 0.09))
		board.draw_polyline(loop, base, maxf(2.0, cs * 0.04))
	if progress.shapes:
		_draw_mark(c + Vector2(0, 0.17).rotated(ang) * cs, cs * 0.08, k, Color(1, 1, 1, 0.95))

## Colour-blind marks: dot, square, triangle, diamond, plus, ring.
func _draw_mark(c: Vector2, s: float, k: int, col: Color) -> void:
	match k % 6:
		0:
			board.draw_circle(c, s * 0.8, col)
		1:
			board.draw_rect(Rect2(c - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), col)
		2:
			board.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), col)
		3:
			board.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)
		4:
			board.draw_rect(Rect2(c - Vector2(s, s * 0.3), Vector2(s * 2, s * 0.6)), col)
			board.draw_rect(Rect2(c - Vector2(s * 0.3, s), Vector2(s * 0.6, s * 2)), col)
		_:
			board.draw_arc(c, s * 0.75, 0, TAU, 20, col, maxf(1.5, s * 0.4))

func _draw_home_logo(c: Control) -> void:
	var cs := minf(c.size.y / 3.4, 46.0)
	var o := c.size / 2.0 - Vector2(cs * 1.5, cs * 1.5)
	var layout := [[1, 0, 0], [1, 1, -1], [2, 2, 0], [1, 3, -1], [1, 3, -1], [2, 3, 0], [1, 2, -1], [2, 0, 3], [1, 1, -1]]
	for i in 9:
		var cc: Vector2 = o + (Vector2(i % 3, i / 3) + Vector2(0.5, 0.5)) * cs
		var k: int = layout[i][1]
		var col: Color = NEON_PAL[k]
		if layout[i][0] == 1:
			c.draw_circle(cc, cs * 0.34, Color(col, 0.2))
			c.draw_arc(cc, cs * 0.34, 0, TAU, 32, col, 3.0)
		else:
			var pts := PackedVector2Array()
			for p in ARROW_SHAPE:
				pts.append(cc + (p as Vector2).rotated(layout[i][2] * PI / 2.0) * cs)
			c.draw_colored_polygon(pts, Color(col, 0.75))

# ---------- level map ----------

## 🗺 Every level in groups of 40: stars earned, the next one to play, the rest locked.
func _show_levels() -> void:
	var parts: Array = home._overlay(tr("🗺 Levels"), HomeKit.CYAN, true)
	parts[0].visible = true
	var body: VBoxContainer = parts[1]
	body.add_child(home._row(tr("Levels cleared"), "%d / %d" % [progress.best.size(), ApEngine.LEVEL_COUNT], HomeKit.WHITE, HomeKit.LIME, true))
	body.add_child(home._row(tr("Stars"), "%d ★" % _total_stars(), HomeKit.WHITE, HomeKit.GOLD))
	var last: int = mini(ApEngine.LEVEL_COUNT, int(progress.level) + 14)
	last += (5 - last % 5) % 5
	last = mini(last, ApEngine.LEVEL_COUNT)
	var a := 1
	while a <= last:
		var b: int = mini(a + 39, last)
		body.add_child(home._section(tr("Levels %d–%d") % [a, b]))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		body.add_child(grid)
		for n in range(a, b + 1):
			grid.add_child(_level_cell(n))
		a += 40

func _level_cell(n: int) -> Button:
	var key := str(n)
	var done: bool = progress.best.has(key)
	var open: bool = n <= int(progress.level)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var second := "🔒"
	if done:
		var st := int(progress.best[key])
		second = "★".repeat(st) + "☆".repeat(3 - st)
	elif open:
		second = "▶"
	b.text = "%d\n%s" % [n, second]
	b.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = HomeKit.CYAN if open else Color(1, 1, 1, 0.15)
	sb.bg_color = Color(HomeKit.CYAN, 0.30) if n == int(progress.level) else (Color(0.1, 0.2, 0.35, 0.9) if done else Color(0.05, 0.08, 0.15, 0.9))
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.disabled = not open
	b.pressed.connect(_play_level.bind(n))
	return b

func _play_level(n: int) -> void:
	home.start_mode({"text": "Play", "key": "campaign", "action": _play_from_grid.bind(n)})

func _play_from_grid(n: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_deal(n)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	win_dialog.visible = false
	lose_dialog.visible = false
	home.go_home()

func _save_game() -> void:
	if not started or finished:
		return
	SaveUtil.write(SAVE_PATH, engine.to_dict())

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary):
		return ""
	return tr("Level %d") % int(d.get("level", 1)) + "   ·   " + "❤".repeat(clampi(int(d.get("hearts", 3)), 0, 6))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	_deal(int(d.get("level", progress.level)) if d is Dictionary else int(progress.level))
	if d is Dictionary and engine.from_dict(d):
		level = engine.level_no
		_render()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

# ---------- helps (STANDARDS §17) ----------

## 💡 help: light up an arrow that is free to fire.
func _help_hint() -> bool:
	if not started or finished:
		return false
	var free: Array = engine.free_arrows()
	for c in held:
		free.erase(c)
	if free.is_empty():
		return false
	hint_cell = free[0]
	hint_t = 3.0
	board.queue_redraw()
	return true

## ❤ help: one more heart on this level.
func _help_heart() -> bool:
	if not started or finished or engine.hearts >= ApEngine.MAX_HEARTS + 3:
		return false
	engine.hearts += 1  # stars still count the bumps
	_sfx("powerup")
	_render()
	return true
