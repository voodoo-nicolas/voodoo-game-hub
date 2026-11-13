extends SceneTree

## Headless test for Bridge Master's engine (no scene, no saves touched).
## godot --headless --path . --script res://tools/test_bridge_master.gd

const E = preload("res://scripts/games/bridge_master/bridge_master_engine.gd")
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	E.load_table()
	var vehicles := {}
	for n in range(1, E.LEVEL_COUNT + 1):
		var lv := E.level(n)
		check(lv == E.level(n), "level %d deterministic" % n)
		check(int(lv.w) % 2 == 0 and int(lv.w) >= 4, "level %d even span" % n)
		check(int(lv.ref) > 0, "level %d has a proven reference bridge" % n)
		check(int(lv.ref) <= int(lv.budget), "level %d reference within budget" % n)
		check("road" in lv.mats, "level %d has road" % n)
		for a in lv.anchors:
			check(E.can_place(lv, int(a[0]), int(a[1])), "level %d anchor placeable" % n)
		vehicles[lv.vehicle] = vehicles.get(lv.vehicle, 0) + 1
	print("vehicles: ", vehicles)
	# Spot-check: the table's claim holds (a reference bridge crosses), and a bare road snaps.
	for n in [1, 37, 120, 233, 300]:
		var lv := E.level(n)
		var found := false
		for h in [2, 3, 4]:
			for chord in ["wood", "steel"]:
				for web in ["wood", "steel"]:
					for road in ["road", "sroad"]:
						if found or not (chord in lv.mats and web in lv.mats and road in lv.mats):
							continue
						var d := E.ref_design(lv, h, chord, web, road)
						if not d.is_empty() and E.design_cost(d) == int(lv.ref):
							found = E.simulate(lv, d) == "win"
		check(found, "level %d reference crosses" % n)
		var bare: Array = []
		var x := 0
		while x < int(lv.w):
			bare.append([x, 0, x + 2, 0, "road"])
			x += 2
		if int(lv.dh) == 0 and int(lv.w) >= 8:
			check(E.simulate(lv, bare) == "fail", "level %d bare road fails" % n)
	# Editor rules.
	var lv1 := E.level(1)
	check(E.check_member(lv1, [], 0, 0, 2, 0, "road") == "", "road piece ok")
	check(E.check_member(lv1, [], 0, 0, 3, 0, "road") != "", "road too long")
	check(E.check_member(lv1, [], 0, 0, -1, -1, "wood") != "", "inside rock refused")
	check(E.check_member(lv1, [[0, 0, 2, 0, "road"]], 2, 0, 0, 0, "road") == "same", "duplicate refused")
	check(E.clamp_reach(0, 0, 9.0, 0.0, "wood") == Vector2i(3, 0), "drag clamps to reach")
	check(E.design_cost([[0, 0, 2, 0, "road"]]) == 240, "cost maths")
	print("fails: ", fails)
	quit(1 if fails > 0 else 0)
