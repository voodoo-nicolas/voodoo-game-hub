extends SceneTree

## The hub's boot cover shows once, then fades and frees itself.
var hub: Node
var frames := 0

func _initialize() -> void:
	hub = load("res://scenes/hub/hub.tscn").instantiate()
	root.add_child(hub)

func _count() -> int:
	var n := 0
	for c in hub.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("boot_cover.gd"):
			n += 1
	return n

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		print("cover present early: ", _count() == 1)
	if frames == 400:
		var gone := _count() == 0
		print("cover gone after settling: ", gone)
		quit(0 if gone else 1)
	return false
