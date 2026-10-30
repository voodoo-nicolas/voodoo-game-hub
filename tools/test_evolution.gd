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
	e._story = 4
	e.tree_unlocked = true
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
	# Quick run of just the growth / species checks (the whole test takes ~10 minutes): ... --script res://tools/test_evolution.gd -- growth
	if OS.get_cmdline_user_args().has("growth"):
		_growth_and_species()
		print("FAILS: %d" % fails)
		quit(1 if fails else 0)
		return
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
	# Bigger is NOT slower: it moves faster in the world, so on screen (zoomed out) the speed holds.
	var screen_small: float = Ev.TUNING.player_speed * Ev.size_boost(10.0) * Ev.zoom_for(10.0)
	var screen_big: float = Ev.TUNING.player_speed * Ev.size_boost(500.0) * Ev.zoom_for(500.0)
	check(screen_big > screen_small * 0.7 and screen_big < screen_small * 1.4, "speed on screen holds as you grow (%d vs %d)" % [int(screen_small), int(screen_big)])
	check(Ev.size_boost(500.0) > Ev.size_boost(10.0), "bigger creatures move faster in the world")
	# Size levels and values
	check(Ev.size_level(1.0) == 1 and Ev.size_level(10.0) == 1 and Ev.size_level(Data.LEVELS[3]) == 4, "size levels")
	var lv := Ev.new()
	lv.reset(1)
	lv.player.mass = Data.LEVELS[3]    # size 4
	check(lv.level() == 4 and lv.value_of(1.0) == 0, "at size 4 the smallest dots are worth nothing")
	check(lv.visibility_of(1.0) == 0.35, "...and barely visible")
	lv.player.mass = Data.LEVELS[4]    # size 5
	check(lv.visibility_of(1.0) == 0.0, "at size 5 size-1 dots are invisible")
	check(lv.visibility_of(Data.LEVELS[1]) == 0.35 and lv.value_of(Data.LEVELS[1]) == 0, "...size 2 is tiny and worth nothing")
	check(lv.value_of(Data.LEVELS[2]) == 3 and lv.visibility_of(Data.LEVELS[2]) == 1.0, "size 3 is worth 3")
	lv.player.mass = 10.0
	check(lv.value_of(1.0) == 1 and lv.value_of(Data.LEVELS[1]) == 2, "the smallest dots are worth 1; a size-2 creature 2")
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
	for role in ["prey", "hunter"]:
		check(Data.species_by_role(role).size() > 0, "a species for role " + role)
	check(Data.MASS_RANGE.has("toxic") and Data.MASS_RANGE.has("rare"), "toxic and rare are sized relative to you")
	var tiers := {}
	for sp in Data.SPECIES:
		if sp.role == "prey" or sp.role == "hunter":
			check(float(sp.mass[0]) > 0.0 and float(sp.mass[1]) >= float(sp.mass[0]), "a mass range: " + sp.id)
		if not sp.has("trait") and sp.role != "toxic" and sp.role != "rare":
			tiers[int(sp.tier)] = int(tiers.get(int(sp.tier), 0)) + 1
		if int(sp.tier) == 1 and not sp.has("trait") and sp.role == "prey":
			check(float(sp.flee) == 0.0, "single cells never swim away: " + sp.id)
		if sp.role == "hunter":
			check(int(sp.tier) >= 3, "predators only from stage 3: " + sp.id)
	check(tiers.has(1) and tiers.has(2) and tiers.has(3) and tiers.has(4), "creatures at every stage")
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
	check(e.missions.size() > 0 and e.missions[0].kind == "value", "after the jolts, mission 2 appears")
	# --- Mission 2: eat a lot of small creatures for a tail (value, hidden numbers) ...
	check(e.missions.size() > 0 and e.missions[0].kind == "value" and e.missions[0].reward == "tail", "mission 2: eat to grow a tail")
	var rows: Array = e.mission_rows()
	check(rows.size() > 0 and rows[0].has("frac") and not rows[0].has("reward") and not rows[0].has("target"), "the list shows a bar, no counts and no rewards")
	var worth0: int = e.eaten_value
	var meals := 0
	while e.move_rank == 0 and meals < 60:
		e.npcs = [_npc(e.player.pos, 2.5, "coccus", "prey")]
		e.step(1.0 / 60.0, Vector2.ZERO)
		meals += 1
	check(e.move_rank == 1 and meals >= 3, "a lot of creatures eaten grows a tail (after %d more meals)" % meals)
	check(e.eaten_value >= int(Ev.TUNING.tail_value), "...about %d worth" % int(Ev.TUNING.tail_value))
	check(e.level() == 1, "...and you are still size 1")
	check(e.tree_unlocked == false and e.missions.size() > 0, "the tree is not open yet")
	e.npcs.clear()
	e.food.clear()
	for i in 90:
		e.step(1.0 / 60.0, Vector2.RIGHT)
	check(e.player.vel.length() > Ev.TUNING.jolt_speed * 0.9, "tail swims faster than a jolt")
	# --- ... or eat a creature that has the trait: the faster way
	var fx := Ev.new()
	fx.reset(2)
	fx.npcs = [_npc(fx.player.pos, 3.0, "tailed", "prey")]
	fx.step(1.0 / 60.0, Vector2.ZERO)
	check(fx.move_rank == 1, "eating a creature with a tail gives you a tail at once")
	var got_tail := false
	for ev in fx.events:
		if ev.type == "tail":
			got_tail = true
	check(got_tail, "tail event (the game pops up a message)")
	check(fx.missions.size() > 0 and fx.missions[-1].reward == "eye" and not fx.missions[-1].done, "next: the eye")
	fx.npcs = [_npc(fx.player.pos, 3.0, "eyed", "prey")]
	fx.step(1.0 / 60.0, Vector2.ZERO)
	check(fx.sight_rank == 2 and fx.has_bars() and fx.hunters_on(), "eating a creature with an eye gives you an eye")
	check(not fx.tree_unlocked, "tail and eye do not open the tree yet")
	check(fx.level() == 1, "tail and eye come while you are still size 1")
	check(fx.missions[-1].kind == "mass" and fx.missions[-1].reward == "tree", "next: grow to size 2 for the tree")
	# owner 2026-10-24: eat eat eat to size 2, which opens the tree
	var meals2 := 0
	while fx.level() < 2 and meals2 < 800:
		fx.npcs = [_npc(fx.player.pos, 3.0, "bacillus", "prey")]
		fx.step(1.0 / 60.0, Vector2.ZERO)
		meals2 += 1
		if fx.level() < 2:
			check(not fx.tree_unlocked, "still size 1: the tree stays closed")
	check(meals2 >= 400, "size 2 takes a good while of eating (%d meals)" % meals2)
	check(fx.tree_unlocked, "size 2 opens the evolution tree")
	check(fx.dna == Data.TREE_DNA, "...with its 2 DNA, nothing more (%d)" % fx.dna)
	fx.dna = 5
	check(fx.buy("burst") == false or fx.node_state("burst") != "locked", "the tree can be used now")
	var tree_event := false
	for ev in fx.events:
		if ev.type == "tree":
			tree_event = true
	check(tree_event, "tree event (the game pops up a message)")
	var gk := {}
	for m in fx.missions:
		gk[m.kind] = true
	check(gk.has("mass"), "an eat-and-grow mission is always on the list")
	# Before the tree is open nothing can be bought
	var g := Ev.new()
	g.reset(3)
	g.dna = 9
	check(not g.buy("tail") and not g.can_buy("burst"), "no buying before the tree is unlocked")
	# Missions are found, not handed out
	fx.npcs = [_npc(fx.player.pos + Vector2(100, 0), 2.0, "zika", "equal")]
	fx.step(1.0 / 60.0, Vector2.ZERO)
	var found_new := false
	for ev in fx.events:
		if ev.type == "seen":
			found_new = true
	check(found_new, "meeting a new species is an event")
	check(fx.seen.has("zika"), "...recorded")
	# rewards alternate size / DNA, hidden from the list
	var rw := {}
	for m in fx.missions:
		if not m.done:
			rw[m.reward] = true
	check(rw.has("") and not rw.has("size"), "growing pays nothing (owner 2026-10-29); discoveries pay DNA")
	# zero-value things are left alone
	var z := Ev.new()
	z.reset(4)
	z.player.mass = Data.LEVELS[3]
	z.npcs.clear()
	z.food = [z.player.pos]
	z.step(1.0 / 60.0, Vector2.ZERO)
	check(z.eaten_food == 1, "food specks are still eaten at size 4 (owner 2026-10-24: small particles always)")
	check(z.level() == 4, "...and never shrink you (no eye yet, but already big)")
	z.npcs = [_npc(z.player.pos, 1.5, "coccus", "prey")]
	z.step(1.0 / 60.0, Vector2.ZERO)
	check(z.eaten_cells == 0, "a tiny creature worth nothing is not eaten either")
	# Creatures of different species are hostile; the same species is not
	var h := Ev.new()
	h.reset(5)
	h.sight_rank = 2
	h.move_rank = 1
	var base: Vector2 = h.player.pos
	h.npcs = [_npc(base + Vector2(500, 0), 40.0, "zika", "equal"), _npc(base + Vector2(525, 0), 6.0, "coccus", "prey")]
	for i in 600:
		h.step(1.0 / 60.0, Vector2(0, 0))
		h.player.pos = base
		h.npcs = h.npcs.filter(func(n): return n.id == 999)
		if h.npcs.size() < 2:
			break
	check(h.npcs.size() == 1 and h.npcs[0].species == "zika" and h.npcs[0].mass > 40.0, "a bigger creature eats a smaller one of another species")
	h.reset(5)
	h.sight_rank = 2
	base = h.player.pos
	h.npcs = [_npc(base + Vector2(500, 0), 40.0, "coccus", "prey"), _npc(base + Vector2(520, 0), 6.0, "coccus", "prey")]
	for i in 300:
		h.step(1.0 / 60.0, Vector2(0, 0))
		h.player.pos = base
		h.npcs = h.npcs.filter(func(n): return n.id == 999)
	check(h.npcs.size() == 2, "the same species does not eat each other")
	# Spread out: creatures are not clumped
	var near := 0
	var pairs := 0
	for sd in 8:
		h.reset(60 + sd)
		for i in h.npcs.size():
			for j in range(i + 1, h.npcs.size()):
				pairs += 1
				if h.npcs[i].pos.distance_to(h.npcs[j].pos) < 100.0:
					near += 1
	check(float(near) / float(maxi(pairs, 1)) < 0.03, "creatures are spread out (%d of %d pairs close)" % [near, pairs])
	# --- Stages: what spawns when, and where
	var sg := Ev.new()
	for sd in 12:
		sg.reset(300 + sd)
		for n in sg.npcs:
			var spd: Dictionary = Data.species_of(n.species)
			check(int(spd.tier) == 1, "stage 1 holds only single cells (got %s)" % n.species)
			check(not n.flees, "single cells do not swim away")
	var stage2 := {}
	for sd in 30:
		sg.reset(400 + sd)
		sg.sight_rank = 2
		sg.player.mass = Data.LEVELS[1] + 1.0       # size 2
		sg.npcs.clear()
		for i in 30:
			sg._top_up()
		for n in sg.npcs:
			stage2[n.species] = true
			check(n.role != "hunter", "no predators before stage 3")
			check(int(Data.species_of(n.species).tier) <= 2, "stage 2 has chains, not viruses (got %s)" % n.species)
	check(stage2.has("strepto"), "stage 2 brings chain bacteria")
	var seen3 := {}
	var fleeing := 0
	var total3 := 0
	for sd in 30:
		sg.reset(500 + sd)
		sg.sight_rank = 2
		sg.move_rank = 1
		sg.player.mass = Data.LEVELS[2] + 1.0       # size 3
		sg.npcs.clear()
		for i in 60:
			sg._top_up()
		for n in sg.npcs:
			seen3[n.species] = true
			total3 += 1
			if n.flees:
				fleeing += 1
			var spd2: Dictionary = Data.species_of(n.species)
			if spd2.role != "toxic" and spd2.role != "rare":
				check(n.mass >= float(spd2.mass[0]) - 0.001 and n.mass <= float(spd2.mass[1]) + 0.001, "creatures keep their own size, not yours (%s %f)" % [n.species, n.mass])
	check(seen3.has("herpes") and seen3.has("corona"), "stage 3 brings viruses and predators")
	check(fleeing > 0 and float(fleeing) / float(maxi(total3, 1)) > 0.3, "many stage-3 creatures swim away")
	# Hunters never spawn close to you; at most LEVEL_CAP of one size around you
	var safe_ok := true
	var cap_ok := true
	for sd in 20:
		sg.reset(600 + sd)
		sg.sight_rank = 2
		sg.player.mass = Data.LEVELS[3] + 1.0       # size 4
		sg.npcs.clear()
		var known := {}
		for i in 400:
			sg._top_up()
			var counts := {}
			for n in sg.npcs:
				var lvn := Ev.size_level(n.mass)
				counts[lvn] = int(counts.get(lvn, 0)) + 1
				if not known.has(n.id):
					known[n.id] = true
					if n.role == "hunter" and n.pos.distance_to(sg.player.pos) < Ev.TUNING.hunter_safe - 1.0:
						safe_ok = false
			for k in counts:
				if counts[k] > Data.LEVEL_CAP + 1:
					cap_ok = false
			if i % 7 == 0 and sg.npcs.size() > 0:
				sg.npcs.remove_at(0)
	check(safe_ok, "no hunter spawns within the safe distance of you")
	check(cap_ok, "no more than LEVEL_CAP creatures of one size around you")
	# As you grow, the enemies shrink: the same species stays the same size
	var mass_small := 0.0
	var mass_big := 0.0
	for k in 2:
		sg.reset(700)
		sg.sight_rank = 2
		sg.player.mass = 10.0 if k == 0 else 600.0
		sg.npcs.clear()
		for i in 80:
			sg._top_up()
		var hs := 0.0
		var hc := 0
		for n in sg.npcs:
			if n.species == "corona":
				hs += n.mass
				hc += 1
		if k == 0:
			mass_small = hs / maxf(float(hc), 1.0)
		else:
			mass_big = hs / maxf(float(hc), 1.0)
	check(absf(mass_small - mass_big) < 40.0 or mass_small == 0.0 or mass_big == 0.0, "a given predator does not grow with you")
	# --- Events behind the badges
	var bdg := Ev.new()
	_veteran(bdg, 80)
	give(bdg, "tail", 2)
	for i in 60:
		bdg.step(1.0 / 60.0, Vector2.RIGHT)
	check(bdg.distance > 100.0, "swimming adds up distance (%d)" % int(bdg.distance))
	bdg.player.hp = 0.5
	bdg.step(0.01, Vector2.ZERO)
	bdg.player.hp = bdg.max_hp()
	bdg.step(0.01, Vector2.ZERO)
	var got_cb := false
	for ev in bdg.events:
		if ev.type == "comeback":
			got_cb = true
	check(got_cb, "below 10% health then back to full = a comeback")
	_veteran(bdg, 81)
	give(bdg, "shock")
	bdg.npcs.clear()
	for i in 6:
		bdg.npcs.append(_npc(bdg.player.pos + Vector2(60 + 20 * i, 0), 30.0, "coccus", "prey"))
	bdg.power = 100.0
	check(bdg.use_ability("shock") and bdg.max_stunned >= 6, "one shock can stun many (%d)" % bdg.max_stunned)
	var got_stun := false
	for ev in bdg.events:
		if ev.type == "stun_count" and ev.count >= 6:
			got_stun = true
	check(got_stun, "stun_count event")
	_veteran(bdg, 82)
	give(bdg, "ink")
	bdg.player.mass = Ev.STAGES[3][0]
	bdg.player.hp = 1000.0
	bdg.npcs = [_npc(bdg.player.pos + Vector2(300, 0), 300.0, "corona", "hunter")]
	for i in 300:
		bdg.step(1.0 / 60.0, Vector2.ZERO)
		bdg.npcs[0].pos = bdg.player.pos + Vector2(300, 0)
		bdg.player.hp = 1000.0
	check(bdg.npcs[0].get("chase_t", 0.0) > 4.0, "a hunter has been chasing you")
	bdg.ink_t = 5.0
	bdg.ink_pos = bdg.npcs[0].pos
	var got_evade := false
	for i in 5:
		bdg.step(1.0 / 60.0, Vector2.ZERO)
		for ev in bdg.events:
			if ev.type == "evaded":
				got_evade = true
	check(got_evade, "losing a chasing hunter counts as evading it")
	_veteran(bdg, 83)
	bdg.player.mass = 40.0
	var old_chaser := _npc(bdg.player.pos, 20.0, "corona", "hunter")
	old_chaser["chased_lvl"] = 1
	bdg.npcs = [old_chaser]
	bdg.step(1.0 / 60.0, Vector2.ZERO)
	var got_rev := false
	for ev in bdg.events:
		if ev.type == "revenge":
			got_rev = true
	check(got_rev, "eating what once chased you, after growing = revenge")
	_veteran(bdg, 84)
	check(bdg.speed_pct() < 100, "a fresh body is not at top speed")
	give(bdg, "tail", 2)
	give(bdg, "fins", 2)
	give(bdg, "flagella")
	give(bdg, "cilia")
	give(bdg, "streamlined")
	check(bdg.speed_pct() == 100, "the best body reaches 100%% speed (%d)" % bdg.speed_pct())
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
	var m1: float = e.xp
	e.food = [e.player.pos]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(absf((e.xp - m1) - Ev.TUNING.food_xp * 0.5) < 0.01, "bottomless appetite: half growth")
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
	e.npcs = [_npc(e.player.pos, 40.0, "coccus", "prey")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(absf(e.player.hp - 5.0) < 0.4, "defense: 2 points = +2 HP per meal (hp %f)" % e.player.hp)
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
	e.npcs = [_npc(e.player.pos + Vector2(220, 0), 100.0, "corona", "hunter")]
	check(e.use_ability("ink") and e.ink_t > 0.0, "ink fires")
	for i in 30:
		e.step(1.0 / 60.0, Vector2.ZERO)
	check(not e.npcs[0].get("hunting", false), "a hunter in the ink cloud does not chase")
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
	# --- Each toxic kind always gives the same ailment; repeats build a free resistance (10, 30, 50, 70, 90)
	var tox_ail := {}
	for sp in Data.SPECIES:
		if sp.role == "toxic":
			check(Data.AILMENTS.has(str(sp.get("ailment", ""))), "toxic %s has a fixed ailment" % sp.id)
			tox_ail[sp.ailment] = true
	check(tox_ail.size() == Data.AILMENT_ORDER.size(), "every ailment has its own toxic creature")
	for sp in Data.SPECIES:
		if sp.role != "toxic":
			continue
		for k in 3:
			_veteran(e, 60 + k)
			e.npcs = [_npc(e.player.pos, 4.0, sp.id, "toxic")]
			e.step(1.0 / 60.0, Vector2.ZERO)
			check(e.ailments.size() == 1 and e.ailments.has(sp.ailment), "%s always gives %s" % [sp.id, sp.ailment])
			check(float(e.ail_full.get(sp.ailment, 0.0)) >= float(e.ailments.get(sp.ailment, 1.0)), "the timer knows its full length")
	_veteran(e, 70)
	var got_resist := []
	var full0 := 0.0
	for i in 95:
		e.ailments = {}
		e.npcs = [_npc(e.player.pos, 4.0, "toxin", "toxic")]
		e.step(1.0 / 60.0, Vector2.ZERO)
		e.player.hp = e.max_hp()
		for ev in e.events:
			if ev.type == "resist":
				got_resist.append([i + 1, ev.rank])
		if i == 0:
			full0 = e.ail_full.get("brittle", 0.0)
		if i == 9:
			check(e.resist_rank("brittle") == 1 and e.ail_full.get("brittle", 99.0) < full0 * 0.85, "10 times brittle = Hard cells 1/5, shorter")
	check(got_resist == [[10, 1], [30, 2], [50, 3], [70, 4], [90, 5]], "resistance ranks at 10/30/50/70/90 (%s)" % str(got_resist))
	check(e.ailments.is_empty(), "5/5 = immune")
	check(e.resist_rank("glow") == 0, "resistance is per ailment")
	# --- Only a few hunters chase you at once, and only so many are around
	_veteran(e, 71)
	e.player.mass = 40.0
	for i in 9:
		var hn := _npc(e.player.pos + Vector2.RIGHT.rotated(float(i) * 0.7) * 260.0, 100.0, "corona", "hunter")
		hn.id = 2000 + i
		e.npcs.append(hn)
	for i in 3:
		e.step(1.0 / 60.0, Vector2.ZERO)
	var chasing := 0
	for n in e.npcs:
		if n.get("hunting", false):
			chasing += 1
	check(chasing >= 1 and chasing <= int(Data.DIFFICULTY.normal.chasers), "at most %d chase you (%d did)" % [Data.DIFFICULTY.normal.chasers, chasing])
	for i in 400:
		e.player.hp = e.max_hp()
		e.step(1.0 / 60.0, Vector2.ZERO)
	var threats := 0
	for n in e.npcs:
		if n.role == "hunter" and Ev.can_eat(n.mass, e.player.mass) and int(n.id) < 2000:
			threats += 1
	check(threats == 0, "no new hunters spawn while too many are around")
	# --- The surface: pushing up along it keeps your speed (no catching)
	_veteran(e, 72)
	e.player.pos = Vector2(0.0, 5.0)
	for i in 120:
		e.npcs.clear()
		e.step(1.0 / 60.0, Vector2(1, -1).normalized())
	check(e.player.vel.x > e.top_speed() * 0.9, "sliding along the surface at full speed (%d of %d)" % [int(e.player.vel.x), int(e.top_speed())])
	# --- Water: colder with depth; too deep / too cold hurts; traits move the limits
	check(Ev.temp_at(Vector2(3000.0, 10.0)) > Ev.temp_at(Vector2(3000.0, 3000.0)) and Ev.temp_at(Vector2(0, 1.0e6)) >= -1.0, "colder with depth, never ice")
	_veteran(e, 73)
	e.player.pos = Vector2(4500.0, 500.0)      # warm, shallow
	e.player.hp = 5.0
	e.hit_t = 99.0
	e.step(1.0, Vector2.ZERO)
	check(e.too_cold == 0.0 and e.too_deep == 0.0 and e.player.hp > 5.0, "shallow water is fine")
	e.player.pos = Vector2(4500.0, (e.max_depth_m() + 150.0) * Ev.TUNING.units_per_m)
	e.player.hp = e.max_hp()
	e.step(1.0, Vector2.ZERO)
	check(e.too_deep > 0.0 and e.player.hp < e.max_hp(), "too deep hurts")
	var lim0: float = e.max_depth_m()
	give(e, "pressure_tol", 3)
	check(e.max_depth_m() > lim0 + 300.0, "pressure cells let you dive deeper")
	var cold0: float = e.min_temp()
	give(e, "cold_tol", 2)
	check(e.min_temp() < cold0 - 4.0, "antifreeze: colder water")
	_veteran(e, 74)
	e.player.pos = Vector2(4500.0, 100000.0)
	for i in 600:
		e.npcs.clear()
		e.player.pos = Vector2(4500.0, 100000.0)
		e.step(0.1, Vector2.ZERO)
		if not e.alive:
			break
	check(not e.alive and (e.death_cause == "deep" or e.death_cause == "cold"), "the deep can kill (%s)" % e.death_cause)
	_veteran(e, 75)
	e.sight_rank = 1
	e.player.pos = Vector2(4500.0, 100000.0)
	e.step(1.0, Vector2.ZERO)
	check(e.too_deep == 0.0, "no depth limit before the eye opens")
	# --- Rare creatures are always worth eating; tree nodes waiting on growth are readable
	_veteran(e, 76)
	e.player.mass = Data.LEVELS[5]
	e.npcs = [_npc(e.player.pos, e.player.mass * 0.15, "gold", "rare")]
	e.step(1.0 / 60.0, Vector2.ZERO)
	check(e.npcs.is_empty() or e.npcs[0].species != "gold", "a tiny rare creature can still be eaten")
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
		for i in 10800:
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
				elif (n.species == "tailed" or n.species == "eyed") and dn < 900.0:
					bd = 0.0
					best = (n.pos - e.player.pos).normalized()
				elif n.role == "prey" and dn < minf(bd * 3.0, 700.0) and Ev.can_eat(e.player.mass, n.mass):
					bd = dn / 3.0
					best = (n.pos - e.player.pos).normalized()
			e.step(1.0 / 60.0, best)
			if not e.alive:
				break
		if e.sight_rank >= 2:
			eyes += 1
		if e.xp > 60.0:    # size 1 now lasts ~10 min, so the mass barely moves
			grow += 1
	print("greedy bot got its eye in %d/10 runs, grew in %d/10" % [eyes, grow])
	check(eyes >= 6, "greedy bot finishes the tutorial")
	check(grow >= 6, "greedy bot grows")
	# Threats pile up slowly: never more creatures that can eat you than the cap for your size
	var worst := 0
	var cap_seen := 0
	e.reset(901)
	e.view_r = 400.0
	e.vision_r = 400.0
	e.sight_rank = 2
	e.player.mass = 40.0
	for i in 4000:
		e.player.hp = e.max_hp()
		e.step(1.0 / 60.0, Vector2.ZERO)
		var thr_now := 0
		for n in e.npcs:
			if n.role == "hunter" and Ev.can_eat(n.mass, e.player.mass):
				thr_now += 1
		worst = maxi(worst, thr_now)
		cap_seen = e.threat_cap()
	print("most hunters at once at size %d: %d (cap %d)" % [e.level(), worst, cap_seen])
	check(cap_seen == 1 and worst <= 1, "one hunter at the first predator size")
	e.player.mass = 300.0
	check(e.threat_cap() == mini(e.level() - 2, int(Data.DIFFICULTY.normal.hunter_max)), "the hunter cap grows one per size")
	# Endless mode: dying brings you back at the start of your size, keeping what you evolved
	e.reset(902)
	e.sight_rank = 2
	e.player.mass = 100.0
	e.owned["jaws"] = 1
	e.dna = 3
	e.player.pos = Vector2(500.0, 4000.0)
	e.player.hp = 0.0
	e.alive = false
	e.death_cause = "cold"
	e.revive()
	check(e.alive and e.death_cause == "", "revive: alive again")
	check(is_equal_approx(e.player.mass, 62.0), "revive: back to the start of the size (level 4 starts at 62)")
	check(is_equal_approx(e.player.hp, e.max_hp()), "revive: full health")
	check(e.player.pos.y <= Ev.TUNING.start_depth, "revive: out of the deep water")
	check(e.owned.get("jaws", 0) == 1 and e.dna == 3 and e.sight_rank == 2, "revive: keeps traits, DNA and the eye")
	check(e.grace > 0.0 and e.deaths == 1, "revive: a moment of grace, counted")
	_growth_and_species()
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)

## Owner 2026-10-23: slow growing, fast mutations (DNA per size), animals instead of cells, a depth scale you
## can feel. Owner 2026-10-24: size 2 -> 3 costs X, then every size 50% more than the last; size N of 10 =
## N/10 of the tree's DNA; tail and eye at size 1, the tree at size 2; bacteria 1-3, fish 3-6, all sorts 5-10,
## sea monsters 9-10; more rare creatures.
func _growth_and_species() -> void:
	# xp (owner 2026-10-29): each size costs Data.XP_KILLS kills of prey one size below (worth size - 1, at size 1
	# worth 1); 19,500 kills to size 10; mass follows xp through the size starts
	var kills := 0
	for lv in range(1, 10):
		kills += int(Data.XP_KILLS[lv - 1])
		check(is_equal_approx(Ev.xp_span(lv), float(Data.XP_KILLS[lv - 1]) * float(maxi(lv - 1, 1))), "size %d to %d = %d kills of prey worth %d" % [lv, lv + 1, Data.XP_KILLS[lv - 1], maxi(lv - 1, 1)])
		check(Ev.xp_span(lv + 1) > Ev.xp_span(lv), "size %d costs more than size %d" % [lv + 1, lv])
	check(kills == 19500, "19,500 kills to size 10 (%d)" % kills)
	check(is_equal_approx(Ev.xp_at(10), 117800.0), "117,800 xp to size 10 (%d)" % int(Ev.xp_at(10)))
	check(Ev.xp_span(1) > float(Ev.TUNING.eye_value), "size 1 lasts past the eye")
	var blind := Ev.new()
	blind.reset(9)
	blind._gain_xp(500.0)
	check(blind.level() == 1, "no eye yet: you stay size 1")
	# Growth branch (owner 2026-10-29): size 3 and up must be bought
	var cp := Ev.new()
	cp.reset(10)
	cp.sight_rank = 2
	cp.tree_unlocked = true
	cp._gain_xp(Ev.xp_at(2) + 0.1)
	check(cp.level() == 2 and cp.size_cap() == 2, "size 2 is free, the cap is 2")
	var dbar0: float = cp.dna_bar
	cp._gain_xp(100000.0)
	check(cp.level() == 2 and cp.xp < Ev.xp_at(3), "no Growth: eating cannot take you to size 3")
	check(cp.dna_bar != dbar0 or cp.dna > 0, "...but the DNA bar still fills")
	cp.dna = 6
	check(cp.buy("growth") and cp.size_cap() == 3, "Growth rank 1 costs 6 and lifts the cap to 3")
	cp._gain_xp(100000.0)
	check(cp.level() == 3, "...now you reach size 3 and stop there (%d)" % cp.level())
	check(cp.cost_of("growth") == 7, "the next Growth rank costs 7")
	# ability loadout picker
	var ld := Ev.new()
	ld.reset(11)
	ld.tree_unlocked = true
	ld.owned["burst"] = 1
	ld.owned["spit"] = 1
	ld.owned["ink"] = 1
	ld._recompute_ranks()
	ld.auto_assign()
	check(ld.slot_ids[0] in ["burst", "spit"] and ld.slot_ids[1] == "ink", "loadout: buttons filled")
	ld.assign_slot(0, "spit")
	check(ld.slot_ids[0] == "spit", "loadout: picked Acid spit for the offense button")
	ld.assign_slot(0, "ink")
	check(ld.slot_ids[0] == "spit", "loadout: a defensive ability cannot go on the offense button")
	check(is_equal_approx(Ev.mass_of_xp(0.0), Ev.TUNING.start_mass), "xp 0 = the start mass")
	for lv in range(2, 11):
		check(is_equal_approx(Ev.mass_of_xp(Ev.xp_at(lv)), Data.LEVELS[lv - 1]), "reaching size %d puts you at its start mass" % lv)
		check(is_equal_approx(Ev.xp_of_mass(Data.LEVELS[lv - 1]), Ev.xp_at(lv)), "mass -> xp -> mass round trip at size %d" % lv)
	check(Ev.size_level(Ev.mass_of_xp(Ev.xp_at(5) - 0.01)) == 4 and Ev.size_level(Ev.mass_of_xp(Ev.xp_at(5))) == 5, "the size changes exactly at its xp")
	var g := Ev.new()
	g.reset(1234)
	g.sight_rank = 2
	g.npcs.clear()
	g.food.clear()
	var x0: float = g.xp
	g.npcs = [_npc(g.player.pos, 3.0, "coccus", "prey")]
	g.step(1.0 / 60.0, Vector2.ZERO)
	check(is_equal_approx(g.xp - x0, 1.0), "a size-1 creature is worth 1 xp")
	check(is_equal_approx(g.player.mass, Ev.mass_of_xp(g.xp)), "mass follows xp")
	# mutations (owner 2026-10-29): no DNA lump for a new size; the 🧬 bar pays 1 point at a time as you eat
	var tree := 0
	for n in Data.NODES:
		for k in int(n.max):
			tree += int(n.cost) + k
	var by10 := 0
	for v in Data.DNA_PER_SIZE:
		by10 += int(v)
	check(by10 == 196, "196 DNA from eating by size 10 (%d)" % by10)
	check(Data.TREE_DNA + by10 < tree, "growing alone never buys the whole tree (%d of %d)" % [Data.TREE_DNA + by10, tree])
	var d := Ev.new()
	d.reset(77)
	d.sight_rank = 2
	d.npcs.clear()
	d.food.clear()
	d._gain_xp(Ev.xp_at(4) - d.xp)
	d.step(1.0 / 60.0, Vector2.ZERO)
	check(d.level() == 4 and d.dna == 0, "growing to size 4 pays no DNA lump (%d)" % d.dna)
	var lvl_events := 0
	for ev in d.events:
		if ev.type == "level":
			lvl_events += 1
	check(lvl_events == 3, "...one banner event per size (%d)" % lvl_events)
	# each size's kills pay about its DNA_PER_SIZE, one point at a time, and never more than 1 per meal
	for lv in range(2, 10):
		var b := Ev.new()
		b.reset(900 + lv)
		b.sight_rank = 2
		b.tree_unlocked = true
		b.owned["growth"] = 8      # Growth lifts the size cap (owner 2026-10-29)
		b.npcs.clear()
		b.food.clear()
		b._gain_xp(Ev.xp_at(lv) - b.xp, false)
		check(b.level() == lv and b.dna == 0, "size %d reached without DNA" % lv)
		var worth := float(maxi(lv - 1, 1))
		var most := 0
		for k in int(Data.XP_KILLS[lv - 1]):
			var d0: int = b.dna
			b._gain_xp(worth)
			most = maxi(most, b.dna - d0)
		check(absi(b.dna - int(Data.DNA_PER_SIZE[lv - 1])) <= 1, "size %d -> %d pays %d DNA from eating (%d)" % [lv, lv + 1, Data.DNA_PER_SIZE[lv - 1], b.dna])
		check(most <= 1, "size %d: never more than 1 DNA per meal" % lv)
	var big := Ev.new()
	big.reset(31)
	big.sight_rank = 2
	big.tree_unlocked = true
	big._gain_xp(Ev.xp_at(2) - big.xp, false)
	big._gain_xp(5000.0)
	check(big.dna == 1, "one huge meal still pays 1 DNA (%d)" % big.dna)
	var gift := Ev.new()
	gift.reset(32)
	gift.sight_rank = 2
	gift.tree_unlocked = true
	gift._gain_xp(Ev.xp_at(3) - gift.xp, false)
	gift._gain_xp(Ev.xp_span(3) * Ev.TUNING.story_xp, false)
	check(gift.dna == 0, "a mission's xp gift pays no DNA")
	var shut := Ev.new()
	shut.reset(33)
	shut.sight_rank = 2
	shut._gain_xp(Ev.xp_at(3) - shut.xp)
	check(shut.dna == 0 and shut.dna_frac() == 0.0, "no DNA bar before the tree is open")
	# the creatures around you, by your size
	var cells := ["beads", "rod", "blob", "chain", "spiral", "tailed", "eyed"]
	var viruses := ["spiky", "bumpy", "corona", "worm", "phage"]
	var animals := ["fish", "jelly", "squid", "ray", "snake", "octopus", "turtle", "star", "seahorse", "mermaid", "poseidon"]
	var monsters := ["leviathan", "kraken", "serpent", "maw", "wyrm", "titanturtle"]
	for lv in range(1, 11):
		var p := Ev.new()
		p.reset(500 + lv)
		p.sight_rank = 2
		p.move_rank = 1
		p.player.mass = Data.LEVELS[lv - 1] + 1.0
		p._mass_seen = -1.0
		p._sync_mass()
		var seen := {}
		var picks := 0
		var animal_picks := 0
		var fish_picks := 0
		var monster_picks := 0
		for i in 600:
			p.npcs.clear()
			p._hunter_cd = 0.0
			var sp: Dictionary = p._pick_species()
			if sp.is_empty():
				continue
			seen[sp.id] = sp
			picks += 1
			# toxic and rare creatures are sized relative to you: from size 5 they are always size 3+, so animals
			var shape: String = sp.shape
			if sp.has("adv") and lv >= 5:
				shape = sp.adv.shape
			if animals.has(shape):
				animal_picks += 1
			if shape == "fish":
				fish_picks += 1
			if monsters.has(sp.id):
				monster_picks += 1
				check(lv >= 9, "sea monsters only at sizes 9-10 (%s at size %d)" % [sp.id, lv])
			if lv >= 4 and not sp.has("adv"):
				check(not cells.has(shape) and not viruses.has(shape), "size %d meets no bacteria or viruses (%s)" % [lv, sp.id])
			if lv >= 5:
				check(not cells.has(shape) and not viruses.has(shape), "size %d meets no cells or viruses (%s)" % [lv, sp.id])
		check(picks > 0, "size %d meets someone" % lv)
		print("size %d: %d%% of what you meet are animals" % [lv, int(100.0 * animal_picks / maxf(picks, 1))])
		if lv >= 7:
			check(animal_picks == picks, "from size 7 everyone is an animal (%d of %d)" % [animal_picks, picks])
		if lv >= 5:
			check(animal_picks == picks, "from size 5 everyone is an animal (%d of %d)" % [animal_picks, picks])
		if lv == 4:
			check(animal_picks * 2 >= picks, "at size 4 most are animals (%d of %d)" % [animal_picks, picks])
		if lv >= 4 and lv <= 6:
			check(fish_picks * 2 >= picks, "sizes 4-6 are mostly fish (%d of %d at size %d)" % [fish_picks, picks, lv])
		if lv >= 9:
			check(monster_picks * 5 >= picks, "sizes 9-10 bring sea monsters (%d of %d at size %d)" % [monster_picks, picks, lv])
	for sp in Data.SPECIES:
		if sp.role == "toxic" or (sp.role == "rare" and int(sp.tier) < 3):
			check(sp.has("adv") and sp.adv.name != "" and animals.has(sp.adv.shape), "%s turns into an animal when big" % sp.id)
		elif sp.role == "rare":
			check(animals.has(sp.shape), "%s is an animal" % sp.id)
	# rare creatures: a whole family, the bigger you are the more kinds, the rarest the rarest
	var rare_seen := {}
	var rr := Ev.new()
	rr.reset(41)
	rr.sight_rank = 2
	for lv in [1, 3, 5, 7, 10]:
		rr.player.mass = Data.LEVELS[lv - 1] + 1.0
		rr._mass_seen = -1.0
		rr._sync_mass()
		for i in 4000:
			var sp: Dictionary = rr._pick_rare(rr.level())
			check(int(sp.tier) <= lv, "a %s only from size %d (at %d)" % [sp.id, int(sp.tier), lv])
			rare_seen[sp.id] = int(rare_seen.get(sp.id, 0)) + 1
	for id in ["gold", "starfish", "seahorse", "mermaid", "poseidon"]:
		check(rare_seen.has(id), "rare %s turns up" % id)
	check(int(rare_seen.get("poseidon", 0)) < int(rare_seen.get("mermaid", 0)) and int(rare_seen.get("mermaid", 0)) < int(rare_seen.get("starfish", 0)), "little Poseidon is the rarest")
	var rd := Ev.new()
	_veteran(rd, 43)
	rd.player.mass = Data.LEVELS[6] + 1.0
	rd._mass_seen = -1.0
	rd._sync_mass()
	var dna0: int = rd.dna
	rd.npcs = [_npc(rd.player.pos, rd.player.mass * 0.4, "poseidon", "rare")]
	rd.step(1.0 / 60.0, Vector2.ZERO)
	check(rd.dna >= dna0 + 8,"little Poseidon pays 8 DNA on top of its trait (%d -> %d)" % [dna0, rd.dna])
	check(rd._counter("rare", "") >= 1.0, "every rare kind counts as a rare catch")
	# food specks stay at every size
	var fd := Ev.new()
	_veteran(fd, 44)
	fd.player.mass = Data.LEVELS[7] + 1.0
	fd._mass_seen = -1.0
	fd._sync_mass()
	fd.food = [fd.player.pos]
	var ef: int = fd.eaten_food
	fd.step(1.0 / 60.0, Vector2.ZERO)
	check(fd.eaten_food == ef + 1, "a size 8 creature still eats the food specks")
	# depth is on a scale you can feel
	var w := Ev.new()
	w.reset(3)
	w.player.pos = Vector2(0.0, 60.0 * Ev.TUNING.units_per_m)
	check(is_equal_approx(w.depth_m(), 60.0), "60 m is 60 x units_per_m")
	check(Ev.TUNING.units_per_m * w.max_depth_m() > 8000.0, "the bare depth limit is thousands of units away")
	var warned := false
	w.sight_rank = 2
	w.player.pos = Vector2(100.0, w.max_depth_m() * 0.9 * Ev.TUNING.units_per_m)
	w.step(1.0 / 60.0, Vector2.ZERO)
	for ev in w.events:
		if ev.type == "env_warn" and ev.what == "deep":
			warned = true
	check(warned and w.too_deep == 0.0, "a warning comes before the pressure does")
