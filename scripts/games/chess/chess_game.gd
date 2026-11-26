extends Control

const ChessEngine = preload("res://scripts/games/chess/chess_engine.gd")
const HomeKit = preload("res://scripts/games/chess/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
const ChessPieces = preload("res://scripts/games/chess/chess_pieces.gd")
const ChessStyles = preload("res://scripts/games/chess/chess_styles.gd")
const ChessLessons = preload("res://scripts/games/chess/chess_lessons.gd")
const ChessProgress = preload("res://scripts/games/chess/chess_progress.gd")
const CLOUD_SAVE := "res://scripts/common/cloud_save.gd"  # [NEW 2026-11-24] STANDARDS §18; APK-side, load() guarded
var cloud: Node = null
const BoardView = preload("res://scripts/games/chess/chess_board_view.gd")
const ChessArchive = preload("res://scripts/games/chess/chess_archive.gd")
const SoundLib = preload("res://scripts/games/chess/sound_lib.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://chess_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
## The Landing art (owner's), also the play background in the Classic look.
const ART := "res://games/chess/landing_bg.jpg"

const COLOR_SELECTED := HomeKit.GOLD
const COLOR_CHECK := Color("ff3b4f")
## Neon outlines: White's pieces glow cyan, Black's magenta.
const GLOW_WHITE := HomeKit.CYAN
const GLOW_BLACK := HomeKit.MAGENTA
const LEVELS := ["Easy", "Medium", "Hard"]
const CPU_DELAY := 0.35
## Clocks, picked on the setup screens: seconds for each player
## (0 = no limit: the clocks count the time each side has used).
const TIME_CONTROLS := [0, 300, 600, 1800]
const TIME_NAMES := ["No limit", "5 min", "10 min", "30 min"]
## [Phase A 2026-11-25] The clock choices now: [seconds each, seconds added
## after every move]. TIME_CONTROLS above only maps the old saved choice.
const CLOCK_PRESETS := [[0, 0], [60, 0], [120, 1], [180, 0], [180, 2], [300, 0], [300, 3],
	[600, 0], [600, 5], [900, 10], [1800, 0], [3600, 0]]
## Below this many seconds left a clock turns red and ticks.
const LOW_TIME := 10.0
## Pause before Black answers in a mate-in-two lesson, and before a wrong
## lesson move is taken back.
const LESSON_REPLY_DELAY := 0.6
const LESSON_UNDO_DELAY := 0.9

const RESULT_MESSAGES := {
	"checkmate": "Checkmate!",
	"stalemate": "Stalemate — draw",
	"draw_50move": "Draw — 50-move rule",
	"draw_insufficient_material": "Draw — insufficient material",
	"draw_repetition": "Draw — same position 3 times",
	"timeout": "Out of time!",
	"draw_timeout": "Draw — out of time, but no mating material left",
	"resign": "Resigned",
	"draw_agreed": "Draw agreed",
}

## Set before going 🏠 Home from a finished lesson: the Landing then opens
## the 📚 Lessons card straight away.
static var reopen_lessons := false

var info = null  # GameInfo; null on apps without it, so guard every use
var engine
var progress  # ChessProgress
var game_active: bool = false
## A real game began here (not just the board set up under the Landing):
## only then is there anything to save (STANDARDS §6).
var started: bool = false
## "cpu", "local" (two players, one phone), "online", "lesson", "daily".
var mode: String = "local"
var selected: Vector2i = Vector2i(-1, -1)
var dest_map: Dictionary = {}  # Vector2i(dest) -> move dict
var pending_promotion: Dictionary = {}  # {from, to} awaiting a piece choice
var san_moves: Array = []  # the game's moves in notation ("e4", "Nf3"...)
var last_move: Array = []  # [from, to]
## [Phase A 2026-11-25] The game's moves as UCI ("e2e4"), from start_fen
## ("" = the usual start): takebacks, PGN and the replay rebuild from these.
var ucis: Array = []
var start_fen: String = ""
## Seconds added to a clock after each of that side's moves.
var increment: int = 0
## Takebacks in this game (a game with any gets no rating change or points).
var takebacks_used: int = 0
## Online: we offered a draw and wait for the answer.
var draw_offered := false
## A tap on the picked piece unpicks it when the finger lifts (so it can be dragged).
var _deselect_on_release := false
var action_row: HBoxContainer
var takeback_btn: Button
var draw_btn: Button
var resign_btn: Button
var flip_btn: Button
var copy_btn: Button

var board_view  # chess_board_view.gd
var status_label: Label
var title_label: Label
var promotion_dialog: Control
var promotion_buttons: Array = []  # 4 Buttons: Queen, Rook, Bishop, Knight
var result_dialog: Control
var result_label: Label
var result_buttons: VBoxContainer
var home  # HomeKit
## The strips above and below the board: [top, bottom], each
## {"box", "name", "rating", "captured", "clock"}.
var strips: Array = []
var eval_bar: Control
var moves_scroll: ScrollContainer
var moves_label: Label
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
var music_started := false

## Clocks: seconds left for each side (or used, with no limit).
var clock_limit: int = 0
var clocks := {ChessEngine.WHITE: 0.0, ChessEngine.BLACK: 0.0}
var _clock_shown := {}
## The evaluation bar's latest reading (engine.evaluation()).
var evaluation: Dictionary = {"score": 0.0, "mate": 0}
var _eval_key := ""

## Lessons: the lesson (or today's daily lesson) and where the player is in it.
var lesson: Dictionary = {}
var board_i: int = 0
var lesson_moves: int = 0
var stars_left: Array = []  # square names
var hint_used := false
var board_solved := false
var lesson_stage: int = 0  # mate in two: 0 first move, 1 Black answering, 2 the mate
var lesson_points: int = 0  # earned in this run of the lesson
var lesson_busy := false  # a wrong move is about to be taken back, or Black is answering
var lesson_pending: String = ""  # what lesson_timer does: "undo" / "reply"
var lesson_snapshot: Dictionary = {}
var lesson_timer: Timer
var lesson_panel: Control
var lesson_head: Label
var lesson_task: Label
var lesson_feedback: Label
var hint_btn: Button
var retry_btn: Button
var next_btn: Button

func _ready() -> void:
	preload("res://scripts/games/chess/chess_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = ChessEngine.new()
	progress = ChessProgress.new()
	if ResourceLoader.exists(CLOUD_SAVE):
		cloud = load(CLOUD_SAVE).new()
		cloud.setup("chess", ChessProgress.PATH, ChessProgress.score, progress.load_file)
		add_child(cloud)
	_build_ui()
	_reset_board()
	_prepare_music()
	if reopen_lessons:
		reopen_lessons = false
		call_deferred("_open_lessons")

func _exit_tree() -> void:
	if cpu_thread and cpu_thread.is_started():
		cpu_thread.wait_to_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

var _root: VBoxContainer
var _mid: HBoxContainer
var _side: VBoxContainer
var _wide := false

## Wide windows (PC): players, captured pieces and the move list go in a column
## beside the board, which then grows to the full height. Narrow: stacked as before.
func _fit_layout() -> void:
	if _root == null or _mid == null or strips.size() < 2 or moves_scroll == null:
		return
	var vp := get_viewport_rect().size
	var wide := vp.x > vp.y * 1.15
	if wide == _wide:
		return
	_wide = wide
	var s0: Control = strips[0].box
	var s1: Control = strips[1].box
	var mp: Control = moves_scroll.get_parent()
	for n in [s0, s1, mp]:
		n.get_parent().remove_child(n)
	if wide:
		_side.visible = true
		_side.add_child(s0)
		_side.add_child(mp)
		_side.add_child(s1)
		mp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		moves_scroll.custom_minimum_size = Vector2(0, 120)
	else:
		_side.visible = false
		_root.add_child(s0)
		_root.move_child(s0, eval_bar.get_index())
		_root.add_child(s1)
		_root.move_child(s1, _mid.get_index() + 1)
		_root.add_child(mp)
		_root.move_child(mp, s1.get_index() + 1)
		mp.size_flags_vertical = Control.SIZE_FILL
		moves_scroll.custom_minimum_size = Vector2(0, 40)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)
	if ResourceLoader.exists(ART):
		art_bg = TextureRect.new()
		art_bg.texture = load(ART)
		art_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(art_bg)
		art_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var veil := ColorRect.new()
		veil.color = Color(0.02, 0.02, 0.04, 0.72)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_bg.add_child(veil)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	_root = root

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	root.add_child(top_bar)

	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	title_label = Label.new()
	title_label.text = tr("Chess")
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title_label.add_theme_constant_override("outline_size", 6)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	top_bar.add_child(title_label)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	_build_lesson_panel(root)
	strips.append(_build_strip(root))
	eval_bar = EvalBar.new()
	eval_bar.custom_minimum_size = Vector2(0, 14)
	root.add_child(eval_bar)

	board_view = BoardView.new()
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.custom_minimum_size = Vector2(0, 240)
	board_view.square_pressed.connect(_on_square_pressed)
	board_view.square_released.connect(_on_square_released)
	board_view.drag_dropped.connect(_on_drag_dropped)
	# [2026-11-23] board row: on wide windows the info panels move to a column beside the board.
	_mid = HBoxContainer.new()
	_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mid.add_theme_constant_override("separation", 12)
	root.add_child(_mid)
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mid.add_child(board_view)
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(320, 0)
	_side.add_theme_constant_override("separation", 10)
	_side.visible = false
	_mid.add_child(_side)

	strips.append(_build_strip(root))

	moves_scroll = ScrollContainer.new()
	moves_scroll.custom_minimum_size = Vector2(0, 40)  # [2026-11-23] smaller, so the board grows
	moves_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var moves_panel := PanelContainer.new()
	moves_panel.add_theme_stylebox_override("panel", _strip_style())
	moves_panel.add_child(moves_scroll)
	root.add_child(moves_panel)
	moves_label = Label.new()
	moves_label.add_theme_font_size_override("font_size", 22)
	moves_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	moves_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	moves_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_scroll.add_child(moves_label)

	_build_action_row(root)

	get_viewport().size_changed.connect(_fit_layout)
	call_deferred("_fit_layout")

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	status_label.add_theme_constant_override("outline_size", 6)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.timeout.connect(_cpu_start)
	add_child(cpu_timer)
	lesson_timer = Timer.new()
	lesson_timer.one_shot = true
	lesson_timer.timeout.connect(_on_lesson_timer)
	add_child(lesson_timer)

	_build_promotion_dialog()
	_build_result_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("chess", tr("Chess"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_on_remote_new_game)
		online.status_changed.connect(_render)
		add_child(online)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/chess/chess_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())
	_apply_panels()

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
		"accent": HomeKit.GOLD,
		"solo_heading": "vs Computer",
		"subtitle": "Play the computer or a friend, or learn step by step.",
		"art": ART,
		"modes": modes,
		"play": [
			{"text": "📚 Lessons", "sub": "The pieces, the rules, checkmate", "action": _open_lessons, "card": true},
			{"text": "📅 Daily Lesson", "sub": "Three new boards every day", "action": _start_daily},
		],
		"more": [["📜 My Games", HomeKit.BUTTON, _open_archive], ["🛒 Shop", HomeKit.BUTTON, _open_shop]],
		"extra": _add_clock_picker,
		"options": _add_panel_options,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _start_new_game,
		"helps": [{"text": "💡 Hint", "how": "The computer plays your best move for you.", "action": _help_move}],
		"board": "Wins",
		"board_note": "Games won against the computer, at any level.",
		"online": online,
	})
	add_child(home)

# ---------- setup screens and Options ----------

## Setup screens: the clock for the next game.
## [Phase A] 12 presets in rows of 4: "3+2" = 3 minutes each, 2 seconds added per move.
func _add_clock_picker(box: Control) -> void:
	box.add_child(home.section("⏱ Clock"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var group := ButtonGroup.new()
	var current := _clock_choice()
	for i in CLOCK_PRESETS.size():
		var b := HomeKit.neon_button(_clock_name(i), HomeKit.BUTTON, 24, 58)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		home._style_toggle(b, HomeKit.BUTTON)
		b.pressed.connect(_on_clock_pick.bind(i))
		grid.add_child(b)
	box.add_child(grid)
	box.add_child(HomeKit.label(tr("Minutes each + seconds added after every move. Bullet: 1+0, 2+1. Blitz: 3+0 to 5+3. Rapid: 10+0 to 15+10. Classical: 30 and 60. Run out of time and you lose. No limit: the clocks just count. Online games have no limit."), 21, HomeKit.DIM, true))

func _clock_name(i: int) -> String:
	var p: Array = CLOCK_PRESETS[i]
	return tr("No limit") if p[0] == 0 else "%d+%d" % [p[0] / 60, p[1]]

## The picked preset; a choice saved before the presets maps to the same minutes.
func _clock_choice() -> int:
	var i: int = progress.clock_preset()
	if i >= 0 and i < CLOCK_PRESETS.size():
		return i
	var secs: int = TIME_CONTROLS[clampi(progress.clock_index(), 0, TIME_CONTROLS.size() - 1)]
	for k in CLOCK_PRESETS.size():
		if CLOCK_PRESETS[k][0] == secs and CLOCK_PRESETS[k][1] == 0:
			return k
	return 0

func _on_clock_pick(i: int) -> void:
	progress.set_clock_preset(i)

## ⚙ Options → Show: each panel around the board on or off.
func _add_panel_options(body: Control) -> void:
	body.add_child(home.section("Show"))
	for key in ChessProgress.PANELS:
		body.add_child(HomeKit.label(tr(ChessProgress.PANEL_NAMES[key]), 24, HomeKit.WHITE, true))
		body.add_child(home.choice_row(["On", "Off"], 0 if progress.panel_on(key) else 1, _on_panel_pick.bind(key)))
	body.add_child(HomeKit.label(tr("⟲ Takebacks"), 24, HomeKit.WHITE, true))
	body.add_child(home.choice_row(["On", "Off"], 0 if progress.panel_on("takebacks") else 1, _on_panel_pick.bind("takebacks")))
	body.add_child(HomeKit.label(tr("Takebacks work against the computer and on one phone. A game with a takeback doesn't change your rating or earn points."), 21, HomeKit.DIM, true))
	body.add_child(HomeKit.label(tr("The evaluation bar shows who stands better (+ for White, − for Black). It is hidden in online games and lessons."), 21, HomeKit.DIM, true))

func _on_panel_pick(i: int, key: String) -> void:
	progress.set_panel(key, i == 0)
	_apply_panels()

## Shows or hides the panels around the board for the player's choices
## and the kind of game (lessons have their own panel instead).
func _apply_panels() -> void:
	var lessons := _in_lesson()
	var show_players: bool = progress.panel_on("players") and not lessons
	var show_captured: bool = progress.panel_on("captured") and not lessons
	var show_clocks: bool = progress.panel_on("clocks") and not lessons
	for s in strips:
		s.box.visible = show_players or show_captured or show_clocks
		s.name.get_parent().visible = show_players
		s.captured.visible = show_captured
		s.clock.visible = show_clocks
	eval_bar.visible = progress.panel_on("eval") and not lessons and not _is_online()
	moves_scroll.get_parent().visible = progress.panel_on("moves") and not lessons
	lesson_panel.visible = lessons
	if action_row:
		action_row.visible = not lessons
	status_label.visible = not lessons
	board_view.coords = progress.panel_on("coords")
	_update_info()

# ---------- panels around the board ----------

func _strip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.06, 0.72)
	sb.border_color = Color(1, 0.85, 0.55, 0.22)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

## One player's strip: name and rating, the pieces they have captured with
## the material lead, and their clock.
func _build_strip(parent: Control) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _strip_style())
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	who.custom_minimum_size.x = 170  # a clipped name has no width of its own
	row.add_child(who)
	var name_l := HomeKit.label("", 24, Color(0.96, 0.93, 0.86))
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_child(name_l)
	var rating_l := HomeKit.label("", 18, Color(0.78, 0.72, 0.6))
	who.add_child(rating_l)
	var cap := PieceRow.new()
	cap.custom_minimum_size = Vector2(60, 40)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cap)
	var clock_l := HomeKit.label("", 30, Color(0.96, 0.93, 0.86))
	clock_l.custom_minimum_size = Vector2(112, 0)
	clock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var clock_bg := StyleBoxFlat.new()
	clock_bg.bg_color = Color(0, 0, 0, 0.5)
	clock_bg.set_corner_radius_all(8)
	clock_bg.content_margin_left = 8
	clock_bg.content_margin_right = 8
	clock_l.add_theme_stylebox_override("normal", clock_bg)
	row.add_child(clock_l)
	return {"box": panel, "name": name_l, "rating": rating_l, "captured": cap, "clock": clock_l}

## The side shown at the bottom of the board (White unless flipped).
func _bottom_side() -> int:
	return ChessEngine.BLACK if flipped else ChessEngine.WHITE

func _side_name(side: int) -> String:
	var white: bool = side == ChessEngine.WHITE
	if _is_online():
		if not online.has_method("opponent_name"):  # apps before v0.22
			return tr("You") if side == my_color else (tr("White") if white else tr("Black"))
		return online.my_name() if side == my_color else online.opponent_name()
	if mode == "cpu":
		return tr("You") if white else tr("Computer (%s)") % tr(LEVELS[clampi(cpu_level, 0, 2)])
	return tr("White") if white else tr("Black")

func _side_rating(side: int) -> String:
	var mine: bool = (mode == "cpu" and side == ChessEngine.WHITE) or (_is_online() and side == my_color)
	if mine:
		var r: int = progress.rating()
		return "%d · %s" % [r, tr(ChessProgress.rank_name(r))]
	if mode == "cpu":
		return tr("Rating ≈ %d") % ChessProgress.CPU_RATINGS[clampi(cpu_level, 0, 2)]
	return ""

## Names, captured pieces, material, clocks, evaluation and the move list.
func _update_info() -> void:
	if strips.size() < 2 or engine == null or engine.board.size() != 8 or _in_lesson():
		return
	var lead: int = engine.material(ChessEngine.WHITE) - engine.material(ChessEngine.BLACK)
	for i in 2:
		var side: int = -_bottom_side() if i == 0 else _bottom_side()
		var s: Dictionary = strips[i]
		s.name.text = _side_name(side)
		s.rating.text = _side_rating(side)
		var cap: PieceRow = s.captured
		cap.types = engine.lost_pieces(-side)
		cap.white = side == ChessEngine.BLACK  # the pieces it took are the other colour
		cap.style = _piece_style()
		var mine: int = lead if side == ChessEngine.WHITE else -lead
		cap.lead = mine if mine > 0 else 0
		cap.queue_redraw()
	_update_clocks()
	_update_moves()
	_update_eval()

func _update_clocks() -> void:
	if strips.size() < 2:
		return
	for i in 2:
		var side: int = -_bottom_side() if i == 0 else _bottom_side()
		var secs: float = clocks[side]
		var whole := int(ceil(secs)) if clock_limit > 0 else int(secs)
		var key := "%d|%d|%s" % [side, whole, str(engine.current_player == side and game_active)]
		if _clock_shown.get(i, "") == key:
			continue
		_clock_shown[i] = key
		var l: Label = strips[i].clock
		l.text = "%d:%02d" % [whole / 60, whole % 60]
		var running: bool = game_active and engine.current_player == side
		var low: bool = clock_limit > 0 and secs <= LOW_TIME
		l.add_theme_color_override("font_color", COLOR_CHECK if low else (Color(1, 0.95, 0.8) if running else Color(0.6, 0.58, 0.52)))
		var sb: StyleBoxFlat = l.get_theme_stylebox("normal")
		sb.bg_color = Color(1, 0.75, 0.3, 0.22) if running else Color(0, 0, 0, 0.5)

func _update_moves() -> void:
	var parts: PackedStringArray = []
	for i in san_moves.size():
		if i % 2 == 0:
			parts.append("%d." % (i / 2 + 1))
		parts.append(san_moves[i])
	moves_label.text = " ".join(parts) if not parts.is_empty() else tr("Moves appear here.")
	moves_scroll.set_deferred("scroll_vertical", 100000)

func _update_eval() -> void:
	if not eval_bar.visible:
		return
	# Worked out once per position (a tap that only picks a piece changes nothing).
	var key: String = engine.position_key() + str(engine.game_over)
	if key != _eval_key:
		_eval_key = key
		evaluation = engine.evaluation(120)
	eval_bar.score = float(evaluation.get("score", 0.0))
	eval_bar.mate = int(evaluation.get("mate", 0))
	eval_bar.over = int(evaluation.get("over", 99)) if engine.game_over else 99
	eval_bar.flipped = flipped
	eval_bar.queue_redraw()

func _process(delta: float) -> void:
	if not game_active or not started or _in_lesson() or engine.game_over:
		return
	var side: int = engine.current_player
	if clock_limit > 0 and not _is_online():
		var before: float = clocks[side]
		clocks[side] = maxf(0.0, before - delta)
		if clocks[side] <= LOW_TIME and int(ceil(before)) != int(ceil(clocks[side])) and _my_clock(side):
			_sfx("tick")
		if clocks[side] <= 0.0:
			engine.flag_fall(side)
			_render()
			_show_result()
			return
	else:
		clocks[side] += delta
	if strips[0].clock.visible:
		_update_clocks()

## Ticks only for a clock the player on this phone is watching run down.
func _my_clock(side: int) -> bool:
	return mode == "local" or (mode == "cpu" and side == ChessEngine.WHITE)

# ---------- starting games ----------

func _new_vs_cpu(level: int) -> void:
	mode = "cpu"
	cpu_level = level
	SaveUtil.delete(SAVE_PATH)
	_begin()

func _new_two_player() -> void:
	mode = "local"
	cpu_level = -1
	SaveUtil.delete(SAVE_PATH)
	_begin()

## A fresh game in the current mode, with the clock picked on setup.
func _begin(fen: String = "") -> void:
	flipped = false
	var preset: Array = CLOCK_PRESETS[_clock_choice()]
	clock_limit = preset[0]
	increment = preset[1] if clock_limit > 0 else 0
	start_fen = fen
	started = true
	_reset_board()
	_start_music()
	_maybe_cpu()  # a pasted position with Black (the computer) to move

func _vs_cpu() -> bool:
	return mode == "cpu" and cpu_level >= 0 and not _is_online()

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
	# The browser build has no threads (Thread.start() never runs the
	# function): think right here; the level's time budget bounds the pause.
	if OS.has_feature("web"):
		_cpu_think(engine.clone(), cpu_level, rng.randi(), cpu_token)
		return
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
		btn.custom_minimum_size = Vector2(84, 84)
		btn.pressed.connect(_on_promotion_chosen.bind(choice))
		row.add_child(btn)
		# The piece is drawn in the mover's colour, set when the dialog opens.
		var pic := Control.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(pic)
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.draw.connect(_draw_promotion_piece.bind(pic, choice))
		btn.set_meta("piece_type", choice)
		btn.set_meta("pic", pic)
		promotion_buttons.append(btn)

func _draw_promotion_piece(pic: Control, ptype: int) -> void:
	var white: bool = engine.current_player == ChessEngine.WHITE
	var st: Dictionary = _piece_style()
	ChessPieces.draw(pic, ptype, white, Rect2(Vector2(6, 6), pic.size - Vector2(12, 12)), st.get("white" if white else "black", {}))

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
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x - 120.0), 0)
	box.add_child(result_label)

	result_buttons = VBoxContainer.new()
	result_buttons.add_theme_constant_override("separation", 14)
	box.add_child(result_buttons)

## The result card's buttons: [[English text, colour, callable], ...].
func _set_result_buttons(specs: Array) -> void:
	for c in result_buttons.get_children():
		c.queue_free()
	for s in specs:
		var b := HomeKit.neon_button(tr(s[0]), s[1], 26, 70)
		b.custom_minimum_size.x = 320
		b.pressed.connect(s[2])
		result_buttons.add_child(b)

func _on_play_again() -> void:
	result_dialog.visible = false
	_start_new_game()

func _go_home() -> void:
	home.go_home()

# ---------- game flow ----------

func _is_online() -> bool:
	return online != null and online.is_online()

func _in_lesson() -> bool:
	return mode == "lesson" or mode == "daily"

func _start_new_game() -> void:
	if _in_lesson():
		_load_lesson_board(board_i)
		return
	if online:
		online.new_game()
	_reset_board()

func _on_remote_new_game() -> void:
	_reset_board()

func _reset_board() -> void:
	if start_fen != "" and ChessEngine.is_valid_fen(start_fen):
		engine.load_fen(start_fen)
	else:
		start_fen = ""
		engine.reset()
	ucis = []
	takebacks_used = 0
	draw_offered = false
	_deselect_on_release = false
	cpu_token += 1
	cpu_busy = false
	cpu_timer.stop()
	game_active = true
	selected = Vector2i(-1, -1)
	dest_map = {}
	pending_promotion = {}
	san_moves = []
	last_move = []
	board_view.hint = []
	_reset_clocks()
	result_dialog.visible = false
	promotion_dialog.visible = false
	title_label.text = tr("Chess")
	_apply_panels()
	_render()

func _reset_clocks() -> void:
	var start: float = float(clock_limit) if clock_limit > 0 and not _is_online() else 0.0
	clocks = {ChessEngine.WHITE: start, ChessEngine.BLACK: start}
	_clock_shown = {}

func _on_pause_pressed() -> void:
	home.pause()

func _on_square_pressed(r: int, c: int) -> void:
	if not game_active or promotion_dialog.visible or lesson_busy:
		return
	if _is_online() and not online.can_act(engine.current_player == my_color):
		return
	if (_vs_cpu() or _in_lesson()) and engine.current_player != ChessEngine.WHITE:
		return  # the computer is thinking
	var pos := Vector2i(r, c)

	if dest_map.has(pos):
		if engine.is_promotion_move(selected, pos):
			pending_promotion = {"from": selected, "to": pos}
			_show_promotion_dialog()
			return
		_apply_move(selected, pos, ChessEngine.QUEEN)
		return

	if pos == selected:
		_deselect_on_release = true  # unpicked when the finger lifts, unless it drags
		return
	_deselect_on_release = false

	var piece: int = engine.board[r][c]
	if piece != 0 and engine.owner_of(piece) == engine.current_player:
		selected = pos
	else:
		selected = Vector2i(-1, -1)
	_render()

func _show_promotion_dialog() -> void:
	for btn in promotion_buttons:
		btn.get_meta("pic").queue_redraw()
	promotion_dialog.visible = true

func _on_promotion_chosen(piece_type: int) -> void:
	promotion_dialog.visible = false
	_apply_move(pending_promotion.from, pending_promotion.to, piece_type)
	pending_promotion = {}

func _apply_move(from: Vector2i, to: Vector2i, promotion_piece: int) -> void:
	if _in_lesson():
		_lesson_move(from, to, promotion_piece)
		return
	var san: String = engine.san(from, to, promotion_piece)
	var result: Dictionary = engine.move(from, to, promotion_piece)
	if not result.valid:
		return
	san_moves.append(san + engine.san_suffix())
	ucis.append(ChessEngine.uci(from, to, promotion_piece if result.promotes else 0))
	var mover: int = -engine.current_player
	if increment > 0 and clock_limit > 0 and not _is_online() and not result.game_over:
		clocks[mover] += increment
	if _is_online() and engine.current_player != my_color:  # it was our move
		online.send_move({"from": [from.x, from.y], "to": [to.x, to.y], "promo": promotion_piece})
	selected = Vector2i(-1, -1)
	last_move = [from, to]
	board_view.animate(from, to)
	_render()
	_move_sound(result)
	if result.game_over:
		_show_result()
	else:
		_maybe_cpu()

## Wooden pieces on a board: a light tap, a heavier one for a capture or
## castling; a check also sounds the alert.
func _move_sound(result: Dictionary) -> void:
	if result.get("is_capture", false):
		SoundLib.play(self, "impact/wood_medium")
	elif result.get("is_castle", false):
		SoundLib.play(self, "impact/wood_heavy", -4.0)
	else:
		SoundLib.play(self, "impact/wood_light")
	if engine.is_in_check(engine.current_player) and not engine.game_over:
		_sfx("notify")

## Plays a sound from the app's library (silent on apps from before v0.23).
func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

# ---------- music ----------

func _prepare_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.prepare("calm", 2)

## Calm music from the hub's shared library while playing (apps before v0.33
## play none).
func _start_music() -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play("calm", self, 2, 2.0)

# ---------- online ----------

func _online_state() -> Dictionary:
	return {
		"board": engine.board, "current_player": engine.current_player,
		"castling_rights": engine.castling_rights,
		"en_passant_target": [engine.en_passant_target.x, engine.en_passant_target.y],
		"halfmove_clock": engine.halfmove_clock, "position_counts": engine.position_counts,
		"game_over": engine.game_over, "winner": engine.winner, "result_reason": engine.result_reason,
		"sans": san_moves,
		"ucis": ucis,
	}

func _on_online_started(my_player: int) -> void:
	my_color = ChessEngine.WHITE if my_player == 1 else ChessEngine.BLACK
	flipped = my_color == ChessEngine.BLACK
	cpu_level = -1
	mode = "online"
	clock_limit = 0
	increment = 0
	start_fen = ""
	started = true
	home.hide_home()
	_reset_board()
	_start_music()

func _on_remote_move(p: Dictionary) -> void:
	var kind := str(p.get("kind", ""))
	if kind != "":
		_on_remote_action(kind, p)
		return
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
	san_moves = []
	for s in st.get("sans", []):
		san_moves.append(str(s))
	ucis = []
	for u in st.get("ucis", []):
		ucis.append(str(u))
	if ucis.size() != san_moves.size():
		ucis = []  # an older app's state: PGN and replay then read the notation
	game_active = not engine.game_over
	selected = Vector2i(-1, -1)
	last_move = []
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
	var msg: String = tr(RESULT_MESSAGES.get(engine.result_reason, "Game over"))
	var decisive: bool = engine.winner != 0
	if decisive and _is_online():
		msg += "\n" + online.result_text(engine.winner == my_color)
	elif decisive and _vs_cpu():
		msg += "\n" + (tr("You win!") if engine.winner == ChessEngine.WHITE else tr("The computer wins!"))
	elif decisive:
		msg += tr("\n%s wins!") % (tr("White") if engine.winner == ChessEngine.WHITE else tr("Black"))
	result_label.text = msg
	if just_ended:
		_archive_game()
	if just_ended and _vs_cpu() and takebacks_used > 0:
		result_label.text += "\n" + tr("No rating change: takebacks were used.")
	elif just_ended and _vs_cpu():
		var score: float = 0.5 if not decisive else (1.0 if engine.winner == ChessEngine.WHITE else 0.0)
		var change: int = progress.rate(cpu_level, score)
		result_label.text += "\n" + tr("Rating %d (%s)") % [progress.rating(), ("+%d" % change) if change >= 0 else str(change)]
		var pts: int = ChessProgress.POINTS_WIN[cpu_level] if score == 1.0 else (ChessProgress.POINTS_WIN[cpu_level] / 2 if score == 0.5 else 0)
		if pts > 0:
			_earn(pts)
			result_label.text += "\n" + tr("+%d ⭐ points") % pts
	if info and just_ended:
		if _is_online():
			info.result("draw" if not decisive else ("win" if engine.winner == my_color else "loss"), true)
			result_label.text += "\n" + info.summary(["Online wins", "Online losses", "Online draws"])
		elif _vs_cpu():
			info.result("draw" if not decisive else ("win" if engine.winner == ChessEngine.WHITE else "loss"))
			if decisive and engine.winner == ChessEngine.WHITE:
				info.add("Wins (%s)" % LEVELS[cpu_level])
			result_label.text += "\n" + info.summary(["Wins", "Losses", "Draws"])
		else:
			info.add("Draws" if not decisive else ("White wins" if engine.winner == ChessEngine.WHITE else "Black wins"))
			if decisive:
				info.celebrate(result_label.text.split("\n")[0])
			result_label.text += "\n" + info.summary(["White wins", "Black wins"])
	_set_result_buttons([["Play Again", HomeKit.GO, _on_play_again], ["▶ Replay", HomeKit.BUTTON, _replay_last],
		["📋 Copy PGN", HomeKit.BUTTON, _copy_pgn], ["🏠 Chess Home", HomeKit.BUTTON, _go_home]])
	result_dialog.visible = true
	_update_actions()

## Points for the 🛒 Shop, also counted in 📊 Statistics.
func _earn(pts: int) -> void:
	if pts <= 0:
		return
	progress.earn(pts)
	if info:
		info.add("Points earned", pts)
	SoundLib.play(self, "rpg/handle_coins", -4.0)

# ---------- rendering ----------

## Look (STANDARDS §9): "classic" = the board and pieces picked in the 🛒
## Shop (wood and ivory/ebony to start) over the Landing art; "voodoo" =
## the neon board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: ColorRect
var art_bg: TextureRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		for c in bg.get_children():
			if c == art_bg:
				c.visible = skin == "classic"
			elif c is TextureRect:
				c.visible = art_bg == null  # the shared leather, only without the art
			else:
				c.visible = skin != "classic"  # the neon grid
	_render()

func _board_style() -> Dictionary:
	return ChessStyles.VOODOO_BOARD if skin == "voodoo" else ChessStyles.board(progress.board_id())

func _piece_style() -> Dictionary:
	if skin == "voodoo":
		return ChessStyles.VOODOO_PIECES
	var p: Dictionary = ChessStyles.pieces(progress.pieces_id())
	return {"white": p.white, "black": p.black}

func _render() -> void:
	dest_map = {}
	if selected.x >= 0:
		for m in engine.legal_moves_for(selected.x, selected.y):
			dest_map[m.to] = m

	var checked_king: Vector2i = Vector2i(-1, -1)
	if engine.is_in_check(engine.current_player):
		checked_king = engine.find_king(engine.current_player)

	board_view.board = engine.board
	board_view.flipped = flipped
	board_view.selected = selected
	var dests := {}
	for sq in dest_map:
		dests[sq] = dest_map[sq].is_capture
	board_view.dests = dests
	board_view.last_move = last_move
	board_view.check_sq = checked_king
	board_view.voodoo = skin == "voodoo"
	board_view.board_style = _board_style()
	board_view.piece_style = _piece_style()
	var star_squares: Array = []
	if _in_lesson():
		for s in stars_left:
			star_squares.append(ChessEngine.square_from_name(s))
	board_view.stars = star_squares
	board_view.queue_redraw()
	_update_info()
	_update_actions()

	if not game_active or _in_lesson():
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

# ---------- lessons ----------

func _build_lesson_panel(parent: Control) -> void:
	lesson_panel = PanelContainer.new()
	lesson_panel.add_theme_stylebox_override("panel", _strip_style())
	lesson_panel.visible = false
	parent.add_child(lesson_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	lesson_panel.add_child(col)
	lesson_head = HomeKit.label("", 20, Color(0.85, 0.78, 0.62))
	col.add_child(lesson_head)
	lesson_task = HomeKit.label("", 26, Color(0.98, 0.95, 0.88), true)
	col.add_child(lesson_task)
	lesson_feedback = HomeKit.label("", 22, Color(0.8, 0.85, 0.95), true)
	col.add_child(lesson_feedback)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	hint_btn = HomeKit.neon_button(tr("💡 Hint"), HomeKit.BUTTON, 22, 56)
	hint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_btn.pressed.connect(_on_hint)
	row.add_child(hint_btn)
	retry_btn = HomeKit.neon_button(tr("↺ Retry"), HomeKit.BUTTON, 22, 56)
	retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry_btn.pressed.connect(_on_retry)
	row.add_child(retry_btn)
	next_btn = HomeKit.neon_button("", HomeKit.GO, 22, 56)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(_on_next_board)
	row.add_child(next_btn)

## 📚 Lessons card over the Landing: every lesson, by category, with how far
## the player has got.
func _open_lessons() -> void:
	var parts: Array = home.card(tr("📚 Lessons"))
	var body: VBoxContainer = parts[1]
	SoundLib.play(self, "rpg/book_open", -6.0)
	body.add_child(HomeKit.label(tr("⭐ %d points · spend them in the 🛒 Shop") % progress.points(), 24, HomeKit.GOLD, true))
	body.add_child(HomeKit.label(tr("Each board solved the first time earns points; a hint halves them. Finishing a lesson earns a bonus."), 21, HomeKit.DIM, true))
	for cat in ChessLessons.CATEGORIES:
		body.add_child(home.section(str(cat.icon) + " " + tr(cat.title)))
		for l in cat.lessons:
			var solved := 0
			for i in l.boards.size():
				if progress.is_solved(ChessLessons.board_key(l.id, i)):
					solved += 1
			var mark: String = "  ✓" if progress.lesson_done(l.id) else ""
			var b := HomeKit.neon_button(tr(l.title) + mark + "\n" + tr("%d of %d boards") % [solved, l.boards.size()], HomeKit.BUTTON, 24, 88)
			b.pressed.connect(_on_lesson_picked.bind(l.id))
			body.add_child(b)
	home.show_card(parts[0])

func _on_lesson_picked(lesson_id: String) -> void:
	home.play_now(_start_lesson.bind(lesson_id))

func _start_lesson(lesson_id: String) -> void:
	var l: Dictionary = ChessLessons.find(lesson_id)
	if l.is_empty():
		return
	mode = "lesson"
	lesson = l
	lesson_points = 0
	# Carry on at the first board not solved yet.
	board_i = 0
	for i in l.boards.size():
		if not progress.is_solved(ChessLessons.board_key(l.id, i)):
			board_i = i
			break
	_enter_lesson()

func _start_daily() -> void:
	mode = "daily"
	var day: int = ChessProgress.day_number(ChessProgress.today())
	lesson = {"id": "daily", "title": "Daily Lesson", "boards": ChessLessons.daily_boards(day),
		"intro": "Three boards: a tactic and two checkmates. Solve them all to keep your streak."}
	lesson_points = 0
	board_i = 0
	_enter_lesson()

func _enter_lesson() -> void:
	flipped = false
	cpu_level = -1
	cpu_token += 1
	cpu_busy = false
	cpu_timer.stop()
	started = true
	result_dialog.visible = false
	_apply_panels()
	_load_lesson_board(board_i)
	_start_music()

func _load_lesson_board(i: int) -> void:
	board_i = clampi(i, 0, lesson.boards.size() - 1)
	var b: Dictionary = lesson.boards[board_i]
	engine.load_fen(b.fen)
	stars_left = b.get("stars", []).duplicate()
	lesson_moves = 0
	hint_used = false
	board_solved = false
	lesson_stage = 0
	lesson_busy = false
	lesson_timer.stop()
	game_active = true
	selected = Vector2i(-1, -1)
	last_move = []
	board_view.hint = []
	result_dialog.visible = false
	promotion_dialog.visible = false
	title_label.text = tr(lesson.title)
	lesson_head.text = tr("Board %d of %d") % [board_i + 1, lesson.boards.size()]
	if b.goal == "collect":
		lesson_head.text += "   ·   " + tr("Par: %d moves") % int(b.par)
	lesson_task.text = tr(b.text)
	_feedback(tr(lesson.intro), Color(0.8, 0.85, 0.95))
	hint_btn.disabled = false
	next_btn.visible = false
	_render()

func _feedback(text: String, color: Color) -> void:
	lesson_feedback.text = text
	lesson_feedback.add_theme_color_override("font_color", color)

func _snapshot() -> Dictionary:
	var b: Array = []
	for row in engine.board:
		b.append(row.duplicate())
	return {"board": b, "player": engine.current_player, "rights": engine.castling_rights.duplicate(),
		"ep": engine.en_passant_target, "half": engine.halfmove_clock, "counts": engine.position_counts.duplicate(),
		"stars": stars_left.duplicate(), "last": last_move.duplicate()}

func _restore(s: Dictionary) -> void:
	engine.board = s.board
	engine.current_player = s.player
	engine.castling_rights = s.rights
	engine.en_passant_target = s.ep
	engine.halfmove_clock = s.half
	engine.position_counts = s.counts
	engine.game_over = false
	engine.winner = 0
	engine.result_reason = ""
	stars_left = s.stars
	last_move = s.last

## A move on a lesson board: played, then judged against the board's goal.
func _lesson_move(from: Vector2i, to: Vector2i, promo: int) -> void:
	var b: Dictionary = lesson.boards[board_i]
	var goal: String = b.goal
	var before := _snapshot()
	var piece: int = engine.board[from.x][from.y]
	var target: int = engine.board[to.x][to.y]
	var forces := false
	if goal == "mate2" and lesson_stage == 0:
		forces = engine.forces_mate_in_two(from, to, promo)
	var res: Dictionary = engine.move(from, to, promo)
	if not res.valid:
		return
	selected = Vector2i(-1, -1)
	last_move = [from, to]
	board_view.hint = []
	board_view.animate(from, to)
	_move_sound(res)
	match goal:
		"collect":
			lesson_moves += 1
			var name: String = ChessEngine.square_name(to)
			if stars_left.has(name):
				stars_left.erase(name)
				_sfx("pickup")
			# Black never moves here: it's White's turn again.
			engine.current_player = ChessEngine.WHITE
			engine.game_over = false
			engine.result_reason = ""
			if ChessLessons.collect_done(engine.board, stars_left):
				_board_done(lesson_moves <= int(b.par))
			else:
				_feedback(tr("Moves: %d (par %d)") % [lesson_moves, int(b.par)], Color(0.8, 0.85, 0.95))
		"move":
			if _matches_solution(b, from, to, promo):
				_board_done(true)
			else:
				_wrong(before, tr("Not this time. Try again."))
		"check":
			if engine.is_in_check(ChessEngine.BLACK):
				_board_done(true)
			else:
				_wrong(before, tr("That's not check: no piece attacks the black king."))
		"escape":
			var how := "king" if absi(piece) == ChessEngine.KING else ("capture" if target != 0 else "block")
			if how == str(b.by):
				_board_done(true)
			else:
				var ask: Dictionary = {"king": "That works too, but this time move the king.",
					"block": "That works too, but this time block the check with a piece.",
					"capture": "That works too, but this time capture the attacker."}
				_wrong(before, tr(ask.get(str(b.by), "Try again.")))
		"mate1":
			_judge_mate(res, before)
		"mate2":
			if lesson_stage == 0:
				if res.result_reason == "checkmate":
					_board_done(true)
				elif forces:
					lesson_stage = 1
					lesson_busy = true
					_feedback(tr("Good move! Black answers..."), Color("7dff3a"))
					lesson_pending = "reply"
					lesson_timer.start(LESSON_REPLY_DELAY)
				else:
					_wrong(before, tr("That doesn't force mate. Look for checks."))
			else:
				_judge_mate(res, before)
	_render()

func _judge_mate(res: Dictionary, before: Dictionary) -> void:
	if res.result_reason == "checkmate":
		_board_done(true)
	elif res.result_reason == "stalemate":
		_wrong(before, tr("Stalemate! Black has no legal move and isn't in check: that's a draw. Try again."))
	else:
		_wrong(before, tr("Not checkmate yet. Try again."))

func _matches_solution(b: Dictionary, from: Vector2i, to: Vector2i, promo: int) -> bool:
	for u in b.get("solution", []):
		var m := ChessEngine.parse_uci(u)
		if m.from == from and m.to == to and (m.promo == 0 or m.promo == promo):
			return true
	return false

## A wrong lesson move: say why, then take it back.
func _wrong(before: Dictionary, why: String) -> void:
	_feedback(why, COLOR_CHECK)
	_sfx("invalid")
	lesson_busy = true
	lesson_snapshot = before
	lesson_pending = "undo"
	lesson_timer.start(LESSON_UNDO_DELAY)

func _on_lesson_timer() -> void:
	if not _in_lesson():
		return
	var what := lesson_pending
	lesson_pending = ""
	lesson_busy = false
	if what == "undo":
		_restore(lesson_snapshot)
		_render()
	elif what == "reply":
		_black_reply()

## Mate in two: Black plays its most stubborn answer (the one leaving White
## the fewest mates), then White must mate.
func _black_reply() -> void:
	var best: Dictionary = {}
	var fewest := 1 << 30
	for mv in engine.get_all_legal_moves(ChessEngine.BLACK):
		var c = engine.clone()
		c.move(mv.from, mv.move.to)
		var n: int = c.mates_in_one().size()
		if n < fewest:
			fewest = n
			best = {"from": mv.from, "to": mv.move.to}
	if best.is_empty():
		return
	var res: Dictionary = engine.move(best.from, best.to)
	last_move = [best.from, best.to]
	board_view.animate(best.from, best.to)
	_move_sound(res)
	lesson_stage = 2
	_feedback(tr("Now checkmate!"), Color("7dff3a"))
	_render()

## The board's goal is met: points the first time, the "why", and Next.
func _board_done(full: bool) -> void:
	board_solved = true
	game_active = false
	var b: Dictionary = lesson.boards[board_i]
	var text: String = tr(str(b.get("why", "Solved!")))
	if mode == "lesson" and progress.mark_solved(ChessLessons.board_key(lesson.id, board_i)):
		var pts: int = ChessProgress.POINTS_HARD_BOARD if b.goal == "mate2" else ChessProgress.POINTS_BOARD
		if hint_used or not full:
			pts /= 2
		if info:
			info.add("Lessons solved")
		lesson_points += pts
		_earn(pts)
		text += "  " + tr("+%d ⭐") % pts
	elif b.goal == "collect" and not full:
		text += "  " + tr("Can you do it in %d moves?") % int(b.par)
	_feedback(text, Color("7dff3a"))
	_sfx("record")
	hint_btn.disabled = true
	next_btn.text = tr("Next ›") if board_i + 1 < lesson.boards.size() else tr("Finish ✓")
	next_btn.visible = true

func _on_next_board() -> void:
	if board_i + 1 < lesson.boards.size():
		_load_lesson_board(board_i + 1)
	else:
		_lesson_complete()

func _lesson_complete() -> void:
	var lines: Array = []
	var buttons: Array = []
	if mode == "daily":
		var pts: int = progress.finish_daily()
		if pts > 0:
			if info:
				info.add("Daily lessons")
			_earn(pts)
			lines.append(tr("Daily lesson done! 🎉"))
			lines.append(tr("🔥 Streak: %d days") % progress.daily_streak())
			lines.append(tr("+%d ⭐ points") % pts)
		else:
			lines.append(tr("Done again! Points come once a day: new boards tomorrow."))
	else:
		if progress.mark_lesson_done(lesson.id):
			lesson_points += ChessProgress.POINTS_LESSON
			_earn(ChessProgress.POINTS_LESSON)
		lines.append(tr("Lesson complete! 🎓"))
		if lesson_points > 0:
			lines.append(tr("+%d ⭐ points") % lesson_points)
		var nxt: Dictionary = ChessLessons.next_lesson(lesson.id)
		if not nxt.is_empty():
			buttons.append([tr("▶ Next: %s") % tr(nxt.title), HomeKit.GO, _on_next_lesson.bind(nxt.id)])
	lines.append(tr("⭐ %d points to spend in the 🛒 Shop") % progress.points())
	result_label.text = "\n".join(lines)
	buttons.append(["📚 Lessons", HomeKit.BUTTON, _back_to_lessons])
	buttons.append(["🏠 Chess Home", HomeKit.BUTTON, _go_home])
	_set_result_buttons(buttons)
	result_dialog.visible = true

func _on_next_lesson(lesson_id: String) -> void:
	result_dialog.visible = false
	_start_lesson(lesson_id)

func _back_to_lessons() -> void:
	reopen_lessons = true
	home.go_home()

func _on_hint() -> void:
	if not _in_lesson() or board_solved or lesson_busy:
		return
	var b: Dictionary = lesson.boards[board_i]
	var u := ""
	match str(b.goal):
		"collect":
			var path: Array = ChessLessons.collect_solution(engine, stars_left)
			if not path.is_empty():
				u = path[0]
		"mate2":
			if lesson_stage == 2:
				var mates: Array = engine.mates_in_one()
				if not mates.is_empty():
					u = ChessEngine.uci(mates[0].from, mates[0].to)
			else:
				u = b.solution[0]
		_:
			u = b.solution[0] if b.has("solution") else ""
	if u == "":
		_feedback(tr("No hint from here: tap ↺ Retry."), COLOR_CHECK)
		return
	hint_used = true
	var m := ChessEngine.parse_uci(u)
	selected = Vector2i(-1, -1)  # the player taps the piece, then the square
	board_view.hint = [m.from, m.to]
	_feedback(tr("Hint: move the highlighted piece to the green square. (Half points)"), Color(0.8, 0.85, 0.95))
	_render()

func _on_retry() -> void:
	_load_lesson_board(board_i)

# ---------- 🛒 Shop ----------

var shop_body: VBoxContainer

func _open_shop() -> void:
	var parts: Array = home.card(tr("🛒 Shop"))
	shop_body = parts[1]
	_fill_shop()
	home.show_card(parts[0])

func _fill_shop() -> void:
	for c in shop_body.get_children():
		c.queue_free()
	shop_body.add_child(HomeKit.label(tr("⭐ %d points") % progress.points(), 30, HomeKit.GOLD))
	shop_body.add_child(HomeKit.label(tr("Earn points in 📚 Lessons, the 📅 Daily Lesson and by beating the computer. What you pick shows in the Classic look (⚙ Options → Look)."), 21, HomeKit.DIM, true))
	shop_body.add_child(home.section("Boards"))
	for b in ChessStyles.BOARDS:
		shop_body.add_child(_shop_row("board", b))
	shop_body.add_child(home.section("Pieces"))
	for p in ChessStyles.PIECES:
		shop_body.add_child(_shop_row("pieces", p))

func _shop_row(kind: String, item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(96, 96)
	pic.draw.connect(_draw_swatch.bind(pic, kind, str(item.id)))
	row.add_child(pic)
	var name_l := HomeKit.label(tr(item.name), 26, HomeKit.WHITE, true)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var owned: bool = progress.owns(kind, item.id)
	var in_use: bool = (progress.board_id() if kind == "board" else progress.pieces_id()) == item.id
	var text: String
	var color: Color = HomeKit.BUTTON
	if in_use:
		text = tr("✓ In use")
	elif owned:
		text = tr("Use")
	else:
		text = "⭐ %d" % int(item.price)
		color = HomeKit.GO if progress.points() >= int(item.price) else HomeKit.BUTTON
	var b := HomeKit.neon_button(text, color, 22, 64)
	b.custom_minimum_size.x = 150
	b.disabled = in_use or (not owned and progress.points() < int(item.price))
	b.pressed.connect(_on_shop_pick.bind(kind, str(item.id)))
	row.add_child(b)
	return row

func _on_shop_pick(kind: String, id: String) -> void:
	var had: bool = progress.owns(kind, id)
	if progress.buy(kind, id):
		if not had:
			SoundLib.play(self, "rpg/handle_coins")
		_fill_shop()
		_render()

## A 2x2 corner of a board, or a king and a knight from a piece set on wood.
func _draw_swatch(pic: Control, kind: String, id: String) -> void:
	var b: Dictionary = ChessStyles.board(id) if kind == "board" else ChessStyles.BOARDS[0]
	var s: float = pic.size.x / 2.0
	pic.draw_rect(Rect2(Vector2.ZERO, pic.size).grow(2), b.frame)
	for r in 2:
		for c in 2:
			pic.draw_rect(Rect2(Vector2(c, r) * s, Vector2(s, s)), b.dark if (r + c) % 2 == 1 else b.light)
	var st: Dictionary = ChessStyles.pieces(id if kind == "pieces" else progress.pieces_id())
	ChessPieces.draw(pic, ChessEngine.KING, true, Rect2(Vector2(0, s), Vector2(s, s)), st.white)
	ChessPieces.draw(pic, ChessEngine.KNIGHT, false, Rect2(Vector2(s, 0), Vector2(s, s)), st.black)

# ---------- save / load ----------

## Games against the computer and on one phone are saved; online games and
## lessons are not (a lesson board takes a minute: it starts again).
func _save_game() -> void:
	if not started or not game_active or _is_online() or _in_lesson() or mode == "online":
		return
	SaveUtil.write(SAVE_PATH, {
		"board": engine.board,
		"current_player": engine.current_player,
		"castling_rights": engine.castling_rights,
		"en_passant_target": [engine.en_passant_target.x, engine.en_passant_target.y],
		"halfmove_clock": engine.halfmove_clock,
		"position_counts": engine.position_counts,
		"cpu": cpu_level,
		"sans": san_moves,
		"last": [[last_move[0].x, last_move[0].y], [last_move[1].x, last_move[1].y]] if last_move.size() == 2 else [],
		"clock_limit": clock_limit,
		"clocks": [clocks[ChessEngine.WHITE], clocks[ChessEngine.BLACK]],
		"ucis": ucis, "start_fen": start_fen, "increment": increment, "takebacks": takebacks_used,
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
	started = true
	cpu_level = clampi(int(data.get("cpu", -1)), -1, 2)
	mode = "cpu" if cpu_level >= 0 else "local"
	flipped = false
	san_moves = []
	for s in data.get("sans", []):
		san_moves.append(str(s))
	last_move = []
	var last: Array = data.get("last", [])
	if last.size() == 2:
		last_move = [Vector2i(int(last[0][0]), int(last[0][1])), Vector2i(int(last[1][0]), int(last[1][1]))]
	clock_limit = int(data.get("clock_limit", 0))
	increment = int(data.get("increment", 0))
	start_fen = str(data.get("start_fen", ""))
	takebacks_used = int(data.get("takebacks", 0))
	draw_offered = false
	ucis = []
	for u in data.get("ucis", []):
		ucis.append(str(u))
	if ucis.size() != san_moves.size():
		ucis = []  # a save from before Phase A: no takebacks in it
	var saved_clocks: Array = data.get("clocks", [])
	_reset_clocks()
	if saved_clocks.size() == 2:
		clocks = {ChessEngine.WHITE: float(saved_clocks[0]), ChessEngine.BLACK: float(saved_clocks[1])}
	cpu_token += 1
	cpu_busy = false
	selected = Vector2i(-1, -1)
	result_dialog.visible = false
	promotion_dialog.visible = false
	title_label.text = tr("Chess")
	_apply_panels()
	_render()
	_start_music()
	_maybe_cpu()
	return true

# ---------- small drawn pieces of the screen ----------

## Captured pieces, small, in a row, and "+3" when that side is ahead.
class PieceRow extends Control:
	const Pieces = preload("res://scripts/games/chess/chess_pieces.gd")
	var types: Array = []
	var white := true
	var style: Dictionary = {}
	var lead := 0

	func _draw() -> void:
		var h: float = minf(size.y, 34.0)
		var step: float = h * 0.55
		var x := 0.0
		var y: float = (size.y - h) / 2.0
		var last := -1
		for t in types:
			if last != -1 and t != last:
				x += h * 0.25  # a gap between kinds
			if x + h > size.x - 44.0:
				break
			Pieces.draw(self, t, white, Rect2(Vector2(x, y), Vector2(h, h)), style.get("white" if white else "black", {}))
			x += step
			last = t
		if lead > 0:
			var font := ThemeDB.fallback_font
			var fs := 20
			draw_string(font, Vector2(x + h * 0.6, y + h * 0.5 + font.get_ascent(fs) * 0.4), "+%d" % lead,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.9, 0.75))

## The evaluation bar: White's share from the left (from the right when the
## board is flipped), with the number at the leading side.
class EvalBar extends Control:
	var score := 0.0
	var mate := 0
	var over := 99  # after the game: the winner (1 / -1 / 0 draw); 99 = still playing
	var flipped := false

	func _draw() -> void:
		var frac: float
		var text: String
		if over != 99:
			frac = 0.5 + 0.5 * over
			text = "1-0" if over == 1 else ("0-1" if over == -1 else "½-½")
		elif mate != 0:
			frac = 1.0 if mate > 0 else 0.0
			text = "M1"
		else:
			frac = 0.5 + clampf(score, -8.0, 8.0) / 16.0
			text = ("+%.1f" % score) if score >= 0.05 else ("%.1f" % score if score <= -0.05 else "0.0")
		if over == 99:
			frac = clampf(frac, 0.03, 0.97)  # a sliver of the losing side always shows
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.08, 0.08, 0.09))
		var w: float = size.x * frac
		var white_rect := Rect2(Vector2(size.x - w, 0), Vector2(w, size.y)) if flipped else Rect2(Vector2.ZERO, Vector2(w, size.y))
		draw_rect(white_rect, Color(0.94, 0.92, 0.88))
		draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, size.y), Color(0.85, 0.3, 0.2, 0.7), 2.0)
		draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)
		var font := ThemeDB.fallback_font
		var fs := int(maxf(12.0, size.y * 0.75))
		var white_ahead: bool = (mate > 0) or (mate == 0 and score >= 0.0)
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var on_left: bool = white_ahead != flipped
		var x: float = 6.0 if on_left else size.x - tw - 6.0
		var on_white: bool = white_ahead
		draw_string(font, Vector2(x, size.y / 2.0 + font.get_ascent(fs) * 0.38), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(0.1, 0.1, 0.1) if on_white else Color(0.95, 0.93, 0.88))

# ---------- Phase A (2026-11-25): game actions, takeback, resign / draw, copy, My Games, replay ----------

const BRAND_PATH := "res://scripts/common/brand.gd"

## The row under the board: ⟲ Undo, ½ Draw, 🏳 Resign, ⇅ Flip, 📋 Copy.
func _build_action_row(root: Control) -> void:
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)
	takeback_btn = _action_button("⟲ Undo", _on_takeback)
	draw_btn = _action_button("½ Draw", _on_draw)
	resign_btn = _action_button("🏳 Resign", _on_resign)
	flip_btn = _action_button("⇅ Flip", _on_flip)
	copy_btn = _action_button("📋 Copy", _on_copy)

func _action_button(text: String, cb: Callable) -> Button:
	var b := HomeKit.neon_button(tr(text), HomeKit.BUTTON, 20, 52)
	b.custom_minimum_size.x = 0
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.pressed.connect(cb)
	action_row.add_child(b)
	return b

func _update_actions() -> void:
	if action_row == null or takeback_btn == null:
		return
	var playing: bool = game_active and started and not _in_lesson()
	takeback_btn.visible = (mode == "cpu" or mode == "local") and progress.panel_on("takebacks")
	takeback_btn.disabled = not _can_takeback()
	draw_btn.disabled = not playing or draw_offered
	resign_btn.disabled = not playing

# --- picking and dragging ---

## The finger lifted on the piece it pressed without dragging: a second tap
## on the picked piece unpicks it.
func _on_square_released(r: int, c: int) -> void:
	if _deselect_on_release and Vector2i(r, c) == selected:
		_deselect_on_release = false
		selected = Vector2i(-1, -1)
		_render()

## The picked piece was dragged to `to`: played if legal, else it goes back.
func _on_drag_dropped(from: Vector2i, to: Vector2i) -> void:
	_deselect_on_release = false
	if selected != from:
		return
	if dest_map.has(to):
		_on_square_pressed(to.x, to.y)
	else:
		_render()

# --- takeback ---

func _can_takeback() -> bool:
	return game_active and started and (mode == "cpu" or mode == "local") and not _is_online() \
		and progress.panel_on("takebacks") and not ucis.is_empty() and ucis.size() == san_moves.size() \
		and not promotion_dialog.visible

## Against the computer: your last move and its answer; on one phone: the last move.
func _on_takeback() -> void:
	if not _can_takeback():
		return
	var n := 2 if _vs_cpu() and engine.current_player == ChessEngine.WHITE else 1
	n = mini(n, ucis.size())
	takebacks_used += 1
	_rebuild_to(ucis.size() - n)
	SoundLib.play(self, "impact/wood_light", -6.0)
	_maybe_cpu()

## Plays the game again from its start up to move `k` (in plies).
func _rebuild_to(k: int) -> void:
	var keep: Array = ucis.slice(0, k)
	if start_fen != "":
		engine.load_fen(start_fen)
	else:
		engine.reset()
	ucis = []
	san_moves = []
	last_move = []
	for u in keep:
		var m: Dictionary = ChessEngine.parse_uci(str(u))
		if m.is_empty():
			break
		var promo: int = m.promo if m.promo > 0 else ChessEngine.QUEEN
		var s: String = engine.san(m.from, m.to, promo)
		if not engine.move(m.from, m.to, promo).valid:
			break
		san_moves.append(s + engine.san_suffix())
		ucis.append(str(u))
		last_move = [m.from, m.to]
	cpu_token += 1
	cpu_busy = false
	cpu_timer.stop()
	selected = Vector2i(-1, -1)
	pending_promotion = {}
	_deselect_on_release = false
	game_active = true
	_render()

# --- a question on the result card ---

## Shows `text` with buttons [[English text, colour, callable], ...].
func _ask(text: String, specs: Array) -> void:
	result_label.text = text
	_set_result_buttons(specs)
	result_dialog.visible = true

## Closes a question; after the game it shows the result again.
func _close_ask() -> void:
	if engine.game_over and not _in_lesson():
		_show_result()
	else:
		result_dialog.visible = false

# --- resign and draw ---

## Who gives up from this phone: you (vs computer, online), else the side to move.
func _resigner() -> int:
	if _is_online():
		return my_color
	if _vs_cpu():
		return ChessEngine.WHITE
	return engine.current_player

func _on_resign() -> void:
	if not game_active or not started or _in_lesson():
		return
	var q := tr("Resign this game?") if (_is_online() or _vs_cpu()) else tr("Resign for %s?") % _side_name(_resigner())
	_ask(q, [["🏳 Resign", HomeKit.PINK, _do_resign], ["Cancel", HomeKit.BUTTON, _close_ask]])

func _do_resign() -> void:
	if not game_active:
		return
	var side := _resigner()
	engine.resign(side)
	if _is_online():
		online.send_move({"kind": "resign", "by": side, "from": [-1, -1], "to": [-1, -1]})
	_render()
	_show_result()

func _on_draw() -> void:
	if not game_active or not started or _in_lesson() or draw_offered:
		return
	if _is_online():
		draw_offered = true
		online.send_move({"kind": "draw_offer", "from": [-1, -1], "to": [-1, -1]})
		home.help_toast(tr("Draw offered. Waiting for an answer…"))
		_update_actions()
	elif _vs_cpu():
		# The computer takes a draw when it stands worse, or late in a level game.
		var score: float = float(engine.evaluation(150).get("score", 0.0))
		if score >= 1.0 or (san_moves.size() >= 60 and absf(score) <= 0.3):
			_do_draw()
		else:
			home.help_toast(tr("The computer declines the draw: it wants to play on."))
	else:
		_ask(tr("Do both players agree to a draw?"), [["½ Draw", HomeKit.GO, _do_draw], ["Cancel", HomeKit.BUTTON, _close_ask]])

func _do_draw() -> void:
	if not game_active:
		return
	engine.agree_draw()
	_render()
	_show_result()

func _accept_online_draw() -> void:
	if not game_active:
		result_dialog.visible = false
		return
	engine.agree_draw()
	online.send_move({"kind": "draw_accept", "from": [-1, -1], "to": [-1, -1]})
	_render()
	_show_result()

func _decline_online_draw() -> void:
	result_dialog.visible = false
	if _is_online():
		online.send_move({"kind": "draw_decline", "from": [-1, -1], "to": [-1, -1]})

## Resign / draw messages from the other phone.
func _on_remote_action(kind: String, p: Dictionary) -> void:
	match kind:
		"resign":
			if engine.game_over:
				return
			engine.resign(int(p.get("by", -my_color)))
			_render()
			_show_result()
		"draw_offer":
			if not game_active:
				return
			var who: String = online.opponent_name() if online.has_method("opponent_name") else tr("Your opponent")
			_ask(tr("%s offers a draw.") % who, [["½ Accept draw", HomeKit.GO, _accept_online_draw], ["Decline", HomeKit.BUTTON, _decline_online_draw]])
		"draw_accept":
			if draw_offered and not engine.game_over:
				draw_offered = false
				engine.agree_draw()
				_render()
				_show_result()
		"draw_decline":
			draw_offered = false
			home.help_toast(tr("Draw declined."))
			_update_actions()

# --- flip ---

func _on_flip() -> void:
	flipped = not flipped
	_render()

# --- PGN / FEN ---

func _on_copy() -> void:
	_ask(tr("Copy this game"), [["📋 Copy PGN", HomeKit.BUTTON, _copy_pgn], ["📋 Copy FEN", HomeKit.BUTTON, _copy_fen],
		["Cancel", HomeKit.BUTTON, _close_ask]])

func _copy_pgn() -> void:
	DisplayServer.clipboard_set(_pgn_for(_current_entry()))
	home.help_toast(tr("PGN copied: paste it into any chess app."))
	_close_ask()

func _copy_fen() -> void:
	DisplayServer.clipboard_set(engine.to_fen(san_moves.size() / 2 + 1))
	home.help_toast(tr("FEN copied: the position as one line of text."))
	_close_ask()

## This game as a My Games entry (also what PGN is made from).
func _current_entry() -> Dictionary:
	return {
		"date": Time.get_date_string_from_system(),
		"white": _side_name(ChessEngine.WHITE), "black": _side_name(ChessEngine.BLACK),
		"result": engine.result_token(), "reason": engine.result_reason,
		"fen": start_fen, "ucis": ucis.duplicate() if ucis.size() == san_moves.size() else [],
		"sans": san_moves.duplicate(), "mode": mode, "cpu": cpu_level,
	}

func _pgn_for(e: Dictionary) -> String:
	var site := "-"
	if ResourceLoader.exists(BRAND_PATH):
		var b = load(BRAND_PATH)
		site = str(b.get("NAME")) if b.get("NAME") != null else "-"
	var headers := {"Event": "Casual game", "Site": site, "Date": str(e.get("date", "")).replace("-", "."),
		"White": str(e.get("white", "White")), "Black": str(e.get("black", "Black"))}
	return ChessEngine.make_pgn(headers, e.get("sans", []), str(e.get("result", "*")), str(e.get("fen", "")))

# --- 📜 My Games ---

func _archive_game() -> void:
	if san_moves.is_empty():
		return
	ChessArchive.add(_current_entry())

var archive_card: Control
var archive_body: VBoxContainer

func _open_archive() -> void:
	var parts: Array = home.card(tr("📜 My Games"))
	archive_card = parts[0]
	archive_body = parts[1]
	_fill_archive("")
	home.show_card(archive_card)

func _fill_archive(note: String) -> void:
	for c in archive_body.get_children():
		c.queue_free()
	archive_body.add_child(HomeKit.label(tr("Your last 50 finished games on this phone. Tap one to replay it move by move, or paste a game (PGN) or a position (FEN) copied from another chess app."), 21, HomeKit.DIM, true))
	var paste := HomeKit.neon_button(tr("📥 Paste PGN or FEN"), HomeKit.BUTTON, 24, 62)
	paste.pressed.connect(_on_paste)
	archive_body.add_child(paste)
	if note != "":
		archive_body.add_child(HomeKit.label(note, 22, HomeKit.GOLD, true))
	var games := ChessArchive.load_all()
	if games.is_empty():
		archive_body.add_child(HomeKit.label(tr("No finished games yet."), 24, HomeKit.WHITE, true))
	for e in games:
		if not (e is Dictionary):
			continue
		var moves: int = int(ceil((e.get("sans", []) as Array).size() / 2.0))
		var b := HomeKit.neon_button("%s   %s – %s   %s · %s" % [str(e.get("date", "")), str(e.get("white", "")),
			str(e.get("black", "")), str(e.get("result", "*")), tr("%d moves") % moves], HomeKit.BUTTON, 21, 58)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = 0
		b.pressed.connect(_open_replay.bind(e))
		archive_body.add_child(b)

func _on_paste() -> void:
	var text := DisplayServer.clipboard_get().strip_edges()
	if text == "":
		_fill_archive(tr("The clipboard is empty: copy a PGN or a FEN first."))
		return
	if not "\n" in text and ChessEngine.is_valid_fen(text):
		var probe = ChessEngine.new()
		probe.load_fen(text)
		if probe.get_all_legal_moves(probe.current_player).is_empty():
			_fill_archive(tr("No legal move in that position: nothing to play."))
			return
		_fill_archive(tr("Position read. Play it:"))
		var specs := [["🙂 vs Computer: Easy", 0], ["😐 vs Computer: Medium", 1], ["😈 vs Computer: Hard", 2], ["👥 2 Players", -1]]
		for s in specs:
			var b := HomeKit.neon_button(tr(s[0]), HomeKit.GO, 24, 62)
			b.pressed.connect(_start_from_fen.bind(text, s[1]))
			archive_body.add_child(b)
			archive_body.move_child(b, 3 + specs.find(s))
		return
	var g: Dictionary = ChessEngine.parse_pgn(text)
	if g.is_empty():
		_fill_archive(tr("That isn't a game (PGN) or a position (FEN) this app can read."))
		return
	var h: Dictionary = g.headers
	var e := {"date": str(h.get("Date", Time.get_date_string_from_system())).replace(".", "-"),
		"white": str(h.get("White", "White")), "black": str(h.get("Black", "Black")),
		"result": str(g.result), "reason": "", "fen": str(g.fen), "ucis": g.ucis, "sans": g.sans, "mode": "import", "cpu": -1}
	ChessArchive.add(e)
	var note := tr("Game added.")
	if str(g.error) != "":
		note = tr("Game added up to the move it couldn't read: %s") % str(g.error)
	_fill_archive(note)
	_open_replay(e)

func _start_from_fen(fen: String, level: int) -> void:
	if archive_card and is_instance_valid(archive_card):
		home.close_card(archive_card)
	home.play_now(_begin_fen.bind(fen, level))

func _begin_fen(fen: String, level: int) -> void:
	mode = "cpu" if level >= 0 else "local"
	cpu_level = level
	SaveUtil.delete(SAVE_PATH)
	_begin(fen)

# --- ▶ Replay ---

## The open replay: {entry, positions, i, view, moves, count, timer, play}.
var rp: Dictionary = {}

func _replay_last() -> void:
	_open_replay(_current_entry())

func _open_replay(e: Dictionary) -> void:
	var positions := _positions_for(e)
	var parts: Array = home.card(tr("▶ Replay"))
	var card: Control = parts[0]
	var body: VBoxContainer = parts[1]
	var col: VBoxContainer = parts[2]
	body.add_child(HomeKit.label("%s – %s   %s" % [str(e.get("white", "")), str(e.get("black", "")), str(e.get("result", "*"))], 26, HomeKit.WHITE, true, true))
	var view = BoardView.new()
	view.interactive = false
	var vp := get_viewport_rect().size
	var side: float = maxf(240.0, minf(vp.x - 72.0, vp.y * 0.5))
	view.custom_minimum_size = Vector2(side, side)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.board_style = _board_style()
	view.piece_style = _piece_style()
	view.voodoo = skin == "voodoo"
	view.coords = progress.panel_on("coords")
	view.flipped = flipped
	body.add_child(view)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count := HomeKit.label("", 22, HomeKit.DIM, false, true)
	body.add_child(count)
	var moves := HomeKit.label("", 22, Color(0.9, 0.88, 0.82), true)
	body.add_child(moves)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var play: Button
	for spec in [["⏮", _replay_go.bind(-1000)], ["◀", _replay_go.bind(-1)], ["⏯", _replay_toggle], ["▶", _replay_go.bind(1)], ["⏭", _replay_go.bind(1000)]]:
		var b := HomeKit.neon_button(spec[0], HomeKit.BUTTON, 28, 64)
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		row.add_child(b)
		if spec[0] == "⏯":
			play = b
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	col.add_child(row2)
	for spec in [["📋 PGN", _replay_copy_pgn], ["📋 FEN", _replay_copy_fen], ["⇅ Flip", _replay_flip]]:
		var b := HomeKit.neon_button(tr(spec[0]), HomeKit.BUTTON, 22, 56)
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		row2.add_child(b)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_replay_go.bind(1))
	card.add_child(timer)
	rp = {"entry": e, "positions": positions, "i": 0, "view": view, "moves": moves, "count": count, "timer": timer, "play": play}
	_replay_show(0)
	home.show_card(card)

## Every position of a game, from its start: {board, last, check, fen}.
## Played from the UCI moves when there are all of them, else from the notation.
func _positions_for(e: Dictionary) -> Array:
	var eng = ChessEngine.new()
	var fen := str(e.get("fen", ""))
	if fen != "" and ChessEngine.is_valid_fen(fen):
		eng.load_fen(fen)
	else:
		eng.reset()
	var out: Array = [_snap(eng, [], 0)]
	var u: Array = e.get("ucis", [])
	var sans: Array = e.get("sans", [])
	var by_uci: bool = not u.is_empty() and u.size() == sans.size()
	var list: Array = u if by_uci else sans
	for i in list.size():
		var m: Dictionary = ChessEngine.parse_uci(str(list[i])) if by_uci else eng.move_from_san(str(list[i]))
		if m.is_empty():
			break
		var promo: int = m.promo if m.promo > 0 else ChessEngine.QUEEN
		if not eng.move(m.from, m.to, promo).valid:
			break
		out.append(_snap(eng, [m.from, m.to], i + 1))
	return out

func _snap(eng, last: Array, ply: int) -> Dictionary:
	var chk := Vector2i(-1, -1)
	if eng.is_in_check(eng.current_player):
		chk = eng.find_king(eng.current_player)
	return {"board": eng.board.duplicate(true), "last": last, "check": chk, "fen": eng.to_fen(ply / 2 + 1)}

func _replay_ok() -> bool:
	return not rp.is_empty() and is_instance_valid(rp.get("view"))

func _replay_show(i: int) -> void:
	if not _replay_ok():
		return
	var positions: Array = rp.positions
	i = clampi(i, 0, positions.size() - 1)
	rp.i = i
	var p: Dictionary = positions[i]
	var view = rp.view
	view.board = p.board
	view.last_move = p.last
	view.check_sq = p.check
	view.queue_redraw()
	var sans: Array = rp.entry.get("sans", [])
	var parts: PackedStringArray = []
	for k in mini(sans.size(), positions.size() - 1):
		if k % 2 == 0:
			parts.append("%d." % (k / 2 + 1))
		parts.append(("▸" + str(sans[k])) if k == i - 1 else str(sans[k]))
	rp.moves.text = " ".join(parts)
	rp.count.text = tr("Move %d of %d") % [i, positions.size() - 1]
	if i >= positions.size() - 1 and rp.timer.time_left > 0:
		rp.timer.stop()

func _replay_go(step: int) -> void:
	if _replay_ok():
		_replay_show(int(rp.i) + step)

func _replay_toggle() -> void:
	if not _replay_ok():
		return
	if not rp.timer.is_stopped():
		rp.timer.stop()
		return
	if int(rp.i) >= rp.positions.size() - 1:
		_replay_show(0)
	rp.timer.start()

func _replay_flip() -> void:
	if _replay_ok():
		rp.view.flipped = not rp.view.flipped
		rp.view.queue_redraw()

func _replay_copy_pgn() -> void:
	if _replay_ok():
		DisplayServer.clipboard_set(_pgn_for(rp.entry))
		home.help_toast(tr("PGN copied: paste it into any chess app."))

func _replay_copy_fen() -> void:
	if _replay_ok():
		DisplayServer.clipboard_set(str(rp.positions[rp.i].fen))
		home.help_toast(tr("FEN copied: the position as one line of text."))

# ---------- helps (STANDARDS §17) ----------

## 💡 help: the computer plays the move it thinks best for your side.
func _help_move() -> bool:
	if not game_active or _in_lesson() or _is_online() or promotion_dialog.visible or lesson_busy:
		return false
	if _vs_cpu() and (engine.current_player != ChessEngine.WHITE or cpu_busy):
		return false
	var mv: Dictionary = engine.clone().cpu_move(1, rng)
	if mv.is_empty():
		return false
	selected = Vector2i(-1, -1)
	_apply_move(mv.from, mv.to, ChessEngine.QUEEN)
	return true
