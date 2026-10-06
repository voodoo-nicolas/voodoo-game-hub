extends "res://scripts/hub/hub_screen.gd"

## 👤 Profile (STANDARDS §2b, since v0.30): who you are, what you've played
## across the whole hub, and the hub-wide screens that used to sit on the
## home screen (🏆 Leaderboards, 🏅 Achievements, 👥 Friends, 🎮 Multiplayer).
## Everything is read from the games' stats files and the hub's own records
## (HubData), so no pack has to be mounted.

const Achievements = preload("res://scripts/common/achievements.gd")
const HubData = preload("res://scripts/common/hub_data.gd")
## Deleting an account needs a server function (docs/delete_my_account.sql,
## run once in the Supabase SQL editor by the owner); until then the button
## explains instead of failing silently.
const DELETE_RPC := "delete_my_account"

func _title() -> String:
	return tr("👤 Profile")

func _build() -> void:
	var me := section("")
	if Auth.is_logged_in():
		me.add_child(label("👤 " + Auth.get_display_name(), 34, pal.accent, true, true))
		me.add_child(dim(tr("Your best scores sync to every device you sign in on.")))
	else:
		me.add_child(label("👤 " + tr("Guest"), 34, pal.accent, true, true))
		me.add_child(dim(tr("Not signed in. Sign in to keep your best scores on every device.")))
		var sign := pill(tr("Sign In"), true)
		sign.pressed.connect(_to_scene.bind("res://scenes/account/account.tscn"))
		me.add_child(sign)

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

	var lang := section(tr("Language"))
	lang.add_child(tabs(["English", "Español"], Lang.SUPPORTED.find(Lang.current), _on_language))

	if Auth.is_logged_in():
		var acc := section(tr("Account"))
		var out := pill(tr("Sign Out"), false)
		out.pressed.connect(_on_sign_out)
		acc.add_child(out)
		var del := pill(tr("Delete my account"), false)
		del.pressed.connect(_on_delete_pressed)
		acc.add_child(del)
		acc.add_child(dim(tr("Deletes your account and the scores stored online. Games and saves on this phone stay.")))

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
	box.add_child(label(tr("This can't be undone. Your account and online scores are deleted; games and saves on this phone stay."), 24))
	var yes := pill(tr("Delete my account"), true)
	yes.pressed.connect(_delete_account)
	box.add_child(yes)
	var no := pill(tr("Cancel"), false)
	no.pressed.connect(close_dialog)
	box.add_child(no)

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
