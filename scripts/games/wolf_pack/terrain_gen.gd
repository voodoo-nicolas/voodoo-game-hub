extends RefCounted

## Terrain generator: shared, pure logic (no Nodes, headless-testable).
## Template: tools/templates/terrain_gen.gd is the only copy ever edited;
## `python tools/hub.py sync` copies it into every game that names this file, as
## scripts/games/<id>/terrain_gen.gd, so its pack runs on any app version.
##
## Use:
##     const TerrainGen = preload("res://scripts/games/<id>/terrain_gen.gd")
##     var h: PackedFloat32Array = TerrainGen.generate(gw, gh, seed, {"hill": 40.0, ...})
##
## Output: one height per cell, row-major (y * gw + x), 0..1.
## Users: Thrust (hover_duel), Wolf Pack (wolf_pack).
##
## How it gets its depth (all knobs in DEFAULTS, override any of them):
## - rolling hills: fractal simplex noise, domain-warped so hills flow into
##   each other instead of sitting as round blobs;
## - big height differences: a broad "macro" layer (whole highlands and
##   basins, a few per map) under the hills, then the result is stretched to
##   the full 0..1 range;
## - crests: a little ridged noise for sharper hilltops (ridge = 0 turns it off);
## - always crossable: max_slope caps how much two neighbouring cells may
##   differ, so a hill can be tall but never a cliff (0 = no cap).
## - valleys: long winding troughs that run on and branch, so the hills sit
##   between connected low paths instead of in a random field;
## - erosion: simulated rain carves gullies down every slope and leaves soft
##   fans at the bottom, which is what makes land read as real depth.
## Same seed + same options = same map on every device (FastNoiseLite is
## deterministic), so a save only needs the seed.

const DEFAULTS := {
	"hill": 40.0,        # size of a typical hill, in cells (noise wavelength)
	"octaves": 5,        # detail layers on the hills
	"gain": 0.5,         # how strong each finer layer is
	"warp": 0.6,         # domain warp, in hill sizes: 0 = round blobs, 1 = long winding ridges and valleys
	"macro": 0.9,        # broad highlands / basins under the hills (0..~1.5)
	"macro_size": 3.0,   # their size, in hill sizes
	"ridge": 0.2,        # 0..1 share of ridged noise (sharper crests)
	"curve": 1.0,        # >1 widens the lowlands and sharpens peaks, <1 the opposite
	"max_slope": 0.0,    # cap on the height step between neighbouring cells (0 = none)
	# [NEW 2026-11-23] depth passes:
	"valleys": 0.0,      # 0..~0.6: long winding valleys cut through the hills (connected low paths)
	"valley_size": 2.2,  # valley spacing, in hill sizes
	"erosion": 0.0,      # 0..~1.5: rain erosion (gullies down the slopes, soft fans at the bottom); cost grows with it
}

static func generate(gw: int, gh: int, seed_v: int, opts: Dictionary = {}) -> PackedFloat32Array:
	var o := DEFAULTS.duplicate()
	o.merge(opts, true)
	var hill: float = maxf(2.0, float(o.hill))
	var base := FastNoiseLite.new()
	base.seed = seed_v
	base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base.frequency = 1.0 / hill
	base.fractal_type = FastNoiseLite.FRACTAL_FBM
	base.fractal_octaves = int(o.octaves)
	base.fractal_gain = float(o.gain)
	base.fractal_lacunarity = 2.0
	if float(o.warp) > 0.0:
		base.domain_warp_enabled = true
		base.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
		base.domain_warp_amplitude = float(o.warp) * hill
		base.domain_warp_frequency = 1.0 / (hill * 1.7)
		base.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_PROGRESSIVE
		base.domain_warp_fractal_octaves = 2
	var macro := FastNoiseLite.new()
	macro.seed = seed_v * 31 + 7
	macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro.frequency = 1.0 / (hill * float(o.macro_size))
	macro.fractal_type = FastNoiseLite.FRACTAL_FBM
	macro.fractal_octaves = 2
	var ridged := FastNoiseLite.new()
	ridged.seed = seed_v * 17 + 3
	ridged.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridged.frequency = 1.0 / (hill * 1.3)
	ridged.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridged.fractal_octaves = 3
	var rmix: float = clampf(float(o.ridge), 0.0, 1.0)
	var mamp: float = float(o.macro)
	# Valleys: where a warped noise crosses zero, a narrow trough; the zero lines of
	# simplex noise are long connected curves, so the valleys run on and branch.
	var vamp: float = float(o.valleys)
	var vnoise := FastNoiseLite.new()
	vnoise.seed = seed_v * 13 + 5
	vnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	vnoise.frequency = 1.0 / (hill * float(o.valley_size))
	vnoise.fractal_type = FastNoiseLite.FRACTAL_FBM
	vnoise.fractal_octaves = 2
	vnoise.domain_warp_enabled = true
	vnoise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	vnoise.domain_warp_amplitude = hill * 0.8
	vnoise.domain_warp_frequency = 1.0 / (hill * 2.0)
	var h := PackedFloat32Array()
	h.resize(gw * gh)
	var lo := INF
	var hi := -INF
	for y in gh:
		for x in gw:
			var fx := float(x)
			var fy := float(y)
			# get_noise_2d is -1..1 (roughly); ridged is too.
			var v: float = base.get_noise_2d(fx, fy) * (1.0 - rmix)
			if rmix > 0.0:
				v += ridged.get_noise_2d(fx, fy) * rmix
			v += macro.get_noise_2d(fx, fy) * mamp
			if vamp > 0.0:
				var vv: float = 1.0 - minf(1.0, absf(vnoise.get_noise_2d(fx, fy)) * 4.0)
				v -= vv * vv * vamp   # smooth U-shaped trough, 0 away from the valley line
			h[y * gw + x] = v
			lo = minf(lo, v)
			hi = maxf(hi, v)
	# Stretch to the full 0..1 range: the most height difference the map can have.
	var span: float = maxf(hi - lo, 0.0001)
	var curve: float = float(o.curve)
	for i in h.size():
		var t: float = (h[i] - lo) / span
		h[i] = pow(t, curve) if curve != 1.0 else t
	if float(o.erosion) > 0.0:
		erode(h, gw, gh, seed_v, float(o.erosion))
	if float(o.max_slope) > 0.0:
		limit_slope(h, gw, gh, float(o.max_slope))
	return h

## Rain erosion (droplet model): each drop runs downhill, picks up soil where it
## speeds up and drops it where it slows, carving gullies and leaving soft fans.
## Deterministic (own seeded rng). Re-stretched to 0..1 afterwards.
## amount 1.0 = about one drop per 20 cells, 30 steps each.
static func erode(h: PackedFloat32Array, gw: int, gh: int, seed_v: int, amount: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7 + 11
	var drops := int(gw * gh * 0.05 * amount)
	const INERTIA := 0.08
	const CAP := 10.0
	const MIN_CAP := 0.002
	const ERODE := 0.5
	const DEPOSIT := 0.3
	const EVAP := 0.03
	const GRAV := 6.0
	for _d in drops:
		var px := rng.randf_range(1.0, gw - 2.0)
		var py := rng.randf_range(1.0, gh - 2.0)
		var dx := 0.0
		var dy := 0.0
		var speed := 1.0
		var water := 1.0
		var sed := 0.0
		for _life in 30:
			var ix := int(px)
			var iy := int(py)
			var ox := px - ix
			var oy := py - iy
			var i := iy * gw + ix
			var h00: float = h[i]
			var h10: float = h[i + 1]
			var h01: float = h[i + gw]
			var h11: float = h[i + gw + 1]
			var gx: float = (h10 - h00) * (1.0 - oy) + (h11 - h01) * oy
			var gy: float = (h01 - h00) * (1.0 - ox) + (h11 - h10) * ox
			var hh: float = h00 * (1 - ox) * (1 - oy) + h10 * ox * (1 - oy) + h01 * (1 - ox) * oy + h11 * ox * oy
			dx = dx * INERTIA - gx * (1.0 - INERTIA)
			dy = dy * INERTIA - gy * (1.0 - INERTIA)
			var dl := sqrt(dx * dx + dy * dy)
			if dl < 0.000001:
				break
			dx /= dl
			dy /= dl
			px += dx
			py += dy
			if px < 1.0 or py < 1.0 or px >= gw - 2.0 or py >= gh - 2.0:
				break
			var nh := sample(h, gw, gh, px, py)
			var dh := nh - hh
			var cap := maxf(-dh * speed * water * CAP, MIN_CAP)
			if sed > cap or dh > 0.0:
				var put := minf(dh, sed) if dh > 0.0 else (sed - cap) * DEPOSIT
				sed -= put
				h[i] += put * (1 - ox) * (1 - oy)
				h[i + 1] += put * ox * (1 - oy)
				h[i + gw] += put * (1 - ox) * oy
				h[i + gw + 1] += put * ox * oy
			else:
				var take := minf((cap - sed) * ERODE, -dh)
				sed += take
				h[i] -= take * (1 - ox) * (1 - oy)
				h[i + 1] -= take * ox * (1 - oy)
				h[i + gw] -= take * (1 - ox) * oy
				h[i + gw + 1] -= take * ox * oy
			speed = sqrt(maxf(0.0, speed * speed + dh * GRAV))
			water *= 1.0 - EVAP
	var lo := INF
	var hi := -INF
	for v in h:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span: float = maxf(hi - lo, 0.0001)
	for k in h.size():
		h[k] = (h[k] - lo) / span

## Caps the height step between 8-neighbours at `max_step` by lowering the
## higher cell (peaks soften, nothing becomes a wall). Two sweeps, forward
## and back, settle it (a chamfer distance pass).
static func limit_slope(h: PackedFloat32Array, gw: int, gh: int, max_step: float) -> void:
	var diag := max_step * 1.41421356
	for pass_i in 2:
		var ys: Array = range(gh) if pass_i == 0 else range(gh - 1, -1, -1)
		var xs: Array = range(gw) if pass_i == 0 else range(gw - 1, -1, -1)
		var d := 1 if pass_i == 0 else -1
		for y in ys:
			for x in xs:
				var i: int = y * gw + x
				var m: float = h[i]
				# Neighbours already visited in this sweep: (x-d, y), (x, y-d), (x-d, y-d), (x+d, y-d).
				var px: int = x - d
				var py: int = y - d
				if px >= 0 and px < gw:
					m = minf(m, h[y * gw + px] + max_step)
				if py >= 0 and py < gh:
					m = minf(m, h[py * gw + x] + max_step)
					if px >= 0 and px < gw:
						m = minf(m, h[py * gw + px] + diag)
					var qx: int = x + d
					if qx >= 0 and qx < gw:
						m = minf(m, h[py * gw + qx] + diag)
				h[i] = m

## Re-maps heights so the given share of cells lands under each level:
## stops = [[share, level], ...] with shares and levels rising, e.g.
## [[0.18, 0.30], [0.92, 0.86]] puts 18 % of the map below 0.30 and 8 % above
## 0.86. Between the stops it is linear, so the shape of the hills is kept.
static func remap_shares(h: PackedFloat32Array, stops: Array) -> void:
	if h.is_empty():
		return
	var sorted := h.duplicate()
	sorted.sort()
	var n := sorted.size()
	# Input knots (heights at those shares) -> output levels, framed by 0 and 1.
	var ins: Array = [sorted[0]]
	var outs: Array = [0.0]
	for s in stops:
		var k: int = clampi(int(float(s[0]) * n), 0, n - 1)
		var v: float = sorted[k]
		if v <= float(ins.back()):
			continue
		ins.append(v)
		outs.append(float(s[1]))
	if sorted[n - 1] > float(ins.back()):
		ins.append(sorted[n - 1])
		outs.append(1.0)
	for i in h.size():
		var v: float = h[i]
		var j := 1
		while j < ins.size() - 1 and v > float(ins[j]):
			j += 1
		var a: float = ins[j - 1]
		var b: float = ins[j]
		var t: float = clampf((v - a) / maxf(b - a, 0.000001), 0.0, 1.0)
		h[i] = lerpf(float(outs[j - 1]), float(outs[j]), t)

## Height at a fractional cell position (cell centres at .0), bilinear, clamped to the grid.
static func sample(h: PackedFloat32Array, gw: int, gh: int, fx: float, fy: float) -> float:
	fx = clampf(fx, 0.0, gw - 1.001)
	fy = clampf(fy, 0.0, gh - 1.001)
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - ix
	var ty := fy - iy
	var a := lerpf(h[iy * gw + ix], h[iy * gw + ix + 1], tx)
	var b := lerpf(h[(iy + 1) * gw + ix], h[(iy + 1) * gw + ix + 1], tx)
	return lerpf(a, b, ty)

## Slope at a fractional cell position: height change per cell along x and y.
static func gradient(h: PackedFloat32Array, gw: int, gh: int, fx: float, fy: float) -> Vector2:
	return Vector2(sample(h, gw, gh, fx + 0.5, fy) - sample(h, gw, gh, fx - 0.5, fy),
		sample(h, gw, gh, fx, fy + 0.5) - sample(h, gw, gh, fx, fy - 0.5))

## A soft-shaded picture of the heights (one pixel per cell, RGBA8): light
## from the top-left, darker in valleys, lighter on tops. Draw it over the
## ground with a multiply-like tint to give a flat map its hills.
## relief: how tall the hills look (bigger = stronger shading).
static func shade_image(h: PackedFloat32Array, gw: int, gh: int, relief: float = 6.0, light := Vector2(-0.6, -0.8)) -> Image:
	var img := Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	var l := light.normalized()
	for y in gh:
		for x in gw:
			var g := gradient(h, gw, gh, float(x), float(y)) * relief
			# Lambert on a normal (-gx, -gy, 1) against a sun 45 degrees up.
			var nrm := Vector3(-g.x, -g.y, 1.0).normalized()
			var lit: float = nrm.dot(Vector3(-l.x, -l.y, 1.0).normalized())
			var hv: float = h[y * gw + x]
			var shade: float = clampf(lit * 0.75 + hv * 0.45, 0.0, 1.4)
			img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	return img
