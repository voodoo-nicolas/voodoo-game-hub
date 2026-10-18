extends SceneTree
## Headless: Options and Hub scenes instantiate without script errors.
func _initialize() -> void:
	for p in ["res://scenes/hub/options.tscn", "res://scenes/hub/hub.tscn"]:
		var s = load(p).instantiate()
		root.add_child(s)
		await process_frame
		print("booted ", p)
	quit(0)
