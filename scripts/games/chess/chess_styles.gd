extends RefCounted

## The shop's boards and piece sets (bought with lesson points, chosen in
## 🛒 Shop). They are variants of the Classic look (STANDARDS §9); the
## Voodoo look keeps its own neon board and pieces (VOODOO_*).
## Names are English (es.json translates them). Prices in points.

const BOARDS := [
	{"id": "wood", "name": "Classic Wood", "price": 0,
		"light": Color("f0d9b5"), "dark": Color("b58863"), "frame": Color("6b4423")},
	{"id": "tournament", "name": "Tournament Green", "price": 80,
		"light": Color("eeeed2"), "dark": Color("6f8f4e"), "frame": Color("3d5229")},
	{"id": "ocean", "name": "Ocean Blue", "price": 120,
		"light": Color("dfe7ec"), "dark": Color("7f9fb3"), "frame": Color("3c5566")},
	{"id": "rose", "name": "Rose Garden", "price": 120,
		"light": Color("f4e1e1"), "dark": Color("bf7d8c"), "frame": Color("6e3a46")},
	{"id": "midnight", "name": "Midnight", "price": 160,
		"light": Color("a9bbcf"), "dark": Color("34465f"), "frame": Color("1b2433")},
	{"id": "walnut", "name": "Walnut & Maple", "price": 200,
		"light": Color("ecd2a6"), "dark": Color("7a4f2a"), "frame": Color("3e2412")},
	{"id": "marble", "name": "Marble Hall", "price": 250, "veins": true,
		"light": Color("ecebe6"), "dark": Color("9d9a93"), "frame": Color("55524c")},
	{"id": "gothic", "name": "Gothic Castle", "price": 300, "veins": true,
		"light": Color("c49a5c"), "dark": Color("2c2b34"), "frame": Color("17120e")},
]

## light/dark = the gradient across each piece, line = its outline,
## detail = the small lines on it.
const PIECES := [
	{"id": "staunton", "name": "Ivory & Ebony", "price": 0,
		"white": {"light": Color("fffaf0"), "dark": Color("d8ccb4"), "line": Color("2b2016"), "detail": Color("2b2016", 0.55)},
		"black": {"light": Color("4b4845"), "dark": Color("121110"), "line": Color("050505"), "detail": Color("d8d0c0", 0.7)}},
	{"id": "gold", "name": "Gold & Silver", "price": 150,
		"white": {"light": Color("fff3b8"), "dark": Color("d09a22"), "line": Color("4f3604"), "detail": Color("4f3604", 0.55)},
		"black": {"light": Color("eef1f5"), "dark": Color("7f8996"), "line": Color("1f242c"), "detail": Color("1f242c", 0.55)}},
	{"id": "ruby", "name": "Ruby & Sapphire", "price": 200,
		"white": {"light": Color("ff9aa6"), "dark": Color("a3132b"), "line": Color("3d0410"), "detail": Color("ffe4e8", 0.7)},
		"black": {"light": Color("8fbfff"), "dark": Color("1b3f9a"), "line": Color("08153a"), "detail": Color("e2eeff", 0.7)}},
	{"id": "jade", "name": "Jade & Onyx", "price": 200,
		"white": {"light": Color("d4f5dd"), "dark": Color("4b9e69"), "line": Color("12331d"), "detail": Color("12331d", 0.5)},
		"black": {"light": Color("5d5d6a"), "dark": Color("17171e"), "line": Color("040406"), "detail": Color("b8f0c8", 0.6)}},
	{"id": "bronze", "name": "Marble & Bronze", "price": 250,
		"white": {"light": Color("faf8f3"), "dark": Color("c6c0b3"), "line": Color("5e564a"), "detail": Color("5e564a", 0.5)},
		"black": {"light": Color("e09a58"), "dark": Color("774214"), "line": Color("2e1606"), "detail": Color("ffe0bf", 0.6)}},
	{"id": "glass", "name": "Crystal Glass", "price": 300,
		"white": {"light": Color(1, 1, 1, 0.92), "dark": Color(0.78, 0.9, 1.0, 0.75), "line": Color("4f87ad"), "detail": Color("4f87ad", 0.6)},
		"black": {"light": Color(0.32, 0.38, 0.5, 0.85), "dark": Color(0.04, 0.07, 0.14, 0.92), "line": Color("9fc6ff"), "detail": Color("9fc6ff", 0.6)}},
]

## The Voodoo look: the neon board and glowing pieces it always had.
const VOODOO_BOARD := {"id": "voodoo", "light": Color(0.15, 0.2, 0.35), "dark": Color(0.07, 0.1, 0.2), "frame": Color("29e6ff")}
const VOODOO_PIECES := {
	"white": {"light": Color(0.98, 1.0, 1.0), "dark": Color(0.78, 0.9, 1.0), "line": Color("29e6ff"), "glow": Color("29e6ff"), "detail": Color("29e6ff", 0.7)},
	"black": {"light": Color(0.2, 0.17, 0.25), "dark": Color(0.04, 0.03, 0.07), "line": Color("ff2bd6"), "glow": Color("ff2bd6"), "detail": Color("ff2bd6", 0.7)},
}

static func board(id: String) -> Dictionary:
	for b in BOARDS:
		if b.id == id:
			return b
	return BOARDS[0]

static func pieces(id: String) -> Dictionary:
	for p in PIECES:
		if p.id == id:
			return p
	return PIECES[0]
