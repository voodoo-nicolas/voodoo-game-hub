extends Control

## Bubble Pop: aim and fire coloured bubbles at the honeycomb. Three of a
## colour touching pop; anything left hanging falls for bonus points. Miss
## too often and the whole ceiling drops a row; touch the line and it's over.

## Landing menu style: S6 Stone Slabs (docs/MENU_STYLES.md).
const MenuStyles = preload("res://scripts/games/bubble_pop/menu_styles.gd")
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
var bits: Array = []  # falling / bursting bubbles: [pos, vel, colour, life, kind]
## Look-only state (no effect on play): clock, trail, shake, score punch.
var t := 0.0
var trail: Array = []  # recent flying positions, in radii
var shake := 0.0
var flash := 0.0  # whole-field flash after a ceiling drop / clear
## Side walls, in bubble radii, drawn outside the 2*COLS-wide field.
const WALL := 0.55
## Field height needed from the ceiling to just under the shooter ring.
const V_UNITS := 25.8
static var _tex_cache: Dictionary = {}

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
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 12)
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
	info_label.add_theme_font_size_override("font_size", 20)
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
	bm.add_theme_constant_override("margin_bottom", 6)
	bm.add_theme_constant_override("margin_left", 4)
	bm.add_theme_constant_override("margin_right", 4)
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
		# Menu style (docs/MENU_STYLES.md): S6 Stone Slabs, own title font + colours.
		"landing": "slabs",
		"landing_style": MenuStyles,
		"title_font": "res://games/bubble_pop/title.ttf",
		"title_colors": [Color("ff4fa3"), Color("ffd23f"), Color("3ee0ff"), Color("8cff5a")],
		"landing_colors": [Color("2a0b52"), Color("5b1a8a")],
		"menu_font": true,
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
		"helps": [{"text": "🧹 Clear the bottom row", "how": "Pops the lowest row of bubbles.", "action": _help_clear}],
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
	return maxf(1.0, minf(board.size.x / (2.0 * (BubbleEngine.COLS + WALL)), board.size.y / V_UNITS))

func _origin() -> Vector2:
	var r := _radius()
	return Vector2((board.size.x - r * 2.0 * BubbleEngine.COLS) / 2.0, r * 0.25)

## The shooter sits at the foot of the board: on tall phones the field
## stretches down (more room to aim) while the grid and lose line stay put.
func _shooter() -> Vector2:
	var base := 1.0 + (BubbleEngine.ROWS - 1) * sqrt(3.0) + 0.6
	var room := (board.size.y - _origin().y) / _radius() - 1.75
	return Vector2(BubbleEngine.COLS, maxf(base, room))

func _next_spot() -> Vector2:
	return _shooter() + Vector2(4.4, 0.2)

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
	trail.clear()
	fly_pos = _shooter()
	fly_vel = aim * SPEED
	_sfx("shoot")

func _process(delta: float) -> void:
	t += delta
	shake = maxf(0.0, shake - delta * 2.5)
	flash = maxf(0.0, flash - delta * 1.8)
	if not (home and home.visible):
		board.queue_redraw()  # idle shimmer; every draw is a cheap texture blit
	if flying:
		var steps := int(ceil(SPEED * delta / 0.25))
		for i in steps:
			if _step(delta / steps):
				break
		board.queue_redraw()
	if not bits.is_empty():
		for b in bits:
			b[0] += b[1] * delta
			if b[4] <= 1 or b[4] == 5:
				b[1].y += 40.0 * delta
			b[3] -= delta
		bits = bits.filter(func(b): return b[3] > 0.0)
		board.queue_redraw()

## Moves the flying bubble one small step; true once it has stuck.
func _step(dt: float) -> bool:
	fly_pos += fly_vel * dt
	trail.push_front(fly_pos)
	if trail.size() > 10:
		trail.pop_back()
	var w := 2.0 * BubbleEngine.COLS
	if fly_pos.x < 1.0:
		fly_pos.x = 2.0 - fly_pos.x
		fly_vel.x = absf(fly_vel.x)
		_wall_hit(fly_pos)
	elif fly_pos.x > w - 1.0:
		fly_pos.x = 2.0 * (w - 1.0) - fly_pos.x
		fly_vel.x = -absf(fly_vel.x)
		_wall_hit(fly_pos)
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
		bits.append([engine.center(best[0], best[1]), Vector2.ZERO, cur, 0.35, 3])
	else:
		_sfx("pickup" if res.dropped.is_empty() else "explode")
		misses = 0
		for p in res.popped:
			_burst(engine.center(p[0], p[1]), p[2], false)
		for p in res.dropped:
			_burst(engine.center(p[0], p[1]), p[2], true)
		best_shot = maxi(best_shot, res.popped.size() + res.dropped.size())
		var n: int = res.popped.size() + res.dropped.size()
		shake = minf(0.6, 0.12 + n * 0.03)
		_punch_score()
		if res.points > 0:
			bits.append([engine.center(best[0], best[1]), Vector2(0, -2.5), cur, 1.0, 4, "+%d" % res.points])
	if engine.count() == 0:
		engine.score += CLEAR_BONUS
		_sfx("powerup")
		flash = 1.0
		for i in BubbleEngine.START_ROWS:
			engine.push_row(rng)
	if misses >= PUSH_EVERY[level]:
		misses = 0
		engine.push_row(rng)
		_sfx("whoosh")
		shake = 0.5
		flash = 0.5
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
	bits.append([at, v, color, 1.4 if falling else 0.5, 1 if falling else 0])
	if not falling:
		bits.append([at, Vector2.ZERO, color, 0.4, 2])  # shock ring
		for i in 5:  # sparks
			var a := rng.randf() * TAU
			bits.append([at, Vector2.from_angle(a) * rng.randf_range(5.0, 11.0), color, rng.randf_range(0.3, 0.55), 5])

func _wall_hit(at: Vector2) -> void:
	bits.append([at, Vector2.ZERO, cur, 0.3, 6])

func _punch_score() -> void:
	score_label.pivot_offset = score_label.size / 2.0
	var tw := score_label.create_tween()
	tw.tween_property(score_label, "scale", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

## Look textures, made once per run: a glossy bubble per colour, a soft glow
## and a wall strip. Each bubble then costs one texture blit instead of four
## circle draws (Godot 4.7 draw_circle is ~100 µs each).
static func _bubble_tex(col: Color) -> Texture2D:
	var key := "b" + col.to_html()
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n / 2.0
	var hl := Vector2(c - n * 0.17, c - n * 0.19)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(Vector2(c, c)) / (n * 0.5)  # 0 centre .. 1 edge
			if d > 1.0:
				continue
			var body := col.lightened(0.15).lerp(col.darkened(0.5), smoothstep(0.25, 1.0, d))
			var shade := clampf((p.y - c) / n + 0.5, 0.0, 1.0)  # darker toward the bottom
			body = body.darkened(shade * 0.25)
			var rim := smoothstep(0.72, 0.9, d) * (1.0 - smoothstep(0.93, 1.0, d))
			body = body.lerp(col.lightened(0.25), rim * 0.9)
			var h := 1.0 - clampf(p.distance_to(hl) / (n * 0.26), 0.0, 1.0)
			body = body.lerp(Color.WHITE, pow(h, 2.2) * 0.8)
			var under := 1.0 - clampf(absf(d - 0.66) / 0.08, 0.0, 1.0)
			if p.y > c + n * 0.18:
				body = body.lerp(col.lightened(0.5), under * 0.35)  # bounce light
			body.a = 1.0 - smoothstep(0.96, 1.0, d)
			img.set_pixel(x, y, body)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func _glow_tex() -> Texture2D:
	if _tex_cache.has("glow"):
		return _tex_cache["glow"]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 2.2)))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache["glow"] = tex
	return tex

static func _ring_tex() -> Texture2D:
	if _tex_cache.has("ring"):
		return _tex_cache["ring"]
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - absf(d - 0.85) / 0.13, 0.0, 1.0), 1.5)))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache["ring"] = tex
	return tex

## Wall strip: a lit glass pillar (left-to-right shading), tiled vertically.
static func _wall_tex() -> Texture2D:
	if _tex_cache.has("wall"):
		return _tex_cache["wall"]
	var w := 24
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := Color("2a0b52")
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var col := base.lerp(HomeKit.PURPLE, 0.35 + 0.4 * sin(u * PI))
			col = col.lerp(Color.WHITE, pow(1.0 - absf(u - 0.3) / 0.3, 4.0) * 0.35 if absf(u - 0.3) < 0.3 else 0.0)
			if y % 32 < 2:
				col = col.darkened(0.35)  # panel seams
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache["wall"] = tex
	return tex

func _glow(at: Vector2, r: float, col: Color) -> void:
	board.draw_texture_rect(_glow_tex(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

func _draw_board() -> void:
	if engine.grid.is_empty():
		return
	var R := _radius()
	var o := _origin()
	if shake > 0.0:
		o += Vector2(sin(t * 61.0), cos(t * 47.0)) * shake * R * 0.25
	var w := R * 2.0 * BubbleEngine.COLS
	var shooter := _shooter()
	var floor_y := o.y + (shooter.y + 1.6) * R
	var line_y: float = o.y + (engine.center(BubbleEngine.LOSE_ROW, 0).y - 1.0) * R
	var field := Rect2(o, Vector2(w, floor_y - o.y))
	# Playfield: deep glass panel, lighter at the top, faint honeycomb behind.
	board.draw_rect(field, Color(0.03, 0.02, 0.09, 0.82))
	board.draw_rect(Rect2(o, Vector2(w, R * 6.0)), Color(HomeKit.PURPLE, 0.08))
	board.draw_rect(Rect2(o, Vector2(w, R * 2.0)), Color(HomeKit.PURPLE, 0.08))
	for i in 4:  # slow drifting light motes behind the bubbles
		var mx := o.x + w * fposmod(0.17 + i * 0.29 + sin(t * 0.13 + i) * 0.05, 1.0)
		var my := floor_y - fposmod(t * R * (0.6 + i * 0.25) + i * 211.0, floor_y - o.y)
		_glow(Vector2(mx, my), R * (2.5 + i), Color(PALETTE[i], 0.07))
	# Danger zone under the lose line, pulsing harder when bubbles get close.
	var low := 0
	for r in BubbleEngine.ROWS:
		if engine.grid[r].any(func(v): return v != BubbleEngine.EMPTY):
			low = r
	var danger := clampf(float(low - (BubbleEngine.LOSE_ROW - 4)) / 3.0, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * (3.0 + danger * 5.0))
	board.draw_rect(Rect2(Vector2(o.x, line_y), Vector2(w, floor_y - line_y)), Color(HomeKit.PINK, 0.04 + 0.1 * danger * pulse))
	# Side walls: lit pillars the shots bounce off.
	var ww := WALL * R
	var wall := _wall_tex()
	for side in [o.x - ww, o.x + w]:
		board.draw_texture_rect(wall, Rect2(Vector2(side, o.y - R * 0.25), Vector2(ww, floor_y - o.y + R * 0.25)), true)
		HomeKit.glow_line(board, Vector2(side + (ww if side < o.x else 0.0), o.y), Vector2(side + (ww if side < o.x else 0.0), floor_y), Color(HomeKit.CYAN, 0.55), 1.5)
	# Ceiling bar and floor.
	board.draw_texture_rect(wall, Rect2(Vector2(o.x - ww, o.y - R * 0.25), Vector2(w + ww * 2.0, R * 0.25)), true)
	HomeKit.glow_line(board, o, o + Vector2(w, 0), HomeKit.PURPLE, 2.0)
	HomeKit.glow_line(board, Vector2(o.x, floor_y), Vector2(o.x + w, floor_y), Color(HomeKit.PURPLE, 0.6), 1.5)
	# Lose line: dashed, brighter as danger grows.
	var lc := Color(HomeKit.PINK, 0.45 + 0.5 * danger * pulse)
	var dash := R * 0.6
	var x := o.x
	var segs := PackedVector2Array()
	while x < o.x + w:
		segs.append(Vector2(x, line_y))
		segs.append(Vector2(minf(x + dash, o.x + w), line_y))
		x += dash * 1.8
	board.draw_multiline(segs, lc, 2.0)
	if danger > 0.0:
		board.draw_rect(Rect2(Vector2(o.x, line_y - R * 0.4), Vector2(w, R * 0.8)), Color(HomeKit.PINK, 0.08 * danger * pulse))
	# Bubbles.
	for r in BubbleEngine.ROWS:
		for c in engine.row_len(r):
			var v: int = engine.grid[r][c]
			if v != BubbleEngine.EMPTY:
				var p: Vector2 = o + engine.center(r, c) * R
				p.y += sin(t * 1.6 + c * 0.7 + r * 1.1) * R * 0.03  # tiny idle sway
				_bubble(p, R, v)
	# Effects.
	for b in bits:
		var at: Vector2 = o + b[0] * R
		var col: Color = PALETTE[int(b[2]) % PALETTE.size()]
		match int(b[4]):
			0:  # popping: swells and fades
				var k := clampf(b[3] / 0.5, 0.0, 1.0)
				_glow(at, R * 2.2, Color(col, 0.5 * k))
				_bubble(at, R * (1.0 + (1.0 - k) * 0.5), b[2], k)
			1:  # falling: tumbles away
				_bubble(at, R * clampf(b[3], 0.5, 1.0), b[2], clampf(b[3] * 1.5, 0.0, 1.0))
			2:  # shock ring
				var k: float = 1.0 - b[3] / 0.4
				var rr: float = R * (1.0 + k * 1.8)
				board.draw_texture_rect(_ring_tex(), Rect2(at - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(col.lightened(0.3), 1.0 - k))
			3:  # thud when a shot sticks without popping
				var k: float = 1.0 - b[3] / 0.35
				var rr: float = R * (1.0 + k * 0.6)
				board.draw_texture_rect(_ring_tex(), Rect2(at - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(1, 1, 1, 0.5 * (1.0 - k)))
			4:  # floating "+points"
				var a := clampf(b[3] * 1.5, 0.0, 1.0)
				HomeKit.glow_text(board, at, b[5], int(R * 0.9), Color(HomeKit.GOLD.lightened(0.3), a))
			5:  # spark
				_glow(at, R * 0.45, Color(col.lightened(0.5), clampf(b[3] * 2.5, 0.0, 1.0)))
			6:  # wall spark
				var k: float = b[3] / 0.3
				_glow(at + Vector2(-1.0 if b[0].x < BubbleEngine.COLS else 1.0, 0) * R, R * 1.6, Color(HomeKit.CYAN, 0.7 * k))
	if flash > 0.0:
		board.draw_rect(field, Color(1, 1, 1, 0.12 * flash))
	if over:
		return
	# Aim guide: dots along the path, bouncing off the walls, shrinking with distance.
	if not flying:
		var p := shooter
		var v := aim
		var pts: Array = []
		for i in 80:
			p += v * 0.7
			if p.x < 1.0 or p.x > 2.0 * BubbleEngine.COLS - 1.0:
				v.x = -v.x
				p.x = clampf(p.x, 1.0, 2.0 * BubbleEngine.COLS - 1.0)
			if p.y <= 1.0 or _touching(p):
				break
			pts.append(p)
		var phase := fposmod(t * 4.0, 2.0)
		for i in pts.size():
			if (i + int(phase)) % 2 == 0:
				var fade := 1.0 - float(i) / maxf(1.0, pts.size()) * 0.7
				_glow(o + pts[i] * R, R * 0.32 * fade, Color(PALETTE[cur].lightened(0.3), 0.9 * fade))
		if not pts.is_empty():  # ghost of where it will land
			board.draw_texture_rect(_ring_tex(), Rect2(o + pts[-1] * R - Vector2(R, R), Vector2(R, R) * 2.0), false, Color(PALETTE[cur], 0.35 + 0.2 * sin(t * 6.0)))
	# Launcher: glowing ring with a pointer along the aim.
	var sp := o + shooter * R
	_glow(sp, R * 2.6, Color(PALETTE[cur], 0.22 + 0.05 * sin(t * 3.0)))
	HomeKit.glow_circle(board, sp, R * 1.45, Color(HomeKit.PURPLE, 0.85), 2.0)
	if not flying:
		HomeKit.glow_line(board, sp + aim * R * 1.55, sp + aim * R * 2.25, Color(PALETTE[cur], 0.9), 2.5)
	# Trail behind the flying shot.
	for i in trail.size():
		var k := 1.0 - float(i) / trail.size()
		_glow(o + trail[i] * R, R * (0.9 * k + 0.2), Color(PALETTE[cur], 0.35 * k))
	if flying:
		_glow(o + fly_pos * R, R * 1.8, Color(PALETTE[cur], 0.35))
	_bubble(o + (fly_pos if flying else shooter + Vector2(0, sin(t * 2.4) * 0.05)) * R, R, cur)
	_bubble(o + _next_spot() * R, R * 0.75, nxt)
	var font := board.get_theme_default_font()
	board.draw_string(font, o + (_next_spot() + Vector2(-1.6, -1.15)) * R, tr("Next"), HORIZONTAL_ALIGNMENT_CENTER, R * 3.2, int(R * 0.6), HomeKit.DIM)

func _bubble(at: Vector2, r: float, color: int, alpha: float = 1.0) -> void:
	var col: Color = PALETTE[color % PALETTE.size()]
	board.draw_texture_rect(_bubble_tex(col), Rect2(at - Vector2(r, r) * 0.96, Vector2(r, r) * 1.92), false, Color(1, 1, 1, alpha))

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

# ---------- helps (STANDARDS §17) ----------

## 🧹 help: the lowest row of bubbles goes.
func _help_clear() -> bool:
	if not started or over or flying:
		return false
	for r in range(engine.grid.size() - 1, -1, -1):
		var row: Array = engine.grid[r]
		if row.any(func(v): return v != BubbleEngine.EMPTY):
			for c in row.size():
				row[c] = BubbleEngine.EMPTY
			_sfx("powerup")
			board.queue_redraw()
			return true
	return false
