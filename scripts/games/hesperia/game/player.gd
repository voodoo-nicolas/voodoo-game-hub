extends Node2D
const Combat = preload("res://scripts/games/hesperia/core/combat.gd")
const Art = preload("res://scripts/games/hesperia/game/art.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
const WorldState = preload("res://scripts/games/hesperia/world_state.gd")
## Player: 8-dir movement, sword arc (A), shield (B, hold), item X / item Y, hurt/knockback, death signal.
## Position = centre of a 10x8 feet hitbox.

signal died
signal request_interact(pos, facing)

const SPEED := 62.0
const HALF := Vector2(5, 4)
const SWORD_TIME := 0.20
const SWORD_REACH := 18.0     ## Fisher's Gaff: short reach (items.json)
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

func _ready() -> void:
	z_index = 5

func get_rect() -> Rect2:
	return Rect2(position - HALF, HALF * 2.0)

func has_sword() -> bool:
	return WorldState.item_count("gaff") > 0

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
	moving = d.length() > 0.1 and sword_t <= 0.0
	anim_t += dt
	if d.length() > 0.1 and sword_t <= 0.0:
		if absf(d.x) > absf(d.y):
			facing = Vector2i(int(signf(d.x)), 0)
		else:
			facing = Vector2i(0, int(signf(d.y)))
		var sp: float = SPEED * area.speed_at(position) * (0.55 if shielding else 1.0)
		_move(d.normalized() * sp * dt)
	if Input.is_action_just_pressed("btn_a"):
		_press_a()
	if Input.is_action_just_pressed("btn_x"):
		_use_item(WorldState.equipped_x)
	if Input.is_action_just_pressed("btn_y"):
		_use_item(WorldState.equipped_y)
	area.check_player_tile(self)
	queue_redraw()

func _move(delta: Vector2) -> void:
	var p := position
	p.x += delta.x
	if area.blocked(Rect2(p - HALF, HALF * 2.0), self, Vector2i(int(signf(delta.x)), 0)):
		p.x = position.x
	var q := Vector2(p.x, position.y + delta.y)
	if area.blocked(Rect2(q - HALF, HALF * 2.0), self, Vector2i(0, int(signf(delta.y)))):
		q.y = position.y
	position = q

func _press_a() -> void:
	# talk / open / read if something is in front, otherwise swing
	if area.interact(self):
		return
	if has_sword() and sword_t <= 0.0:
		sword_t = SWORD_TIME
		var r := sword_rect()
		area.attack(r, facing, 1, "sword")

func sword_rect() -> Rect2:
	var f := Vector2(facing)
	var c := position + f * (HALF.x + SWORD_REACH * 0.5)
	var sz := Vector2(SWORD_REACH, 14) if facing.x != 0 else Vector2(14, SWORD_REACH)
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
			invuln = 0.25
			return
	invuln = INVULN
	vel_kb = Combat.knockback(from_pos, position, 150.0)
	var died_now := WorldState.hurt(half)
	if died_now and cant_die:
		WorldState.half_hearts = 1
	elif died_now:
		dead = true
		emit_signal("died")

func _draw() -> void:
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
		var o := Vector2(facing) * 8.0
		draw_rect(Rect2(o - Vector2(4, 5), Vector2(8, 10)), Color(0.75, 0.6, 0.35))
	if sword_t > 0.0:
		var r := sword_rect()
		draw_rect(Rect2(r.position - position, r.size), Color(0.9, 0.9, 1.0, 0.8))
