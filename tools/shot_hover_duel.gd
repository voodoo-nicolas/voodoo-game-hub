extends SceneTree

## Hover Duel in a real window: Landing, a battle on every land, 2 Players, Voodoo skin.
##   godot --path . --resolution 1280x720 --script res://tools/shot_hover_duel.gd -- <out_dir>
## Starts games, so the save is removed afterwards (it never existed before a battle).

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://hover_duel_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	if args.size() > 1 and args[1] == "art":
		_art()
	else:
		_run()

## The Landing picture (games/hover_duel/landing_bg.jpg): a staged duel on the
## right of the screen, no HUD, Pad or pause button.
func _art() -> void:
	await _wait(3)
	change_scene_to_file("res://scenes/games/hover_duel/hover_duel.tscn")
	await _wait(25)
	game = current_scene
	game.home.play_now(game._new_vs.bind(1))
	var e = game.engine
	e.reset("valley", 1207, ["skimmer", "hornet"], [-1, -1])
	game._rebuild_terrain()
	game.briefing = false
	game.brief_dialog.visible = false
	var c0: Vector2 = Vector2(e.W * 0.52, e.H * 0.5)
	e.crafts[0].p = c0
	e.crafts[0].a = -0.35
	e.crafts[1].p = c0 + Vector2(330, -120)
	e.crafts[1].a = PI - 0.3
	for k in 5:
		e.shots.append({"p": c0 + Vector2.RIGHT.rotated(-0.35) * (40 + k * 55), "v": Vector2.RIGHT.rotated(-0.35) * 760.0, "z": 9.0, "o": 0, "t": 9.0, "dmg": 0.0})
	e.missiles.append({"p": c0 + Vector2(240, -60), "v": Vector2(-430, 60), "o": 1, "t": 9.0})
	game.started = false
	game.hud.visible = false
	for ch in game.get_children():
		if ch is Button or (game.touch_pad != null and ch == game.touch_pad):
			ch.visible = false
	game.home.visible = false
	game.zoom = 1.0
	game.cam = c0 + Vector2(-190, -60)
	_hide_text(root, "?")
	game.set_process(false)
	game.terrain.queue_redraw()
	game.field.queue_redraw()
	await _wait(10)
	var img := root.get_texture().get_image()
	img.save_jpg(out_dir.path_join("landing_bg.jpg"), 0.88)
	print("SHOT landing_bg")
	quit()

func _shot(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _hide_text(n: Node, text: String) -> void:
	for ch in n.get_children():
		if ch is Button and ch.text == text:
			ch.visible = false
		_hide_text(ch, text)

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _run() -> void:
	var had_save := FileAccess.file_exists("user://hover_duel_save.json")
	await _wait(3)
	change_scene_to_file("res://scenes/games/hover_duel/hover_duel.tscn")
	await _wait(25)
	game = current_scene
	await _shot("00_landing")
	game._open_goals()
	await _wait(5)
	await _shot("01_objectives")
	game.home.show_home()
	game._open_campaign()
	await _wait(5)
	await _shot("02_campaign")
	game.home.show_home()
	game.home.play_now(game._start_campaign.bind(0))
	await _wait(20)
	await _shot("03_briefing")
	game._end_briefing()
	for n in [0, 2, 5, 6, 8, 11]:
		game.home.play_now(game._start_campaign.bind(n))
		game._end_briefing()
		await _wait(150)
		await _shot("1%d_battle" % n)
	game.home.play_now(game._new_duo)
	await _wait(90)
	await _shot("20_duo")
	game._set_skin("voodoo")
	await _wait(30)
	await _shot("30_voodoo")
	game.started = false
	if not had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://hover_duel_save.json"))
	quit()
