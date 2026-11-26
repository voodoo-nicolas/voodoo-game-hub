extends SceneTree

## Chess Phase A (2026-11-25), headless: FEN out and back, SAN read back for
## every move of random games, PGN made and read back, resign / agreed draw,
## and on the game screen: takeback vs the computer and on one phone,
## increment, drag-to-move, resign, the archive entry, replay positions.
##
##   godot --headless --path . --script res://tools/test_chess_phase_a.gd
##
## Plays on the real user data (chess_save.json, chess_games.json, stats):
## back up %APPDATA%\Godot\app_userdata\Voodoo first.

const E = preload("res://scripts/games/chess/chess_engine.gd")
const Archive = preload("res://scripts/games/chess/chess_archive.gd")

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

func _engine_tests() -> void:
	var e = E.new()
	e.reset()
	check(e.to_fen() == E.START_FEN, "start FEN")
	e.move(Vector2i(6, 4), Vector2i(4, 4))
	check(e.to_fen() == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1", "FEN after e4: " + e.to_fen())
	check(E.is_valid_fen(E.START_FEN) and not E.is_valid_fen("8/8/8 w") and not E.is_valid_fen("hello"), "FEN check")
	# Random games: every SAN reads back to the same move; PGN round trip.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var san_ok := true
	var pgn_ok := true
	for game in 12:
		e.reset()
		var sans: Array = []
		var ucis: Array = []
		for ply in 120:
			var all: Array = e.get_all_legal_moves(e.current_player)
			if all.is_empty() or e.game_over:
				break
			var pick: Dictionary = all[rng.randi() % all.size()]
			var promo: int = [E.QUEEN, E.KNIGHT, E.ROOK, E.BISHOP][rng.randi() % 4] if pick.move.promotes else E.QUEEN
			var s: String = e.san(pick.from, pick.move.to, promo)
			var back: Dictionary = e.move_from_san(s)
			if back.is_empty() or back.from != pick.from or back.to != pick.move.to or (pick.move.promotes and back.promo != promo):
				san_ok = false
				print("  SAN mismatch ", s)
			e.move(pick.from, pick.move.to, promo)
			sans.append(s + e.san_suffix())
			ucis.append(E.uci(pick.from, pick.move.to, promo if pick.move.promotes else 0))
			if e.game_over:
				break
		var pgn: String = E.make_pgn({"White": "A", "Black": "B"}, sans, e.result_token())
		var r: Dictionary = E.parse_pgn(pgn)
		if r.is_empty() or r.ucis != ucis or r.sans != sans or r.result != e.result_token() or r.error != "":
			pgn_ok = false
			print("  PGN mismatch in game ", game)
	check(san_ok, "SAN reads back for every random move")
	check(pgn_ok, "PGN round trip (12 random games)")
	var r2: Dictionary = E.parse_pgn("[Event \"x\"]\n\n1. e4 {best by test} e5 (1... c5) 2. Nf3 Nc6 3. Bb5 a6 1/2-1/2")
	check(r2.get("sans", []) == ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"] and r2.result == "1/2-1/2", "PGN with comments and variations")
	var r3: Dictionary = E.parse_pgn("1. e4 e5 2. Ke3")
	check(r3.get("error", "") == "Ke3" and r3.sans.size() == 2, "PGN stops at an illegal move")
	check(E.parse_pgn("nonsense").is_empty(), "no PGN in plain text")
	# From a FEN, Black to move first.
	var fen := "4k3/8/8/8/8/8/4P3/4K3 b - - 0 30"
	var pgn2: String = E.make_pgn({}, ["Kd7", "e4"], "*", fen)
	check("30... Kd7 31. e4" in pgn2 and "[FEN \"%s\"]" % fen in pgn2, "PGN from a FEN with Black first")
	var r4: Dictionary = E.parse_pgn(pgn2)
	check(r4.fen == fen and r4.sans == ["Kd7", "e4"], "PGN with FEN reads back")
	e.reset()
	e.resign(E.WHITE)
	check(e.game_over and e.winner == E.BLACK and e.result_token() == "0-1", "resign")
	e.reset()
	e.agree_draw()
	check(e.game_over and e.winner == 0 and e.result_token() == "1/2-1/2", "agreed draw")

func tap(sq: String) -> void:
	var v := E.square_from_name(sq)
	g._on_square_pressed(v.x, v.y)

func tap_move(u: String) -> void:
	var m := E.parse_uci(u)
	g._on_square_pressed(m.from.x, m.from.y)
	g._on_square_pressed(m.to.x, m.to.y)

func _run() -> void:
	_engine_tests()
	g = load("res://scenes/games/chess/chess.tscn").instantiate()
	root.add_child(g)
	await frames(3)
	g.progress.set_panel("takebacks", true)
	# One phone: a takeback undoes one move.
	g.home.start_mode({"action": g._new_two_player})
	await frames(2)
	tap_move("e2e4")
	tap_move("e7e5")
	check(g.ucis == ["e2e4", "e7e5"] and g.san_moves == ["e4", "e5"], "moves recorded as UCI")
	g._on_takeback()
	check(g.ucis == ["e2e4"] and g.engine.current_player == E.BLACK and g.takebacks_used == 1, "takeback on one phone: one move")
	# Second tap on the picked piece unpicks only when the finger lifts.
	tap("e7")
	tap("e7")
	check(g.selected == E.square_from_name("e7"), "still picked while pressed")
	var e7 := E.square_from_name("e7")
	g._on_square_released(e7.x, e7.y)
	check(g.selected == Vector2i(-1, -1), "unpicked on release")
	# Drag: pick, drop on a legal square.
	tap("e7")
	g._on_drag_dropped(e7, E.square_from_name("e5"))
	check(g.san_moves == ["e4", "e5"], "drag-to-move plays the move")
	tap("d1")
	g._on_drag_dropped(E.square_from_name("d1"), E.square_from_name("d5"))
	check(g.san_moves.size() == 2 and g.selected == E.square_from_name("d1"), "an illegal drop changes nothing")
	# Resign on one phone: the side to move gives up.
	g._on_resign()
	g._do_resign()
	check(g.engine.game_over and g.engine.winner == E.BLACK and not g.game_active, "resign")
	var last: Dictionary = Archive.load_all()[0]
	check(last.result == "0-1" and last.ucis == ["e2e4", "e7e5"], "game kept in My Games")
	var pos: Array = g._positions_for(last)
	check(pos.size() == 3 and pos[2].fen.begins_with("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w"), "replay positions")
	var by_san: Dictionary = last.duplicate()
	by_san.ucis = []
	check(g._positions_for(by_san).size() == 3, "replay from notation only")
	g._open_replay(last)
	g._replay_go(1000)
	check(g.rp.i == 2, "replay to the end")
	g._replay_go(-1)
	check(g.rp.i == 1, "replay one back")
	g.home._close_overlays()
	# Against the computer: a takeback undoes your move and its answer; no rating change.
	g.progress.set_clock_preset(4)  # 3+2
	g.home.start_mode({"action": g._new_vs_cpu.bind(0)})
	await frames(2)
	check(g.clock_limit == 180 and g.increment == 2, "3+2 clock")
	var before: float = g.clocks[E.WHITE]
	tap_move("e2e4")
	check(g.clocks[E.WHITE] > before + 1.0, "increment added after the move")
	for i in 300:
		if g.engine.current_player == E.WHITE and not g.cpu_busy:
			break
		await frames(1)
	check(g.ucis.size() == 2, "computer answered")
	g._on_takeback()
	check(g.ucis.is_empty() and g.engine.current_player == E.WHITE, "takeback vs computer: two moves")
	var rating: int = g.progress.rating()
	g._do_resign()
	check(g.progress.rating() == rating, "no rating change after a takeback")
	# Draw offer the computer turns down at the start.
	g.home.start_mode({"action": g._new_vs_cpu.bind(0)})
	await frames(2)
	g._on_draw()
	check(not g.engine.game_over, "computer declines an even draw at move 1")
	# Paste a FEN, play from it vs one phone.
	g._begin_fen("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1", -1)
	check(g.start_fen != "" and g.engine.board[6][4] == E.PAWN, "game from a FEN")
	tap_move("e2e4")
	g._on_takeback()
	check(g.engine.board[6][4] == E.PAWN and g.ucis.is_empty(), "takeback in a FEN game")
	g.progress.set_clock_preset(0)
	g.progress.set_panel("takebacks", true)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
