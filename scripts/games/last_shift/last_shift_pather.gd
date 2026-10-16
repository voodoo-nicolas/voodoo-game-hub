extends RefCounted

## Path following for enemies: asks the world for an A* path over the room's tile grid
## (walls and solid props are blocked), refreshes it a few times a second, and hands out the
## next waypoint. Fixes enemies getting stuck on corners and doorways.

var world: Node
var path := PackedVector2Array()
var index := 0
var goal := Vector2(-99999, -99999)
var age := 99.0

func _init(world_node: Node) -> void:
	world = world_node

## The point to walk toward right now to reach `target` from `pos`.
func next_point(pos: Vector2, target: Vector2, delta: float) -> Vector2:
	age += delta
	if path.is_empty() or age > 0.35 or goal.distance_to(target) > 24.0:
		path = world.path_to(pos, target)
		goal = target
		age = 0.0
		index = 1 if path.size() > 1 else 0
	while index < path.size() - 1 and pos.distance_to(path[index]) < 8.0:
		index += 1
	# Close enough (and probably in the open): walk straight at the target.
	if index >= path.size() or pos.distance_to(target) < 34.0:
		return target
	return path[index]

func reset() -> void:
	path = PackedVector2Array()
	age = 99.0
