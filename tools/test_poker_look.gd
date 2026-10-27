extends SceneTree

## Headless check of the Poker looks (video_poker_look.gd): both looks define
## the same keys, every colour is a real Color, the skin names map right, art
## slots return null until the owner's art exists, and every colour the table
## and card code ask for is defined. Pure logic: touches no saves.
## godot --headless --path . --script res://tools/test_poker_look.gd

const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")

var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	var classic: Dictionary = Look.LOOKS.classic
	var voodoo: Dictionary = Look.LOOKS.voodoo
	for k in classic:
		ok(voodoo.has(k), "voodoo lacks %s" % k)
	for k in voodoo:
		ok(classic.has(k), "classic lacks %s" % k)
	for name in Look.LOOKS:
		for k in Look.LOOKS[name]:
			var v = Look.LOOKS[name][k]
			if k == "glow":
				ok(typeof(v) == TYPE_FLOAT, "%s/%s is a number" % [name, k])
			else:
				ok(typeof(v) == TYPE_COLOR, "%s/%s is a Color" % [name, k])
	Look.set_skin("voodoo")
	ok(Look.look == "voodoo" and not Look.is_classic() and Look.f("glow") == 1.0, "voodoo skin")
	Look.set_skin("classic")
	ok(Look.is_classic() and Look.f("glow") == 0.0, "classic skin")
	Look.set_skin("anything else")
	ok(Look.is_classic(), "an unknown skin name is classic")
	# Every key the drawing code asks for exists.
	var wanted := {}
	for f in ["video_poker_view.gd", "video_poker_cards.gd", "video_poker_game.gd", "video_poker_machine.gd", "video_poker_training.gd", "video_poker_drills.gd"]:
		var text := FileAccess.get_file_as_string("res://scripts/games/video_poker/" + f)
		var rx := RegEx.new()
		rx.compile("Look\\.[cf]\\(\"([a-z_0-9]+)\"")
		for m in rx.search_all(text):
			wanted[m.get_string(1)] = true
	for k in wanted:
		ok(classic.has(k), "the code uses Look key '%s' which the looks lack" % k)
	ok(wanted.size() > 15, "found the keys the code uses (%d)" % wanted.size())
	# Art slots: null while no art exists, cached, and no error for a missing file.
	for k in ["table_portrait", "card_back", "crest", "face_K_s"]:
		ok(Look.tex(k) == null or Look.tex(k) is Texture2D, "art slot %s" % k)
	ok(Look.tex("no_such_slot") == null and Look.tex("no_such_slot") == null, "a missing slot is null every time")
	print("poker look: ", "OK" if fails == 0 else "%d FAILED" % fails, "  (", wanted.size(), " keys used)")
	quit(1 if fails else 0)
