extends SceneTree

## Headless check of the Poker table layout (video_poker_view.gd): for 2 to 6
## seats on screens of several shapes, every seat's plate stays inside the
## felt and clear of the other plates, the board and the pot line, and every
## bet lies on the felt, not on a plate or the board. Pure geometry: no
## drawing, no saves.
## godot --headless --path . --script res://tools/test_poker_layout.gd

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const View = preload("res://scripts/games/video_poker/video_poker_view.gd")

## The view's size on a few screens: phones in portrait (small, usual, tall), and the same
## kind of screens turned on their side, a tablet.
const SIZES := [Vector2(540, 860), Vector2(720, 900), Vector2(720, 1100), Vector2(900, 600), Vector2(1280, 640), Vector2(1100, 800)]

var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	for variant in ["holdem", "stud"]:
		for seats in range(2, 7):
			for sz in SIZES:
				_check(variant, seats, sz)
	print("poker layout: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)

func _check(variant: String, seats: int, sz: Vector2) -> void:
	var tag := "%s, %d seats, view %dx%d" % [variant, seats, sz.x, sz.y]
	var t = Table.new()
	t.variant = variant
	t.limit = "fl" if variant == "stud" else "nl"
	for i in seats:
		t.seats.append(Table.new_seat("P%d" % i, 1000, 1 if i == 0 else 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	t.start_hand(rng)
	var v = View.new()
	v.t = t
	v.viewer = 0
	v.size = sz
	var play: Rect2 = v.play_rect()
	var plates: Array = []
	for i in range(1, seats):
		var r: Rect2 = v.seat_rect(i)
		plates.append(r)
		ok(play.encloses(r), tag + ": seat %d inside the felt (%s in %s)" % [i, str(r), str(play)])
	for a in plates.size():
		for b in range(a + 1, plates.size()):
			ok(not (plates[a] as Rect2).intersects(plates[b]), tag + ": plates %d and %d overlap" % [a + 1, b + 1])
	var board := Rect2()
	if variant == "holdem":
		board = v._board_rect()
		ok(board.size.x > 0 and play.encloses(board), tag + ": board inside the felt (%s)" % str(board))
		for r in plates:
			ok(not (r as Rect2).intersects(board), tag + ": a plate on the board")
		var pot := Rect2(v._pot_pos() - Vector2(105, 32), Vector2(210, 42))
		for r in plates:
			ok(not (r as Rect2).intersects(pot), tag + ": a plate on the pot line")
		ok(board.size.x / 5.0 >= 28.0, tag + ": board cards at least 28 wide (%f)" % (board.size.x / 5.0))
	for i in range(seats):
		var spot: Vector2 = v.bet_spot(i)
		ok(play.grow(-8).has_point(spot), tag + ": seat %d bet on the felt (%s)" % [i, str(spot)])
		for r in plates:
			ok(not (r as Rect2).grow(-1).has_point(spot), tag + ": seat %d bet lies on a plate" % i)
		if board.size.x > 0:
			ok(not board.has_point(spot), tag + ": seat %d bet lies on the board" % i)
	v.free()
