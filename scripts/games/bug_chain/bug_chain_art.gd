extends RefCounted

## Bug Chain art, all drawn in code (no image files): the beetle textures
## (one per colour, two leg poses for the crawl, Classic and Voodoo) and the
## field backdrop. A bug faces +x; the game rotates it along its track.
##
## Colour is never the only cue: each colour has its own shell pattern
## (MARKS, same index as the palettes).

const SIZE := 64
## Classic: garden beetles. Voodoo: neon shells on black, bone-white marks.
const CLASSIC := [Color("e0312b"), Color("f2c418"), Color("2f7fe0"), Color("3fae3a"), Color("9a4fd0"), Color("f07a1a")]
const VOODOO := [Color("ff3b6b"), Color("ffe03a"), Color("29e6ff"), Color("7dff3a"), Color("c56bff"), Color("ff9a2b")]
## Pattern per colour: spots, stripes, big spots, diamonds, dots, rings.
const MARKS := ["spots", "stripes", "big spots", "diamonds", "dots", "rings"]
const COLOR_NAMES := ["Red", "Yellow", "Blue", "Green", "Purple", "Orange"]

## [skin][colour][frame] -> Texture2D, built once per skin.
static func bug_set(voodoo: bool) -> Array:
	var out: Array = []
	var pal: Array = VOODOO if voodoo else CLASSIC
	for i in pal.size():
		out.append([bug(pal[i], i, 0, voodoo), bug(pal[i], i, 1, voodoo)])
	return out

static func bug(col: Color, mark: int, frame: int, voodoo: bool) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c := Vector2(29.0, 32.0)
	var rx := 20.0
	var ry := 18.5
	var ink := Color(0.09, 0.07, 0.07) if not voodoo else Color(0.04, 0.04, 0.08)
	var leg_c := Color(0.12, 0.09, 0.08) if not voodoo else col.lerp(Color.WHITE, 0.2)
	var mark_c := Color(0.1, 0.07, 0.07) if not voodoo else Color("efe7d2")
	var legs: Array = []
	for side in [-1.0, 1.0]:
		for k in 3:
			var dx := -9.0 + 9.0 * k
			var swing := (3.5 if (k + int(side > 0) + frame) % 2 == 0 else -3.5)
			legs.append([c + Vector2(dx, side * 12.0), c + Vector2(dx * 1.25 + swing, side * 28.5)])
	var head := c + Vector2(19.0, 0.0)
	var feelers: Array = [[head + Vector2(5, -4), head + Vector2(13, -11 + frame)],
		[head + Vector2(5, 4), head + Vector2(13, 11 - frame)]]
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var out := Color(0, 0, 0, 0)
			# Legs and feelers.
			var dl := INF
			for l in legs:
				dl = minf(dl, _seg(p, l[0], l[1]))
			for l in feelers:
				dl = minf(dl, _seg(p, l[0], l[1]) + 0.4)
			out = _over(out, leg_c, clampf(1.6 - dl, 0.0, 1.0))
			# Head.
			var dh := p.distance_to(head) - 8.5
			out = _over(out, ink if not voodoo else Color("1b1b2a"), clampf(0.5 - dh, 0.0, 1.0))
			for e in [-1.0, 1.0]:
				var de := p.distance_to(head + Vector2(4.0, e * 4.0)) - 2.1
				out = _over(out, Color(1, 1, 1) if not voodoo else col.lerp(Color.WHITE, 0.5), clampf(0.5 - de, 0.0, 1.0))
			# Shell.
			var u := p - c
			var q := Vector2(u.x / rx, u.y / ry)
			var ql := q.length()
			var d := (ql - 1.0) * minf(rx, ry)
			if voodoo:
				# Neon glow just outside the rim.
				out = _over(out, col, clampf(0.45 * (1.0 - d / 4.0), 0.0, 0.45) if d > 0.0 else 0.0)
			var a := clampf(0.5 - d, 0.0, 1.0)
			if a > 0.0:
				var body: Color
				if voodoo:
					body = col.darkened(0.72).lerp(col.darkened(0.45), clampf(1.0 - ql, 0.0, 1.0) * 0.5)
				else:
					body = col.lerp(col.lightened(0.18), clampf(1.0 - ql, 0.0, 1.0)).darkened(0.38 * ql * ql * ql)
				# Marks (inside the shell only).
				var dm := _mark(MARKS[mark % MARKS.size()], u)
				body = body.lerp(mark_c, clampf(0.5 - dm, 0.0, 1.0) * (0.92 if not voodoo else 0.95))
				# The line between the wing cases.
				if u.x < 9.0:
					body = body.lerp(ink, clampf(1.0 - absf(u.y), 0.0, 1.0) * 0.85)
				# Rim.
				var rim := col.lerp(Color.WHITE, 0.35) if voodoo else ink
				body = body.lerp(rim, clampf(d + 2.0, 0.0, 1.0) * (0.9 if voodoo else 0.7))
				# Shine.
				var hs := p.distance_to(c + Vector2(-7.0, -7.0))
				body = body.lerp(Color.WHITE, clampf(1.0 - hs / 8.0, 0.0, 1.0) * (0.45 if not voodoo else 0.25))
				out = _over(out, body, a)
			img.set_pixel(x, y, out)
	return ImageTexture.create_from_image(img)

## Signed distance (negative inside) to the pattern's nearest mark.
static func _mark(kind: String, u: Vector2) -> float:
	var ay := absf(u.y)
	match kind:
		"spots":
			return minf(Vector2(u.x + 8.0, ay - 8.5).length(), Vector2(u.x - 4.0, ay - 9.5).length()) - 3.6
		"stripes":
			return minf(absf(u.x + 8.0), absf(u.x - 3.0)) - 2.4
		"big spots":
			return Vector2(u.x + 2.0, ay - 9.0).length() - 6.0
		"diamonds":
			return (absf(u.x + 2.0) + absf(ay - 9.0)) - 6.5
		"dots":
			var dd := INF
			for o in [Vector2(-12, 5), Vector2(-3, 12), Vector2(6, 6), Vector2(-4, 4)]:
				dd = minf(dd, Vector2(u.x - o.x, ay - o.y).length())
			return dd - 2.3
		"rings":
			return absf(Vector2(u.x + 2.0, ay - 9.0).length() - 5.0) - 1.4
	return INF

static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func _over(dst: Color, src: Color, a: float) -> Color:
	if a <= 0.0:
		return dst
	var oa := a + dst.a * (1.0 - a)
	if oa <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Color(src.r, src.g, src.b) * a + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - a)) / oa
	return Color(rgb.r, rgb.g, rgb.b, oa)

## A soft round blob (white, fading edge) for glows and particles: tinted
## with modulate, drawn with draw_texture_rect (cheap; draw_circle is not).
static func disc() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

## A hard-edged round dot (anti-aliased), for the track's pebbles.
static func dot() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() - (n / 2.0 - 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(0.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

## Garden ground for Classic: grass with lighter and darker tufts (tiles).
static func grass() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.06
	var fine := FastNoiseLite.new()
	fine.seed = 11
	fine.frequency = 0.35
	var base := Color("4c8a35")
	for y in n:
		for x in n:
			var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var f := fine.get_noise_2d(x, y)
			var col := base.darkened(0.18 * (1.0 - v)).lightened(0.1 * v)
			col = col.lightened(maxf(0.0, f) * 0.18).darkened(maxf(0.0, -f) * 0.15)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
