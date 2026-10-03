extends Control

const SolitaireEngine = preload("res://scripts/games/solitaire/solitaire_engine.gd")
const HomeKit = preload("res://scripts/games/solitaire/home_kit.gd")
const CardData = preload("res://scripts/games/solitaire/card_data.gd")
const CardView = preload("res://scripts/games/solitaire/card_view.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://solitaire_save.json"

const CARD_W := 84
const CARD_H := 118
const COL_GAP := 10
const ROW_GAP := 20
const FAN := 28
const BOARD_WIDTH := 7 * CARD_W + 6 * COL_GAP  # 648
const BOARD_HEIGHT := CARD_H + ROW_GAP + 18 * FAN + CARD_H  # generous room for deep piles

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine

var selected_pile: String = ""
var selected_pile_index: int = -1
var selected_card_index: int = -1

var board_area: Control
var board_holder: Control
var board_scroll: ScrollContainer
var timer_label: Label
var moves_label: Label
var undo_button: Button
var win_dialog: Control
var win_stats_label: Label
var pause_dialog: Control

var elapsed_seconds: float = 0.0
## Double-click / double-tap: a second press on the same card this soon after
## the first sends it to its foundation.
const DOUBLE_TAP_MS := 400
const AUTO_STEP := 0.05  # seconds per card when finishing the game by itself
var last_press: Array = []  # [pile, pile_index, card_index, ticks_msec]
## Finishing by itself (every card face up, stock and waste empty). Input is
## ignored meanwhile; the tween belongs to this scene, so leaving stops it.
var autoplaying: bool = false
var autoplay_tween: Tween
var timer_running: bool = false
var game_active: bool = false

func _ready() -> void:
	preload("res://scripts/games/solitaire/solitaire_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = SolitaireEngine.new()
	_build_ui()
	_start_new_game()  # a deal behind the Home screen; Resume / New deal there

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

	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
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
	pause_button.text = "⏸"
	pause_button.custom_minimum_size = Vector2(76, 64)
	pause_button.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_button)

	timer_label = _stat_label("00:00")
	moves_label = _stat_label(tr("Moves: 0"))
	for l in [timer_label, moves_label]:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_bar.add_child(l)

	undo_button = Button.new()
	undo_button.text = tr("Undo")
	undo_button.pressed.connect(_on_undo_pressed)
	top_bar.add_child(undo_button)

	board_scroll = ScrollContainer.new()
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The board shrinks to the screen width instead of scrolling sideways.
	board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(board_scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_scroll.add_child(center)

	# board_area keeps the fixed 648-wide layout and is scaled down to fit;
	# the holder reserves the scaled size so the containers lay out around it.
	board_holder = Control.new()
	center.add_child(board_holder)
	board_area = Control.new()
	board_area.custom_minimum_size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)
	board_area.size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)
	board_holder.add_child(board_area)
	board_scroll.resized.connect(_fit_board)

	_build_win_dialog()
	_build_pause_dialog()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/solitaire/solitaire_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _fit_board() -> void:
	var avail: float = board_scroll.size.x - 8.0
	var s: float = clampf(avail / BOARD_WIDTH, 0.3, 1.25)
	board_area.scale = Vector2(s, s)
	board_holder.custom_minimum_size = Vector2(BOARD_WIDTH, BOARD_HEIGHT) * s

func _stat_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
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
	title.text = tr("You Win!")
	title.add_theme_font_size_override("font_size", 33)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	win_stats_label = Label.new()
	win_stats_label.add_theme_font_size_override("font_size", 24)
	win_stats_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	win_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_stats_label)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(_go_home)
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
	title.text = tr("Paused")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.LIME.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.LIME, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = tr("Resume")
	resume_btn.custom_minimum_size = Vector2(220, 48)
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)

	var new_deal_btn := Button.new()
	new_deal_btn.text = tr("New Deal")
	new_deal_btn.custom_minimum_size = Vector2(220, 44)
	new_deal_btn.pressed.connect(func():
		pause_dialog.visible = false
		SaveUtil.delete(SAVE_PATH)
		_start_new_game()
	)
	box.add_child(new_deal_btn)

	var exit_btn := Button.new()
	exit_btn.text = tr("Exit to Hub")
	exit_btn.custom_minimum_size = Vector2(220, 44)
	exit_btn.pressed.connect(func():
		_save_game()
		get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
	)
	box.add_child(exit_btn)

# ---------- game flow ----------

func _start_new_game() -> void:
	_stop_autoplay()
	engine.new_game()
	elapsed_seconds = 0.0
	timer_running = true
	game_active = true
	_clear_selection()
	win_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	home.pause()

func _on_resume_pressed() -> void:
	pause_dialog.visible = false
	timer_running = true

func _on_undo_pressed() -> void:
	if autoplaying or not engine.can_undo():
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
		child.queue_free()

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

	moves_label.text = tr("Moves: %d") % engine.move_count

# ---------- interaction ----------

func _on_card_pressed(pile: String, pile_index: int, card_index: int) -> void:
	if autoplaying:
		return
	var now := Time.get_ticks_msec()
	var is_double: bool = not last_press.is_empty() and last_press[0] == pile and last_press[1] == pile_index \
		and last_press[2] == card_index and now - int(last_press[3]) <= DOUBLE_TAP_MS
	last_press = [] if is_double else [pile, pile_index, card_index, now]
	if is_double and _send_to_foundation(pile, pile_index, card_index):
		_clear_selection()
		_after_move()
		return

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
		_after_move()
		return
	# not a valid destination -- maybe they're picking a new source instead
	_try_select(pile, pile_index, card_index)
	_render()

## The top card of a tableau column (or the waste) straight to its foundation.
func _send_to_foundation(pile: String, pile_index: int, card_index: int) -> bool:
	if pile == "waste":
		return engine.move_waste_to_foundation()
	if pile == "tableau" and card_index >= 0 and card_index == engine.tableau[pile_index].size() - 1:
		return engine.move_tableau_to_foundation(pile_index)
	return false

func _after_move() -> void:
	_render()
	if engine.is_won():
		_show_win()
	elif _can_autocomplete():
		_start_autoplay()

## Like the classic Windows game: once nothing is hidden and the stock is
## used up, the rest is a formality, so the cards fly up by themselves.
func _can_autocomplete() -> bool:
	if not engine.stock.is_empty() or not engine.waste.is_empty():
		return false
	for pile in engine.tableau:
		for c in pile:
			if not c.face_up:
				return false
	return true

func _start_autoplay() -> void:
	autoplaying = true
	_autoplay_step()

func _autoplay_step() -> void:
	if not autoplaying:
		return
	if engine.is_won():
		autoplaying = false
		_show_win()
		return
	# lowest card that can go up first, so every foundation fills evenly
	var best_col := -1
	for col in range(7):
		var pile: Array = engine.tableau[col]
		if pile.is_empty():
			continue
		var card = pile.back()
		if engine._can_place_on_foundation(card, card.suit) and (best_col < 0 or card.rank < engine.tableau[best_col].back().rank):
			best_col = col
	if best_col < 0:
		autoplaying = false  # can't happen with everything face up, but never hang
		return
	var pile: Array = engine.tableau[best_col]
	var card = pile.back()
	var from := Vector2(_col_x(best_col), CARD_H + ROW_GAP + (pile.size() - 1) * FAN)
	var to := Vector2(_col_x(3 + card.suit), 0)
	for child in board_area.get_children():
		if child.pile == "tableau" and child.pile_index == best_col and child.card_index == pile.size() - 1:
			child.visible = false
	var flyer := CardView.new()
	flyer.setup("flying", -1, -1)
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.position = from
	flyer.show_face_up(card)
	board_area.add_child(flyer)
	autoplay_tween = create_tween()
	autoplay_tween.tween_property(flyer, "position", to, AUTO_STEP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	autoplay_tween.tween_callback(_land_autoplay_card.bind(best_col))

func _land_autoplay_card(col: int) -> void:
	engine.move_tableau_to_foundation(col)
	_render()
	_autoplay_step()

func _stop_autoplay() -> void:
	autoplaying = false
	if autoplay_tween:
		autoplay_tween.kill()

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
	win_stats_label.text = tr("Time: %s   Moves: %d") % [_format_time(elapsed_seconds), engine.move_count]
	if info:
		info.add("Games won")
		info.celebrate("You win!")
		var fast: bool = info.low("Best time", elapsed_seconds)
		var few: bool = info.low("Fewest moves", engine.move_count)
		if fast or few:
			win_stats_label.text += "\n" + tr("New best!")
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

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/solitaire/solitaire_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/solitaire/solitaire_help.gd"),
		"info": info,
		"accent": HomeKit.LIME,
		"subtitle": "Classic Klondike: build up the foundations from Ace to King.",
		"logo": _draw_home_logo,
		"modes": [{"text": "🃏  New deal", "sub": "Draw one", "action": _fresh_deal}],
		"save_path": SAVE_PATH,
		"resume": _resume_saved,
		"restart": _start_new_game,
		"board": "Games won",
		"board_note": "Games won, all time.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y * 0.8, 140.0)
	var w := h * 0.68
	var o := Vector2(c.size.x / 2.0 - w * 2.2, c.size.y / 2.0 - h / 2.0)
	var suits := ["♠", "♥", "♦", "♣"]
	for i in 4:
		var r := Rect2(o + Vector2(i * w * 1.1, 0), Vector2(w, h))
		var red: bool = i == 1 or i == 2
		c.draw_rect(r, Color(0.05, 0.07, 0.15))
		HomeKit.glow_rect(c, r, HomeKit.PINK if red else HomeKit.CYAN, 2.0)
		HomeKit.glow_text(c, r.get_center() + Vector2(0, -h * 0.12), "A", int(h * 0.3), Color.WHITE)
		HomeKit.glow_text(c, r.get_center() + Vector2(0, h * 0.2), suits[i], int(h * 0.26), HomeKit.PINK if red else HomeKit.CYAN)

func _fresh_deal() -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _resume_saved() -> void:
	if not _load_saved_game():
		_start_new_game()
