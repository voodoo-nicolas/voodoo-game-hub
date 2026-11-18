extends Node2D
const Combat = preload("res://scripts/games/hesperia/core/combat.gd")
const Art = preload("res://scripts/games/hesperia/game/art.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
## Generic enemy (state machine: idle/wander -> chase/attack -> hurt). Stats from enemies.json (hp, name);
## movement style from STYLE below (keyed by enemy id). Add an id here to give a new enemy its behaviour.

const STYLE := {
	"e01": {"move": "swoop", "speed": 95.0, "aggro": 90.0, "size": 11.0, "shell": false},   # Giant Gull
	"e02": {"move": "side", "speed": 30.0, "aggro": 70.0, "size": 12.0, "shell": true},     # Rock Crab: shell in front
	"e03": {"move": "hop", "speed": 70.0, "aggro": 80.0, "size": 10.0, "shell": false},     # Marsh Frog
	"e04": {"move": "chase", "speed": 28.0, "aggro": 90.0, "size": 10.0, "shell": false},   # Water Snake
	"e07": {"move": "chase", "speed": 36.0, "aggro": 90.0, "size": 12.0, "shell": false},   # Giant Spider
	"e08": {"move": "flutter", "speed": 55.0, "aggro": 100.0, "size": 9.0, "shell": false}, # Cave Bat
	"e15": {"move": "chase", "speed": 22.0, "aggro": 70.0, "size": 8.0, "shell": false},    # Marsh Leech
}

var id: String = "e01"
var area
var player
var hp: int = 1
var style: Dictionary = {}
var facing: Vector2i = Vector2i(0, 1)
var state: String = "idle"
var t: float = 0.0
var dir: Vector2 = Vector2.ZERO
var kb: Vector2 = Vector2.ZERO
var flash: float = 0.0
var HALF: Vector2
const Fx := preload("res://scripts/games/hesperia/game/fx.gd")

func setup(enemy_id: String, a, p) -> void:
	id = enemy_id
	area = a
	player = p
	hp = int(Data.enemies[id]["hp"]) if Data.enemies.has(id) else 1
	style = STYLE.get(id, {"move": "chase", "speed": 30.0, "aggro": 80.0, "size": 10.0, "shell": false})
	HALF = Vector2(style["size"], style["size"]) * 0.5
	add_to_group("hittable")
	t = randf() * 2.0

func get_rect() -> Rect2:
	return Rect2(position - HALF, HALF * 2.0)

func _process(dt: float) -> void:
	if player == null or area == null:
		return
	if flash > 0.0:
		flash -= dt
	t -= dt
	if kb.length() > 1.0:
		_step(kb * dt)
		kb = kb.move_toward(Vector2.ZERO, 500.0 * dt)
		queue_redraw()
		return
	var to_p: Vector2 = player.position - position
	var dist := to_p.length()
	var aggro: bool = dist < float(style["aggro"]) and not player.dead
	match style["move"]:
		"swoop":
			if state == "swoop":
				_step(dir * float(style["speed"]) * dt)
				if t <= 0.0:
					state = "idle"
					t = 1.5 + randf()
			elif aggro and t <= 0.0:
				state = "swoop"
				dir = to_p.normalized()
				t = 0.7
			else:
				_wander(dt, 0.3)
		"side":
			if aggro:
				var d := Vector2(signf(to_p.x), 0.0) if absf(to_p.x) > 6.0 else Vector2(0.0, signf(to_p.y))
				_step(d * float(style["speed"]) * dt)
				facing = Vector2i(int(d.x), int(d.y)) if d != Vector2.ZERO else facing
			else:
				_wander(dt, 0.5)
		"hop":
			if t <= 0.0:
				t = 0.7 + randf() * 0.5
				dir = to_p.normalized() if aggro else Vector2.from_angle(randf() * TAU)
				state = "hop"
			if state == "hop":
				_step(dir * float(style["speed"]) * dt * clampf(t * 2.0, 0.0, 1.0))
		"flutter":
			if t <= 0.0:
				t = 0.25 + randf() * 0.3
				dir = (to_p.normalized() + Vector2.from_angle(randf() * TAU) * 0.9).normalized() if aggro else Vector2.from_angle(randf() * TAU)
			_step(dir * float(style["speed"]) * dt)
		_:
			if aggro:
				_step(to_p.normalized() * float(style["speed"]) * dt)
			else:
				_wander(dt, 0.4)
	if absf(to_p.x) > absf(to_p.y):
		facing = Vector2i(int(signf(to_p.x)), 0) if style["move"] != "side" else facing
	# touch damage
	if get_rect().intersects(player.get_rect()):
		player.hurt(1, position)
	queue_redraw()

func _wander(dt: float, speed_mul: float) -> void:
	if t <= 0.0:
		t = 0.8 + randf() * 1.2
		dir = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
	_step(dir * float(style["speed"]) * speed_mul * dt)

func _step(delta: Vector2) -> void:
	var p := position + Vector2(delta.x, 0.0)
	if area.blocked(Rect2(p - HALF, HALF * 2.0), self, Vector2i.ZERO, true):
		p.x = position.x
	var q := Vector2(p.x, position.y + delta.y)
	if area.blocked(Rect2(q - HALF, HALF * 2.0), self, Vector2i.ZERO, true):
		q.y = position.y
	position = q

## Called by Area.attack(). Returns true if it connected.
func hit_rect(r: Rect2, dir_v: Vector2i, dmg: int, src: String) -> bool:
	if not r.intersects(get_rect()):
		return false
	var mult := 1
	if style["shell"] and src == "sword":
		mult = Combat.crab_hit_mult(dir_v, facing)
	if mult == 0:
		kb = Combat.knockback(player.position, position, 40.0)
		area.hit_spark(r.get_center().lerp(position, 0.5), true)
		return true
	hp -= dmg * mult
	flash = 0.15
	kb = Combat.knockback(player.position, position, 160.0)
	area.hit_spark(r.get_center().lerp(position, 0.5))
	if hp <= 0:
		area.enemy_died(self)
	return true

func _draw() -> void:
	var col := Art.color_for(id)
	if flash > 0.0:
		col = Color.WHITE
	var side := "left" if facing.x < 0 else ("right" if facing.x > 0 else "")
	var mod := Color(3, 3, 3) if flash > 0.0 else Color.WHITE
	# visual pass: contact shadow; flyers hover above theirs with a slow bob (hitbox unchanged)
	var sz := float(style["size"])
	var flyer: bool = style["move"] == "swoop" or style["move"] == "flutter"
	var lift := Vector2.ZERO
	if flyer:
		lift = Vector2(0, -5.0 + roundf(sin(Time.get_ticks_msec() / 220.0 + float(get_instance_id() % 7)) * 1.5))
		Fx.shadow(self, Vector2(0, sz * 0.5), sz * 0.35, 0.22)
	else:
		Fx.shadow(self, Vector2(0, sz * 0.5 - 1.0), sz * 0.55, 0.3)
	if kb.length() > 1.0 and flash <= 0.0:
		mod = Color(1.4, 1.2, 1.2)
	if not Art.anim(self, id + "_move", lift, Time.get_ticks_msec() / 1000.0 + float(get_instance_id() % 7) * 0.13, side, -1, mod, float(style["size"]) * 0.5):
		Art.actor(self, id, Vector2.ZERO, float(style["size"]), col, facing)
	if style["shell"]:
		var f := Vector2(facing) * float(style["size"]) * 0.5
		draw_rect(Rect2(f - Vector2(2, 2), Vector2(4, 4)), Color(0.4, 0.35, 0.3))
