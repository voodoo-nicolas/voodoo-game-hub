extends SceneTree

## Headless check of Arrows: every Classic level (and the daily/zen sizes) generates,
## is solvable, keeps arrows inside the picture and never overlapping; a wrong tap
## costs a heart and paints the arrow red; a save round-trips.
## godot --headless --path . --script res://tools/test_arrows.gd

const E = preload("res://scripts/games/arrows/arrows_engine.gd")
const G = preload("res://scripts/games/arrows/arrows_generator.gd")

var fails := 0

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var worst := 0
	for lvl in range(1, G.LEVELS + 1):
		var t := Time.get_ticks_msec()
		var p := G.classic(lvl)
		worst = maxi(worst, Time.get_ticks_msec() - t)
		_check_level(p, lvl)
		if lvl in [1, 10, 50, 100, 200, 300, G.LEVELS]:
			var e := E.new()
			e.load_puzzle(p)
			var filled := 0
			var cells := 0
			for a in e.arrows:
				filled += a.cells.size()
			for b in e.mask:
				cells += b
			print("level %d: %dx%d %s, %d arrows, %d%% filled, %d free now" % [lvl, p.cols, p.rows, p.shape,
				p.arrows.size(), 100 * filled / maxi(cells, 1), _free_now(e)])
	# Same seed, same level.
	if JSON.stringify(G.classic(77)) != JSON.stringify(G.classic(77)):
		_fail("level 77 differs between two runs")
	_check_rules()
	print("slowest level: %d ms, total %d ms" % [worst, Time.get_ticks_msec() - t0])
	print("FAILS: %d" % fails if fails else "ALL OK")
	quit(1 if fails else 0)

func _free_now(e) -> int:
	var n := 0
	for i in e.arrows.size():
		if e.can_remove(i):
			n += 1
	return n

func _check_level(p: Dictionary, lvl: int) -> void:
	var e := E.new()
	e.load_puzzle(p)
	if e.arrows.size() < 2:
		_fail("level %d: only %d arrows" % [lvl, e.arrows.size()])
	var seen := {}
	for a in e.arrows:
		if a.cells.size() < 2:
			_fail("level %d: arrow shorter than 2" % lvl)
		for k in a.cells.size():
			var c: Vector2i = a.cells[k]
			if not e.inside(c) or e.mask[c.y * e.cols + c.x] == 0:
				_fail("level %d: arrow outside the picture at %s" % [lvl, c])
			if seen.has(c):
				_fail("level %d: two arrows on %s" % [lvl, c])
			seen[c] = true
			if k > 0 and (c - a.cells[k - 1]).length_squared() != 1:
				_fail("level %d: arrow jumps at %s" % [lvl, c])
	if not e.solvable():
		_fail("level %d: not solvable" % lvl)

func _check_rules() -> void:
	# Two arrows in a row, both pointing right: the left one is blocked by the right one.
	var e := E.new()
	e.load_puzzle({"cols": 6, "rows": 1, "arrows": [[0, 0, 1, 0], [2, 0, 3, 0]]})
	var r: Dictionary = e.tap(0)
	if r.ok or r.blocker != 1 or r.free != 0 or not e.arrows[0].red or e.hearts != 2:
		_fail("blocked tap: %s hearts %d" % [r, e.hearts])
	r = e.tap(1)
	if not r.ok or r.to_edge != 3:
		_fail("free tap: %s" % r)
	var saved := e.to_dict()
	var e2 := E.new()
	if not e2.from_dict(JSON.parse_string(JSON.stringify(saved))):
		_fail("save did not load")
	if e2.hearts != 2 or e2.arrows[1].alive or not e2.arrows[0].red or e2.hint() != 0:
		_fail("save round trip")
	r = e2.tap(0)
	if not r.ok or not e2.solved():
		_fail("red arrow can still leave")
	# Three wrong taps end the level.
	e.load_puzzle({"cols": 6, "rows": 1, "arrows": [[0, 0, 1, 0], [2, 0, 3, 0]]})
	for k in 3:
		e.tap(0)
	if not e.failed() or not e.tap(1).get("ignored", false):
		_fail("three mistakes should end the level")

func _fail(msg: String) -> void:
	fails += 1
	if fails < 20:
		print("FAIL ", msg)
