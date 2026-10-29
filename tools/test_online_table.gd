extends SceneTree

## Friends tables (OnlineRoom / OnlineTable / the table lobby) without the
## network: a fake Realtime server hands each message (JSON round trip, next
## frame) to the rooms on the same channel, with presence like Supabase's.
##   godot --headless --path . --script res://tools/test_online_table.gd
## Part 1: the room itself (seats, full, started, a dropped player keeps the
## seat). Part 2: three copies of Poker at one table with a computer player:
## host, join by code, Start, random play until the tournament ends, every
## phone holding the same game after each action; a player who drops out is
## checked / folded for; a cash table rebuys; emotes reach the others.
## WRITES the real Poker saves and stats: back up
## %APPDATA%\Godot\app_userdata\Voodoo first (CLAUDE.md), restore after.

const POKER := "res://scenes/games/video_poker/video_poker.tscn"

class FakeServer extends Node:
	var members := {}   # topic -> {presence key: room}
	var metas := {}     # topic -> {presence key: meta}
	var sent := 0

	func receive(room: Node, topic: String, event: String, payload: Dictionary, ref: String) -> void:
		if room.offline:
			return
		match event:
			"phx_join":
				var key := str(payload.config.presence.key)
				if not members.has(topic):
					members[topic] = {}
					metas[topic] = {}
				members[topic][key] = room
				_send(room, {"topic": topic, "event": "phx_reply", "ref": ref, "payload": {"status": "ok", "response": {}}})
				var state := {}
				for k in metas[topic]:
					state[k] = {"metas": [metas[topic][k]]}
				_send(room, {"topic": topic, "event": "presence_state", "payload": state})
			"presence":
				var key2 := str(room.my_id)
				metas[topic][key2] = payload.get("payload", {})
				for r in members[topic].values():
					_send(r, {"topic": topic, "event": "presence_diff", "payload": {"joins": {key2: {"metas": [metas[topic][key2]]}}, "leaves": {}}})
			"broadcast":
				sent += 1
				for k in members.get(topic, {}):
					if members[topic][k] != room:
						_send(members[topic][k], {"topic": topic, "event": "broadcast", "payload": payload})
			"phx_leave":
				drop(room)

	func drop(room: Node) -> void:
		for topic in members:
			for k in members[topic].keys():
				if members[topic][k] == room:
					members[topic].erase(k)
					var m = metas[topic].get(k, {})
					metas[topic].erase(k)
					for r in members[topic].values():
						_send(r, {"topic": topic, "event": "presence_diff", "payload": {"joins": {}, "leaves": {k: {"metas": [m]}}}})

	func _send(room: Node, msg: Dictionary) -> void:
		if not is_instance_valid(room) or room.offline:
			return
		room.call_deferred("_handle", JSON.parse_string(JSON.stringify(msg)))

## OnlineRoom with the socket swapped for the fake server.
class FakeRoom extends "res://scripts/common/online_room.gd":
	static var server: Node
	var offline := false

	func _connect() -> void:
		_channel_joined = false
		_join_channel()

	func _push(topic: String, event: String, payload: Dictionary, ref: String = "") -> void:
		if server and is_instance_valid(server):
			server.receive(self, topic, event, payload, ref if ref != "" else str(_next_ref()))

	func _process(delta: float) -> void:
		if not active or _join_deadline <= 0.0:
			return
		_join_deadline -= delta
		if _join_deadline <= 0.0 and not opponent_present:
			active = false
			server.drop(self)
			join_failed.emit("timeout")

	func leave() -> void:
		if server and is_instance_valid(server):
			server.drop(self)
		active = false
		_channel_joined = false

	## Drops off the network (Android killed it, a tunnel...) and later comes back.
	func go_offline() -> void:
		server.drop(self)
		offline = true

	func come_back() -> void:
		offline = false
		_connect()

var fails := 0
var server: FakeServer

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	server = FakeServer.new()
	root.add_child(server)
	FakeRoom.server = server
	await _test_rooms()
	await _test_poker("tourney")
	await _test_poker("cash")
	print("ONLINE TABLE TEST: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)

# ---------- part 1: the room ----------

func _room(nm: String) -> Node:
	var r := FakeRoom.new()
	r.my_name = nm
	root.add_child(r)
	return r

func _test_rooms() -> void:
	var h := _room("Ana")
	h.max_players = 3
	h.note = "Hold'em"
	h.host("video_poker")
	await _frames(3)
	ok(h.code.length() == 5, "table codes are 5 letters")
	var g1 := _room("Bo")
	var g2 := _room("Cy")
	var g3 := _room("Di")
	var joined := {}
	var failed := {}
	for g in [g1, g2, g3]:
		g.joined.connect(func(): joined[g.my_name] = true)
		g.join_failed.connect(func(why): failed[g.my_name] = why)
	g1.join("video_poker", h.code)
	await _frames(6)
	g2.join("video_poker", h.code)
	await _frames(6)
	ok(joined.has("Bo") and joined.has("Cy"), "two guests get seats")
	ok(h.seats.size() == 3 and g2.seats.size() == 3, "everyone has the same three seats")
	ok(g2.my_player() == 3 and g1.my_player() == 2 and h.my_player() == 1, "player numbers follow the seats")
	ok(g1.note == "Hold'em" and str(g2.seats[0].name) == "Ana", "the roster carries the note and names")
	g3.join("video_poker", h.code)
	await _frames(6)
	ok(str(failed.get("Di", "")) != "" and not joined.has("Di"), "a fourth player is turned away from a 3-seat table")
	# Before the start, a guest who leaves gives the seat back.
	g2.leave()
	await _frames(6)
	ok(h.seats.size() == 2 and g1.seats.size() == 2, "a guest who leaves before the start frees the seat (%d, %d)" % [h.seats.size(), g1.seats.size()])
	g2.join("video_poker", h.code)
	await _frames(6)
	ok(h.seats.size() == 3, "and can sit down again")
	h.start_table()
	await _frames(4)
	ok(g1.locked and g2.locked, "the start locks the table for everyone")
	# After the start, a dropped guest keeps the seat and gets it back.
	g1.go_offline()
	await _frames(6)
	ok(h.seats.size() == 3 and not h.is_here(str(g1.my_id)), "a dropped player keeps the seat, shown away")
	g1.come_back()
	await _frames(6)
	ok(h.is_here(str(g1.my_id)) and g1.my_player() == 2, "back in the same seat")
	var g4 := _room("Ed")
	var refused := [""]
	g4.join_failed.connect(func(why): refused[0] = why)
	g4.join("video_poker", h.code)
	await _frames(6)
	ok(refused[0] != "" and g4.my_player() == 0, "nobody new sits down after the start")
	for r in [h, g1, g2, g3, g4]:
		r.queue_free()
	await _frames(3)

# ---------- part 2: Poker ----------

func _poker() -> Node:
	var g: Node = load(POKER).instantiate()
	root.add_child(g)
	return g

func _test_poker(fmt: String) -> void:
	var games: Array = [_poker(), _poker(), _poker()]
	await _frames(3)
	for g in games:
		if g.info:
			g.info.close()
		g.table_net.lobby.room_script = FakeRoom
		g.away_sec = 0.3
	var host: Node = games[0]
	ok(host.table_net != null, "Poker has the friends table on this app")
	host.prefs.variant = "holdem"
	host.prefs.limit = "nl"
	host.prefs.ofmt = 1 if fmt == "cash" else 0
	host.prefs.oseats = 4
	host.prefs.ofill = true
	host.prefs.ostack = 2 if fmt == "tourney" else 0  # deep stacks: the drop-out step comes before the end
	host.prefs.ospeed = 0
	host.prefs.oturn = 0
	host._host_friends()
	await _frames(4)
	var code: String = str(host.table_net.lobby.room.code)
	ok(code.length() == 5, "%s: the host's lobby has a code" % fmt)
	for k in [1, 2]:
		var lob = games[k].table_net.lobby
		games[k].table_net.open_lobby()
		lob._name_edit.text = "Guest %d" % k
		lob._code_edit.text = code
		lob._on_join()
		await _frames(6)
	ok(host.table_net.lobby.room.seats.size() == 3, "%s: three people in the lobby" % fmt)
	host.table_net.lobby._on_start()
	paused = false
	await _frames(8)
	for g in games:
		ok(g.mode == "online" and g._is_table(), "%s: every phone is at the table" % fmt)
	ok(host.t.seats.size() == 4, "%s: three people and a computer player" % fmt)
	var kinds: Array = []
	for s in host.t.seats:
		kinds.append(int(s.kind))
	kinds.sort()
	ok(kinds == [0, 1, 2, 3], "%s: seat kinds are the player numbers (got %s)" % [fmt, kinds])
	ok(_all_same(games), "%s: same table after the start" % fmt)
	for g in games:
		ok(int(g.t.seats[g.viewer].kind) == g.my_player, "%s: each phone sits at its own seat" % fmt)

	# An emote reaches the others.
	games[1]._send_emote(0)
	await _frames(4)
	ok(games[0].view.bubbles.has(games[1].viewer) and games[2].view.bubbles.has(games[1].viewer), "%s: an emote shows on the other phones" % fmt)

	var actions := 0
	var dropped := false
	var auto_seen := false
	var limit := 1500 if fmt == "tourney" else 160
	while actions < limit:
		if host.end_dialog.visible:
			break
		# One guest drops out for a while: the host checks / folds for them.
		if fmt == "tourney" and actions == 12 and not dropped:
			dropped = true
			var r = games[2].table_net.session
			r.go_offline()
			await _frames(6)
			ok(host.view.away.size() == 1, "tourney: the dropped player shows Away on the host")
			var tries := 0
			while tries < 300 and not auto_seen and not host.end_dialog.visible:
				tries += 1
				await _cpu_step(host)
				if host.t.phase in ["bet", "draw"] and host.t.to_act >= 0 and int(host.t.seats[host.t.to_act].kind) == 3:
					var key: String = host._decision_key()
					await _wait(0.6)
					auto_seen = host._decision_key() != key
					continue
				var stepped := false
				for k in [0, 1]:
					if games[k]._hero_can_act():
						_act(games[k])
						stepped = true
						break
				if not stepped and host.t.phase == "done" and not host.end_dialog.visible:
					host._on_next()
				await _frames(3)
			r.come_back()
			await _frames(10)
			ok(_all_same(games), "tourney: the player who came back has the table again")
			continue
		var moved := false
		await _cpu_step(host)
		for g in games:
			if g._hero_can_act():
				_act(g)
				moved = true
				break
		if not moved and host.t.phase == "done" and not host.end_dialog.visible:
			host._on_next()
			moved = true
		await _frames(3)
		if moved:
			actions += 1
			if not _all_same(games):
				ok(false, "%s: phones differ after action %d" % [fmt, actions])
				break
	if fmt == "tourney":
		ok(host.end_dialog.visible, "tourney: the table finished (%d actions)" % actions)
		print("tourney: %d actions, hands %d" % [actions, host.t.hand_no])
		ok(auto_seen, "tourney: the host acted for the player who dropped out")
		await _frames(4)
		for g in games:
			ok(g.result_recorded, "tourney: every phone recorded its finish")
	else:
		var rebuys := 0
		for b in host.meta.buys:
			rebuys += int(b)
		ok(not host.end_dialog.visible, "cash: the table never ends by itself")
		print("cash: %d actions, %d rebuys" % [actions, rebuys])
	print("%s: %d messages" % [fmt, server.sent])
	for g in games:
		g.queue_free()
	await _frames(4)

func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < until:
		await process_frame

## The host's computer player: don't wait for its timer.
func _cpu_step(host: Node) -> void:
	if not host.cpu_timer.is_stopped():
		host.cpu_timer.stop()
		host._on_cpu_timer()
	var n := 0
	while host.think_task >= 0 and n < 400:
		await process_frame
		n += 1

func _all_same(games: Array) -> bool:
	var a := JSON.stringify(games[0]._online_state())
	for g in games.slice(1):
		var b := JSON.stringify(g._online_state())
		if a != b:
			print("  host:  ", a.left(600), "\n  guest: ", b.left(600))
			return false
	return true

func _act(g: Node) -> void:
	if g.t.phase == "draw":
		g.discards = []
		g._on_call()
		return
	var r := randf()
	if r < 0.12 and g.fold_btn.visible:
		g._on_fold()
	elif r < 0.75 or not g.raise_btn.visible:
		g._on_call()
	else:
		g._size_preset(["min", "half", "pot", "all"].pick_random())
		g._on_raise()
