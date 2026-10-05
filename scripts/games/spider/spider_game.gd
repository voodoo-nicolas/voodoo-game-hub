extends Control

## Spider Solitaire -- tap a card to move it (with the cards below it) to the
## best spot. Tap the stock (top left) to deal a new row.

const SpiderEngine = preload("res://scripts/games/spider/spider_engine.gd")
const HomeKit = preload("res://scripts/games/spider/home_kit.gd")
const Cards = preload("res://scripts/games/spider/spider_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_FELT := Color(0.03, 0.04, 0.1)
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://spider_save.json"

var result_recorded := false  # this deal's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: SpiderEngine
var board: Control
var info_label: Label
var suits_btn: Button
var win_dialog: ColorRect
var started := false  # a deal is on (not just the one behind Home)
var suit_choice: int = 1
var flash_col: int = -1
var flash_timer: Timer

func _ready() -> void:
	preload("res://scripts/games/spider/spider_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = SpiderEngine.new()
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
	root.add_theme_constant_override("separation", 8)
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
	title.text = tr("🕷️ Spider")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_start_new_game)
	bar.add_child(new_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 20)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 30)
	cm.add_child(controls)
	root.add_child(cm)
	var undo_btn := Button.new()
	undo_btn.text = tr("↶ Undo")
	undo_btn.custom_minimum_size = Vector2(200, 68)
	undo_btn.add_theme_font_size_override("font_size", 26)
	undo_btn.pressed.connect(_on_undo)
	controls.add_child(undo_btn)
	suits_btn = Button.new()
	suits_btn.custom_minimum_size = Vector2(260, 68)
	suits_btn.add_theme_font_size_override("font_size", 26)
	suits_btn.pressed.connect(_cycle_suits)
	controls.add_child(suits_btn)

	flash_timer = Timer.new()
	flash_timer.one_shot = true
	flash_timer.wait_time = 0.25
	flash_timer.timeout.connect(_clear_flash)
	add_child(flash_timer)

	win_dialog = UI.build_dialog(tr("You Win!"), [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/spider/spider_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _cycle_suits() -> void:
	suit_choice = {1: 2, 2: 4, 4: 1}[suit_choice]
	_start_new_game()

func _start_new_game() -> void:
	started = true
	result_recorded = false
	if info:
		info.start_clock()
	engine.new_game(suit_choice)
	_sfx("card_shuffle")
	win_dialog.visible = false
	_refresh()

func _on_undo() -> void:
	engine.undo()
	_refresh()

func _refresh() -> void:
	suits_btn.text = tr("Suits: %d (new game)") % suit_choice
	info_label.text = tr("Moves: %d   Runs: %d/8   Deals left: %d") % [engine.moves, engine.completed, engine.stock.size() / 10]
	board.queue_redraw()

func _clear_flash() -> void:
	flash_col = -1
	board.queue_redraw()

# ---------- geometry ----------

func _card_size() -> Vector2:
	var w: float = floor((board.size.x - 16.0) / 10.0) - 4.0
	return Vector2(w, floor(w * 1.4))

func _col_x(c: int) -> float:
	var cw: float = _card_size().x + 4.0
	return (board.size.x - cw * 10.0) / 2.0 + c * cw + 2.0

func _tableau_top() -> float:
	return _card_size().y + 24.0

## y offsets for each card in column c, squeezed to fit the board.
func _offsets(c: int) -> Array:
	var cs := _card_size()
	var n: int = engine.cols[c].size()
	var dn: int = engine.down[c]
	var gap_down := cs.y * 0.12
	var gap_up := cs.y * 0.3
	var avail: float = board.size.y - _tableau_top() - cs.y - 8.0
	var need: float = dn * gap_down + max(0, n - dn - 1) * gap_up
	var scale: float = min(1.0, avail / need) if need > 0 else 1.0
	var out: Array = []
	var y := _tableau_top()
	for k in n:
		out.append(y)
		y += (gap_down if k < dn else gap_up) * scale
	return out

func _draw_board() -> void:
	if engine.cols.is_empty():
		return
	var cs := _card_size()
	# stock (tap to deal) and finished runs
	var stock_rect := Rect2(Vector2(_col_x(0), 6), cs)
	if engine.stock.is_empty():
		Cards.draw_card(board, stock_rect, -1)
	else:
		for k in min(engine.stock.size() / 10, 5):
			Cards.draw_card(board, Rect2(stock_rect.position + Vector2(k * 6, 0), cs), 0, false)
	for k in engine.completed:
		Cards.draw_card(board, Rect2(Vector2(_col_x(9) - k * cs.x * 0.35, 6), cs), 12 + 13 * (k % engine.suits), true)
	for c in 10:
		var col: Array = engine.cols[c]
		var x := _col_x(c)
		if col.is_empty():
			Cards.draw_card(board, Rect2(Vector2(x, _tableau_top()), cs), -1, true, c == flash_col)
			continue
		var ys := _offsets(c)
		for k in col.size():
			Cards.draw_card(board, Rect2(Vector2(x, ys[k]), cs), col[k], k >= engine.down[c], c == flash_col and k == col.size() - 1)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if win_dialog.visible:
		return
	var cs := _card_size()
	var pos: Vector2 = event.position
	if pos.y < _tableau_top() - 10.0:
		if pos.x < _col_x(0) + cs.x + 40.0:
			if engine.deal():
				_sfx("card_deal")
				_after_change()
			elif not engine.stock.is_empty():
				info_label.text = tr("Fill every empty column before dealing.")
		return
	var c := clampi(int((pos.x - _col_x(0)) / (cs.x + 4.0)), 0, 9)
	var col: Array = engine.cols[c]
	if col.is_empty():
		return
	var ys := _offsets(c)
	var k := -1
	for i in range(col.size() - 1, -1, -1):
		if pos.y >= ys[i]:
			k = i
			break
	if k < 0 or pos.y > ys[col.size() - 1] + cs.y:
		return
	var start := engine.run_start(c)
	if k < start:
		k = start   # tapping a buried card of the run moves the whole run
		if k < 0:
			return
	var to := engine.best_target(c, k)
	if to >= 0 and engine.move(c, k, to):
		_sfx("card_place")
		_after_change()
	else:
		flash_col = c
		flash_timer.start()
		board.queue_redraw()

func _after_change() -> void:
	_refresh()
	if engine.is_won():
		SaveUtil.delete(SAVE_PATH)
		win_dialog.get_meta("message_label").text = tr("Cleared in %d moves!") % engine.moves
		if info and not result_recorded:
			result_recorded = true
			var suits: String = {1: "1 suit", 2: "2 suits", 4: "4 suits"}.get(engine.suits, "%d suits" % engine.suits)
			info.add("Games won")
			info.celebrate("You win!")
			info.add("Games won (%s)" % suits)
			var secs: float = info.stop_clock()
			var fast: bool = info.low("Best time (%s)" % suits, secs)
			win_dialog.get_meta("message_label").text += "\n" + tr("Time: %d:%02d") % [int(secs) / 60, int(secs) % 60]
			if fast:
				win_dialog.get_meta("message_label").text += "  ·  " + tr("New best!")
		win_dialog.visible = true

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/spider/spider_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/spider/spider_help.gd"),
		"info": info,
		"accent": HomeKit.PURPLE,
		"subtitle": "Build King-to-Ace runs in one suit to clear them away.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "1 suit", "sub": "Easy", "row": "s", "color": HomeKit.LIME, "action": _new_suits.bind(1)},
			{"text": "2 suits", "sub": "Medium", "row": "s", "color": HomeKit.CYAN, "action": _new_suits.bind(2)},
			{"text": "4 suits", "sub": "Hard", "row": "s", "color": HomeKit.PINK, "action": _new_suits.bind(4)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): var d = SaveUtil.read(SAVE_PATH); return "" if d == null else tr("Suits: %d") % int(d.suits),
		"restart": _start_new_game,
		"board": "Games won",
		"board_note": "Games won, any number of suits.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y * 0.42, 70.0)
	var w := h * 0.68
	var ctr := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	for i in 5:
		Cards.draw_card(c, Rect2(ctr + Vector2(-w / 2.0, -h * 1.15 + i * h * 0.3), Vector2(w, h)), 12 - i)
	# a neon spider beside the run
	var s := ctr + Vector2(w * 1.6, -h * 0.2)
	HomeKit.glow_circle(c, s, h * 0.16, HomeKit.PURPLE, 2.0, 0.4)
	for k in 4:
		for side in [-1, 1]:
			var a := Vector2(side * h * 0.14, (k - 1.5) * h * 0.08)
			HomeKit.glow_polyline(c, PackedVector2Array([s + a, s + a + Vector2(side * h * 0.22, -h * 0.1), s + a + Vector2(side * h * 0.32, h * 0.12)]), HomeKit.PURPLE, 1.5)

func _new_suits(n: int) -> void:
	suit_choice = n
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not started or win_dialog.visible or engine.is_won():
		return
	SaveUtil.write(SAVE_PATH, {"cols": engine.cols, "down": engine.down, "stock": engine.stock, "completed": engine.completed,
		"moves": engine.moves, "suits": engine.suits})

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
	suit_choice = int(d.get("suits", 1))
	_start_new_game()
	engine.cols = []
	for col in d.cols:
		engine.cols.append(_ints(col))
	engine.down = _ints(d.down)
	engine.stock = _ints(d.stock)
	engine.completed = int(d.completed)
	engine.moves = int(d.moves)
	engine.suits = suit_choice
	engine.history = []
	_refresh()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
