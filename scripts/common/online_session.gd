extends Node

## Two-player online play over Supabase Realtime "broadcast" channels -- no
## database tables, nothing stored server-side. A game scene adds one of
## these as a child (it's freed with the scene, which leaves the room):
##
##     var online := OnlineSession.new()
##     add_child(online)
##     online.message.connect(_on_online_message)
##     online.host("tictactoe")        # -> room_created(code)
##     online.join("tictactoe", code)  # -> joined / join_failed(reason)
##
## Roles: the host is player 1, the guest player 2. Both sides run the same
## game engine and exchange moves with send("move", {...}); each side
## validates incoming moves against its own engine. Messages carry a
## sequence number, and whenever the opponent (re)appears the host sends
## "sync" with the full game state, so a dropped connection recovers.
##
## Protocol: Phoenix channels over a WebSocket (what supabase-js speaks),
## with presence used to see who is in the room.

const Config = preload("res://scripts/common/config.gd")

signal room_created(code: String)
signal joined()                      # guest: in the room, host is there
signal join_failed(reason: String)
signal opponent_joined()
signal opponent_left()
signal message(event: String, payload: Dictionary)
signal connection_changed(connected: bool)

const HEARTBEAT_SEC := 25.0
const RECONNECT_SEC := 3.0
const JOIN_TIMEOUT_SEC := 8.0
## No 0/O/1/I/L: codes get read aloud and typed on phones.
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 4

var is_host: bool = false
var code: String = ""
var game_id: String = ""
var my_id: String = ""
var opponent_present: bool = false
var active: bool = false

var _ws := WebSocketPeer.new()
var _topic: String = ""
var _ref: int = 0
var _join_ref: String = ""
var _channel_joined: bool = false
var _heartbeat_left: float = HEARTBEAT_SEC
var _reconnect_left: float = -1.0
var _join_deadline: float = -1.0
var _was_open: bool = false
var _presence: Dictionary = {}  # presence key -> role

func _init() -> void:
	my_id = "%d%d" % [Time.get_unix_time_from_system(), randi()]

# ---------- public API ----------

func host(p_game_id: String) -> void:
	is_host = true
	game_id = p_game_id
	code = _random_code()
	_start()

func join(p_game_id: String, p_code: String) -> void:
	is_host = false
	game_id = p_game_id
	code = p_code.strip_edges().to_upper()
	if code.length() != CODE_LENGTH:
		join_failed.emit("Codes are %d letters." % CODE_LENGTH)
		return
	_join_deadline = JOIN_TIMEOUT_SEC
	_start()

## Sends an event to the opponent. Silently dropped while disconnected --
## the host's "sync" on reconnect restores the full state anyway.
func send(event: String, payload: Dictionary = {}) -> void:
	if not _channel_joined:
		return
	_push(_topic, "broadcast", {"type": "broadcast", "event": event, "payload": payload})

func leave() -> void:
	if active and _channel_joined:
		_push(_topic, "phx_leave", {})
	active = false
	_channel_joined = false
	_ws.close()

func is_connected_to_room() -> bool:
	return _channel_joined

# ---------- lifecycle ----------

func _start() -> void:
	active = true
	_topic = "realtime:voodoo-%s-%s" % [game_id, code]
	_connect()

func _connect() -> void:
	_channel_joined = false
	_was_open = false
	_ws = WebSocketPeer.new()
	var url := Config.SUPABASE_URL.replace("https://", "wss://") \
		+ "/realtime/v1/websocket?apikey=" + Config.SUPABASE_ANON_KEY + "&vsn=1.0.0"
	if _ws.connect_to_url(url) != OK:
		_schedule_reconnect()

func _exit_tree() -> void:
	leave()

func _process(delta: float) -> void:
	if not active:
		return
	if _join_deadline > 0.0:
		_join_deadline -= delta
		if _join_deadline <= 0.0 and not opponent_present:
			active = false
			_ws.close()
			join_failed.emit("No game found with code %s." % code)
			return
	if _reconnect_left > 0.0:
		_reconnect_left -= delta
		if _reconnect_left <= 0.0:
			_connect()
		return

	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_join_channel()
		_heartbeat_left -= delta
		if _heartbeat_left <= 0.0:
			_heartbeat_left = HEARTBEAT_SEC
			_push("phoenix", "heartbeat", {})
		while _ws.get_available_packet_count() > 0:
			_handle(JSON.parse_string(_ws.get_packet().get_string_from_utf8()))
	elif state == WebSocketPeer.STATE_CLOSED:
		if _channel_joined or _was_open:
			connection_changed.emit(false)
		_channel_joined = false
		_schedule_reconnect()

func _schedule_reconnect() -> void:
	_reconnect_left = RECONNECT_SEC

func _join_channel() -> void:
	_join_ref = str(_next_ref())
	_push(_topic, "phx_join", {"config": {
		"broadcast": {"self": false, "ack": false},
		"presence": {"key": my_id},
		"private": false,
	}}, _join_ref)

# ---------- incoming ----------

func _handle(msg: Variant) -> void:
	if typeof(msg) != TYPE_DICTIONARY or msg.get("topic") != _topic:
		return
	var event: String = str(msg.get("event", ""))
	var payload = msg.get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}
	match event:
		"phx_reply":
			if str(msg.get("ref", "")) == _join_ref:
				if payload.get("status") == "ok":
					_channel_joined = true
					connection_changed.emit(true)
					_push(_topic, "presence", {"type": "presence", "event": "track",
						"payload": {"role": "host" if is_host else "guest"}})
					if is_host and code != "" and not opponent_present:
						room_created.emit(code)
				else:
					_schedule_reconnect()
		"presence_state":
			_presence = {}
			for key in payload:
				_presence[key] = _role_of(payload[key])
			_update_opponent()
		"presence_diff":
			for key in payload.get("joins", {}):
				_presence[key] = _role_of(payload.joins[key])
			for key in payload.get("leaves", {}):
				_presence.erase(key)
			_update_opponent()
		"broadcast":
			var inner = payload.get("payload", {})
			message.emit(str(payload.get("event", "")), inner if typeof(inner) == TYPE_DICTIONARY else {})
		"phx_error", "phx_close":
			_channel_joined = false
			_schedule_reconnect()

func _role_of(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		var metas = entry.get("metas", [])
		if typeof(metas) == TYPE_ARRAY and metas.size() > 0 and typeof(metas[0]) == TYPE_DICTIONARY:
			return str(metas[0].get("role", ""))
	return ""

func _update_opponent() -> void:
	var want: String = "guest" if is_host else "host"
	var present := false
	for key in _presence:
		if key != my_id and _presence[key] == want:
			present = true
	if not is_host:
		# A host already occupied by another guest means the room is full.
		for key in _presence:
			if key != my_id and _presence[key] == "guest" and not opponent_present and _join_deadline > 0.0:
				active = false
				_ws.close()
				join_failed.emit("That game already has two players.")
				return
	if present == opponent_present:
		return
	opponent_present = present
	if present:
		if not is_host and _join_deadline > 0.0:
			_join_deadline = -1.0
			joined.emit()
		opponent_joined.emit()
	else:
		opponent_left.emit()

# ---------- outgoing ----------

func _next_ref() -> int:
	_ref += 1
	return _ref

func _push(topic: String, event: String, payload: Dictionary, ref: String = "") -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify({
		"topic": topic, "event": event, "payload": payload,
		"ref": ref if ref != "" else str(_next_ref()),
		"join_ref": _join_ref,
	}))

func _random_code() -> String:
	var s := ""
	for i in range(CODE_LENGTH):
		s += CODE_CHARS[randi() % CODE_CHARS.length()]
	return s
