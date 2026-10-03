extends RefCounted

## Snake on a cols x rows field, for one snake (solo) or two (versus).
## Pure logic, no Nodes -- the game scene calls step() on its own clock.
##
## Versus: a snake dies when its head leaves the field, hits its own body or
## hits the OTHER snake's body -- so you win by making your opponent run into
## your side. Two heads meeting (same cell, or swapping places) kill both.

enum Dir { UP, DOWN, LEFT, RIGHT }

const DELTA := {
	Dir.UP: Vector2i(0, -1), Dir.DOWN: Vector2i(0, 1),
	Dir.LEFT: Vector2i(-1, 0), Dir.RIGHT: Vector2i(1, 0),
}
const OPPOSITE := {
	Dir.UP: Dir.DOWN, Dir.DOWN: Dir.UP,
	Dir.LEFT: Dir.RIGHT, Dir.RIGHT: Dir.LEFT,
}
const START_LEN := 3
## Swipes that can wait behind the next step's turn.
const MAX_TURNS := 2

var cols: int = 15
var rows: int = 15
## [{body: Array[Vector2i] (0 = head), dir, pending, turns: Array, alive: bool, score: int}]
## pending = the direction of the next step; turns = later swipes waiting
## their turn, so two quick swipes (a U-turn) inside one step both count.
var snakes: Array = []
var foods: Array = []  # Vector2i
var game_over: bool = false
## Versus result once over: index of the surviving snake, or -1 for a draw.
var winner: int = -1

# Solo shortcuts, kept for older callers/tests.
var snake: Array:
	get: return snakes[0].body if not snakes.is_empty() else []
var score: int:
	get: return snakes[0].score if not snakes.is_empty() else 0
var food: Vector2i:
	get: return foods[0] if not foods.is_empty() else Vector2i(-1, -1)
var grid_size: int:
	get: return cols

func reset(p_cols: int = 15, p_rows: int = -1, players: int = 1) -> void:
	cols = p_cols
	rows = p_rows if p_rows > 0 else p_cols
	snakes.clear()
	foods.clear()
	game_over = false
	winner = -1
	if players <= 1:
		_add_snake(Vector2i(cols / 2, rows / 2), Dir.RIGHT)
	else:
		# Opposite corners-ish, heading toward each other's side.
		_add_snake(Vector2i(cols / 2, rows - 4), Dir.UP)
		_add_snake(Vector2i(cols / 2 - 1, 3), Dir.DOWN)
	for i in (1 if players <= 1 else 3):
		_spawn_food()

func _add_snake(head: Vector2i, d: int) -> void:
	var body: Array = []
	for k in START_LEN:
		body.append(head - DELTA[d] * k)
	snakes.append({"body": body, "dir": d, "pending": d, "turns": [], "alive": true, "score": 0})

func players() -> int:
	return snakes.size()

func _occupied(cell: Vector2i) -> bool:
	for s in snakes:
		if s.body.has(cell):
			return true
	return foods.has(cell)

## Picks from the actually-free cells, so it can't spin forever once the
## snakes cover most of the board. A full board (solo) means the player won.
func _spawn_food() -> void:
	var free: Array = []
	for x in range(cols):
		for y in range(rows):
			var cell := Vector2i(x, y)
			if not _occupied(cell):
				free.append(cell)
	if free.is_empty():
		if players() == 1:
			game_over = true
		return
	foods.append(free.pick_random())

## Queues a turn for the coming steps (up to MAX_TURNS ahead). Ignores a
## repeat of the direction it will already be going and a 180-degree
## reversal into its own neck. Returns true if the turn was taken.
func set_direction(i: int, d: int = -1) -> bool:
	# Old solo signature: set_direction(dir)
	if d == -1:
		d = i
		i = 0
	if i < 0 or i >= snakes.size():
		return false
	var s: Dictionary = snakes[i]
	if not s.has("turns"):
		s.turns = []
	if s.pending == s.dir:
		if d == s.dir or OPPOSITE[d] == s.dir:
			return false
		s.pending = d
		return true
	var last: int = s.turns.back() if not s.turns.is_empty() else s.pending
	if d == last or OPPOSITE[d] == last or s.turns.size() >= MAX_TURNS:
		return false
	s.turns.append(d)
	return true

## Advances one tick. Returns true if this step just ended the game.
func step() -> bool:
	if game_over:
		return false
	var heads: Array = []
	var eats: Array = []
	for s in snakes:
		if not s.alive:
			heads.append(Vector2i(-99, -99))
			eats.append(false)
			continue
		s.dir = s.pending
		if not s.get("turns", []).is_empty():
			s.pending = s.turns.pop_front()
		var h: Vector2i = s.body[0] + DELTA[s.dir]
		heads.append(h)
		eats.append(foods.has(h))
	# Who dies this tick (decided before anyone moves).
	var dies: Array = []
	for i in snakes.size():
		var s: Dictionary = snakes[i]
		if not s.alive:
			dies.append(false)
			continue
		var h: Vector2i = heads[i]
		var dead := h.x < 0 or h.x >= cols or h.y < 0 or h.y >= rows
		for j in snakes.size():
			if dead:
				break
			var o: Dictionary = snakes[j]
			if not o.alive:
				continue
			# A tail that moves away this tick is free to enter.
			var body: Array = o.body if eats[j] else o.body.slice(0, o.body.size() - 1)
			if body.has(h):
				dead = true
			elif j != i and (heads[j] == h or (heads[j] == s.body[0] and h == o.body[0])):
				dead = true  # head-on
		dies.append(dead)
	for i in snakes.size():
		var s: Dictionary = snakes[i]
		if not s.alive:
			continue
		if dies[i]:
			s.alive = false
			continue
		s.body.insert(0, heads[i])
		if eats[i]:
			s.score += 1
			foods.erase(heads[i])
			_spawn_food()
		else:
			s.body.pop_back()
	var alive := []
	for i in snakes.size():
		if snakes[i].alive:
			alive.append(i)
	if players() == 1:
		if alive.is_empty():
			game_over = true
	elif alive.size() <= 1:
		game_over = true
		winner = alive[0] if alive.size() == 1 else -1
	return game_over

# ---------- computer opponent ----------

## A cautious greedy snake: never steps into certain death, prefers moves
## that keep plenty of room (flood fill), then heads for the nearest food.
func ai_direction(i: int) -> int:
	var s: Dictionary = snakes[i]
	var best_dir: int = s.dir
	var best_score := -INF
	for d in [Dir.UP, Dir.DOWN, Dir.LEFT, Dir.RIGHT]:
		if OPPOSITE[d] == s.dir:
			continue
		var h: Vector2i = s.body[0] + DELTA[d]
		if not _cell_free(h):
			continue
		var room := _room(h, s.body.size() * 2 + 10)
		var near := 999
		for f in foods:
			near = mini(near, absi(f.x - h.x) + absi(f.y - h.y))
		var danger := 0.0
		for j in snakes.size():  # don't go nose to nose
			if j != i and snakes[j].alive:
				var oh: Vector2i = snakes[j].body[0]
				if absi(oh.x - h.x) + absi(oh.y - h.y) <= 1:
					danger += 40.0
		var score_d: float = minf(room, s.body.size() * 2 + 10) * 3.0 - near - danger + randf() * 0.5
		if score_d > best_score:
			best_score = score_d
			best_dir = d
	return best_dir

func _cell_free(c: Vector2i) -> bool:
	if c.x < 0 or c.x >= cols or c.y < 0 or c.y >= rows:
		return false
	for o in snakes:
		if o.alive and o.body.slice(0, o.body.size() - 1).has(c):
			return false
	return true

func _room(start: Vector2i, limit: int) -> int:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty() and seen.size() < limit:
		var c: Vector2i = queue.pop_front()
		for d in DELTA.values():
			var n: Vector2i = c + d
			if not seen.has(n) and _cell_free(n):
				seen[n] = true
				queue.append(n)
	return seen.size()

# ---------- online sync ----------

func to_dict() -> Dictionary:
	var ss := []
	for s in snakes:
		var b := []
		for c in s.body:
			b.append([c.x, c.y])
		ss.append({"b": b, "d": s.dir, "p": s.pending, "a": s.alive, "s": s.score})
	var fs := []
	for f in foods:
		fs.append([f.x, f.y])
	return {"cols": cols, "rows": rows, "snakes": ss, "foods": fs, "over": game_over, "winner": winner}

func from_dict(d: Dictionary) -> void:
	cols = int(d.get("cols", 15))
	rows = int(d.get("rows", 15))
	snakes.clear()
	for s in d.get("snakes", []):
		var body := []
		for c in s.b:
			body.append(Vector2i(int(c[0]), int(c[1])))
		snakes.append({"body": body, "dir": int(s.d), "pending": int(s.p), "turns": [], "alive": bool(s.a), "score": int(s.s)})
	foods.clear()
	for f in d.get("foods", []):
		foods.append(Vector2i(int(f[0]), int(f[1])))
	game_over = bool(d.get("over", false))
	winner = int(d.get("winner", -1))
