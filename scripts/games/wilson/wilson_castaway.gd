extends Node2D

## Beached: the castaway, from the owner's character sheets (8 looks x 19 poses, cut by
## tools/wilson_art.py into games/wilson/art/chars/<look>_<pose>.webp). Origin = the feet, in plate
## pixels. Walk frames face left on the sheets; `facing` 1 (right) mirrors them. Walking cycles walk1-4; standing
## still for a while plays a fidget (shrug, facepalm, sit...). If a texture is missing the old
## rectangle placeholder is drawn instead.

const ART := "res://games/wilson/art/chars/"
const POSES := ["idle", "walk1", "walk2", "walk3", "walk4", "run", "sit", "sleep", "hammock", "fish",
	"chop", "craft", "eat", "drink", "shrug", "wave", "facepalm", "sulk", "collapse"]
## Extra poses only the blonde (female5) has: the fishing cycle and three kinds of handwork.
const EXTRA := ["carve", "weave", "tool", "f_ready", "f_back", "f_swing", "f_wait", "f_bite", "f_strike", "f_reel"]
## The fishing cycle as [pose, seconds]; it loops while he fishes.
const FISH_CYCLE := [["f_ready", 1.6], ["f_back", 0.5], ["f_swing", 0.6], ["f_wait", 4.0], ["f_bite", 1.0], ["f_strike", 0.8], ["f_reel", 1.6]]
const LOOKS := ["male1", "male2", "male3", "male4", "female1", "female3", "female4", "female5"]
## Easter-egg looks (owner, 2026-11-20): never in the picker; the engine's `shown_look()` picks them by name.
const SPECIAL := ["nicolas"]
## Job frames: a running action / pastime may have its own pictures, <look>_job_<id>_<n>.webp (Nicolas's
## action sheet) or job_<id>_<n>.webp (the blonde's secret odd jobs); they cycle while the job runs.
## Some jobs borrow another job's pictures.
const JOB_ALIAS := {"practise_roast": "roast", "bank_embers": "fan_fire", "comb": "search_sand", "shake_rocks": "search_sand",
	"dig_clay": "dig", "practise_cast": "fish", "read_sky": "peek", "horizon": "peek", "learn_plants": "search_sand",
	"knot_practice": "carve", "fiddle_junk": "carve", "stretch": "yoga", "salvage": "haul",
	"egg_beber": "egg_drink", "egg_llorar": "egg_cry"}
const JOB_FRAME_S := 0.9
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
var job := ""              # the running action kind or pastime id (set by the game; "" = none)
var _jobs := {}            # job id -> Array of textures (cached, empty = none)

signal arrived

func _ready() -> void:
	set_look(look)

func set_look(l: String) -> void:
	if l == "female2":      # dropped 2026-11-10 (a twin of female5): old saves get the other blonde
		l = "female5"
	look = l if l in LOOKS or l in SPECIAL else "male1"
	_tex = {}
	_jobs = {}
	for p in POSES + EXTRA:
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
			return _variant("craft")
		"idle":
			return _fidget if _fidget != "" else "idle"
	return _variant(pose)

## The blonde's own versions of a pose (fishing cycle, handwork); other looks keep the plain one.
func _variant(p: String) -> String:
	if p == "fish" and _tex.has("f_ready"):
		var total := 0.0
		for st in FISH_CYCLE:
			total += float(st[1])
		var k := fmod(_t, total)
		for st in FISH_CYCLE:
			k -= float(st[1])
			if k < 0.0 and _tex.has(str(st[0])):
				return str(st[0])
	if p == "craft" and _tex.has("carve"):
		return ["craft", "carve", "tool"][int(_t / 7.0) % 3]
	return p

## The job's own frames (see JOB_ALIAS), [] when it has none.
func job_frames(id: String) -> Array:
	if id == "":
		return []
	if not _jobs.has(id):
		var out: Array = []
		for key in [id, str(JOB_ALIAS.get(id, ""))]:
			if key == "" or not out.is_empty():
				continue
			for pre in ["%s_job_%s_" % [look, key], "job_%s_" % key]:
				var n := 1
				while ResourceLoader.exists(ART + pre + "%d.webp" % n):
					out.append(load(ART + pre + "%d.webp" % n))
					n += 1
				if not out.is_empty():
					break
		_jobs[id] = out
	return _jobs[id]

## Head position in plate pixels (for the thought bubble).
func head_global() -> Vector2:
	var p := current_pose()
	if p in ["sleep", "collapse"]:
		return position + Vector2(0, -40)
	if p == "hammock":
		return position + Vector2(0, -60)
	if p in ["sit", "sulk", "craft", "fish", "carve", "weave", "tool", "f_sit", "f_wait", "f_bite", "f_strike"]:
		return position + Vector2(0, -HEIGHT * 0.8)
	return position + Vector2(0, -HEIGHT)

func _scale() -> float:
	var depth := clampf((position.y - 430.0) / 110.0, 0.0, 1.0)
	return lerpf(0.9, 1.08, depth)

# craft / carve / weave / tool / chop added 2026-11-19: they never mirrored, so she knelt with her back to the pebbles
# const FACING_POSES := ["idle", "run", "sit", "eat", "drink", "shrug", "wave", "facepalm", "sulk", "craft", "carve", "weave", "tool", "chop"]
const FACING_POSES := ["idle", "run", "sit", "eat", "drink", "shrug", "wave", "facepalm", "sulk", "carve", "chop"]
## Poses drawn looking LEFT on the sheets (the basket, the rope tool, weaving): mirrored when she faces right.
## (2026-11-20: mirroring them like the right-facing ones turned her away from the pebbles, owner's photo.)
const LEFT_POSES := ["craft", "weave", "tool"]

func _draw() -> void:
	var p := current_pose()
	var tex: Texture2D = _tex.get(p)
	var frames: Array = job_frames(job) if not walking and pose not in ["idle", "walk", "sleep", "hammock", "collapse"] else []
	if not frames.is_empty():
		tex = frames[int(_t / JOB_FRAME_S) % frames.size()]
		p = "craft"         # job frames turn with him like the work poses
	if tex == null:
		_draw_placeholder()
		return
	var idle: Texture2D = _tex.get("idle", tex)
	var k := HEIGHT / float(idle.get_height()) * _scale()
	var sz := tex.get_size() * k
	if p in ["idle", "sit", "shrug", "sulk", "facepalm"]:      # breathing: a slow 1 % rise from the feet
		sz.y *= 1.0 + 0.012 * sin(_t * 2.1)
	if p != "hammock":
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, sz.x * 0.32, Color(0, 0, 0, 0.2))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	# walk frames face right on the sheets (checked on the owner's phone 2026-11-09): mirror them when walking left
	# the sheets face right: mirror every standing / walking pose when he faces left, so he stays turned
	# the way he last walked (owner, 2026-11-09). Sleeping, hammock and collapse are lying poses: as drawn.
	var flip := (facing < 0.0 and (p.begins_with("walk") or p in FACING_POSES)) or (facing > 0.0 and p in LEFT_POSES)
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
