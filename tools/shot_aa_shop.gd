extends SceneTree

## Amazonia's Landing (menu left, her on the right) and the Shop (turning preview with drag and
## arrows, try-on of dances and emotes), as pictures. Needs a window:
##   godot --path . --resolution 540x1170 --script res://tools/shot_aa_shop.gd -- <out_dir>
## Only tries looks on (nothing is bought), but the game touches its progress save: back it up.

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://aa_shop_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _secs(t: float) -> void:
	await create_timer(t).timeout

func _shot(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _run() -> void:
	await _wait(3)
	change_scene_to_file("res://scenes/games/ancient_assassins/ancient_assassins.tscn")
	await _wait(40)
	game = current_scene
	await _secs(1.2)
	await _shot("a_landing")
	game._open_shop()
	await _secs(0.8)
	await _shot("b_shop")
	# the arrows: zoom in, turn
	game._preview_press("zoom_in")
	await _secs(1.2)

	game._preview_release("zoom_in")
	game._preview_press("rot_r")
	await _secs(0.7)
	game._preview_release("rot_r")
	await _shot("c_shop_zoomed")
	game.preview_zoom = 1.12
	game._try({"dance": "samba"}, "Samba")
	await _secs(1.4)
	await _shot("d_shop_dance")
	game._try({"dance": "samba"}, "Samba")
	game._try({"emote": "wave"}, "Wave")
	await _secs(1.3)
	await _shot("e_shop_emote")
	game._try({"outfit": "domina"}, "Dominatrix")
	await _secs(0.6)
	await _shot("f_shop_domina")
	quit()
