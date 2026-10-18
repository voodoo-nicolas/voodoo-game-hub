extends "res://scripts/hub/hub_screen.gd"

## 👤 Profile (STANDARDS §2b, since v0.30): who you are, what you've played
## across the whole hub, and the hub-wide screens that used to sit on the
## home screen (🏆 Leaderboards, 🏅 Achievements, 👥 Friends, 🎮 Multiplayer).
## Everything is read from the games' stats files and the hub's own records
## (HubData), so no pack has to be mounted.

const Achievements = preload("res://scripts/common/achievements.gd")
const HubData = preload("res://scripts/common/hub_data.gd")
const Avatar = preload("res://scripts/common/avatar.gd")
const AvatarEditor = preload("res://scripts/hub/avatar_editor.gd")
const PHOTO_EXTENSIONS := ["jpg", "jpeg", "png", "webp"]
const PHOTO_MAX_BYTES := 5 * 1024 * 1024
## Photos are shrunk to this before the editor opens (phone photos are huge).
const PHOTO_MAX_SIDE := 1536
## Deleting an account needs a server function (docs/delete_my_account.sql,
## run once in the Supabase SQL editor by the owner); until then the button
## explains instead of failing silently.
const DELETE_RPC := "delete_my_account"

func _title() -> String:
	return tr("👤 Profile")

func _build() -> void:
	var me := section("")
	var face := CenterContainer.new()
	face.add_child(Avatar.make(Avatar.mine(), 112.0))
	me.add_child(face)
	if Auth.is_logged_in():
		me.add_child(label(Auth.get_display_name(), 34, pal.accent, true, true))
		me.add_child(dim(tr("Your best scores sync to every device you sign in on.")))
	else:
		me.add_child(label(tr("Guest"), 34, pal.accent, true, true))
		me.add_child(dim(tr("Not signed in. Sign in to keep your best scores on every device.")))
		var sign := pill(tr("Sign In"), true)
		sign.pressed.connect(_to_scene.bind("res://scenes/account/account.tscn"))
		me.add_child(sign)
	var change := pill(tr("Change avatar"), false)
	change.pressed.connect(_on_change_avatar)
	me.add_child(change)

	# Hub-wide numbers.
	var all := Achievements.all_stats()
	for id in all.keys():
		if Catalog.is_archived(id):
			all.erase(id)
	var plays := 0
	var wins := 0
	for id in all:
		for k in all[id]:
			var key := str(k)
			if Achievements.PLAY_KEYS.has(key):
				plays += int(all[id][k])
			elif Achievements.WIN_KEYS.has(key):
				wins += int(all[id][k])
	var stats := section(tr("Your numbers"))
	stats.add_child(_stat(tr("Viral Power"), Social.format_number(Achievements.local_power(Catalog.archived_ids.keys()))))
	stats.add_child(_stat(tr("Games tried"), str(Achievements.games_played(all))))
	stats.add_child(_stat(tr("Games played"), str(plays)))
	stats.add_child(_stat(tr("Wins"), str(wins)))
	stats.add_child(_stat(tr("Achievements"), str(Achievements.total_unlocked())))
	stats.add_child(_stat(tr("Time played"), _hours(HubData.play_seconds())))
	stats.add_child(_stat(tr("★ Favorites"), str(HubData.favorites().size())))

	var go := section(tr("More"))
	for spec in [["🏆 Leaderboards", "res://scenes/hub/leaderboards.tscn"],
			["🏅 Achievements", "res://scenes/hub/achievements.tscn"],
			["👥 Friends", "res://scenes/hub/friends.tscn"],
			["🎮 Multiplayer", "res://scenes/hub/multiplayer.tscn"]]:
		var b := pill(tr(spec[0]), true)
		b.pressed.connect(_to_scene.bind(spec[1]))
		go.add_child(b)

	if Auth.is_logged_in():
		var privacy := section(tr("Privacy"))
		privacy.add_child(dim(tr("Who can see your games, Viral XP and achievements?")))
		privacy.add_child(tabs([tr("Friends"), tr("Only me")], 1 if Social.visibility == "private" else 0, _on_visibility))

	var lang := section(tr("Language"))
	lang.add_child(tabs(["English", "Español"], Lang.SUPPORTED.find(Lang.current), _on_language))

	if Auth.is_logged_in():
		var acc := section(tr("Account"))
		linked_box = section(tr("Connected accounts"), acc)
		linked_box.add_child(dim(tr("Connect Google or Facebook to sign in without a password. Same account, same progress.")))
		Auth.fetch_identities(_on_identities)
		var out := pill(tr("Sign Out"), false)
		out.pressed.connect(_on_sign_out)
		acc.add_child(out)
		# Danger zone: far below Sign Out, low emphasis (a text link, not a button).
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 220)
		list.add_child(gap)
		var danger := section(tr("Danger zone"))
		danger.add_child(dim(tr("Deleting your account is permanent.")))
		var del := Button.new()
		del.text = tr("Delete my account")
		del.flat = true
		del.focus_mode = Control.FOCUS_NONE
		del.alignment = HORIZONTAL_ALIGNMENT_LEFT
		del.add_theme_font_size_override("font_size", 20)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			del.add_theme_color_override(key, pal.text_dim)
		del.pressed.connect(_on_delete_pressed)
		danger.add_child(del)

var linked_box: VBoxContainer
var linked_rows: Array = []
## Providers the account has, once known (null = not loaded / offline).
var identities: Variant = null

## Coming back from the browser after connecting an account: look again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and linked_box and is_instance_valid(linked_box):
		Auth.fetch_identities(_on_identities)

func _on_identities(found: Variant) -> void:
	if not linked_box or not is_instance_valid(linked_box):
		return  # screen was rebuilt/left while the request was in flight
	identities = found
	for r in linked_rows:
		if is_instance_valid(r):
			r.queue_free()
	linked_rows.clear()
	if found == null:
		return  # offline: leave just the explanation
	for provider in Auth.PROVIDERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := label(provider.capitalize(), 25, null, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if found.has(provider):
			row.add_child(label(tr("Connected ✓"), 23, pal.accent, false))
		else:
			var b := pill(tr("Connect"), false, 22)
			b.custom_minimum_size = Vector2(150, 52)
			b.pressed.connect(_on_connect.bind(provider))
			row.add_child(b)
		linked_box.add_child(row)
		linked_rows.append(row)

func _on_connect(provider: String) -> void:
	if tapped():
		Auth.link_identity_url(provider, _on_link_url)

func _on_link_url(url: String, error: String) -> void:
	if url == "":
		message(tr("Connected accounts"), tr(error))
	else:
		OS.shell_open(url)

func _stat(name: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := label(name, 25, null, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(label(value, 25, pal.accent, false))
	return row

func _hours(s: int) -> String:
	if s < 3600:
		return tr("%d min") % int(s / 60)
	return tr("%d h %d min") % [int(s / 3600), int((s % 3600) / 60)]

func _to_scene(path: String) -> void:
	if tapped():
		get_tree().change_scene_to_file(path)

func _on_visibility(i: int) -> void:
	Social.set_visibility("private" if i == 1 else "friends")
	rebuild()

func _on_language(i: int) -> void:
	var code: String = Lang.SUPPORTED[i]
	if code != Lang.current:
		Lang.set_language(code)
		get_tree().reload_current_scene()

func _on_sign_out() -> void:
	if tapped():
		Auth.sign_out()
		rebuild()

func _on_delete_pressed() -> void:
	if not tapped():
		return
	var box := dialog(tr("Delete my account?"))
	box.add_child(label(tr("This can't be undone. Deleted: your profile, friends, scores, achievements and play time stored online, and your sign-in. Games and saves on this phone stay."), 24))
	var tag := Auth.get_display_name()
	box.add_child(label(tr("Type your gamer tag (%s) or DELETE to confirm.") % tag, 22, pal.card_message))
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(0, 64)
	edit.add_theme_font_size_override("font_size", 28)
	box.add_child(edit)
	var yes := pill(tr("Delete my account"), true)
	yes.disabled = true
	yes.pressed.connect(_delete_account)
	edit.text_changed.connect(_on_confirm_typed.bind(yes, tag))
	box.add_child(yes)
	var no := pill(tr("Cancel"), false)
	no.pressed.connect(close_dialog)
	box.add_child(no)

## The confirm button stays off until the gamer tag or DELETE is typed.
func _on_confirm_typed(text: String, button: Button, tag: String) -> void:
	var t := text.strip_edges()
	button.disabled = not (t.to_upper() == "DELETE" or (tag != "" and t == tag))

# ---------- avatar ----------

func _on_change_avatar() -> void:
	if not tapped():
		return
	var box := dialog(tr("Choose your avatar"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var centered := CenterContainer.new()
	centered.add_child(grid)
	box.add_child(centered)
	for i in Avatar.PRESETS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(88, 88)
		b.pressed.connect(_pick_preset.bind(i))
		var a := Avatar.make("p%d" % i, 80.0)
		a.position = Vector2(4, 4)
		b.add_child(a)
		grid.add_child(b)
	var up := pill(tr("📷 Upload a photo"), true)
	up.pressed.connect(_pick_photo)
	box.add_child(up)
	if Avatar.mine() != "":
		var none := pill(tr("Remove my avatar"), false)
		none.pressed.connect(_set_avatar.bind(""))
		box.add_child(none)
	var cancel := pill(tr("Cancel"), false)
	cancel.pressed.connect(close_dialog)
	box.add_child(cancel)

func _pick_preset(i: int) -> void:
	if tapped():
		_set_avatar("p%d" % i)

func _set_avatar(avatar: String) -> void:
	close_dialog()
	Avatar.save_mine(avatar)
	rebuild()

func _pick_photo() -> void:
	if not tapped():
		return
	close_dialog()
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		message(tr("Your photo"), tr("Picking a photo isn't available on this device. Choose one of the avatars instead."))
		return
	DisplayServer.file_dialog_show(tr("Choose a photo"), "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			PackedStringArray(["*.jpg, *.jpeg, *.png, *.webp ; Images"]), _on_photo_picked)

func _on_photo_picked(status: bool, paths: PackedStringArray, _filter: int) -> void:
	if not status or paths.is_empty() or not is_inside_tree():
		return
	call_deferred("_open_editor", paths[0])

func _open_editor(path: String) -> void:
	var ext := path.get_extension().to_lower()
	if not PHOTO_EXTENSIONS.has(ext):
		message(tr("Your photo"), tr("Use a JPG, PNG or WebP picture."))
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		message(tr("Your photo"), tr("Couldn't open that picture."))
		return
	if bytes.size() > PHOTO_MAX_BYTES:
		message(tr("Your photo"), tr("That picture is too big (max 5 MB)."))
		return
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match ext:
		"png": err = img.load_png_from_buffer(bytes)
		"webp": err = img.load_webp_from_buffer(bytes)
		_: err = img.load_jpg_from_buffer(bytes)
	if err != OK or img.is_empty():
		message(tr("Your photo"), tr("Couldn't open that picture."))
		return
	var longest := maxi(img.get_width(), img.get_height())
	if longest > PHOTO_MAX_SIDE:
		var k := float(PHOTO_MAX_SIDE) / float(longest)
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	var editor := AvatarEditor.new()
	add_child(editor)
	editor.setup(self, img)
	editor.saved.connect(_set_avatar)

func _delete_account() -> void:
	close_dialog()
	if Auth.has_method("db_call"):
		Auth.db_call(DELETE_RPC, {}, _on_deleted)
	else:
		_on_deleted(false, null)

func _on_deleted(ok: bool, _result: Variant) -> void:
	if not is_inside_tree():
		return
	if not ok:
		message(tr("Delete my account"), tr("Couldn't delete the account right now. Use Options → Send feedback and we'll delete it for you."))
		return
	Auth.sign_out()
	message(tr("Delete my account"), tr("Your account was deleted."))
	rebuild()
