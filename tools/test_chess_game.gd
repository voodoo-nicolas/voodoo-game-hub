extends SceneTree

## Plays Chess's screen headless: a lesson board solved by taps (points
## earned once), a wrong move taken back, a mate in two with Black's reply,
## today's daily lesson solved through its hints, the shop, a move against
## the computer (its reply arrives), a clock running out, save and resume,
## and the info panels switched off and on.
##
##   godot --headless --path . --script res://tools/test_chess_game.gd
##
## Plays on the real user data (chess_progress.json, chess_save.json,
## stats): back up %APPDATA%\Godot\app_userdata\Voodoo first.

const Engine2 = preload("res://scripts/games/chess/chess_engine.gd")
const Lessons = preload("res://scripts/games/chess/chess_lessons.gd")

var fails := 0
var g: Node

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func tap_move(u: String) -> void:
	var m := Engine2.parse_uci(u)
	g._on_square_pressed(m.from.x, m.from.y)
	g._on_square_pressed(m.to.x, m.to.y)
	if g.promotion_dialog.visible:
		g._on_promotion_chosen(m.promo if m.promo > 0 else Engine2.QUEEN)

func _run() -> void:
	for i in 3:
		await process_frame
	change_scene_to_file("res://scenes/games/chess/chess.tscn")
	await frames(20)
	g = current_scene
	g.home.hide_home()
	paused = false
	# --- a lesson board, by taps ---
	var key: String = Lessons.board_key("rook", 0)
	g.progress.data.solved_list.erase(key)
	g.progress.data.done_lessons.erase("rook")
	var pts0: int = g.progress.points()
	g._start_lesson("rook")
	g._load_lesson_board(0)
	check(g._in_lesson() and g.lesson_panel.visible and not g.eval_bar.visible, "lesson mode shows the lesson panel, no eval bar")
	for u in ["a1a6", "a6f6", "f6f1"]:
		tap_move(u)
		await frames(2)
	check(g.board_solved, "rook board 1 solved by taps")
	check(g.progress.points() == pts0 + 10, "10 points for the first solve (got %d)" % (g.progress.points() - pts0))
	g._load_lesson_board(0)
	for u in ["a1a6", "a6f6", "f6f1"]:
		tap_move(u)
	check(g.board_solved and g.progress.points() == pts0 + 10, "no points the second time")
	# --- a wrong move is taken back ---
	g._load_lesson_board(2)
	var before: String = str(g.engine.board)
	tap_move("b1b2")
	check(g.lesson_busy, "wrong move: waiting to take it back")
	await frames(90)
	check(not g.lesson_busy and str(g.engine.board) == before, "wrong move taken back")
	tap_move("b1e1")
	check(g.board_solved, "the skewer solves board 3")
	# --- mate in two: Black answers, then the mate ---
	g._start_lesson("mate_in_two")
	g._load_lesson_board(0)
	tap_move("e2e8")
	check(g.lesson_stage == 1, "first move accepted, Black to answer")
	await frames(70)
	check(g.lesson_stage == 2 and g.engine.current_player == Engine2.WHITE, "Black answered")
	var mates: Array = g.engine.mates_in_one()
	check(not mates.is_empty(), "a mate is there")
	tap_move(Engine2.uci(mates[0].from, mates[0].to))
	check(g.board_solved, "mate in two solved")
	# --- the daily lesson, through its hints ---
	g._start_daily()
	for i in 3:
		check(g.board_i == i, "daily board %d" % (i + 1))
		var guard := 0
		while not g.board_solved and guard < 8:
			guard += 1
			if g.lesson_busy:
				await frames(70)
				continue
			g._on_hint()
			var h: Array = g.board_view.hint
			if h.size() != 2:
				break
			g._on_square_pressed(h[0].x, h[0].y)
			g._on_square_pressed(h[1].x, h[1].y)
			if g.promotion_dialog.visible:
				g._on_promotion_chosen(Engine2.QUEEN)
			await frames(2)
		check(g.board_solved, "daily board %d solved with hints" % (i + 1))
		g._on_next_board()
	check(g.result_dialog.visible, "daily lesson finished")
	check(g.progress.daily_done_today(), "daily marked done today")
	# --- shop ---
	g.progress.data["points"] = 1000
	g._open_shop()
	g._on_shop_pick("board", "marble")
	check(g.progress.board_id() == "marble" and g.progress.points() == 750, "bought Marble Hall")
	g._on_shop_pick("board", "wood")
	check(g.progress.board_id() == "wood" and g.progress.points() == 750, "switching back costs nothing")
	g.home._close_overlays()
	# --- against the computer ---
	g.progress.set_clock_index(0)
	g._new_vs_cpu(0)
	check(g.mode == "cpu" and not g.lesson_panel.visible, "vs computer: game panels")
	tap_move("e2e4")
	check(g.san_moves == ["e4"], "move list: e4")
	var waited := 0
	while g.san_moves.size() < 2 and waited < 400:
		await process_frame
		waited += 1
	check(g.san_moves.size() == 2, "the computer replied (%s)" % str(g.san_moves))
	# --- save and resume ---
	g._save_game()
	var saved: Array = g.san_moves.duplicate()
	g._reset_board()
	check(g._load_saved_game() and g.san_moves == saved and g.mode == "cpu", "resume keeps the moves and mode")
	# --- a clock running out ---
	g.progress.set_clock_index(1)
	g._new_two_player()
	check(g.clock_limit == 300, "5 minute clock")
	g.clocks[Engine2.WHITE] = 0.05
	await frames(10)
	check(g.engine.game_over and g.engine.result_reason == "timeout" and g.engine.winner == Engine2.BLACK, "White's flag falls: Black wins")
	check(g.result_dialog.visible, "result shown")
	g.progress.set_clock_index(0)
	# --- panels off and on ---
	for k in ["eval", "moves", "clocks", "players", "captured"]:
		g._on_panel_pick(1, k)
	g._new_two_player()
	check(not g.eval_bar.visible and not g.moves_scroll.get_parent().visible and not g.strips[0].box.visible, "panels off")
	for k in ["eval", "moves", "clocks", "players", "captured"]:
		g._on_panel_pick(0, k)
	check(g.eval_bar.visible and g.strips[0].box.visible, "panels back on")
	_delete_test_save()
	print("%d failed" % fails)
	quit(1 if fails > 0 else 0)

func _delete_test_save() -> void:
	# Leave no half-played test game behind as a Resume.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://chess_save.json"))
