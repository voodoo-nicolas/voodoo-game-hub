extends SceneTree

## Headless check of the Bug Chain engine: every track shape stays on the
## field and never runs over itself (or the other track), bugs never overlap
## while a level plays, a save round-trips, and an aiming bot plays the 30
## campaign levels at each difficulty (prints how many it clears; a sloppy bot
## should lose more, especially on Hard).
## godot --headless --path . --script res://tools/test_bug_chain.gd

const E = preload("res://scripts/games/bug_chain/bug_chain_engine.gd")
const DT := 1.0 / 60.0

var fails := 0

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	_check_shapes()
	_check_save()
	for skill in [0.9, 0.5]:
		for diff in 3:
			var cleared := 0
			var secs := 0.0
			for n in range(1, E.CAMPAIGN_LEVELS + 1):
				var r := _play(n, diff, skill, n * 31 + diff)
				if r[0]:
					cleared += 1
				secs += r[1]
			print("skill %.1f diff %d: cleared %d/30, avg %.0f s" % [skill, diff, cleared, secs / 30.0])
	# Endless waves build and play too.
	for n in [31, 37, 45, 60]:
		_play(n, 1, 0.9, n)
	print("%s (%d fails) in %d ms" % ["OK" if fails == 0 else "FAILED", fails, Time.get_ticks_msec() - t0])
	quit(1 if fails > 0 else 0)

func _fail(msg: String) -> void:
	fails += 1
	print("FAIL: " + msg)

func _check_shapes() -> void:
	for shape in E.SHAPES:
		var all: Array = []
		for ctrl in E.shape_points(shape):
			var t: Dictionary = E.build_track(ctrl)
			all.append(t)
			if t.len < 150.0:
				_fail("%s: track only %.0f long" % [shape, t.len])
			var pts: PackedVector2Array = t.pts
			for i in pts.size():
				var p := pts[i]
				if i * E.STEP > 20.0 and (p.x < E.R or p.x > E.FIELD.x - E.R or p.y < E.R or p.y > E.FIELD.y - E.R):
					_fail("%s: off the field at s=%.0f %s" % [shape, i * E.STEP, p])
					break
			# Parts far apart along the track must be far apart on the field too.
			var step := 4
			var worst := INF
			for i in range(0, pts.size(), step):
				for j in range(i + int(4.0 * E.D / E.STEP), pts.size(), step):
					if i * E.STEP > 15.0:
						worst = minf(worst, pts[i].distance_to(pts[j]))
			if worst < E.D * 1.15:
				_fail("%s: track runs too close to itself (%.1f)" % [shape, worst])
			print("%s: length %.0f, closest pass %.1f" % [shape, t.len, worst])
		if all.size() == 2:
			var close := INF
			for p in all[0].pts:
				for q in all[1].pts:
					close = minf(close, p.distance_to(q))
			if close < E.D * 1.3:
				_fail("%s: the two tracks come within %.1f" % [shape, close])

func _check_save() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var e = E.new()
	e.setup(E.level_spec(12, 1), rng)
	for i in 600:
		e.update(DT)
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var f = E.new()
	if not f.from_dict(d, rng):
		_fail("save did not load")
		return
	if f.ball_count() != e.ball_count() or f.remaining() != e.remaining() or f.spec.shape != e.spec.shape:
		_fail("save round trip: %d/%d bugs, %d/%d left" % [f.ball_count(), e.ball_count(), f.remaining(), e.remaining()])

## Plays one level with a bot; [cleared, seconds].
func _play(n: int, diff: int, skill: float, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var e = E.new()
	e.setup(E.level_spec(n, diff), rng)
	var t := 0.0
	var reload := 0.0
	var cur := 0
	var last_score := 0
	while t < 900.0:
		t += DT
		reload -= DT
		if reload <= 0.0 and e.shots.is_empty() and not e.losing:
			var present: Array = e.colors_present()
			if not present.is_empty():
				cur = present[rng.randi_range(0, present.size() - 1)]
				var x := _aim(e, cur) if rng.randf() < skill else rng.randf_range(4.0, 96.0)
				e.fire(x, cur)
			reload = 0.3
		var ev: Array = e.update(DT)
		for tr in e.tracks:
			var b: Array = tr.balls
			for i in range(1, b.size()):
				if b[i].s - b[i - 1].s < E.D - 0.01:
					_fail("level %d: bugs overlap (%.2f)" % [n, b[i].s - b[i - 1].s])
					return [false, t]
		if e.score < last_score:
			_fail("score went down")
		last_score = e.score
		for x in ev:
			if x[0] == "cleared":
				return [true, t]
			if x[0] == "lost":
				return [false, t]
	_fail("level %d diff %d: never ended" % [n, diff])
	return [false, t]

## The x where a shot of colour c first meets the longest run of c.
func _aim(e, c: int) -> float:
	var best_x := 50.0
	var best := -1
	for xi in range(4, 97, 2):
		var x := float(xi)
		var hit = null
		var hy := -INF
		for tr in e.tracks:
			for i in tr.balls.size():
				var b: Dictionary = tr.balls[i]
				if b.s < 0.0:
					continue
				var p: Vector2 = E.pos_at(tr, b.vs)
				if absf(p.x - x) < E.D * 0.8 and p.y > hy:
					hy = p.y
					hit = [tr, i]
		if hit == null:
			continue
		var b: Array = hit[0].balls
		var i: int = hit[1]
		if b[i].c != c:
			continue
		var run := 1
		var k := i - 1
		while k >= 0 and b[k].c == c:
			run += 1
			k -= 1
		k = i + 1
		while k < b.size() and b[k].c == c:
			run += 1
			k += 1
		# Prefer runs near the pit.
		var score := run * 100 + int(b[i].s)
		if score > best:
			best = score
			best_x = x
	return best_x
