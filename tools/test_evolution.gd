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

## A run past the tutorial: tail and eye, nothing around.
func _veteran(e, seed_: int) -> void:
	e.reset(seed_)
	e.move_rank = 1
	e.sight_rank = 2
	e._story = 3
	e.missions.clear()
	e._grow_mission()
	e._fill()
	e.npcs.clear()

## Hands out trait points without paying (to test effects, not the shop).
func give(e, id: String, rank: int = 1) -> void:
	e.owned[id] = rank
	e._recompute_ranks()
	e.auto_assign()

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
	var ids := {}
	var spots := {}
	var multi_req := 0
	var multi_child := {}
	var multi_point := 0
	for n in Data.NODES:
		check(not ids.has(n.id), "unique node id " + n.id)
		ids[n.id] = true
	for n in Data.NODES:
		check(Data.BRANCH.has(n.branch), "known branch: " + n.id)
		check(int(n.max) >= 1 and int(n.cost) >= 1, "sane max/cost: " + n.id)
		check(int(n.stage) < Ev.STAGES.size(), "sane stage: " + n.id)
		var key := "%s,%s" % [str(n.x), str(n.y)]
		check(not spots.has(key), "no two nodes on one spot: " + n.id)
		spots[key] = true
		if n.req.size() > 1:
			multi_req += 1
		if int(n.max) > 1:
			multi_point += 1
		for q in n.req:
			check(ids.has(q[0]), "prerequisite exists: %s needs %s" % [n.id, q[0]])
			check(int(q[1]) >= 1 and int(q[1]) <= int(Data.node_of(q[0]).max), "prerequisite points in range: " + n.id)
			check(float(Data.node_of(q[0]).x) < float(n.x), "prerequisites sit to the left: " + n.id)
			multi_child[q[0]] = int(multi_child.get(q[0], 0)) + 1
		if n.ability:
			check(Data.ABILITIES.has(n.id), "an ability entry for " + n.id)
	var kids3 := 0
	for k in multi_child:
		if multi_child[k] >= 2:
			kids3 += 1
	check(multi_req >= 5, "several traits need more than one prerequisite")
	check(multi_point >= 10, "several traits take more than one point")
	check(kids3 >= 5, "several traits open more than one option")
	for id in Data.ABILITY_ORDER:
		check(not Data.node_of(id).is_empty() and Data.node_of(id).ability, "ability has a node: " + id)
		check(Data.ABILITIES[id].kind == "off" or Data.ABILITIES[id].kind == "def", "ability kind: " + id)
	for role in ["prey", "equal", "hunter", "toxic", "rare"]:
		check(Data.species_by_role(role).size() > 0, "a species for role " + role)
		check(Data.MASS_RANGE.has(role), "a mass range for " + role)
	var e := Ev.new()
	# --- Start: blind, no tail, no bars, no hostiles, no buttons
	e.reset(1)
	check(e.move_rank == 0 and e.sight_rank == 1 and not e.has_bars(), "starts as a blind blob with no tail")
	check(not e.hunters_on(), "no hunters before the eye")
	for i in 4:
		check(not e.slot_visible(i), "no ability buttons at the start")
	for n in e.npcs:
		check(n.role == "prey", "only prey at the start")
		check(n.pos.y >= 0.0, "nothing starts above the surface")
	check(e.player.pos.y > 300.0, "you start well below the surface")
	check(e.missions.size() == 1 and e.missions[0].kind == "jolts", "first mission: learn to move")
	# --- Jolting: no smooth swimming without a tail
	e.npcs.clear()
	e.food.clear()
	var p0: Vector2 = e.player.pos
	for i in 120:
		e.step(1.0 / 60.0, Vector2.RIGHT)
	check(e.jolts >= 2 and e.jolts <= 3, "two seconds of holding the stick = 2-3 jolts (got %d)" % e.jolts)
	check(e.player.pos.x > p0.x + 60.0, "jolts do move the cell")
	check(e.player.vel.length() < Ev.TUNING.jolt_speed, "never a smooth sprint")
	for i in 400:
		e.step(1.0 / 60.0, Vector2.RIGHT)
	check(e.missions.size() > 0 and e.missions[0].kind == "cells" and e.missions[0].target == 1, "mission 2: eat another creature")
	# --- Mission 2: one meal grows a tail
	e.npcs = [_npc(e.player.pos, 3.0, "coccus", "prey")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.move_rank == 1, "first creature eaten grows a tail")
	check(e.missions.size() > 0 and e.missions[-1].target == 10 and e.missions[-1].reward == "eye", "mission 3: eat 10")
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
	var rewards := {}
	for m in e.missions:
		kinds[m.kind] = true
		if not m.done:
			rewards[m.reward] = true
	check(kinds.has("mass"), "an eat-and-grow mission is always on the list")
	check(not rewards.has("eye") and not rewards.has("tail"), "no tutorial rewards after it")
	var dna0: int = e.dna
	var mass0: float = e.player.mass
	for m in e.missions.duplicate():
		if m.reward == "dna" and not m.done:
			e._complete(m)
	for m in e.missions.duplicate():
		if m.reward == "size" and not m.done:
			e._complete(m)
	check(e.player.mass > mass0 and e.dna > dna0, "missions pay size and DNA")
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
	_veteran(e, 41)
	e.ailments = {}
	e.npcs = [_npc(e.player.pos, 4.0, "toxin", "toxic")]
	give(e, "meal_heal")
	give(e, "tox_res", 2)
	e.step(1.0 / 60.0, Vector2.ZERO)
	var shortest := 99.0
	for k in e.ailments:
		shortest = e.ailments[k]
	check(shortest < 25.0 * 0.5, "toxin resistance: ailments wear off sooner")
	# --- Rare creatures give a trait
	_veteran(e, 5)
	e.npcs = [_npc(e.player.pos, 2.0, "gold", "rare")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.owned.size() + e.specials.size() == 1, "a rare creature grants exactly one trait")
	# --- DNA, points, prerequisites (the tree)
	_veteran(e, 6)
	check(e.node_state("tail") == "available" and e.node_state("fins") == "locked", "tree: first nodes open, later ones '?'")
	check(not e.buy("tail"), "can't buy without DNA")
	e.dna = 30
	check(e.buy("tail") and e.move_rank == 2 and e.dna == 29, "tail point 1: rank 2, 1 DNA")
	check(e.cost_of("tail") == 2, "each further point costs one more")
	check(e.buy("tail") and e.move_rank == 3 and e.dna == 27, "tail point 2: rank 3")
	check(e.node_state("tail") == "maxed" and not e.buy("tail"), "a maxed trait can't be bought again")
	check(e.node_state("fins") == "stage", "fins: prerequisite owned, but you are not big enough")
	e.player.mass = Ev.STAGES[1][0]
	check(e.buy("fins") and e.buy("fins") and e.rank_of("fins") == 2, "fins take two points")
	check(e.node_state("streamlined") == "locked", "streamlined needs fins AND flagella")
	e.player.mass = Ev.STAGES[2][0]
	check(e.buy("flagella"), "flagella (needs tail 2)")
	check(e.reqs_met("streamlined") and e.reqs_met("cilia"), "flagella opens two traits at once")
	check(e.buy("streamlined"), "streamlined: both prerequisites owned")
	check(e.top_speed() > 0.0 and e.move_rank == 4, "tail 2 + flagella = move rank 4")
	# senses
	check(e.buy("second_eye") and e.sight_rank == 3, "second eye widens vision")
	check(e.buy("lens") and e.clarity() == 1, "lens point 1: less blur")
	check(e.node_state("real_eyes") == "locked", "real eyes need the lens twice and night vision")
	check(e.buy("night_vision") and e.buy("wide_eyes") and e.sight_rank == 4, "wide eyes: rank 4")
	check(e.buy("lens") and e.clarity() == 2, "lens point 2")
	e.player.mass = Ev.STAGES[3][0]
	check(e.buy("real_eyes") and e.clarity() == 3 and Data.BLUR[e.clarity()] == 0.0, "real eyes: no blur")
	# defense
	e.dna = 60
	check(e.buy("meal_heal"), "buy nutrient store")
	check(e.reqs_met("membrane") and e.reqs_met("tox_res") and not e.reqs_met("regen"), "nutrient store opens several traits")
	check(e.buy("meal_heal") and e.reqs_met("regen"), "regeneration needs 2 points of it")
	e.player.hp = 3.0
	e.npcs = [_npc(e.player.pos, 3.0, "coccus", "prey")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(absf(e.player.hp - 5.0) < 0.4, "defense: 2 points = +2 HP per meal")
	check(e.buy("membrane") and e.max_hp() == Ev.TUNING.base_hp + Ev.TUNING.membrane_hp, "membrane: more max HP")
	# offense
	check(e.buy("burst") and e.buy("jaws") and e.eat_ratio() < Ev.TUNING.eat_ratio and e.strength() == 2, "jaws lower the eat ratio")
	check(not (Ev.can_eat(1.0, 1.0 * 1.2, e.eat_ratio()) and Ev.can_eat(1.2, 1.0)), "still never mutual with jaws")
	# --- The ability buttons
	_veteran(e, 7)
	for i in 4:
		check(not e.slot_visible(i), "no buttons before any ability")
	give(e, "burst")
	check(e.slot_visible(0) and not e.slot_visible(1), "an offensive ability gives the offensive button only")
	check(e.slot_ids[0] == "burst", "it is assigned automatically")
	give(e, "ink")
	check(e.slot_visible(1) and e.slot_ids[1] == "ink", "a defensive ability gives the defensive button")
	check(not e.slot_visible(2) and not e.slot_visible(3), "buttons 3 and 4 come later")
	give(e, "spit")
	check(e.eligible(0).size() == 2 and not e.eligible(1).has("spit"), "buttons only take their own kind")
	var before: String = e.slot_ids[0]
	e.cycle_slot(0)
	check(e.slot_ids[0] != before and e.slot_ids[0] == "spit", "the player can choose the ability on a button")
	e.cycle_slot(0)
	check(e.slot_ids[0] == "burst", "...and cycle back")
	give(e, "camo")
	give(e, "decoy")
	check(not e.slot_visible(2), "button 3 needs growth too")
	e.player.mass = Ev.STAGES[3][0]
	check(e.slot_visible(2) and not e.slot_visible(3), "button 3 arrives at the Hunter stage")
	e.auto_assign()
	check(e.eligible(2).size() > 0 and e.slot_ids[2] != "", "button 3 takes either kind")
	e.player.mass = Ev.STAGES[4][0]
	e.auto_assign()
	check(e.slot_visible(3) and e.slot_ids[3] != "" and e.slot_ids[3] != e.slot_ids[2], "button 4 arrives at the Predator stage")
	var ids_used := {}
	for i in 4:
		check(not ids_used.has(e.slot_ids[i]), "no ability on two buttons")
		ids_used[e.slot_ids[i]] = true
	# --- Actives and the blue power bar
	_veteran(e, 70)
	check(not e.use_ability("burst"), "no boost before the trait")
	give(e, "burst")
	e.power = Data.POWER_MAX
	var c0: float = e.ability_cost("burst")
	check(e.use_slot(0) and absf(e.power - (Data.POWER_MAX - c0)) < 0.01 and e.dash_t > 0.0, "the button fires the boost and spends power")
	e.power = 1.0
	check(not e.use_slot(0), "can't boost without power")
	for i in 1800:
		e.npcs.clear()
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.power >= Data.POWER_MAX - 0.01, "the bar slowly refills")
	give(e, "burst", 3)
	check(e.ability_cost("burst") < c0 * 0.7 and e.ability_time("burst") > Data.ABILITIES.burst.time * 1.5, "more points: cheaper and longer")
	# spit slows what it hits
	give(e, "spit")
	e.npcs = [_npc(e.player.pos + Vector2(200, 0), 30.0, "coccus", "prey")]
	e.facing = Vector2.RIGHT
	e.power = 100.0
	check(e.use_ability("spit") and e.shots.size() == 1, "spit launches a shot")
	for i in 60:
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.npcs.size() > 0 and e.npcs[0].get("slow", 0.0) > 0.0, "the spit slows what it hits")
	# shock / spine stun nearby only
	give(e, "shock")
	e.npcs = [_npc(e.player.pos + Vector2(100, 0), 30.0, "coccus", "prey"), _npc(e.player.pos + Vector2(2000, 0), 30.0, "coccus", "prey")]
	e.power = 100.0
	check(e.use_ability("shock"), "shock fires")
	check(e.npcs[0].get("stun", 0.0) > 0.0 and e.npcs[1].get("stun", 0.0) == 0.0, "shock stuns only nearby creatures")
	# lure pulls prey in
	give(e, "lure")
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
	give(e, "camo")
	give(e, "ink")
	e.player.mass = 40.0
	e.player.hp = e.max_hp()
	e.camo_t = 0.0
	e.power = 100.0
	e.npcs = [_npc(e.player.pos + Vector2(300, 0), 100.0, "corona", "hunter")]
	check(e.use_ability("camo") and e.camo_t > 0.0, "camouflage fires")
	e.camo_t = 0.0
	e.power = 100.0
	e.npcs = [_npc(e.player.pos + Vector2(300, 0), 100.0, "corona", "hunter")]
	check(e.use_ability("ink") and e.ink_t > 0.0, "ink fires")
	for i in 30:
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.npcs[0].vel.length() < 20.0, "a hunter in the ink cloud does not chase")
	# poison skin makes the biter shrink
	_veteran(e, 8)
	e.player.mass = Ev.STAGES[3][0]
	give(e, "poison_skin")
	give(e, "spikes", 2)
	e.npcs = [_npc(e.player.pos, 400.0, "corona", "hunter")]
	var hm: float = e.npcs[0].mass
	e.player.hp = e.max_hp()
	for i in 20:
		e.step(0.1, Vector2.ZERO)
		if e.npcs.size() > 0:
			e.npcs[0].pos = e.player.pos
	check(e.npcs.size() > 0 and e.npcs[0].mass < hm, "poison skin: the biter shrinks")
	# harpoon venom: the target shrinks
	_veteran(e, 11)
	e.player.mass = Ev.STAGES[3][0]
	e.player.hp = 1000.0
	give(e, "harpoon")
	e.npcs = [_npc(e.player.pos + Vector2(300, 0), e.player.mass * 2.0, "corona", "hunter")]
	e.facing = Vector2.RIGHT
	e.power = 100.0
	var hm0: float = e.npcs[0].mass
	check(e.use_ability("harpoon"), "harpoon fires")
	for i in 150:
		e.step(1.0 / 60.0, Vector2.ZERO)
		e.player.hp = 1000.0
		if e.npcs.is_empty():
			break
	check(e.npcs.is_empty() or e.npcs[0].mass < hm0 * 0.85, "venom shrinks the target")
	# decoy draws the hunter off; limb stuns hunters and costs health
	_veteran(e, 12)
	e.player.mass = Ev.STAGES[3][0]
	give(e, "decoy")
	give(e, "limb")
	e.npcs = [_npc(e.player.pos + Vector2(400, 0), 300.0, "corona", "hunter")]
	e.facing = Vector2.LEFT
	e.power = 100.0
	check(e.use_ability("decoy") and e.decoy.t > 0.0, "decoy appears")
	e.decoy.pos = e.player.pos + Vector2(900, 0)
	e.decoy.vel = Vector2.ZERO
	for i in 20:
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.npcs[0].vel.x > 0.0, "the hunter goes for the decoy")
	e.power = 100.0
	var hp1: float = e.player.hp
	e.npcs = [_npc(e.player.pos + Vector2(200, 0), 300.0, "corona", "hunter")]
	check(e.use_ability("limb") and e.player.hp < hp1 and e.npcs[0].get("stun", 0.0) > 0.0, "limb: costs HP, stuns hunters")
	# shell, spikes and slime
	_veteran(e, 13)
	e.player.mass = Ev.STAGES[3][0]
	e.npcs = [_npc(e.player.pos, 400.0, "corona", "hunter")]
	var hp2: float = e.player.hp
	e.step(0.1, Vector2.ZERO)
	var plain: float = hp2 - e.player.hp
	_veteran(e, 13)
	e.player.mass = Ev.STAGES[3][0]
	give(e, "membrane", 3)
	give(e, "shell")
	give(e, "spikes", 2)
	give(e, "slime")
	e.npcs = [_npc(e.player.pos, 400.0, "corona", "hunter")]
	hp2 = e.player.hp
	e.step(0.1, Vector2.ZERO)
	check(hp2 - e.player.hp < plain * 0.5, "shell + spikes cut bites")
	check(e.npcs[0].get("slow", 0.0) > 0.0, "slime slows the biter")
	# tentacles: a second set of options
	_veteran(e, 14)
	e.dna = 99
	e.player.mass = Ev.STAGES[4][0]
	check(not e.reqs_met("suction"), "tentacle traits are locked at first")
	give(e, "burst")
	give(e, "spit")
	give(e, "jaws", 2)
	give(e, "lure")
	check(e.buy("tentacles"), "buy tentacles (needs jaws 2 and lure)")
	check(e.reqs_met("stinger") and e.reqs_met("suction") and not e.reqs_met("grab"), "tentacles open several options")
	check(e.buy("stinger") and e.buy("suction") and e.reqs_met("grab") and e.buy("grab"), "buy tentacle traits")
	e.npcs = [_npc(e.player.pos + Vector2(250, 0), 3.0, "coccus", "prey")]
	e.power = 100.0
	check(e.use_ability("suction"), "suction fires")
	var sd0: float = e.npcs[0].pos.distance_to(e.player.pos)
	for i in 30:
		e.step(1.0 / 60.0, Vector2.ZERO)
		if e.npcs.is_empty():
			break
	check(e.npcs.is_empty() or e.npcs[0].pos.distance_to(e.player.pos) < sd0 - 50.0, "suction pulls prey in")
	e.npcs = [_npc(e.player.pos + Vector2(200, 0), 3.0, "bacillus", "prey")]
	e.power = 100.0
	check(e.use_ability("grab") and e.npcs[0].get("held", 0.0) > 0.0, "grab holds a creature")
	e.npcs = [_npc(e.player.pos, 400.0, "corona", "hunter")]
	e.npcs[0]["stun"] = 5.0
	var sm: float = e.npcs[0].mass
	for i in 30:
		e.step(1.0 / 60.0, Vector2.ZERO)
		e.npcs[0].pos = e.player.pos
	check(e.npcs[0].mass < sm, "stinger hurts what touches you")
	# sonar
	_veteran(e, 15)
	give(e, "sonar")
	e.power = 100.0
	check(e.use_ability("sonar") and e.sonar_t > 0.0, "sonar pings")
	# fins add speed
	_veteran(e, 9)
	var sp0: float = e.top_speed()
	give(e, "tail")
	give(e, "fins", 2)
	check(e.top_speed() > sp0 * 1.3, "tail + fins are faster")
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
	# --- Endless world: no walls to the sides or down, population follows the player
	_veteran(e, 7)
	e.view_r = 300.0
	e.vision_r = 300.0
	var far := 0.0
	for s in 6:
		var d := Vector2.RIGHT.rotated(float(s) * 0.9 + 0.3)
		for i in 600:
			e.step(1.0 / 60.0, d)
			if not e.alive:
				e.player.hp = e.max_hp()
				e.alive = true
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
			check(e.player.pos.y >= 0.0, "never above the surface")
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
		if e.sight_rank >= 2:
			eyes += 1
		if e.peak_mass > Ev.TUNING.start_mass * 1.8:
			grow += 1
	print("greedy bot got its eye in %d/10 runs, grew in %d/10" % [eyes, grow])
	check(eyes >= 6, "greedy bot finishes the tutorial")
	check(grow >= 6, "greedy bot grows")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
