extends RefCounted

## The Hunt (id sniper_hold) -- the valley, drawn in code (no image files): sky, sun, clouds, birds, three
## mountain ranges with snow and sunlit faces, forested hills, a lake that mirrors them, the
## far-shore pines, a meadow with a dirt track, grass, flowers, trees, rocks, bushes, logs,
## the animals, swaying foreground grass and the weather (mist, leaves, snow, fireflies, pollen).
##
## Everything is in world units (E.W x E.H) and depth in metres (E.ground_y / E.scale_at), so
## it lines up with the engine's hit tests. The game puts each draw_* on its own layer:
## the static ones (sky, land) are recorded once and only moved by the camera; the dynamic
## ones redraw each frame.

const E = preload("res://scripts/games/sniper_hold/sniper_hold_engine.gd")

const PALETTES := {
	"dawn": {
		"sky": [Color("27335f"), Color("8a6a9a"), Color("f2a98a"), Color("ffd9a8")],
		"sun": Color("ffe2b0"), "sun_pos": Vector2(330, 360), "sun_r": 34.0, "glow": Color("ffb37a"),
		"cloud": Color("f7c4b4"), "cloud_shade": Color("8f6f98"),
		"mtn": [Color("9c8fb6"), Color("7a6f9c"), Color("5a5682")], "snow": Color("fbe9ee"), "snowline": 300.0,
		"hill": Color("3d4f62"), "forest": Color("2c3d44"), "haze": Color("e8b8b0"),
		"lake": [Color("f0b49a"), Color("5f6a8e")],
		"ground": [Color("8c9a78"), Color("5e7a48"), Color("3e5f30")], "path": Color("8a7458"),
		"grass": [Color("6f8f4a"), Color("8aa85a"), Color("4e6e34")], "flowers": [Color("ffffff"), Color("f7b3c8"), Color("e8e0ff")],
		"tree": "pine", "leaf": [Color("2f4a38"), Color("3c5a40")], "trunk": Color("4a3a30"),
		"rock": Color("8a8494"), "light": Color(1.0, 0.9, 0.85), "mist": 0.55, "weather": "pollen", "stars": 0,
	},
	"noon": {
		"sky": [Color("2a6fd0"), Color("5aa2e6"), Color("a9d6f2"), Color("dff0f8")],
		"sun": Color("fffbe8"), "sun_pos": Vector2(1220, 110), "sun_r": 30.0, "glow": Color("fff4c8"),
		"cloud": Color("ffffff"), "cloud_shade": Color("b8c8dc"),
		"mtn": [Color("98aec8"), Color("7690ae"), Color("587290")], "snow": Color("ffffff"), "snowline": 280.0,
		"hill": Color("3e6a48"), "forest": Color("2a5434"), "haze": Color("c8e0f0"),
		"lake": [Color("8cc4e8"), Color("2f6a8a")],
		"ground": [Color("a8c070"), Color("7aa848"), Color("4e8a2c")], "path": Color("b09468"),
		"grass": [Color("6ea83a"), Color("9cc85a"), Color("4a8a26")], "flowers": [Color("fff36a"), Color("ffffff"), Color("b88cff"), Color("ff7a8a")],
		"tree": "oak", "leaf": [Color("3e7a32"), Color("5a9a40")], "trunk": Color("5a4434"),
		"rock": Color("9a9a9a"), "light": Color(1, 1, 1), "mist": 0.0, "weather": "butterflies", "stars": 0,
	},
	"autumn": {
		"sky": [Color("3a66a8"), Color("7aa0c8"), Color("e8cfa0"), Color("fbe2b4")],
		"sun": Color("fff0c8"), "sun_pos": Vector2(1260, 250), "sun_r": 32.0, "glow": Color("ffd48a"),
		"cloud": Color("fff3dc"), "cloud_shade": Color("c8a888"),
		"mtn": [Color("a8a0b4"), Color("8a7e98"), Color("6a5e74")], "snow": Color("fff6ea"), "snowline": 250.0,
		"hill": Color("6a5a3a"), "forest": Color("5a4a2a"), "haze": Color("f0d8b0"),
		"lake": [Color("e8d8b0"), Color("3a5a78")],
		"ground": [Color("c8b070"), Color("a89040"), Color("7a6a2a")], "path": Color("8a6a48"),
		"grass": [Color("b8963a"), Color("d8b45a"), Color("8a7026")], "flowers": [Color("e86a2a"), Color("f0c040")],
		"tree": "oak", "leaf": [Color("c8602a"), Color("e09a30"), Color("a84a20"), Color("8a8a30")], "trunk": Color("4a3428"),
		"rock": Color("9a8a80"), "light": Color(1.0, 0.95, 0.85), "mist": 0.15, "weather": "leaves", "stars": 0,
	},
	"dusk": {
		"sky": [Color("141230"), Color("4a2a5e"), Color("c4506a"), Color("ff9a52")],
		"sun": Color("ffc070"), "sun_pos": Vector2(1050, 440), "sun_r": 46.0, "glow": Color("ff7a3a"),
		"cloud": Color("ff9a7a"), "cloud_shade": Color("4a2a50"),
		"mtn": [Color("6a4a78"), Color("4a3460"), Color("2e2244")], "snow": Color("f8b8b0"), "snowline": 270.0,
		"hill": Color("262238"), "forest": Color("1a1a28"), "haze": Color("c86a6a"),
		"lake": [Color("ff9a6a"), Color("2a2244")],
		"ground": [Color("5a5a48"), Color("3e4a32"), Color("26341e")], "path": Color("5a4a3a"),
		"grass": [Color("3e5a2e"), Color("5a6a3a"), Color("2a3e20")], "flowers": [Color("ffd8a8")],
		"tree": "pine", "leaf": [Color("1c2a22"), Color("243428")], "trunk": Color("2a2220"),
		"rock": Color("5a5060"), "light": Color(0.82, 0.68, 0.7), "mist": 0.35, "weather": "fireflies", "stars": 70,
	},
	"winter": {
		"sky": [Color("7a90b0"), Color("a8bad0"), Color("d4dee8"), Color("eef2f6")],
		"sun": Color("ffffff"), "sun_pos": Vector2(500, 200), "sun_r": 26.0, "glow": Color("f4f8ff"),
		"cloud": Color("e8eef4"), "cloud_shade": Color("9aaac0"),
		"mtn": [Color("b8c4d4"), Color("98a8bc"), Color("7a8ca4")], "snow": Color("ffffff"), "snowline": 400.0,
		"hill": Color("5a6a74"), "forest": Color("2e3e40"), "haze": Color("dfe6ee"),
		"lake": [Color("c8d8e4"), Color("8aa0b4")],
		"ground": [Color("e2e8ee"), Color("d4dce6"), Color("c4ceda")], "path": Color("b0a8a0"),
		"grass": [Color("8a8a6a"), Color("a8a080"), Color("6a6a50")], "flowers": [],
		"tree": "pine_snow", "leaf": [Color("2a3c38"), Color("34483e")], "trunk": Color("3a302a"),
		"rock": Color("7a8088"), "light": Color(0.92, 0.95, 1.0), "mist": 0.3, "weather": "snow", "stars": 0,
	},
}

var env := "dawn"
var pal: Dictionary
var rng := RandomNumberGenerator.new()
var blob: Texture2D          # soft round spot (glow, clouds, mist)
var ridges: Array = []       # per mountain range: PackedVector2Array of ridge points
var hill_ridge := PackedVector2Array()
var props: Array = []        # {"kind", "x", "d", "h", "w", "seed", "tone"}
var tufts := PackedVector2Array()
var tuft_cols := PackedColorArray()
var flowers: Array = []      # [pos, size, colour]
var clouds: Array = []       # {"x", "y", "w", "puffs": [[dx, dy, r]]}
var birds: Array = []        # {"x", "y", "vx", "n", "ph"}
var motes: Array = []        # weather particles: [x, y, vx, vy, phase, size]
var fg: Array = []           # foreground grass blades: [x, h, lean, phase, colour]
var stars: Array = []
var voodoo := false          # Skull mode: animals glow hot, the thermal filter does the rest

func _init(p_env: String, p_seed: int) -> void:
	env = p_env if PALETTES.has(p_env) else "dawn"
	pal = PALETTES[env]
	rng.seed = p_seed
	blob = _make_blob()
	_gen()

static func _make_blob() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 128
	tx.height = 128
	return tx

# ---------------------------------------------------------------- generation

func _noise_ridge(base: float, amp: float, n: int, rough: float) -> PackedVector2Array:
	# Ridged noise (1 - |sin|) gives sharp peaks and rounded saddles; small jitter breaks it up.
	var pts := PackedVector2Array()
	var waves: Array = []
	var total := 0.0
	for i in 4:
		var w := Vector3(rng.randf_range(0.6, 1.0) / pow(1.8, i), rng.randf_range(1.2, 2.2) * pow(2.1, i), rng.randf() * TAU)
		waves.append(w)
		total += w.x
	for i in n + 1:
		var x := -20.0 + (E.W + 40.0) * float(i) / float(n)
		var u := x / E.W
		var v := 0.0
		for w in waves:
			v += w.x * pow(1.0 - absf(sin(u * w.y * PI + w.z)), 1.6)
		v = v / total + rng.randf_range(-rough, rough)
		pts.append(Vector2(x, base - amp * clampf(v, 0.0, 1.2)))
	return pts

func _gen() -> void:
	ridges = [
		_noise_ridge(430.0, 300.0, 160, 0.02),
		_noise_ridge(450.0, 200.0, 140, 0.025),
		_noise_ridge(462.0, 110.0, 120, 0.03),
	]
	hill_ridge = _noise_ridge(462.0, 26.0, 80, 0.08)
	# Clouds.
	var nc := 4 if env == "dusk" else (7 if env != "winter" else 9)
	for i in nc:
		var c := {"x": rng.randf_range(-200.0, E.W + 200.0), "y": rng.randf_range(40.0, 300.0), "w": rng.randf_range(140.0, 320.0), "puffs": []}
		if env == "dusk":
			c.y = rng.randf_range(260.0, 400.0)
		var np := 7 + rng.randi() % 5
		for j in np:
			var f := float(j) / float(np - 1) - 0.5
			c.puffs.append([f * c.w, -absf(sin(f * PI + 1.57)) * c.w * rng.randf_range(0.1, 0.25), c.w * rng.randf_range(0.16, 0.3)])
		clouds.append(c)
	# Stars (dusk).
	for i in int(pal.stars):
		stars.append(Vector3(rng.randf() * E.W, rng.randf() * 260.0, rng.randf()))
	# Grass tufts: denser and bigger towards the viewer.
	for i in 2600:
		var d := lerpf(60.0, 900.0, pow(rng.randf(), 1.6))
		var x := rng.randf() * E.W
		var y := E.ground_y(d)
		if y > E.H + 10.0:
			continue
		var s := E.scale_at(d)
		var hgt := s * rng.randf_range(0.18, 0.45)
		var col: Color = pal.grass[rng.randi() % pal.grass.size()]
		col = col.lerp(pal.haze, clampf((d - 250.0) / 900.0, 0.0, 0.45))
		for k in 3:
			var lean := (float(k) - 1.0) * 0.45 + rng.randf_range(-0.2, 0.2)
			tufts.append(Vector2(x, y))
			tufts.append(Vector2(x + sin(lean) * hgt, y - cos(lean) * hgt))
			tuft_cols.append(col)
	# Flowers.
	if not pal.flowers.is_empty():
		for i in 700:
			var d := lerpf(60.0, 700.0, pow(rng.randf(), 1.4))
			var s := E.scale_at(d)
			flowers.append([Vector2(rng.randf() * E.W, E.ground_y(d) - s * rng.randf_range(0.05, 0.3)), maxf(0.6, s * 0.05), pal.flowers[rng.randi() % pal.flowers.size()]])
	# Props: framing trees at the sides, clumps in the middle distance, rocks, bushes, logs.
	for i in 6:
		var left := i % 2 == 0
		_prop("tree", rng.randf_range(-60.0, 90.0) if left else rng.randf_range(1510.0, 1660.0), rng.randf_range(110.0, 200.0), rng.randf_range(9.0, 14.0))
	for i in 10:
		_prop("tree", rng.randf_range(0.0, E.W), rng.randf_range(300.0, 700.0), rng.randf_range(9.0, 18.0))
	for i in 3:
		var cx := rng.randf_range(200.0, 1400.0)
		var cd := rng.randf_range(420.0, 650.0)
		for j in 4:
			_prop("tree", cx + rng.randf_range(-60.0, 60.0), cd + rng.randf_range(-20.0, 30.0), rng.randf_range(10.0, 16.0))
	for i in 12:
		_prop("rock", rng.randf_range(40.0, E.W - 40.0), rng.randf_range(80.0, 600.0), rng.randf_range(0.5, 1.3))
	for i in 14:
		_prop("bush", rng.randf_range(0.0, E.W), rng.randf_range(70.0, 620.0), rng.randf_range(0.7, 1.4))
	for i in 3:
		_prop("log", rng.randf_range(150.0, E.W - 150.0), rng.randf_range(90.0, 400.0), rng.randf_range(0.45, 0.6))
	props.sort_custom(func(a, b): return a.d > b.d)
	# Birds.
	for i in 2:
		_new_flock()
	# Weather motes.
	var nm: int = {"pollen": 50, "butterflies": 8, "leaves": 45, "fireflies": 40, "snow": 160}[pal.weather]
	for i in nm:
		motes.append([rng.randf() * E.W, rng.randf() * E.H, rng.randf_range(-6.0, 6.0), rng.randf_range(10.0, 40.0), rng.randf() * TAU, rng.randf_range(0.5, 1.0)])
	# Foreground grass across the bottom.
	for i in 150:
		var col2: Color = pal.grass[rng.randi() % pal.grass.size()].darkened(0.25)
		if env == "winter":
			col2 = Color("7a7458")
		fg.append([rng.randf() * E.W, rng.randf_range(30.0, 90.0), rng.randf_range(-0.3, 0.3), rng.randf() * TAU, col2])

func _prop(kind: String, x: float, d: float, h: float) -> void:
	props.append({"kind": kind, "x": x, "d": d, "h": h, "w": h * rng.randf_range(0.8, 1.6), "seed": rng.randi(), "tone": rng.randf()})

func _new_flock() -> void:
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	birds.append({"x": -100.0 if dir > 0 else E.W + 100.0, "y": rng.randf_range(80.0, 300.0), "vx": dir * rng.randf_range(40.0, 70.0), "n": 3 + rng.randi() % 6, "ph": rng.randf() * TAU})

## Shots flush birds from the trees.
func flush_birds(at: Vector2) -> void:
	birds.append({"x": at.x, "y": minf(at.y - 40.0, 440.0), "vx": (1.0 if rng.randf() < 0.5 else -1.0) * 120.0, "n": 6 + rng.randi() % 6, "ph": 0.0, "climb": 50.0})

## Bushes, rocks, logs and tree trunks stop bullets: [x, d, half width m, height m].
func cover() -> Array:
	var out: Array = []
	for p in props:
		match p.kind:
			"bush":
				out.append([p.x, p.d, p.h * 0.75, p.h * 0.9])
			"rock":
				out.append([p.x, p.d, p.h * 0.8, p.h * 0.75])
			"log":
				out.append([p.x, p.d, p.h * 4.0, p.h])
			"tree":
				out.append([p.x, p.d, p.h * 0.025 + 0.15, p.h])
	return out

# ---------------------------------------------------------------- helpers

func _lit(c: Color) -> Color:
	var l: Color = pal.light
	return Color(c.r * l.r, c.g * l.g, c.b * l.b, c.a)

## Scenery colour for the current look: Skull mode keeps the land cool (dark) so animals stand out hot.
func _dim(c: Color) -> Color:
	return Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, c.a) if voodoo else c

func _glow(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_texture_rect(blob, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

## A vertical gradient rectangle through any number of colour stops.
static func vgrad(c: CanvasItem, r: Rect2, cols: Array) -> void:
	var n := cols.size() - 1
	for i in n:
		var y0 := r.position.y + r.size.y * float(i) / float(n)
		var y1 := r.position.y + r.size.y * float(i + 1) / float(n)
		c.draw_polygon(PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.end.x, y0), Vector2(r.end.x, y1), Vector2(r.position.x, y1)]),
			PackedColorArray([cols[i], cols[i], cols[i + 1], cols[i + 1]]))

static func ellipse(center: Vector2, r: Vector2, n: int = 18, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts

# ---------------------------------------------------------------- static layers

func draw_sky(c: CanvasItem) -> void:
	vgrad(c, Rect2(-400, -400, E.W + 800, E.HORIZON + 420), [pal.sky[0], pal.sky[0], pal.sky[1], pal.sky[2], pal.sky[3]])
	for s in stars:
		c.draw_rect(Rect2(s.x, s.y, 1.2 + s.z * 1.6, 1.2 + s.z * 1.6), Color(1, 1, 1, 0.25 + s.z * 0.6 * (1.0 - s.y / 260.0)))
	var sp: Vector2 = pal.sun_pos
	var sr: float = pal.sun_r
	_glow(c, sp, sr * 14.0, Color(pal.glow, 0.22))
	_glow(c, sp, sr * 6.0, Color(pal.glow, 0.35))
	_glow(c, sp, sr * 2.4, Color(pal.sun, 0.7))
	if env == "dawn" or env == "autumn" or env == "dusk":
		# Faint god rays fanning from the sun.
		for i in 11:
			var a := -0.2 + float(i) * 0.32 + rng.randf_range(-0.05, 0.05)
			var d := Vector2(cos(a), sin(a))
			var side := Vector2(-d.y, d.x)
			var L := 1400.0
			c.draw_colored_polygon(PackedVector2Array([sp, sp + d * L + side * L * 0.05, sp + d * L - side * L * 0.05]),
				Color(pal.glow, 0.035 if i % 2 == 0 else 0.02))
	c.draw_circle(sp, sr, pal.sun)

func draw_land(c: CanvasItem) -> void:
	var haze: Color = pal.haze
	var base_y := E.HORIZON
	# Three ranges, farthest first. Each is a strip of quads (ridge -> mid -> foot) with
	# per-vertex colours: slopes facing the sun lit, the others in cool shadow, the foot fading
	# into the haze. Shared vertices share colours, so the shading is smooth (no stripes).
	var sunx: float = (pal.sun_pos as Vector2).x
	for li in 3:
		var rp: PackedVector2Array = ridges[li]
		var n := rp.size()
		var col: Color = pal.mtn[li]
		var foot: Color = col.lerp(haze, 0.62 - li * 0.16)
		var peak := base_y
		for p in rp:
			peak = minf(peak, p.y)
		var lit: Array = []
		for i in n:
			var a := rp[maxi(i - 1, 0)]
			var b := rp[mini(i + 1, n - 1)]
			var slope := (b.y - a.y) / maxf(1.0, b.x - a.x)
			lit.append(clampf(slope * (1.0 if sunx > rp[i].x else -1.0) * 1.3, -1.0, 1.0))
		# Smooth the light over neighbours so faces read as broad planes, not stripes.
		var sm: Array = []
		for i in n:
			var acc := 0.0
			var wsum := 0.0
			for j in range(-3, 4):
				var k := clampi(i + j, 0, n - 1)
				var wt := 4.0 - absf(float(j))
				acc += float(lit[k]) * wt
				wsum += wt
			sm.append(acc / wsum)
		lit = sm
		var light: Color = col.lerp(pal.glow, 0.25).lightened(0.25)
		var shadow: Color = col.darkened(0.28).lerp(Color(0.18, 0.2, 0.38), 0.15)
		var top_c: Array = []
		var mid_c: Array = []
		var mid_p: Array = []
		for i in n:
			var sh: float = lit[i]
			var tc: Color = col.lerp(light, sh) if sh > 0.0 else col.lerp(shadow, -sh)
			top_c.append(tc)
			mid_c.append(col.lerp(tc, 0.35).lerp(foot, 0.25))
			mid_p.append(Vector2(rp[i].x, rp[i].y + (base_y - rp[i].y) * 0.45))
		for i in n - 1:
			var a := rp[i]
			var b := rp[i + 1]
			c.draw_polygon(PackedVector2Array([a, b, mid_p[i + 1], mid_p[i]]),
				PackedColorArray([top_c[i], top_c[i + 1], mid_c[i + 1], mid_c[i]]))
			c.draw_polygon(PackedVector2Array([mid_p[i], mid_p[i + 1], Vector2(b.x, base_y + 4.0), Vector2(a.x, base_y + 4.0)]),
				PackedColorArray([mid_c[i], mid_c[i + 1], foot, foot]))
		# Snow caps on the high peaks only, with a ragged lower edge.
		var frac: float = [0.42, 0.3, 0.16][li] * (1.7 if env == "winter" else 1.0)
		var sl := peak + (base_y - peak) * frac
		var snow: Color = pal.snow.lerp(haze, 0.2 - li * 0.06)
		var snow_lit: Color = snow.lerp(pal.glow, 0.18)
		var snow_sh: Color = snow.darkened(0.18).lerp(Color(0.55, 0.62, 0.85), 0.25)
		for i in n - 1:
			var a := rp[i]
			var b := rp[i + 1]
			if a.y >= sl and b.y >= sl:
				continue
			var ja := sl + sin(a.x * 0.13) * 9.0 + sin(a.x * 0.37 + li) * 6.0 + sin(a.x * 0.051) * 14.0
			var jb := sl + sin(b.x * 0.13) * 9.0 + sin(b.x * 0.37 + li) * 6.0 + sin(b.x * 0.051) * 14.0
			var ab := maxf(a.y, ja)
			var bb := maxf(b.y, jb)
			var sa: float = lit[i]
			var sb: float = lit[i + 1]
			var ca: Color = snow.lerp(snow_lit, sa) if sa > 0.0 else snow.lerp(snow_sh, -sa)
			var cb: Color = snow.lerp(snow_lit, sb) if sb > 0.0 else snow.lerp(snow_sh, -sb)
			c.draw_polygon(PackedVector2Array([a, b, Vector2(b.x, bb), Vector2(a.x, ab)]),
				PackedColorArray([ca, cb, cb, ca]))
		# A few faint gullies down the faces.
		for g in 10:
			var i := rng.randi() % (n - 1)
			var p := rp[i]
			var pts := PackedVector2Array([p])
			var q := p
			for k in 5:
				q += Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(8.0, 18.0))
				pts.append(q)
			c.draw_polyline(pts, Color(col.darkened(0.4), 0.08 if env == "winter" else 0.16), 1.2)
		# Haze pooling at the foot of each range.
		vgrad(c, Rect2(-20, base_y - 70.0 + li * 18.0, E.W + 40, 74.0 - li * 18.0), [Color(haze, 0.0), Color(haze, 0.35)])
	# Forested foothills.
	var hcol: Color = pal.hill
	var hp := PackedVector2Array(hill_ridge)
	hp.append(Vector2(E.W + 20.0, base_y + 4.0))
	hp.append(Vector2(-20.0, base_y + 4.0))
	c.draw_colored_polygon(hp, hcol)
	for i in range(0, hill_ridge.size(), 1):
		var p := hill_ridge[i]
		for j in 2:
			var x := p.x + rng.randf_range(-8.0, 8.0)
			var y := p.y + rng.randf_range(0.0, 12.0)
			_pine(c, Vector2(x, y + 2.0), rng.randf_range(9.0, 16.0), hcol.darkened(0.15), env == "winter")
	# Mist lying on the hills.
	if float(pal.mist) > 0.0:
		for i in 18:
			_glow(c, Vector2(rng.randf() * E.W, base_y - rng.randf_range(0.0, 25.0)), rng.randf_range(80.0, 160.0), Color(haze, 0.18 * float(pal.mist)))
	# The lake: sky colours mirrored, the hills and mountains upside down and faded.
	var lake_top := base_y
	var lake_bot := 500.0
	vgrad(c, Rect2(-20, lake_top, E.W + 40, lake_bot - lake_top), [pal.lake[0], pal.lake[0].lerp(pal.lake[1], 0.6)])
	for li in 3:
		var rp2: PackedVector2Array = ridges[li]
		var refl := PackedVector2Array()
		for p in rp2:
			refl.append(Vector2(p.x, lake_top + (lake_top - p.y) * 0.18))
		refl.append(Vector2(rp2[rp2.size() - 1].x, lake_top))
		refl.append(Vector2(rp2[0].x, lake_top))
		c.draw_colored_polygon(refl, Color(pal.mtn[li], 0.22))
	var sp: Vector2 = pal.sun_pos
	_glow(c, Vector2(sp.x, lake_top + 14.0), 60.0, Color(pal.sun, 0.35))
	# Far-shore pines standing at the water's edge, and their reflections.
	var fcol: Color = pal.forest
	for i in 260:
		var x := rng.randf_range(-10.0, E.W + 10.0)
		var h := rng.randf_range(10.0, 26.0)
		_pine(c, Vector2(x, lake_top + 1.0), h, fcol.lerp(haze, rng.randf_range(0.0, 0.18)), env == "winter")
		_pine_reflect(c, Vector2(x, lake_top + 1.0), h, Color(fcol, 0.28))
	# Near shore: a pale strip of sand / reeds.
	vgrad(c, Rect2(-20, lake_bot - 2.0, E.W + 40, 8.0), [Color(pal.path.lightened(0.2), 0.0), pal.path.lerp(haze, 0.3)])
	for i in 180:
		var x := rng.randf() * E.W
		var h := rng.randf_range(4.0, 10.0)
		c.draw_line(Vector2(x, lake_bot + 3.0), Vector2(x + rng.randf_range(-2.0, 2.0), lake_bot + 3.0 - h), Color(pal.grass[0].darkened(0.2).lerp(haze, 0.3), 0.8), 1.0)
	# The meadow: hazy far, rich near.
	var g: Array = pal.ground
	vgrad(c, Rect2(-20, lake_bot + 3.0, E.W + 40, E.H - lake_bot + 20.0), [g[0].lerp(haze, 0.35), g[0], g[1], g[2]])
	# Gentle swells and shadows across the meadow: soft, wide patches.
	for i in 26:
		var d := lerpf(80.0, 650.0, rng.randf())
		var y := E.ground_y(d)
		var hgt := E.scale_at(d) * rng.randf_range(1.0, 3.0)
		var w := rng.randf_range(250.0, 700.0)
		var sh := Color(0.0, 0.05, 0.0, 0.10) if i % 2 == 0 else Color(1, 1, 0.85, 0.07)
		c.draw_texture_rect(blob, Rect2(rng.randf_range(-200.0, E.W) , y - hgt * 0.5, w, hgt), false, sh)
	# The dirt track winding away.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var d2 := 40.0
	while d2 <= 700.0:
		var cx := 860.0 + 260.0 * sin(d2 / 140.0) - 120.0 * sin(d2 / 53.0)
		var hw := E.scale_at(d2) * 1.6
		var y := E.ground_y(d2)
		left.append(Vector2(cx - hw, y))
		right.append(Vector2(cx + hw, y))
		d2 += 6.0 if d2 < 150.0 else 14.0
	var track := PackedVector2Array(left)
	right.reverse()
	track.append_array(right)
	c.draw_colored_polygon(track, Color(pal.path, 0.75))
	# Wheel ruts.
	right.reverse()
	var r1 := PackedVector2Array()
	var r2 := PackedVector2Array()
	for i in left.size():
		r1.append(left[i].lerp(right[i], 0.3))
		r2.append(left[i].lerp(right[i], 0.7))
	c.draw_polyline(r1, Color(pal.path.darkened(0.25), 0.6), 2.0)
	c.draw_polyline(r2, Color(pal.path.darkened(0.25), 0.6), 2.0)
	if env == "winter":
		# Snow drifts: soft white humps.
		for i in 60:
			var d := lerpf(70.0, 650.0, rng.randf())
			var s := E.scale_at(d)
			var p := Vector2(rng.randf() * E.W, E.ground_y(d))
			c.draw_colored_polygon(ellipse(p, Vector2(s * rng.randf_range(1.0, 3.0), s * 0.25), 14), Color(1, 1, 1, 0.5))
	# Grass and flowers.
	c.draw_multiline_colors(tufts, tuft_cols, 1.2)
	for f in flowers:
		c.draw_circle(f[0], f[1], f[2])

func _pine(c: CanvasItem, base: Vector2, h: float, col: Color, snow: bool) -> void:
	var w := h * 0.42
	c.draw_line(base, base - Vector2(0, h * 0.2), col.darkened(0.3), maxf(1.0, h * 0.06))
	for k in 3:
		var y0 := base.y - h * (0.15 + 0.27 * k)
		var ww := w * (1.0 - 0.28 * k)
		var top := base.y - h * (0.5 + 0.25 * k)
		var tri := PackedVector2Array([Vector2(base.x - ww, y0), Vector2(base.x + ww, y0), Vector2(base.x, top)])
		c.draw_colored_polygon(tri, col)
		if snow:
			c.draw_colored_polygon(PackedVector2Array([Vector2(base.x - ww * 0.45, top + (y0 - top) * 0.45), Vector2(base.x + ww * 0.45, top + (y0 - top) * 0.45), Vector2(base.x, top)]), Color(1, 1, 1, 0.85))

func _pine_reflect(c: CanvasItem, base: Vector2, h: float, col: Color) -> void:
	var w := h * 0.42
	var hh := h * 0.55
	c.draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, base.y), Vector2(base.x + w, base.y), Vector2(base.x, base.y + hh)]), col)

# ---------------------------------------------------------------- dynamic layers

func draw_clouds(c: CanvasItem, t: float, wind: float) -> void:
	var flat := 0.38 if env in ["dawn", "dusk"] else 1.0
	for cl in clouds:
		var x := fposmod(cl.x + t * (4.0 + wind * 2.0) + 400.0, E.W + 800.0) - 400.0
		for p in cl.puffs:
			var r: float = p[2] * 1.5
			var q := Vector2(x + p[0], cl.y + p[1] * flat + p[2] * 0.35 * flat)
			c.draw_texture_rect(blob, Rect2(q - Vector2(r * (2.0 - flat), r * flat), Vector2(r * (2.0 - flat) * 2.0, r * flat * 2.0)), false, Color(pal.cloud_shade, 0.4 * flat))
		for p in cl.puffs:
			var r2: float = p[2] * 1.3
			var q2 := Vector2(x + p[0], cl.y + p[1] * flat)
			c.draw_texture_rect(blob, Rect2(q2 - Vector2(r2 * (2.0 - flat), r2 * flat), Vector2(r2 * (2.0 - flat) * 2.0, r2 * flat * 2.0)), false, Color(pal.cloud, 0.75))
			# Sunlit rim on the side facing the sun.
			var toward := ((pal.sun_pos as Vector2) - q2).normalized() * r2 * 0.25
			c.draw_texture_rect(blob, Rect2(q2 + toward - Vector2(r2, r2 * flat) * 0.6, Vector2(r2, r2 * flat) * 1.2), false, Color(pal.glow, 0.18))
	# Birds: little flapping Vs.
	for b in birds.duplicate():
		for i in b.n:
			var off := Vector2(-signf(b.vx) * (i / 2) * 14.0, (i / 2) * 7.0 * (1 if i % 2 == 0 else -1))
			var p := Vector2(b.x, b.y) + off
			var flap := sin(t * 9.0 + b.ph + i) * 3.5
			c.draw_polyline(PackedVector2Array([p + Vector2(-6, -flap), p, p + Vector2(6, -flap)]), Color(0.1, 0.1, 0.12, 0.8), 1.4)

func tick(dt: float) -> void:
	for b in birds.duplicate():
		b.x += b.vx * dt
		if b.has("climb"):
			b.y -= b.climb * dt
			b.climb = maxf(0.0, b.climb - dt * 20.0)
		if b.x < -300.0 or b.x > E.W + 300.0:
			birds.erase(b)
	if birds.size() < 2 and rng.randf() < dt * 0.05:
		_new_flock()

func draw_water(c: CanvasItem, t: float) -> void:
	# Ripples glinting on the lake.
	for i in 40:
		var y := E.HORIZON + 3.0 + fposmod(float(i) * 7.3, 28.0)
		var x := fposmod(float(i) * 131.7 + t * (6.0 + float(i % 5)), E.W + 80.0) - 40.0
		var w := 10.0 + float(i % 7) * 6.0
		var a := 0.25 + 0.2 * sin(t * 1.7 + float(i))
		c.draw_line(Vector2(x, y), Vector2(x + w, y), Color(pal.sun, a * 0.6), 1.0)
	# Slow mist banks over the meadow.
	if float(pal.mist) > 0.0:
		for i in 8:
			var x := fposmod(float(i) * 260.0 + t * 5.0, E.W + 600.0) - 300.0
			var y := 505.0 + float(i % 3) * 14.0
			_glow(c, Vector2(x, y), 150.0 + float(i % 4) * 40.0, Color(pal.haze, 0.13 * float(pal.mist)))

## Props and animals, far to near (so nearer things hide farther ones), only those in `view`.
func draw_actors(c: CanvasItem, eng, view: Rect2, t: float, wind: float, marks: Dictionary) -> void:
	var items: Array = []
	for p in props:
		items.append([p.d, 0, p])
	for a in eng.animals:
		items.append([a.d, 1, a])
	items.sort_custom(func(x, y): return x[0] > y[0])
	for it in items:
		if it[1] == 0:
			var p: Dictionary = it[2]
			var s := E.scale_at(p.d)
			var r := Rect2(p.x - p.w * s, E.ground_y(p.d) - p.h * s * 1.1, p.w * s * 2.0, p.h * s * 1.2)
			if r.intersects(view):
				_draw_prop(c, p, t, wind)
		else:
			var a: Dictionary = it[2]
			var s2 := E.scale_at(a.d)
			var r2 := Rect2(a.x - s2 * 2.0, E.ground_y(a.d) - s2 * 2.5, s2 * 4.0, s2 * 3.0)
			if r2.intersects(view):
				draw_animal(c, eng, a, t, marks.get(a.id, ""))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_prop(c: CanvasItem, p: Dictionary, t: float, wind: float) -> void:
	var s := E.scale_at(p.d)
	var base := Vector2(p.x, E.ground_y(p.d))
	var haze_k := clampf((p.d - 200.0) / 900.0, 0.0, 0.4)
	var hz: Color = pal.haze
	match p.kind:
		"tree":
			var h: float = p.h * s
			var sway: float = sin(t * 0.8 + p.tone * 6.0) * (0.4 + absf(wind) * 0.15) * s * 0.02 * p.h
			var trunk: Color = _dim(_lit(pal.trunk).lerp(hz, haze_k))
			var kind := str(pal.tree)
			if kind == "oak":
				c.draw_line(base, base - Vector2(0, h * 0.55), trunk, maxf(1.0, s * 0.35))
				c.draw_line(base - Vector2(0, h * 0.4), base - Vector2(h * 0.18, h * 0.62), trunk, maxf(1.0, s * 0.18))
				c.draw_line(base - Vector2(0, h * 0.45), base - Vector2(-h * 0.16, h * 0.66), trunk, maxf(1.0, s * 0.16))
				var lrng := RandomNumberGenerator.new()
				lrng.seed = p.seed
				var leaves: Array = pal.leaf
				for k in 9:
					var off := Vector2(lrng.randf_range(-0.32, 0.32) * h + sway * (0.5 + k * 0.1), -h * lrng.randf_range(0.55, 0.95))
					var col: Color = _dim(_lit(leaves[lrng.randi() % leaves.size()]).lerp(hz, haze_k))
					c.draw_circle(base + off + Vector2(0, h * 0.04), h * lrng.randf_range(0.17, 0.25), col.darkened(0.25))
					c.draw_circle(base + off, h * lrng.randf_range(0.15, 0.22), col)
			else:
				var leaf: Color = _dim(_lit(pal.leaf[0]).lerp(hz, haze_k))
				var leaf2: Color = _dim(_lit(pal.leaf[1 % pal.leaf.size()]).lerp(hz, haze_k))
				c.draw_line(base, base - Vector2(0, h * 0.3), trunk, maxf(1.0, s * 0.3))
				var tiers := 6
				for k in tiers:
					var f := float(k) / float(tiers)
					var y0 := base.y - h * (0.12 + 0.8 * f)
					var ww := h * 0.34 * (1.0 - f * 0.85)
					var tip := Vector2(base.x + sway * f, y0 - h * 0.24)
					var l := Vector2(base.x - ww + sway * f * 0.6, y0 + h * 0.02)
					var r := Vector2(base.x + ww + sway * f * 0.6, y0 + h * 0.02)
					c.draw_colored_polygon(PackedVector2Array([l, r, tip]), leaf.darkened(0.1) if k % 2 == 0 else leaf2)
					# Lit edge on the sun side.
					var sunx: float = (pal.sun_pos as Vector2).x
					var edge := r if sunx > p.x else l
					c.draw_line(tip, edge, Color(1, 1, 0.9, 0.12), maxf(1.0, s * 0.08))
					if kind == "pine_snow":
						c.draw_colored_polygon(PackedVector2Array([tip, tip.lerp(l, 0.45), tip.lerp(r, 0.45)]), Color(1, 1, 1, 0.9))
		"rock":
			var w: float = p.h * s
			var lrng2 := RandomNumberGenerator.new()
			lrng2.seed = p.seed
			var pts := PackedVector2Array()
			for k in 9:
				var a := PI + PI * float(k) / 8.0
				pts.append(base + Vector2(cos(a) * w * lrng2.randf_range(0.7, 1.0), sin(a) * w * 0.75 * lrng2.randf_range(0.7, 1.0)))
			var rc: Color = _dim(_lit(pal.rock).lerp(hz, haze_k))
			c.draw_colored_polygon(pts, rc.darkened(0.15))
			var hi := PackedVector2Array()
			for k in range(2, 7):
				hi.append(pts[k].lerp(base - Vector2(0, w * 0.2), 0.25))
			hi.append(base - Vector2(0, w * 0.15))
			c.draw_colored_polygon(hi, rc.lightened(0.12))
			if env == "winter":
				c.draw_colored_polygon(ellipse(base - Vector2(0, w * 0.6), Vector2(w * 0.55, w * 0.16), 12), Color(1, 1, 1, 0.9))
			c.draw_colored_polygon(ellipse(base, Vector2(w * 1.05, w * 0.12), 12), Color(0, 0, 0, 0.18))
		"bush":
			var w2: float = p.h * s
			var lrng3 := RandomNumberGenerator.new()
			lrng3.seed = p.seed
			var bc: Color = _dim(_lit(pal.leaf[0]).lerp(hz, haze_k))
			if env == "autumn":
				bc = _dim(_lit(pal.leaf[lrng3.randi() % pal.leaf.size()]).lerp(hz, haze_k))
			c.draw_colored_polygon(ellipse(base, Vector2(w2 * 0.9, w2 * 0.14), 12), Color(0, 0, 0, 0.2))
			for k in 7:
				var off := Vector2(lrng3.randf_range(-0.6, 0.6) * w2 + sin(t + k) * s * 0.01, -w2 * lrng3.randf_range(0.25, 0.7))
				var rr := w2 * lrng3.randf_range(0.28, 0.42)
				c.draw_circle(base + off, rr, bc.darkened(0.12 + 0.05 * (k % 3)))
				c.draw_circle(base + off - Vector2(rr * 0.2, rr * 0.25), rr * 0.6, bc.lightened(0.06))
			if env == "winter":
				c.draw_colored_polygon(ellipse(base - Vector2(0, w2 * 0.85), Vector2(w2 * 0.6, w2 * 0.15), 12), Color(1, 1, 1, 0.85))
		"log":
			var r3: float = p.h * s
			var len := r3 * 8.0
			var lc: Color = _dim(_lit(pal.trunk.lightened(0.15)).lerp(hz, haze_k))
			c.draw_rect(Rect2(base.x - len * 0.5, base.y - r3 * 2.0, len, r3 * 2.0), lc)
			c.draw_line(Vector2(base.x - len * 0.5, base.y - r3 * 1.4), Vector2(base.x + len * 0.5, base.y - r3 * 1.5), lc.darkened(0.25), maxf(1.0, r3 * 0.15))
			c.draw_colored_polygon(ellipse(Vector2(base.x + len * 0.5, base.y - r3), Vector2(r3 * 0.5, r3), 12), lc.lightened(0.3))
			c.draw_arc(Vector2(base.x + len * 0.5, base.y - r3), r3 * 0.5, 0, TAU, 12, lc.darkened(0.2), maxf(1.0, r3 * 0.08))

# ---------------------------------------------------------------- animals

## Colours for one animal kind: [back, belly, legs, accent].
func _coat(kind: String) -> Array:
	if voodoo:
		# Thermal: warm bodies glow; the filter turns this into hot magenta / orange / white.
		return [Color(0.92, 0.92, 0.92), Color(1, 1, 1), Color(0.8, 0.8, 0.8), Color(1, 1, 1)]
	var c: Array
	match kind:
		"buck":
			c = [Color("7e5028"), Color("d4ac80"), Color("4a3020"), Color("e8dcc0")]
		"doe":
			c = [Color("8e5c30"), Color("dcb88e"), Color("50361f"), Color("f4ece0")]
		"fawn":
			c = [Color("a8642e"), Color("e0bc90"), Color("5a3a20"), Color("fbf1df")]
		"boar":
			c = [Color("3e332c"), Color("5e5046"), Color("221c18"), Color("efe6d8")]
		"fox":
			c = [Color("c8561c"), Color("f6eee2"), Color("261a14"), Color("fbfaf6")]
		_:
			c = [Color("85705a"), Color("cdbca5"), Color("5a4a3a"), Color("f6f2ea")]
	for i in c.size():
		c[i] = _lit(c[i])
	return c

## One animal in its own metre frame: x towards the head, y up, origin on the ground.
func draw_animal(c: CanvasItem, eng, a: Dictionary, t: float, mark: String) -> void:
	var s := E.scale_at(a.d)
	var k: Dictionary = E.KINDS[a.kind]
	var L: float = k.len
	var h: float = k.h
	var base := Vector2(a.x, E.ground_y(a.d))
	var col := _coat(a.kind)
	var running: bool = a.state == "flee" or (a.kind == "hare" and a.speed > 1.0)
	var walking: bool = a.speed > 0.05
	var cyc: float = a.phase * (11.0 if running else 5.5)
	var bob := (absf(sin(cyc)) * 0.08 * h) if running else 0.0
	# Shadow on the ground.
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	c.draw_colored_polygon(ellipse(base, Vector2(L * 0.6 * s, L * 0.07 * s), 14), Color(0, 0, 0, 0.22))
	if mark != "":
		# Spotter help: a ring round each target.
		var mc := Color(1.0, 0.85, 0.2, 0.85) if mark == "target" else Color(1.0, 0.3, 0.3, 0.85)
		c.draw_arc(base - Vector2(0, h * 0.8 * s), maxf(L, h * 1.4) * 0.75 * s, 0, TAU, 32, mc, maxf(1.0, s * 0.04))
	# Fall: the animal tips over sideways as `fall` goes 0 -> 1.
	# Down: the animal lies on its side -- body lowered and flattened, legs stretched out.
	var down: bool = a.state == "down"
	var squash: float = lerpf(1.0, 0.42, a.fall) if down else 1.0
	c.draw_set_transform_matrix(Transform2D(0.0, base).scaled_local(Vector2(s * a.dir, -s * squash)))
	var pt: Dictionary = eng.parts(a)
	var body_c: Vector2 = pt.body + Vector2(0, bob)
	var head_c: Vector2 = pt.head + Vector2(0, bob)
	if down:
		head_c = head_c.lerp(Vector2(L * 0.78, h * 0.3), a.fall)
	var alert: bool = a.state == "alert"
	if alert and a.kind in ["buck", "doe", "fawn"]:
		head_c += Vector2(-0.04, 0.12) * h
	var lw := 0.075 * h * (0.7 if a.kind in ["fox", "hare"] else 1.0)
	if a.kind == "boar":
		lw = 0.11 * h
	# Legs: far pair first (darker), then near pair.
	var legs := [[L * 0.32, 0.0, true], [-L * 0.3, PI, true], [L * 0.36, PI, false], [-L * 0.26, 0.0, false]]
	var leg_top := body_c.y - (pt.body_r as Vector2).y * 0.4
	for lg in legs:
		var amp := 0.0
		if walking:
			amp = 0.55 if running else 0.3
		var ang: float = sin(cyc + lg[1]) * amp
		if down:
			ang = (1.25 if lg[0] > 0.0 else -1.25) * a.fall
		var hip := Vector2(lg[0], leg_top)
		var leg_len := leg_top
		var knee := hip + Vector2(sin(ang) * leg_len * 0.5, -cos(ang) * leg_len * 0.5)
		var bend := 0.25 if lg[0] > 0.0 else -0.25
		var foot := knee + Vector2(sin(ang + bend * (1.0 + absf(ang))) * leg_len * 0.5, -cos(ang + bend) * leg_len * 0.5)
		if a.kind == "hare" and lg[0] < 0.0 and not down:
			# Big folded hind legs.
			knee = hip + Vector2(-L * 0.12, -leg_len * 0.35)
			foot = Vector2(hip.x + L * 0.12, 0.0)
		var lc: Color = col[2] if lg[2] else col[2].lightened(0.08)
		if lg[2]:
			lc = lc.darkened(0.2)
		c.draw_line(hip, knee, lc, lw * 1.45)
		c.draw_line(knee, foot, lc, lw * 0.8)
		c.draw_circle(knee, lw * 0.55, lc)
		if a.kind in ["buck", "doe", "fawn", "boar"]:
			c.draw_circle(foot, lw * 0.6, Color(0.1, 0.08, 0.07) if not voodoo else lc)
	# Tail.
	match a.kind:
		"fox":
			var tail := PackedVector2Array()
			var wag := sin(t * 3.0 + a.phase) * 0.05
			for i in 9:
				var f := float(i) / 8.0
				tail.append(body_c + Vector2(-L * (0.45 + 0.65 * f), -h * 0.15 - f * h * 0.25 + wag * f) + Vector2(0, h * 0.13 * sin(f * PI)))
			for i in range(8, -1, -1):
				var f2 := float(i) / 8.0
				tail.append(body_c + Vector2(-L * (0.45 + 0.65 * f2), -h * 0.15 - f2 * h * 0.25 + wag * f2) - Vector2(0, h * 0.13 * sin(f2 * PI)))
			c.draw_colored_polygon(tail, col[0])
			c.draw_circle(body_c + Vector2(-L * 1.08, -h * 0.4 + wag), h * 0.09, col[3])
		"hare":
			c.draw_circle(body_c + Vector2(-L * 0.48, h * 0.05), h * 0.12, col[3])
		"boar":
			c.draw_line(body_c + Vector2(-L * 0.48, h * 0.05), body_c + Vector2(-L * 0.58, -h * 0.15 + sin(t * 6.0) * 0.03), col[2], lw * 0.4)
		_:
			var flick := 0.04 * sin(t * 8.0) if alert else 0.0
			c.draw_colored_polygon(ellipse(body_c + Vector2(-L * 0.5, h * 0.08 + flick), Vector2(h * 0.07, h * 0.11), 10), col[3])
	# Body: darker back, lighter belly (vertex colours).
	var br: Vector2 = pt.body_r
	var bpts := PackedVector2Array()
	var bcols := PackedColorArray()
	for i in 22:
		var an := TAU * float(i) / 22.0
		var v := Vector2(cos(an) * br.x, sin(an) * br.y)
		if a.kind == "boar" and v.x > 0.0 and v.y > 0.0:
			v.y *= 1.35   # the boar's hump
		if v.x > 0.0:
			v.y *= 1.08   # deeper chest
		if a.kind == "hare":
			v = v.rotated(0.12 * sin(cyc) if running else 0.12)
		bpts.append(body_c + v)
		bcols.append(col[1].lerp(col[0], clampf(0.5 + sin(an) * 0.9, 0.0, 1.0)))
	c.draw_polygon(bpts, bcols)
	if a.kind == "boar":
		# Bristly ridge along the back.
		var ridge := PackedVector2Array()
		for i in 9:
			var f := float(i) / 8.0
			var x := lerpf(-br.x * 0.7, br.x * 0.8, f)
			var yb := body_c.y + br.y * sqrt(maxf(0.0, 1.0 - pow(x / br.x, 2.0))) * (1.3 if x > 0.0 else 1.05)
			ridge.append(Vector2(x, yb + (0.05 if i % 2 == 0 else 0.0) * h))
		c.draw_polyline(ridge, col[2], lw * 0.5)
	if a.kind == "fawn" and not voodoo:
		var srng := RandomNumberGenerator.new()
		srng.seed = int(a.id) * 13
		for i in 12:
			c.draw_circle(body_c + Vector2(srng.randf_range(-0.8, 0.7) * br.x, srng.randf_range(0.0, 0.8) * br.y), h * 0.035, col[3])
	# Neck and head.
	var shoulder := body_c + Vector2(br.x * 0.62, br.y * 0.45)
	var hr: float = pt.head_r
	match a.kind:
		"boar":
			var snout := head_c + Vector2(hr * 1.5, -hr * 0.55)
			c.draw_colored_polygon(ellipse(shoulder.lerp(head_c, 0.5), Vector2(hr * 1.2, hr * 0.95), 14), col[0])
			c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(-hr * 0.6, hr * 0.9), head_c + Vector2(-hr * 0.8, -hr * 0.7), snout + Vector2(0, -hr * 0.35), snout + Vector2(0, hr * 0.3)]), col[0].lerp(col[1], 0.2))
			c.draw_colored_polygon(ellipse(snout, Vector2(hr * 0.2, hr * 0.34), 10), col[1].lightened(0.15))
			c.draw_line(snout + Vector2(-hr * 0.4, -hr * 0.2), snout + Vector2(-hr * 0.15, hr * 0.35), col[3], lw * 0.4)
			c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(-hr * 0.3, hr * 0.7), head_c + Vector2(-hr * 0.1, hr * 1.35), head_c + Vector2(hr * 0.15, hr * 0.75)]), col[2])
			c.draw_circle(head_c + Vector2(hr * 0.4, hr * 0.3), hr * 0.08, Color(0.05, 0.03, 0.02))
		"hare":
			c.draw_colored_polygon(ellipse(head_c, Vector2(hr * 1.15, hr * 0.85), 14, -0.2), col[0].lerp(col[1], 0.3))
			var ear_up := 0.25 if alert else 0.0
			for e in 2:
				var ec := head_c + Vector2(-hr * 0.4 - e * hr * 0.25, hr * 1.2)
				c.draw_colored_polygon(ellipse(ec + Vector2(-hr * 0.3, hr * 0.6), Vector2(hr * 0.28, hr * 1.25), 12, 0.5 - ear_up - e * 0.15), col[0].darkened(0.1 * e))
			c.draw_circle(head_c + Vector2(hr * 0.45, hr * 0.15), hr * 0.13, Color(0.08, 0.05, 0.03))
		"fox":
			c.draw_line(shoulder, head_c, col[0], hr * 1.1)
			c.draw_circle(shoulder, hr * 0.55, col[0])
			c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(-hr * 0.7, hr * 0.5), head_c + Vector2(-hr * 0.6, -hr * 0.5), head_c + Vector2(hr * 1.6, -hr * 0.25), head_c + Vector2(hr * 0.6, hr * 0.55)]), col[0])
			c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(-hr * 0.5, -hr * 0.5), head_c + Vector2(hr * 1.6, -hr * 0.25), head_c + Vector2(hr * 0.3, -hr * 0.05)]), col[1])
			for e in 2:
				var ex := -hr * 0.45 + e * hr * 0.35
				c.draw_colored_polygon(PackedVector2Array([head_c + Vector2(ex - hr * 0.25, hr * 0.45), head_c + Vector2(ex + hr * 0.25, hr * 0.45), head_c + Vector2(ex - hr * 0.05, hr * 1.35)]), col[0].darkened(0.15 * e))
			c.draw_circle(head_c + Vector2(hr * 1.6, -hr * 0.25), hr * 0.12, Color(0.05, 0.03, 0.02))
			c.draw_circle(head_c + Vector2(hr * 0.4, hr * 0.15), hr * 0.1, Color(0.05, 0.03, 0.02))
		_:
			# Deer: tapered neck, a shaped head (pale muzzle, black nose, bright eye), leaf ears.
			var neck_w := h * 0.1
			var nd := (head_c - shoulder).normalized()
			var nn := Vector2(-nd.y, nd.x)
			var neck_c: Color = col[0].lerp(col[1], 0.12)
			c.draw_colored_polygon(PackedVector2Array([shoulder + nn * neck_w * 1.7, head_c + nn * neck_w * 0.8, head_c - nn * neck_w * 0.8, shoulder - nn * neck_w * 1.9]), neck_c)
			var face := nd.rotated(-1.15 if a.state != "graze" else -0.35)
			var fn := Vector2(-face.y, face.x)
			var hp := func(x: float, y: float) -> Vector2: return head_c + face * hr * x + fn * hr * y
			var ear_dir := (-face).rotated(-0.9 if alert else -0.5)
			# Far ear behind the head.
			c.draw_colored_polygon(ellipse(hp.call(-0.25, 0.55) + ear_dir * hr * 0.8, Vector2(hr * 0.85, hr * 0.32), 12, ear_dir.angle()), col[0].darkened(0.15))
			var head := PackedVector2Array([hp.call(-0.7, 0.2), hp.call(-0.3, 0.75), hp.call(0.4, 0.62), hp.call(1.6, 0.28), hp.call(2.15, 0.02),
				hp.call(2.0, -0.32), hp.call(1.0, -0.55), hp.call(-0.4, -0.62)])
			c.draw_colored_polygon(head, col[0].lerp(col[1], 0.2))
			# Paler muzzle and chin, throat patch.
			c.draw_colored_polygon(PackedVector2Array([hp.call(1.45, 0.2), hp.call(2.12, 0.0), hp.call(1.98, -0.3), hp.call(1.3, -0.45)]), col[1].lerp(col[3], 0.4))
			c.draw_colored_polygon(ellipse(head_c - fn * hr * 0.55 - face * hr * 0.6, Vector2(hr * 0.5, hr * 0.28), 10, face.angle()), col[3])
			c.draw_circle(hp.call(2.05, 0.02), hr * 0.17, Color(0.08, 0.06, 0.05) if not voodoo else col[0])
			c.draw_circle(hp.call(0.45, 0.28), hr * 0.15, Color(0.05, 0.03, 0.02) if not voodoo else col[2])
			c.draw_circle(hp.call(0.5, 0.33), hr * 0.05, Color(1, 1, 1, 0.8))
			# Near ear.
			c.draw_colored_polygon(ellipse(hp.call(-0.35, 0.6) + ear_dir * hr * 0.8, Vector2(hr * 0.85, hr * 0.32), 12, ear_dir.angle()), col[0])
			c.draw_colored_polygon(ellipse(hp.call(-0.35, 0.6) + ear_dir * hr * 0.85, Vector2(hr * 0.55, hr * 0.16), 10, ear_dir.angle()), col[1].lerp(col[3], 0.3))
			if a.kind == "buck":
				var ac: Color = col[3].darkened(0.12)
				var top := head_c - face * hr * 0.2 + fn * hr * 0.7
				for side in 2:
					var sx := 1.0 - side * 0.35
					var beam := PackedVector2Array([top, top + Vector2(-0.12, 0.25) * sx, top + Vector2(-0.18, 0.5) * sx, top + Vector2(-0.08, 0.72) * sx])
					c.draw_polyline(beam, ac.darkened(0.15 * side), lw * 0.35)
					c.draw_line(beam[1], beam[1] + Vector2(0.12, 0.12) * sx, ac.darkened(0.15 * side), lw * 0.3)
					c.draw_line(beam[2], beam[2] + Vector2(0.1, 0.15) * sx, ac.darkened(0.15 * side), lw * 0.28)
					c.draw_line(beam[2], beam[2] + Vector2(-0.14, 0.1) * sx, ac.darkened(0.15 * side), lw * 0.25)

# ---------------------------------------------------------------- weather and foreground

func draw_weather(c: CanvasItem, t: float, dt: float, wind: float, view: Rect2) -> void:
	var kind := str(pal.weather)
	for m in motes:
		match kind:
			"snow":
				m[0] += (m[2] + wind * 6.0) * dt
				m[1] += m[3] * dt
			"leaves":
				m[0] += (m[2] + wind * 8.0 + 10.0) * dt
				m[1] += m[3] * 0.6 * dt
			"fireflies", "pollen", "butterflies":
				m[0] += (sin(t * 0.7 + m[4]) * 8.0 + wind * 2.0) * dt
				m[1] += cos(t * 0.5 + m[4]) * 6.0 * dt
		if m[1] > E.H + 10.0:
			m[1] = -10.0
			m[0] = rng.randf() * E.W
		m[0] = fposmod(m[0] + 20.0, E.W + 40.0) - 20.0
		m[1] = fposmod(m[1] + 20.0, E.H + 40.0) - 20.0
		var p := Vector2(m[0], m[1])
		if not view.grow(20.0).has_point(p):
			continue
		match kind:
			"snow":
				c.draw_circle(p, 0.8 + m[5] * 1.6, Color(1, 1, 1, 0.85))
			"leaves":
				var sp := sin(t * 3.0 + m[4])
				var lc: Color = pal.leaf[int(m[4] * 10.0) % pal.leaf.size()]
				c.draw_colored_polygon(ellipse(p, Vector2(3.5 * m[5], 1.6 * m[5] * absf(sp) + 0.4), 8, t * 2.0 + m[4]), lc)
			"fireflies":
				if m[1] > 480.0:
					var f := 0.5 + 0.5 * sin(t * 2.5 + m[4] * 5.0)
					_glow(c, p, 7.0 * m[5], Color(1.0, 0.95, 0.5, 0.5 * f))
					c.draw_circle(p, 0.9, Color(1, 1, 0.7, f))
			"pollen":
				c.draw_circle(p, 0.7 * m[5] + 0.3, Color(1, 0.96, 0.85, 0.5))
			"butterflies":
				if m[1] > 520.0:
					var fl := absf(sin(t * 14.0 + m[4]))
					var bc := Color("fff36a") if int(m[4] * 3.0) % 2 == 0 else Color("ffffff")
					c.draw_colored_polygon(ellipse(p + Vector2(-2.0 * fl, 0), Vector2(2.4 * fl + 0.3, 1.8), 8), bc)
					c.draw_colored_polygon(ellipse(p + Vector2(2.0 * fl, 0), Vector2(2.4 * fl + 0.3, 1.8), 8), bc)

## Tall grass right in front of the hide, bending in the wind.
func draw_foreground(c: CanvasItem, t: float, wind: float) -> void:
	for b in fg:
		var x: float = b[0]
		var hh: float = b[1]
		var bend: float = b[2] + sin(t * 1.6 + b[3]) * 0.12 + wind * 0.03
		var p0 := Vector2(x, E.H + 4.0)
		var pts := PackedVector2Array([p0])
		for i in 4:
			var f := float(i + 1) / 4.0
			pts.append(p0 + Vector2(sin(bend * f) * hh * f, -cos(bend * f) * hh * f))
		c.draw_polyline(pts, b[4], 2.6)
