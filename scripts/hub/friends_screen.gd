extends "res://scripts/hub/hub_screen.gd"

## 👥 Friends (since v0.25): your friend code, adding a friend by theirs,
## requests to accept, and your friends with who's online now and an
## "🎮 Invite" button (picks an online game, opens it hosting, and sends the
## invite as soon as the room exists). All of it is the Social autoload; the
## server side is supabase/migrations/20261004000000_friends.sql.

var code_edit: LineEdit
var add_status: Label
var _status_text: String = ""
var _typed: String = ""  # survives the rebuild when the friend list refreshes

func _title() -> String:
	return tr("👥 Friends")

func _ready() -> void:
	super()
	Social.friends_changed.connect(rebuild)
	Social.code_changed.connect(rebuild.unbind(1))
	Auth.signed_in.connect(rebuild.unbind(2))
	Auth.signed_out.connect(rebuild)
	Social.refresh()

func _build() -> void:
	if not Auth.is_logged_in():
		var box := section("")
		box.add_child(label(tr("Sign in to add friends, see who's online and invite them to play."), 26, null, true, true))
		var b := pill(tr("Sign In"), true, 26)
		b.pressed.connect(_sign_in)
		box.add_child(b)
		return
	if not Social.available:
		var box := section("")
		box.add_child(label(tr("Connecting..."), 26, null, true, true))
		box.add_child(dim(tr("If this doesn't change, friends aren't available right now. Check your connection and try again later.")))
		return

	var me := section(tr("Your friend code"))
	me.add_child(label(Social.friend_code, 64, pal.accent, false, true))
	me.add_child(dim(tr("Give this code to a friend. They type it below on their phone.")))
	var copy := pill(tr("📋 Copy code"), false)
	copy.pressed.connect(_copy_code)
	me.add_child(copy)

	var add := section(tr("Add a friend"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add.add_child(row)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = tr("Friend code")
	code_edit.max_length = 6
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.custom_minimum_size = Vector2(0, 72)
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.add_theme_font_size_override("font_size", 36)
	code_edit.text = _typed
	code_edit.text_changed.connect(_on_code_changed)
	code_edit.text_submitted.connect(_on_add.unbind(1))
	row.add_child(code_edit)
	var add_btn := pill(tr("Add"), true, 28)
	add_btn.custom_minimum_size = Vector2(140, 72)
	add_btn.pressed.connect(_on_add)
	row.add_child(add_btn)
	add_status = dim(_status_text)
	add_status.visible = _status_text != ""
	add.add_child(add_status)

	var incoming: Array = Social.friends.filter(func(f): return f.status == "incoming")
	var outgoing: Array = Social.friends.filter(func(f): return f.status == "outgoing")
	var mates: Array = Social.friends.filter(func(f): return f.status == "friend")

	if not incoming.is_empty():
		var req := section(tr("Friend requests"))
		for f in incoming:
			var r := _person_row(f, tr("wants to be your friend"))
			var yes := pill("✓", true, 28)
			yes.custom_minimum_size = Vector2(72, 60)
			yes.pressed.connect(_respond.bind(str(f.user_id), true))
			r.add_child(yes)
			var no := pill("✕", false, 28)
			no.custom_minimum_size = Vector2(72, 60)
			no.pressed.connect(_respond.bind(str(f.user_id), false))
			r.add_child(no)
			req.add_child(r)

	var fb := section(tr("Friends (%d)") % mates.size())
	if mates.is_empty():
		fb.add_child(dim(tr("No friends yet. Share your code to get started!")))
	for f in mates:
		var online: bool = bool(f.get("online", false))
		var r := _person_row(f, tr("🟢 Online now") if online else tr("Last seen %s") % _ago(str(f.get("last_seen", ""))))
		var inv := pill(tr("🎮 Invite"), online, 22)
		inv.pressed.connect(_on_invite.bind(f))
		r.add_child(inv)
		var x := pill("✕", false, 24)
		x.custom_minimum_size = Vector2(60, 60)
		x.pressed.connect(_confirm_remove.bind(f))
		r.add_child(x)
		fb.add_child(r)

	if not outgoing.is_empty():
		var out := section(tr("Waiting for them to accept"))
		for f in outgoing:
			var r := _person_row(f, "")
			var x := pill(tr("Cancel"), false, 22)
			x.pressed.connect(_remove.bind(str(f.user_id)))
			r.add_child(x)
			out.add_child(r)

func _person_row(f: Dictionary, sub: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := label(str(f.get("display_name", "Player")), 27, null, false)
	name_l.clip_text = true
	col.add_child(name_l)
	if sub != "":
		col.add_child(dim(sub, 19))
	row.add_child(col)
	return row

## "5 min ago", "3 h ago", "2 days ago" from an ISO time.
func _ago(iso: String) -> String:
	var t := Time.get_unix_time_from_datetime_string(iso.left(19))
	var s: int = int(Time.get_unix_time_from_system()) - int(t)
	if iso == "" or s < 0:
		return "?"
	if s < 3600:
		return tr("%d min ago") % maxi(1, s / 60)
	if s < 86400:
		return tr("%d h ago") % (s / 3600)
	return tr("%d days ago") % (s / 86400)

func _on_code_changed(t: String) -> void:
	var caret := code_edit.caret_column
	code_edit.text = t.to_upper()
	code_edit.caret_column = caret
	_typed = code_edit.text

func _on_add() -> void:
	if not tapped() or code_edit == null:
		return
	var c := code_edit.text.strip_edges()
	if c.length() != 6:
		_set_status(tr("Friend codes are 6 letters."))
		return
	_set_status(tr("Adding..."))
	Social.add_friend(c, _on_added)

func _on_added(result: String) -> void:
	match result:
		"sent", "accepted":
			_typed = ""
	match result:
		"sent":
			_status_text = tr("Request sent! You'll be friends once they accept.")
		"accepted":
			_status_text = tr("You're friends now!")
		"already":
			_status_text = tr("You've already added them.")
		"self":
			_status_text = tr("That's your own code!")
		"not_found":
			_status_text = tr("No player has that code. Check it and try again.")
		_:
			_status_text = tr("Couldn't reach the server. Check your connection and try again.")
	_set_status(_status_text)

func _set_status(t: String) -> void:
	_status_text = t
	if add_status and is_instance_valid(add_status):
		add_status.text = t
		add_status.visible = t != ""

func _respond(user_id: String, accept: bool) -> void:
	if tapped():
		Social.respond(user_id, accept)

func _remove(user_id: String) -> void:
	if tapped():
		close_dialog()
		Social.remove(user_id)

func _confirm_remove(f: Dictionary) -> void:
	if not tapped():
		return
	var box := dialog(tr("Remove %s?") % str(f.get("display_name", "Player")))
	box.add_child(label(tr("You can add each other again later with your friend codes."), 24, pal.card_message, true, true))
	var yes := pill(tr("Remove"), true, 26)
	yes.pressed.connect(_remove.bind(str(f.user_id)))
	box.add_child(yes)
	var no := pill(tr("Cancel"), false, 26)
	no.pressed.connect(close_dialog)
	box.add_child(no)

func _on_invite(f: Dictionary) -> void:
	if tapped():
		pick_game_for(f)

func _copy_code() -> void:
	if tapped():
		DisplayServer.clipboard_set(Social.friend_code)
		_set_status(tr("Code copied."))

func _sign_in() -> void:
	if tapped():
		get_tree().change_scene_to_file("res://scenes/account/account.tscn")
