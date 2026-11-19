extends SceneTree

## TerrainGen (tools/templates/terrain_gen.gd) + its users.
## godot --headless --path . --script res://tools/test_terrain_gen.gd
## - same seed = same map; heights stay in 0..1 and use the full range
## - max_slope is respected (every hill crossable)
## - remap_shares puts the asked share of cells under each level
## - Thrust: both start spots in one open (non-rock) region on every campaign map
## - Wolf Pack: no neighbouring cells steeper than the cap; climbing never stops anyone

func _init() -> void:
	var T = load("res://tools/templates/terrain_gen.gd")
	var fails := 0
	var a: PackedFloat32Array = T.generate(120, 90, 42, {"max_slope": 0.04})
	var b: PackedFloat32Array = T.generate(120, 90, 42, {"max_slope": 0.04})
	if a != b:
		print("FAIL not deterministic"); fails += 1
	var lo := 1.0
	var hi := 0.0
	var worst := 0.0
	for y in 90:
		for x in 120:
			var v: float = a[y * 120 + x]
			lo = minf(lo, v); hi = maxf(hi, v)
			if x > 0: worst = maxf(worst, absf(v - a[y * 120 + x - 1]))
			if y > 0: worst = maxf(worst, absf(v - a[(y - 1) * 120 + x]))
	if lo < 0.0 or hi > 1.0 or hi - lo < 0.6:
		print("FAIL range %.3f..%.3f" % [lo, hi]); fails += 1
	if worst > 0.04 + 0.0001:
		print("FAIL max_slope: step %.4f" % worst); fails += 1
	var c: PackedFloat32Array = T.generate(120, 90, 7)
	T.remap_shares(c, [[0.2, 0.3], [0.9, 0.8]])
	var under := 0
	var over := 0
	for v in c:
		if v < 0.3: under += 1
		if v >= 0.8: over += 1
	if absf(under / 10800.0 - 0.2) > 0.01 or absf(over / 10800.0 - 0.1) > 0.01:
		print("FAIL remap_shares %.3f %.3f" % [under / 10800.0, over / 10800.0]); fails += 1
	print("generator: range %.2f..%.2f, steepest step %.4f" % [lo, hi, worst])

	# Thrust: the two craft can always reach each other.
	var HD = load("res://scripts/games/hover_duel/hover_duel_engine.gd")
	for lv in HD.CAMPAIGN.size():
		var bt: Dictionary = HD.CAMPAIGN[lv]
		var e = HD.new()
		e.reset(bt.theme, bt.seed, ["skimmer", bt.foe], [2, 2])
		var start := Vector2i(int(e.crafts[0].p.x / HD.CELL), int(e.crafts[0].p.y / HD.CELL))
		var goal := Vector2i(int(e.crafts[1].p.x / HD.CELL), int(e.crafts[1].p.y / HD.CELL))
		var seen := PackedByteArray()
		seen.resize(HD.GW * HD.GH)
		var q: Array = [start]
		seen[start.y * HD.GW + start.x] = 1
		var open := 0
		while not q.is_empty():
			var p: Vector2i = q.pop_back()
			open += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = p + d
				if n.x < 0 or n.y < 0 or n.x >= HD.GW or n.y >= HD.GH or seen[n.y * HD.GW + n.x]:
					continue
				if e.hgt[n.y * HD.GW + n.x] >= e.theme.rock:
					continue
				seen[n.y * HD.GW + n.x] = 1
				q.append(n)
		if not seen[goal.y * HD.GW + goal.x]:
			print("FAIL thrust lv %d: craft can't reach each other" % lv); fails += 1
		print("thrust lv %d %s: start region %d%% of the map" % [lv, bt.theme, 100 * open / (HD.GW * HD.GH)])

	# Wolf Pack: hills everywhere, none too steep to climb.
	var WP = load("res://scripts/games/wolf_pack/wolf_pack_engine.gd")
	for s in [1, 77, 4242]:
		var w = WP.new()
		w.reset(s)
		var steep := 0.0
		var wlo := 1.0
		var whi := 0.0
		for y in range(1, WP.TGH):
			for x in range(1, WP.TGW):
				var v: float = w.hgt[y * WP.TGW + x]
				wlo = minf(wlo, v); whi = maxf(whi, v)
				steep = maxf(steep, absf(v - w.hgt[y * WP.TGW + x - 1]))
				steep = maxf(steep, absf(v - w.hgt[(y - 1) * WP.TGW + x]))
		if steep > float(WP.TERRAIN.max_slope) + 0.0001:
			print("FAIL wolf seed %d too steep %.4f" % [s, steep]); fails += 1
		if whi - wlo < 0.6:
			print("FAIL wolf seed %d flat (%.2f)" % [s, whi - wlo]); fails += 1
		# A trot straight up the steepest hill still moves.
		var slow := 1.0
		for k in 400:
			var p := Vector2(w.rng.randf() * WP.W, w.rng.randf() * WP.H)
			for ang in 8:
				slow = minf(slow, w.slope_mult(p, Vector2.RIGHT.rotated(TAU * ang / 8.0)))
		if slow < WP.SLOPE_MIN - 0.0001:
			print("FAIL wolf seed %d slope_mult %.2f" % [s, slow]); fails += 1
		# Save keeps the same hills (rebuilt from the seed).
		var w2 = WP.new()
		w2.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
		if w2.hgt != w.hgt:
			print("FAIL wolf save hills differ"); fails += 1
		print("wolf seed %d: heights %.2f..%.2f, steepest step %.4f, slowest climb x%.2f" % [s, wlo, whi, steep, slow])
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
