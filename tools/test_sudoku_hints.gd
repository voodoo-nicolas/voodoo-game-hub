extends SceneTree
## Plays puzzles with hints only: every single a hint names must match the
## solution and every elimination must cross out a wrong number.
## godot --headless --path . --script res://tools/test_sudoku_hints.gd

const Gen = preload("res://scripts/games/sudoku/sudoku_generator.gd")
const Hints = preload("res://scripts/games/sudoku/sudoku_hints.gd")

func _init() -> void:
	var fails := 0
	for d in ["easy", "medium", "hard", "expert"]:
		var kinds := {}
		for t in range(15):
			var p := Gen.generate_puzzle(d)
			var grid := []
			var sol := []
			for r in range(9):
				for c in range(9):
					grid.append(p.puzzle[r][c])
					sol.append(p.solution[r][c])
			var elim := {}
			while true:
				var h := Hints.find(grid, elim, -1)
				if h.is_empty():
					break
				kinds[h.kind] = kinds.get(h.kind, 0) + 1
				if h.kind in ["hidden", "naked"]:
					if sol[h.cell] != h.digit:
						fails += 1
						print("BAD single ", h)
					grid[h.cell] = sol[h.cell]
				elif h.kind == "fewest":
					if not (sol[h.cell] in h.digits):
						fails += 1
						print("BAD fewest ", h)
					grid[h.cell] = sol[h.cell]  # player guesses right eventually
				else:
					for key in h.elim:
						var parts: PackedStringArray = key.split(":")
						if sol[int(parts[0])] == int(parts[1]):
							fails += 1
							print("BAD elim ", key, " ", h.kind)
						elim[key] = true
			if grid != sol:
				fails += 1
		print(d, " ", kinds)
	print("FAILS ", fails)
	quit(1 if fails else 0)
