extends ColorRect

## The shared lobby for tables of 2 to 6 people (since v0.39): host a table
## (a code, QR, invites to several friends) or join one by code, see who has
## sat down, and -- for the host -- Start. Emits `started(room, my_player)`
## on every phone when the host starts (host = player 1), then hides. The
## OnlineRoom stays a child of this node. Used by OnlineTable; games never
## load it themselves.

const OnlineRoom = preload("res://scripts/common/online_room.gd")
const OnlineLobby = preload("res://scripts/common/online_lobby.gd")
const UI = preload("res://scripts/common/ui.gd")
const QR = preload("res://scripts/common/qr.gd")
const Config = preload("res://scripts/common/config.gd")
const Brand = preload("res://scripts/common/brand.gd")

signal started(room: Node, my_player: int)
signal cancelled()

var game_id: String
var game_title: String
var room: Node = null
## {code, host: bool, id, seats} of a table this app can take its seat at
## again (set by OnlineTable from its saved room), or empty.
var rejoin_room: Dictionary = {}
var min_players: int = 2
var max_players: int = 6
## The host's description of the table, shown to everyone in the lobby.
var note: String = ""
## The room class (tools/test_online_table.gd swaps in one without a network).
var room_script: Script = OnlineRoom

var _name_edit: LineEdit
var _rejoin_btn: Button
var _join_title: Label
var _join_row: HBoxContainer
var _code_edit: LineEdit
var _join_btn: Button
var _note_label: Label
var _code_label: Label
var _qr_rect: TextureRect
var _share_row: HBoxContainer
var _share_text: String = ""
var _seat_box: VBoxContainer
var _invite_btn: Button
var _friend_box: VBoxContainer
var _status: Label
var _start_btn: Button
var _invited: Dictionary = {}   # friend user id -> true once invited
var _auto_friends: bool = false
var _auto_invite: Dictionary = {}

func _init(p_game_id: String = "", p_title: String = "") -> void:
	game_id = p_game_id
	game_title = p_title

func _ready() -> void:
	color = Color(0, 0, 0, 0.88)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	center.add_child(m)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	m.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)

	var title := _label(tr("🌐 %s: friends table") % game_title, 34, Color(1, 1, 1))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(title)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	box.add_child(name_row)
	name_row.add_child(_label(tr("Your name"), 26, Color(0.75, 0.78, 0.85)))
	_name_edit = LineEdit.new()
	_name_edit.max_length = OnlineLobby.NAME_MAX
	_name_edit.placeholder_text = tr("Player")
	_name_edit.custom_minimum_size = Vector2(0, 64)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 30)
	_name_edit.text = OnlineLobby.load_name()
	name_row.add_child(_name_edit)

	_note_label = _label("", 24, Color(1, 0.84, 0.3))
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_note_label)
	_rejoin_btn = _button("")
	_rejoin_btn.pressed.connect(_on_rejoin)
	box.add_child(_rejoin_btn)
	# Hosting starts from the game's own setup screen (open_host): here, joining.
	_join_title = _label(tr("Type the table code from your friend:"), 24, Color(0.7, 0.72, 0.78))
	_join_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_join_title)
	_join_row = HBoxContainer.new()
	_join_row.add_theme_constant_override("separation", 12)
	box.add_child(_join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = tr("Code")
	_code_edit.max_length = OnlineRoom.TABLE_CODE_LENGTH
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.custom_minimum_size = Vector2(240, 80)
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.add_theme_font_size_override("font_size", 40)
	_code_edit.text_changed.connect(_on_code_changed)
	_code_edit.text_submitted.connect(_on_join.unbind(1))
	_join_row.add_child(_code_edit)
	_join_btn = _button(tr("Join"))
	_join_btn.custom_minimum_size = Vector2(180, 80)
	_join_btn.pressed.connect(_on_join)
	_join_row.add_child(_join_btn)

	_code_label = _label("", 64, Color(1, 0.84, 0.3))
	box.add_child(_code_label)
	_qr_rect = TextureRect.new()
	_qr_rect.custom_minimum_size = Vector2(200, 200)
	_qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_qr_rect)
	_share_row = HBoxContainer.new()
	_share_row.add_theme_constant_override("separation", 12)
	box.add_child(_share_row)
	var copy_btn := _button(tr("📋 Copy invite"))
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_btn.pressed.connect(_on_copy_invite)
	_share_row.add_child(copy_btn)
	var wa_btn := _button(tr("💬 WhatsApp"))
	wa_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wa_btn.pressed.connect(_on_whatsapp)
	_share_row.add_child(wa_btn)

	_seat_box = VBoxContainer.new()
	_seat_box.add_theme_constant_override("separation", 6)
	box.add_child(_seat_box)
	_invite_btn = _button(tr("📨 Invite friends"))
	_invite_btn.pressed.connect(_show_friends)
	box.add_child(_invite_btn)
	_friend_box = VBoxContainer.new()
	_friend_box.add_theme_constant_override("separation", 8)
	box.add_child(_friend_box)
	_status = _label("", 26, Color(0.85, 0.9, 0.87))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)
	_start_btn = _button(tr("Start the game"))
	_start_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
	_start_btn.pressed.connect(_on_start)
	box.add_child(_start_btn)
	var cancel := _button(tr("Leave"))
	cancel.pressed.connect(_on_cancel)
	box.add_child(cancel)
	_show_menu(true)

## Join by code (and Rejoin when there's a saved table).
func open() -> void:
	_reset_room()
	_code_edit.text = ""
	_status.text = ""
	_invited = {}
	_show_menu(true)
	_rejoin_btn.visible = not rejoin_room.is_empty()
	if not rejoin_room.is_empty():
		_rejoin_btn.text = tr("↩ Rejoin table %s") % rejoin_room.code
		_status.text = tr("You were at table %s when you left. Rejoin to pick up where you were.") % rejoin_room.code
	visible = true

## The game's setup screen chose the table: host it straight away.
func open_host() -> void:
	open()
	_on_host()

## Opened from an invite or the hub (Social.launch_online, through OnlineTable).
func auto_start(p: Dictionary) -> void:
	match str(p.get("mode", "")):
		"join":
			open()
			_code_edit.text = str(p.get("code", ""))
			_on_join()
		_:
			open()

# ---------- screens ----------

## true: join (or rejoin) by code; false: the table's waiting room.
func _show_menu(menu: bool) -> void:
	_name_edit.editable = menu
	_rejoin_btn.visible = menu and not rejoin_room.is_empty()
	_join_title.visible = menu
	_join_row.visible = menu
	_code_label.visible = not menu and room != null and str(room.code) != ""
	_qr_rect.visible = _code_label.visible and _qr_rect.texture != null
	_share_row.visible = _code_label.visible
	_seat_box.visible = not menu
	_invite_btn.visible = false
	_friend_box.visible = false
	_start_btn.visible = false
	_note_label.visible = note != "" and not menu
	_note_label.text = note

func _render_seats() -> void:
	if room == null:
		return
	for c in _seat_box.get_children():
		c.queue_free()
	var cap: int = int(room.max_players)
	_seat_box.add_child(_label(tr("Players: %d of %d") % [room.seats.size(), cap], 26, Color(0.75, 0.78, 0.85)))
	for i in room.seats.size():
		var s: Dictionary = room.seats[i]
		var nm := str(s.get("name", ""))
		if nm == "":
			nm = tr("Player %d") % (i + 1)
		var text := ("🟢 " if room.is_here(str(s.id)) else "⚪ ") + nm
		if i == 0:
			text += "  " + tr("(host)")
		if str(s.id) == str(room.my_id):
			text += "  " + tr("(you)")
		var l := _label(text, 28, Color(1, 1, 1))
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_seat_box.add_child(l)
	note = str(room.note) if str(room.note) != "" else note
	_note_label.text = note
	_note_label.visible = note != ""
	if room.is_host:
		var n: int = room.seats.size()
		_start_btn.visible = true
		_start_btn.disabled = n < min_players
		_status.text = tr("Waiting for friends to join...") if n < min_players else tr("Start when everyone is here.")
	elif room.my_player() > 0:
		_status.text = tr("You have a seat. Waiting for the host to start...")

# ---------- host ----------

func _new_room() -> Node:
	_reset_room()
	room = room_script.new()
	room.my_name = _my_name()
	room.max_players = max_players
	room.note = note
	room.roster_changed.connect(_render_seats)
	room.message.connect(_on_room_message)
	add_child(room)
	return room

func _reset_room() -> void:
	if room != null and is_instance_valid(room):
		room.queue_free()
	room = null
	_qr_rect.texture = null

func _on_host() -> void:
	var r := _new_room()
	r.room_created.connect(_on_room_created)
	_show_menu(false)
	_status.text = tr("Opening a table...")
	r.host(game_id)

func _on_room_created(code: String) -> void:
	_code_label.text = code
	_show_join_link(code)
	_show_menu(false)
	var social := _social()
	_invite_btn.visible = social != null and social.available
	if not _auto_invite.is_empty() and social:
		_send_invite(str(_auto_invite.user_id), str(_auto_invite.get("name", "")))
		_auto_invite = {}
	elif _auto_friends and _invite_btn.visible:
		_show_friends()
	_auto_friends = false
	_render_seats()

func _on_start() -> void:
	if room == null or not room.is_host or room.seats.size() < min_players:
		return
	room.start_table()
	room.send("start", {})
	_begin(1)

# ---------- join ----------

func _on_code_changed(t: String) -> void:
	var caret := _code_edit.caret_column
	_code_edit.text = t.to_upper()
	_code_edit.caret_column = caret

func _on_join() -> void:
	var code := _code_edit.text.strip_edges().to_upper()
	if code.length() != OnlineRoom.TABLE_CODE_LENGTH:
		_status.text = tr("Type the %d-letter table code from your friend.") % OnlineRoom.TABLE_CODE_LENGTH
		return
	var r := _new_room()
	r.joined.connect(_on_seated)
	r.join_failed.connect(_on_join_failed)
	_join_btn.disabled = true
	_status.text = tr("Joining %s...") % code
	r.join(game_id, code)

func _on_rejoin() -> void:
	var r := _new_room()
	var as_host: bool = bool(rejoin_room.get("host", false))
	if as_host:
		r.room_created.connect(_on_rejoined_host, CONNECT_ONE_SHOT)
	else:
		r.joined.connect(_on_seated)
		r.join_failed.connect(_on_join_failed)
	_status.text = tr("Rejoining %s...") % rejoin_room.code
	r.rejoin_table(game_id, str(rejoin_room.code), as_host, str(rejoin_room.get("id", "")), rejoin_room.get("seats", []))

## A returning host goes straight back to its table (the others still have the game).
func _on_rejoined_host(_code: String) -> void:
	_begin(1)

func _on_seated() -> void:
	_join_btn.disabled = false
	_code_label.text = str(room.code)
	_show_join_link(str(room.code))
	_show_menu(false)
	_render_seats()
	if room.locked:
		_begin(room.my_player())  # back at a table that already started

func _on_room_message(event: String, _p: Dictionary) -> void:
	if event == "start" and room != null and not room.is_host and room.my_player() > 0 and visible:
		_begin(room.my_player())

func _on_join_failed(reason: String) -> void:
	_join_btn.disabled = false
	_status.text = reason
	_reset_room()
	_show_menu(true)

func _begin(my_player: int) -> void:
	rejoin_room = {}
	visible = false
	started.emit(room, my_player)

func _on_cancel() -> void:
	_auto_invite = {}
	_auto_friends = false
	_reset_room()
	visible = false
	cancelled.emit()

# ---------- sharing ----------

func _my_name() -> String:
	var n := _name_edit.text.strip_edges().left(OnlineLobby.NAME_MAX)
	var f := FileAccess.open(OnlineLobby.NAME_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"name": n}))
	return n

func _show_join_link(code: String) -> void:
	var url := "%s?g=%s&c=%s" % [Config.JOIN_PAGE_URL, game_id.uri_encode(), code.uri_encode()]
	_share_text = tr("Join my %s table in %s! Code: %s") % [game_title, Brand.NAME, code] + "\n" + url
	var img: Image = QR.image(url, 6)
	if img:
		_qr_rect.texture = ImageTexture.create_from_image(img)

func _on_copy_invite() -> void:
	DisplayServer.clipboard_set(_share_text)
	_status.text = tr("Invite copied — paste it in any chat.")

func _on_whatsapp() -> void:
	OS.shell_open("https://wa.me/?text=" + _share_text.uri_encode())

func _social() -> Node:
	var s := get_node_or_null("/root/Social")
	return s if s and s.has_method("invite") else null

## Every friend gets a button; each can be invited once (✓ afterwards).
func _show_friends() -> void:
	var social := _social()
	for c in _friend_box.get_children():
		c.queue_free()
	_friend_box.visible = true
	_invite_btn.visible = false
	var list: Array = social.friends.filter(func(f): return str(f.get("status", "")) == "friend") if social else []
	if list.is_empty():
		_friend_box.add_child(_label(tr("No friends yet. Add them in the hub: 👥 Friends."), 22, Color(0.7, 0.72, 0.78)))
		return
	list.sort_custom(func(a, b): return bool(a.get("online", false)) and not bool(b.get("online", false)))
	for f in list.slice(0, 10):
		var b := _button("")
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 26)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.set_meta("friend", f)
		_paint_friend(b)
		b.pressed.connect(_send_invite.bind(str(f.user_id), str(f.get("display_name", ""))))
		_friend_box.add_child(b)

func _paint_friend(b: Button) -> void:
	var f: Dictionary = b.get_meta("friend")
	var sent: bool = _invited.has(str(f.user_id))
	b.text = ("✓ " if sent else ("🟢 " if bool(f.get("online", false)) else "⚪ ")) + str(f.get("display_name", "Player"))
	b.disabled = sent

func _send_invite(user_id: String, who: String) -> void:
	var social := _social()
	if social == null or room == null or str(room.code) == "" or _invited.has(user_id):
		return
	_invited[user_id] = true
	for b in _friend_box.get_children():
		if b is Button and b.has_meta("friend"):
			_paint_friend(b)
	_status.text = tr("Inviting %s...") % who
	social.invite(user_id, game_id, game_title, str(room.code), _on_invite_sent.bind(who, user_id))

func _on_invite_sent(ok: bool, who: String, user_id: String) -> void:
	if not is_inside_tree():
		return
	if ok:
		_status.text = tr("Invite sent to %s.") % who
	else:
		_invited.erase(user_id)
		for b in _friend_box.get_children():
			if b is Button and b.has_meta("friend"):
				_paint_friend(b)
		_status.text = tr("Couldn't send the invite. Check your connection and try again.")

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 80)
	b.add_theme_font_size_override("font_size", 30)
	b.focus_mode = Control.FOCUS_NONE
	return b
