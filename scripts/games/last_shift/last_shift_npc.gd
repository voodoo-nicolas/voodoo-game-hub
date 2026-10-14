extends CharacterBody2D

## A person who is not an enemy. Two uses:
## 1. The scripted Day 0 coworker: he runs into the plant and is grabbed (the world tweens him).
##    When `down` is true he lies on the floor. Green shirt (never cyan).
## 2. Ambient people from the room data ("npcs"): a cleaner mopping the lobby, a tech in the plant,
##    a coworker heading home, survivors hiding after the alarm. They stroll along a short path
##    (or stay put), and say one line in a speech bubble when Nash comes close.
##    Lines are mundane; nobody explains anything (Day 0 rule).
##
## Room data: {"id", "cell": Vector2i, "look": LOOKS key, "pose": "stand" | "sit" | "cower" |
##   "mop" | "phone", "path": [Vector2i...] (optional), "bark": English line (see LsText.BARKS),
##   "when": "" | "calm" | "alarm" | "after_attack", "face": "down" | "left" | "right" | "up"}
##
## v0.5:
## - "stages": what the person does as the night goes on. {stage: {"pose", "barks": [keys], "shout"}}
##   with stage "alarm" (after the alarms), "attack" (after the first attack), "kill" (after Nash's
##   first kill). The world calls react(stage). "shout": true = he shouts the lines on his own,
##   wherever Nash is (the plant tech screaming about the dead infected); "shouts": n = only n times.
## - pose "panic": runs around the room in a blind panic, away from any infected nearby, screaming.
## - The infected go after people out in the open (cowering = hidden, they are left alone). Bites
##   take a hit point each (LsEngine.PERSON_HP); at 0 the person dies and the world turns them.
## - "barks": [keys] instead of one "bark": the lines take turns.

const A = preload("res://scripts/games/last_shift/last_shift_art.gd")
const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")
const LsText = preload("res://scripts/games/last_shift/last_shift_text.gd")
const Pather = preload("res://scripts/games/last_shift/last_shift_pather.gd")

const WALK_SPEED := 32.0
const PAUSE := Vector2(1.5, 3.5)    # stands this long at each path point
const BARK_RANGE := 70.0
const BARK_SECONDS := 3.2
const BARK_COOLDOWN := 9.0
const PANIC_SPEED := 105.0          # v0.5: running in a panic (Nash walks at 150)
const FLEE_RANGE := 150.0           # runs away from an infected this close
const SHOUT_EVERY := Vector2(3.0, 5.0)   # a panicking / shouting person yells this often

## Clothes per kind of person (no cyan, ever).
const LOOKS := {
	"coworker": {"body": Color("4f8f5a"), "pants": Color("3a3a48"), "skin": Color("d2a07a"), "hair": Color("5a4a2a")},
	"tech": {"body": Color("5a5e66"), "pants": Color("3c3a40"), "skin": Color("a8704a"), "hair": Color("1e1a18"), "band": Color(0.64, 0.65, 0.66, 0.85)},
	"cleaner": {"body": Color("4a6a9a"), "pants": Color("2e3a52"), "skin": Color("c98e6a"), "hair": Color("3a2a22")},
	"office": {"body": Color("c9ccd3"), "pants": Color("2a2e38"), "skin": Color("f1c7a3"), "hair": Color("8a5a2a")},
	"office2": {"body": Color("9a4a5a"), "pants": Color("2a2a30"), "skin": Color("8a5a3a"), "hair": Color("141210")},
	"visitor": {"body": Color("8a7a5a"), "pants": Color("4a4238"), "skin": Color("e0b08a"), "hair": Color("b0a080")},
}

var id := ""
var world: Node = null
var nash: Node2D = null
var look := "coworker"
var pose := "stand"
## The line this person says (English; translated when drawn). Set from the "bark" key.
var bark := ""
## v0.5: several lines that take turns (English), and whether they are shouted unprompted.
var barks: Array = []
var shout := false
var _bark_i := 0
var _shout_t := 0.0
var _shouts_left := -1          # -1 = keeps shouting (panic); the tech stops after a few
var hp := 3
var _stages := {}
var _flee_goal := Vector2.ZERO
var _pather: RefCounted = null
var down := false
var path: Array[Vector2] = []
var _wp := 0
var _pause := 0.0
var _facing := Vector2.DOWN
var _t := 0.0
var _last_pos := Vector2.ZERO
var _phase := 0.0
var _moving := false
var _bark_t := 0.0
var _bark_cd := 0.0
var _bubble: Node2D = null
## The scripted coworker is moved by a tween, not by this script.
var scripted := false

func setup(data: Dictionary, world_node: Node, nash_node: Node2D) -> void:
	id = data.id
	world = world_node
	nash = nash_node
	position = (Vector2(data.cell) + Vector2(0.5, 0.5)) * 32.0
	look = data.get("look", "coworker")
	pose = data.get("pose", "stand")
	bark = LsText.BARKS.get(data.get("bark", ""), "")
	for k in data.get("barks", []):
		barks.append(LsText.BARKS.get(k, k))
	_stages = data.get("stages", {})
	hp = LsEngine.PERSON_HP
	if pose == "panic":
		shout = true
		_shout_t = randf_range(0.5, 2.0)
	_facing = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}[data.get("face", "down")]
	for c in data.get("path", []):
		path.append((Vector2(c) + Vector2(0.5, 0.5)) * 32.0)
	_pause = randf_range(PAUSE.x, PAUSE.y)

func set_down(on: bool) -> void:
	down = on
	queue_redraw()

## v0.5: the night moves on ("alarm", "attack", "kill"): new pose and lines, if the data has them.
## `loud` = it happened right now (not on entering the room): shout the first line at once.
func react(stage: String, loud: bool = false) -> void:
	if not _stages.has(stage) or down:
		return
	var st: Dictionary = _stages[stage]
	if st.has("pose"):
		pose = str(st.pose)
	if st.has("barks"):
		barks.clear()
		for k in st.barks:
			barks.append(LsText.BARKS.get(k, k))
		_bark_i = 0
		bark = barks[0] if not barks.is_empty() else ""
	shout = bool(st.get("shout", pose == "panic"))
	_shouts_left = int(st.get("shouts", -1))
	_shout_t = 0.4 if loud else randf_range(1.0, 2.5)
	if loud and bark != "" and not shout:
		_say_next()

## A living person the infected can go after: out in the open (cowering survivors are hidden).
func is_prey() -> bool:
	return not down and not scripted and pose != "cower" and pose != "sit"

## An infected's bite. One hit point each; at 0 the person dies (the world turns them later).
func infected_hit(from_pos: Vector2) -> void:
	if not is_prey():
		return
	hp -= 1
	world.on_person_bitten(self, from_pos)
	if hp <= 0:
		down = true
		velocity = Vector2.ZERO
		_bubble.visible = false
		var shape := get_node_or_null("body_shape")
		if shape != null:
			shape.set_deferred("disabled", true)
		world.on_person_killed(self)
		queue_redraw()
		return
	if pose != "panic":
		pose = "panic"       # bitten and still standing: now they run
		shout = true

## The next line in the bubble (lines take turns).
func _say_next() -> void:
	if not barks.is_empty():
		bark = barks[_bark_i % barks.size()]
		_bark_i += 1
	_bark_t = BARK_SECONDS
	_bark_cd = BARK_COOLDOWN
	if _bubble != null:
		_bubble.queue_redraw()

func _ready() -> void:
	_last_pos = position
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_pather = Pather.new(world)
	if not scripted:
		# a small solid body, so Nash walks around people instead of through them
		var shape := CollisionShape2D.new()
		shape.name = "body_shape"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(18, 14)
		shape.shape = rect
		shape.position = Vector2(0, 4)
		add_child(shape)
	_bubble = Bubble.new()
	_bubble.npc = self
	add_child(_bubble)

func _physics_process(delta: float) -> void:
	if scripted or down:
		return
	velocity = Vector2.ZERO
	if pose == "panic":
		_panic_step(delta)
	elif path.size() > 1 and pose != "sit" and pose != "cower":
		if _pause > 0.0:
			_pause -= delta
		else:
			var to := path[_wp] - position
			if to.length() < 3.0:
				_wp = (_wp + 1) % path.size()
				_pause = randf_range(PAUSE.x, PAUSE.y)
			else:
				velocity = to.normalized() * WALK_SPEED
				_facing = Vector2(LsEngine.facing_to_vector(LsEngine.facing_from_vector(velocity, LsEngine.Facing.DOWN)))
	move_and_slide()

func _process(delta: float) -> void:
	_t += delta
	z_index = int(position.y) + 14
	var moved := position.distance_to(_last_pos)
	_phase += moved * 0.12
	_moving = moved > 0.05 or velocity.length() > 1.0
	if scripted and moved > 0.05:
		_facing = Vector2.LEFT
	_last_pos = position
	# one line in a bubble when Nash comes close
	_bark_cd = maxf(0.0, _bark_cd - delta)
	_bark_t = maxf(0.0, _bark_t - delta)
	# v0.5: shouting on their own (panic, the plant tech), wherever Nash is
	if shout and not down and (bark != "" or not barks.is_empty()):
		_shout_t -= delta
		if _shout_t <= 0.0:
			_shout_t = randf_range(SHOUT_EVERY.x, SHOUT_EVERY.y)
			_say_next()
			_bark_t = minf(BARK_SECONDS, _shout_t - 0.3)
			if _shouts_left > 0:
				_shouts_left -= 1
				if _shouts_left == 0:
					shout = false
	elif (bark != "" or not barks.is_empty()) and not down and nash != null and _bark_cd <= 0.0 and not nash.in_locker \
			and position.distance_to(nash.position) < BARK_RANGE:
		_say_next()
		if pose != "cower":
			_facing = Vector2(LsEngine.facing_to_vector(LsEngine.facing_from_vector(nash.position - position, LsEngine.Facing.DOWN)))
	_bubble.visible = _bark_t > 0.0
	_bubble.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var lk: Dictionary = LOOKS.get(look, LOOKS.coworker)
	if down:
		if hp <= 0:
			draw_circle(Vector2(2, 6), 17.0, Color("6e0a0e"))     # v0.5: killed by the infected
		A.shadow(self, Vector2(0, 8), 16, 6)
		A.ink_rect(self, Rect2(-14, -4, 28, 14), lk.body)
		A.ink_rect(self, Rect2(12, -6, 9, 9), lk.skin)
		A.ink_rect(self, Rect2(-20, -2, 8, 7), Color("2a2a32"))
		return
	var o := {"facing": _facing, "phase": _phase if not scripted else _t * 16.0,
		"amp": 1.0 if _moving else 0.0, "t": _t,
		"body": lk.body, "pants": lk.pants, "skin": lk.skin, "hair": lk.hair, "boots": Color("2a2a2e"),
		"glove": lk.skin, "pouches": look == "tech", "stubble": false, "band": lk.get("band", Color(0, 0, 0, 0)),
		"badge": look in ["office", "office2", "tech"]}
	match pose:
		"panic":
			# running with the arms up, a little bigger steps
			o.amp = 1.0 if _moving else 0.4
			A.person(self, o)
			A.ink_rect(self, Rect2(-11, -22, 4, 9), lk.skin, 1.2)
			A.ink_rect(self, Rect2(7, -22, 4, 9), lk.skin, 1.2)
		"sit":
			# sitting: a little lower and squatter, legs tucked
			draw_set_transform(Vector2(0, 5), 0.0, Vector2(1.0, 0.82))
			A.person(self, o)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"cower":
			# crouched with the arms over the head, shaking a little
			draw_set_transform(Vector2(sin(_t * 30.0) * 0.6, 7), 0.0, Vector2(1.05, 0.7))
			o.facing = Vector2.DOWN
			A.person(self, o)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			A.ink_rect(self, Rect2(-10, -16, 20, 5), lk.body, 1.5)
		"mop":
			A.person(self, o)
			# mop: a long handle to the side, a grey head on the floor, and a yellow bucket
			var hand := Vector2(13, 3)
			draw_line(hand + Vector2(0, -14), hand + Vector2(4, 12), A.INK, 4.0)
			draw_line(hand + Vector2(0, -14), hand + Vector2(4, 12), Color("c9a227"), 2.0)
			A.ink_rect(self, Rect2(hand.x - 3, 11, 14, 4), Color("b8bcc4"), 1.5)
		"phone":
			A.person(self, o)
			# looking down at a phone: a small glowing rectangle in the hands
			A.flat_rect(self, Rect2(-3, -2, 6, 8), Color("1a1d22"), 1.0)
			draw_rect(Rect2(-2, -1, 4, 5), Color("e8dcc0"))
		_:
			A.person(self, o)

## v0.5: running around in a panic: away from the closest infected if one is near, else to a random
## spot in the room, at a run.
func _panic_step(_delta: float) -> void:
	var threat: Node2D = null
	var td := FLEE_RANGE
	for e in world.infected():
		var d := position.distance_to(e.position)
		if d < td:
			td = d
			threat = e
	if threat != null:
		var away := (position - threat.position).normalized()
		if _flee_goal == Vector2.ZERO or _flee_goal.distance_to(position) < 12.0 \
				or (_flee_goal - position).normalized().dot(away) < 0.2:
			_flee_goal = world.open_point_near(position + away.rotated(randf_range(-0.6, 0.6)) * randf_range(90.0, 180.0))
	elif _flee_goal == Vector2.ZERO or _flee_goal.distance_to(position) < 12.0:
		_flee_goal = world.open_point_near(position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 200.0))
	var nxt: Vector2 = _pather.next_point(position, _flee_goal, get_physics_process_delta_time())
	var dir := nxt - position
	if dir.length() > 2.0:
		velocity = dir.normalized() * PANIC_SPEED
		_facing = Vector2(LsEngine.facing_to_vector(LsEngine.facing_from_vector(velocity, LsEngine.Facing.DOWN)))
	if get_real_velocity().length() < 5.0 and dir.length() > 2.0:
		_flee_goal = Vector2.ZERO      # stuck on something: pick another way

## The speech bubble (its own node so it draws above the furniture).
class Bubble extends Node2D:
	var npc: Node2D

	func _ready() -> void:
		z_as_relative = false
		z_index = 3000
		visible = false

	func _draw() -> void:
		var text: String = tr(npc.bark)
		var font := ThemeDB.fallback_font
		var fs := 9
		var width := 120.0
		var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, fs)
		var box := Rect2(Vector2(-sz.x * 0.5 - 6, -46 - sz.y), Vector2(sz.x + 12, sz.y + 8))
		var ink := Color("0e0e12")
		draw_rect(box.grow(1.5), ink)
		draw_rect(box, Color("f4f1e8"))
		var tail := PackedVector2Array([Vector2(-4, box.end.y), Vector2(4, box.end.y), Vector2(0, box.end.y + 6)])
		draw_colored_polygon(tail, ink)
		draw_colored_polygon(PackedVector2Array([Vector2(-2.5, box.end.y - 0.5), Vector2(2.5, box.end.y - 0.5),
			Vector2(0, box.end.y + 3.5)]), Color("f4f1e8"))
		draw_multiline_string(font, Vector2(-sz.x * 0.5, box.position.y + 4 + fs), text,
			HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, -1, ink)
