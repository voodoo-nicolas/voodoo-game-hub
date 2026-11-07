extends SceneTree

## Headless check of the Maze Trail engine: the 195-level schedule (10 + 1
## challenge from the next tier, three times per tier block; Insane 30), every
## level builds the same way twice, is a perfect maze, its par route wins, keys
## open their gates, and a locked gate really blocks.
## godot --headless --path . --script res://tools/test_maze_trail.gd

const E = preload("res://scripts/games/maze_trail/maze_trail_engine.gd")

func _init() -> void:
	var fails := 0
	var t0 := Time.get_ticks_msec()
	var sch: Array = E.schedule()
	if sch.size() != E.LEVEL_COUNT or E.LEVEL_COUNT != 195:
		fails += 1; print("FAIL: schedule has %d levels" % sch.size())
	var per_tier := {}
	var sneaks := 0
	for i in sch.size():
		var li: Dictionary = sch[i]
		if li.sneak:
			sneaks += 1
			if (i + 1) % 11 != 0: fails += 1; print("FAIL: challenge at level %d" % (i + 1))
			if int(li.tier) != E.block_of(i + 1) + 1: fails += 1; print("FAIL: level %d challenge tier" % (i + 1))
		else:
			per_tier[li.tier] = per_tier.get(li.tier, 0) + 1
	for t in 6:
		if per_tier.get(t, 0) != 30: fails += 1; print("FAIL: tier %d has %d mazes" % [t, per_tier.get(t, 0)])
	if sneaks != 15: fails += 1; print("FAIL: %d challenge mazes" % sneaks)
	var key_levels := 0
	var fog_levels := 0
	var par_by_tier := {}
	for n in range(1, E.LEVEL_COUNT + 1):
		var e = E.new()
		var p: Dictionary = E.params_for(n)
		e.generate(p, E.seed_for(n))
		var e2 = E.new()
		e2.generate(p, E.seed_for(n))
		if e.walls != e2.walls or e.start != e2.start or e.exit != e2.exit:
			fails += 1; print("FAIL: level %d not repeatable" % n)
		# Perfect maze: w*h-1 passages, every cell reachable.
		var open := 0
		for c in e.w * e.h:
			for d in 4:
				if e.walls[c] & E.BITS[d] == 0: open += 1
		if open != (e.w * e.h - 1) * 2: fails += 1; print("FAIL: level %d not a perfect maze" % n)
		var dist: PackedInt32Array = e.distances(e.start)
		if dist.has(-1): fails += 1; print("FAIL: level %d unreachable cells" % n)
		if e.keys.size() != int(p.keys): fails += 1; print("FAIL: level %d wants %d keys, has %d" % [n, p.keys, e.keys.size()])
		if e.keys.size() > 0: key_levels += 1
		if e.fog > 0: fog_levels += 1
		if e.par <= 0: fails += 1; print("FAIL: level %d par %d" % [n, e.par]); continue
		var t: int = int(p.tier)
		if not par_by_tier.has(t): par_by_tier[t] = []
		par_by_tier[t].append(e.par)
		# A closed gate blocks: the plain way to the exit (no keys) must fail.
		if e.gates.size() > 0 and not e.route(e.start, e.exit, true).is_empty():
			fails += 1; print("FAIL: level %d gate does not block" % n)
		# Walk the solution.
		var path: Array = e.solution_from_here()
		for c in path:
			var d := E.DIRS.find(c - e.player)
			if d < 0: fails += 1; print("FAIL: level %d solution jumps" % n); break
			var r: String = e.step(d)
			if r == "" or r == "locked": fails += 1; print("FAIL: level %d solution blocked (%s)" % [n, r]); break
		if not e.won: fails += 1; print("FAIL: level %d solution doesn't win" % n)
		if e.steps != e.par: fails += 1; print("FAIL: level %d steps %d != par %d" % [n, e.steps, e.par])
		if e.stars() != 3: fails += 1; print("FAIL: level %d par isn't 3 stars" % n)
		for k in e.keys:
			if not k.got: fails += 1; print("FAIL: level %d key left behind" % n)
		# Save round trip mid-maze.
		e.reset()
		var half: Array = e.solution_from_here()
		for i in half.size() / 2:
			e.step(E.DIRS.find(half[i] - e.player))
		var saved: Dictionary = e.to_dict()
		var e3 = E.new()
		e3.generate(p, E.seed_for(n))
		e3.from_dict(JSON.parse_string(JSON.stringify(saved)))
		if e3.player != e.player or e3.steps != e.steps: fails += 1; print("FAIL: level %d save round trip" % n)
		if e3.solution_from_here() != e.solution_from_here(): fails += 1; print("FAIL: level %d save keys/gates" % n)
		# run() stops at junctions and never reverses.
		e.reset()
		var moved: Array = e.run(E.DIRS.find(e.solution_from_here()[0] - e.player))
		if moved.is_empty() or moved[0] == "": fails += 1; print("FAIL: level %d run did not move" % n)
	for t in 6:
		var a: Array = par_by_tier.get(t, [])
		var s := 0
		for v in a: s += v
		print("tier %d (%s): avg par %.1f, min %d, max %d" % [t, E.TIERS[t], s / float(maxi(1, a.size())), a.min(), a.max()])
	print("key levels %d, fog levels %d" % [key_levels, fog_levels])
	print("maze_trail: %d failures (%d ms)" % [fails, Time.get_ticks_msec() - t0])
	quit(1 if fails > 0 else 0)
