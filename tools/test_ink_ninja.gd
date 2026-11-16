extends SceneTree

## Headless logic test for Ink Ninja's engine: every stage builds, the hero can
## stand at the start, a bot that runs right, jumps and slashes reaches the boss,
## and invariants hold. godot --headless --path . --script res://tools/test_ink_ninja.gd

const E = preload("res://scripts/games/ink_ninja/ink_ninja_engine.gd")
var fails := 0
var _spare := 0

func _spend_spare() -> bool:
	if _spare > 0:
		_spare -= 1
		return true
	return false

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
			check(e.foes.size() > (1 if e.boss_stage() else 3), "foes d%d s%d" % [d, st])   # a boss stage is a short climb
			var t := 0.0
			var deaths := 0
			var best := 0.0
			var dt := 1.0 / 30.0
			while t < 700.0 and e.state == "play":
				var near_pit := false
				for p in e.pits:
					if e.px > p[0] - 90 and e.px < p[0]:
						near_pit = true
				var stuck: bool = absf(e.vx) < 30.0 and not e.locked
				var jump: bool = near_pit or stuck or (not e.on_ground and e.vy > -50.0 and e.jumps == 1) or (randf() < 0.02)
				for bb in e.bridges:
					if not bb.cut and e.px > bb.x0 - 500.0 and e.px < bb.x0:
						e.shots.append({"x": bb.rx - 60.0, "y": bb.ry, "vx": 900.0, "vy": 0.0, "mine": true, "life": 0.5})   # the bot throws a star at the rope
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
	print("end reached in %d/%d runs, won %d" % [reached, 3 * E.STAGES, won])
	check(reached >= 3 * E.STAGES - 5, "a random bot crosses almost every stage to the boss in 700 s")
	# next_stage past the last one clears the campaign
	var e2 = E.new()
	e2.reset(1)
	e2.stage = E.STAGES
	e2.state = "won"
	e2.next_stage()
	check(e2.state == "cleared", "cleared after the last stage")
	# Crouching: an enemy star at thrower height flies over; standing, it hits.
	for crouching in [true, false]:
		var e3 = E.new()
		e3.reset(1)
		e3.foes.clear()
		e3.shots = [{"x": e3.px + 200.0, "y": E.GROUND - 45.0, "vx": -520.0, "vy": 0.0, "mine": false, "life": 2.0}]
		for i in 60:
			e3.step(1.0 / 60.0, 0.0, false, false, false, false, crouching)
		check((e3.hp == E.MAX_HP) == crouching, "crouch=%s star %s" % [crouching, "misses" if crouching else "hits"])
	# Round 3 (2026-11-15): rolling ground with no cliffs, water in dips, breath, knockback.
	var pools_seen := 0
	for st in range(1, E.STAGES + 1):
		var e4 = E.new()
		e4.reset(1)
		e4.stage = st
		e4.build_stage()
		pools_seen += e4.pools.size()
		var steep := 0.0
		for i in e4.heights.size() - 1:
			steep = maxf(steep, absf(e4.heights[i + 1] - e4.heights[i]) / E.SEG)
			check(e4.heights[i] <= E.LOWEST + 0.01, "ground on screen s%d" % st)
		check(steep < 1.6, "no cliff in the ground s%d (steepest %.2f)" % [st, steep])
		check(absf(e4.ground_y(e4.arena_x + 300) - E.GROUND) < 0.01, "flat arena s%d" % st)
	check(pools_seen >= 15, "water in the dips (%d pools)" % pools_seen)
	# Deepest pool: sink, lose breath, drown slowly; a stroke to the surface refills the air.
	var e5 = E.new()
	e5.reset(1)
	var best_pool = null
	for st in range(1, E.STAGES + 1):
		e5.stage = st
		e5.build_stage()
		for w in e5.pools:
			var cx: float = (w.x0 + w.x1) / 2.0
			if e5.ground_y(cx) - w.level > E.PH + 20:
				best_pool = [st, cx]
		if best_pool != null:
			break
	check(best_pool != null, "a pool deep enough to swim")
	if best_pool != null:
		e5.stage = best_pool[0]
		e5.build_stage()
		e5.foes.clear()
		e5.px = best_pool[1]
		e5.py = e5.water_level(e5.px) - 10.0
		for i in 120:
			e5.step(1.0 / 60.0, 0.0, false, false, false, false)
		check(e5.on_ground and e5.air < E.AIR, "sank to the bottom, holding breath")
		for i in int((E.AIR + 2.0) * 60):
			e5.step(1.0 / 60.0, 0.0, false, false, false, false)
		check(e5.hp < E.MAX_HP, "drowning costs hearts")
		var hp_before: int = e5.hp
		var surfaced := false
		for i in 240:
			e5.step(1.0 / 60.0, 0.0, i % 20 == 0, false, false, false)
			if e5.air >= E.AIR:
				surfaced = true
		check(surfaced and e5.hp >= hp_before - 1, "swim strokes reach the air and refill it")
	# Wading is 30% slower.
	var e6 = E.new()
	e6.reset(1)
	check(absf(E.WADE - 0.7) < 0.001, "wading speed 70%")
	# Stage 1 boss: touching it no longer chains hits; you are knocked clear.
	var e7 = E.new()
	e7.reset(1)
	e7.foes.clear()
	e7.px = e7.arena_x + 200
	e7.step(1.0 / 60.0, 0.0, false, false, false, false)
	e7.boss.x = e7.px + 20
	e7.boss.phase = "idle"
	e7.boss.t = 5.0
	for i in 90:
		e7.step(1.0 / 60.0, 1.0, false, false, false, false)   # keep pushing into it
	check(e7.hp >= E.MAX_HP - 2, "stage-1 boss contact for 1.5 s costs at most 2 hearts (hp %d)" % e7.hp)
	# Owner round 4 (2026-11-15): thrust attacks, block, crouch under the tutorial beam, no one-hit death.
	for st in [4, 6, 9]:
		var t1 = E.new()
		t1.reset(1)
		t1.stage = st
		t1.build_stage()
		t1.foes.clear()
		t1.foes.append({"kind": "brute", "x": t1.px + 120.0, "y": t1.ground_y(t1.px + 120.0), "vx": 0.0, "vy": 0.0, "hp": 3, "face": -1, "t": 9.0, "atk": 0.0, "hit": 0.0, "id": 0})
		t1.step(1.0 / 60.0, 1.0, false, false, false, true)
		for i in 60:
			t1.step(1.0 / 60.0, 1.0, false, false, false, false)
		check(t1.state == "play" and t1.hp >= E.MAX_HP - 1, "thrust into a brute s%d: hero fine (hp %d)" % [st, t1.hp])
		check(t1.foes.is_empty() or t1.foes[0].hp < 3, "thrust damages the brute s%d" % st)
	var t2 = E.new()
	t2.reset(1)
	t2.stage = 2
	t2.build_stage()
	t2.foes.clear()
	t2.shots = [{"x": t2.px + 200.0, "y": t2.py - 45.0, "vx": -520.0, "vy": 0.0, "mine": false, "life": 2.0}]
	for i in 60:
		t2.step(1.0 / 60.0, 0.0, false, false, false, false, false, true)
	check(t2.hp == E.MAX_HP, "block stops a star on stage 2")
	var t3 = E.new()
	t3.reset(1)
	check(not t3.can("block") and not t3.can("star") and not t3.can("thrust"), "stage 1: basics only")
	t3.foes.clear()
	var thrown: int = t3.stars
	t3.step(1.0 / 60.0, 0.0, false, false, true, false)
	check(t3.stars == thrown, "no stars on stage 1")
	t3.px = 900.0
	for i in 300:
		t3.step(1.0 / 60.0, 1.0, false, false, false, false, true)
	check(t3.px > 1200.0, "crouch-creep under the tutorial beam (x %d)" % t3.px)
	for i in 30:
		t3.step(1.0 / 60.0, 1.0, false, false, false, false)
	check(t3.py >= t3.ground_y(t3.px) - 1.0, "stands up on the ground, not on the beam")
	var t4 = E.new()
	t4.reset(1)
	t4.stage = 5
	t4.build_stage()
	t4.hp = E.MAX_HP
	t4._hurt(5, false, t4.px + 50.0)
	check(t4.state == "play" and t4.hp >= 1, "one blow never kills a hero with hearts to spare")
	# 24 stages: bosses only on every 4th; a plain stage is cleared at its gate.
	var e8 = E.new()
	e8.reset(1)
	e8.foes.clear()
	e8.px = e8.arena_x + 100
	var ev8: Array = e8.step(1.0 / 60.0, 1.0, false, false, false, false)
	check(e8.state == "won" and "clear" in ev8 and e8.boss.is_empty(), "stage 1 cleared at its gate, no boss")
	e8.stage = 4
	e8.build_stage()
	e8.foes.clear()
	e8.px = e8.arena_x + 100
	e8.step(1.0 / 60.0, 1.0, false, false, false, false)
	check(e8.state == "play" and not e8.boss.is_empty() and e8.boss_name() == "Gate Warden", "stage 4: the Gate Warden")
	e8.stage = 24
	check(e8.boss_name() == "Lord Shu" and e8.act() == 6, "stage 24: Lord Shu, act 6")
	# Round 11 (owner 2026-11-16).
	# Nothing to pick up that the hero cannot use: stages 1-2 drop no stars or bombs; hearts only from bamboo.
	for st in [1, 2, 3]:
		var d1 = E.new()
		d1.reset(1)
		d1.stage = st
		d1.build_stage()
		d1.foes.clear()
		d1.drops.clear()
		for i in 400:
			d1.flora = [{"x": d1.px + 30.0, "kind": "bamboo", "s": 1, "h": 1.0}]
			d1.slash_t = 0.0
			d1.step(1.0 / 60.0, 0.0, false, true, false, false)
			for dd in d1.drops:
				if st < 3:
					check(dd.kind == "heart", "stage %d bamboo gives only hearts (%s)" % [st, dd.kind])
			d1.hp = E.MAX_HP
			d1.drops.clear()
	var d2 = E.new()
	d2.reset(1)
	d2.stage = 5
	d2.build_stage()
	d2.foes.clear()
	d2.drops.clear()
	for i in 600:
		d2.foes = [{"kind": "blade", "x": d2.px + 40.0, "y": d2.py, "vx": 0.0, "vy": 0.0, "hp": 1, "face": -1, "t": 9.0, "atk": 0.0, "hit": 0.0, "id": 1}]
		d2.hurt_t = 5.0
		d2.slash_t = 0.0
		d2.step(1.0 / 60.0, 0.0, false, true, false, false)
	var heart_drops := 0
	for dd in d2.drops:
		if dd.kind == "heart":
			heart_drops += 1
	check(heart_drops == 0, "kills never drop hearts")
	# Stars and bombs are capped.
	d2.stars = E.MAX_STARS
	d2.bombs = E.MAX_BOMBS
	d2.drops = [{"x": d2.px, "y": d2.py - 20.0, "vy": 0.0, "kind": "star", "age": 1.0}, {"x": d2.px, "y": d2.py - 20.0, "vy": 0.0, "kind": "bomb", "age": 1.0}]
	d2.step(1.0 / 60.0, 0.0, false, false, false, false)
	check(d2.stars == E.MAX_STARS and d2.bombs == E.MAX_BOMBS and d2.drops.size() == 2, "a full quiver and bomb bag leave pickups on the ground")
	# Stage 2: the first foe stands on dry ground.
	for d in 3:
		var f2 = E.new()
		f2.reset(d)
		f2.stage = 2
		f2.build_stage()
		var f0: Dictionary = f2.foes[0]
		check(f2.water_depth(f0.x) <= 0.0 and f2.water_depth(f0.x - 60.0) <= 0.0, "stage 2 first foe is dry d%d" % d)
	# Space before the gate: nothing within END_CLEAR of the end.
	for st in range(1, E.STAGES + 1):
		var g1 = E.new()
		g1.reset(1)
		g1.stage = st
		g1.build_stage()
		var last := 0.0
		for f in g1.foes:
			last = maxf(last, f.x)
		for sc in g1.scrolls:
			last = maxf(last, sc.x)
		for sl in g1.solids:
			if sl.size.y < 600.0:
				last = maxf(last, sl.end.x)
		for st2 in g1.structs:
			last = maxf(last, st2.x)
		for t in g1.trees:
			last = maxf(last, t.x)
		check(g1.length - last >= E.END_CLEAR - 5.0, "s%d: %d px clear before the gate" % [st, g1.length - last])
	# Drawbridge: a star at the rope lowers it; the lake is deadly until then.
	var b1 = E.new()
	b1.reset(1)
	b1.stage = 3
	b1.build_stage()
	b1.foes.clear()
	check(not b1.bridges.is_empty(), "stage 3 has a drawbridge lake")
	var br: Dictionary = b1.bridges[0]
	check(b1.pool_at((br.x0 + br.x1) / 2.0).get("deadly", false), "the lake is deadly")
	b1.shots.append({"x": br.rx - 100.0, "y": br.ry, "vx": 900.0, "vy": 0.0, "mine": true, "life": 1.0})
	for i in 30:
		b1.step(1.0 / 60.0, 0.0, false, false, false, false)
	check(br.cut and b1.solids.has(br.deck), "a star through the knot lowers the bridge")
	b1.px = br.x0 - 100.0
	b1.py = b1.ground_y(b1.px)
	b1.hp = E.MAX_HP
	for i in 900:
		b1.step(1.0 / 60.0, 1.0, false, false, false, false)
	check(b1.px > br.x1 + 20.0 and b1.hp == E.MAX_HP, "the lowered bridge can be walked across (x %d of %d, hp %d)" % [b1.px, br.x1, b1.hp])
	# Without the bridge, swimming the lake is nearly fatal.
	var b2 = E.new()
	b2.reset(1)
	b2.stage = 3
	b2.build_stage()
	b2.foes.clear()
	var br2: Dictionary = b2.bridges[0]
	b2.px = br2.x0 - 20.0
	b2.py = b2.ground_y(b2.px)
	for i in 1500:
		b2.step(1.0 / 60.0, 1.0, i % 25 == 0, false, false, false)
		if b2.state == "dead":
			break
	check(b2.state == "dead" or b2.hp <= 2, "crossing the deep lake without the bridge costs nearly everything (hp %d)" % b2.hp)
	# Spike board: kills foes under it when it drops.
	var k1 = E.new()
	k1.reset(1)
	k1.stage = 5
	k1.build_stage()
	check(not k1.traps.is_empty(), "stage 5 has a spike board")
	var tr: Dictionary = k1.traps[0]
	k1.foes = [{"kind": "blade", "x": tr.x + 10.0, "y": tr.y, "vx": 0.0, "vy": 0.0, "hp": 1, "face": -1, "t": 9.0, "atk": 0.0, "hit": 0.0, "id": 5},
		{"kind": "blade", "x": tr.x - 30.0, "y": tr.y, "vx": 0.0, "vy": 0.0, "hp": 1, "face": -1, "t": 9.0, "atk": 0.0, "hit": 0.0, "id": 6}]
	k1.px = tr.x - 900.0
	k1.py = k1.ground_y(k1.px)
	tr.t = 2.6 - tr.ph
	var killed := false
	for i in 90:
		var ev: Array = k1.step(1.0 / 60.0, 0.0, false, false, false, false)
		if "trapkill" in ev:
			killed = true
	check(killed and k1.foes.is_empty(), "a dropping spike board kills the foes under it")
	# Air cuts: rising = up, falling = down (and a plunge onto a foe bounces).
	var a1 = E.new()
	a1.reset(1)
	a1.foes.clear()
	a1.step(1.0 / 60.0, 0.0, true, false, false, false)
	var ev1: Array = a1.step(1.0 / 60.0, 0.0, false, true, false, false)
	check("slash_up" in ev1 and a1.air_dir == 1, "a cut while rising goes up")
	var a2 = E.new()
	a2.reset(1)
	a2.foes.clear()
	a2.py = a2.ground_y(a2.px) - 200.0
	a2.on_ground = false
	a2.vy = 300.0
	a2.foes = [{"kind": "blade", "x": a2.px, "y": a2.py + 60.0, "vx": 0.0, "vy": 0.0, "hp": 1, "face": -1, "t": 9.0, "atk": 0.0, "hit": 0.0, "id": 3}]
	var ev2: Array = a2.step(1.0 / 60.0, 0.0, false, true, false, false)
	check("slash_down" in ev2 and a2.air_dir == 2, "a cut while falling goes down")
	for i in 6:
		ev2 = a2.step(1.0 / 60.0, 0.0, false, false, false, false)
	check(a2.foes.is_empty() and a2.vy < 0.0, "a plunging cut kills the foe and bounces the hero (vy %d)" % a2.vy)
	# Spare lives: the last heart spends one automatically and the hero stays on his feet.
	var r1 = E.new()
	r1.reset(1)
	r1.stage = 5
	r1.build_stage()
	_spare = 1
	r1.revive_cb = _spend_spare
	r1.hp = 1
	r1.hurt_t = 0.0
	r1._hurt(3, false, r1.px + 30.0)
	check(r1.state == "play" and r1.hp == 3, "a spare life revives on the spot")
	r1.hp = 1
	r1.hurt_t = 0.0
	r1._hurt(3, false, r1.px + 30.0)
	check(r1.state == "dead", "with no spare life the hero falls as before")
	# Foes may wade into water but do not last in deep water.
	var w1 = E.new()
	w1.reset(1)
	w1.stage = 3
	w1.build_stage()
	var lake: Dictionary = w1.bridges[0]
	var mid: float = (lake.x0 + lake.x1) / 2.0
	w1.foes = [{"kind": "blade", "x": mid, "y": w1.ground_y(mid), "vx": 0.0, "vy": 0.0, "hp": 1, "face": -1, "t": 9.0, "atk": 0.0, "hit": 0.0, "id": 9}]
	w1.px = mid + 600.0
	w1.py = w1.ground_y(w1.px)
	for i in 300:
		w1.step(1.0 / 60.0, 0.0, false, false, false, false)
	check(w1.foes.is_empty(), "a foe in the deep lake drowns")
	# Night stages have lanterns; a torch swing lights one.
	var n1 = E.new()
	n1.reset(1)
	n1.stage = E.NIGHT_STAGES[0]
	n1.build_stage()
	check(n1.night and not n1.night_lanterns.is_empty(), "night stage has dark lanterns")
	n1.foes.clear()
	var nl: Dictionary = n1.night_lanterns[0]
	n1.px = nl.x - 40.0
	n1.py = n1.ground_y(n1.px)
	n1.step(1.0 / 60.0, 0.0, false, true, false, false)
	for i in 10:
		n1.step(1.0 / 60.0, 0.0, false, false, false, false)
	check(nl.lit, "swinging the torch lights the lantern")
	# Secrets: a rooftop scroll is worth it.
	var sx1 = E.new()
	sx1.reset(1)
	sx1.stage = 2
	sx1.build_stage()
	sx1.foes.clear()
	check(not sx1.secrets.is_empty(), "stage 2 hides secrets")
	var sec: Dictionary = sx1.secrets[0]
	sx1.px = sec.x
	sx1.py = sec.y + 35.0
	sx1.vy = 0.0
	var ev3: Array = sx1.step(1.0 / 60.0, 0.0, false, false, false, false)
	check("secret" in ev3 and sx1.secrets_found == 1, "collecting a secret")
	print("ink_ninja: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails else 0)
