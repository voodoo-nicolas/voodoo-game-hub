extends Node2D
const Combat = preload("res://scripts/games/hesperia/core/combat.gd")
const Art = preload("res://scripts/games/hesperia/game/art.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
const WorldState = preload("res://scripts/games/hesperia/world_state.gd")
## Player: 8-dir movement, sword arc (A), shield (B, hold), item X / item Y, hurt/knockback, death signal.
## Position = centre of a 10x8 feet hitbox.

signal died
signal request_interact(pos, facing)
signal damaged                 # visual pass: main flashes the screen / shakes the camera

const Fx := preload("res://scripts/games/hesperia/game/fx.gd")

const SPEED := 62.0
const HALF := Vector2(5, 4)
const SWORD_TIME := 0.20
const SWORD_REACH := 18.0     ## Fisher's Gaff: short reach (items.json)
const CLUB_REACH := 13.0      ## Driftwood Club (Argos', end of the prologue): starter weapon until the gaff
const ACCEL := 900.0          ## walk feel: full speed in ~0.07 s, stop in ~0.05 s
const DECEL := 1300.0
const NUDGE := 6.0            ## corner assist: slide round a corner when this close to clearing it
const Sounds := preload("res://scripts/games/hesperia/hesperia_sounds.gd")
const INVULN := 0.9

var area                      # Area node (set by main)
var facing: Vector2i = Vector2i(0, 1)
var vel_kb: Vector2 = Vector2.ZERO
var sword_t: float = 0.0
var item_t: float = 0.0
var invuln: float = 0.0
var shielding: bool = false
var frozen: bool = false      # cutscenes / dialogue
var dead: bool = false
var cant_die: bool = false    # prologue
var moving: bool = false      # drives walk animation
var anim_t: float = 0.0
var dust_t: float = 0.0       # walk dust puffs + footsteps
var vel: Vector2 = Vector2.ZERO

func _ready() -> void:
	z_index = 5

func get_rect() -> Rect2:
	return Rect2(position - HALF, HALF * 2.0)

func has_sword() -> bool:
	return WorldState.item_count("gaff") > 0 or WorldState.item_count("stick") > 0

func reach() -> float:
	return SWORD_REACH if WorldState.item_count("gaff") > 0 else CLUB_REACH

func has_shield() -> bool:
	return WorldState.item_count("wicker") > 0

func _process(dt: float) -> void:
	if area == null or dead:
		return
	if invuln > 0.0:
		invuln -= dt
	if sword_t > 0.0:
		sword_t -= dt
	if item_t > 0.0:
		item_t -= dt
	shielding = (not frozen) and has_shield() and Input.is_action_pressed("btn_b")
	if frozen:
		queue_redraw()
		return
	# knockback decays
	if vel_kb.length() > 1.0:
		_move(vel_kb * dt)
		vel_kb = vel_kb.move_toward(Vector2.ZERO, 420.0 * dt)
	var d := Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down")
	var want := Vector2.ZERO
	if d.length() > 0.1 and sword_t <= 0.0:
		# facing: keep the current direction while its axis is still held (no flicker on diagonals)
		if Vector2(facing).dot(d) < 0.3:
			if absf(d.x) > absf(d.y):
				facing = Vector2i(int(signf(d.x)), 0)
			else:
				facing = Vector2i(0, int(signf(d.y)))
		var sp: float = SPEED * area.speed_at(position) * (0.55 if shielding else 1.0)
		want = d.normalized() * sp * minf(1.0, d.length() * 1.15)
	vel = vel.move_toward(want, (ACCEL if want != Vector2.ZERO else DECEL) * dt)
	var moved := Vector2.ZERO
	if vel.length() > 0.5:
		moved = _move(vel * dt)
		if moved.length() < 0.01 and want != Vector2.ZERO:
			moved = _corner_assist(want, dt)
	var spd := moved.length() / maxf(dt, 0.0001)
	moving = spd > 8.0                       # walk cycle only when actually moving (not when pushing a wall)
	anim_t += dt * clampf(spd / SPEED, 0.5, 1.2) if moving else dt
	if moving:
		dust_t -= dt * clampf(spd / SPEED, 0.4, 1.0)
		if dust_t <= 0.0:
			dust_t = 0.27
			var wet: bool = area.speed_at(position) < 1.0
			area.burst(position + Vector2(randf_range(-2, 2), 3), Color(0.6, 0.8, 0.85, 0.8) if wet else Color(0.82, 0.75, 0.6, 0.7), 2, 10.0, 0.35, -8.0, 1.0)
			Sounds.step(self, area.ground_at(position))
	if Input.is_action_just_pressed("btn_a"):
		_press_a()
	if Input.is_action_just_pressed("btn_x"):
		_use_item(WorldState.equipped_x)
	if Input.is_action_just_pressed("btn_y"):
		_use_item(WorldState.equipped_y)
	area.check_player_tile(self)
	queue_redraw()

## Walking straight into a wall corner: if a few pixels sideways clears it, slide that way (Zelda-style).
func _corner_assist(want: Vector2, dt: float) -> Vector2:
	if absf(want.x) > 0.1 and absf(want.y) > 0.1:
		return Vector2.ZERO
	var step := want.length() * dt
	var ax := Vector2(signf(want.x), signf(want.y))
	var side := Vector2(absf(ax.y), absf(ax.x))
	for k in range(1, int(NUDGE) + 1):
		for sgn in [1.0, -1.0]:
			var probe: Vector2 = position + side * float(k) * sgn + ax * maxf(step, 1.0)
			if not area.blocked(Rect2(probe - HALF, HALF * 2.0), null):
				return _move(side * sgn * minf(step, float(k)))
	return Vector2.ZERO

func _move(delta: Vector2) -> Vector2:
	var start := position
	var p := position
	p.x += delta.x
	if area.blocked(Rect2(p - HALF, HALF * 2.0), self, Vector2i(int(signf(delta.x)), 0)):
		p.x = position.x
	var q := Vector2(p.x, position.y + delta.y)
	if area.blocked(Rect2(q - HALF, HALF * 2.0), self, Vector2i(0, int(signf(delta.y)))):
		q.y = position.y
	position = q
	return position - start

func _press_a() -> void:
	# talk / open / read if something is in front, otherwise swing
	if area.interact(self):
		return
	if has_sword() and sword_t <= 0.0:
		sword_t = SWORD_TIME
		Sounds.swing(self)
		var r := sword_rect()
		area.attack(r, facing, 1, "sword")
		area.burst(r.get_center(), Color(1, 1, 0.9), 2, 25.0, 0.15, 0.0, 1.0)

func sword_rect() -> Rect2:
	var f := Vector2(facing)
	var rr := reach()
	var c := position + f * (HALF.x + rr * 0.5)
	var sz := Vector2(rr, 14) if facing.x != 0 else Vector2(14, rr)
	return Rect2(c - sz * 0.5, sz)

func _use_item(id: String) -> void:
	if id == "" or WorldState.item_count(id) <= 0 or item_t > 0.0:
		return
	var f := Vector2(facing)
	match id:
		"torch":
			if WorldState.use_magic(1):
				item_t = 0.3
				var c := position + f * 14.0
				area.attack(Rect2(c - Vector2(9, 9), Vector2(18, 18)), facing, 1, "fire")
				area.flame_fx(c)
			else:
				WorldState.bus.emit_signal("toast", Data.tr_ui("no_magic"))
		"fire_rod":
			if WorldState.use_magic(2):
				item_t = 0.35
				area.spawn_bolt(position + f * 10.0, f * 150.0, "fire")
			else:
				WorldState.bus.emit_signal("toast", Data.tr_ui("no_magic"))
		"honey":
			WorldState.remove_item("honey")
			WorldState.heal(4)
		"nectar":
			WorldState.remove_item("nectar")
			WorldState.heal(99)
			WorldState.magic = WorldState.max_magic

## damage in half-hearts; from_pos for knockback / shield direction
func hurt(half: int, from_pos: Vector2) -> void:
	if invuln > 0.0 or dead:
		return
	var to_attacker := (from_pos - position)
	if shielding and to_attacker.length() > 0.1:
		var dir := Vector2(facing)
		if dir.dot(to_attacker.normalized()) > 0.4:
			vel_kb = Combat.knockback(from_pos, position, 90.0)
			area.hit_spark(position + dir * 8.0, true)
			Sounds.block(self)
			invuln = 0.25
			return
	invuln = INVULN
	vel_kb = Combat.knockback(from_pos, position, 150.0)
	area.burst(position + Vector2(0, -6), Color(1.0, 0.3, 0.3), 8, 55.0, 0.35, 0.0, 1.5)
	emit_signal("damaged")
	Sounds.hurt(self)
	var died_now := WorldState.hurt(half)
	if died_now and cant_die:
		WorldState.half_hearts = 1
	elif died_now:
		dead = true
		emit_signal("died")

func _draw() -> void:
	Fx.shadow(self, Vector2(0, 3), 5.5, 0.32)
	var blink := invuln > 0.0 and int(invuln * 20.0) % 2 == 0
	if blink:
		return
	var col := Color(0.85, 0.7, 0.5) if WorldState.male else Color(0.9, 0.65, 0.55)
	var base := "hero_m" if WorldState.male else "hero_f"
	var hb := base if WorldState.hair == "brown" else base + "_" + WorldState.hair   # hair colour strips
	var side := "left" if facing.x < 0 else ("right" if facing.x > 0 else "")
	var drew := false
	if sword_t > 0.0:
		var fr := clampi(int((1.0 - sword_t / SWORD_TIME) * 4.0), 0, 3)
		var at := "_attack_side" if facing.x != 0 else ("_attack_up" if facing.y < 0 else "_attack")
		for k in [hb + at, base + at, hb + "_attack", base + "_attack"]:
			if Art.anim_frames(k) > 0:
				drew = Art.anim(self, k, Vector2.ZERO, 0.0, side, fr % Art.anim_frames(k))
				break
	else:
		var a := "_walk_side" if facing.x != 0 else ("_walk_up" if facing.y < 0 else "_walk_down")
		drew = Art.anim(self, hb + a, Vector2.ZERO, anim_t, side, -1 if moving else 0)
		if not drew:
			drew = Art.anim(self, base + a, Vector2.ZERO, anim_t, side, -1 if moving else 0)
	if not drew:
		Art.actor(self, base, Vector2.ZERO, 12.0, col, facing)
		draw_rect(Rect2(Vector2(-6, -7), Vector2(12, 4)), Color(0.35, 0.22, 0.12))   # hair
	if shielding:
		# round wicker shield: dark rim, woven face, bronze boss
		var o := Vector2(facing) * 8.0 + Vector2(0, -3)
		draw_circle(o, 5.5, Color(0.3, 0.2, 0.1))
		draw_circle(o, 4.5, Color(0.75, 0.6, 0.35))
		draw_arc(o, 3.0, 0.0, TAU, 10, Color(0.6, 0.45, 0.25), 1.0)
		draw_circle(o, 1.5, Color(0.95, 0.8, 0.45))
	if sword_t > 0.0:
		# slash arc sweeping across the facing direction (hitbox unchanged: sword_rect())
		var k := 1.0 - sword_t / SWORD_TIME
		var ang := Vector2(facing).angle()
		var rch := HALF.x + reach()
		var a0 := ang - 1.25
		var a1 := a0 + 2.5 * minf(1.0, k * 1.6)
		var fade := 1.0 - maxf(0.0, (k - 0.6) / 0.4)
		var cen := Vector2(0, -3)
		draw_arc(cen, rch * 0.8, a0, a1, 14, Color(1.0, 0.85, 0.5, 0.35 * fade), 6.0)
		draw_arc(cen, rch * 0.85, maxf(a0, a1 - 1.2), a1, 10, Color(1, 1, 1, 0.9 * fade), 2.0)
		draw_line(cen + Vector2.from_angle(a1) * 4.0, cen + Vector2.from_angle(a1) * rch, Color(0.92, 0.92, 1.0, fade), 1.0)
