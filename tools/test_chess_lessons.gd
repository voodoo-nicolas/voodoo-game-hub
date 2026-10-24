extends SceneTree

## Checks Chess's lessons and the engine's notation helpers, headless:
## every lesson board (and 400 days of daily lessons, mirrored ones too)
## sets up legally, its solution does what the board asks, a "collect"
## board's par is the fewest moves, mate-in-two boards have no mate in one,
## stalemate boards really hold a stalemate trap. Then SAN, FEN, the
## captured-pieces count, the clock rule and the progress file's sums.
##
##   godot --headless --path . --script res://tools/test_chess_lessons.gd
##
## Touches no saves (the progress test uses its own scratch file).

const Engine2 = preload("res://scripts/games/chess/chess_engine.gd")
const Lessons = preload("res://scripts/games/chess/chess_lessons.gd")
const Progress = preload("res://scripts/games/chess/chess_progress.gd")

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL " + what)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var n := 0
	for e in Lessons.all_lessons():
		var l: Dictionary = e.lesson
		check(l.has("intro") and l.has("title"), l.id + ": title and intro")
		for i in l.boards.size():
			_check_board(l.boards[i], "%s #%d" % [l.id, i + 1])
			n += 1
	print("lesson boards: %d" % n)
	check(n == Lessons.board_count(), "board_count")
	var seen := {}
	for day in range(20000, 20400):
		var picks: Array = Lessons.daily_boards(day)
		check(picks.size() == 3, "daily %d has 3 boards" % day)
		for b in picks:
			seen[b.fen] = true
			_check_board(b, "daily %d %s" % [day, b.fen])
	print("different daily boards over 400 days: %d" % seen.size())
	check(seen.size() >= 30, "daily lessons vary")
	_check_notation()
	_check_progress()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _check_board(b: Dictionary, what: String) -> void:
	var e = Engine2.new()
	e.load_fen(b.fen)
	check(e.current_player == Engine2.WHITE, what + ": White to move")
	check(not e.is_in_check(Engine2.BLACK), what + ": Black not in check at the start")
	var goal: String = b.goal
	check(goal == "escape" or not e.is_in_check(Engine2.WHITE), what + ": White not in check unless escaping")
	check(str(b.get("text", "")) != "", what + ": has a task")
	for u in b.get("solution", []):
		check(Engine2.parse_uci(u).size() == 3, what + ": solution " + u + " parses")
	match goal:
		"collect":
			var stars: Array = b.get("stars", [])
			var path: Array = Lessons.collect_solution(e, stars, 8)
			check(not path.is_empty(), what + ": can be finished")
			check(path.size() == int(b.par), what + ": par %d = fewest moves %d" % [int(b.par), path.size()])
		"move":
			check(not b.solution.is_empty() and b.has("why"), what + ": solution and why")
			for u in b.solution:
				var m := Engine2.parse_uci(u)
				var res: Dictionary = e.clone().move(m.from, m.to, m.promo if m.promo > 0 else Engine2.QUEEN)
				check(res.get("valid", false), what + ": " + u + " is legal")
		"check":
			var m := Engine2.parse_uci(b.solution[0])
			var c = e.clone()
			check(c.move(m.from, m.to).get("valid", false) and c.is_in_check(Engine2.BLACK), what + ": hint gives check")
		"escape":
			check(e.is_in_check(Engine2.WHITE), what + ": White starts in check")
			var m := Engine2.parse_uci(b.solution[0])
			var piece: int = e.board[m.from.x][m.from.y]
			var target: int = e.board[m.to.x][m.to.y]
			var c = e.clone()
			check(c.move(m.from, m.to).get("valid", false), what + ": hint is legal")
			match str(b.by):
				"king":
					check(absi(piece) == Engine2.KING, what + ": hint moves the king")
				"capture":
					check(target < 0, what + ": hint captures")
				"block":
					check(absi(piece) != Engine2.KING and target == 0, what + ": hint blocks")
		"mate1":
			var mates: Array = e.mates_in_one()
			check(not mates.is_empty(), what + ": has a mate in one")
			var m := Engine2.parse_uci(b.solution[0])
			var c = e.clone()
			var res: Dictionary = c.move(m.from, m.to)
			check(res.get("result_reason", "") == "checkmate", what + ": hint mates")
			if what.begins_with("stalemate"):
				var traps := 0
				for mv in e.get_all_legal_moves(Engine2.WHITE):
					var c2 = e.clone()
					if c2.move(mv.from, mv.move.to).get("result_reason", "") == "stalemate":
						traps += 1
				check(traps > 0, what + ": has a stalemate trap")
		"mate2":
			check(e.mates_in_one().is_empty(), what + ": no mate in one")
			var m := Engine2.parse_uci(b.solution[0])
			check(e.forces_mate_in_two(m.from, m.to), what + ": first hint forces mate in two")
			var c = e.clone()
			c.move(m.from, m.to)
			# Black's most stubborn reply, then the second hint or another mate.
			var any_mate := true
			for reply in c.get_all_legal_moves(Engine2.BLACK):
				var c2 = c.clone()
				c2.move(reply.from, reply.move.to)
				if c2.mates_in_one().is_empty():
					any_mate = false
			check(any_mate, what + ": every reply allows mate")
		_:
			check(false, what + ": unknown goal " + goal)

func _check_notation() -> void:
	var e = Engine2.new()
	e.reset()
	var line := ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5c6", "d7c6", "e1g1"]
	var want := ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Bxc6", "dxc6", "O-O"]
	for i in line.size():
		var m := Engine2.parse_uci(line[i])
		var s: String = e.san(m.from, m.to)
		e.move(m.from, m.to)
		s += e.san_suffix()
		check(s == want[i], "SAN %s = %s (got %s)" % [line[i], want[i], s])
	check(e.lost_pieces(Engine2.WHITE) == [Engine2.BISHOP], "White lost a bishop")
	check(e.lost_pieces(Engine2.BLACK) == [Engine2.KNIGHT], "Black lost a knight")
	check(e.material(Engine2.WHITE) == e.material(Engine2.BLACK), "material level after the trade")
	# Disambiguation, promotion, check and mate signs.
	e.load_fen("4k3/1P6/8/8/8/8/4K3/R6R w - - 0 1")
	check(e.san(Vector2i(7, 0), Vector2i(7, 3)) == "Rad1", "SAN Rad1")
	check(e.san(Vector2i(7, 7), Vector2i(7, 5)) == "Rhf1", "SAN Rhf1")
	check(e.san(Vector2i(1, 1), Vector2i(0, 1), Engine2.QUEEN) == "b8=Q", "SAN b8=Q")
	e.move(Vector2i(1, 1), Vector2i(0, 1), Engine2.QUEEN)
	check(e.san_suffix() == "+", "b8=Q gives check")
	e.load_fen("6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1")
	check(e.san(Vector2i(7, 0), Vector2i(0, 0)) == "Ra8", "SAN Ra8")
	e.move(Vector2i(7, 0), Vector2i(0, 0))
	check(e.san_suffix() == "#", "Ra8 is mate")
	# En passant from FEN.
	e.load_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	check(e.san(Vector2i(3, 4), Vector2i(2, 3)) == "exd6", "SAN exd6 en passant")
	# Promotion counts as a pawn gone, not a captured piece.
	e.load_fen("QQ2k3/8/8/8/8/8/PPPPPP2/RNBQKBNR w - - 0 1")
	check(e.lost_pieces(Engine2.WHITE) == [], "promoted pawns aren't captures (got %s)" % str(e.lost_pieces(Engine2.WHITE)))
	# Clock: out of time against a lone king is a draw.
	e.load_fen("4k3/8/8/8/8/8/8/R3K3 w - - 0 1")
	e.flag_fall(Engine2.BLACK)
	check(e.result_reason == "timeout" and e.winner == Engine2.WHITE, "Black's flag falls: White wins")
	e.load_fen("4k3/8/8/8/8/8/8/R3K3 w - - 0 1")
	e.flag_fall(Engine2.WHITE)
	check(e.result_reason == "draw_timeout", "White's flag falls, Black has a lone king: draw")
	# Evaluation: a queen up is a big plus for White; a mate in one shows.
	e.load_fen("4k3/8/8/8/8/8/8/3QK3 w - - 0 1")
	check(float(e.evaluation(400).score) > 5.0, "a queen up evaluates well for White")
	e.load_fen("6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1")
	check(int(e.evaluation(400).mate) == 1, "the evaluation sees White's mate in one")

func _check_progress() -> void:
	var tmp := "user://test_chess_progress.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	var p = Progress.new(tmp)
	var before: int = p.rating()
	check(before == Progress.START_RATING, "starting rating")
	check(p.panel_on("eval"), "panels default on")
	# Expected-score maths: beating an equal opponent gains K/2.
	p.data["rating"] = 1200
	check(p.rate(1, 1.0) == 16, "win vs equal rating = +16")
	check(Progress.rank_name(1250) == "Club player", "rank name")
	p.data["points"] = 100
	check(not p.buy("board", "walnut"), "can't buy what costs more than you have")
	check(p.buy("board", "tournament") and p.points() == 20 and p.board_id() == "tournament", "buy and equip")
	check(p.finish_daily() == Progress.POINTS_DAILY and p.daily_streak() == 1 and p.finish_daily() == 0, "daily once a day")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
