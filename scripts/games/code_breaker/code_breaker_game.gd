extends Control

## Code Breaker -- pick colours from the palette to fill the current row, then
## Check. Black pegs = right colour in the right spot, white = right colour,
## wrong spot. Tap a filled slot in the current row to clear it.

const CBEngine = preload("res://scripts/games/code_breaker/code_breaker_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")

const PEG_COLORS := [Color(0.93, 0.26, 0.26), Color(0.26, 0.6, 0.95), Color(0.3, 0.8, 0.35),
	Color(0.98, 0.84, 0.2), Color(0.7, 0.4, 0.95), Color(0.98, 0.55, 0.15)]

var engine: CBEngine
var board: Control
var current: Array = []
var end_dialog: ColorRect
var check_btn: Button

func _ready() -> void:
	preload("res://scripts/games/code_breaker/code_breaker_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = CBEngine.new()
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🧠 Code Breaker")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start_new_game)
	bar.add_child(restart_btn)

	var hint := Label.new()
	hint.text = tr("Crack the 4-colour code in 10 tries.\n● right colour & spot   ○ right colour, wrong spot")
	hint.add_theme_font_size_override("font_size", 21)
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
		var sb := StyleBoxFlat.new()
		sb.bg_color = PEG_COLORS[i]
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
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	engine.reset()
	current = [-1, -1, -1, -1]
	end_dialog.visible = false
	_refresh()

func _refresh() -> void:
	check_btn.disabled = current.has(-1) or engine.is_over()
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
	if not engine.submit(current):
		return
	current = [-1, -1, -1, -1]
	_refresh()
	if engine.is_over():
		var msg: String
		if engine.solved:
			msg = tr("Cracked in %d tries!") % engine.guesses.size()
		else:
			msg = tr("Out of tries — the code is shown at the top.")
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
			board.draw_circle(c, r, PEG_COLORS[engine.secret[s]])
		else:
			board.draw_circle(c, r, Color(0.25, 0.25, 0.3))
			board.draw_string(ThemeDB.fallback_font, c + Vector2(-60, r * 0.45), "?", HORIZONTAL_ALIGNMENT_CENTER, 120, int(r * 1.3), Color(0.7, 0.7, 0.8))
	for row in CBEngine.MAX_GUESSES:
		var y := _slot_center(row, 0).y
		var is_current: bool = row == engine.guesses.size() and not engine.is_over()
		if is_current:
			board.draw_rect(Rect2(board.size.x / 2.0 - 260.0, y - rh / 2.0 + 3, 520, rh - 6), Color(1, 1, 1, 0.08))
		var code: Array = []
		if row < engine.guesses.size():
			code = engine.guesses[row].code
		elif is_current:
			code = current
		for s in CBEngine.SLOTS:
			var c := _slot_center(row, s)
			var v: int = code[s] if s < code.size() else -1
			if v >= 0:
				board.draw_circle(c, r, PEG_COLORS[v])
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
