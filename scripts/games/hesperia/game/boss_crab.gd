extends Node2D
const Art = preload("res://scripts/games/hesperia/game/art.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
const WorldState = preload("res://scripts/games/hesperia/world_state.gd")
## Stone-Back Crab (bosses.json b00): hp 8, 1 phase. Charges in a line; shell blocks the front;
## hit it from the side (1) or rear/belly (2). Slams into a wall -> stunned.

signal defeated

var area
var player
var max_hp: int = 8
var hp: int = 8
var facing: Vector2i = Vector2i(0, 1)
var state: String = "idle"     # idle | wind | charge | stun
var t: float = 1.5
var flash: float = 0.0
var kb: Vector2 = Vector2.ZERO
const HALF := Vector2(14, 11)

func setup(a, p) -> void:
	area = a
	player = p
	max_hp = int(Data.bosses["b00"]["hp"])
	hp = max_hp
	add_to_group("hittable")

func get_rect() -> Rect2:
	return Rect2(position - HALF, HALF * 2.0)

func _process(dt: float) -> void:
	if player == null:
		return
	if flash > 0.0:
		flash -= dt
	t -= dt
	match state:
		"idle":
			var to_p: Vector2 = player.position - position
			if absf(to_p.x) > absf(to_p.y):
				facing = Vector2i(int(signf(to_p.x)), 0)
			else:
				facing = Vector2i(0, int(signf(to_p.y)))
			position += Vector2(facing) * 14.0 * dt * 0.5
			if t <= 0.0:
				state = "wind"
				t = 0.7
		"wind":
			if t <= 0.0:
				state = "charge"
				t = 1.4
		"charge":
			var step := Vector2(facing) * 120.0 * dt
			var np := position + step
			if area.blocked(Rect2(np - HALF, HALF * 2.0), self, Vector2i.ZERO, true):
				state = "stun"
				t = 1.6
				area.shake(0.25)
			else:
				position = np
			if t <= 0.0:
				state = "idle"
				t = 1.0
		"stun":
			if t <= 0.0:
				state = "idle"
				t = 1.0
	if get_rect().intersects(player.get_rect()) and state != "stun":
		player.hurt(2, position)
	queue_redraw()

func hit_rect(r: Rect2, dir_v: Vector2i, dmg: int, src: String) -> bool:
	if not r.intersects(get_rect()):
		return false
	var amount := 0
	if dir_v == -facing and src == "sword":
		area.flame_fx(position)              # clink
		WorldState.bus.emit_signal("toast", Data.tr_ui("hint_crab"))
		return true
	if dir_v == facing:
		amount = dmg * 2                     # rear / belly
	else:
		amount = dmg                         # side
	if src == "fire":
		amount = dmg
	hp -= amount
	flash = 0.2
	area.hit_spark(r.get_center().lerp(position, 0.5), amount == 0)
	if state == "stun":
		t = max(t, 0.4)
	if hp <= 0:
		emit_signal("defeated")
		queue_free()
	return true

func _draw() -> void:
	var sh := Vector2(0, 14)
	draw_colored_polygon(PackedVector2Array([sh + Vector2(-16, 0), sh + Vector2(-11, -4), sh + Vector2(11, -4), sh + Vector2(16, 0), sh + Vector2(11, 4), sh + Vector2(-11, 4)]), Color(0.02, 0.03, 0.06, 0.3))
	var col := Color(0.55, 0.45, 0.4)
	if flash > 0.0:
		col = Color.WHITE
	if state == "wind":
		col = Color(0.9, 0.4, 0.3)
	var mod := Color.WHITE if col == Color(0.55, 0.45, 0.4) else col.lightened(0.4)
	if not Art.anim(self, "b00_idle", Vector2.ZERO, Time.get_ticks_msec() / 1000.0, "", -1, mod, 16.0):
		Art.actor(self, "b00", Vector2.ZERO, 26.0, col, facing)
	# shell on the front
	var f := Vector2(facing)
	var c := f * 12.0
	var sz := Vector2(5, 20) if facing.x != 0 else Vector2(20, 5)
	draw_rect(Rect2(c - sz * 0.5, sz), Color(0.35, 0.33, 0.3))
	# hp bar
	draw_rect(Rect2(Vector2(-15, -21), Vector2(30, 4)), Color(0.05, 0.03, 0.04, 0.85))
	draw_rect(Rect2(Vector2(-14, -20), Vector2(28.0 * float(hp) / float(max_hp), 2)), Color(0.9, 0.2, 0.2))
	draw_rect(Rect2(Vector2(-14, -20), Vector2(28.0 * float(hp) / float(max_hp), 1)), Color(1, 0.55, 0.5))
