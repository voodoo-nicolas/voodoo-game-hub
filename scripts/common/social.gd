extends Node

## Autoload `Social` (since v0.25): friends, game invites, and starting an
## online game from outside it. Server side is the social_* functions in
## supabase/migrations/20261004000000_friends.sql (run once in the SQL
## editor); until they exist, `available` stays false and the friend screens
## say so -- nothing else changes.
##
## - Friends: add by friend code (`add_friend`), accept / decline
##   (`respond`), `remove`. `friends` is the cached list: [{user_id,
##   display_name, status: "friend" | "incoming" | "outgoing", online}].
##   Refreshed on sign-in and every HEARTBEAT_SEC while the app is open
##   (which also marks this player online for their friends).
## - Invites: `invite(friend, game_id, title, room_code)` from the online
##   lobby; the friend's app polls `social_inbox` every INBOX_SEC and pops up
##   "Ana invites you to Chess -- Join". Settings.invites can silence them.
## - Starting a game in online mode: `launch_online(game_id, mode, code,
##   invite_to)` stores a request and goes to the hub, which opens the game
##   (downloading it first if needed); the shared OnlineMatch then calls
##   `take_pending(game_id)` and hosts / joins / opens its lobby by itself.
##   So no game code is involved -- every OnlineMatch game gets it.
##
## Games never reference Social directly (packs run on older apps): only
## the shared online_lobby.gd / online_match.gd do, through
## get_node_or_null("/root/Social").

const Achievements = preload("res://scripts/common/achievements.gd")
const Ui = preload("res://scripts/common/ui.gd")

const HEARTBEAT_SEC := 60.0
const INBOX_SEC := 12.0
const HUB_SCENE := "res://scenes/hub/hub.tscn"

signal friends_changed()
signal code_changed(code: String)

## False until the server answers social_me (SQL not run yet, offline, or signed out).
var available: bool = false
var friend_code: String = ""
var friends: Array = []
## {game, mode: "host" | "join" | "lobby", code, invite_to, invite_name}, or {}.
var pending: Dictionary = {}
## Set by launch_online for the hub to open (game id), or "".
var launch_request: String = ""

var _beat_left: float = 1.0
var _inbox_left: float = 4.0
var _busy_beat: bool = false
var _busy_inbox: bool = false
var _layer: CanvasLayer
var _invite_box: VBoxContainer
var _seen_invites: Dictionary = {}  # "sender|code" -> true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Auth.signed_in.connect(_on_signed_in.unbind(2))
	Auth.signed_out.connect(_on_signed_out)
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_invite_box = VBoxContainer.new()
	_invite_box.add_theme_constant_override("separation", 10)
	_invite_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_invite_box)

func _process(delta: float) -> void:
	if not Auth.is_logged_in():
		return
	_beat_left -= delta
	if _beat_left <= 0.0:
		_beat_left = HEARTBEAT_SEC
		refresh()
	_inbox_left -= delta
	if _inbox_left <= 0.0:
		_inbox_left = INBOX_SEC
		_poll_inbox()

func _notification(what: int) -> void:
	# Back from the background: catch up straight away.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_beat_left = minf(_beat_left, 0.5)
		_inbox_left = minf(_inbox_left, 0.5)

func _on_signed_in() -> void:
	_beat_left = 0.1
	_inbox_left = 2.0

func _on_signed_out() -> void:
	available = false
	friend_code = ""
	friends = []
	friends_changed.emit()

# ---------- friends ----------

## Marks me online, fetches my friend code and my friends.
func refresh() -> void:
	if _busy_beat or not Auth.is_logged_in():
		return
	_busy_beat = true
	Auth.db_call("social_me", {"p_name": Auth.get_display_name()}, _on_me)

func _on_me(ok: bool, result: Variant) -> void:
	if not ok or typeof(result) != TYPE_STRING:
		_busy_beat = false
		if available:
			available = false
			friends_changed.emit()
		return
	available = true
	if str(result) != friend_code:
		friend_code = str(result)
		code_changed.emit(friend_code)
	Auth.db_call("social_list", {}, _on_list)

func _on_list(ok: bool, result: Variant) -> void:
	_busy_beat = false
	if not ok or typeof(result) != TYPE_ARRAY:
		return
	friends = result
	var n := friend_ids(false).size()
	_announce_hub(Achievements.check_hub({"friends": n}))
	friends_changed.emit()

## Accepted friends' user ids (plus mine when include_me).
func friend_ids(include_me: bool = true) -> Array:
	var ids: Array = []
	for f in friends:
		if str(f.get("status", "")) == "friend":
			ids.append(str(f.user_id))
	if include_me and Auth.is_logged_in():
		ids.append(Auth.user_id)
	return ids

func online_friends() -> Array:
	return friends.filter(func(f): return str(f.get("status", "")) == "friend" and bool(f.get("online", false)))

## on_done.call(result) -- "sent", "accepted", "already", "self",
## "not_found", or "" when it couldn't reach the server.
func add_friend(code: String, on_done: Callable) -> void:
	Auth.db_call("social_add", {"p_code": code.strip_edges().to_upper()}, _on_add.bind(on_done))

func _on_add(ok: bool, result: Variant, on_done: Callable) -> void:
	_safe_call(on_done, [str(result) if ok and typeof(result) == TYPE_STRING else ""])
	refresh()

func respond(user_id: String, accept: bool) -> void:
	Auth.db_call("social_respond", {"p_other": user_id, "p_accept": accept}, _after_change)

func remove(user_id: String) -> void:
	Auth.db_call("social_remove", {"p_other": user_id}, _after_change)

func _after_change(_ok: bool, _result: Variant) -> void:
	_busy_beat = false
	refresh()

# ---------- invites ----------

## Invites a friend into the online room `code` of `game_id`. on_done(ok).
func invite(user_id: String, game_id: String, title: String, code: String, on_done: Callable = Callable()) -> void:
	Auth.db_call("social_invite", {"p_other": user_id, "p_game": game_id, "p_code": code, "p_title": title},
		_on_invited.bind(on_done))

func _on_invited(ok: bool, result: Variant, on_done: Callable) -> void:
	var sent: bool = ok and result == true
	if sent:
		var hub := Achievements.load_hub()
		_announce_hub(Achievements.check_hub({"invites": int(hub.get("invites", 0)) + 1}))
	_safe_call(on_done, [sent])

func _poll_inbox() -> void:
	if _busy_inbox or not available:
		return
	_busy_inbox = true
	Auth.db_call("social_inbox", {}, _on_inbox)

func _on_inbox(ok: bool, result: Variant) -> void:
	_busy_inbox = false
	if not ok or typeof(result) != TYPE_ARRAY:
		return
	var settings = get_node_or_null("/root/Settings")
	if settings and settings.has_method("invites_allowed") and not settings.invites_allowed():
		return  # taken from the server and dropped: the player blocked them
	for inv in result:
		if typeof(inv) != TYPE_DICTIONARY:
			continue
		var key := "%s|%s" % [inv.get("sender", ""), inv.get("room_code", "")]
		if _seen_invites.has(key) or _in_that_room(inv):
			continue
		_seen_invites[key] = true
		_show_invite(inv)

func _in_that_room(inv: Dictionary) -> bool:
	var scene := get_tree().current_scene
	var m := scene.get_node_or_null("OnlineMatch") if scene else null
	return m != null and m.session != null and str(m.session.code) == str(inv.get("room_code", ""))

# ---------- launching a game in online mode ----------

## Opens `game_id` straight into online play: mode "host" (and invite
## `invite_to` once the room exists), "join" room `code`, or "lobby".
## Goes through the hub, which downloads the game first if needed.
func launch_online(game_id: String, mode: String, code: String = "", invite_to: String = "", invite_name: String = "") -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("_save_game"):
		scene.call("_save_game")  # leaving a game for an invite keeps its progress
	pending = {"game": game_id, "mode": mode, "code": code, "invite_to": invite_to, "invite_name": invite_name,
		"t": Time.get_ticks_msec()}
	launch_request = game_id
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE)

## The hub's part: the game to open now, once.
func take_launch_request() -> String:
	var g := launch_request
	launch_request = ""
	return g

## OnlineMatch's part: the online request for this game, once (stale after
## two minutes, e.g. a download that was cancelled).
func take_pending(game_id: String) -> Dictionary:
	if pending.is_empty() or str(pending.get("game", "")) != game_id:
		return {}
	var p := pending
	pending = {}
	if Time.get_ticks_msec() - int(p.get("t", 0)) > 120000:
		return {}
	return p

# ---------- pop-ups ----------

func _show_invite(inv: Dictionary) -> void:
	var game_id := str(inv.get("game", ""))
	var game: Dictionary = Catalog.get_game(game_id) if has_node("/root/Catalog") else {}
	if game.is_empty():
		return
	var title: String = Lang.pick(game, "title") if has_node("/root/Lang") else str(inv.get("title", game_id))
	var panel := _popup_panel()
	var box: VBoxContainer = panel.get_child(0)
	box.add_child(_label(tr("🎮 %s invites you to play %s") % [str(inv.get("sender_name", "Player")), title], 26, Color(1, 1, 1)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var join := _button(tr("Join"), Color(0.25, 1.0, 0.6))
	join.pressed.connect(_on_join_invite.bind(panel, game_id, str(inv.get("room_code", ""))))
	row.add_child(join)
	var no := _button(tr("Not now"), Color(0.62, 0.66, 0.78))
	no.pressed.connect(_close_popup.bind(panel))
	row.add_child(no)
	var sfx = get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("notify")
	var settings = get_node_or_null("/root/Settings")
	if settings:
		settings.buzz(settings.RESULT_BUZZ_MS)
	# Gone by itself after a minute: the room may be over by then.
	var tw := panel.create_tween()
	tw.tween_interval(60.0)
	tw.tween_callback(_close_popup.bind(panel))

func _on_join_invite(panel: Control, game_id: String, code: String) -> void:
	_close_popup(panel)
	launch_online(game_id, "join", code)

## Short notes ("Achievement unlocked: Friendly") that fade by themselves.
func toast(text: String) -> void:
	var panel := _popup_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.get_child(0).add_child(_label(text, 24, Color(1, 0.85, 0.35)))
	var tw := panel.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_close_popup.bind(panel))

func _announce_hub(unlocked: Array) -> void:
	for h in unlocked:
		toast("%s  %s: %s" % [h[1], tr("Achievement unlocked!"), tr(h[2])])
	if not unlocked.is_empty() and Auth.is_logged_in():
		Auth.submit_score(Achievements.BOARD_ID, Achievements.total_unlocked())

func _popup_panel() -> PanelContainer:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = minf(vp.x - 32.0, 600.0)
	_invite_box.position = Vector2((vp.x - w) / 2.0, 80.0)
	_invite_box.custom_minimum_size = Vector2(w, 0)
	var panel := PanelContainer.new()
	var sb := Ui.panel_style()
	sb.border_color = Color(0.8, 0.45, 1.0)
	sb.shadow_color = Color(0.8, 0.45, 1.0, 0.5)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_invite_box.add_child(panel)
	return panel

func _close_popup(panel: Control) -> void:
	if is_instance_valid(panel):
		panel.queue_free()

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", color)
	return b

static func _safe_call(cb: Callable, args: Array) -> void:
	if cb.is_valid():
		cb.callv(args)
