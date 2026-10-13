extends "res://scripts/hub/hub_screen.gd"

## A friend's page (tap a row on the Friends screen): avatar, gamer tag, Viral
## Power, what they're doing now, the games they've earned Viral XP in, and a
## per-game "compare achievements" (mine vs theirs). Invite and a "..." menu
## to remove them. Which friend comes from `Social.viewing` (a social_list row);
## the details come from the server (player_overview / player_compare), which
## only answers for friends who haven't set themselves to private.

const Avatar = preload("res://scripts/common/avatar.gd")
const FRIENDS_SCENE := "res://scenes/hub/friends.tscn"

var _overview: Variant = null       # null = loading, {} = failed, else the server's answer
var _compare_game: String = ""      # "" = the overview, else the game being compared
var _compare_rows: Variant = null   # null = loading, [] = none

func _title() -> String:
	return tr("Player")

func _ready() -> void:
	super()
	Social.friends_changed.connect(rebuild)
	var id := str(Social.viewing.get("user_id", ""))
	if id != "":
		Social.fetch_overview(id, _on_overview)

func _on_overview(ok: bool, data: Variant) -> void:
	if not is_inside_tree():
		return
	_overview = data if ok and data is Dictionary else {}
	rebuild()

## Back: from a comparison to the overview, else to the friends list.
func go_hub() -> void:
	if _compare_game != "":
		_compare_game = ""
		_compare_rows = null
		rebuild()
		return
	get_tree().change_scene_to_file(FRIENDS_SCENE)

func _friend() -> Dictionary:
	var id := str(Social.viewing.get("user_id", ""))
	for f in Social.friends:
		if str(f.get("user_id", "")) == id and str(f.get("status", "")) == "friend":
			return f
	return {}

func _build() -> void:
	var f := _friend()
	if f.is_empty():
		var box := section("")
		box.add_child(label(tr("This player isn't on your friends list."), 26, null, true, true))
		return
	if _compare_game != "":
		_build_compare(f)
		return
	_build_overview(f)

func _build_overview(f: Dictionary) -> void:
	var card := section("")
	var face := CenterContainer.new()
	face.add_child(Avatar.make(str(f.get("avatar", "")), 120.0))
	card.add_child(face)
	card.add_child(label(str(f.get("display_name", "Player")), 36, pal.accent, true, true))
	var hidden: bool = _overview is Dictionary and bool(_overview.get("private", false))
	if f.has("viral_power") and not hidden:
		card.add_child(label(tr("%s Viral Power") % Social.format_number(int(f.viral_power)), 28, null, true, true))
	card.add_child(label(Social.activity_text(f), 24, pal.text_dim, true, true))
	var online: bool = bool(f.get("online", false))
	var inv := pill(tr("🎮 Invite"), online, 26)
	inv.disabled = not online
	inv.pressed.connect(_on_invite.bind(f))
	card.add_child(inv)
	var more := Button.new()
	more.text = tr("⋯ More")
	more.flat = true
	more.focus_mode = Control.FOCUS_NONE
	more.add_theme_font_size_override("font_size", 20)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		more.add_theme_color_override(key, pal.text_dim)
	more.pressed.connect(_on_more.bind(f))
	card.add_child(more)

	var games := section(tr("Games played"))
	if _overview == null:
		games.add_child(dim(tr("Loading...")))
	elif not (_overview is Dictionary) or _overview.is_empty():
		games.add_child(dim(tr("Couldn't load their games right now. Try again later.")))
	elif hidden:
		games.add_child(dim(tr("%s keeps their games and achievements private.") % str(f.get("display_name", "Player"))))
	elif (_overview.get("games", []) as Array).is_empty():
		games.add_child(dim(tr("No achievements yet.")))
	else:
		games.add_child(dim(tr("Tap a game to compare achievements."), 20))
		for g in _overview.games:
			games.add_child(_game_row(g))

func _game_row(g: Dictionary) -> Control:
	var gid := str(g.get("game", ""))
	var entry: Dictionary = Catalog.get_game(gid)
	var title: String = Lang.pick(entry, "title") if not entry.is_empty() else (tr("Viral Game Hub") if gid == "hub" else gid)
	var root := Control.new()
	root.custom_minimum_size = Vector2(0, 76)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	root.add_child(hit)
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(_open_compare.bind(gid))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon := Label.new()
	icon.text = str(entry.get("icon", "🎮")) if not entry.is_empty() else "🎮"
	icon.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	icon.add_theme_font_size_override("font_size", 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var name_l := label(title, 25, null, false)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_l)
	var xp := label(tr("%s XP") % Social.format_number(int(g.get("xp", 0))), 24, pal.accent, false)
	xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(xp)
	return root

func _open_compare(game_id: String) -> void:
	if not tapped():
		return
	_compare_game = game_id
	_compare_rows = null
	rebuild()
	Social.fetch_compare(str(Social.viewing.get("user_id", "")), game_id, _on_compare.bind(game_id))

func _on_compare(ok: bool, rows: Variant, game_id: String) -> void:
	if not is_inside_tree() or game_id != _compare_game:
		return
	_compare_rows = rows if ok and rows is Array else []
	rebuild()

## Per game: every challenge either of you has earned, mine vs theirs.
func _build_compare(f: Dictionary) -> void:
	var entry: Dictionary = Catalog.get_game(_compare_game)
	var title: String = Lang.pick(entry, "title") if not entry.is_empty() else (tr("Viral Game Hub") if _compare_game == "hub" else _compare_game)
	var box := section(tr("Compare: %s") % title)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	for who in [tr("You"), str(f.get("display_name", "Player"))]:
		var l := label(who, 20, pal.link, false, true)
		l.custom_minimum_size = Vector2(120, 0)
		l.clip_text = true
		head.add_child(l)
	if _compare_rows == null:
		box.add_child(dim(tr("Loading...")))
		return
	if (_compare_rows as Array).is_empty():
		box.add_child(dim(tr("No achievements to compare yet.")))
		return
	for r in _compare_rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := label(str(r.get("icon", "🏅")), 30, null, false)
		icon.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := label(tr(str(r.get("title", ""))), 22, null, false)
		t.clip_text = true
		col.add_child(t)
		col.add_child(dim(tr("%d XP") % int(r.get("xp", 0)), 18))
		row.add_child(col)
		row.add_child(_mark(r.get("mine")))
		row.add_child(_mark(r.get("theirs")))
		box.add_child(row)

## "✓ 12 Oct" or "—" (not earned), in a fixed-width column.
func _mark(unix: Variant) -> Label:
	var l := label("—", 20, pal.text_dim, false, true)
	if unix != null:
		var d := Time.get_datetime_dict_from_unix_time(int(unix))
		l.text = "✓ %d/%d/%02d" % [d.day, d.month, int(d.year) % 100]
		l.add_theme_color_override("font_color", pal.ready)
	l.custom_minimum_size = Vector2(120, 0)
	return l

func _on_invite(f: Dictionary) -> void:
	if tapped():
		pick_game_for(f)

func _on_more(f: Dictionary) -> void:
	if not tapped():
		return
	var box := dialog(str(f.get("display_name", "Player")))
	var rm := pill(tr("Remove friend"), false)
	rm.pressed.connect(_confirm_remove.bind(f))
	box.add_child(rm)
	var no := pill(tr("Cancel"), false)
	no.pressed.connect(close_dialog)
	box.add_child(no)

## Named confirmation: nobody is removed with one tap.
func _confirm_remove(f: Dictionary) -> void:
	if not tapped():
		return
	var name := str(f.get("display_name", "Player"))
	var box := dialog(tr("Remove %s?") % name)
	box.add_child(label(tr("You can add each other again later with your friend codes."), 24, pal.card_message, true, true))
	var yes := pill(tr("Remove %s") % name, true, 26)
	yes.pressed.connect(_remove.bind(str(f.user_id)))
	box.add_child(yes)
	var no := pill(tr("Cancel"), false, 26)
	no.pressed.connect(close_dialog)
	box.add_child(no)

func _remove(user_id: String) -> void:
	if tapped():
		close_dialog()
		Social.remove(user_id)
		_compare_game = ""
		go_hub()
