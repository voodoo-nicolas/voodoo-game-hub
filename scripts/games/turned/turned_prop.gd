extends Node2D

## A y-sorted street prop (lamp post, tree trunk, stall, carriage, crate, barrel): a Node2D whose
## position is its base, drawn by turned_art.gd. Collision is the area's `solids`, not this node.
## Kind "lib" is a sprite from the hub's shared sprite library (docs/claude/sprite-library.md):
## `sprite` = its id, drawn 1 sprite px = 1 world px with its bottom centre on the base (pixel art,
## nearest filter); `lift` raises it (an owl on a branch) without changing its y-sort; `fly` =
## [radius x, radius y, laps per second] circles it round its base, above everything (bats).
## Decoration only: no collision, nothing to do.

const Art = preload("res://scripts/games/turned/turned_art.gd")
const SpriteLib = preload("res://scripts/games/turned/sprite_lib.gd")

var kind := ""
var data: Dictionary = {}
var _base := Vector2.ZERO
var _phase := 0.0

func setup(d: Dictionary) -> void:
	data = d
	kind = str(d["kind"])
	position = d["pos"]
	_base = position
	if kind == "lib":
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if data.has("fly"):
			z_index = 20
			_phase = fmod(_base.x * 0.013, TAU)  # bats out of step with each other

func _process(dt: float) -> void:
	if not data.has("fly"):
		set_process(false)  # Godot turns processing on when a node with _process enters the tree
		return
	var f: Array = data["fly"]
	_phase += dt * TAU * float(f[2])
	position = _base + Vector2(cos(_phase) * float(f[0]), sin(_phase) * float(f[1]) + sin(_phase * 3.0) * 4.0)
	queue_redraw()

func _draw() -> void:
	match kind:
		"lib": _draw_lib()
		"lamp": Art.lamp(self, bool(data.get("dim", false)))
		"tree": Art.tree_trunk(self)
		"stall": Art.stall(self)
		"carriage": Art.carriage(self)
		"crate": Art.crate(self, data.get("size", Vector2(24, 24)))
		"barrel": Art.barrel(self, float(data.get("r", 9.0)))

func _draw_lib() -> void:
	var t := SpriteLib.texture(str(data["sprite"]))
	if t == null:
		return
	var size := t.get_size()
	var lift := float(data.get("lift", 0.0))
	var flying := data.has("fly")
	if flying:
		size.y *= 0.7 + 0.3 * absf(sin(_phase * 9.0))  # wing beats: a quick squash (the bat faces us)
	elif lift == 0.0:
		Art.shadow(self, Vector2(0, -1), size.x * 0.45, maxf(2.0, size.y * 0.12), 0.25)
	draw_texture_rect(t, Rect2(Vector2(-size.x * 0.5, -size.y - lift), size), false)
