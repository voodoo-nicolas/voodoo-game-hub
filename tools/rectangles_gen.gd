extends SceneTree

## Writes the Classic level pack for Rectangles (working title Gridmaster).
## godot --headless --path . --script res://tools/rectangles_gen.gd
## 300 levels, sizes 5x5 to 10x10 (Gen.classic_spec). Within each board size the levels are
## sorted by the logic solver's score, so difficulty rises steadily from level 1 to 300.
## Every level: clue sum == cells, exactly one solution, solvable by logic (no guessing).

const Gen = preload("res://scripts/games/rectangles/rectangles_generator.gd")
const Solver = preload("res://scripts/games/rectangles/rectangles_solver.gd")
const OUT := "res://games/rectangles/levels/classic_1.json"
const COUNT := 300

func _init() -> void:
	var by_size := {}  # size -> [puzzle, ...] in level order
	for lvl in range(1, COUNT + 1):
		var spec := Gen.classic_spec(lvl)
		var n: int = spec["size"]
		var p := Gen.generate(n, n, spec["seed"], spec["tier"])
		var sum := 0
		for cl in p.clues:
			sum += int(cl.n)
		assert(sum == n * n)
		assert(Solver.count_solutions(n, n, p.clues, 2) == 1)
		if not by_size.has(n):
			by_size[n] = []
		by_size[n].append(p)
	var levels: Array = []
	var sizes: Array = by_size.keys()
	sizes.sort()
	for n in sizes:
		var list: Array = by_size[n]
		list.sort_custom(func(a, b): return int(a.score) < int(b.score) or (int(a.score) == int(b.score) and int(a.seed) < int(b.seed)))
		levels.append_array(list)
	for i in levels.size():
		levels[i]["id"] = "classic-%03d" % (i + 1)
		print("%s  %dx%d  clues %d  difficulty %d  score %d" % [levels[i].id, levels[i]["size"][0], levels[i]["size"][1],
			levels[i].clues.size(), levels[i].difficulty, levels[i].score])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(levels))
	f.close()
	print("wrote ", OUT)
	quit()
