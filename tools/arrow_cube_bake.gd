extends SceneTree

## Bakes Arrow Cube's 500 levels to games/arrow_cube/levels.json, so a later generator change
## never reshuffles a level under a player's saved progress (design doc §4).
##   godot --headless --path . --script res://tools/arrow_cube_bake.gd
## Every level is checked with the solver; one that fails is re-rolled with the next seed.
## Bump E.GEN_VERSION whenever the generator changes, then re-bake.

const E = preload("res://scripts/games/arrow_cube/arrow_cube_engine.gd")
const OUT := "res://games/arrow_cube/levels.json"

func _initialize() -> void:
	var levels: Array = []
	var t0 := Time.get_ticks_msec()
	var rerolls := 0
	for lv in range(1, E.LEVEL_COUNT + 1):
		var e := E.new()
		var p := E.params(lv)
		var seed_ := E.level_seed(lv)
		e.generate(p, seed_)
		var tries := 0
		while e.solve_first(30000).is_empty() and tries < 10:
			tries += 1
			rerolls += 1
			e.generate(p, seed_ + tries * 1000003)
		levels.append(e.level_dict())
		if lv % 25 == 0:
			print("  baked %d / %d  (%d s)" % [lv, E.LEVEL_COUNT, (Time.get_ticks_msec() - t0) / 1000])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://games/arrow_cube"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"gen": E.GEN_VERSION, "levels": levels}))
	f.close()
	print("arrow_cube_bake: %d levels, %d re-rolled, %d s" % [levels.size(), rerolls, (Time.get_ticks_msec() - t0) / 1000])
	quit()
