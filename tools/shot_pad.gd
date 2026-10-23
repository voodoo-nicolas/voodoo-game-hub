extends SceneTree

## Screenshots of the shared controller (scripts/common/pad/) inside Pad Lab, one PNG per layout / look:
##   godot --path . --resolution 1280x720 --script res://tools/shot_pad.gd -- <out_dir> [layout_id skin_id ...]
## Without ids it shoots every layout in the neon look, the three looks on stick_4, and the settings
## panel + button map. Presses a few parts so the lit states show. Saves nothing to the player's prefs.

const Prefs = preload("res://scripts/common/pad/pad_prefs.gd")
const Layouts = preload("res://scripts/common/pad/pad_layouts.gd")
const Draw = preload("res://scripts/common/pad/pad_draw.gd")

var _lab: Control
var _pad: Control

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://pad_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in 3:
		await process_frame
	var scene: PackedScene = load("res://scenes/games/pad_lab/pad_lab.tscn")
	_lab = scene.instantiate()
	root.add_child(_lab)
	for i in 5:
		await process_frame
	_pad = _lab.pad
	var jobs: Array = []
	if args.size() >= 3:
		var i := 1
		while i + 1 < args.size():
			jobs.append([args[i], args[i + 1]])
			i += 2
	else:
		for id in Layouts.ids():
			jobs.append([id, "neon"])
		for sk in ["mono", "outline"]:
			jobs.append(["stick_4", sk])
			jobs.append(["dpad_4", sk])
	for job in jobs:
		await _shoot(out_dir, str(job[0]), str(job[1]), false)
	if args.size() < 3:
		await _shoot(out_dir, "stick_4", "neon", true)
	quit()

func _base_prefs() -> Dictionary:
	var p: Dictionary = Prefs.DEFAULTS.duplicate()
	p["opacity"] = 1.0
	return p

func _shoot(out_dir: String, layout: String, skin: String, with_ui: bool) -> void:
	var p := _base_prefs()
	p["layout"] = layout
	p["skin"] = skin
	if with_ui:
		p["show_map"] = true
	_pad.apply_prefs(p, false)
	_lab._opts_panel.visible = with_ui
	for i in 3:
		await process_frame
	# Light a few parts: stick pushed up-right, A pressed.
	var held: Array = []
	for el in _pad.parts():
		if el["kind"] == "stick" and el["id"] == "move":
			_pad._press(90, el["pos"], true)
			_pad._move(90, el["pos"] + Vector2(el["r"] * 0.7, -el["r"] * 0.5))
			held.append(90)
		elif el["kind"] == "dpad":
			_pad._press(91, el["pos"], true)
			_pad._move(91, el["pos"] + Vector2(el["r"] * 0.6, 0))
			held.append(91)
		elif el["kind"] == "button" and el["id"] == "a":
			_pad._press(92, el["pos"], true)
			held.append(92)
	for i in 4:
		await process_frame
	var name := "%s_%s%s.png" % [layout, skin, "_ui" if with_ui else ""]
	root.get_texture().get_image().save_png(out_dir.path_join(name))
	print("SHOT ", name, "  window ", root.get_visible_rect().size)
	for f in held:
		_pad._press(f, Vector2.ZERO, false)
