extends Node2D

## The player: a placeholder figure drawn in code. Lies in bed, sits up, wipes the face (the hand
## slides down to the neck), then walks. Feet at the node's origin while standing; in the bed the
## origin is the middle of the bed. Movement slides along the area's walls and stops at people.

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Art = preload("res://scripts/games/turned/turned_art.gd")
const Area = preload("res://scripts/games/turned/turned_area.gd")

## The owner's bed pictures (SL-01 asleep, SL-02 sitting up; DECISIONS B-21), cut by tools/turned_bed_cuts.py:
## the box they cover in the upstairs painting's px (keep it the same as BOX there).
const BED_BOX := Rect2(56, 436, 348, 312)
## The storeroom cot in the cigar shop painting (painting px), the box tools/turned_bed_cuts.py cuts out of the
## owner's SL-03 / SL-04 (DECISIONS B-26)
const COT_BOX := Rect2(995, 470, 210, 315)

const LOOK := {"coat": "3f4f6e", "skin": "cfc3c6", "accent": "8d8f98", "hat": ""}
const NIGHTSHIRT := Color("e3d9c0")         # her cream blouse: she sleeps in her own clothes (DECISIONS B-17; was a grey nightshirt, b9bccb)
const BLANKET := Color("3d4a68")
const HAIR := Color("7a3418")       # auburn (DECISIONS P-1)

var radius := 9.0
var face := Vector2.DOWN
var moving := false
var scarf := false
var hobble := false           # aching before the mirror: a limp (a sway around the feet)
var sneak := false
## "lying", "sitting" (in bed) or "stand"
var pose := "stand"
var own_blanket := false      # the bed under her is painted with its blanket: draw none (the world sets it per area)
var sit_t := 1.0              # 0 lying ... 1 sitting up (while in bed)
var cot_t := -1.0             # on the storeroom cot: 0 out cold ... 1 come round; -1 = not on it
var cot_goal := 0.0
var holding_head := false     # hands on the head ("What happened last night?")
var wipe_t := -1.0            # 0..1 while the hand wipes the face and slides to the neck; -1 = off
var hurt := 0.0               # 0..1, flashes the figure when the sun burns
var ring_detect := 0.0        # the detection ring and noise ring, px (eased towards the targets)
var ring_noise := 0.0
var show_rings := false

var _phase := 0.0
var _stride := 0.0             # world px walked, for the walk cycle frames (player_<dir>_w0..w3)

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
	# standing people take the area's size (Art.people_k); lying in a painted bed she fits the painting as is
	scale = Vector2.ONE * (Art.people_k if pose == "stand" else 1.0)
	if cot_t >= 0.0:
		cot_t = move_toward(cot_t, cot_goal, delta / 1.2)
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
	_stride += from.distance_to(p)
	position = p
	_phase += speed * delta * 0.22

func set_rings(detect_px: float, noise_px: float, delta: float, speed: float) -> void:
	ring_detect = move_toward(ring_detect, detect_px, speed * 60.0 * delta)
	ring_noise = move_toward(ring_noise, noise_px, speed * 60.0 * delta)

func _draw() -> void:
	if not sneak:
		ring_detect = 0.0      # owner 2026-11-08: no rings at all while walking; they grow out again on sneak
		ring_noise = 0.0
	elif show_rings and ring_detect > 1.0:
		var rk := 1.0 / maxf(scale.x, 0.01)      # the rings are world distances: not scaled with her
		draw_arc(Vector2.ZERO, ring_detect * rk, 0.0, TAU, 56, Color(0.8, 0.85, 1.0, 0.18), 1.5 * rk)
		draw_arc(Vector2.ZERO, ring_noise * rk, 0.0, TAU, 40, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.3), 1.5 * rk)
	if cot_t >= 0.0 and _draw_on_cot():
		return
	if pose == "stand":
		var a := 1.0
		var col := Color(1, 1, 1, 1).lerp(Color(1.0, 0.62, 0.55, 1), hurt)
		modulate = col
		_draw_standing(0.82 if sneak else a)
		return
	modulate = Color.WHITE
	if own_blanket:
		_draw_in_painted_bed()
	else:
		_draw_in_bed()

## Standing: a slim young woman in a long dark dress, auburn hair to the shoulders (owner 2026-11-03: the
## old round figure read as "a fat blob"). Painted sprites (player_down / _up / _side) replace it by name.
func _draw_standing(alpha: float) -> void:
	var dir := "down" if face.y > 0.35 else ("up" if face.y < -0.35 else "side")
	var pic := "player_" + dir
	if Art.tex(pic + "_w0") != null:
		# her walk cycle (owner's sheets WK-01..03, DECISIONS B-18): four frames, one every walk_frame_px she
		# walks (half a footstep); standing she holds the passing frame, so her clothes match the walk
		var f := int(_stride / T.f("player.walk_frame_px")) % 4 if moving else 1
		pic += "_w%d" % f
	if Art.tex(pic) != null:
		Art.shadow(self, Vector2(0.5, 0.5), 9.0, 3.4, 0.36 * alpha)
	if Art.sprite(self, pic, Vector2(0.5, 0.92), alpha, dir == "side" and face.x < 0.0, Art.PERSON_CANVAS_H):
		if scarf:
			# the painted sprite has no scarf: wind one round the neck (feet at 0, the head's top about 46 px up)
			var nx := 0.0 if dir != "side" else signf(face.x) * 0.6
			draw_colored_polygon(Art.ellipse_points(Vector2(nx, -38.5), 4.6, 2.2), Color(Art.SCARF.r, Art.SCARF.g, Art.SCARF.b, alpha))
			draw_colored_polygon(Art.ellipse_points(Vector2(nx - 1.0, -39.1), 2.6, 0.9), Color(1, 1, 1, 0.2 * alpha))
		return
	var walk := _phase if moving else 0.0
	var dress := Color(str(LOOK["coat"]))
	var skin := Color(str(LOOK["skin"]))
	var line := Color(0.04, 0.04, 0.07, 0.85 * alpha)
	dress.a = alpha
	skin.a = alpha
	var hair := Color(HAIR.r, HAIR.g, HAIR.b, alpha)
	var side := 0.0 if dir != "side" else signf(face.x)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(Art.PERSON_SCALE, (0.88 if sneak else 1.0) * Art.PERSON_SCALE))
	Art.shadow(self, Vector2(0.5, 1.5), 8.0, 3.6, 0.34 * alpha)
	var swing := sin(walk) * 2.4
	# shoes peeking under the hem as she walks
	var shoe := Color(0.06, 0.05, 0.07, alpha)
	draw_rect(Rect2(-4.0 + side * 1.5, -1.0 + swing * 0.5, 3.4, 2.4), shoe)
	draw_rect(Rect2(0.6 + side * 1.5, -1.0 - swing * 0.5, 3.4, 2.4), shoe)
	# seen from behind, the hair covers the back of the head and falls to the shoulders
	if dir == "up":
		draw_colored_polygon(Art.ellipse_points(Vector2(0, -23.5), 5.2, 4.6), hair)
	# the skirt: narrow at the waist, flaring to the hem, swaying a little as she walks
	var hem := 6.8
	var sw := swing * 0.35
	var skirt := PackedVector2Array([Vector2(-3.6, -14.5), Vector2(3.6, -14.5), Vector2(hem + sw, 0.0), Vector2(-hem + sw, 0.0)])
	draw_colored_polygon(skirt, dress)
	draw_colored_polygon(PackedVector2Array([Vector2(-hem * 0.8 + sw, -3.2), Vector2(hem * 0.8 + sw, -3.2), Vector2(hem + sw, 0.0), Vector2(-hem + sw, 0.0)]), Art.tinted(dress, 0.7))
	var ol := skirt.duplicate()
	ol.append(skirt[0])
	draw_polyline(ol, line, 1.1)
	# arms: thin sleeves to small hands (from the side, one arm swinging in front of her)
	var hands: Array = [Vector2(-5.6, -11.5 + swing * 0.5), Vector2(5.6, -11.5 - swing * 0.5)]
	if side != 0.0:
		hands = [Vector2(side * 1.0 + swing * 0.9, -11.0)]
	for hand in hands:
		var sh := Vector2(signf(hand.x) * 3.6 if side == 0.0 else 0.0, -21.0)
		draw_line(sh, hand, line, 3.4)
		draw_line(sh, hand, Art.tinted(dress, 0.85), 2.0)
		draw_circle(hand, 1.4, Art.tinted(skin, 0.85))
	# the bodice: narrow shoulders down to the waist
	var w := 4.2 if side == 0.0 else 3.2
	var body := PackedVector2Array([Vector2(-w, -21.8), Vector2(w, -21.8), Vector2(w - 0.8, -14.2), Vector2(-w + 0.8, -14.2)])
	draw_colored_polygon(body, dress)
	draw_colored_polygon(Art.ellipse_points(Vector2(-1.2, -19.5), 2.2, 1.6), Color(1, 1, 1, 0.12 * alpha))
	var bol := body.duplicate()
	bol.append(body[0])
	draw_polyline(bol, line, 1.1)
	draw_line(Vector2(-w + 0.8, -14.4), Vector2(w - 0.8, -14.4), Color(0, 0, 0, 0.35 * alpha), 1.0)   # the waist
	# the neck, then the scarf over it
	draw_rect(Rect2(-1.2, -23.6, 2.4, 2.2), skin)
	if scarf:
		draw_colored_polygon(Art.ellipse_points(Vector2(0, -22.4), 4.6, 2.2), Color(Art.SCARF.r, Art.SCARF.g, Art.SCARF.b, alpha))
		draw_colored_polygon(Art.ellipse_points(Vector2(-1.0, -23.0), 2.6, 0.9), Color(1, 1, 1, 0.2 * alpha))
	# the head: hair behind, the face, the hair on top
	var hc := Vector2(0, -27.8)
	if dir == "down":
		draw_colored_polygon(Art.ellipse_points(hc + Vector2(0, 1.2), 5.9, 6.4), hair)    # hair down to the shoulders
	elif dir == "side":
		draw_colored_polygon(Art.ellipse_points(hc + Vector2(-side * 2.6, 2.6), 3.4, 5.0), hair)
	draw_circle(hc, 5.4, line)
	draw_circle(hc, 4.7, skin)
	var eye := Color(0.08, 0.08, 0.1, alpha)
	match dir:
		"down":
			draw_circle(hc + Vector2(-1.8, 0.6), 0.75, eye)
			draw_circle(hc + Vector2(1.8, 0.6), 0.75, eye)
			draw_line(hc + Vector2(-0.8, 2.7), hc + Vector2(0.8, 2.7), Color(0.45, 0.2, 0.2, 0.7 * alpha), 0.7)
			draw_colored_polygon(Art.ellipse_points(hc + Vector2(0, -2.8), 5.3, 2.6), hair)        # the parting and fringe
		"side":
			draw_circle(hc + Vector2(side * 2.4, 0.4), 0.75, eye)
			draw_circle(hc + Vector2(side * 4.7, 1.2), 0.7, skin)                                  # a nose in profile
			draw_colored_polygon(Art.ellipse_points(hc + Vector2(-side * 1.3, -2.2), 4.8, 3.2), hair)
		_:
			draw_colored_polygon(Art.ellipse_points(hc + Vector2(0, -0.5), 5.2, 5.0), hair)        # the back of the head
	draw_colored_polygon(Art.ellipse_points(hc + Vector2(-1.6, -3.2), 1.8, 0.8), Color(1, 0.75, 0.55, 0.22 * alpha))   # light on the hair
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## On the storeroom cot after the blackout: the owner's pictures of her on it (out cold, then up on one elbow
## with her hand at the collar), laid over the cigar shop painting; she is drawn there instead of standing.
## False when the pictures are missing (an old pack's art): she stands beside the cot as before.
func _draw_on_cot() -> bool:
	var out := Art.tex("cot_out")
	var waking := Art.tex("cot_waking")
	if out == null or waking == null:
		return false
	modulate = Color.WHITE
	var rk := 1.0 / maxf(scale.x, 0.01)       # the box is in world px: undo her people scale
	var r := Rect2((COT_BOX.position * Area.RM_K - position) * rk, COT_BOX.size * Area.RM_K * rk)
	draw_texture_rect(out, r, false)
	var k := smoothstep(0.0, 1.0, cot_t)
	if k > 0.0:
		draw_texture_rect(waking, r, false, Color(1, 1, 1, k))
	return true

## In the painted bed (house_up): the bed runs left to right with the pillows on the left, so she lies
## with her head on the pillow and sits up facing the foot of the bed, the viewer's right (owner
## 2026-11-03). The painting has the blanket; this draws her and a fold of it over her legs. The origin
## is the middle of the bed.
func _draw_in_painted_bed() -> void:
	var asleep := Art.tex("bed_asleep")
	var sitting := Art.tex("bed_sitting")
	if asleep != null and sitting != null:
		# the owner's pictures of her in this bed, laid over the painting: asleep, then fading into sitting up
		# (her hand already at her neck); the drawn figure below is the fallback
		var r := Rect2(BED_BOX.position * Area.UP_K - position, BED_BOX.size * Area.UP_K)
		draw_texture_rect(asleep, r, false)
		var k := smoothstep(0.15, 0.85, sit_t)
		if k > 0.0:
			draw_texture_rect(sitting, r, false, Color(1, 1, 1, k))
		return
	var skin := Art.SKIN_PALE
	var up := sit_t
	var sheet := Color(0.80, 0.80, 0.84)
	var sheet_dark := Color(0.58, 0.58, 0.64)
	var head := Vector2(-14.5, -13.0).lerp(Vector2(-12.0, -26.0), up)
	# lying: the painted blanket covers her, only a fold over the shoulder; sitting: the nightgown upright
	# at the pillow end, down to where the blanket starts
	if up < 0.5:
		draw_colored_polygon(Art.ellipse_points(head + Vector2(9.0, 1.5), 5.0, 3.6), sheet_dark)
		draw_colored_polygon(Art.ellipse_points(head + Vector2(9.0, 0.8), 4.4, 2.8), sheet)
	var torso_top := head + Vector2(-0.5, 5.5)
	var torso_bot := head + Vector2(0.5, 15.0)
	if up >= 0.15:
		var a := clampf((up - 0.15) / 0.35, 0.0, 1.0)
		var gown := Color(NIGHTSHIRT.r, NIGHTSHIRT.g, NIGHTSHIRT.b, a)
		draw_colored_polygon(PackedVector2Array([torso_top + Vector2(-3.4, 0), torso_top + Vector2(3.4, 0), torso_bot + Vector2(4.6, 0), torso_bot + Vector2(-4.6, 0)]), gown)
		draw_polyline(PackedVector2Array([torso_bot + Vector2(-4.6, 0), torso_top + Vector2(-3.4, 0), torso_top + Vector2(3.4, 0), torso_bot + Vector2(4.6, 0)]), Color(0.04, 0.04, 0.07, 0.6 * a), 1.0)
	# hair: spread on the pillow while lying, down her back once she sits up
	if up < 0.5:
		draw_colored_polygon(Art.ellipse_points(head + Vector2(-3.0, 0.5), 7.5, 6.0), HAIR)
	else:
		draw_colored_polygon(Art.ellipse_points(head + Vector2(-2.6, 2.5), 4.6, 7.0), HAIR)
	draw_circle(head, 5.4, Color(0.04, 0.04, 0.07, 0.85))
	draw_circle(head, 4.7, skin)
	if up < 0.5:
		# on her back: closed eyes, hair round the face
		draw_line(head + Vector2(-0.6, -1.9), head + Vector2(0.6, -1.9), Color(0.1, 0.08, 0.1, 0.8), 0.8)
		draw_line(head + Vector2(-0.6, 1.9), head + Vector2(0.6, 1.9), Color(0.1, 0.08, 0.1, 0.8), 0.8)
		draw_colored_polygon(Art.ellipse_points(head + Vector2(-3.2, 0.0), 2.6, 4.8), HAIR)
	else:
		# sitting: in profile, looking towards the foot of the bed
		draw_colored_polygon(Art.ellipse_points(head + Vector2(-1.6, -2.0), 4.9, 3.4), HAIR)
		draw_circle(head + Vector2(2.4, 0.4), 0.8, Color(0.08, 0.08, 0.1))
		draw_circle(head + Vector2(4.7, 1.2), 0.7, skin)
	# hands
	if wipe_t >= 0.0:
		draw_circle(head + _bed_hand_at(wipe_t), 1.9, skin)
		draw_circle(torso_bot + Vector2(4.0, -1.0), 1.8, skin)
	elif holding_head:
		draw_circle(head + Vector2(-2.0, -4.5), 1.9, skin)
		draw_circle(head + Vector2(3.5, -3.5), 1.9, skin)
	elif up >= 0.5:
		draw_circle(torso_bot + Vector2(4.0, -1.0), 1.8, skin)
		draw_circle(torso_bot + Vector2(6.0, 0.5), 1.8, skin)

## The wiping hand in the painted bed, relative to the head: lap -> face -> a wipe across it -> neck.
func _bed_hand_at(t: float) -> Vector2:
	var neck_at := T.f("prologue.wipe_neck_at")
	if t < 0.2:
		return Vector2(4.5, 14.0).lerp(Vector2(4.0, 0.5), t / 0.2)
	if t < neck_at:
		var k := (t - 0.2) / (neck_at - 0.2)
		return Vector2(4.0 + sin(k * TAU * 1.5) * 1.5, 0.5 - sin(k * TAU * 1.5) * 1.5)
	var j := clampf((t - neck_at) / (1.0 - neck_at), 0.0, 1.0)
	return Vector2(4.0, 0.5).lerp(Vector2(2.0, 6.5), j)

## The old drawn bed (an area without a painted bed): a figure facing the viewer under a drawn blanket.
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
	if not own_blanket:     # a painted bedroom has its own blanket
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
