extends Control

const MemoryEngine = preload("res://scripts/games/memory/memory_engine.gd")
const HomeKit = preload("res://scripts/games/memory/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
## Not preloaded either: apps older than v0.14 don't have it (no Online button).
## Online, the host deals the board; each flip is sent as a move. Player 1
## is the host, player 2 the guest; a match earns another go, as on one phone.
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"

const SAVE_PATH := "user://memory_save.json"
const SYMBOLS := ["🍕", "🚀", "🎧", "🐼", "🌵", "⚽", "🎨", "🍩"]
const MISMATCH_DELAY := 0.7
const COLOR_HIDDEN := Color("9b4dff")
const COLOR_FLIPPED := Color("29e6ff")
const COLOR_MATCHED := Color("7dff3a")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var game_active: bool = false
var waiting_for_resolve: bool = false
## Bumped on every new game so a flip-back timer from the previous game
## (restarted while two cards were showing) can't flip cards in this one.
var game_id: int = 0
## Two players on one phone: they take turns; a match earns another go.
var two_player := false
var turn_player: int = 0
var pairs: Array = [0, 0]
## Online play (null on apps without it); my_player 1 = host, 2 = guest.
var online: Control = null
var my_player: int = 0
var result_recorded := false

var status_label: Label
var cell_buttons: Array = []  # 16 Buttons
var pause_dialog: Control
var win_dialog: Control
var win_label: Label

func _ready() -> void:
	preload("res://scripts/games/memory/memory_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MemoryEngine.new()
	_build_ui()
	_start_new_game()  # behind the Home screen

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
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
	title.text = tr("Memory")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.CYAN.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.CYAN, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 32)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)

	var viewport_width: float = get_viewport_rect().size.x
	var outer_margin := 20.0
	var separation := 8
	var cell_size: float = floor((viewport_width - outer_margin * 2.0 - separation * 3.0) / 4.0)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	box.add_child(grid)

	for i in range(16):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		cell.add_theme_font_size_override("font_size", int(cell_size * 0.45))
		cell.flat = false
		cell.focus_mode = Control.FOCUS_NONE
		_style_cell(cell, COLOR_HIDDEN)
		cell.set_meta("sfx", "")  # a flip plays its own sound
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(cell)
		cell_buttons.append(cell)

	_build_pause_dialog()
	_build_win_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("memory", tr(TITLE_FOR_HOME), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_on_remote_new_game)
		online.status_changed.connect(_render)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/memory/memory_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _style_cell(cell: Button, color: Color) -> void:
	var sb := HomeKit.neon_box(color, "normal")
	sb.bg_color = Color(color, 0.12 if color == COLOR_HIDDEN else 0.24)
	sb.set_border_width_all(3)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		cell.add_theme_stylebox_override(state, sb)

func _build_pause_dialog() -> void:
	pause_dialog = Ui.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": Callable()},
		{"text": tr("Restart"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	])
	add_child(pause_dialog)

func _build_win_dialog() -> void:
	win_dialog = Ui.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	win_label = win_dialog.get_meta("message_label")

func _start_new_game() -> void:
	if _is_online():
		online.new_game()
		if not online.is_host():
			return  # the host deals; its new board arrives as a sync
	_reset_game()
	if _is_online():
		online.push_state()

func _reset_game() -> void:
	engine.reset()
	game_id += 1
	result_recorded = false
	turn_player = 0
	pairs = [0, 0]
	game_active = true
	waiting_for_resolve = false
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()

func _on_cell_pressed(i: int) -> void:
	if not game_active or waiting_for_resolve:
		return
	if _is_online() and not online.can_act(turn_player + 1 == my_player):
		return
	if _flip(i) and _is_online():
		online.send_move({"card": i})

## Turns card `i` over; false if that wasn't a legal flip.
func _flip(i: int) -> bool:
	var result: String = engine.flip(i)
	if result != "ignored":
		_sfx("merge" if result == "match" else "card_flip")
	match result:
		"match":
			if two_player or _is_online():
				pairs[turn_player] += 1  # and the same player goes again
			_render()
			if engine.is_over():
				_show_win()
		"mismatch":
			_render()
			waiting_for_resolve = true
			var timer := get_tree().create_timer(MISMATCH_DELAY, false)
			timer.timeout.connect(_on_mismatch_resolved.bind(game_id))
		"first":
			_render()
		"ignored":
			return false
	return true

func _on_mismatch_resolved(for_game: int) -> void:
	if for_game != game_id:
		return
	engine.resolve_mismatch()
	waiting_for_resolve = false
	if two_player or _is_online():
		turn_player = 1 - turn_player
	_render()

func _on_pause_pressed() -> void:
	home.pause()

func _show_win() -> void:
	game_active = false
	if _is_online():  # an online game ending mustn't wipe a paused local one
		var mine: int = pairs[my_player - 1]
		var theirs: int = pairs[2 - my_player]
		win_label.text = (tr("It's a tie! %d - %d") % [mine, theirs]) if mine == theirs \
			else online.result_text(mine > theirs) + "  %d - %d" % [mine, theirs]
		if info and not result_recorded:
			result_recorded = true
			info.result("draw" if mine == theirs else ("win" if mine > theirs else "loss"), true)
		if info:
			win_label.text += "\n" + info.summary(["Online wins", "Online losses", "Online draws"])
		win_dialog.visible = true
		return
	SaveUtil.delete(SAVE_PATH)
	if two_player:
		win_label.text = (tr("It's a tie! %d - %d") % [pairs[0], pairs[1]]) if pairs[0] == pairs[1] \
			else tr("Player %d wins! %d - %d") % [1 if pairs[0] > pairs[1] else 2, pairs[0], pairs[1]]
		if info:
			info.add("2-player games")
			if pairs[0] != pairs[1]:
				info.celebrate(win_label.text)
		win_dialog.visible = true
		return
	win_label.text = tr("Solved in %d moves!") % engine.moves
	if info:
		info.add("Games solved")
		info.celebrate("Solved!")
		if info.low("Fewest moves", engine.moves):
			win_label.text += "\n" + tr("New best!")
	win_dialog.visible = true

func _render() -> void:
	for i in range(16):
		var btn: Button = cell_buttons[i]
		var face_up: bool = engine.matched[i] or engine.flipped.has(i)
		if face_up:
			btn.text = SYMBOLS[engine.deck[i]]
			_style_cell(btn, COLOR_MATCHED if engine.matched[i] else COLOR_FLIPPED)
		else:
			btn.text = ""
			_style_cell(btn, COLOR_HIDDEN)

	if _is_online():
		var mine: bool = turn_player + 1 == my_player
		status_label.text = online.status_text(mine, "%d – %d" % [pairs[my_player - 1], pairs[2 - my_player]])
		status_label.add_theme_color_override("font_color", COLOR_FLIPPED if mine else HomeKit.PINK)
	elif two_player:
		status_label.text = tr("Player %d's turn") % (turn_player + 1) + "   ·   " + "%d – %d" % [pairs[0], pairs[1]]
		status_label.add_theme_color_override("font_color", COLOR_FLIPPED if turn_player == 0 else HomeKit.PINK)
	else:
		status_label.text = tr("Moves: %d") % engine.moves

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or _is_online():
		return
	SaveUtil.write(SAVE_PATH, {
		"deck": engine.deck,
		"matched": engine.matched,
		"moves": engine.moves,
		"two": two_player, "turn": turn_player, "pairs": pairs,
	})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return false
	engine.deck = []
	for v in data.deck:
		engine.deck.append(int(v))
	engine.matched = []
	for v in data.matched:
		engine.matched.append(bool(v))
	engine.moves = int(data.moves)
	engine.flipped = []
	two_player = bool(data.get("two", false))
	turn_player = int(data.get("turn", 0))
	var pp: Array = data.get("pairs", [0, 0])
	pairs = [int(pp[0]), int(pp[1])]

	if engine.is_over():
		return false

	game_active = true
	waiting_for_resolve = false
	_render()
	return true

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/memory/memory_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/memory/memory_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Flip two cards at a time. Find every pair.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🧩  Solo", "sub": "In as few moves as you can", "action": _new_game.bind(false)},
			{"text": "👥  2 Players", "sub": "Take turns; a match earns another go", "multi": true, "action": _new_game.bind(true)},
		] + ([{"text": "🌐 Online", "sub": "Play a friend on another phone", "multi": true,
			"color": HomeKit.PURPLE, "action": online.open_lobby}] if online else []),
		"save_path": SAVE_PATH,
		"resume": _resume_saved,
		"restart": _start_new_game,
		"board": "Games solved",
		"board_note": "Boards cleared on your own.",
		"online": online,
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 2.3, 74.0)
	var o := Vector2(c.size.x / 2.0 - k * 1.5, c.size.y / 2.0 - k)
	var faces := ["", "🚀", "", "🚀", "", ""]
	for i in 6:
		var r := Rect2(o + Vector2(i % 3, int(i / 3)) * k, Vector2(k, k)).grow(-4)
		HomeKit.glow_rect(c, r, HomeKit.LIME if faces[i] != "" else HomeKit.PURPLE, 2.0, 0.12)
		if faces[i] != "":
			HomeKit.glow_text(c, r.get_center(), faces[i], int(k * 0.45), Color.WHITE)

func _new_game(two: bool) -> void:
	two_player = two
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _resume_saved() -> void:
	if not _load_saved_game():
		_start_new_game()

# ---------- online ----------

func _is_online() -> bool:
	return online != null and online.is_online()

## The whole game, including the deck (the host deals it) and any card
## turned over but not yet resolved.
func _online_state() -> Dictionary:
	return {"deck": engine.deck, "matched": engine.matched, "flipped": engine.flipped,
		"moves": engine.moves, "turn": turn_player, "pairs": pairs}

func _on_online_started(p_my_player: int) -> void:
	my_player = p_my_player
	two_player = false
	home.hide_home()
	_reset_game()  # the host's deal arrives right after as a sync

## Either player may ask for a new game; the host deals it.
func _on_remote_new_game() -> void:
	_reset_game()  # the guest's deal is a placeholder until the host's arrives
	if online.is_host():
		online.push_state()

func _on_remote_move(p: Dictionary) -> void:
	if game_active and not waiting_for_resolve and turn_player + 1 != my_player:
		_flip(int(p.get("card", -1)))

func _on_remote_state(st: Dictionary) -> void:
	var deck: Array = []
	for v in st.get("deck", []):
		deck.append(int(v))
	if deck.size() != MemoryEngine.NUM_PAIRS * 2:
		return
	engine.deck = deck
	engine.matched = []
	for v in st.get("matched", []):
		engine.matched.append(bool(v))
	engine.flipped = []
	for v in st.get("flipped", []):
		engine.flipped.append(int(v))
	engine.moves = int(st.get("moves", 0))
	turn_player = int(st.get("turn", 0))
	var pp: Array = st.get("pairs", [0, 0])
	pairs = [int(pp[0]), int(pp[1])]
	game_id += 1  # drop any flip-back timer from before
	waiting_for_resolve = false
	if engine.flipped.size() >= 2:
		# Two cards were showing: let them be seen, then turn them back.
		waiting_for_resolve = true
		get_tree().create_timer(MISMATCH_DELAY, false).timeout.connect(_on_mismatch_resolved.bind(game_id))
	game_active = not engine.is_over()
	win_dialog.visible = false
	_render()
	if engine.is_over():
		_show_win()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
