extends SceneTree

## Chess Phase B2 (2026-11-25), headless: 📮 Daily games against a fake
## server that follows supabase/migrations/20261126000000_chess_daily.sql
## (turn, move number, deadlines, draw offers). The player here is "me";
## the friend's moves are written straight into the fake rows.
##
##   godot --headless --path . --script res://tools/test_chess_daily.gd
##
## Touches the real stats and chess_games.json: back up
## %APPDATA%\Godot\app_userdata\Voodoo first.

const E = preload("res://scripts/games/chess/chess_engine.gd")

var fails := 0
var g: Node
var rows: Array = []
var next_id := 1
var offline := false
var calls: Array = []

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func row(id: int) -> Dictionary:
	for r in rows:
		if r.id == id:
			return r
	return {}

## The fake server: the same answers as the SQL functions.
func server(fn: String, a: Dictionary, done: Callable) -> void:
	calls.append(fn)
	if offline:
		done.call(false, null)
		return
	var me := "me"
	match fn:
		"chess_daily_list":
			var out: Array = []
			for r in rows:
				if r.status != "declined":
					out.append(r.duplicate(true))
			done.call(true, out)
		"chess_daily_challenge":
			if str(a.p_other) != "friend":
				done.call(true, -1)
				return
			rows.append(_new_row(next_id, "me", "friend", "me", "invited", int(a.p_days)))
			next_id += 1
			done.call(true, next_id - 1)
		"chess_daily_respond":
			var r := row(int(a.p_game))
			if r.is_empty() or r.status != "invited" or r.created_by == me:
				done.call(true, "no")
				return
			r.status = "active" if a.p_accept else "declined"
			done.call(true, "ok")
		"chess_daily_move":
			var r := row(int(a.p_game))
			if r.status != "active":
				done.call(true, "over")
				return
			if int(r.ply) != int(a.p_ply):
				done.call(true, "stale")
				return
			var to_move: String = r.white if int(r.ply) % 2 == 0 else r.black
			if to_move != me:
				done.call(true, "not_your_turn")
				return
			_append(r, str(a.p_uci), str(a.p_san))
			if str(a.p_result) != "*":
				r.status = "over"
				r.result = str(a.p_result)
				r.reason = str(a.p_reason)
			done.call(true, "ok")
		"chess_daily_resign":
			var r := row(int(a.p_game))
			r.status = "over"
			r.result = "0-1" if r.white == me else "1-0"
			r.reason = "resign"
			done.call(true, "ok")
		"chess_daily_draw":
			var r := row(int(a.p_game))
			if a.p_action == "offer" and r.draw_offer == null:
				r.draw_offer = me
			elif a.p_action == "accept" and r.draw_offer != null and r.draw_offer != me:
				r.status = "over"
				r.result = "1/2-1/2"
				r.reason = "draw_agreed"
				r.draw_offer = null
			elif a.p_action == "decline" and r.draw_offer != null and r.draw_offer != me:
				r.draw_offer = null
			else:
				done.call(true, "no")
				return
			done.call(true, "ok")
		"chess_daily_claim":
			var r := row(int(a.p_game))
			var to_move: String = r.white if int(r.ply) % 2 == 0 else r.black
			if r.status != "active" or to_move == me or r.deadline > r.now_at:
				done.call(true, "no")
				return
			r.status = "over"
			r.result = "1-0" if r.white == me else "0-1"
			r.reason = "timeout"
			done.call(true, "ok")

func _new_row(id: int, white: String, black: String, by: String, status: String, days: int) -> Dictionary:
	return {"id": id, "white": white, "black": black, "white_name": "Me" if white == "me" else "Pat",
		"black_name": "Me" if black == "me" else "Pat", "created_by": by, "status": status, "days": days,
		"moves": "", "sans": "", "ply": 0, "deadline": "2026-11-28T10:00:00", "result": "*", "reason": "",
		"draw_offer": null, "updated_at": "2026-11-25T10:00:00", "now_at": "2026-11-25T10:00:00"}

func _append(r: Dictionary, u: String, s: String) -> void:
	r.moves = (str(r.moves) + " " + u).strip_edges()
	r.sans = (str(r.sans) + " " + s).strip_edges()
	r.ply = int(r.ply) + 1
	r.draw_offer = null

func tap_move(u: String) -> void:
	var m := E.parse_uci(u)
	g._on_square_pressed(m.from.x, m.from.y)
	g._on_square_pressed(m.to.x, m.to.y)

func _run() -> void:
	g = load("res://scenes/games/chess/chess.tscn").instantiate()
	root.add_child(g)
	await frames(3)
	g.daily_backend = server
	# A challenge to a friend, answered by them.
	g._open_daily()
	await frames(1)
	g._send_challenge("friend", "Pat")
	check(rows.size() == 1 and rows[0].status == "invited", "challenge sent")
	g._send_challenge("stranger", "X")
	check(rows.size() == 1, "only friends can be challenged")
	rows[0].status = "active"
	# A challenge from them, which I accept (I'm Black there).
	rows.append(_new_row(next_id, "friend", "me", "friend", "invited", 3))
	next_id += 1
	g._daily_respond(2, true)
	check(row(2).status == "active", "accept a challenge")
	# Game 1: I'm White and it's my move.
	g._load_daily(row(1).duplicate(true))
	check(g._in_daily() and g.my_color == E.WHITE and not g.flipped and g.game_active, "Daily game on the board")
	tap_move("e2e4")
	check(row(1).ply == 1 and row(1).moves == "e2e4" and row(1).sans == "e4", "my move reached the server")
	tap_move("e7e5")
	check(g.engine.current_player == E.BLACK and row(1).ply == 1, "can't move for the opponent")
	# Their move arrives by polling.
	_append(row(1), "e7e5", "e5")
	g._daily_poll()
	check(g.san_moves == ["e4", "e5"] and g.engine.current_player == E.WHITE, "their move shows after a poll")
	# A stale move (the server moved on) puts the board back.
	_append(row(1), "g1f3", "Nf3")  # as if played on my other phone
	tap_move("d2d4")
	check(row(1).ply == 3 and g.ucis == ["e2e4", "e7e5", "g1f3"], "stale move refused, board reloaded")
	# No connection: the move is taken back.
	_append(row(1), "b8c6", "Nc6")
	g._daily_poll()
	offline = true
	tap_move("f1b5")
	check(g.ucis.size() == 4 and row(1).ply == 4, "offline move not kept")
	offline = false
	# Draw offered by them, declined here.
	row(1).draw_offer = "friend"
	g._daily_poll()
	check(g.result_dialog.visible, "their draw offer is asked")
	g._daily_draw("decline")
	check(row(1).draw_offer == null and not g.engine.game_over, "draw declined")
	# I resign.
	g._do_resign()
	check(row(1).status == "over" and row(1).result == "0-1" and g.engine.game_over, "resign on the server")
	# Game 2: I'm Black; they mate me (fool's mate) and it ends by poll.
	g._load_daily(row(2).duplicate(true))
	check(g.flipped and g.my_color == E.BLACK, "Black sees the board turned")
	_append(row(2), "f2f3", "f3")
	g._daily_poll()
	tap_move("e7e5")
	_append(row(2), "g2g4", "g4")
	g._daily_poll()
	tap_move("d8h4")
	check(row(2).status == "over" and row(2).result == "0-1" and g.engine.result_reason == "checkmate", "mate sent with the result")
	# A third game where their deadline passed: claim.
	rows.append(_new_row(next_id, "me", "friend", "me", "active", 1))
	next_id += 1
	_append(row(3), "e2e4", "e4")
	row(3).deadline = "2026-11-24T10:00:00"
	g._daily_claim(3)
	check(row(3).status == "over" and row(3).result == "1-0", "claim the win after their deadline")
	# The list shows sections.
	g._open_daily()
	await frames(2)
	check(g.daily_rows.size() == 3, "list loaded")
	var e: Dictionary = g._daily_entry(row(2))
	check(g._positions_for(e).size() == 5, "finished Daily game replays")
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
