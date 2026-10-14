extends CharacterBody2D

## Barricade shooter: a panicked survivor behind cover who thinks Nash is infected.
## Stays put, aims (a thin white line warns you for a moment), then fires one shot.
## Shoots OVER crates (cover blocks Nash walking, not bullets), but pillars block his view.
## Never killed: two hits from Nash knock him out, and he drops a little ammo.
## Placeholder art (shapes). No cyan.
##
## v0.5: he shoots the infected too (the closest one in range comes before Nash), and they go for
## him: their bites take one hit point each, and at 0 he is DEAD; the world turns him later.

const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")
const A = preload("res://scripts/games/last_shift/last_shift_art.gd")

enum S { IDLE, AIM, COOLDOWN, DOWN, DEAD }

const RANGE := 340.0
const AIM_SECONDS := 0.8      # the white line is visible this long before the shot
const COOLDOWN_SECONDS := 1.4
# Damage to Nash and hit points: see DAMAGE.shooter / ENEMY_HP.shooter in last_shift_engine.gd.

const JACKET := Color("7a5a3a")
const SKIN := Color("d2a07a")

var id := ""
## Enemy kind (see LsEngine.ENEMY_HP / DAMAGE).
var kind := "shooter"
var world: Node = null
var nash: Node2D = null
var state: int = S.IDLE
var hp: int = LsEngine.ENEMY_HP.shooter
var _timer := 0.0
var _facing := Vector2.LEFT
var _t := 0.0
## v0.5: who he is aiming at (Nash or an infected).
var _aim: Node2D = null

func setup(data: Dictionary, world_node: Node, nash_node: Node2D) -> void:
	id = data.id
	world = world_node
	nash = nash_node
	position = (Vector2(data.cell) + Vector2(0.5, 0.5)) * 32.0
	_facing = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}[data.get("face", "left")]

func _ready() -> void:
	z_index = int(position.y) + 14
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	shape.name = "body_shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	add_child(shape)
	if state == S.DOWN or state == S.DEAD:
		shape.set_deferred("disabled", true)

func set_down() -> void:
	state = S.DOWN
	var shape := get_node_or_null("body_shape")
	if shape != null:
		shape.set_deferred("disabled", true)
	queue_redraw()

func investigate(_pos: Vector2) -> void:
	pass

func wake() -> void:
	pass

## Melee hit for `dmg` (the knife does nothing to people).
func hit(from_pos: Vector2, dmg: int = 2, _push: float = 0.0, _by: String = "") -> void:
	_hurt(from_pos, dmg)

func shot(from_pos: Vector2, _by: String = "pistol") -> void:
	_hurt(from_pos, int(LsEngine.WEAPONS.pistol.damage))

## v0.5: a living person the infected can go after.
func is_prey() -> bool:
	return state != S.DOWN and state != S.DEAD

## v0.5: an infected's bite: one hit point each; at 0 he is dead (the world turns him later).
func infected_hit(from_pos: Vector2) -> void:
	if not is_prey():
		return
	hp -= 1
	world.on_person_bitten(self, from_pos)
	if hp <= 0:
		state = S.DEAD
		get_node("body_shape").set_deferred("disabled", true)
		world.on_person_killed(self)
		queue_redraw()

func is_aware() -> bool:
	return state != S.IDLE

## Is he after Nash right now? (Nash's health only ticks back when nobody is.)
func is_hunting() -> bool:
	return (state == S.AIM or state == S.COOLDOWN) and _aim == nash

func lose_trail() -> void:
	pass

func saw_hide(_locker: Node2D) -> void:
	pass

func has_line_to_nash() -> bool:
	return false   # he stays behind his barricade either way

func _hurt(_from_pos: Vector2, dmg: int) -> void:
	if state == S.DOWN or state == S.DEAD:
		return
	hp -= dmg
	if hp <= 0:
		state = S.DOWN
		get_node("body_shape").set_deferred("disabled", true)
		world.on_guard_down(self)
		queue_redraw()

func _physics_process(delta: float) -> void:
	if state == S.DOWN or state == S.DEAD:
		return
	match state:
		S.IDLE:
			# v0.5: an infected in range comes first, then Nash
			_aim = _closest_infected()
			if _aim == null and _sees_nash():
				_aim = nash
			if _aim != null:
				state = S.AIM
				_timer = AIM_SECONDS
		S.AIM:
			if not _still_sees(_aim):
				state = S.IDLE       # Nash ducked behind a pillar or into a locker
				_aim = null
			else:
				_timer -= delta
				var d := _aim.position - position
				_facing = Vector2(LsEngine.facing_to_vector(LsEngine.facing_from_vector(d, LsEngine.Facing.LEFT)))
				if _timer <= 0.0:
					world.on_shooter_fired(self)
					if _aim == nash:
						world.damage_nash(LsEngine.DAMAGE.shooter, position)
					else:
						world.shooter_hits_infected(self, _aim)
					state = S.COOLDOWN
					_timer = COOLDOWN_SECONDS
		S.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0:
				state = S.IDLE
	_t += delta
	queue_redraw()

## Sees Nash if he is in range, not hiding, and no pillar or wall blocks the line.
## Crates do not block it (he shoots over his own barricade).
func _sees_nash() -> bool:
	if nash.in_locker or position.distance_to(nash.position) > RANGE:
		return false
	return _line_to(nash)

## Still has a shot at `who`? (Nash: as above. An infected: alive, in range, clear line.)
func _still_sees(who: Node2D) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	if who == nash:
		return _sees_nash()
	return world.is_live_enemy(who) and position.distance_to(who.position) <= RANGE and _line_to(who)

## The closest infected in range with a clear line (over the crates), or null.
func _closest_infected() -> Node2D:
	var best: Node2D = null
	var best_d := RANGE
	for e in world.infected():
		var d := position.distance_to(e.position)
		if d < best_d and _line_to(e):
			best_d = d
			best = e
	return best

func _line_to(who: Node2D) -> bool:
	var q := PhysicsRayQueryParameters2D.create(position, who.position)
	var skip: Array = [get_rid(), who.get_rid()]
	skip.append_array(world.crate_rids())
	q.exclude = skip
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _draw() -> void:
	if state == S.DOWN or state == S.DEAD:
		if state == S.DEAD:
			draw_circle(Vector2(2, 6), 17.0, Color("6e0a0e"))
		A.shadow(self, Vector2(0, 8), 16, 6)
		A.ink_rect(self, Rect2(-14, -4, 28, 14), JACKET)
		A.ink_rect(self, Rect2(12, -6, 9, 9), SKIN)
		return
	A.person(self, {
		"facing": _facing, "phase": 0.0, "amp": 0.0, "t": _t,
		"body": JACKET, "pants": Color("3a3a48"), "skin": SKIN, "hair": Color("4a3a2a"),
		"boots": Color("2a2a2e"), "glove": SKIN, "pouches": false, "held": "pistol", "stubble": true,
	})
	if state == S.AIM and _aim != null and is_instance_valid(_aim):
		# Warning line toward Nash (or the infected he is about to shoot).
		draw_line(Vector2.ZERO, _aim.position - position, Color(1, 1, 1, 0.55), 2.0)
