extends SceneTree

## Headless test for scripts/games/brick_breaker/brick_breaker_engine.gd
## (Classic + Reloaded power-ups).
##   godot --headless --path . --script res://tools/test_brick_breaker.gd

const BBEngine = preload("res://scripts/games/brick_breaker/brick_breaker_engine.gd")

var fails := 0

func _initialize() -> void:
	_run()
	print("brick_breaker: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _run() -> void:
	# --- Classic: unchanged, no power-ups, no TNT ---
	var e := BBEngine.new()
	e.reset()
	ok(e.balls.size() == 1 and e.stuck, "classic starts with one ball on the paddle")
	ok(not e.bricks.any(func(b): return b.tnt), "classic has no TNT")
	e.set_paddle(100)
	ok(e.ball.x == 100.0, "stuck ball follows the paddle")
	e.launch()
	ok(e.vel.y < 0, "launch goes up")
	var n0 := e.bricks.size()
	for i in 3000:
		e.set_paddle(e.ball.x)  # perfect player
		if e.step(1.0 / 60.0) == "cleared":
			break
	ok(e.lives == 3 and (e.level == 2 or e.bricks.size() < n0), "perfect paddle breaks bricks, loses nothing (%d left)" % e.bricks.size())
	ok(e.powerups.is_empty() and e.timers.is_empty(), "classic never drops power-ups")

	# --- Reloaded ---
	var r := BBEngine.new()
	r.reloaded = true
	r.reset()
	# wide / shrink cancel each other
	r.apply_power("wide")
	ok(is_equal_approx(r.paddle_w(), BBEngine.PADDLE.x * 1.7), "wide paddle")
	r.apply_power("shrink")
	ok(not r.has_power("wide") and r.paddle_w() < BBEngine.PADDLE.x, "shrink replaces wide")
	r.timers.clear()
	# multi-ball launches and splits
	r.apply_power("multi")
	ok(not r.stuck and r.balls.size() == 3, "multi launches + splits into 3 (%d)" % r.balls.size())
	r.apply_power("multi")
	ok(r.balls.size() == 9, "multi again: 9 balls")
	for i in 5:
		r.apply_power("multi")
	ok(r.balls.size() <= BBEngine.MAX_BALLS, "ball cap")
	# losing one ball of several costs no life
	r.reset()
	r.apply_power("multi")
	r.balls[1].p = Vector2(300, 1100)
	r.balls[1].v = Vector2(0, 100)
	r.step(0.016)
	ok(r.lives == 3 and r.balls.size() == 2, "extra ball lost, no life lost")

	# pierce: ball goes straight through a column of bricks without bouncing
	r.reset()
	r.apply_power("pierce")
	r.stuck = false
	r.balls = [{"p": Vector2(30, 600), "v": Vector2(0, -500)}]
	var before := r.bricks.size()
	for i in 60:
		r.step(1.0 / 60.0)
	ok(r.bricks.size() <= before - 5, "fireball smashed a column (%d -> %d)" % [before, r.bricks.size()])
	ok(r.balls[0].v.y < 0 or r.balls[0].p.y < 100, "fireball kept going up")

	# boom: one hit breaks several bricks
	r.reset()
	r.apply_power("boom")
	r.stuck = false
	before = r.bricks.size()
	r.balls = [{"p": Vector2(300, 600), "v": Vector2(0, -500)}]
	for i in 60:
		if r.bricks.size() < before:
			break
		r.step(1.0 / 60.0)
	ok(before - r.bricks.size() >= 3, "explosive ball breaks several (%d)" % (before - r.bricks.size()))

	# TNT chain
	r.reset()
	r.timers.clear()
	for b in r.bricks:
		b.tnt = false
		b.hp = 1
	r.bricks[12].tnt = true
	var n := r.bricks.size()
	r._damage(r.bricks[12], 1)
	ok(n - r.bricks.size() >= 4, "TNT takes neighbours (%d)" % (n - r.bricks.size()))
	ok(r.events.any(func(ev): return ev.type == "boom"), "TNT emits boom event")

	# combo multiplies points
	r.reset()
	r.combo = 4
	var s0 := r.score
	for b in r.bricks:
		b.tnt = false
	r._damage(r.bricks[0], 99)
	ok(r.score - s0 == int(10 * 1.0 * (1.0 + 0.25 * 4)), "combo x5 scores 20 (%d)" % (r.score - s0))

	# capsule caught by the paddle applies it
	r.reset()
	r.set_paddle(300)
	r.powerups = [{"kind": "laser", "pos": Vector2(300, BBEngine.PADDLE_Y - 20)}]
	for i in 20:
		r.step(1.0 / 60.0)
	ok(r.has_power("laser") and r.powerups.is_empty(), "caught capsule -> laser on")
	r.launch()
	before = r.bricks.size()
	var bricks_hp := 0
	for b in r.bricks:
		bricks_hp += b.hp
	for i in 90:
		r.set_paddle(r.ball.x)
		r.step(1.0 / 60.0)
	var after_hp := 0
	for b in r.bricks:
		after_hp += b.hp
	ok(after_hp < bricks_hp, "lasers hit bricks")
	# missed capsule disappears
	r.reset()
	r.powerups = [{"kind": "wide", "pos": Vector2(20, 990)}]
	r.set_paddle(500)
	for i in 30:
		r.step(1.0 / 60.0)
	ok(r.powerups.is_empty() and not r.has_power("wide"), "missed capsule is gone")

	# shield saves one ball
	r.reset()
	r.apply_power("shield")
	r.stuck = false
	r.balls = [{"p": Vector2(50, 940), "v": Vector2(0, 400)}]
	r.set_paddle(500)
	for i in 20:
		r.step(1.0 / 60.0)
	ok(r.lives == 3 and r.shield == 0 and r.balls[0].v.y < 0, "shield bounced the ball")

	# timers run out; life lost clears powers
	r.reset()
	r.apply_power("slow")
	ok(r.speed_mul() < 1.0, "slow-mo")
	r.timers.slow = 0.01
	r.step(0.05)
	ok(not r.has_power("slow"), "power times out")
	r.apply_power("wide")
	r.stuck = false
	r.balls = [{"p": Vector2(300, 1009), "v": Vector2(0, 400)}]
	ok(r.step(0.05) == "lost_life" and r.timers.is_empty(), "lost life clears powers")

	# drops happen over a long game
	var drops := 0
	for k in 4:
		r.reset()
		while not r.bricks.is_empty():
			r._damage(r.bricks[0], 99)
		drops += r.powerups.size()
	ok(drops > 10, "power-ups drop (%d)" % drops)
	for k in BBEngine.POWERS:
		r.apply_power(k)  # every kind applies without error
	ok(true, "all powers apply")

	# --- walls: numbers, steel, diagonals, wide field ---
	var w := BBEngine.new()
	w.field = Vector2(1200, 1000)
	w.reset()
	ok(w.cols() == 20 and w.bricks.size() >= 120, "wide field: 20 columns, bigger wall (%d)" % w.bricks.size())
	var steel_lvls := 0
	var cut_lvls := 0
	var tough := 0
	for lv in range(1, 13):
		w.level = lv
		w._build_level()
		if w.bricks.any(func(b): return b.steel):
			steel_lvls += 1
		if w.bricks.any(func(b): return b.cut >= 0):
			cut_lvls += 1
		for b in w.bricks:
			if b.hp > 2:
				tough += 1
		ok(w.breakable_left() > 0, "level %d has bricks to break" % lv)
	ok(steel_lvls >= 8 and cut_lvls >= 8 and tough > 50, "steel %d / diagonal %d levels, %d tough bricks" % [steel_lvls, cut_lvls, tough])
	# steel never breaks and does not block clearing
	w.level = 5
	w._build_level()
	var st = w.bricks.filter(func(b): return b.steel)[0]
	w._damage(st, 99)
	ok(w.bricks.has(st), "steel shrugs off damage")
	for b in w.bricks.duplicate():
		w._damage(b, 99)
	ok(w.breakable_left() == 0 and w.bricks.size() > 0, "only steel left")
	w.stuck = false
	w.balls = [{"p": Vector2(600, 800), "v": Vector2(0, -300)}]
	ok(w.step(0.016) == "cleared" and w.level == 6, "only steel left = cleared")
	# a slanted side turns the ball sideways
	var d := BBEngine.new()
	d.reset()
	d.bricks = []
	d._add_brick(Vector2i(4, 10), 5, false, 3, false)   # bottom-left corner cut off
	var br = d.bricks[0]
	var c: Vector2 = br.rect.get_center()
	d.stuck = false
	d.balls = [{"p": Vector2(c.x - 8, br.rect.end.y + 14), "v": Vector2(0, -400)}]
	for i in 10:
		d._move_ball(d.balls[0], 1.0 / 120.0)
	ok(d.balls[0].v.x < -100 and br.hp < 5, "diagonal deflects sideways (%s)" % d.balls[0].v)
	# hp numbers count down
	var h := br.hp as int
	d._damage(br, 1)
	ok(br.hp == h - 1, "a hit takes one off the number")

