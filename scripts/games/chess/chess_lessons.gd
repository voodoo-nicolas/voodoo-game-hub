extends RefCounted

## The lessons: short boards set up to teach one thing each, grouped by
## category (how each piece plays, the rules, checkmate). Strings are
## English; es.json translates them. tools/test_chess_lessons.gd checks
## every board (legal set-up, the solution works, the par is the fewest moves).
##
## A board: "fen" (White always moves; Black only answers in "mate2") and a "goal":
##   "collect" -- capture every black piece and step on every star ("stars");
##                Black never moves. "par" = fewest moves (full points).
##   "move"    -- play one of the moves in "solution" (UCI: "e2e4", "e7e8n").
##   "check"   -- give check with any move.
##   "escape"  -- get out of check the way "by" says: "king", "block", "capture".
##   "mate1"   -- checkmate in one (any mate counts).
##   "mate2"   -- force checkmate in two moves (any forcing move counts).
## "text" = the task, "why" = shown once it's solved, "solution" = the hint.

const CATEGORIES := [
	{"id": "pieces", "icon": "♞", "title": "How each piece plays", "lessons": [
		{"id": "rook", "piece": 4, "title": "The Rook",
			"intro": "The rook moves in straight lines: up, down, left or right, as far as it likes. It can't jump over pieces.",
			"boards": [
				{"fen": "8/8/8/8/8/8/8/R7 w - - 0 1", "goal": "collect", "stars": ["a6", "f6", "f1"], "par": 3,
					"text": "Collect all the stars."},
				{"fen": "8/8/3p2p1/8/8/8/6p1/3R4 w - - 0 1", "goal": "collect", "par": 3,
					"text": "Capture all the black pieces."},
				{"fen": "4q3/8/8/8/4k3/8/8/1R5K w - - 0 1", "goal": "move", "solution": ["b1e1"],
					"text": "Win the queen: check the king along a line with the queen behind it.",
					"why": "A skewer! The king has to step aside, and the rook takes the queen behind it."},
			]},
		{"id": "bishop", "piece": 3, "title": "The Bishop",
			"intro": "The bishop moves diagonally, as far as it likes. It stays on squares of one colour all game.",
			"boards": [
				{"fen": "8/8/8/8/8/8/8/2B5 w - - 0 1", "goal": "collect", "stars": ["f4", "c7", "a5"], "par": 3,
					"text": "Collect all the stars."},
				{"fen": "8/3p4/8/1p6/p7/8/8/5B2 w - - 0 1", "goal": "collect", "par": 3,
					"text": "Capture all the black pieces."},
				{"fen": "6r1/8/8/3k4/8/8/7K/1B6 w - - 0 1", "goal": "move", "solution": ["b1a2"],
					"text": "Check the king so that the rook behind it falls next.",
					"why": "A skewer on the diagonal: the king moves away and the bishop takes the rook."},
			]},
		{"id": "queen", "piece": 5, "title": "The Queen",
			"intro": "The queen moves like a rook and a bishop together: any straight line or diagonal. She's your strongest piece.",
			"boards": [
				{"fen": "8/8/8/8/8/8/8/3Q4 w - - 0 1", "goal": "collect", "stars": ["d5", "a8", "h1"], "par": 3,
					"text": "Collect all the stars."},
				{"fen": "n7/8/8/8/p7/8/8/3Q3n w - - 0 1", "goal": "collect", "par": 3,
					"text": "Capture all the black pieces."},
				{"fen": "r5k1/6pp/8/8/8/8/5PPP/3Q2K1 w - - 0 1", "goal": "move", "solution": ["d1d5"],
					"text": "Attack the king and the rook with one move.",
					"why": "A fork: the queen checks the king and hits the rook. After the king moves, the rook is yours."},
			]},
		{"id": "knight", "piece": 2, "title": "The Knight",
			"intro": "The knight jumps in an L: two squares one way, then one to the side. It's the only piece that jumps over others.",
			"boards": [
				{"fen": "8/8/8/8/8/8/8/1N6 w - - 0 1", "goal": "collect", "stars": ["c3", "e4", "f6"], "par": 3,
					"text": "Collect all the stars."},
				{"fen": "8/8/2p5/4p3/8/5p2/8/6N1 w - - 0 1", "goal": "collect", "par": 3,
					"text": "Capture all the black pieces."},
				{"fen": "r3k3/pp3ppp/8/1N6/8/8/5PPP/6K1 w - - 0 1", "goal": "move", "solution": ["b5c7"],
					"text": "Find the knight fork: check the king and attack the rook.",
					"why": "Knights are the kings of forks: nothing can block a knight's check."},
			]},
		{"id": "pawn", "piece": 1, "title": "The Pawn",
			"intro": "A pawn moves straight ahead one square (two on its first move), but captures one square diagonally forward. It never moves back.",
			"boards": [
				{"fen": "8/8/8/8/8/8/4P3/8 w - - 0 1", "goal": "collect", "stars": ["e5"], "par": 2,
					"text": "Collect the star."},
				{"fen": "8/8/8/2p5/3p4/4p3/3P4/8 w - - 0 1", "goal": "collect", "par": 3,
					"text": "Capture all the black pieces."},
				{"fen": "6k1/8/3n1n2/8/4P3/8/8/6K1 w - - 0 1", "goal": "move", "solution": ["e4e5"],
					"text": "Attack both knights with one pawn move.",
					"why": "A pawn fork: one of the knights is lost, and a pawn is worth much less."},
			]},
		{"id": "king", "piece": 6, "title": "The King",
			"intro": "The king moves one square any way. It may never step onto a square that is attacked, not even to capture.",
			"boards": [
				{"fen": "8/8/8/8/8/8/8/4K3 w - - 0 1", "goal": "collect", "stars": ["e2", "f3", "g2"], "par": 3,
					"text": "Collect all the stars."},
				{"fen": "8/8/8/4p3/3p4/8/5K2/8 w - - 0 1", "goal": "collect", "par": 4,
					"text": "Capture both pawns. Take the one that guards the other first."},
			]},
	]},
	{"id": "rules", "icon": "📜", "title": "The rules", "lessons": [
		{"id": "check", "title": "Check",
			"intro": "Check: the king is attacked. The side in check must get out of it at once: move the king, block the attack, or capture the attacker.",
			"boards": [
				{"fen": "4k3/8/8/8/8/8/8/R6K w - - 0 1", "goal": "check", "solution": ["a1a8"],
					"text": "Give check: attack the black king."},
				{"fen": "4r1k1/8/8/8/8/8/8/4K3 w - - 0 1", "goal": "escape", "by": "king", "solution": ["e1d2"],
					"text": "You're in check! Move your king out of the attack."},
				{"fen": "4r1k1/8/8/8/8/8/8/4KB2 w - - 0 1", "goal": "escape", "by": "block", "solution": ["f1e2"],
					"text": "You're in check! Block the attack with a piece."},
				{"fen": "R3r1k1/8/8/8/8/8/8/4K3 w - - 0 1", "goal": "escape", "by": "capture", "solution": ["a8e8"],
					"text": "You're in check! Capture the piece that gives check."},
			]},
		{"id": "castling", "title": "Castling",
			"intro": "Castling: the king moves two squares toward a rook, and the rook jumps to the king's other side. Only if neither has moved, nothing stands between them, and the king isn't in check, doesn't cross an attacked square and doesn't land on one.",
			"boards": [
				{"fen": "4k3/8/8/8/8/8/5PPP/4K2R w K - 0 1", "goal": "move", "solution": ["e1g1"],
					"text": "Castle on the king's side: move the king two squares toward the rook.",
					"why": "Castled! The king is tucked away and the rook joins the game."},
				{"fen": "4k3/8/8/8/8/8/PPP5/R3K3 w Q - 0 1", "goal": "move", "solution": ["e1c1"],
					"text": "Castle on the queen's side: the king goes two squares to the left.",
					"why": "Queenside castling: the rook lands right beside the king."},
				{"fen": "4k3/8/8/8/2b5/8/PPP2PPP/R3K2R w KQ - 0 1", "goal": "move", "solution": ["e1c1"],
					"text": "The bishop attacks f1, so the king can't castle to the right. Castle the other way.",
					"why": "The king may not pass over an attacked square, but it can castle on the safe side."},
			]},
		{"id": "en_passant", "title": "En passant",
			"intro": "En passant: when a pawn moves two squares and lands right beside your pawn, your pawn can capture it as if it had moved only one. Only on the very next move.",
			"boards": [
				{"fen": "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1", "goal": "move", "solution": ["e5d6"],
					"text": "Black's pawn just jumped two squares past yours. Capture it en passant.",
					"why": "Your pawn lands on the square the black pawn skipped, and the black pawn is gone."},
				{"fen": "4k3/8/8/1Pp5/8/8/8/4K3 w - c6 0 1", "goal": "move", "solution": ["b5c6"],
					"text": "Same again: capture the pawn that just moved past.",
					"why": "Wait one move and the chance is gone for good."},
			]},
		{"id": "promotion", "title": "Promotion",
			"intro": "A pawn that reaches the far row turns into a queen, rook, bishop or knight: your choice.",
			"boards": [
				{"fen": "4k3/1P6/8/8/8/8/8/4K3 w - - 0 1", "goal": "move", "solution": ["b7b8q"],
					"text": "Promote your pawn to a queen.",
					"why": "A new queen, and it gives check too!"},
				{"fen": "8/1k1P1q2/8/8/8/8/8/7K w - - 0 1", "goal": "move", "solution": ["d7d8n"],
					"text": "A queen isn't always best: promote to the piece that checks the king and attacks the queen.",
					"why": "A knight fork straight from promotion. Next move the queen falls."},
			]},
		{"id": "stalemate", "title": "Stalemate",
			"intro": "Stalemate: the side to move has no legal move but isn't in check. The game is a draw! When you're winning, always leave the enemy king a move.",
			"boards": [
				{"fen": "k7/2K5/8/1Q6/8/8/8/8 w - - 0 1", "goal": "mate1", "solution": ["b5b7"],
					"text": "Checkmate in one, and watch out: some moves leave Black no move at all."},
				{"fen": "7k/8/6K1/8/8/8/8/5Q2 w - - 0 1", "goal": "mate1", "solution": ["f1f8"],
					"text": "Checkmate in one without stalemating the king."},
			]},
	]},
	{"id": "mate", "icon": "♚", "title": "Checkmate", "lessons": [
		{"id": "back_rank", "title": "Back-rank mate",
			"intro": "Checkmate: the king is in check and nothing can save it. A king stuck behind its own pawns is easy prey on the back row.",
			"boards": [
				{"fen": "6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1", "goal": "mate1", "solution": ["a1a8"],
					"text": "Checkmate in one."},
				{"fen": "7k/6pp/8/8/8/8/6PP/1Q4K1 w - - 0 1", "goal": "mate1", "solution": ["b1b8"],
					"text": "Checkmate in one."},
				{"fen": "2r3k1/5ppp/8/8/8/8/5PPP/2R3K1 w - - 0 1", "goal": "mate1", "solution": ["c1c8"],
					"text": "Checkmate in one: the black rook guards the back row. Remove it."},
			]},
		{"id": "queen_mate", "title": "Queen and king",
			"intro": "The queen mates best with her king nearby: the king guards the squares the queen can't, or protects her right next to the enemy king.",
			"boards": [
				{"fen": "4k3/8/4K3/8/8/8/8/7Q w - - 0 1", "goal": "mate1", "solution": ["h1h8"],
					"text": "Checkmate in one."},
				{"fen": "7k/Q7/6K1/8/8/8/8/8 w - - 0 1", "goal": "mate1", "solution": ["a7g7"],
					"text": "Checkmate in one: the king protects the queen."},
				{"fen": "1k6/7Q/1K6/8/8/8/8/8 w - - 0 1", "goal": "mate1", "solution": ["h7b7"],
					"text": "Checkmate in one."},
			]},
		{"id": "two_rooks", "title": "Two rooks",
			"intro": "Two rooks mate like a ladder: one cuts the king off from a row, the other gives check along the edge.",
			"boards": [
				{"fen": "4k3/R7/8/8/8/8/8/1R4K1 w - - 0 1", "goal": "mate1", "solution": ["b1b8"],
					"text": "Checkmate in one."},
				{"fen": "1R6/8/8/8/k7/6K1/8/7R w - - 0 1", "goal": "mate1", "solution": ["h1a1"],
					"text": "Checkmate in one: this time the king is on the side edge."},
			]},
		{"id": "knight_mate", "title": "Knight mates",
			"intro": "A knight can check a king that is boxed in by its own pieces. Nothing can block a knight.",
			"boards": [
				{"fen": "6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1", "goal": "mate1", "solution": ["g5f7"],
					"text": "Smothered mate: checkmate in one with the knight."},
				{"fen": "7k/1R6/5N2/8/8/8/8/6K1 w - - 0 1", "goal": "mate1", "solution": ["b7h7"],
					"text": "Checkmate in one: the knight guards your rook."},
			]},
		{"id": "mate_in_two", "title": "Mate in two",
			"intro": "Mate in two: your first move forces the reply, your second move mates. Look for checks first.",
			"boards": [
				{"fen": "r5k1/5ppp/8/8/8/8/4RPPP/4R1K1 w - - 0 1", "goal": "mate2", "solution": ["e2e8", "e1e8"],
					"text": "Checkmate in two moves."},
				{"fen": "7k/8/8/8/8/8/1R6/R5K1 w - - 0 1", "goal": "mate2", "solution": ["a1a7", "b2b8"],
					"text": "Checkmate in two moves: the first one is quiet."},
				{"fen": "5r1k/6pp/7N/3Q4/8/8/6PP/6K1 w - - 0 1", "goal": "mate2", "solution": ["d5g8", "h6f7"],
					"text": "Checkmate in two moves: give up your queen!"},
			]},
	]},
]

## Every lesson in order, each with its category: [{cat, lesson}].
static func all_lessons() -> Array:
	var out: Array = []
	for cat in CATEGORIES:
		for l in cat.lessons:
			out.append({"cat": cat, "lesson": l})
	return out

static func find(lesson_id: String) -> Dictionary:
	for e in all_lessons():
		if e.lesson.id == lesson_id:
			return e.lesson
	return {}

## The lesson after this one ({} after the last).
static func next_lesson(lesson_id: String) -> Dictionary:
	var list := all_lessons()
	for i in list.size():
		if list[i].lesson.id == lesson_id and i + 1 < list.size():
			return list[i + 1].lesson
	return {}

static func board_key(lesson_id: String, i: int) -> String:
	return "%s_%d" % [lesson_id, i + 1]

static func board_count() -> int:
	var n := 0
	for e in all_lessons():
		n += e.lesson.boards.size()
	return n

# ---------- "collect" boards ----------

## Every black piece captured and every star stepped on?
static func collect_done(board: Array, stars_left: Array) -> bool:
	if not stars_left.is_empty():
		return false
	for row in board:
		for v in row:
			if v < 0:
				return false
	return true

## The fewest White moves that finish a "collect" board from where `engine`
## stands now (Black never moves), as UCI moves; [] if none within
## `max_moves`. For the 💡 hint and the test. Leaves the engine as it was.
static func collect_solution(engine, stars_left: Array, max_moves: int = 6) -> Array:
	var start_board: Array = _copy(engine.board)
	var saved_player: int = engine.current_player
	var saved_rights: Dictionary = engine.castling_rights.duplicate()
	var saved_ep: Vector2i = engine.en_passant_target
	var queue: Array = [{"board": start_board, "stars": stars_left.duplicate(), "path": []}]
	var seen := {str(start_board) + str(stars_left): true}
	var found: Array = []
	if collect_done(start_board, stars_left):
		queue = []
	while not queue.is_empty() and found.is_empty():
		var node: Dictionary = queue.pop_front()
		if node.path.size() >= max_moves:
			continue
		engine.board = _copy(node.board)
		engine.current_player = 1
		engine.castling_rights = {"K": false, "Q": false, "k": false, "q": false}
		engine.en_passant_target = Vector2i(-1, -1)
		for m in engine.get_all_legal_moves(1):
			var rec: Dictionary = engine._make_move_raw(m.from, m.move, 5)
			var after: Array = _copy(engine.board)
			engine._unmake_move_raw(rec)
			var stars: Array = node.stars.duplicate()
			stars.erase(engine.square_name(m.move.to))
			var path: Array = node.path.duplicate()
			path.append(engine.uci(m.from, m.move.to))
			if collect_done(after, stars):
				found = path
				break
			var key := str(after) + str(stars)
			if not seen.has(key):
				seen[key] = true
				queue.append({"board": after, "stars": stars, "path": path})
	engine.board = start_board
	engine.current_player = saved_player
	engine.castling_rights = saved_rights
	engine.en_passant_target = saved_ep
	return found

static func _copy(board: Array) -> Array:
	var out: Array = []
	for row in board:
		out.append(row.duplicate())
	return out

# ---------- the daily lesson ----------

## Today's three boards: a tactic, a mate in one, and a mate in two on odd
## days (a second mate in one on even days). On about half the days they
## are mirrored left to right, so a board seen before looks new. The same
## for everyone on the same date.
static func daily_boards(day: int) -> Array:
	var tactics: Array = []
	var mate1: Array = []
	var mate2: Array = []
	for e in all_lessons():
		for b in e.lesson.boards:
			if b.fen.split(" ")[2] != "-":
				continue  # castling boards don't mirror
			match str(b.goal):
				"move":
					tactics.append(b)
				"mate1":
					mate1.append(b)
				"mate2":
					mate2.append(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chess-daily-%d" % day)
	var picks: Array = [tactics[rng.randi() % tactics.size()]]
	var m1: int = rng.randi() % mate1.size()
	picks.append(mate1[m1])
	if day % 2 == 1:
		picks.append(mate2[rng.randi() % mate2.size()])
	else:
		picks.append(mate1[(m1 + 1 + rng.randi() % (mate1.size() - 1)) % mate1.size()])
	if rng.randi() % 2 == 0:
		for i in picks.size():
			picks[i] = mirrored(picks[i])
	return picks

## The same board seen in a mirror (a-file <-> h-file). Only for boards
## without castling rights.
static func mirrored(b: Dictionary) -> Dictionary:
	var out := b.duplicate(true)
	var parts: PackedStringArray = str(b.fen).split(" ")
	var ranks: PackedStringArray = parts[0].split("/")
	for i in ranks.size():
		var cells := ""
		for ch in ranks[i]:
			cells += "1".repeat(int(ch)) if ch.is_valid_int() else ch
		cells = cells.reverse()
		var packed := ""
		var run := 0
		for ch in cells:
			if ch == "1":
				run += 1
			else:
				if run > 0:
					packed += str(run)
					run = 0
				packed += ch
		if run > 0:
			packed += str(run)
		ranks[i] = packed
	parts[0] = "/".join(ranks)
	if parts.size() > 3 and parts[3] != "-":
		parts[3] = _mirror_square(parts[3])
	out["fen"] = " ".join(parts)
	if b.has("solution"):
		var sol: Array = []
		for u in b.solution:
			sol.append(_mirror_square(u.substr(0, 2)) + _mirror_square(u.substr(2, 2)) + u.substr(4))
		out["solution"] = sol
	if b.has("stars"):
		var stars: Array = []
		for s in b.stars:
			stars.append(_mirror_square(s))
		out["stars"] = stars
	return out

static func _mirror_square(s: String) -> String:
	return "hgfedcba"["abcdefgh".find(s[0])] + s.substr(1)
