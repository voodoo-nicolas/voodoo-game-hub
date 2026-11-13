extends Control

## Tilt Maze -- tilt the phone to roll a marble through the maze into the goal
## hole; the other holes send it back to the start. Same campaign layout as
## Maze Trail: 195 mazes in six tiers (Very Easy .. Insane) with a challenge
## maze from the next tier after every 10 (tilt_maze_engine.gd). Also a Daily
## Maze. Controls: the phone's tilt (calibrated to how you hold it at the start
## of each maze, ◎ to recentre), or a touch joystick where there is no sensor
## (PC, browsers); arrow keys on a keyboard. All art drawn in code.

const TiltEngine = preload("res://scripts/games/tilt_maze/tilt_maze_engine.gd")
const Shop = preload("res://scripts/games/tilt_maze/tilt_maze_shop.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SoundLib = preload("res://scripts/games/tilt_maze/sound_lib.gd")
## Landing menu style: S7 Diegetic Cinema (docs/MENU_STYLES.md).
const MenuStyles = preload("res://scripts/games/tilt_maze/menu_styles.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/tilt_maze/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/tilt_maze/tilt_maze_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://tilt_maze_save.json"
const PROGRESS_PATH := "user://tilt_maze_progress.json"
const PREFS_PATH := "user://tilt_maze_prefs.json"
## Owner's Landing picture (2026-11-07). His version with "Tilt Maze" painted in
## (reference/art/games/tilt_maze_title_src.jpg) is not used: on a portrait
## phone the painted title is wider than the screen and gets cut, and Spanish
## needs the translated title, which the kit prints.
const ART := "res://games/tilt_maze/landing_bg.jpg"

## Hints (owner, 2026-11-01, every game): at most 3, +1 every 24 h, per game.
## Owner 2026-11-08: the 24 h restart with every hint used; the pool is the kit's (STANDARDS §17).
const MAX_HINTS := 3
const HINT_REFILL_SECS := 86400
const HINT_SECONDS := 5.0
const READY_TIME := 0.9  # the marble waits while the tilt calibrates
const STICK_RADIUS := 110.0  # touch joystick: this far = full tilt
## Full tilt at this many g of sideways gravity (about 14, 20 and 30 degrees).
const SENSITIVITY := [0.5, 0.35, 0.25]
const SENS_NAMES := ["Low", "Normal", "High"]
const TIER_COLORS := [Color("6fd36f"), Color("4fc3f7"), Color("ffd54f"), Color("ff9f43"), Color("ff5f6d"), Color("c86bff")]
## Daily maze tier by weekday (0 = Sunday .. 6 = Saturday).
const DAILY_TIER := [4, 1, 2, 2, 3, 3, 5]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var mode: String = "campaign"  # campaign | daily
var cur_level: int = 1
var cur_tier: int = 0
var cur_seed: int = 0
var started := false  # a real game is on (not just the maze behind Home)
var solved := false
var progress: Dictionary = {}
var prefs: Dictionary = {}

var ready_t: float = 0.0
var grav := Vector3.ZERO  # smoothed accelerometer
var grav_base := Vector3.ZERO  # how the phone was held when calibrated
var calib_n: int = 0
var has_sensor := false
var stick_on := false
var stick_from := Vector2.ZERO
var stick_at := Vector2.ZERO
var tilt := Vector2.ZERO
var hint_path: Array = []
var hint_t: float = 0.0
var win_t: float = -1.0
var pulse_t: float = 0.0
var trail_pts: Array = []  # recent marble centres (cells), for the shop effects
var shop_body: VBoxContainer

var board: Control
var title_label: Label
var status_label: Label
var tip_label: Label
var hint_btn: Button
var end_card: Control
var map_layer: Control
var map_drag = null
var map_from_landing := false
var bg: ColorRect
var skin: String = "classic"
var _geo_key := ""
var _wall_lines := PackedVector2Array()
var _posts: Array = []
var _disc: Texture2D

func _ready() -> void:
	preload("res://scripts/games/tilt_maze/tilt_maze_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = TiltEngine.new()
	_load_progress()
	var p = SaveUtil.read(PREFS_PATH)
	prefs = p if p is Dictionary else {}
	_disc = _make_disc()
	_build_ui()
	_play_music()
	_begin("campaign", 1, TiltEngine.seed_for(1))
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()
	elif what == NOTIFICATION_UNPAUSED:
		_recalibrate()  # back from the pause menu: hold the phone however you like

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = ColorRect.new()
	bg.color = Color("3b2414")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 24)
	top.add_theme_constant_override("margin_left", 14)
	top.add_theme_constant_override("margin_right", 14)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(72, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	bar.add_child(title_label)
	hint_btn = Button.new()
	hint_btn.custom_minimum_size = Vector2(96, 64)
	hint_btn.pressed.connect(_on_hint)
	bar.add_child(hint_btn)
	var centre_btn := Button.new()
	centre_btn.text = "◎"
	centre_btn.custom_minimum_size = Vector2(72, 64)
	centre_btn.pressed.connect(_recalibrate)
	bar.add_child(centre_btn)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(72, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(_on_board_resized)
	root.add_child(board)

	tip_label = Label.new()
	tip_label.add_theme_font_size_override("font_size", 22)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(0, 58)
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_bottom", 22)
	tm.add_theme_constant_override("margin_left", 20)
	tm.add_theme_constant_override("margin_right", 20)
	tm.add_child(tip_label)
	root.add_child(tm)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var cfg := {
		# Menu style (docs/MENU_STYLES.md): S7 Diegetic Cinema; colours analogous violet/indigo/blue.
		"landing": "cinema",
		"landing_style": MenuStyles,
		"title_font": "res://games/tilt_maze/title.ttf",
		"title_colors": [Color("b06aff"), Color("7a6aff"), Color("4c8cff")],
		"landing_colors": [Color("0a0618"), Color("1a1440")],
		"menu_color": Color("b06aff"),
		"landing_art": true,
		"help": HELP,
		"info": info,
		"accent": Color("4fc3f7"),
		"subtitle": "Tilt your phone, roll the marble home, miss the holes.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🗺 Campaign", "sub": "195 mazes · collect stars", "action": _start_campaign},
		],
		"play": [
			{"text": "📋 Level Select", "sub": "Pick any maze you have opened", "action": _open_map_from_landing, "card": true},
			{"text": "📅 Daily Maze", "sub": "One maze a day, the same for everyone", "action": _start_daily},
			{"text": "🛒 Marble Shop", "sub": "Spend your coins on marbles and effects", "action": _open_shop, "card": true},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "💡 Hint", "how": "Shows the way ahead for a few seconds.", "action": _hint_now}],
		"board": "Mazes cleared",
		"board_note": "Mazes cleared in any mode.",
		"options": _add_game_options,
	}
	cfg["art"] = ART
	home = HomeKit.new(cfg)
	add_child(home)
	home.track_help_button(hint_btn)
	if info:
		add_child(info)

func _add_game_options(body: VBoxContainer) -> void:
	body.add_child(home.section("Controls"))
	body.add_child(home.choice_row(["Tilt the phone", "Touch joystick"], 1 if _touch_pref() else 0, _pick_controls))
	body.add_child(HomeKit.label(tr("Tilt needs a motion sensor. Without one (PC, some browsers) the touch joystick is used anyway."), 22, HomeKit.DIM, true))
	body.add_child(home.section("Tilt sensitivity"))
	body.add_child(home.choice_row(SENS_NAMES, int(prefs.get("sens", 1)), _pick_sens))
	body.add_child(home.section("Left and right"))
	body.add_child(home.choice_row(["Normal", "Flipped"], int(prefs.get("flip", 0)) % 2, _pick_flip_x))
	body.add_child(home.section("Up and down"))
	body.add_child(home.choice_row(["Normal", "Flipped"], int(prefs.get("flip", 0)) / 2, _pick_flip_y))
	body.add_child(HomeKit.label(tr("If the marble rolls the wrong way on your phone, flip it here."), 22, HomeKit.DIM, true))

func _touch_pref() -> bool:
	return bool(prefs.get("touch", false))

func _pick_controls(i: int) -> void:
	prefs["touch"] = i == 1
	SaveUtil.write(PREFS_PATH, prefs)
	_labels()

func _pick_sens(i: int) -> void:
	prefs["sens"] = clampi(i, 0, SENSITIVITY.size() - 1)
	SaveUtil.write(PREFS_PATH, prefs)

## prefs "flip": bit 1 = left/right flipped, bit 2 = up/down flipped.
func _pick_flip_x(i: int) -> void:
	prefs["flip"] = (int(prefs.get("flip", 0)) & 2) | (1 if i == 1 else 0)
	SaveUtil.write(PREFS_PATH, prefs)

func _pick_flip_y(i: int) -> void:
	prefs["flip"] = (int(prefs.get("flip", 0)) & 1) | (2 if i == 1 else 0)
	SaveUtil.write(PREFS_PATH, prefs)

func _on_board_resized() -> void:
	_geo_key = ""
	board.queue_redraw()

# ---------- game flow ----------

func _start_campaign() -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_level(_next_level())

func _start_level(lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_close_map()
	_begin("campaign", lvl, TiltEngine.seed_for(lvl))

func _start_daily() -> void:
	_close_map()
	SaveUtil.delete(SAVE_PATH)
	_begin("daily", 0, _today() * 6151 + 29)

func _restart() -> void:
	_begin(mode, cur_level, cur_seed)

func _begin(m: String, lvl: int, seed_value: int) -> void:
	mode = m
	cur_level = lvl
	cur_seed = seed_value
	var params: Dictionary
	if m == "daily":
		cur_tier = DAILY_TIER[_weekday()]
		params = TiltEngine.params_for_tier(cur_tier, 10 + _today() % 20)
	else:
		cur_tier = int(TiltEngine.level_info(lvl).tier)
		params = TiltEngine.params_for(lvl)
	engine.generate(params, seed_value)
	solved = false
	started = true
	hint_path.clear()
	hint_t = 0.0
	win_t = -1.0
	trail_pts.clear()
	_geo_key = ""
	_close_end()
	_close_map()
	_recalibrate()
	_labels()
	_status()
	board.queue_redraw()

func _recalibrate() -> void:
	ready_t = READY_TIME
	calib_n = 0
	grav_base = Vector3.ZERO

func _labels() -> void:
	var tier_name: String = tr(TiltEngine.TIERS[cur_tier])
	var col: Color = TIER_COLORS[cur_tier]
	if mode == "daily":
		title_label.text = tr("📅 Daily Maze")
		tip_label.text = tr("Today: %s. The same maze for everyone.") % tier_name
	else:
		title_label.text = tr("Maze %d") % cur_level
		if TiltEngine.level_info(cur_level).sneak:
			tip_label.text = tr("⚡ Challenge maze: a taste of %s!") % tier_name
		elif _using_touch():
			tip_label.text = tier_name + " · " + tr("Drag anywhere to tilt the maze.")
		else:
			tip_label.text = tier_name + " · " + tr("Tilt the phone to roll. ◎ recentres the tilt.")
	tip_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.35))
	title_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.55))
	_hint_label()

func _status() -> void:
	status_label.text = "⏱ " + _clock(engine.time) + " / " + _clock(engine.par) + "   ·   " + tr("Falls: %d") % engine.falls

static func _clock(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]

static func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

static func _weekday() -> int:
	return int(Time.get_datetime_dict_from_system().get("weekday", 0))

# ---------- input ----------

func _using_touch() -> bool:
	return _touch_pref() or not has_sensor

func _read_tilt(delta: float) -> Vector2:
	var raw: Vector3 = Input.get_accelerometer()
	if raw.length() > 2.0:
		has_sensor = true
		grav = raw if grav == Vector3.ZERO else grav.lerp(raw, minf(1.0, delta * 12.0))
	var t := Vector2.ZERO
	if _using_touch():
		if stick_on:
			t = (stick_at - stick_from) / STICK_RADIUS
	elif has_sensor:
		var sens: float = SENSITIVITY[clampi(int(prefs.get("sens", 1)), 0, SENSITIVITY.size() - 1)] * 9.81
		var d := grav - grav_base
		# Godot reports gravity's pull in the phone's frame: +x towards the right
		# edge, +y towards the top. The marble rolls the way gravity pulls.
		t = Vector2(d.x, -d.y) / sens
	var flip: int = int(prefs.get("flip", 0))
	if flip & 1:
		t.x = -t.x
	if flip & 2:
		t.y = -t.y
	# Arrow keys (PC).
	var k := Vector2(float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
	if k != Vector2.ZERO:
		t = k * 0.8
	return t.limit_length(1.0)

func _on_board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		stick_on = event.pressed and _using_touch()
		stick_from = event.position
		stick_at = event.position
	elif event is InputEventMouseMotion and stick_on:
		stick_at = event.position

# ---------- the loop ----------

func _process(delta: float) -> void:
	pulse_t += delta
	tilt = _read_tilt(delta)
	if ready_t > 0.0:
		ready_t -= delta
		if has_sensor:
			grav_base = (grav_base * calib_n + grav) / (calib_n + 1)
			calib_n += 1
		tilt = Vector2.ZERO
	if started and not solved and ready_t <= 0.0:
		var before := int(engine.time)
		for ev in engine.update(minf(delta, 0.05), tilt):
			_on_event(ev)
		if int(engine.time) != before:
			_status()
	if started and engine.falling_t < 0.0 and not engine.won:
		if trail_pts.is_empty() or (trail_pts[trail_pts.size() - 1] as Vector2).distance_to(engine.pos) > 0.02:
			trail_pts.append(engine.pos)
			if trail_pts.size() > Shop.TRAIL_LEN:
				trail_pts.pop_front()
	if hint_t > 0.0:
		hint_t -= delta
		if hint_t <= 0.0:
			hint_path.clear()
	if win_t >= 0.0:
		win_t += delta
	board.queue_redraw()

func _on_event(ev: Array) -> void:
	match ev[0]:
		"hit":
			SoundLib.play(self, "impact/glass_light", clampf(-22.0 + float(ev[1]) * 4.0, -22.0, 0.0))
		"fall":
			SoundLib.play(self, "impact/soft_medium", -2.0)
			_sfx("invalid")
			hint_path.clear()
			trail_pts.clear()
			_status()
		"back":
			_status()
		"win":
			_on_solved()

# ---------- hints ----------

## The kit's pool (STANDARDS §17): 3 max, one back 24 h after the last use.
func _hints_now() -> int:
	return HomeKit.helps_left("tilt_maze")

func _hint_label() -> void:
	if home:
		home.refresh_helps()
	else:
		hint_btn.text = "💡%d" % _hints_now()

func _on_hint() -> void:
	if home:
		home.try_help(_hint_now)

## 💡 help: shows the way ahead for a few seconds.
func _hint_now() -> bool:
	if solved or not started:
		return false
	var way: Array = engine.safe_way(engine.pos)
	if way.is_empty():
		return false
	hint_path = way
	hint_t = HINT_SECONDS
	_sfx("notify")
	return true

# ---------- winning ----------

func _on_solved() -> void:
	solved = true
	win_t = 0.0
	hint_path.clear()
	SaveUtil.delete(SAVE_PATH)
	SoundLib.play(self, "reward/coin_plingy")
	_sfx("win")
	var stars: int = engine.stars()
	var note := ""
	var old_stars: int = int(progress.stars.get(str(cur_level), 0))
	if info:
		info.add("Mazes cleared")
		info.result("win")
		if engine.falls == 0:
			info.add("Clean runs")
	match mode:
		"campaign":
			var key := str(cur_level)
			if stars > int(progress.stars.get(key, 0)):
				progress.stars[key] = stars
			var best: float = float(progress.best.get(key, 0.0))
			if best <= 0.0 or engine.time < best:
				progress.best[key] = snappedf(engine.time, 0.01)
				if best > 0.0:
					note = tr("New best time!")
			var earned: int = Shop.earn_campaign(old_stars, stars, engine.falls)
			progress["coins"] = Shop.coins(progress) + earned
			var coin_line: String = tr("+%d coins (%d)") % [earned, Shop.coins(progress)]
			note = coin_line if note == "" else note + "\n" + coin_line
			_save_progress()
			if info:
				info.high("Highest maze cleared", _cleared())  # levels open in order, so cleared = highest
				info.high("Campaign stars", _total_stars())
				info.high("Highest tier reached", _highest_tier() + 1)
		"daily":
			var day := _today()
			if int(progress.get("daily_day", 0)) != day:
				if int(progress.get("daily_day", 0)) == day - 1:
					progress.daily_streak = int(progress.get("daily_streak", 0)) + 1
				else:
					progress.daily_streak = 1
				progress.daily_day = day
				var earned_d: int = Shop.earn_daily(int(progress.daily_streak), engine.falls)
				progress["coins"] = Shop.coins(progress) + earned_d
				_save_progress()
				note = tr("Daily streak: %d") % int(progress.daily_streak) + "\n" + tr("+%d coins (%d)") % [earned_d, Shop.coins(progress)]
				if info:
					info.high("Longest daily streak", int(progress.daily_streak))
			else:
				note = tr("Already done today. Come back tomorrow for a new one.")
	if info:
		info.celebrate(tr("In the hole!"))
	var msg := "⏱ %.1f s / %s   ·   " % [engine.time, _clock(engine.par)] + tr("Falls: %d") % engine.falls
	if note != "":
		msg += "\n" + note
	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_callback(_show_solved_card.bind(stars, msg))

func _show_solved_card(stars: int, msg: String) -> void:
	var star_text := ""
	for i in 3:
		star_text += "★" if i < stars else "☆"
	var buttons: Array = []
	if mode == "campaign":
		if cur_level < TiltEngine.LEVEL_COUNT:
			var nxt := TiltEngine.level_info(cur_level + 1)
			var label := tr("Next maze")
			if nxt.sneak:
				label = tr("⚡ Next: challenge maze")
			elif TiltEngine.block_of(cur_level + 1) != TiltEngine.block_of(cur_level):
				label = tr("Next: %s") % tr(TiltEngine.TIERS[TiltEngine.block_of(cur_level + 1)])
			buttons.append({"text": label, "action": _start_level.bind(cur_level + 1)})
		else:
			msg += "\n" + tr("All 195 mazes cleared!")
		if stars < 3:
			buttons.append({"text": tr("Try for 3 stars"), "action": _restart})
		buttons.append({"text": tr("📋 Levels"), "action": _open_map.bind(false)})
	else:
		buttons.append({"text": tr("Play again"), "action": _restart})
	buttons.append({"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home})
	_show_card(tr("In the hole!"), star_text, msg, buttons)

func _show_card(title_text: String, stars_text: String, msg: String, buttons: Array) -> void:
	_close_end()
	var accent: Color = TIER_COLORS[cur_tier]
	end_card = ColorRect.new()
	(end_card as ColorRect).color = Color(0, 0, 0, 0.7)
	end_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(end_card)
	end_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	end_card.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.03, 0.96) if _is_classic() else Color(0.05, 0.07, 0.16, 0.96)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = accent
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if stars_text != "":
		var s := Label.new()
		s.text = stars_text
		s.add_theme_font_size_override("font_size", 80)
		s.add_theme_color_override("font_color", Color("ffd54f"))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
	var m := Label.new()
	m.text = msg
	m.add_theme_font_size_override("font_size", 26)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size = Vector2(380, 0)
	box.add_child(m)
	for spec in buttons:
		var b := Button.new()
		b.text = spec.text
		b.custom_minimum_size = Vector2(380, 66)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_card_button.bind(spec.action))
		box.add_child(b)

func _card_button(action: Callable) -> void:
	if action.is_valid():
		action.call()

func _close_end() -> void:
	if end_card and is_instance_valid(end_card):
		end_card.queue_free()
	end_card = null

# ---------- 🛒 Marble Shop ----------

func _open_shop() -> void:
	var parts: Array = home.card(tr("🛒 Marble Shop"))
	shop_body = parts[1]
	_fill_shop()
	home.show_card(parts[0])

func _fill_shop() -> void:
	if shop_body == null or not is_instance_valid(shop_body):
		return
	for c in shop_body.get_children():
		c.queue_free()
	shop_body.add_child(HomeKit.label(tr("🪙 %d coins") % Shop.coins(progress), 30, HomeKit.GOLD))
	shop_body.add_child(HomeKit.label(tr("Earn coins by clearing mazes: more for stars and for no falls, and every day from the 📅 Daily Maze. Coins can't be bought."), 21, HomeKit.DIM, true))
	shop_body.add_child(home.section("Marbles"))
	for it in Shop.MARBLES:
		shop_body.add_child(_shop_row("marble", it))
	shop_body.add_child(home.section("Effects"))
	for it in Shop.EFFECTS:
		shop_body.add_child(_shop_row("fx", it))

func _shop_row(kind: String, item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(110 if kind == "fx" else 90, 90)
	pic.draw.connect(Shop.draw_swatch.bind(pic, _disc, kind, str(item.id), not _is_classic()))
	row.add_child(pic)
	var name_l := HomeKit.label(tr(item.name), 26, HomeKit.WHITE, true)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var owned: bool = Shop.owns(progress, kind, str(item.id))
	var in_use: bool = Shop.equipped(progress, kind) == str(item.id)
	var text: String
	var color: Color = HomeKit.BUTTON
	if in_use:
		text = tr("✓ In use")
	elif owned:
		text = tr("Use")
	else:
		text = "🪙 %d" % int(item.price)
		color = HomeKit.GO if Shop.coins(progress) >= int(item.price) else HomeKit.BUTTON
	var b := HomeKit.neon_button(text, color, 22, 64)
	b.custom_minimum_size.x = 150
	b.disabled = in_use or (not owned and Shop.coins(progress) < int(item.price))
	b.pressed.connect(_on_shop_pick.bind(kind, str(item.id)))
	row.add_child(b)
	return row

func _on_shop_pick(kind: String, id: String) -> void:
	var had: bool = Shop.owns(progress, kind, id)
	if Shop.pick(progress, kind, id):
		_save_progress()
		if not had:
			SoundLib.play(self, "rpg/handle_coins")
		_fill_shop()
		board.queue_redraw()

# ---------- progress and the level map ----------

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	progress = d if d is Dictionary else {}
	if not progress.get("stars") is Dictionary:
		progress["stars"] = {}
	if not progress.get("best") is Dictionary:
		progress["best"] = {}

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)

func _cleared() -> int:
	var n := 0
	for k in progress.stars:
		if int(progress.stars[k]) > 0:
			n += 1
	return n

func _total_stars() -> int:
	var n := 0
	for k in progress.stars:
		n += int(progress.stars[k])
	return n

func _highest_tier() -> int:
	var t := 0
	for k in progress.stars:
		if int(progress.stars[k]) > 0:
			t = maxi(t, int(TiltEngine.level_info(int(k)).tier))
	return t

func _next_level() -> int:
	for lvl in range(1, TiltEngine.LEVEL_COUNT + 1):
		if int(progress.stars.get(str(lvl), 0)) == 0:
			return lvl
	return TiltEngine.LEVEL_COUNT

func _unlocked(lvl: int) -> bool:
	return lvl <= 1 or int(progress.stars.get(str(lvl - 1), 0)) > 0

func _open_map_from_landing() -> void:
	_open_map(true)

func _open_map(from_landing: bool) -> void:
	_close_end()
	_close_map()
	map_from_landing = from_landing
	map_layer = ColorRect.new()
	(map_layer as ColorRect).color = Color(0.1, 0.06, 0.03, 0.98) if _is_classic() else Color(0.03, 0.04, 0.1, 0.98)
	map_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	map_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(map_layer)
	map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_layer.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_drag = HomeKit._DragScroll.new()
	scroll.add_child(map_drag)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	box.add_child(bar)
	var home_btn := HomeKit.neon_button(tr("🏠 Home"), HomeKit.BUTTON, 24, 60)
	home_btn.custom_minimum_size.x = 170
	home_btn.pressed.connect(_map_home)
	bar.add_child(home_btn)
	if not from_landing:
		var back := HomeKit.neon_button(tr("‹ Back"), HomeKit.BUTTON, 24, 60)
		back.custom_minimum_size.x = 150
		back.pressed.connect(_map_back)
		bar.add_child(back)
	var heading := Label.new()
	heading.text = tr("Levels")
	heading.add_theme_font_size_override("font_size", 34)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(heading)
	var total := Label.new()
	total.text = "★ %d / %d" % [_total_stars(), TiltEngine.LEVEL_COUNT * 3]
	total.add_theme_font_size_override("font_size", 28)
	total.add_theme_color_override("font_color", Color("ffd54f"))
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(total)
	var scroll_to: Control = null
	var next_lvl := _next_level()
	for b in TiltEngine.TIERS.size():
		var name_label := Label.new()
		name_label.text = tr(TiltEngine.TIERS[b])
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.add_theme_color_override("font_color", TIER_COLORS[b])
		box.add_child(name_label)
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		box.add_child(grid)
		for lvl in range(TiltEngine.first_level_of_block(b), TiltEngine.last_level_of_block(b) + 1):
			var li := TiltEngine.level_info(lvl)
			var stars: int = int(progress.stars.get(str(lvl), 0))
			var open := _unlocked(lvl)
			var bt := Button.new()
			bt.text = ("⚡" if li.sneak else "") + str(lvl) + "\n" + ("🔒" if not open else "★".repeat(stars) + "☆".repeat(3 - stars))
			bt.custom_minimum_size = Vector2(0, 86)
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bt.add_theme_font_size_override("font_size", 21)
			bt.disabled = not open
			if li.sneak:
				bt.add_theme_color_override("font_color", TIER_COLORS[int(li.tier)])
			elif stars == 3:
				bt.add_theme_color_override("font_color", Color("ffd54f"))
			bt.pressed.connect(_map_pick.bind(lvl))
			grid.add_child(bt)
			if lvl == next_lvl:
				scroll_to = bt
	var legend := Label.new()
	legend.text = tr("⚡ = a challenge maze from the next tier.")
	legend.add_theme_font_size_override("font_size", 22)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(legend)
	if scroll_to:
		scroll.call_deferred("ensure_control_visible", scroll_to)

func _map_pick(lvl: int) -> void:
	if map_drag and map_drag.moved:
		return
	if not _unlocked(lvl):
		return
	if map_from_landing:
		home.play_now(_start_level.bind(lvl))
	else:
		_start_level(lvl)

func _map_home() -> void:
	if map_drag and map_drag.moved:
		return
	var from_landing := map_from_landing
	_close_map()
	if not from_landing:
		_go_home()  # the Landing is already under a map opened from it

func _map_back() -> void:
	if map_drag and map_drag.moved:
		return
	_close_map()

func _close_map() -> void:
	if map_layer and is_instance_valid(map_layer):
		map_layer.queue_free()
	map_layer = null
	map_drag = null

# ---------- drawing ----------

## A soft-edged white disc, tinted per use: draw_texture_rect is far cheaper
## than draw_circle in Godot 4.7 (CLAUDE.md gotchas).
static func _make_disc() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(c - d + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _disc_at(c: Vector2, r: float, col: Color) -> void:
	board.draw_texture_rect(_disc, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

func _geom() -> Dictionary:
	var side_w: float = board.size.x - 28.0
	var side_h: float = board.size.y - 20.0
	var cell: float = floor(minf(minf(side_w / engine.w, side_h / engine.h), 130.0))
	var span := Vector2(cell * engine.w, cell * engine.h)
	return {"cell": cell, "origin": ((board.size - span) / 2.0).floor()}

## Look (STANDARDS §9): "classic" = a wooden tray with a steel marble
## (default); "voodoo" = neon walls on black, a glowing marble, a skull goal.
func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = Color("3b2414") if skin == "classic" else HomeKit.BG
	_geo_key = ""
	if board:
		board.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _cache_walls(g: Dictionary) -> void:
	var key := "%d:%d:%d:%s:%s" % [engine.w, engine.h, cur_seed, str(g.cell), str(g.origin)]
	if key == _geo_key:
		return
	_geo_key = key
	_wall_lines = PackedVector2Array()
	_posts.clear()
	var cs: float = g.cell
	var o: Vector2 = g.origin
	var post := {}
	for y in engine.h:
		for x in engine.w:
			var wv: int = engine.walls[y * engine.w + x]
			var p := o + Vector2(x, y) * cs
			if wv & TiltEngine.N:
				_wall_lines.append_array([p, p + Vector2(cs, 0)])
				post[Vector2i(x, y)] = true
				post[Vector2i(x + 1, y)] = true
			if wv & TiltEngine.W:
				_wall_lines.append_array([p, p + Vector2(0, cs)])
				post[Vector2i(x, y)] = true
				post[Vector2i(x, y + 1)] = true
			if x == engine.w - 1 and wv & TiltEngine.E:
				_wall_lines.append_array([p + Vector2(cs, 0), p + Vector2(cs, cs)])
				post[Vector2i(x + 1, y)] = true
				post[Vector2i(x + 1, y + 1)] = true
			if y == engine.h - 1 and wv & TiltEngine.S:
				_wall_lines.append_array([p + Vector2(0, cs), p + Vector2(cs, cs)])
				post[Vector2i(x, y + 1)] = true
				post[Vector2i(x + 1, y + 1)] = true
	for k in post:
		_posts.append(o + Vector2(k) * cs)

func _draw_board() -> void:
	if engine.w == 0:
		return
	var g := _geom()
	_cache_walls(g)
	var cs: float = g.cell
	var o: Vector2 = g.origin
	var classic := _is_classic()
	var area := Rect2(o, Vector2(engine.w, engine.h) * cs)
	var wall_w: float = maxf(3.0, cs * TiltEngine.WALL_HALF * 2.0)
	# Tray.
	if classic:
		board.draw_rect(area.grow(cs * 0.22), Color("5a3418"))
		board.draw_rect(area, Color("d9b07a"))
		for i in range(1, engine.h * 3):
			var y: float = o.y + i * cs / 3.0
			board.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.55, 0.36, 0.18, 0.12), 1.0)
	else:
		board.draw_rect(area, Color("0b0d1a"))
	# Holes, then the goal.
	var hr: float = cs * TiltEngine.HOLE_R
	for hc in engine.holes:
		var hp: Vector2 = o + hc * cs
		if classic:
			_disc_at(hp, hr * 1.12, Color("8a5a2b"))
			_disc_at(hp, hr, Color("140b05"))
		else:
			_disc_at(hp, hr * 1.25, Color(HomeKit.MAGENTA, 0.35))
			_disc_at(hp, hr, Color("000000"))
	var gp := o + (Vector2(engine.goal) + Vector2(0.5, 0.5)) * cs
	var pulse := 0.9 + 0.1 * sin(pulse_t * 4.0)
	if classic:
		_disc_at(gp, hr * 1.35 * pulse, Color("4caf50"))
		_disc_at(gp, hr, Color("10240f"))
	else:
		_disc_at(gp, hr * 1.45 * pulse, Color(HomeKit.LIME, 0.35))
		_disc_at(gp, hr * 1.05, Color("000000"))
		HomeKit.glow_circle(board, gp, hr * 1.05, HomeKit.LIME, maxf(2.0, cs * 0.04), 0.3)
	# Start pad.
	var sp := o + (Vector2(engine.start) + Vector2(0.5, 0.5)) * cs
	board.draw_rect(Rect2(sp - Vector2(cs, cs) * 0.38, Vector2(cs, cs) * 0.76), Color(1, 1, 1, 0.08 if classic else 0.05), false, 2.0)
	# Hint route.
	if not hint_path.is_empty():
		var pts := PackedVector2Array()
		for i in range(0, hint_path.size(), 2):
			pts.append(o + (hint_path[i] as Vector2) * cs)
		pts.append(o + (hint_path[hint_path.size() - 1] as Vector2) * cs)
		var hc2 := Color("ff8f00") if classic else HomeKit.CYAN
		board.draw_polyline(pts, Color(hc2, 0.75 * clampf(hint_t, 0.0, 1.0)), maxf(2.0, cs * 0.08))
	# Walls.
	var wc := Color("6d3f1c") if classic else HomeKit.PURPLE
	if not classic:
		board.draw_multiline(_wall_lines, Color(wc, 0.3), wall_w * 2.4)
	board.draw_multiline(_wall_lines, wc, wall_w)
	var ph: float = wall_w * 0.5
	for p in _posts:
		board.draw_rect(Rect2(p - Vector2(ph, ph), Vector2(wall_w, wall_w)), wc)
	if classic:
		board.draw_multiline(_wall_lines, Color("8d5a2f"), maxf(1.0, wall_w * 0.35))
	# The marble (shrinks while it drops into a hole).
	var mr: float = cs * TiltEngine.BALL_R
	if engine.falling_t >= 0.0:
		mr *= maxf(0.0, 1.0 - engine.falling_t / TiltEngine.FALL_TIME)
	if engine.won:
		mr *= maxf(0.0, 1.0 - win_t * 2.0)
	var mp: Vector2 = o + engine.pos * cs
	if mr > 0.5:
		# The player's marble and effect from the 🛒 shop (tilt_maze_shop.gd).
		var marble := Shop.equipped(progress, "marble")
		var fx := Shop.equipped(progress, "fx")
		if fx != "none":
			var pts: Array = []
			for q in trail_pts:
				pts.append(o + (q as Vector2) * cs)
			Shop.draw_fx_under(board, _disc, fx, marble, pts, mp, mr, pulse_t)
		Shop.draw_marble(board, _disc, marble, mp, mr, engine.vel, pulse_t, not classic)
	# Touch joystick.
	if stick_on and _using_touch():
		board.draw_arc(stick_from, STICK_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.25), 3.0)
		_disc_at(stick_from + (stick_at - stick_from).limit_length(STICK_RADIUS), 34.0, Color(1, 1, 1, 0.3))
	# Ready: calibrating.
	if ready_t > 0.0 and started and not solved:
		var f := get_theme_default_font()
		var txt := tr("Ready...")
		var fs := 44
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		board.draw_string_outline(f, Vector2((board.size.x - tw) / 2.0, board.size.y / 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, 0.8))
		board.draw_string(f, Vector2((board.size.x - tw) / 2.0, board.size.y / 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 4.6, 44.0)
	var o := Vector2(c.size.x / 2.0 - k * 2.5, c.size.y / 2.0 - k * 2.0)
	var col := Color("4fc3f7")
	var segs := [[0, 0, 5, 0], [0, 4, 5, 4], [0, 0, 0, 4], [5, 0, 5, 4], [1, 1, 4, 1], [1, 1, 1, 3], [2, 2, 2, 4], [3, 2, 5, 2]]
	for s in segs:
		HomeKit.glow_line(c, o + Vector2(s[0], s[1]) * k, o + Vector2(s[2], s[3]) * k, col, maxf(2.0, k * 0.12))
	c.draw_circle(o + Vector2(3.5, 3.2) * k, k * 0.3, Color("000000"))
	HomeKit.glow_circle(c, o + Vector2(3.5, 3.2) * k, k * 0.3, HomeKit.MAGENTA, 2.0, 0.4)
	HomeKit.glow_circle(c, o + Vector2(0.5, 3.5) * k, k * 0.26, Color.WHITE, 2.5, 0.6)
	HomeKit.glow_circle(c, o + Vector2(4.5, 0.5) * k, k * 0.3, HomeKit.LIME, 2.0, 0.3)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or solved or engine.w == 0:
		return
	SaveUtil.write(SAVE_PATH, {"mode": mode, "level": cur_level, "seed": cur_seed,
		"x": engine.pos.x, "y": engine.pos.y, "time": engine.time, "falls": engine.falls})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary or not d.has("mode"):
		return ""
	if str(d.mode) == "daily":
		return tr("📅 Daily Maze") + "   ·   " + _clock(float(d.get("time", 0)))
	return tr("Maze %d") % int(d.get("level", 1)) + "   ·   " + _clock(float(d.get("time", 0)))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not d is Dictionary or not d.has("mode"):
		_start_campaign()
		return
	var m := str(d.mode)
	if m == "daily" and int(d.get("seed", 0)) != _today() * 6151 + 29:
		_start_daily()  # yesterday's daily: start today's
		return
	_begin(m, clampi(int(d.get("level", 1)), 1, TiltEngine.LEVEL_COUNT), int(d.get("seed", 1)))
	var p := Vector2(float(d.get("x", engine.pos.x)), float(d.get("y", engine.pos.y)))
	if p.x > 0.0 and p.y > 0.0 and p.x < engine.w and p.y < engine.h:
		engine.pos = p
	engine.time = float(d.get("time", 0.0))
	engine.falls = int(d.get("falls", 0))
	_status()

# ---------- sound and music ----------

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

## Music from the hub's shared library (apps before v0.33 play none).
func _play_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, -1, 2.0)
