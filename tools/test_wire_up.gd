extends SceneTree

## Headless check of the Wire Up (pipe_flow) engine: every campaign level builds,
## its own layout lights every bulb, the scramble doesn't, and the colour rules hold.
## godot --headless --path . --script res://tools/test_wire_up.gd

const E = preload("res://scripts/games/pipe_flow/pipe_flow_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	var t0 := Time.get_ticks_msec()
	for lvl in range(1, E.LEVEL_COUNT + 1):
		e.new_level(lvl)
		var p: Dictionary = E.params_for(lvl)
		if e.bulb_total == 0: fails += 1; print("FAIL: level %d has no bulbs" % lvl)
		if e.is_won(): fails += 1; print("FAIL: level %d starts solved" % lvl)
		if e.par <= 0: fails += 1; print("FAIL: level %d par %d" % [lvl, e.par])
		# Same level, same board.
		var first: Array = e.mask.duplicate()
		var e2 = E.new()
		e2.new_level(lvl)
		if e2.mask != first: fails += 1; print("FAIL: level %d not repeatable" % lvl)
		# Playing the generator's answer wins; every piece reaches it by turning.
		var taps := 0
		for c in e.w * e.h:
			if e.kind[c] == E.EMPTY: continue
			if e.fixed[c]:
				if e.mask[c] != e.solution[c]: fails += 1; print("FAIL: level %d fixed piece %d is wrong" % [lvl, c])
				continue
			var guard := 0
			while e.mask[c] != e.solution[c] and guard < 4:
				e.rotate(c)
				taps += 1
				guard += 1
			if e.mask[c] != e.solution[c]: fails += 1; print("FAIL: level %d piece %d can't reach answer" % [lvl, c])
		if not e.is_won(): fails += 1; print("FAIL: level %d answer doesn't win (%d/%d)" % [lvl, e.lit_bulbs, e.bulb_total])
		if taps != e.par: fails += 1; print("FAIL: level %d par %d != taps %d" % [lvl, e.par, taps])
		if e.stars() != 3: fails += 1; print("FAIL: level %d perfect play not 3 stars" % lvl)
		# Board fits the chapter's size.
		if e.w > 8 or e.h > 10: fails += 1; print("FAIL: level %d too big %dx%d" % [lvl, e.w, e.h])
		if lvl % 20 == 0 or lvl == 1:
			print("level %d: %dx%d bulbs %d par %d (asked %dx%d, %d networks)" % [lvl, e.w, e.h, e.bulb_total, e.par, p.w, p.h, p.nets.size()])
		if e.w != p.w or e.h != p.h: fails += 1; print("FAIL: level %d fell back to a smaller board" % lvl)
	print("built %d levels in %d ms" % [E.LEVEL_COUNT, Time.get_ticks_msec() - t0])

	# Colour rules on a hand-made 3x1 strip: blue battery, wire, bulb.
	var m = E.new()
	m.w = 3; m.h = 1
	m.kind = [E.SOURCE, E.WIRE, E.BULB]
	m.color = [E.BLUE, 0, E.BLUE]
	m.mask = [E.E, E.E | E.W, E.W]
	m.fixed = [true, false, true]
	m.analyze()
	if not m.is_won(): fails += 1; print("FAIL: blue on blue")
	m.color[2] = E.YELLOW
	m.analyze()
	if m.is_won() or not m.is_shorted(2): fails += 1; print("FAIL: blue on yellow must short")
	m.color[2] = E.GREEN
	m.analyze()
	if m.is_won(): fails += 1; print("FAIL: blue alone must not light green")
	# Add a yellow battery on the other end of a longer strip: mixed = green.
	var g = E.new()
	g.w = 4; g.h = 1
	g.kind = [E.SOURCE, E.WIRE, E.WIRE, E.SOURCE]
	g.color = [E.BLUE, 0, 0, E.YELLOW]
	g.mask = [E.E, E.E | E.W, E.E | E.W, E.W]
	g.analyze()
	if g.power[1] != E.GREEN: fails += 1; print("FAIL: mixed network should be green, got %d" % g.power[1])
	# Rotation and undo.
	var r = E.new()
	r.w = 1; r.h = 1
	r.kind = [E.WIRE]; r.mask = [E.N | E.E]; r.fixed = [false]; r.color = [0]
	r.rotate(0)
	if r.mask[0] != (E.E | E.S): fails += 1; print("FAIL: rotate")
	r.unrotate(0)
	if r.mask[0] != (E.N | E.E) or r.moves != 0: fails += 1; print("FAIL: undo")

	print("wire up engine: %s" % ("all ok" if fails == 0 else "%d FAIL(S)" % fails))
	quit(1 if fails > 0 else 0)
