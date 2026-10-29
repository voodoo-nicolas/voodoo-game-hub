extends Control

## OnlineMatch for tables of 2 to 6 people (since v0.39): friends sit at one
## table, each on their own phone. Same idea as OnlineMatch (its header):
## the host is the authority, every move carries the sender's whole state,
## a mismatch re-syncs. What's new is the seat list (online_room.gd): player
## numbers 1..n, the host = 1, and players who drop out keep their seat.
##
##     const ONLINE_TABLE_PATH := "res://scripts/common/online_table.gd"
##     if ResourceLoader.exists(ONLINE_TABLE_PATH):   # never preload: older apps lack it
##         tbl = load(ONLINE_TABLE_PATH).new("video_poker", "Poker", _online_state)
##         add_child(tbl)
##         tbl.started.connect(_on_table_started)       # my_player: 1 host, 2.. guests
##         tbl.remote_move.connect(_on_remote_move)
##         tbl.remote_state.connect(_on_remote_state)
##         tbl.remote_new_game.connect(_on_remote_new_game)
##         tbl.remote_event.connect(_on_remote_event)   # emotes and other extras
##         tbl.status_changed.connect(_render)          # someone came, went, dropped
##     ...
##     tbl.host_table(4, "Hold'em · 4 seats")  # the game's setup screen chose the table
##     tbl.open_lobby()                         # join with a code
##     tbl.players()                            # [{n, name, here}] in seat order
##     tbl.send_move({...}) / push_state() / new_game() / send_event("emote", {...})
##
## The game decides who sits where: players() gives the people; it can fill
## the other seats with computer players (the host runs them).
##
## Rooms: codes are 5 letters (OnlineRoom), so an invite or a typed code says
## whether it is a table or a two-player room; OnlineMatch leaves 5-letter
## invites to this. The room is saved in ROOM_PATH while a table is on, for
## "↩ Rejoin" after Android kills the app; a returning host asks the others
## for the game ("state_please").

const Lobby = preload("res://scripts/common/online_table_lobby.gd")
const OnlineRoom = preload("res://scripts/common/online_room.gd")
const ROOM_PATH := "user://online_table.json"
const ROOM_MAX_AGE_SEC := 30 * 60

signal started(my_player: int)
signal remote_move(payload: Dictionary)
signal remote_state(state: Dictionary)
signal remote_new_game()
signal remote_event(event: String, from: int, payload: Dictionary)
signal status_changed()

var game_id: String
var title: String
var get_state: Callable
var lobby: Control
var session: Node = null   # the OnlineRoom
var my_player: int = 0     # 0 = not online
var connected: bool = true
var adopting: bool = false
var _here: Dictionary = {}  # seat ids last seen here (to notice who came back)

func _init(p_game_id: String = "", p_title: String = "", p_get_state: Callable = Callable()) -> void:
	game_id = p_game_id
	title = p_title
	get_state = p_get_state
	name = "OnlineTable"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby = Lobby.new(game_id, title)
	lobby.started.connect(_on_lobby_started)
	add_child(lobby)
	var social := get_node_or_null("/root/Social")
	var peek = social.get("pending") if social else null
	var room := _saved_room()
	if typeof(peek) == TYPE_DICTIONARY and str(peek.get("game", "")) == game_id \
			and str(peek.get("code", "")).length() == OnlineRoom.TABLE_CODE_LENGTH and social.has_method("take_pending"):
		lobby.call_deferred("auto_start", social.take_pending(game_id))
	elif not room.is_empty():
		lobby.rejoin_room = room
		lobby.call_deferred("open")

func _exit_tree() -> void:
	if is_online() and FileAccess.file_exists(ROOM_PATH):
		DirAccess.remove_absolute(ROOM_PATH)

func _saved_room() -> Dictionary:
	if not FileAccess.file_exists(ROOM_PATH):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(ROOM_PATH))
	if typeof(data) != TYPE_DICTIONARY or str(data.get("game", "")) != game_id:
		return {}
	if Time.get_unix_time_from_system() - float(data.get("t", 0)) > ROOM_MAX_AGE_SEC:
		return {}
	return data

func _save_room() -> void:
	var f := FileAccess.open(ROOM_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"game": game_id, "code": session.code, "host": is_host(),
			"id": session.my_id, "seats": session.seats, "t": int(Time.get_unix_time_from_system())}))

# ---------- public API ----------

## Host a table of up to `max_players` people; `note` describes it in the lobby.
func host_table(max_players: int, note: String = "", min_players: int = 2) -> void:
	lobby.max_players = clampi(max_players, 2, 6)
	lobby.min_players = clampi(min_players, 2, lobby.max_players)
	lobby.note = note
	lobby.open_host()

## Join a table by code (or rejoin the saved one).
func open_lobby() -> void:
	lobby.note = ""
	lobby.open()

func is_online() -> bool:
	return my_player != 0

func is_host() -> bool:
	return my_player == 1

## The people at the table: [{n, name, here}], n = player number (1 = host).
func players() -> Array:
	var out: Array = []
	if session == null:
		return out
	for i in session.seats.size():
		var s: Dictionary = session.seats[i]
		var nm := str(s.get("name", ""))
		out.append({"n": i + 1, "name": nm if nm != "" else tr("Player %d") % (i + 1), "here": session.is_here(str(s.id))})
	return out

func name_of(n: int) -> String:
	for p in players():
		if int(p.n) == n:
			return str(p.name)
	return tr("Player %d") % n

func here(n: int) -> bool:
	if session == null or n < 1 or n > session.seats.size():
		return false
	return session.is_here(str(session.seats[n - 1].id))

func host_here() -> bool:
	return session != null and session.host_here()

func my_name() -> String:
	return name_of(my_player)

## Names of the seated people who are away right now.
func missing() -> Array:
	var out: Array = []
	for p in players():
		if not bool(p.here):
			out.append(str(p.name))
	return out

## Can the local player act now? Only with the host there to keep the table.
func can_act(current_player_is_me: bool) -> bool:
	return not is_online() or (current_player_is_me and host_here() and connected)

func send_move(payload: Dictionary) -> void:
	if not is_online():
		return
	var p := payload.duplicate()
	p["state"] = get_state.call()
	p["from"] = my_player
	session.send("move", p)
	_save_room()

func push_state() -> void:
	if is_online() and is_host():
		_send_sync()

func new_game() -> void:
	if is_online():
		session.send("new_game")

## Something besides a move (an emote...): everyone else gets remote_event.
func send_event(event: String, payload: Dictionary = {}) -> void:
	if is_online():
		session.send("ev", {"e": event, "from": my_player, "p": payload})

# ---------- internals ----------

func _on_lobby_started(p_room: Node, p_my_player: int) -> void:
	var rejoined: bool = p_room.locked and not p_room.is_host
	# A host back from a saved table has lost the game; the others still have it.
	var saved := _saved_room()
	adopting = p_room.is_host and not saved.is_empty() and str(saved.get("code", "")) == str(p_room.code)
	session = p_room
	my_player = p_my_player
	session.message.connect(_on_message)
	session.roster_changed.connect(_on_roster)
	session.connection_changed.connect(_on_connection_changed)
	_here = {}
	for s in session.seats:
		_here[str(s.id)] = session.is_here(str(s.id))
	_save_room()
	started.emit(my_player)  # the game reads `adopting` to know whether to deal
	if is_host():
		if adopting:
			session.send("state_please")
		else:
			_send_sync()
	elif rejoined:
		session.send("sync_request")

func _send_sync() -> void:
	session.send("sync", {"state": get_state.call()})

func _on_roster() -> void:
	var back := false
	for s in session.seats:
		var id := str(s.id)
		var now: bool = session.is_here(id)
		if now and not bool(_here.get(id, false)):
			back = true
		_here[id] = now
	if back and is_host():
		if adopting:
			session.send("state_please")
		else:
			_send_sync()
	status_changed.emit()

func _on_connection_changed(is_up: bool) -> void:
	connected = is_up
	if is_up and not is_host():
		session.send("sync_request")
	status_changed.emit()

func _on_message(event: String, p: Dictionary) -> void:
	match event:
		"move":
			remote_move.emit(p)
			if p.has("state") and not _same_state(p.state):
				if is_host():
					_send_sync()
				else:
					session.send("sync_request")
		"sync":
			if typeof(p.get("state")) == TYPE_DICTIONARY:
				if is_host() and not adopting:
					return  # the host's own copy is the table
				adopting = false
				remote_state.emit(p.state)
		"sync_request":
			if is_host() and not adopting:
				_send_sync()
		"state_please":
			if not is_host():
				_send_sync()
		"new_game":
			remote_new_game.emit()
		"ev":
			remote_event.emit(str(p.get("e", "")), int(p.get("from", 0)), p.get("p", {}) if typeof(p.get("p")) == TYPE_DICTIONARY else {})

func _same_state(received: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(get_state.call())) == received
