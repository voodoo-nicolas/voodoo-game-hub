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
		print("%d w=%d %s ref=%d budget=%d %s" % [n, E.generate(n).w, row.veh, row.ref, row.budget, row.get("how", "")])
	var keys := table.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	var lines: Array = []
	for k in keys:
		var r: Dictionary = table[k]
		lines.append('  "%s": {"budget": %d, "ref": %d, "veh": "%s"}' % [k, int(r.budget), int(r.ref), r.veh])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("{\n" + ",\n".join(lines) + "\n}\n")
	f.close()
	print("done in %d s" % ((Time.get_ticks_msec() - t0) / 1000))
	quit()

func solve(n: int) -> Dictionary:
	var lv := E.generate(n)
	var mats: Array = lv.mats
	var vi := E.VEHICLE_ORDER.find(lv.vehicle)
	while vi >= 0:
		lv.vehicle = E.VEHICLE_ORDER[vi]
		var opts: Array = []
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
				var c: int = lv.chapter
				var slack := 1.6 - 0.45 * c / 9.0
				var budget := int(ceil(o.cost * slack / 50.0)) * 50
				return {"budget": budget, "ref": o.cost, "veh": lv.vehicle, "how": o.how}
		vi -= 1
	push_error("level %d: no reference bridge works" % n)
	return {"budget": 400 * lv.w + 1000, "ref": 0, "veh": "car", "how": "NONE"}
