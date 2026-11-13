extends SceneTree

## Headless checks for Rectangles: solver, generator invariants, engine rules, shipped levels.
## godot --headless --path . --script res://tools/test_rectangles.gd

const Solver = preload("res://scripts/games/rectangles/rectangles_solver.gd")
const Gen = preload("res://scripts/games/rectangles/rectangles_generator.gd")
const E = preload("res://scripts/games/rectangles/rectangles_engine.gd")
const LEVELS := "res://games/rectangles/levels/classic_1.json"

var fails := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	# Known tiny puzzles: 2x2 with two 2s is ambiguous unless clues force it.
	var amb := [{"r": 0, "c": 0, "n": 2}, {"r": 1, "c": 1, "n": 2}]
	_check(Solver.count_solutions(2, 2, amb, 2) == 2, "2x2 diagonal 2s has two solutions")
	var uni := [{"r": 0, "c": 0, "n": 2}, {"r": 0, "c": 1, "n": 2}]
	_check(Solver.count_solutions(2, 2, uni, 2) == 1, "2x2 top-row 2s is unique")
	_check(Solver.count_solutions(2, 2, [{"r": 0, "c": 0, "n": 3}], 2) == 0, "bad sum has no solution")

	# Generator: many seeds, every size; invariants + uniqueness + determinism.
	for n in [5, 6, 7, 8]:
		for s in 8:
			var tier: int = [0, 1, 2, 3][s % 4]
			var p := Gen.generate(n, n, 1000 + s * 31 + n, tier, tier == 3)
			_check(not p.is_empty(), "generator returned a puzzle %dx%d" % [n, n])
			if p.is_empty():
				continue
			_check_puzzle(p, "gen %dx%d seed %d" % [n, n, s])
			var again := Gen.generate(n, n, 1000 + s * 31 + n, tier, tier == 3)
			_check(JSON.stringify(again) == JSON.stringify(p), "same seed gives same puzzle")
	var big := Gen.generate(10, 10, 104729 * 3 + 7, 3, true)
	_check_puzzle(big, "weekly 10x10")

	# Engine rules on a generated puzzle.
	var e = E.new()
	var p := Gen.generate(6, 6, 42, 1)
	_check(e.load_puzzle(p), "load_puzzle")
	var sol: Dictionary = e.solution_by_clue()
	_check(sol.size() == e.clues.size(), "solution maps every clue")
	var first: Array = sol[0]
	# all four drag directions give the same rectangle
	var a := Vector2i(first[1], first[0])
	var b := Vector2i(first[1] + first[3] - 1, first[0] + first[2] - 1)
	_check(e.rect_from(a, b) == first and e.rect_from(b, a) == first
		and e.rect_from(Vector2i(b.x, a.y), Vector2i(a.x, b.y)) == first
		and e.rect_from(Vector2i(a.x, b.y), Vector2i(b.x, a.y)) == first, "drag direction")
	_check(not e.place([0, 0, e.rows, e.cols]), "whole-board rect is invalid")
	_check(e.place(first) and e.placed_count() == 1, "place valid")
	_check(e.remove_at(a) and e.placed_count() == 0, "tap removes")
	_check(e.undo() and e.placed_count() == 1, "undo restores")
	_check(e.reset() and e.placed_count() == 0, "reset clears")
	# hint is always a solution rect
	for i in 4:
		var h: Array = e.hint_rect()
		var k: int = e.clue_of(h)
		_check(k >= 0 and sol[k] == h, "hint is correct")
		e.place(h)
	# overlap: a valid different rect for some clue removes the overlapped one
	for k in sol:
		e.place(sol[k])
	_check(e.solved(), "full solution wins")
	_check(e.placed_count() == e.clues.size(), "counter matches clues")
	e.undo()
	_check(not e.solved(), "undo un-wins")
	# save round trip
	var e2 = E.new()
	_check(e2.from_dict(JSON.parse_string(JSON.stringify(e.to_dict()))) and e2.placed == e.placed, "save round trip")

	# Shipped levels (if generated).
	if FileAccess.file_exists(LEVELS):
		var data = JSON.parse_string(FileAccess.get_file_as_string(LEVELS))
		_check(data is Array and data.size() == 300, "300 classic levels")
		for lp in data:
			_check_puzzle(lp, str(lp.get("id", "?")))
	else:
		print("note: ", LEVELS, " not generated yet (tools/rectangles_gen.gd)")

	print("rectangles: %s" % ("OK" if fails == 0 else "%d failures" % fails))
	quit(1 if fails else 0)

func _check_puzzle(p: Dictionary, label: String) -> void:
	var rows: int = int(p["size"][0])
	var cols: int = int(p["size"][1])
	var sum := 0
	for cl in p.clues:
		sum += int(cl.n)
	_check(sum == rows * cols, label + ": clue sum == cells")
	_check(Solver.count_solutions(rows, cols, p.clues, 2) == 1, label + ": exactly one solution")
	var e = E.new()
	e.load_puzzle(p)
	var sol: Dictionary = e.solution_by_clue()
	for k in sol:
		e.place(sol[k])
	_check(e.solved(), label + ": stored solution wins")
