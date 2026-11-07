extends RefCounted

## Tilt Maze's 🛒 Marble Shop (owner, 2026-11-07: "scores/points used to
## purchase new marbles, or cool effects for the marbles"). Coins are earned by
## playing only -- never sold (no ads, no store; STANDARDS). Everything is drawn
## in code with one soft disc texture (draw_texture_rect is far cheaper than
## draw_circle in Godot 4.7). The game keeps the wallet in its progress file:
## "coins", "owned" {"marble": [ids], "fx": [ids]}, "marble", "fx".

## Coins for a maze: the first clear pays BASE + PER_STAR x stars; later, each
## new star pays PER_STAR; any other replay REPLAY. No falls adds CLEAN.
## The Daily Maze pays DAILY + DAILY_STREAK x streak (streak counted up to 5), once a day.
const BASE := 10
const PER_STAR := 5
const REPLAY := 2
const CLEAN := 5
const DAILY := 25
const DAILY_STREAK := 5

const MARBLES := [
	{"id": "steel", "name": "Steel", "price": 0},
	{"id": "glass", "name": "Glass", "price": 60},
	{"id": "ruby", "name": "Ruby gem", "price": 100},
	{"id": "emerald", "name": "Emerald", "price": 100},
	{"id": "gold", "name": "Gold", "price": 200},
	{"id": "moon", "name": "Moon", "price": 250},
	{"id": "eye", "name": "Eyeball", "price": 300},
	{"id": "skull", "name": "Skull", "price": 400},
	{"id": "fire", "name": "Fireball", "price": 450},
	{"id": "galaxy", "name": "Galaxy", "price": 600},
	{"id": "rainbow", "name": "Rainbow", "price": 800},
]
const EFFECTS := [
	{"id": "none", "name": "No effect", "price": 0},
	{"id": "trail", "name": "Dot trail", "price": 80},
	{"id": "glow", "name": "Glow", "price": 150},
	{"id": "sparks", "name": "Sparks", "price": 200},
	{"id": "comet", "name": "Comet tail", "price": 300},
	{"id": "ghosts", "name": "Ghosts", "price": 400},
	{"id": "rainbow_trail", "name": "Rainbow trail", "price": 500},
]
const TRAIL_LEN := 24  # positions the game keeps for trails

# ---------- the wallet (in the game's progress Dictionary) ----------

static func coins(p: Dictionary) -> int:
	return int(p.get("coins", 0))

static func owns(p: Dictionary, kind: String, id: String) -> bool:
	if price_of(kind, id) == 0:
		return true
	var owned = p.get("owned", {})
	return owned is Dictionary and owned.get(kind, []).has(id)

static func equipped(p: Dictionary, kind: String) -> String:
	var id := str(p.get(kind, "steel" if kind == "marble" else "none"))
	return id if owns(p, kind, id) and price_of(kind, id) >= 0 else ("steel" if kind == "marble" else "none")

static func price_of(kind: String, id: String) -> int:
	for it in (MARBLES if kind == "marble" else EFFECTS):
		if it.id == id:
			return int(it.price)
	return -1

## Buys (if needed and affordable) and equips. Returns true if it changed anything.
static func pick(p: Dictionary, kind: String, id: String) -> bool:
	var price := price_of(kind, id)
	if price < 0:
		return false
	if not owns(p, kind, id):
		if coins(p) < price:
			return false
		p["coins"] = coins(p) - price
		if not p.get("owned") is Dictionary:
			p["owned"] = {}
		var lst: Array = p.owned.get(kind, [])
		lst.append(id)
		p.owned[kind] = lst
	p[kind] = id
	return true

## Coins for a campaign maze. `old_stars` = best stars before this run (0 = first clear).
static func earn_campaign(old_stars: int, stars: int, falls: int) -> int:
	var n: int
	if old_stars == 0:
		n = BASE + PER_STAR * stars
	elif stars > old_stars:
		n = PER_STAR * (stars - old_stars)
	else:
		n = REPLAY
	if falls == 0:
		n += CLEAN
	return n

static func earn_daily(streak: int, falls: int) -> int:
	return DAILY + DAILY_STREAK * clampi(streak, 1, 5) + (CLEAN if falls == 0 else 0)

# ---------- drawing ----------

static func _d(ci: CanvasItem, disc: Texture2D, c: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(disc, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

## The marble's main colour (for trails and sparks).
static func tint(id: String, t: float) -> Color:
	match id:
		"glass": return Color("6ec6ff")
		"ruby": return Color("e0245e")
		"emerald": return Color("1fbf6a")
		"gold": return Color("ffc928")
		"moon": return Color("c9ccd6")
		"eye": return Color("ffffff")
		"skull": return Color("efe6cf")
		"fire": return Color("ff7a1a")
		"galaxy": return Color("9b5cff")
		"rainbow": return Color.from_hsv(fposmod(t * 0.35, 1.0), 0.75, 1.0)
	return Color("c5ccd6")

## Draws marble `id` at `c` with radius `r`. `look` = rolling direction (eyes
## follow it), `t` = seconds (animation), `neon` = Voodoo skin (steel glows cyan).
static func draw_marble(ci: CanvasItem, disc: Texture2D, id: String, c: Vector2, r: float, look: Vector2, t: float, neon: bool) -> void:
	_d(ci, disc, c + Vector2(r * 0.15, r * 0.25), r, Color(0, 0, 0, 0.3))
	match id:
		"glass":
			_d(ci, disc, c, r, Color(0.43, 0.78, 1.0, 0.55))
			_d(ci, disc, c + Vector2(r * 0.15, r * 0.1), r * 0.55, Color(0.2, 0.5, 1.0, 0.6))
			_d(ci, disc, c - Vector2(r * 0.25, r * 0.3), r * 0.3, Color(1, 1, 1, 0.85))
			ci.draw_arc(c, r * 0.6, t * 2.0, t * 2.0 + 2.2, 10, Color(1, 1, 1, 0.5), maxf(1.0, r * 0.12))
		"ruby", "emerald", "gold":
			var col := tint(id, t)
			_d(ci, disc, c, r, col.darkened(0.35))
			_d(ci, disc, c - Vector2(r, r) * 0.1, r * 0.8, col)
			_d(ci, disc, c - Vector2(r, r) * 0.32, r * 0.32, Color(1, 1, 1, 0.8))
			if id != "gold":
				var facets := PackedVector2Array([c + Vector2(0, -r * 0.6), c + Vector2(r * 0.55, 0), c + Vector2(0, r * 0.6), c + Vector2(-r * 0.55, 0), c + Vector2(0, -r * 0.6)])
				ci.draw_polyline(facets, Color(1, 1, 1, 0.35), maxf(1.0, r * 0.08))
		"moon":
			_d(ci, disc, c, r, Color("9aa0ac"))
			_d(ci, disc, c - Vector2(r, r) * 0.1, r * 0.85, Color("c9ccd6"))
			for k in [[Vector2(0.3, -0.2), 0.22], [Vector2(-0.35, 0.25), 0.18], [Vector2(0.1, 0.45), 0.12], [Vector2(-0.25, -0.4), 0.1]]:
				_d(ci, disc, c + k[0] * r, r * k[1], Color("8a909c"))
		"eye":
			_d(ci, disc, c, r, Color("f4f1ea"))
			var lk := look.limit_length(1.0) * r * 0.35
			_d(ci, disc, c + lk, r * 0.48, Color("2e8b57") if not neon else Color("ff2bd6"))
			_d(ci, disc, c + lk * 1.15, r * 0.24, Color("0a0a0a"))
			_d(ci, disc, c + lk - Vector2(r, r) * 0.15, r * 0.1, Color(1, 1, 1, 0.9))
			ci.draw_line(c + Vector2(-r * 0.8, -r * 0.3), c + Vector2(-r * 0.45, -r * 0.1), Color(0.8, 0.1, 0.1, 0.6), maxf(1.0, r * 0.06))
		"skull":
			_d(ci, disc, c, r, Color("efe6cf"))
			_d(ci, disc, c + Vector2(-r * 0.33, -r * 0.05), r * 0.24, Color("1a1410"))
			_d(ci, disc, c + Vector2(r * 0.33, -r * 0.05), r * 0.24, Color("1a1410"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.15), c + Vector2(-r * 0.1, r * 0.35), c + Vector2(r * 0.1, r * 0.35)]), Color("1a1410"))
			for k in 3:
				var x: float = (k - 1) * r * 0.22
				ci.draw_line(c + Vector2(x, r * 0.5), c + Vector2(x, r * 0.78), Color("1a1410"), maxf(1.0, r * 0.07))
		"fire":
			var f := 0.9 + 0.1 * sin(t * 23.0) + 0.05 * sin(t * 37.0)
			_d(ci, disc, c, r * 1.5 * f, Color(1.0, 0.35, 0.0, 0.25))
			_d(ci, disc, c, r, Color("ff4500"))
			_d(ci, disc, c - Vector2(0, r * 0.1), r * 0.7 * f, Color("ff9a1a"))
			_d(ci, disc, c - Vector2(0, r * 0.2), r * 0.38 * f, Color("fff2a0"))
		"galaxy":
			_d(ci, disc, c, r, Color("1a0b3a"))
			_d(ci, disc, c + Vector2(r * 0.2, r * 0.1), r * 0.6, Color(0.6, 0.3, 1.0, 0.45))
			_d(ci, disc, c - Vector2(r * 0.25, r * 0.2), r * 0.4, Color(0.2, 0.6, 1.0, 0.35))
			for k in 6:
				var a := k * 1.7 + 0.3
				var p := c + Vector2(cos(a), sin(a)) * r * (0.2 + 0.12 * k)
				var tw := 0.5 + 0.5 * sin(t * 5.0 + k * 2.1)
				ci.draw_rect(Rect2(p - Vector2(1, 1) * maxf(1.0, r * 0.06), Vector2(2, 2) * maxf(1.0, r * 0.06)), Color(1, 1, 1, tw))
		"rainbow":
			for k in 6:
				_d(ci, disc, c, r * (1.0 - k * 0.15), Color.from_hsv(fposmod(t * 0.35 + k * 0.12, 1.0), 0.75, 1.0))
			_d(ci, disc, c - Vector2(r, r) * 0.35, r * 0.28, Color(1, 1, 1, 0.85))
		_:
			if neon:
				_d(ci, disc, c, r * 1.5, Color(0.16, 0.9, 1.0, 0.25))
				_d(ci, disc, c, r, Color(0.16, 0.9, 1.0).lerp(Color.WHITE, 0.3))
				_d(ci, disc, c - Vector2(r, r) * 0.35, r * 0.3, Color(1, 1, 1, 0.9))
			else:
				_d(ci, disc, c, r, Color("8e99a8"))
				_d(ci, disc, c - Vector2(r, r) * 0.12, r * 0.82, Color("c5ccd6"))
				_d(ci, disc, c - Vector2(r, r) * 0.38, r * 0.3, Color(1, 1, 1, 0.9))

## Effects drawn UNDER the marble. `trail` = recent centres, oldest first.
static func draw_fx_under(ci: CanvasItem, disc: Texture2D, fx: String, marble: String, trail: Array, c: Vector2, r: float, t: float) -> void:
	var col := tint(marble, t)
	var n := trail.size()
	match fx:
		"trail":
			for i in range(0, n, 2):
				var a := float(i + 1) / n
				_d(ci, disc, trail[i], r * 0.3 * a, Color(col, 0.5 * a))
		"glow":
			var p := 1.0 + 0.15 * sin(t * 5.0)
			_d(ci, disc, c, r * 2.0 * p, Color(col, 0.18))
			_d(ci, disc, c, r * 1.45 * p, Color(col, 0.28))
		"sparks":
			for i in range(0, n, 3):
				var a := float(i + 1) / n
				var j := Vector2(sin(i * 12.9898 + t * 9.0), cos(i * 78.233 + t * 7.0)) * r * 0.5
				ci.draw_rect(Rect2(trail[i] + j - Vector2(1.5, 1.5), Vector2(3, 3)), Color(Color("fff3a0").lerp(col, 0.4), a))
		"comet":
			for i in n:
				var a := float(i + 1) / n
				_d(ci, disc, trail[i], r * 0.95 * a, Color(col, 0.22 * a))
		"ghosts":
			for k in [6, 12, 18]:
				if n > k:
					_d(ci, disc, trail[n - 1 - k], r * 0.9, Color(col, 0.32 - k * 0.012))
		"rainbow_trail":
			for i in n:
				var a := float(i + 1) / n
				_d(ci, disc, trail[i], r * 0.5 * a + r * 0.15, Color.from_hsv(fposmod(i * 0.06 - t * 0.5, 1.0), 0.8, 1.0, 0.55 * a))

## A shop picture: the marble (and the effect, laid out as a short run).
static func draw_swatch(ci: Control, disc: Texture2D, kind: String, id: String, neon: bool) -> void:
	var s := ci.size
	ci.draw_rect(Rect2(Vector2.ZERO, s), Color("2a1a0e") if not neon else Color("0b0d1a"))
	var r: float = minf(s.x, s.y) * 0.22
	var t := Time.get_ticks_msec() / 1000.0
	var c := s * 0.5
	if kind == "fx":
		var trail: Array = []
		for i in TRAIL_LEN:
			var f := float(i) / TRAIL_LEN
			trail.append(Vector2(s.x * (0.12 + 0.5 * f), s.y * (0.7 - 0.25 * f)))
		c = Vector2(s.x * 0.66, s.y * 0.44)
		draw_fx_under(ci, disc, id, "steel", trail, c, r, t)
		draw_marble(ci, disc, "steel", c, r, Vector2.RIGHT, t, neon)
	else:
		draw_marble(ci, disc, id, c, r * 1.4, Vector2(0.6, 0.3), t, neon)
