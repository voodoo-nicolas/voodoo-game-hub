extends RefCounted

## Ink Ninja scenery (owner 2026-11-16): houses, pagodas, shrines, statues (Akita, komainu,
## dragon, terracotta warriors), ruins, river bridges, the raised drawbridge, spike boards,
## the far palace and the boss hall. Drawing only; the engine owns where things stand.
## `g` is the game node: it owns pal, disc, anim_t, engine and skin, and the brush helpers.

var g

func _init(game) -> void:
	g = game

func _wood() -> Color:
	return Color(0.36, 0.25, 0.17, 0.95) if g.skin == "classic" else g.pal.mid

func _clay() -> Color:
	return Color(0.55, 0.42, 0.33) if g.skin == "classic" else g.pal.mid

func _poly(c: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	g._poly(c, pts, col)

## A curved roof: `y` is the walkable top, the tips curl up. cx and y are screen units.
func roof(c: CanvasItem, cx: float, y: float, w: float, u: float, col: Color, thick: float = 18.0) -> void:
	var up := PackedVector2Array()
	var lo := PackedVector2Array()
	for i in 13:
		var f := i / 12.0 * 2.0 - 1.0
		var curl := pow(absf(f), 5.0) * 16.0
		up.append(Vector2(cx + f * w * 0.5 * u, y + (-4.0 * (1.0 - f * f) - curl) * u))
		lo.append(Vector2(cx + f * w * 0.46 * u, y + (thick - curl * 0.8) * u))
	var edge := up.duplicate()
	lo.reverse()
	_poly(c, up + lo, col)
	c.draw_polyline(edge, Color(g.pal.paper2, 0.55), 1.5 * u)

# ---------- houses, pagodas, shrines ----------

func house(c: CanvasItem, X: float, Y: float, w: float, u: float, seed_: int) -> void:
	var bw := w * u
	var wood: Color = _wood()
	c.draw_rect(Rect2(X - bw / 2.0, Y - 112.0 * u, bw, 112.0 * u), Color(g.pal.ink, 0.8))   # the room inside
	c.draw_rect(Rect2(X - bw / 2.0, Y - 8.0 * u, bw, 8.0 * u), Color(_clay(), 0.9))   # tatami floor
	var side := 1.0 if seed_ % 2 == 0 else -1.0
	# A hanging scroll and a floor lamp: the warm light inside.
	c.draw_rect(Rect2(X - side * 70.0 * u - 14.0 * u, Y - 96.0 * u, 28.0 * u, 52.0 * u), Color(g.pal.paper2, 0.9))
	c.draw_line(Vector2(X - side * 70.0 * u, Y - 90.0 * u), Vector2(X - side * 70.0 * u, Y - 58.0 * u), g.pal.ink, 3.0 * u)
	var lamp := Vector2(X + side * 50.0 * u, Y - 30.0 * u)
	c.draw_texture_rect(g.disc, Rect2(lamp - Vector2(60, 60) * u, Vector2(120, 120) * u), false, Color(1.0, 0.7, 0.3, 0.38 + 0.06 * sin(g.anim_t * 5.0 + seed_)))
	c.draw_rect(Rect2(lamp + Vector2(-8, -16) * u, Vector2(16, 32) * u), Color(1.0, 0.82, 0.45, 0.9))
	c.draw_rect(Rect2(lamp + Vector2(-8, -16) * u, Vector2(16, 32) * u), g.pal.ink, false, 2.0 * u)
	# Posts and the shoji screen folded at one side.
	for px in [-0.5, 0.5]:
		c.draw_rect(Rect2(X + px * bw - 6.0 * u, Y - 118.0 * u, 12.0 * u, 118.0 * u), wood)
	c.draw_rect(Rect2(X - side * (bw * 0.5 - 6.0 * u) - (0.0 if side > 0.0 else 54.0 * u) , Y - 108.0 * u, 54.0 * u, 100.0 * u), Color(g.pal.paper2, 0.82))
	for i in 3:
		var lx := X - side * (bw * 0.5 - 6.0 * u) - (0.0 if side > 0.0 else 54.0 * u) + (i + 1) * 13.5 * u
		c.draw_line(Vector2(lx, Y - 108.0 * u), Vector2(lx, Y - 8.0 * u), Color(g.pal.ink, 0.6), 1.5 * u)
	c.draw_rect(Rect2(X - bw / 2.0 - 4.0 * u, Y - 120.0 * u, bw + 8.0 * u, 8.0 * u), wood)   # the beam under the eaves
	roof(c, X, Y - 126.0 * u, w + 40.0, u, g.pal.ink)

func pagoda(c: CanvasItem, X: float, Y: float, w: float, tiers: int, u: float, ruin: bool, open_door: bool = true) -> void:
	var wood: Color = _wood()
	var roofc: Color = g.pal.ink if not ruin else Color(g.pal.ink).lerp(g.pal.mid, 0.35)
	for i in tiers:
		var ry := Y - (120.0 + i * 118.0) * u
		var bw := (w - 70.0 - i * 70.0) * u
		var by1 := Y if i == 0 else Y - (120.0 + (i - 1) * 118.0) * u
		var by0 := ry + 16.0 * u
		c.draw_rect(Rect2(X - bw / 2.0, by0, bw, by1 - by0), wood.darkened(0.3))
		# lit paper panels with a lattice
		var pn := 3
		var pw := bw / (pn * 2.0 + 1.0)
		for j in pn:
			var rx := X - bw / 2.0 + pw * (1.0 + j * 2.0)
			if i == 0 and j == 1 and open_door:
				c.draw_rect(Rect2(rx, by0 + 14.0 * u, pw, by1 - by0 - 14.0 * u), Color(g.pal.ink, 0.9))   # the open doorway
				c.draw_texture_rect(g.disc, Rect2(Vector2(rx - pw * 0.5, by0 + 24.0 * u), Vector2(pw * 2.0, 70.0 * u)), false, Color(1.0, 0.7, 0.3, 0.3))
				continue
			c.draw_rect(Rect2(rx, by0 + 14.0 * u, pw, 62.0 * u), Color(g.pal.paper2, 0.8))
			c.draw_line(Vector2(rx + pw * 0.5, by0 + 14.0 * u), Vector2(rx + pw * 0.5, by0 + 76.0 * u), Color(g.pal.ink, 0.5), 1.5 * u)
		for px in [-0.5, 0.5]:
			c.draw_rect(Rect2(X + px * bw - 5.0 * u, by0, 10.0 * u, by1 - by0), wood)
		roof(c, X, ry, w + 40.0 - i * 70.0, u, roofc)
	# the spire: a staff with rings
	var top := Y - (120.0 + (tiers - 1) * 118.0) * u
	if not ruin:
		c.draw_line(Vector2(X, top - 6.0 * u), Vector2(X, top - 74.0 * u), g.pal.ink, 4.0 * u)
		for r in 5:
			c.draw_rect(Rect2(X - (11.0 - r * 1.6) * u, top - (22.0 + r * 11.0) * u, (22.0 - r * 3.2) * u, 4.0 * u), g.pal.ink)
	else:
		c.draw_line(Vector2(X, top - 6.0 * u), Vector2(X + 10.0 * u, top - 34.0 * u), g.pal.ink, 4.0 * u)
		for i in 4:
			var vx := X + (-w * 0.35 + i * w * 0.23) * u
			c.draw_polyline(PackedVector2Array([Vector2(vx, Y - 122.0 * u), Vector2(vx + 6.0 * u, Y - 90.0 * u), Vector2(vx - 4.0 * u, Y - 64.0 * u), Vector2(vx + 3.0 * u, Y - 40.0 * u)]), Color(g.pal.mid, 0.8), 3.0 * u)

func shrine(c: CanvasItem, X: float, Y: float, u: float, seed_: int) -> void:
	var wood: Color = _wood()
	c.draw_rect(Rect2(X - 52.0 * u, Y - 74.0 * u, 104.0 * u, 74.0 * u), wood.darkened(0.25))
	c.draw_rect(Rect2(X - 20.0 * u, Y - 62.0 * u, 40.0 * u, 62.0 * u), Color(g.pal.ink, 0.92))   # the doors, open
	c.draw_texture_rect(g.disc, Rect2(Vector2(X - 34.0 * u, Y - 70.0 * u), Vector2(68.0, 56.0) * u), false, Color(1.0, 0.72, 0.3, 0.3 + 0.05 * sin(g.anim_t * 4.0 + seed_)))
	roof(c, X, Y - 84.0 * u, 150.0, u, g.pal.ink)
	# the sacred rope with its paper zigzags
	var rope := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		rope.append(Vector2(X - 54.0 * u + f * 108.0 * u, Y - 66.0 * u + sin(f * PI) * 9.0 * u))
	c.draw_polyline(rope, Color(0.78, 0.66, 0.42), 3.0 * u)
	for i in 3:
		var zx := X - 30.0 * u + i * 30.0 * u
		c.draw_rect(Rect2(zx - 3.0 * u, Y - 62.0 * u + sin((zx - X) * 0.05 + 2.0) * 3.0 * u, 6.0 * u, 12.0 * u), g.pal.paper)
	g._lantern(c, Vector2(X - 112.0 * u, Y), u, false)
	g._lantern(c, Vector2(X + 112.0 * u, Y), u, false)
	komainu(c, X - 78.0 * u, Y, u, 1)
	komainu(c, X + 78.0 * u, Y, u, -1)
	# incense in front
	var ib := Vector2(X, Y - 3.0 * u)
	c.draw_rect(Rect2(ib + Vector2(-10, -8) * u, Vector2(20, 8) * u), Color(0.3, 0.3, 0.3, 0.85))
	c.draw_line(ib + Vector2(0, -8) * u, ib + Vector2(0, -26) * u, Color(0.5, 0.35, 0.2), 2.0 * u)
	var wisp := PackedVector2Array()
	for i in 10:
		wisp.append(ib + Vector2(sin(g.anim_t * 1.6 + i * 0.55 + seed_) * (3.0 + i * 1.2), -26.0 * u / u - i * 6.0) * u)
	c.draw_polyline(wisp, Color(g.pal.smoke, 0.45), 2.0 * u)

# ---------- statues ----------

## A stone lion-dog on a plinth; f is the way it faces.
func komainu(c: CanvasItem, X: float, Y: float, u: float, f: int) -> void:
	var stone: Color = g.pal.near
	c.draw_rect(Rect2(X - 22.0 * u, Y - 24.0 * u, 44.0 * u, 24.0 * u), stone)
	c.draw_rect(Rect2(X - 22.0 * u, Y - 24.0 * u, 44.0 * u, 24.0 * u), g.pal.ink, false, 2.0 * u)
	var y0 := Y - 24.0 * u
	g._ell(c, Vector2(X - f * 6.0 * u, y0 - 16.0 * u), 17.0 * u, 15.0 * u, stone)
	_poly(c, PackedVector2Array([Vector2(X - f * 14.0 * u, y0 - 2.0 * u), Vector2(X + f * 14.0 * u, y0 - 2.0 * u), Vector2(X + f * 14.0 * u, y0 - 38.0 * u), Vector2(X + f * 2.0 * u, y0 - 46.0 * u), Vector2(X - f * 8.0 * u, y0 - 28.0 * u)]), stone)
	var head := Vector2(X + f * 10.0 * u, y0 - 50.0 * u)
	for i in 6:
		var a := i * 1.05 + (0.3 if f > 0 else 0.0)
		c.draw_texture_rect(g.disc, Rect2(head + Vector2(cos(a), sin(a)) * 11.0 * u - Vector2(6, 6) * u, Vector2(12, 12) * u), false, g.pal.ink)   # curled mane
	g._ell(c, head, 11.0 * u, 10.0 * u, stone)
	c.draw_line(head + Vector2(f * 2.0, 3.0) * u, head + Vector2(f * 12.0, 3.0) * u, g.pal.ink, 2.0 * u)   # the open mouth
	c.draw_texture_rect(g.disc, Rect2(head + Vector2(f * 3.0 - 2.0, -5.0) * u, Vector2(4, 4) * u), false, g.pal.ink)
	c.draw_rect(Rect2(X + f * 10.0 * u - 3.0 * u, y0 - 28.0 * u, 6.0 * u, 26.0 * u), g.pal.ink)   # the front leg

## Hachiko, the loyal Akita, waiting on his plinth.
func akita(c: CanvasItem, X: float, Y: float, u: float, f: int) -> void:
	var stone: Color = g.pal.near
	var fur: Color = g.pal.ink.lerp(g.pal.near, 0.35)
	c.draw_rect(Rect2(X - 46.0 * u, Y - 34.0 * u, 92.0 * u, 34.0 * u), stone)
	c.draw_rect(Rect2(X - 46.0 * u, Y - 34.0 * u, 92.0 * u, 34.0 * u), g.pal.ink, false, 2.5 * u)
	c.draw_rect(Rect2(X - 22.0 * u, Y - 27.0 * u, 44.0 * u, 14.0 * u), g.pal.paper2)   # the plaque
	for i in 3:
		c.draw_line(Vector2(X - 16.0 * u, Y - 24.0 * u + i * 4.0 * u), Vector2(X + 16.0 * u - i * 5.0 * u, Y - 24.0 * u + i * 4.0 * u), Color(g.pal.ink, 0.6), 1.2 * u)
	var y0 := Y - 34.0 * u
	g._ell(c, Vector2(X - f * 12.0 * u, y0 - 18.0 * u), 22.0 * u, 18.0 * u, fur)
	_poly(c, PackedVector2Array([Vector2(X - f * 8.0 * u, y0 - 2.0 * u), Vector2(X + f * 18.0 * u, y0 - 2.0 * u), Vector2(X + f * 16.0 * u, y0 - 46.0 * u), Vector2(X + f * 6.0 * u, y0 - 56.0 * u), Vector2(X - f * 10.0 * u, y0 - 30.0 * u)]), fur)
	var head := Vector2(X + f * 12.0 * u, y0 - 62.0 * u)
	g._ell(c, head, 13.0 * u, 11.0 * u, fur)
	g._ell(c, head + Vector2(f * 13.0, 5.0) * u, 8.0 * u, 5.5 * u, fur)   # the snout
	c.draw_texture_rect(g.disc, Rect2(head + Vector2(f * 19.0 - 2.5, 2.0) * u, Vector2(5, 5) * u), false, g.pal.ink)   # nose
	for e in [-1, 1]:
		_poly(c, PackedVector2Array([head + Vector2(e * 3.0 + f * 1.0, -8.0) * u, head + Vector2(e * 11.0, -9.0) * u, head + Vector2(e * 9.0 + f * 1.0, -26.0) * u]), fur)
	c.draw_texture_rect(g.disc, Rect2(head + Vector2(f * 6.0 - 2.0, -3.0) * u, Vector2(4, 4) * u), false, g.pal.paper2)
	# the curled tail over his back
	var tail := PackedVector2Array()
	for i in 14:
		var a := PI * 0.9 + i * 0.45
		tail.append(Vector2(X - f * 28.0 * u, y0 - 28.0 * u) + Vector2(cos(a) * f, sin(a)) * (13.0 - i * 0.5) * u)
	c.draw_polyline(tail, fur, 8.0 * u)

func dragon(c: CanvasItem, X: float, Y: float, u: float, f: int) -> void:
	var stone: Color = g.pal.near
	c.draw_rect(Rect2(X - 55.0 * u, Y - 90.0 * u, 110.0 * u, 90.0 * u), stone)
	c.draw_rect(Rect2(X - 55.0 * u, Y - 90.0 * u, 110.0 * u, 90.0 * u), g.pal.ink, false, 3.0 * u)
	for i in 4:
		c.draw_line(Vector2(X - 55.0 * u, Y - 20.0 * u - i * 18.0 * u), Vector2(X + 55.0 * u, Y - 20.0 * u - i * 18.0 * u), Color(g.pal.ink, 0.5), 1.5 * u)
	var body: Array = []
	for i in 22:
		var t := i / 21.0
		body.append(Vector2(X + sin(t * TAU * 1.25) * 44.0 * u, Y - 92.0 * u - t * 170.0 * u))
	g._ribbon(c, body, 30.0 * u, 12.0 * u, g.pal.ink)
	var head: Vector2 = body[-1]
	g._ell(c, head, 16.0 * u, 11.0 * u, g.pal.ink)
	_poly(c, PackedVector2Array([head + Vector2(f * 8.0, -4.0) * u, head + Vector2(f * 36.0, 0.0) * u, head + Vector2(f * 30.0, 10.0) * u, head + Vector2(f * 6.0, 8.0) * u]), g.pal.ink)
	for e in [-1, 1]:
		c.draw_line(head + Vector2(-f * 4.0, -8.0) * u, head + Vector2(-f * 20.0, -24.0 + e * 4.0) * u, g.pal.ink, 3.0 * u)   # antlers
	c.draw_texture_rect(g.disc, Rect2(head + Vector2(f * 6.0 - 3.0, -5.0) * u, Vector2(6, 6) * u), false, g.pal.moon)
	for i in 8:
		var sp: Vector2 = body[2 + i * 2]
		c.draw_line(sp, sp + Vector2(-10.0, -6.0) * u, g.pal.mid, 2.0 * u)

func warriors(c: CanvasItem, X: float, Y: float, u: float, seed_: int, ruin: bool) -> void:
	var clay: Color = _clay()
	for i in 5:
		var wx := X + (i - 2) * 96.0 * u
		var broken := ruin and (seed_ + i * 7) % 3 == 0
		c.draw_rect(Rect2(wx - 20.0 * u, Y - 12.0 * u, 40.0 * u, 12.0 * u), g.pal.near)   # plinth
		_poly(c, PackedVector2Array([Vector2(wx - 14.0 * u, Y - 12.0 * u), Vector2(wx + 14.0 * u, Y - 12.0 * u), Vector2(wx + 11.0 * u, Y - 44.0 * u), Vector2(wx - 11.0 * u, Y - 44.0 * u)]), clay.darkened(0.15))   # the robe
		c.draw_rect(Rect2(wx - 16.0 * u, Y - 72.0 * u, 32.0 * u, 30.0 * u), clay)   # armoured chest
		for r in 3:
			c.draw_line(Vector2(wx - 14.0 * u, Y - 66.0 * u + r * 8.0 * u), Vector2(wx + 14.0 * u, Y - 66.0 * u + r * 8.0 * u), Color(g.pal.ink, 0.55), 1.5 * u)
		c.draw_line(Vector2(wx - 16.0 * u, Y - 70.0 * u), Vector2(wx - 22.0 * u, Y - 46.0 * u), clay, 6.0 * u)
		c.draw_line(Vector2(wx + 16.0 * u, Y - 70.0 * u), Vector2(wx + 22.0 * u, Y - 50.0 * u), clay, 6.0 * u)
		if not broken:
			g._ell(c, Vector2(wx, Y - 84.0 * u), 9.0 * u, 11.0 * u, clay)
			c.draw_texture_rect(g.disc, Rect2(Vector2(wx - 3.0 * u, Y - 100.0 * u), Vector2(6, 6) * u), false, clay.darkened(0.3))   # the topknot
		if i % 2 == 0:
			c.draw_line(Vector2(wx + 24.0 * u, Y - 8.0 * u), Vector2(wx + 24.0 * u, Y - 110.0 * u), g.pal.ink, 3.0 * u)   # a spear
			_poly(c, PackedVector2Array([Vector2(wx + 21.0 * u, Y - 108.0 * u), Vector2(wx + 27.0 * u, Y - 108.0 * u), Vector2(wx + 24.0 * u, Y - 124.0 * u)]), g.pal.ink)

func ruin_arch(c: CanvasItem, X: float, Y: float, u: float, seed_: int) -> void:
	var stone: Color = g.pal.near
	for s in [-1, 1]:
		var ph := 170.0 if s < 0 else 120.0
		c.draw_rect(Rect2(X + s * 120.0 * u - 17.0 * u, Y - ph * u, 34.0 * u, ph * u), stone)
		c.draw_rect(Rect2(X + s * 120.0 * u - 17.0 * u, Y - ph * u, 34.0 * u, ph * u), g.pal.ink, false, 2.5 * u)
	_poly(c, PackedVector2Array([Vector2(X - 150.0 * u, Y - 184.0 * u), Vector2(X - 10.0 * u, Y - 176.0 * u), Vector2(X - 14.0 * u, Y - 158.0 * u), Vector2(X - 140.0 * u, Y - 168.0 * u)]), stone)   # the lintel, half gone
	for i in 5:
		var rx := X + (-60.0 + fmod(seed_ * 0.37 + i * 53.0, 150.0)) * u
		c.draw_rect(Rect2(rx, Y - (8.0 + i % 3 * 5.0) * u, (22.0 + i * 3.0) * u, (8.0 + i % 3 * 5.0) * u), stone)
	for vx in [-120.0, 100.0]:
		c.draw_polyline(PackedVector2Array([Vector2(X + vx * u, Y - 100.0 * u), Vector2(X + (vx + 6.0) * u, Y - 70.0 * u), Vector2(X + (vx - 4.0) * u, Y - 44.0 * u)]), Color(g.pal.mid, 0.8), 3.0 * u)

## Vines and crumbled tops on the ruin walls (the blocks themselves are engine solids).
func ruin_wall(c: CanvasItem, X: float, Y: float, w: float, u: float, seed_: int) -> void:
	var stone: Color = g.pal.near
	var x0 := X - w * u / 2.0
	for i in 4:
		var tx := x0 + (10.0 + i * 32.0) * u
		_poly(c, PackedVector2Array([Vector2(tx, Y - 150.0 * u), Vector2(tx + 14.0 * u, Y - (162.0 + (i % 2) * 10.0) * u), Vector2(tx + 28.0 * u, Y - 150.0 * u)]), stone)
	for i in 3:
		var vx := x0 + (24.0 + i * 38.0) * u
		c.draw_polyline(PackedVector2Array([Vector2(vx, Y - 150.0 * u), Vector2(vx + 5.0 * u, Y - 118.0 * u), Vector2(vx - 4.0 * u, Y - 92.0 * u), Vector2(vx + 3.0 * u, Y - 66.0 * u)]), Color(g.pal.mid, 0.85), 3.0 * u)
	for i in 4:
		var bx := X + (60.0 + i * 38.0) * u
		c.draw_rect(Rect2(bx, Y - 14.0 * u, 26.0 * u, 14.0 * u), stone)
		c.draw_rect(Rect2(bx, Y - 14.0 * u, 26.0 * u, 14.0 * u), g.pal.ink, false, 1.5 * u)

# ---------- bridges, spikes ----------

## A decorative river bridge: lacquered rails, lantern posts.
func arch_bridge(c: CanvasItem, x0: float, x1: float, y: float, u: float) -> void:
	var red := Color(0.62, 0.15, 0.1)
	c.draw_rect(Rect2(x0, y, x1 - x0, 14.0 * u), _wood())
	c.draw_line(Vector2(x0, y + 14.0 * u), Vector2(x1, y + 14.0 * u), g.pal.ink, 2.5 * u)
	var n := maxi(2, int((x1 - x0) / (56.0 * u)))
	var pts := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / n
		var px := lerpf(x0, x1, f)
		var top := y - (40.0 + sin(f * PI) * 14.0) * u
		pts.append(Vector2(px, top))
		c.draw_line(Vector2(px, y), Vector2(px, top), red, 4.0 * u)
	c.draw_polyline(pts, red, 5.0 * u)
	for ex in [x0, x1]:
		c.draw_rect(Rect2(ex - 6.0 * u, y - 70.0 * u, 12.0 * u, 70.0 * u), red.darkened(0.15))
		c.draw_texture_rect(g.disc, Rect2(Vector2(ex - 8.0 * u, y - 82.0 * u), Vector2(16, 16) * u), false, Color(0.78, 0.66, 0.42))

## The drawbridge over a deep lake: hinged on the near bank, raised until the rope is cut.
func drawbridge(c: CanvasItem, o: Vector2, k: float, b: Dictionary) -> void:
	var hx: float = o.x + b.x0 * k
	var hy: float = o.y + b.y * k
	var span: float = (b.x1 - b.x0) * k
	var fall: float = clampf(float(b.t) / 0.9, 0.0, 1.0) if b.cut else 0.0
	fall = fall * fall * (3.0 - 2.0 * fall)
	var ang: float = (1.0 - fall) * 1.12
	var length: float = lerpf(minf(span, 360.0 * k), span, fall)
	var dir := Vector2(cos(ang), -sin(ang))
	var nrm := dir.orthogonal() * -1.0 if dir.orthogonal().y < 0.0 else dir.orthogonal()
	var thick := 16.0 * k
	var wood: Color = _wood()
	var tip: Vector2 = Vector2(hx, hy) + dir * length
	_poly(c, PackedVector2Array([Vector2(hx, hy), tip, tip + nrm * thick, Vector2(hx, hy) + nrm * thick]), wood)
	c.draw_polyline(PackedVector2Array([Vector2(hx, hy), tip, tip + nrm * thick, Vector2(hx, hy) + nrm * thick, Vector2(hx, hy)]), g.pal.ink, 2.5 * k)
	for i in range(1, 9):
		var pp: Vector2 = Vector2(hx, hy) + dir * length * (i / 9.0)
		c.draw_line(pp, pp + nrm * thick, Color(g.pal.ink, 0.6), 2.0 * k)
	if fall >= 1.0:
		# lowered: rails along both sides and a post at each end
		for ex in [hx, hx + span]:
			c.draw_rect(Rect2(ex - 5.0 * k, hy - 46.0 * k, 10.0 * k, 46.0 * k), g.pal.ink)
		c.draw_line(Vector2(hx, hy - 38.0 * k), Vector2(hx + span, hy - 38.0 * k), Color(g.pal.ink, 0.75), 3.0 * k)
	# the gate frame on the near bank, with the rope and its knot (a jump and a throw away)
	var kn: Vector2 = o + Vector2(b.rx, b.ry) * k
	var gy: float = o.y + g.engine.ground_y(b.rx) * k
	c.draw_rect(Rect2(kn.x - 5.0 * k, kn.y - 20.0 * k, 10.0 * k, gy - kn.y + 20.0 * k), wood)
	c.draw_rect(Rect2(kn.x - 5.0 * k, kn.y - 20.0 * k, 10.0 * k, gy - kn.y + 20.0 * k), g.pal.ink, false, 2.0 * k)
	c.draw_line(Vector2(kn.x - 16.0 * k, kn.y - 20.0 * k), Vector2(kn.x + 16.0 * k, kn.y - 20.0 * k), g.pal.ink, 5.0 * k)
	if not b.cut:
		var sag := Vector2(0.0, 26.0 * k + sin(g.anim_t * 2.0) * 3.0 * k)
		var rp := PackedVector2Array()
		for i in 9:
			var f := i / 8.0
			rp.append(kn.lerp(tip, f) + sag * sin(f * PI))
		c.draw_polyline(rp, Color(0.78, 0.66, 0.42), 3.0 * k)
		var pr := (14.0 + 5.0 * sin(g.anim_t * 5.0)) * k
		c.draw_texture_rect(g.disc, Rect2(kn - Vector2(pr, pr) * 1.6, Vector2(pr, pr) * 3.2), false, Color(0.85, 0.25, 0.15, 0.28))
		c.draw_texture_rect(g.disc, Rect2(kn - Vector2(9, 9) * k, Vector2(18, 18) * k), false, Color(0.78, 0.66, 0.42))
		c.draw_texture_rect(g.disc, Rect2(kn - Vector2(4, 4) * k, Vector2(8, 8) * k), false, g.pal.ink)
	else:
		c.draw_polyline(PackedVector2Array([kn, kn + Vector2(8, 30) * k, kn + Vector2(2, 54) * k]), Color(0.78, 0.66, 0.42), 3.0 * k)
	# far bank: a matching post
	c.draw_rect(Rect2(hx + span + 4.0 * k, hy - 64.0 * k, 10.0 * k, 64.0 * k), wood)

## A spike board that drops on a beat: warns (shakes, sinks a little), slams, rises.
func spike_trap(c: CanvasItem, o: Vector2, k: float, t: Dictionary) -> void:
	var X: float = o.x + t.x * k
	var Y: float = o.y + (t.y + 2.0) * k
	var cyc: float = fmod(float(t.t) + float(t.ph), 3.4)
	var off := -160.0
	var shake := 0.0
	if cyc >= 1.9 and cyc < 2.7:
		off = -160.0 + 12.0 * (cyc - 1.9) / 0.8
		shake = sin(g.anim_t * 60.0) * 2.5 * (cyc - 1.9) / 0.8
	elif cyc >= 2.7 and cyc < 3.15:
		off = lerpf(-148.0, 0.0, clampf((cyc - 2.7) / 0.1, 0.0, 1.0))
	elif cyc >= 3.15:
		off = lerpf(0.0, -160.0, (cyc - 3.15) / 0.25)
	var wood: Color = _wood()
	var top := Y - 270.0 * k
	for s in [-1, 1]:
		c.draw_rect(Rect2(X + s * 86.0 * k - 6.0 * k, top, 12.0 * k, Y - top), wood)
		c.draw_rect(Rect2(X + s * 86.0 * k - 6.0 * k, top, 12.0 * k, Y - top), g.pal.ink, false, 2.0 * k)
	c.draw_rect(Rect2(X - 96.0 * k, top - 8.0 * k, 192.0 * k, 14.0 * k), g.pal.ink)
	var by := Y - 60.0 * k + off * k
	var bx := X + shake * k
	for s in [-1, 1]:
		c.draw_line(Vector2(X + s * 56.0 * k, top + 6.0 * k), Vector2(bx + s * 56.0 * k, by), Color(0.78, 0.66, 0.42), 3.0 * k)
	c.draw_rect(Rect2(bx - 66.0 * k, by, 132.0 * k, 22.0 * k), wood)
	c.draw_rect(Rect2(bx - 66.0 * k, by, 132.0 * k, 22.0 * k), g.pal.ink, false, 2.5 * k)
	for i in 8:
		var sx := bx - 58.0 * k + i * 16.5 * k
		_poly(c, PackedVector2Array([Vector2(sx - 7.0 * k, by + 22.0 * k), Vector2(sx + 7.0 * k, by + 22.0 * k), Vector2(sx, by + 56.0 * k)]), g.pal.ink)
	if cyc >= 1.9 and cyc < 3.15:
		var wa := 0.1 + 0.25 * clampf((cyc - 1.9) / 0.8, 0.0, 1.0)
		c.draw_texture_rect(g.disc, Rect2(Vector2(X - 80.0 * k, Y - 10.0 * k), Vector2(160.0, 22.0) * k), false, Color(0.8, 0.1, 0.06, wa))

# ---------- far background ----------

## The palace on the horizon: tiny and far at the start, huge by the last stage.
func palace(c: CanvasItem, X: float, baseY: float, h: float, col: Color, glow: float) -> void:
	var u := h / 300.0
	c.draw_rect(Rect2(X - 240.0 * u, baseY - 34.0 * u, 480.0 * u, 34.0 * u), col)   # the great wall
	for side in [-1, 1]:
		var wx: float = X + side * 175.0 * u
		c.draw_rect(Rect2(wx - 55.0 * u, baseY - 90.0 * u, 110.0 * u, 56.0 * u), col)
		roof(c, wx, baseY - 92.0 * u, 150.0, u, col, 14.0)
	for i in 4:
		var tw := 150.0 - i * 24.0
		var ty := baseY - (84.0 + i * 52.0) * u
		c.draw_rect(Rect2(X - (tw - 30.0) * 0.5 * u, ty, (tw - 30.0) * u, 50.0 * u), col)
		roof(c, X, ty - 6.0 * u, tw + 40.0, u, col, 14.0)
	c.draw_line(Vector2(X, baseY - 300.0 * u), Vector2(X, baseY - 340.0 * u), col, 3.0 * u)
	if glow > 0.0:
		for i in 4:
			var ty := baseY - (60.0 + i * 52.0) * u
			c.draw_texture_rect(g.disc, Rect2(Vector2(X - 10.0 * u, ty - 6.0 * u), Vector2(20, 20) * u), false, Color(1.0, 0.7, 0.3, 0.7 * glow))
		c.draw_rect(Rect2(X - 14.0 * u, baseY - 34.0 * u, 28.0 * u, 34.0 * u), Color(0.1, 0.05, 0.04, 0.9))
