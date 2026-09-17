extends Control

const ChessEngine = preload("res://scripts/games/chess/chess_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const SAVE_PATH := "user://chess_save.json"

const COLOR_DARK_SQUARE := Color(0.35, 0.24, 0.15)
const COLOR_LIGHT_SQUARE := Color(0.72, 0.6, 0.48)
const COLOR_SELECTED := Color(1.0, 0.84, 0.04)
const COLOR_DEST := Color(0.4, 0.9, 0.4, 0.6)
const COLOR_CHECK := Color(0.9, 0.2, 0.2, 0.75)
const COLOR_WHITE_PIECE := Color(0.98, 0.98, 0.96)
const COLOR_BLACK_PIECE := Color(0.08, 0.08, 0.1)

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
}

var engine
var game_active: bool = false
var selected: Vector2i = Vector2i(-1, -1)
var dest_map: Dictionary = {}  # Vector2i(dest) -> move dict
var pending_promotion: Dictionary = {}  # {from, to} awaiting a piece choice

var squares: Array = []       # 64 Buttons
var piece_labels: Array = []  # 64 Labels
var status_label: Label
var pause_dialog: Control
var promotion_dialog: Control
var promotion_buttons: Array = []  # 4 Buttons: Queen, Rook, Bishop, Knight
var result_dialog: Control
var result_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = ChessEngine.new()
	_build_ui()
	if not _load_saved_game():
		_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

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
	pause_btn.text = "Pause"
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var title := Label.new()
	title.text = "♟️ Chess"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
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

	_build_pause_dialog()
	_build_promotion_dialog()
	_build_result_dialog()
	add_child(SettingsDrawer.new())

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.18)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	return sb

func _build_pause_dialog() -> void:
	pause_dialog = ColorRect.new()
	pause_dialog.color = Color(0, 0, 0, 0.75)
	pause_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_dialog.visible = false
	add_child(pause_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dialog.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(200, 48)
	resume_btn.pressed.connect(func(): pause_dialog.visible = false)
	box.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.custom_minimum_size = Vector2(200, 44)
	restart_btn.pressed.connect(func():
		pause_dialog.visible = false
		_start_new_game()
	)
	box.add_child(restart_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit to Hub"
	exit_btn.custom_minimum_size = Vector2(200, 44)
	exit_btn.pressed.connect(func():
		_save_game()
		get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
	)
	box.add_child(exit_btn)

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
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Promote to:"
	title.add_theme_font_size_override("font_size", 20)
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
		btn.add_theme_font_size_override("font_size", 36)
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
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 24)
	result_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_label)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		result_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Back to Hub"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(menu_btn)

# ---------- game flow ----------

func _start_new_game() -> void:
	engine.reset()
	game_active = true
	selected = Vector2i(-1, -1)
	dest_map = {}
	pending_promotion = {}
	result_dialog.visible = false
	pause_dialog.visible = false
	promotion_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	if not game_active:
		return
	_save_game()
	pause_dialog.visible = true

func _on_square_pressed(r: int, c: int) -> void:
	if not game_active or promotion_dialog.visible:
		return
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
	selected = Vector2i(-1, -1)
	_render()
	if result.game_over:
		_show_result()

func _show_result() -> void:
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	var msg: String = RESULT_MESSAGES.get(engine.result_reason, "Game over")
	if engine.result_reason == "checkmate":
		msg += "\n%s wins!" % ("White" if engine.winner == ChessEngine.WHITE else "Black")
	result_label.text = msg
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
			var idx := r * 8 + c
			var pos := Vector2i(r, c)
			var sq: Button = squares[idx]
			var is_dark: bool = (r + c) % 2 == 1

			var square_color: Color
			if pos == selected:
				square_color = COLOR_SELECTED
			elif dest_map.has(pos):
				square_color = COLOR_DEST
			elif pos == checked_king:
				square_color = COLOR_CHECK
			else:
				square_color = COLOR_DARK_SQUARE if is_dark else COLOR_LIGHT_SQUARE
			_style_square(sq, square_color)

			var v: int = engine.board[r][c]
			var label: Label = piece_labels[idx]
			if v == 0:
				label.text = ""
			else:
				label.text = PIECE_GLYPHS[v]
				var piece_color: Color = COLOR_WHITE_PIECE if v > 0 else COLOR_BLACK_PIECE
				var outline_color: Color = COLOR_BLACK_PIECE if v > 0 else COLOR_WHITE_PIECE
				label.add_theme_color_override("font_color", piece_color)
				label.add_theme_color_override("font_outline_color", outline_color)

	if not game_active:
		return
	var check_suffix := " — Check!" if checked_king.x >= 0 else ""
	status_label.text = "%s's turn%s" % ["White" if engine.current_player == ChessEngine.WHITE else "Black", check_suffix]

func _style_square(sq: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		sq.add_theme_stylebox_override(state, sb)

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active:
		return
	SaveUtil.write(SAVE_PATH, {
		"board": engine.board,
		"current_player": engine.current_player,
		"castling_rights": engine.castling_rights,
		"en_passant_target": [engine.en_passant_target.x, engine.en_passant_target.y],
		"halfmove_clock": engine.halfmove_clock,
	})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
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
	engine.move_history = []
	engine.game_over = false
	engine.winner = 0
	engine.result_reason = ""

	game_active = true
	selected = Vector2i(-1, -1)
	result_dialog.visible = false
	pause_dialog.visible = false
	promotion_dialog.visible = false
	_render()
	return true
