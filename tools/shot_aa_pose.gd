extends SceneTree

## Amazonia's pose layer on a stage, saved as pictures: the six stances side by side, the emotes
## and the dances (a row each), and optionally a look from the Shop ("looks" = hair styles,
## costumes, tattoos). Needs a window (not --headless):
##   godot --path . --resolution 800x400 --script res://tools/shot_aa_pose.gd -- <out_dir> [lineup|emotes|dances|looks|all]

const AaCharacter = preload("res://scripts/games/ancient_assassins/aa_character.gd")
const Game = preload("res://scripts/games/ancient_assassins/ancient_assassins_game.gd")

var out_dir := ""
var ctl: Control
var vp: SubViewport

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://aa_pose"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run(args[1] if args.size() > 1 else "all")

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _secs(t: float) -> void:
	await create_timer(t).timeout

func _stage(width: float, cam_z: float, look_y: float = 0.95) -> void:
	if ctl:
		ctl.queue_free()
	ctl = Control.new()
	root.add_child(ctl)
	ctl.size = Vector2(width, 700)
	vp = AaCharacter.make_stage(ctl, 700, false)
	(vp.get_parent() as Control).size = Vector2(width, 700)
	var cam: Camera3D = vp.get_node("Cam")
	cam.position = Vector3(0, look_y + 0.1, cam_z)
	cam.look_at(Vector3(0, look_y, 0))

func _put(ch: Dictionary, x: float) -> Node3D:
	var a = AaCharacter.new()
	vp.add_child(a)
	a.position.x = x
	a.build(ch, false)
	a.play("idle", 0.0)
	return a

func _save(name: String) -> void:
	await _wait(3)
	vp.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _run(what: String) -> void:
	await _wait(5)
	if what in ["lineup", "all"]:
		_stage(1700, 5.6)
		for i in 6:
			_put(Game.CHARS[i], (i - 2.5) * 1.3)
		await _wait(60)
		await _save("lineup_front")
		for a in vp.get_children():
			if a is AaCharacter:
				a.rotation.y = 0.9
		await _wait(5)
		await _save("lineup_side")
	if what in ["emotes", "all"]:
		_stage(1700, 5.6)
		var ids: Array = AaCharacter.EMOTES.keys()
		var cs: Array = []
		for i in ids.size():
			var a := _put(Game.CHARS[0], (i - (ids.size() - 1) / 2.0) * 1.3)
			cs.append(a)
		await _wait(30)
		for i in ids.size():
			cs[i].play_emote(ids[i])
		await _secs(1.1)
		print("DBG ", cs[0]._ov, " ", cs[0]._ov_t, " ", cs[0]._ov_len, " ", cs[0]._state, " ", cs[0].current)
		await _save("emotes_a")
		await _secs(0.6)
		await _save("emotes_b")
	if what in ["dances", "all"]:
		_stage(1500, 5.4)
		var ids: Array = AaCharacter.DANCES.keys()
		var cs: Array = []
		for i in ids.size():
			var a := _put(Game.CHARS[3], (i - (ids.size() - 1) / 2.0) * 1.4)
			cs.append(a)
		await _wait(30)
		for i in ids.size():
			cs[i].start_dance(ids[i])
		await _secs(1.6)
		await _save("dances_a")
		await _secs(0.5)
		await _save("dances_b")
	if what in ["looks", "all"]:
		_stage(1500, 5.6, 1.0)
		var looks: Array = []
		for st in Game.HAIR_STYLES.slice(0, 6):
			looks.append({"hair3d": st.base, "hair_extra": st.extra})
		for k in looks.size():
			var c: Dictionary = Game.CHARS[k % 6].duplicate()
			c.merge(looks[k], true)
			_put(c, (k - 2.5) * 1.1).rotation.y = 0.0
		await _wait(40)
		await _save("hair_styles")
		_stage(1500, 5.6, 1.0)
		var cos := ["belly", "domina", "devil"]
		for k in 3:
			var c: Dictionary = Game.CHARS[k].duplicate()
			c["costume"] = cos[k]
			c["bikini"] = {}
			_put(c, (k - 1) * 1.6)
		await _wait(40)
		await _save("costumes_front")
		for a in vp.get_children():
			if a is AaCharacter:
				a.rotation.y = PI
		await _wait(5)
		await _save("costumes_back")
		_stage(1500, 5.6, 1.0)
		for k in 6:
			var c: Dictionary = Game.CHARS[k].duplicate()
			c["tattoo"] = k + 1
			c["bikini"] = {"pattern": 0}
			c["c1"] = Color("141418")
			_put(c, (k - 2.5) * 1.1)
		await _wait(40)
		await _save("tattoos_front")
		for a in vp.get_children():
			if a is AaCharacter:
				a.rotation.y = PI
		await _wait(5)
		await _save("tattoos_back")
	quit()
