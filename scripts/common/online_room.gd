extends "res://scripts/common/online_session.gd"

## A table for 2 to `max_players` people (since v0.39): OnlineSession's
## Realtime channel, presence and reconnects, plus a list of seats that the
## host keeps. Games use it through OnlineTable (online_table.gd), whose
## header is the how-to; this file is the room itself.
##
## Seats: `seats` = [{id, name}] in seat order, the host first, so player
## number n is seats[n - 1]. Only the host changes it, and it sends the whole
## list ("roster") whenever anyone comes or goes; guests just adopt it.
## Before the start the table is whoever is in the room (up to max_players);
## once the host locks it (start_table), nobody new gets a seat, and a seated
## player who drops out keeps the seat and takes it again with rejoin().
##
## Codes are TABLE_CODE_LENGTH letters, one more than the two-player rooms,
## so an invite's code alone says which kind of room it is (the invite on the
## server only carries a game and a code).

signal roster_changed()

const TABLE_CODE_LENGTH := 5

var max_players: int = 6
var seats: Array = []
var locked: bool = false
## The host's one-line description of the table ("Hold'em · 4 seats"),
## carried in the roster so the lobby can show it to everyone.
var note: String = ""
var _seated: bool = false

func _init() -> void:
	super()
	message.connect(_on_room_message)

func host(p_game_id: String) -> void:
	is_host = true
	game_id = p_game_id
	code = _random_table_code()
	seats = [{"id": my_id, "name": my_name}]
	locked = false
	_start()

func join(p_game_id: String, p_code: String) -> void:
	is_host = false
	game_id = p_game_id
	code = p_code.strip_edges().to_upper()
	if code.length() != TABLE_CODE_LENGTH:
		join_failed.emit(tr("Table codes are %d letters.") % TABLE_CODE_LENGTH)
		return
	_seated = false
	_join_deadline = JOIN_TIMEOUT_SEC
	_start()

## Back into a table (see OnlineSession.rejoin). A returning host brings the
## seats it saved, so the table stays locked to the same people.
func rejoin_table(p_game_id: String, p_code: String, as_host: bool, p_id: String, p_seats: Array) -> void:
	if as_host:
		seats = p_seats.duplicate(true)
		locked = seats.size() > 1
	_seated = false
	rejoin(p_game_id, p_code, as_host, p_id)

## Host: nobody new gets a seat from now on; the lobby then starts the game.
func start_table() -> void:
	if not is_host:
		return
	locked = true
	_send_roster()

func seat_of(id: String) -> int:
	for i in seats.size():
		if str(seats[i].id) == id:
			return i
	return -1

## Player number (1 = host) of this app, 0 while it has no seat.
func my_player() -> int:
	return seat_of(my_id) + 1

func is_here(id: String) -> bool:
	return id == my_id or _presence.has(id)

func host_here() -> bool:
	return is_host or (seats.size() > 0 and is_here(str(seats[0].id)))

# ---------- the seat list ----------

## OnlineSession calls this after every presence change.
func _update_opponent() -> void:
	if is_host:
		_host_roster()
	roster_changed.emit()

func _host_roster() -> void:
	if seats.is_empty() or str(seats[0].id) != my_id:
		seats = [{"id": my_id, "name": my_name}]
	if not locked:
		# Before the start the table is whoever is here.
		var keep: Array = [seats[0]]
		for s in seats.slice(1):
			if _presence.has(str(s.id)):
				keep.append(s)
		seats = keep
	for key in _presence:
		if key == my_id or _presence[key] != "guest" or seat_of(key) >= 0:
			continue
		if not locked and seats.size() < max_players:
			seats.append({"id": key, "name": str(_names.get(key, ""))})
		else:
			send("refused", {"id": key, "why": "started" if locked else "full"})
	for s in seats:
		if str(_names.get(str(s.id), "")) != "":
			s.name = str(_names[str(s.id)])
	seats[0].name = my_name
	opponent_present = seats.size() > 1
	_send_roster()

func _send_roster() -> void:
	send("roster", {"seats": seats, "locked": locked, "note": note, "max": max_players})

func _on_room_message(event: String, p: Dictionary) -> void:
	if is_host:
		return
	match event:
		"roster":
			var list: Array = []
			for s in p.get("seats", []):
				if typeof(s) == TYPE_DICTIONARY:
					list.append({"id": str(s.get("id", "")), "name": str(s.get("name", ""))})
			seats = list
			locked = bool(p.get("locked", false))
			note = str(p.get("note", ""))
			max_players = int(p.get("max", max_players))
			if seat_of(my_id) >= 0 and not _seated:
				_seated = true
				opponent_present = true
				_join_deadline = -1.0
				joined.emit()
			roster_changed.emit()
		"refused":
			if str(p.get("id", "")) != my_id or _seated:
				return
			leave()  # out of the room's presence, or the host would seat us when a seat frees up
			join_failed.emit(tr("That table has already started.") if str(p.get("why", "")) == "started"
				else tr("That table is full."))

func _random_table_code() -> String:
	var s := ""
	for i in range(TABLE_CODE_LENGTH):
		s += CODE_CHARS[randi() % CODE_CHARS.length()]
	return s
