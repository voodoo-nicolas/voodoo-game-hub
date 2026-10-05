extends Control

## Code Breaker -- pick colours from the palette to fill the current row, then
## Check. Black pegs = right colour in the right spot, white = right colour,
## wrong spot. Tap a filled slot in the current row to clear it.

const CBEngine = preload("res://scripts/games/code_breaker/code_breaker_engine.gd")
const HomeKit = preload("res://scripts/games/code_breaker/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://code_breaker_save.json"

const PEG_COLORS := [Color(0.93, 0.26, 0.26), Color(0.26, 0.6, 0.95), Color(0.3, 0.8, 0.35),
	Color(0.98, 0.84, 0.2), Color(0.7, 0.4, 0.95), Color(0.98, 0.55, 0.15)]

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: CBEngine
var board: Control
var current: Array = []
var end_dialog: ColorRect
var check_btn: Button
var hint_label: Label
## Two players: the code master picks the secret first (setting = true).
var two_player := false
var setting := false
var started := false  # a game is on (not just the one behind Home)

func _ready() -> void:
	preload("res://scripts/games/code_breaker/code_breaker_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = CBEngine.new()
	_build_ui()
	_start_new_game()
	started = false

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
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
	title.text = tr("🧠 Code Breaker")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start_new_game)
	bar.add_child(restart_btn)

	var hint := Label.new()
	hint_label = hint
	hint.text = tr("Crack the 4-colour code in 10 tries.\n● right colour & spot   ○ right colour, wrong spot")
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var palette := HBoxContainer.new()
	palette.alignment = BoxContainer.ALIGNMENT_CENTER
	palette.add_theme_constant_override("separation", 12)
	root.add_child(palette)
	for i in CBEngine.COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(88, 88)
		b.focus_mode = Control.FOCUS_NONE
		var sb := HomeKit.neon_box(PEG_COLORS[i], "pressed")
		sb.bg_color = Color(PEG_COLORS[i], 0.55)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(44)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_on_color.bind(i))
		palette.add_child(b)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	var am := MarginContainer.new()
	am.add_theme_constant_override("margin_bottom", 36)
	am.add_child(actions)
	root.add_child(am)
	var back := Button.new()
	back.text = "⌫"
	back.custom_minimum_size = Vector2(140, 70)
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(_on_backspace)
	actions.add_child(back)
	check_btn = Button.new()
	check_btn.text = tr("Check")
	check_btn.custom_minimum_size = Vector2(260, 70)
	check_btn.add_theme_font_size_override("font_size", 30)
	check_btn.pressed.connect(_on_check)
	actions.add_child(check_btn)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/code_breaker/code_breaker_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	result_recorded = false
	started = true
	engine.reset()
	current = [-1, -1, -1, -1]
	end_dialog.visible = false
	setting = two_player
	_refresh()

func _refresh() -> void:
	check_btn.disabled = current.has(-1) or engine.is_over()
	check_btn.text = tr("🔒 Lock code") if setting else tr("Check")
	if setting:
		hint_label.text = tr("Code master: pick the secret code, then lock it.\nCode breaker — look away!")
	elif two_player:
		hint_label.text = tr("Code breaker: crack it in 10 tries.\n● right colour & spot   ○ right colour, wrong spot")
	else:
		hint_label.text = tr("Crack the 4-colour code in 10 tries.\n● right colour & spot   ○ right colour, wrong spot")
	board.queue_redraw()

func _on_color(i: int) -> void:
	if engine.is_over():
		return
	var slot := current.find(-1)
	if slot >= 0:
		current[slot] = i
	_refresh()

func _on_backspace() -> void:
	for i in range(CBEngine.SLOTS - 1, -1, -1):
		if current[i] != -1:
			current[i] = -1
			break
	_refresh()

func _on_check() -> void:
	if setting:
		if current.has(-1):
			return
		engine.secret = current.duplicate()
		current = [-1, -1, -1, -1]
		setting = false
		_refresh()
		return
	if not engine.submit(current):
		_sfx("invalid")
		return
	_sfx("place")
	current = [-1, -1, -1, -1]
	_refresh()
	if engine.is_over():
		SaveUtil.delete(SAVE_PATH)
		if two_player:
			var m2 := tr("The code breaker cracked it in %d tries!") % engine.guesses.size() if engine.solved \
				else tr("The code master wins — the code is shown at the top.")
			if info and not result_recorded:
				result_recorded = true
				info.add("Codes cracked (2 players)" if engine.solved else "Codes kept (2 players)")
				if engine.solved:
					info.celebrate(tr("Cracked!"))
			end_dialog.get_meta("message_label").text = m2
			end_dialog.visible = true
			return
		var msg: String
		if engine.solved:
			msg = tr("Cracked in %d tries!") % engine.guesses.size()
		else:
			msg = tr("Out of tries — the code is shown at the top.")
		if info and engine.solved and not result_recorded:
			if info.low("Fewest tries", engine.guesses.size()):
				msg += "\n" + tr("New best!")
		msg += _record_result("win" if engine.solved else "loss")
		end_dialog.get_meta("message_label").text = msg
		end_dialog.visible = true

# ---------- drawing ----------

func _row_h() -> float:
	return min(92.0, board.size.y / (CBEngine.MAX_GUESSES + 1.3))

func _slot_center(row: int, slot: int) -> Vector2:
	var rh := _row_h()
	var left := board.size.x / 2.0 - 250.0
	return Vector2(left + 60.0 + slot * rh * 1.05, rh * 1.3 + rh * (row + 0.5))

func _draw_board() -> void:
	var rh := _row_h()
	var r := rh * 0.36
	# secret row
	for s in CBEngine.SLOTS:
		var c := _slot_center(-1, s) - Vector2(0, rh * 0.3)
		if engine.is_over():
			HomeKit.glow_circle(board, c, r, PEG_COLORS[engine.secret[s]], 2.0, 0.6)
		else:
			board.draw_circle(c, r, Color(0.25, 0.25, 0.3))
			board.draw_string(ThemeDB.fallback_font, c + Vector2(-60, r * 0.45), "?", HORIZONTAL_ALIGNMENT_CENTER, 120, int(r * 1.3), Color(0.7, 0.7, 0.8))
	for row in CBEngine.MAX_GUESSES:
		var y := _slot_center(row, 0).y
		var is_current: bool = row == engine.guesses.size() and not engine.is_over()
		if is_current:
			HomeKit.glow_rect(board, Rect2(board.size.x / 2.0 - 260.0, y - rh / 2.0 + 3, 520, rh - 6), HomeKit.CYAN, 1.5, 0.06)
		var code: Array = []
		if row < engine.guesses.size():
			code = engine.guesses[row].code
		elif is_current:
			code = current
		for s in CBEngine.SLOTS:
			var c := _slot_center(row, s)
			var v: int = code[s] if s < code.size() else -1
			if v >= 0:
				HomeKit.glow_circle(board, c, r, PEG_COLORS[v], 2.0, 0.6)
			else:
				board.draw_circle(c, r * 0.4, Color(0.3, 0.3, 0.36))
		if row < engine.guesses.size():
			var g: Dictionary = engine.guesses[row]
			var fx := _slot_center(row, CBEngine.SLOTS).x + 20.0
			var pr := rh * 0.12
			for k in CBEngine.SLOTS:
				var p := Vector2(fx + (k % 2) * pr * 3.0, y + (-0.75 + (k / 2) * 1.5) * pr * 1.4)
				if k < g.exact:
					board.draw_circle(p, pr, Color(0.05, 0.05, 0.05))
					board.draw_arc(p, pr, 0, TAU, 16, Color(0.8, 0.8, 0.8), 1.5)
				elif k < g.exact + g.near:
					board.draw_circle(p, pr, Color(0.95, 0.95, 0.95))
				else:
					board.draw_arc(p, pr * 0.6, 0, TAU, 12, Color(0.35, 0.35, 0.4), 1.5)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if engine.is_over():
		return
	var row: int = engine.guesses.size()
	for s in CBEngine.SLOTS:
		if event.position.distance_to(_slot_center(row, s)) < _row_h() * 0.5:
			current[s] = -1
			_refresh()
			return


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/code_breaker/code_breaker_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/code_breaker/code_breaker_help.gd"),
		"info": info,
		"accent": HomeKit.MAGENTA,
		"subtitle": "Crack the secret 4-colour code in 10 tries.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🧠  Crack the computer's code", "sub": "Solo", "action": _new_game.bind(false)},
			{"text": "👥  Code master vs code breaker", "sub": "One player sets the code, the other cracks it", "multi": true, "action": _new_game.bind(true)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): return tr("Try %d of %d") % [int((SaveUtil.read(SAVE_PATH) if SaveUtil.read(SAVE_PATH) else {}).get("guesses", []).size()) + 1, CBEngine.MAX_GUESSES],
		"restart": _start_new_game,
		"board": "Wins",
		"board_note": "Codes cracked on your own.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var r := minf(c.size.y / 7.0, 22.0)
	var o := Vector2(c.size.x / 2.0 - r * 5.5, c.size.y / 2.0 - r * 2.6)
	var rows := [[0, 3, 2, 5], [0, 1, 4, 2], [0, 1, 2, 3]]
	for y in 3:
		for x in 4:
			HomeKit.glow_circle(c, o + Vector2(x * r * 2.6, y * r * 2.6), r, PEG_COLORS[rows[y][x]], 2.0, 0.5)
		for k in 4:
			var p := o + Vector2(4 * r * 2.6 + (k % 2) * r * 0.9, y * r * 2.6 + (-0.4 + (k / 2) * 0.8) * r)
			var hit: int = [1, 2, 4][y]
			if k < hit:
				c.draw_circle(p, r * 0.25, Color.WHITE if y < 2 else HomeKit.LIME)
			else:
				c.draw_arc(p, r * 0.25, 0, TAU, 12, Color(1, 1, 1, 0.35), 1.5)

func _new_game(two: bool) -> void:
	two_player = two
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not started or engine.is_over() or setting:
		return
	SaveUtil.write(SAVE_PATH, {"secret": engine.secret, "guesses": engine.guesses, "current": current, "two": two_player})

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	_start_new_game()
	two_player = bool(d.get("two", false))
	setting = false
	engine.secret = _ints(d.secret)
	engine.guesses = []
	for g in d.get("guesses", []):
		engine.guesses.append({"code": _ints(g.code), "exact": int(g.exact), "near": int(g.near)})
	var cur := _ints(d.get("current", [-1, -1, -1, -1]))
	current = cur if cur.size() == CBEngine.SLOTS else [-1, -1, -1, -1]
	_refresh()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
