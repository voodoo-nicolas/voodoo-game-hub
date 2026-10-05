extends SceneTree

## Plays whole online games between two copies of a game in one process,
## joined by a fake session that hands each message to the other copy
## (through a JSON round trip, as the network does). After every action it
## checks both copies hold the same game, and at the end that both saw it end.
##   godot --headless --path . --script res://tools/test_online_pair.gd -- [ids]
## Ids: morris backgammon memory five_in_row hex video_poker (default: all). Records online results in
## the stats files: back up user data first (see CLAUDE.md).

const SCENES := {
	"morris": "res://scenes/games/morris/morris.tscn",
	"backgammon": "res://scenes/games/backgammon/backgammon.tscn",
	"memory": "res://scenes/games/memory/memory.tscn",
	"five_in_row": "res://scenes/games/five_in_row/five_in_row.tscn",
	"hex": "res://scenes/games/hex/hex.tscn",
	"video_poker": "res://scenes/games/video_poker/video_poker.tscn",
}
const GAMES_EACH := 3

## Stands in for OnlineSession: send() delivers to the peer next frame.
class FakeSession extends Node:
	signal opponent_joined()
	signal opponent_left()
	signal message(event: String, payload: Dictionary)
	signal connection_changed(connected: bool)
	var peer: FakeSession
	var code := "TEST"
	var my_id := ""
	var my_name := ""
	var opponent_name := ""
	var sent := 0
	func send(event: String, payload: Dictionary = {}) -> void:
		sent += 1
		var copy: Dictionary = JSON.parse_string(JSON.stringify(payload))
		peer.call_deferred("_deliver", event, copy)
	func _deliver(event: String, payload: Dictionary) -> void:
		message.emit(event, payload)

var fails := 0

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _run() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = SCENES.keys()
	for id in ids:
		await _test_game(id)
	print("ONLINE PAIR TEST: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _test_game(id: String) -> void:
	var host: Node = load(SCENES[id]).instantiate()
	var guest: Node = load(SCENES[id]).instantiate()
	root.add_child(host)
	root.add_child(guest)
	await _frames(3)
	for g in [host, guest]:
		if g.info:
			g.info.close()
	var sh := FakeSession.new()
	var sg := FakeSession.new()
	sh.my_name = "Host"
	sh.opponent_name = "Guest"
	sg.my_name = "Guest"
	sg.opponent_name = "Host"
	sh.peer = sg
	sg.peer = sh
	root.add_child(sh)
	root.add_child(sg)
	host.online._on_lobby_started(sh, 1)
	guest.online._on_lobby_started(sg, 2)
	paused = false
	await _frames(3)
	ok(_same(host, guest), "%s: same game after the start sync" % id)
	for n in GAMES_EACH:
		var actions := await _play(id, host, guest)
		await _frames(3)
		ok(_same(host, guest), "%s game %d: same final state" % [id, n + 1])
		ok(_ended(id, host) and _ended(id, guest), "%s game %d: both saw the end (%d actions)" % [id, n + 1, actions])
		# Alternate who asks for the rematch; the other copy follows.
		var asker: Node = guest if n % 2 == 0 else host
		asker._start_new_game()
		await _frames(4)
		ok(_same(host, guest) and not _ended(id, host) and not _ended(id, guest),
			"%s game %d: rematch asked by the %s starts on both" % [id, n + 2, "guest" if asker == guest else "host"])
	print("%s: %d + %d messages" % [id, sh.sent, sg.sent])
	for n in [host, guest, sh, sg]:
		n.queue_free()
	await _frames(2)

func _same(a: Node, b: Node) -> bool:
	var sa := JSON.stringify(a._online_state())
	var sb := JSON.stringify(b._online_state())
	if sa != sb:
		print("  host:  ", sa, "\n  guest: ", sb)
	return sa == sb

func _ended(id: String, g: Node) -> bool:
	match id:
		"morris":
			return g.engine.winner != 0 and g.end_dialog.visible
		"backgammon":
			return g.BgEngine.winner(g.engine.state) != -1 and g.end_dialog.visible
		"memory":
			return g.engine.is_over() and g.win_dialog.visible
		"five_in_row", "hex":
			return g.engine.winner != 0 and g.end_dialog.visible
		"video_poker":
			return g.end_dialog.visible
	return false

## Random legal play until the game ends; returns the number of actions.
func _play(id: String, host: Node, guest: Node) -> int:
	var actions := 0
	var deadline := Time.get_ticks_msec() + 120000
	for step in 1000000:
		if _ended(id, host) or Time.get_ticks_msec() > deadline:
			break
		var actor: Node = null
		for g in [host, guest]:
			if _can_act(id, g):
				actor = g
		if actor == null:
			await _frames(1)
			continue
		var other: Node = guest if actor == host else host
		ok(not _can_act(id, other), "%s: only one player may act (step %d)" % [id, step])
		_act(id, actor)
		actions += 1
		await _frames(2)
		if _settled(id, host) and _settled(id, guest) and not _same(host, guest):
			ok(false, "%s: states differ after action %d" % [id, actions])
			return actions
	ok(_ended(id, host), "%s: game didn't end" % id)
	return actions

func _can_act(id: String, g: Node) -> bool:
	match id:
		"morris":
			return g.engine.winner == 0 and g._my_turn()
		"backgammon":
			return g.turn >= 0 and g._is_person_turn() and (g.dice.is_empty() or not g.legal.is_empty())
		"memory":
			return g.game_active and not g.waiting_for_resolve and g.online.can_act(g.turn_player + 1 == g.my_player)
		"five_in_row", "hex":
			return g.engine.winner == 0 and g.online.can_act(g.engine.turn == g.my_player)
		"video_poker":
			# The host also deals the next hand (instead of waiting its timer).
			return g._hero_can_act() or (g.online.is_host() and g.t.phase == "done" and not g.end_dialog.visible)
	return false

## No half-made turn (Morris waiting for a removal).
func _settled(id: String, g: Node) -> bool:
	return not (id == "morris" and g.must_remove)

func _act(id: String, g: Node) -> void:
	match id:
		"morris":
			var e = g.engine
			if g.must_remove:
				_click(g, e.removable(3 - e.turn).pick_random())
				return
			var m: Array = e.moves_for(e.turn).pick_random()
			if m[0] >= 0:
				_click(g, m[0])
			_click(g, m[1])
		"backgammon":
			if g.dice.is_empty():
				g._on_roll()
			else:
				g._do_human_move(g.legal.pick_random())
		"memory":
			var choices: Array = []
			for i in g.engine.deck.size():
				if not g.engine.matched[i] and not g.engine.flipped.has(i):
					choices.append(i)
			g._on_cell_pressed(choices.pick_random())
		"five_in_row":
			var i: int = g.engine.candidates().pick_random()
			var geo: Dictionary = g._geom()
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = geo.origin + Vector2(i % 15, i / 15) * geo.step
			g._on_board_input(ev)
		"video_poker":
			if g.t.phase == "done":
				g._on_next()
			elif g.t.phase == "draw":
				g.discards = [0, 1, 2].slice(0, randi_range(0, 3))
				g._on_call()
			else:
				var r := randf()
				if r < 0.15 and g.fold_btn.visible:
					g._on_fold()
				elif r < 0.7 or not g.raise_btn.visible:
					g._on_call()
				else:
					g._size_preset(["min", "half", "pot", "all"].pick_random())
					g._on_raise()
		"hex":
			var free: Array = []
			for k in g.engine.board.size():
				if g.engine.board[k] == 0:
					free.append(k)
			var ev2 := InputEventMouseButton.new()
			ev2.button_index = MOUSE_BUTTON_LEFT
			ev2.pressed = true
			ev2.position = g._center(free.pick_random(), g._geom())
			g._on_board_input(ev2)

func _click(g: Node, point: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = g._point_pos(point, g._geom())
	g._on_board_input(ev)
