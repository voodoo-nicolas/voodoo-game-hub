extends RefCounted

## Block Drop: falling four-square pieces fill a 10×20 well; complete rows
## clear. Speed rises every 10 lines. Pure logic, no Nodes -- the game scene
## calls tick() on its own clock.

const W := 10
const H := 20
## Each piece: list of rotations, each a list of 4 cells (x, y).
const PIECES := [
	[[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)],
	 [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)], [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]],
	[[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)]],
	[[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
	 [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)], [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]],
	[[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)], [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
	 [Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)], [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]],
	[[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)], [Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
	 [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)], [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]],
	[[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
	 [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)], [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]],
	[[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
	 [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)], [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]],
]
const LINE_POINTS := [0, 100, 300, 500, 800]

## Well size and starting speed, set by configure() before reset(). A wider
## well makes every piece smaller on screen (more room to fit them).
var w: int = W
var h: int = H
var start_level: int = 1
## Multiplies the time per gravity step: > 1 is slower (Easy).
var speed_scale: float = 1.0
var well: Array = []       # w*h: 0 empty, else piece type + 1
var piece: int = 0
var rot: int = 0
var pos := Vector2i.ZERO
var next_piece: int = 0
var bag: Array = []
var score: int = 0
var lines: int = 0
var level: int = 1
var over: bool = false

func configure(width: int, height: int, first_level: int = 1, slow: float = 1.0) -> void:
	w = width
	h = height
	start_level = max(1, first_level)
	speed_scale = slow

func reset() -> void:
	well.clear()
	well.resize(w * h)
	well.fill(0)
	bag.clear()
	score = 0
	lines = 0
	level = start_level
	over = false
	next_piece = _from_bag()
	_spawn()

func _from_bag() -> int:
	if bag.is_empty():
		bag = [0, 1, 2, 3, 4, 5, 6]
		bag.shuffle()
	return bag.pop_back()

func _spawn() -> void:
	piece = next_piece
	next_piece = _from_bag()
	rot = 0
	pos = Vector2i(w / 2 - 2, 0)
	if not _fits(piece, rot, pos):
		over = true

func cells(p: int = piece, r: int = rot, at: Vector2i = pos) -> Array:
	var out: Array = []
	var shape: Array = PIECES[p][r % PIECES[p].size()]
	for c in shape:
		out.append(at + c)
	return out

func _fits(p: int, r: int, at: Vector2i) -> bool:
	for c in cells(p, r, at):
		if c.x < 0 or c.x >= w or c.y >= h:
			return false
		if c.y >= 0 and well[c.y * w + c.x] != 0:
			return false
	return true

func move(dx: int) -> bool:
	if over or not _fits(piece, rot, pos + Vector2i(dx, 0)):
		return false
	pos.x += dx
	return true

## Rotates clockwise (dir 1) or counter-clockwise (dir -1), nudging
## sideways/up if blocked (simple wall kicks).
func rotate(dir: int = 1) -> bool:
	if over:
		return false
	var n: int = PIECES[piece].size()
	var r: int = (rot + dir + n) % n
	for kick in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1)]:
		if _fits(piece, r, pos + kick):
			rot = r
			pos += kick
			return true
	return false

## One gravity step. Returns the number of lines cleared if the piece locked,
## -1 if it just fell.
func tick() -> int:
	if over:
		return -1
	if _fits(piece, rot, pos + Vector2i(0, 1)):
		pos.y += 1
		return -1
	return _lock()

func hard_drop() -> int:
	var dist := 0
	while _fits(piece, rot, pos + Vector2i(0, 1)):
		pos.y += 1
		dist += 1
	score += dist * 2
	return _lock()

func ghost_y() -> int:
	var y := pos.y
	while _fits(piece, rot, Vector2i(pos.x, y + 1)):
		y += 1
	return y

func _lock() -> int:
	for c in cells():
		if c.y < 0:
			over = true
			return 0
		well[c.y * w + c.x] = piece + 1
	var cleared := 0
	var y := h - 1
	while y >= 0:
		var full := true
		for x in w:
			if well[y * w + x] == 0:
				full = false
				break
		if full:
			for yy in range(y, 0, -1):
				for x in w:
					well[yy * w + x] = well[(yy - 1) * w + x]
			for x in w:
				well[x] = 0
			cleared += 1
		else:
			y -= 1
	lines += cleared
	score += LINE_POINTS[mini(cleared, 4)] * level
	level = start_level + lines / 10
	_spawn()
	return cleared

func step_seconds() -> float:
	return max(0.08, 0.8 * pow(0.85, level - 1) * speed_scale)
