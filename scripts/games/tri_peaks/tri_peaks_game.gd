extends Control

## Tri-Peaks solitaire: clear three peaks of cards by playing one rank up or
## down onto the waste pile. Long streaks score more.

const TpEngine = preload("res://scripts/games/tri_peaks/tri_peaks_engine.gd")
const Cards = preload("res://scripts/games/tri_peaks/tri_peaks_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/tri_peaks/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/tri_peaks/tri_peaks_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://tri_peaks_save.json"
const CARD_ASPECT := 1.42

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var started := false
var finished := false
var flash: Dictionary = {}  # slot -> seconds of "nope" shake left

var board: Control
var score_label: Label
var info_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/tri_peaks/tri_peaks_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = TpEngine.new()
	_build_ui()
	_deal(true)
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", HomeKit.CYAN.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(HomeKit.CYAN, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.add_theme_color_override("font_color", HomeKit.DIM)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 30)
	root.add_child(bm)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bm.add_child(row)
	var undo := Button.new()
	undo.text = "↶ " + tr("Undo")
	undo.custom_minimum_size = Vector2(200, 64)
	undo.pressed.connect(_undo)
	row.add_child(undo)

	end_dialog = UI.build_dialog("", [
		{"text": tr("New deal"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "One up or one down. Clear the three peaks.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🃏 Classic", "sub": "Ace and King touch", "row": "mode", "action": _new_game.bind(true)},
			{"text": "🎯 Strict", "sub": "No Ace–King wrap", "row": "mode", "color": HomeKit.PINK, "action": _new_game.bind(false)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.975)
	add_child(drawer)

# ---------- game flow ----------

func _new_game(p_wrap: bool) -> void:
	SaveUtil.delete(SAVE_PATH)
	_deal(p_wrap)

func _restart() -> void:
	_deal(engine.wrap)

func _deal(p_wrap: bool) -> void:
	engine.deal(p_wrap, rng)
	started = true
	finished = false
	end_dialog.visible = false
	_sfx("card_shuffle")
	_update()

func _update() -> void:
	score_label.text = str(engine.score)
	info_label.text = tr("Stock: %d   ·   Streak: %d   ·   Cards left: %d") % [engine.stock.size(), engine.streak, engine.remaining()]
	board.queue_redraw()

func _process(delta: float) -> void:
	if flash.is_empty():
		return
	for k in flash.keys():
		flash[k] -= delta
		if flash[k] <= 0.0:
			flash.erase(k)
	board.queue_redraw()

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if finished:
		return
	var g := _geom()
	if g.stock.has_point(event.position):
		if engine.draw():
			_sfx("card_flip")
			_after()
		return
	for i in range(TpEngine.N - 1, -1, -1):
		if engine.gone[i]:
			continue
		if _slot_rect(i, g).has_point(event.position):
			if engine.play(i):
				_sfx("card_place")
				_after()
			elif engine.exposed(i):
				flash[i] = 0.3
				_sfx("invalid")
			return

func _after() -> void:
	_update()
	if engine.won():
		_finish(true)
	elif engine.stuck():
		_finish(false)

func _finish(won: bool) -> void:
	finished = true
	SaveUtil.delete(SAVE_PATH)
	var msg := (tr("All three peaks cleared!") if won else tr("No more moves.")) + "\n" + tr("Score: %d") % engine.score
	if info:
		info.add("Games played")
		if won:
			info.add("Games won")
		info.high("Longest streak", engine.best_streak)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
		elif won:
			info.celebrate(tr("All three peaks cleared!"))
	end_dialog.get_meta("message_label").text = msg
	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_callback(_show_end)

func _show_end() -> void:
	end_dialog.visible = finished

func _undo() -> void:
	if finished:
		return
	if engine.undo():
		_sfx("back")
		_update()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var cw: float = minf((board.size.x - 24.0) / 10.0, (board.size.y - 30.0) / (CARD_ASPECT * 4.2))
	var ch: float = cw * CARD_ASPECT
	var ox: float = (board.size.x - cw * 10.0) / 2.0
	var oy: float = 10.0
	var big := minf(cw * 1.9, 150.0)
	var tab_bottom: float = oy + ch * 2.5
	var pile_y: float = tab_bottom + maxf(20.0, (board.size.y - tab_bottom - big * CARD_ASPECT) / 2.0 - 20.0)
	var stock := Rect2(Vector2(board.size.x / 2.0 - big * 1.25, pile_y), Vector2(big, big * CARD_ASPECT))
	var waste := Rect2(Vector2(board.size.x / 2.0 + big * 0.25, pile_y), Vector2(big, big * CARD_ASPECT))
	return {"cw": cw, "ch": ch, "ox": ox, "oy": oy, "stock": stock, "waste": waste}

func _slot_rect(i: int, g: Dictionary) -> Rect2:
	var s: Array = TpEngine.SLOTS[i]
	var x: float = g.ox + s[1] * g.cw
	var y: float = g.oy + s[0] * g.ch * 0.5
	if flash.has(i):
		x += sin(flash[i] * 60.0) * 4.0
	return Rect2(Vector2(x, y), Vector2(g.cw, g.ch)).grow(-1.5)

func _draw_board() -> void:
	if engine.tableau.is_empty():
		return
	var g := _geom()
	for i in TpEngine.N:
		if engine.gone[i]:
			continue
		var up: bool = engine.exposed(i)
		Cards.draw_card(board, _slot_rect(i, g), engine.tableau[i], up, false, up and not engine.fits(engine.tableau[i]))
	# Stock (face down, with a count) and the waste top.
	var font := ThemeDB.fallback_font
	if engine.stock.is_empty():
		Cards.draw_card(board, g.stock, -1)
	else:
		for k in mini(3, engine.stock.size()):
			Cards.draw_card(board, Rect2(g.stock.position - Vector2(k, k) * 3.0, g.stock.size), 0, false)
	board.draw_string(font, Vector2(g.stock.position.x - 40, g.stock.end.y + 30), tr("Stock: %d") % engine.stock.size(),
		HORIZONTAL_ALIGNMENT_CENTER, g.stock.size.x + 80, 24, HomeKit.DIM)
	Cards.draw_card(board, g.waste, engine.waste[-1], true, true)
	if engine.streak >= 2:
		HomeKit.glow_text(board, Vector2(g.waste.get_center().x, g.waste.end.y + 22), tr("Streak ×%d") % engine.streak, 24, HomeKit.GOLD)

func _draw_home_logo(c: Control) -> void:
	var w := minf(c.size.y * 0.32, 44.0)
	var h := w * CARD_ASPECT
	var mid := Vector2(c.size.x / 2.0, c.size.y / 2.0 - h * 0.5)
	for peak in [-1, 0, 1]:
		var top := mid + Vector2(peak * w * 2.4, 0)
		HomeKit.glow_polyline(c, PackedVector2Array([top + Vector2(-w * 1.2, h * 1.3), top + Vector2(0, -h * 0.1), top + Vector2(w * 1.2, h * 1.3)]),
			[HomeKit.CYAN, HomeKit.MAGENTA, HomeKit.CYAN][peak + 1], 2.5)
		Cards.draw_card(c, Rect2(top + Vector2(-w / 2.0, 0), Vector2(w, h)), [12, 26, 39][peak + 1], true)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or finished:
		return
	SaveUtil.write(SAVE_PATH, {"tableau": engine.tableau, "gone": engine.gone, "stock": engine.stock, "waste": engine.waste,
		"wrap": engine.wrap, "score": engine.score, "streak": engine.streak, "best": engine.best_streak, "history": engine.history})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Score: %d") % int(d.get("score", 0))

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or d.get("tableau", []).size() != TpEngine.N:
		_deal(true)
		return
	_deal(bool(d.get("wrap", true)))
	engine.tableau = _ints(d.tableau)
	engine.gone = []
	for v in d.get("gone", []):
		engine.gone.append(bool(v))
	engine.stock = _ints(d.get("stock", []))
	engine.waste = _ints(d.get("waste", []))
	engine.score = int(d.get("score", 0))
	engine.streak = int(d.get("streak", 0))
	engine.best_streak = int(d.get("best", 0))
	engine.history = []
	for h in d.get("history", []):
		var e: Array = [str(h[0])]
		for k in range(1, h.size()):
			e.append(int(h[k]))
		engine.history.append(e)
	if engine.waste.is_empty() or engine.gone.size() != TpEngine.N:
		_deal(true)
		return
	_update()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
