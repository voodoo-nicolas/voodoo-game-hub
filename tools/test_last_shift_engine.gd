extends SceneTree

## Headless logic test for slice 1:
##   godot --headless --path . --script res://tools/test_last_shift_engine.gd

const E = preload("res://scripts/games/last_shift/last_shift_engine.gd")

var fails := 0

func check(label: String, got, want) -> void:
	if got != want:
		fails += 1
		print("FAIL ", label, ": got ", got, " want ", want)

func _init() -> void:
	var D := E.Facing.DOWN
	var L := E.Facing.LEFT
	var R := E.Facing.RIGHT
	var U := E.Facing.UP
	check("zero keeps facing", E.facing_from_vector(Vector2.ZERO, L), L)
	check("right", E.facing_from_vector(Vector2.RIGHT, D), R)
	check("left", E.facing_from_vector(Vector2.LEFT, D), L)
	check("up", E.facing_from_vector(Vector2.UP, R), U)
	check("down", E.facing_from_vector(Vector2.DOWN, R), D)
	# Diagonals: stay on the current axis (hysteresis).
	check("diag keeps horizontal", E.facing_from_vector(Vector2(0.7, 0.72), R), R)
	check("diag keeps vertical", E.facing_from_vector(Vector2(0.72, 0.7), D), D)
	check("diag flips when clearly vertical", E.facing_from_vector(Vector2(0.3, 0.9), R), D)
	check("diag flips when clearly horizontal", E.facing_from_vector(Vector2(0.9, 0.3), U), R)
	check("to vector", E.facing_to_vector(U), Vector2.UP)
	check("name", E.facing_name(L), "left")
	print("last_shift_engine tests: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
