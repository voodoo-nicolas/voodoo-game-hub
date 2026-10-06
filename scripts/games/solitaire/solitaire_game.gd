extends Control

const SolitaireEngine = preload("res://scripts/games/solitaire/solitaire_engine.gd")
const HomeKit = preload("res://scripts/games/solitaire/home_kit.gd")
const CardData = preload("res://scripts/games/solitaire/card_data.gd")
const CardView = preload("res://scripts/games/solitaire/card_view.gd")
const Victory = preload("res://scripts/games/solitaire/solitaire_victory.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://solitaire_save.json"
## Every win, newest first: {"d": unix time, "t": seconds, "m": moves}.
const HISTORY_PATH := "user://solitaire_history.json"
const HISTORY_MAX := 200

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
var victory  # solitaire_victory.gd: the cascade + results panel
var pause_dialog: Control
var neon_bg: Control
var felt_bg: ColorRect
const FELT := Color(0.05, 0.34, 0.17)
const STYLE_PATH := "user://solitaire_style.json"

var elapsed_seconds: float = 0.0
## Double-click / double-tap: a second press on the same card this soon after
## the first sends it to its foundation.
const DOUBLE_TAP_MS := 400
## Finishing by itself: every card flies to its foundation, a new one
## taking off every FLY_GAP seconds, so several are in the air at once.
const FLY_TIME := 0.26
const FLY_GAP := 0.035
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
	neon_bg = HomeKit.backdrop()
	add_child(neon_bg)
	felt_bg = ColorRect.new()
	felt_bg.color = FELT
	felt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(felt_bg)
	var style = SaveUtil.read(STYLE_PATH)
	CardView.classic = style == null or str(style.get("cards", "classic")) != "neon"
	_apply_card_style()

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

## Classic (white cards on green felt, the default) or Neon cards.
func _apply_card_style() -> void:
	felt_bg.visible = CardView.classic
	neon_bg.visible = not CardView.classic

func _pick_card_style(i: int) -> void:
	CardView.classic = i == 0
	SaveUtil.write(STYLE_PATH, {"cards": "classic" if CardView.classic else "neon"})
	_apply_card_style()
	_render()

## The kit's Look (Options): Classic = these white cards on felt, Voodoo =
## the neon cards with voodoo-doll backs. Same file as before, so a player's
## earlier "neon" pick carries over (_current_skin).
func _set_skin(name: String) -> void:
	var classic := name != "voodoo"
	if classic == CardView.classic:
		return
	_pick_card_style(0 if classic else 1)

func _current_skin() -> String:
	return "classic" if CardView.classic else "voodoo"

func _add_style_picker(box: VBoxContainer) -> void:
	box.add_child(home.section("Cards"))
	box.add_child(home.choice_row(["Classic", "Neon"], 0 if CardView.classic else 1, _pick_card_style))

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
	victory = Victory.new()
	add_child(victory)
	victory.new_deal.connect(_on_victory_new_deal)
	victory.show_history.connect(_show_history)
	victory.show_leaderboard.connect(_on_victory_leaderboard)
	victory.go_home.connect(_go_home)

func _on_victory_new_deal() -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _on_victory_leaderboard() -> void:
	home._show_leaderboard()

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
	victory.stop()
	board_area.visible = true
	_render()

func _on_pause_pressed() -> void:
	home.pause()

func _on_resume_pressed() -> void:
	pause_dialog.visible = false
	timer_running = true

func _on_undo_pressed() -> void:
	if autoplaying or not game_active or not engine.can_undo():
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
		_sfx("card_flip")
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
	_sfx("card_place")
	_render()
	if engine.is_won():
		_record_win()
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

## The game is decided, so it's recorded now; the board keeps showing the
## old layout while the cards fly (they land on top of the foundations),
## then one _render() shows the result.
func _start_autoplay() -> void:
	autoplaying = true
	var flights: Array = []  # [card, column, index in column]
	while not engine.is_won():
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
			break  # can't happen with everything face up, but never hang
		var idx: int = engine.tableau[best_col].size() - 1
		flights.append([engine.tableau[best_col][idx], best_col, idx])
		engine.move_tableau_to_foundation(best_col)
	if not engine.is_won():
		autoplaying = false
		_render()
		return
	_record_win()
	autoplay_tween = create_tween().set_parallel(true)
	for i in flights.size():
		var card = flights[i][0]
		var col: int = flights[i][1]
		var idx: int = flights[i][2]
		var source: Control = null
		for child in board_area.get_children():
			if child.pile == "tableau" and child.pile_index == col and child.card_index == idx:
				source = child
		var flyer := CardView.new()
		flyer.setup("flying", -1, -1)
		flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flyer.position = Vector2(_col_x(col), CARD_H + ROW_GAP + idx * FAN)
		flyer.show_face_up(card)
		flyer.visible = false
		board_area.add_child(flyer)
		var t0: float = i * FLY_GAP
		autoplay_tween.tween_callback(_launch_flyer.bind(source, flyer)).set_delay(t0)
		autoplay_tween.tween_property(flyer, "position", Vector2(_col_x(3 + card.suit), 0), FLY_TIME) \
			.set_delay(t0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		autoplay_tween.tween_callback(_sfx.bind("card_place")).set_delay(t0 + FLY_TIME)
	autoplay_tween.chain().tween_callback(_finish_autoplay)

func _launch_flyer(source: Control, flyer: Control) -> void:
	if is_instance_valid(source):
		source.visible = false
	flyer.visible = true

func _finish_autoplay() -> void:
	autoplaying = false
	_render()
	_show_win()

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

var _last_win: Dictionary = {}

## Stats, history and the save, once per game (the cards may still be flying).
func _record_win() -> void:
	timer_running = false
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	var history := _read_history()
	history.push_front({"d": int(Time.get_unix_time_from_system()), "t": int(elapsed_seconds), "m": engine.move_count})
	if history.size() > HISTORY_MAX:
		history.resize(HISTORY_MAX)
	SaveUtil.write(HISTORY_PATH, {"wins": history})
	_last_win = {"time": int(elapsed_seconds), "moves": engine.move_count, "wins": history.size(), "win_no": history.size()}
	if info:
		info.add("Games won")
		_last_win.best_time = info.low("Best time", int(elapsed_seconds))
		_last_win.best_moves = info.low("Fewest moves", engine.move_count)
		_last_win.wins = int(info.stats.get("Games won", history.size()))
		_last_win.win_no = _last_win.wins

func _show_win() -> void:
	_sfx("record" if _last_win.get("best_time", false) or _last_win.get("best_moves", false) else "win")
	if info and info.has_method("_buzz"):
		info._buzz()
	var to_me: Transform2D = victory.get_global_transform().affine_inverse() * board_area.get_global_transform()
	var slots: Array = []
	for s in 4:
		var p: Vector2 = to_me * Vector2(_col_x(3 + s), 0)
		slots.append(Rect2(p, to_me * Vector2(_col_x(3 + s) + CARD_W, CARD_H) - p))
	board_area.visible = false
	victory.start(engine.foundations, slots, _last_win)

func _read_history() -> Array:
	var data = SaveUtil.read(HISTORY_PATH)
	if data is Dictionary and data.get("wins") is Array:
		return data.wins
	return []

## 📜 History: the totals, then every win (newest first), bests marked.
func _show_history() -> void:
	var parts: Array = home._overlay(tr("📜 History"), HomeKit.PURPLE, true)
	parts[0].visible = true
	var body: VBoxContainer = parts[1]
	var wins := _read_history()
	var total: int = int(info.stats.get("Games won", wins.size())) if info else wins.size()
	var best_t := -1
	var best_m := -1
	var sum_t := 0
	for w in wins:
		var t := int(w.get("t", 0))
		var m := int(w.get("m", 0))
		best_t = t if best_t < 0 else mini(best_t, t)
		best_m = m if best_m < 0 else mini(best_m, m)
		sum_t += t
	body.add_child(home._row(tr("Games won"), str(total), HomeKit.WHITE, HomeKit.LIME, true))
	if not wins.is_empty():
		body.add_child(home._row(tr("Best time"), _format_clock(best_t), HomeKit.WHITE, HomeKit.CYAN))
		body.add_child(home._row(tr("Fewest moves"), str(best_m), HomeKit.WHITE, HomeKit.PINK))
		body.add_child(home._row(tr("Average time"), _format_clock(roundi(float(sum_t) / wins.size())), HomeKit.WHITE, HomeKit.CYAN))
	body.add_child(HomeKit.gap(6))
	body.add_child(home._section(tr("Recent wins")))
	if wins.is_empty():
		body.add_child(HomeKit.label(tr("No wins yet. Finish a deal and it shows up here."), 24, HomeKit.DIM, true))
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	for i in wins.size():
		var w: Dictionary = wins[i]
		var t := int(w.get("t", 0))
		var m := int(w.get("m", 0))
		var when: Dictionary = Time.get_datetime_dict_from_unix_time(int(w.get("d", 0)) + bias)
		var date := "%04d-%02d-%02d  %02d:%02d" % [when.year, when.month, when.day, when.hour, when.minute]
		body.add_child(_history_row(total - i, date, t, m, t == best_t, m == best_m))
	if total > wins.size():
		body.add_child(HomeKit.label(tr("Wins from before the history was kept: %d") % (total - wins.size()), 22, HomeKit.DIM, true))

## One win: number and date on the left, time and moves on the right; a
## best time or fewest moves is gold.
func _history_row(n: int, date: String, t: int, m: int, best_time: bool, best_moves: bool) -> Control:
	var star: bool = best_time or best_moves
	var edge: Color = HomeKit.GOLD if star else HomeKit.PURPLE
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(edge, 0.12) if star else Color(1, 1, 1, 0.04)
	sb.border_color = Color(edge, 0.8) if star else Color(1, 1, 1, 0.1)
	sb.set_border_width_all(2 if star else 1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)
	left.add_child(HomeKit.label(("★ " if star else "") + "#%d" % n, 28, HomeKit.GOLD if star else HomeKit.WHITE))
	left.add_child(HomeKit.label(date, 20, HomeKit.DIM))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	row.add_child(right)
	var tl := HomeKit.label(_format_clock(t), 28, HomeKit.GOLD if best_time else HomeKit.CYAN)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(tl)
	var ml := HomeKit.label(tr("%d moves") % m, 20, HomeKit.GOLD if best_moves else HomeKit.DIM)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(ml)
	return panel

func _format_clock(s: int) -> String:
	return "%d:%02d" % [int(s / 60), s % 60]

func _sfx(sound: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound)

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
	victory.stop()
	board_area.visible = true
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
		"more": [["📜 History", HomeKit.PURPLE, _show_history]],
		# The card look moved to ⚙ Options → Look (STANDARDS §9); the old
		# "Cards" picker (_add_style_picker) is kept for reference.
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
