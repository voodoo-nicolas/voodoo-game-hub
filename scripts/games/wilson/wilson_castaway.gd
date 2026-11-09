extends Node2D

## Beached: the castaway, from the owner's character sheets (8 looks x 19 poses, cut by
## tools/wilson_art.py into games/wilson/art/chars/<look>_<pose>.webp). Origin = the feet, in plate
## pixels. Walk frames face left on the sheets; `facing` 1 (right) mirrors them. Walking cycles walk1-4; standing
## still for a while plays a fidget (shrug, facepalm, sit...). If a texture is missing the old
## rectangle placeholder is drawn instead.

const ART := "res://games/wilson/art/chars/"
const POSES := ["idle", "walk1", "walk2", "walk3", "walk4", "run", "sit", "sleep", "hammock", "fish",
	"chop", "craft", "eat", "drink", "shrug", "wave", "facepalm", "sulk", "collapse"]
const LOOKS := ["male1", "male2", "male3", "male4", "female1", "female2", "female3", "female4", "female5"]
## Standing height on screen (plate pixels) at the middle lane.
const HEIGHT := 124.0
const SKIN := Color("e0a878")

var look := "male1"
var pose := "idle"         # set by the game: idle / walk / work / chop / fish / sleep / hammock / collapse
var facing := -1.0         # -1 left (as drawn), 1 right
var target := Vector2.ZERO
var walking := false
var mood := 60.0           # the engine's mood: low mood fidgets with a sulk
var _t := 0.0
var _tex := {}
var _fidget := ""
var _fidget_until := 0.0
var _next_fidget := 8.0
var _once := ""            # a short pose on top (eat, drink, wave, shrug) until _once_until
var _once_until := 0.0

signal arrived

func _ready() -> void:
	set_look(look)

func set_look(l: String) -> void:
	look = l if l in LOOKS else "male1"
	_tex = {}
	for p in POSES:
		var path := ART + "%s_%s.webp" % [look, p]
		if ResourceLoader.exists(path):
			_tex[p] = load(path)
	queue_redraw()

## A short pose (eat, drink, wave, shrug, facepalm) for `secs` seconds.
func play_once(p: String, secs := 1.6) -> void:
	_once = p
	_once_until = _t + secs

func _process(dt: float) -> void:
	_t += dt
	if walking:
		var to := target - position
		var step := 150.0 * dt
		if absf(to.x) > 2.0:
			facing = signf(to.x)
		if to.length() <= step:
			position = target
			walking = false
			arrived.emit()
		else:
			position += to.normalized() * step
	if pose == "idle" and not walking:
		if _fidget == "" and _t > _next_fidget:
			var pool := ["shrug", "facepalm", "sit", "idle"] if mood >= 35.0 else ["sulk", "facepalm", "sit"]
			_fidget = pool[randi() % pool.size()]
			_fidget_until = _t + (6.0 if _fidget in ["sit", "sulk"] else 2.0)
		elif _fidget != "" and _t > _fidget_until:
			_fidget = ""
			_next_fidget = _t + randf_range(8.0, 16.0)
	else:
		_fidget = ""
		_next_fidget = _t + randf_range(8.0, 16.0)
	queue_redraw()

func walk_to(p: Vector2) -> void:
	target = p
	walking = position.distance_to(p) > 2.0
	if not walking:
		arrived.emit()

## Which sheet pose to show now.
func current_pose() -> String:
	if _once != "" and _t < _once_until and not walking and pose in ["idle", "work"]:
		return _once
	if walking or pose == "walk":
		return "walk%d" % (int(_t * 8.0) % 4 + 1)
	match pose:
		"work":
			return "craft"
		"idle":
			return _fidget if _fidget != "" else "idle"
	return pose

## Head position in plate pixels (for the thought bubble).
func head_global() -> Vector2:
	var p := current_pose()
	if p in ["sleep", "collapse"]:
		return position + Vector2(0, -40)
	if p == "hammock":
		return position + Vector2(0, -60)
	if p in ["sit", "sulk", "craft", "fish"]:
		return position + Vector2(0, -HEIGHT * 0.8)
	return position + Vector2(0, -HEIGHT)

func _scale() -> float:
	var depth := clampf((position.y - 430.0) / 110.0, 0.0, 1.0)
	return lerpf(0.9, 1.08, depth)

const FACING_POSES := ["idle", "run", "sit", "eat", "drink", "shrug", "wave", "facepalm", "sulk"]

func _draw() -> void:
	var p := current_pose()
	var tex: Texture2D = _tex.get(p)
	if tex == null:
		_draw_placeholder()
		return
	var idle: Texture2D = _tex.get("idle", tex)
	var k := HEIGHT / float(idle.get_height()) * _scale()
	var sz := tex.get_size() * k
	if p != "hammock":
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, sz.x * 0.32, Color(0, 0, 0, 0.2))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	# walk frames face right on the sheets (checked on the owner's phone 2026-11-09): mirror them when walking left
	# the sheets face right: mirror every standing / walking pose when he faces left, so he stays turned
	# the way he last walked (owner, 2026-11-09). Sleeping, hammock and collapse are lying poses: as drawn.
	var flip := facing < 0.0 and (p.begins_with("walk") or p in FACING_POSES)
	var at := Vector2(-sz.x / 2.0, -sz.y + 4.0 * k)
	if p == "hammock":
		at = Vector2(-sz.x / 2.0, -sz.y * 0.75)
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect(tex, Rect2(at, sz), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_placeholder() -> void:
	draw_rect(Rect2(-12, -90, 24, 50), Color("efe9d8"))
	draw_rect(Rect2(-10, -40, 20, 40), Color("3b4f74"))
	draw_circle(Vector2(0, -102), 12.0, SKIN)
