extends Control

const ChessEngine = preload("res://scripts/games/chess/chess_engine.gd")
const HomeKit = preload("res://scripts/games/chess/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://chess_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"

const COLOR_DARK_SQUARE := Color(0.07, 0.1, 0.2)
const COLOR_LIGHT_SQUARE := Color(0.15, 0.2, 0.35)
const COLOR_SELECTED := HomeKit.GOLD
const COLOR_DEST := HomeKit.LIME
const COLOR_CHECK := Color("ff3b4f")
const COLOR_WHITE_PIECE := Color(0.96, 0.99, 1.0)
const COLOR_BLACK_PIECE := Color(0.05, 0.04, 0.08)
## Neon outlines: White's pieces glow cyan, Black's magenta.
const GLOW_WHITE := HomeKit.CYAN
const GLOW_BLACK := HomeKit.MAGENTA
const LEVELS := ["Easy", "Medium", "Hard"]
const CPU_DELAY := 0.35

const PIECE_GLYPHS := {
	1: "♙", -1: "♟",
	2: "♘", -2: "♞",
	3: "♗", -3: "♝",
	4: "♖", -4: "♜",
	5: "♕", -5: "♛",
	6: "♔", -6: "♚",
}

const RESULT_MESSAGES := {
	"checkmate": "Checkmate!",
	"stalemate": "Stalemate — draw",
	"draw_50move": "Draw — 50-move rule",
	"draw_insufficient_material": "Draw — insufficient material",
	"draw_repetition": "Draw — same position 3 times",
}

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var game_active: bool = false
var selected: Vector2i = Vector2i(-1, -1)
var dest_map: Dictionary = {}  # Vector2i(dest) -> move dict
var pending_promotion: Dictionary = {}  # {from, to} awaiting a piece choice

var squares: Array = []       # 64 Buttons
var piece_labels: Array = []  # 64 Labels
var status_label: Label
var promotion_dialog: Control
var promotion_buttons: Array = []  # 4 Buttons: Queen, Rook, Bishop, Knight
var result_dialog: Control
var result_label: Label
var home  # HomeKit
## -1 = two players on one phone; 0..2 = against the computer, which plays Black.
var cpu_level: int = -1
var cpu_timer: Timer
## The computer thinks in a thread (up to ~1.6 s) so the screen stays alive.
var cpu_thread: Thread
## Bumped on every new game, so a reply to an old position is thrown away.
var cpu_token: int = 0
var cpu_busy: bool = false
var rng := RandomNumberGenerator.new()
## Online play (null on apps without it). Host plays White, guest Black and
## sees the board flipped (Black at the bottom). my_color uses the engine's
## WHITE / BLACK; 0 = same-phone play.
var online: Control = null
var my_color: int = 0
var flipped: bool = false

func _ready() -> void:
	preload("res://scripts/games/chess/chess_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = ChessEngine.new()
	_build_ui()
	_reset_board()

func _exit_tree() -> void:
	if cpu_thread and cpu_thread.is_started():
		cpu_thread.wait_to_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
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
	title.text = tr("Chess")
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0))
	title.add_theme_color_override("font_outline_color", Color(GLOW_WHITE, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 32)
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

	var board_wrap := Control.new()
	board_wrap.custom_minimum_size = Vector2(board_size, board_size)
	center.add_child(board_wrap)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	board_wrap.add_child(grid)

	squares.resize(64)
	piece_labels.resize(64)

	for r in range(8):
		for c in range(8):
			var idx := r * 8 + c
			var sq := Button.new()
			sq.custom_minimum_size = Vector2(cell_size, cell_size)
			sq.flat = false
			sq.focus_mode = Control.FOCUS_NONE
			sq.pressed.connect(_on_square_pressed.bind(r, c))
			grid.add_child(sq)
			squares[idx] = sq

			var label := Label.new()
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", int(cell_size * 0.62))
			label.add_theme_constant_override("outline_size", max(3, int(cell_size * 0.07)))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sq.add_child(label)
			piece_labels[idx] = label

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_start)
	add_child(cpu_timer)

	_build_promotion_dialog()
	_build_result_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("chess", tr("Chess"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_reset_board)
		online.status_changed.connect(_render)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/chess/chess_help.gd"))
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
		"help": preload("res://scripts/games/chess/chess_help.gd"),
		"info": info,
		"accent": GLOW_WHITE,
		"solo_heading": "vs Computer",
		"subtitle": "Checkmate the king. Play the computer or a friend.",
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
	var k := minf(c.size.y / (n + 0.3), 44.0)
	var o := Vector2((c.size.x - k * n) / 2.0, (c.size.y - k * n) / 2.0)
	for y in n:
		for x in n:
			if (x + y) % 2 == 1:
				c.draw_rect(Rect2(o + Vector2(x, y) * k, Vector2(k, k)), Color(HomeKit.BLUE, 0.2))
	HomeKit.glow_rect(c, Rect2(o, Vector2(k * n, k * n)), HomeKit.BLUE, 2.5)
	var font := ThemeDB.fallback_font
	var fs := int(k * 1.5)
	for spec in [["♚", Vector2(1.45, 2.05), GLOW_BLACK, COLOR_BLACK_PIECE], ["♔", Vector2(2.55, 2.05), GLOW_WHITE, COLOR_WHITE_PIECE]]:
		var w := font.get_string_size(spec[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos: Vector2 = o + spec[1] * k + Vector2(-w / 2.0, font.get_ascent(fs) * 0.5)
		for g in [[12, 0.12], [6, 0.35], [3, 1.0]]:
			c.draw_string_outline(font, pos, spec[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, g[0], Color(spec[2], g[1]))
		c.draw_string(font, pos, spec[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, spec[3])

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
	if game_active and _vs_cpu() and engine.current_player == ChessEngine.BLACK and not cpu_busy:
		cpu_busy = true
		cpu_timer.start(CPU_DELAY)
		_render()

func _cpu_start() -> void:
	if not game_active or not _vs_cpu():
		cpu_busy = false
		return
	if cpu_thread and cpu_thread.is_started():
		cpu_thread.wait_to_finish()
	cpu_thread = Thread.new()
	cpu_thread.start(_cpu_think.bind(engine.clone(), cpu_level, rng.randi(), cpu_token))

## Runs in the thread, on a copy of the game.
func _cpu_think(copy, level: int, seed_value: int, token: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var mv: Dictionary = copy.cpu_move(level, r)
	call_deferred("_cpu_done", mv, token)

func _cpu_done(mv: Dictionary, token: int) -> void:
	if cpu_thread and cpu_thread.is_started():
		cpu_thread.wait_to_finish()
	cpu_busy = false
	if token != cpu_token or not game_active or mv.is_empty() or engine.current_player != ChessEngine.BLACK:
		return
	_apply_move(mv.from, mv.to, ChessEngine.QUEEN)

func _resume_text() -> String:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return ""
	var lvl := int(data.get("cpu", -1))
	return tr("2 Players") if lvl < 0 else tr(LEVELS[clampi(lvl, 0, 2)])

func _build_promotion_dialog() -> void:
	promotion_dialog = ColorRect.new()
	promotion_dialog.color = Color(0, 0, 0, 0.75)
	promotion_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	promotion_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	promotion_dialog.visible = false
	add_child(promotion_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	promotion_dialog.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("Promote to:")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	for choice in [ChessEngine.QUEEN, ChessEngine.ROOK, ChessEngine.BISHOP, ChessEngine.KNIGHT]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.add_theme_font_size_override("font_size", 43)
		btn.pressed.connect(_on_promotion_chosen.bind(choice))
		row.add_child(btn)
		# Glyph shown always matches the mover's color, set at prompt-time in
		# _show_promotion_dialog() since we don't know whose pawn yet here.
		btn.set_meta("piece_type", choice)
		promotion_buttons.append(btn)

func _build_result_dialog() -> void:
	result_dialog = ColorRect.new()
	result_dialog.color = Color(0, 0, 0, 0.75)
	result_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_dialog.visible = false
	add_child(result_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_dialog.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 31)
	result_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_label)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(320, 64)
	again_btn.pressed.connect(func():
		result_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 Chess Home")
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(_go_home)
	box.add_child(menu_btn)

func _go_home() -> void:
	home.go_home()

# ---------- game flow ----------

func _is_online() -> bool:
	return online != null and online.is_online()

func _start_new_game() -> void:
	if online:
		online.new_game()
	_reset_board()

func _reset_board() -> void:
	engine.reset()
	cpu_token += 1
	cpu_busy = false
	cpu_timer.stop()
	game_active = true
	selected = Vector2i(-1, -1)
	dest_map = {}
	pending_promotion = {}
	result_dialog.visible = false
	promotion_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	home.pause()

## Screen square -> board square. Black's view is rotated 180 degrees.
func _view_index(r: int, c: int) -> int:
	return (7 - r) * 8 + (7 - c) if flipped else r * 8 + c

func _on_square_pressed(vr: int, vc: int) -> void:
	if not game_active or promotion_dialog.visible:
		return
	if _is_online() and not online.can_act(engine.current_player == my_color):
		return
	if _vs_cpu() and engine.current_player != ChessEngine.WHITE:
		return  # the computer is thinking
	var r: int = 7 - vr if flipped else vr
	var c: int = 7 - vc if flipped else vc
	var pos := Vector2i(r, c)

	if dest_map.has(pos):
		if engine.is_promotion_move(selected, pos):
			pending_promotion = {"from": selected, "to": pos}
			_show_promotion_dialog()
			return
		_apply_move(selected, pos, ChessEngine.QUEEN)
		return

	if pos == selected:
		selected = Vector2i(-1, -1)
		_render()
		return

	var piece: int = engine.board[r][c]
	if piece != 0 and engine.owner_of(piece) == engine.current_player:
		selected = pos
	else:
		selected = Vector2i(-1, -1)
	_render()

func _show_promotion_dialog() -> void:
	var mover: int = engine.current_player
	for btn in promotion_buttons:
		var ptype: int = btn.get_meta("piece_type")
		btn.text = PIECE_GLYPHS[ptype * mover]
		btn.add_theme_color_override("font_color", COLOR_WHITE_PIECE if mover == ChessEngine.WHITE else COLOR_BLACK_PIECE)
	promotion_dialog.visible = true

func _on_promotion_chosen(piece_type: int) -> void:
	promotion_dialog.visible = false
	_apply_move(pending_promotion.from, pending_promotion.to, piece_type)
	pending_promotion = {}

func _apply_move(from: Vector2i, to: Vector2i, promotion_piece: int) -> void:
	var result: Dictionary = engine.move(from, to, promotion_piece)
	if not result.valid:
		return
	if _is_online() and engine.current_player != my_color:  # it was our move
		online.send_move({"from": [from.x, from.y], "to": [to.x, to.y], "promo": promotion_piece})
	selected = Vector2i(-1, -1)
	_render()
	_sfx("capture" if result.is_capture else "place")
	if result.game_over:
		_show_result()
	else:
		_maybe_cpu()

## Plays a sound from the app's library (silent on apps from before v0.23).
func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

# ---------- online ----------

func _online_state() -> Dictionary:
	return {
		"board": engine.board, "current_player": engine.current_player,
		"castling_rights": engine.castling_rights,
		"en_passant_target": [engine.en_passant_target.x, engine.en_passant_target.y],
		"halfmove_clock": engine.halfmove_clock, "position_counts": engine.position_counts,
		"game_over": engine.game_over, "winner": engine.winner, "result_reason": engine.result_reason,
	}

func _on_online_started(my_player: int) -> void:
	my_color = ChessEngine.WHITE if my_player == 1 else ChessEngine.BLACK
	flipped = my_color == ChessEngine.BLACK
	cpu_level = -1
	home.hide_home()
	_reset_board()

func _on_remote_move(p: Dictionary) -> void:
	if not game_active or engine.current_player == my_color:
		return
	var f: Array = p.get("from", [-1, -1])
	var t: Array = p.get("to", [-1, -1])
	promotion_dialog.visible = false
	pending_promotion = {}
	_apply_move(Vector2i(int(f[0]), int(f[1])), Vector2i(int(t[0]), int(t[1])), int(p.get("promo", ChessEngine.QUEEN)))

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
	engine.current_player = int(st.get("current_player", ChessEngine.WHITE))
	var rights = st.get("castling_rights", {})
	engine.castling_rights = {
		"K": bool(rights.get("K", false)), "Q": bool(rights.get("Q", false)),
		"k": bool(rights.get("k", false)), "q": bool(rights.get("q", false)),
	}
	var ep: Array = st.get("en_passant_target", [-1, -1])
	engine.en_passant_target = Vector2i(int(ep[0]), int(ep[1]))
	engine.halfmove_clock = int(st.get("halfmove_clock", 0))
	engine.position_counts = {}
	var counts = st.get("position_counts", {})
	for key in counts:
		engine.position_counts[str(key)] = int(counts[key])
	engine.game_over = bool(st.get("game_over", false))
	engine.winner = int(st.get("winner", 0))
	engine.result_reason = str(st.get("result_reason", ""))
	game_active = not engine.game_over
	selected = Vector2i(-1, -1)
	pending_promotion = {}
	promotion_dialog.visible = false
	result_dialog.visible = false
	_render()
	if engine.game_over:
		_show_result()

func _show_result() -> void:
	var just_ended := game_active  # a resync of a finished game isn't a new result
	game_active = false
	if not _is_online():  # an online game ending mustn't wipe a paused local one
		SaveUtil.delete(SAVE_PATH)
	var msg: String = RESULT_MESSAGES.get(engine.result_reason, tr("Game over"))
	if engine.result_reason == "checkmate" and _is_online():
		msg += "\n" + online.result_text(engine.winner == my_color)
	elif engine.result_reason == "checkmate" and _vs_cpu():
		msg += "\n" + (tr("You win!") if engine.winner == ChessEngine.WHITE else tr("The computer wins!"))
	elif engine.result_reason == "checkmate":
		msg += tr("\n%s wins!") % (tr("White") if engine.winner == ChessEngine.WHITE else tr("Black"))
	result_label.text = msg
	if info and just_ended:
		if _is_online():
			info.result("draw" if engine.result_reason != "checkmate" else ("win" if engine.winner == my_color else "loss"), true)
			result_label.text += "\n" + info.summary(["Online wins", "Online losses", "Online draws"])
		elif _vs_cpu():
			info.result("draw" if engine.result_reason != "checkmate" else ("win" if engine.winner == ChessEngine.WHITE else "loss"))
			if engine.result_reason == "checkmate" and engine.winner == ChessEngine.WHITE:
				info.add("Wins (%s)" % LEVELS[cpu_level])
			result_label.text += "\n" + info.summary(["Wins", "Losses", "Draws"])
		else:
			info.add("Draws" if engine.result_reason != "checkmate" else ("White wins" if engine.winner == ChessEngine.WHITE else "Black wins"))
			if not (engine.result_reason != "checkmate"):
				info.celebrate(result_label.text.split("\n")[0])
			result_label.text += "\n" + info.summary(["White wins", "Black wins"])
	result_dialog.visible = true

# ---------- rendering ----------

func _render() -> void:
	dest_map = {}
	if selected.x >= 0:
		for m in engine.legal_moves_for(selected.x, selected.y):
			dest_map[m.to] = m

	var checked_king: Vector2i = Vector2i(-1, -1)
	if game_active and engine.is_in_check(engine.current_player):
		checked_king = engine.find_king(engine.current_player)

	for r in range(8):
		for c in range(8):
			var idx := _view_index(r, c)
			var pos := Vector2i(r, c)
			var sq: Button = squares[idx]
			var is_dark: bool = (r + c) % 2 == 1

			var edge := Color(0, 0, 0, 0)
			if pos == selected:
				edge = COLOR_SELECTED
			elif dest_map.has(pos):
				edge = COLOR_DEST
			elif pos == checked_king:
				edge = COLOR_CHECK
			_style_square(sq, COLOR_DARK_SQUARE if is_dark else COLOR_LIGHT_SQUARE, edge)

			var v: int = engine.board[r][c]
			var label: Label = piece_labels[idx]
			if v == 0:
				label.text = ""
			else:
				label.text = PIECE_GLYPHS[v]
				var piece_color: Color = COLOR_WHITE_PIECE if v > 0 else COLOR_BLACK_PIECE
				var outline_color: Color = GLOW_WHITE if v > 0 else GLOW_BLACK
				label.add_theme_color_override("font_color", piece_color)
				label.add_theme_color_override("font_outline_color", outline_color)

	if not game_active:
		return
	var check_suffix := tr(" — Check!") if checked_king.x >= 0 else ""
	var side := tr("White") if engine.current_player == ChessEngine.WHITE else tr("Black")
	if _is_online():
		status_label.text = online.status_text(engine.current_player == my_color, side + check_suffix)
	elif _vs_cpu():
		status_label.text = (tr("Your turn (%s)") % side + check_suffix) if engine.current_player == ChessEngine.WHITE \
			else tr("Computer is thinking...")
	else:
		status_label.text = tr("%s's turn%s") % [side, check_suffix]

func _style_square(sq: Button, color: Color, edge: Color = Color(0, 0, 0, 0)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color if edge.a == 0.0 else color.lerp(edge, 0.28)
	if edge.a > 0.0:
		sb.border_color = edge
		sb.set_border_width_all(3)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		sq.add_theme_stylebox_override(state, sb)

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or _is_online():
		return  # online games aren't resumable alone
	SaveUtil.write(SAVE_PATH, {
		"board": engine.board,
		"current_player": engine.current_player,
		"castling_rights": engine.castling_rights,
		"en_passant_target": [engine.en_passant_target.x, engine.en_passant_target.y],
		"halfmove_clock": engine.halfmove_clock,
		"position_counts": engine.position_counts,
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

	var rights_data: Dictionary = data.castling_rights
	engine.castling_rights = {
		"K": bool(rights_data.get("K", false)), "Q": bool(rights_data.get("Q", false)),
		"k": bool(rights_data.get("k", false)), "q": bool(rights_data.get("q", false)),
	}
	var ep: Array = data.en_passant_target
	engine.en_passant_target = Vector2i(int(ep[0]), int(ep[1]))
	engine.halfmove_clock = int(data.halfmove_clock)
	engine.position_counts = {}
	var counts = data.get("position_counts", {})
	if typeof(counts) == TYPE_DICTIONARY:
		for key in counts:
			engine.position_counts[str(key)] = int(counts[key])
	if engine.position_counts.is_empty():
		engine.record_position()  # saves from before repetition tracking
	engine.move_history = []
	engine.game_over = false
	engine.winner = 0
	engine.result_reason = ""

	game_active = true
	cpu_level = clampi(int(data.get("cpu", -1)), -1, 2)
	cpu_token += 1
	cpu_busy = false
	selected = Vector2i(-1, -1)
	result_dialog.visible = false
	promotion_dialog.visible = false
	_render()
	_maybe_cpu()
	return true
