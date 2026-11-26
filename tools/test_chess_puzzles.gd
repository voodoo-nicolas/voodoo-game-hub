extends SceneTree

## Chess Phase C (2026-11-25), headless: every puzzle in games/chess/puzzles.json
## loads and every move in it is legal for our engine (mate puzzles end in
## mate); then the screen: a rated puzzle solved (rating up), a wrong move
## (rating down once, taken back), hint, solution, Rush strikes and end,
## Survival end, Puzzle of the Day streak.
##
##   godot --headless --path . --script res://tools/test_chess_puzzles.gd [-- --skip-bank]
##
## WRITES the real chess_progress.json + stats: back up
## %APPDATA%\Godot\app_userdata\Voodoo first.

const E = preload("res://scripts/games/chess/chess_engine.gd")
const P = preload("res://scripts/games/chess/chess_puzzle_bank.gd")

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

func _bank_test() -> void:
	var all := P.all()
	check(all.size() >= 3000, "bank has %d puzzles" % all.size())
	var bad := 0
	var mates_ok := true
	for p in all:
		var e = E.new()
		e.load_fen(str(p[1]))
		var ok := true
		for u in P.moves_of(p):
			var m := E.parse_uci(u)
			if m.is_empty() or not e.move(m.from, m.to, m.promo if m.promo > 0 else E.QUEEN).valid:
				ok = false
				break
		if not ok:
			bad += 1
			if bad < 5:
				print("  unplayable ", p[0])
		elif str(p[4]).contains("mateIn") and e.result_reason != "checkmate":
			mates_ok = false
			print("  mate puzzle not mate ", p[0])
	check(bad == 0, "every puzzle playable (%d bad)" % bad)
	check(mates_ok, "every mate puzzle ends in mate")
	for t in P.THEME_ORDER:
		var n := 0
		for p in all:
			if P.has_theme(p, t):
				n += 1
		if n < 5:
			check(false, "theme %s has %d" % [t, n])
	check(not P.daily("2026-11-25").is_empty() and P.daily("2026-11-25") == P.daily("2026-11-25") and P.daily("2026-11-25") != P.daily("2026-11-26"), "Puzzle of the Day by date")

## Plays the player's right move for the puzzle on the board.
func play_right() -> void:
	var m := E.parse_uci(g.pz_moves[g.pz_step])
	g._on_square_pressed(m.from.x, m.from.y)
	g._on_square_pressed(m.to.x, m.to.y)
	if g.promotion_dialog.visible:
		g._on_promotion_chosen(m.promo if m.promo > 0 else E.QUEEN)

func wait_turn() -> void:
	for i in 200:
		if not g.pz_busy:
			return
		await frames(1)

## A legal move that isn't the answer and doesn't mate.
func play_wrong() -> bool:
	var want: String = g.pz_moves[g.pz_step]
	for e in g.engine.get_all_legal_moves(g.engine.current_player):
		var u := E.uci(e.from, e.move.to)
		if u == want.substr(0, 4):
			continue
		var probe = g.engine.clone()
		probe.move(e.from, e.move.to)
		if probe.result_reason == "checkmate":
			continue
		g._puzzle_move(e.from, e.move.to, E.QUEEN)
		return true
	return false

func solve() -> void:
	for k in 12:
		await wait_turn()
		if g.pz_done or g.pz_step >= g.pz_moves.size() or g.mode != "puzzle":
			return
		var before: String = str(g.pz[0])
		play_right()
		if str(g.pz[0]) != before:
			return  # a run moved on to the next puzzle

func _run() -> void:
	if not "--skip-bank" in OS.get_cmdline_user_args():
		_bank_test()  # ~10 min: every move of every puzzle
	g = load("res://scenes/games/chess/chess.tscn").instantiate()
	root.add_child(g)
	await frames(3)
	var d := P.record(g.progress)
	d.rating = 1200
	d.played = 30
	d.streak = 0
	# Rated: solved -> up.
	g.home.play_now(g._begin_puzzle.bind("rated", ""))
	await wait_turn()
	check(g._in_puzzle() and g.engine.current_player == g.pz_color and g.lesson_panel.visible, "rated puzzle on the board, first move played")
	await solve()
	check(g.pz_done and int(P.record(g.progress).rating) > 1200, "solved: rating up to %d" % int(P.record(g.progress).rating))
	# Rated: wrong -> down once, board unchanged.
	g._pz_next()
	await wait_turn()
	var r0 := int(P.record(g.progress).rating)
	var board_before := str(g.engine.board)
	check(play_wrong(), "found a wrong move")
	check(str(g.engine.board) == board_before and int(P.record(g.progress).rating) < r0, "wrong move not played, rating down")
	var r1 := int(P.record(g.progress).rating)
	g._pz_hint()
	check(g.board_view.hint.size() == 1 and int(P.record(g.progress).rating) == r1, "hint shows the piece, no second loss")
	g._pz_retry()  # 👁 solution
	for i in 400:
		if g.pz_done:
			break
		await frames(1)
	check(g.pz_done and g.pz_step == g.pz_moves.size(), "solution played out")
	# A theme.
	g._begin_puzzle("rated", "fork")
	check(P.has_theme(g.pz, "fork"), "theme puzzle has the theme")
	# Rush: 3 strikes end it.
	g._begin_run("rush")
	await wait_turn()
	await solve()
	await wait_turn()
	check(g.run_score == 1 and g.pz_kind == "rush", "rush: one solved, next loaded")
	for k in 3:
		await wait_turn()
		play_wrong()
	check(g.pz_done and g.result_dialog.visible and int(P.record(g.progress).best_rush) >= 1, "rush over after 3 mistakes")
	# Rush clock.
	g._run_again()
	g.run_left = 0.5
	g._process(1.0)
	check(g.pz_done and g.result_dialog.visible, "rush ends when time is up")
	# Survival: first mistake ends it.
	g._begin_run("survival")
	await wait_turn()
	play_wrong()
	check(g.pz_done and g.result_dialog.visible, "survival over at the first mistake")
	# Daily.
	P.record(g.progress).daily_last = g._yesterday()
	P.record(g.progress).daily_streak = 4
	g._begin_puzzle("daily", "")
	await wait_turn()
	await solve()
	check(str(P.record(g.progress).daily_last) == g._today() and int(P.record(g.progress).daily_streak) == 5, "daily solved: streak 5")
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
