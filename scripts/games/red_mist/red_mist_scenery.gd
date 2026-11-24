extends RefCounted

## Red Mist scenery: paints the six places in code (no image files), in world
## units (red_mist_engine.gd explains the perspective). Everything is split into
## layers the game turns into Node2Ds, depth-sorted with z_index so a guard
## walking behind a cabin is hidden by it:
##   sky (animated: gradient, sun / moon, drifting clouds, birds, lightning)
##   far (static: mountain ranges or mesas or islands, mist bands, forest belts)
##   ground (static: valley floor, snow / sand / quay / sea, road, patches)
##   water (animated, harbour: glitter on the sea)
##   one node per structure (static) + its animated bits (smoke, flags, flame,
##   lighthouse beam, torches, blinking lights) + its front rail
##   front (animated: grass / ferns right under the hide, swaying in the wind)
##   lights (not tinted: windows, lamps, headlights at dusk and night)
##   fog banks (weather "fog"), sun rays (clear dawn / dusk)
## Each contract sets the time of day (dawn, day, dusk, night) and the weather
## (clear, fog, snow, rain, dust, storm): palette() mixes the place's daylight
## colours with the hour's sky and returns a "tint" the game puts on every
## lit-by-the-sun layer (night is dark blue), so one painting serves all hours.
## Classic mode uses each place's natural colours; Skull mode (skin "voodoo")
## paints the same shapes near-black with neon edges.

const E = preload("res://scripts/games/red_mist/red_mist_engine.gd")
const X0 := -500.0          # paint this far past the picture's edges (wide screens, sway)
const X1 := E.W + 500.0

## Daylight colours per place ("uni" = uniforms). The sky comes from TOD.
const PAL := {
	"alpine": {"far": Color("9aa0c4"), "mid": Color("6d7299"), "near": Color("434a70"), "snow": Color("f4eef4"), "haze": Color("d9dfee"),
		"forest": Color("23393d"), "ground_far": Color("c7c6da"), "ground_near": Color("eceaf3"), "patch": Color("b9bccf"),
		"road": Color("8d8379"), "wood": Color("5b3b29"), "roof": Color("e8e4ee"), "metal": Color("5e646e"), "canvas": Color("6c7353"),
		"uni": Color("3b4632"), "uni2": Color("2c3326"), "hat": "beanie", "skin_tone": Color("c09070"), "grass": Color("8a8a74")},
	"desert": {"far": Color("d8a98a"), "mid": Color("c47a52"), "near": Color("a65a38"), "snow": Color("e7c29a"), "haze": Color("efd9c2"),
		"forest": Color("5e6b3a"), "ground_far": Color("e4c08a"), "ground_near": Color("d49c5c"), "patch": Color("c98d50"),
		"road": Color("a88a64"), "wood": Color("7a5838"), "roof": Color("bfae8e"), "metal": Color("d6d4cc"), "canvas": Color("b59c6c"),
		"uni": Color("7a6644"), "uni2": Color("5e4e34"), "hat": "scarf", "skin_tone": Color("9a6a4c"), "grass": Color("9a8a4a")},
	"harbour": {"far": Color("6a6278"), "mid": Color("534c62"), "near": Color("3e384c"), "snow": Color("8a8090"), "haze": Color("c4c8d4"),
		"forest": Color("2c2a38"), "ground_far": Color("6d6e76"), "ground_near": Color("84848a"), "patch": Color("76767c"),
		"road": Color("4a4b52"), "wood": Color("4a3a34"), "roof": Color("8a8a90"), "metal": Color("e2a33a"), "canvas": Color("5a5e70"),
		"uni": Color("27324a"), "uni2": Color("1c2436"), "hat": "helmet", "skin_tone": Color("a77a62"), "grass": Color("5a6048"),
		"sea": [Color("8aa6c0"), Color("3c5a78"), Color("20324a")]},
	"canyon": {"far": Color("c98a6a"), "mid": Color("b0603e"), "near": Color("8a4228"), "snow": Color("e0a888"), "haze": Color("e8c8b0"),
		"forest": Color("6a6a3a"), "ground_far": Color("d49a70"), "ground_near": Color("c07a50"), "patch": Color("a8663e"),
		"road": Color("9a7a5c"), "wood": Color("6a4a30"), "roof": Color("8a6a4a"), "metal": Color("6a6a6e"), "canvas": Color("a08a64"),
		"uni": Color("4e5a3a"), "uni2": Color("3a4430"), "hat": "cap", "skin_tone": Color("a8785a"), "grass": Color("9a8a5a")},
	"jungle": {"far": Color("5a7a72"), "mid": Color("3c5e4a"), "near": Color("27462f"), "snow": Color("6a8a80"), "haze": Color("a8c0b6"),
		"forest": Color("1e3a26"), "ground_far": Color("4a6a44"), "ground_near": Color("56763e"), "patch": Color("62844a"),
		"road": Color("6a5a40"), "wood": Color("5a4430"), "roof": Color("7a6a42"), "metal": Color("5a6262"), "canvas": Color("4a5a3a"),
		"uni": Color("33452e"), "uni2": Color("26341f"), "hat": "boonie", "skin_tone": Color("8a6450"), "grass": Color("3a6a34")},
	"city": {"far": Color("6a7080"), "mid": Color("545a6a"), "near": Color("3e4452"), "snow": Color("7a8090"), "haze": Color("b8c0cc"),
		"forest": Color("2a3a2e"), "ground_far": Color("50545c"), "ground_near": Color("5e6168"), "patch": Color("54575e"),
		"road": Color("34363c"), "wood": Color("5a4a40"), "roof": Color("6a6e76"), "metal": Color("8a8e96"), "canvas": Color("4a5060"),
		"uni": Color("23262c"), "uni2": Color("17191d"), "hat": "balaclava", "skin_tone": Color("b08066"), "grass": Color("3a4a3a")},
}

## The sky per time of day: gradient (top..horizon), sun or moon, clouds, haze,
## and the tint for everything the sun lights (dark blue at night).
const TOD := {
	"dawn": {"sky": [Color("1d2a52"), Color("5d5f8f"), Color("d98a7a"), Color("f6c49a")], "sun": Color("ffe2b0"), "sun_pos": Vector2(1700, 330), "sun_r": 34.0,
		"cloud": Color("f3cfc3"), "haze": Color("e9b9a6"), "tint": Color(1.0, 0.9, 0.88), "night": false, "rays": true, "lit": false},
	"day": {"sky": [Color("2f6fc6"), Color("5a95d6"), Color("a9cdea"), Color("e0ecf2")], "sun": Color("fffbe8"), "sun_pos": Vector2(620, 150), "sun_r": 26.0,
		"cloud": Color("ffffff"), "haze": Color("d4e2ec"), "tint": Color(1.0, 1.0, 1.0), "night": false, "rays": false, "lit": false},
	"dusk": {"sky": [Color("231a42"), Color("6a3a5e"), Color("d0604a"), Color("ffb26a")], "sun": Color("ffcf7a"), "sun_pos": Vector2(1950, 452), "sun_r": 46.0,
		"cloud": Color("ffb08a"), "haze": Color("e08a70"), "tint": Color(1.0, 0.8, 0.7), "night": false, "rays": true, "lit": true},
	"night": {"sky": [Color("03050c"), Color("0a1222"), Color("15233a"), Color("1f3248")], "sun": Color("dfe8ff"), "sun_pos": Vector2(700, 190), "sun_r": 22.0,
		"cloud": Color("3a4a5e"), "haze": Color("2a3e4e"), "tint": Color(0.3, 0.36, 0.55), "night": true, "rays": false, "lit": true},
}

## Each place's own hour when no contract says otherwise (the Landing before the first contract).
const HOME_TOD := {"alpine": "dawn", "desert": "day", "harbour": "dusk", "canyon": "day", "jungle": "night", "city": "night"}

const NEON := {"sky": [Color("05030b"), Color("0c0518"), Color("170828"), Color("240a36")], "sun": Color("ff2bd6"), "sun_r": 30.0,
	"far": Color("0d0718"), "mid": Color("0b0614"), "near": Color("090410"), "snow": Color("1a0d2a"), "haze": Color("2a0c3a"),
	"forest": Color("07040c"), "ground_far": Color("0b0614"), "ground_near": Color("100820"), "patch": Color("160a28"),
	"road": Color("1c0f30"), "wood": Color("120a1e"), "roof": Color("1a0e2c"), "metal": Color("1a1030"), "canvas": Color("140c22"),
	"uni": Color("ff2bd6"), "skin_tone": Color("ff8ae8"), "grass": Color("0f2a18"), "cloud": Color("2a0f40"),
	"edge": Color("29e6ff"), "edge2": Color("ff2bd6"), "edge3": Color("7dff3a")}

static func palette(loc: String, skin: String, tod: String = "", wx: String = "clear") -> Dictionary:
	if tod == "":
		tod = HOME_TOD[loc]
	var p: Dictionary = PAL[loc].duplicate()
	var t: Dictionary = TOD[tod]
	for k in t:
		p[k] = t[k]
	p["loc"] = loc
	p["tod"] = tod
	p["wx"] = wx
	p["haze"] = (PAL[loc].haze as Color).lerp(t.haze, 0.25 if tod == "day" else 0.75)
	p["fog"] = 1.0 if wx == "fog" else 0.0
	p["sun_hidden"] = wx in ["fog", "rain", "storm"]
	p["sun_side"] = 1.0 if (t.sun_pos as Vector2).x > E.W * 0.5 else -1.0
	var sky: Array = (t.sky as Array).duplicate()
	var tint: Color = t.tint
	match wx:
		"fog":
			p["haze"] = (p.haze as Color).lerp(Color("c4c8cc") if tod != "night" else Color("1c2228"), 0.65)  # fog is grey, whatever the hour
			for i in sky.size():
				sky[i] = (sky[i] as Color).lerp(p.haze, 0.55)
			p["rays"] = false
		"rain", "storm":
			for i in sky.size():
				sky[i] = (sky[i] as Color).lerp(Color("4a5360") if tod != "night" else Color("0a0e16"), 0.55)
			tint = tint * Color(0.78, 0.8, 0.86)
			p["cloud"] = Color("6a7280") if tod != "night" else Color("1a2230")
			p["rays"] = false
			p["lit"] = true
		"snow":
			for i in sky.size():
				sky[i] = (sky[i] as Color).lerp(Color("aab4c4") if tod != "night" else Color("1a2030"), 0.35)
			p["rays"] = false
		"dust":
			for i in sky.size():
				sky[i] = (sky[i] as Color).lerp(Color("d8b080") if tod != "night" else Color("2a2018"), 0.4)
			p["haze"] = (p.haze as Color).lerp(Color("d8b080"), 0.5)
	p["sky"] = sky
	p["tint"] = tint
	p["neon_on"] = skin == "voodoo"
	if skin == "voodoo":
		for k in NEON:
			p[k] = NEON[k]
		p["tint"] = Color.WHITE
		p["rays"] = false
		if p.has("sea"):
			p["sea"] = [Color("ff2bd6"), Color("2a0a3a"), Color("07040c")]
	elif tod == "dusk" and p.has("sea"):
		p["sea"] = [Color("ffb070"), Color("8a4a5a"), Color("2a2c48")]
	return p

# ---------- helpers ----------

static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

## A mountain line across the picture: midpoint displacement, x from X0 to X1.
static func ridge(seed: int, base: float, amp: float, rough: float = 0.55, n: int = 64) -> PackedVector2Array:
	var r := _rng(seed)
	var ys: Array = []
	ys.resize(n + 1)
	ys[0] = base - r.randf() * amp
	ys[n] = base - r.randf() * amp
	var step := n
	var a := amp
	while step > 1:
		var half := step / 2
		var i := half
		while i < n:
			ys[i] = (float(ys[i - half]) + float(ys[i + half])) * 0.5 + r.randf_range(-a, a)
			i += step
		step = half
		a *= rough
	# One smoothing pass: rounded shoulders instead of a jagged skyline, peaks kept.
	var sm: Array = ys.duplicate()
	for i in range(1, n):
		sm[i] = minf(float(ys[i]), (float(ys[i - 1]) + float(ys[i]) * 2.0 + float(ys[i + 1])) * 0.25)
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(Vector2(lerpf(X0, X1, float(i) / n), minf(float(sm[i]), base + amp * 0.15)))
	return pts

static func _fill_below(ci: CanvasItem, top: PackedVector2Array, bottom_y: float, col: Color, pal: Dictionary, edge: Color = Color(0, 0, 0, 0)) -> void:
	var poly := top.duplicate()
	poly.append(Vector2(X1, bottom_y))
	poly.append(Vector2(X0, bottom_y))
	ci.draw_colored_polygon(poly, col)
	if pal.neon_on and edge.a > 0.0:
		ci.draw_polyline(top, Color(edge, 0.25), 6.0)
		ci.draw_polyline(top, edge, 1.6)

static func _vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, n: int = 14) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)

static func _glow(ci: CanvasItem, c: Vector2, r: float, col: Color, rings: int = 6) -> void:
	for i in rings:
		var k := 1.0 - float(i) / rings
		ci.draw_circle(c, r * (0.4 + k * 1.6), Color(col, col.a * 0.08 * (1.0 - k) + 0.02))
	ci.draw_circle(c, r * 0.4, col)

static func _edge(ci: CanvasItem, pts: PackedVector2Array, pal: Dictionary, key: String = "edge2", w: float = 1.4) -> void:
	if not pal.neon_on:
		return
	var c: Color = pal[key]
	ci.draw_polyline(pts, Color(c, 0.3), w * 3.5)
	ci.draw_polyline(pts, c, w)

static func _box(ci: CanvasItem, r: Rect2, col: Color, pal: Dictionary, key: String = "edge2") -> void:
	ci.draw_rect(r, col)
	if pal.neon_on:
		_edge(ci, PackedVector2Array([r.position + Vector2(0, r.size.y), r.position, Vector2(r.end.x, r.position.y), r.end]), pal, key, maxf(0.8, r.size.x * 0.01))

## Haze: things far away fade toward the sky colour near the horizon.
static func _haze(c: Color, pal: Dictionary, d: float) -> Color:
	var k := clampf((d - 150.0) / 1400.0, 0.0, 0.55)
	if float(pal.get("fog", 0.0)) > 0.0:
		k = clampf((d - 60.0) / 650.0, 0.0, 0.88)  # fog: the far side of the valley fades out
	return c.lerp(pal.haze, k)

static func wind_sign(w: float) -> float:
	return clampf(w / 6.0, -1.0, 1.0)

# ---------- sky (animated) ----------

static func draw_sky(ci: CanvasItem, pal: Dictionary, time: float, wind: float, flash: float) -> void:
	var s: Array = pal.sky
	_vgrad(ci, Rect2(X0, -600, X1 - X0, 760), s[0], s[1])
	_vgrad(ci, Rect2(X0, 160, X1 - X0, 200), s[1], s[2])
	_vgrad(ci, Rect2(X0, 360, X1 - X0, E.HORIZON - 360 + 60), s[2], s[3])
	var loc: String = pal.loc
	var sp: Vector2 = pal.sun_pos
	if pal.night and not pal.neon_on and pal.sun_hidden:
		pass  # overcast night: no stars, no moon
	elif pal.night and not pal.neon_on:
		# Stars, then the moon behind thin cloud.
		var r := _rng(77)
		for i in 220:
			var p := Vector2(r.randf_range(X0, X1), r.randf_range(-500, 420))
			var tw := 0.5 + 0.5 * sin(time * r.randf_range(1.0, 3.0) + i)
			ci.draw_rect(Rect2(p, Vector2(1.6, 1.6)), Color(0.85, 0.9, 1.0, 0.25 + 0.5 * tw * r.randf()))
		_glow(ci, sp, pal.sun_r * 2.2, Color(0.75, 0.82, 1.0, 0.5))
		ci.draw_circle(sp, pal.sun_r, pal.sun)
		ci.draw_circle(sp + Vector2(-6, -4), pal.sun_r * 0.25, Color(0.8, 0.84, 0.92))
		ci.draw_circle(sp + Vector2(7, 6), pal.sun_r * 0.18, Color(0.82, 0.86, 0.94))
	elif pal.neon_on:
		var r := _rng(78)
		for i in 160:
			ci.draw_rect(Rect2(Vector2(r.randf_range(X0, X1), r.randf_range(-500, 440)), Vector2(1.5, 1.5)), Color(pal.edge, 0.2 + 0.4 * r.randf()))
		# A neon sun cut by horizontal bands.
		var c := Vector2(sp.x, 380)
		_glow(ci, c, 70.0, Color(pal.edge2, 0.6))
		for i in 7:
			var y := c.y - 60 + i * 18
			var hw := sqrt(maxf(0.0, 70.0 * 70.0 - pow(y - c.y, 2)))
			ci.draw_rect(Rect2(c.x - hw, y, hw * 2, 11.0 - i * 0.6), Color(pal.edge2, 0.9).lerp(Color("ffae2b"), float(i) / 7.0))
	elif pal.sun_hidden:
		_glow(ci, sp, pal.sun_r * 4.0, Color(pal.sun, 0.18), 6)  # a pale smear behind the cloud
	else:
		_glow(ci, sp, pal.sun_r * 3.0, Color(pal.sun, 0.55), 8)
		ci.draw_circle(sp, pal.sun_r, pal.sun)
		if loc == "harbour":  # the setting sun squashed on the sea line
			ci.draw_rect(Rect2(sp.x - 90, E.HORIZON - 4, 180, 4), Color(pal.sun, 0.5))
	# Clouds drift with the wind.
	var cr := _rng(5 + loc.length())
	var heavy: bool = pal.wx in ["rain", "storm", "snow"]
	var n := 9 if loc != "desert" else 4
	if heavy:
		n = 22
	for i in n:
		var base := cr.randf_range(0.0, X1 - X0)
		var y := cr.randf_range(60.0, 330.0) if not heavy else cr.randf_range(-40.0, 380.0)
		var sc := cr.randf_range(0.6, 1.4) * (1.0 - y / 700.0 + 0.5)
		var x := X0 + fposmod(base + time * (4.0 + wind * 3.0) * sc, X1 - X0)
		var col: Color = pal.cloud
		col.a = (0.32 if not pal.night else 0.55) if not heavy else 0.75
		_cloud(ci, Vector2(x, y), sc * 90.0, col, cr.randi())
	if flash > 0.0:
		ci.draw_rect(Rect2(X0, -600, X1 - X0, E.HORIZON + 600), Color(0.75, 0.82, 1.0, flash * 0.55))

static func _cloud(ci: CanvasItem, c: Vector2, size: float, col: Color, seed: int) -> void:
	var r := _rng(seed)
	for i in 7:
		var o := Vector2(r.randf_range(-1.3, 1.3) * size, r.randf_range(-0.25, 0.15) * size)
		_ellipse(ci, c + o, size * r.randf_range(0.45, 0.8), size * r.randf_range(0.16, 0.28), col, 12)

## Birds wheel over the valley; `scatter` (0..1) after a shot sends them off.
static func draw_birds(ci: CanvasItem, pal: Dictionary, time: float, scatter: float) -> void:
	var col: Color = Color(0.08, 0.08, 0.1, 0.85) if not pal.neon_on else pal.edge3
	if pal.loc == "harbour" and not pal.neon_on:
		col = Color(0.95, 0.9, 0.88, 0.9)
	if pal.night and not pal.neon_on:
		return  # no birds wheeling in the dark
	var center := Vector2(1100, 300)
	for i in 9:
		var a := time * 0.35 + i * 0.7
		var p := center + Vector2(cos(a) * (260 + i * 14), sin(a * 1.3) * 40 - i * 4)
		if scatter > 0.0:
			p += Vector2(cos(i * 2.1), -0.6 - absf(sin(i * 1.7))) * scatter * 900.0
		var flap := sin(time * 9.0 + i) * 4.0
		var w := 9.0
		ci.draw_polyline(PackedVector2Array([p + Vector2(-w, -flap), p, p + Vector2(w, -flap)]), col, 2.0)

# ---------- far scenery (static) ----------

static func draw_far(ci: CanvasItem, pal: Dictionary) -> void:
	match str(pal.loc):
		"alpine":
			var l1 := ridge(11, 340.0, 150.0, 0.55)
			_fill_below(ci, l1, E.HORIZON + 5, pal.far, pal, pal.get("edge", Color()))
			_snow(ci, l1, 255.0, Color(pal.snow, 0.9).lerp(pal.haze, 0.2), pal)
			_mist(ci, 360.0, 90.0, Color(pal.haze, 0.45))
			var l2 := ridge(12, 385.0, 120.0, 0.55)
			_fill_below(ci, l2, E.HORIZON + 5, pal.mid, pal, pal.get("edge2", Color()))
			_snow(ci, l2, 330.0, Color(pal.snow, 0.8).lerp(pal.haze, 0.2), pal)
			_mist(ci, 420.0, 60.0, Color(pal.haze, 0.35))
			var l3 := ridge(13, 455.0, 45.0, 0.5)
			_fill_below(ci, l3, E.HORIZON + 5, pal.near, pal, pal.get("edge", Color()))
			_forest(ci, pal, 21, 1250.0, 2400.0, 520, 16.0, pal.forest.lerp(pal.haze, 0.25))
		"desert":
			var l1 := ridge(31, 400.0, 50.0, 0.45)
			_fill_below(ci, l1, E.HORIZON + 5, pal.far, pal, pal.get("edge", Color()))
			_mesas(ci, pal)
			_mist(ci, 440.0, 40.0, Color(pal.haze, 0.5))
		"harbour":
			_islands(ci, pal)
			var head := PackedVector2Array([Vector2(X0, 360), Vector2(200, 372), Vector2(380, 396), Vector2(520, 430), Vector2(700, 460), Vector2(760, E.HORIZON + 2), Vector2(X0, E.HORIZON + 2)])
			ci.draw_colored_polygon(head, pal.mid)
			_edge(ci, head.slice(0, 6), pal, "edge")
		"jungle":
			var l1 := ridge(51, 330.0, 150.0, 0.6)
			_fill_below(ci, l1, E.HORIZON + 5, pal.far, pal, pal.get("edge", Color()))
			_mist(ci, 380.0, 80.0, Color(pal.haze, 0.5))
			var l2 := ridge(52, 420.0, 70.0, 0.55)
			_fill_below(ci, l2, E.HORIZON + 5, pal.mid, pal, pal.get("edge3", Color()))
			_canopy(ci, pal, 53, 1100.0, 2600.0, 220, pal.near)
			_mist(ci, 455.0, 30.0, Color(pal.haze, 0.4))
		"canyon":
			var l1 := ridge(61, 420.0, 70.0, 0.5)
			_fill_below(ci, l1, E.HORIZON + 5, pal.far, pal, pal.get("edge", Color()))
			_mesas(ci, pal)
			_mist(ci, 450.0, 40.0, Color(pal.haze, 0.45))
			_cliff(ci, pal, true)
			_cliff(ci, pal, false)
		"city":
			_skyline(ci, pal, 71, 330.0, pal.far, 4.0)
			_mist(ci, 420.0, 60.0, Color(pal.haze, 0.35))
			_skyline(ci, pal, 72, 400.0, pal.mid, 7.0)
			_mist(ci, 460.0, 30.0, Color(pal.haze, 0.3))

## A canyon wall up one side of the picture: banded red rock, lit edge, cracks.
static func _cliff(ci: CanvasItem, pal: Dictionary, left: bool) -> void:
	var r := _rng(63 if left else 64)
	var edge := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var f := float(i) / n
		var y := lerpf(-260.0, E.HORIZON + 4.0, f)
		var x := lerpf(300.0, 560.0, pow(f, 1.8)) + r.randf_range(-22.0, 22.0)
		edge.append(Vector2(x if left else E.W - x, y))
	var poly := edge.duplicate()
	poly.append(Vector2(X0 if left else X1, E.HORIZON + 4.0))
	poly.append(Vector2(X0 if left else X1, -260.0))
	var rock: Color = pal.mid
	ci.draw_colored_polygon(poly, rock)
	# Strata: bands across the wall, each a slightly different red.
	for k in 14:
		var y := -240.0 + k * 52.0
		if y > E.HORIZON:
			break
		var x_in := _edge_x(edge, y)
		var c := rock.darkened(0.08 + 0.1 * (k % 3)) if k % 2 == 0 else rock.lightened(0.05)
		var x_out := X0 if left else X1
		ci.draw_rect(Rect2(minf(x_out, x_in), y, absf(x_in - x_out), 20.0 + (k % 4) * 6.0), Color(c, 0.6))
	# The sunlit rim along the opening, and a few vertical cracks.
	var lit: Color = Color(pal.snow, 0.5) if not pal.neon_on else pal.edge2
	ci.draw_polyline(edge, lit, 5.0)
	for k in 7:
		var y0 := r.randf_range(-200.0, 300.0)
		var x := _edge_x(edge, y0) + (-1.0 if left else 1.0) * r.randf_range(30.0, 260.0)
		ci.draw_line(Vector2(x, y0), Vector2(x + r.randf_range(-10.0, 10.0), y0 + r.randf_range(60.0, 160.0)), Color(0, 0, 0, 0.25), 2.0)
	_edge(ci, edge, pal, "edge2")

static func _edge_x(edge: PackedVector2Array, y: float) -> float:
	for i in range(1, edge.size()):
		if edge[i].y >= y:
			var a := edge[i - 1]
			var b := edge[i]
			return lerpf(a.x, b.x, clampf((y - a.y) / maxf(0.001, b.y - a.y), 0.0, 1.0))
	return edge[edge.size() - 1].x

## A city skyline on the horizon: towers with flat or stepped tops and antennas.
static func _skyline(ci: CanvasItem, pal: Dictionary, seed: int, top: float, col: Color, step: float) -> void:
	var r := _rng(seed)
	var x := X0
	while x < X1:
		var w := r.randf_range(30.0, 90.0) * step / 5.0
		var hgt := r.randf_range(0.3, 1.0) * (E.HORIZON - top)
		var y := E.HORIZON + 2.0 - hgt
		var c := col.lerp(pal.haze, r.randf() * 0.15)
		ci.draw_rect(Rect2(x, y, w, hgt), c)
		if r.randf() < 0.3:
			ci.draw_rect(Rect2(x + w * 0.2, y - hgt * 0.12, w * 0.6, hgt * 0.12), c)
		if r.randf() < 0.25:
			ci.draw_line(Vector2(x + w * 0.5, y), Vector2(x + w * 0.5, y - r.randf_range(14.0, 40.0)), c, 1.5)
		if pal.neon_on:
			_edge(ci, PackedVector2Array([Vector2(x, E.HORIZON), Vector2(x, y), Vector2(x + w, y), Vector2(x + w, E.HORIZON)]), pal, "edge" if r.randf() < 0.5 else "edge2", 0.8)
		x += w + r.randf_range(0.0, 8.0)

## Lit windows of the far skyline and the far towns (only after dark; not tinted).
static func draw_far_lights(ci: CanvasItem, pal: Dictionary) -> void:
	if not pal.lit or pal.neon_on:
		return
	var k := 1.0 if pal.night else 0.55
	match str(pal.loc):
		"city":
			for seed in [71, 72]:
				var r := _rng(seed + 100)
				for i in (700 if seed == 72 else 900):
					var p := Vector2(r.randf_range(X0, X1), r.randf_range(E.HORIZON - (60.0 if seed == 71 else 40.0) * r.randf() * 3.0, E.HORIZON - 2.0))
					var c := Color(1.0, 0.85, 0.55) if r.randf() < 0.7 else Color(0.7, 0.85, 1.0)
					ci.draw_rect(Rect2(p, Vector2(2.0, 1.6)), Color(c, (0.35 + 0.5 * r.randf()) * k))
		"harbour", "alpine", "canyon", "desert":
			var r := _rng(81)
			for i in 40:
				var p := Vector2(r.randf_range(X0, X1), E.HORIZON - r.randf_range(0.0, 6.0))
				ci.draw_rect(Rect2(p, Vector2(1.6, 1.4)), Color(1.0, 0.85, 0.55, 0.6 * k))

## Far islands on the sea line: rounded humps with a rough top.
static func _islands(ci: CanvasItem, pal: Dictionary) -> void:
	var r := _rng(41)
	for k in 5:
		var cx := r.randf_range(300.0, E.W + 300.0)
		var w := r.randf_range(220.0, 520.0)
		var hgt := r.randf_range(25.0, 80.0)
		var pts := PackedVector2Array()
		for i in 25:
			var f := float(i) / 24.0
			var y := E.HORIZON + 1.0 - hgt * pow(sin(f * PI), 0.7) * (1.0 + r.randf_range(-0.08, 0.08))
			pts.append(Vector2(cx - w * 0.5 + f * w, y))
		var col: Color = pal.far.lerp(pal.haze, 0.15 * (k % 3))
		ci.draw_colored_polygon(pts, col)
		_edge(ci, pts, pal, "edge")

static func _snow(ci: CanvasItem, line: PackedVector2Array, snow_y: float, col: Color, pal: Dictionary) -> void:
	if pal.neon_on:
		return
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		if a.y >= snow_y and b.y >= snow_y:
			continue
		# The snow line wanders smoothly (same function at both ends of each piece, so no steps).
		var la := snow_y + 14.0 * sin(a.x * 0.011) + 6.0 * sin(a.x * 0.037)
		var lb := snow_y + 14.0 * sin(b.x * 0.011) + 6.0 * sin(b.x * 0.037)
		var poly := PackedVector2Array([a, b, Vector2(b.x, maxf(b.y, lb)), Vector2(a.x, maxf(a.y, la))])
		ci.draw_colored_polygon(poly, col)

static func _mist(ci: CanvasItem, y: float, h: float, col: Color) -> void:
	var clear := Color(col, 0.0)
	_vgrad(ci, Rect2(X0, y - h, X1 - X0, h), clear, col)
	_vgrad(ci, Rect2(X0, y, X1 - X0, h * 0.6), col, clear)

static func _mesas(ci: CanvasItem, pal: Dictionary) -> void:
	var r := _rng(32)
	for i in 6:
		var cx := r.randf_range(-200, E.W + 200)
		var w := r.randf_range(160, 420)
		var top := r.randf_range(330, 410)
		var base := E.HORIZON + 3.0
		var col: Color = pal.mid.lerp(pal.haze, 0.25 + 0.1 * (i % 2))
		var poly := PackedVector2Array([Vector2(cx - w * 0.5 - 40, base), Vector2(cx - w * 0.5, top + 14), Vector2(cx - w * 0.42, top),
			Vector2(cx + w * 0.4, top), Vector2(cx + w * 0.5, top + 18), Vector2(cx + w * 0.5 + 50, base)])
		ci.draw_colored_polygon(poly, col)
		if not pal.neon_on:
			for k in 3:  # rock strata
				var y := top + 12.0 + k * (base - top) / 4.0
				ci.draw_line(Vector2(cx - w * 0.5 + k * 6, y), Vector2(cx + w * 0.5 + k * 9, y), Color(pal.near, 0.35), 3.0)
		_edge(ci, poly, pal, "edge2")

static func _forest(ci: CanvasItem, pal: Dictionary, seed: int, d0: float, d1: float, n: int, tree_m: float, col: Color, sides: bool = false) -> void:
	var r := _rng(seed)
	var trees: Array = []
	for i in n:
		trees.append(Vector2(_side_x(r) if sides else r.randf_range(X0, X1), r.randf_range(d0, d1)))
	trees.sort_custom(func(a, b): return a.y > b.y)
	for tr in trees:
		var d: float = tr.y
		_pine(ci, Vector2(tr.x, E.ground_y(d)), tree_m * r.randf_range(0.7, 1.2) * E.upm(d), _haze(col, pal, d), pal)

static func _pine(ci: CanvasItem, foot: Vector2, h: float, col: Color, pal: Dictionary) -> void:
	var w := h * 0.32
	for k in 3:
		var y0 := foot.y - h * (0.15 + k * 0.27)
		var tri := PackedVector2Array([Vector2(foot.x - w * (1.0 - k * 0.22), y0), Vector2(foot.x + w * (1.0 - k * 0.22), y0), Vector2(foot.x, y0 - h * 0.45)])
		ci.draw_colored_polygon(tri, col.darkened(0.06 * k))
	if pal.neon_on and h > 6.0:
		_edge(ci, PackedVector2Array([Vector2(foot.x - w, foot.y - h * 0.15), Vector2(foot.x, foot.y - h * 1.0), Vector2(foot.x + w, foot.y - h * 0.15)]), pal, "edge3", 0.8)
	ci.draw_rect(Rect2(foot.x - h * 0.03, foot.y - h * 0.16, h * 0.06, h * 0.16), col.darkened(0.4))

static func _canopy(ci: CanvasItem, pal: Dictionary, seed: int, d0: float, d1: float, n: int, col: Color) -> void:
	var r := _rng(seed)
	var blobs: Array = []
	for i in n:
		blobs.append(Vector2(r.randf_range(X0, X1), r.randf_range(d0, d1)))
	blobs.sort_custom(func(a, b): return a.y > b.y)
	for b in blobs:
		var d: float = b.y
		var u := E.upm(d)
		var foot := Vector2(b.x, E.ground_y(d))
		var hh := r.randf_range(14.0, 30.0) * u
		var c := _haze(col, pal, d).lightened(r.randf_range(-0.05, 0.08))
		ci.draw_rect(Rect2(foot.x - 0.4 * u, foot.y - hh, 0.8 * u, hh), c.darkened(0.3))
		for k in 4:
			_ellipse(ci, foot + Vector2(r.randf_range(-5, 5) * u, -hh - r.randf_range(-2, 3) * u), r.randf_range(4, 8) * u, r.randf_range(2.5, 4.5) * u, c, 10)

# ---------- ground (static) ----------

static func draw_ground(ci: CanvasItem, pal: Dictionary, lay: Dictionary) -> void:
	var gtop := E.HORIZON
	_vgrad(ci, Rect2(X0, gtop, X1 - X0, E.H + 300 - gtop), pal.ground_far, pal.ground_near)
	var loc: String = pal.loc
	if lay.has("sea"):
		var sea_y := E.ground_y(float(lay.sea))
		var sc: Array = pal.sea
		_vgrad(ci, Rect2(X0, gtop, X1 - X0, sea_y - gtop), sc[0], sc[1])
		_vgrad(ci, Rect2(X0, sea_y - 10, X1 - X0, 10), sc[1], sc[2])
		# The quay edge.
		ci.draw_rect(Rect2(X0, sea_y, X1 - X0, 6), pal.road.darkened(0.3))
		_edge(ci, PackedVector2Array([Vector2(X0, sea_y), Vector2(X1, sea_y)]), pal, "edge")
	# Patches give the floor texture and show the perspective.
	var r := _rng(61 + loc.length())
	var start_d := float(lay.get("sea", 2500.0))
	for i in 300:
		var d := r.randf_range(140.0, minf(start_d - 10.0, 2200.0))
		var u := E.upm(d)
		var c := _haze(pal.patch, pal, d)
		c.a = 0.28
		# Flattened like the ground they lie on: depth shrinks them far more than width.
		var rx := r.randf_range(2.0, 7.0) * u
		_ellipse(ci, Vector2(r.randf_range(X0, X1), E.ground_y(d)), rx, rx * E.CAM_H / d * 1.5, c, 12)
	_road(ci, pal, lay.road)
	match loc:
		"alpine":
			_lake(ci, pal)
			_forest(ci, pal, 22, 160.0, 900.0, 70, 14.0, pal.forest, true)  # at the sides, never in front of a post
		"desert":
			_dunes(ci, pal)
			_scrub(ci, pal, 34)
		"jungle":
			_canopy(ci, pal, 54, 900.0, 1100.0, 60, pal.near.lightened(0.04))
		"canyon":
			# A dry gulch under the trestle, boulders, sagebrush.
			var y0 := E.ground_y(690.0)
			var y1 := E.ground_y(620.0)
			var gulch := PackedVector2Array([Vector2(700, y0), Vector2(1700, y0 - 1), Vector2(1760, (y0 + y1) / 2), Vector2(1650, y1), Vector2(760, y1), Vector2(640, (y0 + y1) / 2)])
			ci.draw_colored_polygon(gulch, _haze(pal.near, pal, 650.0))
			ci.draw_polyline(gulch, Color(0, 0, 0, 0.2), 1.0, true)
			_boulders(ci, pal, 65)
			_scrub(ci, pal, 66, false)
		"city":
			_street(ci, pal, lay)

static func _boulders(ci: CanvasItem, pal: Dictionary, seed: int) -> void:
	var r := _rng(seed)
	for i in 40:
		var d := r.randf_range(120.0, 1000.0)
		var u := E.upm(d)
		var x := r.randf_range(X0, X1)
		if x > 500 and x < 1900 and d < 700.0 and r.randf() < 0.7:
			continue
		var sz := r.randf_range(0.8, 3.0) * u
		var c := _haze(pal.near.lightened(0.1), pal, d)
		var foot := Vector2(x, E.ground_y(d))
		_ellipse(ci, foot + Vector2(-float(pal.sun_side) * sz * 0.4, 0), sz * 1.1, sz * 0.18, Color(0, 0, 0, 0.18), 10)
		_ellipse(ci, foot + Vector2(0, -sz * 0.45), sz, sz * 0.55, c, 12)
		_ellipse(ci, foot + Vector2(float(pal.sun_side) * sz * 0.3, -sz * 0.6), sz * 0.55, sz * 0.3, c.lightened(0.12), 10)

## City streets: kerbs, lane marks, a crossing, parked cars and street lamps.
static func _street(ci: CanvasItem, pal: Dictionary, lay: Dictionary) -> void:
	var d := float(lay.road[0][1])
	var u := E.upm(d)
	var y := E.ground_y(d)
	ci.draw_rect(Rect2(X0, y - 9.0 * u * E.CAM_H / d, X1 - X0, 2.0), pal.road.lightened(0.25))
	var x := X0
	while x < X1:
		ci.draw_rect(Rect2(x, y - 0.5, 3.0 * u, 1.5), Color(0.9, 0.9, 0.85, 0.5))
		x += 7.0 * u
	for k in 6:
		ci.draw_rect(Rect2(1180 + k * 1.0 * u, y - 3.0, 0.5 * u, 6.0), Color(0.95, 0.95, 0.9, 0.5))
	var r := _rng(91)
	var cols := [Color("8a2a2a"), Color("2a4a7a"), Color("c8c8c0"), Color("2a2a2a"), Color("6a7a3a")]
	for i in 12:
		var cx := r.randf_range(X0, X1)
		var cd := d + 6.0
		var cu := E.upm(cd)
		var cf := Vector2(cx, E.ground_y(cd))
		var c: Color = cols[r.randi() % cols.size()] if not pal.neon_on else pal.wood
		ci.draw_rect(Rect2(cf.x - 2.1 * cu, cf.y - 0.9 * cu, 4.2 * cu, 0.55 * cu), c)
		ci.draw_rect(Rect2(cf.x - 1.2 * cu, cf.y - 1.35 * cu, 2.3 * cu, 0.5 * cu), c.darkened(0.15))
		ci.draw_rect(Rect2(cf.x - 1.05 * cu, cf.y - 1.28 * cu, 2.0 * cu, 0.36 * cu), Color(0.15, 0.2, 0.25))
		for wx in [-1.3, 1.3]:
			ci.draw_circle(Vector2(cf.x + wx * cu, cf.y - 0.32 * cu), 0.32 * cu, Color(0.06, 0.06, 0.06))
	for x2 in [150.0, 650.0, 1150.0, 1650.0, 2150.0]:
		var lf := Vector2(x2, E.ground_y(d + 8.0))
		var lu := E.upm(d + 8.0)
		ci.draw_line(lf, lf + Vector2(0, -7.0 * lu), Color(0.2, 0.22, 0.25), maxf(1.0, 0.18 * lu))
		ci.draw_line(lf + Vector2(0, -7.0 * lu), lf + Vector2(1.2 * lu, -7.2 * lu), Color(0.2, 0.22, 0.25), maxf(1.0, 0.14 * lu))

## Trees at the sides only, so they never stand in front of a post.
static func _side_x(r: RandomNumberGenerator) -> float:
	return r.randf_range(X0, 260.0) if r.randf() < 0.5 else r.randf_range(2150.0, X1)

static func _road(ci: CanvasItem, pal: Dictionary, pts: Array) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for p in pts:
		var d := float(p[1])
		var u := E.upm(d)
		var y := E.ground_y(d)
		left.append(Vector2(float(p[0]) - 3.5 * u, y))
		right.append(Vector2(float(p[0]) + 3.5 * u, y))
	for i in left.size() - 1:
		var quad := PackedVector2Array([left[i], right[i], right[i + 1], left[i + 1]])
		var d := float(pts[i][1])
		ci.draw_colored_polygon(quad, _haze(pal.road, pal, d))
	if pal.neon_on:
		_edge(ci, left, pal, "edge", 1.0)
		_edge(ci, right, pal, "edge", 1.0)

static func _lake(ci: CanvasItem, pal: Dictionary) -> void:
	var y0 := E.ground_y(1500.0)
	var y1 := E.ground_y(1100.0)
	var poly := PackedVector2Array([Vector2(300, y0), Vector2(1100, y0 - 1), Vector2(1350, (y0 + y1) / 2), Vector2(1000, y1), Vector2(420, y1 - 1), Vector2(200, (y0 + y1) / 2)])
	ci.draw_colored_polygon(poly, Color("aebbd6") if not pal.neon_on else Color("12082a"))
	ci.draw_polyline(poly, Color(1, 1, 1, 0.35) if not pal.neon_on else pal.edge, 1.0, true)

static func _dunes(ci: CanvasItem, pal: Dictionary) -> void:
	var r := _rng(33)
	for i in 5:
		var d := r.randf_range(150.0, 1100.0)
		var y := E.ground_y(d)
		var u := E.upm(d)
		var cx := r.randf_range(0, E.W)
		var w := r.randf_range(60, 140) * u
		var hgt := r.randf_range(3.0, 6.0) * u
		var pts := PackedVector2Array()
		for k in 17:
			var f := float(k) / 16.0
			pts.append(Vector2(cx - w + f * w * 2.0, y - sin(f * PI) * hgt * (1.0 - 0.3 * f)))
		var poly := pts.duplicate()
		poly.append(Vector2(cx + w, y + 1))
		poly.append(Vector2(cx - w, y + 1))
		ci.draw_colored_polygon(poly, _haze(pal.ground_near.lerp(pal.ground_far, 0.4), pal, d))
		var shade := pts.slice(8)
		shade.append(Vector2(cx + w, y + 1))
		ci.draw_colored_polygon(shade, Color(pal.near, 0.12))

static func _scrub(ci: CanvasItem, pal: Dictionary, seed: int, palms: bool = true) -> void:
	var r := _rng(seed)
	for i in 90:
		var d := r.randf_range(100.0, 900.0)
		var u := E.upm(d)
		var p := Vector2(r.randf_range(X0, X1), E.ground_y(d))
		_ellipse(ci, p + Vector2(0, -0.3 * u), r.randf_range(0.6, 1.4) * u, 0.45 * u, _haze(pal.forest, pal, d), 8)
	# A few palms at the sides.
	for i in (8 if palms else 0):
		var d := r.randf_range(160.0, 700.0)
		_palm(ci, Vector2(_side_x(r), E.ground_y(d)), E.upm(d), pal, r.randf_range(-0.2, 0.2))

static func _palm(ci: CanvasItem, foot: Vector2, u: float, pal: Dictionary, lean: float) -> void:
	var top := foot + Vector2(lean * 8.0 * u, -9.0 * u)
	ci.draw_line(foot, top, pal.wood, 0.45 * u)
	for k in 7:
		var a := -PI * 0.5 + (k - 3) * 0.45
		var tip := top + Vector2(cos(a), sin(a) + 0.9) * 3.8 * u
		ci.draw_polyline(PackedVector2Array([top, top.lerp(tip, 0.5) + Vector2(0, -0.6 * u), tip]), pal.forest, 0.5 * u)

# ---------- structures ----------

## z_index for a thing d metres away: nearer is drawn later.
static func z_for(d: float) -> int:
	return clampi(2000 - int(d), -3000, 3000)

static func draw_structure(ci: CanvasItem, s: Dictionary, pal: Dictionary) -> void:
	var d := float(s.d)
	var u := E.upm(d)
	var foot := Vector2(float(s.x), E.ground_y(d) - float(s.get("base", 0.0)) * u)
	var w := float(s.get("w", 4.0)) * u
	var h := float(s.get("h", 4.0)) * u
	var dark := func(c: Color) -> Color: return _haze(c, pal, d)
	# A soft contact shadow, thrown away from the sun.
	if not str(s.t) in ["pipes", "trestle", "flare", "mast", "crane", "lighthouse"] and float(s.get("base", 0.0)) <= 0.0:
		_ellipse(ci, foot + Vector2(-float(pal.sun_side) * w * 0.12, 0.0), w * 0.56, maxf(1.0, minf(w * 0.035, 0.6 * u)), Color(0, 0, 0, 0.2 if not pal.night else 0.1), 16)
	if _draw_more(ci, s, pal, foot, u, w, h, d):
		return
	match str(s.t):
		"cabin":
			var body := Rect2(foot.x - w * 0.5, foot.y - h * 0.62, w, h * 0.62)
			_box(ci, body, dark.call(pal.wood), pal)
			if not pal.neon_on:
				for k in 6:  # logs
					var y := body.position.y + body.size.y * (k + 0.5) / 6.0
					ci.draw_line(Vector2(body.position.x, y), Vector2(body.end.x, y), dark.call(pal.wood.darkened(0.25)), maxf(0.6, u * 0.08))
			var roof := PackedVector2Array([Vector2(foot.x - w * 0.6, body.position.y), Vector2(foot.x, foot.y - h), Vector2(foot.x + w * 0.6, body.position.y)])
			ci.draw_colored_polygon(roof, dark.call(pal.roof))
			_edge(ci, roof, pal, "edge")
			# Door and a warm window.
			ci.draw_rect(Rect2(foot.x + w * 0.18, foot.y - h * 0.42, w * 0.14, h * 0.42), dark.call(pal.wood.darkened(0.45)))
			ci.draw_rect(Rect2(foot.x - w * 0.3, foot.y - h * 0.45, w * 0.16, h * 0.16), dark.call(Color("2a3038")) if not pal.neon_on else pal.edge3)
			_shade_side(ci, body, pal)
			ci.draw_rect(Rect2(foot.x - w * 0.34, foot.y - h * 0.86, w * 0.08, h * 0.3), dark.call(pal.metal))  # chimney
		"tower":
			var top := foot.y - h
			var legs := [[-0.5, -0.32], [0.5, 0.32]]
			for l in legs:
				ci.draw_line(Vector2(foot.x + float(l[0]) * w, foot.y), Vector2(foot.x + float(l[1]) * w, top), dark.call(pal.wood), maxf(1.0, 0.25 * u))
			for k in 3:  # cross braces
				var y0 := lerpf(foot.y, top, k / 3.0)
				var y1 := lerpf(foot.y, top, (k + 1) / 3.0)
				var xa := lerpf(0.5, 0.32, k / 3.0) * w
				var xb := lerpf(0.5, 0.32, (k + 1) / 3.0) * w
				ci.draw_line(Vector2(foot.x - xa, y0), Vector2(foot.x + xb, y1), dark.call(pal.wood.darkened(0.2)), maxf(0.8, 0.12 * u))
				ci.draw_line(Vector2(foot.x + xa, y0), Vector2(foot.x - xb, y1), dark.call(pal.wood.darkened(0.2)), maxf(0.8, 0.12 * u))
			ci.draw_rect(Rect2(foot.x - w * 0.42, top - 0.25 * u, w * 0.84, 0.3 * u), dark.call(pal.wood))  # platform
			var roof := PackedVector2Array([Vector2(foot.x - w * 0.55, top - 2.4 * u), Vector2(foot.x, top - 3.4 * u), Vector2(foot.x + w * 0.55, top - 2.4 * u)])
			ci.draw_colored_polygon(roof, dark.call(pal.roof))
			for sx in [-0.4, 0.4]:
				ci.draw_line(Vector2(foot.x + sx * w, top), Vector2(foot.x + sx * w, top - 2.4 * u), dark.call(pal.wood), maxf(0.8, 0.12 * u))
			_edge(ci, roof, pal, "edge")
		"truck", "jeep":
			var body_h := h * (0.55 if s.t == "truck" else 0.6)
			_box(ci, Rect2(foot.x - w * 0.5, foot.y - body_h - 0.45 * u, w * 0.62, body_h), dark.call(pal.canvas), pal)
			_box(ci, Rect2(foot.x + w * 0.12, foot.y - body_h * 0.85 - 0.45 * u, w * 0.38, body_h * 0.85), dark.call(pal.canvas.darkened(0.15)), pal)
			ci.draw_rect(Rect2(foot.x + w * 0.3, foot.y - body_h * 0.8 - 0.4 * u, w * 0.16, body_h * 0.35), Color(0.6, 0.75, 0.85, 0.8) if not pal.neon_on else Color(pal.edge, 0.6))
			if s.t == "truck":  # canvas cover hoops
				var cov := PackedVector2Array([Vector2(foot.x - w * 0.5, foot.y - body_h - 0.45 * u), Vector2(foot.x - w * 0.46, foot.y - h), Vector2(foot.x + w * 0.1, foot.y - h), Vector2(foot.x + w * 0.12, foot.y - body_h - 0.45 * u)])
				ci.draw_colored_polygon(cov, dark.call(pal.canvas.lightened(0.1)))
			for wx in [-0.32, 0.3]:
				ci.draw_circle(Vector2(foot.x + wx * w, foot.y - 0.45 * u), 0.45 * u, Color(0.08, 0.08, 0.08))
		"sandbags":
			for row in 3:
				var n := int(w / (0.7 * u)) - row
				var y := foot.y - (row + 1) * 0.36 * u
				for k in maxi(n, 1):
					var x := foot.x - w * 0.5 + (k + row * 0.5) * 0.7 * u
					_ellipse(ci, Vector2(x + 0.35 * u, y + 0.18 * u), 0.38 * u, 0.2 * u, dark.call(pal.canvas.lerp(Color("8a7a5a"), 0.5)).darkened(0.05 * ((k + row) % 3)), 10)
			_edge(ci, PackedVector2Array([Vector2(foot.x - w * 0.5, foot.y - 1.05 * u), Vector2(foot.x + w * 0.5, foot.y - 1.05 * u)]), pal, "edge3")
		"tent":
			var tent := PackedVector2Array([Vector2(foot.x - w * 0.5, foot.y), Vector2(foot.x - w * 0.12, foot.y - h), Vector2(foot.x + w * 0.38, foot.y - h * 0.95), Vector2(foot.x + w * 0.5, foot.y)])
			ci.draw_colored_polygon(tent, dark.call(pal.canvas))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(foot.x - w * 0.12, foot.y - h), Vector2(foot.x - w * 0.22, foot.y), Vector2(foot.x, foot.y)]), dark.call(pal.canvas.darkened(0.4)))
			_edge(ci, tent, pal, "edge3")
		"mast":
			var top := foot.y - h
			ci.draw_line(foot, Vector2(foot.x, top), dark.call(pal.metal), maxf(1.0, 0.25 * u))
			for k in 8:
				var y := lerpf(foot.y, top, k / 8.0)
				ci.draw_line(Vector2(foot.x - 0.5 * u * (1.0 - k / 9.0), y), Vector2(foot.x + 0.5 * u * (1.0 - k / 9.0), y - h / 8.0), dark.call(pal.metal), maxf(0.5, 0.06 * u))
			for sx in [-1.0, 1.0]:  # guy wires
				ci.draw_line(Vector2(foot.x, top + h * 0.2), Vector2(foot.x + sx * h * 0.45, foot.y), Color(dark.call(pal.metal), 0.4), 0.6)
		"hut":
			_box(ci, Rect2(foot.x - w * 0.5, foot.y - h * 0.8, w, h * 0.8), dark.call(pal.roof.darkened(0.25)), pal)
			_shade_side(ci, Rect2(foot.x - w * 0.5, foot.y - h * 0.8, w, h * 0.8), pal)
			ci.draw_rect(Rect2(foot.x + w * 0.2, foot.y - h * 0.6, w * 0.16, h * 0.18), dark.call(Color("2a3038")))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(foot.x - w * 0.56, foot.y - h * 0.8), Vector2(foot.x + w * 0.56, foot.y - h * 0.8), Vector2(foot.x + w * 0.5, foot.y - h), Vector2(foot.x - w * 0.5, foot.y - h)]), dark.call(pal.metal.darkened(0.3)))
			ci.draw_rect(Rect2(foot.x - w * 0.1, foot.y - h * 0.55, w * 0.2, h * 0.55), dark.call(pal.wood.darkened(0.4)))
		"tank":
			var body := Rect2(foot.x - w * 0.5, foot.y - h, w, h)
			ci.draw_polygon(PackedVector2Array([body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]),
				PackedColorArray([dark.call(pal.metal.lightened(0.1)), dark.call(pal.metal.darkened(0.35)), dark.call(pal.metal.darkened(0.35)), dark.call(pal.metal.lightened(0.1))]))
			_ellipse(ci, Vector2(foot.x, foot.y - h), w * 0.5, 0.9 * u, dark.call(pal.metal.lightened(0.2)), 18)
			for k in 4:
				ci.draw_line(Vector2(body.position.x, foot.y - h * k / 4.0), Vector2(body.end.x, foot.y - h * k / 4.0), Color(0, 0, 0, 0.12), maxf(0.5, 0.06 * u))
			# A ladder up the side.
			ci.draw_line(Vector2(foot.x + w * 0.38, foot.y), Vector2(foot.x + w * 0.38, foot.y - h), Color(0, 0, 0, 0.35), maxf(0.6, 0.08 * u))
			if pal.neon_on:
				_edge(ci, PackedVector2Array([Vector2(body.position.x, foot.y), body.position, Vector2(body.end.x, body.position.y), Vector2(body.end.x, foot.y)]), pal, "edge")
		"pipes":
			for k in 2:
				var y := foot.y - (0.5 + k * 0.7) * u
				ci.draw_line(Vector2(foot.x - w * 0.5, y), Vector2(foot.x + w * 0.5, y), dark.call(pal.metal.darkened(0.1 + k * 0.1)), 0.55 * u)
				ci.draw_line(Vector2(foot.x - w * 0.5, y - 0.18 * u), Vector2(foot.x + w * 0.5, y - 0.18 * u), Color(1, 1, 1, 0.18), 0.12 * u)
			var x := foot.x - w * 0.5
			while x < foot.x + w * 0.5:
				ci.draw_line(Vector2(x, foot.y), Vector2(x, foot.y - 1.5 * u), dark.call(pal.metal.darkened(0.4)), 0.15 * u)
				x += 9.0 * u
			_edge(ci, PackedVector2Array([Vector2(foot.x - w * 0.5, foot.y - 1.4 * u), Vector2(foot.x + w * 0.5, foot.y - 1.4 * u)]), pal, "edge")
		"flare":
			ci.draw_line(foot, Vector2(foot.x, foot.y - h), dark.call(pal.metal.darkened(0.2)), maxf(1.0, 0.7 * u))
			for k in 6:
				var y := foot.y - h * k / 6.0
				ci.draw_line(Vector2(foot.x - 1.2 * u, y), Vector2(foot.x + 1.2 * u, y - h / 6.0), Color(dark.call(pal.metal), 0.5), 0.12 * u)
		"containers":
			var cols := [Color("a8432f"), Color("2f5d8a"), Color("3d7a4a"), Color("c07a2a"), Color("6a6a70")]
			var rows := int(round(float(s.h) / 2.6))
			var r := _rng(int(s.x))
			for row in rows:
				for k in 2:
					var c: Color = cols[r.randi() % cols.size()] if not pal.neon_on else pal.wood
					var box := Rect2(foot.x - w * 0.5 + k * w * 0.5 + (row % 2) * 0.3 * u, foot.y - (row + 1) * 2.6 * u, w * 0.5 - 0.1 * u, 2.55 * u)
					_box(ci, box, dark.call(c), pal, "edge" if (row + k) % 2 == 0 else "edge2")
					if not pal.neon_on:
						var x := box.position.x + 0.4 * u
						while x < box.end.x:
							ci.draw_line(Vector2(x, box.position.y + 0.2 * u), Vector2(x, box.end.y - 0.2 * u), Color(0, 0, 0, 0.2), maxf(0.4, 0.07 * u))
							x += 0.6 * u
		"crane":
			var top := foot.y - h
			for sx in [-0.5, 0.5]:
				ci.draw_line(Vector2(foot.x + sx * w, foot.y), Vector2(foot.x + sx * w * 0.6, top + 6 * u), dark.call(pal.metal), maxf(1.0, 0.5 * u))
			ci.draw_line(Vector2(foot.x - w * 0.5, foot.y - h * 0.35), Vector2(foot.x + w * 0.5, foot.y - h * 0.35), dark.call(pal.metal), maxf(1.0, 0.4 * u))
			_box(ci, Rect2(foot.x - w * 0.35, top + 4 * u, w * 0.7, 3 * u), dark.call(pal.metal.darkened(0.15)), pal)
			ci.draw_line(Vector2(foot.x - w * 1.4, top + 4 * u), Vector2(foot.x + w * 2.6, top + 4 * u), dark.call(pal.metal), maxf(1.0, 0.6 * u))  # boom
			ci.draw_line(Vector2(foot.x, top), Vector2(foot.x + w * 2.6, top + 4 * u), Color(dark.call(pal.metal), 0.6), 0.6)
			ci.draw_line(Vector2(foot.x, top), Vector2(foot.x - w * 1.4, top + 4 * u), Color(dark.call(pal.metal), 0.6), 0.6)
			ci.draw_line(Vector2(foot.x + w * 2.0, top + 4 * u), Vector2(foot.x + w * 2.0, top + 16 * u), Color(0.1, 0.1, 0.1, 0.7), 0.5)  # hook cable
			_edge(ci, PackedVector2Array([Vector2(foot.x - w * 1.4, top + 4 * u), Vector2(foot.x + w * 2.6, top + 4 * u)]), pal, "edge")
		"ship":
			var deck := foot.y - 8.0 * u
			var hull := PackedVector2Array([Vector2(foot.x - w * 0.5, deck), Vector2(foot.x + w * 0.5 + 4 * u, deck - 1.5 * u), Vector2(foot.x + w * 0.46, foot.y + 1 * u), Vector2(foot.x - w * 0.47, foot.y + 1 * u)])
			ci.draw_colored_polygon(hull, dark.call(Color("3a4252") if not pal.neon_on else pal.wood))
			ci.draw_rect(Rect2(foot.x - w * 0.5, foot.y - 1.2 * u, w, 1.0 * u), dark.call(Color("8a2a24") if not pal.neon_on else pal.wood))
			_box(ci, Rect2(foot.x - w * 0.42, deck - 7 * u, w * 0.16, 7 * u), dark.call(Color("dcdcd6") if not pal.neon_on else pal.roof), pal, "edge")
			ci.draw_rect(Rect2(foot.x - w * 0.36, deck - 9 * u, 1.2 * u, 3 * u), dark.call(pal.metal))
			for k in 4:  # deck cargo
				_box(ci, Rect2(foot.x - w * 0.2 + k * w * 0.16, deck - 2.6 * u, w * 0.14, 2.6 * u), dark.call([Color("2f5d8a"), Color("a8432f"), Color("3d7a4a"), Color("c07a2a")][k] if not pal.neon_on else pal.wood), pal)
			_edge(ci, hull, pal, "edge")
		"lighthouse":
			var tower := PackedVector2Array([Vector2(foot.x - w * 0.5, foot.y), Vector2(foot.x - w * 0.3, foot.y - h), Vector2(foot.x + w * 0.3, foot.y - h), Vector2(foot.x + w * 0.5, foot.y)])
			ci.draw_colored_polygon(tower, dark.call(Color("e8e2da") if not pal.neon_on else pal.wood))
			for k in 3:
				var y := foot.y - h * (0.2 + k * 0.28)
				ci.draw_rect(Rect2(foot.x - w * 0.45 + k * 0.05 * w, y, w * (0.9 - k * 0.1), h * 0.08), dark.call(Color("b03030") if not pal.neon_on else pal.edge2))
			ci.draw_rect(Rect2(foot.x - w * 0.35, foot.y - h - 3 * u, w * 0.7, 3 * u), dark.call(pal.metal.darkened(0.4)))
		"stilt":
			var floor_y := foot.y - h * 0.55
			for sx in [-0.45, -0.15, 0.15, 0.45]:
				ci.draw_line(Vector2(foot.x + sx * w, foot.y), Vector2(foot.x + sx * w, floor_y), dark.call(pal.wood), maxf(0.8, 0.2 * u))
			_box(ci, Rect2(foot.x - w * 0.5, floor_y - h * 0.3, w, h * 0.3), dark.call(pal.wood.lightened(0.05)), pal, "edge3")
			var roof := PackedVector2Array([Vector2(foot.x - w * 0.62, floor_y - h * 0.3), Vector2(foot.x, foot.y - h * 1.1), Vector2(foot.x + w * 0.62, floor_y - h * 0.3)])
			ci.draw_colored_polygon(roof, dark.call(Color("6a5a32") if not pal.neon_on else pal.roof))
			_edge(ci, roof, pal, "edge3")
		"ruin":
			var r := _rng(int(s.x) + 3)
			var x := foot.x - w * 0.5
			while x < foot.x + w * 0.5:
				var bh := r.randf_range(0.5, 1.0) * h
				_box(ci, Rect2(x, foot.y - bh, 1.1 * u, bh), dark.call(Color("4a524a") if not pal.neon_on else pal.wood).darkened(r.randf() * 0.15), pal, "edge3")
				x += 1.05 * u
			for sx in [-0.5, 0.45]:  # broken pillars at the ends
				var ph := h * r.randf_range(2.5, 3.6)
				_box(ci, Rect2(foot.x + sx * w, foot.y - ph, 1.5 * u, ph), dark.call(Color("525a52") if not pal.neon_on else pal.wood), pal, "edge3")
			if not pal.neon_on:
				for k in 6:  # moss and vines
					ci.draw_line(Vector2(foot.x + r.randf_range(-0.5, 0.5) * w, foot.y - h), Vector2(foot.x + r.randf_range(-0.5, 0.5) * w, foot.y - h * 0.2), Color("2c5a30", 0.7), maxf(0.6, 0.12 * u))
		"temple":
			var steps := 6
			for k in steps:
				var sw := w * (1.0 - k * 0.13)
				var y0 := foot.y - h * k / float(steps)
				var y1 := foot.y - h * (k + 1) / float(steps)
				var stone: Color = Color("3e4842").lightened(0.03 * k) if not pal.neon_on else pal.wood
				var face := PackedVector2Array([Vector2(foot.x - sw * 0.5, y0), Vector2(foot.x - sw * 0.46, y1), Vector2(foot.x + sw * 0.46, y1), Vector2(foot.x + sw * 0.5, y0)])
				ci.draw_colored_polygon(face, dark.call(stone))
				ci.draw_line(Vector2(foot.x - sw * 0.46, y1), Vector2(foot.x + sw * 0.46, y1), Color(1, 1, 1, 0.08) if not pal.neon_on else pal.edge3, maxf(0.6, 0.3 * u))
			# Stairs up the middle and the shrine on top.
			ci.draw_colored_polygon(PackedVector2Array([Vector2(foot.x - 3 * u, foot.y), Vector2(foot.x - 2 * u, foot.y - h), Vector2(foot.x + 2 * u, foot.y - h), Vector2(foot.x + 3 * u, foot.y)]), dark.call(Color("2e3632") if not pal.neon_on else pal.near))
			_box(ci, Rect2(foot.x - w * 0.12, foot.y - h - 6 * u, w * 0.24, 6 * u), dark.call(Color("444e48") if not pal.neon_on else pal.wood), pal, "edge3")
			ci.draw_rect(Rect2(foot.x - 1.2 * u, foot.y - h - 4 * u, 2.4 * u, 4 * u), Color(0.02, 0.02, 0.02))

## Places 4-6 and the kinds that came with them: a railway station, a water
## tower, box cars, a timber trestle; city blocks, a billboard, a roof water tank.
static func _draw_more(ci: CanvasItem, s: Dictionary, pal: Dictionary, foot: Vector2, u: float, w: float, h: float, d: float) -> bool:
	var glass := _haze(Color("2a3038"), pal, d)
	match str(s.t):
		"station":
			var body := Rect2(foot.x - w * 0.5, foot.y - h * 0.75, w, h * 0.75)
			_box(ci, body, _haze(pal.wood.lightened(0.1), pal, d), pal)
			if not pal.neon_on:
				var x := body.position.x
				while x < body.end.x:
					ci.draw_line(Vector2(x, body.position.y), Vector2(x, body.end.y), Color(0, 0, 0, 0.12), maxf(0.5, 0.05 * u))
					x += 0.5 * u
			var roof := PackedVector2Array([Vector2(foot.x - w * 0.62, body.position.y + 0.3 * u), Vector2(foot.x - w * 0.5, foot.y - h), Vector2(foot.x + w * 0.5, foot.y - h), Vector2(foot.x + w * 0.62, body.position.y + 0.3 * u)])
			ci.draw_colored_polygon(roof, _haze(pal.roof, pal, d))
			_edge(ci, roof, pal, "edge")
			for k in 3:
				ci.draw_rect(Rect2(foot.x - w * 0.4 + k * w * 0.3, foot.y - h * 0.55, w * 0.14, h * 0.24), glass)
			ci.draw_rect(Rect2(foot.x - w * 0.25, foot.y - h * 0.95, w * 0.5, h * 0.12), _haze(Color("e8dcc0"), pal, d))  # blank name board
			ci.draw_rect(Rect2(foot.x - w * 0.62, foot.y - 0.4 * u, w * 1.24, 0.4 * u), _haze(pal.road.darkened(0.1), pal, d))  # platform
			_shade_side(ci, body, pal)
		"watertower":
			var tank_b := foot.y - h * 0.62
			for sx in [-0.45, -0.15, 0.15, 0.45]:
				ci.draw_line(Vector2(foot.x + sx * w, foot.y), Vector2(foot.x + sx * w * 0.8, tank_b), _haze(pal.wood, pal, d), maxf(0.8, 0.18 * u))
			for k in 2:
				var y := lerpf(foot.y, tank_b, 0.35 + k * 0.35)
				ci.draw_line(Vector2(foot.x - w * 0.42, y), Vector2(foot.x + w * 0.42, y), _haze(pal.wood.darkened(0.2), pal, d), maxf(0.6, 0.08 * u))
			var tank := Rect2(foot.x - w * 0.5, foot.y - h, w, h * 0.38)
			_box(ci, tank, _haze(pal.wood.lightened(0.05), pal, d), pal, "edge")
			if not pal.neon_on:
				for k in 3:
					ci.draw_line(Vector2(tank.position.x, tank.position.y + tank.size.y * (k + 1) / 4.0), Vector2(tank.end.x, tank.position.y + tank.size.y * (k + 1) / 4.0), Color(0.1, 0.1, 0.1, 0.4), maxf(0.5, 0.06 * u))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(foot.x - w * 0.56, foot.y - h), Vector2(foot.x, foot.y - h - 1.6 * u), Vector2(foot.x + w * 0.56, foot.y - h)]), _haze(pal.roof.darkened(0.2), pal, d))
			ci.draw_line(Vector2(foot.x + w * 0.5, tank_b - 0.4 * u), Vector2(foot.x + w * 0.9, tank_b + 1.0 * u), _haze(pal.metal, pal, d), maxf(0.6, 0.12 * u))
			ci.draw_rect(Rect2(foot.x - w * 0.6, tank_b - 0.2 * u, w * 1.2, 0.2 * u), _haze(pal.wood, pal, d))  # catwalk
			_shade_side(ci, tank, pal)
		"railcar":
			ci.draw_line(Vector2(foot.x - w * 0.8, foot.y), Vector2(foot.x + w * 0.8, foot.y), Color(0.2, 0.18, 0.16), maxf(0.6, 0.1 * u))
			var body := Rect2(foot.x - w * 0.5, foot.y - h, w, h - 0.9 * u)
			_box(ci, body, _haze(Color("7a3a28") if not pal.neon_on else pal.wood, pal, d), pal, "edge")
			if not pal.neon_on:
				var x := body.position.x + 0.3 * u
				while x < body.end.x:
					ci.draw_line(Vector2(x, body.position.y), Vector2(x, body.end.y), Color(0, 0, 0, 0.15), maxf(0.5, 0.06 * u))
					x += 0.8 * u
			ci.draw_rect(Rect2(foot.x - w * 0.12, body.position.y + 0.3 * u, w * 0.24, body.size.y - 0.4 * u), _haze(Color("5a2a1e"), pal, d))
			for wx in [-0.38, -0.28, 0.28, 0.38]:
				ci.draw_circle(Vector2(foot.x + wx * w, foot.y - 0.42 * u), 0.42 * u, Color(0.1, 0.1, 0.1))
			_shade_side(ci, body, pal)
		"trestle":
			var deck := foot.y - h
			var col := _haze(pal.wood.darkened(0.1), pal, d)
			var bay := 9.0 * u
			var x := foot.x - w * 0.5
			while x <= foot.x + w * 0.5:
				ci.draw_line(Vector2(x - 0.8 * u, foot.y + 2.0 * u), Vector2(x, deck), col, maxf(0.8, 0.3 * u))
				ci.draw_line(Vector2(x + 0.8 * u, foot.y + 2.0 * u), Vector2(x, deck), col, maxf(0.8, 0.3 * u))
				if x + bay <= foot.x + w * 0.5 + 0.1:
					for k in 3:
						var ya := lerpf(foot.y + 2.0 * u, deck, k / 3.0)
						var yb := lerpf(foot.y + 2.0 * u, deck, (k + 1) / 3.0)
						ci.draw_line(Vector2(x, ya), Vector2(x + bay, yb), Color(col, 0.8), maxf(0.5, 0.12 * u))
						ci.draw_line(Vector2(x + bay, ya), Vector2(x, yb), Color(col, 0.8), maxf(0.5, 0.12 * u))
				x += bay
			ci.draw_rect(Rect2(foot.x - w * 0.5 - 2.0 * u, deck - 0.6 * u, w + 4.0 * u, 0.6 * u), _haze(pal.wood, pal, d))
			ci.draw_line(Vector2(foot.x - w * 0.5 - 2.0 * u, deck - 0.7 * u), Vector2(foot.x + w * 0.5 + 2.0 * u, deck - 0.7 * u), _haze(pal.metal, pal, d), maxf(0.5, 0.08 * u))
			_edge(ci, PackedVector2Array([Vector2(foot.x - w * 0.5, deck - 0.6 * u), Vector2(foot.x + w * 0.5, deck - 0.6 * u)]), pal, "edge")
		"block":
			var hsh := int(s.x) * 7 + int(s.d)
			var mats := [Color("8a8478"), Color("7a4a3a"), Color("4a5a6e"), Color("9a9a96"), Color("5a5048")]
			var mat: Color = mats[hsh % mats.size()] if not pal.neon_on else pal.wood
			var body := Rect2(foot.x - w * 0.5, foot.y - h, w, h)
			_box(ci, body, _haze(mat, pal, d), pal, "edge")
			# Window grid: one every 2.6 m across, one per 3.2 m storey.
			var gc := glass if not pal.neon_on else Color("0a0614")
			var cols := maxi(2, int(float(s.w) / 2.6))
			var rows := maxi(2, int(float(s.h) / 3.2))
			var cw := w / cols
			var rh := h / rows
			for ry in rows:
				for cx in cols:
					ci.draw_rect(Rect2(body.position.x + cx * cw + cw * 0.22, body.position.y + ry * rh + rh * 0.25, cw * 0.56, rh * 0.5), gc)
			ci.draw_rect(Rect2(body.position.x - 0.2 * u, body.position.y - 0.9 * u, w + 0.4 * u, 0.9 * u), _haze(mat.darkened(0.2), pal, d))  # parapet
			var r := _rng(hsh)
			for k in 2:  # roof boxes
				var bx := body.position.x + r.randf_range(0.1, 0.8) * w
				ci.draw_rect(Rect2(bx, body.position.y - 1.6 * u, 1.4 * u, 0.8 * u), _haze(pal.metal.darkened(0.2), pal, d))
			ci.draw_rect(Rect2(foot.x - w * 0.1, foot.y - 3.2 * u, w * 0.2, 3.2 * u), Color(0.08, 0.08, 0.1))  # street door
			_shade_side(ci, body, pal)
		"billboard":
			for sx in [-0.3, 0.3]:
				ci.draw_line(Vector2(foot.x + sx * w, foot.y), Vector2(foot.x + sx * w, foot.y - h * 0.4), _haze(pal.metal.darkened(0.3), pal, d), maxf(0.8, 0.2 * u))
			var panel := Rect2(foot.x - w * 0.5, foot.y - h, w, h * 0.6)
			ci.draw_rect(panel, _haze(Color("2a2e36"), pal, d))
			var bands := [Color("d8402a"), Color("f0c040"), Color("2a8ad8")]
			for k in 3:
				ci.draw_rect(Rect2(panel.position.x + w * 0.06, panel.position.y + panel.size.y * (0.12 + k * 0.28), w * (0.88 - k * 0.2), panel.size.y * 0.18), _haze(bands[k], pal, d) if not pal.neon_on else [pal.edge, pal.edge2, pal.edge3][k])
		"watertank":
			for sx in [-0.4, 0.4]:
				ci.draw_line(Vector2(foot.x + sx * w, foot.y), Vector2(foot.x + sx * w, foot.y - h * 0.35), _haze(pal.metal.darkened(0.4), pal, d), maxf(0.6, 0.15 * u))
			var tank := Rect2(foot.x - w * 0.5, foot.y - h * 0.85, w, h * 0.5)
			_box(ci, tank, _haze(Color("6a4a34") if not pal.neon_on else pal.wood, pal, d), pal, "edge3")
			ci.draw_colored_polygon(PackedVector2Array([Vector2(foot.x - w * 0.55, tank.position.y), Vector2(foot.x, foot.y - h), Vector2(foot.x + w * 0.55, tank.position.y)]), _haze(Color("4a3a2a"), pal, d))
			_shade_side(ci, tank, pal)
		_:
			return false
	return true

## The side away from the sun, in shade.
static func _shade_side(ci: CanvasItem, r: Rect2, pal: Dictionary) -> void:
	if pal.neon_on:
		return
	var away := -float(pal.sun_side)
	var sw := r.size.x * 0.24
	var x := r.end.x - sw if away > 0.0 else r.position.x
	ci.draw_rect(Rect2(x, r.position.y, sw, r.size.y), Color(0, 0, 0, 0.18))
	var lx := r.position.x if away > 0.0 else r.end.x - maxf(1.0, r.size.x * 0.02)
	ci.draw_rect(Rect2(lx, r.position.y, maxf(1.0, r.size.x * 0.02), r.size.y), Color(1, 1, 1, 0.12))

## Rails in front of guards standing on a platform (z one step nearer than the guard).
static func draw_front_rail(ci: CanvasItem, s: Dictionary, pal: Dictionary) -> void:
	var d := float(s.d)
	var u := E.upm(d)
	var foot := Vector2(float(s.x), E.ground_y(d) - float(s.get("base", 0.0)) * u)
	var w := float(s.get("w", 4.0)) * u
	var h := float(s.get("h", 4.0)) * u
	var col: Color = _haze(pal.wood.darkened(0.1), pal, d)
	match str(s.t):
		"tower":
			var top := foot.y - h
			ci.draw_rect(Rect2(foot.x - w * 0.42, top - 0.7 * u, w * 0.84, 0.55 * u), col)
			ci.draw_line(Vector2(foot.x - w * 0.42, top - 1.0 * u), Vector2(foot.x + w * 0.42, top - 1.0 * u), col, maxf(0.6, 0.1 * u))
			_edge(ci, PackedVector2Array([Vector2(foot.x - w * 0.42, top - 1.0 * u), Vector2(foot.x + w * 0.42, top - 1.0 * u)]), pal, "edge")
		"stilt":
			var floor_y := foot.y - h * 0.55
			ci.draw_rect(Rect2(foot.x - w * 0.5, floor_y - 0.55 * u, w, 0.55 * u), col)
		"block":
			var roof := foot.y - h
			ci.draw_rect(Rect2(foot.x - w * 0.5 - 0.2 * u, roof - 0.9 * u, w + 0.4 * u, 0.9 * u), _haze(Color("6a6660") if not pal.neon_on else pal.wood, pal, d))
			_edge(ci, PackedVector2Array([Vector2(foot.x - w * 0.5, roof - 0.9 * u), Vector2(foot.x + w * 0.5, roof - 0.9 * u)]), pal, "edge")
		"watertower":
			var cw := foot.y - h * 0.62
			ci.draw_line(Vector2(foot.x - w * 0.6, cw - 1.0 * u), Vector2(foot.x + w * 0.6, cw - 1.0 * u), col, maxf(0.6, 0.1 * u))
			var x := foot.x - w * 0.6
			while x <= foot.x + w * 0.6:
				ci.draw_line(Vector2(x, cw), Vector2(x, cw - 1.0 * u), col, maxf(0.4, 0.06 * u))
				x += 0.6 * u
		"trestle":
			var deck := foot.y - h
			ci.draw_line(Vector2(foot.x - w * 0.5, deck - 1.4 * u), Vector2(foot.x + w * 0.5, deck - 1.4 * u), col, maxf(0.6, 0.12 * u))
			var x := foot.x - w * 0.5
			while x <= foot.x + w * 0.5:
				ci.draw_line(Vector2(x, deck - 0.6 * u), Vector2(x, deck - 1.4 * u), col, maxf(0.4, 0.08 * u))
				x += 1.5 * u
		"ship":
			var deck := foot.y - 8.0 * u
			ci.draw_line(Vector2(foot.x - w * 0.5, deck - 0.9 * u), Vector2(foot.x + w * 0.5, deck - 0.9 * u), _haze(pal.metal, pal, d), maxf(0.6, 0.1 * u))
			var x := foot.x - w * 0.5
			while x < foot.x + w * 0.5:
				ci.draw_line(Vector2(x, deck), Vector2(x, deck - 0.9 * u), _haze(pal.metal, pal, d), maxf(0.4, 0.06 * u))
				x += 1.2 * u

## The moving bits of a structure: smoke, flags, flames, beams, lights.
static func draw_structure_live(ci: CanvasItem, s: Dictionary, pal: Dictionary, time: float, wind: float) -> void:
	var d := float(s.d)
	var u := E.upm(d)
	var foot := Vector2(float(s.x), E.ground_y(d) - float(s.get("base", 0.0)) * u)
	var w := float(s.get("w", 4.0)) * u
	var h := float(s.get("h", 4.0)) * u
	var ws := wind_sign(wind)
	match str(s.t):
		"cabin":
			_smoke(ci, Vector2(foot.x - w * 0.3, foot.y - h * 0.86), u, time, wind, pal, int(s.x))
		"tower":
			_flag(ci, Vector2(foot.x, foot.y - h - 3.4 * u), u, time, wind, pal)
		"tent", "hut", "station":
			_flag(ci, Vector2(foot.x + w * 0.4, foot.y - h * 1.1), u * 0.8, time, wind, pal)
		"watertower":
			_flag(ci, Vector2(foot.x, foot.y - h - 1.6 * u), u, time, wind, pal)
		"block":
			if int(s.x) % 3 == 0:
				_smoke(ci, Vector2(foot.x + w * 0.3, foot.y - h - 1.6 * u), u, time, wind, pal, int(s.x), Color(0.9, 0.9, 0.95, 0.25))
		"mast":
			var on := fposmod(time, 1.6) < 0.5
			_glow(ci, Vector2(foot.x, foot.y - h), maxf(1.2, 0.35 * u), Color(1.0, 0.15, 0.1, 0.95 if on else 0.25), 4)
			if pal.loc == "desert":
				_windsock(ci, Vector2(foot.x, foot.y - h * 0.55), u, time, wind, pal)
		"flare":
			var tip := Vector2(foot.x, foot.y - h)
			for k in 6:
				var f := sin(time * (11.0 + k) + k) * 0.5 + 0.5
				var p := tip + Vector2(ws * (k * 0.7 + f) * u, -(k * 1.0 + f * 1.5) * u)
				_glow(ci, p, (1.6 - k * 0.2) * u, Color(1.0, 0.55 - k * 0.06, 0.1, 0.7 - k * 0.09), 3)
			_smoke(ci, tip + Vector2(ws * 4 * u, -7 * u), u * 1.4, time, wind, pal, 99, Color(0.15, 0.13, 0.12, 0.5))
		"lighthouse":
			var lamp := Vector2(foot.x, foot.y - h - 1.5 * u)
			var a := time * 0.9
			var dir := Vector2(cos(a), sin(a) * 0.12).normalized()
			# The beam sweeps round after dark: brightest along the coast, faint when it faces us.
			if not pal.lit and not pal.neon_on:
				_glow(ci, lamp, 1.2 * u, Color(1.0, 0.95, 0.7, 0.5), 3)
				return
			var len_ := 900.0
			var spread := 0.07
			var c: Color = Color(1.0, 0.95, 0.75, 0.22 * (0.35 + 0.65 * absf(cos(a)))) if not pal.neon_on else Color(pal.edge, 0.25)
			ci.draw_colored_polygon(PackedVector2Array([lamp, lamp + dir.rotated(-spread) * len_, lamp + dir.rotated(spread) * len_]), c)
			_glow(ci, lamp, 2.2 * u, Color(1.0, 0.95, 0.7, 0.9), 4)
		"crane":
			var top := foot.y - h
			var on := fposmod(time + float(s.x) * 0.01, 2.0) < 0.6
			_glow(ci, Vector2(foot.x + w * 2.6, top + 4 * u), maxf(1.2, 0.5 * u), Color(1.0, 0.2, 0.1, 0.95 if on else 0.2), 3)
		"ship":
			_smoke(ci, Vector2(foot.x - w * 0.36 + 0.6 * u, foot.y - 8.0 * u - 9 * u), u, time, wind, pal, 7)
		"temple":
			for sx in [-0.3, 0.3]:
				var p := Vector2(foot.x + sx * w * 0.7, foot.y - h * 0.5)
				_torch(ci, p, u, time, pal)
			_torch(ci, Vector2(foot.x - w * 0.12, foot.y - h - 6 * u), u, time, pal)
			_torch(ci, Vector2(foot.x + w * 0.12, foot.y - h - 6 * u), u, time, pal)
		"stilt":
			var lamp := Vector2(foot.x - w * 0.2, foot.y - h * 0.7)
			_glow(ci, lamp, 1.0 * u, Color(1.0, 0.7, 0.3, 0.6 + 0.2 * sin(time * 7.0 + float(s.x))), 4)

static func _smoke(ci: CanvasItem, src: Vector2, u: float, time: float, wind: float, pal: Dictionary, seed: int, col: Color = Color(0.85, 0.85, 0.9, 0.35)) -> void:
	if pal.neon_on:
		col = Color(pal.edge, 0.18)
	else:
		col = col * Color(pal.tint, 1.0)  # this layer isn't tinted: smoke takes the hour's light itself
	for k in 9:
		var age := fposmod(time * 0.45 + k / 9.0 + seed * 0.13, 1.0)
		var p := src + Vector2(wind * age * age * 6.0 * u + sin(age * 6.0 + k) * 0.4 * u, -age * 9.0 * u)
		var r := (0.4 + age * 2.2) * u
		ci.draw_circle(p, r, Color(col, col.a * (1.0 - age)))

static func _flag(ci: CanvasItem, pole_top: Vector2, u: float, time: float, wind: float, pal: Dictionary) -> void:
	ci.draw_line(pole_top, pole_top + Vector2(0, 3.0 * u), Color(0.2, 0.2, 0.2) * Color(pal.tint, 1.0), maxf(0.6, 0.08 * u))
	var ws := wind_sign(wind)
	var droop := 1.0 - absf(ws)
	var len_ := 1.6 * u
	var col: Color = Color("b0302a") * Color(pal.tint, 1.0) if not pal.neon_on else pal.edge2
	var pts := PackedVector2Array()
	var bottom := PackedVector2Array()
	for k in 7:
		var f := k / 6.0
		var wave := sin(time * (5.0 + absf(ws) * 6.0) - f * 5.0) * 0.18 * u * f
		var off := Vector2((ws if absf(ws) > 0.05 else 0.1) * len_ * f, droop * f * 1.0 * u + wave)
		pts.append(pole_top + off)
		bottom.append(pole_top + off + Vector2(0, 0.95 * u * (1.0 - f * 0.15)))
	bottom.reverse()
	var poly := pts.duplicate()
	poly.append_array(bottom)
	ci.draw_colored_polygon(poly, col)

static func _windsock(ci: CanvasItem, at: Vector2, u: float, time: float, wind: float, pal: Dictionary) -> void:
	var ws := wind_sign(wind)
	var lift := absf(ws)
	for k in 5:
		var f := k / 5.0
		var p := at + Vector2(ws * f * 2.4 * u, (1.0 - lift) * f * 1.6 * u + sin(time * 6.0 - k) * 0.05 * u)
		var c := Color("ff6a1a") if k % 2 == 0 else Color("f2f2f2")
		if pal.neon_on:
			c = pal.edge2 if k % 2 == 0 else pal.edge
		ci.draw_circle(p, (0.42 - k * 0.05) * u, c)

static func _torch(ci: CanvasItem, p: Vector2, u: float, time: float, pal: Dictionary) -> void:
	var f := 0.75 + 0.25 * sin(time * 13.0 + p.x) * sin(time * 7.0 + p.y)
	_glow(ci, p, 1.4 * u * f, Color(1.0, 0.6, 0.2, 0.85) if not pal.neon_on else Color(pal.edge3, 0.9), 5)

## The dish on top of a mast / crane / tower (a target: shooting it quiets the alarm).
static func draw_dish(ci: CanvasItem, pr: Dictionary, pal: Dictionary, time: float) -> void:
	var d := float(pr.d)
	var u := E.upm(d)
	var c := Vector2(float(pr.x), E.ground_y(d) - float(pr.h) * u - 0.6 * u)
	if not pr.alive:
		ci.draw_line(c + Vector2(0, 0.6 * u), c + Vector2(0.5 * u, 0.9 * u), Color(0.15, 0.15, 0.15), 0.12 * u)
		return
	var col: Color = Color("d8d8d0") if not pal.neon_on else pal.edge
	_ellipse(ci, c, 0.75 * u, 0.62 * u, _haze(col, pal, d), 14)
	_ellipse(ci, c + Vector2(0.12 * u, 0), 0.5 * u, 0.42 * u, _haze(col.darkened(0.2), pal, d), 12)
	ci.draw_line(c, c + Vector2(0.7 * u, -0.4 * u), Color(0.3, 0.3, 0.3), maxf(0.4, 0.06 * u))
	if fposmod(time, 2.4) < 0.3:
		ci.draw_circle(c + Vector2(0.7 * u, -0.4 * u), maxf(0.8, 0.12 * u), Color(0.4, 1.0, 0.4))

static func draw_drum(ci: CanvasItem, pr: Dictionary, pal: Dictionary) -> void:
	var d := float(pr.d)
	var u := E.upm(d)
	var foot := Vector2(float(pr.x), E.ground_y(d))
	if not pr.alive:
		_ellipse(ci, foot, 1.4 * u, 0.25 * u, Color(0.05, 0.04, 0.03, 0.8), 12)
		ci.draw_rect(Rect2(foot.x - 0.3 * u, foot.y - 0.3 * u, 0.6 * u, 0.3 * u), Color(0.12, 0.08, 0.06))
		return
	var col: Color = Color("b8321e") if not pal.neon_on else pal.edge3
	ci.draw_rect(Rect2(foot.x - 0.3 * u, foot.y - 0.88 * u, 0.6 * u, 0.88 * u), _haze(col, pal, d))
	for k in 2:
		ci.draw_line(Vector2(foot.x - 0.3 * u, foot.y - (0.3 + k * 0.3) * u), Vector2(foot.x + 0.3 * u, foot.y - (0.3 + k * 0.3) * u), Color(0, 0, 0, 0.35), maxf(0.4, 0.05 * u))
	ci.draw_rect(Rect2(foot.x - 0.2 * u, foot.y - 0.7 * u, 0.16 * u, 0.5 * u), Color(1, 1, 1, 0.2))
	# A hazard mark so it reads as "shoot me".
	var m := Vector2(foot.x, foot.y - 0.5 * u)
	ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -0.16 * u), m + Vector2(0.14 * u, 0.1 * u), m + Vector2(-0.14 * u, 0.1 * u)]), Color("ffd23a"))

# ---------- people ----------

## A guard, the officer or a civilian. Proportions in metres times `u`; the
## figure turns with tg.face, walks with tg.walk, ducks in cover, falls when hit.
## Idle guards do one of three things (tg.act): hold the rifle ready, smoke with
## the rifle slung, or lower the rifle; the officer has a peaked cap, a red
## armband, a pistol and binoculars (that glint). Civilians wear hi-vis vests
## and white hard hats and carry a toolbox: never a target.
static func draw_guard(ci: CanvasItem, tg: Dictionary, foot: Vector2, pal: Dictionary, time: float, marker: bool) -> void:
	var d := float(tg.d)
	var u := E.upm(d)
	var face := float(tg.face)
	var st: String = tg.state
	if st == "gone":
		return
	var alpha := 1.0
	var angle := 0.0
	if st == "down":
		var k := clampf(float(tg.down_t) / 0.45, 0.0, 1.0)
		angle = -face * PI * 0.5 * k * k
		alpha = clampf(1.0 - (float(tg.down_t) - 1.4) / 1.0, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var civ: bool = tg.get("civ", false)
	var officer: bool = tg.kind == "officer"
	var hd := d * 0.6
	var jacket: Color = _haze(pal.uni, pal, hd)
	var trousers: Color = _haze(pal.uni2, pal, hd)
	if civ:
		jacket = _haze(Color("e2ea34"), pal, hd)
		trousers = _haze(Color("34445e"), pal, hd)
	elif officer:
		jacket = _haze((pal.uni as Color).lightened(0.1), pal, hd)
	if pal.neon_on:
		jacket = pal.edge3 if civ else pal.edge2
		trousers = jacket.darkened(0.45)
	jacket.a = alpha
	trousers.a = alpha
	var skin: Color = _haze(pal.skin_tone, pal, hd)
	skin.a = alpha
	var boots := Color(0.08, 0.07, 0.06, alpha)
	var lit := float(pal.get("sun_side", 1.0))
	if st != "down":
		_ellipse(ci, foot + Vector2(-lit * 0.35 * u, 0.02 * u), 0.55 * u, 0.1 * u, Color(0, 0, 0, (0.25 if not pal.night else 0.1) * alpha), 12)
	var duck := st == "cover"
	ci.draw_set_transform(foot, angle, Vector2(1.0, 0.62 if duck else 1.0))
	var walking: bool = st in ["walk", "flee"]
	var ph := float(tg.get("walk", 0.0)) * (3.2 if st == "flee" else 2.4)
	var swing := (sin(ph) * (0.45 if st == "flee" else 0.32)) if walking else 0.0
	_leg(ci, u, -swing, trousers.darkened(0.25), boots, face, walking, ph + PI)
	_leg(ci, u, swing, trousers, boots, face, walking, ph)
	var act := int(tg.get("act", 0)) if st == "idle" else 0
	var rifleman := not civ and not officer
	if rifleman and act == 1:  # slung on the back while he smokes
		ci.draw_line(Vector2(-face * 0.2 * u, -0.95 * u), Vector2(face * 0.1 * u, -1.65 * u), Color(0.08, 0.07, 0.06, alpha), 0.07 * u)
	var torso := PackedVector2Array([Vector2(-0.17 * u, -0.9 * u), Vector2(0.17 * u, -0.9 * u), Vector2(0.22 * u, -1.48 * u), Vector2(-0.22 * u, -1.48 * u)])
	ci.draw_colored_polygon(torso, jacket)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -0.9 * u), Vector2(lit * 0.17 * u, -0.9 * u), Vector2(lit * 0.22 * u, -1.48 * u), Vector2(0, -1.48 * u)]), Color(1, 1, 1, 0.1 * alpha))
	if civ:
		for yy in [-1.08, -1.28]:
			ci.draw_line(Vector2(-0.2 * u, yy * u), Vector2(0.2 * u, yy * u), Color(0.85, 0.88, 0.92, alpha), 0.045 * u)
	else:
		ci.draw_line(Vector2(-0.18 * u, -0.97 * u), Vector2(0.18 * u, -0.97 * u), Color(0.1, 0.09, 0.07, alpha), 0.05 * u)
		for px in [-0.12, 0.04]:
			ci.draw_rect(Rect2(px * u, -1.2 * u, 0.08 * u, 0.11 * u), jacket.darkened(0.3))
	var head := Vector2(face * 0.02 * u, -1.66 * u)
	ci.draw_rect(Rect2(-0.05 * u, -1.56 * u, 0.1 * u, 0.08 * u), skin.darkened(0.15))
	ci.draw_circle(head, 0.115 * u, skin)
	ci.draw_circle(head + Vector2(face * 0.1 * u, 0.015 * u), 0.03 * u, skin)
	_hat(ci, head, u, face, pal, jacket, civ, officer, alpha)
	var sh_f := Vector2(face * 0.13 * u, -1.42 * u)
	var sh_b := Vector2(-face * 0.13 * u, -1.42 * u)
	var sleeve_b := jacket.darkened(0.2)
	if civ:
		var hf := Vector2(face * 0.06 * u + swing * 0.25 * u, -0.98 * u)
		var hb := Vector2(-face * 0.06 * u - swing * 0.25 * u, -0.98 * u)
		_arm(ci, sh_b, hb, sleeve_b, skin, u)
		_arm(ci, sh_f, hf, jacket, skin, u)
		ci.draw_rect(Rect2(hf.x - 0.11 * u, hf.y, 0.22 * u, 0.15 * u), Color(0.75, 0.16, 0.1, alpha))
	elif officer and act == 2:
		var bh := head + Vector2(face * 0.13 * u, 0.0)
		_arm(ci, sh_b, bh + Vector2(-face * 0.04 * u, 0.05 * u), sleeve_b, skin, u)
		_arm(ci, sh_f, bh + Vector2(0, 0.06 * u), jacket, skin, u)
		ci.draw_rect(Rect2(bh.x - 0.07 * u, bh.y - 0.05 * u, 0.14 * u, 0.09 * u), Color(0.06, 0.06, 0.06, alpha))
		if fposmod(time * 0.7 + float(tg.id), 3.0) < 0.15:
			_glow(ci, bh + Vector2(face * 0.08 * u, 0), 0.14 * u, Color(1, 1, 0.9, 0.9 * alpha), 3)
	elif officer:
		_arm(ci, sh_b, Vector2(-face * 0.14 * u, -1.0 * u), sleeve_b, skin, u)
		_arm(ci, sh_f, Vector2(face * 0.22 * u, -1.02 * u), jacket, skin, u)
		ci.draw_rect(Rect2(face * 0.13 * u - 0.04 * u, -1.03 * u, 0.08 * u, 0.14 * u), Color(0.14, 0.09, 0.05, alpha))
	elif act == 1:
		var mouth := head + Vector2(face * 0.1 * u, 0.05 * u)
		_arm(ci, sh_b, Vector2(-face * 0.05 * u, -1.0 * u), sleeve_b, skin, u)
		_arm(ci, sh_f, mouth + Vector2(face * 0.03 * u, 0.03 * u), jacket, skin, u)
		var gk := 0.5 + 0.5 * sin(time * 2.2 + float(tg.id))
		ci.draw_circle(mouth + Vector2(face * 0.08 * u, 0), maxf(0.4, 0.025 * u), Color(1.0, 0.45 + 0.35 * gk, 0.15, alpha))
		var age := fposmod(time * 0.5 + float(tg.id) * 0.37, 1.0)
		ci.draw_circle(mouth + Vector2(face * 0.1 * u + age * 0.3 * u, -age * 0.6 * u), (0.04 + age * 0.12) * u, Color(0.85, 0.85, 0.88, 0.3 * (1.0 - age) * alpha))
	else:
		var lowered := act == 2 and st == "idle"
		var stock := Vector2(-face * 0.12 * u, -1.06 * u) if not lowered else Vector2(-face * 0.04 * u, -1.24 * u)
		var muzzle := stock + (Vector2(face * 0.95 * u, -0.48 * u) if not lowered else Vector2(face * 0.72 * u, 0.48 * u))
		if st == "flee":
			muzzle = stock + Vector2(face * 0.9 * u, -0.25 * u)
		_arm(ci, sh_b, stock.lerp(muzzle, 0.2), sleeve_b, skin, u)
		_rifle(ci, stock, muzzle, u, alpha)
		_arm(ci, sh_f, stock.lerp(muzzle, 0.52), jacket, skin, u)
	if officer:
		ci.draw_line(sh_f + Vector2(0, 0.07 * u), sh_f + Vector2(0, 0.17 * u), Color(0.9, 0.1, 0.1, alpha), 0.11 * u)
	if pal.neon_on:
		ci.draw_polyline(PackedVector2Array([Vector2(-0.17 * u, -0.9 * u), Vector2(-0.22 * u, -1.48 * u), head + Vector2(0, -0.17 * u), Vector2(0.22 * u, -1.48 * u), Vector2(0.17 * u, -0.9 * u)]), Color(pal.edge, 0.8 * alpha), maxf(0.6, 0.04 * u))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The officer's marker (Easy / Normal): a small red chevron over him.
	if marker and tg.primary and st != "down":
		var m := foot + Vector2(0, -2.5 * u * (0.62 if duck else 1.0) - 0.3 * u)
		var k := 0.25 * u + 2.0
		var bob := sin(time * 4.0) * 0.08 * u
		ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-k, -k + bob), m + Vector2(k, -k + bob), m + Vector2(0, bob)]), Color(1.0, 0.2, 0.15, 0.85))

## One leg: thigh and shin (the knee bends on the back-swing), and a boot.
static func _leg(ci: CanvasItem, u: float, a: float, col: Color, boots: Color, face: float, walking: bool, ph: float) -> void:
	var hip := Vector2(0, -0.92 * u)
	var knee := hip + Vector2(sin(a) * face, cos(a)) * 0.47 * u
	var bend := maxf(0.0, sin(ph)) * 0.55 if walking else 0.04
	var b := a - bend
	var ankle := knee + Vector2(sin(b) * face, cos(b)) * 0.44 * u
	ci.draw_line(hip, knee, col, 0.16 * u)
	ci.draw_line(knee, ankle, col, 0.13 * u)
	ci.draw_circle(knee, 0.075 * u, col)
	ci.draw_rect(Rect2(ankle.x - 0.06 * u * face - (0.0 if face > 0 else 0.18 * u), ankle.y - 0.06 * u, 0.24 * u, 0.09 * u), boots)

## An arm from shoulder to hand, bent at the elbow, with the hand.
static func _arm(ci: CanvasItem, sh: Vector2, hand: Vector2, col: Color, skin: Color, u: float) -> void:
	var mid := sh.lerp(hand, 0.5)
	var n := (hand - sh).orthogonal().normalized()
	if n.y < 0.0:
		n = -n
	var elbow := mid + n * 0.07 * u
	ci.draw_line(sh, elbow, col, 0.11 * u)
	ci.draw_line(elbow, hand, col, 0.1 * u)
	ci.draw_circle(elbow, 0.05 * u, col)
	ci.draw_circle(hand, 0.045 * u, skin)

static func _rifle(ci: CanvasItem, stock: Vector2, muzzle: Vector2, u: float, alpha: float) -> void:
	var dir := (muzzle - stock).normalized()
	var n := dir.orthogonal()
	var dark := Color(0.07, 0.065, 0.06, alpha)
	var wood := Color(0.28, 0.2, 0.13, alpha)
	ci.draw_colored_polygon(PackedVector2Array([stock - n * 0.05 * u, stock + n * 0.06 * u, stock + dir * 0.3 * u + n * 0.03 * u, stock + dir * 0.3 * u - n * 0.03 * u]), wood)
	ci.draw_line(stock + dir * 0.28 * u, stock + dir * 0.75 * u, dark, 0.07 * u)
	ci.draw_line(stock + dir * 0.75 * u, muzzle, dark, 0.035 * u)
	ci.draw_line(stock + dir * 0.45 * u, stock + dir * 0.45 * u - n * 0.16 * u + dir * 0.03 * u, dark, 0.05 * u)  # magazine
	ci.draw_line(stock + dir * 0.38 * u + n * 0.06 * u, stock + dir * 0.6 * u + n * 0.06 * u, dark, 0.045 * u)  # optic

## Headgear by place: beanie, scarf, helmet, cap, boonie hat or balaclava; the
## officer's peaked cap; the civilians' white hard hat.
static func _hat(ci: CanvasItem, head: Vector2, u: float, face: float, pal: Dictionary, jacket: Color, civ: bool, officer: bool, alpha: float) -> void:
	var dome := func(rx: float, ry: float, lift: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 11:
			var a := PI + PI * i / 10.0
			pts.append(head + Vector2(cos(a) * rx * u, sin(a) * ry * u - lift * u))
		ci.draw_colored_polygon(pts, col)
	if civ:
		dome.call(0.15, 0.13, 0.02, Color(0.95, 0.95, 0.92, alpha))
		ci.draw_line(head + Vector2(-0.17 * u, -0.02 * u), head + Vector2(0.17 * u, -0.02 * u), Color(0.9, 0.9, 0.88, alpha), 0.03 * u)
		return
	if officer:
		dome.call(0.13, 0.08, 0.06, jacket.darkened(0.15))
		ci.draw_rect(Rect2(head.x - 0.15 * u, head.y - 0.13 * u, 0.3 * u, 0.07 * u), jacket.darkened(0.3))
		ci.draw_rect(Rect2(head.x - 0.13 * u, head.y - 0.1 * u, 0.26 * u, 0.025 * u), Color(0.85, 0.1, 0.1, alpha))
		ci.draw_line(head + Vector2(face * 0.02 * u, -0.06 * u), head + Vector2(face * 0.2 * u, -0.04 * u), Color(0.05, 0.05, 0.05, alpha), 0.035 * u)
		return
	var dark := jacket.darkened(0.3)
	match str(pal.get("hat", "helmet")):
		"beanie":
			dome.call(0.13, 0.14, 0.0, Color(0.32, 0.32, 0.34, alpha))
			ci.draw_rect(Rect2(head.x - 0.13 * u, head.y - 0.06 * u, 0.26 * u, 0.05 * u), Color(0.24, 0.24, 0.26, alpha))
		"scarf":
			dome.call(0.14, 0.13, 0.0, Color(0.78, 0.7, 0.55, alpha))
			ci.draw_rect(Rect2(head.x - 0.12 * u, head.y + 0.03 * u, 0.24 * u, 0.1 * u), Color(0.72, 0.64, 0.5, alpha))
			ci.draw_line(head + Vector2(-face * 0.1 * u, 0.05 * u), head + Vector2(-face * 0.22 * u, 0.22 * u), Color(0.72, 0.64, 0.5, alpha), 0.06 * u)
		"cap":
			dome.call(0.125, 0.1, 0.02, dark)
			ci.draw_line(head + Vector2(face * 0.04 * u, -0.05 * u), head + Vector2(face * 0.22 * u, -0.04 * u), dark.darkened(0.2), 0.035 * u)
		"boonie":
			dome.call(0.12, 0.1, 0.03, dark)
			ci.draw_line(head + Vector2(-0.22 * u, -0.04 * u), head + Vector2(0.22 * u, -0.04 * u), dark, 0.04 * u)
		"balaclava":
			ci.draw_circle(head, 0.12 * u, Color(0.06, 0.06, 0.07, alpha))
			ci.draw_rect(Rect2(head.x + face * 0.02 * u - 0.06 * u, head.y - 0.04 * u, 0.12 * u, 0.04 * u), Color(pal.skin_tone, alpha))
		_:
			dome.call(0.16, 0.15, 0.02, dark)
			ci.draw_line(head + Vector2(-0.17 * u, -0.03 * u), head + Vector2(0.17 * u, -0.03 * u), dark.darkened(0.2), 0.03 * u)

# ---------- trucks ----------

## A covered army truck seen side-on, facing tr.face. The red-and-white striped
## fuel tank under the body and the cab window are where to hit it.
static func draw_truck(ci: CanvasItem, tr: Dictionary, foot: Vector2, pal: Dictionary, time: float, wind: float) -> void:
	if tr.state in ["wait", "gone"]:
		return
	var d := float(tr.d)
	var u := E.upm(d)
	var L := E.TRUCK_L * u
	var face := float(tr.face)
	var burnt: bool = tr.state == "burning"
	var body: Color = _haze((pal.canvas as Color).darkened(0.25), pal, d) if not burnt else Color(0.08, 0.07, 0.06)
	var cover: Color = _haze((pal.canvas as Color).lightened(0.05), pal, d) if not burnt else Color(0.1, 0.09, 0.08)
	if pal.neon_on and not burnt:
		body = pal.wood
		cover = pal.roof
	_ellipse(ci, foot + Vector2(0, 0.05 * u), L * 0.55, 0.25 * u, Color(0, 0, 0, 0.25), 16)
	ci.draw_set_transform(foot, 0.0, Vector2(face, 1.0))
	ci.draw_rect(Rect2(-0.5 * L, -1.3 * u, L, 0.4 * u), Color(0.08, 0.08, 0.08))
	if not burnt or tr.get("cover_left", true):
		var bed := PackedVector2Array([Vector2(-0.5 * L, -1.3 * u), Vector2(-0.5 * L, -2.7 * u), Vector2(-0.46 * L, -3.0 * u), Vector2(0.06 * L, -3.0 * u), Vector2(0.1 * L, -2.7 * u), Vector2(0.1 * L, -1.3 * u)])
		ci.draw_colored_polygon(bed, cover)
		for k in 4:
			var x := lerpf(-0.46, 0.06, k / 3.0) * L
			ci.draw_line(Vector2(x, -2.95 * u), Vector2(x, -1.35 * u), Color(0, 0, 0, 0.15), maxf(0.5, 0.05 * u))
	var cab := PackedVector2Array([Vector2(0.13 * L, -1.3 * u), Vector2(0.13 * L, -2.55 * u), Vector2(0.3 * L, -2.55 * u), Vector2(0.42 * L, -1.85 * u), Vector2(0.5 * L, -1.8 * u), Vector2(0.5 * L, -1.3 * u)])
	ci.draw_colored_polygon(cab, body)
	var win := PackedVector2Array([Vector2(0.2 * L, -1.95 * u), Vector2(0.2 * L, -2.42 * u), Vector2(0.29 * L, -2.42 * u), Vector2(0.38 * L, -1.95 * u)])
	ci.draw_colored_polygon(win, Color(0.12, 0.16, 0.2) if not burnt else Color(0.05, 0.05, 0.05))
	if tr.state == "drive":
		ci.draw_circle(Vector2(0.27 * L, -2.08 * u), 0.15 * u, Color(0.05, 0.05, 0.05))  # the driver
	# The fuel tank: under the body, just behind the cab.
	var tank := Rect2(-0.75 * u - 0.4 * u, -1.25 * u, 1.5 * u, 0.8 * u)
	ci.draw_rect(tank, Color("c8321e") if not burnt else Color(0.1, 0.06, 0.05))
	if not burnt:
		for k in 3:
			ci.draw_rect(Rect2(tank.position.x + tank.size.x * (0.15 + k * 0.3), tank.position.y, tank.size.x * 0.1, tank.size.y), Color(0.95, 0.95, 0.92))
	var spin := float(tr.s) / 0.5 if tr.state == "drive" else 0.0
	for wx in [-0.36, -0.22, 0.33]:
		var c := Vector2(wx * L, -0.5 * u)
		ci.draw_circle(c, 0.5 * u, Color(0.06, 0.06, 0.06))
		ci.draw_circle(c, 0.25 * u, Color(0.3, 0.3, 0.28) if not burnt else Color(0.12, 0.1, 0.1))
		for k in 3:
			var a := spin + TAU * k / 3.0
			ci.draw_line(c, c + Vector2(cos(a), sin(a)) * 0.24 * u, Color(0.1, 0.1, 0.1), maxf(0.4, 0.05 * u))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if pal.neon_on:
		_edge(ci, PackedVector2Array([foot + Vector2(-0.5 * L * face, -1.3 * u), foot + Vector2(-0.5 * L * face, -3.0 * u), foot + Vector2(0.1 * L * face, -3.0 * u), foot + Vector2(0.5 * L * face, -1.8 * u)]), pal, "edge")
	match str(tr.state):
		"drive":
			if pal.loc in ["desert", "canyon", "alpine"]:
				for k in 6:
					var age := fposmod(time * 1.6 + k / 6.0, 1.0)
					var dp := foot + Vector2(-face * (0.5 * L + age * 3.0 * u), -0.4 * u - age * 1.2 * u)
					ci.draw_circle(dp, (0.3 + age * 1.2) * u, Color(pal.ground_far, 0.35 * (1.0 - age)))
		"burning":
			for k in 7:
				var f := sin(time * (9.0 + k) + k) * 0.5 + 0.5
				_glow(ci, foot + Vector2((k - 3) * 0.6 * u, -1.6 * u - f * 1.5 * u - k % 2 * 0.6 * u), (1.0 + f * 0.4) * u, Color(1.0, 0.5 + 0.2 * f, 0.1, 0.8), 3)
			_smoke(ci, foot + Vector2(0, -3.0 * u), u * 1.6, time, wind, pal, int(tr.id), Color(0.12, 0.11, 0.1, 0.55))
		"stopped":
			_smoke(ci, foot + Vector2(face * 0.45 * L, -1.9 * u), u * 0.7, time, wind, pal, int(tr.id), Color(0.9, 0.9, 0.92, 0.4))

## Headlights and tail lights after dark (drawn on the untinted lights layer).
static func draw_truck_lights(ci: CanvasItem, tr: Dictionary, foot: Vector2, pal: Dictionary) -> void:
	if not pal.lit or tr.state != "drive":
		return
	var u := E.upm(float(tr.d))
	var L := E.TRUCK_L * u
	var face := float(tr.face)
	var front := foot + Vector2(face * 0.5 * L, -1.55 * u)
	var k := 1.0 if pal.night else 0.6
	ci.draw_colored_polygon(PackedVector2Array([front, front + Vector2(face * 14.0 * u, -1.2 * u), front + Vector2(face * 14.0 * u, 2.2 * u)]), Color(1.0, 0.95, 0.75, 0.16 * k))
	_glow(ci, front, 0.35 * u, Color(1.0, 0.96, 0.8, 0.95 * k), 4)
	_glow(ci, foot + Vector2(-face * 0.5 * L, -1.4 * u), 0.2 * u, Color(1.0, 0.1, 0.05, 0.85 * k), 3)

# ---------- light, fog and rays ----------

## Windows, lamps and searchlights after dark (dusk, night, storms). Not tinted.
static func draw_lights(ci: CanvasItem, s: Dictionary, pal: Dictionary, time: float) -> void:
	if not pal.lit or pal.neon_on:
		return
	var k := 1.0 if pal.night else 0.55
	var d := float(s.d)
	var u := E.upm(d)
	var foot := Vector2(float(s.x), E.ground_y(d) - float(s.get("base", 0.0)) * u)
	var w := float(s.get("w", 4.0)) * u
	var h := float(s.get("h", 4.0)) * u
	var warm := Color(1.0, 0.78, 0.42)
	match str(s.t):
		"cabin":
			ci.draw_rect(Rect2(foot.x - w * 0.3, foot.y - h * 0.45, w * 0.16, h * 0.16), Color(warm, 0.95 * k))
			_glow(ci, foot + Vector2(-w * 0.22, -h * 0.37), 0.9 * u, Color(warm, 0.35 * k), 4)
		"hut":
			ci.draw_rect(Rect2(foot.x + w * 0.2, foot.y - h * 0.6, w * 0.16, h * 0.18), Color(warm, 0.9 * k))
		"station":
			for i in 3:
				ci.draw_rect(Rect2(foot.x - w * 0.4 + i * w * 0.3, foot.y - h * 0.55, w * 0.14, h * 0.24), Color(warm, 0.85 * k))
			_glow(ci, foot + Vector2(0, -h * 0.85), 0.6 * u, Color(warm, 0.8 * k), 4)
		"block":
			var hsh := int(s.x) * 7 + int(s.d)
			var r := _rng(hsh + 1)
			var cols := maxi(2, int(float(s.w) / 2.6))
			var rows := maxi(2, int(float(s.h) / 3.2))
			var cw := w / cols
			var rh := h / rows
			var share := 0.38 if pal.night else 0.15
			for ry in rows:
				for cx in cols:
					if r.randf() < share:
						var c := warm if r.randf() < 0.75 else Color(0.7, 0.85, 1.0)
						ci.draw_rect(Rect2(foot.x - w * 0.5 + cx * cw + cw * 0.22, foot.y - h + ry * rh + rh * 0.25, cw * 0.56, rh * 0.5), Color(c, (0.6 + 0.35 * r.randf()) * k))
		"billboard":
			var panel := Rect2(foot.x - w * 0.5, foot.y - h, w, h * 0.6)
			ci.draw_rect(panel, Color(1.0, 0.95, 0.85, 0.18 * k))
			for sx in [-0.3, 0.3]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(foot.x + sx * w, foot.y - h * 0.4), Vector2(foot.x + sx * w - w * 0.25, foot.y - h), Vector2(foot.x + sx * w + w * 0.25, foot.y - h)]), Color(1.0, 0.95, 0.8, 0.12 * k))
		"ship":
			for i in 10:
				_glow(ci, foot + Vector2(-w * 0.42 + i * w * 0.08, -5.5 * u), 0.3 * u, Color(warm, 0.8 * k), 2)
		"stilt", "watertower":
			_glow(ci, foot + Vector2(-w * 0.2, -h * 0.7), 1.0 * u, Color(warm, (0.6 + 0.2 * sin(time * 7.0 + float(s.x))) * k), 4)
		"tower":
			# A searchlight sweeping the valley floor.
			var top := foot + Vector2(0, -h - 1.0 * u)
			var a := sin(time * 0.35 + float(s.x) * 0.01) * 0.9
			var tgt := Vector2(foot.x + sin(a) * 420.0, E.ground_y(maxf(120.0, d * 0.55)))
			var dir := (tgt - top).normalized()
			var n := dir.orthogonal()
			var len_ := top.distance_to(tgt)
			ci.draw_colored_polygon(PackedVector2Array([top + n * 0.3 * u, top - n * 0.3 * u, top + dir * len_ - n * len_ * 0.08, top + dir * len_ + n * len_ * 0.08]), Color(1.0, 0.97, 0.85, 0.09 * k))
			_ellipse(ci, tgt, len_ * 0.1, len_ * 0.025, Color(1.0, 0.97, 0.85, 0.12 * k), 16)
			_glow(ci, top, 0.5 * u, Color(1, 1, 0.9, 0.95 * k), 4)

## The city's street lamps and the pools of light under them.
static func draw_street_lights(ci: CanvasItem, pal: Dictionary, lay: Dictionary) -> void:
	if not pal.lit or pal.neon_on or not lay.has("road"):
		return
	var k := 1.0 if pal.night else 0.55
	var d := float(lay.road[0][1]) + 8.0
	var lu := E.upm(d)
	for x2 in [150.0, 650.0, 1150.0, 1650.0, 2150.0]:
		var lamp := Vector2(x2 + 1.2 * lu, E.ground_y(d) - 7.2 * lu)
		_ellipse(ci, Vector2(x2 + 1.2 * lu, E.ground_y(d - 4.0)), 4.5 * lu, 0.7 * lu, Color(1.0, 0.8, 0.45, 0.16 * k), 16)
		_glow(ci, lamp, 0.4 * lu, Color(1.0, 0.85, 0.55, 0.95 * k), 4)

## A bank of fog lying across the valley at range d, drifting with the wind.
static func draw_fog(ci: CanvasItem, pal: Dictionary, time: float, wind: float, d: float, seed: int) -> void:
	var u := E.upm(d)
	var y := E.ground_y(d)
	var r := _rng(seed)
	var c: Color = pal.haze
	var a := clampf((d - 200.0) / 500.0, 0.06, 0.24)  # a near bank is a thin veil, a far one thick
	for i in 16:
		var x := X0 + fposmod(r.randf_range(0.0, X1 - X0) + time * (3.0 + wind * 4.0) * (0.6 + r.randf()), X1 - X0)
		var rx := r.randf_range(18.0, 40.0) * u
		_ellipse(ci, Vector2(x, y - r.randf_range(0.5, 4.0) * u), rx, minf(rx * 0.18, 60.0), Color(c, a), 16)

## Shafts of low sunlight fanning up from the sun (clear dawn and dusk), in the sky.
static func draw_rays(ci: CanvasItem, pal: Dictionary, time: float) -> void:
	if not pal.rays or pal.neon_on:
		return
	var sp: Vector2 = pal.sun_pos
	var c: Color = pal.sun
	for i in 7:
		var a := -PI * 0.5 + (float(i) - 3.0) * 0.32 + sin(time * 0.05 + i) * 0.03 - float(pal.sun_side) * 0.35
		var dir := Vector2(cos(a), sin(a))
		var n := dir.orthogonal()
		var len_ := 1800.0
		var wd := 30.0 + (i % 3) * 22.0
		ci.draw_colored_polygon(PackedVector2Array([sp + n * 4.0, sp - n * 4.0, sp + dir * len_ - n * wd * 4.0, sp + dir * len_ + n * wd * 4.0]),
			Color(c, 0.035 + 0.02 * sin(time * 0.3 + i)))

# ---------- the foreground (animated) ----------

## Grass, ferns or reeds right under the hide, swaying with the wind.
static func draw_front(ci: CanvasItem, pal: Dictionary, time: float, wind: float) -> void:
	if pal.loc == "city":
		_rooftop(ci, pal, time, wind)
		return
	var r := _rng(91)
	var base := E.H + 20.0
	var col: Color = pal.grass if not pal.neon_on else Color("0b2414")
	if pal.loc == "alpine" and not pal.neon_on:
		col = Color("8a8a74")
	var ws := wind_sign(wind)
	for i in 120:
		var x := r.randf_range(X0, X1)
		if x > 600 and x < 1800 and r.randf() < 0.7:
			continue  # keep the middle of the view clear
		var hgt := r.randf_range(40.0, 130.0)
		var bend := (ws * 0.6 + sin(time * 1.7 + x * 0.01) * 0.25) * hgt * 0.5
		var c := col.darkened(r.randf() * 0.35)
		var tip := Vector2(x + bend, base - hgt)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, base), Vector2(x + 4, base), Vector2(x + bend * 0.5 + 1, base - hgt * 0.55), tip]), c)
		if pal.neon_on and i % 3 == 0:
			ci.draw_line(Vector2(x, base), tip, Color(pal.edge3, 0.5), 1.0)
	# A dark lip of earth (the edge of the hide).
	var lip := PackedVector2Array([Vector2(X0, E.H - 10), Vector2(300, E.H - 22), Vector2(700, E.H - 8), Vector2(1700, E.H - 6), Vector2(2100, E.H - 24), Vector2(X1, E.H - 12), Vector2(X1, E.H + 300), Vector2(X0, E.H + 300)])
	ci.draw_colored_polygon(lip, Color(0.05, 0.05, 0.05) if not pal.neon_on else Color("05020a"))

## Night City: the hide is a rooftop. Its gravel, parapet, a vent and an aerial.
static func _rooftop(ci: CanvasItem, pal: Dictionary, time: float, wind: float) -> void:
	var top := E.H - 150.0
	var con: Color = Color("4a4c52") if not pal.neon_on else Color("0b0614")
	ci.draw_rect(Rect2(X0, top, X1 - X0, 400.0), con)
	ci.draw_rect(Rect2(X0, top, X1 - X0, 10.0), con.lightened(0.15))
	if pal.neon_on:
		_edge(ci, PackedVector2Array([Vector2(X0, top), Vector2(X1, top)]), pal, "edge", 2.0)
	var r := _rng(93)
	for i in 160:
		ci.draw_rect(Rect2(r.randf_range(X0, X1), r.randf_range(top + 14.0, E.H + 60.0), 3.0, 2.0), Color(0, 0, 0, 0.25))
	# A vent at the left, an aerial at the right, puddles if it rains.
	ci.draw_rect(Rect2(60.0, top - 120.0, 150.0, 120.0), con.darkened(0.2))
	ci.draw_rect(Rect2(52.0, top - 128.0, 166.0, 12.0), con.lightened(0.1))
	for k in 6:
		ci.draw_line(Vector2(72.0, top - 104.0 + k * 16.0), Vector2(198.0, top - 104.0 + k * 16.0), Color(0, 0, 0, 0.35), 3.0)
	var ax := E.W - 160.0
	var sway := sin(time * 1.3) * 3.0 + wind_sign(wind) * 6.0
	ci.draw_line(Vector2(ax, top), Vector2(ax + sway, top - 260.0), con.darkened(0.3), 6.0)
	for k in 4:
		var y := top - 120.0 - k * 36.0
		ci.draw_line(Vector2(ax - 50.0 + sway * (1.0 - y / top), y), Vector2(ax + 50.0 + sway * (1.0 - y / top), y), con.darkened(0.3), 4.0)
	if fposmod(time, 1.8) < 0.5:
		_glow(ci, Vector2(ax + sway, top - 262.0), 6.0, Color(1.0, 0.15, 0.1, 0.95), 4)
	if pal.wx in ["rain", "storm"] and not pal.neon_on:
		for k in 5:
			_ellipse(ci, Vector2(300.0 + k * 420.0, E.H - 20.0 + (k % 2) * 14.0), 120.0, 10.0, Color(0.6, 0.7, 0.85, 0.18), 18)

## Sea glitter (harbour) and the lake shine (alpine), drawn over the ground.
static func draw_water(ci: CanvasItem, pal: Dictionary, lay: Dictionary, time: float) -> void:
	if not lay.has("sea"):
		return
	var sea_d := float(lay.sea)
	var r := _rng(17)
	var sp: Vector2 = pal.sun_pos
	for i in 160:
		var d := r.randf_range(sea_d + 20.0, 4000.0)
		var y := E.ground_y(d)
		var near_sun := 1.0 - clampf(absf(r.randf_range(X0, X1) - sp.x) / 900.0, 0.0, 1.0)
		var x := sp.x + r.randf_range(-1.0, 1.0) * (300.0 + (y - E.HORIZON) * 12.0)
		var tw := 0.5 + 0.5 * sin(time * r.randf_range(1.5, 4.0) + i)
		var len_ := r.randf_range(6.0, 26.0) * (y - E.HORIZON) / 40.0
		var c: Color = Color(1.0, 0.75, 0.45, 0.25 + 0.45 * tw * (0.4 + near_sun)) if not pal.neon_on else Color(pal.edge2, 0.4 * tw)
		ci.draw_line(Vector2(x - len_, y), Vector2(x + len_, y), c, 1.2)
