extends SceneTree

## Headless logic test for Ink Ninja's engine: every stage builds, the hero can
## stand at the start, a bot that runs right, jumps and slashes reaches the boss,
## and invariants hold. godot --headless --path . --script res://tools/test_ink_ninja.gd

const E = preload("res://scripts/games/ink_ninja/ink_ninja_engine.gd")
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	var reached := 0
	var won := 0
	for d in 3:
		for st in range(1, E.STAGES + 1):
			var e = E.new()
			e.reset(d)
			e.stage = st
			e.build_stage()
			check(e.on_ground and e.py == E.GROUND, "start on ground d%d s%d" % [d, st])
			check(e.foes.size() > 3, "foes d%d s%d" % [d, st])
			var t := 0.0
			var deaths := 0
			var best := 0.0
			var dt := 1.0 / 30.0
			while t < 150.0 and e.state == "play":
				var near_pit := false
				for p in e.pits:
					if e.px > p[0] - 90 and e.px < p[0]:
						near_pit = true
				var stuck: bool = absf(e.vx) < 30.0 and not e.locked
				var jump: bool = near_pit or stuck or (not e.on_ground and e.vy > -50.0 and e.jumps == 1) or (randf() < 0.02)
				var ev: Array = e.step(dt, 1.0 if not e.locked else signf(e.boss.get("x", e.px) - e.px), jump, randf() < 0.3, e.locked and randf() < 0.05, randf() < 0.01)
				check(e.hp <= E.MAX_HP and e.stars >= 0, "bounds")
				if e.state == "dead":
					e.lives = 3
					deaths += 1
					e.retry()
				best = maxf(best, e.px)
				t += dt
			if e.locked or best > e.arena_x:
				reached += 1
			else:
				print("stuck d%d s%d at x=%d/%d best=%d deaths=%d" % [d, st, e.px, e.arena_x, best, deaths])
			if e.state == "won":
				won += 1
	print("boss reached in %d/30 runs, won %d/30" % [reached, won])
	check(reached >= 25, "a random bot crosses almost every stage to the boss in 150 s")
	# next_stage past the last one clears the campaign
	var e2 = E.new()
	e2.reset(1)
	e2.stage = E.STAGES
	e2.state = "won"
	e2.next_stage()
	check(e2.state == "cleared", "cleared after stage 10")
	# Crouching: an enemy star at thrower height flies over; standing, it hits.
	for crouching in [true, false]:
		var e3 = E.new()
		e3.reset(1)
		e3.foes.clear()
		e3.shots = [{"x": e3.px + 200.0, "y": E.GROUND - 45.0, "vx": -520.0, "vy": 0.0, "mine": false, "life": 2.0}]
		for i in 60:
			e3.step(1.0 / 60.0, 0.0, false, false, false, false, crouching)
		check((e3.hp == E.MAX_HP) == crouching, "crouch=%s star %s" % [crouching, "misses" if crouching else "hits"])
	print("ink_ninja: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails else 0)
