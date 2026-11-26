extends SceneTree

## Headless test for scripts/common/camera_service.gd's pure helpers (patch,
## thumbnail_jpg). The live feed itself only runs on a phone.
##   godot --headless --path . --script res://tools/test_camera_service.gd

const Cam = preload("res://scripts/common/camera_service.gd")

var fails := 0


func _initialize() -> void:
	var img := Image.create(40, 30, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.4, 0.6))
	img.set_pixel(20, 15, Color(1, 0, 0))
	var p: Array[Color] = Cam.patch(img, Vector2i(20, 15), 7)
	ok(p.size() == 15 * 15, "15x15 patch in the middle: %d" % p.size())
	ok(p.count(Color(1, 0, 0)) == 1, "patch holds the marked pixel once")
	var corner: Array[Color] = Cam.patch(img, Vector2i(0, 0), 7)
	ok(corner.size() == 8 * 8, "corner patch is clipped to 8x8: %d" % corner.size())
	ok(Cam.patch(null, Vector2i.ZERO).is_empty(), "no image -> empty patch")
	var big := Image.create(1280, 720, false, Image.FORMAT_RGB8)
	big.fill(Color(0.5, 0.5, 0.5))
	var jpg: PackedByteArray = Cam.thumbnail_jpg(big, 128)
	ok(jpg.size() > 100 and jpg.size() < 20000, "thumbnail jpg size %d" % jpg.size())
	var back := Image.new()
	ok(back.load_jpg_from_buffer(jpg) == OK, "thumbnail decodes")
	ok(back.get_width() == 128 and back.get_height() == 72, "thumbnail 128x72: %dx%d" % [back.get_width(), back.get_height()])
	ok(Cam.API_VERSION >= 1, "API_VERSION")
	print("camera_service: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)
