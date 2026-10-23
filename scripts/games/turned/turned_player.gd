extends Node2D

## The player: a placeholder figure drawn in code. Lies in bed, sits up, wipes the face (the hand
## slides down to the neck), then walks. Feet at the node's origin while standing; in the bed the
## origin is the middle of the bed. Movement slides along the area's walls and stops at people.

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Art = preload("res://scripts/games/turned/turned_art.gd")

const LOOK := {"coat": "3f4f6e", "skin": "cfc3c6", "accent": "8d8f98", "hat": ""}
const NIGHTSHIRT := Color("b9bccb")
const BLANKET := Color("3d4a68")

var radius := 9.0
var face := Vector2.DOWN
var moving := false
var scarf := false
var hobble := false           # aching before the mirror: a limp (a sway around the feet)
var sneak := false
## "lying", "sitting" (in bed) or "stand"
var pose := "stand"
var sit_t := 1.0              # 0 lying ... 1 sitting up (while in bed)
var holding_head := false     # hands on the head ("What happened last night?")
var wipe_t := -1.0            # 0..1 while the hand wipes the face and slides to the neck; -1 = off
var hurt := 0.0               # 0..1, flashes the figure when the sun burns
var ring_detect := 0.0        # the detection ring and noise ring, px (eased towards the targets)
var ring_noise := 0.0
var show_rings := false

var _phase := 0.0

func _ready() -> void:
	radius = T.f("player.radius")

## The hand's position (local) for a wipe progress 0..1: lap -> face -> a wipe across it -> neck.
func hand_at(t: float) -> Vector2:
	var neck_at := T.f("prologue.wipe_neck_at")
	if t < 0.2:
		return Vector2(10, -6).lerp(Vector2(3, -23), t / 0.2)
	if t < neck_at:
		var k := (t - 0.2) / (neck_at - 0.2)
		return Vector2(3 + sin(k * TAU * 1.5) * 3.0, -23.0 + k * 2.0)
	var j := clampf((t - neck_at) / (1.0 - neck_at), 0.0, 1.0)
	return Vector2(3, -21).lerp(Vector2(6, -14), j)

func _process(delta: float) -> void:
	hurt = maxf(0.0, hurt - delta * 2.5)
	var sway := sin(_phase * 0.9) * T.f("prologue.hobble_sway") if hobble and moving and pose == "stand" else 0.0
	rotation = lerpf(rotation, sway, 1.0 - exp(-14.0 * delta))
	queue_redraw()

## One frame of walking: `dir` is the d-pad/keyboard direction (any length up to 1), `blockers`
## are Node2D with a `radius` (people).
func walk(dir: Vector2, delta: float, area: RefCounted, speed: float, blockers: Array) -> void:
	moving = dir.length() > 0.05
	if not moving:
		return
	var d := dir.normalized()
	face = d
	var from := position
	var p: Vector2 = area.move_circle(position, d * speed * delta, radius)
	for b in blockers:
		var n: Node2D = b
		var min_d := radius + float(n.get("radius"))
		var off := p - n.position
		if off.length() < min_d:
			p = n.position + (off.normalized() if off.length() > 0.001 else d) * min_d
	if not area.is_free(p, radius):
		p = from
	position = p
	_phase += speed * delta * 0.22

func set_rings(detect_px: float, noise_px: float, delta: float, speed: float) -> void:
	ring_detect = move_toward(ring_detect, detect_px, speed * 60.0 * delta)
	ring_noise = move_toward(ring_noise, noise_px, speed * 60.0 * delta)

func _draw() -> void:
	if show_rings and ring_detect > 1.0:
		draw_arc(Vector2.ZERO, ring_detect, 0.0, TAU, 56, Color(0.8, 0.85, 1.0, 0.18), 1.5)
		draw_arc(Vector2.ZERO, ring_noise, 0.0, TAU, 40, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.3), 1.5)
	if pose == "stand":
		var a := 1.0
		var col := Color(1, 1, 1, 1).lerp(Color(1.0, 0.62, 0.55, 1), hurt)
		modulate = col
		Art.person(self, LOOK, face, _phase if moving else 0.0, sneak, scarf, "player", 0.82 if sneak else a)
		return
	modulate = Color.WHITE
	_draw_in_bed()

func _draw_in_bed() -> void:
	var skin := Art.SKIN_PALE
	var up := sit_t
	var head := Vector2(0, lerpf(-30.0, -22.0, up))
	Art.shadow(self, Vector2(0, 8), 26.0, 40.0, 0.12)
	# body: lying = a long shape under the blanket, sitting = shoulders over it
	var shoulders := Vector2(0, lerpf(-14.0, -8.0, up))
	draw_colored_polygon(Art.ellipse_points(shoulders, 12.0, lerpf(9.0, 8.0, up)), NIGHTSHIRT)
	draw_circle(head, 7.5, skin)
	draw_colored_polygon(Art.ellipse_points(head + Vector2(0, -3), 7.0, 4.5), Color("2a2222"))   # hair
	if up > 0.55:
		draw_circle(head + Vector2(-2.5, 0.5), 0.9, Color(0.08, 0.08, 0.1))
		draw_circle(head + Vector2(2.5, 0.5), 0.9, Color(0.08, 0.08, 0.1))
	# blanket over the legs
	var by := lerpf(-4.0, 6.0, up)
	draw_rect(Rect2(-27, by, 54, 52), BLANKET)
	draw_rect(Rect2(-27, by, 54, 5), Color(0.36, 0.42, 0.6))
	draw_rect(Rect2(-27, by, 54, 52), Color("1c2438"), false, 1.5)
	# hands
	if wipe_t >= 0.0:
		var h := hand_at(wipe_t)
		draw_circle(h + Vector2(0, head.y + 22.0), 3.2, skin)
		draw_circle(Vector2(-10, by + 2.0), 3.0, skin)
	elif holding_head:
		draw_circle(head + Vector2(-9.5, 2), 3.2, skin)
		draw_circle(head + Vector2(9.5, 2), 3.2, skin)
	else:
		draw_circle(Vector2(-11, by + 2.0), 3.0, skin)
		draw_circle(Vector2(11, by + 2.0), 3.0, skin)
