extends CharacterBody2D

## Nash. Moves with the ls_move_* actions, which are fed by the keyboard AND by the on-screen
## touch D-pad. Health (out of 100), hiding, melee (fist / knife / wrench) and the pistol.
## His stuff (bag, weapons, money) is in `inv` (last_shift_inventory.gd).
## (The world decides who gets hit.)

const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")
const LsArt = preload("res://scripts/games/last_shift/last_shift_art.gd")
const Inventory = preload("res://scripts/games/last_shift/last_shift_inventory.gd")

## Walk speed in pixels per second (tiles are 32 px).
const SPEED := 150.0
## Movement smaller than this does not change the facing.
const FACING_DEADZONE := 0.25

const MAX_HP := LsEngine.NASH_MAX_HP
const INVULN_SECONDS := 1.0     # blinks and can't be hurt after a hit
const SWING_SECONDS := 0.15     # how long the melee arc is visible/active
const FLASH_SECONDS := 0.07     # muzzle flash
## Work gloves: a dark grey (the light grey from the concept sheet read as a white block on screen).
const GLOVE := Color("62666e")

var facing: int = LsEngine.Facing.DOWN
var hp := MAX_HP
var inv := Inventory.new()
## Armor points (0..100) and what he is wearing: "" | "vest" (his hi-vis vest) | "riot" (riot gear).
## Armor soaks part of every hit until it runs out (LsEngine.hit_on_nash).
var armor := 0
var armor_kind := ""
## True while hiding in a locker: invisible, can't move, enemies can't see him.
var in_locker := false
## True while a dialog, email, search or room fade is up: Nash stands still.
var frozen := false

## Read-only shortcuts into the inventory (older code and tests use these names).
var has_wrench: bool:
	get: return inv.has_weapon("wrench")
var has_pistol: bool:
	get: return inv.has_weapon("pistol")
var ammo: int:
	get: return inv.ammo()
var weapon: String:
	get: return inv.equipped

var _invuln := 0.0
var _shape: CollisionShape2D = null
var _swing := 0.0
var _flash := 0.0
var _cooldown := 0.0
var _phase := 0.0   # walk-cycle angle
var _amp := 0.0     # how much he is walking (0..1), eased
var _t := 0.0

signal facing_changed(new_facing: int)
## Emitted about every 28 px of walking (the world makes dust puffs).
signal footstep(pos: Vector2)
var _step_acc := 0.0

func _ready() -> void:
	# Top-down: no gravity or floor, so use floating mode.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# Collision box is smaller than a 32 px tile so he fits through 1-tile gaps.
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	_shape.shape = rect
	add_child(_shape)

## Puts Nash somewhere without the in-between frames sliding him there (room changes).
func teleport(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	reset_physics_interpolation()

## Turns Nash to face a direction without moving (used when entering a room).
func set_facing(f: int) -> void:
	facing = f
	queue_redraw()

## The direction the player is pushing (keyboard or D-pad), even while Nash can't move.
func input_dir() -> Vector2:
	return Input.get_vector("ls_move_left", "ls_move_right", "ls_move_up", "ls_move_down")

## v0.5: the infected go for any living person they can see; Nash only while he is not hiding.
func is_prey() -> bool:
	return not in_locker and hp > 0

func can_attack() -> bool:
	return not in_locker and not frozen and _cooldown <= 0.0

## Starts a melee swing / punch (the world checks who it hits).
func start_swing(cooldown: float) -> void:
	_swing = SWING_SECONDS
	_cooldown = cooldown
	queue_redraw()

## Starts a pistol shot (the world checks who it hits and uses up the bullet).
func start_shot(cooldown: float) -> void:
	_flash = FLASH_SECONDS
	_cooldown = cooldown
	queue_redraw()

## Returns true if the hit landed (false while invulnerable or hiding). `armor_loss` comes off the
## armor first (see LsEngine.hit_on_nash); when the armor is gone, so is the gear.
func take_hit(amount: int, armor_loss: int = 0) -> bool:
	if _invuln > 0.0 or in_locker:
		return false
	hp = maxi(0, hp - amount)
	armor = maxi(0, armor - armor_loss)
	if armor <= 0:
		armor_kind = ""
	_invuln = INVULN_SECONDS
	queue_redraw()
	return true

## Puts on armor: "vest" or "riot". Returns false if he already wears something better.
func wear(kind: String, points: int) -> bool:
	if armor >= points:
		return false
	armor = points
	armor_kind = kind
	queue_redraw()
	return true

func heal(amount: int) -> void:
	hp = mini(MAX_HP, hp + amount)

func heal_full() -> void:
	hp = MAX_HP
	_invuln = INVULN_SECONDS
	queue_redraw()

## Hiding in a locker: invisible, can't move, and no body in the way (infected can walk up to the
## locker door).
func set_hidden(on: bool) -> void:
	in_locker = on
	visible = not on
	frozen = on
	if _shape != null:
		_shape.set_deferred("disabled", on)

func _process(delta: float) -> void:
	_t += delta
	var target_amp := clampf(velocity.length() / SPEED, 0.0, 1.0)
	_amp = move_toward(_amp, target_amp, delta * 8.0)
	_phase += velocity.length() * delta * 0.115
	_swing = maxf(0.0, _swing - delta)
	_flash = maxf(0.0, _flash - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	z_index = int(position.y) + 14   # sorted against props by the feet
	queue_redraw()

func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		return
	# Keyboard and D-pad both end up here (the D-pad presses the same actions).
	var dir := input_dir()
	velocity = dir * SPEED
	move_and_slide()
	_step_acc += velocity.length() * delta
	if _step_acc > 28.0:
		_step_acc = 0.0
		footstep.emit(global_position)
	if dir.length() > FACING_DEADZONE:
		var new_facing := LsEngine.facing_from_vector(dir, facing)
		if new_facing != facing:
			facing = new_facing
			queue_redraw()
			facing_changed.emit(facing)

## Nash's look for the art routine (also used by tests/shot_sprites.gd): charcoal coveralls (no
## chest band), black T-shirt in the open collar, ID badge, sleeves rolled up with reflective bands
## at the elbows and shins, dark work gloves, tool belt with tools poking out, brown boots, messy
## dark hair and stubble.
func draw_options() -> Dictionary:
	return {
		"body": Color("3c3a40"), "band": Color(0.64, 0.65, 0.66, 0.85), "skin": LsArt.SKIN,
		"hair": Color("2a1f1a"), "boots": Color("5a3a22"), "glove": GLOVE, "belt": Color("6b4a2a"),
		"tee": Color("17171b"), "badge": true, "rolled": true, "tools": true,
		"vest": armor_kind == "vest", "riot": armor_kind == "riot",
		"hat": inv.hat_worn == "party", "hat_color": Color("e84a8a"),
		"toque": inv.hat_worn == "chef",
	}

func _draw() -> void:
	# Blink while invulnerable after a hit.
	if _invuln > 0.0 and int(_invuln * 14.0) % 2 == 0:
		return
	var f := LsEngine.facing_to_vector(facing)
	var held := "none"
	if inv.equipped in ["wrench", "pistol", "knife", "arm", "coolant"]:
		held = inv.equipped
	var progress := 0.0 if _swing <= 0.0 else 1.0 - _swing / SWING_SECONDS
	var o := draw_options()
	o.merge({"facing": f, "phase": _phase, "amp": _amp, "t": _t, "held": held, "swing": progress})
	LsArt.person(self, o)
	if _swing > 0.0:
		var a := f.angle()
		if held == "none":
			# a punch: the glove shoots out in front and comes back
			var reach := 10.0 + 12.0 * sin(progress * PI)
			var fist := f * reach + Vector2(0, -2)
			draw_circle(fist, 5.5, LsArt.INK)
			draw_circle(fist, 4.2, GLOVE)
			draw_arc(Vector2(0, 2), 24.0, a - 0.5, a + 0.5, 8, Color(1, 1, 1, 0.55), 3.0)
		else:
			draw_arc(Vector2(0, 2), 30.0, a - 0.9, a + 0.9, 12, Color(1, 1, 1, 0.8), 4.0)
	if _flash > 0.0:
		var side := Vector2(-f.y, f.x)
		draw_circle(side * 8.0 + f * 24.0 + Vector2(0, 4), 7.0, Color("fff0a0"))
		draw_circle(side * 8.0 + f * 24.0 + Vector2(0, 4), 3.5, Color.WHITE)
