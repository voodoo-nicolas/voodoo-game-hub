extends SceneTree

## Headless test of Social.launch_online's path: hub -> game -> OnlineMatch
## opens the lobby by itself and the game's Home steps aside, un-paused.
##   godot --headless --path . --script res://tools/test_social_launch.gd
## "lobby" mode only: nothing connects to the server.

var fails := 0

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _run() -> void:
	for i in 3:
		await process_frame
	var social = root.get_node("Social")
	ok(not social.available, "no friends server without sign-in")
	ok(social.take_pending("tictactoe").is_empty(), "nothing pending at start")
	social.pending = {"game": "tictactoe", "mode": "lobby", "t": Time.get_ticks_msec()}
	social.launch_request = "tictactoe"
	change_scene_to_file("res://scenes/hub/hub.tscn")
	for i in 90:
		await process_frame
	var scene := current_scene
	ok(scene != null and scene.scene_file_path == "res://scenes/games/tictactoe/tictactoe.tscn",
		"hub opened the requested game (%s)" % (scene.scene_file_path if scene else "none"))
	if scene:
		var m := scene.get_node_or_null("OnlineMatch")
		ok(m != null and m.lobby.visible, "lobby opened by itself")
		var kit := scene.get_node_or_null("HomeKit")
		ok(kit != null and not kit.is_home_visible(), "Home stepped aside")
		ok(not paused, "tree not paused under the lobby")
	ok(social.pending.is_empty(), "request used once")
	ok(social.take_launch_request() == "", "launch request used once")
	print("SOCIAL LAUNCH TEST: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
