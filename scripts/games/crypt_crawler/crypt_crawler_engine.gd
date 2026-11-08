extends RefCounted

## Crypt Crawler: a first-person crawl through a maze of crypts. Find the
## glowing exit on each floor while skulls and wraiths hunt you; your wand
## blasts whatever is in front of you. Pure logic in grid units (one cell =
## 1.0): the map, movement with wall sliding, the monsters, and the DDA ray
## caster the game draws its 3D view with.

const FOV_PLANE := 0.66       # camera plane length: ~66° field of view
const RADIUS := 0.22          # player / monster size against walls
const MOVE := 2.6             # cells per second
const TURN := 2.6             # radians per second
const FIRE_COOLDOWN := 0.32
const MAX_HP := 100
const SEE := 11.0             # how far monsters notice you
## Easy / Normal / Hard: monster damage and numbers.
const DIFFS := [
	{"dmg": 0.6, "count": 0.7, "speed": 0.8},
	{"dmg": 1.0, "count": 1.0, "speed": 1.0},
	{"dmg": 1.4, "count": 1.3, "speed": 1.15},
]
## kind -> hp, speed (cells/s), score, dmg (a bite / blow; 0 = shoots instead)
const MONSTERS := {
	"skull": {"hp": 2, "speed": 1.9, "score": 100, "dmg": 9},
	"wraith": {"hp": 3, "speed": 1.3, "score": 200, "dmg": 0},
	"brute": {"hp": 6, "speed": 1.1, "score": 400, "dmg": 18},
	"rat": {"hp": 1, "speed": 2.3, "score": 50, "dmg": 4},        # comes in packs of three
	"bat": {"hp": 1, "speed": 2.9, "score": 75, "dmg": 5},        # zigzags, hard to line up
	"skeleton": {"hp": 4, "speed": 1.45, "score": 250, "dmg": 14},
	"specter": {"hp": 3, "speed": 0.9, "score": 300, "dmg": 12},  # drifts through walls
	"gargoyle": {"hp": 8, "speed": 1.7, "score": 500, "dmg": 22}, # a statue until you get close
	"monk": {"hp": 5, "speed": 1.0, "score": 450, "dmg": 0},      # keeps away, calls up bats
}
## Which monsters a floor can have: [kind, first floor, weight].
const SPAWN := [
	["skull", 1, 10], ["rat", 1, 5], ["bat", 2, 6], ["wraith", 2, 6], ["skeleton", 3, 7],
	["brute", 3, 3], ["specter", 4, 4], ["gargoyle", 5, 3], ["monk", 6, 2],
]
const MAX_MONSTERS := 48      # summoned bats stop at this
const GARGOYLE_WAKE := 2.4    # a gargoyle stays stone until you are this close (or shoot it)
const DECOR := ["skull_pile", "candelabra", "tomb", "web", "chains"]

var diff: int = 1
var level: int = 1
var score: int = 0
var kills: int = 0
var hp: int = MAX_HP
var state := "play"           # play, dead, won, over

var size: int = 15
var grid: PackedByteArray = PackedByteArray()   # 1 = wall
var seen: PackedByteArray = PackedByteArray()   # for the map
var pos := Vector2(1.5, 1.5)
var angle: float = 0.0
var exit_cell := Vector2i(1, 1)
var monsters: Array = []      # {"pos", "kind", "hp", "cool", "hurt", "bob"}
var items: Array = []         # {"pos", "kind": "health" | "gem"}
var bolts: Array = []         # monster fireballs: {"pos", "vel"}
var decor: Array = []         # props, only drawn: {"pos", "kind"}
var fire_cool: float = 0.0
var hurt_t: float = 0.0       # red flash when hit
var level_kills: int = 0
var rng := RandomNumberGenerator.new()

func reset(p_diff: int = 1, seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	diff = clampi(p_diff, 0, DIFFS.size() - 1)
	level = 1
	score = 0
	kills = 0
	hp = MAX_HP
	new_level()

func dir() -> Vector2:
	return Vector2(cos(angle), sin(angle))

func plane() -> Vector2:
	return Vector2(-sin(angle), cos(angle)) * FOV_PLANE

func is_wall(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= size or y >= size:
		return true
	return grid[y * size + x] == 1

# ---------- the level ----------

func new_level() -> void:
	size = mini(15 + (level - 1) * 2, 27)
	grid = PackedByteArray()
	grid.resize(size * size)
	grid.fill(1)
	seen = PackedByteArray()
	seen.resize(size * size)
	# A maze carved on the odd cells (recursive backtracker)...
	var stack: Array = [Vector2i(1, 1)]
	_open(1, 1)
	while not stack.is_empty():
		var c: Vector2i = stack[stack.size() - 1]
		var nbrs: Array = []
		for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var n: Vector2i = c + d
			if n.x > 0 and n.y > 0 and n.x < size - 1 and n.y < size - 1 and is_wall(n.x, n.y):
				nbrs.append(n)
		if nbrs.is_empty():
			stack.pop_back()
			continue
		var n: Vector2i = nbrs[rng.randi_range(0, nbrs.size() - 1)]
		_open((c.x + n.x) / 2, (c.y + n.y) / 2)
		_open(n.x, n.y)
		stack.append(n)
	# ...with some walls knocked through for loops, and a few halls.
	for i in size * size / 12:
		var x := rng.randi_range(1, size - 2)
		var y := rng.randi_range(1, size - 2)
		if is_wall(x, y) and ((not is_wall(x - 1, y) and not is_wall(x + 1, y)) or (not is_wall(x, y - 1) and not is_wall(x, y + 1))):
			_open(x, y)
	for i in 2 + level / 2:
		var cx := rng.randi_range(2, size - 4)
		var cy := rng.randi_range(2, size - 4)
		for y in range(cy, cy + 3):
			for x in range(cx, cx + 3):
				if x < size - 1 and y < size - 1:
					_open(x, y)
	# Start in a corner, the exit at the farthest reachable cell.
	pos = Vector2(1.5, 1.5)
	angle = 0.0 if not is_wall(2, 1) else PI / 2.0
	var dist := _distances(Vector2i(1, 1))
	var far := 0
	for i in dist.size():
		if dist[i] > dist[far]:
			far = i
	exit_cell = Vector2i(far % size, far / size)
	# Monsters and items on free cells away from the start.
	monsters = []
	items = []
	bolts = []
	decor = []
	var free: Array = []
	for i in dist.size():
		if dist[i] >= 6 and i != far:
			free.append(i)
	_shuffle(free)
	var d: Dictionary = DIFFS[diff]
	var n_mon := int(roundf((4 + level * 2) * d.count))
	for i in mini(n_mon, free.size()):
		var cell: int = free.pop_back()
		var kind := pick_kind()
		if kind == "rat":
			for k in 3:
				_add_monster("rat", _center(cell) + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25)))
		else:
			_add_monster(kind, _center(cell))
	for i in mini(2 + level / 2, free.size()):
		items.append({"pos": _center(free.pop_back()), "kind": "health"})
	for i in mini(4 + level, free.size()):
		items.append({"pos": _center(free.pop_back()), "kind": "gem"})
	for i in mini(3 + level, free.size()):
		decor.append({"pos": _center(free.pop_back()), "kind": DECOR[rng.randi_range(0, DECOR.size() - 1)]})
	level_kills = 0
	state = "play"
	_mark_seen()

## A monster kind for this floor, by the SPAWN weights.
func pick_kind() -> String:
	var total := 0
	for row in SPAWN:
		if level >= int(row[1]):
			total += int(row[2])
	var r := rng.randi_range(1, total)
	for row in SPAWN:
		if level >= int(row[1]):
			r -= int(row[2])
			if r <= 0:
				return str(row[0])
	return "skull"

func _add_monster(kind: String, p: Vector2) -> void:
	monsters.append({"pos": p, "kind": kind, "hp": MONSTERS[kind].hp, "cool": rng.randf_range(0.5, 2.0),
		"hurt": 0.0, "bob": rng.randf() * TAU, "awake": false})

func _open(x: int, y: int) -> void:
	grid[y * size + x] = 0

func _center(cell: int) -> Vector2:
	return Vector2(cell % size + 0.5, cell / size + 0.5)

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## Steps from a cell to every cell (-1 = walls / unreachable).
func _distances(from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(size * size)
	dist.fill(-1)
	dist[from.y * size + from.x] = 0
	var q: Array = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not is_wall(n.x, n.y) and dist[n.y * size + n.x] < 0:
				dist[n.y * size + n.x] = dist[c.y * size + c.x] + 1
				q.append(n)
	return dist

func _mark_seen() -> void:
	var cx := int(pos.x)
	var cy := int(pos.y)
	for y in range(cy - 2, cy + 3):
		for x in range(cx - 2, cx + 3):
			if x >= 0 and y >= 0 and x < size and y < size:
				seen[y * size + x] = 1

# ---------- rays ----------

## DDA ray from p along d: {"dist" (perpendicular), "side" (0 = x face,
## 1 = y face), "cell": Vector2i, "u" (0..1 along the face)}.
func cast(p: Vector2, d: Vector2, max_dist: float = 64.0) -> Dictionary:
	var mx := int(p.x)
	var my := int(p.y)
	var ddx := 1e30 if d.x == 0.0 else absf(1.0 / d.x)
	var ddy := 1e30 if d.y == 0.0 else absf(1.0 / d.y)
	var sx := 1 if d.x >= 0.0 else -1
	var sy := 1 if d.y >= 0.0 else -1
	var side_x := ((mx + 1.0 - p.x) if d.x >= 0.0 else (p.x - mx)) * ddx
	var side_y := ((my + 1.0 - p.y) if d.y >= 0.0 else (p.y - my)) * ddy
	var side := 0
	for i in 200:
		if side_x < side_y:
			side_x += ddx
			mx += sx
			side = 0
		else:
			side_y += ddy
			my += sy
			side = 1
		if is_wall(mx, my):
			break
		if minf(side_x, side_y) > max_dist:
			return {"dist": max_dist, "side": 0, "cell": Vector2i(-1, -1), "u": 0.0}
	var dist := (side_x - ddx) if side == 0 else (side_y - ddy)
	var hit := p + d * dist
	var u := hit.y - floorf(hit.y) if side == 0 else hit.x - floorf(hit.x)
	return {"dist": maxf(dist, 0.0001), "side": side, "cell": Vector2i(mx, my), "u": u}

func line_of_sight(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return true
	return cast(a, d / l, l + 1.0).dist >= l

# ---------- one frame ----------

## fwd / strafe: -1..1, turn: radians to turn this frame (already scaled),
## fire: pressed. Returns events: "fire", "kill", "hit_monster", "hurt",
## "health", "gem", "exit", "dead", "bolt".
func step(dt: float, fwd: float, strafe: float, turn: float, fire: bool) -> Array:
	var ev: Array = []
	if state != "play":
		return ev
	angle = wrapf(angle + turn, -PI, PI)
	var mv := (dir() * fwd + Vector2(-sin(angle), cos(angle)) * strafe)
	if mv.length() > 1.0:
		mv = mv.normalized()
	pos = _slide(pos, mv * MOVE * dt)
	_mark_seen()
	hurt_t = maxf(0.0, hurt_t - dt)
	fire_cool = maxf(0.0, fire_cool - dt)
	if fire and fire_cool <= 0.0:
		fire_cool = FIRE_COOLDOWN
		ev.append("fire")
		_shoot(ev)
	for it in items.duplicate():
		if pos.distance_to(it.pos) < 0.5:
			items.erase(it)
			if it.kind == "health":
				hp = mini(MAX_HP, hp + 30)
				ev.append("health")
			else:
				score += 50
				ev.append("gem")
	_step_monsters(dt, ev)
	_step_bolts(dt, ev)
	if hp <= 0 and state == "play":
		state = "dead"
		ev.append("dead")
	elif Vector2i(int(pos.x), int(pos.y)) == exit_cell and state == "play":
		state = "won"
		score += 500 + level * 100
		ev.append("exit")
	return ev

## Move with wall sliding (each axis on its own).
func _slide(p: Vector2, d: Vector2) -> Vector2:
	var nx := p.x + d.x
	var r := RADIUS * signf(d.x) if d.x != 0.0 else 0.0
	if not is_wall(int(nx + r), int(p.y - RADIUS)) and not is_wall(int(nx + r), int(p.y + RADIUS)):
		p.x = nx
	var ny := p.y + d.y
	r = RADIUS * signf(d.y) if d.y != 0.0 else 0.0
	if not is_wall(int(p.x - RADIUS), int(ny + r)) and not is_wall(int(p.x + RADIUS), int(ny + r)):
		p.y = ny
	return p

## The wand hits the nearest monster near the middle of the view, if no
## wall is in between.
func _shoot(ev: Array) -> void:
	var best = null
	var best_d := INF
	var f := dir()
	for m in monsters:
		var to: Vector2 = m.pos - pos
		var d := to.length()
		var along := to.dot(f)
		if along <= 0.05:
			continue
		var off := absf(to.cross(f))
		if off > 0.35 + d * 0.04:
			continue
		if d < best_d and line_of_sight(pos, m.pos):
			best = m
			best_d = d
	if best == null:
		return
	best.hp -= 1
	best.hurt = 0.25
	best.awake = true
	if best.hp <= 0:
		monsters.erase(best)
		score += MONSTERS[best.kind].score
		kills += 1
		level_kills += 1
		ev.append("kill")
	else:
		ev.append("hit_monster")

func _step_monsters(dt: float, ev: Array) -> void:
	var d: Dictionary = DIFFS[diff]
	var callers: Array = []
	for m in monsters:
		m.hurt = maxf(0.0, m.hurt - dt)
		m.bob += dt * 3.0
		m.cool = maxf(0.0, m.cool - dt)
		var to: Vector2 = pos - m.pos
		var dist := maxf(to.length(), 0.001)
		if not m.awake:
			if m.kind == "gargoyle":
				if dist < GARGOYLE_WAKE:
					m.awake = true
					ev.append("wake")
				continue
			if dist < SEE and (m.kind == "specter" or line_of_sight(m.pos, pos)):
				m.awake = true
			else:
				continue
		# Specters see (and drift) through walls.
		var sees: bool = dist < SEE * 1.5 and (m.kind == "specter" or line_of_sight(m.pos, pos))
		var spd: float = MONSTERS[m.kind].speed * d.speed * (1.0 + 0.04 * (level - 1))
		var want := 0.55
		var back := 0.0
		if m.kind == "wraith":
			want = 3.5
			back = 2.5
		elif m.kind == "monk":
			want = 4.5
			back = 3.0
		var way: Vector2 = to / dist
		if m.kind == "bat":
			way = (way + Vector2(-way.y, way.x) * sin(m.bob * 2.5) * 0.9).normalized()
		if sees and dist > want:
			if m.kind == "specter":
				m.pos = (m.pos + way * spd * dt).clamp(Vector2(0.6, 0.6), Vector2(size - 0.6, size - 0.6))
			else:
				m.pos = _slide(m.pos, way * spd * dt)
		elif sees and back > 0.0 and dist < back:
			m.pos = _slide(m.pos, -way * spd * 0.6 * dt)
		# Keep monsters from stacking on one another.
		for o in monsters:
			if not is_same(o, m) and (o.pos as Vector2).distance_to(m.pos) < 0.45:
				m.pos = _slide(m.pos, ((m.pos as Vector2) - o.pos).normalized() * 0.5 * dt)
		if m.cool > 0.0:
			continue
		if m.kind == "wraith":
			if sees and dist < 9.0:
				m.cool = 2.2 / d.speed
				bolts.append({"pos": m.pos + to / dist * 0.3, "vel": to / dist * 4.2})
				ev.append("bolt")
		elif m.kind == "monk":
			if sees and dist < 9.0 and monsters.size() < MAX_MONSTERS:
				m.cool = 6.0 / d.speed
				callers.append(m)
				ev.append("summon")
		elif dist < 0.75:
			m.cool = 0.7 if m.kind in ["rat", "bat"] else 0.9
			_hurt(int(roundf(float(MONSTERS[m.kind].dmg) * d.dmg)), ev)
	# Two bats per call join after the loop (not while it walks the list).
	for caller in callers:
		for k in 2:
			var p: Vector2 = caller.pos + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
			if is_wall(int(p.x), int(p.y)):
				p = caller.pos
			_add_monster("bat", p)
			monsters[monsters.size() - 1].awake = true

func _step_bolts(dt: float, ev: Array) -> void:
	var keep: Array = []
	for b in bolts:
		b.pos += b.vel * dt
		if is_wall(int(b.pos.x), int(b.pos.y)):
			continue
		if (b.pos as Vector2).distance_to(pos) < 0.32:
			_hurt(int(roundf(12 * DIFFS[diff].dmg)), ev)
			continue
		keep.append(b)
	bolts = keep

func _hurt(n: int, ev: Array) -> void:
	hp = maxi(0, hp - n)
	hurt_t = 0.35
	ev.append("hurt")

## After the pause following a death or the exit.
func next() -> void:
	if state == "won":
		level += 1
		hp = mini(MAX_HP, hp + 25)
		new_level()
	elif state == "dead":
		state = "over"
