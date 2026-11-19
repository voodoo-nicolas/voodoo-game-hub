extends SceneTree

## Writes the 300 Block Escape levels to games/block_escape/levels.json (shipped in the
## pack, so phones don't spend time generating). The game falls back to generating
## any level missing from the file with the same seed, so both always agree.
## godot --headless --path . --script res://tools/block_escape_gen.gd

const Gen = preload("res://scripts/games/block_escape/block_escape_gen.gd")
const OUT := "res://games/block_escape/levels.json"

func _init() -> void:
	var all: Array = []
	for lvl in range(1, Gen.LEVELS + 1):
		var p := Gen.generate(lvl, Gen.seed_for(lvl))
		all.append(p)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://games/block_escape"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(all))
	f.close()
	print("wrote %d levels to %s" % [all.size(), OUT])
	quit()
