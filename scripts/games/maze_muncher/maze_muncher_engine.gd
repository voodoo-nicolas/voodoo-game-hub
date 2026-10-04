extends RefCounted

## Maze Muncher: eat every dot in the maze while four ghosts hunt you. A
## power dot turns the ghosts blue for a few seconds -- then you can eat
## them. Pure simulation on a tile grid (no Nodes), stepped by the game.
## Positions are in tiles; an actor moves from one tile centre to the next.

const MAZE := [
	"###################",
	"#........#........#",
	"#o##.###.#.###.##o#",
	"#.................#",
	"#.##.#.#####.#.##.#",
	"#....#...#...#....#",
	"####.### # ###.####",
	"   #.#       #.#   ",
	"####.# ##-## #.####",
	"    .  #GGG#  .    ",
	"####.# ##### #.####",
	"   #.#       #.#   ",
	"####.# ##### #.####",
	"#........#........#",
	"#.##.###.#.###.##.#",
	"#o.#.....P.....#.o#",
	"##.#.#.#####.#.#.##",
	"#....#...#...#....#",
	"#.######.#.######.#",
	"#.................#",
	"###################",
]
const W := 19
const H := 21
const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]  # up, left, down, right (tie order)
const DOOR := Vector2i(9, 8)
const HOUSE := Vector2i(9, 9)
const OUTSIDE := Vector2i(9, 7)
const CORNERS := [Vector2i(17, 0), Vector2i(1, 0), Vector2i(17, 20), Vector2i(1, 20)]
const PELLET := 10
const POWER := 50
const GHOST_BASE := 200
const RELEASE := [0.0, 2.5, 6.0, 10.0]
## Seconds of scatter / chase, repeating (chase forever at the end).
const PHASES := [7.0, 20.0, 7.0, 20.0, 5.0, 20.0, 5.0]

var dots: Dictionary = {}   # Vector2i -> 1 pellet, 2 power
var level: int = 1
var score: int = 0
var lives: int = 3
var over := false
var player: Dictionary = {}
var want := Vector2i.ZERO
var ghosts: Array = []
var fright: float = 0.0
var ghost_combo: int = 0
var phase_i: int = 0
var phase_t: float = 0.0
var since_start: float = 0.0
var dying: float = 0.0
var rng := RandomNumberGenerator.new()

func reset(seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	level = 1
	score = 0
	lives = 3
	over = false
	_fill_dots()
	_place_actors()

func next_level() -> void:
	level += 1
	_fill_dots()
	_place_actors()

func _fill_dots() -> void:
	dots = {}
	for y in H:
		for x in W:
			var ch: String = MAZE[y][x]
			if ch == ".":
				dots[Vector2i(x, y)] = 1
			elif ch == "o":
				dots[Vector2i(x, y)] = 2

func _place_actors() -> void:
	player = {"t": Vector2i(9, 15), "p": Vector2(9, 15), "d": Vector2i(-1, 0), "next": Vector2i(9, 15)}
	want = Vector2i(-1, 0)
	ghosts = []
	for i in 4:
		var start: Vector2i = OUTSIDE if i == 0 else Vector2i(8 + (i - 1), 9)
		ghosts.append({"t": start, "p": Vector2(start), "d": Vector2i(-1, 0), "next": start, "id": i,
			"home": i != 0, "eaten": false, "release": RELEASE[i]})
	fright = 0.0
	ghost_combo = 0
	phase_i = 0
	phase_t = 0.0
	since_start = 0.0
	dying = 0.0

func wall(t: Vector2i) -> bool:
	if t.y < 0 or t.y >= H:
		return true
	if t.x < 0 or t.x >= W:
		return t.y != 9  # the tunnel row wraps
	var ch: String = MAZE[t.y][t.x]
	return ch == "#"

func _wrap(t: Vector2i) -> Vector2i:
	return Vector2i(posmod(t.x, W), t.y)

## Can this actor enter tile t? Only ghosts use the door.
func _open(t: Vector2i, ghost: bool, may_door: bool) -> bool:
	t = _wrap(t)
	if wall(t):
		return false
	var ch: String = MAZE[t.y][t.x]
	if ch == "-" or ch == "G":
		return ghost and may_door
	return true

func scatter() -> bool:
	return phase_i < PHASES.size() and phase_i % 2 == 0

func player_speed() -> float:
	return 6.6 + 0.25 * mini(level - 1, 4)

func ghost_speed(g: Dictionary) -> float:
	if g.eaten:
		return 14.0
	if fright > 0.0:
		return 3.8
	if g.t.y == 9 and (g.t.x < 4 or g.t.x > 14):
		return 3.5  # slow in the tunnel
	return 6.0 + 0.3 * mini(level - 1, 5)

func fright_time() -> float:
	return maxf(2.0, 7.0 - (level - 1) * 0.8)

## One frame. Events: ["dot"], ["power"], ["ghost", points], ["die"], ["level"], ["over"].
func step(dt: float) -> Array:
	var ev: Array = []
	if over:
		return ev
	if dying > 0.0:
		dying -= dt
		if dying <= 0.0:
			if lives <= 0:
				over = true
				ev.append(["over"])
			else:
				var keep := dots
				_place_actors()
				dots = keep
		return ev
	since_start += dt
	if fright > 0.0:
		fright = maxf(0.0, fright - dt)
	else:
		phase_t += dt
		if phase_i < PHASES.size() and phase_t >= PHASES[phase_i]:
			phase_t = 0.0
			phase_i += 1
			for g in ghosts:
				if not g.home and not g.eaten:
					g.d = -g.d  # ghosts turn round when the mode changes
	_move_player(dt, ev)
	for g in ghosts:
		_move_ghost(g, dt)
	_collide(ev)
	if dots.is_empty():
		ev.append(["level"])
		next_level()
	return ev

func _move_player(dt: float, ev: Array) -> void:
	var p := player
	if want == -p.d and p.next != p.t:
		# Reversing is allowed anywhere, not just at a tile centre.
		var back: Vector2i = p.next - p.d
		p.d = want
		p.t = _wrap(p.next)
		p.next = back
	var dist := player_speed() * dt
	while dist > 0.0:
		var target := Vector2(p.next)
		var to: Vector2 = target - p.p
		if to.length() > dist:
			p.p += to.normalized() * dist
			break
		dist -= to.length()
		p.p = target
		p.t = _wrap(p.next)
		if p.t != p.next:
			p.p = Vector2(p.t)
		var d = dots.get(p.t, 0)
		if d > 0:
			dots.erase(p.t)
			if d == 2:
				score += POWER
				fright = fright_time()
				ghost_combo = 0
				for g in ghosts:
					if not g.home and not g.eaten:
						g.d = -g.d
				ev.append(["power"])
			else:
				score += PELLET
				ev.append(["dot"])
		# At a tile centre: turn if the wanted way is open, else carry on, else stop.
		if _open(p.t + want, false, false):
			p.d = want
		if _open(p.t + p.d, false, false):
			p.next = p.t + p.d
		else:
			p.next = p.t
			break

func _move_ghost(g: Dictionary, dt: float) -> void:
	if g.home:
		if since_start >= g.release and fright <= 0.0:
			# Leave the house: straight up through the door.
			g.home = false
			g.t = OUTSIDE
			g.p = Vector2(OUTSIDE)
			g.next = OUTSIDE
			g.d = Vector2i(-1, 0)
		return
	var dist := ghost_speed(g) * dt
	while dist > 0.0:
		var to: Vector2 = Vector2(g.next) - g.p
		if to.length() > dist:
			g.p += to.normalized() * dist
			break
		dist -= to.length()
		g.p = Vector2(g.next)
		g.t = _wrap(g.next)
		if g.t != g.next:
			g.p = Vector2(g.t)
		if g.eaten and g.t == OUTSIDE:
			# Eyes reached the house: back to normal.
			g.eaten = false
		g.d = _choose(g)
		g.next = g.t + g.d

func _choose(g: Dictionary) -> Vector2i:
	var options: Array = []
	for d in DIRS:
		if d == -g.d:
			continue
		if _open(g.t + d, true, false):
			options.append(d)
	if options.is_empty():
		return -g.d
	if fright > 0.0 and not g.eaten:
		return options[rng.randi_range(0, options.size() - 1)]
	var target := _target(g)
	var best: Vector2i = options[0]
	var best_d := INF
	for d in options:
		var t: Vector2i = g.t + d
		var dd := Vector2(t - target).length_squared()
		if dd < best_d:
			best_d = dd
			best = d
	return best

func _target(g: Dictionary) -> Vector2i:
	if g.eaten:
		return OUTSIDE
	if scatter():
		return CORNERS[g.id]
	var pt: Vector2i = player.t
	var pd: Vector2i = player.d
	match g.id:
		0:
			return pt
		1:
			return pt + pd * 4
		2:
			var ahead: Vector2i = pt + pd * 2
			return ahead * 2 - ghosts[0].t
		_:
			if Vector2(pt - g.t).length() > 8.0:
				return pt
			return CORNERS[3]

func _collide(ev: Array) -> void:
	for g in ghosts:
		if g.home or g.eaten:
			continue
		if g.p.distance_to(player.p) < 0.7:
			if fright > 0.0:
				g.eaten = true
				ghost_combo += 1
				var pts := GHOST_BASE * int(pow(2, ghost_combo - 1))
				score += pts
				ev.append(["ghost", pts])
			else:
				lives -= 1
				dying = 1.6
				ev.append(["die"])
				return
