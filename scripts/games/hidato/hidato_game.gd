extends Control

## Hidato -- fill the grid with 1 to N so each number touches the next one
## (sideways, up, down or diagonally). Tap an empty cell, then pick the number
## for it from the pad. Some numbers are given.

const HidatoEngine = preload("res://scripts/games/hidato/hidato_engine.gd")
const HELP = preload("res://scripts/games/hidato/hidato_help.gd")
const HomeKit = preload("res://scripts/games/hidato/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://hidato_save.json"
const LEVEL_NAMES := ["Easy", "Normal", "Hard", "Expert"]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Landing + pause menu
var engine: HidatoEngine
var bg: ColorRect
var skin: String = "classic"
var info_label: Label
var feedback_label: Label
var board: Control
var pad: GridContainer
var end_dialog: ColorRect
var feedback_timer: Timer
var check_timer: Timer
var selected: int = -1
var checking: bool = false
var elapsed: float = 0.0
var hints_used: int = 0
var playing: bool = false

func _ready() -> void:
	preload("res://scripts/games/hidato/hidato_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = HidatoEngine.new()
	engine.new_game(0)
	_build_ui()
	_calm_music()

## Calm background music from the hub's Music library (apps before v0.33 play none).
func _calm_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 1, 2.0)

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
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause_home)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🔢 Hidato")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = "↺"
	new_btn.custom_minimum_size = Vector2(76, 64)
	new_btn.add_theme_font_size_override("font_size", 30)
	new_btn.pressed.connect(_restart)
	bar.add_child(new_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_left", 12)
	bm.add_theme_constant_override("margin_right", 12)
	root.add_child(bm)
	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	bm.add_child(board)

	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 22)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.custom_minimum_size = Vector2(0, 30)
	root.add_child(feedback_label)

	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 10)
	pm.add_theme_constant_override("margin_right", 10)
	root.add_child(pm)
	pad = GridContainer.new()
	pad.columns = 8
	pad.add_theme_constant_override("h_separation", 6)
	pad.add_theme_constant_override("v_separation", 6)
	pm.add_child(pad)

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_bottom", 30)
	row_margin.add_theme_constant_override("margin_left", 12)
	row_margin.add_theme_constant_override("margin_right", 12)
	root.add_child(row_margin)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	row_margin.add_child(actions)
	actions.add_child(_button(tr("⌫ Clear"), _on_clear))
	actions.add_child(_button(tr("💡 Hint"), _on_hint))
	actions.add_child(_button(tr("✔ Check"), _on_check))

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = 2.2
	feedback_timer.timeout.connect(_clear_feedback)
	add_child(feedback_timer)
	check_timer = Timer.new()
	check_timer.one_shot = true
	check_timer.wait_time = 2.5
	check_timer.timeout.connect(_end_check)
	add_child(check_timer)

	end_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Next puzzle"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(HELP.TITLE), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in 4:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard", "🤯 Expert"][i], "sub": "%d × %d" % [HidatoEngine.LEVELS[i].size, HidatoEngine.LEVELS[i].size], "row": "lvl",
			"action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Connect 1 to the last number, one touching step at a time.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Puzzles solved",
		"board_note": "Puzzles solved at any size.",
	})
	add_child(home)
	if info:
		add_child(info)

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b

func _process(delta: float) -> void:
	if playing and not engine.solved():
		elapsed += delta
		_update_info()

# ---------- looks ----------

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if board:
		board.queue_redraw()
	_build_pad()

func _is_classic() -> bool:
	return skin == "classic"

func _update_info() -> void:
	var t := int(elapsed)
	info_label.text = tr("Time %d:%02d   Filled %d/%d") % [t / 60, t % 60, engine.filled_count(), engine.total()]

# ---------- drawing ----------

func _cell_size() -> float:
	return minf(board.size.x, board.size.y) / float(engine.size)

func _board_origin() -> Vector2:
	var s := _cell_size() * engine.size
	return Vector2((board.size.x - s) / 2.0, (board.size.y - s) / 2.0)

func _cell_rect(i: int) -> Rect2:
	var s := _cell_size()
	return Rect2(_board_origin() + Vector2((i % engine.size) * s, (i / engine.size) * s), Vector2(s, s))

func _draw_board() -> void:
	if engine == null or engine.grid.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var s := _cell_size()
	var bad: Array = []
	if checking or engine.is_complete():
		bad = engine.conflicts()
	for i in engine.total():
		var r := _cell_rect(i).grow(-3.0)
		var v: int = engine.grid[i]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(s * 0.14))
		sb.set_border_width_all(3)
		var ink: Color
		if _is_classic():
			sb.bg_color = Color("d9d2bf") if engine.given[i] else Color("f4efe4")
			sb.border_color = Color("8a8473")
			ink = HomeKit.CLASSIC.ink if engine.given[i] else Color("1e5bd8")
			if i == selected:
				sb.bg_color = Color("fff0b3")
				sb.border_color = HomeKit.CLASSIC.yellow.darkened(0.3)
				sb.set_border_width_all(5)
			if bad.has(i):
				sb.bg_color = Color("f4b1ad")
				sb.border_color = HomeKit.CLASSIC.red
		else:
			var c := HomeKit.GOLD if engine.given[i] else HomeKit.CYAN
			sb.bg_color = Color(c, 0.2 if engine.given[i] else 0.08)
			sb.border_color = c
			ink = Color.WHITE if engine.given[i] else HomeKit.CYAN.lightened(0.4)
			if i == selected:
				sb.border_color = HomeKit.PINK
				sb.bg_color = Color(HomeKit.PINK, 0.2)
				sb.set_border_width_all(5)
			if bad.has(i):
				sb.border_color = Color("ff3b3b")
				sb.bg_color = Color(1, 0.2, 0.2, 0.28)
		board.draw_style_box(sb, r)
		if v > 0:
			var fs: int = int(s * (0.5 if v < 100 else 0.4))
			var txt := str(v)
			var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			board.draw_string(font, Vector2(r.get_center().x - w / 2.0, r.get_center().y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# the path so far: short gold links between touching consecutive numbers
	for k in range(1, engine.total()):
		var a: int = engine.cell_of(k)
		var b: int = engine.cell_of(k + 1)
		if a >= 0 and b >= 0 and engine.adjacent(a, b):
			var pa: Vector2 = _cell_rect(a).get_center()
			var pb: Vector2 = _cell_rect(b).get_center()
			var dir: Vector2 = (pb - pa).normalized()
			board.draw_line(pa + dir * s * 0.34, pb - dir * s * 0.34, Color(HomeKit.GOLD, 0.9) if not _is_classic() else Color("c9961a"), 4.0)


func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y * 0.3, 42.0)
	var mid := c.size / 2.0
	var nums := [[1, 2, 0], [0, 3, 0], [0, 4, 5]]
	for r in 3:
		for q in 3:
			var rect := Rect2(mid + Vector2((q - 1.5) * k * 1.12, (r - 1.5) * k * 1.12), Vector2(k, k))
			var v: int = nums[r][q]
			HomeKit.glow_rect(c, rect, HomeKit.GOLD if v > 0 else HomeKit.CYAN, 2.0, 0.1 if v > 0 else 0.0)
			if v > 0:
				HomeKit.glow_text(c, rect.get_center(), str(v), int(k * 0.55), Color.WHITE)

func _build_pad() -> void:
	if pad == null:
		return
	for c in pad.get_children():
		pad.remove_child(c)
		c.queue_free()
	var rem: Array = engine.remaining()
	var kw: float = clampf((get_viewport_rect().size.x - 20.0) / 8.0 - 6.0, 40.0, 78.0)
	for v in rem:
		var b := Button.new()
		b.text = str(v)
		b.custom_minimum_size = Vector2(kw, 54)
		b.add_theme_font_size_override("font_size", 24)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "key")
		b.pressed.connect(_on_number.bind(v))
		pad.add_child(b)

func _render() -> void:
	_update_info()
	_build_pad()
	board.queue_redraw()

# ---------- play ----------

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not playing or engine.solved():
		return
	for i in engine.total():
		if _cell_rect(i).has_point(event.position):
			selected = -1 if selected == i else i
			board.queue_redraw()
			return

func _on_number(v: int) -> void:
	if selected < 0:
		_feedback(tr("Tap a cell first"), Color(0.9, 0.8, 0.4))
		return
	if not engine.set_cell(selected, v):
		_sfx("invalid")
		_feedback(tr("That cell is given"), Color(1, 0.7, 0.35))
		return
	_after_change()

func _on_clear() -> void:
	if selected < 0:
		return
	if engine.set_cell(selected, 0):
		_sfx("back")
		_after_change()

func _after_change() -> void:
	_render()
	_save_game()
	if engine.solved():
		_on_solved()
	elif engine.is_complete():
		_feedback(tr("Every number is placed, but some don't touch the next one."), Color(1, 0.45, 0.45))

func _on_hint() -> void:
	if not playing or engine.solved():
		return
	var i := engine.hint()
	if i < 0:
		return
	hints_used += 1
	selected = -1
	_sfx("powerup")
	_after_change()

func _on_check() -> void:
	if not playing or engine.solved():
		return
	var bad := engine.conflicts()
	if bad.is_empty():
		_feedback(tr("No mistakes so far"), Color(0.5, 0.95, 0.5))
		return
	_sfx("letter_wrong")
	checking = true
	_feedback(tr("%d numbers don't touch the next one") % (bad.size() / 2 if bad.size() > 1 else 1), Color(1, 0.45, 0.45))
	board.queue_redraw()
	check_timer.start()

func _end_check() -> void:
	checking = false
	board.queue_redraw()

func _on_solved() -> void:
	playing = false
	selected = -1
	board.queue_redraw()
	_sfx("win")
	if info:
		info.add("Puzzles solved")
		if hints_used == 0:
			info.add("No-hint solves")
		info.best("Best time (%s)" % LEVEL_NAMES[engine.level], elapsed, true)
		info.celebrate(tr("Solved!"))
	SaveUtil.delete(SAVE_PATH)
	var t := int(elapsed)
	end_dialog.get_meta("message_label").text = tr("Time %d:%02d") % [t / 60, t % 60]
	end_dialog.visible = true

func _feedback(text: String, col: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", col)
	feedback_timer.start()

func _clear_feedback() -> void:
	feedback_label.text = ""

# ---------- Landing (home_kit.gd) ----------

func _new_game(level: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.new_game(level)
	elapsed = 0.0
	hints_used = 0
	_begin_play()

func _restart() -> void:
	_new_game(engine.level)

func _begin_play() -> void:
	playing = true
	selected = -1
	checking = false
	end_dialog.visible = false
	_clear_feedback()
	_render()
	_save_game()

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

# ---------- save / resume ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine == null or not playing or engine.solved() or engine.grid.is_empty():
		return
	var d := engine.to_dict()
	d["elapsed"] = elapsed
	d["hints"] = hints_used
	SaveUtil.write(SAVE_PATH, d)

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var t := int(float(d.get("elapsed", 0.0)))
	return tr("Time %d:%02d") % [t / 60, t % 60]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not engine.from_dict(d):
		_new_game(0)
		return
	elapsed = float(d.get("elapsed", 0.0))
	hints_used = int(d.get("hints", 0))
	_begin_play()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
