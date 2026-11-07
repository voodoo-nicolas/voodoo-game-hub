extends SceneTree

## Headless check of the Tilt Maze engine: the 195-level schedule, every level
## builds the same way twice, has a safe way from start to goal, holes never sit
## at the start or goal, and a steering bot (follows the safe way at a careful
## speed) rolls the marble into the goal. Prints per tier how the bot's times
## compare with par (par is meant to be beatable but not by a slow, safe roll).
## godot --headless --path . --script res://tools/test_tilt_maze.gd [-- first last]

const E = preload("res://scripts/games/tilt_maze/tilt_maze_engine.gd")
const DT := 1.0 / 60.0

func _init() -> void:
	var fails := 0
	var t0 := Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	var first := 1
	var last: int = E.LEVEL_COUNT
	if args.size() >= 2:
		first = int(args[0])
		last = int(args[1])
	var sch: Array = E.schedule()
	if sch.size() != 195: fails += 1; print("FAIL: schedule %d" % sch.size())
	var by_tier := {}
	var gen_ms := 0
	for n in range(first, last + 1):
		var e = E.new()
		var p: Dictionary = E.params_for(n)
		var g0 := Time.get_ticks_msec()
		e.generate(p, E.seed_for(n))
		gen_ms = maxi(gen_ms, Time.get_ticks_msec() - g0)
		var e2 = E.new()
		e2.generate(p, E.seed_for(n))
		if e.walls != e2.walls or e.holes != e2.holes or e.goal != e2.goal:
			fails += 1; print("FAIL: level %d not repeatable" % n)
		var way: Array = e.safe_way(e.pos)
		if way.is_empty(): fails += 1; print("FAIL: level %d no safe way" % n); continue
		for hc in e.holes:
			if hc.distance_to(e.pos) < 0.9 or hc.distance_to(Vector2(e.goal) + Vector2(0.5, 0.5)) < 0.9:
				fails += 1; print("FAIL: level %d hole by start/goal" % n)
		var res := _bot(e, 2.4)
		var t: int = int(p.tier)
		if not by_tier.has(t): by_tier[t] = {"n": 0, "won": 0, "ratio": 0.0, "falls": 0, "three": 0, "holes": 0}
		var bt: Dictionary = by_tier[t]
		bt.n += 1
		bt.holes += e.holes.size()
		if res.won:
			bt.won += 1
			bt.ratio += e.time / e.par
			bt.falls += e.falls
			if e.stars() == 3: bt.three += 1
		else:
			print("  bot did not finish level %d (tier %d, falls %d)" % [n, t, e.falls])
	for t in by_tier:
		var b: Dictionary = by_tier[t]
		print("tier %d %-9s: bot finished %d/%d, time/par %.2f, falls %d, 3-star %d, holes %.1f avg" % [t, E.TIERS[t], b.won, b.n, b.ratio / maxf(1, b.won), b.falls, b.three, b.holes / float(b.n)])
		if b.won < b.n * 0.8: fails += 1; print("FAIL: tier %d bot finishes too few" % t)
	print("slowest generate: %d ms" % gen_ms)
	print("tilt_maze: %d failures (%d ms)" % [fails, Time.get_ticks_msec() - t0])
	quit(1 if fails > 0 else 0)

## Follows the safe way: aims half a cell ahead, slows near holes, steers by
## tilting toward the wanted velocity. Gives up after 3 minutes.
func _bot(e, speed: float) -> Dictionary:
	e.reset()
	var way: Array = e.safe_way(e.pos)
	var idx := 0
	while e.time < 180.0 and not e.won:
		var near := idx
		var best := 1e9
		for i in range(idx, mini(idx + 40, way.size())):
			var d: float = (way[i] as Vector2).distance_to(e.pos)
			if d < best:
				best = d
				near = i
		idx = near
		var target: Vector2 = way[mini(idx + 4, way.size() - 1)]
		var v := speed
		for hc in e.holes:
			if hc.distance_to(e.pos) < 1.0:
				v = speed * 0.6
		var want: Vector2 = (target - e.pos).normalized() * v
		var tilt: Vector2 = (want - e.vel) * 0.8
		for ev in e.update(DT, tilt):
			if ev[0] == "back":
				way = e.safe_way(e.pos)
				idx = 0
	return {"won": e.won}
