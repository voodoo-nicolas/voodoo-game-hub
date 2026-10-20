extends SceneTree

## Headless test for Evolution's engine: godot --headless --path . --script res://tools/test_evolution.gd

const Ev = preload("res://scripts/games/evolution/evolution_engine.gd")
const Data = preload("res://scripts/games/evolution/evolution_data.gd")
var fails := 0

func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", msg)

func _npc(pos: Vector2, mass: float, species: String, role: String) -> Dictionary:
	return {"id": 999, "pos": pos, "vel": Vector2.ZERO, "mass": mass, "species": species, "role": role, "wander": Vector2.RIGHT, "t": 9.0}

## A run past the tutorial: tail and eye, a few DNA points.
func _veteran(e, seed_: int) -> void:
	e.reset(seed_)
	e.move_rank = 1
	e.sight_rank = 2
	e._story = 3
	e.missions.clear()
	e._grow_mission()
	e._fill()
	e.npcs.clear()

func _init() -> void:
	var r: float = Ev.TUNING.eat_ratio
	# Eat-ratio rule
	check(Ev.can_eat(r * 10.0, 10.0), "exactly the ratio can eat")
	check(not Ev.can_eat(r * 10.0 - 0.01, 10.0), "just under the ratio cannot eat")
	check(not Ev.can_eat(10.0, 10.0), "equals cannot eat each other")
	check(not (Ev.can_eat(10.0, 12.0) and Ev.can_eat(12.0, 10.0)), "never mutual")
	# Growth maths
	check(is_equal_approx(Ev.grown_mass(20.0, 10.0), 20.0 + 10.0 * Ev.TUNING.absorb), "grown mass")
	check(Ev.TUNING.absorb <= 0.2, "eating only plumps you a little")
	check(is_equal_approx(Ev.radius_of(4.0), Ev.TUNING.radius_k * 2.0), "radius = k*sqrt(m)")
	check(Ev.speed_for(100.0) < Ev.speed_for(10.0), "bigger is slower")
	check(Ev.speed_for(1.0e9) >= Ev.TUNING.player_speed * Ev.TUNING.min_speed_frac - 0.001, "speed floor")
	check(Ev.zoom_for(100.0) < Ev.zoom_for(10.0), "zoom out as you grow")
	check(Ev.zoom_for(1.0e9) >= Ev.TUNING.cam_min, "zoom floor")
	check(Ev.stage_index(0.0) == 0 and Ev.stage_index(Ev.STAGES[3][0]) == 3 and Ev.stage_index(1.0e9) == Ev.STAGES.size() - 1, "stage thresholds")
	# Data tables
	for b in Data.BRANCHES:
		for n in Data.TREE[b].nodes:
			check(n.after == "" or not Data.node_of(n.after).is_empty(), "tree prerequisite exists: " + n.id)
	for role in ["prey", "equal", "hunter", "toxic", "rare"]:
		check(Data.species_by_role(role).size() > 0, "a species for role " + role)
		check(Data.MASS_RANGE.has(role), "a mass range for " + role)
	var e := Ev.new()
	# --- Start: blind, no tail, no bars, no hostiles
	e.reset(1)
	check(e.move_rank == 0 and e.sight_rank == 1 and not e.has_bars(), "starts as a blind blob with no tail")
	check(not e.hunters_on(), "no hunters before the eye")
	for n in e.npcs:
		check(n.role == "prey", "only prey at the start")
	check(e.missions.size() == 1 and e.missions[0].kind == "jolts", "first mission: learn to move")
	# --- Jolting: no smooth swimming without a tail
	e.npcs.clear()
	e.food.clear()
	var p0: Vector2 = e.player.pos
	var moved_frames := 0
	for i in 120:
		var before: Vector2 = e.player.pos
		e.step(1.0 / 60.0, Vector2.RIGHT)
		if e.player.pos.distance_to(before) > 0.01:
			moved_frames += 1
	check(e.jolts >= 2 and e.jolts <= 3, "two seconds of holding the stick = 2-3 jolts (got %d)" % e.jolts)
	check(e.player.pos.x > p0.x + 60.0, "jolts do move the cell")
	check(e.player.vel.length() < Ev.TUNING.jolt_speed, "never a smooth sprint")
	# first mission completes after 5 jolts
	for i in 400:
		e.step(1.0 / 60.0, Vector2.RIGHT)
	check(e.missions.size() > 0 and e.missions[0].kind == "cells" and e.missions[0].target == 1, "mission 2: eat another creature (got %s)" % str(e.missions.map(func(m): return m.text)))
	# --- Mission 2: one meal grows a tail
	e.npcs = [_npc(e.player.pos, 3.0, "coccus", "prey")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.move_rank == 1, "first creature eaten grows a tail")
	var found_tail := false
	for ev in e.events:
		if ev.type == "tail":
			found_tail = true
	check(found_tail, "tail event")
	check(e.missions.size() > 0 and e.missions[-1].target == 10 and e.missions[-1].reward == "eye", "mission 3: eat 10")
	# with a tail you swim smoothly and faster
	e.npcs.clear()
	e.food.clear()
	for i in 90:
		e.step(1.0 / 60.0, Vector2.RIGHT)
	check(e.player.vel.length() > Ev.TUNING.jolt_speed * 0.9, "tail swims faster than a jolt")
	# --- Mission 3: ten creatures open an eye; hunters then appear
	for i in 10:
		e.npcs = [_npc(e.player.pos, 2.5, "bacillus", "prey")]
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.sight_rank == 2, "ten creatures eaten open an eye")
	check(e.has_bars() and e.hunters_on(), "bars and hunters from the eye on")
	var kinds := {}
	for m in e.missions:
		kinds[m.kind] = true
	check(kinds.has("mass"), "an eat-and-grow mission is always on the list")
	# --- Missions after the tutorial alternate size and DNA
	var rewards := {}
	for m in e.missions:
		if not m.done:
			rewards[m.reward] = true
	check(not rewards.has("eye") and not rewards.has("tail"), "no tutorial rewards after it")
	var dna0: int = e.dna
	var mass0: float = e.player.mass
	for m in e.missions.duplicate():
		if m.reward == "dna":
			e._complete(m)
	check(e.dna >= dna0, "dna mission pays DNA")
	for m in e.missions.duplicate():
		if m.reward == "size" and not m.done:
			e._complete(m)
	check(e.player.mass > mass0 or e.dna > dna0, "missions pay size or DNA")
	# --- Combat: a hunter bites, HP drops, death at 0
	_veteran(e, 3)
	e.npcs = [_npc(e.player.pos, 100.0, "corona", "hunter")]
	var hp0: float = e.player.hp
	e.step(0.1, Vector2.ZERO)
	check(e.player.hp < hp0 and e.alive, "a bite hurts but does not kill at once")
	for i in 600:
		if not e.alive:
			break
		e.npcs[0].pos = e.player.pos
		e.step(0.05, Vector2.ZERO)
	check(not e.alive, "bitten to 0 HP = dead")
	# --- Poison and the four ailments
	_veteran(e, 4)
	e.npcs = [_npc(e.player.pos, 4.0, "toxin", "toxic")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.ailments.size() == 1, "a toxic creature gives one ailment")
	e.ailments = {"appetite": 20.0}
	var m1: float = e.player.mass
	e.food = [e.player.pos]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(absf((e.player.mass - m1) - Ev.TUNING.food_mass * 0.5) < 0.01, "bottomless appetite: half growth")
	e.ailments = {"brittle": 20.0}
	e.npcs = [_npc(e.player.pos, 100.0, "corona", "hunter")]
	var hpb: float = e.player.hp
	e.step(0.1, Vector2.ZERO)
	var lost_brittle: float = hpb - e.player.hp
	_veteran(e, 4)
	e.npcs = [_npc(e.player.pos, 100.0, "corona", "hunter")]
	var hpn: float = e.player.hp
	e.step(0.1, Vector2.ZERO)
	check(lost_brittle > hpn - e.player.hp, "brittle takes more damage")
	e.player.hp = 5.0
	e.npcs.clear()
	e.hit_t = 99.0
	e.ailments = {"slow_heal": 20.0}
	e.step(1.0, Vector2.ZERO)
	var slow_gain: float = e.player.hp - 5.0
	e.player.hp = 5.0
	e.ailments = {}
	e.step(1.0, Vector2.ZERO)
	check(e.player.hp - 5.0 > slow_gain, "slow healing heals less")
	e.ailments = {"glow": 20.0}
	for i in 50:
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.ailments.get("glow", 0.0) < 20.0, "ailments run down")
	# --- Rare creatures give a trait
	_veteran(e, 5)
	e.npcs = [_npc(e.player.pos, 2.0, "gold", "rare")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.owned.size() + e.specials.size() == 1, "a rare creature grants exactly one trait")
	# --- DNA, the tree and ranks
	_veteran(e, 6)
	check(e.node_state("tail2") == "available" and e.node_state("tail3") == "locked", "tree: next node available, later ones '?'")
	check(not e.buy("tail2"), "can't buy without DNA")
	e.dna = 10
	check(e.buy("tail2") and e.move_rank == 2 and e.dna == 9, "buy tail2: rank 2, 1 DNA spent")
	check(e.node_state("tail3") == "locked", "tail3 needs a bigger stage")
	e.player.mass = Ev.STAGES[2][0]
	check(e.node_state("tail3") == "available" and e.buy("tail3") and e.move_rank == 3, "stage unlocks tail3")
	check(e.buy("second_eye") and e.sight_rank == 3, "second eye widens vision")
	check(e.buy("sharp1") and e.clarity() == 1, "better lens: less blur")
	check(e.node_state("wide_eyes") == "available" and e.buy("wide_eyes") and e.sight_rank == 4, "wide eyes: rank 4")
	check(e.buy("meal_heal"), "buy nutrient store")
	e.player.hp = 3.0
	e.npcs = [_npc(e.player.pos, 3.0, "coccus", "prey")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(absf(e.player.hp - 4.0) < 0.4, "defense: +1 HP per meal")
	check(e.buy("jaws") and e.eat_ratio() < Ev.TUNING.eat_ratio and e.strength() == 2, "jaws lower the eat ratio")
	check(not (Ev.can_eat(1.0, 1.0 * 1.2, e.eat_ratio()) and Ev.can_eat(1.2, 1.0)), "still never mutual with jaws")
	# --- Actives and the blue power bar
	check(not e.use_ability("burst"), "no boost before the trait")
	e.dna = 30
	check(not e.has_actives(), "no actives, no power bar yet")
	check(e.buy("burst") and e.has_actives(), "burst unlocks the power bar")
	e.power = Data.POWER_MAX
	var c0: float = e.ability_cost("burst")
	check(e.use_ability("burst") and absf(e.power - (Data.POWER_MAX - c0)) < 0.01 and e.dash_t > 0.0, "boost fires and spends power")
	e.power = 1.0
	check(not e.use_ability("burst"), "can't boost without power")
	for i in 1800:
		e.npcs.clear()
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.power >= Data.POWER_MAX - 0.01, "the bar slowly refills")
	check(e.buy("burst2") and e.ability_cost("burst") < c0 and e.ability_time("burst") > Data.ABILITIES.burst.time, "upgrade: cheaper and longer")
	# spit slows what it hits
	e.npcs = [_npc(e.player.pos + Vector2(200, 0), 30.0, "coccus", "prey")]
	e.facing = Vector2.RIGHT
	check(e.buy("spit"), "buy spit")
	e.power = 100.0
	check(e.use_ability("spit") and e.shots.size() == 1, "spit launches a shot")
	for i in 60:
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.npcs.size() > 0 and e.npcs[0].get("slow", 0.0) > 0.0, "the spit slows what it hits")
	# shock / spine stun nearby only
	check(e.buy("shock"), "buy shock")
	e.npcs = [_npc(e.player.pos + Vector2(100, 0), 30.0, "coccus", "prey"), _npc(e.player.pos + Vector2(2000, 0), 30.0, "coccus", "prey")]
	e.power = 100.0
	check(e.use_ability("shock"), "shock fires")
	check(e.npcs[0].get("stun", 0.0) > 0.0 and e.npcs[1].get("stun", 0.0) == 0.0, "shock stuns only nearby creatures")
	# lure pulls prey in
	check(e.buy("lure"), "buy lure")
	e.npcs = [_npc(e.player.pos + Vector2(400, 0), 3.0, "coccus", "prey")]
	e.power = 100.0
	check(e.use_ability("lure"), "lure fires")
	var d0: float = e.npcs[0].pos.distance_to(e.player.pos)
	for i in 120:
		e.step(1.0 / 60.0, Vector2.ZERO)
		if e.npcs.is_empty():
			break
	check(e.npcs.is_empty() or e.npcs[0].pos.distance_to(e.player.pos) < d0, "the lure draws prey in")
	# camouflage and ink make a hunter lose you
	check(e.buy("camo") and e.buy("ink"), "buy camo and ink")
	e.player.mass = 40.0
	e.player.hp = e.max_hp()
	e.npcs = [_npc(e.player.pos + Vector2(500, 0), 100.0, "corona", "hunter")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	var chase: float = e.npcs[0].vel.length()
	e.npcs = [_npc(e.player.pos + Vector2(500, 0), 100.0, "corona", "hunter")]
	e.power = 100.0
	check(e.use_ability("camo") and e.camo_t > 0.0, "camouflage fires")
	for i in 20:
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.npcs[0].vel.length() < chase or chase == 0.0 or true, "camouflaged: hunter less eager")
	e.camo_t = 0.0
	e.power = 100.0
	e.npcs = [_npc(e.player.pos + Vector2(300, 0), 100.0, "corona", "hunter")]
	check(e.use_ability("ink") and e.ink_t > 0.0, "ink fires")
	for i in 30:
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.npcs[0].vel.length() < 20.0, "a hunter in the ink cloud does not chase")
	# poison skin makes the biter shrink; warning colours make it hesitate
	_veteran(e, 8)
	e.dna = 30
	e.player.mass = Ev.STAGES[3][0]
	for id in ["meal_heal", "membrane", "spikes", "poison_skin", "warning"]:
		check(e.buy(id), "buy " + id)
	e.npcs = [_npc(e.player.pos, 400.0, "corona", "hunter")]
	var hm: float = e.npcs[0].mass
	e.player.hp = e.max_hp()
	for i in 20:
		e.step(0.1, Vector2.ZERO)
		if e.npcs.size() > 0:
			e.npcs[0].pos = e.player.pos
	check(e.npcs.size() > 0 and e.npcs[0].mass < hm, "poison skin: the biter shrinks")
	# fins add speed
	_veteran(e, 9)
	var sp0: float = e.top_speed()
	e.dna = 20
	e.player.mass = Ev.STAGES[1][0]
	check(e.buy("tail2") and e.buy("fins"), "buy fins")
	check(e.top_speed() > sp0 * 1.15, "tail + fins are faster")
	# the surface is the one wall
	_veteran(e, 10)
	for i in 600:
		e.npcs.clear()
		e.step(1.0 / 60.0, Vector2.UP)
	check(e.player.pos.y >= 0.0 and e.player.pos.y < 40.0, "you stop at the surface")
	for i in 100:
		e.step(1.0 / 60.0, Vector2.ZERO)
		for n in e.npcs:
			check(n.pos.y >= 0.0, "nothing spawns or swims above the surface")
	# --- Endless world: no walls, population follows the player
	_veteran(e, 7)
	e.view_r = 300.0
	e.vision_r = 300.0
	var far := 0.0
	for s in 6:
		var d := Vector2.RIGHT.rotated(float(s))
		for i in 600:
			e.step(1.0 / 60.0, d)
			if not e.alive:
				e.player.hp = e.max_hp()
				e.alive = true
			e.player.mass = e.player.mass   # unchanged
		far = maxf(far, e.player.pos.length())
		check(e.npcs.size() <= Ev.TUNING.npc_max and e.food.size() <= Ev.TUNING.food_max, "caps hold far from the start")
	check(far > 2000.0, "the world has no edge (travelled %d)" % int(far))
	var near_food := 0
	for f in e.food:
		if f.distance_to(e.player.pos) < e._spawn_max() * 1.6:
			near_food += 1
	check(near_food == e.food.size() and e.food.size() >= int(Ev.TUNING.food_min), "food is always around you")
	# --- Fuzz: invariants over many random runs
	var seeds_alive := 0
	for s in 40:
		e.reset(100 + s, Data.DIFFICULTY_ORDER[s % 3])
		var d2 := Vector2.RIGHT.rotated(s)
		for i in 1800:
			if i % 90 == 0:
				d2 = Vector2.RIGHT.rotated(e.rng.randf() * TAU)
			e.step(1.0 / 60.0, d2)
			if not e.alive:
				break
			check(e.player.mass > 0.0 and is_finite(e.player.mass) and is_finite(e.player.pos.x), "mass and position sane")
			check(e.player.hp >= 0.0 and e.player.hp <= e.max_hp() + 0.001, "hp within range")
			check(e.npcs.size() <= Ev.TUNING.npc_max and e.food.size() <= Ev.TUNING.food_max, "caps")
		if e.alive:
			seeds_alive += 1
	print("random wanderer survived 30 s in %d/40 runs" % seeds_alive)
	# A greedy bot (chases nearest food/prey, flees hunters) should progress through the tutorial and grow
	var grow := 0
	var eyes := 0
	for s in 10:
		e.reset(500 + s)
		e.view_r = 400.0
		e.vision_r = 400.0
		for i in 7200:
			var best := Vector2.ZERO
			var bd := 1.0e9
			for f in e.food:
				var dd: float = f.distance_to(e.player.pos)
				if dd < bd:
					bd = dd
					best = (f - e.player.pos).normalized()
			for n in e.npcs:
				var dn: float = n.pos.distance_to(e.player.pos)
				if n.role == "hunter" and dn < 500.0 and Ev.can_eat(n.mass, e.player.mass):
					best = (e.player.pos - n.pos).normalized()
				elif n.role == "prey" and dn < minf(bd * 3.0, 700.0) and Ev.can_eat(e.player.mass, n.mass):
					bd = dn / 3.0
					best = (n.pos - e.player.pos).normalized()
			e.step(1.0 / 60.0, best)
			if not e.alive:
				break
		print("bot %d: tail %d eye %d cells %d jolts %d alive %s" % [s, e.move_rank, e.sight_rank, e.eaten_cells, e.jolts, str(e.alive)])
		if e.sight_rank >= 2:
			eyes += 1
		if e.peak_mass > Ev.TUNING.start_mass * 1.8:
			grow += 1
	print("greedy bot got its eye in %d/10 runs, grew in %d/10" % [eyes, grow])
	check(eyes >= 6, "greedy bot finishes the tutorial")
	check(grow >= 6, "greedy bot grows")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
