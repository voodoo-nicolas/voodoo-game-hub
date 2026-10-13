extends SceneTree

## Friends list rows (tag / Viral Power / activity, whole row opens the player
## page, "..." menu -> named confirmation) with fake data; no server needed.
## Needs a window:
##   godot --path . --script res://tools/test_friends_ui.gd [-- <out_dir>]
## Overwrites Social's in-memory friend list only.

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _initialize() -> void:
	var social = root.get_node("Social")
	_check(social.format_number(12450) == "12,450" and social.format_number(7) == "7" and social.format_number(1000000) == "1,000,000", "format_number")
	var rows := [
		{"user_id": "a", "display_name": "Ana", "status": "friend", "online": true, "current_game": "chess", "viral_power": 12450, "avatar": "p0"},
		{"user_id": "b", "display_name": "Beto", "status": "friend", "online": true, "current_game": "", "viral_power": 80, "avatar": "p5"},
		{"user_id": "c", "display_name": "Cami", "status": "friend", "online": false, "current_game": "", "viral_power": 0, "avatar": ""},
	]
	_check(social.activity_text(rows[1]) == "• Currently in the menus" or social.activity_text(rows[1]) != "", "menus text")
	social._presence_ok = false
	var screen = load("res://scenes/hub/friends.tscn").instantiate()
	root.add_child(screen)
	for i in 3:
		await process_frame
	social.available = true
	social.friends = rows
	screen.rebuild()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_cmdline_user_args()
	if out.size() > 0:
		DirAccess.make_dir_recursive_absolute(out[0])
		root.get_viewport().get_texture().get_image().save_png(out[0] + "/friends.png")
	var kebabs := []
	_find_buttons(screen, "⋯", kebabs)
	_check(kebabs.size() == 3, "one ... menu per friend, got %d" % kebabs.size())
	var remove_texts := []
	_find_buttons(screen, "Remove", remove_texts)
	_check(remove_texts.is_empty(), "no remove button on the list itself")
	kebabs[0].pressed.emit()
	for i in 3:
		await process_frame
	var rm := []
	_find_buttons(screen, "Remove friend", rm)
	_check(rm.size() == 1, "menu offers Remove friend")
	rm[0].pressed.emit()
	for i in 3:
		await process_frame
	var named := []
	_find_buttons(screen, "Remove Ana", named)
	_check(named.size() == 1, "confirmation names the friend")
	_check(social.friends.size() == 3, "nothing removed before confirming")
	await RenderingServer.frame_post_draw
	if out.size() > 0:
		root.get_viewport().get_texture().get_image().save_png(out[0] + "/confirm.png")
	print("PASS" if fails == 0 else "FAILED")
	quit(1 if fails > 0 else 0)

func _find_buttons(n: Node, text: String, into: Array) -> void:
	if n is Button and (n as Button).text.contains(text):
		into.append(n)
	for c in n.get_children():
		_find_buttons(c, text, into)
