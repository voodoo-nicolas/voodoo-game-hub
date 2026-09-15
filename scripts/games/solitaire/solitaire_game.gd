extends Control

const SolitaireEngine = preload("res://scripts/games/solitaire/solitaire_engine.gd")
const CardData = preload("res://scripts/games/solitaire/card_data.gd")
const CardView = preload("res://scripts/games/solitaire/card_view.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")

const SAVE_PATH := "user://solitaire_save.json"

const CARD_W := 84
const CARD_H := 118
const COL_GAP := 10
const ROW_GAP := 20
const FAN := 28
const BOARD_WIDTH := 7 * CARD_W + 6 * COL_GAP  # 648
const BOARD_HEIGHT := CARD_H + ROW_GAP + 18 * FAN + CARD_H  # generous room for deep piles

var engine

var selected_pile: String = ""
var selected_pile_index: int = -1
var selected_card_index: int = -1

var board_area: Control
var timer_label: Label
var moves_label: Label
var undo_button: Button
var win_dialog: Control
var win_stats_label: Label
var pause_dialog: Control

var elapsed_seconds: float = 0.0
var timer_running: bool = false
var game_active: bool = false

func _ready() -> void:
	Orientation.lock_portrait()
	engine = SolitaireEngine.new()
	_build_ui()
	if not _load_saved_game():
		_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _process(delta: float) -> void:
	if timer_running:
		elapsed_seconds += delta
		timer_label.text = _format_time(elapsed_seconds)

func _format_time(s: float) -> String:
	var total := int(s)
	return "%02d:%02d" % [int(total / 60), total % 60]

# ---------- UI construction ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.28, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 16)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)

	var pause_button := Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_button)

	timer_label = _stat_label("00:00")
	moves_label = _stat_label("Moves: 0")
	for l in [timer_label, moves_label]:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_bar.add_child(l)

	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.pressed.connect(_on_undo_pressed)
	top_bar.add_child(undo_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var center := CenterContainer.new()
	scroll.add_child(center)

	board_area = Control.new()
	board_area.custom_minimum_size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)
	center.add_child(board_area)

	_build_win_dialog()
	_build_pause_dialog()

func _stat_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	return l

func _build_win_dialog() -> void:
	win_dialog = ColorRect.new()
	win_dialog.color = Color(0, 0, 0, 0.75)
	win_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_dialog.visible = false
	add_child(win_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_dialog.add_child(center)

	var panel := PanelContainer.new()
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
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "You Win!"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	win_stats_label = Label.new()
	win_stats_label.add_theme_font_size_override("font_size", 16)
	win_stats_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	win_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_stats_label)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Back to Hub"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(menu_btn)

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
	panel.add_theme_stylebox_override("panel", sb)
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
	resume_btn.custom_minimum_size = Vector2(220, 48)
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)

	var new_deal_btn := Button.new()
	new_deal_btn.text = "New Deal"
	new_deal_btn.custom_minimum_size = Vector2(220, 44)
	new_deal_btn.pressed.connect(func():
		pause_dialog.visible = false
		SaveUtil.delete(SAVE_PATH)
		_start_new_game()
	)
	box.add_child(new_deal_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit to Hub"
	exit_btn.custom_minimum_size = Vector2(220, 44)
	exit_btn.pressed.connect(func():
		_save_game()
		get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
	)
	box.add_child(exit_btn)

# ---------- game flow ----------

func _start_new_game() -> void:
	engine.new_game()
	elapsed_seconds = 0.0
	timer_running = true
	game_active = true
	_clear_selection()
	win_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	if not game_active:
		return
	timer_running = false
	_save_game()
	pause_dialog.visible = true

func _on_resume_pressed() -> void:
	pause_dialog.visible = false
	timer_running = true

func _on_undo_pressed() -> void:
	if not engine.can_undo():
		return
	engine.undo()
	_clear_selection()
	_render()

func _clear_selection() -> void:
	selected_pile = ""
	selected_pile_index = -1
	selected_card_index = -1

func _col_x(col: int) -> float:
	return col * (CARD_W + COL_GAP)

# ---------- rendering ----------

func _render() -> void:
	for child in board_area.get_children():
		board_area.remove_child(child)
		child.free()

	# stock (column 0)
	var stock_view := CardView.new()
	stock_view.setup("stock", 0, 0)
	stock_view.position = Vector2(_col_x(0), 0)
	if engine.stock.is_empty():
		stock_view.show_empty_slot()
	else:
		stock_view.show_face_down()
	stock_view.card_pressed.connect(_on_card_pressed)
	board_area.add_child(stock_view)

	# waste (column 1)
	if engine.waste.is_empty():
		var empty_waste := CardView.new()
		empty_waste.setup("waste", 0, -1)
		empty_waste.position = Vector2(_col_x(1), 0)
		empty_waste.show_empty_slot()
		empty_waste.card_pressed.connect(_on_card_pressed)
		board_area.add_child(empty_waste)
	else:
		var top_index: int = engine.waste.size() - 1
		var waste_view := CardView.new()
		waste_view.setup("waste", 0, top_index)
		waste_view.position = Vector2(_col_x(1), 0)
		waste_view.show_face_up(engine.waste[top_index])
		waste_view.set_selected(selected_pile == "waste")
		waste_view.card_pressed.connect(_on_card_pressed)
		board_area.add_child(waste_view)

	# foundations (columns 3..6)
	for s in range(4):
		var fview := CardView.new()
		fview.setup("foundation", s, engine.foundations[s].size() - 1)
		fview.position = Vector2(_col_x(3 + s), 0)
		if engine.foundations[s].is_empty():
			fview.show_empty_slot()
		else:
			fview.show_face_up(engine.foundations[s].back())
		fview.card_pressed.connect(_on_card_pressed)
		board_area.add_child(fview)

	# tableau
	var tableau_top: float = CARD_H + ROW_GAP
	for col in range(7):
		var pile: Array = engine.tableau[col]
		if pile.is_empty():
			var empty_col := CardView.new()
			empty_col.setup("tableau", col, -1)
			empty_col.position = Vector2(_col_x(col), tableau_top)
			empty_col.show_empty_slot()
			empty_col.card_pressed.connect(_on_card_pressed)
			board_area.add_child(empty_col)
			continue
		for i in range(pile.size()):
			var cview := CardView.new()
			cview.setup("tableau", col, i)
			cview.position = Vector2(_col_x(col), tableau_top + i * FAN)
			var card = pile[i]
			if card.face_up:
				cview.show_face_up(card)
				cview.set_selected(selected_pile == "tableau" and selected_pile_index == col and selected_card_index == i)
			else:
				cview.show_face_down()
			cview.card_pressed.connect(_on_card_pressed)
			board_area.add_child(cview)

	moves_label.text = "Moves: %d" % engine.move_count

# ---------- interaction ----------

func _on_card_pressed(pile: String, pile_index: int, card_index: int) -> void:
	if pile == "stock":
		engine.draw_from_stock()
		_clear_selection()
		_render()
		return

	if selected_pile == "":
		_try_select(pile, pile_index, card_index)
		return

	# tapping the currently-selected card again deselects it
	if selected_pile == pile and selected_pile_index == pile_index and selected_card_index == card_index:
		_clear_selection()
		_render()
		return

	var moved := _try_move_to(pile, pile_index)
	if moved:
		_clear_selection()
		if engine.is_won():
			_show_win()
	else:
		# not a valid destination -- maybe they're picking a new source instead
		_try_select(pile, pile_index, card_index)
	_render()

func _try_select(pile: String, pile_index: int, card_index: int) -> void:
	if pile == "tableau" and card_index >= 0 and engine.tableau[pile_index][card_index].face_up:
		selected_pile = "tableau"
		selected_pile_index = pile_index
		selected_card_index = card_index
		_render()
	elif pile == "waste" and card_index >= 0:
		selected_pile = "waste"
		selected_pile_index = 0
		selected_card_index = card_index
		_render()
	# foundations and empty/face-down cells aren't valid selection sources

func _try_move_to(dest_pile: String, dest_index: int) -> bool:
	if selected_pile == "tableau":
		if dest_pile == "tableau":
			return engine.move_tableau_to_tableau(selected_pile_index, selected_card_index, dest_index)
		elif dest_pile == "foundation":
			# only the top card of the tableau pile can go to a foundation
			if selected_card_index == engine.tableau[selected_pile_index].size() - 1:
				return engine.move_tableau_to_foundation(selected_pile_index)
			return false
	elif selected_pile == "waste":
		if dest_pile == "tableau":
			return engine.move_waste_to_tableau(dest_index)
		elif dest_pile == "foundation":
			return engine.move_waste_to_foundation()
	return false

func _show_win() -> void:
	timer_running = false
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	win_stats_label.text = "Time: %s   Moves: %d" % [_format_time(elapsed_seconds), engine.move_count]
	win_dialog.visible = true

# ---------- save / load ----------

func _serialize_pile(pile: Array) -> Array:
	var out := []
	for c in pile:
		out.append({"rank": c.rank, "suit": c.suit, "face_up": c.face_up})
	return out

func _deserialize_pile(data: Array) -> Array:
	var out := []
	for d in data:
		out.append(CardData.new(int(d.rank), int(d.suit), bool(d.face_up)))
	return out

func _save_game() -> void:
	if not game_active:
		return
	var tableau_data := []
	for pile in engine.tableau:
		tableau_data.append(_serialize_pile(pile))
	var foundations_data := []
	for pile in engine.foundations:
		foundations_data.append(_serialize_pile(pile))

	SaveUtil.write(SAVE_PATH, {
		"tableau": tableau_data,
		"foundations": foundations_data,
		"stock": _serialize_pile(engine.stock),
		"waste": _serialize_pile(engine.waste),
		"move_count": engine.move_count,
		"elapsed_seconds": elapsed_seconds,
	})

## Returns true if a saved game was found and loaded.
func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return false

	engine.tableau = []
	for pile in data.tableau:
		engine.tableau.append(_deserialize_pile(pile))
	engine.foundations = []
	for pile in data.foundations:
		engine.foundations.append(_deserialize_pile(pile))
	engine.stock = _deserialize_pile(data.stock)
	engine.waste = _deserialize_pile(data.waste)
	engine.move_count = int(data.move_count)

	elapsed_seconds = float(data.elapsed_seconds)
	timer_running = true
	game_active = true
	_clear_selection()
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()
	return true
