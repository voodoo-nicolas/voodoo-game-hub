extends CharacterBody2D

## Walker: a plain infected person. Patrols, notices Nash by sight or noise, chases,
## flickers cyan just before attacking (the one allowed use of cyan), then hits.
## No hive-mind: every walker decides on its own. Placeholder art (shapes).
##
## Losing Nash (v0.3):
## - Nash breaks line of sight: the walker goes to where it last saw him, then searches.
## - Nash hides (locker) while the walker can NOT see him: it has lost the trail. It starts
##   searching at once, wandering off in random directions, and gives up after SEARCH_SECONDS.
## - Nash hides while the walker CAN see him: it saw where he went. It walks to the locker,
##   bangs on it and drags him out (the world does the damage).
## A "?" floats over a searching walker, a "!" flashes when it spots Nash.
##
## v0.4 kinds (same script, own numbers in LsEngine): "gary" (Gary at his party: tougher, tie and
## party hat), "brute" (the night cook: big, slow, hits hard, long cyan wind-up), "crawler" (on the
## floor: slow, low, hard to spot, short sight). Party guests wear hats ("hat": true in the data).
## Every hit tells the world (blood: on_enemy_hit).
##
## v0.5:
## - Hostile to EVERY living person, not just Nash: guards, barricade shooters and panicking
##   survivors too (world.humans()). It goes for the closest one it can see. People hiding
##   (cowering survivors, Nash in a locker) are not seen. Infected never attack infected.
## - "feed": true in the data: crouched over a body, eating. It only notices Nash very close
##   (FEED_SIGHT), on a noise, or when hit.
## - Coolant (Nash's thrown can): slowed to a crawl while the cold lasts (slow()).
## - Faster, tougher and a little harder-hitting (numbers in LsEngine and below).
## - People the infected kill get back up as walkers ("turned": the data carries their clothes).
## - `last_hit_by`: who hit it last (a weapon id = Nash, "guard" / "shooter" = not Nash's kill).

const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")
const A = preload("res://scripts/games/last_shift/last_shift_art.gd")
const Pather = preload("res://scripts/games/last_shift/last_shift_pather.gd")

enum S { PATROL, CHASE, SEARCH, WINDUP, RECOVER, STAGGER, SCRIPTED, IDLE, DORMANT, SHRIEK, DIG, FEED }

# v0.4: patrol 45, chase 95, runner 115.
const SPEED_PATROL := 55.0
const SPEED_CHASE := 115.0
const SPEED_RUNNER := 135.0     # Dwayne: fast, but Nash (150) can still outrun him
const SIGHT_RANGE := 210.0      # sees Nash this close, if no wall is in the way
const ATTACK_RANGE := 36.0      # starts the attack wind-up this close
const HIT_RANGE := 46.0         # the swing still lands if Nash is within this at the end
const WINDUP_SECONDS := 0.6     # cyan flicker = the warning
const RECOVER_SECONDS := 0.9
const STAGGER_SECONDS := 0.45
const SEARCH_SECONDS := 7.0     # how long a walker hunts around before it gives up
const SEARCH_STEP := Vector2(70.0, 190.0)   # each search leg goes this far (px, min..max)
const LOOK_SECONDS := Vector2(0.5, 1.2)     # pause at each search point, looking around
const DIG_SECONDS := 1.1        # banging on the locker before it drags Nash out
const RUNNER_WINDUP := 0.55
const WAKE_DISTANCE := 70.0     # a sleeping runner wakes when Nash gets this close
const SPOT_FLASH := 0.8         # the "!" shows this long
const FEED_SIGHT := 85.0        # v0.5: a feeding walker only sees someone this close
const PREY_CHECK := 0.25        # v0.5: how often it looks around for someone to go after (s)

const SKIN := Color("8a9a78")
const SHIRT := Color("6b5a4a")
const CYAN := Color("29e6ff")   # infected glow only (art rule)
const FROST := Color(0.82, 0.9, 1.0)   # coolant: a pale frost tint (white-blue, never cyan)

var id := ""
## "walker", "screamer" or "runner" (sets hit points and damage, see last_shift_engine.gd).
var kind := "walker"
var world: Node = null
var nash: Node2D = null
var state: int = S.PATROL
var hp := 4
var is_runner := false
var is_screamer := false
var is_crawler := false
var is_brute := false
## Who hit it last: a weapon id ("wrench", "pistol"...) when it was Nash, else "guard" / "shooter".
var last_hit_by := ""
var _hat := false
var _scale := 1.0
var _speed_chase := SPEED_CHASE
var _windup := WINDUP_SECONDS
var _sight := SIGHT_RANGE
var patrol: Array[Vector2] = []
var _wp := 0
var _timer := 0.0
var _last_known := Vector2.ZERO
var _search_goal := Vector2.ZERO
var _look := 0.0                # >0 while standing at a search point looking around
var _dig_target: Node2D = null # the locker it saw Nash climb into
var _spot := 0.0                # "!" timer
var _push := Vector2.ZERO       # knockback velocity
var _facing := Vector2.DOWN
var _phase := 0.0
var _pather: RefCounted = null
var _t := 0.0
## v0.5: who it is after (Nash or another person), and whether the hunt is for Nash (only then
## does it count as "hunting" for Nash's health regen and for hiding in lockers).
var _prey: Node2D = null
var _after_nash := false
var _prey_t := 0.0
var _feed_at := Vector2.ZERO    # the body it is eating
var _slow_t := 0.0              # coolant: seconds left
var _slow := 1.0                # coolant: speed multiplier while it lasts
var _shirt := Color(0, 0, 0, 0) # turned people keep their clothes

func setup(data: Dictionary, world_node: Node, nash_node: Node2D) -> void:
	id = data.id
	world = world_node
	nash = nash_node
	position = (Vector2(data.cell) + Vector2(0.5, 0.5)) * 32.0
	if data.has("pos"):
		position = Vector2(data.pos)
	kind = data.get("kind", "walker")
	hp = LsEngine.ENEMY_HP[kind]
	if kind == "screamer":
		# Screamer: fragile, slow, but when it notices Nash it shrieks and every infected in
		# the room comes to look (the world does that part). No hive-mind: it is just loud.
		is_screamer = true
		_speed_chase = 85.0     # v0.4: 70
		_sight = SIGHT_RANGE - 30.0
	if kind == "runner":
		is_runner = true
		_speed_chase = SPEED_RUNNER
		_windup = RUNNER_WINDUP
		_sight = SIGHT_RANGE + 50.0
		if data.get("dormant", false):
			state = S.DORMANT
	if kind == "brute":
		is_brute = true
		_speed_chase = 86.0     # v0.4: 72
		_windup = 0.95          # a long, clear warning: get out of the way
		_scale = 1.3
	if kind == "crawler":
		is_crawler = true
		_speed_chase = 72.0     # v0.4: 62
		_sight = 130.0
	if kind == "gary":
		_speed_chase = 122.0    # v0.4: 100
		_hat = true
	_hat = _hat or data.get("hat", false)
	if data.has("shirt"):
		_shirt = Color(str(data.shirt))
	if data.get("feed", false):
		state = S.FEED
		var on: Vector2i = data.get("feed_on", data.cell)
		_feed_at = (Vector2(on) + Vector2(0.5, 0.5)) * 32.0
	patrol.clear()
	for c in data.get("patrol", []):
		patrol.append((Vector2(c) + Vector2(0.5, 0.5)) * 32.0)
	if patrol.is_empty():
		patrol.append(position)
	_prey_t = randf() * PREY_CHECK    # spread the look-arounds over the frames

func _ready() -> void:
	_pather = Pather.new(world)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	add_child(shape)

## Cutscenes move the walker themselves (a tween); the AI stays out of the way.
func set_scripted(on: bool) -> void:
	state = S.SCRIPTED if on else S.PATROL

## Stand still for a bit, then go back to patrolling.
func idle(secs: float) -> void:
	state = S.IDLE
	_timer = secs

## Has it noticed Nash? (A knife on an infected that hasn't is a silent takedown.)
## v0.5: one busy with somebody else hasn't noticed Nash either.
func is_aware() -> bool:
	if state in [S.PATROL, S.IDLE, S.SEARCH, S.DORMANT, S.SCRIPTED, S.FEED]:
		return false
	return _after_nash

## Is it after Nash right now (chasing, attacking, searching)? Nash's health only ticks back
## when nobody is.
func is_hunting() -> bool:
	return _after_nash and state in [S.CHASE, S.WINDUP, S.RECOVER, S.STAGGER, S.SHRIEK, S.SEARCH, S.DIG]

## Is it chasing / biting somebody who is not Nash? (The world: "guards have bigger problems".)
func is_after_someone_else() -> bool:
	return not _after_nash and _prey != null and state in [S.CHASE, S.WINDUP, S.RECOVER]

## Heard something at `pos` (a swing, a gunshot, a shriek): go and look, unless busy.
func investigate(pos: Vector2) -> void:
	if state == S.PATROL or state == S.IDLE or state == S.SEARCH or state == S.FEED:
		_after_nash = true
		_begin_search(pos, true)

## Nash hid somewhere this walker didn't see: the trail is lost. Search in a random direction.
func lose_trail() -> void:
	if _after_nash and state in [S.CHASE, S.WINDUP, S.RECOVER, S.STAGGER, S.SEARCH]:
		_begin_search(position, false)

## Nash climbed into `locker` right in front of this walker: go and get him.
func saw_hide(locker: Node2D) -> void:
	if _after_nash and state in [S.CHASE, S.WINDUP, S.RECOVER, S.STAGGER, S.SEARCH]:
		_dig_target = locker
		state = S.DIG
		_timer = DIG_SECONDS

## A sleeping runner jumps up and goes straight for Nash.
func wake() -> void:
	if state == S.DORMANT:
		state = S.CHASE
		_prey = nash
		_after_nash = true
		_spot = SPOT_FLASH
		world.on_runner_woke(self)

## Coolant cloud: moves at `factor` of its speed for `secs` seconds.
func slow(factor: float, secs: float) -> void:
	_slow = factor
	_slow_t = maxf(_slow_t, secs)

func is_slowed() -> bool:
	return _slow_t > 0.0

## Pistol shot. Always hurts; short stagger. `by` = "pistol" (Nash) or "shooter".
func shot(from_pos: Vector2, by: String = "pistol") -> void:
	if state == S.DORMANT:
		wake()
	last_hit_by = by
	hp -= int(LsEngine.WEAPONS.pistol.damage)
	world.on_enemy_hit(self, from_pos)
	if hp <= 0:
		world.on_walker_killed(self)
		return
	state = S.STAGGER
	_timer = 0.3    # a shot staggers him: time for the next one
	_push = (position - from_pos).normalized() * (60.0 if is_brute else 140.0)

## Melee hit for `dmg` (the world works it out per weapon). The runner shrugs melee off.
## `by` = Nash's weapon, or "guard" (a guard's baton).
func hit(from_pos: Vector2, dmg: int = 2, push: float = 240.0, by: String = "") -> void:
	if is_runner and by != "guard":
		if state == S.DORMANT:
			wake()
		world.on_wrench_useless()
		return
	last_hit_by = by
	hp -= dmg
	world.on_enemy_hit(self, from_pos)
	if hp <= 0:
		world.on_walker_killed(self)
		return
	state = S.STAGGER
	_timer = STAGGER_SECONDS * (0.5 if is_brute else 1.0)
	_push = (position - from_pos).normalized() * push * (0.3 if is_brute else 1.0)
	_last_known = from_pos
	# hit from behind by Nash while busy with someone else: now it is after Nash
	if by != "guard" and by != "shooter":
		_after_nash = true
		_prey = nash

func _physics_process(delta: float) -> void:
	z_index = int(position.y) + 14
	_spot = maxf(0.0, _spot - delta)
	_slow_t = maxf(0.0, _slow_t - delta)
	if state == S.SCRIPTED:
		return
	_prey_t -= delta
	var sees := _sees_nash()
	match state:
		S.SHRIEK:
			velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				world.on_screamer_shriek(self)
				state = S.CHASE
		S.DORMANT:
			velocity = Vector2.ZERO
			if not nash.in_locker and position.distance_to(nash.position) < WAKE_DISTANCE:
				wake()
		S.FEED:
			# crouched over the body, eating; only someone right next to it gets noticed
			velocity = Vector2.ZERO
			var d := _feed_at - position
			if d.length() > 1.0:
				_facing = Vector2(LsEngine.facing_to_vector(LsEngine.facing_from_vector(d, LsEngine.Facing.DOWN)))
			var close := _pick_prey(FEED_SIGHT)
			if close != null:
				_start_chase(close)
		S.PATROL:
			var p := _pick_prey(_sight) if _prey_t <= 0.0 else (nash if sees else null)
			if p != null:
				_start_chase(p)
			else:
				_walk_to(patrol[_wp], SPEED_PATROL)
				if position.distance_to(patrol[_wp]) < 8.0:
					_wp = (_wp + 1) % patrol.size()
		S.IDLE:
			velocity = Vector2.ZERO
			_timer -= delta
			var p2 := _pick_prey(_sight) if _prey_t <= 0.0 else (nash if sees else null)
			if p2 != null:
				_start_chase(p2)
			elif _timer <= 0.0:
				state = S.PATROL
		S.CHASE:
			# v0.5: now and then, look for someone closer (or someone at all, once the prey is gone)
			if _prey_t <= 0.0:
				var closer := _pick_prey(_sight)
				if closer != null and closer != _prey:
					_prey = closer
					_after_nash = closer == nash
			if _prey_sees():
				_last_known = _prey.position
				_walk_to(_prey.position, _speed_chase)
				if position.distance_to(_prey.position) < ATTACK_RANGE:
					state = S.WINDUP
					_timer = _windup
					velocity = Vector2.ZERO
			else:
				# Lost sight (Nash went round a corner): go to where he was last seen.
				_begin_search(_last_known, true)
		S.SEARCH:
			var p3 := _pick_prey(_sight) if _prey_t <= 0.0 else (nash if sees else null)
			if p3 != null:
				_start_chase(p3)
			else:
				_search_step(delta)
				_timer -= delta
				if _timer <= 0.0:
					state = S.PATROL
					_after_nash = false
					_wp = _nearest_patrol_point()
		S.DIG:
			if _dig_target == null or not is_instance_valid(_dig_target) or not nash.in_locker:
				if sees:
					_start_chase(nash)
				else:
					_begin_search(position, false)
			else:
				var spot: Vector2 = _dig_target.position + Vector2(16, 48)   # in front of the locker
				if position.distance_to(spot) > 24.0:
					_walk_to(spot, _speed_chase)
				else:
					velocity = Vector2.ZERO
					_facing = Vector2.UP
					_timer -= delta
					if _timer <= 0.0:
						world.drag_out_of_locker(self)
						state = S.RECOVER
						_timer = RECOVER_SECONDS
		S.WINDUP:
			velocity = Vector2.ZERO
			_timer -= delta * (_slow if _slow_t > 0.0 else 1.0)
			if _timer <= 0.0:
				_bite()
				state = S.RECOVER
				_timer = RECOVER_SECONDS
		S.RECOVER:
			velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				var p4 := _pick_prey(_sight)
				if p4 != null:
					_start_chase(p4)
				else:
					_begin_search(_last_known, true)
		S.STAGGER:
			velocity = _push
			_push = _push.move_toward(Vector2.ZERO, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				var p5 := _pick_prey(_sight * 1.5)
				_start_chase(p5 if p5 != null else nash)
	if _prey_t <= 0.0:
		_prey_t = PREY_CHECK
	move_and_slide()
	_t += delta
	_phase += velocity.length() * delta * 0.1
	if state == S.STAGGER:
		modulate = Color(2.2, 2.2, 2.2)
	elif _slow_t > 0.0:
		modulate = FROST
	else:
		modulate = Color.WHITE
	if velocity.length() > 5.0:
		_facing = Vector2(LsEngine.facing_to_vector(LsEngine.facing_from_vector(velocity, LsEngine.Facing.DOWN)))
	queue_redraw()

## The wind-up is over: the bite lands if the prey is still in reach.
func _bite() -> void:
	if _prey == null or not is_instance_valid(_prey) or position.distance_to(_prey.position) >= HIT_RANGE:
		return
	if _prey == nash:
		if not nash.in_locker:
			world.damage_nash(LsEngine.DAMAGE[kind], position)
	elif _prey.is_prey():
		_prey.infected_hit(position)

func _start_chase(prey: Node2D = null) -> void:
	if prey == null:
		prey = nash
	_prey = prey
	_after_nash = prey == nash
	if state != S.CHASE and state != S.STAGGER and state != S.RECOVER:
		_spot = SPOT_FLASH
	if is_screamer and state != S.CHASE:
		state = S.SHRIEK
		_timer = 1.0
		return
	state = S.CHASE

## The closest living person it can see within `range_px` (Nash, guards, shooters, survivors
## out in the open), or null. Never another infected.
func _pick_prey(range_px: float) -> Node2D:
	var best: Node2D = null
	var best_d := range_px
	for h in world.humans():
		if not is_instance_valid(h) or not h.is_prey():
			continue
		var d := position.distance_to(h.position)
		if d < best_d and _line_to(h):
			best_d = d
			best = h
	return best

## Can it still see its prey? (Nash: in range, not hiding, clear line. Others: alive, clear line.)
func _prey_sees() -> bool:
	if _prey == null or not is_instance_valid(_prey):
		return false
	if _prey == nash:
		return _sees_nash() or (position.distance_to(nash.position) < 60.0 and not nash.in_locker)
	if not _prey.is_prey():
		return false
	return position.distance_to(_prey.position) < _sight * 1.3 and _line_to(_prey)

## Starts a search. `go_there` = first walk to `from` (a noise, the last place Nash was seen);
## otherwise the first leg already heads off in a random direction (lost trail).
func _begin_search(from: Vector2, go_there: bool) -> void:
	state = S.SEARCH
	_timer = SEARCH_SECONDS
	_last_known = from
	_look = 0.0
	_search_goal = from if go_there else _random_goal(from)

## One frame of searching: walk to the current search point, look around, then pick another one
## in a random direction (always somewhere it can walk to).
func _search_step(delta: float) -> void:
	if _look > 0.0:
		velocity = Vector2.ZERO
		var before := int(_look * 3.0)
		_look -= delta
		if int(_look * 3.0) != before:
			_facing = Vector2(-_facing.y, _facing.x)   # turns its head around
		if _look <= 0.0:
			_search_goal = _random_goal(position)
		return
	if position.distance_to(_search_goal) > 10.0:
		_walk_to(_search_goal, _speed_chase * 0.6)
		if velocity.length() < 1.0:   # nowhere to go from here: pick another spot
			_search_goal = _random_goal(position)
	else:
		_look = randf_range(LOOK_SECONDS.x, LOOK_SECONDS.y)

func _random_goal(from: Vector2) -> Vector2:
	var dir := Vector2.RIGHT.rotated(randf() * TAU)
	return world.open_point_near(from + dir * randf_range(SEARCH_STEP.x, SEARCH_STEP.y))

func _nearest_patrol_point() -> int:
	var best := 0
	for i in patrol.size():
		if position.distance_to(patrol[i]) < position.distance_to(patrol[best]):
			best = i
	return best

func _walk_to(target: Vector2, speed: float) -> void:
	# Follow an A* path around walls and furniture (no more snagging on corners).
	var next: Vector2 = _pather.next_point(position, target, get_physics_process_delta_time())
	var d := next - position
	if _slow_t > 0.0:
		speed *= _slow
	velocity = d.normalized() * speed if d.length() > 2.0 else Vector2.ZERO

## Sight: close enough, Nash not hiding, and no wall between us (ray test).
func _sees_nash() -> bool:
	if nash.in_locker or position.distance_to(nash.position) > _sight:
		return false
	return has_line_to_nash()

## Is the straight line to Nash free of walls and furniture? (Ignores range and hiding: the world
## asks this at the moment Nash climbs into a locker.)
func has_line_to_nash() -> bool:
	return _line_to(nash)

func _line_to(who: Node2D) -> bool:
	var q := PhysicsRayQueryParameters2D.create(position, who.position)
	q.exclude = [get_rid(), who.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _draw() -> void:
	var f := _facing
	var shirts := [Color("5a6a7a"), Color("7a5a4a"), Color("4a5a4a"), Color("6a4a5a")]
	var o := {
		"facing": f, "phase": _phase, "amp": clampf(velocity.length() / 90.0, 0.0, 1.0), "t": _t,
		"body": shirts[absi(id.hash()) % 4], "pants": Color("2e3038"), "skin": A.ZOMBIE, "hair": Color("3a3a36"),
		"boots": Color("2a2a2e"), "glove": A.ZOMBIE, "zombie": true, "torn": true, "pouches": false,
		"stubble": false, "held": "none",
	}
	o.blood = true
	if _shirt.a > 0.0:
		o.body = _shirt
	if _hat:
		o.hat = true
		o.hat_color = [Color("e84a8a"), Color("4a9ae8"), A.YELLOW, Color("8ae84a")][absi(id.hash()) % 4]
	if is_runner:
		o.body = Color("2f3f6a")
		o.pants = Color("232a3e")
		o.hair = Color("8a8a90")
	elif is_screamer:
		o.body = Color("6a4a7a")
		o.skin = A.ZOMBIE_PALE
		o.glove = A.ZOMBIE_PALE
		o.mouth_open = true
	elif kind == "gary":
		# Gary Pemberton: white shirt, tie, party hat, his Employee of the Month badge
		o.body = Color("d8dce4")
		o.pants = Color("2a2e38")
		o.hair = Color("8a5a2a")
		o.tie = true
		o.badge = true
	elif is_brute:
		o.body = Color("c8c4bc")
		o.pants = Color("3a3a40")
		o.apron = true
		o.toque = true
		o.hair = Color("1e1a18")
	elif is_crawler:
		o.body = Color("5a4a6a")
	if state == S.DORMANT:
		# Slumped at the security station (Dwayne, asleep).
		draw_set_transform(Vector2(0, 6), 0.22, Vector2(1.0, 0.86))
		o.zombie = false
		o.amp = 0.0
		A.person(self, o)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if state == S.FEED:
		# crouched over the body, head going up and down (v0.5)
		var bob := absf(sin(_t * 7.0 + float(absi(id.hash()) % 10))) * 2.5
		draw_set_transform(Vector2(0, 8 + bob), 0.0, Vector2(1.05, 0.72))
		o.amp = 0.0
		o.mouth_open = true
		A.person(self, o)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# fresh blood dripping from the mouth
		draw_circle(f * 7.0 + Vector2(0, -2 + bob), 2.2, A.BLOOD)
		return
	if is_crawler:
		# on the floor, dragging itself along: drawn lying down, head toward where it's going
		var ang := _facing.angle() - PI * 0.5
		draw_set_transform(Vector2(0, 8), ang, Vector2(0.9, 0.75))
		o.facing = Vector2.UP
		o.amp = 0.0
		A.person(self, o)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif _scale != 1.0:
		draw_set_transform(Vector2(0, 14 - 14 * _scale), 0.0, Vector2(_scale, _scale))
		A.person(self, o)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		A.person(self, o)
	if is_runner:
		A.flat_rect(self, Rect2(-7, -5, 5, 4), A.YELLOW, 1.0)    # Dwayne's badge
	if state == S.WINDUP or state == S.SHRIEK:
		# The warning: a flickering cyan glow (infected glow = the one allowed use of cyan).
		if int(_timer * 16.0) % 2 == 0:
			draw_arc(Vector2(0, -2), 21.0, 0.0, TAU, 28, A.CYAN_CORE, 3.0)
			draw_arc(Vector2(0, -2), 25.0, 0.0, TAU, 28, Color(A.CYAN_GLOW.r, A.CYAN_GLOW.g, A.CYAN_GLOW.b, 0.4), 3.0)
			var side := Vector2(-f.y, f.x)
			draw_circle(Vector2(0, -13) + side * 3.0 + f * 2.0, 2.0, A.CYAN_GLOW)
			draw_circle(Vector2(0, -13) - side * 3.0 + f * 2.0, 2.0, A.CYAN_GLOW)
	if _slow_t > 0.0:
		# frost crystals around the feet while the coolant holds it
		for i in 5:
			var a := float(i) / 5.0 * TAU + _t * 0.6
			draw_circle(Vector2(cos(a) * 13.0, 12.0 + sin(a) * 4.0), 1.6, Color(0.95, 0.98, 1.0, 0.85))
	# awareness marker over the head: "!" just spotted Nash, "?" searching
	if _spot > 0.0:
		_marker("!", A.YELLOW)
	elif state == S.SEARCH or state == S.DIG:
		_marker("?", A.WHITE)

func _marker(s: String, col: Color) -> void:
	var c := Vector2(0, -34 + sin(_t * 6.0) * 1.5)
	A.ink_circle(self, c, 6.5, col, 1.5)
	draw_string(ThemeDB.fallback_font, c + Vector2(-3.2, 4.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, A.INK)
