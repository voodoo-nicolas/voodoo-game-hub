extends SceneTree

## Writes QR test images for scripts/common/qr.gd (decode them with any reader
## or OpenCV): godot --headless --path . --script res://tools/test_qr.gd -- <out_dir>
const QR = preload("res://scripts/common/qr.gd")

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var texts := ["HI", "ABCD", "https://voodoo-nicolas.github.io/voodoo-game-hub/j/?g=connect4&c=QWER",
		"Join me in Viral Game Hub! Four in a Row, code QWER: https://voodoo-nicolas.github.io/voodoo-game-hub/j/?c=Q",
		"ñandú 🎲 código"]
	for i in texts.size():
		var img: Image = QR.image(texts[i], 6)
		if img == null:
			print("too long: ", texts[i])
			continue
		img.save_png(out + "/qr_%d.png" % i)
		print("qr_%d: %d px" % [i, img.get_width()])
	quit()
