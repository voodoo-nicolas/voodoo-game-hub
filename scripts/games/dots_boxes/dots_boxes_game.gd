extends Control

const DotsBoxesEngine = preload("res://scripts/games/dots_boxes/dots_boxes_engine.gd")
const HomeKit = preload("res://scripts/games/dots_boxes/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://dots_boxes_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"

const COLOR_P1 := HomeKit.CYAN   # "Blue"
const COLOR_P2 := Color("ff3b6b")  # "Red"
const COLOR_DOT := Color(0.92, 0.92, 0.95)
const COLOR_EDGE_HIDDEN := Color(1, 1, 1, 0)
const COLOR_HOVER := Color(1, 1, 1, 0.35)
const COLOR_SELECTED := Color(1, 0.85, 0.2, 0.95)
const COLOR_BOX_FILL_ALPHA := 0.5
const BOARD_PADDING := 10.0
const AI_PLAYER := 2
const AI_MOVE_DELAY := 0.7

const SIZE_OPTIONS := [
	{"label": "5 × 5", "rows": 5, "cols": 5},
	{"label": "7 × 7", "rows": 7, "cols": 7},
	{"label": "10 × 10", "rows": 10, "cols": 10},
]

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var rows: int = 5
var cols: int = 5
var game_active: bool = false
var vs_computer: bool = false
var pending_vs_computer: bool = false
var ai_thinking: bool = false
## Bumped every time an AI move is scheduled or a game starts, so a delayed
## AI move that belongs to an earlier request (paused and resumed, or a new
## game started meanwhile) knows it's stale and does nothing.
var ai_request: int = 0
var touch_mode: bool = false
var selected_edge: Variant = null  # {"o","r","c"} or null

var size_screen: Control
var game_screen: Control
var board_slot: CenterContainer
var board_wrap: Control

var mode_2p_tab: Button
var mode_cpu_tab: Button

var status_label: Label
var score_p1_label: Label
var score_p2_label: Label
var confirm_btn: Button
var pause_dialog: Control
var win_dialog: Control
var win_label: Label

## The most recently drawn line ({"o","r","c"}) glows so the other player
## can see what just changed.
var last_edge: Variant = null
var glow_rect: ColorRect
var cell_px: float = 0.0
var line_px: float = 0.0
var chime: AudioStreamPlayer
var chime_stream: AudioStreamWAV

var h_lines_view: Array = []
var v_lines_view: Array = []
var box_panels: Array = []  # [r][c] ColorRect

## Online play (null on apps without it). Host is Blue (player 1) and picks
## the board size; guest is Red. my_player == 0 means same-phone play.
var online: Control = null
var my_player: int = 0
var online_btn: Button
var size_subtitle: Label
var size_buttons: Array = []
var mode_row: HBoxContainer
var home  # HomeKit

func _ready() -> void:
	preload("res://scripts/games/dots_boxes/dots_boxes_i18n.gd").install(self)
	Orientation.lock_portrait()
	touch_mode = DisplayServer.is_touchscreen_available()
	engine = DotsBoxesEngine.new()
	_build_ui()
	# Home is on top; the size screen behind it is only used by online games
	# (the host picks the board there).
	size_screen.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI construction ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	_build_size_screen()
	_build_game_screen()
	_build_pause_dialog()
	_build_win_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("dots_boxes", tr("Dots and Boxes"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_on_remote_new_game)
		online.status_changed.connect(_on_online_status)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/dots_boxes/dots_boxes_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _build_home() -> void:
	var modes: Array = []
	for vs_cpu in [true, false]:
		for i in SIZE_OPTIONS.size():
			var opt: Dictionary = SIZE_OPTIONS[i]
			modes.append({"text": opt.label, "row": "cpu" if vs_cpu else "2p", "multi": not vs_cpu,
				"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i] if vs_cpu else HomeKit.MAGENTA,
				"action": _new_local.bind(vs_cpu, opt.rows, opt.cols)})
	if online:
		modes.append({"text": "🌐 Online", "sub": "Play a friend on another phone", "multi": true,
			"color": HomeKit.PURPLE, "action": online.open_lobby})
	home = HomeKit.new({
		"help": preload("res://scripts/games/dots_boxes/dots_boxes_help.gd"),
		"info": info,
		"accent": COLOR_P1,
		"solo_heading": "vs Computer · board size",
		"multi_heading": "2 Players on one phone · board size",
		"subtitle": "Draw lines, close boxes, take the most.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart_same,
		"board": "Wins",
		"board_note": "Games won against the computer.",
		"online": online,
	})
	add_child(home)

func _draw_home_logo(c: Control) -> void:
	var n := 3
	var k := minf(c.size.y / (n + 0.6), 52.0)
	var o := Vector2((c.size.x - k * n) / 2.0, (c.size.y - k * n) / 2.0)
	c.draw_rect(Rect2(o, Vector2(k, k)), Color(COLOR_P1, 0.3))
	c.draw_rect(Rect2(o + Vector2(k * 2, k), Vector2(k, k)), Color(COLOR_P2, 0.3))
	var lines := [[0, 0, 1, 0, COLOR_P1], [0, 0, 0, 1, COLOR_P2], [1, 0, 1, 1, COLOR_P1], [0, 1, 1, 1, COLOR_P2],
		[2, 1, 3, 1, COLOR_P2], [3, 1, 3, 2, COLOR_P1], [2, 2, 3, 2, COLOR_P2], [2, 1, 2, 2, COLOR_P2],
		[1, 2, 1, 3, COLOR_P1], [1, 1, 2, 1, COLOR_P1]]
	for l in lines:
		HomeKit.glow_line(c, o + Vector2(l[0], l[1]) * k, o + Vector2(l[2], l[3]) * k, l[4], 3.0)
	for y in n + 1:
		for x in n + 1:
			HomeKit.glow_circle(c, o + Vector2(x, y) * k, 4.0, Color.WHITE, 1.5, 1.0)

func _new_local(vs_cpu: bool, p_rows: int, p_cols: int) -> void:
	pending_vs_computer = vs_cpu
	SaveUtil.delete(SAVE_PATH)
	_start_new_game(p_rows, p_cols)

func _restart_same() -> void:
	pending_vs_computer = vs_computer
	_start_new_game(rows, cols)

func _resume_text() -> String:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return ""
	var who := tr("vs Computer") if bool(data.get("vs_computer", false)) else tr("2 Players")
	return "%s  %d × %d" % [who, int(data.get("rows", 5)), int(data.get("cols", 5))]

func _go_home() -> void:
	home.go_home()

func _build_size_screen() -> void:
	size_screen = Control.new()
	size_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(size_screen)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	size_screen.add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var hub_btn := Button.new()
	hub_btn.text = tr("🏠 Home")
	hub_btn.custom_minimum_size = Vector2(0, 64)
	hub_btn.pressed.connect(_go_home)
	top_margin.add_child(hub_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = tr("Dots and Boxes")
	title.add_theme_font_size_override("font_size", 39)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	mode_row = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	box.add_child(mode_row)

	mode_2p_tab = Button.new()
	mode_2p_tab.text = tr("2 Players")
	mode_2p_tab.custom_minimum_size = Vector2(0, 44)
	mode_2p_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_2p_tab.focus_mode = Control.FOCUS_NONE
	mode_2p_tab.pressed.connect(func(): _set_pending_mode(false))
	mode_row.add_child(mode_2p_tab)

	mode_cpu_tab = Button.new()
	mode_cpu_tab.text = tr("vs Computer")
	mode_cpu_tab.custom_minimum_size = Vector2(0, 44)
	mode_cpu_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_cpu_tab.focus_mode = Control.FOCUS_NONE
	mode_cpu_tab.pressed.connect(func(): _set_pending_mode(true))
	mode_row.add_child(mode_cpu_tab)

	var subtitle := Label.new()
	size_subtitle = subtitle
	subtitle.text = tr("Choose a board size")
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	for opt in SIZE_OPTIONS:
		var btn := Button.new()
		btn.text = opt.label
		btn.custom_minimum_size = Vector2(300, 76)
		btn.add_theme_font_size_override("font_size", 30)
		btn.pressed.connect(_start_new_game.bind(opt.rows, opt.cols))
		box.add_child(btn)
		size_buttons.append(btn)

	mode_row.visible = false  # chosen on the Home screen now
	_set_pending_mode(false)

func _set_pending_mode(is_cpu: bool) -> void:
	pending_vs_computer = is_cpu
	_style_mode_tab(mode_2p_tab, not is_cpu)
	_style_mode_tab(mode_cpu_tab, is_cpu)

func _style_mode_tab(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.45, 0.28) if active else Color(0.16, 0.16, 0.2)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.15, 1.0, 0.55) if active else Color(0.35, 0.35, 0.4)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1) if active else Color(0.65, 0.65, 0.7))

func _build_game_screen() -> void:
	game_screen = Control.new()
	game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_screen.visible = false
	add_child(game_screen)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	game_screen.add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	top_margin.add_child(top_bar)

	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(func(): _start_new_game(rows, cols))
	top_bar.add_child(restart_btn)

	var title := Label.new()
	title.text = tr("Dots and Boxes")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0))
	title.add_theme_color_override("font_outline_color", Color(COLOR_P1, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	top_bar.add_child(spacer)

	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 40)
	root.add_child(score_row)

	score_p1_label = Label.new()
	score_p1_label.add_theme_font_size_override("font_size", 30)
	score_p1_label.add_theme_color_override("font_color", _c1())
	score_row.add_child(score_p1_label)

	score_p2_label = Label.new()
	score_p2_label.add_theme_font_size_override("font_size", 30)
	score_p2_label.add_theme_color_override("font_color", _c2())
	score_row.add_child(score_p2_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 36)
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	status_label.add_theme_constant_override("outline_size", 6)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	# Board and Confirm sit together in the middle of the free space, so the
	# button is right under the line being confirmed.
	var top_space := Control.new()
	top_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(top_space)

	board_slot = CenterContainer.new()
	root.add_child(board_slot)

	confirm_btn = Button.new()
	confirm_btn.text = tr("Confirm Line")
	confirm_btn.custom_minimum_size = Vector2(0, 72)
	confirm_btn.add_theme_font_size_override("font_size", 30)
	confirm_btn.disabled = true
	confirm_btn.visible = touch_mode
	confirm_btn.pressed.connect(_on_confirm_pressed)
	var confirm_margin := MarginContainer.new()
	confirm_margin.add_theme_constant_override("margin_left", 60)
	confirm_margin.add_theme_constant_override("margin_right", 60)
	confirm_margin.add_child(confirm_btn)
	root.add_child(confirm_margin)

	var bottom_space := Control.new()
	bottom_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(bottom_space)

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
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("Paused")
	title.add_theme_font_size_override("font_size", 33)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = tr("Resume")
	resume_btn.custom_minimum_size = Vector2(200, 48)
	resume_btn.pressed.connect(func():
		pause_dialog.visible = false
		_maybe_ai_move()
	)
	box.add_child(resume_btn)

	var new_game_btn := Button.new()
	new_game_btn.text = tr("New Game")
	new_game_btn.custom_minimum_size = Vector2(200, 44)
	new_game_btn.pressed.connect(func():
		pause_dialog.visible = false
		if _is_online():
			_start_new_game(rows, cols)  # host restarts; guest asks the host to
			return
		game_active = false
		SaveUtil.delete(SAVE_PATH)
		game_screen.visible = false
		_show_size_screen()
	)
	box.add_child(new_game_btn)

	var exit_btn := Button.new()
	exit_btn.text = tr("Exit to Hub")
	exit_btn.custom_minimum_size = Vector2(200, 44)
	exit_btn.pressed.connect(func():
		_save_game()
		get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
	)
	box.add_child(exit_btn)

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
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	win_label = Label.new()
	win_label.add_theme_font_size_override("font_size", 28)
	win_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	win_label.custom_minimum_size = Vector2(220, 0)
	box.add_child(win_label)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again (Same Setup)")
	again_btn.custom_minimum_size = Vector2(320, 64)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
		_start_new_game(rows, cols)
	)
	box.add_child(again_btn)

	var new_size_btn := Button.new()
	new_size_btn.text = tr("🏠 Dots and Boxes Home")
	new_size_btn.custom_minimum_size = Vector2(320, 64)
	new_size_btn.pressed.connect(_go_home)
	box.add_child(new_size_btn)



# ---------- game flow ----------

func _show_size_screen() -> void:
	size_screen.visible = true
	game_screen.visible = false

func _on_pause_pressed() -> void:
	home.pause()

func _player_label(player: int) -> String:
	if _is_online():
		# Player names from the lobby (apps before v0.22: You / Friend).
		if online.has_method("my_name"):
			return online.my_name() if player == my_player else online.opponent_name()
		return tr("You") if player == my_player else tr("Friend")
	if player == 1:
		return tr("Blue")
	return tr("Computer") if vs_computer else tr("Red")

func _is_online() -> bool:
	return online != null and online.is_online()

func _start_new_game(p_rows: int, p_cols: int) -> void:
	if _is_online() and not online.is_host():
		online.new_game()  # the host decides; it will push the new board
		return
	rows = p_rows
	cols = p_cols
	vs_computer = pending_vs_computer
	engine.reset(rows, cols)
	game_active = true
	selected_edge = null
	last_edge = null
	ai_thinking = false
	ai_request += 1
	size_screen.visible = false
	game_screen.visible = true
	win_dialog.visible = false
	pause_dialog.visible = false
	_build_board()
	_render()
	if _is_online():
		online.push_state()

func _on_edge_pressed(orientation: String, r: int, c: int) -> void:
	if not game_active or pause_dialog.visible:
		return
	if vs_computer and engine.current_player == AI_PLAYER:
		return
	if _is_online() and not online.can_act(engine.current_player == my_player):
		return
	var taken: bool = engine.is_h_taken(r, c) if orientation == "h" else engine.is_v_taken(r, c)
	if taken:
		return
	if touch_mode:
		selected_edge = {"o": orientation, "r": r, "c": c}
		_render()
	else:
		_commit_edge(orientation, r, c)

func _on_confirm_pressed() -> void:
	if selected_edge == null:
		return
	var o: String = selected_edge.o
	var r: int = selected_edge.r
	var c: int = selected_edge.c
	selected_edge = null
	_commit_edge(o, r, c)

func _commit_edge(orientation: String, r: int, c: int) -> void:
	var before: int = engine.current_player
	var res: Dictionary = engine.play_line(orientation, r, c)
	if not res.valid:
		return
	_after_line(orientation, r, c, before)
	if _is_online():
		online.send_move({"o": orientation, "r": r, "c": c})
	_render()
	if engine.game_over:
		_show_result()
		return
	_maybe_ai_move()

func _maybe_ai_move() -> void:
	if not game_active or pause_dialog.visible or not vs_computer or engine.current_player != AI_PLAYER:
		return
	ai_request += 1
	ai_thinking = true
	_render()
	# A tween owned by this scene, not an await on a SceneTree timer: it dies
	# with the scene if the player leaves during the delay.
	create_tween().tween_callback(_play_ai_move.bind(ai_request)).set_delay(AI_MOVE_DELAY)

func _play_ai_move(request: int) -> void:
	if request != ai_request:
		return  # superseded by a newer request or a new game
	ai_thinking = false
	if not game_active or pause_dialog.visible or engine.current_player != AI_PLAYER:
		_render()
		return
	var m: Dictionary = engine.pick_ai_move()
	var before: int = engine.current_player
	var res: Dictionary = engine.play_line(m.o, m.r, m.c)
	if not res.valid:
		return
	_after_line(m.o, m.r, m.c, before)
	_render()
	if engine.game_over:
		_show_result()
		return
	_maybe_ai_move()

## Marks the line as the latest, and chimes when the turn passes to a player
## at this phone: the other side in pass-and-play, never the computer, and
## online only when it becomes my turn.
func _after_line(o: String, r: int, c: int, player_before: int) -> void:
	last_edge = {"o": o, "r": r, "c": c}
	# Same player again = they closed a box.
	_sfx("merge" if engine.current_player == player_before or engine.game_over else "place")
	if engine.game_over or engine.current_player == player_before:
		return
	var now: int = engine.current_player
	if vs_computer and now == AI_PLAYER:
		return
	if _is_online() and now != my_player:
		return
	_play_chime()

func _play_chime() -> void:
	# Through the app's sound library when it has one (v0.23+), so the
	# player's Sound settings apply; older apps play it directly.
	var sfx = get_node_or_null("/root/Sfx")
	if sfx and sfx.has_method("play_stream"):
		if chime_stream == null:
			chime_stream = _make_chime()
		sfx.play_stream(chime_stream, -6.0, 1.0, "alerts")
		return
	if chime == null:
		chime = AudioStreamPlayer.new()
		chime.stream = _make_chime()
		chime.volume_db = -6.0
		add_child(chime)
	chime.play()

## A soft two-note "ding-dong" built in code (the app ships no sound files).
static func _make_chime() -> AudioStreamWAV:
	var rate := 22050
	var notes := [[880.0, 0.0, 0.22], [1318.5, 0.12, 0.35]]  # [Hz, start s, length s]
	var total := int(rate * 0.5)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / rate
		var v := 0.0
		for n in notes:
			var lt: float = t - n[1]
			if lt >= 0.0 and lt < n[2]:
				var env: float = minf(lt / 0.01, 1.0) * exp(-lt * 9.0)
				v += sin(TAU * n[0] * lt) * env * 0.35
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _on_edge_mouse_entered(orientation: String, r: int, c: int, line: ColorRect) -> void:
	if touch_mode or not game_active:
		return
	if vs_computer and engine.current_player == AI_PLAYER:
		return
	if _edge_owner(orientation, r, c) == 0:
		line.color = COLOR_HOVER

func _on_edge_mouse_exited(orientation: String, r: int, c: int, line: ColorRect) -> void:
	if touch_mode:
		return
	line.color = _owner_color(_edge_owner(orientation, r, c))

func _edge_owner(orientation: String, r: int, c: int) -> int:
	return engine.h_lines[r][c] if orientation == "h" else engine.v_lines[r][c]

# ---------- online ----------

func _online_state() -> Dictionary:
	return {
		"in_game": game_screen.visible,
		"rows": rows, "cols": cols,
		"h": engine.h_lines, "v": engine.v_lines, "boxes": engine.box_owner,
		"scores": [engine.scores[1], engine.scores[2]],
		"current": engine.current_player,
		"game_over": engine.game_over, "winner": engine.winner,
		"last": last_edge,
	}

func _on_online_started(p_my_player: int) -> void:
	my_player = p_my_player
	vs_computer = false
	pending_vs_computer = false
	mode_row.visible = false
	home.hide_home()
	game_active = false
	win_dialog.visible = false
	pause_dialog.visible = false
	_show_size_screen()
	_on_online_status()

## Keeps the size screen honest about who's choosing.
func _on_online_status() -> void:
	if not _is_online():
		return
	var host: bool = online.is_host()
	for b in size_buttons:
		b.disabled = not host
	if not online.opponent_here:
		size_subtitle.text = (tr("%s disconnected — waiting...") % online.opponent_name()) if online.has_method("opponent_name") else tr("Friend disconnected — waiting...")
	elif host:
		size_subtitle.text = tr("Choose a board size for both of you")
	else:
		size_subtitle.text = tr("Waiting for your friend to choose a board...")
	if game_screen.visible:
		_render()

func _on_remote_move(p: Dictionary) -> void:
	if not game_active or engine.current_player == my_player:
		return
	var before: int = engine.current_player
	var o := str(p.get("o", ""))
	var r := int(p.get("r", -1))
	var c := int(p.get("c", -1))
	if engine.play_line(o, r, c).valid:
		_after_line(o, r, c, before)
		_render()
		if engine.game_over:
			_show_result()

func _on_remote_new_game() -> void:
	if online.is_host():
		win_dialog.visible = false
		_start_new_game(rows, cols)

func _on_remote_state(st: Dictionary) -> void:
	win_dialog.visible = false
	pause_dialog.visible = false
	if not bool(st.get("in_game", false)):
		game_active = false
		_show_size_screen()
		_on_online_status()
		return
	rows = int(st.get("rows", 5))
	cols = int(st.get("cols", 5))
	engine.reset(rows, cols)
	engine.h_lines = _to_int_grid(st.get("h", []))
	engine.v_lines = _to_int_grid(st.get("v", []))
	engine.box_owner = _to_int_grid(st.get("boxes", []))
	var sc: Array = st.get("scores", [0, 0])
	engine.scores = {1: int(sc[0]), 2: int(sc[1])}
	engine.current_player = int(st.get("current", 1))
	engine.game_over = bool(st.get("game_over", false))
	engine.winner = int(st.get("winner", 0))
	game_active = not engine.game_over
	selected_edge = null
	var last = st.get("last", null)
	last_edge = null
	if typeof(last) == TYPE_DICTIONARY and last.has("o"):
		last_edge = {"o": str(last.o), "r": int(last.r), "c": int(last.c)}
	size_screen.visible = false
	game_screen.visible = true
	_build_board()
	_render()
	if engine.game_over:
		_show_result()

func _show_result() -> void:
	var just_ended := game_active  # a resync of a finished game isn't a new result
	game_active = false
	if not _is_online():  # an online game ending mustn't wipe a paused local one
		SaveUtil.delete(SAVE_PATH)
	var p1 := _player_label(1)
	var p2 := _player_label(2)
	if engine.winner == 0:
		win_label.text = tr("It's a tie!\n%s %d - %s %d") % [p1, engine.scores[1], p2, engine.scores[2]]
	elif _is_online():
		win_label.text = "%s\n%s %d - %s %d" % [online.result_text(engine.winner == my_player), p1, engine.scores[1], p2, engine.scores[2]]
	else:
		var name := _player_label(engine.winner)
		win_label.text = tr("%s wins!\n%s %d - %s %d") % [name, p1, engine.scores[1], p2, engine.scores[2]]
	if info and just_ended:
		if _is_online() or vs_computer:
			var me: int = my_player if _is_online() else 1
			info.result("draw" if engine.winner == 0 else ("win" if engine.winner == me else "loss"), _is_online())
			win_label.text += "\n" + info.summary(["Online wins", "Online losses", "Online draws"] if _is_online() else ["Wins", "Losses", "Draws"])
		else:
			info.add("2-player ties" if engine.winner == 0 else ("Blue wins" if engine.winner == 1 else "Red wins"))
			if not (engine.winner == 0):
				info.celebrate(win_label.text.split("\n")[0])
			win_label.text += "\n" + info.summary(["Blue wins", "Red wins", "2-player ties"])
	win_dialog.visible = true

# ---------- board construction ----------

func _build_board() -> void:
	if board_wrap:
		board_wrap.queue_free()

	var viewport_width: float = get_viewport_rect().size.x
	var board_margin := 12.0
	var max_dim: int = max(rows, cols)
	var cell_size: float = floor((viewport_width - board_margin * 2.0 - BOARD_PADDING * 2.0) / max_dim)
	var board_w: float = cell_size * cols + BOARD_PADDING * 2.0
	var board_h: float = cell_size * rows + BOARD_PADDING * 2.0
	var touch_thickness: float = max(20.0, cell_size * 0.32)
	var line_thickness: float = max(4.0, cell_size * 0.07)
	var dot_size: float = max(8.0, cell_size * 0.14)

	board_wrap = Control.new()
	board_wrap.custom_minimum_size = Vector2(board_w, board_h)
	board_slot.add_child(board_wrap)

	box_panels = []
	for r in range(rows):
		var row: Array = []
		for c in range(cols):
			var panel := ColorRect.new()
			panel.color = COLOR_EDGE_HIDDEN
			panel.position = Vector2(BOARD_PADDING + c * cell_size, BOARD_PADDING + r * cell_size)
			panel.size = Vector2(cell_size, cell_size)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_wrap.add_child(panel)
			row.append(panel)
		box_panels.append(row)

	h_lines_view = []
	for r in range(rows + 1):
		var vrow: Array = []
		for c in range(cols):
			var btn := Button.new()
			btn.flat = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.position = Vector2(BOARD_PADDING + c * cell_size, BOARD_PADDING + r * cell_size - touch_thickness / 2.0)
			btn.size = Vector2(cell_size, touch_thickness)
			_style_edge_button(btn)
			btn.pressed.connect(_on_edge_pressed.bind("h", r, c))
			board_wrap.add_child(btn)

			var line := ColorRect.new()
			line.color = COLOR_EDGE_HIDDEN
			line.position = Vector2(0, (touch_thickness - line_thickness) / 2.0)
			line.size = Vector2(cell_size, line_thickness)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(line)
			btn.mouse_entered.connect(_on_edge_mouse_entered.bind("h", r, c, line))
			btn.mouse_exited.connect(_on_edge_mouse_exited.bind("h", r, c, line))

			vrow.append(line)
		h_lines_view.append(vrow)

	v_lines_view = []
	for r in range(rows):
		var vrow2: Array = []
		for c in range(cols + 1):
			var btn := Button.new()
			btn.flat = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.position = Vector2(BOARD_PADDING + c * cell_size - touch_thickness / 2.0, BOARD_PADDING + r * cell_size)
			btn.size = Vector2(touch_thickness, cell_size)
			_style_edge_button(btn)
			btn.pressed.connect(_on_edge_pressed.bind("v", r, c))
			board_wrap.add_child(btn)

			var line := ColorRect.new()
			line.color = COLOR_EDGE_HIDDEN
			line.position = Vector2((touch_thickness - line_thickness) / 2.0, 0)
			line.size = Vector2(line_thickness, cell_size)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(line)
			btn.mouse_entered.connect(_on_edge_mouse_entered.bind("v", r, c, line))
			btn.mouse_exited.connect(_on_edge_mouse_exited.bind("v", r, c, line))

			vrow2.append(line)
		v_lines_view.append(vrow2)

	cell_px = cell_size
	line_px = line_thickness
	glow_rect = ColorRect.new()
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_rect.visible = false
	board_wrap.add_child(glow_rect)
	board_wrap.move_child(glow_rect, rows * cols)  # above the boxes, under the lines
	var pulse := glow_rect.create_tween().set_loops()
	pulse.tween_property(glow_rect, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow_rect, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

	for r in range(rows + 1):
		for c in range(cols + 1):
			var dot := ColorRect.new()
			dot.color = COLOR_DOT
			dot.position = Vector2(BOARD_PADDING + c * cell_size - dot_size / 2.0, BOARD_PADDING + r * cell_size - dot_size / 2.0)
			dot.size = Vector2(dot_size, dot_size)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_wrap.add_child(dot)

func _style_edge_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, sb)

# ---------- rendering ----------

func _render() -> void:
	for r in range(rows + 1):
		for c in range(cols):
			h_lines_view[r][c].color = _owner_color(engine.h_lines[r][c])
	for r in range(rows):
		for c in range(cols + 1):
			v_lines_view[r][c].color = _owner_color(engine.v_lines[r][c])
	for r in range(rows):
		for c in range(cols):
			var box_owner_val: int = engine.box_owner[r][c]
			if box_owner_val == 0:
				box_panels[r][c].color = COLOR_EDGE_HIDDEN
			else:
				var col: Color = _c1() if box_owner_val == 1 else _c2()
				box_panels[r][c].color = Color(col.r, col.g, col.b, COLOR_BOX_FILL_ALPHA)

	_place_glow()

	if touch_mode and selected_edge != null:
		var sel: Dictionary = selected_edge
		var sel_line: ColorRect = h_lines_view[sel.r][sel.c] if sel.o == "h" else v_lines_view[sel.r][sel.c]
		sel_line.color = COLOR_SELECTED

	score_p1_label.text = "%s: %d" % [_player_label(1), engine.scores[1]]
	score_p2_label.text = "%s: %d" % [_player_label(2), engine.scores[2]]

	if touch_mode:
		confirm_btn.disabled = selected_edge == null

	if not game_active:
		return
	if vs_computer and engine.current_player == AI_PLAYER and ai_thinking:
		status_label.add_theme_color_override("font_color", _c2())
		status_label.text = tr("Computer is thinking...")
	else:
		var turn_color: Color = _c1() if engine.current_player == 1 else _c2()
		status_label.add_theme_color_override("font_color", turn_color)
		if _is_online():
			status_label.text = online.status_text(engine.current_player == my_player, tr("Blue") if engine.current_player == 1 else tr("Red"))
		else:
			status_label.text = tr("%s's turn") % _player_label(engine.current_player)

## A wide, pulsing halo in the drawer's color behind the latest line.
func _place_glow() -> void:
	if glow_rect == null or not is_instance_valid(glow_rect):
		return
	if last_edge == null:
		glow_rect.visible = false
		return
	var e: Dictionary = last_edge
	var line_owner: int = _edge_owner(e.o, e.r, e.c)
	if line_owner == 0:
		glow_rect.visible = false
		return
	var w: float = line_px * 3.5
	var start := Vector2(BOARD_PADDING + e.c * cell_px, BOARD_PADDING + e.r * cell_px)
	if e.o == "h":
		glow_rect.position = start - Vector2(0, w / 2.0)
		glow_rect.size = Vector2(cell_px, w)
	else:
		glow_rect.position = start - Vector2(w / 2.0, 0)
		glow_rect.size = Vector2(w, cell_px)
	var col: Color = _owner_color(line_owner).lightened(0.35)
	glow_rect.color = Color(col.r, col.g, col.b, 0.55)
	glow_rect.visible = true
	var line: ColorRect = h_lines_view[e.r][e.c] if e.o == "h" else v_lines_view[e.r][e.c]
	line.color = _owner_color(line_owner).lightened(0.3)

## Look (STANDARDS §9): "classic" = blue and red pens (default); "voodoo" = the neon
## board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: ColorRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if score_p1_label:
		score_p1_label.add_theme_color_override("font_color", _c1())
		score_p2_label.add_theme_color_override("font_color", _c2())
	if not h_lines_view.is_empty():
		_render()

func _c1() -> Color:
	return HomeKit.CLASSIC.blue.lightened(0.3) if skin == "classic" else COLOR_P1

func _c2() -> Color:
	return HomeKit.CLASSIC.red.lightened(0.15) if skin == "classic" else COLOR_P2

func _is_classic() -> bool:
	return skin == "classic"

func _owner_color(line_owner: int) -> Color:
	if line_owner == 0:
		return COLOR_EDGE_HIDDEN
	return _c1() if line_owner == 1 else _c2()

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or _is_online():
		return  # online games aren't resumable alone
	SaveUtil.write(SAVE_PATH, {
		"rows": rows,
		"cols": cols,
		"vs_computer": vs_computer,
		"h_lines": engine.h_lines,
		"v_lines": engine.v_lines,
		"box_owner": engine.box_owner,
		"current_player": engine.current_player,
		"scores": {"1": engine.scores[1], "2": engine.scores[2]},
	})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		_new_local(false, 5, 5)
		return false
	rows = int(data.rows)
	cols = int(data.cols)
	vs_computer = bool(data.get("vs_computer", false))
	engine.rows = rows
	engine.cols = cols
	engine.h_lines = _to_int_grid(data.h_lines)
	engine.v_lines = _to_int_grid(data.v_lines)
	engine.box_owner = _to_int_grid(data.box_owner)
	engine.current_player = int(data.current_player)
	engine.scores = {1: int(data.scores["1"]), 2: int(data.scores["2"])}
	engine.game_over = false
	engine.winner = 0

	game_active = true
	selected_edge = null
	last_edge = null
	ai_thinking = false
	size_screen.visible = false
	game_screen.visible = true
	win_dialog.visible = false
	pause_dialog.visible = false
	_build_board()
	_render()
	_maybe_ai_move()
	return true

func _to_int_grid(grid: Array) -> Array:
	var out: Array = []
	for row in grid:
		var r: Array = []
		for v in row:
			r.append(int(v))
		out.append(r)
	return out

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
