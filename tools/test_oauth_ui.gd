extends SceneTree
## Headless: account screen builds with the Google/Facebook buttons, Auth helpers behave.
## godot --headless --path . --script res://tools/test_oauth_ui.gd
func _initialize() -> void:
	var fails := 0
	var auth = root.get_node("Auth")
	var url: String = auth.oauth_url("google")
	if not url.contains("provider=google") or not url.contains("auth-callback.html".uri_encode()):
		print("FAIL oauth_url ", url); fails += 1
	if not auth.looks_like_code("VGH1.abcdefghijklmnop") or auth.looks_like_code("hello") or auth.looks_like_code("VGH1."):
		print("FAIL looks_like_code"); fails += 1
	var scr = load("res://scenes/account/account.tscn").instantiate()
	root.add_child(scr)
	await process_frame
	if scr.social_box == null or scr.social_box.get_child_count() < 4:
		print("FAIL social buttons"); fails += 1
	var prof = load("res://scenes/hub/profile.tscn")
	if prof == null:
		print("FAIL profile scene"); fails += 1
	print("test_oauth_ui: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(fails)
