extends CharacterBody2D

## Lockdown guard: a scared human following orders (not a villain, not infected).
## Stands at his post. If Nash walks into his view he WARNS first ("Stop right there!"),
## then chases and hits with a baton. Hits from Nash only knock him out, never kill him.
## A knocked-out guard drops a little ammo. Placeholder art (shapes). No cyan.
##
## v0.5: guards fight the infected. An infected he can see (all around him, FIGHT_SIGHT) comes
## before Nash: he shouts, goes at it and swings his baton (it hurts them; Dwayne too). The
## infected go for him as well (they go for every living person): PERSON bites take one hit point
## each, and at 0 he is DEAD (not knocked out). The world turns him into a walker a few seconds later.

const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")
const LsText = preload("res://scripts/games/last_shift/last_shift_text.gd")
const A = preload("res://scripts/games/last_shift/last_shift_art.gd")
const Pather = preload("res://scripts/games/last_shift/last_shift_pather.gd")

enum S { POST, WARN, CHASE, WINDUP, RECOVER, DOWN, STAGGER, FIGHT, DEAD }

const SIGHT_RANGE := 240.0
const SIGHT_CONE := 0.5          # dot product with facing: 0.5 = sees within +-60 degrees
const NEAR_SENSE := 60.0         # notices Nash right next to him even from behind
const WARN_SECONDS := 1.6
const SPEED_CHASE := 85.0        # slower than Nash (150)
const ATTACK_RANGE := 34.0
const HIT_RANGE := 44.0
const WINDUP_SECONDS := 0.5      # white flash = the warning (humans never use cyan)
const RECOVER_SECONDS := 1.0
const STAGGER_SECONDS := 0.35
const FIGHT_SIGHT := 230.0       # v0.5: sees an infected this close, any direction
const BATON_DAMAGE := 1          # v0.5: one baton hit on an infected
const SHOUT_COOLDOWN := 5.0
# Damage to Nash and hit points: see DAMAGE.guard / ENEMY_HP.guard in last_shift_engine.gd.

const UNIFORM := Color("3a4a5e")
const SHIELD := Color("c9ccd3")
const SKIN := Color("d2a07a")

var id := ""
## Enemy kind (see LsEngine.ENEMY_HP / DAMAGE).
var kind := "guard"
var world: Node = null
var nash: Node2D = null
var state: int = S.POST
var hp: int = LsEngine.ENEMY_HP.guard
var _facing := Vector2.LEFT
var _home := Vector2.ZERO
var _timer := 0.0
var _warned := 0
var _push := Vector2.ZERO
var _phase := 0.0
var _pather: RefCounted = null
var _t := 0.0
var _foe: Node2D = null          # v0.5: the infected he is fighting
var _shout_t := 0.0
var _look_t := 0.0

func setup(data: Dictionary, world_node: Node, nash_node: Node2D) -> void:
	id = data.id
	world = world_node
	nash = nash_node
	position = (Vector2(data.cell) + Vector2(0.5, 0.5)) * 32.0
	_home = position
	_facing = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}[data.get("face", "left")]

func _ready() -> void:
	_pather = Pather.new(world)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	shape.name = "body_shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	add_child(shape)
	if state == S.DOWN or state == S.DEAD:
		shape.set_deferred("disabled", true)

## Spawns already knocked out (when the player comes back to a room).
func set_down() -> void:
	state = S.DOWN
	var shape := get_node_or_null("body_shape")
	if shape != null:
		shape.set_deferred("disabled", true)
	queue_redraw()

## Guards ignore noise: they hold their post.
func investigate(_pos: Vector2) -> void:
	pass

func wake() -> void:
	pass

## Melee hit for `dmg` (two wrench hits or four punches; the knife does nothing to people).
func hit(from_pos: Vector2, dmg: int = 2, _push: float = 200.0, _by: String = "") -> void:
	_hurt(from_pos, dmg)

func shot(from_pos: Vector2, _by: String = "pistol") -> void:
	_hurt(from_pos, int(LsEngine.WEAPONS.pistol.damage))

## Has he noticed Nash? (Used for the knife takedown, which never applies to people anyway.)
func is_aware() -> bool:
	return state != S.POST

## Is he after Nash right now? (Nash's health only ticks back when nobody is.)
func is_hunting() -> bool:
	return state in [S.WARN, S.CHASE, S.WINDUP, S.RECOVER, S.STAGGER] and _foe == null

## Is he fighting an infected right now? (The world: "the guards have bigger problems".)
func is_fighting() -> bool:
	return _foe != null and state in [S.FIGHT, S.WINDUP, S.RECOVER]

## v0.5: a living person the infected can go after.
func is_prey() -> bool:
	return state != S.DOWN and state != S.DEAD

## v0.5: an infected's bite. One hit point each; at 0 he is dead (the world turns him later).
func infected_hit(from_pos: Vector2) -> void:
	if not is_prey():
		return
	hp -= 1
	world.on_person_bitten(self, from_pos)
	if hp <= 0:
		state = S.DEAD
		velocity = Vector2.ZERO
		get_node("body_shape").set_deferred("disabled", true)
		world.on_person_killed(self)
		queue_redraw()
		return
	state = S.STAGGER
	_timer = STAGGER_SECONDS
	_push = (position - from_pos).normalized() * 120.0

## Nash hid out of sight: the guard gives up and goes back to his post.
func lose_trail() -> void:
	if state != S.DOWN and state != S.DEAD and _foe == null:
		state = S.POST

func saw_hide(_locker: Node2D) -> void:
	lose_trail()

## Hits knock him out at 0. Never lethal.
func _hurt(from_pos: Vector2, dmg: int) -> void:
	if state == S.DOWN or state == S.DEAD:
		return
	hp -= dmg
	if hp <= 0:
		state = S.DOWN
		velocity = Vector2.ZERO
		get_node("body_shape").set_deferred("disabled", true)
		world.on_guard_down(self)
		queue_redraw()
		return
	_foe = null      # Nash hit him: Nash is the problem now
	state = S.STAGGER
	_timer = STAGGER_SECONDS
	_push = (position - from_pos).normalized() * 200.0

func _physics_process(delta: float) -> void:
	z_index = int(position.y) + 14
	if state == S.DOWN or state == S.DEAD:
		return
	_shout_t = maxf(0.0, _shout_t - delta)
	_look_t -= delta
	# v0.5: infected first. Look around a few times a second for the closest one in view.
	if _look_t <= 0.0:
		_look_t = 0.25
		if _foe == null or not is_instance_valid(_foe) or not world.is_live_enemy(_foe):
			_foe = _closest_infected()
			if _foe != null and state in [S.POST, S.WARN, S.CHASE]:
				state = S.FIGHT
				if _shout_t <= 0.0:
					_shout_t = SHOUT_COOLDOWN
					world.guard_shout(LsText.MSG["guard_fight_%d" % (randi() % 3 + 1)], self)
	if _foe != null and (not is_instance_valid(_foe) or not world.is_live_enemy(_foe)):
		_foe = null
		if state == S.FIGHT:
			state = S.POST
	var sees := _sees_nash()
	match state:
		S.POST:
			velocity = Vector2.ZERO
			if sees:
				state = S.WARN
				_timer = WARN_SECONDS
				_warned += 1
				world.guard_shout(_warn_text(_warned), self)
		S.WARN:
			velocity = Vector2.ZERO
			_face(nash.position)
			_timer -= delta
			if not sees:
				state = S.POST          # Nash got away (hid or left sight)
			elif _timer <= 0.0:
				state = S.CHASE
		S.FIGHT:
			# go at the infected and swing the baton
			var fd: Vector2 = _foe.position - position
			var nxf: Vector2 = _pather.next_point(position, _foe.position, delta)
			velocity = (nxf - position).normalized() * SPEED_CHASE
			_face(_foe.position)
			if fd.length() < ATTACK_RANGE:
				state = S.WINDUP
				_timer = WINDUP_SECONDS
				velocity = Vector2.ZERO
		S.CHASE:
			if sees or position.distance_to(nash.position) < NEAR_SENSE * 2.0 and not nash.in_locker:
				var d := nash.position - position
				var nxt: Vector2 = _pather.next_point(position, nash.position, delta)
				velocity = (nxt - position).normalized() * SPEED_CHASE
				_face(nash.position)
				if d.length() < ATTACK_RANGE:
					state = S.WINDUP
					_timer = WINDUP_SECONDS
					velocity = Vector2.ZERO
			else:
				state = S.POST          # lost him: walks back
		S.WINDUP:
			velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				if _foe != null:
					if position.distance_to(_foe.position) < HIT_RANGE:
						world.guard_hits_infected(self, _foe, BATON_DAMAGE)
				elif position.distance_to(nash.position) < HIT_RANGE and not nash.in_locker:
					world.damage_nash(LsEngine.DAMAGE.guard, position)
				state = S.RECOVER
				_timer = RECOVER_SECONDS
		S.RECOVER:
			velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				state = S.FIGHT if _foe != null else S.CHASE
		S.STAGGER:
			velocity = _push
			_push = _push.move_toward(Vector2.ZERO, 800.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				state = S.FIGHT if _foe != null else S.CHASE
	# Walk back to the post when idle and displaced.
	if state == S.POST and position.distance_to(_home) > 6.0:
		velocity = (_home - position).normalized() * 60.0
	move_and_slide()
	_t += delta
	_phase += velocity.length() * delta * 0.1
	modulate = Color(2.2, 2.2, 2.2) if state == S.STAGGER else Color.WHITE
	queue_redraw()

## The closest infected he can see (any direction), or null.
func _closest_infected() -> Node2D:
	var best: Node2D = null
	var best_d := FIGHT_SIGHT
	for e in world.infected():
		var d := position.distance_to(e.position)
		if d < best_d and _line_to(e):
			best_d = d
			best = e
	return best

func _warn_text(n: int) -> String:
	return LsText.MSG.guard_warn_1 if n % 2 == 1 else LsText.MSG.guard_warn_2

func _face(target: Vector2) -> void:
	var d := target - position
	if d.length() > 1.0:
		_facing = Vector2(LsEngine.facing_to_vector(LsEngine.facing_from_vector(d, LsEngine.Facing.DOWN)))

## Sight: Nash in front of him (cone) or very close, not hiding, and no wall in between.
func _sees_nash() -> bool:
	if nash.in_locker:
		return false
	return _in_view() and has_line_to_nash()

func _in_view() -> bool:
	var d := nash.position - position
	var dist := d.length()
	if dist > SIGHT_RANGE:
		return false
	return dist <= NEAR_SENSE or d.normalized().dot(_facing) >= SIGHT_CONE

## Is the straight line to Nash free of walls and furniture?
func has_line_to_nash() -> bool:
	return _line_to(nash)

func _line_to(who: Node2D) -> bool:
	var q := PhysicsRayQueryParameters2D.create(position, who.position)
	q.exclude = [get_rid(), who.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _draw() -> void:
	if state == S.DOWN or state == S.DEAD:
		# Knocked out (or dead, v0.5: in a pool of blood), lying on the floor.
		if state == S.DEAD:
			draw_circle(Vector2(2, 6), 17.0, Color("6e0a0e"))
		A.shadow(self, Vector2(0, 8), 16, 6)
		A.ink_rect(self, Rect2(-14, -4, 28, 14), UNIFORM)
		A.ink_rect(self, Rect2(12, -6, 9, 9), SKIN)
		A.ink_rect(self, Rect2(-20, -2, 8, 7), Color("202020"))
		return
	var f := _facing
	A.person(self, {
		"facing": f, "phase": _phase, "amp": clampf(velocity.length() / 80.0, 0.0, 1.0), "t": _t,
		"body": UNIFORM, "pants": Color("2a3342"), "skin": SKIN, "hair": Color("2a3138"),
		"boots": Color("1f1f24"), "glove": Color("202020"), "band": Color(0, 0, 0, 0),
		"pouches": true, "held": "baton", "stubble": true,
		"swing": (1.0 - _timer / WINDUP_SECONDS) if state == S.WINDUP else 0.0,
	})
	# Riot shield in front (clear plastic with ink frame).
	var side := Vector2(-f.y, f.x)
	var c := f * 12.0 + Vector2(0, 2)
	var pts := PackedVector2Array([c + side * 10.0 - f * 4.0, c + side * 10.0 + f * 4.0,
		c - side * 10.0 + f * 4.0, c - side * 10.0 - f * 4.0])
	if absf(f.y) > 0.5:
		pts = PackedVector2Array([c + Vector2(-11, -8), c + Vector2(11, -8), c + Vector2(11, 9), c + Vector2(-11, 9)])
	if f.y >= 0.0:
		A.ink_poly(self, pts, Color(0.78, 0.84, 0.9, 0.55), 2.0)
	if state == S.WARN:
		A.ink_circle(self, Vector2(0, -32), 5.0, A.YELLOW, 1.5)     # "!" marker over his head
		draw_rect(Rect2(-1, -35, 2, 5), A.INK)
	if state == S.WINDUP and int(_timer * 16.0) % 2 == 0:
		draw_arc(Vector2(0, -2), 21.0, 0.0, TAU, 24, Color.WHITE, 3.0)
