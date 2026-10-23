extends Node2D

## A y-sorted street prop (lamp post, tree trunk, stall, carriage, crate, barrel): a Node2D whose
## position is its base, drawn by turned_art.gd. Collision is the area's `solids`, not this node.

const Art = preload("res://scripts/games/turned/turned_art.gd")

var kind := ""
var data: Dictionary = {}

func setup(d: Dictionary) -> void:
	data = d
	kind = str(d["kind"])
	position = d["pos"]

func _draw() -> void:
	match kind:
		"lamp": Art.lamp(self, bool(data.get("dim", false)))
		"tree": Art.tree_trunk(self)
		"stall": Art.stall(self)
		"carriage": Art.carriage(self)
		"crate": Art.crate(self, data.get("size", Vector2(24, 24)))
		"barrel": Art.barrel(self, float(data.get("r", 9.0)))
