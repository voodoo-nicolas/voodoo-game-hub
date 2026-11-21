extends SceneTree

## Ancient Assassins: copies the few clips the game uses out of Quaternius'
## Universal Animation Library (CC0, 43 clips, 7.6 MB) into one small
## AnimationLibrary, games/ancient_assassins/models/aa_anims.res. The library
## itself stays outside the project (it would ship whole otherwise).
##   godot --headless --path . --script res://tools/aa_build_anims.gd -- "<path to UAL1_Standard.glb>"
## Default path: the owner's copy in D:/Dev/Sprites/quaternius/.

const OUT := "res://games/ancient_assassins/models/aa_anims.res"
const DEFAULT := "D:/Dev/Sprites/quaternius/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb"
## Source clip -> name in the game.
const KEEP := {
	"Idle_Loop": "idle",
	"Spell_Simple_Enter": "aim_in",
	"Spell_Simple_Idle_Loop": "aim",
	"Spell_Simple_Shoot": "throw",
	"Hit_Chest": "hit",
	"Hit_Head": "hit_head",
	"Death01": "death",
	"Dance_Loop": "win",
	"Sword_Idle": "ready",
}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0] if args.size() > 0 else DEFAULT
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(src, state)
	if err != OK:
		printerr("can't read ", src, " (", err, ")")
		quit(1)
		return
	var scene := doc.generate_scene(state)
	var player := _find_player(scene)
	if player == null:
		printerr("no AnimationPlayer in ", src)
		quit(1)
		return
	var skel_path := ""
	var skel := _find_skeleton(scene)
	if skel:
		skel_path = str(scene.get_path_to(skel))
	var lib := AnimationLibrary.new()
	for src_name in KEEP:
		var a: Animation = null
		for ln in player.get_animation_library_list():
			var l := player.get_animation_library(ln)
			if l.has_animation(src_name):
				a = l.get_animation(src_name).duplicate(true)
		if a == null:
			printerr("missing clip ", src_name)
			continue
		var loop: bool = src_name.ends_with("_Loop") or src_name == "Sword_Idle"
		a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		# Keep bone rotations only (+ the hips' position), so any character on the
		# same rig can play it; drop scale tracks.
		for t in range(a.get_track_count() - 1, -1, -1):
			var path := str(a.track_get_path(t))
			var tt := a.track_get_type(t)
			if tt == Animation.TYPE_SCALE_3D or (tt == Animation.TYPE_POSITION_3D and not path.ends_with(":pelvis") and not path.ends_with(":root")):
				a.remove_track(t)
		lib.add_animation(KEEP[src_name], a)
		print("kept ", src_name, " -> ", KEEP[src_name], "  ", snappedf(a.length, 0.01), " s, ", a.get_track_count(), " tracks, e.g. ", a.track_get_path(0) if a.get_track_count() > 0 else "")
	print("skeleton path in source: ", skel_path, "  anim root: ", player.root_node)
	var e := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("saved ", OUT, " -> ", e)
	scene.free()
	quit(0 if e == OK else 1)

func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_player(c)
		if r:
			return r
	return null

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null
