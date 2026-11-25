extends Control

## Brick Breaker -- slide to move the paddle, tap to launch the ball.

const BBEngine = preload("res://scripts/games/brick_breaker/brick_breaker_engine.gd")
## Landing menu style: S9 Arcade Marquee (docs/MENU_STYLES.md).
const MenuStyles = preload("res://scripts/games/brick_breaker/menu_styles.gd")
const HomeKit = preload("res://scripts/games/brick_breaker/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://brick_breaker_best.json"
const CLOUD_SAVE := "res://scripts/common/cloud_save.gd"  # [NEW 2026-11-24] STANDARDS §18; APK-side, load() guarded
var cloud: Node = null
const ROW_COLORS := [Color(0.95, 0.35, 0.35), Color(0.98, 0.6, 0.2), Color(0.98, 0.85, 0.25), Color(0.4, 0.85, 0.4),
	Color(0.3, 0.75, 0.95), Color(0.45, 0.45, 0.95), Color(0.75, 0.45, 0.95)]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: BBEngine
var board: Control
var info_label: Label
var start_dialog: ColorRect
var over_dialog: ColorRect
var pause_dialog: ColorRect
var running := false
var best: int = 0
var banner := ""
var banner_time: float = 0.0

# ---- Reloaded mode (power-ups + the wild background) ----
## Neon colours per power-up, and the glyph on its capsule.
const POWER_LOOK := {
	"wide": [Color("38f0ff"), "↔"], "multi": [Color("ffe23a"), "✱"], "pierce": [Color("ff8a1e"), "🔥"],
	"boom": [Color("ff3a5a"), "💥"], "laser": [Color("b6ff3a"), "⚡"], "slow": [Color("7a8cff"), "◷"],
	"shield": [Color("3affb0"), "▬"], "life": [Color("ff5ad2"), "♥"], "shrink": [Color("8a8a9a"), "→←"],
	"fast": [Color("ff2a2a"), "»"],
}
const POWER_NAMES := {
	"wide": "WIDE PADDLE", "multi": "MULTI-BALL", "pierce": "FIREBALL", "boom": "EXPLOSIVE",
	"laser": "LASERS", "slow": "SLOW-MO", "shield": "SHIELD", "life": "EXTRA LIFE",
	"shrink": "TINY PADDLE", "fast": "SPEED UP",
}
const GRID_COLS := 13   # springy background grid, in field space
const GRID_ROWS := 21
const GRID_GAP := 50.0
var reloaded := false
var best_reloaded: int = 0
var t: float = 0.0                 # seconds, drives every wobble
var shake: float = 0.0
var sparks: Array = []            # [{p, v, life, max, col, size}]
var rings: Array = []             # [{p, r, max_r, life, col}]
var popups: Array = []            # [{p, text, life, col}]
var stars: Array = []             # [Vector3(x, y, speed)]
var grid_d := PackedVector2Array()  # grid point offsets + velocities
var grid_v := PackedVector2Array()
var flash: float = 0.0

func _ready() -> void:
	preload("res://scripts/games/brick_breaker/brick_breaker_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BBEngine.new()
	_load_best()
	if ResourceLoader.exists(CLOUD_SAVE):
		cloud = load(CLOUD_SAVE).new()
		cloud.setup("brick_breaker", BEST_PATH, _progress_score, _load_best, _merge_best)
		add_child(cloud)
	grid_d.resize(GRID_COLS * GRID_ROWS)
	grid_v.resize(GRID_COLS * GRID_ROWS)
	for i in 90:
		stars.append(Vector3(randf() * BBEngine.FIELD.x, randf() * BBEngine.FIELD.y, randf_range(20.0, 140.0)))
	_build_ui()
	engine.reset()
	_update_info()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🎯 Brick Breaker")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 26)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_left", 12)
	bm.add_theme_constant_override("margin_right", 12)
	bm.add_theme_constant_override("margin_bottom", 24)
	root.add_child(bm)
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.clip_contents = true  # Reloaded's nebula and shake stay inside the board
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	bm.add_child(board)

	start_dialog = UI.build_dialog(tr("🎯 Brick Breaker"), [
		{"text": tr("Start"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	start_dialog.get_meta("message_label").text = tr("Slide to move the paddle, tap to launch. Break every brick!")
	add_child(start_dialog)
	over_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(over_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	])
	add_child(pause_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/brick_breaker/brick_breaker_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best > 0:
			info.high("Best score", best)
		if best_reloaded > 0:
			info.high("Reloaded best", best_reloaded)
	add_child(SettingsDrawer.new())

func _start() -> void:
	_start_mode(false)

func _start_reloaded() -> void:
	_start_mode(true)

## ↺ / Play Again: same mode as the round that just ended.
func _restart() -> void:
	_start_mode(reloaded)

func _start_mode(r: bool) -> void:
	reloaded = r
	engine.reloaded = r
	engine.reset()
	sparks.clear()
	rings.clear()
	popups.clear()
	grid_d.fill(Vector2.ZERO)
	grid_v.fill(Vector2.ZERO)
	over_dialog.visible = false
	running = true
	if r:
		banner = tr("RELOADED!")
		banner_time = 1.5
	_update_info()

func _cur_best() -> int:
	return best_reloaded if reloaded else best

func _resume() -> void:
	running = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running and home:
			home.pause()

func _update_info() -> void:
	info_label.text = tr("Level %d   Score: %d   Lives: %s   Best: %d") % [engine.level, engine.score, "♥".repeat(max(0, engine.lives)), _cur_best()]

func _process(delta: float) -> void:
	if banner_time > 0.0:
		banner_time -= delta
	if reloaded:
		_tick_fx(delta)
	if not running:
		board.queue_redraw()
		return
	var pre_score: int = engine.score
	var res := engine.step(min(delta, 0.05))
	if reloaded:
		_on_events(engine.events)
	if res == "cleared":
		_sfx("powerup")
	elif res != "":
		_sfx("explode")
	elif engine.score > pre_score:
		_sfx("hit")
	match res:
		"cleared":
			banner = tr("Level %d!") % engine.level
			banner_time = 1.5
		"lost_life":
			banner = tr("Ouch! Tap to launch")
			banner_time = 1.5
		"game_over":
			running = false
			if reloaded and engine.score > best_reloaded:
				best_reloaded = engine.score
			elif not reloaded and engine.score > best:
				best = engine.score
			SaveUtil.write(BEST_PATH, {"best": best, "best_reloaded": best_reloaded})
			if cloud:
				cloud.saved()
			if info:
				info.add("Games played")
				if reloaded:
					info.best("Reloaded best", best_reloaded)
				else:
					info.best("Best score", best)
				info.high("Highest level", engine.level)
			over_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score + "\n" + tr("Best: %d") % _cur_best()
			over_dialog.visible = true
	if res != "":
		_update_info()
	elif engine.stuck == false:
		_update_info()
	board.queue_redraw()

func _scale() -> float:
	return min(board.size.x / BBEngine.FIELD.x, board.size.y / BBEngine.FIELD.y)

func _origin() -> Vector2:
	return (board.size - BBEngine.FIELD * _scale()) / 2.0

func _draw_board() -> void:
	if reloaded:
		_draw_reloaded()
		return
	var s := _scale()
	var o := _origin()
	board.draw_rect(Rect2(o, BBEngine.FIELD * s), Color(0.03, 0.04, 0.1))
	HomeKit.glow_rect(board, Rect2(o, BBEngine.FIELD * s), HomeKit.BLUE, 2.0)
	for b in engine.bricks:
		var r: Rect2 = b.rect
		var col: Color = ROW_COLORS[b.row % ROW_COLORS.size()]
		var rect := Rect2(o + r.position * s, r.size * s).grow(-2)
		# tough bricks are filled brighter; every brick is a glowing outline
		board.draw_rect(rect, Color(col, 0.45 if b.hp > 1 else 0.18))
		board.draw_rect(rect, col, false, 2.0)
		board.draw_rect(rect.grow(2), Color(col, 0.25), false, 3.0)
	var pw := BBEngine.PADDLE * s
	HomeKit.glow_rect(board, Rect2(o + Vector2(engine.paddle_x * s - pw.x / 2.0, BBEngine.PADDLE_Y * s), pw), HomeKit.CYAN, 2.5, 0.45)
	HomeKit.glow_circle(board, o + engine.ball * s, BBEngine.BALL_R * s, Color.WHITE, 2.0, 0.9)
	var font: Font = ThemeDB.fallback_font
	if banner_time > 0.0:
		board.draw_string(font, o + Vector2(0, BBEngine.FIELD.y * s * 0.6), banner, HORIZONTAL_ALIGNMENT_CENTER, BBEngine.FIELD.x * s, 40, Color(1, 0.9, 0.4))
	elif running and engine.stuck:
		board.draw_string(font, o + Vector2(0, BBEngine.FIELD.y * s * 0.6), tr("Tap to launch"), HORIZONTAL_ALIGNMENT_CENTER, BBEngine.FIELD.x * s, 34, Color(1, 1, 1, 0.7))

func _on_board_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		engine.set_paddle((event.position.x - _origin().x) / _scale())
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		engine.launch()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/brick_breaker/brick_breaker_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S9 Arcade Marquee; colours analogous orange/red/magenta.
		"landing": "marquee",
		"landing_style": MenuStyles,
		"title_font": "res://games/brick_breaker/title.ttf",
		"title_colors": [Color("ff9a2e"), Color("ff4a3a"), Color("ff3e9a")],
		"landing_colors": [Color("140812"), Color("2a0f22")],
		"menu_color": Color("ff9a2e"),
		"retro": true,
		"help": preload("res://scripts/games/brick_breaker/brick_breaker_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Slide the paddle, tap to launch. Smash every brick!",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "▶  Classic", "sub": "Three lives, level after level", "action": _start},
			{"text": "⚡  Reloaded", "sub": "Power-ups, multi-ball, explosions. Wild!", "action": _start_reloaded},
		],
		"restart": _restart,
		"helps": [{"text": "❤ Extra life", "how": "Gives you one more life, right now.", "action": _help_life}],
		"board_note": "Your best score.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 180.0)
	var w := h * 1.4
	var o := Vector2((c.size.x - w) / 2.0, (c.size.y - h) / 2.0)
	var cols := [HomeKit.MAGENTA, HomeKit.GOLD, HomeKit.LIME]
	for row in 3:
		for i in 5:
			if row == 2 and i == 3:
				continue
			HomeKit.glow_rect(c, Rect2(o + Vector2(i * w / 5.0 + 3, row * h * 0.13 + 3), Vector2(w / 5.0 - 6, h * 0.13 - 6)), cols[row], 1.5, 0.3)
	HomeKit.glow_circle(c, o + Vector2(w * 0.62, h * 0.62), h * 0.05, Color.WHITE, 2.0, 0.8)
	HomeKit.glow_line(c, o + Vector2(w * 0.62, h * 0.62), o + Vector2(w * 0.5, h * 0.86), Color(HomeKit.CYAN, 0.5), 1.0)
	HomeKit.glow_rect(c, Rect2(o + Vector2(w * 0.32, h * 0.9), Vector2(w * 0.36, h * 0.07)), HomeKit.CYAN, 2.5, 0.4)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

# ---------- helps (STANDARDS §17) ----------

## ❤ help: one more life.
func _help_life() -> bool:
	if not running:
		return false
	engine.lives += 1
	_sfx("powerup")
	return true

# ---------- Reloaded: effects + the wild background ----------
# Everything here is drawn in code (no media): a hue-cycling nebula, a warp
# starfield that speeds up with the combo, and a springy neon grid that the
# explosions and broken bricks shove around (it settles back on its own).

## Called every frame while Reloaded is on (also while paused, so the
## background keeps moving behind the menu).
func _tick_fx(delta: float) -> void:
	t += delta
	shake = maxf(0.0, shake - delta * 2.5)
	flash = maxf(0.0, flash - delta * 2.0)
	var warp := 1.0 + mini(engine.combo, 20) * 0.15
	for i in stars.size():
		var st: Vector3 = stars[i]
		st.y += st.z * delta * warp
		if st.y > BBEngine.FIELD.y:
			st = Vector3(randf() * BBEngine.FIELD.x, -10.0, randf_range(20.0, 140.0))
		stars[i] = st
	# grid springs
	for i in grid_d.size():
		grid_v[i] += (-grid_d[i] * 60.0 - grid_v[i] * 5.0) * delta
		grid_d[i] += grid_v[i] * delta
	for sp in sparks:
		sp.p += sp.v * delta
		sp.v = sp.v * 0.97 + Vector2(0, 320.0 * delta)
		sp.life -= delta
	sparks = sparks.filter(_alive)
	for r in rings:
		r.life -= delta
		r.r = lerpf(r.max_r, 6.0, maxf(r.life, 0.0) / r.max_life)
	rings = rings.filter(_alive)
	for p in popups:
		p.p.y -= 60.0 * delta
		p.life -= delta
	popups = popups.filter(_alive)
	# ball trails ride on the engine's ball dictionaries
	for b in engine.balls:
		var tail: PackedVector2Array = b.get("trail", PackedVector2Array())
		tail.append(b.p)
		if tail.size() > 12:
			tail.remove_at(0)
		b["trail"] = tail

func _alive(x: Dictionary) -> bool:
	return x.life > 0.0

func _ring(p: Vector2, max_r: float, life: float, col: Color) -> void:
	rings.append({"p": p, "r": 6.0, "max_r": max_r, "life": life, "max_life": life, "col": col})

func _on_events(evs: Array) -> void:
	for e in evs:
		var p: Vector2 = e.pos
		match e.type:
			"break":
				var col: Color = Color("ff7a1e") if e.tnt else ROW_COLORS[e.row % ROW_COLORS.size()]
				_burst(p, col, 14, 260.0)
				_impulse(p, 140.0, 320.0)
				if e.combo >= 3:
					popups.append({"p": p, "text": "+%d  x%d" % [e.pts, e.combo], "life": 0.9, "col": col.lightened(0.3)})
			"chip":
				_burst(p, Color.WHITE, 5, 160.0)
				_impulse(p, 90.0, 120.0)
			"boom":
				_ring(p, e.r * 1.3, 0.5, Color("ff5a2a"))
				_burst(p, Color("ffb02a"), 26, 420.0)
				_burst(p, Color("ff3a5a"), 14, 300.0)
				_impulse(p, 300.0, 1100.0)
				shake = maxf(shake, 0.55)
				_sfx("explode")
			"power":
				var look: Array = POWER_LOOK.get(e.kind, [Color.WHITE, "?"])
				_ring(p, 220.0, 0.5, look[0])
				_burst(p, look[0], 22, 380.0)
				_impulse(p, 360.0, 600.0)
				popups.append({"p": p + Vector2(0, -60), "text": tr(POWER_NAMES[e.kind]), "life": 1.3, "col": look[0]})
				flash = 0.35
				_sfx("powerup")
			"paddle":
				_impulse(p, 90.0, 140.0)
			"shield":
				_ring(p, 120.0, 0.4, POWER_LOOK.shield[0])
				_burst(p, POWER_LOOK.shield[0], 12, 260.0)
			"lost":
				shake = 1.0
				flash = 0.5
				_impulse(p, 500.0, 900.0)
			"cleared":
				_impulse(p, 900.0, 1600.0)
				for k in 3:
					_ring(p, 300.0 + k * 200.0, 0.5 + k * 0.15, Color.from_hsv(randf(), 0.8, 1.0))
				flash = 0.6

func _burst(p: Vector2, col: Color, n: int, spd: float) -> void:
	if sparks.size() > 500:
		return
	for i in n:
		var life := randf_range(0.35, 0.8)
		sparks.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * spd, "life": life, "max": life, "col": col, "size": randf_range(1.5, 4.0)})

## Shove the background grid away from `at`.
func _impulse(at: Vector2, radius: float, strength: float) -> void:
	for y in GRID_ROWS:
		for x in GRID_COLS:
			var i := y * GRID_COLS + x
			var d := Vector2(x, y) * GRID_GAP + grid_d[i] - at
			var dist := d.length()
			if dist < radius and dist > 0.01:
				grid_v[i] += d / dist * strength * (1.0 - dist / radius)

func _draw_reloaded() -> void:
	var s := _scale()
	var o := _origin() + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 12.0 * s
	var F := BBEngine.FIELD
	var fs := F * s
	var hue := fmod(t * 0.03, 1.0)
	var font: Font = ThemeDB.fallback_font
	# deep space, slowly changing colour
	board.draw_rect(Rect2(o, fs), Color.from_hsv(fmod(hue + 0.7, 1.0), 0.85, 0.1))
	# nebula: big soft blobs on slow looping paths
	for i in 5:
		var c := Vector2(0.5 + 0.42 * sin(t * (0.13 + i * 0.05) + i * 1.7), 0.5 + 0.42 * cos(t * (0.11 + i * 0.04) + i * 2.3)) * F
		var col := Color.from_hsv(fmod(hue + i * 0.19, 1.0), 0.9, 1.0)
		var pulse := 1.0 + 0.15 * sin(t * 0.9 + i)
		for k in 4:
			board.draw_circle(o + c * s, (240.0 - k * 50.0) * pulse * s, Color(col, 0.04))
	# warp stars
	var warp := 1.0 + mini(engine.combo, 20) * 0.25
	for st in stars:
		var a := Vector2(st.x, st.y)
		board.draw_line(o + a * s, o + (a - Vector2(0, st.z * 0.07 * warp)) * s, Color(1, 1, 1, 0.15 + st.z / 400.0), maxf(1.0, s * 1.5))
	# the springy grid, wobbling even when nothing hits it
	var gcol := Color.from_hsv(fmod(hue + 0.5, 1.0), 0.8, 1.0, 0.22)
	var pts := PackedVector2Array()
	pts.resize(GRID_COLS * GRID_ROWS)
	for y in GRID_ROWS:
		for x in GRID_COLS:
			var base := Vector2(x, y) * GRID_GAP
			var wob := Vector2(sin(t * 1.3 + base.y * 0.013), cos(t * 1.1 + base.x * 0.017)) * 5.0
			pts[y * GRID_COLS + x] = o + (base + grid_d[y * GRID_COLS + x] + wob) * s
	for y in GRID_ROWS:
		board.draw_polyline(pts.slice(y * GRID_COLS, (y + 1) * GRID_COLS), gcol, 1.5, true)
	for x in GRID_COLS:
		var line := PackedVector2Array()
		for y in GRID_ROWS:
			line.append(pts[y * GRID_COLS + x])
		board.draw_polyline(line, gcol, 1.5, true)
	# bricks: glassy neon, pulsing; TNT flashes
	for b in engine.bricks:
		var r: Rect2 = b.rect
		var rect := Rect2(o + r.position * s, r.size * s).grow(-1.5)
		var col: Color = ROW_COLORS[b.row % ROW_COLORS.size()]
		var glow := 0.5 + 0.5 * sin(t * 3.0 + b.row * 0.7 + r.position.x * 0.02)
		if b.tnt:
			col = Color("ff7a1e").lerp(Color("ff2a2a"), 0.5 + 0.5 * sin(t * 9.0))
		board.draw_rect(rect, Color(col, 0.75 if b.hp > 1 else 0.38))
		board.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.35)), Color(1, 1, 1, 0.22))
		HomeKit.glow_rect(board, rect, Color(col, 0.6 + 0.4 * glow), 1.5)
		if b.tnt:
			board.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.75), "TNT", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(10, int(rect.size.y * 0.6)), Color.WHITE)
	# falling power-up capsules
	for p in engine.powerups:
		var look: Array = POWER_LOOK.get(p.kind, [Color.WHITE, "?"])
		var sz: Vector2 = BBEngine.POWER_SIZE * s * (1.0 + 0.08 * sin(t * 10.0))
		var rect := Rect2(o + p.pos * s - sz / 2.0, sz)
		HomeKit.glow_rect(board, rect, look[0], 2.0, 0.35)
		board.draw_string(font, rect.position + Vector2(0, sz.y * 0.78), look[1], HORIZONTAL_ALIGNMENT_CENTER, sz.x, maxi(10, int(sz.y * 0.8)), Color.WHITE)
	# lasers
	for l in engine.lasers:
		HomeKit.glow_line(board, o + l * s, o + (l + Vector2(0, 26)) * s, POWER_LOOK.laser[0], 2.0)
	# shield barrier
	if engine.shield > 0:
		var sc: Color = POWER_LOOK.shield[0]
		for k in engine.shield:
			var y := (BBEngine.SHIELD_Y + k * 6.0) * s
			HomeKit.glow_line(board, o + Vector2(0, y), o + Vector2(fs.x, y), Color(sc, 0.5 + 0.3 * sin(t * 6.0 + k)), 2.0)
	# paddle
	var pw: float = engine.paddle_w()
	var prect := Rect2(o + Vector2((engine.paddle_x - pw / 2.0) * s, BBEngine.PADDLE_Y * s), Vector2(pw, BBEngine.PADDLE.y) * s)
	HomeKit.glow_rect(board, prect, Color.from_hsv(fmod(t * 0.25, 1.0), 0.6, 1.0), 2.5, 0.5)
	if engine.has_power("laser"):
		for side in [prect.position.x + 2, prect.end.x - 10 * s]:
			board.draw_rect(Rect2(Vector2(side, prect.position.y - 10 * s), Vector2(8, 12) * s), POWER_LOOK.laser[0])
	# balls + trails
	var bcol := Color.WHITE
	if engine.has_power("pierce"):
		bcol = Color("ff8a1e")
	elif engine.has_power("boom"):
		bcol = Color("ff3a5a").lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 14.0))
	var fat := 1.3 if engine.has_power("pierce") else 0.9
	for b in engine.balls:
		var tail: PackedVector2Array = b.get("trail", PackedVector2Array())
		for i in tail.size():
			var f := float(i + 1) / tail.size()
			board.draw_circle(o + tail[i] * s, BBEngine.BALL_R * s * f * fat, Color(bcol, 0.35 * f))
		HomeKit.glow_circle(board, o + b.p * s, BBEngine.BALL_R * s, bcol, 2.0, 0.9)
	# sparks, shockwaves, popups
	for sp in sparks:
		var a: float = sp.life / sp.max
		board.draw_line(o + sp.p * s, o + (sp.p - sp.v * 0.03) * s, Color(sp.col, a), maxf(1.0, sp.size * s), true)
	for r in rings:
		HomeKit.glow_circle(board, o + r.p * s, r.r * s, Color(r.col, clampf(r.life * 2.0, 0.0, 1.0)), 3.0)
	for p in popups:
		var at: Vector2 = o + p.p * s - Vector2(200, 0)
		board.draw_string_outline(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 28, 6, Color(0, 0, 0, minf(p.life, 1.0)))
		board.draw_string(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 28, Color(p.col, minf(p.life * 2.0, 1.0)))
	# active power-ups with time bars, along the top
	var cx := 10.0
	for k in engine.timers:
		var look: Array = POWER_LOOK.get(k, [Color.WHITE, "?"])
		var chip := Rect2(o + Vector2(cx, 30) * s, Vector2(64, 44) * s)
		HomeKit.glow_rect(board, chip, look[0], 1.5, 0.25)
		board.draw_string(font, chip.position + Vector2(0, chip.size.y * 0.62), look[1], HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, maxi(10, int(chip.size.y * 0.55)), Color.WHITE)
		var left: float = engine.timers[k] / BBEngine.POWERS[k].time
		board.draw_rect(Rect2(chip.position + Vector2(0, chip.size.y + 3 * s), Vector2(chip.size.x * left, 4 * s)), look[0])
		cx += 72.0
	if engine.combo >= 3:
		board.draw_string(font, o + Vector2(0, 100 * s), tr("COMBO x%d") % engine.combo, HORIZONTAL_ALIGNMENT_RIGHT, fs.x - 12 * s, 26 + mini(engine.combo, 20), Color.from_hsv(fmod(t, 1.0), 0.7, 1.0))
	if flash > 0.0:
		board.draw_rect(Rect2(o, fs), Color(1, 1, 1, flash * 0.25))
	HomeKit.glow_rect(board, Rect2(o, fs), Color.from_hsv(fmod(hue + 0.3, 1.0), 0.8, 1.0), 2.5)
	var mid := o + Vector2(0, F.y * s * 0.6)
	if banner_time > 0.0:
		board.draw_string_outline(font, mid, banner, HORIZONTAL_ALIGNMENT_CENTER, fs.x, 48, 8, Color(0, 0, 0, 0.6))
		board.draw_string(font, mid, banner, HORIZONTAL_ALIGNMENT_CENTER, fs.x, 48, Color.from_hsv(fmod(t * 0.8, 1.0), 0.6, 1.0))
	elif running and engine.stuck:
		board.draw_string(font, mid, tr("Tap to launch"), HORIZONTAL_ALIGNMENT_CENTER, fs.x, 34, Color(1, 1, 1, 0.7))

# ---------- cloud (STANDARDS §18) ----------

func _load_best() -> void:
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
		best_reloaded = int(data.get("best_reloaded", 0))

func _progress_score(_d: Dictionary) -> int:
	return 0   # unused: bests merge key by key

## Device + cloud bests: each mode keeps the higher score.
func _merge_best(local: Dictionary, cloud_d: Dictionary) -> Dictionary:
	var out := local.duplicate()
	for k in ["best", "best_reloaded"]:
		if int(cloud_d.get(k, 0)) > int(out.get(k, 0)):
			out[k] = cloud_d[k]
	return out
