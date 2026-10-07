extends Control

## Bubble Pop: aim and fire coloured bubbles at the honeycomb. Three of a
## colour touching pop; anything left hanging falls for bonus points. Miss
## too often and the whole ceiling drops a row; touch the line and it's over.

const BubbleEngine = preload("res://scripts/games/bubble_pop/bubble_pop_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/bubble_pop/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/bubble_pop/bubble_pop_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://bubble_pop_save.json"

const LEVELS := ["Easy", "Normal", "Hard"]
const LEVEL_COLORS := [4, 5, 6]
## Shots in a row without a pop before the ceiling drops.
const PUSH_EVERY := [8, 6, 5]
const PALETTE := [Color("29e6ff"), Color("ff2bd6"), Color("7dff3a"), Color("ffae2b"), Color("9b4dff"), Color("ff3b3b")]
const SPEED := 30.0  # radii per second
const CLEAR_BONUS := 500

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var level: int = 1
var started := false
var over := false
var cur: int = 0
var nxt: int = 0
var misses: int = 0
var best_shot: int = 0
var aim := Vector2(0, -1)
var aiming := false
var flying := false
var fly_pos := Vector2.ZERO  # in radii
var fly_vel := Vector2.ZERO
var bits: Array = []  # falling / bursting bubbles: [pos, vel, colour, life]

var board: Control
var score_label: Label
var info_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/bubble_pop/bubble_pop_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = BubbleEngine.new()
	_build_ui()
	_new_round(1)
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

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
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", HomeKit.MAGENTA.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(HomeKit.MAGENTA, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 22)
	info_label.add_theme_color_override("font_color", HomeKit.DIM)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_bottom", 18)
	bm.add_child(board)
	root.add_child(bm)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": LEVELS[i], "sub": tr("%d colours") % LEVEL_COLORS[i], "row": "levels",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": HomeKit.MAGENTA,
		"subtitle": "Aim, fire, pop three of a colour. Don't let them reach the line.",
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
	drawer.set("default_frac", 0.97)  # beside the shooter, right of the next bubble
	add_child(drawer)

# ---------- game flow ----------

func _new_game(lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_new_round(lvl)

func _restart() -> void:
	_new_round(level)

func _new_round(lvl: int) -> void:
	level = lvl
	engine.reset(LEVEL_COLORS[lvl], rng)
	misses = 0
	best_shot = 0
	over = false
	started = true
	flying = false
	bits.clear()
	cur = _pick_color()
	nxt = _pick_color()
	end_dialog.visible = false
	_update_labels()
	board.queue_redraw()

func _pick_color() -> int:
	var present: Array = engine.colors_present()
	if present.is_empty():
		return rng.randi_range(0, engine.colors - 1)
	return present[rng.randi_range(0, present.size() - 1)]

func _update_labels() -> void:
	score_label.text = str(engine.score)
	var left: int = PUSH_EVERY[level] - misses
	info_label.text = tr("%s   ·   The ceiling drops in %d") % [tr(LEVELS[level]), left]

# ---------- geometry (everything in bubble radii, scaled by R) ----------

func _radius() -> float:
	return minf(board.size.x / (2.0 * BubbleEngine.COLS), board.size.y / 27.0)

func _origin() -> Vector2:
	var r := _radius()
	return Vector2((board.size.x - r * 2.0 * BubbleEngine.COLS) / 2.0, 0.0)

func _shooter() -> Vector2:
	return Vector2(BubbleEngine.COLS, 1.0 + (BubbleEngine.ROWS - 1) * sqrt(3.0) + 0.6)

func _next_spot() -> Vector2:
	return _shooter() + Vector2(4.2, 0.3)

func _to_units(p: Vector2) -> Vector2:
	return (p - _origin()) / _radius()

# ---------- input ----------

func _on_board_input(event: InputEvent) -> void:
	if over or flying:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var u := _to_units(event.position)
		if event.pressed:
			if u.distance_to(_next_spot()) < 1.8:
				var t := cur
				cur = nxt
				nxt = t
				_sfx("toggle")
				board.queue_redraw()
				return
			aiming = true
			_set_aim(u)
		elif aiming:
			aiming = false
			_set_aim(u)
			_fire()
	elif event is InputEventMouseMotion and aiming:
		_set_aim(_to_units(event.position))

func _set_aim(u: Vector2) -> void:
	var d := u - _shooter()
	if d.length() < 0.5:
		return
	d = d.normalized()
	if d.y > -0.17:  # never flatter than ~10 degrees
		d = Vector2(signf(d.x) if d.x != 0.0 else 1.0, -0.17).normalized()
	aim = d
	board.queue_redraw()

func _fire() -> void:
	flying = true
	fly_pos = _shooter()
	fly_vel = aim * SPEED
	_sfx("shoot")

func _process(delta: float) -> void:
	if flying:
		var steps := int(ceil(SPEED * delta / 0.25))
		for i in steps:
			if _step(delta / steps):
				break
		board.queue_redraw()
	if not bits.is_empty():
		for b in bits:
			b[0] += b[1] * delta
			b[1].y += 40.0 * delta
			b[3] -= delta
		bits = bits.filter(func(b): return b[3] > 0.0)
		board.queue_redraw()

## Moves the flying bubble one small step; true once it has stuck.
func _step(dt: float) -> bool:
	fly_pos += fly_vel * dt
	var w := 2.0 * BubbleEngine.COLS
	if fly_pos.x < 1.0:
		fly_pos.x = 2.0 - fly_pos.x
		fly_vel.x = absf(fly_vel.x)
	elif fly_pos.x > w - 1.0:
		fly_pos.x = 2.0 * (w - 1.0) - fly_pos.x
		fly_vel.x = -absf(fly_vel.x)
	if fly_pos.y <= 1.0 or _touching(fly_pos):
		_land()
		return true
	return false

func _touching(p: Vector2) -> bool:
	for r in BubbleEngine.ROWS:
		for c in engine.row_len(r):
			if engine.grid[r][c] != BubbleEngine.EMPTY and p.distance_to(engine.center(r, c)) < 1.75:
				return true
	return false

func _land() -> void:
	flying = false
	var best := [-1, -1]
	var best_d := INF
	for r in BubbleEngine.ROWS:
		for c in engine.row_len(r):
			if engine.can_rest(r, c):
				var d: float = fly_pos.distance_to(engine.center(r, c))
				if d < best_d:
					best_d = d
					best = [r, c]
	if best[0] < 0:
		return
	var res: Dictionary = engine.place(best[0], best[1], cur)
	if res.popped.is_empty():
		_sfx("hit")
		misses += 1
	else:
		_sfx("pickup" if res.dropped.is_empty() else "explode")
		misses = 0
		for p in res.popped:
			_burst(engine.center(p[0], p[1]), p[2], false)
		for p in res.dropped:
			_burst(engine.center(p[0], p[1]), p[2], true)
		best_shot = maxi(best_shot, res.popped.size() + res.dropped.size())
	if engine.count() == 0:
		engine.score += CLEAR_BONUS
		_sfx("powerup")
		for i in BubbleEngine.START_ROWS:
			engine.push_row(rng)
	if misses >= PUSH_EVERY[level]:
		misses = 0
		engine.push_row(rng)
		_sfx("whoosh")
	cur = nxt
	nxt = _pick_color()
	if not engine.colors_present().has(cur) and not engine.colors_present().is_empty():
		cur = _pick_color()
	_update_labels()
	if engine.lost():
		_game_over()

func _burst(at: Vector2, color: int, falling: bool) -> void:
	var v := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 1.0)) if falling \
		else Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-8.0, -2.0))
	bits.append([at, v, color, 1.4 if falling else 0.5])

func _game_over() -> void:
	over = true
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("Game over!") + "\n" + tr("Score: %d") % engine.score
	if info:
		info.add("Games played")
		info.high("Most bubbles in one shot", best_shot)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _draw_board() -> void:
	if engine.grid.is_empty():
		return
	var R := _radius()
	var o := _origin()
	var w := R * 2.0 * BubbleEngine.COLS
	var line_y: float = o.y + (engine.center(BubbleEngine.LOSE_ROW, 0).y - 1.0) * R
	board.draw_rect(Rect2(o, Vector2(w, line_y - o.y)), Color(0.02, 0.03, 0.08, 0.6))
	HomeKit.glow_line(board, o, o + Vector2(w, 0), HomeKit.PURPLE, 2.0)
	HomeKit.glow_line(board, o + Vector2(0, line_y), o + Vector2(w, line_y), Color(HomeKit.PINK, 0.6), 1.5)
	for r in BubbleEngine.ROWS:
		for c in engine.row_len(r):
			var v: int = engine.grid[r][c]
			if v != BubbleEngine.EMPTY:
				_bubble(o + engine.center(r, c) * R, R, v)
	for b in bits:
		_bubble(o + b[0] * R, R * clampf(b[3] * 2.0, 0.2, 1.0), b[2], clampf(b[3] * 2.0, 0.0, 1.0))
	if over:
		return
	# Aim guide: dots along the path, bouncing off the walls.
	var shooter := _shooter()
	if not flying:
		var p := shooter
		var v := aim
		for i in 60:
			p += v * 0.7
			if p.x < 1.0 or p.x > 2.0 * BubbleEngine.COLS - 1.0:
				v.x = -v.x
				p.x = clampf(p.x, 1.0, 2.0 * BubbleEngine.COLS - 1.0)
			if p.y <= 1.0 or _touching(p):
				break
			if i % 2 == 0:
				board.draw_circle(o + p * R, R * 0.12, Color(PALETTE[cur], 0.55))
	HomeKit.glow_circle(board, o + shooter * R, R * 1.45, Color(HomeKit.PURPLE, 0.8), 2.0)
	_bubble(o + (fly_pos if flying else shooter) * R, R, cur)
	_bubble(o + _next_spot() * R, R * 0.75, nxt)
	var font := ThemeDB.fallback_font
	board.draw_string(font, o + (_next_spot() + Vector2(-1.6, 1.9)) * R, tr("Next"), HORIZONTAL_ALIGNMENT_CENTER, R * 3.2, int(R * 0.6), HomeKit.DIM)

func _bubble(at: Vector2, r: float, color: int, alpha: float = 1.0) -> void:
	var col: Color = PALETTE[color % PALETTE.size()]
	board.draw_circle(at, r * 0.94, Color(col.darkened(0.6), alpha))
	board.draw_circle(at, r * 0.7, Color(col, 0.35 * alpha))
	board.draw_arc(at, r * 0.9, 0, TAU, 28, Color(col, alpha), maxf(2.0, r * 0.12), true)
	board.draw_circle(at + Vector2(-r * 0.32, -r * 0.34), r * 0.18, Color(1, 1, 1, 0.75 * alpha))

func _draw_home_logo(c: Control) -> void:
	var r := minf(c.size.y / 5.6, 28.0)
	var mid := Vector2(c.size.x / 2.0, c.size.y / 2.0 - r * 0.8)
	var cells := [[-3, -1, 0], [-1, -1, 1], [1, -1, 2], [3, -1, 3], [-2, 0.73, 1], [0, 0.73, 1], [2, 0.73, 4]]
	for b in cells:
		var p := mid + Vector2(b[0] * r, b[1] * r * 1.0)
		var col: Color = PALETTE[b[2]]
		c.draw_circle(p, r * 0.94, col.darkened(0.6))
		HomeKit.glow_circle(c, p, r * 0.88, col, 2.5, 0.3)
	var s := mid + Vector2(0, r * 2.7)
	HomeKit.glow_line(c, s, s + Vector2(r * 0.9, -r * 1.6), HomeKit.WHITE, 2.0)
	HomeKit.glow_circle(c, s, r * 0.8, PALETTE[1], 2.5, 0.3)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or over:
		return
	SaveUtil.write(SAVE_PATH, {"level": level, "grid": engine.grid, "shifted": engine.shifted,
		"score": engine.score, "cur": cur, "nxt": nxt, "misses": misses, "best": best_shot})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	return tr(LEVELS[clampi(int(d.get("level", 0)), 0, 2)]) + "   ·   " + tr("Score: %d") % int(d.get("score", 0))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or d.get("grid", []).size() != BubbleEngine.ROWS:
		_new_round(1)
		return
	_new_round(clampi(int(d.get("level", 1)), 0, 2))
	for r in BubbleEngine.ROWS:
		engine.shifted[r] = bool(d.shifted[r])
		for c in BubbleEngine.COLS:
			engine.grid[r][c] = int(d.grid[r][c])
	engine.score = int(d.get("score", 0))
	cur = int(d.get("cur", 0))
	nxt = int(d.get("nxt", 0))
	misses = int(d.get("misses", 0))
	best_shot = int(d.get("best", 0))
	_update_labels()
	board.queue_redraw()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
