extends Control

const ReversiEngine = preload("res://scripts/games/reversi/reversi_engine.gd")
const HomeKit = preload("res://scripts/games/reversi/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
## Voodoo Mode (black and white skulls); not preloaded either (apps before v0.21).
const VOODOO_PATH := "res://scripts/common/voodoo.gd"

const SAVE_PATH := "user://reversi_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"

const COLOR_BOARD := Color(0.05, 0.12, 0.13)
const COLOR_HINT := HomeKit.LIME
const COLOR_BLACK := Color(0.08, 0.08, 0.1)
const COLOR_WHITE := Color(0.95, 0.95, 0.92)
## Neon rims: black discs glow magenta, white ones cyan.
const RIM_BLACK := HomeKit.MAGENTA
const RIM_WHITE := HomeKit.CYAN
const LEVELS := ["Easy", "Medium", "Hard"]
const CPU_DELAY := 0.6

var info = null  # GameInfo; null on apps without it, so guard every use
var voodoo = null  # the Voodoo script, null on apps without it
var voodoo_on: bool = false
var marks: Array = []  # 64 Voodoo pieces, one per piece view (empty without Voodoo)
var bg: ColorRect
var engine
var game_active: bool = false
var legal_now: Array = []

var piece_views: Array = []
var hint_views: Array = []
var status_label: Label
var score_label: Label
var win_dialog: Control
var win_label: Label
var home  # HomeKit
## -1 = two players on one phone; 0..2 = against the computer, which plays White.
var cpu_level: int = -1
var cpu_timer: Timer
var rng := RandomNumberGenerator.new()
## Online play (null on apps without it). Host plays Black, guest White;
## my_color == 0 means ordinary same-phone play.
var online: Control = null
var my_color: int = 0

func _ready() -> void:
	preload("res://scripts/games/reversi/reversi_i18n.gd").install(self)
	Orientation.lock_portrait()
	if ResourceLoader.exists(VOODOO_PATH):
		voodoo = load(VOODOO_PATH)
		voodoo_on = voodoo.is_on()
	rng.randomize()
	engine = ReversiEngine.new()
	_build_ui()
	_reset_board()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)

	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var title := Label.new()
	title.text = tr("Reversi")
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.LIME, 0.45))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(score_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 30)
	status_label.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var viewport_width: float = get_viewport_rect().size.x
	var board_margin := 12.0
	var cell_size: float = floor((viewport_width - board_margin * 2.0) / 8.0)
	var board_size: float = cell_size * 8.0

	var board_sb := StyleBoxFlat.new()
	board_sb.bg_color = Color(HomeKit.LIME, 0.25)
	board_sb.set_border_width_all(3)
	board_sb.border_color = HomeKit.LIME
	board_sb.shadow_color = Color(HomeKit.LIME, 0.3)
	board_sb.shadow_size = 12

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", board_sb)
	board_panel.custom_minimum_size = Vector2(board_size, board_size)
	center.add_child(board_panel)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	board_panel.add_child(grid)

	piece_views.resize(64)
	hint_views.resize(64)

	for r in range(8):
		for c in range(8):
			var idx := r * 8 + c
			var sq := Button.new()
			sq.custom_minimum_size = Vector2(cell_size, cell_size)
			sq.flat = false
			sq.focus_mode = Control.FOCUS_NONE
			sq.set_meta("sfx", "")  # a move plays its own sound
			_style_square(sq, COLOR_BOARD)
			sq.pressed.connect(_on_square_pressed.bind(r, c))
			grid.add_child(sq)

			var piece := PanelContainer.new()
			piece.custom_minimum_size = Vector2(cell_size * 0.82, cell_size * 0.82)
			piece.size = piece.custom_minimum_size
			piece.position = Vector2(cell_size * 0.09, cell_size * 0.09)
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piece.visible = false
			sq.add_child(piece)
			piece_views[idx] = piece
			if voodoo:
				var mark: Control = voodoo.new()
				mark.span = 1.15
				piece.add_child(mark)
				marks.append(mark)

			var hint := PanelContainer.new()
			hint.custom_minimum_size = Vector2(cell_size * 0.28, cell_size * 0.28)
			hint.size = hint.custom_minimum_size
			hint.position = Vector2(cell_size * 0.36, cell_size * 0.36)
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hint.visible = false
			var hint_sb := StyleBoxFlat.new()
			hint_sb.bg_color = Color(COLOR_HINT, 0.55)
			var hr := int(hint.custom_minimum_size.x / 2.0)
			hint_sb.corner_radius_top_left = hr
			hint_sb.corner_radius_top_right = hr
			hint_sb.corner_radius_bottom_left = hr
			hint_sb.corner_radius_bottom_right = hr
			hint.add_theme_stylebox_override("panel", hint_sb)
			sq.add_child(hint)
			hint_views[idx] = hint

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	_build_win_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("reversi", tr("Reversi"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_reset_board)
		online.status_changed.connect(_render)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/reversi/reversi_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _build_home() -> void:
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": ["🙂 Easy", "😐 Medium", "😈 Hard"][i], "row": "cpu",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_vs_cpu.bind(i)})
	modes.append({"text": "👥 2 Players", "sub": "Take turns on one phone", "multi": true, "action": _new_two_player})
	if online:
		modes.append({"text": "🌐 Online", "sub": "Play a friend on another phone", "multi": true,
			"color": HomeKit.PURPLE, "action": online.open_lobby})
	home = HomeKit.new({
		"help": preload("res://scripts/games/reversi/reversi_help.gd"),
		"info": info,
		"accent": HomeKit.LIME,
		"solo_heading": "vs Computer",
		"subtitle": "Trap and flip. Own the board when it's full.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _start_new_game,
		"board": "Wins",
		"board_note": "Games won against the computer, at any level.",
		"online": online,
	})
	add_child(home)

func _draw_home_logo(c: Control) -> void:
	var n := 4
	var k := minf(c.size.y / (n + 0.4), 44.0)
	var o := Vector2((c.size.x - k * n) / 2.0, (c.size.y - k * n) / 2.0)
	HomeKit.glow_rect(c, Rect2(o, Vector2(k * n, k * n)), HomeKit.LIME, 2.5, 0.06)
	for i in range(1, n):
		c.draw_line(o + Vector2(k * i, 0), o + Vector2(k * i, k * n), Color(HomeKit.LIME, 0.3), 1.5)
		c.draw_line(o + Vector2(0, k * i), o + Vector2(k * n, k * i), Color(HomeKit.LIME, 0.3), 1.5)
	var black := [Vector2i(1, 1), Vector2i(2, 2), Vector2i(0, 3), Vector2i(3, 0)]
	var white := [Vector2i(2, 1), Vector2i(1, 2)]
	for p in black:
		var ctr := o + (Vector2(p) + Vector2(0.5, 0.5)) * k
		c.draw_circle(ctr, k * 0.36, COLOR_BLACK)
		HomeKit.glow_circle(c, ctr, k * 0.36, RIM_BLACK, 2.0)
	for p in white:
		var ctr := o + (Vector2(p) + Vector2(0.5, 0.5)) * k
		HomeKit.glow_circle(c, ctr, k * 0.36, RIM_WHITE, 2.0, 0.85)
	# a flipping disc: half black, half white
	var f := o + Vector2(3.5, 3.5) * k
	c.draw_arc(f, k * 0.36, PI / 2, PI * 1.5, 24, RIM_WHITE, k * 0.2)
	HomeKit.glow_circle(c, f, k * 0.36, HomeKit.GOLD, 2.0)

func _new_vs_cpu(level: int) -> void:
	cpu_level = level
	SaveUtil.delete(SAVE_PATH)
	_reset_board()

func _new_two_player() -> void:
	cpu_level = -1
	SaveUtil.delete(SAVE_PATH)
	_reset_board()

func _vs_cpu() -> bool:
	return cpu_level >= 0 and not _is_online()

func _maybe_cpu() -> void:
	if game_active and _vs_cpu() and engine.current_player == ReversiEngine.WHITE:
		cpu_timer.start(CPU_DELAY)

func _cpu_turn() -> void:
	if not game_active or not _vs_cpu() or engine.current_player != ReversiEngine.WHITE:
		return
	var m: Vector2i = engine.cpu_move(cpu_level, rng)
	if m.x >= 0:
		_place(m.x, m.y)

func _resume_text() -> String:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return ""
	var lvl := int(data.get("cpu", -1))
	return tr("2 Players") if lvl < 0 else tr(LEVELS[clampi(lvl, 0, 2)])

func _build_win_dialog() -> void:
	win_dialog = Ui.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 Reversi Home"), "action": _go_home},
	], true)
	add_child(win_dialog)
	win_label = win_dialog.get_meta("message_label")

func _go_home() -> void:
	home.go_home()

func _is_online() -> bool:
	return online != null and online.is_online()

func _start_new_game() -> void:
	if online:
		online.new_game()
	_reset_board()

func _reset_board() -> void:
	engine.reset()
	cpu_timer.stop()
	game_active = true
	win_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	home.pause()

func _on_square_pressed(r: int, c: int) -> void:
	if not game_active:
		return
	if _is_online() and not online.can_act(engine.current_player == my_color):
		return
	if _vs_cpu() and engine.current_player != ReversiEngine.BLACK:
		return  # the computer is thinking
	if not legal_now.has(Vector2i(r, c)):
		return
	var result: Dictionary = _place(r, c)
	if result.valid and _is_online():
		online.send_move({"r": r, "c": c})

func _place(r: int, c: int) -> Dictionary:
	var mover: int = engine.current_player
	var result: Dictionary = engine.place(r, c)
	if not result.valid:
		return result
	_sfx("capture" if result.flips.size() > 2 else "place")
	_render()
	if engine.game_over:
		_show_result()
	elif result.passed:
		status_label.text = tr("%s has no move — turn passes back!") % (tr("White") if mover == ReversiEngine.BLACK else tr("Black"))
	_maybe_cpu()
	return result

# ---------- online ----------

func _online_state() -> Dictionary:
	return {"board": engine.board, "current_player": engine.current_player, "game_over": engine.game_over}

func _on_online_started(my_player: int) -> void:
	my_color = ReversiEngine.BLACK if my_player == 1 else ReversiEngine.WHITE
	cpu_level = -1
	home.hide_home()
	_reset_board()

func _on_remote_move(p: Dictionary) -> void:
	if game_active and engine.current_player != my_color:
		_place(int(p.get("r", -1)), int(p.get("c", -1)))

func _on_remote_state(st: Dictionary) -> void:
	var board: Array = []
	for row in st.get("board", []):
		var r: Array = []
		for v in row:
			r.append(int(v))
		board.append(r)
	if board.size() != 8:
		return
	engine.board = board
	engine.current_player = int(st.get("current_player", ReversiEngine.BLACK))
	engine.game_over = bool(st.get("game_over", false))
	game_active = not engine.game_over
	win_dialog.visible = false
	_render()
	if engine.game_over:
		_show_result()

func _show_result() -> void:
	var just_ended := game_active  # a resync of a finished game isn't a new result
	game_active = false
	if not _is_online():  # an online game ending mustn't wipe a paused local one
		SaveUtil.delete(SAVE_PATH)
	var w: int = engine.winner()
	var s: Dictionary = engine.score()
	if w == ReversiEngine.EMPTY:
		win_label.text = tr("It's a tie! %d - %d") % [s.black, s.white]
	elif _is_online():
		win_label.text = "%s %d - %d" % [online.result_text(w == my_color), s.black, s.white]
	elif _vs_cpu():
		win_label.text = (tr("You win!") if w == ReversiEngine.BLACK else tr("The computer wins!")) + "  %d - %d" % [s.black, s.white]
	else:
		win_label.text = tr("%s wins! %d - %d") % [tr("Black") if w == ReversiEngine.BLACK else tr("White"), s.black, s.white]
	if info and just_ended:
		if _is_online():
			info.result("draw" if w == ReversiEngine.EMPTY else ("win" if w == my_color else "loss"), true)
			win_label.text += "\n" + info.summary(["Online wins", "Online losses", "Online draws"])
		elif _vs_cpu():
			info.result("draw" if w == ReversiEngine.EMPTY else ("win" if w == ReversiEngine.BLACK else "loss"))
			if w == ReversiEngine.BLACK:
				info.add("Wins (%s)" % LEVELS[cpu_level])
				info.high("Biggest win (discs)", s.black - s.white)
			win_label.text += "\n" + info.summary(["Wins", "Losses", "Draws"])
		else:
			info.add("Draws" if w == ReversiEngine.EMPTY else ("Black wins" if w == ReversiEngine.BLACK else "White wins"))
			if not (w == ReversiEngine.EMPTY):
				info.celebrate(win_label.text.split("\n")[0])
			win_label.text += "\n" + info.summary(["Black wins", "White wins"])
	win_dialog.visible = true

# ---------- rendering ----------

## Called by the settings drawer's Voodoo toggle.
func _set_voodoo(on: bool) -> void:
	if voodoo == null:
		return
	voodoo_on = on
	_render()

func _render() -> void:
	bg.color = voodoo.BG if voodoo_on else HomeKit.BG
	legal_now = engine.legal_moves(engine.current_player)
	var legal_set := {}
	for m in legal_now:
		legal_set[m] = true

	for r in range(8):
		for c in range(8):
			var idx := r * 8 + c
			var v: int = engine.board[r][c]
			var piece: PanelContainer = piece_views[idx]
			if v == ReversiEngine.EMPTY:
				piece.visible = false
			else:
				piece.visible = true
				if voodoo_on:
					_style_skull(piece, marks[idx], v == ReversiEngine.BLACK)
				else:
					_style_piece(piece, COLOR_BLACK if v == ReversiEngine.BLACK else COLOR_WHITE, RIM_BLACK if v == ReversiEngine.BLACK else RIM_WHITE)
					if voodoo:
						marks[idx].kind = voodoo.NONE
			var my_turn: bool = (not _is_online() or engine.current_player == my_color) \
				and not (_vs_cpu() and engine.current_player == ReversiEngine.WHITE)
			hint_views[idx].visible = legal_set.has(Vector2i(r, c)) and game_active and my_turn

	var s: Dictionary = engine.score()
	score_label.text = tr("⚫ Black: %d      ⚪ White: %d") % [s.black, s.white]
	if game_active:
		var turn_name := tr("Black") if engine.current_player == ReversiEngine.BLACK else tr("White")
		if _is_online():
			status_label.text = online.status_text(engine.current_player == my_color, turn_name)
		elif _vs_cpu():
			status_label.text = tr("Your turn (%s)") % turn_name if engine.current_player == ReversiEngine.BLACK \
				else tr("Computer is thinking...")
		else:
			status_label.text = tr("%s's turn") % turn_name

func _style_square(sq: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(HomeKit.LIME, 0.18)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		sq.add_theme_stylebox_override(state, sb)

func _style_piece(piece: PanelContainer, color: Color, rim: Color = Color.BLACK) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.shadow_color = Color(rim, 0.5)
	sb.shadow_size = 5
	var radius: int = int(piece.custom_minimum_size.x / 2.0)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.set_border_width_all(3)
	sb.border_color = rim
	piece.add_theme_stylebox_override("panel", sb)

## Voodoo Mode: the disc disappears and the skull is the piece -- black with
## glowing red eyes, or bone white.
func _style_skull(piece: PanelContainer, mark: Control, black: bool) -> void:
	piece.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mark.kind = voodoo.SKULL
	mark.fill = COLOR_BLACK if black else COLOR_WHITE
	mark.ink = Color(0.95, 0.22, 0.18) if black else voodoo.INK
	mark.outline = Color(1, 1, 1, 0.3) if black else Color(0, 0, 0, 0.55)

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or _is_online():
		return  # online games aren't resumable alone
	SaveUtil.write(SAVE_PATH, {
		"board": engine.board,
		"current_player": engine.current_player,
		"cpu": cpu_level,
	})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		_reset_board()
		return false
	var board: Array = []
	for row in data.board:
		var r: Array = []
		for v in row:
			r.append(int(v))
		board.append(r)
	engine.board = board
	engine.current_player = int(data.current_player)
	engine.game_over = false
	game_active = true
	cpu_level = clampi(int(data.get("cpu", -1)), -1, 2)
	win_dialog.visible = false
	_render()
	_maybe_cpu()
	return true

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
