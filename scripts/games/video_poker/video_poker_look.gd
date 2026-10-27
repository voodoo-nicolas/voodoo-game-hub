extends RefCounted

## The look of the Poker table: every colour the table, seats, chips and cards
## use, in one place, for the two looks (STANDARDS §9, skins). "classic" is the
## default: dark green felt, gold and mahogany, ivory cards. "voodoo" is the
## skull skin: neon purple and blue on near-black. Both follow the owner's
## art (Drive > Viral Game Hub > poker; notes in docs/claude/poker-revamp.md).
##
## The game's `_set_skin()` calls set_skin(); drawing code asks c("key") /
## f("key") and never hard-codes a colour, so a new look is one more entry in
## LOOKS (same keys: tools/test_poker_look.gd checks).
##
## Art slots: everything is drawn in code, and tex("key") returns a picture
## from games/video_poker/art/<look>/<key>.webp (or .png / .jpg) when the owner
## has supplied one, else null so the code drawing is used. Slots, all
## optional: table_portrait, table_landscape (a whole empty table, full
## screen), crest (the skull-in-V mark, transparent, drawn faintly on the
## felt), card_back, card_face (a blank face for the number cards, whose pips
## the code draws), chip_1..chip_6 (white red blue green black gold,
## transparent), dealer, and face_<A|J|Q|K>_<s|h|d|c> for the court cards and
## aces. The code falls back per slot, so the art can arrive in any order.
## tools/poker_art_import.py makes them from the owner's pictures.

const ART_DIR := "res://games/video_poker/art/"

const LOOKS := {
	"classic": {
		"room": Color("0b0d0b"),
		"felt": Color("14522f"), "felt_deep": Color("0e3d22"), "felt_line": Color("c9a24a"),
		"rail": Color("4a2113"), "rail_hi": Color("8a4a26"), "rail_lo": Color("22100a"),
		"glow_a": Color("c9a24a"), "glow_b": Color("c9a24a"), "line2": Color("c9a24a"),
		"seat_bg": Color(0.05, 0.09, 0.07, 0.94),
		"you": Color("e6dfc8"), "cpu": Color("b99a52"), "active": Color("7be07b"), "winner": Color("ffd24a"),
		"text": Color("f3ecd8"), "dim": Color("a39b82"), "gold": Color("e3b94a"),
		"accent_call": Color("8fd0a0"), "accent_raise": Color("e3b94a"),
		"card_face": Color("f6f1e3"), "card_back": Color("123d2a"), "card_back_rim": Color("c9a24a"),
		"card_edge": Color(0.45, 0.42, 0.38),
		"ink_red": Color("b3151c"), "ink_black": Color("111418"),
		"rim_red": Color("b3151c"), "rim_black": Color("111418"), "hilite": Color("ffae2b"),
		"chip_1": Color("e8e4d8"), "chip_2": Color("b3262e"), "chip_3": Color("2d5fb0"),
		"chip_4": Color("2e8f4e"), "chip_5": Color("1a1a1d"), "chip_6": Color("d4a62a"),
		"chip_edge": Color("f3ecd8"),
		"dealer": Color("f3ecd8"), "dealer_ink": Color("1a1410"),
		"suit_s": Color("e6d3a3"), "suit_c": Color("e6d3a3"), "suit_h": Color("e8454a"), "suit_d": Color("e8454a"),
		"suit4_s": Color("e9e4d2"), "suit4_c": Color("48d17a"), "suit4_h": Color("e8454a"), "suit4_d": Color("4aa3ff"),
		"plate": Color(0.03, 0.06, 0.05, 0.9), "plate_edge": Color("9a8450"),
		"glow": 0.0,
	},
	"voodoo": {
		"room": Color("07051a"),
		"felt": Color("100c33"), "felt_deep": Color("0a0826"), "felt_line": Color("6a4dff"),
		"rail": Color("14122b"), "rail_hi": Color("2a2760"), "rail_lo": Color("05041a"),
		"glow_a": Color("9a4dff"), "glow_b": Color("2e6bff"), "line2": Color("9a4dff"),
		"seat_bg": Color(0.05, 0.04, 0.14, 0.94),
		"you": Color("3aa0ff"), "cpu": Color("b04dff"), "active": Color("45e6ff"), "winner": Color("ffd45a"),
		"text": Color("eef0ff"), "dim": Color("8f93c8"), "gold": Color("ffd36b"),
		"accent_call": Color("5ab8ff"), "accent_raise": Color("e04fff"),
		"card_face": Color("0a0820"), "card_back": Color("0c0a26"), "card_back_rim": Color("9a4dff"),
		"card_edge": Color("3d8bff"),
		"ink_red": Color("ff5fc8"), "ink_black": Color("86b6ff"),
		"rim_red": Color("d63bff"), "rim_black": Color("3d8bff"), "hilite": Color("ffcf5a"),
		"chip_1": Color("dcd8ff"), "chip_2": Color("e0409f"), "chip_3": Color("2e6bff"),
		"chip_4": Color("20d8d0"), "chip_5": Color("14122b"), "chip_6": Color("ffcf5a"),
		"chip_edge": Color("9a4dff"),
		"dealer": Color("dcd8ff"), "dealer_ink": Color("14122b"),
		"suit_s": Color("86b6ff"), "suit_c": Color("86b6ff"), "suit_h": Color("ff5fc8"), "suit_d": Color("ff5fc8"),
		"suit4_s": Color("c9d8ff"), "suit4_c": Color("4be0c8"), "suit4_h": Color("ff5fc8"), "suit4_d": Color("4aa3ff"),
		"plate": Color(0.04, 0.03, 0.12, 0.9), "plate_edge": Color("6a4dff"),
		"glow": 1.0,
	},
}

## "classic" or "voodoo".
static var look := "classic"
static var _tex := {}

## The game's skin name ("classic" / "voodoo") to use.
static func set_skin(skin: String) -> void:
	look = "voodoo" if skin == "voodoo" else "classic"

static func is_classic() -> bool:
	return look == "classic"

static func c(key: String) -> Color:
	return LOOKS[look][key]

## A number of the look ("glow": 0 none .. 1 neon).
static func f(key: String) -> float:
	return float(LOOKS[look][key])

## The owner's picture for art slot `key` in the current look, or null.
static func tex(key: String) -> Texture2D:
	var id := look + "/" + key
	if _tex.has(id):
		return _tex[id]
	var found: Texture2D = null
	for ext in ["webp", "png", "jpg"]:
		var path := "%s%s/%s.%s" % [ART_DIR, look, key, ext]
		if ResourceLoader.exists(path):
			found = load(path) as Texture2D
			break
	_tex[id] = found
	return found
