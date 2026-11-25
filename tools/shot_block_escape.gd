extends SceneTree
## Block Escape look pass screenshots: landing, intro pop, a level, block lifted with its gate
## glowing, an escape burst, a hammer smash, low-clock danger and the win confetti.
## godot --path . --resolution 540x1170 --script res://tools/shot_block_escape.gd -- <out_dir> [skin]
## Starts games: back up user://block_escape_*.json first (shares the real saves).

var g
var out := ""

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String, frames: int = 12) -> void:
	await _wait(frames)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var skin: String = args[1] if args.size() > 1 else "classic"
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(3)
	change_scene_to_file("res://scenes/games/block_escape/block_escape.tscn")
	await _wait(25)
	g = current_scene
	g._set_skin(skin)
	await _shot("00_landing")
	g._start_level(40)
	g.home.visible = false
	paused = false
	await _shot("01_intro", 6)
	await _shot("02_level", 60)
	# lift a movable block
	for bi in g.engine.blocks.size():
		if g.engine.can_move(bi):
			g.drag_block = bi
			break
	await _shot("03_lifted", 20)
	g.drag_block = -1
	# fake an escape through gate 0 with the matching colour
	var gi := 0
	for bi in g.engine.blocks.size():
		var b = g.engine.blocks[bi]
		if not b.gone and int(b.color) == int(g.engine.gates[gi].color):
			g._escape(bi, gi)
			break
	await _shot("04_escape", 7)
	for bi in g.engine.blocks.size():
		if not g.engine.blocks[bi].gone:
			g._smash(bi)
			break
	await _shot("05_smash", 6)
	g.started = true
	g.time_left = 6.0
	await _shot("06_danger", 50)
	g.time_left = 60.0
	for bi in g.engine.blocks.size():
		if not g.engine.blocks[bi].gone:
			g.engine.remove(bi)
	g._after_change()
	await _shot("07_win", 18)
	await _shot("08_end", 70)
	quit()
