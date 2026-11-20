extends SceneTree

## Screenshots of the Account screen with this device's remembered accounts (needs a window):
##   godot --path . --resolution 405x880 --script res://tools/shot_account.gd -- <out_dir> <name>
## Seeds two fake accounts (no network), restores the real list afterwards.

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shots"
	var name: String = args[1] if args.size() > 1 else "account"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var A = root.get_node("Auth")
	var bak := FileAccess.get_file_as_bytes(A.KNOWN_PATH) if FileAccess.file_exists(A.KNOWN_PATH) else PackedByteArray()
	var signed: bool = A.is_logged_in()
	A._known = []
	A._known_loaded = true
	A._remember("demo1", "Nico", "nico@gmail.com", "demo-token-1")
	A._remember("demo2", "Ana", "ana.perez@hotmail.com", "demo-token-2")
	var uid: String = A.user_id
	A.user_id = ""   # show the signed-out screen
	var acc: String = A.access_token
	A.access_token = ""
	change_scene_to_file("res://scenes/account/account.tscn")
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	current_scene._show_form(true)
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s_other.png" % [out, name])
	current_scene._show_form(false)
	current_scene._on_quick_pick(A.known_accounts()[0])
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s_confirm.png" % [out, name])
	# put it all back
	A.user_id = uid
	A.access_token = acc
	A._known = []
	A._known_loaded = false
	if bak.is_empty():
		if FileAccess.file_exists(A.KNOWN_PATH):
			DirAccess.remove_absolute(A.KNOWN_PATH)
	else:
		var f := FileAccess.open(A.KNOWN_PATH, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	quit()
