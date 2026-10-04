extends Control

## City Defense: tap the sky to burst interceptors in the path of falling
## missiles. Protect the six cities as long as you can.

const CdEngine = preload("res://scripts/games/city_defense/city_defense_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/city_defense/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/city_defense/city_defense_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://city_defense_save.json"

const ENEMY := Color("ff2bd6")
const MINE := Color("29e6ff")
const CITY := Color("7dff3a")
const BASE := Color("ffae2b")
const BREAK_TIME := 2.6

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var break_left: float = 0.0
var banner := ""
var stars: Array = []

var field: Control
var score_label: Label
var hud_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/city_defense/city_defense_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = CdEngine.new()
	_build_ui()
	var r := RandomNumberGenerator.new()
	for i in 60:
		stars.append([Vector2(r.randf(), r.randf() * 0.8), r.randf_range(0.5, 1.5)])

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
	hud_label.custom_minimum_size = Vector2(150, 64)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(hud_label)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 38)
	score_label.add_theme_color_override("font_color", MINE.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(MINE, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	bar.add_child(spacer)

	var fm := MarginContainer.new()
	fm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fm.add_theme_constant_override("margin_left", 8)
	fm.add_theme_constant_override("margin_right", 8)
	fm.add_theme_constant_override("margin_bottom", 16)
	root.add_child(fm)
	field = Control.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	field.resized.connect(_on_field_resized)
	fm.add_child(field)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": MINE,
		"subtitle": "Tap the sky to stop the missiles. Save the cities.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  " + tr("Play"), "sub": "6 cities · 3 bases · endless waves", "action": _new_game}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _new_game,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.05)  # right of the score, above the field
	add_child(drawer)

func _on_field_resized() -> void:
	if field.size.x > 0.0:
		engine.resize(field.size)
	field.queue_redraw()

# ---------- game flow ----------

func _new_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset(field.size if field.size.x > 0 else Vector2(704, 1000))
	started = true
	break_left = -1.5  # show "Wave 1" for a moment
	banner = tr("Wave %d") % engine.wave
	end_dialog.visible = false
	_update_hud()

func _update_hud() -> void:
	score_label.text = str(engine.score)
	hud_label.text = tr("Wave %d") % engine.wave + "\n" + "🏙".repeat(engine.cities_left()) + ("  +%d" % engine.spare_cities if engine.spare_cities > 0 else "")

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and started:
		if engine.fire(event.position):
			_sfx("shoot")
		elif not engine.between:
			_sfx("invalid")

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	if engine.between:
		break_left -= delta
		if break_left <= 0.0:
			engine.start_wave()
			banner = tr("Wave %d") % engine.wave
			break_left = -1.2
			_update_hud()
		field.queue_redraw()
		return
	if break_left < 0.0:
		break_left = minf(0.0, break_left + delta)
		if break_left == 0.0:
			banner = ""
	var ev: Array = engine.step(delta)
	for e in ev:
		match e[0]:
			"boom":
				_sfx("explode")
			"kill":
				_sfx("hit")
			"city", "base":
				_sfx("lose")
			"city_back":
				_sfx("record")
			"wave_done":
				_sfx("powerup")
				banner = tr("Wave %d cleared!") % engine.wave + "\n" + tr("Bonus +%d") % e[1]
				break_left = BREAK_TIME
			"over":
				_game_over()
	if not ev.is_empty():
		_update_hud()
	field.queue_redraw()

func _game_over() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("The last city has fallen.") + "\n" + tr("Score: %d") % engine.score + "   ·   " + tr("Wave %d") % engine.wave
	if info:
		info.add("Games played")
		info.high("Highest wave", engine.wave)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _draw_field() -> void:
	var s := field.size
	field.draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.015, 0.045))
	for st in stars:
		field.draw_circle(st[0] * s, st[1], Color(1, 1, 1, 0.3))
	HomeKit.glow_rect(field, Rect2(Vector2.ZERO, s).grow(-1), Color(HomeKit.PURPLE, 0.5), 1.5)
	if engine.cities.is_empty():
		return
	var g: float = engine.ground
	field.draw_rect(Rect2(0, g, s.x, s.y - g), Color(0.05, 0.03, 0.1))
	HomeKit.glow_line(field, Vector2(0, g), Vector2(s.x, g), Color(HomeKit.PURPLE, 0.9), 2.0)
	for c in engine.cities:
		_draw_city(field, Vector2(c.x, g), c.alive)
	var font := ThemeDB.fallback_font
	for b in engine.bases:
		var p := Vector2(b.x, g)
		var col: Color = BASE if b.alive else Color(BASE, 0.25)
		HomeKit.glow_polyline(field, PackedVector2Array([p + Vector2(-26, 0), p + Vector2(0, -26), p + Vector2(26, 0)]), col, 2.0)
		if b.alive:
			field.draw_string(font, p + Vector2(-30, 34), str(b.ammo), HORIZONTAL_ALIGNMENT_CENTER, 60, 24, BASE if b.ammo > 0 else HomeKit.PINK)
	for e in engine.enemies:
		field.draw_line(e.from, e.p, Color(ENEMY, 0.45), 2.0)
		field.draw_circle(e.p, 4.0, Color.WHITE)
		field.draw_circle(e.p, 7.0, Color(ENEMY, 0.4))
	for sh in engine.shots:
		var start := Vector2(sh.p) - Vector2(sh.v).normalized() * 40.0
		field.draw_line(start, sh.p, Color(MINE, 0.6), 2.0)
		field.draw_circle(sh.p, 3.0, Color.WHITE)
		field.draw_line(sh.to + Vector2(-7, -7), sh.to + Vector2(7, 7), Color(MINE, 0.7), 2.0)
		field.draw_line(sh.to + Vector2(-7, 7), sh.to + Vector2(7, -7), Color(MINE, 0.7), 2.0)
	for b in engine.blasts:
		var r: float = engine.blast_radius(b)
		var col: Color = HomeKit.GOLD if b.enemy else MINE
		field.draw_circle(b.p, r, Color(col, 0.25))
		HomeKit.glow_circle(field, b.p, r, col, 2.0)
	if banner != "":
		var lines := banner.split("\n")
		for i in lines.size():
			HomeKit.glow_text(field, Vector2(s.x / 2.0, s.y * 0.35 + i * 50), lines[i], 40 if i == 0 else 30, HomeKit.GOLD)

func _draw_city(c: CanvasItem, base: Vector2, alive: bool) -> void:
	if not alive:
		HomeKit.glow_polyline(c, PackedVector2Array([base + Vector2(-20, 0), base + Vector2(-12, -6), base + Vector2(-2, -3),
			base + Vector2(8, -8), base + Vector2(20, 0)]), Color(HomeKit.PINK, 0.4), 1.5)
		return
	var hs := [16, 26, 20, 32, 18]
	var pts := PackedVector2Array([base + Vector2(-22, 0)])
	for i in hs.size():
		var x := -22 + i * 9
		pts.append(base + Vector2(x, -hs[i]))
		pts.append(base + Vector2(x + 9, -hs[i]))
	pts.append(base + Vector2(23, 0))
	c.draw_colored_polygon(pts, Color(CITY, 0.12))
	HomeKit.glow_polyline(c, pts, CITY, 1.8)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.0, 52.0)
	var o := Vector2(c.size.x / 2.0, c.size.y * 0.85)
	HomeKit.glow_line(c, o + Vector2(-k * 3, 0), o + Vector2(k * 3, 0), HomeKit.PURPLE, 2.0)
	for x in [-1.8, -0.9, 0.9, 1.8]:
		_draw_city(c, o + Vector2(x * k, 0), true)
	c.draw_line(o + Vector2(-k * 2.4, -k * 2.6), o + Vector2(-k * 0.6, -k * 1.2), Color(ENEMY, 0.6), 2.0)
	c.draw_line(o + Vector2(k * 2.2, -k * 2.7), o + Vector2(k * 0.9, -k * 1.5), Color(ENEMY, 0.6), 2.0)
	HomeKit.glow_circle(c, o + Vector2(-k * 0.55, -k * 1.15), k * 0.55, MINE, 2.5, 0.25)
	HomeKit.glow_circle(c, o + Vector2(k * 0.85, -k * 1.5), k * 0.4, HomeKit.GOLD, 2.0, 0.25)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

## The cities, bases and score; a wave in progress starts over on Resume.
func _save_game() -> void:
	if not started or engine.over:
		return
	var alive: Array = []
	for c in engine.cities:
		alive.append(1 if c.alive else 0)
	SaveUtil.write(SAVE_PATH, {"score": engine.score, "wave": engine.wave if not engine.between else engine.wave + 1,
		"cities": alive, "spare": engine.spare_cities, "next_city": engine.next_city})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Score: %d") % int(d.get("score", 0)) + "   ·   " + tr("Wave %d") % int(d.get("wave", 1))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	_new_game()
	if d == null:
		return
	var alive: Array = d.get("cities", [])
	for i in mini(alive.size(), engine.cities.size()):
		engine.cities[i].alive = int(alive[i]) == 1
	engine.score = int(d.get("score", 0))
	engine.wave = maxi(1, int(d.get("wave", 1))) - 1
	engine.spare_cities = int(d.get("spare", 0))
	engine.next_city = int(d.get("next_city", CdEngine.NEW_CITY_EVERY))
	engine.start_wave()
	banner = tr("Wave %d") % engine.wave
	break_left = -1.5
	_update_hud()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
