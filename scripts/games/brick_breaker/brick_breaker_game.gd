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
const STEEL := Color(0.7, 0.71, 0.74)   # neutral grey: the Classic retro filter keeps it grey
const GOOD := Color("3aff6a")
const BAD := Color("ff2a3a")
const STATUS_H := 64.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: BBEngine
var board: Control
var fx: Control          # additive-blend layer over the board: sparks, glows
var status: Control      # strip under the board: active power-ups, combo
var info_label: Label
var title: Label
var top_bar: HBoxContainer
var info_row: Control   # where info_label sits on tall screens
var start_dialog: ColorRect
var over_dialog: ColorRect
var pause_dialog: ColorRect
var running := false
var best: int = 0
var banner := ""
var banner_time: float = 0.0

# ---- Reloaded mode (power-ups + the warping grid) ----
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
const GRID_GAP := 25.0   # springy background grid spacing, in field space (wider on wide fields)
var grid_gap := GRID_GAP
var grid_nx := 0
var grid_ny := 0
var reloaded := false
var best_reloaded: int = 0
var t: float = 0.0                 # seconds, drives every wobble
var shake: float = 0.0
var shake_off := Vector2.ZERO
var sparks: Array = []            # [{p, v, life, max, col, size}]
var shards: Array = []            # brick pieces: [{p, v, a, spin, len, life, max, col}]
var blooms: Array = []            # soft additive glows: [{p, r, life, max, col}]
var rings: Array = []             # [{p, r, max_r, life, col}]
var popups: Array = []            # [{p, text, life, col}]
var grid_d := PackedVector2Array()  # grid point offsets + velocities
var grid_v := PackedVector2Array()
var flash: float = 0.0
var flash_col := Color.WHITE
var disc: Texture2D               # soft round glow, drawn many times (cheap)

func _ready() -> void:
	preload("res://scripts/games/brick_breaker/brick_breaker_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BBEngine.new()
	_load_best()
	if ResourceLoader.exists(CLOUD_SAVE):
		cloud = load(CLOUD_SAVE).new()
		cloud.setup("brick_breaker", BEST_PATH, _progress_score, _load_best, _merge_best)
		add_child(cloud)
	disc = _make_disc()
	_build_ui()
	engine.reset()
	_update_info()
	_fit_header.call_deferred()

static func _make_disc() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 12)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	top_bar = bar
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	title = Label.new()
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
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row = root
	root.add_child(info_label)
	resized.connect(_fit_header)

	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_left", 8)
	bm.add_theme_constant_override("margin_right", 8)
	root.add_child(bm)
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.clip_contents = true  # shake and sparks stay inside the board
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	bm.add_child(board)
	fx = Control.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = add_mat
	fx.draw.connect(_draw_fx)
	board.add_child(fx)
	# power-ups, shield and combo live here, outside the playing field
	status = Control.new()
	status.custom_minimum_size = Vector2(0, STATUS_H)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.draw.connect(_draw_status)
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 8)
	sm.add_theme_constant_override("margin_right", 8)
	sm.add_theme_constant_override("margin_bottom", 8)
	sm.add_child(status)
	root.add_child(sm)

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

## Wide screens (PC): the score line joins the top bar in place of the
## title, so the board gets the height.
func _fit_header() -> void:
	var wide := size.x > size.y * 1.2
	if wide and info_label.get_parent() != top_bar:
		info_label.reparent(top_bar)
		top_bar.move_child(info_label, 2)
	elif not wide and info_label.get_parent() != info_row:
		info_label.reparent(info_row)
		info_row.move_child(info_label, 1)
	title.visible = not wide

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
	_fit_retro()
	# wide screens (PC) get a wider field, so the game fills the window
	var h := maxf(board.size.y, 1.0)
	var fw := floorf(BBEngine.FIELD.y * board.size.x / h / BBEngine.CELL_W) * BBEngine.CELL_W
	engine.field = Vector2(clampf(fw, BBEngine.FIELD.x, BBEngine.MAX_FIELD_X), BBEngine.FIELD.y)
	engine.reset()
	sparks.clear()
	shards.clear()
	blooms.clear()
	rings.clear()
	popups.clear()
	grid_gap = maxf(GRID_GAP, engine.field.x / 48.0)
	grid_nx = int(engine.field.x / grid_gap) + 1
	grid_ny = int(engine.field.y / grid_gap) + 1
	grid_d.resize(grid_nx * grid_ny)
	grid_v.resize(grid_nx * grid_ny)
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

## The Classic skin's retro filter flattens every colour to a few primaries:
## right for Classic mode, but it would kill Reloaded's glow, so Reloaded
## always plays in full neon.
## The kit calls _set_skin() on start-up and whenever the player changes it.
var skin := "classic"

func _set_skin(n: String) -> void:
	skin = n
	_fit_retro()

func _fit_retro() -> void:
	if home and home.has_method("_set_retro"):
		home._set_retro(not reloaded and skin != "voodoo")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running and home:
			home.pause()

func _update_info() -> void:
	info_label.text = tr("Level %d   Score: %d   Lives: %s   Best: %d") % [engine.level, engine.score, "♥".repeat(max(0, engine.lives)), _cur_best()]

func _process(delta: float) -> void:
	if banner_time > 0.0:
		banner_time -= delta
	_tick_fx(delta)
	if not running:
		_redraw()
		return
	var pre_score: int = engine.score
	var res := engine.step(min(delta, 0.05))
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
	_redraw()

func _redraw() -> void:
	board.queue_redraw()
	fx.queue_redraw()
	status.queue_redraw()

func _scale() -> float:
	return min(board.size.x / engine.field.x, board.size.y / engine.field.y)

func _origin() -> Vector2:
	return (board.size - engine.field * _scale()) / 2.0

## Origin with the screen shake applied (drawing only, never input).
func _so() -> Vector2:
	return _origin() + shake_off * _scale()

func _draw_board() -> void:
	var s := _scale()
	var o := _so()
	var fs := engine.field * s
	var font: Font = ThemeDB.fallback_font
	if reloaded:
		board.draw_rect(Rect2(o, fs), Color(0.01, 0.015, 0.05))
		_draw_grid(o, s)
	else:
		board.draw_rect(Rect2(o, fs), Color(0.03, 0.04, 0.1))
		HomeKit.glow_rect(board, Rect2(o, fs), HomeKit.BLUE, 2.0)
	_draw_bricks(o, s, font)
	if reloaded:
		_draw_capsules(o, s, font)
		for l in engine.lasers:
			board.draw_line(o + l * s, o + (l + Vector2(0, 26)) * s, Color.WHITE, maxf(2.0, 3.0 * s))
		if engine.shield > 0:
			var sc: Color = POWER_LOOK.shield[0]
			for k in engine.shield:
				var y := (BBEngine.SHIELD_Y + k * 6.0) * s
				HomeKit.glow_line(board, o + Vector2(0, y), o + Vector2(fs.x, y), Color(sc, 0.5 + 0.3 * sin(t * 6.0 + k)), 2.0)
	# paddle
	var pw: float = engine.paddle_w()
	var prect := Rect2(o + Vector2((engine.paddle_x - pw / 2.0) * s, BBEngine.PADDLE_Y * s), Vector2(pw, BBEngine.PADDLE.y) * s)
	var pcol: Color = HomeKit.CYAN
	if reloaded:
		pcol = BAD if engine.has_power("shrink") else Color.from_hsv(fmod(t * 0.25, 1.0), 0.6, 1.0)
	HomeKit.glow_rect(board, prect, pcol, 2.5, 0.5)
	if reloaded and engine.has_power("laser"):
		for side in [prect.position.x + 2, prect.end.x - 10 * s]:
			board.draw_rect(Rect2(Vector2(side, prect.position.y - 10 * s), Vector2(8, 12) * s), POWER_LOOK.laser[0])
	# ball cores (their glow and trails are on the fx layer)
	for b in engine.balls:
		var r := BBEngine.BALL_R * s
		board.draw_texture_rect(disc, Rect2(o + b.p * s - Vector2(r, r) * 1.2, Vector2(r, r) * 2.4), false, _ball_col())
		board.draw_texture_rect(disc, Rect2(o + b.p * s - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), false, Color.WHITE)
	for p in popups:
		var at: Vector2 = o + p.p * s - Vector2(200, 0)
		board.draw_string_outline(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 28, 6, Color(0, 0, 0, minf(p.life, 1.0)))
		board.draw_string(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 28, Color(p.col, minf(p.life * 2.0, 1.0)))
	if reloaded:
		HomeKit.glow_rect(board, Rect2(o, fs), Color(0.3, 0.5, 1.0).lerp(Color("ff3ad2"), minf(engine.combo / 15.0, 1.0)), 2.5)
	var mid := o + Vector2(0, engine.field.y * s * 0.6)
	if banner_time > 0.0:
		var bc := Color.from_hsv(fmod(t * 0.8, 1.0), 0.6, 1.0) if reloaded else Color(1, 0.9, 0.4)
		board.draw_string_outline(font, mid, banner, HORIZONTAL_ALIGNMENT_CENTER, fs.x, 48, 8, Color(0, 0, 0, 0.6))
		board.draw_string(font, mid, banner, HORIZONTAL_ALIGNMENT_CENTER, fs.x, 48, bc)
	elif running and engine.stuck:
		board.draw_string(font, mid, tr("Tap to launch"), HORIZONTAL_ALIGNMENT_CENTER, fs.x, 34, Color(1, 1, 1, 0.7))

func _ball_col() -> Color:
	if not reloaded:
		return Color(0.7, 0.9, 1.0)
	if engine.has_power("pierce"):
		return Color("ff8a1e")
	if engine.has_power("boom"):
		return Color("ff3a5a").lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 14.0))
	return Color(0.6, 0.85, 1.0)

## Bricks are plain rects (cheap); only the few slanted bricks are
## polygons. The number is the hits a brick still needs.
func _draw_bricks(o: Vector2, s: float, font: Font) -> void:
	var labels: Array = []
	for b in engine.bricks:
		var col: Color
		var fill: Color
		var rc: Vector2 = (b.rect as Rect2).get_center()
		if b.steel:
			col = STEEL
			fill = Color(0.36, 0.37, 0.39)
		else:
			col = ROW_COLORS[b.row % ROW_COLORS.size()]
			if reloaded and b.tnt:
				col = Color("ff7a1e").lerp(Color("ff2a2a"), 0.5 + 0.5 * sin(t * 9.0))
			fill = Color(col.darkened(0.35), 0.35 + 0.07 * mini(b.hp, 8))
			var hit: float = b.get("hit", 0.0)
			if hit > 0.0:
				fill = fill.lerp(Color.WHITE, hit)
		var poly: PackedVector2Array = b.poly
		var pts := PackedVector2Array()
		for v in poly:
			# shrink a hair toward the centre so neighbours don't touch
			pts.append(o + (v + (rc - v).normalized() * 1.0) * s)
		var lw := maxf(1.5, 2.0 * s)
		if pts.size() == 4:
			var rr := Rect2(pts[0], pts[2] - pts[0])
			board.draw_rect(rr, fill)
			if reloaded:
				board.draw_rect(rr.grow(1.5), Color(col, 0.25), false, lw * 3.0)
			board.draw_rect(rr, col, false, lw)
		else:
			board.draw_colored_polygon(pts, fill)
			var loop := pts.duplicate()
			loop.append(pts[0])
			board.draw_polyline(loop, col, lw)
		if b.steel:
			# a bright bevel along the top edge
			board.draw_line(pts[0], pts[1], Color(1, 1, 1, 0.8), lw)
		elif reloaded and b.tnt:
			labels.append([o + rc * s, "TNT"])
		elif b.hp > 1:
			labels.append([o + rc * s, str(b.hp)])
	var fsz := maxi(12, int(BBEngine.BRICK_H * s * 0.72))
	for l in labels:
		var w := font.get_string_size(l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var at: Vector2 = l[0] + Vector2(-w / 2.0, fsz * 0.36)
		board.draw_string_outline(font, at, l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 4, Color(0, 0, 0, 0.7))
		board.draw_string(font, at, l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color.WHITE)

## Falling capsules. Good ones: green frame, ▲ badge, steady. Bad ones:
## red frame with warning stripes, ▼ badge, and they shudder.
func _draw_capsules(o: Vector2, s: float, font: Font) -> void:
	for p in engine.powerups:
		var look: Array = POWER_LOOK.get(p.kind, [Color.WHITE, "?"])
		var good := BBEngine.is_good(p.kind)
		var frame: Color = GOOD if good else BAD
		var at: Vector2 = p.pos
		if not good:
			at.x += sin(t * 40.0) * 3.0
		var sz: Vector2 = BBEngine.POWER_SIZE * s * (1.0 + 0.08 * sin(t * 10.0))
		var rect := Rect2(o + at * s - sz / 2.0, sz)
		board.draw_rect(rect, Color(frame.darkened(0.7), 0.9))
		if not good:
			var step := sz.y * 0.6
			var x := 0.0
			while x < sz.x + sz.y:
				board.draw_line(rect.position + Vector2(x, 0), rect.position + Vector2(x - sz.y, sz.y), Color(BAD, 0.35), step * 0.35)
				x += step
		HomeKit.glow_rect(board, rect, frame, 2.5)
		var fsz := maxi(10, int(sz.y * 0.7))
		board.draw_string(font, rect.position + Vector2(sz.x * 0.18, sz.y * 0.76), look[1], HORIZONTAL_ALIGNMENT_CENTER, sz.x * 0.82, fsz, look[0].lightened(0.3))
		# badge on the left
		var badge := Rect2(rect.position, Vector2(sz.x * 0.3, sz.y))
		board.draw_rect(badge, frame)
		board.draw_string(font, badge.position + Vector2(0, sz.y * 0.74), "▲" if good else "▼", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, fsz, Color.BLACK)

## The warping grid: thin lines that light up where they are stretched.
func _draw_grid(o: Vector2, s: float) -> void:
	if grid_nx == 0:
		return
	var pts := PackedVector2Array()
	pts.resize(grid_nx * grid_ny)
	var amp := PackedFloat32Array()
	amp.resize(pts.size())
	for i in pts.size():
		var base := Vector2(i % grid_nx, i / grid_nx) * grid_gap
		pts[i] = o + (base + grid_d[i]) * s
		amp[i] = minf(grid_d[i].length() / 22.0, 1.0)
	var calm := Color(0.12, 0.22, 0.75).lerp(Color(0.55, 0.12, 0.7), minf(engine.combo / 15.0, 1.0))
	var hot := Color(0.75, 0.95, 1.0)
	var minor := PackedVector2Array()
	var minor_c := PackedColorArray()
	var major := PackedVector2Array()
	var major_c := PackedColorArray()
	for y in grid_ny:
		for x in grid_nx:
			var i := y * grid_nx + x
			if x + 1 < grid_nx:
				var a := (amp[i] + amp[i + 1]) * 0.5
				var c := Color(calm.lerp(hot, a), 0.28 + 0.6 * a)
				if y % 4 == 0:
					major.append_array([pts[i], pts[i + 1]])
					major_c.append(Color(c, minf(c.a + 0.2, 1.0)))
				else:
					minor.append_array([pts[i], pts[i + 1]])
					minor_c.append(c)
			if y + 1 < grid_ny:
				var a2 := (amp[i] + amp[i + grid_nx]) * 0.5
				var c2 := Color(calm.lerp(hot, a2), 0.28 + 0.6 * a2)
				if x % 4 == 0:
					major.append_array([pts[i], pts[i + grid_nx]])
					major_c.append(Color(c2, minf(c2.a + 0.2, 1.0)))
				else:
					minor.append_array([pts[i], pts[i + grid_nx]])
					minor_c.append(c2)
	board.draw_multiline_colors(minor, minor_c, maxf(1.0, 1.0 * s))
	board.draw_multiline_colors(major, major_c, maxf(1.5, 2.2 * s))

## Additive layer: glows, sparks, brick shards, shockwaves, ball trails.
func _draw_fx() -> void:
	var s := _scale()
	var o := _so()
	for bl in blooms:
		var a: float = bl.life / bl.max
		var r: float = bl.r * s * (1.6 - a * 0.6)
		fx.draw_texture_rect(disc, Rect2(o + bl.p * s - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(bl.col, a * a))
	var bcol := _ball_col()
	for b in engine.balls:
		var tail: PackedVector2Array = b.get("trail", PackedVector2Array())
		for i in tail.size():
			var f := float(i + 1) / tail.size()
			var r := BBEngine.BALL_R * s * (0.6 + 1.2 * f) * (1.6 if reloaded and engine.has_power("pierce") else 1.0)
			fx.draw_texture_rect(disc, Rect2(o + tail[i] * s - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(bcol, 0.35 * f))
		var g := BBEngine.BALL_R * s * 3.5
		fx.draw_texture_rect(disc, Rect2(o + b.p * s - Vector2(g, g), Vector2(g, g) * 2.0), false, Color(bcol, 0.6))
	if reloaded:
		for l in engine.lasers:
			var g := 14.0 * s
			fx.draw_texture_rect(disc, Rect2(o + l * s - Vector2(g, g), Vector2(g, g * 4.0)), false, POWER_LOOK.laser[0])
		for p in engine.powerups:
			var g := 60.0 * s
			var c: Color = GOOD if BBEngine.is_good(p.kind) else BAD
			fx.draw_texture_rect(disc, Rect2(o + p.pos * s - Vector2(g, g * 0.7), Vector2(g * 2.0, g * 1.4)), false, Color(c, 0.35 + 0.15 * sin(t * 8.0)))
	for sh in shards:
		var a: float = sh.life / sh.max
		var d: Vector2 = Vector2.from_angle(sh.a) * sh.len * 0.5
		fx.draw_line(o + (sh.p - d) * s, o + (sh.p + d) * s, Color(sh.col, a), maxf(2.0, 5.0 * s))
	for sp in sparks:
		var a: float = sp.life / sp.max
		fx.draw_line(o + sp.p * s, o + (sp.p - sp.v * 0.035) * s, Color(sp.col, a), maxf(1.0, sp.size * s))
	for r in rings:
		var a: float = clampf(r.life / r.max_life * 1.5, 0.0, 1.0)
		fx.draw_arc(o + r.p * s, r.r * s, 0.0, TAU, 64, Color(r.col, a), maxf(2.0, 8.0 * s * a))
	if flash > 0.0:
		fx.draw_rect(Rect2(o, engine.field * s), Color(flash_col, flash * 0.3))

## Under the board: active power-ups (with time left), shield and combo.
## Classic shows how much of the wall is left.
func _draw_status() -> void:
	var font: Font = ThemeDB.fallback_font
	var h := status.size.y
	var w := status.size.x
	if not reloaded:
		var total: int = maxi(1, engine.bricks.size())
		var left := float(engine.breakable_left()) / total
		var bar := Rect2(Vector2(w * 0.2, h * 0.4), Vector2(w * 0.6, h * 0.2))
		status.draw_rect(bar, Color(1, 1, 1, 0.08))
		status.draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Color(HomeKit.CYAN, 0.6))
		return
	var x := 0.0
	var chip_w := h * 1.1
	for k in engine.timers:
		var look: Array = POWER_LOOK.get(k, [Color.WHITE, "?"])
		var frame: Color = GOOD if BBEngine.is_good(k) else BAD
		var chip := Rect2(Vector2(x, 2), Vector2(chip_w, h - 14))
		status.draw_rect(chip, Color(frame.darkened(0.7), 0.9))
		HomeKit.glow_rect(status, chip, frame, 2.0)
		status.draw_string(font, chip.position + Vector2(0, chip.size.y * 0.72), look[1], HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, int(chip.size.y * 0.6), look[0].lightened(0.3))
		var left: float = engine.timers[k] / BBEngine.POWERS[k].time
		status.draw_rect(Rect2(Vector2(x, h - 8), Vector2(chip_w * left, 6)), frame)
		x += chip_w + 10.0
	for k in engine.shield:
		var r := Rect2(Vector2(x, h * 0.3), Vector2(h * 0.7, h * 0.25))
		HomeKit.glow_rect(status, r, POWER_LOOK.shield[0], 2.0, 0.4)
		x += h * 0.8
	if engine.combo >= 3:
		var fsz := 28 + mini(engine.combo, 20)
		status.draw_string_outline(font, Vector2(0, h * 0.72), tr("COMBO x%d") % engine.combo, HORIZONTAL_ALIGNMENT_RIGHT, w - 6, fsz, 6, Color(0, 0, 0, 0.7))
		status.draw_string(font, Vector2(0, h * 0.72), tr("COMBO x%d") % engine.combo, HORIZONTAL_ALIGNMENT_RIGHT, w - 6, fsz, Color.from_hsv(fmod(t, 1.0), 0.7, 1.0))

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

# ---------- effects ----------
# Everything is drawn in code (no media). Both modes get sparks and brick
# shards when a brick breaks; Reloaded adds the warping grid (explosions
# punch deep dents into it that ripple out and settle), glows, shockwaves,
# flashes and screen shake.

## Called every frame (also while paused, so effects finish behind the menu).
func _tick_fx(delta: float) -> void:
	t += delta
	shake = maxf(0.0, shake - delta * 2.2)
	shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 22.0 if shake > 0.0 else Vector2.ZERO
	flash = maxf(0.0, flash - delta * 2.5)
	for b in engine.bricks:
		if b.has("hit"):
			b.hit = maxf(0.0, b.hit - delta * 5.0)
	if reloaded and grid_nx > 0:
		_tick_grid(minf(delta, 0.033))
	for sp in sparks:
		sp.p += sp.v * delta
		sp.v = sp.v * (1.0 - 2.0 * delta) + Vector2(0, 260.0 * delta)
		sp.life -= delta
	sparks = sparks.filter(_alive)
	for sh in shards:
		sh.p += sh.v * delta
		sh.v += Vector2(0, 900.0 * delta)
		sh.a += sh.spin * delta
		sh.life -= delta
	shards = shards.filter(_alive)
	for bl in blooms:
		bl.life -= delta
	blooms = blooms.filter(_alive)
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
		if tail.size() > 14:
			tail.remove_at(0)
		b["trail"] = tail

## Grid points are springs: pulled home, damped, and tugged by their four
## neighbours, so a dent spreads out as a ripple.
func _tick_grid(dt: float) -> void:
	var n := grid_d.size()
	var acc := PackedVector2Array()
	acc.resize(n)
	for y in grid_ny:
		for x in grid_nx:
			var i := y * grid_nx + x
			var d := grid_d[i]
			var lap := -4.0 * d
			lap += grid_d[i - 1] if x > 0 else Vector2.ZERO
			lap += grid_d[i + 1] if x + 1 < grid_nx else Vector2.ZERO
			lap += grid_d[i - grid_nx] if y > 0 else Vector2.ZERO
			lap += grid_d[i + grid_nx] if y + 1 < grid_ny else Vector2.ZERO
			acc[i] = -d * 28.0 + lap * 55.0 - grid_v[i] * 3.2
	for i in n:
		grid_v[i] += acc[i] * dt
		grid_d[i] += grid_v[i] * dt
		if grid_d[i].length_squared() > 4900.0:
			grid_d[i] = grid_d[i].limit_length(70.0)

## Punch the grid at `at`: strong in the middle, fading fast with distance
## (negative strength sucks the grid in).
func _impulse(at: Vector2, radius: float, strength: float) -> void:
	if not reloaded or grid_nx == 0:
		return
	var x0 := maxi(0, int((at.x - radius) / grid_gap))
	var x1 := mini(grid_nx - 1, int((at.x + radius) / grid_gap) + 1)
	var y0 := maxi(0, int((at.y - radius) / grid_gap))
	var y1 := mini(grid_ny - 1, int((at.y + radius) / grid_gap) + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * grid_nx + x
			var d := Vector2(x, y) * grid_gap + grid_d[i] - at
			var dist := d.length()
			if dist < radius and dist > 0.01:
				var f := 1.0 - dist / radius
				grid_v[i] += d / dist * strength * f * f

func _alive(x: Dictionary) -> bool:
	return x.life > 0.0

func _ring(p: Vector2, max_r: float, life: float, col: Color) -> void:
	if rings.size() < 16:
		rings.append({"p": p, "r": 6.0, "max_r": max_r, "life": life, "max_life": life, "col": col})

func _bloom(p: Vector2, r: float, life: float, col: Color) -> void:
	if blooms.size() < 60:
		blooms.append({"p": p, "r": r, "life": life, "max": life, "col": col})

func _on_events(evs: Array) -> void:
	for e in evs:
		var p: Vector2 = e.pos
		match e.type:
			"break":
				var br: Dictionary = e.brick
				var col: Color = Color("ff7a1e") if e.tnt else ROW_COLORS[e.row % ROW_COLORS.size()]
				_shatter(br, col, 10 if reloaded else 6)
				if not reloaded:
					_burst(p, col, 12, 260.0)
					continue
				var heat := minf(e.combo / 10.0, 1.0)
				_burst(p, col, 22 + int(heat * 20), 360.0 + heat * 200.0)
				_burst(p, Color.WHITE, 6, 200.0)
				_bloom(p, 70.0 + heat * 60.0, 0.35, col)
				_impulse(p, 130.0, 650.0 + heat * 500.0)
				shake = maxf(shake, 0.15 + heat * 0.2)
				if e.combo >= 3:
					popups.append({"p": p, "text": "+%d  x%d" % [e.pts, e.combo], "life": 0.9, "col": col.lightened(0.3)})
			"chip":
				var br: Dictionary = e.brick
				br["hit"] = 1.0
				_burst(p, Color.WHITE, 6 if reloaded else 4, 180.0)
				_impulse(p, 80.0, 250.0)
			"steel":
				_burst(p, STEEL.lightened(0.3), 5, 220.0)
			"boom":
				_ring(p, e.r * 1.6, 0.45, Color("ffb02a"))
				_ring(p, e.r * 2.6, 0.7, Color("ff3a5a"))
				_bloom(p, e.r * 2.2, 0.5, Color("ff7a2a"))
				_bloom(p, e.r * 1.0, 0.25, Color.WHITE)
				_burst(p, Color("ffd02a"), 40, 620.0)
				_burst(p, Color("ff3a5a"), 26, 420.0)
				_burst(p, Color.WHITE, 10, 800.0)
				_impulse(p, 300.0, 2600.0)
				shake = maxf(shake, 0.7)
				flash = maxf(flash, 0.5)
				flash_col = Color("ff8a3a")
				_sfx("explode")
			"power":
				var look: Array = POWER_LOOK.get(e.kind, [Color.WHITE, "?"])
				var good := BBEngine.is_good(e.kind)
				var c: Color = look[0] if good else BAD
				_ring(p, 240.0, 0.5, c)
				_bloom(p, 160.0, 0.4, c)
				_burst(p, c, 30, 420.0)
				_impulse(p, 260.0, 1200.0 if good else -1400.0)
				var label: String = tr(POWER_NAMES[e.kind])
				popups.append({"p": p + Vector2(0, -60), "text": ("▲ " if good else "▼ ") + label, "life": 1.3, "col": GOOD if good else BAD})
				flash = 0.45
				flash_col = GOOD if good else BAD
				if not good:
					shake = maxf(shake, 0.5)
				_sfx("powerup" if good else "explode")
			"paddle":
				_impulse(p, 100.0, 300.0)
				if reloaded:
					_burst(p, HomeKit.CYAN, 5, 160.0)
			"laser":
				_bloom(p, 40.0, 0.12, POWER_LOOK.laser[0])
			"shield":
				_ring(p, 140.0, 0.4, POWER_LOOK.shield[0])
				_burst(p, POWER_LOOK.shield[0], 16, 300.0)
				_impulse(p, 200.0, 900.0)
			"lost":
				shake = 1.0
				flash = 0.6
				flash_col = BAD
				_impulse(p, 600.0, -2500.0)
				_burst(p, BAD, 40, 600.0)
			"cleared":
				_level_fireworks()

## Level clear in Reloaded: the whole field goes up.
func _level_fireworks() -> void:
	var f := engine.field
	if reloaded:
		for k in 9:
			var at := Vector2(randf_range(0.1, 0.9) * f.x, randf_range(0.1, 0.6) * f.y)
			var c := Color.from_hsv(randf(), 0.8, 1.0)
			_ring(at, 260.0, 0.6 + k * 0.05, c)
			_bloom(at, 220.0, 0.6, c)
			_burst(at, c, 30, 600.0)
			_impulse(at, 400.0, 2200.0)
		shake = 1.0
		flash = 0.7
		flash_col = Color.WHITE
	else:
		for k in 5:
			_burst(Vector2(randf_range(0.1, 0.9) * f.x, randf_range(0.1, 0.5) * f.y), Color.from_hsv(randf(), 0.7, 1.0), 20, 380.0)

## A broken brick flies apart in pieces along its outline.
func _shatter(br: Dictionary, col: Color, n: int) -> void:
	if shards.size() > 400:
		return
	var r: Rect2 = br.rect
	for i in n:
		var at := r.position + Vector2(randf() * r.size.x, randf() * r.size.y)
		var out := (at - r.get_center()).normalized()
		var life := randf_range(0.5, 1.0)
		shards.append({"p": at, "v": out * randf_range(120.0, 360.0) + Vector2(randf_range(-80, 80), -randf_range(80, 260)),
			"a": randf() * TAU, "spin": randf_range(-14.0, 14.0), "len": randf_range(8.0, r.size.x * 0.4),
			"life": life, "max": life, "col": col.lightened(0.2)})

func _burst(p: Vector2, col: Color, n: int, spd: float) -> void:
	if sparks.size() > 900:
		return
	for i in n:
		var life := randf_range(0.35, 0.9)
		sparks.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * spd, "life": life, "max": life, "col": col, "size": randf_range(1.5, 4.5)})

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
