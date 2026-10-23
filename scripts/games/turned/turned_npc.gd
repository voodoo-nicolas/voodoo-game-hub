extends Node2D

## A villager. Placeholder figure drawn in code. Data from turned_npcs.json: `knows_player` 0 =
## unaware, 1 = suspects, 2 = knows (the Watcher). Standing ones stay put; walking ones go back
## and forth along `path`, and wait when somebody is in the way. The Watcher turns to stare at
## the player's neck and never moves. Others glance at the player when the marks are uncovered.

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Art = preload("res://scripts/games/turned/turned_art.gd")

var id := ""
var data: Dictionary = {}
var knows_player := 0
var radius := 9.0
var face := Vector2.DOWN
var look: Dictionary = {}

var _path: Array = []
var _target := 0
var _wait := 0.0
var _phase := 0.0
var _moving := false
var _talk := 0.0
var _stare := false
var _walker := false

func setup(d: Dictionary) -> void:
	data = d
	id = str(d["id"])
	knows_player = int(d.get("knows_player", 0))
	look = d.get("look", {})
	var p: Array = d["pos"]
	position = Vector2(float(p[0]), float(p[1]))
	var f: Array = d.get("face", [0, 1])
	face = Vector2(float(f[0]), float(f[1])).normalized()
	_stare = bool(d.get("stare", false))
	_walker = str(d.get("behavior", "stand")) == "walk"
	if _walker:
		for pt in d["path"]:
			_path.append(Vector2(float(pt[0]), float(pt[1])))
		_target = 1

func is_walker() -> bool:
	return _walker

## Called when the player talks to this villager: stop and face the player for a moment.
func talk_to(player_pos: Vector2) -> void:
	_talk = 3.2
	_face_toward(player_pos, 1.0)

func _face_toward(p: Vector2, k: float) -> void:
	var d := p - position
	if d.length() > 1.0:
		face = face.lerp(d.normalized(), k).normalized()

## Moves one frame. `player` is the player node (position, scarf), `others` other Node2D to avoid.
func tick(delta: float, player: Node2D, others: Array) -> void:
	_phase += delta
	var to_player := player.position.distance_to(position)
	var exposed: bool = not player.scarf
	if _talk > 0.0:
		_talk -= delta
		_moving = false
		_face_toward(player.position, 0.3)
		queue_redraw()
		return
	if _stare and to_player < T.m(T.f("npc.stare_range_m")):
		_face_toward(player.position, minf(1.0, delta * 6.0))
	elif knows_player == 0 and exposed and to_player < T.m(T.f("npc.glance_range_m")):
		_face_toward(player.position, minf(1.0, delta * 4.0))
	_moving = false
	if _walker:
		if _wait > 0.0:
			_wait -= delta
		else:
			var goal: Vector2 = _path[_target]
			var dir := goal - position
			if dir.length() < 2.0:
				_target = (_target + 1) % _path.size()
				_wait = 1.6
			else:
				dir = dir.normalized()
				if _blocked(dir, player, others):
					_moving = false
				else:
					position += dir * T.f("npc.walk_speed") * delta
					face = dir
					_moving = true
	queue_redraw()

func _blocked(dir: Vector2, player: Node2D, others: Array) -> bool:
	var ahead := position + dir * T.f("npc.blocked_range_px")
	if ahead.distance_to(player.position) < radius + float(player.get("radius")) + 4.0:
		return true
	for o in others:
		if o != self and ahead.distance_to((o as Node2D).position) < radius * 2.0:
			return true
	return false

func _draw() -> void:
	Art.person(self, look, face, _phase * 6.0 if _moving else 0.0, false, false, "npc_" + id)
