extends SceneTree

## Headless check of the Poker looks (video_poker_look.gd): both looks define
## the same keys, every colour is a real Color, the skin names map right, art
## slots return null until the owner's art exists, and every colour the table
## and card code ask for is defined. Pure logic: touches no saves.
## godot --headless --path . --script res://tools/test_poker_look.gd

const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")
const Cards = preload("res://scripts/games/video_poker/video_poker_cards.gd")

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
	_cards()
	print("poker look: ", "OK" if fails == 0 else "%d FAILED" % fails, "  (", wanted.size(), " keys used)")
	quit(1 if fails else 0)


## The card art and the code that lays pips over it.
func _cards() -> void:
	# Classic has all its art: a missing import would show as a fallback card, silently.
	Look.set_skin("classic")
	var slots := ["card_back", "card_face", "dealer", "table_portrait"]
	for s in "shdc":
		for r in "AJQK":
			slots.append("face_%s_%s" % [r, s])
	for i in range(1, 7):
		slots.append("chip_%d" % i)
	for k in slots:
		ok(Look.tex(k) != null, "classic art slot %s loads" % k)
	for k in ["card_back", "card_face", "face_K_h"]:
		var t := Look.tex(k)
		ok(t != null and t.get_width() == 350 and t.get_height() == 500, "%s is 350x500" % k)
	# Number cards: the pip layouts hold exactly their rank, inside the card.
	for r in range(2, 11):
		var pips: Array = Cards.PIPS[r]
		ok(pips.size() == r, "a %d has %d pips (%d)" % [r, r, pips.size()])
		for p in pips:
			ok(p[0] > 0.1 and p[0] < 0.9 and p[1] > 0.1 and p[1] < 0.9, "%d: pip inside the card" % r)
	ok(Cards.face_key(0) == "face_A_s" and Cards.face_key(12) == "face_K_s" and Cards.face_key(13 + 10) == "face_J_h"
		and Cards.face_key(26 + 11) == "face_Q_d" and Cards.face_key(39) == "face_A_c" and Cards.face_key(5) == "", "face_key")
	Cards.four_color = false
	var plain := Cards.suit_color(2)
	Cards.four_color = true
	ok(Cards.suit_color(2) != plain, "the four-colour deck has its own diamonds")
	ok(Cards.suit_color(1) == Look.c("suit4_h"), "four-colour hearts")
	Cards.four_color = false
	for look in Look.LOOKS:
		for k in ["suit_s", "suit_h", "suit_d", "suit_c", "suit4_s", "suit4_h", "suit4_d", "suit4_c", "plate", "plate_edge"]:
			ok(Look.LOOKS[look].has(k), "%s has %s" % [look, k])
