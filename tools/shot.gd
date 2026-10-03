extends SceneTree

## Drives one scene and saves screenshots -- for checking a game's screens
## and buttons without a phone. Needs a window (not --headless):
##
##   godot --path . --resolution 720x1280 --script res://tools/shot.gd -- \
##       res://scenes/games/<id>/<id>.tscn <out_dir> step step ...
##
## Steps:  shot:<name>   save <out_dir>/<name>.png
##         wait:<frames> let the game run
##         press:<text>  press the topmost visible button whose text contains <text>
##         buttons       print every visible button's text
##         close_info    close GameInfo's first-play card if it's open
##         tap:<x>,<y>   a mouse click at that fraction of the window (0..1)
##         inset:l,t,r,b nothing here -- use VOODOO_SAFE_INSET for that
## Anything a step can't find prints "STEP FAILED" so a caller can grep it.
## Tests share the PC build's user data -- back it up first (CLAUDE.md).

var out_dir := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- <scene> <out_dir> steps...")
		quit(2)
		return
	out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	change_scene_to_file(args[0])
	_run(args.slice(2))

func _run(steps: Array) -> void:
	for i in 20:
		await process_frame
	for s in steps:
		var step := str(s)
		var arg := step.substr(step.find(":") + 1) if ":" in step else ""
		if step.begins_with("shot:"):
			await process_frame
			await process_frame
			var img := root.get_texture().get_image()
			img.save_png(out_dir.path_join(arg + ".png"))
			print("SHOT ", arg)
		elif step.begins_with("wait:"):
			for i in int(arg):
				await process_frame
		elif step.begins_with("press:"):
			var b := _find_button(arg)
			if b == null:
				print("STEP FAILED: no button ", arg)
			else:
				print("PRESS ", b.text.replace("\n", " / "))
				if b.toggle_mode:
					b.button_pressed = not b.button_pressed
				b.pressed.emit()
			for i in 12:
				await process_frame
		elif step == "buttons":
			for b in _buttons(root):
				print("  BUTTON [", b.text.replace("\n", " / "), "] ", b.get_global_rect())
		elif step == "close_info":
			var gi := _find_info(root)
			if gi and gi.overlay and gi.overlay.visible:
				gi.close()
			for i in 4:
				await process_frame
		elif step.begins_with("tap:"):
			# Fractions of the window (0..1), so steps work at any --resolution.
			var p := arg.split(",")
			var pos := Vector2(float(p[0]), float(p[1])) * Vector2(DisplayServer.window_get_size())
			for pressed in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = pressed
				ev.position = pos
				ev.global_position = pos
				root.push_input(ev)
				await process_frame
			for i in 10:
				await process_frame
		else:
			print("STEP FAILED: unknown step ", step)
	print("DONE")
	paused = false
	quit(0)

func _buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button and n.is_visible_in_tree() and not n.disabled:
		out.append(n)
	for c in n.get_children():
		out.append_array(_buttons(c))
	return out

## Topmost = last in tree order.
func _find_button(text: String) -> Button:
	var found: Button = null
	for b in _buttons(root):
		if text in b.text or text == b.name:
			found = b
	return found

func _find_info(n: Node) -> Node:
	if n.get_script() and str(n.get_script().resource_path).ends_with("game_info.gd"):
		return n
	for c in n.get_children():
		var r := _find_info(c)
		if r:
			return r
	return null
