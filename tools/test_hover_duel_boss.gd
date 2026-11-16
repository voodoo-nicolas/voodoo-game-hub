extends SceneTree

## Hover Duel: a boss launches drones, locked abilities stay locked, W thrust moves the ship forward.
## godot --headless --path . --script res://tools/test_hover_duel_boss.gd

func _init() -> void:
	var E = load("res://scripts/games/hover_duel/hover_duel_engine.gd")
	var fails := 0
	var e = E.new()
	e.reset("valley", 1101, ["skimmer", "barge"], [-1, 1], [{}, {}], [false, true], ["gun"])
	if e.crafts[0].missiles != 0 or e.crafts[1].mines != 0:
		print("FAIL locked abilities still stocked"); fails += 1
	var maxd := 0
	for i in 60 * 30:
		e.step(E.DT, [{}, {}])
		maxd = maxi(maxd, e.drones.size())
		if e.is_over():
			break
	print("max drones %d" % maxd)
	if maxd < 1:
		print("FAIL boss never launched a drone"); fails += 1
	# Keyboard steering: W alone flies forward fast, D turns right.
	var f = E.new()
	f.reset("valley", 1101, ["skimmer", "gnat"], [-1, -1])
	f.crafts[1].p = Vector2(100, 100)
	f.crafts[0].a = (Vector2(E.W, E.H) / 2.0 - f.crafts[0].p).angle()
	var sp := 0.0
	for i in 60:
		f.step(E.DT, [{"thrust": 1.0}, {}])
		sp = maxf(sp, f.crafts[0].v.length())
	print("speed peak in 1 s of W: %.0f (top %.0f; it may hit a cliff first)" % [sp, 330.0 * E.SPEED_K])
	if sp < 250.0:
		print("FAIL too slow"); fails += 1
	var a1: float = f.crafts[0].a
	for i in 30:
		f.step(E.DT, [{"turn": 1.0}, {}])
	var turned := absf(wrapf(f.crafts[0].a - a1, -PI, PI))
	print("turn in 0.5 s: %.2f rad" % turned)
	if turned < 2.0:
		print("FAIL turns too slowly"); fails += 1
	# Shots are not stopped by hills.
	print("FAILS: %d" % fails)
	quit()
