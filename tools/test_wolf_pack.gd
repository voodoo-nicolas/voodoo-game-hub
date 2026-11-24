extends SceneTree

## Stonewater: engine + data (campaign maps, ranks, missions, Quick Mission generator).
## godot --headless --path . --script res://tools/test_wolf_pack.gd
## - ranks rise with renown and the campaign pays enough to reach every rank
## - every campaign map builds; den, landmark, posts and herds are inside it
## - Quick Mission: same choices = same mission; every map type x role builds and is winnable in principle
## - objectives: marking posts, reaching the Howl Point, scouting finish a mission; stars add up
## - the non-leader roles get an automatic leader; raids spawn and cost the den
## - save / load round trip keeps the state

const E = preload("res://scripts/games/wolf_pack/wolf_pack_engine.gd")
const D = preload("res://scripts/games/wolf_pack/wolf_pack_data.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL ", msg)
		fails += 1

func inside(p: Vector2, m: Dictionary) -> bool:
	return p.x > 0.0 and p.y > 0.0 and p.x < float(m.w) and p.y < float(m.h)

func _init() -> void:
	# --- ranks
	check(D.rank_for(0) == 0 and D.rank_for(99) == 0 and D.rank_for(100) == 1, "rank thresholds")
	check(D.rank_for(100000) == D.RANKS.size() - 1, "top rank")
	var last := -1
	for rk in D.RANKS:
		check(int(rk.renown) > last, "renown thresholds rise (%s)" % rk.id)
		last = int(rk.renown)
	for i in range(1, D.RANKS.size()):
		for c in D.RANKS[i - 1].cmds:
			check(c in D.RANKS[i].cmds, "rank %d keeps command %s" % [i, c])
		for a in D.RANKS[i - 1].abil:
			check(a in D.RANKS[i].abil, "rank %d keeps ability %s" % [i, a])
		check((D.RANKS[i].roster as Array).size() >= (D.RANKS[i - 1].roster as Array).size(), "roster grows")
	var total := 0
	for m in D.MISSIONS:
		total += D.reward_for(m, 1, true)
	check(total >= int(D.RANKS.back().renown), "campaign pays %d, top rank needs %d" % [total, D.RANKS.back().renown])
	# no mission gets a rank before it could be earned: the reward before mission i must not skip two ranks
	var acc := 0
	for m in D.MISSIONS:
		var before := D.rank_for(acc)
		acc += D.reward_for(m, 3, true)
		check(D.rank_for(acc) - before <= 1, "%s: a mission skips a rank" % m.id)

	# --- campaign maps
	for id in D.MAPS:
		var mp: Dictionary = D.MAPS[id]
		check(int(mp.w) % 32 == 0 and int(mp.h) % 32 == 0, "%s size is whole cells" % id)
		check(D.MAP_TYPES.has(mp.type), "%s has a terrain type" % id)
		check(inside(mp.den, mp) and inside(mp.landmark, mp), "%s den/landmark inside" % id)
		for p in mp.posts:
			check(inside(p, mp), "%s post inside" % id)
		for hd in mp.herds:
			check(inside(hd.at, mp) and D.SPECIES.has(hd.sp), "%s herd ok" % id)
		for rg in mp.rivals:
			check(inside(rg.at, mp), "%s rival inside" % id)
	var seen_ids := {}
	for m in D.MISSIONS:
		check(not seen_ids.has(m.id), "unique mission id %s" % m.id)
		seen_ids[m.id] = true
		check(D.MAPS.has(m.map), "%s: map exists" % m.id)
		var mp2: Dictionary = D.map_for(m)
		for o in m.objectives:
			if o.t == "mark":
				check(int(o.n) <= (mp2.posts as Array).size(), "%s: enough posts" % m.id)
			if o.t == "rivals":
				var avail := 0
				for rg in mp2.rivals:
					avail += int(rg.n)
				for wv in m.get("waves", []):
					avail += int(wv[1])
				check(int(o.n) <= avail, "%s: enough rivals (%d of %d)" % [m.id, o.n, avail])
			if o.t == "hunt":
				var animals := 0
				for hd in mp2.herds:
					if not o.has("sp") or hd.sp == o.sp:
						animals += int(hd.n)
				check(int(o.n) <= animals, "%s: enough prey" % m.id)
		# builds, at the rank the mission is played at
		var eng = E.new()
		var rank_at := D.rank_for(0)
		var idx := D.mission_index(m.id)
		var cum := 0
		for k in idx:
			cum += D.reward_for(D.MISSIONS[k], 2, true)
		rank_at = D.rank_for(cum)
		eng.start(mp2, m, rank_at, "leader", D.rank(rank_at).roster)
		check(eng.hgt.size() == eng.TGW * eng.TGH, "%s: terrain built" % m.id)
		check(eng.herd.size() > 0, "%s: has prey" % m.id)
		var ev: Array = eng.step(0.05, {})
		check(not eng.over, "%s: not over at the start" % m.id)

	# --- quick missions
	var q1: Dictionary = D.quick_setup("marsh", "scout", 777)
	var q2: Dictionary = D.quick_setup("marsh", "scout", 777)
	check(q1.map.den == q2.map.den and q1.map.posts == q2.map.posts and q1.mission.objectives == q2.mission.objectives, "quick is deterministic")
	var q3: Dictionary = D.quick_setup("marsh", "scout", 778)
	check(q3.map.den != q1.map.den or q3.map.posts != q1.map.posts, "other seed, other mission")
	for ty in D.TYPE_ORDER:
		for ro in D.ROLE_ORDER:
			for sd in [1, 2, 3]:
				var q: Dictionary = D.quick_setup(ty, ro, sd)
				var mp3: Dictionary = q.map
				check(inside(mp3.den, mp3) and inside(mp3.landmark, mp3), "quick %s/%s den inside" % [ty, ro])
				check(mp3.den.distance_to(mp3.landmark) > 600.0, "quick %s/%s den away from the landmark" % [ty, ro])
				for p in mp3.posts:
					check(inside(p, mp3), "quick post inside")
				var roster: Array = D.quick_roster(ro)
				check((ro == "leader") == not ("leader" in roster), "quick roster %s" % ro)
				check(not (ro in roster), "quick roster drops the player's own role %s" % ro)
				var eng2 = E.new()
				eng2.start(mp3, q.mission, q.rank, ro, roster)
				for o in eng2.objectives():
					check(o.need > 0, "quick objective has a goal")
				var rivals_avail := 0
				for rg in mp3.rivals:
					rivals_avail += int(rg.n)
				for o in q.mission.objectives:
					if o.t == "rivals":
						check(int(o.n) <= rivals_avail, "quick %s/%s rivals %d <= %d" % [ty, ro, o.n, rivals_avail])
					if o.t == "mark":
						check(int(o.n) <= (mp3.posts as Array).size(), "quick marks")

	# --- objectives and stars
	var m1: Dictionary = D.mission("m04")   # mark 4 + drive off 3
	var e = E.new()
	e.start(D.map_for(m1), m1, 3, "leader", D.rank(3).roster)
	for p in e.posts:
		e.hero.p = p.p
		e.step(0.05, {})
	check(e.marked_count() == e.posts.size(), "all posts marked")
	check(not e.over, "not over with rivals left")
	for r in e.rivals:
		r.hp = 1.0
	e.step(0.05, {})
	check(e.driven_off >= 3 or e.over, "rivals driven off when hurt: %d" % e.driven_off)
	for r in e.rivals:
		r.hp = 1.0
	e.step(0.05, {})
	check(e.over and e.outcome == "win", "mission won (%s, driven %d)" % [e.outcome, e.driven_off])
	var res: Dictionary = e.result()
	check(res.stars >= 2, "quick win in time gives 2+ stars, no one down gives 3: %d" % res.stars)

	var e2 = E.new()
	var m5: Dictionary = D.mission("m05")   # reach the Howl Point + 3 elk
	e2.start(D.map_for(m5), m5, 3, "leader", D.rank(3).roster)
	e2.hero.p = e2.landmark
	for w in e2.pack:
		w.p = e2.landmark + Vector2(60, 40)
	e2.step(0.05, {})
	check(e2.reached, "Howl Point reached with the pack")
	var e3 = E.new()
	e3.start(D.map_for(m5), m5, 3, "leader", D.rank(3).roster)
	e3.hero.p = e3.landmark
	for w in e3.pack:
		w.p = e3.den
	e3.step(0.05, {})
	check(not e3.reached, "Howl Point needs the pack with you")

	# scouting: reveal the whole map by stepping the hero around is slow; mark all cells instead
	var m3: Dictionary = D.mission("m03")
	var e4 = E.new()
	e4.start(D.map_for(m3), m3, 2, "scout", D.rank(2).roster)
	for i in e4.revealed.size():
		e4.revealed[i] = 1
	check(e4.scout_pct() == 100, "scout pct")

	# --- the leader NPC for non-leader roles
	var qa: Dictionary = D.quick_setup("hills", "chaser", 5)
	var e5 = E.new()
	e5.start(qa.map, qa.mission, qa.rank, "chaser", D.quick_roster("chaser"))
	check(e5.pack.any(func(w): return w.role == "leader"), "Sable leads when the hero is the chaser")
	e5.hero.p = (e5.herd[0] as Dictionary).p + Vector2(300, 0)
	for _i in 120:
		e5.step(0.05, {})
	check(e5.command in ["drive", "flank", "strike", "rally"], "auto leader picks a command: %s" % e5.command)

	# --- raids and defence (m06)
	var m6: Dictionary = D.mission("m06")
	var e6 = E.new()
	e6.start(D.map_for(m6), m6, 3, "leader", D.rank(3).roster)
	var spawned := 0
	for _i in 4000:
		e6.step(0.05, {})
		if e6.over:
			break
	for r in e6.rivals:
		spawned += 1
	check(spawned >= 8, "waves spawned %d raiders" % spawned)
	check(e6.over, "the night ends one way or the other")
	if e6.outcome == "fail":
		check(e6.fail_reason == "den", "den fell")
	print("m06 outcome with an idle hero: ", e6.outcome, " den ", int(e6.den_hp), " time ", int(e6.time))
	# Nobody home: the raiders walk in and the den falls.
	var e6b = E.new()
	e6b.start(D.map_for(m6), m6, 3, "leader", [])
	e6b.hero.p = Vector2(e6b.W - 120.0, e6b.H - 120.0)
	for _i in 6000:
		e6b.step(0.05, {})
		if e6b.over:
			break
	check(e6b.den_hp < 100.0, "raiders hurt an undefended den (%d)" % int(e6b.den_hp))

	# --- hero down / wolf down / abilities
	var e7 = E.new()
	e7.start(D.map_for(D.mission("m01")), D.mission("m01"), 0, "leader", [])
	check(e7.hero_stats().bite == 4.0, "pup bite")
	check(not e7.has_command("drive") and e7.set_command("drive") == false, "pup cannot Drive")
	check(e7.set_command("hold"), "pup can Hold")
	var e8 = E.new()
	e8.start(D.map_for(D.mission("m07")), D.mission("m07"), 4, "leader", D.rank(4).roster)
	check(e8.set_command("guard"), "Pack Leader can Guard")
	check(e8.set_command("rally") and e8.rally_cd > 0.0, "Rallying Howl starts")
	var ev8: Array = e8.step(0.05, {})
	check(ev8.any(func(x): return x[0] == "rally_howl"), "rally_howl event")
	e8._hurt_hero(9999.0, Vector2.ZERO, ev8)
	check(e8.downs == 1 and e8.hero.down_t > 0.0, "hero down counts")
	for _i in 80:
		e8.step(0.05, {})
	check(e8.hero.hp > 0.0 and e8.hero.p == e8.den or e8.hero.down_t <= 0.0, "hero back at the den")
	e8._hurt_wolf(e8.pack[0], 9999.0, ev8)
	check(e8.downs == 2 and e8.pack[0].down_t > 0.0, "wolf down counts")

	# --- save round trip
	var sv = e8.to_dict()
	var js = JSON.stringify(sv)
	var back: Dictionary = JSON.parse_string(js)
	var e9 = E.new()
	e9.start(D.map_for(D.mission("m07")), D.mission("m07"), 4, "leader", D.rank(4).roster)
	e9.from_dict(back)
	check(absf(e9.time - e8.time) < 0.001 and e9.downs == e8.downs and e9.kills == e8.kills, "save round trip")
	check(e9.revealed == e8.revealed, "fog round trip")
	check(e9.pack[0].down_t > 0.0, "wolf down time kept")

	print("wolf_pack test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
