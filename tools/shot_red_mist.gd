extends SceneTree

## Red Mist in a real window: the Landing, contracts in every place, hour and
## weather (naked eye, then the scope on the officer or a truck), Skull mode,
## and a played contract up to its result card.
##   godot --path . --resolution 1280x720 --script res://tools/shot_red_mist.gd -- <out_dir>
## Starts contracts, so the save file is removed at the end.

const SHOTS := [0, 4, 8, 12, 15, 19, 20, 21, 25, 27, 29]

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://red_mist_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _shot(name: String) -> void:
	await _wait(4)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _run() -> void:
	await _wait(3)
	change_scene_to_file("res://scenes/games/red_mist/red_mist.tscn")
	await _wait(30)
	game = current_scene
	await _shot("00_landing")
	game.progress.cash = 2500
	game._open_armory()
	await _wait(10)
	await _shot("02_armory")
	for c in SHOTS:
		game.home.play_now(game._start_contract.bind(c))
		await _wait(10)
		if c == 0:
			await _shot("03_briefing")
		game._on_begin()
		game.hint_t = 0.0
		game.banner_t = 0.0
		var e = game.engine
		var tag := "%02d_%s_%s_%s" % [c + 1, e.loc, e.tod, e.wx]
		if e.goal == "convoy":
			for i in 900:  # let the first truck set off
				await process_frame
				if _truck().get("state", "") == "drive":
					break
			await _wait(60)
		await _shot(tag + "_eye")
		var tr: Dictionary = _truck()
		if not tr.is_empty() and tr.state == "drive":
			_look(e.truck_pos(tr) + Vector2(0, -1.6 * game.E.upm(tr.d)), 5.0)
		else:
			_scope_on_officer(6.0)
		await _wait(20)
		await _shot(tag + "_scope")
	game._set_skin("voodoo")
	game._start_contract(10)
	await _wait(10)
	game._on_begin()
	await _shot("40_voodoo_eye")
	_scope_on_officer(5.0)
	await _wait(20)
	await _shot("41_voodoo_scope")
	game._set_skin("classic")
	# A played contract: shoot every target with the spotter's hold.
	game._start_contract(0)
	await _wait(10)
	game._on_begin()
	game.zoom = 1.0
	game.zoom_target = 1.0
	await _wait(10)
	await _shot("49_rifle")
	for i in 12:
		var tg: Dictionary = {}
		for t in game.engine.targets:
			if game.engine._live(t) and not t.civ:
				tg = t
				break
		if tg.is_empty():
			break
		_look(game.engine.target_pos(tg), 6.0)
		game.engine.bolt_t = 0.0
		game.engine.reload_t = 0.0
		await _wait(3)
		game.cam = game._hold_point(tg) - game.engine.sway_mils() * game.E.MIL
		game._apply_camera()
		game._fire()
		if i == 0:
			await _wait(8)
			await _shot("50_fired")
		if not game.bcam.is_empty():
			await _wait(40)
			await _shot("52_bullet_cam_%d" % i)
			while not game.bcam.is_empty():
				await process_frame
		await _wait(90)
	await _wait(200)
	if game.results_chip.visible:
		game._show_results_again()
	await _shot("51_card")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://red_mist_save.json"))
	quit()

func _truck() -> Dictionary:
	for pr in game.engine.props:
		if pr.kind == "truck":
			return pr
	return {}

func _scope_on_officer(z: float) -> void:
	var pick: Dictionary = {}
	for t in game.engine.targets:
		if t.primary:
			pick = t
	if pick.is_empty():
		for t in game.engine.targets:
			if not t.civ:
				pick = t
				break
	if not pick.is_empty():
		_look(game.engine.target_pos(pick) + Vector2(0, -1.2 * game.E.upm(pick.d)), z)

func _look(p: Vector2, z: float) -> void:
	game.cam = p
	game.zoom_target = z
	game.zoom = z
