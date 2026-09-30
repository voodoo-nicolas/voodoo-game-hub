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

var game_id: String
var game_title: String
var session: Node = null

var _menu: Control
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

	box.add_child(_label("🌐 Play %s Online" % game_title, 36, Color(1, 1, 1)))

	_host_btn = _button("Host a Game")
	_host_btn.pressed.connect(_on_host)
	box.add_child(_host_btn)

	box.add_child(_label("— or join a friend's game —", 24, Color(0.7, 0.72, 0.78)))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 12)
	box.add_child(join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "CODE"
	_code_edit.max_length = OnlineSession.CODE_LENGTH
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.custom_minimum_size = Vector2(240, 80)
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.add_theme_font_size_override("font_size", 40)
	_code_edit.text_changed.connect(_on_code_changed)
	_code_edit.text_submitted.connect(func(_t): _on_join())
	join_row.add_child(_code_edit)
	_join_btn = _button("Join")
	_join_btn.custom_minimum_size = Vector2(180, 80)
	_join_btn.pressed.connect(_on_join)
	join_row.add_child(_join_btn)

	_code_label = _label("", 64, Color(1, 0.84, 0.3))
	_code_label.visible = false
	box.add_child(_code_label)
	_status = _label("", 26, Color(0.85, 0.9, 0.87))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)

	var cancel := _button("Cancel")
	cancel.pressed.connect(_on_cancel)
	box.add_child(cancel)

func open() -> void:
	_reset_session()
	_code_edit.text = ""
	_code_label.visible = false
	_status.text = ""
	_set_busy(false)
	visible = true

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
	_code_edit.editable = not busy

func _on_code_changed(t: String) -> void:
	var caret := _code_edit.caret_column
	_code_edit.text = t.to_upper()
	_code_edit.caret_column = caret

func _new_session() -> Node:
	_reset_session()
	session = OnlineSession.new()
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
	_status.text = "Creating a game..."
	s.host(game_id)

func _on_room_created(code: String) -> void:
	_code_label.text = code
	_code_label.visible = true
	_status.text = "Tell your friend this code.\nWaiting for them to join..."

func _on_join() -> void:
	var code := _code_edit.text.strip_edges()
	if code.length() != OnlineSession.CODE_LENGTH:
		_status.text = "Type the %d-letter code from your friend." % OnlineSession.CODE_LENGTH
		return
	var s := _new_session()
	s.joined.connect(_on_both_in.bind(2), CONNECT_ONE_SHOT)
	s.join_failed.connect(_on_join_failed)
	_set_busy(true)
	_status.text = "Joining %s..." % code
	s.join(game_id, code)

func _on_join_failed(reason: String) -> void:
	_set_busy(false)
	_status.text = reason
	_reset_session()

func _on_both_in(my_player: int) -> void:
	visible = false
	started.emit(session, my_player)

func _on_cancel() -> void:
	_reset_session()
	visible = false
	cancelled.emit()
