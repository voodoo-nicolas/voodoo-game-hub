extends SceneTree

## Headless test for Evolution's engine: godot --headless --path . --script res://tools/test_evolution.gd

const Ev = preload("res://scripts/games/evolution/evolution_engine.gd")
var fails := 0

func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var r: float = Ev.TUNING.eat_ratio
	# Eat-ratio rule
	check(Ev.can_eat(r * 10.0, 10.0), "exactly the ratio can eat")
	check(not Ev.can_eat(r * 10.0 - 0.01, 10.0), "just under the ratio cannot eat")
	check(not Ev.can_eat(10.0, 10.0), "equals cannot eat each other")
	check(not (Ev.can_eat(10.0, 12.0) and Ev.can_eat(12.0, 10.0)), "never mutual")
	# Growth maths
	check(is_equal_approx(Ev.grown_mass(20.0, 10.0), 20.0 + 10.0 * Ev.TUNING.absorb), "grown mass")
	check(is_equal_approx(Ev.radius_of(4.0), Ev.TUNING.radius_k * 2.0), "radius = k*sqrt(m)")
	check(Ev.radius_of(40.0) > Ev.radius_of(10.0), "radius grows with mass")
	check(Ev.speed_for(100.0) < Ev.speed_for(10.0), "bigger is slower")
	check(Ev.speed_for(1.0e9) >= Ev.TUNING.player_speed * Ev.TUNING.min_speed_frac - 0.001, "speed floor")
	check(Ev.zoom_for(100.0) < Ev.zoom_for(10.0), "zoom out as you grow")
	check(Ev.zoom_for(1.0e9) >= Ev.TUNING.cam_min, "zoom floor")
	check(Ev.stage_index(0.0) == 0 and Ev.stage_index(Ev.STAGES[3][0]) == 3 and Ev.stage_index(1.0e9) == Ev.STAGES.size() - 1, "stage thresholds")
	# Eating food in the engine
	var e := Ev.new()
	e.reset(1)
	e.npcs.clear()
	e.food = [e.player.pos]
	var m0: float = e.player.mass
	e.step(0.016, Vector2.ZERO)
	check(e.player.mass > m0 - 0.1 and e.eaten_food == 1, "food on contact is eaten")
	# Eating a smaller cell / dying to a bigger one
	e.reset(2)
	e.food.clear()
	e.npcs = [{"pos": e.player.pos, "vel": Vector2.ZERO, "mass": 5.0, "wander": Vector2.RIGHT, "t": 9.0}]
	e.step(0.016, Vector2.ZERO)
	check(e.eaten_cells == 1 and e.alive, "smaller cell eaten")
	e.reset(3)
	e.npcs = [{"pos": e.player.pos, "vel": Vector2.ZERO, "mass": 100.0, "wander": Vector2.RIGHT, "t": 9.0}]
	e.step(0.016, Vector2.ZERO)
	check(not e.alive, "bigger cell kills")
	# Fuzz: invariants over many random runs
	var seeds_alive := 0
	for s in 40:
		e.reset(100 + s)
		var d := Vector2.RIGHT.rotated(s)
		for i in 1800:
			if i % 90 == 0:
				d = Vector2.RIGHT.rotated(e.rng.randf() * TAU)
			e.step(1.0 / 60.0, d)
			if not e.alive:
				break
			check(e.player.mass > 0.0 and is_finite(e.player.mass), "mass sane")
			check(e.player.pos.x >= 0.0 and e.player.pos.x <= Ev.TUNING.arena, "inside arena")
			check(e.npcs.size() <= Ev.TUNING.microbe_count and e.food.size() <= Ev.TUNING.food_count, "caps")
		if e.alive:
			seeds_alive += 1
	print("random wanderer survived 30 s in %d/40 runs" % seeds_alive)
	# A greedy bot (chases nearest food, flees hunters) should grow
	var grow := 0
	for s in 10:
		e.reset(500 + s)
		for i in 3600:
			var best := Vector2.ZERO
			var bd := 1.0e9
			for f in e.food:
				var dd: float = f.distance_to(e.player.pos)
				if dd < bd:
					bd = dd
					best = (f - e.player.pos).normalized()
			for n in e.npcs:
				var dn: float = n.pos.distance_to(e.player.pos)
				if dn < 500.0 and Ev.can_eat(n.mass, e.player.mass):
					best = (e.player.pos - n.pos).normalized()
			e.step(1.0 / 60.0, best)
			if not e.alive:
				break
		if e.peak_mass > Ev.TUNING.start_mass * 3.0:
			grow += 1
	print("greedy bot tripled mass in %d/10 runs" % grow)
	check(grow >= 6, "greedy bot grows")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
