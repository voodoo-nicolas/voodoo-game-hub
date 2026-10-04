extends "res://scripts/hub/hub_screen.gd"

## 🎮 Multiplayer (since v0.25): every way to play with other people, from
## the manifest's per-game "modes" ("online", "local", "cpu", "party"):
##
## - 🌐 Online, two phones: "Play" opens the game's online lobby (host or
##   join by code), "📨 Invite" picks a friend and opens it hosting, inviting
##   them as soon as the room exists (Social.launch_online).
## - 👥 One phone, two or more players; 🍻 party games for a group;
##   🤖 against the computer. These open the game's own Home screen.

const SECTIONS := [
	["online", "🌐 Online — two phones", "Host a room and share its code, or invite a friend."],
	["local", "👥 Same phone", "Take turns on one phone."],
	["party", "🍻 Party games", "Pass the phone around a group."],
	["cpu", "🤖 vs Computer", "Easy, medium or hard opponents."],
]

func _title() -> String:
	return tr("🎮 Multiplayer")

func _build() -> void:
	var friends_on: bool = Auth.is_logged_in() and Social.available
	if not friends_on:
		var tip := section("")
		tip.add_child(dim(tr("Sign in and add friends (👥 Friends) to invite them straight into a game.")))
	for s in SECTIONS:
		var games := games_with_mode(s[0])
		if games.is_empty():
			continue
		var box := section(tr(s[1]))
		box.add_child(dim(tr(s[2])))
		for g in games:
			box.add_child(HSeparator.new())
			var row := game_row(g)
			if s[0] == "online":
				var play := pill(tr("Play"), true, 22)
				play.pressed.connect(_online.bind(str(g.id)))
				row.add_child(play)
				if friends_on:
					var inv := pill(tr("📨 Invite"), false, 22)
					inv.pressed.connect(_invite.bind(str(g.id)))
					row.add_child(inv)
			else:
				var open := pill("▶", true, 26)
				open.custom_minimum_size = Vector2(76, 60)
				open.pressed.connect(_open.bind(str(g.id)))
				row.add_child(open)
			box.add_child(row)

func _online(id: String) -> void:
	if tapped():
		Social.launch_online(id, "lobby")

func _open(id: String) -> void:
	if tapped():
		open_game(id)

func _invite(id: String) -> void:
	if not tapped():
		return
	var mates: Array = Social.friends.filter(func(f): return f.status == "friend")
	var title: String = Lang.pick(Catalog.get_game(id), "title")
	var box := dialog(tr("Invite a friend to %s") % title)
	if mates.is_empty():
		box.add_child(label(tr("No friends yet. Share your code in 👥 Friends."), 24, pal.card_message, true, true))
	mates.sort_custom(func(a, b): return bool(a.get("online", false)) and not bool(b.get("online", false)))
	for f in mates:
		var b := pill(("🟢 " if bool(f.get("online", false)) else "⚪ ") + str(f.get("display_name", "Player")), false, 26)
		b.custom_minimum_size.y = 68
		b.pressed.connect(_invite_friend.bind(id, f))
		box.add_child(b)
	var cancel := pill(tr("Cancel"), false)
	cancel.pressed.connect(close_dialog)
	box.add_child(cancel)

func _invite_friend(id: String, f: Dictionary) -> void:
	close_dialog()
	Social.launch_online(id, "host", "", str(f.user_id), str(f.get("display_name", "")))
