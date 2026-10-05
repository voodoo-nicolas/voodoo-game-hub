extends Control

## Shut the Box -- roll, then tap tiles that add up to the roll; they flip
## down as soon as the sum is right. Solo (chase a low score) or vs Computer
## (you play your round, then it plays its own; lower score wins).

const STBEngine = preload("res://scripts/games/shut_the_box/shut_the_box_engine.gd")
const HomeKit = preload("res://scripts/games/shut_the_box/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const PIPS := {1: [[1, 1]], 2: [[0, 0], [2, 2]], 3: [[0, 0], [1, 1], [2, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
	5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]]}
const COLOR_FELT := Color(0.03, 0.04, 0.1)
const COLOR_WOOD := Color("ffae2b")
const COLOR_WOOD_DOWN := Color(0.4, 0.28, 0.1)

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: STBEngine
var vs_computer := true
var phase := "roll"       # roll | pick | cpu | over
var selected: Array = []
var player_score := -1    # your finished round, while the computer plays

var board: Control
var status_label: Label
var mode_btn: Button
var roll_btn: Button
var roll_one_btn: Button
var cpu_timer: Timer
var end_dialog: ColorRect
## Two players on one phone: Player 1 plays a full round, then Player 2.
var two_player := false
var p2_turn := false

func _ready() -> void:
	preload("res://scripts/games/shut_the_box/shut_the_box_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = STBEngine.new()
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
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
	title.text = tr("📦 Shut the Box")
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

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 27)
	status_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.custom_minimum_size = Vector2(0, 100)
	root.add_child(status_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_bottom", 36)
	rm.add_theme_constant_override("margin_left", 24)
	rm.add_theme_constant_override("margin_right", 24)
	rm.add_child(rows)
	root.add_child(rm)
	var roll_row := HBoxContainer.new()
	roll_row.add_theme_constant_override("separation", 14)
	rows.add_child(roll_row)
	roll_btn = _button(tr("🎲🎲 Roll"), _on_roll.bind(false))
	roll_row.add_child(roll_btn)
	roll_one_btn = _button(tr("🎲 Roll one die"), _on_roll.bind(true))
	roll_row.add_child(roll_one_btn)
	mode_btn = _button("", _toggle_mode)
	rows.add_child(mode_btn)

	cpu_timer = Timer.new()
	cpu_timer.wait_time = 0.8
	cpu_timer.timeout.connect(_cpu_step)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/shut_the_box/shut_the_box_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b

# ---------- flow ----------

func _start_new_game() -> void:
	cpu_timer.stop()
	engine.reset()
	phase = "roll"
	selected = []
	player_score = -1
	p2_turn = false
	end_dialog.visible = false
	_refresh(tr("Player 1: roll the dice!") if two_player else tr("Roll the dice to start."))

func _toggle_mode() -> void:
	vs_computer = not vs_computer
	_start_new_game()

func _on_roll(one_die: bool) -> void:
	if phase != "roll":
		return
	engine.roll(one_die)
	_sfx("dice_roll")
	selected = []
	if engine.can_play():
		phase = "pick"
		_refresh(tr("You rolled %d — tap tiles that add up to %d.") % [engine.total, engine.total])
	else:
		_end_player_round()

func _on_board_input(event: InputEvent) -> void:
	if phase != "pick":
		return
	var pos := Vector2(-1, -1)
	# Mouse only: a phone sends each tap as a ScreenTouch AND an emulated
	# mouse click, and handling both selected then unselected the tile.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	else:
		return
	for n in range(1, STBEngine.TILES + 1):
		if _tile_rect(n).has_point(pos) and engine.up[n]:
			if selected.has(n):
				selected.erase(n)
			else:
				selected.append(n)
			_after_pick()
			return

func _after_pick() -> void:
	var sum := 0
	for n in selected:
		sum += n
	if sum == engine.total and engine.flip(selected):
		selected = []
		if engine.is_shut():
			_end_player_round()
			return
		phase = "roll"
		_refresh(tr("Roll again!"))
	elif sum > engine.total:
		selected = []
		_refresh(tr("Too much — those add up to more than %d. Try again.") % engine.total)
	else:
		_refresh(tr("You rolled %d — tap tiles that add up to %d.") % [engine.total, engine.total] + "\n" + tr("Selected: %d") % sum)

func _end_player_round() -> void:
	if two_player:
		if not p2_turn:
			player_score = engine.score()
			if player_score == 0:
				_finish()
				return
			p2_turn = true
			engine.reset()
			phase = "roll"
			selected = []
			_refresh(tr("Player 1 scored %d. Player 2: roll the dice!") % player_score)
			return
		_finish()
		return
	player_score = engine.score()
	if not vs_computer or engine.is_shut():
		_finish()
		return
	phase = "cpu"
	_refresh(tr("No tiles add up to %d. Your score: %d.\nNow the computer plays…") % [engine.total, player_score])
	engine.reset()
	cpu_timer.start()

func _cpu_step() -> void:
	if phase != "cpu":
		cpu_timer.stop()
		return
	if engine.total == 0:
		engine.roll(engine.cpu_wants_one_die())
		if not engine.can_play():
			cpu_timer.stop()
			_finish()
			return
		_refresh(tr("Your score: %d · Computer rolled %d…") % [player_score, engine.total])
	else:
		var pick := engine.best_combo()
		engine.flip(pick)
		if engine.is_shut():
			cpu_timer.stop()
			_finish()
			return
		_refresh(tr("Your score: %d · Computer flips %s.") % [player_score, ", ".join(PackedStringArray(pick.map(func(n): return str(n))))])

func _finish() -> void:
	phase = "over"
	var msg: String
	if two_player:
		var p2 := engine.score() if p2_turn else 99
		if player_score == 0:
			msg = tr("Player 1 shut the box!")
		elif p2 == 0:
			msg = tr("Player 2 shut the box!")
		elif player_score == p2:
			msg = tr("It's a draw!") + "  %d – %d" % [player_score, p2]
		else:
			msg = tr("Player %d wins!") % (1 if player_score < p2 else 2) + "  %d – %d" % [player_score, p2]
		if info:
			info.add("2-player games")
			if player_score == 0 or p2 == 0:
				info.add("Boxes shut")
			info.celebrate(msg)
		_refresh(msg)
		end_dialog.get_meta("message_label").text = msg
		end_dialog.visible = true
		return
	if not vs_computer:
		msg = tr("You shut the box!") if player_score == 0 else tr("Your score: %d") % player_score
		if info:
			info.add("Rounds played")
			if player_score == 0:
				info.add("Boxes shut")
				info.celebrate("Solved!")
			elif info.low("Lowest score", player_score) and player_score > 0:
				msg += "\n" + tr("New best!")
	else:
		var cpu_score := engine.score() if player_score != 0 else 99
		var outcome := "draw"
		if player_score == 0:
			msg = tr("You shut the box!")
			outcome = "win"
		elif cpu_score == 0:
			msg = tr("The computer shut the box!")
			outcome = "loss"
		else:
			msg = tr("You %d · Computer %d") % [player_score, cpu_score] + "\n"
			outcome = "win" if player_score < cpu_score else ("loss" if player_score > cpu_score else "draw")
			msg += {"win": tr("You win!"), "loss": tr("You lose!"), "draw": tr("It's a draw!")}[outcome]
		if info:
			if player_score == 0:
				info.add("Boxes shut")
			info.result(outcome)
			msg += "\n" + info.summary()
	_refresh(msg.split("\n")[0])
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

func _refresh(text: String) -> void:
	status_label.text = text
	roll_btn.disabled = phase != "roll"
	roll_one_btn.disabled = phase != "roll" or not engine.can_roll_one_die()
	mode_btn.text = tr("Mode: vs Computer") if vs_computer else tr("Mode: Solo")
	mode_btn.visible = not two_player
	board.queue_redraw()

# ---------- drawing ----------

func _tile_rect(n: int) -> Rect2:
	var w: float = (board.size.x - 40.0) / STBEngine.TILES
	var h: float = minf(w * 2.1, board.size.y * 0.42)
	return Rect2(Vector2(20.0 + (n - 1) * w + 3.0, board.size.y * 0.08), Vector2(w - 6.0, h))

func _draw_board() -> void:
	var font: Font = ThemeDB.fallback_font
	for n in range(1, STBEngine.TILES + 1):
		var r := _tile_rect(n)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		if engine.up[n]:
			var rim: Color = HomeKit.CYAN if selected.has(n) else COLOR_WOOD
			sb.bg_color = Color(rim, 0.3 if selected.has(n) else 0.14)
			sb.border_color = rim
			sb.set_border_width_all(5 if selected.has(n) else 3)
			sb.shadow_color = Color(rim, 0.4)
			sb.shadow_size = 8
		else:
			sb.bg_color = Color(0.08, 0.06, 0.04)
			sb.border_color = COLOR_WOOD_DOWN
			sb.set_border_width_all(2)
			r = Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, r.size.y * 0.45))
		board.draw_style_box(sb, r)
		var fs := int(r.size.x * 0.62)
		var col := Color(1, 0.95, 0.85) if engine.up[n] else COLOR_WOOD_DOWN
		board.draw_string(font, Vector2(r.position.x, r.position.y + r.size.y / 2.0 + fs * 0.35), str(n), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)
	# dice
	var s: float = minf(120.0, board.size.x * 0.2)
	var y: float = board.size.y * 0.68
	var n_dice: int = engine.dice.size()
	for i in n_dice:
		var total_w: float = n_dice * s + (n_dice - 1) * 30.0
		_draw_die(Rect2(Vector2((board.size.x - total_w) / 2.0 + i * (s + 30.0), y), Vector2(s, s)), engine.dice[i])

func _draw_die(r: Rect2, v: int) -> void:
	var sb := HomeKit.neon_box(HomeKit.CYAN)
	sb.bg_color = Color(HomeKit.CYAN, 0.1)
	sb.set_corner_radius_all(int(r.size.x * 0.16))
	board.draw_style_box(sb, r)
	for sp in PIPS[v]:
		board.draw_circle(r.position + Vector2(0.22 + sp[0] * 0.28, 0.22 + sp[1] * 0.28) * r.size.x, r.size.x * 0.085, Color.WHITE)

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/shut_the_box/shut_the_box_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/shut_the_box/shut_the_box_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Roll the dice and flip down tiles that add up. Shut them all!",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🎲 Solo", "sub": "Lowest score you can", "row": "solo", "action": _new_mode.bind("solo")},
			{"text": "🤖 vs Computer", "sub": "Lower score wins", "row": "solo", "action": _new_mode.bind("cpu")},
			{"text": "👥 2 Players", "sub": "Take turns on one phone", "multi": true, "action": _new_mode.bind("two")},
		],
		"restart": _start_new_game,
		"board": "Boxes shut",
		"board_note": "Times you shut the box, all time.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var w := minf(c.size.x * 0.8, 360.0) / 9.0
	var o := Vector2(c.size.x / 2.0 - w * 4.5, c.size.y / 2.0 - w)
	for n in 9:
		var up: bool = n in [0, 3, 4, 7]
		var r := Rect2(o + Vector2(n * w + 2, 0 if up else w * 1.1), Vector2(w - 4, w * 2.0 if up else w * 0.9))
		HomeKit.glow_rect(c, r, HomeKit.GOLD if up else Color(HomeKit.GOLD, 0.4), 2.0, 0.15)
		if up:
			HomeKit.glow_text(c, r.get_center(), str(n + 1), int(w * 0.6), Color.WHITE)

func _new_mode(m: String) -> void:
	vs_computer = m == "cpu"
	two_player = m == "two"
	_start_new_game()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
