extends SceneTree

## Tests the shared sprite library's loader (tools/templates/sprite_lib.gd)
## against media/common/sprites/: single images and series (0- and 1-based)
## are found and load as textures of the right size, frame numbers map to
## files, unknown ids are null, sprite_frames() builds animations, and every
## id in the generated catalog loads.
##
##   godot --headless --path . --script res://tools/test_sprite_lib.gd

const SpriteLib = preload("res://tools/templates/sprite_lib.gd")
const CATALOG := "res://docs/claude/sprite-library.md"

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _initialize() -> void:
	var ship := SpriteLib.texture("space/player_ship1_blue")
	check(ship != null and ship.get_size() == Vector2(99, 75), "space/player_ship1_blue is one 99x75 image")
	check(SpriteLib.count("space/player_ship1_blue") == 1, "a single image counts 1")
	check(SpriteLib.count("space/laser_blue") == 16, "space/laser_blue has 16 files (1-16)")
	check(SpriteLib.count("space/fire") == 20, "space/fire has 20 frames (0-19)")
	check(SpriteLib.texture("space/fire", 0) != null, "a 0-based series has frame 0")
	check(SpriteLib.texture("space/laser_blue", 0) == null, "a 1-based series has no frame 0")
	check(SpriteLib.texture("space/laser_blue", 16) != null and SpriteLib.texture("space/laser_blue", 17) == null,
		"frame numbers are the file numbers (16 yes, 17 no)")
	check(SpriteLib.texture("space/laser_blue", 3).resource_path.ends_with("laser_blue_3.png"),
		"texture(id, 3) is file _3")
	check(SpriteLib.count("space/meteor_brown_med") == 2, "the gapped meteor_brown_med series was renumbered 1-2")
	check(SpriteLib.random("space/meteor_grey_big") != null, "random() gives a variant")
	# A caller that only draws it in _draw() keeps no reference: the library must, or it draws white.
	var rid := SpriteLib.texture("forest/owl").get_rid()
	check(SpriteLib.texture("forest/owl").get_rid() == rid, "a texture stays loaded between calls (same RID)")
	check(SpriteLib.texture("iso_dungeon/barrel_e").get_size() == Vector2(256, 512), "iso pieces are 256x512")
	check(SpriteLib.count("iso_dungeon/male_3_run") == 10 and SpriteLib.count("iso_dungeon/male_3_idle") == 1,
		"the iso man: run 10 frames, idle one image")
	check(SpriteLib.has("anime_portraits/monk_wandering_master"), "renamed portrait is there")
	check(not SpriteLib.has("anime_portraits/monk_drunken_master"), "its old name is not")
	check(not SpriteLib.has("cyberpunk/neon_sign_bar"), "the BAR sign was left out")
	check(SpriteLib.has("village/inn") and not SpriteLib.has("village/tavern"), "village/tavern is village/inn")
	check(SpriteLib.texture("nope/nothing") == null and SpriteLib.frames("nope/nothing").is_empty(),
		"an unknown id gives nothing")

	var sf := SpriteLib.sprite_frames("smoke/explosion", 18.0, false)
	check(sf.get_frame_count("default") == 9 and not sf.get_animation_loop("default")
		and is_equal_approx(sf.get_animation_speed("default"), 18.0), "sprite_frames: 9 frames, 18 fps, no loop")
	SpriteLib.sprite_frames("iso_dungeon/male_0_run", 12.0, true, "run", sf)
	check(sf.has_animation("run") and sf.get_frame_count("run") == 10, "sprite_frames(into): a second animation")

	# Every id the catalog lists loads, with the frame count it states.
	var text := FileAccess.get_file_as_string(CATALOG)
	var row := RegEx.create_from_string("\\| `([a-z0-9_]+)/([a-z0-9_]+?)(_\\{e,n,s,w\\})?` \\| (\\d*)")
	var ids := 0
	var bad := []
	for m in row.search_all(text):
		var names := [m.get_string(2)]
		if m.get_string(3) != "":
			names = []
			for facing in ["e", "n", "s", "w"]:
				names.append(m.get_string(2) + "_" + facing)
		var want := int(m.get_string(4)) if m.get_string(4) != "" else 1
		for name in names:
			var id: String = m.get_string(1) + "/" + name
			ids += 1
			var all := SpriteLib.frames(id)
			if all.size() != want or all.any(func(t): return t == null or t.get_width() == 0):
				bad.append("%s (%d of %d)" % [id, all.size(), want])
	check(ids > 1300, "catalog lists %d ids" % ids)
	check(bad.is_empty(), "every catalog id loads with its frames %s" % [bad.slice(0, 5)])

	print("%d failure(s)" % fails)
	quit(1 if fails else 0)
