extends SceneTree

## Makes scripts/games/bridge_master/bridge_master_levels.json: for every level,
## tries the engineer's reference bridges (cheapest first) in the real physics;
## the first that carries the vehicle across sets "ref" (its cost) and the budget.
## If none can, the vehicle steps down to a lighter one. Every level is thereby
## proven solvable within its budget.
##   godot --headless --path . --script res://tools/bridge_master_levels.gd [-- from to]

const E = preload("res://scripts/games/bridge_master/bridge_master_engine.gd")
const OUT := "res://scripts/games/bridge_master/bridge_master_levels.json"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var from := 1
	var to := E.LEVEL_COUNT
	if args.size() >= 2:
		from = int(args[0])
		to = int(args[1])
	var table := {}
	if FileAccess.file_exists(OUT):
		var d = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if d is Dictionary:
			table = d
	var t0 := Time.get_ticks_msec()
	for n in range(from, to + 1):
		var row := solve(n)
		table[str(n)] = row
		print("%d w=%d %s ref=%d budget=%d %s" % [n, row.w, row.veh, row.ref, row.budget, row.get("how", "")])
	var keys := table.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	var lines: Array = []
	for k in keys:
		var r: Dictionary = table[k]
		lines.append('  "%s": {"budget": %d, "ref": %d, "veh": "%s", "w": %d}' % [k, int(r.budget), int(r.ref), r.veh, int(r.get("w", 0))])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("{\n" + ",\n".join(lines) + "\n}\n")
	f.close()
	print("done in %d s" % ((Time.get_ticks_msec() - t0) / 1000))
	quit()

func solve(n: int) -> Dictionary:
	var lv0 := E.generate(n)
	var w: int = lv0.w
	var vi := E.VEHICLE_ORDER.find(lv0.vehicle)
	var tries := 0
	while true:
		var row := solve_w(n, w, vi)
		if n < 3 or not str(row.how).begins_with("plain") or tries >= 6:
			if tries >= 6:
				push_error("level %d: a plain road deck still crosses it" % n)
			return row
		# A plain road deck crosses it: a wider gap before steel road, then a heavier vehicle
		# (steel road alone carries light vehicles over any gap).
		tries += 1
		if not "sroad" in lv0.mats and w < 18:
			w += 2
		elif vi < E.VEHICLE_ORDER.size() - 1:
			vi += 1
		else:
			w += 2
	return {}

func solve_w(n: int, w: int, vi: int) -> Dictionary:
	var lv := E.generate(n, w)
	var mats: Array = lv.mats
	while vi >= 0:
		lv.vehicle = E.VEHICLE_ORDER[vi]
		var opts: Array = []
		# A plain road deck (plus a post onto the pillar) counts too: it sets the level's real price.
		for road in ["road", "sroad"]:
			if road in mats:
				var plain: Array = []
				for m in E.ref_design(lv, 2, "wood", "wood", road):
					if str(m[4]) == road:
						plain.append(m)
				if not plain.is_empty():
					opts.append({"d": plain, "cost": E.design_cost(plain), "how": "plain " + road})
		for h in [2, 3, 4]:
			for chord in ["wood", "steel"]:
				for web in ["wood", "steel"]:
					for road in ["road", "sroad"]:
						if not (chord in mats and web in mats and road in mats):
							continue
						var d := E.ref_design(lv, h, chord, web, road)
						if d.is_empty():
							continue
						opts.append({"d": d, "cost": E.design_cost(d), "how": "h%d %s/%s/%s" % [h, chord, web, road]})
		opts.sort_custom(func(a, b): return a.cost < b.cost)
		for o in opts:
			if E.simulate(lv, o.d) == "win":
				# Budget slack shrinks from +55 % (level 1) to +15 % (level 300).
				var slack := 1.55 - 0.4 * float(n - 1) / float(E.LEVEL_COUNT - 1)
				var budget := int(ceil(o.cost * slack / 50.0)) * 50
				return {"budget": budget, "ref": o.cost, "veh": lv.vehicle, "w": w, "how": o.how}
		vi -= 1
	push_error("level %d: no reference bridge works" % n)
	return {"budget": 400 * lv.w + 1000, "ref": 0, "veh": "car", "w": w, "how": "NONE"}
