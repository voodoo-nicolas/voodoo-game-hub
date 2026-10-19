extends RefCounted

## Evolution (M1, eat and grow): a glowing cell in a dark pond. Eat food and
## smaller microbes to grow; bigger cells hunt you. Pure simulation in world
## units, stepped by the game. All tuning lives in TUNING (no magic numbers
## below it), so balance changes touch one place.

const TUNING := {
	"arena": 4200.0,            # square side, world units
	"start_mass": 10.0,
	"radius_k": 7.0,            # radius = radius_k * sqrt(mass)
	"eat_ratio": 1.15,          # eater needs mass >= victim mass * eat_ratio
	"absorb": 0.85,             # share of the victim's mass the eater gains
	"food_mass": 1.0,
	"food_count": 260,
	"microbe_count": 34,        # NPC cells, kept topped up
	"smaller_share": 0.55,      # of spawned NPCs: prey (smaller than you)
	"similar_share": 0.20,      # about your size (can't eat each other)
	"prey_range": [0.25, 0.8],  # x player mass
	"similar_range": [0.88, 1.1],
	"hunter_range": [1.3, 2.6],
	"min_npc_mass": 2.0,
	"spawn_clear": 900.0,       # NPCs spawn at least this far (screen units / zoom) from you
	"player_speed": 360.0,
	"speed_decay": 0.17,        # bigger = slower: speed / mass^decay
	"min_speed_frac": 0.35,
	"npc_speed_frac": 0.92,     # NPCs are a bit slower than you at equal mass
	"flee_speed_frac": 1.0,
	"sense": 520.0,             # NPC sight, x radius floor
	"accel": 7.0,               # velocity smoothing per second
	"mass_loss": 0.012,         # per second, fraction of mass above start
	"cam_base": 1.0,
	"cam_k": 0.045,             # zoom out per sqrt(mass) above start
	"cam_min": 0.25,
	"respawn_per_step": 3,
}

var rng := RandomNumberGenerator.new()
var player := {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "mass": 0.0}
var food: Array = []      # Vector2
var npcs: Array = []      # {"pos","vel","mass","wander":Vector2,"t":float}
var alive := true
var peak_mass: float = 0.0
var eaten_food: int = 0
var eaten_cells: int = 0
var time: float = 0.0

static func t(key: String):
	return TUNING[key]

static func radius_of(mass: float) -> float:
	return TUNING.radius_k * sqrt(maxf(mass, 0.0))

## The one rule: can `a_mass` eat `b_mass`?
static func can_eat(a_mass: float, b_mass: float) -> bool:
	return a_mass >= b_mass * TUNING.eat_ratio

## Mass after the eater swallows the victim.
static func grown_mass(eater: float, victim: float) -> float:
	return eater + victim * TUNING.absorb

## Top speed for a cell of this mass.
static func speed_for(mass: float, base: float = -1.0) -> float:
	if base < 0.0:
		base = TUNING.player_speed
	var m := maxf(mass / TUNING.start_mass, 1.0)
	return base * maxf(pow(m, -TUNING.speed_decay), TUNING.min_speed_frac)

## Camera zoom (smaller = further out) for the player's mass.
static func zoom_for(mass: float) -> float:
	var over := maxf(sqrt(mass) - sqrt(TUNING.start_mass), 0.0)
	return maxf(TUNING.cam_base / (1.0 + over * TUNING.cam_k), TUNING.cam_min)

func score() -> int:
	return int(peak_mass * 10.0)

func reset(seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	var a: float = t("arena")
	player = {"pos": Vector2(a, a) / 2.0, "vel": Vector2.ZERO, "mass": t("start_mass")}
	food.clear()
	npcs.clear()
	alive = true
	peak_mass = player.mass
	eaten_food = 0
	eaten_cells = 0
	time = 0.0
	for i in int(t("food_count")):
		food.append(_random_pos())
	for i in int(t("microbe_count")):
		npcs.append(_new_npc())

func _random_pos(away: bool = false) -> Vector2:
	var a: float = t("arena")
	for i in 20:
		var p := Vector2(rng.randf_range(0.0, a), rng.randf_range(0.0, a))
		if not away or p.distance_to(player.pos) >= t("spawn_clear") / zoom_for(player.mass):
			return p
	return Vector2(rng.randf_range(0.0, a), rng.randf_range(0.0, a))

func _new_npc() -> Dictionary:
	var pm: float = player.mass
	var roll := rng.randf()
	var rng_range: Array
	if roll < t("smaller_share"):
		rng_range = t("prey_range")
	elif roll < t("smaller_share") + t("similar_share"):
		rng_range = t("similar_range")
	else:
		rng_range = t("hunter_range")
	var m: float = maxf(pm * rng.randf_range(rng_range[0], rng_range[1]), t("min_npc_mass"))
	# Spawns off-screen, never on top of the player.
	return {"pos": _random_pos(true), "vel": Vector2.ZERO, "mass": m, "wander": Vector2.RIGHT.rotated(rng.randf() * TAU), "t": rng.randf_range(0.5, 3.0)}

## dir: desired heading, length 0..1 (joystick deflection).
func step(delta: float, dir: Vector2) -> void:
	if not alive:
		return
	time += delta
	var a: float = t("arena")
	# Player
	if dir.length() > 1.0:
		dir = dir.normalized()
	var want: Vector2 = dir * speed_for(player.mass)
	player.vel = player.vel.lerp(want, clampf(t("accel") * delta, 0.0, 1.0))
	player.pos = (player.pos + player.vel * delta).clamp(Vector2.ZERO, Vector2(a, a))
	var extra: float = player.mass - t("start_mass")
	if extra > 0.0:
		player.mass -= extra * t("mass_loss") * delta
	# NPC brains
	var sense_floor: float = t("sense")
	for n in npcs:
		n.t -= delta
		var steer := Vector2.ZERO
		var speed := speed_for(n.mass, t("player_speed") * t("npc_speed_frac"))
		var to_p: Vector2 = player.pos - n.pos
		var d := to_p.length()
		var sight := maxf(sense_floor, radius_of(n.mass) * 6.0)
		if d < sight and can_eat(n.mass, player.mass):
			steer = to_p / maxf(d, 0.001)                     # hunt
		elif d < sight and can_eat(player.mass, n.mass):
			steer = -to_p / maxf(d, 0.001)                    # flee
			speed = speed_for(n.mass, t("player_speed") * t("flee_speed_frac"))
		else:
			if n.t <= 0.0:
				n.wander = Vector2.RIGHT.rotated(rng.randf() * TAU)
				n.t = rng.randf_range(1.5, 4.0)
			steer = n.wander * 0.4
		# Bounce off the walls.
		if (n.pos.x < 40.0 and steer.x < 0.0) or (n.pos.x > a - 40.0 and steer.x > 0.0):
			steer.x = -steer.x
			n.wander.x = -n.wander.x
		if (n.pos.y < 40.0 and steer.y < 0.0) or (n.pos.y > a - 40.0 and steer.y > 0.0):
			steer.y = -steer.y
			n.wander.y = -n.wander.y
		n.vel = n.vel.lerp(steer * speed, clampf(t("accel") * delta, 0.0, 1.0))
		n.pos = (n.pos + n.vel * delta).clamp(Vector2.ZERO, Vector2(a, a))
	_resolve()
	_top_up()

## Eating on contact: the eater's centre must be inside the victim's rim
## (overlap by the victim's radius) so a graze doesn't swallow.
func _resolve() -> void:
	var pr := radius_of(player.mass)
	# Food
	var fr := radius_of(t("food_mass"))
	var keep: Array = []
	for f in food:
		if f.distance_to(player.pos) < pr + fr * 0.5:
			player.mass += t("food_mass")
			eaten_food += 1
		else:
			keep.append(f)
	food = keep
	# NPCs
	var left: Array = []
	for n in npcs:
		var d: float = n.pos.distance_to(player.pos)
		var nr := radius_of(n.mass)
		if can_eat(player.mass, n.mass) and d < pr - nr * 0.35:
			player.mass = grown_mass(player.mass, n.mass)
			eaten_cells += 1
			pr = radius_of(player.mass)
			continue
		if can_eat(n.mass, player.mass) and d < nr - pr * 0.35:
			alive = false
		left.append(n)
	npcs = left
	peak_mass = maxf(peak_mass, player.mass)

func _top_up() -> void:
	var made := 0
	while food.size() < int(t("food_count")) and made < int(t("respawn_per_step")):
		food.append(_random_pos())
		made += 1
	made = 0
	while npcs.size() < int(t("microbe_count")) and made < 1:
		npcs.append(_new_npc())
		made += 1
