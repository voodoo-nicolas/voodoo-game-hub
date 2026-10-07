extends Control

## Crypt Crawler: a first-person crawl through neon crypts. Walk with the
## pad (or drag on the view to turn), blast skulls and wraiths with the
## wand, find the glowing exit on every floor.

const CcEngine = preload("res://scripts/games/crypt_crawler/crypt_crawler_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/crypt_crawler/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/crypt_crawler/crypt_crawler_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://crypt_crawler_save.json"

const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const COLS := 120
const WALL_X := Color("9b4dff")
const WALL_Y := Color("3a8cff")
const SKULL := Color("ff2bd6")
const WRAITH := Color("29e6ff")
const BRUTE := Color("ff4f9a")
const EXIT := Color("7dff3a")
const BOLT := Color("ffae2b")
const PAUSE_AFTER := 1.8
const DRAG_TURN := 0.0065

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var held: Dictionary = {}
var drag_turn: float = 0.0
var after: float = 0.0
var banner := ""
var flash_t: float = 0.0
var walk_t: float = 0.0
var zbuf: PackedFloat32Array = PackedFloat32Array()
var view_drag_index: int = -2

var view: Control
var score_label: Label
var hud_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/crypt_crawler/crypt_crawler_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = CcEngine.new()
	engine.reset(1)
	zbuf.resize(COLS)
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	hud_label = Label.new()
	hud_label.custom_minimum_size = Vector2(170, 64)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(hud_label)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 38)
	score_label.add_theme_color_override("font_color", EXIT.lerp(Color.WHITE, 0.6))
	score_label.add_theme_color_override("font_outline_color", Color(EXIT, 0.45))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	bar.add_child(spacer)

	var vm := MarginContainer.new()
	vm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vm.add_theme_constant_override("margin_left", 8)
	vm.add_theme_constant_override("margin_right", 8)
	root.add_child(vm)
	view = Control.new()
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.draw.connect(_draw_view)
	view.gui_input.connect(_on_view_input)
	vm.add_child(view)

	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 28)
	cm.add_theme_constant_override("margin_top", 4)
	cm.add_theme_constant_override("margin_left", 12)
	cm.add_theme_constant_override("margin_right", 12)
	root.add_child(cm)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 20)
	cm.add_child(controls)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 8)
	pad.add_theme_constant_override("v_separation", 8)
	controls.add_child(pad)
	for spec in [["⟲", "tl"], ["▲", "fw"], ["⟳", "tr"], ["◀", "sl"], ["▼", "bk"], ["▶", "sr"]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(100, 88)
		b.add_theme_font_size_override("font_size", 40)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "")
		b.button_down.connect(_hold.bind(spec[1], true))
		b.button_up.connect(_hold.bind(spec[1], false))
		pad.add_child(b)
	var fire := Button.new()
	fire.text = "✴\n" + tr("Fire")
	fire.custom_minimum_size = Vector2(190, 184)
	fire.add_theme_font_size_override("font_size", 32)
	fire.focus_mode = Control.FOCUS_NONE
	fire.set_meta("sfx", "")
	HomeKit.style_button(fire, BOLT)
	fire.button_down.connect(_hold.bind("fire", true))
	fire.button_up.connect(_hold.bind("fire", false))
	controls.add_child(fire)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in DIFF_NAMES.size():
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "row": "diff",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": WALL_X,
		"solo_heading": "Descend",
		"subtitle": "Down into the crypts. Blast the dead, find the way out.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.05)  # beside the score, above the view
	add_child(drawer)

func _hold(key: String, on: bool) -> void:
	if on:
		held[key] = true
	else:
		held.erase(key)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var map := {KEY_W: "fw", KEY_UP: "fw", KEY_S: "bk", KEY_DOWN: "bk", KEY_A: "sl", KEY_D: "sr",
			KEY_LEFT: "tl", KEY_RIGHT: "tr", KEY_Q: "tl", KEY_E: "tr", KEY_SPACE: "fire"}
		if map.has(event.keycode):
			_hold(map[event.keycode], event.pressed)

## Dragging sideways on the 3D view turns; a tap on it fires.
func _on_view_input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventScreenTouch:
		view_drag_index = event.index if event.pressed else -2
	elif event is InputEventScreenDrag:
		drag_turn += event.relative.x * DRAG_TURN
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and view_drag_index == -2:
		drag_turn += event.relative.x * DRAG_TURN

# ---------- game flow ----------

func _new_game(d: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset(d)
	_begin()

func _restart() -> void:
	_new_game(engine.diff)

func _begin() -> void:
	started = true
	after = 0.0
	banner = ""
	held.clear()
	end_dialog.visible = false
	_update_hud()

func _update_hud() -> void:
	score_label.text = str(engine.score)
	hud_label.text = tr("Floor %d") % engine.level + "\n♥ %d" % engine.hp
	hud_label.add_theme_color_override("font_color", HomeKit.WHITE if engine.hp > 30 else BRUTE)

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	flash_t = maxf(0.0, flash_t - delta)
	if after > 0.0:
		after -= delta
		if after <= 0.0:
			engine.next()
			banner = ""
			if engine.state == "over":
				_game_over()
				return
			if info and engine.state == "play":
				info.high("Deepest floor", engine.level)
			_update_hud()
		view.queue_redraw()
		return
	var fwd := (1.0 if held.has("fw") else 0.0) - (1.0 if held.has("bk") else 0.0)
	var strafe := (1.0 if held.has("sr") else 0.0) - (1.0 if held.has("sl") else 0.0)
	var turn := ((1.0 if held.has("tr") else 0.0) - (1.0 if held.has("tl") else 0.0)) * CcEngine.TURN * delta + drag_turn
	drag_turn = 0.0
	if fwd != 0.0 or strafe != 0.0:
		walk_t += delta
	var ev: Array = engine.step(delta, fwd, strafe, turn, held.has("fire"))
	for e in ev:
		match e:
			"fire":
				flash_t = 0.12
				_sfx("shoot")
			"hit_monster":
				_sfx("hit")
			"kill":
				_sfx("explode")
				if info:
					info.add("Monsters destroyed")
			"hurt":
				_sfx("hit")
				_buzz()
			"health":
				_sfx("powerup")
			"gem":
				_sfx("pickup")
				if info:
					info.add("Soul gems")
			"exit":
				_sfx("win")
				banner = tr("Way out! Floor %d cleared") % engine.level
				after = PAUSE_AFTER
				if info:
					info.add("Floors cleared")
			"dead":
				_sfx("lose")
				banner = tr("The crypt claims you…")
				after = PAUSE_AFTER
	if not ev.is_empty():
		_update_hud()
	view.queue_redraw()

func _game_over() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("You fell on floor %d.") % engine.level + "\n" + tr("Score: %d") % engine.score + "   ·   " + tr("Kills: %d") % engine.kills
	if info:
		info.add("Games played")
		info.high("Deepest floor", engine.level)
		info.high("Best score (%s)" % DIFF_NAMES[engine.diff], engine.score)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- the 3D view ----------

func _draw_view() -> void:
	var c := view
	var s := view.size
	if s.x < 10:
		return
	var horizon := s.y * 0.5 + sin(walk_t * 9.0) * 3.0
	# Ceiling and floor: dark, with faint bands that fade into the distance.
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(s.x, horizon)), Color(0.015, 0.008, 0.035))
	c.draw_rect(Rect2(Vector2(0, horizon), Vector2(s.x, s.y - horizon)), Color(0.025, 0.012, 0.05))
	var phase := fmod(walk_t * 2.6, 1.0)
	for i in 8:
		var d := 1.0 + i - phase
		var y := horizon + s.y / (2.0 * d) * 0.95
		c.draw_line(Vector2(0, y), Vector2(s.x, y), Color(WALL_X, 0.16 / (1.0 + i * 0.4)), 1.5)
		c.draw_line(Vector2(0, 2.0 * horizon - y), Vector2(s.x, 2.0 * horizon - y), Color(WALL_Y, 0.08 / (1.0 + i * 0.4)), 1.0)
	# Walls, one ray per column.
	var dir: Vector2 = engine.dir()
	var pl: Vector2 = engine.plane()
	var cw := s.x / COLS
	var tops := PackedVector2Array()
	var bots := PackedVector2Array()
	var prev: Dictionary = {}
	var seg_col := WALL_X
	var seg_d := 1.0
	for i in COLS:
		var camx := 2.0 * (i + 0.5) / COLS - 1.0
		var hit: Dictionary = engine.cast(engine.pos, dir + pl * camx, 40.0)
		var dist: float = hit.dist
		zbuf[i] = dist
		var h := s.y / dist
		var top := horizon - h / 2.0
		var bot := horizon + h / 2.0
		var col: Color = WALL_X if hit.side == 0 else WALL_Y
		var fade := clampf(1.15 - dist / 11.0, 0.08, 1.0)
		var x0 := i * cw
		c.draw_rect(Rect2(x0, top, cw + 0.6, h), Color(0.02, 0.012, 0.045).lerp(col.darkened(0.62), 0.55 * fade + 0.1))
		var new_face: bool = prev.is_empty() or prev.cell != hit.cell or prev.side != hit.side
		if new_face and not prev.is_empty():
			# A corner: close the run of edges, and stand a glowing post on the nearer face.
			_flush_edges(c, tops, bots, seg_col, seg_d)
			var px := x0
			var nearer: float = minf(prev.dist, dist)
			var ph := s.y / nearer
			HomeKit.glow_line(c, Vector2(px, horizon - ph / 2.0), Vector2(px, horizon + ph / 2.0), Color(col, clampf(1.15 - nearer / 11.0, 0.08, 1.0)), 1.5)
			tops = PackedVector2Array()
			bots = PackedVector2Array()
		if tops.is_empty():
			tops.append(Vector2(x0, top))
			bots.append(Vector2(x0, bot))
		tops.append(Vector2(x0 + cw, top))
		bots.append(Vector2(x0 + cw, bot))
		seg_col = col
		seg_d = dist
		prev = hit
	_flush_edges(c, tops, bots, seg_col, seg_d)
	_draw_sprites(c, s, horizon, dir, pl, cw)
	_draw_wand(c, s)
	if engine.hurt_t > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.0, 0.2, engine.hurt_t * 0.8))
	_draw_minimap(c, s)
	if banner != "":
		HomeKit.glow_text(c, Vector2(s.x / 2.0, s.y * 0.3), banner, int(clampf(s.x / 18.0, 22, 40)), EXIT if engine.state == "won" else SKULL)

func _flush_edges(c: CanvasItem, tops: PackedVector2Array, bots: PackedVector2Array, col: Color, dist: float) -> void:
	if tops.size() < 2:
		return
	var a := clampf(1.15 - dist / 11.0, 0.08, 1.0)
	HomeKit.glow_polyline(c, tops, Color(col, a), 1.8)
	HomeKit.glow_polyline(c, bots, Color(col, a), 1.8)

## Monsters, items, bolts and the exit, far to near, hidden behind walls.
func _draw_sprites(c: CanvasItem, s: Vector2, horizon: float, dir: Vector2, pl: Vector2, cw: float) -> void:
	var list: Array = []
	for m in engine.monsters:
		list.append({"pos": m.pos, "kind": m.kind, "m": m})
	for it in engine.items:
		list.append({"pos": it.pos, "kind": it.kind})
	for b in engine.bolts:
		list.append({"pos": b.pos, "kind": "bolt"})
	list.append({"pos": Vector2(engine.exit_cell) + Vector2(0.5, 0.5), "kind": "exit"})
	var inv := 1.0 / (pl.x * dir.y - dir.x * pl.y)
	for e in list:
		var rel: Vector2 = e.pos - engine.pos
		e.tx = inv * (dir.y * rel.x - dir.x * rel.y)
		e.ty = inv * (-pl.y * rel.x + pl.x * rel.y)
	list.sort_custom(func(a, b): return a.ty > b.ty)
	var t := Time.get_ticks_msec() / 1000.0
	for e in list:
		var depth: float = e.ty
		if depth < 0.15:
			continue
		var sx: float = s.x / 2.0 * (1.0 + e.tx / depth)
		var sz: float = s.y / depth
		var col_i := int(sx / cw)
		var visible := false
		for k in [col_i - 2, col_i, col_i + 2]:
			if k >= 0 and k < COLS and zbuf[k] > depth:
				visible = true
		if not visible:
			continue
		var fade := clampf(1.2 - depth / 12.0, 0.15, 1.0)
		match e.kind:
			"skull", "wraith", "brute":
				_draw_monster(c, Vector2(sx, horizon), sz, e.m, fade)
			"health":
				var p := Vector2(sx, horizon + sz * 0.32)
				var r := sz * 0.09
				HomeKit.glow_line(c, p - Vector2(r, 0), p + Vector2(r, 0), Color(EXIT, fade), maxf(2.0, r * 0.5))
				HomeKit.glow_line(c, p - Vector2(0, r), p + Vector2(0, r), Color(EXIT, fade), maxf(2.0, r * 0.5))
			"gem":
				var p := Vector2(sx, horizon + sz * (0.22 + sin(t * 3.0 + sx) * 0.03))
				var r := sz * 0.08
				var pts := PackedVector2Array([p + Vector2(0, -r * 1.3), p + Vector2(r, 0), p + Vector2(0, r * 1.3), p + Vector2(-r, 0)])
				c.draw_colored_polygon(pts, Color(BOLT, 0.3 * fade))
				HomeKit.glow_polyline(c, pts, Color(BOLT, fade), 1.6, true)
			"bolt":
				var p := Vector2(sx, horizon)
				c.draw_circle(p, sz * 0.06, Color(1, 1, 1, fade))
				HomeKit.glow_circle(c, p, sz * 0.08, Color(BOLT, fade), 2.0, 0.4)
			"exit":
				var p := Vector2(sx, horizon + sz * 0.05)
				for k in 3:
					var rr := sz * (0.18 + 0.07 * k + 0.02 * sin(t * 4.0 + k))
					c.draw_arc(p, rr, t * (1.5 + k) , t * (1.5 + k) + TAU * 0.75, 32, Color(EXIT, fade * (1.0 - k * 0.25)), maxf(1.5, sz * 0.012), true)
				c.draw_circle(p, sz * 0.12, Color(EXIT, 0.15 * fade))

func _draw_monster(c: CanvasItem, base: Vector2, sz: float, m: Dictionary, fade: float) -> void:
	var col: Color = SKULL if m.kind == "skull" else (WRAITH if m.kind == "wraith" else BRUTE)
	if m.hurt > 0.0:
		col = Color.WHITE
	col = Color(col, fade)
	var w := maxf(1.5, sz * 0.012)
	match m.kind:
		"skull":
			var p := base + Vector2(0, sin(m.bob) * sz * 0.05 - sz * 0.02)
			var r := sz * 0.13
			c.draw_circle(p, r, Color(col.darkened(0.7), 0.6 * fade))
			HomeKit.glow_circle(c, p, r, col, w)
			for sd in [-1, 1]:
				c.draw_circle(p + Vector2(sd * r * 0.4, -r * 0.05), r * 0.24, Color(0, 0, 0, 0.9))
				c.draw_circle(p + Vector2(sd * r * 0.4, -r * 0.05), r * 0.09, Color(1, 0.3, 0.4, fade))
			var jaw := PackedVector2Array([p + Vector2(-r * 0.55, r * 0.6), p + Vector2(-r * 0.45, r * 1.15), p + Vector2(r * 0.45, r * 1.15), p + Vector2(r * 0.55, r * 0.6)])
			HomeKit.glow_polyline(c, jaw, col, w)
			for k in 4:
				var x := -r * 0.3 + k * r * 0.2
				c.draw_line(p + Vector2(x, r * 0.75), p + Vector2(x, r * 1.1), col, w * 0.7)
		"wraith":
			var p := base + Vector2(0, sin(m.bob) * sz * 0.04 - sz * 0.05)
			var r := sz * 0.15
			var pts := PackedVector2Array()
			for k in 9:
				var a := PI + PI * k / 8.0
				pts.append(p + Vector2(cos(a) * r, sin(a) * r))
			for k in 7:
				var x := r - k * (2.0 * r / 6.0)
				pts.append(p + Vector2(x, r * 1.9 + sin(m.bob * 2.0 + k * 1.3) * r * 0.18 * (1 if k % 2 == 0 else -1)))
			c.draw_colored_polygon(pts, Color(col.darkened(0.6), 0.45 * fade))
			HomeKit.glow_polyline(c, pts, col, w, true)
			for sd in [-1, 1]:
				c.draw_circle(p + Vector2(sd * r * 0.35, r * 0.1), r * 0.13, Color(1, 1, 1, fade))
		"brute":
			var p := base + Vector2(0, sz * 0.02)
			var r := sz * 0.2
			var body := PackedVector2Array([p + Vector2(-r, -r * 0.6), p + Vector2(r, -r * 0.6), p + Vector2(r * 0.8, r * 1.7), p + Vector2(-r * 0.8, r * 1.7)])
			c.draw_colored_polygon(body, Color(col.darkened(0.7), 0.6 * fade))
			HomeKit.glow_polyline(c, body, col, w, true)
			var head := p + Vector2(0, -r * 1.0)
			HomeKit.glow_circle(c, head, r * 0.5, col, w)
			for sd in [-1, 1]:
				HomeKit.glow_polyline(c, PackedVector2Array([head + Vector2(sd * r * 0.4, -r * 0.3), head + Vector2(sd * r * 0.9, -r * 0.95), head + Vector2(sd * r * 0.55, -r * 0.15)]), col, w)
				c.draw_circle(head + Vector2(sd * r * 0.18, 0), r * 0.09, Color(1, 0.8, 0.2, fade))

func _draw_wand(c: CanvasItem, s: Vector2) -> void:
	var bob := Vector2(sin(walk_t * 5.0) * 8.0, absf(cos(walk_t * 5.0)) * 6.0)
	var kick := flash_t * 160.0
	var base := Vector2(s.x * 0.62, s.y + 10.0) + bob + Vector2(0, kick * 0.3)
	var tip := Vector2(s.x * 0.53, s.y * 0.76) + bob + Vector2(0, kick * 0.2)
	HomeKit.glow_line(c, base, tip, HomeKit.PURPLE, 6.0)
	HomeKit.glow_circle(c, tip, 14.0, BOLT if flash_t > 0.0 else HomeKit.PURPLE, 2.0, 0.3)
	for sd in [-1, 1]:
		c.draw_line(tip + Vector2(sd * 5, -2), tip + Vector2(sd * 5 + 3 * sd, 2), HomeKit.WHITE, 1.5)
	if flash_t > 0.0:
		var mid := Vector2(s.x / 2.0, s.y / 2.0)
		HomeKit.glow_line(c, tip, mid, BOLT, 3.0)
		c.draw_circle(mid, 10.0, Color(1, 1, 1, 0.8))
	# Crosshair.
	var m := Vector2(s.x / 2.0, s.y / 2.0)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		c.draw_line(m + d * 6.0, m + d * 14.0, Color(1, 1, 1, 0.55), 2.0)

func _draw_minimap(c: CanvasItem, s: Vector2) -> void:
	var n: int = engine.size
	var cell := minf(s.x * 0.3, 190.0) / n
	var o := Vector2(10, 10)
	c.draw_rect(Rect2(o, Vector2(n, n) * cell), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(o, Vector2(n, n) * cell), Color(WALL_X, 0.35), false, 1.5)
	for y in n:
		for x in n:
			if engine.seen[y * n + x] == 0:
				continue
			var r := Rect2(o + Vector2(x, y) * cell, Vector2(cell, cell))
			if engine.is_wall(x, y):
				c.draw_rect(r, Color(WALL_X, 0.55))
			elif Vector2i(x, y) == engine.exit_cell:
				c.draw_rect(r, EXIT)
			else:
				c.draw_rect(r, Color(1, 1, 1, 0.06))
	var p: Vector2 = o + engine.pos * cell
	c.draw_circle(p, maxf(2.5, cell * 0.45), WRAITH)
	c.draw_line(p, p + engine.dir() * cell * 2.0, WRAITH, 2.0)

func _draw_home_logo(c: Control) -> void:
	var s := c.size
	var o := s / 2.0
	var k := minf(s.y / 160.0, 1.4)
	# A corridor in perspective with a skull at the end.
	var near := Vector2(150, 75) * k
	var far := Vector2(40, 20) * k
	for sd in [-1.0, 1.0]:
		HomeKit.glow_line(c, o + Vector2(sd * near.x, -near.y), o + Vector2(sd * far.x, -far.y), WALL_X, 2.0)
		HomeKit.glow_line(c, o + Vector2(sd * near.x, near.y), o + Vector2(sd * far.x, far.y), WALL_X, 2.0)
		HomeKit.glow_line(c, o + Vector2(sd * far.x, -far.y), o + Vector2(sd * far.x, far.y), WALL_Y, 2.0)
		for t in [0.35, 0.65]:
			var a := (o + Vector2(sd * near.x, -near.y)).lerp(o + Vector2(sd * far.x, -far.y), t)
			var b := (o + Vector2(sd * near.x, near.y)).lerp(o + Vector2(sd * far.x, far.y), t)
			HomeKit.glow_line(c, a, b, Color(WALL_Y, 0.7), 1.4)
	HomeKit.glow_line(c, o + Vector2(-far.x, -far.y), o + Vector2(far.x, -far.y), WALL_Y, 1.6)
	HomeKit.glow_line(c, o + Vector2(-far.x, far.y), o + Vector2(far.x, far.y), WALL_Y, 1.6)
	_draw_monster(c, o + Vector2(0, -6 * k), 150.0 * k, {"kind": "skull", "hurt": 0.0, "bob": 0.0}, 1.0)

# ---------- pause / save ----------

func _on_pause() -> void:
	held.clear()
	home.pause()

func _go_home() -> void:
	home.go_home()

## Floor, score, health and kills; Resume starts that floor afresh.
func _save_game() -> void:
	if not started or engine.state == "over" or engine.state == "dead":
		return
	var lvl: int = engine.level + (1 if engine.state == "won" else 0)
	SaveUtil.write(SAVE_PATH, {"level": lvl, "score": engine.score, "hp": engine.hp, "kills": engine.kills, "diff": engine.diff})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Floor %d") % int(d.get("level", 1)) + "   ·   " + tr("Score: %d") % int(d.get("score", 0))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_new_game(1)
		return
	engine.reset(int(d.get("diff", 1)))
	engine.level = maxi(1, int(d.get("level", 1)))
	engine.score = int(d.get("score", 0))
	engine.kills = int(d.get("kills", 0))
	engine.new_level()
	engine.hp = clampi(int(d.get("hp", 100)), 1, CcEngine.MAX_HP)
	_begin()

func _buzz() -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(40)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
