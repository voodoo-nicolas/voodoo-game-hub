extends SceneTree

## Beached's own Landing + ⚙ Options (owner, 2026-11-20): two screenshots.
## godot --path . --resolution 1280x720 --audio-driver Dummy --script res://tools/shot_wilson_landing.gd -- <dir>
## Uses the desktop save as it is (only reads it).

var dir := "user://"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		dir = args[0]
	var g = load("res://scenes/games/wilson/wilson.tscn").instantiate()
	root.add_child(g)
	_run.call_deferred(g)

func _run(g) -> void:
	for i in 40:
		await process_frame
	g.home.refresh()
	for i in 5:
		await process_frame
	_shot("landing_new")
	g.home._show_options()
	for i in 10:
		await process_frame
	_shot("landing_options")
	quit()

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(n + ".png"))
	print("SHOT ", n)
