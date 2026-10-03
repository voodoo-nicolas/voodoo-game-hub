extends Control

## Everything a turn-based game needs for online play, so each game only
## supplies its own state and move logic:
##
##     const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
##     if ResourceLoader.exists(ONLINE_MATCH_PATH):   # never preload -- see below
##         match_ = load(ONLINE_MATCH_PATH).new("chess", "Chess", _online_state)
##         add_child(match_)                          # before SettingsDrawer
##         match_.remote_move.connect(_on_remote_move)      # apply opponent's move
##         match_.remote_state.connect(_on_remote_state)    # adopt full state
##         match_.remote_new_game.connect(_reset_board)
##         match_.started.connect(_on_online_started)      # my_player: 1 host, 2 guest
##         match_.status_changed.connect(_render)
##     ...
##     match_.open_lobby()           # the "Play Online" button
##     match_.send_move({...})       # after making a local move
##     match_.new_game()             # local "Play Again"/"Restart"
##
## Consistency: the host is the authority. It sends the full state whenever
## the guest (re)appears or asks. Every move also carries the sender's
## resulting state; after the game applies a remote move (synchronously,
## inside remote_move), this compares states and re-syncs on any mismatch --
## so a missed message or a reconnect mid-move heals itself.
##
## `get_state` must return only JSON-safe values (ints, strings, arrays,
## dicts) describing the whole game, and remote_state must accept the same
## shape back (numbers arrive as floats -- cast with int()).
##
## Games must not preload this: packs also run on apps from before it
## existed (< v0.14), where the file isn't there. Without it: no Online button.
##
## Coming back after a drop-out (since v0.22): the room (game, code, role,
## presence id) is saved in ROOM_PATH while a match is on and deleted when
## the player leaves the game normally. If Android kills the app mid-match,
## the game opens again with the lobby offering "Rejoin game XXXX", which
## takes the same seat. A returning HOST has lost its game state, so it asks
## the guest for theirs ("state_please") instead of pushing a blank board.
##
## Names: my_name() / opponent_name() (from the lobby's "Your name" field)
## and status_text() / result_text() use them.

const OnlineLobby = preload("res://scripts/common/online_lobby.gd")
const ROOM_PATH := "user://online_room.json"
## A saved room older than this is stale -- the other player has gone.
const ROOM_MAX_AGE_SEC := 30 * 60

signal started(my_player: int)
signal remote_move(payload: Dictionary)
signal remote_state(state: Dictionary)
signal remote_new_game()
## Opponent came or went, or the connection dropped -- re-render the status.
signal status_changed()

var game_id: String
var title: String
var get_state: Callable
var lobby: Control
var session: Node = null
var my_player: int = 0  # 0 = not online; 1 = host; 2 = guest
var opponent_here: bool = false
var connected: bool = true
## True while a returning host waits for the guest's copy of the game.
var adopting: bool = false

func _init(p_game_id: String = "", p_title: String = "", p_get_state: Callable = Callable()) -> void:
	game_id = p_game_id
	title = p_title
	get_state = p_get_state
	name = "OnlineMatch"

## A full-screen layer that ignores clicks, holding the lobby overlay. Add it
## where an overlay belongs: after the game's dialogs, before SettingsDrawer.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby = OnlineLobby.new(game_id, title)
	lobby.started.connect(_on_lobby_started)
	add_child(lobby)
	var room := _saved_room()
	if not room.is_empty():
		lobby.rejoin_room = room
		lobby.call_deferred("open")  # straight back to "Rejoin game XXXX"

## Leaving the game normally ends the match for us: forget the room.
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
			"id": session.my_id, "t": int(Time.get_unix_time_from_system())}))

func my_name() -> String:
	var n: String = str(session.my_name) if session else ""
	return n if n != "" else tr("You")

func opponent_name() -> String:
	var n: String = str(session.opponent_name) if session else ""
	return n if n != "" else tr("Friend")

func is_online() -> bool:
	return my_player != 0

func is_host() -> bool:
	return my_player == 1

## Can the local player act right now? `current_player_is_me` is the game's
## own "whose turn" test; offline this is always true.
func can_act(current_player_is_me: bool) -> bool:
	return not is_online() or (current_player_is_me and opponent_here)

func open_lobby() -> void:
	lobby.open()

func send_move(payload: Dictionary) -> void:
	if not is_online():
		return
	var p := payload.duplicate()
	p["state"] = get_state.call()
	session.send("move", p)
	_save_room()  # keeps the saved room fresh through a long match

## Host: send the whole current state now (e.g. after choosing a new board
## that a plain "new_game" can't describe).
func push_state() -> void:
	if is_online():
		_send_sync()

func new_game() -> void:
	if is_online():
		session.send("new_game")

## Standard status line for online games; `turn_text` is the game's own
## description of whose turn it is ("White", "Red"...).
func status_text(my_turn: bool, turn_text: String) -> String:
	if not opponent_here:
		return tr("%s disconnected — waiting...") % opponent_name()
	if my_turn:
		return tr("Your turn (%s)") % turn_text
	return tr("%s's turn (%s)") % [opponent_name(), turn_text]

func result_text(i_won: bool) -> String:
	return tr("You win!") if i_won else tr("%s wins!") % opponent_name()

# ---------- internals ----------

func _on_lobby_started(p_session: Node, p_my_player: int) -> void:
	session = p_session
	my_player = p_my_player
	opponent_here = true
	var rejoined: bool = not lobby.rejoin_room.is_empty() and str(lobby.rejoin_room.get("code", "")) == str(session.code)
	lobby.rejoin_room = {}
	session.message.connect(_on_message)
	session.opponent_left.connect(_on_opponent_left)
	session.opponent_joined.connect(_on_opponent_back)
	session.connection_changed.connect(_on_connection_changed)
	_save_room()
	started.emit(my_player)
	if is_host():
		if rejoined:
			adopting = true  # our board is blank; the guest still has the game
			session.send("state_please")
		else:
			_send_sync()
	elif rejoined:
		session.send("sync_request")

func _send_sync() -> void:
	session.send("sync", {"state": get_state.call()})

func _on_opponent_back() -> void:
	opponent_here = true
	if is_host():
		if adopting:
			session.send("state_please")
		else:
			_send_sync()
	status_changed.emit()

func _on_opponent_left() -> void:
	opponent_here = false
	status_changed.emit()

func _on_connection_changed(is_up: bool) -> void:
	connected = is_up
	if is_up and not is_host():
		session.send("sync_request")  # we may have missed moves while away
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
				adopting = false
				remote_state.emit(p.state)
		"sync_request":
			if is_host() and not adopting:
				_send_sync()
		"state_please":
			# The host came back with a blank board: give it our copy.
			if not is_host():
				_send_sync()
		"new_game":
			remote_new_game.emit()

## Compare through a JSON round trip, since the received copy has floats
## where ours has ints.
func _same_state(received: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(get_state.call())) == received
