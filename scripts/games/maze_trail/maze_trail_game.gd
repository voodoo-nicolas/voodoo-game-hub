extends Control

## Maze Trail -- walk from the start to the exit. Drag your finger along the
## paths to walk; a quick swipe runs down a corridor to the next turning.
## Campaign: 195 mazes in six tiers (Very Easy .. Insane), with a challenge
## maze from the next tier after every 10 (maze_trail_engine.gd). Medium and up
## add gates and keys, Very Hard and Insane fog. Also a Daily Maze. All art is
## drawn in code; sounds from the shared library.

const MazeEngine = preload("res://scripts/games/maze_trail/maze_trail_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SoundLib = preload("res://scripts/games/maze_trail/sound_lib.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/maze_trail/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/maze_trail/maze_trail_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://maze_trail_save.json"
const PROGRESS_PATH := "user://maze_trail_progress.json"

## Hints (owner, 2026-11-01, every game): at most 3, +1 every 24 h, per game.
const MAX_HINTS := 3
const HINT_REFILL_SECS := 86400
const HINT_CELLS := 12  # how far ahead a hint shows the way
const HINT_SECONDS := 4.0
const WALK_SPEED := 16.0  # cells per second for the drawn walker
const DRAG_REACH := 4  # a drag walks to a cell at most this many steps away
## Tier colours (also the tier names' colour in the level map).
const TIER_COLORS := [Color("6fd36f"), Color("4fc3f7"), Color("ffd54f"), Color("ff9f43"), Color("ff5f6d"), Color("c86bff")]
## Daily maze tier by weekday (0 = Sunday .. 6 = Saturday).
const DAILY_TIER := [4, 1, 2, 2, 3, 3, 5]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var mode: String = "campaign"  # campaign | daily
var cur_level: int = 1
var cur_tier: int = 0
var cur_idx: int = 0
var cur_seed: int = 0
var elapsed: float = 0.0
var hints_used: int = 0
var started := false  # a real game is on (not just the maze behind Home)
var solved := false
var progress: Dictionary = {}

var walker := Vector2.ZERO  # drawn position (cells), eases toward engine.player
var hint_path: Array = []
var hint_t: float = 0.0
var win_t: float = -1.0
var bump_t: float = 0.0
var bump_dir := Vector2.ZERO
var pulse_t: float = 0.0

var drag_down := false
var drag_from := Vector2.ZERO
var drag_ms: int = 0
var drag_walked := false

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

func _ready() -> void:
	preload("res://scripts/games/maze_trail/maze_trail_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MazeEngine.new()
	_load_progress()
	_build_ui()
	_play_music()
	_begin("campaign", 1, MazeEngine.seed_for(1))
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = ColorRect.new()
	bg.color = Color("23401f")
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
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": TIER_COLORS[0],
		"subtitle": "Find the way out. 195 mazes, from very easy to insane.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🗺 Campaign", "sub": "195 mazes · collect stars", "action": _start_campaign},
		],
		"play": [
			{"text": "📋 Level Select", "sub": "Pick any maze you have opened", "action": _open_map_from_landing, "card": true},
			{"text": "📅 Daily Maze", "sub": "One maze a day, the same for everyone", "action": _start_daily},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Mazes solved",
		"board_note": "Mazes solved in any mode.",
	})
	add_child(home)
	if info:
		add_child(info)

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
	_begin("campaign", lvl, MazeEngine.seed_for(lvl))

func _start_daily() -> void:
	_close_map()
	SaveUtil.delete(SAVE_PATH)
	var day := _today()
	_begin("daily", 0, day * 7919 + 13)

func _restart() -> void:
	_begin(mode, cur_level, cur_seed)

func _begin(m: String, lvl: int, seed_value: int) -> void:
	mode = m
	cur_level = lvl
	cur_seed = seed_value
	var params: Dictionary
	if m == "daily":
		var day := _today()
		cur_tier = DAILY_TIER[_weekday()]
		cur_idx = 10 + day % 20
		params = MazeEngine.params_for_tier(cur_tier, cur_idx)
	else:
		var li := MazeEngine.level_info(lvl)
		cur_tier = int(li.tier)
		cur_idx = int(li.idx)
		params = MazeEngine.params_for(lvl)
	engine.generate(params, seed_value)
	walker = Vector2(engine.player)
	elapsed = 0.0
	hints_used = 0
	solved = false
	started = true
	hint_path.clear()
	hint_t = 0.0
	win_t = -1.0
	_geo_key = ""
	_close_end()
	_close_map()
	_labels()
	_status()
	board.queue_redraw()

func _labels() -> void:
	var tier_name: String = tr(MazeEngine.TIERS[cur_tier])
	var col: Color = TIER_COLORS[cur_tier]
	if mode == "daily":
		title_label.text = tr("📅 Daily Maze")
		tip_label.text = tr("Today: %s. The same maze for everyone.") % tier_name
	else:
		title_label.text = tr("Maze %d") % cur_level
		var li := MazeEngine.level_info(cur_level)
		if li.sneak:
			tip_label.text = tr("⚡ Challenge maze: a taste of %s!") % tier_name
		elif engine.fog > 0:
			tip_label.text = tier_name + " · " + tr("Fog: you only see what is near you.")
		elif engine.keys.size() > 0:
			tip_label.text = tier_name + " · " + tr("Gates: find the key of the same colour first.")
		else:
			tip_label.text = tier_name + " · " + tr("Drag along the path to walk. Swipe to run.")
	tip_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.35))
	title_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.55))
	_hint_label()

func _status() -> void:
	var line := tr("Steps: %d") % engine.steps + "   ·   " + tr("Best route: %d") % engine.par + "   ·   " + _clock(elapsed)
	if engine.keys.size() > 0:
		var got := 0
		for k in engine.keys:
			if k.got:
				got += 1
		line += "   ·   🔑 %d/%d" % [got, engine.keys.size()]
	status_label.text = line

static func _clock(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]

static func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

static func _weekday() -> int:
	return int(Time.get_datetime_dict_from_system().get("weekday", 0))

func _process(delta: float) -> void:
	pulse_t += delta
	var redraw := false
	if started and not solved:
		var before := int(elapsed)
		elapsed += delta
		if int(elapsed) != before:
			_status()
	var target := Vector2(engine.player)
	if walker != target:
		walker = walker.move_toward(target, delta * WALK_SPEED)
		redraw = true
	if hint_t > 0.0:
		hint_t -= delta
		if hint_t <= 0.0:
			hint_path.clear()
		redraw = true
	if bump_t > 0.0:
		bump_t -= delta
		redraw = true
	if win_t >= 0.0 and win_t < 2.0:
		win_t += delta
		redraw = true
	if engine.keys.size() > 0 or started:
		redraw = true  # the exit and keys glow
	if redraw:
		board.queue_redraw()

# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if not started or solved or not is_visible_in_tree() or get_tree().paused:
		return
	if event is InputEventKey and event.pressed:
		var d := -1
		match event.keycode:
			KEY_UP, KEY_W: d = 0
			KEY_RIGHT, KEY_D: d = 1
			KEY_DOWN, KEY_S: d = 2
			KEY_LEFT, KEY_A: d = 3
		if d >= 0:
			_run(d)
			get_viewport().set_input_as_handled()

func _on_board_input(event: InputEvent) -> void:
	if not started or solved:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_down = true
			drag_from = event.position
			drag_ms = Time.get_ticks_msec()
			drag_walked = false
			_walk_towards(event.position)
		elif drag_down:
			drag_down = false
			var dv: Vector2 = event.position - drag_from
			# A quick flick that did not walk the finger along: run that way.
			if not drag_walked and dv.length() > 40.0 and Time.get_ticks_msec() - drag_ms < 400:
				if absf(dv.x) > absf(dv.y):
					_run(1 if dv.x > 0 else 3)
				else:
					_run(2 if dv.y > 0 else 0)
	elif event is InputEventMouseMotion and drag_down:
		_walk_towards(event.position)

## Walks to the cell under the finger if it is a few steps away along the paths.
func _walk_towards(pos: Vector2) -> void:
	var g := _geom()
	var p: Vector2 = (pos - g.origin) / g.cell
	if p.x < 0 or p.y < 0 or p.x >= engine.w or p.y >= engine.h:
		return
	var target := Vector2i(int(p.x), int(p.y))
	if target == engine.player:
		return
	if engine.fog > 0 and not engine.is_seen(target):
		return
	var path: Array = engine.route(engine.player, target, false)
	if path.size() < 2 or path.size() - 1 > DRAG_REACH:
		return
	for i in range(1, path.size()):
		var d: int = MazeEngine.DIRS.find(path[i] - engine.player)
		if not _do_step(d):
			break
	drag_walked = true

func _run(d: int) -> void:
	var results: Array = engine.run(d)
	if results.is_empty() or results[0] == "":
		_bump(d)
		return
	if results[0] == "locked":
		_locked(d)
		return
	for r in results:
		_after_step(r)

func _do_step(d: int) -> bool:
	var r: String = engine.step(d)
	if r == "":
		_bump(d)
		return false
	if r == "locked":
		_locked(d)
		return false
	_after_step(r)
	return true

func _bump(d: int) -> void:
	bump_t = 0.15
	bump_dir = Vector2(MazeEngine.DIRS[d])

func _locked(d: int) -> void:
	_bump(d)
	SoundLib.play(self, "rpg/metal_click", -4.0)
	tip_label.text = tr("Locked. Find the key of the same colour.")

func _after_step(r: String) -> void:
	match r:
		"move":
			SoundLib.play(self, "rpg/footstep", -14.0)
		"key":
			SoundLib.play(self, "reward/coin_plingy", -2.0)
		"gate":
			SoundLib.play(self, "rpg/metal_latch", -2.0)
		"win":
			_on_solved()
	_status()
	board.queue_redraw()

# ---------- hints ----------

func _hints_now() -> int:
	var now := int(Time.get_unix_time_from_system())
	var left: int = int(progress.get("hints", MAX_HINTS))
	var stamp: int = int(progress.get("hint_stamp", 0))
	if left >= MAX_HINTS or stamp <= 0 or stamp > now:
		stamp = now
	var gained: int = (now - stamp) / HINT_REFILL_SECS
	if gained > 0:
		left = mini(MAX_HINTS, left + gained)
		stamp = now if left >= MAX_HINTS else stamp + gained * HINT_REFILL_SECS
	progress["hints"] = left
	progress["hint_stamp"] = stamp
	return left

func _hint_label() -> void:
	hint_btn.text = "💡%d" % _hints_now()

func _on_hint() -> void:
	if solved or not started:
		return
	if _hints_now() <= 0:
		var now := int(Time.get_unix_time_from_system())
		var wait: int = maxi(60, int(progress.hint_stamp) + HINT_REFILL_SECS - now)
		tip_label.text = tr("No hints left. Next one in %d h %d min.") % [wait / 3600, (wait % 3600) / 60]
		SoundLib.play(self, "ui/wrong", -8.0)
		return
	var way: Array = engine.solution_from_here()
	if way.is_empty():
		return
	progress["hints"] = int(progress.hints) - 1
	_save_progress()
	hints_used += 1
	hint_path = way.slice(0, HINT_CELLS)
	hint_t = HINT_SECONDS
	_hint_label()
	_sfx("notify")

# ---------- winning ----------

func _on_solved() -> void:
	solved = true
	win_t = 0.0
	hint_path.clear()
	SaveUtil.delete(SAVE_PATH)
	SoundLib.play(self, "reward/accomplished")
	_sfx("win")
	var stars: int = engine.stars()
	var note := ""
	if info:
		info.add("Mazes solved")
		info.result("win")
		info.low("Fastest maze (seconds)", int(elapsed))
	match mode:
		"campaign":
			var key := str(cur_level)
			if stars > int(progress.stars.get(key, 0)):
				progress.stars[key] = stars
			var best_steps: int = int(progress.best.get(key, 0))
			if best_steps == 0 or engine.steps < best_steps:
				progress.best[key] = engine.steps
			_save_progress()
			if info:
				info.high("Highest maze cleared", _cleared())  # levels open in order, so cleared = highest
				info.high("Campaign stars", _total_stars())
				if stars == 3:
					info.add("Perfect routes")
				info.high("Highest tier reached", _highest_tier() + 1)
		"daily":
			var day := _today()
			if int(progress.get("daily_day", 0)) != day:
				if int(progress.get("daily_day", 0)) == day - 1:
					progress.daily_streak = int(progress.get("daily_streak", 0)) + 1
				else:
					progress.daily_streak = 1
				progress.daily_day = day
				_save_progress()
				note = tr("Daily streak: %d") % int(progress.daily_streak)
				if info:
					info.high("Longest daily streak", int(progress.daily_streak))
			else:
				note = tr("Already done today. Come back tomorrow for a new one.")
	if info:
		info.celebrate(tr("Way out!"))
	var msg := tr("Steps: %d") % engine.steps + "   ·   " + tr("Best route: %d") % engine.par + "   ·   " + _clock(elapsed)
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
		if cur_level < MazeEngine.LEVEL_COUNT:
			var nxt := MazeEngine.level_info(cur_level + 1)
			var label := tr("Next maze")
			if nxt.sneak:
				label = tr("⚡ Next: challenge maze")
			elif MazeEngine.block_of(cur_level + 1) != MazeEngine.block_of(cur_level):
				label = tr("Next: %s") % tr(MazeEngine.TIERS[MazeEngine.block_of(cur_level + 1)])
			buttons.append({"text": label, "action": _start_level.bind(cur_level + 1)})
		else:
			msg += "\n" + tr("All 195 mazes solved!")
		if stars < 3:
			buttons.append({"text": tr("Try for 3 stars"), "action": _restart})
		buttons.append({"text": tr("📋 Levels"), "action": _open_map.bind(false)})
	else:
		buttons.append({"text": tr("Play again"), "action": _restart})
	buttons.append({"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home})
	_show_card(tr("Way out!"), star_text, msg, buttons)

## A small result card over the board: title, stars, a line of text, buttons.
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
	sb.bg_color = Color(0.05, 0.08, 0.06, 0.96) if _is_classic() else Color(0.05, 0.07, 0.16, 0.96)
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
			t = maxi(t, int(MazeEngine.level_info(int(k)).tier))
	return t

func _next_level() -> int:
	for lvl in range(1, MazeEngine.LEVEL_COUNT + 1):
		if int(progress.stars.get(str(lvl), 0)) == 0:
			return lvl
	return MazeEngine.LEVEL_COUNT

func _unlocked(lvl: int) -> bool:
	return lvl <= 1 or int(progress.stars.get(str(lvl - 1), 0)) > 0

func _open_map_from_landing() -> void:
	_open_map(true)

func _open_map(from_landing: bool) -> void:
	_close_end()
	_close_map()
	map_from_landing = from_landing
	map_layer = ColorRect.new()
	(map_layer as ColorRect).color = Color(0.04, 0.07, 0.05, 0.98) if _is_classic() else Color(0.03, 0.04, 0.1, 0.98)
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
	total.text = "★ %d / %d" % [_total_stars(), MazeEngine.LEVEL_COUNT * 3]
	total.add_theme_font_size_override("font_size", 28)
	total.add_theme_color_override("font_color", Color("ffd54f"))
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(total)
	var scroll_to: Control = null
	var next_lvl := _next_level()
	for b in MazeEngine.TIERS.size():
		var col: Color = TIER_COLORS[b]
		var name_label := Label.new()
		name_label.text = tr(MazeEngine.TIERS[b])
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.add_theme_color_override("font_color", col)
		box.add_child(name_label)
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		box.add_child(grid)
		for lvl in range(MazeEngine.first_level_of_block(b), MazeEngine.last_level_of_block(b) + 1):
			var li := MazeEngine.level_info(lvl)
			var stars: int = int(progress.stars.get(str(lvl), 0))
			var open := _unlocked(lvl)
			var bt := Button.new()
			var head := ("⚡" if li.sneak else "") + str(lvl)
			bt.text = head + "\n" + ("🔒" if not open else "★".repeat(stars) + "☆".repeat(3 - stars))
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

func _geom() -> Dictionary:
	var side_w: float = board.size.x - 20.0
	var side_h: float = board.size.y - 12.0
	var cell: float = floor(minf(minf(side_w / engine.w, side_h / engine.h), 110.0))
	var span := Vector2(cell * engine.w, cell * engine.h)
	return {"cell": cell, "origin": ((board.size - span) / 2.0).floor()}

## Look (STANDARDS §9): "classic" = a garden hedge maze on a sandy path
## (default); "voodoo" = neon walls on black, a skull at the exit.
func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = Color("23401f") if skin == "classic" else HomeKit.BG
	_geo_key = ""
	if board:
		board.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

## Wall segments and corner posts, rebuilt when the maze or the size changes.
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
			if wv & MazeEngine.N:
				_wall_lines.append_array([p, p + Vector2(cs, 0)])
				post[Vector2i(x, y)] = true
				post[Vector2i(x + 1, y)] = true
			if wv & MazeEngine.W:
				_wall_lines.append_array([p, p + Vector2(0, cs)])
				post[Vector2i(x, y)] = true
				post[Vector2i(x, y + 1)] = true
			if x == engine.w - 1 and wv & MazeEngine.E:
				_wall_lines.append_array([p + Vector2(cs, 0), p + Vector2(cs, cs)])
				post[Vector2i(x + 1, y)] = true
				post[Vector2i(x + 1, y + 1)] = true
			if y == engine.h - 1 and wv & MazeEngine.S:
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
	var wall_w: float = maxf(3.0, cs * (0.26 if classic else 0.12))
	# Floor.
	if classic:
		board.draw_rect(area.grow(wall_w * 0.5), Color("2f6b2f"))
		board.draw_rect(area, Color("e6d3a3"))
	else:
		board.draw_rect(area, Color("0b1020"))
	# Trail behind the walker.
	if engine.trail.size() >= 2:
		var pts := PackedVector2Array()
		for c in engine.trail:
			pts.append(o + (Vector2(c) + Vector2(0.5, 0.5)) * cs)
		var tc := Color("c9a86a") if classic else Color(HomeKit.CYAN, 0.35)
		board.draw_polyline(pts, tc, maxf(2.0, cs * 0.18))
	# Hint: dots along the way ahead, fading.
	if not hint_path.is_empty():
		var a: float = clampf(hint_t, 0.0, 1.0)
		for i in hint_path.size():
			var c: Vector2 = o + (Vector2(hint_path[i]) + Vector2(0.5, 0.5)) * cs
			var s: float = cs * 0.14
			var hc := Color("ff8f00") if classic else HomeKit.MAGENTA
			board.draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), Color(hc, a * (1.0 - i / float(hint_path.size() + 2))))
	# Exit.
	var ex := o + (Vector2(engine.exit) + Vector2(0.5, 0.5)) * cs
	var pulse := 0.85 + 0.15 * sin(pulse_t * 4.0)
	if classic:
		board.draw_rect(Rect2(ex - Vector2(cs, cs) * 0.42, Vector2(cs, cs) * 0.84), Color("8bc34a"))
		board.draw_line(ex + Vector2(-cs * 0.12, cs * 0.3), ex + Vector2(-cs * 0.12, -cs * 0.32), Color("4e342e"), maxf(2.0, cs * 0.06))
		board.draw_colored_polygon(PackedVector2Array([ex + Vector2(-cs * 0.12, -cs * 0.32), ex + Vector2(cs * 0.3, -cs * 0.2 * pulse), ex + Vector2(-cs * 0.12, -cs * 0.06)]), Color("d62828"))
	else:
		HomeKit.glow_circle(board, ex, cs * 0.34 * pulse, HomeKit.LIME, maxf(2.0, cs * 0.06), 0.3)
		_draw_skull(ex, cs * 0.2, HomeKit.LIME)
	# Gates and keys.
	for i in engine.gates.size():
		var gt: Dictionary = engine.gates[i]
		var gc := o + (Vector2(gt.pos) + Vector2(0.5, 0.5)) * cs
		var kc: Color = _key_color(i)
		if gt.open:
			board.draw_rect(Rect2(gc - Vector2(cs, cs) * 0.45, Vector2(cs, cs) * 0.9), Color(kc, 0.18))
		else:
			var r := Rect2(gc - Vector2(cs, cs) * 0.45, Vector2(cs, cs) * 0.9)
			board.draw_rect(r, Color(kc, 0.35) if classic else Color(kc, 0.15))
			for b in 4:
				var x: float = r.position.x + r.size.x * (0.15 + b * 0.233)
				board.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), kc.darkened(0.3) if classic else kc, maxf(2.0, cs * 0.07))
			board.draw_rect(r, kc.darkened(0.4) if classic else kc, false, maxf(1.5, cs * 0.05))
	for i in engine.keys.size():
		var k: Dictionary = engine.keys[i]
		if k.got:
			continue
		var kp := o + (Vector2(k.pos) + Vector2(0.5, 0.5)) * cs
		_draw_key(kp, cs * 0.5 * pulse, _key_color(i))
	# Walls (one batched call) and corner posts.
	var wc := Color("2f6b2f") if classic else HomeKit.CYAN
	if not classic:
		board.draw_multiline(_wall_lines, Color(wc, 0.25), wall_w * 2.2)
	board.draw_multiline(_wall_lines, wc, wall_w)
	var ph: float = wall_w * 0.5
	for p in _posts:
		board.draw_rect(Rect2(p - Vector2(ph, ph), Vector2(wall_w, wall_w)), wc)
	if classic:
		board.draw_multiline(_wall_lines, Color("3f8a3a"), maxf(1.0, wall_w * 0.35))
	# Fog.
	if engine.fog > 0:
		var dark := Color("10200f") if classic else Color("03050b")
		for y in engine.h:
			for x in engine.w:
				var c := Vector2i(x, y)
				var r := Rect2(o + Vector2(x, y) * cs, Vector2(cs, cs)).grow(0.5)
				if not engine.is_seen(c):
					board.draw_rect(r, dark)
				elif not engine.is_lit(c):
					board.draw_rect(r, Color(dark, 0.55))
	# The walker.
	var wp := o + (walker + Vector2(0.5, 0.5)) * cs
	if bump_t > 0.0:
		wp += bump_dir * cs * 0.08 * (bump_t / 0.15)
	var pr: float = cs * 0.3
	if classic:
		board.draw_circle(wp + Vector2(1, 2), pr, Color(0, 0, 0, 0.25))
		board.draw_circle(wp, pr, Color("1e5bd8"))
		board.draw_circle(wp + Vector2(-pr * 0.3, -pr * 0.3), pr * 0.3, Color(1, 1, 1, 0.5))
	else:
		board.draw_circle(wp, pr, Color(HomeKit.MAGENTA, 0.3))
		HomeKit.glow_circle(board, wp, pr, HomeKit.MAGENTA, maxf(2.0, cs * 0.06))
	# A win ripple.
	if win_t >= 0.0 and win_t < 1.5:
		var rr: float = cs * (0.5 + win_t * 4.0)
		board.draw_arc(ex, rr, 0, TAU, 40, Color(1, 1, 1, 0.6 * (1.0 - win_t / 1.5)), maxf(2.0, cs * 0.08))

func _key_color(i: int) -> Color:
	return Color("ffb300") if i == 0 else Color("00b8d4")

## A key: ring bow, shaft and two teeth (colour is not the only cue: gate 1
## has one notch on the key's bow, gate 2 two).
func _draw_key(c: Vector2, s: float, col: Color) -> void:
	var lw: float = maxf(2.0, s * 0.22)
	board.draw_arc(c + Vector2(-s * 0.45, 0), s * 0.35, 0, TAU, 16, col, lw)
	board.draw_line(c + Vector2(-s * 0.1, 0), c + Vector2(s * 0.8, 0), col, lw)
	board.draw_line(c + Vector2(s * 0.55, 0), c + Vector2(s * 0.55, s * 0.35), col, lw)
	board.draw_line(c + Vector2(s * 0.8, 0), c + Vector2(s * 0.8, s * 0.3), col, lw)

func _draw_skull(c: Vector2, r: float, col: Color) -> void:
	board.draw_circle(c + Vector2(0, -r * 0.15), r, col)
	board.draw_rect(Rect2(c + Vector2(-r * 0.55, r * 0.5), Vector2(r * 1.1, r * 0.5)), col)
	board.draw_circle(c + Vector2(-r * 0.38, -r * 0.1), r * 0.26, Color("03050b"))
	board.draw_circle(c + Vector2(r * 0.38, -r * 0.1), r * 0.26, Color("03050b"))

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 4.6, 44.0)
	var o := Vector2(c.size.x / 2.0 - k * 2.5, c.size.y / 2.0 - k * 2.0)
	var col: Color = TIER_COLORS[0]
	var segs := [[0, 0, 5, 0], [0, 4, 5, 4], [0, 0, 0, 3], [5, 1, 5, 4], [1, 1, 4, 1], [1, 1, 1, 3], [2, 2, 2, 4], [3, 2, 5, 2], [4, 3, 4, 4]]
	for s in segs:
		HomeKit.glow_line(c, o + Vector2(s[0], s[1]) * k, o + Vector2(s[2], s[3]) * k, col, maxf(2.0, k * 0.12))
	HomeKit.glow_circle(c, o + Vector2(0.5, 3.5) * k, k * 0.28, HomeKit.MAGENTA, 2.5, 0.35)
	HomeKit.glow_circle(c, o + Vector2(5.5, 0.5) * k, k * 0.22, HomeKit.GOLD, 2.0, 0.5)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or solved or engine.w == 0:
		return
	SaveUtil.write(SAVE_PATH, {"mode": mode, "level": cur_level, "seed": cur_seed, "time": elapsed,
		"hints": hints_used, "state": engine.to_dict()})

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
	if m == "daily" and int(d.get("seed", 0)) != _today() * 7919 + 13:
		_start_daily()  # yesterday's daily: start today's
		return
	_begin(m, clampi(int(d.get("level", 1)), 1, MazeEngine.LEVEL_COUNT), int(d.get("seed", 1)))
	var st = d.get("state", {})
	if st is Dictionary:
		engine.from_dict(st)
	walker = Vector2(engine.player)
	elapsed = float(d.get("time", 0.0))
	hints_used = int(d.get("hints", 0))
	_status()
	board.queue_redraw()

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
