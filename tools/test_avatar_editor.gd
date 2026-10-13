extends SceneTree

## Avatar editor: opens it on a generated picture (via the Profile screen's
## own validation), saves, and checks the result is a small decodable avatar.
## Needs a window (renders a SubViewport), so no --headless:
##   godot --path . --script res://tools/test_avatar_editor.gd [-- <screenshot.png>]
## The Profile screen saves the avatar it gets, so user://avatar.json is
## backed up first and put back (or removed) at the end.

var fails := 0
var got := ""
var had_file := false
var old_text := ""

func _initialize() -> void:
	had_file = FileAccess.file_exists("user://avatar.json")
	old_text = FileAccess.get_file_as_string("user://avatar.json") if had_file else ""
	var img := Image.create_empty(900, 600, false, Image.FORMAT_RGB8)
	for y in 600:
		for x in 900:
			img.set_pixel(x, y, Color(x / 900.0, y / 600.0, 0.5))
	img.save_png("user://test_avatar_src.png")
	var profile = load("res://scenes/hub/profile.tscn").instantiate()
	root.add_child(profile)
	for i in 5:
		await process_frame
	profile._open_editor("user://test_avatar_src.png")
	for i in 5:
		await process_frame
	var editor = null
	for c in profile.get_children():
		if c.has_signal("saved"):
			editor = c
	if editor == null:
		print("FAIL: editor did not open")
		quit(1)
		return
	editor.saved.connect(func(a): got = a)
	editor._sliders["zoom"].value = 2.0
	editor._sliders["brightness"].value = 0.1
	editor._turn(90.0)
	for i in 5:
		await process_frame
	var args := OS.get_cmdline_user_args()
	await RenderingServer.frame_post_draw
	if args.size() > 0:
		root.get_viewport().get_texture().get_image().save_png(args[0])
	editor._on_save()
	for i in 6:
		await process_frame
	if not got.begins_with("img:"):
		print("FAIL: nothing saved")
		fails += 1
	else:
		var tex = load("res://scripts/common/avatar.gd").texture_from(got)
		if tex == null or tex.get_width() != 256:
			print("FAIL: saved avatar doesn't decode to 256 px")
			fails += 1
		if got.length() > 40000:
			print("FAIL: avatar too long for the server column: %d" % got.length())
			fails += 1
		print("avatar string length: %d" % got.length())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_avatar_src.png"))
	if had_file:
		var f := FileAccess.open("user://avatar.json", FileAccess.WRITE)
		f.store_string(old_text)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://avatar.json"))
	print("PASS" if fails == 0 else "FAILED")
	quit(1 if fails > 0 else 0)
