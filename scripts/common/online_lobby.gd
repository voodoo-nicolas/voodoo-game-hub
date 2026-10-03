extends ColorRect

## The shared "Play Online" screen: host a game (get a code to share) or join
## one by typing a code. Emits `started(session, my_player)` once both
## players are in -- host is player 1, guest player 2 -- then hides itself.
## The OnlineSession stays a child of this node, so it lives exactly as
## long as the game scene that added the lobby.
##
## Games must not preload this (or online_session.gd): apps older than the
## one that shipped them don't have these files. Check first:
##     if ResourceLoader.exists(ONLINE_LOBBY_PATH): ...load(ONLINE_LOBBY_PATH).new(...)

const OnlineSession = preload("res://scripts/common/online_session.gd")
const UI = preload("res://scripts/common/ui.gd")

signal started(session: Node, my_player: int)
signal cancelled()

## Your name as the other player sees it; remembered between games. Starts
## as your account's display name.
const NAME_PATH := "user://player_name.json"
const NAME_MAX := 16

var game_id: String
var game_title: String
var session: Node = null
## {code, host: bool, id} of a game this app can take its seat in again
## (set by OnlineMatch from its saved room), or empty.
var rejoin_room: Dictionary = {}

var _menu: Control
var _name_edit: LineEdit
var _rejoin_btn: Button
var _code_edit: LineEdit
var _status: Label
var _code_label: Label
var _host_btn: Button
var _join_btn: Button

func _init(p_game_id: String = "", p_title: String = "") -> void:
	game_id = p_game_id
	game_title = p_title

func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	# ...and_offsets: by _ready() this node is already in the tree, and plain
	# set_anchors_preset() would keep its current 0x0 size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)
	_menu = box

	box.add_child(_label(tr("🌐 Play %s Online") % game_title, 36, Color(1, 1, 1)))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	box.add_child(name_row)
	var name_label := _label(tr("Your name"), 26, Color(0.75, 0.78, 0.85))
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.max_length = NAME_MAX
	_name_edit.placeholder_text = tr("Player")
	_name_edit.custom_minimum_size = Vector2(0, 64)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 30)
	_name_edit.text = load_name()
	name_row.add_child(_name_edit)

	_rejoin_btn = _button("")
	_rejoin_btn.visible = false
	_rejoin_btn.pressed.connect(_on_rejoin)
	box.add_child(_rejoin_btn)

	_host_btn = _button(tr("Host a Game"))
	_host_btn.pressed.connect(_on_host)
	box.add_child(_host_btn)

	box.add_child(_label(tr("— or join a friend's game —"), 24, Color(0.7, 0.72, 0.78)))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 12)
	box.add_child(join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = tr("Code")
	_code_edit.max_length = OnlineSession.CODE_LENGTH
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.custom_minimum_size = Vector2(240, 80)
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.add_theme_font_size_override("font_size", 40)
	_code_edit.text_changed.connect(_on_code_changed)
	_code_edit.text_submitted.connect(func(_t): _on_join())
	join_row.add_child(_code_edit)
	_join_btn = _button(tr("Join"))
	_join_btn.custom_minimum_size = Vector2(180, 80)
	_join_btn.pressed.connect(_on_join)
	join_row.add_child(_join_btn)

	_code_label = _label("", 64, Color(1, 0.84, 0.3))
	_code_label.visible = false
	box.add_child(_code_label)
	_status = _label("", 26, Color(0.85, 0.9, 0.87))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)

	var cancel := _button(tr("Cancel"))
	cancel.pressed.connect(_on_cancel)
	box.add_child(cancel)

func open() -> void:
	_reset_session()
	_code_edit.text = ""
	_code_label.visible = false
	_status.text = ""
	_rejoin_btn.visible = not rejoin_room.is_empty()
	if not rejoin_room.is_empty():
		_rejoin_btn.text = tr("↩ Rejoin game %s") % rejoin_room.code
		_status.text = tr("You were in game %s when you left. Rejoin to pick up where you were.") % rejoin_room.code
	_set_busy(false)
	visible = true

## The saved name, else the account's display name, else "".
static func load_name() -> String:
	if FileAccess.file_exists(NAME_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(NAME_PATH))
		if typeof(data) == TYPE_DICTIONARY and str(data.get("name", "")) != "":
			return str(data.name)
	var tree := Engine.get_main_loop() as SceneTree
	var auth = tree.root.get_node_or_null("Auth") if tree else null
	if auth and auth.has_method("is_logged_in") and auth.is_logged_in():
		return str(auth.get_display_name())
	return ""

func _my_name() -> String:
	var n := _name_edit.text.strip_edges().left(NAME_MAX)
	var f := FileAccess.open(NAME_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"name": n}))
	return n

func _on_rejoin() -> void:
	var s := _new_session()
	var as_host: bool = bool(rejoin_room.get("host", false))
	if as_host:
		s.opponent_joined.connect(_on_both_in.bind(1), CONNECT_ONE_SHOT)
		s.room_created.connect(_on_rejoin_waiting)
	else:
		s.joined.connect(_on_both_in.bind(2), CONNECT_ONE_SHOT)
		s.join_failed.connect(_on_join_failed)
	_set_busy(true)
	_status.text = tr("Rejoining %s...") % rejoin_room.code
	s.rejoin(game_id, str(rejoin_room.code), as_host, str(rejoin_room.get("id", "")))

func _on_rejoin_waiting(code: String) -> void:
	_status.text = tr("Back in game %s. Waiting for your friend...") % code

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 80)
	b.add_theme_font_size_override("font_size", 30)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _set_busy(busy: bool) -> void:
	_host_btn.disabled = busy
	_join_btn.disabled = busy
	_rejoin_btn.disabled = busy
	_code_edit.editable = not busy
	_name_edit.editable = not busy

func _on_code_changed(t: String) -> void:
	var caret := _code_edit.caret_column
	_code_edit.text = t.to_upper()
	_code_edit.caret_column = caret

func _new_session() -> Node:
	_reset_session()
	session = OnlineSession.new()
	session.my_name = _my_name()
	add_child(session)
	return session

func _reset_session() -> void:
	if session != null and is_instance_valid(session):
		session.queue_free()
	session = null

func _on_host() -> void:
	var s := _new_session()
	s.room_created.connect(_on_room_created)
	s.opponent_joined.connect(_on_both_in.bind(1), CONNECT_ONE_SHOT)
	_set_busy(true)
	_status.text = tr("Creating a game...")
	s.host(game_id)

func _on_room_created(code: String) -> void:
	_code_label.text = code
	_code_label.visible = true
	_status.text = tr("Tell your friend this code.\nWaiting for them to join...")

func _on_join() -> void:
	var code := _code_edit.text.strip_edges()
	if code.length() != OnlineSession.CODE_LENGTH:
		_status.text = tr("Type the %d-letter code from your friend.") % OnlineSession.CODE_LENGTH
		return
	var s := _new_session()
	s.joined.connect(_on_both_in.bind(2), CONNECT_ONE_SHOT)
	s.join_failed.connect(_on_join_failed)
	_set_busy(true)
	_status.text = tr("Joining %s...") % code
	s.join(game_id, code)

func _on_join_failed(reason: String) -> void:
	_set_busy(false)
	_status.text = reason
	_reset_session()
	if not rejoin_room.is_empty():
		_rejoin_btn.visible = true  # the host may just be slow to come back

func _on_both_in(my_player: int) -> void:
	visible = false
	started.emit(session, my_player)

func _on_cancel() -> void:
	_reset_session()
	visible = false
	cancelled.emit()
