extends SceneTree

## Crypt Crawler engine: many seeded runs over floors 1-12 with random input, checking that
## monsters stay inside the map (and out of walls, except drifting specters), every new kind
## turns up on its floor, monks summon, gargoyles wake, and health / score stay sane.
##   godot --headless --path . --script res://tools/test_crypt_crawler.gd

const CcEngine = preload("res://scripts/games/crypt_crawler/crypt_crawler_engine.gd")

var fails := 0
var checks := 0

func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		if fails < 30:
			print("FAIL: ", what)

func _init() -> void:
	var seen_kind := {}
	var events := {}
	for seed_ in 10:
		var e = CcEngine.new()
		e.reset(seed_ % 3, seed_)
		for lvl in range(1, 13):
			e.level = lvl
			e.hp = CcEngine.MAX_HP
			e.new_level()
			ok(not e.is_wall(int(e.pos.x), int(e.pos.y)), "start in a wall (seed %d floor %d)" % [seed_, lvl])
			ok(not e.is_wall(e.exit_cell.x, e.exit_cell.y), "exit in a wall")
			for m in e.monsters:
				seen_kind[m.kind] = maxi(int(seen_kind.get(m.kind, 99)), 0)
				if not seen_kind.has(m.kind + "_first") or int(seen_kind[m.kind + "_first"]) > lvl:
					seen_kind[m.kind + "_first"] = lvl
				ok(CcEngine.MONSTERS.has(m.kind), "unknown kind " + m.kind)
			for row in CcEngine.SPAWN:
				for m in e.monsters:
					if m.kind == row[0]:
						ok(lvl >= int(row[1]), "%s on floor %d before its floor %d" % [m.kind, lvl, row[1]])
			for d in e.decor:
				ok(not e.is_wall(int(d.pos.x), int(d.pos.y)), "decor in a wall")
			# Play a while: wander, turn, fire; never die (to keep walking the floor).
			for f in 240:
				var ev: Array = e.step(1.0 / 30.0, sin(f * 0.05), cos(f * 0.031) * 0.5, 0.02 * sin(f * 0.013), f % 3 == 0)
				for x in ev:
					events[x] = int(events.get(x, 0)) + 1
				if e.state != "play":
					break
				e.hp = maxi(e.hp, 40)
				for m in e.monsters:
					var p: Vector2 = m.pos
					ok(p.x > 0.0 and p.y > 0.0 and p.x < e.size and p.y < e.size, "%s left the map" % m.kind)
					if m.kind != "specter":
						ok(not e.is_wall(int(p.x), int(p.y)), "%s inside a wall at %s (floor %d)" % [m.kind, p, lvl])
					ok(m.hp > 0, "dead monster kept")
				ok(e.monsters.size() <= CcEngine.MAX_MONSTERS + 2 * 6, "too many monsters: %d" % e.monsters.size())
				ok(e.hp >= 0 and e.hp <= CcEngine.MAX_HP, "hp out of range")
	# Every kind shows up somewhere, and on its first floor or later.
	for row in CcEngine.SPAWN:
		ok(seen_kind.has(row[0]), "never spawned: " + str(row[0]))
	for x in ["fire", "kill", "hurt", "summon", "wake"]:
		ok(int(events.get(x, 0)) > 0, "event never happened: " + x)
	# A gargoyle sleeps until you are close, then wakes.
	var g = CcEngine.new()
	g.reset(1, 7)
	g.level = 5
	g.new_level()
	g.monsters = []
	g._add_monster("gargoyle", g.pos + Vector2(3.0, 0.0))
	g.step(0.1, 0.0, 0.0, 0.0, false)
	ok(not g.monsters[0].awake, "gargoyle woke from afar")
	g.monsters[0].pos = g.pos + Vector2(1.5, 0.0)
	if g.is_wall(int(g.monsters[0].pos.x), int(g.monsters[0].pos.y)):
		g.monsters[0].pos = g.pos + Vector2(0.0, 1.5)
	var ev2: Array = g.step(0.1, 0.0, 0.0, 0.0, false)
	ok(g.monsters[0].awake and "wake" in ev2, "gargoyle did not wake up close")
	print("crypt_crawler: %d checks, %d failed; events %s" % [checks, fails, events])
	quit(1 if fails > 0 else 0)
